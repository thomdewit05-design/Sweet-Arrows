#!/usr/bin/env python3
"""Draws the App Store promotional artwork (the wide image Apple uses when it features the app).

Apple's guidelines for this artwork: no text, no app icon, no device or screenshot, the main subject in
the middle (the edges are cropped differently in different places). So: the smiling lemon star from the
icon riding a big white arrow across a candy sky, with the game's candies and their arrows around it.

Run: python3 Tools/AppStore/make_banner.py
Writes docs/appstore/banner/banner-3840x1646.png and banner-5244x2950.png.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "docs", "appstore", "banner")
INK = (74, 44, 42)
COL = {
    "lemon": (255, 210, 63), "mint": (61, 220, 151), "blue": (91, 108, 255),
    "orange": (255, 159, 28), "grape": (162, 89, 255), "pink": (255, 92, 138),
}
SS = 2  # supersampling


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def lighten(c, a):
    return lerp(c, (255, 255, 255), a)


def darken(c, a):
    return lerp(c, (0, 0, 0), a)


def round_poly(pts, rad, steps=8):
    out = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        v1 = (p0[0] - p1[0], p0[1] - p1[1])
        v2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*v1) or 1, math.hypot(*v2) or 1
        r = min(rad, l1 / 2, l2 / 2)
        a = (p1[0] + v1[0] / l1 * r, p1[1] + v1[1] / l1 * r)
        b = (p1[0] + v2[0] / l2 * r, p1[1] + v2[1] / l2 * r)
        for k in range(steps + 1):
            t = k / steps
            # quadratic bezier a -> p1 -> b
            x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * b[0]
            y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * b[1]
            out.append((x, y))
    return out


def star_pts(cx, cy, ro, ri, n=5, rot=0):
    return [(cx + math.cos(rot + math.pi * i / n - math.pi / 2) * (ro if i % 2 == 0 else ri),
             cy + math.sin(rot + math.pi * i / n - math.pi / 2) * (ro if i % 2 == 0 else ri)) for i in range(2 * n)]


def shape_poly(kind, cx, cy, r):
    if kind == "circle":
        return [(cx + math.cos(t) * r, cy + math.sin(t) * r) for t in [i / 120 * 2 * math.pi for i in range(120)]]
    if kind == "star":
        return round_poly(star_pts(cx, cy, r * 1.1, r * 0.55), r * 0.12)
    if kind == "diamond":
        return round_poly([(cx, cy - r * 1.08), (cx + r * 0.95, cy), (cx, cy + r * 1.08), (cx - r * 0.95, cy)], r * 0.18)
    if kind == "square":
        return round_poly([(cx - r * .88, cy - r * .88), (cx + r * .88, cy - r * .88),
                           (cx + r * .88, cy + r * .88), (cx - r * .88, cy + r * .88)], r * 0.35)
    if kind == "drop":
        pts = []
        for i in range(120):
            t = i / 120 * 2 * math.pi
            x, y = math.sin(t) * r * 0.9, -math.cos(t) * r
            if math.cos(t) > 0:
                k = math.cos(t)
                x *= (1 - k) ** 0.9
                y *= 1.15
            pts.append((cx + x, cy + y + r * 0.1))
        return pts
    raise ValueError(kind)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w * SS, h * SS
        self.img = Image.new("RGB", (self.w, self.h))
        self.u = self.h  # unit: the height

    def sky(self, top, bottom, cx, cy):
        d = ImageDraw.Draw(self.img)
        for x in range(self.w):  # diagonal-ish: blend by x with a little y below
            pass
        grad = Image.new("RGB", (2, 2))
        grad.putpixel((0, 0), top)
        grad.putpixel((1, 0), lerp(top, bottom, 0.6))
        grad.putpixel((0, 1), lerp(top, bottom, 0.4))
        grad.putpixel((1, 1), bottom)
        self.img = grad.resize((self.w, self.h), Image.BILINEAR)
        mask = Image.new("L", (self.w, self.h), 0)
        md = ImageDraw.Draw(mask)
        X, Y, R = self.w * cx, self.h * cy, max(self.w, self.h) * 1.5
        for i in range(24):
            a0 = 2 * math.pi * i / 24
            a1 = a0 + math.pi / 24
            md.polygon([(X, Y), (X + math.cos(a0) * R, Y + math.sin(a0) * R), (X + math.cos(a1) * R, Y + math.sin(a1) * R)],
                       fill=30)
        glow = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(glow).ellipse([X - self.u * .6, Y - self.u * .6, X + self.u * .6, Y + self.u * .6], fill=70)
        mask = Image.composite(mask, mask, mask)
        self.img.paste((255, 255, 255), mask=mask.filter(ImageFilter.GaussianBlur(self.u * 0.004)))
        self.img.paste((255, 255, 255), mask=glow.filter(ImageFilter.GaussianBlur(self.u * 0.2)))
        del d

    def shadow(self, poly, off, blur, alpha=80):
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        pad = int(blur * 3 + off)
        box = (int(min(xs)) - pad, int(min(ys)) - pad, int(max(xs)) + pad, int(max(ys)) + pad)
        m = Image.new("L", (box[2] - box[0], box[3] - box[1]), 0)
        ImageDraw.Draw(m).polygon([(x - box[0], y + off - box[1]) for x, y in poly], fill=alpha)
        self.img.paste(darken((120, 60, 90), 0.2), box[:2], m.filter(ImageFilter.GaussianBlur(blur)))

    def candy(self, kind, color, cx, cy, r, direction=None, face=False):
        poly = shape_poly(kind, cx, cy, r)
        self.shadow(poly, r * 0.14, r * 0.14)
        d = ImageDraw.Draw(self.img)
        d.polygon(shape_poly(kind, cx, cy, r * 1.1), fill=(255, 255, 255))
        box = (int(cx - r * 1.3), int(cy - r * 1.3), int(cx + r * 1.3), int(cy + r * 1.3))
        body = Image.new("RGB", (box[2] - box[0], box[3] - box[1]))
        bd = ImageDraw.Draw(body)
        top, bot = lighten(color, 0.25), darken(color, 0.12)
        for y in range(body.height):
            bd.line([(0, y), (body.width, y)], fill=lerp(top, bot, y / body.height))
        m = Image.new("L", body.size, 0)
        ImageDraw.Draw(m).polygon([(x - box[0], y - box[1]) for x, y in poly], fill=255)
        self.img.paste(body, box[:2], m)
        d = ImageDraw.Draw(self.img)
        if kind == "star":  # the star's arms are narrow: keep the shine inside the body
            d.ellipse([cx - r * .42, cy - r * .5, cx - r * .02, cy - r * .26], fill=lighten(color, 0.6))
            d.ellipse([cx - r * .34, cy - r * .45, cx - r * .16, cy - r * .34], fill=(255, 255, 255))
        else:
            d.ellipse([cx - r * .62, cy - r * .66, cx - r * .08, cy - r * .34], fill=lighten(color, 0.6))
            d.ellipse([cx - r * .52, cy - r * .6, cx - r * .3, cy - r * .46], fill=(255, 255, 255))
        if direction is not None:
            self.small_arrow(cx, cy + r * 0.04, r * 1.05, direction)
        if face:
            self.face(cx, cy + r * 0.15, r * 0.5)

    def small_arrow(self, cx, cy, s, ang):
        d = ImageDraw.Draw(self.img)
        pts = [(0, -.42), (.3, -.06), (.11, -.06), (.11, .38), (-.11, .38), (-.11, -.06), (-.3, -.06)]
        P = round_poly([(cx + (x * math.cos(ang) - y * math.sin(ang)) * s, cy + (x * math.sin(ang) + y * math.cos(ang)) * s)
                        for x, y in pts], s * 0.05, 4)
        d.polygon([(x + s * .03, y + s * .05) for x, y in P], fill=INK)
        d.polygon(P, fill=(255, 255, 255))

    def long_arrow(self, a, b, w):
        d = ImageDraw.Draw(self.img)
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        L = math.hypot(b[0] - a[0], b[1] - a[1])

        def rot(x, y):
            return (a[0] + x * math.cos(ang) - y * math.sin(ang), a[1] + x * math.sin(ang) + y * math.cos(ang))

        head = w * 4.2
        shaft = [(0, -w), (L - head * .8, -w), (L - head * .8, w), (0, w)]
        tip = [(L - head, -w * 2.9), (L, 0), (L - head, w * 2.9)]
        for poly in (shaft, tip):
            P = round_poly([rot(x, y) for x, y in poly], w * .4, 4)
            d.polygon([(x + w * .35, y + w * .55) for x, y in P], fill=INK)
        for poly in (shaft, tip):
            d.polygon(round_poly([rot(x, y) for x, y in poly], w * .4, 4), fill=(255, 255, 255))

    def face(self, cx, cy, s):
        d = ImageDraw.Draw(self.img)
        for ex in (cx - s * .45, cx + s * .45):
            d.ellipse([ex - s * .24, cy - s * .62, ex + s * .24, cy - s * .06], fill=(255, 255, 255))
            d.ellipse([ex - s * .15, cy - s * .48, ex + s * .17, cy - s * .1], fill=(50, 30, 36))
            d.ellipse([ex - s * .1, cy - s * .43, ex, cy - s * .32], fill=(255, 255, 255))
        d.chord([cx - s * .26, cy - s * .02, cx + s * .26, cy + s * .36], 0, 180, fill=(110, 30, 50))
        for chx in (cx - s * .82, cx + s * .82):
            d.ellipse([chx - s * .16, cy - s * .04, chx + s * .16, cy + s * .1], fill=(255, 150, 175))

    def speedlines(self, x0, y0, dx, dy, n, length, gap, width):
        d = ImageDraw.Draw(self.img)
        nx, ny = -dy, dx
        for i in range(n):
            o = (i - (n - 1) / 2) * gap
            L = length * (0.7 if i % 2 else 1)
            sx, sy = x0 + nx * o, y0 + ny * o
            ex, ey = sx - dx * L, sy - dy * L
            d.line([(sx, sy), (ex, ey)], fill=(255, 255, 255), width=int(width))
            for px, py in ((sx, sy), (ex, ey)):
                d.ellipse([px - width / 2, py - width / 2, px + width / 2, py + width / 2], fill=(255, 255, 255))

    def burst(self, cx, cy, r, color):
        d = ImageDraw.Draw(self.img)
        for i in range(10):
            a = 2 * math.pi * i / 10 + 0.2
            d.line([(cx + math.cos(a) * r * .7, cy + math.sin(a) * r * .7),
                    (cx + math.cos(a) * r * 1.1, cy + math.sin(a) * r * 1.1)], fill=(255, 255, 255), width=int(r * .09))
        for a, k, sz in ((0.6, 1.25, .16), (2.4, 1.3, .12), (4.2, 1.22, .14)):
            d.polygon(star_pts(cx + math.cos(a) * r * k, cy + math.sin(a) * r * k, r * sz, r * sz * .45, 4),
                      fill=lighten(color, 0.4))

    def sparkle(self, x, y, s, alpha=255):
        d = ImageDraw.Draw(self.img)
        d.polygon(star_pts(x, y, s, s * 0.32, 4), fill=(255, 255, 255))

    def save(self, path, size):
        self.img.resize(size, Image.LANCZOS).save(path, optimize=True)


def draw(width, height):
    c = Canvas(width, height)
    W, H = c.w, c.h
    u = min(H, W / 2.25)  # the size of the middle group, so it fits both shapes
    c.u = u
    cx, cy = W / 2, H * 0.52
    c.sky((61, 200, 170), (162, 110, 255), 0.5, 0.52)

    a = (cx - u * 0.75, cy + u * 0.32)
    b = (cx + u * 0.78, cy - u * 0.33)

    def near_arrow(x, y, margin):
        # distance from the point to the arrow's line segment
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0, min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy)))
        return math.hypot(x - (a[0] + t * dx), y - (a[1] + t * dy)) < margin

    # The game's candies around the middle, each with its arrow; none cut off, none touching.
    rnd = random.Random(11)
    kinds = [("circle", "pink"), ("diamond", "blue"), ("drop", "orange"), ("circle", "mint"), ("square", "grape"),
             ("star", "lemon"), ("diamond", "pink"), ("circle", "blue"), ("drop", "mint"), ("square", "orange")]
    placed = []
    want = int(W * H / (u * u) * 3.4)
    tries = 0
    while len(placed) < want and tries < 20000:
        tries += 1
        r = u * rnd.uniform(0.055, 0.085)
        x = rnd.uniform(r * 1.6, W - r * 1.6)
        y = rnd.uniform(r * 1.6, H - r * 1.8)
        if ((x - cx) / (u * 0.62)) ** 2 + ((y - cy) / (u * 0.5)) ** 2 < 1:
            continue  # keep the star free
        if near_arrow(x, y, r + u * 0.16):
            continue
        if math.hypot(x - (cx - u * 0.56), y - (cy + u * 0.45)) < r + u * 0.26:
            continue  # the speed lines under the arrow
        if any(math.hypot(x - px, y - py) < r + pr + u * 0.08 for px, py, pr in placed):
            continue
        placed.append((x, y, r))
    for i, (x, y, r) in enumerate(placed):
        kind, color = kinds[i % len(kinds)]
        c.candy(kind, COL[color], x, y, r, direction=rnd.choice([0, math.pi / 2, math.pi, -math.pi / 2]))
        if i % 4 == 1:
            c.burst(x, y, r * 1.7, COL[color])

    # The big arrow and the star riding it, in the middle.
    c.long_arrow(a, b, u * 0.045)
    c.speedlines(cx - u * 0.38, cy + u * 0.34, 0.92, -0.39, 3, u * 0.3, u * 0.07, u * 0.02)
    c.candy("star", COL["lemon"], cx, cy, u * 0.25, face=True)
    for dx, dy, sz in [(-.32, -.33, .03), (.36, .22, .026), (.3, -.36, .02), (-.42, .1, .022), (.05, -.42, .018)]:
        c.sparkle(cx + dx * u, cy + dy * u, sz * u)
    for _ in range(int(want * 0.8)):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        if not near_arrow(x, y, u * 0.12) and ((x - cx) / (u * .5)) ** 2 + ((y - cy) / (u * .45)) ** 2 > 1:
            c.sparkle(x, y, u * rnd.uniform(0.008, 0.016))
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    for size in ((3840, 1646), (5244, 2950)):
        path = os.path.join(OUT, f"banner-{size[0]}x{size[1]}.png")
        draw(*size).save(path, size)
        print("wrote", path)


if __name__ == "__main__":
    main()
