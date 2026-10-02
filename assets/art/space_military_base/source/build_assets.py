"""Editable pixel-art designs for the proposed Space Military Base.

Run from anywhere with: python assets/art/space_military_base/source/build_assets.py
Requires ImageMagick's convert for PNG exports. No game maps or tilesets are changed.
"""

from base64 import b64encode
from pathlib import Path
import subprocess

BASE = Path(__file__).resolve().parents[1]
SOURCE = BASE / 'source'
INK = '#17162d'
SHADOW = '#303948'
STONE = '#66717c'
STONE_LIGHT = '#99a5a6'
METAL = '#536979'
STEEL = '#afc6c4'
HIGHLIGHT = '#e2e4c9'
GREEN = '#58d740'
LIME = '#a5f068'
DARK_GREEN = '#2e8747'
SAND = '#ad855d'
DARK_SAND = '#805e4b'
RUST = '#a2664a'
WINDOW = '#72d9d7'
GOLD = '#dfc873'

FONT = {
    'A': ['010', '101', '111', '101', '101'],
    'C': ['011', '100', '100', '100', '011'],
    'E': ['111', '100', '110', '100', '111'],
    'H': ['101', '101', '111', '101', '101'],
    'M': ['101', '111', '111', '101', '101'],
    'O': ['010', '101', '101', '101', '010'],
    'Q': ['010', '101', '101', '011', '001'],
    'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'],
    '1': ['010', '110', '010', '010', '111'],
    '2': ['110', '001', '010', '100', '111'],
}


class Sprite:
    def __init__(self, name, width, height):
        self.name, self.width, self.height = name, width, height
        self.parts = []

    def rect(self, x, y, width, height, color):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{width}" height="{height}" fill="{color}"/>')

    def box(self, x, y, width, height, fill, border=INK, thickness=2):
        self.rect(x, y, width, height, border)
        self.rect(x + thickness, y + thickness, width - 2 * thickness,
                  height - 2 * thickness, fill)

    def glyph(self, text, x, y, color=HIGHLIGHT, pixel=1):
        for char in text:
            rows = FONT[char]
            for dy, row in enumerate(rows):
                for dx, mark in enumerate(row):
                    if mark == '1':
                        self.rect(x + dx * pixel, y + dy * pixel, pixel, pixel, color)
            x += 4 * pixel

    def file(self):
        body = ''.join(self.parts)
        xml = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" '
               f'height="{self.height}" viewBox="0 0 {self.width} {self.height}" '
               f'shape-rendering="crispEdges">{body}</svg>')
        path = SOURCE / f'{self.name}.svg'
        path.write_text(xml + '\n')
        subprocess.run(['convert', '-background', 'none', str(path),
                        str(BASE / f'{self.name}.png')], check=True)
        return self


