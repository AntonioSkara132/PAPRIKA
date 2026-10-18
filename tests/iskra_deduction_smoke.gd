extends Node

var game: Node
var ui: GameUI
var checks := 0
var failures := 0
var submissions := 0
var hint_requests := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	game.world.capture_player_position()
	_check(GameState.save_game(), "prepare isolated quick-save test")
	var saved := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	var focus_button := Button.new()
	focus_button.text = "Previous focus"
	focus_button.position = Vector2(12, 200)
	ui.add_child(focus_button)
	focus_button.grab_focus()
	_open()
	await _frames()
	_check(ui.text_prompt_open() and get_tree().paused, "name prompt pauses game")
	_check(game.world.player.ui_is_open(), "player sees deduction as an open UI")
	_check(get_viewport().gui_get_focus_owner() == ui._text_prompt_input, "name field receives focus")
	await _type("receptionist")
	_check(ui._text_prompt_input.text == "receptionist", "actual letter keys type instead of opening menus or interacting")
	_check(ui._active_service_id == "text_prompt" and not ui.order_bar.visible, "typing preserves prompt and does not open orders")
	var position: Vector2 = game.world.player.global_position
	await _key(KEY_W, 119)
	_check(game.world.player.global_position == position, "typing movement key does not move player")
	GameState.gold += 7
	var gold := GameState.gold
	await _key(KEY_F5)
	await _key(KEY_F9)
	await _action("debug_gold")
	_check(FileAccess.get_file_as_string(GameState.SAVE_PATH) == saved, "F5 cannot overwrite save during text entry")
	_check(GameState.gold == gold, "F9 and debug action cannot change state during text entry")
	ui._text_prompt_input.text = ""
	await _key(KEY_ENTER)
	_check(submissions == 1 and ui.text_prompt_open(), "empty submission gives feedback without ending deduction")
	_check(not ui._text_prompt_feedback.text.is_empty(), "invalid answer feedback visible")
	_check(get_viewport().gui_get_focus_owner() == ui._text_prompt_input, "incorrect submission keeps keyboard focus for another answer")
	await _type("Secretary")
	await _key(KEY_ENTER)
	_check(ui.text_prompt_open() and ui._text_prompt_feedback.text.contains("Secretary"), "plausible alternative remains a question rather than conviction")
	ui._show_text_prompt_hint()
	_check(hint_requests == 1 and ui._text_prompt_feedback.text.contains("evening"), "hint changes feedback without answering")
	var prior_submissions := submissions
	await _key(KEY_ESCAPE)
	await _frames()
	_check(not ui.text_prompt_open() and not get_tree().paused, "Escape closes prompt without pausing game again")
	_check(submissions == prior_submissions, "cancellation invokes no submit callback")
	_check(get_viewport().gui_get_focus_owner() == focus_button, "cancellation restores previous keyboard focus")
	focus_button.queue_free()
	await _frames()
	_open()
	await _frames()
	await _type("Mara")
	await _key(KEY_ENTER)
	_check(not ui.text_prompt_open() and not ui.modal_overlay.visible and not get_tree().paused, "accepted name closes prompt and resumes game")
	_open()
	await _frames()
	ui._text_prompt_input.text = "x".repeat(200)
	_check(ui._text_prompt_input.text.length() <= 64, "name input has bounded length")
	ui.close_modal()
	get_tree().paused = true
	_open()
	await _frames()
	await _key(KEY_ESCAPE)
	_check(get_tree().paused, "prompt preserves a previously paused game")
	get_tree().paused = false
	_open()
	await _frames()
	ui.open_inventory()
	_check(not ui.text_prompt_open() and not get_tree().paused and ui._active_service_id == "inventory", "replacing prompt clears its callback and pause state")
	ui.close_modal()
	ui.open_text_prompt("Davor", "Who should we question?", func(_answer: String) -> Dictionary:
		ui.play_scene([{"speaker": "Davor", "text": "Let us speak to them."}])
		return {"accepted": true})
	await _frames()
	await _key(KEY_ENTER)
	_check(ui.scene_playing() and not ui.text_prompt_open() and not get_tree().paused, "submit may safely open the next dialogue")
	ui.cancel_scene()
	for size in [Vector2i(640, 360), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		await _frames()
		_open()
		await _frames()
		var input_rect := ui._text_prompt_input.get_global_rect()
		var available := Vector2(640, 360) / ui.scale.x
		_check(input_rect.position.x >= 0 and input_rect.end.x <= available.x and input_rect.position.y >= 0 and input_rect.end.y <= available.y, "name field fits window " + str(size))
		var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
		if not directory.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("deduction_%dx%d.png" % [size.x, size.y]))
		ui.close_modal()
	_finish()

func _open() -> void:
	ui.open_text_prompt("Davor", "They knew where we were staying and when we would return. Who should we question?", _answer, _hint, "Enter a name")

func _answer(text: String) -> Dictionary:
	submissions += 1
	if text.strip_edges().to_lower() == "mara":
		return {"accepted": true}
	if text.to_lower() == "secretary":
		return {"accepted": false, "message": "The Secretary knew our room. We can ask about the payment instruction."}
	return {"accepted": false, "message": "Who else heard our plans? We can think about it."}

func _hint() -> String:
	hint_requests += 1
	return "Who heard our evening arrangements?"

func _type(text: String) -> void:
	for character in text:
		var unicode := character.unicode_at(0)
		await _key(character.to_upper().unicode_at(0), unicode)

func _key(code: int, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])

func _finish() -> void:
	get_tree().paused = false
	print("Iskra deduction UI: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
