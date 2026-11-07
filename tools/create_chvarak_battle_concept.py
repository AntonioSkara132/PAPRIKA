#!/usr/bin/python3
"""Concept sheet: the ship battle on the Chvarak diplomatic ship, before the hackers board.

Soon after the white diplomatic ship leaves Chvarak, a hackers' ship comes up
behind it with its lights off. Julius pays them in secret, so they look
independent and never name him. The pilot, Klara Rog, hands the Captain the
ship's two pairs of TNT launchers and explains them. The hackers' ship fires teal bolts from a distance and tries to catch the
white ship with a harpoon on a cable. The battle always ends with the hackers
coming aboard, and the player is told so at the start:
- the harpoon catches the white ship and the hackers reel it in, or
- the player wrecks the hackers' ship, and the phase hacker jumps across onto
  the white ship's hull anyway, with a cable for the others.
Then the existing boarding fight in scripts/world/chvarak_world.gd follows.

This is the player's first ship battle (Chvarak comes before Otpornik), so the
pilot explains the controls here, and Veki's lesson on the Otpornik flight
is a short reminder.

Writes art/concepts/chvarak_battle_concept.png and the two ships, nose to the
right, for the game: assets/art/ship_battle/diplomatic_ship.png and
assets/art/ship_battle/hacker_ship.png.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from create_otpornik_ship_art import (INK, CREAM, YELLOW, FONT, SPACE, GLOW, GLOW_HOT, IRON, IRON_LIGHT, RED,
                                      GREEN, BRASS, BRASS_DARK)
from create_ship_battle_concept import (canvas, turned, put, tnt, blast, arc_wedge, starfield, current, FIRE)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/chvarak_battle_concept.png"
ASSETS = ROOT / "assets/art/ship_battle"

# The white ship's colours, from tools/create_chvarak_art.py
WHITE = (222, 226, 232)
WHITE_SHADE = (176, 182, 194)
WHITE_DARK = (124, 130, 146)
BLUE = (78, 131, 207)
BLUE_DARK = (47, 92, 156)
GOLD = (245, 195, 76)
WINDOW = (96, 176, 206)
WINDOW_LIGHT = (160, 220, 236)
ENGINE_GLOW = (120, 200, 230)
# The hackers, from assets/art/hacker.png: an indigo hood, a teal visor and
# a teal screen on the chest
INDIGO = (64, 60, 105)
INDIGO_DARK = (51, 52, 77)
INDIGO_LIGHT = (110, 109, 147)
TEAL = (36, 127, 138)
TEAL_GLOW = (95, 214, 211)
SCREEN_GREEN = (120, 230, 140)
CABLE = (150, 150, 168)
SMOKE = (96, 90, 104)
# Chvarak seen from space
CHVARAK_GREEN = (98, 146, 64)
CHVARAK_FIELD = (214, 182, 92)
CHVARAK_ROCK = (112, 104, 104)
SNOW = (238, 242, 246)
PANEL = (28, 23, 48, 230)


# ---------- the ships, seen from above, nose to the right ----------

def diplomatic_ship():
    """The Council's white ship from above: a long white hull with the blue and
    gold stripe of its side view, a glass cockpit at the nose, a row of cabin
    windows, swept fins, one engine, the Confederation's blue disc on the roof,
    and two TNT launchers on each side behind small blue hatches."""
    img, d = canvas(76, 42)
    # swept fins at the back
    d.polygon([(10, 12), (4, 2), (12, 2), (24, 12)], fill=WHITE_SHADE, outline=INK)
    d.polygon([(10, 29), (4, 39), (12, 39), (24, 29)], fill=WHITE_SHADE, outline=INK)
    # hull: a long rounded body with a pointed nose
    d.polygon([(8, 14), (16, 9), (56, 9), (70, 16), (74, 20), (70, 25), (56, 32), (16, 32), (8, 27)],
              fill=WHITE, outline=INK)
    d.line((16, 30, 56, 30), fill=WHITE_SHADE)
    d.line((14, 31, 58, 31), fill=WHITE_SHADE)
    # the blue and gold stripe along the spine
    d.line((10, 19, 66, 19), fill=BLUE, width=2)
    d.line((10, 22, 64, 22), fill=GOLD)
    # cockpit glass at the nose
    d.polygon([(58, 13), (68, 17), (70, 20), (68, 24), (58, 28), (61, 20)], fill=WINDOW, outline=INK)
    d.line((61, 15, 66, 18), fill=WINDOW_LIGHT)
    # cabin windows down each flank
    for x in range(22, 52, 8):
        d.rectangle((x, 11, x + 3, 13), fill=WINDOW, outline=INK)
        d.rectangle((x, 28, x + 3, 30), fill=WINDOW, outline=INK)
    # the Confederation's blue disc with a gold dot
    d.ellipse((36, 16, 44, 24), fill=BLUE, outline=INK)
    d.point((40, 20), fill=GOLD)
    # one engine with a pale blue glow
    d.rectangle((2, 16, 9, 25), fill=WHITE_DARK, outline=INK)
    d.line((1, 18, 1, 23), fill=ENGINE_GLOW)
    d.line((0, 19, 0, 22), fill=GLOW_HOT)
    # two launchers a side, behind blue hatches that open for the fight
    for x in (27, 43):
        for y in (6, 32):
            d.rectangle((x, y, x + 5, y + 3), fill=IRON, outline=BLUE_DARK)
            d.point((x + 2, y + (0 if y < 20 else 3)), fill=BRASS)
    return img


def hacker_ship():
    """The hackers' ship from above: a narrow indigo hull shaped like the
    hackers' hood, with a teal visor slit for a cockpit, a teal screen on its
    back with green signs running across it, two cable antennas trailing behind,
    bolt lamps on short wings, and a harpoon on the nose with its cable drum."""
    img, d = canvas(74, 44)
    # short wings with bolt lamps at the tips
    d.polygon([(20, 14), (30, 3), (40, 3), (40, 14)], fill=INDIGO_DARK, outline=INK)
    d.polygon([(20, 30), (30, 41), (40, 41), (40, 30)], fill=INDIGO_DARK, outline=INK)
    for y in (5, 39):
        d.ellipse((34, y - 2, 38, y + 2), fill=TEAL_GLOW, outline=INK)
    # the hood-shaped hull: wide at the back, closing to a rounded point
    d.polygon([(6, 12), (16, 8), (44, 8), (58, 14), (62, 22), (58, 30), (44, 36), (16, 36), (6, 32)],
              fill=INDIGO, outline=INK)
    d.line((16, 9, 44, 9), fill=INDIGO_LIGHT)
    d.line((16, 35, 44, 35), fill=INDIGO_DARK)
    # the hood's fold down the middle
    d.line((10, 22, 30, 22), fill=INDIGO_DARK)
    # teal visor slit across the cockpit
    d.polygon([(46, 17), (55, 19), (55, 25), (46, 27)], fill=TEAL, outline=INK)
    d.line((48, 19, 54, 20), fill=TEAL_GLOW)
    # the hood's rim around the visor
    d.line((45, 15, 56, 17), fill=INDIGO_LIGHT)
    d.line((45, 29, 56, 27), fill=INDIGO_LIGHT)
    # the screen on its back, with green signs
    d.rectangle((24, 15, 38, 29), fill=INDIGO_DARK, outline=INK)
    d.rectangle((25, 16, 37, 28), fill=TEAL)
    for i, (x, y) in enumerate(((27, 18), (31, 18), (34, 21), (27, 24), (30, 26), (35, 26))):
        d.point((x, y), fill=SCREEN_GREEN if i % 2 == 0 else TEAL_GLOW)
        d.point((x + 1, y), fill=SCREEN_GREEN)
    # cable antennas trailing back off the stern
    d.line((8, 14, 1, 8), fill=CABLE)
    d.line((8, 30, 1, 36), fill=CABLE)
    d.point((1, 8), fill=TEAL_GLOW)
    d.point((1, 36), fill=TEAL_GLOW)
    # teal engine glow
    d.rectangle((3, 18, 7, 26), fill=INDIGO_DARK, outline=INK)
    d.line((2, 20, 2, 24), fill=TEAL_GLOW)
    # the harpoon: a cable drum and a barbed head on the nose
    d.ellipse((40, 19, 46, 25), fill=IRON_LIGHT, outline=INK)
    d.point((43, 22), fill=CABLE)
    d.line((60, 22, 68, 22), fill=IRON_LIGHT, width=2)
    d.polygon([(68, 18), (73, 22), (68, 26)], fill=IRON_LIGHT, outline=INK)
    d.line((66, 19, 68, 21), fill=INK)
    d.line((66, 25, 68, 23), fill=INK)
    return img


# ---------- pieces ----------

def chvarak_below(img, cx, cy, r, seed):
    """Chvarak seen from space: green and gold fields with grey mountains and snow."""
    d = ImageDraw.Draw(img)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=CHVARAK_GREEN, outline=(160, 200, 230))
    rng = random.Random(seed)
    for _ in range(40):
        a = rng.random() * math.tau
        dist = rng.random() * (r - 10)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        if rng.random() < 0.55:
            d.rectangle((x, y, x + rng.randrange(4, 10), y + rng.randrange(3, 6)), fill=CHVARAK_FIELD)
        else:
            d.polygon([(x, y + 6), (x + 5, y - 3), (x + 10, y + 6)], fill=CHVARAK_ROCK)
            d.point((x + 5, y - 2), fill=SNOW)
            d.point((x + 5, y - 1), fill=SNOW)


def teal_bolt(d, x, y, a):
    d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=TEAL_GLOW)
    d.line((x, y, x - math.cos(a) * 6, y - math.sin(a) * 6), fill=TEAL)


def harpoon(d, x, y, a, tail_x, tail_y, taut=False):
    """A barbed harpoon head at (x, y) pointing along `a`, its cable back to (tail_x, tail_y).
    A slack cable sags in a curve, a taut one is a straight line."""
    if taut:
        d.line((tail_x, tail_y, x, y), fill=CABLE, width=2)
    else:
        points = []
        for i in range(13):
            t = i / 12
            px = tail_x + (x - tail_x) * t
            py = tail_y + (y - tail_y) * t + math.sin(t * math.pi) * 10
            points.append((px, py))
        d.line(points, fill=CABLE)
    c, s = math.cos(a), math.sin(a)
    tip = (x + c * 6, y + s * 6)
    d.polygon([tip, (x - s * 3, y + c * 3), (x + s * 3, y - c * 3)], fill=IRON_LIGHT, outline=INK)
    for side in (-1, 1):
        d.line((x, y, x - c * 3 + side * -s * 4, y - s * 3 + side * c * 4), fill=INK)


def phase_flash(d, x, y, r):
    for i, colour in enumerate((TEAL, TEAL_GLOW, CREAM)):
        rr = r - i * r / 3
        d.ellipse((x - rr, y - rr, x + rr, y + rr), outline=colour)
    for k in range(8):
        a = k * math.tau / 8
        d.point((x + math.cos(a) * (r + 3), y + math.sin(a) * (r + 3)), fill=TEAL_GLOW)


def hud(d, w, h, own_share, enemy_share, left_ready=True, right_share=1.0):
    d.rectangle((6, 6, 168, 46), fill=PANEL, outline=YELLOW)
    d.text((12, 9), "COUNCIL SHIP", font=FONT, fill=CREAM)
    d.rectangle((100, 11, 162, 17), fill=INK, outline=CREAM)
    d.rectangle((101, 12, 101 + int(60 * own_share), 16), fill=GREEN)
    d.text((12, 21), "CREW  7", font=FONT, fill=CREAM)
    d.text((12, 32), "LEFT", font=FONT, fill=CREAM)
    d.rectangle((40, 35, 80, 40), fill=INK, outline=CREAM)
    d.rectangle((41, 36, 79 if left_ready else 52, 39), fill=YELLOW if left_ready else RED)
    d.text((86, 32), "RIGHT", font=FONT, fill=CREAM)
    d.rectangle((116, 35, 162, 40), fill=INK, outline=CREAM)
    d.rectangle((117, 36, 117 + int(44 * right_share), 39), fill=YELLOW if right_share >= 1.0 else RED)
    d.rectangle((w - 136, 6, w - 6, 34), fill=PANEL, outline=TEAL_GLOW)
    d.text((w - 130, 9), "HACKERS", font=FONT, fill=TEAL_GLOW)
    d.rectangle((w - 130, 21, w - 12, 27), fill=INK, outline=CREAM)
    d.rectangle((w - 129, 22, w - 129 + int(116 * enemy_share), 26), fill=TEAL)
    d.rectangle((6, h - 22, 260, h - 6), fill=PANEL, outline=YELLOW)
    d.text((12, h - 19), "Q fire left   E fire right   SHOT: TNT", font=FONT, fill=CREAM)


def radio(d, x, y, w, lines, edge=YELLOW, colour=CREAM):
    d.rectangle((x, y, x + w, y + 6 + 12 * len(lines)), fill=PANEL, outline=edge)
    for i, line in enumerate(lines):
        d.text((x + 6, y + 4 + i * 12), line, font=FONT, fill=colour)


# ---------- panels ----------

W, H = 480, 270


def lesson():
    """Leaving Chvarak: the hackers' ship comes up behind with its lights off and
    Klara hands the Captain the guns."""
    rng = random.Random(12)
    img, d = canvas(W, H, SPACE + (255,))
    starfield(img, rng, 240)
    chvarak_below(img, 40, 290, 120, 3)
    d = ImageDraw.Draw(img)
    ship_at = (250, 128)
    arc_wedge(d, *ship_at, 0.0, -1, 100, YELLOW)
    arc_wedge(d, *ship_at, 0.0, 1, 100, YELLOW)
    put(img, diplomatic_ship(), *ship_at)
    hacker_at = (110, 84)
    put(img, turned(hacker_ship(), math.degrees(-0.25)), *hacker_at)
    d.text((hacker_at[0] - 30, hacker_at[1] - 34), "lights off", font=FONT, fill=TEAL_GLOW)
    radio(d, 150, 178, 236, ["KLARA: Arrows steer. TNT only leaves our",
                             "sides: Q fires left, E fires right.",
                             "Keep their harpoon off us!"])
    hud(d, W, H, 1.0, 1.0)
    return img


def fight():
    """The white ship has fired its right side; one barrel bursts on the hackers'
    hull. Teal bolts come back, and the harpoon is in the air: turning away
    makes it miss."""
    rng = random.Random(6)
    img, d = canvas(W, H, SPACE + (255,))
    starfield(img, rng, 240)
    d = current(img, rng, 200, 250, -0.2)
    ship_at = (200, 150)
    hacker_at = (330, 70)
    # turn the white ship so its left side faces the hackers
    heading = math.atan2(hacker_at[1] - ship_at[1], hacker_at[0] - ship_at[0]) + math.pi / 2
    out = heading - math.pi / 2
    arc_wedge(d, *ship_at, heading, -1, 120, YELLOW)
    arc_wedge(d, *ship_at, heading, 1, 70, (120, 110, 150))
    for i, (t, spread) in enumerate(((0.4, -0.1), (0.65, 0.08))):
        dist = 26 + t * 100
        a = out + spread
        tnt(d, ship_at[0] + math.cos(a) * dist, ship_at[1] + math.sin(a) * dist, angle=i * 1.2)
    hacker_heading = math.atan2(ship_at[1] - hacker_at[1], ship_at[0] - hacker_at[0]) - 0.5
    # teal bolts
    for k, t in enumerate((0.35, 0.55)):
        a = hacker_heading + (k - 0.5) * 0.12
        bx = hacker_at[0] + math.cos(a) * (40 + t * 60)
        by = hacker_at[1] + math.sin(a) * (40 + t * 60)
        teal_bolt(d, bx, by, a)
    # the harpoon in flight, about to pass behind the white ship's tail
    nose = (hacker_at[0] + math.cos(hacker_heading) * 34, hacker_at[1] + math.sin(hacker_heading) * 34)
    head = (nose[0] + math.cos(hacker_heading) * 100, nose[1] + math.sin(hacker_heading) * 100)
    harpoon(d, *head, hacker_heading, *nose)
    d.text((head[0] + 10, head[1] - 4), "harpoon: turn away!", font=FONT, fill=CREAM)
    put(img, turned(diplomatic_ship(), math.degrees(-heading)), *ship_at)
    put(img, turned(hacker_ship(), math.degrees(-hacker_heading)), *hacker_at)
    d = ImageDraw.Draw(img)
    blast(d, hacker_at[0] - 12, hacker_at[1] + 10, 8)
    radio(d, 150, 206, 220, ["HACKER: Sink us if you like. We're", "coming aboard either way."],
          edge=TEAL_GLOW, colour=TEAL_GLOW)
    hud(d, W, H, 0.7, 0.6, left_ready=False, right_share=1.0)
    return img


def harpooned():
    """Ending A: the harpoon is in the white ship's tail by the hatch; the cable
    is taut and the hackers reel themselves in."""
    rng = random.Random(31)
    img, d = canvas(220, 150, SPACE + (255,))
    starfield(img, rng, 70)
    ship_at = (70, 74)
    hacker_at = (168, 50)
    hook = (ship_at[0] - 8, ship_at[1] - 12)
    put(img, diplomatic_ship(), *ship_at)
    put(img, turned(hacker_ship(), 160), *hacker_at)
    nose = (hacker_at[0] + math.cos(math.radians(160)) * 36, hacker_at[1] - math.sin(math.radians(160)) * 36)
    d = ImageDraw.Draw(img)
    harpoon(d, *hook, math.atan2(hook[1] - nose[1], hook[0] - nose[0]), *nose, taut=True)
    for x, y in ((hook[0] - 3, hook[1] + 3), (hook[0] + 2, hook[1] - 3)):
        d.point((x, y), fill=YELLOW)
    d.text((8, 118), "KLARA: The harpoon's in! They're", font=FONT, fill=CREAM)
    d.text((8, 130), "pulling us in!", font=FONT, fill=CREAM)
    return img


def jump_across():
    """Ending B: the hackers' ship is wrecked and drifting, and the phase hacker
    jumps onto the white ship's hull by the hatch with a cable for the others."""
    rng = random.Random(44)
    img, d = canvas(220, 150, SPACE + (255,))
    starfield(img, rng, 70)
    hacker_at = (150, 46)
    for i in range(9):
        x = hacker_at[0] + 14 + i * 5 + rng.randrange(-2, 3)
        y = hacker_at[1] - 6 - i * 2 + rng.randrange(-2, 3)
        r = 2 + i // 2
        d.ellipse((x - r, y - r, x + r, y + r), fill=SMOKE)
    put(img, turned(hacker_ship(), 200), *hacker_at)
    d = ImageDraw.Draw(img)
    blast(d, hacker_at[0] + 6, hacker_at[1] + 4, 6)
    ship_at = (70, 80)
    put(img, diplomatic_ship(), *ship_at)
    d = ImageDraw.Draw(img)
    # the jump: a dotted teal line, a flash where the hacker left and where he lands
    start = (hacker_at[0] - 20, hacker_at[1] + 10)
    land = (ship_at[0] - 22, ship_at[1] - 18)
    phase_flash(d, *start, 6)
    for k in range(1, 12):
        t = k / 12
        d.point((start[0] + (land[0] - start[0]) * t, start[1] + (land[1] - start[1]) * t), fill=TEAL_GLOW)
    phase_flash(d, *land, 6)
    d.rectangle((land[0] - 1, land[1] - 2, land[0] + 1, land[1] + 2), fill=INDIGO, outline=INK)
    d.text((8, 118), "HACKER: Our ship? Keep it. We were", font=FONT, fill=TEAL_GLOW)
    d.text((8, 130), "never staying on it.", font=FONT, fill=TEAL_GLOW)
    return img


