class_name SoldierSandbox
extends Node2D

const MAP_PATH := "res://maps/paprika.tmj"
const SOLDIER_COUNT := 12
const DEFAULT_LANDMARKS := {"A": Vector2(824, 520), "B": Vector2(824, 784), "C": Vector2(936, 648)}
const PLAYER_START := Vector2(896, 696)
const LANDMARK_COLORS := {"A": Color("f5c34c"), "B": Color("5fd6d3"), "C": Color("e6a5ec")}
const PROTOCOL_VERSION := 2
const SUPPORTED_ACTIONS := ["form_line", "move_to", "stop", "clarify", "follow_player", "patrol", "create_group"]
const FOLLOW_SPEED := 104.0
const FOLLOW_INTERVAL := 0.25
const FOLLOW_RETRY_INTERVAL := 0.5
const FOLLOW_RETRIES := 8
const FOLLOW_DISPLACEMENT := 8.0

var tiled_loader: TiledLoader
var actors_root: Node2D
var avoidance_map: RID
var player: SandboxPlayer
var soldiers: Array[SandboxSoldier] = []
var landmarks: Dictionary = {}
var controls: SandboxUI
var request_revision := 0
var active_assignments: Dictionary = {}
var groups: Dictionary = {}
var tasks: Dictionary = {}
var soldier_tasks: Dictionary = {}
var completed_tasks: Dictionary = {}
var last_error := ""
var _next_task_id := 0
var _latest_task_id := ""
var _service_compatible := false
var _selected_landmark := ""
var _slots := PackedVector2Array()
var _spawn_positions: Dictionary = {}
var _marker_root: Node2D
var _pending_request: HTTPRequest
var _health_request: HTTPRequest
var _health_revision := 0
var _service_url := "http://127.0.0.1:8787"
var _service_valid := true
var _request_timeout := 150.0
var _game_state_processing := true
var _progress_timer := 0.0
var _reported_completion := false
var _source := ""
var _active_action := ""

func _ready() -> void:
	_game_state_processing = GameState.is_processing()
	GameState.set_process(false)
	_ensure_input_actions()
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.scenery_only = true
	add_child(tiled_loader)
	if not tiled_loader.load_map(MAP_PATH):
		push_error("The sandbox could not load Paprika.")
		return
	avoidance_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(avoidance_map, true)
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	_marker_root = Node2D.new()
	_marker_root.name = "Landmarks"
	_marker_root.z_index = 2500
	add_child(_marker_root)
	_marker_root.draw.connect(_draw_markers)
	controls = SandboxUI.new()
	controls.name = "SandboxUI"
	add_child(controls)
	controls.order_submitted.connect(submit_order)
	controls.landmark_selected.connect(select_landmark)
	controls.stop_requested.connect(stop_orders)
	controls.reset_requested.connect(reset_sandbox)
	controls.demo_requested.connect(run_offline_example)
	controls.connection_retry_requested.connect(check_service)
	player = SandboxPlayer.new()
	player.name = "SandboxPlayer"
	player.controls = controls
	player.avoidance_map = avoidance_map
	player.configure("res://assets/art/space_military_base/player_uniform.png", PLAYER_START, Rect2(Vector2.ZERO, tiled_loader.map_size))
	actors_root.add_child(player)
	for index in SOLDIER_COUNT:
		var soldier := SandboxSoldier.new()
		var id := "soldier_%02d" % (index + 1)
		var wanted := Vector2(872 + (index % 2) * 24, 536 + floori(float(index) / 2.0) * 24)
		var spawn := _find_spawn(wanted)
		_spawn_positions[id] = spawn
		soldier.name = id
		soldier.avoidance_map = avoidance_map
		soldier.route_provider = _get_soldier_path.bind(id)
		soldier.configure(id, "res://assets/art/space_military_base/station_soldier_%d.png" % (index % 6 + 1), spawn, tiled_loader, [])
		actors_root.add_child(soldier)
		soldiers.append(soldier)
	landmarks = DEFAULT_LANDMARKS.duplicate()
	_rebuild_markers()
	controls.set_landmarks(landmarks, "")
	controls.set_status("Create a named group, follow in formation, or patrol A–B. Type stop to stop everyone immediately.")
	_refresh_progress()
	var configured_url := OS.get_environment("SANDBOX_SERVICE_URL").trim_suffix("/")
	if not configured_url.is_empty():
		var pattern := RegEx.new()
		pattern.compile("^http://(127\\.0\\.0\\.1|localhost)(:[0-9]{1,5})?$")
		var matched := pattern.search(configured_url)
		_service_valid = matched != null
		if matched != null and not matched.get_string(2).is_empty():
			var port := int(matched.get_string(2).trim_prefix(":"))
			_service_valid = port >= 1 and port <= 65535
		if _service_valid:
			_service_url = configured_url.replace("localhost", "127.0.0.1")
	check_service()

