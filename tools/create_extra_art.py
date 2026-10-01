"""Draw the extra Paprika sprites with the same small palette as the concept art.

Run with /usr/bin/python3 tools/create_extra_art.py. Add --aseprite to also
save editable LibreSprite copies when its `sprite` executable is available.
"""

from pathlib import Path
import argparse
import shutil
import subprocess

from PIL import Image, ImageDraw
from paprika_visual_art import draw_service_plaque, field_sign, forest_warning_sign


PROJECT = Path(__file__).resolve().parents[1]
ART = PROJECT / "assets" / "art"
PLAYER_SOURCE = PROJECT / "art" / "concepts" / "source" / "player.png"
INK = (28, 23, 48)
SHADOW = (28, 23, 48, 95)
DARK = (41, 39, 59)
IVORY = (247, 241, 221)
CREAM = (234, 228, 211)
GOLD = (245, 195, 76)
TEAL = (36, 127, 138)
CYAN = (95, 214, 211)


def canvas(size):
    image = Image.new("RGBA", size)
    return image, ImageDraw.Draw(image)


def clothing_shop():
    image, d = canvas((80, 64))
    d.ellipse((5, 55, 76, 63), fill=SHADOW)
    d.polygon([(9, 27), (13, 19), (20, 14), (49, 14), (56, 18),
               (68, 18), (72, 23), (72, 58), (8, 58)], fill=INK)
    d.polygon([(11, 27), (15, 20), (21, 16), (48, 16), (55, 20),
               (67, 20), (70, 24), (70, 56), (10, 56)], fill=(139, 75, 91))
    d.polygon([(12, 26), (20, 16), (48, 16), (55, 20), (67, 20),
               (70, 24), (69, 28), (55, 24), (18, 24)], fill=(229, 139, 110))
    d.polygon([(12, 26), (20, 17), (25, 17), (19, 24)], fill=(251, 181, 136))
    d.line([(53, 18), (64, 20), (69, 24)], fill=(251, 181, 136))
    d.rectangle((13, 30, 67, 56), fill=(171, 91, 104))
    d.rectangle((14, 44, 39, 56), fill=INK)
    d.rectangle((17, 45, 36, 54), fill=(61, 101, 113))
    d.line((18, 45, 33, 45), fill=CYAN)
    d.line((17, 46, 17, 53), fill=TEAL)
    # A dress in the left display window.
    d.rectangle((26, 46, 27, 48), fill=CREAM)
    d.polygon([(23, 48), (25, 47), (27, 49), (29, 47), (31, 49),
               (30, 50), (29, 50), (31, 53), (23, 53), (25, 50), (24, 50)],
              fill=(248, 205, 150))
    d.line((21, 54, 34, 54), fill=TEAL)
    d.rectangle((44, 43, 63, 57), fill=INK)
    d.rectangle((46, 44, 61, 56), fill=(52, 91, 105))
    d.rectangle((47, 45, 53, 54), fill=(77, 136, 144))
    d.line((48, 46, 52, 46), fill=CYAN)
    d.rectangle((55, 45, 60, 55), fill=(77, 136, 144))
    d.point((56, 51), fill=GOLD)
    d.line((43, 57, 64, 57), fill=(225, 149, 117))
    # Striped canvas awning, below the sign.
    d.rectangle((12, 36, 68, 43), fill=INK)
    d.line((14, 37, 66, 37), fill=CREAM)
    for x in range(14, 66, 8):
        d.polygon([(x, 38), (x + 4, 38), (x + 3, 42), (x - 1, 42)],
                  fill=(251, 211, 163))
    d.line((13, 43, 67, 43), fill=(103, 58, 77))
    draw_service_plaque(d, 80, 23, "CLOTHES")
    return image


