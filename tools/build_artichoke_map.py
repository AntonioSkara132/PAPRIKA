#!/usr/bin/python3
"""Write the Artichoke Tiled map from the layout in create_artichoke_concept.py.

The concept image and the game map come from the same layout() call, so they
match tile for tile. Writes:

- assets/art/artichoke/artichoke_terrain.png and maps/artichoke_terrain.tsj:
  every distinct ground, cliff, sea and decal tile, 16 per row.
- assets/art/artichoke/objects/*.png and maps/artichoke_objects.tsj: one image
  per distinct object sprite.
- maps/artichoke.tmj with the layers Artichoke Ground, Water, Artichoke Cliffs,
  Artichoke Decals and the object layer Artichoke Objects. TiledLoader blocks
  movement on Water and Artichoke Cliffs tiles; the decals are walkable. The map
  property trench_cells lists the trench tiles, which give cover from distant shots.

Run tools/render_tiled_map.py maps/artichoke.tmj <png> to check the result.
"""

import json
from pathlib import Path

from PIL import Image

import create_artichoke_concept as concept

ROOT = concept.ROOT
TILE = concept.TILE
ART = ROOT / "assets/art/artichoke"
OBJECT_ART = ART / "objects"
MAPS = ROOT / "maps"
COLUMNS = 16
WATER_KINDS = ("ice", "shore")
CLIFF_KINDS = ("cliff_top", "cliff_mid", "cliff_low")


