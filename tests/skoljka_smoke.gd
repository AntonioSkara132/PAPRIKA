extends Node

var checks := 0
var failures := 0
var game: Node
var ui: GameUI
var world: Node
var screenshot_dir := ""
var combat_walking := false
var combat_attacks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	screenshot_dir = OS.get_environment("SKOLJKA_SCREENSHOT_DIR")
	var data_home := OS.get_environment("XDG_DATA_HOME")
	var save_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	if data_home.is_empty() or not save_path.begins_with(data_home + "/"):
		_check(false, "Skoljka smoke requires an isolated XDG_DATA_HOME")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	ui = game.get_node_or_null("GameUI") as GameUI
	_check(ui != null, "main scene creates its UI")
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	game._on_story_travel_requested("skoljka")
	await get_tree().process_frame
	_check(GameState.current_planet == "skoljka", "the story transition reaches Skoljka after the Rudnik passage flag")
	world = game.world
	_check(world != null and world.tiled_loader.map_loaded, "the Skoljka map loads in the game")
	if world == null:
		_finish()
		return
	_check(world.markers.size() >= 50, "named Tiled markers load")
	_check(world.player.global_position.distance_to(GameState.SKOLJKA_ARRIVAL) < 32.0, "arrival is on the dock")
	_check(world.davor != null, "Davor travels with the player")
	_check(world.story_people.has("port_officer") and world.story_people.has("company_clerk"), "map story characters become interactable")
	_check(world.story_people.size() >= 20 and (world.story_people["worker_0"] as Node).display_name == "Niko" and (world.story_people["seeker"] as Node).display_name == "Mira", "the city has named residents and an identifiable missing worker")
	_check(world.tiled_loader.has_group("housing_leak") and world.tiled_loader.group_blocked("housing_leak"), "the housing flood starts blocked")
	var hatch_cells: Array[Vector2i] = world.tiled_loader.group_cells("hatch_west")
	var hatch_probe := Vector2(hatch_cells[0] * 16) + Vector2(8, 8)
	_check(not world.tiled_loader.is_walkable_position(hatch_probe), "a closed hatch blocks walking navigation")
	world._set_group("hatch_west", false)
	_check(world.tiled_loader.is_walkable_position(hatch_probe), "opening the hatch updates walking navigation")
	world._set_group("hatch_west", true)
	_check(world.story_status_text().contains("port officer"), "arrival objective points to the port officer")
	_check(ui.location_label.text == "SKOLJKA DOCK", "the location title identifies the arrival dock")
	_end_scene()
	var runner := world.story_people["citizen_3"] as Node2D
	var runner_start: Vector2 = runner.global_position
	for frame in range(210):
		await get_tree().physics_frame
	_check(runner.global_position.distance_to(runner_start) > 12.0, "a resident walks a visible route through the plaza")
	var city_routes_ok := true
	for index in range(8):
		var citizen: Node = world.story_people["citizen_%d" % index]
		city_routes_ok = city_routes_ok and citizen._stops.size() > 1
		for stop in range(1, citizen._stops.size()):
			city_routes_ok = city_routes_ok and world.tiled_loader.is_walkable_position(citizen._stops[stop]) and not world.tiled_loader.get_walk_path(citizen._stops[stop - 1], citizen._stops[stop]).is_empty()
	_check(city_routes_ok, "all eight citizens have walkable local routines")
	await _capture("dock")

	_check(_approach_and_press("lift_top"), "the arrival lift can be reached and used with E")
	_end_scene()
	_check(world.story_step() == 0 and world.player.global_position.y < 360.0, "the lift waits for the port officer before descending")
	var port_officer := world.story_people["port_officer"] as Node2D
	var port_path: PackedVector2Array = _path_to_actor(port_officer)
	_check(not port_path.is_empty(), "the port officer can be reached from the lift")
	if not port_path.is_empty():
		_check(await _walk_path(port_path) and _press_actor(port_officer), "the player walks up and speaks to the port officer with E")
	_end_scene()
	_check(world._has_flag(world.FLAGS[0]), "port conversation completes the arrival step")
	var lift_path: PackedVector2Array = _path_to_interaction("lift_top")
	_check(not lift_path.is_empty(), "the lift remains reachable after speaking to the port officer")
	if not lift_path.is_empty():
		_check(await _walk_path(lift_path) and _press_interaction("lift_top"), "the player descends to the plaza using E")
	_check(world.davor.order == "follow" and world.davor.global_position.distance_to(world.player.global_position) < 64.0, "Davor takes the pressure lift down with the player")
	await _capture("plaza")
	_check(ui.location_label.text == "SKOLJKA", "the location title changes at the plaza")
	_check(world.story_status_text().contains("Find the leak"), "the plaza objective updates after using the lift")
	var library := world.tiled_loader._object_root.get_node_or_null("skoljka_library") as WorldService
	_check(library != null and library.service_id == "skoljka_library", "the upper city has a usable Skoljka Library")
	if library != null:
		var library_path: PackedVector2Array = _path_to_actor(library)
		_check(not library_path.is_empty(), "the library entrance is reachable from the plaza")
		if not library_path.is_empty():
			_check(await _walk_path(library_path) and _press_actor(library), "the player walks into the library and reads it with E")
			_check(ui._active_service_id == "skoljka_library" and _has_text(ui.modal_content, "Destruction of Block") and _has_text(ui.modal_content, "Blockovia") and _has_text(ui.modal_content, "Otpornik"), "the library tells how Engineeria began on Otpornik")
			_check(_has_text(ui.modal_content, "underwater city") and _has_text(ui.modal_content, "refuge") and _has_text(ui.modal_content, "Elektrika") and _has_text(ui.modal_content, "hackers"), "the library explains Skoljka's refuge and Elektrika joining")
			_check(_has_text(ui.modal_content, "man-made planet") and _has_text(ui.modal_content, "capital") and _has_text(ui.modal_content, "Rudnik") and _has_text(ui.modal_content, "five planets"), "Iskra is the fourth planet and Rudnik later brings the total to five")
			var heads_ok := _has_text(ui.modal_content, "Engineering Board") and _has_text(ui.modal_content, "short-term Heads") and _has_text(ui.modal_content, "Head of Nation")
			for area in ["Technology", "Architecture", "Navy", "Demographics", "Finance", "Defense"]:
				heads_ok = heads_ok and _has_text(ui.modal_content, area)
			_check(heads_ok, "the library names the Engineering Board and all seven leadership roles")
			await _capture("library")
			ui.close_modal()
			_check(not world.tiled_loader.get_walk_path(world.player.global_position, world.marker("housing_safe")).is_empty(), "the library visit leaves the housing route open")
	var food_stall := world.tiled_loader._object_root.get_node_or_null("skoljka_food") as WorldService
	var cloth_stall := world.tiled_loader._object_root.get_node_or_null("skoljka_clothing") as WorldService
	_check(food_stall != null and cloth_stall != null and food_stall.service_id == "skoljka_food" and cloth_stall.service_id == "skoljka_clothing", "both Skoljka market stalls are usable services")
	GameState.add_gold(130)
	if food_stall != null:
		_check(_approach_service(food_stall), "the player reaches and opens Tala's food stall with E")
		_check(ui._active_service_id == "skoljka_food" and _find_button(ui.modal_content, "Kelp Broth") != null and _find_button(ui.modal_content, "Shellfish Stew") != null, "Tala sells Skoljka meals")
		await _capture("food_menu")
		var buy_broth := _find_button(ui.modal_content, "Kelp Broth —")
		if buy_broth != null:
			buy_broth.pressed.emit()
		_check(int(GameState.inventory.get("kelp_broth", 0)) == 1 and ui._active_service_id == "skoljka_food", "buying broth updates inventory and keeps the menu open")
		var buy_stew := _find_button(ui.modal_content, "Shellfish Stew —")
		if buy_stew != null:
			buy_stew.pressed.emit()
		_check(int(GameState.inventory.get("shellfish_stew", 0)) == 1, "the food stall sells shellfish stew")
		ui.close_modal()
		var injured_health: int = maxi(1, GameState.max_health - 15)
		GameState.health = injured_health
		var earlier_food := {}
		for food_id in ["bread", "stew", "rye_bread", "berry_pie", "smoked_fish", "olive_bread", "fish_stew", "citrus"]:
			earlier_food[food_id] = int(GameState.inventory.get(food_id, 0))
			GameState.inventory[food_id] = 0
		var eat := InputEventAction.new()
		eat.action = "use_food"
		eat.pressed = true
		world.player._unhandled_input(eat)
		_check(GameState.health == mini(GameState.max_health, injured_health + 13) and int(GameState.inventory.get("kelp_broth", 0)) == 0, "H consumes kelp broth and restores health")
		for food_id in earlier_food:
			GameState.inventory[food_id] = earlier_food[food_id]
		GameState.restore_health()
	if cloth_stall != null:
		_check(_approach_service(cloth_stall), "the player reaches and opens Lumi's clothing stall with E")
		_check(ui._active_service_id == "skoljka_clothing" and _find_button(ui.modal_content, "Buy another Sea-Glass Tunic") != null and _find_button(ui.modal_content, "Buy another Coral Tunic") != null, "Lumi sells both Skoljka outfit colors")
		var buy_outfit := _find_button(ui.modal_content, "Buy another Sea-Glass Tunic")
		if buy_outfit != null:
			buy_outfit.pressed.emit()
		var equip_outfit := _find_button(ui.modal_content, "Equip Sea-Glass Tunic")
		if equip_outfit != null:
			equip_outfit.pressed.emit()
		_check(GameState.equipment.get("clothing", "") == "sea_glass_tunic" and world.player._sprite.texture == load("res://assets/art/player_sea_glass.png"), "buying and equipping sea-glass clothes changes the player sprite")
		var buy_coral := _find_button(ui.modal_content, "Buy another Coral Tunic")
		if buy_coral != null:
			buy_coral.pressed.emit()
		var equip_coral := _find_button(ui.modal_content, "Equip Coral Tunic")
		if equip_coral != null:
			equip_coral.pressed.emit()
		_check(GameState.equipment.get("clothing", "") == "coral_tunic" and world.player._sprite.texture == load("res://assets/art/player_coral.png"), "coral clothes can be bought and worn")
		_check(_find_button(ui.modal_content, "Buy Sea-Glass Cloth") != null, "Lumi also sells sea-glass cloth")
		await _capture("clothing_menu")
		ui.close_modal()
	world.capture_player_position()
	_check(GameState.save_game(), "Skoljka food and clothing can be saved")
	_quick_load()
	_check(GameState.equipment.get("clothing", "") == "coral_tunic" and int(GameState.inventory.get("shellfish_stew", 0)) == 1 and world.player._sprite.texture == load("res://assets/art/player_coral.png"), "loading preserves purchased food and the visible coral outfit")
	await _capture("shops")
	var housing_start: Vector2 = world.marker("housing_safe")
	_check(not world.tiled_loader.get_walk_path(world.player.global_position, housing_start).is_empty(), "the housing quarter is reachable from the lift")
	world.player.global_position = housing_start
	var lever_path: PackedVector2Array = _path_to_interaction("housing_lever")
	_check(not lever_path.is_empty(), "the lever has a reachable interaction position")
	if not lever_path.is_empty():
		_check(await _walk_path(lever_path), "the player can walk from housing to the lever")
	await _capture("housing_flood")
	_check(_press_interaction("housing_lever"), "E at the lever closes the inner door")
	_end_scene()
	_check(world.tiled_loader.group_blocked("housing_inner"), "the inner door seals before repairing the leak")
	world.capture_player_position()
	_check(GameState.save_game(), "the sealed housing door can be saved")
	world.apply_loaded_state()
	_check(world.tiled_loader.group_blocked("housing_inner") and not world._interactions["housing_lever"].visible, "loading keeps the door sealed and the used lever hidden")
	var leak_path: PackedVector2Array = _path_to_interaction("leak_point")
	_check(not leak_path.is_empty(), "the seal remains reachable with the inner door closed and the pod flooded")
	if not leak_path.is_empty():
		_check(await _walk_path(leak_path), "the player can walk to the damaged seal")
		_check(_press_interaction("leak_point"), "E at the damaged seal repairs the leak")
	_end_scene()
	_check(world._has_flag(world.FLAGS[1]) and not world.tiled_loader.group_blocked("housing_leak"), "the leak is stopped after the door sequence")
	_check(world.story_status_text().contains("PUMP WORKS") and world.story_status_text().contains("four valves"), "repairing housing directs the player to the pumps")
	_check((world.story_people["resident_0"] as Node)._stops.size() > 1, "the housing residents resume walking when the pod is dry")
	world._handle_interaction("resident_0")
	var housing_line: String = ui.scene_text_label.text
	_end_scene()
	world._handle_interaction("resident_1")
	_check(ui.scene_text_label.text != housing_line and ui.scene_speaker_label.text == "Besa", "neighbors in the repaired pod have distinct conversations")
	_end_scene()
	var ina := world.story_people["resident_2"] as Node2D
	var ina_path: PackedVector2Array = _path_to_actor(ina)
	_check(not ina_path.is_empty(), "Ina can be reached in the repaired housing pod")
	if not ina_path.is_empty():
		_check(await _walk_path(ina_path), "the player can walk over to Ina")
		for frame in range(100):
			await get_tree().physics_frame
		_check(world.davor.order == "follow" and world.davor.global_position.distance_to(world.player.global_position) < 80.0, "Davor is near enough for Ina to notice him")
		_check(_press_actor(ina), "the player speaks to Ina with E")
		_check(ui.scene_speaker_label.text == "Ina" and ui.scene_text_label.text.contains("face seems familiar"), "Ina finds Davor familiar without explaining why")
		_check(world._has_flag(world.DAVOR_RECOGNIZED_FLAG), "Ina's recognition is recorded once")
		_end_scene()
		world.capture_player_position()
		_check(GameState.save_game(), "Ina's recognition can be saved")
		_quick_load()
		await get_tree().process_frame
		_check(world._has_flag(world.DAVOR_RECOGNIZED_FLAG), "loading preserves Ina's recognition")
		world._handle_interaction("resident_2")
		_check(ui.scene_speaker_label.text == "Ina" and ui.scene_text_label.text.contains("pump still makes that knock"), "Ina returns to her usual conversation afterward")
		_end_scene()
	_check(not world.tiled_loader.group_blocked("housing_inner") and not world.tiled_loader.get_walk_path(world.player.global_position, housing_start).is_empty(), "the player can leave the pod after repairing it")
	await _capture("housing_repaired")
	for index in range(4):
		_check(_approach_and_press("valve_%d" % index), "valve %d can be reached and turned with E" % (index + 1))
		_end_scene()
	_check(_approach_and_press("pressure_log"), "the pressure log can be inspected from the pump rooms")
	_check(ui.scene_text_label.text.contains("before the flood alarm"), "the pressure log gives a clue before the company records are found")
	_end_scene()
	_check(_approach_and_press("pump_console"), "the pump console can be reached and operated with E")
	_end_scene()
	_check(world._has_flag(world.FLAGS[2]), "ordered valves restart the pumps")
	_check(world.story_status_text().contains("RELAY HALL"), "starting the pumps directs the player to the relay")
	_check(_approach_and_press("relay_console"), "the relay console is reachable from the pump rooms")
	_end_scene()
	for index in range(5):
		_check(_approach_and_press("rack_%d" % index), "relay rack %d can be traced with E" % (index + 1))
		_end_scene()
	_check(world._has_flag(world.FLAGS[3]), "relay trace records the sabotage")
	_check(world.story_status_text().contains("LOWER WORKS") and world.story_status_text().contains("sections A and B"), "tracing the relay directs the player to drain both sections")
	_check(_approach_and_press("lower_a_console"), "section A can be reached and drained")
	_end_scene()
	_check(_approach_and_press("lower_b_console"), "section B can be reached and drained")
	_end_scene()
	_check(world._has_flag("skoljka_lower_a_drained") and world._has_flag("skoljka_lower_b_drained") and not world._has_flag(world.FLAGS[4]), "draining both sections opens the way but does not count as a rescue")
	_check(world.story_status_text().contains("Niko") and world.story_status_text().contains("west airlock"), "the objective names the workers and their shelter")
	var niko := world.story_people["worker_0"] as Node2D
	var shelter_path: PackedVector2Array = _path_to_actor(niko)
	_check(not shelter_path.is_empty(), "the drained section leads to the four workers")
	if not shelter_path.is_empty():
		_check(await _walk_path(shelter_path) and _press_actor(niko), "the player walks to Niko and begins the rescue with E")
	_end_scene()
	_check(world._escort_active and not world._has_flag(world.FLAGS[4]), "the workers follow before the rescue is recorded")
	await _capture("workers_escort")
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "an escort in progress can be saved and loaded")
	world.apply_loaded_state()
	_check(not world._escort_active and not world._has_flag(world.FLAGS[4]) and world._has_flag("skoljka_lower_a_drained") and world._has_flag("skoljka_lower_b_drained") and niko.global_position.distance_to(niko.home_position) < 2.0, "loading restarts the escort at the shelter without reflooding the route")
	_check(_press_actor(niko), "the player can restart the rescue after loading")
	_end_scene()
	world.player._invulnerability = 0.0
	world.player.take_damage(999)
	_check(not world._escort_active and not world._has_flag(world.FLAGS[4]) and niko.global_position.distance_to(niko.home_position) < 2.0, "being downed returns the workers to the shelter for another attempt")
	var retry_path: PackedVector2Array = _path_to_actor(niko)
	_check(not retry_path.is_empty() and await _walk_path(retry_path) and _press_actor(niko), "the player can return and restart the rescue after respawning")
	_end_scene()
	var safety_path: PackedVector2Array = world.tiled_loader.get_walk_path(world.player.global_position, world.marker("workers_safe"))
	_check(not safety_path.is_empty() and await _walk_path(safety_path), "the player can escort the workers back to the junction")
	for frame in range(1800):
		if world._has_flag(world.FLAGS[4]):
			break
		await get_tree().physics_frame
	_check(world._has_flag(world.FLAGS[4]) and world._workers_near_safety() == 4, "all four workers physically reach safety before the rescue completes")
	_end_scene()
	world._handle_interaction("seeker")
	_check(ui.scene_speaker_label.text == "Mira" and ui.scene_text_label.text.contains("Niko made it out"), "Niko's family responds to the rescue")
	_end_scene()
	world.apply_loaded_state()
	_check(world._has_flag(world.FLAGS[4]) and (world.story_people["worker_0"] as Node2D).global_position.distance_to(world.marker("niko_reunion")) < 24.0, "completed or older rescue saves keep Niko and the other workers safe")
	_check(world.story_status_text().contains("west airlock") and world.story_status_text().contains("diving suit"), "after the rescue the objective points to the diving suit")
	await _capture("lower_works")
	_check(_approach_and_press("air_0"), "the lower-works air station can be reached")
	_end_scene()
	world._air = world.AIR_MAX
	world._step_air(2.0)
	_check(world.air_fraction() < 1.0, "air drains in the lower works")
	world._handle_interaction("air_0")
	_end_scene()
	_check(is_equal_approx(world.air_fraction(), 1.0), "air stations refill the reserve")
	var armor_before := String(GameState.equipment.get("armor", ""))
	GameState.equipment["armor"] = "iron_armor"
	_check(GameState.damage_player(2, true) == 2, "air damage bypasses equipped armor")
	GameState.equipment["armor"] = armor_before
	_check(_approach_and_press("airlock_west"), "the west airlock can be reached and activated with E")
	_check(world.has_diving_suit() and world.player.damage_scale < 1.0 and world.player._costume_texture_path == "res://assets/art/skoljka/diving_suit.png", "the diving suit changes appearance and reduces damage")
	_check(world.player._sprite.texture == load("res://assets/art/skoljka/diving_suit.png"), "the diving suit temporarily covers the purchased outfit")
	_check(world.story_status_text().contains("SEABED"), "the objective changes when the suit opens the seabed hatch")
	_end_scene()
	await _capture("seabed")
	_check(ui.location_label.text == "SEABED", "the location title changes outside the hull")
	world.capture_player_position()
	_check(GameState.save_game(), "a west seabed save can be written")
	_quick_load()
	_check(not world.has_diving_suit() and world.player.global_position.distance_to(world.marker("airlock_west_stand")) < 24.0 and world.tiled_loader.group_blocked("hatch_west"), "loading on the west seabed returns to the safe airlock")
	_check(_approach_and_press("airlock_west"), "the west diving suit can be worn again after loading")
	_end_scene()
	_check(world.has_diving_suit() and world.player.global_position.y > 1600.0, "the intake remains accessible after reloading")
	world._air = world.AIR_MAX
	world._step_air(2.0)
	_check(world.air_fraction() < 1.0 and world.air_fraction() > 0.9, "the suit supplies a slower-draining air reserve")
	_check(ui.job_label.text.contains("AIR %d%%" % roundi(world.air_fraction() * 100.0)), "the air percentage on the HUD changes with the reserve")
	world._refill_air()
	_end_scene()
	_check(ui.job_label.text.contains("AIR 100%"), "refilling air updates the HUD immediately")
	_check(_approach_and_press("intake"), "the suited player can reach and repair the seabed intake")
	_end_scene()
	_check(world._has_flag(world.FLAGS[5]), "the suited player repairs the seabed intake")
	_check(_approach_and_press("evidence"), "the company part can be reached and collected")
	_end_scene()
	_check(int(GameState.inventory.get("skoljka_company_part", 0)) == 1, "the player collects the company part")
	_check(world.story_status_text().contains("COMPANY DEPOT"), "collecting the evidence directs the player to the depot")
	_check(_approach_and_press("seabed_west_hatch"), "the west hatch can be reached for the return trip")
	_check(not world.has_diving_suit() and world.tiled_loader.group_blocked("hatch_west") and world.davor.order == "follow", "returning through the hatch removes the suit and Davor resumes following")
	_check(world.player._sprite.texture == load("res://assets/art/player_coral.png"), "removing the diving suit restores the coral outfit")
	_check(_approach_and_press("airlock_east"), "the optional east airlock can be reached and opened")
	_end_scene()
	_check(world.has_diving_suit() and world._active_airlock == "east" and world.davor.order == "hold", "Davor waits inside the east airlock")
	_check(_approach_and_press("frame_window_view"), "the sealed frame can be viewed from the east seabed")
	_end_scene()
	world.capture_player_position()
	_check(GameState.save_game(), "an east seabed save can be written")
	_check(game._switch_world("skoljka", false), "a fresh Skoljka world can load the east seabed save")
	world = game.world
	_check(not world.has_diving_suit() and world.player.global_position.distance_to(world.marker("airlock_east_stand")) < 24.0 and world.tiled_loader.group_blocked("hatch_east"), "loading on the east seabed returns to the safe airlock")
	_check(ui.location_label.text == "LOWER WORKS" and not ui.job_label.text.contains("AIR "), "a fresh-world load immediately shows the interior location and objective")
	await _capture("east_airlock")
	world.capture_player_position()
	_check(GameState.save_game(), "the depot choices can be retried from a save")
	_check(_approach_and_press("depot_front_outside") and _choose_scene("Sneak in"), "the depot offers a playable sneaking choice")
	_end_scene()
	_check(not world._company_crew_alive() and not world._depot_alerted and world._depot_watchers.size() == 4, "sneaking in shows the crew watch posts without starting a fight")
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "an unfinished depot infiltration can be saved and loaded")
	world.apply_loaded_state()
	_check(world.player.global_position.distance_to(world.marker("depot_front_outside")) < 24.0 and world.tiled_loader.group_blocked("depot_front") and world._depot_watchers.is_empty(), "loading inside the depot returns outside for a fresh choice")
	_check(_approach_and_press("depot_front_outside") and _choose_scene("Sneak in"), "the sneak route can be chosen after loading inside")
	_end_scene()
	await _capture("depot_sneak")
	var patrols := PackedVector2Array()
	for index in range(4):
		patrols.append(world.marker("crew_patrol_%d" % index))
	var stealth_path: PackedVector2Array = world.tiled_loader.get_walk_path_avoiding(world.player.global_position, world.marker("depot_records"), patrols, 64.0)
	_check(not stealth_path.is_empty(), "the repair records have a path outside the crew's sight")
	if not stealth_path.is_empty():
		_check(await _walk_path(stealth_path), "the player can walk the concealed depot route")
		_check(not world._depot_alerted and not world._company_crew_alive(), "reaching the records unseen avoids a fight")
		_check(_press_interaction("depot_records"), "E retrieves the records after an undetected approach")
		_end_scene()
		_check(world._has_flag(world.FLAGS[6]) and world._depot_watchers.is_empty(), "undetected entry completes the depot step and clears the watch posts")
	_check(GameState.load_game(), "the depot save restores the alternate sneak route")
	world.apply_loaded_state()
	_check(_approach_and_press("depot_front_outside") and _choose_scene("Sneak in"), "the sneak choice can be attempted again")
	_end_scene()
	world.player.global_position = world.marker("crew_patrol_0")
	await get_tree().physics_frame
	_check(world._company_crew_alive() and world._depot_alerted and world._depot_watchers.is_empty(), "entering a marked patrol area triggers a crew fight")
	await _capture("depot_alert")
	_end_scene()
	world._take_orders()
	_end_scene()
	_check(not world._has_flag(world.FLAGS[6]), "the crew blocks access to repair records until defeated")
	for actor in world.actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("story_skoljka_depot_"):
			actor.take_damage(999)
	_check(_approach_and_press("depot_records"), "the cleared records aisle can be reached and searched")
	_end_scene()
	_check(world._has_flag(world.FLAGS[6]) and int(GameState.inventory.get("skoljka_repair_orders", 0)) == 1, "the sneak route yields repair records once")
	_check(GameState.load_game(), "the save restores the unused depot choice")
	world.apply_loaded_state()
	_check(world.story_step() == 6 and world.tiled_loader.group_blocked("depot_front"), "reloading requires a new depot entry choice")
	_check(_approach_and_press("depot_front_outside") and _choose_scene("Use the work order"), "the depot offers a playable work-order choice")
	_end_scene()
	_check(int(GameState.inventory.get("skoljka_forged_work_order", 0)) == 1 and not world._company_crew_alive(), "the work order avoids a crew fight")
	await _capture("depot_talk")
	_check(_approach_and_press("depot_records"), "the work-order route reaches the repair records")
	_end_scene()
	_check(world._has_flag(world.FLAGS[6]) and int(GameState.inventory.get("skoljka_repair_orders", 0)) == 1, "repair records are collected once")
	_check(world.story_status_text().contains("Martin") and world.story_status_text().contains("depot"), "the orders warn that Martin's spies may be outside")
	_check(world._has_flag(world.FLAGS[2]), "the first pump repair remains completed")
	GameState.add_item("iron_sword")
	GameState.add_item("iron_armor")
	GameState.equip_item("iron_sword")
	GameState.equip_item("iron_armor")
	GameState.add_item("shellfish_stew", 8)
	GameState.restore_health()
	world.capture_player_position()
	_check(GameState.save_game(), "the pre-attack state can be saved")
	var exit_path: PackedVector2Array = world.tiled_loader.get_walk_path(world.player.global_position, world.marker("depot_front_outside"))
	_check(not exit_path.is_empty() and await _walk_path(exit_path), "the player walks out of the depot to the ambush")
	for frame in range(5):
		await get_tree().physics_frame
	_check(world._assassin_active and _story_crew_count("story_skoljka_assassin") == 1 and not world._has_flag(world.ASSASSINATION_FLAG), "the warned attacker appears once without marking the encounter completed")
	_check(world._assassin.definition.get("name") == "Martin's Assassin" and ui.job_label.text.contains("Martin"), "the attempted killer is identified as Martin's spy, not company staff")
	await _capture("assassin")
	world.capture_player_position()
	_check(GameState.save_game(), "the active ambush can be saved")
	_quick_load()
	await get_tree().process_frame
	_check(not world._assassin_active and _story_crew_count("story_skoljka_assassin") == 0 and world.player.global_position.distance_to(world.marker("depot_front_inside")) < 24.0, "loading an active ambush returns to a safe depot exit checkpoint")
	world.start_climax()
	_check(world._climax_time < 0.0, "the unresolved attack cannot be skipped at the relay console")
	exit_path = world.tiled_loader.get_walk_path(world.player.global_position, world.marker("depot_front_outside"))
	_check(await _walk_path(exit_path), "the player can retry the ambush after loading")
	await get_tree().physics_frame
	world.player._invulnerability = 0.0
	world.player.take_damage(999)
	await get_tree().process_frame
	_check(not world._assassin_active and not world._has_flag(world.ASSASSINATION_FLAG) and _story_crew_count("story_skoljka_assassin") == 0, "being downed resets the attacker without losing the orders")
	_check(int(GameState.inventory.get("skoljka_repair_orders", 0)) == 1, "the evidence survives the attack retry")
	exit_path = world.tiled_loader.get_walk_path(world.player.global_position, world.marker("depot_front_outside"))
	_check(await _walk_path(exit_path), "the player reaches the attacker again after respawn")
	var escape_path: PackedVector2Array = world.tiled_loader.get_walk_path(world.player.global_position, world.marker("plaza_centre"))
	_check(not escape_path.is_empty() and await _walk_path(escape_path), "the player can escape by walking to the plaza")
	for frame in range(5):
		await get_tree().physics_frame
	_check(world._has_flag(world.ASSASSINATION_FLAG) and not world._assassin_active, "reaching the plaza resolves the attack without requiring a kill")
	_check(GameState.load_game(), "the active-ambush save restores the combat alternative")
	world.apply_loaded_state()
	await get_tree().process_frame
	GameState.restore_health()
	exit_path = world.tiled_loader.get_walk_path(world.player.global_position, world.marker("depot_front_outside"))
	combat_walking = true
	_check(await _walk_path(exit_path), "the combat route reaches the attacker")
	_check(await _fight_crew("story_skoljka_assassin"), "the player and Davor can defeat the attacker through ordinary combat")
	await get_tree().process_frame
	_check(world._has_flag(world.ASSASSINATION_FLAG), "defeating the attacker records the one-time outcome")
	world.capture_player_position()
	_check(GameState.save_game(), "the resolved attempt can be saved")
	_quick_load()
	await get_tree().process_frame
	_check(world._has_flag(world.ASSASSINATION_FLAG) and not world._assassin_active, "loading does not repeat a completed attempt")
	_check(world.davor.order == "follow", "Davor follows the player before the final encounter")
	_check(_approach_and_press("pump_console"), "pump control explains the company's new cutoff boxes")
	_check(ui.scene_text_label.text.contains("remote command") and ui.scene_text_label.text.contains("pumps"), "the pumpmaster explains that a remote command could stop the repaired pumps")
	ui.advance_scene()
	_check(ui.scene_speaker_label.text == "Davor" and ui.scene_text_label.text.contains("four rescued workers"), "Davor explains why he stays with the workers")
	_end_scene()
	_check(_davor_guards_workers(), "Davor holds a walkable post beside the rescued workers")
	_check(world._guard_phase and _story_crew_count("story_skoljka_climax_") == 8, "the final encounter has exactly eight guards")
	var placements_ok := true
	for chamber in range(4):
		placements_ok = placements_ok and _story_crew_count("story_skoljka_climax_%d_" % chamber) == 2
		for slot in range(2):
			placements_ok = placements_ok and world.tiled_loader.is_walkable_position(world.marker("crew_climax_%d_%d" % [chamber, slot]))
	_check(placements_ok, "each pump chamber has two guards on walkable positions")
	var identities_ok := true
	for actor in world.actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("story_skoljka_climax_"):
			identities_ok = identities_ok and actor.definition.get("name") == "Martin's Spy"
	_check(identities_ok and GameData.enemy("company_crew").get("name") == "Company Crew", "only final-mission attackers are Martin's spies; depot crew remain company staff")
	world._disconnect_cutoff(0)
	_check(world._cutoffs_done.is_empty(), "a guarded cutoff cannot be disconnected")
	world.start_climax()
	_check(world._climax_time < 0.0, "the countdown cannot start until all four cutoffs are secured")
	world._turn_valve(0)
	_check(world._cutoffs_done.is_empty() and world._has_flag(world.FLAGS[2]), "old valves neither repeat the pump repair nor count as cutoff progress")
	world.capture_player_position()
	_check(GameState.save_game(), "the guard encounter can be saved")
	_quick_load()
	await get_tree().process_frame
	_check(not world._guard_phase and _story_crew_count("story_skoljka_climax_") == 0 and world._cutoffs_done.is_empty(), "loading clears temporary guards and allows a fresh confrontation")
	_check(world.davor.order == "follow", "loading a guard encounter restores Davor's follow order")
	_check(_approach_and_press("pump_console"), "pump control restarts the guard encounter")
	_end_scene()
	_check(_davor_guards_workers(), "Davor returns to the workers on a fresh attempt")
	world.player._invulnerability = 0.0
	world.player.take_damage(999)
	await get_tree().process_frame
	_check(not world._guard_phase and _story_crew_count("story_skoljka_climax_") == 0 and world._has_flag(world.FLAGS[2]), "being downed resets the guards but keeps the original pump repair")
	_check(world.davor.order == "follow", "respawning during the guard encounter restores Davor's follow order")
	GameState.restore_health()
	_check(_approach_and_press("pump_console"), "the guard encounter restarts after respawn")
	_end_scene()
	_check(_davor_guards_workers(), "Davor stays with the workers after the encounter restarts")
	var guard_route_ok := true
	var combat_start_attacks := combat_attacks
	for chamber in range(4):
		var cutoff_path: PackedVector2Array = _path_to_interaction("cutoff_%d" % chamber)
		if cutoff_path.is_empty() or not await _walk_path(cutoff_path) or not await _fight_crew("story_skoljka_climax_%d_" % chamber):
			guard_route_ok = false
			break
		cutoff_path = _path_to_interaction("cutoff_%d" % chamber)
		if cutoff_path.is_empty() or not await _walk_path(cutoff_path) or not _press_interaction("cutoff_%d" % chamber):
			guard_route_ok = false
			break
		_check(world._cutoffs_done.has(chamber), "chamber %d can be cleared and its cutoff disconnected" % (chamber + 1))
		_check(_davor_guards_workers(), "Davor stays with the workers during chamber %d combat" % (chamber + 1))
		await _capture("cutoff_%d" % chamber)
	_check(guard_route_ok and world._cutoffs_done.size() == 4 and combat_attacks > combat_start_attacks, "real movement and player attacks clear all four guarded chambers without Davor")
	combat_walking = false
	if not guard_route_ok:
		_finish()
		return
	_check(world._climax_time < 0.0 and not world.tiled_loader.group_blocked("lower_a") and not world.tiled_loader.group_blocked("lower_b"), "combat uses no countdown and the rescued workers' route stays dry")
	_check(_approach_and_press("relay_console") and _choose_scene("Start reconnecting"), "the relay countdown starts only after an explicit warning and choice")
	_check(world._climax_time > 0.0 and ui.job_label.text.contains("seconds left"), "the relay HUD displays the running countdown")
	_check(_davor_guards_workers(), "Davor stays with the workers during the timed relay")
	world._climax_time = 0.01
	for frame in range(5):
		await get_tree().physics_frame
	_check(world._climax_time < 0.0 and not world._guard_phase and world._cutoffs_done.is_empty() and not world._has_flag(world.FLAGS[7]), "expiry resets the final confrontation without completing it")
	_check(world.davor.order == "follow" and (world.story_people["worker_0"] as Node2D).global_position.distance_to(world.marker("niko_reunion")) < 16.0, "an expired relay restores Davor and Niko to their usual positions")
	_check(world._has_flag(world.FLAGS[2]) and not world.tiled_loader.group_blocked("lower_a"), "a failed relay attempt does not undo the pumps or the rescue")
	# The complete combat route was exercised above; these resets target save behavior.
	await _clear_guard_fixture()
	_check(_approach_and_press("relay_console") and _choose_scene("Start reconnecting"), "the timer can restart after recovering the cutoff boxes")
	_check(_approach_and_press("rack_0"), "the first reconnectable rack is reachable before saving")
	world.capture_player_position()
	_check(GameState.save_game(), "an active relay repair can be saved")
	_quick_load()
	await get_tree().process_frame
	_check(world._climax_time < 0.0 and world._relay_done.is_empty() and world._cutoffs_done.is_empty() and not world._guard_phase, "loading resets partial relay work and temporary cutoff progress")
	_check(world.davor.order == "follow", "loading a timed relay restores Davor's follow order")
	await _clear_guard_fixture()
	_check(_approach_and_press("relay_console") and _choose_scene("Start reconnecting"), "the repair restarts after loading")
	world.player._invulnerability = 0.0
	world.player.take_damage(999)
	await get_tree().process_frame
	_check(world._climax_time < 0.0 and world._relay_done.is_empty() and world._cutoffs_done.is_empty() and not world._guard_phase, "being downed resets the timer and unfinished relay work")
	_check(world.davor.order == "follow", "respawning during the relay restores Davor's follow order")
	GameState.restore_health()
	await _clear_guard_fixture()
	_check(_approach_and_press("relay_console") and _choose_scene("Start reconnecting"), "the final relay repair can restart after respawn")
	_check(_davor_guards_workers(), "Davor guards the workers through the final relay attempt")
	await _capture("climax")
	var climax_route_ok := true
	var relay_elapsed := 0.0
	for index in range(5):
		var rack_name := "rack_%d" % index
		var rack_path: PackedVector2Array = _path_to_interaction(rack_name)
		if rack_path.is_empty() or not await _walk_path(rack_path):
			climax_route_ok = false
			break
		relay_elapsed = world.CLIMAX_SECONDS - world._climax_time
		if not _press_interaction(rack_name):
			climax_route_ok = false
			break
		_end_scene()
	print("FINAL RELAY seconds=", relay_elapsed)
	_check(climax_route_ok and world._has_flag(world.FLAGS[7]), "walking and reconnecting five racks completes the finale without turning pump valves again")
	_check(world.davor.order == "follow" and (world.story_people["worker_0"] as Node2D).global_position.distance_to(world.marker("niko_reunion")) < 16.0, "completing the relay restores Davor and Niko to their usual positions")
	_check(world._has_flag(world.FLAGS[2]) and not world.tiled_loader.group_blocked("lower_a"), "the original repair and rescue remain complete after the finale")
	# Completed older saves have no assassination flag; never replay a new ambush there.
	GameState.defeated_persistent_enemies.erase(world.ASSASSINATION_FLAG)
	world.apply_loaded_state()
	await get_tree().process_frame
	_check(world.story_step() == 8 and not world._assassin_active and _story_crew_count("story_skoljka_") == 0, "older completed-finale saves proceed to the council without new fights")
	_check(world.story_status_text().contains("COUNCIL"), "the objective sends the evidence to the council")
	_check(_approach_and_press("council_spot"), "the city council can be reached for the final decision")
	_end_scene()
	_check(world._has_flag(world.FLAGS[8]), "the council expels the company after the climax")
	_check(world.story_status_text().contains("expelled"), "the final objective records the aftermath")
	var council_gold: int = GameState.gold
	_check(_approach_and_press("council_spot"), "the council can be visited after its decision")
	_end_scene()
	_check(GameState.gold == council_gold, "revisiting the council cannot collect the reward twice")
	_check(GameState.save_game(), "Skoljka progress saves at the current schema")
	world.apply_loaded_state()
	_check(world.tiled_loader.is_walkable_position(world.player.global_position), "loading resolves to a walkable position")
	_check(world.davor != null and is_instance_valid(world.davor), "Davor remains in the loaded world")
	_check(world._interactions.has("lift_top") and world._interactions.has("lift_bottom") and world._interactions["lift_top"] != world._interactions["lift_bottom"], "both pressure lift stops have distinct registered interactions")
	var return_path := _path_to_interaction("lift_bottom")
	_check(not return_path.is_empty(), "the lower pressure lift can be reached from the council")
	if not return_path.is_empty():
		_check(await _walk_path(return_path) and _press_interaction("lift_bottom"), "the player walks to the lower lift and presses E to return to the dock")
	_check(world.player.global_position.distance_to(world.marker("lift_top")) < 24.0, "the lower lift returns the player to the upper stop")
	_check(world.davor.order == "follow" and world.davor.global_position.distance_to(world.player.global_position) < 64.0 and world.tiled_loader.is_walkable_position(world.davor.global_position), "Davor rides the pressure lift back to walkable dock ground")
	var departure_path := _path_to_actor(world.story_people["port_officer"])
	_check(not departure_path.is_empty(), "the port officer is reachable after taking the lift up")
	if not departure_path.is_empty():
		_check(await _walk_path(departure_path) and _press_actor(world.story_people["port_officer"]), "the player walks from the upper lift to the port officer and presses E")
	_check(ui._scene_choices.size() == 2 and String(ui._scene_choices[0]["label"]).contains("Iskra"), "the port conversation offers the ship after the council ending")
	_check(_choose_scene("Board the ship to Iskra"), "the player selects boarding through the dialogue button")
	_end_scene()
	await get_tree().process_frame
	world = game.world
	_check(GameState.current_planet == "iskra" and world is IskraWorld and world.tiled_loader.map_loaded, "the lift-to-officer route boards the ship and loads Iskra")
	_check(world.davor != null and world.davor.order == "follow" and world.davor.global_position.distance_to(world.player.global_position) < 64.0, "Davor arrives on Iskra beside the player after the return journey")
	_finish()

