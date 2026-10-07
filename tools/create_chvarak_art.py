#!/usr/bin/python3
"""Draw the Chvarak sprites and terrain used by maps/chvarak.tmj.

Chvarak is a farming planet in the mountains. Snowy peaks close off the north,
the spaceport sits on a stone shelf below them, and terraced fields, pastures
with cows and pigs, barns and stone farmhouses fill the valley under the shelf.

The diplomatic ship's interior uses the same terrain atlas, so the ambush on
the flight to Engineeria can be played on this map.

Writes PNGs to assets/art/chvarak/.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

from paprika_visual_art import draw_service_plaque
from create_pomidor_art import person, recolor, roof, window, door, SKINS, HAIRS

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/art/chvarak"

INK = (28, 23, 48)
SHADOW = (28, 23, 48, 95)
GRASS = (112, 150, 86)
GRASS_2 = (102, 140, 80)
GRASS_LIGHT = (140, 172, 100)
MEADOW_FLOWERS = [(236, 226, 120), (240, 240, 236), (186, 140, 210)]
DIRT = (168, 130, 88)
DIRT_2 = (152, 116, 78)
DIRT_DARK = (124, 92, 62)
FIELD_GREEN = (98, 146, 64)
FIELD_GREEN_DARK = (72, 112, 50)
FIELD_GOLD = (214, 182, 92)
FIELD_GOLD_DARK = (176, 142, 66)
STONE = (150, 146, 140)
STONE_2 = (134, 130, 126)
STONE_DARK = (100, 96, 96)
STONE_LIGHT = (184, 180, 172)
ROCK = (112, 104, 104)
ROCK_DARK = (78, 72, 76)
ROCK_LIGHT = (146, 138, 134)
SNOW = (238, 242, 246)
SNOW_SHADE = (196, 208, 222)
WOOD = (122, 84, 56)
WOOD_DARK = (84, 56, 38)
WOOD_LIGHT = (156, 112, 76)
BARN_RED = (162, 62, 48)
BARN_RED_DARK = (118, 42, 36)
SLATE = (78, 82, 96)
SLATE_DARK = (54, 56, 68)
SLATE_LIGHT = (108, 112, 128)
HAY = (226, 196, 104)
HAY_DARK = (186, 152, 70)
HULL = (222, 226, 232)
HULL_SHADE = (176, 182, 194)
HULL_DARK = (124, 130, 146)
BLUE = (78, 131, 207)
BLUE_DARK = (47, 92, 156)
GOLD = (245, 195, 76)
GLASS = (96, 176, 206)
GLASS_LIGHT = (160, 220, 236)
CHVARAK = (176, 120, 64)
CHVARAK_DARK = (120, 80, 44)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


def shadow_under(img, box):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=SHADOW)
    return Image.alpha_composite(layer, img)


# ---------- mountains ----------

def peak(width, height, seed):
    """A snowy peak; the rock tiles below it block the way north."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = (width // 2 + rng.randint(-8, 8), 2)
    left, right = (0, height - 1), (width - 1, height - 1)
    d.polygon([left, top, right], fill=ROCK, outline=INK)
    # the shaded east face
    d.polygon([top, right, (top[0] + 6, height - 1)], fill=ROCK_DARK)
    for _ in range(10):
        x = rng.randint(10, width - 10)
        y = rng.randint(height // 2, height - 6)
        d.line([(x, y), (x + rng.randint(-6, 6), y + 5)], fill=ROCK_LIGHT)
    snow_h = int(height * 0.38)
    sx = snow_h * (top[0] - left[0]) / (height)
    ex = snow_h * (right[0] - top[0]) / (height)
    pts = [top, (top[0] + ex, snow_h)]
    steps = 6
    for i in range(steps, -1, -1):
        x = top[0] - sx + (sx + ex) * i / steps
        pts.append((x, snow_h + (5 if i % 2 else -1)))
    pts.append((top[0] - sx, snow_h))
    d.polygon(pts, fill=SNOW, outline=INK)
    d.polygon([top, (top[0] + ex, snow_h), (top[0] + 4, snow_h)], fill=SNOW_SHADE)
    return img


def boulder(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (22, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 9, 21, 15), fill=SHADOW)
    d.polygon([(2, 13), (4, 4), (11, 1 + rng.randint(0, 2)), (19, 5), (20, 13)], fill=ROCK, outline=INK)
    d.line([(6, 5), (11, 3)], fill=ROCK_LIGHT)
    d.line([(14, 6), (18, 12)], fill=ROCK_DARK)
    return img


def pine(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (24, 42), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 36, 20, 41), fill=SHADOW)
    d.rectangle((10, 30, 13, 39), fill=WOOD_DARK, outline=INK)
    green, dark = (52, 104, 72), (34, 74, 56)
    for i, (w, y) in enumerate(((11, 30), (9, 22), (7, 14), (4, 7))):
        d.polygon([(12 - w, y + 4), (12, y - 9), (12 + w, y + 4)], fill=green, outline=INK)
        d.line([(12, y - 7), (12 + w - 2, y + 3)], fill=dark)
    if rng.random() < 0.5:
        d.polygon([(12, 0), (9, 5), (15, 5)], fill=SNOW)
    return img


