class_name PomidorWorld
extends GameWorld

## Pomidor, where the Council of all six Confederation planets meets.
##
## The Council chamber is a walled room in the southwest corner of the same map.
## The Council Hall door moves the player into it and the chamber doors move
## them back out, so the chamber needs no scene or save area of its own.

const POMIDOR_MAP := "res://maps/pomidor.tmj"
const COUNCIL_SERVICE_PREFIX := "pomidor_council:"
const POMIDOR_NAMES := [
	"Rosa", "Dino", "Lucia", "Marko", "Petra", "Sandi", "Vesna", "Tino", "Zora", "Bruno",
	"Ines", "Kosta", "Mila", "Nino", "Olga", "Paolo", "Rada", "Silvio", "Tea", "Vito",
	"Ana", "Boris", "Cvita", "Davor", "Ela", "Franko", "Gita", "Hrvoje", "Iva", "Jure",
	"Klara", "Lovro", "Maja", "Neno", "Ora", "Pino",
]

## Who sits in the chamber, keyed by the map object name after its prefix.
## Big Council members carry their planet; Secretaries carry their office.
const COUNCIL := {
	"member_paprika_0": {"name": "Councillor Ilka Vrba", "planet": "Paprika"},
	"member_paprika_1": {"name": "Councillor Teo Marn", "planet": "Paprika"},
	"member_pomidor_0": {"name": "Councillor Rosa Pelat", "planet": "Pomidor"},
	"member_pomidor_1": {"name": "Councillor Dino Sugo", "planet": "Pomidor"},
	"member_brudet_0": {"name": "Councillor Neri Valo", "planet": "Brudet"},
	"member_brudet_1": {"name": "Councillor Ana Brod", "planet": "Brudet"},
	"member_artichoke_0": {"name": "Councillor Jarek Stan", "planet": "Artichoke"},
	"member_artichoke_1": {"name": "Councillor Oleh Kardo", "planet": "Artichoke"},
	"member_cichvarda_0": {"name": "Councillor Mirna Ceh", "planet": "Cichvarda"},
	"member_cichvarda_1": {"name": "Councillor Bo Cichy", "planet": "Cichvarda"},
	"member_chvarak_0": {"name": "Councillor Dag Hvar", "planet": "Chvarak"},
	"member_chvarak_1": {"name": "Councillor Lira Kost", "planet": "Chvarak"},
	"secretary_army": {"name": "Secretary of the Army Marko Vojnic", "office": "army"},
	"secretary_gold": {"name": "Secretary of Gold Zlata Kun", "office": "gold"},
	"secretary_law": {"name": "Secretary of Law Pravdan Ruz", "office": "law"},
	"secretary_economy": {"name": "Secretary of the Economy Lena Trg", "office": "economy"},
	"secretary_diplomacy": {"name": "Secretary of Diplomacy Iva Most", "office": "diplomacy"},
	"secretary_navy": {"name": "Secretary of the Navy and Transport Luka Plov", "office": "navy"},
}
## Set once the player has reported on Artichoke to the Secretary of the Army.
const REPORTED_FLAG := "pomidor_reported_to_council"
const REPORT_REWARD := 300
## The chamber's floor inside its walls; tools/build_pomidor_world.py CHAMBER.
const CHAMBER_RECT := Rect2(48, 752, 320, 384)

var _hall_door := Vector2(INF, INF)
var _chamber_entry := Vector2(INF, INF)
var _council: Dictionary = {}

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
	if not tiled_loader.load_map(POMIDOR_MAP):
		push_error("Pomidor map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	if player == null:
		_spawn_player(GameState.POMIDOR_ARRIVAL, "res://art/concepts/source/player.png")
	_find_doors()
	player.global_position = _safe_loaded_position(GameState.player_position)
	_assign_town_routines()
	GameState.squad_changed.connect(_sync_squad)
	_sync_squad()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = GameState.POMIDOR_ARRIVAL
	player.respawn_location_name = "Pomidor"

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, stable_id: String) -> void:
	if kind != "council":
		super._on_actor_spawn_requested(kind, position, variant, stable_id)
		return
	var key := stable_id.trim_prefix("council_")
	if not COUNCIL.has(key):
		push_error("Unknown Council seat on the Pomidor map: %s" % stable_id)
		return
	var person := StationStaff.new()
	person.name = stable_id
	person.configure(COUNCIL_SERVICE_PREFIX + key, String(COUNCIL[key]["name"]), variant, position)
	person.service_requested.connect(_on_service_requested)
	actors_root.add_child(person)
	_council[key] = person

## Council seat keys in the order of the COUNCIL table.
func council_keys() -> Array:
	return COUNCIL.keys()

