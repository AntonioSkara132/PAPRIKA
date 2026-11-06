#!/usr/bin/python3
"""Game art for R-7, the space rock, from the approved concept (create_space_rock_concept.py).

Writes to assets/art/rock/:
- surface.png: the rock's ground without ships (480x300, shown at 2x);
- cave_dark.png, cave_lit.png: the cave before and after the merge (288x176, shown at 2x);
- martin_ship.png: Martin's ship (132x60, shown at 2x);
- martin.png: Martin (18x26, shown at 1x like every character);
- voice.png: the Voice in the Dark over the grave (60x84, shown at 1x);
- hacker.png, hacker_trooper.png: the two hackers who come back with Veki,
  on the standard 16x24 body in dark dotted clothes: pyjamas with a
  nightcap, and a jumpsuit;
- sealed_rocks.png: the rocks Martin's men roll across the cave mouth (48x32, shown at 2x).

surface_walk() and cave_walk() return where people can walk, at half size
(255 = open ground); tools/build_space_rock_world.py turns them into the
map's Walls layer.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFilter

import create_space_rock_concept as concept

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/art/rock"

SURFACE_W, SURFACE_H = concept.SURFACE_W, concept.SURFACE_H
CAVE_W, CAVE_H = 288, 176
# Where the ships stand on the surface, top left at half size.
LASTA_AT = concept.LASTA_AT
LASTA_SIZE = (110, 56)
# Martin lands in view of the cave mouth, closer than on the concept sheet.
MARTIN_SHIP_AT = (270, 128)
# Base rectangles the ships block while they stand there, at half size.
LASTA_BASE = (LASTA_AT[0] + 10, LASTA_AT[1] + 40, LASTA_AT[0] + 100, LASTA_AT[1] + 56)
MARTIN_SHIP_BASE = (MARTIN_SHIP_AT[0] + 8, MARTIN_SHIP_AT[1] + 30, MARTIN_SHIP_AT[0] + 128, MARTIN_SHIP_AT[1] + 46)


def voice():
    """The Voice alone: a tall soldier's outline in pale light, its lower body breaking into motes."""
    w, h = 60, 84
    cx = w // 2
    body = Image.new("RGBA", (w, h))
    bd = ImageDraw.Draw(body)
    V, VD = concept.VOICE, concept.VOICE_DIM
    bd.rounded_rectangle((cx - 7, 4, cx + 7, 20), 4, fill=V + (70,), outline=V)
    bd.line((cx - 4, 11, cx + 4, 11), fill=V, width=2)
    bd.polygon([(cx - 4, 20), (cx + 4, 20), (cx + 5, 24), (cx - 5, 24)], fill=V + (60,))
    bd.polygon([(cx - 18, 26), (cx - 6, 23), (cx + 6, 23), (cx + 18, 26), (cx + 13, 62), (cx - 13, 62)],
               fill=V + (55,), outline=VD)
    bd.polygon([(cx - 18, 26), (cx - 22, 52), (cx - 18, 54), (cx - 14, 32)], fill=V + (45,), outline=VD)
    bd.polygon([(cx + 18, 26), (cx + 22, 52), (cx + 18, 54), (cx + 14, 32)], fill=V + (45,), outline=VD)
    for y in (32, 40, 48):
        bd.line((cx - 9, y, cx - 3, y), fill=V)
        bd.line((cx - 3, y, cx - 3, y + 4), fill=V)
        bd.line((cx + 3, y + 2, cx + 9, y + 2), fill=V)
        bd.point((cx + 9, y + 2), fill=(255, 255, 255))
    fade = Image.linear_gradient("L").resize((w, h)).point(lambda v: 255 if v < 128 else max(0, 255 - (v - 128) * 4))
    body.putalpha(Image.composite(body.split()[3], Image.new("L", (w, h), 0), fade))
    glow = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(glow)
    gd.bitmap((0, 0), body.split()[3], fill=V + (90,))
    rng = random.Random(3)
    for _ in range(60):
        gd.point((cx + rng.randint(-14, 14), rng.randint(56, 80)), fill=V + (rng.randint(80, 220),))
    img = Image.new("RGBA", (w, h))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2)))
    img.alpha_composite(body)
    img.alpha_composite(glow)
    return img


