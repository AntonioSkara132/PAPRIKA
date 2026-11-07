#!/usr/bin/python3
"""Concept sheet: the Lasta's first ship battle, on the flight from Otpornik to R-7.

The yard scavengers from Otpornik follow the Lasta out of port in a ship they
welded together from stolen scrap. It is slow and turns badly, so the fight
teaches the guns: Veki explains them while the thieves close in. They throw
sprays of scrap from a hopper on the nose and try to come close with a claw to
tear plates off the Lasta. When their hull is gone their engine dies and they
drift.

Writes art/concepts/scrap_battle_concept.png and the ship, nose to the right,
for the game: assets/art/ship_battle/scrap_ship.png.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from create_otpornik_ship_art import (INK, CREAM, YELLOW, FONT, SPACE, GLOW, GLOW_HOT, HULL, HULL_DARK, PATCH,
                                      IRON, IRON_LIGHT, RED, GREEN, RUST)
from create_ship_battle_concept import (canvas, lasta, turned, put, tnt, blast, arc_wedge, starfield, current,
                                        FIRE, DUST_LIGHT)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/scrap_battle_concept.png"
ASSETS = ROOT / "assets/art/ship_battle"
RUST_LIGHT = (196, 120, 70)
SCRAP = (150, 146, 136)
SMOKE = (96, 90, 104)
NET = (176, 160, 110)


# ---------- the ship ----------

def scrap_ship():
    """The thieves' ship from above: a boxy hull of plates that do not match,
    a cockpit bubble off to one side, a scrap hopper and a two-pronged claw on
    the nose, a cargo net on one flank and one big sputtering engine."""
    img, d = canvas(64, 44)
    # hull, three welded boxes of different sizes
    d.rectangle((12, 11, 44, 33), fill=IRON, outline=INK)
    d.rectangle((6, 15, 14, 29), fill=RUST, outline=INK)
    d.rectangle((40, 14, 50, 30), fill=HULL_DARK, outline=INK)
    rng = random.Random(11)
    for x in range(14, 42, 7):
        for y in (12, 22):
            if rng.random() < 0.75:
                d.rectangle((x, y, x + 5, y + 8), fill=rng.choice(PATCH + [RUST, RUST_LIGHT, SCRAP]))
    for x, y in ((16, 21), (27, 13), (33, 26), (21, 29)):
        d.point((x, y), fill=INK)  # rivets
    d.line((13, 22, 43, 22), fill=HULL)
    # cockpit bubble, off-centre
    d.ellipse((26, 6, 36, 14), fill=(110, 170, 190), outline=INK)
    d.point((29, 8), fill=CREAM)
    # scrap hopper on the nose, a funnel full of junk
    d.polygon([(48, 17), (55, 14), (55, 30), (48, 27)], fill=RUST_LIGHT, outline=INK)
    for x, y in ((51, 19), (53, 23), (51, 26)):
        d.point((x, y), fill=SCRAP)
    # the claw: two hooked prongs
    for sign in (-1, 1):
        y0 = 22 + sign * 7
        d.line((54, y0, 61, y0 + sign * 3), fill=IRON_LIGHT, width=2)
        d.line((61, y0 + sign * 3, 63, y0 - sign * 1), fill=IRON_LIGHT, width=2)
    # cargo net on the right flank (bottom of the image)
    for x in range(16, 40, 4):
        d.line((x, 33, x + 3, 39), fill=NET)
        d.line((x + 3, 33, x, 39), fill=NET)
    d.line((15, 39, 41, 39), fill=NET)
    # one big engine with a smoky orange flame
    d.rectangle((1, 18, 7, 26), fill=IRON, outline=INK)
    d.line((0, 20, 0, 24), fill=FIRE)
    d.point((0, 22), fill=YELLOW)
    return img


# ---------- pieces ----------

def scrap_spray(d, x, y, heading, count, reach, seed):
    """A spray of junk thrown out of the hopper: bolts, nuts and bits of plate."""
    rng = random.Random(seed)
    for i in range(count):
        a = heading + rng.uniform(-0.35, 0.35)
        dist = rng.uniform(reach * 0.3, reach)
        px, py = x + math.cos(a) * dist, y + math.sin(a) * dist
        colour = rng.choice((SCRAP, IRON_LIGHT, RUST_LIGHT))
        if rng.random() < 0.5:
            d.rectangle((px - 2, py - 2, px + 2, py + 2), fill=colour, outline=INK)
        else:
            d.line((px, py, px + 4, py + 2), fill=colour, width=2)


def hud(d, w, h, enemy_share):
    d.rectangle((6, 6, 150, 46), fill=(28, 23, 48, 230), outline=YELLOW)
    d.text((12, 9), "LASTA  HULL", font=FONT, fill=CREAM)
    d.rectangle((82, 11, 144, 17), fill=INK, outline=CREAM)
    d.rectangle((83, 12, 136, 16), fill=GREEN)
    d.text((12, 21), "CREW  3", font=FONT, fill=CREAM)
    d.text((12, 32), "LEFT", font=FONT, fill=CREAM)
    d.rectangle((40, 35, 80, 40), fill=INK, outline=CREAM)
    d.rectangle((41, 36, 79, 39), fill=YELLOW)
    d.text((86, 32), "RIGHT", font=FONT, fill=CREAM)
    d.rectangle((116, 35, 144, 40), fill=INK, outline=CREAM)
    d.rectangle((117, 36, 125, 39), fill=RED)
    d.rectangle((w - 136, 6, w - 6, 34), fill=(28, 23, 48, 230), outline=RUST_LIGHT)
    d.text((w - 130, 9), "SCRAP THIEVES", font=FONT, fill=RUST_LIGHT)
    d.rectangle((w - 130, 21, w - 12, 27), fill=INK, outline=CREAM)
    d.rectangle((w - 129, 22, w - 129 + int(116 * enemy_share), 26), fill=RUST)
    d.rectangle((6, h - 22, 260, h - 6), fill=(28, 23, 48, 230), outline=YELLOW)
    d.text((12, h - 19), "Q fire left   E fire right   SHOT: TNT", font=FONT, fill=CREAM)


# ---------- panels ----------

W, H = 480, 270


def lesson():
    """Veki explains the guns while the thieves' ship lumbers in from the port side."""
    rng = random.Random(21)
    img, d = canvas(W, H, SPACE + (255,))
    starfield(img, rng, 240)
    # Otpornik's port lights far behind
    for x, y in ((24, 236), (30, 240), (40, 232), (52, 244)):
        d.point((x, y), fill=YELLOW)
    lasta_at, heading = (230, 150), 0.0
    arc_wedge(d, *lasta_at, heading, -1, 110, YELLOW)
    arc_wedge(d, *lasta_at, heading, 1, 110, YELLOW)
    scrap_at = (300, 52)
    put(img, turned(scrap_ship(), math.degrees(0.9)), *scrap_at)
    put(img, lasta(), *lasta_at)
    # big key hints, Veki's lesson
    d.rectangle((150, 178, 330, 218), fill=(28, 23, 48, 230), outline=YELLOW)
    d.text((158, 182), "VEKI: Arrows steer her. Our guns are", font=FONT, fill=CREAM)
    d.text((158, 194), "on the SIDES. Q is left, E is right.", font=FONT, fill=CREAM)
    d.text((158, 206), "Turn a side to them and let go.", font=FONT, fill=CREAM)
    hud(d, W, H, 1.0)
    return img


