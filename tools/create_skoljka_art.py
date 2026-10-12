#!/usr/bin/python3
"""Draw the Skoljka sprites and terrain used by maps/skoljka.tmj.

Skoljka is an underwater city of Engineeria. Its surface dock sits on a stormy
sea; everything else is a hull of grey plate under the water: a lit plaza under
a glass dome, housing, the company's office and depot, the pump hall, the relay
hall, the dark lower works, and two pieces of seabed outside the airlocks.
The colours follow Rudnik: grey hulls, orange hazard bands and valves, blue
lamps and seawater.

Writes PNGs to assets/art/skoljka/.
"""

from pathlib import Path
import random

from PIL import Image, ImageDraw

from create_pomidor_art import person, SKINS, HAIRS
from create_engineeria_art import (GREY, GREY_DARK, GREY_LIGHT, ORANGE, ORANGE_DARK, BLUE, BLUE_LIGHT,
                                   BLUE_DARK, INK, SHADOW, stripes, supply_crates)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/art/skoljka"

SEA = (34, 70, 104)
SEA_2 = (30, 62, 96)
SEA_FOAM = (150, 190, 214)
DEEP = (20, 40, 66)
DEEP_2 = (24, 46, 74)
FLOOD = (46, 104, 150)
FLOOD_LIGHT = (110, 170, 214)
SAND = (120, 112, 92)
SAND_2 = (108, 100, 84)
SEABED_ROCK = (64, 70, 80)
SEABED_ROCK_DARK = (44, 48, 58)
KELP = (58, 108, 82)
KELP_DARK = (38, 78, 60)
WARM = (236, 196, 120)
WARM_DARK = (196, 150, 84)
PLAZA = (150, 140, 128)
PLAZA_2 = (140, 130, 118)
LOWER = (52, 62, 78)
LOWER_2 = (46, 56, 72)
CARPET = (128, 64, 52)
CARPET_DARK = (100, 48, 40)
# The company's colour, dark teal; nothing on Skoljka itself uses it.
TEAL = (36, 110, 108)
TEAL_DARK = (22, 76, 76)
TEAL_LIGHT = (96, 176, 168)
FRAME = (150, 158, 170)
FRAME_DARK = (92, 98, 112)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def worker(tunic, tunic_dark, skin_index, hair, badge=None, blade=False, tool=False):
    """A Skoljka person, 18 x 26. Company crews wear a teal badge and may carry a
    short blade or a wrench; nobody here carries a gun."""
    img, d = canvas(18, 26)
    img.alpha_composite(person(tunic, tunic_dark, SKINS[skin_index % 4], hair), (1, 2))
    if badge is not None:
        d.rectangle((5, 14, 7, 16), fill=badge, outline=INK)
    if blade:
        d.line([(15, 12), (15, 21)], fill=GREY_LIGHT)
        d.line([(14, 18), (16, 18)], fill=GREY_DARK)
    if tool:
        d.line([(2, 13), (2, 21)], fill=GREY_DARK)
        d.rectangle((1, 12, 3, 13), fill=GREY_LIGHT, outline=INK)
    return img


def diving_suit():
    """The player in a heavy armored diving suit, 16 x 24 like the player sprite,
    so the swap does not move their feet."""
    img, d = canvas(16, 24)
    d.ellipse((2, 20, 14, 23), fill=SHADOW)
    # boots and legs
    d.rectangle((3, 16, 7, 22), fill=GREY_DARK, outline=INK)
    d.rectangle((8, 16, 12, 22), fill=GREY_DARK, outline=INK)
    # body with an orange hazard band and the air tank behind
    d.rectangle((1, 8, 14, 17), fill=GREY, outline=INK)
    d.line([(2, 13), (13, 13)], fill=ORANGE)
    d.rectangle((12, 6, 15, 15), fill=ORANGE_DARK, outline=INK)
    # round helmet with a blue glass port
    d.ellipse((2, 0, 13, 10), fill=GREY_LIGHT, outline=INK)
    d.ellipse((4, 2, 11, 8), fill=BLUE_DARK, outline=INK)
    d.point((6, 3), fill=BLUE_LIGHT)
    d.point((7, 3), fill=BLUE_LIGHT)
    return img


def sea_creature():
    """A long armoured fish that comes in through broken intakes."""
    img, d = canvas(30, 18)
    d.ellipse((3, 13, 27, 17), fill=SHADOW)
    d.polygon([(2, 8), (8, 3), (20, 3), (26, 7), (26, 11), (20, 14), (8, 14)], fill=(70, 96, 120), outline=INK)
    d.polygon([(24, 8), (29, 3), (29, 14)], fill=(52, 76, 98), outline=INK)
    for x in (10, 14, 18):
        d.arc((x - 3, 4, x + 3, 12), 270, 90, fill=(110, 140, 164))
    d.point((6, 7), fill=ORANGE)
    d.line([(3, 10), (7, 10)], fill=(220, 220, 220))
    return img


def big_pump(running=True):
    img, d = canvas(48, 44)
    d.ellipse((2, 38, 46, 43), fill=SHADOW)
    d.rectangle((4, 18, 43, 40), fill=GREY, outline=INK)
    stripes(d, (5, 36, 42, 38), 3)
    d.ellipse((10, 2, 38, 30), fill=GREY_DARK, outline=INK)
    d.ellipse((16, 8, 32, 24), fill=GREY_LIGHT, outline=INK)
    d.ellipse((21, 13, 27, 19), fill=ORANGE if running else GREY_DARK, outline=INK)
    for x in (6, 40):
        d.rectangle((x - 2, 22, x + 2, 34), fill=BLUE_DARK, outline=INK)
    d.rectangle((20, 32, 28, 36), fill=BLUE_LIGHT if running else (90, 40, 40), outline=INK)
    return img


def valve():
    img, d = canvas(16, 20)
    d.ellipse((2, 16, 14, 19), fill=SHADOW)
    d.rectangle((6, 8, 9, 17), fill=GREY_DARK, outline=INK)
    d.ellipse((1, 0, 14, 13), outline=ORANGE, width=2)
    d.line([(7, 1), (7, 12)], fill=ORANGE)
    d.line([(2, 6), (13, 6)], fill=ORANGE)
    d.ellipse((5, 4, 9, 8), fill=ORANGE_DARK, outline=INK)
    return img


def console(lamp=BLUE_LIGHT):
    img, d = canvas(24, 26)
    d.ellipse((2, 22, 22, 25), fill=SHADOW)
    d.rectangle((2, 8, 21, 23), fill=GREY, outline=INK)
    d.polygon([(2, 8), (5, 2), (18, 2), (21, 8)], fill=GREY_DARK, outline=INK)
    d.rectangle((6, 3, 17, 7), fill=BLUE_DARK)
    for x in (7, 11, 15):
        d.point((x, 5), fill=lamp)
    for x in (6, 12, 17):
        d.rectangle((x - 1, 12, x + 1, 14), fill=ORANGE, outline=INK)
    d.line([(4, 18), (19, 18)], fill=GREY_DARK)
    return img


