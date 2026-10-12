#!/usr/bin/python3
"""Draw the Rudnik sprites and terrain used by maps/engineeria.tmj.

The diplomatic ship came down in a broadleaf forest on Rudnik, a mining planet
of Engineeria. The map has the wreck, a stream with fords, rocky ledges with
ramps, the forest beasts that chase the player, Davor's house in a clearing with
a fence, and the walled mining port east of the house.

Writes PNGs to assets/art/engineeria/.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

from create_pomidor_art import person, SKINS

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/art/engineeria"
CHVARAK = ROOT / "assets/art/chvarak"

INK = (28, 23, 48)
SHADOW = (28, 23, 48, 95)
FLOOR = (70, 104, 62)
FLOOR_2 = (64, 96, 58)
MOSS = (88, 124, 66)
LEAF = (122, 104, 58)
LEAF_2 = (148, 116, 60)
PATH = (132, 108, 76)
PATH_2 = (118, 96, 68)
WATER = (64, 120, 160)
WATER_2 = (58, 110, 150)
WATER_LIGHT = (120, 180, 210)
STONE = (140, 136, 128)
STONE_DARK = (98, 94, 92)
ROCK = (108, 102, 96)
ROCK_DARK = (76, 72, 72)
ROCK_LIGHT = (146, 140, 132)
CLEARING = (112, 150, 82)
CLEARING_LIGHT = (140, 172, 100)
SCORCH = (58, 50, 44)
SCORCH_2 = (44, 38, 34)
TRUNK = (96, 66, 44)
TRUNK_DARK = (66, 44, 30)
CANOPY = [((54, 112, 58), (36, 84, 46), (84, 146, 70)),
          ((64, 120, 52), (44, 90, 40), (100, 156, 66)),
          ((48, 100, 64), (32, 74, 50), (76, 132, 82))]
THICKET = (38, 74, 44)
THICKET_DARK = (26, 54, 34)
LOG = (124, 86, 56)
LOG_DARK = (86, 58, 38)
LOG_END = (196, 160, 110)
SHINGLE = (92, 70, 58)
SHINGLE_DARK = (66, 50, 42)
SMOKE = (196, 196, 204, 170)
SMOKE_DARK = (150, 150, 162, 150)
FIRE = (246, 162, 56)
FIRE_HOT = (252, 228, 120)
FIRE_RED = (214, 72, 40)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


def broadleaf(variant):
    rng = random.Random(variant * 13 + 5)
    green, dark, light = CANOPY[variant % 3]
    w, h = (44, 54) if variant != 2 else (52, 62)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = w // 2
    d.ellipse((cx - 14, h - 8, cx + 14, h - 1), fill=SHADOW)
    d.rectangle((cx - 3, h - 22, cx + 3, h - 4), fill=TRUNK, outline=INK)
    d.line([(cx - 1, h - 20), (cx - 1, h - 6)], fill=TRUNK_DARK)
    blobs = [(cx, 16, 15), (cx - 10, 22, 11), (cx + 10, 22, 11), (cx - 4, 10, 10), (cx + 6, 12, 10), (cx, 26, 12)]
    if variant == 2:
        blobs += [(cx - 15, 28, 9), (cx + 15, 28, 9)]
    for bx, by, r in blobs:
        d.ellipse((bx - r - 1, by - r - 1, bx + r + 1, by + r + 1), fill=INK)
    for bx, by, r in blobs:
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=green)
    for bx, by, r in blobs:
        d.ellipse((bx - r // 2, by + r // 3, bx + r, by + r - 1), fill=dark)
    for _ in range(14):
        px, py = rng.randint(cx - 14, cx + 12), rng.randint(4, 26)
        d.point((px, py), fill=light)
        d.point((px + 1, py), fill=light)
    return img


def bush(variant):
    green, dark, light = CANOPY[(variant + 1) % 3]
    img = Image.new("RGBA", (22, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 11, 20, 15), fill=SHADOW)
    for bx, by, r in ((7, 9, 6), (14, 8, 6), (11, 6, 5)):
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=green, outline=INK)
    d.ellipse((9, 8, 17, 13), fill=dark)
    d.point((8, 5), fill=light)
    d.point((13, 4), fill=light)
    if variant == 1:
        for p in ((6, 9), (15, 7), (11, 11)):
            d.point(p, fill=(204, 60, 70))
    return img


def fern():
    img = Image.new("RGBA", (14, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for angle in (-60, -30, 0, 30, 60):
        a = math.radians(angle - 90)
        d.line([(7, 11), (7 + math.cos(a) * 7, 11 + math.sin(a) * 9)], fill=(84, 140, 70))
    return img


def fallen_log():
    img = Image.new("RGBA", (40, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 9, 38, 13), fill=SHADOW)
    d.rectangle((4, 2, 34, 10), fill=LOG, outline=INK)
    d.line([(6, 5), (32, 5)], fill=LOG_DARK)
    d.ellipse((30, 1, 38, 11), fill=LOG_END, outline=INK)
    d.ellipse((32, 4, 36, 8), outline=LOG_DARK)
    d.point((14, 3), fill=MOSS)
    d.point((15, 3), fill=MOSS)
    return img


def flame(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (14, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(2, 17), (4, 8), (7, 1 + rng.randint(0, 2)), (10, 7), (12, 17)], fill=FIRE_RED, outline=INK)
    d.polygon([(4, 17), (6, 9), (8, 5), (10, 17)], fill=FIRE)
    d.polygon([(6, 17), (7, 11), (9, 17)], fill=FIRE_HOT)
    return img


def smoke_column(height=48, seed=1):
    rng = random.Random(seed)
    img = Image.new("RGBA", (24, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y = height - 6
    x = 12
    r = 4
    while y > 4:
        d.ellipse((x - r, y - r, x + r, y + r), fill=SMOKE if rng.random() < .6 else SMOKE_DARK)
        y -= 6
        x += rng.choice((-1, 0, 1, 1))
        r = min(9, r + 1)
    return img


def wreck():
    """The diplomatic ship broken in two, the front half nose-down in the earth."""
    ship = Image.open(CHVARAK / "diplomatic_ship.png").convert("RGBA")
    ship = ship.crop((0, 0, ship.width, 58))
    rear = ship.crop((0, 0, 70, 58)).rotate(-7, expand=True, resample=Image.NEAREST)
    front = ship.crop((74, 0, ship.width, 58)).rotate(11, expand=True, resample=Image.NEAREST)
    img = Image.new("RGBA", (176, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 74, 170, 94), fill=(28, 23, 48, 120))
    d.ellipse((60, 70, 120, 92), fill=(40, 32, 30, 160))
    img.alpha_composite(rear, (4, 30))
    img.alpha_composite(front, (90, 30))
    d = ImageDraw.Draw(img)
    rng = random.Random(3)
    # soot and torn metal along the break
    for _ in range(90):
        x, y = rng.randint(54, 112), rng.randint(36, 86)
        if img.getpixel((x, y))[3] > 0:
            d.point((x, y), fill=rng.choice([SCORCH, SCORCH_2, (70, 64, 70)]))
    for _ in range(40):
        x, y = rng.randint(8, 168), rng.randint(36, 86)
        if img.getpixel((x, y))[3] > 0:
            d.point((x, y), fill=SCORCH_2)
    d.polygon([(70, 46), (78, 40), (82, 52), (88, 44), (92, 58), (74, 62)], fill=(84, 84, 96), outline=INK)
    for fx, fy, s in ((70, 50, 2), (98, 58, 5), (30, 54, 9)):
        img.alpha_composite(flame(s), (fx, fy))
    for sx, sy, s in ((64, 0, 4), (92, 4, 6)):
        img.alpha_composite(smoke_column(44, s), (sx, sy))
    return img


def debris(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (22, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 9, 20, 13), fill=SHADOW)
    pts = [(2, 10), (5, 3 + rng.randint(0, 2)), (14, 2), (20, 6 + rng.randint(0, 3)), (16, 11)]
    d.polygon(pts, fill=(176, 182, 194), outline=INK)
    d.line([(5, 6), (16, 5)], fill=(78, 131, 207), width=2)
    d.point((10, 8), fill=SCORCH)
    d.point((12, 9), fill=SCORCH)
    return img


def davor():
    """An old man in plain clothes: grey hair, grey beard, a bow on his back."""
    tunic, dark = (112, 98, 74), (82, 70, 52)
    img = Image.new("RGBA", (18, 26), (0, 0, 0, 0))
    base = person(tunic, dark, SKINS[0], (196, 196, 200))
    img.alpha_composite(base, (1, 2))
    d = ImageDraw.Draw(img)
    # beard
    d.rectangle((6, 11, 11, 13), fill=(206, 206, 210))
    d.point((7, 14), fill=(206, 206, 210))
    d.point((10, 14), fill=(206, 206, 210))
    # bow across the back, showing over the left shoulder
    d.arc((0, 4, 12, 24), 200, 300, fill=(150, 108, 66), width=1)
    d.line([(1, 9), (4, 20)], fill=(226, 220, 200))
    return img


def davor_house():
    img = Image.new("RGBA", (84, 92), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = 28
    d.rectangle((6, top + 30, 77, top + 62), fill=LOG, outline=INK)
    for y in range(top + 33, top + 62, 5):
        d.line([(7, y), (76, y)], fill=LOG_DARK)
    for y in range(top + 31, top + 62, 5):
        d.ellipse((3, y, 8, y + 4), fill=LOG_END, outline=INK)
        d.ellipse((75, y, 80, y + 4), fill=LOG_END, outline=INK)
    d.polygon([(0, top + 32), (42, top + 4), (83, top + 32)], fill=SHINGLE, outline=INK)
    for i in range(1, 5):
        y = top + 4 + i * 6
        half = 42 * (y - top - 4) / 28
        d.line([(42 - half + 2, y), (42 + half - 2, y)], fill=SHINGLE_DARK)
    # stone chimney with smoke
    d.rectangle((58, top + 2, 66, top + 22), fill=STONE, outline=INK)
    d.line([(59, top + 8), (65, top + 8)], fill=STONE_DARK)
    d.line([(59, top + 14), (65, top + 14)], fill=STONE_DARK)
    img.alpha_composite(smoke_column(34, 9), (50, 0))
    d = ImageDraw.Draw(img)
    # door and windows
    d.rectangle((36, top + 42, 48, top + 62), fill=TRUNK_DARK, outline=INK)
    d.point((46, top + 52), fill=(230, 200, 90))
    for wx in (14, 58):
        d.rectangle((wx, top + 40, wx + 10, top + 49), fill=(232, 196, 110), outline=INK)
        d.line([(wx + 5, top + 40), (wx + 5, top + 49)], fill=INK)
    return img


def woodpile():
    img = Image.new("RGBA", (30, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 13, 29, 17), fill=SHADOW)
    for row, count in ((0, 4), (1, 3), (2, 2)):
        for i in range(count):
            x = 3 + row * 3 + i * 7
            y = 10 - row * 5
            d.ellipse((x, y, x + 7, y + 6), fill=LOG_END, outline=INK)
            d.point((x + 3, y + 3), fill=LOG_DARK)
    d.line([(26, 2), (26, 15)], fill=TRUNK_DARK)  # an axe handle
    d.polygon([(24, 2), (29, 1), (29, 5)], fill=(200, 204, 208), outline=INK)
    return img


def chopping_block():
    img = Image.new("RGBA", (14, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((2, 4, 11, 11), fill=LOG, outline=INK)
    d.ellipse((2, 1, 11, 6), fill=LOG_END, outline=INK)
    return img


def forest_beast():
    """A large dark six-legged beast with a ridge of spines and pale eyes."""
    img = Image.new("RGBA", (34, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, dark, spine = (54, 46, 62), (34, 28, 42), (92, 80, 96)
    d.ellipse((2, 17, 32, 21), fill=SHADOW)
    for lx in (6, 10, 14, 19, 23, 27):
        d.line([(lx, 13), (lx - 1, 19)], fill=dark, width=2)
    d.ellipse((3, 6, 28, 16), fill=body, outline=INK)
    for sx in range(7, 25, 4):
        d.polygon([(sx, 7), (sx + 2, 2), (sx + 4, 7)], fill=spine, outline=INK)
    # head and jaw
    d.ellipse((22, 5, 33, 15), fill=body, outline=INK)
    d.line([(27, 13), (33, 12)], fill=(220, 214, 200))
    d.point((29, 8), fill=(214, 236, 120))
    d.point((31, 8), fill=(214, 236, 120))
    d.line([(2, 10), (0, 7)], fill=dark, width=2)
    return img


# ---- Rudnik mining port ----
# Engineeria builds in grey stone and steel, marks its work in orange and lights
# its instruments in blue.
GREY = (128, 132, 140)
GREY_DARK = (84, 88, 98)
GREY_LIGHT = (172, 176, 184)
ORANGE = (232, 128, 44)
ORANGE_DARK = (176, 86, 30)
BLUE = (70, 130, 210)
BLUE_LIGHT = (140, 200, 250)
BLUE_DARK = (40, 70, 130)
ORE = (150, 96, 70)
ORE_DARK = (104, 64, 50)
ORE_LIGHT = (196, 140, 96)
MINE_ROCK = (92, 86, 84)
MINE_ROCK_DARK = (62, 58, 60)


def stripes(d, box, width=4):
    """Orange and dark hazard stripes across `box`."""
    x0, y0, x1, y1 = box
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            band = (x + (y1 - y)) // width
            d.point((x, y), fill=ORANGE if band % 2 == 0 else INK)


def port_gate():
    """The wicket gate in the port's west wall, seen from the side: a steel door
    under an orange-striped lintel."""
    img = Image.new("RGBA", (20, 46), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 2, 18, 45), fill=GREY_DARK, outline=INK)
    d.rectangle((3, 10, 16, 43), fill=GREY, outline=INK)
    for y in (16, 24, 32, 40):
        d.line([(4, y), (15, y)], fill=GREY_DARK)
    d.rectangle((1, 2, 18, 8), fill=ORANGE, outline=INK)
    for x in range(3, 18, 5):
        d.line([(x, 3), (x + 2, 7)], fill=INK)
    d.rectangle((12, 26, 14, 29), fill=BLUE_LIGHT, outline=INK)
    return img


def gate_bell():
    img = Image.new("RGBA", (14, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 22, 12, 25), fill=SHADOW)
    d.rectangle((6, 6, 8, 24), fill=GREY_DARK, outline=INK)
    d.rectangle((3, 4, 12, 6), fill=GREY, outline=INK)
    d.polygon([(7, 7), (3, 14), (11, 14)], fill=ORANGE, outline=INK)
    d.point((7, 15), fill=INK)
    return img


def gate_lever():
    img = Image.new("RGBA", (14, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 20, 13, 23), fill=SHADOW)
    d.rectangle((2, 12, 12, 21), fill=GREY, outline=INK)
    d.rectangle((4, 14, 6, 16), fill=BLUE_LIGHT)
    d.line([(9, 13), (11, 3)], fill=GREY_DARK, width=2)
    d.ellipse((9, 1, 13, 5), fill=ORANGE, outline=INK)
    return img


def mine_entrance():
    img = Image.new("RGBA", (52, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((2, 4, 49, 39), fill=MINE_ROCK, outline=INK)
    d.rectangle((10, 12, 41, 39), fill=(18, 16, 22))
    # steel frame and an orange-striped header beam
    d.rectangle((7, 10, 10, 39), fill=GREY, outline=INK)
    d.rectangle((41, 10, 44, 39), fill=GREY, outline=INK)
    stripes(d, (6, 6, 45, 11), 3)
    d.rectangle((6, 6, 45, 11), outline=INK)
    for y in (20, 30):
        d.line([(12, y), (39, y)], fill=(40, 36, 44))
    d.rectangle((24, 14, 27, 17), fill=BLUE_LIGHT, outline=INK)
    return img


def lift_headframe(broken=True):
    """The lift tower over the shaft: a steel lattice with the sheave wheel on
    top and the winch house at its foot."""
    img = Image.new("RGBA", (48, 76), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 68, 44, 75), fill=SHADOW)
    for x0, x1 in ((8, 18), (40, 30)):
        d.line([(x0, 70), (x1, 8)], fill=GREY_DARK, width=3)
    for y in range(16, 66, 10):
        t = (y - 8) / 62
        d.line([(18 - 10 * t, y), (30 + 10 * t, y)], fill=GREY)
        d.line([(18 - 10 * t, y), (30 + 10 * (t + .16), y + 10)], fill=GREY_DARK)
    d.ellipse((14, 2, 34, 22), outline=INK, fill=None, width=3)
    d.ellipse((15, 3, 33, 21), outline=ORANGE, width=2)
    d.line([(24, 12), (24, 60)], fill=INK)
    # the winch house
    d.rectangle((2, 50, 46, 72), fill=GREY, outline=INK)
    stripes(d, (3, 51, 45, 54), 3)
    d.rectangle((6, 58, 18, 68), fill=BLUE_DARK, outline=INK)
    d.rectangle((8, 60, 11, 62), fill=BLUE_LIGHT if not broken else (90, 110, 140))
    d.rectangle((13, 60, 16, 62), fill=BLUE_LIGHT)
    d.ellipse((26, 57, 40, 71), fill=GREY_DARK, outline=INK)
    d.ellipse((30, 61, 36, 67), fill=ORANGE)
    return img


def maintenance_shed():
    img = Image.new("RGBA", (60, 50), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 44, 58, 49), fill=SHADOW)
    d.polygon([(0, 16), (30, 4), (59, 16)], fill=GREY_DARK, outline=INK)
    d.rectangle((3, 16, 56, 46), fill=GREY, outline=INK)
    for x in range(6, 56, 4):
        d.line([(x, 17), (x, 45)], fill=GREY_LIGHT)
    d.rectangle((20, 26, 38, 46), fill=ORANGE, outline=INK)
    d.line([(29, 26), (29, 46)], fill=ORANGE_DARK)
    d.rectangle((6, 20, 17, 25), fill=BLUE_DARK, outline=INK)
    d.line([(8, 22), (15, 22)], fill=BLUE_LIGHT)
    # a cog painted on the wall
    d.ellipse((42, 22, 52, 32), outline=ORANGE, width=2)
    return img


def bunkhouse(variant):
    img = Image.new("RGBA", (66, 50), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 44, 64, 49), fill=SHADOW)
    d.rectangle((2, 8, 63, 46), fill=GREY if variant == 0 else GREY_LIGHT, outline=INK)
    d.rectangle((0, 4, 65, 10), fill=GREY_DARK, outline=INK)
    stripes(d, (1, 11, 64, 13), 3)
    for wx in (6, 22, 44):
        d.rectangle((wx, 18, wx + 12, 28), fill=BLUE, outline=INK)
        d.line([(wx + 2, 20), (wx + 6, 20)], fill=BLUE_LIGHT)
    d.rectangle((26, 32, 38, 46), fill=GREY_DARK, outline=INK)
    d.point((36, 39), fill=ORANGE)
    return img


def dispatch_engine():
    """The port's dispatch engine: a hall-sized logic machine. Racks of switching
    blocks behind glass, cable runs and cooling vents. It schedules the lift, the
    ore stores and the ship."""
    img = Image.new("RGBA", (124, 78), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(41)
    d.ellipse((4, 70, 120, 77), fill=SHADOW)
    d.rectangle((2, 16, 121, 74), fill=GREY, outline=INK)
    d.rectangle((0, 10, 123, 18), fill=GREY_DARK, outline=INK)
    stripes(d, (1, 19, 122, 21), 4)
    # vents and cooling stacks on the roof
    for x in (14, 40, 96):
        d.rectangle((x, 0, x + 10, 10), fill=GREY_DARK, outline=INK)
        d.line([(x + 2, 3), (x + 8, 3)], fill=INK)
        d.line([(x + 2, 6), (x + 8, 6)], fill=INK)
    # the racks of logic blocks seen through long windows
    for row_y in (26, 46):
        d.rectangle((6, row_y, 117, row_y + 14), fill=BLUE_DARK, outline=INK)
        for bx in range(8, 116, 6):
            d.rectangle((bx, row_y + 2, bx + 4, row_y + 12), fill=GREY_DARK)
            for ly in range(row_y + 3, row_y + 12, 3):
                if rng.random() < .55:
                    d.point((bx + rng.randint(1, 3), ly), fill=BLUE_LIGHT if rng.random() < .8 else ORANGE)
    # orange cable runs and the door
    d.line([(2, 64), (121, 64)], fill=ORANGE, width=2)
    d.rectangle((54, 62, 70, 74), fill=GREY_DARK, outline=INK)
    d.rectangle((60, 66, 64, 68), fill=BLUE_LIGHT)
    return img


def ore_pile():
    img = Image.new("RGBA", (28, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 12, 27, 17), fill=SHADOW)
    d.polygon([(2, 15), (8, 6), (13, 2), (19, 5), (26, 15)], fill=ORE, outline=INK)
    for p in ((9, 9), (14, 6), (18, 11), (12, 12), (21, 12)):
        d.point(p, fill=ORE_LIGHT)
        d.point((p[0] + 1, p[1] + 1), fill=ORE_DARK)
    return img


def ore_cart():
    img = Image.new("RGBA", (22, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 14, 20, 17), fill=SHADOW)
    d.polygon([(2, 6), (20, 6), (17, 14), (5, 14)], fill=GREY, outline=INK)
    d.line([(3, 9), (19, 9)], fill=ORANGE)
    d.polygon([(4, 6), (8, 2), (12, 3), (17, 6)], fill=ORE, outline=INK)
    for wx in (6, 15):
        d.ellipse((wx - 2, 13, wx + 2, 17), fill=GREY_DARK, outline=INK)
    return img


def supply_crates():
    img = Image.new("RGBA", (24, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 17, 23, 21), fill=SHADOW)
    d.rectangle((1, 8, 12, 19), fill=GREY, outline=INK)
    d.rectangle((11, 10, 22, 19), fill=GREY_LIGHT, outline=INK)
    d.rectangle((5, 1, 16, 10), fill=GREY_DARK, outline=INK)
    d.line([(1, 13), (12, 13)], fill=ORANGE)
    d.line([(11, 14), (22, 14)], fill=BLUE)
    return img


def lamp_post():
    img = Image.new("RGBA", (10, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 28, 9, 31), fill=SHADOW)
    d.rectangle((4, 6, 5, 29), fill=GREY_DARK)
    d.rectangle((1, 1, 8, 6), fill=GREY, outline=INK)
    d.rectangle((2, 3, 7, 5), fill=BLUE_LIGHT)
    return img


def ore_ship():
    """An Engineeria ore ship: the same hull plan as the diplomatic ship, in
    working grey with orange cargo pods and blue running lights."""
    ship = Image.open(CHVARAK / "diplomatic_ship.png").convert("RGBA")
    px = ship.load()
    for y in range(ship.height):
        for x in range(ship.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            brightness = (r + g + b) / 3
            if b > r + 40:
                px[x, y] = BLUE_LIGHT + (a,) if brightness > 150 else ORANGE + (a,) if brightness > 90 else ORANGE_DARK + (a,)
            elif brightness > 170:
                px[x, y] = GREY_LIGHT + (a,)
            elif brightness > 120:
                px[x, y] = GREY + (a,)
            elif brightness > 70:
                px[x, y] = GREY_DARK + (a,)
    d = ImageDraw.Draw(ship)
    # two ore pods slung under the hull
    for x in (40, 82):
        d.rectangle((x, 44, x + 22, 56), fill=ORANGE, outline=INK)
        d.line([(x + 2, 50), (x + 20, 50)], fill=ORANGE_DARK)
    return ship


def port_person(tunic, tunic_dark, skin_index, helmet):
    """An Engineeria worker: the hair is drawn as a helmet or a cap in `helmet`."""
    img = Image.new("RGBA", (18, 26), (0, 0, 0, 0))
    img.alpha_composite(person(tunic, tunic_dark, SKINS[skin_index % 4], helmet), (1, 2))
    return img


PORT_PEOPLE = {
    # The foreman wears orange; miners wear orange vests over grey, with blue helmets.
    "foreman": (ORANGE, ORANGE_DARK, 1, GREY_LIGHT),
    "captain": (BLUE, BLUE_DARK, 3, GREY_DARK),
    "dispatcher": (BLUE_DARK, (28, 48, 92), 0, (60, 48, 40)),
    "gatekeeper": (GREY, GREY_DARK, 2, ORANGE),
    "resident_0": (GREY_LIGHT, GREY, 0, (91, 57, 44)),
    "resident_1": ((150, 120, 96), (110, 86, 70), 3, (40, 32, 36)),
    "miner_0": (ORANGE, GREY_DARK, 0, BLUE),
    "miner_1": (ORANGE, GREY_DARK, 2, BLUE),
    "miner_2": (ORANGE, GREY_DARK, 3, BLUE),
    "miner_3": (ORANGE, GREY_DARK, 1, BLUE),
}


TERRAIN = ["floor", "floor_2", "moss", "leaves", "path", "path_2", "water", "water_2",
           "ford", "ledge", "ramp", "clearing", "scorch", "fence_h", "fence_v", "fence_post",
           "thicket", "thicket_2", "bank", "ledge_face", "port_wall", "paving", "paving_2", "rail",
           "mine_rock", "mine_face", "pad", "ore_heap"]


def terrain():
    img = Image.new("RGBA", (16 * 8, 16 * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(31)

    def at(i):
        return (i % 8) * 16, (i // 8) * 16

    def speckle(x, y, colors, n):
        for _ in range(n):
            d.point((x + rng.randrange(16), y + rng.randrange(16)), fill=rng.choice(colors))

    for i, name in enumerate(TERRAIN):
        x, y = at(i)
        if name in ("floor", "floor_2"):
            d.rectangle((x, y, x + 15, y + 15), fill=FLOOR if name == "floor" else FLOOR_2)
            speckle(x, y, [MOSS, FLOOR_2 if name == "floor" else FLOOR, (90, 80, 52)], 10)
        elif name == "moss":
            d.rectangle((x, y, x + 15, y + 15), fill=MOSS)
            speckle(x, y, [FLOOR, (110, 150, 80)], 10)
        elif name == "leaves":
            d.rectangle((x, y, x + 15, y + 15), fill=FLOOR_2)
            speckle(x, y, [LEAF, LEAF_2, (160, 80, 50)], 18)
        elif name in ("path", "path_2"):
            d.rectangle((x, y, x + 15, y + 15), fill=PATH if name == "path" else PATH_2)
            speckle(x, y, [PATH_2 if name == "path" else PATH, (100, 82, 60), LEAF], 9)
        elif name in ("water", "water_2"):
            d.rectangle((x, y, x + 15, y + 15), fill=WATER if name == "water" else WATER_2)
            for wy in (4, 11):
                wx = rng.randrange(2, 8)
                d.line([(x + wx, y + wy), (x + wx + 5, y + wy)], fill=WATER_LIGHT)
        elif name == "ford":
            d.rectangle((x, y, x + 15, y + 15), fill=WATER)
            for sx, sy in ((1, 2), (8, 1), (3, 9), (10, 8), (6, 13)):
                d.ellipse((x + sx, y + sy, x + sx + 5, y + sy + 4), fill=STONE, outline=STONE_DARK)
        elif name == "bank":
            d.rectangle((x, y, x + 15, y + 15), fill=FLOOR)
            d.rectangle((x, y + 10, x + 15, y + 15), fill=PATH_2)
        elif name == "ledge":
            d.rectangle((x, y, x + 15, y + 15), fill=ROCK)
            d.rectangle((x, y, x + 15, y + 2), fill=MOSS)
            for cx in range(1, 16, 4):
                d.line([(x + cx, y + 3), (x + cx + 1, y + 15)], fill=ROCK_DARK)
                d.point((x + cx + 2, y + 6), fill=ROCK_LIGHT)
        elif name == "ledge_face":
            d.rectangle((x, y, x + 15, y + 15), fill=ROCK_DARK)
            for cx in range(2, 16, 5):
                d.line([(x + cx, y), (x + cx - 1, y + 13)], fill=INK)
                d.point((x + cx + 1, y + 4), fill=ROCK)
                d.point((x + cx + 2, y + 9), fill=ROCK)
            d.rectangle((x, y + 14, x + 15, y + 15), fill=(40, 52, 40))
        elif name == "ramp":
            d.rectangle((x, y, x + 15, y + 15), fill=PATH)
            for ry in range(2, 16, 4):
                d.line([(x, y + ry), (x + 15, y + ry)], fill=PATH_2)
                d.point((x + 2, y + ry + 1), fill=ROCK_LIGHT)
        elif name == "clearing":
            d.rectangle((x, y, x + 15, y + 15), fill=CLEARING)
            for _ in range(6):
                gx, gy = x + rng.randrange(15), y + 2 + rng.randrange(13)
                d.line([(gx, gy), (gx, gy - 2)], fill=CLEARING_LIGHT)
        elif name == "scorch":
            d.rectangle((x, y, x + 15, y + 15), fill=SCORCH)
            speckle(x, y, [SCORCH_2, (80, 70, 60), (120, 60, 40)], 12)
        elif name in ("fence_h", "fence_v", "fence_post"):
            d.rectangle((x, y, x + 15, y + 15), fill=CLEARING)
            if name == "fence_h":
                d.rectangle((x, y + 6, x + 15, y + 7), fill=LOG)
                d.rectangle((x, y + 10, x + 15, y + 11), fill=LOG)
                d.rectangle((x + 6, y + 3, x + 8, y + 14), fill=LOG_DARK, outline=INK)
            elif name == "fence_v":
                d.rectangle((x + 7, y, x + 8, y + 15), fill=LOG)
                d.rectangle((x + 6, y + 4, x + 9, y + 11), fill=LOG_DARK, outline=INK)
            else:
                d.rectangle((x + 6, y + 3, x + 9, y + 14), fill=LOG_DARK, outline=INK)
        elif name in ("thicket", "thicket_2"):
            d.rectangle((x, y, x + 15, y + 15), fill=THICKET_DARK)
            for _ in range(5):
                bx, by, r = x + rng.randrange(16), y + rng.randrange(16), rng.randint(3, 6)
                d.ellipse((bx - r, by - r, bx + r, by + r), fill=THICKET if name == "thicket" else CANOPY[2][0])
            speckle(x, y, [CANOPY[0][2]], 4)
        elif name == "port_wall":
            # Dressed grey blocks with an orange band, the top lit from the north.
            d.rectangle((x, y, x + 15, y + 15), fill=GREY_DARK)
            d.rectangle((x, y, x + 15, y + 3), fill=GREY_LIGHT)
            for by in (4, 10):
                d.line([(x, y + by), (x + 15, y + by)], fill=INK)
            for bx in (3, 11):
                d.line([(x + bx, y + 4), (x + bx, y + 9)], fill=INK)
            d.line([(x + 7, y + 10), (x + 7, y + 15)], fill=INK)
            d.rectangle((x, y + 12, x + 15, y + 13), fill=ORANGE)
        elif name in ("paving", "paving_2"):
            d.rectangle((x, y, x + 15, y + 15), fill=GREY if name == "paving" else (120, 124, 130))
            d.line([(x, y + 7), (x + 15, y + 7)], fill=GREY_DARK)
            d.line([(x + (4 if name == "paving" else 11), y), (x + (4 if name == "paving" else 11), y + 6)], fill=GREY_DARK)
            d.line([(x + 9, y + 8), (x + 9, y + 15)], fill=GREY_DARK)
            speckle(x, y, [GREY_LIGHT, (110, 112, 118)], 5)
        elif name == "rail":
            d.rectangle((x, y, x + 15, y + 15), fill=(120, 124, 130))
            for sy in range(1, 16, 4):
                d.rectangle((x + 1, y + sy, x + 14, y + sy + 1), fill=LOG_DARK)
            d.line([(x + 4, y), (x + 4, y + 15)], fill=GREY_LIGHT)
            d.line([(x + 11, y), (x + 11, y + 15)], fill=GREY_LIGHT)
        elif name in ("mine_rock", "mine_face"):
            d.rectangle((x, y, x + 15, y + 15), fill=MINE_ROCK if name == "mine_rock" else MINE_ROCK_DARK)
            speckle(x, y, [MINE_ROCK_DARK, ORE, (120, 112, 108)], 12)
            if name == "mine_face":
                for cx in range(2, 16, 5):
                    d.line([(x + cx, y), (x + cx - 1, y + 13)], fill=INK)
                d.rectangle((x, y + 14, x + 15, y + 15), fill=(52, 50, 54))
        elif name == "pad":
            d.rectangle((x, y, x + 15, y + 15), fill=(104, 108, 116))
            d.rectangle((x, y, x + 15, y + 15), outline=GREY_DARK)
            d.line([(x + 2, y + 2), (x + 5, y + 2)], fill=BLUE_LIGHT)
            d.line([(x + 10, y + 13), (x + 13, y + 13)], fill=ORANGE)
        elif name == "ore_heap":
            d.rectangle((x, y, x + 15, y + 15), fill=ORE_DARK)
            for _ in range(5):
                bx, by, r = x + rng.randrange(16), y + rng.randrange(16), rng.randint(3, 5)
                d.ellipse((bx - r, by - r, bx + r, by + r), fill=ORE, outline=ORE_DARK)
            speckle(x, y, [ORE_LIGHT], 5)
    return img


def main():
    save(terrain(), "engineeria_terrain")
    for i in range(3):
        save(broadleaf(i), f"broadleaf_{i}")
    for i in range(2):
        save(bush(i), f"bush_{i}")
        save(debris(i), f"debris_{i}")
    save(fern(), "fern")
    save(fallen_log(), "fallen_log")
    save(flame(1), "flame")
    save(wreck(), "wreck")
    save(davor(), "davor")
    save(davor_house(), "davor_house")
    save(woodpile(), "woodpile")
    save(chopping_block(), "chopping_block")
    save(forest_beast(), "forest_beast")
    save(port_gate(), "port_gate")
    save(gate_bell(), "gate_bell")
    save(gate_lever(), "gate_lever")
    save(mine_entrance(), "mine_entrance")
    save(lift_headframe(), "lift_headframe")
    save(maintenance_shed(), "maintenance_shed")
    for i in range(2):
        save(bunkhouse(i), f"bunkhouse_{i}")
    save(dispatch_engine(), "dispatch_engine")
    save(ore_pile(), "ore_pile")
    save(ore_cart(), "ore_cart")
    save(supply_crates(), "supply_crates")
    save(lamp_post(), "lamp_post")
    save(ore_ship(), "ore_ship")
    for key, (tunic, dark, skin, helmet) in PORT_PEOPLE.items():
        save(port_person(tunic, dark, skin, helmet), f"port_{key}")
    print("wrote", len(list(OUT.glob("*.png"))), "Engineeria sprites")


if __name__ == "__main__":
    main()
