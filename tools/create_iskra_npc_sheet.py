#!/usr/bin/python3
"""Export Iskra NPCs using Paprika's 16x24 character silhouettes and palettes."""
from functools import lru_cache
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/concepts/iskra_npc_sheet.png"
ASSETS = ROOT / "assets/art/iskra/npcs"
SOURCE = ROOT / "art/concepts/source"
MILITARY = ROOT / "assets/art/space_military_base"
CELL = (16, 24)
SCALE = 5
INK = (28, 23, 48)
SKIN = (220, 167, 120, 255)
# Only clothing colors are replaced. Faces, hands, hair, outlines and shadows remain intact.
VARIANTS = [
    ("civic_engineer", "Civic engineer", SOURCE / "villager1.png", (154, 94, 85), (184, 122, 50), (242, 200, 110)),
    ("sky_courier", "Sky courier", SOURCE / "villager2.png", (86, 122, 155), (178, 78, 49), (226, 166, 84)),
    ("market_keeper", "Market keeper", SOURCE / "villager3.png", (133, 112, 165), (160, 82, 118), (224, 165, 148)),
    ("greenhouse_worker", "Greenhouse worker", SOURCE / "villager4.png", (95, 138, 86), (75, 137, 85), (156, 187, 103)),
    ("library_archivist", "Library archivist", SOURCE / "villager5.png", (178, 122, 78), (114, 91, 155), (199, 169, 114)),
    ("dock_mechanic", "Dock mechanic", SOURCE / "villager6.png", (141, 89, 111), (190, 144, 53), (234, 195, 105)),
    ("police_clerk", "Police clerk", MILITARY / "station_soldier_1.png", (73, 106, 71), (58, 73, 90), (204, 159, 73)),
    ("tower_guard", "Tower guard", MILITARY / "station_soldier_2.png", (82, 109, 76), (92, 72, 50), (230, 184, 82)),
    ("park_artist", "Park artist", SOURCE / "villager3.png", (133, 112, 165), (146, 60, 120), (80, 191, 168)),
    ("night_watch", "Night watch", MILITARY / "station_soldier_1.png", (73, 106, 71), (59, 56, 64), (158, 133, 87)),
    ("board_officer", "Board officer", MILITARY / "station_soldier_2.png", (82, 109, 76), (106, 113, 123), (227, 184, 90)),
    ("canal_worker", "Canal worker", SOURCE / "villager2.png", (86, 122, 155), (60, 130, 126), (196, 164, 94)),
]


@lru_cache(maxsize=1)
def variants():
    result = {}
    for key, label, source, old, color, trim in VARIANTS:
        with Image.open(source) as opened:
            sprite = opened.convert("RGBA")
        assert sprite.size == CELL, source
        pixels = sprite.load()
        for y in range(9, 18):
            for x in range(sprite.width):
                original = pixels[x, y]
                if original == (*old, 255):
                    pixels[x, y] = (*color, 255)
                elif source.parent == MILITARY and original[:3] in [(155, 181, 104), (192, 162, 91)] and original[3] == 255:
                    pixels[x, y] = (*trim, 255)
        if source.parent == SOURCE:
            for x, y in [(5, 10), (10, 10), (6, 15), (7, 15), (8, 15), (9, 15)]:
                if pixels[x, y] == (*color, 255):
                    pixels[x, y] = (*trim, 255)
        result[key] = sprite
    return result


def npc(key):
    sprite = variants()[key].copy()
    sprite.info["npc_role"] = key
    return sprite


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (CELL[0] * 4, CELL[1] * 3))
    manifest = []
    reference = [("Original player", Image.open(SOURCE / "player.png").convert("RGBA")),
                 ("Original villager", Image.open(SOURCE / "villager1.png").convert("RGBA")),
                 ("Original villager", Image.open(SOURCE / "villager4.png").convert("RGBA")),
                 ("Original soldier", Image.open(MILITARY / "station_soldier_1.png").convert("RGBA"))]
    for index, (key, label, source, old, color, trim) in enumerate(VARIANTS):
        sprite = npc(key)
        sprite.save(ASSETS / (key + ".png"))
        x, y = index % 4 * CELL[0], index // 4 * CELL[1]
        atlas.alpha_composite(sprite, (x, y))
        manifest.append({"id": key, "name": label, "image": key + ".png", "region": [x, y, *CELL], "source": str(source.relative_to(ROOT))})
        reference.append((label, sprite))
    atlas.save(ASSETS / "sheet.png")
    (ASSETS / "sheet.json").write_text(json.dumps(manifest, indent=2) + "\n")
    width, height = 144, 156
    sheet = Image.new("RGBA", (width * 4, height * 4), (*INK, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (label, sprite) in enumerate(reference):
        x, y = index % 4 * width, index // 4 * height
        draw.rectangle((x+3, y+3, x+width-4, y+height-4), fill=(48, 37, 32), outline=(143, 112, 71))
        sheet.alpha_composite(sprite.resize((80, 120), Image.Resampling.NEAREST), (x+32, y+8))
        box = draw.textbbox((0, 0), label, font=font)
        draw.text((x+(width-box[2])/2, y+136), label, font=font, fill=(247, 225, 178))
    sheet.save(OUT)
    print(f"Exported {len(VARIANTS)} 16x24 NPCs, transparent atlas and reference: {OUT}")


if __name__ == "__main__":
    main()
