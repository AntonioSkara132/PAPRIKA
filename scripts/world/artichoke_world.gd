class_name ArtichokeWorld
extends GameWorld

## Artichoke: a tundra planet where the Cauliflower Confederation holds the high
## ground (Cauliflower Base) and the New Republic holds the walled base, the
## occupied village to the southeast and a two-cannon battery in the southwest.
##
## A new arrival goes through a chain of missions, saved as flags in
## GameState.defeated_persistent_enemies (see story_stage):
## 1. Report to Captain Vela, then draw a bow, a spear, field mines and bandages
##    at the Arms building east of the barracks.
## 2. Mine duty: plant a field mine on each of three marked spots below the cliffs
##    while the Republic battery shells them.
## 3. Trench assault: with six soldiers, storm the Republic forward trench west of
##    the occupied village; it is won when one marked Republic soldier falls.
##    Captain Vela then promotes the player to Officer.
## 4. The trench raid on the battery and 5. the counterattack defense, below.
## 6. Captain Vela deserts; General Hickey takes her place and sends the player
##    with six soldiers to mine the Republic warships at the airfield: one field
##    mine destroys an escort, the flagship needs three.
## 7. Back at the base General Hickey praises the player, promotes them to Captain
##    and sends them to the Council on Pomidor, the Confederation capital.
## The Mess beside the Arms building heals the player fully between missions.
## Saves from before the chain existed count a destroyed cannon as steps 1 to 3 done.
##
## The battery shells the Confederation trenches until both of its cannons are
## destroyed. Captain Vela at Cauliflower Base sends the player on a trench raid
## with six soldiers who take Q (follow), R (hold) and T (attack) orders. Planting
## a charge on a cannon (E) or wearing it down with arrows and blows destroys it;
## destroyed cannons are saved. The raid fails when the player is defeated or all six soldiers are down.
##
## The red-marked ground in no man's land is mined, barbed wire slows anyone
## crossing it, and soldiers in or beside a trench are hard to hit from afar.
##
## Once the battery is silenced the Republic counterattacks: four waves march
## from the airfield to the two ramps up to Cauliflower Base, the west ramp and the
## east stairs. The first wave takes one ramp; the later waves split between both,
## and each announcement names the ramps. After the third wave Captain Vela sends
## fresh soldiers to replace the fallen before the largest wave comes. The player
## holds the trenches with the six-soldier squad while Confederation cannons shell
## the attackers. Three Republic soldiers reaching the ramp tops, the player's
## defeat or all six defenders down lose the defense; beating every wave is saved.
##
## During the defense the player can also type orders (Enter). The squad starts in
## three groups, bowmen, spearmen and swordsmen, and the orders name groups,
## soldiers and three places: the west ramp, the east stairs and the centre
## trench. "mark here as NAME" adds a place where the player stands, up to five,
## and "forget NAME" removes it; both are handled in this world. The local order
## service interprets the other orders with the same rules as the soldier
## sandbox, where the places are landmarks A to H; this world checks the reply
## again and turns it into hold, patrol, follow or attack tasks.

const ARTICHOKE_MAP := "res://maps/artichoke.tmj"
const OFFICER_SERVICE := "artichoke_officer"
const OFFICER_NAME := "Captain Vela"
## General Hickey replaces Captain Vela once the counterattack is beaten.
const GENERAL_NAME := "General Hickey"
const GENERAL_TEXTURE := "res://assets/art/space_military_base/confederation_officer.png"
const MESS_SERVICE := "artichoke_mess"
const REPORTED_FLAG := "artichoke_reported"
const KIT_FLAG := "artichoke_kit_drawn"
const MINES_FLAG := "artichoke_mines_laid"
## Winning the trench assault also promotes the player to Officer.
const ASSAULT_FLAG := "artichoke_assault_won"
const SHIP_FLAG := "artichoke_ship_%d_destroyed"
const FLEET_FLAG := "artichoke_fleet_destroyed"
## Set when General Hickey's debrief after the fleet strike is read; the player is a Captain.
const CAPTAIN_FLAG := "artichoke_captain"
## The kit's bow, spear and armor; the Arms building replaces any the player lost.
const KIT_GEAR := ["service_bow", "iron_spear", "wood_armor"]
## Field mines the Arms building tops the player up to; the fleet strike needs six.
const KIT_MINES := 3
const FLEET_MINES := 6
## Mines the Arms building issues for the counterattack, counting the ones already
## buried for it. Mines that go off are replaced; mines still in the ground are not.
const DEFENSE_MINES := 6
const KIT_BANDAGES := 2
## Mine duty: plant a field mine within MINE_SPOT_RADIUS of each spot.
const MINE_DUTY_SPOTS := [Vector2(272, 488), Vector2(416, 528), Vector2(608, 480)]
const MINE_SPOT_RADIUS := 16.0
const MINE_DUTY_REWARD := 60
## Republic soldiers in the forward trench during the assault, by post.
const ASSAULT_POSTS := [Vector2(1000, 618), Vector2(1048, 618), Vector2(1080, 618), Vector2(1128, 602), Vector2(1160, 602), Vector2(1192, 602)]
const ASSAULT_KINDS := ["republic_archer", "republic_spearman", "republic_archer", "republic_swordsman", "republic_archer", "republic_spearman"]
const ASSAULT_REWARD := 100
## Guards around the warships during the fleet strike.
const FLEET_GUARD_POSTS := [Vector2(480, 1016), Vector2(576, 1008), Vector2(704, 1016), Vector2(800, 1032), Vector2(672, 1072), Vector2(752, 1152)]
const FLEET_GUARD_KINDS := ["republic_archer", "republic_spearman", "republic_swordsman", "republic_archer", "republic_swordsman", "republic_archer"]
const FLEET_REWARD := 300
const RAID_SIZE := 6
const RAID_REWARD := 150
const RAID_NAMES := ["Brannock", "Ilse", "Corwin", "Petra", "Dusan", "Maren"]
const RAID_TEXTURES := [
	"res://assets/art/artichoke/objects/front_soldier.png",
	"res://assets/art/artichoke/objects/front_soldier_2.png",
	"res://assets/art/artichoke/objects/front_soldier_3.png",
	"res://assets/art/artichoke/objects/front_soldier_4.png",
	"res://assets/art/artichoke/objects/front_soldier_5.png",
	"res://assets/art/artichoke/objects/front_soldier_6.png",
]
## The raid squad's weapons by slot: three archers, two spearmen and a swordsman.
const RAID_WEAPONS := ["bow", "bow", "spear", "bow", "sword", "spear"]
const CANNON_FLAG := "artichoke_cannon_%d_destroyed"
const BATTERY_CENTER := Vector2(250, 875)
const AIRFIELD := Vector2(648, 1030)
const REINFORCEMENTS := 3
## Reinforcements leave the airfield when the player comes this close to the battery.
const REINFORCEMENT_TRIGGER := 280.0
## Republic shells land around these points in the Confederation trenches.
const REPUBLIC_SHELL_TARGETS := [Vector2(290, 248), Vector2(480, 232), Vector2(500, 280), Vector2(620, 296), Vector2(150, 360), Vector2(680, 184)]
## Confederation counter-fire lands around these points in the Republic base.
const COUNTER_FIRE_TARGETS := [Vector2(1150, 880), Vector2(1300, 950), Vector2(1080, 1010), Vector2(1350, 720), Vector2(900, 1090), Vector2(1220, 560)]
const SHELL_SPREAD := 40.0
const SHELL_RADIUS := 30.0
const SHELL_DAMAGE := 12
const SHELL_WARNING := 2.2
const CHARGE_FUSE := 4.0
const CHARGE_RADIUS := 36.0
const CHARGE_DAMAGE := 20
const MINE_RADIUS := 30.0
const MINE_DAMAGE := 16
## Each red marker covers three buried mines.
const MINEFIELD_OFFSETS := [Vector2.ZERO, Vector2(-14, 7), Vector2(14, -7)]
const WIRE_FACTOR := 0.4
## Shots from farther than this at a soldier in or beside a trench may hit the parapet.
const COVER_DISTANCE := 56.0
const TRENCH_COVER_CHANCE := 0.7
const DEFENSE_FLAG := "artichoke_counterattack_repelled"
const DEFENSE_REWARD := 200
const DEFENSE_WAVES := [
	["republic_swordsman", "republic_spearman", "republic_archer", "republic_archer"],
	["republic_swordsman", "republic_swordsman", "republic_spearman", "republic_archer", "republic_archer", "republic_archer"],
	["republic_swordsman", "republic_swordsman", "republic_spearman", "republic_spearman", "republic_archer", "republic_archer", "republic_archer", "republic_archer"],
	["republic_swordsman", "republic_swordsman", "republic_swordsman", "republic_swordsman", "republic_spearman", "republic_spearman", "republic_spearman", "republic_spearman", "republic_archer", "republic_archer", "republic_archer", "republic_archer"],
]
## Ramp tops the attackers march for: the west ramp and the east stairs.
const BREACH_POINTS := [Vector2(176, 330), Vector2(830, 300)]
const BREACH_NAMES := ["the west ramp", "the east stairs"]
## The ramps each wave attacks, as indexes into BREACH_POINTS. A wave with two
## ramps sends its soldiers to them in turn, so each ramp gets half.
const WAVE_RAMPS := [[0], [0, 1], [1, 0], [0, 1]]
const BREACH_DISTANCE := 24.0
const BREACH_LIMIT := 3
const FIRST_WAVE_DELAY := 15.0
const WAVE_GAP := 8.0
## After this wave is beaten (counting from 1), fresh soldiers replace the fallen
## and the pause before the next wave is longer so they can reach the trenches.
const RELIEF_AFTER_WAVE := 3
const RELIEF_GAP := 16.0
## Names of the fresh soldiers by squad slot.
const RELIEF_NAMES := ["Halvard", "Sigrun", "Oskar", "Teodor", "Liesl", "Anselm"]
## Places typed orders can name, as the order service's landmark letters. The
## player can add more as D to H (see order_places).
const ORDER_PLACES := {"A": Vector2(176, 330), "B": Vector2(830, 300), "C": Vector2(500, 300)}
const ORDER_PLACE_NAMES := {"A": "west ramp", "B": "east stairs", "C": "centre trench"}
const CUSTOM_PLACE_LETTERS := ["D", "E", "F", "G", "H"]
## Words a place name may not contain, because orders use them for other things.
const RESERVED_PLACE_WORDS := ["all", "everyone", "everybody", "soldier", "soldiers", "group", "here", "there", "me", "you", "us", "line", "patrol", "stop", "halt", "hold", "attack", "charge", "follow", "move", "go", "to", "and", "between", "from", "at", "mark", "forget"]
## Phrases replaced by a landmark letter before the text goes to the order service,
## which knows places only by letter. Longer phrases come first.
const ORDER_PLACE_PHRASES := [
	["(the )?west (ramp|side)", "A"], ["(the )?east (stairs|stair|side)", "B"],
	["(the )?(centre|center|middle)( trench)?", "C"], ["(the )?west", "A"], ["(the )?east", "B"], ["(the )?stairs", "B"], ["(the )?ramp", "A"],
]
## The starting groups by weapon. Typed orders may create up to five more.
const STARTING_GROUPS := {"bowmen": "bow", "spearmen": "spear", "swordsmen": "sword"}
const GROUP_WORDS := {"archers": "bowmen", "archer": "bowmen", "bowman": "bowmen", "swordmen": "swordsmen", "swordsman": "swordsmen", "spearman": "spearmen", "spears": "spearmen", "swords": "swordsmen", "bows": "bowmen"}

