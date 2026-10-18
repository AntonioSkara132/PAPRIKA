#!/usr/bin/python3
"""Draw Iskra's investigation rooms and original-size characters."""
from pathlib import Path
import json
import math

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art/iskra/investigation"
SOURCE = ROOT / "art/concepts/source"
MILITARY = ROOT / "assets/art/space_military_base"
INK = (28, 23, 48)
BRASS = (190, 143, 73)
CREAM = (241, 220, 171)
FLOOR = (88, 65, 51)
PLANK = (66, 49, 43)
WALL = (50, 43, 44)
GREEN = (88, 116, 73)
RED = (149, 57, 64)
SILVER = (192, 204, 197)
FONT = ImageFont.load_default()

# World rectangles match iskra_investigation_data.gd. Artwork and local geometry use 2x smaller pixels.
ROOMS = {
    "hall": (2112, 2816, 640, 352),
    "owner": (2816, 2816, 640, 352),
    "neighbor": (2816, 3232, 384, 256),
    "squirrel": (64, 3392, 896, 544),
    "pelican": (1056, 3392, 896, 544),
    "board": (3264, 3216, 1088, 800),
}
WALLS = {
    "hall": [(96, 8, 8, 64), (96, 120, 8, 48), (216, 64, 8, 104)],
    "owner": [(104, 8, 8, 56), (104, 112, 8, 56), (112, 104, 96, 8), (208, 8, 8, 56)],
    "neighbor": [],
    "squirrel": [(144, 8, 8, 144), (144, 200, 8, 64), (8, 152, 88, 8),
                 (256, 8, 8, 96), (264, 144, 104, 8), (152, 144, 56, 8)],
    "pelican": [(136, 8, 8, 112), (136, 176, 8, 88), (272, 104, 8, 160), (144, 104, 80, 8)],
}
FURNITURE = {
    "hall": [(16, 72, 40, 24), (128, 136, 64, 16), (240, 88, 32, 24), (72, 136, 8, 16)],
    "owner": [(16, 16, 32, 48), (128, 16, 64, 24), (224, 16, 56, 16),
              (224, 112, 64, 24), (232, 80, 32, 16), (24, 112, 48, 16)],
    "neighbor": [(20, 18, 26, 42), (144, 18, 26, 42), (68, 20, 40, 16), (136, 88, 32, 16)],
    "squirrel": [(24, 16, 80, 24), (40, 64, 64, 24), (184, 16, 40, 24),
                 (272, 20, 24, 48), (312, 20, 96, 24), (224, 224, 64, 24), (248, 184, 48, 16)],
    "pelican": [(32, 16, 80, 24), (24, 168, 56, 32), (168, 16, 64, 24),
                (320, 184, 80, 24), (168, 208, 64, 24)],
}
# Native coordinates are centred on navigation tiles (4 mod 8).
POINTS = {
    "hall": {"arrival": (44, 132), "room12": (44, 44), "exit": (20, 148), "neighbor": (156, 44),
             "attacker": (76, 84), "flee_0": (132, 92), "flee_1": (196, 36), "flee_2": (268, 36),
             "escape": (292, 148), "evidence": (276, 140)},
    "owner": {"arrival": (44, 140), "exit": (20, 148), "person": (276, 68), "desk": (244, 44)},
    "neighbor": {"arrival": (76, 100), "exit": (92, 116), "record": (92, 52)},
    "squirrel": {"arrival": (52, 228), "exit": (20, 244), "boss": (364, 60), "handler": (292, 76),
                 # Guards ring Sena so a direct attack is met by all six at once.
                 "record": (396, 100), "guard_0": (332, 68), "guard_1": (396, 68),
                 "guard_2": (324, 100), "guard_3": (420, 92), "guard_4": (348, 124),
                 "guard_5": (380, 124), "ally_0": (36, 196), "ally_1": (68, 196), "ally_2": (100, 228)},
    # Roko waits in the far corner from the entrance; six guards hold the rooms in between.
    "pelican": {"arrival": (52, 228), "exit": (20, 244), "boss": (76, 60), "hacker": (412, 60),
                "guard_0": (108, 132), "guard_1": (220, 156), "guard_2": (356, 148),
                "guard_3": (84, 92), "guard_4": (196, 132), "guard_5": (308, 124),
                "ally_0": (36, 212), "ally_1": (68, 212), "ally_2": (100, 228)},
}
# Existing unnamed buildings become accessible; their geometry is unchanged.
EXTERIOR_POINTS = {
    "inv_owner_entry": (330, 1232),
    "inv_pelican_entry": (1178, 1122),
    "inv_squirrel_entry": (1682, 1200),
    "inv_rendezvous": (1096, 1000),
    "inv_rendezvous_ally_0": (1080, 1000),
    "inv_rendezvous_ally_1": (1112, 1000),
    "inv_rendezvous_ally_2": (1096, 1016),
}
SIGNS = {"owner": ("FLAT 4", BRASS), "squirrel": ("SQUIRRELS", GREEN), "pelican": ("PELICANS", RED)}
VARIANTS = [
    ("police_attacker", "Police coat", MILITARY / "station_soldier_1.png", (73, 106, 71), (54, 65, 82), BRASS),
    ("uniform_owner", "Uniform owner", SOURCE / "villager6.png", (141, 89, 111), (126, 118, 99), (60, 67, 78)),
    ("squirrel_boss", "Squirrel boss", SOURCE / "villager4.png", (95, 138, 86), (61, 77, 56), (210, 169, 83)),
    ("pelican_boss", "Pelican boss", SOURCE / "villager5.png", (178, 122, 78), (115, 48, 61), (227, 198, 149)),
    ("pelican_hacker", "Roko - hacker", SOURCE / "villager1.png", (154, 94, 85), (58, 43, 57), (172, 66, 63)),
    ("contract_handler", "Contract handler", SOURCE / "villager2.png", (86, 122, 155), (126, 82, 52), (67, 91, 108)),
    ("squirrel_guard", "Squirrel guard", SOURCE / "villager3.png", (133, 112, 165), (67, 91, 64), (178, 164, 119)),
    ("squirrel_tv_guard", "Tvrdium guard", MILITARY / "station_soldier_2.png", (82, 109, 76), (68, 87, 62), SILVER),
    ("pelican_guard", "Pelican guard", MILITARY / "station_soldier_1.png", (73, 106, 71), (134, 52, 58), (211, 180, 126)),
]
CYAN = (98, 226, 214)
SKIN = (220, 167, 120)
COPPER = (168, 98, 58)
GOLD = (232, 190, 82)
# The Board and their guests wear long tailored coats over the original villager bodies.
BOARD_OUTFITS = [
    ("board_nation", "Head of Nation", SOURCE / "villager6.png", (226, 222, 208), COPPER, CYAN),
    ("board_technology", "Head of Technology", SOURCE / "villager1.png", (52, 58, 70), BRASS, CYAN),
    ("board_architecture", "Head of Architecture", SOURCE / "villager2.png", (52, 90, 148), (214, 226, 236), CYAN),
    ("board_navy", "Head of Navy", SOURCE / "villager3.png", (32, 42, 76), GOLD, CYAN),
    ("board_demographics", "Head of Demographics", SOURCE / "villager4.png", (42, 118, 116), SILVER, CYAN),
    ("board_finance", "Head of Finance", SOURCE / "villager5.png", (114, 34, 52), GOLD, CYAN),
    ("board_defense", "Head of Defense", SOURCE / "villager1.png", (70, 80, 76), SILVER, CYAN),
    ("cauliflower_secretary", "Iva Most", SOURCE / "villager4.png", (157, 204, 134), (112, 150, 94), CREAM),
    ("diplomatic_secretary", "Diplomatic Secretary", SOURCE / "villager2.png", (82, 64, 98), BRASS, CYAN),
]