def work_office():
    image, d = canvas((80, 64))
    d.ellipse((5, 55, 75, 63), fill=SHADOW)
    d.polygon([(21, 15), (25, 9), (53, 9), (58, 15), (58, 34),
               (65, 34), (72, 40), (72, 58), (8, 58), (8, 42),
               (15, 35), (21, 35)], fill=INK)
    d.polygon([(23, 16), (26, 11), (52, 11), (56, 16), (56, 40),
               (24, 40)], fill=(76, 94, 110))
    d.polygon([(26, 11), (52, 11), (55, 15), (23, 15)], fill=(125, 153, 164))
    d.rectangle((21, 15, 23, 37), fill=(50, 67, 87))
    d.rectangle((54, 15, 56, 37), fill=(48, 68, 83))
    d.line((27, 16, 52, 16), fill=(174, 194, 190))
    for y in (19, 26, 33):
        for x in (27, 37, 47):
            d.rectangle((x, y, x + 6, y + 4), fill=INK)
            d.rectangle((x + 1, y + 1, x + 5, y + 3), fill=(59, 141, 153))
            d.line((x + 1, y + 1, x + 4, y + 1), fill=CYAN)
    d.rectangle((38, 5, 40, 9), fill=INK)
    d.point((39, 4), fill=GOLD)
    d.polygon([(10, 43), (16, 37), (22, 37), (22, 39),
               (59, 39), (59, 36), (64, 36), (70, 41),
               (70, 56), (10, 56)], fill=(86, 112, 123))
    d.polygon([(10, 43), (16, 37), (22, 37), (22, 40), (12, 45)],
              fill=(126, 154, 157))
    d.polygon([(60, 39), (64, 37), (69, 42), (69, 44)],
              fill=(126, 154, 157))
    d.rectangle((13, 51, 29, 54), fill=INK)
    d.rectangle((14, 52, 28, 53), fill=TEAL)
    d.rectangle((51, 51, 66, 54), fill=INK)
    d.rectangle((52, 52, 65, 53), fill=TEAL)
    d.rectangle((34, 50, 48, 57), fill=INK)
    d.rectangle((36, 51, 46, 56), fill=(45, 97, 110))
    d.line((41, 51, 41, 56), fill=INK)
    d.point((43, 54), fill=GOLD)
    d.line((11, 57, 69, 57), fill=(116, 145, 146))
    draw_service_plaque(d, 80, 39, "WORK")
    return image


def bandit():
    image, d = canvas((16, 24))
    d.ellipse((2, 20, 14, 23), fill=SHADOW)
    d.polygon([(5, 4), (7, 2), (10, 2), (13, 5), (14, 10),
               (12, 13), (15, 17), (12, 18), (12, 22),
               (9, 23), (7, 21), (5, 23), (2, 21),
               (4, 15), (2, 13), (4, 9)], fill=INK)
    d.polygon([(6, 4), (8, 3), (10, 3), (12, 6), (11, 9),
               (5, 9), (5, 7)], fill=(113, 49, 58))
    d.line((7, 3, 10, 3), fill=(196, 85, 69))
    d.rectangle((6, 8, 11, 10), fill=(150, 99, 76))
    d.rectangle((6, 8, 11, 9), fill=INK)
    d.point((7, 9), fill=IVORY)
    d.point((10, 9), fill=GOLD)
    d.polygon([(4, 10), (11, 11), (13, 14), (13, 17),
               (10, 17), (9, 20), (4, 19), (3, 16)], fill=(117, 44, 58))
    d.polygon([(4, 11), (7, 12), (7, 18), (4, 17)], fill=(172, 67, 64))
    d.polygon([(11, 9), (13, 10), (15, 9), (14, 13), (12, 12)],
              fill=(191, 74, 63))
    d.rectangle((5, 17, 11, 18), fill=INK)
    d.point((8, 17), fill=GOLD)
    d.rectangle((5, 19, 7, 21), fill=(65, 57, 71))
    d.rectangle((10, 19, 11, 21), fill=(65, 57, 71))
    d.line((4, 22, 7, 22), fill=INK)
    d.line((9, 22, 12, 22), fill=INK)
    d.rectangle((3, 13, 4, 15), fill=(193, 135, 91))
    d.line((1, 12, 2, 16), fill=(171, 182, 179))
    d.line((2, 12, 3, 14), fill=IVORY)
    d.point((2, 17), fill=GOLD)
    return image


