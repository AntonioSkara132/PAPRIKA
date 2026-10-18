extends Node

var game: Node
var world: IskraWorld
var jobs: RefCounted
var ui: GameUI
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		get_tree().quit(2)
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
	world = game.world as IskraWorld
	jobs = world.gang_jobs
	Engine.time_scale = 4.0
	await _dialogues()
	await _shipment()
	await _rescue()
	if OS.get_environment("ISKRA_TIMING_ONLY") != "1":
		_migration()
		await _search()
	Engine.time_scale = 1.0
	print("Iskra pressure/search: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _dialogues() -> void:
	for faction in ["pelican", "squirrel"]:
		_reset()
		jobs.set_flag("shipment_" + faction)
		jobs.set_flag("shipment_delivered")
		for paid in [false, true]:
			if paid:
				jobs.set_flag("shipment_paid")
			for id in ["red_pelican", "green_squirrel"]:
				_at(id)
				world.story_people[id].interact(world.player)
				var text := ui.scene_text_label.text
				_check(not text.contains("We need two crates") and not text.contains("We want their two crates") and not text.contains("Meet Veki"), "completed recruiter has no initial offer or stale instructions")
				var accepts := false
				var payment := false
				for button in ui.scene_buttons.get_children():
					accepts = accepts or button.text.begins_with("Accept shipment")
					payment = payment or button.text.begins_with("Collect shipment")
				var own: bool = (id == "red_pelican") == (faction == "pelican")
				_check(not accepts and payment == (own and not paid), "only unpaid contractor offers payment")
				_check(text.contains("shipment is finished") if own else text.contains("You delivered K-17"), "recruiter acknowledges actual faction outcome")
				await _capture("finished_" + faction + "_" + id + str(paid))
		world.chapter.set_flag("audience_complete")
		for id in ["red_pelican", "green_squirrel"]:
			_at(id)
			world.story_people[id].interact(world.player)
			var offered := false
			for button in ui.scene_buttons.get_children():
				offered = offered or button.text.begins_with("Ask about")
			_check(offered, "post-audience contract offered after completed shipment")

func _shipment() -> void:
	_reset()
	_at("red_pelican")
	jobs.accept_shipment("pelican")
	_end()
	jobs.set_flag("inspection_seen")
	jobs.set_flag("manifest_read")
	_at("freight_office")
	_check(jobs.enter_freight(false), "enter freight for timed job")
	_check(world.davor.order == "hold" and not jobs.ROOMS.freight.has_point(world.davor.global_position), "Davor remains outside freight")
	jobs.pressure.step(100)
	_check(not jobs.pressure.started("shipment"), "acceptance and investigation have no shipment clock")
	_at("gang_freight_crate_a")
	_check(not jobs.take_crate(0) and not jobs.pressure.started("shipment"), "cargo waits for pilot rather than leaving player unable to load")
	_pilot("freight")
	_check(jobs.take_crate(0) and jobs.pressure.remaining("shipment") == 18.75, "first crate starts warned18.75-second loading window")
	_check(ui.scene_text_label.text.contains("18.75 seconds") and ui.scene_text_label.text.contains("inspection crew"), "Pelican warning names inspection crew and duration")
	await _capture("shipment_timer")
	jobs.pressure.step(100)
	_check(jobs.pressure.remaining("shipment") == 18.75, "dialogue pauses countdown")
	_end()
	ui.open_inventory()
	jobs.pressure.step(100)
	_check(jobs.pressure.remaining("shipment") == 18.75, "inventory pauses countdown")
	ui.close_modal()
	get_tree().paused = true
	jobs.pressure.step(100)
	_check(jobs.pressure.remaining("shipment") == 18.75, "game pause pauses countdown")
	get_tree().paused = false
	jobs.pressure.step(10)
	_check(jobs.has("pressure_shipment_half") and jobs.pressure.enemies.size() == 2, "graduated warning and outside crew arrive")
	_check(world.davor.max_health == 260 and world.davor.strike_damage == 30, "Davor keeps normal strength")
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "save active cargo countdown")
	world.apply_loaded_state()
	_check(jobs.pressure.remaining("shipment") == 8.75 and jobs.carrying.visible, "load preserves exact time and cargo")
	jobs.pressure.step(100)
	_check(jobs.pressure.remaining("shipment") == 8.75 and ui.scene_playing(), "load shows paused warning instead of unwarned expiry")
	_end()
	jobs.pressure.step(9)
	_check(jobs.has("pressure_shipment_expired") and jobs.pressure.remaining("shipment") == 0 and jobs.pressure.enemies.size() == 4, "expiry adds two ordinary interior guards without failing job")
	await _capture("shipment_guards")
	_at("gang_freight_exit")
	_check(not jobs.leave_site("freight", false), "guarded front exit requires combat")
	_at("gang_freight_side")
	_check(jobs.leave_site("freight", true) and jobs.carrying.visible, "service door permits cargo escape after expiry")
	_check(world.davor.order == "follow" and world.davor.global_position.distance_to(world.player.global_position) < 64, "Davor rejoins after leaving freight")
	world.player.global_position = world.marker("arrival")
	jobs.on_respawn()
	_check(jobs.pressure.remaining("shipment") == 0, "knockout does not refill loading window")
	ui.cancel_scene()
	_reset()
	jobs.set_flag("shipment_squirrel")
	jobs.set_flag("manifest_read")
	_pilot("freight")
	_at("gang_freight_crate_a")
	jobs.take_crate(0)
	_check(ui.scene_text_label.text.contains("returning warehouse crew"), "Squirrel warning names returning crew")
	_end()
	jobs.pressure.step(10)
	world.davor.set_physics_process(true)
	await get_tree().create_timer(4).timeout
	_check(jobs.has("pressure_down_shipment_outside_a") and jobs.has("pressure_down_shipment_outside_b") and world.davor.health > 0, "Davor defeats ordinary outside pair without being weakened")
	world.davor.set_physics_process(false)
	world.capture_player_position()
	var saved_time: float = jobs.pressure.remaining("shipment")
	_check(GameState.save_game(), "save timed job before switching worlds")
	GameState.start_new_game()
	game._switch_world("paprika")
	var event := InputEventAction.new()
	event.action = "quick_load"
	event.pressed = true
	game._unhandled_input(event)
	await get_tree().process_frame
	world = game.world as IskraWorld
	jobs = world.gang_jobs
	_check(world != null and ui.scene_playing() and is_equal_approx(jobs.pressure.remaining("shipment"), saved_time), "actual F9 from another world retains time and resume warning")