class TileSheet:
    """Collects distinct 16x16 tiles and hands out their local ids."""

    def __init__(self):
        self.images = []
        self._by_key = {}
        self._by_bytes = {}

    def add(self, key, make):
        if key in self._by_key:
            return self._by_key[key]
        return self.add_image(make(), key)

    def add_image(self, image, key=None):
        data = image.tobytes()
        if data not in self._by_bytes:
            self._by_bytes[data] = len(self.images)
            self.images.append(image)
        local_id = self._by_bytes[data]
        if key is not None:
            self._by_key[key] = local_id
        return local_id

    def save(self, path):
        rows = (len(self.images) + COLUMNS - 1) // COLUMNS
        sheet = Image.new("RGBA", (COLUMNS * TILE, rows * TILE))
        for index, image in enumerate(self.images):
            sheet.alpha_composite(image, ((index % COLUMNS) * TILE, (index // COLUMNS) * TILE))
        sheet.save(path)
        return sheet.size


def tile_layer(layer_id, name, data):
    return {"id": layer_id, "name": name, "type": "tilelayer", "x": 0, "y": 0, "width": concept.MAP_W,
            "height": concept.MAP_H, "opacity": 1, "visible": True, "data": data}


def main():
    data = concept.layout()
    ground, trench = data["ground"], data["trench"]
    sheet = TileSheet()
    layers = {name: [0] * (concept.MAP_W * concept.MAP_H) for name in ("ground", "water", "cliffs", "decals")}
    for y in range(concept.MAP_H):
        for x in range(concept.MAP_W):
            kind = ground[y][x]
            key, make = concept.ground_tile(ground, trench, x, y)
            layer = "water" if kind in WATER_KINDS else "cliffs" if kind in CLIFF_KINDS else "ground"
            layers[layer][y * concept.MAP_W + x] = sheet.add(key, make) + 1
    for (x, y), image in sorted(data["decals"].items()):
        layers["decals"][y * concept.MAP_W + x] = sheet.add_image(image) + 1

    ART.mkdir(parents=True, exist_ok=True)
    OBJECT_ART.mkdir(parents=True, exist_ok=True)
    width, height = sheet.save(ART / "artichoke_terrain.png")
    terrain = {
        "type": "tileset", "version": "1.10", "tiledversion": "1.12.2", "name": "artichoke_terrain",
        "tilewidth": TILE, "tileheight": TILE, "tilecount": len(sheet.images), "columns": COLUMNS,
        "image": "../assets/art/artichoke/artichoke_terrain.png", "imagewidth": width, "imageheight": height,
    }
    (MAPS / "artichoke_terrain.tsj").write_text(json.dumps(terrain, indent=2) + "\n")

    # One image file per distinct sprite; sprites that share a name and differ get _2, _3...
    for old in OBJECT_ART.glob("*.png"):
        old.unlink()
    tiles = []
    local_ids = {}
    name_counts = {}
    for item in data["objects"]:
        sprite = item["sprite"]
        key = (item["name"], sprite.size, sprite.tobytes())
        if key in local_ids:
            continue
        count = name_counts[item["name"]] = name_counts.get(item["name"], 0) + 1
        file_name = item["name"] + ("" if count == 1 else "_%d" % count) + ".png"
        sprite.save(OBJECT_ART / file_name)
        local_ids[key] = len(tiles)
        tiles.append({"id": len(tiles), "image": "../assets/art/artichoke/objects/" + file_name,
                      "imagewidth": sprite.width, "imageheight": sprite.height})
    objects_tileset = {
        "type": "tileset", "version": "1.10", "tiledversion": "1.12.2", "name": "artichoke_objects",
        "tilewidth": max(tile["imagewidth"] for tile in tiles), "tileheight": max(tile["imageheight"] for tile in tiles),
        "tilecount": len(tiles), "columns": 0, "objectalignment": "bottomleft", "tiles": tiles,
    }
    (MAPS / "artichoke_objects.tsj").write_text(json.dumps(objects_tileset, indent=2) + "\n")

    objects_firstgid = (len(sheet.images) // 100 + 1) * 100
    objects = []
    for item in data["objects"]:
        sprite = item["sprite"]
        local_id = local_ids[(item["name"], sprite.size, sprite.tobytes())]
        objects.append({"id": len(objects) + 1, "name": item["name"], "type": "", "gid": objects_firstgid + local_id,
                        "x": item["x"], "y": item["bottom"], "width": sprite.width, "height": sprite.height,
                        "rotation": 0, "visible": True})
    tmj = {
        "type": "map", "version": "1.10", "tiledversion": "1.12.2", "orientation": "orthogonal",
        "renderorder": "right-down", "width": concept.MAP_W, "height": concept.MAP_H, "tilewidth": TILE,
        "tileheight": TILE, "infinite": False, "nextlayerid": 6, "nextobjectid": len(objects) + 1,
        "backgroundcolor": "#e3eaee",
        # Trench tiles as "x,y;x,y;...": soldiers standing in them are covered from distant shots.
        "properties": [{"name": "trench_cells", "type": "string",
                        "value": ";".join("%d,%d" % cell for cell in sorted(trench))}],
        "tilesets": [{"firstgid": 1, "source": "artichoke_terrain.tsj"},
                     {"firstgid": objects_firstgid, "source": "artichoke_objects.tsj"}],
        "layers": [
            tile_layer(1, "Artichoke Ground", layers["ground"]),
            tile_layer(2, "Water", layers["water"]),
            tile_layer(3, "Artichoke Cliffs", layers["cliffs"]),
            tile_layer(4, "Artichoke Decals", layers["decals"]),
            {"id": 5, "name": "Artichoke Objects", "type": "objectgroup", "draworder": "topdown", "x": 0, "y": 0,
             "opacity": 1, "visible": True, "objects": objects},
        ],
    }
    (MAPS / "artichoke.tmj").write_text(json.dumps(tmj, separators=(",", ":")) + "\n")
    spawn_x, spawn_y = concept.PLAYER_SPAWN
    print("Wrote maps/artichoke.tmj: %d terrain tiles, %d object images, %d objects; player feet at (%d, %d)"
          % (len(sheet.images), len(tiles), len(objects), spawn_x * TILE, spawn_y * TILE - 2))


if __name__ == "__main__":
    main()
