#!/usr/bin/python3
"""Build Bavarin, the Republic base in the desert, from the approved desert concept
(create_bavarin_desert_concept.py).

The map is the concept at 1x, the size the people are drawn at: the canyon with the
Lasta in the southwest, the oasis village in the south, the dunes in the southeast and
the walled base in the north and east. The ground (sand, dunes, roads, the oasis, the
base's concrete, the landing pads) is one backdrop image. Every building, wall piece,
tower, palm, rock and crate is a separate "bavarin_scenery" sprite, sorted by its bottom
edge like the actors, with its footprint cut out of the walk grid.

Changes from the concept for play:
- the people, the Lasta, the two warships, the searchlights and the sandstorm are left
  out; the world script (scripts/world/bavarin_world.gd) places and moves them;
- one piece of the south-east wall is crumbled: that is where the player climbs in;
- the fence and the crates in front of the prison block are gone, so the fight with
  Martin has open ground, and Davor is chained to a post there;
- a few more rocks on the dunes give cover from the sentries.

Walking is a 16-pixel grid in the "Walls" tile layer (1 = blocked). Points the world
script needs are in the "Markers" layer, each moved to the nearest open cell. The
sentries' routes are markers too ("sentry_<n>_<k>"); the build fails if a route crosses
blocked ground.

Writes assets/art/bavarin/ and maps/bavarin*. With --debug it also writes the walk grid
over the map to /dev/shm/bavarin_walk.png.
"""
from __future__ import annotations

from collections import deque
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import create_bavarin_desert_concept as c
from create_otpornik_concept import INK, canvas, box, load_sprite, inside, seg_dist
from create_bavarin_concept import NAVY

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/art/bavarin"
MAPS = ROOT / "maps"
OBJ = ROOT / "assets/art/artichoke/objects"
CELL = 16
MAP_W, MAP_H = c.W, c.H
W, H = MAP_W // CELL, MAP_H // CELL

# The crumbled wall piece, left edge and bottom; the player climbs over it.
BREACH = (1182, 576)
# Where Veki lands the Lasta in the base at the end, top left.
LASTA_LANDING = (744, 410)
# Davor's post in front of the prison block.
POST = (1078, 508)

POINTS = {
    "arrival": (200, 830), "respawn": (200, 830), "veki_post": (150, 832),
    "lasta_spot": (130, 818),
    "villager_0": (545, 776), "villager_1": (585, 836), "villager_2": (470, 716),
    "villager_3": (650, 782), "villager_4": (420, 852), "off_duty": (700, 852),
    "well": (536, 744),
    "gate_guard_0": (758, 594), "gate_guard_1": (818, 594), "gate": (788, 590),
    # Where a spotted player starts again: the edge of the dunes, and inside the wall.
    "dunes_start": (800, 690), "breach_out": (1206, 602), "breach_in": (1206, 540),
    "bomb_flagship": (1052, 170), "bomb_escort": (1190, 182),
    "davor": (1066, 510),
    "fight_player": (1040, 466), "fight_donat": (1012, 488),
    "martin_door": (1180, 496), "martin_stand": (1130, 470),
    # Veki brings the Lasta down south of the parade ground at the end (LASTA_LANDING is its top left).
    "lasta_veki": (900, 540), "lasta_door": (860, 540),
    "wreck": (320, 372), "arch": (420, 484),
}
# Martin's men: four come out of the prison block with him, four from the parade ground.
MEN = [(1140, 500), (1190, 506), (1160, 530), (1108, 520),
       (930, 430), (940, 470), (920, 510), (960, 540)]
# Sentries walk back and forth along these routes, stopping at each end.
SENTRIES = [
    [(860, 616), (1130, 616)],                 # along the outside of the south wall
    [(890, 742), (1250, 742)],                 # across the dunes
    [(986, 652), (986, 872)],                  # up and down the middle of the dunes
    [(1092, 330), (1092, 482)],                # inside: between the mess hall and the armoury
    [(1120, 528), (1262, 528)],                # inside: in front of the prison block
    [(1024, 214), (1024, 318)],                # inside: between the headquarters and the hangar
]