func _rescue() -> void:
	_reset()
	jobs.set_flag("rescue_job")
	_at("holding_side")
	jobs.enter_holding("sneak")
	_check(world.davor.order == "hold" and not jobs.ROOMS.holding.has_point(world.davor.global_position), "Davor covers outside holding entrance")
	jobs.pressure.step(100)
	_check(not jobs.pressure.started("rescue"), "searching prison has no escape clock")
	_at("gang_holding_lock")
	_check(not jobs.release_prisoners() and not jobs.pressure.started("rescue"), "escape waits for pilot before starting alarm")
	_pilot("holding")
	jobs.release_prisoners()
	_check(jobs.pressure.remaining("rescue") == 11.25 and ui.scene_text_label.text.contains("11.25 seconds"), "release starts clearly warned escape phase")
	await _capture("rescue_timer")
	_end()
	jobs.pressure.step(2.5)
	world.capture_player_position()
	var first: Vector2 = jobs.prisoners[0].global_position
	_check(GameState.save_game() and GameState.load_game(), "save timed prisoner escape")
	world.apply_loaded_state()
	_check(jobs.room() == "holding" and jobs.has("rescue_freed") and jobs.prisoners[0].global_position == first and jobs.pressure.remaining("rescue") == 8.75, "timed escape resumes inside with exact prisoners and time")
	_end()
	_at("gang_holding_stash")
	_check(jobs.start_stash_alarm(), "optional money brings another ordinary guard")
	jobs.pressure.step(9)
	_check(jobs.has("pressure_rescue_expired") and jobs.pressure.enemies.size() == 4, "lingering for money permits reinforcements")
	await _capture("rescue_reinforcements")
	world.player.global_position = world.marker("arrival")
	jobs.on_respawn()
	_check(not jobs.has("rescue_freed") and jobs.pressure.remaining("rescue") == 0, "retry resets prisoners without refilling escape time")
	ui.cancel_scene()
	_at("holding_side")
	jobs.enter_holding("sneak")
	_at("gang_holding_lock")
	jobs.release_prisoners()
	_check(jobs.pressure.remaining("rescue") == 0 and ui.scene_text_label.text.contains("already here"), "retry warns about existing pressure")
	_reset()
	jobs.set_flag("rescue_job")
	GameState.gold = 50
	_pilot("holding")
	_at("holding_office")
	jobs.pay_ransom()
	_at("gang_holding_lock")
	jobs.release_prisoners()
	jobs.pressure.step(1000)
	_check(not jobs.pressure.started("rescue") and jobs.pressure.enemies.is_empty(), "negotiated ransom creates no escape alarm")
	world.capture_player_position()
	_check(GameState.save_game(), "new pressure state saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	saved.erase("iskra_gang_state")
	_check(GameState._valid_save(saved), "old quest saves without timing fields remain valid")
	saved["iskra_gang_state"] = {"shipment_seconds": -1}
	_check(not GameState._valid_save(saved), "negative countdown rejected")
	saved["iskra_gang_state"] = {"shipment_seconds": "bad"}
	_check(not GameState._valid_save(saved), "nonnumeric countdown rejected")
	GameState.iskra_gang_state = {"shipment_seconds": 40.0, "rescue_seconds": 20.0}
	jobs.pressure.migrate_timing()
	_check(jobs.pressure.remaining("shipment") == 10 and jobs.pressure.remaining("rescue") == 5, "older remaining times are divided by four")
	jobs.pressure.migrate_timing()
	_check(jobs.pressure.remaining("shipment") == 10 and jobs.pressure.remaining("rescue") == 5, "timing migration applies exactly once")
	GameState.iskra_gang_state = {"shipment_seconds": 75.0, "rescue_seconds": 45.0}
	jobs.pressure.migrate_timing()
	_check(jobs.pressure.remaining("shipment") == 18.75 and jobs.pressure.remaining("rescue") == 11.25, "old full windows migrate to exact quarter durations")
	GameState.iskra_gang_state = {"shipment_seconds": 0.0, "rescue_seconds": 0.0}
	jobs.pressure.migrate_timing()
	_check(jobs.pressure.remaining("shipment") == 0 and jobs.pressure.remaining("rescue") == 0, "expired old windows stay expired")

func _migration() -> void:
	for state in ["searching", "rival_custody", "rival_delivered", "intercept_fight", "escort", "escape_pending", "escape_safe"]:
		_reset()
		jobs.set_flag("hunt_job")
		if state != "searching":
			jobs.set_flag("hunt_" + state)
		if state in ["escape_pending", "escape_safe"]:
			jobs.set_flag("hunt_money")
		if state == "intercept_fight":
			jobs.set_flag("hunt_rival_custody")
		GameState.iskra_gang_state = {"search_stage": 4.0, "search_wait": 7.0, "search_miro_stop": 1.0, "search_miro_wait": 5.0, "search_rival_x": 3384.0, "search_rival_y": 1464.0, "search_miro_x": 3384.0, "search_miro_y": 1464.0, "search_fighter_health": 23.0}
		jobs.apply_loaded_state()
		_check(jobs.search.get_value("version") == 1 and jobs.search.get_value("stage") == 4 and jobs.search.get_value("wait") == 7, "old search migrates once without resetting stage/wait: " + state)
		_check(jobs.search.rival.global_position.x < 1600, "old rival moves to western streets: " + state)
		if state == "escort":
			_check(jobs.collector.global_position == Vector2(3384, 1464) and jobs.collector._target == world.player, "existing player escort keeps its saved position")
		else:
			_check(jobs.collector.global_position.x < 1600, "old Miro moves to western streets: " + state)
		if state == "rival_custody":
			_check(jobs.collector._target == jobs.search.rival and jobs.collector.global_position.distance_to(jobs.search.rival.global_position) < 64, "migrated custody keeps collector beside rival")
		elif state == "rival_delivered":
			_check(jobs.search.rival.global_position == world.marker("collector_holding") and jobs.has("hunt_rival_delivered"), "recorded delivery remains at western collection point")
		elif state == "intercept_fight":
			_check(jobs.search.fighter.health == 23 and jobs.has("hunt_intercept_fight"), "migration keeps interception damage and encounter")
		elif state == "searching":
			_check(jobs.collector._stop_index == 1 and jobs.collector._wait == 5, "migration preserves Miro stop and pause")
		elif state == "escape_pending":
			_check(jobs.collector._target == jobs.search.escape_target and jobs.has("hunt_money"), "migrated escape heads toward western crew with outcome unchanged")
		var before: Dictionary = GameState.iskra_gang_state.duplicate()
		jobs.search.migrate_location()
		_check(GameState.iskra_gang_state == before, "repeated migration leaves coordinates unchanged: " + state)
		world.capture_player_position()
		_check(GameState.save_game() and GameState.load_game(), "migrated search saves and loads: " + state)
		var position: Vector2 = jobs.collector.global_position
		jobs.apply_loaded_state()
		_check(jobs.collector.global_position == position and GameState.gold == 0 and not jobs.has("hunt_paid"), "reload preserves migrated location without paying reward: " + state)

func _search() -> void:
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("red_pelican")
	jobs.accept_hunt()
	_check(ui.scene_text_label.text.contains("Radan") and ui.scene_text_label.text.contains("west-side"), "Ves warns of real rival search at acceptance")
	_end()
	for marker in ["collector_neighbor", "collector_hideout", "collector_route_north", "collector_route_south", "collector_market", "collector_holding", "collector_dispatch", "collector_rival_start", "collector_escape"]:
		_check(world.marker(marker).x < 1600 and world.tiled_loader.is_walkable_position(world.marker(marker)), "western city marker walkable: " + marker)
		_check(not world.tiled_loader.get_walk_path(GameState.ISKRA_ARRIVAL, world.marker(marker)).is_empty(), "western marker stays connected to city: " + marker)
	_check(world.marker("freight_office").x > 3000 and world.marker("veki_freight").x > 3000, "shipment freight stays at eastern docks")
	if not OS.get_environment("ISKRA_SCREENSHOT_DIR").is_empty():
		for marker in ["collector_neighbor", "collector_market", "collector_dispatch", "collector_route_north", "collector_route_south", "collector_holding", "collector_escape"]:
			_at(marker)
			await _capture("western_" + marker)
	world.player.global_position = jobs.collector.global_position + Vector2(32, 24)
	world._move_davor()
	world.davor.set_physics_process(false)
	await _capture("western_miro_route")
	_at("red_pelican")
	jobs.collector._stop_index = 1
	jobs.collector._wait = 0
	jobs.search._miro_stop = 1
	var initial: Vector2 = jobs.collector.global_position
	await get_tree().create_timer(2).timeout
	_check(jobs.collector.global_position.distance_to(initial) > 12 and world.tiled_loader.is_walkable_position(jobs.collector.global_position), "Miro actually walks bounded western route")
	jobs._tell("Nera", jobs.search.hint())
	var rival_initial: Vector2 = jobs.search.rival.global_position
	initial = jobs.collector.global_position
	var stage: float = jobs.search.get_value("stage")
	await get_tree().create_timer(2).timeout
	_check(initial == jobs.collector.global_position and rival_initial == jobs.search.rival.global_position and stage == jobs.search.get_value("stage"), "dialogue pauses both moving searchers and capture")
	_end()
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "save active western search")
	world.apply_loaded_state()
	_check(jobs.search.rival.global_position == rival_initial and jobs.collector.global_position == initial and jobs.search.get_value("stage") == stage, "load restores rival and Miro positions and search progress")
	var elapsed := 0.0
	while not jobs.has("hunt_rival_custody") and elapsed < 240:
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	_check(jobs.has("hunt_rival_custody"), "rival finds and catches Miro through actual street walking")
	if jobs.has("hunt_rival_custody"):
		_check(jobs.search.rival.global_position.distance_to(jobs.collector.global_position) < 60, "capture happens in physical proximity")
		world.capture_player_position()
		_check(GameState.save_game() and GameState.load_game(), "save rival custody")
		world.apply_loaded_state()
		_check(jobs.has("hunt_rival_custody") and jobs.collector._target == jobs.search.rival, "load preserves rival escort custody")
		world.player.global_position = jobs.search.rival.global_position + Vector2(-48, 24)
		world._move_davor()
		world.davor.set_physics_process(false)
		await _capture("rival_custody")
		elapsed = 0
		while not jobs.has("hunt_rival_delivered") and elapsed < 100:
			await get_tree().create_timer(0.2).timeout
			elapsed += 0.2
		_check(jobs.has("hunt_rival_delivered"), "rival and Miro physically arrive at western collection point")
		_at("red_pelican")
		var gold := GameState.gold
		_check(not jobs.report_hunt() and GameState.gold == gold, "rival delivery cannot pay player a bounty")
		ui.cancel_scene()
		world.player.global_position = jobs.search.rival.global_position
		_check(not jobs.search.intercept("demand"), "recorded rival delivery cannot be claimed by demand")
		_end()
		GameState.gold = 45
		_check(jobs.search.intercept("negotiate") and GameState.gold == 0, "harder45-gold release remains available after delivery")
		_end()
		world.player.global_position = jobs.collector.global_position
		_check(jobs.decide_hunt("escort"), "released collector still permits original outcomes")
		_at("red_pelican")
		jobs.collector.wait_at(world.player.global_position + Vector2(20, 0))
		_check(jobs.report_hunt() and GameState.gold == 0 and jobs.has("hunt_paid"), "return after rival delivery settles without undeserved capture reward")
	for mode in ["demand", "negotiate", "fight"]:
		await _captured_fixture()
		world.player.global_position = jobs.search.rival.global_position
		GameState.gold = 20
		_check(jobs.search.intercept(mode), "intercept rival by " + mode)
		if mode == "fight":
			_check(jobs.search.fighter.enemy_id == "bandit_sword", "rival fight is ordinary swordsman")
			jobs.search.fighter.take_damage(5, Vector2.ZERO)
			var health: int = jobs.search.fighter.health
			world.capture_player_position()
			_check(GameState.save_game() and GameState.load_game(), "save interception fight")
			world.apply_loaded_state()
			_check(jobs.search.fighter.health == health and jobs.has("hunt_intercept_fight"), "interception combat damage and custody persist")
			jobs.search.fighter.take_damage(999, Vector2.ZERO)
			await get_tree().process_frame
		_end()
		_check(not jobs.has("hunt_rival_custody") and jobs.has("hunt_rival_released"), "interception transfers Miro without a duplicate")
		world.player.global_position = jobs.collector.global_position
		jobs.collector.interact(world.player)
		_check(ui.scene_buttons.get_child_count() == 5, "all four collector outcomes remain available after interception")
		_end()
		_check(jobs.decide_hunt("escort") and jobs.collector._target == world.player, "player escort overrides rival and patrol after " + mode)
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("red_pelican")
	jobs.accept_hunt()
	_end()
	world.player.global_position = jobs.collector.global_position
	jobs.collector.interact(world.player)
	_end()
	_check(jobs.decide_hunt("bribe") and GameState.gold == 40, "player-first bribe begins physical escape")
	jobs.search.rival.wait_at(jobs.collector.global_position + Vector2(16, 0))
	jobs.search.put("stage", 4)
	jobs.search._target = ""
	jobs.search.step(100)
	_check(not jobs.has("hunt_rival_custody"), "rival cannot steal private decision while dialogue is open")
	_end()
	jobs.search.step(0.016)
	_check(jobs.has("hunt_rival_custody") and jobs.has("hunt_escape_pending"), "rival remains a physical threat after helping Miro escape")
	world.player.global_position = jobs.search.rival.global_position
	_check(jobs.search.intercept("fight"), "player can free Miro after interrupted escape")
	jobs.search.fighter.take_damage(999, Vector2.ZERO)
	await get_tree().process_frame
	_end()
	elapsed = 0
	while not jobs.has("hunt_escape_safe") and elapsed < 60:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_check(jobs.has("hunt_escape_safe") and GameState.gold == 40, "freed Miro reaches ship without duplicating bribe")
	_at("red_pelican")
	_check(jobs.report_hunt() and GameState.gold == 50, "completed protected escape retains original bribe outcome")
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("red_pelican")
	jobs.accept_hunt()
	_end()
	world.player.global_position = jobs.collector.global_position
	jobs.collector.interact(world.player)
	_end()
	jobs.decide_hunt("refused")
	jobs.search.step(0.016)
	initial = jobs.collector.global_position
	rival_initial = jobs.search.rival.global_position
	await get_tree().create_timer(2).timeout
	_check(initial == jobs.collector.global_position and rival_initial == jobs.search.rival.global_position, "refusal stops the rival race and Miro patrol")

