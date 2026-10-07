class_name ChvarakWorld
extends GameWorld

## Chvarak, a farming planet in the mountains, where the embassy to Engineeria
## changes ships.
##
## The diplomatic ship's interior is a walled room on the same map, in open
## space below the southern mountains. Boarding moves the player and the envoys
## into it. Hackers paid by Julius board the ship in flight; the fight cannot be
## won, and after FLIGHT_SECONDS, or as soon as the player is downed, the ship
## goes down and the story moves the player to Engineeria.

const CHVARAK_MAP := "res://maps/chvarak.tmj"
const STORY_SERVICE_PREFIX := "chvarak_story:"
const STORY_PEOPLE := {
	"guard": "Port Guard Stipe",
	"envoy_0": "Envoy Petar Lis",
	"envoy_1": "Envoy Nada Grof",
	"envoy_2": "Envoy Oto Ban",
}
const ENVOYS := ["envoy_0", "envoy_1", "envoy_2"]
const FARMER_NAMES := ["Bara", "Grgo", "Jela", "Mato", "Ruza", "Stipan", "Tona", "Vid", "Zdenka", "Ivek", "Kata", "Luka"]
## Fenced pastures in cells, fences included; tools/build_chvarak_world.py PENS.
const PENS := [Rect2i(37, 20, 15, 8), Rect2i(53, 20, 9, 8), Rect2i(39, 32, 17, 10)]
## The ship room with its walls; tools/build_chvarak_world.py SHIP.
const SHIP_RECT := Rect2(320, 960, 384, 224)
## Where the player stands on board when the flight starts, by the cabin.
const SHIP_ENTRY := Vector2(488, 1096)
## Where the envoys sit in the cabin.
const CABIN_SEATS := [Vector2(352, 1078), Vector2(376, 1126), Vector2(400, 1078)]
## Where the ship's two guards stand, between the cabin and the hatch.
const GUARD_POSTS := [Vector2(560, 1080), Vector2(560, 1130)]
## The hatch the hackers cut through, at the east end of the ship.
const HATCH_SPAWNS := [Vector2(664, 1056), Vector2(648, 1092), Vector2(668, 1126), Vector2(640, 1140)]
## In front of the boarding ramp on the east pad. A save made in flight loads here.
const BOARD_POSITION := Vector2(740, 254)
const ALARM_SECONDS := 6.0
const FLIGHT_SECONDS := 50.0
## When each group of hackers comes through the hatch, in seconds of flight.
const WAVES := [
	{"at": ALARM_SECONDS, "kinds": ["hacker", "hacker"]},
	{"at": 20.0, "kinds": ["hacker", "hacker", "phase_hacker"]},
	{"at": 34.0, "kinds": ["hacker", "hacker", "hacker"]},
]
const SHIP_GUARD_HEALTH := 80
## Julius's hired hackers hit far softer than Paprika's level-5 hacker (18), so a
## player with 20 health can hold the corridor through more than one group
## before the ship goes down.
const AMBUSH_DAMAGE := {"hacker": 6, "phase_hacker": 5}

