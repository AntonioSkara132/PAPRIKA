#!/usr/bin/python3
"""Create a large editable first-planet Tiled map from the approved village sketch.

This script writes the initial map once. After that, edit `maps/paprika.tmj` in Tiled;
do not rerun the generator over hand-edited map changes.
"""
from pathlib import Path
import json
import random

ROOT = Path(__file__).resolve().parents[1]
CONCEPT = ROOT / "maps/concepts/paprika_first_view.tmj"
DEST = ROOT / "maps/paprika.tmj"
WIDTH, HEIGHT = 104, 72
OX, OY = 32, 22
PX, PY = OX * 16, OY * 16
TILE = 16
RNG = random.Random(2718)

source = json.loads(CONCEPT.read_text())
legacy_layers = {layer["name"]: layer for layer in source["layers"]}


def index(x: int, y: int) -> int:
    return y * WIDTH + x


def set_tile(layer: list[int], x: int, y: int, gid: int) -> None:
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        layer[index(x, y)] = gid


def rect(layer: list[int], x1: int, y1: int, x2: int, y2: int, gid: int) -> None:
    for y in range(y1, y2):
        for x in range(x1, x2):
            set_tile(layer, x, y, gid)


def layer(name: str, data: list[int], layer_id: int) -> dict:
    return {
        "id": layer_id, "name": name, "type": "tilelayer",
        "width": WIDTH, "height": HEIGHT, "x": 0, "y": 0,
        "opacity": 1, "visible": True, "data": data,
    }


# Tileset GIDs: grass 1/2, path 3, stone 4, soil 5,
# breathable outer space 6, cliff 7, landing pad 8,
# potatoes 9, carrots 10, tomatoes 11, grapes 12, flowers 13.
ground = [2 if RNG.random() < 0.115 else 1 for _ in range(WIDTH * HEIGHT)]
paths = [0] * len(ground)
common = [0] * len(ground)
private = [0] * len(ground)
decoration = [0] * len(ground)

for old_y in range(source["height"]):
    for old_x in range(source["width"]):
        new_x, new_y = old_x + OX, old_y + OY
        old_i = old_y * source["width"] + old_x
        base_id = legacy_layers["Ground"]["data"][old_i]
        # The concept picture showed the rim close to town. The playable
        # planet has more land beyond the village; rebuild the actual rim.
        if base_id in (6, 7):
            base_id = 2 if RNG.random() < 0.16 else 1
        set_tile(ground, new_x, new_y, base_id)
        set_tile(paths, new_x, new_y, legacy_layers["Paths and Plaza"]["data"][old_i])
        planted = legacy_layers["Fields and Landing Pad"]["data"][old_i]
        if planted in (9, 10, 11, 12):
            crop_x, crop_y = new_x, new_y
            # The concept's small private plot would lie under the food shop.
            if 55 <= new_x <= 59 and 26 <= new_y <= 28:
                crop_x, crop_y = new_x + 2, new_y - 7
            set_tile(common if old_y >= 15 else private, crop_x, crop_y, planted)
        else:
            set_tile(decoration, new_x, new_y, planted)

# Rural roads connecting village to outer fields, forest and travel dock.
for x in range(8, 58):
    rect(paths, x, 33, x + 1, 35, 3)
for x in range(71, 94):
    rect(paths, x, 33, x + 1, 35, 3)
for y in range(8, 34):
    rect(paths, 51, y, 53, y + 1, 3)
# Side path to the work office, clear of nearby houses.
rect(paths, 47, 21, 52, 23, 3)
for y in range(42, 55):
    rect(paths, 53, y, 55, y + 1, 3)
for x in range(54, 79):
    rect(paths, x, 53, x + 1, 55, 3)
for y in range(34, 56):
    rect(paths, 78, y, 80, y + 1, 3)
for x in range(15, 50):
    rect(paths, x, 47, x + 1, 49, 3)
for y in range(34, 49):
    rect(paths, 22, y, 24, y + 1, 3)

