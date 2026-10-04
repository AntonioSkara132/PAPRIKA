extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	var save_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	if data_home.is_empty() or not save_path.begins_with(data_home + "/"):
		_check(false, "station smoke requires an isolated XDG_DATA_HOME")
		_finish(null)
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene loads for station enlistment")
	if scene == null:
		_finish(null)
		return
	var game := scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	var ui := game.get_node_or_null("GameUI") as GameUI
	if ui == null or game.world == null:
		_check(false, "main scene starts with travel UI and a player")
		_finish(game)
		return
	var state := GameState
	_check(not state.can_travel("station") and state.military_stage == "none", "the station cannot be entered directly from Paprika")
	state.add_gold(GameData.TRAVEL_FARE)
	ui.open_service("travel", "Paprika Travel Agency")
	var visit := _find_button(ui.modal_content, "Visit Brudet")
	_check(visit != null and not visit.disabled, "regular travel offers Brudet before enlistment")
	if visit == null:
		_finish(game)
		return
	visit.pressed.emit()
	await get_tree().process_frame
	_check(game._world_planet == "brudet" and state.current_planet == "brudet", "ordinary travel reaches Brudet")
	if game._world_planet != "brudet":
		_finish(game)
		return
	var hq := _service(game.world, "military_hq")
	_check(hq != null, "Military Headquarters exists on Brudet")
	if hq == null:
		_finish(game)
		return
	var brudet_departure := hq.get_interaction_position() + Vector2(0, 11)
	var previous_gold := state.gold
	state.add_item("iron_sword", 2)
	state.add_item("wood_armor")
	state.add_item("red_tunic")
	state.equip_item("iron_sword")
	state.equip_item("wood_armor")
	state.equip_item("red_tunic")
	_check(state.accept_job("river_patrol"), "preexisting Brudet work remains active before enlistment")
	var personal_items: Dictionary = state.inventory.duplicate(true)
	var personal_equipment: Dictionary = state.equipment.duplicate(true)
	_check(_interact_service(game.world, ui, "military_hq") and ui._active_service_id == "military_hq", "E at headquarters opens its enlistment menu")
	var join := _find_button(ui.modal_content, "Join the Military")
	_check(join != null and _has_text(ui.modal_content, "regular ship") and _has_text(ui.modal_content, "depot"), "headquarters offers direct enlistment beside a regular ship and depot")
	if join == null:
		_finish(game)
		return
	join.pressed.emit()
	await get_tree().process_frame
	var station := game.world as StationWorld
	_check(station != null and state.current_planet == "station" and state.current_area == "exterior" and state.military_stage == "depot" and state.gold == previous_gold, "Join the Military travels directly to the station for free")
	if station == null:
		_finish(game)
		return
	_check(station.player.global_position.distance_to(state.MILITARY_ARRIVAL) < 50.0 and station.player.respawn_location_name.contains("station") and station.tiled_loader.is_walkable_position(station.player.global_position), "station arrival is walkable and has a station respawn")
	_check(ui.location_label.text.contains("STATION"), "HUD identifies the training station")
	_check_visual_station(station)
	await _check_station_ambience(station)
	_check(_service(station, "station_ship") != null and _service(station, "station_depot") != null, "regular ship and depot are present on the exterior")
	var exterior_ids: Dictionary = {}
	for actor in station.actors_root.get_children():
		if actor is StationRecruit:
			exterior_ids[(actor as StationRecruit).recruit_id] = true
	_check(exterior_ids.size() == 9 and StationRoster.RECRUITS.all(func(data: Dictionary) -> bool: return exterior_ids.has(data["id"])), "the same nine named recruits have exterior routines")
	_check(not state.can_travel("brudet") and not state.military_complete_drill("run") and not state.military_sleep(), "ship, drill and bed cannot skip the depot")
	_check(_service_routes(station, ["station_ship", "station_depot", "station_barracks", "station_canteen", "station_track", "station_spar", "station_squad_spar", "station_range", "station_cannon_start", "station_tnt_pile", "station_cannon", "station_trap_pad"]), "all exterior station services have walkable entrances from the arrival")
	_check(_interact_service(station, ui, "station_spar"), "E opens the sparring station even before its stage")
	var early_spar := _find_button(ui.modal_content, "Use training station")
	_check(early_spar != null and early_spar.disabled, "out-of-order drill button is disabled")
	ui.close_modal()
	_check(_press_service(game, ui, "station_depot", "Receive your military uniform"), "depot issues the uniform through its interaction menu")
	_check(state.military_stage == "barracks" and int(state.inventory.get("military_uniform", 0)) == 1 and state.equipment["clothing"] == "military_uniform", "one issued uniform is visibly equipped")
	_check(station.player._sprite.texture.resource_path.ends_with("player_uniform.png") and station.player._sprite.texture.get_width() == 16 and station.player._sprite.texture.get_height() == 24, "uniform changes the player sprite to 16-by-24 military art")
	_check(not state.military_claim_uniform(), "the depot cannot duplicate the uniform")
	_check(_press_service(game, ui, "station_barracks", "Enter the barracks"), "barracks door leads to its first interior")
	await get_tree().process_frame
	var interior := game.world as StationBarracksWorld
	_check(interior != null and state.current_area == "barracks" and ui.location_label.text.contains("BARRACKS"), "area transition loads the barracks and its location title")
	if interior == null:
		_finish(game)
		return
	var interior_soldier_count := 0
	for actor in interior.actors_root.get_children():
		var actor_script := actor.get_script() as Script
		if actor_script != null and actor_script.resource_path.ends_with("station_soldier.gd"):
			interior_soldier_count += 1
	_check(interior_soldier_count == 0, "ambient soldiers remain outside the barracks interior")
	_check(interior.tiled_loader.is_walkable_position(interior.player.global_position), "barracks spawn is walkable")
	var fixtures := _fixture_counts(interior)
	_check(int(fixtures.get("player_bed", 0)) == 1 and int(fixtures.get("player_chest", 0)) == 1 and int(fixtures.get("recruit_bed", 0)) == 9 and int(fixtures.get("recruit_chest", 0)) == 9, "first interior has one assigned bed/chest and nine recruit beds/chests")
	var recruits: Dictionary = {}
	var origins: Dictionary = {}
	var all_stops_reachable := true
	for actor in interior.actors_root.get_children():
		if not actor is StationRecruit:
			continue
		var recruit := actor as StationRecruit
		recruits[recruit.recruit_id] = recruit
		origins[recruit.origin] = true
		all_stops_reachable = all_stops_reachable and recruit._stops.size() >= 2
		for stop in recruit._stops:
			var route: PackedVector2Array = interior.tiled_loader.get_walk_path(recruit.home_position, stop)
			all_stops_reachable = all_stops_reachable and interior.tiled_loader.is_walkable_position(stop) and not route.is_empty() and route[-1].distance_to(stop) < 17.0
	_check(recruits.size() == 9 and origins.has("Paprika") and origins.has("Brudet") and origins.has("Confederation"), "nine distinct named recruits come from Paprika, Brudet and elsewhere in the Confederation")
	for data in StationRoster.RECRUITS:
		var id := String(data["id"])
		var named := recruits.get(id) as StationRecruit
		_check(named != null and named.recruit_name == String(data["name"]), "barracks recruit %s has a stable name and identity" % id)
		if named != null:
			named.interact(interior.player)
			_check(ui.notification_label.text.begins_with(named.recruit_name + ": "), "%s responds with their own named dialogue" % named.recruit_name)
	_check(all_stops_reachable, "all nine recruit routines have walkable, connected barracks stops")
	var first := recruits.get("station_recruit_mara") as StationRecruit
	if first != null:
		var routine_start := first.global_position
		first._wait = 0.0
		first._stop_index = 1
		for tick in 35:
			await get_tree().physics_frame
		_check(first.global_position.distance_to(routine_start) > 3.0, "a named recruit physically moves along the barracks routine (start=%s, end=%s, stops=%s)" % [routine_start, first.global_position, first._stops])
		var heard: Array[String] = []
		var capture_recruit_dialogue := func(message: String) -> void: heard.append(message)
		state.notification_requested.connect(capture_recruit_dialogue)
		first.interact(interior.player)
		first.interact(interior.player)
		state.notification_requested.disconnect(capture_recruit_dialogue)
		_check(heard.size() >= 2 and heard[-1].begins_with("Mara:") and heard[-2] != heard[-1], "talking to a recruit gives distinct named dialogue")
	_check(_interact_service(interior, ui, "recruit_chest") and _find_button(ui.modal_content, "Store personal belongings") == null, "another recruit's footlocker cannot store the player's gear")
	ui.close_modal()
	_check(_interact_service(interior, ui, "player_bed"), "player bunk opens its menu before graduation")
	var early_bed := _find_button(ui.modal_content, "Sleep in your bunk")
	_check(early_bed != null and early_bed.disabled and not state.military_sleep(), "sleep is locked until all six drills are finished")
	ui.close_modal()
	_check(_press_service(game, ui, "player_chest", "Store personal belongings"), "assigned chest stores gear through its menu")
	_check(state.military_stage == "run" and state.military_storage == personal_items and state.military_stored_equipment == personal_equipment, "chest stores every civilian item and equipped choice with the original counts")
	_check(state.inventory == {"military_uniform": 1} and state.equipment == {"weapon": "", "armor": "", "clothing": "military_uniform"}, "stored gear is no longer available in the backpack")
	_check(not state.military_store_gear() and not state.military_withdraw_gear(), "storage and withdrawal cannot be repeated during training")
	interior.player.global_position = _near_service(interior, _service(interior, "player_chest"))
	var saved_interior := interior.player.global_position
	_check(_quick_save(game), "F5 saves while inside the barracks")
	var stored_save = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	if stored_save is Dictionary:
		var duplicated_gear: Dictionary = stored_save.duplicate(true)
		duplicated_gear["inventory"]["stick"] = 1
		_check(not state._valid_save(duplicated_gear), "save validation rejects an item duplicated between pack and footlocker")
	interior.player.global_position = state.MILITARY_BARRACKS_ARRIVAL
	_quick_load(game)
	await get_tree().process_frame
	interior = game.world as StationBarracksWorld
	_check(interior != null and state.current_area == "barracks" and state.military_storage == personal_items and interior.player.global_position.distance_to(saved_interior) < 20.0, "F9 rebuilds the barracks and restores its position and chest")
	if interior == null:
		_finish(game)
		return
	_check(_press_service(game, ui, "barracks_exit", "Leave the barracks"), "exit returns to the exterior")
	await get_tree().process_frame
	station = game.world as StationWorld
	_check(station != null and state.current_area == "exterior" and state.military_stage == "run", "exterior resumes at the running stage")
	if station == null:
		_finish(game)
		return
	await _check_run(game, ui, station)
	if state.military_stage != "spar":
		_finish(game)
		return
	station = game.world as StationWorld
	await _check_spar(game, ui, station)
	if state.military_stage != "squad":
		_finish(game)
		return
	await _check_squad(game, ui, station)
	if state.military_stage != "range":
		_finish(game)
		return
	await _check_range(game, ui, station)
	if state.military_stage != "cannon":
		_finish(game)
		return
	await _check_cannon(game, ui, station)
	if state.military_stage != "trap":
		_finish(game)
		return
	await _check_trap(game, ui, station)
	if state.military_stage != "sleep":
		_finish(game)
		return
	_check(state.military_stage == "sleep" and state.military_meal_credits >= 1 and state.military_cannon_hits.size() == 3 and state.military_trap_progress == 3, "six drills advance in order and record their distinct target progress")
	_check(not state.record_event("river_monster_defeated") and int(state.active_jobs.get("river_patrol", -1)) == 0, "station drills do not advance an unfinished Brudet patrol")
	_check(not state.can_travel("brudet") and not state.military_sleep(), "completion without sleeping still blocks the return ship")
	_check(_press_service(game, ui, "station_barracks", "Enter the barracks"), "barracks remains enterable after training")
	await get_tree().process_frame
	interior = game.world as StationBarracksWorld
	if interior == null:
		_check(false, "barracks opens for graduation")
		_finish(game)
		return
	_check(_press_service(game, ui, "player_bed", "Sleep in your bunk"), "assigned bed finishes training through its action")
	_check(state.military_stage == "graduated" and state.health == state.max_health, "sleep heals and graduates only after all six drills")
	var credits_before_second_sleep := state.military_meal_credits
	state.damage_player(2)
	_check(state.military_sleep() and state.military_stage == "graduated" and state.health == state.max_health and state.military_meal_credits == credits_before_second_sleep, "later nights heal without repeating graduation rewards")
	_check(not state.can_travel("brudet") and state.military_storage == personal_items, "ship cannot depart from inside the barracks, and the personal chest stays full")
	_check(_press_service(game, ui, "barracks_exit", "Leave the barracks"), "graduated recruit leaves the barracks")
	await get_tree().process_frame
	station = game.world as StationWorld
	_check(station != null and state.can_travel("brudet") and state.military_storage == personal_items, "graduate can return to Brudet while their belongings remain in the footlocker")
	if station != null:
		_check(_press_service(game, ui, "station_ship", "Return to Brudet"), "regular station ship offers the free return")
		await get_tree().process_frame
	_check(game._world_planet == "brudet" and state.current_planet == "brudet" and state.gold == previous_gold and game.world.player.global_position.distance_to(brudet_departure) < 60.0, "return is free and recalls the prior Brudet location")
	_check(state.military_storage == personal_items and state.military_stored_equipment == personal_equipment and state.inventory == {"military_uniform": 1}, "stored gear stays at the station, with no copies in the pack on Brudet")
	_check(int(state.active_jobs.get("river_patrol", -1)) == 0, "return preserves the unfinished civilian patrol without training credit")
	if game._world_planet == "brudet":
		_check(_press_service(game, ui, "military_hq", "Return to the training station"), "headquarters allows a later visit to the station")
		await get_tree().process_frame
		station = game.world as StationWorld
		_check(station != null and state.military_stage == "graduated" and int(state.inventory.get("military_uniform", 0)) == 1 and state.military_storage == personal_items and state.gold == previous_gold, "re-entry keeps graduation and the stored gear without another uniform or fare")
		if station != null:
			_check(_quick_save(game), "F5 saves on the station exterior with the footlocker still full")
			var saved_exterior := station.player.global_position
			station.player.global_position += Vector2(40, 0)
			_quick_load(game)
			await get_tree().process_frame
			station = game.world as StationWorld
			_check(station != null and state.current_area == "exterior" and station.player.global_position.distance_to(saved_exterior) < 20.0 and state.military_stage == "graduated" and state.military_storage == personal_items, "F9 rebuilds the exterior and preserves graduation and stored belongings")
			_check(_press_service(game, ui, "station_barracks", "Enter the barracks"), "graduated recruit can revisit the barracks for their gear")
			await get_tree().process_frame
			interior = game.world as StationBarracksWorld
			if interior != null:
				_check(_press_service(game, ui, "player_chest", "Retrieve stored belongings"), "footlocker returns gear after an interplanetary round trip")
				var expected_return := personal_items.duplicate(true)
				expected_return["military_uniform"] = 1
				_check(state.inventory == expected_return and state.equipment == personal_equipment and state.military_storage.is_empty() and not state.military_withdraw_gear(), "withdrawal restores original counts once with no duplicates")
			else:
				_check(false, "barracks reloads for gear collection after returning from Brudet")
	_check_migration()
	_finish(game)

