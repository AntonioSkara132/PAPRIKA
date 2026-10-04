class_name StationWorld
extends GameWorld

const STATION_MAP := "res://maps/station.tmj"
const ARRIVAL := Vector2(224, 384)
const RUN_SECONDS := 12.0
const RUN_OFFSETS := [Vector2(-62, -28), Vector2(48, -34), Vector2(60, 29), Vector2(-49, 34)]

var _services: Dictionary = {}
var _pending_soldier_spawns: Array[Dictionary] = []
var _recruits: Dictionary = {}
var _round := ""
var _run_markers: Array[Node2D] = []
var _run_index := 0
var _run_remaining := 0.0
var _spar_hits := 0
var _training_hits_taken := 0
var _allies: Array[StationRecruit] = []
var _cadets: Array[StationRecruit] = []
var _range_targets: Array[StationMovingTarget] = []
var _range_hits: Dictionary = {}
var _cannon_targets: Array[Node2D] = []
var _cannon_in_flight := false
var _cannonball_visual: Node2D
var _cannon_tween: Tween
var _cannon_impact_visuals: Array[Node2D] = []
var _visual_generation := 0
var _trap_dummy: StationMovingTarget
var _trap_visual: Node2D
var _trap_mine_visual: Node2D
var _trap_marker := Vector2.ZERO
var _trap_lane_start := Vector2.ZERO
var _trap_lane_end := Vector2.ZERO
var _trap_previous_dummy_position := Vector2.ZERO
var _trap_mine_progress := -1.0
var _status: Label

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	tiled_loader.service_requested.connect(_on_service_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(STATION_MAP):
		push_error("Station map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	for object in tiled_loader.get_node("MapObjects").get_children():
		if object is WorldService:
			_services[object.service_id] = object.get_interaction_position()
		elif object.name.begins_with("station_range_target") or object.name.begins_with("station_trap_dummy") or object.name.begins_with("station_cannon_target"):
			object.visible = false
	_spawn_ambient_soldiers()
	if player == null:
		_spawn_player(ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	_spawn_recruits()
	_build_status()
	GameState.military_changed.connect(_on_military_changed)
	_on_military_changed()
	_rebuild_active_round()

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, stable_id: String) -> void:
	if kind == "player" and player == null:
		_spawn_player(position, variant)
	elif kind in ["station_instructor", "station_cook", "station_guard"]:
		var staff := StationStaff.new()
		var title := "Instructor" if kind == "station_instructor" else ("Canteen Cook" if kind == "station_cook" else "Station Guard")
		staff.name = stable_id
		staff.configure(kind, title, variant, position)
		staff.service_requested.connect(_on_service_requested)
		actors_root.add_child(staff)
		if kind != "station_guard":
			_services[kind] = position
	elif kind == "station_soldier":
		_pending_soldier_spawns.append({"id": stable_id, "position": position, "texture": variant})

func _spawn_ambient_soldiers() -> void:
	for data in _pending_soldier_spawns:
		var stable_id := String(data["id"])
		var spawn := _nearby_open_position(Vector2(data["position"]))
		var route_distance := 24.0 + float(absi(stable_id.hash()) % 3) * 8.0
		var side := 1.0 if absi(stable_id.hash()) % 2 == 0 else -1.0
		var stops: Array[Vector2] = [
			spawn,
			_nearby_open_position(spawn + Vector2(route_distance * side, 0)),
			_nearby_open_position(spawn + Vector2(route_distance * side, route_distance * 0.5)),
		]
		var soldier := StationSoldier.new()
		soldier.name = stable_id
		soldier.configure(stable_id, String(data["texture"]), spawn, tiled_loader, stops)
		actors_root.add_child(soldier)
	_pending_soldier_spawns.clear()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = ARRIVAL
	player.respawn_location_name = "the training station"

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if tiled_loader.is_walkable_position(saved):
		return saved
	return _nearby_open_position(ARRIVAL)

func apply_loaded_state() -> void:
	_stop_round()
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_on_military_changed()
	_rebuild_active_round()

func _exit_tree() -> void:
	_cancel_cannon_flight()

func _on_military_changed() -> void:
	if GameState.current_planet == "station" and GameState.current_area == "exterior" and GameState.military_stage == "cannon" and GameState.military_cannon_round_active:
		_show_cannon_targets()
	else:
		_clear_cannon_targets()
	_refresh_hud()

func _rebuild_active_round() -> void:
	if GameState.current_planet != "station" or GameState.current_area != "exterior":
		return
	if GameState.military_stage == "cannon" and GameState.military_cannon_round_active:
		_round = "cannon"
		_show_cannon_targets()
	elif GameState.military_stage == "trap" and GameState.military_trap_round_active:
		_round = "trap"
		_build_trap_round_visuals()

func _spawn_recruits() -> void:
	var canteen := _service_position("station_canteen", Vector2(350, 330))
	var barracks := _service_position("station_barracks", Vector2(420, 520))
	var instructor := _service_position("station_instructor", Vector2(640, 400))
	for index in StationRoster.RECRUITS.size():
		var data: Dictionary = StationRoster.RECRUITS[index]
		var origin: Vector2 = [barracks, canteen, instructor][index % 3] + Vector2((index / 3 - 1) * 17, (index % 3 - 1) * 12)
		var spawn := _nearby_open_position(origin)
		var stops: Array[Vector2] = [spawn, _nearby_open_position(canteen + Vector2(index * 11 - 44, 25)), _nearby_open_position(instructor + Vector2(index * 8 - 32, 22))]
		var recruit := StationRecruit.new()
		recruit.name = String(data["id"])
		recruit.configure(data, spawn, tiled_loader, stops)
		recruit.training_hit.connect(_on_recruit_hit)
		recruit.training_defeated.connect(_on_recruit_defeated)
		actors_root.add_child(recruit)
		_recruits[recruit.recruit_id] = recruit

func _service_position(service_id: String, fallback: Vector2) -> Vector2:
	return Vector2(_services.get(service_id, _services.get(service_id.trim_prefix("station_"), fallback)))

func _current_checkpoint() -> String:
	return String(GameState.military_stage)

func _require_checkpoint(id: String) -> bool:
	var next := _current_checkpoint()
	if next == id:
		return true
	GameState.notify("Next exercise: %s. Speak to the instructor if you need directions." % next.capitalize() if not next.is_empty() else "Training is complete. You can still use the station facilities.")
	return false

func _complete_checkpoint(id: String, _results: Dictionary = {}) -> void:
	_stop_round()
	GameState.military_complete_drill(id)
	_refresh_hud()

func _on_service_requested(service_id: String, display_name: String) -> void:
	if service_id == "station_instructor":
		_instructor_briefing()
	elif service_id == "station_cook":
		super._on_service_requested("station_canteen", display_name)
	elif service_id == "station_guard":
		GameState.notify("The station guard nods and returns to the watch.")
	elif service_id == "station_tnt_pile":
		collect_game_charge()
	elif service_id == "station_cannon":
		use_cannon()
	else:
		super._on_service_requested(service_id, display_name)

# Called by Main after the player chooses an action in the station service dialog.
func handle_station_action(action: String) -> void:
	match action:
		"station_depot":
			if GameState.military_claim_uniform():
				GameState.notify("The depot issued your uniform. Your assigned bunk is in the barracks.")
			else:
				GameState.notify("Your uniform has already been issued, or you need to enlist first.")
		"station_canteen":
			if GameState.military_eat_meal():
				GameState.notify("A meal is served. Credits remaining: %d." % GameState.military_meal_credits)
			else:
				GameState.notify("Complete a training drill to earn your next meal.")
		"station_instructor": _instructor_briefing()
		"station_track": start_run()
		"station_spar": start_spar()
		"station_squad_spar": start_squad_spar()
		"station_range": start_range()
		"station_cannon_start": start_cannon_round()
		"station_tnt_pile": collect_game_charge()
		"station_cannon": use_cannon()
		"station_trap_pad": start_trap()
		"station_trap_restart": restart_trap_round()
	_refresh_hud()

func _instructor_briefing() -> void:
	var stage := _current_checkpoint()
	match stage:
		"none": GameState.notify("Instructor: Enlist at Brudet headquarters to begin training.")
		"depot": GameState.notify("Instructor: The depot has your uniform and station kit.")
		"barracks": GameState.notify("Instructor: Put your gear in your own footlocker before training.")
		"run": GameState.notify("Instructor: Run the marked course before time runs out. Hold Shift to sprint.")
		"spar": GameState.notify("Instructor: Practice with the moving partner. Three clean hits end the round; nobody gets hurt.")
		"squad": GameState.notify("Instructor: Mara and Tovin are with you against three cadets. Q follow, R hold, T attack.")
		"range": GameState.notify("Instructor: Hit each moving target with a shot from your own weapon.")
		"cannon": GameState.notify("Instructor: Start at the Cannon Range Flag. Then use E at the supply pile and cannon; shots score when the game ball reaches a painted target.")
		"trap": GameState.notify("Instructor: Start at the pad, use I to equip the toy practice mine, then Space to place it on the moving dummy's lane.")
		"sleep": GameState.notify("Instructor: All six drills are done. Rest in your own bed in the barracks.")
		_: GameState.notify("Instructor: Training complete. Well done, recruit.")

func start_run() -> void:
	if not _require_checkpoint("run") or not _round.is_empty():
		return
	_round = "run"
	_run_remaining = RUN_SECONDS
	_run_index = 0
	var track := _service_position("station_track", Vector2(760, 510))
	for index in RUN_OFFSETS.size():
		var marker := _make_marker(_nearby_open_position(track + RUN_OFFSETS[index]), "%d" % (index + 1), Color("56d4e0"))
		marker.visible = index == 0
		_run_markers.append(marker)
	GameState.notify("Course started: touch markers 1 through 4. Hold Shift to sprint. %d seconds." % int(RUN_SECONDS))
	_refresh_hud()

func start_spar() -> void:
	if not _require_checkpoint("spar") or not _round.is_empty():
		return
	_round = "spar"
	_spar_hits = 0
	_training_hits_taken = 0
	var partner := _recruit(5)
	var point := _nearby_open_position(_service_position("station_spar", Vector2(940, 370)) + Vector2(0, 32))
	partner.global_position = point
	partner.start_training("spar", point, 3)
	GameState.notify("Moving partner: land three clean practice hits. No health or loot is at stake.")
	_refresh_hud()

func start_squad_spar() -> void:
	if not _require_checkpoint("squad") or not _round.is_empty():
		return
	_round = "squad"
	_training_hits_taken = 0
	_allies.clear()
	_cadets.clear()
	var center := _nearby_open_position(_service_position("station_squad_spar", Vector2(1050, 620)) + Vector2(0, 35))
	for index in 2:
		var ally := _recruit(index)
		ally.global_position = _nearby_open_position(center + Vector2(-45, index * 27 - 14))
		ally.start_training("ally", ally.global_position, 18)
		_allies.append(ally)
	for index in 3:
		var cadet := _recruit(index + 2)
		cadet.global_position = _nearby_open_position(center + Vector2(34, index * 28 - 28))
		cadet.start_training("cadet", cadet.global_position, 12)
		_cadets.append(cadet)
	GameState.notify("3 vs 3 practice: Mara and Tovin join you. Q follow, R hold, T attack.")
	_refresh_hud()

func issue_order(order: String) -> void:
	if _round != "squad" or order not in ["follow", "hold", "attack"]:
		return
	for ally in _allies:
		ally.training_order = order
		if order == "hold":
			ally.training_focus = ally.global_position
	GameState.notify("Training squad: %s." % order.capitalize())
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _round != "squad" or player == null or player.ui_is_open() or get_tree().paused:
		return
	for order in ["follow", "hold", "attack"]:
		if event.is_action_pressed("order_" + order):
			issue_order(order)
			get_viewport().set_input_as_handled()
			return

func start_range() -> void:
	if not _require_checkpoint("range") or not _round.is_empty():
		return
	_round = "range"
	_range_hits.clear()
	var centers := _map_object_feet("station_range_target")
	if centers.size() != 3:
		var fallback := _service_position("station_range", Vector2(1432, 782))
		centers = [fallback + Vector2(72, -70), fallback + Vector2(168, -70), fallback + Vector2(264, -70)]
	for index in 3:
		var center: Vector2 = centers[index]
		var start := center + Vector2(-26, 0)
		var finish := center + Vector2(26, 0)
		var target := StationMovingTarget.new()
		target.name = "RangeTarget%d" % (index + 1)
		target.configure("range_%d" % index, start, finish)
		target.player_shot_hit.connect(_on_range_hit)
		actors_root.add_child(target)
		target.restart()
		_range_targets.append(target)
	GameState.notify("Range started: shoot all three moving targets. Practice shots do not cost supplies.")
	_refresh_hud()

func start_cannon_round() -> void:
	if not _require_checkpoint("cannon") or not _round.is_empty():
		return
	if not GameState.military_start_cannon_round():
		GameState.notify("The cannon round is already active or not ready to start.")
		return
	_round = "cannon"
	_show_cannon_targets()
	GameState.notify("Cannon round started. Press E at the supply pile, then load and fire at the cannon.")
	_refresh_hud()

func collect_game_charge() -> bool:
	if GameState.military_stage != "cannon":
		return _require_checkpoint("cannon")
	if not GameState.military_cannon_round_active:
		GameState.notify("Start the cannon round at the Cannon Range Flag first.")
		return false
	if _cannon_in_flight:
		GameState.notify("Wait for the cannonball to reach its target before taking another charge.")
		return false
	if GameState.military_cannon_phase != "empty":
		GameState.notify("Use the charge already carried or loaded before taking another.")
		return false
	if not GameState.military_take_cannon_charge():
		return false
	GameState.notify("You took one game-only practice charge. Carry it to the training cannon.")
	_refresh_hud()
	return true

func load_cannon() -> bool:
	if GameState.military_stage != "cannon":
		return _require_checkpoint("cannon")
	if not GameState.military_cannon_round_active:
		GameState.notify("Start the cannon round at the Cannon Range Flag first.")
		return false
	if _cannon_in_flight:
		GameState.notify("Wait for the cannonball to reach its target.")
		return false
	if GameState.military_cannon_phase != "carried":
		GameState.notify("Take a game-only practice charge from the supply pile first.")
		return false
	if not GameState.military_load_cannon():
		return false
	GameState.notify("Training cannon loaded. Press E again to fire at the painted target.")
	_refresh_hud()
	return true

func use_cannon() -> void:
	if GameState.military_stage != "cannon":
		_require_checkpoint("cannon")
		return
	if not GameState.military_cannon_round_active:
		GameState.notify("Start the cannon round at the Cannon Range Flag first.")
		return
	if _cannon_in_flight:
		GameState.notify("The cannonball is still travelling to its target.")
		return
	match GameState.military_cannon_phase:
		"empty": GameState.notify("Take a game-only practice charge from the supply pile first.")
		"carried": load_cannon()
		"loaded": fire_cannon()

func _show_cannon_targets() -> void:
	if not _cannon_targets.is_empty() or not GameState.military_cannon_round_active:
		return
	var cannon := _service_position("station_cannon", Vector2(1684, 1014))
	for index in 3:
		var point := _nearby_open_position(cannon + Vector2(80 + index * 28, -68 + index * 23))
		var marker := _make_marker(point, "TARGET %d" % (index + 1), Color("ffb864"))
		marker.name = "CannonTarget%d" % index
		marker.visible = not GameState.military_cannon_hits.has("cannon_target_%d" % index)
		_cannon_targets.append(marker)

func _clear_cannon_targets() -> void:
	for marker in _cannon_targets:
		if is_instance_valid(marker):
			marker.queue_free()
	_cannon_targets.clear()

func fire_cannon() -> bool:
	if GameState.military_stage != "cannon" or not GameState.military_cannon_round_active or GameState.military_cannon_phase != "loaded" or _cannon_in_flight:
		return false
	var target_index := GameState.military_cannon_hits.size()
	if target_index >= 3:
		return false
	_show_cannon_targets()
	if target_index >= _cannon_targets.size() or not is_instance_valid(_cannon_targets[target_index]):
		return false
	var cannon := _service_position("station_cannon", Vector2(1684, 1014))
	var start := cannon + Vector2(8, -16)
	var target_point := _cannon_targets[target_index].global_position
	var projectile := Node2D.new()
	projectile.name = "Cannonball"
	projectile.global_position = start
	projectile.z_index = 950 + int(start.y)
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(-2, -1.5), Vector2(2, -1.5), Vector2(4, 0), Vector2(2, 1.5), Vector2(-2, 1.5)])
	shadow.color = Color(0.06, 0.04, 0.10, 0.55)
	projectile.add_child(shadow)
	var ball := Sprite2D.new()
	ball.name = "Sprite"
	ball.texture = load("res://assets/art/space_military_base/station_cannonball.png") as Texture2D
	ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ball.z_index = 1
	projectile.add_child(ball)
	actors_root.add_child(projectile)
	_cannonball_visual = projectile
	_cannon_in_flight = true
	var generation := _visual_generation
	var tween := create_tween()
	_cannon_tween = tween
	tween.tween_method(Callable(self, "_update_cannonball").bind(projectile, shadow, ball, start, target_point, generation), 0.0, 1.0, 0.82)
	tween.tween_callback(Callable(self, "_start_cannon_impact").bind(target_index, target_point, generation))
	GameState.notify("The training cannonball is in the air.")
	_refresh_hud()
	return true

