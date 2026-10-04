class_name BrudetWorld
extends GameWorld

const TargetScript = preload("res://scripts/world/practice_target.gd")
const BRUDET_MAP := "res://maps/brudet.tmj"
const FISHING_COOLDOWN := 15.0
const TEAM_SPAWN_AREAS := {
	"brudet_monster_team": Rect2(1824, 912, 272, 240),
	"brudet_bandit_team": Rect2(1808, 1320, 312, 200),
	"brudet_hacker_team": Rect2(1904, 128, 224, 208),
}
const TEAM_SPAWN_POINTS := {
	"brudet_monster_team": [Vector2(1856, 960), Vector2(1984, 1008), Vector2(1920, 1088)],
	"brudet_bandit_team": [Vector2(1840, 1392), Vector2(1968, 1360), Vector2(2056, 1480)],
	"brudet_hacker_team": [Vector2(2016, 224)],
}
const TEAM_MONSTER_KINDS := ["finling", "lake_maw", "river_serpent"]
const TEAM_MONSTER_TEXTURES := ["res://assets/art/river_planet/finling.png", "res://assets/art/river_planet/lake_maw.png", "res://assets/art/river_planet/river_serpent.png"]
const TEAM_HACKER_TEXTURE := "res://assets/art/hacker.png"
const RIVER_NAMES := [
	"Ayla", "Belen", "Ciro", "Dalia", "Eren", "Fara", "Gio", "Hana", "Ivo", "Juna",
	"Kora", "Leto", "Mina", "Neri", "Olia", "Piro", "Quin", "Ravi", "Suna", "Tali",
	"Una", "Vero", "Willa", "Xena", "Yara", "Zeno", "Ada", "Borin", "Celia", "Daro",
]

var _target: TargetScript
var _team_camp_marker: Node2D

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
	GameState.job_changed.connect(_sync_solo_hacker)
	_sync_squad()
	_sync_solo_hacker()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = GameState.BRUDET_ARRIVAL
	player.respawn_location_name = "Brudet"

func _sync_camp() -> void:
	var job_id: String = GameState.team_job_id if GameState.squad_deployed else ""
	if not GameState.BRUDET_TEAM_IDS.has(job_id):
		job_id = ""
	var expected_ids: Array = GameState.BRUDET_TEAM_IDS.get(job_id, [])
	if job_id == "brudet_bandit_team" and not is_instance_valid(_team_camp_marker):
		_build_team_camp_marker()
	elif job_id != "brudet_bandit_team" and is_instance_valid(_team_camp_marker):
		_team_camp_marker.queue_free()
		_team_camp_marker = null
	for actor in actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("brudet_team_"):
			if not expected_ids.has(actor.persistent_id) or GameState.team_defeated_ids.has(actor.persistent_id):
				actor.queue_free()
	if job_id.is_empty():
		return
	var used_positions: Array[Vector2] = []
	for index in expected_ids.size():
		var stable_id: String = expected_ids[index]
		if GameState.team_defeated_ids.has(stable_id):
			continue
		var exists := false
		for actor in actors_root.get_children():
			if actor is Enemy and actor.persistent_id == stable_id and not actor.is_queued_for_deletion():
				exists = true
				used_positions.append(actor.global_position)
				break
		if exists:
			continue
		var position := _team_walk_position(job_id, index, used_positions)
		if not position.is_finite():
			continue
		used_positions.append(position)
		var kind: String = ["bandit_spear", "bandit_bow", "bandit_sword"][index]
		var texture: String = CAMP_TEXTURE
		if job_id == "brudet_monster_team":
			kind = TEAM_MONSTER_KINDS[index]
			texture = TEAM_MONSTER_TEXTURES[index]
		elif job_id == "brudet_hacker_team":
			kind = "phase_hacker"
			texture = TEAM_HACKER_TEXTURE
		_spawn_enemy(kind, position, texture, stable_id)
		var enemy := actors_root.get_child(actors_root.get_child_count() - 1) as Enemy
		var marker := Label.new()
		marker.text = "TEAM TARGET"
		marker.position = Vector2(-42, -48)
		marker.size = Vector2(84, 16)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 9)
		marker.add_theme_color_override("font_color", Color("ffe071"))
		enemy.add_child(marker)

func _sync_solo_hacker() -> void:
	var active := GameState.team_job_id.is_empty() and GameState.active_jobs.has(GameState.BRUDET_SOLO_HACKER_JOB) and int(GameState.active_jobs[GameState.BRUDET_SOLO_HACKER_JOB]) < 1
	var existing: Enemy
	for actor in actors_root.get_children():
		if actor is Enemy and actor.persistent_id == GameState.BRUDET_SOLO_HACKER_ID and not actor.is_queued_for_deletion():
			existing = actor
			break
	if not active:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var used_positions: Array[Vector2] = []
	for actor in actors_root.get_children():
		if actor is Enemy and actor.persistent_id == "brudet_team_hacker_0" and not actor.is_queued_for_deletion():
			used_positions.append(actor.global_position)
	var position := _team_walk_position("brudet_hacker_team", 0, used_positions)
	if not position.is_finite():
		return
	_spawn_enemy("phase_hacker", position, TEAM_HACKER_TEXTURE, GameState.BRUDET_SOLO_HACKER_ID)
	var enemy := actors_root.get_child(actors_root.get_child_count() - 1) as Enemy
	var marker := Label.new()
	marker.text = "SOLO TARGET"
	marker.position = Vector2(-42, -48)
	marker.size = Vector2(84, 16)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 9)
	marker.add_theme_color_override("font_color", Color("ffe071"))
	enemy.add_child(marker)

