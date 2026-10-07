#!/usr/bin/python3
"""Draw the Engineeria forest sprites and terrain used by maps/engineeria.tmj.

The diplomatic ship came down in a broadleaf forest somewhere in Engineeria. The
map has the wreck, a stream with fords, rocky ledges with ramps, the forest
beasts that chase the player, and Davor's house in a clearing with a fence.

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


TERRAIN = ["floor", "floor_2", "moss", "leaves", "path", "path_2", "water", "water_2",
           "ford", "ledge", "ramp", "clearing", "scorch", "fence_h", "fence_v", "fence_post",
           "thicket", "thicket_2", "bank", "ledge_face"]


def terrain():
    img = Image.new("RGBA", (16 * 8, 16 * 3), (0, 0, 0, 0))
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
    print("wrote", len(list(OUT.glob("*.png"))), "Engineeria sprites")


if __name__ == "__main__":
    main()