def fight():
    """The thieves come at the Lasta's nose with the claw open, throwing scrap;
    her left side has just fired and a barrel bursts on their hull."""
    rng = random.Random(4)
    img, d = canvas(W, H, SPACE + (255,))
    starfield(img, rng, 240)
    d = current(img, rng, 190, 236, -0.18)
    lasta_at, heading = (170, 170), -0.3
    out = heading - math.pi / 2
    scrap_at = (lasta_at[0] + math.cos(out) * 112 + 30, lasta_at[1] + math.sin(out) * 112)
    arc_wedge(d, *lasta_at, heading, 1, 70, (120, 110, 150))
    for i, (t, spread) in enumerate(((0.45, -0.18), (0.7, 0.04))):
        dist = 24 + t * 90
        a = out + spread * 0.6
        tnt(d, lasta_at[0] + math.cos(a) * dist, lasta_at[1] + math.sin(a) * dist, angle=i * 1.3)
    blast(d, scrap_at[0] - 8, scrap_at[1] + 10, 10)
    scrap_heading = math.atan2(lasta_at[1] - scrap_at[1], lasta_at[0] - scrap_at[0]) + 0.25
    scrap_spray(d, scrap_at[0] + math.cos(scrap_heading) * 30, scrap_at[1] + math.sin(scrap_heading) * 30,
                scrap_heading, 16, 52, 8)
    put(img, turned(lasta(), math.degrees(-heading)), *lasta_at)
    put(img, turned(scrap_ship(), math.degrees(-scrap_heading)), *scrap_at)
    d.text((lasta_at[0] - 60, lasta_at[1] + 30), "DAVOR: Is that a claw?", font=FONT, fill=CREAM)
    hud(d, W, H, 0.55)
    return img


