"""Generate Brudet's 16px terrain atlas without rewriting existing sprites.

Run with /usr/bin/python3 create_river_terrain.py --aseprite to write the
atlas, its editable LibreSprite source, and the River Planet contact sheet.
"""

from pathlib import Path
import argparse
import runpy
import shutil
import subprocess

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
TILE_SIZE = 16
COLUMNS = 8
ATLAS = HERE / "river_terrain.png"
TILE_NAMES = (
    "water_base", "dry_bank", "warm_stone_street", "bank_north",
    "bank_south", "bridge_north_rail", "bridge_south_rail", "bridge_deck",
    "crop_seedlings", "crop_green", "crop_ripe", "crop_harvest",
    "bank_west", "bank_east", "bank_outer_nw", "bank_outer_ne",
    "bank_outer_sw", "bank_outer_se", "bank_inner_nw", "bank_inner_ne",
    "bank_inner_sw", "bank_inner_se", "water_ripple_a", "water_ripple_b",
    "water_deep", "warm_stone_street_a", "warm_stone_street_b",
    "bridge_deck_worn", "bridge_west_entry", "bridge_east_entry",
    "stone_plaza", "stone_curb",
)

WATER = (54, 143, 164, 255)
WATER_DEEP = (42, 119, 147, 255)
WATER_DARK = (31, 96, 127, 255)
TEAL = (36, 127, 138, 255)
CYAN = (95, 214, 211, 255)
FOAM = (130, 203, 208, 255)
SAND = (214, 180, 111, 255)
RIM = (234, 217, 172, 255)
STONE = (185, 182, 166, 255)
STONE_LIGHT = (216, 201, 158, 255)
STONE_DARK = (101, 117, 130, 255)
STREET = (199, 174, 137, 255)
MORTAR = (139, 121, 100, 255)
INK = (28, 23, 48, 255)
GREEN = (67, 134, 74, 255)
GREEN_LIGHT = (99, 168, 82, 255)
SOIL = (132, 85, 53, 255)
SOIL_DARK = (84, 51, 40, 255)
GOLD = (245, 195, 76, 255)


def water_tile(name):
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), WATER)
    d = ImageDraw.Draw(image)
    if name == "water_base":
        d.line((4, 6, 8, 6), fill=CYAN)
        d.point((11, 11), fill=TEAL)
    elif name == "water_ripple_a":
        d.line((3, 5, 9, 5), fill=CYAN)
        d.line((7, 10, 12, 10), fill=FOAM)
        d.point((5, 11), fill=TEAL)
    elif name == "water_ripple_b":
        d.line((5, 4, 11, 4), fill=FOAM)
        d.line((3, 10, 7, 10), fill=CYAN)
        d.point((12, 12), fill=TEAL)
    elif name == "water_deep":
        d.rectangle((3, 3, 12, 12), fill=WATER_DEEP)
        d.line((5, 7, 9, 7), fill=WATER)
        d.point((10, 10), fill=CYAN)
    elif name == "water_flow_east":
        d.line((3, 5, 10, 5), fill=FOAM)
        d.line((9, 4, 12, 6), fill=CYAN)
        d.line((4, 11, 9, 11), fill=CYAN)
    elif name == "water_flow_south":
        d.line((5, 3, 5, 10), fill=FOAM)
        d.line((4, 9, 6, 12), fill=CYAN)
        d.line((11, 5, 11, 9), fill=CYAN)
    elif name == "water_foam":
        d.arc((3, 4, 12, 11), 15, 170, fill=FOAM)
        d.line((6, 10, 11, 10), fill=CYAN)
        d.point((4, 12), fill=FOAM)
    elif name == "water_weeds":
        d.line((5, 12, 7, 7), fill=GREEN)
        d.line((8, 12, 10, 5), fill=GREEN)
        d.line((10, 11, 11, 8), fill=TEAL)
        d.point((10, 5), fill=GOLD)
        d.line((4, 13, 12, 13), fill=WATER_DEEP)
    return image


