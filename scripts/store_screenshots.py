#!/usr/bin/env python3
"""Typeset local, real HALF CAM captures. Never downloads or redraws photos."""

from pathlib import Path
import argparse
import unicodedata
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
W, H = 1320, 2868
OUTPUT_SIZE = (1206, 2622)
OUTPUT_TAG = "1206x2622"
OUTPUT_VERSION = "v4"
BG = (17, 16, 14)
PAPER = (244, 237, 223)
BRASS = (188, 158, 111)
MUTED = (157, 149, 135)
SERIF = "/System/Library/Fonts/Supplemental/Songti.ttc"
MONO = "/System/Library/Fonts/Menlo.ttc"
OUTPUT_ROOT = ROOT / "docs/store/screenshots"
SOURCE_SETS = {
    "zh-Hans": {
        "folder": "简体中文",
        "files": {
            "album": "对页成片.PNG",
            "camera": "相机取景.PNG",
            "load": "未显影胶片.PNG",
            "wait": "暗房.PNG",
            "develop": "IMG_7661.PNG",
        },
        "pair_tops": (611, 1779),
        "wait_bottom": 1000,
    },
    "zh-Hant": {
        "folder": "繁体中文",
        "files": {
            "camera": "IMG_7663.PNG", "load": "IMG_7664.PNG",
            "album": "IMG_7665.PNG", "wait": "IMG_7666.PNG",
            "develop": "IMG_7667.PNG",
        },
        "pair_tops": (579, 1747),
        "wait_bottom": 850,
    },
    "en-US": {
        "folder": "英语",
        "files": {
            "camera": "IMG_7668.PNG", "load": "IMG_7669.PNG",
            "album": "IMG_7670.PNG", "wait": "IMG_7671.PNG",
            "develop": "IMG_7672.PNG",
        },
        "pair_tops": (555, 1723),
        "wait_bottom": 850,
    },
    "ja": {
        "folder": "日语",
        "files": {
            "camera": "IMG_7673.PNG", "load": "IMG_7674.PNG",
            "album": "IMG_7675.PNG", "wait": "IMG_7676.PNG",
            "develop": "IMG_7677.PNG",
        },
        "pair_tops": (650, 1818),
        "wait_bottom": 850,
    },
    "ko": {
        "folder": "韩语",
        "files": {
            "camera": "IMG_7678.PNG", "load": "IMG_7679.PNG",
            "album": "IMG_7680.PNG", "wait": "IMG_7681.PNG",
            "develop": "IMG_7682.PNG",
        },
        "pair_tops": (563, 1731),
        "wait_bottom": 850,
    },
}
LABELS = [
    "LITTLE MOMENTS, SIDE BY SIDE.",
    "A CAMERA IN YOUR POCKET.",
    "PICK A ROLL. GO OUTSIDE.",
    "A LITTLE WAIT, A LITTLE WONDER.",
    "THE DARKROOM, IN YOUR HAND.",
]
COPY = {
    "zh-Hans": {
        "titles": [
            ["两格照片，", "装下一段日常。"],
            ["从装一卷开始，", "把今天慢慢拍下来。"],
            ["选一卷，", "带着它出门。"],
            ["照片先存着，", "期待慢慢来。"],
            ["这一卷，", "会洗出什么？"],
        ],
        "subtitles": [
            "相邻两格，组成一张对页。",
            "手动上卷，把拍照变回一件不着急的事。",
            "彩色、反转、电影、黑白，留住不同的心情。",
            "留一点时间，等这一卷的故事显影。",
            "从倒片到显影，再到照片慢慢揭晓。",
        ],
        "wait": ["不必每拍一张，就停下来检查。", "等显影的时候，再一起回看。"],
        "rush": "也可以使用加急券，早点揭晓。",
        "closing": ["拍的时候，专心生活。", "显影的时候，再看这一卷。"],
    },
    "zh-Hant": {
        "titles": [
            ["兩格照片，", "裝下一段日常。"],
            ["從裝一卷開始，", "把今天慢慢拍下來。"],
            ["選一卷，", "帶著它出門。"],
            ["照片先留著，", "期待慢慢來。"],
            ["這一卷，", "會洗出什麼？"],
        ],
        "subtitles": [
            "相鄰兩格，組成一張對頁。",
            "手動過片，讓拍照變回一件不著急的事。",
            "彩色、正片、電影、黑白，留下不同的心情。",
            "留一點時間，等這一卷的故事顯影。",
            "從回片到顯影，再到照片慢慢揭曉。",
        ],
        "wait": ["不必每拍一張，就停下來檢查。", "等顯影的時候，再一起回看。"],
        "rush": "也可以使用加急券，早點揭曉。",
        "closing": ["拍的時候，專心生活。", "顯影的時候，再看這一卷。"],
    },
    "en-US": {
        "titles": [
            ["Two frames.", "A little of your day."],
            ["Load a roll.", "Take your time."],
            ["Pick a roll.", "Take it outside."],
            ["Shoot now.", "See it later."],
            ["What will", "this roll reveal?"],
        ],
        "subtitles": [
            "Two neighboring frames, paired into one photo.",
            "Wind by hand. Let the moment set the pace.",
            "Color, slide, cine or black-and-white. Find your mood.",
            "Let the story of your roll develop.",
            "Rewind, develop, then watch your photos appear.",
        ],
        "wait": ["No need to check every shot.", "See the whole roll when it's ready."],
        "rush": "Want to see it sooner? Use a rush ticket.",
        "closing": [
            "Be in the moment when you shoot.",
            "Relive it when you develop.",
        ],
    },
    "ja": {
        "titles": [
            ["ふたコマで、", "日常がつながる。"],
            ["フィルムを入れて、", "今日はゆっくり。"],
            ["一本選んで、", "出かけよう。"],
            ["今は撮るだけ。", "見るのは、あとで。"],
            ["この一本には、", "何が写っている？"],
        ],
        "subtitles": [
            "隣り合う2コマを、1枚の写真に。",
            "手で巻き上げて、目の前の瞬間を楽しもう。",
            "カラー、リバーサル、シネ、モノクロ。気分に合う一本を。",
            "この一本の物語が、写し出されるまで。",
            "巻き戻して、現像して、写真と出会う。",
        ],
        "wait": [
            "一枚ごとに、確かめなくても大丈夫。",
            "現像できたら、一本まとめて振り返ろう。",
        ],
        "rush": "早く見たいときは、特急チケットで。",
        "closing": [
            "撮るときは、目の前の瞬間を。",
            "現像したら、あの日をもう一度。",
        ],
    },
    "ko": {
        "titles": [
            ["두 컷에 담은", "우리의 하루."],
            ["필름 한 롤부터,", "오늘은 천천히."],
            ["필름을 고르고,", "밖으로 나가요."],
            ["지금은 찍고,", "나중에 꺼내 봐요."],
            ["이 한 롤에는", "무엇이 담겼을까요?"],
        ],
        "subtitles": [
            "나란한 두 컷이 한 장의 사진으로.",
            "손으로 필름을 감고, 눈앞의 순간에 집중하세요.",
            "컬러, 슬라이드, 시네마, 흑백. 오늘의 분위기에 맞게.",
            "한 롤에 담긴 이야기가 현상될 때까지.",
            "필름을 되감고, 현상하고, 사진을 한 장씩 만나보세요.",
        ],
        "wait": [
            "한 장 찍을 때마다 확인하지 않아도 괜찮아요.",
            "현상이 끝나면, 한 롤을 함께 돌아봐요.",
        ],
        "rush": "빨리 보고 싶다면, 급행 티켓을 사용하세요.",
        "closing": [
            "찍을 때는, 지금 이 순간에.",
            "현상할 때는, 그날의 기억 속으로.",
        ],
    },
}


