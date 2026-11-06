#!/usr/bin/python3
"""Build the Tiled map of R-7, the space rock, from tools/create_space_rock_art.py.

The surface fills the top of the map; the cave lies in open space below it,
outside the surface's walkable ground, and the world script moves the player
between them. Both are drawn at half size and shown at 2x. The ships are not
on the map: the world script places the Lasta and Martin's ship, since both
land and leave during the chapter.

Walking is a 16-pixel grid in the "Walls" tile layer (1 = blocked). Points the
world script needs are in the "Markers" layer.
"""
from __future__ import annotations

from collections import deque
import json
from pathlib import Path

from PIL import Image, ImageDraw

import create_otpornik_ship_art as ship_art
import create_space_rock_art as art

ROOT = Path(__file__).resolve().parents[1]
ASSETS = art.OUT
MAPS = ROOT / "maps"
CELL = 16
SCALE = 2
SURFACE_RECT = (0, 0, art.SURFACE_W * SCALE, art.SURFACE_H * SCALE)
# The cave, in map pixels. The gap keeps the surface out of the camera's view
# while the player is in the cave (SpaceRockWorld.CAVE_RECT must match).
CAVE_AT = (192, art.SURFACE_H * SCALE + 192)
CAVE_RECT = (CAVE_AT[0], CAVE_AT[1], CAVE_AT[0] + art.CAVE_W * SCALE, CAVE_AT[1] + art.CAVE_H * SCALE)
MAP_W = art.SURFACE_W * SCALE
MAP_H = CAVE_RECT[3] + 192 + 8
W, H = MAP_W // CELL, MAP_H // CELL

# Points on the surface, at half size.
SURFACE_POINTS = {
    "arrival": (112, 236), "respawn": (112, 236),
    "lasta": (96, 228), "veki_post": (76, 232),
    "cave_mouth": (232, 88), "raid_trigger": (232, 104),
    "davor_taken": (244, 104), "martin": (278, 116),
    "martin_ramp": (350, 192),
    "raider_0": (330, 198), "raider_1": (372, 196), "raider_2": (300, 192),
    "raider_3": (416, 176), "raider_4": (176, 132), "raider_5": (250, 204),
    "raider_6": (150, 200), "raider_7": (390, 220),
    "wake": (226, 112),
    "sign": (232, 96),
}
# Points in the cave, at half size from its top left.
CAVE_POINTS = {
    "cave_entry": (26, 152), "cave_wake": (62, 124), "camp": (104, 108), "triangle": (48, 118),
    "grave": (228, 102), "voice": (228, 98),
}