def stone_wall(s, x, y, width, height):
    s.box(x, y, width, height, STONE)
    for row in range(y + 8, y + height - 3, 10):
        s.rect(x + 3, row, width - 6, 1, SHADOW)
        for col in range(x + 8 + (row % 20) // 2, x + width - 5, 19):
            s.rect(col, row - 7, 1, 7, SHADOW)
            s.rect(col + 1, row - 6, 2, 1, STONE_LIGHT)


def window(s, x, y):
    s.box(x, y, 12, 13, INK)
    s.rect(x + 3, y + 2, 6, 7, WINDOW)
    s.rect(x + 5, y + 2, 2, 7, METAL)
    s.rect(x + 2, y + 10, 8, 2, STONE_LIGHT)


def roof(s, x, y, width, green=False):
    color = DARK_GREEN if green else METAL
    s.rect(x + 9, y, width - 18, 4, INK)
    s.rect(x + 7, y + 3, width - 14, 4, color)
    s.rect(x + 4, y + 7, width - 8, 6, INK)
    s.rect(x + 6, y + 8, width - 12, 3, GREEN if green else STEEL)
    s.rect(x + 1, y + 13, width - 2, 7, color)
    s.rect(x, y + 18, width, 4, INK)
    s.rect(x + 10, y + 2, width - 20, 1, LIME if green else STONE_LIGHT)


def insignia(s, x, y):
    s.box(x, y, 12, 12, DARK_GREEN, INK, 1)
    s.rect(x + 5, y + 2, 2, 8, LIME)
    s.rect(x + 2, y + 5, 8, 2, LIME)
    s.rect(x + 4, y + 4, 4, 4, HIGHLIGHT)


def headquarters():
    s = Sprite('headquarters', 112, 96)
    s.rect(10, 89, 92, 5, SHADOW)
    stone_wall(s, 9, 28, 94, 62)
    s.box(2, 37, 16, 51, SHADOW)
    s.box(94, 37, 16, 51, SHADOW)
    for x in (6, 98):
        s.rect(x, 31, 8, 5, STONE_LIGHT)
        s.rect(x + 2, 27, 4, 4, INK)
        s.rect(x + 2, 50, 4, 13, GREEN)
    roof(s, 8, 8, 96, True)
    s.rect(50, 4, 12, 5, INK)
    s.rect(54, 0, 4, 5, GREEN)
    insignia(s, 50, 24)
    window(s, 24, 43)
    window(s, 76, 43)
    s.box(42, 54, 28, 35, SHADOW)
    s.rect(46, 59, 20, 26, METAL)
    s.rect(55, 59, 2, 26, INK)
    s.rect(49, 72, 3, 3, GOLD)
    s.rect(60, 72, 3, 3, GOLD)
    s.rect(38, 87, 36, 4, STONE_LIGHT)
    s.box(43, 36, 26, 13, INK)
    s.glyph('HQ', 51, 39, LIME)
    return s.file()


def cafeteria():
    s = Sprite('cafeteria', 96, 72)
    s.rect(8, 67, 80, 4, SHADOW)
    stone_wall(s, 7, 25, 82, 43)
    roof(s, 5, 6, 86, True)
    s.box(11, 35, 26, 19, SHADOW)
    s.rect(14, 38, 20, 10, WINDOW)
    s.rect(17, 48, 14, 3, METAL)
    s.box(60, 34, 23, 32, METAL)
    s.rect(68, 40, 7, 12, WINDOW)
    s.rect(65, 56, 13, 2, STEEL)
    s.rect(3, 26, 90, 3, GREEN)
    s.box(40, 32, 17, 10, INK)
    s.glyph('MESS', 42, 34, LIME)
    s.rect(39, 51, 16, 3, SHADOW)
    s.rect(43, 54, 8, 6, GOLD)
    for x in (44, 49):
        s.rect(x, 45, 1, 4, HIGHLIGHT)
    return s.file()


def armory():
    s = Sprite('weapons_storage', 96, 72)
    s.rect(6, 68, 84, 3, SHADOW)
    stone_wall(s, 7, 23, 82, 46)
    roof(s, 5, 4, 86)
    s.rect(9, 22, 78, 4, GREEN)
    s.box(28, 32, 42, 37, SHADOW)
    s.box(32, 35, 34, 32, METAL)
    s.rect(47, 35, 3, 32, INK)
    s.rect(37, 39, 2, 18, STEEL)
    s.rect(58, 39, 2, 18, STEEL)
    s.rect(40, 52, 6, 3, GOLD)
    s.rect(52, 52, 6, 3, GOLD)
    for x in (13, 77):
        s.box(x, 36, 9, 22, INK)
        s.rect(x + 3, 39, 3, 14, GREEN)
    s.box(28, 26, 40, 9, INK)
    s.glyph('ARM', 42, 28, LIME)
    s.rect(4, 61, 18, 6, DARK_SAND)
    s.rect(74, 61, 18, 6, DARK_SAND)
    return s.file()


def house(name, roof_green, right_door, window_count):
    s = Sprite(name, 64, 72)
    stone_wall(s, 4, 25, 56, 44)
    roof(s, 2, 6, 60, roof_green)
    s.rect(8, 66, 48, 4, SHADOW)
    door_x = 36 if right_door else 10
    s.box(door_x, 45, 16, 23, METAL)
    s.rect(door_x + 4, 49, 8, 8, DARK_GREEN)
    s.rect(door_x + (5 if right_door else 11), 59, 2, 2, GOLD)
    for x in ([13] if right_door else [38])[:window_count]:
        window(s, x, 34)
    if window_count == 2:
        window(s, 26, 34)
    s.rect(5, 69, 54, 2, STONE_LIGHT)
    return s.file()


def large_warship():
    s = Sprite('warship_flagship', 144, 72)
    s.rect(3, 49, 14, 15, INK)
    s.rect(5, 51, 9, 10, RUST)
    s.rect(0, 55, 6, 4, GOLD)
    s.rect(4, 29, 21, 7, INK)
    s.rect(9, 30, 15, 4, METAL)
    s.rect(18, 21, 104, 10, INK)
    s.rect(22, 23, 99, 7, STONE_LIGHT)
    s.rect(10, 30, 122, 34, INK)
    s.rect(13, 33, 117, 27, STEEL)
    s.rect(129, 34, 9, 23, INK)
    s.rect(132, 37, 7, 17, STEEL)
    s.rect(139, 42, 5, 8, GREEN)
    s.rect(18, 60, 99, 7, INK)
    s.rect(27, 63, 78, 5, METAL)
    s.rect(30, 27, 79, 6, DARK_GREEN)
    s.rect(34, 31, 71, 4, GREEN)
    s.rect(48, 20, 52, 7, INK)
    s.rect(54, 14, 39, 8, INK)
    s.rect(59, 16, 28, 6, WINDOW)
    s.rect(62, 22, 29, 7, METAL)
    s.rect(71, 16, 3, 7, SHADOW)
    for x in (35, 103):
        s.rect(x, 11, 6, 13, INK)
        s.rect(x + 2, 8, 3, 7, STEEL)
        s.rect(x + 2, 15, 1, 8, GREEN)
    for x in (26, 42, 108, 121):
        s.rect(x, 40, 8, 3, METAL)
        s.rect(x + 2, 42, 4, 2, WINDOW)
    s.rect(45, 50, 59, 3, DARK_GREEN)
    s.rect(55, 54, 39, 3, GREEN)
    insignia(s, 110, 48)
    return s.file()


def small_warship(name, variation):
    s = Sprite(name, 96, 56)
    s.rect(2, 40, 12, 11, INK)
    s.rect(4, 42, 7, 7, RUST)
    s.rect(0, 45, 5, 3, GOLD)
    s.rect(9, 19, 71, 7, INK)
    s.rect(15, 21, 61, 5, GREEN if variation else METAL)
    s.rect(8, 25, 76, 26, INK)
    s.rect(11, 28, 71, 20, STEEL)
    s.rect(82, 31, 10, 17, INK)
    s.rect(85, 34, 8, 10, STONE_LIGHT)
    s.rect(93, 37, 3, 4, LIME)
    s.rect(18, 48, 59, 5, SHADOW)
    s.rect(32, 13, 35, 9, INK)
    s.rect(38, 15, 23, 6, WINDOW)
    s.rect(46, 15, 2, 7, METAL)
    s.rect(28, 31, 45, 3, DARK_GREEN)
    s.rect(33, 34, 35, 2, LIME)
    if variation:
        s.rect(18, 10, 5, 16, INK)
        s.rect(20, 7, 2, 12, GOLD)
        s.rect(68, 11, 5, 15, INK)
        s.rect(70, 8, 2, 12, GOLD)
        s.rect(15, 41, 9, 3, RUST)
        s.rect(69, 41, 9, 3, RUST)
    else:
        s.rect(20, 16, 7, 10, INK)
        s.rect(22, 12, 3, 11, STEEL)
        s.rect(70, 15, 7, 11, INK)
        s.rect(72, 12, 3, 10, STEEL)
        insignia(s, 47, 37)
    return s.file()


def landing_pad(name, width, height, large):
    s = Sprite(name, width, height)
    s.box(1, 1, width - 2, height - 2, INK)
    s.rect(5, 5, width - 10, height - 10, METAL)
    s.rect(9, 9, width - 18, height - 18, SHADOW)
    s.rect(13, 13, width - 26, height - 26, STONE)
    for y in range(17, height - 14, 16):
        s.rect(13, y, width - 26, 1, STONE_LIGHT)
        for x in range(22 + (y % 32), width - 19, 33):
            s.rect(x, y + 1, 2, min(15, height - 14 - y), SHADOW)
    for x in range(21, width - 16, 24):
        s.rect(x, height // 2 - 2, 12, 4, HIGHLIGHT)
    for y in range(8, height - 4, 16):
        for x in (5, width - 9):
            s.rect(x, y, 4, 4, INK)
            s.rect(x + 1, y + 1, 2, 2, LIME)
    s.rect(14, 6, width - 28, 3, GREEN)
    s.rect(14, height - 9, width - 28, 3, GREEN)
    if large:
        s.glyph('A', 19, 18, HIGHLIGHT, 2)
    else:
        s.glyph('1' if name.endswith('one') else '2', 18, 17, HIGHLIGHT, 2)
    return s.file()


def arrow_target():
    s = Sprite('training_arrow_target', 32, 40)
    s.rect(14, 21, 4, 17, INK)
    s.rect(16, 25, 2, 10, DARK_SAND)
    s.rect(8, 37, 16, 2, DARK_SAND)
    s.box(4, 2, 24, 23, INK)
    s.rect(7, 5, 18, 17, HIGHLIGHT)
    s.rect(10, 7, 13, 13, RUST)
    s.rect(13, 10, 7, 7, HIGHLIGHT)
    s.rect(15, 12, 3, 3, GREEN)
    s.rect(14, 11, 1, 1, INK)
    s.rect(23, 13, 8, 2, DARK_SAND)
    s.rect(28, 11, 3, 2, STEEL)
    s.rect(28, 15, 3, 2, STEEL)
    return s.file()


def training_ground():
    s = Sprite('training_ground', 128, 80)
    s.box(0, 0, 128, 80, DARK_SAND, DARK_SAND, 1)
    s.rect(4, 4, 120, 72, SAND)
    for x, y, width in ((9, 13, 24), (56, 7, 21), (88, 58, 26), (16, 66, 19), (57, 49, 32)):
        s.rect(x, y, width, 2, DARK_SAND)
        s.rect(x + 3, y + 3, width // 2, 2, GOLD)
    for x in (14, 57, 100):
        s.rect(x, 41, 16, 3, STONE_LIGHT)
        s.rect(x + 3, 39, 4, 2, SHADOW)
        s.rect(x + 10, 37, 4, 2, SHADOW)
        s.rect(x + 6, 57, 5, 3, DARK_SAND)
    for y in (18, 34, 50, 66):
        s.rect(40, y, 3, 7, HIGHLIGHT)
        s.rect(84, y, 3, 7, HIGHLIGHT)
    for x in (2, 124):
        for y in (3, 74):
            s.rect(x, y, 2, 3, DARK_GREEN)
    return s.file()


def soldier():
    s = Sprite('confederation_soldier', 24, 32)
    s.rect(7, 29, 5, 3, INK)
    s.rect(14, 29, 5, 3, INK)
    s.rect(8, 22, 4, 7, DARK_GREEN)
    s.rect(15, 22, 4, 7, DARK_GREEN)
    s.rect(5, 13, 15, 12, INK)
    s.rect(7, 15, 11, 8, GREEN)
    s.rect(10, 15, 5, 7, LIME)
    s.rect(3, 15, 4, 8, DARK_GREEN)
    s.rect(19, 15, 3, 8, DARK_GREEN)
    s.rect(7, 21, 12, 3, SHADOW)
    s.rect(12, 21, 3, 3, GOLD)
    s.rect(7, 7, 12, 8, SAND)
    s.rect(8, 10, 2, 2, INK)
    s.rect(16, 10, 2, 2, INK)
    s.rect(6, 3, 14, 8, INK)
    s.rect(8, 3, 10, 5, GREEN)
    s.rect(10, 0, 6, 4, LIME)
    s.rect(11, 4, 4, 3, HIGHLIGHT)
    return s.file()


def officer():
    s = Sprite('confederation_officer', 24, 32)
    s.rect(5, 29, 6, 3, INK)
    s.rect(15, 29, 6, 3, INK)
    s.rect(7, 22, 4, 7, SHADOW)
    s.rect(15, 22, 4, 7, SHADOW)
    s.rect(4, 13, 17, 12, INK)
    s.rect(6, 15, 13, 9, DARK_GREEN)
    s.rect(9, 15, 7, 9, GREEN)
    s.rect(11, 17, 2, 7, HIGHLIGHT)
    s.rect(3, 15, 4, 5, GOLD)
    s.rect(18, 15, 4, 5, GOLD)
    s.rect(7, 21, 12, 3, INK)
    s.rect(11, 21, 4, 2, GOLD)
    s.rect(7, 7, 12, 8, SAND)
    s.rect(8, 10, 2, 2, INK)
    s.rect(16, 10, 2, 2, INK)
    s.rect(5, 4, 16, 6, INK)
    s.rect(7, 3, 12, 4, DARK_GREEN)
    s.rect(10, 1, 6, 4, GOLD)
    s.rect(11, 2, 4, 2, LIME)
    s.rect(4, 9, 18, 2, GREEN)
    return s.file()


def watchtower():
    s = Sprite('watchtower', 48, 80)
    s.rect(7, 75, 34, 4, SHADOW)
    for x in (12, 33):
        s.rect(x, 38, 4, 37, INK)
        s.rect(x + 1, 41, 2, 30, STONE_LIGHT)
    for y in (48, 60, 71):
        s.rect(12, y, 25, 2, SHADOW)
    s.box(4, 22, 40, 21, STONE)
    s.rect(7, 30, 34, 10, SHADOW)
    s.rect(13, 30, 22, 9, WINDOW)
    s.rect(17, 32, 2, 7, METAL)
    s.rect(29, 32, 2, 7, METAL)
    roof(s, 2, 2, 44, True)
    s.rect(22, 0, 2, 6, INK)
    s.rect(24, 0, 9, 5, GREEN)
    s.rect(27, 1, 2, 2, HIGHLIGHT)
    return s.file()


def base_gate():
    s = Sprite('base_gate', 64, 48)
    s.rect(2, 43, 60, 4, SHADOW)
    for x in (2, 50):
        stone_wall(s, x, 10, 12, 35)
        s.rect(x - 1, 7, 14, 5, INK)
        s.rect(x + 2, 8, 8, 2, GREEN)
    s.box(11, 3, 42, 11, METAL)
    s.rect(16, 6, 32, 4, GREEN)
    s.rect(25, 8, 13, 2, LIME)
    s.rect(14, 17, 36, 4, INK)
    s.rect(17, 19, 30, 2, STONE_LIGHT)
    for x in (19, 29, 39):
        s.rect(x, 21, 3, 19, METAL)
        s.rect(x + 1, 23, 1, 14, INK)
    return s.file()


def munitions_crate():
    s = Sprite('munitions_crate', 32, 32)
    s.rect(1, 27, 30, 3, SHADOW)
    s.box(3, 7, 26, 22, DARK_SAND)
    s.rect(5, 10, 22, 3, SAND)
    for x in (7, 23):
        s.rect(x, 10, 3, 16, METAL)
    s.rect(12, 13, 10, 9, INK)
    s.rect(13, 14, 8, 7, DARK_GREEN)
    s.rect(16, 15, 2, 5, LIME)
    s.rect(14, 17, 6, 2, LIME)
    s.rect(5, 24, 22, 2, RUST)
    return s.file()


def training_sandbags():
    s = Sprite('training_sandbags', 48, 24)
    s.rect(2, 20, 44, 3, DARK_SAND)
    for x in (4, 18, 32):
        s.box(x, 12, 13, 9, SAND, DARK_SAND, 1)
        s.rect(x + 3, 14, 5, 1, GOLD)
    for x in (10, 24):
        s.box(x, 4, 15, 9, SAND, DARK_SAND, 1)
        s.rect(x + 4, 6, 5, 1, GOLD)
    s.rect(3, 21, 43, 2, SHADOW)
    return s.file()


def write_contact_sheet(assets):
    card_width, card_height = 216, 162
    cols = 4
    rows = (len(assets) + cols - 1) // cols
    width, height = 928, 70 + rows * card_height + 34
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
             f'viewBox="0 0 {width} {height}" shape-rendering="crispEdges">',
             f'<rect width="{width}" height="{height}" fill="{INK}"/>',
             f'<text x="32" y="39" font-family="sans-serif" font-size="23" '
             f'font-weight="bold" fill="{HIGHLIGHT}">SPACE MILITARY BASE</text>',
             f'<text x="33" y="58" font-family="sans-serif" font-size="11" '
             f'fill="{STONE_LIGHT}">CAULIFLOWER CONFEDERATION   /   PIXEL ART CONCEPT   /   SPRITES AT NATIVE SIZE</text>']
    for i, sprite in enumerate(assets):
        col, row = i % cols, i // cols
        x, y = 28 + col * 224, 76 + row * card_height
        is_training = sprite.name in ('training_ground', 'training_arrow_target',
                                      'training_sandbags')
        ground = DARK_SAND if is_training else STONE
        detail = SAND if is_training else STONE_LIGHT
        parts.extend([f'<rect x="{x}" y="{y}" width="{card_width}" height="{card_height - 9}" '
                      f'fill="{SHADOW}" stroke="{METAL}" stroke-width="1"/>',
                      f'<rect x="{x + 9}" y="{y + 8}" width="{card_width - 18}" height="{card_height - 42}" '
                      f'fill="{ground}"/>'])
        for gx in range(x + 17, x + card_width - 12, 16):
            parts.append(f'<rect x="{gx}" y="{y + card_height - 62}" width="1" height="8" fill="{detail}"/>')
        raw = b64encode((BASE / f'{sprite.name}.png').read_bytes()).decode()
        ix = x + (card_width - sprite.width) // 2
        iy = y + 12 + (card_height - 49 - sprite.height) // 2
        parts.append(f'<image x="{ix}" y="{iy}" width="{sprite.width}" height="{sprite.height}" '
                     f'href="data:image/png;base64,{raw}"/>')
        label = sprite.name.replace('_', ' ').upper()
        parts.append(f'<text x="{x + 11}" y="{y + card_height - 21}" '
                     f'font-family="sans-serif" font-size="12" font-weight="bold" '
                     f'fill="{HIGHLIGHT}">{label}</text>')
        parts.append(f'<text x="{x + card_width - 12}" y="{y + card_height - 21}" '
                     f'text-anchor="end" font-family="monospace" font-size="10" '
                     f'fill="{STONE_LIGHT}">{sprite.width}×{sprite.height}</text>')
    parts.append('</svg>')
    svg = BASE / 'contact_sheet.svg'
    svg.write_text('\n'.join(parts) + '\n')
    subprocess.run(['convert', '-background', 'none', str(svg),
                    str(BASE / 'contact_sheet.png')], check=True)
    return svg


def write_scene_preview():
    def image(name, x, y):
        png = BASE / f'{name}.png'
        raw = b64encode(png.read_bytes()).decode()
        width, height = subprocess.check_output(
            ['identify', '-format', '%w %h', str(png)], text=True).split()
        return (f'<image x="{x}" y="{y}" width="{width}" height="{height}" '
                f'href="data:image/png;base64,{raw}"/>')

    pieces = ['<svg xmlns="http://www.w3.org/2000/svg" width="960" height="624" '
              'viewBox="0 0 960 624" shape-rendering="crispEdges">',
              f'<rect width="960" height="624" fill="{INK}"/>',
              f'<rect x="12" y="12" width="936" height="600" fill="{STONE}"/>']
    # Most of the base is paved. The staggered joints keep the courtyard legible
    # without adding visual clutter around the small character sprites.
    for y in range(12, 612, 32):
        pieces.append(f'<rect x="12" y="{y}" width="936" height="1" fill="{METAL}"/>')
        for x in range(12 + (y // 32 % 2) * 16, 948, 32):
            pieces.append(f'<rect x="{x}" y="{y}" width="1" height="32" fill="{METAL}"/>')
    for x, y, w, h, fill in ((72, 40, 216, 178, STONE_LIGHT),
                             (303, 43, 344, 162, STONE_LIGHT),
                             (42, 278, 463, 267, SAND),
                             (558, 262, 360, 275, METAL)):
        pieces.extend([f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{SHADOW}"/>',
                       f'<rect x="{x + 6}" y="{y + 6}" width="{w - 12}" height="{h - 12}" '
                       f'fill="{STONE}"/>',
                       f'<rect x="{x + 8}" y="{y + 8}" width="{w - 16}" height="{h - 16}" '
                       f'fill="{fill}"/>'])
    # The training ground is the only large earth patch; the apron stays metal.
    for i in range(22):
        x = 54 + (i * 139) % 440
        y = 289 + (i * 81) % 244
        pieces.append(f'<rect x="{x}" y="{y}" width="7" height="2" fill="{GOLD}"/>')
    for y in range(283, 533, 32):
        pieces.append(f'<rect x="566" y="{y}" width="344" height="1" fill="{STONE_LIGHT}"/>')
        for x in range(566 + (y // 32 % 2) * 16, 910, 32):
            pieces.append(f'<rect x="{x}" y="{y}" width="1" height="32" fill="{STONE}"/>')
    pieces.append(f'<rect x="544" y="218" width="6" height="42" fill="{LIME}"/>')
    pieces.append(f'<rect x="551" y="218" width="2" height="42" fill="{SHADOW}"/>')
    placements = [
        ('headquarters', 107, 70), ('weapons_storage', 318, 71),
        ('cafeteria', 460, 73), ('barracks_a', 673, 64),
        ('barracks_b', 750, 80), ('barracks_c', 827, 64),
        ('watchtower', 25, 26), ('watchtower', 903, 26),
        ('training_ground', 94, 362), ('training_ground', 246, 362),
        ('training_arrow_target', 117, 329), ('training_arrow_target', 264, 329),
        ('training_arrow_target', 390, 329),
        ('training_sandbags', 404, 456), ('munitions_crate', 365, 157),
        ('munitions_crate', 403, 157), ('base_gate', 448, 228),
        ('confederation_soldier', 196, 461), ('confederation_soldier', 360, 462),
        ('confederation_soldier', 533, 179), ('confederation_soldier', 874, 482),
        ('confederation_officer', 225, 179),
        ('landing_pad_flagship', 557, 263), ('landing_pad_one', 582, 428),
        ('landing_pad_two', 748, 428),
        ('warship_flagship', 565, 275), ('warship_scout', 590, 434),
        ('warship_escort', 756, 434),
    ]
    pieces.extend(image(name, x, y) for name, x, y in placements)
    pieces.append(f'<rect x="20" y="574" width="920" height="29" fill="{INK}"/>')
    pieces.append(f'<text x="33" y="594" font-family="sans-serif" font-size="14" '
                  f'fill="{HIGHLIGHT}">SPACE MILITARY BASE  •  CONCEPT ONLY  •  NOT A PLAYABLE MAP</text>')
    pieces.append('</svg>')
    svg = BASE / 'scene_concept.svg'
    svg.write_text('\n'.join(pieces) + '\n')
    subprocess.run(['convert', '-background', 'none', str(svg),
                    str(BASE / 'scene_concept.png')], check=True)


def main():
    assets = [headquarters(), cafeteria(), armory(),
              house('barracks_a', True, False, 1),
              house('barracks_b', False, True, 2),
              house('barracks_c', True, True, 1),
              large_warship(), small_warship('warship_scout', False),
              small_warship('warship_escort', True),
              landing_pad('landing_pad_flagship', 160, 96, True),
              landing_pad('landing_pad_one', 112, 64, False),
              landing_pad('landing_pad_two', 112, 64, False),
              training_ground(), arrow_target(), soldier(), officer(), watchtower(),
              base_gate(), munitions_crate(), training_sandbags()]
    write_contact_sheet(assets)
    write_scene_preview()
    print(f'Created {len(assets)} editable SVG sprites and PNG exports, contact sheet, and scene concept in {BASE}')


if __name__ == '__main__':
    main()
