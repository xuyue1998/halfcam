#!/usr/bin/env python3
"""Check user-facing copy and print a five-language inventory without changing files."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("zh-Hans", "zh-Hant", "en", "ja", "ko")
CATALOGS = (
    "HalfCam/Localizable.xcstrings",
    "HalfCam/InfoPlist.xcstrings",
    "DevelopLive/Localizable.xcstrings",
)
HAN = re.compile(r"[\u3400-\u9fff]")
FORMAT = re.compile(r"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(lld|llu|ld|lu|d|i|u|f|g|@)")
NON_COPY_KEYS = {
    "›", "/%@", "%lld", "%lld/%lld", "38°C", "135", "A", "F", "HALFCAM", "ISO %lld", "M",
    "CFBundleDisplayName", "CFBundleName",
}
SWIFT_LOOKUP = re.compile(r'\bL\s*\(\s*"((?:\\.|[^"\\])*)"')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key!r}")
        result[key] = value
    return result


def load_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_object)


def placeholders(value):
    """Normalize positional placeholders without changing their argument types.

    >>> placeholders("%lld rolls · %@")
    [(1, 'lld'), (2, '@')]
    >>> placeholders("%2$@ · %1$lld rolls")
    [(1, 'lld'), (2, '@')]
    >>> placeholders("%2$lld · %1$@") == placeholders("%lld · %@")
    False
    >>> placeholders("100%% · %lld")
    [(1, 'lld')]
    """
    arguments = []
    implicit = 1
    for match in FORMAT.finditer(value.replace("%%", "")):
        position, kind = match.groups()
        arguments.append((int(position) if position else implicit, kind))
        implicit += 1
    return sorted(arguments)


def is_copy(key, entry):
    # Meter markings, product names and format-only strings are not translatable prose.
    return (
        entry.get("extractionState") != "stale"
        and key not in NON_COPY_KEYS
    )


def check_catalog(path):
    catalog = load_json(path)
    errors = []
    rows = []
    for key, entry in catalog["strings"].items():
        if not is_copy(key, entry):
            continue
        values = {}
        for language in LANGUAGES:
            unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
            value = unit.get("value", "")
            values[language] = value
            label = f"{path.relative_to(ROOT)} / {key!r} / {language}"
            if not value.strip() or unit.get("state") != "translated":
                errors.append(f"{label}: missing or unreviewed translation")
            if placeholders(value) != placeholders(key):
                errors.append(f"{label}: placeholder arguments do not match")
            if language == "en" and re.search(r"\b(?:dump\w*|undumped)\b", value, re.I):
                errors.append(f"{label}: use export / save, not dump")
            if language.startswith("zh") and re.search(r"倒出|倒走|清掉", value):
                errors.append(f"{label}: use 导出 / 匯出 or 删除 / 刪除")
        rows.append((str(path.relative_to(ROOT)), key, values))
    return catalog, rows, errors


def check_subtitles(catalog):
    text = (ROOT / "HalfCam/Film/FilmCatalog.swift").read_text()
    subtitles = set(re.findall(r'subtitle: "([^"]+)"', text))
    errors = []
    for key in sorted(subtitles):
        entry = catalog["strings"].get(key, {})
        if entry.get("extractionState") != "manual":
            errors.append(f"Film subtitle {key!r}: must be registered as manual")
    return errors


def swift_template(raw):
    r"""Turn a Swift lookup literal into a template, including nested interpolation.

    >>> swift_template(r"已送进暗房 · 约 \(Int(ceil(seconds))) 秒")
    '已送进暗房 · 约 {} 秒'
    >>> swift_template(r"\(rolls) 卷 · 未倒 \(frames)")
    '{} 卷 · 未倒 {}'
    >>> swift_template(r"Line one\nLine two")
    'Line one\nLine two'
    """
    result = []
    i = 0
    escapes = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
    while i < len(raw):
        if raw.startswith(r"\(", i):
            depth = 1
            i += 2
            while i < len(raw) and depth:
                if raw[i] == "(":
                    depth += 1
                elif raw[i] == ")":
                    depth -= 1
                i += 1
            if depth:
                raise ValueError(f"Unclosed Swift interpolation: {raw!r}")
            result.append("{}")
        elif raw[i] == "\\" and i + 1 < len(raw):
            result.append(escapes.get(raw[i + 1], raw[i:i + 2]))
            i += 2
        else:
            result.append(raw[i])
            i += 1
    return "".join(result)


def check_references(source, catalog, label):
    templates = {}
    for key, entry in catalog["strings"].items():
        template = FORMAT.sub("{}", key)
        templates.setdefault(template, []).append(entry)
    errors = []
    for match in SWIFT_LOOKUP.finditer(source):
        template = swift_template(match.group(1))
        entries = templates.get(template, [])
        line = source.count("\n", 0, match.start()) + 1
        if not entries:
            errors.append(f"{label}:{line}: lookup not registered: {template!r}")
        elif all(entry.get("extractionState") == "stale" for entry in entries):
            errors.append(f"{label}:{line}: live lookup incorrectly marked stale: {template!r}")
    return errors


def check_storekit():
    store = load_json(ROOT / "HalfCam.storekit")
    groups = store["subscriptionGroups"]
    products = store["products"] + [
        product for group in groups for product in group["subscriptions"]
    ]
    errors = []
    expected = Counter(("zh_CN", "zh_TW", "en_US", "ja", "ko"))
    for item in products + groups:
        label = item.get("productID", item.get("name"))
        locales = Counter(value["locale"] for value in item["localizations"])
        if locales != expected:
            errors.append(f"StoreKit {label}: each of the five locales is required once")
        for value in item["localizations"]:
            if not value["displayName"] or not value["description"]:
                errors.append(f"StoreKit {label} / {value['locale']}: empty copy")
        if item in products:
            errors.extend(check_product_copy(item))
    return errors


def check_product_copy(product):
    """Check current App Store Connect localizable IAP field limits.

    Source checked November 17, 2026:
    developer.apple.com/help/app-store-connect/reference/
    in-app-purchases-and-subscriptions/in-app-purchase-information/
    """
    errors = []
    for value in product["localizations"]:
        label = f"StoreKit {product['productID']} / {value['locale']}"
        if not 2 <= len(value["displayName"]) <= 30:
            errors.append(f"{label}: display name must be 2–30 characters")
        if len(value["description"]) > 45:
            errors.append(f"{label}: description must be at most 45 characters")
    return errors


def check_permission_fallbacks(catalog):
    """Keep Debug/Release Info.plist fallbacks aligned with reviewed Chinese."""
    project = (ROOT / "HalfCam.xcodeproj/project.pbxproj").read_text()
    errors = []
    for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
                "NSPhotoLibraryAddUsageDescription"):
        expected = catalog["strings"][key]["localizations"]["zh-Hans"]["stringUnit"]["value"]
        values = re.findall(r"INFOPLIST_KEY_" + key + r' = "([^"]*)";', project)
        if len(values) != 2 or any(value != expected for value in values):
            errors.append(f"{key}: Debug/Release fallback differs from reviewed Chinese")
    return errors


def cell(value):
    return value.replace("|", r"\|").replace("\n", "<br>")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", action="store_true", help="print all live copy as Markdown")
    args = parser.parse_args()
    errors = []
    rows = []
    catalogs = {}
    try:
        for name in CATALOGS:
            catalog, entries, problems = check_catalog(ROOT / name)
            catalogs[name] = catalog
            rows.extend(entries)
            errors.extend(problems)
        errors.extend(check_subtitles(catalogs[CATALOGS[0]]))
        for path in sorted((ROOT / "HalfCam").rglob("*.swift")):
            errors.extend(check_references(
                path.read_text(), catalogs[CATALOGS[0]], str(path.relative_to(ROOT))
            ))
        errors.extend(check_storekit())
        errors.extend(check_permission_fallbacks(catalogs[CATALOGS[1]]))
    except (ValueError, KeyError, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    if args.inventory:
        print("| 文案表 | 引用键（不是显示文案） | " + " | ".join(LANGUAGES) + " |")
        print("|---|---|" + "---|" * len(LANGUAGES))
        for name, key, values in rows:
            print("| " + " | ".join(map(cell, (name, key, *(values[l] for l in LANGUAGES)))) + " |")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(
        f"OK: {len(rows)} live text entries, five languages, matching placeholders, "
        "source lookups, film subtitles and StoreKit locales.",
        file=sys.stderr if args.inventory else sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
