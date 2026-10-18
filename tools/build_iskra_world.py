"""Build Iskra's Tiled map from the same placements as its approved concept."""
from __future__ import annotations

from collections import deque
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import create_iskra_concept as art
import create_iskra_hotel_art as hotel
import create_iskra_gang_art as gangs
import create_iskra_investigation_art as investigation

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/art/iskra"
MAPS = ROOT / "maps"
SCALE, CELL = 2, 16
W, H = (art.W * SCALE + 15) // 16, 4032 // 16


def main():
    hotel.main()
    gangs.main()
    investigation.main()
    records = json.loads((ASSETS / "placement.json").read_text())
    # Vacant southern courtyard, west of the central canal; existing scenery stays put.
    records.append(dict(kind='holding_store', image='gang_holding_exterior.png',
                        x=756, bottom=1248, width=84, height=44,
                        building=True, person=False, solid_rect=[2, 10, 80, 31]))
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
    mark("hotel_door", 1005, 1126)
    mark("hotel_laundry", 960, 1144)
    mark("park_vendor", 1292, 1124+art.MARGIN)
    mark("red_pelican", 1350, 974+art.MARGIN)
    mark("green_squirrel", 1510, 1128+art.MARGIN)
    mark("park_witness", 1432, 1176+art.MARGIN)
    mark("workshop", 1470, 884+art.MARGIN)
    mark("courier", 1722, 730+art.MARGIN)
    mark("veki_park", 1206, 1080+art.MARGIN)
    mark("veki_freight", 1728, 570+art.MARGIN)
    mark("freight_office", 1704, 548+art.MARGIN)
    mark("freight_side", 1734, 610+art.MARGIN)
    mark("delivery_pelican", 1728, 950+art.MARGIN)
    mark("delivery_squirrel", 764, 674+art.MARGIN)
    mark("veki_holding", 876, 1188)
    mark("holding_office", 797, 1260)
    mark("holding_side", 848, 1248)
    mark("collector_hideout", 280, 680)
    mark("collector_neighbor", 350, 944)
    mark("collector_route_north", 280, 616)
    mark("collector_route_south", 280, 752)
    mark("collector_market", 680, 748)
    mark("collector_rival_start", 744, 920)
    mark("collector_dispatch", 310, 580)
    mark("collector_holding", 160, 944)
    mark("collector_escape", 780, 734)
    for name, (x, y) in investigation.EXTERIOR_POINTS.items():
        mark(name, x, y)
    landmark_kinds = {"tesla_palace": "tower", "police_post": "police", "library": "library",
                      "forge": "forge", "market_hall": "food", "vertical_farm": "farm"}
    # The second police post is the eastern station, where the quartermaster keeps the issue register.
    seen = {}
    for r in records:
        kind = r["kind"]
        count = seen.get(kind, 0)
        if kind in landmark_kinds and count < (2 if kind == "police_post" else 1):
            name = "police_records" if count == 1 else landmark_kinds[kind]
            mark(name, r["x"]+r["width"]*.5, r["bottom"]+12)
            seen[kind] = count + 1
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
    for site in investigation.SIGNS:
        point = next(m for m in markers if m['name'] == 'inv_' + site + '_entry')
        image = 'investigation/' + site + '_sign.png'
        sw, sh = Image.open(ASSETS / image).size
        dx, dy = {'owner': (42, 10), 'squirrel': (0, -6), 'pelican': (20, -6)}[site]
        obj('iskra_scenery', image, point['x']+dx-sw/2, point['y']+dy, sw, sh)
    point = next(m for m in markers if m['name'] == 'inv_rendezvous')
    obj('ground_backdrop', 'investigation/rendezvous_mark.png', point['x']-40, point['y']+8, 80, 32)
    hx, hy = hotel.ROOM_ORIGIN
    hw, hh = hotel.ROOM_SIZE
    walk[(hy+16)//16:(hy+hh-16)//16, (hx+16)//16:(hx+hw-16)//16] = True
    for x, y, width, height in hotel.FURNITURE:
        walk[(hy+y*2)//16:(hy+(y+height)*2+15)//16, (hx+x*2)//16:(hx+(x+width)*2+15)//16] = False
    room_points = {"hotel_room_arrival": (hx+192, hy+208), "hotel_room_exit": (hx+192, hy+224),
                   "hotel_room_bed": (hx+80, hy+128), "hotel_room_chest": (hx+160, hy+96)}
    for name, (x, y) in room_points.items():
        assert walk[y//16, x//16], name
        markers.append(dict(id=0, name=name, type="marker", point=True, x=x, y=y, width=0, height=0, visible=True))
    obj("ground_backdrop", "hotel_room.png", hx, hy+hh, hw, hh)
    # The lobby is walkable: the street door leads in, the stairs lead to room 12, and Mara's desk is inside.
    lx, ly = hotel.LOBBY_ORIGIN
    lw, lh = hotel.LOBBY_SIZE
    walk[(ly+16)//16:(ly+lh-16)//16, (lx+16)//16:(lx+lw-16)//16] = True
    for x, y, width, height in hotel.LOBBY_FURNITURE:
        walk[(ly+y*2)//16:(ly+(y+height)*2+15)//16, (lx+x*2)//16:(lx+(x+width)*2+15)//16] = False
    lobby_points = {"hotel": (lx+192, ly+88), "hotel_stairs": (lx+48, ly+168),
                    "hotel_lobby_arrival": (lx+192, ly+190), "hotel_lobby_door": (lx+192, ly+226)}
    for name, (x, y) in lobby_points.items():
        assert walk[y//16, x//16], name
        markers.append(dict(id=0, name=name, type="marker", point=True, x=x, y=y, width=0, height=0, visible=True))
    obj("ground_backdrop", "hotel_lobby.png", lx, ly+lh, lw, lh)
    obj("iskra_scenery", "hotel_sign.png", 1944, 2232, 172, 32)
    for name, (gx, gy, gw, gh) in gangs.ROOMS.items():
        walk[(gy+16)//16:(gy+gh-16)//16, (gx+16)//16:(gx+gw-16)//16] = True
        # Shelves occupy only the rear wall, leaving routes on both sides of the room.
        for sx in (36, 96, 222, 274):
            walk[(gy+48)//16:(gy+88)//16, (gx+sx*2)//16:(gx+sx*2+46+15)//16] = False
        walk[(gy+298)//16:(gy+334+15)//16, (gx+132)//16:(gx+508+15)//16] = False
        if name == 'freight':
            walk[(gy+160)//16:(gy+196)//16, (gx+90)//16:(gx+148+15)//16] = False
        points = {'arrival': (72, 288), 'side': (568, 288), 'exit': (48, 288)}
        if name == 'freight':
            points.update({'manifest': (112, 208), 'crate_a': (272, 176), 'crate_b': (400, 176)})
        else:
            points.update({'prisoner_a': (480, 144), 'prisoner_b': (536, 176), 'lock': (448, 208),
                           'guard_a': (192, 224), 'guard_b': (288, 224), 'stash': (328, 112), 'stash_guard': (352, 160)})
        for suffix, (dx, dy) in points.items():
            x, y = gx+dx, gy+dy
            assert walk[y//16, x//16], (name, suffix)
            markers.append(dict(id=0, name='gang_'+name+'_'+suffix, type='marker', point=True, x=x, y=y, width=0, height=0, visible=True))
        obj('ground_backdrop', 'gang_'+name+'.png', gx, gy+gh, gw, gh)
    investigation_areas = {}
    for site, (rx, ry, rw, rh) in investigation.ROOMS.items():
        walk[(ry+16)//16:(ry+rh-16)//16, (rx+16)//16:(rx+rw-16)//16] = True
        for x, y, width, height in investigation.WALLS[site] + investigation.FURNITURE[site]:
            walk[(ry+y*2)//16:(ry+(y+height)*2+15)//16, (rx+x*2)//16:(rx+(x+width)*2+15)//16] = False
        ax, ay = investigation.POINTS[site]['arrival']
        arrival = ((rx+ax*2)//16, (ry+ay*2)//16)
        room_reached = {arrival}
        todo = deque([arrival])
        assert walk[arrival[1], arrival[0]], site
        while todo:
            x, y = todo.popleft()
            for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if rx//16 <= nx < (rx+rw)//16 and ry//16 <= ny < (ry+rh)//16 and walk[ny,nx] and (nx,ny) not in room_reached:
                    room_reached.add((nx,ny)); todo.append((nx,ny))
        for suffix, (x, y) in investigation.POINTS[site].items():
            name = 'inv_' + site + '_' + suffix
            x, y = rx+x*2, ry+y*2
            assert (x//16, y//16) in room_reached, name
            markers.append(dict(id=0, name=name, type='marker', point=True, x=x, y=y, width=0, height=0, visible=True))
            investigation_areas[name] = room_reached
        obj('ground_backdrop', 'investigation/' + site + '.png', rx, ry+rh, rw, rh)
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
        cell = (int(m["x"]//16), int(m["y"]//16))
        if m['name'] in investigation_areas:
            assert cell in investigation_areas[m['name']], m['name']
        elif not m["name"].startswith(("hotel_room_", "hotel_lobby_", "gang_")) and m["name"] not in ("hotel", "hotel_stairs"):
            assert cell in reached, m["name"]
    print(f"Iskra: {W}x{H} tiles, {len(records)} objects, {len(reached)} connected exterior cells; {len(markers)} markers")
    print("Arrival:", next((m["x"],m["y"]) for m in markers if m["name"]=="arrival"))


if __name__ == "__main__":
    main()
