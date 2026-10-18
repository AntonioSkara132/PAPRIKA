"""Every inventory item has a transparent, reproducible 16×16 picture."""

from io import BytesIO
from pathlib import Path
import re
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import create_item_icons as art


class ItemIconTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        game_data = (ROOT / "scripts/data/game_data.gd").read_text()
        items = game_data.split("const ITEMS := {", 1)[1].split("\nconst JOBS :=", 1)[0]
        cls.registered = set(re.findall(r'^\s*"([a-z_]+)":\s*\{', items, re.MULTILINE))
        lookup = (ROOT / "scripts/data/item_icons.gd").read_text()
        cls.paths = dict(re.findall(r'^\s*"([a-z_]+)":\s*"(res://[^"]+\.png)"', lookup, re.MULTILINE))

    def test_explicit_mapping_covers_every_item_and_basic_arrow(self):
        expected = self.registered | {"basic_arrow", "bronze_arrow", "iron_arrow"}
        self.assertEqual(len(expected), 68)
        self.assertEqual(set(art.ITEM_IDS), expected)
        self.assertEqual(set(self.paths), expected)
        self.assertIn('static func icon_path(item_id: String) -> String:',
                      (ROOT / "scripts/data/item_icons.gd").read_text())

    def test_icons_are_transparent_16_pixel_images(self):
        for item_id, path in self.paths.items():
            with self.subTest(item=item_id):
                file = ROOT / path.removeprefix("res://")
                self.assertTrue(file.is_file(), file)
                with Image.open(file) as icon:
                    self.assertEqual(icon.size, (16, 16))
                    self.assertEqual(icon.mode, "RGBA")
                    alpha = list(icon.getchannel("A").getdata())
                    self.assertIn(0, alpha)
                    self.assertGreater(sum(a > 0 for a in alpha), 12)
                    self.assertLess(sum(a > 0 for a in alpha), 220)

    def test_generated_icons_match_the_source_art(self):
        for item_id in set(art.ITEM_IDS) - art.EXISTING:
            with self.subTest(item=item_id):
                path = ROOT / self.paths[item_id].removeprefix("res://")
                expected = BytesIO()
                art.draw_icon(item_id).save(expected, format="PNG", optimize=False)
                self.assertEqual(path.read_bytes(), expected.getvalue())

    def test_item_variants_remain_visually_distinct(self):
        for group in (
            ("basic_arrow", "bronze_arrow", "iron_arrow", "banishing_arrow"),
            ("wood_sword", "bronze_sword", "iron_sword", "tvrdium_sword"),
            ("red_tunic", "blue_tunic", "green_tunic", "purple_tunic",
             "orange_tunic", "sea_glass_tunic", "coral_tunic"),
            ("practice_mine", "field_mine"),
        ):
            pictures = []
            for item_id in group:
                with Image.open(ROOT / self.paths[item_id].removeprefix("res://")) as image:
                    pictures.append(image.tobytes())
            self.assertEqual(len(set(pictures)), len(group), group)


if __name__ == "__main__":
    unittest.main()