func _exit_tree() -> void:
	if is_instance_valid(_pending_request):
		_pending_request.cancel_request()
	if avoidance_map.is_valid():
		NavigationServer2D.free_rid(avoidance_map)
		avoidance_map = RID()
	if is_instance_valid(GameState):
		GameState.set_process(_game_state_processing)

func _process(delta: float) -> void:
	if controls == null:
		return
	_progress_timer -= delta
	if _progress_timer <= 0.0:
		_progress_timer = 0.15
		_refresh_progress()

func _physics_process(delta: float) -> void:
	if controls != null and player != null:
		_tick_tasks(delta)

func _unhandled_input(event: InputEvent) -> void:
	if controls == null or controls.is_typing():
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_selected_landmark = ""
		controls.set_landmarks(landmarks, "")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not _selected_landmark.is_empty():
			set_landmark(_selected_landmark, get_canvas_transform().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var camera := player.get_node("Camera") as Camera2D
			var change := 0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x + change, 0.5, 1.5)
			get_viewport().set_input_as_handled()

func select_landmark(id: String) -> void:
	if not LANDMARK_COLORS.has(id):
		return
	_selected_landmark = "" if _selected_landmark == id else id
	controls.set_landmarks(landmarks, _selected_landmark)
	controls.set_status("Click the map to place %s. Moving a landmark stops the current order." % id if not _selected_landmark.is_empty() else "Landmark placement cancelled.")

func set_landmark(id: String, point: Vector2) -> bool:
	if not LANDMARK_COLORS.has(id) or not SandboxFormationPlanner.body_fits(tiled_loader, point):
		_show_error("Place the landmark on open ground, away from tree trunks and walls.")
		return false
	_invalidate_order()
	landmarks[id] = point
	_selected_landmark = ""
	_rebuild_markers()
	controls.set_landmarks(landmarks, "")
	controls.set_status("%s placed at (%d, %d). Describe a new order." % [id, roundi(point.x), roundi(point.y)])
	return true

func submit_order(prompt: String) -> void:
	prompt = prompt.strip_edges()
	if prompt.to_lower() == "stop":
		stop_orders()
		return
	if prompt.is_empty() or prompt.length() > 2000:
		_show_error("Orders must contain between 1 and 2,000 characters.")
		return
	_cancel_pending_order()
	if not _service_valid:
		_show_error("SANDBOX_SERVICE_URL must use HTTP on localhost or 127.0.0.1.")
		return
	if not _service_compatible:
		_show_error("Reconnect to an updated protocol 2 order service. Existing tasks continue; stop works without a service.")
		return
	_pending_request = HTTPRequest.new()
	_pending_request.name = "OrderRequest"
	_pending_request.timeout = _request_timeout
	_pending_request.body_size_limit = 65536
	add_child(_pending_request)
	_pending_request.request_completed.connect(_on_order_completed.bind(request_revision))
	var payload := {"request_id": request_revision, "prompt": prompt, "context": order_context()}
	var result := _pending_request.request(_service_url + "/orders", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if result != OK:
		_pending_request.queue_free()
		_pending_request = null
		_show_error("The local service request could not start. Start tools/sandbox_order_service.py and retry.")
		return
	controls.set_busy(true)
	controls.set_status("Interpreting your order… Existing tasks continue. Stop cancels tasks and this reply.")

func order_context() -> Dictionary:
	var actor_data: Array = []
	var ids: Array[String] = []
	for soldier in soldiers:
		actor_data.append({"id": soldier.soldier_id, "position": [soldier.global_position.x, soldier.global_position.y]})
		ids.append(soldier.soldier_id)
	var marker_data: Dictionary = {}
	for id: String in landmarks:
		var point: Vector2 = landmarks[id]
		marker_data[id] = [point.x, point.y]
	var group_data := groups.duplicate(true)
	group_data["all"] = ids
	return {"soldiers": actor_data, "groups": group_data, "landmarks": marker_data}

func _on_order_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int) -> void:
	if revision != request_revision:
		return
	if is_instance_valid(_pending_request):
		_pending_request.queue_free()
	_pending_request = null
	controls.set_busy(false)
	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("No order was executed: the local service is unavailable or the request timed out. Offline example still works.")
		controls.set_connection("Service unavailable · offline example available")
		return
	var decoder := JSON.new()
	var parsed: Variant = decoder.data if decoder.parse(body.get_string_from_utf8()) == OK else null
	if not parsed is Dictionary:
		_show_error("No order was executed: the service returned invalid JSON.")
		return
	if code != 200:
		var message: Variant = parsed.get("error", "The service rejected this request.")
		_show_error(str(message).left(500))
		return
	accept_response(parsed, revision)

