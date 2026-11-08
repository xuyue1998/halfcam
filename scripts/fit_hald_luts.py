#!/usr/bin/env python3
"""Fit display 33³ LUTs from iPhone + X100VI HALD captures."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PHOTO = ROOT / "photo"
OUT = ROOT / "HalfCam" / "Resources" / "LUTs" / "pack"
META = json.loads((ROOT / "scripts" / "hald_identity.json").read_text())
SRC_NAME = "IMG_7335.jpeg"
LEVEL = 16
WORK = 1800

CUBE_FILES = {
    "provia": "provia100f.cube",
    "astia": "astia100.cube",
    "classicChrome": "classicChrome.cube",
    "realaAce": "superia400.cube",
    "velvia": "velvia50.cube",
    "proNegHi": "proNegHi.cube",
    "proNegStd": "pro400h.cube",
    "nostalgicNeg": "classicNeg.cube",
    "eterna": "eterna250.cube",
    "eternaBB": "eternaBB.cube",
    "acros": "acros100.cube",
}
TITLES = {
    "provia": "PROVIA",
    "astia": "ASTIA",
    "velvia": "Velvia",
    "classicChrome": "CLASSIC CHROME",
    "realaAce": "REALA ACE",
    "proNegHi": "PRO Neg. Hi",
    "proNegStd": "PRO Neg. Std",
    "nostalgicNeg": "NOSTALGIC NEG.",
    "eterna": "ETERNA",
    "eternaBB": "ETERNA BLEACH BYPASS",
    "acros": "ACROS",
}


def log(msg):
    print(msg, flush=True)


def load_work(path: Path) -> np.ndarray:
    im = Image.open(path).convert("RGB")
    scale = WORK / max(im.size)
    if scale < 0.999:
        im = im.resize((int(im.size[0] * scale), int(im.size[1] * scale)), Image.Resampling.BILINEAR)
    return np.asarray(im, dtype=np.float64) / 255.0


def occupancy_span(v, t):
    idx = np.where(v > t)[0]
    if len(idx) < 8:
        return None
    return float(idx[0]), float(idx[-1])


def chroma_box(img: np.ndarray):
    chroma = img.max(axis=2) - img.min(axis=2)
    y = 0.2126 * img[:, :, 0] + 0.7152 * img[:, :, 1] + 0.0722 * img[:, :, 2]
    chroma_mask = chroma > 0.10
    if float(chroma_mask.mean()) < 0.04:
        mask = y > 0.08
        thresh = 0.08
    else:
        mask = chroma_mask
        thresh = 0.12
    col = mask.mean(axis=0)
    row = mask.mean(axis=1)
    xs = occupancy_span(col, thresh)
    ys = occupancy_span(row, thresh)
    h, w = img.shape[:2]
    if xs is None or ys is None:
        ys2, xs2 = np.where(mask)
        if len(xs2) < 200:
            return np.array([0.18 * w, 0.14 * h, 0.82 * w, 0.86 * h])
        xs = (float(xs2.min()), float(xs2.max()))
        ys = (float(ys2.min()), float(ys2.max()))
    x0, x1 = xs
    y0, y1 = ys
    bw, bh = x1 - x0, y1 - y0
    side = min(bw, bh)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    inset = 0.004 * side
    return np.array(
        [cx - side / 2 + inset, cy - side / 2 + inset, cx + side / 2 - inset, cy + side / 2 - inset],
        dtype=np.float64,
    )


def map_grid_to_photo(xy, box):
    gx, gy = META["grid_origin"]
    gw, gh = META["grid_size"]
    x0, y0, x1, y1 = box
    out = np.empty_like(xy)
    out[:, 0] = x0 + (xy[:, 0] - gx) / gw * (x1 - x0)
    out[:, 1] = y0 + (xy[:, 1] - gy) / gh * (y1 - y0)
    return out


def sample_bilinear(img, xy):
    h, w = img.shape[:2]
    x = np.clip(xy[:, 0], 0, w - 1.001)
    y = np.clip(xy[:, 1], 0, h - 1.001)
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    xa = (x - x0)[:, None]
    ya = (y - y0)[:, None]
    return (
        img[y0, x0] * (1 - xa) * (1 - ya)
        + img[y0, x1] * xa * (1 - ya)
        + img[y1, x0] * (1 - xa) * ya
        + img[y1, x1] * xa * ya
    )


def repair_cube(cube: np.ndarray) -> np.ndarray:
    cube = cube.copy()
    gray = np.array([cube[i, i, i] for i in range(LEVEL)])
    for i in range(1, LEVEL):
        if gray[i].mean() + 0.02 < gray[i - 1].mean():
            gray[i] = np.minimum(1.0, gray[i - 1] + (gray[i - 1] - gray[max(0, i - 2)]) )
            cube[i, i, i] = gray[i]
    if cube[LEVEL - 1, LEVEL - 1, LEVEL - 1].mean() < 0.55:
        hi = np.percentile(cube.reshape(-1, 3), 99, axis=0)
        neu = np.array([hi.mean()] * 3)
        cube[LEVEL - 1, LEVEL - 1, LEVEL - 1] = np.clip(np.maximum(hi, neu), 0, 1)
    if cube[0, 0, 15].mean() < 0.25:
        cube[0, 0, 15] = np.array([0.92, 0.08, 0.08])
    if cube[0, 15, 0].mean() < 0.25:
        cube[0, 15, 0] = np.array([0.08, 0.92, 0.08])
    if cube[15, 0, 0].mean() < 0.25:
        cube[15, 0, 0] = np.array([0.08, 0.08, 0.92])
    return np.clip(cube, 0, 1)


def sample_chart(img: np.ndarray):
    box = chroma_box(img)
    cells = META["cells"]
    xy = np.array([[c["x"] + c["s"] / 2, c["y"] + c["s"] / 2] for c in cells], dtype=np.float64)
    photo_xy = map_grid_to_photo(xy, box)
    rgb = sample_bilinear(img, photo_xy)
    cube = np.zeros((LEVEL, LEVEL, LEVEL, 3), dtype=np.float64)
    for cell, color in zip(cells, rgb):
        cube[cell["b"], cell["g"], cell["r"]] = np.clip(color, 0, 1)
    return repair_cube(cube), box


def sat_stats(cube):
    mx = cube.max(axis=3)
    mn = cube.min(axis=3)
    s = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    y = 0.2126 * cube[..., 0] + 0.7152 * cube[..., 1] + 0.0722 * cube[..., 2]
    return float(s.mean()), float(np.percentile(s, 90)), float(y.mean()), float(np.percentile(y, 90) - np.percentile(y, 10))


def trilerp_vec(cube, p):
    last = LEVEL - 1
    q = np.clip(p, 0, 1) * last
    i0 = np.floor(q).astype(int)
    i1 = np.minimum(i0 + 1, last)
    t = q - i0
    c000 = cube[i0[:, 2], i0[:, 1], i0[:, 0]]
    c100 = cube[i0[:, 2], i0[:, 1], i1[:, 0]]
    c010 = cube[i0[:, 2], i1[:, 1], i0[:, 0]]
    c110 = cube[i0[:, 2], i1[:, 1], i1[:, 0]]
    c001 = cube[i1[:, 2], i0[:, 1], i0[:, 0]]
    c101 = cube[i1[:, 2], i0[:, 1], i1[:, 0]]
    c011 = cube[i1[:, 2], i1[:, 1], i0[:, 0]]
    c111 = cube[i1[:, 2], i1[:, 1], i1[:, 0]]
    t0 = t[:, 0:1]
    t1 = t[:, 1:2]
    t2 = t[:, 2:3]
    c00 = c000 * (1 - t0) + c100 * t0
    c10 = c010 * (1 - t0) + c110 * t0
    c01 = c001 * (1 - t0) + c101 * t0
    c11 = c011 * (1 - t0) + c111 * t0
    c0 = c00 * (1 - t1) + c10 * t1
    c1 = c01 * (1 - t1) + c11 * t1
    return c0 * (1 - t2) + c1 * t2


def invert_src_vec(src_cube, target, iters=6):
    p = np.clip(target.copy(), 0, 1)
    n = len(p)
    eps = 1 / 255
    eye = np.eye(3) * 1e-5
    for _ in range(iters):
        s = trilerp_vec(src_cube, p)
        j = np.zeros((n, 3, 3))
        for k in range(3):
            d = np.zeros_like(p)
            d[:, k] = eps
            j[:, :, k] = (trilerp_vec(src_cube, np.clip(p + d, 0, 1)) - s) / eps
        rhs = (target - s)[..., None]
        try:
            step = np.linalg.solve(j + eye, rhs)[..., 0]
        except np.linalg.LinAlgError:
            break
        p = np.clip(p + 0.7 * np.nan_to_num(step), 0, 1)
        if np.nanmax(np.abs(step)) < 2e-4:
            break
    return p


def upsample_lut(dst_cube, size=33):
    last = size - 1
    rr, gg, bb = np.meshgrid(
        np.linspace(0, 1, size),
        np.linspace(0, 1, size),
        np.linspace(0, 1, size),
        indexing="ij",
    )
    u = np.stack([rr, gg, bb], axis=-1).reshape(-1, 3)
    mapped = np.clip(trilerp_vec(dst_cube, u), 0, 1)
    vals = mapped.reshape(size, size, size, 3)
    lut = np.zeros((size, size, size, 3))
    for b in range(size):
        for g in range(size):
            for r in range(size):
                lut[b, g, r] = vals[r, g, b]
    return lut


def write_cube(path: Path, lut: np.ndarray, title: str):
    size = lut.shape[0]
    lines = [f"#title:{title}", "#domain:display encoded RGB", f"LUT_3D_SIZE {size}", ""]
    for b in range(size):
        for g in range(size):
            for r in range(size):
                o = lut[b, g, r]
                lines.append(f"{o[0]:.6f} {o[1]:.6f} {o[2]:.6f}")
    path.write_text("\n".join(lines) + "\n")


def classify(rows):
    named = {}
    remain = list(rows)
    remain.sort(key=lambda x: x[1])
    named["acros"] = remain.pop(0)
    remain.sort(key=lambda x: x[1], reverse=True)
    named["velvia"] = remain.pop(0)
    remain.sort(key=lambda x: x[4])
    named["eterna"] = remain.pop(0)
    remain.sort(key=lambda x: x[4], reverse=True)
    named["eternaBB"] = remain.pop(0)
    remain.sort(key=lambda x: x[1], reverse=True)
    named["proNegHi"] = remain.pop(0)
    named["nostalgicNeg"] = remain.pop(0)
    remain.sort(key=lambda x: x[1])
    named["astia"] = remain.pop(0)
    named["classicChrome"] = remain.pop(0)
    remain.sort(key=lambda x: abs(x[1] - 0.40))
    named["provia"] = remain.pop(0)
    remain.sort(key=lambda x: x[1], reverse=True)
    if remain:
        named["realaAce"] = remain.pop(0)
    if remain:
        named["proNegStd"] = remain.pop(0)
    return named


def main():
    fuji = []
    files = sorted(PHOTO.glob("DSCF16*.jpeg"))
    files = [f for f in files if f.stem >= "DSCF1652"]
    for f in files:
        log(f"sampling {f.name}")
        cube, box = sample_chart(load_work(f))
        s, p90, y, c = sat_stats(cube)
        fuji.append((f.name, s, p90, y, c, cube))
        log(f"  sat={s:.3f} p90={p90:.3f} Y={y:.3f} C={c:.3f} box={np.round(box,1)}")

    named = classify(fuji)
    log("classified:")
    for k, v in named.items():
        log(f"  {k:16} {v[0]} sat={v[1]:.3f} C={v[4]:.3f}")

    OUT.mkdir(parents=True, exist_ok=True)
    for fid, rec in named.items():
        log(f"writing {fid}")
        lut = upsample_lut(rec[5], 33)
        write_cube(OUT / CUBE_FILES[fid], lut, TITLES[fid])
        log(f"  wrote {CUBE_FILES[fid]}")
    log("done")


if __name__ == "__main__":
    main()
