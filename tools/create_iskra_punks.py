#!/usr/bin/python3
"""Punk Park clothes drawn on Paprika's original 16x24 villager."""
import json
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/concepts/source/villager3.png"
OUT = ROOT / "assets/art/iskra/npcs"
PREVIEW = ROOT / "art/concepts/iskra_punk_outfits.png"
INK = (28, 23, 48)
SKIN = (220, 167, 120)
BLACK = (47, 43, 53)
SILVER = (185, 190, 178)
CREAM = (220, 204, 166)
RED = (166, 55, 64)
DENIM = (65, 106, 139)
GREEN = (94, 113, 65)
VARIANTS = (
    ("punk_leather", "Studded leather", "Pink crop / zip / studs"),
    ("punk_denim", "Patched denim", "Bleached hair / red patch"),
    ("punk_tartan", "Tartan skirt", "Black jacket / red plaid"),
    ("punk_stripes", "Striped shirt", "Teal fringe / ripped knees"),
    ("punk_crust", "Crust patches", "Olive trousers / repairs"),
    ("punk_fishnet", "Fishnet sleeves", "Purple hair / wrist cuffs"),
    ("punk_braces", "Red braces", "White shirt / dark trousers"),
    ("punk_vest", "Sleeveless vest", "Ginger hair / chain / boots"),
)


@lru_cache(maxsize=1)
def variants():
    result = {}
    with Image.open(SOURCE) as source:
        original = source.convert("RGBA")
    for index, (key, _, _) in enumerate(VARIANTS):
        sprite = original.copy()
        pixels = sprite.load()
        hair = [(191, 66, 128), (213, 185, 115), (47, 43, 53), (61, 153, 140),
                (96, 73, 51), (138, 83, 165), (75, 48, 39), (177, 99, 52)][index]
        shirt = [BLACK, DENIM, BLACK, CREAM, BLACK, BLACK, CREAM, BLACK][index]
        for y in range(24):
            for x in range(16):
                if pixels[x, y] == (75, 48, 39, 255):
                    pixels[x, y] = (*hair, 255)
                elif pixels[x, y] == (133, 112, 165, 255):
                    pixels[x, y] = (*shirt, 255)
        draw = ImageDraw.Draw(sprite)
        if index in (0, 1, 2, 4):
            draw.rectangle((3, 10, 4, 13), fill=shirt)
            draw.rectangle((11, 10, 12, 13), fill=shirt)
        if index == 0:
            draw.line((5, 10, 7, 12), fill=SILVER)
            draw.line((10, 10, 8, 12), fill=SILVER)
            draw.line((8, 13, 8, 15), fill=SILVER)
            draw.point([(5, 13), (10, 13)], fill=SILVER)
            draw.line((5, 4, 10, 4), fill=SKIN)
            draw.line((7, 2, 8, 4), fill=hair)
        elif index == 1:
            draw.line((7, 10, 7, 14), fill=BLACK)
            draw.line((8, 10, 8, 14), fill=BLACK)
            draw.rectangle((9, 11, 10, 12), fill=RED)
            draw.point([(5, 14), (6, 14)], fill=CREAM)
            draw.line((5, 18, 7, 18), fill=DENIM)
            draw.line((9, 18, 11, 18), fill=DENIM)
        elif index == 2:
            draw.line((5, 10, 7, 12), fill=SILVER)
            draw.rectangle((5, 14, 10, 17), fill=RED)
            draw.line((6, 14, 6, 17), fill=BLACK)
            draw.line((9, 14, 9, 17), fill=BLACK)
            draw.line((5, 16, 10, 16), fill=CREAM)
        elif index == 3:
            for y in (11, 13, 15):
                draw.line((5, y, 10, y), fill=BLACK)
            draw.point([(6, 18), (10, 18)], fill=SKIN)
            draw.point([(5, 4), (6, 4), (7, 4)], fill=BLACK)
        elif index == 4:
            draw.rectangle((5, 11, 6, 12), fill=CREAM)
            draw.rectangle((9, 14, 10, 15), fill=GREEN)
            for y in range(17, 20):
                for x in (5, 6, 7, 9, 10, 11):
                    draw.point((x, y), fill=GREEN)
            draw.point([(6, 18), (10, 19)], fill=CREAM)
            draw.line((7, 3, 10, 3), fill=INK)
        elif index == 5:
            # Mesh is drawn over the original bare arms, not over the hands.
            for y in range(10, 14):
                for x in (3, 4, 11, 12):
                    if (x + y) % 2 == 0:
                        draw.point((x, y), fill=BLACK)
            draw.line((3, 14, 4, 14), fill=BLACK)
            draw.line((11, 14, 12, 14), fill=BLACK)
            draw.line((6, 10, 9, 10), fill=SKIN)
            draw.point([(6, 13), (9, 13)], fill=RED)
        elif index == 6:
            draw.line((6, 10, 6, 15), fill=RED)
            draw.line((9, 10, 9, 15), fill=RED)
            draw.point([(6, 14), (9, 14)], fill=SILVER)
            draw.line((5, 16, 10, 16), fill=BLACK)
        else:
            draw.rectangle((7, 10, 8, 14), fill=CREAM)
            draw.line((9, 15, 10, 16), fill=SILVER)
            draw.point([(5, 11), (10, 11)], fill=SILVER)
            draw.line((5, 4, 10, 4), fill=SKIN)
            draw.line((7, 2, 8, 4), fill=hair)
        draw.line((5, 15, 8 if index == 7 else 10, 15), fill=INK)
        draw.point((8, 15), fill=SILVER)
        # Keep feet, shadow, and transparent silhouette exactly as the source.
        for y in (20, 21):
            for x in (5, 6, 7, 9, 10, 11):
                draw.point((x, y), fill=BLACK)
        if index in (0, 2, 5, 7):
            draw.point([(6, 20), (10, 20)], fill=SILVER)
        sprite.putalpha(original.getchannel("A"))
        result[key] = sprite
    return result


def npc(index):
    key = VARIANTS[index % len(VARIANTS)][0]
    sprite = variants()[key].copy()
    sprite.info["npc_role"] = key
    return sprite


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (64, 48))
    preview = Image.new("RGBA", (880, 500), (*INK, 255))
    draw = ImageDraw.Draw(preview)
    font = ImageFont.load_default()
    draw.text((16, 12), "PUNK PARK - original 16 x 24 NPC proportions", fill=CREAM, font=font)
    entries = []
    for i, (key, label, detail) in enumerate(VARIANTS):
        sprite = variants()[key]
        sprite.save(OUT / (key + ".png"))
        x, y = (i % 4) * 16, (i // 4) * 24
        atlas.alpha_composite(sprite, (x, y))
        entries.append(dict(id=key, image=key + ".png", region=[x, y, 16, 24], source=str(SOURCE.relative_to(ROOT))))
        px, py = (i % 4) * 220, 40 + (i // 4) * 225
        draw.rectangle((px+6, py, px+212, py+216), fill=(54, 44, 41))
        preview.alpha_composite(sprite.resize((96, 144), Image.Resampling.NEAREST), (px+60, py+8))
        preview.alpha_composite(sprite, (px+176, py+128))
        draw.text((px+12, py+164), label, fill=CREAM, font=font)
        draw.text((px+12, py+188), detail, fill=SILVER, font=font)
    atlas.save(OUT / "punk_sheet.png")
    (OUT / "punk_sheet.json").write_text(json.dumps(entries, indent=2) + "\n")
    preview.save(PREVIEW)
    print(PREVIEW)


if __name__ == "__main__":
    main()
