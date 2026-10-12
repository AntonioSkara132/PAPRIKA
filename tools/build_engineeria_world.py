#!/usr/bin/env python3
"""Build the Rudnik Tiled map and its tilesets.

Rudnik is a mining planet of Engineeria. The diplomatic ship came down in the
southwest of a broadleaf forest. A stream runs from north to south through the
middle with two fords, and a rocky ledge crosses the east half with a single
ramp. Davor's house stands in a fenced clearing, with smoke rising from its
chimney.

A path leads from the wreck over the southern ford, up the ramp and north to
the clearing. Thickets that cannot be walked through keep the run on or near
the path, and they ring the whole map.

East of the clearing a road leads to the Rudnik mining port: an unbroken stone
wall with a wicket gate, the mine and its lift, a maintenance shed, the dispatch
engine, bunkhouses, ore heaps and an ore ship on its pad. The internal planet
key stays `engineeria`, so saves made before the port existed still load.

Run tools/create_engineeria_art.py first; it draws the sprites used here.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "maps"
ART = "../assets/art/engineeria"
# The forest is the first WIDTH columns and is drawn exactly as it was before the
# port existed; the port and the forest round it take the columns up to FULL_WIDTH.
WIDTH, HEIGHT, CELL = 96, 72, 16
FULL_WIDTH = 150
RNG = random.Random(7310)
PORT_RNG = random.Random(4417)

# Terrain atlas order from create_engineeria_art.TERRAIN; the map uses firstgid 1.
T = {name: i + 1 for i, name in enumerate(
    ["floor", "floor_2", "moss", "leaves", "path", "path_2", "water", "water_2",
     "ford", "ledge", "ramp", "clearing", "scorch", "fence_h", "fence_v", "fence_post",
     "thicket", "thicket_2", "bank", "ledge_face", "port_wall", "paving", "paving_2", "rail",
     "mine_rock", "mine_face", "pad", "ore_heap"])}

OBJECT_IMAGES = {
    "player": "../art/concepts/source/player.png",
    "wreck": f"{ART}/wreck.png",
    "davor_house": f"{ART}/davor_house.png",
    "woodpile": f"{ART}/woodpile.png",
    "chopping_block": f"{ART}/chopping_block.png",
    "fern": f"{ART}/fern.png",
    "fallen_log": f"{ART}/fallen_log.png",
    "flame": f"{ART}/flame.png",
    "port_gate": f"{ART}/port_gate.png",
    "mine_entrance": f"{ART}/mine_entrance.png",
    "lift_headframe": f"{ART}/lift_headframe.png",
    "maintenance_shed": f"{ART}/maintenance_shed.png",
    "dispatch_engine": f"{ART}/dispatch_engine.png",
    "ore_pile": f"{ART}/ore_pile.png",
    "ore_cart": f"{ART}/ore_cart.png",
    "supply_crates": f"{ART}/supply_crates.png",
    "lamp_post": f"{ART}/lamp_post.png",
    "ore_ship": f"{ART}/ore_ship.png",
}
for key in ("foreman", "captain", "dispatcher", "gatekeeper", "resident_0", "resident_1",
            "miner_0", "miner_1", "miner_2", "miner_3"):
    OBJECT_IMAGES[f"port_{key}"] = f"{ART}/port_{key}.png"
for i in range(2):
    OBJECT_IMAGES[f"bunkhouse_{i}"] = f"{ART}/bunkhouse_{i}.png"
for i in range(3):
    OBJECT_IMAGES[f"broadleaf_{i}"] = f"{ART}/broadleaf_{i}.png"
    OBJECT_IMAGES[f"envoy_{i}_lying"] = f"../assets/art/pomidor/envoy_{i}_lying.png"
for i in range(2):
    OBJECT_IMAGES[f"bush_{i}"] = f"{ART}/bush_{i}.png"
    OBJECT_IMAGES[f"debris_{i}"] = f"{ART}/debris_{i}.png"

NAMES = list(OBJECT_IMAGES)
GID = {name: 100 + i for i, name in enumerate(NAMES)}
SIZE = {}
for name, rel in OBJECT_IMAGES.items():
    with Image.open((MAPS / rel).resolve()) as im:
        SIZE[name] = im.size

# Areas in cells: x0, y0, x1, y1.
CRASH = (6, 52, 28, 68)
YARD = (74, 5, 91, 18)          # inside Davor's fence, fence included
CLEARING = (70, 2, 94, 23)      # mown grass around the yard
LEDGE_ROWS = (35, 38)           # a rock top and two rows of cliff face
LEDGE_X = (44, 94)
RAMP_X = (66, 69)
FORDS = (22, 50)                # rows where the path crosses the stream
GATE_X = (82, 84)               # the gap in the yard's south fence

# The Rudnik mining port, walls included: the wall runs round the edge of this box.
PORT = (106, 4, 146, 44)
PORT_GATE_ROWS = (20, 22)       # the wicket gate in the west wall; the wall stays solid
ROAD_ROWS = (20, 22)            # the road from Davor's yard to the gate
MINE_ROCK_ROWS = (5, 10)        # the mine hill inside the north wall; the last row is its face
ORE_HEAPS = (116, 24, 121, 27)  # five cells wide, so Davor can just jump it
PAD = (128, 28, 144, 42)
RAIL_X = 124


def stream_x(y: int) -> int:
    """The stream's west column on row y."""
    return 40 + round(3 * math.sin(y / 7.0))


