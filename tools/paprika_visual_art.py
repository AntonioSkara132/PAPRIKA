"""Shared pixel-art details for Paprika's shops, signs, and forest tiles."""

from PIL import Image, ImageDraw

COLORS = {
    "ink": "#1c1730",
    "wood": "#8b5537",
    "wood_dark": "#543328",
    "white": "#f7f1dd",
    "gold": "#f5c34c",
    "cyan": "#5fd6d3",
    "orange": "#ef873f",
}

# The signs use 5×7 pixels per letter so zooming never softens their edges.
LETTERS = {
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "B": ("11110", "10001", "10001", "11110", "10001", "10001", "11110"),
    "C": ("01111", "10000", "10000", "10000", "10000", "10000", "01111"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "F": ("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
    "G": ("01111", "10000", "10000", "10111", "10001", "10001", "01111"),
    "H": ("10001", "10001", "10001", "11111", "10001", "10001", "10001"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "J": ("00111", "00010", "00010", "00010", "10010", "10010", "01100"),
    "K": ("10001", "10010", "10100", "11000", "10100", "10010", "10001"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "N": ("10001", "11001", "10101", "10101", "10011", "10001", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "P": ("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
    "Q": ("01110", "10001", "10001", "10001", "10101", "10010", "01101"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "S": ("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
    "V": ("10001", "10001", "10001", "10001", "10001", "01010", "00100"),
    "W": ("10001", "10001", "10001", "10101", "10101", "10101", "01010"),
    "X": ("10001", "10001", "01010", "00100", "01010", "10001", "10001"),
    "Y": ("10001", "10001", "01010", "00100", "00100", "00100", "00100"),
    "Z": ("11111", "00001", "00010", "00100", "01000", "10000", "11111"),
    " ": ("00000",) * 7,
}


def centered_text(draw, center_x, top, value, color):
    if not value or any(letter not in LETTERS for letter in value):
        raise ValueError(f"Unsupported sign text: {value}")
    width = len(value) * 6 - 1
    x = center_x - width // 2
    for letter in value:
        for row, bits in enumerate(LETTERS[letter]):
            for column, bit in enumerate(bits):
                if bit == "1":
                    draw.point((x + column, top + row), fill=color)
        x += 6
    return width, 7


def draw_service_plaque(draw, canvas_width, top, value):
    text_width = len(value) * 6 - 1
    width = max(36, text_width + 14)
    if width > canvas_width - 8:
        raise ValueError(f"The {value} sign does not fit a {canvas_width}-pixel building")
    x = (canvas_width - width) // 2
    draw.rectangle((x, top, x + width - 1, top + 12), fill=COLORS["ink"],
                   outline=COLORS["cyan"])
    draw.line((x + 3, top + 10, x + width - 4, top + 10), fill=COLORS["wood"])
    draw.point((x + 2, top + 2), fill=COLORS["gold"])
    draw.point((x + width - 3, top + 2), fill=COLORS["gold"])
    centered_text(draw, canvas_width // 2, top + 2, value, COLORS["white"])
    return x, top, x + width, top + 13


def forest_sign():
    image = Image.new("RGBA", (48, 32))
    draw = ImageDraw.Draw(image)
    draw.ellipse((9, 26, 39, 31), fill=(28, 23, 48, 95))
    draw.rectangle((23, 14, 26, 29), fill=COLORS["wood_dark"])
    draw.rectangle((2, 8, 45, 18), fill=COLORS["wood"], outline=COLORS["ink"])
    draw.line((4, 10, 43, 10), fill="#b17842")
    draw.point((5, 16), fill=COLORS["gold"])
    centered_text(draw, 24, 10, "FOREST", COLORS["white"])
    return image


def field_sign(value):
    if value not in ("COMMON", "PRIVATE"):
        raise ValueError(value)
    image = Image.new("RGBA", (64, 32))
    draw = ImageDraw.Draw(image)
    draw.ellipse((18, 26, 47, 31), fill=(28, 23, 48, 95))
    draw.rectangle((30, 15, 33, 28), fill=COLORS["wood_dark"])
    draw.polygon([(3, 8), (60, 8), (62, 13), (60, 19), (3, 19)],
                 fill=COLORS["wood"], outline=COLORS["ink"])
    draw.line((5, 10, 58, 10), fill="#b17842")
    centered_text(draw, 32, 10, value, COLORS["white"])
    return image


def forest_warning_sign():
    image = Image.new("RGBA", (64, 40))
    draw = ImageDraw.Draw(image)
    draw.ellipse((18, 34, 47, 39), fill=(28, 23, 48, 95))
    draw.rectangle((30, 24, 33, 36), fill=COLORS["wood_dark"])
    draw.polygon([(3, 5), (60, 5), (62, 10), (60, 27), (3, 27)],
                 fill="#66343c", outline=COLORS["ink"])
    draw.rectangle((6, 7, 57, 25), outline=COLORS["orange"])
    centered_text(draw, 32, 7, "DANGER", COLORS["gold"])
    centered_text(draw, 32, 17, "FOREST", COLORS["white"])
    return image


def modern_building(name, size, base, accent, label, kind, palette=COLORS):
    width, height = size
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    ink = palette["ink"]
    draw.ellipse((5, height - 14, width - 3, height - 2), fill=(28, 23, 48, 95))
    if name == "forge":
        for x, y in ((13, 1), (14, 1), (11, 3), (12, 3), (10, 5), (15, 5)):
            draw.point((x, y), fill="#b8b3a6")
        draw.point((9, 6), fill="#8c898a")
        draw.rectangle((18, 3, 27, 17), fill="#656977", outline=ink)
        draw.rectangle((17, 2, 28, 5), fill="#a8a7a0", outline=ink)
        draw.line((20, 8, 20, 15), fill="#89909a")
    if kind == "wedge":
        draw.polygon([(7, height - 10), (10, 24), (34, 7), (width - 7, 18),
                      (width - 9, height - 10)], fill=base, outline=ink)
        draw.polygon([(14, 26), (35, 12), (width - 15, 22), (width - 17, 28)],
                     fill=accent)
    elif kind == "hex":
        draw.polygon([(8, 20), (24, 7), (width - 18, 7), (width - 6, 23),
                      (width - 11, height - 9), (10, height - 9)],
                     fill=base, outline=ink)
        draw.polygon([(22, 10), (width - 20, 10), (width - 11, 23), (16, 23)],
                     fill=accent)
    elif kind == "fort":
        draw.polygon([(7, height - 9), (7, 20), (22, 8), (width - 20, 8),
                      (width - 6, 20), (width - 6, height - 9)],
                     fill=base, outline=ink)
        draw.polygon([(13, 22), (28, 13), (width - 29, 13), (width - 12, 22)],
                     fill=accent)
        draw.rectangle((14, 25, width - 14, 31), fill=ink)
    else:
        draw.ellipse((7, 5, width - 7, height - 7), fill=base, outline=ink, width=2)
        draw.arc((13, 10, width - 13, height - 14), 180, 360, fill=accent, width=4)
        draw.polygon([(19, height - 18), (width // 2, 14),
                      (width - 19, height - 18)],
                     fill=(95, 214, 211, 110), outline=palette["cyan"])
    draw.rectangle((width // 2 - 7, height - 28, width // 2 + 7, height - 9),
                   fill="#29273b", outline=ink)
    if name == "forge":
        draw.rectangle((53, 41, 70, 54), fill=ink, outline="#b96b38")
        draw.rectangle((56, 44, 67, 51), fill="#b34926")
        draw.polygon([(59, 51), (57, 48), (61, 45), (63, 48), (66, 46),
                      (66, 51)], fill="#ffab3c")
        draw.point((61, 47), fill=palette["white"])
        draw.rectangle((11, 53, 25, 55), fill="#98a0a1", outline=ink)
        draw.polygon([(14, 56), (22, 56), (20, 59), (16, 59)],
                     fill="#6e7984", outline=ink)
        draw.rectangle((17, 59, 19, 61), fill="#6e7984")
        draw.rectangle((14, 61, 22, 62), fill=ink)
        draw.line((10, 54, 5, 52), fill="#b0b8b7", width=2)
        draw.rectangle((70, 53, 77, 57), fill="#795137", outline=ink)
        draw.line((71, 55, 76, 55), fill="#c0884d")
        draw.rectangle((68, 57, 76, 61), fill="#795137", outline=ink)
        draw.line((69, 59, 75, 59), fill="#c0884d")
        draw.point((65, 59), fill="#36343b")
        draw.point((66, 60), fill="#36343b")
        draw.point((64, 61), fill="#36343b")
    draw_service_plaque(draw, width, height - 41, label)
    return image


def draw_forest_tiles(sheet):
    if sheet.size != (128, 48):
        raise ValueError("The terrain sheet must be 128×48 pixels")
    draw = ImageDraw.Draw(sheet)
    x, y = 0, 32
    draw.rectangle((x, y, x + 15, y + 15), fill="#4d7946")
    for px, py in ((3, 5), (10, 2), (8, 12), (14, 8)):
        draw.point((x + px, y + py), fill="#72944e")
        draw.point((x + px + 1, y + py + 1), fill="#315d3a")
    x = 16
    draw.rectangle((x, y, x + 15, y + 15), fill="#3c693f")
    for px, py in ((2, 3), (9, 6), (4, 12), (13, 14)):
        draw.line((x + px, y + py, x + px + 2, y + py), fill="#537b45")
    draw.point((x + 12, y + 4), fill="#a6a46c")
    x = 32
    draw.ellipse((x + 4, y + 9, x + 9, y + 14), fill="#d2cbb2", outline="#747687")
    draw.point((x + 5, y + 11), fill="#3c3544")
    draw.point((x + 8, y + 11), fill="#3c3544")
    draw.line((x + 10, y + 12, x + 14, y + 8), fill="#d2cbb2", width=2)
    draw.point((x + 14, y + 7), fill="#f7f1dd")
    x = 48
    draw.line((x + 2, y + 11, x + 8, y + 8), fill="#543328", width=2)
    draw.line((x + 9, y + 7, x + 13, y + 4), fill="#8b5537", width=2)
    draw.rectangle((x + 3, y + 9, x + 5, y + 13), fill="#8b5537")
    draw.rectangle((x + 11, y + 3, x + 13, y + 8), fill="#543328")
    draw.point((x + 7, y + 12), fill="#b17842")
    x = 64
    draw.line((x + 5, y + 9, x + 4, y + 13), fill="#427247")
    draw.line((x + 11, y + 7, x + 12, y + 11), fill="#427247")
    draw.rectangle((x + 5, y + 6, x + 6, y + 8), fill="#6a9a55")
    draw.rectangle((x + 11, y + 5, x + 12, y + 7), fill="#6a9a55")
    x = 80
    draw.ellipse((x + 5, y + 10, x + 11, y + 14), fill="#6c6b68", outline="#343847")
    draw.line((x + 7, y + 10, x + 11, y + 11), fill="#a7a597")
    x = 96
    draw.line((x + 2, y + 12, x + 12, y + 11), fill="#543328", width=2)
    draw.line((x + 9, y + 7, x + 12, y + 10), fill="#8b5537", width=2)
    x = 112
    draw.ellipse((x + 4, y + 12, x + 11, y + 14), fill="#2d5b36")
    draw.point((x + 6, y + 10), fill="#628e4a")
    draw.point((x + 10, y + 11), fill="#628e4a")
