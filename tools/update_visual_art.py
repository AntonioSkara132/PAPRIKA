#!/usr/bin/python3
"""Replace only Paprika's selected building, sign, and forest-tile artwork.

This does not touch Tiled maps or unrelated sprites. Rerun it only when intending
to replace these specific images and their editable LibreSprite copies.
"""

import argparse
from pathlib import Path
import shutil
import subprocess

from PIL import Image

from create_extra_art import clothing_shop, work_office
from paprika_visual_art import (
    draw_forest_tiles, field_sign, forest_sign, forest_warning_sign,
    modern_building,
)

ROOT = Path(__file__).resolve().parents[1]
CONCEPT = ROOT / "art/concepts/source"
EXTRA = ROOT / "assets/art"


def selected_images():
    terrain_source = Image.open(CONCEPT / "terrain_tiles.png").convert("RGBA")
    if terrain_source.width != 128 or terrain_source.height not in (32, 48):
        raise ValueError("Unexpected original terrain dimensions")
    terrain = Image.new("RGBA", (128, 48))
    terrain.paste(terrain_source.crop((0, 0, 128, 32)), (0, 0))
    draw_forest_tiles(terrain)
    return {
        CONCEPT / "terrain_tiles.png": terrain,
        CONCEPT / "forest_sign.png": forest_sign(),
        CONCEPT / "food_shop.png": modern_building(
            "food_shop", (80, 64), "#247f8a", "#5fd6d3", "FOOD", "wedge"),
        CONCEPT / "forge.png": modern_building(
            "forge", (80, 64), "#7d4a3a", "#ef873f", "FORGE", "hex"),
        CONCEPT / "mercenary.png": modern_building(
            "mercenary", (96, 64), "#4b4f68", "#d94b4b", "MERCENARY", "fort"),
        CONCEPT / "travel.png": modern_building(
            "travel", (112, 72), "#247f8a", "#5fd6d3", "TRAVEL", "dome"),
        EXTRA / "work_office.png": work_office(),
        EXTRA / "clothing_shop.png": clothing_shop(),
        EXTRA / "common_field_sign.png": field_sign("COMMON"),
        EXTRA / "private_garden_sign.png": field_sign("PRIVATE"),
        EXTRA / "forest_warning_sign.png": forest_warning_sign(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aseprite", action="store_true",
                        help="also update matching LibreSprite sources")
    args = parser.parse_args()
    sprite = shutil.which("sprite") if args.aseprite else None
    if args.aseprite and sprite is None:
        parser.error("LibreSprite's `sprite` executable is required for --aseprite")
    for png, image in selected_images().items():
        if png.exists() and png.name != "terrain_tiles.png":
            old = Image.open(png)
            if png.name != "forest_sign.png" and old.size != image.size:
                raise ValueError(f"Unexpected existing size for {png}")
            if png.name == "forest_sign.png" and old.size not in ((24, 32), (48, 32)):
                raise ValueError(f"Unexpected existing size for {png}")
        image.save(png)
        if sprite is not None:
            aseprite = (ROOT / "art/concepts/paprika_tileset.aseprite"
                        if png.name == "terrain_tiles.png" else png.with_suffix(".aseprite"))
            subprocess.run([sprite, "--batch", str(png), "--save-as", str(aseprite)],
                           check=True, stdout=subprocess.DEVNULL)
        print(f"{png.relative_to(ROOT)}: {image.width}x{image.height}")


if __name__ == "__main__":
    main()
