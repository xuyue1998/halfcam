#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

PATCHES = [
    [(115, 82, 68), (194, 150, 130), (98, 122, 157), (87, 108, 67), (133, 128, 177), (103, 189, 170)],
    [(214, 126, 44), (80, 91, 166), (193, 90, 99), (94, 60, 108), (157, 188, 64), (224, 163, 46)],
    [(56, 61, 150), (70, 148, 73), (175, 54, 60), (231, 199, 31), (187, 86, 149), (8, 133, 161)],
    [(243, 243, 242), (200, 200, 200), (160, 160, 160), (122, 122, 121), (85, 85, 85), (52, 52, 52)],
]

NAMES = [
    ["dark skin", "light skin", "blue sky", "foliage", "blue flower", "bluish green"],
    ["orange", "purplish blue", "moderate red", "purple", "yellow green", "orange yellow"],
    ["blue", "green", "red", "yellow", "magenta", "cyan"],
    ["white", "neutral 8", "neutral 6.5", "neutral 5", "neutral 3.5", "black"],
]

COLS, ROWS = 6, 4
W, H = 3840, 2560
MARGIN = 160
GAP = 18
BAR = 96

def font(size):
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()

def main():
    img = Image.new("RGB", (W, H), (18, 18, 18))
    draw = ImageDraw.Draw(img)
    inner_top = MARGIN
    inner_bottom = H - MARGIN - BAR
    inner_left = MARGIN
    inner_right = W - MARGIN
    grid_w = inner_right - inner_left
    grid_h = inner_bottom - inner_top
    pw = (grid_w - GAP * (COLS - 1)) // COLS
    ph = (grid_h - GAP * (ROWS - 1)) // ROWS
    title = font(36)
    caption = font(22)
    for r in range(ROWS):
        for c in range(COLS):
            x = inner_left + c * (pw + GAP)
            y = inner_top + r * (ph + GAP)
            draw.rectangle([x, y, x + pw - 1, y + ph - 1], fill=PATCHES[r][c])
            label = NAMES[r][c]
            tw = draw.textlength(label, font=caption)
            tx = x + (pw - tw) / 2
            ty = y + ph - 36
            draw.rectangle([tx - 8, ty - 4, tx + tw + 8, ty + 26], fill=(0, 0, 0))
            draw.text((tx, ty), label, fill=(255, 255, 255), font=caption)
    hint = "ColorChecker Classic  ·  sRGB  ·  全屏  ·  正对  ·  关 True Tone / 自动亮度"
    hw = draw.textlength(hint, font=title)
    draw.text(((W - hw) / 2, H - MARGIN - BAR + 28), hint, fill=(210, 210, 210), font=title)
    out = os.path.join(os.path.dirname(__file__), "colorchecker_classic.png")
    img.save(out, "PNG")
    print(out)

if __name__ == "__main__":
    main()