# Broad common fields southwest of town and smaller private holdings to the north.
for y in range(49, 57):
    for x in range(28, 48):
        if x % 6 == 0 or y % 5 == 0:
            set_tile(common, x, y, 5)
        else:
            set_tile(common, x, y, 9 + ((x // 3 + y // 2) % 4))
for y in range(15, 19):
    for x in range(57, 66):
        set_tile(private, x, y, 9 + ((x // 2 + y) % 4))

# Distant raised, flat rim. Space can be breathed; walking off the edge is blocked.
for y in range(HEIGHT):
    for x in range(WIDTH):
        edge_y = 62 if x < 48 else (57 if x < 74 else 53)
        edge_y += (x // 9) % 2
        if y == edge_y:
            set_tile(ground, x, y, 7)
            set_tile(paths, x, y, 0)
            set_tile(common, x, y, 0)
            set_tile(private, x, y, 0)
            set_tile(decoration, x, y, 0)
        elif y > edge_y:
            set_tile(ground, x, y, 6)
            set_tile(paths, x, y, 0)
            set_tile(common, x, y, 0)
            set_tile(private, x, y, 0)
            set_tile(decoration, x, y, 0)

# Native flowers break up the open meadow. No flowers over roads or crops.
for _ in range(240):
    x, y = RNG.randrange(3, WIDTH - 2), RNG.randrange(3, 61)
    i = index(x, y)
    if ground[i] in (1, 2) and not paths[i] and not common[i] and not private[i] and not decoration[i]:
        set_tile(decoration, x, y, 13)

# Original approved buildings and props, offset intact.
objects = []
for old in legacy_layers["Buildings Characters and Props"]["objects"]:
    obj = dict(old)
    obj["x"] = old["x"] + PX
    obj["y"] = old["y"] + PY
    if obj["name"] == "player":
        obj["y"] = PY + 268
    if obj["name"] == "forest_sign":
        obj["x"], obj["y"], obj["width"] = 634, 508, 48
    if obj["name"] in ("wolf", "rabbit"):
        continue  # wildlife belongs in the forest on the larger map
    objects.append(obj)
next_id = max(obj["id"] for obj in objects) + 1

extra_defs = [
    ("clothing_shop", 80, 64),
    ("work_office", 80, 64),
    ("bandit", 16, 24),
    ("zombie", 16, 24),
    ("zombie_bear", 30, 26),
    ("hacker", 16, 24),
    ("common_field_sign", 64, 32),
    ("private_garden_sign", 64, 32),
    ("forest_warning_sign", 64, 40),
]

def add(name: str, x: int, y: int, *, base_id: int = 100, tile_id: int = 0, w: int = 32, h: int = 48, properties: dict | None = None):
    global next_id
    obj = {
        "id": next_id, "name": name, "type": "world_object", "gid": base_id + tile_id,
        "x": x, "y": y, "width": w, "height": h, "rotation": 0,
        "visible": True,
    }
    if properties:
        obj["properties"] = [{"name": k, "type": "string", "value": v} for k, v in properties.items()]
    objects.append(obj)
    next_id += 1

old_ts = json.loads((ROOT / "maps/concepts/objects.tsj").read_text())
old_ids = {Path(tile["image"]).stem: tile["id"] for tile in old_ts["tiles"]}

# Non-immediate service buildings, individually accessible.
add("work_office", 720, 354, base_id=200, tile_id=1, w=80, h=64)
add("clothing_shop", 1190, 492, base_id=200, tile_id=0, w=80, h=64)

# Border homes, including a visible second floor on the square houses.
for name, x, y, w, h in [
    ("cottage_blue", 420, 562, 64, 56), ("cottage_red", 535, 450, 64, 56),
    ("shack", 1060, 443, 48, 40), ("two_storey", 1165, 609, 64, 72),
    ("shack", 675, 715, 48, 40), ("cottage_red", 807, 725, 64, 56),
    ("cottage_blue", 1155, 742, 64, 56), ("two_storey", 964, 765, 64, 72),
]:
    add(name, x, y, tile_id=old_ids[name], w=w, h=h)

# Forest pockets begin beyond the cultivated village. Each clearing leaves
# enough room to move, and the central road remains open.
forest_zones = [
    (100, 110, 420, 520), (1080, 125, 1490, 450),
    (90, 590, 470, 950), (1230, 490, 1530, 800),
    (360, 100, 680, 290), (750, 95, 980, 315),
    (700, 840, 1220, 975),
]
for x1, y1, x2, y2 in forest_zones:
    count = max(8, ((x2 - x1) * (y2 - y1)) // 2500)
    for _ in range(count):
        x, y = RNG.randrange(x1, x2), RNG.randrange(y1, y2)
        cell = (x // TILE, y // TILE)
        idx = index(*cell)
        if ground[idx] in (6, 7) or paths[idx] or common[idx] or private[idx]:
            continue
        if any(abs(x - existing["x"]) < 31 and abs(y - existing["y"]) < 22 for existing in objects if existing["name"].startswith("tree")):
            continue
        tree_name = "tree1" if RNG.random() < 0.5 else "tree2"
        add(tree_name, x, y, tile_id=old_ids[tree_name], w=32, h=48)

for x, y in [(410, 500), (1280, 490), (396, 821)]:
    add("forest_sign", x, y, tile_id=old_ids["forest_sign"], w=48, h=32)

# Keep the ship visible at the rim, and add a second usable-looking landing pad.
for y in range(46, 49):
    for x in range(77, 85):
        set_tile(decoration, x, y, 8)
add("spaceship", 1250, 788, tile_id=old_ids["spaceship"], w=112, h=56)

# Native forest creatures appear in the map itself and remain editable in Tiled.
for i, (x, y) in enumerate([(365, 280), (190, 420), (280, 700), (435, 792), (1350, 290), (1430, 570), (1010, 890), (764, 290)]):
    add("rabbit", x, y, tile_id=old_ids["rabbit"], w=16, h=16, properties={"spawn": f"rabbit_{i:02d}"})
for name, x, y, type_id in [
    ("wolf", 220, 650, None), ("wolf", 1300, 330, None),
    ("zombie", 1450, 620, 3), ("zombie_bear", 1330, 720, 4),
    ("bandit", 340, 210, 2), ("hacker", 1090, 910, 5),
]:
    if name == "wolf":
        add(name, x, y, tile_id=old_ids["wolf"], w=24, h=18)
    else:
        _, w, h = extra_defs[type_id]
        add(name, x, y, base_id=200, tile_id=type_id, w=w, h=h)

extra_ts = {
    "type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
    "name": "paprika_additions", "tilewidth": 80, "tileheight": 64,
    "tilecount": len(extra_defs), "columns": 0,
    "objectalignment": "bottomleft",
    "tiles": [
        {"id": idx, "image": f"../assets/art/{name}.png", "imagewidth": w, "imageheight": h}
        for idx, (name, w, h) in enumerate(extra_defs)
    ],
}
(ROOT / "maps/additions.tsj").write_text(json.dumps(extra_ts, indent=2))

layers = [
    layer("Ground", ground, 1),
    layer("Paths and Plaza", paths, 2),
    layer("Common Fields", common, 3),
    layer("Private Fields", private, 4),
    layer("Flowers and Landing Pads", decoration, 5),
    {
        "id": 6, "name": "Buildings, Villagers and Forest", "type": "objectgroup",
        "draworder": "topdown", "opacity": 1, "visible": True,
        "x": 0, "y": 0, "objects": objects,
    },
]

world = {
    "type": "map", "version": "1.10", "tiledversion": "1.12.2",
    "orientation": "orthogonal", "renderorder": "right-down", "width": WIDTH, "height": HEIGHT,
    "tilewidth": TILE, "tileheight": TILE, "infinite": False,
    "nextlayerid": 7, "nextobjectid": next_id,
    "backgroundcolor": "#17152f", "layers": layers,
    "tilesets": [
        {"firstgid": 1, "source": "concepts/terrain.tsj"},
        {"firstgid": 100, "source": "concepts/objects.tsj"},
        {"firstgid": 200, "source": "additions.tsj"},
    ],
}
DEST.write_text(json.dumps(world, indent=2))
print(f"Created {WIDTH}x{HEIGHT} Paprika world with {len(objects)} placed objects at {DEST}")
