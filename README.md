# Craft — Paprika and Brudet

A playable, single-player pixel-art prototype across two flat planets. Paprika, in the Cauliflower Confederation, has an original village and a more advanced northern village separated by a long forest road. Wolves and zombies can be seen near the road; rabbits, bandits, and a level-five hacker also inhabit the forest. Brudet is a river planet with a larger city, lakes, fishermen, bridges, markets, and fishlike monsters. Both worlds stay in daylight.

## Start

Open `/home/antonio/Paprika/project.godot` in Godot 4.7 or newer and press **F5 in the editor** to run the project, or run from a terminal:

```bash
godot --path /home/antonio/Paprika
```

The playable Tiled source maps are `maps/paprika.tmj` and `maps/brudet.tmj`. The smaller `maps/concepts/paprika_first_view.tmj` was used for the original concept image, not the running game.

### Controls

| Key | Action |
| --- | --- |
| WASD / arrow keys | Walk |
| E | Interact, harvest, speak, or **catch** a rabbit |
| Space | Attack with the equipped weapon; **hunt** a rabbit for meat |
| I | Open inventory, use food, or change equipment |
| J | View active jobs, choose one to track, or abandon a job |
| H | Eat an available food item to restore health |
| 1 / 2 / 3 | Control yourself / first recruit / second recruit after deploying |
| Q / R / T | Tell the other squad members to follow / hold / attack nearby enemies |
| F5 | Save |
| F6 | Add 100,000 gold for testing (debug builds only) |
| F9 | Load the saved game |
| Esc | Close a menu, pause, or resume |

In a debug build, press **F6** to add testing gold, then **F5** if you want it in your save. Release builds do not have the F6 shortcut.

**Rabbit hunting and catching are different.** Catching a rabbit with **E** counts toward the five-rabbit work-office job; attacking a rabbit gives meat instead. The food shop buys rabbit meat. Rabbits respawn after a short interval, so the job remains possible. The on-screen interaction prompt appears within about 45 pixels of a rabbit.

### First things to try

1. Follow the road north from the village square to the **WORK** office and accept **Help in the Common Fields**.
2. Harvest five crops with **E** in the common fields south and southwest of the square. Private plots do not count and cannot be harvested.
3. Return to the work office to claim **10 gold**. Crops regrow after **120 seconds** of unpaused play.
4. Accept the rabbit-catching job and a mercenary job at the same time. Each job keeps its own progress; press **J** to view them all, choose which one the HUD tracks, or abandon one. Claim each completed job at the office that offered it. A stick is starting equipment; both forges sell wooden and bronze swords, spears, and bows. The more advanced northern forge also sells iron weapons and armor; the clothing shops sell outfits and lighter armor. Armor reduces attack damage by 1, 2, or 3 points depending on its tier.
5. Sell crops or rabbit meat at the food shop. Enter at the shop's door; the private crops are farther north, away from the building. The level-five hacker is intentionally much stronger than starting equipment.
6. After defeating the hacker, return to the **MERCENARY** center and accept **Clear the Bandit Camp**. Choose exactly two villagers from its named roster; each choice shows a stable villager ID, so villagers with the same name can be distinguished. Before deploying, you can dismiss and replace either recruit. Recruits start with militia clubs; assign weapons or armor you own from the mercenary menu. Each equipped item needs its own copy in your inventory, including items equipped by you. Shops have separate **Equip** and **Buy another** actions, so you can purchase a sword or armor piece for each recruit.
7. Deploy the three-person squad and head for the camp in the northwest forest. Press **1/2/3** to switch the character you control. **Q** orders the others to follow, **R** to hold, and **T** to attack nearby enemies; these shortcuts do not act while a menu is open. The HUD shows squad health, orders, and recovery. A fallen recruit returns after a short recovery. Once all **three distinct camp bandits** are defeated, return to the mercenary center to claim the reward. A deployed camp mission cannot be abandoned.
8. Follow the road north through the forest to the second village. Watch for monsters among the trees; the path leads into the northern square. Visit its food shop for rye bread, berry pie and smoked fish; its clothier for purple cloth and a purple tunic; and its forge for iron weapons and armor. Both spaceships and Paprika's sole travel agency are in the northern village. **Visit Brudet** costs **1,000 gold**; opening the agency or attempting to travel without enough gold costs nothing. Finish a deployed bandit-camp squad mission before leaving Paprika. Return from Brudet is free.
9. On Brudet, visit the central market to buy a **fishing rod**, fish stew, olive bread, and citrus. Press **E** beside a fishing pond to catch river fish; a short cooldown separates catches. The market buys fish and offers a three-fish job. Follow the stone bridges across the river: open water is impassable. The green Military Headquarters offers a river-monster patrol and has a practice arrow target beside it. Read the library's Craft history and local guidance, then use the Brudet agency to return to your saved Paprika position.