func _check_run(game: Node, ui: GameUI, station: StationWorld) -> void:
	var state := GameState
	_check(_press_service(game, ui, "station_track", "Use training station") and station._round == "run" and station._run_markers.size() == 4, "track starts a timed four-checkpoint exercise")
	if station._round != "run" or station._run_markers.size() != 4:
		return
	var first: Vector2 = station._run_markers[0].global_position
	station.player.global_position = first + Vector2(-72, 0)
	Input.action_press("move_right")
	var normal_start := station.player.global_position
	for tick in 12:
		await get_tree().physics_frame
	var normal_distance := station.player.global_position.distance_to(normal_start)
	Input.action_press("station_sprint")
	var sprint_start := station.player.global_position
	for tick in 12:
		await get_tree().physics_frame
	var sprint_distance := station.player.global_position.distance_to(sprint_start)
	Input.action_release("move_right")
	_check(normal_distance > 4.0 and sprint_distance > normal_distance * 1.25, "holding Shift increases actual running speed")
	var start := station.player.global_position
	Input.action_press("station_sprint")
	for marker_index in 4:
		var reached := false
		for tick in 180:
			if state.military_stage != "run" or station._run_index > marker_index:
				reached = true
				break
			if marker_index >= station._run_markers.size():
				break
			var marker: Vector2 = station._run_markers[marker_index].global_position
			_move_toward(station.player.global_position, marker)
			await get_tree().physics_frame
		_release_movement()
		_check(reached or station._run_index > marker_index or state.military_stage != "run", "player physically reaches timed run marker %d" % (marker_index + 1))
		if station._round != "run":
			break
	_check(state.military_stage == "spar" and station._round.is_empty() and station.player.global_position.distance_to(start) > 40.0 and station._run_remaining > 0.0, "running course completes before its timer expires (stage=%s, seconds=%.1f)" % [state.military_stage, station._run_remaining])
	_check(state.military_meal_credits == 1, "finishing the run earns one canteen meal")
	if _interact_service(station, ui, "station_canteen"):
		var meal := _find_button(ui.modal_content, "Collect a meal")
		_check(meal != null and not meal.disabled, "canteen offers an earned meal after the run")
		ui.close_modal()
	state.health = maxi(1, state.max_health - 12)
	var credits := state.military_meal_credits
	_check(_press_service(game, ui, "station_canteen", "Collect a meal"), "earned canteen meal can be requested at the exterior canteen")
	_check(state.health > state.max_health - 12 and state.military_meal_credits == credits - 1, "canteen restores health and spends exactly one earned meal credit")