def zombie():
    image, d = canvas((16, 24))
    d.ellipse((2, 20, 14, 23), fill=SHADOW)
    d.polygon([(5, 5), (7, 3), (10, 4), (12, 6), (12, 10),
               (14, 11), (15, 14), (13, 15), (12, 13),
               (12, 18), (11, 19), (12, 22), (9, 22),
               (8, 19), (7, 22), (3, 22), (4, 17),
               (3, 15), (1, 16), (0, 13), (2, 11),
               (4, 12), (4, 8)], fill=INK)
    d.polygon([(5, 6), (7, 4), (10, 5), (11, 7),
               (10, 11), (5, 10)], fill=(118, 156, 100))
    d.rectangle((5, 4, 9, 5), fill=(58, 80, 68))
    d.point((6, 8), fill=IVORY)
    d.point((10, 8), fill=GOLD)
    d.line((7, 10, 9, 10), fill=(69, 82, 68))
    d.polygon([(4, 11), (7, 12), (11, 11), (13, 15),
               (11, 18), (7, 17), (4, 19)], fill=(112, 92, 135))
    d.line((5, 12, 10, 12), fill=(152, 123, 160))
    d.rectangle((4, 14, 5, 16), fill=(135, 168, 109))
    d.rectangle((2, 14, 4, 15), fill=(135, 168, 109))
    d.rectangle((12, 13, 14, 14), fill=(135, 168, 109))
    d.line((8, 14, 10, 14), fill=(91, 70, 105))
    d.point((10, 16), fill=(163, 85, 86))
    d.rectangle((6, 18, 7, 21), fill=(121, 145, 99))
    d.rectangle((10, 18, 11, 20), fill=(121, 145, 99))
    d.line((3, 22, 7, 22), fill=(63, 56, 69))
    d.line((10, 21, 12, 21), fill=(63, 56, 69))
    return image


def zombie_bear():
    image, d = canvas((30, 26))
    d.ellipse((2, 21, 28, 25), fill=SHADOW)
    d.polygon([(4, 9), (7, 7), (7, 4), (9, 2), (12, 3),
               (14, 5), (18, 4), (20, 2), (23, 3), (24, 7),
               (27, 10), (28, 18), (26, 21), (23, 21),
               (23, 23), (19, 23), (17, 21), (11, 21),
               (9, 23), (5, 23), (4, 20), (2, 20), (1, 17)], fill=INK)
    d.polygon([(7, 9), (10, 6), (13, 7), (19, 6), (23, 8),
               (26, 12), (26, 18), (23, 19), (21, 21),
               (9, 21), (5, 19), (3, 18), (5, 12)], fill=(74, 95, 77))
    d.rectangle((9, 4, 11, 7), fill=(91, 110, 79))
    d.rectangle((20, 4, 22, 7), fill=(91, 110, 79))
    d.rectangle((10, 4, 11, 5), fill=(139, 109, 98))
    d.rectangle((21, 4, 22, 5), fill=(139, 109, 98))
    d.polygon([(10, 7), (14, 5), (20, 7), (23, 11),
               (20, 16), (12, 15), (9, 11)], fill=(93, 115, 83))
    d.polygon([(5, 12), (8, 10), (9, 17), (7, 20),
               (4, 19)], fill=(60, 76, 69))
    d.polygon([(24, 11), (26, 13), (27, 18), (24, 20),
               (22, 17)], fill=(60, 76, 69))
    d.rectangle((12, 9, 14, 10), fill=INK)
    d.rectangle((19, 9, 21, 10), fill=INK)
    d.point((13, 9), fill=(230, 94, 81))
    d.point((20, 9), fill=GOLD)
    d.polygon([(12, 12), (20, 12), (23, 14), (21, 16),
               (13, 16), (10, 14)], fill=INK)
    d.polygon([(12, 13), (20, 13), (21, 14), (20, 15),
               (13, 15), (11, 14)], fill=(175, 170, 136))
    d.rectangle((16, 12, 18, 13), fill=INK)
    d.line((15, 16, 19, 16), fill=(80, 59, 69))
    d.point((12, 15), fill=IVORY)
    d.point((21, 15), fill=IVORY)
    # Exposed ribs and a torn patch distinguish the undead bear from a wolf.
    d.polygon([(19, 17), (23, 16), (24, 19), (22, 21), (18, 20)],
              fill=(107, 71, 76))
    d.line((20, 18, 22, 18), fill=CREAM)
    d.line((19, 20, 21, 20), fill=CREAM)
    d.line((11, 17, 15, 17), fill=(115, 137, 90))
    d.rectangle((7, 21, 10, 22), fill=(59, 67, 64))
    d.rectangle((20, 21, 23, 22), fill=(59, 67, 64))
    d.point((4, 20), fill=IVORY)
    d.point((6, 21), fill=IVORY)
    d.point((24, 20), fill=IVORY)
    d.point((26, 19), fill=IVORY)
    return image