var raid_active := false
var defense_active := false
var mine_duty_active := false
var assault_active := false
var ships_active := false
## Chance that a long shot at an entrenched soldier is stopped by the trench.
var cover_chance := TRENCH_COVER_CHANCE
var _pending_soldiers: Array[Dictionary] = []
var _garrison_posts: Array[Dictionary] = []
var _battlefield: Node2D
var _rng := RandomNumberGenerator.new()
var _trench_cells: Dictionary = {}
var _wire_rects: Array[Rect2] = []
var _cannons: Array[BatteryCannon] = []
var _raid_soldiers: Array[RaidSoldier] = []
var _republic_units: Array[Enemy] = []
var _reinforcements_sent := false
var _raid_order := "follow"
var _shell_timer := 0.0
var _counter_timer := 0.0
var _officer: FrontSoldier
var _placed_mines := 0
var _wave_units: Array[Enemy] = []
var _wave_index := 0
var _wave_timer := 0.0
var _breaches := 0
var _support_timer := 0.0
## Named groups of squad order IDs for typed orders. "soldier_01" is the soldier
## in slot 0: RAID_NAMES[0], or RELIEF_NAMES[0] after a replacement.
var squad_groups: Dictionary = {}
var order_client: SquadOrderClient
var _place_markers: Node2D
## Every place typed orders can name: ORDER_PLACES plus the ones the player
## marked. Marked places last until the game is closed; they are not saved.
var order_places: Dictionary = ORDER_PLACES.duplicate()
var order_place_names: Dictionary = ORDER_PLACE_NAMES.duplicate()
## Mine-duty spots on open ground, and which ones have a mine. Laid spots last
## until the game is closed, so a retry after a fall only needs the rest.
var mine_spots: Array[Vector2] = []
var _mine_spots_done: Array[bool] = []
var _mine_spot_markers: Node2D
var _officer_home := Vector2.ZERO
var _assault_units: Array[Enemy] = []
var _assault_target: Enemy
var _warships: Array[RepublicWarship] = []
var _fleet_guards: Array[Enemy] = []

func _ready() -> void:
	add_to_group("game_world")
	_rng.seed = 7203
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	tiled_loader.service_requested.connect(_on_service_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(ARTICHOKE_MAP):
		push_error("Artichoke map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	_battlefield = Node2D.new()
	_battlefield.name = "Battlefield"
	add_child(_battlefield)
	_read_trench_cells()
	_spawn_front_soldiers()
	_build_battery()
	_build_warships()
	_build_mine_spots()
	_build_minefields()
	_build_wire()
	if player == null:
		_spawn_player(GameState.ARTICHOKE_ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	_spawn_garrison()
	_shell_timer = _rng.randf_range(4.0, 8.0)
	_counter_timer = _rng.randf_range(9.0, 14.0)

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, stable_id: String) -> void:
	if kind in ["front_soldier", "republic_soldier", "confederation_officer", "confederation_cook"]:
		# Spawned after loading so every soldier stands on the finished navigation grid.
		_pending_soldiers.append({"kind": kind, "position": position, "texture": variant, "id": stable_id})
	elif kind == "republic_battery_soldier":
		_garrison_posts.append({"position": position, "texture": variant, "id": stable_id})
	else:
		super._on_actor_spawn_requested(kind, position, variant, stable_id)

func _spawn_front_soldiers() -> void:
	for data in _pending_soldiers:
		if data["kind"] == "confederation_officer":
			_officer_home = Vector2(data["position"])
			_spawn_officer(String(data["id"]), String(data["texture"]))
			continue
		var soldier := FrontSoldier.new()
		soldier.name = String(data["id"])
		var side := "republic" if data["kind"] == "republic_soldier" else "confederation"
		soldier.configure(String(data["id"]), side, String(data["texture"]), Vector2(data["position"]))
		if data["kind"] == "confederation_cook":
			soldier.offer_service(MESS_SERVICE, "Mess")
		actors_root.add_child(soldier)
	_pending_soldiers.clear()

## Puts Captain Vela at the officer's spot, or General Hickey once the
## counterattack is beaten. `texture` is Vela's sprite from the map.
func _spawn_officer(id: String, texture: String) -> void:
	var general := counterattack_repelled()
	if _officer != null:
		_officer.queue_free()
	var soldier := FrontSoldier.new()
	soldier.name = "General_Hickey" if general else id
	soldier.configure("artichoke_general" if general else id, "confederation", GENERAL_TEXTURE if general else texture, _officer_home)
	soldier.offer_service(OFFICER_SERVICE, officer_name())
	soldier.set_meta("vela_id", id)
	soldier.set_meta("vela_texture", texture)
	actors_root.add_child(soldier)
	_officer = soldier

## Swaps Vela for General Hickey, or back after loading an older save.
func _refresh_officer() -> void:
	if _officer == null or _officer.service_name == officer_name():
		return
	_spawn_officer(String(_officer.get_meta("vela_id")), String(_officer.get_meta("vela_texture")))

func officer_name() -> String:
	return GENERAL_NAME if counterattack_repelled() else OFFICER_NAME

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = GameState.ARTICHOKE_ARRIVAL
	player.respawn_location_name = "Cauliflower Base"

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if tiled_loader.is_walkable_position(saved):
		return saved
	return _nearby_open_position(GameState.ARTICHOKE_ARRIVAL)

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
		player.hold_field_mine(false)
	# A raid is not saved: loading puts the squad back in the base and the battery
	# back to its saved state.
	if raid_active:
		_end_raid("")
	if defense_active:
		_end_defense("")
	if mine_duty_active:
		_end_mine_duty()
	if assault_active:
		_end_assault("")
	if ships_active:
		_end_ships("")
	for index in _warships.size():
		if GameState.defeated_persistent_enemies.has(SHIP_FLAG % index):
			_warships[index].show_wrecked()
		else:
			_warships[index].restore()
	_refresh_officer()
	for index in _cannons.size():
		var cannon := _cannons[index]
		if GameState.defeated_persistent_enemies.has(CANNON_FLAG % index):
			cannon.show_wrecked()
		else:
			cannon.restore()
	_restore_garrison()
	_refresh_front_hud()

func soldiers(side: String) -> Array[FrontSoldier]:
	var found: Array[FrontSoldier] = []
	for actor in actors_root.get_children():
		if actor is FrontSoldier and actor.side == side:
			found.append(actor)
	return found

func officer() -> FrontSoldier:
	return _officer

func cannons() -> Array[BatteryCannon]:
	return _cannons

func raid_soldiers() -> Array[RaidSoldier]:
	return _raid_soldiers

func republic_units() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for unit in _republic_units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			alive.append(unit)
	return alive

# --- Map features -------------------------------------------------------------

func _read_trench_cells() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(ARTICHOKE_MAP))
	if not raw is Dictionary:
		return
	for property in raw.get("properties", []):
		if property is Dictionary and property.get("name", "") == "trench_cells":
			for pair in String(property.get("value", "")).split(";", false):
				var parts := pair.split(",")
				if parts.size() == 2:
					_trench_cells[Vector2i(int(parts[0]), int(parts[1]))] = true

func _cell_at(world_position: Vector2) -> Vector2i:
	var local := tiled_loader.to_local(world_position)
	return Vector2i(floori(local.x / tiled_loader.tile_size.x), floori(local.y / tiled_loader.tile_size.y))

## True when the position is in a trench or on a tile next to one.
func in_trench(world_position: Vector2) -> bool:
	var cell := _cell_at(world_position)
	for y in range(-1, 2):
		for x in range(-1, 2):
			if _trench_cells.has(cell + Vector2i(x, y)):
				return true
	return false

## Called by projectiles before they hurt someone. A long shot at a soldier in or
## beside a trench hits the parapet `cover_chance` of the time.
func shot_blocked(origin: Vector2, target_position: Vector2) -> bool:
	if origin.distance_to(target_position) <= COVER_DISTANCE or not in_trench(target_position):
		return false
	return _rng.randf() < cover_chance

func show_cover_hit(at: Vector2) -> void:
	var puff := Polygon2D.new()
	puff.polygon = ArtilleryShell.circle(4.0, 8)
	puff.color = Color(0.86, 0.84, 0.78, 0.85)
	puff.position = at
	puff.z_index = 960 + int(at.y)
	_battlefield.add_child(puff)
	var tween := puff.create_tween()
	tween.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.25)
	tween.parallel().tween_property(puff, "modulate:a", 0.0, 0.25)
	tween.tween_callback(puff.queue_free)

func _build_wire() -> void:
	for holder in tiled_loader.map_objects("barbed_wire"):
		var size := TiledLoader.map_object_size(holder)
		var rect := Rect2(holder.global_position + Vector2(2, 4), size - Vector2(4, 4))
		_wire_rects.append(rect)
		for y in range(floori(rect.position.y / 16.0), floori(rect.end.y / 16.0) + 1):
			for x in range(floori(rect.position.x / 16.0), floori(rect.end.x / 16.0) + 1):
				tiled_loader.set_walk_cost(Vector2(x * 16 + 8, y * 16 + 8), 3.0)

func movement_factor(at: Vector2) -> float:
	for rect in _wire_rects:
		if rect.has_point(at):
			return WIRE_FACTOR
	return 1.0

func _build_minefields() -> void:
	for holder in tiled_loader.map_objects("trap_marker"):
		var center := holder.global_position + TiledLoader.map_object_size(holder) * 0.5
		for offset in MINEFIELD_OFFSETS:
			var mine := FieldMine.new()
			mine.name = "Minefield_%d" % _battlefield.get_child_count()
			mine.set_meta("marker", holder)
			_battlefield.add_child(mine)
			mine.configure(center + offset, "minefield", 0.0, false)
			mine.triggered.connect(_on_mine_triggered)
			_set_mine_cost(mine.global_position, 25.0)

func minefield_mines() -> Array[FieldMine]:
	var found: Array[FieldMine] = []
	for child in _battlefield.get_children():
		if child is FieldMine and child.side == "minefield" and not child.is_queued_for_deletion():
			found.append(child)
	return found

func _set_mine_cost(at: Vector2, weight: float) -> void:
	for offset in [Vector2.ZERO, Vector2(-12, 0), Vector2(12, 0), Vector2(0, -12), Vector2(0, 12)]:
		tiled_loader.set_walk_cost(at + offset, weight)