func _build_team_camp_marker() -> void:
	_team_camp_marker = Node2D.new()
	_team_camp_marker.name = "BrudetBanditCamp"
	_team_camp_marker.position = Vector2(1944, 1456)
	_team_camp_marker.z_index = 40
	actors_root.add_child(_team_camp_marker)
	var tent := Polygon2D.new()
	tent.polygon = PackedVector2Array([Vector2(-28, 5), Vector2(-12, -22), Vector2(7, 5)])
	tent.color = Color("855043")
	_team_camp_marker.add_child(tent)
	var fire := Polygon2D.new()
	fire.polygon = PackedVector2Array([Vector2(12, 6), Vector2(18, -11), Vector2(24, 6)])
	fire.color = Color("f6a94a")
	_team_camp_marker.add_child(fire)
	var label := Label.new()
	label.text = "BANDIT CAMP"
	label.position = Vector2(-36, -43)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("f6d391"))
	_team_camp_marker.add_child(label)

func _team_walk_position(job_id: String, index: int, used_positions: Array[Vector2]) -> Vector2:
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	var hall_position := Vector2(INF, INF)
	if map_objects != null:
		for node in map_objects.get_children():
			if node is WorldService and node.service_id == "river_town_hall":
				hall_position = node.get_interaction_position()
				break
	if not hall_position.is_finite():
		push_error("Brudet Town Hall is missing; team targets cannot be placed.")
		return Vector2(INF, INF)
	var area: Rect2 = TEAM_SPAWN_AREAS[job_id]
	var desired: Vector2 = TEAM_SPAWN_POINTS[job_id][index]
	for radius in range(8):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := desired + Vector2(x, y) * 16.0
				if not area.has_point(candidate) or not tiled_loader.is_walkable_position(candidate):
					continue
				var separated := true
				for used in used_positions:
					if used.distance_to(candidate) < 96.0:
						separated = false
						break
				if not separated:
					continue
				var arrival_path := tiled_loader.get_walk_path(GameState.BRUDET_ARRIVAL, candidate)
				var hall_path := tiled_loader.get_walk_path(hall_position, candidate)
				if not arrival_path.is_empty() and arrival_path[-1].distance_to(candidate) <= 16.0 and not hall_path.is_empty() and hall_path[-1].distance_to(candidate) <= 16.0:
					return candidate
	push_error("No reachable exterior Brudet team enemy spawn for %s slot %d." % [job_id, index])
	return Vector2(INF, INF)

func capture_player_position() -> void:
	super.capture_player_position()

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_squad_ai.clear()
	for actor in actors_root.get_children():
		if actor is Enemy and (String(actor.persistent_id).begins_with("brudet_team_") or actor.persistent_id == GameState.BRUDET_SOLO_HACKER_ID):
			actor.queue_free()
	for villager_id in GameState.squad_recruits:
		var villager := find_villager(villager_id)
		if villager != null and GameState.squad_members.has(villager_id):
			var member: Dictionary = GameState.squad_members[villager_id]
			var position_data: Array = member["position"]
			villager.global_position = _safe_loaded_position(Vector2(float(position_data[0]), float(position_data[1])))
			member["position"] = [villager.global_position.x, villager.global_position.y]
			GameState.squad_members[villager_id] = member
	_sync_squad()
	_sync_solo_hacker()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if tiled_loader.is_walkable_position(saved):
		return saved
	var saved_in_water := tiled_loader.is_amphibious_walkable_position(saved)
	var tile := Vector2(tiled_loader.tile_size)
	var cell := Vector2(floorf(saved.x / tile.x), floorf(saved.y / tile.y))
	for radius in range(1, 9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := (cell + Vector2(x, y) + Vector2(0.5, 0.5)) * tile
				if not tiled_loader.is_walkable_position(candidate):
					continue
				if not saved_in_water and _crosses_water(saved, candidate):
					continue
				var path := tiled_loader.get_walk_path(GameState.BRUDET_ARRIVAL, candidate)
				if not path.is_empty() and path[-1].distance_to(candidate) <= 16.0:
					return candidate
	push_error("No reachable open position near saved Brudet coordinate %s." % saved)
	return _nearby_open_position(GameState.BRUDET_ARRIVAL)

func _crosses_water(start: Vector2, destination: Vector2) -> bool:
	var steps := ceili(start.distance_to(destination) / 8.0)
	for step in range(1, steps):
		var point := start.lerp(destination, float(step) / steps)
		if tiled_loader.is_amphibious_walkable_position(point) and not tiled_loader.is_walkable_position(point):
			return true
	return false

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
