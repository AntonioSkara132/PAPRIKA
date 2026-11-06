#!/usr/bin/python3
"""Concept sheet for Smokva, the hacker Krešo's bar on a space rock in the Sea of Propuh.

Modelled on Caffe bar Smokva in Ždrelac (the user's reference photos):
- a night garden round a big old olive tree in a round, pebble-edged bed,
  lit from below; a swing bench with a green canopy and striped cushions;
  dark wooden chairs; strings of nautical signal flags overhead;
- a covered terrace on orange columns with a timber pergola, rattan chairs
  with pink cushions and dark tables;
- a lounge corner on artificial grass with barrel tables under a dark
  awning, string bulbs, and purple and cyan lights in the trees;
- a building of light cut-stone blocks with big windows and a TV on the
  wall; inside, an orange-red room with a wooden counter, a fridge and a
  shelf with a model boat (here, a model ship);
- low dry-stone walls round it.

Ždrelac is the strait and bridge between Ugljan and Pašman, so the rock is
two lobes joined by a stone bridge over open space: the landing pad on the
west lobe, the bar on the east one. Space rocks are always dark, so the
whole place is lit as at night.

Writes art/concepts/smokva_concept.png. Areas are drawn at half size and shown at 2x.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFilter

import create_otpornik_ship_art as ship
from create_otpornik_ship_art import (INK, SPACE, STAR, IRON, IRON_LIGHT, WOOD, WOOD_LIGHT, WOOD_DARK, BRASS,
                                      CREAM, YELLOW, GLOW, GLASS, GLASS_LIGHT, FONT, canvas, stains)
import create_space_rock_concept as rock

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/smokva_concept.png"

W, H = 480, 300
ROCK = rock.ROCK
ROCK_LIGHT = rock.ROCK_LIGHT
ROCK_DARK = rock.ROCK_DARK
ROCK_DEEP = rock.ROCK_DEEP
LIMESTONE = (214, 206, 186)
LIMESTONE_LIGHT = (236, 230, 212)
LIMESTONE_DARK = (168, 158, 138)
DRYSTONE = (150, 142, 128)
PAVING = (172, 150, 132)
PAVING_DARK = (146, 124, 110)
ORANGE = (222, 120, 52)
ORANGE_DARK = (170, 82, 36)
TIMBER = (176, 104, 56)
TIMBER_DARK = (128, 70, 38)
RATTAN = (150, 92, 50)
CUSHION = (222, 132, 140)
DARK_WOOD = (78, 44, 32)
LEAF = (78, 120, 70)
LEAF_LIGHT = (130, 170, 96)
OLIVE_LEAF = (120, 140, 96)
OLIVE_LIGHT = (176, 190, 140)
BARK = (110, 100, 88)
TURF = (52, 112, 66)
TURF_LIGHT = (70, 140, 80)
CANOPY = (66, 96, 74)
PURPLE = (184, 70, 230)
CYAN = (70, 210, 240)
BULB = (255, 230, 150)
WALL_RED = (196, 72, 44)
WALL_RED_DARK = (150, 52, 34)
TILE = (214, 200, 184)
TILE_DARK = (190, 174, 158)
FLAGS = [(222, 52, 44), (246, 246, 240), (40, 80, 170), (246, 206, 50), (30, 30, 36), (222, 52, 44)]


# ---------- pieces ----------

def lobe(cx, cy, rx, ry, seed):
    pts = []
    for i in range(56):
        a = i / 56 * math.tau
        r = 1 + .05 * math.sin(a * 4 + seed) + .03 * math.sin(a * 9 + seed * 2)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    return pts


def dry_wall(d, pts, rng):
    """A low dry-stone wall along a path of points: irregular light and grey stones."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / 4))
        for i in range(n):
            x, y = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
            c = rng.choice((DRYSTONE, LIMESTONE_DARK, (128, 120, 108), LIMESTONE))
            d.rectangle((x - 2, y - 2, x + 2, y + 1), fill=c, outline=INK)


def stone_blocks(d, box, rng):
    """Light cut-stone blocks in courses, as on the bar's walls."""
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=LIMESTONE)
    for row, y in enumerate(range(y0, y1, 5)):
        off = 0 if row % 2 == 0 else 4
        for x in range(x0 - 8 + off, x1, 9):
            c = rng.choice((LIMESTONE, LIMESTONE_LIGHT, LIMESTONE_DARK, LIMESTONE))
            d.rectangle((max(x0, x), y, min(x1, x + 8), min(y1, y + 4)), fill=c)
        d.line((x0, y, x1, y), fill=LIMESTONE_DARK)


