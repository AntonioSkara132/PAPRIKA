#!/usr/bin/python3
"""Render an autumn concept of Bavarin, the first Republic planet the player visits.

Layout, from the landing to Davor:
- southwest: a forest clearing where Veki sets the Lasta down, away from the port;
- a forest path to a stream with a stone bridge, and a hunter's hut on the way;
- the middle: a quiet, wealthy Republic town with a market square, a tavern
  and patrols, navy-and-gold banners on the houses;
- the east: orchards and vineyards climbing towards the estate, with hedges,
  leaf piles that rustle and evening fog for sneaking;
- the northeast: the walled officers' estate with its gardens, a guard house,
  and the cellar where Davor is held. Martin waits in the gardens.

Helpers and the drawing style come from create_otpornik_concept.py: 16-pixel
ground, sprites sorted by their bottom edge, #1c1730 outlines, flat shading.

Writes art/concepts/bavarin_concept.png (whole map, 1x) and two 2x close-ups:
bavarin_concept_estate.png and bavarin_concept_town.png.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

import create_otpornik_concept as base
from create_otpornik_concept import (INK, canvas, box, windows, door, gable_roof, sign, shadow,
                                     wobble, blob, seg_dist, inside, load_sprite, townhouse, lamp)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/bavarin_concept.png"
ESTATE_OUT = ROOT / "art/concepts/bavarin_concept_estate.png"
TOWN_OUT = ROOT / "art/concepts/bavarin_concept_town.png"

W, H = 1280, 896
TILE = 16

# autumn ground: the grass has gone olive and ochre
GRASS = (150, 150, 84)
GRASS_2 = (140, 140, 78)
GRASS_LIGHT = (184, 170, 96)
FOREST_FLOOR = (118, 86, 58)
FOREST_FLOOR_2 = (106, 76, 52)
DIRT = (166, 128, 88)
DIRT_DARK = (130, 98, 66)
COBBLE = (176, 168, 156)
COBBLE_2 = (160, 152, 142)
COBBLE_DARK = (128, 120, 112)
GRAVEL = (206, 196, 172)
LAWN = (120, 146, 84)
LAWN_2 = (110, 136, 78)
WATER = (70, 112, 140)
WATER_LIGHT = (140, 180, 196)
STONE = (222, 210, 186)
STONE_SHADE = (186, 172, 148)
STONE_DARK = (140, 126, 106)
WOOD = (122, 84, 56)
WOOD_DARK = (88, 58, 40)

# leaves
LEAF_COLOURS = [
    ((214, 96, 40), (164, 62, 30), (240, 150, 70)),    # orange
    ((186, 46, 40), (130, 30, 34), (226, 92, 70)),     # red
    ((226, 176, 54), (176, 126, 36), (248, 216, 110)),  # yellow
    ((160, 70, 50), (116, 48, 40), (200, 112, 80)),    # rust
]
PINE = (54, 86, 62)
PINE_DARK = (36, 60, 46)

# Republic colours: navy and gold
NAVY = (36, 52, 102)
NAVY_DARK = (24, 34, 70)
NAVY_LIGHT = (70, 92, 150)
GOLD = (222, 180, 62)
GOLD_DARK = (170, 128, 40)

PLASTER = [(234, 222, 196), (226, 206, 180), (214, 200, 176), (238, 228, 210), (220, 196, 168)]
ROOFS = [(NAVY, NAVY_DARK), ((150, 64, 48), (110, 44, 36)), ((92, 84, 96), (66, 60, 72)), ((126, 70, 52), (92, 50, 38))]
WINDOW = (64, 92, 120)
WINDOW_LIT = (248, 206, 110)
APPLE = (200, 44, 40)
PUMPKIN = (226, 120, 36)
GRAPE = (96, 52, 110)
HEDGE = (66, 104, 58)
HEDGE_DARK = (44, 76, 44)
HEDGE_LIGHT = (96, 136, 74)
WHITE = (240, 238, 230)

rng = random.Random(41)


# ---------- trees and plants ----------

def autumn_tree(kind=None, big=False, bare=False):
    s = 46 if big else 34
    img, d = canvas(s, s + 14)
    leaf, dark, light = LEAF_COLOURS[kind if kind is not None else rng.randrange(4)]
    d.rectangle((s // 2 - 3, s - 8, s // 2 + 2, s + 12), fill=WOOD, outline=INK)
    if bare:  # nearly bare: branches and a few leaves left
        for a in (-0.9, -0.4, 0.3, 0.8):
            x = s // 2 + int(math.sin(a) * s * 0.42)
            y = s // 2 - int(math.cos(a) * s * 0.3)
            d.line([(s // 2, s - 6), (x, y)], fill=WOOD_DARK, width=2)
        for _ in range(8):
            x, y = rng.randint(4, s - 6), rng.randint(4, s - 12)
            d.rectangle((x, y, x + 2, y + 2), fill=leaf)
        return img
    d.ellipse((1, 1, s - 2, s - 2), fill=leaf, outline=INK)
    d.ellipse((5, 4, s - 12, s - 14), fill=light)
    d.arc((2, 2, s - 3, s - 3), 20, 120, fill=dark, width=3)
    for _ in range(5):
        x, y = rng.randint(6, s - 8), rng.randint(6, s - 10)
        d.point((x, y), fill=dark)
    return img


def pine():
    img, d = canvas(30, 50)
    d.rectangle((13, 38, 16, 48), fill=WOOD, outline=INK)
    for i, (w, y) in enumerate(((26, 26), (20, 14), (12, 2))):
        d.polygon([(15, y), (15 + w // 2 + 2, y + 16), (15 - w // 2 - 2, y + 16)], fill=PINE, outline=INK)
        d.line([(15, y + 3), (15 + w // 2 - 2, y + 14)], fill=PINE_DARK)
    return img


def apple_tree():
    img, d = canvas(28, 38)
    d.rectangle((12, 22, 15, 36), fill=WOOD, outline=INK)
    d.ellipse((1, 1, 26, 26), fill=(110, 130, 60), outline=INK)
    d.ellipse((4, 3, 18, 15), fill=(160, 150, 70))
    for _ in range(6):
        x, y = rng.randint(4, 21), rng.randint(5, 21)
        d.rectangle((x, y, x + 2, y + 2), fill=APPLE, outline=None)
    return img


def vine_row(w):
    img, d = canvas(w, 22)
    d.line([(2, 8), (w - 3, 8)], fill=STONE_DARK)
    for x in range(2, w - 2, 12):
        d.rectangle((x, 4, x + 1, 21), fill=WOOD_DARK)
    for x in range(0, w - 6, 6):
        c = LEAF_COLOURS[rng.choice([0, 2, 3])][0]
        d.ellipse((x, 6, x + 8, 16), fill=c, outline=INK)
        if rng.random() < 0.4:
            d.ellipse((x + 2, 12, x + 6, 18), fill=GRAPE, outline=INK)
    return img


def hedge(w, h=14):
    img, d = canvas(w, h + 6)
    d.rounded_rectangle((0, 2, w - 1, h + 4), 4, fill=HEDGE, outline=INK)
    d.line([(3, 5), (w - 4, 5)], fill=HEDGE_LIGHT)
    d.line([(3, h + 1), (w - 4, h + 1)], fill=HEDGE_DARK, width=2)
    return img


def leaf_pile():
    img, d = canvas(26, 12)
    d.ellipse((0, 2, 25, 11), fill=LEAF_COLOURS[0][1], outline=INK)
    d.ellipse((3, 2, 20, 8), fill=LEAF_COLOURS[rng.choice([0, 2])][0])
    for _ in range(6):
        x, y = rng.randint(3, 21), rng.randint(3, 8)
        d.point((x, y), fill=LEAF_COLOURS[rng.randrange(4)][2])
    return img


def pumpkin():
    img, d = canvas(14, 11)
    d.ellipse((0, 2, 13, 10), fill=PUMPKIN, outline=INK)
    d.line([(7, 3), (7, 9)], fill=(176, 86, 26))
    d.rectangle((6, 0, 7, 2), fill=(90, 110, 50))
    return img


def haystack():
    img, d = canvas(30, 28)
    d.ellipse((0, 4, 29, 27), fill=(214, 182, 96), outline=INK)
    for x in range(5, 26, 4):
        d.line([(x, 10), (x - 1, 24)], fill=(176, 142, 66))
    return img


def basket():
    img, d = canvas(16, 12)
    box(d, (1, 4, 14, 11), (170, 120, 70))
    for x in (4, 8, 11):
        d.ellipse((x - 2, 1, x + 2, 5), fill=APPLE, outline=INK)
    return img


def rock(s):
    img, d = canvas(s + 2, s)
    d.ellipse((0, 2, s, s - 1), fill=(140, 132, 124), outline=INK)
    d.ellipse((3, 3, s // 2, s // 2), fill=(176, 170, 160))
    return img


# ---------- buildings ----------

def banner(d, x, y, h=20):
    """A navy Republic banner with a gold sun."""
    d.rectangle((x, y, x + 8, y + h), fill=NAVY, outline=INK)
    d.polygon([(x, y + h), (x + 4, y + h - 4), (x + 8, y + h)], fill=(0, 0, 0, 0))
    d.ellipse((x + 2, y + 5, x + 6, y + 9), fill=GOLD)
    d.line([(x + 1, y + 1), (x + 7, y + 1)], fill=GOLD)


def republic_house(w, h, roof, plaster):
    img = townhouse(w, h, roof, plaster, rng.choice([0, 0, 1]))
    d = ImageDraw.Draw(img)
    if rng.random() < 0.45:
        banner(d, 8, 36, 18)
    if rng.random() < 0.3:  # window box with flowers
        d.rectangle((10, 50, 24, 53), fill=WOOD, outline=INK)
        d.point((13, 49), fill=APPLE)
        d.point((19, 49), fill=PUMPKIN)
    return img


def manor():
    """The officers' estate: a long stone house, navy roof with gold ridges, two corner towers."""
    img, d = canvas(300, 170)
    bs = 166
    box(d, (30, 58, 270, bs), STONE)
    d.rectangle((31, bs - 26, 269, bs - 1), fill=STONE_SHADE)
    for y in (72, 104):
        windows(d, 40, 260, y, 9, 16, WINDOW, (120, 150, 180))
    # columned porch
    box(d, (118, 98, 182, 108), STONE)
    for x in range(122, 182, 14):
        d.rectangle((x, 108, x + 5, bs - 2), fill=WHITE, outline=INK)
    door(d, 150, bs, 20, 30, NAVY_DARK)
    gable_roof(d, 30, 270, 26, 60, (NAVY, NAVY_DARK))
    d.line([(38, 26), (262, 26)], fill=GOLD, width=2)
    d.polygon([(120, 60), (150, 34), (180, 60)], fill=STONE, outline=INK)
    d.ellipse((143, 42, 157, 56), fill=GOLD, outline=INK)
    # corner towers
    for x0 in (2, 248):
        box(d, (x0, 40, x0 + 50, bs), STONE)
        d.rectangle((x0 + 1, bs - 26, x0 + 49, bs - 1), fill=STONE_SHADE)
        for y in (60, 92, 124):
            windows(d, x0 + 4, x0 + 46, y, 2, 14, WINDOW, (120, 150, 180))
        d.polygon([(x0 - 4, 42), (x0 + 25, 0), (x0 + 54, 42)], fill=NAVY, outline=INK)
        d.line([(x0 + 25, 2), (x0 + 25, -10)], fill=GOLD, width=2)
        banner(d, x0 + 21, 52, 22)
    return img


