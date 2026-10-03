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
    elif kind == 2:  # leaf
        pts = []
        for i in range(0, 361, 10):
            a = math.radians(i)
            pts.append((cx + s * 0.34 * math.cos(a) * (1 - 0.0), cy + s * 0.22 * math.sin(a) * 1.4))
        d.polygon(pts, fill=fill)
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
    """The Loop Sort mark: a stadium conveyor with tiles."""
    S = size * 2  # supersample
    if with_bg:
        bg = vgrad((S, S), (34, 98, 124), (9, 30, 42)).convert("RGBA")
    else:
        bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(bg)
    cx = cy = S / 2
    w = S * 0.60 * scale
    h = S * 0.36 * scale
    belt = S * 0.115 * scale
    # belt (stadium) rails
    def stadium(inflate, color):
        d.rounded_rectangle([cx - w / 2 - inflate, cy - h / 2 - inflate, cx + w / 2 + inflate, cy + h / 2 + inflate],
                            int(h / 2 + inflate), outline=color, width=int(belt))
    stadium(belt * 0.0 + 8 * scale, (7, 24, 32))
    stadium(0, (47, 112, 144))
    inner = belt * 0.62
    d.rounded_rectangle([cx - w / 2 + belt * 0.0, cy - h / 2, cx + w / 2, cy + h / 2], int(h / 2),
                        outline=(23, 63, 82), width=int(inner))
    # amber arrow chevrons on belt
    for k in range(7):
        a = k / 7 * 2 * math.pi
        # sample point on stadium centreline
        px = cx + (w / 2 - h / 2) * (1 if math.cos(a) > 0 else -1) * 0 + 0
    # tiles around
    sz = S * 0.205 * scale
    tile(bg, cx - w * 0.29, cy - h / 2, sz, 0, 0, 8)
    tile(bg, cx + w * 0.29, cy - h / 2, sz, 1, 1, -6)
    tile(bg, cx + w / 2 - 2, cy + 0, sz * 0.95, 3, 3, 10)
    tile(bg, cx, cy + h / 2, sz, 2, 2, -4)
    tile(bg, cx - w / 2 + 2, cy + 0, sz * 0.95, 4, 3, -8)
    # centre arrow (loop sign)
    d2 = ImageDraw.Draw(bg)
    r = S * 0.07 * scale
    d2.arc([cx - r, cy - r, cx + r, cy + r], 40, 320, fill=(255, 180, 46), width=int(S * 0.022 * scale))
    ax, ay = cx + r * math.cos(math.radians(40)), cy + r * math.sin(math.radians(40))
    d2.polygon([(ax - S * 0.002, ay - S * 0.03 * scale), (ax + S * 0.035 * scale, ay + S * 0.006 * scale), (ax - S * 0.03 * scale, ay + S * 0.016 * scale)], fill=(255, 180, 46))
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
