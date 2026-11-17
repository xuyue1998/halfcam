"""Local release checks; these are not device or App Store validation tests."""

import plistlib
import struct
import unittest

import check_release


class ReleaseMetadataChecks(unittest.TestCase):
    def test_source_metadata_and_privacy_pass(self):
        root = check_release.ROOT
        (_, build), errors = check_release.versions((root / "HalfCam.xcodeproj/project.pbxproj").read_text())
        self.assertEqual(errors, [])
        self.assertTrue(build.isdigit())
        manifest = plistlib.loads((root / "HalfCam/PrivacyInfo.xcprivacy").read_bytes())
        self.assertEqual(check_release.check_privacy(manifest), [])
        self.assertEqual(check_release.check_icon((root / "HalfCam/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()), [])

    def test_mismatched_extension_build_is_rejected(self):
        project = "CURRENT_PROJECT_VERSION = 13;\n" * 3 + "CURRENT_PROJECT_VERSION = 12;\n"
        project += "MARKETING_VERSION = 1.0;\n" * 4
        self.assertEqual(len(check_release.versions(project)[1]), 1)

    def test_missing_build_configuration_is_rejected(self):
        self.assertEqual(len(check_release.versions("")[1]), 2)

    def test_alpha_and_transparency_are_rejected(self):
        header = b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR"
        opaque = header + struct.pack(">IIBBBBB", 1024, 1024, 8, 2, 0, 0, 0) + b"\0" * 4
        alpha = header + struct.pack(">IIBBBBB", 1024, 1024, 8, 6, 0, 0, 0) + b"\0" * 4
        self.assertEqual(check_release.check_icon(opaque), [])
        self.assertTrue(check_release.check_icon(alpha))
        self.assertTrue(check_release.check_icon(opaque + struct.pack(">I", 0) + b"tRNS" + b"\0" * 4))
        self.assertTrue(check_release.check_icon(b"not a PNG"))

    def test_on_device_content_is_not_misdeclared_as_collected(self):
        manifest = plistlib.loads((check_release.ROOT / "HalfCam/PrivacyInfo.xcprivacy").read_bytes())
        manifest["NSPrivacyCollectedDataTypes"] = [{"NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeOtherUserContent"}]
        self.assertTrue(check_release.check_privacy(manifest))

    def test_dsym_uuid_comparison_includes_architecture(self):
        first = "UUID: 68B0A3A5-97FC-3777-8B0F-8DA1E7011F45 (arm64) /path/app"
        self.assertEqual(check_release.uuid_set(first), check_release.uuid_set(first.replace("/path/app", "/path/symbols")))
        self.assertNotEqual(check_release.uuid_set(first), check_release.uuid_set(first.replace("(arm64)", "(x86_64)")))


if __name__ == "__main__":
    unittest.main()
