#!/usr/bin/python3
"""Concept sheet for the space rock chapter, to check the design before building.

On the way to Breece, Davor asks to stop at a small rock. Veki stays with the
Lasta and flies off when Martin's ship comes; Martin's raiders beat the MC and
Davor, take Davor and leave the MC injured. The MC goes into the cave Davor
opened, where the Voice in the Dark, an old Brine and Davor's former apprentice,
is buried. The merge with the Voice makes the MC a Brine: more health, more
attack, and white or black eyes.

The sheet shows:
- the rock's surface, with the landed Lasta, Martin's ship and the cave mouth
  under old Republic scaffolding;
- the cave: the tunnel, Davor's old camp and the grave chamber;
- the Voice over the grave;
- Martin, two raiders, and the MC before and after (white and black eyes).

Martin and Davor are Admins; the Voice was one. Martin wears the Admin badge;
the badge on the Voice's broken mask is scratched off.

Writes art/concepts/space_rock_concept.png. Areas are drawn at half size, like
the Lasta's rooms, and shown at 2x.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFilter

import create_otpornik_ship_art as ship
from create_otpornik_ship_art import (INK, SPACE, STAR, IRON, IRON_LIGHT, RUST, RUST_DARK, BRASS, RED,
                                      CREAM, YELLOW, GLOW, FONT, canvas, stains)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/space_rock_concept.png"

ROCK = (104, 94, 110)
ROCK_LIGHT = (134, 124, 138)
ROCK_DARK = (74, 66, 82)
ROCK_DEEP = (52, 46, 60)
DUST = (120, 108, 116)
CAVE_FLOOR = (84, 76, 92)
CAVE_RIM = (58, 52, 66)
CAVE_WALL = (30, 26, 38)
CAVE_LIGHT = (70, 62, 76)
MOSS = (70, 120, 110)
MOSS_GLOW = (120, 210, 190)
COAT = (34, 32, 44)
COAT_LIGHT = (62, 60, 76)
PALE = (214, 196, 178)
SILVER = (196, 200, 212)
VOICE = (200, 236, 255)
VOICE_DIM = (110, 160, 200)
# The Republic's colours are navy and gold, as on the Artichoke soldiers.
NAVY = (36, 52, 104)
NAVY_DARK = (24, 32, 70)
NAVY_LIGHT = (70, 96, 170)
GOLD = (245, 195, 76)
GOLD_DARK = (190, 140, 50)
MARTIN_HULL = (40, 50, 86)
MARTIN_HULL_LIGHT = (70, 84, 130)
# Kept for a future hacker design, not the Republic.
HACKER_RED = (170, 44, 44)


def admin_badge(d, x, y, scratched=False):
    """The Admin badge on the Voice's mask: a gold ring round a small triangle."""
    d.ellipse((x - 2, y - 2, x + 2, y + 2), outline=GOLD)
    d.point((x, y - 1), fill=GOLD)
    d.line((x - 1, y + 1, x + 1, y + 1), fill=GOLD)
    if scratched:
        d.line((x - 3, y - 3, x + 3, y + 2), fill=INK)
        d.line((x - 2, y + 3, x + 3, y - 2), fill=INK)


# ---------- characters ----------

def hacker_concept():
    """Kept for a future hacker: long black coat, high collar, red arm band, rod with a red tip.

    This was the first Martin design; the Republic is navy and gold, so Martin
    was redrawn and this one waits for a hacker."""
    img, d = canvas(18, 26)
    d.ellipse((3, 22, 15, 25), fill=(28, 23, 48, 95))
    # boots under the coat
    d.rectangle((6, 21, 8, 24), fill=INK)
    d.rectangle((10, 21, 12, 24), fill=INK)
    # long coat from the collar to below the knees, open down the front
    d.rectangle((4, 10, 14, 21), fill=COAT)
    d.line((4, 10, 4, 21), fill=INK)
    d.line((14, 10, 14, 21), fill=INK)
    d.line((5, 11, 5, 20), fill=COAT_LIGHT)
    d.line((9, 13, 9, 21), fill=INK)
    d.line((4, 16, 14, 16), fill=(60, 58, 70))  # belt
    # high collar
    d.rectangle((5, 9, 13, 10), fill=COAT_LIGHT)
    # arms: a red Republic band on the left one, pale hands
    d.rectangle((2, 11, 3, 18), fill=COAT)
    d.line((2, 13, 3, 13), fill=HACKER_RED)
    d.point((2, 19), fill=PALE)
    d.point((3, 19), fill=PALE)
    d.rectangle((15, 11, 16, 18), fill=COAT)
    d.point((15, 19), fill=PALE)
    # a short black rod with a red tip in the right hand
    d.line((16, 15, 16, 22), fill=INK)
    d.point((16, 14), fill=(240, 80, 70))
    # the Admin badge: two silver pixels on the chest
    d.point((11, 12), fill=SILVER)
    d.point((12, 12), fill=SILVER)
    # head: pale face, black hair combed back, a cold grey eye
    d.rectangle((6, 3, 11, 8), fill=PALE)
    d.rectangle((6, 2, 11, 3), fill=(30, 28, 36))
    d.line((6, 2, 6, 8), fill=(30, 28, 36))
    d.line((11, 4, 11, 8), fill=(190, 172, 156))
    d.point((9, 6), fill=(150, 156, 172))
    return img