def drifting():
    """The end: their engine is dead, the ship spins slowly, the thieves shout."""
    rng = random.Random(30)
    img, d = canvas(220, 150, SPACE + (255,))
    starfield(img, rng, 70)
    for i in range(9):
        x = 96 - i * 7 + rng.randrange(-2, 3)
        y = 70 + i * 2 + rng.randrange(-2, 3)
        r = 2 + i // 2
        d.ellipse((x - r, y - r, x + r, y + r), fill=SMOKE)
    put(img, turned(scrap_ship(), 35), 120, 66)
    for x, y in ((140, 50), (146, 58), (132, 44)):
        d.point((x, y), fill=GLOW_HOT)
    d.text((8, 118), "THIEF: Our engine! You owe us", font=FONT, fill=RUST_LIGHT)
    d.text((8, 130), "an engine!", font=FONT, fill=RUST_LIGHT)
    put(img, turned(lasta(), 0), 186, 128)
    return img


def claw():
    """Close in, the claw tears a plate off the Lasta: being rammed side-on by them hurts more."""
    img, d = canvas(220, 110, SPACE + (255,))
    starfield(img, random.Random(41), 50)
    put(img, lasta(), 80, 60)
    put(img, turned(scrap_ship(), 90), 92, 18)
    d.rectangle((94, 38, 101, 44), fill=PATCH[0], outline=INK)
    for x, y in ((90, 42), (104, 40), (98, 36)):
        d.point((x, y), fill=YELLOW)
    d.text((132, 50), "claw:", font=FONT, fill=CREAM)
    d.text((132, 62), "rips plates", font=FONT, fill=CREAM)
    return img


def build():
    sheet = Image.new("RGBA", (1520, 1240), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def label(x, y, title):
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)

    def panel(img, x, y, scale, title, note):
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 18))
        label(x, y, title)
        d.text((x, y + 24 + big.height), note, font=FONT, fill=CREAM)

    panel(lesson(), 20, 10, 2, "THE LASTA'S FIRST BATTLE - LEAVING OTPORNIK",
          "On the way to R-7, the scrap thieves from Otpornik's yard follow the Lasta out of port in a ship welded from stolen plates.\n"
          "Their ship is slow and turns badly. The player learned the guns on the Chvarak diplomatic ship, so Veki only reminds them.")
    panel(fight(), 20, 620, 2, "THE FIGHT",
          "They come at the Lasta's nose and throw sprays of scrap from the hopper: short range, many small hits. Up close the claw tears plates off her.\n"
          "Here her left side has fired and a barrel bursts on their hull. Crew on this flight: you, Veki and Davor.")
    panel(drifting(), 1000, 10, 2, "THE END - ENGINE DEAD",
          "At 0 hull their engine dies and they drift.\nNobody dies: Veki leaves them for the port\npatrol and flies on to R-7.")
    panel(claw(), 1000, 380, 2, "THE CLAW",
          "Their only close attack. Ramming them hurts\nboth ships, the claw hurts the Lasta more.")
    big = scrap_ship().resize((64 * 4, 44 * 4), Image.NEAREST)
    sheet.alpha_composite(big, (1000, 680))
    label(1000, 662, "THE SCRAP SHIP FROM ABOVE")
    d.text((1000, 870), "Welded boxes of plates that do not match, a cockpit bubble\noff to one side, a scrap hopper and a claw on the nose,\n"
                        "a cargo net on one flank, one big sputtering engine.", font=FONT, fill=CREAM)
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))
    ASSETS.mkdir(parents=True, exist_ok=True)
    scrap_ship().save(ASSETS / "scrap_ship.png")
    print((ASSETS / "scrap_ship.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
