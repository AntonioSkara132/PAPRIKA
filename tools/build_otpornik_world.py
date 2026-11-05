#!/usr/bin/python3
"""Build Otpornik's Tiled map from the approved concept and the Lasta's floors.

The port, town, beach and university terrace come from
tools/create_otpornik_concept.py: its ground is the map's backdrop at 2x, and
each building, tree and ship is a separate object so actors sort in front of
and behind it. The university is scenery only; nothing there can be entered.

The pad-1 ship of the concept is replaced by the Lasta, the old ship the
party buys. Its three floors (top deck, upper floor, lower floor) from
tools/create_otpornik_ship_art.py sit in open space below the port, outside
the planet's walkable ground, and the world script moves the party between
them.

Walking is a 16-pixel grid in the "Walls" tile layer (1 = blocked). Points the
world script needs are in the "Markers" layer.
"""
from __future__ import annotations

from collections import deque
import json
from pathlib import Path

from PIL import Image, ImageDraw

import create_otpornik_concept as art
import create_otpornik_ship_art as ship_art

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/art/otpornik"
MAPS = ROOT / "maps"
CELL = 16
SCALE = 2
PORT_W, PORT_H = art.W * SCALE, art.H * SCALE
# The Lasta's floors, in map pixels: origin and the size of the 2x room image.
# The gaps are wide enough that the camera, limited to one floor, never shows
# another floor or the port's edge (OtpornikWorld.ROOM_RECTS must match).
ROOM_Y = PORT_H + 192
ROOMS = {"ship_deck": (64, ROOM_Y), "ship_upper": (960, ROOM_Y), "ship_lower": (1856, ROOM_Y)}
MAP_W, MAP_H = PORT_W, ROOM_Y + 288 + 192
W, H = MAP_W // CELL, MAP_H // CELL
# The concept's pad-1 ship; the Lasta stands there instead.
PAD_ONE_SHIP = (722, 680)
LASTA_SIZE = (220, 112)
FLYING_SHIPS = {(938, 628), (1058, 852)}

# Concept functions whose sprites get their own collision shape.
KINDS = ["twin_towers", "old_hall", "glass_lab", "observatory", "library", "department", "walking_robot",
         "clock_post", "tree", "lamp", "townhouse", "cafe", "bookshop", "fountain", "market_stall", "spaceship",
         "broker_office", "repair_shed", "passenger_dock", "cargo", "gantry", "control_tower", "fuel_tanks",
         "palm", "umbrella", "towel", "beach_hut", "beach_bar", "lifeguard", "sandcastle", "pier", "rowboat",
         "rock", "fish_hut", "garden_wall"]
# Sprites the party walks through: flat on the ground or over open space.
NO_COLLISION = {"towel", "pier", "rowboat", "walking_robot"}

# Residents, at spots from the concept's people list (concept pixels) with an
# Iskra NPC sprite each; the world script gives them their lines.
RESIDENTS = [("civic_engineer", 230, 240), ("library_archivist", 480, 210), ("park_artist", 600, 262),
             ("market_keeper", 800, 330), ("greenhouse_worker", 1060, 420), ("canal_worker", 980, 252),
             ("board_officer", 520, 500), ("park_artist", 290, 680), ("market_keeper", 430, 722),
             ("dock_mechanic", 960, 668), ("canal_worker", 1060, 640), ("greenhouse_worker", 150, 620)]

# Port points the world script needs, in concept pixels.
PORT_POINTS = {
    "arrival": (1196, 572), "respawn": (1196, 572), "terminal": (1160, 574),
    "broker": (942, 612), "foreman": (676, 700), "porter": (566, 392),
    "lasta": (PAD_ONE_SHIP[0] + 66, 690),
    "veki_ship": (812, 700), "davor_ship": (760, 700),
    "scavenger_0": (640, 774), "scavenger_1": (700, 784), "scavenger_2": (760, 790),
    "scavenger_3": (820, 792), "scavenger_4": (668, 750), "scavenger_5": (884, 790),
    "yard_watch": (720, 740),
}


