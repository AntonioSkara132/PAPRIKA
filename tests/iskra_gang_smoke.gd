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
		_check(false, "isolated saves required")
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
	world = game.world as IskraWorld
	jobs = world.gang_jobs
	var veki_sprite := jobs.veki.get_child(0) as Sprite2D
	_check(veki_sprite.texture.resource_path == "res://assets/art/iskra/npcs/veki.png" and veki_sprite.texture.get_size() == Vector2(16, 24), "Veki uses the distinctive original-size sprite")
	world.davor.set_physics_process(false)
	_check(jobs.veki.visible and not jobs.collector.visible and not jobs.prisoners[0].visible, "pilot present; undiscovered quest actors hidden")
	_at("red_pelican")
	_check(not jobs.accept_hunt(), "headhunt unavailable before audience")
	_at("green_squirrel")
	_check(not jobs.accept_rescue(), "rescue unavailable before audience")
	world.chapter.set_flag("morning")
	_check(not jobs.accept_rescue(), "morning alone does not unlock rescue")
	for faction in ["pelican", "squirrel"]:
		_reset()
		_at("red_pelican" if faction == "pelican" else "green_squirrel")
		world.story_people["red_pelican" if faction == "pelican" else "green_squirrel"].interact(world.player)
		_choose("Accept shipment")
		_check(jobs.side() == faction, "actual recruiter accepts " + faction + " shipment")
		_end()
		_at("green_squirrel" if faction == "pelican" else "red_pelican")
		_check(not jobs.accept_shipment("squirrel" if faction == "pelican" else "pelican"), "same shipment cannot be accepted from other gang")
		_at("veki_park")
		_check(jobs.fly("freight"), "Veki flies to freight without cash")
		world.capture_player_position()
		_check(GameState.save_game() and GameState.load_game(), "save during flight reloads")
		world.apply_loaded_state()
		_check(not world.taxi_active and jobs._veki_stop == "park" and world.player.visible and world.player.global_position == world.marker("veki_park"), "interrupted flight returns to departure without moving Veki")
		await _fly("freight")
		_at("freight_side")
		_check(not jobs.enter_freight(true), "inspection must be learned before entering")
		_at("freight_office")
		world.story_people.freight_office.interact(world.player)
		ui.cancel_scene()
		_check(not jobs.has("inspection_seen"), "cancelled inspection dialogue records nothing")
		world.story_people.freight_office.interact(world.player)
		_end()
		_check(jobs.has("inspection_seen"), "clerk explains inspection and alternate pad")
		if faction == "squirrel":
			_check(not jobs.bribe_freight(), "broke thief cannot pay clerk")
			_end()
			_at("freight_side")
			_check(jobs.enter_freight(true), "free service entrance avoids cash softlock")
		else:
			_check(jobs.enter_freight(false), "Pelican order allows front entrance")
		_check(world._camera.limit_bottom == 3200, "freight room camera follows interior")
		await _capture("freight_" + faction)
		_at("gang_freight_crate_a")
		_check(not jobs.take_crate(0), "cannot take cargo without manifest")
		_at("gang_freight_manifest")
		world.story_people.gang_freight_manifest.interact(world.player)
		_end()
		for i in 2:
			var suffix := "a" if i == 0 else "b"
			_at("gang_freight_crate_" + suffix)
			world.player._update_nearest_interactable()
			_check(world.player._current_interactable == world.story_people["gang_freight_crate_" + suffix], "E selects crate " + suffix)
			world.story_people["gang_freight_crate_" + suffix].interact(world.player)
			_check(jobs.has("shipment_carried_" + suffix), "physical pickup of crate " + suffix)
			_check(jobs.carrying.visible and not world.story_people["gang_freight_crate_" + suffix].visible, "carried crate replaces warehouse prop")
			_check(not jobs.take_crate(i), "crate cannot be duplicated")
			world.capture_player_position()
			_check(GameState.save_game() and GameState.load_game(), "carried cargo saves")
			world.apply_loaded_state()
			_check(jobs.carrying.visible and jobs.room() == "freight", "load preserves cargo and interior")
			_at("gang_freight_exit")
			_check(jobs.leave_site("freight", false), "cargo leaves warehouse through door")
			_at("veki_freight")
			_check(not jobs.fly("park"), "cannot board while holding cargo")
			_end()
			_check(jobs.load_crate(), "crate loaded on Veki's ship")
			_end()
			_check(not jobs.load_crate(), "cannot load same cargo twice")
			if i == 0:
				_at("freight_side")
				_check(jobs.enter_freight(true), "return for second crate")
		await _fly(faction)
		_check(not jobs.fly("squirrel" if faction == "pelican" else "pelican"), "cannot fly cargo to competing receiver")
		_check(jobs.deliver_shipment(), "both crates delivered to selected receiver")
		_end()
		_check(not jobs.deliver_shipment(), "delivery cannot repeat")
		await _fly("park")
		_at("red_pelican" if faction == "pelican" else "green_squirrel")
		_check(jobs.claim_shipment(), "shipment pays at recruiter")
		_end()
		_check(GameState.gold == (80 if faction == "pelican" else 90) and not jobs.claim_shipment(), "exact faction reward paid once")
		_check(not jobs.accept_shipment(faction), "completed shipment cannot restart")
	for outcome in ["escort", "money", "bribe", "refused"]:
		_reset()
		world.chapter.set_flag("audience_complete")
		_at("red_pelican")
		_check(jobs.accept_hunt(), "post-audience collector search accepted")
		_at("veki_park")
		jobs.veki.interact(world.player)
		_choose("Ask about Miro")
		_end()
		_check(jobs.has("hunt_flight_clue"), "Veki provides completed flight clue")
		_at("hotel")
		world.chapter.set_flag("hotel_cover_confirmed")
		world.story_people.hotel.interact(world.player)
		_choose("Ask about Miro")
		_choose("Ask where Miro")
		_end()
		_at("collector_neighbor")
		world.story_people.collector_neighbor.interact(world.player)
		_end()
		_check(jobs.has("hunt_route_known") and jobs.collector.visible, "hotel and neighbor clues identify western search route")
		_at("collector_hideout")
		jobs.collector.interact(world.player)
		await _capture("collector_" + outcome)
		ui.cancel_scene()
		_check(jobs.decide_hunt(outcome), "collector chooses " + outcome)
		_check(not jobs.decide_hunt("bribe"), "collector outcomes mutually exclusive")
		if outcome == "escort":
			_check(jobs.collector.is_escorting(), "collector physically follows")
			_at("red_pelican")
			_check(not jobs.report_hunt(), "distant collector cannot be handed over")
			_end()
			jobs.collector.global_position = world.player.global_position + Vector2(60, 0)
			var before: float = jobs.collector.global_position.distance_to(world.player.global_position)
			await get_tree().create_timer(0.5).timeout
			_check(jobs.collector.global_position.distance_to(world.player.global_position) < before, "collector walks under escort AI")
			world.capture_player_position()
			_check(GameState.save_game() and GameState.load_game(), "escort can save and reload")
			world.apply_loaded_state()
			_check(jobs.collector.is_escorting() and jobs.collector.visible, "collector escort restored after load")
		if outcome in ["money", "bribe"]:
			ui.cancel_scene()
			var elapsed := 0.0
			while jobs.has("hunt_escape_pending") and elapsed < 45.0:
				await get_tree().create_timer(0.1).timeout
				elapsed += 0.1
			if not jobs.has("hunt_escape_safe"):
				print("ESCAPE_DIAGNOSTIC ", jobs.collector.global_position, " target=", world.marker("collector_escape"), " mode=", jobs.collector._mode, " stop=", jobs.collector._stop_index, " wait=", jobs.collector._wait, " custody=", jobs.has("hunt_rival_custody"), " stage=", jobs.search.get_value("stage"))
			_check(jobs.has("hunt_escape_safe"), "Miro physically reaches departing crew for " + outcome)
		_at("red_pelican")
		_check(jobs.report_hunt() == (outcome != "refused"), "report handles " + outcome)
		_end()
		var expected: int = {"escort": 100, "money": 55, "bribe": 50, "refused": 0}[outcome]
		_check(GameState.gold == expected and not jobs.report_hunt(), "collector reward exact and cannot repeat: " + outcome)
	for mode in ["ransom", "sneak", "fight"]:
		_reset()
		world.chapter.set_flag("audience_complete")
		GameState.gold = 100
		_at("green_squirrel")
		_check(jobs.accept_rescue(), "rescue accepted after audience")
		await _fly("holding")
		_at("holding_side" if mode == "sneak" else "holding_office")
		_check(jobs.pay_ransom() if mode == "ransom" else jobs.enter_holding(mode), "enter prison by " + mode)
		if mode == "fight":
			_check(jobs.guards.size() == 2 and jobs.guards[0].enemy_id == "bandit_sword", "ordinary sword guards defend prison")
			world.capture_player_position()
			_check(GameState.save_game() and GameState.load_game(), "save partial fight")
			world.apply_loaded_state()
			_check(jobs.room().is_empty() and not jobs._alarm and not jobs.has("rescue_freed"), "load interrupted fight resets outside prison")
			_at("holding_office")
			jobs.enter_holding("fight")
			for guard: Enemy in jobs.guards:
				guard.take_damage(999, Vector2.ZERO)
			await get_tree().process_frame
			_check(jobs.has("rescue_guards_cleared"), "defeated ordinary guards allow unlock")
		_at("gang_holding_lock")
		_check(jobs.release_prisoners(), "release two prisoners via " + mode)
		_check(jobs.prisoners[0].is_escorting() and jobs.prisoners[1].is_escorting(), "both prisoners use escort movement")
		await _capture("rescue_" + mode)
		if mode == "fight":
			_at("gang_holding_stash")
			_check(jobs.start_stash_alarm(), "optional money triggers extra guard")
			_check(not jobs.take_stash(), "money unavailable while extra guard alive")
			jobs.guards[-1].take_damage(999, Vector2.ZERO)
			await get_tree().process_frame
			_check(jobs.take_stash(), "money recovered after extra fight")
			_end()
		_at("gang_holding_side")
		_check(not jobs.leave_site("holding", true), "cannot teleport distant prisoners through exit")
		var waited := 0.0
		while waited < 8.0 and (jobs.prisoners[0].global_position.distance_to(world.player.global_position) > 70 or jobs.prisoners[1].global_position.distance_to(world.player.global_position) > 70):
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_check(jobs.leave_site("holding", true), "both prisoners physically reach service exit")
		_at("veki_holding")
		_check(not jobs.fly("park"), "ship waits for prisoners to reach it")
		_end()
		waited = 0.0
		while waited < 10.0 and (jobs.prisoners[0].global_position.distance_to(jobs.veki.global_position) > 90 or jobs.prisoners[1].global_position.distance_to(jobs.veki.global_position) > 90):
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		await _fly("park")
		_check(jobs.has("rescue_extracted"), "both prisoners extracted to park")
		_at("green_squirrel")
		_check(jobs.claim_rescue(), "rescue reward paid")
		_end()
		var expected := 170 if mode == "ransom" else (260 if mode == "fight" else 220)
		_check(GameState.gold == expected and not jobs.claim_rescue(), "rescue exact base reward, optional bonus, no repeat: " + mode)
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("green_squirrel")
	jobs.accept_rescue()
	await _fly("holding")
	_at("holding_side")
	jobs.enter_holding("sneak")
	_at("gang_holding_guard_a")
	jobs.step(0.016)
	_check(jobs._alarm and jobs.guards.size() == 2, "entering watch circle starts ordinary guard fight")
	jobs.on_respawn()
	_check(not jobs._alarm and not jobs.has("rescue_freed") and not jobs.has("rescue_guards_cleared"), "knockout resets unfinished fight and prisoners")
	_at("holding_office")
	GameState.gold = 50
	_check(jobs.pay_ransom(), "ransom can be paid after a failed infiltration")
	_at("gang_holding_lock")
	jobs.release_prisoners()
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "save during prisoner escort inside prison")
	world.apply_loaded_state()
	_check(not jobs.has("rescue_freed") and jobs.has("rescue_ransom") and jobs.room().is_empty(), "interrupted indoor escort resets safely but preserves paid ransom")
	_at("holding_office")
	_check(jobs.pay_ransom() and GameState.gold == 0, "paid ransom receipt allows free repeat entry")
	_finish()