func _combat_input() -> void:
	if GameState.health < 12:
		GameState.use_food("shellfish_stew")
	var target: Enemy
	var distance := 31.0
	for actor in world.actors_root.get_children():
		if actor is Enemy and actor.health > 0 and not actor.is_queued_for_deletion():
			var current: float = actor.global_position.distance_to(world.player.global_position)
			if current < distance:
				target = actor
				distance = current
	if target != null and world.player._attack_cooldown <= 0.0:
		world.player.facing = (target.global_position - world.player.global_position).normalized()
		var event := InputEventAction.new()
		event.action = "attack"
		event.pressed = true
		world.player._unhandled_input(event)
		combat_attacks += 1

func _fight_crew(prefix: String) -> bool:
	for frame in range(1800):
		if _story_crew_count(prefix) == 0:
			await get_tree().process_frame
			return true
		_combat_input()
		var nearest: Enemy
		var nearest_distance := INF
		for actor in world.actors_root.get_children():
			if actor is Enemy and actor.health > 0 and not actor.is_queued_for_deletion() and String(actor.persistent_id).begins_with(prefix):
				var distance: float = world.player.global_position.distance_to(actor.global_position)
				if distance < nearest_distance:
					nearest = actor
					nearest_distance = distance
		if nearest != null and nearest_distance > float(GameState.weapon_definition().get("reach", 24.0)) - 3.0 and nearest_distance < 42.0:
			var direction: Vector2 = (nearest.global_position - world.player.global_position).normalized()
			var approach: Vector2 = world.player.global_position + direction * 5.0
			if world.tiled_loader.is_walkable_position(approach):
				Input.action_press("move_right" if absf(direction.x) > absf(direction.y) and direction.x > 0.0 else "move_left" if absf(direction.x) > absf(direction.y) else "move_down" if direction.y > 0.0 else "move_up")
		await get_tree().physics_frame
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
	return false

