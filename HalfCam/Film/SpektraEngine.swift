import CoreGraphics
import CoreImage
import Foundation
import Metal
import UIKit

final class SpektraEngine {
    static let shared = SpektraEngine()
    static let previewEdge: CGFloat = 2048
    static let exportEdge: CGFloat = 4032

    let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    private let jpegContext: CIContext
    private let lock = NSLock()
    private var cachedReady: Bool?

    private init() {
        if let device = metalDevice {
            jpegContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.rommrgb) as Any,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any,
                .cacheIntermediates: false
            ])
        } else {
            jpegContext = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.rommrgb) as Any,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any,
                .cacheIntermediates: false
            ])
        }
    }

    var isAvailable: Bool {
        lock.lock()
        if let cachedReady {
            lock.unlock()
            return cachedReady
        }
        lock.unlock()
        let ready = resourcesDir().withCString { dir -> Bool in
            if let device = metalDevice {
                return hc_spk_ready(dir, Unmanaged.passUnretained(device).toOpaque()) != 0
            }
            return hc_spk_ready(dir, nil) != 0
        }
        lock.lock()
        cachedReady = ready
        lock.unlock()
        return ready
    }

    func warmUp(film: String, paper: String) {
        guard isAvailable else { return }
        film.withCString { f in
            paper.withCString { p in
                _ = hc_spk_warm_up(f, p)
            }
        }
    }

    func develop(data: Data, recipe: FilmRecipe, roll: Roll, frame: Frame) -> FilmRenderer.Output? {
        guard isAvailable else { return nil }
        guard var linear = Ingest.linearRGB(data: data, longEdge: Self.exportEdge) else { return nil }
        let json = paramsJSON(recipe: recipe, roll: roll, frame: frame)
        lock.lock()
        defer { lock.unlock() }
        let session: UnsafeMutableRawPointer? = linear.rgb.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return nil }
            return json.withCString { cjson in
                hc_spk_open(base, UInt32(linear.width), UInt32(linear.height), cjson)
            }
        }
        linear.rgb.removeAll(keepingCapacity: false)
        guard let session else { return nil }
        defer { hc_spk_close(session) }

        guard let thumb = reprint(session, tier: "live") else { return nil }
        guard let positive = reprint(session, tier: "full") else {
            return FilmRenderer.Output(positive: thumb, thumb: thumb)
        }
        return FilmRenderer.Output(
            positive: FilmRenderer.stamp(positive, original: data, frame: frame, recipe: recipe),
            thumb: thumb
        )
    }

    private func reprint(_ session: UnsafeMutableRawPointer, tier: String) -> Data? {
        var rgba: UnsafeMutablePointer<UInt16>?
        var width: UInt32 = 0
        var height: UInt32 = 0
        var stride: UInt32 = 0
        var texture: UnsafeMutableRawPointer?
        var hold: UnsafeMutableRawPointer?
        let ok = tier.withCString { ctier in
            hc_spk_reprint(session, ctier, &rgba, &width, &height, &stride, &texture, &hold)
        }
        defer { hc_spk_result_free(hold) }
        guard ok == 0, width > 0, height > 0 else { return nil }
        if let texture, let jpeg = jpeg(texture: texture) {
            return jpeg
        }
        guard let rgba else { return nil }
        return jpeg(rgba16: UnsafePointer(rgba), width: Int(width), height: Int(height), stride: Int(stride))
    }

    private func resourcesDir() -> String {
        Bundle.main.resourceURL?.appendingPathComponent("engine", isDirectory: true).path ?? ""
    }

    private func paramsJSON(recipe: FilmRecipe, roll: Roll, frame: Frame) -> String {
        let grain = Double(min(2, max(0, roll.grain.resolvedAmount(seed: roll.rollSeed, frame: frame.index))))
        var obj: [String: Any] = [
            "film_stock": FilmCatalog.spkFilm(id: recipe.id),
            "print_stock": FilmCatalog.spkPaper(id: recipe.id, paperId: roll.paperId),
            "scan_film": FilmCatalog.spkScanFilm(id: recipe.id),
            "grain_amount": grain,
            "grain_active": grain > 0.001,
            "preview_long_edge": 2048,
            "film_format_mm": 24,
            "input_color_space": "ProPhoto RGB",
            "input_cctf_decoding": false
        ]
        if recipe.process == .bw {
            obj["grain_sublayers_active"] = false
            if !roll.cameraFilter.isEmpty {
                obj["camera_filter"] = roll.cameraFilter
            }
        }
        if recipe.id == "cinestill_800t" {
            obj["antihalation_removed"] = true
            obj["halation_headroom_ev"] = 4.0
        }
        if roll.dateStamp {
            obj["date_imprint_active"] = true
            obj["date_imprint_style"] = "lcd"
            obj["date_imprint_placement"] = "frame"
            obj["date_imprint_corner"] = "br"
            obj["date_imprint_text"] = dateText(frame.shotAt)
            obj["date_imprint_ev"] = 3.5
            obj["date_imprint_size"] = 1.0
        }
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    private func dateText(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date) % 100
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%02d %02d %02d", y, m, d)
    }

    private func jpeg(texture: UnsafeMutableRawPointer) -> Data? {
        let mtl = Unmanaged<MTLTexture>.fromOpaque(texture).takeUnretainedValue()
        let space = CGColorSpace(name: CGColorSpace.rommrgb)
        var options: [CIImageOption: Any] = [:]
        if let space { options[.colorSpace] = space }
        guard var image = CIImage(mtlTexture: mtl, options: options) else { return nil }
        image = image.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: image.extent.height))
        return jpeg(image)
    }

    private func jpeg(rgba16: UnsafePointer<UInt16>, width: Int, height: Int, stride: Int) -> Data? {
        let pitch = max(width, stride)
        let packed: Data
        if pitch == width {
            packed = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: rgba16), count: width * height * 8, deallocator: .none)
        } else {
            var data = Data(count: width * height * 8)
            data.withUnsafeMutableBytes { raw in
                guard let dstBase = raw.baseAddress else { return }
                for y in 0..<height {
                    memcpy(
                        dstBase.advanced(by: y * width * 8),
                        rgba16.advanced(by: y * pitch * 4),
                        width * 8
                    )
                }
            }
            packed = data
        }
        let space = CGColorSpace(name: CGColorSpace.rommrgb) ?? CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
        guard let provider = CGDataProvider(data: packed as CFData), let cg = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 16,
            bitsPerPixel: 64,
            bytesPerRow: width * 8,
            space: space,
            bitmapInfo: info,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .relativeColorimetric
        ) else { return nil }
        return jpeg(CIImage(cgImage: cg)) ?? UIImage(cgImage: cg).jpegData(compressionQuality: 0.92)
    }

    private func jpeg(_ image: CIImage) -> Data? {
        let p3 = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        return jpegContext.jpegRepresentation(
            of: image,
            colorSpace: p3,
            options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.92]
        )
    }
}