func _reset() -> void:
	ui.cancel_scene()
	for flag: String in GameState.defeated_persistent_enemies.duplicate():
		if flag.begins_with("iskra_gang_") or flag == "iskra_audience_complete":
			GameState.defeated_persistent_enemies.erase(flag)
	GameState.gold = 0
	GameState.iskra_gang_state.clear()
	world.player.global_position = world.marker("veki_park")
	jobs.apply_loaded_state()

func _at(id: String) -> void:
	ui.cancel_scene()
	world.player.global_position = world.marker(id)
	world.player.velocity = Vector2.ZERO
	world._move_davor()
	world.davor.set_physics_process(false)

func _fly(destination: String) -> void:
	ui.cancel_scene()
	world.player.global_position = jobs.veki.global_position
	_check(jobs.fly(destination), "start actual Veki flight to " + destination)
	for i in 300:
		if not world.taxi_active:
			break
		await get_tree().create_timer(0.02).timeout
	_check(not world.taxi_active and jobs._veki_stop == destination and world.player.visible, "animated landing completes at " + destination)
	world.davor.set_physics_process(false)

func _choose(prefix: String) -> void:
	for child in ui.scene_buttons.get_children():
		if child is Button and child.text.begins_with(prefix):
			child.pressed.emit()
			return
	_check(false, "missing dialogue choice " + prefix)

func _end() -> void:
	for i in 40:
		if not ui.scene_playing():
			return
		ui.advance_scene()
	_check(false, "dialogue finishes")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	ui._hide_notice()
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("gang_" + label + ".png"))

func _finish() -> void:
	print("Iskra gangs: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