def cellar_door():
    """Stone steps down into the cellar, behind an iron grate."""
    img, d = canvas(44, 34)
    box(d, (2, 8, 41, 33), STONE_SHADE)
    for i, y in enumerate(range(12, 32, 5)):
        d.rectangle((6 + i * 2, y, 37 - i * 2, y + 4), fill=(96, 88, 80) if i % 2 else (78, 72, 66), outline=INK)
    for x in range(6, 40, 5):
        d.line([(x, 8), (x, 30)], fill=(60, 60, 70))
    d.rectangle((0, 2, 43, 9), fill=STONE, outline=INK)
    return img


def guard_house():
    img, d = canvas(90, 76)
    bs = 72
    box(d, (6, 26, 84, bs), STONE)
    windows(d, 10, 50, 36, 2, 12)
    door(d, 66, bs, 14, 20, NAVY_DARK)
    gable_roof(d, 6, 84, 2, 28, (NAVY, NAVY_DARK))
    banner(d, 52, 30, 16)
    return img


def gate_towers():
    img, d = canvas(130, 90)
    bs = 86
    for x0 in (2, 92):
        box(d, (x0, 20, x0 + 36, bs), STONE)
        d.polygon([(x0 - 3, 22), (x0 + 18, 0), (x0 + 39, 22)], fill=NAVY, outline=INK)
        banner(d, x0 + 14, 30, 22)
    d.rectangle((38, 34, 92, 42), fill=STONE, outline=INK)
    for x in range(42, 90, 6):  # iron gate, open
        d.line([(x, 42), (x, bs - 2)], fill=(60, 60, 70)) if x < 50 or x > 82 else None
    d.line([(38, 38), (92, 38)], fill=GOLD)
    return img


