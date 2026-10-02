"""Regenerate the northern-village pixel art in this directory.

Run with /usr/bin/python3 create_northern_art.py --aseprite to also create
editable LibreSprite copies. Some sprites are used on the live northern map.
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
WALL = (234, 217, 172)
WALL_SHADE = (216, 201, 158)
WOOD = (139, 85, 55)
WOOD_DARK = (84, 51, 40)
COPPER = (168, 77, 63)
COPPER_LIGHT = (213, 107, 79)
BLUE = (78, 131, 207)
TEAL = (36, 127, 138)
CYAN = (95, 214, 211)
FORGE = (125, 74, 58)
AMBER = (239, 135, 63)
GOLD = (245, 195, 76)
IRON = (116, 127, 137)
IRON_LIGHT = (216, 226, 223)
PURPLE = (133, 112, 165)
PURPLE_LIGHT = (192, 158, 214)
GREEN = (67, 134, 74)
FONT = ImageFont.load_default()


def canvas(size):
    image = Image.new("RGBA", size)
    return image, ImageDraw.Draw(image)


def ground(draw, width, y):
    draw.ellipse((3, y - 4, width - 4, y + 2), fill=SHADOW)


def plaque(draw, text, cx, y):
    width = round(FONT.getlength(text)) + 6
    left = cx - width // 2
    draw.rectangle((left, y, left + width, y + 12), fill=INK, outline=IVORY)
    draw.text((left + 3, y), text, font=FONT, fill=IVORY)


def window(draw, x, y, color=BLUE, lit=False, width=9, height=10):
    draw.rectangle((x, y, x + width, y + height), fill=INK)
    draw.rectangle((x + 2, y + 2, x + width - 2, y + height - 2),
                   fill=GOLD if lit else color)
    draw.line((x + 2, y + 2, x + width - 2, y + 2),
              fill=WALL if lit else CYAN)
    draw.line((x + width // 2, y + 2, x + width // 2, y + height - 2),
              fill=WOOD_DARK)


def door(draw, x, y, width=11, height=18):
    draw.rectangle((x, y, x + width, y + height), fill=INK)
    draw.rectangle((x + 2, y + 2, x + width - 2, y + height - 1),
                   fill=WOOD_DARK)
    draw.line((x + 3, y + 3, x + width - 3, y + 3), fill=WOOD)
    draw.point((x + width - 3, y + height // 2), fill=GOLD)


def north_house_copper():
    image, d = canvas((64, 80))
    ground(d, 64, 75)
    d.rectangle((12, 27, 52, 70), fill=INK)
    d.rectangle((14, 29, 50, 68), fill=WALL)
    d.rectangle((15, 46, 49, 48), fill=WOOD)
    d.rectangle((17, 49, 18, 68), fill=WALL_SHADE)
    d.rectangle((46, 49, 47, 68), fill=WALL_SHADE)
    d.rectangle((45, 5, 52, 20), fill=INK)
    d.rectangle((47, 7, 50, 19), fill=WOOD)
    d.line((46, 5, 53, 5), fill=WALL_SHADE)
    d.polygon([(5, 28), (22, 9), (42, 9), (59, 28),
               (57, 32), (7, 32)], fill=INK)
    d.polygon([(9, 28), (23, 11), (41, 11), (55, 28),
               (53, 30), (11, 30)], fill=COPPER)
    d.polygon([(23, 11), (28, 11), (12, 29), (9, 28)],
              fill=COPPER_LIGHT)
    d.line((30, 11, 40, 11), fill=COPPER_LIGHT)
    d.line((8, 32, 56, 32), fill=WOOD_DARK)
    window(d, 19, 35, width=9, height=9)
    window(d, 36, 35, width=9, height=9)
    window(d, 18, 53, lit=True, width=8, height=10)
    door(d, 33, 51, width=11, height=18)
    d.rectangle((12, 68, 52, 70), fill=INK)
    d.line((16, 69, 47, 69), fill=WOOD)
    d.point((11, 31), fill=GOLD)
    return image


def north_house_blue():
    image, d = canvas((64, 80))
    ground(d, 64, 75)
    d.polygon([(10, 36), (16, 30), (51, 30), (55, 36),
               (55, 71), (10, 71)], fill=INK)
    d.rectangle((13, 37, 52, 69), fill=WALL)
    d.rectangle((18, 34, 47, 57), fill=WALL_SHADE)
    d.polygon([(7, 35), (18, 19), (48, 19), (57, 35),
               (53, 38), (10, 38)], fill=INK)
    d.polygon([(11, 34), (20, 21), (46, 21), (53, 34),
               (49, 35), (14, 35)], fill=BLUE)
    d.polygon([(11, 34), (20, 21), (25, 21), (15, 34)],
              fill=(114, 166, 221))
    d.polygon([(24, 21), (28, 12), (38, 12), (42, 21)], fill=INK)
    d.polygon([(27, 20), (29, 14), (37, 14), (40, 20)], fill=BLUE)
    d.rectangle((30, 18, 36, 27), fill=INK)
    d.rectangle((31, 20, 35, 25), fill=CYAN)
    d.line((14, 37, 51, 37), fill=WOOD_DARK)
    window(d, 18, 41, width=9, height=10)
    window(d, 38, 41, lit=True, width=9, height=10)
    d.polygon([(9, 56), (27, 56), (31, 61), (31, 69),
               (7, 69), (7, 61)], fill=INK)
    d.polygon([(9, 59), (27, 59), (29, 62), (29, 68),
               (9, 68)], fill=WOOD)
    door(d, 14, 53, width=11, height=17)
    d.line((7, 57, 29, 57), fill=COPPER_LIGHT)
    d.rectangle((34, 57, 49, 68), fill=WALL_SHADE)
    d.line((36, 59, 47, 59), fill=WOOD)
    d.rectangle((11, 70, 54, 71), fill=INK)
    return image


def north_house_green():
    image, d = canvas((64, 80))
    ground(d, 64, 75)
    d.rectangle((11, 28, 39, 71), fill=INK)
    d.rectangle((13, 30, 37, 69), fill=WALL)
    d.polygon([(32, 43), (40, 35), (55, 35), (58, 42),
               (58, 71), (33, 71)], fill=INK)
    d.rectangle((35, 45, 56, 69), fill=WALL_SHADE)
    d.polygon([(8, 30), (18, 10), (30, 10), (42, 30),
               (39, 33), (11, 33)], fill=INK)
    d.polygon([(11, 29), (19, 12), (29, 12), (39, 29),
               (37, 31), (13, 31)], fill=(55, 109, 68))
    d.line((17, 15, 21, 12), fill=(99, 168, 82))
    d.polygon([(29, 43), (38, 32), (53, 32), (61, 44),
               (58, 46), (33, 46)], fill=INK)
    d.polygon([(33, 43), (39, 34), (52, 34), (57, 43)],
              fill=GREEN)
    d.line((40, 35, 50, 35), fill=(99, 168, 82))
    window(d, 20, 34, lit=True, width=10, height=10)
    window(d, 41, 49, width=9, height=9)
    door(d, 19, 52, width=12, height=18)
    d.rectangle((11, 68, 57, 71), fill=INK)
    d.line((13, 69, 56, 69), fill=IRON)
    d.rectangle((32, 47, 33, 67), fill=WOOD_DARK)
    d.point((15, 44), fill=GOLD)
    return image


def north_food_shop():
    image, d = canvas((80, 72))
    ground(d, 80, 68)
    d.polygon([(9, 29), (18, 17), (53, 15), (72, 28),
               (73, 66), (7, 66)], fill=INK)
    d.polygon([(11, 31), (19, 19), (52, 17), (70, 29),
               (70, 64), (10, 64)], fill=TEAL)
    d.polygon([(9, 30), (19, 18), (53, 16), (69, 27),
               (65, 31), (19, 27)], fill=CYAN)
    d.polygon([(20, 19), (27, 18), (19, 27), (10, 30)],
              fill=(140, 230, 207))
    d.line((53, 17, 69, 28), fill=TEAL)
    d.rectangle((13, 39, 67, 63), fill=(36, 112, 124))
    d.rectangle((14, 46, 30, 60), fill=INK)
    d.rectangle((16, 48, 28, 58), fill=(66, 148, 151))
    d.line((17, 48, 26, 48), fill=CYAN)
    d.polygon([(18, 56), (19, 52), (21, 50), (25, 51),
               (27, 55), (25, 56)], fill=GOLD)
    d.line((20, 52, 22, 51), fill=IVORY)
    d.rectangle((50, 46, 66, 60), fill=INK)
    d.rectangle((52, 48, 64, 58), fill=(66, 148, 151))
    d.rectangle((55, 53, 61, 56), fill=WALL)
    d.point((56, 52), fill=GOLD)
    door(d, 34, 45, width=11, height=20)
    d.rectangle((12, 39, 68, 45), fill=INK)
    for x in range(14, 66, 9):
        d.rectangle((x, 41, x + 4, 44), fill=WALL)
    d.line((13, 40, 67, 40), fill=CYAN)
    plaque(d, "FOOD", 40, 29)
    d.line((9, 65, 72, 65), fill=(27, 87, 102))
    return image


def north_clothing_shop():
    image, d = canvas((80, 72))
    ground(d, 80, 68)
    d.polygon([(8, 30), (18, 15), (59, 15), (72, 29),
               (72, 66), (7, 66)], fill=INK)
    d.polygon([(10, 32), (19, 17), (58, 17), (70, 30),
               (70, 64), (10, 64)], fill=WALL_SHADE)
    d.polygon([(9, 30), (19, 16), (58, 16), (71, 29),
               (68, 33), (14, 33)], fill=PURPLE)
    d.polygon([(12, 28), (20, 17), (28, 17), (17, 30)],
              fill=PURPLE_LIGHT)
    d.line((22, 17, 56, 17), fill=PURPLE_LIGHT)
    d.line((14, 33, 68, 33), fill=WOOD_DARK)
    d.rectangle((12, 40, 68, 64), fill=WALL)
    d.rectangle((14, 48, 34, 62), fill=INK)
    d.rectangle((16, 50, 32, 60), fill=(61, 101, 113))
    d.line((17, 50, 30, 50), fill=CYAN)
    d.polygon([(18, 56), (22, 52), (28, 52), (31, 56),
               (30, 59), (18, 59)], fill=PURPLE)
    d.line((20, 54, 28, 54), fill=PURPLE_LIGHT)
    d.line((19, 58, 29, 58), fill=(90, 69, 123))
    d.rectangle((53, 48, 67, 62), fill=INK)
    d.rectangle((55, 50, 65, 60), fill=(61, 101, 113))
    d.line((56, 50, 63, 50), fill=CYAN)
    d.polygon([(57, 53), (59, 52), (60, 53), (62, 52),
               (64, 54), (62, 55), (62, 58), (57, 58),
               (57, 55), (55, 54)], fill=PURPLE_LIGHT)
    d.line((59, 55, 59, 58), fill=PURPLE)
    door(d, 38, 47, width=12, height=18)
    d.rectangle((12, 41, 68, 47), fill=INK)
    d.line((14, 42, 66, 42), fill=PURPLE_LIGHT)
    for x in range(14, 67, 9):
        d.rectangle((x, 43, x + 4, 46), fill=IVORY)
        d.rectangle((x + 5, 43, x + 8, 46), fill=PURPLE)
    plaque(d, "CLOTHES", 40, 29)
    d.line((9, 65, 71, 65), fill=WOOD_DARK)
    return image


def north_forge():
    image, d = canvas((80, 72))
    ground(d, 80, 68)
    d.point((61, 2), fill=WALL_SHADE)
    d.point((65, 5), fill=IRON)
    d.rectangle((57, 5, 66, 24), fill=INK)
    d.rectangle((59, 8, 64, 23), fill=FORGE)
    d.rectangle((56, 5, 67, 7), fill=DARK)
    d.line((58, 8, 65, 8), fill=IRON)
    d.polygon([(8, 31), (18, 17), (60, 17), (72, 31),
               (73, 66), (7, 66)], fill=INK)
    d.polygon([(10, 32), (19, 19), (59, 19), (70, 32),
               (70, 64), (10, 64)], fill=FORGE)
    d.polygon([(9, 31), (19, 18), (59, 18), (71, 31),
               (67, 34), (16, 34)], fill=AMBER)
    d.polygon([(19, 19), (26, 19), (17, 31), (10, 31)],
              fill=(252, 166, 88))
    d.line((15, 34, 68, 34), fill=WOOD_DARK)
    d.rectangle((13, 44, 67, 64), fill=(110, 64, 54))
    door(d, 34, 45, width=12, height=20)
    d.rectangle((53, 49, 68, 62), fill=INK)
    d.rectangle((55, 51, 66, 60), fill=AMBER)
    d.polygon([(56, 60), (58, 56), (57, 53), (61, 55),
               (64, 52), (65, 59)], fill=GOLD)
    d.point((61, 57), fill=IVORY)
    d.rectangle((12, 51, 29, 61), fill=INK)
    d.rectangle((14, 53, 27, 59), fill=(58, 63, 76))
    d.polygon([(10, 60), (14, 57), (20, 57), (21, 55),
               (28, 55), (26, 61), (23, 61), (23, 64),
               (14, 64), (14, 61)], fill=INK)
    d.polygon([(13, 59), (21, 59), (23, 57), (26, 57),
               (24, 60), (20, 60), (20, 62), (16, 62)], fill=IRON)
    d.line((14, 59, 24, 59), fill=IRON_LIGHT)
    plaque(d, "FORGE", 40, 30)
    d.line((9, 65, 71, 65), fill=WOOD_DARK)
    return image


def north_travel_agency():
    image, d = canvas((112, 80))
    ground(d, 112, 75)
    d.polygon([(9, 34), (29, 29), (40, 20), (47, 12),
               (77, 12), (87, 27), (105, 34), (105, 70),
               (8, 70)], fill=INK)
    d.polygon([(11, 36), (31, 31), (42, 22), (49, 14),
               (75, 14), (85, 29), (102, 35), (102, 68),
               (10, 68)], fill=TEAL)
    d.polygon([(24, 32), (47, 13), (77, 13), (94, 32),
               (85, 32), (73, 17), (49, 17), (34, 33)], fill=CYAN)
    d.polygon([(47, 14), (53, 14), (35, 34), (25, 34)],
              fill=(154, 233, 212))
    d.rectangle((11, 37, 101, 68), fill=(33, 107, 120))
    d.line((12, 37, 100, 37), fill=CYAN)
    d.rectangle((16, 44, 37, 61), fill=INK)
    d.rectangle((18, 46, 35, 59), fill=(67, 137, 152))
    d.line((19, 47, 34, 47), fill=CYAN)
    d.polygon([(21, 55), (25, 51), (28, 53), (32, 48),
               (33, 56)], fill=WALL)
    d.line((22, 56, 33, 56), fill=INK)
    d.point((25, 52), fill=GOLD)
    d.point((32, 49), fill=AMBER)
    d.rectangle((75, 44, 97, 61), fill=INK)
    d.rectangle((77, 46, 95, 59), fill=(67, 137, 152))
    d.line((78, 47, 94, 47), fill=CYAN)
    d.polygon([(82, 51), (86, 51), (89, 54), (91, 53),
               (93, 56), (81, 56)], fill=WALL)
    d.point((87, 52), fill=AMBER)
    d.rectangle((45, 44, 68, 69), fill=INK)
    d.rectangle((47, 46, 66, 68), fill=(45, 114, 126))
    d.line((56, 47, 56, 67), fill=INK)
    d.line((48, 47, 64, 47), fill=CYAN)
    d.point((59, 58), fill=GOLD)
    d.polygon([(18, 63), (31, 63), (33, 68), (16, 68)], fill=WOOD_DARK)
    d.line((20, 63, 30, 63), fill=GOLD)
    d.line((9, 69, 104, 69), fill=INK)
    d.rectangle((60, 5, 63, 13), fill=INK)
    d.polygon([(63, 6), (75, 8), (70, 13), (63, 13)], fill=GOLD)
    d.point((66, 9), fill=INK)
    plaque(d, "TRAVEL", 56, 30)
    return image


def iron_gear_shop():
    image, d = canvas((80, 72))
    ground(d, 80, 68)
    d.polygon([(8, 34), (17, 21), (62, 21), (73, 33),
               (73, 67), (7, 67)], fill=INK)
    d.polygon([(10, 35), (19, 23), (60, 23), (70, 34),
               (70, 65), (10, 65)], fill=(106, 116, 124))
    d.polygon([(9, 33), (18, 21), (62, 21), (72, 33),
               (68, 35), (13, 35)], fill=(66, 74, 87))
    d.polygon([(17, 23), (24, 23), (14, 34), (10, 34)], fill=IRON)
    d.line((24, 22, 60, 22), fill=IRON)
    for x in (17, 32, 47, 62):
        d.line((x, 29, x - 3, 34), fill=(87, 97, 106))
    d.rectangle((12, 43, 68, 63), fill=(89, 100, 109))
    d.rectangle((14, 47, 31, 62), fill=INK)
    d.rectangle((16, 49, 29, 60), fill=(54, 87, 101))
    d.line((22, 49, 22, 56), fill=IRON_LIGHT)
    d.polygon([(21, 50), (23, 50), (22, 48)], fill=IRON_LIGHT)
    d.line((19, 56, 25, 56), fill=IRON)
    d.point((22, 57), fill=GOLD)
    d.rectangle((49, 47, 66, 62), fill=INK)
    d.rectangle((51, 49, 64, 60), fill=(54, 87, 101))
    d.polygon([(54, 50), (57, 49), (60, 49), (63, 51),
               (61, 54), (61, 58), (55, 58), (55, 54)], fill=IRON)
    d.line((55, 51, 61, 51), fill=IRON_LIGHT)
    door(d, 35, 49, width=10, height=17)
    plaque(d, "IRON GEAR", 40, 33)
    d.line((8, 66, 71, 66), fill=IRON_LIGHT)
    return image


def iron_sword_display():
    image, d = canvas((24, 32))
    ground(d, 24, 28)
    d.rectangle((9, 21, 14, 28), fill=INK)
    d.rectangle((10, 23, 13, 27), fill=WOOD)
    d.rectangle((4, 27, 20, 29), fill=INK)
    d.line((6, 28, 18, 28), fill=WOOD)
    d.polygon([(11, 3), (14, 3), (15, 15), (13, 19),
               (11, 19), (9, 15)], fill=INK)
    d.polygon([(11, 6), (13, 4), (14, 15), (12, 17),
               (10, 15)], fill=IRON)
    d.line((12, 6, 12, 15), fill=IRON_LIGHT)
    d.rectangle((6, 17, 18, 19), fill=INK)
    d.line((8, 17, 16, 17), fill=IRON_LIGHT)
    d.rectangle((11, 19, 13, 24), fill=WOOD_DARK)
    d.point((12, 23), fill=GOLD)
    return image


def iron_armor_display():
    image, d = canvas((24, 32))
    ground(d, 24, 28)
    d.rectangle((10, 19, 13, 27), fill=WOOD_DARK)
    d.rectangle((5, 27, 19, 29), fill=INK)
    d.line((7, 28, 18, 28), fill=WOOD)
    d.polygon([(9, 4), (10, 2), (14, 2), (16, 5),
               (15, 9), (9, 9)], fill=INK)
    d.rectangle((10, 4, 14, 7), fill=IRON)
    d.line((10, 4, 13, 4), fill=IRON_LIGHT)
    d.polygon([(5, 9), (9, 8), (11, 10), (14, 10),
               (16, 8), (20, 9), (21, 14), (18, 16),
               (17, 22), (7, 22), (6, 16), (3, 14)], fill=INK)
    d.polygon([(6, 10), (9, 10), (10, 12), (14, 12),
               (16, 10), (19, 10), (19, 14), (16, 14),
               (16, 20), (8, 20), (8, 14), (5, 14)], fill=IRON)
    d.line((8, 12, 12, 13), fill=IRON_LIGHT)
    d.line((12, 13, 16, 12), fill=IRON_LIGHT)
    d.line((12, 13, 12, 18), fill=INK)
    d.line((8, 19, 16, 19), fill=(74, 84, 96))
    d.point((12, 18), fill=GOLD)
    return image


def purple_cloth_display():
    image, d = canvas((24, 32))
    ground(d, 24, 28)
    d.rectangle((3, 8, 20, 10), fill=INK)
    d.line((5, 9, 19, 9), fill=WOOD)
    d.rectangle((4, 11, 5, 28), fill=WOOD_DARK)
    d.rectangle((19, 11, 20, 28), fill=WOOD_DARK)
    d.polygon([(8, 11), (11, 11), (12, 13), (15, 11),
               (17, 12), (19, 17), (16, 19), (16, 25),
               (8, 25), (8, 19), (5, 17)], fill=INK)
    d.polygon([(8, 13), (11, 13), (12, 15), (15, 13),
               (16, 14), (17, 17), (15, 18), (15, 23),
               (9, 23), (9, 18), (7, 17)], fill=PURPLE)
    d.line((9, 14, 10, 14), fill=PURPLE_LIGHT)
    d.line((9, 19, 9, 22), fill=PURPLE_LIGHT)
    d.line((12, 16, 12, 22), fill=(82, 63, 118))
    d.polygon([(2, 27), (6, 24), (9, 26), (16, 26),
               (21, 24), (22, 28), (2, 29)], fill=INK)
    d.line((4, 27, 19, 27), fill=PURPLE_LIGHT)
    return image


def iron_sword_icon():
    image, d = canvas((16, 16))
    d.ellipse((2, 12, 14, 15), fill=SHADOW)
    d.polygon([(11, 2), (14, 1), (13, 5), (7, 11),
               (5, 9)], fill=INK)
    d.polygon([(11, 3), (13, 2), (12, 5), (7, 10),
               (6, 9)], fill=IRON)
    d.line((12, 3, 7, 8), fill=IRON_LIGHT)
    d.line((3, 7, 9, 13), fill=INK)
    d.line((4, 8, 8, 12), fill=IRON_LIGHT)
    d.line((5, 10, 3, 12), fill=WOOD_DARK)
    d.point((3, 13), fill=GOLD)
    return image


def iron_armor_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.polygon([(4, 3), (6, 2), (7, 4), (9, 4),
               (10, 2), (12, 3), (15, 7), (12, 9),
               (12, 13), (4, 13), (4, 9), (1, 7)], fill=INK)
    d.polygon([(5, 4), (6, 4), (7, 6), (9, 6),
               (10, 4), (11, 4), (13, 7), (11, 8),
               (11, 11), (5, 11), (5, 8), (3, 7)], fill=IRON)
    d.line((5, 5, 8, 7), fill=IRON_LIGHT)
    d.line((8, 7, 11, 5), fill=IRON_LIGHT)
    d.line((8, 7, 8, 11), fill=(65, 69, 84))
    d.line((5, 12, 11, 12), fill=IRON_LIGHT)
    d.point((8, 10), fill=GOLD)
    return image


def purple_cloth_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 12, 15, 15), fill=SHADOW)
    d.polygon([(2, 10), (5, 8), (13, 8), (15, 11),
               (13, 14), (3, 14)], fill=INK)
    d.polygon([(4, 10), (6, 9), (12, 9), (13, 11),
               (12, 12), (4, 12)], fill=PURPLE)
    d.line((6, 9, 11, 9), fill=PURPLE_LIGHT)
    d.rectangle((3, 5, 12, 8), fill=INK)
    d.rectangle((4, 6, 11, 7), fill=(110, 83, 150))
    d.line((4, 5, 10, 5), fill=PURPLE_LIGHT)
    d.polygon([(4, 3), (10, 3), (12, 5), (3, 5)], fill=INK)
    d.line((5, 3, 10, 3), fill=PURPLE_LIGHT)
    return image


def purple_tunic_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 13, 15, 15), fill=SHADOW)
    d.polygon([(4, 2), (6, 2), (7, 4), (9, 4),
               (10, 2), (12, 2), (15, 6), (12, 8),
               (12, 13), (4, 13), (4, 8), (1, 6)], fill=INK)
    d.polygon([(5, 3), (6, 3), (7, 5), (9, 5),
               (10, 3), (11, 3), (13, 6), (11, 7),
               (11, 11), (5, 11), (5, 7), (3, 6)], fill=PURPLE)
    d.line((5, 4, 6, 4), fill=PURPLE_LIGHT)
    d.line((10, 4, 11, 4), fill=PURPLE_LIGHT)
    d.line((5, 12, 11, 12), fill=PURPLE_LIGHT)
    d.line((8, 6, 8, 10), fill=(82, 63, 118))
    d.point((8, 7), fill=GOLD)
    return image


def food_rye_bread_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 12, 15, 15), fill=SHADOW)
    d.polygon([(1, 10), (3, 6), (5, 4), (10, 3),
               (13, 5), (15, 9), (14, 12), (3, 13)], fill=INK)
    d.polygon([(3, 10), (4, 7), (7, 5), (10, 5),
               (13, 7), (13, 11), (4, 11)], fill=WOOD)
    d.line((4, 10, 12, 10), fill=WALL)
    d.line((6, 7, 7, 6), fill=GOLD)
    d.line((9, 6, 10, 7), fill=GOLD)
    d.point((11, 8), fill=GOLD)
    return image


def food_berry_pie_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 12, 15, 15), fill=SHADOW)
    d.polygon([(2, 7), (4, 4), (11, 4), (14, 7),
               (15, 11), (12, 13), (4, 13), (1, 11)], fill=INK)
    d.polygon([(3, 7), (5, 5), (11, 5), (13, 7),
               (13, 10), (11, 11), (4, 11), (3, 10)], fill=COPPER)
    d.line((4, 6, 11, 6), fill=COPPER_LIGHT)
    d.line((3, 9, 12, 9), fill=GOLD)
    d.line((6, 6, 5, 10), fill=GOLD)
    d.line((10, 6, 11, 10), fill=GOLD)
    d.point((8, 7), fill=(110, 47, 83))
    d.line((4, 12, 12, 12), fill=WALL)
    return image


def food_smoked_fish_icon():
    image, d = canvas((16, 16))
    d.ellipse((1, 12, 15, 15), fill=SHADOW)
    d.polygon([(1, 5), (5, 7), (9, 4), (13, 6),
               (15, 9), (12, 12), (7, 11), (5, 9),
               (1, 11), (3, 8)], fill=INK)
    d.polygon([(3, 6), (6, 8), (9, 6), (12, 7),
               (13, 9), (11, 10), (7, 10), (5, 8),
               (3, 10), (4, 8)], fill=IRON)
    d.line((7, 8, 11, 8), fill=IRON_LIGHT)
    d.point((12, 8), fill=INK)
    d.line((6, 9, 7, 10), fill=TEAL)
    d.point((10, 11), fill=GOLD)
    return image


def player_purple():
    image = Image.open(HERE.parent / "player_blue.png").convert("RGBA")
    colors = {
        (*BLUE, 255): (*PURPLE, 255),
        (47, 92, 156, 255): (82, 62, 117, 255),
    }
    for y in range(10, 17):
        for x in range(image.width):
            color = image.getpixel((x, y))
            if color in colors:
                image.putpixel((x, y), colors[color])
    d = ImageDraw.Draw(image)
    d.line((5, 11, 5, 15), fill=PURPLE_LIGHT)
    d.line((10, 11, 10, 14), fill=(105, 78, 140))
    return image


SPRITES = {
    "north_house_copper": north_house_copper,
    "north_house_blue": north_house_blue,
    "north_house_green": north_house_green,
    "north_food_shop": north_food_shop,
    "north_clothing_shop": north_clothing_shop,
    "north_forge": north_forge,
    "north_travel_agency": north_travel_agency,
    "iron_gear_shop": iron_gear_shop,
    "iron_sword_display": iron_sword_display,
    "iron_armor_display": iron_armor_display,
    "purple_cloth_display": purple_cloth_display,
    "iron_sword_icon": iron_sword_icon,
    "iron_armor_icon": iron_armor_icon,
    "purple_cloth_icon": purple_cloth_icon,
    "purple_tunic_icon": purple_tunic_icon,
    "player_purple": player_purple,
    "food_rye_bread_icon": food_rye_bread_icon,
    "food_berry_pie_icon": food_berry_pie_icon,
    "food_smoked_fish_icon": food_smoked_fish_icon,
}


def contact_sheet(images):
    sheet = Image.new("RGB", (1060, 1680), (33, 31, 45))
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.load_default(size=24)
    card_font = ImageFont.load_default(size=15)
    note_font = ImageFont.load_default(size=13)
    draw.text((25, 23), "NORTHERN VILLAGE  /  PIXEL ART",
              font=title_font, fill=IVORY)
    draw.text((25, 53), "PNG + editable LibreSprite source | artwork used on the live map",
              font=note_font, fill=(157, 167, 177))
    for index, (name, image) in enumerate(images.items()):
        column = index % 3
        row = index // 3
        if row == (len(images) - 1) // 3 and len(images) % 3 == 1:
            column = 1
        x = 20 + column * 340
        y = 87 + row * 225
        draw.rectangle((x, y, x + 320, y + 210), fill=(43, 43, 61),
                       outline=(85, 86, 105))
        draw.text((x + 12, y + 10), name, font=card_font, fill=IVORY)
        scale = min(10, 280 // image.width, 160 // image.height)
        enlarged = image.resize((image.width * scale, image.height * scale),
                                Image.Resampling.NEAREST)
        sheet.paste(enlarged, (x + (320 - enlarged.width) // 2,
                               y + 29 + (160 - enlarged.height) // 2), enlarged)
        draw.text((x + 12, y + 188), f"{image.width} x {image.height} px",
                  font=note_font, fill=(163, 177, 187))
    sheet.save(HERE / "northern_village_contact_sheet.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aseprite", action="store_true",
                        help="also save editable LibreSprite copies")
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
    print("northern_village_contact_sheet.png: 1060 x 1680")


if __name__ == "__main__":
    main()