# The path from the wreck to the gate, as waypoints in cells.
PATH = [(17, 62), (24, 58), (30, 54), (stream_x(FORDS[1]) - 2, FORDS[1]), (stream_x(FORDS[1]) + 4, FORDS[1]),
        (52, 47), (60, 43), (67, 40), (67, 34), (70, 28), (76, 24), (GATE_X[0], 20), (GATE_X[0], 17)]
# A second, longer route over the northern ford.
NORTH_PATH = [(24, 58), (20, 46), (22, 34), (28, 26), (stream_x(FORDS[0]) - 2, FORDS[0]),
              (stream_x(FORDS[0]) + 4, FORDS[0]), (54, 20), (64, 22), (70, 28)]


def blank(fill: int = 0, width: int = WIDTH) -> list[int]:
    return [fill] * (width * HEIGHT)


# Layers are flat lists; their width follows from their length, so the same
# helpers draw on the forest (WIDTH wide) and on the widened map (FULL_WIDTH).
def paint(data: list[int], x: int, y: int, gid: int) -> None:
    width = len(data) // HEIGHT
    if 0 <= x < width and 0 <= y < HEIGHT:
        data[y * width + x] = gid


def get(data: list[int], x: int, y: int) -> int:
    width = len(data) // HEIGHT
    return data[y * width + x] if 0 <= x < width and 0 <= y < HEIGHT else -1


def widen(data: list[int]) -> list[int]:
    """The forest layer with empty columns added on the east for the port."""
    extra = [0] * (FULL_WIDTH - WIDTH)
    return [gid for y in range(HEIGHT) for gid in data[y * WIDTH:(y + 1) * WIDTH] + extra]


def rect(data: list[int], x0: int, y0: int, x1: int, y1: int, gid: int) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            paint(data, x, y, gid)


def inside(x: int, y: int, box: tuple[int, int, int, int]) -> bool:
    return box[0] <= x < box[2] and box[1] <= y < box[3]


def line_cells(points: list[tuple[int, int]]):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            yield round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps)


def layer(name: str, data: list[int], index: int) -> dict:
    return {"id": index, "name": name, "type": "tilelayer", "x": 0, "y": 0,
            "width": FULL_WIDTH, "height": HEIGHT, "opacity": 1, "visible": True, "data": data}


