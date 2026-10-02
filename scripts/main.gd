extends Node2D

const WORLD_SCRIPTS := {
	"paprika": "res://scripts/world/game_world.gd",
	"brudet": "res://scripts/world/brudet_world.gd",
}
const DEBUG_GOLD_AMOUNT := 100_000

var world: Node
var game_ui: CanvasLayer
var _world_planet := ""

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
			if _world_planet != GameState.current_planet:
				_switch_world(GameState.current_planet)
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

func _close_ui() -> void:
	if game_ui != null and game_ui.has_method("close_modal"):
		game_ui.call("close_modal")

func _switch_world(planet: String, traveling: bool = false, departure: Vector2 = Vector2.ZERO) -> bool:
	if not WORLD_SCRIPTS.has(planet):
		GameState.notify("That destination is unavailable.")
		return false
	var world_script := load(String(WORLD_SCRIPTS[planet]))
	if world_script == null:
		GameState.notify("The %s world is unavailable." % planet.capitalize())
		return false
	var saved_position := GameState.player_position
	var next_world: Node = world_script.new()
	next_world.name = "PaprikaWorld" if planet == "paprika" else "BrudetWorld"
	add_child(next_world)
	var loader := next_world.get("tiled_loader") as TiledLoader
	if loader == null or not loader.map_loaded or not next_world.has_method("apply_loaded_state") or next_world.get("player") == null:
		remove_child(next_world)
		next_world.queue_free()
		GameState.player_position = saved_position
		GameState.notify("The %s world could not be loaded." % planet.capitalize())
		return false
	GameState.player_position = saved_position
	if traveling and not GameState.travel_to(planet, departure):
		remove_child(next_world)
		next_world.queue_free()
		return false
	if world != null or traveling:
		next_world.apply_loaded_state()
	if world != null:
		remove_child(world)
		world.queue_free()
	world = next_world
	_world_planet = planet
	return true

func _ensure_input_actions() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
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
