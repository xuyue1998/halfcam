#!/usr/bin/env python3
"""Generate HALF CAM App Store 6.7" story screenshots and a refined icon."""

from __future__ import annotations

import math
import os
import random
import urllib.request
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "store"
SHOT_DIR = OUT / "screenshots" / "zh-Hans"
ICON_DIR = OUT / "icon"
SRC_DIR = OUT / "src"
ICON_APP = ROOT / "HalfCam" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

W, H = 1320, 2868
S = 3.2
BODY = (14, 13, 12)
SAFE = (180, 35, 24)
BRASS = (196, 165, 116)
PAPER = (243, 237, 228)
MIST = (138, 129, 120)
INK = (18, 16, 14)
METAL_HI = (210, 205, 198)
METAL_MID = (140, 132, 124)
METAL_LO = (56, 52, 48)

PHOTOS = {
    "portrait": "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=1600&q=82&auto=format&fit=crop",
    "cafe": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1600&q=82&auto=format&fit=crop",
    "street": "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=1600&q=82&auto=format&fit=crop",
    "city": "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=1600&q=82&auto=format&fit=crop",
    "night": "https://images.unsplash.com/photo-1514565131-fce0801e5785?w=1600&q=82&auto=format&fit=crop",
    "neon": "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=1600&q=82&auto=format&fit=crop",
    "window": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=1600&q=82&auto=format&fit=crop",
    "bw": "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=1600&q=82&auto=format&fit=crop",
}

SEGS = {
    "0": {0, 1, 2, 3, 4, 5},
    "1": {1, 2},
    "2": {0, 1, 6, 4, 3},
    "3": {0, 1, 6, 2, 3},
    "4": {5, 6, 1, 2},
    "5": {0, 5, 6, 2, 3},
    "6": {0, 5, 6, 2, 3, 4},
    "7": {0, 1, 2},
    "8": {0, 1, 2, 3, 4, 5, 6},
    "9": {0, 1, 2, 3, 5, 6},
}


def font(path, size, index=0):
    return ImageFont.truetype(path, size, index=index)


F_TITLE = font("/System/Library/Fonts/Supplemental/Songti.ttc", 78, 1)
F_TITLE_SM = font("/System/Library/Fonts/Supplemental/Songti.ttc", 56, 1)
F_SERIF = font("/System/Library/Fonts/Supplemental/Songti.ttc", 42, 1)
F_SERIF_SM = font("/System/Library/Fonts/Supplemental/Songti.ttc", 28, 6)
F_NY = font("/System/Library/Fonts/NewYork.ttf", 28)
F_NY_LG = font("/System/Library/Fonts/NewYork.ttf", 36)
F_MONO = font("/System/Library/Fonts/Menlo.ttc", 24, 0)
F_MONO_SM = font("/System/Library/Fonts/Menlo.ttc", 18, 0)
F_MONO_LG = font("/System/Library/Fonts/Menlo.ttc", 32, 1)
F_HEI = font("/System/Library/Fonts/STHeiti Medium.ttc", 22, 1)
SONGTI = "/System/Library/Fonts/Supplemental/Songti.ttc"
HEITI = "/System/Library/Fonts/STHeiti Medium.ttc"
MENLO = "/System/Library/Fonts/Menlo.ttc"


def has_cjk(text):
    return any("\u4e00" <= ch <= "\u9fff" for ch in text)


def ui_font(size, text="", bold=False):
    size = int(size)
    if has_cjk(text):
        return font(HEITI, size, 1)
    return font(MENLO, size, 1 if bold else 0)


def serif_font(size, bold=True):
    return font(SONGTI, int(size), 1 if bold else 6)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    if isinstance(a, tuple):
        return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))
    return a + (b - a) * t


def px(n):
    return int(round(n * S))


def new_canvas(color=BODY):
    return Image.new("RGB", (W, H), color)


def gradient(size, c0, c1, vertical=True):
    w, h = size
    im = Image.new("RGB", size, c0)
    draw = ImageDraw.Draw(im)
    span = h if vertical else w
    for i in range(span):
        col = lerp(c0, c1, i / max(1, span - 1))
        if vertical:
            draw.line([(0, i), (w, i)], fill=col)
        else:
            draw.line([(i, 0), (i, h)], fill=col)
    return im


def radial(size, inner, outer, center=None, rmax=None):
    w, h = size
    cx, cy = center or (w / 2, h / 4)
    rmax = rmax or math.hypot(w, h) * 0.55
    base = Image.new("RGB", size, outer)
    overlay = Image.new("L", size, 0)
    d = ImageDraw.Draw(overlay)
    steps = 28
    for i in range(steps, 0, -1):
        t = i / steps
        r = int(rmax * t)
        v = int(255 * (1 - t) ** 1.6)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=v)
    color = Image.new("RGB", size, inner)
    return Image.composite(color, base, overlay)