# The Board chamber is a domed oval with a horseshoe table; the MC and Davor stand in its open end.
BOARD_CENTRE = (272, 176)
BOARD_DOME = (196, 132)
BOARD_TABLE = (112, 76)
BOARD_TABLE_INNER = (64, 40)
BOARD_GAP = 40
BOARD_SEATS = {"nation": 270, "technology": 228, "architecture": 312, "navy": 186,
               "demographics": 354, "finance": 144, "defense": 36}
BOARD_SPACES = {"gallery": (168, 16, 376, 52), "waiting": (16, 128, 84, 224), "cloaks": (112, 264, 176, 344),
                "archive": (368, 264, 432, 344), "passage": (256, 296, 288, 320), "lobby": (224, 320, 320, 384)}


def _inside(x, y, radii, centre=BOARD_CENTRE):
    return ((x-centre[0])/radii[0])**2 + ((y-centre[1])/radii[1])**2 <= 1


def _board_floor(x, y):
    return _inside(x, y, BOARD_DOME) or any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in BOARD_SPACES.values())


def _board_table(x, y):
    cx, cy = BOARD_CENTRE
    if _inside(x, y, (24, 16)):
        return True
    in_ring = _inside(x, y, BOARD_TABLE) and not _inside(x, y, BOARD_TABLE_INNER)
    return in_ring and not (y > cy and abs(x-cx) < BOARD_GAP)


def _seat(angle, rx, ry):
    a = math.radians(angle)
    x = BOARD_CENTRE[0] + rx*math.cos(a)
    y = BOARD_CENTRE[1] + ry*math.sin(a)
    return int(x)//8*8+4, int(y)//8*8+4


def _runs(test, w, h):
    rects = []
    for y in range(8, h-8, 8):
        start = None
        for x in range(8, w-8+8, 8):
            hit = x < w-8 and test(x+4, y+4)
            if hit and start is None:
                start = x
            elif not hit and start is not None:
                rects.append((start, y, x-start, 8))
                start = None
    return rects


def _board_layout():
    w, h = ROOMS["board"][2]//2, ROOMS["board"][3]//2
    walls = _runs(lambda x, y: not _board_floor(x, y), w, h)
    chairs = []
    for angle in BOARD_SEATS.values():
        x, y = _seat(angle, 150, 108)
        chairs.append((x-12, y-12, 16, 16))
    furniture = _runs(lambda x, y: _board_floor(x, y) and _board_table(x, y), w, h) + chairs + [
        (192, 16, 32, 8), (320, 16, 32, 8),    # gallery benches under the windows
        (16, 136, 16, 24), (16, 192, 16, 24),  # waiting-alcove benches
        (64, 128, 16, 8), (64, 216, 16, 8),    # potted ferns
        (112, 328, 24, 16), (152, 272, 24, 8),  # coat rack and cloak chest
        (408, 272, 24, 16), (408, 320, 24, 24),  # archive shelves and terminal
        (224, 320, 8, 16), (312, 320, 8, 16),  # lobby planters
    ]
    points = {"arrival": (268, 356), "exit": (268, 372), "mc_stand": (252, 212), "davor_stand": (292, 212),
              "cauliflower_secretary": (180, 268), "diplomatic_secretary": (364, 268)}
    for name, angle in BOARD_SEATS.items():
        points[name] = _seat(angle, 128, 92)
    return walls, furniture, points


WALLS["board"], FURNITURE["board"], POINTS["board"] = _board_layout()


def _box(draw, rect, fill, outline=INK):
    x, y, w, h = rect
    draw.rectangle((x, y, x+w-1, y+h-1), fill=fill, outline=outline)