func _check_spar(game: Node, ui: GameUI, station: StationWorld) -> void:
	var state := GameState
	_check(_press_service(game, ui, "station_spar", "Use training station") and station._round == "spar", "partner spar begins at the sparring ring")
	if station._round != "spar":
		return
	var partner: StationRecruit = station._recruit(5)
	_check(partner.training_active and partner.training_team == "spar" and partner.is_in_group("damageable"), "named partner moves and accepts nonlethal practice hits")
	var health_before := state.health
	for attempt in 8:
		if state.military_stage != "spar":
			break
		station.player.global_position = partner.global_position + Vector2(-14, 0)
		station.player.facing = Vector2.RIGHT
		station.player._attack()
		for tick in 35:
			await get_tree().physics_frame
	_check(state.military_stage == "squad" and station._round.is_empty() and state.health == health_before and state.military_meal_credits >= 1, "player melee completes a moving 1v1 bout without losing health")

func _check_squad(game: Node, ui: GameUI, station: StationWorld) -> void:
	var state := GameState
	_check(_press_service(game, ui, "station_squad_spar", "Use training station") and station._round == "squad", "three-versus-three match starts from its own ring")
	if station._round != "squad":
		return
	_check(station._allies.size() == 2 and station._cadets.size() == 3 and station._allies[0].recruit_name == "Mara" and station._allies[1].recruit_name == "Tovin", "Mara and Tovin face three named, nonlethal cadets")
	for pair in [["order_hold", "hold"], ["order_follow", "follow"], ["order_attack", "attack"]]:
		var event := InputEventAction.new()
		event.action = String(pair[0])
		event.pressed = true
		station._unhandled_input(event)
		_check(station._allies.size() == 2 and station._allies.all(func(ally: StationRecruit) -> bool: return ally.training_order == String(pair[1])), "Q/R/T sets both squad allies to %s" % pair[1])
	var health_before := state.health
	for attempt in 15:
		if state.military_stage != "squad" or station._round != "squad":
			break
		var target: StationRecruit = station._nearest_live_cadet(station.player.global_position)
		if target == null:
			break
		station.player.global_position = target.global_position + Vector2(-14, 0)
		station.player.facing = Vector2.RIGHT
		station.player._attack()
		for tick in 35:
			await get_tree().physics_frame
	_check(state.military_stage == "range" and station._round.is_empty() and state.health == health_before, "player and two ordered allies defeat three cadets without player health loss")

func _check_range(game: Node, ui: GameUI, station: StationWorld) -> void:
	var state := GameState
	_check(_press_service(game, ui, "station_range", "Use training station") and station._range_targets.size() == 3, "range starts three moving physical targets")
	if station._round != "range" or station._range_targets.size() != 3:
		return
	var first: StationMovingTarget = station._range_targets[0]
	var before := station._range_hits.size()
	first.take_damage(100, first.global_position)
	_check(station._range_hits.size() == before, "direct melee-style damage cannot score a range hit")
	for target_id in 3:
		if state.military_stage != "range":
			break
		var target: StationMovingTarget = station._range_targets[target_id]
		var start := target.global_position
		for tick in 4:
			await get_tree().physics_frame
		_check(target.global_position.distance_to(start) > 0.1 and target.moving, "range target %d moves before being shot" % (target_id + 1))
		station.player.global_position = target.global_position + Vector2(-59, 0)
		station.player.facing = Vector2.RIGHT
		station.player._attack_cooldown = 0.0
		station.player._attack()
		for tick in 70:
			if not target.moving or state.military_stage != "range":
				break
			await get_tree().physics_frame
		_check(not target.moving or state.military_stage != "range", "player-fired projectile strikes moving range target %d" % (target_id + 1))
	_check(state.military_stage == "cannon" and station._range_hits.size() == 3, "three separate player shots finish the range checkpoint")
	_check(_quick_save(game), "F5 saves the exterior after projectile practice")
	var saved_stage := state.military_stage
	_quick_load(game)
	await get_tree().process_frame
	_check(state.military_stage == saved_stage and game.world is StationWorld, "F9 resumes training on the exterior after range practice")

