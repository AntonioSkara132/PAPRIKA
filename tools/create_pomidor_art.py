#!/usr/bin/python3
"""Draw the Pomidor sprites and terrain used by maps/pomidor.tmj.

Pomidor is where the Council of all six Confederation planets meets. The town
is warm stone and red tile, and nothing there has to obey physics, so the rich
quarter has houses shaped like a spiral, a tomato, a pear and a pepper.

People are recolored from the 16x24 player sprite so they match the player.
Big Council members wear their planet's color; the six Secretaries of the
Small Council wear dark robes with the color of their office.

Writes PNGs to assets/art/pomidor/ and assets/art/player_orange.png.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

from paprika_visual_art import draw_service_plaque

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/art/pomidor"

INK = (28, 23, 48)
SHADOW = (28, 23, 48, 95)
PLASTER = (236, 220, 184)
PLASTER_SHADE = (212, 192, 154)
MARBLE = (240, 236, 226)
MARBLE_SHADE = (204, 198, 188)
MARBLE_DARK = (168, 160, 150)
GOLD = (245, 195, 76)
GOLD_DARK = (178, 128, 50)
WINDOW = (58, 142, 168)
WINDOW_LIGHT = (122, 196, 214)
DOOR = (104, 62, 44)
WOOD = (122, 84, 56)
WOOD_DARK = (84, 56, 38)
TILE_RED = (186, 72, 58)
TILE_RED_DARK = (142, 50, 46)
TILE_RED_LIGHT = (220, 108, 84)
ORANGE = (236, 128, 44)
ORANGE_DARK = (186, 88, 30)
ORANGE_LIGHT = (252, 172, 88)
TOMATO = (214, 54, 44)
TOMATO_DARK = (156, 34, 36)
TOMATO_LIGHT = (246, 110, 84)
LEAF = (72, 132, 60)
LEAF_DARK = (46, 92, 46)
LEAF_LIGHT = (108, 170, 82)
PEAR = (200, 196, 72)
PEAR_DARK = (150, 146, 52)
PEPPER = (226, 196, 52)
PEPPER_DARK = (180, 150, 36)
VIOLET = (126, 84, 160)
VIOLET_DARK = (88, 56, 118)
VIOLET_LIGHT = (168, 128, 198)
GRASS = (118, 156, 92)
GRASS_2 = (108, 146, 86)
GRASS_LIGHT = (146, 178, 104)
COBBLE = (214, 196, 168)
COBBLE_2 = (198, 178, 150)
COBBLE_DARK = (170, 148, 122)
PLAZA = (226, 210, 182)
CARPET = (168, 44, 48)
CARPET_DARK = (128, 30, 40)
WALL = (190, 160, 128)
WALL_DARK = (140, 112, 88)

# Planet colors for the Big Council sashes and banners.
PLANETS = {
    "paprika": ((189, 76, 83), (128, 44, 65)),
    "pomidor": ((214, 54, 44), (245, 195, 76)),
    "brudet": ((78, 131, 207), (47, 92, 156)),
    "artichoke": ((96, 150, 80), (226, 234, 238)),
    "cichvarda": ((126, 84, 160), (88, 56, 118)),
    "chvarak": ((176, 120, 64), (120, 80, 44)),
}
# Small Council offices and the color of each Secretary's robe trim.
OFFICES = {
    "army": (150, 154, 168),
    "gold": GOLD,
    "law": (247, 241, 221),
    "economy": (96, 160, 72),
    "diplomacy": (78, 131, 207),
    "navy": (64, 168, 170),
}


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


def ground_shadow(img, x0, y0, x1, y1):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((x0, y0, x1, y1), fill=SHADOW)
    out = Image.alpha_composite(layer, img)
    img.paste(out)


def roof(d, x0, x1, y_top, y_base, color=TILE_RED, dark=TILE_RED_DARK, light=TILE_RED_LIGHT):
    d.polygon([(x0 - 3, y_base), (x0 + 5, y_top), (x1 - 5, y_top), (x1 + 3, y_base)], fill=color, outline=INK)
    d.line([(x0 + 6, y_top + 2), (x1 - 6, y_top + 2)], fill=light)
    d.line([(x0 - 1, y_base - 1), (x1 + 1, y_base - 1)], fill=dark)


def window(d, x, y, w=8, h=10):
    d.rectangle((x, y, x + w, y + h), fill=WINDOW, outline=INK)
    d.line([(x + 2, y + 2), (x + 2, y + h - 2)], fill=WINDOW_LIGHT)


def door(d, cx, y_base, w=12, h=18):
    d.rectangle((cx - w // 2, y_base - h, cx + w // 2, y_base), fill=DOOR, outline=INK)
    d.point((cx + w // 2 - 3, y_base - h // 2), fill=GOLD)


def plaque(img, top, text):
    draw_service_plaque(ImageDraw.Draw(img), img.width, top, text)


# ---------- civic buildings ----------

def council_hall():
    """Marble hall with columns; its dome is a ripe tomato with a gold stem."""
    img = Image.new("RGBA", (176, 150), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = 147
    for i, inset in enumerate((0, 6, 12)):
        d.rectangle((6 + inset, base - 6 - i * 4, 169 - inset, base - i * 4), fill=MARBLE_SHADE if i == 0 else MARBLE, outline=INK)
    d.rectangle((18, 64, 157, base - 12), fill=MARBLE, outline=INK)
    d.rectangle((19, 120, 156, base - 13), fill=MARBLE_SHADE)
    for cx in range(28, 152, 18):
        if 78 < cx < 98:
            continue
        d.rectangle((cx - 3, 82, cx + 3, base - 13), fill=(250, 248, 240), outline=INK)
        d.line([(cx - 1, 84), (cx - 1, base - 15)], fill=MARBLE_SHADE)
    d.polygon([(12, 76), (88, 50), (163, 76)], fill=MARBLE, outline=INK)
    d.polygon([(30, 72), (88, 56), (145, 72)], fill=MARBLE_SHADE)
    d.rectangle((12, 74, 163, 80), fill=GOLD, outline=INK)
    d.rectangle((60, 34, 116, 54), fill=MARBLE, outline=INK)
    for wx in range(64, 112, 12):
        window(d, wx, 39, 7, 9)
    d.ellipse((50, 2, 126, 46), fill=TOMATO, outline=INK)
    d.arc((56, 6, 120, 44), 200, 260, fill=TOMATO_LIGHT, width=3)
    d.arc((52, 4, 124, 46), 20, 110, fill=TOMATO_DARK, width=3)
    for ang in range(0, 360, 60):
        x = 88 + 9 * math.cos(math.radians(ang))
        y = 5 + 3 * math.sin(math.radians(ang))
        d.line([(88, 4), (x, y)], fill=LEAF, width=2)
    d.rectangle((86, 0, 90, 5), fill=GOLD, outline=INK)
    door(d, 88, base - 13, 20, 28)
    d.arc((78, base - 48, 98, base - 30), 180, 360, fill=INK)
    for bx, planet in zip((40, 58, 118, 136), ("paprika", "brudet", "artichoke", "cichvarda")):
        col = PLANETS[planet][0]
        d.rectangle((bx - 4, 96, bx + 4, 116), fill=col, outline=INK)
        d.polygon([(bx - 4, 116), (bx, 112), (bx + 4, 116)], fill=MARBLE)
    plaque(img, 82, "COUNCIL HALL")
    return img


def library():
    img = Image.new("RGBA", (96, 88), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 30, 89, 85), fill=PLASTER, outline=INK)
    d.rectangle((7, 72, 88, 84), fill=PLASTER_SHADE)
    roof(d, 6, 89, 10, 32, VIOLET, VIOLET_DARK, VIOLET_LIGHT)
    d.rectangle((40, 2, 56, 14), fill=PLASTER, outline=INK)
    d.ellipse((43, 4, 53, 12), fill=WINDOW, outline=INK)
    for wx in (12, 68):
        d.rounded_rectangle((wx, 50, wx + 16, 70), 6, fill=WINDOW, outline=INK)
        d.line([(wx + 8, 52), (wx + 8, 69)], fill=INK)
    door(d, 48, 85, 14, 20)
    d.polygon([(40, 56), (48, 59), (56, 56), (56, 62), (48, 64), (40, 62)], fill=MARBLE, outline=INK)
    d.line([(48, 59), (48, 64)], fill=INK)
    plaque(img, 34, "LIBRARY")
    return img


def clothing_shop():
    """Orange striped awning and fabric rolls in the window."""
    img = Image.new("RGBA", (80, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((5, 22, 74, 69), fill=PLASTER, outline=INK)
    roof(d, 5, 74, 6, 24)
    d.polygon([(3, 38), (76, 38), (72, 47), (7, 47)], fill=ORANGE, outline=INK)
    for sx in range(9, 72, 9):
        d.polygon([(sx, 38), (sx + 4, 38), (sx + 3, 47), (sx - 1, 47)], fill=ORANGE_LIGHT)
    d.rectangle((9, 50, 35, 65), fill=(244, 232, 210), outline=INK)
    for i, col in enumerate((ORANGE, ORANGE_DARK, ORANGE_LIGHT, TOMATO)):
        d.rectangle((12 + i * 6, 53, 16 + i * 6, 64), fill=col, outline=INK)
    d.rectangle((51, 50, 70, 65), fill=(244, 232, 210), outline=INK)
    d.polygon([(55, 53), (66, 53), (68, 57), (64, 57), (64, 64), (57, 64), (57, 57), (53, 57)], fill=ORANGE, outline=INK)
    door(d, 43, 69, 10, 18)
    plaque(img, 24, "CLOTHES")
    return img


def beer_hall():
    img = Image.new("RGBA", (96, 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 26, 89, 77), fill=(164, 112, 72), outline=INK)
    for y in range(32, 76, 6):
        d.line([(7, y), (88, y)], fill=(140, 94, 60))
    roof(d, 6, 89, 6, 28, (110, 76, 52), (80, 54, 38), (146, 104, 70))
    d.rectangle((70, 0, 78, 12), fill=(120, 110, 104), outline=INK)
    for wx in (12, 26, 62, 76):
        window(d, wx, 46, 8, 12)
    door(d, 48, 77, 16, 22)
    d.line([(84, 34), (94, 34)], fill=INK)
    d.rectangle((86, 36, 93, 46), fill=GOLD, outline=INK)
    d.rectangle((86, 35, 93, 38), fill=(250, 248, 240), outline=INK)
    plaque(img, 30, "BEER HALL")
    return img


def townhouse(wall, roof_colors, seed, width=48, height=72, floors=3):
    """Narrow town house; Pomidor's streets are lined with these wall to wall."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shade = tuple(max(0, c - 26) for c in wall)
    top = 16
    d.rectangle((3, top, width - 4, height - 2), fill=wall, outline=INK)
    d.rectangle((4, height - 12, width - 5, height - 3), fill=shade)
    roof(d, 3, width - 4, 2, top + 2, *roof_colors)
    if rng.random() < 0.6:
        cx = rng.choice((10, width - 14))
        d.rectangle((cx, 0, cx + 5, 8), fill=(120, 110, 104), outline=INK)
    floor_h = (height - top - 22) // max(1, floors - 1)
    for f in range(floors - 1):
        y = top + 5 + f * floor_h
        for wx in (8, width - 17):
            window(d, wx, y, 8, 9)
            if rng.random() < 0.5:
                d.rectangle((wx - 1, y + 9, wx + 9, y + 11), fill=LEAF, outline=INK)
                d.point((wx + 3, y + 9), fill=TOMATO)
    door(d, width // 2, height - 2, 10, 15)
    return img


def row_house(seed):
    """Two front doors under one roof, for the denser blocks."""
    rng = random.Random(seed)
    walls = [(236, 206, 160), (232, 182, 150), (224, 214, 170)]
    wall = walls[seed % len(walls)]
    img = Image.new("RGBA", (80, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shade = tuple(max(0, c - 26) for c in wall)
    d.rectangle((3, 18, 76, 62), fill=wall, outline=INK)
    d.rectangle((4, 52, 75, 61), fill=shade)
    d.line([(40, 19), (40, 61)], fill=shade)
    roof(d, 3, 76, 2, 20)
    for wx in (8, 26, 46, 64):
        window(d, wx, 24, 8, 9)
    for cx in (20, 60):
        door(d, cx, 62, 10, 14)
    if rng.random() < 0.5:
        d.rectangle((58, 0, 63, 8), fill=(120, 110, 104), outline=INK)
    return img


# ---------- the rich quarter ----------

def spiral_house():
    """A tower that winds up like a shell on a stem far too thin for it."""
    img = Image.new("RGBA", (64, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((29, 84, 35, 116), fill=MARBLE_SHADE, outline=INK)
    d.ellipse((18, 110, 46, 119), fill=MARBLE_SHADE, outline=INK)
    for i in range(6):
        w = 26 - i * 3
        y = 86 - i * 13
        shift = int(6 * math.sin(i * 1.2))
        col = (VIOLET, VIOLET_LIGHT)[i % 2]
        d.ellipse((32 - w + shift, y - 10, 32 + w + shift, y + 4), fill=col, outline=INK)
        d.rectangle((28 + shift, y - 6, 34 + shift, y), fill=WINDOW, outline=INK)
    d.line([(30, 12), (32, 2)], fill=INK, width=2)
    d.ellipse((29, 0, 35, 6), fill=GOLD, outline=INK)
    door(d, 32, 116, 6, 10)
    return img


def tomato_house():
    img = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 12, 68, 70), fill=TOMATO, outline=INK)
    d.arc((10, 16, 62, 66), 200, 260, fill=TOMATO_LIGHT, width=4)
    d.arc((6, 14, 66, 68), 20, 120, fill=TOMATO_DARK, width=4)
    for ang in range(0, 360, 72):
        x = 36 + 14 * math.cos(math.radians(ang))
        y = 14 + 5 * math.sin(math.radians(ang))
        d.polygon([(36, 12), (x, y), (36 + (x - 36) * 0.4, y + 3)], fill=LEAF, outline=LEAF_DARK)
    d.rectangle((34, 2, 38, 13), fill=LEAF_DARK, outline=INK)
    d.ellipse((14, 30, 26, 42), fill=WINDOW, outline=INK)
    d.ellipse((46, 30, 58, 42), fill=WINDOW, outline=INK)
    door(d, 36, 69, 12, 16)
    return img


def pear_house():
    """A pear that floats above its garden; a ladder hangs down to the ground."""
    img = Image.new("RGBA", (56, 104), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 26, 50, 70), fill=PEAR, outline=INK)
    d.ellipse((14, 6, 42, 40), fill=PEAR, outline=INK)
    d.rectangle((15, 26, 41, 36), fill=PEAR)
    d.arc((8, 28, 48, 68), 30, 120, fill=PEAR_DARK, width=3)
    d.rectangle((26, 0, 29, 8), fill=WOOD, outline=INK)
    d.polygon([(29, 4), (40, 0), (36, 7)], fill=LEAF, outline=INK)
    d.ellipse((22, 18, 32, 28), fill=WINDOW, outline=INK)
    d.rectangle((22, 50, 34, 66), fill=DOOR, outline=INK)
    for x in (24, 32):
        d.line([(x, 68), (x, 103)], fill=WOOD_DARK)
    for y in range(72, 103, 5):
        d.line([(24, y), (32, y)], fill=WOOD)
    return img


def pepper_house():
    img = Image.new("RGBA", (48, 88), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(6, 18), (42, 18), (44, 40), (38, 70), (28, 86), (22, 86), (10, 70), (4, 40)], fill=PEPPER, outline=INK)
    d.line([(24, 22), (24, 82)], fill=PEPPER_DARK, width=2)
    d.rectangle((14, 10, 34, 19), fill=LEAF, outline=INK)
    d.rectangle((22, 2, 26, 11), fill=LEAF_DARK, outline=INK)
    d.rectangle((10, 30, 18, 40), fill=WINDOW, outline=INK)
    d.rectangle((30, 30, 38, 40), fill=WINDOW, outline=INK)
    door(d, 24, 70, 10, 14)
    return img


def fruit_tree():
    img = Image.new("RGBA", (28, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((12, 24, 16, 39), fill=WOOD, outline=INK)
    d.ellipse((2, 2, 26, 28), fill=LEAF, outline=INK)
    d.arc((5, 5, 23, 25), 200, 280, fill=LEAF_LIGHT, width=3)
    for fx, fy in ((9, 12), (18, 9), (15, 19)):
        d.ellipse((fx - 2, fy - 2, fx + 2, fy + 2), fill=TOMATO, outline=INK)
    return img


def market_stall(color, seed):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    light = tuple(min(255, c + 50) for c in color)
    for x in (3, 28):
        d.line([(x, 8), (x, 30)], fill=WOOD_DARK, width=2)
    d.polygon([(0, 10), (16, 2), (31, 10)], fill=color, outline=INK)
    for sx in range(4, 28, 8):
        d.line([(sx, 9), (16, 3)], fill=light)
    d.rectangle((2, 20, 29, 30), fill=WOOD, outline=INK)
    rng = random.Random(seed)
    for i in range(5):
        x = 5 + i * 5
        d.ellipse((x, 16, x + 4, 20), fill=rng.choice((TOMATO, PEPPER, LEAF, ORANGE, PEAR)), outline=INK)
    return img


# ---------- people ----------

def recolor(base, mapping):
    img = base.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (p[3],)
    return img


PLAYER_RED = Image.open(ROOT / "assets/art/player_red.png").convert("RGBA")
TUNIC, TUNIC_DARK = (189, 76, 83), (128, 44, 65)
SKIN, HAIR = (220, 167, 120), (91, 57, 44)
SKINS = [(220, 167, 120), (196, 140, 98), (150, 100, 70), (236, 196, 160)]
HAIRS = [(91, 57, 44), (40, 32, 36), (200, 160, 90), (150, 150, 156)]


def person(tunic, tunic_dark, skin=SKIN, hair=HAIR):
    return recolor(PLAYER_RED, {TUNIC: tunic, TUNIC_DARK: tunic_dark, SKIN: skin, HAIR: hair})


def councillor(planet, index):
    main, trim = PLANETS[planet]
    img = person(MARBLE, MARBLE_SHADE, SKINS[(index * 2 + len(planet)) % 4], HAIRS[(index + len(planet)) % 4])
    d = ImageDraw.Draw(img)
    # a planet-colored sash across the white robe
    for i in range(6):
        d.point((5 + i, 12 + i), fill=main)
        d.point((6 + i, 12 + i), fill=trim)
    return img


def secretary(office, index):
    trim = OFFICES[office]
    img = person((58, 52, 72), (40, 34, 52), SKINS[index % 4], HAIRS[(index + 1) % 4])
    d = ImageDraw.Draw(img)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][:3] == (40, 34, 52):
                px[x, y] = trim + (255,)
    d.point((8, 13), fill=GOLD)
    return img


def guard():
    img = Image.new("RGBA", (16, 28), (0, 0, 0, 0))
    body = person(TOMATO, GOLD_DARK)
    img.alpha_composite(body, (0, 4))
    d = ImageDraw.Draw(img)
    d.line([(14, 0), (14, 27)], fill=WOOD_DARK)
    d.polygon([(13, 3), (14, 0), (15, 3)], fill=MARBLE_SHADE, outline=INK)
    return img


def townsfolk():
    colors = [(ORANGE, ORANGE_DARK), (TOMATO, TOMATO_DARK), ((96, 150, 80), (60, 104, 56)),
              (PEAR, PEAR_DARK), (VIOLET, VIOLET_DARK), ((78, 131, 207), (47, 92, 156))]
    return [person(c, cd, SKINS[i % 4], HAIRS[(i * 3) % 4]) for i, (c, cd) in enumerate(colors)]


# ---------- council chamber furniture ----------

def council_table():
    """The Big Council's long table, with twelve chairs behind it."""
    img = Image.new("RGBA", (208, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((2, 14, 205, 30), fill=WOOD, outline=INK)
    d.rectangle((3, 15, 204, 18), fill=(150, 108, 72))
    d.rectangle((3, 26, 204, 29), fill=WOOD_DARK)
    for x in (6, 100, 196):
        d.rectangle((x, 30, x + 5, 38), fill=WOOD_DARK, outline=INK)
    for i in range(12):
        x = 10 + i * 16
        d.rectangle((x, 21, x + 6, 23), fill=MARBLE, outline=INK)
    d.rectangle((96, 16, 110, 20), fill=GOLD, outline=INK)
    return img


def secretary_desk(office):
    img = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 6, 30, 18), fill=WOOD, outline=INK)
    d.rectangle((2, 7, 29, 9), fill=(150, 108, 72))
    d.rectangle((3, 18, 6, 23), fill=WOOD_DARK, outline=INK)
    d.rectangle((25, 18, 28, 23), fill=WOOD_DARK, outline=INK)
    d.rectangle((10, 11, 21, 17), fill=OFFICES[office], outline=INK)
    d.rectangle((4, 2, 9, 7), fill=MARBLE, outline=INK)
    return img


def banner(planet):
    main, trim = PLANETS[planet]
    img = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([(1, 0), (1, 31)], fill=WOOD_DARK, width=2)
    d.rectangle((3, 2, 14, 22), fill=main, outline=INK)
    d.polygon([(3, 22), (8, 27), (14, 22)], fill=main, outline=INK)
    d.rectangle((5, 6, 12, 8), fill=trim)
    return img


def chamber_exit():
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 2, 31, 15), fill=CARPET, outline=INK)
    d.polygon([(10, 12), (16, 5), (22, 12)], fill=GOLD, outline=INK)
    return img


