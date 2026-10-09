"""Render the original Banco do Tabuleiro iOS app icon with Pillow."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SIZE = 1024
SCALE = 4
CANVAS = SIZE * SCALE
OUTPUT = Path("BancoDoTabuleiro/Assets.xcassets/AppIcon.appiconset/AppIcon.png")


def scaled_box(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(int(value * SCALE) for value in box)


def gradient_background() -> Image.Image:
    image = Image.new("RGB", (SIZE, SIZE))
    pixels = image.load()
    top = (12, 83, 60)
    bottom = (3, 30, 23)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        ease = t * t * (3 - 2 * t)
        color = tuple(round(top[i] * (1 - ease) + bottom[i] * ease) for i in range(3))
        for x in range(SIZE):
            pixels[x, y] = color
    return image.resize((CANVAS, CANVAS), Image.Resampling.LANCZOS).convert("RGBA")


def main() -> None:
    os.makedirs(OUTPUT.parent, exist_ok=True)
    image = gradient_background()

    glow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(scaled_box((170, 95, 850, 875)), fill=(227, 184, 89, 72))
    glow = glow.filter(ImageFilter.GaussianBlur(130 * SCALE))
    image.alpha_composite(glow)

    # Quiet embossed frame, inset to respect the iOS rounded icon mask.
    frame = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle(
        scaled_box((44, 44, 980, 980)),
        radius=210 * SCALE,
        outline=(236, 206, 132, 96),
        width=3 * SCALE,
    )
    image.alpha_composite(frame)

    # Drop shadow beneath the original bank-hall mark.
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(scaled_box((265, 790, 760, 870)), fill=(0, 0, 0, 145))
    shadow_draw.polygon([tuple(int(v * SCALE) for v in p) for p in [(512, 240), (822, 400), (202, 400)]], fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22 * SCALE))
    image.alpha_composite(shadow)

    mark = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)
    gold = (239, 199, 105, 255)
    light_gold = (255, 230, 157, 255)
    deep_gold = (166, 112, 37, 255)

    # Temple roof and lintel.
    draw.polygon([tuple(int(v * SCALE) for v in p) for p in [(512, 230), (815, 390), (209, 390)]], fill=deep_gold)
    draw.polygon([tuple(int(v * SCALE) for v in p) for p in [(512, 250), (770, 380), (254, 380)]], fill=gold)
    draw.rounded_rectangle(scaled_box((250, 390, 774, 458)), radius=18 * SCALE, fill=light_gold)
    draw.rounded_rectangle(scaled_box((291, 465, 733, 512)), radius=12 * SCALE, fill=deep_gold)

    # Four evenly spaced fluted columns with softly rounded capitals and bases.
    for center_x in (347, 457, 567, 677):
        draw.rounded_rectangle(scaled_box((center_x - 33, 485, center_x + 33, 785)), radius=17 * SCALE, fill=gold)
        draw.rounded_rectangle(scaled_box((center_x - 18, 500, center_x - 5, 770)), radius=6 * SCALE, fill=light_gold)
        draw.rounded_rectangle(scaled_box((center_x - 45, 486, center_x + 45, 520)), radius=10 * SCALE, fill=light_gold)
        draw.rounded_rectangle(scaled_box((center_x - 45, 752, center_x + 45, 788)), radius=10 * SCALE, fill=deep_gold)

    # Broad stepped foundation.
    draw.rounded_rectangle(scaled_box((270, 794, 754, 844)), radius=13 * SCALE, fill=deep_gold)
    draw.rounded_rectangle(scaled_box((238, 842, 786, 888)), radius=13 * SCALE, fill=gold)
    draw.rounded_rectangle(scaled_box((202, 885, 822, 928)), radius=13 * SCALE, fill=light_gold)
    image.alpha_composite(mark)

    image.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(OUTPUT, format="PNG", optimize=True)
    print(f"Generated {OUTPUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
