#!/usr/bin/env python3
"""Build the Pomidor Tiled map and its tilesets.

Pomidor is a dense old town. Houses stand wall to wall in rows, each row facing
the street below it, and the streets form a grid of two-tile lanes with wider
avenues through the middle. The square in the center holds the Council Hall,
the fountain and the shops. The rich quarter in the northeast has lawns and the
houses that ignore physics. The landing ground is south of the square.

The Council chamber is a walled room in the southwest corner of the same map,
outside the town. The world script moves the player into it through the Council
Hall door and out again through its exit, so it needs no separate scene.

Run tools/create_pomidor_art.py first; it draws the sprites used here.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "maps"
ART = "../assets/art/pomidor"
WIDTH, HEIGHT, CELL = 100, 76, 16
RNG = random.Random(9783)

# Terrain atlas order from create_pomidor_art.TERRAIN; the map uses firstgid 1.
T = {name: i + 1 for i, name in enumerate(
    ["grass", "grass_2", "street", "street_2", "plaza", "marble", "marble_2",
     "chamber_wall", "carpet", "lawn", "street_edge", "wall_top"])}

OBJECT_IMAGES = {
    "council_hall": f"{ART}/council_hall.png",
    "pomidor_library": f"{ART}/pomidor_library.png",
    "pomidor_clothing": f"{ART}/pomidor_clothing.png",
    "beer_hall": f"{ART}/beer_hall.png",
    "pomidor_market": "../assets/art/river_planet/river_market.png",
    "pomidor_forge": "../assets/art/river_planet/river_forge.png",
    "fountain": "../assets/art/river_planet/town_center_fountain.png",
    "pomidor_ship": "../assets/art/artichoke/objects/artichoke_ship.png",
    "player": "../art/concepts/source/player.png",
    "spiral_house": f"{ART}/spiral_house.png",
    "tomato_house": f"{ART}/tomato_house.png",
    "pear_house": f"{ART}/pear_house.png",
    "pepper_house": f"{ART}/pepper_house.png",
    "tree_fruit": f"{ART}/fruit_tree.png",
    "council_guard": f"{ART}/council_guard.png",
    "council_table": f"{ART}/council_table.png",
    "chamber_exit": f"{ART}/chamber_exit.png",
}
for i in range(6):
    OBJECT_IMAGES[f"townhouse_{i}"] = f"{ART}/townhouse_{i}.png"
    OBJECT_IMAGES[f"townsfolk_{i}"] = f"{ART}/townsfolk_{i}.png"
for i in range(3):
    OBJECT_IMAGES[f"row_house_{i}"] = f"{ART}/row_house_{i}.png"
    OBJECT_IMAGES[f"market_stall_{i}"] = f"{ART}/market_stall_{i}.png"
PLANETS = ["paprika", "pomidor", "brudet", "artichoke", "cichvarda", "chvarak"]
OFFICES = ["army", "gold", "law", "economy", "diplomacy", "navy"]
for planet in PLANETS:
    OBJECT_IMAGES[f"banner_{planet}"] = f"{ART}/banner_{planet}.png"
    for i in range(2):
        OBJECT_IMAGES[f"councillor_{planet}_{i}"] = f"{ART}/councillor_{planet}_{i}.png"
for office in OFFICES:
    OBJECT_IMAGES[f"secretary_{office}"] = f"{ART}/secretary_{office}.png"
    OBJECT_IMAGES[f"desk_{office}"] = f"{ART}/desk_{office}.png"

NAMES = list(OBJECT_IMAGES)
GID = {name: 100 + i for i, name in enumerate(NAMES)}
SIZE = {}
for name, rel in OBJECT_IMAGES.items():
    with Image.open((MAPS / rel).resolve()) as im:
        SIZE[name] = im.size

# Town limits in cells. North of the avenue the town reaches the west edge;
# south of it the Council chamber takes the west side.
TOWN_X0, TOWN_X1 = 2, 98
SOUTH_X0 = 26
SQUARE = (44, 22, 74, 42)          # plaza cells x0, y0, x1, y1
RICH = (78, 2, 98, 22)
LANDING = (52, 58, 70, 74)
CHAMBER = (2, 46, 24, 72)          # walls included


def blank(fill: int = 0) -> list[int]:
    return [fill] * (WIDTH * HEIGHT)


def paint(data: list[int], x: int, y: int, gid: int) -> None:
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        data[y * WIDTH + x] = gid


def rect(data: list[int], x0: int, y0: int, x1: int, y1: int, gid: int) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            paint(data, x, y, gid)


def inside(x: int, y: int, box: tuple[int, int, int, int]) -> bool:
    return box[0] <= x < box[2] and box[1] <= y < box[3]


def layer(name: str, data: list[int], index: int) -> dict:
    return {"id": index, "name": name, "type": "tilelayer", "x": 0, "y": 0,
            "width": WIDTH, "height": HEIGHT, "opacity": 1, "visible": True, "data": data}


def main() -> None:
    ground = [T["grass"] if RNG.random() < .8 else T["grass_2"] for _ in range(WIDTH * HEIGHT)]
    streets = blank()
    walls = blank()
    objects: list[dict] = []

    def add(name: str, sprite: str, x: float, bottom: float) -> None:
        w, h = SIZE[sprite]
        objects.append({"id": len(objects) + 1, "name": name, "type": "pomidor_object",
                        "gid": GID[sprite], "x": round(x), "y": round(bottom),
                        "width": w, "height": h, "rotation": 0, "visible": True})

    # Streets: rows of houses face the lane below them. Lanes run every seven
    # cells; cross lanes every fourteen. Avenues are three cells wide.
    lane_rows = [8, 15, 22, 29, 36, 42, 50, 57, 64, 71]
    cross_cols = [2, 14, 26, 40, 54, 68, 82, 96]

    def west_edge(y: int) -> int:
        return TOWN_X0 if y < 45 else SOUTH_X0

    for y in lane_rows:
        rect(streets, west_edge(y), y, TOWN_X1, y + 2, T["street"])
    for x in cross_cols:
        rect(streets, x, 2, x + 2, 45 if x < SOUTH_X0 else 73, T["street"])
    rect(streets, 58, 2, 61, 74, T["street_2"])           # north-south avenue
    rect(streets, TOWN_X0, 42, TOWN_X1, 45, T["street_2"])  # east-west avenue
    reserved: list[tuple[int, int, int, int]] = [SQUARE, RICH, LANDING, CHAMBER]
    # The square, the rich quarter's lawn and the landing ground.
    rect(streets, *SQUARE, T["plaza"])
    rect(streets, RICH[0], RICH[1], RICH[2], RICH[3], T["lawn"])
    rect(streets, RICH[0], 8, RICH[2], 10, T["street"])
    rect(streets, RICH[0] + 9, RICH[1], RICH[0] + 11, RICH[3], T["street"])
    rect(streets, *LANDING, T["plaza"])
    for i in range(len(streets)):
        if streets[i] == T["street"] and RNG.random() < .3:
            streets[i] = T["street_2"]

    # ---- houses wall to wall along every lane ----
    def blocked(x0: float, x1: float, row_bottom: int) -> bool:
        top = row_bottom - 4
        for cx in range(int(x0 // CELL), int((x1 - 1) // CELL) + 1):
            for cy in range(top, row_bottom):
                if cx >= WIDTH or streets[cy * WIDTH + cx] or any(inside(cx, cy, box) for box in reserved):
                    return True
        return False

    # The beer hall faces the avenue south of the square, beside the landing ground.
    beer_x = (LANDING[0] - 7) * CELL
    add("beer_hall", "beer_hall", beer_x, 57 * CELL)
    reserved.append((LANDING[0] - 7, 52, LANDING[0] - 1, 57))

    # Fill each lane wall to wall. A gap too narrow for any house gets a fruit tree.
    house_kinds = [f"townhouse_{i}" for i in range(6)] + [f"row_house_{i}" for i in range(3)]
    houses = 0
    for row_bottom in lane_rows:
        x = west_edge(row_bottom) * CELL
        while x < TOWN_X1 * CELL:
            fits = [k for k in house_kinds if not blocked(x, x + SIZE[k][0], row_bottom)]
            if not fits:
                if not blocked(x, x + CELL, row_bottom) and blocked(x - CELL, x, row_bottom) is False and RNG.random() < .7:
                    add("tree_fruit", "tree_fruit", x - 6, row_bottom * CELL - 2)
                x += CELL
                continue
            sprite = RNG.choice(fits)
            add("pomidor_house", sprite, x, row_bottom * CELL)
            houses += 1
            x += SIZE[sprite][0]

    # ---- the square ----
    sq_x0, sq_y0, sq_x1, sq_y1 = (v * CELL for v in SQUARE)
    mid = (sq_x0 + sq_x1) // 2
    w, _ = SIZE["council_hall"]
    add("pomidor_council_hall", "council_hall", mid - w // 2, sq_y0 + 168)
    for gx in (mid - 40, mid + 26):
        add("council_guard", "council_guard", gx, sq_y0 + 184)
    w, _ = SIZE["fountain"]
    add("fountain", "fountain", mid - w // 2, sq_y0 + 264)
    add("pomidor_library", "pomidor_library", sq_x0 + 8, sq_y0 + 120)
    add("pomidor_clothing", "pomidor_clothing", sq_x1 - 88, sq_y0 + 112)
    add("pomidor_market", "pomidor_market", sq_x0 + 8, sq_y1 - 8)
    add("pomidor_forge", "pomidor_forge", sq_x1 - 88, sq_y1 - 8)
    for i, sx in enumerate((sq_x0 + 136, sq_x0 + 176, sq_x1 - 208, sq_x1 - 168)):
        add("market_stall", f"market_stall_{i % 3}", sx, sq_y1 - 40)
    for tx in (sq_x0 + 120, sq_x1 - 136):
        add("tree_fruit", "tree_fruit", tx, sq_y0 + 104)

    # ---- landing ground ----
    lx0, ly0, lx1, ly1 = (v * CELL for v in LANDING)
    w, h = SIZE["pomidor_ship"]
    add("pomidor_ship", "pomidor_ship", (lx0 + lx1) // 2 - w // 2, ly0 + 136)
    add("player", "player", (lx0 + lx1) // 2 - 8, ly0 + 176)

    # ---- the rich quarter ----
    rx0, ry0 = RICH[0] * CELL, RICH[1] * CELL
    for name, sx, sb in (("spiral_house", 8, 120), ("tomato_house", 176, 116),
                         ("pear_house", 24, 300), ("pepper_house", 200, 300),
                         ("tomato_house", 96, 300)):
        add("pomidor_rich_house", name, rx0 + sx, ry0 + sb)
    for sx, sb in ((96, 96), (264, 120), (152, 300), (290, 300), (8, 180)):
        add("tree_fruit", "tree_fruit", rx0 + sx, ry0 + sb)

    # ---- townsfolk on the streets and the square ----
    spots = [(mid - 120, sq_y0 + 200), (mid + 100, sq_y0 + 210), (mid - 60, sq_y0 + 290),
             (mid + 70, sq_y0 + 300), (mid - 150, sq_y0 + 250), (mid + 160, sq_y0 + 250)]
    for lane in (8, 15, 29, 50, 57, 64):
        for cx in ((8, 20, 34, 48, 63, 76, 90) if lane < 45 else (34, 48, 63, 76, 90)):
            spots.append((cx * CELL + 8, lane * CELL + 20))
    for i, (x, feet) in enumerate(spots, 1):
        add(f"villager_pomidor_{i:02d}", f"townsfolk_{i % 6}", x - 8, feet + 2)

    # ---- the Council chamber ----
    cx0, cy0, cx1, cy1 = CHAMBER
    rect(walls, 0, cy0 - 2, cx1 + 2, HEIGHT, T["wall_top"])
    rect(walls, cx0 + 1, cy0 + 1, cx1 - 1, cy1 - 1, 0)
    rect(streets, cx0 + 1, cy0 + 1, cx1 - 1, cy1 - 1, T["marble"])
    for y in range(cy0 + 1, cy1 - 1):
        for x in range(cx0 + 1, cx1 - 1):
            if (x + y) % 2:
                paint(streets, x, y, T["marble_2"])
    rect(walls, cx0 + 1, cy0 + 1, cx1 - 1, cy0 + 4, T["chamber_wall"])
    chamber_mid = (cx0 + cx1) // 2
    rect(streets, chamber_mid - 1, cy0 + 4, chamber_mid + 1, cy1 - 1, T["carpet"])
    px0, py0 = (cx0 + 1) * CELL, (cy0 + 1) * CELL
    pw = (cx1 - cx0 - 2) * CELL
    pmid = px0 + pw // 2
    for i, planet in enumerate(PLANETS):
        add("council_banner", f"banner_{planet}", px0 + 24 + i * (pw - 64) // 5, py0 + 48)
    # The Big Council sits behind its table: two members from each planet.
    tw, th = SIZE["council_table"]
    table_bottom = py0 + 128
    add("council_table", "council_table", pmid - tw // 2, table_bottom)
    seat_y = table_bottom - th + 10
    for i, planet in enumerate(PLANETS):
        for j in range(2):
            seat = i * 2 + j
            add(f"council_member_{planet}_{j}", f"councillor_{planet}_{j}", pmid - tw // 2 + 6 + seat * 16, seat_y)
    # The Small Council: six Secretaries at their desks in two rows.
    for i, office in enumerate(OFFICES):
        col, row = i % 3, i // 3
        dx = px0 + 24 + col * (pw - 80) // 2
        dy = py0 + 208 + row * 88
        add("council_desk", f"desk_{office}", dx, dy)
        add(f"council_secretary_{office}", f"secretary_{office}", dx + 8, dy - 18)
    add("chamber_exit", "chamber_exit", pmid - 16, (cy1 - 1) * CELL)

    layers = [layer("Ground", ground, 1), layer("Streets and Plaza", streets, 2),
              layer("Chamber Walls", walls, 3),
              {"id": 4, "name": "Buildings and People", "type": "objectgroup",
               "draworder": "topdown", "opacity": 1, "visible": True,
               "x": 0, "y": 0, "objects": objects}]
    map_data = {"type": "map", "version": "1.10", "tiledversion": "1.12.2",
                "orientation": "orthogonal", "renderorder": "right-down", "width": WIDTH,
                "height": HEIGHT, "tilewidth": CELL, "tileheight": CELL,
                "infinite": False, "nextlayerid": 5, "nextobjectid": len(objects) + 1,
                "backgroundcolor": "#3a2a2a", "layers": layers,
                "tilesets": [{"firstgid": 1, "source": "pomidor_terrain.tsj"},
                             {"firstgid": 100, "source": "pomidor_objects.tsj"}]}
    object_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                      "name": "pomidor_objects", "tilewidth": 208, "tileheight": 150,
                      "tilecount": len(NAMES), "columns": 0, "objectalignment": "bottomleft",
                      "tiles": [{"id": i, "image": OBJECT_IMAGES[name],
                                 "imagewidth": SIZE[name][0], "imageheight": SIZE[name][1]}
                                for i, name in enumerate(NAMES)]}
    terrain_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                       "name": "pomidor_terrain", "tilewidth": 16, "tileheight": 16,
                       "tilecount": 16, "columns": 8,
                       "image": f"{ART}/pomidor_terrain.png", "imagewidth": 128, "imageheight": 32}
    for filename, data in (("pomidor.tmj", map_data), ("pomidor_objects.tsj", object_tileset),
                           ("pomidor_terrain.tsj", terrain_tileset)):
        (MAPS / filename).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Generated {WIDTH}x{HEIGHT} Pomidor: {len(objects)} objects, {houses} houses")


if __name__ == "__main__":
    main()