func _check_cannon(game: Node, ui: GameUI, station: StationWorld) -> void:
	station = game.world as StationWorld
	var state := GameState
	if station == null or state.military_stage != "cannon":
		_check(false, "cannon stage is available after range")
		return
	_check(state.military_cannon_hits.is_empty() and not state.military_cannon_round_active and state.military_cannon_phase == "empty", "cannon stage starts with no active round or scored targets")
	_check(_interact_service_with_key(station, ui, "station_tnt_pile", KEY_E, false) and not state.military_cannon_round_active and ui.notification_label.text.to_lower().contains("flag"), "E at the supply pile before starting points to the cannon range flag")
	_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and not state.military_cannon_round_active and ui.notification_label.text.to_lower().contains("flag"), "E at the cannon before starting points to the cannon range flag")
	_check(_interact_service_with_key(station, ui, "station_cannon_start", KEY_E, true), "E opens the separate cannon range start menu")
	var start_button := _find_button(ui.modal_content, "Use training station")
	_check(start_button != null and not start_button.disabled, "cannon range flag offers Use training station")
	if start_button == null or start_button.disabled:
		ui.close_modal()
		return
	start_button.pressed.emit()
	_check(state.military_cannon_round_active and state.military_cannon_phase == "empty" and state.military_cannon_hits.is_empty() and station._cannon_targets.size() == 3, "starting the cannon round sets its saved empty phase and three targets")
	_check(_interact_service_with_key(station, ui, "station_cannon_start", KEY_E, true), "active cannon flag still opens its menu")
	var active_button := _find_button(ui.modal_content, "Cannon round already active")
	_check(active_button != null and active_button.disabled, "active cannon round cannot be started twice")
	ui.close_modal()
	_check(_interact_service_with_key(station, ui, "station_tnt_pile", KEY_E, false) and state.military_cannon_phase == "carried", "E at the supply pile directly takes one game charge")
	_check(_interact_service_with_key(station, ui, "station_tnt_pile", KEY_E, false) and state.military_cannon_phase == "carried", "repeated E at the pile does not add another charge")
	_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and state.military_cannon_phase == "loaded", "E at the cannon directly loads the carried charge")
	var first_shot_hits := state.military_cannon_hits.size()
	_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and station._cannon_in_flight and state.military_cannon_phase == "loaded" and state.military_cannon_hits.size() == first_shot_hits, "next E launches one visible shot without scoring before impact")
	var in_flight_sprite := _find_sprite_with_texture(station._cannonball_visual, "station_cannonball.png")
	var ground_shadow := station._cannonball_visual.get_node_or_null("GroundShadow") as Polygon2D if station._cannonball_visual != null else null
	_check(ground_shadow != null and ground_shadow.polygon.size() >= 4, "cannonball includes a separate ground shadow")
	var in_flight_start := in_flight_sprite.global_position if in_flight_sprite != null else Vector2.ZERO
	for tick in 5:
		await get_tree().physics_frame
	var in_flight_moved := in_flight_sprite != null and is_instance_valid(in_flight_sprite) and in_flight_sprite.global_position.distance_to(in_flight_start) > 0.1
	_check(in_flight_sprite != null and in_flight_sprite.texture.get_width() == 6 and in_flight_sprite.texture.get_height() == 6 and in_flight_moved and state.military_cannon_hits.size() == first_shot_hits and state.military_cannon_phase == "loaded", "cannonball moves while its loaded shot remains unscored")
	_check(_interact_service_with_key(station, ui, "station_tnt_pile", KEY_E, false) and state.military_cannon_phase == "loaded" and station._cannon_in_flight and _count_sprites_with_texture(station, "station_cannonball.png") == 1, "pile input cannot add a charge during flight")
	_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and station._cannon_in_flight and _count_sprites_with_texture(station, "station_cannonball.png") == 1, "cannon accepts only one ball in flight")
	_check(_quick_save(game), "F5 saves while a cannonball is in flight")
	var flight_save = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(flight_save is Dictionary and bool(flight_save.get("military_cannon_round_active", false)) and flight_save.get("military_cannon_phase") == "loaded" and flight_save.get("military_cannon_hits", []).is_empty(), "in-flight save keeps a loaded shot with no recorded hit")
	_quick_load(game)
	await get_tree().process_frame
	station = game.world as StationWorld
	_check(station != null and state.military_stage == "cannon" and state.military_cannon_round_active and state.military_cannon_phase == "loaded" and state.military_cannon_hits.is_empty() and not station._cannon_in_flight and station._cannonball_visual == null, "F9 restores the loaded shot without rebuilding a ball in flight")
	for tick in 100:
		await get_tree().physics_frame
	_check(state.military_cannon_hits.is_empty() and state.military_cannon_phase == "loaded", "the replaced world's old impact does not score after reload")
	_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and station._cannon_in_flight and state.military_cannon_phase == "loaded", "E fires the saved loaded shot without taking another charge")
	var first_impact := await _watch_cannon_impact(station, first_shot_hits)
	var first_arc_deviation := float(first_impact.get("arc_deviation", 0.0))
	_check(bool(first_impact.get("observed_ball", false)) and bool(first_impact.get("moved", false)) and first_arc_deviation > 2.0, "cannonball follows a visible curved arc (deviation=%.2f, observed=%s, moved=%s)" % [first_arc_deviation, first_impact.get("observed_ball", false), first_impact.get("moved", false)])
	_check(bool(first_impact.get("burst_before_score", false)) and state.military_cannon_hits == [state.MILITARY_CANNON_TARGETS[0]] and state.military_cannon_phase == "empty", "impact burst is visible before the first target is scored")
	_check(_quick_save(game), "F5 saves the first cannon impact")
	_quick_load(game)
	await get_tree().process_frame
	station = game.world as StationWorld
	_check(station != null and state.military_stage == "cannon" and state.military_cannon_hits == [state.MILITARY_CANNON_TARGETS[0]] and state.military_cannon_round_active and state.military_cannon_phase == "empty", "F9 restores the first distinct cannon hit without duplicating it")
	for shot in range(1, 3):
		if state.military_stage != "cannon":
			break
		_check(_interact_service_with_key(station, ui, "station_tnt_pile", KEY_E, false) and state.military_cannon_phase == "carried", "E takes the next game charge for target %d" % (shot + 1))
		_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and state.military_cannon_phase == "loaded", "E loads the next shot for target %d" % (shot + 1))
		var hits_before := state.military_cannon_hits.size()
		_check(_interact_service_with_key(station, ui, "station_cannon", KEY_E, false) and station._cannon_in_flight and state.military_cannon_hits.size() == hits_before, "target %d stays unscored while its ball is in flight" % (shot + 1))
		var impact := await _watch_cannon_impact(station, hits_before)
		_check(bool(impact.get("burst_before_score", false)) and state.military_cannon_hits.size() == shot + 1 and state.military_cannon_hits[-1] == state.MILITARY_CANNON_TARGETS[shot], "impact burst precedes score for distinct target %d" % (shot + 1))
	_check(state.military_stage == "trap" and state.military_cannon_hits == state.MILITARY_CANNON_TARGETS and not state.military_cannon_round_active and station._cannon_targets.is_empty(), "third impact clears the cannon round and advances to trap practice")

func _watch_cannon_impact(station: StationWorld, hits_before: int) -> Dictionary:
	var state := GameState
	var ball := station._cannonball_visual
	var ball_sprite := _find_sprite_with_texture(ball, "station_cannonball.png")
	var expected_target := station._cannon_targets[hits_before].global_position if hits_before < station._cannon_targets.size() else Vector2.ZERO
	var samples: Array[Vector2] = []
	var observed_ball := false
	var burst_before_score := false
	for tick in 150:
		if state.military_cannon_hits.size() > hits_before:
			break
		if ball_sprite != null and is_instance_valid(ball_sprite):
			observed_ball = true
			samples.append(ball_sprite.global_position)
		for visual in station._cannon_impact_visuals:
			if is_instance_valid(visual) and not visual.is_queued_for_deletion():
				burst_before_score = true
		await get_tree().physics_frame
	var arc_deviation := 0.0
	if samples.size() >= 3 and expected_target != Vector2.ZERO:
		for point in samples:
			arc_deviation = maxf(arc_deviation, _distance_to_segment(point, samples[0], expected_target))
	var moved := samples.size() >= 2 and samples[0].distance_to(samples[-1]) > 2.0
	return {
		"observed_ball": observed_ball,
		"moved": moved,
		"arc_deviation": arc_deviation,
		"burst_before_score": burst_before_score,
		"recorded_hit": state.military_cannon_hits.size() > hits_before,
	}

