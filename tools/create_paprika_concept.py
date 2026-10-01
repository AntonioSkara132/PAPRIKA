#!/usr/bin/python3
"""Create editable pixel-art assets and a Tiled concept map for Paprika."""

from pathlib import Path
import json
import random
from PIL import Image, ImageDraw, ImageFont
from paprika_visual_art import draw_forest_tiles, forest_sign, modern_building as modern_building_art

ROOT = Path("/home/antonio/Paprika")
ART = ROOT / "art/concepts/source"
MAPS = ROOT / "maps/concepts"
ART.mkdir(parents=True, exist_ok=True)
MAPS.mkdir(parents=True, exist_ok=True)

TILE = 16
MAP_W = 40
MAP_H = 23
WIDTH = MAP_W * TILE
HEIGHT = MAP_H * TILE
FONT = ImageFont.load_default()
random.seed(17)

C = {
    "ink": "#1c1730",
    "grass": "#76a94b",
    "grass_dark": "#4f7b3a",
    "grass_light": "#98c95c",
    "path": "#d6b46f",
    "path_dark": "#a67d50",
    "stone": "#b9b6a6",
    "stone_dark": "#747687",
    "soil": "#845535",
    "soil_light": "#b17842",
    "space": "#17152f",
    "space_light": "#40315e",
    "cliff": "#61523c",
    "wood": "#8b5537",
    "wood_dark": "#543328",
    "cream": "#ead9ac",
    "roof": "#a84d3f",
    "roof_light": "#d56b4f",
    "gold": "#f5c34c",
    "cyan": "#5fd6d3",
    "cyan_dark": "#247f8a",
    "orange": "#ef873f",
    "red": "#d94b4b",
    "blue": "#4e83cf",
    "purple": "#7056a8",
    "white": "#f7f1dd",
    "black": "#11101b",
}


def save(img: Image.Image, name: str) -> Path:
    path = ART / name
    img.save(path)
    return path


def px(draw, xy, fill):
    draw.point(xy, fill=fill)


def outlined_rect(draw, box, fill, outline=C["ink"], width=2):
    draw.rectangle(box, fill=fill, outline=outline, width=width)


def text(draw, xy, value, fill=C["white"], anchor=None):
    draw.text(xy, value, font=FONT, fill=fill, anchor=anchor)


# --- Terrain tileset -------------------------------------------------------
tiles = Image.new("RGBA", (8 * TILE, 3 * TILE), (0, 0, 0, 0))

