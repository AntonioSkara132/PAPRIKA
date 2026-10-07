#!/usr/bin/python3
"""Render a concept of Pomidor, the planet where the Council of all planets meets.

The scene is built like a rendered Tiled map: 16-pixel ground tiles, then sprites
sorted by their bottom edge. The Brudet market, forge, townhouses, fountain and
villagers are reused. The new Pomidor pieces (the Council Hall, library, orange
clothing shop, beer hall and the rich quarter's spiral and fruit-shaped houses)
are drawn here in the same style: dark #1c1730 outlines, flat shading and soft
shadows. Nothing on Pomidor needs to obey physics, so the rich build houses that
stand on one thin stem or float above their gardens.

Writes art/concepts/pomidor_concept.png (whole town, 1x) and
art/concepts/pomidor_concept_detail.png (square and rich quarter, 2x).
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/pomidor_concept.png"
DETAIL_OUT = ROOT / "art/concepts/pomidor_concept_detail.png"
RIVER = ROOT / "assets/art/river_planet"

TILE = 16
MAP_W, MAP_H = 52, 34

INK = (28, 23, 48)
SHADOW = (28, 23, 48, 90)
GRASS = (118, 156, 92)
GRASS_2 = (108, 146, 86)
GRASS_LIGHT = (146, 178, 104)
COBBLE = (214, 196, 168)
COBBLE_2 = (198, 178, 150)
COBBLE_DARK = (170, 148, 122)
TILE_RED = (186, 72, 58)
TILE_RED_DARK = (142, 50, 46)
TILE_RED_LIGHT = (220, 108, 84)
PLASTER = (236, 220, 184)
PLASTER_SHADE = (212, 192, 154)
MARBLE = (240, 236, 226)
MARBLE_SHADE = (204, 198, 188)
GOLD = (232, 186, 74)
GOLD_DARK = (178, 128, 50)
WINDOW = (58, 142, 168)
WINDOW_LIGHT = (122, 196, 214)
DOOR = (104, 62, 44)
WOOD = (122, 84, 56)
ORANGE = (236, 128, 44)
ORANGE_DARK = (186, 88, 30)
ORANGE_LIGHT = (252, 172, 88)
TOMATO = (214, 54, 44)
TOMATO_DARK = (156, 34, 36)
TOMATO_LIGHT = (246, 110, 84)
LEAF = (72, 132, 60)
LEAF_DARK = (46, 92, 46)
PEAR = (200, 196, 72)
PEAR_DARK = (150, 146, 52)
PEPPER = (226, 196, 52)
VIOLET = (126, 84, 160)
VIOLET_DARK = (88, 56, 118)
VIOLET_LIGHT = (168, 128, 198)
WATER = (82, 156, 196)

FONT = ImageFont.load_default()


def outline_rect(d, box, fill, width=1):
    d.rectangle(box, fill=fill, outline=INK, width=width)


def sign(img, cx, y, text, bg=INK, fg=(236, 230, 214)):
    d = ImageDraw.Draw(img)
    w = int(d.textlength(text, font=FONT))
    box = (cx - w // 2 - 4, y, cx + w // 2 + 3, y + 12)
    d.rectangle(box, fill=bg, outline=(236, 230, 214) if bg == INK else INK)
    d.text((cx - w // 2, y + 1), text, font=FONT, fill=fg)


def shadow(img, x0, y0, x1, y1):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((x0, y0, x1, y1), fill=SHADOW)
    img.alpha_composite(layer)


def roof(d, x0, x1, y_top, y_base, color=TILE_RED, dark=TILE_RED_DARK, light=TILE_RED_LIGHT):
    d.polygon([(x0 - 4, y_base), (x0 + 6, y_top), (x1 - 6, y_top), (x1 + 4, y_base)], fill=color, outline=INK)
    d.line([(x0 + 7, y_top + 2), (x1 - 7, y_top + 2)], fill=light)
    d.line([(x0 - 2, y_base - 1), (x1 + 2, y_base - 1)], fill=dark)


def windows(d, x0, x1, y, count, h=10):
    step = (x1 - x0) / count
    for i in range(count):
        wx = int(x0 + step * i + step / 2) - 4
        d.rectangle((wx, y, wx + 8, y + h), fill=WINDOW, outline=INK)
        d.line([(wx + 2, y + 2), (wx + 2, y + h - 2)], fill=WINDOW_LIGHT)


def door(d, cx, y_base, w=12, h=18):
    d.rectangle((cx - w // 2, y_base - h, cx + w // 2, y_base), fill=DOOR, outline=INK)
    d.point((cx + w // 2 - 3, y_base - h // 2), fill=GOLD)


# ---------- new building sprites ----------

def council_hall():
    """Domed hall of white marble; the dome is a ripe tomato with a gold stem."""
    img = Image.new("RGBA", (176, 150), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = 146
    # steps
    for i, inset in enumerate((0, 6, 12)):
        outline_rect(d, (6 + inset, base - 6 - i * 4, 169 - inset, base - i * 4), MARBLE_SHADE if i == 0 else MARBLE)
    # main block
    outline_rect(d, (18, 64, 157, base - 12), MARBLE)
    d.rectangle((19, 120, 156, base - 13), fill=MARBLE_SHADE)
    # columns
    for cx in range(28, 152, 18):
        d.rectangle((cx - 3, 76, cx + 3, base - 13), fill=(250, 248, 240), outline=INK)
        d.line([(cx - 1, 78), (cx - 1, base - 15)], fill=MARBLE_SHADE)
    # pediment
    d.polygon([(12, 76), (88, 50), (163, 76)], fill=MARBLE, outline=INK)
    d.polygon([(30, 72), (88, 56), (145, 72)], fill=MARBLE_SHADE)
    d.rectangle((12, 74, 163, 80), fill=GOLD, outline=INK)
    # tomato dome
    d.rectangle((60, 34, 116, 54), fill=MARBLE, outline=INK)
    windows(d, 62, 114, 39, 4, 9)
    d.ellipse((50, 2, 126, 46), fill=TOMATO, outline=INK)
    d.arc((56, 6, 120, 44), 200, 260, fill=TOMATO_LIGHT, width=3)
    d.arc((52, 4, 124, 46), 20, 110, fill=TOMATO_DARK, width=3)
    for ang in range(0, 360, 60):
        x = 88 + 9 * math.cos(math.radians(ang))
        y = 5 + 3 * math.sin(math.radians(ang))
        d.line([(88, 4), (x, y)], fill=LEAF, width=2)
    d.rectangle((86, 0, 90, 5), fill=GOLD, outline=INK)
    # door and banners of the planets
    door(d, 88, base - 13, 20, 28)
    d.arc((78, base - 48, 98, base - 30), 180, 360, fill=INK)
    for bx, col in ((40, (200, 60, 50)), (58, (236, 128, 44)), (118, (66, 120, 176)), (136, (96, 150, 80))):
        d.rectangle((bx - 4, 84, bx + 4, 104), fill=col, outline=INK)
        d.polygon([(bx - 4, 104), (bx, 100), (bx + 4, 104)], fill=MARBLE)
    sign(img, 88, 82, "COUNCIL HALL")
    return img


def library():
    img = Image.new("RGBA", (104, 92), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline_rect(d, (8, 30, 95, 88), PLASTER)
    d.rectangle((9, 74, 94, 87), fill=PLASTER_SHADE)
    roof(d, 8, 95, 10, 32, VIOLET, VIOLET_DARK, VIOLET_LIGHT)
    d.rectangle((44, 2, 60, 14), fill=PLASTER, outline=INK)
    d.ellipse((47, 4, 57, 12), fill=WINDOW, outline=INK)
    for wx in (16, 70):
        d.rounded_rectangle((wx, 44, wx + 16, 66), 6, fill=WINDOW, outline=INK)
        d.line([(wx + 8, 46), (wx + 8, 65)], fill=INK)
    door(d, 52, 87, 14, 22)
    # an open book over the door
    d.polygon([(44, 58), (52, 61), (60, 58), (60, 64), (52, 66), (44, 64)], fill=MARBLE, outline=INK)
    d.line([(52, 61), (52, 66)], fill=INK)
    sign(img, 52, 34, "LIBRARY")
    return img


def clothing_shop():
    """Shop with an orange awning and fabric rolls in the window."""
    img = Image.new("RGBA", (88, 74), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline_rect(d, (6, 24, 81, 70), PLASTER)
    roof(d, 6, 81, 8, 26)
    # striped orange awning
    d.polygon([(4, 36), (84, 36), (80, 46), (8, 46)], fill=ORANGE, outline=INK)
    for sx in range(10, 80, 10):
        d.polygon([(sx, 36), (sx + 5, 36), (sx + 4, 46), (sx - 1, 46)], fill=ORANGE_LIGHT)
    # window with fabric rolls
    d.rectangle((10, 49, 40, 66), fill=(244, 232, 210), outline=INK)
    for i, col in enumerate((ORANGE, ORANGE_DARK, ORANGE_LIGHT, TOMATO)):
        d.rectangle((13 + i * 7, 52, 18 + i * 7, 65), fill=col, outline=INK)
    # orange tunic on a stand
    d.rectangle((56, 49, 76, 66), fill=(244, 232, 210), outline=INK)
    d.polygon([(60, 53), (72, 53), (74, 58), (70, 58), (70, 65), (62, 65), (62, 58), (58, 58)], fill=ORANGE, outline=INK)
    door(d, 48, 70, 10, 18)
    sign(img, 44, 26, "CLOTHES", bg=ORANGE, fg=INK)
    return img


def beer_hall():
    img = Image.new("RGBA", (96, 78), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline_rect(d, (6, 26, 89, 74), (164, 112, 72))
    for y in range(32, 74, 6):
        d.line([(7, y), (88, y)], fill=(140, 94, 60))
    roof(d, 6, 89, 6, 28, (110, 76, 52), (80, 54, 38), (146, 104, 70))
    d.rectangle((70, 0, 78, 14), fill=(120, 110, 104), outline=INK)
    windows(d, 10, 36, 44, 2, 12)
    windows(d, 60, 86, 44, 2, 12)
    door(d, 48, 74, 16, 22)
    # hanging mug sign
    d.line([(84, 32), (94, 32)], fill=INK)
    d.rectangle((86, 34, 93, 44), fill=GOLD, outline=INK)
    d.rectangle((86, 33, 93, 36), fill=(250, 248, 240), outline=INK)
    sign(img, 48, 30, "BEER HALL")
    # barrels
    for bx in (12, 24):
        d.ellipse((bx - 5, 64, bx + 5, 76), fill=WOOD, outline=INK)
        d.line([(bx - 5, 70), (bx + 5, 70)], fill=INK)
    return img


def spiral_house():
    """Tower that winds up like a shell, standing on a stem far too thin for it."""
    img = Image.new("RGBA", (64, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((29, 84, 35, 116), fill=MARBLE_SHADE, outline=INK)
    d.ellipse((20, 110, 44, 118), fill=MARBLE_SHADE, outline=INK)
    for i in range(6):
        w = 26 - i * 3
        y = 86 - i * 13
        shift = int(6 * math.sin(i * 1.2))
        col = (VIOLET, VIOLET_LIGHT)[i % 2]
        d.ellipse((32 - w + shift, y - 10, 32 + w + shift, y + 4), fill=col, outline=INK)
        d.rectangle((28 + shift, y - 6, 34 + shift, y), fill=WINDOW, outline=INK)
    d.line([(32 + int(6 * math.sin(6)), 12), (32, 2)], fill=INK, width=2)
    d.ellipse((29, 0, 35, 6), fill=GOLD, outline=INK)
    return img


def tomato_house():
    img = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 12, 68, 68), fill=TOMATO, outline=INK)
    d.arc((10, 16, 62, 64), 200, 260, fill=TOMATO_LIGHT, width=4)
    d.arc((6, 14, 66, 66), 20, 120, fill=TOMATO_DARK, width=4)
    for ang in range(0, 360, 72):
        x = 36 + 14 * math.cos(math.radians(ang))
        y = 14 + 5 * math.sin(math.radians(ang))
        d.polygon([(36, 12), (x, y), (36 + (x - 36) * 0.4, y + 3)], fill=LEAF, outline=LEAF_DARK)
    d.rectangle((34, 2, 38, 13), fill=LEAF_DARK, outline=INK)
    d.ellipse((14, 30, 26, 42), fill=WINDOW, outline=INK)
    d.ellipse((46, 30, 58, 42), fill=WINDOW, outline=INK)
    door(d, 36, 66, 12, 16)
    return img


def pear_house():
    """A pear that floats above its garden; a ladder reaches up to the door."""
    img = Image.new("RGBA", (56, 104), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 26, 50, 74), fill=PEAR, outline=INK)
    d.ellipse((14, 6, 42, 40), fill=PEAR, outline=INK)
    d.rectangle((15, 26, 41, 36), fill=PEAR)
    d.arc((8, 28, 48, 72), 30, 120, fill=PEAR_DARK, width=3)
    d.rectangle((26, 0, 29, 8), fill=WOOD, outline=INK)
    d.polygon([(29, 4), (40, 0), (36, 7)], fill=LEAF, outline=INK)
    d.ellipse((22, 18, 32, 28), fill=WINDOW, outline=INK)
    d.rectangle((22, 52, 34, 70), fill=DOOR, outline=INK)
    # ladder down to the ground
    for x in (24, 32):
        d.line([(x, 72), (x, 100)], fill=WOOD, width=1)
    for y in range(76, 100, 5):
        d.line([(24, y), (32, y)], fill=WOOD)
    return img


def pepper_house():
    img = Image.new("RGBA", (48, 88), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(6, 18), (42, 18), (44, 40), (38, 70), (28, 86), (22, 86), (10, 70), (4, 40)], fill=PEPPER, outline=INK)
    d.line([(24, 22), (24, 82)], fill=(196, 164, 40), width=2)
    d.rectangle((14, 10, 34, 19), fill=LEAF, outline=INK)
    d.rectangle((22, 2, 26, 11), fill=LEAF_DARK, outline=INK)
    d.rectangle((10, 30, 18, 40), fill=WINDOW, outline=INK)
    d.rectangle((30, 30, 38, 40), fill=WINDOW, outline=INK)
    door(d, 24, 66, 10, 14)
    return img


def villager(color, hat):
    img = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 2, 12, 10), fill=(232, 190, 150), outline=INK)
    if hat:
        d.rectangle((3, 1, 13, 4), fill=hat, outline=INK)
    d.rectangle((3, 10, 13, 20), fill=color, outline=INK)
    d.rectangle((4, 20, 7, 23), fill=INK)
    d.rectangle((9, 20, 12, 23), fill=INK)
    return img


def council_guard():
    """Council guard in red and gold with a spear."""
    img = Image.new("RGBA", (16, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([(14, 0), (14, 27)], fill=WOOD, width=1)
    d.polygon([(12, 4), (14, 0), (16, 4)], fill=MARBLE_SHADE, outline=INK)
    d.ellipse((3, 5, 11, 13), fill=(232, 190, 150), outline=INK)
    d.rectangle((2, 4, 12, 7), fill=GOLD, outline=INK)
    d.rectangle((2, 13, 12, 23), fill=TOMATO, outline=INK)
    d.line([(3, 16), (11, 16)], fill=GOLD)
    d.rectangle((3, 23, 6, 27), fill=INK)
    d.rectangle((8, 23, 11, 27), fill=INK)
    return img


def tree(round_crown=True):
    img = Image.new("RGBA", (28, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((12, 24, 16, 39), fill=WOOD, outline=INK)
    if round_crown:
        d.ellipse((2, 2, 26, 28), fill=LEAF, outline=INK)
        d.arc((5, 5, 23, 25), 200, 280, fill=(108, 170, 82), width=3)
        for fx, fy in ((9, 12), (18, 9), (15, 19)):
            d.ellipse((fx - 2, fy - 2, fx + 2, fy + 2), fill=TOMATO, outline=INK)
    else:
        d.polygon([(14, 0), (26, 28), (2, 28)], fill=LEAF_DARK, outline=INK)
    return img


def load(name):
    return Image.open(RIVER / name).convert("RGBA")


# ---------- ground ----------

def ground():
    rng = random.Random(97)
    img = Image.new("RGBA", (MAP_W * TILE, MAP_H * TILE), GRASS + (255,))
    d = ImageDraw.Draw(img)
    for tx in range(MAP_W):
        for ty in range(MAP_H):
            if rng.random() < 0.35:
                x, y = tx * TILE, ty * TILE
                d.rectangle((x, y, x + 15, y + 15), fill=GRASS_2)
            if rng.random() < 0.18:
                x, y = tx * TILE + rng.randrange(14), ty * TILE + rng.randrange(14)
                d.line([(x, y), (x, y - 2)], fill=GRASS_LIGHT)
    return img


def cobbles(img, box, rng):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=COBBLE)
    for y in range(y0, y1, 6):
        off = 4 if (y // 6) % 2 else 0
        for x in range(x0 - off, x1, 8):
            if rng.random() < 0.5:
                d.rectangle((max(x0, x + 1), y + 1, min(x1, x + 6), min(y1, y + 4)), fill=COBBLE_2)
    d.rectangle(box, outline=COBBLE_DARK)


def render():
    rng = random.Random(83)
    img = ground()
    W, H = img.size
    # roads and the square
    square = (232, 220, 600, 432)
    cobbles(img, square, rng)
    cobbles(img, (0, 300, W, 332), rng)              # east-west road
    cobbles(img, (400, 432, 432, H), rng)           # road south to the landing ground
    cobbles(img, (600, 160, 616, 300), rng)          # lane up to the rich quarter
    cobbles(img, (600, 144, 800, 160), rng)
    # the rich quarter's garden lawn and pond
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((632, 24, 824, 256), 12, fill=(132, 172, 98), outline=LEAF_DARK)
    d.ellipse((700, 196, 770, 236), fill=WATER, outline=INK)
    # landing pad in the south
    d.rectangle((360, 480, 472, 540), fill=(170, 170, 176), outline=INK)
    d.rectangle((366, 486, 466, 534), outline=GOLD)
    d.text((388, 504), "LANDING", font=FONT, fill=INK)

    sprites = []  # (bottom y, x, image)

    def put(sprite, x, bottom, shadow_w=None):
        sprites.append((bottom, x, sprite, shadow_w))

    put(council_hall(), 328, 232)
    put(load("town_center_fountain.png"), 384, 360)
    put(library(), 120, 296)
    put(load("river_market.png"), 236, 434, )
    put(clothing_shop(), 610, 296)
    put(load("river_forge.png"), 610, 434)
    put(beer_hall(), 480, 534)
    put(load("river_townhouse.png"), 40, 296)
    put(load("river_townhouse.png"), 30, 470)
    put(load("river_townhouse.png"), 110, 470)
    put(load("river_townhouse.png"), 720, 470)
    # rich quarter: houses that ignore physics
    put(spiral_house(), 646, 140)
    put(tomato_house(), 736, 124)
    put(pear_house(), 650, 252)
    put(pepper_house(), 776, 232)
    for x, b in ((210, 230), (186, 210), (16, 200), (520, 210), (612, 120), (816, 300), (300, 520), (560, 470), (180, 520)):
        put(tree(rng.random() < 0.7), x, b)
    # people
    put(council_guard(), 380, 240)
    put(council_guard(), 452, 240)
    for x, y, col, hat in ((300, 300, ORANGE, None), (460, 330, (66, 120, 176), GOLD), (520, 388, TOMATO, None),
                           (350, 400, (96, 150, 80), (230, 220, 200)), (640, 312, ORANGE, ORANGE_DARK),
                           (560, 300, VIOLET, None), (150, 316, (66, 120, 176), None)):
        put(villager(col, hat), x, y)
    put(load("river_villager_sunhat.png"), 270, 372)
    put(load("river_villager_shawl.png"), 500, 420)

    for bottom, x, sprite, _ in sorted(sprites, key=lambda s: s[0]):
        shadow(img, x + 2, bottom - 5, x + sprite.width - 2, bottom + 3)
        img.alpha_composite(sprite, (x, bottom - sprite.height))
    return img


def main():
    img = render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    detail = img.crop((200, 0, 840, 360)).resize((1280, 720), Image.NEAREST)
    detail.save(DETAIL_OUT)
    print(OUT, img.size)
    print(DETAIL_OUT, detail.size)


if __name__ == "__main__":
    main()
