class_name BrudetWorld
extends GameWorld

const TargetScript = preload("res://scripts/world/practice_target.gd")
const BRUDET_MAP := "res://maps/brudet.tmj"
const FISHING_COOLDOWN := 15.0
const RIVER_NAMES := [
	"Ayla", "Belen", "Ciro", "Dalia", "Eren", "Fara", "Gio", "Hana", "Ivo", "Juna",
	"Kora", "Leto", "Mina", "Neri", "Olia", "Piro", "Quin", "Ravi", "Suna", "Tali",
	"Una", "Vero", "Willa", "Xena", "Yara", "Zeno", "Ada", "Borin", "Celia", "Daro",
]

var _target: TargetScript

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
	if not tiled_loader.load_map(BRUDET_MAP):
		push_error("Brudet map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	if player == null:
		_spawn_player(GameState.BRUDET_ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	for actor in actors_root.get_children():
		if actor is Enemy and actor.enemy_id in ["finling", "lake_maw", "river_serpent"]:
			actor._choose_patrol()
	_assign_river_routines()
	_spawn_practice_target()
	GameState.squad_changed.connect(_sync_squad)
	_sync_squad()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = GameState.BRUDET_ARRIVAL
	player.respawn_location_name = "Brudet"

func _sync_camp() -> void:
	# Paprika's bandit camp is never created on Brudet.
	pass

func capture_player_position() -> void:
	if player != null:
		GameState.player_position = player.global_position

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_squad_ai.clear()
	_sync_squad()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	return saved if tiled_loader.is_walkable_position(saved) else _nearby_open_position(GameState.BRUDET_ARRIVAL)

func _on_service_requested(service_id: String, display_name: String) -> void:
	if service_id in ["fishing_pond", "fishing"]:
		try_fish()
	else:
		super._on_service_requested(service_id, display_name)

func try_fish() -> bool:
	if int(GameState.inventory.get("fishing_rod", 0)) <= 0:
		GameState.notify("You need a fishing rod to fish here.")
		return false
	var ready_at := GameState.fishing_ready_at
	if GameState.play_seconds < ready_at:
		GameState.notify("Wait %d seconds before fishing again." % ceili(ready_at - GameState.play_seconds))
		return false
	if not GameState.add_item("river_fish"):
		GameState.notify("The catch could not be added to your inventory.")
		return false
	GameState.fishing_ready_at = GameState.play_seconds + FISHING_COOLDOWN
	GameState.record_event("river_fish_caught")
	GameState.notify("Caught a river fish!")
	return true

func _assign_river_routines() -> void:
	var services: Dictionary = {}
	var ponds: Array[Vector2] = []
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	for node in map_objects.get_children():
		if node is WorldService:
			var position := (node as WorldService).get_interaction_position()
			if node.service_id in ["fishing_pond", "fishing"]:
				ponds.append(position)
			else:
				services[node.service_id] = position
	var villagers: Array[Villager] = []
	for actor in actors_root.get_children():
		if actor is Villager:
			villagers.append(actor)
	villagers.sort_custom(func(a: Villager, b: Villager) -> bool: return a.villager_id < b.villager_id)
	if villagers.size() != 30:
		push_error("Expected 30 Brudet villagers, found %d." % villagers.size())
	for index in villagers.size():
		var villager := villagers[index]
		villager._navigation = tiled_loader
		villager.villager_name = RIVER_NAMES[index % RIVER_NAMES.size()]
		villager.interaction_text = "Talk to %s" % villager.villager_name
		var home := villager.home_position
		var role := "fisher" if villager.villager_id.contains("_fisher") or index % 4 == 0 else ("river_farmer" if index % 5 == 0 else ("river_market" if index % 3 == 0 else "river_neighbor"))
		var stops: Array[Dictionary] = [{"kind": "home", "position": home, "wait": 2.0}]
		var plaza := _nearby_open_position(home + Vector2(24 if index % 2 == 0 else -24, 20))
		stops.append({"kind": "square", "position": plaza, "wait": 3.0})
		if role == "fisher" and not ponds.is_empty():
			var pond := _closest_position(home, ponds)
			stops.append({"kind": "fishing", "position": _nearby_open_position(pond), "wait": 5.0})
		elif role == "river_farmer":
			stops.append({"kind": "field", "position": _nearby_open_position(home + Vector2(32, -20)), "wait": 4.0})
		elif role == "river_market" and services.has("river_market"):
			stops.append({"kind": "market", "position": _nearby_open_position(Vector2(services["river_market"]) + Vector2(0, 10)), "wait": 4.0})
		elif services.has("river_library"):
			stops.append({"kind": "library", "position": _nearby_open_position(Vector2(services["river_library"]) + Vector2(0, 10)), "wait": 3.0})
		villager.configure_routine(role, stops)

func _closest_position(origin: Vector2, points: Array[Vector2]) -> Vector2:
	var nearest := points[0]
	for point in points:
		if origin.distance_squared_to(point) < origin.distance_squared_to(nearest):
			nearest = point
	return nearest

func _spawn_practice_target() -> void:
	var hq_position := GameState.BRUDET_ARRIVAL
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	for node in map_objects.get_children():
		if node is WorldService and node.service_id == "military_hq":
			hq_position = node.get_interaction_position()
			break
	var position := _nearby_open_position(hq_position + Vector2(52, 18))
	var data = JSON.parse_string(FileAccess.get_file_as_string(BRUDET_MAP))
	if data is Dictionary:
		for layer in data.get("layers", []):
			if not layer is Dictionary or String(layer.get("type", "")) != "objectgroup":
				continue
			for object in layer.get("objects", []):
				if object is Dictionary and String(object.get("name", "")) == "arrow_target":
					position = Vector2(float(object.get("x", 0)) + float(object.get("width", 0)) * 0.5, float(object.get("y", 0)) - 2.0)
					break
	_target = TargetScript.new()
	_target.name = "PracticeTarget"
	_target.position = position
	actors_root.add_child(_target)
	# A TiledLoader without explicit target handling creates a decorative duplicate.
	if map_objects != null:
		var decoration := map_objects.get_node_or_null("arrow_target")
		if decoration != null:
			decoration.visible = false
