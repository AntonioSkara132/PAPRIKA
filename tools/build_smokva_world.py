#!/usr/bin/python3
"""Build Smokva, Krešo's bar on a space rock, from the approved concept (create_smokva_concept.py).

The rock with the yard fills the top of the map; the bar's single room lies in open space
below it, and the world script moves the player between them through the bar's door. Both
are drawn at half size and shown at 2x. The Lasta is not part of the backdrop: the world
script places her on the pad.

Walking is a 16-pixel grid in the "Walls" tile layer (1 = blocked). Points the world script
needs are in the "Markers" layer.

Writes assets/art/smokva/ and maps/smokva*.
"""
from __future__ import annotations

from collections import deque
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

import create_otpornik_ship_art as ship_art
import create_smokva_concept as concept
import create_hacker_designs as hackers  # the sprites; SmokvaWorld.ROUTINES places them
import create_parrot_concept as parrots

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/art/smokva"
MAPS = ROOT / "maps"
CELL = 16
SCALE = 2
OUT_W, OUT_H = concept.W, concept.H
IN_W, IN_H = concept.IW, concept.IH
# The room, in map pixels. The gap keeps the rock out of the camera's view while the
# player is inside (SmokvaWorld.ROOM_RECT must match).
ROOM_AT = (280, OUT_H * SCALE + 192)
ROOM_RECT = (ROOM_AT[0], ROOM_AT[1], ROOM_AT[0] + IN_W * SCALE, ROOM_AT[1] + IN_H * SCALE)
MAP_W = OUT_W * SCALE
MAP_H = ROOM_RECT[3] + 192
W, H = MAP_W // CELL, MAP_H // CELL

# Points outside, at half size.
OUTSIDE_POINTS = {
    "arrival": (124, 202), "respawn": (124, 202),
    "lasta": (96, 194), "veki_post": (58, 202),
    "dock_sign": (66, 124), "bridge": (168, 166), "gate": (210, 166),
    "bar_door": (318, 102), "olive": (262, 206), "swing": (318, 180),
    "fig": (226, 222), "lounge": (418, 166),
}
# Points in the room, at half size from its top left.
ROOM_POINTS = {
    "room_entry": (102, 122), "room_door": (102, 130),
    "bar": (150, 52), "couch": (36, 40), "jukebox": (116, 26),
    "darts": (56, 116), "table_soccer": (48, 72), "wc_door": (184, 60),
    "photo": (72, 28),
}
# Krešo stands behind the counter, out of reach of the walk grid.
KRESO_AT = (150, 32)


def lobe_inset(cx, cy, rx, ry, seed, inset):
    return [(cx + (x - cx) * inset, cy + (y - cy) * inset) for x, y in concept.lobe(cx, cy, rx, ry, seed)]


def outside_walk():
    """Open ground outside: both lobes and the bridge, off the walls, the building, the tree,
    the furniture and the booth."""
    mask = Image.new("L", (OUT_W, OUT_H), 0)
    d = ImageDraw.Draw(mask)
    d.polygon(lobe_inset(86, 174, 80, 82, 1, 0.9), fill=255)
    d.polygon(lobe_inset(300, 150, 168, 134, 2, 0.92), fill=255)
    d.rectangle((140, 160, 204, 172), fill=255)  # the bridge and the gate
    # the dry-stone wall round the yard, open at the gate facing the bridge
    yard = [(204, 178), (198, 206), (206, 236), (236, 258), (270, 268), (304, 264), (334, 272), (372, 262),
            (404, 248), (430, 230), (450, 200), (454, 166), (446, 132), (440, 104), (204, 104), (204, 154)]
    d.line(yard, fill=0, width=6)
    d.line([(376, 134), (378, 160)], fill=0, width=6)
    d.line([(378, 186), (384, 216)], fill=0, width=6)
    x0, y0, x1, y1 = concept.BAR_BOX
    d.rectangle((x0 - 2, y0 - 20, x1 + 2, y1 + 1), fill=0)
    for box in ((426, 64, 448, 90), (408, 78, 428, 101), (386, 54, 409, 79), (182, 70, 200, 82),
                (24, 102, 48, 122), (50, 106, 84, 118), (388, 108, 446, 132), (304, 160, 332, 175),
                (300, 246, 366, 266), (268, 252, 296, 260)):
        d.rectangle(box, fill=0)
    d.ellipse((238, 178, 286, 200), fill=0)  # the olive tree's bed
    for i in range(4):
        cx, cy = 220 + i * 25, y1 + 12 + (i % 2) * 6
        d.rectangle((cx - 9, cy - 4, cx + 9, cy + 8), fill=0)
    for i in range(2):
        cx = 330 + i * 26
        d.rectangle((cx - 9, y1 + 10, cx + 9, y1 + 17), fill=0)
    for x in range(x0 - 4, x1 + 5, 32):  # the terrace columns
        d.rectangle((x - 2, y1 + 31, x + 2, y1 + 37), fill=0)
    for cx, cy in ((312, 214), (348, 200), (290, 236), (350, 228), (402, 148), (430, 152), (408, 180), (432, 196), (404, 206)):
        d.rectangle((cx - 9, cy - 3, cx + 9, cy + 3), fill=0)
    for x, y in ((382, 126), (452, 146), (452, 214), (222, 214)):
        d.rectangle((x - 2, y - 4, x + 2, y), fill=0)
    # the Lasta stands on the pad
    d.rectangle((33, 150, 123, 187), fill=0)
    return mask