func _update_cannonball(progress: float, projectile: Node2D, shadow: Polygon2D, ball: Sprite2D, start: Vector2, target: Vector2, generation: int) -> void:
	if not _is_current_world(generation) or not is_instance_valid(projectile):
		return
	var t := clampf(progress, 0.0, 1.0)
	var ground_position := start.lerp(target, t)
	var arc_height := sin(t * PI) * 68.0
	projectile.global_position = ground_position + Vector2(0, -arc_height)
	projectile.z_index = 950 + int(ground_position.y)
	ball.position = Vector2.ZERO
	shadow.position = Vector2(0, arc_height)
	shadow.scale = Vector2(0.7 + t * 0.55, 0.65 + t * 0.45)
	shadow.modulate.a = 0.72 - t * 0.2

func _start_cannon_impact(target_index: int, target: Vector2, generation: int) -> void:
	if not _is_current_world(generation) or not _cannon_in_flight:
		return
	if is_instance_valid(_cannonball_visual):
		_cannonball_visual.queue_free()
	_cannonball_visual = null
	var impact := _make_cannon_impact(target)
	_cannon_impact_visuals.append(impact)
	var tween := create_tween()
	_cannon_tween = tween
	tween.tween_interval(0.14)
	tween.tween_callback(Callable(self, "_record_cannon_impact").bind(target_index, generation))

