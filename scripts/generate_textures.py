#!/usr/bin/env python3
import math, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "HalfCam", "Assets.xcassets"))


def imageset(name, img):
    d = os.path.join(ROOT, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, f"{name}.png"), "PNG")
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write(
            '{\n  "images" : [{"filename" : "%s.png", "idiom" : "universal", "scale" : "1x"}],\n  "info" : {"author" : "xcode", "version" : 1}\n}\n'
            % name
        )


def metal_cylinder(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx = w / 2
    for y in range(h):
        v = y / max(1, h - 1)
        for x in range(w):
            nx = (x - cx) / (w * 0.42)
            if abs(nx) > 1:
                continue
            rim = math.sqrt(max(0.0, 1 - nx * nx))
            shade = 0.22 + 0.55 * (1 - abs(nx) ** 1.4) + 0.18 * rim
            if 0.08 < v < 0.12 or 0.88 < v < 0.93:
                shade *= 0.55
            r = int(48 + shade * 140)
            g = int(46 + shade * 130)
            b = int(42 + shade * 110)
            a = 255 if abs(nx) < 0.98 else int(255 * (1 - abs(nx)) / 0.02)
            px[x, y] = (min(255, r), min(255, g), min(255, b), a)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    draw = ImageDraw.Draw(img)
    draw.ellipse([w * 0.12, 2, w * 0.88, h * 0.08], outline=(210, 205, 195, 90), width=2)
    return img


def tank():
    w, h = 520, 780
    base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body = metal_cylinder(420, 640)
    base.paste(body, (50, 90), body)
    lid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lid)
    d.ellipse([70, 40, 450, 150], fill=(70, 66, 60, 255))
    d.ellipse([90, 52, 430, 138], fill=(120, 112, 100, 255))
    d.ellipse([160, 70, 360, 120], fill=(50, 46, 42, 255))
    for i in range(8):
        ang = i / 8 * math.pi
        x0 = 260 + math.cos(ang) * 40
        y0 = 95 + math.sin(ang) * 12
        d.rectangle([x0 - 3, y0 - 8, x0 + 3, y0 + 8], fill=(30, 28, 26, 200))
    base = Image.alpha_composite(base, lid)
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([90, 700, 430, 760], fill=(0, 0, 0, 80))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    return Image.alpha_composite(shadow, base)


def chem_glass():
    w, h = 480, 760
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx = w / 2
    for y in range(h):
        for x in range(w):
            nx = (x - cx) / (w * 0.38)
            if abs(nx) > 1:
                continue
            glass = 40 + int(80 * (1 - abs(nx)))
            edge = abs(nx) > 0.92
            a = 210 if abs(nx) < 0.97 else int(210 * (1 - (abs(nx) - 0.97) / 0.03))
            if edge:
                px[x, y] = (200, 210, 220, min(255, a + 40))
            else:
                px[x, y] = (glass + 20, glass + 28, glass + 36, a)
    highlight = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.ellipse([110, 80, 190, 620], fill=(255, 255, 255, 28))
    return Image.alpha_composite(img, highlight.filter(ImageFilter.GaussianBlur(6)))


def cassette():
    w, h = 420, 260
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([20, 40, 400, 220], radius=70, fill=(28, 28, 30, 255))
    d.rounded_rectangle([28, 48, 392, 212], radius=64, fill=(18, 18, 20, 255))
    d.ellipse([55, 70, 175, 190], outline=(90, 90, 94, 255), width=6)
    d.ellipse([70, 85, 160, 175], fill=(40, 40, 44, 255))
    d.rounded_rectangle([250, 55, 390, 85], radius=4, fill=(170, 170, 175, 255))
    for i in range(10):
        col = (10, 10, 12, 255) if i % 2 == 0 else (200, 200, 205, 255)
        d.rectangle([258 + i * 12, 60, 266 + i * 12, 80], fill=col)
    d.rectangle([330, 130, 400, 210], fill=(210, 140, 40, 255))
    d.rectangle([330, 130, 400, 138], fill=(30, 20, 8, 180))
    return img.filter(ImageFilter.SMOOTH)


def paper_lid():
    w, h = 368, 88
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=6, fill=(236, 232, 224, 255))
    d.line([8, h - 6, w - 8, h - 6], fill=(40, 40, 40, 40), width=2)
    noise = Image.effect_noise((w, h), 18).convert("L")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    p, n, s = out.load(), noise.load(), img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = s[x, y]
            k = (n[x, y] - 128) // 18
            p[x, y] = (max(0, r + k), max(0, g + k), max(0, b + k), a)
    return out


def safelight_bg():
    w, h = 750, 1334
    img = Image.new("RGB", (w, h), (12, 4, 4))
    px = img.load()
    for y in range(h):
        for x in range(w):
            dx = (x - w * 0.5) / w
            dy = (y - h * 0.12) / h
            dist = math.sqrt(dx * dx + dy * dy)
            t = max(0.0, 1 - dist * 1.6)
            px[x, y] = (int(12 + 70 * t), int(4 + 8 * t), int(4 + 6 * t))
    return img.filter(ImageFilter.GaussianBlur(12))


def film_strip_edge():
    w, h = 640, 120
    img = Image.new("RGBA", (w, h), (8, 8, 8, 255))
    d = ImageDraw.Draw(img)
    for i in range(18):
        x = 12 + i * 35
        d.rounded_rectangle([x, 8, x + 18, 22], radius=2, fill=(220, 220, 220, 255))
        d.rounded_rectangle([x, h - 22, x + 18, h - 8], radius=2, fill=(220, 220, 220, 255))
    return img


imageset("DarkroomTank", tank())
imageset("DarkroomChemGlass", chem_glass())
imageset("FilmCassette", cassette())
imageset("PaperLid", paper_lid())
imageset("SafelightBG", safelight_bg())
imageset("FilmStripEdge", film_strip_edge())
print("textures ok")
