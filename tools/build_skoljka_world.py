#!/usr/bin/env python3
"""Build the Skoljka Tiled map and its tilesets.

Skoljka is an underwater city of Engineeria. The city is not one hull but a
cluster of small round rooms standing on the seabed, joined by glass tunnels,
with deep water between them:

- the surface dock at the top, on open sea: a ring of deck round the landing
  pad where the Rudnik ore ship stands, the port office platform, a cargo pier
  and the lift tower; the lift shaft runs down to the city;
- the upper city: the lift pod, the plaza dome with the shell statue, the
  canteen and the kelp garden, the council chamber, the company's office
  bolted on below the plaza, and the company depot to the east, a square
  block of small rooms in the company's own plate;
- the housing quarter to the west: a street dome with shell houses and five
  homes in their own pods, one of them the leak pod behind a pressure door;
- the pump works under the plaza: the control room, four small pump rooms in
  a chain, the sump gallery, a workshop, and the relay hall to the east with
  a service tunnel up to the depot's back door;
- the lower works at the bottom: a junction, three intake rooms, a small
  control room on each side, flood sections A (west) and B (east), and an
  airlock beyond each;
- two seabed shelves outside the airlocks, reached through the airlock
  hatches: the west intake with a broken intake pipe, and the east shelf
  with a wreck and the sealed dock.

Tile layers named "Door <id>" and "Flood <id>" are pressure doors and flood
water that scripts/world/skoljka_world.gd opens and closes at runtime; every
door closes a tunnel from wall to wall. Points the game script needs
(interactables, landing points, spawn points) are point objects in the
"Markers" layer, which the tile loader skips and the world script reads from
this file.

Run tools/create_skoljka_art.py first; it draws the sprites used here.
"""
from __future__ import annotations

import json
import math
import random
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "maps"
ART = "../assets/art/skoljka"
WIDTH, HEIGHT, CELL = 140, 124, 16
SURFACE_ROWS = 20                 # rows 0..19 are the open sea at the surface
RNG = random.Random(2614)

# Terrain atlas order from create_skoljka_art.TERRAIN; the map uses firstgid 1.
T = {name: i + 1 for i, name in enumerate(
    ["hull", "hull_2", "plaza", "plaza_2", "grate", "hull_wall", "glass", "hazard",
     "sea", "sea_2", "flood", "flood_2", "door_h", "door_v", "deck", "deck_2",
     "pad", "sand", "sand_2", "seabed_rock", "lower", "lower_2", "carpet", "carpet_edge",
     "deep", "deep_2", "office", "cell_door",
     "tube_h", "tube_v", "mosaic_0", "mosaic_1", "mosaic_2", "sump", "company_wall", "silt",
     "silt_2", "porthole", "pipe_wall", "garden", "puddle", "shaft", "planks", "checker",
     "rug", "algae", "sand_ripple", "coral_floor"])}

SPRITES = ["port_office", "crane", "cargo", "lift_head", "housing_0", "housing_1",
           "market_stall_0", "market_stall_1", "market_stall_2", "library_shelf", "bench", "dome_lamp", "blue_lamp",
           "council_table", "office_desk", "company_sign", "depot_shelf", "company_crates",
           "big_pump", "pipe_run", "bunk", "kelp_0", "kelp_1", "seabed_rock_0", "seabed_rock_1",
           "frame_window", "sealed_dock_door", "intake_broken", "suit_rack",
           "shell_house", "bubble_house", "boat_house", "capsule_stack", "coral_house", "snail_house",
           "fish_lamp", "laundry_line", "planter", "fish_school_0", "fish_school_1", "jellyfish_0",
           "jellyfish_1", "coral_0", "coral_1", "coral_2", "bubbles", "buoy", "anchor", "barrels",
           "net_rack", "shell_statue", "aquarium", "canteen_table", "workbench", "gauge_panel",
           "lockers", "generator", "fish_bones", "wreck"]
PEOPLE = ["port_officer", "company_clerk", "pumpmaster", "technician", "councillor", "company_rep",
          "crew_lead", "resident_0", "resident_1", "resident_2", "worker_0", "worker_1", "worker_2",
          "worker_3", "engineer", "seeker", "citizen_0", "citizen_1", "citizen_2", "citizen_3",
          "citizen_4", "citizen_5", "citizen_6", "citizen_7"]
OBJECT_IMAGES = {name: f"{ART}/{name}.png" for name in SPRITES}
OBJECT_IMAGES["ore_ship"] = "../assets/art/engineeria/ore_ship.png"
for key in PEOPLE:
    OBJECT_IMAGES[f"person_{key}"] = f"{ART}/person_{key}.png"
NAMES = list(OBJECT_IMAGES)
GID = {name: 100 + i for i, name in enumerate(NAMES)}
SIZE = {}
for name, rel in OBJECT_IMAGES.items():
    with Image.open((MAPS / rel).resolve()) as im:
        SIZE[name] = im.size
# Object names the tile loader gives no collision (see tiled_loader.gd).
WALK_THROUGH = {"fern", "sea_decor"}


# ---- shapes, as sets of cells ----

def disc(cx: float, cy: float, r: float) -> set:
    return {(x, y) for y in range(int(cy - r) - 1, int(cy + r) + 2) for x in range(int(cx - r) - 1, int(cx + r) + 2)
            if (x - cx) ** 2 + (y - cy) ** 2 <= (r + .3) ** 2}


def oval(cx: float, cy: float, rx: float, ry: float) -> set:
    return {(x, y) for y in range(int(cy - ry) - 1, int(cy + ry) + 2) for x in range(int(cx - rx) - 1, int(cx + rx) + 2)
            if ((x - cx) / (rx + .3)) ** 2 + ((y - cy) / (ry + .3)) ** 2 <= 1}