sprites = []  # (bottom, image, x, kind)


def put(sprite, x, bottom, kind="small"):
    if sprite is not None:
        sprites.append((bottom, sprite, x, kind))


def broken_wall(w):
    """A wall piece with its top fallen in and the stones heaped in front: a way over."""
    img = c.wall_piece(w)
    d = ImageDraw.Draw(img)
    d.polygon([(10, 0), (w - 12, 0), (w - 18, 16), (w // 2, 20), (16, 14)], fill=(0, 0, 0, 0))
    d.line([(10, 0), (16, 14), (w // 2, 20), (w - 18, 16), (w - 12, 0)], fill=INK)
    for x, y, s in ((6, 22, 6), (14, 25, 7), (24, 24, 8), (34, 26, 6), (40, 23, 5), (20, 19, 5)):
        d.ellipse((x - s, y - s // 2, x + s, y + s // 2), fill=c.SANDSTONE_SHADE, outline=INK)
    return img


def post():
    """A thick post with an iron ring and a chain hanging off it."""
    img, d = canvas(12, 34)
    box(d, (3, 2, 8, 33), c.WOOD)
    d.line([(5, 4), (5, 31)], fill=c.WOOD_DARK)
    d.ellipse((1, 12, 10, 18), outline=c.STEEL_DARK, width=2)
    for y in range(18, 30, 3):
        d.ellipse((0, y, 3, y + 3), outline=c.STEEL)
    return img


def rock_pile(seed):
    r = random.Random(seed)
    img, d = canvas(34, 22)
    for _ in range(4):
        x, y, s = r.randint(2, 18), r.randint(6, 10), r.randint(8, 12)
        d.ellipse((x, y, x + s + 4, y + s), fill=c.ROCK, outline=INK)
        d.ellipse((x + 2, y + 1, x + s // 2 + 2, y + s // 2), fill=c.ROCK_LIGHT)
    return img


# Martin's men in Tvrdium armor: the Republic guardsman with his steel plate in
# Tvrdium's blue steel (the colour of the Tvrdium armor icon).
TVRDIUM_REMAP = {(132, 144, 160): (110, 150, 174), (190, 200, 212): (168, 206, 224), (58, 64, 76): (52, 78, 96)}


def tvrdium_guard():
    img = load_sprite(OBJ / "republic_guardsman.png")
    img.putdata([TVRDIUM_REMAP.get(p[:3], p[:3]) + (p[3],) if p[3] else p for p in img.getdata()])
    return img


def layout():
    c.rng.seed(23)
    put(c.headquarters(), 760, 200, "building")
    put(c.flagpole(), 820, 300, "pole")
    put(c.prison_block(), 1110, 486, "building")
    put(c.hangar(), 1060, 300, "hangar")
    for x in (1210, 1236):
        put(c.fuel_tank(), x, 300 + (x - 1210), "small")
    put(c.barracks_long(150), 580, 250, "building")
    put(c.barracks_long(130), 580, 360, "building")
    put(load_sprite(OBJ / "republic_barracks_a.png"), 600, 440, "building")
    put(load_sprite(OBJ / "republic_barracks_b.png"), 670, 470, "building")
    put(load_sprite(OBJ / "republic_cafeteria.png"), 960, 400, "building")
    put(load_sprite(OBJ / "republic_weapons_storage.png"), 1150, 380, "building")
    crate = load_sprite(OBJ / "republic_munitions_crate.png")
    for x, y in ((1110, 318), (1250, 420), (870, 216)):
        put(crate, x, y, "small")
    put(load_sprite(OBJ / "republic_tnt_pile.png"), 1240, 456, "small")
    put(load_sprite(OBJ / "republic_cannon.png"), 620, 520, "small")
    for x in range(750, 900, 30):
        put(c.spear_dummy(), x, 380, "small")
    for x in (880, 912, 944):
        put(c.target(), x, 340, "small")
    put(c.weapon_rack(), 900, 384, "small")
    put(post(), *POST, "pole")
    # The south wall, the gate and the crumbled piece.
    for x0, x1, y in ((560, 740, 556), (804, 990, 570), (990, 1272, 576)):
        for x in range(x0, x1, 48):
            w = min(48, x1 - x)
            put(broken_wall(w) if (x, y) == BREACH else c.wall_piece(w), x, y, "breach" if (x, y) == BREACH else "wall")
    put(load_sprite(OBJ / "republic_gate.png"), 740, 560, "gate")
    for x, y in ((520, 560), (540, 300), (540, 120), (990, 586), (1236, 590), (1236, 40), (760, 34), (1000, 36)):
        put(c.watchtower(), x, y, "tower")

    # Dunes, rocks and cover.
    for x, y, s in ((640, 640, 22), (700, 700, 16), (880, 660, 20), (940, 720, 14), (1040, 640, 18), (1200, 700, 24),
                    (480, 600, 18), (360, 500, 20), (280, 420, 16)):
        put(c.boulder(s), x, y, "small")
    for i, (x, y) in enumerate(((870, 704), (1100, 676), (1060, 800), (1170, 840), (920, 820), (1240, 790), (1120, 652))):
        put(rock_pile(40 + i), x, y, "small")
    for x, y in ((560, 700), (820, 776), (1000, 834), (1150, 772), (300, 470), (450, 470), (150, 420), (660, 870)):
        put(c.cactus(), x, y, "small")
    put(c.skull(), 760, 720, "none")
    put(c.wreck(), 300, 360, "wreck")
    put(c.rock_arch(), 380, 480, "arch")
    for x, y in ((240, 420), (420, 380), (200, 520), (470, 280), (330, 300), (110, 470)):
        put(c.dry_bush(), x, y, "none")
    put(c.skull(), 230, 470, "none")
    for x, y, w, h, s in ((-20, 560, 150, 90, 1), (110, 620, 120, 70, 2), (236, 690, 90, 80, 3), (260, 826, 100, 70, 4),
                          (-10, 900, 120, 70, 5), (-20, 380, 140, 90, 6), (160, 280, 130, 80, 7), (360, 220, 110, 70, 8),
                          (20, 240, 100, 70, 9)):
        put(c.mesa(w, h, s), x, y, "mesa")

    # The oasis village.
    put(c.well(), 520, 740, "well")
    put(c.stall(c.CLOTH[0]), 560, 800, "small")
    put(c.stall(c.CLOTH[1]), 600, 760, "small")
    put(c.jars(), 610, 806, "small")
    put(c.camel_cart(), 470, 830, "small")
    for x, y in ((330, 730), (390, 720), (500, 760), (350, 820), (490, 800), (420, 836), (300, 790)):
        put(c.palm(), x, y, "palm")
    taken = [(x, b - s.height * 0.55, x + s.width, b) for b, s, x, _k in sprites]
    paths = c.road_paths()
    keep_clear = [POINTS[k] for k in POINTS if k.startswith(("villager", "off_duty", "well"))]

    def free(x0, y0, x1, y1):
        return all(not (x0 < a[2] and x1 > a[0] and y0 < a[3] and y1 > a[1]) for a in taken)

    def clear(x0, x1, y, pad=6):
        for path, (_, width, _) in zip(paths, c.ROADS):
            for a, b in zip(path, path[1:]):
                for px in (x0, (x0 + x1) / 2, x1):
                    if seg_dist(px, y - 6, a, b) < width / 2 + pad:
                        return False
        return all(not (x0 - 14 < px < x1 + 14 and y - 50 < py < y + 20) for px, py in keep_clear)

    c.rng.seed(29)
    for _ in range(200):
        w = c.rng.choice([34, 40, 46, 52])
        h = c.rng.choice([28, 34, 40])
        ox, bottom = c.rng.uniform(330, 760), c.rng.uniform(640, 890)
        x0, x1, top = ox, ox + w + 8, bottom - (h + 22) * 0.55
        if inside(c.POOL, (x0 + x1) / 2, bottom) or inside(c.BASE, x0, top) or inside(c.CANYON, x0, bottom):
            continue
        if clear(x0, x1, bottom) and free(x0, top - 4, x1, bottom + 4):
            put(c.mud_house(w, h, c.rng.random() < 0.25), ox, bottom, "house")
            taken.append((x0, top, x1, bottom))
    for i, (x, y) in enumerate(((620, 870), (680, 830), (760, 870))):
        put(c.tent(c.CLOTH[i + 1]), x, y, "tent")


# The concept leaves the base's south-west corner open between the west wall's end and
# the south wall; this short stretch of wall closes it.
CORNER = [(590, 470), (562, 548)]


def close_corner(img):
    d = ImageDraw.Draw(img)
    d.line(CORNER, fill=INK, width=12)
    d.line(CORNER, fill=c.SANDSTONE_SHADE, width=9)
    d.line([(x - 2, y - 2) for x, y in CORNER], fill=c.SANDSTONE, width=3)
    (x0, y0), (x1, y1) = CORNER
    n = int(math.hypot(x1 - x0, y1 - y0) // 10)
    for k in range(n):
        x, y = x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n
        d.rectangle((x - 2, y - 7, x + 2, y - 3), fill=c.SANDSTONE, outline=INK)


def footprint(kind, x, bottom, w, h):
    """The ground a sprite stands on, blocked for walking."""
    if kind == "none":
        return None
    if kind == "building":
        return (x + 3, bottom - min(h * 0.5, 56), x + w - 3, bottom)
    if kind == "hangar":
        return (x + 3, bottom - h * 0.9, x + w - 3, bottom)
    if kind == "house":
        return (x + 4, bottom - min(h * 0.5, 30), x + w - 4, bottom)
    if kind in ("wall", "breach", "gate"):
        return (x, bottom - 16, x + w, bottom)
    if kind == "tower":
        return (x + 8, bottom - 16, x + 36, bottom)
    if kind == "palm":
        return (x + 16, bottom - 6, x + 24, bottom)
    if kind == "pole":
        return (x + 2, bottom - 5, x + 10, bottom)
    if kind == "mesa":
        return (x + 6, bottom - h * 0.8, x + w - 6, bottom - 2)
    if kind == "well":
        return (x + 2, bottom - 16, x + w - 2, bottom)
    if kind == "tent":
        return (x + 4, bottom - 14, x + w - 4, bottom)
    if kind == "wreck":
        return (x + 10, bottom - 22, x + w - 10, bottom - 4)
    if kind == "arch":
        return [(x + 4, bottom - 20, x + 22, bottom), (x + 58, bottom - 20, x + 76, bottom)]
    return (x + 2, bottom - min(h * 0.4, 14), x + w - 2, bottom)


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    tvrdium_guard().save(ASSETS / "tvrdium_guard.png")
    for old in ASSETS.glob("sprite_*.png"):
        old.unlink()
    ground = Image.new("RGBA", (MAP_W, MAP_H), (0, 0, 0, 255))
    c.rng.seed(23)
    c.ground(ground)
    close_corner(ground)
    layout()

    mask = Image.new("L", (MAP_W, MAP_H), 255)
    md = ImageDraw.Draw(mask)
    md.polygon(c.wobble(c.RIDGE, amount=8, seed=2), fill=0)
    md.polygon(c.POOL, fill=0)
    edge = c.BASE[-3:] + c.BASE[:5]
    md.line(edge, fill=0, width=14, joint="curve")
    md.line(CORNER, fill=0, width=14)
    # The east side of the base runs to the map's edge.
    md.rectangle((1272, 0, MAP_W, 580), fill=0)
    # The two warships stand on the pads (placed by the world script).
    md.rectangle((996, 132, 1108, 150), fill=0)
    md.rectangle((1154, 148, 1226, 164), fill=0)
    # The Lasta in the canyon (placed by the world script).
    md.rectangle((44, 788, 216, 802), fill=0)

    objects, tiles, images = [], [], {}

    def gid(name, img):
        if name not in images:
            images[name] = len(images) + 100
            img.save(ASSETS / name)
            tiles.append(dict(id=len(images) - 1, image=f"../assets/art/bavarin/{name}", imagewidth=img.width, imageheight=img.height))
        return images[name]

    def obj(name, image_name, img, x, bottom):
        objects.append(dict(id=0, name=name, gid=gid(image_name, img), x=x, y=bottom, width=img.width, height=img.height, rotation=0, visible=True))

    obj("ground_backdrop", "ground.png", ground, 0, MAP_H)
    sprites.sort(key=lambda s: s[0])
    for index, (bottom, sprite, x, kind) in enumerate(sprites):
        obj("bavarin_scenery", f"sprite_{index:03d}.png", sprite, round(x), round(bottom))
        rect = footprint(kind, x, bottom, sprite.width, sprite.height)
        for r in (rect if isinstance(rect, list) else [rect] if rect else []):
            md.rectangle(r, fill=0)

    walk = [[False] * W for _ in range(H)]
    for row in range(H):
        for col in range(W):
            x, y = col * CELL + 8, row * CELL + 8
            walk[row][col] = 0 < col < W - 1 and 0 < row < H - 1 and all(
                mask.getpixel((min(MAP_W - 1, max(0, x + dx)), min(MAP_H - 1, max(0, y + dy))))
                for dx, dy in ((0, 0), (-4, 0), (4, 0), (0, -4), (0, 4)))

    def flood(start):
        seen = {start}
        todo = deque([start])
        while todo:
            x, y = todo.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if (nx, ny) not in seen and 0 <= nx < W and 0 <= ny < H and walk[ny][nx]:
                    seen.add((nx, ny))
                    todo.append((nx, ny))
        return seen

    def cell_of(p):
        return (int(p[0]) // CELL, int(p[1]) // CELL)

    outside_start = cell_of(POINTS["arrival"])
    inside_start = cell_of(POINTS["breach_in"])
    assert walk[outside_start[1]][outside_start[0]], "arrival is blocked"
    assert walk[inside_start[1]][inside_start[0]], "breach_in is blocked"
    outside = flood(outside_start)
    inside_base = flood(inside_start)
    if outside & inside_base and "--debug" in sys.argv:
        prev = {outside_start: None}
        todo = deque([outside_start])
        while todo:
            q = todo.popleft()
            if q == inside_start:
                break
            for n in ((q[0] - 1, q[1]), (q[0] + 1, q[1]), (q[0], q[1] - 1), (q[0], q[1] + 1)):
                if n not in prev and 0 <= n[0] < W and 0 <= n[1] < H and walk[n[1]][n[0]]:
                    prev[n] = q
                    todo.append(n)
        q, route = inside_start, []
        while q is not None:
            route.append((q[0] * 16 + 8, q[1] * 16 + 8))
            q = prev[q]
        SENTRIES.append(route[::-1])
        print("LEAK", route[::-1])
    if outside & inside_base and "--debug" not in sys.argv:
        raise AssertionError("the base can be walked into without climbing the wall")
    reached = outside | inside_base
    for row in range(H):
        for col in range(W):
            if walk[row][col] and (col, row) not in reached:
                walk[row][col] = False

    markers = []

    def marker(name, x, y):
        markers.append(dict(id=0, name=name, type="marker", point=True, x=x, y=y, width=0, height=0, visible=True))

    def in_base(p):
        return p[1] < 560 and p[0] > 560 or inside(c.BASE, *p)

    def snap(name, p, limit=40):
        cells = inside_base if (in_base(p) and name not in ("breach_out",) and not name.startswith("gate")) else outside
        cell = min(cells, key=lambda q: (q[0] * 16 + 8 - p[0]) ** 2 + (q[1] * 16 + 8 - p[1]) ** 2)
        distance = abs(cell[0] * 16 + 8 - p[0]) + abs(cell[1] * 16 + 8 - p[1])
        if distance > limit:
            if "--debug" not in sys.argv:
                raise AssertionError(f"{name} is {distance}px from open ground")
            print(f"WARNING {name} is {distance}px from open ground")
        return cell[0] * 16 + 8, cell[1] * 16 + 8

    for name, p in POINTS.items():
        if name in ("davor",):
            marker(name, *p)  # Davor stands at his post; the world script blocks nothing there.
            continue
        marker(name, *snap(name, p))
    for i, p in enumerate(MEN):
        marker(f"man_{i}", *snap(f"man_{i}", p))
    for i, route in enumerate(SENTRIES):
        for k, (a, b) in enumerate(zip(route, route[1:])):
            steps = int(math.dist(a, b) // 4)
            for s in range(steps + 1):
                px, py = a[0] + (b[0] - a[0]) * s / steps, a[1] + (b[1] - a[1]) * s / steps
                col, row = cell_of((px, py))
                if not walk[row][col]:
                    if "--debug" not in sys.argv:
                        raise AssertionError(f"sentry {i} route is blocked at {px:.0f},{py:.0f}")
                    print(f"WARNING sentry {i} route is blocked at {px:.0f},{py:.0f}")
                    break
        for k, p in enumerate(route):
            marker(f"sentry_{i}_{k}", *p)
    marker("post", *POST)
    marker("lasta_landing", *LASTA_LANDING)
    marker("breach", *BREACH)

    blockers = [0 if walk[y][x] else 1 for y in range(H) for x in range(W)]
    Image.new("RGBA", (16, 16)).save(ASSETS / "collision.png")
    layers = [dict(id=1, name="Background", type="objectgroup", objects=[o for o in objects if o["name"] == "ground_backdrop"], visible=True, opacity=1),
              dict(id=2, name="Walls", type="tilelayer", width=W, height=H, x=0, y=0, opacity=1, visible=True, data=blockers),
              dict(id=3, name="Base", type="objectgroup", objects=[o for o in objects if o["name"] != "ground_backdrop"], visible=True, opacity=1, draworder="topdown"),
              dict(id=4, name="Markers", type="objectgroup", objects=markers, visible=True, opacity=1)]
    everything = [o for layer in layers if layer["type"] == "objectgroup" for o in layer["objects"]]
    for i, item in enumerate(everything, 1):
        item["id"] = i
    terrain = dict(type="tileset", version="1.10", name="bavarin_terrain", tilewidth=16, tileheight=16, tilecount=1, columns=1,
                   image="../assets/art/bavarin/collision.png", imagewidth=16, imageheight=16, margin=0, spacing=0)
    objectset = dict(type="tileset", version="1.10", name="bavarin_objects", tilewidth=MAP_W, tileheight=MAP_H,
                     tilecount=len(tiles), columns=0, tiles=tiles)
    world = dict(type="map", version="1.10", tiledversion="1.11.0", orientation="orthogonal", renderorder="right-down",
                 infinite=False, width=W, height=H, tilewidth=16, tileheight=16, nextlayerid=5, nextobjectid=len(everything) + 1,
                 layers=layers, tilesets=[dict(firstgid=1, source="bavarin_terrain.tsj"), dict(firstgid=100, source="bavarin_objects.tsj")])
    for name, data in (("bavarin.tmj", world), ("bavarin_terrain.tsj", terrain), ("bavarin_objects.tsj", objectset)):
        (MAPS / name).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Bavarin: {W}x{H} tiles, {len(objects)} objects, {len(outside)} outside cells, {len(inside_base)} base cells, {len(markers)} markers")

    if "--debug" in sys.argv:
        view = ground.copy()
        for bottom, sprite, x, _k in sprites:
            view.alpha_composite(sprite, (int(x), int(bottom - sprite.height)))
        layer = Image.new("RGBA", view.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for row in range(H):
            for col in range(W):
                if not walk[row][col]:
                    ld.rectangle((col * 16, row * 16, col * 16 + 15, row * 16 + 15), fill=(200, 0, 0, 70))
        for route in SENTRIES:
            ld.line(route, fill=(0, 0, 255, 255), width=2)
        for m in markers:
            ld.ellipse((m["x"] - 3, m["y"] - 3, m["x"] + 3, m["y"] + 3), fill=(0, 255, 0, 255))
            ld.text((m["x"] + 4, m["y"] - 4), m["name"], fill=(0, 0, 0, 255))
        view.alpha_composite(layer)
        view.convert("RGB").save("/dev/shm/bavarin_walk.png")


if __name__ == "__main__":
    main()
