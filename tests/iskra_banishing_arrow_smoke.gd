extends Node

const Data = preload("res://scripts/world/iskra_investigation_data.gd")
const Arrow = preload("res://scripts/actors/iskra_banishing_arrow.gd")

var game: Node
var world: IskraWorld
var story: RefCounted
var encounters: RefCounted
var ui: GameUI
var checks := 0
var failures := 0
var respawns := 0
var warnings := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		_check(false, "isolated save directory required")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	game._on_story_travel_requested("iskra")
	await get_tree().process_frame
	world = game.world
	story = world.investigation
	encounters = story.encounters
	world.player.respawned.connect(func() -> void: respawns += 1)
	GameState.notification_requested.connect(func(message: String) -> void:
		if message == "Davor: Don’t let that arrow hit you!!!":
			warnings += 1)
	_validate()
	await _paused_release()
	await _live_dodge()
	await _lethal_hit()
	await _wall_collision()
	await _companion_hit()
	await _flight_reload()
	await _resolved_attacker_reload()
	await _old_save()
	_finish()

func _reset() -> void:
	_release()
	ui.cancel_scene()
	ui.close_modal()
	encounters.clear_runtime()
	for flag: String in GameState.defeated_persistent_enemies.duplicate():
		if flag.begins_with(Data.FLAG_PREFIX) or flag.begins_with("story_iskra_inv_"):
			GameState.defeated_persistent_enemies.erase(flag)
	GameState.iskra_investigation_state.clear()
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH
	GameState.restore_health()
	GameState.add_item("iron_armor")
	GameState.equip_item("iron_armor")
	world.player._invulnerability = 0.0
	world.player.damage_scale = 1.0
	world.player.global_position = world.marker("inv_hall_arrival")
	world.player.velocity = Vector2.ZERO
	story.set_value("site", "hall")
	story.set_flag("attack_started")
	for flag in ["arrival", "registered", "morning", "room_rented", "audience_complete", "hotel_cover_confirmed"]:
		world.chapter.set_flag(flag)
	world._move_davor()
	world.davor.get_up()
	world.davor.health = world.davor.max_health
	world.davor.set_physics_process(false)
	encounters.apply_loaded_state()
	story.refresh_location()
	respawns = 0
	warnings = 0

func _validate() -> void:
	var flight := {"x": 2264.0, "y": 2981.0, "dx": 0.0, "dy": 1.0, "remaining": 500.0}
	_check(Data.valid_state({"version": 1, "assassin_phase": "shoot", "banishing_arrow": flight}), "pending shot and complete flight validate")
	_check(Data.valid_state({"version": 1, "banishing_arrow": {}}), "completed flight validates")
	for replacement in [null, [], {"x": 1}, {"x": 2264, "y": 2981, "dx": 0, "dy": 0, "remaining": 10}, {"x": 0, "y": 0, "dx": 0, "dy": 1, "remaining": 10}, {"x": 2264, "y": 2981, "dx": INF, "dy": 1, "remaining": 10}, {"x": 2264, "y": 2981, "dx": 0, "dy": 1, "remaining": 721}, {"x": 2264, "y": 2981, "dx": 0, "dy": 1, "remaining": -1}]:
		_check(not Data.valid_state({"version": 1, "banishing_arrow": replacement}), "malformed flight rejected: " + str(replacement))

func _paused_release() -> void:
	_reset()
	ui.play_scene([{"speaker": "Officer", "text": "The officer raises a bow."}])
	_check(encounters.begin_assassin("davor"), "Davor choice prepares the same single arrow")
	await get_tree().create_timer(0.2).timeout
	_check(not encounters.arrow_in_flight() and warnings == 0, "no shot or warning while dialogue blocks movement")
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "pending shot saves and loads")
	world.apply_loaded_state()
	_check(encounters.enemies.assassin.mode == "shoot", "pending shot survives reload")
	ui.cancel_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(encounters.arrow_in_flight() and warnings == 1, "first active gameplay frame fires and warns once")
	_check(not ui.scene_playing() and not get_tree().paused, "warning does not pause gameplay")
	_check(encounters.enemies.assassin.mode == "flee", "assassin runs immediately after shooting")
	var arrow: Node2D = encounters.arrow
	var before := arrow.global_position
	ui.open_inventory()
	await get_tree().create_timer(0.2).timeout
	_check(arrow.global_position == before, "inventory pauses the moving arrow")
	ui.close_modal()
	ui.play_scene([{"speaker": "Test", "text": "Pause the flight."}])
	await get_tree().create_timer(0.2).timeout
	_check(arrow.global_position == before, "dialogue pauses the moving arrow")
	ui.cancel_scene()
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	_check(arrow.global_position == before, "game pause stops the moving arrow")
	get_tree().paused = false

