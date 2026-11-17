"""Crash hardening regressions; native bridge tests run on macOS."""

from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

from test_camera_session import method


ROOT = Path(__file__).resolve().parents[1]
CAMERA_DIR = ROOT / "HalfCam" / "Camera"
TEMP_ROOT = Path(os.environ.get("TMPDIR", tempfile.gettempdir())) / "opencode"


class CrashSafetyChecks(unittest.TestCase):
    def test_export_renderers_use_pixel_dimensions(self):
        source = (ROOT / "HalfCam" / "Album" / "PhotoExport.swift").read_text()
        renderer = method(source, "exportRenderer")
        self.assertIn("format.scale = 1", renderer)
        self.assertIn("format.opaque = true", renderer)
        self.assertIn("format.preferredRange = .standard", renderer)
        for name in ("stitch", "strip"):
            body = method(source, name)
            self.assertIn("exportRenderer(size: canvas)", body)
            self.assertNotIn("UIGraphicsImageRenderer(size:", body)
        self.assertIn("autoreleasepool {", method(source, "composeJPEG"))

    @unittest.skipUnless(sys.platform == "darwin" and shutil.which("clang"), "macOS clang required")
    def test_native_aperture_invocation(self):
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="safe-invocation-", dir=TEMP_ROOT) as directory:
            executable = str(Path(directory) / "tests")
            subprocess.run(
                ["clang", "-DDEBUG=1", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation",
                 "-I", str(CAMERA_DIR),
                 str(CAMERA_DIR / "HCSafeInvocation.m"),
                 str(ROOT / "scripts" / "tests" / "safe_invocation_tests.m"),
                 "-o", executable],
                check=True, capture_output=True, text=True,
            )
            result = subprocess.run([executable], check=True, capture_output=True, text=True)
            self.assertIn("exceptions passed", result.stdout)

    @unittest.skipUnless(sys.platform == "darwin" and shutil.which("clang"), "macOS clang required")
    def test_release_bridge_does_not_contain_private_hardware_selectors(self):
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="release-bridge-", dir=TEMP_ROOT) as directory:
            object_file = str(Path(directory) / "bridge.o")
            subprocess.run(
                ["clang", "-fobjc-arc", "-Wall", "-Werror", "-c",
                 str(CAMERA_DIR / "HCSafeInvocation.m"), "-o", object_file],
                check=True, capture_output=True, text=True,
            )
            symbols = subprocess.run(
                ["strings", object_file], check=True, capture_output=True, text=True,
            ).stdout
            self.assertNotIn("setAperture:", symbols)
            self.assertNotIn("valueForKey:", symbols)

    @unittest.skipUnless(shutil.which("swift"), "Swift required")
    def test_legacy_transactions_deduplicate_without_extra_grants(self):
        source = (ROOT / "HalfCam" / "Store" / "Entitlements.swift").read_text()
        match = re.search(r"skipTxCounts = (Dictionary\(legacy\.map[^\n]+)", source)
        self.assertIsNotNone(match)
        # Execute the production migration expression without starting StoreKit.
        expression = match.group(1)
        code = """
        import Foundation
        for legacy: [String] in [[], ["a"], ["a", "a", "b", "a", "b"]] {
            let counts = EXPRESSION
            assert(counts.count == Set(legacy).count)
            assert(counts.values.allSatisfy { $0 == 3 })
        }
        print("Migration passed")
        """.replace("EXPRESSION", expression)
        result = subprocess.run(
            ["swift", "-"], input=code, text=True, capture_output=True, check=True, timeout=60,
        )
        self.assertIn("Migration passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