var _story: Dictionary = {}
var _flying := false
## Seconds since the ship took off; it counts once the take-off lines are read.
var _flight_time := -1.0
var _next_wave := 0
var _crashing := false
var _ambushers: Array[Enemy] = []
var _ship_guards: Array[RaidSoldier] = []

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	tiled_loader.service_requested.connect(_on_service_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(CHVARAK_MAP):
		push_error("Chvarak map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	if player == null:
		_spawn_player(GameState.CHVARAK_ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	_assign_farm_routines()
	_sync_story_people()
	GameState.squad_changed.connect(_sync_squad)
	_sync_squad()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = GameState.CHVARAK_ARRIVAL
	player.respawn_location_name = "Chvarak"

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, stable_id: String) -> void:
	match kind:
		"story":
			if not STORY_PEOPLE.has(stable_id):
				push_error("Unknown story person on the Chvarak map: %s" % stable_id)
				return
			var someone := StationStaff.new()
			someone.name = "story_" + stable_id
			someone.configure(STORY_SERVICE_PREFIX + stable_id, String(STORY_PEOPLE[stable_id]), variant, position)
			someone.service_requested.connect(_on_service_requested)
			actors_root.add_child(someone)
			_story[stable_id] = someone
		"animal":
			var animal := FarmAnimal.new()
			animal.configure(stable_id, variant, position, _pasture_at(position))
			actors_root.add_child(animal)
		_:
			super._on_actor_spawn_requested(kind, position, variant, stable_id)

## The inside of the fenced pasture around `point`, in world coordinates.
func _pasture_at(point: Vector2) -> Rect2:
	var tile := Vector2(tiled_loader.tile_size)
	for pen: Rect2i in PENS:
		var area := Rect2(Vector2(pen.position) * tile, Vector2(pen.size) * tile)
		if area.has_point(point):
			# One tile in from the fence, and room for the sprite above its feet.
			return Rect2(area.position + Vector2(tile.x + 8, tile.y + 14), area.size - Vector2(tile.x * 2 + 16, tile.y * 2 + 14))
	return Rect2(point - Vector2(24, 16), Vector2(48, 32))

func story_person(key: String) -> StationStaff:
	return _story.get(key, null)

func farm_animals() -> Array[FarmAnimal]:
	var animals: Array[FarmAnimal] = []
	for actor in actors_root.get_children():
		if actor is FarmAnimal:
			animals.append(actor)
	return animals

func location_title() -> String:
	return "DIPLOMATIC SHIP" if on_ship() else "CHVARAK"

func on_ship(position: Vector2 = Vector2.INF) -> bool:
	if position == Vector2.INF:
		position = player.global_position if player != null else Vector2.ZERO
	return SHIP_RECT.has_point(position)

func flying() -> bool:
	return _flying

func flight_time() -> float:
	return _flight_time

func ambushers() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for enemy in _ambushers:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			alive.append(enemy)
	return alive

func ship_guards() -> Array[RaidSoldier]:
	return _ship_guards

## Objective text for the HUD panel in the top right.
func story_status_text() -> String:
	if _flying:
		if _flight_time >= ALARM_SECONDS:
			return "DIPLOMATIC SHIP\nHackers are boarding through the hatch\nKeep them away from the cabin"
		return "DIPLOMATIC SHIP\nOn the way to Engineeria"
	return "CHVARAK\nWalk the envoys to the diplomatic ship\non the east pad"

func _has_flag(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has(flag)

func _set_flag(flag: String) -> void:
	if not _has_flag(flag):
		GameState.defeated_persistent_enemies.append(flag)
	GameState.military_changed.emit()

func _sync_story_people() -> void:
	var waiting := _has_flag(PomidorWorld.EMBASSY_FLAG) and not _has_flag(PomidorWorld.DEPARTED_FLAG)
	for key in ENVOYS:
		_set_present(key, waiting, not _flying)

func _set_present(key: String, present: bool, talkable: bool = true) -> void:
	var someone := story_person(key)
	if someone == null:
		return
	someone.visible = present
	if present and talkable and not someone.is_in_group("interactable"):
		someone.add_to_group("interactable")
	elif not present or not talkable:
		someone.remove_from_group("interactable")

func _on_service_requested(service_id: String, display_name: String) -> void:
	if service_id.begins_with(STORY_SERVICE_PREFIX):
		talk_to(service_id.trim_prefix(STORY_SERVICE_PREFIX))
		return
	match service_id:
		"chvarak_terminal": _talk_terminal()
		"diplomatic_ship": _offer_boarding()
		_: super._on_service_requested(service_id, display_name)

func _play(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("play_scene"):
		ui.play_scene(lines, finished, choices)
	else:
		for line: Dictionary in lines:
			GameState.notify(String(line["text"]))
		if finished.is_valid():
			finished.call()

func _line(key: String, text: String) -> Dictionary:
	if key.is_empty():
		return {"speaker": "", "text": text}
	return {"speaker": String(STORY_PEOPLE[key]), "text": text, "focus": story_person(key)}

func talk_to(key: String) -> void:
	match key:
		"guard":
			_play([
				_line("guard", "Welcome to Chvarak. Mind the cows on the road down; they have right of way here."),
				_line("guard", "That white ship on the east pad came in from Pomidor last night for your envoys. The pilot is waiting on board."),
			])
		"envoy_0":
			_play([_line("envoy_0", "Chvarak smells of hay and cows. I like it. The ship is on the east pad; we board when you are ready.")])
		"envoy_1":
			_play([_line("envoy_1", "From here it is open space all the way to Engineeria. That is where ships get stopped, if they get stopped.")])
		"envoy_2":
			_play([_line("envoy_2", "Those are real mountains. I have only ever seen them in the Pomidor library.")])

func _talk_terminal() -> void:
	_play([
		{"speaker": "Spaceport Clerk", "text": "Chvarak Spaceport. Two pads, one terminal, and more cattle through here than travellers."},
		{"speaker": "Spaceport Clerk", "text": "Grain and cattle go up to Pomidor every week. Someone keeps buying more than gets delivered, mind you. Crates go missing between here and the market."},
	])

# ---- boarding and the flight ----

func _offer_boarding() -> void:
	if _flying:
		return
	if not _has_flag(PomidorWorld.EMBASSY_FLAG) or _has_flag(PomidorWorld.DEPARTED_FLAG):
		_play([{"speaker": "", "text": "The ship's hatch is shut. It flies only for the Council's embassy."}])
		return
	_play([
		_line("envoy_0", "Our ship. Iva Most hired the pilot himself; she has flown to Engineeria a dozen times."),
		_line("envoy_2", "Are we really going? All right. All right."),
	], Callable(), [
		{"label": "Board the ship", "action": board_ship},
		{"label": "Not yet", "action": Callable()},
	])

## The player and the envoys board, and the ship takes off for Engineeria.
func board_ship() -> bool:
	if _flying or not _has_flag(PomidorWorld.EMBASSY_FLAG) or _has_flag(PomidorWorld.DEPARTED_FLAG):
		return false
	_flying = true
	_crashing = false
	_flight_time = -1.0
	_next_wave = 0
	player.global_position = SHIP_ENTRY
	player.respawn_position = SHIP_ENTRY
	player.respawn_notice = "You go down hard on the deck."
	for index in ENVOYS.size():
		var envoy := story_person(ENVOYS[index])
		if envoy != null:
			envoy.global_position = CABIN_SEATS[index]
	_sync_story_people()
	for index in GUARD_POSTS.size():
		var guard := RaidSoldier.new()
		guard.configure("ship_guard_%d" % index, "Ship Guard", "res://assets/art/chvarak/ship_guard_%d.png" % index, GUARD_POSTS[index], "sword", index, self)
		guard.max_health = SHIP_GUARD_HEALTH
		guard.health = SHIP_GUARD_HEALTH
		actors_root.add_child(guard)
		guard.hunt(Vector2.INF, GUARD_POSTS[index], "guard the ship")
		_ship_guards.append(guard)
	_refresh_location_title()
	GameState.military_changed.emit()
	_play([
		{"speaker": "", "text": "The hatch closes. The engines start, and Chvarak's mountains drop away under the windows."},
		_line("envoy_1", "Four days to Engineeria, if the pilot keeps to the open lanes."),
		_line("envoy_0", "Then we have time to read the letters again. Captain, sit down; nothing happens out here for hours."),
	], _start_flight_clock)
	return true

func _start_flight_clock() -> void:
	if _flying and _flight_time < 0.0:
		_flight_time = 0.0

func _physics_process(delta: float) -> void:
	if not _flying or _crashing or _flight_time < 0.0:
		return
	_flight_time += delta
	while _next_wave < WAVES.size() and _flight_time >= float(WAVES[_next_wave]["at"]):
		_send_wave(_next_wave)
		_next_wave += 1
	if _flight_time >= FLIGHT_SECONDS:
		crash()

## Runs the flight clock forward; used by the tests.
func advance_flight(seconds: float) -> void:
	if _flight_time < 0.0:
		_start_flight_clock()
	var step := 0.25
	var left := seconds
	while left > 0.0 and _flying and not _crashing:
		_physics_process(minf(step, left))
		left -= step

func _send_wave(index: int) -> void:
	if index == 0:
		GameState.notify("Alarm! Something is cutting through the hatch at the back of the ship!")
		screen_flash(Color(0.9, 0.1, 0.1, 0.35), 0.6)
		shake_camera(0.4, 3.0)
		GameState.military_changed.emit()
	else:
		GameState.notify("More hackers come through the hatch.")
	var kinds: Array = WAVES[index]["kinds"]
	var ship_center := SHIP_RECT.get_center() + Vector2(0, 24)
	for slot in kinds.size():
		var kind := String(kinds[slot])
		var hacker := Enemy.new()
		var texture := "res://assets/art/hacker.png"
		hacker.configure(kind, texture, HATCH_SPAWNS[slot % HATCH_SPAWNS.size()], "story_ambush_%d_%d_%d" % [Time.get_ticks_msec(), index, slot])
		hacker.definition["damage"] = AMBUSH_DAMAGE[kind]
		# Their leash centres on the ship, so they go after anyone in it.
		hacker.spawn_position = ship_center
		actors_root.add_child(hacker)
		_ambushers.append(hacker)

## The ship is hit and goes down. The story continues in Engineeria.
func crash() -> void:
	if not _flying or _crashing:
		return
	_crashing = true
	_clear_flight_fighters()
	_set_flag(PomidorWorld.DEPARTED_FLAG)
	_set_flag(GameState.CRASH_FLAG)
	GameState.record_event("embassy_ship_down")
	screen_flash(Color(1.0, 0.25, 0.1, 0.8), 1.2, 0.2)
	shake_camera(1.6, 6.0)
	_play([
		{"speaker": "", "text": "Something hits the ship from outside. The deck jumps, the lights go red, and the windows fill with fire."},
		_line("envoy_0", "The engines! They are shooting the engines!"),
		{"speaker": "", "text": "A planet swings into the windows, green and close. The ship is falling."},
		_line("envoy_1", "Hold on to something! Hold on—"),
		{"speaker": "", "text": "The noise stops all at once."},
	], _go_down)

func _go_down() -> void:
	var cover := screen_flash(Color.BLACK, 0.4, 0.6)
	cover.modulate.a = 1.0
	_flying = false
	player.respawn_notice = ""
	call_deferred("emit_signal", "story_travel_requested", "engineeria")

func _clear_flight_fighters() -> void:
	for enemy in _ambushers:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_ambushers.clear()
	for guard in _ship_guards:
		if is_instance_valid(guard):
			guard.queue_free()
	_ship_guards.clear()
	for projectile in actors_root.get_children():
		if projectile is Projectile:
			projectile.queue_free()

## Ends a flight that a load interrupted: the player is back on the pad and
## the envoys wait by the ship again.
func _cancel_flight() -> void:
	if not _flying:
		return
	_flying = false
	_crashing = false
	_flight_time = -1.0
	_clear_flight_fighters()
	_place_envoys_at_pad()
	player.respawn_position = GameState.CHVARAK_ARRIVAL
	player.respawn_notice = ""
	_sync_story_people()

func _place_envoys_at_pad() -> void:
	for index in ENVOYS.size():
		var envoy := story_person(ENVOYS[index])
		if envoy != null:
			envoy.global_position = BOARD_POSITION + Vector2(36 + index * 18, 14)

func _on_player_respawned() -> void:
	if _flying and not _crashing:
		crash()
		return
	super._on_player_respawned()

func capture_player_position() -> void:
	super.capture_player_position()
	# The flight cannot be saved halfway; a save in flight keeps the player on the pad.
	if on_ship(GameState.player_position):
		GameState.player_position = BOARD_POSITION

func apply_loaded_state() -> void:
	_cancel_flight()
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_squad_ai.clear()
	_sync_story_people()
	_sync_squad()
	_refresh_location_title()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if on_ship(saved):
		saved = BOARD_POSITION
	if tiled_loader.is_walkable_position(saved):
		return saved
	return _nearby_open_position(saved if saved.is_finite() else GameState.CHVARAK_ARRIVAL)

func _refresh_location_title() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("refresh_location"):
		ui.refresh_location()

func _assign_farm_routines() -> void:
	var farmers: Array[Villager] = []
	for actor in actors_root.get_children():
		if actor is Villager:
			farmers.append(actor)
	farmers.sort_custom(func(a: Villager, b: Villager) -> bool: return a.villager_id < b.villager_id)
	var crossroads := Vector2(32 * 16, 30 * 16)
	for index in farmers.size():
		var farmer := farmers[index]
		farmer._navigation = tiled_loader
		farmer.villager_name = FARMER_NAMES[index % FARMER_NAMES.size()]
		farmer.interaction_text = "Talk to %s" % farmer.villager_name
		var role := "chvarak_herder" if index % 3 == 2 else "chvarak_farmer"
		var stops: Array[Dictionary] = [{"kind": "home", "position": farmer.home_position, "wait": 4.0}]
		stops.append({"kind": "square", "position": _nearby_open_position(crossroads + Vector2((index % 5 - 2) * 20, (index % 2) * 12)), "wait": 3.0})
		stops.append({"kind": "home", "position": _nearby_open_position(farmer.home_position + Vector2((index % 3 - 1) * 40, 24)), "wait": 5.0})
		farmer.configure_routine(role, stops)
