#!/usr/bin/python3
"""Concept sheet: the Purple Parrots, Julius's gang at Smokva, and Donat.

The three proposed members (Puffa, Luster and Ruff from create_hacker_designs.py) each
wear a purple parrot feather as the gang's mark. Donat stands beside them for comparison.

Writes art/concepts/purple_parrots.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw

import create_hacker_designs as hackers
import create_smokva_concept as smokva
from create_otpornik_ship_art import INK, CREAM, YELLOW, FONT

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concepts/purple_parrots.png"
PURPLE = (124, 58, 186)
LIGHT = (190, 140, 236)
DARK = (78, 34, 122)
QUILL = (246, 236, 200)


def feather(img, x, y, lean=1):
    """A purple parrot feather, 3 wide and 7 tall, its quill at (x, y), leaning `lean`."""
    d = ImageDraw.Draw(img)
    for i in range(6):
        cx = x + lean * (i // 3)
        top = y - 1 - i
        d.point((cx, top), fill=PURPLE if i < 4 else LIGHT)
        d.point((cx - 1, top), fill=DARK if i < 5 else PURPLE)
        if 1 <= i <= 4:
            d.point((cx + 1, top), fill=LIGHT)
    d.point((x, y), fill=QUILL)
    return img


def puffa():
    """In the bleached spikes, leaning back."""
    return feather(hackers.big_puffer(), 15, 13, 1)


def luster():
    """Tucked into the chandelier's rim."""
    return feather(hackers.chandelier(), 16, 10, 1)


def ruff():
    """Pinned to the fur coat at the collar, under the ruff."""
    return feather(hackers.fur_ruff(), 15, 24, 1)


def donat():
    """Donat on the same 24x36 canvas as the hackers."""
    img = Image.new("RGBA", (hackers.W, hackers.H))
    img.alpha_composite(smokva.donat(), (hackers.OX, hackers.OY))
    return img


FIGURES = [
    (puffa, "PUFFA", "feather in the spikes"),
    (luster, "LUSTER (leader)", "feather in the chandelier"),
    (ruff, "RUFF", "feather on the collar"),
    (donat, "DONAT", "rank 12, not a Parrot"),
]


def build():
    scale = 6
    cell = hackers.W * scale + 40
    sheet = Image.new("RGBA", (cell * len(FIGURES) + 20, hackers.H * scale + 90), (40, 34, 58, 255))
    d = ImageDraw.Draw(sheet)
    d.text((14, 10), "THE PURPLE PARROTS - Julius's gang at Smokva. The purple feather is the gang mark.", font=FONT, fill=CREAM)
    for i, (draw, name, note) in enumerate(FIGURES):
        x, y = 14 + i * cell, 34
        img = draw()
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        d.rectangle((x, y, x + big.width, y + big.height), fill=(52, 46, 72))
        sheet.alpha_composite(big, (x, y))
        d.rectangle((x, y + big.height + 6, x + int(d.textlength(name, font=FONT)) + 8, y + big.height + 19), fill=YELLOW, outline=INK)
        d.text((x + 4, y + big.height + 7), name, font=FONT, fill=INK)
        d.text((x, y + big.height + 24), note, font=FONT, fill=CREAM)
        sheet.alpha_composite(img, (x + big.width + 6, y + big.height - img.height))
    return sheet


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
