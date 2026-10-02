# Space Military Base — art concept

Concept art for a possible future Cauliflower Confederation military location. **These sprites are not connected to a map, tileset, collision system, or mission.** The scene image is a visual arrangement, not a playable layout.

## Preview

- `contact_sheet.png` — all sprites at native pixel size, with names and dimensions.
- `scene_concept.png` — one possible arrangement of HQ, stores, cafeteria, barracks, training lanes, and three ship berths. Stone paving covers the main courtyard; the ship apron is metal, while brown earth is reserved for the practice range.
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

Each sprite has a matching editable `source/<name>.svg`. The shapes use integer pixel coordinates and a limited palette; exports preserve transparency outside each sprite.

## Regeneration

Run from the project root:

```sh
python assets/art/space_military_base/source/build_assets.py
```

The source script contains the palette, individual drawing instructions, and the contact-sheet and scene layout. It writes only inside `assets/art/space_military_base/` and uses ImageMagick `convert` to export the PNGs. Changes to an individual SVG can also be rendered with `convert -background none source/<name>.svg <name>.png`, but running the script again will replace those SVG edits; make repeatable changes in `build_assets.py`.

The ships, pads, buildings, and props still need placement and collision choices before any future game integration. No map or gameplay files were changed for this art pass.