STRIP = (245, 195, 76)
STRIP_HAND = (247, 241, 221)


def without_strip(img):
    """Replace the old template's yellow strip and hilt by the right hand with a plain arm.

    The strip is two columns wide; the left arm sits nine columns to its left,
    so its pixels are copied across, and everything right of the new arm in
    those rows is cleared, apart from the ground shadow.
    """
    img = img.copy()
    px = img.load()
    # the strip is a column of at least four yellow pixels; single ones are buckles
    cols = [x for x in range(img.width // 2, img.width) if sum(px[x, y][:3] == STRIP for y in range(img.height)) >= 4]
    if not cols:
        return img
    x0 = min(cols)
    rows = [y for y in range(img.height) if px[x0, y][:3] in (STRIP, STRIP_HAND)]
    for y in range(min(rows), max(rows) + 2):
        if y <= max(rows):
            px[x0, y] = px[x0 - 9, y]
        for x in range(x0 + 1, img.width):
            if px[x, y][3] > 200:
                px[x, y] = (0, 0, 0, 0)
    return img


def martin():
    """Martin, 18x26 like Davor: an Admin in a long navy coat with gold trim and a high collar."""
    img, d = canvas(18, 26)
    d.ellipse((3, 22, 15, 25), fill=(28, 23, 48, 95))
    d.rectangle((6, 21, 8, 24), fill=INK)
    d.rectangle((10, 21, 12, 24), fill=INK)
    # long navy coat, gold edging down the front and at the hem
    d.rectangle((4, 10, 14, 21), fill=NAVY)
    d.line((4, 10, 4, 21), fill=INK)
    d.line((14, 10, 14, 21), fill=INK)
    d.line((5, 11, 5, 20), fill=NAVY_LIGHT)
    d.line((9, 12, 9, 21), fill=GOLD_DARK)
    d.line((5, 21, 13, 21), fill=GOLD_DARK)
    d.line((5, 16, 13, 16), fill=NAVY_DARK)  # belt
    d.point((9, 16), fill=GOLD)
    # high collar and gold shoulder boards
    d.rectangle((5, 9, 13, 10), fill=NAVY_DARK)
    d.line((5, 10, 6, 10), fill=GOLD)
    d.line((12, 10, 13, 10), fill=GOLD)
    # arms with gold cuffs, pale hands
    d.rectangle((2, 11, 3, 18), fill=NAVY)
    d.line((2, 18, 3, 18), fill=GOLD)
    d.point((2, 19), fill=PALE)
    d.point((3, 19), fill=PALE)
    d.rectangle((15, 11, 16, 18), fill=NAVY)
    d.point((15, 18), fill=GOLD)
    d.point((15, 19), fill=PALE)
    # a short black rod with a pale gold tip
    d.line((16, 15, 16, 22), fill=INK)
    d.point((16, 14), fill=(255, 236, 160))
    # the Admin badge: gold on the chest
    d.point((11, 12), fill=GOLD)
    d.point((12, 12), fill=GOLD)
    d.point((11, 13), fill=GOLD_DARK)
    # head: pale face, black hair combed back, a cold grey eye
    d.rectangle((6, 3, 11, 8), fill=PALE)
    d.rectangle((6, 2, 11, 3), fill=(30, 28, 36))
    d.line((6, 2, 6, 8), fill=(30, 28, 36))
    d.line((11, 4, 11, 8), fill=(190, 172, 156))
    d.point((9, 6), fill=(150, 156, 172))
    return img


def raider(seed):
    """Martin's soldiers: Republic soldiers in navy and gold, as on Artichoke."""
    name = "republic_soldier_2.png" if seed else "republic_soldier.png"
    return Image.open(ROOT / "assets/art/artichoke/objects" / name).convert("RGBA")


def hacker_soldier(seed):
    """Kept for future hackers' soldiers: the company crew in dark red, one with a helmet."""
    src = without_strip(Image.open(ROOT / "assets/art/skoljka/company_crew.png").convert("RGBA"))
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a and g > r + 20 and g >= b - 10:  # teal cloth to dark red
                px[x, y] = (min(255, g), int(b * .35), int(b * .35), a)
    if seed:
        d = ImageDraw.Draw(src)
        d.rectangle((5, 1, 12, 4), fill=IRON, outline=INK)
        d.line((6, 4, 11, 4), fill=HACKER_RED)
    return src


def mc(eyes=None):
    """The MC; after the merge the eye turns white or black and a faint light rises off him."""
    src = Image.open(ROOT / "assets/art/player_plain.png").convert("RGBA")
    if eyes is None:
        return src
    src.putpixel((8, 6), {"white": (250, 250, 255, 255), "black": (10, 8, 14, 255)}[eyes])
    big = Image.new("RGBA", (src.width + 6, src.height + 6))
    glow = Image.new("RGBA", big.size)
    mask = src.split()[3].point(lambda a: 255 if a > 100 else 0)
    glow.paste(Image.new("RGBA", src.size, VOICE + (150,)), (3, 3), mask)
    glow = glow.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(.6))
    big.alpha_composite(glow)
    big.alpha_composite(src, (3, 3))
    return big


def sprite(img, path):
    return without_strip(Image.open(ROOT / path).convert("RGBA")) if img is None else img


# ---------- the rock's surface ----------

def starfield(img, rng, count):
    d = ImageDraw.Draw(img)
    for _ in range(count):
        d.point((rng.randrange(img.width), rng.randrange(img.height)), fill=rng.choice((STAR, GLOW, (120, 110, 170))))


def crater(d, x, y, r):
    d.ellipse((x - r, y - r * .55, x + r, y + r * .55), fill=ROCK_DARK)
    d.ellipse((x - r + 2, y - r * .55 + 2, x + r - 1, y + r * .55), fill=ROCK_DEEP)
    d.arc((x - r, y - r * .55, x + r, y + r * .55), 200, 340, fill=ROCK_LIGHT)


def martin_ship():
    """Side view, nose left: a narrow navy hull with hard angles and a gold Republic stripe."""
    img, d = canvas(132, 60)
    d.polygon([(4, 30), (30, 14), (112, 12), (128, 22), (128, 38), (112, 44), (30, 44)], fill=MARTIN_HULL, outline=INK)
    d.polygon([(30, 14), (112, 12), (118, 18), (36, 20)], fill=MARTIN_HULL_LIGHT)
    d.polygon([(10, 30), (28, 20), (40, 20), (32, 30)], fill=ship.GLASS, outline=INK)  # canopy
    d.line((14, 28, 28, 22), fill=ship.GLASS_LIGHT)
    for x in range(48, 108, 12):
        d.line((x, 14, x - 2, 44), fill=INK)
    d.rectangle((118, 20, 130, 26), fill=IRON, outline=INK)
    d.rectangle((118, 30, 130, 36), fill=IRON, outline=INK)
    for x in (52, 76, 100):
        d.point((x, 40), fill=GOLD)
    # gold Republic stripe and the ramp down
    d.line((44, 34, 110, 33), fill=GOLD, width=2)
    d.polygon([(70, 44), (90, 44), (98, 58), (64, 58)], fill=IRON_LIGHT, outline=INK)
    for x in (40, 104):
        d.line((x, 44, x - 4, 56), fill=INK, width=2)
        d.line((x - 8, 56, x, 56), fill=INK, width=2)
    return img


SURFACE_W, SURFACE_H = 480, 300
LASTA_AT = (40, 166)        # top left of the Lasta sprite
MARTIN_SHIP_AT = (318, 176)  # top left of Martin's ship


def boulder(d, x, y, r):
    d.ellipse((x - r, y - r * .7, x + r, y + r * .7), fill=ROCK_DARK, outline=INK)
    d.ellipse((x - r + 2, y - r * .7 + 1, x + r * .3, y), fill=ROCK_LIGHT)


def surface(ships=True):
    """The rock's surface, 480x300 at half size: room for the landing, the raid and the walk to the cave.

    Without ships it is the game's ground: the world script places the Lasta
    and Martin's ship as sprites, since both come and go."""
    rng = random.Random(41)
    img, d = canvas(SURFACE_W, SURFACE_H, SPACE + (255,))
    starfield(img, rng, 300)
    cx, cy = SURFACE_W / 2, SURFACE_H / 2 + 14
    # the rock: an uneven blob, the far edge falling away into space
    pts = []
    for i in range(64):
        a = i / 64 * math.tau
        r = 1 + .05 * math.sin(a * 5 + 1) + .03 * math.sin(a * 11) + .02 * math.sin(a * 17)
        pts.append((cx + math.cos(a) * 252 * r, cy + math.sin(a) * 148 * r))
    d.polygon(pts, fill=ROCK_DARK)
    inner = [(cx + (x - cx) * .975, cy + 2 + (y - cy) * .96) for x, y in pts]
    d.polygon(inner, fill=ROCK)
    stains(d, rng, (10, 30, 470, 296), 320, (ROCK_LIGHT, ROCK_DARK, DUST), (2, 5))
    for x, y, r in ((70, 248, 18), (400, 260, 14), (300, 150, 9), (130, 140, 8), (440, 160, 11),
                    (230, 280, 12), (170, 220, 7), (360, 120, 8), (40, 130, 10), (270, 220, 6)):
        crater(d, x, y, r)
    for x, y, r in ((110, 110, 7), (96, 116, 4), (380, 96, 6), (210, 250, 5), (450, 210, 6), (20, 190, 5)):
        boulder(d, x, y, r)
    # ridge at the back with the cave mouth under rusted scaffolding
    ox, oy = 80, 14
    d.polygon([(70 + ox, 52 + oy), (100 + ox, 30 + oy), (140 + ox, 24 + oy), (190 + ox, 28 + oy), (230 + ox, 44 + oy),
               (240 + ox, 64 + oy), (60 + ox, 66 + oy)], fill=ROCK_DEEP, outline=INK)
    d.polygon([(80 + ox, 60 + oy), (104 + ox, 38 + oy), (140 + ox, 32 + oy), (186 + ox, 36 + oy), (222 + ox, 52 + oy),
               (228 + ox, 64 + oy)], fill=ROCK_DARK)
    d.chord((134 + ox, 40 + oy, 170 + ox, 80 + oy), 180, 360, fill=INK)
    d.rectangle((134 + ox, 60 + oy, 170 + ox, 66 + oy), fill=INK)
    # the door slab Davor pushed aside, and a faded survey sign
    d.polygon([(172 + ox, 46 + oy), (184 + ox, 48 + oy), (182 + ox, 66 + oy), (170 + ox, 66 + oy)], fill=IRON, outline=INK)
    for x in (126, 178):
        d.line((x + ox, 30 + oy, x + ox, 66 + oy), fill=RUST, width=2)
    d.line((124 + ox, 32 + oy, 180 + ox, 32 + oy), fill=RUST, width=2)
    d.line((126 + ox, 44 + oy, 178 + ox, 44 + oy), fill=RUST_DARK)
    d.line((126 + ox, 30 + oy, 150 + ox, 44 + oy), fill=RUST_DARK)
    d.rectangle((136 + ox, 22 + oy, 166 + ox, 30 + oy), fill=(150, 140, 110), outline=INK)
    d.text((138 + ox, 21 + oy), "R-7", font=ship.FONT, fill=NAVY)
    # old Republic crates, a broken survey mast and a smaller ridge on the right
    for x, y in ((176, 86), (186, 90), (290, 88), (420, 230)):
        d.rectangle((x, y, x + 9, y + 7), fill=(110, 104, 92), outline=INK)
        d.line((x + 1, y + 2, x + 8, y + 2), fill=GOLD_DARK)
    d.line((350, 110, 362, 80), fill=IRON_LIGHT, width=2)
    d.line((362, 80, 372, 86), fill=IRON_LIGHT)
    d.polygon([(390, 120), (410, 100), (440, 104), (456, 126), (420, 132)], fill=ROCK_DEEP, outline=INK)
    d.polygon([(40, 100), (60, 84), (84, 88), (90, 104), (60, 110)], fill=ROCK_DEEP, outline=INK)
    # footprints from the landing to the cave
    for i in range(22):
        t = i / 21
        x, y = 100 + (232 - 100) * t, 222 + (82 - 222) * t
        d.point((int(x + (i % 2) * 2), int(y)), fill=ROCK_DEEP)
    if not ships:
        return img
    # the Lasta on the left, Martin's ship on the right
    lasta = ship.ship_exterior().resize((110, 56), Image.NEAREST)
    lx, ly = LASTA_AT
    d.ellipse((lx, ly + 44, lx + 110, ly + 58), fill=ROCK_DEEP)
    img.alpha_composite(lasta, LASTA_AT)
    mx, my = MARTIN_SHIP_AT
    d.ellipse((mx + 4, my + 48, mx + 128, my + 60), fill=ROCK_DEEP)
    img.alpha_composite(martin_ship(), MARTIN_SHIP_AT)
    return img


def place(img, figure, x, bottom):
    img.alpha_composite(figure, (int(x - figure.width / 2), int(bottom - figure.height)))


def surface_raid():
    """The surface during the raid: the Lasta gone, raiders round the MC and Davor."""
    img = surface()
    d = ImageDraw.Draw(img)
    # the Lasta has left: only its landing marks
    lx, ly = LASTA_AT
    d.rectangle((lx - 4, ly - 2, lx + 114, ly + 60), fill=ROCK)
    rng = random.Random(41)
    stains(d, rng, (lx, ly + 10, lx + 110, ly + 58), 30, (ROCK_LIGHT, ROCK_DARK, DUST), (2, 5))
    for x in (20, 50, 86):
        d.rectangle((lx + x, ly + 50, lx + x + 6, ly + 54), fill=ROCK_DEEP)
    d.line((lx + 50, ly - 8, 20, 4), fill=GLOW)  # the Lasta's trail into space
    d.line((lx + 51, ly - 8, 21, 4), fill=(120, 110, 170))
    place(img, mc(), 222, 132)
    place(img, sprite(None, "assets/art/engineeria/davor.png"), 242, 134)
    place(img, martin(), 300, 176)
    for x, y, s in ((196, 142, 0), (268, 128, 1), (206, 164, 1), (258, 156, 0), (316, 150, 0), (180, 120, 1)):
        place(img, raider(s), x, y)
    return img


# ---------- the cave ----------

def cave(lit=False):
    """Tunnel from the mouth (bottom left) to the grave chamber (right), 288x176."""
    rng = random.Random(7)
    img, d = canvas(288, 176, CAVE_WALL + (255,))
    # floor: a winding tunnel and a round chamber
    path = [(20, 160), (40, 130), (70, 118), (110, 112), (140, 96), (170, 84), (196, 82)]
    for grow, color in ((5, CAVE_RIM), (0, CAVE_FLOOR)):
        for (x0, y0), (x1, y1) in zip(path, path[1:]):
            for t in range(12):
                x, y = x0 + (x1 - x0) * t / 12, y0 + (y1 - y0) * t / 12
                d.ellipse((x - 18 - grow, y - 12 - grow, x + 18 + grow, y + 12 + grow), fill=color)
        d.ellipse((168 - grow, 30 - grow, 280 + grow, 140 + grow), fill=color)
    # stalagmites along the walls
    for x, y in ((30, 118), (86, 92), (150, 74), (196, 46), (270, 96), (182, 132), (120, 134)):
        d.polygon([(x - 4, y + 6), (x, y - 8), (x + 4, y + 6)], fill=ROCK_DARK, outline=INK)
        d.line((x - 1, y - 4, x - 2, y + 4), fill=ROCK_LIGHT)
    stains(d, rng, (10, 30, 280, 170), 120, ((96, 88, 104), CAVE_RIM, (74, 66, 82)), (1, 4))
    # wall edge highlights and rubble
    for _ in range(60):
        x, y = rng.randrange(288), rng.randrange(176)
        if img.getpixel((x, y))[:3] == CAVE_WALL:
            d.point((x, y), fill=ROCK_DEEP)
    for x, y in ((50, 140), (96, 120), (150, 104), (186, 128), (264, 70)):
        d.polygon([(x, y), (x + 5, y - 3), (x + 9, y + 1), (x + 4, y + 3)], fill=ROCK_DARK, outline=INK)
    # glowing moss in the cracks: the only light before the merge
    for x, y in ((64, 116), (120, 100), (176, 60), (250, 112), (230, 44)):
        for i in range(5):
            d.point((x + rng.randint(-4, 4), y + rng.randint(-2, 2)), fill=MOSS_GLOW if i % 2 else MOSS)
    # Davor's old camp: bedroll, cold fire ring, a crate, notes pinned to the wall
    d.rectangle((92, 96, 112, 102), fill=(110, 80, 60), outline=INK)
    d.line((94, 99, 110, 99), fill=(140, 104, 76))
    d.ellipse((118, 104, 128, 110), outline=ROCK_LIGHT)
    d.point((123, 107), fill=(90, 60, 50))
    d.rectangle((80, 100, 88, 106), fill=(110, 104, 92), outline=INK)
    for x in (100, 106):
        d.rectangle((x, 88, x + 4, 92), fill=CREAM, outline=INK)
    # a Republic triangle painted on the tunnel wall, half scraped off
    d.polygon([(40, 112), (48, 98), (56, 112)], outline=GOLD_DARK)
    d.line((44, 112, 52, 100), fill=CAVE_WALL)
    # the grave: a stone cairn with the Voice's broken mask set in it
    d.ellipse((206, 70, 250, 92), fill=ROCK_DEEP)
    for i, (x, y) in enumerate(((212, 80), (222, 76), (234, 78), (242, 82), (216, 70), (230, 68), (224, 62))):
        d.ellipse((x - 6, y - 5, x + 6, y + 4), fill=(ROCK_DARK, ROCK, ROCK_LIGHT)[i % 3], outline=INK)
    d.rectangle((218, 54, 230, 66), fill=IRON_LIGHT, outline=INK)
    d.line((220, 58, 228, 58), fill=GLOW)
    d.line((224, 54, 222, 66), fill=INK)  # the crack across the mask
    admin_badge(d, 227, 63, scratched=True)
    # Davor's candle stubs and a carved line on the slab
    for x in (206, 246):
        d.rectangle((x, 84, x + 2, 88), fill=CREAM)
    d.line((214, 94, 236, 94), fill=ROCK_LIGHT)
    if not lit:
        # darkness: only the moss and the faint mask glow show
        dark = Image.new("RGBA", img.size, (6, 4, 12, 190))
        holes = Image.new("L", img.size, 0)
        hd = ImageDraw.Draw(holes)
        for x, y, r in ((64, 116, 18), (120, 100, 18), (176, 60, 16), (250, 112, 16), (230, 44, 14), (224, 62, 28), (24, 158, 30), (100, 100, 16)):
            hd.ellipse((x - r, y - r, x + r, y + r), fill=255)
        holes = holes.filter(ImageFilter.GaussianBlur(6))
        dark.putalpha(Image.eval(holes, lambda a: 190 - a * 150 // 255))
        img.alpha_composite(dark)
    return img


def voice_scene():
    """The grave chamber when the Voice speaks: a tall soldier's outline in pale light over the cairn."""
    full = cave()
    img = full.crop((168, 6, 288, 130))
    d = ImageDraw.Draw(img)
    glow = Image.new("RGBA", img.size)
    gd = ImageDraw.Draw(glow)
    cx = 58
    body = Image.new("RGBA", img.size)
    bd = ImageDraw.Draw(body)
    # head with a visor slit, broad armoured shoulders, a long body fading into the cairn
    bd.rounded_rectangle((cx - 7, 4, cx + 7, 20), 4, fill=VOICE + (70,), outline=VOICE)
    bd.line((cx - 4, 11, cx + 4, 11), fill=VOICE, width=2)
    bd.polygon([(cx - 4, 20), (cx + 4, 20), (cx + 5, 24), (cx - 5, 24)], fill=VOICE + (60,))
    bd.polygon([(cx - 18, 26), (cx - 6, 23), (cx + 6, 23), (cx + 18, 26), (cx + 13, 62), (cx - 13, 62)],
               fill=VOICE + (55,), outline=VOICE_DIM)
    bd.polygon([(cx - 18, 26), (cx - 22, 52), (cx - 18, 54), (cx - 14, 32)], fill=VOICE + (45,), outline=VOICE_DIM)
    bd.polygon([(cx + 18, 26), (cx + 22, 52), (cx + 18, 54), (cx + 14, 32)], fill=VOICE + (45,), outline=VOICE_DIM)
    # square circuit lines across the chest: the AI it was made as
    for y in (32, 40, 48):
        bd.line((cx - 9, y, cx - 3, y), fill=VOICE)
        bd.line((cx - 3, y, cx - 3, y + 4), fill=VOICE)
        bd.line((cx + 3, y + 2, cx + 9, y + 2), fill=VOICE)
        bd.point((cx + 9, y + 2), fill=(255, 255, 255))
    # the lower body breaks into motes over the stones
    fade = Image.linear_gradient("L").resize(img.size).point(lambda v: 255 if v < 128 else max(0, 255 - (v - 128) * 4))
    body.putalpha(Image.composite(body.split()[3], Image.new("L", img.size, 0), fade))
    gd.bitmap((0, 0), body.split()[3], fill=VOICE + (90,))
    rng = random.Random(3)
    for _ in range(60):
        gd.point((cx + rng.randint(-14, 14), rng.randint(56, 78)), fill=VOICE + (rng.randint(80, 220),))
    img.alpha_composite(body)
    soft = glow.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(soft)
    img.alpha_composite(glow)
    # the MC on his knees before it
    kneel = mc().crop((0, 0, 16, 18))
    img.alpha_composite(kneel, (cx - 8, 96))
    return img


# ---------- the sheet ----------

def build():
    sheet = Image.new("RGBA", (1980, 1340), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def label(x, y, title, note=""):
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)
        if note:
            d.text((x, y + 16), note, font=FONT, fill=CREAM)

    def panel(img, x, y, scale, title, note):
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 18))
        label(x, y, title)
        d.text((x, y + 22 + big.height), note, font=FONT, fill=CREAM)

    panel(surface(), 20, 10, 2, "THE ROCK - LANDING",
          "The Lasta lands; Veki stays aboard. The MC and Davor walk to the cave under old Republic scaffolding (R-7).\n"
          "Davor has pushed the door slab aside. Martin's navy ship lands on the right.")
    panel(surface_raid(), 1000, 10, 2, "THE ROCK - MARTIN'S RAID",
          "Veki has flown off; only the landing marks are left. Raiders close in on the MC and Davor;\n"
          "Martin comes down his ship's ramp last.")
    panel(cave(), 20, 680, 2, "THE CAVE - IN THE DARK",
          "The MC alone. Light only from glowing moss. Davor's old camp in the tunnel: bedroll, fire ring, notes.\n"
          "The grave chamber at the end: a cairn with a broken mask, its Admin badge scratched off.")
    panel(cave(lit=True), 620, 680, 2, "THE CAVE - LIT (LAYOUT)",
          "The same cave without the darkness, to show the layout.")
    panel(voice_scene(), 1220, 680, 2, "THE VOICE IN THE DARK",
          "An outline of pale light over the grave:\n"
          "a tall soldier, square lines across the chest,\n"
          "dissolving into the stones. The MC kneels.")

    figures = [
        (martin(), "MARTIN", "Admin. Long navy coat,\ngold trim, high collar,\ngold shoulder boards\nand Admin badge,\nshort rod."),
        (raider(0), "REPUBLIC SOLDIER", "Martin's men: Republic\nsoldiers in navy and gold."),
        (raider(1), "REPUBLIC SOLDIER", ""),
        (mc(), "MC - BEFORE", ""),
        (mc("white"), "MC - BRINE, WHITE EYES", "Faint pale light round him."),
        (mc("black"), "MC - BRINE, BLACK EYES", ""),
    ]
    x, y = 1500, 680
    for i, (img, title, note) in enumerate(figures):
        fx, fy = x + (i % 2) * 230, y + (i // 2) * 190
        big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        sheet.alpha_composite(big, (fx, fy + 18))
        label(fx, fy, title)
        d.text((fx + big.width + 10, fy + 30), note, font=FONT, fill=CREAM)
    # designs kept for future hackers
    label(20, 1130, "KEPT FOR LATER - HACKER DESIGNS",
          "The first Martin and raider designs, not in Republic colours. Kept for a future hacker and his soldiers.")
    for i, img in enumerate((hacker_concept(), hacker_soldier(0), hacker_soldier(1))):
        big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        sheet.alpha_composite(big, (20 + i * 120, 1166))
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
