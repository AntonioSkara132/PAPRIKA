# Paprika — first planet of Craft

A playable, single-player pixel-art prototype set on Paprika, a flat planet in the Cauliflower Confederation. The village is the safe center. Roads continue into the forest, where rabbits, monsters, bandits, and a level-five hacker can be found. The world stays in daylight.

## Start

Open `/home/antonio/Paprika/project.godot` in Godot 4.7 or newer and press **F5 in the editor** to run the project, or run from a terminal:

```bash
godot --path /home/antonio/Paprika
```

The source map is `/home/antonio/Paprika/maps/paprika.tmj`. This is the playable map, not the smaller `maps/concepts/paprika_first_view.tmj` used for the original concept image.

### Controls

| Key | Action |
| --- | --- |
| WASD / arrow keys | Walk |
| E | Interact, harvest, speak, or **catch** a rabbit |
| Space | Attack with the equipped weapon; **hunt** a rabbit for meat |
| I | Open inventory, use food, or change equipment |
| J | View active jobs, choose one to track, or abandon a job |
| H | Eat bread (or stew) to restore health |
| F5 | Save |
| F9 | Load the saved game |
| Esc | Close a menu, pause, or resume |

**Rabbit hunting and catching are different.** Catching a rabbit with **E** counts toward the five-rabbit work-office job; attacking a rabbit gives meat instead. The food shop buys rabbit meat. Rabbits respawn after a short interval, so the job remains possible. The on-screen interaction prompt appears within about 45 pixels of a rabbit.

### First things to try

1. Follow the road north from the village square to the **WORK** office and accept **Help in the Common Fields**.
2. Harvest five crops with **E** in the common fields south and southwest of the square. Private plots do not count and cannot be harvested.
3. Return to the work office to claim **10 gold**. Crops regrow after **120 seconds** of unpaused play.
4. Accept the rabbit-catching job and a mercenary job at the same time. Each job keeps its own progress; press **J** to view them all, choose which one the HUD tracks, or abandon one. Claim each completed job at the office that offered it. A stick is starting equipment; the forge sells swords, spears, and bows. The clothing shop sells clothing and armor. Armor reduces attack damage by 1, 2, or 3 points depending on its tier.
5. Sell crops or rabbit meat at the food shop. Enter at the shop's door; the private crops are farther north, away from the building. The level-five hacker is intentionally much stronger than starting equipment.
6. Visit the travel agency near the landing pad. It quotes a **1,000-gold** fare, but other planets are not built yet: opening it never takes gold.

Matching dark plaques identify the FOOD, FORGE, WORK, MERCENARY, CLOTHES, and TRAVEL services; visit the door to open a menu. Wooden **COMMON** signs and fences mark public fields; **PRIVATE** marks gardens that cannot be harvested. The fence openings are the entrances. **FOREST** signs show routes into the woods, while **DANGER** marks the darker forest where enemies may be nearby. The wooden signs are landmarks, not interaction points.

There are **25 active villagers**. Some visit and work around the fields. Villagers and the player do not have an experience-level system yet: a displayed level describes relative fighting ability, while equipment provides the current player progression.

## Editing the world and art

Open the live map in Tiled:

```bash
tiled /home/antonio/Paprika/maps/paprika.tmj
```

The finite orthogonal Tiled JSON map references external `.tsj` tilesets and individual PNG sprites. Terrain uses 16×16 tiles. The game reads the `.tmj` and `.tsj` files at startup, so changing a supported tile or object and restarting the game changes the playable world. The layers **Common Fields** and **Private Fields** decide whether harvesting is allowed. The **Field Boundaries and Forest Details** layer draws fence tiles and forest debris; its intact fence tiles block movement, so keep openings when editing a field. New named shops or enemies also need a matching rule in `scripts/world/tiled_loader.gd` and, for shops, `scripts/ui/game_ui.gd`.

The art is original and local. Open `art/concepts/paprika_tileset.aseprite` for the first terrain tiles. The new building, enemy, and clothing `.aseprite` files are under `assets/art/`, and the PNGs used by Tiled and Godot are beside them. LibreSprite opens either kind:

```bash
sprite /home/antonio/Paprika/art/concepts/paprika_tileset.aseprite
sprite /home/antonio/Paprika/assets/art/clothing_shop.aseprite
```

Original image reference: `art/concepts/paprika_first_view.png`. Larger map preview: `art/concepts/paprika_world_layout.png`. These are reference images; the game renders separate tiles, characters, crops, and buildings rather than displaying a single static image.

`tools/create_paprika_concept.py`, `tools/create_extra_art.py`, and `tools/build_paprika_world.py` generated the first versions. **Do not rerun these generators over manually edited art or maps** unless you intend to replace the changes. `tools/render_tiled_map.py` can render a map image without changing the map itself:

```bash
/usr/bin/python3 /home/antonio/Paprika/tools/render_tiled_map.py /home/antonio/Paprika/maps/paprika.tmj /tmp/paprika-preview.png
```

## Testing

```bash
godot --headless --path /home/antonio/Paprika --editor --quit
godot --headless --path /home/antonio/Paprika --script res://tests/run_tests.gd
TEST_HOME=$(mktemp -d /tmp/paprika-worldtest.XXXXXX)
XDG_DATA_HOME="$TEST_HOME" godot --headless --path /home/antonio/Paprika --quit-after 600 res://tests/world_smoke.tscn
```

The world smoke test writes a save file, so always run it with an isolated `XDG_DATA_HOME` as shown. Normal game saves go to Godot's `user://paprika_save.json`; F5 writes a previous-save backup alongside it, and F9 restores the save. Schema-one saves load with their active mission and progress intact; the next F5 writes schema two with all active missions and their tracked selection. Saving does not overwrite the Tiled map or sprite files.

## This version's boundaries

Paprika is the only playable planet. Buildings are exterior interaction points without indoor scenes. Daylight does not change. NPC conversations, routines, equipment, the economy, and combat are prototype systems that can be extended; there is no multiplayer, spaceship flight, Block modification system, or playable New Republic yet.
