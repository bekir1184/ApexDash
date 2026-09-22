#!/usr/bin/env python3
"""Builds App Store screenshots from raw simulator captures.

The app is landscape, the App Store is browsed in portrait. Each store image is
a portrait canvas carrying a caption and one or two landscape screens, over the
app's own navy ground and slanted stripes, set in Saira.

    python3 Tools/store_screenshots.py <captures dir> <output dir>
        [--landscape|--ipad|--iphone65|--ipad129]

Captures are named "<language>-<scene>.png". Portrait output is 1320 x 2868 and
landscape output 2868 x 1320, the sizes Apple asks for the 6.9 inch iPhone.
Run from the repository root, so the fonts are found.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PORTRAIT = (1320, 2868)          # 6.9 inch iPhone, upright
LANDSCAPE = (2868, 1320)         # 6.9 inch iPhone, on its side
IPAD = (2064, 2752)              # 13 inch iPad, upright
IPHONE_65 = (1284, 2778)         # 6.5 inch iPhone, upright
IPAD_129 = (2048, 2732)          # 12.9 inch iPad, upright
GROUND = (21, 21, 30)
STRIPE_NEAR = (41, 41, 51)
STRIPE_FAR = (49, 49, 59)
ACCENT = (225, 6, 0)
INK = (241, 242, 245)
DIM = (150, 150, 168)

FONTS = Path("Resources/Fonts")

# Each store image: the scenes it shows, its caption and its closing line.
PAGES = {
    "en": [
        (["realistic", "broadcast"], "Your phone becomes the wheel display",
         "Live from your game over Wi-Fi, 60 times a second"),
        (["menu", "cluster"], "Six dashboards, one swipe away",
         "Swipe to change, tap to go full screen"),
        (["dotMatrix", "modern", "game"], "Pick the look you like",
         "Every layout draws the same live telemetry"),
        (["analysis", "laps"], "Every lap, recorded and compared",
         "Track map, speed and pedal traces, corner by corner"),
        (["setup", "webguide"], "Two-minute setup, no PC in between",
         "Free and open source. No ads, no account, no tracking."),
    ],
    "tr": [
        (["realistic", "broadcast"], "Telefonun direksiyon ekranına dönüşür",
         "Oyundan Wi-Fi ile saniyede 60 kez canlı"),
        (["menu", "cluster"], "Altı pano, tek kaydırma",
         "Kaydırarak değiştir, dokunarak tam ekrana geç"),
        (["dotMatrix", "modern", "game"], "Beğendiğin görünümü seç",
         "Her pano aynı canlı telemetriyi çizer"),
        (["analysis", "laps"], "Her tur kayıtta ve karşılaştırmada",
         "Pist haritası, hız ve pedal grafikleri, viraj viraj"),
        (["setup", "webguide"], "İki dakikada kurulum, arada PC yok",
         "Ücretsiz ve açık kaynak. Reklam yok, hesap yok, takip yok."),
    ],
}


def stripes(image):
    """The app's background: two grey bands leaning across the screen."""
    draw = ImageDraw.Draw(image)
    width, height = image.size
    band = width * 0.42
    gap = band * 0.22
    shift = height * 0.18
    for index, colour in enumerate((STRIPE_NEAR, STRIPE_FAR)):
        x = width * 0.18 + index * (band + gap)
        draw.polygon([(x + shift, 0), (x + shift + band, 0), (x + band, height), (x, height)], fill=colour)


def tracked_text(draw, position, text, font, fill, tracking):
    """Draws text with letter spacing, the way the app sets its titles."""
    x, y = position
    for character in text:
        draw.text((x, y), character, font=font, fill=fill)
        x += draw.textlength(character, font=font) + tracking


def tracked_width(draw, text, font, tracking):
    return sum(draw.textlength(c, font=font) + tracking for c in text) - tracking