def paving(d, box, rng):
    """Irregular stone paving of the terrace and garden paths."""
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=PAVING)
    for _ in range((x1 - x0) * (y1 - y0) // 40):
        x, y = rng.randint(x0, x1 - 4), rng.randint(y0, y1 - 3)
        d.rectangle((x, y, x + rng.randint(3, 6), y + rng.randint(2, 4)), outline=PAVING_DARK)


def olive_tree(d, img, x, y):
    """The big old olive tree in its round bed: a pebble rim, low green plants, a twisted trunk
    lit from below, and a wide grey-green crown."""
    d.ellipse((x - 26, y - 12, x + 26, y + 14), fill=LIMESTONE_DARK, outline=INK)
    for i in range(36):
        a = i / 36 * math.tau
        d.point((x + math.cos(a) * 25, y + 1 + math.sin(a) * 12), fill=LIMESTONE_LIGHT)
    d.ellipse((x - 22, y - 9, x + 22, y + 11), fill=LEAF)
    rng = random.Random(7)
    for _ in range(50):
        px, py = x + rng.randint(-20, 20), y + rng.randint(-8, 9)
        d.point((px, py), fill=rng.choice((LEAF_LIGHT, (60, 96, 56))))
    # warm uplight on the trunk
    glow = Image.new("RGBA", img.size)
    ImageDraw.Draw(glow).ellipse((x - 14, y - 30, x + 14, y + 4), fill=(255, 226, 150, 110))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5)))
    d.polygon([(x - 6, y + 2), (x - 3, y - 18), (x + 3, y - 18), (x + 7, y + 2)], fill=BARK, outline=INK)
    d.line((x - 1, y - 2, x - 2, y - 16), fill=(150, 140, 124))
    d.line((x + 3, y, x + 2, y - 12), fill=(80, 72, 64))
    for dx, dy in ((-10, -24), (9, -26), (0, -30)):
        d.line((x, y - 16, x + dx, y + dy), fill=BARK, width=2)
    for cx, cy, r in ((x - 16, y - 34, 14), (x + 14, y - 36, 15), (x, y - 44, 15), (x - 4, y - 30, 12), (x + 22, y - 26, 10), (x - 24, y - 24, 9)):
        d.ellipse((cx - r, cy - r * .7, cx + r, cy + r * .7), fill=OLIVE_LEAF, outline=INK)
    for _ in range(90):
        a, rr = rng.random() * math.tau, rng.random() * 26
        d.point((x + math.cos(a) * rr * 1.2, y - 35 + math.sin(a) * rr * .6), fill=rng.choice((OLIVE_LIGHT, (92, 110, 76))))


def flag_string(d, a, b, sag=6, step=5):
    """A string of nautical signal flags between two posts."""
    (x0, y0), (x1, y1) = a, b
    n = max(2, int(math.hypot(x1 - x0, y1 - y0) / step))
    prev = None
    for i in range(n + 1):
        t = i / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + sag * math.sin(math.pi * t)
        if prev:
            d.line((prev, (x, y)), fill=INK)
        if 0 < i < n:
            c = FLAGS[i % len(FLAGS)]
            d.rectangle((x - 1, y + 1, x + 1, y + 3), fill=c)
            if i % 3 == 0:
                d.point((x, y + 2), fill=FLAGS[(i + 2) % len(FLAGS)])
        prev = (x, y)


def bulb_string(d, a, b, sag=5, step=6):
    (x0, y0), (x1, y1) = a, b
    n = max(2, int(math.hypot(x1 - x0, y1 - y0) / step))
    prev = None
    for i in range(n + 1):
        t = i / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + sag * math.sin(math.pi * t)
        if prev:
            d.line((prev, (x, y)), fill=INK)
        d.point((x, y + 1), fill=BULB)
        prev = (x, y)


def chair(d, x, y, rattan=False):
    if rattan:
        d.ellipse((x - 3, y - 4, x + 3, y), fill=RATTAN, outline=INK)
        d.rectangle((x - 2, y - 1, x + 2, y + 2), fill=CUSHION, outline=INK)
    else:
        d.rectangle((x - 2, y - 4, x + 2, y - 2), fill=DARK_WOOD, outline=INK)
        d.rectangle((x - 2, y - 1, x + 2, y + 2), fill=(214, 200, 150), outline=INK)


def table(d, x, y, r=4, color=DARK_WOOD):
    d.ellipse((x - r, y - r * .7, x + r, y + r * .7), fill=color, outline=INK)
    d.point((x - 1, y - 1), fill=(130, 90, 64))


def barrel_table(d, x, y):
    d.ellipse((x - 4, y - 3, x + 4, y + 3), fill=(120, 74, 44), outline=INK)
    d.line((x - 4, y, x + 4, y), fill=IRON)
    d.ellipse((x - 3, y - 3, x + 3, y), fill=(150, 96, 58))