def octagon(cx: int, cy: int, r: int) -> set:
    return {(x, y) for y in range(cy - r, cy + r + 1) for x in range(cx - r, cx + r + 1)
            if abs(x - cx) + abs(y - cy) <= r * 1.42}


def box(x0: int, y0: int, x1: int, y1: int) -> set:
    """Cells from (x0, y0) up to but not including (x1, y1)."""
    return {(x, y) for y in range(y0, y1) for x in range(x0, x1)}


def blob(cx: float, cy: float, rx: float, ry: float, seed: int) -> set:
    """A rough oval with a wavy edge, for pieces of seabed."""
    rng = random.Random(seed)
    p1, p2, p3 = (rng.random() * 6.28 for _ in range(3))
    cells = set()
    for y in range(int(cy - ry * 1.4), int(cy + ry * 1.4) + 1):
        for x in range(int(cx - rx * 1.4), int(cx + rx * 1.4) + 1):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            angle = math.atan2(dy, dx)
            edge = 1 + .14 * math.sin(3 * angle + p1) + .08 * math.sin(7 * angle + p2) + .05 * math.sin(11 * angle + p3)
            if math.hypot(dx, dy) <= edge:
                cells.add((x, y))
    return cells


# Doors: id -> (x, y, direction). A "v" door is a column of three cells across
# a tunnel running east and west, starting at (x, y) and going down; an "h"
# door is a row of three cells across a tunnel running north and south.
DOORS = {
    "housing_west": (48, 37, "v"),
    "housing_inner": (21, 37, "v"),
    "depot_front": (103, 37, "v"),
    "depot_back": (127, 50, "h"),
    "pumps": (69, 52, "h"),
    "lower_works": (69, 79, "h"),
    "lower_a_east": (48, 89, "v"),
    "lower_a_west": (26, 89, "v"),
    "lower_b_west": (92, 89, "v"),
    "lower_b_east": (114, 89, "v"),
    "hatch_west": (16, 98, "h"),
    "hatch_east": (121, 98, "h"),
}


def door_cells(door_id: str) -> set:
    x, y, direction = DOORS[door_id]
    return {(x, y + k) for k in range(3)} if direction == "v" else {(x + k, y) for k in range(3)}


class City:
    """Floors, walls and their styles, built room by room."""
    WALL_TILE = {"glass": "glass", "hull": "hull_wall", "company": "company_wall"}
    PRIORITY = {"glass": 0, "hull": 1, "company": 2}

    def __init__(self) -> None:
        self.floor: dict = {}        # cell -> terrain name
        self.style: dict = {}        # cell -> wall style for walls next to it, or None (open deck)
        self.inner: dict = {}        # cell -> wall style, walls placed inside rooms
        self.rooms: dict = {}        # room name -> cells

    def room(self, name: str, cells: set, floor, style: str | None) -> set:
        for cell in cells:
            self.floor[cell] = floor() if callable(floor) else floor
            self.style[cell] = style
            self.inner.pop(cell, None)
        self.rooms[name] = set(cells)
        return cells

    def tunnel(self, a: tuple, b: tuple, style: str = "glass", corner: str = "hv", floor: str | None = None) -> None:
        """A tunnel three cells wide from cell a to cell b, with one bend. It only
        fills cells that are not floor already, so it never repaints a room."""
        (ax, ay), (bx, by) = a, b
        legs = [((ax, ay), (bx, ay)), ((bx, ay), (bx, by))] if corner == "hv" else [((ax, ay), (ax, by)), ((ax, by), (bx, by))]
        for (x0, y0), (x1, y1) in legs:
            horizontal = y0 == y1
            for x in range(min(x0, x1) - 1, max(x0, x1) + 2):
                for y in range(min(y0, y1) - 1, max(y0, y1) + 2):
                    if (x, y) not in self.floor:
                        self.floor[(x, y)] = floor or ("tube_h" if horizontal else "tube_v")
                        self.style[(x, y)] = style

    def wall(self, cells: set, style: str) -> None:
        for cell in cells:
            self.floor.pop(cell, None)
            self.style.pop(cell, None)
            self.inner[cell] = style

    def ring(self, cells: set, style: str, gaps: set = frozenset()) -> None:
        """Walls round a room drawn inside another room, except at `gaps`."""
        border = {(x + dx, y + dy) for x, y in cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)} - cells
        self.wall({c for c in border if c in self.floor and c not in gaps}, style)

    def walls(self) -> dict:
        result = dict(self.inner)
        for (x, y), style in list(self.style.items()):
            if style is None:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    cell = (x + dx, y + dy)
                    if cell in self.floor:
                        continue
                    old = result.get(cell)
                    if old is None or self.PRIORITY[style] > self.PRIORITY[old]:
                        result[cell] = style
        return result


def mix(a: str, b: str, share: float = .7):
    return lambda: a if RNG.random() < share else b


def blank(fill: int = 0) -> list[int]:
    return [fill] * (WIDTH * HEIGHT)


def layer(name: str, data: list[int], index: int) -> dict:
    return {"id": index, "name": name, "type": "tilelayer", "x": 0, "y": 0,
            "width": WIDTH, "height": HEIGHT, "opacity": 1, "visible": True, "data": data}