func accept_response(response: Dictionary, revision: int) -> bool:
	if revision != request_revision:
		return false
	var echoed: Variant = response.get("request_id")
	if (not echoed is int and not echoed is float) or echoed != revision:
		_show_error("No order was executed: the response has the wrong request ID.")
		return false
	if response.size() != 3 or response.get("mode") not in ["cloud", "fixture", "local"] or not response.has("order"):
		_show_error("No order was executed: the response format is invalid.")
		return false
	var source: String = {"cloud": "Cloud model", "local": "Local model", "fixture": "Fixture service — fixed response, not an LLM"}[response["mode"]]
	controls.set_connection(source)
	return execute_order(response["order"], source)

func execute_order(value: Variant, source: String = "Offline example — fixed order, not an LLM") -> bool:
	var known: Array[String] = []
	for soldier in soldiers:
		known.append(soldier.soldier_id)
	var checked := SandboxFormationPlanner.validate_order(value, known, landmarks, groups)
	if not checked["ok"]:
		_show_error(checked["error"])
		return false
	var order: Dictionary = checked["order"]
	if order["action"] == "clarify":
		controls.set_status("%s: %s" % [source, order["message"]])
		return true
	if order["action"] == "attack":
		# Attack orders are for battles such as the Artichoke defense; the sandbox has no enemies.
		controls.set_status("%s: there are no enemies in the sandbox to attack. Running tasks are unchanged." % source)
		return true
	var selected: Array[String] = []
	for id: String in order["soldier_ids"]:
		selected.append(id)
	if order["action"] == "create_group":
		var group_name: String = order["group_name"]
		groups[group_name] = selected.duplicate()
		controls.set_status("%s: created group %s with %d soldiers. Running tasks are unchanged." % [source, group_name, selected.size()])
		last_error = ""
		_refresh_progress()
		return true
	if order["action"] == "stop":
		_detach_soldiers(selected)
		controls.set_status("%s: stopped %d soldiers. Other tasks continue." % [source, selected.size()])
		_refresh_progress()
		return true
	var task := SandboxTask.new("", order, source)
	if task.action == "patrol":
		if landmarks[order["start"]].distance_to(landmarks[order["end"]]) < SandboxFormationPlanner.MIN_SPACING:
			_show_error("Patrol endpoints must be at least 24 pixels apart. Existing tasks continue.")
			return false
		task.endpoint = order["start"]
	elif task.action == "follow_player":
		var line := _line_for_follow(selected)
		task.follow_offsets = SandboxFormationPlanner.make_follow_offsets(selected, line.get("assignments", {}), line.get("facing", Vector2.ZERO))
		task.heading = _player_heading()
		task.leader_position = player.global_position
		task.update_timer = FOLLOW_INTERVAL
	task.facing = _order_facing(order)
	var plan := _plan_task(task)
	if not plan["ok"]:
		_show_error(plan["error"])
		return false
	_detach_soldiers(selected)
	_next_task_id += 1
	task.id = "task_%06d" % _next_task_id
	tasks[task.id] = task
	for id in selected:
		soldier_tasks[id] = task.id
	_latest_task_id = task.id
	_apply_task_plan(task, plan)
	last_error = ""
	var face_text := " · facing %s" % order["facing"] if order["facing"] != null else ""
	if task.action == "move_to":
		controls.set_status("%s: %d soldiers → near %s%s. Hold on arrival." % [source, selected.size(), order["end"], face_text])
	elif task.action == "form_line":
		controls.set_status("%s: %d soldiers → line %s–%s%s. Hold on arrival." % [source, selected.size(), order["start"], order["end"], face_text])
	elif task.action == "follow_player":
		controls.set_status("%s: %d soldiers following the player in formation until stopped." % [source, selected.size()])
	else:
		controls.set_status("%s: %d soldiers patrolling %s → %s, starting at %s, until stopped." % [source, selected.size(), order["start"], order["end"], task.endpoint])
	_refresh_progress()
	return true

