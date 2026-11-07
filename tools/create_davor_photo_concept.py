#!/usr/bin/python3
"""Concept sheet: an easter egg in Krešo's bar on Smokva.

A faded photo hangs on the wall between the TV and the back door. It shows a
Davor at about 40, his beard still brown, drinking at this counter with a Brine
of about 20 with white eyes, the one Krešo half remembers: the Voice from
R-7, before his body was destroyed. They knew each other
and came here together. A younger Krešo stands behind the counter.

Writes art/concepts/davor_photo_concept.png and, for the game,
assets/art/smokva/davor_photo.png (the framed photo, shown big when the player
looks at it) and assets/art/smokva/photo_frame.png (the small frame on the
bar wall, drawn at the room's own scale).
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/davor_photo_concept.png"
ASSETS = ROOT / "assets/art/smokva"
## Where the small frame hangs in assets/art/smokva/room.png, top left.
FRAME_AT = (60, 6)
FONT = ImageFont.load_default()

INK = (28, 23, 48)
CREAM = (238, 222, 184)
YELLOW = (236, 192, 56)
WALL_RED = (196, 72, 44)
WALL_RED_DARK = (150, 52, 34)
COUNTER = (128, 40, 52)
COUNTER_DARK = (92, 28, 40)
COUNTER_TOP = (160, 64, 72)
SHELF = (70, 44, 34)
SKIN = (222, 170, 120)
SKIN_DARK = (186, 132, 92)
DAVOR_BEARD = (122, 80, 44)
DAVOR_CAP = (198, 200, 206)
DAVOR_VEST = (108, 92, 64)
DAVOR_SHIRT = (214, 214, 206)
DAVOR_EYE = (70, 130, 220)
BRINE_HAIR = (46, 32, 30)
BRINE_HAIR_SHINE = (96, 70, 58)
DAVOR_GREY = (176, 166, 150)
BRINE_CLOAK = (78, 96, 84)
BRINE_CLOAK_DARK = (56, 70, 62)
BRINE_EYE = (255, 255, 255)
BRINE_GLOW = (200, 236, 255)
KRESO_HAIR = (44, 30, 26)
KRESO_APRON = (34, 90, 56)
KRESO_DOT = (236, 200, 60)
TOWEL = (236, 232, 214)
BEER = (236, 176, 48)
FOAM = (250, 246, 230)
GLASS = (200, 220, 230)
FRAME = (92, 56, 34)
FRAME_LIGHT = (140, 92, 56)


def rect(d, x, y, w, h, colour):
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=colour)


def mug(d, x, y):
    """A beer mug, 4x5, handle on the right."""
    rect(d, x, y + 1, 4, 4, BEER)
    rect(d, x, y, 4, 1, FOAM)
    d.point((x + 4, y + 2), fill=GLASS)
    d.point((x + 4, y + 3), fill=GLASS)


def davor(d, x, y):
    """Davor at about 40: the same grey cap and blue eyes, a brown beard with the
    first grey in it, raising a beer."""
    rect(d, x + 1, y, 8, 3, DAVOR_CAP)                 # cap
    rect(d, x + 1, y + 3, 8, 6, SKIN)                  # face
    d.point((x + 3, y + 5), fill=DAVOR_EYE)
    d.point((x + 6, y + 5), fill=DAVOR_EYE)
    rect(d, x + 1, y + 7, 8, 4, DAVOR_BEARD)           # beard
    rect(d, x + 3, y + 7, 4, 1, SKIN_DARK)             # grin
    d.point((x + 1, y + 9), fill=DAVOR_GREY)           # first grey in the beard
    d.point((x + 8, y + 8), fill=DAVOR_GREY)
    rect(d, x + 0, y + 11, 10, 10, DAVOR_SHIRT)        # shirt
    rect(d, x + 2, y + 11, 6, 10, DAVOR_VEST)          # vest
    rect(d, x - 2, y + 6, 2, 6, DAVOR_SHIRT)           # raised arm
    mug(d, x - 4, y + 1)


def brine(d, x, y):
    """The Voice at about 20, a Brine already: as tall as Davor, handsome, dark
    hair swept to one side, a strong jaw, a sure half-smile, white eyes with a
    faint glow, an open travel jacket over a light shirt, one arm over Davor's
    shoulder."""
    rect(d, x + 1, y + 1, 9, 3, BRINE_HAIR)            # hair, swept to the right
    rect(d, x + 3, y, 7, 1, BRINE_HAIR)
    rect(d, x + 4, y + 1, 4, 1, BRINE_HAIR_SHINE)      # shine
    rect(d, x + 7, y + 4, 3, 1, BRINE_HAIR)            # fringe falling over the brow
    rect(d, x + 1, y + 4, 9, 7, SKIN)                  # face
    rect(d, x + 1, y + 4, 1, 3, BRINE_HAIR)            # sideburn
    rect(d, x + 3, y + 5, 2, 1, BRINE_HAIR)            # brows
    rect(d, x + 7, y + 5, 2, 1, BRINE_HAIR)
    for ex in (x + 4, x + 7):
        d.point((ex - 1, y + 6), fill=BRINE_GLOW)
        d.point((ex, y + 6), fill=BRINE_EYE)
    d.point((x + 6, y + 7), fill=SKIN_DARK)            # nose
    d.point((x + 6, y + 8), fill=SKIN_DARK)
    rect(d, x + 4, y + 9, 3, 1, SKIN_DARK)             # half-smile, up at one corner
    d.point((x + 7, y + 8), fill=SKIN_DARK)
    rect(d, x + 1, y + 10, 1, 1, SKIN_DARK)            # jaw
    rect(d, x + 9, y + 10, 1, 1, SKIN_DARK)
    rect(d, x + 3, y + 11, 5, 1, SKIN_DARK)            # neck shadow
    rect(d, x, y + 11, 11, 11, BRINE_CLOAK)            # jacket
    rect(d, x + 4, y + 11, 3, 11, DAVOR_SHIRT)         # open over a light shirt
    d.point((x + 3, y + 12), fill=BRINE_CLOAK_DARK)    # lapels
    d.point((x + 7, y + 12), fill=BRINE_CLOAK_DARK)
    rect(d, x - 6, y + 11, 7, 2, BRINE_CLOAK)          # arm over Davor's shoulder
    rect(d, x + 11, y + 12, 2, 5, BRINE_CLOAK)         # other arm, holding a beer on the counter
    mug(d, x + 11, y + 16)


def kreso(d, x, y):
    """Krešo, younger, behind the counter: dark hair, a shorter beard, the dotted apron
    and the towel on his shoulder, wiping a glass as always."""
    rect(d, x + 1, y, 8, 3, KRESO_HAIR)
    rect(d, x + 1, y + 3, 8, 5, SKIN)
    d.point((x + 3, y + 4), fill=INK)
    d.point((x + 6, y + 4), fill=INK)
    rect(d, x + 1, y + 6, 8, 3, KRESO_HAIR)
    rect(d, x, y + 9, 10, 10, KRESO_APRON)
    for dx, dy in ((2, 11), (6, 13), (3, 16)):
        d.point((x + dx, y + dy), fill=KRESO_DOT)
    rect(d, x - 1, y + 9, 2, 6, TOWEL)
    rect(d, x + 10, y + 10, 3, 4, GLASS)


def photo_scene():
    """The photo at native size, 84x60, before it fades."""
    img = Image.new("RGBA", (84, 60), WALL_RED)
    d = ImageDraw.Draw(img)
    rect(d, 0, 22, 84, 38, WALL_RED_DARK)
    # Bottle shelf behind the counter.
    rect(d, 40, 6, 44, 2, SHELF)
    rect(d, 40, 16, 44, 2, SHELF)
    rng = random.Random(3)
    for row in (1, 11):
        for bx in range(42, 82, 3):
            colour = rng.choice([(60, 120, 70), (120, 70, 40), (200, 190, 150), (70, 80, 140)])
            rect(d, bx, row, 2, 5, colour)
    kreso(d, 58, 20)
    # The counter in front, the two friends leaning on it.
    davor(d, 14, 22)
    brine(d, 30, 21)
    rect(d, 0, 42, 84, 3, COUNTER_TOP)
    rect(d, 0, 45, 84, 15, COUNTER)
    rect(d, 0, 52, 84, 1, COUNTER_DARK)
    mug(d, 66, 38)
    return img


def faded(img):
    """An old print: warm, washed-out colours, a darker edge, a crease and a torn corner."""
    w, h = img.size
    out = Image.new("RGBA", img.size)
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            grey = (r + g + b) / 3
            r, g, b = (grey * 0.45 + r * 0.55, grey * 0.45 + g * 0.55, grey * 0.45 + b * 0.55)
            r, g, b = r * 1.04 + 18, g * 0.98 + 12, b * 0.86
            edge = min(x, y, w - 1 - x, h - 1 - y)
            if edge < 4:
                r, g, b = r * (0.82 + 0.045 * edge), g * (0.82 + 0.045 * edge), b * (0.82 + 0.045 * edge)
            out.putpixel((x, y), (int(min(255, r)), int(min(255, g)), int(min(255, b)), a))
    d = ImageDraw.Draw(out)
    for i in range(h):
        x = 52 + i // 9
        r, g, b, a = out.getpixel((x, i))
        out.putpixel((x, i), (min(255, r + 26), min(255, g + 24), min(255, b + 20), a))
    d.polygon([(w - 1, h - 6), (w - 1, h - 1), (w - 6, h - 1)], fill=(0, 0, 0, 0))
    # The Brine's eyes stay white; they never fade on any print.
    for ex in (34, 37):
        out.putpixel((ex, 27), BRINE_EYE + (255,))
    return out


def framed(photo):
    w, h = photo.size
    img = Image.new("RGBA", (w + 8, h + 8), FRAME)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w + 7, h + 7), outline=INK)
    d.rectangle((2, 2, w + 5, h + 5), outline=FRAME_LIGHT)
    img.alpha_composite(photo, (4, 4))
    return img


def wall_frame():
    """The photo as it looks on the wall from across the room: a 10x8 frame with
    two small figures and one white point for the eyes."""
    img = Image.new("RGBA", (10, 8), FRAME)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 9, 7), outline=INK)
    d.rectangle((2, 2, 7, 5), fill=(200, 160, 120))
    d.point((3, 3), fill=(120, 90, 60))
    d.point((6, 3), fill=(90, 66, 50))
    d.point((6, 2), fill=(255, 255, 255))
    return img


def wall_view():
    """The top of the bar room with the photo hung between the TV and the back door."""
    room = Image.open(ROOT / "assets/art/smokva/room.png").convert("RGBA").crop((0, 0, 200, 40))
    room.alpha_composite(wall_frame(), FRAME_AT)
    return room


def back_of_photo():
    img = Image.new("RGBA", (200, 70), (226, 212, 180, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 199, 69), outline=(170, 150, 120))
    d.text((10, 10), "SMOKVA. D. and the kid.", font=FONT, fill=(70, 60, 90))
    d.text((10, 26), "Their tab is still open!!", font=FONT, fill=(70, 60, 90))
    d.text((10, 42), "            - K.", font=FONT, fill=(70, 60, 90))
    return img


def build():
    sheet = Image.new("RGBA", (1240, 580), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)

    def label(x, y, title):
        d.rectangle((x, y, x + int(d.textlength(title, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), title, font=FONT, fill=INK)

    def panel(img, x, y, scale, title, note):
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + 18))
        label(x, y, title)
        d.text((x, y + 24 + big.height), note, font=FONT, fill=CREAM)

    panel(framed(faded(photo_scene())), 20, 10, 7, "THE PHOTO (shown big when you look at it)",
          "Davor at about 40, beard still brown with the first grey, the same grey cap and blue eyes, raises a beer.\n"
          "The Brine, about 20, has an arm over his shoulder: handsome, dark hair swept aside, a half-smile, white eyes. He is the Voice from R-7.\n"
          "Behind the counter, a younger Kreso wipes a glass. The colours have faded; the white eyes have not.")
    panel(wall_view(), 700, 10, 2, "WHERE IT HANGS",
          "Top wall of the bar, between the TV and the back door.\nA small frame you can walk up to and look at.")
    panel(back_of_photo(), 700, 160, 2, "THE BACK OF THE PHOTO",
          "Kreso's handwriting.")
    d.text((700, 340), "LOOKING AT IT (proposed lines)", font=FONT, fill=YELLOW)
    d.multiline_text((700, 360),
                     "\"A faded photo in a wooden frame. Two men drinking at this counter.\n"
                     " One is Davor, years younger. The other is a young man with white eyes.\"\n\n"
                     "Turn it over: the back of the photo.\n\n"
                     "Then, if Kreso is asked about it:\n"
                     "Kreso: \"What photo? There's no photo there. There's never been a photo.\"\n"
                     "Kreso: \"...They never paid, you know. Either of them.\"\n\n"
                     "Once Donat has joined, he can look at it too:\n"
                     "Donat: \"That one with the cap has my eyes. ...Weird. Whatever.\"",
                     font=FONT, fill=CREAM, spacing=4)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    framed(faded(photo_scene())).save(ASSETS / "davor_photo.png")
    wall_frame().save(ASSETS / "photo_frame.png")
    print("wrote", OUT)


if __name__ == "__main__":
    build()
