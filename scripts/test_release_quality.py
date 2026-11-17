"""Release regressions.

Runtime tests execute production Foundation-only method bodies in small Swift
harnesses. They do not replace iPhone camera, Photos, GPU or StoreKit testing.
"""

from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import unittest

from test_camera_session import method
from test_crash_safety import TEMP_ROOT


ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / "HalfCam" / path).read_text()


def block(text, marker):
    start = text.index("{", text.index(marker))
    depth = 1
    for end in range(start + 1, len(text)):
        depth += (text[end] == "{") - (text[end] == "}")
        if depth == 0:
            return text[start + 1:end]
    raise AssertionError(marker)


class ReleaseQualityChecks(unittest.TestCase):
    def test_photo_counter_changes_only_after_successful_write(self):
        body = method(source("AppModel.swift"), "commitShot")
        self.assertLess(body.index("await Task.detached"), body.index("guard saved else"))
        self.assertLess(body.index("guard saved else"), body.index("live.frames.append"))
        self.assertIn("live.id == rollId", body)
        self.assertIn("live.shotCount == roll.shotCount", body)
        self.assertNotIn("pendingWrites", source("AppModel.swift"))

    def test_roll_mutations_are_blocked_during_capture(self):
        text = source("AppModel.swift")
        for name in ("wind", "rewind", "forceUnload", "loadRoll", "resetOnboardingForTest"):
            with self.subTest(method=name):
                self.assertIn("!isCapturing", method(text, name))

    def test_capture_delegates_are_request_scoped(self):
        text = source("Camera/CameraSession.swift")
        self.assertIn("guard activeCaptureID == id", method(text, "finishCapture"))
        self.assertIn("let id = photo.resolvedSettings.uniqueID", text)
        self.assertIn("self.capturedPhotoData = data", text)
        self.assertIn("failed ? nil : self.capturedPhotoData", text)
        self.assertIn("self.queue.asyncAfter(deadline: .now() + 60", text)
        self.assertIn("self.wantsRunning = false", method(text, "stop"))
        self.assertIn("self.wantsRunning else", method(text, "requestAndRun"))

    def test_real_devices_do_not_save_simulator_photos(self):
        body = method(source("Camera/CameraSession.swift"), "capture")
        self.assertIn("#if targetEnvironment(simulator)", body)
        self.assertIn("#else\n                    cont.resume(returning: nil)", body)

    def test_failed_development_does_not_become_success(self):
        text = source("AppModel.swift")
        body = method(text, "runDevelop")
        self.assertNotIn("developProgress = 1", body)
        self.assertIn("developFailedRollIDs.insert(id)", body)
        self.assertIn("frameId: frame.id", body)
        self.assertNotIn("frames[i]", body)
        self.assertIn("finished.frames.allSatisfy", method(text, "finishRitual"))
        engine = method(source("Film/SpektraEngine.swift"), "develop")
        self.assertNotIn("positive: thumb", engine)
        self.assertIn('guard let positive = reprint(session, tier: "full") else { return nil }', engine)

    def test_export_generation_is_bounded_and_checks_missing_frames(self):
        text = source("AppModel.swift")
        body = method(text, "flushDumpGroups")
        self.assertIn("jobs.count == PhotoExport.batchSize", body)
        self.assertIn("jobs.removeAll(keepingCapacity: true)", body)
        self.assertIn("urls.count == ready.count", body)
        self.assertIn("if failed { return .failed }", body)
        self.assertIn("images.count == urls.count", source("Album/PhotoExport.swift"))

    def test_limited_library_and_new_exports_are_not_treated_as_deleted(self):
        body = method(source("AppModel.swift"), "reconcileExportedPrints")
        self.assertNotIn("requestAuthorization", body)
        self.assertIn("authorizationStatus(for: .readWrite) == .authorized", body)
        self.assertIn("!checked.contains($0) || live.contains($0)", body)

    def test_crypto_never_replaces_an_inaccessible_key(self):
        text = source("Film/FrameCrypto.swift")
        self.assertNotIn("SecItemDelete", text)
        self.assertIn("key(createIfMissing: false)", method(text, "open"))
        self.assertIn("status == errSecItemNotFound", method(text, "key"))
        self.assertIn("errSecDuplicateItem", text)
        self.assertIn("defer { lock.unlock() }", method(text, "key"))

    def test_unreadable_store_is_preserved_and_backed_up(self):
        text = source("AppModel.swift")
        self.assertIn("guard !persistenceReadFailed else { return }", method(text, "persist"))
        self.assertIn("store.backup.json", method(text, "persist"))
        self.assertIn("store.backup.json", method(text, "load"))
        self.assertIn("persistenceReadFailed = true", method(text, "load"))
        self.assertIn("model.flushPersistence()", source("HalfCamApp.swift"))

    def test_storekit_reentry_refunds_and_unfinished_purchases(self):
        text = source("Store/Entitlements.swift")
        self.assertIn("guard !purchasing", method(text, "buy"))
        self.assertIn("guard !purchasing", method(text, "restore"))
        self.assertIn("guard !refreshing", method(text, "refresh"))
        self.assertIn("pendingSkipGrant != 0", text)
        self.assertNotIn("trim(&skipRevokedIds)", text)
        reconcile = method(text, "reconcileSkipTransactions")
        self.assertLess(reconcile.index("Transaction.unfinished"), reconcile.index("Transaction.all"))

    def test_notification_callbacks_do_not_transfer_framework_objects_to_main(self):
        text = source("HalfCamApp.swift")
        self.assertEqual(text.count("nonisolated func userNotificationCenter("), 2)
        self.assertIn("pendingDarkboxOpen = true", text)

    def test_image_inflight_generation_survives_purge(self):
        text = source("AppModel.swift")
        body = method(text, "start")
        self.assertIn("nextGeneration &+= 1", body)
        self.assertNotIn("(inflight[key]?.gen ?? 0) + 1", body)
        self.assertIn("task.cancel()", method(text, "purge"))

    def test_focus_position_is_not_written_as_exif_aperture(self):
        body = method(source("Film/FilmRenderer.swift"), "writeMetadata")
        self.assertNotIn("exif[kCGImagePropertyExifFNumber] = lens", body)
        self.assertIn("iso.isFinite", body)
        self.assertIn("shutter.isFinite", body)