def hacker():
    image, d = canvas((16, 24))
    d.ellipse((2, 20, 14, 23), fill=SHADOW)
    d.polygon([(5, 4), (6, 2), (11, 2), (13, 5), (13, 10),
               (15, 14), (13, 18), (12, 18), (13, 22),
               (9, 22), (8, 19), (7, 22), (3, 22),
               (4, 18), (2, 17), (3, 12), (4, 10),
               (4, 6)], fill=INK)
    d.polygon([(6, 4), (7, 3), (11, 4), (12, 6),
               (12, 10), (5, 10), (5, 6)], fill=(64, 60, 105))
    d.line((6, 4, 10, 4), fill=(104, 104, 151))
    d.rectangle((6, 7, 11, 9), fill=(57, 83, 98))
    d.rectangle((7, 8, 10, 8), fill=CYAN)
    d.point((12, 9), fill=GOLD)
    d.polygon([(5, 11), (11, 11), (13, 15), (12, 20),
               (4, 20), (3, 16)], fill=(66, 63, 105))
    d.line((5, 12, 6, 12), fill=(110, 109, 147))
    d.rectangle((3, 13, 4, 17), fill=(138, 103, 102))
    d.rectangle((12, 13, 13, 17), fill=(138, 103, 102))
    # A laptop with a luminous screen makes the silhouette different at 16px.
    d.rectangle((5, 13, 12, 17), fill=INK)
    d.rectangle((6, 14, 11, 16), fill=TEAL)
    d.line((7, 14, 10, 14), fill=CYAN)
    d.point((9, 15), fill=IVORY)
    d.line((4, 18, 13, 18), fill=(110, 109, 147))
    d.rectangle((5, 20, 7, 21), fill=(51, 52, 77))
    d.rectangle((10, 20, 12, 21), fill=(51, 52, 77))
    return image


def forest_bush():
    image, d = canvas((24, 16))
    d.ellipse((1, 12, 23, 15), fill=SHADOW)
    d.polygon([(1, 12), (3, 8), (5, 8), (6, 5), (9, 4),
               (11, 6), (13, 3), (17, 3), (19, 7),
               (21, 7), (23, 11), (21, 14), (3, 14)], fill=INK)
    d.polygon([(3, 11), (5, 9), (8, 6), (11, 8),
               (14, 5), (17, 5), (21, 10), (20, 12),
               (4, 12)], fill=(45, 96, 56))
    d.polygon([(5, 9), (8, 6), (10, 9), (13, 8), (15, 5),
               (18, 7), (19, 10), (15, 9), (11, 11)], fill=(67, 134, 74))
    d.rectangle((7, 7, 8, 8), fill=(99, 168, 82))
    d.rectangle((15, 6, 16, 7), fill=(99, 168, 82))
    d.point((12, 10), fill=(239, 135, 63))
    return image


def field_rock():
    image, d = canvas((20, 12))
    d.ellipse((1, 9, 19, 11), fill=SHADOW)
    d.polygon([(2, 9), (4, 5), (7, 5), (10, 2), (15, 3),
               (18, 7), (18, 10), (3, 10)], fill=INK)
    d.polygon([(4, 8), (6, 6), (8, 6), (11, 3),
               (14, 4), (17, 8), (16, 9), (4, 9)], fill=(114, 120, 135))
    d.polygon([(8, 6), (11, 3), (14, 4), (12, 6)], fill=(169, 176, 178))
    d.line((6, 8, 13, 8), fill=(65, 69, 84))
    return image


