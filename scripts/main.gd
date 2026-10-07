extends Node2D

const WORLD_SCRIPTS := {
	"paprika": "res://scripts/world/game_world.gd",
	"brudet": "res://scripts/world/brudet_world.gd",
	"station": "res://scripts/world/station_world.gd",
	"station_barracks": "res://scripts/world/station_barracks_world.gd",
	"artichoke": "res://scripts/world/artichoke_world.gd",
	"pomidor": "res://scripts/world/pomidor_world.gd",
	"chvarak": "res://scripts/world/chvarak_world.gd",
	"engineeria": "res://scripts/world/engineeria_world.gd",
}
const DEBUG_GOLD_AMOUNT := 100_000

var world: Node
var game_ui: CanvasLayer
var _world_planet := ""
var _world_area := "exterior"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	GameState.start_new_game()
	if not _switch_world("paprika"):
		return
	var ui_script := load("res://scripts/ui/game_ui.gd")
	if ui_script != null:
		game_ui = ui_script.new()
		game_ui.name = "GameUI"
		add_child(game_ui)
		if game_ui.has_signal("travel_requested"):
			game_ui.connect("travel_requested", _on_travel_requested)
		if game_ui.has_signal("station_area_requested"):
			game_ui.connect("station_area_requested", _on_station_area_requested)
		if game_ui.has_signal("station_action_requested"):
			game_ui.connect("station_action_requested", _on_station_action_requested)
		if game_ui.has_signal("world_action_requested"):
			game_ui.connect("world_action_requested", _on_world_action_requested)
	GameState.notify("Welcome to Paprika. Visit the JOBS center to find work.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		GameState.notify("Paused" if get_tree().paused else "Resumed")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save") and not get_tree().paused:
		if world != null and world.has_method("capture_player_position"):
			world.capture_player_position()
		GameState.remember_player_position(GameState.player_position)
		GameState.save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load") and not get_tree().paused:
		if GameState.load_game():
			_close_ui()
			_cancel_scene()
			if _world_planet != GameState.current_planet or _world_area != GameState.current_area:
				_switch_world(GameState.current_planet, false, Vector2.ZERO, GameState.current_area)
			elif world != null and world.has_method("apply_loaded_state"):
				world.apply_loaded_state()
			if game_ui != null:
				game_ui.refresh_location()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event.is_action_pressed("debug_gold") and not get_tree().paused:
		GameState.add_gold(DEBUG_GOLD_AMOUNT)
		GameState.notify("Added %d gold for testing." % DEBUG_GOLD_AMOUNT)
		get_viewport().set_input_as_handled()

func _on_travel_requested(destination: String) -> void:
	if not GameState.can_travel(destination):
		return
	if world != null and world.has_method("capture_player_position"):
		world.capture_player_position()
	var departure := GameState.player_position
	_close_ui()
	if _switch_world(destination, true, departure):
		if game_ui != null:
			game_ui.refresh_location()
		GameState.notify("Arrived on %s." % destination.capitalize())

## The story moves the player to another planet, such as the diplomatic ship
## going down in Engineeria. No fare and no travel rules apply.
func _on_story_travel_requested(destination: String) -> void:
	if world != null and world.has_method("capture_player_position"):
		world.capture_player_position()
	var departure := GameState.player_position
	_close_ui()
	if _switch_world(destination, false, departure, "exterior", false, true) and game_ui != null:
		game_ui.refresh_location()

func _on_station_area_requested(area: String) -> void:
	if GameState.current_planet != "station" or area == GameState.current_area or area not in ["exterior", "barracks"]:
		return
	if world != null and world.has_method("capture_player_position"):
		world.capture_player_position()
	var departure := GameState.player_position
	_close_ui()
	if _switch_world("station", false, departure, area, true) and game_ui != null:
		game_ui.refresh_location()