func _clear_guard_fixture() -> void:
	_check(_approach_and_press("pump_console"), "the retry fixture reaches pump control")
	_end_scene()
	for actor in world.actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("story_skoljka_climax_"):
			actor.take_damage(999)
	await get_tree().process_frame
	for chamber in range(4):
		_check(_approach_and_press("cutoff_%d" % chamber), "the unguarded cutoff %d is accessible on retry" % (chamber + 1))

func _davor_guards_workers() -> bool:
	if world.davor.order != "hold" or world.davor.hold_point.distance_to(world.marker("workers_safe")) >= 32.0 or world.davor.global_position.distance_to(world.davor.hold_point) >= 32.0 or not world.tiled_loader.is_walkable_position(world.davor.global_position):
		return false
	for index in range(4):
		var worker := world.story_people["worker_%d" % index] as Node2D
		if worker.global_position.distance_to(world.davor.hold_point) >= 72.0:
			return false
	return true

func _story_crew_count(prefix: String) -> int:
	var count := 0
	for actor in world.actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with(prefix) and not actor.is_queued_for_deletion():
			count += 1
	return count

func _quick_load() -> void:
	var event := InputEventAction.new()
	event.action = "quick_load"
	event.pressed = true
	game._unhandled_input(event)
	world = game.world

