#!/usr/bin/env python3
import math
import os
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PHOTO = ROOT / "photo"
OUT = ROOT / "HalfCam" / "Resources" / "LUTs" / "pack"
SRC_NAME = "IMG_7309.jpeg"

FILMS = [
    ("DSCF1641.jpeg", "provia", "PROVIA"),
    ("DSCF1643.jpeg", "astia", "ASTIA"),
    ("DSCF1644.jpeg", "classicChrome", "CLASSIC CHROME"),
    ("DSCF1645.jpeg", "realaAce", "REALA ACE"),
    ("DSCF1646.jpeg", "velvia", "Velvia"),
    ("DSCF1642.jpeg", "proNegHi", "PRO Neg. Hi"),
    ("DSCF1648.jpeg", "proNegStd", "PRO Neg. Std"),
    ("DSCF1647.jpeg", "nostalgicNeg", "NOSTALGIC NEG."),
    ("DSCF1649.jpeg", "eterna", "ETERNA"),
    ("DSCF1650.jpeg", "eternaBB", "ETERNA BLEACH BYPASS"),
    ("DSCF1651.jpeg", "acros", "ACROS"),
]

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

P3_TO_XYZ = [
    [0.486570948648216, 0.265667693169093, 0.198217285234362],
    [0.228974564069749, 0.691738521836506, 0.079286914093745],
    [0.000000000000000, 0.045113381858903, 1.043944368900976],
]
XYZ_TO_SRGB = [
    [3.2404542, -1.5371385, -0.4985314],
    [-0.9692660, 1.8760108, 0.0415560],
    [0.0556434, -0.2040259, 1.0572252],
]


def matvec(m, v):
    return [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]


def mul3(a, b):
    out = [[0.0] * 3 for _ in range(3)]
    for i in range(3):
        for j in range(3):
            out[i][j] = a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j]
    return out


P3_TO_SRGB = mul3(XYZ_TO_SRGB, P3_TO_XYZ)


