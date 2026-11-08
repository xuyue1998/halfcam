#!/usr/bin/env python3
import math, os, random, struct, wave, zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "HalfCam"))
SND = os.path.join(ROOT, "Resources", "Sounds")
ICON = os.path.join(ROOT, "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
os.makedirs(SND, exist_ok=True)
os.makedirs(os.path.dirname(ICON), exist_ok=True)

SR = 44100
random.seed(7)


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        buf = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            buf += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(buf))


def noise():
    return random.uniform(-1, 1)


def sine(i, f):
    return math.sin(2 * math.pi * f * i / SR)


def env(i, n, a=0.004, r=0.05):
    t = i / SR
    dur = n / SR
    if t < a:
        return t / max(a, 1e-6)
    if t > dur - r:
        return max(0.0, (dur - t) / max(r, 1e-6))
    return 1.0


def shutter():
    n = int(SR * 0.16)
    out = [0.0] * n
    for imp, amp, decay in ((int(SR * 0.004), 0.95, 90), (int(SR * 0.026), 0.72, 58)):
        for i in range(n - imp):
            t = i / SR
            e = math.exp(-decay * t)
            out[imp + i] += noise() * amp * e
            out[imp + i] += sine(i, 1750) * amp * 0.22 * e
    return out


def empty():
    n = int(SR * 0.11)
    out = []
    for i in range(n):
        t = i / SR
        out.append((noise() * 0.35 + sine(i, 82) * 0.55) * math.exp(-26 * t))
    return out


def wind():
    n = int(SR * 0.2)
    out = []
    for i in range(n):
        t = i / SR
        f = 130 + 90 * t
        out.append((sine(i, f) * 0.38 + noise() * 0.16) * env(i, n, 0.012, 0.05) * 0.85)
    return out


def tick():
    n = int(SR * 0.028)
    out = []
    for i in range(n):
        t = i / SR
        out.append((noise() * 0.75 + sine(i, 2550) * 0.28) * math.exp(-130 * t))
    return out


def back():
    n = int(SR * 0.18)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        out[i] += (noise() * 0.48 + sine(i, 430) * 0.4) * math.exp(-42 * t)
    delay = int(SR * 0.048)
    for i in range(delay, n):
        t = (i - delay) / SR
        out[i] += (noise() * 0.32 + sine(i, 200) * 0.5) * math.exp(-28 * t) * 0.85
    return out


def rewind():
    n = int(SR * 1.15)
    out = []
    for i in range(n):
        t = i / SR
        f = 88 + 36 * math.sin(t * 16)
        click = 1.0 if int(t * 22) != int((t - 1 / SR) * 22) else 0.0
        out.append((sine(i, f) * 0.28 + noise() * 0.1 + click * noise() * 0.35) * env(i, n, 0.04, 0.16))
    return out


def water():
    n = int(SR * 2.0)
    out = []
    lp = 0.0
    for i in range(n):
        lp = lp * 0.87 + noise() * 0.13
        t = i / SR
        bubble = sine(i, 680 + 90 * math.sin(t * 3.2)) * 0.09 * (0.5 + 0.5 * math.sin(t * 6.5))
        out.append((lp * 0.65 + bubble) * env(i, n, 0.18, 0.4) * 0.55)
    return out


def reveal():
    n = int(SR * 0.85)
    out = []
    for i in range(n):
        out.append((sine(i, 196) * 0.22 + sine(i, 392) * 0.1 + noise() * 0.04) * env(i, n, 0.07, 0.32))
    return out


write_wav(os.path.join(SND, "shutter.wav"), shutter())
write_wav(os.path.join(SND, "empty.wav"), empty())
write_wav(os.path.join(SND, "wind.wav"), wind())
write_wav(os.path.join(SND, "tick.wav"), tick())
write_wav(os.path.join(SND, "back.wav"), back())
write_wav(os.path.join(SND, "rewind.wav"), rewind())
write_wav(os.path.join(SND, "water.wav"), water())
write_wav(os.path.join(SND, "reveal.wav"), reveal())


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    raw = bytearray()
    row = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * row : (y + 1) * row])
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


W = 1024
px = bytearray(W * W * 4)
bg = (18, 18, 20)


def setp(x, y, r, g, b, a=255):
    if 0 <= x < W and 0 <= y < W:
        i = (y * W + x) * 4
        px[i : i + 4] = bytes((int(r), int(g), int(b), int(a)))


for y in range(W):
    for x in range(W):
        setp(x, y, *bg)

cx, cy = 512, 500
fw, fh = 430, 574
x0, y0 = cx - fw // 2, cy - fh // 2
rad = 28


def in_round_rect(x, y, x0, y0, w, h, r):
    if x0 + r <= x <= x0 + w - r and y0 <= y <= y0 + h:
        return True
    if x0 <= x <= x0 + w and y0 + r <= y <= y0 + h - r:
        return True
    corners = ((x0 + r, y0 + r), (x0 + w - r, y0 + r), (x0 + r, y0 + h - r), (x0 + w - r, y0 + h - r))
    for cx, cy in corners:
        if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
            return True
    return False


for y in range(y0 - 10, y0 + fh + 10):
    for x in range(x0 - 10, x0 + fw + 10):
        if in_round_rect(x, y, x0 - 8, y0 - 8, fw + 16, fh + 16, rad + 6):
            setp(x, y, 70, 70, 74)
        if in_round_rect(x, y, x0, y0, fw, fh, rad):
            inside = 36, 36, 38
            if x < cx:
                inside = 42, 42, 46
            setp(x, y, *inside)
        if abs(x - cx) <= 2 and y0 + 8 <= y <= y0 + fh - 8:
            setp(x, y, 12, 12, 14)

# red shutter
for y in range(W):
    for x in range(W):
        d2 = (x - 512) ** 2 + (y - 900) ** 2
        if d2 <= 28 * 28:
            setp(x, y, 176, 28, 32)
        elif d2 <= 34 * 34:
            setp(x, y, 90, 90, 94)

write_png(ICON, W, W, px)
print("assets ok")
