#!/usr/bin/env python3
"""Pack SimplePhoto samples into HalfCam/Resources/samples.

Drop 2–3 photos into each film folder (or a shared _tag folder).
Then run:

    python3 scripts/pack_samples.py
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image, ExifTags
    from PIL.ExifTags import IFD
except ImportError:
    Image = None
    ExifTags = None
    IFD = None

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "SimplePhoto"
OUT = ROOT / "HalfCam" / "Resources" / "samples"
MAX_EDGE = 960
JPEG_QUALITY = 72
PER_ROLL = 3

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".tif", ".tiff", ".bmp"}

FILMS = [
    ("fujifilm_provia_100f", "PROVIA 100F", "provia", "slide"),
    ("kodak_ektachrome_100", "EKTACHROME 100", "astia", "slide"),
    ("fujifilm_velvia_100", "VELVIA 100", "velvia", "slide"),
    ("kodak_kodachrome_64", "KODACHROME 64", "astia", "slide"),
    ("kodak_portra_160", "PORTRA 160", "classicChrome", "color"),
    ("kodak_portra_400", "PORTRA 400", "proNegStd", "color"),
    ("kodak_portra_800", "PORTRA 800", "proNegHi", "color"),
    ("kodak_portra_800_push1", "PORTRA 800 +1", "proNegHi", "color"),
    ("kodak_portra_800_push2", "PORTRA 800 +2", "proNegHi", "color"),
    ("kodak_gold_200", "GOLD 200", "nostalgicNeg", "color"),
    ("kodak_ektar_100", "EKTAR 100", "velvia", "color"),
    ("kodak_ultramax_400", "ULTRAMAX 400", "realaAce", "color"),
    ("fujifilm_xtra_400", "SUPERIA 400", "realaAce", "color"),
    ("fujifilm_c200", "C200", "nostalgicNeg", "color"),
    ("fujifilm_pro_400h", "PRO 400H", "proNegStd", "color"),
    ("cinestill_800t", "CINESTILL 800T", "eternaBB", "color"),
    ("kodak_vision3_50d", "VISION3 50D", "eterna", "cine"),
    ("kodak_vision3_250d", "VISION3 250D", "eterna", "cine"),
    ("kodak_vision3_200t", "VISION3 200T", "eterna", "cine"),
    ("kodak_vision3_500t", "VISION3 500T", "eternaBB", "cine"),
    ("kodak_verita_200d", "VERITA 200D", "eterna", "cine"),
    ("fujifilm_neopan_acros_100_ii", "ACROS 100 II", "acros", "bw"),
    ("kodak_tmax_100", "T-MAX 100", "acros", "bw"),
    ("kodak_tri_x_400", "TRI-X 400", "acros", "bw"),
    ("ilford_hp5_plus_400", "HP5 PLUS 400", "acros", "bw"),
]

SHARED = {
    "_人像": ["classicChrome", "proNegStd", "proNegHi"],
    "_风景": ["velvia", "provia"],
    "_日常": ["nostalgicNeg", "realaAce"],
    "_夜色": ["eternaBB"],
    "_电影": ["eterna", "eternaBB"],
    "_黑白": ["acros"],
    "_幻灯": ["slide"],
    "_彩色": ["color"],
    "人像": ["classicChrome", "proNegStd", "proNegHi"],
    "风景": ["velvia", "provia"],
    "日常": ["nostalgicNeg", "realaAce"],
    "夜色": ["eternaBB"],
    "电影": ["eterna", "eternaBB"],
    "黑白": ["acros"],
    "幻灯": ["slide"],
    "彩色": ["color"],
    "portrait": ["classicChrome", "proNegStd", "proNegHi"],
    "landscape": ["velvia", "provia"],
    "daily": ["nostalgicNeg", "realaAce"],
    "night": ["eternaBB"],
    "cine": ["eterna", "eternaBB"],
    "bw": ["acros"],
    "slide": ["slide"],
    "color": ["color"],
}

EXTRA_ALIASES = {
    "provia": "fujifilm_provia_100f",
    "provia100f": "fujifilm_provia_100f",
    "ektachrome": "kodak_ektachrome_100",
    "ektachrome100": "kodak_ektachrome_100",
    "astia": "kodak_ektachrome_100",
    "velvia": "fujifilm_velvia_100",
    "velvia100": "fujifilm_velvia_100",
    "kodachrome": "kodak_kodachrome_64",
    "kodachrome64": "kodak_kodachrome_64",
    "portra160": "kodak_portra_160",
    "p160": "kodak_portra_160",
    "portra400": "kodak_portra_400",
    "p400": "kodak_portra_400",
    "portra": "kodak_portra_400",
    "portra800": "kodak_portra_800",
    "p800": "kodak_portra_800",
    "portra800push1": "kodak_portra_800_push1",
    "portra800+1": "kodak_portra_800_push1",
    "p800+1": "kodak_portra_800_push1",
    "portra800push2": "kodak_portra_800_push2",
    "portra800+2": "kodak_portra_800_push2",
    "p800+2": "kodak_portra_800_push2",
    "gold": "kodak_gold_200",
    "gold200": "kodak_gold_200",
    "ektar": "kodak_ektar_100",
    "ektar100": "kodak_ektar_100",
    "ultramax": "kodak_ultramax_400",
    "ultramax400": "kodak_ultramax_400",
    "superia": "fujifilm_xtra_400",
    "superia400": "fujifilm_xtra_400",
    "xtra400": "fujifilm_xtra_400",
    "c200": "fujifilm_c200",
    "pro400h": "fujifilm_pro_400h",
    "400h": "fujifilm_pro_400h",
    "cinestill": "cinestill_800t",
    "cinestill800t": "cinestill_800t",
    "800t": "cinestill_800t",
    "vision350d": "kodak_vision3_50d",
    "50d": "kodak_vision3_50d",
    "vision3250d": "kodak_vision3_250d",
    "250d": "kodak_vision3_250d",
    "vision3200t": "kodak_vision3_200t",
    "200t": "kodak_vision3_200t",
    "vision3500t": "kodak_vision3_500t",
    "500t": "kodak_vision3_500t",
    "verita": "kodak_verita_200d",
    "verita200d": "kodak_verita_200d",
    "acros": "fujifilm_neopan_acros_100_ii",
    "acros100": "fujifilm_neopan_acros_100_ii",
    "tmax": "kodak_tmax_100",
    "tmax100": "kodak_tmax_100",
    "trix": "kodak_tri_x_400",
    "trix400": "kodak_tri_x_400",
    "hp5": "ilford_hp5_plus_400",
    "hp5plus": "ilford_hp5_plus_400",
    "hp5plus400": "ilford_hp5_plus_400",
}


def norm(text: str) -> str:
    t = text.lower().strip()
    for brand in ("kodak_", "kodak ", "fujifilm_", "fuji ", "ilford_", "ilford ", "cinestill_"):
        if t.startswith(brand):
            t = t[len(brand):]
    drop = " _-./·()[]"
    out = []
    for ch in t:
        if ch in drop:
            continue
        out.append(ch)
    return "".join(out)


def build_maps():
    by_key = {}
    by_id = {}
    for film_id, name, family, group in FILMS:
        rec = {"id": film_id, "name": name, "family": family, "group": group}
        by_id[film_id] = rec
        for key in (film_id, name, family):
            by_key[norm(key)] = film_id
        by_key[norm(film_id.replace("_", ""))] = film_id
    for alias, film_id in EXTRA_ALIASES.items():
        by_key[norm(alias)] = film_id
    shared = {norm(k): v for k, v in SHARED.items()}
    return by_key, by_id, shared


def is_image(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTS and not path.name.startswith(".")


def exif_tag(path: Path) -> str:
    if Image is None:
        return ""
    try:
        with Image.open(path) as im:
            desc = im.info.get("description") or im.info.get("Description") or ""
            if isinstance(desc, bytes):
                desc = desc.decode("utf-8", "ignore")
            if desc:
                return str(desc).strip()
            exif = im.getexif()
            if not exif:
                return ""
            for key in ("ImageDescription", "XPTitle", "Artist"):
                for code, name in ExifTags.TAGS.items():
                    if name == key and code in exif:
                        value = exif.get(code)
                        if isinstance(value, bytes):
                            value = value.decode("utf-8", "ignore")
                        if value:
                            return str(value).strip()
            try:
                extra = exif.get_ifd(IFD.Exif)
            except Exception:
                extra = {}
            for code, value in extra.items():
                name = ExifTags.TAGS.get(code, "")
                if name in {"ImageDescription", "UserComment"} and value:
                    if isinstance(value, bytes):
                        value = value.decode("utf-8", "ignore")
                    text = str(value).strip()
                    if text:
                        return text
    except Exception:
        return ""
    return ""


def collect_images(folder: Path) -> list[Path]:
    if not folder.exists():
        return []
    files = [p for p in folder.iterdir() if is_image(p)]
    files.sort(key=lambda p: p.name.lower())
    return files


def convert(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        jpeg = Path(tmp) / "in.jpg"
        try:
            subprocess.run(
                ["sips", "-s", "format", "jpeg", str(src), "--out", str(jpeg)],
                check=True,
                capture_output=True,
            )
        except subprocess.CalledProcessError as exc:
            raise RuntimeError(f"sips failed on {src.name}: {exc.stderr.decode('utf-8', 'ignore')}") from exc
        subprocess.run(
            [
                "sips",
                "-Z",
                str(MAX_EDGE),
                "-s",
                "formatOptions",
                str(JPEG_QUALITY),
                str(jpeg),
                "--out",
                str(dest),
            ],
            check=True,
            capture_output=True,
        )
        if Image is not None:
            with Image.open(dest) as im:
                rgb = im.convert("RGB")
                rgb.save(dest, "JPEG", quality=JPEG_QUALITY, optimize=True)


def assign(src_files: dict[str, list[Path]], by_id: dict) -> dict[str, list[Path]]:
    chosen: dict[str, list[Path]] = {film_id: [] for film_id in by_id}
    used: dict[str, set[str]] = {film_id: set() for film_id in by_id}

    def add(film_id: str, path: Path) -> bool:
        key = str(path.resolve())
        if key in used[film_id]:
            return False
        if len(chosen[film_id]) >= PER_ROLL:
            return False
        chosen[film_id].append(path)
        used[film_id].add(key)
        return True

    for film_id in by_id:
        for path in src_files.get(film_id, []):
            add(film_id, path)

    for film_id, rec in by_id.items():
        if len(chosen[film_id]) >= 2:
            continue
        for path in src_files.get(f"family:{rec['family']}", []):
            if len(chosen[film_id]) >= PER_ROLL:
                break
            add(film_id, path)

    for film_id, rec in by_id.items():
        if len(chosen[film_id]) >= 2:
            continue
        for path in src_files.get(f"group:{rec['group']}", []):
            if len(chosen[film_id]) >= PER_ROLL:
                break
            add(film_id, path)

    return chosen


def scan(by_key, by_id, shared) -> dict[str, list[Path]]:
    buckets: dict[str, list[Path]] = {}

    def put(key: str, path: Path):
        buckets.setdefault(key, []).append(path)

    if not SRC.exists():
        return buckets

    for item in sorted(SRC.iterdir(), key=lambda p: p.name.lower()):
        if item.name.startswith(".") or item.name in {"README.md", "README.txt"}:
            continue
        tag = item.name
        if tag.startswith("_"):
            tag = tag[1:]
        key = norm(item.stem if item.is_file() else item.name)

        if item.is_dir():
            images = collect_images(item)
            if key in by_key:
                for path in images:
                    put(by_key[key], path)
                continue
            if key in shared:
                for token in shared[key]:
                    kind = "group" if token in {"color", "slide", "cine", "bw"} else "family"
                    for path in images:
                        put(f"{kind}:{token}", path)
                continue
            print(f"skip folder (unknown tag): {item.name}")
            continue

        if not is_image(item):
            continue
        tagged = match_file(item, key, by_key, shared, put)
        if not tagged:
            print(f"skip file (unknown tag): {item.name}")
    return buckets


def match_file(item: Path, key: str, by_key, shared, put) -> bool:
    tag = exif_tag(item)
    if tag:
        tkey = norm(tag)
        if tkey in by_key:
            put(by_key[tkey], item)
            return True
        if tkey in shared:
            for token in shared[tkey]:
                kind = "group" if token in {"color", "slide", "cine", "bw"} else "family"
                put(f"{kind}:{token}", item)
            return True
    if key in by_key:
        put(by_key[key], item)
        return True
    if key in shared:
        for token in shared[key]:
            kind = "group" if token in {"color", "slide", "cine", "bw"} else "family"
            put(f"{kind}:{token}", item)
        return True
    for alias, film_id in by_key.items():
        if alias and key.startswith(alias):
            put(film_id, item)
            return True
    return False


def write_samples(chosen: dict[str, list[Path]], by_id: dict) -> dict:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"edge": MAX_EDGE, "rolls": {}}
    for film_id, rec in by_id.items():
        dest_dir = OUT / film_id
        names = []
        for i, src in enumerate(chosen.get(film_id, []), start=1):
            dest = dest_dir / f"{i:02d}.jpg"
            convert(src, dest)
            names.append(dest.name)
        if names:
            manifest["rolls"][film_id] = {
                "name": rec["name"],
                "count": len(names),
                "files": names,
            }
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return manifest


def report(chosen: dict[str, list[Path]], by_id: dict) -> int:
    missing = 0
    print("")
    print(f"{'film':<32} {'have':>4}  source")
    print("-" * 72)
    for film_id, rec in by_id.items():
        files = chosen.get(film_id, [])
        n = len(files)
        if n < 2:
            missing += 1
        src = ", ".join(p.parent.name if p.parent != SRC else p.name for p in files) or "-"
        mark = "ok" if n >= 2 else "!!"
        print(f"{rec['name']:<32} {n:>4}  {mark}  {src}")
    print("-" * 72)
    if missing:
        print(f"{missing} rolls still need at least 2 photos.")
    else:
        print("all rolls have at least 2 samples.")
    return missing


def main() -> int:
    by_key, by_id, shared = build_maps()
    buckets = scan(by_key, by_id, shared)
    total = sum(len(v) for k, v in buckets.items() if not k.startswith(("family:", "group:")))
    shared_n = sum(len(v) for k, v in buckets.items() if k.startswith(("family:", "group:")))
    print(f"found {total} tagged photos, {shared_n} shared photos in {SRC}")
    chosen = assign(buckets, by_id)
    missing = report(chosen, by_id)
    packed = sum(1 for files in chosen.values() if files)
    if packed == 0:
        print("\nSimplePhoto is empty. Drop photos into the film folders, then rerun.")
        return 0
    write_samples(chosen, by_id)
    print(f"\npacked {packed} rolls into {OUT.relative_to(ROOT)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