func _soldier_positions() -> Dictionary:
	var positions: Dictionary = {}
	for soldier in soldiers:
		positions[soldier.soldier_id] = soldier.global_position
	return positions

func _actual_occupied(selected: Array[String]) -> PackedVector2Array:
	var occupied := PackedVector2Array([player.global_position])
	for soldier in soldiers:
		if not selected.has(soldier.soldier_id):
			occupied.append(soldier.global_position)
	return occupied

func _planning_occupied(selected: Array[String]) -> PackedVector2Array:
	var occupied := _actual_occupied(selected)
	for records: Dictionary in [tasks, completed_tasks]:
		for task: SandboxTask in records.values():
			if task.status in ["paused", "blocked"]:
				continue
			for id: String in task.assignments:
				if not selected.has(id):
					occupied.append(task.assignments[id])
	return occupied

func _plan_task(task: SandboxTask) -> Dictionary:
	var positions := _soldier_positions()
	var occupied := _planning_occupied(task.soldier_ids)
	var plan: Dictionary
	if task.action == "form_line":
		plan = SandboxFormationPlanner.plan_line(task.order, positions, landmarks, tiled_loader)
	elif task.action == "follow_player":
		plan = SandboxFormationPlanner.plan_follow(task.soldier_ids, positions, player.global_position, task.heading, task.follow_offsets, tiled_loader, _actual_occupied(task.soldier_ids))
	else:
		var move_order := task.order.duplicate(true)
		if task.action == "patrol":
			move_order["end"] = task.endpoint
		plan = SandboxFormationPlanner.plan_move(move_order, positions, landmarks, tiled_loader, occupied)
	if not plan["ok"]:
		return plan
	for id: String in plan["assignments"]:
		var point: Vector2 = plan["assignments"][id]
		for occupied_point in occupied:
			if point.distance_to(occupied_point) < SandboxFormationPlanner.MIN_SPACING:
				return {"ok": false, "error": "The requested destinations conflict with the player or another task. Existing tasks continue."}
		var path := _get_soldier_path(positions[id], point, id, task.soldier_ids)
		if path.is_empty() or path[-1].distance_to(point) > 0.1:
			return {"ok": false, "error": "Not every soldier can reach the requested destinations around other actors. Existing tasks continue."}
		plan["paths"][id] = path
	return plan

func _order_facing(order: Dictionary) -> Vector2:
	if order["action"] == "form_line":
		var start: Vector2 = landmarks[order["start"]]
		var end: Vector2 = landmarks[order["end"]]
		var default_facing := (end - start).normalized().orthogonal()
		var direction: Vector2 = landmarks[order["facing"]] - (start + end) * 0.5 if order["facing"] != null else default_facing
		return default_facing if direction.length_squared() < 0.01 else direction
	if order["action"] == "move_to" and order["facing"] != null:
		return landmarks[order["facing"]] - landmarks[order["end"]]
	return Vector2.ZERO

func _line_for_follow(ids: Array[String]) -> Dictionary:
	for records: Dictionary in [tasks, completed_tasks]:
		for task: SandboxTask in records.values():
			if task.action != "form_line":
				continue
			var contains_selection := true
			for id in ids:
				if not task.assignments.has(id):
					contains_selection = false
					break
			if contains_selection:
				var assignments: Dictionary = {}
				for id in ids:
					assignments[id] = task.assignments[id]
				return {"assignments": assignments, "facing": task.facing}
	return {}

