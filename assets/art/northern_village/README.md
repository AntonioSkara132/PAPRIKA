# Northern village art

Pixel art for the larger northern village. Artwork from this directory is used on the live map, with some item and display sprites available for further service work. Iron sword and armor stock moves to the northern outfitter rather than staying in the original village. Brudet is a separate planet and is not part of this village.

All sprites have transparent PNGs and matching editable `.aseprite` files. The labeled preview is `northern_village_contact_sheet.png`.

| Sprites | Size | Intended use |
| --- | --- | --- |
| `north_house_copper`, `north_house_blue`, `north_house_green` | 64×80 | Taller village homes |
| `north_food_shop` | 80×72 | Larger food shop |
| `north_clothing_shop` | 80×72 | CLOTHES vendor with purple fabric and tunic in its windows |
| `north_forge` | 80×72 | Larger forge with chimney, fire, and anvil |
| `north_travel_agency` | 112×80 | Northern travel service |
| `iron_gear_shop` | 80×72 | Northern iron equipment outfitter |
| `iron_sword_display`, `iron_armor_display`, `purple_cloth_display` | 24×32 | Market displays |
| `iron_sword_icon`, `iron_armor_icon`, `purple_cloth_icon`, `purple_tunic_icon` | 16×16 | Inventory and shop menus |
| `player_purple` | 16×24 | Player appearance when wearing the purple tunic; matches the existing player silhouette |
| `food_rye_bread_icon`, `food_berry_pie_icon`, `food_smoked_fish_icon` | 16×16 | New food entries |

To regenerate the PNGs and editable sources, run `/usr/bin/python3 create_northern_art.py --aseprite` from this directory. Do not rerun the original whole-map generator over the live map.