func _on_mine_triggered(mine: FieldMine) -> void:
	if not is_instance_valid(mine) or not mine.armed:
		return
	mine.armed = false
	var at := mine.global_position
	var marker: Node2D = mine.get_meta("marker") if mine.has_meta("marker") else null
	mine.queue_free()
	if mine.side == "minefield":
		_set_mine_cost(at, 1.0)
		var remaining := 0
		for other in minefield_mines():
			if other != mine and other.has_meta("marker") and other.get_meta("marker") == marker:
				remaining += 1
		if remaining == 0 and is_instance_valid(marker):
			marker.visible = false
		_blast(at, MINE_RADIUS, MINE_DAMAGE, true, true)
		GameState.notify("A mine went off in no man's land!")
	else:
		_blast(at, MINE_RADIUS, MINE_DAMAGE + 6, false, true)

## Arms or puts away a field mine in the player's hand; Space then plants it.
func set_field_mine_ready(ready: bool) -> bool:
	if player == null:
		return false
	if ready and int(GameState.inventory.get("field_mine", 0)) <= 0:
		GameState.notify("You have no field mines. The Arms building east of the barracks issues them.")
		return false
	player.hold_field_mine(ready)
	GameState.notify("Field mine in hand: press Space to plant it." if ready else "Field mine put away.")
	return true

func place_field_mine() -> bool:
	var stage := story_stage()
	# Mine duty mines go only on the marked spots, so none of the three is wasted.
	if player != null and stage in ["kit", "mines"] and _open_spot_near(player.global_position) < 0:
		GameState.notify("Plant your mines on the marked spots during mine duty." if mine_duty_active else "Keep your mines for the duty; %s will show you where they go." % OFFICER_NAME)
		return false
	if player == null or not GameState.remove_item("field_mine"):
		if player != null:
			player.hold_field_mine(false)
		GameState.notify("You have no field mines left.")
		return false
	var mine := FieldMine.new()
	_placed_mines += 1
	mine.name = "PlacedMine_%d" % _placed_mines
	mine.set_meta("stage", stage)
	_battlefield.add_child(mine)
	mine.configure(player.global_position, "confederation", 1.5, true)
	mine.triggered.connect(_on_mine_triggered)
	var left := int(GameState.inventory.get("field_mine", 0))
	if left == 0:
		player.hold_field_mine(false)
	GameState.notify("Field mine planted; it arms in a moment. Only Republic boots set it off. %d left." % left)
	if mine_duty_active:
		_check_mine_spot(mine.global_position)
	return true

func placed_mines() -> Array[FieldMine]:
	var found: Array[FieldMine] = []
	for child in _battlefield.get_children():
		if child is FieldMine and child.side == "confederation" and not child.is_queued_for_deletion():
			found.append(child)
	return found

# --- Battery and artillery ----------------------------------------------------

func _build_battery() -> void:
	var holders := tiled_loader.map_objects("republic_cannon")
	holders.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	for index in holders.size():
		var cannon := BatteryCannon.new()
		cannon.name = "RepublicCannon_%d" % index
		actors_root.add_child(cannon)
		cannon.configure("artichoke_cannon_%d" % index, holders[index], TiledLoader.map_object_size(holders[index]))
		cannon.destroyed.connect(_on_cannon_destroyed.bind(index))
		if GameState.defeated_persistent_enemies.has(CANNON_FLAG % index):
			cannon.show_wrecked()
		_cannons.append(cannon)

func intact_cannon_count() -> int:
	var count := 0
	for cannon in _cannons:
		if cannon.intact:
			count += 1
	return count

func battery_cleared() -> bool:
	return not _cannons.is_empty() and intact_cannon_count() == 0

func nearest_intact_cannon(origin: Vector2, radius: float) -> BatteryCannon:
	var nearest: BatteryCannon
	var best := radius
	for cannon in _cannons:
		if cannon.intact and origin.distance_to(cannon.global_position) < best:
			nearest = cannon
			best = origin.distance_to(cannon.global_position)
	return nearest

func plant_charge(cannon: BatteryCannon) -> bool:
	if cannon == null or not cannon.intact or cannon.charge_planted:
		return false
	cannon.charge_planted = true
	var charge := ArtilleryShell.new()
	charge.name = "Charge_%s" % cannon.cannon_id
	_battlefield.add_child(charge)
	var detonate := func(at: Vector2) -> void:
		if is_instance_valid(cannon):
			cannon.destroy()
		_blast(at, CHARGE_RADIUS, CHARGE_DAMAGE, true, true)
	charge.launch(cannon.global_position, CHARGE_RADIUS, CHARGE_FUSE, detonate, false)
	GameState.notify("Charge planted on the Republic cannon. Get clear: %d seconds!" % int(CHARGE_FUSE))
	return true

func _on_cannon_destroyed(_cannon_id: String, index: int) -> void:
	var flag := CANNON_FLAG % index
	if not GameState.defeated_persistent_enemies.has(flag):
		GameState.defeated_persistent_enemies.append(flag)
	if index < _cannons.size():
		_explosion(_cannons[index].global_position, 34.0, Color(1.0, 0.55, 0.2))
	if battery_cleared():
		GameState.add_gold(RAID_REWARD)
		GameState.notify("The Republic battery is silenced! Captain Vela sends %d gold. The base is safe from its shells." % RAID_REWARD)
		if raid_active:
			_end_raid("success")
	else:
		GameState.notify("Republic cannon destroyed. %d left." % intact_cannon_count())
	_refresh_front_hud()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not battery_cleared():
		_shell_timer -= delta
		if _shell_timer <= 0.0:
			# The battery fires faster at the mine-duty spots.
			_shell_timer = _rng.randf_range(5.0, 8.0) if mine_duty_active else _rng.randf_range(8.0, 13.0)
			fire_republic_salvo()
	_counter_timer -= delta
	if _counter_timer <= 0.0:
		_counter_timer = _rng.randf_range(15.0, 22.0)
		fire_counter_battery()
	if raid_active:
		_step_raid()
	if defense_active:
		_step_defense(delta)

## Each standing Republic gun sends one shell at the Confederation trenches, or
## during mine duty at the spots still waiting for a mine.
func fire_republic_salvo() -> Array[ArtilleryShell]:
	var shells: Array[ArtilleryShell] = []
	var targets: Array = REPUBLIC_SHELL_TARGETS
	if mine_duty_active:
		targets = open_mine_spots()
	for cannon in _cannons:
		if not cannon.intact:
			continue
		_muzzle_flash(cannon.global_position + Vector2(18, -22))
		var target: Vector2 = targets[_rng.randi_range(0, targets.size() - 1)]
		target += Vector2(_rng.randf_range(-SHELL_SPREAD, SHELL_SPREAD), _rng.randf_range(-SHELL_SPREAD, SHELL_SPREAD) * 0.6)
		shells.append(launch_shell(target, true))
	return shells

## One Confederation gun at Cauliflower Base fires into the Republic base.
func fire_counter_battery() -> ArtilleryShell:
	var guns := tiled_loader.map_objects("front_cannon")
	if not guns.is_empty():
		var gun := guns[_rng.randi_range(0, guns.size() - 1)]
		_muzzle_flash(gun.global_position + Vector2(TiledLoader.map_object_size(gun).x * 0.75, 8))
	var target: Vector2 = COUNTER_FIRE_TARGETS[_rng.randi_range(0, COUNTER_FIRE_TARGETS.size() - 1)]
	target += Vector2(_rng.randf_range(-SHELL_SPREAD, SHELL_SPREAD), _rng.randf_range(-SHELL_SPREAD, SHELL_SPREAD) * 0.6)
	return launch_shell(target, false)

## A shell from Republic guns hurts the player's side; Confederation shells hurt Republic soldiers.
func launch_shell(target: Vector2, republic: bool) -> ArtilleryShell:
	var shell := ArtilleryShell.new()
	shell.name = "Shell_%d" % _battlefield.get_child_count()
	_battlefield.add_child(shell)
	shell.launch(target, SHELL_RADIUS, SHELL_WARNING, func(at: Vector2) -> void: _blast(at, SHELL_RADIUS, SHELL_DAMAGE, republic, not republic))
	return shell

func _blast(at: Vector2, radius: float, damage: int, hurts_party: bool, hurts_republic: bool) -> void:
	_explosion(at, radius, Color(1.0, 0.62, 0.25))
	if hurts_party:
		for node in get_tree().get_nodes_in_group("party_target"):
			if node is Node2D and (node as Node2D).visible and node.has_method("take_damage") and (node as Node2D).global_position.distance_to(at) <= radius:
				node.take_damage(damage, at)
	if hurts_republic:
		for node in get_tree().get_nodes_in_group("damageable"):
			if node is Enemy and node.visible and node.global_position.distance_to(at) <= radius:
				node.take_damage(damage, at)

func _explosion(at: Vector2, radius: float, color: Color) -> void:
	var blast := Node2D.new()
	blast.position = at
	blast.z_index = 970 + int(at.y)
	_battlefield.add_child(blast)
	var fire := Polygon2D.new()
	fire.polygon = ArtilleryShell.circle(radius * 0.45, 14)
	fire.color = color
	blast.add_child(fire)
	var smoke := Polygon2D.new()
	smoke.polygon = ArtilleryShell.circle(radius, 18)
	smoke.color = Color(0.32, 0.30, 0.34, 0.55)
	smoke.z_index = -1
	blast.add_child(smoke)
	var tween := blast.create_tween()
	tween.tween_property(fire, "scale", Vector2(2.0, 2.0), 0.35)
	tween.parallel().tween_property(blast, "modulate:a", 0.0, 0.7)
	tween.tween_callback(blast.queue_free)

func _muzzle_flash(at: Vector2) -> void:
	var flash := Polygon2D.new()
	flash.polygon = ArtilleryShell.circle(6.0, 8)
	flash.color = Color(1.0, 0.88, 0.45)
	flash.position = at
	flash.z_index = 980 + int(at.y)
	_battlefield.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

# --- Republic soldiers --------------------------------------------------------

func _spawn_garrison() -> void:
	if battery_cleared():
		return
	for index in _garrison_posts.size():
		var post := _garrison_posts[index]
		var kind := "republic_archer"
		if index % 3 == 2:
			kind = "republic_spearman" if index < 4 else "republic_swordsman"
		var unit := _spawn_republic_unit(kind, Vector2(post["position"]), String(post["texture"]), "artichoke_garrison_%s" % String(post["id"]).get_slice("_", String(post["id"]).get_slice_count("_") - 1))
		# Archers keep to their posts and shoot from there; spearmen and swordsmen charge.
		unit.hold_ground = kind == "republic_archer"

func _spawn_republic_unit(kind: String, at: Vector2, texture_path: String, stable_id: String) -> Enemy:
	var unit := Enemy.new()
	unit.name = "Republic_%s" % stable_id
	unit.configure(kind, texture_path, at, stable_id)
	actors_root.add_child(unit)
	unit.defeated.connect(func(_id: String) -> void: _refresh_front_hud.call_deferred())
	_republic_units.append(unit)
	return unit

func _restore_garrison() -> void:
	for unit in _republic_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_republic_units.clear()
	_reinforcements_sent = false
	_spawn_garrison()

