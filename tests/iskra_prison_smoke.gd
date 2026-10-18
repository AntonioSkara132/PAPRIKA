extends "res://tests/iskra_pressure_smoke.gd"

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
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("green_squirrel")
	_check(jobs.accept_rescue(), "accept rescue at Toma")
	_end()
	_at("veki_park")
	_check(jobs.fly("holding"), "Veki flies to relocated Store 6")
	await get_tree().create_timer(3.5).timeout
	_check(jobs.veki.global_position == world.marker("veki_holding"), "flight lands at new courtyard stop")
	_check(world.marker("holding_office").x < 1800 and world.marker("holding_office").y > 2400, "Store 6 is in southern courtyard, not dock")
	for marker in ["holding_office", "holding_side", "veki_holding"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("arrival"), world.marker(marker)).is_empty(), "city access: " + marker)
	await _capture("store6_courtyard")
	var has_opening := false
	var paths_clear := true
	for tick in 300:
		jobs._step_patrols(0.1)
		var seen := false
		for mark: Node2D in jobs.guard_marks:
			paths_clear = paths_clear and world.tiled_loader.is_walkable_position(mark.global_position)
			for point in ["gang_holding_lock", "gang_holding_prisoner_a", "gang_holding_prisoner_b"]:
				seen = seen or jobs.patrol_can_see(mark.global_position, world.marker(point))
		has_opening = has_opening or not seen
	_check(paths_clear, "patrol routes stay on walkable floor")
	_check(has_opening, "patrol cycle leaves stealth opening at lock and both prisoners")
	jobs._clear_guards(false)
	_at("holding_side")
	_check(jobs.enter_holding("sneak"), "service entrance opens relocated prison")
	_check(not jobs._alarm, "service entry allows time to observe patrol")
	var start: Vector2 = jobs.guard_marks[1].global_position
	await get_tree().create_timer(0.5).timeout
	_check(jobs.guard_marks[1].global_position.distance_to(start) > 10, "service corridor guard actually moves")
	jobs._tell("Patrol test", "Planning pauses patrols.")
	start = jobs.guard_marks[1].global_position
	await get_tree().create_timer(1.0).timeout
	_check(jobs.guard_marks[1].global_position == start and not jobs._alarm, "dialogue pauses movement and detection")
	await _capture("prison_patrols")
	_end()
	# Stay at the service entrance; the guard must eventually see this exposed position.
	await get_tree().create_timer(5.0).timeout
	_check(jobs._alarm and jobs.guards.size() == 2, "moving guard detects exposed service-entry player")
	for guard: Enemy in jobs.guards:
		_check(guard.max_health == 38 and guard.definition.damage == 5, "patrol alarm retains ordinary guard stats")
	_check(not jobs.ROOMS.holding.has_point(world.davor.global_position), "Davor remains outside prison")
	var origin: Vector2 = jobs.ROOMS.holding.position
	_check(jobs.patrol_can_see(origin + Vector2(400, 224), origin + Vector2(500, 224)), "sight reaches 100 pixels along open aisle")
	_check(not jobs.patrol_can_see(origin + Vector2(400, 224), origin + Vector2(536, 224)), "sight range remains bounded")
	_check(not jobs.patrol_can_see(origin + Vector2(80, 32), origin + Vector2(80, 112)), "shelving blocks sight within detection range")
	for guard: Enemy in jobs.guards:
		guard.take_damage(999, Vector2.ZERO)
	await get_tree().process_frame
	_at("gang_holding_lock")
	_check(jobs.release_prisoners(), "ordinary guard defeat allows rescue")
	_end()
	await _escort_to_ship()
	_check(jobs.fly("park"), "rescued prisoners board at relocated stop")
	await get_tree().create_timer(3.5).timeout
	_check(jobs.has("rescue_extracted"), "relocated rescue flight completes")
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("green_squirrel")
	_check(jobs.accept_rescue(), "accept stealth rescue")
	_end()
	_pilot("holding")
	_at("holding_side")
	jobs.enter_holding("sneak")
	await _walk_to(jobs.ROOMS.holding.position + Vector2(608, 328))
	_check(not jobs._alarm, "service entrant can reach sheltered corner")
	var waited := 0.0
	while waited < 12.0 and jobs.guard_marks[1].position.x > jobs.ROOMS.holding.position.x + 432:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	# Observe a complete first approach before following the guard away from the cells.
	while waited < 12.0 and (jobs.guard_marks[1].position.y > jobs.ROOMS.holding.position.y + 128 or jobs.guard_marks[1].position.x > jobs.ROOMS.holding.position.x + 432):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	await _walk_to(world.marker("gang_holding_lock"))
	_check(not jobs._alarm and jobs.release_prisoners(), "timed stealth approach reaches lock without alarm")
	_end()
	await _escort_to_ship()
	_check(not jobs._alarm, "both prisoners can follow the patrol opening without detection")
	_check(jobs.fly("park"), "stealth rescue boards relocated ship")
	await get_tree().create_timer(3.5).timeout
	_check(jobs.has("rescue_extracted"), "stealth rescue extraction completes")
	_reset()
	world.chapter.set_flag("audience_complete")
	_at("green_squirrel")
	_check(jobs.accept_rescue(), "accept rescue at Toma")
	_end()
	_pilot("holding")
	GameState.gold = 50
	_at("holding_office")
	_check(jobs.pay_ransom(), "ransom opens new front entrance")
	_at("gang_holding_lock")
	await get_tree().create_timer(3.0).timeout
	_check(not jobs._alarm and jobs.guards.is_empty(), "ransom permits walking beside guards without forced alarm")
	_check(jobs.release_prisoners() and not jobs.pressure.started("rescue"), "paid rescue starts no timer")
	_end()
	await _escort_to_ship()
	_check(jobs.fly("park"), "ransom passengers board relocated ship")
	await get_tree().create_timer(3.5).timeout
	_check(jobs.has("rescue_extracted"), "ransom extraction completes")
	Engine.time_scale = 1.0
	print("Iskra prison: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _escort_to_ship() -> void:
	await _walk_to(world.marker("gang_holding_side"))
	await get_tree().create_timer(1.5).timeout
	_check(jobs.leave_site("holding", true), "both prisoners physically reach service door")
	await _walk_to(world.marker("veki_holding"))
	await get_tree().create_timer(1.5).timeout
	_check(jobs.prisoners[0].global_position.distance_to(jobs.veki.global_position) < 96 and jobs.prisoners[1].global_position.distance_to(jobs.veki.global_position) < 96, "both prisoners physically walk from new exit to ship")
	await _capture("prison_exterior_escort")

func _walk_to(destination: Vector2) -> void:
	var path: PackedVector2Array = world.tiled_loader.get_walk_path(world.player.global_position, destination)
	_check(not path.is_empty(), "escort walking path exists")
	world.player.set_physics_process(false)
	for point in path:
		while world.player.global_position.distance_to(point) > 1:
			await get_tree().physics_frame
			world.player.global_position = world.player.global_position.move_toward(point, 90.0 * get_physics_process_delta_time())
	world.player.set_physics_process(true)
