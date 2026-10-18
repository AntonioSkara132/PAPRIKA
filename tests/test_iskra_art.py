"""Asset checks for Iskra's original-style NPCs and green park."""
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import create_iskra_concept as art
import create_iskra_npc_sheet as characters
import create_veki_art


class IskraArtTests(unittest.TestCase):
    def test_npc_dimensions_and_original_alpha(self):
        for key, _, source, *_ in characters.VARIANTS:
            with self.subTest(npc=key), Image.open(source) as original:
                sprite = characters.npc(key)
                self.assertEqual(sprite.size, (16, 24))
                self.assertEqual(sprite.getchannel("A").tobytes(), original.getchannel("A").tobytes())

    def test_npc_faces_hands_hair_and_outlines_are_preserved(self):
        for key, _, source, old, *_ in characters.VARIANTS:
            with self.subTest(npc=key), Image.open(source) as original:
                sprite = characters.npc(key)
                allowed = {(*old, 255)}
                if source.parent == characters.MILITARY:
                    allowed.update({(155, 181, 104, 255), (192, 162, 91, 255)})
                changed = 0
                for y in range(24):
                    for x in range(16):
                        before, after = original.getpixel((x, y)), sprite.getpixel((x, y))
                        if before != after:
                            self.assertTrue(9 <= y < 18)
                            self.assertIn(before, allowed)
                            changed += 1
                self.assertGreater(changed, 10)

    def test_transparent_atlas_matches_individual_sprites(self):
        with Image.open(characters.ASSETS / "sheet.png") as atlas:
            self.assertEqual(atlas.size, (64, 72))
            entries = json.loads((characters.ASSETS / "sheet.json").read_text())
            self.assertEqual(len(entries), 12)
            for entry in entries:
                with self.subTest(npc=entry["id"]), Image.open(characters.ASSETS / entry["image"]) as sprite:
                    x, y, w, h = entry["region"]
                    self.assertEqual(atlas.crop((x, y, x+w, y+h)).tobytes(), sprite.tobytes())
                    self.assertEqual(sprite.tobytes(), characters.npc(entry["id"]).tobytes())

    def test_veki_keeps_original_npc_size_hands_and_silhouette(self):
        sprite = create_veki_art.veki()
        with Image.open(create_veki_art.SOURCE) as original:
            self.assertEqual(sprite.size, (16, 24))
            self.assertEqual(sprite.getchannel("A").tobytes(), original.getchannel("A").tobytes())
            self.assertEqual(sprite.crop((0, 17, 16, 24)).tobytes(), original.crop((0, 17, 16, 24)).tobytes())
            for y in range(24):
                for x in range(16):
                    if original.getpixel((x, y)) == characters.SKIN and (x, y) != (9, 6):
                        self.assertEqual(sprite.getpixel((x, y)), characters.SKIN)

    def test_veki_export_is_distinct_from_courier(self):
        with Image.open(create_veki_art.OUT) as sprite:
            self.assertEqual(sprite.tobytes(), create_veki_art.veki().tobytes())
            self.assertNotEqual(sprite.tobytes(), characters.npc("sky_courier").tobytes())
            self.assertEqual(sprite.getpixel((6, 3)), (*create_veki_art.LENS, 255))
            self.assertEqual(sprite.getpixel((6, 11)), (*create_veki_art.SCARF, 255))

    def test_every_map_resident_uses_the_new_npc_assets(self):
        records = json.loads((ROOT / "assets/art/iskra/placement.json").read_text())
        residents = [r for r in records if r["person"]]
        self.assertGreater(len(residents), 50)
        for record in residents:
            self.assertEqual((record["width"], record["height"]), (16, 24))
            self.assertEqual(record["image"], "npcs/" + record["npc_role"] + ".png")

    def test_trees_and_benches_have_collision_rectangles(self):
        records = json.loads((ROOT / "assets/art/iskra/placement.json").read_text())
        trees = [r for r in records if r["kind"] == "leafy_tree"]
        benches = [r for r in records if r["kind"] == "park_bench"]
        self.assertEqual(len(trees), 14)
        self.assertEqual(len(benches), 4)
        for record in trees + benches:
            self.assertEqual(len(record["solid_rect"]), 4)

    def test_new_park_is_separate_from_punk_park(self):
        self.assertFalse(np.any(art.poly_mask(art.NATURE_PARK) & art.poly_mask(art.PARK)))
        self.assertFalse(np.any(art.poly_mask(art.NATURE_PARK) & art.layout()["canals"]))

    def test_playable_npc_tiles_are_not_scaled_up(self):
        world = json.loads((ROOT / "maps/iskra.tmj").read_text())
        city = next(layer for layer in world["layers"] if layer["name"] == "City")
        tiles = json.loads((ROOT / "maps/iskra_objects.tsj").read_text())["tiles"]
        images = {tile["id"] + 100: tile["image"] for tile in tiles}
        for obj in city["objects"]:
            if obj["name"].startswith("story_resident_"):
                self.assertEqual((obj["width"], obj["height"]), (16, 24))
                self.assertIn("/iskra/npcs/", images[obj["gid"]])

    def test_warm_ambient_lighting_and_green_grass(self):
        neutral = np.full((1, 1, 3), 100, dtype=np.float32)
        lit = art.shade_pixels(neutral, np.zeros_like(neutral))[0, 0]
        self.assertGreater(lit[0], lit[2])
        with Image.open(ROOT / "assets/art/iskra/ground.png") as ground:
            r, g, b = ground.getpixel((350, 640 + art.MARGIN))[:3]
            self.assertGreater(g, r)
            self.assertGreater(g, b)


if __name__ == "__main__":
    unittest.main()