func _captured_fixture() -> void:
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("red_pelican")
	jobs.accept_hunt()
	_end()
	jobs.collector.wait_at(world.marker("collector_hideout"))
	jobs.search.rival.wait_at(world.tiled_loader.nearest_walkable_position(jobs.collector.global_position + Vector2(64, 0)))
	jobs.search.put("stage", 4)
	jobs.search._target = ""
	var elapsed := 0.0
	while not jobs.has("hunt_rival_custody") and elapsed < 10:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_check(jobs.has("hunt_rival_custody"), "nearby rival walks to waiting Miro before capture")

func _pilot(stop: String) -> void:
	for old: String in jobs.STOPS:
		jobs.clear_flag("veki_at_" + old)
	jobs.set_flag("veki_at_" + stop)
	jobs._veki_stop = stop
	jobs.sync()

func _reset() -> void:
	ui.cancel_scene()
	for flag: String in GameState.defeated_persistent_enemies.duplicate():
		if flag.begins_with("iskra_gang_"):
			GameState.defeated_persistent_enemies.erase(flag)
	GameState.iskra_gang_state.clear()
	GameState.gold = 0
	GameState.health = GameState.max_health
	world.player.global_position = world.marker("veki_park")
	jobs.apply_loaded_state()
	world.davor.set_physics_process(false)

func _at(marker: String) -> void:
	ui.cancel_scene()
	world.player.global_position = world.marker(marker)
	world.player.velocity = Vector2.ZERO
	world._move_davor()
	world.davor.set_physics_process(false)

func _end() -> void:
	for i in 40:
		if not ui.scene_playing():
			return
		ui.advance_scene()

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	world.chapter.refresh_location()
	jobs.refresh_camera()
	world._camera.reset_smoothing()
	await get_tree().process_frame
	ui._hide_notice()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("pressure_" + label + ".png"))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + message)