func send_reinforcements() -> void:
	if _reinforcements_sent:
		return
	_reinforcements_sent = true
	var start := _nearby_open_position(AIRFIELD)
	for index in REINFORCEMENTS:
		var kind: String = ["republic_swordsman", "republic_spearman", "republic_archer"][index % 3]
		var texture := "res://assets/art/artichoke/objects/republic_soldier%s.png" % ("" if index == 0 else "_%d" % (index + 1))
		var origin := _nearby_open_position(start + Vector2(index * 16 - 16, 0))
		var unit := _spawn_republic_unit(kind, origin, texture, "artichoke_reinforcement_%d" % index)
		unit.march_along(tiled_loader.get_walk_path(origin, BATTERY_CENTER + Vector2(index * 24 - 24, -24)))
	GameState.notify("Republic reinforcements are coming up from the airfield!")

# --- Trench raid --------------------------------------------------------------

func start_raid() -> bool:
	if squad_deployed() or player == null:
		return false
	if battery_cleared():
		GameState.notify("The Republic battery is already silenced.")
		return false
	if story_stage() != "raid":
		GameState.notify("Captain Vela has other orders for you first.")
		return false
	raid_active = true
	_reinforcements_sent = false
	_deploy_squad()
	GameState.notify("Trench raid: six soldiers follow you. Q follow, R hold, T attack. Plant charges on both Republic cannons with E.")
	_refresh_front_hud()
	return true

## Puts the six soldiers beside the player, following.
func _deploy_squad() -> void:
	_raid_order = "follow"
	for index in RAID_SIZE:
		var soldier := RaidSoldier.new()
		soldier.name = "Squad_%s" % RAID_NAMES[index]
		var spot := _nearby_open_position(player.global_position + RaidSoldier.FOLLOW_SLOTS[index])
		actors_root.add_child(soldier)
		soldier.configure("squad_%d" % index, RAID_NAMES[index], RAID_TEXTURES[index], spot, RAID_WEAPONS[index], index, self)
		soldier.downed.connect(_on_raid_soldier_downed)
		_raid_soldiers.append(soldier)

## Sends standing soldiers back to the officer and removes the rest.
func _withdraw_squad(walk_back: bool) -> void:
	var home := _officer.global_position + Vector2(0, 30) if _officer != null else GameState.ARTICHOKE_ARRIVAL
	for soldier in _raid_soldiers:
		if not is_instance_valid(soldier):
			continue
		if walk_back and not soldier.down:
			soldier.return_to(_nearby_open_position(home))
		else:
			soldier.queue_free()
	_raid_soldiers.clear()

func standing_raid_soldiers() -> int:
	var count := 0
	for soldier in _raid_soldiers:
		if is_instance_valid(soldier) and not soldier.down:
			count += 1
	return count

func squad_deployed() -> bool:
	return raid_active or defense_active or assault_active or ships_active

## "Raid", "Trench", "Assault" or "Strike": the squad's name in messages.
func _squad_label() -> String:
	if defense_active:
		return "Trench"
	if assault_active:
		return "Assault"
	if ships_active:
		return "Strike"
	return "Raid"

func issue_order(order: String) -> void:
	if not squad_deployed():
		super.issue_order(order)
		return
	if order not in ["follow", "hold", "attack"]:
		return
	_raid_order = order
	for soldier in _raid_soldiers:
		if is_instance_valid(soldier) and not soldier.down:
			soldier.set_order(order)
	GameState.notify("%s squad: %s." % [_squad_label(), order.capitalize()])
	_refresh_front_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not squad_deployed():
		super._unhandled_input(event)
		return
	if get_tree().paused or player == null or player.ui_is_open():
		return
	for order in ["follow", "hold", "attack"]:
		if event.is_action_pressed("order_" + order):
			issue_order(order)
			get_viewport().set_input_as_handled()
			return

func _step_raid() -> void:
	if not _reinforcements_sent and player.global_position.distance_to(BATTERY_CENTER) < REINFORCEMENT_TRIGGER:
		send_reinforcements()

func _on_raid_soldier_downed(soldier_id: String) -> void:
	var soldier_name := soldier_id
	for soldier in _raid_soldiers:
		if is_instance_valid(soldier) and soldier.soldier_id == soldier_id:
			soldier_name = soldier.soldier_name
	if standing_raid_soldiers() == 0:
		if defense_active:
			_end_defense("failed")
			GameState.notify("All six defenders are down. The Republic takes the forward trenches; Captain Vela pulls everyone back to regroup.")
		elif assault_active:
			_end_assault("failed")
			GameState.notify("All six soldiers are down. The assault has failed; Captain Vela will try again when you are ready.")
		elif ships_active:
			_end_ships("failed")
			GameState.notify("All six soldiers are down. The strike has failed; the Republic will clear the mines off its hulls.")
		else:
			_end_raid("failed")
			GameState.notify("All six raiders are down. The raid has failed; the survivors are carried back to Cauliflower Base.")
		return
	var left := standing_raid_soldiers()
	var noun := "defender" if defense_active else "raider" if raid_active else "soldier"
	GameState.notify("%s is down. %d %s%s still standing." % [soldier_name, left, noun, "" if left == 1 else "s"])
	_refresh_front_hud()

## Ends the raid. "success" sends the standing soldiers back to the officer;
## anything else returns the squad to the base and resets the Republic garrison.
func _end_raid(result: String) -> void:
	raid_active = false
	_withdraw_squad(result == "success")
	if result != "success":
		for cannon in _cannons:
			cannon.repair()
		_restore_garrison()
	_refresh_front_hud()

func cancel_raid() -> void:
	if raid_active:
		_end_raid("cancelled")
		GameState.notify("The raid is called off. The squad returns to Cauliflower Base.")

func _on_player_respawned() -> void:
	super._on_player_respawned()
	if raid_active:
		_end_raid("failed")
		GameState.notify("The raid failed. Captain Vela will send a new squad when you are ready.")
	if defense_active:
		_end_defense("failed")
		GameState.notify("The trenches fell while you were down. Captain Vela will hold them again when you are ready.")
	if mine_duty_active:
		_end_mine_duty()
		GameState.notify("You were carried back from mine duty. The mines you laid stay; Captain Vela sends you out again when you are ready.")
	if assault_active:
		_end_assault("failed")
		GameState.notify("The assault failed while you were down. Captain Vela will try again when you are ready.")
	if ships_active:
		_end_ships("failed")
		GameState.notify("The strike failed while you were down. General Hickey will send you again when you are ready.")

# --- Republic counterattack ---------------------------------------------------

func counterattack_repelled() -> bool:
	return GameState.defeated_persistent_enemies.has(DEFENSE_FLAG)

func counterattack_ready() -> bool:
	return battery_cleared() and not counterattack_repelled()

func start_defense() -> bool:
	if squad_deployed() or player == null:
		return false
	if not counterattack_ready():
		GameState.notify("There is no Republic attack to hold off." if counterattack_repelled() else "The Republic battery must fall before its infantry comes.")
		return false
	defense_active = true
	_wave_index = 0
	_wave_timer = FIRST_WAVE_DELAY
	_breaches = 0
	_support_timer = _rng.randf_range(3.0, 5.0)
	_deploy_squad()
	_start_typed_orders()
	GameState.notify("Trench defense: the first wave leaves the airfield in %d seconds, heading for %s. Q follow, R hold, T attack." % [int(FIRST_WAVE_DELAY), wave_targets(0)])
	_refresh_front_hud()
	return true

func wave_units() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for unit in _wave_units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			alive.append(unit)
	return alive

func current_wave() -> int:
	return _wave_index

func breaches() -> int:
	return _breaches

func wave_countdown() -> float:
	return _wave_timer

## "the west ramp" or "the west ramp and the east stairs" for a wave (from 0).
func wave_targets(index: int) -> String:
	var names: Array[String] = []
	for ramp: int in WAVE_RAMPS[clampi(index, 0, WAVE_RAMPS.size() - 1)]:
		names.append(BREACH_NAMES[ramp])
	return " and ".join(names)

## Starts the next wave from the airfield towards its ramps in WAVE_RAMPS.
func send_wave() -> Array[Enemy]:
	var sent: Array[Enemy] = []
	if _wave_index >= DEFENSE_WAVES.size():
		return sent
	var kinds: Array = DEFENSE_WAVES[_wave_index]
	var ramps: Array = WAVE_RAMPS[_wave_index]
	var targets := wave_targets(_wave_index)
	_wave_index += 1
	_wave_timer = INF
	var start := _nearby_open_position(AIRFIELD)
	for index in kinds.size():
		var texture := "res://assets/art/artichoke/objects/republic_soldier%s.png" % ("" if index % 3 == 0 else "_%d" % (index % 3 + 1))
		var origin := _nearby_open_position(start + Vector2((index % 4) * 16 - 24, (index / 4) * 18))
		var unit := Enemy.new()
		unit.name = "Wave%d_%d" % [_wave_index, index]
		unit.configure(String(kinds[index]), texture, origin, "artichoke_wave_%d_%d" % [_wave_index, index])
		actors_root.add_child(unit)
		unit.defeated.connect(func(_id: String) -> void: _refresh_front_hud.call_deferred())
		var goal: Vector2 = BREACH_POINTS[ramps[index % ramps.size()]]
		var spread := (index / ramps.size()) % 3
		unit.march_along(tiled_loader.get_walk_path(origin, _nearby_open_position(goal + Vector2(spread * 12 - 12, 0))))
		_wave_units.append(unit)
		sent.append(unit)
	GameState.notify("Wave %d of %d: %d Republic soldiers march from the airfield for %s!" % [_wave_index, DEFENSE_WAVES.size(), kinds.size(), targets])
	_refresh_front_hud()
	return sent

func _step_defense(delta: float) -> void:
	var alive := wave_units()
	for unit in alive:
		if unit.march_finished() and _near_breach_point(unit.global_position):
			_breaches += 1
			_wave_units.erase(unit)
			unit.queue_free()
			if _breaches >= BREACH_LIMIT:
				_end_defense("failed")
				GameState.notify("The Republic has broken into the trenches. Captain Vela pulls everyone back to regroup.")
				return
			GameState.notify("A Republic soldier broke through at the ramp! Breaches: %d of %d." % [_breaches, BREACH_LIMIT])
			_refresh_front_hud()
	alive = wave_units()
	if alive.is_empty() and _wave_timer == INF:
		if _wave_index >= DEFENSE_WAVES.size():
			_win_defense()
			return
		if _wave_index == RELIEF_AFTER_WAVE:
			_wave_timer = RELIEF_GAP
			var fresh := send_relief()
			var joined := "No one has fallen, so no fresh soldiers are needed." if fresh.is_empty() else "Captain Vela sends %s to replace the fallen." % _join_names(fresh)
			GameState.notify("Wave %d beaten back. %s The last and largest wave comes in %d seconds, heading for %s." % [_wave_index, joined, int(RELIEF_GAP), wave_targets(_wave_index)])
		else:
			_wave_timer = WAVE_GAP
			GameState.notify("Wave %d beaten back. The next wave comes in %d seconds, heading for %s." % [_wave_index, int(WAVE_GAP), wave_targets(_wave_index)])
		_refresh_front_hud()
	if _wave_timer != INF:
		var shown := ceili(_wave_timer)
		_wave_timer -= delta
		if ceili(_wave_timer) != shown:
			_refresh_front_hud()
		if _wave_timer <= 0.0:
			send_wave()
	_support_timer -= delta
	if _support_timer <= 0.0:
		_support_timer = _rng.randf_range(5.0, 8.0)
		fire_support_shell()

