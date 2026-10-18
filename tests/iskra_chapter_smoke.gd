extends Node

var game: Node
var world: IskraWorld
var ui: GameUI
var chapter: RefCounted
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		_check(false, "tests require isolated saves")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	GameState.add_item("embassy_letters")
	game._on_story_travel_requested("iskra")
	await get_tree().process_frame
	world = game.world as IskraWorld
	_check(world != null, "actual world loader opens Iskra")
	if world == null:
		_finish()
		return
	chapter = world.chapter
	_talk("dock_officer")
	_check(not chapter.has_flag("arrival"), "opening arrival dialogue does not finish it")
	ui.cancel_scene()
	_check(not chapter.has_flag("arrival"), "cancelling arrival has no effect")
	_talk("dock_officer")
	_end()
	_talk("police")
	_end()
	_talk("tower")
	ui.cancel_scene()
	_check(not chapter.has_flag("tower_closed_seen"), "cancelled Tower visit stays incomplete")
	_talk("tower")
	_end()
	_check(chapter.has_flag("tower_closed_seen") and not chapter.has_flag("tower_received"), "night guard asks for morning, without accepting letters")
	_check(not chapter.audience(), "night audience is refused")
	await _capture("tower_night")
	GameState.gold = 100
	_talk("park_vendor")
	_choose("Not now")
	_check(not chapter.has_flag("vendor_job"), "ordinary job can be declined")
	_talk("park_vendor")
	_choose("Collect")
	_talk("workshop")
	ui.cancel_scene()
	_check(not chapter.has_flag("vendor_coil"), "cancelled pickup does not award coil")
	_talk("workshop")
	_end()
	_talk("park_vendor")
	_end()
	_check(GameState.gold == 130 and chapter.has_flag("vendor_paid"), "completed kitchen delivery pays thirty")
	_talk("park_vendor")
	_end()
	_check(GameState.gold == 130, "kitchen delivery cannot pay twice")
	_talk("red_pelican")
	_check(ui.scene_text_label.text.contains("Julius"), "Pelicans disclose Julius affiliation")
	_choose("Leave")
	_check(not chapter.has_flag("pelican_job"), "Pelican work can be refused")
	# An earlier save can still finish its accepted envelope contract.
	chapter.set_flag("pelican_job")
	_talk("courier")
	_choose("Keep it")
	_check(not chapter.has_flag("pelican_delivered"), "courier allows returning the notice")
	_talk("red_pelican")
	_choose("Return the envelope")
	_check(chapter.has_flag("pelican_returned") and GameState.gold == 130, "returning notice ends work without pay or membership")
	GameState.defeated_persistent_enemies.erase("iskra_pelican_returned")
	_talk("courier")
	_choose("Leave the envelope")
	_talk("red_pelican")
	_end()
	_talk("red_pelican")
	_end()
	_check(GameState.gold == 155 and chapter.has_flag("pelican_paid"), "delivered notice pays once")
	_talk("green_squirrel")
	_end()
	_check(chapter.has_flag("squirrels_met"), "independent rival introduction completes")
	_talk("park_witness")
	_end()
	for topic in ["Appearance?", "What did he ask?", "Where did he go"]:
		_talk("park_witness")
		_choose(topic)
		_end()
	_check(chapter.has_flag("stranger_coat") and chapter.has_flag("stranger_question") and chapter.has_flag("stranger_route"), "three concrete stranger clues are recorded")
	_talk("park_witness")
	await _capture("park_witness")
	ui.cancel_scene()
	world.player.global_position = world.marker("hotel_door")
	world._move_davor()
	chapter.refresh_location()
	_interact("hotel_door")
	_check(chapter.in_lobby() and world.player.global_position == world.marker("hotel_lobby_arrival") and ui.location_label.text.contains("LOBBY"), "the street door opens into the walkable lobby")
	_check(await _walk("hotel"), "player walks across the lobby to Mara's desk")
	_talk("hotel")
	ui.set_interaction_prompt("Talk to Mara — Hotel Kinova")
	_check(not ui.prompt_panel.visible, "interaction prompts cannot cover dialogue choices")
	await _capture("hotel_reception")
	_choose("Rent room")
	_check(chapter.has_flag("room_rented") and GameState.gold == 135, "room twelve costs twenty")
	_check(not chapter.rent_room() and GameState.gold == 135, "room cannot charge twice")
	_check(await _walk("hotel_stairs"), "player walks from the desk to the stairs")
	_interact("hotel_stairs")
	_check(chapter.in_room() and world.davor.global_position.distance_to(world.player.global_position) < 64, "both companions climb the stairs to room twelve")
	_check(ui.location_label.text.contains("ROOM 12"), "hotel location label is correct")
	await _capture("room")
	_check(await _walk("hotel_room_chest"), "player walks around room furniture to chest")
	_interact("hotel_room_chest")
	_check(ui.modal_panel.visible, "E opens chest storage")
	ui.close_modal()
	GameState.add_item("wood_sword", 3)
	var original := int(GameState.inventory.get("wood_sword", 0))
	_check(not chapter.transfer_storage("embassy_letters", true), "embassy letters cannot enter chest")
	_check(not chapter.transfer_storage("not_an_item", true), "unknown items cannot enter chest")
	chapter._storage()
	await get_tree().process_frame
	var stored_with_button := false
	for child in ui.modal_content.get_children():
		if child is Button and child.text.begins_with("Store Wooden Sword"):
			child.pressed.emit()
			stored_with_button = true
			break
	_check(stored_with_button and GameState.iskra_storage.has("wood_sword"), "chest button stores spare swords")
	await _capture("chest")
	ui.close_modal()
	_check(int(GameState.inventory.get("wood_sword", 0)) + int(GameState.iskra_storage.get("wood_sword", 0)) == original, "deposit preserves count")
	_check(not chapter.transfer_storage(GameState.equipment["weapon"], true), "equipped weapon stays in pack")
	world.capture_player_position()
	_check(GameState.save_game(), "room position and chest save")
	var room_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(chapter.transfer_storage("wood_sword", false), "stored swords return to pack")
	_check(not chapter.transfer_storage("wood_sword", false), "empty chest cannot duplicate swords")
	_check(GameState.load_game(), "room save reloads")
	world.apply_loaded_state()
	_check(chapter.in_room() and not GameState.iskra_storage.is_empty(), "reload restores room and chest")
	_check(chapter.transfer_storage("wood_sword", false) and int(GameState.inventory.get("wood_sword", 0)) == original, "loaded chest preserves exact item totals")
	await _walk("hotel_room_bed")
	_interact("hotel_room_bed")
	_choose("Keep exploring")
	_check(not chapter.has_flag("morning"), "declining sleep keeps night")
	_interact("hotel_room_bed")
	_choose("Sleep until morning")
	ui.cancel_scene()
	_check(not chapter.has_flag("morning"), "cancelled sleep narration does not advance morning")
	_interact("hotel_room_bed")
	_choose("Sleep until morning")
	_end()
	_check(chapter.has_flag("morning"), "deliberate sleep advances morning")
	_check(await _walk("hotel_room_exit"), "player walks to room door")
	_interact("hotel_room_exit")
	_check(not chapter.in_room() and world.player.global_position == world.marker("hotel_stairs"), "E returns both companions to the lobby stairs")
	_check(chapter.in_lobby() and world._camera.limit_bottom == 2816 + 256 + 32, "the lobby keeps its own camera limits")
	_check(await _walk("hotel_lobby_door"), "player walks to the lobby door")
	_interact("hotel_lobby_door")
	_check(not chapter.in_lobby() and world.player.global_position == world.marker("hotel_door"), "leaving the lobby returns to the street")
	_check(world._camera.limit_bottom == 2608, "leaving restores city camera limits")
	_talk("tower")
	_choose("Attend")
	_check(ui.scene_playing() and GameState.inventory.has("embassy_letters"), "letters remain during audience")
	world.capture_player_position()
	_check(GameState.save_game(), "mid-audience save succeeds")
	var event := InputEventAction.new()
	event.action = "quick_load"
	event.pressed = true
	game._unhandled_input(event)
	await get_tree().process_frame
	world = game.world as IskraWorld
	chapter = world.chapter
	_check(not ui.scene_playing() and not chapter.has_flag("audience_complete") and GameState.inventory.has("embassy_letters"), "F9 cancels audience without handing over letters")
	GameState.remove_item("embassy_letters")
	_check(not chapter.audience(), "missing originals prevent audience")
	GameState.add_item("embassy_letters")
	_talk("tower")
	_choose("Attend")
	await _capture("audience")
	_end()
	_check(chapter.has_flag("audience_complete") and chapter.has_flag("tower_received") and not GameState.inventory.has("embassy_letters"), "completed audience hands over letters and grants diplomatic status")
	_check(not chapter.audience(), "audience cannot repeat")
	_talk("hotel")
	ui.cancel_scene()
	_check(not chapter.has_flag("hotel_cover_confirmed"), "cancelled reception confirmation remains unread")
	_talk("hotel")
	_end()
	_check(chapter.has_flag("hotel_cover_confirmed"), "reception confirms government coverage")
	var gold := GameState.gold
	GameState.health = 1
	_check(chapter.hotel_meal(), "diplomat meal heals")
	_end()
	_check(GameState.health == GameState.max_health and GameState.gold == gold, "covered meal costs nothing and adds no saleable food")
	world.player.global_position = world.marker("hotel_stairs")
	_check(chapter.enter_stairs(), "same room remains accessible after audience")
	_check(chapter.in_room() and chapter.ROOM_NUMBER == 12, "diplomacy keeps original room twelve")
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "completed chapter saves and loads")
	world.apply_loaded_state()
	_check(chapter.has_flag("audience_complete") and chapter.has_flag("hotel_cover_confirmed") and chapter.in_room(), "morning status and hotel agreement persist")
	game._unhandled_input(event)
	await get_tree().process_frame
	world = game.world as IskraWorld
	chapter = world.chapter
	_check(chapter.in_room() and chapter.has_flag("morning") and world._camera.limit_bottom == 3184, "F9 restores actual hotel room and interior camera")
	await _capture("room_morning")
	var invalid := room_save.duplicate(true)
	invalid["iskra_storage"] = {"embassy_letters": 1}
	_check(not GameState._valid_save(invalid), "save validator rejects stored keys")
	invalid["iskra_storage"] = {"wood_sword": -1}
	_check(not GameState._valid_save(invalid), "save validator rejects negative storage")
	invalid["iskra_storage"] = {"wood_sword": 1.5}
	_check(not GameState._valid_save(invalid), "save validator rejects fractional storage")
	invalid["iskra_storage"] = {"unknown": 1}
	_check(not GameState._valid_save(invalid), "save validator rejects unknown stored items")
	invalid = room_save.duplicate(true)
	invalid["defeated_persistent_enemies"].erase("iskra_room_rented")
	_check(not GameState._valid_save(invalid), "save validator rejects chest without rented room")
	var legacy := room_save.duplicate(true)
	legacy.erase("iskra_storage")
	_check(GameState._valid_save(legacy), "old saves without storage remain valid")
	GameState.start_new_game()
	_check(GameState.iskra_storage.is_empty(), "new game clears hotel storage")
	GameState.defeated_persistent_enemies.append_array(["iskra_arrival", "iskra_registered", "iskra_tower_received"])
	_check(not chapter.has_flag("audience_complete"), "old Tower request does not invent a completed diplomatic audience")
	_talk("tower")
	_end()
	_check(chapter.has_flag("tower_closed_seen") and not chapter.has_flag("morning"), "old request saves can play the night chapter")
	GameState.gold = 0
	_talk("hotel")
	_choose("Rent room")
	_end()
	_check(not chapter.has_flag("room_rented"), "broke player is not charged or given room without work")
	_talk("hotel")
	_choose("Ask about work")
	_end()
	_talk("hotel_laundry")
	_end()
	_talk("hotel")
	_choose("Give Mara")
	_end()
	_talk("hotel")
	_choose("Rent room")
	_check(chapter.has_flag("room_rented") and GameState.gold == 0, "linen work guarantees lodging even after spending all money")
	_end()
	_check(not chapter.transfer_storage("stick", true), "storage cannot be used from reception")
	_finish()

