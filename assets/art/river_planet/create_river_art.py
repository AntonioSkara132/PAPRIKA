"""Draw reusable River Planet sprites and their labeled contact sheet.

Run with /usr/bin/python3 create_river_art.py --aseprite to make PNGs and
editable LibreSprite sources. Nothing in this set is placed in the live map.
"""

from pathlib import Path
import argparse
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
INK = (28, 23, 48)
SHADOW = (28, 23, 48, 95)
DARK = (41, 39, 59)
IVORY = (247, 241, 221)
STUCCO = (234, 217, 172)
STUCCO_SHADE = (216, 201, 158)
SAND = (214, 180, 111)
STONE = (185, 182, 166)
STONE_DARK = (101, 117, 130)
WOOD = (139, 85, 55)
WOOD_DARK = (84, 51, 40)
TERRA = (168, 77, 63)
TERRA_LIGHT = (213, 107, 79)
BLUE = (78, 131, 207)
TEAL = (36, 127, 138)
WATER = (54, 143, 164)
WATER_DARK = (31, 96, 127)
CYAN = (95, 214, 211)
FOAM = (130, 203, 208)
GOLD = (245, 195, 76)
SKIN = (220, 167, 120)
IRON = (116, 127, 137)
IRON_LIGHT = (216, 226, 223)
GREEN = (67, 134, 74)
GREEN_DARK = (45, 96, 56)
GREEN_LIGHT = (99, 168, 82)
FONT = ImageFont.load_default()


def canvas(size):
    image = Image.new("RGBA", size)
    return image, ImageDraw.Draw(image)


def ground(draw, width, y):
    draw.ellipse((2, y - 4, width - 3, y + 2), fill=SHADOW)


def plaque(draw, text, cx, y):
    width = round(FONT.getlength(text)) + 6
    x = cx - width // 2
    draw.rectangle((x, y, x + width, y + 12), fill=INK, outline=IVORY)
    draw.text((x + 3, y), text, font=FONT, fill=IVORY)