def _table(draw, rect, papers=False):
    x, y, w, h = rect
    _box(draw, rect, (122, 81, 48))
    draw.line((x+2, y+2, x+w-3, y+2), fill=BRASS)
    draw.line((x+2, y+h-4, x+w-3, y+h-4), fill=(76, 49, 36))
    for px in (x+3, x+w-5):
        draw.line((px, y+h-3, px, y+h-1), fill=INK, width=2)
    if papers:
        for px in range(x+6, x+w-10, 22):
            draw.rectangle((px, y+5, px+9, y+11), fill=CREAM, outline=(163, 142, 106))
            draw.line((px+2, y+7, px+7, y+7), fill=(96, 83, 71))
            draw.line((px+2, y+9, px+6, y+9), fill=(96, 83, 71))
        draw.ellipse((x+w-13, y+5, x+w-8, y+10), fill=BRASS, outline=INK)


def _shelf(draw, rect, clothes=False):
    x, y, w, h = rect
    _box(draw, rect, (83, 61, 45))
    for yy in range(y+4, y+h-3, 8):
        for xx in range(x+4, x+w-5, 10):
            color = CREAM if clothes else ((108, 126, 90) if (xx//10) % 2 else (148, 92, 63))
            draw.rectangle((xx, yy, xx+6, min(yy+4, y+h-3)), fill=color, outline=(63, 52, 43))
        draw.line((x+2, yy+5, x+w-3, yy+5), fill=BRASS)


def _bed(draw, rect, cover=(91, 124, 110)):
    x, y, w, h = rect
    _box(draw, rect, (68, 43, 34))
    draw.rectangle((x+3, y+4, x+w-4, y+12), fill=CREAM, outline=INK)
    draw.rectangle((x+3, y+14, x+w-4, y+h-5), fill=cover, outline=INK)
    draw.line((x+6, y+16, x+6, y+h-7), fill=(148, 171, 131))


def _sofa(draw, rect, color):
    x, y, w, h = rect
    _box(draw, rect, color)
    draw.rectangle((x+3, y+3, x+w-4, y+7), outline=BRASS)
    for xx in range(x+6, x+w-8, 16):
        draw.rectangle((xx, y+10, min(xx+12, x+w-6), y+h-5), outline=INK)


def _crate(draw, rect):
    x, y, w, h = rect
    _box(draw, rect, (111, 75, 46))
    draw.rectangle((x+3, y+3, x+w-4, y+h-4), outline=BRASS)
    draw.line((x+3, y+3, x+w-4, y+h-4), fill=BRASS)
    draw.line((x+w-4, y+3, x+3, y+h-4), fill=BRASS)


def _door(draw, x, y, label):
    draw.rectangle((x-12, y, x+12, y+20), fill=(74, 49, 39), outline=BRASS)
    draw.rectangle((x-9, y+3, x+9, y+16), outline=INK)
    draw.point((x+7, y+12), fill=CREAM)
    if label:
        box = draw.textbbox((0, 0), label, font=FONT)
        draw.text((x-(box[2]-box[0])//2, y+2), label, font=FONT, fill=CREAM)


def room_image(name):
    if name == "board":
        return _board_image()
    _, _, world_w, world_h = ROOMS[name]
    w, h = world_w//2, world_h//2
    image = Image.new("RGBA", (w, h), INK)
    draw = ImageDraw.Draw(image)
    draw.rectangle((8, 8, w-9, h-9), fill=FLOOR, outline=BRASS)
    for y in range(12, h-8, 8):
        draw.line((9, y, w-10, y), fill=PLANK)
        for x in range(12+(y%16)*2, w-10, 32):
            draw.line((x, y, x, min(y+7, h-10)), fill=PLANK)
    for x in range(16, w-12, 64):
        draw.rectangle((x, 9, x+4, 12), fill=(253, 204, 112), outline=(126, 88, 50))
        draw.line((x+1, 14, x+3, 14), fill=(141, 103, 60))
    if name == "hall":
        draw.rectangle((60, 76, 208, 116), fill=(104, 61, 62), outline=(170, 117, 74))
        draw.rectangle((108, 80, 204, 112), outline=(149, 99, 68))
        _shelf(draw, FURNITURE[name][0], True)
        _sofa(draw, FURNITURE[name][1], (96, 65, 65))
        _shelf(draw, FURNITURE[name][2], True)
        draw.rectangle((73, 143, 78, 151), fill=(117, 75, 50), outline=INK)
        draw.ellipse((71, 135, 79, 145), fill=GREEN, outline=INK)
        for x, number in ((44, "12"), (156, "13"), (268, "14")):
            _door(draw, x, 12, number)
        for x in (20, 292):
            for yy in range(152, 166, 3):
                draw.line((x-10, yy, x+10, yy), fill=BRASS)
        draw.text((11, 133), "DESK", fill=CREAM, font=FONT)
        draw.text((269, 133), "STAIRS", fill=CREAM, font=FONT)
    elif name == "owner":
        _bed(draw, FURNITURE[name][0], (84, 98, 119))
        _shelf(draw, FURNITURE[name][1])
        _table(draw, FURNITURE[name][2], True)
        _sofa(draw, FURNITURE[name][3], (78, 103, 92))
        _table(draw, FURNITURE[name][4], True)
        _crate(draw, FURNITURE[name][5])
        draw.rectangle((56, 18, 72, 23), fill=(48, 50, 62), outline=BRASS)
        for x in (59, 65, 70):
            draw.line((x, 22, x, 30), fill=BRASS)
        draw.line((60, 27, 60, 42), fill=(52, 67, 84), width=5)
        draw.rectangle((130, 19, 143, 34), fill=(101, 107, 94), outline=INK)
        draw.ellipse((132, 22, 141, 31), outline=CREAM)
        _door(draw, 20, 146, "")
    elif name == "neighbor":
        _bed(draw, FURNITURE[name][0])
        _bed(draw, FURNITURE[name][1])
        _table(draw, FURNITURE[name][2], True)
        _crate(draw, FURNITURE[name][3])
        draw.rectangle((60, 64, 120, 108), fill=(95, 62, 69), outline=(171, 125, 75))
        draw.rectangle((64, 68, 116, 104), outline=(145, 104, 71))
        for x in (76, 96):
            draw.ellipse((x, 23, x+4, 27), fill=BRASS, outline=INK)
        _door(draw, 92, 107, "")
    else:
        accent = GREEN if name == "squirrel" else RED
        draw.rectangle((156, 120, 248, 136), fill=accent, outline=BRASS)
        if name == "squirrel":
            _shelf(draw, FURNITURE[name][0])
            _table(draw, FURNITURE[name][1])
            _shelf(draw, FURNITURE[name][2])
            _shelf(draw, FURNITURE[name][3])
            _table(draw, FURNITURE[name][4], True)
            _sofa(draw, FURNITURE[name][5], accent)
            _table(draw, FURNITURE[name][6])
            # Three bright blades on the rack match the guards' equipment.
            for x in (277, 284, 291):
                draw.line((x, 26, x, 59), fill=SILVER, width=2)
                draw.line((x-2, 53, x+2, 53), fill=BRASS)
            draw.rectangle((380, 84, 405, 88), fill=(120, 80, 47), outline=INK)
            draw.rectangle((390, 82, 401, 86), fill=CREAM, outline=(133, 110, 76))
        else:
            _table(draw, FURNITURE[name][0], True)
            _crate(draw, FURNITURE[name][1])
            _shelf(draw, FURNITURE[name][2])
            _table(draw, FURNITURE[name][3])
            _sofa(draw, FURNITURE[name][4], accent)
            draw.ellipse((308, 28, 412, 120), outline=(176, 126, 72), width=2)
            draw.ellipse((316, 36, 404, 112), outline=(112, 79, 60))
            for x in (324, 388):
                draw.line((x, 188, x+11, 199), fill=SILVER, width=2)
                draw.line((x+2, 194, x+7, 189), fill=BRASS)
        _door(draw, 20, h-24, "")
        for y in range(48, h-24, 48):
            draw.rectangle((w-14, y, w-10, y+4), fill=(253, 204, 112))
    for rect in WALLS[name]:
        x, y, ww, hh = rect
        _box(draw, rect, WALL)
        draw.line((x+1, y+1, x+ww-2, y+1), fill=BRASS)
        draw.line((x+1, y+1, x+1, y+hh-2), fill=(129, 94, 64))
        for yy in range(y+8, y+hh, 8):
            draw.line((x+2, yy, x+ww-2, yy), fill=(76, 59, 51))
    title = {"hall": "KINOVA / CORRIDOR", "owner": "FLAT 4", "neighbor": "KINOVA / 13",
             "squirrel": "GREEN SQUIRRELS", "pelican": "RED PELICANS"}[name]
    box = draw.textbbox((0, 0), title, font=FONT)
    x = (w-box[2])//2
    draw.rectangle((x-6, 1, x+box[2]+5, 13), fill=INK, outline=BRASS)
    draw.text((x, 2), title, font=FONT, fill=CREAM)
    return image


def npc(role):
    if any(outfit[0] == role for outfit in BOARD_OUTFITS):
        return _board_npc(role)
    entry = next(v for v in VARIANTS if v[0] == role)
    _, _, source, old, color, trim = entry
    with Image.open(source) as image:
        sprite = image.convert("RGBA")
    alpha = sprite.getchannel("A")
    px = sprite.load()
    for y in range(9, 18):
        for x in range(16):
            if px[x, y] == (*old, 255):
                px[x, y] = (*color, 255)
            elif source.parent == MILITARY and px[x, y][:3] in [(155, 181, 104), (192, 162, 91)] and px[x, y][3]:
                px[x, y] = (*trim, 255)
    draw = ImageDraw.Draw(sprite)
    if role in ("squirrel_boss", "pelican_boss"):
        draw.line((5, 10, 7, 12), fill=trim)
        draw.line((10, 10, 8, 12), fill=trim)
        draw.line((8, 13, 8, 15), fill=INK)
        draw.point((9, 14), fill=BRASS)
    elif role == "pelican_hacker":
        for y in range(2, 5):
            for x in range(5, 11):
                if px[x, y][3] and px[x, y][:3] != INK:
                    px[x, y] = (181, 180, 169, 255)
        draw.line((5, 10, 10, 10), fill=trim)
        draw.line((5, 11, 5, 15), fill=trim)
        draw.point([(7, 11), (9, 11)], fill=SILVER)
    elif role == "contract_handler":
        draw.line((5, 10, 5, 14), fill=trim)
        draw.line((10, 10, 10, 14), fill=trim)
        draw.point((9, 12), fill=CREAM)
    elif role == "squirrel_guard":
        draw.rectangle((5, 11, 6, 12), fill=trim)
        draw.point([(9, 14), (10, 14)], fill=BRASS)
    elif role == "uniform_owner":
        draw.line((5, 10, 10, 10), fill=trim)
        draw.line((8, 11, 8, 14), fill=trim)
    elif role == "squirrel_tv_guard":
        draw.line((5, 10, 6, 10), fill=SILVER)
        draw.line((9, 10, 10, 10), fill=SILVER)
    draw.line((5, 15, 10, 15), fill=INK)
    draw.point((8, 15), fill=trim)
    sprite.putalpha(alpha)
    return sprite


def _ellipse(draw, radii, fill=None, outline=None, width=1, centre=BOARD_CENTRE):
    cx, cy = centre
    rx, ry = radii
    draw.ellipse((cx-rx, cy-ry, cx+rx, cy+ry), fill=fill, outline=outline, width=width)


def _arc_point(angle, radii, centre=BOARD_CENTRE):
    a = math.radians(angle)
    return round(centre[0]+radii[0]*math.cos(a)), round(centre[1]+radii[1]*math.sin(a))


def _plant(draw, x, y):
    draw.rectangle((x+3, y+10, x+12, y+15), fill=(117, 75, 50), outline=INK)
    draw.line((x+4, y+11, x+11, y+11), fill=BRASS)
    for dx, dy in ((2, 2), (7, 0), (11, 3), (4, 6), (9, 6)):
        draw.ellipse((x+dx-2, y+dy-1, x+dx+3, y+dy+4), fill=GREEN, outline=INK)
    draw.point([(x+7, y+2), (x+4, y+7)], fill=(148, 171, 131))


def _bench(draw, rect, color):
    x, y, w, h = rect
    _box(draw, rect, (96, 66, 46))
    draw.rectangle((x+2, y+2, x+w-3, y+h-3), fill=color, outline=BRASS)


def _board_image():
    _, _, world_w, world_h = ROOMS["board"]
    w, h = world_w//2, world_h//2
    image = Image.new("RGBA", (w, h), INK)
    draw = ImageDraw.Draw(image)
    cx, cy = BOARD_CENTRE
    # Wall mass with brass pipe runs and rivets between the rooms.
    draw.rectangle((4, 4, w-5, h-5), fill=WALL, outline=BRASS)
    for y in range(12, h-8, 10):
        draw.line((6, y, w-7, y), fill=(58, 49, 49))
    for y, x0, x1 in ((246, 8, 104), (256, 8, 104), (356, 184, 216), (356, 328, 360), (250, 440, 536)):
        draw.line((x0, y, x1, y), fill=COPPER, width=3)
        draw.line((x0, y-1, x1, y-1), fill=(214, 150, 96))
        for x in range(x0+6, x1, 18):
            draw.rectangle((x, y-2, x+2, y+2), fill=BRASS, outline=INK)
    # City Computer behind a curved glass wall on the east side.
    draw.rectangle((470, 92, 538, 262), fill=(22, 30, 38), outline=BRASS)
    for y in range(102, 252, 22):
        draw.rectangle((492, y, 532, y+12), fill=(40, 48, 56), outline=INK)
        for x in range(495, 530, 6):
            draw.rectangle((x, y+2, x+3, y+5), fill=CYAN if (x+y) % 3 else (54, 120, 126))
            draw.point((x+1, y+9), fill=(253, 204, 112) if (x//6+y) % 4 == 0 else (84, 150, 96))
    draw.line((482, 100, 482, 254), fill=(54, 120, 126))
    draw.text((486, 84), "CITY", font=FONT, fill=CYAN)
    # Window gallery: tall panes onto the lamps and canals of Iskra.
    gx0, gy0, gx1, gy1 = BOARD_SPACES["gallery"]
    draw.rectangle((gx0-4, gy0-4, gx1+12, gy1+8), fill=PLANK, outline=BRASS)
    for x in range(gx0, gx1+8, 42):
        draw.rectangle((x, 5, x+36, 15), fill=(26, 34, 66), outline=BRASS)
        draw.line((x+1, 12, x+35, 13), fill=(54, 120, 150))
        for lx in range(x+3, x+34, 7):
            draw.point((lx, 8+(lx % 3)), fill=(253, 204, 112))
        draw.line((x+18, 5, x+18, 15), fill=BRASS)
    for x in range(gx0, gx1+8, 16):
        draw.line((x, gy0, x, gy1+6), fill=(84, 61, 48))
    # The small rooms around the dome: waiting alcove, cloakroom, archive and lift lobby.
    carpets = {"waiting": (95, 62, 69), "cloaks": (78, 103, 92), "archive": (84, 98, 119), "passage": FLOOR, "lobby": FLOOR}
    for key, color in carpets.items():
        x0, y0, x1, y1 = BOARD_SPACES[key]
        draw.rounded_rectangle((x0-4, y0-4, x1+11, y1+11), radius=6, fill=FLOOR, outline=BRASS)
        if key in ("waiting", "cloaks", "archive"):
            draw.rounded_rectangle((x0+4, y0+4, x1+3, y1+3), radius=4, fill=color, outline=(171, 125, 75))
    for y in range(BOARD_SPACES["lobby"][1], BOARD_SPACES["lobby"][3]+8, 8):
        draw.line((BOARD_SPACES["lobby"][0], y, BOARD_SPACES["lobby"][2]+8, y), fill=PLANK)
    # Like the top of a Tesla tower: a copper ring around the dome and a lattice frame carrying it.
    _ellipse(draw, (BOARD_DOME[0]+5, BOARD_DOME[1]+5), fill=(46, 39, 41), outline=BRASS, width=2)
    _ellipse(draw, BOARD_DOME, fill=(70, 55, 50))
    for scale in (0.9, 0.78, 0.64):
        _ellipse(draw, (int(BOARD_DOME[0]*scale), int(BOARD_DOME[1]*scale)), outline=(92, 70, 58))
    for angle in range(15, 375, 30):
        inner, outer = (BOARD_TABLE[0]+6, BOARD_TABLE[1]+4), (BOARD_DOME[0]-4, BOARD_DOME[1]-4)
        rails = [(_arc_point(angle+side, inner), _arc_point(angle+side*0.6, outer)) for side in (-2.5, 2.5)]
        for start, end in rails:
            draw.line((start, end), fill=(98, 74, 58))
        for i in range(6):
            t0, t1 = i/6, (i+1)/6
            a = rails[i % 2]
            b = rails[(i+1) % 2]
            p0 = (a[0][0]+(a[1][0]-a[0][0])*t0, a[0][1]+(a[1][1]-a[0][1])*t0)
            p1 = (b[0][0]+(b[1][0]-b[0][0])*t1, b[0][1]+(b[1][1]-b[0][1])*t1)
            draw.line((p0, p1), fill=(86, 66, 56))
    _ellipse(draw, BOARD_DOME, outline=COPPER, width=4)
    _ellipse(draw, (BOARD_DOME[0]-1, BOARD_DOME[1]-1), outline=(214, 150, 96))
    _ellipse(draw, (BOARD_DOME[0]-3, BOARD_DOME[1]-3), outline=(110, 62, 40))
    # A runner leads from the lift to the open end of the table, where guests stand.
    draw.rectangle((cx-14, cy+56, cx+13, 330), fill=(114, 34, 52), outline=BRASS)
    for y in range(cy+62, 326, 10):
        draw.line((cx-10, y, cx+9, y), fill=(150, 64, 70))
    # Glass panels where the dome meets the computer room.
    for angle in range(-36, 40, 4):
        draw.point(_arc_point(angle, BOARD_DOME), fill=CYAN)
        draw.point(_arc_point(angle, (BOARD_DOME[0]-2, BOARD_DOME[1]-2)), fill=(162, 236, 228))
    for angle in range(0, 360, 24):
        x, y = _arc_point(angle, (BOARD_DOME[0]-6, BOARD_DOME[1]-6))
        if not -40 < ((angle+180) % 360)-180 < 40:
            draw.ellipse((x-2, y-2, x+2, y+2), fill=(253, 204, 112), outline=(126, 88, 50))
    # Raised seats on a dais behind the table, each with a cyan desk screen.
    _ellipse(draw, (BOARD_TABLE[0]+44, BOARD_TABLE[1]+40), outline=(120, 82, 56), width=3)
    seat_colors = {"nation": (226, 222, 208), "technology": (52, 58, 70), "architecture": (52, 90, 148), "navy": (32, 42, 76),
                   "demographics": (42, 118, 116), "finance": (114, 34, 52), "defense": (70, 80, 76)}
    for name, angle in BOARD_SEATS.items():
        x, y = _seat(angle, 150, 108)
        x0, y0 = x-12, y-12
        draw.rounded_rectangle((x0-2, y0-2, x0+17, y0+17), radius=4, fill=(96, 66, 46), outline=INK)
        draw.rounded_rectangle((x0+2, y0+1, x0+13, y0+14), radius=3, fill=seat_colors[name], outline=BRASS)
        draw.rectangle((x0+4, y0+4, x0+11, y0+8), outline=(214, 150, 96))
        if name == "nation":
            draw.polygon([(x0+7, y0-5), (x0+9, y0-1), (x0+5, y0-1)], fill=GOLD, outline=INK)
            draw.line((x0+8, y0+5, x0+6, y0+7, x0+9, y0+7, x0+7, y0+10), fill=(253, 204, 112))
    # Horseshoe table in copper, open to the south, around the brass model of the five planets.
    table = Image.new("L", (w, h), 0)
    tdraw = ImageDraw.Draw(table)
    _ellipse(tdraw, BOARD_TABLE, fill=255)
    _ellipse(tdraw, BOARD_TABLE_INNER, fill=0)
    tdraw.rectangle((cx-BOARD_GAP, cy+8, cx+BOARD_GAP-1, cy+BOARD_TABLE[1]+2), fill=0)
    copper = Image.new("RGBA", (w, h), (*COPPER, 255))
    image.paste(copper, (0, 0), table)
    edges = Image.new("L", (w, h), 0)
    edraw = ImageDraw.Draw(edges)
    _ellipse(edraw, BOARD_TABLE, outline=255)
    _ellipse(edraw, (BOARD_TABLE[0]-6, BOARD_TABLE[1]-5), outline=255)
    _ellipse(edraw, BOARD_TABLE_INNER, outline=255)
    edges = Image.composite(edges, Image.new("L", (w, h), 0), table)
    image.paste(Image.new("RGBA", (w, h), (*BRASS, 255)), (0, 0), edges)
    for side in (-1, 1):
        x = cx+side*BOARD_GAP-(1 if side > 0 else 0)
        draw.line((x, cy+18, x, cy+BOARD_TABLE[1]-4), fill=INK, width=2)
    for angle in BOARD_SEATS.values():
        x, y = _arc_point(angle, (BOARD_TABLE[0]-12, BOARD_TABLE[1]-10))
        draw.rectangle((x-4, y-2, x+4, y+2), fill=(30, 48, 56), outline=INK)
        draw.line((x-3, y, x+3, y), fill=CYAN)
    # The planet model turns on top of a coil; small arcs jump from its terminal.
    _ellipse(draw, (30, 21), fill=(54, 46, 46), outline=BRASS)
    for i, radii in enumerate(((27, 19), (25, 17), (23, 16), (21, 14))):
        _ellipse(draw, radii, outline=COPPER if i % 2 == 0 else (110, 62, 40))
    _ellipse(draw, (20, 13), outline=(214, 150, 96))
    _ellipse(draw, (12, 8), outline=(214, 150, 96))
    _ellipse(draw, (7, 5), outline=BRASS, width=2)
    draw.ellipse((cx-4, cy-4, cx+4, cy+4), fill=(253, 204, 112), outline=INK)
    for points in (((cx+5, cy-3), (cx+9, cy-7), (cx+8, cy-10), (cx+13, cy-14)),
                   ((cx-5, cy-2), (cx-9, cy-5), (cx-8, cy-8), (cx-14, cy-11)),
                   ((cx+3, cy+5), (cx+6, cy+8), (cx+4, cy+11))):
        draw.line(points, fill=(200, 250, 255))
        draw.point(points[-1], fill=CYAN)
    # Otpornik, Skoljka, Elektrika, Iskra and Rudnik on their brass arms.
    for angle, radii, color in ((20, (12, 8), (176, 98, 70)), (130, (12, 8), (210, 196, 168)),
                                (250, (20, 13), (110, 170, 214)), (320, (20, 13), (226, 132, 64)), (75, (20, 13), (122, 108, 96))):
        x, y = _arc_point(angle, radii)
        draw.line((cx, cy, x, y), fill=BRASS)
        draw.ellipse((x-3, y-3, x+3, y+3), fill=color, outline=INK)
    draw.point([(cx-14, cy-12), (cx+16, cy+10), (cx+22, cy-6)], fill=CYAN)
    # Furniture in the small rooms.
    _bench(draw, (192, 16, 32, 8), (114, 34, 52))
    _bench(draw, (320, 16, 32, 8), (52, 90, 148))
    _bench(draw, (16, 136, 16, 24), (95, 62, 69))
    _bench(draw, (16, 192, 16, 24), (95, 62, 69))
    for x, y in ((64, 122), (64, 210), (224, 318), (312, 318)):
        _plant(draw, x-4, y-4)
    draw.rectangle((112, 328, 135, 343), fill=(74, 49, 39), outline=BRASS)
    for x, color in ((116, (226, 222, 208)), (122, (32, 42, 76)), (128, (114, 34, 52))):
        draw.rectangle((x, 330, x+4, 341), fill=color, outline=INK)
        draw.point((x+2, 336), fill=CYAN)
    _crate(draw, (152, 272, 24, 8))
    _shelf(draw, (408, 272, 24, 16))
    draw.rectangle((408, 320, 431, 343), fill=(40, 48, 56), outline=BRASS)
    draw.rectangle((411, 323, 428, 333), fill=(30, 48, 56), outline=INK)
    for y in (325, 328, 331):
        draw.line((413, y, 413+(y*3) % 13, y), fill=CYAN)
    # Lift doors at the bottom of the lobby.
    lx0, _, lx1, ly1 = BOARD_SPACES["lobby"]
    draw.rectangle((248, ly1-2, 296, ly1+11), fill=(74, 49, 39), outline=BRASS)
    draw.rectangle((251, ly1+1, 293, ly1+11), fill=(111, 75, 46), outline=INK)
    draw.line((272, ly1+1, 272, ly1+11), fill=INK)
    for x in (261, 283):
        draw.ellipse((x-3, ly1+3, x+3, ly1+9), outline=BRASS)
    draw.text((300, ly1-2), "LIFT", font=FONT, fill=CREAM)
    for x in (lx0+6, lx1-2):
        draw.rectangle((x, ly1-2, x+3, ly1+1), fill=(253, 204, 112), outline=(126, 88, 50))
    title = "TOWER / BOARD CHAMBER"
    box = draw.textbbox((0, 0), title, font=FONT)
    draw.rectangle((10, 1, box[2]+21, 13), fill=INK, outline=BRASS)
    draw.text((16, 2), title, font=FONT, fill=CREAM)
    return image


def _board_npc(role):
    _, _, source, coat, trim, accent = next(o for o in BOARD_OUTFITS if o[0] == role)
    with Image.open(source) as image:
        sprite = image.convert("RGBA")
    d = ImageDraw.Draw(sprite)
    shade = tuple(max(0, c-36) for c in coat)
    # Long coat with sleeves to the wrists and tails to the knees; the hands stay visible.
    d.rectangle((3, 10, 12, 15), fill=shade)
    d.rectangle((5, 10, 10, 19), fill=coat)
    d.rectangle((4, 16, 11, 19), fill=coat)
    d.line((4, 17, 4, 19), fill=shade)
    d.line((11, 17, 11, 19), fill=shade)
    d.point([(3, 16), (12, 16)], fill=SKIN)
    d.line((8, 17, 8, 19), fill=INK)
    d.line((7, 10, 7, 16), fill=shade)
    d.line((8, 10, 8, 16), fill=trim)
    # High collar, cuffs and hem piping.
    d.line((4, 9, 11, 9), fill=trim)
    d.line((4, 7, 4, 8), fill=trim)
    d.line((11, 7, 11, 8), fill=trim)
    d.point([(3, 15), (4, 15), (11, 15), (12, 15)], fill=accent)
    for x in range(4, 12):
        d.point((x, 19), fill=accent if x % 2 else trim)
    if role == "board_nation":
        d.line((5, 3, 10, 3), fill=trim)
        d.point((7, 3), fill=accent)
        d.point([(6, 11), (5, 12), (6, 12), (5, 13)], fill=(253, 204, 112))
        d.line((4, 10, 4, 14), fill=trim)
        d.line((11, 10, 11, 14), fill=trim)
    elif role == "board_technology":
        d.line((5, 6, 10, 6), fill=accent)
        d.point([(5, 6), (10, 6)], fill=INK)
        d.point((9, 6), fill=(236, 252, 248))
        for i in range(7):
            d.point((4+i, 10+i), fill=accent)
            if i < 6:
                d.point((5+i, 10+i), fill=(170, 246, 236))
    elif role == "board_architecture":
        d.point([(6, 11), (5, 12), (7, 12), (5, 13), (7, 13)], fill=BRASS)
        d.point([(5, 17), (6, 18), (9, 17), (10, 18)], fill=(120, 160, 210))
        d.line((12, 11, 12, 14), fill=(214, 226, 236))
        d.point((12, 12), fill=(52, 90, 148))
    elif role == "board_navy":
        for y in (1, 2):
            d.line((4, y, 11, y), fill=coat)
        d.line((4, 3, 11, 3), fill=trim)
        d.line((4, 4, 11, 4), fill=INK)
        d.point((7, 2), fill=trim)
        d.line((2, 10, 4, 10), fill=trim)
        d.line((11, 10, 13, 10), fill=trim)
        d.point([(2, 11), (4, 11), (11, 11), (13, 11)], fill=trim)
        d.point([(6, 11), (6, 13), (6, 15), (9, 11), (9, 13), (9, 15)], fill=trim)
    elif role == "board_demographics":
        d.point([(6, 6), (9, 6)], fill=SILVER)
        d.point([(5, 11), (6, 12), (7, 12), (8, 13), (9, 13)], fill=trim)
        d.rectangle((11, 15, 12, 17), fill=CREAM, outline=(96, 66, 46))
        d.point((10, 14), fill=trim)
    elif role == "board_finance":
        d.point([(5, 11), (5, 12), (6, 13), (7, 13), (9, 13), (10, 12), (10, 11)], fill=trim)
        d.rectangle((7, 14, 8, 15), fill=trim)
        d.point((7, 14), fill=(255, 236, 160))
        d.point([(3, 15), (4, 15), (11, 15), (12, 15)], fill=trim)
    elif role == "board_defense":
        for y in range(2, 5):
            for x in range(5, 11):
                if sprite.getpixel((x, y))[3] and sprite.getpixel((x, y))[:3] != INK:
                    d.point((x, y), fill=(118, 124, 130))
        d.rectangle((2, 10, 4, 11), fill=trim, outline=INK)
        d.rectangle((11, 10, 13, 11), fill=trim, outline=INK)
        d.point([(3, 9), (12, 9)], fill=trim)
        d.point([(3, 10), (12, 10)], fill=(236, 244, 240))
        d.point([(6, 12), (7, 12)], fill=accent)
    elif role == "cauliflower_secretary":
        for i in range(7):
            d.point((11-i, 10+i), fill=(111, 75, 46))
        d.rectangle((3, 16, 5, 18), fill=(111, 75, 46), outline=INK)
        d.point((4, 17), fill=BRASS)
        d.point([(9, 17), (10, 18)], fill=(120, 96, 70))
        d.point([(9, 11), (10, 11), (9, 12)], fill=CREAM)
        d.point((10, 12), fill=GREEN)
    elif role == "diplomatic_secretary":
        d.point([(5, 11), (6, 12), (5, 13)], fill=BRASS)
        d.rectangle((12, 14, 13, 17), fill=CREAM, outline=INK)
        d.point((13, 15), fill=RED)
    return sprite


def _props():
    coat = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(coat)
    d.polygon([(8, 4), (16, 4), (21, 9), (18, 13), (16, 11), (17, 20), (7, 20), (8, 11), (5, 13), (2, 9)], fill=(54, 65, 82), outline=INK)
    d.line((12, 6, 12, 18), fill=BRASS)
    d.rectangle((14, 7, 16, 9), fill=BRASS)
    coat.save(OUT / "uniform_evidence.png")
    papers = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(papers)
    d.rectangle((2, 3, 12, 13), fill=(174, 149, 109), outline=INK)
    d.rectangle((4, 1, 14, 11), fill=CREAM, outline=INK)
    for y in (4, 6, 8):
        d.line((6, y, 12, y), fill=(105, 91, 77))
    papers.save(OUT / "contract_record.png")
    papers.save(OUT / "company_receipt.png")
    for role, (label, color) in SIGNS.items():
        w = len(label)*6+12
        sign = Image.new("RGBA", (w, 14))
        d = ImageDraw.Draw(sign)
        d.rectangle((0, 0, w-1, 13), fill=INK, outline=color)
        d.text((6, 2), label, fill=CREAM, font=FONT)
        sign.save(OUT / (role + "_sign.png"))
    meeting = Image.new("RGBA", (40, 16))
    d = ImageDraw.Draw(meeting)
    d.line((4, 4, 4, 12, 35, 12, 35, 4), fill=BRASS, width=2)
    for x in (12, 20, 28):
        d.rectangle((x-1, 6, x+1, 8), fill=CREAM)
    meeting.save(OUT / "rendezvous_mark.png")


def main():
    (OUT / "npcs").mkdir(parents=True, exist_ok=True)
    for name in ROOMS:
        room_image(name).save(OUT / (name + ".png"))
    _props()
    roles = VARIANTS + BOARD_OUTFITS
    atlas = Image.new("RGBA", (48, 24*((len(roles)+2)//3)))
    preview = Image.new("RGBA", (576, 164*((len(roles)+6)//4)), (*INK, 255))
    draw = ImageDraw.Draw(preview)
    references = [("Original player", Image.open(SOURCE / "player.png").convert("RGBA")),
                  ("Original villager", Image.open(SOURCE / "villager1.png").convert("RGBA")),
                  ("Original soldier", Image.open(MILITARY / "station_soldier_1.png").convert("RGBA"))]
    manifest = []
    for i, (role, label, source, *_rest) in enumerate(roles):
        sprite = npc(role)
        sprite.save(OUT / "npcs" / (role + ".png"))
        x, y = (i%3)*16, (i//3)*24
        atlas.alpha_composite(sprite, (x, y))
        manifest.append(dict(id=role, image=role+".png", region=[x, y, 16, 24], source=str(source.relative_to(ROOT))))
        references.append((label, sprite))
    for i, (label, sprite) in enumerate(references):
        x, y = (i%4)*144, (i//4)*164
        draw.rectangle((x+3, y+3, x+140, y+160), fill=(52, 42, 39), outline=(126, 91, 61))
        preview.alpha_composite(sprite.resize((80, 120), Image.Resampling.NEAREST), (x+32, y+10))
        draw.text((x+8, y+140), label, fill=CREAM, font=FONT)
    atlas.save(OUT / "npcs/sheet.png")
    (OUT / "npcs/sheet.json").write_text(json.dumps(manifest, indent=2)+"\n")
    preview.save(ROOT / "art/concepts/iskra_investigation_npcs.png")
    print(f"Created {len(ROOMS)} Iskra investigation interiors, {len(roles)} 16x24 NPCs and evidence props")


if __name__ == "__main__":
    main()
