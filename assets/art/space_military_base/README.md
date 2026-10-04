# Confederation Military Art

The smaller training station has playable exterior and barracks maps at `maps/station.tmj` and `maps/station_barracks.tmj`. It uses an ordinary transport ship, two noninteractive warships, ten exterior barracks (only one can be entered), and soldiers drawn at the same 16×24 scale as Paprika's player and villagers. Their muted military-green tunics include small medieval details. Station-specific terrain, the open block-built practice cannon, training props and barracks furnishings are in the game. The larger three-ship base in `scene_concept.png` remains concept art, not a playable location or battlefield.

## Preview

- `contact_sheet.png` — the original concept sprites at native pixel size, with names and dimensions. The newer 16×24 station character variants and training props are generated separately.
- `scene_concept.png` — one possible arrangement of HQ, stores, cafeteria, barracks, training lanes, and three ship berths. It depicts the larger unplayable base, not the current station.
- `art/concepts/station_world_layout.png` and `art/concepts/station_barracks_layout.png` — previews rendered from the playable Tiled maps.
- The corresponding `.svg` files are editable preview sources. The contact sheet uses stone backgrounds for base assets and earth backgrounds for training props.

## Sprites

| Asset | Size | Intended use |
| --- | --- | --- |
| `headquarters.png` | 112×96 | Stone HQ with green roof and command door |
| `cafeteria.png` | 96×72 | Military cafeteria with serving window |
| `weapons_storage.png` | 96×72 | Reinforced storage building |
| `barracks_a.png`, `barracks_b.png`, `barracks_c.png` | 64×72 each | Three small stone-and-metal houses |
| `warship_flagship.png` | 144×72 | Larger armed ship |
| `warship_scout.png`, `warship_escort.png` | 96×56 each | Two smaller armed ships |
| `landing_pad_flagship.png` | 160×96 | Berth A, with clearance around the large ship |
| `landing_pad_one.png`, `landing_pad_two.png` | 112×64 each | Berths 1 and 2 for smaller ships |
| `training_ground.png` | 128×80 | Earthy practice ground with lane markings |
| `training_arrow_target.png` | 32×40 | Standalone arrow target |
| `confederation_soldier.png` | 24×32 | Bright-green soldier uniform and helmet concept |
| `confederation_officer.png` | 24×32 | Distinct command cap, gold insignia, and green coat |
| `watchtower.png` | 48×80 | Stone-and-metal lookout |
| `base_gate.png` | 64×48 | Metal entry gate between stone posts |
| `munitions_crate.png` | 32×32 | Marked weapons-supply crate |
| `training_sandbags.png` | 48×24 | Low practice-lane cover |

The original concept sprites have matching editable `source/<name>.svg` files with integer pixel coordinates and a limited palette. The playable station's 16×24 people and small training props are drawn by `source/build_station_people.py`; this keeps each face, tunic and medieval uniform detail at the same pixel scale as the villagers.

## Regeneration

To rebuild the playable station's people and small training props, run from the project root:

```sh
/usr/bin/python3 assets/art/space_military_base/source/build_station_people.py
```

This Pillow script draws only those station sprites. Its 16×24 characters follow the same head, body and feet proportions as the village sprites. `build_assets.py` is the older generator for the original concept art; do not run it to update station sprites or maps.

The playable station uses the ordinary transport rather than a warship, and its exterior shows a lit, irregular edge against space. The compact barracks interior has gray flooring, neutral carpet, front windows, and ten paired beds and chests. Station terrain, buildings and furnishings have editable `source/station_*.svg` files; station people and training props are defined in `source/build_station_people.py`, with exported PNGs beside this README. Collision and interaction rules are in `scripts/world/tiled_loader.gd` and the station world scripts. The original art generator predates station-specific additions: **do not rerun it over station art or maps**.