def main() -> None:
    ground = []
    for _ in range(WIDTH * HEIGHT):
        r = RNG.random()
        ground.append(T["floor"] if r < .55 else T["floor_2"] if r < .78 else T["leaves"] if r < .92 else T["moss"])
    paths = blank()
    water = blank()
    ledges = blank()
    thicket = blank()
    fences = blank()
    objects: list[dict] = []
    clear: set[tuple[int, int]] = set()   # cells kept free of trees

    def add(name: str, sprite: str, x: float, bottom: float) -> None:
        w, h = SIZE[sprite]
        objects.append({"id": len(objects) + 1, "name": name, "type": "engineeria_object",
                        "gid": GID[sprite], "x": round(x), "y": round(bottom),
                        "width": w, "height": h, "rotation": 0, "visible": True})

    # ---- the stream ----
    for y in range(HEIGHT):
        sx = stream_x(y)
        for x in (sx, sx + 1):
            paint(water, x, y, T["water"] if (x + y) % 3 else T["water_2"])
            clear.add((x, y))
        paint(paths, sx - 1, y, T["bank"])
        paint(paths, sx + 2, y, T["bank"])
    for row in FORDS:
        sx = stream_x(row)
        for y in (row, row + 1):
            for x in (sx, sx + 1):
                paint(water, x, y, 0)
                paint(paths, x, y, T["ford"])

    # ---- paths ----
    for route in (PATH, NORTH_PATH):
        for x, y in line_cells(route):
            for dx in (0, 1):
                for dy in (0, 1):
                    if get(water, x + dx, y + dy) == 0:
                        paint(paths, x + dx, y + dy, T["path"] if RNG.random() < .75 else T["path_2"])
                    for ax in range(-2, 4):
                        for ay in range(-2, 4):
                            clear.add((x + ax, y + ay))

    # ---- the ledge with its ramp ----
    for y in range(*LEDGE_ROWS):
        for x in range(LEDGE_X[0], LEDGE_X[1]):
            if RAMP_X[0] <= x < RAMP_X[1]:
                paint(paths, x, y, T["ramp"])
            else:
                paint(ledges, x, y, T["ledge"] if y == LEDGE_ROWS[0] else T["ledge_face"])
                paint(paths, x, y, 0)
            clear.add((x, y))
    # The ledge meets the stream so the only ways up are the ramp and the northern ford.
    for y in range(*LEDGE_ROWS):
        for x in range(stream_x(y) + 2, LEDGE_X[0]):
            paint(ledges, x, y, T["ledge"] if y == LEDGE_ROWS[0] else T["ledge_face"])
            paint(paths, x, y, 0)

    # ---- the crash site ----
    cx0, cy0, cx1, cy1 = CRASH
    for y in range(cy0, cy1):
        for x in range(cx0, cx1):
            d = math.hypot((x - 15) / 9.0, (y - 60) / 6.0)
            if d < 1.0 or (d < 1.3 and RNG.random() < .4):
                paint(paths, x, y, T["scorch"])
            clear.add((x, y))
    add("wreck", "wreck", 10 * CELL, 60 * CELL)
    for sprite, x, y in (("debris_0", 7, 57), ("debris_1", 22, 55), ("debris_0", 25, 63), ("debris_1", 9, 65), ("debris_0", 19, 66)):
        add("debris", sprite, x * CELL, y * CELL)
    for x, y in ((8, 61), (26, 59), (21, 65)):
        add("wreck_fire", "flame", x * CELL, y * CELL)
    # The three envoys where they were thrown from the ship.
    add("envoy_lying_0", "envoy_0_lying", 11 * CELL, 63 * CELL + 6)
    add("envoy_lying_1", "envoy_1_lying", 18 * CELL, 64 * CELL + 10)
    add("envoy_lying_2", "envoy_2_lying", 23 * CELL - 4, 61 * CELL + 6)
    add("player", "player", 14 * CELL, 62 * CELL + 12)

    # ---- Davor's clearing ----
    gx0, gy0, gx1, gy1 = CLEARING
    for y in range(gy0, gy1):
        for x in range(gx0, gx1):
            edge = min(x - gx0, gx1 - 1 - x, y - gy0, gy1 - 1 - y)
            if edge > 0 or RNG.random() < .5:
                paint(ground, x, y, T["clearing"])
            clear.add((x, y))
    yx0, yy0, yx1, yy1 = YARD
    for x in range(yx0, yx1):
        paint(fences, x, yy0, T["fence_h"])
        if not GATE_X[0] <= x < GATE_X[1]:
            paint(fences, x, yy1 - 1, T["fence_h"])
    for y in range(yy0, yy1):
        paint(fences, yx0, y, T["fence_v"])
        paint(fences, yx1 - 1, y, T["fence_v"])
    for cx, cy in ((yx0, yy0), (yx1 - 1, yy0), (yx0, yy1 - 1), (yx1 - 1, yy1 - 1), (GATE_X[0] - 1, yy1 - 1), (GATE_X[1], yy1 - 1)):
        paint(fences, cx, cy, T["fence_post"])
    hw, _ = SIZE["davor_house"]
    add("davor_house", "davor_house", 83 * CELL - hw // 2, 12 * CELL)
    add("woodpile", "woodpile", 76 * CELL, 13 * CELL)
    add("chopping_block", "chopping_block", 78 * CELL + 6, 14 * CELL + 6)
    rect(paths, GATE_X[0], 12, GATE_X[1], yy1, T["path"])

    # ---- thickets ----
    # A ring round the map, and patches in the forest away from the paths.
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if (x < 2 or y < 2 or x >= WIDTH - 2 or y >= HEIGHT - 2) and get(water, x, y) == 0:
                paint(thicket, x, y, T["thicket"] if RNG.random() < .6 else T["thicket_2"])
    for _ in range(46):
        px, py = RNG.randrange(4, WIDTH - 4), RNG.randrange(4, HEIGHT - 4)
        rw, rh = RNG.randint(2, 6), RNG.randint(2, 4)
        cells = [(x, y) for x in range(px, px + rw) for y in range(py, py + rh)]
        if any((x, y) in clear for x, y in cells):
            continue
        for x, y in cells:
            paint(thicket, x, y, T["thicket"] if RNG.random() < .6 else T["thicket_2"])
            clear.add((x, y))

    # ---- trees, bushes, logs and ferns ----
    taken: list[tuple[int, int]] = []
    attempts = 0
    while attempts < 6000 and len(taken) < 330:
        attempts += 1
        x, y = RNG.randrange(2, WIDTH - 2), RNG.randrange(3, HEIGHT - 2)
        if (x, y) in clear or get(ledges, x, y) or get(thicket, x, y) or any(abs(x - tx) < 2 and abs(y - ty) < 2 for tx, ty in taken):
            continue
        taken.append((x, y))
        sprite = f"broadleaf_{RNG.randrange(3)}"
        w, _ = SIZE[sprite]
        add("tree_broadleaf", sprite, x * CELL + 8 - w // 2, y * CELL + 14)
    for _ in range(140):
        x, y = RNG.randrange(3, WIDTH - 3), RNG.randrange(3, HEIGHT - 3)
        if get(ledges, x, y) or get(thicket, x, y) or get(water, x, y) or get(paths, x, y) or (x, y) in taken:
            continue
        roll = RNG.random()
        if roll < .45:
            add("fern", "fern", x * CELL + 1, y * CELL + 12)
        elif roll < .8 and (x, y) not in clear:
            add("bush", f"bush_{RNG.randrange(2)}", x * CELL - 3, y * CELL + 14)
        elif (x, y) not in clear and (x + 1, y) not in clear:
            add("fallen_log", "fallen_log", x * CELL - 4, y * CELL + 13)

    # ---- the Rudnik mining port, east of Davor's clearing ----
    ground, paths, water, ledges, thicket, fences = (widen(data) for data in (ground, paths, water, ledges, thicket, fences))
    mine_rock = blank(width=FULL_WIDTH)
    ore_heaps = blank(width=FULL_WIDTH)
    port_walls = blank(width=FULL_WIDTH)
    port_trees = build_port(ground, paths, thicket, mine_rock, ore_heaps, port_walls, add)

    layers = [layer("Ground", ground, 1), layer("Paths", paths, 2), layer("Water", water, 3),
              layer("Ledges", ledges, 4), layer("Thicket", thicket, 5), layer("Fences", fences, 6),
              layer("Mine Rock", mine_rock, 7), layer("Ore Heaps", ore_heaps, 8), layer("Port Walls", port_walls, 9),
              {"id": 10, "name": "Trees and People", "type": "objectgroup",
               "draworder": "topdown", "opacity": 1, "visible": True,
               "x": 0, "y": 0, "objects": objects}]
    map_data = {"type": "map", "version": "1.10", "tiledversion": "1.12.2",
                "orientation": "orthogonal", "renderorder": "right-down", "width": FULL_WIDTH,
                "height": HEIGHT, "tilewidth": CELL, "tileheight": CELL,
                "infinite": False, "nextlayerid": 11, "nextobjectid": len(objects) + 1,
                "backgroundcolor": "#26442c", "layers": layers,
                "tilesets": [{"firstgid": 1, "source": "engineeria_terrain.tsj"},
                             {"firstgid": 100, "source": "engineeria_objects.tsj"}]}
    object_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                      "name": "engineeria_objects", "tilewidth": 176, "tileheight": 96,
                      "tilecount": len(NAMES), "columns": 0, "objectalignment": "bottomleft",
                      "tiles": [{"id": i, "image": OBJECT_IMAGES[name],
                                 "imagewidth": SIZE[name][0], "imageheight": SIZE[name][1]}
                                for i, name in enumerate(NAMES)]}
    terrain_tileset = {"type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
                       "name": "engineeria_terrain", "tilewidth": 16, "tileheight": 16,
                       "tilecount": 32, "columns": 8,
                       "image": f"{ART}/engineeria_terrain.png", "imagewidth": 128, "imageheight": 64}
    for filename, data in (("engineeria.tmj", map_data), ("engineeria_objects.tsj", object_tileset),
                           ("engineeria_terrain.tsj", terrain_tileset)):
        (MAPS / filename).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Generated {FULL_WIDTH}x{HEIGHT} Rudnik: {len(objects)} objects, {len(taken) + port_trees} trees")


def build_port(ground, paths, thicket, mine_rock, ore_heaps, port_walls, add) -> int:
    """Draws the forest east of the clearing, the road and the walled port.

    The wall is one cell thick and unbroken; the gate is drawn over it and the
    game moves the player through it, so beasts have no way in. Returns the
    number of trees planted."""
    px0, py0, px1, py1 = PORT
    clear: set[tuple[int, int]] = set()

    def in_port(x: int, y: int, margin: int = 0) -> bool:
        return px0 - margin <= x < px1 + margin and py0 - margin <= y < py1 + margin

    # Forest floor and the ring of thicket for the new columns.
    for y in range(HEIGHT):
        for x in range(WIDTH, FULL_WIDTH):
            r = PORT_RNG.random()
            paint(ground, x, y, T["floor"] if r < .55 else T["floor_2"] if r < .78 else T["leaves"] if r < .92 else T["moss"])
            if y < 2 or y >= HEIGHT - 2 or x >= FULL_WIDTH - 2:
                paint(thicket, x, y, T["thicket"] if PORT_RNG.random() < .6 else T["thicket_2"])

    # The road leaves the yard gate, crosses the clearing and the old thicket ring
    # and widens into a small square in front of the port gate.
    for x, y in line_cells([(GATE_X[0], ROAD_ROWS[0]), (px0 - 1, ROAD_ROWS[0])]):
        for dy in range(ROAD_ROWS[1] - ROAD_ROWS[0]):
            paint(paths, x, y + dy, T["path"] if PORT_RNG.random() < .75 else T["path_2"])
            paint(paths, x + 1, y + dy, T["path"] if PORT_RNG.random() < .75 else T["path_2"])
    for x in range(WIDTH - 4, px0):
        for y in range(ROAD_ROWS[0] - 3, ROAD_ROWS[1] + 3):
            paint(thicket, x, y, 0)
            clear.add((x, y))
    for x in range(px0 - 4, px0):
        for y in range(ROAD_ROWS[0] - 1, ROAD_ROWS[1] + 1):
            paint(paths, x, y, T["path"] if PORT_RNG.random() < .75 else T["path_2"])

    # Inside the walls: paving, the mine hill, the rails, the ore heaps and the pad.
    for y in range(py0, py1):
        for x in range(px0, px1):
            clear.add((x, y))
            if x in (px0, px1 - 1) or y in (py0, py1 - 1):
                paint(port_walls, x, y, T["port_wall"])
                continue
            paint(ground, x, y, T["paving"] if PORT_RNG.random() < .7 else T["paving_2"])
            if MINE_ROCK_ROWS[0] <= y < MINE_ROCK_ROWS[1]:
                paint(mine_rock, x, y, T["mine_face"] if y == MINE_ROCK_ROWS[1] - 1 else T["mine_rock"])
    hx0, hy0, hx1, hy1 = ORE_HEAPS
    rect(ore_heaps, hx0, hy0, hx1, hy1, T["ore_heap"])
    ax0, ay0, ax1, ay1 = PAD
    rect(paths, ax0, ay0, ax1, ay1, T["pad"])
    for y in range(MINE_ROCK_ROWS[1] + 3, 34):
        paint(paths, RAIL_X, y, T["rail"])
    for x in range(RAIL_X, ax0):
        paint(paths, x, 33, T["rail"])

    # Buildings, the lift and the ship. Map objects with service names are used
    # by scripts/world/engineeria_world.gd; their positions match its constants.
    gw, gh = SIZE["port_gate"]
    add("rudnik_gate", "port_gate", px0 * CELL + 8 - gw // 2, PORT_GATE_ROWS[1] * CELL)
    add("mine_entrance", "mine_entrance", 111 * CELL, 11 * CELL)
    add("rudnik_lift", "lift_headframe", 121 * CELL, 13 * CELL)
    add("rudnik_shed", "maintenance_shed", 108 * CELL + 4, 16 * CELL)
    add("rudnik_dispatch", "dispatch_engine", 131 * CELL, 15 * CELL)
    add("bunkhouse", "bunkhouse_0", 108 * CELL, 31 * CELL)
    add("bunkhouse", "bunkhouse_1", 108 * CELL, 38 * CELL)
    add("rudnik_ore_ship", "ore_ship", 128 * CELL + 8, 38 * CELL)
    for sprite, x, y in (("ore_pile", 115, 29), ("ore_pile", 121, 29), ("ore_cart", 126, 31),
                         ("ore_cart", 126, 22), ("supply_crates", 140, 18), ("supply_crates", 142, 25),
                         ("supply_crates", 117, 40)):
        add(sprite, sprite, x * CELL, y * CELL)
    for x, y in ((px0 - 2, ROAD_ROWS[0] - 1), (px0 - 2, ROAD_ROWS[1] + 2), (115, 19), (128, 19), (127, 27), (144, 27)):
        add("lamp_post", "lamp_post", x * CELL + 3, y * CELL)

    # The people of the port. The four miners stand where the lift lets them out;
    # the game shows them once they are brought up.
    people = {"gatekeeper": (1762, 302), "foreman": (2012, 222), "dispatcher": (2196, 262),
              "captain": (2150, 628), "resident_0": (1838, 520), "resident_1": (1900, 650),
              "miner_0": (1930, 238), "miner_1": (1950, 244), "miner_2": (1972, 238), "miner_3": (1992, 246)}
    for key, (fx, fy) in people.items():
        w, _ = SIZE[f"port_{key}"]
        add(f"story_{key}", f"port_{key}", fx - w // 2, fy + 2)

    # Thicket patches and trees in the forest round the port.
    for _ in range(14):
        sx, sy = PORT_RNG.randrange(WIDTH, FULL_WIDTH - 4), PORT_RNG.randrange(4, HEIGHT - 4)
        rw, rh = PORT_RNG.randint(2, 5), PORT_RNG.randint(2, 4)
        cells = [(x, y) for x in range(sx, sx + rw) for y in range(sy, sy + rh)]
        if any((x, y) in clear or in_port(x, y, 2) for x, y in cells):
            continue
        for x, y in cells:
            paint(thicket, x, y, T["thicket"] if PORT_RNG.random() < .6 else T["thicket_2"])
            clear.add((x, y))
    taken: list[tuple[int, int]] = []
    for _ in range(3000):
        if len(taken) >= 150:
            break
        x, y = PORT_RNG.randrange(WIDTH, FULL_WIDTH - 2), PORT_RNG.randrange(3, HEIGHT - 2)
        if (x, y) in clear or in_port(x, y, 2) or get(thicket, x, y) or any(abs(x - tx) < 2 and abs(y - ty) < 2 for tx, ty in taken):
            continue
        taken.append((x, y))
        sprite = f"broadleaf_{PORT_RNG.randrange(3)}"
        w, _ = SIZE[sprite]
        add("tree_broadleaf", sprite, x * CELL + 8 - w // 2, y * CELL + 14)
    return len(taken)


if __name__ == "__main__":
    main()
