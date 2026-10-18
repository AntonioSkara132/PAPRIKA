"""Investigation artwork, collision geometry and city access checks."""
from collections import deque
import json
from pathlib import Path
import re
import sys
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import create_iskra_investigation_art as art


class IskraInvestigationArtTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.world = json.loads((ROOT / "maps/iskra.tmj").read_text())
        cls.markers = {m["name"]: (m["x"], m["y"]) for layer in cls.world["layers"]
                       if layer["name"] == "Markers" for m in layer["objects"]}
        walls = next(layer for layer in cls.world["layers"] if layer["name"] == "Hull Walls")
        cls.walk = np.array(walls["data"]).reshape((cls.world["height"], cls.world["width"])) == 0
        cls.city = next(layer for layer in cls.world["layers"] if layer["name"] == "City")["objects"]
        tiles = json.loads((ROOT / "maps/iskra_objects.tsj").read_text())["tiles"]
        cls.images = {tile["id"]+100: tile["image"] for tile in tiles}

    @classmethod
    def reached(cls, point, rect=None):
        start = (int(point[0]//16), int(point[1]//16))
        done, todo = {start}, deque([start])
        x0, y0, x1, y1 = 0, 0, cls.world["width"], cls.world["height"]
        if rect:
            x, y, w, h = rect
            x0, y0, x1, y1 = x//16, y//16, (x+w)//16, (y+h)//16
        while todo:
            x, y = todo.popleft()
            for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if x0 <= nx < x1 and y0 <= ny < y1 and cls.walk[ny, nx] and (nx, ny) not in done:
                    done.add((nx, ny))
                    todo.append((nx, ny))
        return done

    def test_npcs_keep_original_scale_alpha_and_hands(self):
        for role, _, source, *_ in art.VARIANTS:
            with self.subTest(role=role), Image.open(source) as original, Image.open(art.OUT / "npcs" / (role+".png")) as sprite:
                self.assertEqual(sprite.size, (16, 24))
                self.assertEqual(sprite.getchannel("A").tobytes(), original.getchannel("A").tobytes())
                self.assertEqual(sprite.crop((0, 18, 16, 24)).tobytes(), original.crop((0, 18, 16, 24)).tobytes())
                for y in range(24):
                    for x in range(16):
                        if original.getpixel((x, y)) == (220, 167, 120, 255):
                            self.assertEqual(sprite.getpixel((x, y)), original.getpixel((x, y)))

    def test_npc_exports_are_distinct_and_repeatable(self):
        sprites = []
        for role, *_ in art.VARIANTS:
            with Image.open(art.OUT / "npcs" / (role+".png")) as sprite:
                self.assertEqual(sprite.tobytes(), art.npc(role).tobytes())
                sprites.append(sprite.tobytes())
        self.assertEqual(len(set(sprites)), 9)

    def test_board_outfits_are_distinct_native_size_and_keep_faces(self):
        sprites = []
        for role, _, source, *_ in art.BOARD_OUTFITS:
            with self.subTest(role=role), Image.open(source) as original, Image.open(art.OUT / "npcs" / (role+".png")) as sprite:
                self.assertEqual(sprite.size, (16, 24))
                self.assertEqual(sprite.tobytes(), art.npc(role).tobytes())
                # Hair may change under hats and circlets; faces and boots stay the villager's own.
                self.assertEqual(sprite.crop((5, 7, 11, 9)).tobytes(), original.crop((5, 7, 11, 9)).tobytes())
                self.assertEqual(sprite.crop((0, 20, 16, 24)).tobytes(), original.convert("RGBA").crop((0, 20, 16, 24)).tobytes())
                sprites.append(sprite.tobytes())
        self.assertEqual(len(set(sprites)), len(art.BOARD_OUTFITS))
        roles = {outfit[0] for outfit in art.BOARD_OUTFITS}
        heads = {"nation", "technology", "architecture", "navy", "demographics", "finance", "defense"}
        self.assertEqual(roles, {"board_"+head for head in heads} | {"cauliflower_secretary", "diplomatic_secretary"})

    def test_board_chamber_seats_everyone_around_the_table(self):
        heads = ["nation", "technology", "architecture", "navy", "demographics", "finance", "defense"]
        names = heads + ["cauliflower_secretary", "diplomatic_secretary", "mc_stand", "davor_stand", "arrival", "exit"]
        self.assertEqual(set(art.POINTS["board"]), set(names))
        points = [self.markers["inv_board_"+name] for name in names]
        self.assertEqual(len(set(points)), len(points))
        self.assertEqual(set(art.BOARD_SEATS), set(heads))
        cx, cy = art.ROOMS["board"][0]+art.BOARD_CENTRE[0]*2, art.ROOMS["board"][1]+art.BOARD_CENTRE[1]*2
        # The MC and Davor stand in the open end of the table, facing the Heads.
        for name in ("mc_stand", "davor_stand"):
            x, y = self.markers["inv_board_"+name]
            self.assertGreater(y, cy)
            self.assertLess(abs(x-cx), art.BOARD_GAP*2)
        lift = self.markers["inv_board_arrival"]
        self.assertGreater(lift[1], max(self.markers["inv_board_"+head][1] for head in heads))

    def test_npc_atlas_has_native_size_regions(self):
        entries = json.loads((art.OUT / "npcs/sheet.json").read_text())
        roles = art.VARIANTS + art.BOARD_OUTFITS
        self.assertEqual(len(entries), len(roles))
        with Image.open(art.OUT / "npcs/sheet.png") as atlas:
            self.assertEqual(atlas.size, (48, 24*((len(roles)+2)//3)))
            for entry in entries:
                x, y, w, h = entry["region"]
                self.assertEqual((w, h), (16, 24))
                with Image.open(art.OUT / "npcs" / entry["image"]) as sprite:
                    self.assertEqual(atlas.crop((x, y, x+w, y+h)).tobytes(), sprite.tobytes())

    def test_room_rectangles_match_gameplay_data(self):
        source = (ROOT / "scripts/world/iskra_investigation_data.gd").read_text()
        values = re.findall(r'"(\w+)": Rect2\(([\d, ]+)\)', source)
        rooms = {name: tuple(map(int, coords.split(","))) for name, coords in values}
        self.assertEqual(rooms, art.ROOMS)

    def test_interiors_do_not_overlap_previous_rooms_or_city(self):
        previous = [(64, 2816, 384, 256), (640, 2816, 640, 352), (1408, 2816, 640, 352)]
        rooms = list(art.ROOMS.values())
        for index, (x, y, w, h) in enumerate(rooms):
            self.assertGreaterEqual(y, 2704)
            for ox, oy, ow, oh in previous + rooms[index+1:]:
                self.assertTrue(x+w <= ox or ox+ow <= x or y+h <= oy or oy+oh <= y)

    def test_map_contains_all_rooms_without_shifting_arrival(self):
        self.assertGreaterEqual(self.world["height"]*16, 4032)
        self.assertEqual(self.markers["arrival"], (3448, 824))
        self.assertEqual(self.markers["hotel_room_arrival"], (256, 3024))
        self.assertEqual(self.markers["collector_escape"], (1560, 1464))
        self.assertEqual(self.markers["veki_holding"], (1752, 2376))
        for x, y, w, h in art.ROOMS.values():
            self.assertLessEqual(x+w, self.world["width"]*16)
            self.assertLessEqual(y+h, self.world["height"]*16)

    def test_room_art_uses_native_pixels_scaled_twice(self):
        for site, (x, y, w, h) in art.ROOMS.items():
            with self.subTest(site=site), Image.open(art.OUT / (site+".png")) as image:
                self.assertEqual(image.size, (w//2, h//2))
                self.assertEqual(image.tobytes(), art.room_image(site).tobytes())
            matches = [obj for obj in self.city if self.images[obj["gid"]].endswith("/investigation/"+site+".png")]
            self.assertEqual(len(matches), 1)
            obj = matches[0]
            self.assertEqual((obj["x"], obj["y"], obj["width"], obj["height"]), (x, y+h, w, h))
            self.assertEqual(obj["name"], "ground_backdrop")

    def test_all_interior_floor_tiles_are_connected(self):
        for site, rect in art.ROOMS.items():
            with self.subTest(site=site):
                reached = self.reached(self.markers["inv_"+site+"_arrival"], rect)
                x, y, w, h = rect
                floor_count = int(self.walk[y//16:(y+h)//16, x//16:(x+w)//16].sum())
                self.assertEqual(len(reached), floor_count)
                self.assertGreater(floor_count, 100)

    def test_all_interior_markers_are_reachable(self):
        for site, rect in art.ROOMS.items():
            rx, ry, *_ = rect
            reached = self.reached(self.markers["inv_"+site+"_arrival"], rect)
            for suffix, (x, y) in art.POINTS[site].items():
                name = "inv_"+site+"_"+suffix
                with self.subTest(marker=name):
                    self.assertEqual(self.markers[name], (rx+x*2, ry+y*2))
                    self.assertIn(((rx+x*2)//16, (ry+y*2)//16), reached)

    def test_exterior_entries_are_connected_and_separate(self):
        reached = self.reached(self.markers["arrival"])
        points = []
        for name in art.EXTERIOR_POINTS:
            x, y = self.markers[name]
            self.assertIn((x//16, y//16), reached)
            points.append((x, y))
        self.assertEqual(len(set(points)), len(points))
        for site in ("owner", "squirrel", "pelican"):
            x, y = self.markers["inv_"+site+"_entry"]
            self.assertLess(y, 2608)
            self.assertGreater(abs(x-self.markers["holding_office"][0])+abs(y-self.markers["holding_office"][1]), 160)

    def test_walls_and_furniture_block_navigation(self):
        for site, (rx, ry, *_size) in art.ROOMS.items():
            for x, y, w, h in art.WALLS[site]+art.FURNITURE[site]:
                blocked = self.walk[(ry+y*2)//16:(ry+(y+h)*2+15)//16,
                                    (rx+x*2)//16:(rx+(x+w)*2+15)//16]
                self.assertFalse(blocked.any(), (site, x, y))

    def test_each_interior_has_closed_outer_boundaries(self):
        for x, y, w, h in art.ROOMS.values():
            tiles = self.walk[y//16:(y+h)//16, x//16:(x+w)//16]
            self.assertFalse(tiles[0].any())
            self.assertFalse(tiles[-1].any())
            self.assertFalse(tiles[:, 0].any())
            self.assertFalse(tiles[:, -1].any())

    def test_patrol_and_combat_points_have_room_for_characters(self):
        for site in ("squirrel", "pelican"):
            names = [name for name in self.markers if name.startswith("inv_"+site+"_guard_") or name.startswith("inv_"+site+"_ally_")]
            for i, name in enumerate(names):
                x, y = self.markers[name]
                for other in names[i+1:]:
                    ox, oy = self.markers[other]
                    self.assertGreaterEqual((x-ox)**2+(y-oy)**2, 32**2)

    def test_hall_escape_passes_through_multiple_sections(self):
        x, y, *_ = art.ROOMS["hall"]
        path = [self.markers["inv_hall_attacker"]] + [self.markers["inv_hall_flee_"+str(i)] for i in range(3)] + [self.markers["inv_hall_escape"]]
        self.assertLess(path[0][0], x+192)
        self.assertGreater(path[-1][0], x+448)
        self.assertLess(path[2][1], y+128)
        reached = self.reached(path[0], art.ROOMS["hall"])
        for px, py in path:
            self.assertIn((px//16, py//16), reached)

    def test_evidence_props_have_transparent_backgrounds(self):
        for name, size in (("uniform_evidence", (24, 24)), ("contract_record", (16, 16)), ("company_receipt", (16, 16))):
            with Image.open(art.OUT / (name+".png")) as image:
                self.assertEqual(image.size, size)
                alpha = image.getchannel("A")
                self.assertEqual(alpha.getpixel((0, 0)), 0)
                self.assertGreater(alpha.getextrema()[1], 0)


if __name__ == "__main__":
    unittest.main()