def gazebo():
    img, d = canvas(56, 54)
    for x in (8, 26, 46):
        d.rectangle((x, 22, x + 3, 52), fill=WHITE, outline=INK)
    d.polygon([(0, 24), (28, 2), (55, 24)], fill=NAVY, outline=INK)
    d.line([(4, 22), (52, 22)], fill=GOLD, width=2)
    return img


def statue():
    img, d = canvas(24, 46)
    box(d, (3, 30, 20, 45), STONE_SHADE)
    d.rectangle((8, 8, 15, 30), fill=STONE, outline=INK)
    d.ellipse((7, 0, 16, 9), fill=STONE, outline=INK)
    d.line([(15, 12), (21, 4)], fill=STONE_DARK, width=2)  # raised sword
    return img


def fountain():
    img = base.fountain()
    d = ImageDraw.Draw(img)
    d.ellipse((24, 0, 39, 8), fill=GOLD, outline=INK)
    for x, y in ((14, 24), (40, 30), (30, 34)):
        d.point((x, y), fill=LEAF_COLOURS[0][0])
    return img


def tavern():
    img, d = canvas(130, 96)
    bs = 92
    box(d, (6, 24, 124, bs), PLASTER[1])
    for x in range(6, 124, 10):  # timber frame
        d.line([(x, 26), (x, 54)], fill=WOOD_DARK)
    d.line([(6, 54), (124, 54)], fill=WOOD_DARK, width=2)
    windows(d, 10, 120, 60, 4, 14, WINDOW_LIT, WHITE)
    door(d, 65, bs, 18, 24)
    gable_roof(d, 6, 124, 0, 26, ROOFS[1])
    for x in (16, 112):  # barrels
        box(d, (x - 7, bs - 14, x + 7, bs), WOOD)
        d.line([(x - 7, bs - 7), (x + 7, bs - 7)], fill=INK)
    return img