def leather(size):
    w, h = size
    im = gradient(size, (38, 32, 28), (10, 9, 8))
    rng = random.Random(0xC0FFEE)
    dots = Image.new("RGBA", size, (0, 0, 0, 0))
    p = dots.load()
    n = min(2200, w * h // 1800)
    for _ in range(n):
        x = int(rng.random() * w)
        y = int(rng.random() * h)
        s = int(rng.random() * 2) + 1
        a = int(18 + rng.random() * 40)
        for dx in range(s):
            for dy in range(s):
                xx, yy = min(w - 1, x + dx), min(h - 1, y + dy)
                p[xx, yy] = (255, 255, 255, a)
    im = Image.alpha_composite(im.convert("RGBA"), dots).convert("RGB")
    top = gradient((w, 64 * 3), (88, 82, 76), (28, 26, 24))
    im.paste(top, (0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 64 * 3, w, 64 * 3 + 8], fill=(0, 0, 0))
    return im


def grain(im, sigma=12, opacity=0.18):
    n = Image.effect_noise(im.size, sigma).convert("L")
    n = ImageEnhance.Contrast(n).enhance(1.4)
    overlay = Image.merge("RGB", (n, n, n))
    return Image.blend(im, overlay, opacity)


def vignette(im, strength=0.45):
    w, h = im.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    pad = int(min(w, h) * 0.08)
    d.ellipse([-pad, -pad, w + pad, h + pad], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(int(min(w, h) * 0.18)))
    dark = Image.new("RGB", (w, h), (0, 0, 0))
    faded = Image.composite(im, dark, mask)
    return Image.blend(im, faded, strength)


def grade(im, kind="portra"):
    im = im.convert("RGB")
    if kind == "optical":
        im = ImageEnhance.Color(im).enhance(0.62)
        im = ImageEnhance.Contrast(im).enhance(0.92)
        cool = Image.new("RGB", im.size, (210, 220, 228))
        im = Image.blend(im, cool, 0.08)
        return vignette(im, 0.28)
    if kind == "acros":
        im = ImageOps.grayscale(im).convert("RGB")
        im = ImageEnhance.Contrast(im).enhance(1.18)
        im = ImageEnhance.Brightness(im).enhance(0.96)
        im = grain(im, 10, 0.16)
        return vignette(im, 0.32)
    if kind == "tungsten":
        im = ImageEnhance.Color(im).enhance(0.88)
        teal = Image.new("RGB", im.size, (18, 40, 52))
        im = ImageChops.multiply(im, ImageEnhance.Brightness(teal).enhance(8.5).convert("RGB"))
        im = Image.blend(im, Image.new("RGB", im.size, (40, 70, 80)), 0.12)
        warm = Image.new("RGB", im.size, (255, 140, 70))
        im = Image.blend(im, ImageChops.screen(im, warm), 0.10)
        im = grain(im, 14, 0.2)
        return vignette(im, 0.4)
    if kind == "superia":
        im = ImageEnhance.Color(im).enhance(1.05)
        green = Image.new("RGB", im.size, (210, 230, 200))
        im = Image.blend(im, green, 0.08)
        im = ImageEnhance.Contrast(im).enhance(1.04)
        im = grain(im, 12, 0.17)
        return vignette(im, 0.3)
    im = ImageEnhance.Color(im).enhance(0.92)
    im = ImageEnhance.Contrast(im).enhance(0.96)
    warm = Image.new("RGB", im.size, (255, 220, 185))
    im = Image.blend(im, warm, 0.12)
    im = ImageEnhance.Brightness(im).enhance(1.04)
    im = grain(im, 11, 0.14)
    return vignette(im, 0.26)


def ipaste(base, overlay, xy, mask=None):
    x, y = int(round(xy[0])), int(round(xy[1]))
    if mask is not None:
        base.paste(overlay, (x, y), mask)
    else:
        base.paste(overlay, (x, y))
    return base


def cover(im, size, kind="portra"):
    tw, th = size
    im = im.convert("RGB")
    src_w, src_h = im.size
    scale = max(tw / src_w, th / src_h)
    nw, nh = int(src_w * scale), int(src_h * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (nw - tw) // 2
    y = (nh - th) // 2
    im = im.crop((x, y, x + tw, y + th))
    return grade(im, kind)


def fallback_photo(size, kind):
    w, h = size
    palettes = {
        "portra": ((80, 50, 36), (220, 180, 140)),
        "superia": ((30, 50, 36), (180, 200, 160)),
        "tungsten": ((8, 12, 28), (220, 90, 40)),
        "acros": ((12, 12, 12), (190, 190, 186)),
        "optical": ((40, 48, 58), (170, 176, 182)),
    }
    c0, c1 = palettes.get(kind, palettes["portra"])
    im = radial(size, c1, c0, center=(w * 0.45, h * 0.38), rmax=min(w, h) * 0.8)
    d = ImageDraw.Draw(im)
    if kind == "tungsten":
        for i, x in enumerate((0.2, 0.55, 0.82)):
            r = int(min(w, h) * (0.04 + i * 0.01))
            cx, cy = int(w * x), int(h * (0.18 + i * 0.08))
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 170, 80))
    elif kind == "optical":
        d.rectangle([int(w * 0.1), int(h * 0.35), int(w * 0.9), int(h * 0.9)], fill=(60, 64, 70))
        d.rectangle([int(w * 0.18), 0, int(w * 0.28), h], fill=(90, 92, 98))
    else:
        d.ellipse([int(w * 0.28), int(h * 0.18), int(w * 0.72), int(h * 0.78)], fill=lerp(c0, c1, 0.35))
    return grade(im, kind if kind != "optical" else "optical")


def fetch_photos():
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    got = {}
    for name, url in PHOTOS.items():
        path = SRC_DIR / f"{name}.jpg"
        if not path.exists() or path.stat().st_size < 8000:
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 HALF-CAM-store-art"})
                with urllib.request.urlopen(req, timeout=25) as r:
                    path.write_bytes(r.read())
                print("downloaded", name, path.stat().st_size)
            except Exception as e:
                print("photo fail", name, e)
                continue
        try:
            im = Image.open(path).convert("RGB")
            if min(im.size) < 200:
                continue
            got[name] = im
        except Exception as e:
            print("open fail", name, e)
    return got


def photo(bank, key, size, kind):
    if key in bank:
        return cover(bank[key], size, kind)
    alts = [k for k in bank]
    if alts:
        return cover(bank[alts[hash(key) % len(alts)]], size, kind)
    return fallback_photo(size, kind)


def text_size(draw, text, fnt):
    b = draw.textbbox((0, 0), text, font=fnt)
    return b[2] - b[0], b[3] - b[1]


def draw_centered(draw, xy, text, fnt, fill, anchor="mm"):
    draw.text(xy, text, font=fnt, fill=fill, anchor=anchor)