def font_spec(locale):
    if locale == "zh-Hant":
        return SERIF, 2  # Songti TC Bold, with traditional Chinese glyph forms.
    if locale == "en-US":
        return "/System/Library/Fonts/NewYork.ttf", 0
    if locale == "ko":
        return "/System/Library/Fonts/Supplemental/AppleMyungjo.ttf", 0
    if locale == "ja":
        # macOS ships decomposed Japanese filenames; normalize for discovery.
        candidates = [
            path for path in Path("/System/Library/Fonts").glob("*.ttc")
            if "ヒラギノ明朝" in unicodedata.normalize("NFC", path.name)
        ]
        if not candidates:
            raise SystemExit("Japanese Mincho font not found.")
        return str(sorted(candidates)[0]), 0
    return SERIF, 1


def serif(size, locale="zh-Hans"):
    path, index = font_spec(locale)
    return ImageFont.truetype(path, size, index=index)


def fitted_font(lines, size, locale, max_width=1152, minimum=26):
    for candidate in range(size, minimum - 1, -1):
        font = serif(candidate, locale)
        if all(font.getlength(line) <= max_width for line in lines):
            return font
    raise ValueError(f"{locale}: copy does not fit: {lines}")


def text(draw, xy, value, size, fill, locale):
    font = fitted_font([value], size, locale, max_width=1236 - xy[0])
    box = draw.textbbox(xy, value, font=font)
    if box[2] > 1236 or box[3] > H:
        raise ValueError(f"{locale}: text overflows: {value}")
    draw.text(xy, value, font=font, fill=fill)


