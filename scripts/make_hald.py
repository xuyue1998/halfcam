#!/usr/bin/env python3
"""16³ HALD identity chart for iPhone + X100VI display LUT capture.

Layout: 4×4 tiles of 16×16 RG planes (one tile per B). Square, screen-friendly.
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

LEVEL = 16
TILE = 4
CELL = 28
GAP = 1
TILE_GAP = 10
MARGIN = 110
FID = 84
HEADER = 100
FOOTER = 70
BG = (22, 22, 22)
INK = (230, 230, 230)
MUTED = (150, 150, 150)


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


def fiducial(draw, x, y, size):
    draw.rectangle([x, y, x + size - 1, y + size - 1], fill=(255, 255, 255))
    i = max(6, size // 7)
    draw.rectangle([x + i, y + i, x + size - 1 - i, y + size - 1 - i], fill=(0, 0, 0))
    j = i * 2
    draw.rectangle([x + j, y + j, x + size - 1 - j, y + size - 1 - j], fill=(255, 255, 255))


def main():
    tile_px = LEVEL * CELL + (LEVEL - 1) * GAP
    grid_w = TILE * tile_px + (TILE - 1) * TILE_GAP
    grid_h = grid_w
    w = MARGIN * 2 + grid_w
    h = HEADER + MARGIN + grid_h + FOOTER + MARGIN
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    gx = MARGIN
    gy = HEADER + MARGIN
    cells = []
    for bi in range(LEVEL):
        tx = bi % TILE
        ty = bi // TILE
        ox = gx + tx * (tile_px + TILE_GAP)
        oy = gy + ty * (tile_px + TILE_GAP)
        for gi in range(LEVEL):
            for ri in range(LEVEL):
                x = ox + ri * (CELL + GAP)
                y = oy + gi * (CELL + GAP)
                r = int(round(ri / (LEVEL - 1) * 255))
                g = int(round(gi / (LEVEL - 1) * 255))
                b = int(round(bi / (LEVEL - 1) * 255))
                draw.rectangle([x, y, x + CELL - 1, y + CELL - 1], fill=(r, g, b))
                cells.append({"r": ri, "g": gi, "b": bi, "x": x, "y": y, "s": CELL})
    fiducial(draw, 18, 18, FID)
    fiducial(draw, w - 18 - FID, 18, FID)
    fiducial(draw, 18, h - 18 - FID, FID)
    fiducial(draw, w - 18 - FID, h - 18 - FID, FID)
    title = font(32)
    small = font(20)
    t1 = "HALD 16³ identity  ·  4096 patches  ·  sRGB"
    t2 = "全屏  ·  正对  ·  关 True Tone / 自动亮度  ·  四角标都拍进画面"
    w1 = draw.textlength(t1, font=title)
    w2 = draw.textlength(t2, font=small)
    draw.text(((w - w1) / 2, 26), t1, fill=INK, font=title)
    draw.text(((w - w2) / 2, 62), t2, fill=MUTED, font=small)
    foot = "iPhone 拍 1 张  ·  X100VI 每种模拟各 1 张  ·  原片导入，勿进手机相册"
    wf = draw.textlength(foot, font=small)
    draw.text(((w - wf) / 2, h - MARGIN - FOOTER + 22), foot, fill=MUTED, font=small)
    out = os.path.join(os.path.dirname(__file__), "hald_identity.png")
    img.save(out, "PNG")
    meta = {
        "level": LEVEL,
        "tile": TILE,
        "cell": CELL,
        "gap": GAP,
        "tile_gap": TILE_GAP,
        "grid_origin": [gx, gy],
        "grid_size": [grid_w, grid_h],
        "image_size": [w, h],
        "order": "4x4 tiles of 16x16 RG, tile index = B, x=R y=G inside tile",
        "file": out,
        "cells": cells,
    }
    with open(os.path.join(os.path.dirname(__file__), "hald_identity.json"), "w") as f:
        json.dump(meta, f)
    print(out)
    print(f"{w}x{h}  4x4 tiles of {LEVEL}x{LEVEL}  cell {CELL}px  patches {len(cells)}")


if __name__ == "__main__":
    main()
