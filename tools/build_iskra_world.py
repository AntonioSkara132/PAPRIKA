"""Build Iskra's Tiled map from the same placements as its approved concept."""
from __future__ import annotations

from collections import deque
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import create_iskra_concept as art

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/art/iskra"
MAPS = ROOT / "maps"
SCALE, CELL = 2, 16
W, H = (art.W * SCALE + 15) // 16, (art.CANVAS_H * SCALE + 15) // 16


def main():
    records = json.loads((ASSETS / "placement.json").read_text())
    mask = Image.new("L", (art.W, art.CANVAS_H), 0)
    d = ImageDraw.Draw(mask)
    def polygon(points, fill):
        d.polygon([(x, y + art.MARGIN) for x, y in points], fill=fill)
    polygon(art.PLATFORM, 255)
    for points in art.CANALS:
        d.line([(x, y + art.MARGIN) for x, y in points], fill=0, width=art.CANAL_W + 4, joint="curve")
    for x, y, vertical in art.bridges():
        y += art.MARGIN
        dx, dy = (10, art.CANAL_W // 2 + 10) if vertical else (art.CANAL_W // 2 + 10, 10)
        d.rectangle((x-dx, y-dy, x+dx, y+dy), fill=255)
    for y0, y1 in art.PIERS:
        d.rectangle((1700, y0+art.MARGIN+3, 1820, y1+art.MARGIN-3), fill=255)
    # The piers stop at the ship's hull; there is no route onto its deck.
    for r in records:
        if r["building"]:
            x, b, w, h = r["x"], r["bottom"], r["width"], r["height"]
            d.rectangle((x+w*.14, b-max(6, h*.10)-max(7, h*.16)/2,
                         x+w*.86, b-max(6, h*.10)+max(7, h*.16)/2), fill=0)
        if "solid_rect" in r:
            dx, dy, width, height = r["solid_rect"]
            x, y = r["x"]+dx, r["bottom"]-r["height"]+dy
            d.rectangle((x, y, x+width-1, y+height-1), fill=0)
    walk = np.zeros((H, W), bool)
    for row in range(H):
        for col in range(W):
            x, y = col*8+4, row*8+4
            if x < art.W-2 and y < art.CANVAS_H-2:
                # Retain a little space around the player's feet at canal edges.
                walk[row, col] = all(mask.getpixel((x+dx, y+dy)) for dx, dy in ((0,0),(-2,0),(2,0),(0,-2),(0,2)))
    for r in records:
        if "solid_rect" not in r:
            continue
        dx, dy, width, height = r["solid_rect"]
        x, y = r["x"]+dx, r["bottom"]-r["height"]+dy
        # A narrow trunk can fall between the navigation tile's sample points.
        left, top = max(0, int(x//8)), max(0, int(y//8))
        right, bottom = min(W, int((x+width-1)//8)+1), min(H, int((y+height-1)//8)+1)
        walk[top:bottom, left:right] = False
    def nearest(x, y, allowed=walk):
        ys, xs = np.where(allowed)
        distances = (xs*16+8-x*2)**2 + (ys*16+8-y*2)**2
        i = int(np.argmin(distances))
        return int(xs[i]), int(ys[i])
    start = nearest(1728, 350+art.MARGIN)
    reached = {start}
    todo = deque([start])
    while todo:
        x, y = todo.popleft()
        for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0 <= nx < W and 0 <= ny < H and walk[ny,nx] and (nx,ny) not in reached:
                reached.add((nx,ny)); todo.append((nx,ny))
    connected = np.zeros_like(walk)
    for x, y in reached:
        connected[y,x] = True
    markers = []
    def mark(name, x, y):
        cell = nearest(x, y, connected)
        if abs(cell[0]*8+4-x)+abs(cell[1]*8+4-y) > 90:
            raise ValueError(f"{name} is not near a reachable street: {x}, {y}")
        markers.append(dict(id=0, name=name, type="marker", point=True,
                            x=cell[0]*16+8, y=cell[1]*16+8, width=0, height=0, visible=True))
    mark("arrival", 1728, 350+art.MARGIN)
    mark("respawn", 1728, 350+art.MARGIN)
    mark("dock_officer", 1720, 368+art.MARGIN)
    mark("taxi_dock", 1734, 338+art.MARGIN)
    mark("taxi_tower", 930, 418+art.MARGIN)
    mark("taxi_market", 780, 674+art.MARGIN)
    mark("taxi_park", 1242, 1080+art.MARGIN)
    mark("taxi_cruiser", 1790, 653+art.MARGIN)
    mark("cruiser", 1800, 868+art.MARGIN)
    mark("park", 1440, 1134+art.MARGIN)
    mark("nature_park", 418, 652+art.MARGIN)
    mark("nature_park_north", 406, 534+art.MARGIN)
    mark("nature_park_south", 410, 704+art.MARGIN)
    landmark_kinds = {"tesla_palace": "tower", "police_post": "police", "library": "library",
                      "forge": "forge", "market_hall": "food", "vertical_farm": "farm"}
    seen = set()
    for r in records:
        kind = r["kind"]
        if kind in landmark_kinds and kind not in seen:
            mark(landmark_kinds[kind], r["x"]+r["width"]*.5, r["bottom"]+12)
            seen.add(kind)
    objects, tiles, images = [], [], {}
    def gid(image):
        if image not in images:
            n = len(images)
            images[image] = n + 100
            w, h = Image.open(ASSETS / image).size
            tiles.append(dict(id=n, image=f"../assets/art/iskra/{image}", imagewidth=w, imageheight=h))
        return images[image]
    def obj(name, image, x, bottom, width, height):
        objects.append(dict(id=0, name=name, gid=gid(image), x=x, y=bottom,
                            width=width, height=height, rotation=0, visible=True))
    obj("ground_backdrop", "ground.png", 0, art.CANVAS_H*2, art.W*2, art.CANVAS_H*2)
    for i, r in enumerate(records):
        name = f"story_resident_{i}" if r["person"] else "iskra_scenery"
        if r["person"]:
            obj(name, r["image"], r["x"]*2+r["width"]*.5, r["bottom"]*2, r["width"], r["height"])
        else:
            obj(name, r["image"], r["x"]*2, r["bottom"]*2, r["width"]*2, r["height"]*2)
    for marker in markers:
        if marker["name"].startswith("taxi_"):
            pw, ph = Image.open(ASSETS / "taxi_pad.png").size
            obj("landing_pad_"+marker["name"], "taxi_pad.png", marker["x"]-pw, marker["y"]+ph, pw*2, ph*2)
    blockers = [0 if walk[y,x] else 1 for y in range(H) for x in range(W)]
    layers = [dict(id=1,name="Background",type="objectgroup",objects=objects[:1],visible=True,opacity=1),
              dict(id=2,name="Hull Walls",type="tilelayer",width=W,height=H,x=0,y=0,opacity=1,visible=True,data=blockers),
              dict(id=3,name="City",type="objectgroup",objects=objects[1:],visible=True,opacity=1,draworder="topdown"),
              dict(id=4,name="Markers",type="objectgroup",objects=markers,visible=True,opacity=1)]
    for i, item in enumerate(objects+markers, 1):
        item["id"] = i
    terrain = dict(type="tileset",version="1.10",name="iskra_terrain",tilewidth=16,tileheight=16,tilecount=1,columns=1,
                   image="../assets/art/iskra/collision.png",imagewidth=16,imageheight=16,margin=0,spacing=0)
    objectset = dict(type="tileset",version="1.10",name="iskra_objects",tilewidth=art.W*2,tileheight=art.CANVAS_H*2,
                     tilecount=len(tiles),columns=0,tiles=tiles)
    world = dict(type="map",version="1.10",tiledversion="1.11.0",orientation="orthogonal",renderorder="right-down",
                 infinite=False,width=W,height=H,tilewidth=16,tileheight=16,nextlayerid=5,nextobjectid=len(objects+markers)+1,
                 layers=layers,tilesets=[dict(firstgid=1,source="iskra_terrain.tsj"),dict(firstgid=100,source="iskra_objects.tsj")])
    for name, data in (("iskra.tmj",world),("iskra_terrain.tsj",terrain),("iskra_objects.tsj",objectset)):
        (MAPS/name).write_text(json.dumps(data,indent=2)+"\n")
    for m in markers:
        assert (int(m["x"]//16),int(m["y"]//16)) in reached, m["name"]
    print(f"Iskra: {W}x{H} tiles, {len(records)} objects, {len(reached)} connected cells; all {len(markers)} markers reachable")
    print("Arrival:", next((m["x"],m["y"]) for m in markers if m["name"]=="arrival"))


if __name__ == "__main__":
    main()