func _apply_task_plan(task: SandboxTask, plan: Dictionary, retarget: bool = false) -> void:
	task.assignments = plan["assignments"].duplicate()
	task.paths = plan["paths"].duplicate()
	task.slots = plan["slots"].duplicate()
	var following := task.action == "follow_player"
	var facing_direction := task.heading if following else task.facing
	for soldier in soldiers:
		if not task.assignments.has(soldier.soldier_id):
			continue
		var point: Vector2 = task.assignments[soldier.soldier_id]
		var path: PackedVector2Array = task.paths[soldier.soldier_id]
		if retarget:
			soldier.retarget_position(point, path, facing_direction)
		else:
			soldier.assign_position(point, path, facing_direction, FOLLOW_SPEED if following else SandboxSoldier.MOVE_SPEED, following)
	_sync_assignments()

func _detach_soldiers(ids: Array[String]) -> void:
	for soldier in soldiers:
		if ids.has(soldier.soldier_id):
			soldier.stop()
			soldier_tasks.erase(soldier.soldier_id)
	for records: Dictionary in [tasks, completed_tasks]:
		for task_id: String in records.keys():
			var task: SandboxTask = records[task_id]
			task.remove_soldiers(ids)
			if task.soldier_ids.is_empty():
				records.erase(task_id)
	_sync_assignments()

func _sync_assignments() -> void:
	active_assignments.clear()
	for records: Dictionary in [tasks, completed_tasks]:
		for task: SandboxTask in records.values():
			for id: String in task.assignments:
				active_assignments[id] = task.assignments[id]
	var latest: SandboxTask = tasks.get(_latest_task_id)
	if latest == null:
		latest = completed_tasks.get(_latest_task_id)
	if latest == null:
		var ids: Array = tasks.keys()
		ids.append_array(completed_tasks.keys())
		ids.sort()
		_latest_task_id = str(ids[-1]) if not ids.is_empty() else ""
		latest = tasks.get(_latest_task_id, completed_tasks.get(_latest_task_id))
	if latest == null:
		_active_action = ""
		_source = ""
		_slots = PackedVector2Array()
		_reported_completion = false
	else:
		_active_action = latest.action
		_source = latest.source
		_slots = latest.slots.duplicate()
		_reported_completion = latest.status == "complete"
	if _marker_root != null:
		_marker_root.queue_redraw()

func _player_heading() -> Vector2:
	var heading := player.velocity.normalized() if player.velocity.length_squared() > 1.0 else player.facing.normalized()
	return Vector2.DOWN if heading.length_squared() < 0.01 else heading

func _task_arrival_count(task: SandboxTask) -> int:
	var arrived := 0
	for soldier in soldiers:
		if task.assignments.has(soldier.soldier_id) and soldier.task_state == "holding" and soldier.global_position.distance_to(task.assignments[soldier.soldier_id]) <= SandboxFormationPlanner.ARRIVAL_DISTANCE:
			arrived += 1
	return arrived

func _task_blocked_reason(task: SandboxTask) -> String:
	for soldier in soldiers:
		if task.soldier_ids.has(soldier.soldier_id) and soldier.task_state == "blocked":
			return "%s: %s" % [soldier.soldier_id, soldier.blocked_reason]
	return ""

func _stop_task_motion(task: SandboxTask) -> void:
	for soldier in soldiers:
		if task.soldier_ids.has(soldier.soldier_id) and soldier.task_state != "blocked":
			soldier.stop()

func _block_task(task: SandboxTask, reason: String) -> void:
	_stop_task_motion(task)
	task.status = "blocked"
	task.blocked_reason = reason
	_sync_assignments()
	_refresh_progress()

func _complete_task(task: SandboxTask) -> void:
	tasks.erase(task.id)
	for id in task.soldier_ids:
		soldier_tasks.erase(id)
	task.status = "complete"
	completed_tasks[task.id] = task
	_sync_assignments()
	if task.id == _latest_task_id and not is_instance_valid(_pending_request):
		controls.set_status("%s: all %d soldiers reached their assigned positions and are holding." % [task.source, task.soldier_ids.size()])
	_refresh_progress()

