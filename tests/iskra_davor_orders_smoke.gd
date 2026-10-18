extends Node

var game: Node
var world: IskraWorld
var ui: GameUI
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		_check(false, "isolated saves required")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	ui.cancel_scene()
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	game._on_story_travel_requested("iskra")
	await get_tree().process_frame
	world = game.world as IskraWorld
	if world == null:
		_check(false, "Iskra loads for Davor orders")
		_finish()
		return
	for flag in ["arrival", "registered", "tower_closed_seen", "morning", "room_rented", "audience_complete", "hotel_cover_confirmed"]:
		world.chapter.set_flag(flag)
	world.player.global_position = world.marker("taxi_dock")
	world._move_davor()
	world.player.set_physics_process(false)

	_press("order_attack")
	_check(world.davor.order == "attack", "T sends Davor to attack nearby enemies")
	_press("order_follow")
	_check(world.davor.order == "follow", "Q sends Davor back to following")
	_press("order_hold")
	_check(world.davor.order == "hold" and world.davor.hold_point.distance_to(world.davor.global_position) < 1.0, "R holds Davor at his current spot")

	# A held Davor stays put while the player walks away.
	var held := world.davor.global_position
	world.player.global_position = world.marker("taxi_park")
	world.davor.set_physics_process(true)
	for frame in range(60):
		await get_tree().physics_frame
	_check(world.davor.global_position.distance_to(held) < 4.0, "held Davor does not follow the player")
	world.davor.set_physics_process(false)

	_press("order_follow")
	world.davor.set_physics_process(true)
	var before := world.davor.global_position.distance_to(world.player.global_position)
	for frame in range(120):
		await get_tree().physics_frame
	_check(world.davor.global_position.distance_to(world.player.global_position) < before, "Q brings held Davor back toward the player")
	world.davor.set_physics_process(false)

	ui.open_inventory()
	_press("order_attack")
	_check(world.davor.order == "follow", "order keys do nothing while a menu is open")
	ui.close_modal()

	world.davor.down = true
	_press("order_hold")
	_check(world.davor.order == "follow", "a downed Davor refuses new orders")
	world.davor.down = false

	_finish()

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	world._unhandled_input(event)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])

func _finish() -> void:
	print("Iskra Davor orders: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
