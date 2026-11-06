extends Node

## R-7: the flight from Otpornik, Martin's raid, Davor taken, the Voice and the
## Brine merge, and the flight back. Set ROCK_SCREENSHOT_DIR to save
## screenshots when the test runs with a window.

var game: Node
var world: SpaceRockWorld
var ui: GameUI
var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "R-7 tests require an isolated save directory")
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
	GameState.defeated_persistent_enemies.append(GameState.ROCK_UNLOCK_FLAG)
	GameState.defeated_persistent_enemies.append("otpornik_arrival")
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH
	GameState.restore_health()
	game._on_story_travel_requested("otpornik")
	await get_tree().process_frame
	var port := game.world as OtpornikWorld
	_check(port != null and port.davor != null, "Davor is with the party on Otpornik before R-7")
	port._helm()
	_check(ui.scene_playing() and ui.scene_lines_left() == 4, "Davor asks Veki to fly to R-7")
	ui.cancel_scene()

	game._on_story_travel_requested("rock")
	await get_tree().process_frame
	world = game.world as SpaceRockWorld
	_check(world != null and GameState.current_planet == "rock" and world.tiled_loader.map_loaded, "the Lasta flies to R-7")
	if world == null:
		_finish()
		return
	await get_tree().process_frame
	_check(world.player.global_position == GameState.ROCK_ARRIVAL, "the party lands by the Lasta")
	_check(ui.scene_playing() and world.has_flag("arrival"), "the landing scene plays")
	_check(world.stage() == "landed" and world.davor != null and world.veki != null and world.lasta_sprite.visible and not world.martin_ship_sprite.visible, "Davor follows, Veki waits by the Lasta")
	_check(world.location_title() == "R-7 · SURFACE", "surface title")
	await _capture("landing")
	ui.cancel_scene()

	for id in ["cave_mouth", "martin", "davor_taken", "wake", "raider_0", "raider_3", "raider_5", "raider_7", "veki_post"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("arrival"), world.marker(id)).is_empty(), "walk path from the landing to " + id)
	for id in ["camp", "triangle", "grave"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("cave_entry"), world.marker(id)).is_empty(), "walk path in the cave to " + id)
	_check(not world.tiled_loader.is_walkable_position(world.marker("cave_mouth") + Vector2(0, -64)), "nobody walks onto the ridge over the cave")
	world.player.global_position = world.marker("lasta")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable != null, "the Lasta or Veki can be talked to at the landing")

	# The raid starts by the cave mouth.
	world.player.global_position = world.marker("raid_trigger")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(world.raid_active and ui.scene_playing() and world.martin_ship_sprite.visible, "Martin's ship lands by the cave")
	await get_tree().create_timer(1.7).timeout
	await _capture("raid_start")
	ui.cancel_scene()
	world._veki_flies_off()
	_check(world.veki == null and world._raiders.size() == 4, "Veki flies off and the first wave comes")
	await get_tree().create_timer(2.0).timeout
	_check(not world.lasta_sprite.visible, "the Lasta is gone")
	await _capture("raid")
	for enemy in world._raiders.duplicate():
		enemy.take_damage(1000)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(world.raid_kills == 4 and world.raid_wave == 2 and world._raiders.size() == 5, "a beaten wave brings the next one")

	# A heavy hit does not knock the player out: Martin steps in instead.
	var respawns := [0]
	world.player.respawned.connect(func() -> void: respawns[0] += 1)
	GameState.health = 3
	world.player._invulnerability = 0.0
	world.player.take_damage(30, Vector2.ZERO, true)
	_check(respawns[0] == 0 and GameState.health >= 1 and world.martin_coming, "a knockout hit during the raid brings Martin")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(world._raiders.is_empty() and ui.scene_playing() and world._staged.size() == 5, "Martin and his soldiers face Davor")
	await get_tree().create_timer(2.0).timeout
	await _capture("martin")
	ui.cancel_scene()
	world._davor_taken()
	_check(GameState.davor_taken() and world.davor == null and world.stage() == "alone", "Martin takes Davor")
	_check(not world.lasta_sprite.visible and not world.martin_ship_sprite.visible and world.veki == null, "the player is left alone on the rock")
	_check(world.in_cave() and world.player.global_position == world.marker("cave_wake") and world.sealed_rocks.visible and world.cave_sealed(), "the player wakes shut in the cave")
	_check(GameState.health == int(GameState.max_health * 0.25), "the player wakes hurt")
	_check(ui.scene_playing(), "the waking scene plays")
	ui.cancel_scene()
	await get_tree().create_timer(2.8).timeout
	await _capture("alone")

	# A save after the raid keeps Davor taken.
	world.capture_player_position()
	_check(GameState.save_game(), "saving on R-7")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(saved is Dictionary and int(saved["schema"]) == GameState.SAVE_SCHEMA and saved["current_planet"] == "rock" and GameState._valid_save(saved), "the save records R-7")
	var locked: Dictionary = saved.duplicate(true)
	locked["defeated_persistent_enemies"].erase(GameState.ROCK_UNLOCK_FLAG)
	_check(not GameState._valid_save(locked), "an R-7 save needs the Lasta")
	var legacy: Dictionary = saved.duplicate(true)
	legacy["schema"] = GameState.OTPORNIK_SAVE_SCHEMA
	legacy["current_planet"] = "otpornik"
	legacy["planet_positions"].erase("rock")
	_check(GameState._valid_save(legacy), "schema 16 saves stay valid")
	_check(game._load_saved_game(), "loading the R-7 save")
	world = game.world as SpaceRockWorld
	_check(world != null and world.stage() == "alone" and world.davor == null and not world.raid_active, "the load keeps Davor taken and does not restart the raid")
	_check(world.in_cave() and world.sealed_rocks.visible, "the load keeps the player shut in the cave")

	# The cave and the Voice.
	_check(world.location_title() == "R-7 · THE CAVE", "cave title")
	_check(not world.tiled_loader.get_walk_path(world.marker("cave_wake"), world.marker("grave")).is_empty(), "walk path from where the player wakes to the grave")
	world.player.global_position = world.marker("cave_wake")
	world.player.velocity = Vector2.ZERO
	for i in 40:
		world.player.velocity = (world.marker("cave_entry") - world.player.global_position).normalized() * 120.0
		world.player.move_and_slide()
	_check(world.player.global_position.y < SpaceRockWorld.SEALED_ROCKS_BASE.position.y, "the rocks block the way out")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world._spots["cave_entry"] and world._spots["cave_entry"].get_interaction_text() == "Push the rocks", "the rocks can be pushed at")
	world._on_spot("cave_entry")
	_check(ui.scene_playing() and world.in_cave() and world.cave_sealed(), "the rocks are too heavy before the merge")
	ui.cancel_scene()
	_check(not world.cave_light.visible, "the cave is dark")
	await _capture("cave_dark")
	world._on_spot("camp")
	_check(ui.scene_playing(), "Davor's notes can be read")
	ui.cancel_scene()
	world.player.global_position = world.marker("grave")
	world._on_spot("grave")
	_check(ui.scene_playing() and world.voice_sprite.visible, "the Voice speaks at the grave")
	await get_tree().create_timer(1.6).timeout
	await _capture("voice")
	ui.cancel_scene()
	var health_before := GameState.max_health
	_check(world.merge_with_voice(), "the player merges with the Voice")
	_check(GameState.is_brine() and GameState.max_health == health_before + GameState.BRINE_MAX_HEALTH_BONUS and GameState.health == GameState.max_health, "a Brine has more health, fully restored")
	_check(GameState.brine_damage(10) == 15 and GameState.brine_damage(4) == 6, "a Brine hits harder")
	_check(world.player._brine_eye.visible, "the Brine's eye is white")
	_check(world.cave_light.visible and world.stage() == "rescued", "the Brine sees in the dark")
	_check(not world.merge_with_voice(), "the merge happens once")
	ui.cancel_scene()
	await get_tree().create_timer(2.2).timeout
	await _capture("brine")

	# A Brine pushes the rocks out; Veki is back.
	world._on_spot("cave_entry")
	_check(ui.scene_playing() and world.rocks_pushed() and not world.sealed_rocks.visible and not world.cave_sealed(), "a Brine pushes the rocks out")
	ui.cancel_scene()
	world._on_spot("cave_entry")
	await get_tree().process_frame
	_check(not world.in_cave() and world.hacker_fight_active and world._hackers.size() == 2 and world.veki == null and world.veki_fighter != null, "Veki lands with two hackers after him")
	_check(ui.scene_playing(), "Veki explains the treasure he promised them")
	await get_tree().create_timer(1.6).timeout
	await _capture("hackers")
	ui.cancel_scene()
	_check(GameData.enemy("void_hacker")["max_health"] > GameData.enemy("hacker")["max_health"] and GameData.enemy("hacker_trooper")["damage"] >= GameData.enemy("phase_hacker")["damage"], "these hackers are stronger than the Paprika and Brudet ones")
	world.apply_loaded_state()
	await get_tree().process_frame
	_check(world.hacker_fight_active and world._hackers.size() == 2, "a load outside brings the hackers again")
	ui.cancel_scene()
	for enemy in world._hackers.duplicate():
		enemy.take_damage(10000)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not world.hacker_fight_active and world.has_flag("hackers_beaten") and world.veki != null and world.veki_fighter == null, "beating the hackers ends the fight")
	_check(ui.scene_playing(), "Veki asks about Davor")
	ui.cancel_scene()
	world._on_spot("cave_mouth")
	_check(world.in_cave() and world.player.global_position == world.marker("cave_entry"), "the open cave can be entered again")
	world._on_spot("cave_entry")
	_check(not world.hacker_fight_active, "the hackers do not come back")
	await _capture("rescued")
	world._talk_to_veki()
	_check(ui.scene_playing(), "Veki offers to fly")
	ui.cancel_scene()
	world.leave_rock()
	_check(ui.scene_playing() and ui.scene_lines_left() == 1, "Veki sets course for the Republic")
	for i in 2:
		ui.advance_scene()
	await get_tree().process_frame
	_check(not ui.scene_playing() and GameState.current_planet == "rock" and game.world == world, "the flight to the Republic is not in the game yet, so the player stays on R-7")
	# A save from before the change could still go back to Otpornik.
	game._on_story_travel_requested("otpornik")
	await get_tree().process_frame
	port = game.world as OtpornikWorld
	_check(port != null and port.davor == null and port.veki != null, "Davor is not on Otpornik after R-7")
	port._helm()
	_check(ui.scene_playing() and ui.scene_lines_left() == 2, "the helm points at the search for Davor")
	ui.cancel_scene()
	port._terminal()
	_check(ui.scene_playing(), "Veki will not leave for Iskra without Davor")
	ui.cancel_scene()
	_finish()

func _capture(label: String) -> void:
	var directory := OS.get_environment("ROCK_SCREENSHOT_DIR")
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
	print("R-7 smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