def main():
    art.export()
    walk_surface = art.surface_walk()
    walk_cave = art.cave_walk()

    # One backdrop: the surface, open space with stars, and the dark cave.
    full = Image.new("RGBA", (MAP_W // SCALE, MAP_H // SCALE), ship_art.SPACE + (255,))
    fd = ImageDraw.Draw(full)
    for i in range(700):
        x, y = (i * 7919) % full.width, (i * 104729) % full.height
        fd.point((x, y), fill=(ship_art.STAR, ship_art.GLOW, (120, 110, 170))[i % 3])
    full.alpha_composite(Image.open(ASSETS / "surface.png"), (0, 0))
    full.alpha_composite(Image.open(ASSETS / "cave_dark.png"), (CAVE_AT[0] // SCALE, CAVE_AT[1] // SCALE))
    full.save(ASSETS / "ground.png")

    walk = [[False] * W for _ in range(H)]

    def open_at(mask, sx, sy):
        return all(0 <= sx + dx < mask.width and 0 <= sy + dy < mask.height and mask.getpixel((sx + dx, sy + dy))
                   for dx, dy in ((0, 0), (-3, 0), (3, 0), (0, -3), (0, 3)))

    for row in range(H):
        for col in range(W):
            x, y = col * CELL + 8, row * CELL + 8
            if y < SURFACE_RECT[3]:
                walk[row][col] = open_at(walk_surface, x // SCALE, y // SCALE)
            elif CAVE_RECT[0] <= x < CAVE_RECT[2] and CAVE_RECT[1] <= y < CAVE_RECT[3]:
                walk[row][col] = open_at(walk_cave, (x - CAVE_AT[0]) // SCALE, (y - CAVE_AT[1]) // SCALE)

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
            assert distance <= 48, f"{name} is {distance}px from walkable ground"
            marker(name, cell[0] * 16 + 8, cell[1] * 16 + 8)

    arrival = (SURFACE_POINTS["arrival"][0] * SCALE // CELL, SURFACE_POINTS["arrival"][1] * SCALE // CELL)
    assert walk[arrival[1]][arrival[0]], "arrival is blocked"
    surface_cells = flood(arrival)
    surface_all = {(c, r) for r in range(H) for c in range(W) if walk[r][c] and r * CELL < SURFACE_RECT[3]}
    cut_off = surface_all - surface_cells
    # Pockets cut off by the ridges and boulders are closed, so no one walks into them.
    for col, row in cut_off:
        walk[row][col] = False
    place(SURFACE_POINTS, (0, 0), surface_cells)

    entry = ((CAVE_AT[0] + CAVE_POINTS["cave_entry"][0] * SCALE) // CELL, (CAVE_AT[1] + CAVE_POINTS["cave_entry"][1] * SCALE) // CELL)
    if not walk[entry[1]][entry[0]]:
        entry = min(((c, r) for r in range(H) for c in range(W) if walk[r][c] and r * CELL >= CAVE_RECT[1]),
                    key=lambda c: (c[0] - entry[0]) ** 2 + (c[1] - entry[1]) ** 2)
    cave_cells = flood(entry)
    cave_all = {(c, r) for r in range(H) for c in range(W) if walk[r][c] and r * CELL >= CAVE_RECT[1]}
    for col, row in cave_all - cave_cells:
        walk[row][col] = False
    place(CAVE_POINTS, CAVE_AT, cave_cells)
    for name, (x, y) in (("cave_rect_origin", CAVE_AT), ("cave_rect_end", CAVE_RECT[2:])):
        marker(name, x, y)

    blockers = [0 if walk[y][x] else 1 for y in range(H) for x in range(W)]
    Image.new("RGBA", (16, 16)).save(ASSETS / "collision.png")
    backdrop = dict(id=0, name="ground_backdrop", gid=100, x=0, y=MAP_H, width=MAP_W, height=MAP_H, rotation=0, visible=True)
    tiles = [dict(id=0, image="../assets/art/rock/ground.png", imagewidth=full.width, imageheight=full.height)]
    layers = [dict(id=1, name="Background", type="objectgroup", objects=[backdrop], visible=True, opacity=1),
              dict(id=2, name="Walls", type="tilelayer", width=W, height=H, x=0, y=0, opacity=1, visible=True, data=blockers),
              dict(id=3, name="Markers", type="objectgroup", objects=markers, visible=True, opacity=1)]
    everything = [backdrop] + markers
    for i, item in enumerate(everything, 1):
        item["id"] = i
    terrain = dict(type="tileset", version="1.10", name="space_rock_terrain", tilewidth=16, tileheight=16, tilecount=1, columns=1,
                   image="../assets/art/rock/collision.png", imagewidth=16, imageheight=16, margin=0, spacing=0)
    objectset = dict(type="tileset", version="1.10", name="space_rock_objects", tilewidth=MAP_W, tileheight=MAP_H,
                     tilecount=1, columns=0, tiles=tiles)
    world = dict(type="map", version="1.10", tiledversion="1.11.0", orientation="orthogonal", renderorder="right-down",
                 infinite=False, width=W, height=H, tilewidth=16, tileheight=16, nextlayerid=4, nextobjectid=len(everything) + 1,
                 layers=layers, tilesets=[dict(firstgid=1, source="space_rock_terrain.tsj"), dict(firstgid=100, source="space_rock_objects.tsj")])
    for name, data in (("space_rock.tmj", world), ("space_rock_terrain.tsj", terrain), ("space_rock_objects.tsj", objectset)):
        (MAPS / name).write_text(json.dumps(data, indent=2) + "\n")
    print(f"R-7: {W}x{H} tiles, {len(surface_cells)} surface cells, {len(cave_cells)} cave cells, {len(markers)} markers")
    print("Cave rect:", CAVE_RECT)
    for m in markers:
        if m["name"] in ("arrival", "cave_entry", "grave"):
            print(m["name"], m["x"], m["y"])


if __name__ == "__main__":
    main()