func council_person(key: String) -> StationStaff:
	return _council.get(key, null)

func _find_doors() -> void:
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	if map_objects == null:
		return
	var exit_node: WorldService
	for node in map_objects.get_children():
		if node is WorldService and node.service_id == "pomidor_council_hall":
			_hall_door = node.get_interaction_position()
		elif node is WorldService and node.service_id == "chamber_exit":
			exit_node = node
	if exit_node == null or not _hall_door.is_finite():
		push_error("The Pomidor Council Hall or its chamber doors are missing.")
		return
	_chamber_entry = _nearby_open_position(exit_node.global_position + Vector2(16, -14))

func in_council_chamber(position: Vector2 = Vector2.INF) -> bool:
	if position == Vector2.INF:
		position = player.global_position if player != null else Vector2.ZERO
	return CHAMBER_RECT.has_point(position)

func hall_door() -> Vector2:
	return _hall_door

func chamber_entry() -> Vector2:
	return _chamber_entry

func enter_council_chamber() -> bool:
	if not _chamber_entry.is_finite() or player == null:
		return false
	player.global_position = _chamber_entry
	GameState.player_position = player.global_position
	GameState.notify("You enter the Council chamber. The Big Council sits at the long table; the six Secretaries of the Small Council work at their desks.")
	_refresh_location_title()
	return true

func leave_council_chamber() -> bool:
	if not _hall_door.is_finite() or player == null:
		return false
	player.global_position = _nearby_open_position(_hall_door + Vector2(0, 12))
	GameState.player_position = player.global_position
	_refresh_location_title()
	return true

func _refresh_location_title() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("refresh_location"):
		ui.refresh_location()

func _on_service_requested(service_id: String, display_name: String) -> void:
	match service_id:
		"pomidor_council_hall": enter_council_chamber()
		"chamber_exit": leave_council_chamber()
		_: super._on_service_requested(service_id, display_name)

func reported_to_council() -> bool:
	return GameState.defeated_persistent_enemies.has(REPORTED_FLAG)

## The player tells the Secretary of the Army what was done on Artichoke.
func report_to_council() -> bool:
	if reported_to_council():
		return false
	GameState.defeated_persistent_enemies.append(REPORTED_FLAG)
	GameState.add_gold(REPORT_REWARD)
	GameState.record_event("pomidor_reported")
	GameState.notify("The Council heard your report on Artichoke. The Secretary of Gold pays you %d gold from the common treasury." % REPORT_REWARD)
	return true

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_squad_ai.clear()
	_sync_squad()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if tiled_loader.is_walkable_position(saved):
		return saved
	var tile := Vector2(tiled_loader.tile_size)
	var cell := Vector2(floorf(saved.x / tile.x), floorf(saved.y / tile.y))
	for radius in range(1, 9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := (cell + Vector2(x, y) + Vector2(0.5, 0.5)) * tile
				if tiled_loader.is_walkable_position(candidate):
					return candidate
	return _nearby_open_position(GameState.POMIDOR_ARRIVAL)

func _assign_town_routines() -> void:
	var services: Dictionary = {}
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	for node in map_objects.get_children():
		if node is WorldService:
			services[node.service_id] = (node as WorldService).get_interaction_position()
	var townsfolk: Array[Villager] = []
	for actor in actors_root.get_children():
		if actor is Villager:
			townsfolk.append(actor)
	townsfolk.sort_custom(func(a: Villager, b: Villager) -> bool: return a.villager_id < b.villager_id)
	var fountain := _hall_door + Vector2(0, 80)
	for index in townsfolk.size():
		var person := townsfolk[index]
		person._navigation = tiled_loader
		person.villager_name = POMIDOR_NAMES[index % POMIDOR_NAMES.size()]
		person.interaction_text = "Talk to %s" % person.villager_name
		var role := "pomidor_market" if index % 3 == 0 else ("pomidor_clerk" if index % 3 == 1 else "pomidor_neighbor")
		var stops: Array[Dictionary] = [{"kind": "home", "position": person.home_position, "wait": 2.0}]
		stops.append({"kind": "square", "position": _nearby_open_position(fountain + Vector2((index % 7 - 3) * 18, (index % 3) * 14)), "wait": 3.0})
		var errand := "pomidor_market" if role == "pomidor_market" else ("pomidor_library" if role == "pomidor_clerk" else "beer_hall")
		if services.has(errand):
			stops.append({"kind": "market" if errand == "pomidor_market" else "library", "position": _nearby_open_position(Vector2(services[errand]) + Vector2(0, 10)), "wait": 4.0})
		person.configure_routine(role, stops)
