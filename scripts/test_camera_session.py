"""Source-level guards for the Build 12 capture-session ownership regression.

These checks do not replace camera lifecycle testing on a physical iPhone.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
CAMERA = ROOT / "HalfCam" / "Camera" / "CameraSession.swift"
VIEWFINDER = ROOT / "HalfCam" / "Camera" / "ViewfinderView.swift"


def method(source, name):
    """Return a Swift function, including its nested closure bodies."""
    match = re.search(r"\bfunc " + re.escape(name) + r"\(", source)
    if not match:
        raise AssertionError(f"Missing method: {name}")
    start = source.index("{", match.end())
    depth = 1
    for end in range(start + 1, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if depth == 0:
            return source[start + 1:end]
    raise AssertionError(f"Unclosed method: {name}")


class CameraSessionOwnershipChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camera = CAMERA.read_text()
        cls.viewfinder = VIEWFINDER.read_text()

    def test_capture_session_is_not_exposed_to_ui(self):
        self.assertIn("private let session = AVCaptureSession()", self.camera)
        self.assertNotIn("AVCaptureSession", self.viewfinder)
        self.assertNotRegex(self.viewfinder, r"\.preview\.session\b")
        self.assertNotRegex(self.viewfinder, r"\.preview\.connection\b")

    def test_preview_attachment_and_detachment_are_queued(self):
        for name, assignment in (
            ("attachPreviewLayer", "layer.session = self.session"),
            ("detachPreviewLayer", "layer.session = nil"),
        ):
            with self.subTest(method=name):
                body = method(self.camera, name)
                queued = body.index("queue.async {")
                mutation = body.index(assignment)
                self.assertLess(queued, mutation)
                self.assertGreater(body.rfind("}"), mutation)

    def test_internal_session_operations_assert_queue_ownership(self):
        for name in ("requestAndRun", "configureIfNeeded", "switchTo", "orientPreviewLayers"):
            with self.subTest(method=name):
                self.assertIn(
                    "dispatchPrecondition(condition: .onQueue(queue))",
                    method(self.camera, name),
                )

    def test_capture_is_serialized_with_configuration(self):
        body = method(self.camera, "capture")
        queued = body.index("queue.async {")
        self.assertLess(queued, body.index("self.session.isRunning"))
        self.assertLess(queued, body.index("self.photoOutput.capturePhoto("))

    def test_preview_lifecycle_uses_camera_owner(self):
        self.assertIn("session.attachPreviewLayer(v.preview)", self.viewfinder)
        self.assertIn(
            "coordinator.session.detachPreviewLayer(uiView.preview)",
            method(self.viewfinder, "dismantleUIView"),
        )
        self.assertIn(".id(ObjectIdentifier(session))", self.viewfinder)
        self.assertIn("let session: CameraSession", self.viewfinder)

    def test_orientation_is_restored_after_configuration(self):
        # Connections can be created/replaced during initial setup or lens switches.
        for name in ("configureIfNeeded", "switchTo"):
            with self.subTest(method=name):
                body = method(self.camera, name)
                commits = re.findall(
                    r"session\.commitConfiguration\(\)\s+orientPreviewLayers\(\)",
                    body,
                )
                self.assertEqual(len(commits), body.count("session.commitConfiguration()"))

    def test_configuration_lock_failures_are_not_ignored(self):
        self.assertNotRegex(self.camera, r"try\?\s+\w+\.lockForConfiguration\(\)")
        for name, device in (("configureIfNeeded", "cam"), ("unlockFocus", "device")):
            body = method(self.camera, name)
            self.assertIn(f"try {device}.lockForConfiguration()", body)
            self.assertIn(f"defer {{ {device}.unlockForConfiguration() }}", body)

    def test_control_mutations_belong_to_session_queue(self):
        mutations = {
            "setEV": ("savedEV", "pendingEVFactor"),
            "applyAuto": ("exposureLocked", "focusLocked", "pendingShutter",
                          "pendingISO", "pendingLens", "pendingEVFactor", "lastFocusPoint"),
            "applyMixed": ("exposureLocked", "pendingShutter", "pendingISO", "pendingEVFactor"),
            "unlockFocus": ("focusLocked", "pendingLens"),
            "setManualFocus": ("focusLocked", "pendingLens"),
            "setFlash": ("flashOn",),
            "setSavedEV": ("savedEV",),
        }
        for name, fields in mutations.items():
            body = method(self.camera, name)
            queued = body.index("queue.async {")
            for field in fields:
                with self.subTest(method=name, field=field):
                    match = re.search(r"\b(?:self\.)?" + field + r"\s*=", body)
                    self.assertIsNotNone(match)
                    self.assertGreater(match.start(), queued)

    def test_hardware_controls_are_private_and_meter_is_locked(self):
        for field in ("savedEV", "flashOn", "exposureLocked", "focusLocked"):
            self.assertRegex(self.camera, r"@ObservationIgnored private var " + field + r"\b")
        self.assertIn("var lastMeter: Meter { lock.withLock { meterSnapshot } }", self.camera)
        self.assertIn("self.lock.withLock { self.meterSnapshot = meter }", self.camera)

    def test_dynamic_aperture_uses_checked_bridge(self):
        self.assertIn("HCSetApertureSafely(device, value)", self.camera)
        self.assertIn("HCValueForKeySafely(object, key)", self.camera)
        self.assertNotIn("device.perform(", self.camera)


if __name__ == "__main__":
    unittest.main()