def is_land(name, x, y):
    if name == "bank_north":
        return y <= 5 + (x in (4, 5, 10, 11))
    if name == "bank_south":
        return y >= 10 - (x in (4, 5, 10, 11))
    if name == "bank_west":
        return x <= 5 + (y in (4, 5, 10, 11))
    if name == "bank_east":
        return x >= 10 - (y in (4, 5, 10, 11))
    if name == "bank_outer_nw":
        return x <= 5 or y <= 5
    if name == "bank_outer_ne":
        return x >= 10 or y <= 5
    if name == "bank_outer_sw":
        return x <= 5 or y >= 10
    if name == "bank_outer_se":
        return x >= 10 or y >= 10
    if name == "bank_inner_nw":
        return not (x <= 9 and y <= 9)
    if name == "bank_inner_ne":
        return not (x >= 6 and y <= 9)
    if name == "bank_inner_sw":
        return not (x <= 9 and y >= 6)
    if name == "bank_inner_se":
        return not (x >= 6 and y >= 6)
    return True


def bank_tile(name):
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), WATER)
    neighbors = ((0, -1), (1, 0), (0, 1), (-1, 0))
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            if is_land(name, x, y):
                color = SAND
                if 2 <= x <= 13 and 2 <= y <= 13 and (x, y) in ((3, 3), (12, 11)):
                    color = STONE_LIGHT
            elif any(is_land(name, x + dx, y + dy) for dx, dy in neighbors):
                color = RIM
            elif any(is_land(name, x + dx * 2, y + dy * 2) for dx, dy in neighbors):
                color = TEAL
            else:
                color = WATER
            image.putpixel((x, y), color)
    return image


def warm_stone_tile(name):
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), STREET)
    d = ImageDraw.Draw(image)
    for y in (5, 11):
        d.line((0, y, 15, y), fill=MORTAR)
    for x, top, bottom in ((8, 0, 4), (3, 6, 10), (12, 6, 10), (8, 12, 15)):
        d.line((x, top, x, bottom), fill=MORTAR)
    d.line((1, 1, 5, 1), fill=STONE_LIGHT)
    d.line((9, 7, 12, 7), fill=STONE_LIGHT)
    if name == "warm_stone_street_a":
        d.point((5, 9), fill=STONE)
        d.line((10, 13, 12, 13), fill=STONE_LIGHT)
    elif name == "warm_stone_street_b":
        d.line((4, 2, 5, 3), fill=STONE_DARK)
        d.point((13, 9), fill=STONE)
    return image


def bridge_tile(name):
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), STONE)
    d = ImageDraw.Draw(image)
    for y in (5, 11):
        d.line((0, y, 15, y), fill=STONE_DARK)
    d.line((8, 0, 8, 4), fill=STONE_DARK)
    d.line((4, 6, 4, 10), fill=STONE_DARK)
    d.line((12, 6, 12, 10), fill=STONE_DARK)
    d.line((8, 12, 8, 15), fill=STONE_DARK)
    d.line((2, 2, 6, 2), fill=STONE_LIGHT)
    d.line((7, 8, 10, 8), fill=STONE_LIGHT)
    if name == "bridge_deck_worn":
        d.line((10, 13, 12, 14), fill=MORTAR)
        d.point((6, 7), fill=STONE_DARK)
    elif name == "bridge_north_rail":
        d.rectangle((0, 0, 15, 4), fill=INK)
        d.rectangle((0, 1, 15, 3), fill=STONE_LIGHT)
        d.line((0, 1, 15, 1), fill=RIM)
    elif name == "bridge_south_rail":
        d.rectangle((0, 11, 15, 15), fill=INK)
        d.rectangle((0, 12, 15, 14), fill=STONE_LIGHT)
        d.line((0, 12, 15, 12), fill=RIM)
    elif name == "bridge_west_entry":
        d.rectangle((0, 0, 5, 15), fill=STREET)
        d.line((5, 0, 5, 15), fill=MORTAR)
        d.line((0, 5, 4, 5), fill=MORTAR)
        d.line((0, 11, 4, 11), fill=MORTAR)
    elif name == "bridge_east_entry":
        d.rectangle((10, 0, 15, 15), fill=STREET)
        d.line((10, 0, 10, 15), fill=MORTAR)
        d.line((11, 5, 15, 5), fill=MORTAR)
        d.line((11, 11, 15, 11), fill=MORTAR)
    return image


