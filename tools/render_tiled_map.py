#!/usr/bin/python3
"""Render the finite orthogonal Paprika TMJ map exactly from its Tiled layers."""

from pathlib import Path
import json
import sys
from PIL import Image

MAP_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/home/antonio/Paprika/maps/concepts/paprika_first_view.tmj")
OUTPUT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("/home/antonio/Paprika/art/concepts/paprika_first_view_raw.png")

m = json.loads(MAP_PATH.read_text())
base = MAP_PATH.parent
width = m["width"] * m["tilewidth"]
height = m["height"] * m["tileheight"]
out = Image.new("RGBA", (width, height), m.get("backgroundcolor", "#000000"))

# Resolve each external Tiled tileset.
tilesets = []
for ref in m["tilesets"]:
    tsj_path = base / ref["source"]
    ts = json.loads(tsj_path.read_text())
    tilesets.append((ref["firstgid"], tsj_path.parent, ts))
tilesets.sort(key=lambda item: item[0])

terrain_cache = {}
object_cache = {}

def get_tile(gid):
    if gid == 0:
        return None
    selected = None
    for firstgid, folder, ts in tilesets:
        if gid >= firstgid:
            selected = firstgid, folder, ts
        else:
            break
    if selected is None:
        return None
    firstgid, folder, ts = selected
    tile_id = gid - firstgid
    key = (firstgid, tile_id)
    if ts.get("image"):
        if firstgid not in terrain_cache:
            terrain_cache[firstgid] = Image.open(folder / ts["image"]).convert("RGBA")
        sheet = terrain_cache[firstgid]
        tw, th = ts["tilewidth"], ts["tileheight"]
        columns = ts["columns"]
        x = (tile_id % columns) * tw
        y = (tile_id // columns) * th
        return sheet.crop((x, y, x + tw, y + th))
    if key not in object_cache:
        tile = next(t for t in ts["tiles"] if t["id"] == tile_id)
        object_cache[key] = Image.open(folder / tile["image"]).convert("RGBA")
    return object_cache[key]

for layer in m["layers"]:
    if not layer.get("visible", True):
        continue
    if layer["type"] == "tilelayer":
        layer_img = Image.new("RGBA", out.size, (0, 0, 0, 0))
        for i, gid in enumerate(layer["data"]):
            tile = get_tile(gid)
            if tile is None:
                continue
            x = (i % layer["width"]) * m["tilewidth"]
            y = (i // layer["width"]) * m["tileheight"]
            layer_img.alpha_composite(tile, (x, y))
        if layer.get("opacity", 1) < 1:
            alpha = layer_img.getchannel("A").point(lambda a: int(a * layer["opacity"]))
            layer_img.putalpha(alpha)
        out.alpha_composite(layer_img)
    elif layer["type"] == "objectgroup":
        # Tiled's top-down order is based on the bottom edge of each tile object.
        for obj in sorted(layer["objects"], key=lambda o: (o.get("y", 0), o.get("id", 0))):
            tile = get_tile(obj.get("gid", 0))
            if tile is None:
                continue
            x = round(obj["x"])
            y = round(obj["y"] - obj.get("height", tile.height))
            out.alpha_composite(tile, (x, y))
    elif layer["type"] == "imagelayer" and layer.get("image"):
        image = Image.open(base / layer["image"]).convert("RGBA")
        x = round(layer.get("x", 0) + layer.get("offsetx", 0))
        y = round(layer.get("y", 0) + layer.get("offsety", 0))
        out.alpha_composite(image, (x, y))

out.save(OUTPUT)
print(f"Rendered {OUTPUT} ({out.width}x{out.height})")
