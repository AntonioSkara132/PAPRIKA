extends Node

## Otpornik: arrival from Iskra, the yard job, buying the Lasta and walking
## its three floors. Set OTPORNIK_SCREENSHOT_DIR to save screenshots when the
## test runs with a window.

var game: Node
var world: OtpornikWorld
var ui: GameUI
var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "Otpornik tests require an isolated save directory")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	GameState.defeated_persistent_enemies.append(GameState.OTPORNIK_UNLOCK_FLAG)
	game._on_story_travel_requested("otpornik")
	await get_tree().process_frame
	world = game.world as OtpornikWorld
	_check(world != null and GameState.current_planet == "otpornik" and world.tiled_loader.map_loaded, "the passenger line loads Otpornik")
	if world == null:
		_finish()
		return
	_check(world.player.global_position == GameState.OTPORNIK_ARRIVAL, "the party arrives at the terminal")
	await get_tree().process_frame
	_check(ui.scene_playing() and world.has_flag("arrival"), "the arrival scene plays once")
	await _capture("arrival")
	ui.cancel_scene()
	_check(world.location_title() == "OTPORNIK — SPACEPORT", "port title")

	# Every port point can be walked to from the terminal.
	for id in ["broker", "foreman", "terminal", "porter", "lasta", "scavenger_0", "scavenger_3"]:
		var path := world.tiled_loader.get_walk_path(world.marker("arrival"), world.marker(id))
		_check(not path.is_empty(), "walk path from the terminal to " + id)
	for id in ["broker", "foreman", "terminal", "porter"]:
		world.player.global_position = world.marker(id) + Vector2(0, 16)
		world.player._update_nearest_interactable()
		_check(world.player._current_interactable == world.people[id], "E selects " + id)
	_check(world.people.size() >= 14, "residents and staff are spawned")

	# Not enough gold: the purchase fails and the yard job pays the difference.
	GameState.gold = 1000
	_check(not world.buy_lasta() and GameState.gold == 1000 and not world.has_flag("lasta_bought"), "the Lasta costs 2000 gold")
	ui.cancel_scene()
	world.player.global_position = world.marker("lasta")
	world.player._update_nearest_interactable()
	world.player._current_interactable.interact(world.player)
	_check(ui.scene_playing() and world.player.global_position == world.marker("lasta"), "the unsold Lasta can only be looked at")
	ui.cancel_scene()
	_check(world.start_yard_job() and world._yard_enemies.size() == 3, "the first yard job brings three scavengers")
	_check(not world.start_yard_job(), "only one yard job at a time")
	world.player.global_position = world.marker("yard_watch")
	await _capture("yard_job")
	for enemy in world._yard_enemies.duplicate():
		enemy.take_damage(1000)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(world._yard_enemies.is_empty(), "defeated scavengers end the fight")
	var before := GameState.gold
	world._foreman()
	_check(GameState.gold == before + OtpornikWorld.YARD_PAY and world.yard_runs_done() == 1 and not world.has_flag("yard_active"), "the foreman pays for a cleared bay")
	ui.cancel_scene()
	_check(world.start_yard_job() and world._yard_enemies.size() == 4, "a later job brings more scavengers")
	world.apply_loaded_state()
	_check(world._yard_enemies.is_empty() and not world.has_flag("yard_active"), "a load drops an unfinished job")

	# Buying the Lasta.
	GameState.gold = 2100
	_check(world.buy_lasta() and GameState.gold == 100 and world.has_flag("lasta_bought"), "the Lasta is bought for 2000 gold")
	ui.cancel_scene()
	_check(not world.buy_lasta() and GameState.gold == 100, "the Lasta is bought only once")
	_check(not world.start_yard_job(), "no yard jobs after buying the ship")

	# The three floors.
	for id in ["ship_upper_airlock", "ship_upper_ladder", "ship_upper_stairs", "ship_upper_helm", "ship_upper_drive", "ship_upper_table", "ship_upper_posters",
			"ship_deck_hatch", "ship_deck_ladder", "ship_deck_mast", "ship_lower_stairs", "ship_lower_bunk", "ship_lower_captain_bed", "ship_lower_store"]:
		_check(world.tiled_loader.is_walkable_position(world.marker(id)), id + " stands on the floor")
	for room_ids in [["ship_upper_airlock", "ship_upper_ladder", "ship_upper_stairs", "ship_upper_helm", "ship_upper_drive", "ship_upper_table", "ship_upper_posters"],
			["ship_deck_hatch", "ship_deck_ladder", "ship_deck_mast"], ["ship_lower_stairs", "ship_lower_bunk", "ship_lower_captain_bed", "ship_lower_store"]]:
		for id: String in room_ids.slice(1):
			_check(not world.tiled_loader.get_walk_path(world.marker(room_ids[0]), world.marker(id)).is_empty(), "walk path to " + id)
	world._on_ship_spot("lasta")
	_check(ui.scene_playing(), "the bought Lasta offers the ramp and the ladder")
	ui.cancel_scene()
	world._on_ship_spot("ship_deck_ladder")
	world.move_party(world.marker("ship_upper_airlock"))
	_check(world.current_room() == "ship_upper" and world.location_title() == "LASTA · CONTROL ROOM", "the ramp leads to the control room")
	_check(world.davor.global_position.distance_to(world.player.global_position) < 64 and world.veki.global_position.distance_to(world.player.global_position) < 64, "Davor and Veki come aboard")
	await _capture("upper_floor")
	var frame := world.drive_sprite.texture
	for i in 12:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_check(world.drive_sprite.texture != frame, "the drive's cylinders move")
	world._on_ship_spot("ship_upper_ladder")
	_check(world.current_room() == "ship_deck", "the ladder leads to the top deck")
	await _capture("top_deck")
	world._on_ship_spot("ship_deck_hatch")
	_check(world.current_room() == "ship_upper", "the hatch leads back down")
	world._on_ship_spot("ship_upper_stairs")
	_check(world.current_room() == "ship_lower" and world.location_title() == "LASTA · BUNKS AND STORE", "the stairs lead to the bunks")
	await _capture("lower_floor")
	GameState.health = 1
	world._on_ship_spot("ship_lower_bunk")
	_check(GameState.health == GameState.max_health, "a bunk restores health")
	ui.cancel_scene()

	# A save inside the ship loads back aboard.
	world.capture_player_position()
	var aboard := world.player.global_position
	_check(GameState.save_game(), "saving aboard the Lasta")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(saved is Dictionary and int(saved["schema"]) == GameState.SAVE_SCHEMA and saved["current_planet"] == "otpornik" and GameState._valid_save(saved), "the save records Otpornik")
	world.move_party(world.marker("arrival"))
	_check(game._load_saved_game() and game.world.player.global_position == aboard, "loading returns aboard the Lasta")
	world = game.world as OtpornikWorld
	var locked: Dictionary = saved.duplicate(true)
	locked["defeated_persistent_enemies"].erase(GameState.OTPORNIK_UNLOCK_FLAG)
	_check(not GameState._valid_save(locked), "an Otpornik save needs the Iskra passes")
	var legacy: Dictionary = saved.duplicate(true)
	legacy["schema"] = GameState.ISKRA_SAVE_SCHEMA
	legacy["current_planet"] = "iskra"
	legacy["planet_positions"].erase("otpornik")
	legacy["planet_positions"].erase("rock")
	_check(GameState._valid_save(legacy), "schema 15 saves stay valid")

	# Back to Iskra on the passenger line.
	ui.cancel_scene()
	world._terminal()
	_check(ui.scene_playing(), "the line clerk offers the return")
	ui.cancel_scene()
	game._on_story_travel_requested("iskra")
	await get_tree().process_frame
	_check(game.world is IskraWorld and GameState.current_planet == "iskra", "the line returns to Iskra")
	_finish()

func _capture(label: String) -> void:
	var directory := OS.get_environment("OTPORNIK_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + message)

func _finish() -> void:
	print("Otpornik smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