PLAIN = (91, 57, 44), (28, 23, 48), (220, 167, 120), (78, 131, 207), (65, 57, 71)  # hair, outline, skin, shirt, trousers


def dotted(img, cells, base, dot, phase=0):
    """Paint `cells` in `base` with a dot on every other pixel of every other row."""
    px = img.load()
    for x, y in cells:
        px[x, y] = (dot if (y % 2 == 0 and (x + y // 2 + phase) % 3 == 0) else base) + (255,)


def pyjama_hacker():
    """Dark plum pyjamas with pink dots: a short-sleeved shirt, long trousers and a droopy nightcap."""
    img = Image.open(ROOT / "assets/art/player_plain.png").convert("RGBA")
    px = img.load()
    hair, outline, skin, shirt, trousers = PLAIN
    shirt_cells = [(x, y) for y in range(24) for x in range(16) if px[x, y][:3] == shirt]
    # short sleeves over the top two rows of the arms
    shirt_cells += [(x, y) for y in (10, 11) for x in (3, 4, 11, 12)]
    dotted(img, shirt_cells, (58, 30, 72), (236, 120, 196))
    dotted(img, [(x, y) for y in range(24) for x in range(16) if px[x, y][:3] == trousers], (44, 24, 56), (236, 120, 196), 1)
    d = ImageDraw.Draw(img)
    # nightcap over the hair, its tip flopping to the side with a pompom
    d.rectangle((5, 1, 10, 3), fill=(58, 30, 72))
    d.line((5, 4, 10, 4), fill=(236, 120, 196))
    d.line((11, 2, 13, 4), fill=(58, 30, 72))
    d.point((14, 5), fill=(255, 236, 248))
    d.point((7, 2), fill=(236, 120, 196))
    d.point((9, 1), fill=(236, 120, 196))
    return img


def jumpsuit_hacker():
    """A dark teal one-piece jumpsuit with lime dots, long sleeves and a zip down the front."""
    img = Image.open(ROOT / "assets/art/player_plain.png").convert("RGBA")
    px = img.load()
    hair, outline, skin, shirt, trousers = PLAIN
    cells = [(x, y) for y in range(24) for x in range(16) if px[x, y][:3] in (shirt, trousers)]
    cells += [(x, y) for y in range(10, 15) for x in (3, 4, 11, 12)]
    dotted(img, cells, (22, 44, 50), (150, 232, 96))
    d = ImageDraw.Draw(img)
    d.line((8, 10, 8, 16), fill=(120, 140, 140))  # the zip
    d.line((6, 9, 9, 9), fill=(36, 70, 76))  # collar
    for y in range(24):  # darker hair
        for x in range(16):
            if px[x, y][:3] == hair:
                px[x, y] = (40, 30, 36, 255)
    return img


# The sealing rocks cover the tunnel's end, at half size from the cave's top left.
SEALED_ROCKS_AT = (0, 144)


def sealed_rocks():
    """A heap of boulders filling the end of the tunnel, lit faintly from the moss."""
    img = Image.new("RGBA", (48, 32))
    d = ImageDraw.Draw(img)
    for x, y, r, color in ((10, 24, 10, concept.ROCK_DARK), (30, 25, 11, concept.ROCK_DARK), (40, 14, 8, concept.ROCK),
                           (20, 13, 9, concept.ROCK), (8, 8, 7, concept.ROCK_DARK), (31, 6, 6, concept.ROCK_LIGHT)):
        d.ellipse((x - r, y - r * .8, x + r, y + r * .8), fill=color, outline=concept.INK)
        d.arc((x - r + 2, y - r * .8 + 1, x + r - 2, y + r * .6), 200, 300, fill=concept.ROCK_LIGHT)
    for x, y in ((18, 22), (34, 18), (12, 14)):
        d.line((x, y, x + 3, y + 2), fill=concept.ROCK_DEEP)
    return img


def surface_walk():
    """Open ground on the surface: inside the rock's rim, off the ridges, boulders and crates."""
    mask = Image.new("L", (SURFACE_W, SURFACE_H), 0)
    d = ImageDraw.Draw(mask)
    cx, cy = SURFACE_W / 2, SURFACE_H / 2 + 14
    pts = []
    for i in range(64):
        a = i / 64 * math.tau
        r = 1 + .05 * math.sin(a * 5 + 1) + .03 * math.sin(a * 11) + .02 * math.sin(a * 17)
        pts.append((cx + math.cos(a) * 252 * r * .95, cy + 2 + math.sin(a) * 148 * r * .92))
    d.polygon(pts, fill=255)
    d.rectangle((0, 0, SURFACE_W - 1, SURFACE_H - 1), outline=0, width=6)
    ox, oy = 80, 14
    d.polygon([(70 + ox, 52 + oy), (100 + ox, 30 + oy), (140 + ox, 24 + oy), (190 + ox, 28 + oy), (230 + ox, 44 + oy),
               (240 + ox, 64 + oy), (240 + ox, 68 + oy), (60 + ox, 68 + oy)], fill=0)
    # nobody walks behind the ridge, where they would stand on its drawn face
    d.rectangle((60 + ox - 4, 0, 240 + ox + 4, 68 + oy), fill=0)
    # the scaffolding legs stand a step in front of the ridge
    for x in (126, 178):
        d.rectangle((x + ox - 2, 60 + oy, x + ox + 2, 70 + oy), fill=0)
    d.polygon([(390, 120), (410, 100), (440, 104), (456, 126), (420, 134)], fill=0)
    d.polygon([(40, 100), (60, 84), (84, 88), (90, 104), (60, 112)], fill=0)
    for x, y, r in ((110, 110, 7), (96, 116, 4), (380, 96, 6), (210, 250, 5), (450, 210, 6), (20, 190, 5)):
        d.ellipse((x - r, y - r * .5, x + r, y + r * .7), fill=0)
    for x, y in ((176, 86), (186, 90), (290, 88), (420, 230)):
        d.rectangle((x, y + 2, x + 9, y + 7), fill=0)
    d.rectangle((348, 104, 354, 111), fill=0)  # the survey mast's foot
    return mask


def cave_walk():
    """The cave floor: the tunnel and the chamber, off the stalagmites, rubble, crate and cairn."""
    mask = Image.new("L", (CAVE_W, CAVE_H), 0)
    d = ImageDraw.Draw(mask)
    path = [(20, 160), (40, 130), (70, 118), (110, 112), (140, 96), (170, 84), (196, 82)]
    for (x0, y0), (x1, y1) in zip(path, path[1:]):
        for t in range(12):
            x, y = x0 + (x1 - x0) * t / 12, y0 + (y1 - y0) * t / 12
            d.ellipse((x - 15, y - 9, x + 15, y + 9), fill=255)
    d.ellipse((172, 34, 276, 136), fill=255)
    for x, y in ((30, 118), (86, 92), (150, 74), (196, 46), (270, 96), (182, 132), (120, 134)):
        d.rectangle((x - 4, y - 1, x + 4, y + 6), fill=0)
    for x, y in ((50, 140), (96, 120), (150, 104), (186, 128), (264, 70)):
        d.rectangle((x, y - 2, x + 9, y + 3), fill=0)
    d.rectangle((80, 100, 88, 106), fill=0)  # Davor's crate
    d.ellipse((204, 52, 252, 94), fill=0)  # the cairn
    d.rectangle((0, CAVE_H - 4, CAVE_W - 1, CAVE_H - 1), fill=0)
    return mask


def export():
    OUT.mkdir(parents=True, exist_ok=True)
    concept.surface(ships=False).save(OUT / "surface.png")
    concept.cave(lit=False).save(OUT / "cave_dark.png")
    concept.cave(lit=True).save(OUT / "cave_lit.png")
    concept.martin_ship().save(OUT / "martin_ship.png")
    concept.martin().save(OUT / "martin.png")
    voice().save(OUT / "voice.png")
    sealed_rocks().save(OUT / "sealed_rocks.png")
    pyjama_hacker().save(OUT / "hacker.png")
    jumpsuit_hacker().save(OUT / "hacker_trooper.png")
    for name in ("surface.png", "cave_dark.png", "martin_ship.png", "martin.png", "voice.png", "sealed_rocks.png"):
        print((OUT / name).relative_to(ROOT))


if __name__ == "__main__":
    export()
