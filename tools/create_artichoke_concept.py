#!/usr/bin/python3
"""Render an in-game concept of the Artichoke tundra front from the user's sketch.

The scene is built like a rendered Tiled map: 16-pixel ground tiles, then sprites
sorted by their bottom edge. Existing game sprites are reused where they fit
(warships, barracks, cannons, watchtowers, soldiers, houses). The new
Artichoke pieces (snow ground, cliff, trenches, cleared landing ground, wire, craters,
the Republic wall and
the blue-and-gold New Republic soldiers) are drawn here in the same style: dark
#1c1730 outlines, flat shading and soft shadows.

Writes art/concepts/artichoke_concept.png (whole map, 1x) and
art/concepts/artichoke_concept_detail.png (front line, 1.5x).
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/artichoke_concept.png"
DETAIL_OUT = ROOT / "art/concepts/artichoke_concept_detail.png"
BASE_ART = ROOT / "assets/art/space_military_base"
CONCEPT_ART = ROOT / "art/concepts/source"
NORTH_ART = ROOT / "assets/art/northern_village"

TILE = 16
MAP_W, MAP_H = 96, 84

INK = (28, 23, 48)
SHADOW = (28, 23, 48, 95)
SNOW = (227, 234, 238)
SNOW_2 = (216, 225, 232)
SNOW_SHADE = (197, 210, 221)
SNOW_DEEP = (166, 183, 199)
SPARKLE = (248, 251, 253)
TUNDRA = (128, 143, 116)
TUNDRA_DARK = (98, 115, 94)
TUNDRA_LIGHT = (164, 170, 132)
ROCK = (110, 113, 122)
ROCK_DARK = (78, 80, 92)
ROCK_LIGHT = (146, 150, 160)
ICE = (158, 208, 218)
ICE_DARK = (122, 182, 198)
ICE_LIGHT = (222, 244, 248)
EARTH = (91, 70, 54)
EARTH_DARK = (64, 49, 40)
MUD_ICE = (143, 178, 189)
PATH = (199, 208, 216)
PATH_DARK = (172, 185, 197)
SANDBAG = (183, 154, 97)
SANDBAG_DARK = (138, 114, 69)
WOOD = (107, 74, 51)
WOOD_DARK = (67, 48, 31)
STEEL = (92, 99, 112)
STEEL_LIGHT = (140, 148, 160)
WIRE = (150, 154, 160)
SCORCH = (62, 55, 52)
SCORCH_2 = (88, 80, 74)
EMBER = (224, 138, 60)
GOLD = (245, 195, 76)
GOLD_LIGHT = (255, 224, 138)
NAVY = (39, 58, 104)
REPUBLIC = (78, 116, 199)
REPUBLIC_LIGHT = (138, 174, 232)
STONE = (93, 107, 134)
STONE_DARK = (70, 82, 107)
STONE_LIGHT = (138, 152, 179)
PLAZA = (190, 200, 212)
PLAZA_DARK = (166, 178, 194)
RED_PAINT = (179, 54, 54)


def hexrgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


# --- Map layout, in tile coordinates read off ~/Pictures/plan_for_artichoke.png --

def plateau_edge(x):
    """First lowland row below the Cauliflower Base plateau at tile column x."""
    points = [(0, 25), (18, 25), (30, 22), (46, 22), (56, 19), (66, 15), (80, 13), (96, 12)]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x0 <= x <= x1:
            return round(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
    return points[-1][1]


def south_edge(x):
    """First frozen-sea row along the south of the map."""
    return round(75 + 3 * x / MAP_W + math.sin(x * 0.45) * 0.8)


RAMPS = [range(9, 13), range(50, 54)]


def face_bottom(x):
    """First row below the cliff face; the face also covers the steps where the edge moves."""
    neighbours = [plateau_edge(n) for n in (x - 1, x, x + 1) if 0 <= n < MAP_W]
    return max(neighbours) + CLIFF_ROWS
CLIFF_ROWS = 3

# Diagonal no man's land from the high ground (northeast) to the southwest.
BAND_START = (90, 16)
BAND_END = (4, 52)
BAND_HALF_WIDTH = 6.5

REPUBLIC_WALL = [(69, 50), (75, 49), (87, 51), (92, 58), (95, 66), (88, 74), (62, 75), (56, 69), (60, 57)]
REPUBLIC_GATE = (79, 50)
# Wall rows left open on the west side, toward the Republic airfield.
REPUBLIC_WEST_GATE = range(62, 66)

# Landed warships: (sprite, centre column, bottom row, scale, side). Each one stands
# on ground cleared of snow, with snowbanks around the cleared area.
SHIPS = [
    ("warship_escort", 5.0, 5.6, 1, "confederation"),
    ("warship_scout", 13.0, 5.6, 1, "confederation"),
    ("warship_escort", 23.5, 6.6, 2, "confederation"),
    ("warship_escort", 66.5, 6.0, 1, "confederation"),
    ("warship_escort", 74.5, 6.0, 1, "confederation"),
    ("warship_escort", 40.5, 62.0, 1, "republic"),
    ("warship_escort", 48.5, 62.0, 1, "republic"),
    ("warship_escort", 44.5, 70.0, 1, "republic"),
    # The Republic flagship on the west edge of the airfield; it needs three mines.
    ("warship_flagship", 31.5, 61.5, 1, "republic"),
]


def cleared_tiles():
    """Tiles cleared of snow under and around each landed ship."""
    tiles = set()
    for name, tx, bottom, scale, _ in SHIPS:
        # The flagship is half as wide again as an escort.
        half_width, height = (4.5 if name == "warship_flagship" else 3) * scale, 3.5 * scale
        rows = range(max(0, math.floor(bottom - height * 0.6)), math.ceil(bottom + 1))
        columns = range(math.floor(tx - half_width - 1), math.ceil(tx + half_width + 1))
        for y in rows:
            for x in columns:
                # Leave the corners under snow so the area looks dug out, not drawn with a ruler.
                corner = x in (columns[0], columns[-1]) and y in (rows[0], rows[-1])
                if 0 <= x < MAP_W and not corner:
                    tiles.add((x, y))
    return tiles


TRENCHES = [
    [(13, 11), (30, 10), (46, 11)],
    [(15, 15), (30, 14), (41, 15)],
    [(21, 20), (28, 17), (42, 18)],
    [(47, 19), (58, 12)],
    [(49, 22), (61, 15)],
    [(3, 22), (16, 22)],
    [(7, 57), (25, 55)],
    # Republic forward trench behind the wire west of the occupied village.
    [(62, 38), (74, 37)],
]

PATHS = [
    [(10, 3), (10, 23), (11, 28)],
    [(10, 9), (52, 9), (52, 21)],
    [(52, 21), (55, 26)],
    [(79, 49), (80, 43), (84, 36), (86, 28)],
    [(84, 36), (78, 35)],
    [(44, 64), (52, 64), (60, 64)],
    # From the east stairs to the Arms building and the Mess.
    [(52, 13), (77, 13)],
    [(44, 64), (44, 67)],
]


def band_distance(x, y):
    (x0, y0), (x1, y1) = BAND_START, BAND_END
    dx, dy = x1 - x0, y1 - y0
    t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (x0 + t * dx), y - (y0 + t * dy))


def line_tiles(points):
    tiles = []
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for step in range(steps + 1):
            tile = (round(x0 + (x1 - x0) * step / steps), round(y0 + (y1 - y0) * step / steps))
            if not tiles or tiles[-1] != tile:
                tiles.append(tile)
    return tiles


def inside(polygon, x, y):
    result = False
    for (x0, y0), (x1, y1) in zip(polygon, polygon[1:] + polygon[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            result = not result
    return result


def value_noise(seed, cell):
    rng = random.Random(seed)
    grid = [[rng.random() for _ in range(MAP_W // cell + 3)] for _ in range(MAP_H // cell + 3)]

    def sample(x, y):
        gx, gy = x / cell, y / cell
        ix, iy = int(gx), int(gy)
        fx, fy = gx - ix, gy - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a, b = grid[iy][ix], grid[iy][ix + 1]
        c, d = grid[iy + 1][ix], grid[iy + 1][ix + 1]
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy

    return sample


# --- Ground tiles -----------------------------------------------------------

def speckle(draw, rng, colors, count, size=1):
    for _ in range(count):
        x, y = rng.randrange(0, TILE - size + 1), rng.randrange(0, TILE - size + 1)
        draw.rectangle((x, y, x + size - 1, y + size - 1), fill=rng.choice(colors))


def make_tile(kind, variant):
    rng = random.Random("%s-%d" % (kind, variant))
    image = Image.new("RGBA", (TILE, TILE))
    d = ImageDraw.Draw(image)
    if kind in ("snow", "snow_2", "plateau"):
        d.rectangle((0, 0, 15, 15), fill=SNOW_2 if kind == "snow_2" else SNOW)
        speckle(d, rng, [SPARKLE], 4)
        speckle(d, rng, [SNOW_SHADE], 3)
        if variant % 5 == 0:
            x, y = rng.randrange(1, 10), rng.randrange(3, 14)
            d.line((x, y, x + 4, y), fill=SNOW_SHADE)
            d.line((x + 1, y - 1, x + 3, y - 1), fill=SPARKLE)
        if kind == "plateau" and variant % 4 == 1:
            x, y = rng.randrange(2, 11), rng.randrange(4, 12)
            d.rectangle((x, y, x + 3, y + 2), fill=ROCK)
            d.line((x, y, x + 3, y), fill=SNOW)
            d.line((x, y + 2, x + 3, y + 2), fill=ROCK_DARK)
    elif kind == "snow_tundra":
        d.rectangle((0, 0, 15, 15), fill=SNOW_2)
        speckle(d, rng, [TUNDRA, TUNDRA_DARK, TUNDRA_LIGHT], 9, 2)
        speckle(d, rng, [SPARKLE], 3)
    elif kind == "tundra":
        d.rectangle((0, 0, 15, 15), fill=TUNDRA if variant % 2 else (122, 138, 112))
        speckle(d, rng, [TUNDRA_DARK], 8, 2)
        for _ in range(4):
            x, y = rng.randrange(1, 15), rng.randrange(2, 15)
            d.line((x, y - 1, x, y), fill=TUNDRA_LIGHT)
        speckle(d, rng, [SNOW, SPARKLE], 4)
    elif kind == "rock":
        d.rectangle((0, 0, 15, 15), fill=ROCK)
        speckle(d, rng, [ROCK_DARK], 6, 2)
        speckle(d, rng, [ROCK_LIGHT], 5)
        d.line((0, 0, 15, 0), fill=SNOW_SHADE)
    elif kind in ("cliff_top", "cliff_mid", "cliff_low"):
        # Rock face made of stacked blocks: light top edge, dark lower edge, ink cracks.
        low = kind == "cliff_low"
        d.rectangle((0, 0, 15, 15), fill=INK)
        y = 0
        while y < 16:
            height = rng.randrange(4, 7)
            x = -rng.randrange(0, 6)
            while x < 16:
                width = rng.randrange(5, 10)
                face = ROCK_DARK if low or rng.random() < 0.3 else ROCK
                d.rectangle((x + 1, y + 1, x + width - 1, y + height - 1), fill=face)
                d.line((x + 1, y + 1, x + width - 2, y + 1), fill=ROCK if low else ROCK_LIGHT)
                d.line((x + 1, y + height - 1, x + width - 1, y + height - 1), fill=(60, 60, 74))
                x += width
            y += height
        if kind == "cliff_top":
            # Snow overhang from the plateau above.
            d.rectangle((0, 0, 15, 3), fill=SNOW)
            for x in range(16):
                drip = 4 + (1 if rng.random() < 0.4 else 0) + (1 if rng.random() < 0.15 else 0)
                d.line((x, 3, x, drip), fill=SNOW_SHADE)
                d.point((x, drip + 1), fill=INK)
        elif kind == "cliff_mid" and variant % 3 == 0:
            x = rng.randrange(2, 12)
            d.line((x, 6, x + 3, 6), fill=SNOW)
        if low:
            # Drift piled against the cliff foot.
            for x in range(16):
                height = 2 + int(1.5 * math.sin((x + variant * 5) * 0.7) + 1.5)
                d.line((x, 15 - height, x, 15), fill=SNOW_SHADE)
                d.point((x, 15 - height), fill=SNOW)
    elif kind == "snow_shadow":
        d.rectangle((0, 0, 15, 15), fill=SNOW_SHADE)
        d.rectangle((0, 0, 15, 4), fill=SNOW_DEEP)
        speckle(d, rng, [SNOW_2], 4)
    elif kind == "churned":
        d.rectangle((0, 0, 15, 15), fill=(190, 192, 194) if variant % 2 else (204, 206, 207))
        speckle(d, rng, [SCORCH_2, EARTH, (150, 146, 142)], 6, 2)
        speckle(d, rng, [SCORCH], 3)
        speckle(d, rng, [SNOW], 4)
        if variant % 3 == 1:
            x, y = rng.randrange(1, 9), rng.randrange(3, 13)
            d.line((x, y, x + 6, y - 2), fill=(150, 146, 142))
    elif kind == "path":
        d.rectangle((0, 0, 15, 15), fill=PATH)
        speckle(d, rng, [SNOW_SHADE], 4)
        for _ in range(2):
            x, y = rng.randrange(2, 12), rng.randrange(2, 12)
            d.rectangle((x, y, x + 1, y + 2), fill=PATH_DARK)
            d.rectangle((x + 3, y + 2, x + 4, y + 4), fill=PATH_DARK)
    elif kind == "plaza":
        d.rectangle((0, 0, 15, 15), fill=PLAZA)
        d.line((0, 7, 15, 7), fill=PLAZA_DARK)
        d.line((0, 15, 15, 15), fill=PLAZA_DARK)
        d.line((5 if variant % 2 else 11, 0, 5 if variant % 2 else 11, 7), fill=PLAZA_DARK)
        d.line((8, 8, 8, 15), fill=PLAZA_DARK)
        speckle(d, rng, [SPARKLE], 2)
    elif kind == "ice":
        d.rectangle((0, 0, 15, 15), fill=ICE if variant % 3 else (150, 202, 214))
        for _ in range(2):
            x, y = rng.randrange(0, 12), rng.randrange(0, 15)
            d.line((x, y, x + 3, y), fill=ICE_LIGHT)
        if variant % 4 == 0:
            x = rng.randrange(2, 13)
            d.line((x, 0, x + 2, 6, x + 1, 11, x + 3, 15), fill=ICE_DARK)
    elif kind == "shore":
        d.rectangle((0, 0, 15, 15), fill=ICE)
        for x in range(16):
            height = 3 + int(2 * math.sin((x + variant * 3) * 0.6) + 2)
            d.line((x, 0, x, height), fill=SNOW)
            d.point((x, height + 1), fill=INK)
            d.point((x, height + 2), fill=ICE_DARK)
    return image


def trench_tile(open_sides, variant):
    """Trench floor with dark walls on every side that has no trench neighbour."""
    rng = random.Random("trench-%d" % variant)
    image = Image.new("RGBA", (TILE, TILE), EARTH)
    d = ImageDraw.Draw(image)
    speckle(d, rng, [EARTH_DARK], 6, 2)
    if variant % 3 == 0:
        d.rectangle((5, 7, 10, 9), fill=MUD_ICE)
        d.line((6, 7, 9, 7), fill=ICE_LIGHT)
    for x in range(1, 16, 5):
        d.line((x, 0, x, 15), fill=WOOD_DARK) if "n" in open_sides and "s" in open_sides else None
    if "n" in open_sides:
        d.rectangle((0, 0, 15, 3), fill=EARTH_DARK)
        d.line((0, 0, 15, 0), fill=INK)
    if "s" in open_sides:
        d.rectangle((0, 13, 15, 15), fill=EARTH_DARK)
        d.line((0, 15, 15, 15), fill=INK)
    if "w" in open_sides:
        d.rectangle((0, 0, 1, 15), fill=EARTH_DARK)
        d.line((0, 0, 0, 15), fill=INK)
    if "e" in open_sides:
        d.rectangle((14, 0, 15, 15), fill=EARTH_DARK)
        d.line((15, 0, 15, 15), fill=INK)
    return image


def cleared_tile(open_sides, variant):
    """Frozen gravel scraped clear of snow, with a snowbank on every side that borders snow."""
    rng = random.Random("cleared-%d" % variant)
    image = Image.new("RGBA", (TILE, TILE), (150, 146, 138) if variant % 2 else (142, 139, 132))
    d = ImageDraw.Draw(image)
    speckle(d, rng, [ROCK_DARK, EARTH, (120, 116, 110)], 7, 2)
    speckle(d, rng, [ROCK_LIGHT], 4)
    speckle(d, rng, [SNOW_SHADE], 2)
    if variant % 4 == 1:
        # Skid marks left by landing gear.
        y = rng.randrange(4, 12)
        d.line((0, y, 15, y + 1), fill=(118, 114, 108))
    if "n" in open_sides:
        d.rectangle((0, 0, 15, 3), fill=SNOW)
        d.line((0, 4, 15, 4), fill=SNOW_SHADE)
        d.line((0, 5, 15, 5), fill=(112, 108, 102))
    if "s" in open_sides:
        d.line((0, 11, 15, 11), fill=INK)
        d.rectangle((0, 12, 15, 15), fill=SNOW)
        d.line((0, 12, 15, 12), fill=SPARKLE)
    if "w" in open_sides:
        d.rectangle((0, 0, 2, 15), fill=SNOW)
        d.line((3, 0, 3, 15), fill=SNOW_SHADE)
    if "e" in open_sides:
        d.rectangle((13, 0, 15, 15), fill=SNOW)
        d.line((12, 0, 12, 15), fill=SNOW_SHADE)
    return image


def sandbag_rim():
    """A row of sandbags at the bottom of the tile north of a trench."""
    image = Image.new("RGBA", (TILE, TILE))
    d = ImageDraw.Draw(image)
    for x in (0, 8):
        d.rounded_rectangle((x, 9, x + 7, 15), radius=2, fill=INK)
        d.rounded_rectangle((x + 1, 10, x + 6, 14), radius=1, fill=SANDBAG)
        d.line((x + 2, 10, x + 5, 10), fill=(214, 190, 133))
        d.line((x + 1, 14, x + 6, 14), fill=SANDBAG_DARK)
    d.line((1, 9, 14, 9), fill=SNOW)
    return image


# --- Sprites ----------------------------------------------------------------

def load(path):
    return Image.open(path).convert("RGBA")


def recolor(image, mapping):
    table = {hexrgb(k): hexrgb(v) for k, v in mapping.items()}
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in table:
                pixels[x, y] = table[(r, g, b)] + (a,)
    return out


def snowcap(image, depth=2, top_fraction=0.7):
    """Put snow on the first non-outline pixels seen from above in each column."""
    out = image.copy()
    pixels = out.load()
    limit = int(out.height * top_fraction)
    for x in range(out.width):
        placed = 0
        for y in range(limit):
            r, g, b, a = pixels[x, y]
            if a < 200:
                continue
            if (r, g, b) == INK or (r, g, b) == (23, 22, 45):
                if placed:
                    break
                continue
            pixels[x, y] = (SPARKLE if placed == 0 else SNOW_SHADE) + (255,)
            placed += 1
            if placed >= depth:
                break
    return out


def with_shadow(image, pad=3):
    out = Image.new("RGBA", (image.width, image.height + pad))
    d = ImageDraw.Draw(out)
    d.ellipse((2, image.height - 4, image.width - 3, image.height + pad - 1), fill=SHADOW)
    out.alpha_composite(image)
    return out


CONFED_SOLDIERS = [load(BASE_ART / ("station_soldier_%d.png" % n)) for n in range(1, 7)]
GUARD = load(BASE_ART / "station_guard.png")

def republic_soldier(base, officer=False):
    """Repaint a Confederation soldier in navy and mid blue with gold details.

    The six station soldiers use different greens and khakis, so pixels are sorted
    by colour family instead of exact value. Rows above the collar are skin and
    hair; only a green cap there is repainted.
    """
    image = base.copy()
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if not a or (r, g, b) in (INK, GOLD, (220, 167, 120)):
                continue
            lum = (r * 299 + g * 587 + b * 114) / 255000
            green = g > r and g >= b
            if y < 8:
                if green:
                    pixels[x, y] = NAVY + (a,)
                continue
            if green:
                color = (34, 53, 106) if lum < 0.36 else (43, 63, 120) if lum < 0.5 else (111, 146, 216)
            elif (r, g, b) == (65, 57, 71):
                color = (78, 111, 184)
            elif r > 150 and g > 120 and b < 140:
                color = GOLD
            elif r > g > b and lum < 0.45:
                color = (30, 42, 82)
            else:
                continue
            pixels[x, y] = color + (a,)
    # Gold epaulettes on both shoulders; officers also get a gold collar.
    for x, y in ((4, 9), (11, 9)) + (((5, 10), (10, 10)) if officer else ()):
        if pixels[x, y][3]:
            pixels[x, y] = GOLD + (255,)
    return image


REPUBLIC_SOLDIERS = [republic_soldier(image) for image in CONFED_SOLDIERS] + [republic_soldier(GUARD, officer=True)]

REPUBLIC_BUILDING = {
    "#2e8747": "#2f4f9a", "#58d740": "#5b86e0", "#a5f068": "#f5c34c", "#72d9d7": "#a9c8f5",
}
# Republic warships also get a pale blue-grey hull instead of the green-grey one.
REPUBLIC_SHIP = dict(REPUBLIC_BUILDING, **{"#afc6c4": "#c3cfe3", "#99a5a6": "#97a3bd"})
# Republic cannons: a navy barrel and gold trim in place of the grey-green steel and orange bands.
REPUBLIC_CANNON = {
    "#697b83": "#3f5a9a", "#455562": "#2f4377", "#35434e": "#283a68", "#9aa8a8": "#8fa3cc",
    "#b1bfba": "#a9bce4", "#a5afab": "#9fb0d6", "#9ca9a6": "#93a6cf", "#aab4b2": "#a3b4dc",
    "#e46c40": "#f5c34c", "#e67743": "#ffe08a", "#9d463a": "#b8862e", "#9b4538": "#b8862e",
}


def conifer(variant):
    rng = random.Random("conifer-%d" % variant)
    w, h = 22, 30
    image = Image.new("RGBA", (w, h + 3))
    d = ImageDraw.Draw(image)
    d.ellipse((3, h - 3, w - 4, h + 2), fill=SHADOW)
    d.rectangle((9, h - 7, 12, h - 1), fill=INK)
    d.rectangle((10, h - 7, 11, h - 2), fill=WOOD)
    dark, mid, light = (35, 72, 66), (52, 99, 85), (84, 132, 106)
    for i, (top, half) in enumerate(((1, 5), (8, 8), (15, 10))):
        bottom = top + 10 + (2 if i == 2 else 0)
        d.polygon([(11, top - 1), (11 + half + 1, bottom + 1), (11 - half - 1, bottom + 1)], fill=INK)
        d.polygon([(11, top), (11 + half, bottom), (11 - half, bottom)], fill=mid)
        d.polygon([(11, top), (11 + half, bottom), (13, bottom)], fill=dark)
        d.line((11 - half + 2, bottom - 1, 10, top + 3), fill=light)
        # Snow lying on each layer.
        d.line((11 - half + 1, bottom - 1, 11 - half + 4 + rng.randrange(2), bottom - 2), fill=SPARKLE)
        d.line((11 + half - 4, bottom - 2, 11 + half - 1, bottom - 1), fill=SNOW_SHADE)
        d.point((11, top), fill=SPARKLE)
    return image


def boulder(variant):
    rng = random.Random("boulder-%d" % variant)
    w = 18 + rng.randrange(8)
    h = 12 + rng.randrange(4)
    image = Image.new("RGBA", (w, h + 3))
    d = ImageDraw.Draw(image)
    d.ellipse((1, h - 3, w - 2, h + 2), fill=SHADOW)
    d.rounded_rectangle((1, 2, w - 2, h - 1), radius=5, fill=INK)
    d.rounded_rectangle((2, 3, w - 3, h - 2), radius=4, fill=ROCK)
    d.rounded_rectangle((w // 2, 5, w - 3, h - 2), radius=3, fill=ROCK_DARK)
    d.line((4, 4, w - 6, 3), fill=SNOW)
    d.line((3, 5, w // 2, 4), fill=SNOW_SHADE)
    d.rectangle((4, h - 5, 6, h - 4), fill=(140, 160, 112))
    return image


def barbed_wire():
    w, h = 40, 18
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    for x in (2, 19, 36):
        d.rectangle((x, 3, x + 2, h - 2), fill=INK)
        d.line((x + 1, 4, x + 1, h - 3), fill=WOOD)
        d.point((x + 1, 3), fill=SNOW)
    for x in range(1, w - 3, 5):
        d.ellipse((x, 5, x + 6, 12), outline=WIRE)
        d.point((x + 3, 5), fill=INK)
        d.point((x + 1, 9), fill=STEEL)
    return image


def hedgehog():
    image = Image.new("RGBA", (18, 18))
    d = ImageDraw.Draw(image)
    d.ellipse((2, 13, 15, 17), fill=SHADOW)
    for line in ((2, 3, 15, 15), (15, 3, 2, 15), (9, 1, 9, 15)):
        d.line(line, fill=INK, width=4)
    for line in ((3, 4, 14, 14), (14, 4, 3, 14), (9, 2, 9, 14)):
        d.line(line, fill=STEEL, width=2)
    d.point((3, 4), fill=SNOW)
    d.point((9, 2), fill=SNOW)
    d.point((14, 4), fill=STEEL_LIGHT)
    return image


def crater(size):
    w, h = size, int(size * 0.62)
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    d.ellipse((0, 0, w - 1, h - 1), fill=SNOW_DEEP)
    d.ellipse((2, 2, w - 3, h - 3), fill=SCORCH_2)
    d.ellipse((5, 4, w - 6, h - 4), fill=SCORCH)
    d.ellipse((w // 3, h // 3, w - w // 3, h - h // 3), fill=INK)
    d.arc((5, 4, w - 6, h - 4), 200, 330, fill=(120, 110, 104))
    rng = random.Random(size)
    for _ in range(size // 3):
        angle = rng.random() * math.tau
        x = int(w / 2 + math.cos(angle) * (w / 2 - 2))
        y = int(h / 2 + math.sin(angle) * (h / 2 - 2))
        d.rectangle((x, y, x + 1, y), fill=rng.choice([SCORCH, SCORCH_2, ROCK_DARK]))
    return image


def trap_marker():
    image = Image.new("RGBA", (18, 18))
    d = ImageDraw.Draw(image)
    d.ellipse((1, 9, 16, 16), fill=INK)
    d.ellipse((2, 10, 15, 15), fill=EARTH)
    d.line((4, 11, 13, 14), fill=EARTH_DARK)
    for line in ((4, 2, 13, 12), (13, 2, 4, 12)):
        d.line(line, fill=INK, width=3)
    for line in ((5, 3, 12, 11), (12, 3, 5, 11)):
        d.line(line, fill=RED_PAINT)
    d.point((5, 3), fill=SNOW)
    d.point((12, 3), fill=SNOW)
    return image


def bunker():
    w, h = 34, 28
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    d.ellipse((1, h - 6, w - 2, h - 1), fill=SHADOW)
    d.rectangle((3, 8, w - 4, h - 5), fill=INK)
    d.rectangle((4, 9, w - 5, h - 6), fill=WOOD)
    for y in range(11, h - 6, 4):
        d.line((4, y, w - 5, y), fill=WOOD_DARK)
    d.polygon([(1, 10), (5, 3), (w - 6, 3), (w - 2, 10)], fill=INK)
    d.polygon([(3, 9), (6, 4), (w - 7, 4), (w - 4, 9)], fill=SNOW)
    d.line((4, 9, w - 5, 9), fill=SNOW_SHADE)
    d.rectangle((13, 14, 20, h - 6), fill=INK)
    d.rectangle((14, 15, 19, h - 6), fill=(45, 38, 52))
    for x in (2, 22):
        d.rounded_rectangle((x, h - 10, x + 9, h - 4), radius=2, fill=INK)
        d.rounded_rectangle((x + 1, h - 9, x + 8, h - 5), radius=1, fill=SANDBAG)
        d.line((x + 2, h - 9, x + 7, h - 9), fill=SNOW)
    return image


HOUSE_WALLS = [((214, 201, 165), (176, 163, 132)), ((168, 77, 63), (126, 58, 50)),
               ((78, 131, 207), (58, 98, 156)), ((55, 109, 68), (41, 82, 51))]


def destroyed_house(variant=0):
    """A shelled house: broken walls, fallen beams, rubble and smoke.

    variant picks the wall colour (plaster, copper, blue, green like the northern
    houses), the rubble layout and whether the ruin is mirrored.
    """
    w, h = 66, 60
    wall_color, wall_shade = HOUSE_WALLS[variant % len(HOUSE_WALLS)]
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    d.ellipse((0, h - 10, w - 1, h - 1), fill=(46, 40, 40, 150))
    wall = [(10, h - 8), (10, 26), (16, 22), (20, 28), (27, 17), (31, 24), (36, 20), (40, 30),
            (46, 26), (50, 36), (55, 33), (55, h - 8)]
    d.polygon(wall, fill=INK)
    inner = [(12, h - 10), (12, 28), (16, 25), (20, 31), (27, 20), (31, 27), (36, 23), (40, 33),
             (46, 29), (50, 39), (53, 36), (53, h - 10)]
    d.polygon(inner, fill=wall_color)
    d.polygon([(30, h - 10), (30, 34), (40, 36), (53, 40), (53, h - 10)], fill=wall_shade)
    for x, y in ((16, 32), (36, 38)):
        d.rectangle((x, y, x + 9, y + 10), fill=INK)
        d.rectangle((x + 2, y + 2, x + 7, y + 8), fill=(40, 34, 44))
    d.line((14, 30, 20, 45), fill=SCORCH, width=3)
    d.line((40, 34, 48, 50), fill=SCORCH, width=2)
    # Fallen roof beams and rubble with snow on top.
    d.line((6, 40, 30, 18), fill=INK, width=4)
    d.line((6, 40, 30, 18), fill=WOOD_DARK, width=2)
    d.line((40, 26, 62, 48), fill=INK, width=4)
    d.line((40, 26, 62, 48), fill=WOOD, width=2)
    rng = random.Random(7 + variant)
    for _ in range(22):
        x, y = rng.randrange(2, w - 8), rng.randrange(h - 14, h - 5)
        d.rectangle((x, y, x + 5, y + 3), fill=INK)
        d.rectangle((x + 1, y + 1, x + 4, y + 2), fill=rng.choice([ROCK, ROCK_LIGHT, wall_shade]))
        d.line((x + 1, y, x + 4, y), fill=SNOW)
    d.polygon([(19, 9), (23, 4), (26, 10), (24, 15), (20, 15)], fill=(110, 104, 112, 170))
    d.polygon([(22, 2), (27, 0), (30, 6), (26, 9)], fill=(140, 134, 142, 130))
    if variant % 2:
        image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return snowcap(image, depth=1, top_fraction=0.6)


def banner():
    image = Image.new("RGBA", (14, 30))
    d = ImageDraw.Draw(image)
    d.ellipse((1, 26, 8, 29), fill=SHADOW)
    d.rectangle((2, 1, 4, 28), fill=INK)
    d.line((3, 2, 3, 27), fill=WOOD)
    d.rectangle((4, 2, 13, 15), fill=INK)
    d.rectangle((5, 3, 12, 14), fill=REPUBLIC)
    d.line((5, 3, 12, 3), fill=REPUBLIC_LIGHT)
    d.rectangle((7, 6, 10, 10), fill=GOLD)
    d.point((8, 7), fill=GOLD_LIGHT)
    d.line((5, 14, 12, 14), fill=GOLD)
    d.point((3, 1), fill=GOLD)
    return image


def wall_segment(variant):
    w, h = 16, 30
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    d.rectangle((0, 6, 15, h - 1), fill=INK)
    d.rectangle((0, 8, 15, h - 2), fill=STONE)
    for y in range(12, h - 2, 5):
        d.line((0, y, 15, y), fill=STONE_DARK)
        offset = 4 if (y // 5 + variant) % 2 else 10
        d.line((offset, y + 1, offset, y + 4), fill=STONE_DARK)
    d.rectangle((0, 8, 15, 9), fill=STONE_LIGHT)
    # Battlements with snow.
    for x in (0, 9):
        d.rectangle((x, 1, x + 6, 8), fill=INK)
        d.rectangle((x + 1, 2, x + 5, 8), fill=STONE_LIGHT)
        d.line((x + 1, 2, x + 5, 2), fill=SPARKLE)
    d.line((0, h - 1, 15, h - 1), fill=INK)
    return image


def republic_tower():
    w, h = 36, 64
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    d.ellipse((1, h - 8, w - 2, h - 1), fill=SHADOW)
    d.rectangle((5, 26, w - 6, h - 5), fill=INK)
    d.rectangle((6, 26, w - 7, h - 6), fill=STONE)
    d.rectangle((w // 2 + 3, 26, w - 7, h - 6), fill=STONE_DARK)
    d.rectangle((7, 26, 9, h - 6), fill=STONE_LIGHT)
    for y in range(31, h - 6, 6):
        d.line((6, y, w - 7, y), fill=STONE_DARK)
    d.rectangle((15, 34, 20, 44), fill=INK)
    d.rectangle((16, 35, 19, 43), fill=GOLD)
    d.ellipse((3, 21, w - 4, 30), fill=INK)
    d.ellipse((4, 22, w - 5, 29), fill=STONE_LIGHT)
    d.polygon([(1, 25), (18, 1), (w - 2, 25)], fill=INK)
    d.polygon([(4, 24), (18, 4), (w - 5, 24)], fill=REPUBLIC)
    d.polygon([(18, 4), (w - 5, 24), (22, 24)], fill=NAVY)
    d.line((6, 22, 17, 6), fill=REPUBLIC_LIGHT)
    d.line((5, 24, 14, 24), fill=SNOW)
    d.rectangle((17, 0, 19, 3), fill=GOLD)
    d.line((4, 25, w - 5, 25), fill=GOLD)
    return image


def lookout_flag():
    image = Image.new("RGBA", (16, 30))
    d = ImageDraw.Draw(image)
    d.rectangle((2, 1, 4, 28), fill=INK)
    d.line((3, 2, 3, 27), fill=STEEL_LIGHT)
    d.rectangle((4, 2, 15, 12), fill=INK)
    d.rectangle((5, 3, 14, 11), fill=(79, 123, 58))
    d.rectangle((8, 5, 11, 9), fill=(214, 237, 223))
    return image


def burnt_stump():
    image = Image.new("RGBA", (12, 14))
    d = ImageDraw.Draw(image)
    d.ellipse((0, 10, 11, 13), fill=SHADOW)
    d.rectangle((3, 2, 8, 11), fill=INK)
    d.rectangle((4, 3, 7, 10), fill=SCORCH)
    d.line((4, 3, 7, 3), fill=SNOW)
    d.point((8, 5), fill=INK)
    d.point((9, 4), fill=INK)
    return image


# --- Build the map ----------------------------------------------------------

CRATERS = ((39, 46, 52), (53, 44, 44), (66, 33, 38), (30, 41, 30), (76, 26, 34), (47, 37, 26), (20, 48, 34))
# Feet of the player when arriving on Artichoke, in tiles: beside the flagship.
PLAYER_SPAWN = (19.0, 8.5)
# Republic soldiers guarding the southwest battery: three in its trench, the rest
# between the guns and on the slope north of them.
BATTERY_GARRISON = ((11, 56.9), (16, 56.4), (22, 55.8), (15.8, 54.0), (8.5, 55.8), (27.5, 55.5), (19.0, 50.6), (10.0, 50.8))
SIDES = tuple(zip("nsew", ((0, -1), (0, 1), (1, 0), (-1, 0))))


def ground_grid():
    """Return the ground kind of every tile and the set of trench tiles."""
    tundra_noise = value_noise(11, 7)
    mottle_noise = value_noise(23, 4)
    churn_noise = value_noise(41, 3)
    ground = [["snow"] * MAP_W for _ in range(MAP_H)]
    for y in range(MAP_H):
        for x in range(MAP_W):
            edge = plateau_edge(x)
            south = south_edge(x)
            on_ramp = any(x in ramp for ramp in RAMPS)
            if y >= south:
                ground[y][x] = "shore" if y == south else "ice"
            elif y < edge:
                ground[y][x] = "plateau"
            elif y < face_bottom(x) and not on_ramp:
                ground[y][x] = "cliff_top" if y == edge else "cliff_low" if y == face_bottom(x) - 1 else "cliff_mid"
            elif y == face_bottom(x) and not on_ramp:
                ground[y][x] = "snow_shadow"
            elif band_distance(x, y) < BAND_HALF_WIDTH - 0.5 and churn_noise(x, y) > 0.3:
                ground[y][x] = "churned"
            else:
                value = tundra_noise(x, y)
                if band_distance(x, y) < BAND_HALF_WIDTH + 1:
                    value -= 0.25
                ground[y][x] = "tundra" if value > 0.7 else "snow_tundra" if value > 0.62 else (
                    "snow_2" if mottle_noise(x, y) > 0.58 else "snow")

    for y in range(MAP_H):
        for x in range(MAP_W):
            if ground[y][x] not in ("ice", "shore") and inside(REPUBLIC_WALL, x + 0.5, y + 0.5):
                ground[y][x] = "plaza"
    for points in PATHS:
        for x, y in line_tiles(points):
            for tx in (x, x + 1):
                if 0 <= tx < MAP_W and ground[y][tx] in ("snow", "snow_2", "snow_tundra", "tundra", "plateau"):
                    ground[y][tx] = "path"
    for ramp in RAMPS:
        for x in ramp:
            for y in range(plateau_edge(x), face_bottom(x)):
                ground[y][x] = "path"
    for x, y in cleared_tiles():
        if ground[y][x] not in ("ice", "shore") and not ground[y][x].startswith("cliff"):
            ground[y][x] = "cleared"
    trench = set()
    for points in TRENCHES:
        trench.update(line_tiles(points))
    for x, y in trench:
        ground[y][x] = "trench"
    return ground, trench


def ground_tile(ground, trench, x, y):
    """Return (key, image) for the ground tile at (x, y); equal keys mean equal images."""
    kind = ground[y][x]
    variant = random.Random(x * 1000 + y).randrange(12)
    if kind == "trench":
        sides = "".join(side for side, (dx, dy) in SIDES if (x + dx, y + dy) not in trench)
        return ("trench", sides, variant % 3), lambda: trench_tile(sides, variant % 3)
    if kind == "cleared":
        sides = "".join(side for side, (dx, dy) in SIDES
                        if 0 <= y + dy < MAP_H and 0 <= x + dx < MAP_W and ground[y + dy][x + dx] != "cleared")
        return ("cleared", sides, variant % 4), lambda: cleared_tile(sides, variant % 4)
    return (kind, variant), lambda: make_tile(kind, variant)


def decal_tiles(ground, trench):
    """Sandbag rims and crater pieces, as {(x, y): 16x16 image} drawn over the ground."""
    tiles = {}

    def paste(image, left, top):
        for ty in range(top // TILE, (top + image.height - 1) // TILE + 1):
            for tx in range(left // TILE, (left + image.width - 1) // TILE + 1):
                if not (0 <= tx < MAP_W and 0 <= ty < MAP_H):
                    continue
                tile = tiles.setdefault((tx, ty), Image.new("RGBA", (TILE, TILE)))
                tile.alpha_composite(image.crop((tx * TILE - left, ty * TILE - top, tx * TILE - left + TILE, ty * TILE - top + TILE)))

    rim = sandbag_rim()
    for x, y in sorted(trench):
        if (x, y - 1) not in trench and not ground[y - 1][x].startswith("cliff"):
            paste(rim, x * TILE, (y - 1) * TILE)
    # Craters and scorch marks in no man's land.
    for cx, cy, size in CRATERS:
        decal = crater(size)
        paste(decal, cx * TILE - size // 2, cy * TILE - decal.height // 2)
    return tiles


def layout():
    """Return the ground, trench tiles, decals and objects of the Artichoke map.

    Each object is a dict with the sprite, its name (which decides how the game
    treats it), its top-left pixel position and its bottom row for draw order.
    """
    rng = random.Random(2026)
    tundra_noise = value_noise(11, 7)
    ground, trench = ground_grid()
    objects = []
    occupied = set()

    def place(sprite, tx, ty, name, block=True):
        """Place a sprite with its bottom centre at tile coordinates (tx, ty)."""
        x = round(tx * TILE - sprite.width / 2)
        bottom = round(ty * TILE)
        objects.append({"sprite": sprite, "name": name, "x": x, "bottom": bottom, "index": len(objects)})
        if block:
            for bx in range(int(x // TILE) - 1, int((x + sprite.width) // TILE) + 2):
                for by in range(int((bottom - sprite.height // 2) // TILE) - 1, int(bottom // TILE) + 2):
                    occupied.add((bx, by))

    place(load(CONCEPT_ART / "player.png"), *PLAYER_SPAWN, "player", block=False)

    # Cauliflower Base on the plateau. The large escort is the transport back to the station.
    for name, tx, bottom, scale, side in SHIPS:
        ship = load(BASE_ART / (name + ".png"))
        if side == "republic":
            ship = recolor(ship, REPUBLIC_SHIP)
        if scale != 1:
            ship = ship.resize((ship.width * scale, ship.height * scale), Image.Resampling.NEAREST)
        object_name = "artichoke_ship" if scale != 1 else ("republic_" if side == "republic" else "") + name
        place(ship, tx, bottom, object_name)
    place(snowcap(load(BASE_ART / "headquarters.png")), 36, 7.6, "confederation_headquarters")
    for sprite, tx in ((load(BASE_ART / "barracks_a.png"), 42.5), (load(BASE_ART / "barracks_b.png"), 47.0)):
        place(snowcap(sprite), tx, 7.5, "confederation_barracks")
    cannon = load(BASE_ART / "station_cannon.png")
    for tx in (3.5, 8.0):
        place(snowcap(cannon, depth=1), tx, 10.8, "front_cannon")
    place(load(BASE_ART / "station_tnt_pile.png"), 12.4, 10.4, "front_tnt_pile")
    crate = load(BASE_ART / "munitions_crate.png")
    for tx, ty in ((1.6, 9.0), (50.5, 7.6), (51.8, 7.6)):
        place(snowcap(crate, depth=1), tx, ty, "munitions_crate")
    tower = snowcap(load(BASE_ART / "watchtower.png"), depth=1, top_fraction=0.3)
    for tx, ty in ((24.5, 13.6), (31.0, 9.6), (40.5, 13.6), (55.5, 9.6), (86.5, 9.4)):
        place(tower, tx, ty, "watchtower")
    for tx, ty in ((79, 10.6), (93, 10.2), (61, 8.4), (77, 8.2), (95, 3.0)):
        place(boulder(int(tx)), tx, ty, "boulder")
    confed_flag = lookout_flag()
    place(confed_flag, 89.5, 9.4, "confederation_flag")
    # Houses on the high ground by the lookout, with Confederation flags.
    for name, tx, ty in (("north_house_green.png", 58.5, 6.4), ("north_house_copper.png", 82.5, 5.6),
                         ("north_house_blue.png", 90.5, 6.0)):
        sprite = load(NORTH_ART / name)
        place(snowcap(sprite), tx, ty, "plateau_house")
        place(confed_flag, tx + sprite.width / TILE / 2 + 0.4, ty, "confederation_flag")
    place(snowcap(load(CONCEPT_ART / "cottage_blue.png")), 79.0, 11.0, "plateau_house")
    hut = bunker()
    for tx, ty in ((7.5, 20.8), (13.5, 20.6), (21.5, 13.6), (35.5, 13.3), (31.5, 17.6), (44.5, 16.8), (60.5, 13.4), (56.5, 18.0)):
        place(hut, tx, ty, "bunker")

    # Confederation soldiers in trenches and around the base.
    confed_spots = [(15, 11.6), (22, 10.9), (37, 11.2), (44, 11.5), (19, 15.3), (34, 15.0), (25, 18.6), (38, 18.7),
                    (50, 19.2), (54, 16.4), (57, 18.4), (8, 22.6), (14, 22.7), (10, 26.4), (36, 8.6), (29, 8.8),
                    (5, 11.4), (82.5, 11.2), (85, 10.6), (88, 9.8), (70.5, 7.4), (62.5, 7.2), (86.5, 6.6)]
    for index, (tx, ty) in enumerate(confed_spots):
        place(CONFED_SOLDIERS[index % len(CONFED_SOLDIERS)], tx, ty, "front_soldier", block=False)
    # The officer beside the arrival point gives the trench-raid orders.
    place(GUARD, 16.5, 9.0, "confederation_officer", block=False)
    # The Arms building issues weapons, mines and bandages; the Mess serves hot
    # meals between missions. Both use the training station's buildings.
    place(snowcap(load(BASE_ART / "weapons_storage.png")), 64.5, 12.4, "confederation_arms")
    place(snowcap(load(BASE_ART / "cafeteria.png")), 71.5, 12.4, "confederation_mess")
    place(load(BASE_ART / "station_cook.png"), 75.2, 12.9, "confederation_cook", block=False)

    # No man's land: ruined houses, wire, hedgehogs, booby-trap marks and burnt stumps.
    for variant, (tx, ty) in enumerate(((57.5, 34.2), (66.0, 26.4), (42.0, 36.4), (27.0, 45.4), (15.0, 50.2))):
        place(destroyed_house(variant), tx, ty, "destroyed_house")
    wire = barbed_wire()
    hog = hedgehog()
    for tx, ty in ((48, 33.2), (68, 29.2), (73, 32.3), (57, 40.2), (45, 43.2), (36, 46.3), (8, 45.2), (17, 43.2),
                   (29, 41.2), (26, 49.3), (10, 52.3), (82, 23.2), (63, 37.4), (38, 39.4), (78, 19.8)):
        place(wire, tx, ty, "barbed_wire")
    for tx, ty in ((51, 36.2), (61, 30.4), (70, 25.6), (33, 44.3), (22, 46.4), (11, 47.8), (43, 40.6), (75, 22.3), (55, 47.6)):
        place(hog, tx, ty, "hedgehog")
    marker = trap_marker()
    for tx, ty in ((9, 42.0), (20, 42.0), (44, 33.0), (31, 47.5), (64, 41.5), (71, 28.0)):
        place(marker, tx, ty, "trap_marker")
    stump = burnt_stump()
    for tx, ty in ((35, 39.5), (60, 27.5), (24, 44.6), (49, 48.6), (68, 36.5)):
        place(stump, tx, ty, "burnt_stump")

    # Occupied village east of no man's land.
    village = [(load(NORTH_ART / "north_house_blue.png"), 86.5, 29.2), (load(NORTH_ART / "north_house_copper.png"), 76.5, 34.6),
               (load(NORTH_ART / "north_house_green.png"), 89.0, 35.6), (load(CONCEPT_ART / "cottage_blue.png"), 80.5, 40.6),
               (load(CONCEPT_ART / "cottage_red.png"), 89.5, 41.6)]
    flag = banner()
    for sprite, tx, ty in village:
        place(snowcap(sprite), tx, ty, "village_house")
        place(flag, tx + sprite.width / TILE / 2 + 0.3, ty, "republic_banner")

    # Southwest Republic battery: its two cannons shell Cauliflower Base. The garrison
    # stands in the battery trench and around the guns.
    republic_cannon = snowcap(recolor(cannon, REPUBLIC_CANNON), depth=1)
    for tx in (12.0, 19.5):
        place(republic_cannon, tx, 54.2, "republic_cannon")
    place(load(BASE_ART / "station_tnt_pile.png"), 24.8, 53.6, "republic_tnt_pile")
    place(snowcap(recolor(crate, REPUBLIC_BUILDING), depth=1), 6.2, 54.6, "republic_munitions_crate")
    place(recolor(hut, REPUBLIC_BUILDING), 4.5, 57.2, "republic_bunker")
    for index, (tx, ty) in enumerate(BATTERY_GARRISON):
        place(REPUBLIC_SOLDIERS[index % len(REPUBLIC_SOLDIERS)], tx, ty, "republic_battery_soldier", block=False)

    # Republic base: stone ring wall, round towers, gate and buildings.
    wall_tiles = line_tiles(REPUBLIC_WALL + REPUBLIC_WALL[:1])
    gate_x, gate_y = REPUBLIC_GATE
    for index, (x, y) in enumerate(wall_tiles):
        if y == gate_y and abs(x - gate_x) <= 2 or x < 60 and y in REPUBLIC_WEST_GATE:
            continue
        place(wall_segment(index % 2), x + 0.5, y + 1.0, "republic_wall")
    gate = recolor(load(BASE_ART / "base_gate.png"), REPUBLIC_BUILDING)
    place(snowcap(gate, depth=1), gate_x + 0.5, gate_y + 1.2, "republic_gate")
    rtower = republic_tower()
    for tx, ty in ((69.5, 51.0), (60.5, 58.0), (56.5, 70.0), (64.5, 53.6), (87.5, 52.0), (35.5, 67.0)):
        place(rtower, tx, ty, "republic_tower")
    for name, tx, ty in (("headquarters.png", 77, 61.0), ("barracks_a.png", 68.5, 66.0), ("barracks_b.png", 85.5, 66.5),
                         ("weapons_storage.png", 72.5, 72.8), ("cafeteria.png", 85.0, 72.8), ("barracks_a.png", 64.5, 59.6)):
        place(snowcap(recolor(load(BASE_ART / name), REPUBLIC_BUILDING)), tx, ty, "republic_" + name[:-4])
    for tx, ty in ((83.5, 57.4), (72.5, 57.6), (90.0, 60.6), (56.2, 61.8), (56.2, 65.4)):
        place(flag, tx, ty, "republic_banner")
    republic_spots = [(78, 52.4), (81, 52.6), (75, 58.6), (80, 63.6), (71, 62.6), (88, 62.4), (63, 70.6),
                      (78, 69.4), (83, 47.8), (52, 64.6), (37, 63.4), (50, 70.6), (79, 37.4), (84, 31.4), (91, 38.6), (74, 30.6), (86, 44.3), (66, 52.8)]
    for index, (tx, ty) in enumerate(republic_spots):
        place(REPUBLIC_SOLDIERS[index % len(REPUBLIC_SOLDIERS)], tx, ty, "republic_soldier", block=False)

    # Scatter dwarf conifers and boulders on open ground.
    trees = [snowcap(conifer(n), depth=1) for n in range(3)]
    rocks = [boulder(n) for n in range(4)]
    for _ in range(1400):
        x, y = rng.randrange(1, MAP_W - 1), rng.randrange(1, MAP_H - 1)
        if ground[y][x] not in ("snow", "snow_2", "snow_tundra", "tundra", "plateau") or (x, y) in occupied:
            continue
        # A tree just south of a trench would hide the trench behind its crown.
        if band_distance(x, y) < BAND_HALF_WIDTH + 1 or ground[y + 1][x] in ("trench", "cliff_top", "path", "snow_shadow") or (x, y - 1) in trench:
            continue
        if ground[y][x] == "plateau" and y > 4 and x < 62:
            continue
        roll = rng.random()
        if roll < 0.12 and tundra_noise(x, y) > 0.45:
            place(rng.choice(trees), x + 0.5, y + 1, "tree_conifer")
        elif roll < 0.15:
            place(rng.choice(rocks), x + 0.5, y + 1, "boulder")

    objects.sort(key=lambda item: (item["bottom"], item["index"]))
    return {"ground": ground, "trench": trench, "decals": decal_tiles(ground, trench), "objects": objects}


def render(data, with_player=False):
    """Draw the layout the way the Tiled renderer and the game draw it."""
    ground, trench = data["ground"], data["trench"]
    image = Image.new("RGBA", (MAP_W * TILE, MAP_H * TILE))
    cache = {}
    for y in range(MAP_H):
        for x in range(MAP_W):
            key, make = ground_tile(ground, trench, x, y)
            if key not in cache:
                cache[key] = make()
            image.alpha_composite(cache[key], (x * TILE, y * TILE))
    for (x, y), tile in data["decals"].items():
        image.alpha_composite(tile, (x * TILE, y * TILE))
    for item in data["objects"]:
        if item["name"] != "player" or with_player:
            image.alpha_composite(item["sprite"], (item["x"], item["bottom"] - item["sprite"].height))
    return image


def main():
    image = render(layout())
    image.save(OUT)
    detail = image.crop((34 * TILE, 8 * TILE, 96 * TILE, 46 * TILE))
    detail = detail.resize((detail.width * 3 // 2, detail.height * 3 // 2), Image.Resampling.NEAREST)
    detail.save(DETAIL_OUT)
    print("Saved %s (%dx%d) and %s" % (OUT, image.width, image.height, DETAIL_OUT))


if __name__ == "__main__":
    main()
