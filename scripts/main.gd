extends Node2D

var world: Node
var game_ui: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	GameState.start_new_game()
	var world_script := load("res://scripts/world/game_world.gd")
	if world_script == null:
		push_error("Paprika world script is missing.")
		return
	world = world_script.new()
	world.name = "PaprikaWorld"
	add_child(world)
	var ui_script := load("res://scripts/ui/game_ui.gd")
	if ui_script != null:
		game_ui = ui_script.new()
		game_ui.name = "GameUI"
		add_child(game_ui)
	GameState.notify("Welcome to Paprika. Visit the JOBS center to find work.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		GameState.notify("Paused" if get_tree().paused else "Resumed")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save") and not get_tree().paused:
		if world != null and world.has_method("capture_player_position"):
			world.capture_player_position()
		GameState.save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load") and not get_tree().paused:
		if GameState.load_game() and world != null and world.has_method("apply_loaded_state"):
			world.apply_loaded_state()
		get_viewport().set_input_as_handled()

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
		"pause": [KEY_ESCAPE],
		"quick_save": [KEY_F5],
		"quick_load": [KEY_F9],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for keycode: Key in bindings[action]:
				var key_event := InputEventKey.new()
				key_event.physical_keycode = keycode
				InputMap.action_add_event(action, key_event)