func _tick_tasks(delta: float) -> void:
	for task: SandboxTask in tasks.values():
		if task.status == "blocked":
			continue
		var reason := _task_blocked_reason(task)
		if not reason.is_empty():
			_block_task(task, reason)
			continue
		if task.action == "follow_player":
			_tick_follow(task, delta)
		elif task.status == "active" and _task_arrival_count(task) == task.soldier_ids.size():
			if task.action == "patrol":
				_advance_patrol(task)
			else:
				_complete_task(task)

func _tick_follow(task: SandboxTask, delta: float) -> void:
	task.update_timer -= delta
	if task.update_timer > 0.0:
		return
	task.update_timer = FOLLOW_INTERVAL
	var heading := _player_heading()
	var moved := player.global_position.distance_to(task.leader_position) >= FOLLOW_DISPLACEMENT
	var turned := heading.dot(task.heading) < cos(deg_to_rad(15.0))
	if task.status == "active" and not moved and not turned:
		return
	var previous_heading := task.heading
	task.heading = heading
	var plan := _plan_task(task)
	if not plan["ok"]:
		task.heading = previous_heading
		_stop_task_motion(task)
		task.status = "paused"
		task.blocked_reason = plan["error"]
		task.retry_count += 1
		task.update_timer = FOLLOW_RETRY_INTERVAL
		if task.retry_count >= FOLLOW_RETRIES:
			_block_task(task, "Formation remains blocked after bounded retries: " + task.blocked_reason)
		else:
			_refresh_progress()
		return
	var resuming := task.status == "paused"
	task.status = "active"
	task.blocked_reason = ""
	task.retry_count = 0
	task.leader_position = player.global_position
	_apply_task_plan(task, plan, not resuming)

func _advance_patrol(task: SandboxTask) -> void:
	task.leg_count += 1
	var arrived_endpoint := task.endpoint
	task.endpoint = task.order["end"] if arrived_endpoint == task.order["start"] else task.order["start"]
	var plan := _plan_task(task)
	if plan["ok"]:
		var positions := _soldier_positions()
		var requires_travel := false
		for id: String in plan["assignments"]:
			if positions[id].distance_to(plan["assignments"][id]) > SandboxFormationPlanner.ARRIVAL_DISTANCE:
				requires_travel = true
				break
		if not requires_travel:
			plan = {"ok": false, "error": "The next patrol leg would not move any soldier."}
	if not plan["ok"]:
		task.endpoint = arrived_endpoint
		_stop_task_motion(task)
		task.status = "paused"
		task.blocked_reason = "Cannot start the next patrol leg: " + plan["error"]
		_refresh_progress()
		return
	_apply_task_plan(task, plan)

func run_offline_example() -> void:
	_invalidate_order()
	var ids: Array[String] = []
	for soldier in soldiers:
		ids.append(soldier.soldier_id)
	var order := {"action": "form_line", "soldier_ids": ids, "start": "A", "end": "B", "facing": "C" if landmarks.has("C") else null, "group_name": null, "message": "Fixed line example; no language model was used."}
	execute_order(order)

func stop_orders() -> void:
	_invalidate_order()
	controls.set_status("Stopped. Soldiers hold their current positions; pending replies are ignored.")
	_refresh_progress()

func reset_sandbox() -> void:
	_invalidate_order()
	groups.clear()
	for soldier in soldiers:
		soldier.global_position = _spawn_positions[soldier.soldier_id]
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	(player.get_node("Camera") as Camera2D).zoom = SandboxPlayer.DEFAULT_ZOOM
	landmarks = DEFAULT_LANDMARKS.duplicate()
	_selected_landmark = ""
	_rebuild_markers()
	controls.set_landmarks(landmarks, "")
	controls.set_status("Sandbox reset. Starter landmarks restored; campaign progress is unchanged.")
	_refresh_progress()

func _cancel_pending_order() -> void:
	request_revision += 1
	if is_instance_valid(_pending_request):
		_pending_request.cancel_request()
		_pending_request.queue_free()
	_pending_request = null
	last_error = ""
	if controls != null:
		controls.set_busy(false)