func _live_dodge() -> void:
	_reset()
	world.davor.set_physics_process(true)
	_check(world.davor.max_health == 260 and world.davor.strike_damage == 30 and world.davor.speed == 100.0, "live dodge keeps Davor's normal stats")
	_check(encounters.begin_assassin("order"), "start actual hotel shot with Davor active")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(encounters.arrow), "physical arrow exists in the hotel corridor")
	if not is_instance_valid(encounters.arrow):
		return
	var arrow: Node2D = encounters.arrow
	var heading: Vector2 = arrow.direction
	var origin := world.player.global_position
	await get_tree().create_timer(0.18).timeout
	Input.action_press("move_right")
	await get_tree().create_timer(0.25).timeout
	_check(world.player.global_position.distance_to(origin) >= 15.0, "normal movement input moves MC out of the shot path")
	if is_instance_valid(arrow):
		_check(arrow.direction == heading, "arrow does not home after MC moves")
	await _capture("banishing_dodge")
	await get_tree().create_timer(0.6).timeout
	_release()
	_check(respawns == 0 and GameState.health == GameState.max_health, "moving after release dodges lethal shot at full health")
	_check(warnings == 1 and story.has("banishing_arrow_fired"), "assassin spends exactly one arrow")
	var flight_wait := 0.0
	while encounters.arrow_in_flight() and flight_wait < 3.0:
		await get_tree().create_timer(0.05).timeout
		flight_wait += 0.05
	_check(not encounters.arrow_in_flight(), "missed arrow stops at the corridor wall")
	if not story.attack_resolved() and encounters.enemies.has("assassin"):
		encounters.enemies.assassin.take_damage(999, world.player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(story.has("banishing_arrow_explained") and ui.scene_text_label.text.contains("The Admins used them just like Banishing Swords"), "Davor explains Admin weapons after projectile and chase end")
	await _capture("banishing_explanation")
	ui.cancel_scene()
	await get_tree().create_timer(0.2).timeout
	_check(not ui.scene_playing(), "automatic explanation is not repeated after dismissal")
	print("LIVE_DODGE moved=", world.player.global_position.distance_to(origin), " respawns=", respawns, " health=", GameState.health, "/", GameState.max_health, " warnings=", warnings)

func _lethal_hit() -> void:
	_reset()
	_check(encounters.begin_assassin("refuse"), "start full-health armored hit case")
	await get_tree().create_timer(1.1).timeout
	_check(respawns == 1, "standing still lets arrow knock out full-health armored MC")
	_check(world.player.global_position.distance_to(world.marker("inv_hall_arrival")) < 1.0 and GameState.health == GameState.max_health, "arrow uses normal full-health respawn at hotel entrance")
	_check(not encounters.arrow_in_flight() and story.has("banishing_arrow_fired"), "knockout consumes flight without replenishing arrow")
	await get_tree().create_timer(0.5).timeout
	_check(respawns == 1 and warnings == 1, "attacker cannot fire a second lethal arrow after knockout")
	await _capture("banishing_knockout")
	print("LIVE_HIT respawns=", respawns, " armor=", GameState.equipment.armor, " health=", GameState.health, "/", GameState.max_health)
	_reset()
	world.player._invulnerability = 5.0
	world.player.damage_scale = 0.1
	encounters.begin_assassin("corridor")
	await get_tree().create_timer(1.1).timeout
	_check(respawns == 1, "banishing hit ignores ordinary armor damage scaling and post-hit protection")

func _wall_collision() -> void:
	_reset()
	var start := world.marker("inv_hall_attacker") + Vector2(0, -3)
	encounters._spawn_arrow(start, Vector2.UP)
	var arrow: Node2D = encounters.arrow
	var stopped := {"wall": false}
	arrow.finished.connect(func(body: Node) -> void: stopped.wall = body is StaticBody2D)
	await get_tree().create_timer(2.0).timeout
	_check(stopped.wall and not encounters.arrow_in_flight(), "swept collision stops arrow at a physical hotel wall")
	_check(respawns == 0, "wall collision does not hurt MC")

func _companion_hit() -> void:
	_reset()
	var origin := world.marker("inv_hall_attacker") + Vector2(0, -3)
	var target := world.player.global_position + Vector2(0, -3)
	world.davor.global_position = origin.lerp(target, 0.5) + Vector2(0, 3)
	encounters._spawn_arrow(origin, target - origin)
	await get_tree().create_timer(0.8).timeout
	_check(not world.davor.down and world.davor.health == world.davor.max_health, "the Banishing Arrow flies past Davor without downing him")
	_check(respawns == 1 and not encounters.arrow_in_flight(), "an arrow that passes Davor still reaches the MC")
	_check(world.davor.max_health == 260 and world.davor.strike_damage == 30 and world.davor.get_up_seconds == 10.0, "Davor keeps his normal stats and recovery time")

func _flight_reload() -> void:
	_reset()
	encounters.begin_assassin("order")
	await get_tree().create_timer(0.15).timeout
	ui.open_inventory()
	world.capture_player_position()
	var saved: Dictionary = GameState.iskra_investigation_state.banishing_arrow.duplicate()
	_check(not saved.is_empty() and Data.valid_state(GameState.iskra_investigation_state), "in-flight position direction and distance pass save validation")
	_check(GameState.save_game() and GameState.load_game(), "save and load a live arrow")
	world.apply_loaded_state()
	_check(encounters.arrow.snapshot() == saved, "reload restores exact projectile position direction and remaining distance")
	_check(warnings == 1, "reload does not announce or issue another shot")
	ui.close_modal()
	await get_tree().create_timer(1.0).timeout
	_check(respawns == 1, "restored arrow still hits rather than disappearing on load")
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "spent-arrow state saves and loads")
	world.apply_loaded_state()
	await get_tree().create_timer(0.2).timeout
	_check(not encounters.arrow_in_flight() and warnings == 1 and respawns == 1, "loading spent arrow does not recreate it")