def tagged_build():
    originals = {name: getattr(art, name) for name in KINDS}

    def tag(name, fn):
        def draw(*args, **kwargs):
            image = fn(*args, **kwargs)
            image.info["kind"] = name
            return image
        return draw
    for name, fn in originals.items():
        setattr(art, name, tag(name, fn))
    try:
        return art.build(game=True)
    finally:
        for name, fn in originals.items():
            setattr(art, name, fn)


def footprint(kind, x, bottom, w, h):
    """The rectangle a sprite blocks, in concept pixels: its base, not its roof."""
    if kind in NO_COLLISION:
        return None
    cx = x + w / 2
    if kind in ("tree", "palm"):
        return (cx - 3, bottom - 6, cx + 3, bottom)
    if kind in ("lamp", "clock_post", "umbrella"):
        return (cx - 2, bottom - 3, cx + 2, bottom)
    if kind in ("sandcastle", "rock", "cargo"):
        return (x + 1, bottom - h * .5, x + w - 1, bottom)
    if kind == "fountain":
        return (x + w * .12, bottom - 12, x + w * .88, bottom)
    if kind == "spaceship":
        return (x + w * .16, bottom - 7, x + w * .84, bottom)
    if kind == "gantry":
        return (x, bottom - 16, x + w, bottom)
    if kind == "garden_wall":
        return (x, bottom - 6, x + w, bottom)
    depth = min(h * .3, 26)
    return (x + 3, bottom - depth, x + w - 3, bottom)