def mono(size):
    return ImageFont.truetype(MONO, size)


def canvas(number, locale):
    copy = COPY[locale]
    title = copy["titles"][number - 1]
    subtitle = copy["subtitles"][number - 1]
    image = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(image)
    # Quiet, warm lighting rather than simulated camera or film artwork.
    for y in range(H):
        t = max(0, 1 - y / 1700)
        draw.line((0, y, W, y), fill=(
            BG[0] + round(8 * t), BG[1] + round(5 * t), BG[2] + round(2 * t)))
    draw.line((84, 104, 132, 104), fill=(168, 67, 45), width=5)
    draw.text((154, 83), "HALF CAM", font=mono(28), fill=BRASS)
    draw.text((1236, 83), f"{number:02d} / 05", font=mono(24),
              fill=MUTED, anchor="ra")
    draw.text((84, 192), LABELS[number - 1], font=mono(24), fill=BRASS)
    # Use one consistent headline size across all five cards in each language.
    title_font = fitted_font(
        [line for lines in copy["titles"] for line in lines],
        108, locale, minimum=72)
    for i, line in enumerate(title):
        draw.text((76, 264 + 133 * i), line, font=title_font, fill=PAPER)
    text(draw, (84, 584), subtitle, 37, MUTED, locale)
    draw.line((84, 2786, 1236, 2786), fill=(62, 54, 43), width=1)
    draw.text((84, 2810), "WIND. SHOOT. WAIT. DEVELOP.",
              font=mono(21), fill=MUTED)
    draw.text((1236, 2810), "HALF-FRAME / 3:4",
              font=mono(21), fill=BRASS, anchor="ra")
    return image


def card(canvas_image, content, xy, width, radius=18):
    height = round(content.height * width / content.width)
    content = content.resize((width, height), Image.Resampling.LANCZOS)
    x, y = xy
    mask = Image.new("L", content.size)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius, fill=255)
    shadow = Image.new("RGBA", canvas_image.size)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - 9, y + 19, x + width + 9, y + height + 27),
        radius + 12, fill=(0, 0, 0, 150))
    canvas_image.paste(Image.alpha_composite(
        canvas_image.convert("RGBA"),
        shadow.filter(ImageFilter.GaussianBlur(24))).convert("RGB"))
    canvas_image.paste(content, xy, mask)
    ImageDraw.Draw(canvas_image).rounded_rectangle(
        (x, y, x + width - 1, y + height - 1),
        radius, outline=(83, 73, 56), width=1)