def rounded_box(im, box, radius, fill, outline=None, width=1):
    box = [int(round(v)) for v in box]
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def paste_shadow(base, overlay, xy, blur=18, opacity=90, dy=8):
    x, y = int(xy[0]), int(xy[1])
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer = overlay.convert("RGBA")
    mask = layer.split()[-1]
    black = Image.new("RGBA", layer.size, (0, 0, 0, opacity))
    black.putalpha(mask)
    sh.paste(black, (x, y + dy), black)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.alpha_composite(base.convert("RGBA"), sh)
    out.paste(layer, (x, y), layer)
    return out.convert("RGB")


def sprocket_row(draw, x, y, w, h=18, n=18, fill=(228, 226, 220)):
    gap = w / n
    hole = gap * 0.42
    for i in range(n):
        cx = x + gap * i + gap / 2
        draw.rounded_rectangle(
            [cx - hole / 2, y, cx + hole / 2, y + h],
            radius=2,
            fill=fill,
        )


def film_strip(frames, cell_w, cell_h, gutter=8, rebate=46):
    n = len(frames)
    w = n * cell_w + (n - 1) * gutter + rebate * 2
    h = cell_h + rebate * 2
    strip = Image.new("RGB", (w, h), (12, 12, 12))
    d = ImageDraw.Draw(strip)
    sprocket_row(d, rebate, 10, w - rebate * 2, 14, n * 6)
    sprocket_row(d, rebate, h - 24, w - rebate * 2, 14, n * 6)
    x = rebate
    for fr in frames:
        strip.paste(fr.resize((cell_w, cell_h), Image.Resampling.LANCZOS), (x, rebate))
        x += cell_w + gutter
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 40, 40))
    return strip


def caption_block(im, kicker, title, kicker_fill=BRASS, y0=78):
    d = ImageDraw.Draw(im)
    draw_centered(d, (W / 2, y0), kicker, F_NY, kicker_fill, "mm")
    tw, _ = text_size(d, title, F_TITLE)
    title_font = F_TITLE if tw < W - 160 else F_TITLE_SM
    draw_centered(d, (W / 2, y0 + 82), title, title_font, PAPER, "mm")
    return 250


def bottom_sprockets(im, y=None):
    y = H - 70 if y is None else y
    d = ImageDraw.Draw(im)
    d.rectangle([0, y, W, H], fill=(8, 8, 8))
    sprocket_row(d, 40, y + 22, W - 80, 16, 22, fill=(48, 46, 44))
    return im