def window(draw, x, y, width=9, height=10, lit=False):
    draw.rectangle((x, y, x + width, y + height), fill=INK)
    draw.rectangle((x + 2, y + 2, x + width - 2, y + height - 2),
                   fill=GOLD if lit else WATER)
    draw.line((x + 2, y + 2, x + width - 2, y + 2),
              fill=IVORY if lit else CYAN)
    draw.line((x + width // 2, y + 2, x + width // 2, y + height - 2),
              fill=WOOD_DARK)


def door(draw, x, y, width=12, height=19):
    draw.rectangle((x, y, x + width, y + height), fill=INK)
    draw.rectangle((x + 2, y + 2, x + width - 2, y + height - 1),
                   fill=WOOD_DARK)
    draw.line((x + 3, y + 3, x + width - 3, y + 3), fill=WOOD)
    draw.point((x + width - 3, y + height // 2), fill=GOLD)


def river_town_hall():
    image, d = canvas((112, 96))
    ground(d, 112, 91)
    d.rectangle((43, 17, 70, 57), fill=INK)
    d.rectangle((45, 19, 68, 54), fill=STUCCO)
    d.polygon([(39, 20), (48, 8), (65, 8), (75, 20),
               (73, 23), (41, 23)], fill=INK)
    d.polygon([(42, 19), (49, 10), (64, 10), (72, 19)], fill=TERRA)
    d.line((47, 11, 63, 11), fill=TERRA_LIGHT)
    d.rectangle((52, 23, 62, 33), fill=INK)
    d.rectangle((54, 25, 60, 31), fill=WATER)
    d.point((57, 28), fill=GOLD)
    d.line((57, 25, 57, 28), fill=IVORY)
    d.polygon([(11, 40), (22, 33), (90, 33), (102, 40),
               (102, 87), (10, 87)], fill=INK)
    d.rectangle((13, 43, 99, 84), fill=STUCCO)
    d.rectangle((15, 66, 97, 84), fill=STUCCO_SHADE)
    d.polygon([(8, 43), (22, 32), (91, 32), (104, 43),
               (101, 47), (11, 47)], fill=INK)
    d.polygon([(12, 42), (23, 34), (90, 34), (100, 42),
               (97, 44), (15, 44)], fill=TERRA)
    d.line((23, 34, 89, 34), fill=TERRA_LIGHT)
    for x in (18, 34, 69, 85):
        window(d, x, 49, width=9, height=11)
        d.line((x - 1, 61, x + 10, 61), fill=WOOD)
    d.line((14, 65, 98, 65), fill=WOOD)
    d.rectangle((17, 69, 28, 82), fill=INK)
    d.rectangle((19, 71, 26, 80), fill=WATER)
    d.line((19, 71, 25, 71), fill=CYAN)
    d.rectangle((84, 69, 95, 82), fill=INK)
    d.rectangle((86, 71, 93, 80), fill=WATER)
    d.line((86, 71, 92, 71), fill=CYAN)
    d.polygon([(44, 84), (44, 73), (47, 69), (64, 69),
               (68, 73), (68, 85)], fill=INK)
    d.polygon([(47, 83), (47, 73), (49, 71), (63, 71),
               (65, 73), (65, 83)], fill=WOOD_DARK)
    d.line((56, 72, 56, 83), fill=INK)
    d.point((59, 77), fill=GOLD)
    d.rectangle((40, 86, 72, 88), fill=STONE_DARK)
    d.line((46, 86, 66, 86), fill=STONE)
    plaque(d, "TOWN HALL", 56, 56)
    d.rectangle((13, 84, 99, 87), fill=INK)
    d.line((15, 85, 97, 85), fill=STONE)
    return image


def river_market():
    image, d = canvas((96, 72))
    ground(d, 96, 68)
    d.polygon([(9, 31), (17, 20), (79, 20), (88, 31),
               (88, 66), (8, 66)], fill=INK)
    d.rectangle((11, 34, 85, 64), fill=STUCCO)
    d.polygon([(8, 31), (18, 19), (78, 19), (89, 31),
               (86, 35), (11, 35)], fill=INK)
    d.polygon([(12, 30), (19, 21), (77, 21), (85, 30),
               (83, 32), (14, 32)], fill=TERRA)
    d.line((20, 22, 75, 22), fill=TERRA_LIGHT)
    d.rectangle((12, 41, 84, 49), fill=INK)
    for x in range(14, 84, 10):
        d.rectangle((x, 42, x + 4, 48), fill=IVORY)
        d.rectangle((x + 5, 42, x + 9, 48), fill=TERRA_LIGHT)
    d.line((13, 41, 83, 41), fill=WOOD_DARK)
    d.rectangle((15, 50, 35, 63), fill=INK)
    d.rectangle((17, 52, 33, 61), fill=(112, 157, 155))
    d.ellipse((19, 55, 24, 59), fill=GREEN_DARK)
    d.ellipse((26, 53, 31, 58), fill=GREEN)
    d.rectangle((62, 50, 82, 63), fill=INK)
    d.rectangle((64, 52, 80, 61), fill=(112, 157, 155))
    d.rectangle((66, 57, 78, 59), fill=WOOD)
    d.point((68, 55), fill=GOLD)
    d.point((72, 54), fill=GOLD)
    d.point((76, 55), fill=GOLD)
    door(d, 41, 49, width=14, height=16)
    plaque(d, "MARKET", 48, 29)
    d.line((10, 65, 86, 65), fill=STONE_DARK)
    return image


def river_townhouse():
    image, d = canvas((64, 88))
    ground(d, 64, 83)
    d.rectangle((13, 21, 52, 80), fill=INK)
    d.rectangle((15, 23, 50, 78), fill=STUCCO)
    d.rectangle((16, 58, 49, 78), fill=STUCCO_SHADE)
    d.polygon([(8, 25), (18, 10), (48, 10), (57, 25),
               (54, 28), (10, 28)], fill=INK)
    d.polygon([(12, 24), (20, 12), (46, 12), (53, 24),
               (51, 26), (14, 26)], fill=TERRA)
    d.line((19, 12, 45, 12), fill=TERRA_LIGHT)
    d.rectangle((17, 30, 26, 39), fill=INK)
    d.rectangle((19, 32, 24, 37), fill=WATER)
    d.rectangle((38, 30, 47, 39), fill=INK)
    d.rectangle((40, 32, 45, 37), fill=GOLD)
    d.line((16, 42, 49, 42), fill=WOOD)
    window(d, 18, 47, width=9, height=10)
    window(d, 37, 47, width=9, height=10)
    d.rectangle((16, 60, 48, 62), fill=INK)
    d.line((18, 60, 46, 60), fill=IRON_LIGHT)
    for x in (19, 25, 31, 37, 43):
        d.rectangle((x, 61, x + 1, 64), fill=INK)
    door(d, 25, 65, width=13, height=15)
    d.rectangle((13, 79, 52, 80), fill=INK)
    d.line((46, 47, 52, 53), fill=GREEN_DARK)
    d.point((51, 50), fill=GREEN_LIGHT)
    d.point((49, 54), fill=GREEN_LIGHT)
    return image


def river_library():
    image, d = canvas((96, 88))
    ground(d, 96, 83)
    d.polygon([(10, 28), (20, 19), (76, 19), (86, 28),
               (86, 81), (9, 81)], fill=INK)
    d.rectangle((12, 31, 83, 78), fill=STUCCO)
    d.rectangle((14, 60, 81, 78), fill=STUCCO_SHADE)
    d.polygon([(8, 29), (19, 17), (77, 17), (88, 29),
               (85, 33), (11, 33)], fill=INK)
    d.polygon([(12, 28), (20, 19), (76, 19), (84, 28),
               (82, 31), (14, 31)], fill=TERRA)
    d.line((20, 19, 76, 19), fill=TERRA_LIGHT)
    d.rectangle((15, 34, 18, 77), fill=WOOD)
    d.rectangle((78, 34, 81, 77), fill=WOOD)
    for x in (22, 66):
        d.polygon([(x, 51), (x, 39), (x + 3, 36),
                   (x + 11, 36), (x + 14, 39), (x + 14, 51)], fill=INK)
        d.rectangle((x + 2, 40, x + 12, 49), fill=WATER_DARK)
        d.line((x + 3, 41, x + 11, 41), fill=CYAN)
        d.rectangle((x + 4, 45, x + 5, 48), fill=STUCCO)
        d.rectangle((x + 7, 43, x + 8, 48), fill=GOLD)
        d.rectangle((x + 10, 44, x + 11, 48), fill=TERRA_LIGHT)
    d.ellipse((42, 35, 54, 47), fill=INK)
    d.ellipse((44, 37, 52, 45), fill=STUCCO)
    d.line((46, 39, 46, 44), fill=WOOD)
    d.line((48, 39, 48, 44), fill=WOOD)
    d.line((50, 39, 50, 44), fill=WOOD)
    d.line((14, 55, 82, 55), fill=WOOD)
    d.rectangle((18, 66, 34, 77), fill=INK)
    d.rectangle((20, 68, 32, 75), fill=WATER_DARK)
    d.rectangle((21, 70, 24, 74), fill=TERRA_LIGHT)
    d.rectangle((25, 69, 27, 74), fill=GOLD)
    d.rectangle((28, 71, 31, 74), fill=STUCCO)
    d.rectangle((62, 66, 78, 77), fill=INK)
    d.rectangle((64, 68, 76, 75), fill=WATER_DARK)
    d.polygon([(66, 70), (69, 69), (72, 71), (74, 70),
               (73, 74), (67, 74)], fill=STUCCO)
    d.line((69, 70, 72, 72), fill=TERRA)
    d.polygon([(39, 80), (39, 69), (42, 65), (54, 65),
               (57, 69), (57, 80)], fill=INK)
    d.polygon([(42, 78), (42, 69), (44, 67), (52, 67),
               (54, 69), (54, 78)], fill=WOOD_DARK)
    d.line((48, 68, 48, 78), fill=INK)
    d.point((51, 73), fill=GOLD)
    plaque(d, "LIBRARY", 48, 54)
    d.rectangle((10, 79, 85, 81), fill=INK)
    d.line((14, 80, 82, 80), fill=STONE)
    return image


def town_center_fountain():
    image, d = canvas((64, 48))
    ground(d, 64, 44)
    d.polygon([(5, 32), (14, 26), (49, 26), (59, 32),
               (55, 42), (10, 42)], fill=INK)
    d.polygon([(9, 32), (16, 28), (48, 28), (55, 32),
               (52, 39), (12, 39)], fill=STONE)
    d.ellipse((11, 28, 53, 37), fill=WATER_DARK)
    d.ellipse((14, 29, 50, 34), fill=WATER)
    d.line((18, 30, 43, 30), fill=CYAN)
    d.rectangle((29, 13, 35, 30), fill=INK)
    d.rectangle((30, 15, 34, 28), fill=STONE)
    d.line((30, 16, 33, 16), fill=IVORY)
    d.polygon([(22, 14), (24, 10), (40, 10), (42, 14),
               (38, 18), (26, 18)], fill=INK)
    d.polygon([(25, 12), (39, 12), (38, 15), (26, 15)], fill=STONE)
    d.polygon([(29, 9), (32, 4), (35, 9), (35, 12),
               (29, 12)], fill=INK)
    d.rectangle((31, 8, 33, 11), fill=GOLD)
    d.line((27, 17, 24, 26), fill=FOAM)
    d.line((37, 17, 40, 26), fill=FOAM)
    d.point((22, 27), fill=IVORY)
    d.point((42, 27), fill=IVORY)
    d.line((10, 39, 53, 39), fill=IRON_LIGHT)
    d.line((15, 41, 49, 41), fill=STONE_DARK)
    return image


def military_hq():
    image, d = canvas((96, 96))
    ground(d, 96, 91)
    d.polygon([(9, 32), (19, 21), (77, 21), (87, 32),
               (87, 88), (8, 88)], fill=INK)
    d.rectangle((11, 34, 85, 85), fill=(88, 135, 91))
    d.rectangle((13, 56, 83, 85), fill=(66, 112, 75))
    d.polygon([(7, 33), (20, 19), (76, 19), (89, 33),
               (86, 36), (10, 36)], fill=INK)
    d.polygon([(11, 32), (21, 21), (75, 21), (85, 32),
               (82, 34), (14, 34)], fill=GREEN_DARK)
    d.line((21, 22, 73, 22), fill=GREEN_LIGHT)
    d.polygon([(37, 20), (43, 10), (53, 10), (59, 20)], fill=INK)
    d.polygon([(40, 19), (44, 12), (52, 12), (56, 19)], fill=GREEN)
    d.rectangle((14, 36, 17, 83), fill=STUCCO)
    d.rectangle((79, 36, 82, 83), fill=STUCCO)
    d.line((15, 53, 81, 53), fill=INK)
    d.line((18, 55, 78, 55), fill=STUCCO)
    for x in (22, 38, 56, 72):
        window(d, x, 39, width=9, height=10)
    d.polygon([(43, 14), (48, 12), (53, 14), (52, 19),
               (48, 22), (44, 19)], fill=INK)
    d.polygon([(45, 15), (48, 14), (51, 15), (50, 18),
               (48, 20), (46, 18)], fill=GOLD)
    # Bow and sword are painted on separate ground-floor wall panels.
    d.rectangle((19, 68, 35, 84), fill=GREEN_DARK, outline=STUCCO)
    d.arc((23, 70, 31, 81), 80, 280, fill=GOLD, width=2)
    d.line((25, 71, 25, 80), fill=IVORY)
    d.line((22, 75, 30, 75), fill=IRON_LIGHT)
    d.rectangle((60, 68, 76, 84), fill=GREEN_DARK, outline=STUCCO)
    d.polygon([(67, 69), (70, 69), (70, 77), (68, 79),
               (66, 77)], fill=IRON_LIGHT)
    d.line((64, 78, 72, 78), fill=GOLD)
    d.line((68, 79, 68, 82), fill=WOOD_DARK)
    d.polygon([(38, 86), (38, 69), (42, 65), (53, 65),
               (57, 69), (57, 86)], fill=INK)
    d.polygon([(41, 84), (41, 70), (44, 68), (51, 68),
               (54, 70), (54, 84)], fill=WOOD_DARK)
    d.line((47, 69, 47, 84), fill=INK)
    d.point((50, 78), fill=GOLD)
    plaque(d, "MILITARY HQ", 48, 55)
    d.rectangle((10, 86, 86, 88), fill=INK)
    d.line((16, 87, 80, 87), fill=STUCCO)
    return image


def arrow_target():
    image, d = canvas((32, 32))
    ground(d, 32, 28)
    d.rectangle((14, 19, 17, 28), fill=INK)
    d.rectangle((15, 20, 16, 27), fill=WOOD)
    d.rectangle((8, 28, 24, 29), fill=INK)
    d.ellipse((5, 3, 27, 24), fill=INK)
    d.ellipse((7, 5, 25, 22), fill=STUCCO)
    d.ellipse((10, 8, 22, 19), fill=TERRA)
    d.ellipse((13, 11, 19, 16), fill=IVORY)
    d.rectangle((15, 12, 17, 14), fill=GOLD)
    d.line((17, 13, 29, 8), fill=WOOD_DARK)
    d.point((29, 8), fill=IRON_LIGHT)
    d.line((26, 8, 29, 7), fill=GOLD)
    d.line((27, 10, 30, 10), fill=GOLD)
    return image


def stone_bridge():
    image, d = canvas((96, 48))
    d.polygon([(3, 29), (11, 26), (85, 26), (93, 29),
               (93, 44), (3, 44)], fill=WATER_DARK)
    d.polygon([(4, 33), (22, 29), (70, 30), (92, 34),
               (92, 41), (4, 41)], fill=WATER)
    for x, y in ((12, 37), (28, 41), (47, 37), (61, 42), (77, 36)):
        d.line((x, y, x + 10, y), fill=CYAN)
    d.polygon([(7, 21), (15, 14), (79, 14), (89, 21),
               (88, 36), (80, 38), (17, 38), (8, 36)], fill=INK)
    d.polygon([(10, 22), (16, 17), (79, 17), (86, 23),
               (85, 34), (13, 34)], fill=STONE)
    for x in (27, 59):
        d.polygon([(x - 10, 35), (x - 10, 29), (x - 7, 25),
                   (x - 3, 23), (x + 3, 23), (x + 7, 25),
                   (x + 10, 29), (x + 10, 35)], fill=INK)
        d.polygon([(x - 8, 35), (x - 8, 29), (x - 5, 26),
                   (x - 2, 25), (x + 2, 25), (x + 5, 27),
                   (x + 8, 30), (x + 8, 35)], fill=WATER_DARK)
        d.line((x - 4, 31, x + 3, 31), fill=CYAN)
    d.rectangle((9, 14, 87, 19), fill=INK)
    d.rectangle((11, 12, 85, 17), fill=STONE)
    d.line((12, 12, 84, 12), fill=IVORY)
    for x in range(19, 85, 12):
        d.line((x, 13, x, 17), fill=STONE_DARK)
    d.rectangle((7, 20, 88, 21), fill=INK)
    d.line((10, 22, 85, 22), fill=STUCCO)
    d.line((11, 36, 85, 36), fill=STONE_DARK)
    return image


def lake_patch():
    image, d = canvas((96, 64))
    d.polygon([(2, 29), (10, 17), (21, 12), (35, 9),
               (56, 10), (70, 14), (84, 20), (93, 32),
               (88, 45), (77, 53), (61, 58), (37, 57),
               (20, 52), (7, 44)], fill=INK)
    d.polygon([(5, 30), (12, 19), (22, 14), (36, 11),
               (56, 12), (69, 16), (82, 22), (90, 32),
               (85, 44), (76, 51), (60, 55), (37, 54),
               (21, 50), (9, 43)], fill=SAND)
    d.polygon([(11, 30), (17, 22), (26, 17), (38, 15),
               (57, 16), (72, 21), (84, 29), (84, 38),
               (73, 48), (57, 51), (35, 49), (20, 44),
               (13, 39)], fill=WATER_DARK)
    d.polygon([(16, 29), (27, 20), (44, 18), (60, 21),
               (77, 29), (79, 37), (67, 45), (45, 48),
               (24, 42), (16, 37)], fill=WATER)
    for x, y, length in ((23, 30, 12), (46, 25, 10), (59, 37, 13),
                         (35, 42, 8), (70, 31, 6)):
        d.line((x, y, x + length, y), fill=CYAN)
    d.point((47, 36), fill=GOLD)
    d.line((43, 38, 48, 38), fill=FOAM)
    d.point((19, 22), fill=STONE)
    d.point((81, 44), fill=STONE)
    return image


def fishing_pond():
    image, d = canvas((64, 48))
    d.polygon([(2, 24), (9, 15), (22, 11), (40, 12),
               (55, 17), (62, 26), (56, 38), (39, 43),
               (18, 40), (5, 34)], fill=INK)
    d.polygon([(5, 24), (11, 17), (22, 13), (40, 14),
               (53, 19), (59, 26), (54, 36), (39, 40),
               (19, 38), (8, 33)], fill=SAND)
    d.polygon([(10, 25), (17, 18), (25, 17), (41, 18),
               (52, 23), (54, 28), (49, 34), (37, 37),
               (20, 35), (12, 31)], fill=WATER_DARK)
    d.polygon([(15, 25), (24, 20), (41, 21), (49, 25),
               (49, 31), (37, 34), (22, 31)], fill=WATER)
    d.line((21, 26, 32, 26), fill=CYAN)
    d.line((37, 31, 46, 31), fill=CYAN)
    d.polygon([(31, 29), (36, 28), (38, 30), (36, 32)], fill=IRON_LIGHT)
    d.point((36, 29), fill=INK)
    for x, height in ((6, 10), (9, 15), (55, 10), (58, 13)):
        d.line((x, 22, x, 22 - height), fill=GREEN_DARK)
        d.point((x, 22 - height), fill=GOLD)
    return image


def fishing_boat():
    image, d = canvas((48, 24))
    ground(d, 48, 21)
    d.polygon([(2, 12), (10, 16), (37, 16), (45, 11),
               (43, 19), (36, 22), (12, 22), (4, 18)], fill=INK)
    d.polygon([(5, 15), (12, 18), (36, 18), (42, 14),
               (40, 18), (34, 20), (13, 20), (7, 18)], fill=WOOD)
    d.line((9, 16, 38, 16), fill=STUCCO)
    d.rectangle((19, 12, 29, 16), fill=INK)
    d.rectangle((21, 13, 27, 15), fill=STONE)
    d.line((28, 13, 38, 3), fill=WOOD_DARK)
    d.line((37, 3, 40, 3), fill=IRON_LIGHT)
    d.line((40, 4, 41, 14), fill=IRON_LIGHT)
    d.point((41, 15), fill=TERRA_LIGHT)
    d.polygon([(13, 11), (18, 9), (21, 12), (20, 15),
               (14, 15)], fill=STUCCO)
    d.line((15, 11, 18, 11), fill=CYAN)
    return image


def reed_cluster():
    image, d = canvas((24, 16))
    ground(d, 24, 13)
    d.polygon([(2, 13), (7, 11), (12, 12), (17, 10),
               (22, 12), (21, 14), (3, 14)], fill=GREEN_DARK)
    for x, top in ((5, 5), (8, 2), (11, 6), (15, 3), (19, 5)):
        d.line((x, 12, x, top), fill=GREEN)
        d.point((x, top), fill=WOOD)
    d.line((4, 11, 2, 7), fill=GREEN_LIGHT)
    d.line((9, 11, 11, 4), fill=GREEN_LIGHT)
    d.line((17, 11, 20, 7), fill=GREEN_LIGHT)
    d.point((8, 2), fill=GOLD)
    d.point((15, 3), fill=GOLD)
    return image


def terraced_field():
    image, d = canvas((80, 48))
    ground(d, 80, 44)
    d.polygon([(4, 7), (73, 7), (77, 13), (77, 41),
               (7, 41), (3, 35)], fill=INK)
    d.polygon([(6, 10), (72, 10), (74, 15), (74, 38),
               (9, 38), (6, 34)], fill=WOOD)
    d.line((9, 12, 71, 12), fill=SAND)
    for row_y in (17, 25, 33):
        d.rectangle((9, row_y - 2, 72, row_y + 3), fill=WOOD_DARK)
        d.line((11, row_y + 3, 71, row_y + 3), fill=SAND)
        for x in range(14, 71, 8):
            d.line((x, row_y, x - 2, row_y - 3), fill=GREEN)
            d.line((x, row_y, x + 2, row_y - 4), fill=GREEN_LIGHT)
            d.point((x, row_y - 2), fill=GOLD if row_y == 25 else GREEN)
    d.line((8, 39, 75, 39), fill=STUCCO_SHADE)
    return image


def olive_tree():
    image, d = canvas((32, 48))
    ground(d, 32, 43)
    d.rectangle((13, 27, 18, 41), fill=INK)
    d.rectangle((14, 27, 17, 40), fill=WOOD_DARK)
    d.polygon([(2, 22), (6, 14), (11, 14), (14, 7),
               (21, 7), (24, 13), (29, 16), (30, 26),
               (24, 32), (8, 31), (2, 27)], fill=INK)
    d.polygon([(4, 22), (8, 15), (14, 12), (17, 8),
               (21, 10), (26, 17), (28, 25), (23, 30),
               (9, 29)], fill=GREEN_DARK)
    d.polygon([(6, 21), (10, 16), (14, 18), (18, 11),
               (23, 15), (25, 23), (18, 25), (13, 22),
               (8, 26)], fill=GREEN)
    d.line((13, 13, 17, 9), fill=GREEN_LIGHT)
    d.line((19, 16, 23, 18), fill=GREEN_LIGHT)
    for x, y in ((9, 22), (18, 20), (23, 25), (13, 26)):
        d.point((x, y), fill=INK)
    return image


def crop_bundle():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.polygon([(4, 13), (5, 8), (3, 5), (5, 3),
               (8, 6), (10, 2), (13, 3), (11, 7),
               (12, 12), (9, 14)], fill=INK)
    d.line((6, 12, 6, 5), fill=GREEN)
    d.line((9, 12, 10, 4), fill=GREEN)
    d.line((7, 8, 4, 5), fill=GREEN_LIGHT)
    d.line((9, 9, 12, 5), fill=GREEN_LIGHT)
    d.point((4, 4), fill=GOLD)
    d.point((10, 3), fill=GOLD)
    d.point((12, 4), fill=GOLD)
    d.line((5, 12, 10, 12), fill=WOOD_DARK)
    return image


def villager_base(shirt, skin=SKIN):
    image, d = canvas((16, 24))
    ground(d, 16, 21)
    d.rectangle((5, 17, 7, 21), fill=DARK)
    d.rectangle((9, 17, 11, 21), fill=DARK)
    d.line((4, 22, 7, 22), fill=INK)
    d.line((9, 22, 12, 22), fill=INK)
    d.polygon([(4, 10), (6, 9), (10, 9), (12, 11),
               (12, 17), (4, 17)], fill=INK)
    d.rectangle((5, 11, 11, 16), fill=shirt)
    d.rectangle((3, 11, 4, 16), fill=skin)
    d.rectangle((12, 11, 13, 16), fill=skin)
    d.rectangle((5, 4, 11, 9), fill=INK)
    d.rectangle((6, 5, 10, 8), fill=skin)
    d.point((7, 7), fill=INK)
    return image, d


def river_villager_sunhat():
    image, d = villager_base((237, 222, 183))
    d.rectangle((5, 11, 6, 15), fill=STUCCO_SHADE)
    d.line((9, 11, 9, 16), fill=TERRA)
    d.line((5, 16, 11, 16), fill=WOOD)
    d.rectangle((4, 4, 12, 5), fill=INK)
    d.rectangle((5, 3, 11, 4), fill=SAND)
    d.rectangle((6, 2, 10, 3), fill=STUCCO)
    d.line((5, 4, 11, 4), fill=TERRA)
    return image


def river_villager_shawl():
    image, d = villager_base((71, 133, 149), (179, 121, 85))
    d.rectangle((5, 2, 10, 4), fill=WOOD_DARK)
    d.polygon([(5, 4), (8, 2), (11, 3), (12, 10),
               (14, 13), (11, 14), (10, 10), (5, 9),
               (3, 13), (2, 10)], fill=TERRA)
    d.rectangle((6, 5, 10, 8), fill=(179, 121, 85))
    d.point((7, 7), fill=INK)
    d.line((4, 11, 6, 11), fill=TERRA_LIGHT)
    d.line((10, 11, 12, 13), fill=TERRA_LIGHT)
    d.line((5, 16, 11, 16), fill=STUCCO)
    d.point((8, 12), fill=GOLD)
    return image


def river_fisherman():
    image, d = villager_base(TEAL)
    d.rectangle((6, 12, 10, 16), fill=(74, 141, 148))
    d.line((8, 11, 8, 16), fill=STUCCO)
    d.rectangle((3, 4, 12, 5), fill=INK)
    d.rectangle((5, 2, 10, 4), fill=STUCCO_SHADE)
    d.line((5, 3, 10, 3), fill=GOLD)
    d.line((12, 14, 15, 2), fill=WOOD_DARK)
    d.line((15, 3, 15, 15), fill=IRON_LIGHT)
    d.point((15, 16), fill=TERRA_LIGHT)
    d.point((12, 14), fill=SKIN)
    d.rectangle((5, 17, 7, 19), fill=STONE_DARK)
    return image


def finling():
    image, d = canvas((16, 24))
    ground(d, 16, 21)
    d.polygon([(3, 9), (5, 7), (5, 4), (7, 2),
               (9, 5), (11, 1), (13, 7), (14, 10),
               (14, 16), (12, 17), (12, 21), (9, 22),
               (8, 18), (6, 21), (3, 21), (4, 15),
               (2, 14)], fill=INK)
    d.polygon([(6, 7), (7, 4), (8, 7), (10, 5),
               (12, 8), (9, 10)], fill=CYAN)
    d.polygon([(4, 10), (7, 8), (11, 9), (13, 12),
               (12, 16), (9, 18), (5, 17), (3, 14)], fill=WATER)
    d.rectangle((4, 11, 6, 12), fill=WATER_DARK)
    d.point((5, 10), fill=TERRA_LIGHT)
    d.polygon([(8, 12), (12, 13), (11, 16), (7, 16)], fill=FOAM)
    d.line((6, 16, 10, 16), fill=TEAL)
    d.rectangle((5, 18, 6, 20), fill=WATER_DARK)
    d.rectangle((10, 18, 11, 20), fill=WATER_DARK)
    d.point((2, 14), fill=IVORY)
    d.point((14, 15), fill=IVORY)
    return image


def lake_maw():
    image, d = canvas((32, 24))
    ground(d, 32, 20)
    d.polygon([(2, 11), (6, 8), (11, 7), (14, 3),
               (17, 6), (20, 5), (25, 8), (30, 3),
               (31, 11), (27, 14), (31, 19),
               (25, 17), (20, 20), (13, 20),
               (5, 18), (1, 15)], fill=INK)
    d.polygon([(4, 10), (10, 9), (14, 7), (21, 8),
               (26, 11), (27, 16), (20, 18),
               (12, 18), (4, 15)], fill=WATER_DARK)
    d.polygon([(7, 10), (12, 8), (19, 9), (24, 11),
               (25, 14), (18, 15), (10, 14)], fill=WATER)
    d.polygon([(13, 7), (15, 4), (17, 8)], fill=CYAN)
    d.polygon([(20, 8), (22, 5), (24, 10)], fill=CYAN)
    d.polygon([(27, 8), (30, 5), (29, 11), (30, 17),
               (26, 14)], fill=TEAL)
    d.point((9, 10), fill=TERRA_LIGHT)
    d.polygon([(2, 14), (10, 14), (8, 17), (3, 16)], fill=INK)
    d.point((4, 14), fill=IVORY)
    d.point((7, 14), fill=IVORY)
    d.line((6, 17, 14, 18), fill=FOAM)
    d.line((15, 12, 20, 12), fill=CYAN)
    return image


def river_serpent():
    image, d = canvas((48, 24))
    ground(d, 48, 21)
    d.polygon([(2, 9), (5, 6), (12, 6), (15, 9),
               (17, 13), (23, 15), (29, 12),
               (33, 7), (38, 6), (43, 8),
               (47, 3), (47, 16), (41, 17),
               (36, 13), (33, 16), (29, 20),
               (22, 21), (16, 18), (10, 15),
               (4, 15), (1, 12)], fill=INK)
    d.polygon([(3, 9), (6, 8), (11, 8), (14, 11),
               (16, 15), (23, 17), (30, 14),
               (34, 9), (39, 8), (43, 10),
               (46, 7), (45, 14), (40, 15),
               (35, 11), (31, 16), (27, 18),
               (22, 19), (16, 16), (10, 13),
               (4, 13)], fill=TEAL)
    d.line((10, 9, 15, 14), fill=CYAN)
    d.line((19, 17, 24, 18), fill=CYAN)
    d.line((30, 15, 34, 10), fill=CYAN)
    d.point((7, 10), fill=GOLD)
    d.line((2, 12, 7, 12), fill=INK)
    d.point((3, 13), fill=IVORY)
    d.polygon([(18, 13), (19, 8), (23, 14)], fill=WATER)
    d.polygon([(34, 9), (36, 5), (39, 8)], fill=WATER)
    d.line((43, 10, 45, 9), fill=CYAN)
    return image


def fishing_rod_display():
    image, d = canvas((24, 32))
    ground(d, 24, 28)
    d.rectangle((5, 26, 20, 29), fill=INK)
    d.line((7, 27, 18, 27), fill=WOOD)
    d.rectangle((11, 18, 14, 26), fill=WOOD_DARK)
    d.rectangle((7, 19, 19, 21), fill=INK)
    d.line((9, 19, 17, 19), fill=WOOD)
    d.line((8, 18, 18, 3), fill=WOOD_DARK, width=2)
    d.line((10, 15, 18, 3), fill=STUCCO_SHADE)
    d.point((18, 3), fill=IVORY)
    d.line((18, 4, 21, 14), fill=IRON_LIGHT)
    d.line((21, 14, 20, 22), fill=IRON_LIGHT)
    d.rectangle((18, 20, 20, 22), fill=TERRA_LIGHT)
    d.point((19, 19), fill=IVORY)
    d.point((21, 23), fill=IRON)
    return image


def fishing_rod_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.line((2, 13, 11, 2), fill=INK, width=2)
    d.line((3, 12, 11, 2), fill=WOOD)
    d.point((11, 2), fill=IVORY)
    d.line((11, 3, 14, 6), fill=IRON_LIGHT)
    d.line((14, 6, 14, 12), fill=IRON_LIGHT)
    d.rectangle((13, 11, 15, 13), fill=TERRA_LIGHT)
    d.point((14, 10), fill=IVORY)
    d.point((2, 14), fill=GOLD)
    return image


def library_book_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.polygon([(1, 5), (4, 3), (7, 4), (8, 5),
               (9, 4), (12, 3), (15, 5), (15, 12),
               (9, 12), (8, 13), (7, 12), (1, 12)], fill=INK)
    d.polygon([(3, 5), (5, 4), (7, 5), (7, 11),
               (3, 10)], fill=STUCCO)
    d.polygon([(9, 5), (11, 4), (13, 5), (13, 10),
               (9, 11)], fill=IVORY)
    d.line((8, 5, 8, 12), fill=WOOD)
    d.line((4, 6, 6, 6), fill=TERRA)
    d.line((4, 8, 6, 8), fill=STONE_DARK)
    d.line((10, 6, 12, 6), fill=WATER_DARK)
    d.line((10, 8, 12, 8), fill=WATER_DARK)
    d.point((11, 10), fill=GOLD)
    return image


def food_fish_stew_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.line((5, 5, 6, 3), fill=FOAM)
    d.line((9, 5, 10, 2), fill=FOAM)
    d.polygon([(2, 7), (5, 6), (12, 6), (15, 8),
               (13, 13), (4, 13)], fill=INK)
    d.polygon([(4, 8), (11, 8), (12, 11), (5, 11)], fill=TERRA)
    d.line((5, 8, 11, 8), fill=GOLD)
    d.polygon([(6, 8), (8, 7), (10, 9), (8, 10)], fill=IRON_LIGHT)
    d.point((9, 8), fill=INK)
    d.point((5, 10), fill=GREEN)
    d.line((4, 12, 12, 12), fill=STUCCO)
    return image


def food_olive_bread_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.polygon([(2, 9), (4, 5), (7, 4), (11, 4),
               (14, 7), (14, 12), (3, 13)], fill=INK)
    d.polygon([(4, 9), (5, 6), (8, 5), (11, 6),
               (13, 8), (12, 11), (4, 11)], fill=SAND)
    d.line((5, 7, 8, 6), fill=IVORY)
    for x, y in ((6, 9), (9, 7), (11, 9)):
        d.point((x, y), fill=GREEN_DARK)
    d.line((4, 12, 12, 12), fill=WOOD)
    return image


def food_citrus_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.ellipse((2, 4, 13, 14), fill=INK)
    d.ellipse((4, 5, 11, 12), fill=GOLD)
    d.ellipse((5, 6, 10, 11), fill=(251, 211, 139))
    d.line((7, 6, 7, 11), fill=IVORY)
    d.line((5, 8, 10, 8), fill=IVORY)
    d.polygon([(8, 5), (10, 2), (14, 3), (11, 5)], fill=GREEN_DARK)
    d.line((10, 3, 13, 3), fill=GREEN_LIGHT)
    return image


SPRITES = {
    "river_town_hall": river_town_hall,
    "river_market": river_market,
    "river_townhouse": river_townhouse,
    "river_library": river_library,
    "town_center_fountain": town_center_fountain,
    "military_hq": military_hq,
    "arrow_target": arrow_target,
    "stone_bridge": stone_bridge,
    "lake_patch": lake_patch,
    "fishing_pond": fishing_pond,
    "fishing_boat": fishing_boat,
    "reed_cluster": reed_cluster,
    "terraced_field": terraced_field,
    "olive_tree": olive_tree,
    "crop_bundle": crop_bundle,
    "river_villager_sunhat": river_villager_sunhat,
    "river_villager_shawl": river_villager_shawl,
    "river_fisherman": river_fisherman,
    "finling": finling,
    "lake_maw": lake_maw,
    "river_serpent": river_serpent,
    "fishing_rod_display": fishing_rod_display,
    "fishing_rod_icon": fishing_rod_icon,
    "library_book_icon": library_book_icon,
    "food_fish_stew_icon": food_fish_stew_icon,
    "food_olive_bread_icon": food_olive_bread_icon,
    "food_citrus_icon": food_citrus_icon,
}


def contact_sheet(images):
    atlas_path = HERE / "river_terrain.png"
    if "river_terrain" not in images and atlas_path.is_file():
        images = dict(images)
        images["river_terrain"] = Image.open(atlas_path).convert("RGBA")
    sheet = Image.new("RGB", (1280, 2060), (33, 31, 45))
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.load_default(size=25)
    card_font = ImageFont.load_default(size=15)
    note_font = ImageFont.load_default(size=13)
    draw.text((25, 21), "RIVER PLANET  /  BRUDET PIXEL ART",
              font=title_font, fill=IVORY)
    draw.text((25, 53), "Playable river city | transparent sprites + opaque terrain atlas | PNG + LibreSprite source",
              font=note_font, fill=(169, 186, 191))
    for index, (name, image) in enumerate(images.items()):
        column = index % 4
        row = index // 4
        x = 20 + column * 315
        y = 90 + row * 280
        draw.rectangle((x, y, x + 300, y + 260), fill=(43, 43, 61),
                       outline=(86, 88, 105))
        draw.text((x + 12, y + 11), name, font=card_font, fill=IVORY)
        scale = min(12, 275 // image.width, 200 // image.height)
        enlarged = image.resize((image.width * scale, image.height * scale),
                                Image.Resampling.NEAREST)
        art_x = x + (300 - enlarged.width) // 2
        art_y = y + 31 + (200 - enlarged.height) // 2
        sheet.paste(enlarged, (art_x, art_y), enlarged)
        if name == "river_terrain":
            for grid_x in range(1, 8):
                gx = art_x + grid_x * 16 * scale
                draw.line((gx, art_y, gx, art_y + enlarged.height), fill=(41, 43, 59))
            for grid_y in range(1, 4):
                gy = art_y + grid_y * 16 * scale
                draw.line((art_x, gy, art_x + enlarged.width, gy), fill=(41, 43, 59))
            draw.text((x + 12, y + 220), "32 tiles / local IDs 0-31",
                      font=note_font, fill=(169, 186, 191))
        draw.text((x + 12, y + 239), f"{image.width} x {image.height} px",
                  font=note_font, fill=(167, 183, 190))
    sheet.save(HERE / "river_planet_contact_sheet.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aseprite", action="store_true",
                        help="also save editable LibreSprite sources")
    args = parser.parse_args()
    sprite = shutil.which("sprite") if args.aseprite else None
    if args.aseprite and sprite is None:
        parser.error("LibreSprite's `sprite` executable is required for --aseprite")
    images = {}
    for name, make_image in SPRITES.items():
        image = make_image()
        images[name] = image
        png = HERE / f"{name}.png"
        image.save(png)
        if sprite is not None:
            subprocess.run([sprite, "--batch", str(png), "--save-as",
                            str(HERE / f"{name}.aseprite")], check=True,
                           stdout=subprocess.DEVNULL)
        print(f"{name}: {image.width} x {image.height}")
    contact_sheet(images)
    print("river_planet_contact_sheet.png: 1280 x 2060")


if __name__ == "__main__":
    main()
