#!/usr/bin/env python3
"""Draws the Sweet Arrows app icon: Jelly, a happy pink heart gummy with big eyes,
riding a white arrow over a bright candy sky with sparkles and little sweets.

Run:  python3 Tools/Icon/make_icon.py   (needs Pillow)
Writes the 1024 px icon into the asset catalog, plus the launch-screen and website copies.
No text in the icon (PLAN.md)."""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 3
W = S * SS
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
random.seed(5)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def heart(cx, cy, r, steps=600):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * r, cy - y * r))
    return pts


def star(cx, cy, r_out, r_in, points=4, rot=0.0):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / points - math.pi / 2
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


img = Image.new("RGB", (W, W))
d = ImageDraw.Draw(img)

# Bright candy sky: lilac → pink → peach, diagonal.
top, mid, bottom = (124, 108, 255), (255, 120, 190), (255, 196, 120)
for y in range(W):
    t = y / W
    color = lerp(top, mid, t / 0.55) if t < 0.55 else lerp(mid, bottom, (t - 0.55) / 0.45)
    d.line([(0, y), (W, y)], fill=color)

# Soft sunburst rays from behind Jelly.
rays = Image.new("L", (W, W), 0)
rd = ImageDraw.Draw(rays)
cx, cy = W * 0.5, W * 0.53
for i in range(16):
    a0 = 2 * math.pi * i / 16
    a1 = a0 + math.pi / 16
    rd.polygon([(cx, cy), (cx + math.cos(a0) * W, cy + math.sin(a0) * W), (cx + math.cos(a1) * W, cy + math.sin(a1) * W)], fill=40)
rays = rays.filter(ImageFilter.GaussianBlur(W * 0.01))
img.paste((255, 255, 255), mask=rays)

# Little sweets floating in the background (one per candy color).
for (fx, fy, color, size) in [
    (0.16, 0.18, (255, 210, 63), 0.06), (0.84, 0.16, (61, 220, 151), 0.055), (0.12, 0.80, (91, 108, 255), 0.05),
    (0.87, 0.78, (255, 159, 28), 0.06), (0.18, 0.50, (255, 210, 63), 0.035),
]:
    x, y, r = fx * W, fy * W, size * W
    d.ellipse([x - r * 1.08, y - r * 1.08, x + r * 1.08, y + r * 1.08], fill=(255, 255, 255))
    d.ellipse([x - r, y - r, x + r, y + r], fill=color)
    d.ellipse([x - r * 0.55, y - r * 0.6, x - r * 0.1, y - r * 0.3], fill=(255, 255, 255))

# Sparkles.
for (fx, fy, size) in [(0.30, 0.12, 0.035), (0.70, 0.10, 0.025), (0.92, 0.33, 0.03), (0.07, 0.36, 0.025), (0.62, 0.90, 0.03), (0.33, 0.92, 0.022)]:
    d.polygon(star(fx * W, fy * W, size * W, size * W * 0.3), fill=(255, 255, 255))

# The arrow, shooting diagonally up-right behind Jelly and out of the frame.
ang = math.radians(-38)
def rot(px, py, ox, oy):
    return (ox + px * math.cos(ang) - py * math.sin(ang), oy + px * math.sin(ang) + py * math.cos(ang))
ox, oy = W * 0.46, W * 0.58
outline = (74, 44, 42)
shaft = [(-W * 0.46, -W * 0.045), (W * 0.30, -W * 0.045), (W * 0.30, W * 0.045), (-W * 0.46, W * 0.045)]
head = [(W * 0.26, -W * 0.13), (W * 0.52, 0), (W * 0.26, W * 0.13)]
feathers = [(-W * 0.46, -W * 0.045), (-W * 0.56, -W * 0.12), (-W * 0.50, 0), (-W * 0.56, W * 0.12), (-W * 0.46, W * 0.045)]
for poly in (shaft, head, feathers):
    pts = [rot(x, y, ox, oy) for x, y in poly]
    d.polygon(pts, fill=outline)
    shrink = [rot(x * 0.985, y * 0.8, ox, oy) for x, y in poly]
    d.polygon(shrink, fill=(255, 255, 255))

