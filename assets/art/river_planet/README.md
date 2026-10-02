# River Planet art

River Planet is the art set for Brudet, a playable Mediterranean-influenced river city. The live map uses this directory's terrain atlas, and its buildings, props, characters, and icons support Brudet's map and services. Each of the 27 standalone sprites is a transparent PNG with an editable LibreSprite `.aseprite` file of the same basename; the terrain atlas is opaque and documented below. The labeled preview is `river_planet_contact_sheet.png`.

| Sprite basename | Size | Intended use |
| --- | --- | --- |
| `river_town_hall` | 112×96 | Civic building defining the town center |
| `river_market` | 96×72 | City market and food stalls |
| `river_townhouse` | 64×88 | Tall stucco residence |
| `river_library` | 96×88 | LIBRARY service for lore and practical information |
| `town_center_fountain` | 64×48 | Fountain for the central plaza |
| `military_hq` | 96×96 | Green two-story Military Headquarters with bow and sword motifs |
| `arrow_target` | 32×32 | Archery target to place beside the HQ |
| `stone_bridge` | 96×48 | Stone crossing over turquoise water |
| `lake_patch` | 96×64 | Standalone lake and shoreline |
| `fishing_pond` | 64×48 | Fish pond with reeds |
| `fishing_boat` | 48×24 | Small fishing boat |
| `reed_cluster` | 24×16 | Waterside plants |
| `terraced_field` | 80×48 | Cultivated crop rows |
| `olive_tree` | 32×48 | Mediterranean field tree |
| `crop_bundle` | 16×16 | Small harvested crop prop |
| `river_villager_sunhat` | 16×24 | Local villager in a sunhat |
| `river_villager_shawl` | 16×24 | Local villager in a terracotta shawl |
| `river_fisherman` | 16×24 | Fisher with rod and waterside clothes |
| `finling` | 16×24 | Small finned monster |
| `lake_maw` | 32×24 | Large fishlike monster |
| `river_serpent` | 48×24 | Long river monster |
| `fishing_rod_display` | 24×32 | Fishing rod on a shop display stand |
| `fishing_rod_icon` | 16×16 | Fishing tool inventory icon |
| `library_book_icon` | 16×16 | Open-book icon for the library service |
| `food_fish_stew_icon` | 16×16 | Fish stew food icon |
| `food_olive_bread_icon` | 16×16 | Olive bread food icon |
| `food_citrus_icon` | 16×16 | Citrus fruit food icon |

Dimensions above are full transparent image frames. `lake_patch`, `fishing_pond`, and the field pieces are standalone props; they are not seamless terrain tiles.

## Brudet terrain atlas

**Live Brudet map atlas:** `maps/brudet_terrain.tsj` references `river_terrain.png`, a 128×64 RGBA atlas with a matching `river_terrain.aseprite`. It has 8 columns and 4 rows of opaque 16×16 tiles, with zero margin and zero spacing. Local IDs are **zero-based and row-major**: `id = column + 8 × row`; tile `(column, row)` starts at pixel `(16 × column, 16 × row)`. A Tiled tileset's global GID is `firstgid + local ID` (for example, with `firstgid=300`, water ID 0 is GID 300).

| Row / column | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **0 · map basics** | 0 `water_base` | 1 `dry_bank` | 2 `warm_stone_street` | 3 `bank_north` | 4 `bank_south` | 5 `bridge_north_rail` | 6 `bridge_south_rail` | 7 `bridge_deck` |
| **1 · crops/banks** | 8 `crop_seedlings` | 9 `crop_green` | 10 `crop_ripe` | 11 `crop_harvest` | 12 `bank_west` | 13 `bank_east` | 14 `bank_outer_nw` | 15 `bank_outer_ne` |
| **2 · corners/water** | 16 `bank_outer_sw` | 17 `bank_outer_se` | 18 `bank_inner_nw` | 19 `bank_inner_ne` | 20 `bank_inner_sw` | 21 `bank_inner_se` | 22 `water_ripple_a` | 23 `water_ripple_b` |
| **3 · variants** | 24 `water_deep` | 25 `warm_stone_street_a` | 26 `warm_stone_street_b` | 27 `bridge_deck_worn` | 28 `bridge_west_entry` | 29 `bridge_east_entry` | 30 `stone_plaza` | 31 `stone_curb` |

Use **0 for water**, **1 for dry sand bank**, and **2 for warm stone/cobblestone path**. Tiles 3–4 and 12–13 draw north/south/west/east shoreline; a cardinal bank's direction names its **land side**. Outer corners 14–17 have land on both named edges; inner corners 18–21 have water in the named corner. Water variants 22–24 share border colors with ID 0. Tiles **5–6 are solid bridge rails**, **7 is walkable bridge deck**, and 8–11 are crop stages; do not use those IDs for banks. Tiles 25–26 vary the stone path; 27–29 extend the bridge, 30 is plaza paving, and 31 is a curb.

`river_terrain_tiles.png` and its `.aseprite` are an earlier exploratory atlas with **different IDs**; do not use them for Brudet maps. From this directory, run `/usr/bin/python3 create_river_terrain.py --aseprite` to regenerate **only** the map-facing `river_terrain` atlas, its LibreSprite source, and the contact sheet; it leaves the 27 existing sprite PNGs untouched. The separate `/usr/bin/python3 create_river_art.py --aseprite` command regenerates those sprites. Both scripts require Pillow, and `--aseprite` requires LibreSprite's `sprite` command.