def player_outfit(color, shade, trim):
    image = Image.open(PLAYER_SOURCE).convert("RGBA")
    old_shirt = (78, 131, 207, 255)
    for y in range(10, 17):
        for x in range(image.width):
            if image.getpixel((x, y)) == old_shirt:
                image.putpixel((x, y), (*color, 255))
    d = ImageDraw.Draw(image)
    d.line((6, 10, 9, 10), fill=trim)
    d.point((8, 11), fill=trim)
    d.line((8, 12, 8, 15), fill=shade)
    d.point((7, 13), fill=IVORY)
    d.line((5, 16, 10, 16), fill=shade)
    d.point((8, 16), fill=GOLD)
    return image


def player_armor_overlay():
    image, d = canvas((16, 24))
    steel = (116, 127, 137)
    shine = (216, 226, 223)
    d.rectangle((5, 2, 10, 4), fill=INK)
    d.rectangle((6, 2, 9, 3), fill=steel)
    d.line((6, 2, 8, 2), fill=shine)
    d.line((5, 4, 10, 4), fill=shine)
    d.rectangle((5, 5, 5, 7), fill=steel)
    d.rectangle((10, 5, 10, 7), fill=steel)
    d.rectangle((4, 9, 6, 12), fill=INK)
    d.rectangle((5, 10, 6, 11), fill=steel)
    d.point((5, 10), fill=shine)
    d.rectangle((9, 9, 11, 12), fill=INK)
    d.rectangle((9, 10, 10, 11), fill=steel)
    d.point((10, 10), fill=shine)
    d.rectangle((5, 11, 10, 15), fill=INK)
    d.rectangle((6, 11, 9, 14), fill=steel)
    d.line((6, 11, 9, 11), fill=shine)
    d.line((8, 12, 8, 14), fill=INK)
    d.point((7, 13), fill=GOLD)
    d.line((5, 16, 10, 16), fill=steel)
    d.point((8, 16), fill=GOLD)
    d.rectangle((5, 18, 7, 20), fill=(84, 95, 108))
    d.rectangle((9, 18, 11, 20), fill=(84, 95, 108))
    d.line((5, 18, 6, 18), fill=shine)
    d.line((9, 18, 10, 18), fill=shine)
    return image


def player_armor():
    return Image.alpha_composite(player_blue(), player_armor_overlay())


def player_red():
    return player_outfit((189, 76, 83), (128, 44, 65), (250, 172, 123))


def player_blue():
    return player_outfit((78, 131, 207), (47, 92, 156), (219, 226, 218))


def player_green():
    return player_outfit((77, 152, 102), (42, 103, 73), (203, 220, 134))


SPRITES = {
    "clothing_shop": clothing_shop,
    "work_office": work_office,
    "common_field_sign": lambda: field_sign("COMMON"),
    "private_garden_sign": lambda: field_sign("PRIVATE"),
    "forest_warning_sign": forest_warning_sign,
    "bandit": bandit,
    "zombie": zombie,
    "zombie_bear": zombie_bear,
    "hacker": hacker,
    "forest_bush": forest_bush,
    "field_rock": field_rock,
    "player_red": player_red,
    "player_blue": player_blue,
    "player_green": player_green,
    "player_armor_overlay": player_armor_overlay,
    "player_armor": player_armor,
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aseprite", action="store_true", help="also write LibreSprite files")
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    sprite = shutil.which("sprite") if args.aseprite else None
    if args.aseprite and sprite is None:
        parser.error("LibreSprite's `sprite` executable is required for --aseprite")
    for name, make_image in SPRITES.items():
        image = make_image()
        png = ART / f"{name}.png"
        image.save(png)
        if sprite is not None:
            subprocess.run([sprite, "--batch", str(png), "--save-as",
                            str(ART / f"{name}.aseprite")], check=True,
                           stdout=subprocess.DEVNULL)
        print(f"{png.name}: {image.width}x{image.height}")


if __name__ == "__main__":
    main()
