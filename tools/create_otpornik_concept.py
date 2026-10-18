#!/usr/bin/python3
"""Render a daytime concept of Otpornik, the Engineeria university planet.

The visit is compact: a passenger port and used-ship yard at the bottom, a
crooked town of small squares in the middle, and the university on a raised
terrace at the top. The university's landmark is two copper towers joined by a
glass bridge, with an electrical experiment running between them; it is drawn
large enough to be seen from the port.

The scene follows the other concepts: 16-pixel ground, sprites sorted by their
bottom edge, dark #1c1730 outlines, flat shading and soft shadows. Existing
player, Veki and Iskra NPC sprites give the scale.

Writes art/concepts/otpornik_concept.png (whole map, 1x) and two 2x close-ups:
otpornik_concept_university.png and otpornik_concept_port.png.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/otpornik_concept.png"
UNIVERSITY_OUT = ROOT / "art/concepts/otpornik_concept_university.png"
PORT_OUT = ROOT / "art/concepts/otpornik_concept_port.png"
NPCS = ROOT / "assets/art/iskra/npcs"

TILE = 16
W, H = 1280, 896

INK = (28, 23, 48)
SHADOW = (28, 23, 48, 90)
GRASS = (112, 158, 98)
GRASS_2 = (102, 148, 92)
GRASS_LIGHT = (146, 186, 112)
PAVING = (204, 196, 182)
PAVING_2 = (190, 182, 168)
PAVING_DARK = (160, 152, 140)
TERRACE = (224, 214, 192)
TERRACE_2 = (210, 200, 178)
TERRACE_FACE = (150, 136, 116)
CONCRETE = (150, 154, 158)
CONCRETE_2 = (138, 142, 148)
CONCRETE_LINE = (226, 196, 70)
STONE = (232, 222, 198)
STONE_SHADE = (196, 184, 158)
STONE_DARK = (160, 146, 122)
COPPER = (196, 116, 64)
COPPER_DARK = (146, 80, 48)
COPPER_LIGHT = (232, 160, 96)
VERDIGRIS = (96, 170, 150)
VERDIGRIS_DARK = (62, 126, 112)
GLASS = (120, 186, 210)
GLASS_DARK = (78, 138, 170)
GLASS_LIGHT = (200, 234, 242)
STEEL = (168, 176, 196)
STEEL_DARK = (118, 126, 150)
STEEL_LIGHT = (214, 220, 232)
PLASTER = [(236, 220, 184), (218, 196, 204), (196, 214, 196), (226, 206, 160), (204, 208, 226)]
ROOFS = [((186, 72, 58), (142, 50, 46)), ((84, 108, 150), (60, 78, 112)), ((122, 92, 64), (92, 66, 48)), ((96, 140, 108), (68, 104, 80))]
WINDOW = (58, 142, 168)
WINDOW_LIGHT = (150, 206, 222)
DOOR = (104, 62, 44)
WOOD = (122, 84, 56)
WOOD_DARK = (88, 58, 40)
LEAF = (72, 132, 60)
LEAF_DARK = (46, 92, 46)
LEAF_LIGHT = (118, 176, 84)
SPARK = (250, 246, 170)
SPARK_GLOW = (150, 220, 255)
ORANGE = (236, 128, 44)
WHITE = (240, 238, 230)
YELLOW = (236, 192, 56)

FONT = ImageFont.load_default()
rng = random.Random(7)


# ---------- helpers ----------

def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def box(d, b, fill, width=1):
    d.rectangle(b, fill=fill, outline=INK, width=width)


def windows(d, x0, x1, y, count, h=10, color=WINDOW, light=WINDOW_LIGHT):
    step = (x1 - x0) / count
    for i in range(count):
        wx = int(x0 + step * i + step / 2) - 4
        d.rectangle((wx, y, wx + 8, y + h), fill=color, outline=INK)
        d.line([(wx + 2, y + 2), (wx + 2, y + h - 2)], fill=light)


def door(d, cx, base, w=12, h=18, color=DOOR):
    d.rectangle((cx - w // 2, base - h, cx + w // 2, base), fill=color, outline=INK)
    d.point((cx + w // 2 - 3, base - h // 2), fill=YELLOW)


def gable_roof(d, x0, x1, top, base, colors):
    color, dark = colors
    d.polygon([(x0 - 4, base), (x0 + 6, top), (x1 - 6, top), (x1 + 4, base)], fill=color, outline=INK)
    d.line([(x0 - 2, base - 2), (x1 + 2, base - 2)], fill=dark, width=2)
    for y in range(top + 5, base - 2, 5):
        d.line([(x0 + 2, y), (x1 - 2, y)], fill=dark)


def sign(img, cx, y, text, bg=INK, fg=(236, 230, 214)):
    d = ImageDraw.Draw(img)
    w = int(d.textlength(text, font=FONT))
    d.rectangle((cx - w // 2 - 4, y, cx + w // 2 + 3, y + 12), fill=bg, outline=fg if bg == INK else INK)
    d.text((cx - w // 2, y + 1), text, font=FONT, fill=fg)


def shadow(img, x0, y0, x1, y1):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((x0, y0, x1, y1), fill=SHADOW)
    img.alpha_composite(layer)


# ---------- university ----------

def twin_towers():
    """Two copper towers joined by an enclosed glass bridge, with an arc between them."""
    img, d = canvas(220, 250)
    base = 246
    for x0 in (10, 150):
        box(d, (x0, 60, x0 + 60, base), STONE)
        d.rectangle((x0 + 1, base - 30, x0 + 59, base - 1), fill=STONE_SHADE)
        for y in range(76, base - 36, 26):
            windows(d, x0 + 4, x0 + 56, y, 3, 12)
        door(d, x0 + 30, base, 16, 24)
        # copper crown and verdigris cap
        box(d, (x0 - 4, 44, x0 + 64, 62), COPPER)
        d.line([(x0 - 2, 47), (x0 + 62, 47)], fill=COPPER_LIGHT)
        d.polygon([(x0 - 2, 44), (x0 + 30, 6), (x0 + 62, 44)], fill=VERDIGRIS, outline=INK)
        d.line([(x0 + 30, 8), (x0 + 6, 42)], fill=(150, 210, 186))
        d.line([(x0 + 30, 8), (x0 + 54, 42)], fill=VERDIGRIS_DARK)
        # electrode sphere on top
        d.line([(x0 + 30, 6), (x0 + 30, -4 + 6)], fill=INK, width=2)
        d.ellipse((x0 + 23, -2, x0 + 37, 12), fill=COPPER_LIGHT, outline=INK)
    # glass bridge
    box(d, (68, 92, 152, 120), GLASS)
    d.rectangle((69, 93, 151, 98), fill=GLASS_LIGHT)
    for x in range(78, 152, 12):
        d.line([(x, 93), (x, 119)], fill=STEEL_DARK)
    d.line([(68, 120), (152, 120)], fill=COPPER_DARK, width=3)
    # experiment: discharge between the two spheres
    pts = [(40, 5)]
    x = 40
    while x < 176:
        x += rng.randint(10, 18)
        pts.append((min(x, 180), 5 + rng.randint(-9, 7)))
    pts[-1] = (180, 5)
    d.line(pts, fill=SPARK_GLOW, width=4)
    d.line(pts, fill=SPARK, width=2)
    # coils on the bridge roof
    for cx in (92, 128):
        box(d, (cx - 5, 76, cx + 5, 92), COPPER)
        for y in range(79, 91, 3):
            d.line([(cx - 5, y), (cx + 5, y)], fill=COPPER_DARK)
    return img


def old_hall():
    """The old lecture hall: pale stone, columns, a clock."""
    img, d = canvas(220, 132)
    base = 128
    box(d, (6, base - 8, 213, base), STONE_SHADE)
    box(d, (14, 40, 205, base - 8), STONE)
    d.rectangle((15, base - 30, 204, base - 9), fill=STONE_SHADE)
    for cx in range(26, 200, 20):
        d.rectangle((cx - 3, 52, cx + 3, base - 9), fill=WHITE, outline=INK)
    d.polygon([(8, 52), (110, 14), (211, 52)], fill=STONE, outline=INK)
    d.polygon([(30, 48), (110, 22), (189, 48)], fill=STONE_SHADE)
    d.rectangle((8, 50, 211, 56), fill=COPPER, outline=INK)
    # clock
    d.ellipse((98, 24, 122, 48), fill=WHITE, outline=INK, width=2)
    d.line([(110, 36), (110, 28)], fill=INK)
    d.line([(110, 36), (116, 38)], fill=INK)
    door(d, 110, base - 8, 22, 30, WOOD_DARK)
    return img


def glass_lab():
    """A newer laboratory of glass and steel, with pipes back to the old hall."""
    img, d = canvas(170, 120)
    base = 116
    box(d, (6, 30, 164, base), STEEL)
    for x in range(10, 162, 14):
        d.rectangle((x, 36, x + 10, base - 22), fill=GLASS, outline=INK)
        d.line([(x + 2, 38), (x + 2, base - 26)], fill=GLASS_LIGHT)
    d.rectangle((7, base - 18, 163, base - 1), fill=STEEL_DARK)
    door(d, 85, base, 22, 18, GLASS_DARK)
    # roof: sawtooth skylights
    for x in range(6, 160, 26):
        d.polygon([(x, 30), (x + 26, 30), (x + 26, 16)], fill=GLASS_LIGHT, outline=INK)
    # pipes and a small tank
    d.line([(0, 70), (6, 70)], fill=COPPER, width=4)
    box(d, (140, 4, 158, 30), COPPER)
    d.line([(142, 8), (156, 8)], fill=COPPER_LIGHT)
    return img


def observatory():
    img, d = canvas(96, 110)
    base = 106
    box(d, (12, 50, 84, base), STONE)
    d.rectangle((13, base - 18, 83, base - 1), fill=STONE_SHADE)
    windows(d, 16, 80, 64, 3, 12)
    door(d, 48, base, 14, 20)
    d.chord((6, 6, 90, 94), 180, 360, fill=STEEL_LIGHT, outline=INK)
    d.arc((12, 12, 84, 88), 200, 250, fill=WHITE, width=3)
    d.rectangle((44, 6, 52, 50), fill=INK)
    d.line([(48, 18), (70, 0)], fill=COPPER_DARK, width=5)
    d.line([(48, 18), (70, 0)], fill=COPPER, width=3)
    return img


def library():
    img, d = canvas(130, 104)
    base = 100
    box(d, (8, 34, 122, base), (214, 188, 150))
    d.rectangle((9, base - 22, 121, base - 1), fill=(190, 162, 124))
    for cx in range(26, 110, 26):
        d.rectangle((cx - 7, 46, cx + 7, 74), fill=WINDOW, outline=INK)
        d.chord((cx - 7, 40, cx + 7, 54), 180, 360, fill=WINDOW, outline=INK)
    gable_roof(d, 8, 122, 10, 36, ROOFS[1])
    door(d, 65, base, 18, 24, WOOD_DARK)
    return img


def department():
    """The one department the player can enter: applied mechanics, with a test rig outside."""
    img, d = canvas(150, 116)
    base = 112
    box(d, (10, 36, 140, base), (226, 206, 160))
    d.rectangle((11, base - 22, 139, base - 1), fill=(200, 180, 134))
    windows(d, 14, 136, 50, 5, 14)
    gable_roof(d, 10, 140, 8, 38, ROOFS[0])
    door(d, 75, base, 22, 26, WOOD)
    # big gear on the facade
    d.ellipse((60, 10, 90, 40), fill=STEEL, outline=INK)
    for a in range(0, 360, 45):
        x = 75 + 17 * math.cos(math.radians(a))
        y = 25 + 17 * math.sin(math.radians(a))
        d.rectangle((x - 2, y - 2, x + 2, y + 2), fill=STEEL_DARK, outline=INK)
    d.ellipse((70, 20, 80, 30), fill=COPPER, outline=INK)
    return img


def walking_robot():
    img, d = canvas(16, 18)
    box(d, (2, 4, 13, 13), STEEL)
    d.rectangle((4, 6, 11, 9), fill=GLASS)
    box(d, (3, 0, 12, 5), ORANGE)
    d.line([(4, 14), (4, 17)], fill=INK, width=2)
    d.line([(11, 14), (11, 17)], fill=INK, width=2)
    return img


def clock_post():
    img, d = canvas(20, 52)
    d.rectangle((8, 16, 11, 50), fill=COPPER_DARK, outline=INK)
    d.ellipse((1, 0, 18, 17), fill=WHITE, outline=INK, width=2)
    d.line([(9, 8), (9, 3)], fill=INK)
    d.line([(9, 8), (13, 9)], fill=INK)
    return img


def tree(big=False):
    s = 44 if big else 32
    img, d = canvas(s, s + 14)
    d.rectangle((s // 2 - 3, s - 6, s // 2 + 2, s + 12), fill=WOOD, outline=INK)
    d.ellipse((1, 1, s - 2, s - 2), fill=LEAF, outline=INK)
    d.ellipse((5, 4, s - 12, s - 14), fill=LEAF_LIGHT)
    d.arc((2, 2, s - 3, s - 3), 20, 120, fill=LEAF_DARK, width=3)
    return img


def lamp():
    img, d = canvas(10, 36)
    d.rectangle((4, 6, 5, 34), fill=INK)
    box(d, (1, 0, 8, 7), GLASS_LIGHT)
    return img


# ---------- town ----------

def townhouse(w, h, colors, plaster, odd=0):
    """A narrow town house; odd > 0 adds an overhanging upper storey or a tower room."""
    img, d = canvas(w + 12, h + 30)
    base = h + 26
    x0, x1 = 6, w + 6
    top = 30
    if odd == 1:  # upper floor sticks out over the street
        box(d, (x0 + 6, top + 26, x1 - 6, base), plaster)
        box(d, (x0 - 2, top, x1 + 2, top + 28), plaster)
        windows(d, x0 + 2, x1 - 2, top + 8, max(1, w // 22), 10)
    else:
        box(d, (x0, top, x1, base), plaster)
        windows(d, x0 + 2, x1 - 2, top + 8, max(1, w // 22), 10)
    if h > 50:
        windows(d, x0 + 6, x1 - 6, top + 28, max(1, w // 26), 10)
    door(d, (x0 + x1) // 2, base, 12, 18)
    gable_roof(d, x0, x1, 4, top + 2, colors)
    if odd == 2:  # small round tower room on the roof
        d.rectangle((x1 - 22, 0, x1 - 6, 18), fill=plaster, outline=INK)
        d.ellipse((x1 - 24, -6, x1 - 4, 8), fill=COPPER, outline=INK)
        d.rectangle((x1 - 18, 6, x1 - 12, 14), fill=WINDOW, outline=INK)
    return img


def cafe():
    img, d = canvas(120, 92)
    base = 88
    box(d, (6, 22, 114, base), PLASTER[3])
    windows(d, 10, 110, 34, 4, 14)
    door(d, 60, base, 16, 22)
    gable_roof(d, 6, 114, 0, 24, ROOFS[2])
    for i, x in enumerate(range(8, 112, 13)):
        d.polygon([(x, 54), (x + 13, 54), (x + 13, 62), (x, 62)], fill=(214, 70, 70) if i % 2 else WHITE, outline=INK)
    for x in (18, 98):
        d.ellipse((x - 9, 72, x + 9, 80), fill=WHITE, outline=INK)
        d.line([(x, 80), (x, base)], fill=INK)
    return img


def bookshop():
    img, d = canvas(84, 86)
    base = 82
    box(d, (6, 22, 78, base), PLASTER[4])
    d.rectangle((10, 40, 74, 62), fill=WINDOW, outline=INK)
    for x in range(12, 72, 6):
        d.rectangle((x, 52, x + 4, 61), fill=rng.choice(ROOFS)[0], outline=INK)
    door(d, 42, base, 14, 18)
    gable_roof(d, 6, 78, 0, 24, ROOFS[1])
    return img


def fountain():
    img, d = canvas(64, 44)
    d.ellipse((0, 12, 63, 43), fill=STONE_SHADE, outline=INK)
    d.ellipse((5, 16, 58, 38), fill=GLASS)
    d.ellipse((12, 20, 30, 28), fill=GLASS_LIGHT)
    d.rectangle((28, 4, 35, 28), fill=STONE, outline=INK)
    d.ellipse((24, 0, 39, 8), fill=COPPER, outline=INK)
    return img


def market_stall(color):
    img, d = canvas(44, 40)
    d.rectangle((4, 18, 40, 38), fill=WOOD, outline=INK)
    for i, x in enumerate(range(2, 42, 8)):
        d.rectangle((x, 6, x + 8, 18), fill=color if i % 2 else WHITE, outline=INK)
    for x in (8, 18, 28):
        d.ellipse((x, 20, x + 7, 27), fill=rng.choice([(220, 60, 50), (236, 128, 44), (120, 180, 80)]), outline=INK)
    return img


# ---------- port ----------

def ship(size, hull, accent, open_panel=False):
    w, h = size
    img, d = canvas(w, h)
    d.polygon([(w // 2, 2), (w - 8, h // 3), (w - 4, h - 12), (4, h - 12), (8, h // 3)], fill=hull, outline=INK)
    d.polygon([(w // 2, 8), (w - 18, h // 3), (18, h // 3)], fill=GLASS, outline=INK)
    d.line([(w // 2 - 6, 14), (w // 2 - 12, h // 3 - 4)], fill=GLASS_LIGHT, width=2)
    d.rectangle((10, h // 2, w - 10, h // 2 + 6), fill=accent, outline=INK)
    for x in (w // 4, w - w // 4):
        d.rectangle((x - 6, h - 12, x + 6, h - 2), fill=STEEL_DARK, outline=INK)
    if open_panel:
        d.rectangle((w - 30, h // 2 + 12, w - 14, h - 16), fill=INK)
        d.line([(w - 28, h // 2 + 16), (w - 16, h - 18)], fill=COPPER, width=2)
        d.line([(w - 16, h // 2 + 16), (w - 26, h - 18)], fill=YELLOW, width=1)
    return img


def broker_office():
    img, d = canvas(120, 84)
    base = 80
    box(d, (6, 24, 114, base), (226, 222, 210))
    windows(d, 10, 70, 38, 3, 16)
    door(d, 92, base, 18, 24, GLASS_DARK)
    box(d, (2, 16, 118, 26), YELLOW)
    d.text((24, 16), "SHIP BROKER", font=FONT, fill=INK)
    return img


def repair_shed():
    img, d = canvas(140, 96)
    base = 92
    box(d, (6, 26, 134, base), CONCRETE_2)
    d.rectangle((24, 44, 116, base), fill=(58, 54, 66), outline=INK)
    for y in range(48, base, 6):
        d.line([(26, y), (114, y)], fill=(82, 78, 92))
    d.polygon([(0, 28), (70, 0), (140, 28)], fill=STEEL_DARK, outline=INK)
    d.line([(10, 25), (70, 4)], fill=STEEL_LIGHT)
    return img


def passenger_dock():
    img, d = canvas(170, 80)
    base = 76
    box(d, (6, 30, 164, base), STEEL_LIGHT)
    for x in range(14, 160, 20):
        d.rectangle((x, 38, x + 14, 58), fill=GLASS, outline=INK)
    door(d, 85, base, 26, 18, GLASS_DARK)
    d.chord((0, 2, 170, 60), 180, 360, fill=WHITE, outline=INK)
    d.arc((8, 8, 162, 54), 200, 250, fill=GLASS_LIGHT, width=2)
    return img


def cargo(color):
    img, d = canvas(26, 22)
    box(d, (1, 6, 24, 21), color)
    d.line([(1, 10), (24, 10)], fill=INK)
    d.polygon([(1, 6), (6, 1), (24, 1), (24, 6)], fill=tuple(min(255, c + 30) for c in color), outline=INK)
    return img


def crane():
    img, d = canvas(90, 140)
    d.rectangle((10, 20, 18, 138), fill=YELLOW, outline=INK)
    for y in range(26, 136, 10):
        d.line([(11, y), (17, y + 8)], fill=(178, 136, 40))
    d.rectangle((6, 14, 88, 22), fill=YELLOW, outline=INK)
    d.line([(78, 22), (78, 72)], fill=INK)
    box(d, (72, 72, 84, 80), STEEL_DARK)
    return img


# ---------- people ----------

def load_sprite(path):
    try:
        return Image.open(path).convert("RGBA")
    except OSError:
        return None


def npc_pool():
    names = ["board_officer", "civic_engineer", "dock_mechanic", "library_archivist", "market_keeper", "park_artist", "greenhouse_worker", "canal_worker", "police_clerk"]
    return [s for s in (load_sprite(NPCS / f"{n}.png") for n in names) if s is not None]


# ---------- ground ----------

SEA = (74, 140, 186)
SEA_DARK = (58, 116, 162)
SEA_LIGHT = (140, 196, 222)
SAND = (226, 208, 156)
SAND_DARK = (200, 180, 128)
PAD = (118, 122, 130)
SCORCH = (84, 82, 88)
SPACE = (18, 14, 38)
NEBULA = (70, 40, 110)
NEBULA_2 = (40, 70, 120)
STAR_DIM = (150, 146, 190)
CLIFF = (132, 112, 96)
CLIFF_DARK = (96, 80, 70)

TERRACE_SHAPE = [(20, 46), (130, 22), (260, 30), (380, 12), (520, 36), (640, 58), (700, 120), (690, 196),
                 (716, 262), (640, 318), (560, 352), (440, 384), (330, 370), (230, 392), (130, 352), (60, 300), (28, 196)]
# the sea wraps the whole south side; the beach follows it from the southwest
SEA_SHAPE = [(0, 560), (60, 600), (110, 660), (190, 690), (250, 740), (340, 760), (420, 790), (520, 800),
             (620, 816), (700, 812), (740, 824), (1280, 824), (1280, 896), (0, 896)]
SAND_SHAPE = [(0, 470), (70, 500), (140, 560), (230, 590), (300, 640), (380, 668), (470, 700), (580, 712),
              (680, 722), (760, 700), (760, 824), (0, 824)]
# the shipyard quay stands on the shore and ends at the water
PADS = [(780, 668, 50), (990, 662, 44), (1210, 738, 52)]
PLATFORMS = [(730, 866), (910, 868), (1090, 866), (1240, 868)]
PORT_SHAPE = [(700, 566), (800, 530), (930, 540), (1040, 506), (1150, 486), (1280, 470), (1280, 824), (630, 824), (612, 744), (650, 650)]


def wobble(points, amount=9, step=18, seed=0):
    """Resample a polyline every few pixels and push each point sideways a little."""
    r = random.Random(seed)
    out = []
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(length // step))
        nx, ny = -(y1 - y0) / length, (x1 - x0) / length
        for i in range(n):
            t = i / n
            o = r.uniform(-amount, amount)
            out.append((x0 + (x1 - x0) * t + nx * o, y0 + (y1 - y0) * t + ny * o))
    out.append(points[-1])
    return out


def blob(cx, cy, rx, ry, seed, jag=0.22, n=14):
    r = random.Random(seed)
    return [(cx + math.cos(a) * rx * r.uniform(1 - jag, 1 + jag), cy + math.sin(a) * ry * r.uniform(1 - jag, 1 + jag))
            for a in (2 * math.pi * i / n + r.uniform(-0.15, 0.15) for i in range(n))]


# streets: (control points, width); each is wobbled so no two look alike
STREETS = [
    ([(560, 372), (640, 392), (740, 360), (820, 300), (900, 286), (980, 236), (1090, 214), (1170, 150), (1250, 128)], 40),
    ([(820, 300), (842, 380), (872, 452), (930, 520), (948, 580), (1004, 640)], 34),
    ([(640, 392), (600, 452), (520, 488), (440, 520), (360, 560), (300, 616)], 30),
    ([(980, 236), (1010, 320), (1080, 380), (1150, 410), (1230, 470)], 24),
    ([(872, 452), (790, 470), (720, 520), (690, 586)], 20),
    ([(1090, 214), (1060, 150), (1000, 110), (930, 92)], 18),
    ([(520, 488), (500, 560), (440, 620)], 16),
]
SQUARES = [blob(850, 330, 86, 52, 1), blob(1120, 404, 58, 40, 2), blob(420, 548, 64, 40, 3), blob(1000, 112, 50, 30, 4)]


def seg_dist(px, py, a, b):
    (x0, y0), (x1, y1) = a, b
    dx, dy = x1 - x0, y1 - y0
    t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy or 1)))
    return math.hypot(px - x0 - t * dx, py - y0 - t * dy)


def inside(poly, x, y):
    hit = False
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def ground(img):
    d = ImageDraw.Draw(img)
    for ty in range(0, H, TILE):
        for tx in range(0, W, TILE):
            c = GRASS if (tx // TILE * 7 + ty // TILE * 3) % 5 else GRASS_2
            d.rectangle((tx, ty, tx + TILE - 1, ty + TILE - 1), fill=c)
            if rng.random() < 0.14:
                x, y = tx + rng.randint(2, 13), ty + rng.randint(2, 13)
                d.line([(x, y), (x + 1, y - 2)], fill=GRASS_LIGHT)
    # shoreline in the southwest: sand, then water with a ragged edge
    d.polygon(wobble(SAND_SHAPE, amount=6, seed=8), fill=SAND)
    for _ in range(700):
        x, y = rng.randint(0, 760), rng.randint(470, 824)
        if inside(SAND_SHAPE, x, y):
            d.point((x, y), fill=SAND_DARK)
    sea = wobble(SEA_SHAPE[:-2], amount=5, seed=9) + SEA_SHAPE[-2:]
    # the land ends at a cliff and open space with stars lies below it
    d.polygon(sea, fill=SPACE)
    for cx, cy, rx, ry, c in ((180, 860, 160, 40, NEBULA), (560, 880, 120, 30, NEBULA_2), (1000, 880, 200, 24, NEBULA)):
        for k in range(4):
            d.ellipse((cx - rx + k * 20, cy - ry + k * 6, cx + rx - k * 20, cy + ry - k * 6),
                      fill=tuple(int(a + (b - a) * (k + 1) / 6) for a, b in zip(SPACE, c)))
    for i in range(420):
        x, y = rng.randint(0, W), rng.randint(560, 896)
        if inside(sea, x, y - 24):
            if i % 23 == 0:
                d.line([(x - 2, y), (x + 2, y)], fill=WHITE)
                d.line([(x, y - 2), (x, y + 2)], fill=WHITE)
            else:
                d.point((x, y), fill=(WHITE, STAR_DIM, SPARK_GLOW, STAR_DIM)[i % 4])
    face = [(x, y + 22) for x, y in reversed(sea[:-2])]
    d.polygon(sea[:-2] + face, fill=CLIFF)
    for x, y in sea[:-2:2]:
        d.line([(x, y + 4), (x + rng.randint(-3, 3), y + rng.randint(12, 22))], fill=CLIFF_DARK)
    d.line([(x, y + 22) for x, y in sea[:-2]], fill=INK, width=2)
    d.line(sea[:-2], fill=SAND_DARK, width=2)
    # university terrace in the northwest, its retaining wall following the irregular edge
    face = [(x, y + 18) for x, y in TERRACE_SHAPE]
    d.polygon(face, fill=TERRACE_FACE, outline=INK)
    d.polygon(TERRACE_SHAPE, fill=TERRACE, outline=INK)
    for ty in range(0, 400, TILE):
        for tx in range(0, 720, TILE):
            if (tx // TILE + ty // TILE) % 2 and inside(TERRACE_SHAPE, tx + 8, ty + 8):
                d.rectangle((tx, ty, tx + TILE - 1, ty + TILE - 1), fill=TERRACE_2)
    for x, y in TERRACE_SHAPE[7:]:
        for k in range(2, 18, 6):
            d.line([(x - 2, y + k), (x + 2, y + k)], fill=STONE_DARK)
    for poly in (blob(130, 250, 70, 48, 5), blob(560, 220, 54, 40, 6), blob(250, 70, 50, 26, 7)):
        d.polygon(poly, fill=GRASS, outline=STONE_DARK)
    # stairs down to the town, set at an angle
    for i in range(7):
        d.polygon([(520 + i * 6, 350 + i * 5), (600 + i * 6, 340 + i * 5), (602 + i * 6, 345 + i * 5), (522 + i * 6, 355 + i * 5)],
                  fill=STONE if i % 2 else STONE_SHADE, outline=INK)
    # streets and squares
    for i, (points, width) in enumerate(STREETS):
        path = wobble(points, amount=width / 5, seed=20 + i)
        d.line(path, fill=PAVING_DARK, width=width + 6, joint="curve")
        d.line(path, fill=PAVING, width=width, joint="curve")
    for poly in SQUARES:
        d.polygon(poly, fill=PAVING_2, outline=PAVING_DARK)
    for _ in range(900):
        x, y = rng.randint(0, W), rng.randint(60, 700)
        if img.getpixel((x, y))[:3] in (PAVING, PAVING_2):
            d.point((x, y), fill=PAVING_DARK)
    # port apron in the southeast, a short walk out of town
    d.polygon(PORT_SHAPE, fill=CONCRETE)
    for ty in range(464, H, 32):
        for tx in range(608, W, 32):
            if (tx // 32 + ty // 32) % 2 and inside(PORT_SHAPE, tx + 16, ty + 16):
                d.rectangle((tx, ty, tx + 31, ty + 31), fill=CONCRETE_2)
    d.line(PORT_SHAPE + [PORT_SHAPE[0]], fill=INK, width=2)
    for x in range(632, W, 8):
        d.rectangle((x, 822, x + 5, 828), fill=STEEL_DARK, outline=INK)
    # taxi lines between the pads, the bays and the platforms over the cliff
    for line in ([(780, 668), (870, 700), (990, 662), (1090, 690), (1210, 738)],
                 [(870, 700), (900, 790), (910, 860)], [(1090, 690), (1090, 860)], [(1210, 738), (1240, 860)],
                 [(780, 668), (730, 760), (730, 860)]):
        d.line(line, fill=CONCRETE_LINE, width=3, joint="curve")
    # platforms stand out over open space on steel struts
    for cx, cy in PLATFORMS:
        for dx in (-30, 0, 30):
            d.line([(cx + dx, cy + 10), (cx + dx * 0.6, 846)], fill=STEEL_DARK, width=4)
            d.line([(cx + dx, cy + 10), (cx + dx * 0.6, 846)], fill=INK, width=1)
        d.rectangle((cx - 14, 818, cx + 14, cy), fill=CONCRETE, outline=INK)
        landing_pad(d, cx, cy, 48)
    for cx, cy, r in PADS:
        landing_pad(d, cx, cy, r)
    # the arriving ship's shadow on pad 3
    d.ellipse((962, 654, 1018, 670), fill=SCORCH)


def landing_pad(d, cx, cy, r):
    """Round pad seen at an angle: hazard ring, scorch, centre mark and edge lights."""
    ry = r // 2
    d.ellipse((cx - r - 4, cy - ry - 3, cx + r + 4, cy + ry + 3), fill=INK)
    d.ellipse((cx - r, cy - ry, cx + r, cy + ry), fill=YELLOW)
    for i in range(24):
        a0, a1 = 2 * math.pi * i / 24, 2 * math.pi * (i + 0.5) / 24
        d.polygon([(cx + math.cos(a0) * r, cy + math.sin(a0) * ry), (cx + math.cos(a1) * r, cy + math.sin(a1) * ry),
                   (cx + math.cos(a1) * (r - 6), cy + math.sin(a1) * (ry - 3)), (cx + math.cos(a0) * (r - 6), cy + math.sin(a0) * (ry - 3))],
                  fill=INK)
    d.ellipse((cx - r + 7, cy - ry + 4, cx + r - 7, cy + ry - 4), fill=PAD)
    d.ellipse((cx - r // 2, cy - ry // 2, cx + r // 2, cy + ry // 2), fill=SCORCH)
    d.ellipse((cx - r // 3, cy - ry // 3, cx + r // 3, cy + ry // 3), outline=WHITE, width=2)
    d.line([(cx - r // 5, cy), (cx + r // 5, cy)], fill=WHITE, width=2)
    d.line([(cx, cy - ry // 5), (cx, cy + ry // 5)], fill=WHITE, width=2)
    for i in range(8):
        a = 2 * math.pi * i / 8
        x, y = cx + math.cos(a) * (r + 1), cy + math.sin(a) * (ry + 1)
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=(236, 70, 60) if i % 2 else SPARK_GLOW)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


def spaceship(w, h, hull, accent, damaged=False, flying=False):
    """Side view, nose to the right, standing on landing legs."""
    img, d = canvas(w, h)
    P = lambda *pts: [(int(x * w), int(y * h)) for x, y in pts]
    dark = shade(hull, 0.72)
    if not flying:
        for (x0, y0), (x1, y1) in (P((0.26, 0.62), (0.2, 0.96)), P((0.7, 0.6), (0.76, 0.96))):
            d.line([(x0, y0), (x1, y1)], fill=INK, width=3)
            d.line([(x0, y0), (x1, y1)], fill=STEEL_DARK, width=1)
            d.rectangle((x1 - 5, y1 - 1, x1 + 5, y1 + 1), fill=STEEL_DARK, outline=INK)
    d.polygon(P((0.1, 0.3), (0.2, 0.04), (0.34, 0.27)), fill=accent, outline=INK)
    d.polygon(P((0.04, 0.32), (0.3, 0.22), (0.72, 0.22), (0.98, 0.44), (0.74, 0.62), (0.06, 0.64)), fill=hull, outline=INK)
    d.polygon(P((0.06, 0.5), (0.74, 0.5), (0.74, 0.62), (0.06, 0.64)), fill=dark)
    d.line(P((0.08, 0.44), (0.86, 0.44)), fill=accent, width=3)
    d.polygon(P((0.66, 0.25), (0.8, 0.27), (0.94, 0.42), (0.7, 0.4)), fill=GLASS, outline=INK)
    d.line(P((0.7, 0.29), (0.78, 0.36)), fill=GLASS_LIGHT, width=2)
    for i in range(4):
        x, y = int((0.3 + i * 0.08) * w), int(0.33 * h)
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=WINDOW_LIGHT, outline=INK)
    d.polygon(P((0.28, 0.54), (0.56, 0.54), (0.44, 0.78), (0.2, 0.78)), fill=shade(hull, 0.85), outline=INK)
    d.line(P((0.22, 0.76), (0.44, 0.76)), fill=accent, width=2)
    for y in (0.32, 0.48):
        x0, y0 = int(0.0 * w), int(y * h)
        d.rectangle((x0, y0, x0 + 8, y0 + 10), fill=STEEL_DARK, outline=INK)
        if not damaged:
            d.rectangle((x0, y0 + 2, x0 + 2, y0 + 8), fill=SPARK_GLOW)
    if flying:
        for k, c in enumerate((SPARK_GLOW, WHITE)):
            d.polygon([(int(0.36 * w) + k * 4, int(0.64 * h)), (int(0.5 * w) - k * 4, int(0.64 * h)), (int(0.43 * w), h - 1 - k * 8)], fill=c)
    if damaged:
        x0, y0 = int(0.4 * w), int(0.26 * h)
        d.rectangle((x0, y0, x0 + w // 6, y0 + h // 5), fill=INK)
        for k in range(3):
            d.line([(x0 + 2 + k * 4, y0 + 2), (x0 + 6 + k * 3, y0 + h // 5 - 2)], fill=(COPPER, YELLOW, SPARK_GLOW)[k])
        d.line(P((0.12, 0.52), (0.3, 0.6)), fill=SCORCH, width=3)
    return img


def ship_frame(w, h, plate):
    """A hull under construction: keel, ribs and the first few plates."""
    img, d = canvas(w, h)
    d.line([(6, h - 10), (w - 8, h - 10)], fill=STEEL_DARK, width=4)
    for i in range(10):
        x = 10 + i * (w - 24) // 9
        rh = int((h - 16) * (0.55 + 0.45 * math.sin(math.pi * (i + 1) / 11)))
        d.arc((x - 8, h - 10 - rh, x + 8, h - 10 + 4), 180, 360, fill=INK, width=4)
        d.arc((x - 8, h - 10 - rh, x + 8, h - 10 + 4), 180, 360, fill=STEEL_LIGHT, width=2)
        d.line([(x, h - 10 - rh // 2), (x, h - 10)], fill=STEEL_DARK, width=2)
        if i < 5:
            d.rectangle((x - 7, h - 10 - rh // 2, x + 7, h - 12), fill=plate, outline=INK)
    d.line([(10, 18), (w - 14, 24)], fill=STEEL_DARK, width=2)
    for x in (w * 0.3, w * 0.62):
        d.rectangle((int(x) - 6, h - 9, int(x) + 6, h - 1), fill=YELLOW, outline=INK)
    return img


def gantry(sprite, hook=True):
    """Two steel towers with a bridge on top, walkways and welding sparks."""
    w, h = sprite.width + 28, sprite.height + 34
    img, d = canvas(w, h)
    for x in (2, w - 10):
        d.rectangle((x, 6, x + 8, h - 1), fill=YELLOW, outline=INK)
        for y in range(10, h - 4, 10):
            d.line([(x + 1, y), (x + 7, y + 8)], fill=(178, 136, 40))
    d.rectangle((0, 2, w - 1, 10), fill=YELLOW, outline=INK)
    tx = w // 2 + 10
    d.rectangle((tx - 6, 10, tx + 6, 16), fill=STEEL_DARK, outline=INK)
    if hook:
        d.line([(tx, 16), (tx, 30)], fill=INK)
        d.rectangle((tx - 3, 30, tx + 3, 34), fill=STEEL_DARK, outline=INK)
    img.alpha_composite(sprite, (14, h - sprite.height))
    d = ImageDraw.Draw(img)
    y = h - sprite.height // 2 - 6
    d.line([(10, y), (w - 10, y)], fill=STEEL_LIGHT, width=2)
    d.line([(10, y + 3), (w - 10, y + 3)], fill=INK)
    r = random.Random(w * 31 + h)
    for _ in range(4):
        sx, sy = r.randint(20, w - 20), r.randint(h - sprite.height + 6, h - 10)
        d.ellipse((sx - 4, sy - 4, sx + 4, sy + 4), outline=SPARK_GLOW)
        d.point((sx, sy), fill=WHITE)
        for dx, dy in ((2, -3), (-3, -1), (3, 2), (-1, 3), (4, -1)):
            d.point((sx + dx, sy + dy), fill=SPARK)
    return img


def control_tower():
    img, d = canvas(64, 160)
    box(d, (8, 140, 56, 158), CONCRETE_2)
    box(d, (22, 46, 42, 142), STEEL_LIGHT)
    for y in range(56, 140, 16):
        d.line([(23, y), (41, y)], fill=STEEL_DARK)
        d.rectangle((28, y + 4, 36, y + 9), fill=WINDOW, outline=INK)
    d.polygon([(4, 26), (60, 26), (52, 48), (12, 48)], fill=GLASS, outline=INK)
    for x in (16, 26, 38, 48):
        d.line([(x, 27), (x - (x - 32) // 8, 47)], fill=GLASS_DARK)
    d.line([(10, 30), (20, 30)], fill=GLASS_LIGHT, width=2)
    d.polygon([(2, 26), (12, 16), (52, 16), (62, 26)], fill=STEEL_DARK, outline=INK)
    d.line([(32, 16), (32, 2)], fill=INK, width=2)
    d.ellipse((29, 0, 35, 5), fill=(236, 70, 60), outline=INK)
    d.arc((40, 2, 56, 18), 90, 270, fill=STEEL, width=3)
    door(d, 32, 158, 12, 12, GLASS_DARK)
    return img


def fuel_tanks():
    img, d = canvas(84, 60)
    for i, x in enumerate((4, 30, 56)):
        d.rectangle((x, 14, x + 24, 56), fill=WHITE if i != 1 else STEEL_LIGHT, outline=INK)
        d.ellipse((x, 8, x + 24, 20), fill=STEEL_LIGHT, outline=INK)
        d.line([(x + 1, 30), (x + 23, 30)], fill=(236, 70, 60), width=3)
        d.line([(x + 4, 22), (x + 4, 52)], fill=GLASS_LIGHT)
    d.line([(16, 56), (68, 56)], fill=STEEL_DARK, width=3)
    return img


def palm():
    img, d = canvas(40, 56)
    for i in range(10):
        d.rectangle((18 + i // 3, 18 + i * 4, 22 + i // 3, 22 + i * 4), fill=WOOD if i % 2 else WOOD_DARK, outline=INK)
    for dx, dy in ((-18, 6), (18, 6), (-14, -4), (14, -4), (0, -10), (-20, 14), (20, 14)):
        d.line([(20, 18), (20 + dx, 18 + dy)], fill=LEAF_DARK, width=6)
        d.line([(20, 18), (20 + dx, 18 + dy)], fill=LEAF, width=3)
    d.ellipse((16, 14, 24, 22), fill=(122, 92, 64), outline=INK)
    return img


def umbrella(color):
    img, d = canvas(36, 34)
    d.line([(18, 10), (18, 33)], fill=INK, width=2)
    d.pieslice((0, 0, 35, 24), 180, 360, fill=color, outline=INK)
    for x in (6, 18, 30):
        d.line([(18, 1), (x, 12)], fill=WHITE)
    return img


def towel(color):
    img, d = canvas(14, 24)
    d.rectangle((0, 0, 13, 23), fill=color, outline=INK)
    for y in (5, 12, 19):
        d.line([(1, y), (12, y)], fill=WHITE)
    return img


def beach_hut(color):
    img, d = canvas(30, 40)
    box(d, (2, 14, 27, 39), color)
    for x in range(6, 26, 5):
        d.line([(x, 15), (x, 38)], fill=WHITE)
    door(d, 15, 39, 8, 12)
    gable_roof(d, 0, 29, 2, 16, ROOFS[0] if color != ROOFS[0][0] else ROOFS[1])
    return img


def beach_bar():
    img, d = canvas(84, 60)
    box(d, (6, 30, 78, 58), (226, 196, 140))
    d.rectangle((6, 44, 78, 50), fill=WOOD, outline=INK)
    for x in (14, 30, 56, 70):
        d.rectangle((x - 2, 50, x + 2, 58), fill=WOOD_DARK)
    d.polygon([(0, 30), (42, 4), (84, 30)], fill=(214, 186, 96), outline=INK)
    for x in range(6, 80, 6):
        d.line([(x, 30), (42, 6)], fill=(176, 146, 70))
    d.line([(36, 36), (48, 36)], fill=SPARK_GLOW, width=2)
    return img


def lifeguard():
    img, d = canvas(32, 56)
    for x in (6, 24):
        d.line([(x, 56), (x + (6 if x < 16 else -6), 24)], fill=WOOD_DARK, width=3)
    d.rectangle((4, 18, 28, 26), fill=WHITE, outline=INK)
    d.polygon([(2, 18), (16, 2), (30, 18)], fill=(214, 70, 70), outline=INK)
    d.rectangle((24, 2, 30, 6), fill=YELLOW, outline=INK)
    return img


def sandcastle():
    img, d = canvas(24, 18)
    d.rectangle((2, 8, 22, 17), fill=SAND_DARK, outline=INK)
    for x in (2, 10, 18):
        d.rectangle((x, 2, x + 4, 8), fill=SAND_DARK, outline=INK)
    d.line([(12, 0), (12, 4)], fill=INK)
    return img


def under_repair(ship_img):
    """Scaffolding around a hull, with welding sparks."""
    w, h = ship_img.width + 16, ship_img.height + 8
    img, d = canvas(w, h)
    for x in (2, w - 4):
        d.rectangle((x, 6, x + 2, h - 1), fill=STEEL_DARK, outline=INK)
    for y in range(12, h - 4, 14):
        d.line([(2, y), (w - 2, y)], fill=STEEL, width=2)
    img.alpha_composite(ship_img, (8, 8))
    d = ImageDraw.Draw(img)
    for y in range(12, h - 4, 14):
        d.line([(2, y), (10, y)], fill=STEEL, width=2)
        d.line([(w - 10, y), (w - 2, y)], fill=STEEL, width=2)
    r = random.Random(w * h)
    for _ in range(3):
        sx, sy = r.randint(12, w - 12), r.randint(14, h - 14)
        d.point((sx, sy), fill=WHITE)
        for dx, dy in ((2, -2), (-2, -1), (3, 1), (-1, 3)):
            d.point((sx + dx, sy + dy), fill=SPARK)
        d.ellipse((sx - 3, sy - 3, sx + 3, sy + 3), outline=SPARK_GLOW)
    return img


def pier():
    img, d = canvas(30, 90)
    d.rectangle((6, 0, 23, 88), fill=WOOD, outline=INK)
    for y in range(4, 88, 6):
        d.line([(7, y), (22, y)], fill=WOOD_DARK)
    for y in (20, 50, 80):
        d.rectangle((2, y, 6, y + 8), fill=WOOD_DARK, outline=INK)
        d.rectangle((23, y, 27, y + 8), fill=WOOD_DARK, outline=INK)
    return img


def rowboat():
    img, d = canvas(40, 22)
    d.ellipse((4, 18, 36, 22), fill=SPARK_GLOW)
    d.polygon([(0, 10), (36, 6), (40, 12), (36, 18), (4, 17)], fill=STEEL, outline=INK)
    d.ellipse((12, 2, 28, 14), fill=GLASS, outline=INK)
    d.line([(6, 13), (32, 11)], fill=ORANGE)
    return img


def rock(s):
    img, d = canvas(s, s)
    d.polygon([(2, s - 2), (4, s // 3), (s // 2, 2), (s - 3, s // 3), (s - 2, s - 2)], fill=(140, 140, 150), outline=INK)
    d.line([(s // 2, 4), (s // 3, s - 4)], fill=(176, 176, 184))
    return img


def fish_hut():
    img, d = canvas(64, 58)
    box(d, (6, 22, 58, 56), (168, 138, 104))
    for x in range(10, 56, 6):
        d.line([(x, 24), (x, 55)], fill=WOOD_DARK)
    door(d, 32, 56, 12, 16)
    gable_roof(d, 6, 58, 2, 24, ROOFS[3])
    d.line([(58, 30), (64, 40)], fill=INK)
    return img


def garden_wall(w):
    img, d = canvas(w, 10)
    box(d, (0, 2, w - 1, 9), STONE_SHADE)
    for x in range(6, w, 10):
        d.line([(x, 3), (x, 8)], fill=STONE_DARK)
    return img


def build():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    ground(img)
    sprites = []
    taken = []

    def put(sprite, x, bottom, label=None, label_y=None):
        sprites.append((bottom, sprite, x, label, label_y))
        taken.append((x, bottom - sprite.height * 0.55, x + sprite.width, bottom))

    def free(x0, y0, x1, y1):
        for a in taken:
            if x0 < a[2] and x1 > a[0] and y0 < a[3] and y1 > a[1]:
                return False
        return True

    # university, northwest
    put(twin_towers(), 300, 252, "RESISTOR TOWERS", 256)
    put(old_hall(), 50, 168, "OLD LECTURE HALL", 172)
    put(glass_lab(), 80, 328, "HIGH-VOLTAGE LAB", 332)
    put(observatory(), 560, 140, "OBSERVATORY", 144)
    put(library(), 540, 290, "LIBRARY", 294)
    put(department(), 330, 372, "APPLIED MECHANICS (enter)", 358)
    for x, y in ((40, 238), (190, 214), (620, 196), (520, 196), (260, 300), (230, 96), (470, 66)):
        put(tree(rng.random() < 0.4), x, y)
    put(clock_post(), 486, 330)
    put(lamp(), 280, 350)
    put(lamp(), 620, 328)
    put(walking_robot(), 248, 186)
    put(walking_robot(), 600, 352)

    # landmarks in town
    put(cafe(), 740, 296, "CAFE OHM", 300)
    put(bookshop(), 900, 262, "BOOKS", 266)
    put(fountain(), 824, 352)
    for i, (x, y) in enumerate(((1080, 384), (1128, 392), (1166, 430))):
        put(market_stall([(214, 70, 70), (84, 108, 150), (96, 140, 108)][i]), x, y)
    put(clock_post(), 1112, 440)
    put(fountain(), 980, 124)
    # shoreline, southwest
    put(pier(), 300, 850)
    put(pier(), 600, 880)
    put(rowboat(), 250, 820)
    put(rowboat(), 360, 870)
    put(rowboat(), 640, 860)
    put(fish_hut(), 470, 690)
    put(beach_bar(), 180, 590, "BAR KONDENZATOR", 594)
    put(lifeguard(), 400, 740)
    for i, x in enumerate((60, 96, 132)):
        put(beach_hut(ROOFS[i][0]), x, 548 + i * 14)
    for x, y in ((40, 600), (130, 640), (250, 660), (330, 690), (520, 740), (440, 770), (560, 780), (220, 720)):
        put(umbrella(rng.choice([(214, 70, 70), (84, 108, 150), YELLOW, (96, 140, 108)])), x, y)
        put(towel(rng.choice([(214, 70, 70), WHITE, (84, 108, 150), ORANGE])), x + 20, y + 4)
    for x, y in ((10, 500), (110, 530), (230, 610), (300, 600), (440, 660), (560, 690), (20, 540), (360, 650)):
        put(palm(), x, y)
    for x, y, s in ((160, 700, 18), (30, 640, 14), (540, 820, 16)):
        put(rock(s), x, y)
    put(sandcastle(), 470, 770)

    # spaceport, southeast
    put(passenger_dock(), 1110, 556, "PASSENGER TERMINAL", 560)
    put(control_tower(), 1036, 600, "CONTROL", 604)
    put(broker_office(), 850, 600)
    put(fuel_tanks(), 1190, 664)
    put(repair_shed(), 1000, 812, "HANGAR", 722)
    put(spaceship(120, 70, (196, 200, 214), ORANGE), 722, 680, "PAD 1", 690)
    put(spaceship(110, 74, (206, 186, 160), (84, 108, 150), flying=True), 938, 628, "PAD 2", 684)
    put(spaceship(130, 76, (190, 210, 196), COPPER), 1146, 750, "PAD 3", 764)
    put(gantry(ship_frame(150, 64, (196, 200, 214))), 618, 812, "CONSTRUCTION BAY", 816)
    put(gantry(spaceship(120, 70, (214, 180, 172), (96, 140, 108), damaged=True)), 818, 812, "REPAIR GANTRY", 816)
    put(spaceship(70, 44, (180, 196, 214), (214, 70, 70)), 694, 872)
    put(spaceship(80, 48, (220, 210, 180), (96, 140, 108), damaged=True), 870, 874)
    put(spaceship(66, 42, (200, 190, 214), ORANGE, flying=True), 1058, 852)
    put(spaceship(76, 46, (196, 214, 200), (84, 108, 150)), 1202, 874)
    for x, y in ((1150, 812), (1176, 812), (1162, 794), (1250, 600), (960, 760), (986, 760), (790, 620)):
        put(cargo(rng.choice([ORANGE, (84, 108, 150), (96, 140, 108), COPPER])), x, y)
    for x, y in ((800, 780), (966, 700), (1180, 690)):
        put(walking_robot(), x, y)

    # houses: walk each street and drop houses on either side, uneven sizes and gaps
    rng.seed(11)
    paths = [wobble(points, amount=width / 5, seed=20 + i) for i, (points, width) in enumerate(STREETS)]

    def clear_of_streets(x0, x1, y):
        for path, (_, width) in zip(paths, STREETS):
            for a, b in zip(path, path[1:]):
                for px in (x0, (x0 + x1) / 2, x1):
                    if seg_dist(px, y - 6, a, b) < width / 2 + 6:
                        return False
        for poly in SQUARES:
            if inside(poly, (x0 + x1) / 2, y - 6) or inside(poly, x0, y - 4) or inside(poly, x1, y - 4):
                return False
        return True

    for (points, width) in STREETS:
        path = wobble(points, amount=width / 5, seed=99)
        for j in range(len(path)):
            x, y = path[j]
            for side in (-1, 1, -1, 1):
                w = rng.choice([34, 40, 44, 50, 58])
                h = rng.choice([40, 48, 56, 64])
                ox = x + rng.uniform(-24, 24) - w / 2
                bottom = y + side * (width / 2 + rng.uniform(14, 40)) + (h + 30 if side < 0 else 30) * (0.5 if side < 0 else 1)
                x0, x1, top = ox, ox + w + 12, bottom - (h + 30) * 0.55
                if not (0 < x0 and x1 < W and 60 < bottom < 640):
                    continue
                if inside(TERRACE_SHAPE, x0, bottom + 10) or inside(TERRACE_SHAPE, x1, bottom + 10) or inside(TERRACE_SHAPE, (x0 + x1) / 2, top):
                    continue
                if inside(SAND_SHAPE, x0, bottom) or inside(SAND_SHAPE, x1, bottom) or any(inside(PORT_SHAPE, px, py) for px in (x0, x1) for py in (top, bottom)):
                    continue
                if not clear_of_streets(x0, x1, bottom) or not free(x0, top, x1, bottom):
                    continue
                put(townhouse(w, h, rng.choice(ROOFS), rng.choice(PLASTER), rng.choice([0, 0, 1, 2])), ox, bottom)
                if rng.random() < 0.25 and free(x1, bottom - 8, x1 + 30, bottom):
                    put(garden_wall(rng.randint(18, 34)), x1, bottom)

    # trees and lamps fill gaps instead of a grid
    for _ in range(70):
        x, y = rng.randint(10, W - 40), rng.randint(80, 700)
        if inside(TERRACE_SHAPE, x, y) or inside(SAND_SHAPE, x, y + 20) or inside(PORT_SHAPE, x, y) or inside(PORT_SHAPE, x + 30, y):
            continue
        if clear_of_streets(x, x + 30, y) and free(x, y - 30, x + 32, y):
            put(tree(rng.random() < 0.3), x, y)
    for x, y in ((700, 400), (880, 300), (960, 480), (1040, 240), (470, 520), (620, 560)):
        put(lamp(), x, y)
    put(walking_robot(), 860, 400)
    put(walking_robot(), 1180, 170)

    # people
    pool = npc_pool()
    rng.seed(3)
    spots = [(150, 120), (230, 240), (420, 300), (480, 210), (600, 260), (380, 360),
             (800, 330), (860, 360), (760, 380), (1060, 420), (1140, 450), (980, 250), (1150, 190), (920, 470),
             (440, 560), (400, 540), (520, 500), (1010, 140),
             (150, 620), (290, 680), (430, 720), (560, 760), (660, 790), (960, 660), (1060, 640), (860, 760), (1040, 790), (700, 640), (1200, 680)]
    for x, y in spots:
        if pool:
            s = rng.choice(pool)
            put(s, x - s.width // 2, y)
    veki = load_sprite(ROOT / "assets/art/iskra/npcs/veki.png")
    player = load_sprite(ROOT / "assets/art/player_blue.png")
    if veki is not None:
        put(veki, 1230, 600)
    if player is not None:
        put(player, 1250, 602)

    sprites.sort(key=lambda s: s[0])
    for bottom, sprite, x, label, label_y in sprites:
        shadow(img, x + 2, bottom - 4, x + sprite.width - 2, bottom + 4)
        img.alpha_composite(sprite, (int(x), int(bottom - sprite.height)))
    for bottom, sprite, x, label, label_y in sprites:
        if label:
            sign(img, int(x + sprite.width // 2), label_y, label)
    for text, x, y in (("UNIVERSITY", 120, 6), ("TOWN", 1000, 36), ("BEACH", 90, 870), ("SPACEPORT", 1210, 452)):
        sign(img, x, y, text, bg=YELLOW, fg=INK)
    return img


def main():
    img = build().convert("RGB")
    img.save(OUT)
    img.crop((20, 0, 720, 400)).resize((1400, 800), Image.NEAREST).save(UNIVERSITY_OUT)
    img.crop((700, 560, 1280, 896)).resize((1160, 672), Image.NEAREST).save(PORT_OUT)
    for path in (OUT, UNIVERSITY_OUT, PORT_OUT):
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
