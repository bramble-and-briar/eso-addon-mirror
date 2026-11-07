"""Generates the Bloom HPS pastel textures (flowers, sparkle, heart, shield, panel)
as DXT5 .dds files with mipmaps, plus .png previews.

Usage (from the add-on folder; needs Pillow 11.2+):
    python tools/gen_textures.py textures tools/previews

Edit the `textures` table at the bottom to change colours or shapes.
After adding NEW texture files, fully restart ESO - /reloadui won't see them.
"""
import math
import struct
import sys
from PIL import Image, ImageDraw, ImageFilter

import os

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else os.path.join("tools", "previews")
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREVIEW, exist_ok=True)
SS = 4  # supersampling


def write_dds(img, path):
    img = img.convert("RGBA")
    w, h = img.size
    mips = []
    cur = img
    while True:
        mips.append(cur)
        if cur.size == (1, 1):
            break
        cur = cur.resize((max(1, cur.size[0] // 2), max(1, cur.size[1] // 2)), Image.LANCZOS)
    # DXT5 (BC3) with a full mip chain, the same layout as the game's own textures.
    import io
    blobs = []
    for m in mips:
        if m.size[0] < 4:  # DXT blocks are 4x4; pad tiny mips
            pad = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
            pad.paste(m, (0, 0))
            m = pad
        buf = io.BytesIO()
        m.save(buf, format="DDS", pixel_format="DXT5")
        blobs.append(buf.getvalue()[128:])
    flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000  # caps|h|w|pixelformat|mipmapcount|linearsize
    header = struct.pack("<4sIIIIIII44x", b"DDS ", 124, flags, h, w, len(blobs[0]), 0, len(mips))
    header += struct.pack("<II4sIIIII", 32, 0x4, b"DXT5", 0, 0, 0, 0, 0)
    header += struct.pack("<IIIII", 0x1000 | 0x400000 | 0x8, 0, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(header)
        for blob in blobs:
            f.write(blob)


def hexc(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lerp(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def finish(big, size):
    return big.resize((size, size), Image.LANCZOS)


def petal_poly(cx, cy, angle, length, width, notch=0.0, steps=60):
    """Teardrop petal from centre outwards; optional notch at the tip (sakura)."""
    pts = []
    for i in range(steps + 1):
        t = i / steps  # 0..1 along one side then back
        # outline parametrised over angle u in [0, pi]
        u = math.pi * t
        r = length * math.sin(u / 2) ** 0.8
        # width profile
        side = math.sin(u) * width * (0.6 + 0.4 * math.sin(u / 2))
        pts.append((r, side))
    pts += [(x, -y) for (x, y) in reversed(pts)]
    out = []
    for (x, y) in pts:
        if notch and x > length * 0.9 and abs(y) < width * notch:
            x -= (width * notch - abs(y)) * 0.9
        ca, sa = math.cos(angle), math.sin(angle)
        out.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return out


def flower(size, n_petals, petal_len, petal_w, base, tip, centre, centre_r, notch=0.0, rot=-math.pi / 2,
           layers=1):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S / 2
    for layer in range(layers):
        lrot = rot + (math.pi / n_petals if layer else 0)
        lscale = 1.0 - 0.28 * layer
        for p in range(n_petals):
            ang = lrot + 2 * math.pi * p / n_petals
            # gradient: draw several shrinking copies, tip colour -> base colour
            for k in range(14, -1, -1):
                t = k / 14
                col = lerp(base, tip, t)
                L = petal_len * S * lscale * (0.25 + 0.75 * t)
                W = petal_w * S * lscale * (0.35 + 0.65 * t)
                d = ImageDraw.Draw(img)
                d.polygon(petal_poly(cx, cy, ang, L, W, notch), fill=col)
        # soft white highlight vein (own layer so it blends instead of replacing)
        veins = Image.new("RGBA", (S, S), (255, 255, 255, 0))
        d = ImageDraw.Draw(veins)
        for p in range(n_petals):
            ang = lrot + 2 * math.pi * p / n_petals
            L = petal_len * S * lscale
            x1, y1 = cx + math.cos(ang) * L * 0.25, cy + math.sin(ang) * L * 0.25
            x2, y2 = cx + math.cos(ang) * L * 0.62, cy + math.sin(ang) * L * 0.62
            d.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 110), width=max(1, int(S * 0.012)))
        img.alpha_composite(veins)
    d = ImageDraw.Draw(img)
    R = centre_r * S
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=centre)
    # stamen dots
    for i in range(8):
        a = 2 * math.pi * i / 8 + 0.3
        rx, ry = cx + math.cos(a) * R * 0.62, cy + math.sin(a) * R * 0.62
        rr = R * 0.18
        d.ellipse([rx - rr, ry - rr, rx + rr, ry + rr], fill=(255, 250, 225, 255))
    return finish(img, size)


def heart(size, fill, light):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(400):
        t = 2 * math.pi * i / 400
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((S / 2 + x * S / 36, S * 0.47 - y * S / 36))
    d.polygon(pts, fill=fill)
    # glossy highlight
    hl = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([S * 0.24, S * 0.22, S * 0.40, S * 0.36], fill=light)
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.02))
    img.alpha_composite(Image.composite(hl, Image.new("RGBA", (S, S), (255, 255, 255, 0)), img.split()[3]))
    return finish(img, size)


def shield(size, fill, rim, light):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def outline(inset):
        pts = []
        top, bot = S * 0.1 + inset, S * 0.92 - inset * 1.3
        left, right = S * 0.16 + inset, S * 0.84 - inset
        # top edge with soft dip in the middle
        for i in range(41):
            t = i / 40
            x = left + (right - left) * t
            y = top + math.sin(math.pi * t) * S * 0.05
            pts.append((x, y))
        # right side curving to the point
        for i in range(1, 41):
            t = i / 40
            x = right - (right - S / 2) * (t ** 1.6)
            y = top + (bot - top) * t
            pts.append((x, y))
        for i in range(39, 0, -1):
            t = i / 40
            x = left + (S / 2 - left) * (t ** 1.6)
            y = top + (bot - top) * t
            pts.append((x, y))
        return pts

    d.polygon(outline(0), fill=rim)
    d.polygon(outline(S * 0.07), fill=fill)
    hl = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    ImageDraw.Draw(hl).ellipse([S * 0.28, S * 0.22, S * 0.42, S * 0.40], fill=light)
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.02))
    img.alpha_composite(Image.composite(hl, Image.new("RGBA", (S, S), (255, 255, 255, 0)), img.split()[3]))
    return finish(img, size)