func _near_breach_point(at: Vector2) -> bool:
	for point in BREACH_POINTS:
		if at.distance_to(point) <= BREACH_DISTANCE + 24.0:
			return true
	return false

## Replaces every downed defender with a fresh soldier from Cauliflower Base. The
## new soldier takes the fallen one's slot, weapon and order ID, so the groups
## stay as they were, and follows the player. Returns the new names.
func send_relief() -> Array[String]:
	var names: Array[String] = []
	var home := _officer.global_position + Vector2(0, 30) if _officer != null else GameState.ARTICHOKE_ARRIVAL
	for soldier in _raid_soldiers.duplicate():
		if not is_instance_valid(soldier) or not soldier.down:
			continue
		var index: int = soldier.slot
		_raid_soldiers.erase(soldier)
		soldier.queue_free()
		var fresh := RaidSoldier.new()
		fresh.name = "Squad_%s" % RELIEF_NAMES[index]
		actors_root.add_child(fresh)
		fresh.configure("relief_%d" % index, RELIEF_NAMES[index], RAID_TEXTURES[index], _nearby_open_position(home + Vector2((index % 3) * 18 - 18, (index / 3) * 18)), RAID_WEAPONS[index], index, self)
		fresh.downed.connect(_on_raid_soldier_downed)
		_raid_soldiers.append(fresh)
		names.append(RELIEF_NAMES[index])
	_refresh_front_hud()
	return names

func _join_names(names: Array[String]) -> String:
	return " and ".join(names) if names.size() <= 2 else ", ".join(names.slice(0, -1)) + " and " + names[-1]

## A Confederation cannon fires on the column farthest down the field, aimed
## where the soldier will be when the shell lands.
func fire_support_shell() -> ArtilleryShell:
	var target: Enemy
	for unit in wave_units():
		if not unit.visible or (player != null and unit.global_position.distance_to(player.global_position) < 70.0):
			continue
		if target == null or unit.global_position.y > target.global_position.y:
			target = unit
	if target == null:
		return null
	var guns := tiled_loader.map_objects("front_cannon")
	if not guns.is_empty():
		var gun := guns[_rng.randi_range(0, guns.size() - 1)]
		_muzzle_flash(gun.global_position + Vector2(TiledLoader.map_object_size(gun).x * 0.75, 8))
	var aim := target.global_position + target.velocity * SHELL_WARNING
	return launch_shell(aim + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-8.0, 8.0)), false)

func _win_defense() -> void:
	if not GameState.defeated_persistent_enemies.has(DEFENSE_FLAG):
		GameState.defeated_persistent_enemies.append(DEFENSE_FLAG)
	GameState.add_gold(DEFENSE_REWARD)
	_end_defense("success")
	_refresh_officer()
	GameState.notify("The Republic counterattack is beaten back! Command sends %d gold. Captain Vela is nowhere to be found; General Hickey has landed and wants to see you." % DEFENSE_REWARD)

## Ends the defense. "success" walks the standing soldiers back; anything else
## removes the squad and every attacker still on the field.
func _end_defense(result: String) -> void:
	defense_active = false
	_stop_typed_orders()
	_withdraw_squad(result == "success")
	for unit in _wave_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_wave_units.clear()
	_wave_timer = 0.0
	_refresh_front_hud()

func cancel_defense() -> void:
	if defense_active:
		_end_defense("cancelled")
		GameState.notify("Captain Vela calls the defenders back. The Republic will try again.")

# --- Typed squad orders -------------------------------------------------------

func _start_typed_orders() -> void:
	squad_groups.clear()
	for group_name: String in STARTING_GROUPS:
		var members: Array[String] = []
		for index in RAID_SIZE:
			if RAID_WEAPONS[index] == STARTING_GROUPS[group_name]:
				members.append(squad_order_id(index))
		squad_groups[group_name] = members
	if order_client == null:
		order_client = SquadOrderClient.new()
		order_client.name = "OrderClient"
		order_client.order_ready.connect(_on_typed_order_ready)
		order_client.order_failed.connect(func(message: String) -> void: GameState.notify(message))
		order_client.status_changed.connect(func(_text: String) -> void: _refresh_front_hud())
		add_child(order_client)
	else:
		order_client.check()
	_show_place_markers(true)

func _stop_typed_orders() -> void:
	if order_client != null:
		order_client.cancel()
	_show_place_markers(false)

## Whether Enter opens the order bar.
func accepts_typed_orders() -> bool:
	return defense_active

func squad_order_id(index: int) -> String:
	return "soldier_%02d" % (index + 1)

func _soldier_for_order_id(id: String) -> RaidSoldier:
	for soldier in _raid_soldiers:
		if is_instance_valid(soldier) and not soldier.down and squad_order_id(soldier.slot) == id:
			return soldier
	return null

## The request context for the order service: standing soldiers, groups and places.
func squad_order_context() -> Dictionary:
	var soldier_data: Array = []
	var ids: Array[String] = []
	for soldier in _raid_soldiers:
		if is_instance_valid(soldier) and not soldier.down:
			var id := squad_order_id(soldier.slot)
			soldier_data.append({"id": id, "position": [soldier.global_position.x, soldier.global_position.y]})
			ids.append(id)
	var group_data: Dictionary = {"all": ids}
	for group_name: String in squad_groups:
		var members: Array[String] = []
		for id: String in squad_groups[group_name]:
			if ids.has(id):
				members.append(id)
		# The service rejects empty groups; a group whose soldiers are all down is left out.
		if not members.is_empty():
			group_data[group_name] = members
	var places: Dictionary = {}
	for letter: String in order_places:
		places[letter] = [order_places[letter].x, order_places[letter].y]
	return {"soldiers": soldier_data, "groups": group_data, "landmarks": places}

## Rewrites place names, soldier names and group spellings into the words the
## order service knows: "send Petra and the archers to the east stairs" becomes
## "send soldier 4 and the bowmen to B".
func rewrite_order_text(text: String) -> String:
	var result := text.strip_edges()
	# Marked places first, longest first, so "north tower" is replaced before "tower".
	var custom: Array = order_place_names.keys().filter(func(letter: String) -> bool: return not ORDER_PLACE_NAMES.has(letter))
	custom.sort_custom(func(left: String, right: String) -> bool: return order_place_names[left].length() > order_place_names[right].length())
	for letter: String in custom:
		result = _replace_words(result, "(the )?" + order_place_names[letter], letter)
	for entry: Array in ORDER_PLACE_PHRASES:
		result = _replace_words(result, entry[0], entry[1])
	for soldier in _raid_soldiers:
		if is_instance_valid(soldier) and not soldier.down:
			result = _replace_words(result, soldier.soldier_name.to_lower(), "soldier %d" % (soldier.slot + 1))
	for word: String in GROUP_WORDS:
		result = _replace_words(result, word, GROUP_WORDS[word])
	return result

func _replace_words(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?i)\\b" + pattern + "\\b")
	return regex.sub(text, replacement, true)

## Sends one typed order. "stop" is handled here without the service.
func submit_squad_text(text: String) -> bool:
	if not defense_active or standing_raid_soldiers() == 0:
		return false
	text = text.strip_edges()
	if text.is_empty() or text.length() > 300:
		GameState.notify("Type an order of up to 300 characters.")
		return false
	if text.to_lower() in ["stop", "halt", "hold"]:
		issue_order("hold")
		return true
	var place_command := _place_command(text)
	if not place_command.is_empty():
		if place_command[0] == "mark":
			return mark_place(place_command[1], player.global_position)
		return forget_place(place_command[1])
	return order_client != null and order_client.submit(rewrite_order_text(text), squad_order_context())

## ["mark", name] for "mark here as tower", "name this place tower" or "mark
## tower here"; ["forget", name] for "forget tower"; [] for any other text.
func _place_command(text: String) -> Array:
	var patterns := [
		["mark", "^(mark|name|call)\\s+(here|this\\s+(place|spot))\\s+(as\\s+)?(?<name>.+?)[.!]?$"],
		["mark", "^mark\\s+(?<name>.+?)\\s+here[.!]?$"],
		["forget", "^(forget|unmark)\\s+(place\\s+)?(?<name>.+?)[.!]?$"],
	]
	for entry: Array in patterns:
		var regex := RegEx.new()
		regex.compile("(?i)" + entry[1])
		var found := regex.search(text.strip_edges())
		if found != null:
			return [entry[0], found.get_string("name")]
	return []

## Lowercases a place name and drops a leading "the"; "" unless it is one to
## three words of letters, 2 to 20 characters in all.
func _clean_place_name(raw: String) -> String:
	var place_name := " ".join(raw.strip_edges().to_lower().split(" ", false)).trim_prefix("the ")
	var regex := RegEx.new()
	regex.compile("^[a-z]+( [a-z]+){0,2}$")
	return place_name if place_name.length() >= 2 and place_name.length() <= 20 and regex.search(place_name) != null else ""

## Names the place at `at` for typed orders, as the next free letter D to H.
## Marking a name again moves it.
func mark_place(raw_name: String, at: Vector2) -> bool:
	var place_name := _clean_place_name(raw_name)
	if place_name.is_empty():
		GameState.notify("A place name is one to three words of letters, e.g. mark here as tower.")
		return false
	for word in place_name.split(" "):
		if RESERVED_PLACE_WORDS.has(word) or GROUP_WORDS.has(word) or squad_groups.has(word) or word.length() == 1:
			GameState.notify("\"%s\" means something else in orders; pick another name." % word)
			return false
	var letter := ""
	for existing: String in order_place_names:
		if order_place_names[existing] == place_name and not ORDER_PLACE_NAMES.has(existing):
			letter = existing
	if letter.is_empty() and rewrite_order_text(place_name) != place_name:
		GameState.notify("\"%s\" already names a place or soldier; pick another name." % place_name)
		return false
	if not SandboxFormationPlanner.body_fits(tiled_loader, at):
		GameState.notify("Soldiers cannot stand here; mark open ground.")
		return false
	for existing: String in order_places:
		if existing != letter and order_places[existing].distance_to(at) < 24.0:
			GameState.notify("This spot is already the %s; stand farther away from it." % order_place_names[existing])
			return false
	var moved := not letter.is_empty()
	if not moved:
		for free: String in CUSTOM_PLACE_LETTERS:
			if not order_places.has(free):
				letter = free
				break
	if letter.is_empty():
		GameState.notify("Five places are already marked. Forget one first, e.g. forget %s." % order_place_names[CUSTOM_PLACE_LETTERS[0]])
		return false
	order_places[letter] = at
	order_place_names[letter] = place_name
	_refresh_place_markers()
	_refresh_front_hud()
	GameState.notify(("Moved the %s here." if moved else "Marked this spot as the %s. Orders can name it now.") % place_name)
	return true