def main() -> None:
    city = City()
    objects: list[dict] = []
    markers: list[dict] = []

    def add(name: str, sprite: str, x: float, bottom: float) -> None:
        w, h = SIZE[sprite]
        objects.append({"id": 0, "name": name, "type": "skoljka_object",
                        "gid": GID[sprite], "x": round(x), "y": round(bottom),
                        "width": w, "height": h, "rotation": 0, "visible": True})

    def put(name: str, sprite: str, cx: float, cy: float) -> None:
        """Places a sprite centred on cell column cx with its feet in cell row cy."""
        add(name, sprite, cx * CELL + 8 - SIZE[sprite][0] // 2, cy * CELL + 12)

    def mark(name: str, cx: float, cy: float) -> None:
        markers.append({"id": 0, "name": name, "type": "marker", "point": True,
                        "x": round(cx * CELL + 8), "y": round(cy * CELL + 8),
                        "width": 0, "height": 0, "rotation": 0, "visible": True})

    def person(key: str, cx: float, cy: float) -> None:
        """A story person standing with their feet in cell (cx, cy)."""
        put(f"story_{key}", f"person_{key}", cx, cy)

    def decor(sprite: str, cx: float, cy: float) -> None:
        put("sea_decor", sprite, cx, cy)

    # =================== the surface dock ===================
    city.room("dock_ring", disc(70, 10, 9), mix("deck", "deck_2"), None)
    city.room("port_deck", box(46, 6, 62, 14) - {(46, 6), (46, 13), (47, 6), (46, 7)}, mix("deck", "deck_2"), None)
    city.room("cargo_pier", box(78, 9, 96, 12) | disc(98, 10, 3), mix("deck_2", "deck"), None)
    city.room("lift_tower", disc(60, 17, 2.6), "hazard", None)
    for cell in disc(70, 10, 5.5):
        city.floor[cell] = "pad"
    for cell in disc(70, 10, 6.4) - disc(70, 10, 5.5):
        city.floor[cell] = "hazard"
    add("ore_ship", "ore_ship", 70 * CELL + 8 - SIZE["ore_ship"][0] // 2, 9 * CELL + 8)
    add("port_office", "port_office", 48 * CELL, 12 * CELL + 8)
    put("crane", "crane", 63, 4)
    put("crane", "crane", 77, 4)
    put("crane", "crane", 99, 9)
    for x, y in ((54, 12), (57, 12), (80, 11), (88, 10), (93, 11), (96, 12), (75, 17)):
        put("cargo", "cargo", x, y)
    put("barrels", "barrels", 85, 11)
    put("anchor", "anchor", 58, 8)
    put("net_rack", "net_rack", 52, 8)
    put("lift_head", "lift_head", 60, 17)
    mark("lift_top", 60, 18)
    for x, y in ((63, 14), (77, 15), (91, 10)):
        put("blue_lamp", "blue_lamp", x, y)
    person("port_officer", 64, 16)
    person("company_clerk", 66, 17)
    for x, y in ((40, 4), (106, 6), (88, 2), (44, 17), (102, 16), (30, 10), (118, 12)):
        decor("buoy", x, y)

    # =================== the upper city ===================
    city.room("lift_pod", disc(60, 26, 3), "grate", "glass")
    city.room("library", disc(51, 32, 4), mix("checker", "plaza_2"), "glass")
    city.room("plaza", oval(70, 37, 12, 8), mix("plaza", "plaza_2"), "glass")
    city.room("canteen", disc(89, 28, 5), "planks", "glass")
    city.room("garden", disc(99, 22, 3.4), "garden", "glass")
    city.room("council", disc(55, 50, 5), "carpet", "hull")
    city.room("office", box(75, 48, 87, 55), "office", "company")
    city.tunnel((60, 28), (63, 33), corner="vh")
    city.tunnel((55, 33), (60, 35), corner="hv")
    city.tunnel((82, 38), (103, 38))
    city.tunnel((88, 32), (88, 37))
    city.tunnel((93, 24), (97, 24))
    city.room("kitchen", disc(79, 24, 3), "checker", "glass")
    city.tunnel((82, 25), (85, 25))
    city.tunnel((63, 42), (57, 46), corner="vh")
    city.tunnel((77, 43), (77, 48), style="company")
    # the scallop mosaic round the statue: ribs fanning up from its hinge
    for x, y in oval(70, 37, 12, 8):
        dx, dy = x - 70, y - 40
        r = math.hypot(dx, dy)
        if r > 7.2 or dy > 0:
            continue
        angle = math.degrees(math.atan2(dx, -dy))
        city.floor[(x, y)] = "mosaic_2" if r > 6.2 or r < 1.4 else ("mosaic_0" if int((angle + 90) // 20) % 2 else "mosaic_1")
    for x in range(64, 77):
        city.floor[(x, 41)] = "mosaic_2"

    # the lift pod
    put("lift_head", "lift_head", 60, 25)
    mark("lift_bottom", 60, 27)
    put("planter", "planter", 57, 27)
    put("fish_lamp", "fish_lamp", 63, 25)
    # the library north of the housing passage
    put("skoljka_library", "library_shelf", 51, 30)
    put("library_books", "library_shelf", 48, 31)
    put("bench", "bench", 53, 34)
    put("fish_lamp", "fish_lamp", 55, 32)
    # the plaza
    put("shell_statue", "shell_statue", 70, 38)
    mark("plaza_centre", 70, 40)
    for i, (x, y) in enumerate(((61, 33), (78, 33), (79, 41))):
        put(("skoljka_food", "skoljka_clothing", "skoljka_apothecary")[i], f"market_stall_{i}", x, y)
    for x, y in ((64, 35), (76, 35), (61, 39), (80, 37), (65, 44), (75, 44)):
        put("fish_lamp", "fish_lamp", x, y)
    for x, y in ((63, 30), (77, 30), (59, 37)):
        put("planter", "planter", x, y)
    put("bench", "bench", 66, 43)
    put("bench", "bench", 74, 43)
    person("seeker", 68, 33)
    for i, (x, y) in enumerate(((89, 28), (75, 34), (99, 23), (64, 38),
                                 (36, 38), (42, 40), (70, 63), (54, 52))):
        person(f"citizen_{i}", x, y)
    citizen_stops = {
        "seeker": ((68, 33), (66, 35), (70, 34)),
        "citizen_0": ((89, 28), (88, 29), (90, 29)),
        "citizen_1": ((75, 34), (76, 36), (79, 36)),
        "citizen_2": ((99, 23), (97, 23), (100, 22)),
        "citizen_3": ((64, 38), (74, 39), (61, 37)),
        "citizen_4": ((36, 38), (32, 39), (40, 38)),
        "citizen_5": ((42, 40), (39, 39), (43, 40)),
        "citizen_6": ((70, 63), (68, 63), (72, 63)),
        "citizen_7": ((54, 52), (52, 51), (58, 51)),
        "resident_0": ((10, 38), (12, 38)),
        "resident_1": ((14, 37), (16, 38)),
        "resident_2": ((12, 40), (14, 40)),
    }
    for key, stops in citizen_stops.items():
        for i, (x, y) in enumerate(stops):
            mark(f"{key}_stop_{i}", x, y)
    mark("niko_reunion", 68, 34)
    put("company_sign", "company_sign", 80, 45)
    # the canteen
    for x, y in ((86, 26), (92, 26), (86, 30), (92, 30)):
        put("canteen_table", "canteen_table", x, y)
    put("aquarium", "aquarium", 89, 24)
    put("barrels", "barrels", 93, 31)
    # the canteen's kitchen
    put("workbench", "workbench", 79, 22)
    put("barrels", "barrels", 77, 25)
    put("net_rack", "net_rack", 80, 26)
    # the kelp garden
    for x, y in ((97, 21), (101, 21), (99, 24)):
        put("planter", "planter", x, y)
    mark("garden", 99, 23)
    # the council chamber
    for cell in disc(55, 50, 5) - disc(55, 50, 4):
        city.floor[cell] = "carpet_edge" if cell[1] < 50 else "carpet"
    put("council_table", "council_table", 55, 50)
    person("councillor", 55, 48)
    mark("council_spot", 55, 52)
    put("planter", "planter", 51, 47)
    put("planter", "planter", 59, 47)
    # the company office: square, bolted on under the plaza
    put("office_desk", "office_desk", 82, 51)
    person("company_rep", 82, 50)
    put("lockers", "lockers", 85, 49)
    put("company_crates", "company_crates", 76, 53)

    # =================== the housing quarter ===================
    city.room("shell_row", oval(36, 37, 9, 6), mix("checker", "plaza_2", .55), "glass")
    city.tunnel((44, 38), (58, 38))
    city.room("leak_pod", disc(13, 38, 5), mix("planks", "rug", .75), "glass")
    city.tunnel((18, 38), (28, 38))
    city.room("bubble_pod", disc(24, 26, 4.5), "garden", "glass")
    city.tunnel((27, 34), (25, 29), corner="vh")
    city.room("boat_pod", oval(41, 25, 6, 4), "sand_ripple", "glass")
    city.tunnel((40, 32), (40, 28))
    city.room("coral_pod", disc(31, 50, 4.5), "coral_floor", "glass")
    city.tunnel((33, 42), (31, 46), corner="vh")
    city.room("capsule_pod", disc(19, 52, 4), "checker", "glass")
    city.tunnel((27, 51), (22, 51))
    city.room("snail_pod", disc(43, 51, 3.5), "rug", "glass")
    city.tunnel((35, 51), (40, 51))
    # Shell Row, the quarter's street
    put("shell_house", "shell_house", 32, 36)
    put("snail_house", "snail_house", 41, 36)
    put("laundry_line", "laundry_line", 36, 33)
    for x, y in ((29, 39), (44, 39), (36, 42)):
        put("fish_lamp", "fish_lamp", x, y)
    put("planter", "planter", 28, 35)
    put("barrels", "barrels", 39, 41)
    mark("housing_entry", 46, 38)
    mark("housing_safe", 36, 39)
    mark("housing_lever", 19, 38)
    # the leak pod: three residents live here
    put("bunk", "bunk", 11, 35)
    put("bunk", "bunk", 15, 41)
    put("aquarium", "aquarium", 11, 41)
    person("resident_0", 10, 38)
    person("resident_1", 14, 37)
    person("resident_2", 12, 40)
    mark("leak_point", 18, 38)
    # the homes
    put("bubble_house", "bubble_house", 24, 26)
    put("planter", "planter", 21, 28)
    put("boat_house", "boat_house", 41, 25)
    put("net_rack", "net_rack", 45, 27)
    put("coral_house", "coral_house", 31, 50)
    put("coral_0", "coral_0", 28, 53)
    put("coral_1", "coral_1", 34, 53)
    put("capsule_stack", "capsule_stack", 19, 52)
    put("laundry_line", "laundry_line", 19, 55)
    put("housing", "housing_1", 43, 51)

    # =================== the company depot ===================
    # Six square rooms of the company's plate, two walls thick between them,
    # joined by short doorways. The front door opens into the reception; the
    # back door opens into the back room, two rooms away from the records.
    depot_rooms = {
        "depot_bunks": box(104, 24, 112, 35), "depot_store_north": box(114, 24, 123, 35),
        "depot_records": box(125, 24, 134, 35), "depot_reception": box(104, 37, 112, 50),
        "depot_store_south": box(114, 37, 123, 50), "depot_back": box(125, 37, 134, 50),
    }
    for name, cells in depot_rooms.items():
        city.room(name, cells, mix("office", "hull_2", .93), "company")
    for a, b in (((111, 29), (115, 29)), ((122, 27), (126, 27)), ((108, 34), (108, 38)),
                 ((118, 34), (118, 38)), ((111, 46), (115, 46)), ((122, 44), (126, 44))):
        city.tunnel(a, b, style="company", floor="office")
    # the reception
    put("office_desk", "office_desk", 108, 42)
    put("company_sign", "company_sign", 106, 47)
    put("lockers", "lockers", 110, 48)
    put("planter", "planter", 105, 42)
    put("bench", "bench", 110, 44)
    # the crews' bunk room
    for x, y in ((106, 27), (110, 27), (106, 31)):
        put("bunk", "bunk", x, y)
    put("lockers", "lockers", 110, 32)
    # the storage rooms: shelves in rows, with an aisle down the middle
    for x, y in ((116, 27), (121, 27), (116, 32), (121, 32), (116, 41), (121, 41), (116, 46), (121, 46)):
        put("depot_shelf", "depot_shelf", x, y)
    for x, y in ((115, 25), (122, 25), (115, 38), (122, 38), (119, 49)):
        put("company_crates", "company_crates", x, y)
    # the records room
    put("office_desk", "office_desk", 129, 29)
    put("gauge_panel", "gauge_panel", 132, 26)
    put("company_crates", "company_crates", 127, 25)
    put("lockers", "lockers", 132, 33)
    mark("depot_records", 129, 31)
    # the back room
    put("generator", "generator", 131, 40)
    put("workbench", "workbench", 128, 42)
    put("barrels", "barrels", 132, 46)
    put("company_crates", "company_crates", 126, 48)
    mark("depot_front_outside", 100, 38)
    mark("depot_front_inside", 105, 38)
    mark("assassin_front", 97, 38)
    mark("assassin_back", 128, 54)
    mark("depot_back_inside", 128, 48)
    for i, (x, y) in enumerate(((118, 30), (118, 44), (108, 30), (129, 38))):
        mark(f"crew_patrol_{i}", x, y)
    person("crew_lead", 99, 37)
    put("company_crates", "company_crates", 97, 40)

    # =================== the pump works ===================
    city.tunnel((70, 45), (70, 61))
    city.room("pump_control", disc(70, 64, 4.5), "grate", "hull")
    pump_rooms = ((40, 66), (54, 70), (86, 70), (100, 66))
    for i, (x, y) in enumerate(pump_rooms):
        city.room(f"pump_room_{i}", octagon(x, y, 4), mix("hull", "hull_2", .8), "hull")
    city.tunnel((66, 66), (57, 70), style="hull", corner="vh", floor="grate")
    city.tunnel((51, 69), (43, 66), style="hull", corner="vh", floor="grate")
    city.tunnel((74, 66), (83, 70), style="hull", corner="vh", floor="grate")
    city.tunnel((89, 69), (97, 66), style="hull", corner="vh", floor="grate")
    city.room("workshop", disc(26, 66, 4), mix("hull_2", "hull"), "hull")
    city.tunnel((30, 66), (37, 66), style="hull", floor="grate")
    city.room("sump_gallery", box(62, 70, 79, 76), mix("lower", "lower_2"), "hull")
    city.tunnel((70, 68), (70, 70), style="hull", floor="grate")
    for x in range(62, 79):
        if not 69 <= x <= 71:
            city.floor[(x, 73)] = "sump"
    city.room("relay_hall", octagon(118, 66, 6), mix("hull_2", "hull", .8), "hull")
    city.tunnel((104, 66), (112, 66), style="hull", floor="grate")
    city.tunnel((124, 66), (128, 51), style="hull")
    for i, (x, y) in enumerate(pump_rooms):
        put("main_pump", "big_pump", x, y - 1)
        mark(f"valve_{i}", x, y + 1)
        put("gauge_panel", "gauge_panel", x - 3 if i < 2 else x + 3, y - 1)
    for x, y in ((37, 69), (57, 73), (83, 73), (103, 69)):
        put("blue_lamp", "blue_lamp", x, y)
    mark("pump_console", 70, 64)
    mark("pressure_log", 67, 65)
    person("pumpmaster", 72, 65)
    put("gauge_panel", "gauge_panel", 67, 62)
    # the pump rooms: pipes along the walls, spares and lamps
    for i, (x, y) in enumerate(pump_rooms):
        put("pipe_run", "pipe_run", x, y + 3)
        put("cargo" if i % 2 else "barrels", "cargo" if i % 2 else "barrels", x + (3 if i < 2 else -3), y + 2)
    put("lockers", "lockers", 64, 66)
    put("workbench", "workbench", 76, 66)
    put("anchor", "anchor", 23, 63)
    put("pipe_run", "pipe_run", 28, 63)
    put("blue_lamp", "blue_lamp", 115, 63)
    put("generator", "generator", 121, 71)
    put("pipe_run", "pipe_run", 66, 72)
    put("pipe_run", "pipe_run", 75, 72)
    put("gauge_panel", "gauge_panel", 73, 62)
    put("workbench", "workbench", 25, 64)
    put("generator", "generator", 27, 69)
    put("lockers", "lockers", 23, 68)
    put("barrels", "barrels", 64, 75)
    put("barrels", "barrels", 77, 71)
    for i, (x, y) in enumerate(((114, 64), (116, 62), (120, 62), (122, 64), (118, 71))):
        mark(f"rack_{i}", x, y)
    mark("relay_console", 118, 67)
    person("technician", 115, 69)
    mark("depot_back_lever", 129, 55)
    for i, (x, y) in enumerate(pump_rooms):
        mark(f"cutoff_{i}", x + (2 if i < 2 else -2), y + 2)
        mark(f"crew_climax_{i}_0", x - 2, y + 1)
        mark(f"crew_climax_{i}_1", x + 2, y + 1)

    # =================== the lower works ===================
    city.tunnel((70, 74), (70, 85), style="hull")
    city.room("junction", octagon(70, 88, 5), mix("lower", "lower_2"), "hull")
    city.room("intake_west", disc(57, 98, 3.6), mix("algae", "lower"), "hull")
    city.room("intake_middle", disc(70, 100, 3.6), mix("algae", "lower"), "hull")
    city.room("intake_east", disc(83, 98, 3.6), mix("algae", "lower"), "hull")
    city.tunnel((67, 92), (57, 95), style="hull", corner="vh", floor="grate")
    city.tunnel((70, 93), (70, 97), style="hull", floor="grate")
    city.tunnel((73, 92), (83, 95), style="hull", corner="vh", floor="grate")
    city.room("control_a", disc(55, 88, 3), "grate", "hull")
    city.room("control_b", disc(85, 88, 3), "grate", "hull")
    city.tunnel((58, 88), (65, 88), style="hull")
    city.tunnel((75, 88), (82, 88), style="hull")
    city.room("section_a", disc(38, 90, 7), mix("lower", "puddle", .8), "hull")
    city.room("section_b", disc(102, 90, 7), mix("lower", "puddle", .8), "hull")
    city.tunnel((44, 90), (52, 90), style="hull")
    city.tunnel((88, 90), (96, 90), style="hull")
    city.room("airlock_west", disc(17, 92, 4.5), "grate", "hull")
    city.room("airlock_east", disc(122, 92, 4.5), "grate", "hull")
    city.tunnel((21, 90), (31, 90), style="hull")
    city.tunnel((109, 90), (118, 90), style="hull")
    city.tunnel((17, 96), (17, 101), style="hull", floor="grate")
    city.tunnel((122, 96), (122, 101), style="hull", floor="grate")
    mark("lower_entry", 70, 84)
    mark("workers_safe", 70, 89)
    for i, (x, y) in enumerate(((68, 89), (69, 90), (71, 90), (72, 89))):
        mark(f"worker_safe_{i}", x, y)
    mark("lower_a_console", 55, 87)
    mark("lower_b_console", 85, 87)
    put("gauge_panel", "gauge_panel", 53, 87)
    put("gauge_panel", "gauge_panel", 87, 87)
    for i, (x, y) in enumerate(((66, 86), (70, 102), (74, 86))):
        mark(f"air_{i}", x, y)
    for i, (x, y) in enumerate(((57, 99), (72, 101), (83, 99))):
        put("intake_pipe", "intake_broken", x, y)
        mark(f"creature_{i}", x, y - 2)
    for x, y in ((67, 91), (73, 91), (54, 96), (86, 96)):
        put("blue_lamp", "blue_lamp", x, y)
    put("lockers", "lockers", 68, 85)
    put("barrels", "barrels", 74, 84)
    put("barrels", "barrels", 34, 94)
    put("workbench", "workbench", 104, 93)
    put("cargo", "cargo", 99, 87)
    put("barrels", "barrels", 41, 87)
    put("cargo", "cargo", 36, 87)
    put("pipe_run", "pipe_run", 38, 95)
    put("pipe_run", "pipe_run", 102, 95)
    # the sea got into the intake rooms: kelp grows on the floor
    for x, y in ((55, 96), (59, 100), (68, 98), (73, 98), (81, 96), (85, 100)):
        put("fern", "kelp_0" if (x + y) % 2 else "kelp_1", x, y)
    put("lockers", "lockers", 15, 96)
    put("lockers", "lockers", 124, 95)
    put("gauge_panel", "gauge_panel", 119, 95)
    put("barrels", "barrels", 125, 90)
    person("engineer", 86, 89)
    # the airlocks: the four trapped workers shelter in the west one
    for i, (x, y) in enumerate(((15, 90), (18, 90), (14, 94), (19, 94))):
        person(f"worker_{i}", x, y)
    put("suit_rack", "suit_rack", 17, 89)
    put("suit_rack", "suit_rack", 122, 89)
    mark("airlock_west", 17, 91)
    mark("airlock_west_stand", 17, 94)
    mark("airlock_east", 122, 91)
    mark("airlock_east_stand", 122, 94)

    # =================== the seabed ===================
    west_shelf = blob(30, 112, 25, 8.5, 7) | disc(17, 104, 2.5)
    east_shelf = blob(110, 113, 25, 8.5, 11) | disc(122, 104, 2.5)
    sealed_dock = box(127, 99, 140, 112)
    sealed_dock_bottom = 111
    east_shelf -= sealed_dock
    intake_pipe = box(37, 98, 40, 105)
    shelves = (west_shelf | east_shelf) - intake_pipe
    for cell in shelves:
        if cell not in city.floor:
            city.floor[cell] = RNG.choice(["sand", "sand", "sand_2", "sand_ripple"])
            city.style[cell] = None
    city.rooms["seabed_west"] = west_shelf
    city.rooms["seabed_east"] = east_shelf
    mark("seabed_west_hatch", 17, 102)
    mark("seabed_west_land", 17, 104)
    mark("intake", 38, 107)
    mark("evidence", 46, 113)
    mark("seabed_creature_0", 27, 113)
    mark("seabed_creature_1", 49, 108)
    mark("seabed_east_hatch", 122, 102)
    mark("seabed_east_land", 122, 104)
    mark("frame_window_view", 131, 114)

    # ---- inner walls: the walls of the depot's rooms are already in city.inner ----
    walls_by_cell = city.walls()
    for cell in intake_pipe:
        walls_by_cell[cell] = "pipe"
    # The sealed dock: a plated roof, with its front wall facing the shelf.
    for cell in sealed_dock:
        walls_by_cell[cell] = "dock_front" if cell[1] == sealed_dock_bottom else "dock_roof"
    # pressure doors cut through tunnel walls
    for door_id in DOORS:
        for cell in door_cells(door_id):
            if city.floor.get(cell) is None:
                raise SystemExit(f"door {door_id} cell {cell} is not on a floor")
            city.floor[cell] = "hazard"
            walls_by_cell.pop(cell, None)
        x, y, direction = DOORS[door_id]
        ends = [(x, y - 1), (x, y + 3)] if direction == "v" else [(x - 1, y), (x + 3, y)]
        for end in ends:
            if end not in walls_by_cell:
                raise SystemExit(f"door {door_id} does not close its tunnel at {end}")

    # seabed decoration: kelp and coral to walk through, rocks to walk round
    for shelf, keep_clear in ((west_shelf, [(17, 103), (38, 107), (46, 113), (27, 113), (49, 108)]),
                              (east_shelf, [(122, 103), (131, 114), (120, 108)])):
        cells = sorted(shelf)
        for _ in range(34):
            x, y = RNG.choice(cells)
            if (x, y) in walls_by_cell or any(abs(x - kx) < 3 and abs(y - ky) < 3 for kx, ky in keep_clear):
                continue
            roll = RNG.random()
            if roll < .5:
                put("fern", RNG.choice(["kelp_0", "kelp_1"]), x, y)
            elif roll < .8:
                decor(RNG.choice(["coral_0", "coral_1", "coral_2"]), x, y)
            elif all((x + dx, y) in shelf for dx in (-1, 0, 1)):
                put("seabed_rock", RNG.choice(["seabed_rock_0", "seabed_rock_1"]), x, y)
    put("intake_pipe", "intake_broken", 38, 105)
    put("fish_bones", "fish_bones", 26, 118)
    put("anchor", "anchor", 11, 110)
    put("wreck", "wreck", 104, 117)
    put("frame_window", "frame_window", 131, 111)
    put("sealed_dock_door", "sealed_dock_door", 136, 111)

    # =================== tiles ===================
    ground, water, walls, rock = blank(), blank(), blank(), blank()
    door_layers = {door_id: blank() for door_id in DOORS}
    flood_layers = {"housing_leak": blank(), "lower_a": blank(), "lower_b": blank()}
    flood_rooms = {"housing_leak": "leak_pod", "lower_a": "section_a", "lower_b": "section_b"}

    def paint(data, cell, name) -> None:
        x, y = cell
        if 0 <= x < WIDTH and 0 <= y < HEIGHT:
            data[y * WIDTH + x] = T[name]

    for cell, name in city.floor.items():
        paint(ground, cell, name)
    for cell, style in walls_by_cell.items():
        name = {"pipe": "pipe_wall", "dock_roof": "hull_2", "dock_front": "hull_wall"}.get(style) or City.WALL_TILE[style]
        paint(walls, cell, name)
    # portholes in hull walls that face open water
    for (x, y), style in walls_by_cell.items():
        if style == "hull" and RNG.random() < .22 and (x, y + 1) not in city.floor and (x, y - 1) in city.floor:
            paint(walls, (x, y), "porthole")
    for x in range(59, 62):
        for y in range(20, 24):
            paint(walls, (x, y), "shaft")
    solid = set(city.floor) | set(walls_by_cell) | {(x, y) for x in range(59, 62) for y in range(20, 24)}
    # Open water everywhere else; under the water near the city, the silt it stands on.
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if (x, y) in solid:
                continue
            if y < SURFACE_ROWS:
                paint(water, (x, y), "sea" if RNG.random() < .6 else "sea_2")
                continue
            near = min((max(abs(dx), abs(dy)) for dx in range(-4, 5) for dy in range(-4, 5) if (x + dx, y + dy) in solid), default=9)
            if near <= 2 or (near <= 4 and RNG.random() < .45):
                paint(water, (x, y), "silt" if RNG.random() < .6 else "silt_2")
            else:
                paint(water, (x, y), "deep" if RNG.random() < .7 else "deep_2")
    # rocks along the shelves' edges
    for shelf in (west_shelf, east_shelf):
        for x, y in shelf:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in solid and 0 <= nx < WIDTH and SURFACE_ROWS <= ny < HEIGHT and RNG.random() < .55:
                    paint(rock, (nx, ny), "seabed_rock")
    # surf rocks round the dock
    for cx, cy in ((34, 6), (110, 4), (122, 15), (20, 15)):
        for cell in disc(cx, cy, 1.6):
            if cell not in solid and RNG.random() < .8:
                paint(rock, cell, "seabed_rock")
    for door_id, (x, y, direction) in DOORS.items():
        for cell in door_cells(door_id):
            paint(door_layers[door_id], cell, "door_v" if direction == "v" else "door_h")
    for flood_id, room_name in flood_rooms.items():
        for cell in city.rooms[room_name]:
            if cell in city.floor:
                paint(flood_layers[flood_id], cell, "flood" if RNG.random() < .6 else "flood_2")

    # life in the deep water between the rooms
    open_water = [(x, y) for y in range(SURFACE_ROWS + 1, HEIGHT - 1) for x in range(2, WIDTH - 2)
                  if (x, y) not in solid and all((x + dx, y + dy) not in solid for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1))]
    for sprite, count in (("fish_school_0", 9), ("fish_school_1", 9), ("jellyfish_0", 6), ("jellyfish_1", 6), ("bubbles", 8)):
        for _ in range(count):
            x, y = RNG.choice(open_water)
            decor(sprite, x, y)
    for _ in range(46):
        x, y = RNG.choice(open_water)
        if water[y * WIDTH + x] in (T["silt"], T["silt_2"]):
            if RNG.random() < .6:
                put("fern", RNG.choice(["kelp_0", "kelp_1"]), x, y)
            else:
                decor(RNG.choice(["coral_0", "coral_1", "coral_2"]), x, y)

    for index, obj in enumerate(objects):
        obj["id"] = index + 1
    for index, marker in enumerate(markers):
        marker["id"] = len(objects) + index + 1

    layers = [layer("Ground", ground, 1), layer("Water", water, 2), layer("Hull Walls", walls, 3),
              layer("Seabed Rock", rock, 4)]
    next_id = 5
    for door_id in DOORS:
        layers.append(layer(f"Door {door_id}", door_layers[door_id], next_id))
        next_id += 1
    for flood_id in flood_layers:
        layers.append(layer(f"Flood {flood_id}", flood_layers[flood_id], next_id))
        next_id += 1
    layers.append({"id": next_id, "name": "Objects and People", "type": "objectgroup",
                   "draworder": "topdown", "opacity": 1, "visible": True,
                   "x": 0, "y": 0, "objects": objects})
    layers.append({"id": next_id + 1, "name": "Markers", "type": "objectgroup",
                   "draworder": "topdown", "opacity": 1, "visible": True,
                   "x": 0, "y": 0, "objects": markers})
    map_data = {"type": "map", "version": "1.10", "tiledversion": "1.12.2",
                "orientation": "orthogonal", "renderorder": "right-down", "width": WIDTH,
                "height": HEIGHT, "tilewidth": CELL, "tileheight": CELL,
                "infinite": False, "nextlayerid": next_id + 2, "nextobjectid": len(objects) + len(markers) + 1,
                "backgroundcolor": "#142842", "layers": layers,
                "tilesets": [{"firstgid": 1, "source": "skoljka_terrain.tsj"},
                             {"firstgid": 100, "source": "skoljka_objects.tsj"}]}
    object_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                      "name": "skoljka_objects", "tilewidth": 144, "tileheight": 72,
                      "tilecount": len(NAMES), "columns": 0, "objectalignment": "bottomleft",
                      "tiles": [{"id": i, "image": OBJECT_IMAGES[name],
                                 "imagewidth": SIZE[name][0], "imageheight": SIZE[name][1]}
                                for i, name in enumerate(NAMES)]}
    terrain_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                       "name": "skoljka_terrain", "tilewidth": 16, "tileheight": 16,
                       "tilecount": 48, "columns": 8,
                       "image": f"{ART}/skoljka_terrain.png", "imagewidth": 128, "imageheight": 96}
    for filename, data in (("skoljka.tmj", map_data), ("skoljka_objects.tsj", object_tileset),
                           ("skoljka_terrain.tsj", terrain_tileset)):
        (MAPS / filename).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Generated {WIDTH}x{HEIGHT} Skoljka: {len(city.rooms)} rooms, {len(objects)} objects, {len(markers)} markers")
    check_reachability(ground, water, walls, rock, door_layers, flood_layers, objects, markers)


def object_blocked_cells(objects: list[dict]) -> set:
    """Cells whose centre lies inside an object's collision footprint, using the
    tile loader's default footprint: 72% of the sprite's width along its bottom."""
    cells = set()
    for obj in objects:
        if obj["name"] in WALK_THROUGH or obj["name"].startswith("story_") or obj["name"].endswith("_sign"):
            continue
        w, h = obj["width"], obj["height"]
        top = obj["y"] - h
        cx, cy = obj["x"] + w * .5, top + h - max(6.0, h * .10)
        fw, fh = w * .72, max(7.0, h * .16)
        for y in range(int((cy - fh / 2) // CELL), int((cy + fh / 2) // CELL) + 1):
            for x in range(int((cx - fw / 2) // CELL), int((cx + fw / 2) // CELL) + 1):
                if cx - fw / 2 <= x * CELL + 8 <= cx + fw / 2 and cy - fh / 2 <= y * CELL + 8 <= cy + fh / 2:
                    cells.add((x, y))
    return cells


def check_reachability(ground, water, walls, rock, door_layers, flood_layers, objects, markers) -> None:
    """Report broad connectivity and verify the housing repair at E distance."""
    blocked_by_objects = object_blocked_cells(objects)

    def blocked(x, y, closed):
        i = y * WIDTH + x
        if walls[i] or water[i] or rock[i] or not ground[i] or (x, y) in blocked_by_objects:
            return True
        return any(data[i] for name, data in door_layers.items() if name in closed) or any(
            data[i] for name, data in flood_layers.items() if name in closed)

    def reach(start, closed):
        seen = {start}
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in seen and 0 <= nx < WIDTH and 0 <= ny < HEIGHT and not blocked(nx, ny, closed):
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        return seen

    marker_by_name = {m["name"]: m for m in markers}

    def reachable_stands(name, seen):
        marker = marker_by_name[name]
        cx, cy = marker["x"] // CELL, marker["y"] // CELL
        return {(cx + dx, cy + dy) for dx in range(-2, 3) for dy in range(-2, 3)
                if (dx * dx + dy * dy) * CELL * CELL <= 31 * 31
                and (cx + dx, cy + dy) in seen}

    # The lift moves the player between the dock and the city.
    surface = [m for m in markers if m["y"] // CELL < SURFACE_ROWS]
    city_markers = [m for m in markers if m["y"] // CELL >= SURFACE_ROWS]
    for start, label, group in (((70, 13), "dock, from the pad", surface), ((60, 27), "city, from the lift foot", city_markers)):
        for doors_open in (True, False):
            seen = reach(start, set() if doors_open else set(door_layers))
            missing = [m["name"] for m in group if (m["x"] // CELL, m["y"] // CELL) not in seen]
            print(f"{label}, doors {'open' if doors_open else 'closed'}: {len(seen)} cells, {len(group) - len(missing)}/{len(group)} markers; unreachable: {missing}")

    safe = marker_by_name["housing_safe"]
    safe_cell = safe["x"] // CELL, safe["y"] // CELL
    lever_stands = reachable_stands("housing_lever", reach(safe_cell, {"housing_leak", "pumps"}))
    if not lever_stands:
        raise ValueError("The housing lever cannot be operated from the dry route")
    sealed = reach(next(iter(lever_stands)), {"housing_inner", "housing_leak", "pumps"})
    if not reachable_stands("leak_point", sealed):
        raise ValueError("Closing the housing door prevents the player from reaching the damaged seal")
    print("housing lever and seal: reachable in order with the inner door closed and flood blocked")

    on_props = [m["name"] for m in markers if (m["x"] // CELL, m["y"] // CELL) in blocked_by_objects]
    if on_props:
        print("markers inside a prop's footprint:", on_props)


if __name__ == "__main__":
    main()
