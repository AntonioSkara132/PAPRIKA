#!/usr/bin/env python3
"""Build the independent Brudet River Planet Tiled map and its object tileset."""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "maps"
WIDTH, HEIGHT, CELL = 112, 80, 16
RNG = random.Random(20261002)

# IDs are local to brudet_objects.tsj; the map uses firstgid 400.
OBJECTS = [
    ("river_town_hall", 112, 96), ("river_market", 96, 72),
    ("river_townhouse", 64, 88), ("river_library", 96, 88),
    ("town_center_fountain", 64, 48), ("military_hq", 96, 96),
    ("arrow_target", 32, 32), ("stone_bridge", 96, 48),
    ("lake_patch", 96, 64), ("fishing_pond", 64, 48),
    ("fishing_boat", 48, 24), ("reed_cluster", 24, 16),
    ("terraced_field", 80, 48), ("olive_tree", 32, 48),
    ("crop_bundle", 16, 16), ("river_villager_sunhat", 16, 24),
    ("river_villager_shawl", 16, 24), ("river_fisherman", 16, 24),
    ("finling", 16, 24), ("lake_maw", 32, 24),
    ("river_serpent", 48, 24),
]
GID = {name: 400 + i for i, (name, _, _) in enumerate(OBJECTS)}

def blank() -> list[int]:
    return [0] * (WIDTH * HEIGHT)

def paint(data: list[int], x: int, y: int, gid: int) -> None:
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        data[y * WIDTH + x] = gid

def rect(data: list[int], x0: int, y0: int, x1: int, y1: int, gid: int) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            paint(data, x, y, gid)

def path(data: list[int], points: list[tuple[int, int]], radius: int = 1, gid: int = 3) -> None:
    for (xa, ya), (xb, yb) in zip(points, points[1:]):
        length = max(abs(xb - xa), abs(yb - ya))
        for step in range(length + 1):
            x = round(xa + (xb - xa) * step / max(1, length))
            y = round(ya + (yb - ya) * step / max(1, length))
            rect(data, x - radius, y - radius, x + radius + 1, y + radius + 1, gid)

def layer(name: str, data: list[int], index: int) -> dict:
    return {"id": index, "name": name, "type": "tilelayer", "x": 0, "y": 0,
            "width": WIDTH, "height": HEIGHT, "opacity": 1, "visible": True, "data": data}

