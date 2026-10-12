#!/usr/bin/python3
"""Render a night concept of Iskra, the artificial planet and capital of Engineeria.

The scene follows the other concepts: a top-down map with 16-pixel tiles and
sprites sorted by their bottom edge, outlined in dark #1c1730. Iskra is built
on a metal hull in open space, so the city ends at an irregular rim with stars
beyond it. Streets, raised decks and the palace plateau form three levels.

Lights are drawn in the EMISSIVE colors. The render darkens every other pixel
to night, then adds light pools and a glow around emissive pixels, so the
city reads as lit by its automatic lamps.

Writes art/concepts/iskra_concept.png (whole city, 1x) and three 2x close-ups:
iskra_concept_detail.png (palace and decks), iskra_concept_park.png (market,
alley and the disco park) and iskra_concept_dock.png (the cruiser at its dock).
"""

from pathlib import Path
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

from create_iskra_npc_sheet import npc

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/iskra_concept.png"
DETAIL_OUT = ROOT / "art/concepts/iskra_concept_detail.png"
PARK_OUT = ROOT / "art/concepts/iskra_concept_park.png"
DOCK_OUT = ROOT / "art/concepts/iskra_concept_dock.png"
STREETS_OUT = ROOT / "art/concepts/iskra_concept_streets.png"
CANNON_ART = ROOT / "assets/art/space_military_base/station_cannon.png"  # the Artichoke front's cannon

W, H = 2200, 1240       # the city and the cruiser are laid out in these coordinates
MARGIN = 60             # space above the city, for the palace dome and the cranes
CANVAS_H = H + MARGIN

INK = (24, 18, 20)
SHADOW = (10, 8, 8, 125)
VOID = (8, 7, 9)
HULL = (96, 74, 58)
HULL_2 = (76, 58, 46)
HULL_SEAM = (52, 40, 34)
HULL_LIGHT = (132, 100, 66)
RIM = (180, 142, 70)
ASPHALT = (48, 38, 34)
ASPHALT_2 = (38, 30, 28)
SIDEWALK = (142, 108, 72)
DECK = (118, 82, 48)
DECK_2 = (94, 64, 42)
DECK_FACE = (58, 40, 32)
PLATEAU = (154, 112, 58)
PLATEAU_FACE = (78, 52, 34)
STEEL = (168, 176, 196)
STEEL_DARK = (118, 126, 150)
STEEL_LIGHT = (210, 216, 230)
COPPER = (196, 116, 64)
COPPER_DARK = (146, 80, 48)
COPPER_LIGHT = (232, 160, 96)
BRASS = (214, 176, 84)
BRASS_DARK = (160, 124, 52)
NAVY = (54, 92, 168)
NAVY_DARK = (40, 64, 124)
WHITE = (236, 236, 244)
SKIN = (232, 190, 150)
SKIN_2 = (196, 148, 112)
GREEN = (84, 168, 92)
GREEN_DARK = (54, 116, 64)
GREEN_LIGHT = (130, 206, 120)
GLASS = (92, 104, 96)
GLASS_LIGHT = (176, 184, 132)
TVRDIUM = (54, 48, 42)
TVRDIUM_LIGHT = (112, 92, 64)
PUNK_GROUND = (58, 42, 48)
CRANE = (236, 192, 56)
CRANE_DARK = (178, 136, 40)
LANTERN_HOUSE = (84, 58, 66)

# Warm lamps define Iskra's brass-and-steel night palette. Green and cyan stay
# reserved for farms, machinery and Punk Park accents.
LAMP = (255, 190, 72)
LAMP_HOT = (255, 232, 158)
WIN = (255, 174, 58)
WIN_COOL = (255, 220, 132)
NEON_CYAN = (64, 240, 255)
NEON_PINK = (255, 72, 204)
NEON_YELLOW = (255, 236, 72)
NEON_GREEN = (96, 255, 128)
NEON_ORANGE = (255, 146, 44)
NEON_VIOLET = (178, 104, 255)
SIG_RED = (255, 64, 64)
SIG_AMBER = (255, 184, 44)
SIG_GREEN = (64, 255, 128)
ARC = (255, 176, 58)
ARC_CORE = (255, 244, 178)
THRUST = (255, 214, 126)
FIRE = (255, 164, 72)
GROW = (210, 120, 255)
TVRDIUM_VEIN = (84, 255, 222)
STAR = (255, 228, 166)
STAR_DIM = (164, 128, 92)

EMISSIVE = [LAMP, LAMP_HOT, WIN, WIN_COOL, NEON_CYAN, NEON_PINK, NEON_YELLOW, NEON_GREEN,
            NEON_ORANGE, NEON_VIOLET, SIG_RED, SIG_AMBER, SIG_GREEN, ARC, ARC_CORE, THRUST,
            FIRE, GROW, TVRDIUM_VEIN, STAR, STAR_DIM]
NEONS = [NEON_CYAN, NEON_PINK, NEON_YELLOW, NEON_GREEN, NEON_ORANGE, NEON_VIOLET]
SHIP_COLORS = [(200, 84, 70), (90, 170, 130), (220, 186, 80), (110, 140, 210), (180, 120, 180), (168, 176, 196)]

FONT = ImageFont.load_default()


