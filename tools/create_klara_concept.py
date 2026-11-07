#!/usr/bin/python3
"""Concept sheet for Klara Rog, the pilot Iva Most hired for the Council's white
diplomatic ship. She has flown to Engineeria a dozen times, so all three versions
look experienced rather than new.

Each version is a 16x26 sprite built on the shared person body from
create_pomidor_art.py, shown at 1x and 8x next to a Chvarak ship guard and the
player for scale.

Writes art/concepts/klara_concept.png and, for version A, which the user picked,
assets/art/chvarak/klara_rog.png. Also writes assets/art/chvarak/ship_console.png,
the pilot's console she sits at inside the diplomatic ship.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from create_pomidor_art import person, SKINS, HAIRS

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/klara_concept.png"
SPRITE_OUT = ROOT / "assets/art/chvarak/klara_rog.png"
CONSOLE_OUT = ROOT / "assets/art/chvarak/ship_console.png"

INK = (28, 23, 48)
WHITE = (236, 236, 228)
WHITE_SHADE = (196, 200, 204)
COUNCIL_BLUE = (70, 110, 170)
LEATHER = (130, 84, 52)
LEATHER_DARK = (94, 58, 38)
SCARF = (196, 60, 52)
NAVY_COAT = (52, 72, 120)
NAVY_COAT_DARK = (36, 50, 88)
BRASS = (214, 176, 80)
LENS = (120, 196, 220)
GREY = (150, 150, 156)
GREY_LIGHT = (188, 188, 192)
BG = (30, 26, 44)
PANEL = (44, 40, 62)
TEXT = (236, 230, 214)
MUTED = (170, 164, 190)
FONT = ImageFont.load_default()


def goggles(d, y=4):
    """Goggles pushed up on the hair: a strap over the top hair row with two lenses."""
    d.line([(5, y), (10, y)], fill=LEATHER_DARK)
    for x in (6, 9):
        d.point((x, y), fill=LENS)


def klara_a():
    """Council flight jacket: white with a blue collar and stripe, goggles up, a dark braid."""
    img = Image.new("RGBA", (16, 26), (0, 0, 0, 0))
    img.alpha_composite(person(WHITE, WHITE_SHADE, SKINS[0], HAIRS[1]), (0, 2))
    d = ImageDraw.Draw(img)
    d.line([(4, 12), (11, 12)], fill=COUNCIL_BLUE)  # collar
    d.line([(3, 16), (12, 16)], fill=COUNCIL_BLUE)  # chest stripe
    d.point((9, 14), fill=BRASS)  # wings badge
    d.point((10, 14), fill=BRASS)
    goggles(d, 4)
    for y in range(7, 11):  # hair framing the face
        d.point((4, y), fill=HAIRS[1])
    for y in range(9, 15):  # braid down the back, showing at her right
        d.point((11, y), fill=HAIRS[1])
    d.point((11, 15), fill=SCARF)
    return img


def klara_b():
    """Brown leather flying jacket, red scarf, short grey-streaked hair: the old hand."""
    img = Image.new("RGBA", (16, 26), (0, 0, 0, 0))
    img.alpha_composite(person(LEATHER, LEATHER_DARK, SKINS[3], GREY), (0, 2))
    d = ImageDraw.Draw(img)
    for x in (6, 9):
        d.point((x, 4), fill=GREY_LIGHT)  # grey streaks
    d.line([(4, 12), (11, 12)], fill=SCARF)
    d.line([(10, 13), (12, 15)], fill=SCARF)  # scarf end
    d.line([(7, 13), (7, 18)], fill=(176, 120, 80))  # zip
    goggles(d, 4)
    return img


def klara_c():
    """Navy Confederation pilot coat with brass buttons, a headset with a mic, fair hair in a bun."""
    img = Image.new("RGBA", (16, 28), (0, 0, 0, 0))
    img.alpha_composite(person(NAVY_COAT, NAVY_COAT_DARK, SKINS[1], HAIRS[2]), (0, 4))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 2, 9, 6), fill=HAIRS[2], outline=INK)  # bun
    d.line([(5, 6), (10, 6)], fill=(60, 60, 70))  # headset band over the hair
    d.rectangle((4, 9, 5, 10), fill=(60, 60, 70), outline=INK)  # ear cups
    d.rectangle((10, 9, 11, 10), fill=(60, 60, 70), outline=INK)
    d.line([(5, 11), (7, 12)], fill=(60, 60, 70))  # mic
    for y in (15, 17):
        d.point((7, y), fill=BRASS)
    d.line([(3, 14), (12, 14)], fill=WHITE)  # white Council collar
    return img


def ship_console():
    """The pilot's console against the ship's north wall: white casing in Council
    blue, two screens, a row of lights and the launcher lever."""
    img = Image.new("RGBA", (48, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(2, 27), (4, 8), (44, 8), (46, 27)], fill=WHITE, outline=INK)
    d.rectangle((3, 20, 45, 27), fill=WHITE_SHADE, outline=INK)
    d.line([(4, 20), (44, 20)], fill=COUNCIL_BLUE, width=2)
    for x in (8, 26):
        d.rectangle((x, 10, x + 14, 18), fill=(30, 48, 70), outline=INK)
        d.line([(x + 2, 15), (x + 5, 12), (x + 8, 14), (x + 12, 11)], fill=LENS)
    for i, x in enumerate(range(8, 42, 5)):
        d.point((x, 23), fill=[SCARF, BRASS, LENS][i % 3])
    d.line([(40, 8), (42, 2)], fill=INK, width=2)  # launcher lever
    d.ellipse((40, 0, 44, 4), fill=SCARF, outline=INK)
    return img


def main():
    versions = [("A", "COUNCIL FLIGHT JACKET", ["white jacket, Council blue", "goggles up, dark braid"], klara_a()),
                ("B", "OLD HAND", ["leather flying jacket", "red scarf, grey streaks"], klara_b()),
                ("C", "CONFEDERATION PILOT", ["navy coat, brass buttons", "headset, fair hair in a bun"], klara_c())]
    scale = 8
    col_w = 240
    sheet = Image.new("RGBA", (col_w * 3 + 40, 420), BG + (255,))
    d = ImageDraw.Draw(sheet)
    d.text((20, 12), "KLARA ROG - PILOT OF THE COUNCIL'S DIPLOMATIC SHIP (concept, pick A, B or C)", font=FONT, fill=TEXT)
    guard = Image.open(ROOT / "assets/art/chvarak/ship_guard_0.png").convert("RGBA") if (ROOT / "assets/art/chvarak/ship_guard_0.png").exists() else None
    player = Image.open(ROOT / "assets/art/player_blue.png").convert("RGBA")
    for i, (key, title, notes, sprite) in enumerate(versions):
        x0 = 20 + i * col_w
        d.rectangle((x0, 34, x0 + col_w - 16, 404), fill=PANEL, outline=MUTED)
        d.text((x0 + 10, 42), f"{key}  {title}", font=FONT, fill=TEXT)
        big = sprite.resize((sprite.width * scale, sprite.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x0 + (col_w - 16 - big.width) // 2, 62))
        for j, note in enumerate(notes):
            d.text((x0 + 10, 300 + j * 14), note, font=FONT, fill=MUTED)
        # 1x lineup at 2x: player, Klara, a ship guard
        y = 380
        lineup = [player, sprite] + ([guard] if guard is not None else [])
        x = x0 + 40
        for s in lineup:
            s2 = s.resize((s.width * 2, s.height * 2), Image.NEAREST)
            sheet.alpha_composite(s2, (x, y - s2.height))
            x += s2.width + 14
        d.text((x0 + 10, 386), "you  /  Klara  /  ship guard" if guard is not None else "you  /  Klara", font=FONT, fill=MUTED)
    sheet.convert("RGB").save(OUT)
    klara_a().save(SPRITE_OUT)
    ship_console().save(CONSOLE_OUT)
    for path in (OUT, SPRITE_OUT, CONSOLE_OUT):
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
