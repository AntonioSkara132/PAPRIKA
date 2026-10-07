#!/usr/bin/env python3
"""Build the Chvarak Tiled map and its tilesets.

Chvarak is a farming planet in the mountains. Snowy peaks close the map to the
north and south. The spaceport stands on a stone shelf under the northern
peaks, and a ramp in the shelf's cliff leads down to the valley: terraced
fields in the west, fenced pastures with cows and pigs in the east, barns and
stone farmhouses along the cart road.

The diplomatic ship's interior is a walled room in open space below the
southern mountains, on the same map. The world script moves the player into it
when they board the ship, so the flight needs no separate scene.

Run tools/create_chvarak_art.py first; it draws the sprites used here.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "maps"
ART = "../assets/art/chvarak"
WIDTH, HEIGHT, CELL = 64, 80, 16
RNG = random.Random(4417)

# Terrain atlas order from create_chvarak_art.TERRAIN; the map uses firstgid 1.
T = {name: i + 1 for i, name in enumerate(
    ["grass", "grass_2", "meadow", "road", "road_2", "field_green", "field_gold", "pave",
     "pave_2", "rock", "rock_snow", "cliff", "ramp", "ship_floor", "ship_carpet", "ship_wall",
     "fence_h", "fence_v", "fence_post", "terrace", "pad", "void", "grass_rock", "road_edge"])}

OBJECT_IMAGES = {
    "chvarak_ship": "../assets/art/artichoke/objects/artichoke_ship.png",
    "player": "../art/concepts/source/player.png",
    "envoy_0": "../assets/art/pomidor/envoy_0.png",
    "envoy_1": "../assets/art/pomidor/envoy_1.png",
    "envoy_2": "../assets/art/pomidor/envoy_2.png",
}
for name in ["terminal", "guard_post", "landing_pad", "diplomatic_ship", "haystack", "trough", "cart",
             "chvarak_guard", "ship_bench", "ship_table", "ship_window", "ship_hatch"]:
    OBJECT_IMAGES[name] = f"{ART}/{name}.png"
for i in range(3):
    for name in ("peak", "boulder", "pine", "farmhouse"):
        OBJECT_IMAGES[f"{name}_{i}"] = f"{ART}/{name}_{i}.png"
for i in range(2):
    for name in ("barn", "cow", "pig", "ship_guard"):
        OBJECT_IMAGES[f"{name}_{i}"] = f"{ART}/{name}_{i}.png"
for i in range(4):
    OBJECT_IMAGES[f"farmer_{i}"] = f"{ART}/farmer_{i}.png"

NAMES = list(OBJECT_IMAGES)
GID = {name: 100 + i for i, name in enumerate(NAMES)}
SIZE = {}
for name, rel in OBJECT_IMAGES.items():
    with Image.open((MAPS / rel).resolve()) as im:
        SIZE[name] = im.size

NORTH_ROCK = 8          # rows 0..7 are mountain
SHELF = (8, 18)         # the spaceport shelf, rows 8..17
CLIFF_ROW = 18
RAMP = (30, 34)         # columns of the ramp and the cart road
VALLEY = (19, 44)       # rows 19..43
CROSS_ROAD = 29         # the east-west road, two rows
SOUTH_ROCK = (44, 56)
# Fenced pastures, fences included: x0, y0, x1, y1 in cells. The world script
# keeps the animals inside them (ChvarakWorld.PENS).
PENS = [(37, 20, 52, 28), (53, 20, 62, 28), (39, 32, 56, 42)]
# The ship room, walls included; the rest of the space below the mountains is void.
SHIP = (20, 60, 44, 74)


def blank(fill: int = 0) -> list[int]:
    return [fill] * (WIDTH * HEIGHT)


def paint(data: list[int], x: int, y: int, gid: int) -> None:
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        data[y * WIDTH + x] = gid


def rect(data: list[int], x0: int, y0: int, x1: int, y1: int, gid: int) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            paint(data, x, y, gid)


def layer(name: str, data: list[int], index: int) -> dict:
    return {"id": index, "name": name, "type": "tilelayer", "x": 0, "y": 0,
            "width": WIDTH, "height": HEIGHT, "opacity": 1, "visible": True, "data": data}


def main() -> None:
    ground = [T["grass"] if RNG.random() < .78 else (T["grass_2"] if RNG.random() < .7 else T["meadow"])
              for _ in range(WIDTH * HEIGHT)]
    paths = blank()
    rock = blank()
    fences = blank()
    walls = blank()
    objects: list[dict] = []

    def add(name: str, sprite: str, x: float, bottom: float) -> None:
        w, h = SIZE[sprite]
        objects.append({"id": len(objects) + 1, "name": name, "type": "chvarak_object",
                        "gid": GID[sprite], "x": round(x), "y": round(bottom),
                        "width": w, "height": h, "rotation": 0, "visible": True})

    # ---- mountains to the north and south ----
    for y in range(NORTH_ROCK):
        for x in range(WIDTH):
            paint(rock, x, y, T["rock"])
    for y in range(*SOUTH_ROCK):
        for x in range(WIDTH):
            paint(rock, x, y, T["rock_snow"] if y > SOUTH_ROCK[1] - 4 and RNG.random() < .5 else T["rock"])
    for x in range(0, WIDTH, 1):
        if RNG.random() < .25:
            paint(ground, x, NORTH_ROCK, T["grass_rock"])

    # ---- the spaceport shelf ----
    rect(paths, 3, 10, 61, SHELF[1], T["pave"])
    for i in range(len(paths)):
        if paths[i] == T["pave"] and RNG.random() < .3:
            paths[i] = T["pave_2"]
    # The cliff at the shelf's edge, with the ramp down to the valley.
    for x in range(WIDTH):
        paint(rock, x, CLIFF_ROW, 0 if RAMP[0] <= x < RAMP[1] else T["cliff"])
    rect(paths, RAMP[0], CLIFF_ROW, RAMP[1], CLIFF_ROW + 1, T["ramp"])

    # Transport pad in the west, the terminal in the middle, the diplomatic ship in the east.
    tw, th = SIZE["chvarak_ship"]
    add("landing_pad", "landing_pad", 96, 15 * CELL - 4)
    add("chvarak_ship", "chvarak_ship", 48, 15 * CELL)
    add("player", "player", 136, 16 * CELL + 10)
    w, _ = SIZE["terminal"]
    add("chvarak_terminal", "terminal", 32 * CELL - w // 2, 14 * CELL)
    add("landing_pad", "landing_pad", 728, 15 * CELL - 4)
    add("diplomatic_ship", "diplomatic_ship", 44 * CELL, 15 * CELL)
    add("guard_post", "guard_post", 548, 17 * CELL + 12)
    add("story_guard", "chvarak_guard", 588, 17 * CELL + 12)
    # The three envoys come with the player from Pomidor and wait by the ship's ramp.
    for i in range(3):
        add(f"story_envoy_{i}", f"envoy_{i}", 44 * CELL + 64 + i * 18, 16 * CELL + 14)
    for x in (24, 330, 640, 900, 980):
        add("boulder", f"boulder_{RNG.randrange(3)}", x, 9 * CELL + 10)

    # Peaks along both ranges. Their feet stand on the rock, so they block nothing new.
    # A back row behind the front row fills the sky between the front peaks.
    x = -60
    while x < WIDTH * CELL:
        sprite = RNG.choice(["peak_0", "peak_2"])
        add("mountain_peak", sprite, x, 5 * CELL - RNG.randrange(0, 12))
        x += SIZE[sprite][0] - RNG.randrange(30, 50)
    x = -40
    while x < WIDTH * CELL:
        sprite = RNG.choice(["peak_0", "peak_1", "peak_2"])
        add("mountain_peak", sprite, x, NORTH_ROCK * CELL - RNG.randrange(2, 14))
        x += SIZE[sprite][0] - RNG.randrange(24, 44)
    for row_bottom in (SOUTH_ROCK[0] + 5, SOUTH_ROCK[0] + 9, SOUTH_ROCK[1]):
        x = -30 - RNG.randrange(40)
        while x < WIDTH * CELL:
            sprite = RNG.choice(["peak_0", "peak_1", "peak_2"])
            add("mountain_peak", sprite, x, row_bottom * CELL - RNG.randrange(0, 10))
            x += SIZE[sprite][0] - RNG.randrange(20, 40)

    # ---- the valley ----
    rect(paths, RAMP[0], VALLEY[0], RAMP[1], VALLEY[1], T["road"])
    rect(paths, 2, CROSS_ROAD, 62, CROSS_ROAD + 2, T["road"])
    for i in range(len(paths)):
        if paths[i] == T["road"] and RNG.random() < .3:
            paths[i] = T["road_2"]

    # Terraced fields in the west: crop rows with a low stone wall under each terrace.
    def terraces(x0: int, x1: int, y0: int, bands: list[str]) -> None:
        y = y0
        for crop in bands:
            rect(paths, x0, y, x1, y + 3, T[crop])
            rect(paths, x0, y + 3, x1, y + 4, T["terrace"])
            y += 4

    terraces(3, 22, 20, ["field_gold", "field_green"])
    terraces(3, 22, 32, ["field_green", "field_gold"])
    add("farmhouse", "farmhouse_0", 23 * CELL + 4, 25 * CELL)
    add("haystack", "haystack", 26 * CELL + 6, 27 * CELL + 10)
    add("haystack", "haystack", 23 * CELL, 28 * CELL + 6)
    add("cart", "cart", 22 * CELL + 6, 32 * CELL + 12)
    add("farm_barn", "barn_0", 22 * CELL + 6, 41 * CELL)
    add("haystack", "haystack", 3 * CELL, 42 * CELL + 6)
    add("haystack", "haystack", 5 * CELL + 4, 42 * CELL + 10)
    add("farmhouse", "farmhouse_2", 10 * CELL, 44 * CELL - 2)

    # Pastures in the east, fenced all round.
    for x0, y0, x1, y1 in PENS:
        for x in range(x0, x1):
            paint(fences, x, y0, T["fence_h"])
            paint(fences, x, y1 - 1, T["fence_h"])
        for y in range(y0, y1):
            paint(fences, x0, y, T["fence_v"])
            paint(fences, x1 - 1, y, T["fence_v"])
        for cx, cy in ((x0, y0), (x1 - 1, y0), (x0, y1 - 1), (x1 - 1, y1 - 1)):
            paint(fences, cx, cy, T["fence_post"])
    add("trough", "trough", 44 * CELL, 26 * CELL)
    add("trough", "trough", 56 * CELL, 26 * CELL)
    add("trough", "trough", 47 * CELL, 40 * CELL)
    cows = [(40, 22), (44, 23), (48, 22), (42, 25), (49, 25), (42, 35), (47, 34), (51, 37), (45, 38)]
    for i, (cx, cy) in enumerate(cows):
        add(f"animal_cow_{i}", f"cow_{i % 2}", cx * CELL, cy * CELL + 12)
    for i, (px, py) in enumerate([(55, 22), (58, 23), (56, 25), (59, 26)]):
        add(f"animal_pig_{i}", f"pig_{i % 2}", px * CELL, py * CELL + 10)
    add("farm_barn", "barn_1", 56 * CELL + 8, 41 * CELL)
    add("farmhouse", "farmhouse_1", 34 * CELL + 4, 28 * CELL)
    add("haystack", "haystack", 57 * CELL, 31 * CELL + 14)
    add("cart", "cart", 35 * CELL, 42 * CELL + 6)

    # Pines along the valley's edges and under the shelf's cliff.
    for x, bottom in [(0, 22), (0, 27), (1, 35), (0, 40), (62, 30), (61, 34), (62, 39), (61, 43),
                      (26, 20), (36, 20), (14, 30), (18, 43), (52, 31)]:
        add("tree_pine", f"pine_{RNG.randrange(3)}", x * CELL - 4, bottom * CELL + 12)

    # Farmers and herders.
    spots = [(8, 21), (15, 25), (6, 33), (17, 37), (27, 31), (33, 24), (36, 31), (24, 38),
             (45, 30), (55, 30), (12, 30), (29, 41)]
    for i, (sx, sy) in enumerate(spots, 1):
        add(f"villager_chvarak_{i:02d}", f"farmer_{i % 4}", sx * CELL, sy * CELL + 12)

    # ---- the ship room in open space ----
    rect(walls, 0, SOUTH_ROCK[1], WIDTH, HEIGHT, T["void"])
    sx0, sy0, sx1, sy1 = SHIP
    rect(walls, sx0, sy0, sx1, sy1, T["ship_wall"])
    rect(walls, sx0 + 1, sy0 + 4, sx1 - 1, sy1 - 1, 0)
    rect(paths, sx0 + 1, sy0 + 4, sx1 - 1, sy1 - 1, T["ship_floor"])
    rect(paths, sx0 + 1, sy0 + 6, sx0 + 10, sy1 - 3, T["ship_carpet"])
    for wx in range(sx0 + 2, sx1 - 3, 4):
        add("ship_window", "ship_window", wx * CELL + 4, (sy0 + 3) * CELL + 10)
    add("ship_hatch", "ship_hatch", (sx1 - 3) * CELL, (sy0 + 4) * CELL)
    add("ship_bench", "ship_bench", (sx0 + 2) * CELL, (sy0 + 7) * CELL)
    add("ship_bench", "ship_bench", (sx0 + 2) * CELL, (sy0 + 10) * CELL)
    add("ship_table", "ship_table", (sx0 + 6) * CELL, (sy0 + 9) * CELL)

    layers = [layer("Ground", ground, 1), layer("Roads and Fields", paths, 2),
              layer("Mountain Rock", rock, 3), layer("Fences", fences, 4), layer("Ship Walls", walls, 5),
              {"id": 6, "name": "Buildings and People", "type": "objectgroup",
               "draworder": "topdown", "opacity": 1, "visible": True,
               "x": 0, "y": 0, "objects": objects}]
    map_data = {"type": "map", "version": "1.10", "tiledversion": "1.12.2",
                "orientation": "orthogonal", "renderorder": "right-down", "width": WIDTH,
                "height": HEIGHT, "tilewidth": CELL, "tileheight": CELL,
                "infinite": False, "nextlayerid": 7, "nextobjectid": len(objects) + 1,
                "backgroundcolor": "#0e1028", "layers": layers,
                "tilesets": [{"firstgid": 1, "source": "chvarak_terrain.tsj"},
                             {"firstgid": 100, "source": "chvarak_objects.tsj"}]}
    object_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                      "name": "chvarak_objects", "tilewidth": 192, "tileheight": 112,
                      "tilecount": len(NAMES), "columns": 0, "objectalignment": "bottomleft",
                      "tiles": [{"id": i, "image": OBJECT_IMAGES[name],
                                 "imagewidth": SIZE[name][0], "imageheight": SIZE[name][1]}
                                for i, name in enumerate(NAMES)]}
    terrain_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                       "name": "chvarak_terrain", "tilewidth": 16, "tileheight": 16,
                       "tilecount": 24, "columns": 8,
                       "image": f"{ART}/chvarak_terrain.png", "imagewidth": 128, "imageheight": 48}
    for filename, data in (("chvarak.tmj", map_data), ("chvarak_objects.tsj", object_tileset),
                           ("chvarak_terrain.tsj", terrain_tileset)):
        (MAPS / filename).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Generated {WIDTH}x{HEIGHT} Chvarak: {len(objects)} objects")


if __name__ == "__main__":
    main()
