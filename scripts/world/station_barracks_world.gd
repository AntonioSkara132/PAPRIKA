class_name StationBarracksWorld
extends GameWorld

const MAP_PATH_BARRACKS := "res://maps/station_barracks.tmj"
const ARRIVAL := Vector2(256, 340)

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
	if not tiled_loader.load_map(MAP_PATH_BARRACKS):
		push_error("Station barracks map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	if player == null:
		_spawn_player(ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	_spawn_recruits()

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, _stable_id: String) -> void:
	if kind == "player" and player == null:
		_spawn_player(position, variant)

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = ARRIVAL
	player.respawn_location_name = "the station barracks"

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if tiled_loader.is_walkable_position(saved):
		return saved
	return _nearby_open_position(ARRIVAL)

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position

func _spawn_recruits() -> void:
	var bed_positions: Array[Vector2] = []
	var raw = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH_BARRACKS))
	if raw is Dictionary:
		for layer_value in raw.get("layers", []):
			if not layer_value is Dictionary or String(layer_value.get("type", "")) != "objectgroup":
				continue
			for object_value in layer_value.get("objects", []):
				if not object_value is Dictionary or not String(object_value.get("name", "")).begins_with("recruit_bed"):
					continue
				bed_positions.append(Vector2(float(object_value.get("x", 0)) + float(object_value.get("width", 16)) * 0.5, float(object_value.get("y", 0)) + 14.0))
	bed_positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y or (is_equal_approx(a.y, b.y) and a.x < b.x))
	for index in StationRoster.RECRUITS.size():
		var data: Dictionary = StationRoster.RECRUITS[index]
		var preferred := bed_positions[index] if index < bed_positions.size() else Vector2(72 + (index % 5) * 64, 118 + (index / 5) * 88)
		var spawn := _nearby_open_position(preferred)
		var other_stop := _nearby_open_position(spawn + Vector2(20 if index % 2 == 0 else -20, 18))
		var recruit := StationRecruit.new()
		recruit.name = String(data["id"])
		recruit.configure(data, spawn, tiled_loader, [spawn, other_stop])
		actors_root.add_child(recruit)

func _on_service_requested(service_id: String, display_name: String) -> void:
	super._on_service_requested(service_id, display_name)

# Main forwards actions chosen in the barracks service dialog.
func handle_station_action(action: String) -> void:
	match action:
		"player_chest":
			if GameState.military_stage == "barracks":
				if GameState.military_store_gear():
					GameState.notify("Your belongings are in your footlocker. The timed run is next.")
				else:
					GameState.notify("Your belongings could not be stored yet.")
			elif GameState.military_withdraw_gear():
				GameState.notify("You retrieved your personal belongings.")
			else:
				GameState.notify("Finish training before collecting your belongings.")
		"player_bed":
			if GameState.military_sleep():
				GameState.notify("You rested in your bunk and graduated from basic training.")
			else:
				GameState.notify("Finish all six drills before resting in your bunk.")
