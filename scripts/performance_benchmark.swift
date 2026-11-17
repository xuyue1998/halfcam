import Foundation
import CoreGraphics
import ImageIO
import Darwin

// Compile with the production Models.swift, StoreReader.swift and FilmRenderer
// implementation (the host runner replaces its unused UIKit import).
func L(_ value: String) -> String { value }
struct FilmRecipe { let name: String }

@main
struct PerformanceBenchmark {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else { fatalError("fixture <dir> <rolls> | library/metadata <dir> <baseline/optimized> <iterations>") }
        let directory = URL(fileURLWithPath: args[2], isDirectory: true)
        switch args[1] {
        case "fixture":
            try makeLibrary(directory, rolls: Int(args[3])!)
            try makeJPEG(directory.appendingPathComponent("source.jpg"))
            print("{}")
        case "library":
            try benchmarkLibrary(directory, optimized: args[3] == "optimized", iterations: Int(args[4])!)
        case "metadata":
            try benchmarkMetadata(directory, optimized: args[3] == "optimized", iterations: Int(args[4])!)
        default:
            fatalError("Unknown mode")
        }
    }

    static func makeLibrary(_ directory: URL, rolls count: Int) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let rolls: [Roll] = (0..<count).map { r in
            let frames: [Frame] = (1...72).map { i in
                Frame(id: UUID(), index: i, shotAt: date,
                      fileName: String(format: "%03d.neg", i),
                      posFileName: String(format: "%03d_pos.jpg", i),
                      thumbFileName: String(format: "%03d_thm.jpg", i),
                      leakStrength: 0, leakAngle: 0, leakHue: 0, developed: true,
                      exported: true, exportedAssetIds: ["fixture-\(r)-\(i)"],
                      iso: 400, shutter: 0.008, lens: 0.7)
            }
            return Roll(id: UUID(), filmId: "portra_400", iso: 400, capacity: 72,
                        shotCount: 72, state: .ready, grain: .fine, leak: .off,
                        diffusion: .off, dateStamp: false, rollSeed: Int64(r + 1),
                        loadedAt: date, rewindAt: date, developedAt: date,
                        leaderConsumed: true, armed: false, frames: frames)
        }
        let store = PersistStore(rolls: rolls, currentRollId: nil, flashOn: false,
                                 soundOn: true, hapticOn: true, hasSeenHint: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: directory.appendingPathComponent("store.json"))
        try data.write(to: directory.appendingPathComponent("store.backup.json"))
    }

    static func makeJPEG(_ url: URL) throws {
        let width = 4032, height = 3024
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let pixels = context.data!.assumingMemoryBound(to: UInt32.self)
        var state: UInt32 = 0x12345678
        for i in 0..<(width * height) {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            pixels[i] = state | 0xff000000
        }
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [
            kCGImageDestinationLossyCompressionQuality: 0.92,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifFNumber: 2.8,
                kCGImagePropertyExifISOSpeedRatings: [400]
            ]
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    static func benchmarkLibrary(_ directory: URL, optimized: Bool, iterations: Int) throws {
        let primary = directory.appendingPathComponent("store.json")
        let backup = directory.appendingPathComponent("store.backup.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var reads = 0
        func read(_ url: URL) throws -> Data {
            reads += 1
            return try Data(contentsOf: url)
        }
        func work() -> Int {
            if optimized {
                let restored = StoreReader.firstValid(PersistStore.self, urls: [primary, backup],
                                                      decoder: decoder, readData: read)!
                return restored.value.rolls.count
            }
            // Exact eager-read/eager-decode algorithm used before this performance pass.
            let candidates = [primary, backup].compactMap { try? read($0) }
            let restored = candidates.compactMap { data -> (PersistStore, Data)? in
                guard let store = try? decoder.decode(PersistStore.self, from: data) else { return nil }
                return (store, data)
            }.first!
            let matches = (try? read(primary)) == restored.1
            precondition(matches)
            return restored.0.rolls.count
        }
        for _ in 0..<3 { _ = autoreleasepool { work() } }
        reads = 0
        var samples: [Double] = []
        var checksum = 0
        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum += autoreleasepool { work() }
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        let values = try primary.resourceValues(forKeys: [.fileSizeKey])
        try emit(samples, fields: [
            "scenario": "library", "variant": optimized ? "optimized" : "baseline",
            "file_reads_per_iteration": reads / iterations, "checksum": checksum,
            "fixture_bytes": values.fileSize ?? 0,
            "iterations": iterations
        ])
    }

    static func benchmarkMetadata(_ directory: URL, optimized: Bool, iterations: Int) throws {
        let url = directory.appendingPathComponent("source.jpg")
        func work() throws -> Int {
            if optimized { return FilmRenderer.metadata(at: url).count }
            let data = try Data(contentsOf: url)
            let source = CGImageSourceCreateWithData(data as CFData, nil)!
            return (CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary).count
        }
        for _ in 0..<3 { _ = try autoreleasepool { try work() } }
        var samples: [Double] = []
        var checksum = 0
        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum += try autoreleasepool { try work() }
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        try emit(samples, fields: [
            "scenario": "metadata", "variant": optimized ? "optimized" : "baseline",
            "fixture_bytes": values.fileSize ?? 0, "checksum": checksum,
            "iterations": iterations
        ])
    }

    static func emit(_ samples: [Double], fields: [String: Any]) throws {
        let sorted = samples.sorted()
        var result = fields
        result["p50_ms"] = sorted[sorted.count / 2]
        result["p95_ms"] = sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
        result["peak_rss_bytes"] = peakRSS()
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }

    static func peakRSS() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size_max) : 0
    }
}
