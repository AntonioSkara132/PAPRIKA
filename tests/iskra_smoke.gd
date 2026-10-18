extends Node

const InvestigationData = preload("res://scripts/world/iskra_investigation_data.gd")

var game: Node
var ui: GameUI
var world: IskraWorld
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "Iskra tests require an isolated XDG_DATA_HOME")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	game._on_story_travel_requested("skoljka")
	await get_tree().process_frame
	_end_scene()
	_check(not game.world.sail_to_iskra(), "Skoljka's unfinished story does not allow departure")
	for flag: String in SkoljkaWorld.FLAGS:
		if not GameState.defeated_persistent_enemies.has(flag):
			GameState.defeated_persistent_enemies.append(flag)
	game.world._port_officer()
	_check(ui._scene_choices.size() == 2 and ui._scene_choices[0]["label"].contains("Iskra"), "the port officer offers the ship after the council ending")
	ui.cancel_scene()
	_check(game.world.sail_to_iskra(), "the finished Skoljka story permits boarding")
	_end_scene()
	await get_tree().process_frame
	world = game.world as IskraWorld
	_check(world != null and GameState.current_planet == "iskra", "boarding travels through the actual main world loader")
	if world == null:
		_finish()
		return
	_check(world.tiled_loader.map_loaded, "Iskra's Tiled map loads")
	_check(world.player.global_position == GameState.ISKRA_ARRIVAL, "arrival agrees with map and save defaults")
	_check(world.davor != null and world.davor.global_position.distance_to(world.player.global_position) < 64, "Davor arrives beside the player")
	_check(ui.location_label.text == "ISKRA — NIGHT", "UI names Iskra at night")
	for name: String in world.markers:
		var target: Vector2 = world.marker(name)
		_check(world.tiled_loader.is_walkable_position(target), "%s is walkable" % name)
		var start := world.marker("hotel_room_arrival") if name.begins_with("hotel_room_") else GameState.ISKRA_ARRIVAL
		if name.begins_with("hotel_lobby_") or name == "hotel" or name == "hotel_stairs":
			start = world.marker("hotel_lobby_arrival")
		for site in ["freight", "holding"]:
			if name.begins_with("gang_" + site + "_"):
				start = world.marker("gang_" + site + "_arrival")
		for site: String in InvestigationData.ROOMS:
			if name.begins_with("inv_" + site + "_") and InvestigationData.ROOMS[site].has_point(target):
				start = world.marker("inv_" + site + "_arrival")
		_check(not world.tiled_loader.get_walk_path(start, target).is_empty(), "%s is connected within its area" % name)
	_check(not world.tiled_loader.is_walkable_position(Vector2(1000, 1080)), "the ship canal blocks walking")
	_check(not world.tiled_loader.is_walkable_position(Vector2(4080, 1300)), "the cruiser deck cannot be boarded")
	_check(not world.tiled_loader.is_walkable_position(Vector2(16, 16)), "space beyond the city rim blocks walking")
	var first_ship: Sprite2D = world.traffic[0]["sprite"]
	var initial := first_ship.position
	await get_tree().create_timer(.15).timeout
	_check(first_ship.position != initial and world.traffic.size() == 24, "ship traffic moves on its routes")
	_check(world.story_people.size() > 40, "the city has residents and service staff")
	await _capture("arrival")
	var dock_path := world.tiled_loader.get_walk_path(world.player.global_position, world.marker("dock_officer"))
	_check(await _walk_path(dock_path), "the player walks from the landing point to the dock officer")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world.story_people["dock_officer"], "E selects the dock officer at the end of the walk")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	world.player._unhandled_input(interact)
	_check(ui.scene_playing(), "pressing E opens the arrival conversation")
	_end_scene()
	GameState.defeated_persistent_enemies.erase(world.FLAGS[0])
	GameState.gold = 5
	world.player.global_position = world.marker("taxi_dock")
	_check(world.ride_taxi("dock", "tower"), "taxis operate before the arrival errand")
	await get_tree().create_timer(1.0).timeout
	await _capture("taxi_flight")
	world._taxi_tween.set_speed_scale(30)
	while world.taxi_active:
		await get_tree().process_frame
	_check(world.story_step() == 0, "a taxi ride does not advance the errand")
	world._on_service_requested("iskra:tower", "Tower Clerk")
	_end_scene()
	_check(world.story_step() == 0, "the Tower does not skip registration")
	for id in ["dock_officer", "police", "tower"]:
		world.player.global_position = world.marker(id) + Vector2(0, 8)
		var staff: StationStaff = world.story_people[id]
		staff.interact(world.player)
		_check(ui.scene_playing(), "%s opens dialogue" % id)
		_end_scene()
		var step := world.story_step()
		world.capture_player_position()
		_check(GameState.save_game(), "%s progress saves" % id)
		GameState.defeated_persistent_enemies.erase(world.FLAGS[step-1])
		_check(GameState.load_game(), "%s progress loads" % id)
		world.apply_loaded_state()
		_check(world.story_step() == step, "%s progress survives reload" % id)
	_check(world.story_step() == 2 and world.chapter.has_flag("tower_closed_seen"), "the night Tower visit postpones the audience until morning")
	await _capture("tower")
	await _check_green_park()
	await _check_moving_residents()
	world.story_people["library"].interact(world.player)
	_check(ui._active_service_id == "iskra_library" and ui.modal_panel.visible, "Iskra library opens the shared scrollable library panel")
	var library_text := ""
	for label in ui.modal_panel.find_children("*", "Label", true, false):
		library_text += label.text + "\n"
	for entry in ["YellowSand Engineering", "electrical current and energy over a distance", "fully automated city", "main City Computer", "Tower of Engineering", "transport, lighting, communications", "HMS Schotsky", "Almost the entire ship is controlled by computer", "History of Engineeria", "Otpornik", "Elektrika", "Rudnik", "Engineering Board", "Zvonimir Dom (Nation)", "Nikola Struja (Technology)", "Vedrana Luk (Architecture)", "Kresimir Sidro (Navy)", "Ljerka Popis (Demographics)", "Dubravka Riznic (Finance)", "Branko Stit (Defense)", "Landmarks: the Automated Farms", "Landmarks: Nature Park", "Landmarks: Punk Park", "Landmarks: the docks and ship canals", "Landmarks: the Tvrdium factory", "Food Works", "Hotel Kinova"]:
		_check(library_text.contains(entry), "Iskra library includes " + entry)
	await _capture("library")
	var library_scroll := ui.modal_panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	# The scroll range is only known after the panel has been laid out; _capture waits for that only when taking screenshots.
	await get_tree().process_frame
	await get_tree().process_frame
	library_scroll.scroll_vertical = int(library_scroll.get_v_scroll_bar().max_value / 2)
	await _capture("library_landmarks")
	library_scroll.scroll_vertical = int(library_scroll.get_v_scroll_bar().max_value)
	await _capture("library_history")
	_check(library_scroll.scroll_vertical > 0, "Iskra library entries scroll through to the history section")
	ui.close_modal()
	_check(not ui.modal_overlay.visible and world.story_step() == 2, "Iskra library closes without advancing the story")
	for id in ["farm", "park", "nature_park", "cruiser"]:
		world.story_people[id].interact(world.player)
		_check(ui.scene_playing(), "%s can be read" % id)
		_end_scene()
	world._on_service_requested("iskra:resident_7", "Iskra Resident")
	_check(ui.scene_playing() and not ui.scene_text_label.text.is_empty(), "resident dialogue is readable")
	_end_scene()
	for id in ["food", "forge"]:
		world.story_people[id].interact(world.player)
		_check(ui._active_service_id == "iskra_" + id and ui.modal_panel.visible, "%s shop opens" % id)
		ui.close_modal()
	GameState.gold = 500
	for origin: String in world.TAXI_PADS:
		for destination: String in world.TAXI_PADS:
			if origin == destination:
				continue
			world.player.global_position = world.marker("taxi_" + origin)
			world.story_people["taxi_" + origin].interact(world.player)
			_check(ui._scene_choices.size() == 5, "%s taxi lists four destinations and cancel" % origin)
			ui.cancel_scene()
			var before := GameState.gold
			_check(world.ride_taxi(origin, destination), "%s to %s starts" % [origin, destination])
			_check(not world.ride_taxi(origin, destination), "a flight cannot be purchased twice")
			world._taxi_tween.set_speed_scale(30)
			while world.taxi_active:
				await get_tree().process_frame
			_check(GameState.gold == before - world.TAXI_FARE, "taxi charges exactly one fare")
			_check(world.player.global_position.distance_to(world.marker("taxi_" + destination)) < 8, "taxi lands at the chosen pad")
			_check(world.davor.global_position.distance_to(world.player.global_position) < 64, "Davor comes along")
			_check(world.tiled_loader.is_walkable_position(world.davor.global_position), "Davor lands on walkable ground")
	var last_gold := GameState.gold
	_check(not world.ride_taxi("dock", "dock") and GameState.gold == last_gold, "same-pad rides do not charge")
	world.player.global_position = world.marker("tower")
	_check(not world.ride_taxi("dock", "park") and GameState.gold == last_gold, "remote taxi requests do not charge")
	GameState.gold = 0
	world.player.global_position = world.marker("taxi_dock")
	_check(not world.ride_taxi("dock", "tower") and not world.taxi_active, "an unaffordable ride does not start")
	_check(not world.ride_taxi("dock", "unknown"), "unknown taxi destinations are refused")
	GameState.gold = 20
	world.capture_player_position()
	_check(GameState.save_game(), "save before taxi cancellation")
	_check(world.ride_taxi("dock", "park"), "flight starts before a quick-load")
	world.capture_player_position()
	_check(GameState.player_position == world.marker("taxi_dock"), "saving during a flight records the departure pad")
	_check(GameState.load_game(), "quick-load during a flight loads")
	world.apply_loaded_state()
	await get_tree().create_timer(.2).timeout
	_check(not world.taxi_active and world.player.visible and world.player.is_physics_processing(), "loading cancels flight and restores player control")
	_check(world.player.global_position == world.marker("taxi_dock"), "a cancelled flight does not overwrite loaded position")
	world.player.global_position = world.marker("taxi_park")
	world._move_davor()
	await _capture("park")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	var legacy := saved.duplicate(true)
	legacy["schema"] = 14
	legacy["current_planet"] = "skoljka"
	legacy["player_position"] = [1120, 200]
	legacy["planet_positions"].erase("iskra")
	_write_save(legacy)
	_check(GameState.load_game() and GameState.planet_positions.has("iskra"), "schema 14 migrates to nine planets")
	_check(GameState.save_game(), "migrated saves write schema 15")
	var invalid := saved.duplicate(true)
	invalid["defeated_persistent_enemies"].erase(GameState.ISKRA_UNLOCK_FLAG)
	_check(not GameState._valid_save(invalid), "an Iskra save without Skoljka completion is rejected")
	_check(GameState._valid_save(saved), "the valid Iskra save is accepted")
	_finish()