def market_stall(color, goods):
    img, d = canvas(44, 40)
    d.rectangle((4, 18, 40, 38), fill=WOOD, outline=INK)
    for i, x in enumerate(range(2, 42, 8)):
        d.rectangle((x, 6, x + 8, 18), fill=color if i % 2 else WHITE, outline=INK)
    for x in (8, 18, 28):
        d.ellipse((x, 20, x + 7, 27), fill=goods, outline=INK)
    return img


def wine_press():
    img, d = canvas(70, 64)
    bs = 60
    box(d, (6, 24, 64, bs), PLASTER[4])
    d.rectangle((22, 34, 48, bs), fill=WOOD_DARK, outline=INK)
    gable_roof(d, 6, 64, 0, 26, ROOFS[3])
    for x in (10, 58):
        box(d, (x - 6, bs - 12, x + 6, bs), WOOD)
    return img


def hunter_hut():
    img, d = canvas(64, 58)
    bs = 54
    box(d, (6, 22, 58, bs), WOOD)
    for y in range(26, bs, 6):
        d.line([(7, y), (57, y)], fill=WOOD_DARK)
    door(d, 22, bs, 12, 18, WOOD_DARK)
    windows(d, 34, 56, 30, 1, 10, WINDOW_LIT, WHITE)
    gable_roof(d, 6, 58, 0, 24, ((112, 96, 70), (84, 70, 52)))
    d.rectangle((44, 0, 50, 10), fill=STONE_DARK, outline=INK)  # chimney
    return img


def woodpile():
    img, d = canvas(34, 18)
    for row, y in enumerate((10, 4)):
        for x in range(1 + row * 4, 30 - row * 4, 7):
            d.ellipse((x, y, x + 7, y + 7), fill=(170, 126, 80), outline=INK)
            d.point((x + 3, y + 3), fill=WOOD_DARK)
    return img


def bridge():
    img, d = canvas(84, 40)
    d.polygon([(0, 14), (84, 14), (84, 34), (0, 34)], fill=STONE, outline=INK)
    for x in range(4, 80, 8):
        d.line([(x, 15), (x, 33)], fill=STONE_SHADE)
    d.rectangle((0, 8, 83, 14), fill=STONE_SHADE, outline=INK)
    d.rectangle((0, 33, 83, 39), fill=STONE_SHADE, outline=INK)
    return img


def wall_piece(w):
    img, d = canvas(w, 26)
    box(d, (0, 4, w - 1, 25), STONE_SHADE)
    d.rectangle((0, 0, w - 1, 6), fill=STONE, outline=INK)
    for y in (12, 19):
        for x in range(4 + (y % 2) * 6, w - 4, 12):
            d.line([(x, y - 4), (x, y + 2)], fill=STONE_DARK)
        d.line([(1, y), (w - 2, y)], fill=STONE_DARK)
    return img