def wrapped(draw, text, font, tracking, limit):
    lines, current = [], ""
    for word in text.split():
        candidate = f"{current} {word}".strip()
        if tracked_width(draw, candidate, font, tracking) <= limit:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius, fill=255)
    out = Image.new("RGBA", image.size)
    out.paste(image, mask=mask)
    return out


def place(canvas, path, top, width):
    """Draws one screen with rounded corners and a soft shadow."""
    shot = Image.open(path).convert("RGB")
    height = int(width * shot.height / shot.width)
    shot = rounded(shot.resize((width, height), Image.LANCZOS), 40)
    x = (canvas.width - width) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + 18, x + width, top + height + 18], 40, fill=(0, 0, 0, 160))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB"), (0, 0))
    canvas.paste(shot, (x, top), shot)
    return height


def compose(paths, caption, footer, size=PORTRAIT):
    portrait = size[1] > size[0]
    canvas = Image.new("RGB", size, GROUND)
    stripes(canvas)
    draw = ImageDraw.Draw(canvas)

    scale = size[0] / PORTRAIT[0] if portrait else size[0] / LANDSCAPE[0]
    title = ImageFont.truetype(str(FONTS / "Saira-Black.ttf"), int((104 if portrait else 88) * scale))
    note = ImageFont.truetype(str(FONTS / "Saira-Medium.ttf"), int((50 if portrait else 44) * scale))
    margin = int(size[0] * 0.09)

    y = int((150 if portrait else 86) * scale)
    for line in wrapped(draw, caption, title, 2, size[0] - margin * 2):
        width = tracked_width(draw, line, title, 2)
        tracked_text(draw, ((size[0] - width) / 2, y), line, title, INK, 2)
        y += int(title.size * 1.22)
    rule = 160 * scale
    draw.rounded_rectangle([(size[0] - rule) / 2, y + 26 * scale, (size[0] + rule) / 2, y + 40 * scale], 5, fill=ACCENT)
    y += int(120 * scale)

    footer_height = int((190 if portrait else 150) * scale)
    available = size[1] - y - footer_height
    shot_width = size[0] - margin * 2
    gap = int(80 * scale)
    first = Image.open(paths[0])
    aspect = first.height / first.width
    shot_height = int(shot_width * aspect)
    total = shot_height * len(paths) + gap * (len(paths) - 1)
    if total > available:                      # one tall screen, or a small canvas
        shot_width = int(shot_width * available / total)
        shot_height = int(shot_width * aspect)
        total = shot_height * len(paths) + gap * (len(paths) - 1)
    y += max((available - total) // 2, 0)
    for path in paths:
        y += place(canvas, path, y, shot_width) + gap

    width = tracked_width(draw, footer, note, 1)
    tracked_text(draw, ((size[0] - width) / 2, size[1] - footer_height + 30 * scale), footer, note, DIM, 1)
    return canvas


def main():
    arguments = [a for a in sys.argv[1:] if not a.startswith("--")]
    shapes = {"--landscape": ("landscape", LANDSCAPE), "--ipad": ("ipad", IPAD),
              "--iphone65": ("iphone65", IPHONE_65), "--ipad129": ("ipad129", IPAD_129)}
    shape, size = next((v for k, v in shapes.items() if k in sys.argv), ("portrait", PORTRAIT))
    captures = Path(arguments[0] if arguments else "captures")
    output = Path(arguments[1] if len(arguments) > 1 else "docs/store")
    output.mkdir(parents=True, exist_ok=True)

    for language, pages in PAGES.items():
        for index, (scenes, caption, footer) in enumerate(pages, start=1):
            # Two screens fit an iPad page; a third would shrink them all.
            limit = 2 if shape.startswith("ipad") else 3
            paths = [captures / f"{language}-{scene}.png" for scene in scenes[:limit]]
            missing = [p for p in paths if not p.exists()]
            if missing:
                print(f"missing {missing[0]}")
                continue
            image = compose(paths, caption, footer, size=size)
            target = output / f"{language}-{index}-{scenes[0]}-{shape}.png"
            image.save(target)
            print(target, image.size)


if __name__ == "__main__":
    main()