def screen(canvas_image, source, box, y=720, max_width=1120, max_height=2010):
    crop = source.crop(box)
    width = min(max_width, round(max_height * crop.width / crop.height))
    card(canvas_image, crop, ((W - width) // 2, y), width, radius=24)


def source_folder(source_root, locale):
    localized = source_root / SOURCE_SETS[locale]["folder"]
    # A custom --source may point directly at that locale's capture directory.
    return localized if localized.is_dir() else source_root


def load_sources(source_root, locale):
    source_dir = source_folder(source_root, locale)
    files = SOURCE_SETS[locale]["files"]
    missing = [name for name in files.values() if not (source_dir / name).is_file()]
    if missing:
        raise SystemExit(
            f"{locale}: missing captures in {source_dir}: {', '.join(missing)}")
    sources = {}
    for role, name in files.items():
        with Image.open(source_dir / name) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            if image.size != (W, H):
                raise SystemExit(f"{locale}/{name}: expected {(W, H)}, got {image.size}")
            sources[role] = image.copy()
    return sources


def create(source_root, out, locale="zh-Hans"):
    copy = COPY[locale]
    layout = SOURCE_SETS[locale]
    sources = load_sources(source_root, locale)
    out.mkdir(parents=True, exist_ok=True)
    slides = []

    image = canvas(1, locale)
    album = sources["album"]
    # Extract real contact-sheet pairs; no replacement images or color grading.
    top, second_top = layout["pair_tops"]
    card(image, album.crop((88, top, 1232, top + 977)), (60, 760), 1200)
    card(image, album.crop((88, second_top, 1232, second_top + 977)),
         (175, 1850), 970)
    slides.append(("01-diptych.png", image))

    image = canvas(2, locale)
    screen(image, sources["camera"], (0, 185, W, H))
    slides.append(("02-camera.png", image))

    image = canvas(3, locale)
    screen(image, sources["load"], (0, 470, W, H),
           y=760, max_width=1100, max_height=1950)
    slides.append(("03-load.png", image))

    image = canvas(4, locale)
    screen(image, sources["wait"], (0, 185, W, layout["wait_bottom"]),
           y=910, max_width=1160, max_height=1000)
    draw = ImageDraw.Draw(image)
    text(draw, (84, 2050), copy["wait"][0], 53, PAPER, locale)
    text(draw, (84, 2145), copy["wait"][1], 42, MUTED, locale)
    draw.line((84, 2350, 1236, 2350), fill=(62, 54, 43))
    draw.text((84, 2390), "WAIT IT OUT, OR USE A RUSH TICKET.",
              font=mono(23), fill=BRASS)
    text(draw, (84, 2450), copy["rush"], 36, MUTED, locale)
    slides.append(("04-wait.png", image))

    image = canvas(5, locale)
    screen(image, sources["develop"], (180, 640, 1100, 1970),
           y=810, max_width=1110, max_height=1580)
    draw = ImageDraw.Draw(image)
    text(draw, (84, 2510), copy["closing"][0], 46, PAPER, locale)
    text(draw, (84, 2595), copy["closing"][1], 46, PAPER, locale)
    slides.append(("05-develop.png", image))

    # Keep the capture/layout aspect ratio; only scale proportionally and pad
    # the subpixel ratio difference. Never stretch photos or UI to fit a slot.
    slides = [
        (filename, ImageOps.pad(image, OUTPUT_SIZE,
                               method=Image.Resampling.LANCZOS, color=BG))
        for filename, image in slides
    ]
    for filename, image in slides:
        # RGB PNG: no alpha, screenshot EXIF, or location metadata.
        image.save(out / filename, optimize=True)
        print(out / filename)

    thumb_width = 330
    thumb_height = round(OUTPUT_SIZE[1] * thumb_width / OUTPUT_SIZE[0])
    gap, margin = 18, 24
    preview = Image.new("RGB", (
        2 * margin + len(slides) * thumb_width + (len(slides) - 1) * gap,
        thumb_height + 2 * margin), (231, 226, 216))
    for i, (_, image) in enumerate(slides):
        preview.paste(image.resize((thumb_width, thumb_height),
                                  Image.Resampling.LANCZOS),
                      (margin + i * (thumb_width + gap), margin))
    preview.save(out / "_preview.jpg", quality=92)
    with ZipFile(out / f"HALF-CAM-{locale}-{OUTPUT_TAG}.zip", "w",
                 compression=ZIP_DEFLATED) as archive:
        for filename, _ in slides:
            archive.write(out / filename, arcname=filename)


def bundle_all(output_root, locales):
    archive_path = output_root / f"HALF-CAM-5-languages-{OUTPUT_TAG}.zip"
    with ZipFile(archive_path, "w", compression=ZIP_DEFLATED) as archive:
        for locale in locales:
            files = sorted((output_root / f"{locale}-{OUTPUT_VERSION}").glob("[0-9][0-9]-*.png"))
            if len(files) != 5:
                raise ValueError(f"{locale}: expected five upload images")
            for path in files:
                archive.write(path, arcname=f"{locale}/{path.name}")
    print(archive_path)
    return archive_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "商店页")
    parser.add_argument("--locale", choices=[*COPY, "all"], default="zh-Hans")
    parser.add_argument("--output", type=Path,
                        help="Single-locale output directory; with all, output root.")
    args = parser.parse_args()
    locales = list(COPY) if args.locale == "all" else [args.locale]
    for locale in locales:
        if args.locale == "all":
            out = (args.output or OUTPUT_ROOT) / f"{locale}-{OUTPUT_VERSION}"
        else:
            out = args.output or OUTPUT_ROOT / f"{locale}-{OUTPUT_VERSION}"
        create(args.source, out, locale)
    if args.locale == "all":
        bundle_all(args.output or OUTPUT_ROOT, locales)