def crop_tile(name):
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), SOIL)
    d = ImageDraw.Draw(image)
    d.line((0, 3, 15, 3), fill=SOIL_DARK)
    d.line((0, 11, 15, 11), fill=SOIL_DARK)
    for x in (4, 11):
        d.line((x - 2, 9, x + 2, 9), fill=SAND)
        if name == "crop_seedlings":
            d.line((x, 8, x, 6), fill=GREEN)
            d.point((x - 1, 7), fill=GREEN_LIGHT)
            d.point((x + 1, 7), fill=GREEN_LIGHT)
        else:
            d.line((x, 9, x, 5), fill=GREEN)
            d.line((x - 2, 7, x, 7), fill=GREEN_LIGHT)
            d.line((x, 6, x + 2, 6), fill=GREEN_LIGHT)
            if name in ("crop_ripe", "crop_harvest"):
                d.rectangle((x - 1, 3, x + 1, 5), fill=GOLD)
                d.point((x, 2), fill=RIM)
            if name == "crop_harvest":
                d.line((x - 2, 8, x + 2, 8), fill=GOLD)
                d.point((x + 2, 5), fill=GOLD)
    return image


def make_tile(name):
    if name.startswith("water_"):
        return water_tile(name)
    if name.startswith("bank_") or name == "dry_bank":
        return bank_tile(name)
    if name.startswith("warm_stone_street"):
        return warm_stone_tile(name)
    if name.startswith("crop_"):
        return crop_tile(name)
    if name.startswith("bridge_"):
        return bridge_tile(name)
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), STREET)
    d = ImageDraw.Draw(image)
    if name == "stone_plaza":
        d.line((0, 7, 15, 7), fill=MORTAR)
        d.line((7, 0, 7, 6), fill=MORTAR)
        d.line((7, 8, 7, 15), fill=MORTAR)
        d.rectangle((3, 3, 4, 4), fill=STONE_LIGHT)
        d.point((11, 12), fill=GOLD)
    elif name == "stone_curb":
        d.rectangle((0, 10, 15, 15), fill=STONE)
        d.line((0, 10, 15, 10), fill=RIM)
        d.line((0, 14, 15, 14), fill=STONE_DARK)
        d.line((7, 11, 7, 13), fill=STONE_DARK)
    return image


def terrain_atlas():
    assert len(TILE_NAMES) == 32
    atlas = Image.new("RGBA", (TILE_SIZE * COLUMNS, TILE_SIZE * 4))
    for local_id, name in enumerate(TILE_NAMES):
        tile = make_tile(name)
        atlas.paste(tile, ((local_id % COLUMNS) * TILE_SIZE,
                           (local_id // COLUMNS) * TILE_SIZE))
    return atlas


def refresh_contact_sheet(atlas):
    base = runpy.run_path(str(HERE / "create_river_art.py"), run_name="river_art_preview")
    images = {
        name: Image.open(HERE / f"{name}.png").convert("RGBA")
        for name in base["SPRITES"]
    }
    images["river_terrain"] = atlas
    base["contact_sheet"](images)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aseprite", action="store_true",
                        help="also save an editable LibreSprite atlas")
    args = parser.parse_args()
    sprite = shutil.which("sprite") if args.aseprite else None
    if args.aseprite and sprite is None:
        parser.error("LibreSprite's `sprite` executable is required for --aseprite")
    atlas = terrain_atlas()
    atlas.save(ATLAS)
    if sprite is not None:
        subprocess.run([sprite, "--batch", str(ATLAS), "--save-as",
                        str(ATLAS.with_suffix(".aseprite"))], check=True,
                       stdout=subprocess.DEVNULL)
    refresh_contact_sheet(atlas)
    print(f"{ATLAS.name}: {atlas.width} x {atlas.height}; {len(TILE_NAMES)} local tiles")
    for local_id, name in enumerate(TILE_NAMES):
        print(f"{local_id:02d}: ({local_id % COLUMNS}, {local_id // COLUMNS}) {name}")


if __name__ == "__main__":
    main()