## Removes a place the player marked. The three starting places stay.
func forget_place(raw_name: String) -> bool:
	var place_name := _clean_place_name(raw_name)
	for letter: String in order_place_names:
		if order_place_names[letter] == place_name:
			if ORDER_PLACE_NAMES.has(letter):
				GameState.notify("The %s is one of the fixed places and stays." % place_name)
				return false
			order_places.erase(letter)
			order_place_names.erase(letter)
			_refresh_place_markers()
			_refresh_front_hud()
			GameState.notify("Forgot the %s. Soldiers sent there stay where they are." % place_name)
			return true
	GameState.notify("No place is called %s." % (place_name if not place_name.is_empty() else raw_name.strip_edges()))
	return false

func _on_typed_order_ready(order: Dictionary, source: String) -> void:
	if defense_active:
		execute_squad_order(order, source)

## Checks an interpreted order against the current squad and carries it out.
func execute_squad_order(value: Variant, source: String = "order") -> bool:
	var context := squad_order_context()
	var known: Array[String] = []
	known.assign(context["groups"]["all"])
	var checked := SandboxFormationPlanner.validate_order(value, known, order_places, context["groups"])
	if not checked["ok"]:
		GameState.notify("Order not carried out: %s" % checked["error"])
		return false
	var order: Dictionary = checked["order"]
	var action: String = order["action"]
	if action == "clarify":
		GameState.notify("Squad: %s" % _letters_to_places(order["message"]))
		return true
	var ids: Array[String] = []
	ids.assign(order["soldier_ids"])
	var who := _describe_selection(ids)
	match action:
		"create_group":
			squad_groups[order["group_name"]] = ids
			GameState.notify("New group %s: %s." % [order["group_name"], who])
		"stop":
			for id in ids:
				_soldier_for_order_id(id).set_order("hold")
			GameState.notify("%s: hold where you stand." % _sentence_case(who))
		"follow_player":
			for id in ids:
				_soldier_for_order_id(id).set_order("follow")
			GameState.notify("%s: follow you." % _sentence_case(who))
		"move_to", "form_line", "patrol":
			if not _plan_squad_task(order, ids):
				return false
			var line: String = {"move_to": "to the %s", "form_line": "line from the %s to the %s", "patrol": "patrol between the %s and the %s"}[action]
			var places: Array = [order_place_names[order["end"]]] if action == "move_to" else [order_place_names[order["start"]], order_place_names[order["end"]]]
			GameState.notify("%s: %s. (%s)" % [_sentence_case(who), line % places, source])
		"attack":
			if order["end"] == null:
				for id in ids:
					var soldier := _soldier_for_order_id(id)
					soldier.hunt(Vector2.INF, soldier.global_position, "attack")
			elif not _plan_squad_task(order, ids):
				return false
			var where := "attack" if order["end"] == null else "attack at the %s" % order_place_names[order["end"]]
			var waiting := "" if not wave_units().is_empty() else " No attackers on the field yet; they wait for the next wave."
			GameState.notify("%s: %s. (%s)%s" % [_sentence_case(who), where, source, waiting])
	_raid_order = "typed"
	_refresh_front_hud()
	return true

## Gives each selected soldier its own place near the named landmarks.
func _plan_squad_task(order: Dictionary, ids: Array[String]) -> bool:
	var positions: Dictionary = {}
	var occupied := PackedVector2Array()
	for soldier in _raid_soldiers:
		if not is_instance_valid(soldier) or soldier.down:
			continue
		var id := squad_order_id(soldier.slot)
		if ids.has(id):
			positions[id] = soldier.global_position
		elif soldier.order in ["hold", "patrol", "hunt"]:
			# Soldiers already sent somewhere keep their places.
			occupied.append(soldier.hold_point)
	var action: String = order["action"]
	var plans: Array[Dictionary] = []
	if action == "form_line":
		plans.append(SandboxFormationPlanner.plan_line(order, positions, order_places, tiled_loader))
	else:
		plans.append(SandboxFormationPlanner.plan_move(order, positions, order_places, tiled_loader, occupied))
		if action == "patrol":
			var first := order.duplicate()
			first["end"] = order["start"]
			plans.push_front(SandboxFormationPlanner.plan_move(first, positions, order_places, tiled_loader, occupied))
	for plan in plans:
		if not plan["ok"]:
			var error: String = plan["error"]
			if error.begins_with("Line position"):
				# The places are fixed here, unlike sandbox landmarks, so suggest what can change.
				error = "the ground between %s and %s is not open for a line of %d. Try two other places or fewer soldiers." % [order_place_names[order["start"]], order_place_names[order["end"]], ids.size()]
			GameState.notify("Order not carried out: %s" % _letters_to_places(error))
			return false
	for id in ids:
		var soldier := _soldier_for_order_id(id)
		if action == "patrol":
			soldier.patrol_between(plans[0]["assignments"][id], plans[1]["assignments"][id], "patrol %s–%s" % [order_place_names[order["start"]], order_place_names[order["end"]]])
		elif action == "attack":
			soldier.hunt(order_places[order["end"]], plans[0]["assignments"][id], "attack %s" % order_place_names[order["end"]])
		else:
			soldier.hold_at(plans[0]["assignments"][id], order_place_names[order["end"]] if action == "move_to" else "line %s–%s" % [order_place_names[order["start"]], order_place_names[order["end"]]])
	return true

func _sentence_case(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)

## "the bowmen", "Petra and Dusan" or "everyone" for a list of order IDs.
func _describe_selection(ids: Array[String]) -> String:
	var everyone := squad_order_context()["groups"]["all"] as Array
	if ids.size() == everyone.size():
		return "everyone"
	for group_name: String in squad_groups:
		var members: Array = squad_groups[group_name].filter(func(id: String) -> bool: return everyone.has(id))
		if not members.is_empty() and members.size() == ids.size() and members.all(func(id: String) -> bool: return ids.has(id)):
			# The starting groups are plural nouns; a group the player names may not be.
			return ("the " if STARTING_GROUPS.has(group_name) else "group ") + group_name
	var names: Array[String] = []
	for id in ids:
		names.append(_soldier_for_order_id(id).soldier_name)
	return _join_names(names)

## Names the places in a service or planner message: "move to A" becomes "move to
## the west ramp". A capital A that starts a sentence before a word ("A line
## needs…") is the article and stays.
func _letters_to_places(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?<![A-Za-z])[%s](?![A-Za-z])" % "".join(order_place_names.keys()))
	var result := ""
	var last := 0
	for found in regex.search_all(text):
		var start := found.get_start()
		var before := text.substr(0, start).strip_edges()
		var after := text.substr(found.get_end(), 2)
		var sentence_start := before.is_empty() or before[-1] in [".", "?", "!"]
		var article := found.get_string() == "A" and sentence_start and after.length() == 2 and after[0] == " " and after[1] >= "a" and after[1] <= "z"
		result += text.substr(last, start - last) + (found.get_string() if article else "the " + order_place_names[found.get_string()])
		last = found.get_end()
	return result + text.substr(last)

## One line per starting group for the HUD, e.g. "Bowmen: centre trench".
func group_task_text() -> String:
	var parts: Array[String] = []
	for group_name: String in STARTING_GROUPS:
		var tasks: Array[String] = []
		for id: String in squad_groups.get(group_name, []):
			var soldier := _soldier_for_order_id(id)
			if soldier != null and not tasks.has(soldier.task_label):
				tasks.append(soldier.task_label)
		parts.append("%s: %s" % [group_name.capitalize(), ", ".join(tasks) if not tasks.is_empty() else "down"])
	return " · ".join(parts)

func place_markers_visible() -> bool:
	return _place_markers != null and _place_markers.visible

func _show_place_markers(shown: bool) -> void:
	if _place_markers == null:
		_place_markers = Node2D.new()
		_place_markers.name = "OrderPlaces"
		_place_markers.z_index = 2500
		_battlefield.add_child(_place_markers)
		_place_markers.draw.connect(func() -> void:
			for letter: String in order_places:
				_place_markers.draw_arc(order_places[letter], 9.0, 0.0, TAU, 20, Color("f5c34c") if ORDER_PLACES.has(letter) else Color("8fd3f0"), 2.0)
		)
		_refresh_place_markers()
	_place_markers.visible = shown

## Redraws the rings and labels after a place is marked or forgotten.
func _refresh_place_markers() -> void:
	if _place_markers == null:
		return
	for child in _place_markers.get_children():
		child.queue_free()
	for letter: String in order_places:
		var color := Color("f5c34c") if ORDER_PLACES.has(letter) else Color("8fd3f0")
		var label := Label.new()
		label.text = "%s · %s" % [letter, order_place_names[letter]]
		label.position = order_places[letter] + Vector2(-34, -30)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_shadow_color", Color("1c1730"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		_place_markers.add_child(label)
	_place_markers.queue_redraw()

# --- Officer and HUD ----------------------------------------------------------

## Actions from the officer's briefing, the Arms building and the Mess in the game UI.
func handle_world_action(action: String) -> void:
	match action:
		"raid_start":
			start_raid()
		"raid_cancel":
			cancel_raid()
		"defense_start":
			start_defense()
		"defense_cancel":
			cancel_defense()
		"mines_start":
			start_mine_duty()
		"mines_cancel":
			cancel_mine_duty()
		"assault_start":
			start_assault()
		"assault_cancel":
			cancel_assault()
		"ships_start":
			start_ships()
		"ships_cancel":
			cancel_ships()
		"arms_kit":
			draw_kit()
		"arms_weapons":
			reissue_weapons()
		"arms_mines":
			refill_mines()
		"arms_bandages":
			refill_bandages()
		"mess_meal":
			eat_mess_meal()

