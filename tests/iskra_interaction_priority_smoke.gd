extends Node

var game: Node
var world: IskraWorld
var ui: GameUI
var story: RefCounted
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
	ui.cancel_scene()
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	game._on_story_travel_requested("iskra")
	await get_tree().process_frame
	world = game.world as IskraWorld
	story = world.investigation
	for flag in ["arrival", "registered", "tower_closed_seen", "morning", "room_rented", "audience_complete", "hotel_cover_confirmed"]:
		world.chapter.set_flag(flag)
	story.set_flag("assassin_captured")
	story.set_flag("uniform_found")
	world.player.set_physics_process(false)
	world.davor.set_physics_process(false)
	story.sync()
	var discussion: StationStaff = story.people.inv_davor
	var police: StationStaff = world.story_people.police
	_place(police.global_position + Vector2(0, 24))
	_check(discussion.global_position.distance_to(world.player.global_position) < police.global_position.distance_to(world.player.global_position), "Davor is closer than the police clerk")
	_select(police, "farther eligible police clerk takes priority over Davor")
	await _capture("police_prompt")
	await _key(KEY_E)
	_check(ui.scene_playing() and ui.scene_speaker_label.text == "Police Clerk", "actual E opens police dialogue instead of Davor")
	_check(ui.scene_text_label.text.contains("uniform"), "police dialogue receives the investigation context")
	ui.cancel_scene()

	# Selection must not depend on the order nodes joined the group.
	police.remove_from_group("interactable")
	police.add_to_group("interactable")
	_place(police.global_position + Vector2(0, 60))
	world.player._update_nearest_interactable()
	_place(police.global_position + Vector2(0, 24))
	_select(police, "police retains priority when considered after Davor")
	_place(police.global_position + Vector2(0, Player.INTERACTION_DISTANCE + 1.0))
	_select(discussion, "out-of-range police clerk does not replace nearby Davor")
	await _key(KEY_E)
	_check(ui.scene_playing() and ui.scene_speaker_label.text == "Davor", "actual E still opens Davor when other NPC is out of range")
	ui.cancel_scene()
	_place(police.global_position + Vector2(0, Player.INTERACTION_DISTANCE))
	_select(police, "police remains eligible at the existing interaction boundary")
	police.visible = false
	_select(discussion, "hidden NPC remains ineligible even when within range")
	police.visible = true

	GameState.defeated_persistent_enemies.erase("iskra_investigation_uniform_found")
	var evidence: StationStaff = story.people.inv_hall_evidence
	var evidence_position: Vector2 = world.marker("inv_hall_evidence")
	story.set_value("evidence_x", evidence_position.x)
	story.set_value("evidence_y", evidence_position.y)
	story.set_value("site", "hall")
	story.sync()
	_place(evidence.global_position + Vector2(0, 24))
	story.refresh_location()
	_check(evidence.visible and evidence.is_in_group("interactable"), "physical coat is available as an interaction")
	_check(discussion.global_position.distance_to(world.player.global_position) < evidence.global_position.distance_to(world.player.global_position), "Davor is closer than the coat")
	_select(evidence, "farther eligible coat takes priority over Davor")
	await _capture("coat_prompt")
	await _key(KEY_E)
	_check(ui.scene_playing() and ui.scene_speaker_label.text == "Police coat", "actual E examines the coat instead of talking to Davor")
	_check(ui.scene_text_label.text.contains("K-214"), "actual E reveals the coat's issue tag")
	await _capture("coat_dialogue")
	_end()
	_check(story.has("uniform_found"), "finishing coat dialogue records the clue")
	story.sync()
	_select(discussion, "Davor becomes available after the nearby clue is collected")

	_place(Vector2(2432, 2992))
	_select(discussion, "Davor remains selectable alone in the corridor")
	await _key(KEY_E)
	_check(ui.scene_playing() and ui.scene_speaker_label.text == "Davor", "actual E opens Davor's discussion when alone")
	ui.cancel_scene()
	world.davor.global_position = world.player.global_position + Vector2(0, 40)
	story.step(0.0)
	_select(null, "Davor himself must remain within the existing interaction range")

	var near_staff := StationStaff.new()
	near_staff.service_id = "interaction_test_near"
	near_staff.interaction_text = "Near test NPC"
	world.actors_root.add_child(near_staff)
	var far_staff := StationStaff.new()
	far_staff.service_id = "interaction_test_far"
	far_staff.interaction_text = "Far test NPC"
	world.actors_root.add_child(far_staff)
	_place(Vector2(2432, 2992))
	near_staff.global_position = world.player.global_position + Vector2(18, 0)
	far_staff.global_position = world.player.global_position + Vector2(26, 0)
	_select(near_staff, "ordinary NPCs still select the nearest one")
	near_staff.global_position = world.player.global_position + Vector2(28, 0)
	_select(far_staff, "ordinary nearest selection updates as distances change")
	near_staff.queue_free()
	far_staff.queue_free()
	await get_tree().process_frame
	_finish()

func _place(position: Vector2) -> void:
	ui.cancel_scene()
	world.player.global_position = position
	world.davor.global_position = position + Vector2(0, -4)
	story.step(0.0)

func _select(expected: Node2D, label: String) -> void:
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == expected, label)
	var text: String = "" if expected == null else "[E] " + expected.get_interaction_text()
	_check(ui.prompt_label.text == text, "visible E prompt matches selected interaction: " + label)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _end() -> void:
	for i in 30:
		if not ui.scene_playing():
			return
		ui.advance_scene()
	_check(false, "dialogue finishes")

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	ui._hide_notice()
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])

func _finish() -> void:
	print("Iskra interaction priority: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