def swing(d, x, y):
    """The swing bench with its green canopy and white-green striped cushion."""
    d.line((x - 12, y - 10, x - 12, y + 6), fill=(150, 40, 50), width=1)
    d.line((x + 12, y - 10, x + 12, y + 6), fill=(150, 40, 50), width=1)
    d.rectangle((x - 9, y - 1, x + 9, y + 4), fill=(240, 240, 230), outline=INK)
    for sx in range(x - 8, x + 9, 3):
        d.line((sx, y, sx, y + 3), fill=(52, 110, 74))
    d.polygon([(x - 14, y - 10), (x + 14, y - 10), (x + 12, y - 4), (x - 12, y - 4)], fill=CANOPY, outline=INK)
    for sx in range(x - 12, x + 13, 4):
        d.arc((sx - 2, y - 6, sx + 2, y - 2), 0, 180, fill=INK)


def uplight(img, x, y, color, r=14):
    glow = Image.new("RGBA", img.size)
    ImageDraw.Draw(glow).ellipse((x - r, y - r, x + r, y + r), fill=color + (120,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(r / 2.5)))


def small_tree(d, x, y, color=OLIVE_LEAF):
    d.line((x, y, x, y - 8), fill=BARK, width=2)
    d.ellipse((x - 8, y - 18, x + 8, y - 6), fill=color, outline=INK)
    d.point((x - 3, y - 14), fill=OLIVE_LIGHT)
    d.point((x + 4, y - 11), fill=OLIVE_LIGHT)


def palm_pot(d, x, y):
    d.rectangle((x - 3, y - 4, x + 3, y + 2), fill=(70, 150, 70), outline=INK)
    for dx, dy in ((-7, -9), (7, -9), (-4, -12), (4, -12), (0, -13), (-8, -5), (8, -5)):
        d.line((x, y - 4, x + dx, y + dy), fill=(110, 170, 80))


def small_ship_model(d, x, y):
    d.polygon([(x, y), (x + 10, y - 2), (x + 12, y), (x + 10, y + 2)], fill=IRON_LIGHT, outline=INK)
    d.point((x + 3, y), fill=GLASS_LIGHT)


# ---------- the exterior ----------

PAD = (78, 170)
BAR_BOX = (210, 46, 380, 96)  # the stone building, top-down front wall at the bottom