func front_status_text() -> String:
	if mine_duty_active:
		return "MINE DUTY — plant a field mine on each marked spot\nSpots laid: %d/%d   Field mines carried: %d\nRepublic shells are falling on the spots" % [mine_spots.size() - open_mine_spots().size(), mine_spots.size(), int(GameState.inventory.get("field_mine", 0))]
	if assault_active:
		return "TRENCH ASSAULT — Q follow · R hold · T attack\nTarget: the Republic soldier marked TARGET   Republic left: %d\nSoldiers standing: %d/%d   Squad order: %s" % [assault_units().size(), standing_raid_soldiers(), RAID_SIZE, _raid_order]
	if ships_active:
		return "FLEET STRIKE — E plants a field mine on a hull\nShips left: %d/%d (the flagship needs 3 mines)   Field mines carried: %d\nSoldiers standing: %d/%d   Squad order: %s" % [intact_ship_count(), _warships.size(), int(GameState.inventory.get("field_mine", 0)), standing_raid_soldiers(), RAID_SIZE, _raid_order]
	match story_stage():
		"report":
			return "ARTICHOKE FRONT\nReport to %s by the transport" % OFFICER_NAME
		"kit":
			return "ARTICHOKE FRONT\nDraw your kit at the Arms building east of the barracks"
		"mines":
			return "ARTICHOKE FRONT\nMine duty: see %s at Cauliflower Base" % OFFICER_NAME
		"assault":
			return "ARTICHOKE FRONT\nThe trench assault is forming: see %s" % OFFICER_NAME
		"ships":
			return "ARTICHOKE FRONT\nThe Republic is repairing its warships at the airfield\nSee %s at Cauliflower Base" % GENERAL_NAME
		"debrief":
			return "ARTICHOKE FRONT\nThe Republic fleet is wrecked\nReport to %s at Cauliflower Base" % GENERAL_NAME
		"done":
			return "ARTICHOKE FRONT — Captain\nThe front is quiet for now\nReport to the Council on Pomidor, the Confederation capital"
	if raid_active:
		return "TRENCH RAID — Q follow · R hold · T attack\nRepublic cannons left: %d   Raiders standing: %d/%d\nSquad order: %s" % [intact_cannon_count(), standing_raid_soldiers(), RAID_SIZE, _raid_order]
	if defense_active:
		var next := "Next wave in %ds" % ceili(_wave_timer) if _wave_timer != INF and _wave_index < DEFENSE_WAVES.size() else "Attackers: %d" % wave_units().size()
		var targets := wave_targets(_wave_index - 1 if _wave_timer == INF else _wave_index)
		var marked := order_places.size() - ORDER_PLACES.size()
		var places := "" if marked == 0 else "Marked places: %s\n" % ", ".join(PackedStringArray(order_place_names.keys().filter(func(letter: String) -> bool: return not ORDER_PLACES.has(letter)).map(func(letter: String) -> String: return order_place_names[letter])))
		return "TRENCH DEFENSE — Q follow · R hold · T attack\nWave %d/%d to %s   %s   Breaches: %d/%d\nDefenders standing: %d/%d\n%s\n%s%s" % [mini(DEFENSE_WAVES.size(), _wave_index + (0 if _wave_timer == INF else 1)), DEFENSE_WAVES.size(), targets, next, _breaches, BREACH_LIMIT, standing_raid_soldiers(), RAID_SIZE, group_task_text(), places, order_client.status if order_client != null else ""]
	if counterattack_repelled():
		return "ARTICHOKE FRONT\nThe battery is silenced and the counterattack beaten\nThe flagship returns to the station"
	if battery_cleared():
		return "ARTICHOKE FRONT\nRepublic troops are massing at the airfield\nSee %s at Cauliflower Base" % OFFICER_NAME
	return "ARTICHOKE FRONT\nRepublic battery shelling the trenches (%d cannons)\nSee %s at Cauliflower Base" % [intact_cannon_count(), OFFICER_NAME]

func _refresh_front_hud() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui") if is_inside_tree() else null
	if ui != null and ui.has_method("refresh_front_status"):
		ui.refresh_front_status()

# --- Story -----------------------------------------------------------------------