func _on_station_action_requested(action: String) -> void:
	_close_ui()
	if GameState.current_planet == "station" and world != null and world.has_method("handle_station_action"):
		world.handle_station_action(action)

func _on_world_action_requested(action: String) -> void:
	_close_ui()
	if world != null and world.has_method("handle_world_action"):
		world.handle_world_action(action)

## A scene's actions belong to the world that started it.
func _cancel_scene() -> void:
	if game_ui != null and game_ui.has_method("cancel_scene"):
		game_ui.call("cancel_scene")

func _close_ui() -> void:
	if game_ui != null and game_ui.has_method("close_modal"):
		game_ui.call("close_modal")

func _switch_world(planet: String, traveling: bool = false, departure: Vector2 = Vector2.ZERO, area: String = "exterior", changing_area: bool = false, story: bool = false) -> bool:
	var location := "station_barracks" if planet == "station" and area == "barracks" else planet
	if not WORLD_SCRIPTS.has(location):
		GameState.notify("That destination is unavailable.")
		return false
	var world_script := load(String(WORLD_SCRIPTS[location]))
	if world_script == null:
		GameState.notify("The %s world is unavailable." % location.replace("_", " ").capitalize())
		return false
	var saved_position := GameState.player_position
	var next_world: Node = world_script.new()
	next_world.name = {
		"paprika": "PaprikaWorld",
		"brudet": "BrudetWorld",
		"station": "StationWorld",
		"station_barracks": "StationBarracksWorld",
		"artichoke": "ArtichokeWorld",
		"pomidor": "PomidorWorld",
		"chvarak": "ChvarakWorld",
		"engineeria": "EngineeriaWorld",
	}[location]
	add_child(next_world)
	var loader := next_world.get("tiled_loader") as TiledLoader
	if loader == null or not loader.map_loaded or not next_world.has_method("apply_loaded_state") or next_world.get("player") == null:
		remove_child(next_world)
		next_world.queue_free()
		GameState.player_position = saved_position
		GameState.notify("The %s world could not be loaded." % location.replace("_", " ").capitalize())
		return false
	GameState.player_position = saved_position
	var transition_ok := true
	if traveling:
		transition_ok = GameState.travel_to(planet, departure)
	elif story:
		transition_ok = GameState.story_travel(planet, departure)
	elif changing_area:
		transition_ok = GameState.enter_military_barracks(departure) if area == "barracks" else GameState.exit_military_barracks(departure)
	if not transition_ok:
		remove_child(next_world)
		next_world.queue_free()
		return false
	if world != null or traveling or changing_area or story:
		next_world.apply_loaded_state()
	if world != null:
		remove_child(world)
		world.queue_free()
		_cancel_scene()
	world = next_world
	if world.has_signal("story_travel_requested"):
		world.connect("story_travel_requested", _on_story_travel_requested)
	# The new player reports its own prompt on its first update; drop the old world's.
	if game_ui != null and game_ui.has_method("set_interaction_prompt"):
		game_ui.set_interaction_prompt("")
	_world_planet = planet
	_world_area = area
	return true

func _ensure_input_actions() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"station_sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"attack": [KEY_SPACE],
		"inventory": [KEY_I],
		"jobs": [KEY_J],
		"use_food": [KEY_H],
		"party_player": [KEY_1],
		"party_first": [KEY_2],
		"party_second": [KEY_3],
		"order_follow": [KEY_Q],
		"order_hold": [KEY_R],
		"order_attack": [KEY_T],
		"order_type": [KEY_ENTER, KEY_KP_ENTER],
		"pause": [KEY_ESCAPE],
		"quick_save": [KEY_F5],
		"quick_load": [KEY_F9],
	}
	if OS.is_debug_build():
		bindings["debug_gold"] = [KEY_F6]
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for keycode: Key in bindings[action]:
				var key_event := InputEventKey.new()
				key_event.physical_keycode = keycode
				InputMap.action_add_event(action, key_event)