def main():
    rooms = ship_art.export()
    ground, sprites = tagged_build()
    ASSETS.mkdir(parents=True, exist_ok=True)
    walk_mask = Image.new("L", (art.W, art.H), 255)
    md = ImageDraw.Draw(walk_mask)
    sea = art.wobble(art.SEA_SHAPE[:-2], amount=5, seed=9) + art.SEA_SHAPE[-2:]
    md.polygon(sea, fill=0)
    md.line(sea[:-2], fill=0, width=10)
    # The terrace's retaining wall is a step down; only the stairs cross it.
    face = [(x, y + 18) for x, y in art.TERRACE_SHAPE]
    md.polygon(face, fill=0)
    md.polygon(art.TERRACE_SHAPE, fill=255)
    md.line(art.TERRACE_SHAPE + art.TERRACE_SHAPE[:1], fill=0, width=3)
    md.polygon([(516, 344), (604, 334), (650, 372), (560, 386)], fill=255)

    objects, tiles, images = [], [], {}

    def gid(image_name):
        if image_name not in images:
            images[image_name] = len(images) + 100
            w, h = Image.open(ASSETS / image_name).size
            tiles.append(dict(id=len(images) - 1, image=f"../assets/art/otpornik/{image_name}", imagewidth=w, imageheight=h))
        return images[image_name]

    def obj(name, image_name, x, bottom, width, height):
        objects.append(dict(id=0, name=name, gid=gid(image_name), x=x, y=bottom, width=width, height=height, rotation=0, visible=True))

    # The ground and the open space round the ship's floors.
    void = Image.new("RGBA", (art.W, MAP_H // SCALE - art.H), ship_art.SPACE + (255,))
    vd = ImageDraw.Draw(void)
    for i in range(500):
        x, y = (i * 7919) % void.width, (i * 104729) % void.height
        vd.point((x, y), fill=(ship_art.STAR, ship_art.GLOW, (120, 110, 170))[i % 3])
    full = Image.new("RGBA", (art.W, MAP_H // SCALE))
    full.alpha_composite(ground.convert("RGBA"), (0, 0))
    full.alpha_composite(void, (0, art.H))
    full.save(ASSETS / "ground.png")
    obj("ground_backdrop", "ground.png", 0, MAP_H, MAP_W, MAP_H)

    for index, (bottom, sprite, x, label, label_y) in enumerate(sprites):
        kind = sprite.info.get("kind", "decoration")
        if kind == "spaceship" and (round(x), round(bottom)) == PAD_ONE_SHIP:
            continue
        if label:
            # A label inside the sprite is painted on it; one below it goes on the ground.
            label_img = Image.new("RGBA", (art.W, art.H))
            art.sign(label_img, int(x + sprite.width // 2), label_y, label)
            box = label_img.getbbox()
            if box and box[3] <= bottom and box[1] >= bottom - sprite.height:
                sprite = sprite.copy()
                sprite.alpha_composite(label_img.crop((int(x), int(bottom - sprite.height), int(x) + sprite.width, int(bottom))))
            else:
                full.alpha_composite(label_img)
        name = f"sprite_{index:03d}.png"
        sprite.save(ASSETS / name)
        obj("otpornik_scenery", name, x * SCALE, bottom * SCALE, sprite.width * SCALE, sprite.height * SCALE)
        # Ships taking off over pad 2 and the platform have nothing on the ground.
        hovering = kind == "spaceship" and (round(x), round(bottom)) in FLYING_SHIPS
        rect = None if hovering else footprint(kind, x, bottom, sprite.width, sprite.height)
        if rect:
            md.rectangle(rect, fill=0)
    full.save(ASSETS / "ground.png")

    # The Lasta on pad 1, at map scale so it matches its floors.
    lx = PAD_ONE_SHIP[0] * SCALE + (120 * SCALE - LASTA_SIZE[0]) // 2
    lb = PAD_ONE_SHIP[1] * SCALE
    obj("otpornik_scenery", "lasta.png", lx, lb, *LASTA_SIZE)
    md.rectangle(((lx + 24) / SCALE, (lb - 14) / SCALE, (lx + 196) / SCALE, lb / SCALE), fill=0)

    walk = [[False] * W for _ in range(H)]
    for row in range(art.H * SCALE // CELL):
        for col in range(W):
            x, y = col * 8 + 4, row * 8 + 4
            walk[row][col] = all(walk_mask.getpixel((min(art.W - 1, max(0, x + dx)), min(art.H - 1, max(0, y + dy))))
                                 for dx, dy in ((0, 0), (-3, 0), (3, 0), (0, -3), (0, 3)))

    def flood(start, allowed):
        seen = {start}
        todo = deque([start])
        while todo:
            x, y = todo.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if (nx, ny) not in seen and allowed(nx, ny):
                    seen.add((nx, ny))
                    todo.append((nx, ny))
        return seen

    markers = []

    def marker(name, x, y):
        markers.append(dict(id=0, name=name, type="marker", point=True, x=x, y=y, width=0, height=0, visible=True))

    def nearest(cells, x, y):
        return min(cells, key=lambda c: (c[0] * 16 + 8 - x) ** 2 + (c[1] * 16 + 8 - y) ** 2)

    arrival = (PORT_POINTS["arrival"][0] * SCALE // CELL, PORT_POINTS["arrival"][1] * SCALE // CELL)
    assert walk[arrival[1]][arrival[0]], "arrival is blocked"
    reached = flood(arrival, lambda x, y: 0 <= x < W and 0 <= y < H and walk[y][x])
    for name, (x, y) in PORT_POINTS.items():
        cell = nearest(reached, x * SCALE, y * SCALE)
        distance = abs(cell[0] * 16 + 8 - x * SCALE) + abs(cell[1] * 16 + 8 - y * SCALE)
        assert distance <= 64, f"{name} is {distance}px from reachable ground"
        marker(name, cell[0] * 16 + 8, cell[1] * 16 + 8)
    for i, (role, x, y) in enumerate(RESIDENTS):
        cell = nearest(reached, x * SCALE, y * SCALE)
        image = f"npc_{role}.png"
        source = Image.open(ROOT / f"assets/art/iskra/npcs/{role}.png")
        source.save(ASSETS / image)
        obj(f"story_resident_{i}", image, cell[0] * 16 + 8 - source.width / 2, cell[1] * 16 + 10, source.width, source.height)

    # The Lasta's floors.
    for room, (ox, oy) in ROOMS.items():
        info = rooms[room]
        img = Image.open(ASSETS / f"{room}.png")
        obj("ground_backdrop", f"{room}.png", ox, oy + img.height * SCALE, img.width * SCALE, img.height * SCALE)
        x0, y0, x1, y1 = info["walk"]
        cells = set()
        for row in range(H):
            for col in range(W):
                sx, sy = (col * 16 + 8 - ox) / SCALE, (row * 16 + 8 - oy) / SCALE
                if not (x0 <= sx <= x1 and y0 <= sy <= y1):
                    continue
                # A cell is blocked when furniture covers most of it.
                if any(bx0 <= sx + dx <= bx1 and by0 <= sy + dy <= by1 for bx0, by0, bx1, by1 in info.get("blocked", [])
                       for dx, dy in ((0, 0),)):
                    continue
                walk[row][col] = True
                cells.add((col, row))
        names = [k for k in info if k not in ("walk", "blocked")]
        first = nearest(cells, ox + info[names[0]][0] * SCALE, oy + info[names[0]][1] * SCALE)
        room_cells = flood(first, lambda x, y: (x, y) in cells)
        for name in names:
            px, py = ox + info[name][0] * SCALE, oy + info[name][1] * SCALE
            if name == "machine":
                # Top-left corner of the animated drive sprite, not a place to stand.
                marker(f"{room}_{name}", px, py)
                continue
            cell = nearest(room_cells, px, py)
            distance = abs(cell[0] * 16 + 8 - px) + abs(cell[1] * 16 + 8 - py)
            assert distance <= 48, f"{room}_{name} is {distance}px from the room's floor"
            marker(f"{room}_{name}", cell[0] * 16 + 8, cell[1] * 16 + 8)
        unreachable = cells - room_cells
        assert not unreachable, f"{room}: {len(unreachable)} floor cells cut off"

    blockers = [0 if walk[y][x] else 1 for y in range(H) for x in range(W)]
    Image.new("RGBA", (16, 16)).save(ASSETS / "collision.png")
    layers = [dict(id=1, name="Background", type="objectgroup", objects=[o for o in objects if o["name"] == "ground_backdrop"], visible=True, opacity=1),
              dict(id=2, name="Walls", type="tilelayer", width=W, height=H, x=0, y=0, opacity=1, visible=True, data=blockers),
              dict(id=3, name="Town", type="objectgroup", objects=[o for o in objects if o["name"] != "ground_backdrop"], visible=True, opacity=1, draworder="topdown"),
              dict(id=4, name="Markers", type="objectgroup", objects=markers, visible=True, opacity=1)]
    everything = [o for layer in layers if layer["type"] == "objectgroup" for o in layer["objects"]]
    for i, item in enumerate(everything, 1):
        item["id"] = i
    terrain = dict(type="tileset", version="1.10", name="otpornik_terrain", tilewidth=16, tileheight=16, tilecount=1, columns=1,
                   image="../assets/art/otpornik/collision.png", imagewidth=16, imageheight=16, margin=0, spacing=0)
    objectset = dict(type="tileset", version="1.10", name="otpornik_objects", tilewidth=MAP_W, tileheight=MAP_H,
                     tilecount=len(tiles), columns=0, tiles=tiles)
    world = dict(type="map", version="1.10", tiledversion="1.11.0", orientation="orthogonal", renderorder="right-down",
                 infinite=False, width=W, height=H, tilewidth=16, tileheight=16, nextlayerid=5, nextobjectid=len(everything) + 1,
                 layers=layers, tilesets=[dict(firstgid=1, source="otpornik_terrain.tsj"), dict(firstgid=100, source="otpornik_objects.tsj")])
    for name, data in (("otpornik.tmj", world), ("otpornik_terrain.tsj", terrain), ("otpornik_objects.tsj", objectset)):
        (MAPS / name).write_text(json.dumps(data, indent=2) + "\n")
    arrival_marker = next(m for m in markers if m["name"] == "arrival")
    print(f"Otpornik: {W}x{H} tiles, {len(objects)} objects, {len(reached)} reachable port cells, {len(markers)} markers")
    print("Arrival:", arrival_marker["x"], arrival_marker["y"])


if __name__ == "__main__":
    main()