func _choose_scene(label: String) -> bool:
	if not ui.scene_playing():
		return false
	for button in ui.scene_buttons.get_children():
		if button is Button and String(button.text).contains(label):
			button.pressed.emit()
			return true
	return false

func _path_to_interaction(marker_name: String) -> PackedVector2Array:
	return _path_to_actor(world.actors_root.get_node_or_null("Skoljka_" + marker_name) as Node2D)

func _path_to_actor(actor: Node2D) -> PackedVector2Array:
	if actor == null:
		return PackedVector2Array()
	var target: Vector2 = actor.get_interaction_position() if actor.has_method("get_interaction_position") else actor.global_position
	var start: Vector2 = world.player.global_position
	if actor == null or not world.tiled_loader.is_walkable_position(start):
		return PackedVector2Array()
	var best := PackedVector2Array()
	var best_distance := INF
	for y in range(-2, 3):
		for x in range(-2, 3):
			var candidate := target + Vector2(x, y) * 16.0
			if candidate.distance_to(target) > Player.INTERACTION_DISTANCE or not world.tiled_loader.is_walkable_position(candidate):
				continue
			world.player.global_position = candidate
			world.player._update_nearest_interactable()
			if world.player._current_interactable != actor:
				continue
			var path: PackedVector2Array = world.tiled_loader.get_walk_path(start, candidate)
			if not path.is_empty() and (best.is_empty() or path.size() < best.size() or (path.size() == best.size() and candidate.distance_to(target) < best_distance)):
				best = path
				best_distance = candidate.distance_to(target)
	world.player.global_position = start
	world.player._update_nearest_interactable()
	return best