func _make_cannon_impact(position: Vector2) -> Node2D:
	var effect := Node2D.new()
	effect.name = "CannonImpact"
	effect.global_position = position
	effect.z_index = 960 + int(position.y)
	actors_root.add_child(effect)
	var flash := Polygon2D.new()
	flash.polygon = _circle_polygon(7.0, 10)
	flash.color = Color("ffe27a")
	effect.add_child(flash)
	var ring := Line2D.new()
	var ring_points := _circle_polygon(10.0, 14)
	ring_points.append(ring_points[0])
	ring.points = ring_points
	ring.width = 2.0
	ring.default_color = Color("ff8e55")
	effect.add_child(ring)
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector2(1.7, 1.7), 0.30)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.30)
	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.36
	cleanup_timer.timeout.connect(effect.queue_free)
	effect.add_child(cleanup_timer)
	cleanup_timer.start()
	return effect

func _circle_polygon(radius: float, points: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in points:
		var angle := TAU * float(index) / float(points)
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon

func _record_cannon_impact(target_index: int, generation: int) -> void:
	if not _is_current_world(generation) or not _cannon_in_flight:
		return
	_cannon_in_flight = false
	_cannon_tween = null
	var target_id := "cannon_target_%d" % target_index
	if GameState.military_record_cannon_hit(target_id):
		if target_index < _cannon_targets.size() and is_instance_valid(_cannon_targets[target_index]):
			_cannon_targets[target_index].visible = false
		GameState.notify("Painted target %d/3 hit by the training cannon." % (target_index + 1))
		if not GameState.military_cannon_round_active:
			_round = ""
	else:
		GameState.notify("The practice shot did not count. Start another round at the Cannon Range Flag.")
	_refresh_hud()

func _is_current_world(generation: int) -> bool:
	return is_inside_tree() and generation == _visual_generation and GameState.current_planet == "station" and GameState.current_area == "exterior" and get_tree().get_first_node_in_group("game_world") == self

func start_trap() -> void:
	if not _require_checkpoint("trap") or not _round.is_empty():
		return
	if not GameState.military_start_trap_round():
		GameState.notify("Trap practice is already active or not ready to start.")
		return
	_round = "trap"
	_build_trap_round_visuals()
	GameState.notify("Practice marker %d/3 active. Use I to equip your mine, then Space to place it on the dummy's lane." % (GameState.military_trap_progress + 1))
	_refresh_hud()

func restart_trap_round() -> void:
	if GameState.military_stage != "trap" or not GameState.military_trap_round_active:
		GameState.notify("Start trap practice at the pad before restarting it.")
		return
	if not GameState.military_restart_trap_round():
		GameState.notify("Trap practice could not be restarted.")
		return
	_clear_trap_visuals()
	_round = "trap"
	_build_trap_round_visuals()
	GameState.notify("Practice restarted. Your single mine is back in inventory if it was already placed.")
	_refresh_hud()

func _build_trap_round_visuals() -> void:
	_clear_trap_visuals()
	if not GameState.military_trap_round_active:
		return
	_round = "trap"
	var pad := _service_position("station_trap_pad", Vector2(1164, 1038))
	var next_marker := GameState.military_trap_progress
	_trap_marker = _nearby_open_position(pad + Vector2(0, 52 + next_marker * 23))
	_trap_visual = _make_marker(_trap_marker, "MARKER %d" % (next_marker + 1), Color("68daca"))
	_trap_lane_start = _nearby_open_position(_trap_marker + Vector2(-50, 0))
	_trap_lane_end = _nearby_open_position(_trap_marker + Vector2(50, 0))
	_trap_dummy = StationMovingTarget.new()
	_trap_dummy.name = "PracticeDummy"
	_trap_dummy.configure("trap_dummy", _trap_lane_start, _trap_lane_end, false)
	_trap_dummy.travel_speed = 34.0
	actors_root.add_child(_trap_dummy)
	_trap_dummy.restart()
	_trap_previous_dummy_position = _trap_lane_start
	if GameState.military_trap_mine_placed():
		var saved_position := _saved_trap_mine_position()
		_trap_mine_progress = _lane_progress(saved_position)
		_show_placed_mine(saved_position)

func _saved_trap_mine_position() -> Vector2:
	var values: Array = GameState.military_trap_mine_position
	if values.size() < 2:
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))

