#!/usr/bin/python3
"""Draw original 32px biome symbols for Craft's flat planets and a reusable atlas."""
from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art/planet_map"
PREVIEW = ROOT / "art/concepts/planet_sprite_sheet.png"
INK = (28, 23, 48)
GOLD = (245, 195, 76)
CREAM = (247, 241, 221)
NAMES = ["Otpornik", "Elektrika", "Iskra", "Skoljka", "Rudnik", "Paprika", "Brudet", "Pomidor", "Cichvarda", "Chvarak", "Artichoke", "Unknown"]


def world(top, side):
    image = Image.new("RGBA", (32, 32))
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 13, 29, 30), fill=INK)
    draw.ellipse((3, 12, 28, 28), fill=side)
    draw.ellipse((2, 8, 29, 26), fill=INK)
    draw.ellipse((3, 9, 28, 25), fill=top)
    return image


def terrain(image, paint):
    layer = Image.new("RGBA", image.size)
    paint(ImageDraw.Draw(layer))
    mask = Image.new("L", image.size)
    ImageDraw.Draw(mask).ellipse((4, 10, 27, 24), fill=255)
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", image.size), mask))
    image.alpha_composite(layer)


def tree(draw, x, y, pine=False):
    draw.line((x, y-2, x, y+2), fill=(98, 63, 46))
    if pine:
        draw.polygon([(x, y-8), (x-3, y-2), (x+3, y-2)], fill=INK)
        draw.polygon([(x, y-7), (x-2, y-3), (x+2, y-3)], fill=(76, 136, 81))
        draw.point((x, y-5), fill=(145, 184, 92))
    else:
        draw.ellipse((x-3, y-7, x+3, y-1), fill=INK)
        draw.ellipse((x-2, y-6, x+2, y-2), fill=(77, 139, 77))
        draw.line((x-1, y-5, x+1, y-5), fill=(156, 185, 93))


def house(draw, x, y, roof=(176, 77, 51), wall=(211, 172, 118)):
    draw.rectangle((x-3, y-4, x+3, y), fill=INK)
    draw.rectangle((x-2, y-3, x+2, y-1), fill=wall)
    draw.polygon([(x-4, y-4), (x, y-8), (x+4, y-4)], fill=INK)
    draw.polygon([(x-2, y-5), (x, y-7), (x+2, y-5)], fill=roof)
    draw.point((x, y-2), fill=INK)


def mountain(draw, x, y, snow=False):
    draw.polygon([(x-5, y), (x, y-10), (x+5, y)], fill=INK)
    draw.polygon([(x-4, y-1), (x, y-9), (x+4, y-1)], fill=(147, 158, 164))
    draw.polygon([(x, y-8), (x+4, y-1), (x, y-1)], fill=(85, 100, 121))
    if snow:
        draw.polygon([(x, y-9), (x-2, y-5), (x, y-6), (x+2, y-5)], fill=(234, 244, 244))


def fields(draw, x, y):
    draw.rectangle((x, y, x+7, y+5), fill=(117, 93, 51))
    for offset in (0, 2, 4):
        draw.line((x, y+offset, x+7, y+offset), fill=(207, 178, 84))


def unknown():
    image = world((53, 51, 68), (37, 34, 48))
    draw = ImageDraw.Draw(image)
    for x, y in ((7, 15), (24, 15), (9, 22), (23, 21)):
        draw.line((x, y, x+1, y), fill=(107, 101, 121))
    draw.line([(12, 11), (12, 9), (18, 9), (20, 11), (20, 14), (16, 17), (16, 19)], fill=(214, 201, 173), width=2)
    draw.rectangle((15, 22, 17, 24), fill=GOLD)
    return image


