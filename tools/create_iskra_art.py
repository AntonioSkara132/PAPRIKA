"""Export the Iskra concept's ground and individual sprites for the playable map."""
from __future__ import annotations

import json
import random
from pathlib import Path

import numpy as np
from PIL import Image

import create_iskra_concept as art
import create_iskra_npc_sheet as characters
import create_iskra_punks as punks

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art/iskra"
PEOPLE = {"citizen", "police", "soldier", "punk", "shady", "person"}
BUILDINGS = {"tesla_palace", "library", "forge", "police_post", "market_hall", "factory",
             "vertical_farm", "greenhouse", "lantern_house", "tenement", "tenement_fit", "row_house",
             "boiler_house", "dome_flat", "container_stack", "gear_house", "nut_house", "tube_house",
             "bulb_house", "capacitor_stack", "coil_tower", "piston_house", "gyro_house", "dish_dome",
             "ordinary_house", "girder_frame", "disco", "market_stall"}
TAGGED = PEOPLE | BUILDINGS | {"cruiser", "tower_crane", "crates", "small_ship", "pad", "billboard",
                             "street_lamp", "wire_tree", "coil_pylon", "graffiti_wall", "half_pipe", "leafy_tree", "park_bench"}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    characters.main()
    punks.main()
    originals = {name: getattr(art, name) for name in TAGGED}
    def tagged(name, fn):
        def draw(*args, **kwargs):
            image = fn(*args, **kwargs)
            if image is not None:
                image.info["kind"] = name
            return image
        return draw
    for name, fn in originals.items():
        setattr(art, name, tagged(name, fn))
    try:
        rng = random.Random(4)
        layout = art.layout()
        ground = art.space(rng)
        ground.alpha_composite(art.build_ground(rng, layout), (0, art.MARGIN))
        sprites, _, pools, park_pools, beams, _ = art.place_city(rng, layout)
    finally:
        for name, fn in originals.items():
            setattr(art, name, fn)
    pools = [(x, y + art.MARGIN, r, c, s) for x, y, r, c, s in pools]
    park_pools = [(x, y + art.MARGIN, r, c, s) for x, y, r, c, s in park_pools]
    beams = [((x, y + art.MARGIN), (ex, ey + art.MARGIN), c) for (x, y), (ex, ey), c in beams]
    shape = (art.CANVAS_H, art.W)
    light = art.light_pools(pools, shape) + (art.light_pools(park_pools, shape) + art.beam_layer(beams, shape)) * art.park_clip()
    art.night(ground, pools, park_pools, beams).save(OUT / "ground.png")
    records = []
    for index, (bottom, x, sprite) in enumerate(sprites):
        kind = sprite.info.get("kind", "decoration")
        y = bottom + art.MARGIN - sprite.height
        # Lighting is baked per sprite so actors can still walk in front of and behind it.
        local_light = np.zeros((sprite.height, sprite.width, 3), np.float32)
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(art.W, x + sprite.width), min(art.CANVAS_H, y + sprite.height)
        if x1 > x0 and y1 > y0:
            local_light[y0-y:y1-y, x0-x:x1-x] = light[y0:y1, x0:x1]
        arr = np.asarray(sprite.convert("RGB"), np.float32)
        rgb = arr.astype(np.int32)
        key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
        emissive = np.isin(key, [(r << 16) | (g << 8) | b for r, g, b in art.EMISSIVE])
        out = art.shade_pixels(arr, local_light)
        out[emissive] = arr[emissive]
        image = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("RGBA")
        image.putalpha(sprite.getchannel("A"))
        role = sprite.info.get("npc_role", "")
        filename = f"npcs/{role}.png" if role else f"sprite_{index:04d}.png"
        if not role:
            image.save(OUT / filename)
        record = dict(image=filename, kind=kind, x=x, bottom=bottom + art.MARGIN,
                      width=sprite.width, height=sprite.height,
                      building=kind in BUILDINGS, person=bool(role) or kind in PEOPLE)
        if role:
            record["npc_role"] = role
        if kind == "leafy_tree":
            record["solid_rect"] = [sprite.width//2-3, sprite.height-12, 6, 7]
        elif kind == "park_bench":
            record["solid_rect"] = [2, 7, 22, 5]
        records.append(record)
    for index, color in enumerate(art.SHIP_COLORS):
        art.small_ship(color).save(OUT / f"ship_{index}.png")
    for name, image in {"taxi_pad": art.pad(), "officer": art.police(),
                        "clerk": art.citizen(random.Random(97))}.items():
        image.save(OUT / f"{name}.png")
    Image.new("RGBA", (16, 16)).save(OUT / "collision.png")
    (OUT / "placement.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"Exported {len(records)} Iskra sprites and ground to {OUT}")


if __name__ == "__main__":
    main()