func _show_placed_mine(position: Vector2) -> void:
	if is_instance_valid(_trap_mine_visual):
		_trap_mine_visual.queue_free()
	_trap_mine_visual = Node2D.new()
	_trap_mine_visual.name = "PlacedPracticeMine"
	_trap_mine_visual.global_position = position
	_trap_mine_visual.z_index = 100 + int(position.y)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load("res://assets/art/space_military_base/station_practice_mine.png") as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2(-6, -9)
	_trap_mine_visual.add_child(sprite)
	actors_root.add_child(_trap_mine_visual)

func place_practice_mine() -> bool:
	if GameState.current_planet != "station" or GameState.current_area != "exterior" or _round != "trap" or not GameState.military_trap_round_active or not GameState.military_trap_equipped or GameState.military_trap_mine_placed():
		GameState.notify("Start trap practice and equip the mine before placing it.")
		return false
	if player == null or not is_instance_valid(_trap_dummy):
		return false
	var candidate := player.global_position + player.facing * 18.0
	var progress := _lane_progress(candidate)
	var lane_point := _trap_lane_start.lerp(_trap_lane_end, clampf(progress, 0.0, 1.0))
	if progress <= 0.05 or progress >= 0.95 or candidate.distance_to(lane_point) > 8.0 or not tiled_loader.is_walkable_position(candidate):
		GameState.notify("Place the toy practice mine on the moving dummy's walkable lane.")
		return false
	if not GameState.military_place_practice_mine(candidate):
		GameState.notify("The toy practice mine could not be placed. It stays in your inventory.")
		return false
	_trap_mine_progress = progress
	_trap_previous_dummy_position = _trap_dummy.global_position
	_show_placed_mine(candidate)
	GameState.notify("Toy practice mine placed on the dummy's lane. Watch for it to cross the marker.")
	_refresh_hud()
	return true

