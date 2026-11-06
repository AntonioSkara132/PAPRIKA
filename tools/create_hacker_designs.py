#!/usr/bin/python3
"""Concept sheet: eight hacker designs inspired by rapper fashion, pushed a little wonky and clownish.

Every outfit keeps the dots that all hackers in the game wear (Krešo's apron, Donat's hoodie,
the troopers on R-7). The bodies use the same 16x24 player body as the rest of the cast; each
figure sits on a 24x36 canvas so hats and props can stick out past it.

Writes art/concepts/hacker_designs.png.
"""

from pathlib import Path
import math

from PIL import Image, ImageDraw

from create_otpornik_ship_art import INK, CREAM, YELLOW, FONT

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/hacker_designs.png"

W, H = 24, 36
OX, OY = 4, 12  # where the 16x24 body sits on the canvas
PLAIN = {"hair": (91, 57, 44), "outline": (28, 23, 48), "skin": (220, 167, 120), "shirt": (78, 131, 207),
         "shade": (174, 121, 85), "trousers": (65, 57, 71)}
OUTLINE = PLAIN["outline"]
GOLD = (246, 200, 64)
GOLD_DARK = (178, 128, 34)
WHITE = (246, 244, 236)
RED = (222, 52, 44)
GLASS = (170, 220, 236)
WATER = (60, 140, 200)