def lantern_post():
    img = lamp()
    d = ImageDraw.Draw(img)
    d.rectangle((1, 0, 8, 7), fill=WINDOW_LIT, outline=INK)
    return img


def cart():
    img, d = canvas(44, 30)
    box(d, (4, 6, 40, 20), WOOD)
    for x in (10, 20, 30):
        d.ellipse((x - 4, 2, x + 4, 10), fill=PUMPKIN if x != 20 else APPLE, outline=INK)
    for x in (10, 34):
        d.ellipse((x - 6, 16, x + 6, 28), fill=WOOD_DARK, outline=INK)
    return img


def lasta():
    s = load_sprite(ROOT / "assets/art/otpornik/lasta.png")
    if s is None:
        return None
    return s.resize((s.width * 3 // 4, s.height * 3 // 4), Image.NEAREST)


# ---------- ground ----------

FOREST_WEST = [(0, 0), (300, 0), (330, 120), (300, 230), (360, 340), (330, 460), (380, 560), (340, 680), (400, 780), (380, 896), (0, 896)]
FOREST_NORTH = [(300, 0), (860, 0), (840, 60), (700, 90), (560, 70), (430, 110), (330, 120)]
CLEARING = blob(170, 690, 130, 84, 11, jag=0.14)
STREAM = [(470, -10), (450, 80), (476, 170), (440, 260), (468, 360), (452, 470), (488, 560), (450, 680), (476, 790), (452, 906)]
ESTATE = [(900, 30), (1010, 14), (1130, 26), (1270, 18), (1272, 300), (1180, 312), (1080, 300), (990, 316), (910, 290), (880, 160)]
ORCHARD = [(800, 340), (930, 330), (1080, 350), (1270, 330), (1272, 560), (1100, 590), (960, 580), (840, 560), (790, 450)]
VINEYARD = [(900, 620), (1080, 610), (1272, 600), (1272, 880), (1120, 890), (960, 870), (880, 760)]
SQUARE = blob(690, 470, 92, 58, 12, jag=0.12)
STREETS = [
    ([(200, 640), (280, 600), (360, 560), (430, 510), (520, 480), (600, 470)], 20, DIRT),     # forest path to the bridge and town
    ([(780, 470), (830, 420), (880, 380), (930, 330), (980, 300), (1010, 290)], 30, COBBLE),  # up through the orchard to the gate
    ([(690, 530), (700, 620), (720, 720), (700, 820), (720, 900)], 30, COBBLE),             # south, towards the port
    ([(560, 640), (640, 650), (720, 640), (800, 660), (880, 700)], 22, COBBLE),
    ([(620, 420), (600, 340), (640, 250), (620, 170)], 20, COBBLE),
    ([(1060, 560), (1020, 640), (1000, 720)], 12, DIRT),                                    # farm track between orchard and vines
    ([(560, 640), (540, 720), (566, 800)], 16, COBBLE),                                       # alleys
    ([(800, 660), (826, 750), (806, 840)], 16, COBBLE),
    ([(620, 250), (710, 226), (800, 256), (850, 320)], 16, COBBLE),
    ([(560, 430), (530, 340), (560, 260)], 14, COBBLE),
]
FOG = [(880, 470, 120, 34), (1060, 430, 140, 30), (1160, 520, 100, 26), (980, 700, 130, 28), (1180, 760, 110, 24), (380, 440, 90, 22)]


def street_paths():
    return [wobble(points, amount=width / 6, seed=30 + i) for i, (points, width, _) in enumerate(STREETS)]


def ground(img):
    d = ImageDraw.Draw(img)
    for ty in range(0, H, TILE):
        for tx in range(0, W, TILE):
            c = GRASS if (tx // TILE * 7 + ty // TILE * 3) % 5 else GRASS_2
            d.rectangle((tx, ty, tx + TILE - 1, ty + TILE - 1), fill=c)
            if rng.random() < 0.14:
                x, y = tx + rng.randint(2, 13), ty + rng.randint(2, 13)
                d.line([(x, y), (x + 1, y - 2)], fill=GRASS_LIGHT)
    # forest floor: brown and covered in leaves
    for poly in (FOREST_WEST, FOREST_NORTH):
        d.polygon(wobble(poly, amount=10, seed=len(poly)), fill=FOREST_FLOOR)
    d.polygon(CLEARING, fill=GRASS_2, outline=FOREST_FLOOR_2)
    # orchard grass, vineyard soil, estate lawn
    d.polygon(wobble(ORCHARD, amount=8, seed=3), fill=(156, 156, 86))
    d.polygon(wobble(VINEYARD, amount=8, seed=4), fill=(150, 116, 80))
    for y in range(630, 880, 22):
        d.line([(880, y), (1272, y - 8)], fill=(130, 98, 66), width=2)
    d.polygon(ESTATE, fill=LAWN, outline=INK)
    for ty in range(0, 320, TILE):
        for tx in range(880, W, TILE):
            if (tx // TILE + ty // TILE) % 2 and inside(ESTATE, tx + 8, ty + 8):
                d.rectangle((tx, ty, tx + TILE - 1, ty + TILE - 1), fill=LAWN_2)
    # gravel paths inside the estate
    for line in ([(1010, 300), (1040, 240), (1060, 190)], [(920, 150), (1240, 150)], [(1150, 150), (1170, 270)], [(950, 260), (1100, 260)]):
        d.line(line, fill=GRAVEL, width=14, joint="curve")
    d.ellipse((1100, 222, 1210, 290), fill=GRAVEL, outline=STONE_DARK)
    # stream
    path = wobble(STREAM, amount=6, seed=5)
    d.line(path, fill=INK, width=24, joint="curve")
    d.line(path, fill=WATER, width=20, joint="curve")
    for x, y in path[::3]:
        d.line([(x - 4, y), (x + 3, y)], fill=WATER_LIGHT)
        if rng.random() < 0.5:
            d.point((x + rng.randint(-6, 6), y + 4), fill=LEAF_COLOURS[0][0])
    # streets and the square
    for path, (_, width, colour) in zip(street_paths(), STREETS):
        edge = DIRT_DARK if colour == DIRT else COBBLE_DARK
        d.line(path, fill=edge, width=width + 6, joint="curve")
        d.line(path, fill=colour, width=width, joint="curve")
    d.polygon(SQUARE, fill=COBBLE_2, outline=COBBLE_DARK)
    for _ in range(1500):
        x, y = rng.randint(0, W - 1), rng.randint(0, H - 1)
        if img.getpixel((x, y))[:3] in (COBBLE, COBBLE_2):
            d.point((x, y), fill=COBBLE_DARK)
    # fallen leaves everywhere except water
    for _ in range(4200):
        x, y = rng.randint(0, W - 2), rng.randint(0, H - 2)
        if img.getpixel((x, y))[:3] in (WATER, WATER_LIGHT):
            continue
        c = LEAF_COLOURS[rng.randrange(4)][rng.choice([0, 0, 2])]
        d.rectangle((x, y, x + 1, y + (1 if rng.random() < 0.5 else 0)), fill=c)
    # the estate wall's footprint
    d.line(ESTATE + [ESTATE[0]], fill=STONE_DARK, width=3)


def fog(img):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for cx, cy, rx, ry in FOG:
        for k in range(4):
            d.ellipse((cx - rx + k * 14, cy - ry + k * 4, cx + rx - k * 14, cy + ry - k * 4), fill=(236, 232, 226, 34))
    img.alpha_composite(layer)


def falling_leaves(img):
    d = ImageDraw.Draw(img)
    r = random.Random(77)
    for _ in range(110):
        x, y = r.randint(0, W - 4), r.randint(0, H - 4)
        c = LEAF_COLOURS[r.randrange(4)][0]
        if r.random() < 0.5:
            d.polygon([(x, y + 2), (x + 2, y), (x + 4, y + 2), (x + 2, y + 4)], fill=c, outline=INK)
        else:
            d.line([(x, y), (x + 3, y + 1)], fill=c, width=2)


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

    paths = street_paths()

    def clear(x0, x1, y, pad=6):
        for path, (_, width, _) in zip(paths, STREETS):
            for a, b in zip(path, path[1:]):
                for px in (x0, (x0 + x1) / 2, x1):
                    if seg_dist(px, y - 6, a, b) < width / 2 + pad:
                        return False
        for a, b in zip(STREAM, STREAM[1:]):
            for px in (x0, (x0 + x1) / 2, x1):
                if seg_dist(px, y - 4, a, b) < 18:
                    return False
        return not (inside(SQUARE, (x0 + x1) / 2, y - 4) or inside(SQUARE, x0, y) or inside(SQUARE, x1, y))

    # --- estate, northeast ---
    put(manor(), 950, 140, "OFFICERS' ESTATE", 144)
    put(guard_house(), 1170, 300, "GUARD HOUSE", 238)
    put(cellar_door(), 1250 - 44, 176, "CELLAR (Davor)", 180)
    put(gate_towers(), 950, 330, "GATE", 334)
    put(gazebo(), 1128, 236)
    put(statue(), 1144, 274)
    put(fountain(), 960, 258)
    for x, y, w in ((900, 212, 60), (900, 240, 40), (1060, 214, 52), (1060, 250, 36), (1212, 214, 56), (1222, 260, 46), (1090, 300, 60)):
        put(hedge(w), x, y)
    for x, y in ((1250, 120), (1190, 60), (912, 100)):
        put(autumn_tree(rng.randrange(4), big=True), x - 22, y)
    # wall along the south edge of the estate, broken by the gate
    for x0, x1, y in ((880, 948, 296), (1082, 1180, 304), (1180, 1272, 304)):
        put(wall_piece(int(x1 - x0)), x0, y)

    # --- orchard and vineyard, east ---
    for row, y in enumerate(range(370, 570, 34)):
        for x in range(820 + (row % 2) * 16, 1260, 36):
            if inside(ORCHARD, x + 14, y) and clear(x, x + 28, y, 2) and free(x, y - 20, x + 28, y):
                put(apple_tree(), x, y)
    for y in range(650, 880, 22):
        x0 = 900 if y < 760 else 930
        for x in range(x0, 1260, 112):
            if inside(VINEYARD, x + 40, y) and clear(x, x + 96, y, 2):
                put(vine_row(96), x, y)
    put(wine_press(), 830, 640, "WINE PRESS", 644)
    for x, y in ((850, 600), (1000, 600), (1200, 590), (960, 380), (1140, 380)):
        put(basket(), x, y)
    for x, y in ((800, 560), (790, 600)):
        put(haystack(), x, y)
    for x, y in ((870, 520), (940, 440), (1120, 470), (1230, 420), (1080, 560), (1010, 520), (900, 360)):
        put(leaf_pile(), x, y)
    for x, y in ((820, 330), (1040, 620), (1220, 610)):
        put(hedge(70), x, y)

    # --- town, middle ---
    put(tavern(), 520, 420, "TAVERN THE ACORN", 424)
    put(fountain(), 660, 486)
    for i, (x, y, goods) in enumerate(((610, 530, APPLE), (730, 516, PUMPKIN), (760, 470, GRAPE), (630, 452, (176, 120, 70)))):
        put(market_stall([NAVY, (150, 64, 48), GOLD_DARK, (96, 120, 70)][i], goods), x, y)
    put(cart(), 560, 500)
    for x, y in ((600, 556), (744, 540), (780, 500)):
        put(pumpkin(), x, y)
    put(statue(), 700, 420, "MONUMENT", 424)
    put(bridge(), 424, 534)
    sign(img, 700, 878, "TO THE PORT", bg=NAVY, fg=GOLD)

    rng.seed(13)
    for (points, width, colour) in STREETS:
        if colour != COBBLE:
            continue
        path = wobble(points, amount=width / 6, seed=99)
        for x, y in path:
            for side in (-1, 1, -1, 1):
                w = rng.choice([34, 40, 46, 52])
                h = rng.choice([40, 48, 56])
                ox = x + rng.uniform(-22, 22) - w / 2
                bottom = y + side * (width / 2 + rng.uniform(12, 36)) + (h + 30) * (0.5 if side < 0 else 1)
                x0, x1, top = ox, ox + w + 12, bottom - (h + 30) * 0.55
                if not (500 < x0 and x1 < 900 and 150 < bottom < 860):
                    continue
                if any(inside(p, px, py) for p in (ORCHARD, VINEYARD, ESTATE) for px in (x0, x1) for py in (top, bottom)):
                    continue
                if not clear(x0, x1, bottom) or not free(x0, top, x1, bottom):
                    continue
                put(republic_house(w, h, rng.choice(ROOFS), rng.choice(PLASTER)), ox, bottom)
    # fill the gaps between streets with more small houses
    for _ in range(500):
        w = rng.choice([30, 34, 40, 46])
        h = rng.choice([36, 40, 48])
        ox, bottom = rng.uniform(505, 880 - w), rng.uniform(180, 850)
        x0, x1, top = ox, ox + w + 12, bottom - (h + 30) * 0.55
        if any(inside(p, px, py) for p in (ORCHARD, VINEYARD, ESTATE) for px in (x0, x1) for py in (top, bottom)):
            continue
        if clear(x0, x1, bottom) and free(x0, top - 6, x1, bottom + 6):
            put(republic_house(w, h, rng.choice(ROOFS), rng.choice(PLASTER)), ox, bottom)
    for x, y in ((590, 480), (780, 440), (660, 600), (740, 700), (600, 680), (840, 400), (560, 560)):
        put(lantern_post(), x, y)

    # --- forest, west and north; the landing clearing ---
    put(lasta(), 100, 720, "LASTA (hidden landing)", 724)
    put(hunter_hut(), 300, 470, "HUNTER'S HUT", 474)
    put(woodpile(), 236, 470)
    for x, y, s in ((60, 760, 18), (270, 740, 14), (400, 600, 16)):
        put(rock(s), x, y)
    for x, y in ((250, 640), (120, 610), (330, 560), (60, 450), (210, 380)):
        put(leaf_pile(), x, y)
    rng.seed(17)
    for _ in range(420):
        x, y = rng.randint(-10, W - 30), rng.randint(10, H + 10)
        in_forest = inside(FOREST_WEST, x + 16, y) or inside(FOREST_NORTH, x + 16, y)
        in_town_edge = 330 < x < 900 and y < 200
        if not (in_forest or in_town_edge or (x < 900 and y > 820)):
            continue
        if inside(CLEARING, x + 16, y) or inside(ESTATE, x + 16, y):
            continue
        if not clear(x, x + 32, y, 2) or not free(x, y - 26, x + 32, y):
            continue
        roll = rng.random()
        if roll < 0.18:
            put(pine(), x, y)
        else:
            put(autumn_tree(None, big=roll > 0.7, bare=roll < 0.24), x, y)
    for _ in range(40):  # a few trees inside the town, along the streets
        x, y = rng.randint(500, 880), rng.randint(180, 820)
        if clear(x, x + 32, y) and free(x, y - 26, x + 32, y) and not inside(ORCHARD, x, y) and not inside(VINEYARD, x, y):
            put(autumn_tree(None), x, y)

    # --- people ---
    rep = [load_sprite(ROOT / f"assets/art/artichoke/objects/republic_soldier_{i}.png") for i in (3, 5, 7)]
    rep = [s for s in rep if s is not None]
    guard = load_sprite(ROOT / "assets/art/artichoke/objects/republic_guardsman.png") or (rep[0] if rep else None)
    for x, y in ((990, 336), (1056, 336)):  # gate
        put(guard, x, y)
    for i, (x, y) in enumerate(((920, 200), (1180, 140), (1230, 200), (880, 420), (1150, 500), (980, 760), (680, 560), (820, 640))):
        if rep:
            put(rep[i % len(rep)], x, y)
    put(load_sprite(ROOT / "assets/art/rock/martin.png"), 1100, 236)
    put(load_sprite(ROOT / "assets/art/engineeria/davor.png"), 1188, 172)
    pool = base.npc_pool()
    r = random.Random(5)
    for x, y in ((640, 520), (700, 540), (760, 540), (600, 440), (560, 620), (720, 640), (650, 760), (780, 380), (1000, 650), (1100, 700)):
        if pool:
            s = r.choice(pool)
            put(s, x - s.width // 2, y)
    put(load_sprite(ROOT / "assets/art/player_blue.png"), 220, 700)
    put(load_sprite(ROOT / "assets/art/smokva/donat.png"), 244, 706)
    put(load_sprite(ROOT / "assets/art/iskra/npcs/veki.png"), 200, 724)

    sprites.sort(key=lambda s: s[0])
    for bottom, sprite, x, label, label_y in sprites:
        shadow(img, x + 2, bottom - 4, x + sprite.width - 2, bottom + 4)
        img.alpha_composite(sprite, (int(x), int(bottom - sprite.height)))
    fog(img)
    falling_leaves(img)
    for bottom, sprite, x, label, label_y in sprites:
        if label:
            sign(img, int(x + sprite.width // 2), label_y, label)
    for text, x, y in (("FOREST", 150, 40), ("TOWN", 700, 180), ("ORCHARDS", 1180, 324), ("VINEYARDS", 1200, 872), ("ESTATE", 1220, 6)):
        sign(img, x, y, text, bg=GOLD, fg=INK)
    return img


def main():
    img = build().convert("RGB")
    img.save(OUT)
    img.crop((860, 0, 1280, 360)).resize((840, 720), Image.NEAREST).save(ESTATE_OUT)
    img.crop((400, 340, 900, 760)).resize((1000, 840), Image.NEAREST).save(TOWN_OUT)
    for path in (OUT, ESTATE_OUT, TOWN_OUT):
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