func _lane_progress(position: Vector2) -> float:
	var lane := _trap_lane_end - _trap_lane_start
	if lane.length_squared() <= 0.01:
		return 0.0
	return (position - _trap_lane_start).dot(lane) / lane.length_squared()

func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.01:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)

func _dummy_crossed_mine(previous: Vector2, current: Vector2) -> bool:
	if not GameState.military_trap_mine_placed() or _trap_mine_progress < 0.0:
		return false
	var previous_progress := _lane_progress(previous)
	var current_progress := _lane_progress(current)
	var crossed := (previous_progress < _trap_mine_progress and current_progress >= _trap_mine_progress) or (previous_progress > _trap_mine_progress and current_progress <= _trap_mine_progress)
	return crossed and _point_segment_distance(_saved_trap_mine_position(), previous, current) <= 9.0

func _clear_trap_visuals() -> void:
	if is_instance_valid(_trap_dummy):
		_trap_dummy.queue_free()
	_trap_dummy = null
	if is_instance_valid(_trap_visual):
		_trap_visual.queue_free()
	_trap_visual = null
	if is_instance_valid(_trap_mine_visual):
		_trap_mine_visual.queue_free()
	_trap_mine_visual = null
	_trap_mine_progress = -1.0

func _physics_process(delta: float) -> void:
	if player == null or _round.is_empty() or player.ui_is_open() or get_tree().paused:
		return
	if _round == "run":
		_run_remaining -= delta
		if _run_index < _run_markers.size() and player.global_position.distance_to(_run_markers[_run_index].global_position) < 19.0:
			_run_markers[_run_index].visible = false
			_run_index += 1
			if _run_index >= _run_markers.size():
				GameState.notify("Course complete with %d seconds remaining." % ceili(_run_remaining))
				_complete_checkpoint("run", {"seconds_remaining": maxf(_run_remaining, 0.0)})
				return
			_run_markers[_run_index].visible = true
			GameState.notify("Checkpoint %d/%d." % [_run_index, _run_markers.size()])
		if _run_remaining <= 0.0:
			_stop_round()
			GameState.notify("Time is up. Interact with the track to try again.")
	elif _round in ["spar", "squad"]:
		_step_training_combat()
	elif _round == "trap" and is_instance_valid(_trap_dummy):
		var current_position := _trap_dummy.global_position
		if _dummy_crossed_mine(_trap_previous_dummy_position, current_position):
			_trap_dummy.moving = false
			var marker_number := GameState.military_trap_progress
			if GameState.military_record_trap_step("trap_%d" % marker_number):
				_stop_round()
				GameState.notify("The dummy crossed the placed toy mine at marker %d/3." % (marker_number + 1))
				return
		_trap_previous_dummy_position = current_position
	_refresh_hud()