# Jelly: glossy pink heart with a white rim and a soft shadow.
jx, jy, jr = W * 0.47, W * 0.56, W * 0.0205
shadow = Image.new("L", (W, W), 0)
ImageDraw.Draw(shadow).polygon(heart(jx, jy + W * 0.035, jr), fill=110)
shadow = shadow.filter(ImageFilter.GaussianBlur(W * 0.022))
img.paste((120, 40, 90), mask=shadow)
d = ImageDraw.Draw(img)
d.polygon(heart(jx, jy, jr * 1.07), fill=(255, 255, 255))
# Body with a vertical gradient (lighter top).
body = Image.new("RGB", (W, W))
bd = ImageDraw.Draw(body)
for y in range(W):
    t = min(max((y - (jy - W * 0.3)) / (W * 0.55), 0), 1)
    bd.line([(0, y), (W, y)], fill=lerp((255, 130, 170), (240, 60, 120), t))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).polygon(heart(jx, jy, jr), fill=255)
img.paste(body, mask=mask)
d = ImageDraw.Draw(img)
# Gloss highlights.
d.ellipse([jx - W * 0.25, jy - W * 0.24, jx - W * 0.11, jy - W * 0.16], fill=(255, 200, 220))
d.ellipse([jx - W * 0.09, jy - W * 0.22, jx - W * 0.05, jy - W * 0.18], fill=(255, 225, 235))

# Big friendly eyes with sparkles.
for ex in (jx - W * 0.10, jx + W * 0.10):
    ey = jy - W * 0.035
    d.ellipse([ex - W * 0.068, ey - W * 0.078, ex + W * 0.068, ey + W * 0.078], fill=(255, 255, 255))
    d.ellipse([ex - W * 0.045, ey - W * 0.045, ex + W * 0.050, ey + W * 0.065], fill=(60, 34, 40))
    d.ellipse([ex - W * 0.030, ey - W * 0.032, ex + W * 0.000, ey - W * 0.002], fill=(255, 255, 255))
    d.ellipse([ex + W * 0.015, ey + W * 0.022, ex + W * 0.030, ey + W * 0.037], fill=(255, 255, 255))
# Rosy cheeks.
for chx in (jx - W * 0.185, jx + W * 0.185):
    d.ellipse([chx - W * 0.042, jy + W * 0.035, chx + W * 0.042, jy + W * 0.072], fill=(255, 150, 175))
# Big open smile with a little tongue.
mx, my = jx, jy + W * 0.075
d.chord([mx - W * 0.075, my - W * 0.05, mx + W * 0.075, my + W * 0.075], 0, 180, fill=(110, 30, 50))
d.chord([mx - W * 0.04, my + W * 0.015, mx + W * 0.04, my + W * 0.07], 0, 180, fill=(255, 120, 140))

img = img.resize((S, S), Image.LANCZOS)
icon_path = os.path.join(ROOT, "SweetArrows", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
img.save(icon_path)
launch_dir = os.path.join(ROOT, "SweetArrows", "Resources", "Assets.xcassets", "LaunchIcon.imageset")
rounded = Image.new("L", (S, S), 0)
ImageDraw.Draw(rounded).rounded_rectangle([0, 0, S, S], radius=int(S * 0.22), fill=255)
launch = img.convert("RGBA")
launch.putalpha(rounded)
launch.resize((360, 360), Image.LANCZOS).save(os.path.join(launch_dir, "LaunchIcon@3x.png"))
launch.resize((240, 240), Image.LANCZOS).save(os.path.join(launch_dir, "LaunchIcon@2x.png"))
launch.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "docs", "site", "icon.png"))
print("icon written:", os.path.abspath(icon_path))
