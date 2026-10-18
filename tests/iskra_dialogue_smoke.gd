extends Node

var game: Node
var world: IskraWorld
var ui: GameUI
var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
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
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(640, 360)]:
		get_window().size = resolution
		await get_tree().create_timer(0.25).timeout
		for id in ["red_pelican", "green_squirrel"]:
			ui.cancel_scene()
			world.player.global_position = world.marker(id)
			world._move_davor()
			world.player._update_nearest_interactable()
			_check(world.player._current_interactable == world.story_people[id], "E selects " + id)
			_press("interact")
			await get_tree().create_timer(0.15).timeout
			_check(ui.scene_playing(), "first interaction opens " + id)
			await _capture("%s_%dx%d" % [id, resolution.x, resolution.y])
			var bounds := Rect2(Vector2.ZERO, GameUI.BASE_SIZE / ui.scale.x)
			_check(bounds.encloses(ui.scene_panel.get_global_rect()), "entire recruiter panel fits " + str(resolution))
			var leave: Button
			for child in ui.scene_buttons.get_children():
				if child is Button:
					_check(bounds.encloses(child.get_global_rect()), "choice fits: " + child.text)
					if child.text.begins_with("Leave"):
						leave = child
			_check(leave != null and leave.is_visible_in_tree(), "visible leave button exists")
			_press("interact")
			await get_tree().process_frame
			_check(not ui.scene_playing() and world.gang_jobs.side().is_empty(), "E exits without accepting a job")
			ui.cancel_scene()
			world.story_people[id].interact(world.player)
			_press("pause")
			await get_tree().process_frame
			_check(not ui.scene_playing() and world.gang_jobs.side().is_empty(), "Escape exits without accepting a job")
	world.chapter.set_flag("audience_complete")
	for id in ["red_pelican", "green_squirrel", "collector"]:
		ui.cancel_scene()
		world.gang_jobs.set_flag("hunt_found")
		if id == "collector":
			world.gang_jobs.set_flag("hunt_job")
		world.gang_jobs.sync()
		world.player.global_position = world.story_people[id].global_position
		world.story_people[id].interact(world.player)
		await get_tree().create_timer(0.15).timeout
		await _capture("expanded_" + id)
		var bounds := Rect2(Vector2.ZERO, GameUI.BASE_SIZE / ui.scale.x)
		_check(bounds.encloses(ui.scene_panel.get_global_rect()), "expanded dialogue fits: " + id)
		for child in ui.scene_buttons.get_children():
			_check(bounds.encloses(child.get_global_rect()), "expanded choice fits: " + child.text)
		if id == "collector":
			_check(ui.scene_buttons.get_child(0).position.y != ui.scene_buttons.get_child(-1).position.y, "long collector choices wrap across rows")
		ui.scene_buttons.get_child(-1).pressed.emit()
		_check(not ui.scene_playing() and world.gang_jobs.side().is_empty(), "exit button closes expanded menu without accepting")
	ui.play_scene([{"text": "First line"}, {"text": "Second line"}], Callable(), [{"label": "Accept", "action": func() -> void: _check(false, "must never auto-accept")}, {"label": "Leave", "action": Callable()}])
	_press("interact")
	_check(ui.scene_playing() and ui.scene_text_label.text == "Second line", "E advances multi-line dialogue before choices")
	_press("interact")
	_check(not ui.scene_playing(), "E leaves final choice menu")
	print("Iskra dialogue: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	if ui.scene_playing():
		ui._input(event)
	else:
		world.player._unhandled_input(event)

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + message)