func _check_trap(game: Node, ui: GameUI, station: StationWorld) -> void:
	station = game.world as StationWorld
	var state := GameState
	var equipment_before: Dictionary = state.equipment.duplicate(true)
	for marker in 3:
		if state.military_stage != "trap":
			break
		_check(_interact_service_with_key(station, ui, "station_trap_pad", KEY_E, true), "E opens the trap practice menu for marker %d" % (marker + 1))
		var start_button := _find_button(ui.modal_content, "Use training station")
		_check(start_button != null and not start_button.disabled, "trap marker %d can start the next round" % (marker + 1))
		if start_button == null or start_button.disabled:
			ui.close_modal()
			break
		start_button.pressed.emit()
		var expected_item_count := 1
		_check(state.military_trap_round_active and int(state.inventory.get("practice_mine", 0)) == expected_item_count and not state.military_trap_equipped and state.military_trap_mine_position.is_empty(), "trap round %d issues one held practice mine" % (marker + 1))
		var item := GameData.item("practice_mine")
		_check(item.get("kind") == "training" and int(item.get("buy", -1)) == 0 and int(item.get("sell", -1)) == 0 and bool(item.get("station_only", false)) and not state.equipment.values().has("practice_mine"), "practice mine is a station-only training item outside equipment slots")
		var dummy: StationMovingTarget = station._trap_dummy
		_check(dummy != null and not dummy.shootable and dummy.moving, "trap round %d starts a moving, non-shootable dummy" % (marker + 1))
		if dummy == null:
			break
		var lane_start := station._trap_lane_start
		var lane_end := station._trap_lane_end
		var lane := lane_end - lane_start
		var lane_direction := Vector2.RIGHT
		if absf(lane.x) >= absf(lane.y):
			lane_direction = Vector2.RIGHT if lane.x >= 0.0 else Vector2.LEFT
		else:
			lane_direction = Vector2.DOWN if lane.y >= 0.0 else Vector2.UP
		var lane_midpoint := (lane_start + lane_end) * 0.5
		var lane_side := Vector2(-lane_direction.y, lane_direction.x)
		if marker == 0:
			_press_ui_key(ui, KEY_I)
			var equip_button := _find_button(ui.modal_content, "Equip")
			_check(ui.modal_overlay.visible and ui._active_service_id == "inventory" and equip_button != null and not equip_button.disabled, "I shows an enabled Equip button for the practice mine")
			var dummy_before_modal := dummy.global_position
			for tick in 8:
				await get_tree().physics_frame
			_check(dummy.global_position.distance_to(dummy_before_modal) < 0.01 and state.military_trap_progress == marker, "moving dummy pauses while the inventory modal is open")
			if equip_button != null:
				equip_button.pressed.emit()
			_check(state.military_trap_equipped and state.equipment == equipment_before and station.player._held_mine_icon.visible and station.player._held_mine_icon.texture.get_width() == 8 and station.player._held_mine_icon.texture.get_height() == 8, "equipping the mine shows its small held icon without changing equipment slots")
			ui.close_modal()
			var invalid_position := Vector2.ZERO
			for offset in [24.0, -24.0, 40.0, -40.0]:
				var candidate: Vector2 = lane_midpoint + lane_side * float(offset) - lane_direction * 24.0
				if station.tiled_loader.is_walkable_position(candidate):
					invalid_position = candidate
					break
			_check(invalid_position != Vector2.ZERO, "trap lane has a walkable position outside the dummy path")
			if invalid_position != Vector2.ZERO:
				station.player.global_position = invalid_position
				station.player.facing = lane_direction
				station.player._attack_cooldown = 0.0
				var previous_notice := ui.notification_label.text
				_press_player_key(station.player, KEY_SPACE)
				_check(state.military_trap_equipped and int(state.inventory.get("practice_mine", 0)) == 1 and state.military_trap_mine_position.is_empty() and ui.notification_label.text != previous_notice, "invalid placement keeps the equipped item in inventory")
				_check(ui.notification_label.text.to_lower().contains("lane"), "invalid placement explains that the mine belongs on the dummy lane")
			var place_player := lane_midpoint - lane_direction * 24.0
			_check(station.tiled_loader.is_walkable_position(place_player), "player can stand beside the dummy lane")
			station.player.global_position = place_player
			station.player.facing = lane_direction
			station.player._attack_cooldown = 0.0
			_press_player_key(station.player, KEY_SPACE)
			_check(state.military_trap_mine_placed() and int(state.inventory.get("practice_mine", 0)) == 0 and not state.military_trap_equipped and not station.player._held_mine_icon.visible and state.equipment == equipment_before, "Space places the item and leaves equipment unchanged")
			var mine_position := Vector2(float(state.military_trap_mine_position[0]), float(state.military_trap_mine_position[1])) if state.military_trap_mine_placed() else Vector2.ZERO
			_check(mine_position != Vector2.ZERO and _distance_to_segment(mine_position, lane_start, lane_end) <= 12.0 and _count_sprites_with_texture(station, "station_practice_mine.png") == 1, "one visible practice prop sits on the dummy path")
			var mine_sprite := _find_sprite_with_texture(station, "station_practice_mine.png")
			_check(mine_sprite != null and mine_sprite.texture.get_width() == 12 and mine_sprite.texture.get_height() == 9, "placed practice prop uses its small game sprite")
			_check(_quick_save(game), "F5 saves a placed practice mine")
			var placed_save = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
			var saved_mine: Array = placed_save.get("military_trap_mine_position", []) if placed_save is Dictionary else []
			_check(placed_save is Dictionary and bool(placed_save.get("military_trap_round_active", false)) and _point_arrays_match(saved_mine, state.military_trap_mine_position) and int(placed_save.get("inventory", {}).get("practice_mine", 0)) == 0, "saved trap round has one placed mine and no inventory copy")
			_quick_load(game)
			await get_tree().process_frame
			station = game.world as StationWorld
			_check(station != null and state.military_trap_round_active and state.military_trap_mine_placed() and _point_arrays_match(state.military_trap_mine_position, [mine_position.x, mine_position.y]) and int(state.inventory.get("practice_mine", 0)) == 0 and state.military_trap_progress == marker, "F9 restores the active round and placed-mine position")
			if station == null:
				return
			_check(station._trap_dummy != null and station._trap_dummy.moving and _count_sprites_with_texture(station, "station_practice_mine.png") == 1, "F9 rebuilds the moving dummy and one visible placed mine")
			_check(_interact_service_with_key(station, ui, "station_trap_pad", KEY_E, true), "trap pad opens its active-round menu")
			var restart_button := _find_button(ui.modal_content, "Restart practice")
			_check(restart_button != null and not restart_button.disabled, "active trap round offers Restart practice")
			if restart_button != null:
				restart_button.pressed.emit()
			await get_tree().process_frame
			_check(state.military_trap_round_active and not state.military_trap_mine_placed() and state.military_trap_mine_position.is_empty() and int(state.inventory.get("practice_mine", 0)) == 1 and not state.military_trap_equipped and _count_sprites_with_texture(station, "station_practice_mine.png") == 0, "restart returns the placed mine once and clears its sprite")
			_check(_interact_service_with_key(station, ui, "station_trap_pad", KEY_E, true), "held mine can reopen the restart menu")
			var held_restart := _find_button(ui.modal_content, "Restart practice")
			if held_restart != null:
				held_restart.pressed.emit()
			_check(int(state.inventory.get("practice_mine", 0)) == 1 and not state.military_trap_mine_placed(), "restarting with a held mine does not add a second copy")
			station = game.world as StationWorld
			dummy = station._trap_dummy
			lane_start = station._trap_lane_start
			lane_end = station._trap_lane_end
			lane = lane_end - lane_start
			lane_direction = Vector2.RIGHT if absf(lane.x) >= absf(lane.y) else Vector2.DOWN
			if lane.x < 0.0 or lane.y < 0.0:
				lane_direction = -lane_direction
			lane_midpoint = (lane_start + lane_end) * 0.5
			_press_ui_key(ui, KEY_I)
			equip_button = _find_button(ui.modal_content, "Equip")
			if equip_button != null:
				equip_button.pressed.emit()
			ui.close_modal()
		else:
			_press_ui_key(ui, KEY_I)
			var next_equip_button := _find_button(ui.modal_content, "Equip")
			_check(next_equip_button != null and not next_equip_button.disabled, "I offers Equip for trap marker %d" % (marker + 1))
			if next_equip_button != null:
				next_equip_button.pressed.emit()
			ui.close_modal()
			_check(state.military_trap_equipped and int(state.inventory.get("practice_mine", 0)) == 1 and state.equipment == equipment_before, "equipping marker %d keeps the item out of weapon slots" % (marker + 1))
			lane_start = station._trap_lane_start
			lane_end = station._trap_lane_end
			lane = lane_end - lane_start
			lane_direction = Vector2.RIGHT if absf(lane.x) >= absf(lane.y) else Vector2.DOWN
			if lane.x < 0.0 or lane.y < 0.0:
				lane_direction = -lane_direction
			lane_midpoint = (lane_start + lane_end) * 0.5
		station.player.global_position = lane_midpoint - lane_direction * 24.0
		station.player.facing = lane_direction
		station.player._attack_cooldown = 0.0
		_press_player_key(station.player, KEY_SPACE)
		_check(state.military_trap_mine_placed() and int(state.inventory.get("practice_mine", 0)) == 0 and not state.military_trap_equipped, "Space places the equipped mine for marker %d" % (marker + 1))
		var target_position := Vector2(float(state.military_trap_mine_position[0]), float(state.military_trap_mine_position[1])) if state.military_trap_mine_placed() else Vector2.ZERO
		_check(target_position != Vector2.ZERO and _distance_to_segment(target_position, lane_start, lane_end) <= 12.0, "marker %d practice prop is within the dummy path" % (marker + 1))
		for tick in 240:
			if state.military_trap_progress > marker:
				break
			await get_tree().physics_frame
		_check(state.military_trap_progress == marker + 1 and not state.military_trap_round_active and not state.military_trap_mine_placed() and state.military_trap_mine_position.is_empty() and int(state.inventory.get("practice_mine", 0)) == 0, "dummy crosses the placed mine to finish marker %d" % (marker + 1))
		_check(_count_sprites_with_texture(station, "station_practice_mine.png") == 0 and not station.player._held_mine_icon.visible, "triggered practice item is removed from the world and player")
		if marker == 0:
			_check(_quick_save(game), "F5 saves completed first trap marker")
			_quick_load(game)
			await get_tree().process_frame
			station = game.world as StationWorld
			_check(station != null and state.military_trap_progress == 1 and state.military_stage == "trap" and not state.military_trap_round_active, "F9 keeps one completed trap step without issuing another item")
	_check(state.military_stage == "sleep" and state.military_trap_progress == 3, "third physical dummy crossing unlocks the bunk")