def exterior(lasta=True):
    """The rock at night. Without `lasta` the pad is empty, for the game, which places the ship itself."""
    rng = random.Random(97)
    img, d = canvas(W, H, SPACE + (255,))
    rock.starfield(img, rng, 320)
    west = lobe(86, 174, 80, 82, 1)
    east = lobe(300, 150, 168, 134, 2)
    for pts in (west, east):
        d.polygon(pts, fill=ROCK_DARK)
        d.polygon([(x, y - 3) for x, y in pts], fill=ROCK)
    stains(d, rng, (10, 20, 470, 290), 260, (ROCK_LIGHT, ROCK_DARK, rock.DUST), (2, 5))
    for x, y, r in ((40, 230, 10), (120, 230, 8), (440, 230, 10), (420, 70, 8), (180, 268, 7)):
        rock.crater(d, x, y, r)
    # the landing pad on the west lobe, with the Lasta's ring and lamps
    px, py = PAD
    d.ellipse((px - 46, py - 26, px + 46, py + 26), fill=(110, 110, 118), outline=INK)
    d.ellipse((px - 38, py - 20, px + 38, py + 20), outline=YELLOW)
    d.line((px - 10, py, px + 10, py), fill=YELLOW)
    d.line((px, py - 6, px, py + 6), fill=YELLOW)
    for a in range(0, 360, 45):
        lx, ly = px + math.cos(math.radians(a)) * 46, py + math.sin(math.radians(a)) * 26
        d.point((lx, ly), fill=BULB)
    # a little dock booth and a sign by the pad
    d.rectangle((26, 104, 46, 120), fill=LIMESTONE, outline=INK)
    d.rectangle((30, 108, 36, 114), fill=GLASS)
    d.rectangle((52, 108, 82, 116), fill=DARK_WOOD, outline=INK)
    d.text((54, 106), "SMOKVA", font=FONT, fill=BULB)
    # the stone bridge over the gap between the lobes (the Ždrelac bridge)
    d.polygon([(150, 160), (186, 156), (186, 176), (150, 180)], fill=SPACE)
    d.rectangle((140, 158, 196, 174), fill=LIMESTONE, outline=INK)
    for x in range(142, 196, 6):
        d.line((x, 158, x, 174), fill=LIMESTONE_DARK)
    d.line((140, 158, 196, 158), fill=LIMESTONE_LIGHT, width=2)
    d.line((140, 174, 196, 174), fill=LIMESTONE_DARK, width=2)
    d.arc((146, 170, 190, 192), 180, 360, fill=LIMESTONE_DARK, width=2)
    for x in (142, 194):
        d.rectangle((x - 2, 154, x + 2, 160), fill=LIMESTONE_LIGHT, outline=INK)
        d.point((x, 153), fill=BULB)
    # the garden and terrace on the east lobe, inside an irregular dry-stone wall
    yard = [(204, 178), (198, 206), (206, 236), (236, 258), (270, 268), (304, 264), (334, 272), (372, 262),
            (404, 248), (430, 230), (450, 200), (454, 166), (446, 132), (440, 104), (204, 104), (204, 154)]
    layer, ld = canvas(W, H)
    paving(ld, (196, 100, 456, 274), rng)
    # artificial grass under the lounge, a lawn bay in the south west and a planted bed in the south
    ld.polygon([(386, 128), (446, 124), (452, 168), (446, 214), (420, 230), (392, 214), (380, 170)], fill=TURF)
    ld.polygon([(206, 220), (232, 212), (262, 226), (258, 262), (236, 258), (208, 238)], fill=TURF)
    ld.polygon([(300, 248), (330, 240), (362, 246), (368, 262), (334, 270), (304, 262)], fill=(70, 96, 58))
    for _ in range(320):
        x, y = rng.randint(196, 456), rng.randint(120, 272)
        if ld.im.getpixel((x, y))[:3] == TURF:
            ld.point((x, y), fill=TURF_LIGHT)
    for x, y in ((310, 252), (322, 258), (340, 250), (352, 258), (334, 262)):
        ld.point((x, y), fill=(220, 90, 120))
        ld.point((x + 1, y - 1), fill=LEAF_LIGHT)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(yard, fill=255)
    img.paste(layer, (0, 0), Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
    d = ImageDraw.Draw(img)
    # stepping stones through the lawn bay, a pebble path round the tree
    for x, y in ((214, 226), (224, 236), (236, 246), (248, 254)):
        d.ellipse((x - 3, y - 2, x + 3, y + 2), fill=LIMESTONE_LIGHT, outline=INK)
    dry_wall(d, yard[:-2] + [yard[-2]], rng)
    dry_wall(d, [yard[-2], yard[-1]], rng)
    # a low inner wall with a gap divides the garden from the lounge
    dry_wall(d, [(376, 134), (378, 160)], rng)
    dry_wall(d, [(378, 186), (384, 216)], rng)
    # the toilet hut in the north-east corner, half hidden by a reed screen
    d.rectangle((428, 66, 446, 88), fill=LIMESTONE, outline=INK)
    d.rectangle((432, 76, 440, 88), fill=DARK_WOOD, outline=INK)
    d.text((430, 64), "WC", font=FONT, fill=INK)
    for x in range(410, 428, 2):
        d.line((x, 80, x, 100), fill=(196, 170, 110) if x % 4 else (160, 136, 84))
    # the stone building
    x0, y0, x1, y1 = BAR_BOX
    d.rectangle((x0, y0 - 18, x1, y0), fill=(170, 80, 60), outline=INK)  # roof
    for x in range(x0 + 4, x1, 8):
        d.line((x, y0 - 18, x, y0), fill=(140, 62, 48))
    stone_blocks(d, (x0, y0, x1, y1), rng)
    d.rectangle((x0, y0, x1, y1), outline=INK)
    # windows, the door, the TV between them and the sign over the door
    for wx in (x0 + 10, x0 + 52, x1 - 50):
        d.rectangle((wx, y0 + 16, wx + 30, y1 - 8), fill=(255, 196, 120), outline=INK)
        d.line((wx + 15, y0 + 16, wx + 15, y1 - 8), fill=INK)
        d.point((wx + 6, y0 + 22), fill=(255, 240, 200))
    dx = x0 + 100
    d.rectangle((dx, y0 + 12, dx + 16, y1), fill=WALL_RED_DARK, outline=INK)
    d.rectangle((dx + 2, y0 + 14, dx + 14, y1), fill=(230, 140, 80))
    d.rectangle((x0 + 86, y0 + 4, x0 + 98, y0 + 11), fill=INK)
    d.rectangle((x0 + 87, y0 + 5, x0 + 97, y0 + 10), fill=(90, 150, 220))
    d.rectangle((dx - 8, y0 - 14, dx + 24, y0 - 5), fill=DARK_WOOD, outline=INK)
    d.text((dx - 6, y0 - 16), "SMOKVA", font=FONT, fill=BULB)
    # a little side door to the cellar on the east end
    d.rectangle((x1 - 12, y0 + 22, x1 - 4, y1), fill=DARK_WOOD, outline=INK)
    # covered terrace: orange columns and a timber pergola in front of the building
    tx0, ty0, tx1, ty1 = x0 - 4, y1, x1 + 4, y1 + 34
    d.rectangle((tx0, ty0, tx1, ty1), fill=(150, 116, 98))
    for x in range(tx0, tx1, 6):
        d.line((x, ty0, x, ty1), fill=(138, 104, 88))
    for i in range(4):
        cx = 220 + i * 25
        cy = ty0 + 12 + (i % 2) * 6
        table(d, cx, cy, 5, DARK_WOOD)
        chair(d, cx - 7, cy + 1, True)
        chair(d, cx + 7, cy + 1, True)
        chair(d, cx, cy + 7, True)
    for i in range(2):
        cx = 330 + i * 26
        table(d, cx, ty0 + 14, 5, DARK_WOOD)
        chair(d, cx - 7, ty0 + 15, True)
        chair(d, cx + 7, ty0 + 15, True)
    for x in range(tx0, tx1 + 1, 32):
        d.line((x, ty0 - 2, x, ty1), fill=TIMBER_DARK)
    d.line((tx0, ty1, tx1, ty1), fill=TIMBER, width=3)
    d.line((tx0, ty0 + 1, tx1, ty0 + 1), fill=TIMBER, width=2)
    for x in range(tx0, tx1 + 1, 32):
        d.rectangle((x - 2, ty1 - 3, x + 2, ty1 + 3), fill=ORANGE, outline=INK)
    d.line((tx1, ty0, tx1, ty1 + 4), fill=ORANGE_DARK, width=2)  # the orange gutter pipe
    # the garden: the olive tree, the swing, wooden chairs and tables
    olive_tree(d, img, 262, 188)
    swing(d, 318, 170)
    for cx, cy in ((312, 214), (348, 200), (290, 236), (350, 228)):
        table(d, cx, cy, 5, (190, 170, 130))
        chair(d, cx - 7, cy + 1)
        chair(d, cx + 7, cy + 1)
    # flag strings over the garden from the terrace posts to the wall
    flag_string(d, (206, 132), (300, 150))
    flag_string(d, (300, 150), (380, 132))
    flag_string(d, (380, 132), (440, 160), 4)
    # the lounge: barrel tables on turf under a dark awning with string bulbs
    d.polygon([(388, 112), (440, 108), (446, 128), (392, 132)], fill=(70, 64, 92), outline=INK)
    for x in range(392, 444, 8):
        d.line((x, 112, x + 2, 130), fill=(56, 50, 76))
    for x in range(392, 446, 6):
        d.arc((x - 3, 127, x + 3, 133), 0, 180, fill=INK)
    bulb_string(d, (388, 132), (446, 128), 3, 5)
    for cx, cy in ((402, 148), (430, 152), (408, 180), (432, 196), (404, 206)):
        barrel_table(d, cx, cy)
        chair(d, cx - 7, cy)
        chair(d, cx + 7, cy)
    for x, y, c in ((382, 120, PURPLE), (452, 140, CYAN), (452, 210, PURPLE), (384, 220, CYAN)):
        uplight(img, x, y, c, 14)
    d = ImageDraw.Draw(img)
    small_tree(d, 382, 126, (110, 130, 170))
    small_tree(d, 452, 146, (90, 170, 190))
    small_tree(d, 452, 214, (150, 100, 170))
    # potted palm, planters and a fig (smokva) by the gate
    palm_pot(d, 206, 168)
    palm_pot(d, 444, 236)
    for x, y in ((270, 254), (284, 256)):
        d.rectangle((x, y, x + 10, y + 4), fill=LIMESTONE_DARK, outline=INK)
        d.point((x + 3, y - 1), fill=LEAF_LIGHT)
        d.point((x + 7, y - 1), fill=(220, 90, 120))
    # a young fig tree (smokva) in the lawn bay
    small_tree(d, 222, 214, LEAF)
    d.point((218, 204), fill=(110, 60, 110))
    d.point((226, 208), fill=(110, 60, 110))
    # the gate in the wall facing the bridge, with a lamp
    d.rectangle((196, 160, 204, 174), fill=PAVING)
    d.point((200, 156), fill=BULB)
    # Krešo's crates and empty bottle cases behind the building
    for x, y in ((388, 56), (398, 60), (392, 70)):
        d.rectangle((x, y, x + 9, y + 7), fill=WOOD, outline=INK)
        d.line((x + 1, y + 2, x + 8, y + 2), fill=WOOD_DARK)
    for x in (184, 192):
        d.rectangle((x, 72, x + 6, 80), fill=(70, 110, 70), outline=INK)
    # the Lasta on the pad
    d.ellipse((px - 50, py + 12, px + 50, py + 26), fill=ROCK_DEEP)
    if lasta:
        img.alpha_composite(ship.ship_exterior().resize((100, 51), Image.NEAREST), (px - 50, py - 34))
    # everything is dark: a night tint with the lights kept bright
    night = Image.new("RGBA", img.size, (10, 8, 30, 70))
    img.alpha_composite(night)
    return img


# ---------- the interior ----------

IW, IH = 200, 140


def room_floor(d, box, kind):
    x0, y0, x1, y1 = box
    if kind == "tile":
        for y in range(y0, y1, 8):
            for x in range(x0, x1, 8):
                d.rectangle((x, y, min(x1, x + 7), min(y1, y + 7)), fill=TILE if (x // 8 + y // 8) % 2 else TILE_DARK)
    elif kind == "wood":
        for y in range(y0, y1, 5):
            d.rectangle((x0, y, x1, min(y1, y + 4)), fill=WOOD_LIGHT if (y // 5) % 2 else WOOD)
            d.line((x0 + (y * 7) % 23, y, x0 + (y * 7) % 23, y + 4), fill=WOOD_DARK)
    else:
        d.rectangle(box, fill=kind)


def back_wall(d, x0, x1, y, h=12, color=WALL_RED):
    d.rectangle((x0, y, x1, y + h), fill=color)
    d.line((x0, y + h, x1, y + h), fill=WALL_RED_DARK)


def interior():
    """Inside the bar: one room. The bar with the drinks in the top right, a couch in the top
    left under the TV, tables in the middle, table soccer on the left and darts low on the
    left wall in the bottom corner. Doors lead to Krešo's back room and the WC; a trapdoor
    behind the counter goes down to the cellar; the front door opens on the terrace."""
    img, d = canvas(IW, IH, INK + (255,))
    room_floor(d, (4, 4, IW - 5, IH - 5), "tile")
    back_wall(d, 5, IW - 6, 5, 14)
    # the couch, top left, under the TV: one straight piece
    d.rectangle((22, 6, 44, 14), fill=INK)
    d.rectangle((24, 7, 42, 13), fill=(90, 150, 220))
    d.point((32, 9), fill=(240, 240, 240))
    d.rectangle((8, 20, 64, 32), fill=(214, 200, 170), outline=INK)
    d.rectangle((12, 21, 60, 25), fill=(236, 224, 196))
    d.rectangle((8, 20, 12, 32), fill=(190, 174, 144), outline=INK)
    d.rectangle((60, 20, 64, 32), fill=(190, 174, 144), outline=INK)
    for x, c in ((22, (222, 52, 44)), (48, (60, 140, 70))):  # two cushions
        d.rectangle((x, 24, x + 5, 28), fill=c, outline=INK)
    # the door to Krešo's back room in the back wall
    d.rectangle((96, 6, 110, 19), fill=DARK_WOOD, outline=INK)
    d.point((107, 13), fill=BRASS)
    # the bar, top right: shelves of bottles, the fridge, the coffee machine, a model ship,
    # and the straight wooden counter with stools in front
    d.rectangle((180, 6, 192, 19), fill=(236, 236, 240), outline=INK)  # fridge
    d.line((180, 12, 192, 12), fill=(180, 180, 190))
    for row, y in enumerate((7, 13)):
        d.rectangle((130, y + 4, 176, y + 5), fill=DARK_WOOD, outline=INK)
        for i, x in enumerate(range(132, 166, 4)):
            d.rectangle((x, y, x + 2, y + 4), fill=[(60, 120, 60), (150, 60, 50), (200, 170, 90), (70, 90, 150)][(i + row) % 4], outline=INK)
    small_ship_model(d, 166, 8)
    d.rectangle((114, 34, 192, 44), fill=(120, 54, 60), outline=INK)
    d.rectangle((116, 36, 190, 38), fill=(150, 70, 76))
    d.line((114, 34, 192, 34), fill=DARK_WOOD, width=2)
    d.rectangle((170, 29, 176, 33), fill=IRON)  # coffee machine
    d.point((173, 28), fill=GLOW)
    for x, y in ((124, 31), (134, 31), (150, 31)):  # glasses on the counter
        d.point((x, y), fill=GLASS_LIGHT)
    d.rectangle((140, 24, 152, 30), fill=DARK_WOOD, outline=INK)  # the cellar trapdoor behind the counter
    d.line((142, 27, 150, 27), fill=IRON)
    for x in range(120, 192, 10):
        d.ellipse((x - 3, 48, x + 3, 52), fill=INK)
        d.ellipse((x - 2, 48, x + 2, 51), fill=DARK_WOOD)
    # the WC door in the right wall
    d.rectangle((IW - 8, 52, IW - 5, 66), fill=DARK_WOOD, outline=INK)
    # table soccer on the left
    fx0, fy0, fx1, fy1 = 10, 60, 38, 84
    d.rectangle((fx0, fy0, fx1, fy1), fill=DARK_WOOD, outline=INK)
    d.rectangle((fx0 + 2, fy0 + 2, fx1 - 2, fy1 - 2), fill=(60, 140, 70))
    d.line((fx0 + 2, (fy0 + fy1) // 2, fx1 - 2, (fy0 + fy1) // 2), fill=(230, 240, 230))
    for i, x in enumerate(range(fx0 + 5, fx1 - 2, 4)):
        d.line((x, fy0 - 3, x, fy1 + 3), fill=(190, 194, 204))
        team = (222, 52, 44) if i % 2 == 0 else (40, 80, 170)
        for y in range(fy0 + 5, fy1 - 2, 6):
            d.point((x, y), fill=team)
    d.point((24, 71), fill=(250, 250, 250))
    # tables with rattan chairs in the middle, the jukebox by the back-room door
    for cx, cy in ((122, 66), (158, 68), (138, 88), (172, 90), (124, 110), (156, 112)):
        table(d, cx, cy, 5, DARK_WOOD)
        chair(d, cx - 7, cy + 1, True)
        chair(d, cx + 7, cy + 1, True)
    d.rectangle((114, 8, 124, 20), fill=(120, 40, 80), outline=INK)
    d.rectangle((116, 10, 122, 14), fill=(255, 200, 120))
    palm_pot(d, 88, 30)
    palm_pot(d, 186, 124)
    # darts low on the left wall in the bottom corner, facing right: a round board in a wooden
    # cabinet, darts in it, a chalk score board above, a mat and a throw line
    bx, by = 15, 116
    d.rectangle((4, by - 12, bx + 3, by + 12), fill=DARK_WOOD, outline=INK)
    d.ellipse((bx - 9, by - 10, bx + 9, by + 10), fill=INK)
    for r, c in ((8, (30, 30, 30)), (7, (222, 52, 44)), (6, (236, 226, 196)), (4, (30, 30, 30)), (3, (60, 160, 80)), (1, (222, 52, 44))):
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=c)
    for ang in range(0, 360, 45):
        d.line((bx, by, bx + 7 * math.cos(math.radians(ang)), by + 7 * math.sin(math.radians(ang))), fill=(30, 30, 30))
    d.point((bx, by), fill=(222, 52, 44))
    for x, y in ((bx + 3, by - 2), (bx - 2, by + 3), (bx + 1, by + 5)):
        d.line((x, y, x + 4, y), fill=CREAM)  # darts, flights pointing right
        d.point((x + 4, y), fill=(222, 52, 44))
    d.rectangle((26, by - 10, 48, by + 8), fill=(70, 60, 80))  # the mat
    d.line((52, by - 10, 52, by + 10), fill=CREAM, width=2)  # throw line
    d.rectangle((5, by - 24, bx + 2, by - 15), fill=(40, 52, 46), outline=INK)  # chalk score board
    for y in (by - 22, by - 19):
        d.line((7, y, bx, y), fill=CREAM)
    # the front door and windows out to the terrace along the bottom wall
    d.rectangle((92, IH - 8, 112, IH - 4), fill=(230, 140, 80), outline=INK)
    for x in (20, 56, 124):
        d.rectangle((x, IH - 7, x + 26, IH - 4), fill=(255, 196, 120), outline=INK)
    d.rectangle((0, 0, IW - 1, IH - 1), outline=INK, width=4)
    return img


# ---------- characters ----------

PLAIN = (91, 57, 44), (28, 23, 48), (220, 167, 120), (78, 131, 207), (65, 57, 71)


def recolor(img, mapping):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c[3] and c[:3] in mapping:
                px[x, y] = mapping[c[:3]] + (255,)


def kreso():
    """Krešo, the hacker who runs the bar: heavy, bearded, a dark sailor's striped shirt under a
    bottle-green apron with gold dots, a towel on the shoulder."""
    img = Image.open(ROOT / "assets/art/player_plain.png").convert("RGBA")
    hair, outline, skin, shirt, trousers = PLAIN
    px = img.load()
    for y in range(24):
        for x in range(16):
            if px[x, y][:3] == shirt:
                px[x, y] = ((40, 44, 70) if y % 2 else (196, 200, 214)) + (255,)
    d = ImageDraw.Draw(img)
    # wider body
    d.line((3, 11, 3, 16), fill=(40, 44, 70))
    d.line((12, 11, 12, 16), fill=(40, 44, 70))
    # apron with gold dots
    d.rectangle((5, 12, 10, 20), fill=(30, 70, 50))
    for x, y in ((6, 13), (9, 15), (6, 17), (9, 19)):
        d.point((x, y), fill=(236, 196, 70))
    d.line((5, 12, 10, 12), fill=(20, 50, 36))
    # beard and short dark hair, a towel over the left shoulder
    d.rectangle((5, 6, 10, 8), fill=(60, 40, 34))
    d.point((8, 6), fill=skin)
    recolor(img, {hair: (50, 36, 32)})
    d.rectangle((3, 9, 4, 13), fill=(240, 236, 220))
    return img


def donat():
    """Donat, a young hacker: a dark orange hoodie with black dots, the hood down, grey trousers,
    red hair, and the same blue eyes as Davor, which nobody remarks on yet."""
    img = Image.open(ROOT / "assets/art/player_plain.png").convert("RGBA")
    hair, outline, skin, shirt, trousers = PLAIN
    px = img.load()
    for y in range(24):
        for x in range(16):
            if px[x, y][:3] == shirt:
                dot = y % 2 == 0 and (x + y // 2) % 3 == 0
                px[x, y] = ((20, 16, 24) if dot else (176, 82, 34)) + (255,)
    recolor(img, {hair: (196, 52, 36), trousers: (74, 76, 84)})
    d = ImageDraw.Draw(img)
    # long sleeves, the hood bunched at the neck, a drawstring
    for x in (3, 4, 11, 12):
        d.line((x, 10, x, 14), fill=(176, 82, 34))
    d.line((5, 9, 10, 9), fill=(140, 62, 26))
    d.point((7, 11), fill=(240, 236, 220))
    d.point((8, 11), fill=(240, 236, 220))
    d.point((8, 6), fill=(78, 131, 207))  # Davor's eye colour
    d.point((6, 2), fill=(232, 96, 60))  # a lighter streak in the red hair
    d.point((9, 2), fill=(232, 96, 60))
    return img


def figure_panel(img, scale=4):
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


# ---------- the sheet ----------

def build():
    sheet = Image.new("RGBA", (1460, 720), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def label(x, y, title):
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)

    def panel(img, x, y, scale, title, note):
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 18))
        label(x, y, title)
        d.text((x, y + 22 + big.height), note, font=FONT, fill=CREAM)

    panel(exterior(), 20, 10, 2, "SMOKVA - THE ROCK",
          "Two lobes joined by a stone bridge (Zdrelac). West: the landing pad with the Lasta, a dock booth.\n"
          "East, inside an irregular dry-stone wall: the stone bar with its sign and TV, the covered terrace on orange columns\n"
          "(rattan chairs, pink cushions), the garden round the big olive tree with the swing and signal flags,\n"
          "and the lounge on turf: barrel tables under a dark awning, string bulbs, purple and cyan lights in the trees.\n"
          "A young fig tree (smokva) in the lawn bay, a flower bed in the south, the WC hut behind a reed screen.")
    panel(interior(), 1000, 10, 2, "SMOKVA - INSIDE",
          "One room: orange-red walls, light tiles. Top right, the\n"
          "bar: bottles, fridge, coffee machine, a model ship, the\n"
          "straight wooden counter, stools, the cellar trapdoor.\n"
          "Top left, the couch under the TV. Table soccer on the\n"
          "left, darts low on the left wall (bottom corner).\n"
          "Doors: Kreso's back room, the WC, out to the terrace.")
    figures = [
        (kreso(), "KRESO", "Runs the bar. A hacker.\nSailor's striped shirt,\nbottle-green apron with\ngold dots, towel on\nthe shoulder, beard."),
        (donat(), "DONAT", "Young hacker. Dark\norange hoodie with\nblack dots, red hair,\nDavor's blue eyes."),
        (Image.open(ROOT / "assets/art/engineeria/davor.png").convert("RGBA"), "DAVOR (FOR COMPARISON)", ""),
        (Image.open(ROOT / "assets/art/iskra/npcs/veki.png").convert("RGBA"), "VEKI", ""),
    ]
    for i, (img, title, note) in enumerate(figures):
        fx, fy = 1000 + (i % 2) * 230, 410 + (i // 2) * 150
        big = figure_panel(img)
        sheet.alpha_composite(big, (fx, fy + 18))
        label(fx, fy, title)
        d.text((fx + big.width + 10, fy + 30), note, font=FONT, fill=CREAM)
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