def sparkle(size, col):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    pts = []
    for i in range(8):
        a = -math.pi / 2 + math.pi * i / 4
        r = S * 0.48 if i % 2 == 0 else S * 0.09
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=col)
    glow = img.filter(ImageFilter.GaussianBlur(S * 0.05))
    glow.alpha_composite(img)
    return finish(glow, size)


def panel(size, radius, fill, border, border_w, inner, inner_w):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = radius * SS
    d.rounded_rectangle([0, 0, S - 1, S - 1], R, fill=border)
    bw = border_w * SS
    d.rounded_rectangle([bw, bw, S - 1 - bw, S - 1 - bw], R - bw, fill=fill)
    gap = bw + 2 * SS
    iw = inner_w * SS
    d.rounded_rectangle([gap, gap, S - 1 - gap, S - 1 - gap], R - gap, outline=inner, width=iw)
    return finish(img, size)


textures = {
    "flower_sakura": flower(128, 5, 0.47, 0.17, hexc("ff8fc0"), hexc("ffe6f2"), hexc("ffd36e"), 0.085,
                            notch=0.35),
    "flower_lavender": flower(128, 8, 0.46, 0.10, hexc("a98cff"), hexc("efe6ff"), hexc("ffe08a"), 0.09,
                              layers=2),
    "flower_mint": flower(128, 6, 0.46, 0.15, hexc("7fdcb8"), hexc("e8fff5"), hexc("fff0a8"), 0.08),
    "sparkle": sparkle(64, hexc("fff6fb")),
    "heart_cute": heart(64, hexc("ff8fbf"), (255, 255, 255, 200)),
    "shield_cute": shield(64, hexc("b9a6ff"), hexc("f3edff"), (255, 255, 255, 190)),
    "panel": panel(64, 18, hexc("2e1b33", 205), hexc("ffa8d2", 245), 2, hexc("ffffff", 60), 1),
}

for name, img in textures.items():
    write_dds(img, f"{OUT}/{name}.dds")
    img.save(f"{PREVIEW}/{name}.png")
    print("wrote", name, img.size)
