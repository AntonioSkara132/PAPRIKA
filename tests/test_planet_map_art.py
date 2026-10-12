"""Checks for the original planet symbols and their transparent sprite atlas."""
import importlib.util
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("planet_art", ROOT / "tools/create_planet_map_art.py")
ART = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ART)


class PlanetArtTests(unittest.TestCase):
    def test_all_symbols_are_native_32px_and_transparent(self):
        for name in ART.NAMES:
            with self.subTest(name=name), Image.open(ART.OUT / (name.lower() + ".png")) as image:
                self.assertEqual(image.size, (32, 32))
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.getpixel((0, 0))[3], 0)
                self.assertGreater(image.getchannel("A").getbbox()[2], 20)
                self.assertLessEqual(len(image.getcolors()), 24)

    def test_known_biomes_have_distinct_art(self):
        names = ["paprika", "brudet", "pomidor", "chvarak", "artichoke", "rudnik", "skoljka", "iskra"]
        images = {ART.planet(name).tobytes() for name in names}
        self.assertEqual(len(images), len(names))

    def test_undefined_terrain_does_not_invent_a_biome(self):
        for name in ["cichvarda", "elektrika", "otpornik"]:
            with self.subTest(name=name):
                self.assertEqual(ART.planet(name).tobytes(), ART.unknown().tobytes())

    def test_generated_files_match_the_source(self):
        for name in ART.NAMES:
            with self.subTest(name=name), Image.open(ART.OUT / (name.lower() + ".png")) as image:
                self.assertEqual(image.tobytes(), ART.planet(name.lower()).tobytes())

    def test_atlas_regions_match_individual_symbols(self):
        records = json.loads((ART.OUT / "sheet.json").read_text())
        self.assertEqual(len(records), len(ART.NAMES))
        self.assertEqual(len({record["id"] for record in records}), len(records))
        with Image.open(ART.OUT / "sheet.png") as sheet:
            self.assertEqual(sheet.size, (128, 96))
            for record in records:
                x, y, w, h = record["region"]
                with Image.open(ART.OUT / record["image"]) as sprite:
                    self.assertEqual(sheet.crop((x, y, x+w, y+h)).tobytes(), sprite.tobytes())

    def test_reference_sheet_is_present(self):
        with Image.open(ART.PREVIEW) as image:
            self.assertEqual(image.size, (576, 468))


if __name__ == "__main__":
    unittest.main()