def relay_rack(seed, traced=False):
    rng = random.Random(seed)
    img, d = canvas(30, 42)
    d.ellipse((2, 37, 28, 41), fill=SHADOW)
    d.rectangle((2, 2, 27, 39), fill=GREY_DARK, outline=INK)
    d.rectangle((4, 4, 25, 36), fill=BLUE_DARK, outline=INK)
    for y in range(6, 35, 4):
        d.line([(6, y), (23, y)], fill=GREY_DARK)
        for x in range(7, 24, 3):
            if rng.random() < .5:
                d.point((x, y + 1), fill=BLUE_LIGHT if rng.random() < .85 else ORANGE)
    if traced:
        # a foreign cable clipped across the rack
        d.line([(4, 10), (14, 22), (25, 30)], fill=TEAL_LIGHT, width=2)
    return img


def lever():
    img, d = canvas(12, 22)
    d.ellipse((1, 18, 11, 21), fill=SHADOW)
    d.rectangle((2, 10, 9, 19), fill=GREY, outline=INK)
    stripes(d, (3, 15, 8, 17), 2)
    d.line([(5, 11), (8, 1)], fill=GREY_DARK, width=2)
    d.ellipse((6, 0, 10, 4), fill=ORANGE, outline=INK)
    return img


def air_station():
    img, d = canvas(18, 30)
    d.ellipse((2, 26, 16, 29), fill=SHADOW)
    d.rectangle((3, 4, 14, 27), fill=GREY_LIGHT, outline=INK)
    d.rectangle((5, 7, 12, 14), fill=BLUE, outline=INK)
    d.line([(6, 9), (9, 9)], fill=BLUE_LIGHT)
    d.rectangle((6, 18, 11, 22), fill=ORANGE, outline=INK)
    d.line([(14, 16), (17, 20), (16, 25)], fill=GREY_DARK, width=2)
    d.rectangle((2, 1, 15, 4), fill=GREY_DARK, outline=INK)
    return img


def airlock():
    img, d = canvas(36, 40)
    d.ellipse((2, 34, 34, 39), fill=SHADOW)
    d.rectangle((2, 4, 33, 36), fill=GREY_DARK, outline=INK)
    d.ellipse((6, 6, 29, 30), fill=GREY, outline=INK)
    d.ellipse((10, 10, 25, 26), fill=BLUE_DARK, outline=INK)
    d.line([(17, 10), (17, 26)], fill=ORANGE, width=2)
    d.line([(10, 18), (25, 18)], fill=ORANGE, width=2)
    stripes(d, (3, 31, 32, 34), 4)
    return img


def suit_rack():
    img, d = canvas(20, 30)
    d.ellipse((2, 26, 18, 29), fill=SHADOW)
    d.rectangle((1, 2, 18, 27), fill=GREY_DARK, outline=INK)
    suit = diving_suit()
    img.alpha_composite(suit, (2, 3))
    return img


def intake(repaired=False):
    img, d = canvas(44, 34)
    d.ellipse((2, 28, 42, 33), fill=SHADOW)
    d.rectangle((0, 8, 30, 26), fill=GREY, outline=INK)
    d.ellipse((24, 4, 43, 30), fill=GREY_DARK, outline=INK)
    d.ellipse((28, 8, 39, 26), fill=DEEP, outline=INK)
    for y in (12, 17, 22):
        if repaired:
            d.line([(28, y), (39, y)], fill=ORANGE)
        else:
            d.line([(28, y), (33, y - 2)], fill=ORANGE)
    d.line([(4, 14), (26, 14)], fill=GREY_LIGHT)
    if not repaired:
        d.polygon([(10, 8), (14, 14), (18, 8)], fill=DEEP, outline=INK)
    return img


def kelp(seed):
    rng = random.Random(seed)
    img, d = canvas(14, 24)
    for x in (3, 7, 11):
        top = rng.randint(1, 8)
        d.line([(x, 23), (x + rng.randint(-2, 2), top)], fill=KELP, width=2)
        d.point((x - 1, top + 4), fill=KELP_DARK)
    return img


def seabed_rock(seed):
    rng = random.Random(seed)
    img, d = canvas(28, 18)
    d.ellipse((2, 13, 26, 17), fill=SHADOW)
    d.polygon([(2, 15), (6, 6), (12, 2), (20, 4), (26, 15)], fill=SEABED_ROCK, outline=INK)
    for _ in range(5):
        d.point((rng.randint(7, 20), rng.randint(5, 13)), fill=SEABED_ROCK_DARK)
    return img


def frame_window():
    """A thick window in the sealed dock's wall. Behind it, in the dark, stands
    part of something very large shaped like a person: a shoulder, an arm and
    the side of a head, all plated."""
    img, d = canvas(96, 72)
    d.ellipse((4, 66, 92, 71), fill=SHADOW)
    d.rectangle((0, 4, 95, 68), fill=GREY_DARK, outline=INK)
    stripes(d, (1, 62, 94, 66), 5)
    d.rectangle((8, 10, 87, 58), fill=DEEP, outline=INK)
    # the frame behind the glass
    d.polygon([(30, 58), (34, 30), (46, 22), (64, 22), (72, 32), (70, 58)], fill=FRAME_DARK, outline=INK)
    d.ellipse((52, 10, 74, 30), fill=FRAME, outline=INK)
    d.rectangle((58, 18, 68, 21), fill=ORANGE_DARK)
    d.polygon([(20, 58), (22, 36), (34, 30), (34, 58)], fill=FRAME, outline=INK)
    for y in range(34, 58, 6):
        d.line([(38, y), (68, y)], fill=FRAME)
    # glare on the glass
    d.line([(14, 14), (24, 14)], fill=BLUE_LIGHT)
    d.line([(14, 16), (19, 16)], fill=BLUE_LIGHT)
    return img


def sealed_dock_door():
    img, d = canvas(64, 48)
    d.ellipse((2, 42, 62, 47), fill=SHADOW)
    d.rectangle((0, 2, 63, 44), fill=GREY_DARK, outline=INK)
    d.rectangle((6, 8, 57, 44), fill=GREY, outline=INK)
    d.line([(32, 8), (32, 44)], fill=INK)
    stripes(d, (7, 9, 56, 13), 5)
    d.rectangle((26, 24, 38, 30), fill=(150, 40, 40), outline=INK)
    return img


def crane():
    img, d = canvas(44, 70)
    d.ellipse((6, 64, 38, 69), fill=SHADOW)
    d.rectangle((16, 14, 23, 66), fill=ORANGE, outline=INK)
    for y in range(18, 64, 8):
        d.line([(17, y), (22, y + 6)], fill=ORANGE_DARK)
    d.rectangle((2, 8, 43, 14), fill=ORANGE, outline=INK)
    d.line([(38, 14), (38, 40)], fill=GREY_DARK)
    d.rectangle((35, 40, 41, 44), fill=GREY_DARK, outline=INK)
    d.rectangle((12, 0, 26, 8), fill=GREY, outline=INK)
    d.rectangle((14, 2, 24, 5), fill=BLUE_LIGHT)
    return img


