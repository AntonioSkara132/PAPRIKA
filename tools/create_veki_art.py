#!/usr/bin/python3
"""Draw Veki at Paprika's original NPC scale, with a comparison sheet."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/concepts/source/villager2.png"
OUT = ROOT / "assets/art/iskra/npcs/veki.png"
PREVIEW = ROOT / "art/concepts/veki_sprite.png"
INK = (28, 23, 48)
LEATHER = (150, 86, 51)
LEATHER_DARK = (105, 61, 43)
LINING = (235, 210, 163)
SCARF = (63, 145, 137)
SCARF_LIGHT = (105, 180, 157)
BRASS = (210, 164, 76)
LENS = (139, 183, 190)


def veki():
    with Image.open(SOURCE) as source:
        sprite = source.convert("RGBA")
    pixels = sprite.load()
    for y in range(10, 17):
        for x in range(5, 11):
            if pixels[x, y] == (86, 122, 155, 255):
                pixels[x, y] = (*LEATHER, 255)
    draw = ImageDraw.Draw(sprite)
    draw.rectangle((5, 2, 10, 4), fill=LEATHER_DARK)
    draw.line((6, 2, 9, 2), fill=LEATHER)
    draw.line((5, 3, 10, 3), fill=INK)
    draw.point((6, 3), fill=LENS)
    draw.point((9, 3), fill=LENS)
    draw.point((6, 4), fill=BRASS)
    draw.point((9, 4), fill=BRASS)
    draw.point((9, 6), fill=INK)
    draw.line((5, 10, 5, 12), fill=LINING)
    draw.line((10, 10, 10, 12), fill=LINING)
    draw.line((6, 9, 10, 9), fill=SCARF)
    draw.line((6, 10, 6, 13), fill=SCARF)
    draw.point((6, 10), fill=SCARF_LIGHT)
    draw.line((5, 15, 10, 15), fill=LEATHER_DARK)
    draw.point((8, 15), fill=BRASS)
    return sprite


def main():
    sprite = veki()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sprite.save(OUT)
    references = [
        ("Original player", ROOT / "art/concepts/source/player.png"),
        ("Original villager", SOURCE),
        ("Ordinary courier", ROOT / "assets/art/iskra/npcs/sky_courier.png"),
        ("Veki — pilot", OUT),
    ]
    width, height, scale = 160, 190, 6
    sheet = Image.new("RGBA", (width * len(references), height), (*INK, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (label, path) in enumerate(references):
        x = index * width
        draw.rectangle((x + 3, 3, x + width - 4, height - 4), fill=(48, 37, 32), outline=(143, 112, 71))
        with Image.open(path) as image:
            sheet.alpha_composite(image.convert("RGBA").resize((16 * scale, 24 * scale), Image.Resampling.NEAREST), (x + 32, 10))
        label = label.replace("—", "-")
        bounds = draw.textbbox((0, 0), label, font=font)
        draw.text((x + (width - bounds[2]) / 2, 166), label, font=font, fill=(247, 225, 178))
    sheet.save(PREVIEW)
    print(OUT)
    print(PREVIEW)


if __name__ == "__main__":
    main()
