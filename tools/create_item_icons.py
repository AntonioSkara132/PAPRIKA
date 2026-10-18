#!/usr/bin/env python3
"""Create the inventory's transparent 16×16 pixel icons.

Run with /usr/bin/python3 tools/create_item_icons.py. No random input or resizing is
used, so regenerating the PNGs produces the same bytes.
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/art/items"
INK = "#312b37"
LIGHT = "#f5e9cf"

# Existing hand-drawn item sprites are referenced directly by ItemIcons instead.
EXISTING = {
    "rye_bread", "berry_pie", "smoked_fish", "purple_cloth", "purple_tunic",
    "iron_armor", "iron_sword", "citrus", "fishing_rod", "olive_bread", "fish_stew",
}


def draw_icon(item_id):
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)

    if item_id in ("potato", "carrot", "tomato", "grape", "citrus"):
        if item_id == "potato":
            d.ellipse((2, 5, 13, 13), fill="#ae8051", outline=INK)
            d.point([(5, 8), (9, 7), (10, 11)], fill="#664c39")
            d.line((3, 8, 5, 6, 8, 6), fill="#d9ae74")
        elif item_id == "carrot":
            d.polygon([(4, 5), (12, 6), (8, 14)], fill="#dc7a38")
            d.line((4, 5, 12, 6, 8, 14, 4, 5), fill=INK)
            d.polygon([(6, 5), (3, 2), (7, 3), (9, 1), (9, 5)], fill="#65975b")
            d.line((6, 8, 9, 9), fill="#f7b05d")
        elif item_id == "tomato":
            d.ellipse((2, 4, 13, 13), fill="#d9544a", outline=INK)
            d.polygon([(4, 5), (8, 5), (8, 2), (9, 5), (12, 5), (9, 7), (7, 7)], fill="#658a4b")
            d.line((4, 9, 5, 7), fill="#f69a6c")
        else:
            for x, y in [(5, 5), (9, 5), (4, 9), (8, 9), (12, 9), (6, 12), (10, 12)]:
                d.ellipse((x - 2, y - 2, x + 1, y + 1), fill="#82629b", outline=INK)
            d.line((8, 3, 10, 1, 13, 2), fill="#568650", width=2)
    elif item_id in ("rabbit_meat", "copper_pot_roast"):
        d.ellipse((2, 4, 11, 12), fill="#a85d55", outline=INK)
        d.ellipse((5, 5, 9, 8), fill="#db8b73")
        d.line((10, 10, 13, 13), fill="#ede4c9", width=3)
        d.point((14, 13), fill=INK)
        if item_id == "copper_pot_roast":
            d.arc((1, 8, 14, 15), 0, 180, fill="#d69b55", width=2)
            d.line((4, 14, 11, 14), fill="#715034", width=2)
    elif item_id in ("bread", "olive_bread"):
        d.ellipse((1, 4, 14, 13), fill="#c78348", outline=INK)
        d.ellipse((3, 5, 12, 10), fill="#e8bb75")
        for x in (5, 9):
            d.line((x, 6, x - 1, 9), fill="#a5643e")
    elif item_id in ("stew", "tomato_soup", "kelp_broth", "shellfish_stew", "greenhouse_salad", "dock_dumplings", "fish_stew"):
        fill = {"stew": "#c89148", "tomato_soup": "#d05a44", "kelp_broth": "#6f9b77", "shellfish_stew": "#c69773", "greenhouse_salad": "#69a66b", "dock_dumplings": "#d9bd8a", "fish_stew": "#c89174"}[item_id]
        d.ellipse((1, 6, 14, 12), fill="#e3dac2", outline=INK)
        d.ellipse((3, 5, 12, 9), fill=fill, outline=INK)
        if item_id == "dock_dumplings":
            d.ellipse((4, 5, 7, 7), fill=LIGHT)
            d.ellipse((9, 6, 11, 8), fill=LIGHT)
        elif item_id == "shellfish_stew":
            d.arc((5, 5, 10, 9), 180, 350, fill="#f8d8b5", width=2)
        else:
            d.point([(5, 7), (9, 6), (11, 8)], fill="#e9d09a" if item_id != "greenhouse_salad" else "#c55443")
        d.line((4, 13, 11, 13), fill="#887463")
    elif item_id == "stuffed_peppers":
        for x, y, color in [(2, 6, "#d95541"), (8, 5, "#e8a345")]:
            d.polygon([(x, y), (x + 5, y), (x + 4, y + 7), (x + 1, y + 7)], fill=color, outline=INK)
            d.line((x + 1, y + 1, x + 4, y + 1), fill="#edd29a", width=2)
            d.point((x + 2, y - 1), fill="#5e8b51")
    elif item_id == "ale":
        d.rectangle((3, 4, 10, 13), fill="#a66b42", outline=INK)
        d.rectangle((4, 5, 9, 8), fill="#e7b363")
        d.ellipse((2, 2, 11, 5), fill="#f6e4ba", outline=INK)
        d.arc((9, 5, 15, 11), 270, 90, fill=INK, width=2)
    elif item_id in ("purple_cloth", "orange_cloth", "sea_glass_cloth"):
        color = {"purple_cloth": "#7f619d", "orange_cloth": "#d98a49", "sea_glass_cloth": "#68b1ac"}[item_id]
        d.polygon([(2, 4), (11, 2), (14, 5), (12, 12), (4, 14), (2, 11)], fill=color, outline=INK)
        d.line((3, 8, 12, 6), fill=LIGHT)
        d.line((5, 11, 11, 10), fill="#435260")
    elif item_id == "river_fish":
        d.ellipse((3, 5, 11, 10), fill="#75a9af", outline=INK)
        d.polygon([(10, 7), (14, 3), (14, 12)], fill="#477687", outline=INK)
        d.polygon([(6, 5), (8, 2), (10, 5)], fill="#477687")
        d.point((5, 7), fill=INK)
        d.line((6, 9, 10, 9), fill="#cae3d4")
    elif item_id == "life_potion":
        d.rectangle((6, 1, 9, 4), fill="#b89162", outline=INK)
        d.polygon([(5, 4), (10, 4), (12, 7), (12, 12), (10, 14), (5, 14), (3, 12), (3, 7)], fill="#9ac8c0", outline=INK)
        d.rectangle((4, 9, 11, 12), fill="#d85864")
        d.line((5, 7, 5, 8), fill=LIGHT)
        d.point((10, 10), fill="#f9b2a1")
    elif item_id in ("banishing_arrow", "basic_arrow", "bronze_arrow", "iron_arrow"):
        color = {"banishing_arrow": "#b8a4ed", "basic_arrow": "#d3c8ae", "bronze_arrow": "#cb9760", "iron_arrow": "#b5c4cf"}[item_id]
        d.line((2, 13, 12, 3), fill=INK, width=3)
        d.line((2, 13, 12, 3), fill="#a9794c")
        d.polygon([(9, 3), (14, 1), (12, 6)], fill=color, outline=INK)
        d.line((1, 10, 5, 14), fill=color)
        d.line((2, 8, 7, 13), fill=color)
        if item_id == "banishing_arrow":
            d.point([(12, 0), (15, 5), (8, 2)], fill="#eddaff")
    elif item_id in ("martin_letter", "board_credentials", "embassy_letters", "skoljka_forged_work_order", "skoljka_repair_orders"):
        d.polygon([(3, 2), (10, 2), (13, 5), (13, 14), (3, 14)], fill="#e7d4ae", outline=INK)
        d.polygon([(10, 2), (10, 5), (13, 5)], fill="#a9997f", outline=INK)
        d.line((5, 7, 11, 7), fill="#8d826d")
        d.line((5, 9, 10, 9), fill="#8d826d")
        if item_id in ("embassy_letters", "skoljka_repair_orders"):
            d.rectangle((4, 10, 11, 13), fill="#bb594b", outline=INK)
            d.point((7, 11), fill="#ebc184")
        elif item_id == "skoljka_forged_work_order":
            d.line((5, 12, 9, 10, 11, 12), fill="#515c80")
        elif item_id == "board_credentials":
            d.rectangle((5, 10, 10, 12), fill="#6d8890")
        else:
            d.point((6, 12), fill="#ae5548")
    elif item_id in ("winch_gear", "skoljka_company_part"):
        for x, y in [(6, 1), (10, 1), (2, 6), (12, 6), (6, 12), (10, 12)]:
            d.rectangle((x, y, x + 2, y + 3), fill="#a8a49b", outline=INK)
        d.ellipse((3, 3, 12, 12), fill="#a7aba7", outline=INK)
        d.ellipse((6, 6, 9, 9), fill="#343b44")
        if item_id == "skoljka_company_part":
            d.point([(5, 5), (10, 9)], fill="#deaa65")
    elif item_id in ("stick", "militia_club", "training_club", "wood_sword", "bronze_sword", "iron_sword", "tvrdium_sword"):
        is_sword = item_id.endswith("sword")
        color = {"stick": "#96704d", "militia_club": "#956646", "training_club": "#ba9466", "wood_sword": "#bb9365", "bronze_sword": "#c68c57", "iron_sword": "#b3bfcb", "tvrdium_sword": "#8caec1"}[item_id]
        d.line((3, 13, 12, 3), fill=INK, width=4)
        d.line((3, 13, 12, 3), fill=color, width=2)
        if is_sword:
            d.line((4, 9, 8, 13), fill="#e5bb76", width=2)
            d.point((12, 2), fill=LIGHT)
            if item_id == "tvrdium_sword":
                d.point([(11, 4), (9, 6)], fill="#d9eef2")
        elif item_id in ("militia_club", "training_club"):
            d.ellipse((9, 2, 14, 7), fill=color, outline=INK)
            d.point((11, 3), fill="#dab489")
    elif item_id in ("wood_spear", "bronze_spear", "iron_spear"):
        color = {"wood_spear": "#c09d68", "bronze_spear": "#cd9766", "iron_spear": "#b6c3ce"}[item_id]
        d.line((2, 14, 11, 5), fill=INK, width=3)
        d.line((2, 14, 11, 5), fill="#ad784e")
        d.polygon([(9, 5), (14, 1), (12, 7)], fill=color, outline=INK)
        d.line((5, 10, 8, 13), fill="#e0b47a")
    elif item_id in ("training_bow", "wood_bow", "bronze_bow", "iron_bow", "service_bow"):
        color = {"training_bow": "#ba986b", "wood_bow": "#a8754e", "bronze_bow": "#ce9b60", "iron_bow": "#9caab3", "service_bow": "#6b998a"}[item_id]
        d.line((4, 2, 12, 13), fill=LIGHT)
        d.line((4, 2, 9, 3, 12, 7, 12, 10, 12, 13), fill=INK, width=3)
        d.line((4, 2, 9, 3, 12, 7, 12, 10, 12, 13), fill=color)
        d.point((4, 2), fill="#eee4c7")
    elif item_id in ("wood_armor", "bronze_armor", "iron_armor", "tvrdium_armor"):
        color = {"wood_armor": "#a78056", "bronze_armor": "#c28d59", "iron_armor": "#b6bec4", "tvrdium_armor": "#82a8bd"}[item_id]
        d.polygon([(4, 2), (7, 3), (9, 3), (12, 2), (14, 5), (11, 7), (11, 13), (5, 13), (5, 7), (2, 5)], fill=color, outline=INK)
        d.line((5, 7, 11, 7), fill="#e2d7b9")
        d.polygon([(6, 8), (10, 8), (8, 11)], fill="#6d777d")
    elif item_id.endswith("tunic") or item_id == "military_uniform":
        color = {"red_tunic": "#c4524a", "blue_tunic": "#4e81b0", "green_tunic": "#609564", "purple_tunic": "#8965a4", "orange_tunic": "#d9854b", "sea_glass_tunic": "#69afa5", "coral_tunic": "#d37c76", "military_uniform": "#708267"}[item_id]
        d.polygon([(5, 2), (7, 3), (9, 3), (11, 2), (14, 6), (12, 8), (11, 7), (12, 14), (4, 14), (5, 7), (3, 8), (1, 6)], fill=color, outline=INK)
        d.line((6, 4, 8, 6, 10, 4), fill="#e9d4b0")
        d.line((5, 10, 11, 10), fill="#704d54")
        if item_id == "military_uniform":
            d.point([(7, 8), (9, 8)], fill="#e6c57a")
    elif item_id in ("practice_mine", "field_mine"):
        # The station mine sprite is 8×8; draw it here at native inventory size.
        d.ellipse((1, 5, 14, 13), fill="#717a81", outline=INK)
        d.ellipse((4, 5, 11, 10), fill="#a0a9aa", outline=INK)
        d.rectangle((7, 2, 8, 5), fill="#a5a29a", outline=INK)
        d.point((7, 7), fill="#efc272" if item_id == "practice_mine" else "#e16b54")
        d.point([(3, 9), (12, 9)], fill="#d0c5a7")
    elif item_id == "bandage":
        d.polygon([(2, 6), (10, 2), (14, 9), (6, 13)], fill="#f1e4c7", outline=INK)
        d.polygon([(5, 5), (9, 3), (12, 9), (8, 11)], fill="#d8baa0")
        d.point([(7, 6), (9, 7), (8, 9)], fill="#9b756b")
    elif item_id == "fishing_rod":
        d.line((2, 14, 7, 3, 12, 1), fill="#9d744e", width=2)
        d.line((12, 1, 13, 9), fill=LIGHT)
        d.arc((9, 8, 14, 13), 0, 180, fill="#a6bbc1")
    elif item_id == "unknown":
        d.arc((4, 1, 11, 8), 180, 360, fill=INK, width=2)
        d.polygon([(3, 5), (12, 5), (14, 8), (13, 14), (2, 14), (1, 8)], fill="#716486", outline=INK)
        d.line((5, 7, 6, 6, 9, 6, 10, 7, 10, 8, 8, 10), fill="#f2d47c", width=2)
        d.point((8, 12), fill="#f2d47c")
    else:
        raise ValueError(f"No drawing for {item_id}")
    return image


ITEM_IDS = (
    "potato", "carrot", "tomato", "grape", "rabbit_meat", "bread", "stew",
    "rye_bread", "berry_pie", "smoked_fish", "purple_cloth", "river_fish",
    "fish_stew", "olive_bread", "citrus", "tomato_soup", "stuffed_peppers",
    "ale", "orange_cloth", "kelp_broth", "shellfish_stew", "greenhouse_salad",
    "dock_dumplings", "copper_pot_roast", "life_potion", "sea_glass_cloth",
    "fishing_rod", "banishing_arrow", "martin_letter", "board_credentials",
    "embassy_letters", "winch_gear", "skoljka_company_part",
    "skoljka_forged_work_order", "skoljka_repair_orders", "stick",
    "militia_club", "training_club", "training_bow", "wood_sword",
    "bronze_sword", "iron_sword", "tvrdium_sword", "wood_spear",
    "bronze_spear", "iron_spear", "wood_bow", "bronze_bow", "iron_bow",
    "bronze_arrow", "iron_arrow", "wood_armor", "bronze_armor", "iron_armor",
    "tvrdium_armor", "red_tunic", "blue_tunic", "green_tunic",
    "purple_tunic", "orange_tunic", "sea_glass_tunic", "coral_tunic",
    "military_uniform", "practice_mine", "service_bow", "field_mine",
    "bandage", "basic_arrow",
)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for item_id in (*ITEM_IDS, "unknown"):
        if item_id not in EXISTING:
            draw_icon(item_id).save(DEST / f"{item_id}.png", optimize=False)


if __name__ == "__main__":
    main()