def room_walk():
    """The room's floor, off the couch, the bar, the table soccer, the tables, the palms and the dartboard cabinet."""
    mask = Image.new("L", (IN_W, IN_H), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle((7, 21, IN_W - 8, IN_H - 7), fill=255)
    for box in ((6, 18, 66, 34), (112, 18, IN_W - 6, 46), (8, 56, 40, 88), (84, 24, 92, 34), (182, 118, 190, 128),
                (4, 100, 20, 130)):
        d.rectangle(box, fill=0)
    for cx, cy in ((122, 66), (158, 68), (138, 88), (172, 90), (124, 110), (156, 112)):
        d.rectangle((cx - 11, cy - 4, cx + 11, cy + 5), fill=0)
    return mask


def export_art():
    ASSETS.mkdir(parents=True, exist_ok=True)
    concept.exterior(lasta=False).save(ASSETS / "outside.png")
    concept.interior().save(ASSETS / "room.png")
    concept.kreso().save(ASSETS / "kreso.png")
    (ASSETS / "hackers").mkdir(exist_ok=True)
    for draw, _name, _note in hackers.DESIGNS:
        draw().save(ASSETS / "hackers" / f"{draw.__name__}.png")
    # The Purple Parrots wear the gang's feather; Ruff's decoy uses his plain sprite above.
    for draw in (parrots.puffa, parrots.luster, parrots.ruff):
        draw().save(ASSETS / "hackers" / f"parrot_{draw.__name__}.png")
    parrots.donat().save(ASSETS / "donat.png")


def main():
    export_art()
    walk_out = outside_walk()
    walk_in = room_walk()

    full = Image.new("RGBA", (MAP_W // SCALE, MAP_H // SCALE), ship_art.SPACE + (255,))
    fd = ImageDraw.Draw(full)
    for i in range(700):
        x, y = (i * 7919) % full.width, (i * 104729) % full.height
        fd.point((x, y), fill=(ship_art.STAR, ship_art.GLOW, (120, 110, 170))[i % 3])
    full.alpha_composite(Image.open(ASSETS / "outside.png"), (0, 0))
    full.alpha_composite(Image.open(ASSETS / "room.png"), (ROOM_AT[0] // SCALE, ROOM_AT[1] // SCALE))
    full.save(ASSETS / "ground.png")

    walk = [[False] * W for _ in range(H)]

    def open_at(mask, sx, sy):
        return all(0 <= sx + dx < mask.width and 0 <= sy + dy < mask.height and mask.getpixel((sx + dx, sy + dy))
                   for dx, dy in ((0, 0), (-3, 0), (3, 0), (0, -3), (0, 3)))

    for row in range(H):
        for col in range(W):
            x, y = col * CELL + 8, row * CELL + 8
            if y < OUT_H * SCALE:
                walk[row][col] = open_at(walk_out, x // SCALE, y // SCALE)
            elif ROOM_RECT[0] <= x < ROOM_RECT[2] and ROOM_RECT[1] <= y < ROOM_RECT[3]:
                walk[row][col] = open_at(walk_in, (x - ROOM_AT[0]) // SCALE, (y - ROOM_AT[1]) // SCALE)

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

    markers = []

    def marker(name, x, y):
        markers.append(dict(id=0, name=name, type="marker", point=True, x=x, y=y, width=0, height=0, visible=True))

    def place(points, origin, reached):
        for name, (px, py) in points.items():
            x, y = origin[0] + px * SCALE, origin[1] + py * SCALE
            cell = min(reached, key=lambda c: (c[0] * 16 + 8 - x) ** 2 + (c[1] * 16 + 8 - y) ** 2)
            distance = abs(cell[0] * 16 + 8 - x) + abs(cell[1] * 16 + 8 - y)
            assert distance <= 40, f"{name} is {distance}px from walkable ground"
            marker(name, cell[0] * 16 + 8, cell[1] * 16 + 8)

    def region(cells_filter, start_point, origin):
        start = ((origin[0] + start_point[0] * SCALE) // CELL, (origin[1] + start_point[1] * SCALE) // CELL)
        assert walk[start[1]][start[0]], f"{start_point} is blocked"
        reached = flood(start)
        everything = {(c, r) for r in range(H) for c in range(W) if walk[r][c] and cells_filter(r)}
        # Pockets the walls and furniture cut off are closed, so no one walks into them.
        for col, row in everything - reached:
            walk[row][col] = False
        return reached

    outside = region(lambda r: r * CELL < OUT_H * SCALE, OUTSIDE_POINTS["arrival"], (0, 0))
    place(OUTSIDE_POINTS, (0, 0), outside)
    room = region(lambda r: r * CELL >= ROOM_RECT[1], ROOM_POINTS["room_entry"], ROOM_AT)
    place(ROOM_POINTS, ROOM_AT, room)
    door = next(m for m in markers if m["name"] == "bar_door")
    gate_cells = [c for c in outside if abs(c[0] * 16 + 8 - door["x"]) < 40 and abs(c[1] * 16 + 8 - door["y"]) < 40]
    assert gate_cells, "the bar door cannot be reached from outside"
    marker("kreso", ROOM_AT[0] + KRESO_AT[0] * SCALE, ROOM_AT[1] + KRESO_AT[1] * SCALE)
    for name, (x, y) in (("room_rect_origin", ROOM_AT), ("room_rect_end", ROOM_RECT[2:])):
        marker(name, x, y)

    blockers = [0 if walk[y][x] else 1 for y in range(H) for x in range(W)]
    Image.new("RGBA", (16, 16)).save(ASSETS / "collision.png")
    backdrop = dict(id=0, name="ground_backdrop", gid=100, x=0, y=MAP_H, width=MAP_W, height=MAP_H, rotation=0, visible=True)
    tiles = [dict(id=0, image="../assets/art/smokva/ground.png", imagewidth=full.width, imageheight=full.height)]
    layers = [dict(id=1, name="Background", type="objectgroup", objects=[backdrop], visible=True, opacity=1),
              dict(id=2, name="Walls", type="tilelayer", width=W, height=H, x=0, y=0, opacity=1, visible=True, data=blockers),
              dict(id=3, name="Markers", type="objectgroup", objects=markers, visible=True, opacity=1)]
    everything = [backdrop] + markers
    for i, item in enumerate(everything, 1):
        item["id"] = i
    terrain = dict(type="tileset", version="1.10", name="smokva_terrain", tilewidth=16, tileheight=16, tilecount=1, columns=1,
                   image="../assets/art/smokva/collision.png", imagewidth=16, imageheight=16, margin=0, spacing=0)
    objectset = dict(type="tileset", version="1.10", name="smokva_objects", tilewidth=MAP_W, tileheight=MAP_H,
                     tilecount=1, columns=0, tiles=tiles)
    world = dict(type="map", version="1.10", tiledversion="1.11.0", orientation="orthogonal", renderorder="right-down",
                 infinite=False, width=W, height=H, tilewidth=16, tileheight=16, nextlayerid=4, nextobjectid=len(everything) + 1,
                 layers=layers, tilesets=[dict(firstgid=1, source="smokva_terrain.tsj"), dict(firstgid=100, source="smokva_objects.tsj")])
    for name, data in (("smokva.tmj", world), ("smokva_terrain.tsj", terrain), ("smokva_objects.tsj", objectset)):
        (MAPS / name).write_text(json.dumps(data, indent=2) + "\n")
    print(f"Smokva: {W}x{H} tiles, {len(outside)} outside cells, {len(room)} room cells, {len(markers)} markers")
    print("Room rect:", ROOM_RECT)
    for m in markers:
        if m["name"] in ("arrival", "room_entry", "bar_door", "kreso"):
            print(m["name"], m["x"], m["y"])


if __name__ == "__main__":
    main()
