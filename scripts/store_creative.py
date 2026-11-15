#!/usr/bin/env python3
"""Render localized App Store header/search artwork using real local captures."""

import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image, ImageDraw, ImageFilter, ImageOps

if __package__:
    from . import store_screenshots as shots
else:
    import store_screenshots as shots


OUTPUT_ROOT = shots.ROOT / "docs/store/creative"
HEADER_SIZE = (3840, 1646)
SEARCH_SIZE = (3840, 2560)
# Apple creative-assets-specifications, coordinates for these exact sizes.
HEADER_SAFE = (1097, 493, 2743, 1154)
SEARCH_SAFE = (836, 765, 3004, 1795)
COPY = {
    "zh-Hans": {
        "category": "半格胶片相机",
        "benefits": ["手动上卷。", "暗房显影。", "对页照片。"],
    },
    "zh-Hant": {
        "category": "半格底片相機",
        "benefits": ["手動過片。", "暗房顯影。", "對頁照片。"],
    },
    "en-US": {
        "category": "Half-frame film camera",
        "benefits": ["Wind by hand.", "Develop a roll.", "Two frames, paired."],
    },
    "ja": {
        "category": "ハーフフィルムカメラ",
        "benefits": ["手で巻き上げ。", "暗室で現像。", "ふたコマを一枚に。"],
    },
    "ko": {
        "category": "하프프레임 필름 카메라",
        "benefits": ["손으로 감고.", "암실에서 현상.", "두 컷을 한 장에."],
    },
}


def inside(rect, boundary):
    return (boundary[0] <= rect[0] <= rect[2] <= boundary[2]
            and boundary[1] <= rect[1] <= rect[3] <= boundary[3])


def background(size, pair):
    # Atmospheric background derived from the same user-provided photo.
    # Only the background is blurred/dimmed; foreground photos stay unchanged.
    photo = ImageOps.fit(pair, size, method=Image.Resampling.LANCZOS)
    photo = photo.filter(ImageFilter.GaussianBlur(90))
    base = Image.new("RGB", size, shots.BG)
    return Image.blend(base, photo, 0.11)


def safe_text(image, value, xy, size, width, locale, boundary, fill=shots.PAPER,
              mono=False):
    draw = ImageDraw.Draw(image)
    font = shots.mono(size) if mono else shots.fitted_font(
        [value], size, locale, max_width=width, minimum=24)
    # Position by visible glyph top-left, not a font-dependent ascender offset.
    bounds = draw.textbbox((0, 0), value, font=font)
    position = (xy[0] - bounds[0], xy[1] - bounds[1])
    bounds = draw.textbbox(position, value, font=font)
    if not inside(bounds, boundary) or bounds[2] - bounds[0] > width:
        raise ValueError(f"{locale}: text outside creative safe area: {value}")
    draw.text(position, value, font=font, fill=fill)
    return bounds


def photo_card(image, photo, xy, width, safe):
    height = round(photo.height * width / photo.width)
    rect = (xy[0], xy[1], xy[0] + width, xy[1] + height)
    if not inside(rect, safe):
        raise ValueError(f"Photo outside safe area: {rect}")
    shots.card(image, photo, xy, width, radius=16)
    return rect


def header(pair, locale):
    image = background(HEADER_SIZE, pair)
    draw = ImageDraw.Draw(image)
    draw.line((1130, 526, 1170, 526), fill=(168, 67, 45), width=5)
    safe_text(image, "HALF CAM", (1190, 505), 44, 600, locale,
              HEADER_SAFE, shots.BRASS, mono=True)
    for i, line in enumerate(shots.COPY[locale]["titles"][0]):
        safe_text(image, line, (1130, 665 + 115 * i), 89, 720,
                  locale, HEADER_SAFE)
    draw.line((1130, 965, 1830, 965), fill=(90, 74, 51), width=2)
    safe_text(image, COPY[locale]["category"], (1130, 1010), 42, 720,
              locale, HEADER_SAFE, shots.MUTED)
    photo_card(image, pair, (1955, 514), 720, HEADER_SAFE)
    return image


def search(pair, camera, locale):
    image = background(SEARCH_SIZE, pair)
    safe_text(image, "HALF CAM", (885, 790), 35, 850, locale,
              SEARCH_SAFE, shots.BRASS, mono=True)
    safe_text(image, COPY[locale]["category"], (885, 870), 90, 850,
              locale, SEARCH_SAFE)
    # The actual localized camera UI, not a generated device mockup.
    camera_crop = camera.crop((0, 185, shots.W, shots.H))
    photo_card(image, camera_crop, (885, 1020), 340, SEARCH_SAFE)
    for i, line in enumerate(COPY[locale]["benefits"]):
        safe_text(image, line, (1300, 1135 + i * 120), 55, 440,
                  locale, SEARCH_SAFE, shots.PAPER if i == 0 else shots.MUTED)
    photo_card(image, pair, (1820, 850), 1080, SEARCH_SAFE)
    safe_text(image, "WIND. SHOOT. WAIT. DEVELOP.", (885, 1740), 26,
              850, locale, SEARCH_SAFE, shots.BRASS, mono=True)
    return image


def render(source, out, locale):
    sources = shots.load_sources(source, locale)
    top = shots.SOURCE_SETS[locale]["pair_tops"][0]
    pair = sources["album"].crop((88, top, 1232, top + 977))
    images = [
        ("01-header-3840x1646.png", header(pair, locale)),
        ("02-search-3840x2560.png", search(pair, sources["camera"], locale)),
    ]
    out.mkdir(parents=True, exist_ok=True)
    for filename, image in images:
        image.save(out / filename, optimize=True)
        print(out / filename)

    # Contact sheet is review-only, not an upload asset.
    preview = Image.new("RGB", (1500, 600), (231, 226, 216))
    for x, (filename, image), width in [
        (24, images[0], 840), (900, images[1], 576)
    ]:
        thumb = ImageOps.contain(image, (width, 480),
                                 method=Image.Resampling.LANCZOS)
        preview.paste(thumb, (x, 76))
        ImageDraw.Draw(preview).text(
            (x, 24), "HEADER / 3840 x 1646" if x == 24 else "SEARCH / 3840 x 2560",
            font=shots.mono(24), fill=(35, 31, 25))
    preview.save(out / "_preview.jpg", quality=94)
    with ZipFile(out / f"HALF-CAM-{locale}-creative.zip", "w",
                 compression=ZIP_DEFLATED) as archive:
        for filename, _ in images:
            archive.write(out / filename, arcname=filename)


def bundle(root, locales):
    path = root / "HALF-CAM-creative-5-languages.zip"
    with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
        for locale in locales:
            for name in ("01-header-3840x1646.png", "02-search-3840x2560.png"):
                archive.write(root / locale / name, arcname=f"{locale}/{name}")
    print(path)
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=shots.ROOT / "商店页")
    parser.add_argument("--output", type=Path, default=OUTPUT_ROOT)
    parser.add_argument("--locale", choices=[*COPY, "all"], default="all")
    args = parser.parse_args()
    locales = list(COPY) if args.locale == "all" else [args.locale]
    for locale in locales:
        render(args.source, args.output / locale, locale)
    if args.locale == "all":
        bundle(args.output, locales)