func _invalidate_order() -> void:
	_cancel_pending_order()
	for soldier in soldiers:
		soldier.stop()
	tasks.clear()
	soldier_tasks.clear()
	completed_tasks.clear()
	_latest_task_id = ""
	_sync_assignments()

func check_service() -> void:
	_service_compatible = false
	if not _service_valid:
		controls.set_connection("Invalid service URL · loopback HTTP only")
		return
	if is_instance_valid(_health_request):
		_health_request.cancel_request()
		_health_request.queue_free()
	_health_request = HTTPRequest.new()
	_health_request.timeout = 3.0
	_health_request.body_size_limit = 16384
	add_child(_health_request)
	_health_revision += 1
	_health_request.request_completed.connect(_on_health_completed.bind(_health_revision))
	controls.set_connection("Checking local order service…")
	var result := _health_request.request(_service_url + "/health")
	if result != OK:
		controls.set_connection("Service unavailable · offline example available")

func _on_health_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int) -> void:
	if revision != _health_revision:
		return
	if is_instance_valid(_health_request):
		_health_request.queue_free()
	_health_request = null
	_service_compatible = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		controls.set_connection("Service unavailable · offline example available")
		return
	var decoder := JSON.new()
	var health: Variant = decoder.data if decoder.parse(body.get_string_from_utf8()) == OK else null
	if not health is Dictionary or health.get("mode") not in ["cloud", "fixture", "local"] or not health.get("ready") is bool:
		controls.set_connection("Invalid service response · no orders executed")
		return
	_service_compatible = false
	var version: Variant = health.get("protocol_version")
	var actions: Variant = health.get("supported_actions")
	if (not version is int and not version is float) or version != PROTOCOL_VERSION or not actions is Array:
		controls.set_connection("Incompatible order service · protocol 2 required; use another port or restart it manually")
		return
	if actions.size() > 32:
		controls.set_connection("Invalid service capabilities · no orders executed")
		return
	for action in actions:
		if not action is String or action.is_empty() or action.length() > 40:
			controls.set_connection("Invalid service capabilities · no orders executed")
			return
	for action in SUPPORTED_ACTIONS:
		if not actions.has(action):
			controls.set_connection("Incompatible order service · missing " + action)
			return
	_service_compatible = true
	var timeout_value: Variant = health.get("request_timeout", 150.0 if health["mode"] == "local" else 50.0)
	if (timeout_value is int or timeout_value is float) and is_finite(float(timeout_value)) and float(timeout_value) >= 10.0 and float(timeout_value) <= 180.0:
		_request_timeout = float(timeout_value)
	if health["mode"] == "fixture":
		controls.set_connection("Fixture service — fixed response, not an LLM")
	elif health["mode"] == "local":
		var model := str(health.get("model", "")).left(80)
		controls.set_connection("Local model ready · " + model if health["ready"] else "Local model not ready · " + str(health.get("error", "Start the local order service with tools/run_sandbox_local.py.")).left(200))
	elif not health["ready"]:
		controls.set_connection("Cloud service needs ANTHROPIC_API_KEY")
	else:
		controls.set_connection("Cloud service ready · " + str(health.get("model", "")))

func _task_progress(task: SandboxTask) -> String:
	var arrived := _task_arrival_count(task)
	var text := "%d/%d arrived" % [arrived, task.soldier_ids.size()]
	if task.action == "follow_player":
		text = "%d/%d in position · following player (ongoing)" % [arrived, task.soldier_ids.size()]
	elif task.action == "patrol":
		text += " · patrol to %s · leg %d (ongoing)" % [task.endpoint, task.leg_count + 1]
	if task.status in ["paused", "blocked"]:
		text += " · %s: %s" % [task.status, task.blocked_reason]
	elif task.status == "complete":
		text += " · movement complete; holding" if task.action == "move_to" else " · formation complete; holding"
	elif not task.is_continuous():
		text += " · %d still moving" % (task.soldier_ids.size() - arrived)
	return text