func _step_training_combat() -> void:
	if _round == "spar":
		var partner := _recruit(5)
		if partner.ready_to_strike() and partner.global_position.distance_to(player.global_position) < 24.0:
			partner.mark_strike(1.7)
			_register_training_hit()
		return
	if _round != "squad":
		return
	for ally in _allies:
		if ally.training_down:
			continue
		if ally.training_order == "attack":
			var nearest := _nearest_live_cadet(ally.global_position)
			ally.training_focus = nearest.global_position if nearest != null else ally.global_position
			if nearest != null and ally.global_position.distance_to(nearest.global_position) < 24.0 and ally.ready_to_strike():
				ally.mark_strike(0.8)
				nearest.take_damage(4, ally.global_position)
		elif ally.training_order == "follow":
			ally.training_focus = player.global_position + Vector2(-21, -13 if ally == _allies[0] else 13)
	for cadet in _cadets:
		if cadet.training_down or not cadet.ready_to_strike():
			continue
		var target := _nearest_training_opponent(cadet.global_position)
		if target != null and cadet.global_position.distance_to(target.global_position) < 24.0:
			cadet.mark_strike(1.55)
			if target == player:
				_register_training_hit()
			else:
				(target as StationRecruit).receive_training_hit(3)

func _register_training_hit() -> void:
	_training_hits_taken += 1
	if _training_hits_taken >= 5:
		_stop_round()
		GameState.notify("Practice round ended after five touches. Try again when ready.")
	else:
		GameState.notify("Practice touch! %d/5. Your health is unchanged." % _training_hits_taken)