# ---------- terrain ----------

TERRAIN = ["grass", "grass_2", "street", "street_2", "plaza", "marble", "marble_2",
           "chamber_wall", "carpet", "lawn", "street_edge", "wall_top"]


def terrain():
    img = Image.new("RGBA", (16 * 8, 16 * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(97)

    def tile(i):
        return (i % 8) * 16, (i // 8) * 16

    def stones(x, y, base, var, dark, size=6):
        d.rectangle((x, y, x + 15, y + 15), fill=base)
        for row in range(0, 16, 4):
            off = 2 if (row // 4) % 2 else 0
            for col in range(-off, 16, size):
                if rng.random() < 0.55:
                    d.rectangle((max(x, x + col + 1), y + row + 1, min(x + 15, x + col + size - 2), y + row + 2), fill=var)
            d.line([(x, y + row + 3), (x + 15, y + row + 3)], fill=dark if rng.random() < 0.4 else var)

    for i, name in enumerate(TERRAIN):
        x, y = tile(i)
        if name in ("grass", "grass_2", "lawn"):
            base = {"grass": GRASS, "grass_2": GRASS_2, "lawn": (132, 172, 98)}[name]
            d.rectangle((x, y, x + 15, y + 15), fill=base)
            for _ in range(6):
                gx, gy = x + rng.randrange(15), y + 2 + rng.randrange(13)
                d.line([(gx, gy), (gx, gy - 2)], fill=GRASS_LIGHT)
        elif name == "street":
            stones(x, y, COBBLE, COBBLE_2, COBBLE_DARK)
        elif name == "street_2":
            stones(x, y, COBBLE_2, COBBLE, COBBLE_DARK)
        elif name == "street_edge":
            stones(x, y, COBBLE, COBBLE_2, COBBLE_DARK)
            d.line([(x, y), (x + 15, y)], fill=COBBLE_DARK)
        elif name == "plaza":
            d.rectangle((x, y, x + 15, y + 15), fill=PLAZA, outline=COBBLE_2)
            d.line([(x + 8, y), (x + 8, y + 15)], fill=COBBLE_2)
            d.line([(x, y + 8), (x + 15, y + 8)], fill=COBBLE_2)
        elif name in ("marble", "marble_2"):
            d.rectangle((x, y, x + 15, y + 15), fill=MARBLE if name == "marble" else MARBLE_SHADE, outline=MARBLE_DARK)
            d.line([(x + 3, y + 4), (x + 9, y + 10)], fill=MARBLE_DARK)
        elif name == "chamber_wall":
            d.rectangle((x, y, x + 15, y + 15), fill=WALL)
            for row in range(0, 16, 5):
                d.line([(x, y + row), (x + 15, y + row)], fill=WALL_DARK)
                off = 4 if (row // 5) % 2 else 0
                for col in range(off, 16, 8):
                    d.line([(x + col, y + row), (x + col, y + row + 4)], fill=WALL_DARK)
        elif name == "wall_top":
            d.rectangle((x, y, x + 15, y + 15), fill=(96, 72, 64))
            d.line([(x, y + 14), (x + 15, y + 14)], fill=GOLD_DARK)
        elif name == "carpet":
            d.rectangle((x, y, x + 15, y + 15), fill=CARPET)
            d.line([(x + 1, y), (x + 1, y + 15)], fill=GOLD)
            d.line([(x + 14, y), (x + 14, y + 15)], fill=GOLD)
            d.point((x + 8, y + 8), fill=CARPET_DARK)
    return img


def main():
    save(council_hall(), "council_hall")
    save(library(), "pomidor_library")
    save(clothing_shop(), "pomidor_clothing")
    save(beer_hall(), "beer_hall")
    walls = [(236, 206, 160), (232, 182, 150), (226, 214, 170), (240, 196, 132), (214, 196, 196), (236, 222, 200)]
    roofs = [(TILE_RED, TILE_RED_DARK, TILE_RED_LIGHT), ((196, 104, 56), (150, 72, 40), (228, 140, 84)),
             ((150, 64, 60), (110, 44, 44), (186, 92, 80))]
    for i in range(6):
        save(townhouse(walls[i], roofs[i % 3], i, floors=3 if i % 2 == 0 else 2,
                       height=72 if i % 2 == 0 else 60), f"townhouse_{i}")
    for i in range(3):
        save(row_house(i), f"row_house_{i}")
    save(spiral_house(), "spiral_house")
    save(tomato_house(), "tomato_house")
    save(pear_house(), "pear_house")
    save(pepper_house(), "pepper_house")
    save(fruit_tree(), "fruit_tree")
    for i, col in enumerate((ORANGE, TOMATO, (78, 131, 207))):
        save(market_stall(col, i), f"market_stall_{i}")
    for i, img in enumerate(townsfolk()):
        save(img, f"townsfolk_{i}")
    save(guard(), "council_guard")
    for planet in PLANETS:
        for i in range(2):
            save(councillor(planet, i), f"councillor_{planet}_{i}")
        save(banner(planet), f"banner_{planet}")
    for i, office in enumerate(OFFICES):
        save(secretary(office, i), f"secretary_{office}")
        save(secretary_desk(office), f"desk_{office}")
    save(council_table(), "council_table")
    save(chamber_exit(), "chamber_exit")
    save(terrain(), "pomidor_terrain")
    orange = recolor(PLAYER_RED, {TUNIC: ORANGE, TUNIC_DARK: ORANGE_DARK})
    orange.save(ROOT / "assets/art/player_orange.png")
    print("wrote", len(list(OUT.glob("*.png"))), "Pomidor sprites")


if __name__ == "__main__":
    main()
