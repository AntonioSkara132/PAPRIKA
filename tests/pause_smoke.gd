extends Node

var game: Node
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "pause tests require an isolated save directory")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	var player: Player = game.world.player
	var start := player.global_position
	Input.action_press("move_right")
	for frame in 5:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > start.x, "player can move before pausing")
	await _press_escape()
	_check(get_tree().paused and not game.world.can_process() and not player.can_process(), "Escape pauses the whole world")
	var paused_position := player.global_position
	Input.action_press("move_right")
	for frame in 5:
		await get_tree().process_frame
	Input.action_release("move_right")
	_check(player.global_position == paused_position, "player does not move while paused")
	await _press_escape()
	_check(not get_tree().paused and game.world.can_process() and player.can_process(), "Escape resumes world and player")
	Input.action_press("move_right")
	for frame in 5:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > paused_position.x, "player moves after resuming")
	game.game_ui.open_inventory()
	await _press_escape()
	_check(not get_tree().paused and not game.game_ui.modal_overlay.visible, "Escape closes inventory without pausing")
	await _press_escape()
	game.game_ui.open_inventory()
	await _press_escape()
	_check(get_tree().paused and not game.game_ui.modal_overlay.visible, "closing inventory preserves an existing pause")
	await _press_escape()
	_check(not get_tree().paused, "Escape still resumes after closing a paused inventory")
	_finish()

func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL " + description)

func _finish() -> void:
	get_tree().paused = false
	print("Pause smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