def main() -> None:
    ground = [1] * (WIDTH * HEIGHT)
    paths, common, private, details, water = (blank() for _ in range(5))
    # Paprika's grass and path tiles keep crops usable; the local river tiles
    # provide water and bank detail independently.
    for y in range(2, HEIGHT - 2):
        for x in range(2, WIDTH - 2):
            if RNG.random() < .045:
                paint(ground, x, y, 2)

    # The main channel is six cells wide, centered on x=800 px. Wider reaches
    # give it a natural outline without narrowing either bridge crossing.
    river = set()
    for y in range(HEIGHT):
        west = 47 + (1 if y in (7, 8, 9, 57, 58, 59) else 0)
        east = 53 + (1 if y in (13, 14, 15, 62, 63, 64) else 0)
        for x in range(west, east):
            river.add((x, y))
    # A broad, irregular lake west of Brudet, opening into the channel through
    # a short tributary. Do not put field plots or buildings in the water.
    lake = set()
    for y in range(36, 56):
        for x in range(8, 36):
            dx = (x - 21.5) / 13.5
            dy = (y - 45.5) / 10.5
            ripple = .07 * math.sin(y * 1.3) + .055 * math.sin(x * 1.7)
            if dx * dx + dy * dy < 1 + ripple:
                lake.add((x, y))
    river |= lake
    for x in range(33, 48):
        center = 42 + round(1.4 * math.sin((x - 33) * .52))
        for y in range(center - 1, center + 2):
            river.add((x, y))

    # Streets meet the bridges at y=440 and y=792 and stay open on each bank.
    path(paths, [(3, 27), (46, 27), (54, 27), (107, 27)], 1)
    path(paths, [(3, 49), (7, 49)], 1)
    path(paths, [(37, 49), (46, 49), (54, 49), (106, 49)], 1)
    path(paths, [(39, 4), (39, 37)], 1)
    path(paths, [(39, 48), (39, 75)], 1)
    path(paths, [(12, 27), (12, 34)], 1)
    path(paths, [(69, 8), (69, 71)], 1)
    path(paths, [(86, 8), (86, 73)], 1)
    path(paths, [(56, 39), (107, 39)], 1)
    path(paths, [(57, 61), (105, 61)], 1)
    path(paths, [(56, 15), (103, 15)], 1)
    path(paths, [(101, 27), (101, 70)], 1)
    path(paths, [(91, 44), (91, 58)], 1)
    path(paths, [(22, 14), (39, 14)], 1)
    path(paths, [(25, 61), (39, 61)], 1)
    # The town hall, market, library, travel agency, and HQ face paved courts.
    rect(paths, 71, 31, 85, 39, 4)
    rect(paths, 87, 31, 104, 39, 4)
    rect(paths, 68, 40, 90, 45, 4)
    rect(paths, 87, 42, 105, 47, 4)
    rect(paths, 82, 54, 101, 60, 4)
    path(paths, [(77, 39), (77, 43), (90, 43), (90, 44)], 1, 4)
    path(paths, [(95, 39), (95, 44)], 1, 4)
    # Smaller west-bank fishing neighborhood and trails around the lake.
    path(paths, [(7, 32), (12, 32), (30, 32), (38, 32)], 1)
    path(paths, [(5, 57), (29, 57), (38, 56)], 1)
    path(paths, [(8, 35), (5, 43), (6, 53), (8, 57)], 0)

    # Open civic fields: local tile 8-11 gives global 9-12 in terrain.tsj.
    for x0, y0, x1, y1 in [(7, 6, 19, 19), (24, 7, 35, 20),
                            (9, 62, 23, 74), (27, 64, 37, 75),
                            (58, 65, 67, 75), (72, 65, 82, 75)]:
        for y in range(y0, y1):
            for x in range(x0, x1):
                if x in (x0, x1-1) or y in (y0, y1-1):
                    paint(common, x, y, 5)
                elif (x + y) % 9 == 0:
                    paint(common, x, y, 10)
                elif (x * 3 + y) % 7 == 0:
                    paint(common, x, y, 11)
                else:
                    paint(common, x, y, 9 if (x + y) % 3 else 12)
    for x0, y0, x1, y1 in [(58, 8, 64, 13), (76, 8, 82, 13),
                            (92, 10, 98, 14), (88, 67, 94, 72)]:
        for y in range(y0, y1):
            for x in range(x0, x1):
                paint(private, x, y, (9, 10, 11, 12)[(x * 5 + y) % 4])

    # Deck areas are LAND cells, so every water cell can be collision-solid.
    bridge_rows = ((26, 29), (48, 51))
    for y0, y1 in bridge_rows:
        for y in range(y0, y1):
            for x in range(47, 53):
                river.discard((x, y))
    for x, y in river:
        # Canonical river atlas: base water at 0 and ripple variants at 22/23.
        # IDs 5/6 are bridge rails, not water.
        variation = (x * 37 + y * 53) % 41
        water_tile = 0 if variation < 29 else 22 if variation < 35 else 23
        paint(water, x, y, 300 + water_tile)
        paint(paths, x, y, 0)
        paint(common, x, y, 0)
        paint(private, x, y, 0)
    # Water-edge banks use the correct land-facing atlas tile. None of these
    # local IDs are crop tiles (8–11) or bridge rail collision tiles (5/6).
    for y in range(1, HEIGHT - 1):
        for x in range(1, WIDTH - 1):
            if (x, y) in river or paths[y * WIDTH + x] or common[y * WIDTH + x]:
                continue
            north = (x, y - 1) in river
            south = (x, y + 1) in river
            west = (x - 1, y) in river
            east = (x + 1, y) in river
            if not (north or south or west or east):
                continue
            if south and east:
                bank_tile = 14  # land on north and west
            elif south and west:
                bank_tile = 15
            elif north and east:
                bank_tile = 16
            elif north and west:
                bank_tile = 17
            elif north:
                bank_tile = 4
            elif south:
                bank_tile = 3
            elif west:
                bank_tile = 13
            else:
                bank_tile = 12
            paint(details, x, y, 300 + bank_tile)
    # The east-bank city has its own warm stone streets and public plazas.
    for y in range(HEIGHT):
        for x in range(54, WIDTH):
            position = y * WIDTH + x
            if paths[position] == 3:
                paths[position] = (302, 325, 326)[(x + 2 * y) % 3]
            elif paths[position] == 4:
                paths[position] = 330
    for y0, y1 in bridge_rows:
        for y in range(y0, y1):
            for x in range(47, 53):
                tile_id = 5 if y == y0 else 6 if y == y1 - 1 else (7, 27)[x % 2]
                paint(paths, x, y, 300 + tile_id)
        paint(paths, 46, y0 + 1, 328)
        paint(paths, 53, y0 + 1, 329)

    objects: list[dict] = []
    def add(name: str, sprite: str, x: int, top: int, *, width: int | None = None,
            height: int | None = None) -> None:
        w, h = dict((n, (w, h)) for n, w, h in OBJECTS).get(sprite, (112, 72))
        w, h = width or w, height or h
        gid = GID.get(sprite, 107 if sprite == "travel" else 110 if sprite == "player" else 0)
        objects.append({"id": len(objects) + 1, "name": name,
                        "type": "river_object", "gid": gid, "x": x, "y": top + h,
                        "width": w, "height": h, "rotation": 0, "visible": True})

    add("stone_bridge", "stone_bridge", 752, 416)
    add("stone_bridge", "stone_bridge", 752, 768)
    # Main town square: services sit north of their clear entrances.
    add("river_town_hall", "river_town_hall", 1136, 480)
    add("river_market", "river_market", 1416, 504)
    add("river_library", "river_library", 1592, 488)
    add("fountain", "town_center_fountain", 1216, 624)
    add("travel", "travel", 1464, 632, width=112, height=72)
    add("military_hq", "military_hq", 1480, 864)
    add("arrow_target", "arrow_target", 1624, 918)
    add("fishing_pond", "fishing_pond", 912, 592)
    add("fishing_pond", "fishing_pond", 1664, 880)
    add("fishing_pond", "fishing_pond", 400, 352)
    add("fishing_pond", "fishing_pond", 176, 928)
    # Houses form three blocks and overlook the plaza and both main streets.
    for x in (912, 1008, 1104, 1248, 1344, 1440, 1536, 1632):
        add("river_townhouse", "river_townhouse", x, 96)
    for x in (912, 1008, 1104, 1200, 1296, 1392, 1488, 1584, 1680):
        add("river_townhouse", "river_townhouse", x, 256)
    for x in (912, 1008, 1104, 1200, 1296, 1392, 1584, 1680):
        add("river_townhouse", "river_townhouse", x, 1032)
    for x, y in ((160, 120), (384, 112), (224, 304), (352, 336),
                 (112, 848), (384, 896)):
        add("river_townhouse", "river_townhouse", x, y)
    # Distinct villagers get their own persistent IDs through their object IDs.
    social = [(x, y) for x, y in (
        (1072, 408), (1136, 420), (1264, 420), (1360, 416),
        (1088, 608), (1152, 672), (1344, 672), (1392, 704),
        (1592, 704), (1680, 688), (1024, 784), (1136, 800),
        (1264, 784), (1392, 784), (1536, 784), (1672, 784),
        (976, 992), (1072, 976), (1200, 992), (1312, 976),
        (1440, 1008), (1616, 1008), (608, 368), (672, 368),
        (624, 864), (688, 880), (320, 384), (256, 896),
        (448, 1008), (80, 384))]
    for i, (x, feet_y) in enumerate(social, 1):
        sprite = ("river_villager_sunhat", "river_villager_shawl", "river_fisherman")[(i - 1) % 3]
        add(f"villager_river_{i:02d}", sprite, x, feet_y - 22)
    add("player", "player", 1442, 684, width=16, height=24)
    # Keep hostile wildlife near the banks, lake, and outer approaches.
    for sprite, x, y in (
        ("finling", 576, 224), ("finling", 672, 912),
        ("finling", 896, 1120), ("finling", 64, 832),
        ("lake_maw", 128, 576), ("lake_maw", 592, 720),
        ("lake_maw", 272, 976), ("river_serpent", 848, 128),
        ("river_serpent", 848, 912), ("river_serpent", 912, 1120),
        ("finling", 1120, 1184), ("lake_maw", 544, 592)):
        add(sprite, sprite, x, y)
    for x, y in ((112, 720), (128, 800), (320, 896), (480, 880),
                 (592, 720), (720, 624), (864, 656), (864, 880)):
        add("river_fisherman", "river_fisherman", x, y)
    for x, y in ((200, 656), (368, 728), (784, 576), (792, 1024)):
        add("fishing_boat", "fishing_boat", x, y)
    for x, y in ((96, 992), (480, 1024), (944, 1136), (1040, 1136)):
        add("terraced_field", "terraced_field", x, y)
    # Sparse plants frame the banks without blocking the bridge approaches.
    for x, y in ((736, 176), (864, 192), (736, 336), (864, 368),
                 (736, 592), (864, 656), (736, 896), (864, 992),
                 (736, 1104), (864, 1184), (128, 560), (480, 784),
                 (96, 752), (544, 688), (176, 528), (400, 848)):
        add("reed_cluster", "reed_cluster", x, y)
    for x, y in ((48, 152), (448, 176), (96, 304), (576, 160),
                 (336, 528), (560, 992), (944, 320), (1296, 368),
                 (1680, 368), (1024, 880), (1712, 1056), (608, 1120),
                 (48, 1088), (448, 1136)):
        add("olive_tree", "olive_tree", x, y)

    layers = [layer("Ground", ground, 1), layer("Paths and Plaza", paths, 2),
              layer("Common Fields", common, 3), layer("Private Fields", private, 4),
              layer("Shoreline", details, 5), layer("Water", water, 6),
              {"id": 7, "name": "Buildings, Villagers and River", "type": "objectgroup",
               "draworder": "topdown", "opacity": 1, "visible": True,
               "x": 0, "y": 0, "objects": objects}]
    map_data = {"type": "map", "version": "1.10", "tiledversion": "1.12.2",
                "orientation": "orthogonal", "renderorder": "right-down", "width": WIDTH,
                "height": HEIGHT, "tilewidth": CELL, "tileheight": CELL,
                "infinite": False, "nextlayerid": 8, "nextobjectid": len(objects) + 1,
                "backgroundcolor": "#213340", "layers": layers,
                "tilesets": [{"firstgid": 1, "source": "concepts/terrain.tsj"},
                             {"firstgid": 100, "source": "concepts/objects.tsj"},
                             {"firstgid": 300, "source": "brudet_terrain.tsj"},
                             {"firstgid": 400, "source": "brudet_objects.tsj"}]}
    object_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                      "name": "brudet_objects", "tilewidth": 112, "tileheight": 96,
                      "tilecount": len(OBJECTS), "columns": 0,
                      "objectalignment": "bottomleft",
                      "tiles": [{"id": i, "image": f"../assets/art/river_planet/{name}.png",
                                 "imagewidth": w, "imageheight": h}
                                for i, (name, w, h) in enumerate(OBJECTS)]}
    terrain_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                       "name": "brudet_terrain", "tilewidth": 16, "tileheight": 16,
                       "tilecount": 32, "columns": 8,
                       "image": "../assets/art/river_planet/river_terrain.png",
                       "imagewidth": 128, "imageheight": 64}
    for filename, data in (("brudet.tmj", map_data),
                           ("brudet_objects.tsj", object_tileset),
                           ("brudet_terrain.tsj", terrain_tileset)):
        (MAPS / filename).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Generated {WIDTH}x{HEIGHT} Brudet: {len(objects)} objects, {len(river)} water cells")

if __name__ == "__main__":
    main()