def new(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def sign(img, cx, y, text, bg=INK, fg=LAMP):
    d = ImageDraw.Draw(img)
    w = int(d.textlength(text, font=FONT))
    d.rectangle((cx - w // 2 - 4, y, cx + w // 2 + 3, y + 12), fill=bg, outline=fg)
    d.text((cx - w // 2, y + 1), text, font=FONT, fill=fg)


def lit_windows(d, x0, x1, y, count, rng, h=6, w=5, cool=0.3):
    step = (x1 - x0) / count
    for i in range(count):
        wx = int(x0 + step * i + step / 2) - w // 2
        col = (WIN_COOL if rng.random() < cool else WIN) if rng.random() < 0.85 else INK
        d.rectangle((wx, y, wx + w, y + h), fill=col, outline=INK)


# ---------- people ----------

def person(body, legs=INK, hat=None, hair=None, skin=SKIN, extra=None):
    return npc("dock_mechanic" if hat == CRANE else "board_officer")


def citizen(rng):
    roles = ["sky_courier", "market_keeper", "greenhouse_worker", "civic_engineer", "library_archivist", "canal_worker"]
    role = rng.choice(roles)
    # Preserve the layout generator's random sequence when choosing clothing.
    rng.choice([None, None, COPPER, NAVY])
    return npc(role)


def police():
    return npc("police_clerk")


def soldier():
    return npc("tower_guard")


def punk(rng):
    rng.choice([(40, 36, 52), (90, 30, 60), (30, 30, 30)])
    rng.choice(NEONS[:4])
    return npc("park_artist")


def shady():
    return npc("night_watch")


# ---------- small craft and street furniture ----------

def small_ship(color, facing=1, flying=True, size=1, lights=True):
    w, h = 26 * size, 13 * size
    img, d = new(w + 6, h + 2)
    s = size
    body = [(3, 6 * s), (6 * s, 2 * s), (18 * s, 2 * s), (25 * s, 7 * s), (19 * s, 11 * s), (5 * s, 11 * s)]
    d.polygon(body, fill=color, outline=INK)
    d.line([(6 * s, 9 * s), (19 * s, 9 * s)], fill=tuple(max(0, c - 50) for c in color))
    d.polygon([(11 * s, 2 * s), (13 * s, 0), (19 * s, 0), (22 * s, 4 * s), (14 * s, 4 * s)], fill=WIN_COOL if lights else (40, 44, 60), outline=INK)
    if lights:
        d.rectangle((22 * s, 6 * s, 24 * s, 7 * s), fill=LAMP_HOT)
    if flying:
        d.polygon([(0, 5 * s), (3, 4 * s), (3, 9 * s), (0, 8 * s)], fill=THRUST)
    else:
        d.line([(6 * s, 12 * s), (8 * s, h + 1)], fill=INK)
        d.line([(18 * s, 12 * s), (16 * s, h + 1)], fill=INK)
    return img if facing > 0 else img.transpose(Image.FLIP_LEFT_RIGHT)


def street_lamp(color=LAMP, broken=False):
    img, d = new(12, 34)
    d.rectangle((5, 8, 6, 33), fill=STEEL_DARK, outline=None)
    d.line([(5, 8), (5, 33)], fill=INK)
    d.rectangle((2, 3, 9, 8), fill=(INK if broken else color), outline=INK)
    d.rectangle((3, 0, 8, 3), fill=STEEL, outline=INK)
    return img


def semaphore(lit):
    img, d = new(10, 30)
    d.rectangle((4, 14, 5, 29), fill=STEEL_DARK)
    d.rectangle((1, 0, 8, 15), fill=(36, 36, 48), outline=INK)
    for i, col in enumerate((SIG_RED, SIG_AMBER, SIG_GREEN)):
        d.ellipse((3, 2 + i * 4, 6, 5 + i * 4), fill=col if i == lit else (60, 56, 64))
    return img


def sky_buoy(color):
    """Floating light that marks a ship lane, the semaphore of the air."""
    img, d = new(16, 16)
    d.ellipse((1, 1, 15, 15), outline=INK, fill=(48, 50, 70))
    d.ellipse((4, 4, 12, 12), fill=color)
    return img


# ---------- engineers' houses ----------

def gear_house(rng, color=COPPER, dark=COPPER_DARK):
    """A round house with cog teeth around its wall."""
    img, d = new(66, 62)
    cx, cy, r = 33, 32, 24
    for k in range(12):
        a = math.radians(k * 30)
        x, y = cx + (r + 3) * math.cos(a), cy + (r + 3) * math.sin(a) * 0.8
        d.rectangle((x - 4, y - 4, x + 4, y + 4), fill=dark, outline=INK)
    d.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), fill=color, outline=INK)
    d.ellipse((cx - 10, cy - 14, cx + 10, cy + 2), fill=STEEL, outline=INK)
    d.ellipse((cx - 4, cy - 9, cx + 4, cy - 3), fill=WIN, outline=INK)
    lit_windows(d, cx - 20, cx + 20, cy + 4, 3, rng)
    d.rectangle((cx - 4, cy + 12, cx + 4, cy + 20), fill=INK)
    d.rectangle((cx + 12, 0, cx + 16, 14), fill=STEEL_DARK, outline=INK)
    return img


def bulb_house(rng):
    """A giant light bulb: glass globe, glowing filament rooms, screw base."""
    img, d = new(50, 78)
    d.ellipse((3, 2, 47, 46), fill=GLASS, outline=INK)
    d.arc((7, 6, 43, 42), 190, 250, fill=GLASS_LIGHT, width=3)
    d.line([(17, 44), (17, 30), (21, 22), (25, 30), (29, 22), (33, 30), (33, 44)], fill=LAMP_HOT, width=2)
    d.ellipse((19, 12, 31, 20), fill=WIN, outline=INK)
    for i in range(4):
        d.rectangle((13 + i, 46 + i * 6, 37 - i, 51 + i * 6), fill=(BRASS, BRASS_DARK)[i % 2], outline=INK)
    d.rectangle((21, 70, 29, 77), fill=INK)
    return img


def coil_tower(rng):
    """Apartments wound with copper like a coil, an antenna light on top."""
    img, d = new(44, 124)
    d.rectangle((8, 20, 36, 120), fill=STEEL_DARK, outline=INK)
    for y in range(24, 116, 6):
        d.line([(8, y), (36, y + 3)], fill=COPPER, width=2)
    for y in range(30, 110, 16):
        lit_windows(d, 10, 34, y, 2, rng, h=5)
    d.ellipse((4, 12, 40, 26), fill=STEEL, outline=INK)
    d.line([(22, 12), (22, 0)], fill=INK, width=2)
    d.rectangle((20, 0, 24, 3), fill=SIG_RED)
    d.rectangle((18, 108, 26, 120), fill=INK)
    return img


def capacitor_stack(rng, colors):
    """Apartment block of stacked capacitor drums with colored bands."""
    img, d = new(60, 104)
    y = 100
    for i, col in enumerate(colors):
        top = y - 26
        d.rectangle((6, top + 4, 54, y), fill=col, outline=INK)
        d.ellipse((6, top, 54, top + 9), fill=STEEL_LIGHT, outline=INK)
        d.rectangle((6, y - 8, 54, y - 5), fill=STEEL_DARK)
        lit_windows(d, 8, 52, top + 11, 4, rng, h=5)
        y = top + 4
    d.line([(30, y - 4), (30, y - 14)], fill=INK, width=2)
    d.line([(20, y - 4), (20, y - 10)], fill=INK, width=2)
    d.rectangle((26, 92, 34, 100), fill=INK)
    return img


def tube_house(rng):
    """A vacuum tube with its glowing grid as the upper floor."""
    img, d = new(42, 86)
    d.rounded_rectangle((5, 2, 37, 64), 14, fill=GLASS, outline=INK)
    for y in range(14, 50, 7):
        d.line([(12, y), (30, y)], fill=FIRE)
    d.rectangle((14, 12, 28, 52), outline=FIRE)
    d.rectangle((3, 62, 39, 74), fill=(40, 40, 52), outline=INK)
    for x in (9, 17, 25, 33):
        d.line([(x, 74), (x, 84)], fill=STEEL, width=2)
    d.rectangle((17, 64, 25, 74), fill=WIN, outline=INK)
    return img


def piston_house(rng, color):
    """A house lifted on three hydraulic pistons, with a ladder."""
    img, d = new(68, 92)
    for x in (12, 32, 52):
        d.rectangle((x - 3, 50, x + 3, 88), fill=STEEL_LIGHT, outline=INK)
        d.rectangle((x - 5, 66, x + 5, 88), fill=STEEL_DARK, outline=INK)
    d.rectangle((4, 18, 64, 52), fill=color, outline=INK)
    d.polygon([(0, 20), (34, 2), (68, 20)], fill=STEEL, outline=INK)
    lit_windows(d, 8, 60, 26, 4, rng, h=8, w=7)
    for x in (24, 30):
        d.line([(x, 52), (x, 90)], fill=BRASS)
    for y in range(56, 90, 5):
        d.line([(24, y), (30, y)], fill=BRASS)
    return img


def dish_dome(rng):
    """Observatory dome with a radio dish."""
    img, d = new(76, 66)
    d.pieslice((4, 18, 72, 86), 180, 360, fill=STEEL, outline=INK)
    d.rectangle((4, 52, 72, 64), fill=STEEL_DARK, outline=INK)
    d.arc((10, 22, 66, 82), 200, 250, fill=STEEL_LIGHT, width=3)
    lit_windows(d, 8, 68, 55, 5, rng, h=5)
    d.line([(52, 24), (60, 8)], fill=INK, width=2)
    d.chord((46, -2, 76, 22), 120, 300, fill=WHITE, outline=INK)
    d.rectangle((60, 2, 63, 5), fill=SIG_RED)
    return img


def gyro_house(rng):
    """A round cabin hung inside a tilted gyroscope ring."""
    img, d = new(70, 86)
    d.rectangle((32, 70, 38, 84), fill=STEEL_DARK, outline=INK)
    d.ellipse((20, 78, 50, 86), fill=STEEL, outline=INK)
    d.ellipse((4, 6, 66, 76), outline=BRASS, width=4)
    d.ellipse((4, 6, 66, 76), outline=INK)
    cabin = rng.choice(HOUSE_COLORS)
    d.ellipse((14, 26, 56, 60), fill=cabin, outline=INK)
    d.arc((18, 28, 52, 58), 190, 260, fill=_darker(cabin, -40), width=3)
    d.ellipse((22, 34, 32, 42), fill=WIN, outline=INK)
    d.ellipse((38, 34, 48, 42), fill=WIN_COOL, outline=INK)
    d.line([(10, 60), (60, 22)], fill=BRASS_DARK, width=3)
    return img


def nut_house(rng, color):
    """A hexagonal house like a giant nut, with the bolt as its chimney."""
    img, d = new(60, 58)
    pts = [(30 + 26 * math.cos(math.radians(a)), 32 + 20 * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    d.polygon(pts, fill=color, outline=INK)
    d.ellipse((20, 24, 40, 40), fill=STEEL_DARK, outline=INK)
    d.rectangle((26, 4, 34, 30), fill=STEEL_LIGHT, outline=INK)
    for y in range(8, 28, 4):
        d.line([(26, y), (34, y + 2)], fill=STEEL_DARK)
    lit_windows(d, 10, 50, 40, 3, rng, h=5)
    return img


def pad(color=LAMP):
    """A small round landing pad for personal ships."""
    img, d = new(40, 22)
    d.ellipse((1, 1, 39, 21), fill=(70, 74, 98), outline=INK)
    d.ellipse((6, 4, 34, 18), outline=color)
    d.text((17, 5), "H", font=FONT, fill=WHITE)
    return img


# ---------- ordinary houses that fill the blocks ----------

HOUSE_COLORS = [(122, 112, 140), (140, 104, 96), (104, 120, 140), (120, 128, 104), (150, 130, 104),
                (96, 104, 128), (136, 116, 128), (112, 96, 88), (128, 136, 150), (146, 116, 84)]
ROOF_COLORS = [(150, 156, 176), (128, 116, 120), (112, 124, 120), (140, 120, 100)]


def _darker(color, amount=30):
    return tuple(max(0, c - amount) for c in color)


def roof_clutter(img, x0, x1, roof_y, rng, ships=True):
    """Things on a flat roof: water tanks, vent fans, antennas, a dish, a rooftop
    greenhouse of the automated farms, or a personal ship parked on its pad."""
    d = ImageDraw.Draw(img)
    x = x0 + rng.randint(1, 4)
    while x < x1 - 10:
        kind = rng.choice(["tank", "vent", "antenna", "dish", "greenhouse", "ship", "none", "vent"])
        if kind == "ship" and (not ships or x1 - x < 34):
            kind = "vent"
        if kind == "greenhouse" and x1 - x < 24:
            kind = "antenna"
        if kind == "tank":
            d.rectangle((x, roof_y - 12, x + 9, roof_y - 1), fill=(150, 120, 96), outline=INK)
            d.ellipse((x, roof_y - 15, x + 9, roof_y - 9), fill=(170, 140, 110), outline=INK)
            x += 13
        elif kind == "vent":
            d.rectangle((x, roof_y - 7, x + 8, roof_y - 1), fill=STEEL_DARK, outline=INK)
            d.line([(x + 2, roof_y - 4), (x + 6, roof_y - 4)], fill=INK)
            x += 11
        elif kind == "antenna":
            d.line([(x + 2, roof_y - 1), (x + 2, roof_y - 20)], fill=INK)
            d.line([(x - 1, roof_y - 16), (x + 5, roof_y - 16)], fill=INK)
            x += 7
        elif kind == "dish":
            d.chord((x, roof_y - 12, x + 12, roof_y - 2), 120, 300, fill=STEEL_LIGHT, outline=INK)
            d.line([(x + 6, roof_y - 4), (x + 6, roof_y - 1)], fill=INK)
            x += 15
        elif kind == "greenhouse":
            d.pieslice((x, roof_y - 14, x + 22, roof_y + 10), 180, 360, fill=GLASS, outline=INK)
            for gx in range(x + 4, x + 20, 5):
                d.line([(gx, roof_y - 1), (gx, roof_y - 5)], fill=GREEN_LIGHT, width=2)
            d.line([(x + 6, roof_y - 9), (x + 16, roof_y - 9)], fill=LAMP_HOT)
            x += 25
        elif kind == "ship":
            ship = small_ship(rng.choice(SHIP_COLORS), rng.choice((1, -1)), flying=False)
            img.alpha_composite(ship, (x, roof_y - ship.height))
            x += ship.width + 2
        else:
            x += 8


def tenement(rng, width=None, floors=None):
    """A block of flats in riveted plate: a pipe down the front, lit windows and a
    flat roof crowded with tanks, vents and antennas."""
    w = width or rng.choice((40, 48, 56, 64, 72))
    floors = floors or rng.choice((2, 3, 3, 4, 4, 5))
    roof_depth, headroom = 10, 20
    h = headroom + roof_depth + floors * 16 + 4
    img, d = new(w, h)
    body = rng.choice(HOUSE_COLORS)
    face_top = headroom + roof_depth
    d.rectangle((0, headroom, w - 1, face_top), fill=rng.choice(ROOF_COLORS), outline=INK)
    d.rectangle((0, face_top, w - 1, h - 1), fill=body, outline=INK)
    d.line([(1, face_top + 1), (w - 2, face_top + 1)], fill=_darker(body, -24))
    for f in range(floors):
        y = face_top + 5 + f * 16
        lit_windows(d, 3, w - 4, y, max(2, (w - 6) // 11), rng, h=7, w=5, cool=0.25)
        d.line([(1, y + 11), (w - 2, y + 11)], fill=_darker(body))
    cx = rng.randrange(10, w - 9)
    d.rectangle((cx - 4, h - 12, cx + 4, h - 1), fill=INK)
    d.rectangle((cx - 1, h - 15, cx + 1, h - 14), fill=LAMP)
    px = rng.choice((3, w - 5))
    d.line([(px, face_top + 2), (px, h - 2)], fill=COPPER, width=2)
    roof_clutter(img, 2, w - 2, headroom + roof_depth - 2, rng)
    return img


def row_house(rng):
    """A narrow two-floor house under a ribbed metal gable, with a gear cowl on its chimney."""
    w = rng.choice((30, 34, 38))
    img, d = new(w, 70)
    body = rng.choice(HOUSE_COLORS)
    d.rectangle((1, 30, w - 2, 69), fill=body, outline=INK)
    roof = rng.choice(ROOF_COLORS)
    d.polygon([(0, 32), (w // 2, 12), (w - 1, 32)], fill=roof, outline=INK)
    for x in range(4, w - 3, 4):
        d.line([(x, 31), (w // 2 + (x - w // 2) // 3, 16)], fill=_darker(roof, 20))
    d.ellipse((w // 2 - 4, 20, w // 2 + 4, 28), fill=WIN if rng.random() < 0.7 else INK, outline=INK)
    lit_windows(d, 3, w - 4, 38, 2, rng, h=8, w=6)
    d.rectangle((w // 2 - 4, 54, w // 2 + 4, 69), fill=INK)
    cx = w - 9
    d.rectangle((cx, 6, cx + 5, 22), fill=(120, 84, 70), outline=INK)
    for k in range(6):
        a = math.radians(k * 60)
        d.point((cx + 2 + 4 * math.cos(a), 4 + 3 * math.sin(a)), fill=STEEL_DARK)
    d.ellipse((cx, 1, cx + 5, 6), outline=INK)
    return img


def boiler_house(rng):
    """A low house heated by a riveted boiler drum, with its smokestack."""
    w = rng.choice((60, 68))
    img, d = new(w, 74)
    body = rng.choice(HOUSE_COLORS)
    d.rectangle((1, 38, w - 24, 73), fill=body, outline=INK)
    d.rectangle((1, 30, w - 24, 38), fill=rng.choice(ROOF_COLORS), outline=INK)
    lit_windows(d, 4, w - 28, 46, 2, rng, h=8, w=6)
    d.rectangle((10, 60, 18, 73), fill=INK)
    d.rounded_rectangle((w - 26, 34, w - 2, 73), 10, fill=COPPER_DARK, outline=INK)
    for y in range(40, 72, 6):
        d.line([(w - 24, y), (w - 4, y)], fill=COPPER)
    d.ellipse((w - 18, 48, w - 10, 56), fill=FIRE, outline=INK)
    d.rectangle((w - 18, 4, w - 11, 34), fill=(90, 84, 92), outline=INK)
    d.rectangle((w - 19, 4, w - 10, 8), fill=(70, 66, 74), outline=INK)
    roof_clutter(img, 3, w - 30, 30, rng, ships=False)
    return img


def dome_flat(rng):
    """A dome of riveted plate with round portholes on two floors."""
    img, d = new(52, 58)
    color = rng.choice(HOUSE_COLORS)
    d.pieslice((2, 6, 50, 102), 180, 360, fill=color, outline=INK)
    d.rectangle((2, 52, 50, 57), fill=_darker(color), outline=INK)
    d.arc((8, 12, 44, 96), 200, 250, fill=_darker(color, -30), width=2)
    for x, y in ((14, 28), (26, 22), (38, 28), (14, 42), (38, 42)):
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=WIN if rng.random() < 0.75 else INK, outline=INK)
    d.rectangle((22, 40, 30, 54), fill=INK)
    d.line([(26, 6), (26, 0)], fill=INK)
    return img


def container_stack(rng):
    """Shipping containers stacked into homes, doors cut out as windows."""
    img, d = new(58, 74)
    y = 72
    for i in range(rng.choice((2, 3))):
        col = rng.choice([(150, 80, 64), (70, 110, 140), (140, 130, 70), (90, 120, 90), (120, 90, 130)])
        off = rng.choice((0, 4, 8)) if i else 2
        d.rectangle((off, y - 20, off + 48, y), fill=col, outline=INK)
        for x in range(off + 3, off + 47, 4):
            d.line([(x, y - 18), (x, y - 2)], fill=_darker(col, 20))
        lit_windows(d, off + 6, off + 44, y - 15, 3, rng, h=8, w=7)
        y -= 21
    d.line([(52, 72), (52, y + 21)], fill=BRASS)
    for yy in range(y + 24, 72, 4):
        d.line([(50, yy), (55, yy)], fill=BRASS)
    return img


def front_yard(rng, w):
    """The strip between a house and the footpath: a low fence, a planter or a bench."""
    img, d = new(w, 10)
    kind = rng.choice(["fence", "planter", "bench", "fence", "none"])
    if kind == "fence":
        d.line([(0, 7), (w - 1, 7)], fill=STEEL_DARK)
        for x in range(0, w, 4):
            d.line([(x, 3), (x, 8)], fill=STEEL_DARK)
    elif kind == "planter":
        for x in range(2, w - 8, 12):
            d.rectangle((x, 4, x + 8, 9), fill=(110, 90, 80), outline=INK)
            d.ellipse((x, 0, x + 8, 6), fill=GREEN, outline=INK)
    elif kind == "bench":
        d.rectangle((w // 2 - 7, 4, w // 2 + 7, 7), fill=(130, 100, 70), outline=INK)
    return img


ORDINARY_HOUSES = ["tenement"] * 7 + ["row_house"] * 3 + ["boiler_house", "dome_flat", "container_stack",
                   "gear_house", "nut_house", "tube_house", "bulb_house", "capacitor_stack", "coil_tower",
                   "piston_house", "gyro_house", "dish_dome"]


def tenement_fit(rng, width, max_h):
    """A tenement exactly `width` wide with as many floors as fit under max_h, or None."""
    floors = [f for f in (1, 2, 3, 3, 4, 4, 5) if 34 + 16 * f <= max_h]
    if width < 30 or not floors:
        return None
    return tenement(rng, width, rng.choice(floors[1:] or floors))


def ordinary_house(rng, max_w, max_h=999):
    """Picks a random house that fits in max_w by max_h pixels, or None."""
    for _ in range(8):
        kind = rng.choice(ORDINARY_HOUSES)
        if kind == "tenement":
            img = tenement_fit(rng, rng.choice([x for x in (40, 48, 56, 64, 72) if x <= max_w] or [0]), max_h)
        elif kind == "row_house":
            img = row_house(rng)
        elif kind == "boiler_house":
            img = boiler_house(rng)
        elif kind == "dome_flat":
            img = dome_flat(rng)
        elif kind == "container_stack":
            img = container_stack(rng)
        elif kind == "gear_house":
            col = rng.choice(HOUSE_COLORS)
            img = gear_house(rng, col, _darker(col))
        elif kind == "nut_house":
            img = nut_house(rng, rng.choice(HOUSE_COLORS))
        elif kind == "tube_house":
            img = tube_house(rng)
        elif kind == "bulb_house":
            img = bulb_house(rng)
        elif kind == "capacitor_stack":
            img = capacitor_stack(rng, [rng.choice(HOUSE_COLORS) for _ in range(rng.choice((2, 3)))])
        elif kind == "coil_tower":
            img = coil_tower(rng)
        elif kind == "piston_house":
            img = piston_house(rng, rng.choice(HOUSE_COLORS))
        elif kind == "gyro_house":
            img = gyro_house(rng)
        else:
            img = dish_dome(rng)
        if img is not None and img.width <= max_w and img.height <= max_h:
            return img
    return None


# ---------- landmarks ----------

def jagged(d, a, b, rng, color=ARC, steps=6, spread=6):
    pts = [a]
    for i in range(1, steps):
        t = i / steps
        pts.append((a[0] + (b[0] - a[0]) * t + rng.randint(-spread, spread),
                    a[1] + (b[1] - a[1]) * t + rng.randint(-spread, spread)))
    pts.append(b)
    d.line(pts, fill=color, width=2)
    d.line(pts, fill=ARC_CORE, width=1)


def tesla_palace(rng):
    """The Tower of Engineering, seat of the Engineering Board: a lattice tower with a mushroom dome, arcs
    leaping from its rim, standing on a palace of steel columns."""
    img, d = new(236, 262)
    base = 258
    cx = 118
    # palace hall
    d.rectangle((10, base - 62, 226, base - 8), fill=STEEL, outline=INK)
    d.rectangle((11, base - 22, 225, base - 9), fill=STEEL_DARK)
    for x in range(22, 222, 16):
        d.rectangle((x - 3, base - 58, x + 3, base - 10), fill=STEEL_LIGHT, outline=INK)
    for x in range(30, 214, 16):
        d.rectangle((x - 3, base - 50, x + 3, base - 40), fill=WIN, outline=INK)
    d.rectangle((4, base - 70, 232, base - 60), fill=NAVY, outline=INK)
    d.line([(6, base - 66), (230, base - 66)], fill=WIN_COOL)
    for i, inset in enumerate((0, 8, 16)):
        d.rectangle((40 + inset, base - 8 + i * 0, 196 - inset, base - 2 + i * 2), fill=STEEL_LIGHT, outline=INK)
    d.rectangle((cx - 12, base - 36, cx + 12, base - 8), fill=INK)
    d.arc((cx - 12, base - 46, cx + 12, base - 26), 180, 360, fill=LAMP, width=2)
    # lattice tower
    top_y, bot_y = 64, base - 70
    lw_top, lw_bot = 12, 34
    d.line([(cx, bot_y), (cx, top_y)], fill=WIN_COOL, width=3)
    n = 9
    for i in range(n + 1):
        t = i / n
        y = bot_y + (top_y - bot_y) * t
        hw = lw_bot + (lw_top - lw_bot) * t
        d.line([(cx - hw, y), (cx + hw, y)], fill=INK, width=3)
        d.line([(cx - hw, y), (cx + hw, y)], fill=STEEL)
        if i < n:
            y2 = bot_y + (top_y - bot_y) * (i + 1) / n
            hw2 = lw_bot + (lw_top - lw_bot) * (i + 1) / n
            d.line([(cx - hw, y), (cx + hw2, y2)], fill=STEEL_DARK, width=2)
            d.line([(cx + hw, y), (cx - hw2, y2)], fill=STEEL_DARK, width=2)
    for side in (-1, 1):
        d.line([(cx + side * lw_bot, bot_y), (cx + side * lw_top, top_y)], fill=INK, width=7)
        d.line([(cx + side * lw_bot, bot_y), (cx + side * lw_top, top_y)], fill=STEEL, width=4)
        d.line([(cx + side * (lw_bot - 1), bot_y), (cx + side * (lw_top - 1), top_y)], fill=STEEL_LIGHT)
    # copper coil rings wound round the tower
    for t in (0.25, 0.55, 0.85):
        y = bot_y + (top_y - bot_y) * t
        hw = lw_bot + (lw_top - lw_bot) * t + 6
        d.ellipse((cx - hw, y - 4, cx + hw, y + 4), outline=INK, width=4)
        d.ellipse((cx - hw, y - 4, cx + hw, y + 4), outline=COPPER, width=2)
    # mushroom dome
    d.pieslice((cx - 62, 14, cx + 62, 96), 180, 360, fill=STEEL_LIGHT, outline=INK)
    d.rectangle((cx - 62, 54, cx + 62, 62), fill=STEEL, outline=INK)
    for f in (0.3, 0.65):
        d.arc((cx - 62 * f, 14, cx + 62 * f, 96), 180, 360, fill=STEEL_DARK)
    d.line([(cx, 14), (cx, 54)], fill=STEEL_DARK)
    d.arc((cx - 54, 20, cx + 54, 90), 200, 250, fill=WHITE, width=4)
    for x in range(cx - 54, cx + 55, 12):
        d.rectangle((x - 2, 56, x + 2, 60), fill=WIN_COOL)
    d.line([(cx, 14), (cx, 2)], fill=INK, width=3)
    d.ellipse((cx - 4, 0, cx + 4, 8), fill=ARC_CORE, outline=INK)
    # arcs from the dome rim
    for (a, b) in (((cx - 62, 58), (cx - 112, 36)), ((cx + 62, 58), (cx + 114, 30)),
                   ((cx - 40, 24), (cx - 92, 6)), ((cx + 36, 22), (cx + 98, 4)), ((cx, 4), (cx + 22, 2))):
        jagged(d, a, b, rng)
    sign(img, cx, base - 84, "TOWER OF ENGINEERING", fg=WIN_COOL)
    return img


def tower_crane(rng, jib_left=110, jib_right=60, height=170):
    """A yellow tower crane: lattice mast, long jib, counterweight and a hanging load."""
    img, d = new(jib_left + jib_right + 24, height + 12)
    mx = jib_left + 12
    top = 24
    x0, x1 = 10, mx + jib_right
    # mast: two chords with diagonal lacing, on a concrete footing
    d.rectangle((mx - 8, top, mx + 8, height + 4), outline=INK)
    for x in (mx - 6, mx + 6):
        d.line([(x, top), (x, height + 4)], fill=CRANE, width=3)
    for y in range(top, height, 12):
        d.line([(mx - 6, y), (mx + 6, y)], fill=CRANE_DARK, width=2)
        d.line([(mx - 6, y), (mx + 6, y + 12)], fill=CRANE_DARK, width=2)
    d.rectangle((mx - 16, height + 2, mx + 16, height + 10), fill=(120, 118, 130), outline=INK)
    # jib and counter-jib as one lattice girder
    d.rectangle((x0, top - 8, x1, top + 2), outline=INK)
    d.line([(x0 + 1, top - 7), (x1 - 1, top - 7)], fill=CRANE, width=2)
    d.line([(x0 + 1, top + 1), (x1 - 1, top + 1)], fill=CRANE, width=2)
    for x in range(x0, x1 - 4, 8):
        d.line([(x, top + 1), (x + 4, top - 7)], fill=CRANE_DARK)
        d.line([(x + 4, top - 7), (x + 8, top + 1)], fill=CRANE_DARK)
    # apex with tie bars down to both ends
    d.polygon([(mx - 6, top - 8), (mx, top - 22), (mx + 6, top - 8)], fill=CRANE, outline=INK)
    d.line([(mx, top - 22), (x0 + 6, top - 8)], fill=STEEL_LIGHT)
    d.line([(mx, top - 22), (x1 - 4, top - 8)], fill=STEEL_LIGHT)
    # operator's cab and counterweight
    d.rectangle((mx - 10, top + 2, mx + 10, top + 16), fill=CRANE, outline=INK)
    d.rectangle((mx - 7, top + 5, mx + 7, top + 11), fill=WIN_COOL)
    d.rectangle((x1 - 24, top + 2, x1 - 2, top + 18), fill=(96, 96, 108), outline=INK)
    d.line([(x1 - 22, top + 8), (x1 - 4, top + 8)], fill=INK)
    # trolley, cable and a bundle of beams on its way up
    hook_x = 30 + rng.randint(0, 40)
    hook_y = top + 50 + rng.randint(0, 50)
    d.rectangle((hook_x - 5, top + 2, hook_x + 5, top + 6), fill=STEEL_DARK, outline=INK)
    d.line([(hook_x - 1, top + 6), (hook_x - 1, hook_y)], fill=INK)
    d.line([(hook_x + 1, top + 6), (hook_x + 1, hook_y)], fill=INK)
    for k in range(3):
        d.rectangle((hook_x - 22, hook_y + k * 4, hook_x + 22, hook_y + k * 4 + 3), fill=(COPPER, COPPER_DARK)[k % 2], outline=INK)
    # aviation lights and a floodlight aimed at the site
    d.rectangle((mx - 2, 0, mx + 2, 3), fill=SIG_RED)
    d.rectangle((x0, top - 11, x0 + 3, top - 8), fill=SIG_RED)
    d.rectangle((x1 - 3, top - 11, x1, top - 8), fill=SIG_RED)
    d.rectangle((mx + 8, top + 22, mx + 14, top + 27), fill=LAMP_HOT, outline=INK)
    return img


def girder_frame(rng, floors=4, w=96):
    """A tower under construction: open steel frame, the lower floors already lit."""
    h = floors * 22 + 8
    img, d = new(w + 8, h + 4)
    for f in range(floors):
        y1 = h - f * 22
        y0 = y1 - 22
        if f < 2:
            d.rectangle((4, y0, w + 4, y1), fill=(84, 88, 110), outline=INK)
            lit_windows(d, 6, w + 2, y0 + 7, 6, rng, h=6)
        else:
            for x in range(4, w + 5, 23):
                d.line([(x, y0), (x, y1)], fill=COPPER, width=2)
            d.line([(4, y0), (w + 4, y0)], fill=COPPER, width=2)
            d.line([(4, y0), (27, y1)], fill=COPPER_DARK)
    d.rectangle((w // 2, 0, w // 2 + 3, 3), fill=SIG_AMBER)
    return img


def cruiser_gun(cannon):
    """A main gun: the station cannon of the Artichoke front on a turret ring,
    with twin barrels laid toward the bow."""
    img, d = new(cannon.width + 8, cannon.height + 58)
    d.ellipse((0, 46, cannon.width + 7, cannon.height + 57), fill=STEEL_DARK, outline=INK)
    for bx in (cannon.width // 2 - 6, cannon.width // 2 + 14):
        d.rectangle((bx - 3, 4, bx + 3, 56), fill=(96, 104, 116), outline=INK)
        d.line([(bx - 1, 6), (bx - 1, 54)], fill=(140, 148, 160))
        d.rectangle((bx - 4, 0, bx + 4, 6), fill=(70, 76, 86), outline=INK)
    img.alpha_composite(cannon, (4, 52))
    return img


def point_defense(facing):
    """A small flank turret, its barrel pointing out from the hull."""
    img, d = new(26, 16)
    d.ellipse((7, 2, 19, 14), fill=(150, 158, 170), outline=INK)
    d.rectangle((10, 6, 16, 10), fill=COPPER_LIGHT)
    d.rectangle((18, 6, 25, 9), fill=(70, 76, 86), outline=INK)
    return img if facing > 0 else img.transpose(Image.FLIP_LEFT_RIGHT)


def _inset(poly, amount):
    """Moves every vertex of a convex polygon toward its centroid."""
    cx = sum(x for x, _ in poly) / len(poly)
    cy = sum(y for _, y in poly) / len(poly)
    out = []
    for x, y in poly:
        dist = math.hypot(x - cx, y - cy)
        out.append((x + (cx - x) * amount / dist, y + (cy - y) * amount / dist))
    return out


def cruiser(rng, length=650):
    """The navy cruiser docked beside the city, as long as a district: a wedge-shaped
    hull with its bow to the north and its engines at the stern. `length` is the
    deck's north-south extent; the guns repeat along the middle section."""
    L = length
    w, h = 330, L + 62
    img, d = new(w, h)
    hull = (176, 186, 206)
    hull_dark = (132, 142, 168)
    deck = (204, 210, 226)
    face = (84, 90, 116)
    depth = 40
    outer = [(165, 0), (196, 58), (290, 236), (304, L - 90), (296, L), (34, L), (26, L - 90), (40, 236), (134, 58)]
    inner = [(165, 30), (186, 72), (268, 244), (280, L - 94), (274, L - 20), (56, L - 20), (50, L - 94), (62, 244), (144, 72)]
    # the stern and the lower flanks, seen from the city side
    for k in range(depth, 0, -1):
        d.polygon([(x, y + k) for x, y in outer], fill=face)
    d.polygon([(x, y + depth) for x, y in outer], outline=INK)
    for x, y in ((26, L - 90), (304, L - 90), (34, L), (296, L)):
        d.line([(x, y), (x, y + depth)], fill=INK)
    for y in (L + 12, L + 26):
        d.line([(36, y), (294, y)], fill=(70, 74, 98))
    # engine nozzles, idling while docked
    for nx, r in ((72, 15), (120, 18), (165, 22), (210, 18), (258, 15)):
        cy = L + depth // 2 + 2
        ry = r * 0.72
        d.ellipse((nx - r - 3, cy - ry - 3, nx + r + 3, cy + ry + 3), fill=STEEL_DARK, outline=INK)
        d.ellipse((nx - r, cy - ry, nx + r, cy + ry), fill=INK)
        d.ellipse((nx - r + 4, cy - ry + 3, nx + r - 4, cy + ry - 3), fill=THRUST)
        d.ellipse((nx - r + 9, cy - ry + 6, nx + r - 9, cy + ry - 6), fill=ARC_CORE)
    # deck: an armored border around plated decking
    d.polygon(outer, fill=hull_dark, outline=INK)
    plates = Image.new("RGBA", (w, h), hull + (255,))
    pd = ImageDraw.Draw(plates)
    for y in range(40, L, 32):
        pd.line([(0, y), (w, y)], fill=hull_dark)
        for x in range(rng.randrange(0, 40), w, 48):
            pd.line([(x, y), (x, y + 32)], fill=hull_dark)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(inner, fill=255)
    img.paste(plates, (0, 0), mask)
    d.polygon(inner, outline=INK)
    # running lights along the armored border, red to port and green to starboard
    border = _inset(outer, 8)
    for (ax, ay), (bx, by) in zip(border, border[1:] + border[:1]):
        seg = math.hypot(bx - ax, by - ay)
        for s in range(6, int(seg) - 4, 20):
            t = s / seg
            px, py = ax + (bx - ax) * t, ay + (by - ay) * t
            d.rectangle((px - 1, py - 1, px + 1, py + 1), fill=WIN_COOL)
    d.rectangle((38, 232, 44, 238), fill=SIG_RED, outline=INK)
    d.rectangle((286, 232, 292, 238), fill=SIG_GREEN, outline=INK)
    d.rectangle((162, 4, 168, 10), fill=LAMP_HOT, outline=INK)
    # Engineeria's gear on the bow
    for k in range(8):
        a = math.radians(k * 45)
        gx, gy = 165 + 15 * math.cos(a), 64 + 15 * math.sin(a)
        d.rectangle((gx - 3, gy - 3, gx + 3, gy + 3), fill=BRASS_DARK, outline=INK)
    d.ellipse((152, 51, 178, 77), fill=BRASS, outline=INK)
    d.ellipse((160, 59, 170, 69), fill=NAVY, outline=INK)
    # central spine with a row of lit ports on each side
    spine_end = L - 42
    d.rectangle((146, 208, 184, spine_end + 10), fill=face, outline=INK)
    d.rectangle((146, 200, 184, spine_end), fill=deck, outline=INK)
    d.line([(165, 202), (165, spine_end - 2)], fill=hull_dark)
    for y in range(208, spine_end - 8, 9):
        for x in (150, 177):
            d.rectangle((x, y, x + 3, y + 3), fill=WIN_COOL if rng.random() < 0.75 else INK)
    # stepped bridge tower over the stern
    b = L - 240
    steps = ((110, b + 60, 220, b + 180), (124, b + 30, 206, b + 122), (136, b, 194, b + 76))
    for i, (sx0, sy0, sx1, sy1) in enumerate(steps):
        d.rectangle((sx0, sy1, sx1, sy1 + 12), fill=face, outline=INK)
        lit_windows(d, sx0 + 4, sx1 - 4, sy1 + 3, (sx1 - sx0) // 12, rng, h=5, w=5, cool=0.7)
        d.rectangle((sx0, sy0, sx1, sy1), fill=deck if i % 2 == 0 else hull, outline=INK)
    d.rectangle((140, b + 4, 190, b + 14), fill=WIN_COOL, outline=INK)
    for x, top in ((148, b - 30), (182, b - 40)):
        d.line([(x, b), (x, top)], fill=INK, width=2)
        d.rectangle((x - 2, top - 3, x + 2, top), fill=SIG_RED)
    d.chord((154, b + 30, 176, b + 50), 180, 360, fill=STEEL_LIGHT, outline=INK)
    # main guns: one on the bow, then pairs either side of the spine up to the bridge
    cannon = Image.open(CANNON_ART).convert("RGBA")
    gun = cruiser_gun(cannon)
    img.alpha_composite(gun, (121, 96))
    gy = 206
    while gy + gun.height < b + 8:
        img.alpha_composite(gun, (57, gy))
        img.alpha_composite(gun, (185, gy))
        gy += 112
    # point-defense turrets down both flanks
    for y in range(300, L - 50, 72):
        img.alpha_composite(point_defense(-1), (24, y))
        img.alpha_composite(point_defense(1), (280, y))
    for x, y in ((92, b + 20), (234, b + 60), (98, b + 150)):
        img.alpha_composite(soldier(), (x, y))
    sign(img, 165, L - 38, "CRUISER", fg=WIN_COOL)
    return img


# ---------- farms and industry ----------

def greenhouse(rng):
    """Automated greenhouse dome: crop rows under violet grow lights."""
    img, d = new(96, 64)
    d.pieslice((2, 6, 94, 118), 180, 360, fill=GLASS, outline=INK)
    d.rectangle((2, 58, 94, 62), fill=STEEL_DARK, outline=INK)
    for x in range(14, 90, 12):
        d.line([(x, 56), (x, 20 + abs(48 - x) // 3)], fill=GREEN_DARK, width=4)
        d.line([(x, 56), (x, 22 + abs(48 - x) // 3)], fill=GREEN_LIGHT, width=2)
    for x in range(10, 90, 16):
        d.rectangle((x, 14 + abs(48 - x) // 3, x + 6, 16 + abs(48 - x) // 3), fill=LAMP_HOT)
    d.arc((8, 10, 88, 110), 200, 250, fill=GLASS_LIGHT, width=2)
    return img


def vertical_farm(rng):
    img, d = new(64, 112)
    d.rectangle((4, 6, 60, 108), fill=STEEL_DARK, outline=INK)
    for y in range(12, 100, 12):
        d.rectangle((8, y, 56, y + 8), fill=GREEN_DARK, outline=INK)
        for x in range(10, 56, 5):
            d.line([(x, y + 7), (x + 1, y + 2)], fill=GREEN_LIGHT)
        d.line([(8, y - 1), (56, y - 1)], fill=LAMP_HOT)
    d.rectangle((26, 98, 38, 108), fill=INK)
    sign(img, 32, 0, "FARM")
    return img


def drone(color=LAMP_HOT):
    img, d = new(18, 10)
    d.rectangle((6, 3, 12, 7), fill=STEEL, outline=INK)
    for x in (0, 13):
        d.line([(x, 1), (x + 5, 1)], fill=INK)
    d.line([(3, 1), (7, 4)], fill=INK)
    d.line([(15, 1), (11, 4)], fill=INK)
    d.point((9, 5), fill=color)
    return img


def factory(rng, label, goods):
    """Sawtooth-roofed works with a robot arm loading goods onto a belt."""
    img, d = new(150, 96)
    d.rectangle((4, 30, 146, 92), fill=(124, 120, 136), outline=INK)
    for x in range(4, 146, 24):
        d.polygon([(x, 30), (x + 24, 14), (x + 24, 30)], fill=STEEL, outline=INK)
        d.line([(x + 23, 16), (x + 23, 29)], fill=WIN_COOL, width=2)
    lit_windows(d, 8, 142, 44, 8, rng, h=8, cool=0.6)
    d.rectangle((118, 0, 130, 30), fill=(96, 92, 104), outline=INK)
    d.rectangle((118, 4, 130, 7), fill=SIG_RED)
    d.rectangle((14, 70, 46, 92), fill=INK)
    d.rectangle((16, 72, 44, 90), fill=(36, 34, 46))
    d.rectangle((60, 78, 146, 88), fill=(70, 70, 82), outline=INK)
    for x in range(64, 144, 14):
        d.rectangle((x, 72, x + 9, 79), fill=rng.choice(goods), outline=INK)
    d.line([(100, 60), (110, 50), (122, 64)], fill=COPPER_LIGHT, width=3)
    d.line([(100, 60), (110, 50), (122, 64)], fill=INK, width=1)
    sign(img, 75, 18, label)
    return img


def conveyor(length, rng, goods):
    img, d = new(length, 16)
    d.rectangle((0, 6, length - 1, 13), fill=(70, 70, 82), outline=INK)
    for x in range(4, length - 4, 8):
        d.line([(x, 7), (x, 12)], fill=(96, 96, 110))
    for x in range(6, length - 12, 26):
        d.rectangle((x, 0, x + 10, 7), fill=rng.choice(goods), outline=INK)
    return img


# ---------- town services ----------

def market_stall(rng, color):
    img, d = new(48, 46)
    d.rectangle((6, 22, 42, 42), fill=(110, 88, 76), outline=INK)
    d.polygon([(2, 22), (46, 22), (42, 10), (6, 10)], fill=color, outline=INK)
    for x in range(8, 42, 8):
        d.line([(x, 11), (x - 2, 21)], fill=WHITE)
    for x in range(9, 40, 8):
        d.rectangle((x, 24, x + 5, 29), fill=rng.choice([GREEN_LIGHT, COPPER_LIGHT, (230, 210, 90), (230, 90, 70)]), outline=INK)
    d.line([(4, 10), (44, 10)], fill=LAMP)
    return img


def library(rng):
    """Library of the engineers: a gear rose window above a steel portico."""
    img, d = new(132, 112)
    d.rectangle((8, 40, 124, 108), fill=(150, 140, 168), outline=INK)
    d.polygon([(2, 42), (66, 6), (130, 42)], fill=(94, 84, 130), outline=INK)
    for x in range(18, 120, 14):
        d.rectangle((x - 3, 58, x + 3, 106), fill=STEEL_LIGHT, outline=INK)
    for k in range(10):
        a = math.radians(k * 36)
        gx, gy = 66 + 15 * math.cos(a), 27 + 12 * math.sin(a)
        d.rectangle((gx - 2, gy - 2, gx + 2, gy + 2), fill=BRASS, outline=INK)
    d.ellipse((52, 16, 80, 38), fill=WIN, outline=INK)
    d.ellipse((60, 22, 72, 32), fill=BRASS, outline=INK)
    lit_windows(d, 22, 112, 68, 6, rng, h=10, w=6, cool=0)
    d.rectangle((58, 86, 74, 108), fill=INK)
    sign(img, 66, 43, "LIBRARY", fg=WIN)
    return img


def forge(rng):
    """Forge with an open furnace, an anvil and a Tvrdium suit on display."""
    img, d = new(124, 92)
    d.rectangle((6, 28, 118, 88), fill=(102, 84, 80), outline=INK)
    d.rectangle((6, 18, 118, 30), fill=(70, 60, 64), outline=INK)
    d.rectangle((92, 0, 106, 20), fill=(80, 72, 74), outline=INK)
    d.rectangle((14, 48, 50, 86), fill=INK)
    d.rectangle((18, 54, 46, 86), fill=FIRE)
    d.rectangle((24, 62, 40, 86), fill=LAMP_HOT)
    d.rectangle((58, 74, 76, 80), fill=(60, 60, 70), outline=INK)
    d.rectangle((63, 80, 71, 88), fill=(60, 60, 70), outline=INK)
    # Tvrdium armor on its stand
    d.rectangle((88, 40, 110, 86), fill=(52, 46, 52), outline=INK)
    d.rectangle((93, 46, 105, 52), fill=TVRDIUM, outline=INK)
    d.polygon([(90, 54), (108, 54), (106, 72), (92, 72)], fill=TVRDIUM, outline=INK)
    d.line([(99, 56), (99, 70)], fill=TVRDIUM_LIGHT)
    d.line([(94, 60), (104, 60)], fill=TVRDIUM_LIGHT)
    d.rectangle((92, 72, 97, 84), fill=TVRDIUM_LIGHT, outline=INK)
    d.rectangle((101, 72, 106, 84), fill=TVRDIUM_LIGHT, outline=INK)
    sign(img, 36, 18, "FORGE", fg=FIRE)
    sign(img, 97, 27, "TVRDIUM")
    return img


def police_post(rng):
    img, d = new(84, 64)
    d.rectangle((4, 22, 80, 60), fill=(80, 96, 140), outline=INK)
    d.rectangle((4, 14, 80, 24), fill=(44, 54, 100), outline=INK)
    lit_windows(d, 8, 76, 32, 4, rng, h=8, cool=1)
    d.rectangle((36, 44, 48, 60), fill=INK)
    d.rectangle((30, 6, 38, 14), fill=THRUST, outline=INK)
    d.rectangle((46, 6, 54, 14), fill=THRUST, outline=INK)
    sign(img, 42, 15, "POLICE", fg=WIN_COOL)
    return img


# ---------- the punk park ----------

def disco(rng):
    """A club with a mirror ball on the roof and stripes of changing color."""
    img, d = new(140, 132)
    d.rectangle((8, 50, 132, 128), fill=(44, 34, 62), outline=INK)
    for i, y in enumerate(range(56, 104, 8)):
        d.line([(10, y), (130, y)], fill=NEONS[i % len(NEONS)], width=2)
    d.rectangle((54, 104, 86, 128), fill=INK)
    for x in range(56, 86, 6):
        d.rectangle((x, 106, x + 4, 110), fill=rng.choice(NEONS))
    d.rectangle((48, 36, 92, 50), fill=(60, 50, 80), outline=INK)
    d.line([(70, 36), (70, 28)], fill=INK, width=2)
    d.ellipse((50, 0, 90, 34), fill=STEEL_LIGHT, outline=INK)
    for y in range(4, 32, 5):
        for x in range(54, 88, 5):
            if (x - 70) ** 2 / 400 + (y - 17) ** 2 / 289 < 1:
                d.point((x, y), fill=rng.choice(NEONS + [WHITE, STEEL]))
    sign(img, 70, 40, "DISCO", bg=INK, fg=NEON_PINK)
    return img


def graffiti_wall(rng, length=120):
    """A concrete wall sprayed with tags in fluorescent paint that glows at night."""
    img, d = new(length, 30)
    d.rectangle((0, 4, length - 1, 28), fill=(96, 90, 104), outline=INK)
    for x in range(16, length, 16):
        d.line([(x, 5), (x, 27)], fill=(82, 76, 92))
    # a lightning bolt, then tags side by side with paint dripping under them
    bx = rng.randrange(4, max(5, length - 16))
    d.polygon([(bx + 8, 6), (bx + 2, 16), (bx + 7, 16), (bx + 3, 26), (bx + 12, 13), (bx + 7, 13), (bx + 11, 6)],
              fill=NEON_YELLOW, outline=INK)
    x = 4
    for word in rng.sample(["ZAP!", "VOLT", "OHM", "BZZT", "AMP", "KICK", "SPARK"], 4):
        tw = int(d.textlength(word, font=FONT))
        if x + tw > length - 4:
            break
        col = rng.choice([NEON_PINK, NEON_CYAN, NEON_GREEN, NEON_ORANGE, NEON_VIOLET])
        y = 8 + rng.randint(-2, 3)
        d.text((x, y), word, font=FONT, fill=col)
        for _ in range(2):
            dx = x + rng.randrange(1, max(2, tw - 1))
            d.line([(dx, y + 11), (dx, y + 11 + rng.randint(2, 6))], fill=col)
        x += tw + rng.randint(5, 12)
    return img


def half_pipe():
    img, d = new(80, 36)
    d.rectangle((2, 4, 78, 32), fill=(120, 112, 140), outline=INK)
    d.chord((10, -24, 70, 26), 0, 180, fill=(84, 76, 104), outline=INK)
    d.line([(2, 4), (78, 4)], fill=NEON_PINK, width=2)
    return img


def wire_tree(rng, colors=(LAMP,)):
    """Metal tree with lamp fruit, as Iskra plants its parks and terraces."""
    img, d = new(32, 46)
    d.rectangle((14, 22, 18, 45), fill=STEEL_DARK, outline=INK)
    for a in (-60, -30, 0, 30, 60):
        x = 16 + 14 * math.sin(math.radians(a))
        y = 22 - 16 * math.cos(math.radians(a))
        d.line([(16, 24), (x, y)], fill=STEEL_DARK, width=2)
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=rng.choice(colors), outline=INK)
    return img


def leafy_tree(variant=0):
    with Image.open(ROOT / "art/concepts/source" / f"tree{variant % 2 + 1}.png") as source:
        return source.convert("RGBA")


def park_bench():
    img, d = new(26, 15)
    d.rectangle((2, 2, 23, 5), fill=COPPER_LIGHT, outline=INK)
    d.rectangle((1, 7, 24, 10), fill=COPPER, outline=INK)
    for x in (4, 20):
        d.rectangle((x, 10, x+2, 14), fill=STEEL_DARK)
    return img


def fire_barrel():
    img, d = new(14, 20)
    d.rectangle((2, 8, 12, 19), fill=(90, 70, 60), outline=INK)
    d.polygon([(3, 8), (5, 1), (7, 5), (9, 0), (11, 8)], fill=FIRE)
    return img


def crates(n=3, marked=True):
    img, d = new(14 * n + 4, 18)
    for i in range(n):
        x = 2 + i * 13
        d.rectangle((x, 4, x + 12, 16), fill=(130, 100, 70), outline=INK)
        d.line([(x, 4), (x + 12, 16)], fill=(100, 76, 52))
        if marked:
            d.rectangle((x + 3, 8, x + 9, 11), fill=(70, 60, 50))
    return img


def billboard(text, color):
    """A holographic billboard over the street, as wide as its text."""
    w = int(ImageDraw.Draw(Image.new("RGBA", (1, 1))).textlength(text, font=FONT)) + 40
    img, d = new(w, 52)
    d.rectangle((w // 2 - 3, 30, w // 2 + 3, 50), fill=STEEL_DARK, outline=INK)
    d.rectangle((2, 2, w - 2, 32), fill=(24, 30, 54), outline=color)
    d.rectangle((6, 6, 22, 28), outline=color)
    d.ellipse((9, 10, 19, 22), outline=color)
    d.text((28, 11), text, font=FONT, fill=color)
    return img


# ---------- drawing helpers for the ground ----------

def plated(img, poly, base, alt, seam, rng, tile=16):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    layer = Image.new("RGBA", img.size, base + (255,))
    d = ImageDraw.Draw(layer)
    for tx in range(0, W, tile):
        for ty in range(0, H, tile):
            if rng.random() < 0.3:
                d.rectangle((tx, ty, tx + tile - 1, ty + tile - 1), fill=alt)
            d.line([(tx, ty), (tx + tile - 1, ty)], fill=seam)
            d.line([(tx, ty), (tx, ty + tile - 1)], fill=seam)
            if rng.random() < 0.05:
                d.point((tx + 3, ty + 3), fill=HULL_LIGHT)
    img.paste(layer, (0, 0), mask)


def raised(img, poly, face_h, top, alt, face, rng, rim_light=WIN):
    """A raised level: the polygon pushed up by face_h, its south walls showing."""
    d = ImageDraw.Draw(img)
    for k in range(face_h, 0, -1):
        d.polygon([(x, y + k) for x, y in poly], fill=face)
    d.polygon([(x, y + face_h) for x, y in poly], outline=INK)
    plated(img, poly, top, alt, tuple(max(0, c - 14) for c in top), rng)
    d.polygon(poly, outline=INK)
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        length = math.hypot(x1 - x0, y1 - y0)
        south = (x1 - x0) > 0 if _clockwise(poly) else (x1 - x0) < 0
        if not south:
            continue
        d.line([(x0, y0 + 1), (x1, y1 + 1)], fill=rim_light)
        for s in range(8, int(length) - 6, 9):
            t = s / length
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if rng.random() < 0.75:
                d.rectangle((x - 2, y + face_h // 2 - 2, x + 1, y + face_h // 2 + 1), fill=rng.choice([WIN, WIN, WIN_COOL]))


def _clockwise(poly):
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    return area > 0


def dashed(d, pts, color, on, off, width=1):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        s = 0.0
        while s < length:
            e = min(length, s + on)
            d.line([(x0 + (x1 - x0) * s / length, y0 + (y1 - y0) * s / length),
                    (x0 + (x1 - x0) * e / length, y0 + (y1 - y0) * e / length)], fill=color, width=width)
            s += on + off


# ---------- layout: hull, ship canals, footpaths, terraces and lots ----------
#
# Ships are Iskra's cars, so they fly in sunken canals cut into the hull, kept
# away from the houses by a railing and a promenade. Houses stand back from the
# footpaths behind a front yard. Everything left over between canals, footpaths
# and the special grounds is a lot, packed with houses row behind row.

PLATFORM = [(60, 170), (250, 80), (470, 100), (640, 50), (900, 70), (1120, 40), (1350, 80), (1560, 60),
            (1740, 150), (1772, 300), (1768, 1060), (1730, 1140), (1540, 1210), (1300, 1180), (1060, 1228),
            (800, 1196), (560, 1226), (330, 1186), (150, 1120), (60, 980), (84, 770), (30, 580), (70, 380)]
PALACE = [(730, 150), (830, 104), (990, 104), (1090, 160), (1100, 320), (1010, 368), (810, 368), (720, 312)]
PALACE_FACE = 34
PALACE_PLAZA = [(770, 400), (1050, 400), (1056, 432), (764, 432)]

CANAL_W = 40
CANAL_DEPTH = 12
CANALS = [
    [(0, 520), (300, 500), (620, 466), (910, 474), (1220, 486), (1500, 506), (1800, 496)],
    [(910, 474), (890, 700), (928, 900), (910, 1250)],
    [(0, 912), (330, 930), (620, 896), (928, 900), (1240, 918), (1520, 900), (1800, 908)],
]
JUNCTIONS = [(910, 474), (928, 900)]

PATH_W = 18
YARD = 10
PATHS = [
    [(60, 270), (300, 262), (560, 240), (722, 236)],
    [(1098, 250), (1350, 262), (1600, 250), (1772, 262)],
    [(40, 700), (330, 712), (640, 690), (1240, 690), (1520, 708), (1700, 700)],
    [(150, 1070), (450, 1080), (700, 1062), (1240, 1070)],
    [(300, 90), (280, 300), (300, 520), (270, 700), (300, 900), (290, 1180)],
    [(520, 80), (530, 300), (510, 520), (540, 700), (520, 900), (530, 1210)],
    [(740, 700), (700, 900), (720, 1212)],
    [(1130, 500), (1110, 700), (1140, 900), (1120, 1220)],
    [(1300, 60), (1280, 260), (1310, 500), (1340, 700), (1320, 900)],
    [(1510, 70), (1530, 260), (1520, 500), (1560, 700), (1540, 900)],
]
ALLEY = [(436, 716), (420, 800), (446, 878)]

TERRACE_FACE = 18
TERRACES = [  # raised districts: outline and the x of the stairs on their south edge
    ([(332, 104), (420, 90), (480, 100), (484, 220), (410, 230), (330, 222)], 410),
    ([(1326, 96), (1420, 80), (1488, 96), (1492, 216), (1410, 226), (1322, 218)], 1410),
    ([(1160, 548), (1240, 536), (1300, 548), (1304, 650), (1230, 658), (1156, 650)], 1230),
]

MARKET = [(600, 548), (760, 540), (790, 640), (610, 660)]
PARK = [(1260, 960), (1420, 944), (1560, 970), (1600, 1080), (1530, 1170), (1360, 1180), (1250, 1120), (1236, 1030)]
NATURE_PARK = [(318, 546), (350, 532), (480, 534), (500, 558), (496, 656), (474, 680), (332, 678), (310, 650)]
NATURE_PATH = [(410, 708), (414, 660), (393, 626), (414, 584), (406, 534)]
NATURE_TREES = [(320, 588), (358, 574), (441, 580), (467, 611), (319, 635), (348, 676), (445, 672)]
CITY_TREES = [(756, 355), (1038, 355), (785, 429), (998, 429), (1726, 378), (1724, 560), (1725, 804)]
CONSTRUCTION = [(84, 196), (250, 108), (262, 236), (100, 250)]
FIELD = [(64, 560), (240, 548), (244, 664), (74, 676)]
DOCK = [(1690, 290), (1772, 300), (1768, 1064), (1690, 1064)]
PIERS = [(420, 450), (640, 668), (860, 888)]
CLAMPS = [(1700, 1922, 300), (1700, 1856, 1050)]

PATH = (166, 170, 192)
PATH_SEAM = (142, 148, 174)
CURB = (96, 102, 132)
LOT = (112, 120, 148)
CANAL_WALL = (70, 76, 104)
CANAL_FLOOR = (48, 54, 78)


def space(rng):
    img = Image.new("RGBA", (W, CANVAS_H), VOID + (255,))
    d = ImageDraw.Draw(img)
    for _ in range(2200):
        x, y = rng.randrange(W), rng.randrange(CANVAS_H)
        d.point((x, y), fill=STAR if rng.random() < 0.3 else STAR_DIM)
    for _ in range(50):
        x, y = rng.randrange(W), rng.randrange(CANVAS_H)
        d.line([(x - 1, y), (x + 1, y)], fill=STAR)
        d.line([(x, y - 1), (x, y + 1)], fill=STAR)
    # A pale artificial dawn sits behind the northern rim: the city is bright by design,
    # but the sky remains a real night sky.
    dawn = Image.new("RGBA", (W, CANVAS_H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dawn)
    dd.ellipse((120, -170, 1840, 380), fill=(154, 194, 255, 34))
    dawn = dawn.filter(ImageFilter.GaussianBlur(28))
    img.alpha_composite(dawn)
    # a distant planet in the corner
    d.ellipse((W - 230, -150, W + 90, 140), fill=(70, 58, 110), outline=INK)
    d.arc((W - 220, -140, W + 80, 130), 100, 200, fill=(120, 100, 170), width=6)
    return img


def poly_mask(poly):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return np.asarray(m) > 0


def line_mask(pts, width):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=width, joint="curve")
    for x, y in pts:
        d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=255)
    return np.asarray(m) > 0


def shift_down(mask, k):
    out = np.zeros_like(mask)
    out[k:] = mask[:-k]
    return out


def grow(mask, k):
    return ndimage.binary_dilation(mask, iterations=k)


def paint(img, mask, color):
    alpha = Image.fromarray(mask.astype(np.uint8) * 255)
    img.paste(Image.new("RGBA", img.size, color + (255,)), (0, 0), alpha)


def layout():
    """Masks for everything the ground and the house packing need, in city coordinates."""
    L = {}
    platform = poly_mask(PLATFORM)
    L["platform"] = platform
    canals = np.zeros((H, W), bool)
    canal_zone = np.zeros((H, W), bool)
    for pts in CANALS:
        canals |= line_mask(pts, CANAL_W)
        canal_zone |= line_mask(pts, CANAL_W + 2 * 20)
    L["canals"] = canals & ndimage.binary_erosion(platform, iterations=4)
    L["promenades"] = canal_zone & ~canals & platform
    paths = np.zeros((H, W), bool)
    path_zone = np.zeros((H, W), bool)
    for pts in PATHS:
        paths |= line_mask(pts, PATH_W)
        path_zone |= line_mask(pts, PATH_W + 2 * YARD)
    L["paths"] = paths & platform
    L["alley"] = line_mask(ALLEY, 10) & platform
    special = np.zeros((H, W), bool)
    for poly in (MARKET, PARK, CONSTRUCTION, FIELD, DOCK, PALACE, PALACE_PLAZA):
        special |= poly_mask(poly)
    special |= shift_down(poly_mask(PALACE), PALACE_FACE)
    terraces = [poly_mask(poly) for poly, _ in TERRACES]
    terrace_any = np.zeros((H, W), bool)
    terrace_top = np.zeros((H, W), bool)
    terrace_edge = np.zeros((H, W), bool)
    for t in terraces:
        terrace_any |= t
        terrace_top |= ndimage.binary_erosion(t, iterations=8)
        terrace_edge |= grow(t, 6) & ~ndimage.binary_erosion(t, iterations=8)
        terrace_edge |= grow(shift_down(t, TERRACE_FACE), 4) & ~t
    lots = (ndimage.binary_erosion(platform, iterations=16) & ~grow(canal_zone, 6) & ~path_zone
            & ~grow(line_mask(ALLEY, 10), 6) & ~grow(special, 10) & ~terrace_edge)
    L["lots"] = lots
    L["terrace_top"] = terrace_top
    return L


def _crossings(a_pts, b_pts):
    """Points where polyline a crosses polyline b, with a's direction there."""
    out = []
    for (x1, y1), (x2, y2) in zip(a_pts, a_pts[1:]):
        for (x3, y3), (x4, y4) in zip(b_pts, b_pts[1:]):
            den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
            if den == 0:
                continue
            t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
            u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den
            if 0 <= t <= 1 and 0 <= u <= 1:
                out.append((x1 + t * (x2 - x1), y1 + t * (y2 - y1), abs(y2 - y1) > abs(x2 - x1)))
    return out


def bridges():
    return [c for path in PATHS for canal in CANALS for c in _crossings(path, canal)]


def build_ground(rng, L):
    """The city's ground and levels on a transparent sheet in city coordinates."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the hull rim, then the plated surface of the artificial planet
    d.polygon([(x, y + 16) for x, y in PLATFORM], fill=(40, 42, 60), outline=INK)
    d.polygon([(x, y + 8) for x, y in PLATFORM], fill=RIM, outline=INK)
    plated(img, PLATFORM, HULL, HULL_2, HULL_SEAM, rng)
    d.polygon(PLATFORM, outline=LAMP)
    for (x0, y0), (x1, y1) in zip(PLATFORM, PLATFORM[1:] + PLATFORM[:1]):
        length = math.hypot(x1 - x0, y1 - y0)
        for s in range(10, int(length), 28):
            t = s / length
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            d.rectangle((px - 1, py + 10, px + 1, py + 12), fill=SIG_AMBER)
    # lots, footpaths with curbs, and the paved promenades along the canals
    paint(img, L["lots"], LOT)
    yy, xx = np.mgrid[0:H, 0:W]
    walk = L["paths"] | L["promenades"]
    paint(img, grow(walk, 1) & ~walk, CURB)
    paint(img, walk, PATH)
    paint(img, walk & ((xx % 8 == 0) | (yy % 8 == 0)), PATH_SEAM)
    paint(img, grow(L["alley"], 1) & ~L["alley"], CURB)
    paint(img, L["alley"], (52, 50, 64))
    # special grounds
    d.polygon(MARKET, fill=PATH, outline=CURB)
    for x in range(600, 792, 12):
        d.line([(x, 540), (x, 662)], fill=PATH_SEAM)
    d.polygon(PARK, fill=PUNK_GROUND, outline=INK)
    for _ in range(400):
        x, y = rng.randrange(1236, 1600), rng.randrange(944, 1180)
        d.point((x, y), fill=rng.choice([(84, 110, 70), (90, 80, 100), (110, 96, 120)]))
    d.polygon(CONSTRUCTION, fill=(96, 90, 86), outline=INK)
    for x in range(90, 262, 16):
        d.line([(x, 110), (x, 250)], fill=(84, 78, 76))
    d.polygon(FIELD, fill=(60, 64, 80), outline=INK)
    for y in range(556, 670, 9):
        d.line([(70, y + 4), (240, y + 4)], fill=GREEN, width=3)
        d.line([(70, y), (240, y)], fill=LAMP_HOT if y % 18 == 16 else GREEN_DARK)
    d.polygon(DOCK, fill=DECK, outline=INK)
    for y in range(296, 1062, 14):
        d.line([(1692, y), (1700, y + 8)], fill=CRANE)
    # raised districts with stairs down from their south edge
    for poly, stair_x in TERRACES:
        raised(img, poly, TERRACE_FACE, DECK, DECK_2, DECK_FACE, rng)
        sy = max(y for x, y in poly if abs(x - stair_x) < 60)
        d.rectangle((stair_x - 10, sy - 4, stair_x + 10, sy + TERRACE_FACE + 6), fill=PATH, outline=INK)
        for k in range(sy - 2, sy + TERRACE_FACE + 6, 3):
            d.line([(stair_x - 9, k), (stair_x + 9, k)], fill=PATH_SEAM)
    paint(img, L["lots"] & L["terrace_top"], (100, 106, 136))
    # ship canals: the far wall shows, the floor runs below, railings on both edges
    canals = L["canals"]
    floor = canals & shift_down(canals, CANAL_DEPTH)
    paint(img, canals & ~floor, CANAL_WALL)
    paint(img, canals & ~floor & (yy % 4 == 0), (44, 46, 68))
    paint(img, floor, CANAL_FLOOR)
    paint(img, grow(canals, 1) & ~canals, STEEL_LIGHT)
    paint(img, grow(canals, 2) & ~grow(canals, 1), INK)
    for pts in CANALS:
        dashed(d, [(x, y + CANAL_DEPTH // 2) for x, y in pts], (150, 140, 100), 8, 12)
    # footbridges where footpaths cross the canals
    half = CANAL_W // 2 + 8
    for x, y, vertical in bridges():
        if vertical:
            d.rectangle((x - 10, y - half, x + 10, y + half), fill=PATH, outline=INK)
            d.line([(x - 9, y - half), (x - 9, y + half)], fill=STEEL_LIGHT)
            d.line([(x + 9, y - half), (x + 9, y + half)], fill=STEEL_LIGHT)
        else:
            d.rectangle((x - half, y + 10, x + half, y + 16), fill=DECK_FACE, outline=INK)
            d.rectangle((x - half, y - 10, x + half, y + 10), fill=PATH, outline=INK)
            d.line([(x - half, y - 9), (x + half, y - 9)], fill=STEEL_LIGHT)
            d.line([(x - half, y + 9), (x + half, y + 9)], fill=STEEL_LIGHT)
    # the palace plateau, its forecourt and the grand stairs between them
    raised(img, PALACE, PALACE_FACE, PLATEAU, (112, 116, 148), PLATEAU_FACE, rng, rim_light=WIN_COOL)
    d.polygon(PALACE_PLAZA, fill=PATH, outline=CURB)
    d.rectangle((880, 362, 940, 404), fill=PATH, outline=INK)
    for k in range(364, 404, 4):
        d.line([(881, k), (939, k)], fill=PATH_SEAM)
    # piers out to the cruiser, with a truss under each deck, and the docking clamps
    for y0, y1 in PIERS:
        d.rectangle((1700, y1, 1880, y1 + 9), fill=DECK_FACE, outline=INK)
        for x in range(1700, 1880, 10):
            d.line([(x, y1 + 1), (x + 5, y1 + 8)], fill=STEEL_DARK)
            d.line([(x + 5, y1 + 8), (x + 10, y1 + 1)], fill=STEEL_DARK)
        d.rectangle((1700, y0, 1880, y1), fill=PATH, outline=INK)
        for x in range(1706, 1880, 10):
            d.line([(x, y0 + 2), (x, y1 - 2)], fill=PATH_SEAM)
        d.line([(1700, y0 + 1), (1880, y0 + 1)], fill=LAMP)
        d.line([(1700, y1 - 1), (1880, y1 - 1)], fill=LAMP)
    for xa, xb, y in CLAMPS:
        d.rectangle((xa, y - 6, xb, y + 6), fill=CRANE, outline=INK)
        for x in range(xa + 6, xb - 8, 12):
            d.polygon([(x, y - 5), (x + 6, y - 5), (x + 1, y + 5), (x - 5, y + 5)], fill=INK)
        d.rectangle((xa - 4, y - 10, xa + 8, y + 10), fill=STEEL_DARK, outline=INK)
    d.polygon(NATURE_PARK, fill=(73, 126, 63), outline=(146, 142, 83))
    park_mask = poly_mask(NATURE_PARK)
    garden_rng = random.Random(83)
    for _ in range(500):
        x, y = garden_rng.randrange(310, 501), garden_rng.randrange(532, 681)
        if park_mask[y, x]:
            d.line((x, y, x+1, y-1), fill=garden_rng.choice([(95, 152, 72), (56, 104, 57), (115, 160, 83)]))
    d.line(NATURE_PATH, fill=(192, 169, 124), width=16, joint="curve")
    d.ellipse((372, 594, 438, 650), outline=(180, 161, 113), width=9)
    for x, bottom in CITY_TREES:
        d.ellipse((x-4, bottom-10, x+37, bottom+3), fill=(83, 129, 67), outline=BRASS_DARK)
    return img


# ---------- the city ----------

def market_hall(rng):
    """A covered market: a long hall under a barrel roof, its doors open on stalls."""
    img, d = new(120, 74)
    d.rectangle((4, 30, 116, 72), fill=(140, 118, 100), outline=INK)
    d.chord((2, 6, 118, 56), 180, 360, fill=(150, 156, 176), outline=INK)
    for x in range(14, 110, 12):
        d.arc((x - 40, 6, x + 40, 56), 250, 290, fill=STEEL_DARK)
    for x in range(12, 112, 20):
        d.rectangle((x, 46, x + 12, 72), fill=INK)
        d.rectangle((x + 1, 58, x + 11, 64), fill=rng.choice([GREEN_LIGHT, COPPER_LIGHT, (230, 210, 90)]))
    d.line([(6, 42), (114, 42)], fill=LAMP)
    sign(img, 60, 30, "MARKET")
    return img


def _runs(line):
    """Start and end indices of the True runs in a 1-D bool array."""
    padded = np.concatenate(([False], line, [False]))
    edges = np.flatnonzero(padded[1:] != padded[:-1])
    return list(zip(edges[::2], edges[1::2]))


FOOT = 28      # how deep a house's footprint reaches north from its bottom edge
OVERHANG = 10  # how far a house's sprite may reach past the north edge of its lot: over the yard, not the path


def place_in_lots(L, occ, sprite, want_x, want_bottom, put, radius=220):
    """Puts an important building in the front row of the lot nearest to where it is
    wanted, so it faces a footpath or canal like the houses on either side of it."""
    lots = L["lots"]
    w = sprite.width
    best = None
    for x in range(max(0, want_x - radius), min(W - w - 1, want_x + radius), 2):
        mid = lots[:, x + w // 2]
        for edge in np.flatnonzero(mid[:-1] & ~mid[1:]):
            if abs(edge - want_bottom) > radius:
                continue
            dist = math.hypot(x - want_x, edge - want_bottom)
            if best and dist >= best[0]:
                continue
            for b in range(edge, edge - 12, -1):
                area = (slice(b - FOOT, b + 1), slice(x, x + w))
                if b - FOOT < 0 or not lots[area].all() or occ[area].any():
                    continue
                # most columns must end in the street within a few pixels of the front
                if lots[b + 1:b + 14, x:x + w].all(axis=0).mean() <= 0.25:
                    best = (dist, x, b)
                break
    if best is None:
        raise RuntimeError(f"no street front for a {w}px building near {want_x},{want_bottom}")
    _, x, b = best
    put(sprite, x, b)
    occ[b - FOOT - 8:b + 14, x - 2:x + w + 2] = True
    return x, b


def _pick_house(rng, x, max_w, bottom, top, valid):
    """A house for the free columns from x on, with the bottom row it stands on, or None.
    Its sprite may reach OVERHANG past the lot's north edge; the median of that edge
    ignores the few columns where a slanted side path cuts the lot short."""
    for _ in range(6):
        limit = int(bottom[x:x + 30].min() - np.median(top[x:x + 30]) + OVERHANG)
        house = ordinary_house(rng, max_w, limit)
        if (house is None or 4 < max_w - house.width < 30) and max_w <= 84:
            house = tenement_fit(rng, max_w - rng.randint(0, 2), limit) or house
        if house is None:
            return None
        w = house.width
        b = int(bottom[x:x + w].min())
        if valid[b, x:x + w].all() and house.height <= b - np.median(top[x:x + w]) + OVERHANG:
            return house, b
    return None


def fill_lots(L, occ, rng, put, pools):
    """Packs ordinary houses into every lot in rows that follow its south edge, so
    the front row faces the street and each row behind sits one house deeper."""
    labels, _ = ndimage.label(L["lots"])
    for i, sl in enumerate(ndimage.find_objects(labels), 1):
        comp = labels[sl] == i
        if comp.sum() < 900:
            continue
        y0, x0 = sl[0].start, sl[1].start
        rows, cols = comp.shape
        top = np.where(comp.any(axis=0), comp.argmax(axis=0), rows)
        while True:
            free = comp & ~occ[sl]
            run = np.zeros(free.shape, np.int32)   # free pixels running down to each pixel from above
            run[0] = free[0]
            for y in range(1, rows):
                run[y] = (run[y - 1] + 1) * free[y]
            valid = run > FOOT
            bottom = np.where(valid.any(axis=0), rows - 1 - valid[::-1].argmax(axis=0), -1)
            placed = False
            x = 0
            while x < cols:
                if bottom[x] < 0:
                    x += 1
                    continue
                end = x
                while end < cols and bottom[end] >= 0:
                    end += 1
                max_w = end - x
                if max_w < 30:
                    x = end
                    continue
                picked = _pick_house(rng, x, max_w, bottom, top, valid)
                if picked is None:
                    x += 6
                    continue
                house, b = picked
                w = house.width
                gx, gy = x0 + x, y0 + b
                put(house, gx, gy)
                placed = True
                occ[gy - rng.randint(44, 50):y0 + int(bottom[x:x + w].max()) + 1, gx:gx + w] = True
                pools.append((gx + w / 2, gy - 4, w * 0.75, WIN, 0.16))
                if not comp[min(rows - 1, b + 8), x + w // 2] and rng.random() < 0.75:
                    put(front_yard(rng, w), gx, gy + 10)
                x += w + rng.choice((1, 2, 2, 3, 4))
            if not placed:
                break


def _lamps_along(pts, north, south, step, put, pools, skip=()):
    """One lamp every `step` pixels, alternating sides. `north` and `south` are the
    distances from the centre line; the south side sits closer because the roofs of
    the houses south of a walkway reach over its edge."""
    k = 0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        nx, ny = -(y1 - y0) / length, (x1 - x0) / length
        if ny < 0:
            nx, ny = -nx, -ny   # the normal points south
        for s in range(24, int(length), step):
            t = s / length
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if any(math.hypot(x - sx, y - sy) < 40 for sx, sy in skip):
                continue
            if abs(ny) < 0.5:   # a walkway running north-south: both sides are alike
                off = north if k % 2 == 0 else -north
            else:
                off = -north if k % 2 == 0 else south
            k += 1
            lx, ly = x + nx * off, y + ny * off
            if not (0 < lx < W and 0 < ly < H):
                continue
            put(street_lamp(), int(lx) - 6, int(ly) + 4)
            pools.append((lx, ly + 2, 50, LAMP, 0.45))


def _canal_traffic(rng, air, pools, crossings):
    """Personal ships hovering along the canals in two lanes, queued at the junctions."""
    def ship(color, dx, dy):
        if abs(dx) >= abs(dy):
            return small_ship(color, 1 if dx > 0 else -1)
        img = small_ship(color, 1)
        return img.rotate(90 if dy < 0 else -90, expand=True)

    for pts in CANALS:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            length = math.hypot(x1 - x0, y1 - y0)
            nx, ny = -(y1 - y0) / length, (x1 - x0) / length
            for s in range(30, int(length) - 20, 46):
                if rng.random() < 0.45:
                    continue
                t = s / length
                cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                if any(math.hypot(cx - bx, cy - by) < 36 for bx, by, _ in crossings):
                    continue
                if any(math.hypot(cx - jx, cy - jy) < 50 for jx, jy in JUNCTIONS):
                    continue
                lane = rng.choice((-1, 1))
                dx, dy = (x1 - x0) * lane, (y1 - y0) * lane
                img = ship(rng.choice(SHIP_COLORS), dx, dy)
                x = int(cx + nx * 9 * lane - img.width / 2)
                y = int(cy + ny * 9 * lane + CANAL_DEPTH // 2 + img.height / 2)
                air.append((img, x, y, 4))
    # ships waiting at the red lights of both junctions
    for jx, jy in JUNCTIONS:
        for k in range(3):
            img = small_ship(rng.choice(SHIP_COLORS), 1)
            air.append((img, jx - 62 - k * 34, jy + 18 + CANAL_DEPTH // 2, 4))
            img = small_ship(rng.choice(SHIP_COLORS), -1)
            air.append((img, jx + 34 + k * 34, jy + 2, 4))


def place_city(rng, L):
    """Returns ground sprites (bottom, x, image), flying craft, light pools, the
    park's colored pools and beams, and the sky lanes."""
    sprites, air, pools, park_pools, beams = [], [], [], [], []
    occ = np.zeros((H, W), bool)

    def put(sprite, x, bottom):
        sprites.append((bottom, x, sprite))

    crossings = bridges()

    # the palace plateau
    put(tesla_palace(rng), 792, 352)
    put(coil_pylon(rng), 750, 268)
    put(coil_pylon(rng), 1020, 268)
    for x in (810, 990):
        put(wire_tree(rng), x, 220)
    pools += [(910, 330, 220, WIN_COOL, 0.55), (910, 170, 150, ARC, 0.22), (910, 410, 110, LAMP_HOT, 0.55),
              (776, 190, 50, ARC, 0.24), (1046, 190, 50, ARC, 0.24)]
    # Broad civic lighting keeps the capital's public spaces bright between buildings.
    pools += [(420, 430, 260, LAMP_HOT, 0.12), (1320, 430, 260, WIN_COOL, 0.12),
              (520, 820, 300, LAMP_HOT, 0.12), (1120, 820, 320, WIN_COOL, 0.12),
              (470, 1110, 300, LAMP_HOT, 0.10), (1040, 1110, 340, LAMP_HOT, 0.10)]
    for x in (812, 1000, 870, 940):
        put(soldier(), x, 366 if x in (812, 1000) else 420)

    # important buildings stand in the lots among ordinary houses
    important = [
        (library(rng), 560, 840, [(WIN, 90, 0.4)]),
        (forge(rng), 1420, 840, [(FIRE, 80, 0.6)]),
        (police_post(rng), 560, 440, [(WIN_COOL, 70, 0.4)]),
        (police_post(rng), 1400, 470, [(WIN_COOL, 70, 0.4)]),
        (market_hall(rng), 1160, 840, [(WIN, 80, 0.4)]),
        (factory(rng, "TEXTILES", [(220, 80, 120), (80, 140, 220), (240, 200, 80)]), 120, 900, [(LAMP_HOT, 110, 0.38)]),
        (factory(rng, "FOOD WORKS", [(200, 150, 90), (230, 220, 200), (190, 80, 60)]), 320, 1150, [(LAMP_HOT, 110, 0.38)]),
        (vertical_farm(rng), 120, 470, [(LAMP_HOT, 70, 0.4)]),
        (vertical_farm(rng), 1620, 640, [(LAMP_HOT, 70, 0.4)]),
        (greenhouse(rng), 1600, 440, [(LAMP_HOT, 80, 0.4)]),
        (lantern_house(rng), 318, 812, [(FIRE, 56, 0.45)]),
        (billboard("ISKRA FM", LAMP), 640, 230, []),
        (billboard("TVRDIUM ARMOR", LAMP), 1380, 640, []),
    ]
    landmarks = []   # rectangles that the sky lanes keep clear of, so no ship hides a sign
    for sprite, x, b, lights in important:
        px, pb = place_in_lots(L, occ, sprite, x, b, put)
        landmarks.append((px, pb - sprite.height, px + sprite.width, pb))
        for color, r, s in lights:
            pools.append((px + sprite.width / 2, pb - 10, r, color, s))

    # greenhouses and drones of the automated farm on the field
    put(greenhouse(rng), 70, 556)
    put(greenhouse(rng), 160, 548)
    for x, y in ((110, 600), (190, 640), (90, 650)):
        put(drone(), x, y)
    air.append((drone(), 150, 520, 14))
    air.append((drone(), 1000, 1110, 16))
    pools += [(110, 520, 90, LAMP_HOT, 0.4), (200, 520, 90, LAMP_HOT, 0.4), (150, 610, 110, LAMP_HOT, 0.35)]

    # construction site: unfinished towers between three cranes
    put(girder_frame(rng, 5), 110, 240)
    put(girder_frame(rng, 3, 70), 180, 200)
    put(tower_crane(rng, 100, 60, 180), 40, 246)
    put(tower_crane(rng, 70, 90, 150), 150, 150)
    put(tower_crane(rng, 60, 50, 130), 196, 236)
    put(crates(3, False), 214, 246)
    for x, y in ((100, 248), (170, 210), (230, 236)):
        put(person((220, 140, 40), hat=CRANE), x, y)
    pools += [(150, 200, 130, LAMP_HOT, 0.45), (230, 170, 80, LAMP_HOT, 0.4)]

    # market square
    colors = [NAVY, (190, 70, 70), (70, 150, 110), (200, 140, 50), (140, 80, 170), (60, 140, 170)]
    for i, (x, b) in enumerate(((616, 590), (668, 590), (720, 590), (626, 648), (680, 648), (734, 648))):
        put(market_stall(rng, colors[i]), x, b)
        pools.append((x + 24, b - 8, 46, LAMP, 0.45))
    for _ in range(10):
        put(citizen(rng), rng.randrange(612, 770), rng.randrange(560, 656))
    put(shady(), 702, 616)  # a pickpocket working the crowd

    # the alley: a broken lamp, a deal in the dark, a lookout and a ship stripped for parts
    put(street_lamp(broken=True), 436, 770)
    put(shady(), 414, 800)
    put(shady(), 428, 802)
    put(shady(), 446, 732)
    put(small_ship((50, 52, 64), flying=False, lights=False), 426, 864)
    put(crates(1, False), 456, 870)
    sprites.append((801, 423, _package()))

    # footpath and promenade lamps, and semaphores at the canal junctions
    for pts in PATHS:
        _lamps_along(pts, 13, 7, 64, put, pools, skip=[(x, y) for x, y, _ in crossings])
    for pts in CANALS:
        _lamps_along(pts, 30, 24, 64, put, pools, skip=[(x, y) for x, y, _ in crossings] + JUNCTIONS)
    for jx, jy in JUNCTIONS:
        for dx, dy, lit in ((-34, -28, 0), (34, -28, 2), (-34, 34, 2), (34, 34, 0)):
            put(semaphore(lit), jx + dx - 5, jy + dy)

    # the cruiser at its piers, bow to the north and engines idling at the stern
    put(cruiser(rng, 920), 1820, 1152)
    for y0, y1 in PIERS:
        put(soldier(), 1694, y1 - 4)
        put(person(NAVY, hat=WHITE), rng.randrange(1720, 1820), y1 - 4)
        put(street_lamp(WIN_COOL), 1760, y0 + 2)
        pools.append((1780, (y0 + y1) / 2, 80, WIN_COOL, 0.4))
    put(crates(3), 1740, 668)
    put(crates(4), 1700, 1000)
    for x, y in ((1700, 380), (1710, 760), (1700, 960)):
        put(soldier(), x, y)
    pools += [(1985, 400, 120, WIN_COOL, 0.22), (1985, 700, 140, WIN_COOL, 0.22), (1985, 960, 120, WIN_COOL, 0.22)]
    for nx, r in ((72, 30), (120, 36), (165, 44), (210, 36), (258, 30)):
        pools.append((1820 + nx, 1126, r, THRUST, 0.55))

    # the punk park and its disco: the only colored lights in Iskra
    put(disco(rng), 1350, 1110)
    put(graffiti_wall(rng, 120), 1270, 1010)
    put(graffiti_wall(rng, 90), 1480, 1000)
    put(graffiti_wall(rng, 100), 1380, 1170)
    put(half_pipe(), 1270, 1140)
    put(fire_barrel(), 1300, 1070)
    put(fire_barrel(), 1520, 1090)
    for x, b in ((1250, 990), (1540, 1040), (1500, 1150), (1450, 980)):
        put(wire_tree(rng, NEONS), x, b)
    for _ in range(14):
        put(punk(rng), rng.randrange(1300, 1540), rng.randrange(1112, 1160))
    put(person((40, 36, 52), hat=INK), 1410, 1116)  # doorman
    for i, col in enumerate(NEONS):
        park_pools.append((1350 + i * 28, 1124 + (i % 2) * 14, 64, col, 0.55))
    pools += [(1306, 1066, 40, FIRE, 0.5), (1526, 1086, 40, FIRE, 0.5)]
    for end, col in zip(((1262, 1030), (1330, 964), (1500, 968), (1580, 1060)),
                        (NEON_PINK, NEON_CYAN, NEON_YELLOW, NEON_GREEN)):
        beams.append(((1420, 990), end, col))

    # people on the footpaths and promenades, and police on patrol
    for pts in PATHS + CANALS:
        for _ in range(4):
            x, y = _along(pts, rng.random())
            if L["paths"][int(min(H - 1, y)), int(min(W - 1, x))] or L["promenades"][int(min(H - 1, y + 24)), int(min(W - 1, x))]:
                put(citizen(rng), int(x) - 8, int(y) + 10)
    for x, y in ((520, 712), (1140, 520), (300, 900), (1330, 912), (700, 470)):
        put(police(), x, y)

    def put_house(sprite, x, bottom):
        # Keep the rest of the city identical when this residential block becomes a park.
        if x < 509 and x + sprite.width > 304 and bottom > 530 and bottom - sprite.height < 706:
            return
        put(sprite, x, bottom)

    fill_lots(L, occ, rng, put_house, pools)
    for index, (x, bottom) in enumerate(NATURE_TREES + CITY_TREES):
        put(leafy_tree(index), x, bottom)
    for x, bottom in [(357, 613), (434, 642), (801, 423), (975, 423)]:
        put(park_bench(), x, bottom)
    for x, bottom in [(335, 661), (464, 557), (1724, 576)]:
        put(street_lamp(LAMP_HOT), x, bottom)
        pools.append((x+6, bottom, 65, LAMP_HOT, .36))
    put(npc("greenhouse_worker"), 382, 585)
    put(npc("library_archivist"), 414, 658)
    pools.append((409, 608, 145, (232, 246, 211), .34))

    # ships in the canals, and personal ships on the sky lanes with their buoys
    _canal_traffic(rng, air, pools, crossings)
    lane_a = [(0, 380), (700, 330), (1400, 360), (W, 300)]
    lane_b = [(200, H), (800, 800), (1500, 520), (W, 160)]
    def clear_of_landmarks(img, x, y):
        return not any(x < rx1 and x + img.width > rx0 and y - img.height < ry1 and y > ry0
                       for rx0, ry0, rx1, ry1 in landmarks)

    for lane, n in ((lane_a, 22), (lane_b, 20)):
        for k in range(n):
            t = (k + rng.random() * 0.6) / n
            x, y = _along(lane, t)
            size = 2 if rng.random() < 0.12 else 1
            img = small_ship(rng.choice(SHIP_COLORS), rng.choice((1, -1)), True, size)
            x, y = int(x), int(y) + rng.randint(-8, 8)
            if clear_of_landmarks(img, x, y):
                air.append((img, x, y, 26))
    for t in (0.1, 0.3, 0.55, 0.8):
        for lane in (lane_a, lane_b):
            x, y = _along(lane, t)
            buoy = sky_buoy(SIG_AMBER)
            if clear_of_landmarks(buoy, int(x), int(y) - 14):
                air.append((buoy, int(x), int(y) - 14, 30))
    return sprites, air, pools, park_pools, beams, (lane_a, lane_b)


def _along(pts, t):
    lengths = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])]
    s = t * sum(lengths)
    for (a, b), length in zip(zip(pts, pts[1:]), lengths):
        if s <= length:
            return a[0] + (b[0] - a[0]) * s / length, a[1] + (b[1] - a[1]) * s / length
        s -= length
    return pts[-1]


def _package():
    img, d = new(6, 6)
    d.rectangle((0, 0, 5, 5), fill=NEON_GREEN, outline=INK)
    return img


def lantern_house(rng):
    """A narrow house on the alley: paper lanterns under the eaves, a boarded window
    and a door left open on a lamp-lit room."""
    img, d = new(88, 76)
    d.rectangle((6, 26, 82, 74), fill=LANTERN_HOUSE, outline=INK)
    d.polygon([(0, 28), (12, 12), (76, 12), (88, 28)], fill=(58, 40, 50), outline=INK)
    for x in range(14, 76, 6):
        d.line([(x, 14), (x - 2, 26)], fill=(46, 32, 42))
    d.rectangle((12, 38, 28, 52), fill=(46, 36, 44), outline=INK)
    d.line([(12, 41), (28, 49)], fill=(120, 92, 64), width=2)
    d.line([(12, 49), (28, 43)], fill=(120, 92, 64), width=2)
    d.rectangle((60, 38, 76, 52), fill=(110, 30, 40), outline=INK)
    d.rectangle((38, 50, 52, 74), fill=INK)
    d.rectangle((38, 50, 44, 74), fill=FIRE)
    d.line([(4, 30), (84, 30)], fill=INK)
    for x in (8, 26, 62, 80):
        d.line([(x, 30), (x, 33)], fill=INK)
        d.ellipse((x - 4, 33, x + 4, 43), fill=FIRE, outline=INK)
        d.line([(x - 3, 38), (x + 3, 38)], fill=(150, 30, 40))
    sign(img, 44, 0, "NO QUESTIONS", bg=INK, fg=FIRE)
    return img


def coil_pylon(rng):
    """A Tesla coil on the palace terrace: a copper-wound column under a toroid."""
    img, d = new(52, 108)
    d.rectangle((12, 96, 40, 106), fill=STEEL_DARK, outline=INK)
    d.rectangle((19, 34, 33, 98), fill=COPPER_DARK, outline=INK)
    for y in range(36, 96, 3):
        d.line([(20, y), (32, y)], fill=COPPER_LIGHT if (y // 3) % 2 else COPPER)
    d.ellipse((6, 18, 46, 38), fill=STEEL_LIGHT, outline=INK)
    d.ellipse((16, 24, 36, 32), fill=STEEL_DARK, outline=INK)
    d.ellipse((22, 12, 30, 20), fill=ARC_CORE, outline=INK)
    jagged(d, (26, 14), (2, 2), rng, steps=4, spread=3)
    jagged(d, (26, 14), (50, 4), rng, steps=4, spread=3)
    return img


# ---------- night lighting ----------

def light_pools(pools, shape):
    h, w = shape
    light = np.zeros((h, w, 3), np.float32)
    for cx, cy, r, color, strength in pools:
        x0, x1 = max(0, int(cx - r)), min(w, int(cx + r) + 1)
        y0, y1 = max(0, int(cy - r * 0.62)), min(h, int(cy + r * 0.62) + 1)
        if x0 >= x1 or y0 >= y1:
            continue
        ys, xs = np.mgrid[y0:y1, x0:x1]
        dist = np.sqrt(((xs - cx) / r) ** 2 + ((ys - cy) / (r * 0.62)) ** 2)
        # a soft falloff cut into six flat steps, so pools stay pixel-like without hard rings
        level = np.floor(np.clip(1.0 - dist, 0.0, 1.0) ** 1.4 * 6.0) / 6.0
        light[y0:y1, x0:x1] += level[..., None] * (np.array(color, np.float32) / 255.0) * strength
    return light


def beam_layer(beams, shape):
    img = Image.new("RGB", (shape[1], shape[0]), (0, 0, 0))
    d = ImageDraw.Draw(img)
    for (sx, sy), (ex, ey), color in beams:
        dx, dy = ex - sx, ey - sy
        length = math.hypot(dx, dy)
        nx, ny = -dy / length, dx / length
        spread = 30
        d.polygon([(sx, sy), (ex + nx * spread, ey + ny * spread), (ex - nx * spread, ey - ny * spread)],
                  fill=tuple(int(c * 0.55) for c in color))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(4)), np.float32) / 255.0


def park_clip():
    """1 inside the punk park and 0 outside, with a short soft edge, in canvas coordinates.
    The park's colored light is multiplied by it so none of it falls on the streets."""
    m = Image.new("L", (W, CANVAS_H), 0)
    ImageDraw.Draw(m).polygon([(x, y + MARGIN) for x, y in PARK], fill=255)
    return np.asarray(m.filter(ImageFilter.GaussianBlur(5)), np.float32)[..., None] / 255.0


def shade_pixels(arr, light):
    return arr * np.array([0.58, 0.48, 0.38], np.float32) + arr * light * 1.20 + light * 26.0


def night(img, pools, park_pools, beams):
    arr = np.asarray(img.convert("RGB"), np.float32)
    rgb = arr.astype(np.int32)
    key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
    emissive = np.isin(key, [(r << 16) | (g << 8) | b for r, g, b in EMISSIVE])
    park = light_pools(park_pools, arr.shape[:2]) + beam_layer(beams, arr.shape[:2])
    light = light_pools(pools, arr.shape[:2]) + park * park_clip()
    out = shade_pixels(arr, light)
    out[emissive] = arr[emissive]
    glow_src = Image.fromarray(np.where(emissive[..., None], arr, 0).astype(np.uint8))
    for radius, amount in ((2, 0.9), (7, 0.55)):
        out += np.asarray(glow_src.filter(ImageFilter.GaussianBlur(radius)), np.float32) * amount
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def render():
    rng = random.Random(4)
    L = layout()
    img = space(rng)
    img.alpha_composite(build_ground(rng, L), (0, MARGIN))
    sprites, air, pools, park_pools, beams, lanes = place_city(rng, L)
    # everything below is placed in city coordinates and drawn MARGIN lower
    for bottom, x, sprite in sorted(sprites, key=lambda s: s[0]):
        bottom += MARGIN
        shadow = Image.new("RGBA", (sprite.width, 8), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse((2, 0, sprite.width - 3, 7), fill=SHADOW)
        img.alpha_composite(shadow, (x, bottom - 4))
        img.alpha_composite(sprite, (x, bottom - sprite.height))
    # sky lanes and flying craft, with their shadows on the ground below
    d = ImageDraw.Draw(img)
    for lane in lanes:
        dashed(d, [(x, y + MARGIN) for x, y in lane], (120, 130, 150), 6, 10)
    shadows = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadows)
    for sprite, x, y, height in air:
        y += MARGIN
        sd.ellipse((x + 3, y + height, x + sprite.width - 3, y + height + 5), fill=SHADOW)
    img.alpha_composite(shadows)
    for sprite, x, y, height in sorted(air, key=lambda a: a[2]):
        img.alpha_composite(sprite, (x, y + MARGIN - sprite.height))
        if sprite.width > 20 or sprite.height > 20:
            pools.append((x + sprite.width // 2, y + min(height, 18), 24, THRUST, 0.22))
    pools = [(x, y + MARGIN, r, c, s) for x, y, r, c, s in pools]
    park_pools = [(x, y + MARGIN, r, c, s) for x, y, r, c, s in park_pools]
    beams = [((sx, sy + MARGIN), (ex, ey + MARGIN), c) for (sx, sy), (ex, ey), c in beams]
    return night(img, pools, park_pools, beams)


def main():
    img = render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(OUT, img.size)
    for path, box in ((DETAIL_OUT, (590, 40, 1230, 400)), (STREETS_OUT, (240, 600, 880, 960)),
                      (PARK_OUT, (1080, 900, 1720, 1260)), (DOCK_OUT, (1560, 380, 2200, 740))):
        img.crop(box).resize((1280, 720), Image.NEAREST).save(path)
        print(path, (1280, 720))


if __name__ == "__main__":
    main()
