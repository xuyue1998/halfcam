#!/usr/bin/env python3
"""Check release metadata and an optional local, unsigned Xcode archive.

These checks do not sign, upload, install or validate with App Store Connect.
Run with DEVELOPER_DIR set when xcode-select points to Command Line Tools.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct
import subprocess

import check_copy


ROOT = Path(__file__).resolve().parents[1]
PRIVATE_SELECTORS = (
    b"supportedApertures", b"availableApertureValues",
    b"supportedApertureValues", b"setAperture:",
)


def versions(project):
    builds = re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", project)
    marketing = re.findall(r"MARKETING_VERSION = ([^;]+);", project)
    errors = []
    if len(builds) != 4 or len(set(builds)) != 1:
        errors.append("App/extension Debug/Release build numbers must match")
    if len(marketing) != 4 or len(set(marketing)) != 1:
        errors.append("App/extension Debug/Release marketing versions must match")
    return (marketing[0] if marketing else None, builds[0] if builds else None), errors


def check_icon(data):
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return ["App icon must be a valid PNG"]
    width, height, depth, color, _, _, _ = struct.unpack(">IIBBBBB", data[16:29])
    if (width, height, depth, color) != (1024, 1024, 8, 2):
        return ["Expected the reviewed 1024px, 8-bit RGB app icon without alpha"]
    offset = 8
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"tRNS":
            return ["App icon must not contain transparency"]
        offset += 12 + length
    return []


def check_privacy(manifest):
    """Guard the reviewed local-only data flow, not arbitrary future behavior."""
    errors = []
    if manifest.get("NSPrivacyTracking") is not False or manifest.get("NSPrivacyTrackingDomains") != []:
        errors.append("Privacy manifest differs from the reviewed no-tracking behavior")
    if manifest.get("NSPrivacyCollectedDataTypes") != []:
        errors.append("Review data flow: on-device photos are not collected user content")
    reasons = {
        item["NSPrivacyAccessedAPIType"]: set(item["NSPrivacyAccessedAPITypeReasons"])
        for item in manifest["NSPrivacyAccessedAPITypes"]
    }
    for category, reason in (("UserDefaults", "CA92.1"), ("FileTimestamp", "C617.1")):
        if reason not in reasons.get("NSPrivacyAccessedAPICategory" + category, set()):
            errors.append(f"Missing reviewed required-reason declaration: {category} / {reason}")
    return errors


def uuid_set(text):
    return set(re.findall(r"UUID: ([A-Fa-f0-9-]+) \(([^)]+)\)", text))


def tool(*arguments):
    result = subprocess.run(["xcrun", *arguments], text=True, capture_output=True, timeout=30)
    if result.returncode:
        raise ValueError(result.stderr.strip() or result.stdout.strip())
    return result.stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_archive(archive, version, build):
    errors = []
    facts = {}
    app = archive / "Products/Applications/HalfCam.app"
    bundles = (app, app / "PlugIns/DevelopLive.appex")
    facts["bundles"] = []
    for bundle in bundles:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        if (info["CFBundleShortVersionString"], info["CFBundleVersion"]) != (version, build):
            errors.append(f"{bundle.name}: version differs from source")
        if info.get("MinimumOSVersion") != "17.0" or info.get("UIDeviceFamily") != [1]:
            errors.append(f"{bundle.name}: unexpected supported OS/device family")
        binary = bundle / info["CFBundleExecutable"]
        architectures = tool("lipo", "-archs", str(binary)).strip()
        if architectures != "arm64":
            errors.append(f"{bundle.name}: unexpected release architectures: {architectures}")
        symbols = binary.read_bytes()
        for selector in PRIVATE_SELECTORS:
            if selector in symbols:
                errors.append(f"{bundle.name}: experimental selector present: {selector.decode()}")
        dsym = archive / "dSYMs" / (bundle.name + ".dSYM") / "Contents/Resources/DWARF" / info["CFBundleExecutable"]
        binary_uuids = uuid_set(tool("dwarfdump", "--uuid", str(binary)))
        if not binary_uuids or binary_uuids != uuid_set(tool("dwarfdump", "--uuid", str(dsym))):
            errors.append(f"{bundle.name}: dSYM UUID mismatch")
        catalog_path = "HalfCam/Localizable.xcstrings" if bundle == app else "DevelopLive/Localizable.xcstrings"
        catalog = check_copy.load_json(ROOT / catalog_path)
        for locale in check_copy.LANGUAGES:
            compiled = plistlib.loads((bundle / (locale + ".lproj") / "Localizable.strings").read_bytes())
            for key, entry in catalog["strings"].items():
                if check_copy.is_copy(key, entry):
                    expected = entry["localizations"][locale]["stringUnit"]["value"]
                    if compiled.get(key) != expected:
                        errors.append(f"{bundle.name} / {locale}: compiled copy differs: {key}")
        facts["bundles"].append({
            "name": bundle.name, "identifier": info["CFBundleIdentifier"],
            "version": version, "build": build, "architectures": architectures,
            "dSYM_UUIDs": sorted(value for value, _ in binary_uuids),
            "signaturePresent": (bundle / "_CodeSignature").is_dir(),
        })
    permissions = check_copy.load_json(ROOT / "HalfCam/InfoPlist.xcstrings")
    for locale in check_copy.LANGUAGES:
        compiled = plistlib.loads((app / (locale + ".lproj") / "InfoPlist.strings").read_bytes())
        for key, entry in permissions["strings"].items():
            if check_copy.is_copy(key, entry) and compiled.get(key) != entry["localizations"][locale]["stringUnit"]["value"]:
                errors.append(f"{locale}: compiled permission differs: {key}")
    resources = [(ROOT / "LICENSE", app / "LICENSE.txt"),
                 (ROOT / "LICENSE-SPEKTRAFILM.txt", app / "LICENSE-SPEKTRAFILM.txt"),
                 (ROOT / "HalfCam/PrivacyInfo.xcprivacy", app / "PrivacyInfo.xcprivacy")]
    engine = ROOT / "HalfCam/Resources/engine"
    resources.extend((p, app / "engine" / p.relative_to(engine))
                     for p in engine.rglob("*") if p.is_file() and not p.name.startswith("."))
    for original, packaged in resources:
        if not packaged.is_file() or not packaged.stat().st_size or digest(original) != digest(packaged):
            errors.append(f"Missing, empty or stale packaged resource: {packaged.relative_to(app)}")
    if list(app.rglob("*.storekit")):
        errors.append("Local StoreKit testing configuration included in release app")
    app_info = plistlib.loads((app / "Info.plist").read_bytes())
    if app_info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconName") != "AppIcon":
        errors.append("App icon missing from compiled Info.plist")
    facts["comparedResources"] = len(resources)
    facts["exportComplianceAnswer"] = app_info.get("ITSAppUsesNonExemptEncryption")
    facts["sdk"] = app_info.get("DTSDKName")
    facts["distributionValidated"] = False
    return facts, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = {"checkedAt": datetime.now(timezone.utc).isoformat(), "errors": []}
    errors = report["errors"]
    try:
        (version, build), problems = versions((ROOT / "HalfCam.xcodeproj/project.pbxproj").read_text())
        errors.extend(problems)
        report.update(version=version, build=build)
        manifest = plistlib.loads((ROOT / "HalfCam/PrivacyInfo.xcprivacy").read_bytes())
        errors.extend(check_privacy(manifest))
        errors.extend(check_icon((ROOT / "HalfCam/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()))
        if args.archive:
            report["archive"] = str(args.archive.resolve())
            facts, problems = check_archive(args.archive, version, build)
            report.update(facts)
            errors.extend(problems)
    except (OSError, KeyError, ValueError, plistlib.InvalidFileException, subprocess.TimeoutExpired) as error:
        errors.append(str(error))
    report["passed"] = not errors
    if args.report:
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
