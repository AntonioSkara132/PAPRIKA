#!/usr/bin/python3
"""Draw the Lasta, the old interplanetary ship the party buys on Otpornik.

The Lasta is an old spaceship refitted many times. Its hull is riveted steel
with mismatched patch plates; inside, owners have added wood panelling, plank
floors and stone flagstones round the drive, so it looks more like an old
river boat than a navy ship. It has three places to walk:

- the top deck: the flat top of the hull, planked, with an iron railing all
  round. It is only open on the ground; a sign at the hatch says to seal it
  before launch;
- the upper floor: the control room in the nose behind the big viewports, a
  map table in the middle, and at the rear the drive machine, whose four
  square cylinders pump up and down on a stone bed;
- the lower floor, smaller: bunks, lockers and the store room.

The interiors are drawn at half size, like the Iskra rooms, and the map shows
them at 2x. Each room function returns the image and the rectangles that
block walking, in source pixels.

Writes art/concepts/otpornik_ship_concept.png, a sheet with the outside view
and the three floors, so the design can be checked before it goes into the
game.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CONCEPT_OUT = ROOT / "art/concepts/otpornik_ship_concept.png"
ASSETS = ROOT / "assets/art/otpornik"
FONT = ImageFont.load_default()

INK = (28, 23, 48)
SPACE = (18, 14, 38)
STAR = (200, 196, 230)
HULL = (150, 150, 158)
HULL_LIGHT = (184, 184, 190)
HULL_DARK = (104, 104, 116)
PATCH = [(132, 140, 128), (160, 146, 128), (126, 132, 150), (170, 160, 150)]
RUST = (150, 84, 50)
RUST_DARK = (110, 60, 40)
WOOD = (122, 84, 56)
WOOD_LIGHT = (150, 108, 70)
WOOD_DARK = (88, 58, 40)
WOOD_WORN = (104, 74, 54)
PLANK_GAP = (66, 44, 32)
STONE = (150, 140, 124)
STONE_LIGHT = (176, 166, 148)
STONE_DARK = (112, 102, 90)
IRON = (70, 68, 78)
IRON_LIGHT = (110, 108, 120)
BRASS = (205, 158, 81)
BRASS_DARK = (150, 110, 56)
COPPER = (196, 116, 64)
GLASS = (78, 120, 160)
GLASS_LIGHT = (170, 210, 230)
GLOW = (150, 220, 255)
GLOW_HOT = (250, 246, 170)
RED = (186, 64, 52)
GREEN = (92, 150, 96)
CREAM = (238, 222, 184)
CLOTH = [(120, 70, 66), (84, 104, 132), (110, 120, 80), (150, 120, 80)]
SKIN = (226, 170, 128)
SKIN_DARK = (190, 132, 98)
HAIR = [(70, 44, 34), (196, 150, 70), (40, 30, 40), (170, 70, 50)]
OIL = (46, 42, 50)
SCORCH = (58, 52, 56)
CONCRETE = (150, 154, 158)
CONCRETE_2 = (138, 142, 148)
YELLOW = (236, 192, 56)


def canvas(w, h, fill=(0, 0, 0, 0)):
    img = Image.new("RGBA", (w, h), fill)
    return img, ImageDraw.Draw(img)


def stains(d, rng, area, count, colors, size=(2, 6)):
    x0, y0, x1, y1 = area
    for _ in range(count):
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        rx, ry = rng.randint(*size), rng.randint(1, max(1, size[1] // 2))
        d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=rng.choice(colors))


def planks(d, rng, area, horizontal=True, colors=(WOOD, WOOD_LIGHT, WOOD_WORN), step=6):
    """Plank floor with staggered joints, a few replaced boards and nail heads."""
    x0, y0, x1, y1 = area
    d.rectangle(area, fill=colors[0])
    if horizontal:
        for y in range(y0, y1, step):
            c = rng.choice(colors)
            d.rectangle((x0, y, x1, min(y1, y + step - 1)), fill=c)
            d.line((x0, y, x1, y), fill=PLANK_GAP)
            x = x0 + rng.randint(4, 30)
            while x < x1:
                d.line((x, y, x, min(y1, y + step - 1)), fill=PLANK_GAP)
                d.point((x + 2, y + step // 2), fill=IRON)
                x += rng.randint(26, 48)
    else:
        for x in range(x0, x1, step):
            c = rng.choice(colors)
            d.rectangle((x, y0, min(x1, x + step - 1), y1), fill=c)
            d.line((x, y0, x, y1), fill=PLANK_GAP)
            y = y0 + rng.randint(4, 30)
            while y < y1:
                d.line((x, y, min(x1, x + step - 1), y), fill=PLANK_GAP)
                y += rng.randint(26, 48)


def flagstones(d, rng, area):
    """Irregular stone slabs, set in rows of uneven widths."""
    x0, y0, x1, y1 = area
    d.rectangle(area, fill=STONE_DARK)
    y = y0
    while y < y1:
        h = rng.randint(7, 11)
        x = x0
        while x < x1:
            w = rng.randint(9, 16)
            c = rng.choice((STONE, STONE, STONE_LIGHT, (140, 132, 118)))
            d.rectangle((x + 1, y + 1, min(x1, x + w - 1), min(y1, y + h - 1)), fill=c)
            if rng.random() < .12:
                d.line((x + 2, y + 2, x + w // 2, y + h - 2), fill=STONE_DARK)
            x += w
        y += h


def plated_wall(d, rng, area, base=HULL):
    """Riveted steel plates with odd patch plates and rust runs."""
    x0, y0, x1, y1 = area
    d.rectangle(area, fill=base)
    x = x0
    while x < x1:
        w = rng.randint(14, 26)
        c = rng.choice([base, base, HULL_LIGHT] + PATCH[:2])
        d.rectangle((x, y0, min(x1, x + w), y1), fill=c, outline=HULL_DARK)
        for ry in (y0 + 2, y1 - 2):
            for rx in range(x + 2, min(x1, x + w) - 1, 4):
                d.point((rx, ry), fill=HULL_DARK)
        if rng.random() < .35:
            rx = rng.randint(x + 2, max(x + 3, min(x1, x + w) - 2))
            d.line((rx, y0 + 3, rx + rng.randint(-1, 1), y0 + rng.randint(6, max(7, y1 - y0))), fill=RUST)
        x += w


def wood_wall(d, rng, area):
    """Vertical wood panelling above a dark skirting board."""
    x0, y0, x1, y1 = area
    planks(d, rng, area, horizontal=False, colors=(WOOD_DARK, WOOD, WOOD_WORN), step=5)
    d.line((x0, y1 - 2, x1, y1 - 2), fill=PLANK_GAP, width=3)
    d.line((x0, y0, x1, y0), fill=INK)


def viewport(d, box, stars, rng, frame=BRASS):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=SPACE, outline=INK)
    for _ in range(stars):
        d.point((rng.randint(x0 + 1, x1 - 1), rng.randint(y0 + 1, y1 - 1)), fill=rng.choice((STAR, GLOW, (120, 110, 170))))
    d.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), outline=frame)
    d.line((x0 + 2, y0 + 2, x0 + 4, y0 + 2), fill=GLASS_LIGHT)


def porthole(d, cx, cy, r, rng):
    d.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), fill=INK)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BRASS)
    d.ellipse((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), fill=SPACE)
    d.point((cx - 1, cy - 1), fill=GLASS_LIGHT)
    d.point((cx + rng.randint(-1, 1), cy + 1), fill=STAR)


def pinup(d, x, y, rng, kind):
    """A small, faded pin-up poster: a woman leaning back on a planet or in a deck chair."""
    paper = rng.choice(((214, 196, 160), (226, 206, 168), (204, 176, 150)))
    d.rectangle((x, y, x + 13, y + 18), fill=paper, outline=INK)
    sky = ((92, 70, 120), (176, 96, 86), (70, 120, 140))[kind % 3]
    d.rectangle((x + 1, y + 1, x + 12, y + 11), fill=sky)
    hair = HAIR[kind % len(HAIR)]
    suit = (RED, (60, 120, 170), (220, 200, 90))[kind % 3]
    if kind % 2 == 0:
        # leaning back with one knee raised
        d.ellipse((x + 3, y + 3, x + 6, y + 6), fill=SKIN)
        d.line((x + 2, y + 3, x + 4, y + 7), fill=hair, width=2)
        d.line((x + 5, y + 7, x + 8, y + 10), fill=SKIN, width=2)
        d.point((x + 6, y + 8), fill=suit)
        d.point((x + 7, y + 9), fill=suit)
        d.line((x + 8, y + 10, x + 11, y + 7), fill=SKIN)
        d.line((x + 9, y + 11, x + 12, y + 12), fill=SKIN)
        d.arc((x - 2, y + 9, x + 16, y + 20), 180, 360, fill=(220, 160, 90))
    else:
        # standing, hand on hip, hair blowing
        d.ellipse((x + 6, y + 2, x + 9, y + 5), fill=SKIN)
        d.line((x + 9, y + 2, x + 12, y + 4), fill=hair, width=2)
        d.rectangle((x + 6, y + 6, x + 8, y + 8), fill=suit)
        d.line((x + 6, y + 9, x + 5, y + 12), fill=SKIN)
        d.line((x + 8, y + 9, x + 9, y + 12), fill=SKIN)
        d.line((x + 9, y + 6, x + 10, y + 8), fill=SKIN)
    d.rectangle((x + 1, y + 13, x + 12, y + 17), fill=paper)
    for i in range(3):
        d.line((x + 2, y + 14 + i % 2 * 2, x + 2 + rng.randint(5, 9), y + 14 + i % 2 * 2), fill=(150, 60, 60) if i == 0 else (120, 100, 90))
    d.point((x + 6, y), fill=RED)
    if rng.random() < .5:
        d.polygon([(x + 13, y + 18), (x + 9, y + 18), (x + 13, y + 14)], fill=(170, 150, 120), outline=INK)


def ladder(d, x, y0, y1):
    d.line((x, y0, x, y1), fill=IRON, width=2)
    d.line((x + 7, y0, x + 7, y1), fill=IRON, width=2)
    for y in range(y0 + 2, y1, 4):
        d.line((x + 1, y, x + 6, y), fill=IRON_LIGHT)


def hatch(d, cx, cy, open_hole=True):
    d.rectangle((cx - 9, cy - 7, cx + 9, cy + 7), fill=IRON, outline=INK)
    d.rectangle((cx - 7, cy - 5, cx + 7, cy + 5), fill=INK if open_hole else IRON_LIGHT)
    for x in (cx - 8, cx + 8):
        for y in (cy - 6, cy + 6):
            d.point((x, y), fill=IRON_LIGHT)
    if open_hole:
        ladder(d, cx - 4, cy - 4, cy + 5)


def stairs_down(d, box):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=INK)
    steps = (y1 - y0) // 4
    for i in range(steps):
        shade = tuple(int(c * (1 - i / (steps + 2))) for c in WOOD_LIGHT)
        d.rectangle((x0 + 1, y0 + 1 + i * 4, x1 - 1, y0 + 3 + i * 4), fill=shade)
    d.rectangle(box, outline=IRON_LIGHT)


def railing_h(d, x0, x1, y, post=8):
    d.line((x0, y, x1, y), fill=INK, width=3)
    d.line((x0, y - 1, x1, y - 1), fill=IRON_LIGHT)
    for x in range(x0, x1 + 1, post):
        d.rectangle((x - 1, y - 4, x + 1, y + 2), fill=IRON, outline=INK)


def railing_v(d, x, y0, y1, post=8):
    d.line((x, y0, x, y1), fill=INK, width=3)
    d.line((x - 1, y0, x - 1, y1), fill=IRON_LIGHT)
    for y in range(y0, y1 + 1, post):
        d.rectangle((x - 2, y - 1, x + 2, y + 1), fill=IRON, outline=INK)


def crate(d, x, y, w=12, h=10, color=WOOD_LIGHT):
    d.rectangle((x, y, x + w, y + h), fill=color, outline=INK)
    d.rectangle((x, y, x + w, y + 3), fill=tuple(min(255, c + 24) for c in color), outline=INK)
    d.line((x + 1, y + 4, x + w - 1, y + h - 1), fill=WOOD_DARK)
    d.line((x + w - 1, y + 4, x + 1, y + h - 1), fill=WOOD_DARK)


def barrel(d, x, y):
    d.ellipse((x, y, x + 10, y + 5), fill=WOOD_LIGHT, outline=INK)
    d.rectangle((x, y + 2, x + 10, y + 12), fill=WOOD, outline=INK)
    d.ellipse((x, y, x + 10, y + 5), fill=WOOD_LIGHT, outline=INK)
    for yy in (y + 6, y + 10):
        d.line((x + 1, yy, x + 9, yy), fill=IRON)


def bucket(d, x, y):
    d.polygon([(x, y), (x + 6, y), (x + 5, y + 6), (x + 1, y + 6)], fill=IRON_LIGHT, outline=INK)
    d.line((x + 1, y + 1, x + 5, y + 1), fill=GLASS)


# ---------- the drive machine ----------

def drive_machine(phase=0):
    """Four square cylinders on a stone bed, a crankshaft, flywheel and the glowing core.

    `phase` 0..3 shifts the pistons so the game can animate them."""
    img, d = canvas(84, 56)
    d.rectangle((2, 34, 81, 55), fill=STONE_DARK, outline=INK)
    for x in range(4, 80, 10):
        d.rectangle((x, 36, x + 8, 44), fill=STONE, outline=STONE_DARK)
        d.rectangle((x + 5 if x < 74 else x, 46, min(80, x + 13), 53), fill=STONE_LIGHT, outline=STONE_DARK)
    # crankshaft housing
    d.rectangle((6, 28, 62, 36), fill=IRON, outline=INK)
    d.line((7, 31, 61, 31), fill=IRON_LIGHT)
    for i in range(4):
        x = 9 + i * 13
        lift = (0, 3, 6, 3)[(i + phase) % 4]
        # square cylinder block
        d.rectangle((x, 12, x + 10, 28), fill=HULL_DARK, outline=INK)
        d.rectangle((x + 1, 13, x + 2, 27), fill=HULL_LIGHT)
        for y in (16, 22):
            d.line((x + 1, y, x + 9, y), fill=IRON)
        # square piston head riding out of the top
        top = 2 + lift
        d.rectangle((x + 2, top - 2, x + 8, top + 4), fill=BRASS, outline=INK)
        d.line((x + 3, top - 1, x + 7, top - 1), fill=GLOW_HOT if lift == 0 else CREAM)
        d.rectangle((x + 4, top + 4, x + 6, 12), fill=IRON_LIGHT)
    # flywheel
    d.ellipse((60, 14, 80, 34), fill=IRON, outline=INK)
    d.ellipse((64, 18, 76, 30), fill=IRON_LIGHT, outline=INK)
    a = phase * math.pi / 2
    for k in range(4):
        b = a + k * math.pi / 2
        d.line((70, 24, 70 + math.cos(b) * 9, 24 + math.sin(b) * 9), fill=INK)
    d.ellipse((68, 22, 72, 26), fill=BRASS, outline=INK)
    # core window: the actual star drive, still glowing
    d.rectangle((26, 38, 46, 50), fill=INK)
    d.rectangle((28, 40, 44, 48), fill=(70, 120, 170))
    d.rectangle((30, 42, 42, 46), fill=GLOW if phase % 2 else GLOW_HOT)
    d.rectangle((26, 38, 46, 50), outline=BRASS)
    # oil and soot
    d.line((10, 36, 14, 44), fill=OIL)
    d.point((55, 37), fill=OIL)
    d.line((60, 36, 63, 40), fill=RUST)
    return img


# ---------- outside view ----------

def ship_exterior():
    """Side view, nose right: patched hull, a railing along the top deck, two rows of windows."""
    rng = random.Random(12)
    img, d = canvas(220, 112)
    hull = [(10, 34), (24, 22), (160, 22), (196, 34), (216, 60), (196, 80), (150, 88), (24, 88), (8, 74)]
    # landing legs
    for x0, x1 in ((40, 30), (100, 104), (160, 172)):
        d.line((x0, 84, x1, 108), fill=INK, width=4)
        d.line((x0, 84, x1, 108), fill=IRON_LIGHT, width=2)
        d.rectangle((x1 - 7, 106, x1 + 7, 110), fill=IRON, outline=INK)
    d.polygon(hull, fill=HULL, outline=INK)
    # plates and patches inside the hull outline
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(hull, fill=255)
    plates, pd = canvas(*img.size)
    for row, (y0, y1) in enumerate(((22, 44), (44, 66), (66, 88))):
        x = 4 + row * 9
        while x < 216:
            w = rng.randint(14, 28)
            c = rng.choice([HULL, HULL, HULL_LIGHT, HULL_DARK] + PATCH)
            pd.rectangle((x, y0, x + w, y1), fill=c, outline=HULL_DARK)
            for rx in range(x + 2, x + w - 1, 4):
                pd.point((rx, y0 + 2), fill=HULL_DARK)
            x += w
    img.paste(plates, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.polygon(hull, outline=INK)
    # lower belly darker, keel line
    d.line((24, 80, 150, 80), fill=HULL_DARK, width=2)
    d.line((24, 86, 150, 86), fill=INK)
    # rust runs and scorch at the stern
    for _ in range(14):
        x = rng.randint(20, 190)
        y = rng.randint(30, 70)
        d.line((x, y, x, y + rng.randint(4, 12)), fill=rng.choice((RUST, RUST_DARK)))
    d.polygon([(8, 40), (26, 30), (30, 80), (10, 74)], fill=SCORCH)
    # drive at the stern: four square exhaust ports
    for i in range(4):
        y = 34 + i * 11
        d.rectangle((2, y, 12, y + 9), fill=IRON, outline=INK)
        d.rectangle((3, y + 2, 5, y + 7), fill=(120, 90, 70))
    # control room viewports in the nose
    d.polygon([(160, 26), (190, 34), (206, 52), (164, 50)], fill=GLASS, outline=INK)
    d.line((176, 30, 180, 50), fill=BRASS)
    d.line((192, 38, 196, 52), fill=BRASS)
    d.line((166, 32, 172, 44), fill=GLASS_LIGHT, width=2)
    # tape over a cracked pane
    d.line((184, 36, 190, 46), fill=CREAM, width=2)
    d.line((182, 44, 192, 38), fill=CREAM, width=2)
    # upper row: square windows; lower row: small portholes
    for x in range(56, 152, 18):
        d.rectangle((x, 32, x + 9, 40), fill=GLASS, outline=INK)
        d.rectangle((x + 1, 33, x + 8, 39), outline=BRASS_DARK)
        d.point((x + 2, 34), fill=GLASS_LIGHT)
    for x in range(64, 140, 16):
        d.ellipse((x, 58, x + 7, 65), fill=BRASS, outline=INK)
        d.ellipse((x + 2, 60, x + 5, 63), fill=GLASS)
    # side door and folding ramp
    d.rectangle((120, 54, 136, 78), fill=IRON, outline=INK)
    d.rectangle((122, 56, 134, 76), fill=IRON_LIGHT, outline=INK)
    d.point((132, 66), fill=YELLOW)
    d.polygon([(120, 78), (136, 78), (148, 108), (114, 108)], fill=HULL_DARK, outline=INK)
    for y in range(84, 108, 5):
        d.line((118 + (y - 84) // 6, y, 140 + (y - 84) // 3, y), fill=IRON)
    # name, faded
    d.text((38, 66), "LASTA", font=FONT, fill=(70, 52, 60))
    d.line((40, 76, 52, 76), fill=HULL_LIGHT)
    # top deck: wooden rail cap, iron railing posts and a mast
    d.rectangle((26, 16, 158, 22), fill=WOOD, outline=INK)
    for x in range(28, 158, 4):
        d.line((x, 17, x, 21), fill=WOOD_DARK)
    d.line((26, 8, 158, 8), fill=INK, width=2)
    d.line((26, 7, 158, 7), fill=IRON_LIGHT)
    for x in range(26, 159, 11):
        d.line((x, 8, x, 16), fill=IRON, width=2)
    d.line((90, 0, 90, 16), fill=IRON, width=2)
    d.rectangle((86, 0, 94, 3), fill=RED, outline=INK)
    d.line((90, 4, 104, 10), fill=IRON_LIGHT)
    # side ladder up to the deck
    ladder(d, 140, 18, 54)
    return img


# ---------- the three floors ----------

def top_deck():
    """Flat top of the hull, planked, iron railing round the edge."""
    rng = random.Random(31)
    w, h = 288, 112
    img, d = canvas(w, h, SPACE + (255,))
    # the port apron far below, seen past the hull edges
    for y in range(0, h, 16):
        for x in range(0, w, 16):
            d.rectangle((x, y, x + 15, y + 15), fill=CONCRETE if (x // 16 + y // 16) % 2 else CONCRETE_2)
    d.line((0, 100, w, 96), fill=YELLOW, width=2)
    hull = [(8, 22), (230, 22), (262, 36), (280, 56), (262, 76), (230, 92), (8, 92)]
    d.polygon([(x + 2, y + 6) for x, y in hull], fill=(60, 56, 70))
    d.polygon(hull, fill=HULL, outline=INK)
    plated_wall(d, rng, (10, 24, 228, 32))
    plated_wall(d, rng, (10, 82, 228, 90))
    d.polygon(hull, outline=INK)
    planks(d, rng, (16, 32, 226, 82))
    # the nose top: plated, a dome over the control room
    d.polygon([(228, 26), (258, 38), (274, 56), (258, 74), (228, 88)], fill=HULL_LIGHT, outline=INK)
    d.ellipse((234, 42, 262, 70), fill=GLASS, outline=INK)
    d.arc((238, 46, 258, 66), 200, 260, fill=GLASS_LIGHT, width=2)
    # stern: four square exhaust stacks over the drive
    for i in range(4):
        y = 30 + i * 13
        d.rectangle((2, y, 14, y + 10), fill=IRON, outline=INK)
        d.rectangle((4, y + 2, 12, y + 8), fill=SCORCH)
    d.polygon([(16, 32), (40, 32), (30, 82), (16, 82)], fill=(96, 72, 56))
    # railing round the deck, open at the nose dome and the stern stacks
    railing_h(d, 16, 226, 32)
    railing_h(d, 16, 226, 82)
    railing_v(d, 18, 34, 80)
    railing_v(d, 226, 34, 44)
    railing_v(d, 226, 70, 80)
    # hatch down to the upper floor, with a warning sign
    hatch(d, 120, 50)
    d.rectangle((132, 40, 160, 46), fill=YELLOW, outline=INK)
    d.text((133, 37), "SEAL", font=FONT, fill=INK)
    # mast with beacon and antenna wires
    d.rectangle((84, 38, 92, 46), fill=IRON, outline=INK)
    d.line((88, 38, 88, 26), fill=IRON_LIGHT, width=2)
    d.rectangle((85, 22, 91, 26), fill=RED, outline=INK)
    d.line((88, 26, 40, 36), fill=IRON_LIGHT)
    d.line((88, 26, 140, 34), fill=IRON_LIGHT)
    # bench, coiled cable, a telescope, crates lashed down, a pot plant
    d.rectangle((180, 70, 206, 76), fill=WOOD_DARK, outline=INK)
    d.rectangle((182, 66, 204, 70), fill=WOOD_LIGHT, outline=INK)
    d.ellipse((50, 64, 62, 74), outline=IRON_LIGHT, width=2)
    d.ellipse((53, 67, 59, 71), outline=IRON)
    d.line((196, 50, 210, 38), fill=BRASS, width=3)
    d.line((196, 50, 192, 58), fill=IRON)
    d.line((196, 50, 200, 58), fill=IRON)
    crate(d, 150, 66)
    crate(d, 162, 68, 10, 8, (140, 100, 70))
    d.line((148, 70, 174, 70), fill=(196, 170, 110))
    d.rectangle((210, 70, 216, 76), fill=COPPER, outline=INK)
    d.ellipse((208, 64, 218, 71), fill=GREEN, outline=INK)
    # wear: burnt planks, a missing board, an oil stain
    stains(d, rng, (40, 40, 200, 76), 6, (OIL, (96, 70, 52)), (3, 8))
    d.rectangle((70, 54, 82, 58), fill=INK)
    d.line((70, 56, 82, 56), fill=IRON)
    return img, {
        # A step inside the railing (y 32 and 82, x 18), so nobody stands on the fence.
        "walk": (28, 44, 212, 68),
        "blocked": [(84, 36, 93, 47), (110, 42, 130, 57), (148, 64, 175, 78), (178, 64, 220, 78), (190, 38, 212, 58), (68, 52, 84, 60)],
        "hatch": (120, 62), "ladder": (150, 46), "mast": (88, 48),
    }


def upper_floor(with_machine=True):
    """Control room in the nose, map table, then the drive machine on stone at the rear."""
    rng = random.Random(7)
    w, h = 288, 144
    img, d = canvas(w, h, SPACE + (255,))
    for _ in range(80):
        d.point((rng.randrange(w), rng.randrange(h)), fill=rng.choice((STAR, (120, 110, 170))))
    hull = [(6, 6), (226, 6), (260, 20), (282, 72), (260, 124), (226, 138), (6, 138)]
    d.polygon(hull, fill=HULL_DARK, outline=INK)
    # north wall face: wood panels between stone pillars, viewports and posters
    wood_wall(d, rng, (12, 10, 226, 40))
    for x in (12, 78, 152, 222):
        d.rectangle((x, 10, x + 6, 40), fill=STONE, outline=INK)
        for y in range(12, 40, 6):
            d.line((x + 1, y, x + 5, y), fill=STONE_DARK)
    viewport(d, (26, 16, 44, 30), 6, rng)
    viewport(d, (94, 16, 116, 30), 8, rng)
    viewport(d, (164, 16, 186, 30), 8, rng)
    pinup(d, 52, 16, rng, 0)
    pinup(d, 124, 15, rng, 1)
    pinup(d, 196, 17, rng, 2)
    # a calendar and tally marks scratched by bored crews
    d.rectangle((64, 18, 72, 28), fill=CREAM, outline=INK)
    d.line((65, 21, 71, 21), fill=RED)
    for i in range(7):
        d.line((140 + i * 2, 33, 140 + i * 2, 37), fill=CREAM)
    d.line((139, 37, 153, 33), fill=CREAM)
    # floors: stone round the drive, planks elsewhere
    flagstones(d, rng, (12, 40, 92, 132))
    planks(d, rng, (92, 40, 226, 132))
    # the nose: control room
    nose = [(226, 10), (256, 22), (276, 72), (256, 122), (226, 134)]
    d.polygon(nose, fill=WOOD_DARK, outline=INK)
    planks(d, rng, (226, 40, 254, 108), horizontal=False)
    d.polygon([(226, 10), (256, 22), (276, 72), (262, 72), (246, 30), (226, 24)], fill=GLASS, outline=INK)
    d.polygon([(276, 72), (256, 122), (226, 134), (226, 122), (246, 112), (262, 72)], fill=GLASS, outline=INK)
    for (x0, y0), (x1, y1) in (((236, 13), (234, 26)), ((250, 19), (244, 32)), ((266, 46), (256, 52)), ((266, 98), (256, 92)), ((250, 124), (244, 112))):
        d.line((x0, y0, x1, y1), fill=BRASS, width=2)
    for _ in range(12):
        d.point((rng.randint(230, 268), rng.randint(14, 30)), fill=STAR)
    d.line((240, 16, 248, 26), fill=CREAM, width=2)
    d.line((238, 24, 250, 18), fill=CREAM, width=2)
    # console arc with levers, gauges and lights
    d.polygon([(224, 46), (244, 40), (258, 72), (244, 104), (224, 98), (236, 72)], fill=WOOD, outline=INK)
    for y, c in ((52, RED), (62, GREEN), (82, YELLOW), (92, GREEN)):
        d.rectangle((240, y, 243, y + 2), fill=c)
    for y in (58, 70, 86):
        d.ellipse((244, y, 250, y + 6), fill=CREAM, outline=INK)
        d.line((247, y + 3, 249, y + 1), fill=RED)
    for x, y in ((232, 66), (234, 76)):
        d.line((x, y, x - 4, y - 4), fill=IRON, width=2)
        d.rectangle((x - 6, y - 6, x - 3, y - 3), fill=RED, outline=INK)
    # two worn chairs: pilot and captain
    for cx, cy in ((214, 60), (214, 84)):
        d.rectangle((cx - 6, cy - 6, cx + 6, cy + 6), fill=(120, 60, 50), outline=INK)
        d.rectangle((cx + 2, cy - 7, cx + 6, cy + 7), fill=(96, 48, 42), outline=INK)
        d.line((cx - 4, cy - 2, cx, cy + 2), fill=CREAM)
    # round map table with a star chart, a mug and a dagger stuck in it
    d.ellipse((150, 64, 186, 90), fill=WOOD_DARK, outline=INK)
    d.ellipse((152, 64, 184, 86), fill=WOOD_LIGHT, outline=INK)
    d.rectangle((158, 68, 178, 82), fill=CREAM, outline=INK)
    d.line((160, 78, 166, 72, 172, 76, 176, 70), fill=(80, 90, 150))
    for x, y in ((161, 77), (167, 72), (176, 70)):
        d.point((x, y), fill=RED)
    d.rectangle((179, 74, 182, 78), fill=CREAM, outline=INK)
    d.line((156, 70, 160, 74), fill=IRON_LIGHT, width=2)
    for x, y in ((142, 72), (192, 76), (168, 94)):
        d.rectangle((x - 3, y - 3, x + 3, y + 3), fill=WOOD, outline=INK)
    # the drive machine at the rear, behind a low rail
    if with_machine:
        img.alpha_composite(drive_machine(0), (8, 46))
    d = ImageDraw.Draw(img)
    railing_v(d, 96, 48, 104)
    railing_h(d, 12, 96, 106)
    d.line((92, 60, 120, 40), fill=COPPER, width=3)
    d.line((92, 60, 120, 40), fill=INK)
    d.line((60, 46, 60, 40), fill=COPPER, width=3)
    # ladder up to the top deck hatch, stairs down to the lower floor
    d.rectangle((124, 40, 140, 48), fill=INK)
    ladder(d, 128, 40, 60)
    stairs_down(d, (110, 108, 138, 130))
    railing_h(d, 108, 140, 106)
    # airlock door in the south wall
    d.rectangle((176, 132, 200, 138), fill=IRON, outline=INK)
    d.rectangle((184, 134, 192, 138), fill=YELLOW, outline=INK)
    # wear: oil puddle under the drive, a drip bucket, scorch by the vent, a loose plank
    stains(d, rng, (20, 108, 86, 128), 5, (OIL,), (3, 7))
    bucket(d, 104, 88)
    d.point((107, 84), fill=GLASS)
    d.ellipse((96, 124, 108, 132), fill=SCORCH)
    d.rectangle((200, 112, 212, 116), fill=WOOD_LIGHT, outline=INK)
    d.line((202, 112, 214, 108), fill=INK)
    barrel(d, 140, 112)
    crate(d, 204, 118, 12, 10)
    # wall lamps
    for x in (36, 108, 176, 214):
        d.rectangle((x, 34, x + 3, 37), fill=GLOW_HOT, outline=INK)
    d.polygon(hull, outline=INK)
    return img, {
        "walk": (14, 42, 222, 130),
        "blocked": [(10, 44, 98, 108), (150, 64, 186, 90), (224, 44, 262, 104), (108, 106, 140, 132),
                    (207, 53, 221, 67), (207, 77, 221, 91), (138, 110, 152, 126), (202, 108, 218, 130), (100, 86, 108, 96)],
        "ladder": (132, 66), "stairs": (124, 100), "airlock": (188, 124), "table": (168, 96),
        "machine": (8, 46), "drive": (100, 76), "helm": (214, 72), "posters": (124, 44),
    }


def lower_floor():
    """Smaller deck below: bunks, lockers and the store room."""
    rng = random.Random(19)
    w, h = 192, 112
    img, d = canvas(w, h, SPACE + (255,))
    for _ in range(40):
        d.point((rng.randrange(w), rng.randrange(h)), fill=rng.choice((STAR, (120, 110, 170))))
    hull = [(6, 6), (156, 6), (184, 30), (186, 80), (156, 106), (6, 106)]
    d.polygon(hull, fill=HULL_DARK, outline=INK)
    wood_wall(d, rng, (12, 10, 160, 34))
    plated_wall(d, rng, (160, 14, 180, 34))
    for x in (40, 96, 140):
        porthole(d, x, 21, 5, rng)
    pinup(d, 112, 13, rng, 3)
    planks(d, rng, (12, 34, 178, 100))
    # store room behind a partition at the stern
    d.rectangle((12, 34, 62, 100), fill=STONE_DARK)
    flagstones(d, rng, (12, 34, 62, 100))
    d.rectangle((62, 34, 66, 60), fill=WOOD_DARK, outline=INK)
    for y, (x, c) in enumerate(((16, WOOD_LIGHT), (30, (140, 100, 70)), (16, (110, 80, 60)))):
        crate(d, x, 38 + y * 13, 12, 10, c)
    barrel(d, 46, 38)
    barrel(d, 46, 54)
    d.rectangle((16, 80, 58, 96), fill=WOOD_DARK, outline=INK)
    for x in range(18, 58, 6):
        d.rectangle((x, 82, x + 4, 88), fill=rng.choice(((120, 150, 90), (190, 150, 80), CREAM, (150, 80, 70))), outline=INK)
    d.ellipse((30, 90, 40, 96), fill=(180, 160, 110), outline=INK)
    # bunks along the north wall, one with a torn blanket
    for i, x in enumerate((74, 110)):
        d.rectangle((x, 30, x + 30, 52), fill=WOOD_DARK, outline=INK)
        d.rectangle((x + 2, 32, x + 9, 50), fill=CREAM, outline=INK)
        d.rectangle((x + 9, 32, x + 28, 50), fill=CLOTH[i], outline=INK)
        d.line((x + 12, 34, x + 12, 48), fill=tuple(min(255, c + 30) for c in CLOTH[i]))
        if i == 1:
            d.rectangle((x + 18, 38, x + 24, 42), fill=CLOTH[3], outline=INK)
    # single bed in the bow with a curtain, captain's chest at its foot
    d.rectangle((150, 56, 174, 92), fill=WOOD_DARK, outline=INK)
    d.rectangle((152, 58, 172, 64), fill=CREAM, outline=INK)
    d.rectangle((152, 64, 172, 90), fill=CLOTH[2], outline=INK)
    d.line((146, 52, 146, 94), fill=(150, 60, 60), width=2)
    d.rectangle((126, 82, 144, 94), fill=WOOD, outline=INK)
    d.rectangle((126, 82, 144, 85), fill=BRASS_DARK, outline=INK)
    # lockers, one door hanging open
    for i, x in enumerate((70, 82, 94)):
        d.rectangle((x, 84, x + 10, 100), fill=IRON_LIGHT, outline=INK)
        d.line((x + 2, 86, x + 8, 86), fill=IRON)
        if i == 2:
            d.rectangle((x + 1, 85, x + 9, 99), fill=INK)
            d.line((x + 10, 84, x + 14, 88), fill=IRON_LIGHT, width=2)
    # stairs up, laundry line, dice on a crate
    stairs_down(d, (122, 38, 140, 56))
    d.line((70, 60, 110, 62), fill=CREAM)
    for x, c in ((76, CLOTH[1]), (88, CREAM), (100, CLOTH[0])):
        d.rectangle((x, 61, x + 5, 67), fill=c, outline=INK)
    crate(d, 104, 72, 10, 8)
    d.point((107, 73), fill=CREAM)
    d.point((110, 74), fill=CREAM)
    # wear: a drip bucket under a leak, stains, a lamp
    bucket(d, 86, 74)
    stains(d, rng, (70, 56, 140, 96), 5, (OIL, (90, 64, 48)), (2, 6))
    for x in (30, 92, 150):
        d.rectangle((x, 30, x + 3, 33), fill=GLOW_HOT, outline=INK)
    d.polygon(hull, outline=INK)
    return img, {
        "walk": (14, 36, 176, 98),
        "blocked": [(14, 36, 58, 66), (14, 78, 60, 98), (60, 34, 68, 60), (72, 30, 106, 50), (108, 30, 142, 50),
                    (144, 34, 178, 96), (124, 80, 146, 96), (68, 82, 106, 100), (120, 36, 142, 57), (102, 70, 113, 80), (84, 72, 94, 82)],
        "stairs": (131, 62), "bunk": (90, 58), "captain_bed": (138, 72), "store": (40, 72),
    }


def build_concept():
    exterior = ship_exterior()
    deck, _ = top_deck()
    upper, _ = upper_floor()
    lower, _ = lower_floor()
    machines = [drive_machine(p) for p in range(4)]
    s = 2
    sheet = Image.new("RGBA", (1240, 1040), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def panel(img, x, y, title, note):
        sheet.alpha_composite(img.resize((img.width * s, img.height * s), Image.NEAREST), (x, y + 18))
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)
        d.text((x, y + 22 + img.height * s), note, font=FONT, fill=CREAM)

    panel(exterior, 24, 16, "OUTSIDE - THE LASTA ON ITS PAD",
          "Old patched hull, LASTA in faded paint. Ladder to the top deck; side door and ramp to the upper floor.")
    panel(deck, 520, 16, "TOP DECK",
          "Planked roof of the hull, iron railing round the edge. Hatch down; 'SEAL' sign: closed in flight.")
    panel(upper, 24, 300, "UPPER FLOOR - CONTROL ROOM AND DRIVE",
          "Nose: console, two chairs, big taped viewports. Middle: map table, ladder up, stairs down.\n"
          "Rear: drive with four square cylinders on stone flagstones. Posters between the viewports.")
    panel(lower, 24, 650, "LOWER FLOOR - BUNKS AND STORE",
          "Two bunks, captain's bed with a curtain, lockers, laundry line. Stone store room with crates and barrels.")
    panel(lower.crop((60, 6, 130, 60)).resize((140, 108), Image.NEAREST), 440, 650, "DETAIL - BUNKS", "")
    for i, m in enumerate(machines):
        panel(m, 760 + (i % 2) * 200, 650 + (i // 2) * 150, f"DRIVE FRAME {i + 1}", "")
    panel(upper.crop((40, 8, 216, 40)), 640, 316, "DETAIL - NORTH WALL", "Viewports, pin-up posters, calendar, tally marks.")
    return sheet


def export():
    """Write the game images: the three floors, the drive frames and the Lasta on its pad."""
    ASSETS.mkdir(parents=True, exist_ok=True)
    rooms = {"ship_deck": top_deck(), "ship_upper": upper_floor(with_machine=False), "ship_lower": lower_floor()}
    for name, (img, _) in rooms.items():
        img.save(ASSETS / f"{name}.png")
    for phase in range(4):
        drive_machine(phase).save(ASSETS / f"drive_{phase}.png")
    ship_exterior().save(ASSETS / "lasta.png")
    return {name: info for name, (_, info) in rooms.items()}


def main():
    export()
    sheet = build_concept().convert("RGB")
    CONCEPT_OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONCEPT_OUT)
    print(CONCEPT_OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