def boarding():
    """What comes next: inside the white ship, the hatch glows where the cutter
    goes through it. This is the existing boarding fight."""
    img, d = canvas(220, 110, (40, 34, 58, 255))
    # the ship room from above, cabin at the left, hatch at the right
    d.rectangle((10, 14, 210, 96), fill=WHITE_SHADE, outline=INK)
    d.rectangle((14, 18, 206, 92), fill=(198, 202, 210))
    d.rectangle((14, 18, 60, 92), fill=(176, 160, 140))
    d.text((18, 22), "cabin", font=FONT, fill=INK)
    for y in (40, 62):
        d.rectangle((20, y, 52, y + 8), fill=BLUE, outline=INK)
    # the two guards
    for y in (40, 66):
        d.rectangle((120, y, 125, y + 8), fill=BLUE_DARK, outline=INK)
    # the hatch with a glowing cut line
    d.rectangle((196, 34, 206, 76), fill=WHITE_DARK, outline=INK)
    d.line((196, 36, 196, 74), fill=FIRE, width=2)
    d.line((196, 36, 206, 36), fill=FIRE, width=2)
    rng = random.Random(5)
    for _ in range(14):
        y = rng.randrange(36, 75)
        d.point((196 - rng.randrange(2, 9), y + rng.randrange(-2, 3)), fill=rng.choice((YELLOW, GLOW_HOT, FIRE)))
    d.text((140, 80), "hatch", font=FONT, fill=INK)
    return img