def body(skin=None, hair=None, shirt=None, trousers=None, dots=None, dot_every=3):
    """The plain body on a 24x36 canvas, recoloured; dots go on the shirt."""
    src = Image.open(ROOT / "assets/art/player_plain.png").convert("RGBA")
    px = src.load()
    swap = {PLAIN["skin"]: skin, PLAIN["hair"]: hair, PLAIN["shirt"]: shirt, PLAIN["trousers"]: trousers}
    for y in range(src.height):
        for x in range(src.width):
            c = px[x, y]
            if not c[3]:
                continue
            new = swap.get(c[:3])
            if c[:3] == PLAIN["shirt"] and dots and y % 2 == 0 and (x + y // 2) % dot_every == 0:
                new = dots
            if new:
                px[x, y] = new + (255,)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(src, (OX, OY))
    return img, ImageDraw.Draw(img)


def at(x, y):
    """Body coordinates (the 16x24 sprite) to canvas coordinates."""
    return x + OX, y + OY


def box(d, x0, y0, x1, y1, fill, outline=None):
    d.rectangle((x0 + OX, y0 + OY, x1 + OX, y1 + OY), fill=fill, outline=outline)


def pt(d, x, y, fill):
    d.point(at(x, y), fill=fill)


def line(d, x0, y0, x1, y1, fill):
    d.line((x0 + OX, y0 + OY, x1 + OX, y1 + OY), fill=fill)


def chain(d, y, x0=5, x1=10, drop=2, pendant=None):
    """A gold chain hanging from the shoulders in a V."""
    mid = (x0 + x1) / 2
    for x in range(x0, x1 + 1):
        dy = round(drop * (1 - abs(x - mid) / (mid - x0 + 0.01)))
        pt(d, x, y + dy, GOLD if x % 2 else GOLD_DARK)
    if pendant:
        pendant(d, round(mid), y + drop + 1)


def sneakers(d, color, sole=WHITE, wide=1):
    box(d, 4 - wide, 21, 7, 23, color, OUTLINE)
    box(d, 8, 21, 11 + wide, 23, color, OUTLINE)
    line(d, 4 - wide, 23, 7, 23, sole)
    line(d, 8, 23, 11 + wide, 23, sole)


def baggy_legs(d, color, dots=None):
    box(d, 4, 16, 11, 21, color, OUTLINE)
    line(d, 8, 17, 8, 21, OUTLINE)
    if dots:
        for x, y in ((5, 17), (10, 18), (6, 20), (9, 20)):
            pt(d, x, y, dots)


# ---------- the eight hackers ----------

def aquarium():
    """A glass fish bowl worn as a hat, full of water, with a fish and weed; a teal puffer
    vest with white dots, a heavy chain, baggy jeans and chunky white sneakers."""
    img, d = body(skin=(150, 96, 64), hair=(30, 24, 30), shirt=(40, 150, 150), dots=WHITE,
                  trousers=(70, 96, 150))
    baggy_legs(d, (70, 96, 150))
    sneakers(d, WHITE, (200, 200, 210))
    # puffer quilting lines
    for y in (11, 13, 15):
        line(d, 5, y, 10, y, (30, 110, 112))
    chain(d, 10, drop=3, pendant=lambda d, x, y: box(d, x - 1, y, x, y + 1, GOLD, GOLD_DARK))
    # the bowl: a round glass on the head, water in the lower two thirds
    cx, cy, r = 12, 7, 9
    d.ellipse((cx - r, cy - r + 1, cx + r, cy + r - 1), fill=GLASS + (255,), outline=OUTLINE)
    d.chord((cx - r + 1, cy - r + 2, cx + r - 1, cy + r - 2), 200, 340, fill=None)
    d.pieslice((cx - r + 1, cy - r + 2, cx + r - 1, cy + r - 2), -10, 190, fill=WATER)
    d.rectangle((cx - r + 2, cy, cx + r - 2, cy), fill=(120, 190, 230))  # the water line
    d.rectangle((cx - 4, 1, cx + 4, 2), fill=GLASS, outline=OUTLINE)  # the open rim
    # weed and pebbles at the bottom, an orange fish, bubbles
    for x, h in ((7, 4), (9, 6), (16, 5)):
        d.line((x, cy + r - 3, x + (1 if h > 4 else 0), cy + r - 3 - h), fill=(60, 160, 80))
    for x in range(6, 19, 2):
        d.point((x, cy + r - 2), fill=(200, 180, 150))
    d.rectangle((11, 10, 13, 11), fill=(250, 130, 30))
    d.point((14, 10), fill=(250, 130, 30))
    d.point((14, 11), fill=(250, 130, 30))
    d.point((10, 10), fill=INK)
    for x, y in ((12, 4), (13, 2), (8, 5)):
        d.point((x, y), fill=WHITE)
    d.point((5, 3), fill=WHITE)  # glint on the glass
    d.point((5, 4), fill=WHITE)
    # the face shows through the bottom of the bowl: keep the eye
    pt(d, 8, 6, (40, 40, 40))
    return img


def big_puffer():
    """A puffer jacket three sizes too big, zipped up to the nose, purple with gold dots;
    slatted shutter shades, skinny legs and huge red sneakers."""
    img, d = body(skin=(236, 190, 150), hair=(240, 220, 90), shirt=(120, 60, 170), trousers=(40, 36, 46))
    # the jacket: wider than the body, puffy segments
    d.rounded_rectangle((2, 20, 21, 31), 4, fill=(120, 60, 170), outline=OUTLINE)
    for y in (23, 26, 29):
        d.line((4, y, 19, y), fill=(90, 40, 130))
    for x, y in ((5, 22), (11, 25), (17, 22), (7, 28), (15, 28), (14, 22)):
        d.point((x, y), fill=GOLD)
    d.line((12, 20, 12, 31), fill=(200, 200, 210))  # the zip
    # the collar up over the mouth
    d.rectangle((8, 19, 15, 21), fill=(120, 60, 170), outline=OUTLINE)
    # shutter shades: white slats across the eyes
    d.rectangle((8, 17, 15, 18), fill=WHITE)
    for x in (10, 12, 14):
        d.point((x, 17), fill=OUTLINE)
    # bleached spiky hair
    for x in (9, 11, 13):
        d.point((x, 13), fill=(240, 220, 90))
    # skinny legs, giant sneakers
    sneakers(d, RED, WHITE, wide=2)
    return img


def grills():
    """A bucket hat pulled over the eyes, a grin full of gold teeth, a red tracksuit with white
    stripes and white dots, a floppy disk on the chain."""
    img, d = body(skin=(110, 70, 50), hair=(20, 16, 20), shirt=(200, 40, 40), dots=WHITE, trousers=(200, 40, 40))
    # stripes down the sleeves and legs
    for x in (3, 12):
        line(d, x, 10, x, 15, WHITE)
    line(d, 4, 17, 4, 21, WHITE)
    line(d, 11, 17, 11, 21, WHITE)
    sneakers(d, WHITE, (40, 40, 40))
    # bucket hat, yellow with black dots, brim over the eyes
    d.polygon([at(2, 6), at(13, 6), at(11, 4), at(10, 1), at(5, 1), at(4, 4)], fill=(240, 200, 40), outline=OUTLINE)
    line(d, 3, 4, 12, 4, (200, 160, 30))
    for x, y in ((6, 2), (9, 3), (8, 5), (4, 5), (11, 5)):
        pt(d, x, y, INK)
    # a wide gold grin
    box(d, 5, 7, 10, 8, GOLD, OUTLINE)
    for x in (6, 8, 10):
        pt(d, x, 7, GOLD_DARK)
    # chain with a floppy disk
    def floppy(d, x, y):
        box(d, x - 2, y, x + 1, y + 3, (40, 40, 60), OUTLINE)
        box(d, x - 1, y, x, y + 1, (200, 200, 210))
    chain(d, 10, drop=2, pendant=floppy)
    return img


def fur_ruff():
    """A shaggy pink fur coat with a white clown ruff, huge round sunglasses, a red clown nose
    and three chains of different lengths."""
    img, d = body(skin=(240, 200, 170), hair=(60, 30, 80), shirt=(30, 30, 36), dots=(240, 120, 180),
                  trousers=(30, 30, 36))
    # the fur coat: jagged edges, open at the front
    for y in range(9, 21):
        jag = 1 if y % 2 else 0
        line(d, 2 - jag, y, 5, y, (240, 120, 180))
        line(d, 10, y, 13 + jag, y, (240, 120, 180))
    for x, y in ((3, 12), (11, 15), (4, 18), (12, 11)):
        pt(d, x, y, (255, 170, 210))
    line(d, 1, 9, 1, 20, OUTLINE)
    line(d, 14, 9, 14, 20, OUTLINE)
    sneakers(d, (30, 30, 36), (240, 120, 180))
    # the clown ruff
    for i, x in enumerate(range(3, 13)):
        box(d, x, 8 + (i % 2), x, 9 + (i % 2), WHITE)
    line(d, 3, 10, 12, 10, (200, 200, 210))
    # big round sunglasses and a red nose
    for cx in (6, 9):
        d.ellipse((cx + OX - 2, 4 + OY, cx + OX + 1, 7 + OY), fill=(20, 20, 30), outline=GOLD)
    pt(d, 8, 7, RED)
    pt(d, 7, 7, RED)
    # tall dark hair
    box(d, 5, -1, 10, 3, (60, 30, 80), OUTLINE)
    # three chains
    chain(d, 11, 5, 10, 1)
    chain(d, 12, 5, 10, 3)
    chain(d, 13, 5, 10, 5, pendant=lambda d, x, y: pt(d, x, y, (120, 220, 240)))
    return img


def cap_stack():
    """Five baseball caps stacked on the head, brims pointing every way; a jersey with a big
    number 4 and dots, long basketball shorts, tall socks."""
    img, d = body(skin=(200, 140, 100), hair=(40, 30, 30), shirt=(30, 120, 70), dots=(250, 240, 200),
                  dot_every=4, trousers=(30, 120, 70))
    # shorts and tall socks
    box(d, 4, 16, 11, 18, (30, 120, 70), OUTLINE)
    box(d, 5, 19, 7, 21, WHITE)
    box(d, 8, 19, 10, 21, WHITE)
    line(d, 5, 20, 7, 20, RED)
    line(d, 8, 20, 10, 20, RED)
    sneakers(d, (40, 40, 40), WHITE)
    # jersey number
    # a big 4 on the jersey
    for x, y in ((6, 11), (6, 12), (7, 13), (8, 13), (9, 11), (9, 12), (9, 13), (9, 14), (9, 15)):
        pt(d, x, y, WHITE)
    # the stack: each cap shifted and its brim on a different side
    caps = [((40, 60, 160), 1), (RED, -1), ((240, 200, 40), 1), ((40, 40, 40), -1), ((240, 120, 30), 1)]
    for i, (color, side) in enumerate(caps):
        y = 2 - i * 3
        shift = (i % 2) * (1 if i % 4 == 1 else -1)
        box(d, 5 + shift, y - 2, 10 + shift, y, color, OUTLINE)
        if side > 0:
            line(d, 11 + shift, y, 13 + shift, y, color)
        else:
            line(d, 2 + shift, y, 4 + shift, y, color)
        pt(d, 7 + shift, y - 2, WHITE)
    return img


def cable_durag():
    """A durag whose long tails are cables ending in plugs, a CRT monitor carried on the
    shoulder like a boombox with a grin on its screen, baggy cargo trousers."""
    img, d = body(skin=(130, 84, 60), hair=(20, 16, 20), shirt=(30, 30, 36), dots=(70, 220, 120),
                  trousers=(110, 110, 80))
    baggy_legs(d, (110, 110, 80))
    box(d, 4, 18, 5, 19, (90, 90, 64), OUTLINE)  # cargo pockets
    box(d, 10, 18, 11, 19, (90, 90, 64), OUTLINE)
    sneakers(d, (70, 220, 120), WHITE)
    # the durag, green, tied at the back; its tails become cables
    box(d, 5, 1, 10, 4, (40, 160, 90), OUTLINE)
    line(d, 5, 4, 10, 4, (30, 120, 70))
    for i, (x0, y0) in enumerate(((4, 3), (4, 4))):
        pts = [at(x0, y0)]
        for k in range(1, 9):
            pts.append(at(x0 - 1 - (k % 2), y0 + k * 1.4 + i))
        d.line(pts, fill=(40, 40, 46))
        px, py = pts[-1]
        d.rectangle((px - 1, py, px, py + 1), fill=(200, 200, 210), outline=OUTLINE)
    # a CRT on the right shoulder
    box(d, 11, 2, 18, 8, (210, 200, 180), OUTLINE)
    box(d, 12, 3, 17, 6, (20, 40, 30))
    pt(d, 13, 4, (70, 220, 120))
    pt(d, 16, 4, (70, 220, 120))
    line(d, 13, 5, 16, 5, (70, 220, 120))
    line(d, 12, 8, 12, 10, OUTLINE)  # the arm holding it up
    pt(d, 17, 7, RED)
    return img


def rainbow_clown():
    """A rainbow afro under giant headphones, a red clown nose, dungarees with one strap down
    over a dotted shirt, and long clown sneakers."""
    img, d = body(skin=(240, 210, 180), hair=(240, 80, 60), shirt=(250, 240, 220), dots=(40, 80, 170),
                  trousers=(60, 90, 170))
    # dungarees: bib on the chest, one strap down
    box(d, 5, 12, 10, 16, (60, 90, 170), OUTLINE)
    line(d, 5, 9, 5, 12, (60, 90, 170))
    pt(d, 10, 12, GOLD)
    pt(d, 10, 13, GOLD)
    line(d, 11, 13, 11, 15, (60, 90, 170))  # the loose strap
    baggy_legs(d, (60, 90, 170))
    # long clown sneakers
    box(d, 0, 21, 7, 23, RED, OUTLINE)
    box(d, 8, 21, 15, 23, RED, OUTLINE)
    line(d, 0, 23, 7, 23, WHITE)
    line(d, 8, 23, 15, 23, WHITE)
    # rainbow afro: rings of colour
    colors = [(150, 60, 200), (60, 90, 220), (60, 180, 90), (250, 210, 40), (250, 140, 40), (230, 50, 50)]
    for i, c in enumerate(colors):
        r = 8 - i
        d.ellipse((12 - r, 7 - r, 12 + r, 7 + r - 1), fill=c)
    d.ellipse((4, -1, 20, 14), outline=OUTLINE)
    # the face over the hair
    box(d, 5, 5, 10, 8, (240, 210, 180), OUTLINE)
    pt(d, 8, 6, (78, 131, 207))
    pt(d, 9, 7, RED)
    pt(d, 9, 8, RED)
    pt(d, 6, 8, (180, 60, 60))
    # giant headphones
    box(d, 2, 4, 4, 9, (30, 30, 36), OUTLINE)
    box(d, 11, 4, 13, 9, (30, 30, 36), OUTLINE)
    pt(d, 3, 6, GOLD)
    pt(d, 12, 6, GOLD)
    d.arc((OX + 2, OY - 6, OX + 13, OY + 8), 180, 360, fill=(30, 30, 36))
    return img


def chandelier():
    """A small chandelier worn as a hat, lit; a maroon velvet tracksuit with gold dots, a
    toothpick and one gold tooth, sunglasses, rings on every finger."""
    img, d = body(skin=(176, 120, 86), hair=(20, 16, 20), shirt=(120, 30, 50), dots=GOLD,
                  trousers=(120, 30, 50))
    sneakers(d, GOLD, WHITE)
    line(d, 4, 17, 4, 21, GOLD)
    line(d, 11, 17, 11, 21, GOLD)
    # sunglasses, gold tooth, toothpick
    box(d, 6, 5, 10, 6, (20, 20, 30))
    pt(d, 7, 8, GOLD)
    line(d, 9, 8, 11, 7, (230, 210, 160))
    # rings on the hands
    for x in (3, 4, 11, 12):
        pt(d, x, 15, GOLD)
    # the chandelier: a gold hoop on a stem, arms with candles, crystal drops
    line(d, 7, 1, 7, -3, GOLD_DARK)
    pt(d, 8, -3, GOLD_DARK)
    d.ellipse((OX + 1, OY - 1, OX + 14, OY + 3), outline=GOLD)
    for x in (1, 4, 7, 11, 14):
        line(d, x, -1, x, -4, WHITE)
        pt(d, x, -5, (255, 220, 120))
        pt(d, x, -6, (255, 160, 60))
    for x in (2, 6, 9, 13):
        pt(d, x, 3, (190, 230, 250))
        pt(d, x, 4, (150, 200, 240))
    chain(d, 10, drop=2)
    return img


DESIGNS = [
    (aquarium, "1  AQUARIUM HAT",
     "A glass fish bowl worn as a hat,\nwater, weed, an orange fish.\nTeal puffer vest with white dots,\nheavy chain, baggy jeans, white\nchunky sneakers."),
    (big_puffer, "2  THE PUFFER",
     "Puffer jacket three sizes too\nbig, zipped up over the mouth,\npurple with gold dots. Slatted\nshutter shades, bleached spikes,\nskinny legs, huge red sneakers."),
    (grills, "3  GOLD GRIN",
     "Bucket hat with black dots\npulled over the eyes, a wide gold\ngrill. Red tracksuit with white\nstripes and dots. A floppy disk\nhangs on the chain."),
    (fur_ruff, "4  FUR AND RUFF",
     "Shaggy pink fur coat over black,\na white clown ruff, round gold\nsunglasses, a red clown nose,\nthree chains of different\nlengths."),
    (cap_stack, "5  FIVE CAPS",
     "Five baseball caps stacked on\nthe head, brims every way.\nGreen jersey, a big 4, white\ndots, basketball shorts, tall\nstriped socks."),
    (cable_durag, "6  CABLE DURAG",
     "Green durag whose tails are\ncables ending in plugs. Carries\nan old CRT monitor on the\nshoulder like a boombox, a grin\non the screen. Cargo trousers."),
    (rainbow_clown, "7  RAINBOW CLOWN",
     "Rainbow afro under giant\nheadphones, red clown nose.\nDungarees with one strap down\nover a dotted shirt, long red\nclown sneakers."),
    (chandelier, "8  CHANDELIER",
     "A lit chandelier worn as a hat.\nMaroon velvet tracksuit with gold\ndots, sunglasses, one gold\ntooth, a toothpick, a ring on\nevery finger."),
]


def build():
    scale = 5
    cell_w, cell_h = 340, 250
    sheet = Image.new("RGBA", (cell_w * 4 + 20, cell_h * 2 + 50), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)
    title = "HACKERS - rapper fashion, a little wonky. Every outfit keeps the hacker dots. Shown at 5x; in game 16x24 bodies."
    d.text((14, 12), title, font=FONT, fill=CREAM)
    for i, (draw, name, note) in enumerate(DESIGNS):
        x, y = 14 + (i % 4) * cell_w, 40 + (i // 4) * cell_h
        img = draw()
        big = img.resize((W * scale, H * scale), Image.NEAREST)
        d.rectangle((x, y + 18, x + big.width, y + 18 + big.height), fill=(52, 46, 72))
        sheet.alpha_composite(big, (x, y + 18))
        d.rectangle((x, y, x + int(d.textlength(name, font=FONT)) + 8, y + 13), fill=YELLOW, outline=INK)
        d.text((x + 4, y + 1), name, font=FONT, fill=INK)
        d.text((x + big.width + 10, y + 30), note, font=FONT, fill=CREAM)
        # actual game size next to the note
        sheet.alpha_composite(img, (x + big.width + 10, y + 18 + big.height - H))
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
