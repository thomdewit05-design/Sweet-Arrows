#!/usr/bin/env python3
"""Turns the raw simulator screenshots into App Store screenshots with a headline.

Input:  docs/appstore/raw/<lang>-<n>-<name>.png  (from the "App Store screenshots" workflow)
Output: docs/appstore/<lang>/<n>-<name>.png, 1320 x 2868 (6.9-inch iPhone, accepted for all iPhones)

Run: python3 Tools/AppStore/frame_screenshots.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
RAW = os.path.join(ROOT, "docs", "appstore", "raw")
OUT = os.path.join(ROOT, "docs", "appstore")
FONTS = os.path.join(ROOT, "SweetArrows", "Resources", "Fonts")
W, H = 1320, 2868

# Order in the App Store, raw file name, background colors, headline and line below, per language.
SHOTS = [
    ("1-game", "1-game-00", (0xFF5C8A, 0xA259FF), {
        "nl": ("Tik. Glijd. Plop!", "Zet 3 snoepjes van een kleur op een rij"),
        "en": ("Tap. Slide. Pop!", "Line up 3 candies of a color"),
    }),
    ("2-home", "2-home", (0x4CC9F0, 0x5B6CFF), {
        "nl": ("Elke dag nieuwe opdrachten", "Stijg in level en houd je reeks vast"),
        "en": ("New missions every day", "Level up and keep your streak going"),
    }),
    ("3-result", "3-result", (0xA259FF, 0x5B6CFF), {
        "nl": ("Verbreek je record", "Versla jezelf en je vrienden"),
        "en": ("Beat your record", "Challenge yourself and your friends"),
    }),
    ("4-season", "4-season", (0x3DDC97, 0x1FA2A8), {
        "nl": ("Gratis seizoensbeloningen", "Elk potje brengt je verder"),
        "en": ("Free season rewards", "Every run takes you further"),
    }),
    ("5-album", "5-album", (0xFF5C8A, 0xFF9F1C), {
        "nl": ("Verzamel alle stickers", "Een volle pagina geeft een cadeau"),
        "en": ("Collect every sticker", "A full page earns a gift"),
    }),
    ("6-wheel", "6-wheel", (0xFFC93C, 0xFF7A3D), {
        "nl": ("Draai elke dag aan het rad", "Munten, boosters en een jackpot"),
        "en": ("Spin the wheel every day", "Coins, boosters and a jackpot"),
    }),
    ("7-tournament", "7-tournament", (0x5B6CFF, 0xA259FF), {
        "nl": ("Elke week een toernooi", "Win brons, zilver, goud en diamant"),
        "en": ("A tournament every week", "Win bronze, silver, gold and diamond"),
    }),
]


def rgb(hex_color):
    return ((hex_color >> 16) & 255, (hex_color >> 8) & 255, hex_color & 255)


def gradient(top, bottom):
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    a, b = rgb(top), rgb(bottom)
    for y in range(H):
        t = y / (H - 1)
        draw.line([(0, y), (W, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return image.convert("RGBA")


def sprinkles(image, seed):
    """Soft bubbles and little sparkles in the background."""
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    rnd = random.Random(seed)
    for _ in range(14):
        r = rnd.randint(60, 180)
        x, y = rnd.randint(-r, W + r), rnd.randint(-r, H + r)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(18, 40)))
    for _ in range(26):
        x, y, s = rnd.randint(30, W - 30), rnd.randint(30, 720), rnd.randint(8, 20)
        points = []
        for k in range(8):
            radius = s if k % 2 == 0 else s * 0.35
            angle = math.pi / 4 * k
            points.append((x + radius * math.cos(angle), y + radius * math.sin(angle)))
        draw.polygon(points, fill=(255, 255, 255, rnd.randint(120, 220)))
    layer = layer.filter(ImageFilter.GaussianBlur(1))
    return Image.alpha_composite(image, layer)


def wrap(draw, text, font, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def text_block(image, title, subtitle):
    draw = ImageDraw.Draw(image)
    size = 128
    while True:
        title_font = ImageFont.truetype(os.path.join(FONTS, "Fredoka-Bold.ttf"), size)
        lines = wrap(draw, title, title_font, W - 140)
        if len(lines) <= 2 or size <= 88:
            break
        size -= 6
    sub_font = ImageFont.truetype(os.path.join(FONTS, "Fredoka-Medium.ttf"), 58)
    sub_lines = wrap(draw, subtitle, sub_font, W - 160)
    line_h, sub_h = int(size * 1.12), 72
    total = line_h * len(lines) + 30 + sub_h * len(sub_lines)
    y = 120 + (430 - total) // 2

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    for i, line in enumerate(lines):
        x = (W - draw.textlength(line, font=title_font)) / 2
        shadow_draw.text((x, y + i * line_h + 8), line, font=title_font, fill=(60, 20, 70, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    image.alpha_composite(shadow)
    draw = ImageDraw.Draw(image)
    for i, line in enumerate(lines):
        x = (W - draw.textlength(line, font=title_font)) / 2
        draw.text((x, y + i * line_h), line, font=title_font, fill="white")
    y += line_h * len(lines) + 30
    for i, line in enumerate(sub_lines):
        x = (W - draw.textlength(line, font=sub_font)) / 2
        draw.text((x, y + i * sub_h), line, font=sub_font, fill=(255, 255, 255, 235))


def phone(image, shot):
    """The screenshot in a dark rounded phone frame with a soft shadow."""
    inner_w = 1000
    inner_h = round(shot.height * inner_w / shot.width)
    bezel, radius = 26, 110
    shot = shot.convert("RGBA").resize((inner_w, inner_h), Image.LANCZOS)
    frame_w, frame_h = inner_w + 2 * bezel, inner_h + 2 * bezel
    x, y = (W - frame_w) // 2, H - frame_h - 70

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x, y + 30, x + frame_w, y + frame_h + 30], radius + bezel, fill=(40, 10, 60, 120))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(40)))

    ImageDraw.Draw(image).rounded_rectangle([x, y, x + frame_w, y + frame_h], radius + bezel, fill=(28, 24, 34, 255))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner_w, inner_h], radius, fill=255)
    image.paste(shot, (x + bezel, y + bezel), mask)


def main():
    made = 0
    for lang in ("nl", "en"):
        os.makedirs(os.path.join(OUT, lang), exist_ok=True)
        for index, (name, raw, colors, texts) in enumerate(SHOTS):
            source = os.path.join(RAW, f"{lang}-{raw}.png")
            if not os.path.exists(source):
                print("missing", source)
                continue
            image = sprinkles(gradient(*colors), seed=index)
            text_block(image, *texts[lang])
            phone(image, Image.open(source))
            image.convert("RGB").save(os.path.join(OUT, lang, f"{name}.png"), optimize=True)
            made += 1
    print(f"made {made} screenshots")


if __name__ == "__main__":
    main()