func _nearest_training_opponent(origin: Vector2) -> CharacterBody2D:
	var nearest: CharacterBody2D = player
	var distance := origin.distance_to(player.global_position)
	for ally in _allies:
		if not ally.training_down and origin.distance_to(ally.global_position) < distance:
			nearest = ally
			distance = origin.distance_to(ally.global_position)
	return nearest

func _nearest_live_cadet(origin: Vector2) -> StationRecruit:
	var nearest: StationRecruit
	var distance := INF
	for cadet in _cadets:
		if not cadet.training_down and origin.distance_to(cadet.global_position) < distance:
			nearest = cadet
			distance = origin.distance_to(cadet.global_position)
	return nearest

func _on_recruit_hit(_id: String, team: String, _damage: int) -> void:
	if _round == "spar" and team == "spar":
		_spar_hits += 1
		GameState.notify("Sparring hit %d/3." % mini(_spar_hits, 3))
	_refresh_hud()

func _on_recruit_defeated(_id: String, team: String) -> void:
	if _round == "spar" and team == "spar":
		GameState.notify("Partner spar complete. Everyone walks away unharmed.")
		_complete_checkpoint("spar", {"player_hits": _spar_hits, "touches_taken": _training_hits_taken})
	elif _round == "squad":
		if team == "cadet" and _cadets.all(func(cadet: StationRecruit) -> bool: return cadet.training_down):
			GameState.notify("Your three-person squad completed the practice match.")
			_complete_checkpoint("squad", {"allies": ["Mara", "Tovin"], "touches_taken": _training_hits_taken})
		elif team == "ally" and _allies.all(func(ally: StationRecruit) -> bool: return ally.training_down):
			_stop_round()
			GameState.notify("Your partners need a break. Speak to the sparring marshal to try again.")

func _on_range_hit(target_id: String) -> void:
	if _round != "range" or _range_hits.has(target_id):
		return
	_range_hits[target_id] = true
	GameState.notify("Moving target hit: %d/3." % _range_hits.size())
	if _range_hits.size() == 3:
		_complete_checkpoint("range", {"player_shots": 3})
	else:
		_refresh_hud()

