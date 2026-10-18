"""Punk outfit exports, original proportions, and playable park assignments."""
import json
from pathlib import Path
import random
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import create_iskra_concept as art
import create_iskra_punks as punks


class PunkOutfitTests(unittest.TestCase):
    def test_eight_distinct_outfits_preserve_proportions_and_hands(self):
        originals = Image.open(punks.SOURCE).convert("RGBA")
        sprites = punks.variants()
        self.assertEqual(len(sprites), 8)
        self.assertEqual(len({image.tobytes() for image in sprites.values()}), 8)
        for key, sprite in sprites.items():
            with self.subTest(role=key):
                self.assertEqual(sprite.size, (16, 24))
                self.assertEqual(sprite.getchannel("A").tobytes(), originals.getchannel("A").tobytes())
                self.assertEqual(sprite.crop((0, 5, 16, 9)).tobytes(), originals.crop((0, 5, 16, 9)).tobytes())
                for x in (3, 4, 11, 12):
                    self.assertEqual(sprite.getpixel((x, 15)), originals.getpixel((x, 15)))
                self.assertEqual(sprite.crop((0, 22, 16, 24)).tobytes(), originals.crop((0, 22, 16, 24)).tobytes())

    def test_atlas_and_individual_exports_match_generator(self):
        entries = json.loads((punks.OUT / "punk_sheet.json").read_text())
        self.assertEqual(len(entries), 8)
        with Image.open(punks.OUT / "punk_sheet.png") as atlas:
            self.assertEqual(atlas.size, (64, 48))
            for entry in entries:
                x, y, w, h = entry["region"]
                with Image.open(punks.OUT / entry["image"]) as sprite:
                    self.assertEqual(sprite.tobytes(), punks.variants()[entry["id"]].tobytes())
                    self.assertEqual(atlas.crop((x, y, x+w, y+h)).tobytes(), sprite.tobytes())

    def test_concept_keeps_random_layout_sequence(self):
        rng, original = random.Random(4), random.Random(4)
        for i in range(14):
            original.choice([(40, 36, 52), (90, 30, 60), (30, 30, 30)])
            original.choice(art.NEONS[:4])
            sprite = art.punk(rng, i)
            self.assertEqual(rng.getstate(), original.getstate())
            self.assertEqual(sprite.info["npc_role"], punks.VARIANTS[i % 8][0])

    def test_park_records_assign_all_eight_outfits(self):
        records = json.loads((ROOT / "assets/art/iskra/placement.json").read_text())
        residents = [r for r in records if r["kind"] == "punk"]
        self.assertEqual(len(residents), 14)
        self.assertEqual({r["npc_role"] for r in residents}, set(punks.variants()))
        for i, record in enumerate(residents):
            key = punks.VARIANTS[i % 8][0]
            self.assertEqual(record["image"], "npcs/" + key + ".png")
            self.assertEqual((record["width"], record["height"]), (16, 24))

    def test_playable_map_uses_each_assigned_outfit(self):
        records = json.loads((ROOT / "assets/art/iskra/placement.json").read_text())
        world = json.loads((ROOT / "maps/iskra.tmj").read_text())
        tiles = json.loads((ROOT / "maps/iskra_objects.tsj").read_text())["tiles"]
        firstgid = next(t["firstgid"] for t in world["tilesets"] if t["source"] == "iskra_objects.tsj")
        images = {tile["id"] + firstgid: tile["image"] for tile in tiles}
        city = next(layer for layer in world["layers"] if layer["name"] == "City")
        objects = {obj["name"]: obj for obj in city["objects"]}
        for index, record in enumerate(records):
            if record["kind"] != "punk":
                continue
            obj = objects["story_resident_" + str(index)]
            self.assertTrue(images[obj["gid"]].endswith("/" + record["image"]))
            self.assertEqual((obj["width"], obj["height"]), (16, 24))


if __name__ == "__main__":
    unittest.main()
