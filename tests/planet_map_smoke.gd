extends Node

const Atlas = preload("res://scripts/data/planet_atlas.gd")
const MapView = preload("res://scripts/ui/planet_map.gd")

var game: Node
var ui: GameUI
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "planet map tests require an isolated save directory")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	var view = ui.planet_map
	_check(InputMap.has_action("planet_map"), "map action is registered")
	var binding := InputMap.action_get_events("planet_map")[0] as InputEventKey
	_check(binding != null and binding.physical_keycode == KEY_M, "M is the map shortcut")
	_check(Atlas.world_count() == 49 and Atlas.unknown_count() == 38, "atlas follows the library's political census")
	_check(view.buttons.size() == 49, "all eleven named and 38 unknown worlds are clickable")
	var entries := Atlas.entries()
	var ids := {}
	var counts := {"Engineeria": 0, "Cauliflower Confederation": 0, "Unidentified world": 0}
	for entry: Dictionary in entries:
		var id: String = entry["id"]
		_check(not ids.has(id), "unique atlas entry " + id)
		ids[id] = true
		counts[entry["faction"]] += 1
		_check(ResourceLoader.exists(entry["image"]), "sprite exists for " + id)
		_check(not String(entry["description"]).is_empty(), "description exists for " + id)
		var position: Vector2 = entry["position"]
		if entry["faction"] == "Engineeria":
			_check(position.x < MapView.CHART_SIZE.x / 2 and position.y < MapView.CHART_SIZE.y / 2, id + " is northwest")
		elif entry["faction"] == "Cauliflower Confederation":
			_check(position.x > MapView.CHART_SIZE.x / 2 and position.y < MapView.CHART_SIZE.y / 2, id + " is northeast")
		else:
			_check(entry["name"] == "UNKNOWN" and not entry["known"] and position.y > 135, "unidentified worlds stay anonymous and south of known labels")
	_check(counts == {"Engineeria": 5, "Cauliflower Confederation": 6, "Unidentified world": 38}, "faction membership matches the libraries")
	for id in ["otpornik", "elektrika", "cichvarda"]:
		_check(view.entries_by_id[id]["terrain"] == "Terrain unknown", id + " has no invented landscape")
	_check(not ids.has("station") and not ids.has("engineeria"), "station is not a planet and Engineeria is not duplicated as Rudnik")
	_press("planet_map")
	await get_tree().process_frame
	_check(ui.modal_overlay.visible and view.visible and not ui.modal_panel.visible, "M opens the dedicated map panel")
	_check(view.selected_id == "paprika" and view.detail_status.text == "YOU ARE HERE", "map starts on the current planet")
	_check(game.world.player.ui_is_open(), "map blocks player world controls")
	await _capture("paprika")
	var start: Vector2 = game.world.player.global_position
	var gold := GameState.gold
	var inventory := GameState.inventory.duplicate(true)
	var flags := GameState.defeated_persistent_enemies.duplicate()
	var position_data := GameState.planet_positions.duplicate(true)
	var health := GameState.health
	Input.action_press("move_right")
	for frame in 20:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(game.world.player.global_position == start, "held movement does not move the player while browsing")
	var attack := InputEventAction.new()
	attack.action = "attack"
	attack.pressed = true
	game.world.player._unhandled_input(attack)
	_check(game.world.player._attack_cooldown <= 0, "map does not allow a world attack")
	for entry: Dictionary in entries:
		var id: String = entry["id"]
		(view.buttons[id] as Button).pressed.emit()
		await get_tree().process_frame
		_check(view.selected_id == id and view.detail_name.text == entry["name"], "click selects " + id)
		_check(view.detail_description.text == entry["description"], "click displays description for " + id)
		_check(view.detail_image.texture.resource_path == entry["image"], "click displays the matching sprite for " + id)
		_check(view.detail_description.get_rect().end.y <= 294, "description stays above the status line for %s (%s)" % [id, view.detail_description.get_rect()])
		var button: Button = view.buttons[id]
		_check(Rect2(MapView.CHART_ORIGIN, MapView.CHART_SIZE).encloses(button.get_rect()), id + " button fits in the map")
		for other: String in ids:
			if other != id:
				_check(not button.get_rect().intersects((view.buttons[other] as Button).get_rect()), id + " does not overlap " + other)
	_check(GameState.current_planet == "paprika" and game.world.player.global_position == start, "planet selections never travel")
	_check(GameState.gold == gold and GameState.inventory == inventory and GameState.health == health, "browsing changes no gold, items or health")
	_check(GameState.defeated_persistent_enemies == flags and GameState.planet_positions == position_data, "browsing changes no story or travel records")
	_check(not FileAccess.file_exists(GameState.SAVE_PATH), "browsing does not write a save")
	await _capture("unknown")
	view.select_planet("iskra")
	await _capture("iskra")
	view.select_planet("not_a_planet")
	_check(view.selected_id == "iskra", "invalid selections leave the current details intact")
	(view.buttons["paprika"] as Button).grab_focus()
	await get_tree().process_frame
	_key(KEY_RIGHT)
	await get_tree().process_frame
	_check(view.selected_id == "brudet", "right arrow selects the neighboring world")
	_key(KEY_ENTER)
	await get_tree().process_frame
	_check(view.selected_id == "brudet" and ui.modal_overlay.visible, "Enter activates a planet without travelling or closing")
	_key(KEY_TAB)
	await get_tree().process_frame
	_check(view.selected_id == "pomidor", "Tab browses planet entries")
	_press("planet_map")
	_check(not ui.modal_overlay.visible, "M closes the map")
	_press("planet_map")
	_press("pause")
	_check(not ui.modal_overlay.visible and not get_tree().paused, "Escape closes the map without pausing the world")
	ui.open_inventory()
	_press("planet_map")
	_check(view.visible and not ui.modal_panel.visible, "map replaces inventory cleanly")
	_press("jobs")
	_check(ui.modal_panel.visible and not view.visible and ui._active_service_id == "jobs_detail", "jobs replace the map cleanly")
	_press("planet_map")
	_press("encyclopedia")
	_check(ui.modal_panel.visible and not view.visible and ui._active_service_id == "encyclopedia_categories", "encyclopedia replaces the map cleanly")
	ui.close_modal()
	ui.play_scene([{"speaker": "Test", "text": "Dialogue remains open."}])
	_press("planet_map")
	_check(ui.scene_playing() and not view.visible, "M does not interrupt dialogue")
	ui.cancel_scene()
	ui.open_order_bar()
	_press("planet_map")
	_check(ui.order_bar.visible and not view.visible, "M does not interrupt typed orders")
	ui.close_order_bar()
	get_tree().paused = true
	_press("planet_map")
	_check(view.visible and get_tree().paused, "map can be read while the game is paused")
	_press("pause")
	_check(not view.visible and get_tree().paused, "closing a paused map preserves pause state")
	get_tree().paused = false
	GameState.current_planet = "engineeria"
	ui.open_planet_map()
	_check(view.selected_id == "rudnik" and view.detail_status.text == "YOU ARE HERE", "legacy Engineeria save key selects Rudnik")
	ui.close_modal()
	GameState.current_planet = "station"
	ui.open_planet_map()
	_check(view.location_label.text.contains("Training station (not a planet)") and view.detail_status.text != "YOU ARE HERE", "station location is identified without adding a planet")
	ui.close_modal()
	GameState.current_planet = "paprika"
	ui.open_planet_map()
	for ui_scale in [1.0, 0.75, 0.5]:
		ui.apply_ui_scale(ui_scale)
		_check(view.size == MapView.VIEW_SIZE, "map retains readable dimensions at scale " + str(ui_scale))
		_check(view.position.is_equal_approx((GameUI.BASE_SIZE / ui_scale - MapView.VIEW_SIZE) * 0.5), "map stays centered at scale " + str(ui_scale))
	ui.apply_ui_scale(1.0)
	view.close_button.pressed.emit()
	_check(not ui.modal_overlay.visible and not view.visible, "close button closes the map")
	_check(not game.world.player.ui_is_open(), "closing restores world controls")
	_finish()

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui._input(event)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func _capture(label: String) -> void:
	var directory := OS.get_environment("PLANET_MAP_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join("planet_map_" + label + ".png")) == OK, "saved map screenshot " + label)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL " + description)

func _finish() -> void:
	print("Planet map smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
