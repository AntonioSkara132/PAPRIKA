#!/usr/bin/python3
"""Render a desert concept of Bavarin as a Republic military base, an alternative to
the autumn concept in create_bavarin_concept.py.

Layout, from the landing to Davor:
- southwest: a red-rock canyon where Veki hides the Lasta between the mesas;
- the middle south: a small oasis village of mud-brick houses, tents, palms and a
  well, where the base's soldiers and traders mix;
- dunes and rock outcrops between the village and the base give cover; the
  watchtowers' searchlights sweep the sand and a sandstorm drifts in from the east;
- the north and east: the walled base. Inside are a parade ground with the flag,
  barracks, the mess hall, an armoury, a training yard with spear dummies and archery
  targets, landing pads with Republic warships, a hangar and fuel tanks, the
  headquarters where Martin is, and the prison block where Davor is held.

Republic sprites from Artichoke are reused for the soldiers and some buildings.
Helpers come from create_otpornik_concept.py and create_bavarin_concept.py.

Writes art/concepts/bavarin_desert_concept.png (whole map, 1x) and two 2x close-ups:
bavarin_desert_concept_base.png and bavarin_desert_concept_village.png.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

import create_otpornik_concept as base
from create_otpornik_concept import (INK, canvas, box, windows, door, gable_roof, sign, shadow,
                                     wobble, blob, seg_dist, inside, load_sprite)
from create_bavarin_concept import NAVY, NAVY_DARK, NAVY_LIGHT, GOLD, GOLD_DARK, banner, lasta, WINDOW_LIT

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/bavarin_desert_concept.png"
BASE_OUT = ROOT / "art/concepts/bavarin_desert_concept_base.png"
VILLAGE_OUT = ROOT / "art/concepts/bavarin_desert_concept_village.png"
OBJ = ROOT / "assets/art/artichoke/objects"

W, H = 1280, 896
TILE = 16

SAND = (226, 190, 128)
SAND_2 = (216, 180, 120)
SAND_LIGHT = (240, 210, 156)
SAND_DARK = (190, 150, 96)
DUNE = (234, 198, 132)
DUNE_SHADE = (198, 156, 98)
ROCK = (178, 98, 64)
ROCK_DARK = (130, 66, 46)
ROCK_LIGHT = (214, 136, 90)
CANYON_FLOOR = (196, 128, 84)
CONCRETE = (176, 168, 150)
CONCRETE_2 = (164, 156, 140)
CONCRETE_DARK = (130, 122, 108)
PARADE = (196, 182, 150)
PAD = (120, 120, 126)
ADOBE = [(214, 168, 112), (200, 152, 100), (226, 184, 130), (190, 140, 96)]
ADOBE_DARK = (160, 116, 76)
SANDSTONE = (220, 186, 132)
SANDSTONE_SHADE = (186, 150, 100)
SANDSTONE_DARK = (150, 116, 78)
PALM = (86, 132, 66)
PALM_DARK = (56, 96, 50)
TRUNK = (140, 100, 60)
WATER = (70, 140, 170)
WATER_LIGHT = (150, 206, 222)
OASIS_GRASS = (140, 160, 80)
WOOD = (122, 84, 56)
WOOD_DARK = (88, 58, 40)
STEEL = (150, 156, 170)
STEEL_DARK = (104, 110, 128)
WHITE = (240, 238, 230)
RED = (190, 60, 50)
CLOTH = [(200, 70, 60), (70, 110, 150), (220, 180, 70), (150, 100, 150), (230, 220, 200)]

rng = random.Random(23)


# ---------- desert pieces ----------

def palm():
    img, d = canvas(40, 54)
    d.line([(20, 52), (18, 34), (21, 18)], fill=INK, width=5)
    d.line([(20, 52), (18, 34), (21, 18)], fill=TRUNK, width=3)
    for a in (-2.6, -1.9, -1.2, -0.4, 0.4):
        x, y = 21 + math.cos(a) * 18, 18 + math.sin(a) * 9 + 6
        d.line([(21, 18), ((21 + x) / 2, 10 + math.sin(a) * 4), (x, y)], fill=INK, width=5)
        d.line([(21, 18), ((21 + x) / 2, 10 + math.sin(a) * 4), (x, y)], fill=PALM, width=3)
    d.ellipse((17, 16, 25, 22), fill=(120, 80, 40), outline=INK)
    return img


def cactus():
    img, d = canvas(20, 30)
    box(d, (7, 4, 12, 29), PALM)
    box(d, (1, 12, 5, 20), PALM)
    d.rectangle((5, 18, 7, 20), fill=PALM)
    box(d, (14, 8, 18, 16), PALM)
    d.rectangle((12, 14, 14, 16), fill=PALM)
    d.line([(9, 6), (9, 27)], fill=PALM_DARK)
    return img


def mesa(w, h, seed):
    """A flat-topped red rock: top face, then a cliff face with layered stripes."""
    r = random.Random(seed)
    img, d = canvas(w, h)
    top_h = h // 2
    top = [(4 + r.randint(0, 8), top_h * 0.2), (w * 0.4, r.randint(0, 6)), (w - 6 - r.randint(0, 8), top_h * 0.25),
           (w - 2, top_h - 6), (w * 0.6, top_h), (8, top_h - 4)]
    face = [(8, top_h - 4), (w * 0.6, top_h), (w - 2, top_h - 6), (w - 6, h - 2), (6, h - 2)]
    d.polygon(face, fill=ROCK_DARK, outline=INK)
    for k in range(1, 4):
        y = top_h + (h - top_h) * k / 4
        d.line([(8, y), (w - 6, y - 2)], fill=ROCK)
    d.polygon(top, fill=ROCK, outline=INK)
    d.line([(top[0][0] + 6, top[0][1] + 4), (top[1][0], top[1][1] + 4)], fill=ROCK_LIGHT, width=2)
    return img


def boulder(s):
    img, d = canvas(s + 2, s)
    d.ellipse((0, 2, s, s - 1), fill=ROCK, outline=INK)
    d.ellipse((3, 3, s // 2 + 2, s // 2), fill=ROCK_LIGHT)
    return img


def skull():
    img, d = canvas(16, 8)
    d.ellipse((0, 1, 8, 7), fill=WHITE, outline=INK)
    d.line([(8, 4), (15, 2)], fill=WHITE, width=2)
    d.line([(8, 5), (15, 6)], fill=WHITE, width=2)
    return img


def dry_bush():
    img, d = canvas(20, 14)
    for a in range(-3, 4):
        d.line([(10, 13), (10 + a * 3, 3 + abs(a) * 2)], fill=(150, 110, 60), width=1)
    d.point((10, 12), fill=INK)
    return img


def rock_arch():
    img, d = canvas(80, 60)
    d.polygon([(4, 58), (8, 10), (30, 2), (54, 4), (74, 14), (76, 58), (60, 58), (58, 28), (40, 20), (24, 30), (22, 58)], fill=ROCK, outline=INK)
    d.line([(12, 14), (30, 6), (52, 8)], fill=ROCK_LIGHT, width=2)
    for y in (36, 46):
        d.line([(6, y), (20, y)], fill=ROCK_DARK)
        d.line([(60, y), (74, y)], fill=ROCK_DARK)
    return img


def wreck():
    """A half-buried old ship, sand drifted over one side."""
    img, d = canvas(110, 56)
    d.polygon([(6, 46), (20, 18), (70, 10), (100, 22), (104, 46)], fill=STEEL_DARK, outline=INK)
    d.polygon([(30, 22), (60, 16), (64, 30), (34, 34)], fill=INK)
    for x in range(26, 96, 14):
        d.line([(x, 20), (x - 4, 44)], fill=(84, 90, 106))
    d.line([(20, 18), (6, 6)], fill=STEEL, width=2)
    d.ellipse((0, 36, 110, 56), fill=SAND)
    d.arc((0, 36, 110, 56), 180, 360, fill=SAND_DARK, width=2)
    return img


# ---------- village ----------

def mud_house(w, h, dome=False):
    img, d = canvas(w + 8, h + 22)
    bs = h + 20
    plaster = rng.choice(ADOBE)
    box(d, (4, 20, w + 4, bs), plaster)
    d.rectangle((5, bs - 8, w + 3, bs - 1), fill=ADOBE_DARK)
    if dome:
        d.chord((w // 2 - 12, 4, w // 2 + 20, 36), 180, 360, fill=WHITE, outline=INK)
    else:  # flat roof with a parapet and beams sticking out
        d.rectangle((2, 14, w + 6, 21), fill=plaster, outline=INK)
        for x in range(8, w, 10):
            d.rectangle((x, 22, x + 3, 25), fill=WOOD_DARK, outline=INK)
    for x in range(10, w - 4, 16):
        d.rectangle((x, 30, x + 6, 38), fill=INK)
    d.rectangle((w // 2 - 3, bs - 16, w // 2 + 5, bs), fill=WOOD, outline=INK)
    if rng.random() < 0.4:  # awning
        c = rng.choice(CLOTH)
        d.polygon([(w // 2 - 10, bs - 22), (w // 2 + 12, bs - 22), (w // 2 + 16, bs - 14), (w // 2 - 14, bs - 14)], fill=c, outline=INK)
    return img


def tent(color):
    img, d = canvas(48, 34)
    d.polygon([(2, 32), (24, 4), (46, 32)], fill=color, outline=INK)
    d.polygon([(18, 32), (24, 18), (30, 32)], fill=INK)
    d.line([(24, 4), (24, 0)], fill=WOOD_DARK, width=2)
    d.line([(8, 26), (24, 6)], fill=tuple(min(255, c + 30) for c in color))
    return img


def well():
    img, d = canvas(36, 40)
    d.ellipse((2, 22, 33, 38), fill=SANDSTONE_SHADE, outline=INK)
    d.ellipse((7, 25, 28, 34), fill=WATER)
    for x in (4, 30):
        d.rectangle((x, 4, x + 2, 30), fill=WOOD, outline=INK)
    d.rectangle((2, 2, 33, 6), fill=WOOD_DARK, outline=INK)
    d.line([(18, 6), (18, 22)], fill=INK)
    box(d, (15, 20, 21, 25), WOOD)
    return img


def stall(color):
    img, d = canvas(44, 38)
    d.rectangle((4, 18, 40, 36), fill=WOOD, outline=INK)
    d.polygon([(0, 18), (6, 6), (38, 6), (44, 18)], fill=color, outline=INK)
    for x in (8, 18, 28):
        d.ellipse((x, 20, x + 7, 27), fill=rng.choice([(220, 120, 40), (200, 60, 60), (230, 200, 90), (120, 90, 60)]), outline=INK)
    return img


def jars():
    img, d = canvas(24, 16)
    for x, h in ((1, 12), (9, 15), (16, 11)):
        d.ellipse((x, 16 - h, x + 7, 15), fill=(190, 110, 70), outline=INK)
    return img


def camel_cart():
    img, d = canvas(50, 28)
    box(d, (2, 6, 40, 18), WOOD)
    for x in (8, 18, 28):
        box(d, (x, 0, x + 8, 6), rng.choice(CLOTH))
    for x in (10, 32):
        d.ellipse((x - 6, 14, x + 6, 26), fill=WOOD_DARK, outline=INK)
    d.line([(40, 12), (49, 12)], fill=WOOD_DARK, width=2)
    return img


# ---------- base ----------

def wall_piece(w):
    img, d = canvas(w, 30)
    box(d, (0, 6, w - 1, 29), SANDSTONE_SHADE)
    for x in range(0, w, 8):  # crenellations
        d.rectangle((x, 0, x + 4, 7), fill=SANDSTONE, outline=INK)
    d.rectangle((0, 6, w - 1, 9), fill=NAVY, outline=INK)
    for y in (16, 23):
        d.line([(1, y), (w - 2, y)], fill=SANDSTONE_DARK)
    return img


def watchtower(light=True):
    img, d = canvas(44, 96)
    bs = 94
    box(d, (10, 34, 34, bs), SANDSTONE)
    d.rectangle((11, bs - 16, 33, bs - 1), fill=SANDSTONE_SHADE)
    for y in (50, 70):
        d.rectangle((19, y, 25, y + 8), fill=INK)
    box(d, (4, 22, 40, 36), SANDSTONE)
    d.rectangle((4, 30, 40, 33), fill=NAVY, outline=INK)
    d.polygon([(2, 24), (22, 2), (42, 24)], fill=NAVY, outline=INK)
    d.line([(22, 3), (22, -6)], fill=GOLD, width=2)
    if light:
        box(d, (26, 12, 36, 20), STEEL)
        d.ellipse((34, 13, 39, 19), fill=(255, 250, 200), outline=INK)
    return img


def barracks_long(w=150):
    img, d = canvas(w, 72)
    bs = 68
    box(d, (4, 24, w - 4, bs), SANDSTONE)
    d.rectangle((5, bs - 10, w - 5, bs - 1), fill=SANDSTONE_SHADE)
    windows(d, 10, w - 10, 34, max(2, w // 22), 10, INK, SANDSTONE_DARK)
    door(d, w // 2, bs, 14, 20, NAVY_DARK)
    gable_roof(d, 4, w - 4, 2, 26, (NAVY, NAVY_DARK))
    banner(d, w // 2 - 24, 30, 16)
    return img


def headquarters():
    img, d = canvas(210, 150)
    bs = 146
    box(d, (10, 50, 200, bs), SANDSTONE)
    d.rectangle((11, bs - 22, 199, bs - 1), fill=SANDSTONE_SHADE)
    for y in (62, 92):
        windows(d, 18, 192, y, 8, 16, NAVY_LIGHT, WHITE)
    box(d, (78, 76, 132, 84), SANDSTONE)
    for x in range(82, 132, 12):
        d.rectangle((x, 84, x + 5, bs - 2), fill=WHITE, outline=INK)
    door(d, 105, bs, 20, 30, NAVY_DARK)
    d.rectangle((6, 38, 204, 52), fill=SANDSTONE, outline=INK)
    d.rectangle((6, 44, 204, 48), fill=NAVY)
    d.line([(6, 40), (204, 40)], fill=GOLD, width=2)
    # central dome with the gold sun
    d.chord((70, 0, 140, 70), 180, 360, fill=NAVY, outline=INK)
    d.arc((76, 6, 134, 64), 200, 250, fill=NAVY_LIGHT, width=3)
    d.ellipse((98, 18, 112, 32), fill=GOLD, outline=INK)
    for x in (24, 172):
        banner(d, x, 56, 26)
    return img


def prison_block():
    img, d = canvas(140, 90)
    bs = 86
    box(d, (6, 22, 134, bs), (170, 160, 146))
    d.rectangle((7, bs - 12, 133, bs - 1), fill=(146, 136, 124))
    for x in range(14, 128, 18):  # barred slit windows
        d.rectangle((x, 34, x + 8, 44), fill=INK)
        for bx in range(x + 2, x + 8, 3):
            d.line([(bx, 34), (bx, 44)], fill=STEEL)
    d.rectangle((60, 56, 80, bs), fill=STEEL_DARK, outline=INK)
    for y in range(60, bs, 6):
        d.line([(61, y), (79, y)], fill=STEEL)
    d.rectangle((2, 14, 138, 24), fill=(150, 140, 128), outline=INK)
    d.rectangle((2, 18, 138, 21), fill=NAVY)
    return img


def cell_yard_fence(w):
    img, d = canvas(w, 26)
    for x in range(0, w, 6):
        d.line([(x, 2), (x, 25)], fill=STEEL_DARK)
    d.line([(0, 3), (w - 1, 3)], fill=INK, width=2)
    d.line([(0, 24), (w - 1, 24)], fill=INK, width=2)
    for x in range(2, w, 8):  # wire on top
        d.arc((x, -2, x + 8, 5), 180, 360, fill=STEEL)
    return img


def hangar():
    img, d = canvas(190, 110)
    bs = 106
    box(d, (6, 30, 184, bs), CONCRETE)
    d.rectangle((26, 48, 164, bs), fill=(60, 58, 66), outline=INK)
    for y in range(52, bs, 6):
        d.line([(28, y), (162, y)], fill=(84, 82, 92))
    d.chord((0, 0, 190, 64), 180, 360, fill=NAVY, outline=INK)
    for x in range(20, 180, 20):
        d.line([(x, 8 if 40 < x < 150 else 18), (x, 30)], fill=NAVY_DARK)
    d.rectangle((60, 34, 130, 44), fill=GOLD, outline=INK)
    d.text((68, 34), "HANGAR 2", fill=INK)
    return img


def fuel_tank():
    img, d = canvas(40, 54)
    box(d, (4, 10, 36, 52), STEEL)
    d.ellipse((4, 2, 36, 18), fill=STEEL, outline=INK)
    d.line([(10, 16), (10, 48)], fill=(200, 206, 220), width=2)
    d.rectangle((4, 30, 36, 36), fill=NAVY, outline=INK)
    return img


def flagpole():
    img, d = canvas(40, 90)
    d.rectangle((4, 4, 6, 88), fill=STEEL_DARK, outline=INK)
    d.polygon([(7, 6), (38, 10), (36, 26), (7, 24)], fill=NAVY, outline=INK)
    d.ellipse((17, 10, 27, 20), fill=GOLD, outline=INK)
    return img


def spear_dummy():
    img, d = canvas(18, 34)
    d.rectangle((8, 8, 9, 33), fill=WOOD, outline=INK)
    d.rectangle((2, 14, 15, 17), fill=WOOD, outline=INK)
    box(d, (4, 6, 13, 24), (200, 176, 120))
    d.ellipse((5, 0, 12, 7), fill=(200, 176, 120), outline=INK)
    d.line([(4, 12), (13, 20)], fill=RED)
    return img


def target():
    img, d = canvas(24, 30)
    d.line([(6, 18), (2, 29)], fill=WOOD, width=2)
    d.line([(18, 18), (22, 29)], fill=WOOD, width=2)
    d.ellipse((1, 1, 23, 23), fill=WHITE, outline=INK)
    d.ellipse((5, 5, 19, 19), fill=RED)
    d.ellipse((9, 9, 15, 15), fill=GOLD)
    return img


def weapon_rack():
    img, d = canvas(40, 34)
    d.rectangle((2, 24, 38, 28), fill=WOOD, outline=INK)
    for x in range(6, 36, 6):
        d.line([(x, 2), (x, 30)], fill=WOOD_DARK, width=2)
        d.polygon([(x - 2, 4), (x, 0), (x + 2, 4)], fill=STEEL, outline=INK)
    return img


def crate_stack():
    s = load_sprite(OBJ / "republic_munitions_crate.png")
    return s


def landing_pad(d, cx, cy, r):
    d.ellipse((cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), fill=PAD, outline=INK)
    d.ellipse((cx - r + 8, cy - r * 0.6 + 6, cx + r - 8, cy + r * 0.6 - 6), outline=GOLD, width=2)
    d.text((cx - 3, cy - 6), "R", fill=GOLD)


def searchlight(img, x, y, angle, length=170, spread=0.22):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a0, a1 = angle - spread, angle + spread
    d.polygon([(x, y), (x + math.cos(a0) * length, y + math.sin(a0) * length),
               (x + math.cos(a1) * length, y + math.sin(a1) * length)], fill=(255, 250, 200, 46))
    ex, ey = x + math.cos(angle) * length, y + math.sin(angle) * length
    d.ellipse((ex - 34, ey - 18, ex + 34, ey + 18), fill=(255, 250, 200, 56))
    img.alpha_composite(layer)


# ---------- ground ----------

BASE = [(560, 30), (760, 18), (980, 22), (1270, 16), (1272, 560), (1150, 574), (980, 560), (840, 572), (700, 548), (590, 470), (540, 300), (530, 140)]
CANYON = [(0, 520), (120, 560), (230, 600), (300, 690), (330, 790), (300, 896), (0, 896)]
OASIS = blob(420, 760, 120, 66, 31, jag=0.12)
POOL = blob(430, 770, 56, 26, 32, jag=0.18)
RIDGE = [(0, 0), (540, 0), (520, 70), (420, 110), (300, 90), (200, 140), (80, 120), (0, 160)]
PARADE_GROUND = [(720, 250), (930, 240), (950, 380), (730, 390)]
PADS = [(1050, 120, 70), (1190, 140, 60)]
ROADS = [
    ([(200, 760), (300, 740), (380, 720)], 16, SAND_DARK),                          # canyon track to the village
    ([(480, 720), (560, 660), (640, 600), (720, 560), (760, 540)], 34, CONCRETE),     # village road up to the main gate
    ([(760, 540), (820, 400), (840, 300)], 30, CONCRETE),                             # inside the gate to the parade ground
    ([(840, 300), (980, 220), (1080, 160)], 28, CONCRETE),                            # to the pads
    ([(950, 320), (1080, 380), (1180, 420)], 24, CONCRETE),                           # to the prison block
    ([(500, 800), (620, 860), (700, 896)], 20, SAND_DARK),                            # trade track south
]
DUNES = [(700, 680, 140, 40), (900, 640, 120, 34), (1080, 700, 160, 46), (860, 800, 180, 50), (1180, 820, 120, 40), (600, 780, 80, 24), (340, 400, 120, 40), (180, 330, 110, 34), (420, 560, 90, 30)]
STORM = [(1150, 650, 180, 70), (1000, 760, 140, 50), (1240, 500, 80, 60)]


def road_paths():
    return [wobble(p, amount=w / 6, seed=50 + i) for i, (p, w, _) in enumerate(ROADS)]


def ground(img):
    d = ImageDraw.Draw(img)
    for ty in range(0, H, TILE):
        for tx in range(0, W, TILE):
            c = SAND if (tx // TILE * 7 + ty // TILE * 3) % 5 else SAND_2
            d.rectangle((tx, ty, tx + TILE - 1, ty + TILE - 1), fill=c)
            if rng.random() < 0.18:
                x, y = tx + rng.randint(2, 13), ty + rng.randint(2, 13)
                d.line([(x, y), (x + 3, y)], fill=SAND_LIGHT if rng.random() < 0.6 else SAND_DARK)
    # dunes: a sharp curved crest, lit sand on the windward side, shade behind it
    for i, (cx, cy, rx, ry) in enumerate(DUNES):
        crest = [(cx - rx + 2 * rx * t / 12, cy - ry * 0.2 + math.sin(t / 12 * math.pi) * -ry * 0.7 + (t % 3 - 1) * 2) for t in range(13)]
        back = [(cx + rx * 0.9 - 2 * rx * 0.9 * t / 10, cy + ry * 0.5 + math.sin(t / 10 * math.pi) * ry * 0.3) for t in range(11)]
        lit = [(cx - rx * 0.9 + 2 * rx * 0.9 * t / 10, cy - ry * 1.1 - math.sin(t / 10 * math.pi) * ry * 0.4) for t in range(11)]
        d.polygon(crest + list(reversed(lit)), fill=SAND_LIGHT)
        d.polygon(crest + back, fill=DUNE_SHADE)
        d.line(crest, fill=(250, 226, 176), width=2)
        for k in range(1, 3):
            d.line([(x + 6 * k, y + ry * 0.25 * k) for x, y in crest[2:-2]], fill=SAND_DARK)
    # northern ridge and the canyon in the southwest
    d.polygon(wobble(RIDGE, amount=8, seed=2), fill=ROCK_DARK, outline=INK)
    d.polygon(wobble(CANYON, amount=10, seed=3), fill=CANYON_FLOOR)
    for _ in range(500):
        x, y = rng.randint(0, 340), rng.randint(520, H - 1)
        if inside(CANYON, x, y):
            d.point((x, y), fill=ROCK_DARK)
    # oasis
    d.polygon(OASIS, fill=OASIS_GRASS, outline=SAND_DARK)
    d.polygon(POOL, fill=WATER, outline=INK)
    d.arc((400, 756, 450, 776), 200, 300, fill=WATER_LIGHT, width=2)
    # base ground: packed concrete with seams
    d.polygon(BASE, fill=CONCRETE)
    for ty in range(0, 600, 32):
        for tx in range(520, W, 32):
            if (tx // 32 + ty // 32) % 2 and inside(BASE, tx + 16, ty + 16):
                d.rectangle((tx, ty, tx + 31, ty + 31), fill=CONCRETE_2)
    d.polygon(PARADE_GROUND, fill=PARADE, outline=CONCRETE_DARK)
    for i in range(5):
        d.line([(740 + i * 44, 256), (744 + i * 44, 380)], fill=(214, 200, 168))
    for cx, cy, r in PADS:
        landing_pad(d, cx, cy, r)
    edge = BASE[-3:] + BASE[:5]
    d.line(edge, fill=INK, width=12, joint="curve")
    d.line(edge, fill=SANDSTONE_SHADE, width=9, joint="curve")
    d.line([(x - 2, y - 2) for x, y in edge], fill=SANDSTONE, width=3, joint="curve")
    for (x0, y0), (x1, y1) in zip(edge, edge[1:]):
        n = int(math.hypot(x1 - x0, y1 - y0) // 10)
        for k in range(n):
            x, y = x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n
            d.rectangle((x - 2, y - 7, x + 2, y - 3), fill=SANDSTONE, outline=INK)
    # roads
    for path, (_, width, colour) in zip(road_paths(), ROADS):
        edge = CONCRETE_DARK if colour == CONCRETE else (170, 132, 84)
        d.line(path, fill=edge, width=width + 6, joint="curve")
        d.line(path, fill=colour, width=width, joint="curve")
    # tyre and boot tracks in the sand
    for line in ([(380, 720), (360, 600), (420, 480), (520, 420)], [(880, 580), (980, 640), (1100, 640)]):
        d.line(wobble(line, amount=4, seed=7), fill=SAND_DARK, width=1)


def sandstorm(img):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = random.Random(9)
    for cx, cy, rx, ry in STORM:
        for k in range(5):
            d.ellipse((cx - rx + k * 16, cy - ry + k * 6, cx + rx - k * 16, cy + ry - k * 6), fill=(236, 206, 150, 38))
    for _ in range(260):  # blowing sand streaks, mostly on the east side
        x, y = r.randint(500, W - 10), r.randint(380, H - 4)
        d.line([(x, y), (x - r.randint(6, 16), y + 1)], fill=(250, 226, 176, 120))
    img.alpha_composite(layer)


# ---------- assembly ----------

def build():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    ground(img)
    sprites = []
    taken = []

    def put(sprite, x, bottom, label=None, label_y=None):
        if sprite is None:
            return
        sprites.append((bottom, sprite, x, label, label_y))
        taken.append((x, bottom - sprite.height * 0.55, x + sprite.width, bottom))

    def free(x0, y0, x1, y1):
        return all(not (x0 < a[2] and x1 > a[0] and y0 < a[3] and y1 > a[1]) for a in taken)

    paths = road_paths()

    def clear(x0, x1, y, pad=6):
        for path, (_, width, _) in zip(paths, ROADS):
            for a, b in zip(path, path[1:]):
                for px in (x0, (x0 + x1) / 2, x1):
                    if seg_dist(px, y - 6, a, b) < width / 2 + pad:
                        return False
        return True

    # --- the base ---
    put(headquarters(), 760, 200, "HEADQUARTERS (Martin)", 204)
    put(flagpole(), 820, 300)
    put(prison_block(), 1110, 486, "PRISON BLOCK (Davor)", 490)
    put(cell_yard_fence(110), 990, 520)
    put(hangar(), 1060, 300, "HANGAR", 304)
    for x in (1210, 1236):
        put(fuel_tank(), x, 300 + (x - 1210))
    warship = load_sprite(OBJ / "republic_warship_flagship.png")
    escort = load_sprite(OBJ / "republic_warship_escort.png")
    put(warship, 980, 150, "MARTIN'S SHIP", 156)
    put(escort, 1142, 164)
    barr_a = load_sprite(OBJ / "republic_barracks_a.png")
    barr_b = load_sprite(OBJ / "republic_barracks_b.png")
    put(barracks_long(150), 580, 250, "BARRACKS", 254)
    put(barracks_long(130), 580, 360)
    put(barr_a, 600, 440)
    put(barr_b, 670, 470)
    put(load_sprite(OBJ / "republic_cafeteria.png"), 960, 400, "MESS HALL", 404)
    put(load_sprite(OBJ / "republic_weapons_storage.png"), 1150, 380, "ARMOURY", 384)
    for x, y in ((960, 470), (992, 474), (976, 450), (1240, 420)):
        put(crate_stack(), x, y)
    put(load_sprite(OBJ / "republic_tnt_pile.png"), 1240, 456)
    put(load_sprite(OBJ / "republic_cannon.png"), 620, 520)
    put(load_sprite(OBJ / "republic_cannon.png"), 880, 540)
    # training yard on the parade ground
    for x in range(750, 900, 30):
        put(spear_dummy(), x, 380)
    for x in (880, 912, 944):
        put(target(), x, 340)
    put(weapon_rack(), 900, 384)
    # walls with towers, the main gate on the south side
    for x0, x1, y in ((560, 740, 556), (790, 990, 570), (990, 1272, 576)):
        for x in range(x0, x1, 48):
            put(wall_piece(min(48, x1 - x)), x, y)
    for x, y in ((520, 560), (540, 300), (540, 120), (990, 586), (1236, 590), (1236, 40)):
        put(watchtower(), x, y)
    put(load_sprite(OBJ / "republic_gate.png"), 740, 560, "MAIN GATE", 564)
    for x, y in ((760, 34), (1000, 36)):
        put(watchtower(), x, y)

    # --- dunes and cover between village and base ---
    for x, y, s in ((640, 640, 22), (700, 700, 16), (880, 660, 20), (940, 720, 14), (1040, 640, 18), (1200, 700, 24), (480, 600, 18), (360, 500, 20), (280, 420, 16)):
        put(boulder(s), x, y)
    for x, y in ((560, 700), (820, 760), (1000, 820), (1150, 760), (300, 470), (450, 470), (150, 420), (660, 860)):
        put(cactus(), x, y)
    put(skull(), 760, 720)
    put(wreck(), 300, 360, "OLD WRECK", 364)
    put(rock_arch(), 380, 480)
    for x, y in ((240, 420), (420, 380), (200, 520), (470, 280), (330, 300), (110, 470)):
        put(dry_bush(), x, y)
    put(skull(), 230, 470)

    # --- canyon with the hidden Lasta, southwest ---
    for x, y, w, h, s in ((-20, 560, 150, 90, 1), (110, 620, 120, 70, 2), (230, 700, 90, 80, 3), (250, 820, 100, 70, 4), (-10, 900, 120, 70, 5), (-20, 380, 140, 90, 6), (160, 280, 130, 80, 7), (360, 220, 110, 70, 8), (20, 240, 100, 70, 9)):
        put(mesa(w, h, s), x, y)
    put(lasta(), 40, 770, "LASTA (in the canyon)", 774)

    # --- oasis village, south middle ---
    put(well(), 520, 740)
    put(stall(CLOTH[0]), 560, 800)
    put(stall(CLOTH[1]), 600, 760)
    put(jars(), 610, 806)
    put(camel_cart(), 470, 830)
    for x, y in ((330, 730), (390, 720), (500, 760), (350, 820), (490, 800), (420, 836), (300, 790)):
        put(palm(), x, y)
    rng.seed(29)
    for _ in range(200):
        w = rng.choice([34, 40, 46, 52])
        h = rng.choice([28, 34, 40])
        ox, bottom = rng.uniform(330, 760), rng.uniform(640, 890)
        x0, x1, top = ox, ox + w + 8, bottom - (h + 22) * 0.55
        if inside(POOL, (x0 + x1) / 2, bottom) or inside(BASE, x0, top) or inside(CANYON, x0, bottom):
            continue
        if clear(x0, x1, bottom) and free(x0, top - 4, x1, bottom + 4):
            put(mud_house(w, h, rng.random() < 0.25), ox, bottom)
    for i, (x, y) in enumerate(((620, 870), (680, 830), (760, 870))):
        put(tent(CLOTH[i + 1]), x, y)
    sign(img, 700, 880, "TO THE CARAVAN ROUTE", bg=NAVY, fg=GOLD)

    # --- people ---
    reps = [load_sprite(OBJ / f"republic_soldier{s}.png") for s in ("", "_2", "_3", "_4", "_5", "_6", "_7")]
    reps = [s for s in reps if s is not None]
    guard = load_sprite(OBJ / "republic_guardsman.png")
    for x, y in ((730, 590), (800, 590)):
        put(guard, x, y)
    drill = [(760 + c * 26, 280 + r * 24) for r in range(3) for c in range(4)]
    for i, (x, y) in enumerate(drill):  # soldiers drilling on the parade ground
        put(reps[i % len(reps)], x, y)
    patrols = [(620, 300), (990, 200), (1180, 220), (1060, 430), (1200, 500), (900, 470), (640, 520), (560, 760), (600, 840), (1000, 340)]
    for i, (x, y) in enumerate(patrols):
        put(reps[(i + 3) % len(reps)], x, y)
    put(guard, 1090, 520)
    put(load_sprite(ROOT / "assets/art/rock/martin.png"), 830, 210)
    put(load_sprite(ROOT / "assets/art/engineeria/davor.png"), 1040, 514)
    pool = base.npc_pool()
    r = random.Random(4)
    for x, y in ((540, 770), (580, 820), (450, 750), (640, 790), (520, 860), (400, 860)):
        if pool:
            s = r.choice(pool)
            put(s, x - s.width // 2, y)
    put(load_sprite(ROOT / "assets/art/player_blue.png"), 150, 760)
    put(load_sprite(ROOT / "assets/art/smokva/donat.png"), 172, 768)
    put(load_sprite(ROOT / "assets/art/iskra/npcs/veki.png"), 128, 786)

    sprites.sort(key=lambda s: s[0])
    for bottom, sprite, x, label, label_y in sprites:
        shadow(img, x + 2, bottom - 4, x + sprite.width - 2, bottom + 4)
        img.alpha_composite(sprite, (int(x), int(bottom - sprite.height)))
    # searchlights from the towers sweep the sand outside the walls
    for x, y, a in ((542, 480, 2.3), (1012, 500, 1.9), (1258, 510, 1.6), (562, 220, 3.0)):
        searchlight(img, x, y, a)
    sandstorm(img)
    for bottom, sprite, x, label, label_y in sprites:
        if label:
            sign(img, int(x + sprite.width // 2), label_y, label)
    for text, x, y in (("CANYON", 120, 870), ("OASIS VILLAGE", 440, 640), ("DUNES", 900, 610), ("REPUBLIC BASE BAVARIN", 900, 4), ("SANDSTORM", 1180, 610)):
        sign(img, x, y, text, bg=GOLD, fg=INK)
    return img


def main():
    img = build().convert("RGB")
    img.save(OUT)
    img.crop((520, 0, 1280, 600)).resize((1520, 1200), Image.NEAREST).save(BASE_OUT)
    img.crop((0, 560, 800, 896)).resize((1600, 672), Image.NEAREST).save(VILLAGE_OUT)
    for path in (OUT, BASE_OUT, VILLAGE_OUT):
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