func _resolved_attacker_reload() -> void:
	_reset()
	encounters.begin_assassin("order")
	await get_tree().create_timer(0.1).timeout
	encounters.enemies.assassin.take_damage(999, world.player.global_position)
	_check(story.has("assassin_killed") and encounters.arrow_in_flight(), "killing shooter does not delete an arrow already in flight")
	await get_tree().process_frame
	_check(not ui.scene_playing() and not story.has("banishing_arrow_explained"), "explanation waits for arrow despite attacker death")
	ui.open_inventory()
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "dead shooter with live arrow saves and loads")
	world.apply_loaded_state()
	_check(not encounters.enemies.has("assassin") and encounters.arrow_in_flight(), "reload preserves death and remaining projectile threat")
	ui.close_modal()
	await get_tree().create_timer(1.0).timeout
	_check(respawns == 1 and story.has("assassin_killed"), "arrow can hit after shooter death without losing outcome")
	_check(world.player.global_position.distance_to(world.marker("inv_hall_arrival")) < 1.0, "posthumous shot still respawns MC in the hotel")
	_check(story.people.inv_hall_evidence.visible, "coat evidence remains accessible after lethal arrow")
	ui.cancel_scene()
	_reset()
	encounters.begin_assassin("order")
	await get_tree().create_timer(0.1).timeout
	ui.open_inventory()
	world.capture_player_position()
	var flight: Dictionary = GameState.iskra_investigation_state.banishing_arrow.duplicate()
	world.player.global_position = world.marker("inv_owner_arrival")
	encounters.refresh_room()
	_check(not is_instance_valid(encounters.arrow) and GameState.iskra_investigation_state.banishing_arrow == flight, "leaving room preserves rather than erases flight state")
	world.player.global_position = world.marker("inv_hall_arrival")
	encounters.refresh_room()
	_check(encounters.arrow.snapshot() == flight and warnings == 1, "returning resumes existing flight without another shot")
	ui.close_modal()

func _old_save() -> void:
	_reset()
	story.set_value("assassin_phase", "attack")
	story.set_value("assassin_seconds", 0.9)
	story.set_value("encounter", "assassin")
	encounters.apply_loaded_state()
	_check(encounters.enemies.assassin.mode == "shoot", "older active melee save receives one pending arrow")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(warnings == 1 and encounters.arrow_in_flight(), "migrated active encounter fires once")
	_reset()
	story.set_value("assassin_phase", "escaped")
	story.set_flag("assassin_escaped")
	encounters.apply_loaded_state()
	await get_tree().process_frame
	_check(not encounters.arrow_in_flight() and warnings == 0 and not encounters.enemies.has("assassin"), "older resolved encounter does not replay assassination")

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])

func _finish() -> void:
	_release()
	print("Iskra Banishing Arrow: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