func _approach_and_press(marker_name: String) -> bool:
	var actor: Node2D = world.actors_root.get_node_or_null("Skoljka_" + marker_name) as Node2D
	if actor == null:
		return false
	var start: Vector2 = world.player.global_position
	var target: Vector2 = world.marker(marker_name)
	for radius in range(3):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := target + Vector2(x, y) * 16.0
				if candidate.distance_to(target) > Player.INTERACTION_DISTANCE or not world.tiled_loader.is_walkable_position(candidate):
					continue
				if world.tiled_loader.get_walk_path(start, candidate).is_empty():
					continue
				world.player.global_position = candidate
				if _press_interaction(marker_name):
					return true
	world.player.global_position = start
	return false

func _walk_path(path: PackedVector2Array) -> bool:
	for waypoint in path:
		var frames := 0
		while world.player.global_position.distance_to(waypoint) > 2.0 and frames < 100:
			frames += 1
			var offset: Vector2 = waypoint - world.player.global_position
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			if absf(offset.y) > 0.75:
				Input.action_press("move_down" if offset.y > 0.0 else "move_up")
			elif absf(offset.x) > 0.75:
				Input.action_press("move_right" if offset.x > 0.0 else "move_left")
			if combat_walking:
				_combat_input()
			await get_tree().physics_frame
		if frames >= 100:
			print("WALK FAILED at ", world.player.global_position, " to ", waypoint, " alert=", world._depot_alerted)
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			return false
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	return true