def srgb_eotf(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def srgb_oetf(c):
    c = max(0.0, c)
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def p3_encoded_to_srgb_encoded(rgb):
    lin = [srgb_eotf(x) for x in rgb]
    s = matvec(P3_TO_SRGB, lin)
    return [min(1.0, max(0.0, srgb_oetf(x))) for x in s]


def luma(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def find_chart(im):
    small = im.resize((240, 160))
    w, h = small.size
    pix = small.load()
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            r, g, b = pix[x, y][:3]
            if luma(r, g, b) > 38:
                xs.append(x)
                ys.append(y)
    if not xs:
        return (int(im.size[0] * 0.18), int(im.size[1] * 0.12), int(im.size[0] * 0.82), int(im.size[1] * 0.88))
    xs.sort()
    ys.sort()

    def pct(a, q):
        return a[int((len(a) - 1) * q)]

    x0 = pct(xs, 0.035) / 240 * im.size[0]
    x1 = pct(xs, 0.965) / 240 * im.size[0]
    y0 = pct(ys, 0.055) / 160 * im.size[1]
    y1 = pct(ys, 0.945) / 160 * im.size[1]
    return int(x0), int(y0), int(x1), int(y1)


def sample_grid(im, box, cols=6, rows=4, inset=0.32):
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    pw = w / cols
    ph = h / rows
    pix = im.load()
    W, H = im.size
    out = []
    for r in range(rows):
        row = []
        for c in range(cols):
            cx = x0 + (c + 0.5) * pw
            cy = y0 + (r + 0.5) * ph
            rw = pw * (1 - 2 * inset)
            rh = ph * (1 - 2 * inset)
            xa = max(0, int(cx - rw / 2))
            ya = max(0, int(cy - rh / 2))
            xb = min(W - 1, int(cx + rw / 2))
            yb = min(H - 1, int(cy + rh / 2))
            rs = gs = bs = n = 0
            step = max(1, (xb - xa) // 14)
            for y in range(ya, yb, step):
                for x in range(xa, xb, step):
                    r0, g0, b0 = pix[x, y][:3]
                    rs += r0
                    gs += g0
                    bs += b0
                    n += 1
            row.append((rs / n / 255.0, gs / n / 255.0, bs / n / 255.0) if n else (0, 0, 0))
        out.append(row)
    return out


def flatten(grid):
    return [p for row in grid for p in row]


def gauss(a, b):
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for i in range(n):
        piv = max(range(i, n), key=lambda r: abs(m[r][i]))
        m[i], m[piv] = m[piv], m[i]
        if abs(m[i][i]) < 1e-12:
            m[i][i] = 1e-12
        f = m[i][i]
        for j in range(i, n + 1):
            m[i][j] /= f
        for r in range(n):
            if r == i:
                continue
            f = m[r][i]
            for j in range(i, n + 1):
                m[r][j] -= f * m[i][j]
    return [m[i][n] for i in range(n)]


def fit_affine(src, dst, lam=0.08):
    n = len(src)
    xtx = [[0.0] * 4 for _ in range(4)]
    xty = [[0.0] * 3 for _ in range(4)]
    for (r, g, b), (rr, gg, bb) in zip(src, dst):
        x = [r, g, b, 1.0]
        y = [rr, gg, bb]
        for i in range(4):
            for j in range(4):
                xtx[i][j] += x[i] * x[j]
            for k in range(3):
                xty[i][k] += x[i] * y[k]
    ident = [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
        [0.0, 0.0, 0.0],
    ]
    cols = []
    for k in range(3):
        a = [[xtx[i][j] + (lam if i == j else 0.0) for j in range(4)] for i in range(4)]
        b = [xty[i][k] + lam * ident[i][k] for i in range(4)]
        cols.append(gauss(a, b))
    # 4x3: row is [r g b 1] weights for each output channel
    M = [[cols[k][i] for k in range(3)] for i in range(4)]
    return M


def apply_m(M, rgb):
    r, g, b = rgb
    x = [r, g, b, 1.0]
    out = [0.0, 0.0, 0.0]
    for k in range(3):
        s = 0.0
        for i in range(4):
            s += x[i] * M[i][k]
        out[k] = min(1.0, max(0.0, s))
    return out


def write_cube(path, M, title, size=33):
    lines = [
        f"#title:{title}",
        "#domain:display sRGB",
        f"LUT_3D_SIZE {size}",
        "",
    ]
    last = size - 1
    for bi in range(size):
        for gi in range(size):
            for ri in range(size):
                rgb = (ri / last, gi / last, bi / last)
                o = apply_m(M, rgb)
                lines.append(f"{o[0]:.6f} {o[1]:.6f} {o[2]:.6f}")
    path.write_text("\n".join(lines) + "\n")


def load_work(path):
    im = Image.open(path).convert("RGB")
    scale = 1100 / max(im.size)
    if scale < 0.999:
        im = im.resize((int(im.size[0] * scale), int(im.size[1] * scale)), Image.Resampling.BILINEAR)
    return im


def rmse(src, dst, M):
    e = 0.0
    for a, b in zip(src, dst):
        p = apply_m(M, a)
        e += (p[0] - b[0]) ** 2 + (p[1] - b[1]) ** 2 + (p[2] - b[2]) ** 2
    return math.sqrt(e / len(src))


def main():
    src_im = load_work(PHOTO / SRC_NAME)
    src_grid = sample_grid(src_im, find_chart(src_im))
    src = [p3_encoded_to_srgb_encoded(list(p)) for p in flatten(src_grid)]
    print("source patches", len(src), "white", [round(x, 3) for x in src[18]], "black", [round(x, 3) for x in src[23]])
    OUT.mkdir(parents=True, exist_ok=True)
    for fname, fid, title in FILMS:
        dst_im = load_work(PHOTO / fname)
        dst = flatten(sample_grid(dst_im, find_chart(dst_im)))
        extra_s = src + [(0, 0, 0), (1, 1, 1)]
        extra_d = dst + [(0, 0, 0), dst[18]]
        M = fit_affine(extra_s, extra_d, lam=0.12 if fid == "acros" else 0.06)
        err = rmse(src, dst, M)
        out = OUT / CUBE_FILES[fid]
        write_cube(out, M, title)
        print(f"{fid:16} {title:24} rmse={err:.4f} -> {out.name}")


if __name__ == "__main__":
    main()
