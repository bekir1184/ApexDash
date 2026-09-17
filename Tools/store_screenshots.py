#!/usr/bin/env python3
"""Builds App Store screenshots from raw simulator captures.

Each image keeps the app's look: the navy ground with its two slanted stripes,
a caption set in Saira, and the capture inset with rounded corners.

    python3 Tools/store_screenshots.py <captures dir> <output dir>

Captures are named "<language>-<scene>.png"; the scene order and captions are
below. Output is written at the size Apple asks for the 6.9 inch iPhone in
landscape (2868 x 1320).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SIZE = (2868, 1320)
GROUND = (21, 21, 30)
STRIPE_NEAR = (41, 41, 51)
STRIPE_FAR = (49, 49, 59)
ACCENT = (225, 6, 0)
INK = (241, 242, 245)

FONTS = Path("Resources/Fonts")
SCENES = ["realistic", "menu", "broadcast", "dotMatrix", "cluster", "analysis", "laps"]
CAPTIONS = {
    "en": [
        "Your phone becomes the wheel display",
        "Six dashboards, one swipe away",
        "TV graphics on your desk",
        "Every LED, every temperature",
        "Analogue dials, live data",
        "Study every lap in your browser",
        "Lap times and sectors on the phone",
    ],
    "tr": [
        "Telefonun direksiyon ekranına dönüşür",
        "Altı pano, tek kaydırma",
        "Yayın grafikleri masanda",
        "Her LED, her sıcaklık",
        "Analog kadranlar, canlı veri",
        "Her turu tarayıcında incele",
        "Tur süreleri ve sektörler telefonda",
    ],
}


def stripes(image):
    """The app's background: two grey bands leaning across the screen."""
    draw = ImageDraw.Draw(image)
    width, height = image.size
    band = width * 0.17
    gap = band * 0.22
    shift = height * 0.42
    for index, colour in enumerate((STRIPE_NEAR, STRIPE_FAR)):
        x = width * 0.22 + index * (band + gap)
        draw.polygon([(x + shift, 0), (x + shift + band, 0), (x + band, height), (x, height)], fill=colour)


def tracked_text(draw, position, text, font, fill, tracking):
    """Draws text with letter spacing, the way the app sets its titles."""
    x, y = position
    for character in text:
        draw.text((x, y), character, font=font, fill=fill)
        x += draw.textlength(character, font=font) + tracking


def tracked_width(draw, text, font, tracking):
    return sum(draw.textlength(c, font=font) + tracking for c in text) - tracking


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius, fill=255)
    out = Image.new("RGBA", image.size)
    out.paste(image, mask=mask)
    return out


def compose(capture_path, caption, font_path):
    canvas = Image.new("RGB", SIZE, GROUND)
    stripes(canvas)
    draw = ImageDraw.Draw(canvas)

    font = ImageFont.truetype(str(font_path), 88)
    tracking = 2
    text_width = tracked_width(draw, caption, font, tracking)
    tracked_text(draw, ((SIZE[0] - text_width) / 2, 92), caption, font, INK, tracking)
    # A short accent rule under the caption, like the app's dividers.
    rule = 150
    draw.rounded_rectangle([(SIZE[0] - rule) / 2, 232, (SIZE[0] + rule) / 2, 240], 4, fill=ACCENT)

    shot = Image.open(capture_path).convert("RGB")
    top = 320
    max_height = SIZE[1] - top - 90
    width = min(int(max_height * shot.width / shot.height), 2360)
    height = int(width * shot.height / shot.width)
    shot = rounded(shot.resize((width, height), Image.LANCZOS), 44)

    x = (SIZE[0] - width) // 2
    # A soft dark shadow so the screen sits above the background.
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + 16, x + width, top + height + 16], 44, fill=(0, 0, 0, 150))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB"), (0, 0))
    canvas.paste(shot, (x, top), shot)
    return canvas


def main():
    captures = Path(sys.argv[1] if len(sys.argv) > 1 else "captures")
    output = Path(sys.argv[2] if len(sys.argv) > 2 else "docs/store")
    output.mkdir(parents=True, exist_ok=True)
    font_path = FONTS / "Saira-Black.ttf"

    for language, captions in CAPTIONS.items():
        for index, (scene, caption) in enumerate(zip(SCENES, captions), start=1):
            source = captures / f"{language}-{scene}.png"
            if not source.exists():
                print(f"missing {source}")
                continue
            image = compose(source, caption, font_path)
            target = output / f"{language}-{index}-{scene}.png"
            image.save(target)
            print(target, image.size)


if __name__ == "__main__":
    main()
