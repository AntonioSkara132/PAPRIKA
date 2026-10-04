#!/usr/bin/python3
"""Draw the station's small military characters and training props."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "assets/art/space_military_base"
INK = "#1c1730"
SKIN = "#dca778"
LEG = "#413947"
BLUE = "#4e83cf"
GOLD = "#f5c34c"
CREAM = "#f7f1dd"


def rgba(hex_color, alpha=255):
    value = hex_color.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def draw_person(config, player=False):
    image = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((3, 19, 13, 23), fill=(28, 23, 48, 82))

    # Legs and simple boots keep the same feet position as the village sprites.
    draw.rectangle((5, 17, 7, 20), fill=LEG)
    draw.rectangle((9, 17, 11, 20), fill=LEG)
    draw.rectangle((4, 20, 7, 21), fill=config.get("boot", INK))
    draw.rectangle((9, 20, 12, 21), fill=config.get("boot", INK))

    tunic = config["tunic"]
    draw.rectangle((4, 9, 11, 17), fill=tunic, outline=INK)
    draw.rectangle((3, 10, 4, 15), fill=config.get("skin", SKIN))
    draw.rectangle((11, 10, 12, 15), fill=config.get("skin", SKIN))

    # A short collar, belt, and small shoulder piece give each uniform detail
    # without changing the village character proportions.
    draw.rectangle((6, 9, 9, 10), fill=config.get("collar", config.get("trim", "#a3b36b")))
    draw.rectangle((5, 15, 10, 16), fill=config.get("belt", "#765238"))
    draw.rectangle((7, 15, 8, 16), fill=config.get("buckle", GOLD))
    if config.get("shoulder"):
        pad = config["shoulder"]
        draw.rectangle((4, 9, 6, 11), fill=pad, outline=INK)
        draw.point((5, 10), fill=config.get("shoulder_light", "#b9b6a6"))
    if config.get("cape"):
        draw.rectangle((3, 11, 4, 16), fill=config["cape"], outline=INK)
        draw.rectangle((11, 11, 12, 16), fill=config["cape"], outline=INK)

    # Heads use the shared 6-by-7 pixel scale and the same dark outline.
    skin = config.get("skin", SKIN)
    draw.rectangle((5, 3, 10, 9), fill=skin, outline=INK)
    hair = config["hair"]
    draw.rectangle((5, 2, 10, 4), fill=hair)
    hair_style = config.get("hair_style", "short")
    if hair_style == "side":
        draw.rectangle((4, 4, 5, 6), fill=hair)
        draw.rectangle((10, 4, 11, 7), fill=hair)
    elif hair_style == "fringe":
        draw.rectangle((5, 4, 7, 5), fill=hair)
        draw.point((4, 4), fill=hair)
    elif hair_style == "part":
        draw.rectangle((5, 4, 6, 5), fill=hair)
        draw.rectangle((9, 4, 10, 4), fill=config.get("hair_light", hair))
    elif hair_style == "curl":
        draw.point((4, 3), fill=hair)
        draw.point((11, 3), fill=hair)
        draw.rectangle((4, 4, 5, 5), fill=hair)
    elif hair_style == "cap":
        cap = config.get("hat", "#556b42")
        draw.rectangle((4, 2, 11, 4), fill=cap, outline=INK)
        draw.rectangle((5, 4, 10, 4), fill=config.get("hat_band", "#9b7445"))
        draw.rectangle((4, 5, 4, 6), fill=hair)
        draw.rectangle((11, 5, 11, 6), fill=hair)
    elif hair_style == "headband":
        draw.rectangle((5, 3, 10, 3), fill=config.get("hat", GOLD))
        draw.rectangle((4, 4, 4, 5), fill=hair)
        draw.rectangle((11, 4, 11, 5), fill=hair)

    if player:
        # Keep the player's brown hair, blue eye, and gold-and-white sash.
        draw.point((8, 6), fill=BLUE)
        draw.rectangle((10, 9, 11, 14), fill=GOLD)
        draw.rectangle((10, 15, 12, 16), fill=CREAM)
    else:
        # One small face pixel keeps the quiet, low-detail look of the villagers.
        draw.point((8, 6), fill=config.get("eye", "#5b392c"))
        trim = config.get("trim")
        if trim:
            draw.rectangle((5, 11, 5, 13), fill=trim)
            draw.rectangle((10, 11, 10, 13), fill=trim)

    # Hair is drawn before headwear details that are meant to sit above it.
    return image


PEOPLE = {
    "player_uniform.png": {
        "tunic": "#416c48", "hair": "#5b392c", "trim": "#88b260",
        "belt": "#795232", "collar": "#88b260", "hair_style": "part",
    },
    "station_recruit_mara.png": {
        "tunic": "#416f55", "hair": "#754534", "hair_style": "side",
        "trim": "#9bc46a", "belt": "#795232", "skin": "#dca778",
    },
    "station_recruit_tovin.png": {
        "tunic": "#55734a", "hair": "#302536", "hair_style": "fringe",
        "trim": "#d5ad5b", "belt": "#604630", "skin": "#c99269",
    },
    "station_recruit_elia.png": {
        "tunic": "#3e6856", "hair": "#c59b52", "hair_style": "part",
        "trim": "#87b9aa", "belt": "#805d38", "skin": "#e1b78c",
    },
    "station_recruit_belen.png": {
        "tunic": "#657447", "hair": "#5b392c", "hair_style": "curl",
        "trim": "#d6bd75", "belt": "#72503a", "skin": "#dca778",
    },
    "station_recruit_ciro.png": {
        "tunic": "#3c6147", "hair": "#42302a", "hair_style": "side",
        "trim": "#bd8b58", "belt": "#63442f", "skin": "#bd805b",
    },
    "station_recruit_dalia.png": {
        "tunic": "#4b705d", "hair": "#292537", "hair_style": "headband",
        "hat": "#cc9860", "trim": "#9fc28b", "belt": "#75523b",
        "skin": "#e1b78c",
    },
    "station_recruit_kael.png": {
        "tunic": "#526b42", "hair": "#b88747", "hair_style": "fringe",
        "trim": "#d7c478", "belt": "#705038", "skin": "#dca778",
    },
    "station_recruit_nira.png": {
        "tunic": "#3f695d", "hair": "#705044", "hair_style": "cap",
        "hat": "#668158", "hat_band": "#c6ae68", "trim": "#9bc5b3",
        "belt": "#694d38", "skin": "#c99269",
    },
    "station_recruit_ossian.png": {
        "tunic": "#5d7045", "hair": "#9b5438", "hair_style": "curl",
        "trim": "#d2b56a", "belt": "#775237", "skin": "#e1b78c",
    },
    "station_soldier_1.png": {
        "tunic": "#496a47", "hair": "#49362c", "hair_style": "short",
        "trim": "#9bb568", "belt": "#694a35", "shoulder": "#667253",
    },
    "station_soldier_2.png": {
        "tunic": "#526d4c", "hair": "#342a2a", "hair_style": "side",
        "trim": "#c0a25b", "belt": "#725137", "shoulder": "#8b805c",
    },
    "station_soldier_3.png": {
        "tunic": "#3e6147", "hair": "#76503a", "hair_style": "fringe",
        "trim": "#91a675", "belt": "#5f4935", "shoulder": "#596b56",
    },
    "station_soldier_4.png": {
        "tunic": "#5d7146", "hair": "#49362c", "hair_style": "cap",
        "hat": "#536b47", "hat_band": "#a9864f", "trim": "#c5af6a",
        "belt": "#705139", "shoulder": "#817959",
    },
    "station_soldier_5.png": {
        "tunic": "#455e4b", "hair": "#2d2930", "hair_style": "curl",
        "trim": "#8da27d", "belt": "#654936", "shoulder": "#697665",
    },
    "station_soldier_6.png": {
        "tunic": "#65754d", "hair": "#9a5b3e", "hair_style": "headband",
        "hat": "#b48751", "trim": "#d1bc77", "belt": "#76533b",
        "shoulder": "#877753",
    },
    "station_instructor.png": {
        "tunic": "#536b43", "hair": "#b49a78", "hair_style": "cap",
        "hat": "#c4a65d", "hat_band": "#786039", "trim": "#e1c777",
        "belt": "#60472f", "shoulder": "#887a53", "shoulder_light": "#e2cf92",
    },
    "station_cook.png": {
        "tunic": "#526a4a", "hair": "#604333", "hair_style": "cap",
        "hat": "#e8dbb8", "hat_band": "#a35d48", "trim": "#a9bd79",
        "belt": "#76523a", "shoulder": "#8c7052", "shoulder_light": "#d5b47a",
    },
    "station_guard.png": {
        "tunic": "#405d43", "hair": "#33292a", "hair_style": "cap",
        "hat": "#566344", "hat_band": "#a2874e", "trim": "#9caf6f",
        "belt": "#59432f", "shoulder": "#747960", "shoulder_light": "#c7b97a",
    },
}


def practice_marker():
    image = Image.new("RGBA", (12, 9), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 6, 10, 8), fill=(28, 23, 48, 85))
    # A soft toy-like target disc with a bright center, not a functional device.
    draw.rectangle((1, 3, 10, 6), fill=INK)
    draw.rectangle((2, 2, 9, 6), fill="#6f7350")
    draw.rectangle((3, 1, 8, 5), fill="#d94b4b")
    draw.rectangle((4, 2, 7, 4), fill="#f5c34c")
    draw.point((5, 3), fill=CREAM)
    draw.point((6, 3), fill=CREAM)
    draw.rectangle((2, 5, 9, 6), fill="#777c68")
    draw.line((3, 6, 8, 6), fill="#a5aa8b")
    return image


def held_marker_icon():
    image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 2, 6, 6), fill=INK)
    draw.rectangle((2, 1, 5, 5), fill="#d94b4b")
    draw.rectangle((3, 2, 4, 4), fill="#f5c34c")
    draw.point((3, 3), fill=CREAM)
    draw.point((4, 3), fill=CREAM)
    draw.rectangle((2, 5, 5, 6), fill="#777c68")
    return image


def cannonball():
    image = Image.new("RGBA", (6, 6), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 1, 4, 4), fill=INK)
    draw.rectangle((2, 0, 3, 5), fill="#555464")
    draw.rectangle((0, 2, 5, 3), fill="#555464")
    draw.rectangle((2, 1, 3, 4), fill="#343342")
    draw.point((2, 1), fill="#a7a6a1")
    return image


def cannon_start_flag():
    image = Image.new("RGBA", (24, 28), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 25, 21, 27), fill=(28, 23, 48, 72))
    # Use the same framed marker and broad foot as the other station flags.
    draw.rectangle((3, 3, 20, 17), fill=INK)
    draw.rectangle((5, 5, 18, 15), fill="#a67d50")
    draw.rectangle((7, 7, 16, 13), fill="#d6b46f")
    draw.rectangle((9, 9, 14, 11), fill="#d94b4b")
    draw.point((11, 8), fill=CREAM)
    draw.point((12, 8), fill=CREAM)
    draw.point((10, 10), fill=CREAM)
    draw.point((13, 10), fill=CREAM)
    draw.point((11, 12), fill=CREAM)
    draw.point((12, 12), fill=CREAM)
    draw.rectangle((9, 18, 14, 23), fill="#8b5537")
    draw.rectangle((10, 18, 11, 23), fill="#b17842")
    draw.rectangle((2, 18, 21, 20), fill="#b9a16d", outline=INK)
    draw.rectangle((3, 21, 20, 24), fill="#8b5537")
    draw.rectangle((2, 25, 21, 27), fill=INK)
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for filename, config in PEOPLE.items():
        draw_person(config, player=filename == "player_uniform.png").save(OUT / filename)
    practice_marker().save(OUT / "station_practice_mine.png")
    held_marker_icon().save(OUT / "station_mine_icon.png")
    cannonball().save(OUT / "station_cannonball.png")
    cannon_start_flag().save(OUT / "station_cannon_flag.png")
    print(f"Wrote {len(PEOPLE) + 4} PNGs to {OUT}")


if __name__ == "__main__":
    main()