func _talk(id: String) -> void:
	ui.cancel_scene()
	world.player.global_position = world.marker(id)
	world._move_davor()
	chapter.refresh_location()
	world.story_people[id].interact(world.player)

func _interact(id: String) -> void:
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world.story_people[id], "E selects " + id)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	world.player._unhandled_input(event)

func _choose(prefix: String) -> void:
	for child in ui.scene_buttons.get_children():
		if child is Button and child.text.begins_with(prefix):
			child.pressed.emit()
			return
	_check(false, "missing choice: " + prefix)

func _end() -> void:
	for i in 40:
		if not ui.scene_playing():
			return
		ui.advance_scene()
	_check(false, "dialogue ends within forty lines")

func _walk(id: String) -> bool:
	var path := world.tiled_loader.get_walk_path(world.player.global_position, world.marker(id))
	if path.is_empty():
		return false
	for target in path:
		for frame in 120:
			var delta := target - world.player.global_position
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			if delta.length() < 3:
				break
			if absf(delta.x) > 2:
				Input.action_press("move_right" if delta.x > 0 else "move_left")
			if absf(delta.y) > 2:
				Input.action_press("move_down" if delta.y > 0 else "move_up")
			await get_tree().physics_frame
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		if world.player.global_position.distance_to(target) > 5:
			return false
	return world.player.global_position.distance_to(world.marker(id)) < 24

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	ui._hide_notice()
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("chapter_" + label + ".png"))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])

func _finish() -> void:
	print("Iskra chapter: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