def build():
    sheet = Image.new("RGBA", (1520, 1540), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def label(x, y, title):
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)

    def panel(img, x, y, scale, title, note):
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 18))
        label(x, y, title)
        d.text((x, y + 24 + big.height), note, font=FONT, fill=CREAM)

    panel(lesson(), 20, 10, 2, "CHVARAK - THE PLAYER'S FIRST SHIP BATTLE",
          "Soon after take-off a ship comes up behind the white diplomatic ship with its lights off. Klara, the pilot, calls the Captain to the cockpit\n"
          "and hands them the ship's guns: two TNT launchers on each side, behind blue hatches. She explains the controls one line at a time.\n"
          "Chvarak is still below. Crew in the HUD: you, Klara, two ship guards and the three envoys.")
    panel(fight(), 20, 630, 2, "THE FIGHT",
          "The hackers' ship is faster than the white ship. It keeps its distance and fires pairs of teal bolts, and every few seconds\n"
          "it fires a harpoon on a cable from its nose. The harpoon flies straight and slowly: turning away makes it miss.\n"
          "Here the white ship's left side has fired and a barrel bursts on their hull. The hackers say from the start that they will board.")
    panel(harpooned(), 1000, 10, 2, "ENDING A - HARPOONED",
          "The harpoon catches the hull by the hatch.\nThe cable goes taut and the hackers reel\nthemselves in. Banner: HARPOONED.\n"
          "Also the ending when the white ship's hull\nreaches 0: Klara can't steer any more.")
    panel(jump_across(), 1000, 420, 2, "ENDING B - THEY JUMP ACROSS",
          "If the player wrecks their ship first, the\nphase hacker jumps onto the white ship's\nhull with a cable for the others.\n"
          "Banner: THEY'RE COMING ACROSS.\nThe hackers are not hurt by the wreck.")
    panel(boarding(), 1000, 830, 2, "THEN - THE BOARDING (EXISTING)",
          "Either way the cutter is at the hatch.\nThe boarding fight in chvarak_world.gd follows\nunchanged: same waves, same hacker stats,\nthe crash at 50 s or when the Captain is downed.")

    y0 = 1260
    for i, (img, title, note) in enumerate((
            (diplomatic_ship(), "THE COUNCIL'S WHITE SHIP FROM ABOVE",
             "White hull with the blue and gold stripe of its side view,\nglass cockpit, cabin windows, swept fins, one engine,\n"
             "the Confederation's blue disc on the roof and two TNT\nlaunchers a side behind blue hatches. A courier, not a warship."),
            (hacker_ship(), "THE HACKERS' SHIP FROM ABOVE",
             "Indigo hull shaped like the hackers' hood, a teal visor slit\nfor a cockpit, a teal screen with green signs on its back,\n"
             "two cable antennas trailing behind, bolt lamps on short\nwings and a harpoon with its cable drum on the nose."))):
        big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        x = 20 + i * 400
        label(x, y0, title)
        sheet.alpha_composite(big, (x, y0 + 20))
        d.text((x, y0 + 30 + big.height), note, font=FONT, fill=CREAM)

    x, y = 840, y0
    label(x, y, "FLOW")
    d.text((x, y + 20),
           "1. Board the ship, the take-off lines.\n"
           "2. Klara sees the hackers' ship and calls the Captain to the guns.\n"
           "3. Ship battle: Klara explains the controls; the hackers say they will board.\n"
           "4. Harpoon hits, hull at 0, or their ship wrecked: the battle ends, nobody loses it.\n"
           "5. A short scene: the cable, the cutter at the hatch.\n"
           "6. The existing boarding fight; hackers unchanged; the crash on Rudnik.\n\n"
           "At 50 s a second hackers' ship hits the white ship and it goes down.\n"
           "No guns for people: only ships carry TNT launchers, bolt lamps and harpoons.",
           font=FONT, fill=CREAM)
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name, img in (("diplomatic_ship", diplomatic_ship()), ("hacker_ship", hacker_ship())):
        img.save(ASSETS / (name + ".png"))
        print((ASSETS / (name + ".png")).relative_to(ROOT))


if __name__ == "__main__":
    main()