@unittest.skipUnless(shutil.which("swift"), "Swift required")
class NativeReleaseRegressions(unittest.TestCase):
    def swift(self, code):
        result = subprocess.run(
            ["swift", "-"], input=code, text=True, capture_output=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def test_capture_completion_ignores_duplicate_and_stale_ids(self):
        body = method(source("Camera/CameraSession.swift"), "finishCapture")
        code = """
        import Foundation
        final class Completion {
            var count = 0
            var data: Data?
            func resume(returning data: Data?) { count += 1; self.data = data }
        }
        final class Harness {
            let queue = DispatchQueue(label: "test.capture")
            var activeCaptureID: Int64?
            var continuation: Completion?
            var committed: (@MainActor @Sendable () -> Void)?
            var capturedPhotoData: Data?
            var captureTimeout: DispatchWorkItem?
            func finishCapture(_ data: Data?, id: Int64) { BODY }
        }
        let h = Harness()
        h.queue.sync {
            let first = Completion()
            h.activeCaptureID = 1; h.continuation = first
            h.finishCapture(nil, id: 999)
            assert(first.count == 0 && h.activeCaptureID == 1)
            h.finishCapture(Data([1, 2]), id: 1)
            assert(first.count == 1 && first.data == Data([1, 2]))
            h.finishCapture(nil, id: 1)
            assert(first.count == 1)
            let second = Completion()
            h.activeCaptureID = 2; h.continuation = second
            h.finishCapture(nil, id: 1)
            assert(second.count == 0 && h.activeCaptureID == 2)
            h.finishCapture(nil, id: 2)
            assert(second.count == 1 && h.activeCaptureID == nil)
        }
        print("capture passed")
        """.replace("BODY", body)
        self.assertIn("capture passed", self.swift(code))

    def test_cancelled_export_wait_does_not_spin_or_acquire_the_lock(self):
        body = method(source("AppModel.swift"), "beginExport")
        code = """
        import Foundation
        @MainActor final class Gate {
            var exportBusy = true
            func beginExport() async -> Bool { BODY }
        }
        let gate = await MainActor.run { Gate() }
        let cancelled = Task { @MainActor in await gate.beginExport() }
        cancelled.cancel()
        let result = await cancelled.value
        assert(!result)
        await MainActor.run { gate.exportBusy = false }
        let acquired = await gate.beginExport()
        assert(acquired)
        print("cancel passed")
        """.replace("BODY", body)
        self.assertIn("cancel passed", self.swift(code))

    def test_raster_dimensions_reject_invalid_values_without_allocation(self):
        body = method(source("Film/Ingest.swift"), "rasterSize")
        code = """
        import Foundation
        import CoreGraphics
        func rasterSize(_ rect: CGRect) -> (Int, Int)? { BODY }
        assert(rasterSize(CGRect(x: 0, y: 0, width: 4032, height: 3024))!.0 == 4032)
        for rect in [
            CGRect.zero, CGRect.infinite, CGRect.null,
            CGRect(x: 0, y: 0, width: CGFloat.nan, height: 1),
            CGRect(x: CGFloat.infinity, y: 0, width: 1, height: 1),
            CGRect(x: 0, y: 0, width: 1e30, height: 2),
            CGRect(x: 0, y: 0, width: 8192, height: 8192),
            CGRect(x: 0, y: 0, width: 0.1, height: 0.1)
        ] {
            assert(rasterSize(rect) == nil)
        }
        print("dimensions passed")
        """.replace("BODY", body)
        self.assertIn("dimensions passed", self.swift(code))

    def test_capture_file_write_reports_failure_and_preserves_existing_files(self):
        body = method(source("AppModel.swift"), "writeCaptureData")
        # File protection is iOS-specific; exercise the actual directory/atomic-write
        # logic on macOS without changing the production iOS protection policy.
        body = body.replace("[.atomic, .completeFileProtection]", "[.atomic]")
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="capture-write-", dir=TEMP_ROOT) as directory:
            code = """
            import Foundation
            func write(_ data: Data, to url: URL) throws { BODY }
            let root = URL(fileURLWithPath: DIRECTORY)
            let blocked = root.appendingPathComponent("existing-file")
            try Data([9]).write(to: blocked)
            var failed = false
            do { try write(Data([1]), to: blocked.appendingPathComponent("photo.neg")) }
            catch { failed = true }
            assert(failed)
            let original = try Data(contentsOf: blocked)
            assert(original == Data([9]))
            let photo = root.appendingPathComponent("roll/photo.neg")
            try write(Data([1, 2, 3]), to: photo)
            let saved = try Data(contentsOf: photo)
            assert(saved == Data([1, 2, 3]))
            print("writes passed")
            """.replace("BODY", body).replace("DIRECTORY", json.dumps(directory))
            self.assertIn("writes passed", self.swift(code))

    def test_image_header_checks_accept_nonzero_based_data_slices(self):
        raw = method(source("Film/Ingest.swift"), "isRAW")
        plain = method(source("Film/FrameCrypto.swift"), "looksPlain")
        code = """
        import Foundation
        func isRAW(_ data: Data) -> Bool { RAW_BODY }
        func looksPlain(_ data: Data) -> Bool { PLAIN_BODY }
        let prefix: [UInt8] = [0, 1, 2, 3]
        let jpeg = Data(prefix + [0xff, 0xd8] + Array(repeating: 0, count: 10)).dropFirst(4)
        assert(jpeg.startIndex != 0)
        assert(!isRAW(jpeg) && looksPlain(jpeg))
        let png = Data(prefix + [0x89, 0x50, 0x4e, 0x47] + Array(repeating: 0, count: 8)).dropFirst(4)
        assert(!isRAW(png) && looksPlain(png))
        assert(!isRAW(Data()) && !looksPlain(Data()))
        print("headers passed")
        """.replace("RAW_BODY", raw).replace("PLAIN_BODY", plain)
        self.assertIn("headers passed", self.swift(code))

    def test_engine_initialization_and_warmup_are_serialized(self):
        text = source("Film/SpektraEngine.swift")
        ready = method(text, "readyLocked")
        warmup = method(text, "warmUp")
        available = block(text, "var isAvailable: Bool")
        code = """
        import Foundation
        final class Counter: @unchecked Sendable {
            let lock = NSLock()
            var creates = 0
            var active = 0
            var peak = 0
            func enter() { lock.withLock { active += 1; peak = max(peak, active) } }
            func leave() { lock.withLock { active -= 1 } }
        }
        let counter = Counter()
        func hc_spk_ready(_ path: UnsafePointer<CChar>, _ device: UnsafeMutableRawPointer?) -> Int32 {
            counter.enter(); defer { counter.leave() }
            counter.lock.withLock { counter.creates += 1 }
            Thread.sleep(forTimeInterval: 0.025)
            return 1
        }
        func hc_spk_warm_up(_ f: UnsafePointer<CChar>, _ p: UnsafePointer<CChar>) -> Int32 {
            counter.enter(); defer { counter.leave() }
            Thread.sleep(forTimeInterval: 0.002)
            return 0
        }
        final class Engine: @unchecked Sendable {
            let lock = NSLock()
            var cachedReady: Bool?
            let metalDevice: NSObject? = nil
            func resourcesDir() -> String { "/unused" }
            var isAvailable: Bool { AVAILABLE }
            func readyLocked() -> Bool { READY }
            func warmUp(film: String, paper: String) { WARMUP }
        }
        let engine = Engine()
        DispatchQueue.concurrentPerform(iterations: 32) { i in
            if i % 2 == 0 { engine.warmUp(film: "f", paper: "p") }
            else { assert(engine.isAvailable) }
        }
        assert(counter.creates == 1 && counter.peak == 1)
        print("engine passed")
        """.replace("AVAILABLE", available).replace("READY", ready).replace("WARMUP", warmup)
        self.assertIn("engine passed", self.swift(code))


if __name__ == "__main__":
    unittest.main()