func _check_green_park() -> void:
	var roles: Dictionary = {}
	for id: String in world.story_people:
		var sprite := world.story_people[id].get_child(0) as Sprite2D
		if id == "inv_davor":
			_check(sprite != null and not sprite.visible, "Davor discussion point does not draw a second companion")
			continue
		if id == "inv_hall_evidence":
			_check(sprite != null and sprite.texture.resource_path == "res://assets/art/iskra/investigation/uniform_evidence.png", "police coat interaction draws evidence instead of an NPC")
			continue
		_check(sprite != null and sprite.texture.get_size() == Vector2(16, 24), "%s uses Paprika-sized NPC art" % id)
		if sprite == null or sprite.texture == null:
			continue
		if id.begins_with("inv_"):
			_check(not sprite.visible or sprite.texture.resource_path.begins_with("res://assets/art/iskra/investigation/npcs/"), "%s uses investigation NPC art or a hidden interaction point" % id)
		else:
			_check(sprite.texture.resource_path.begins_with("res://assets/art/iskra/npcs/"), "%s uses the new NPC sheet's sprites" % id)
			roles[sprite.texture.resource_path] = true
	_check(roles.size() == 21 and roles.has("res://assets/art/iskra/npcs/veki.png"), "all twelve shared NPC designs, Veki and eight punk outfits appear in the city")
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/iskra/placement.json"))
	var trees := 0
	for record: Dictionary in records:
		if record["kind"] != "leafy_tree":
			continue
		trees += 1
		var rect: Array = record["solid_rect"]
		var trunk := Vector2(float(record["x"]) + float(rect[0]) + float(rect[2]) / 2.0, float(record["bottom"]) - float(record["height"]) + float(rect[1]) + float(rect[3]) / 2.0) * 2.0
		_check(not world.tiled_loader.is_walkable_position(trunk), "tree %d has a blocking trunk" % trees)
	_check(trees == 14, "seven park trees and seven city trees load")
	world.player.global_position = world.marker("nature_park_north")
	world._move_davor()
	_check(await _walk_path(world.tiled_loader.get_walk_path(world.player.global_position, world.marker("nature_park"))), "player walks through the nature park from its north entrance")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world.story_people["nature_park"], "E selects the nature park gardener")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	world.player._unhandled_input(interact)
	_check(ui.scene_playing() and ui.scene_text_label.text.contains("Real soil"), "nature park dialogue opens with E")
	_end_scene()
	await _capture("nature_park")
	_check(await _walk_path(world.tiled_loader.get_walk_path(world.player.global_position, world.marker("nature_park_south"))), "player walks out through the nature park's south entrance")