Matching plaques identify FOOD, FORGE, WORK, MERCENARY, CLOTHES, and TRAVEL services; visit a door to open its menu. The northern village has taller houses, its own fountain square, and a landing area for both ships. A long forest road links the two settlements. Wooden **COMMON** signs and fences mark public fields in both villages; **PRIVATE** marks gardens that cannot be harvested. Fence openings are the entrances. **FOREST** signs show routes into the woods, while **DANGER** marks the darker forest where enemies may be nearby. Wooden signs are landmarks, not interaction points.

There are **40 active villagers: 15 in the original village and 25 in the north**. Farmers work their own village's common-field rows and take breaks; other residents carry out local errands at shops, the work office, and the village squares. Their small gestures and conversation reflect what they do. Recruited villagers pause those errands while deployed with the squad and resume when released. Villagers and the player do not have an experience-level system yet: a displayed level describes relative fighting ability, while equipment provides the current player progression.

## Editing the world and art

Open the live map in Tiled:

```bash
tiled /home/antonio/Paprika/maps/paprika.tmj
tiled /home/antonio/Paprika/maps/brudet.tmj
```

Both finite orthogonal Tiled JSON maps reference external `.tsj` tilesets and PNG art. Terrain uses 16×16 tiles. The game reads the `.tmj` and `.tsj` files at startup, so changing a supported tile or object and restarting changes the playable world. The layers **Common Fields** and **Private Fields** decide whether harvesting is allowed. Paprika's **Field Boundaries and Forest Details** layer draws fence tiles and debris; intact fence tiles block movement, so keep openings when editing a field. Brudet's **Water** layer blocks movement wherever it has a tile; leave bridge-deck cells empty in that layer. New named shops or enemies also need matching rules in `scripts/world/tiled_loader.gd` and, for shops, `scripts/ui/game_ui.gd`. The Paprika bandit camp marker and its three mission enemies appear dynamically only after squad deployment; they are not permanent Tiled objects in the editable map.

The art is original and local. Open `art/concepts/paprika_tileset.aseprite` for the first terrain tiles. Buildings, enemies, clothing, and Brudet river art have editable `.aseprite` files under `assets/art/`, including `assets/art/northern_village/` and `assets/art/river_planet/`; the PNGs used by Tiled and Godot are beside them. LibreSprite opens either kind:

```bash
sprite /home/antonio/Paprika/art/concepts/paprika_tileset.aseprite
sprite /home/antonio/Paprika/assets/art/clothing_shop.aseprite
```

Map references: `art/concepts/paprika_first_view.png`, `art/concepts/paprika_world_layout.png`, and `art/concepts/brudet_world_layout.png`. The game renders separate tiles, characters, crops, and buildings rather than displaying these static previews.

### Paprika map

The full playable map shows the original village to the south, the forest road, and the northern village with its travel agency and two ships.

![Full Paprika map with both villages and the forest between them](art/concepts/paprika_world_layout.png)

### Brudet map

The full playable map shows the river city, lake, fields, and two bridges across the river.

![Full Brudet map with the river, lake, bridges, and city](art/concepts/brudet_world_layout.png)

`tools/create_paprika_concept.py`, `tools/create_extra_art.py`, and `tools/build_paprika_world.py` generated Paprika's first versions. `tools/build_brudet_world.py` generated Brudet's initial map. **Do not rerun these generators over manually edited art or maps** unless you intend to replace the changes. `tools/render_tiled_map.py` can render either map without changing it:

```bash
/usr/bin/python3 /home/antonio/Paprika/tools/render_tiled_map.py /home/antonio/Paprika/maps/brudet.tmj ~/Pictures/brudet-preview.png
```

## Testing

```bash
godot --headless --path /home/antonio/Paprika --editor --quit
TEST_HOME=$(mktemp -d)
XDG_DATA_HOME="$TEST_HOME" godot --headless --path /home/antonio/Paprika --script res://tests/run_tests.gd
XDG_DATA_HOME="$TEST_HOME" godot --headless --path /home/antonio/Paprika --quit-after 700 res://tests/world_smoke.tscn
XDG_DATA_HOME="$TEST_HOME" godot --headless --path /home/antonio/Paprika --quit-after 700 res://tests/brudet_smoke.tscn
```

World smoke tests write save files, so run them with an isolated `XDG_DATA_HOME` as shown. Normal game saves go to Godot's `user://paprika_save.json`; F5 writes a previous-save backup alongside it, and F9 restores the save, including the current planet, the player's position on each planet, fishing cooldown, and Paprika squad progress. Schema-one through schema-four saves migrate when loaded, including Paprika positions and field regrowth across the longer forest map; the next F5 writes schema five. Saving does not overwrite Tiled maps or sprite files.

## This version's boundaries

Paprika and Brudet are playable exterior worlds. Buildings are interaction points without indoor scenes. Daylight does not change. NPC conversations, routines, equipment, the economy, and combat are prototype systems that can be extended; there is no multiplayer, spaceship flight, Block modification system, or playable New Republic yet.