func _check_migration() -> void:
	var state := GameState
	state.remember_player_position(state.player_position)
	if not state.save_game():
		_check(false, "graduated save exists for old-schema migration fixture")
		return
	var present = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	if not present is Dictionary:
		_check(false, "graduated save has valid JSON")
		return
	var old: Dictionary = present.duplicate(true)
	old["schema"] = 8
	old["current_planet"] = "brudet"
	old["player_position"] = old["planet_positions"]["brudet"].duplicate()
	old["inventory"].erase("military_uniform")
	old["planet_positions"].erase("station")
	for field in ["current_area", "military_barracks_position", "military_stage", "military_storage", "military_stored_equipment", "military_meal_credits", "military_cannon_hits", "military_trap_progress"]:
		old.erase(field)
	_check(state._valid_save(old), "pre-station schema-eight save still validates with only two planets")
	var fixture := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	_check(fixture != null, "legacy save fixture is written only in the isolated data directory")
	if fixture == null:
		return
	fixture.store_string(JSON.stringify(old))
	fixture.close()
	_check(state.load_game() and state.current_planet == "brudet" and state.military_stage == "none" and state.planet_positions["station"] == [state.MILITARY_ARRIVAL.x, state.MILITARY_ARRIVAL.y], "schema-eight migration adds a fresh station without changing the Brudet save")
	_check(state.save_game(), "migrated save writes the current schema")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(migrated is Dictionary and int(migrated.get("schema", -1)) == state.SAVE_SCHEMA and migrated.get("military_stage") == "none", "migration writes current schema and does not invent graduation")

func _check_station_ambience(station: StationWorld) -> void:
	var soldiers: Array[Node2D] = []
	for actor in station.actors_root.get_children():
		var actor_script := actor.get_script() as Script
		if actor_script != null and actor_script.resource_path.ends_with("station_soldier.gd"):
			soldiers.append(actor as Node2D)
	_check(soldiers.size() >= 12 and soldiers.size() <= 20, "ambient soldiers spawn outdoors in the expected group size")
	if soldiers.is_empty():
		return
	var soldier := soldiers[0]
	var stops: Array = soldier.get("_stops")
	var stops_reachable := stops.size() >= 2
	for stop_value in stops:
		var stop: Vector2 = stop_value
		var route := station.tiled_loader.get_walk_path(soldier.global_position, stop)
		stops_reachable = stops_reachable and stop.distance_to(soldier.global_position) <= 220.0 and station.tiled_loader.is_walkable_position(stop) and not route.is_empty() and route[-1].distance_to(stop) <= 17.0
	_check(stops_reachable, "ambient soldier has short, walkable routes between outdoor stops")
	var start := soldier.global_position
	var stop_index := int(soldier.get("_stop_index"))
	soldier.set("_stop_index", (stop_index + 1) % stops.size())
	soldier.set("_wait", 0.0)
	for tick in 60:
		await get_tree().physics_frame
	_check(soldier.global_position.distance_to(start) > 3.0, "ambient soldier moves along an outdoor route")
	var heard: Array[String] = []
	var capture_dialogue := func(message: String) -> void: heard.append(message)
	GameState.notification_requested.connect(capture_dialogue)
	soldier.call("interact", station.player)
	GameState.notification_requested.disconnect(capture_dialogue)
	_check(heard.size() == 1 and heard[0].begins_with("Station soldier:"), "ambient soldier responds with dialogue")