func _check_moving_residents() -> void:
	var walkers: Array[IskraCitizen] = []
	var resident_count := 0
	var initial: Dictionary = {}
	var moved: Dictionary = {}
	var services: Dictionary = {}
	for id: String in world.story_people:
		var person: Node2D = world.story_people[id]
		if person is IskraCitizen and id.begins_with("resident_"):
			resident_count += 1
			var resident := person as IskraCitizen
			_check(resident.citizen_id == id and resident.service_id == "iskra:" + id, "%s keeps its original spawn and conversation IDs" % id)
			if resident._mode == "routine":
				walkers.append(resident)
				initial[id] = resident.global_position
				moved[id] = 0.0
				var route_ok := resident._stops.size() >= 2
				for index in resident._stops.size():
					var point: Vector2 = resident._stops[index]
					route_ok = route_ok and world.tiled_loader.is_walkable_position(point)
					route_ok = route_ok and world._resident_path_fits(point, resident._stops[(index+1) % resident._stops.size()], resident.home_position)
				_check(route_ok, "%s has a connected local walking circuit" % id)
		elif id != "inv_davor":
			services[id] = person.global_position
	_check(walkers.size() == resident_count and resident_count >= 85, "all ordinary residents across Iskra have walking routines")
	world.player.global_position = world.marker("nature_park")
	world._move_davor()
	await _capture("residents_before")
	var stay_walkable := true
	var stay_local := true
	for frame in range(600):
		await get_tree().physics_frame
		for resident in walkers:
			var id := resident.citizen_id
			moved[id] = maxf(float(moved[id]), resident.global_position.distance_to(initial[id]))
			stay_walkable = stay_walkable and world.tiled_loader.is_walkable_position(resident.global_position)
			stay_local = stay_local and resident.global_position.distance_to(resident.home_position) <= 148.0
	await _capture("residents_after")
	_check(stay_walkable, "walking residents stay off canals, trees and building footprints")
	_check(stay_local, "residents stay in their own neighborhoods")
	var regions := {"nature park": Rect2(600, 1140, 420, 390), "market": Rect2(1200, 1190, 400, 300), "docks": Rect2(3380, 680, 280, 1500), "Punk Park": Rect2(2460, 2020, 750, 460)}
	for region: String in regions:
		var count := 0
		for resident in walkers:
			if regions[region].has_point(resident.home_position) and float(moved[resident.citizen_id]) > 10.0:
				count += 1
		_check(count >= 2, "%s has at least two visibly walking residents" % region)
	for resident in walkers:
		_check(float(moved[resident.citizen_id]) > 10.0, "%s physically follows its route" % resident.citizen_id)
	var services_still := true
	for id: String in services:
		services_still = services_still and world.story_people[id].global_position == services[id]
	_check(services_still, "shop staff, taxi pilots and story clerks keep their posts")
	_check(world.story_people["inv_davor"].global_position.distance_to(world.davor.global_position + Vector2(0, 8)) < 2.0, "investigation discussion point follows Davor")
	if walkers.is_empty():
		return
	var speaker: IskraCitizen = walkers[0]
	speaker.interact(world.player)
	_check(ui.scene_playing() and ui.scene_speaker_label.text == speaker.display_name, "a walking resident opens its normal conversation")
	var held: Dictionary = {}
	for resident in walkers:
		held[resident.citizen_id] = resident.global_position
	for frame in range(90):
		await get_tree().physics_frame
	var paused := true
	for resident in walkers:
		paused = paused and resident.global_position == held[resident.citizen_id]
	_check(paused, "residents pause throughout dialogue")
	_end_scene()
	var resumed := false
	for frame in range(240):
		await get_tree().physics_frame
		resumed = resumed or speaker.global_position.distance_to(held[speaker.citizen_id]) > 10.0
	_check(resumed, "resident walking resumes after dialogue closes")
	ui.open_inventory()
	var inventory_position := speaker.global_position
	for frame in range(30):
		await get_tree().physics_frame
	_check(speaker.global_position == inventory_position, "resident walking pauses while inventory is open")
	ui.close_modal()

func _walk_path(path: PackedVector2Array) -> bool:
	if path.is_empty():
		return false
	for point in path:
		var frames := 0
		while world.player.global_position.distance_to(point) > 2.0 and frames < 100:
			frames += 1
			var offset := point - world.player.global_position
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			if absf(offset.y) > .75:
				Input.action_press("move_down" if offset.y > 0 else "move_up")
			elif absf(offset.x) > .75:
				Input.action_press("move_right" if offset.x > 0 else "move_left")
			await get_tree().physics_frame
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		if frames >= 100:
			return false
	return true

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _end_scene() -> void:
	for i in range(30):
		if not ui.scene_playing():
			return
		ui.advance_scene()

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	ui._hide_notice()
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("iskra_" + label + ".png"))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])

func _finish() -> void:
	print("Iskra smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