func _has_flag(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has(flag)

func _set_flag(flag: String) -> void:
	if not _has_flag(flag):
		GameState.defeated_persistent_enemies.append(flag)

## Where the player is in the Artichoke missions: "report", "kit", "mines",
## "assault", "raid", "defense", "ships", "debrief" or "done".
func story_stage() -> String:
	if _has_flag(CAPTAIN_FLAG):
		return "done"
	if _has_flag(FLEET_FLAG):
		return "debrief"
	if counterattack_repelled():
		return "ships"
	if battery_cleared():
		return "defense"
	var cannon_down := false
	for index in _cannons.size():
		cannon_down = cannon_down or _has_flag(CANNON_FLAG % index)
	# A destroyed cannon also covers saves made before the earlier missions existed.
	if _has_flag(ASSAULT_FLAG) or cannon_down:
		return "raid"
	if _has_flag(MINES_FLAG):
		return "assault"
	if _has_flag(KIT_FLAG):
		return "mines"
	if _has_flag(REPORTED_FLAG):
		return "kit"
	return "report"

## True after the trench assault, when Captain Vela promotes the player.
func is_officer() -> bool:
	return story_stage() not in ["report", "kit", "mines", "assault"]

## The player's rank: Soldier, Officer after the trench assault, Captain after
## General Hickey's debrief.
func player_rank() -> String:
	if story_stage() == "done":
		return "Captain"
	return "Officer" if is_officer() else "Soldier"

## Called when the officer's briefing opens: the first one counts as reporting in.
func report_to_officer() -> void:
	if story_stage() == "report":
		_set_flag(REPORTED_FLAG)
		_refresh_front_hud()

## Called when General Hickey's debrief after the fleet strike opens.
func promote_to_captain() -> void:
	if story_stage() == "debrief":
		_set_flag(CAPTAIN_FLAG)
		GameState.notify("Promoted to Captain. Next: report to the Council on Pomidor, the Confederation capital.")
		_refresh_front_hud()

## True while any mission runs; the Mess serves no meals then.
func mission_active() -> bool:
	return squad_deployed() or mine_duty_active

# --- Mess ----------------------------------------------------------------------

## A hot meal at the Mess heals fully; the cook serves nobody during a mission.
func eat_mess_meal() -> bool:
	if mission_active():
		GameState.notify("The cook: \"Not now, the squad is out. Finish the job first.\"")
		return false
	if GameState.health >= GameState.max_health:
		GameState.notify("You are not hungry, and you have no wounds to mend.")
		return false
	GameState.health = GameState.max_health
	GameState.health_changed.emit(GameState.health, GameState.max_health)
	GameState.notify("A bowl of hot stew. You feel whole again.")
	return true

# --- Arms building ---------------------------------------------------------------

## The most field mines the player may carry after an Arms refill at this stage:
## one per open mine-duty spot, six for the counterattack minus those still buried
## for it, and the mines the intact warships need. The assault and the raid get none.
func mine_allowance() -> int:
	match story_stage():
		"kit", "mines":
			return open_mine_spots().size()
		"defense":
			return maxi(0, DEFENSE_MINES - buried_defense_mines())
		"ships":
			var needed := 0
			for ship in _warships:
				if ship.intact:
					needed += ship.mines_needed
			return needed
	return 0

## Mines planted for the counterattack that have not gone off. Planted mines are
## not saved, so after loading this is 0 and the Arms building issues all six again.
func buried_defense_mines() -> int:
	return placed_mines().filter(func(mine: FieldMine) -> bool: return mine.get_meta("stage", "") == "defense").size()

## The first issue after reporting in: a service bow, an iron spear, wooden armor,
## field mines and bandages.
func draw_kit() -> bool:
	if story_stage() == "report":
		GameState.notify("The quartermaster: \"Report to %s first, soldier. Nobody gets kit without orders.\"" % OFFICER_NAME)
		return false
	if _has_flag(KIT_FLAG):
		GameState.notify("You have drawn your kit already. Ask for replacements instead.")
		return false
	_issue_missing_weapons()
	# The issued bow replaces whatever the player arrived with.
	GameState.equip_item("service_bow")
	_top_up("field_mine", KIT_MINES)
	_top_up("bandage", KIT_BANDAGES)
	_set_flag(KIT_FLAG)
	GameState.notify("The quartermaster issues a service bow, an iron spear, wooden armor, %d field mines and %d bandages. You wear the armor and hold the bow; switch to the spear in your inventory (I). H uses a bandage when you have no food." % [KIT_MINES, KIT_BANDAGES])
	_refresh_front_hud()
	return true

func reissue_weapons() -> bool:
	if not _has_flag(KIT_FLAG):
		GameState.notify("Draw your kit first.")
		return false
	var issued := _issue_missing_weapons()
	GameState.notify("You already carry your bow, spear and armor." if issued.is_empty() else "The quartermaster replaces your %s." % " and ".join(issued))
	return not issued.is_empty()

func _issue_missing_weapons() -> Array[String]:
	var issued: Array[String] = []
	for item_id: String in KIT_GEAR:
		if not GameState.inventory.has(item_id) and GameState.add_item(item_id):
			issued.append(String(GameData.item(item_id).get("name", item_id)).to_lower())
	if String(GameState.equipment.get("weapon", "")).is_empty() and GameState.inventory.has("service_bow"):
		GameState.equip_item("service_bow")
	# Better armor the player already wears stays on.
	if String(GameState.equipment.get("armor", "")).is_empty() and GameState.inventory.has("wood_armor"):
		GameState.equip_item("wood_armor")
	return issued

func refill_mines() -> bool:
	if not _has_flag(KIT_FLAG):
		GameState.notify("Draw your kit first.")
		return false
	if mission_active():
		GameState.notify("The quartermaster: \"Mines are issued before an operation, not during one.\"")
		return false
	var allowance := mine_allowance()
	if allowance == 0 and story_stage() in ["assault", "raid"]:
		GameState.notify("The quartermaster: \"No mines for the assault teams. You get six when the Republic comes for our trenches.\"")
		return false
	var added := _top_up("field_mine", allowance)
	if added > 0:
		GameState.notify("The quartermaster issues %d field mine%s. Ready one from your inventory (I)." % [added, "" if added == 1 else "s"])
	elif story_stage() == "defense" and buried_defense_mines() > 0:
		GameState.notify("The quartermaster: \"%d of your six are still in the ground. I only replace the ones that went off.\"" % buried_defense_mines())
	else:
		GameState.notify("You already carry all the field mines the quartermaster will issue.")
	return added > 0

func refill_bandages() -> bool:
	if not _has_flag(KIT_FLAG):
		GameState.notify("Draw your kit first.")
		return false
	var added := _top_up("bandage", KIT_BANDAGES)
	GameState.notify("You already carry %d bandages." % KIT_BANDAGES if added == 0 else "The quartermaster issues %d bandage%s." % [added, "" if added == 1 else "s"])
	return added > 0

## Adds items until the player carries `amount`; returns how many were added.
func _top_up(item_id: String, amount: int) -> int:
	var needed := amount - int(GameState.inventory.get(item_id, 0))
	if needed > 0 and GameState.add_item(item_id, needed):
		return needed
	return 0

# --- Mine duty -------------------------------------------------------------------

func _build_mine_spots() -> void:
	mine_spots.clear()
	_mine_spots_done.clear()
	for spot: Vector2 in MINE_DUTY_SPOTS:
		mine_spots.append(_nearby_open_position(spot))
		_mine_spots_done.append(false)
	_mine_spot_markers = Node2D.new()
	_mine_spot_markers.name = "MineDutySpots"
	_mine_spot_markers.z_index = 2500
	_mine_spot_markers.visible = false
	_battlefield.add_child(_mine_spot_markers)
	_mine_spot_markers.draw.connect(func() -> void:
		for index in mine_spots.size():
			var color := Color("7fd36b") if _mine_spots_done[index] else Color("f5c34c")
			_mine_spot_markers.draw_arc(mine_spots[index], MINE_SPOT_RADIUS, 0.0, TAU, 24, color, 2.0)
	)
	for index in mine_spots.size():
		var label := Label.new()
		label.name = "Spot%d" % (index + 1)
		label.text = "Mine spot %d" % (index + 1)
		label.position = mine_spots[index] + Vector2(-30, -34)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color("f5c34c"))
		label.add_theme_color_override("font_shadow_color", Color("1c1730"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		_mine_spot_markers.add_child(label)

func open_mine_spots() -> Array[Vector2]:
	var open: Array[Vector2] = []
	for index in mine_spots.size():
		if not _mine_spots_done[index]:
			open.append(mine_spots[index])
	return open

func mine_spot_markers_visible() -> bool:
	return _mine_spot_markers != null and _mine_spot_markers.visible

func start_mine_duty() -> bool:
	if mission_active() or player == null:
		return false
	if story_stage() != "mines":
		GameState.notify("There is no mine duty for you now.")
		return false
	var open := open_mine_spots().size()
	if int(GameState.inventory.get("field_mine", 0)) < open:
		GameState.notify("You need %d field mines for the spots. The Arms building east of the barracks issues them." % open)
		return false
	mine_duty_active = true
	_mine_spot_markers.visible = true
	_mine_spot_markers.queue_redraw()
	_shell_timer = 3.0
	GameState.notify("Mine duty: plant a field mine on each marked spot below the cliffs (ready one with I, plant with Space). Their battery has the range; keep moving.")
	_refresh_front_hud()
	return true

func cancel_mine_duty() -> void:
	if mine_duty_active:
		_end_mine_duty()
		GameState.notify("Mine duty is called off. The mines you laid stay where they are.")

func _end_mine_duty() -> void:
	mine_duty_active = false
	if _mine_spot_markers != null:
		_mine_spot_markers.visible = false
	_refresh_front_hud()

## The open mine-duty spot within reach of `at` while the duty runs, or -1.
func _open_spot_near(at: Vector2) -> int:
	if not mine_duty_active:
		return -1
	for index in mine_spots.size():
		if not _mine_spots_done[index] and mine_spots[index].distance_to(at) <= MINE_SPOT_RADIUS:
			return index
	return -1

## Marks the open spot within reach of a new mine as laid.
func _check_mine_spot(at: Vector2) -> void:
	var index := _open_spot_near(at)
	if index >= 0:
		_mine_spots_done[index] = true
		_mine_spot_markers.queue_redraw()
		var left := open_mine_spots().size()
		if left == 0:
			_finish_mine_duty()
		else:
			GameState.notify("Mine spot %d is laid. %d to go." % [index + 1, left])
			_refresh_front_hud()

func _finish_mine_duty() -> void:
	_set_flag(MINES_FLAG)
	_end_mine_duty()
	GameState.add_gold(MINE_DUTY_REWARD)
	GameState.notify("Every spot is mined. %d gold for the duty. Report back to %s." % [MINE_DUTY_REWARD, OFFICER_NAME])

# --- Trench assault --------------------------------------------------------------

func assault_units() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for unit in _assault_units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.health > 0:
			alive.append(unit)
	return alive

func assault_target() -> Enemy:
	return _assault_target if is_instance_valid(_assault_target) else null

func start_assault() -> bool:
	if mission_active() or player == null:
		return false
	if story_stage() != "assault":
		GameState.notify("There is no assault for you now.")
		return false
	assault_active = true
	for index in ASSAULT_POSTS.size():
		var kind: String = ASSAULT_KINDS[index]
		var texture := "res://assets/art/artichoke/objects/republic_soldier%s.png" % ("" if index % 3 == 0 else "_%d" % (index % 3 + 1))
		var unit := _spawn_republic_unit(kind, _nearby_open_position(ASSAULT_POSTS[index]), texture, "artichoke_assault_%d" % index)
		unit.hold_ground = kind == "republic_archer"
		_assault_units.append(unit)
	# The order names one soldier in the trench, chosen at random each time.
	_assault_target = _assault_units[_rng.randi_range(0, _assault_units.size() - 1)]
	var mark := Label.new()
	mark.name = "TargetMark"
	mark.text = "TARGET"
	# Above the name and health line that Enemy draws over its head.
	mark.position = Vector2(-20, -58)
	mark.size = Vector2(40, 12)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 9)
	mark.add_theme_color_override("font_color", Color("f5c34c"))
	mark.add_theme_color_override("font_shadow_color", Color("1c1730"))
	mark.add_theme_constant_override("shadow_offset_x", 1)
	mark.add_theme_constant_override("shadow_offset_y", 1)
	_assault_target.add_child(mark)
	_assault_target.defeated.connect(func(_id: String) -> void: _win_assault.call_deferred())
	_deploy_squad()
	GameState.notify("Trench assault: six soldiers go with you. Storm the Republic trench west of the occupied village and bring down the soldier marked TARGET. Q follow, R hold, T attack.")
	_refresh_front_hud()
	return true

func cancel_assault() -> void:
	if assault_active:
		_end_assault("cancelled")
		GameState.notify("The assault is called off. The soldiers fall back to Cauliflower Base.")

func _win_assault() -> void:
	if not assault_active:
		return
	_set_flag(ASSAULT_FLAG)
	GameState.add_gold(ASSAULT_REWARD)
	_end_assault("success")
	GameState.notify("The marked soldier is down and the Republic trench empties! %d gold. Report to %s." % [ASSAULT_REWARD, OFFICER_NAME])

## Ends the assault. "success" walks the standing soldiers back; the Republic
## soldiers left in the trench fall back either way.
func _end_assault(result: String) -> void:
	assault_active = false
	_withdraw_squad(result == "success")
	for unit in _assault_units:
		if is_instance_valid(unit):
			_republic_units.erase(unit)
			unit.queue_free()
	_assault_units.clear()
	_assault_target = null
	_refresh_front_hud()

# --- Fleet strike ----------------------------------------------------------------

func _build_warships() -> void:
	var holders := tiled_loader.map_objects("republic_warship_escort") + tiled_loader.map_objects("republic_warship_flagship")
	holders.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	for index in holders.size():
		var flagship := String(holders[index].get_meta("object_name", "")) == "republic_warship_flagship"
		var ship := RepublicWarship.new()
		ship.name = "RepublicWarship_%d" % index
		actors_root.add_child(ship)
		ship.configure("artichoke_ship_%d" % index, "Republic flagship" if flagship else "Republic escort", 3 if flagship else 1, holders[index], TiledLoader.map_object_size(holders[index]))
		ship.destroyed.connect(_on_ship_destroyed.bind(index))
		if _has_flag(SHIP_FLAG % index):
			ship.show_wrecked()
		_warships.append(ship)

func warships() -> Array[RepublicWarship]:
	return _warships

func intact_ship_count() -> int:
	var count := 0
	for ship in _warships:
		if ship.intact:
			count += 1
	return count

func fleet_guards() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for unit in _fleet_guards:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.health > 0:
			alive.append(unit)
	return alive

func start_ships() -> bool:
	if mission_active() or player == null:
		return false
	if story_stage() != "ships":
		GameState.notify("There is no strike on the Republic fleet for you now.")
		return false
	var needed := 0
	for ship in _warships:
		if ship.intact:
			needed += ship.mines_needed
	if int(GameState.inventory.get("field_mine", 0)) < needed:
		GameState.notify("You need %d field mines for the ships. The Arms building east of the barracks issues them." % needed)
		return false
	ships_active = true
	for ship in _warships:
		ship.set_open_for_mines(true)
	for index in FLEET_GUARD_POSTS.size():
		var kind: String = FLEET_GUARD_KINDS[index]
		var texture := "res://assets/art/artichoke/objects/republic_soldier%s.png" % ("" if index % 3 == 0 else "_%d" % (index % 3 + 1))
		var unit := _spawn_republic_unit(kind, _nearby_open_position(FLEET_GUARD_POSTS[index]), texture, "artichoke_guard_%d" % index)
		unit.hold_ground = kind == "republic_archer"
		_fleet_guards.append(unit)
	_deploy_squad()
	GameState.notify("Fleet strike: six soldiers go with you to the Republic airfield. Plant a field mine on each escort and three on the flagship (E beside a hull). Q follow, R hold, T attack.")
	_refresh_front_hud()
	return true

func cancel_ships() -> void:
	if ships_active:
		_end_ships("cancelled")
		GameState.notify("The strike is called off. The Republic will clear the mines off its hulls.")

## Plants one field mine on a hull. The last mine a ship needs lights the fuse.
func plant_ship_mine(ship: RepublicWarship) -> bool:
	if ship == null or not ship.intact or ship.fully_mined():
		return false
	if not ships_active:
		GameState.notify("%s has not ordered the strike yet." % GENERAL_NAME)
		return false
	if not GameState.remove_item("field_mine"):
		GameState.notify("You have no field mines left. The Arms building issues more.")
		return false
	if not ship.add_mine():
		GameState.notify("Mine planted on the %s: %d of %d." % [ship.display_name, ship.mines_planted, ship.mines_needed])
		_refresh_front_hud()
		return true
	var charge := ArtilleryShell.new()
	charge.name = "ShipCharge_%s" % ship.ship_id
	_battlefield.add_child(charge)
	var detonate := func(at: Vector2) -> void:
		if is_instance_valid(ship):
			ship.destroy()
		_blast(at, CHARGE_RADIUS, CHARGE_DAMAGE, true, true)
	charge.launch(ship.global_position, CHARGE_RADIUS, CHARGE_FUSE, detonate, false)
	GameState.notify("The %s is mined. Get clear: %d seconds!" % [ship.display_name, int(CHARGE_FUSE)])
	_refresh_front_hud()
	return true

func _on_ship_destroyed(_ship_id: String, index: int) -> void:
	_set_flag(SHIP_FLAG % index)
	if index < _warships.size():
		var ship := _warships[index]
		_explosion(ship.global_position + Vector2(0, -16), 56.0, Color(1.0, 0.55, 0.2))
	if intact_ship_count() == 0:
		_win_ships()
	else:
		GameState.notify("A Republic warship burns. %d left." % intact_ship_count())
		_refresh_front_hud()

func _win_ships() -> void:
	_set_flag(FLEET_FLAG)
	GameState.add_gold(FLEET_REWARD)
	if ships_active:
		_end_ships("success")
	GameState.notify("The Republic fleet burns on the airfield! %s sends %d gold. No warship will bombard Cauliflower Base now. Report to %s." % [GENERAL_NAME, FLEET_REWARD, GENERAL_NAME])
	_refresh_front_hud()

## Ends the strike. "success" walks the standing soldiers back. Otherwise the
## mines come off the hulls still standing; destroyed ships stay destroyed.
func _end_ships(result: String) -> void:
	ships_active = false
	_withdraw_squad(result == "success")
	for ship in _warships:
		if ship.intact:
			ship.restore()
		ship.set_open_for_mines(false)
	for unit in _fleet_guards:
		if is_instance_valid(unit):
			_republic_units.erase(unit)
			unit.queue_free()
	_fleet_guards.clear()
	_refresh_front_hud()