def planet(key):
    if key in ("unknown", "otpornik", "elektrika", "cichvarda"):
        return unknown()
    palettes = {
        "paprika": ((115, 160, 78), (106, 80, 50)),
        "brudet": ((74, 134, 112), (49, 79, 81)),
        "pomidor": ((181, 146, 101), (119, 84, 70)),
        "chvarak": ((125, 158, 84), (100, 94, 81)),
        "artichoke": ((209, 227, 230), (109, 143, 163)),
        "rudnik": ((99, 134, 89), (99, 86, 78)),
        "skoljka": ((47, 117, 162), (29, 66, 109)),
        "iskra": ((75, 63, 56), (114, 76, 41)),
    }
    image = world(*palettes[key])
    draw = ImageDraw.Draw(image)
    if key == "paprika":
        terrain(image, lambda d: fields(d, 17, 18))
        tree(draw, 8, 17)
        tree(draw, 12, 14)
        house(draw, 21, 16)
        draw.line((12, 21, 16, 23), fill=(207, 181, 133))
    elif key == "brudet":
        def rivers(d):
            d.line([(14, 9), (12, 14), (18, 18), (15, 25)], fill=(53, 155, 188), width=4)
            d.line([(12, 14), (6, 17), (3, 17)], fill=(70, 179, 196), width=2)
            d.line((10, 13, 15, 15), fill=(223, 201, 154), width=2)
        terrain(image, rivers)
        tree(draw, 7, 22)
        house(draw, 22, 16, (76, 121, 142))
        draw.line((17, 20, 21, 21), fill=(223, 201, 154), width=2)
    elif key == "pomidor":
        house(draw, 8, 19, (191, 96, 57))
        house(draw, 24, 20, (217, 125, 64))
        draw.rectangle((12, 9, 20, 19), fill=INK)
        draw.rectangle((13, 10, 19, 18), fill=(235, 205, 149))
        draw.polygon([(10, 10), (16, 5), (22, 10)], fill=(174, 80, 49))
        for x in (14, 18):
            draw.line((x, 12, x, 17), fill=(124, 109, 93))
        draw.ellipse((14, 22, 19, 24), fill=(74, 151, 164))
    elif key == "chvarak":
        mountain(draw, 12, 15, True)
        mountain(draw, 22, 16, True)
        terrain(image, lambda d: fields(d, 7, 19))
        house(draw, 22, 23, (162, 64, 51))
    elif key == "artichoke":
        mountain(draw, 9, 16, True)
        mountain(draw, 17, 13, True)
        terrain(image, lambda d: d.polygon([(20, 19), (29, 17), (29, 27), (18, 27)], fill=(93, 151, 175)))
        draw.line([(7, 20), (12, 20), (12, 22), (18, 22)], fill=(103, 102, 101), width=2)
        draw.line((24, 12, 24, 18), fill=INK)
        draw.rectangle((24, 12, 28, 14), fill=(82, 139, 81))
        draw.point((7, 24), fill=(231, 242, 235))
    elif key == "rudnik":
        mountain(draw, 21, 18)
        tree(draw, 7, 19)
        tree(draw, 12, 15)
        draw.rectangle((18, 16, 23, 21), fill=INK)
        draw.line([(17, 21), (17, 15), (24, 15), (24, 21)], fill=(185, 124, 65), width=1)
        draw.line((20, 22, 18, 26), fill=(162, 174, 174))
        draw.line((23, 22, 21, 26), fill=(162, 174, 174))
    elif key == "skoljka":
        def sea(d):
            for x, y in ((6, 13), (22, 14), (8, 22), (22, 22)):
                d.line((x, y, x+3, y), fill=(100, 189, 205))
        terrain(image, sea)
        draw.ellipse((9, 11, 22, 24), fill=INK)
        draw.ellipse((10, 12, 21, 23), fill=(57, 150, 175))
        draw.line((16, 12, 16, 22), fill=(166, 227, 222))
        draw.line((11, 19, 20, 19), fill=(139, 210, 212))
        draw.arc((10, 12, 21, 23), 185, 320, fill=(201, 237, 227), width=1)
        draw.rectangle((22, 9, 28, 12), fill=(168, 112, 61), outline=INK)
        draw.line((25, 12, 23, 17), fill=(235, 171, 69))
    elif key == "iskra":
        draw.arc((3, 9, 28, 25), 0, 180, fill=GOLD)
        for x, y in ((7, 17), (24, 18), (9, 23), (22, 24)):
            draw.rectangle((x-1, y-5, x+2, y), fill=INK)
            draw.rectangle((x, y-4, x+1, y-1), fill=(133, 108, 76))
            draw.point((x, y-3), fill=(255, 218, 113))
        draw.line((16, 8, 16, 22), fill=INK, width=5)
        draw.line((16, 8, 16, 22), fill=(181, 134, 76), width=3)
        for y in (11, 15, 19):
            draw.line((14, y, 18, y), fill=GOLD)
        draw.ellipse((11, 4, 21, 10), fill=INK)
        draw.pieslice((12, 5, 20, 12), 180, 360, fill=(237, 202, 124))
        draw.line((11, 9, 21, 9), fill=GOLD)
        draw.rectangle((13, 22, 20, 24), fill=(91, 153, 92))
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (128, 96))
    sheet = Image.new("RGBA", (576, 468), (17, 17, 29, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    records = []
    for index, name in enumerate(NAMES):
        key = name.lower()
        sprite = planet(key)
        sprite.save(OUT / f"{key}.png")
        x, y = index % 4 * 32, index // 4 * 32
        atlas.alpha_composite(sprite, (x, y))
        records.append({"id": key, "image": f"{key}.png", "region": [x, y, 32, 32]})
        px, py = index % 4 * 144, index // 4 * 156
        draw.rectangle((px+3, py+3, px+140, py+152), fill=(29, 28, 42), outline=(96, 82, 61))
        sheet.alpha_composite(sprite.resize((128, 128), Image.Resampling.NEAREST), (px+8, py+3))
        width = draw.textbbox((0, 0), name, font=font)[2]
        draw.text((px+(144-width)//2, py+137), name, font=font, fill=CREAM)
    atlas.save(OUT / "sheet.png")
    (OUT / "sheet.json").write_text(json.dumps(records, indent=2) + "\n")
    sheet.save(PREVIEW)
    print(f"Exported {len(records)} 32px planet symbols and {PREVIEW}")


if __name__ == "__main__":
    main()