func _check_visual_station(station: StationWorld) -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(StationWorld.STATION_MAP))
	_check(raw is Dictionary, "station Tiled map is readable")
	if not raw is Dictionary:
		return
	var width := int(raw.get("width", 0))
	var height := int(raw.get("height", 0))
	var ground_layer: Dictionary = {}
	var void_layer: Dictionary = {}
	var rim_layer: Dictionary = {}
	var sky_layer: Dictionary = {}
	for layer in raw.get("layers", []):
		match String(layer.get("name", "")):
			"Station Ground": ground_layer = layer
			"Station Void": void_layer = layer
			"Station Walls": rim_layer = layer
			"Station Sky": sky_layer = layer
	_check(width == 120 and height == 80 and void_layer.get("data", []).size() == width * height, "station has a full-size Tiled void layer around its platform")
	if void_layer.is_empty() or width < 30 or height < 30:
		return
	var tiles: Array = void_layer["data"]
	var ground_tiles: Array = ground_layer.get("data", [])
	var left_depths: Dictionary = {}
	var right_depths: Dictionary = {}
	var void_ids: Dictionary = {}
	var void_count := 0
	var clear_space := 0
	var inner_rows := 0
	var blocked_void := true
	for y in range(5, height - 5):
		var left_depth := 0
		while left_depth < width and int(tiles[y * width + left_depth]) != 0:
			left_depth += 1
		var right_depth := 0
		while right_depth < width and int(tiles[y * width + width - 1 - right_depth]) != 0:
			right_depth += 1
		if left_depth > 0 and right_depth > 0 and left_depth + right_depth < width:
			left_depths[left_depth] = true
			right_depths[right_depth] = true
			inner_rows += 1
			if y % 12 == 0:
				blocked_void = blocked_void and not station.tiled_loader.is_walkable_position(Vector2(8, y * 16 + 8))
	for index in tiles.size():
		var id := int(tiles[index])
		if id != 0:
			void_count += 1
			void_ids[id] = true
			if index < ground_tiles.size() and int(ground_tiles[index]) == 0:
				clear_space += 1
	_check(void_count >= 1000 and clear_space >= 1000 and void_ids.size() >= 3 and inner_rows >= 40 and left_depths.size() >= 4 and right_depths.size() >= 4, "space and shore tiles replace ground around a nonrectangular platform with several distinct edge depths")
	_check(blocked_void and station.tiled_loader.is_walkable_position(GameState.MILITARY_ARRIVAL), "space tiles block movement while the platform remains walkable")
	var loader := station.tiled_loader
	_check(loader.is_walkable_position(Vector2(56, 288)) and not loader.is_walkable_position(Vector2(56, 160)) and loader.is_walkable_position(Vector2(1856, 800)) and not loader.is_walkable_position(Vector2(1856, 560)), "west dock and east wing project into space at different depths")
	_check(loader.is_walkable_position(Vector2(928, 1216)) and not loader.is_walkable_position(Vector2(928, 1256)) and not loader.is_walkable_position(Vector2(8, 8)), "southern platform ends at blocked space rather than a rectangular map edge")
	var rim_tiles: Array = rim_layer.get("data", [])
	var west_rim_id := int(rim_tiles[18 * width + 2]) if rim_tiles.size() == width * height else 0
	_check(west_rim_id >= 38 and west_rim_id <= 45 and not loader.is_walkable_position(Vector2(40, 296)), "lit rim tile at the west dock is visible and blocks movement")
	var visible_planet := false
	for sky_tile in sky_layer.get("data", []):
		if int(sky_tile) == 130:
			visible_planet = true
			break
	_check(visible_planet, "space backdrop includes a visible planet")
	var cannon_object: Dictionary = {}
	var station_objects: Dictionary = {}
	var barracks_count := 0
	var map_soldier_count := 0
	var warship_names := ["warship_escort", "warship_scout"]
	for layer in raw.get("layers", []):
		if String(layer.get("type", "")) != "objectgroup":
			continue
		for obj in layer.get("objects", []):
			var name := String(obj.get("name", ""))
			station_objects[name] = obj
			if name == "station_cannon":
				cannon_object = obj
			elif name == "station_barracks" or name in ["barracks_b", "barracks_c", "barracks_d", "barracks_e", "barracks_f", "barracks_g", "barracks_h", "barracks_i", "barracks_j"]:
				barracks_count += 1
			elif name == "station_soldier":
				map_soldier_count += 1
	_check(barracks_count == 10, "station map has ten exterior barracks buildings")
	var barracks_interactive := 0
	var barracks_nodes_valid := true
	for name in ["station_barracks", "barracks_b", "barracks_c", "barracks_d", "barracks_e", "barracks_f", "barracks_g", "barracks_h", "barracks_i", "barracks_j"]:
		var building := loader._object_root.get_node_or_null(name)
		if building is WorldService and building.service_id == "station_barracks":
			barracks_interactive += 1
			barracks_nodes_valid = barracks_nodes_valid and name == "station_barracks"
		else:
			barracks_nodes_valid = barracks_nodes_valid and building != null and not building.is_in_group("interactable")
	_check(barracks_interactive == 1 and barracks_nodes_valid, "only the assigned barracks has an interactive entrance")
	var cannon := _service(station, "station_cannon")
	_check(int(cannon_object.get("width", 0)) == 80 and int(cannon_object.get("height", 0)) == 40 and cannon != null, "Tiled cannon uses its widened block-built size and remains interactive")
	var cannon_sprite := _find_sprite_with_texture(cannon, "station_cannon.png")
	var cannon_texture := cannon_sprite.texture if cannon_sprite != null else null
	_check(cannon_texture != null and cannon_texture.get_width() == 80 and cannon_texture.get_height() == 40, "training cannon sprite matches its 80-by-40 map footprint")
	if cannon_texture != null:
		var image := cannon_texture.get_image()
		var colors: Dictionary = {}
		var filled_bands := 0
		for band in 3:
			var filled := false
			for y in range(band * image.get_height() / 3, (band + 1) * image.get_height() / 3):
				for x in image.get_width():
					var pixel := image.get_pixel(x, y)
					if pixel.a > 0.5:
						filled = true
						colors[pixel.to_html(false)] = true
			if filled:
				filled_bands += 1
		_check(filled_bands == 3 and colors.size() >= 5, "block-built cannon has visible multicolored parts across all three height bands")
	var transport := _service(station, "station_ship")
	var transport_sprite := _find_sprite_with_texture(transport, "spaceship.png")
	_check(transport != null and transport_sprite != null and transport_sprite.texture.get_width() == 112 and transport_sprite.texture.get_height() == 56 and transport.global_position.x < 600.0, "west landing has one interactive 112-by-56 regular transport")
	var warships_valid := true
	for name in warship_names:
		var object: Dictionary = station_objects.get(name, {})
		var node := loader._object_root.get_node_or_null(name)
		var expected_texture := "warship_escort.png" if name == "warship_escort" else "warship_scout.png"
		var sprite := _find_sprite_with_texture(node, expected_texture)
		var object_size := Vector2(float(object.get("width", 0)), float(object.get("height", 0)))
		var expected_size := Vector2(192, 112) if name == "warship_escort" else Vector2(96, 56)
		var expected_scale := expected_size / Vector2(96, 56)
		var bounds := Rect2(float(object.get("x", 0)), float(object.get("y", 0)) - object_size.y, object_size.x, object_size.y)
		warships_valid = warships_valid and not object.is_empty() and object_size == expected_size and bounds.position.x >= 1280.0 and bounds.end.x <= 1712.0 and bounds.position.y >= 256.0 and bounds.end.y <= 390.0 and node != null and not node is WorldService and not node.is_in_group("interactable") and sprite != null and sprite.texture.get_width() == 96 and sprite.texture.get_height() == 56 and sprite.scale.is_equal_approx(expected_scale)
	_check(warships_valid, "escort flagship is twice the scout size, and both warships stay static on the northeast apron")
	var apron_accessible := 0
	for y in range(256, 390, 16):
		for x in range(1280, 1712, 16):
			var candidate := Vector2(x + 8, y + 8)
			if loader.is_walkable_position(candidate):
				var route := loader.get_walk_path(GameState.MILITARY_ARRIVAL, candidate)
				if not route.is_empty() and route[-1].distance_to(candidate) <= 17.0:
					apron_accessible += 1
	_check(apron_accessible >= 12, "walkable routes reach open ground around the warship apron")
	_check(map_soldier_count >= 12 and map_soldier_count <= 20, "map places twelve to twenty exterior soldiers")
	var recruits := 0
	var staff := 0
	var soldiers := 0
	var people_have_military_sprites := true
	for actor in station.actors_root.get_children():
		var actor_script := actor.get_script() as Script
		var is_soldier := actor_script != null and actor_script.resource_path.ends_with("station_soldier.gd")
		if actor is StationRecruit:
			recruits += 1
		elif actor is StationStaff:
			staff += 1
		elif is_soldier:
			soldiers += 1
		else:
			continue
		var sprite := _find_first_sprite(actor)
		people_have_military_sprites = people_have_military_sprites and sprite != null and sprite.texture.get_width() == 16 and sprite.texture.get_height() == 24 and sprite.texture.resource_path.contains("/space_military_base/")
	for name in ["instructor_guard_a", "instructor_guard_b"]:
		var guard := _find_sprite_with_texture(loader._object_root.get_node_or_null(name), "station_guard.png")
		people_have_military_sprites = people_have_military_sprites and guard != null and guard.texture.get_width() == 16 and guard.texture.get_height() == 24
	_check(recruits == 9 and staff == 2 and soldiers == map_soldier_count and people_have_military_sprites, "recruits, staff, guards and ambient soldiers use military 16-by-24 sprites")
	var cannon_start := _service(station, "station_cannon_start")
	var flag_sprite := _find_sprite_with_texture(cannon_start, "station_cannon_flag.png")
	_check(cannon_start != null and flag_sprite != null and flag_sprite.texture.get_width() == 24 and flag_sprite.texture.get_height() == 28, "separate cannon range flag marks where the drill starts")