func _refresh_progress() -> void:
	if controls == null:
		return
	var group_data := groups.duplicate(true)
	var all_ids: Array[String] = []
	for soldier in soldiers:
		all_ids.append(soldier.soldier_id)
	group_data["all"] = all_ids
	controls.set_groups(group_data)
	var summaries: Array[String] = []
	var details: Array[String] = []
	var task_ids: Array = tasks.keys()
	task_ids.sort()
	for task_id: String in task_ids:
		var task: SandboxTask = tasks[task_id]
		var text := _task_progress(task)
		summaries.append(text)
		details.append("%s · %d soldiers · %s\n%s" % [task.id, task.soldier_ids.size(), task.source, text])
	controls.set_task_list(details)
	if not summaries.is_empty():
		controls.set_progress(" | ".join(summaries))
		return
	var latest: SandboxTask = completed_tasks.get(_latest_task_id)
	if latest != null:
		controls.set_progress(_task_progress(latest))
	else:
		controls.set_progress("%d soldiers ready · campaign saves are not used" % soldiers.size())

func _show_error(message: String) -> void:
	last_error = message
	controls.set_status(message, true)

func _get_soldier_path(start: Vector2, destination: Vector2, soldier_id: String, selected: Array = []) -> PackedVector2Array:
	var moving_ids: Array = selected
	if selected.is_empty():
		var task: SandboxTask = tasks.get(soldier_tasks.get(soldier_id, ""))
		moving_ids = task.soldier_ids if task != null else []
	var occupied := PackedVector2Array([player.global_position])
	for soldier in soldiers:
		if soldier.soldier_id == soldier_id:
			continue
		var stationary := not moving_ids.has(soldier.soldier_id) or soldier.task_state in ["holding", "blocked", "idle"]
		var blocks_route := soldier.global_position.distance_to(destination) >= SandboxFormationPlanner.MIN_SPACING
		if not moving_ids.has(soldier.soldier_id) or (selected.is_empty() and (stationary or blocks_route)):
			occupied.append(soldier.global_position)
	return tiled_loader.get_walk_path_avoiding(start, destination, occupied, SandboxSoldier.AVOIDANCE_RADIUS * 2.0)

func _find_spawn(wanted: Vector2) -> Vector2:
	for radius in range(9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var point := wanted + Vector2(x, y) * 16.0
				if not SandboxFormationPlanner.body_fits(tiled_loader, point):
					continue
				var clear := true
				for existing: Vector2 in _spawn_positions.values():
					if point.distance_to(existing) < 20.0:
						clear = false
				if clear:
					return point
	push_error("No open sandbox spawn was found.")
	return wanted

func _rebuild_markers() -> void:
	for child in _marker_root.get_children():
		child.free()
	for id: String in landmarks:
		var label := Label.new()
		label.name = "Landmark" + id
		label.text = id
		label.position = landmarks[id] + Vector2(-6, -26)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", LANDMARK_COLORS[id])
		label.add_theme_color_override("font_shadow_color", Color("1c1730"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		_marker_root.add_child(label)
	_marker_root.queue_redraw()

func _draw_markers() -> void:
	for id: String in landmarks:
		var point: Vector2 = landmarks[id]
		var color: Color = LANDMARK_COLORS[id]
		_marker_root.draw_arc(point, 8.0, 0.0, TAU, 20, color, 2.0)
		_marker_root.draw_line(point - Vector2(4, 0), point + Vector2(4, 0), color, 1.0)
		_marker_root.draw_line(point - Vector2(0, 4), point + Vector2(0, 4), color, 1.0)
	for records: Dictionary in [tasks, completed_tasks]:
		for task: SandboxTask in records.values():
			var points: Array[Vector2] = []
			for point: Vector2 in task.assignments.values():
				points.append(point)
			points.sort_custom(func(left: Vector2, right: Vector2) -> bool: return left.x < right.x if left.x != right.x else left.y < right.y)
			if task.action == "form_line" and points.size() > 1:
				_marker_root.draw_line(points[0], points[-1], Color(1, 0.85, 0.45, 0.55), 1.0)
			var color := Color("5fd6d3") if task.action == "follow_player" else Color("f5c34c")
			for point in points:
				_marker_root.draw_circle(point, 2.0, color)

func _ensure_input_actions() -> void:
	var bindings := {"sandbox_left": [KEY_A, KEY_LEFT], "sandbox_right": [KEY_D, KEY_RIGHT], "sandbox_up": [KEY_W, KEY_UP], "sandbox_down": [KEY_S, KEY_DOWN]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for keycode: Key in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)
