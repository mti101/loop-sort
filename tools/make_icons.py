#!/usr/bin/env python3
"""Draws the app icon + store graphics (original artwork, procedural)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RES = os.path.join(ROOT, "tools", "android_overlay", "res")
STORE = os.path.join(ROOT, "store")
FONT = os.path.join(ROOT, "assets", "fonts", "LilitaOne-Regular.ttf")

TILE = [(255, 84, 112), (62, 155, 255), (61, 214, 127), (255, 210, 63), (166, 108, 255), (255, 140, 66)]


def shade(c, a):
    return tuple(max(0, min(255, int(v + a))) for v in c)


def vgrad(size, top, bot):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        col = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = col
    return img


def symbol(d, kind, cx, cy, s, fill):
    if kind == 0:  # heart
        r = s * 0.26
        d.ellipse([cx - r * 1.9, cy - r * 1.5, cx - r * 0.1, cy + r * 0.3], fill=fill)
        d.ellipse([cx + r * 0.1, cy - r * 1.5, cx + r * 1.9, cy + r * 0.3], fill=fill)
        d.polygon([(cx - r * 1.85, cy - r * 0.2), (cx + r * 1.85, cy - r * 0.2), (cx, cy + r * 1.9)], fill=fill)
    elif kind == 1:  # drop
        r = s * 0.3
        d.ellipse([cx - r, cy - r * 0.2, cx + r, cy + r * 1.8], fill=fill)
        d.polygon([(cx, cy - r * 1.6), (cx - r * 0.95, cy + r * 0.45), (cx + r * 0.95, cy + r * 0.45)], fill=fill)
    elif kind == 2:  # leaf (pointed lens rotated)
        pts_top, pts_bot = [], []
        A, B = s * 0.38, s * 0.2
        n = 24
        for i in range(n + 1):
            x = -A + 2 * A * i / n
            yy = B * (1 - (x / A) ** 2) ** 0.75
            pts_top.append((x, -yy))
            pts_bot.append((x, yy))
        pts = pts_top + pts_bot[::-1]
        ang = math.radians(-40)
        rot = [(cx + px * math.cos(ang) - py * math.sin(ang), cy + px * math.sin(ang) + py * math.cos(ang)) for px, py in pts]
        d.polygon(rot, fill=fill)
    else:  # star
        pts = []
        for i in range(10):
            r = s * (0.42 if i % 2 == 0 else 0.18)
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        d.polygon(pts, fill=fill)


def tile(img, cx, cy, s, ci, kind, rot=0):
    """Glossy tile composited onto img (RGBA)."""
    pad = int(s * 0.5)
    layer = Image.new("RGBA", (int(s) + pad * 2, int(s) + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = TILE[ci]
    x0, y0 = pad, pad
    r = int(s * 0.24)
    d.rounded_rectangle([x0, y0 + s * 0.1, x0 + s, y0 + s * 1.04], r, fill=shade(c, -60))
    d.rounded_rectangle([x0, y0, x0 + s, y0 + s * 0.96], r, fill=c)
    d.rounded_rectangle([x0 + s * 0.07, y0 + s * 0.06, x0 + s * 0.93, y0 + s * 0.4], int(r * 0.8), fill=shade(c, 45))
    symbol(d, kind, x0 + s / 2, y0 + s * 0.5, s, (255, 255, 255, 235))
    if rot:
        layer = layer.rotate(rot, resample=Image.BICUBIC, expand=False)
    img.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


def draw_mark(size, with_bg=True, scale=1.0):
    """The Loop Sort mark: a stadium conveyor with tiles riding it."""
    S = size * 2  # supersample
    if with_bg:
        bg = vgrad((S, S), (34, 98, 124), (9, 30, 42)).convert("RGBA")
    else:
        bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S / 2
    w = S * 0.70 * scale
    h = S * 0.46 * scale
    belt = S * 0.19 * scale
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    def rr(grow, color):
        rd.rounded_rectangle([cx - w / 2 - grow, cy - h / 2 - grow, cx + w / 2 + grow, cy + h / 2 + grow],
                             int(h / 2 + grow), fill=color)
    sh = S * 0.016
    rr(belt / 2 + 12 * scale, (4, 16, 22, 255))
    rr(belt / 2 + 3 * scale, (110, 190, 222, 255))
    rr(belt / 2 - 7 * scale, (38, 96, 124, 255))
    rr(-belt / 2 + 7 * scale, (110, 190, 222, 255))
    rr(-belt / 2 + 13 * scale, (0, 0, 0, 0))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.alpha_composite(ring, (0, int(sh)))
    sd = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd.putalpha(shadow.getchannel("A").point(lambda v: int(v * 0.35)))
    bg.alpha_composite(sd)
    bg.alpha_composite(ring)
    d = ImageDraw.Draw(bg)
    def chev(x, y, dirn):
        k = S * 0.028 * scale
        d.line([(x - dirn * k, y - k), (x + dirn * k * 0.5, y), (x - dirn * k, y + k)], fill=(255, 180, 46), width=int(S * 0.014 * scale), joint="curve")
    for fx in (-0.34, 0.06, 0.40):
        chev(cx + w * fx, cy - h / 2, 1)
        chev(cx + w * fx * -1, cy + h / 2, -1)
    chev(cx + w / 2, cy - h * 0.25, 1)
    chev(cx - w / 2, cy + h * 0.25, -1)
    sz = S * 0.205 * scale
    tile(bg, cx - w * 0.22, cy - h / 2, sz, 0, 0, 7)
    tile(bg, cx + w * 0.30, cy - h / 2, sz, 1, 1, -6)
    tile(bg, cx + w / 2, cy, sz, 3, 3, 8)
    tile(bg, cx + w * 0.02, cy + h / 2, sz, 2, 2, -5)
    tile(bg, cx - w / 2, cy, sz, 4, 3, -9)
    return bg.resize((size, size), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def main():
    # Play Store icon 512
    store_icon = draw_mark(512, True, 1.0).convert("RGB")
    save(store_icon, os.path.join(STORE, "icon_512.png"))

    # Legacy launcher icons (rounded square)
    for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        im = draw_mark(px * 4, True, 1.0)
        mask = Image.new("L", im.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], int(im.width * 0.22), fill=255)
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.paste(im, (0, 0), mask)
        out = out.resize((px, px), Image.LANCZOS)
        save(out, os.path.join(RES, f"mipmap-{name}", "ic_launcher.png"))
        # adaptive foreground: 108dp canvas; mark must live in the 66% safe zone
        fg_px = int(px * 108 / 48)
        fg = draw_mark(fg_px, False, 0.62)
        save(fg, os.path.join(RES, f"mipmap-{name}", "ic_launcher_foreground.png"))

    os.makedirs(os.path.join(RES, "mipmap-anydpi-v26"), exist_ok=True)
    with open(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n</adaptive-icon>\n')
    os.makedirs(os.path.join(RES, "values"), exist_ok=True)
    with open(os.path.join(RES, "values", "ic_launcher_colors.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#16465A</color>\n</resources>\n')

    # Feature graphic 1024x500
    W, H = 1024, 500
    fg = vgrad((W, H), (28, 82, 104), (8, 26, 36)).convert("RGBA")
    d = ImageDraw.Draw(fg)
    for gx in range(20, W, 34):
        for gy in range(20, H, 34):
            d.ellipse([gx - 2, gy - 2, gx + 2, gy + 2], fill=(255, 255, 255, 14))
    mark = draw_mark(420, False, 1.05)
    fg.alpha_composite(mark, (W - 470, 40))
    f1 = ImageFont.truetype(FONT, 150)
    f2 = ImageFont.truetype(FONT, 118)
    f3 = ImageFont.truetype(FONT, 40)
    def outlined(x, y, text, font, fill, outline=(8, 28, 38), ow=8):
        for dx in range(-ow, ow + 1, 2):
            for dy in range(-ow, ow + 1, 2):
                if dx * dx + dy * dy <= ow * ow:
                    d.text((x + dx, y + dy + 6), text, font=font, fill=outline)
        d.text((x, y), text, font=font, fill=fill)
    outlined(50, 70, "LOOP", f1, (255, 180, 46), (58, 34, 0), 9)
    outlined(54, 215, "SORT", f2, (255, 255, 255))
    outlined(58, 372, "Plan it. Loop it. Clear it!", f3, (169, 199, 214), (8, 28, 38), 5)
    save(fg.convert("RGB"), os.path.join(STORE, "feature_graphic_1024x500.png"))
    print("icons + store graphics written")


if __name__ == "__main__":
    main()