func _service(world: Node, id: String) -> WorldService:
	if world == null or world.tiled_loader == null:
		return null
	for fixture in world.tiled_loader._object_root.get_children():
		if fixture is WorldService and fixture.service_id == id:
			return fixture
	return null

func _fixture_counts(world: Node) -> Dictionary:
	var result := {}
	for fixture in world.tiled_loader._object_root.get_children():
		if fixture is WorldService:
			result[fixture.service_id] = int(result.get(fixture.service_id, 0)) + 1
	return result

func _near_service(world: Node, fixture: WorldService) -> Vector2:
	if fixture == null:
		return Vector2.ZERO
	var at := fixture.get_interaction_position()
	for offset in [Vector2(0, 11), Vector2(0, -11), Vector2(14, 0), Vector2(-14, 0), Vector2(0, 22), Vector2(23, 0), Vector2(-23, 0)]:
		var candidate: Vector2 = at + offset
		if world.tiled_loader.is_walkable_position(candidate) and candidate.distance_to(at) <= Player.INTERACTION_DISTANCE:
			return candidate
	return at + Vector2(0, 11)

func _service_routes(world: Node, ids: Array[String]) -> bool:
	for id in ids:
		var fixture := _service(world, id)
		if fixture == null:
			return false
		var entrance := _near_service(world, fixture)
		var route: PackedVector2Array = world.tiled_loader.get_walk_path(GameState.MILITARY_ARRIVAL, entrance)
		if not world.tiled_loader.is_walkable_position(entrance) or route.is_empty() or route[-1].distance_to(entrance) > 17.0:
			return false
	return true

func _interact_service(world: Node, ui: GameUI, id: String) -> bool:
	if world == null:
		return false
	ui.close_modal()
	var fixture := _service(world, id)
	if fixture == null:
		return false
	world.player.global_position = _near_service(world, fixture)
	world.player._update_nearest_interactable()
	if world.player._current_interactable != fixture:
		return false
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	world.player._unhandled_input(event)
	return ui.modal_overlay.visible and ui._active_service_id == id

func _interact_service_with_key(world: Node, ui: GameUI, id: String, key: Key, opens_modal: bool) -> bool:
	if world == null:
		return false
	ui.close_modal()
	var fixture := _service(world, id)
	if fixture == null:
		return false
	world.player.global_position = _near_service(world, fixture)
	world.player._update_nearest_interactable()
	if world.player._current_interactable != fixture:
		return false
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	world.player._unhandled_input(event)
	if opens_modal:
		return ui.modal_overlay.visible and ui._active_service_id == id
	return not ui.modal_overlay.visible

func _press_ui_key(ui: GameUI, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	ui._input(event)

func _press_player_key(player: Player, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	player._unhandled_input(event)

func _press_service(game: Node, ui: GameUI, id: String, label: String) -> bool:
	if not _interact_service(game.world, ui, id):
		_check(false, "E can open %s at a walkable entrance" % id)
		return false
	var button := _find_button(ui.modal_content, label)
	if button == null or button.disabled:
		_check(false, "%s offers an enabled %s action" % [id, label])
		ui.close_modal()
		return false
	button.pressed.emit()
	return true

func _find_sprite_with_texture(node: Node, suffix: String) -> Sprite2D:
	if node == null or node.is_queued_for_deletion():
		return null
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and sprite.texture.resource_path.ends_with(suffix):
			return sprite
	for child in node.get_children():
		var found := _find_sprite_with_texture(child, suffix)
		if found != null:
			return found
	return null

func _find_first_sprite(node: Node) -> Sprite2D:
	if node == null:
		return null
	if node is Sprite2D and (node as Sprite2D).texture != null:
		return node as Sprite2D
	for child in node.get_children():
		var found := _find_first_sprite(child)
		if found != null:
			return found
	return null

func _count_sprites_with_texture(node: Node, suffix: String) -> int:
	if node == null or node.is_queued_for_deletion():
		return 0
	var count := 0
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and sprite.texture.resource_path.ends_with(suffix):
			count += 1
	for child in node.get_children():
		count += _count_sprites_with_texture(child, suffix)
	return count

func _quick_save(game: Node) -> bool:
	var event := InputEventAction.new()
	event.action = "quick_save"
	event.pressed = true
	game._unhandled_input(event)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	return saved is Dictionary and int(saved.get("schema", -1)) == GameState.SAVE_SCHEMA and GameState._valid_save(saved)

func _quick_load(game: Node) -> void:
	var event := InputEventAction.new()
	event.action = "quick_load"
	event.pressed = true
	game._unhandled_input(event)

func _point_arrays_match(first: Array, second: Array) -> bool:
	if first.size() < 2 or second.size() < 2:
		return false
	var first_point := Vector2(float(first[0]), float(first[1]))
	var second_point := Vector2(float(second[0]), float(second[1]))
	return first_point.distance_to(second_point) < 0.01

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.01:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

func _move_toward(position: Vector2, target: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	var offset := target - position
	if offset.length() < 13.0:
		return
	if absf(offset.x) >= absf(offset.y) and absf(offset.x) >= 9.0:
		Input.action_press("move_right" if offset.x > 0.0 else "move_left")
	elif absf(offset.y) >= 9.0:
		Input.action_press("move_down" if offset.y > 0.0 else "move_up")

func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "station_sprint"]:
		Input.action_release(action)

func _find_button(node: Node, label: String) -> Button:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button and child.text.contains(label):
			return child
		var nested := _find_button(child, label)
		if nested != null:
			return nested
	return null

func _has_text(node: Node, text: String) -> bool:
	for child in node.get_children():
		if child is Label and child.text.contains(text):
			return true
		if _has_text(child, text):
			return true
	return false

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		printerr("FAIL ", description)

func _finish(game: Node) -> void:
	_release_movement()
	print("Station smoke: %d checks, %d failures" % [checks, failures])
	if game != null:
		remove_child(game)
		game.free()
	get_tree().quit(0 if failures == 0 else 1)
