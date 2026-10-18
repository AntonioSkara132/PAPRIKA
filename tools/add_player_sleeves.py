#!/usr/bin/python3
"""Give the player's colored outfits visible sleeves below the armor plates."""

from pathlib import Path

from PIL import ImageDraw, Image

ROOT = Path(__file__).resolve().parent.parent
OUTFITS = (
    "assets/art/player_red.png",
    "assets/art/player_blue.png",
    "assets/art/player_green.png",
    "assets/art/player_orange.png",
    "assets/art/player_sea_glass.png",
    "assets/art/player_coral.png",
    "assets/art/northern_village/player_purple.png",
)


def add_sleeves(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    color = image.getpixel((5, 12))
    shade = image.getpixel((5, 16))
    draw = ImageDraw.Draw(image)
    draw.rectangle((3, 10, 4, 13), fill=color)
    draw.line((3, 14, 4, 14), fill=shade)
    draw.rectangle((11, 10, 12, 13), fill=color)
    draw.line((11, 14, 12, 14), fill=shade)
    return image


def remove_baked_weapon(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    for y in range(9, 19):
        for x in range(12, 16):
            image.putpixel((x, y), (0, 0, 0, 0))
    for y in range(10, 16):
        image.putpixel((12, y), (220, 167, 120, 255))
    image.putpixel((12, 16), (174, 121, 85, 255))
    return image


def main() -> None:
    plain = ROOT / "assets/art/player_plain.png"
    with Image.open(ROOT / "art/concepts/source/player.png") as source:
        remove_baked_weapon(source).save(plain)
    print(plain.relative_to(ROOT))
    for relative in OUTFITS:
        path = ROOT / relative
        with Image.open(path) as image:
            dressed = add_sleeves(remove_baked_weapon(image))
        dressed.save(path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
