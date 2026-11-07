#!/usr/bin/python3
"""Concept sheet: ship battles in space, the first one against the Purple Parrots.

The player steers the Lasta seen from above. Her TNT launchers are on her two
sides, so she has to turn a side towards the enemy to fire. A current of dust
crosses the battle; flying with it is faster. The Parrots' little purple ship
fights with light bolts and escapes at the end.

Writes art/concepts/ship_battle_concept.png and the two ships, nose to the right,
for the game: assets/art/ship_battle/lasta.png and parrot_ship.png.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from create_otpornik_ship_art import (INK, CREAM, YELLOW, FONT, SPACE, STAR, GLOW, GLOW_HOT, HULL, HULL_LIGHT,
                                      HULL_DARK, PATCH, BRASS, BRASS_DARK, GLASS, GLASS_LIGHT, IRON, IRON_LIGHT, RED,
                                      GREEN, RUST)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/ship_battle_concept.png"
ASSETS = ROOT / "assets/art/ship_battle"
PURPLE = (124, 58, 186)
PURPLE_LIGHT = (190, 140, 236)
PURPLE_DARK = (78, 34, 122)
BEAK = (236, 150, 52)
BEAK_DARK = (176, 96, 40)
LEAF = (92, 196, 110)
DUST = (92, 74, 118)
DUST_LIGHT = (140, 116, 160)
TNT = (196, 58, 46)
TNT_DARK = (130, 36, 32)
FUSE = (250, 220, 120)
FIRE = (250, 160, 60)


def canvas(w, h, fill=(0, 0, 0, 0)):
    img = Image.new("RGBA", (w, h), fill)
    return img, ImageDraw.Draw(img)


# ---------- the ships, seen from above, nose to the right ----------

def lasta():
    """The Lasta from above: the patched grey hull of the side view, a glass nose,
    two engines at the back and three TNT launchers on each side."""
    img, d = canvas(72, 40)
    d.rounded_rectangle((8, 8, 62, 32), radius=9, fill=HULL, outline=INK)
    # patched plates
    rng = random.Random(7)
    for x in range(12, 56, 9):
        for y in (10, 20):
            if rng.random() < 0.6:
                d.rectangle((x, y, x + 7, y + 9), fill=rng.choice(PATCH))
    d.line((10, 20, 60, 20), fill=HULL_DARK)
    d.line((14, 9, 56, 9), fill=HULL_LIGHT)
    # glass nose
    d.pieslice((50, 10, 70, 30), -90, 90, fill=GLASS, outline=INK)
    d.line((62, 14, 66, 18), fill=GLASS_LIGHT)
    # engines with blue glow
    for y in (11, 24):
        d.rectangle((3, y, 9, y + 5), fill=IRON, outline=INK)
        d.line((1, y + 1, 1, y + 4), fill=GLOW)
        d.line((0, y + 2, 0, y + 3), fill=GLOW_HOT)
    # launchers on each side, brass rims
    for x in (22, 32, 42):
        for y in (5, 32):
            d.rectangle((x, y, x + 5, y + 3), fill=IRON, outline=BRASS_DARK)
            d.point((x + 2, y + (0 if y < 20 else 3)), fill=BRASS)
    d.text((24, 14), "L", font=FONT, fill=INK)
    return img


def parrot_ship():
    """The Parrots' little purple ship: an orange beak for a nose, wings with green
    and yellow tips, and a tail of purple feathers. Light-bolt lamps on the wings."""
    img, d = canvas(56, 44)
    # wings
    d.polygon([(18, 22), (30, 2), (38, 4), (34, 22)], fill=PURPLE_DARK, outline=INK)
    d.polygon([(18, 22), (30, 42), (38, 40), (34, 22)], fill=PURPLE_DARK, outline=INK)
    for y, tip in ((4, LEAF), (8, YELLOW)):
        d.line((30, y, 37, y + 1), fill=tip)
        d.line((30, 44 - y, 37, 43 - y), fill=tip)
    # body
    d.ellipse((10, 14, 46, 30), fill=PURPLE, outline=INK)
    d.line((14, 18, 40, 17), fill=PURPLE_LIGHT)
    # beak
    d.polygon([(44, 17), (55, 22), (44, 27)], fill=BEAK, outline=INK)
    d.line((45, 22, 53, 22), fill=BEAK_DARK)
    d.point((40, 20), fill=CREAM)
    d.point((40, 24), fill=CREAM)
    # tail feathers and engine glow
    for dy, colour in ((-5, PURPLE_LIGHT), (0, PURPLE), (5, PURPLE_LIGHT)):
        d.polygon([(12, 22 + dy // 2), (1, 18 + dy), (3, 22 + dy), (12, 23 + dy // 2)], fill=colour, outline=INK)
    d.point((9, 22), fill=GLOW_HOT)
    # light-bolt lamps (Luster's spiral, ship-sized)
    for x, y in ((31, 8), (31, 36)):
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=GLOW_HOT, outline=INK)
    return img


def turned(img, degrees):
    """The ship turned by `degrees`, counter-clockwise, still in hard pixels."""
    return img.rotate(degrees, resample=Image.NEAREST, expand=True)


def put(base, img, cx, cy):
    base.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))


# ---------- pieces ----------

def tnt(d, x, y, angle=0.0, lit=True):
    """A TNT barrel tumbling through space, its fuse sparking."""
    c, s = math.cos(angle), math.sin(angle)
    corners = [(-4, -3), (4, -3), (4, 3), (-4, 3)]
    d.polygon([(x + cx * c - cy * s, y + cx * s + cy * c) for cx, cy in corners], fill=TNT, outline=INK)
    d.line((x - 3 * c, y - 3 * s, x + 3 * c, y + 3 * s), fill=TNT_DARK)
    if lit:
        fx, fy = x + 5 * c, y + 5 * s
        d.point((fx, fy), fill=FUSE)
        d.point((fx + 1, fy - 1), fill=GLOW_HOT)


def blast(d, x, y, r):
    for i, colour in enumerate((RUST, FIRE, YELLOW, GLOW_HOT)):
        rr = r - i * r / 4
        d.ellipse((x - rr, y - rr * 0.9, x + rr, y + rr * 0.9), fill=colour)
    rng = random.Random(int(x * 13 + y))
    for _ in range(10):
        a = rng.random() * math.tau
        dist = r + rng.randrange(2, 7)
        d.point((x + math.cos(a) * dist, y + math.sin(a) * dist), fill=rng.choice((FIRE, YELLOW, IRON_LIGHT)))


def arc_wedge(d, cx, cy, heading, side, reach, colour):
    """The dotted wedge a broadside covers: out of `side` (+1 right, -1 left) of a ship heading `heading`."""
    out = heading + side * math.pi / 2
    for spread in (-0.45, 0.45):
        a = out + spread
        for step in range(8, int(reach), 6):
            d.point((cx + math.cos(a) * step, cy + math.sin(a) * step), fill=colour)
    for step in range(-12, 13, 3):
        a = out + step / 26
        d.point((cx + math.cos(a) * reach, cy + math.sin(a) * reach), fill=colour)


def starfield(img, rng, count):
    d = ImageDraw.Draw(img)
    for _ in range(count):
        d.point((rng.randrange(img.width), rng.randrange(img.height)), fill=rng.choice((STAR, GLOW, (120, 110, 170))))


def current(img, rng, y0, y1, slope):
    """A band of drifting dust crossing the field, with streaks along its flow."""
    d = ImageDraw.Draw(img)
    for x in range(img.width):
        top = y0 + x * slope
        bottom = y1 + x * slope
        for y in range(int(top), int(bottom)):
            if 0 <= y < img.height and rng.random() < 0.10:
                d.point((x, y), fill=DUST)
    for _ in range(46):
        x = rng.randrange(img.width)
        y = rng.uniform(y0, y1) + x * slope
        d.line((x, y, x + 9, y + 9 * slope), fill=DUST_LIGHT)
    return d


def hud(d, w, h):
    """The battle HUD: hull and crew, a reload bar for each side, the shot and the current."""
    d.rectangle((6, 6, 150, 46), fill=(28, 23, 48, 230), outline=YELLOW)
    d.text((12, 9), "LASTA  HULL", font=FONT, fill=CREAM)
    d.rectangle((82, 11, 144, 17), fill=INK, outline=CREAM)
    d.rectangle((83, 12, 126, 16), fill=GREEN)
    d.text((12, 21), "CREW  4", font=FONT, fill=CREAM)
    d.text((12, 32), "LEFT", font=FONT, fill=CREAM)
    d.rectangle((40, 35, 80, 40), fill=INK, outline=CREAM)
    d.rectangle((41, 36, 50, 39), fill=RED)
    d.text((86, 32), "RIGHT", font=FONT, fill=CREAM)
    d.rectangle((116, 35, 144, 40), fill=INK, outline=CREAM)
    d.rectangle((117, 36, 143, 39), fill=YELLOW)
    d.rectangle((w - 136, 6, w - 6, 34), fill=(28, 23, 48, 230), outline=PURPLE_LIGHT)
    d.text((w - 130, 9), "PURPLE PARROTS", font=FONT, fill=PURPLE_LIGHT)
    d.rectangle((w - 130, 21, w - 12, 27), fill=INK, outline=CREAM)
    d.rectangle((w - 129, 22, w - 64, 26), fill=PURPLE)
    d.rectangle((6, h - 22, 260, h - 6), fill=(28, 23, 48, 230), outline=YELLOW)
    d.text((12, h - 19), "Q fire left   E fire right   SHOT: TNT", font=FONT, fill=CREAM)
    d.rectangle((w - 120, h - 22, w - 6, h - 6), fill=(28, 23, 48, 230), outline=DUST_LIGHT)
    d.text((w - 114, h - 19), "CURRENT  -->", font=FONT, fill=DUST_LIGHT)


# ---------- the panels ----------

W, H = 480, 270


def battle():
    """The main view: the Lasta has turned her left side to the Parrots and fired;
    the barrels tumble across, one bursts by their wing. Their light bolts come back."""
    rng = random.Random(3)
    img, d = canvas(W, H, SPACE + (255,))
    starfield(img, rng, 260)
    d = current(img, rng, 150, 200, -0.32)
    lasta_at, lasta_heading = (150, 182), 0.6
    out = lasta_heading - math.pi / 2
    parrot_at = (lasta_at[0] + math.cos(out) * 128, lasta_at[1] + math.sin(out) * 128)
    arc_wedge(d, *lasta_at, lasta_heading, -1, 120, YELLOW)
    arc_wedge(d, *lasta_at, lasta_heading, 1, 70, (120, 110, 150))
    # the barrels in flight from the left side
    for i, (t, spread) in enumerate(((0.35, -0.2), (0.6, 0.05), (0.8, 0.22))):
        dist = 24 + t * 100
        a = out + spread * 0.6
        tnt(d, lasta_at[0] + math.cos(a) * dist, lasta_at[1] + math.sin(a) * dist, angle=i * 1.1)
    blast(d, parrot_at[0] + 14, parrot_at[1] + 12, 9)
    # the Parrots' answer: a spiral of light bolts
    for i in range(8):
        a = i * math.tau / 8 + 0.4
        r = 34 + i * 2
        x, y = parrot_at[0] + math.cos(a) * r, parrot_at[1] + math.sin(a) * r
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=GLOW_HOT)
        d.line((x, y, x - math.cos(a + 0.9) * 5, y - math.sin(a + 0.9) * 5), fill=GLOW)
    put(img, turned(lasta(), math.degrees(-lasta_heading)), *lasta_at)
    put(img, turned(parrot_ship(), math.degrees(-(lasta_heading + math.pi))), *parrot_at)
    # Veki at the helm
    d.text((lasta_at[0] - 40, lasta_at[1] + 30), "VEKI: Their side is open, fire!", font=FONT, fill=CREAM)
    hud(d, W, H)
    return img


def turning():
    """Why the turn matters: the launchers only cover the two side wedges."""
    img, d = canvas(220, 150, SPACE + (255,))
    starfield(img, random.Random(5), 60)
    centre = (110, 75)
    arc_wedge(d, *centre, 0.0, 1, 62, YELLOW)
    arc_wedge(d, *centre, 0.0, -1, 62, YELLOW)
    put(img, lasta(), *centre)
    d.text((88, 4), "LEFT", font=FONT, fill=YELLOW)
    d.text((86, 138), "RIGHT", font=FONT, fill=YELLOW)
    d.text((176, 70), "nose:", font=FONT, fill=CREAM)
    d.text((176, 80), "no gun", font=FONT, fill=CREAM)
    return img


def escape():
    """The end: the Parrot ship, smoking, dives into the current and is gone."""
    rng = random.Random(9)
    img, d = canvas(220, 150, SPACE + (255,))
    starfield(img, rng, 70)
    d = current(img, rng, 70, 110, -0.25)
    for i in range(14):
        x = 40 + i * 9
        y = 112 - i * 3
        d.ellipse((x - 3, y - 2, x + 3, y + 2), fill=(90, 84, 100) if i % 2 else (120, 112, 128))
    put(img, turned(parrot_ship(), 14), 180, 66)
    put(img, turned(lasta(), 0), 40, 40)
    d.text((70, 132), "LUSTER: Julius will hear of this!", font=FONT, fill=PURPLE_LIGHT)
    return img


def shots():
    """Kinds of shot, as ideas: TNT for the hull, chained TNT for the engines, a cluster for the crew."""
    img, d = canvas(220, 70, SPACE + (255,))
    tnt(d, 30, 30)
    d.text((14, 46), "TNT", font=FONT, fill=CREAM)
    tnt(d, 92, 26)
    tnt(d, 110, 34)
    d.line((95, 26, 107, 34), fill=IRON_LIGHT)
    d.text((80, 46), "CHAINED", font=FONT, fill=CREAM)
    for dx, dy in ((0, 0), (6, -4), (8, 4), (-5, 5)):
        tnt(d, 178 + dx, 30 + dy, angle=dx * 0.3, lit=dx == 0)
    d.text((158, 46), "CLUSTER", font=FONT, fill=CREAM)
    return img


def build():
    sheet = Image.new("RGBA", (1520, 1000), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def label(x, y, title):
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)

    def panel(img, x, y, scale, title, note):
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 18))
        label(x, y, title)
        d.text((x, y + 24 + big.height), note, font=FONT, fill=CREAM)

    panel(battle(), 20, 10, 2, "SHIP BATTLE - THE PURPLE PARROTS",
          "Seen from above. The player steers the Lasta (arrow keys turn and speed up) and fires TNT from the left or right side.\nThe left launchers are reloading (red), the right ones are ready (yellow).\n"
          "Here she has turned her left side to the Parrots and fired: three barrels tumble across, one bursts by their wing.\n"
          "The Parrots answer with a spiral of light bolts. The dust current (diagonal band) is faster to fly with than against.")
    panel(turning(), 1000, 10, 2, "THE TURN",
          "TNT only leaves the two sides.\nTo hit them, put your side\nto them before they do it to you.\nEach side reloads on its own.")
    panel(escape(), 1000, 400, 2, "THE END - THEY ESCAPE",
          "Hurt and smoking, the Parrot ship\ndives into the current and is gone.\nThey work for Julius; they can come back.")
    panel(shots(), 1000, 790, 2, "KINDS OF SHOT - IDEAS, NOT DECIDED",
          "TNT hits the hull. Chained TNT could slow\nengines; a cluster could hurt the crew.")
    for i, (img, title) in enumerate(((lasta(), "THE LASTA FROM ABOVE"), (parrot_ship(), "THE PARROT SHIP"))):
        big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        x = 20 + i * 340
        sheet.alpha_composite(big, (x, 660))
        label(x, 642, title)
    d.text((20, 840), "Lasta: the grey patched hull and glass nose of her side view, two engines, three TNT launchers a side.\n"
                      "Parrot ship: purple body, orange beak nose, wings with green and yellow tips, a feather tail, two bolt lamps.",
           font=FONT, fill=CREAM)
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name, img in (("lasta", lasta()), ("parrot_ship", parrot_ship())):
        img.save(ASSETS / (name + ".png"))
        print((ASSETS / (name + ".png")).relative_to(ROOT))


if __name__ == "__main__":
    main()
