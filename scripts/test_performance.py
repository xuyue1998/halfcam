"""Performance invariants and native, isolated helper tests; not iPhone FPS tests."""

from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest

from test_camera_session import method
from test_crash_safety import TEMP_ROOT
from test_release_quality import block


ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / "HalfCam" / path).read_text()


class PerformanceSourceChecks(unittest.TestCase):
    def test_primary_library_is_not_eagerly_decoded_with_its_backup(self):
        body = method(source("AppModel.swift"), "load")
        self.assertIn("StoreReader.firstValid", body)
        self.assertNotIn(".compactMap", body)
        self.assertNotIn("Data(contentsOf:", body)
        self.assertIn("restored.url == url ? restored.data : nil", body)

    def test_negative_preview_shares_decode_without_holding_a_worker(self):
        body = method(source("AppModel.swift"), "loadNegative")
        self.assertLess(body.index("await self.loadPreview"), body.index("self.imageWork.run"))
        self.assertNotIn("Self.decode(", body)

    def test_priority_upgrade_does_not_restart_image_work(self):
        body = method(source("AppModel.swift"), "start")
        self.assertIn("if var existing = inflight[key]", body)
        self.assertNotIn(".task.cancel()", body)

    def test_memory_pressure_keeps_visible_requests_alive(self):
        body = method(source("AppModel.swift"), "trimMemory")
        self.assertNotIn(".cancel()", body)
        self.assertNotIn("inflight.remove", body)
        self.assertIn("trimMemory()", source("HalfCamApp.swift"))

    def test_export_reads_metadata_by_url_without_a_full_source_data_copy(self):
        body = method(source("Album/PhotoExport.swift"), "composeJPEG")
        self.assertIn("likeURL: urls[0]", body)
        self.assertNotIn("let source = try? Data(contentsOf:", body)
        metadata = method(source("Film/FilmRenderer.swift"), "metadata")
        self.assertIn("CGImageSourceCreateWithURL", metadata)
        self.assertIn("kCGImageSourceShouldCache: false", metadata)

    def test_unchanged_photo_configuration_does_not_reprepare(self):
        body = method(source("Camera/CameraSession.swift"), "applyPhotoConfiguration")
        self.assertIn("rawChanged || qualityChanged", body)
        self.assertIn("session.isRunning", body)

    def test_recovery_image_validation_is_not_repeated_on_main(self):
        body = method(source("AppModel.swift"), "runDevelop")
        self.assertIn("let completed = await Task.detached", body)
        self.assertIn("if completed.contains(frame.id)", body)
        self.assertNotIn("positiveExists(", body)

    def test_quality_limits_and_durability_are_unchanged(self):
        self.assertIn("static let exportEdge: CGFloat = 4032", source("Film/SpektraEngine.swift"))
        self.assertIn("compressionQuality: 0.92", source("Album/PhotoExport.swift"))
        self.assertIn("try data.write(to: url, options: [.atomic, .completeFileProtection])",
                      method(source("AppModel.swift"), "writeCaptureData"))

    def test_camera_launch_does_not_unconditionally_create_the_spectral_engine(self):
        text = source("AppModel.swift")
        initializer = block(text[text.index("final class AppModel"):], "    init()")
        self.assertNotIn("SpektraEngine.shared.isAvailable", initializer)
        self.assertIn("SpektraEngine.shared.warmUp", method(text, "loadRoll"))


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("swift"), "macOS Swift required")
class NativePerformanceTests(unittest.TestCase):
    def swift(self, code):
        result = subprocess.run(["swift", "-"], input=code, text=True,
                                capture_output=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def test_reader_stops_after_primary_and_recovers_corrupt_or_missing_primary(self):
        code = source("Performance/StoreReader.swift") + """
        struct Payload: Codable { let value: Int }
        enum Missing: Error { case file }
        let primary = URL(fileURLWithPath: "/unused/primary")
        let backup = URL(fileURLWithPath: "/unused/backup")
        let valid = Data(#"{"value":7}"#.utf8)
        var reads: [URL] = []
        let first = StoreReader.firstValid(Payload.self, urls: [primary, backup],
            decoder: JSONDecoder()) { url in
                reads.append(url); return valid
            }
        assert(reads == [primary] && first?.value.value == 7)
        assert(first?.data == valid && first?.url == primary)
        for corrupt in [false, true] {
            reads = []
            let recovered = StoreReader.firstValid(Payload.self, urls: [primary, backup],
                decoder: JSONDecoder()) { url in
                    reads.append(url)
                    if url == primary {
                        if corrupt { return Data("broken".utf8) }
                        throw Missing.file
                    }
                    return valid
                }
            assert(reads == [primary, backup] && recovered?.url == backup)
        }
        let missing = StoreReader.firstValid(Payload.self, urls: [primary, backup],
            decoder: JSONDecoder()) { _ in throw Missing.file }
        assert(missing == nil)
        print("reader passed")
        """
        self.assertIn("reader passed", self.swift(code))

    def test_bounded_workers_finish_and_never_exceed_the_limit(self):
        code = source("Performance/BoundedWorkQueue.swift") + """
        final class Counter: @unchecked Sendable {
            let lock = NSLock()
            var active = 0
            var peak = 0
            func begin() { lock.withLock { active += 1; peak = max(peak, active) } }
            func end() { lock.withLock { active -= 1 } }
        }
        let counter = Counter()
        let queue = BoundedWorkQueue(name: "test", maximumConcurrentOperations: 2)
        let result = await withTaskGroup(of: Int?.self, returning: [Int].self) { group in
            for i in 0..<24 {
                group.addTask {
                    await queue.run {
                        counter.begin(); defer { counter.end() }
                        Thread.sleep(forTimeInterval: 0.003)
                        return i
                    }
                }
            }
            var values: [Int] = []
            for await value in group { if let value { values.append(value) } }
            return values.sorted()
        }
        assert(result == Array(0..<24))
        assert(counter.peak <= 2 && counter.active == 0)
        print("workers passed")
        """
        self.assertIn("workers passed", self.swift(code))

    def test_cancellation_before_execution_and_while_running_does_not_hang(self):
        code = source("Performance/BoundedWorkQueue.swift") + """
        let queue = BoundedWorkQueue(name: "cancel", maximumConcurrentOperations: 1)
        let cancelled = Task { @MainActor in await queue.run { 99 } }
        cancelled.cancel()
        let skipped = await cancelled.value
        assert(skipped == nil)

        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let running = Task {
            await queue.run { started.signal(); release.wait(); return 1 }
        }
        await Task.detached { started.wait() }.value
        running.cancel()
        release.signal()
        let abandoned = await running.value
        assert(abandoned == nil)
        let next = await queue.run { 2 }
        assert(next == 2)
        print("cancel passed")
        """
        self.assertIn("cancel passed", self.swift(code))

    def test_priority_escalation_shares_one_task_and_waiter_finishes_once(self):
        text = source("AppModel.swift")
        start = method(text, "start")
        end = method(text, "end")
        waiter = block(text, "private final class ImageWaiter:")
        code = """
        import Foundation
        typealias UIImage = Int
        final class Counter: @unchecked Sendable {
            let lock = NSLock(); var count = 0
            func increment() { lock.withLock { count += 1 } }
        }
        final class Waiter: @unchecked Sendable { WAITER }
        final class Harness {
            let lock = NSLock()
            var nextGeneration = 0
            struct Inflight {
                let gen: Int
                let task: Task<UIImage?, Never>
                var waiters: Int
            }
            var inflight: [String: Inflight] = [:]
            func start(_ key: String, priority: TaskPriority,
                work: @escaping @Sendable () async -> UIImage?) -> Inflight { START }
            func end(_ key: String, gen: Int) { END }
        }
        let h = Harness()
        let count = Counter()
        let first = h.start("same", priority: .utility) {
            count.increment()
            try? await Task.sleep(for: .milliseconds(15))
            return 7
        }
        let second = h.start("same", priority: .userInitiated) {
            count.increment(); return 8
        }
        assert(first.gen == second.gen && second.waiters == 2)
        let a = await first.task.value
        let b = await second.task.value
        assert(a == 7 && b == 7 && count.count == 1)
        h.end("same", gen: first.gen); h.end("same", gen: second.gen)
        assert(h.inflight.isEmpty)

        let waiter = Waiter()
        let once = Counter()
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            waiter.finish { once.increment() }
        }
        assert(once.count == 1)
        print("sharing passed")
        """.replace("WAITER", waiter).replace("START", start).replace("END", end)
        self.assertIn("sharing passed", self.swift(code))

    def test_purge_does_not_hold_the_lock_during_synchronous_cancellation_handlers(self):
        text = source("AppModel.swift")
        purge = method(text, "purge")
        prefix = block(text, "func purge(prefix:")
        code = """
        import Foundation
        final class Cache {
            func removeAllObjects() {}
            func removeObject(forKey: NSString) {}
        }
        final class Harness: @unchecked Sendable {
            struct Inflight { let task: Task<Int?, Never> }
            let lock = NSLock()
            var inflight: [String: Inflight] = [:]
            var previewKeys: Set<String> = ["roll-a/1"]
            var displayKeys: Set<String> = ["roll-a/1"]
            var negativeKeys: Set<String> = ["roll-a/1"]
            let previews = Cache(), displays = Cache(), negatives = Cache()
            var cancellations = 0
            func purge() { PURGE_BODY }
            func purge(prefix: String) { PREFIX_BODY }
        }
        for prefixOnly in [false, true] {
            let h = Harness()
            let started = DispatchSemaphore(value: 0)
            let task = Task.detached { () -> Int? in
                await withTaskCancellationHandler {
                    started.signal()
                    try? await Task.sleep(for: .seconds(30))
                    return nil
                } onCancel: {
                    h.lock.withLock { h.cancellations += 1 }
                }
            }
            h.inflight["p:roll-a/1"] = Harness.Inflight(task: task)
            await Task.detached { started.wait() }.value
            if prefixOnly { h.purge(prefix: "roll-a") } else { h.purge() }
            _ = await task.value
            assert(h.cancellations == 1 && h.inflight.isEmpty && h.previewKeys.isEmpty)
        }
        print("purge passed")
        """.replace("PURGE_BODY", purge).replace("PREFIX_BODY", prefix)
        self.assertIn("purge passed", self.swift(code))

    def test_repeated_photo_configuration_only_prepares_on_actual_changes(self):
        body = method(source("Camera/CameraSession.swift"), "applyPhotoConfiguration")
        code = """
        import Foundation
        enum AVCapturePhotoOutput {
            enum QualityPrioritization: Equatable { case speed, balanced }
        }
        final class Output {
            var isAppleProRAWSupported = true
            var rawWrites = 0, qualityWrites = 0
            var isAppleProRAWEnabled = false { didSet { rawWrites += 1 } }
            var maxPhotoQualityPrioritization: AVCapturePhotoOutput.QualityPrioritization = .speed {
                didSet { qualityWrites += 1 }
            }
        }
        final class Session { var isRunning = false }
        final class Harness {
            let queue = DispatchQueue(label: "photo-config")
            let photoOutput = Output()
            let session = Session()
            var cameraAvailable = true
            var proRAWEnabled = false
            var prepares = 0
            func prepareCapture() { prepares += 1 }
            func applyPhotoConfiguration() { BODY }
        }
        let h = Harness()
        h.queue.sync {
            h.applyPhotoConfiguration()
            assert(h.prepares == 0 && h.photoOutput.rawWrites == 0)
            h.proRAWEnabled = true
            h.applyPhotoConfiguration()
            assert(h.prepares == 0 && h.photoOutput.rawWrites == 1)
            h.session.isRunning = true
            h.prepareCapture() // requestAndRun prepares once after startRunning.
            for _ in 0..<10 { h.applyPhotoConfiguration() }
            assert(h.prepares == 1 && h.photoOutput.rawWrites == 1)
            h.proRAWEnabled = false
            h.applyPhotoConfiguration()
            assert(h.prepares == 2 && h.photoOutput.rawWrites == 2)
            for _ in 0..<10 { h.applyPhotoConfiguration() }
            assert(h.prepares == 2 && h.photoOutput.qualityWrites == 2)
        }
        print("configuration passed")
        """.replace("BODY", body)
        self.assertIn("configuration passed", self.swift(code))

    def test_unchanged_focus_signals_do_not_enqueue_repeated_ui_work(self):
        body = method(source("Camera/CameraSession.swift"), "publishMacroControl")
        body = body.replace("DispatchQueue.main.async", "publish")
        code = """
        import Foundation
        final class Harness {
            var zoomFactor: CGFloat = 1
            var publishedMacro: (zoom: CGFloat, visible: Bool, locked: Bool)?
            var currentZoom: CGFloat = 1
            var macroControlVisible = false
            var macroLocked = false
            var count = 0
            func publish(_ block: () -> Void) { count += 1; block() }
            func publishMacroControl(visible: Bool, locked: Bool) { BODY }
        }
        let h = Harness()
        for _ in 0..<1000 { h.publishMacroControl(visible: false, locked: false) }
        assert(h.count == 1)
        h.publishMacroControl(visible: true, locked: false)
        h.publishMacroControl(visible: true, locked: true)
        h.zoomFactor = 2
        h.publishMacroControl(visible: true, locked: true)
        assert(h.count == 4 && h.currentZoom == 2 && h.macroLocked)
        for _ in 0..<1000 { h.publishMacroControl(visible: true, locked: true) }
        assert(h.count == 4)
        print("signals passed")
        """.replace("BODY", body)
        self.assertIn("signals passed", self.swift(code))

    def test_url_metadata_export_preserves_pixels_and_metadata(self):
        renderer = source("Film/FilmRenderer.swift").replace(
            "import UIKit", "import Foundation\nimport CoreGraphics"
        )
        stubs = """
        struct Frame { var iso: Float?; var shutter: Double?; var shotAt: Date }
        struct FilmRecipe { var name: String }
        """
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="metadata-quality-", dir=TEMP_ROOT) as directory:
            code = renderer + stubs + """
            let space = CGColorSpace(name: CGColorSpace.displayP3)!
            let context = CGContext(data: nil, width: 32, height: 24,
                bitsPerComponent: 8, bytesPerRow: 32 * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.setFillColor(CGColor(red: 0.7, green: 0.2, blue: 0.4, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
            let image = context.makeImage()!
            let buffer = NSMutableData()
            let destination = CGImageDestinationCreateWithData(buffer, "public.jpeg" as CFString, 1, nil)!
            let properties: [CFString: Any] = [
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifFNumber: 2.8,
                    kCGImagePropertyExifISOSpeedRatings: [400],
                    kCGImagePropertyExifExposureTime: 0.008
                ],
                kCGImageDestinationLossyCompressionQuality: 0.92
            ]
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            assert(CGImageDestinationFinalize(destination))
            let original = buffer as Data
            let url = URL(fileURLWithPath: DIRECTORY).appendingPathComponent("source.jpg")
            try original.write(to: url)
            let baseline = FilmRenderer.stampExport(original, like: original)
            let optimized = FilmRenderer.stampExport(original, likeURL: url)
            func pixels(_ data: Data) -> Data {
                let source = CGImageSourceCreateWithData(data as CFData, nil)!
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
                return image.dataProvider!.data! as Data
            }
            assert(pixels(baseline) == pixels(optimized))
            let old = CGImageSourceCreateWithData(baseline as CFData, nil)!
            let new = CGImageSourceCreateWithData(optimized as CFData, nil)!
            let a = CGImageSourceCopyPropertiesAtIndex(old, 0, nil)! as NSDictionary
            let b = CGImageSourceCopyPropertiesAtIndex(new, 0, nil)! as NSDictionary
            assert(a.isEqual(b))
            print("quality passed")
            """.replace("DIRECTORY", json.dumps(directory))
            self.assertIn("quality passed", self.swift(code))


if __name__ == "__main__":
    unittest.main()