def seven_seg(im, text, box):
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    w, h = x1 - x0, y1 - y0
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x0, y0, x1, y1], 6, fill=(18, 4, 4), outline=(88, 88, 88), width=2)
    n = max(1, len(text))
    dw = max(22, min(40, (w - 28) // n - 8))
    dh = int(h * 0.58)
    gap = 12
    total = n * dw + (n - 1) * gap
    sx = x0 + (w - total) // 2
    sy = y0 + (h - dh) // 2
    on = (255, 72, 48)
    off = (36, 8, 8)
    t = max(4, dw // 7)

    def horiz(x, y, length):
        return [int(x + t), int(y), int(x + length - t), int(y + t)]

    def vert(x, y0_, y1_):
        return [int(x), int(y0_ + t * 0.45), int(x + t), int(y1_ - t * 0.45)]

    for i, ch in enumerate(text):
        segs = SEGS.get(ch, set())
        cx = sx + i * (dw + gap)
        mid = sy + dh // 2
        paths = [
            (0, horiz(cx, sy, dw)),
            (6, horiz(cx, mid - t // 2, dw)),
            (3, horiz(cx, sy + dh - t, dw)),
            (5, vert(cx, sy, mid)),
            (1, vert(cx + dw - t, sy, mid)),
            (4, vert(cx, mid, sy + dh)),
            (2, vert(cx + dw - t, mid, sy + dh)),
        ]
        for idx, rect in paths:
            if rect[2] <= rect[0] or rect[3] <= rect[1]:
                continue
            if idx not in segs:
                continue
            d.rounded_rectangle(rect, 1, fill=on)
    return im


def metal_fill(size, hi=METAL_HI, lo=METAL_LO):
    return gradient(size, hi, lo)


def draw_nameplate(im, cx, cy, text):
    w, h = px(168), px(28)
    plate = metal_fill((w, h), (200, 196, 188), (120, 114, 106))
    d = ImageDraw.Draw(plate)
    d.rounded_rectangle([0, 0, w - 1, h - 1], 6, outline=(230, 226, 220), width=2)
    f = font("/System/Library/Fonts/Supplemental/Songti.ttc", int(13 * S), 1)
    d.text((w / 2, h / 2), text, font=f, fill=(28, 26, 24), anchor="mm")
    x, y = int(round(cx - w / 2)), int(round(cy - h / 2))
    im.paste(plate, (x, y))
    return im


def draw_circle_metal(im, c, r, inner=None):
    d = ImageDraw.Draw(im)
    x, y = c
    d.ellipse([x - r, y - r, x + r, y + r], fill=(70, 66, 62), outline=(210, 205, 198), width=max(2, px(1.4)))
    d.ellipse([x - r + 3, y - r + 3, x + r - 3, y + r - 3], fill=(48, 44, 40))
    if inner:
        ir, col = inner
        d.ellipse([x - ir, y - ir, x + ir, y + ir], fill=col)
    d.ellipse([x - r * 0.35, y - r * 0.55, x + r * 0.15, y - r * 0.05], fill=(255, 255, 255, 40) if False else (90, 86, 80))


def draw_winder(im, c, r=None):
    r = r or px(40)
    x, y = c
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(58, 54, 50, 255), outline=(210, 205, 198, 255), width=px(2.2))
    d.ellipse([x - r + px(6), y - r + px(6), x + r - px(6), y + r - px(6)], fill=(36, 34, 32, 255))
    for i in range(18):
        a = math.radians(i * 20 - 8)
        x0 = x + math.cos(a) * (r - px(10))
        y0 = y + math.sin(a) * (r - px(10))
        x1 = x + math.cos(a) * (r - px(4))
        y1 = y + math.sin(a) * (r - px(4))
        d.line([(x0, y0), (x1, y1)], fill=(180, 176, 170, 255), width=max(2, px(1.1)))
    pin_a = math.radians(-50)
    px_ = x + math.cos(pin_a) * (r * 0.52)
    py_ = y + math.sin(pin_a) * (r * 0.52)
    pr = px(5)
    d.rounded_rectangle([px_ - pr, py_ - pr, px_ + pr, py_ + pr], 6, fill=(219, 36, 31, 255))
    d.ellipse([x - px(7), y - px(7), x + px(7), y + px(7)], fill=(90, 86, 82, 255))
    return Image.alpha_composite(im.convert("RGBA"), overlay).convert("RGB")


def draw_shutter(im, c, live=True):
    x, y = c
    r = px(38)
    d = ImageDraw.Draw(im)
    d.ellipse([x - r, y - r, x + r, y + r], outline=(230, 226, 220), width=px(3.5))
    ir = px(29)
    col = (184, 30, 36) if live else (90, 30, 32)
    d.ellipse([x - ir, y - ir, x + ir, y + ir], fill=col)
    d.ellipse([x - ir * 0.45, y - ir * 0.7, x + ir * 0.05, y - ir * 0.15], fill=(220, 90, 80) if live else (110, 50, 52))
    return im


def draw_latch(im, box, open_=False):
    x0, y0, x1, y1 = box
    rounded_box(im, box, 8, (40, 38, 36), (110, 108, 104), 2)
    d = ImageDraw.Draw(im)
    cap = [x0 + px(8), y0 + px(10), x0 + px(28), y1 - px(10)]
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rounded_rectangle(cap, 6, fill=(210, 205, 198, 255))
    if open_:
        overlay = overlay.rotate(-32, center=(cap[0], (cap[1] + cap[3]) / 2), resample=Image.Resampling.BICUBIC)
    im = Image.alpha_composite(im.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(im)
    label = "卸卷" if not open_ else "装卷"
    f = ui_font(10 * S, label, bold=True)
    d.text(((x0 + x1) / 2 + px(8), (y0 + y1) / 2), label, font=f, fill=(210, 210, 210), anchor="mm")
    return im


def hatch_bar(im, title, trailing="", y=0):
    d = ImageDraw.Draw(im)
    d.text((W / 2, y + px(28)), title, font=serif_font(13 * S), fill=(200, 198, 194), anchor="mm")
    d.rounded_rectangle([px(18), y + px(18), px(18) + px(18), y + px(18) + px(8)], 4, fill=(200, 196, 188))
    d.text((px(48), y + px(22)), "合上", font=ui_font(12 * S, "合上", True), fill=(198, 198, 198), anchor="lm")
    if trailing:
        d.text((W - px(24), y + px(22)), trailing, font=ui_font(11 * S, trailing), fill=(184, 184, 184), anchor="rm")
    return im


def chrome_plate(im, box, title, prominent=True):
    x0, y0, x1, y1 = box
    hi = (72, 70, 68) if prominent else (40, 38, 36)
    lo = (36, 34, 32) if prominent else (20, 18, 16)
    plate = gradient((x1 - x0, y1 - y0), hi, lo)
    d = ImageDraw.Draw(plate)
    d.rounded_rectangle([0, 0, x1 - x0 - 1, y1 - y0 - 1], 8, outline=(122, 122, 122) if prominent else (70, 70, 70), width=2)
    f = ui_font(13 * S, title, bold=prominent)
    col = (235, 235, 235) if prominent else (158, 158, 158)
    d.text(((x1 - x0) / 2, (y1 - y0) / 2), title, font=f, fill=col, anchor="mm")
    shine = Image.new("RGBA", plate.size, (255, 255, 255, 0))
    ImageDraw.Draw(shine).rectangle([0, 0, plate.size[0], 14], fill=(255, 255, 255, 40 if prominent else 18))
    plate = Image.alpha_composite(plate.convert("RGBA"), shine).convert("RGB")
    ipaste(im, plate, (x0, y0))
    return im


def metal_selector(im, labels, selected, box):
    x0, y0, x1, y1 = box
    rounded_box(im, box, 22, (12, 12, 12), (80, 80, 80), 2)
    n = len(labels)
    w = (x1 - x0) / n
    d = ImageDraw.Draw(im)
    for i, lab in enumerate(labels):
        f = ui_font(12 * S, lab)
        cx = x0 + w * i + w / 2
        if i == selected:
            d.rounded_rectangle([x0 + w * i + 6, y0 + 6, x0 + w * (i + 1) - 6, y1 - 6], 16, fill=(48, 46, 44), outline=(140, 140, 140))
            d.text((cx, (y0 + y1) / 2), lab, font=f, fill=(230, 230, 230), anchor="mm")
        else:
            d.text((cx, (y0 + y1) / 2), lab, font=f, fill=(140, 140, 140), anchor="mm")
    return im


def film_sleeve(size, family, name, iso):
    w, h = size
    styles = {
        "color": dict(body=(56, 158, 56), band=(240, 240, 240), ink=(255, 255, 255), band_ink=(20, 20, 20), accent=(30, 110, 46)),
        "gold": dict(body=(245, 209, 26), band=(210, 30, 26), ink=(20, 20, 20), band_ink=(255, 255, 255), accent=(210, 30, 26)),
        "slide": dict(body=(158, 162, 168), band=(240, 240, 240), ink=(20, 20, 20), band_ink=(20, 20, 20), accent=(46, 96, 158)),
        "vision": dict(body=(32, 34, 36), band=(26, 132, 138), ink=(240, 240, 240), band_ink=(255, 255, 255), accent=(160, 160, 160)),
        "acros": dict(body=(18, 18, 18), band=(240, 240, 240), ink=(240, 240, 240), band_ink=(20, 20, 20), accent=(46, 132, 56)),
    }
    st = styles[family]
    im = Image.new("RGB", (w, h), st["body"])
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w, h], fill=st["body"])
    # paper grain
    im = grain(im, 8, 0.08)
    d = ImageDraw.Draw(im)
    if family in ("color", "slide", "acros"):
        d.rectangle([0, 0, w, int(h * 0.11)], fill=st["accent"])
    if family == "vision":
        d.rectangle([0, 0, int(w * 0.26), h], fill=st["band"])
        d.rectangle([int(w * 0.26), 0, int(w * 0.26) + 2, h], fill=(220, 220, 220))
        d.ellipse([int(w * 0.58), int(h * 0.22), int(w * 0.90), int(h * 0.78)], outline=(220, 220, 220), width=2)
    else:
        d.rectangle([0, int(h * 0.68), w, h], fill=st["band"])
    f = font("/System/Library/Fonts/Menlo.ttc", max(11, int(h * 0.18)), 1)
    d.text((8, int(h * 0.28)), name, font=f, fill=st["ink"])
    fs = font("/System/Library/Fonts/Menlo.ttc", max(10, int(h * 0.14)), 0)
    d.text((w - 8, int(h * 0.82)), f"ISO {iso}", font=fs, fill=st["band_ink"] if family != "vision" else st["ink"], anchor="rm")
    d.rounded_rectangle([0, 0, w - 1, h - 1], 6, outline=(255, 255, 255, 40) if False else (40, 40, 40), width=1)
    return im


def cassette_body(w=px(96), h=px(58), silver=False):
    src = ROOT / "HalfCam" / "Assets.xcassets" / "FilmCassette.imageset" / "FilmCassette.png"
    im = Image.open(src).convert("RGBA")
    im = im.resize((w, h), Image.Resampling.LANCZOS)
    if silver:
        overlay = Image.new("RGBA", im.size, (200, 200, 200, 80))
        im = Image.alpha_composite(im, overlay)
    return im


def captioned(bg, kicker, title):
    im = bg
    caption_block(im, kicker, title)
    im = bottom_sprockets(im)
    return im


def shot01(bank):
    im = new_canvas((10, 9, 8))
    im = captioned(im, "HALF CAM", "拍完，才能看。")
    left = photo(bank, "window", (560, 746), "portra")
    right = photo(bank, "portrait", (560, 746), "portra")
    paper_w, paper_h = 1232, 900
    paper = Image.new("RGB", (paper_w, paper_h), (236, 228, 214))
    paper = grain(paper, 6, 0.06)
    d = ImageDraw.Draw(paper)
    mx, my, gutter = 48, 52, 12
    paper.paste(left, (mx, my))
    paper.paste(right, (mx + 560 + gutter, my))
    d.rectangle([mx + 560, my, mx + 560 + gutter, my + 746], fill=(8, 8, 8))
    d.rectangle([mx - 2, my - 2, mx + 560 + gutter + 560 + 1, my + 746 + 1], outline=(20, 18, 16), width=2)
    d.text((paper_w / 2, paper_h - 32), "HALF  ·  3:2  SPREAD", font=F_MONO_SM, fill=(90, 80, 70), anchor="mm")
    im = paste_shadow(im, paper, ((W - paper_w) // 2, 300), blur=28, opacity=140, dy=18)
    return im


def shot02(bank):
    im = leather((W, H))
    caption_block(im, "VIEWFINDER  3:4", "一部装在手机里的半格机。")
    top = 318
    draw_circle_metal(im, (px(52), top), px(20), inner=(px(8), (40, 38, 36)))
    im = draw_nameplate(im, W / 2, top, "COLOR 400")
    d = ImageDraw.Draw(im)
    cx = W - px(52)
    d.ellipse([cx - px(15), top - px(15), cx + px(15), top + px(15)], fill=(70, 66, 60), outline=(200, 196, 188), width=3)
    d.ellipse([cx - px(8), top - px(8), cx + px(8), top + px(8)], fill=(70, 60, 40))

    fw, fh = px(300), px(int(300 * 4 / 3))
    fx = (W - fw) // 2
    fy = top + px(36)
    bezel = metal_fill((fw + px(16), fh + px(16)), (150, 146, 140), (70, 64, 58))
    ImageDraw.Draw(bezel).rounded_rectangle([0, 0, bezel.size[0] - 1, bezel.size[1] - 1], 14, outline=(180, 176, 170), width=3)
    bezel.paste(photo(bank, "street", (fw, fh), "optical"), (px(8), px(8)))
    im = paste_shadow(im, bezel, (fx - px(8), fy - px(8)), blur=20, opacity=120, dy=10)

    cy = fy + fh + px(22)
    rounded_box(im, [W / 2 - px(130), cy, W / 2 - px(94), cy + px(38)], 6, (20, 20, 20), (100, 100, 100), 2)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([W / 2 - px(121), cy + px(8), W / 2 - px(103), cy + px(30)], 2, fill=(210, 150, 50))
    im = seven_seg(im, "17", [W / 2 - px(44), cy, W / 2 + px(44), cy + px(38)])
    d = ImageDraw.Draw(im)
    d.text((W / 2, cy + px(44)), "/36", font=ui_font(7 * S, "/36"), fill=(180, 50, 40), anchor="mm")
    rounded_box(im, [W / 2 + px(94), cy, W / 2 + px(130), cy + px(38)], 6, (20, 20, 20), (100, 100, 100), 2)
    for i in range(3):
        d.rectangle([W / 2 + px(101) + i * px(8), cy + px(10), W / 2 + px(106) + i * px(8), cy + px(28)], fill=(180, 180, 180))

    by = H - 300
    im = draw_latch(im, [px(36), by + px(28), px(100), by + px(56)], open_=False)
    im = draw_shutter(im, (W / 2, by + px(42)), live=True)
    im = draw_winder(im, (W - px(80), by + px(42)))
    im = bottom_sprockets(im)
    return im


def shot03(bank):
    im = new_canvas((12, 11, 10))
    glow = radial((W, H), (70, 10, 10), (12, 11, 10), center=(W / 2, 80), rmax=900)
    im = Image.blend(im, glow, 0.55)
    caption_block(im, "UNDEVELOPED", "看不见，才会惦记。")
    im = hatch_bar(im, "暗盒", "免费 · 01 / 02", y=268)
    card_w, card_h = W - px(40), px(168)
    card = gradient((card_w, card_h), (36, 28, 24), (16, 14, 12))
    d = ImageDraw.Draw(card)
    d.rectangle([0, 0, 10, card_h], fill=(56, 158, 56))
    d.rectangle([10, 0, 14, card_h], fill=(240, 240, 240))
    d.rounded_rectangle([0, 0, card_w - 1, card_h - 1], 8, outline=(90, 86, 80), width=2)
    ipaste(card, film_sleeve((px(54), px(36)), "color", "COLOR", 400), (px(28), px(22)))
    d.text((px(96), px(28)), "COLOR 400", font=serif_font(16 * S), fill=(255, 255, 255))
    d.text((px(96), px(58)), "拍摄中", font=ui_font(11 * S, "拍摄中"), fill=(128, 128, 128))
    d.text((px(96), px(82)), "60/72", font=ui_font(12 * S, "60/72", True), fill=(200, 200, 200))
    count, filled, gap = 36, 30, 3
    usable = card_w - px(40)
    hole = max(6, int((usable - gap * (count - 1)) / count))
    sx, sy = px(20), px(118)
    for i in range(count):
        col = (56, 158, 56) if i < filled else (46, 46, 46)
        d.rounded_rectangle([sx + i * (hole + gap), sy, sx + i * (hole + gap) + hole, sy + 10], 1, fill=col)
    d.text((card_w / 2, card_h - px(18)), "还剩 12 格", font=ui_font(11 * S, "还剩 12 格"), fill=(120, 120, 120), anchor="mm")
    im = paste_shadow(im, card, (px(20), 360), blur=16, opacity=100, dy=8)

    blacks = [Image.new("RGB", (200, 268), (6, 6, 6)) for _ in range(6)]
    for i in (1, 2):
        blacks[i] = radial((200, 268), (28, 18, 12), (6, 6, 6), center=(100, 130), rmax=160)
    strip = film_strip(blacks, 200, 268, gutter=6, rebate=36)
    sw = min(W - 80, strip.size[0])
    strip = strip.resize((sw, int(strip.size[1] * sw / strip.size[0])), Image.Resampling.LANCZOS)
    im = paste_shadow(im, strip, ((W - sw) // 2, 980), blur=18, opacity=130, dy=10)
    d = ImageDraw.Draw(im)
    d.text((W / 2, 980 + strip.size[1] + 48), "未显影 · 黑格", font=ui_font(13 * S, "未显影 · 黑格"), fill=(90, 90, 90), anchor="mm")
    im = bottom_sprockets(im)
    return im


def shot04(bank):
    im = radial((W, H), (90, 12, 12), (12, 10, 10), center=(W / 2, 0), rmax=1100)
    caption_block(im, "LOAD  ·  LOCKED", "装卷，即定命运。")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([px(18), 268, px(36), 268 + px(8)], 4, fill=(200, 196, 188))
    d.text((px(48), 272), "合上", font=ui_font(12 * S, "合上", True), fill=(198, 198, 198), anchor="lm")
    im = metal_selector(im, ["彩色", "反转", "电影", "黑白"], 0, [px(24), 320, W - px(24), 320 + px(36)])

    packs = [
        ("color", "COLOR 400", 400, True),
        ("gold", "GOLD 200", 200, False),
        ("slide", "SLIDE 100", 100, False),
        ("vision", "VISION 250", 250, False),
    ]
    cass = cassette_body(px(78), px(46))
    cell_w = 292
    gap_x = 18
    total = cell_w * 4 + gap_x * 3
    x = (W - total) // 2
    y = 430
    for fam, name, iso, sel in packs:
        sleeve = film_sleeve((px(94), px(44)), fam, name.split()[0], iso)
        cell = Image.new("RGBA", (cell_w, px(120)), (0, 0, 0, 0))
        cy = px(10) if sel else px(18)
        ipaste(cell, cass, ((cell.size[0] - cass.size[0]) // 2, cy + px(32)), cass)
        ipaste(cell, sleeve, ((cell.size[0] - sleeve.size[0]) // 2, cy), sleeve.convert("RGBA"))
        im = paste_shadow(im, cell, (x, y), blur=10, opacity=80, dy=4)
        d = ImageDraw.Draw(im)
        d.text((x + cell_w / 2, y + px(118)), name, font=serif_font(12 * S), fill=(230, 230, 230) if sel else (170, 170, 170), anchor="mm")
        d.text((x + cell_w / 2, y + px(136)), f"ISO {iso}", font=ui_font(10 * S, f"ISO {iso}"), fill=(120, 120, 120), anchor="mm")
        x += cell_w + gap_x

    d = ImageDraw.Draw(im)
    ipaste(im, film_sleeve((px(10), px(22)), "color", "", 400), (px(28), 980))
    d.text((px(52), 978), "COLOR 400", font=serif_font(16 * S), fill=(230, 230, 230))
    d.text((px(52), 1020), "青绿 · 日常", font=serif_font(12 * S, bold=False), fill=(140, 140, 140))
    d.text((W - px(28), 1000), "ISO 400", font=ui_font(12 * S, "ISO 400"), fill=(128, 128, 128), anchor="rm")

    d.text((px(28), 1100), "格数", font=ui_font(14 * S, "格数"), fill=(200, 200, 200))
    cx = px(28)
    for lab, on in [("12", False), ("24", False), ("36", True), ("72", False)]:
        box = [cx, 1160, cx + px(72), 1196]
        rounded_box(im, box, 8, (48, 46, 44) if on else (24, 22, 20), (140, 140, 140) if on else (60, 60, 60), 2)
        d = ImageDraw.Draw(im)
        d.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), lab, font=ui_font(13 * S, lab), fill=(230, 230, 230) if on else (140, 140, 140), anchor="mm")
        cx += px(84)

    d.text((px(28), 1260), "颗粒", font=ui_font(14 * S, "颗粒"), fill=(200, 200, 200))
    im = metal_selector(im, ["无", "细", "中", "粗"], 2, [px(28), 1310, W - px(28), 1346])
    im = chrome_plate(im, [px(24), 1420, W - px(24), 1464], "装入这一卷", True)
    d = ImageDraw.Draw(im)
    d.text((W / 2, 1540), "装卷时锁定。洗完不能改。", font=ui_font(13 * S, "装卷时锁定。洗完不能改。"), fill=(90, 90, 90), anchor="mm")
    im = bottom_sprockets(im)
    return im


def shot05(bank):
    bg_path = ROOT / "HalfCam" / "Assets.xcassets" / "SafelightBG.imageset" / "SafelightBG.png"
    bg = Image.open(bg_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    im = Image.blend(new_canvas((12, 8, 8)), bg, 0.85)
    caption_block(im, "DARKROOM  38°C", "一卷拍满，才配打开。", kicker_fill=(210, 150, 120))

    island = Image.new("RGB", (px(200), px(36)), (8, 8, 8))
    d = ImageDraw.Draw(island)
    d.rounded_rectangle([0, 0, island.size[0] - 1, island.size[1] - 1], 20, fill=(8, 8, 8), outline=(40, 40, 40))
    mark = Image.open(ROOT / "DevelopLive" / "Assets.xcassets" / "IslandMark.imageset" / "IslandMark.png").convert("RGBA")
    mark = mark.resize((px(22), px(14)), Image.Resampling.LANCZOS)
    island = island.convert("RGBA")
    ipaste(island, mark, (px(14), px(10)), mark)
    td = ImageDraw.Draw(island)
    td.text((px(44), island.size[1] / 2), "显影中  08:12", font=ui_font(11 * S, "显影中  08:12"), fill=(220, 220, 220, 255), anchor="lm")
    ipaste(im, island.convert("RGB"), ((W - island.size[0]) // 2, 268))

    tw, th = px(148), px(196)
    tank = metal_fill((tw, th), (90, 88, 86), (36, 34, 32))
    d = ImageDraw.Draw(tank)
    d.rounded_rectangle([0, 0, tw - 1, th - 1], 18, outline=(180, 176, 170), width=3)
    inner = [px(12), px(22), tw - px(12), th - px(12)]
    d.rounded_rectangle(inner, 10, fill=(10, 8, 7))
    liquid_h = int((inner[3] - inner[1]) * 0.62)
    fluid = gradient((inner[2] - inner[0] - 8, liquid_h), (190, 90, 30), (120, 40, 16))
    fluid = grain(fluid, 8, 0.1)
    ipaste(tank, fluid, (inner[0] + 4, inner[3] - 8 - liquid_h))
    coil = Image.new("RGBA", (px(90), px(90)), (0, 0, 0, 0))
    cd = ImageDraw.Draw(coil)
    for i in range(7, 0, -1):
        r = int(px(8) * i)
        cd.ellipse([coil.size[0] / 2 - r, coil.size[1] / 2 - r, coil.size[0] / 2 + r, coil.size[1] / 2 + r], outline=(210, 140, 50, 200), width=3)
    ipaste(tank, coil, ((tw - coil.size[0]) // 2, th // 2 - px(10)), coil)
    d.ellipse([0, 0, tw, px(22)], fill=(120, 116, 110), outline=(200, 196, 188))
    d.ellipse([px(15), px(4), tw - px(15), px(18)], fill=(16, 16, 16), outline=(80, 80, 80))
    tank_x = (W - tw) // 2
    tank_y = 620
    im = paste_shadow(im, tank, (tank_x, tank_y), blur=24, opacity=140, dy=16)

    lid_r = px(52)
    lid = Image.new("RGBA", (lid_r * 2, lid_r * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lid)
    ld.ellipse([0, 0, lid_r * 2 - 1, lid_r * 2 - 1], fill=(40, 38, 36, 255), outline=(180, 176, 170, 255), width=4)
    for i in range(12):
        a = math.radians(i * 30)
        x0 = lid_r + math.cos(a) * (lid_r - px(10))
        y0 = lid_r + math.sin(a) * (lid_r - px(10))
        ld.ellipse([x0 - 3, y0 - 6, x0 + 3, y0 + 6], fill=(20, 20, 20, 180))
    ld.rounded_rectangle([lid_r - 4, lid_r - px(14), lid_r + 4, lid_r + px(14)], 3, fill=(210, 205, 198, 255))
    im = paste_shadow(im, lid, ((W - lid.size[0]) // 2, tank_y - px(70)), blur=12, opacity=80, dy=4)

    cass = cassette_body(px(92), px(56))
    ipaste(im, cass, ((W - cass.size[0]) // 2, tank_y + px(18)), cass)
    plate = metal_fill((px(64), px(22)), (200, 196, 188), (130, 124, 116))
    pd = ImageDraw.Draw(plate)
    pd.text((plate.size[0] / 2, plate.size[1] / 2), "38°C", font=ui_font(10 * S, "38°C", True), fill=(28, 26, 24), anchor="mm")
    ipaste(im, plate, (tank_x + tw + px(12), tank_y + px(70)))

    d = ImageDraw.Draw(im)
    d.text((W / 2, tank_y + th + px(40)), "COLOR 400", font=serif_font(16 * S), fill=(230, 220, 210), anchor="mm")
    d.text((W / 2, tank_y + th + px(68)), "送进暗房", font=ui_font(13 * S, "送进暗房"), fill=(140, 120, 110), anchor="mm")
    im = bottom_sprockets(im)
    return im


def shot06(bank):
    im = new_canvas((18, 16, 14))
    caption_block(im, "CONTACT SHEET", "相邻两格，一张对页。")
    im = hatch_bar(im, "COLOR 400", y=268)
    pairs = [
        (photo(bank, "window", (360, 480), "portra"), photo(bank, "portrait", (360, 480), "portra")),
        (photo(bank, "night", (360, 480), "tungsten"), photo(bank, "neon", (360, 480), "tungsten")),
        (photo(bank, "street", (360, 480), "acros"), photo(bank, "city", (360, 480), "acros")),
    ]
    y = 350
    usable = H - 140 - y
    gap = 22
    sh = int((usable - gap * 2) / 3)
    sw = W - px(48)
    for a, b in pairs:
        strip = film_strip([a, b], 360, 480, gutter=8, rebate=36)
        strip = strip.resize((sw, sh), Image.Resampling.LANCZOS)
        im = paste_shadow(im, strip, ((W - sw) // 2, y), blur=12, opacity=90, dy=6)
        y += sh + gap
    d = ImageDraw.Draw(im)
    d.text((W / 2, H - 108), "单格 3:4  ·  对页 3:2", font=ui_font(12 * S, "单格 3:4  ·  对页 3:2"), fill=(100, 96, 90), anchor="mm")
    im = bottom_sprockets(im)
    return im


def refine_icon():
    size = 1024
    im = Image.new("RGB", (size, size), (11, 10, 10))
    rng = random.Random(7)
    dots = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    p = dots.load()
    for _ in range(1400):
        x, y = int(rng.random() * size), int(rng.random() * size)
        p[x, y] = (255, 255, 255, int(8 + rng.random() * 22))
    im = Image.alpha_composite(im.convert("RGBA"), dots).convert("RGB")

    frame_w, frame_h, radius = 440, 590, 72
    fx = (size - frame_w) // 2
    fy = 176
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([fx, fy + 16, fx + frame_w, fy + frame_h + 16], radius, fill=(0, 0, 0, 80))
    im = Image.alpha_composite(im.convert("RGBA"), sh.filter(ImageFilter.GaussianBlur(16))).convert("RGB")

    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, frame_w - 1, frame_h - 1], radius, fill=(34, 33, 32, 255), outline=(86, 84, 82, 255), width=5)
    fd.rounded_rectangle([10, 10, frame_w - 11, frame_h - 11], radius - 10, fill=(31, 30, 29, 255))
    mid = frame_w // 2
    fd.rectangle([mid - 1, 34, mid + 2, frame_h - 34], fill=(8, 8, 8, 255))
    fd.rectangle([mid, 34, mid + 1, frame_h - 34], fill=(20, 20, 20, 255))
    hi = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    ImageDraw.Draw(hi).rounded_rectangle([8, 8, frame_w - 9, 64], radius - 8, fill=(255, 255, 255, 22))
    mask = Image.new("L", (frame_w, frame_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, frame_w - 1, frame_h - 1], radius, fill=255)
    frame = Image.alpha_composite(frame, hi)
    frame.putalpha(mask)
    im.paste(frame, (fx, fy), frame)

    sx, sy, sr = size // 2, fy + frame_h + 88, 44
    d = ImageDraw.Draw(im)
    d.ellipse([sx - sr - 6, sy - sr + 4, sx + sr + 6, sy + sr + 12], fill=(0, 0, 0))
    d.ellipse([sx - sr - 2, sy - sr - 2, sx + sr + 2, sy + sr + 2], fill=(46, 44, 42), outline=(96, 94, 92), width=3)
    d.ellipse([sx - sr + 6, sy - sr + 6, sx + sr - 6, sy + sr - 6], fill=(180, 35, 24))
    hi = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(hi).ellipse([sx - 16, sy - 22, sx + 2, sy - 4], fill=(255, 255, 255, 48))
    im = Image.alpha_composite(im.convert("RGBA"), hi.filter(ImageFilter.GaussianBlur(3))).convert("RGB")
    d = ImageDraw.Draw(im)
    d.ellipse([sx - sr + 6, sy - sr + 6, sx + sr - 6, sy + sr - 6], outline=(122, 42, 36), width=2)
    return grain(im, 6, 0.05)


def preview_strip(paths, dest):
    thumbs = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        tw = 220
        th = int(im.size[1] * tw / im.size[0])
        thumbs.append(im.resize((tw, th), Image.Resampling.LANCZOS))
    gap = 16
    w = len(thumbs) * 220 + (len(thumbs) + 1) * gap
    h = thumbs[0].size[1] + gap * 2
    strip = Image.new("RGB", (w, h), (8, 8, 8))
    x = gap
    for t in thumbs:
        strip.paste(t, (x, gap))
        x += 220 + gap
    strip.save(dest, quality=90)


def main():
    SHOT_DIR.mkdir(parents=True, exist_ok=True)
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    bank = fetch_photos()
    print("photos", list(bank))
    makers = [
        ("01-diptych.png", shot01),
        ("02-body.png", shot02),
        ("03-wait.png", shot03),
        ("04-load.png", shot04),
        ("05-darkroom.png", shot05),
        ("06-album.png", shot06),
    ]
    paths = []
    for name, fn in makers:
        print("render", name)
        im = fn(bank)
        dest = SHOT_DIR / name
        im.save(dest, "PNG", optimize=True)
        paths.append(dest)
        print(" wrote", dest, im.size)
    preview_strip(paths, SHOT_DIR / "_preview.jpg")

    icon = refine_icon()
    icon.save(ICON_DIR / "AppIcon-1024.png", "PNG")
    icon.resize((180, 180), Image.Resampling.LANCZOS).save(ICON_DIR / "AppIcon-180.png", "PNG")
    icon.save(ICON_APP, "PNG")
    print("icon", ICON_APP)


if __name__ == "__main__":
    main()