def tile_canvas(index):
    x = (index % 8) * TILE
    y = (index // 8) * TILE
    return x, y, ImageDraw.Draw(tiles)

# 0 grass
x, y, d = tile_canvas(0)
d.rectangle((x, y, x + 15, y + 15), fill=C["grass"])
for p in [(2, 4), (11, 2), (7, 12), (14, 9)]:
    px(d, (x + p[0], y + p[1]), C["grass_light"])
    px(d, (x + p[0], y + p[1] + 1), C["grass_dark"])
# 1 detailed grass
x, y, d = tile_canvas(1)
d.rectangle((x, y, x + 15, y + 15), fill=C["grass"])
for p in [(2, 3), (9, 6), (13, 12), (5, 14)]:
    d.line((x + p[0], y + p[1], x + p[0] + 1, y + p[1] - 2), fill=C["grass_light"])
px(d, (x + 4, y + 7), "#f4dd70")
px(d, (x + 5, y + 7), "#f7f1dd")
# 2 path
x, y, d = tile_canvas(2)
d.rectangle((x, y, x + 15, y + 15), fill=C["path"])
for p in [(1, 3), (8, 2), (13, 8), (5, 12), (10, 15)]:
    d.rectangle((x + p[0], y + p[1], x + p[0] + 1, y + p[1]), fill=C["path_dark"])
# 3 plaza stone
x, y, d = tile_canvas(3)
d.rectangle((x, y, x + 15, y + 15), fill=C["stone"])
d.line((x, y + 7, x + 15, y + 7), fill=C["stone_dark"])
d.line((x + 7, y, x + 7, y + 7), fill=C["stone_dark"])
d.line((x + 3, y + 8, x + 3, y + 15), fill=C["stone_dark"])
d.line((x + 12, y + 8, x + 12, y + 15), fill=C["stone_dark"])
# 4 tilled soil
x, y, d = tile_canvas(4)
d.rectangle((x, y, x + 15, y + 15), fill=C["soil"])
for yy in (3, 8, 13):
    d.line((x, y + yy, x + 15, y + yy), fill=C["soil_light"])
# 5 space
x, y, d = tile_canvas(5)
d.rectangle((x, y, x + 15, y + 15), fill=C["space"])
for p, col in [((3, 4), C["white"]), ((12, 11), C["cyan"]), ((8, 2), C["purple"])]:
    px(d, (x + p[0], y + p[1]), col)
# 6 cliff edge
x, y, d = tile_canvas(6)
d.rectangle((x, y, x + 15, y + 5), fill=C["grass"])
d.rectangle((x, y + 6, x + 15, y + 15), fill=C["cliff"])
d.line((x, y + 6, x + 15, y + 6), fill=C["ink"], width=2)
for xx in (2, 8, 13):
    d.line((x + xx, y + 9, x + xx - 1, y + 14), fill="#3f352f")
# 7 landing pad
x, y, d = tile_canvas(7)
d.rectangle((x, y, x + 15, y + 15), fill="#657582")
d.rectangle((x + 1, y + 1, x + 14, y + 14), outline=C["cyan_dark"])
d.line((x + 4, y + 8, x + 11, y + 8), fill=C["cyan"])
# crops 8-11
for index, crop, fruit in [
    (8, "#72a94f", "#d7bf75"),
    (9, "#4f9a48", "#ef7c38"),
    (10, "#4f9a48", "#db4545"),
    (11, "#518d3d", "#7554a5"),
]:
    x, y, d = tile_canvas(index)
    d.rectangle((x, y, x + 15, y + 15), fill=C["soil"])
    for xx in (3, 8, 13):
        d.line((x + xx, y + 13, x + xx, y + 5), fill=crop, width=2)
        d.rectangle((x + xx - 2, y + 5, x + xx + 1, y + 7), fill=crop)
        d.rectangle((x + xx - 1, y + 9, x + xx + 1, y + 11), fill=fruit)
# 12 flowers
x, y, d = tile_canvas(12)
d.rectangle((x, y, x + 15, y + 15), fill=C["grass"])
for xx, yy, col in [(3, 4, "#f5d5dd"), (11, 5, "#f4dd70"), (7, 12, "#9edcf2")]:
    d.line((x + xx, y + yy + 1, x + xx, y + yy + 4), fill=C["grass_dark"])
    d.rectangle((x + xx - 1, y + yy, x + xx + 1, y + yy + 1), fill=col)
# 13 horizontal fence
x, y, d = tile_canvas(13)
d.rectangle((x, y, x + 15, y + 15), fill=C["grass"])
d.rectangle((x, y + 6, x + 15, y + 8), fill=C["wood"])
d.rectangle((x + 2, y + 3, x + 4, y + 13), fill=C["wood_dark"])
d.rectangle((x + 12, y + 3, x + 14, y + 13), fill=C["wood_dark"])
# 14 vertical fence
x, y, d = tile_canvas(14)
d.rectangle((x, y, x + 15, y + 15), fill=C["grass"])
d.rectangle((x + 6, y, x + 8, y + 15), fill=C["wood"])
d.rectangle((x + 3, y + 2, x + 13, y + 4), fill=C["wood_dark"])
d.rectangle((x + 3, y + 12, x + 13, y + 14), fill=C["wood_dark"])
# 15 dark stone
x, y, d = tile_canvas(15)
d.rectangle((x, y, x + 15, y + 15), fill="#464b5c")
d.line((x, y + 7, x + 15, y + 7), fill="#272b3b")
d.line((x + 8, y, x + 8, y + 7), fill="#272b3b")
draw_forest_tiles(tiles)

save(tiles, "terrain_tiles.png")


# --- Standalone object images ---------------------------------------------
object_files = []

def register(name, image):
    save(image, name + ".png")
    object_files.append((name, image.width, image.height))


def shadow(draw, box):
    draw.ellipse(box, fill=(28, 23, 48, 95))


def cottage(name, roof=C["roof"], upper=False):
    w, h = (64, 72) if upper else (64, 56)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shadow(d, (5, h - 14, w - 3, h - 2))
    wall_top = 26 if upper else 24
    outlined_rect(d, (9, wall_top, 55, h - 8), C["cream"])
    if upper:
        outlined_rect(d, (15, 13, 49, 40), "#d8c99e")
        d.rectangle((22, 22, 28, 31), fill=C["blue"], outline=C["ink"])
        d.rectangle((37, 22, 43, 31), fill=C["blue"], outline=C["ink"])
    d.polygon([(4, wall_top + 2), (18, 7), (48, 7), (60, wall_top + 2)], fill=roof, outline=C["ink"])
    d.line((18, 9, 48, 9), fill=C["roof_light"], width=2)
    d.rectangle((17, h - 29, 27, h - 10), fill=C["wood"], outline=C["ink"])
    d.rectangle((38, h - 27, 48, h - 17), fill=C["blue"], outline=C["ink"])
    d.rectangle((47, 12, 53, 25), fill="#6b5b54", outline=C["ink"])
    register(name, im)


def shack():
    im = Image.new("RGBA", (48, 40), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shadow(d, (3, 29, 46, 38))
    outlined_rect(d, (7, 16, 41, 34), "#8c714e")
    d.polygon([(3, 18), (13, 7), (38, 9), (45, 19)], fill="#68503f", outline=C["ink"])
    d.line((11, 21, 39, 19), fill="#b3986a")
    d.rectangle((13, 23, 22, 34), fill=C["wood_dark"], outline=C["ink"])
    register("shack", im)


def modern_building(name, size, base, accent, label, kind):
    register(name, modern_building_art(name, size, base, accent, label, kind, C))


def tree(variant=0):
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shadow(d, (7, 38, 28, 46))
    d.rectangle((14, 27, 19, 42), fill=C["wood_dark"])
    dark = "#2d6038" if variant == 0 else "#355936"
    mid = "#43864a" if variant == 0 else "#527a3f"
    light = "#63a852" if variant == 0 else "#71944c"
    d.polygon([(3, 29), (8, 14), (15, 4), (23, 10), (30, 27), (25, 34), (9, 34)], fill=dark, outline=C["ink"])
    d.rectangle((7, 18, 23, 28), fill=mid)
    d.rectangle((12, 10, 21, 20), fill=light)
    d.rectangle((22, 20, 27, 25), fill=light)
    register("tree" + str(variant + 1), im)


def humanoid(name, tunic, hair, armor=None, player=False):
    im = Image.new("RGBA", (16, 24), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shadow(d, (3, 19, 13, 23))
    skin = "#dca778"
    d.rectangle((5, 3, 10, 9), fill=skin, outline=C["ink"])
    d.rectangle((5, 2, 10, 4), fill=hair)
    body = armor or tunic
    d.rectangle((4, 9, 11, 17), fill=body, outline=C["ink"])
    d.rectangle((3, 10, 4, 15), fill=skin)
    d.rectangle((11, 10, 12, 15), fill=skin)
    d.rectangle((5, 17, 7, 21), fill="#413947")
    d.rectangle((9, 17, 11, 21), fill="#413947")
    if player:
        d.rectangle((12, 9, 13, 18), fill=C["gold"])
        d.rectangle((13, 17, 15, 18), fill=C["white"])
        px(d, (8, 6), C["blue"])
    register(name, im)


def animal(name, size, body, accent, ears=True):
    w, h = size
    im = Image.new("RGBA", size, (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shadow(d, (2, h - 5, w - 2, h - 1))
    d.rectangle((4, h - 11, w - 5, h - 5), fill=body, outline=C["ink"])
    d.rectangle((w - 8, h - 14, w - 3, h - 7), fill=body, outline=C["ink"])
    if ears:
        d.rectangle((w - 7, h - 17, w - 6, h - 13), fill=accent)
        d.rectangle((w - 4, h - 16, w - 3, h - 12), fill=accent)
    px(d, (w - 3, h - 10), C["white"])
    d.rectangle((5, h - 5, 7, h - 2), fill=accent)
    d.rectangle((w - 8, h - 5, w - 6, h - 2), fill=accent)
    register(name, im)


def spaceship():
    im = Image.new("RGBA", (112, 56), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shadow(d, (7, 41, 106, 53))
    d.polygon([(6, 35), (18, 22), (43, 15), (87, 19), (107, 34), (91, 42), (25, 43)], fill="#d8e2df", outline=C["ink"])
    d.polygon([(36, 19), (48, 7), (72, 8), (84, 21)], fill=C["cyan_dark"], outline=C["ink"])
    d.polygon([(45, 18), (51, 10), (68, 11), (76, 19)], fill=C["cyan"])
    d.polygon([(19, 27), (4, 17), (8, 35)], fill=C["orange"], outline=C["ink"])
    d.polygon([(88, 24), (109, 17), (104, 36)], fill=C["gold"], outline=C["ink"])
    d.rectangle((34, 33, 78, 39), fill="#747f89")
    for xx in (43, 57, 71):
        d.rectangle((xx, 34, xx + 4, 37), fill=C["blue"])
    text(d, (56, 26), "CAULIFLOWER", fill=C["ink"], anchor="mm")
    register("spaceship", im)


cottage("cottage_red", C["roof"])
cottage("cottage_blue", C["blue"])
cottage("two_storey", C["roof"], upper=True)
shack()
modern_building("food_shop", (80, 64), C["cyan_dark"], C["cyan"], "FOOD", "wedge")
modern_building("forge", (80, 64), "#7d4a3a", C["orange"], "FORGE", "hex")
modern_building("mercenary", (96, 64), "#4b4f68", C["red"], "MERCENARY", "fort")
modern_building("travel", (112, 72), C["cyan_dark"], C["cyan"], "TRAVEL", "dome")
tree(0); tree(1)
humanoid("player", C["blue"], "#5b392c", player=True)
for i, (tunic, hair) in enumerate([
    ("#9a5e55", "#3d2b29"), ("#567a9b", "#d6ad68"), ("#8570a5", "#4b3027"),
    ("#5f8a56", "#2d2528"), ("#b27a4e", "#744629"), ("#8d596f", "#ded1a1"),
]):
    humanoid("villager" + str(i + 1), tunic, hair)
animal("rabbit", (16, 16), "#d8c8ad", "#a98f80")
animal("wolf", (24, 18), "#727887", "#414554", ears=True)
spaceship()

# Signpost
register("forest_sign", forest_sign())

# Fountain / Cauliflower emblem
im = Image.new("RGBA", (48, 40), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
shadow(d, (4, 29, 44, 38)); d.ellipse((5, 18, 43, 35), fill="#5b8fa8", outline=C["ink"], width=2)
d.ellipse((10, 20, 38, 31), fill="#82cbd0")
d.rectangle((22, 9, 26, 24), fill=C["stone_dark"])
d.ellipse((15, 4, 27, 15), fill=C["white"], outline=C["ink"])
d.ellipse((23, 2, 35, 14), fill=C["white"], outline=C["ink"])
d.ellipse((20, 0, 30, 12), fill="#e8ecd7", outline=C["ink"])
register("fountain", im)

# --- HUD overlay -----------------------------------------------------------
hud = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0)); d = ImageDraw.Draw(hud)
# Top status panel
d.rectangle((8, 7, 183, 36), fill=(18, 17, 29, 225), outline=C["white"], width=1)
d.rectangle((17, 14, 73, 21), fill="#3a2028", outline=C["black"])
d.rectangle((18, 15, 68, 20), fill=C["red"])
text(d, (80, 12), "HP  18 / 20", fill=C["white"])
text(d, (17, 24), "LV 1       GOLD  40", fill=C["gold"])
# Quest panel
d.rectangle((414, 7, 632, 46), fill=(18, 17, 29, 225), outline=C["white"], width=1)
text(d, (424, 12), "ACTIVE JOB", fill=C["gold"])
text(d, (424, 24), "Catch rabbits in the forest", fill=C["white"])
text(d, (424, 35), "2 / 5", fill=C["cyan"])
# Location title
d.rectangle((244, 8, 396, 28), fill=(18, 17, 29, 205), outline=C["gold"])
text(d, (320, 13), "PAPRIKA VILLAGE", fill=C["white"], anchor="ma")
# Interaction prompt
d.rectangle((203, HEIGHT - 27, 437, HEIGHT - 7), fill=(18, 17, 29, 225), outline=C["white"])
text(d, (320, HEIGHT - 23), "[E] TALK     [SPACE] ATTACK", fill=C["white"], anchor="ma")
save(hud, "hud_overlay.png")

# --- Tiled tilesets --------------------------------------------------------
terrain_tsj = {
    "type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
    "name": "paprika_terrain", "tilewidth": 16, "tileheight": 16,
    "tilecount": 24, "columns": 8,
    "image": "../../art/concepts/source/terrain_tiles.png",
    "imagewidth": 128, "imageheight": 48,
}
(MAPS / "terrain.tsj").write_text(json.dumps(terrain_tsj, indent=2))

objects_tiles = []
for idx, (name, w, h) in enumerate(object_files):
    objects_tiles.append({
        "id": idx,
        "image": f"../../art/concepts/source/{name}.png",
        "imagewidth": w,
        "imageheight": h,
    })
objects_tsj = {
    "type": "tileset", "version": "1.10", "tiledversion": "1.12.2",
    "name": "paprika_objects", "tilewidth": 112, "tileheight": 72,
    "tilecount": len(objects_tiles), "columns": 0,
    "objectalignment": "bottomleft",
    "tiles": objects_tiles,
}
(MAPS / "objects.tsj").write_text(json.dumps(objects_tsj, indent=2))

# --- Tiled map -------------------------------------------------------------
G = lambda tile_id: tile_id + 1
base = []
for yy in range(MAP_H):
    for xx in range(MAP_W):
        # A broken diagonal planet edge in the southeast.
        is_space = (yy >= 21 and xx >= 18) or (yy == 20 and xx >= 25) or (yy == 19 and xx >= 34)
        is_cliff = (yy == 20 and 18 <= xx < 25) or (yy == 19 and 25 <= xx < 34) or (yy == 18 and xx >= 34)
        if is_space:
            base.append(G(5))
        elif is_cliff:
            base.append(G(6))
        else:
            base.append(G(1 if random.random() < 0.13 else 0))

paths = [0] * (MAP_W * MAP_H)
def set_tile(layer, x, y, tile_id):
    if 0 <= x < MAP_W and 0 <= y < MAP_H:
        layer[y * MAP_W + x] = G(tile_id)

# Crossroads and plaza.
for x in range(8, 35):
    for y in (10, 11): set_tile(paths, x, y, 2)
for y in range(3, 20):
    for x in (19, 20): set_tile(paths, x, y, 2)
for y in range(8, 15):
    for x in range(16, 24):
        if ((x - 19.5) / 4.5) ** 2 + ((y - 11) / 3.5) ** 2 <= 1:
            set_tile(paths, x, y, 3)
# Branches to services/fields/dock.
for x in range(20, 36): set_tile(paths, x, 16, 2)
for y in range(11, 18): set_tile(paths, 31, y, 2)
for x in range(5, 20): set_tile(paths, x, 16, 2)

farms = [0] * (MAP_W * MAP_H)
for y in range(15, 20):
    for x in range(5, 15):
        crop = [8, 9, 10, 11][(x // 2 + y) % 4]
        set_tile(farms, x, y, crop)
# Private plots.
for y in range(4, 7):
    for x in range(23, 28): set_tile(farms, x, y, 9 if x % 2 else 10)
# Landing pad.
for y in range(17, 20):
    for x in range(29, 36): set_tile(farms, x, y, 7)

name_to_id = {name: idx for idx, (name, _, _) in enumerate(object_files)}
obj_id = 1
objects = []
def add(name, x, y, props=None):
    global obj_id
    _, w, h = object_files[name_to_id[name]]
    item = {
        "id": obj_id, "name": name, "type": "concept_object",
        "gid": 100 + name_to_id[name], "x": x, "y": y,
        "width": w, "height": h, "rotation": 0, "visible": True,
    }
    if props:
        item["properties"] = [{"name": k, "type": "string", "value": v} for k, v in props.items()]
    objects.append(item); obj_id += 1

# Forest wall and clusters.
for x, y, variant in [
    (2, 70, 1), (30, 80, 2), (58, 68, 1), (86, 76, 2),
    (5, 118, 2), (42, 130, 1), (76, 125, 1),
    (8, 176, 1), (48, 188, 2), (82, 180, 1),
    (20, 232, 2), (60, 240, 1), (90, 224, 2),
    (2, 285, 1), (38, 300, 2), (78, 290, 1),
    (570, 74, 2), (604, 100, 1), (584, 145, 2), (612, 190, 1),
]: add("tree" + str(variant), x, y)
add("forest_sign", 92, 185)

# Homes around the square.
for name, x, y in [
    ("cottage_red", 118, 112), ("two_storey", 205, 113),
    ("shack", 120, 208), ("cottage_blue", 208, 232),
    ("cottage_red", 292, 102), ("two_storey", 294, 241),
    ("cottage_blue", 348, 106), ("shack", 358, 230),
]: add(name, x, y)
# Landmark and service buildings.
add("fountain", 296, 198)
add("food_shop", 406, 121)
add("forge", 500, 133)
add("mercenary", 410, 239)
add("travel", 465, 323)
add("spaceship", 512, 350)

# Player and visible villagers. The full game will simulate 50; this single camera view shows a subset.
add("player", 326, 227)
for i, (x, y) in enumerate([
    (277, 183), (353, 184), (253, 246), (370, 260), (439, 173),
    (165, 247), (224, 292), (475, 264), (526, 192), (132, 281),
    (393, 145), (305, 287), (185, 153), (554, 280),
]): add("villager" + str((i % 6) + 1), x, y)
add("rabbit", 105, 210); add("rabbit", 71, 254); add("wolf", 28, 260)

layers = [
    {"id": 1, "name": "Ground", "type": "tilelayer", "width": MAP_W, "height": MAP_H, "x": 0, "y": 0, "opacity": 1, "visible": True, "data": base},
    {"id": 2, "name": "Paths and Plaza", "type": "tilelayer", "width": MAP_W, "height": MAP_H, "x": 0, "y": 0, "opacity": 1, "visible": True, "data": paths},
    {"id": 3, "name": "Fields and Landing Pad", "type": "tilelayer", "width": MAP_W, "height": MAP_H, "x": 0, "y": 0, "opacity": 1, "visible": True, "data": farms},
    {"id": 4, "name": "Buildings Characters and Props", "type": "objectgroup", "draworder": "topdown", "opacity": 1, "visible": True, "x": 0, "y": 0, "objects": objects},
    {"id": 5, "name": "Gameplay HUD", "type": "imagelayer", "image": "../../art/concepts/source/hud_overlay.png", "x": 0, "y": 0, "offsetx": 0, "offsety": 0, "opacity": 1, "visible": True},
]

map_json = {
    "type": "map", "version": "1.10", "tiledversion": "1.12.2",
    "orientation": "orthogonal", "renderorder": "right-down",
    "width": MAP_W, "height": MAP_H, "tilewidth": TILE, "tileheight": TILE,
    "infinite": False, "nextlayerid": 6, "nextobjectid": obj_id,
    "backgroundcolor": C["space"],
    "layers": layers,
    "tilesets": [
        {"firstgid": 1, "source": "terrain.tsj"},
        {"firstgid": 100, "source": "objects.tsj"},
    ],
}
(MAPS / "paprika_first_view.tmj").write_text(json.dumps(map_json, indent=2))

print(f"Created {len(object_files)} object sprites and concept map at {MAPS / 'paprika_first_view.tmj'}")
