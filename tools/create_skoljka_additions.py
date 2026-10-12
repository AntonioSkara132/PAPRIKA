#!/usr/bin/python3
"""Draw Skoljka residents and locally dyed outfits without replacing existing art."""
from pathlib import Path

from PIL import Image, ImageDraw

from create_pomidor_art import HAIRS
from create_skoljka_art import BLUE, BLUE_DARK, GREY, GREY_DARK, KELP, ORANGE, OUT, ROOT, WARM, worker


CITIZENS = {
    "citizen_0": ((182, 124, 76), (126, 78, 54), 1, HAIRS[1]),
    "citizen_1": ((84, 162, 158), (44, 106, 118), 2, HAIRS[2]),
    "citizen_2": (KELP, (35, 76, 66), 0, HAIRS[0]),
    "citizen_3": (BLUE, BLUE_DARK, 3, HAIRS[3]),
    "citizen_4": (WARM, (154, 108, 66), 2, GREY_DARK),
    "citizen_5": ((162, 108, 104), (110, 68, 78), 0, HAIRS[1]),
    "citizen_6": (GREY, GREY_DARK, 1, ORANGE),
    "citizen_7": ((142, 126, 158), (96, 78, 118), 3, HAIRS[0]),
}


def dyed_outfit(replacements: dict[tuple[int, int, int], tuple[int, int, int]]) -> Image.Image:
    source = Image.open(ROOT / "assets/art/player_blue.png").convert("RGBA")
    pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, alpha = pixels[x, y]
            new_color = replacements.get((red, green, blue))
            if new_color is not None:
                pixels[x, y] = (*new_color, alpha)
    return source


def library_shelf() -> Image.Image:
    image = Image.new("RGBA", (40, 32))
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 28, 38, 31), fill=(25, 32, 48, 125))
    draw.rectangle((1, 1, 38, 28), fill=(66, 101, 111), outline=(25, 32, 48))
    for y in (4, 12, 20):
        for i, color in enumerate(((86, 168, 158), (205, 115, 104), (220, 184, 118), (115, 146, 187))):
            x = 4 + i * 8
            draw.rectangle((x, y, x + 5, y + 5), fill=color, outline=(25, 32, 48))
        draw.line((2, y + 7, 37, y + 7), fill=(31, 56, 69), width=2)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    library_shelf().save(OUT / "library_shelf.png")
    for name, colors in CITIZENS.items():
        worker(*colors).save(OUT / f"person_{name}.png")
    outfits = {
        "sea_glass": {(78, 131, 207): (82, 170, 161), (47, 92, 156): (43, 111, 115)},
        "coral": {(78, 131, 207): (205, 115, 104), (47, 92, 156): (145, 74, 80)},
    }
    for name, replacements in outfits.items():
        dyed_outfit(replacements).save(ROOT / f"assets/art/player_{name}.png")
    print("Wrote 8 Skoljka residents and 2 outfits")


if __name__ == "__main__":
    main()