def building(w, h, wall, roof, door_color=GREY_DARK, windows=3, sign=None):
    img, d = canvas(w, h)
    d.ellipse((2, h - 6, w - 2, h - 1), fill=SHADOW)
    d.rectangle((2, 10, w - 3, h - 4), fill=wall, outline=INK)
    d.rectangle((0, 4, w - 1, 11), fill=roof, outline=INK)
    stripes(d, (1, 12, w - 2, 14), 3)
    step = (w - 12) // max(1, windows)
    for i in range(windows):
        wx = 6 + i * step
        d.rectangle((wx, 18, wx + 9, 27), fill=BLUE if wall != WARM else WARM_DARK, outline=INK)
        d.line([(wx + 2, 20), (wx + 5, 20)], fill=BLUE_LIGHT)
    d.rectangle((w // 2 - 6, h - 20, w // 2 + 6, h - 4), fill=door_color, outline=INK)
    if sign is not None:
        d.rectangle((w // 2 - 12, 0, w // 2 + 12, 5), fill=sign, outline=INK)
    return img


def lift_head():
    img, d = canvas(44, 48)
    d.ellipse((2, 42, 42, 47), fill=SHADOW)
    d.rectangle((4, 12, 39, 44), fill=GREY, outline=INK)
    d.rectangle((10, 18, 33, 44), fill=BLUE_DARK, outline=INK)
    d.line([(21, 18), (21, 44)], fill=GREY_DARK)
    d.rectangle((0, 6, 43, 13), fill=ORANGE, outline=INK)
    d.rectangle((16, 0, 27, 6), fill=GREY_DARK, outline=INK)
    d.point((21, 3), fill=BLUE_LIGHT)
    stripes(d, (5, 40, 38, 43), 3)
    return img


def market_stall(color, seed):
    rng = random.Random(seed)
    img, d = canvas(40, 34)
    d.ellipse((2, 28, 38, 33), fill=SHADOW)
    d.rectangle((3, 16, 36, 30), fill=GREY, outline=INK)
    d.polygon([(0, 14), (4, 4), (36, 4), (39, 14)], fill=color, outline=INK)
    for x in range(6, 36, 8):
        d.line([(x, 5), (x - 2, 13)], fill=GREY_LIGHT)
    for _ in range(6):
        x = rng.randint(6, 32)
        d.ellipse((x - 2, 15, x + 2, 19), fill=rng.choice([ORANGE, BLUE_LIGHT, WARM, (180, 90, 90)]), outline=INK)
    return img


def bench():
    img, d = canvas(32, 14)
    d.ellipse((2, 10, 30, 13), fill=SHADOW)
    d.rectangle((1, 3, 30, 7), fill=GREY_LIGHT, outline=INK)
    for x in (4, 26):
        d.rectangle((x, 7, x + 2, 11), fill=GREY_DARK)
    return img


def table(w=48, cloth=CARPET):
    img, d = canvas(w, 24)
    d.ellipse((2, 19, w - 2, 23), fill=SHADOW)
    d.rectangle((1, 4, w - 2, 16), fill=GREY_DARK, outline=INK)
    d.rectangle((3, 6, w - 4, 12), fill=cloth)
    for x in (3, w - 6):
        d.rectangle((x, 16, x + 2, 21), fill=GREY_DARK)
    return img


def depot_shelf():
    img, d = canvas(40, 32)
    d.ellipse((2, 28, 38, 31), fill=SHADOW)
    d.rectangle((1, 2, 38, 28), fill=GREY_DARK, outline=INK)
    for y in (8, 16, 24):
        d.line([(2, y), (37, y)], fill=INK)
    for x, y in ((4, 3), (16, 3), (26, 11), (6, 11), (12, 19), (28, 19)):
        d.rectangle((x, y, x + 8, y + 4), fill=TEAL, outline=INK)
    return img


def company_crates():
    img = supply_crates()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in (GREY, GREY_LIGHT):
                px[x, y] = (TEAL if (r, g, b) == GREY else TEAL_LIGHT) + (a,)
    return img


def company_sign():
    img, d = canvas(40, 26)
    d.rectangle((18, 12, 21, 25), fill=GREY_DARK)
    d.rectangle((0, 0, 39, 13), fill=TEAL, outline=INK)
    d.rectangle((3, 3, 36, 10), outline=TEAL_LIGHT)
    d.ellipse((16, 4, 23, 9), fill=TEAL_LIGHT)
    return img


def dome_lamp():
    img, d = canvas(10, 32)
    d.ellipse((1, 28, 9, 31), fill=SHADOW)
    d.rectangle((4, 6, 5, 29), fill=GREY_DARK)
    d.ellipse((0, 0, 9, 8), fill=WARM, outline=INK)
    d.point((3, 3), fill=(255, 240, 200))
    return img


def blue_lamp():
    img, d = canvas(10, 32)
    d.ellipse((1, 28, 9, 31), fill=SHADOW)
    d.rectangle((4, 6, 5, 29), fill=GREY_DARK)
    d.rectangle((1, 1, 8, 6), fill=GREY, outline=INK)
    d.rectangle((2, 3, 7, 5), fill=BLUE_LIGHT)
    return img


def pipe_run():
    img, d = canvas(48, 16)
    d.rectangle((0, 4, 47, 11), fill=GREY, outline=INK)
    d.line([(0, 6), (47, 6)], fill=GREY_LIGHT)
    for x in (10, 34):
        d.rectangle((x, 2, x + 4, 13), fill=ORANGE_DARK, outline=INK)
    return img


def bunk():
    img, d = canvas(32, 20)
    d.ellipse((2, 16, 30, 19), fill=SHADOW)
    d.rectangle((1, 3, 30, 15), fill=GREY_DARK, outline=INK)
    d.rectangle((3, 5, 28, 12), fill=(180, 170, 150))
    d.rectangle((3, 5, 9, 12), fill=(220, 214, 200))
    return img


SHELL = (232, 216, 190)
SHELL_PINK = (214, 166, 150)
SHELL_DARK = (170, 130, 116)
CORAL = (222, 112, 92)
CORAL_DARK = (170, 76, 70)
CORAL_PINK = (206, 120, 150)
WOOD = (122, 92, 64)
WOOD_DARK = (88, 64, 46)
GLOW = (250, 220, 120)


def shell_house():
    """A home under a scallop shell: the ribbed fan is the roof."""
    img, d = canvas(64, 58)
    d.ellipse((4, 52, 60, 57), fill=SHADOW)
    d.rectangle((10, 30, 53, 54), fill=SHELL, outline=INK)
    d.pieslice((0, 0, 63, 60), 180, 360, fill=SHELL_PINK, outline=INK)
    for angle in range(195, 360, 22):
        d.pieslice((0, 0, 63, 60), angle, angle + 9, fill=SHELL)
    d.pieslice((0, 0, 63, 60), 180, 360, outline=INK)
    d.rectangle((24, 22, 39, 30), fill=SHELL_DARK, outline=INK)
    d.ellipse((25, 36, 38, 54), fill=WOOD_DARK, outline=INK)
    d.rectangle((25, 45, 38, 54), fill=WOOD_DARK)
    d.line([(25, 54), (38, 54)], fill=INK)
    for wx in (14, 43):
        d.ellipse((wx, 37, wx + 7, 44), fill=BLUE, outline=INK)
        d.point((wx + 2, 39), fill=BLUE_LIGHT)
    return img


def bubble_house():
    """A glass sphere on three legs with a hatch and a ladder; someone lives in it."""
    img, d = canvas(56, 62)
    d.ellipse((6, 56, 50, 61), fill=SHADOW)
    for x in (12, 28, 44):
        d.line([(x, 40), (x, 58)], fill=GREY_DARK, width=3)
    d.ellipse((4, 2, 52, 48), fill=(60, 110, 140), outline=INK)
    d.ellipse((10, 8, 46, 42), outline=(120, 170, 200))
    d.chord((4, 2, 52, 48), 20, 160, fill=GREY, outline=INK)
    d.rectangle((16, 22, 26, 34), fill=GLOW, outline=INK)
    d.rectangle((30, 18, 40, 30), fill=(180, 150, 120), outline=INK)
    d.arc((12, 6, 30, 22), 200, 280, fill=(220, 240, 250), width=2)
    for y in range(44, 60, 4):
        d.line([(34, y), (40, y)], fill=GREY_LIGHT)
    d.line([(34, 42), (34, 60)], fill=GREY_LIGHT)
    d.line([(40, 42), (40, 60)], fill=GREY_LIGHT)
    return img


def boat_house():
    """An old fishing boat turned upside down and lived in: the keel is the ridge."""
    img, d = canvas(78, 52)
    d.ellipse((4, 46, 74, 51), fill=SHADOW)
    d.polygon([(2, 46), (8, 14), (39, 4), (70, 14), (76, 46)], fill=WOOD, outline=INK)
    for y in range(14, 46, 6):
        d.line([(6, y + 2), (72, y + 2)], fill=WOOD_DARK)
    d.line([(39, 4), (39, 46)], fill=WOOD_DARK, width=3)
    d.rectangle((30, 28, 47, 47), fill=GREY_DARK, outline=INK)
    d.ellipse((10, 24, 19, 33), fill=BLUE, outline=INK)
    d.ellipse((58, 24, 67, 33), fill=GLOW, outline=INK)
    d.rectangle((54, 0, 59, 12), fill=GREY, outline=INK)
    d.rectangle((52, 0, 61, 3), fill=ORANGE_DARK, outline=INK)
    return img


def capsule_stack():
    """Three old pressure tanks stacked and welded into a narrow tall home."""
    img, d = canvas(50, 68)
    d.ellipse((4, 62, 46, 67), fill=SHADOW)
    for i, (y, color) in enumerate(((44, GREY), (24, (130, 120, 104)), (4, GREY_LIGHT))):
        x0 = 2 + (i % 2) * 4
        d.rounded_rectangle((x0, y, x0 + 42, y + 20), 9, fill=color, outline=INK)
        d.line([(x0 + 4, y + 16), (x0 + 38, y + 16)], fill=ORANGE if i != 1 else ORANGE_DARK)
        for px in (x0 + 8, x0 + 26):
            d.ellipse((px, y + 4, px + 9, y + 13), fill=GLOW if (i + px) % 3 == 0 else BLUE, outline=INK)
    d.rectangle((20, 52, 29, 64), fill=GREY_DARK, outline=INK)
    for y in range(8, 60, 5):
        d.line([(45, y), (49, y)], fill=GREY_DARK)
    d.line([(45, 6), (45, 62)], fill=GREY_DARK)
    d.line([(49, 6), (49, 62)], fill=GREY_DARK)
    return img


def coral_house():
    """A house grown out of coral, its windows the holes the coral left."""
    img, d = canvas(60, 58)
    d.ellipse((4, 52, 56, 57), fill=SHADOW)
    for box, color in (((2, 18, 30, 54), CORAL), ((22, 4, 56, 54), CORAL_PINK), ((10, 0, 34, 30), CORAL)):
        d.ellipse(box, fill=color, outline=INK)
    for x, y in ((12, 10), (40, 16), (30, 32), (8, 30), (46, 34)):
        d.ellipse((x, y, x + 6, y + 6), fill=CORAL_DARK)
    d.ellipse((14, 14, 22, 22), fill=GLOW, outline=INK)
    d.ellipse((36, 22, 46, 32), fill=BLUE, outline=INK)
    d.rectangle((24, 38, 36, 54), fill=WOOD_DARK, outline=INK)
    d.pieslice((24, 32, 36, 44), 180, 360, fill=WOOD_DARK, outline=INK)
    return img


def snail_house():
    """A spiral shell lying on its side with a door in its mouth."""
    img, d = canvas(58, 52)
    d.ellipse((4, 46, 54, 51), fill=SHADOW)
    d.ellipse((8, 2, 56, 48), fill=SHELL, outline=INK)
    for r, color in ((19, SHELL_PINK), (13, SHELL), (8, SHELL_PINK), (4, SHELL_DARK)):
        d.ellipse((34 - r, 24 - r, 34 + r, 24 + r), fill=color, outline=SHELL_DARK)
    d.polygon([(0, 48), (4, 26), (16, 22), (18, 48)], fill=SHELL_DARK, outline=INK)
    d.rectangle((5, 32, 14, 48), fill=WOOD_DARK, outline=INK)
    d.point((12, 40), fill=GLOW)
    return img


def fish_lamp():
    """A street lamp: a glass jar where a small glowing fish swims."""
    img, d = canvas(12, 32)
    d.ellipse((1, 28, 11, 31), fill=SHADOW)
    d.rectangle((5, 12, 6, 29), fill=GREY_DARK)
    d.ellipse((0, 0, 11, 13), fill=(70, 130, 150), outline=INK)
    d.ellipse((3, 5, 8, 8), fill=GLOW)
    d.polygon([(8, 6), (10, 4), (10, 9)], fill=GLOW)
    d.point((3, 2), fill=(220, 240, 250))
    return img


def laundry_line():
    img, d = canvas(50, 28)
    for x in (2, 47):
        d.line([(x, 2), (x, 27)], fill=GREY_DARK, width=2)
    d.line([(2, 4), (47, 6)], fill=GREY_LIGHT)
    for x, color in ((7, ORANGE), (15, BLUE_LIGHT), (24, SHELL), (32, CORAL), (40, BLUE)):
        d.rectangle((x, 5, x + 6, 14 + x % 3), fill=color, outline=INK)
    return img


def planter():
    img, d = canvas(18, 26)
    d.ellipse((1, 22, 17, 25), fill=SHADOW)
    d.rectangle((3, 14, 14, 23), fill=GREY, outline=INK)
    d.line([(3, 16), (14, 16)], fill=ORANGE)
    for x, top in ((5, 2), (8, 0), (11, 4), (13, 7)):
        d.line([(x, 14), (x + (1 if x % 2 else -1), top)], fill=KELP, width=2)
    d.point((7, 6), fill=KELP_DARK)
    return img


def fish_school(seed):
    rng = random.Random(seed)
    img, d = canvas(38, 20)
    for _ in range(7):
        x, y = rng.randint(2, 30), rng.randint(2, 15)
        body = rng.choice([(176, 196, 206), (150, 176, 196), (210, 190, 120)])
        d.ellipse((x, y, x + 6, y + 3), fill=body)
        d.polygon([(x + 6, y + 1), (x + 8, y - 1), (x + 8, y + 4)], fill=body)
        d.point((x + 1, y + 1), fill=INK)
    return img


def bubbles():
    img, d = canvas(12, 30)
    for x, y, r in ((5, 25, 3), (7, 17, 2), (4, 11, 2), (7, 5, 1), (5, 1, 1)):
        d.ellipse((x - r, y - r, x + r, y + r), outline=SEA_FOAM)
    return img


def coral(seed):
    rng = random.Random(seed)
    img, d = canvas(24, 20)
    color = [CORAL, CORAL_PINK, (230, 170, 80)][seed % 3]
    for _ in range(5):
        x = rng.randint(4, 19)
        top = rng.randint(2, 10)
        d.line([(12, 19), (x, top)], fill=color, width=2)
        d.ellipse((x - 2, top - 2, x + 2, top + 2), fill=color)
    d.ellipse((7, 16, 17, 19), fill=CORAL_DARK)
    return img


def buoy():
    img, d = canvas(14, 22)
    d.ellipse((0, 16, 13, 21), outline=SEA_FOAM)
    d.polygon([(3, 18), (2, 8), (7, 2), (12, 8), (11, 18)], fill=ORANGE, outline=INK)
    d.line([(3, 12), (11, 12)], fill=SHELL)
    d.ellipse((5, 0, 9, 4), fill=GLOW, outline=INK)
    return img


def anchor():
    img, d = canvas(26, 30)
    d.ellipse((2, 25, 24, 29), fill=SHADOW)
    d.ellipse((9, 0, 16, 6), outline=GREY_DARK, width=2)
    d.line([(12, 6), (12, 26)], fill=GREY_DARK, width=3)
    d.line([(6, 10), (18, 10)], fill=GREY_DARK, width=2)
    d.arc((2, 12, 23, 28), 20, 160, fill=GREY_DARK, width=3)
    return img


def barrels():
    img, d = canvas(28, 26)
    d.ellipse((1, 21, 27, 25), fill=SHADOW)
    for x, color in ((1, ORANGE_DARK), (14, BLUE_DARK)):
        d.rounded_rectangle((x, 6, x + 12, 23), 3, fill=color, outline=INK)
        d.line([(x, 11), (x + 12, 11)], fill=INK)
        d.line([(x, 18), (x + 12, 18)], fill=INK)
    d.rounded_rectangle((7, 0, 20, 10), 3, fill=GREY, outline=INK)
    return img


def net_rack():
    img, d = canvas(42, 32)
    d.ellipse((2, 27, 40, 31), fill=SHADOW)
    for x in (2, 39):
        d.line([(x, 2), (x, 29)], fill=WOOD_DARK, width=2)
    d.line([(2, 3), (39, 3)], fill=WOOD_DARK, width=2)
    for x in range(4, 38, 4):
        d.line([(x, 4), (x + 2, 24)], fill=(160, 150, 120))
    for y in range(8, 24, 4):
        d.line([(4, y), (37, y + 1)], fill=(160, 150, 120))
    for x in (8, 20, 32):
        d.ellipse((x - 2, 22, x + 2, 26), fill=ORANGE, outline=INK)
    return img


def shell_statue():
    """The plaza's statue: a great scallop standing on its hinge."""
    img, d = canvas(44, 58)
    d.ellipse((4, 52, 40, 57), fill=SHADOW)
    d.rectangle((10, 40, 33, 54), fill=GREY, outline=INK)
    d.line([(10, 44), (33, 44)], fill=ORANGE)
    d.pieslice((2, 2, 41, 70), 200, 340, fill=SHELL, outline=INK)
    for angle in range(208, 336, 16):
        d.pieslice((2, 2, 41, 70), angle, angle + 6, fill=SHELL_PINK)
    d.pieslice((2, 2, 41, 70), 200, 340, outline=INK)
    d.ellipse((17, 30, 26, 40), fill=SHELL_DARK, outline=INK)
    return img


def aquarium():
    img, d = canvas(40, 30)
    d.ellipse((2, 25, 38, 29), fill=SHADOW)
    d.rectangle((1, 20, 38, 26), fill=WOOD_DARK, outline=INK)
    d.rectangle((2, 2, 37, 20), fill=(70, 140, 170), outline=INK)
    d.line([(4, 4), (12, 4)], fill=(200, 230, 240))
    for x, y, c in ((10, 10, ORANGE), (24, 14, GLOW), (28, 7, CORAL_PINK)):
        d.ellipse((x, y, x + 5, y + 3), fill=c)
    d.line([(32, 19), (31, 9)], fill=KELP, width=2)
    return img


def canteen_table():
    img, d = canvas(38, 24)
    d.ellipse((2, 19, 36, 23), fill=SHADOW)
    for x in (2, 32):
        d.ellipse((x, 13, x + 5, 18), fill=WOOD_DARK, outline=INK)
    d.rectangle((7, 6, 30, 16), fill=WOOD, outline=INK)
    for x in (11, 22):
        d.ellipse((x, 8, x + 5, 12), fill=SHELL, outline=INK)
        d.point((x + 2, 10), fill=ORANGE)
    return img


def workbench():
    img, d = canvas(42, 28)
    d.ellipse((2, 23, 40, 27), fill=SHADOW)
    d.rectangle((2, 8, 39, 14), fill=GREY, outline=INK)
    for x in (4, 35):
        d.rectangle((x, 14, x + 2, 25), fill=GREY_DARK)
    d.rectangle((6, 2, 14, 8), fill=ORANGE_DARK, outline=INK)
    d.line([(20, 5), (30, 7)], fill=GREY_LIGHT, width=2)
    d.ellipse((31, 3, 37, 8), fill=GREY_DARK, outline=INK)
    return img


def gauge_panel():
    img, d = canvas(34, 32)
    d.ellipse((2, 27, 32, 31), fill=SHADOW)
    d.rectangle((1, 1, 32, 28), fill=GREY_DARK, outline=INK)
    for x, y in ((4, 4), (18, 4), (4, 15), (18, 15)):
        d.ellipse((x, y, x + 10, y + 10), fill=SHELL, outline=INK)
        d.line([(x + 5, y + 5), (x + 8, y + 2 + (x + y) % 6)], fill=(150, 40, 40))
    return img


def lockers():
    img, d = canvas(40, 34)
    d.ellipse((1, 29, 39, 33), fill=SHADOW)
    for i in range(4):
        x = 1 + i * 9
        d.rectangle((x, 2, x + 9, 30), fill=GREY if i % 2 else GREY_LIGHT, outline=INK)
        d.line([(x + 2, 6), (x + 7, 6)], fill=INK)
        d.point((x + 7, 16), fill=ORANGE)
    return img


def generator():
    img, d = canvas(38, 32)
    d.ellipse((2, 27, 36, 31), fill=SHADOW)
    d.rounded_rectangle((2, 6, 35, 28), 5, fill=GREY, outline=INK)
    for x in range(6, 32, 4):
        d.line([(x, 9), (x, 20)], fill=GREY_DARK)
    stripes(d, (3, 23, 34, 26), 3)
    d.rectangle((26, 0, 31, 6), fill=GREY_DARK, outline=INK)
    d.point((8, 24), fill=BLUE_LIGHT)
    return img


def jellyfish(seed):
    img, d = canvas(16, 22)
    color = [(190, 150, 210), (150, 200, 220)][seed % 2]
    d.pieslice((1, 0, 14, 14), 180, 360, fill=color, outline=(230, 220, 240))
    for x in (3, 6, 9, 12):
        d.line([(x, 7), (x + (seed % 3) - 1, 21)], fill=color)
    return img


def fish_bones():
    """The skeleton of a very large fish half sunk in the sand."""
    img, d = canvas(84, 32)
    bone = (214, 206, 186)
    d.ellipse((4, 26, 80, 31), fill=SHADOW)
    d.line([(10, 20), (70, 18)], fill=bone, width=3)
    for x in range(18, 64, 6):
        d.arc((x - 6, 4, x + 6, 34), 200, 340, fill=bone, width=2)
    d.ellipse((66, 10, 82, 26), outline=bone, width=3)
    d.ellipse((72, 14, 76, 18), fill=INK)
    d.polygon([(2, 10), (12, 19), (2, 28)], outline=bone)
    return img


def wreck():
    """An old two-seat submarine lying on its side in the sand, long abandoned."""
    img, d = canvas(96, 52)
    d.ellipse((4, 44, 92, 51), fill=SHADOW)
    d.rounded_rectangle((6, 14, 86, 46), 15, fill=(110, 96, 80), outline=INK)
    for x in range(14, 80, 9):
        d.point((x, 20), fill=(80, 64, 52))
        d.point((x + 3, 38), fill=(140, 90, 60))
    d.ellipse((60, 18, 76, 34), fill=(40, 70, 90), outline=INK)
    d.line([(62, 22), (72, 31)], fill=SEA_FOAM)
    d.rectangle((30, 4, 46, 16), fill=(100, 88, 74), outline=INK)
    d.polygon([(84, 24), (95, 14), (95, 42), (84, 36)], fill=(96, 82, 70), outline=INK)
    for x in (20, 44):
        d.line([(x, 46), (x + 6, 34)], fill=KELP, width=2)
    return img


PEOPLE = {
    # Skoljka's own people wear grey and orange, the port officer blue.
    "port_officer": ((70, 100, 160), BLUE_DARK, 2, GREY_DARK, None),
    "pumpmaster": (ORANGE, ORANGE_DARK, 1, HAIRS[3], None),
    "technician": (BLUE_DARK, (28, 48, 92), 0, HAIRS[1], None),
    "councillor": ((210, 206, 196), (170, 166, 156), 3, HAIRS[2], None),
    "resident_0": (GREY_LIGHT, GREY, 0, HAIRS[0], None),
    "resident_1": ((150, 120, 96), (110, 86, 70), 2, HAIRS[1], None),
    "resident_2": ((120, 140, 110), (90, 108, 84), 3, HAIRS[3], None),
    "worker_0": (ORANGE, GREY_DARK, 0, BLUE),
    "worker_1": (ORANGE, GREY_DARK, 2, BLUE),
    "worker_2": (ORANGE, GREY_DARK, 3, BLUE),
    "worker_3": (ORANGE, GREY_DARK, 1, BLUE),
    "engineer": (GREY, GREY_DARK, 1, ORANGE, None),
    "seeker": ((160, 110, 120), (120, 80, 90), 0, HAIRS[2], None),
    # The company: dark teal overalls with a light badge.
    "company_clerk": (TEAL, TEAL_DARK, 3, HAIRS[0], TEAL_LIGHT),
    "company_rep": ((48, 52, 60), (32, 34, 40), 1, HAIRS[3], TEAL_LIGHT),
    "crew_lead": (TEAL, TEAL_DARK, 2, GREY_DARK, ORANGE),
}


def person_sprite(key):
    values = PEOPLE[key]
    tunic, dark, skin, hair = values[:4]
    badge = values[4] if len(values) > 4 else None
    return worker(tunic, dark, skin, hair, badge, tool=key.startswith("worker") or key in ("pumpmaster", "engineer"))


TERRAIN = ["hull", "hull_2", "plaza", "plaza_2", "grate", "hull_wall", "glass", "hazard",
           "sea", "sea_2", "flood", "flood_2", "door_h", "door_v", "deck", "deck_2",
           "pad", "sand", "sand_2", "seabed_rock", "lower", "lower_2", "carpet", "carpet_edge",
           "deep", "deep_2", "office", "cell_door",
           "tube_h", "tube_v", "mosaic_0", "mosaic_1", "mosaic_2", "sump", "company_wall", "silt",
           "silt_2", "porthole", "pipe_wall", "garden", "puddle", "shaft", "planks", "checker",
           "rug", "algae", "sand_ripple", "coral_floor"]


def terrain():
    img, d = canvas(16 * 8, 16 * 6)
    rng = random.Random(53)

    def at(i):
        return (i % 8) * 16, (i // 8) * 16

    def speckle(x, y, colors, n):
        for _ in range(n):
            d.point((x + rng.randrange(16), y + rng.randrange(16)), fill=rng.choice(colors))

    for i, name in enumerate(TERRAIN):
        x, y = at(i)
        box = (x, y, x + 15, y + 15)
        if name in ("hull", "hull_2"):
            d.rectangle(box, fill=GREY if name == "hull" else (120, 124, 132))
            d.rectangle(box, outline=GREY_DARK)
            for p in ((2, 2), (13, 2), (2, 13), (13, 13)):
                d.point((x + p[0], y + p[1]), fill=GREY_LIGHT)
        elif name in ("plaza", "plaza_2"):
            d.rectangle(box, fill=PLAZA if name == "plaza" else PLAZA_2)
            d.line([(x, y + 7), (x + 15, y + 7)], fill=(120, 112, 102))
            d.line([(x + (5 if name == "plaza" else 11), y), (x + (5 if name == "plaza" else 11), y + 6)], fill=(120, 112, 102))
            d.line([(x + 9, y + 8), (x + 9, y + 15)], fill=(120, 112, 102))
            speckle(x, y, [(168, 158, 144)], 4)
        elif name == "grate":
            d.rectangle(box, fill=GREY_DARK)
            for gx in range(1, 16, 3):
                d.line([(x + gx, y), (x + gx, y + 15)], fill=INK)
            d.line([(x, y + 7), (x + 15, y + 7)], fill=GREY)
        elif name == "hull_wall":
            d.rectangle(box, fill=GREY_DARK)
            d.rectangle((x, y, x + 15, y + 3), fill=GREY_LIGHT)
            d.line([(x, y + 4), (x + 15, y + 4)], fill=INK)
            for p in ((3, 8), (12, 8), (3, 13), (12, 13)):
                d.point((x + p[0], y + p[1]), fill=GREY)
            d.rectangle((x, y + 10, x + 15, y + 11), fill=ORANGE)
        elif name == "glass":
            # The dome's glass, with the sea beyond it.
            d.rectangle(box, fill=SEA)
            d.rectangle(box, outline=GREY_LIGHT)
            d.line([(x + 3, y + 3), (x + 7, y + 3)], fill=SEA_FOAM)
            d.line([(x + 3, y + 5), (x + 5, y + 5)], fill=SEA_FOAM)
            d.line([(x + 8, y), (x + 8, y + 15)], fill=GREY)
        elif name == "hazard":
            # Drawn on its own tile and pasted, so the stripes that start left of
            # the tile do not paint over the glass tile beside it in the atlas.
            tile, td = canvas(16, 16)
            td.rectangle((0, 0, 15, 15), fill=GREY_DARK)
            for k in range(-16, 16, 6):
                td.line([(k, 15), (k + 15, 0)], fill=ORANGE, width=2)
            img.paste(tile, (x, y))
        elif name in ("sea", "sea_2"):
            d.rectangle(box, fill=SEA if name == "sea" else SEA_2)
            for wy in (4, 11):
                wx = rng.randrange(2, 8)
                d.line([(x + wx, y + wy), (x + wx + 5, y + wy)], fill=SEA_FOAM)
        elif name in ("flood", "flood_2"):
            d.rectangle(box, fill=FLOOD)
            wx = 3 if name == "flood" else 8
            d.line([(x + wx, y + 5), (x + wx + 5, y + 5)], fill=FLOOD_LIGHT)
            d.line([(x + 14 - wx, y + 11), (x + 18 - wx, y + 11)], fill=FLOOD_LIGHT)
        elif name in ("door_h", "door_v"):
            d.rectangle(box, fill=GREY)
            d.rectangle(box, outline=INK)
            if name == "door_h":
                d.rectangle((x, y + 5, x + 15, y + 10), fill=ORANGE)
                for k in range(0, 16, 4):
                    d.line([(x + k, y + 10), (x + k + 3, y + 5)], fill=INK)
            else:
                d.rectangle((x + 5, y, x + 10, y + 15), fill=ORANGE)
                for k in range(0, 16, 4):
                    d.line([(x + 5, y + k + 3), (x + 10, y + k)], fill=INK)
        elif name in ("deck", "deck_2"):
            d.rectangle(box, fill=(104, 100, 96) if name == "deck" else (96, 92, 88))
            for k in (3, 11):
                d.line([(x, y + k), (x + 15, y + k)], fill=(80, 76, 74))
            speckle(x, y, [(130, 126, 120), (70, 90, 110)], 5)
        elif name == "pad":
            d.rectangle(box, fill=(104, 108, 116))
            d.rectangle(box, outline=GREY_DARK)
            d.line([(x + 2, y + 2), (x + 5, y + 2)], fill=BLUE_LIGHT)
            d.line([(x + 10, y + 13), (x + 13, y + 13)], fill=ORANGE)
        elif name in ("sand", "sand_2"):
            d.rectangle(box, fill=SAND if name == "sand" else SAND_2)
            speckle(x, y, [SAND_2 if name == "sand" else SAND, (90, 96, 92), (140, 130, 110)], 10)
        elif name == "seabed_rock":
            d.rectangle(box, fill=SEABED_ROCK_DARK)
            for _ in range(4):
                bx, by, r = x + rng.randrange(16), y + rng.randrange(16), rng.randint(3, 6)
                d.ellipse((bx - r, by - r, bx + r, by + r), fill=SEABED_ROCK, outline=SEABED_ROCK_DARK)
        elif name in ("lower", "lower_2"):
            d.rectangle(box, fill=LOWER if name == "lower" else LOWER_2)
            d.rectangle(box, outline=(40, 48, 62))
            d.point((x + 3, y + 3), fill=(80, 96, 118))
            d.point((x + 12, y + 12), fill=(80, 96, 118))
        elif name == "carpet":
            d.rectangle(box, fill=CARPET)
            speckle(x, y, [CARPET_DARK], 6)
        elif name == "carpet_edge":
            d.rectangle(box, fill=CARPET)
            d.rectangle((x, y, x + 15, y + 2), fill=WARM_DARK)
        elif name in ("deep", "deep_2"):
            d.rectangle(box, fill=DEEP if name == "deep" else DEEP_2)
            d.point((x + rng.randrange(16), y + rng.randrange(16)), fill=(60, 90, 120))
        elif name == "office":
            d.rectangle(box, fill=(90, 98, 104))
            d.rectangle(box, outline=(70, 78, 84))
            d.point((x + 7, y + 7), fill=TEAL)
        elif name == "cell_door":
            d.rectangle(box, fill=TEAL_DARK)
            d.rectangle(box, outline=INK)
            d.rectangle((x + 5, y, x + 10, y + 15), fill=TEAL)
        elif name in ("tube_h", "tube_v"):
            # A glass tunnel's floor: a dark walkway with ribs across it.
            d.rectangle(box, fill=(84, 96, 110))
            for k in range(1, 16, 5):
                if name == "tube_h":
                    d.line([(x + k, y), (x + k, y + 15)], fill=(64, 74, 88))
                else:
                    d.line([(x, y + k), (x + 15, y + k)], fill=(64, 74, 88))
            d.point((x + 7, y + 7), fill=(120, 140, 160))
        elif name.startswith("mosaic"):
            base = {"mosaic_0": SHELL, "mosaic_1": SHELL_PINK, "mosaic_2": (96, 150, 180)}[name]
            d.rectangle(box, fill=base)
            for k in range(0, 16, 4):
                d.line([(x + k, y), (x + k, y + 15)], fill=tuple(c - 22 for c in base))
                d.line([(x, y + k), (x + 15, y + k)], fill=tuple(c - 22 for c in base))
        elif name == "sump":
            d.rectangle(box, fill=(28, 58, 84))
            d.line([(x + 3, y + 6), (x + 8, y + 6)], fill=FLOOD_LIGHT)
            d.line([(x + 9, y + 11), (x + 13, y + 11)], fill=(70, 120, 160))
        elif name == "company_wall":
            # The company's prefab plate: cleaner than the city's, with a teal band.
            d.rectangle(box, fill=(46, 52, 60))
            d.rectangle((x, y, x + 15, y + 3), fill=(140, 150, 158))
            d.line([(x, y + 4), (x + 15, y + 4)], fill=INK)
            d.rectangle((x, y + 10, x + 15, y + 11), fill=TEAL)
            d.point((x + 2, y + 7), fill=TEAL_LIGHT)
        elif name in ("silt", "silt_2"):
            # The seabed seen through deep water round the city's foundations.
            d.rectangle(box, fill=(38, 56, 72) if name == "silt" else (34, 52, 68))
            speckle(x, y, [(54, 74, 88), (30, 44, 58), (64, 80, 90)], 9)
        elif name == "porthole":
            d.rectangle(box, fill=GREY_DARK)
            d.rectangle((x, y, x + 15, y + 3), fill=GREY_LIGHT)
            d.line([(x, y + 4), (x + 15, y + 4)], fill=INK)
            d.ellipse((x + 3, y + 5, x + 12, y + 14), fill=SEA, outline=GREY_LIGHT)
            d.point((x + 5, y + 7), fill=SEA_FOAM)
        elif name == "pipe_wall":
            # A big pipe seen from above, running up and down the map.
            for k, color in enumerate((INK, GREY_DARK, GREY, GREY_LIGHT, GREY_LIGHT, GREY, GREY, GREY_DARK)):
                d.rectangle((x + k * 2, y, x + k * 2 + 1, y + 15), fill=color)
            d.rectangle((x, y + 6, x + 15, y + 8), fill=ORANGE_DARK)
        elif name == "garden":
            d.rectangle(box, fill=(62, 52, 42))
            for gy in (3, 9):
                for gx in range(2, 15, 4):
                    d.line([(x + gx, y + gy + 4), (x + gx + 1, y + gy)], fill=KELP)
            d.point((x + 12, y + 13), fill=KELP_DARK)
        elif name == "puddle":
            d.rectangle(box, fill=LOWER)
            d.rectangle(box, outline=(40, 48, 62))
            d.ellipse((x + 2, y + 4, x + 13, y + 12), fill=FLOOD)
            d.line([(x + 5, y + 6), (x + 8, y + 6)], fill=FLOOD_LIGHT)
        elif name == "shaft":
            # The lift shaft from the dock down to the dome, seen from above.
            d.rectangle(box, fill=GREY_DARK)
            d.rectangle((x + 3, y, x + 12, y + 15), fill=(56, 62, 72))
            for k in (2, 10):
                d.line([(x, y + k), (x + 15, y + k)], fill=ORANGE_DARK)
        elif name == "planks":
            d.rectangle(box, fill=WOOD)
            for k in (4, 9, 14):
                d.line([(x, y + k), (x + 15, y + k)], fill=WOOD_DARK)
            d.point((x + 3 + rng.randrange(8), y + 2), fill=WOOD_DARK)
        elif name == "checker":
            for k in range(4):
                cx, cy = x + (k % 2) * 8, y + (k // 2) * 8
                d.rectangle((cx, cy, cx + 7, cy + 7), fill=SHELL if k in (0, 3) else (96, 120, 140))
        elif name == "rug":
            d.rectangle(box, fill=(70, 96, 120))
            d.rectangle((x + 1, y + 1, x + 14, y + 14), outline=WARM_DARK)
            d.point((x + 7, y + 7), fill=CORAL)
        elif name == "algae":
            d.rectangle(box, fill=LOWER_2)
            d.rectangle(box, outline=(40, 48, 62))
            speckle(x, y, [KELP_DARK, (50, 90, 70)], 14)
        elif name == "sand_ripple":
            d.rectangle(box, fill=SAND)
            for k in (3, 9, 14):
                d.arc((x - 2, y + k - 3, x + 18, y + k + 3), 20, 160, fill=SAND_2)
        elif name == "coral_floor":
            d.rectangle(box, fill=SAND_2)
            for _ in range(5):
                cx, cy = x + rng.randrange(2, 14), y + rng.randrange(2, 14)
                d.ellipse((cx - 1, cy - 1, cx + 1, cy + 1), fill=rng.choice([CORAL, CORAL_PINK, (230, 170, 80)]))
    return img


def main():
    save(terrain(), "skoljka_terrain")
    save(diving_suit(), "diving_suit")
    save(sea_creature(), "sea_creature")
    for key in PEOPLE:
        save(person_sprite(key), f"person_{key}")
    save(worker(TEAL, TEAL_DARK, 0, GREY_DARK, TEAL_LIGHT, blade=True), "company_crew")
    save(worker(TEAL, TEAL_DARK, 2, HAIRS[1], TEAL_LIGHT, tool=True), "company_crew_tool")
    save(big_pump(True), "big_pump")
    save(big_pump(False), "big_pump_stopped")
    save(valve(), "valve")
    save(console(), "console")
    save(console(ORANGE), "console_alarm")
    for i in range(3):
        save(relay_rack(i * 7 + 3), f"relay_rack_{i}")
    save(relay_rack(99, traced=True), "relay_rack_traced")
    save(lever(), "door_lever")
    save(air_station(), "air_station")
    save(airlock(), "airlock")
    save(suit_rack(), "suit_rack")
    save(intake(False), "intake_broken")
    save(intake(True), "intake_repaired")
    for i in range(2):
        save(kelp(i), f"kelp_{i}")
        save(seabed_rock(i + 4), f"seabed_rock_{i}")
    save(frame_window(), "frame_window")
    save(sealed_dock_door(), "sealed_dock_door")
    save(crane(), "crane")
    save(building(72, 56, GREY_LIGHT, BLUE_DARK, windows=3, sign=BLUE), "port_office")
    save(building(80, 56, WARM, ORANGE_DARK, door_color=ORANGE_DARK, windows=4, sign=ORANGE), "canteen")
    save(building(64, 52, GREY, GREY_DARK, windows=3), "housing_0")
    save(building(64, 52, GREY_LIGHT, GREY_DARK, windows=3), "housing_1")
    save(lift_head(), "lift_head")
    for i, color in enumerate((ORANGE, BLUE, (150, 80, 80))):
        save(market_stall(color, i + 11), f"market_stall_{i}")
    save(bench(), "bench")
    save(table(64), "council_table")
    save(table(40, TEAL), "office_desk")
    save(depot_shelf(), "depot_shelf")
    save(company_crates(), "company_crates")
    save(supply_crates(), "cargo")
    save(company_sign(), "company_sign")
    save(dome_lamp(), "dome_lamp")
    save(blue_lamp(), "blue_lamp")
    save(pipe_run(), "pipe_run")
    save(bunk(), "bunk")
    save(shell_house(), "shell_house")
    save(bubble_house(), "bubble_house")
    save(boat_house(), "boat_house")
    save(capsule_stack(), "capsule_stack")
    save(coral_house(), "coral_house")
    save(snail_house(), "snail_house")
    save(fish_lamp(), "fish_lamp")
    save(laundry_line(), "laundry_line")
    save(planter(), "planter")
    for i in range(2):
        save(fish_school(i + 31), f"fish_school_{i}")
        save(jellyfish(i), f"jellyfish_{i}")
    for i in range(3):
        save(coral(i), f"coral_{i}")
    save(bubbles(), "bubbles")
    save(buoy(), "buoy")
    save(anchor(), "anchor")
    save(barrels(), "barrels")
    save(net_rack(), "net_rack")
    save(shell_statue(), "shell_statue")
    save(aquarium(), "aquarium")
    save(canteen_table(), "canteen_table")
    save(workbench(), "workbench")
    save(gauge_panel(), "gauge_panel")
    save(lockers(), "lockers")
    save(generator(), "generator")
    save(fish_bones(), "fish_bones")
    save(wreck(), "wreck")
    print("wrote", len(list(OUT.glob("*.png"))), "Skoljka sprites")


if __name__ == "__main__":
    main()