# ---------- farms ----------

def barn(seed):
    img = Image.new("RGBA", (80, 68), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 28, 73, 65), fill=BARN_RED, outline=INK)
    for x in range(10, 72, 5):
        d.line([(x, 29), (x, 64)], fill=BARN_RED_DARK)
    d.polygon([(2, 30), (40, 4), (77, 30)], fill=SLATE, outline=INK)
    d.line([(40, 5), (40, 29)], fill=SLATE_DARK)
    d.line([(8, 28), (72, 28)], fill=SLATE_LIGHT)
    # hay door and the big doors
    d.rectangle((34, 16, 46, 26), fill=WOOD_DARK, outline=INK)
    d.rectangle((36, 18, 44, 24), fill=HAY)
    d.rectangle((26, 40, 54, 65), fill=WOOD, outline=INK)
    d.line([(26, 40), (54, 65)], fill=WOOD_LIGHT, width=2)
    d.line([(54, 40), (26, 65)], fill=WOOD_LIGHT, width=2)
    d.line([(40, 40), (40, 65)], fill=INK)
    if seed % 2:
        d.rectangle((60, 22, 66, 30), fill=STONE, outline=INK)
    return img


def farmhouse(seed):
    """Stone walls, a steep slate roof against the snow, wooden shutters."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (60, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 30, 53, 61), fill=STONE, outline=INK)
    for row in range(32, 60, 5):
        off = 4 if (row // 5) % 2 else 0
        d.line([(7, row), (52, row)], fill=STONE_2)
        for col in range(7 + off, 52, 9):
            d.line([(col, row), (col, row + 4)], fill=STONE_2)
    d.polygon([(2, 32), (30, 2), (57, 32)], fill=(SLATE, (92, 70, 58))[seed % 2], outline=INK)
    d.line([(30, 4), (30, 31)], fill=SLATE_DARK)
    d.rectangle((40, 6, 46, 20), fill=STONE_DARK, outline=INK)
    if rng.random() < 0.7:
        d.polygon([(30, 2), (24, 9), (36, 9)], fill=SNOW)
    for wx in (12, 40):
        d.rectangle((wx, 38, wx + 8, 47), fill=GLASS, outline=INK)
        d.rectangle((wx - 3, 38, wx - 1, 47), fill=WOOD, outline=INK)
        d.rectangle((wx + 9, 38, wx + 11, 47), fill=WOOD, outline=INK)
    door(d, 30, 61, 10, 16)
    return img


def haystack():
    img = Image.new("RGBA", (22, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 14, 21, 19), fill=SHADOW)
    d.ellipse((2, 2, 20, 18), fill=HAY, outline=INK)
    d.rectangle((2, 12, 20, 17), fill=HAY)
    d.line([(2, 12), (2, 17)], fill=INK)
    d.line([(20, 12), (20, 17)], fill=INK)
    d.line([(2, 17), (20, 17)], fill=INK)
    for x in (6, 11, 15):
        d.line([(x, 5), (x - 1, 15)], fill=HAY_DARK)
    return img


def trough():
    img = Image.new("RGBA", (24, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 2, 22, 8), fill=WOOD, outline=INK)
    d.rectangle((3, 3, 20, 5), fill=(88, 140, 170))
    return img


def cart():
    img = Image.new("RGBA", (34, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((3, 6, 26, 14), fill=WOOD, outline=INK)
    d.rectangle((5, 3, 24, 8), fill=HAY, outline=INK)
    d.line([(26, 12), (33, 15)], fill=WOOD_DARK, width=2)
    for cx in (8, 21):
        d.ellipse((cx - 5, 12, cx + 5, 21), fill=WOOD_DARK, outline=INK)
        d.point((cx, 16), fill=WOOD_LIGHT)
    return img


def cow(variant):
    """Side view, 26x18. Variant 0 is white with black patches, 1 is brown."""
    img = Image.new("RGBA", (26, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, patch = ((236, 232, 222), (40, 36, 40)) if variant == 0 else ((150, 96, 60), (110, 66, 40))
    d.ellipse((2, 14, 24, 17), fill=SHADOW)
    for lx in (5, 9, 16, 20):
        d.rectangle((lx, 11, lx + 1, 15), fill=patch if variant else (60, 54, 56))
    d.rounded_rectangle((3, 4, 21, 12), 3, fill=body, outline=INK)
    d.ellipse((7, 5, 12, 9), fill=patch)
    d.ellipse((14, 7, 18, 10), fill=patch)
    # head
    d.rounded_rectangle((19, 2, 25, 9), 2, fill=body, outline=INK)
    d.rectangle((22, 6, 25, 8), fill=(226, 160, 160))
    d.line([(20, 1), (21, 2)], fill=(226, 220, 200))
    d.point((22, 4), fill=INK)
    d.line([(3, 5), (1, 9)], fill=patch)
    return img


def pig(variant):
    img = Image.new("RGBA", (18, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body = (236, 168, 168) if variant == 0 else (214, 150, 140)
    dark = (196, 120, 124)
    d.ellipse((1, 9, 17, 11), fill=SHADOW)
    for lx in (4, 7, 11, 14):
        d.rectangle((lx, 8, lx + 1, 10), fill=dark)
    d.ellipse((2, 2, 15, 10), fill=body, outline=INK)
    d.ellipse((12, 3, 17, 8), fill=body, outline=INK)
    d.rectangle((16, 5, 17, 6), fill=dark)
    d.point((14, 4), fill=INK)
    d.polygon([(12, 3), (13, 1), (14, 3)], fill=dark)
    d.point((1, 4), fill=dark)
    if variant == 1:
        d.ellipse((5, 4, 8, 7), fill=(150, 104, 96))
    return img


def farmer(index):
    """Farmers and herders: work clothes, and most wear a straw hat."""
    tunics = [((122, 140, 70), (88, 104, 50)), ((146, 110, 70), (110, 80, 50)),
              ((96, 112, 140), (66, 80, 106)), ((168, 84, 60), (126, 60, 44))]
    tunic, dark = tunics[index % 4]
    img = Image.new("RGBA", (16, 26), (0, 0, 0, 0))
    img.alpha_composite(person(tunic, dark, SKINS[(index + 1) % 4], HAIRS[(index * 3) % 4]), (0, 2))
    d = ImageDraw.Draw(img)
    if index % 4 != 2:
        d.ellipse((1, 1, 14, 5), fill=HAY, outline=INK)
        d.rectangle((4, 0, 11, 3), fill=HAY, outline=INK)
    if index % 2:
        d.line([(15, 4), (15, 25)], fill=WOOD_DARK)  # herder's staff
    return img


def chvarak_guard():
    img = Image.new("RGBA", (16, 28), (0, 0, 0, 0))
    img.alpha_composite(person(CHVARAK, CHVARAK_DARK, SKINS[1], HAIRS[1]), (0, 4))
    d = ImageDraw.Draw(img)
    d.line([(14, 0), (14, 27)], fill=WOOD_DARK)
    d.polygon([(13, 3), (14, 0), (15, 3)], fill=STONE_LIGHT, outline=INK)
    return img


def ship_guard(index):
    """Confederation sailors who guard the diplomatic ship; sword and blue coat."""
    img = Image.new("RGBA", (18, 26), (0, 0, 0, 0))
    img.alpha_composite(person(BLUE, BLUE_DARK, SKINS[(index + 2) % 4], HAIRS[index % 4]), (0, 2))
    d = ImageDraw.Draw(img)
    d.line([(15, 12), (17, 4)], fill=(215, 227, 228), width=1)
    d.rectangle((3, 2, 12, 4), fill=(36, 44, 74))
    return img


# ---------- the spaceport ----------

def terminal():
    img = Image.new("RGBA", (104, 76), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 28, 97, 73), fill=STONE, outline=INK)
    for row in range(30, 72, 6):
        off = 5 if (row // 6) % 2 else 0
        d.line([(7, row), (96, row)], fill=STONE_2)
        for col in range(7 + off, 96, 10):
            d.line([(col, row), (col, row + 5)], fill=STONE_2)
    d.polygon([(2, 30), (16, 8), (88, 8), (101, 30)], fill=SLATE, outline=INK)
    d.line([(16, 10), (88, 10)], fill=SLATE_LIGHT)
    d.polygon([(30, 8), (52, 0), (74, 8)], fill=SLATE_DARK, outline=INK)
    d.polygon([(16, 8), (30, 8), (24, 4)], fill=SNOW)
    for wx in (12, 28, 66, 82):
        d.rectangle((wx, 46, wx + 10, 60), fill=GLASS, outline=INK)
        d.line([(wx + 2, 48), (wx + 2, 58)], fill=GLASS_LIGHT)
    d.rectangle((44, 46, 60, 73), fill=WOOD_DARK, outline=INK)
    d.line([(52, 46), (52, 73)], fill=INK)
    d.rectangle((88, 12, 92, 30), fill=STONE_DARK, outline=INK)
    d.rectangle((92, 12, 100, 18), fill=CHVARAK, outline=INK)
    draw_service_plaque(d, img.width, 32, "SPACEPORT")
    return img


def guard_post():
    img = Image.new("RGBA", (32, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((4, 14, 27, 38), fill=WOOD, outline=INK)
    for x in range(8, 27, 5):
        d.line([(x, 15), (x, 37)], fill=WOOD_DARK)
    d.polygon([(1, 16), (16, 3), (30, 16)], fill=SLATE, outline=INK)
    d.rectangle((10, 20, 21, 27), fill=GLASS, outline=INK)
    return img


def landing_pad():
    img = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, 93, 45), fill=STONE_2, outline=INK)
    d.ellipse((10, 7, 85, 40), outline=GOLD)
    d.line([(48, 10), (48, 37)], fill=GOLD)
    d.line([(18, 24), (78, 24)], fill=GOLD)
    return img


def diplomatic_ship():
    """White hull with the Confederation's diplomatic blue; the ramp is at the
    bottom left, where the player boards."""
    img = Image.new("RGBA", (144, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((10, 58, 138, 71), fill=SHADOW)
    # landing legs
    for x in (30, 112):
        d.line([(x, 50), (x - 4, 64)], fill=HULL_DARK, width=3)
        d.rectangle((x - 9, 63, x + 1, 66), fill=HULL_DARK, outline=INK)
    # hull
    d.polygon([(6, 38), (24, 20), (104, 16), (138, 30), (140, 40), (120, 52), (20, 54)], fill=HULL, outline=INK)
    d.polygon([(20, 54), (120, 52), (140, 40), (138, 44), (118, 56), (22, 58)], fill=HULL_SHADE, outline=INK)
    d.line([(14, 40), (136, 36)], fill=BLUE, width=3)
    d.line([(14, 43), (130, 40)], fill=GOLD)
    # cockpit
    d.polygon([(104, 18), (130, 28), (126, 32), (104, 26)], fill=GLASS, outline=INK)
    d.line([(108, 20), (124, 27)], fill=GLASS_LIGHT)
    for wx in range(34, 96, 14):
        d.ellipse((wx, 26, wx + 7, 32), fill=GLASS, outline=INK)
    # engines and fins
    d.polygon([(24, 20), (10, 6), (20, 6), (44, 18)], fill=HULL_SHADE, outline=INK)
    d.rectangle((0, 32, 8, 44), fill=HULL_DARK, outline=INK)
    d.rectangle((0, 35, 3, 41), fill=(120, 200, 230))
    # emblem
    d.ellipse((70, 40, 80, 50), fill=BLUE, outline=INK)
    d.point((75, 45), fill=GOLD)
    # boarding ramp
    d.polygon([(26, 54), (44, 54), (50, 70), (20, 70)], fill=HULL_DARK, outline=INK)
    for y in (58, 62, 66):
        d.line([(24, y), (46, y)], fill=HULL_SHADE)
    return img


# ---------- inside the ship ----------

def bench():
    img = Image.new("RGBA", (32, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 2, 30, 9), fill=BLUE, outline=INK)
    d.rectangle((2, 3, 29, 5), fill=(118, 160, 222))
    d.rectangle((3, 9, 6, 13), fill=HULL_DARK, outline=INK)
    d.rectangle((25, 9, 28, 13), fill=HULL_DARK, outline=INK)
    return img


def ship_table():
    img = Image.new("RGBA", (32, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 4, 30, 13), fill=WOOD, outline=INK)
    d.rectangle((2, 5, 29, 7), fill=WOOD_LIGHT)
    d.rectangle((12, 13, 19, 19), fill=WOOD_DARK, outline=INK)
    d.rectangle((6, 6, 14, 10), fill=(232, 220, 180), outline=INK)  # the Council's letters
    d.point((10, 8), fill=(186, 40, 40))
    return img


def ship_window():
    img = Image.new("RGBA", (24, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1, 1, 22, 12), 4, fill=(14, 16, 40), outline=INK)
    rng = random.Random(4)
    for _ in range(6):
        d.point((rng.randint(4, 19), rng.randint(3, 10)), fill=(240, 240, 255))
    d.rounded_rectangle((1, 1, 22, 12), 4, outline=HULL_DARK)
    return img


def hatch():
    img = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 1, 14, 30), fill=HULL_DARK, outline=INK)
    d.rectangle((3, 3, 12, 28), fill=(96, 100, 116))
    d.line([(3, 15), (12, 15)], fill=INK)
    d.rectangle((6, 12, 9, 18), fill=(214, 60, 60))
    return img


def ship_exit():
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 2, 31, 15), fill=HULL_DARK, outline=INK)
    d.polygon([(10, 12), (16, 5), (22, 12)], fill=GOLD, outline=INK)
    return img


# ---------- terrain ----------

TERRAIN = ["grass", "grass_2", "meadow", "road", "road_2", "field_green", "field_gold", "pave",
           "pave_2", "rock", "rock_snow", "cliff", "ramp", "ship_floor", "ship_carpet", "ship_wall",
           "fence_h", "fence_v", "fence_post", "terrace", "pad", "void", "grass_rock", "road_edge"]


def terrain():
    img = Image.new("RGBA", (16 * 8, 16 * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(23)

    def at(i):
        return (i % 8) * 16, (i // 8) * 16

    def grass(x, y, base):
        d.rectangle((x, y, x + 15, y + 15), fill=base)
        for _ in range(6):
            gx, gy = x + rng.randrange(15), y + 2 + rng.randrange(13)
            d.line([(gx, gy), (gx, gy - 2)], fill=GRASS_LIGHT)

    for i, name in enumerate(TERRAIN):
        x, y = at(i)
        if name in ("grass", "grass_2"):
            grass(x, y, GRASS if name == "grass" else GRASS_2)
        elif name == "meadow":
            grass(x, y, GRASS)
            for _ in range(4):
                d.point((x + rng.randrange(1, 15), y + rng.randrange(1, 15)), fill=rng.choice(MEADOW_FLOWERS))
        elif name == "grass_rock":
            grass(x, y, GRASS_2)
            d.ellipse((x + 4, y + 7, x + 10, y + 11), fill=ROCK_LIGHT, outline=ROCK_DARK)
        elif name in ("road", "road_2", "road_edge"):
            d.rectangle((x, y, x + 15, y + 15), fill=DIRT if name != "road_2" else DIRT_2)
            for _ in range(5):
                px, py = x + rng.randrange(15), y + rng.randrange(15)
                d.point((px, py), fill=DIRT_DARK)
            d.line([(x + 4, y), (x + 4, y + 15)], fill=DIRT_2 if name != "road_2" else DIRT)
            d.line([(x + 11, y), (x + 11, y + 15)], fill=DIRT_2 if name != "road_2" else DIRT)
            if name == "road_edge":
                d.line([(x, y), (x + 15, y)], fill=GRASS_2)
        elif name in ("field_green", "field_gold"):
            base, dark = (FIELD_GREEN, FIELD_GREEN_DARK) if name == "field_green" else (FIELD_GOLD, FIELD_GOLD_DARK)
            d.rectangle((x, y, x + 15, y + 15), fill=DIRT_2)
            for row in range(1, 16, 4):
                d.rectangle((x, y + row, x + 15, y + row + 2), fill=base)
                for col in range(0, 16, 3):
                    d.point((x + col, y + row), fill=dark)
        elif name == "terrace":
            # the low stone wall at the foot of a terraced field
            d.rectangle((x, y, x + 15, y + 15), fill=FIELD_GREEN)
            d.rectangle((x, y + 10, x + 15, y + 15), fill=STONE, outline=STONE_DARK)
            d.line([(x + 5, y + 10), (x + 5, y + 15)], fill=STONE_DARK)
            d.line([(x + 12, y + 10), (x + 12, y + 15)], fill=STONE_DARK)
        elif name in ("pave", "pave_2"):
            base = STONE if name == "pave" else STONE_2
            d.rectangle((x, y, x + 15, y + 15), fill=base, outline=STONE_DARK)
            d.line([(x + 8, y), (x + 8, y + 7)], fill=STONE_DARK)
            d.line([(x, y + 8), (x + 15, y + 8)], fill=STONE_DARK)
            d.line([(x + 3, y + 8), (x + 3, y + 15)], fill=STONE_DARK)
        elif name in ("rock", "rock_snow"):
            d.rectangle((x, y, x + 15, y + 15), fill=ROCK)
            for _ in range(4):
                px, py = x + rng.randrange(13), y + rng.randrange(13)
                d.line([(px, py), (px + 3, py + 2)], fill=ROCK_DARK)
                d.point((px + 1, py), fill=ROCK_LIGHT)
            if name == "rock_snow":
                d.rectangle((x, y, x + 15, y + 6), fill=SNOW)
                for sx in range(0, 16, 4):
                    d.point((x + sx, y + 7), fill=SNOW_SHADE)
        elif name == "cliff":
            d.rectangle((x, y, x + 15, y + 15), fill=ROCK_DARK)
            d.rectangle((x, y, x + 15, y + 3), fill=GRASS_2)
            for cx in range(1, 16, 5):
                d.line([(x + cx, y + 4), (x + cx + 1, y + 15)], fill=ROCK)
        elif name == "ramp":
            d.rectangle((x, y, x + 15, y + 15), fill=DIRT)
            for ry in range(2, 16, 4):
                d.line([(x, y + ry), (x + 15, y + ry)], fill=DIRT_DARK)
        elif name == "ship_floor":
            d.rectangle((x, y, x + 15, y + 15), fill=HULL_SHADE, outline=HULL_DARK)
            d.point((x + 2, y + 2), fill=HULL_DARK)
            d.point((x + 13, y + 13), fill=HULL_DARK)
        elif name == "ship_carpet":
            d.rectangle((x, y, x + 15, y + 15), fill=BLUE_DARK)
            d.line([(x, y + 1), (x + 15, y + 1)], fill=GOLD)
            d.point((x + 8, y + 8), fill=BLUE)
        elif name == "ship_wall":
            d.rectangle((x, y, x + 15, y + 15), fill=HULL_DARK)
            d.rectangle((x, y + 11, x + 15, y + 15), fill=(96, 100, 116))
            d.line([(x, y + 4), (x + 15, y + 4)], fill=HULL_SHADE)
        elif name in ("fence_h", "fence_v", "fence_post"):
            grass(x, y, GRASS)
            if name == "fence_h":
                d.rectangle((x, y + 7, x + 15, y + 8), fill=WOOD)
                d.rectangle((x, y + 11, x + 15, y + 12), fill=WOOD)
                d.rectangle((x + 1, y + 5, x + 3, y + 14), fill=WOOD_DARK, outline=INK)
            elif name == "fence_v":
                d.rectangle((x + 7, y, x + 8, y + 15), fill=WOOD)
                d.rectangle((x + 6, y + 4, x + 9, y + 10), fill=WOOD_DARK, outline=INK)
            else:
                d.rectangle((x + 6, y + 4, x + 9, y + 14), fill=WOOD_DARK, outline=INK)
                d.rectangle((x, y + 7, x + 15, y + 8), fill=WOOD)
        elif name == "pad":
            d.rectangle((x, y, x + 15, y + 15), fill=STONE_2, outline=STONE_DARK)
            d.line([(x, y + 15), (x + 15, y + 15)], fill=GOLD)
        elif name == "void":
            d.rectangle((x, y, x + 15, y + 15), fill=(14, 16, 40))
            if rng.random() < 0.8:
                d.point((x + rng.randrange(16), y + rng.randrange(16)), fill=(220, 224, 255))
    return img


def main():
    save(terrain(), "chvarak_terrain")
    save(peak(112, 88, 1), "peak_0")
    save(peak(80, 64, 2), "peak_1")
    save(peak(144, 104, 3), "peak_2")
    for i in range(3):
        save(boulder(i), f"boulder_{i}")
        save(pine(i), f"pine_{i}")
    for i in range(2):
        save(barn(i), f"barn_{i}")
        save(cow(i), f"cow_{i}")
        save(pig(i), f"pig_{i}")
        save(ship_guard(i), f"ship_guard_{i}")
    for i in range(3):
        save(farmhouse(i), f"farmhouse_{i}")
    for i in range(4):
        save(farmer(i), f"farmer_{i}")
    save(haystack(), "haystack")
    save(trough(), "trough")
    save(cart(), "cart")
    save(chvarak_guard(), "chvarak_guard")
    save(terminal(), "terminal")
    save(guard_post(), "guard_post")
    save(landing_pad(), "landing_pad")
    save(diplomatic_ship(), "diplomatic_ship")
    save(bench(), "ship_bench")
    save(ship_table(), "ship_table")
    save(ship_window(), "ship_window")
    save(hatch(), "ship_hatch")
    save(ship_exit(), "ship_exit")
    print("wrote", len(list(OUT.glob("*.png"))), "Chvarak sprites")


if __name__ == "__main__":
    main()