func _approach_service(service: WorldService) -> bool:
	var start: Vector2 = world.player.global_position
	var target := service.get_interaction_position()
	for radius in range(3):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := target + Vector2(x, y) * 16.0
				if candidate.distance_to(target) > Player.INTERACTION_DISTANCE or not world.tiled_loader.is_walkable_position(candidate):
					continue
				if world.tiled_loader.get_walk_path(start, candidate).is_empty():
					continue
				world.player.global_position = candidate
				world.player._update_nearest_interactable()
				if world.player._current_interactable != service:
					continue
				var event := InputEventAction.new()
				event.action = "interact"
				event.pressed = true
				world.player._unhandled_input(event)
				return true
	world.player.global_position = start
	return false

func _find_button(node: Node, label: String) -> Button:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button and child.text.contains(label):
			return child
		var result := _find_button(child, label)
		if result != null:
			return result
	return null

func _has_text(node: Node, fragment: String) -> bool:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label and child.text.contains(fragment):
			return true
		if _has_text(child, fragment):
			return true
	return false

func _press_interaction(marker_name: String) -> bool:
	return _press_actor(world.actors_root.get_node_or_null("Skoljka_" + marker_name) as Node2D)

func _press_actor(actor: Node2D) -> bool:
	if actor == null or ui.scene_playing():
		return false
	var target: Vector2 = actor.get_interaction_position() if actor.has_method("get_interaction_position") else actor.global_position
	if world.player.global_position.distance_to(target) > Player.INTERACTION_DISTANCE:
		return false
	world.player._update_nearest_interactable()
	if world.player._current_interactable != actor:
		return false
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	world.player._unhandled_input(event)
	return true

func _capture(stage: String) -> void:
	if screenshot_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	await get_tree().physics_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(screenshot_dir.path_join("skoljka_%s.png" % stage))
	_check(result == OK, "offscreen %s screenshot saves" % stage)

func _end_scene() -> void:
	if ui == null:
		return
	var guard := 0
	while ui.scene_playing() and guard < 80:
		guard += 1
		if ui.scene_lines_left() == 0 and not ui._scene_choices.is_empty():
			var button := ui.scene_buttons.get_child(ui.scene_buttons.get_child_count() - 1) as Button
			button.pressed.emit()
		else:
			ui.advance_scene()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		printerr("FAIL ", description)

func _finish() -> void:
	print("Skoljka: %d checks, %d failures" % [checks, failures])
	if game != null:
		remove_child(game)
		game.free()
	get_tree().quit(0 if failures == 0 else 1)