func _stop_round() -> void:
	_round = ""
	_cancel_cannon_flight()
	_clear_cannon_targets()
	for marker in _run_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_run_markers.clear()
	for target in _range_targets:
		if is_instance_valid(target):
			target.queue_free()
	_range_targets.clear()
	_clear_trap_visuals()
	for recruit in _recruits.values():
		(recruit as StationRecruit).stop_training()
	_allies.clear()
	_cadets.clear()
	_refresh_hud()

func _cancel_cannon_flight() -> void:
	_visual_generation += 1
	if _cannon_tween != null and _cannon_tween.is_running():
		_cannon_tween.kill()
	_cannon_tween = null
	if is_instance_valid(_cannonball_visual):
		_cannonball_visual.queue_free()
	_cannonball_visual = null
	_cannon_in_flight = false
	for effect in _cannon_impact_visuals:
		if is_instance_valid(effect):
			effect.queue_free()
	_cannon_impact_visuals.clear()

func _recruit(index: int) -> StationRecruit:
	return _recruits[String(StationRoster.RECRUITS[index]["id"])] as StationRecruit

func _map_object_feet(prefix: String) -> Array[Vector2]:
	var feet: Array[Vector2] = []
	var raw = JSON.parse_string(FileAccess.get_file_as_string(STATION_MAP))
	if not raw is Dictionary:
		return feet
	for layer_value in raw.get("layers", []):
		if not layer_value is Dictionary or String(layer_value.get("type", "")) != "objectgroup":
			continue
		for object_value in layer_value.get("objects", []):
			if object_value is Dictionary and String(object_value.get("name", "")).begins_with(prefix):
				feet.append(Vector2(float(object_value.get("x", 0)) + float(object_value.get("width", 0)) * 0.5, float(object_value.get("y", 0)) - 2.0))
	feet.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return feet

func _make_marker(at: Vector2, text: String, color: Color) -> Node2D:
	var marker := Node2D.new()
	marker.name = "TrainingMarker_%s" % text
	marker.position = at
	marker.z_index = 140 + int(at.y)
	actors_root.add_child(marker)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -23), Vector2(8, -13), Vector2(0, -3), Vector2(-8, -13)])
	diamond.color = color
	marker.add_child(diamond)
	var label := Label.new()
	label.text = text
	label.position = Vector2(-32, -42)
	label.size = Vector2(64, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	marker.add_child(label)
	return marker

func _build_status() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrainingStatus"
	layer.layer = 900
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(376, 78)
	_status.size = Vector2(254, 47)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color("ffe7a4"))
	_status.add_theme_color_override("font_shadow_color", Color("17121b"))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_status)

func _refresh_hud() -> void:
	if _status == null:
		return
	var stage := _current_checkpoint()
	var line := "Training complete" if stage == "graduated" else "Next: %s" % stage.capitalize()
	if stage == "cannon":
		var cannon_status := "Visit the range flag to start"
		if GameState.military_cannon_round_active:
			cannon_status = "Shot in flight" if _cannon_in_flight else {
				"empty": "E at supply pile",
				"carried": "E at cannon to load",
				"loaded": "E at cannon to fire",
			}.get(GameState.military_cannon_phase, "Round active")
		line = "Cannon targets: %d/3  •  %s" % [GameState.military_cannon_hits.size(), cannon_status]
	elif stage == "trap":
		var trap_status := "Visit pad to start"
		if GameState.military_trap_round_active:
			trap_status = "Dummy must cross placed mine" if GameState.military_trap_mine_placed() else ("Space to place mine" if GameState.military_trap_equipped else "I to equip practice mine")
		line = "Practice markers: %d/3  •  %s" % [GameState.military_trap_progress, trap_status]
	match _round:
		"run": line = "Run %d/4  •  %ds  •  Shift to sprint" % [_run_index, ceili(_run_remaining)]
		"spar": line = "Partner spar: %d/3 hits" % mini(_spar_hits, 3)
		"squad": line = "3 vs 3: %d/3 cadets  •  Q / R / T" % _cadets.filter(func(cadet: StationRecruit) -> bool: return cadet.training_down).size()
		"range": line = "Moving targets: %d/3 player shots" % _range_hits.size()
		"cannon": line = "Cannon targets: %d/3  •  %s" % [GameState.military_cannon_hits.size(), "Shot in flight" if _cannon_in_flight else String(GameState.military_cannon_phase).capitalize()]
		"trap": line = "Marker %d/3  •  %s" % [GameState.military_trap_progress + 1, "dummy crossing mine" if GameState.military_trap_mine_placed() else ("Space to place" if GameState.military_trap_equipped else "I to equip mine")]
	_status.text = "MILITARY TRAINING STATION\n" + line
