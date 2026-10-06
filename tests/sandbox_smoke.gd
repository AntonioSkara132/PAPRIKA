extends Node

var _checks := 0
var _failures := 0
var _overlap_seen := false
var _save_bytes := PackedByteArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/sandbox.tscn") as PackedScene
	_check(scene != null, "standalone sandbox scene loads")
	if scene == null:
		_finish()
		return
	GameState.gold = 987
	GameState.player_position = Vector2(41, 73)
	GameState.play_seconds = 123.0
	GameState.field_regrowth = {"sandbox_isolation_test": 120.0}
	var processing_before := GameState.is_processing()
	var campaign_before := _campaign_snapshot()
	_save_bytes = "{\"sandbox_isolation_test\":\"leave this save unchanged\"}\n".to_utf8_buffer()
	var save := FileAccess.open("user://paprika_save.json", FileAccess.WRITE)
	_check(save != null, "isolated test save can be written")
	if save != null:
		save.store_buffer(_save_bytes)
		save.close()
	var world := scene.instantiate() as SoldierSandbox
	_check(world != null, "sandbox scene uses the standalone world script")
	if world == null:
		_finish()
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(not GameState.is_processing(), "campaign time and regrowth stop while sandbox is active")
	_check(world.tiled_loader != null and world.tiled_loader.map_loaded, "sandbox loads the existing Paprika map")
	_check(world.tiled_loader.scenery_only and world.tiled_loader.map_size == Vector2(1664, 1920), "scenery-only mode preserves Paprika dimensions")
	_check(world.soldiers.size() == 12, "twelve soldiers spawn")
	_check(world.actors_root.get_child_count() == 13, "sandbox has only the player and twelve soldiers")
	_check(world.player is SandboxPlayer and world.player.get_node_or_null("Camera") is Camera2D, "sandbox has an isolated player and camera")
	_check(SandboxFormationPlanner.body_fits(world.tiled_loader, world.player.global_position), "player starts on open ground")
	_check(get_tree().get_nodes_in_group("interactable").is_empty(), "campaign services and harvesting are not interactable")
	_check(world.tiled_loader.get_node("FieldPlots").get_child_count() == 0, "campaign field behaviors are not created")
	var textures: Array[String] = []
	var spawns := _positions(world)
	var known: Array[String] = []
	for soldier in world.soldiers:
		known.append(soldier.soldier_id)
		var sprite := soldier.get_node("Sprite") as Sprite2D
		_check(sprite != null and sprite.texture != null and sprite.texture.get_size() == Vector2(16, 24), "%s uses matching small military art" % soldier.soldier_id)
		if sprite != null and sprite.texture != null:
			textures.append(sprite.texture.resource_path)
		_check(SandboxFormationPlanner.body_fits(world.tiled_loader, soldier.global_position), "%s starts on open ground" % soldier.soldier_id)
		_check(soldier._avoidance != null and soldier._avoidance.avoidance_enabled and (soldier.collision_mask & 4) != 0, "%s has avoidance and soldier collision enabled" % soldier.soldier_id)
		_check(soldier._avoidance.radius >= 5.0 and SandboxFormationPlanner.MIN_SPACING > soldier._avoidance.radius * 2.0, "%s avoidance covers its collider and leaves space between destinations" % soldier.soldier_id)
	_check(textures.all(func(path: String) -> bool: return path.begins_with("res://assets/art/space_military_base/station_soldier_")), "no civilian textures are used for soldiers")
	_check(_has_unique_ids(known), "soldiers have unique stable IDs")
	_check(_positions_do_not_overlap(world), "starting soldier bodies do not overlap")
	for id: String in ["A", "B", "C"]:
		_check(world.landmarks.has(id) and world.get_node("Landmarks").get_node_or_null("Landmark" + id) != null, "starter landmark %s is visible" % id)
		_check(SandboxFormationPlanner.body_fits(world.tiled_loader, world.landmarks[id]), "starter landmark %s is on open ground" % id)
	await _test_typing_and_ui(world)
	world.reset_sandbox()
	world.run_offline_example()
	_check(world.active_assignments.size() == 12, "offline example assigns a position to every soldier")
	_check(not world.controls.progress_label.text.contains("formation complete"), "accepting an order does not claim immediate completion")
	_check(world.controls.status_label.text.contains("not an LLM"), "offline example is clearly labelled as a fixed order")
	var complete := await _wait_for_formation(world)
	_check(complete, "all twelve soldiers physically reach the line and hold")
	if not complete:
		_print_soldier_states(world)
	_check(not _overlap_seen, "soldier bodies do not overlap while forming the line")
	world._refresh_progress()
	_check(world.controls.progress_label.text.contains("12/12 arrived") and world.controls.progress_label.text.contains("formation complete"), "progress reports completion only after actual arrival")
	var expected_direction: Vector2 = world.landmarks["C"] - (world.landmarks["A"] + world.landmarks["B"]) * 0.5
	var expected_facing := Vector2(signf(expected_direction.x), 0) if absf(expected_direction.x) >= absf(expected_direction.y) else Vector2(0, signf(expected_direction.y))
	var assigned_points: Array[Vector2] = []
	for soldier in world.soldiers:
		_check(soldier.global_position.distance_to(world.active_assignments.get(soldier.soldier_id, Vector2.INF)) <= SandboxFormationPlanner.ARRIVAL_DISTANCE, "%s reaches its exact assigned position" % soldier.soldier_id)
		_check(soldier.task_state == "holding" and soldier.facing == expected_facing, "%s holds the shared facing toward C" % soldier.soldier_id)
		if world.active_assignments.has(soldier.soldier_id):
			assigned_points.append(world.active_assignments[soldier.soldier_id])
	_check(_unique_points(assigned_points), "each soldier has a distinct formation position")
	var held := _positions(world)
	await _frames(60)
	_check(_same_positions(world, held), "completed soldiers remain in place")
	await _capture_screenshot()
	await _test_cancellation_and_reset(world, spawns)
	await _test_timeout_reporting(world)
	_test_bad_orders_and_replies(world, known)
	_test_local_responses(world, known)
	await _test_move_orders(world, known)
	await _test_instant_stop(world, known)
	await _test_groups_and_recurring_tasks(world, known)
	if OS.get_environment("SANDBOX_HTTP_TEST") == "1":
		await _test_http_fixture(world)
	if OS.get_environment("SANDBOX_LOCAL_TEST") == "1":
		await _test_http_local(world)
	if OS.get_environment("SANDBOX_MOVE_LOCAL_TEST") == "1":
		await _test_http_local_move(world, known)
	_check(_campaign_snapshot() == campaign_before, "sandbox movement, orders and resets do not change campaign state")
	_check(FileAccess.get_file_as_bytes("user://paprika_save.json") == _save_bytes, "sandbox does not overwrite the campaign save")
	remove_child(world)
	world.free()
	_check(GameState.is_processing() == processing_before, "freeing the sandbox restores campaign processing")
	_finish()

func _test_typing_and_ui(world: SoldierSandbox) -> void:
	world.controls.order_input.grab_focus()
	await get_tree().process_frame
	_check(world.controls.is_typing(), "text input exposes its typing state")
	var start := world.player.global_position
	Input.action_press("sandbox_right")
	await _frames(20)
	Input.action_release("sandbox_right")
	_check(world.player.global_position.distance_to(start) < 0.01, "typing movement letters does not move the player")
	world.controls.order_input.release_focus()
	await get_tree().process_frame
	Input.action_press("sandbox_right")
	await _frames(10)
	Input.action_release("sandbox_right")
	_check(world.player.global_position.distance_to(start) > 3.0, "movement still works after text input loses focus")
	world.select_landmark("A")
	var before := world.landmarks.duplicate()
	var revision := world.request_revision
	var panel := world.controls.get_node("SandboxControls/OrderPanel") as Control
	var point := panel.get_global_rect().position + Vector2(15, panel.size.y - 3)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	click.global_position = point
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	_check(world.landmarks == before and world.request_revision == revision, "clicks on the order panel do not place a landmark")
	var map_point: Vector2 = world.landmarks["C"]
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	map_click.position = world.get_global_transform_with_canvas() * map_point
	map_click.global_position = map_click.position
	get_viewport().push_input(map_click, true)
	await get_tree().process_frame
	map_click = map_click.duplicate()
	map_click.pressed = false
	get_viewport().push_input(map_click, true)
	await get_tree().process_frame
	_check(world.landmarks["A"].distance_to(map_point) < 0.1 and world.request_revision > revision, "a real map click places the selected landmark at the intended world position")

func _test_cancellation_and_reset(world: SoldierSandbox, spawns: Dictionary) -> void:
	world.reset_sandbox()
	world.run_offline_example()
	await _frames(25)
	var revision := world.request_revision
	world.stop_orders()
	var stopped := _positions(world)
	await _frames(45)
	_check(world.request_revision > revision and world.active_assignments.is_empty(), "Stop invalidates the current order")
	_check(_same_positions(world, stopped) and _all_states(world, "idle"), "Stop keeps every soldier at its current position")
	world.run_offline_example()
	await _frames(25)
	world.reset_sandbox()
	await _frames(5)
	_check(_same_positions(world, spawns), "Reset restores every soldier's initial position")
	_check(world.player.global_position == SoldierSandbox.PLAYER_START and world.landmarks == SoldierSandbox.DEFAULT_LANDMARKS, "Reset restores player and starter landmarks")
	_check(world.active_assignments.is_empty() and _all_states(world, "idle"), "Reset clears movement tasks")
	world.run_offline_example()
	await _frames(15)
	revision = world.request_revision
	var moved := SoldierSandbox.DEFAULT_LANDMARKS["A"] + Vector2(0, 16)
	_check(world.set_landmark("A", moved), "a landmark can be moved to open ground")
	_check(world.request_revision > revision and world.active_assignments.is_empty() and _all_states(world, "idle"), "editing a landmark cancels the previous formation")
	var markers := world.landmarks.duplicate()
	revision = world.request_revision
	_check(not world.set_landmark("A", Vector2(-100, -100)), "blocked landmark placement is rejected")
	_check(not world.set_landmark("D", Vector2(824, 552)), "unknown landmark IDs are rejected")
	_check(not world.set_landmark("B", Vector2(NAN, 40)), "nonfinite landmark placement is rejected")
	_check(world.landmarks == markers and world.request_revision == revision, "bad landmark placement does not alter landmarks or orders")
	world.reset_sandbox()

func _test_instant_stop(world: SoldierSandbox, ids: Array[String]) -> void:
	var service_valid := world._service_valid
	world._service_valid = false
	for prompt: String in ["stop", " STOP ", "\tStOp\n"]:
		world.reset_sandbox()
		world.run_offline_example()
		await _frames(3)
		var revision := world.request_revision
		var pending := HTTPRequest.new()
		world.add_child(pending)
		world._pending_request = pending
		world.controls.set_busy(true)
		world.submit_order(prompt)
		_check(world.request_revision == revision + 1 and world._pending_request == null and pending.is_queued_for_deletion(), "reserved stop cancels a pending request without creating another")
		_check(world.active_assignments.is_empty() and world._active_action.is_empty() and _all_states(world, "idle"), "reserved stop immediately cancels every movement task")
		_check(world.last_error.is_empty() and world.controls.status_label.text.begins_with("Stopped."), "reserved stop works without a valid service and reports local cancellation")
		_check(world.soldiers.all(func(soldier: SandboxSoldier) -> bool: return soldier.velocity == Vector2.ZERO), "reserved stop immediately clears soldier velocities")
		var stopped := _positions(world)
		var order := {"action": "form_line", "soldier_ids": ids.duplicate(), "start": "A", "end": "B", "facing": "C", "group_name": null, "message": "Late reply after keyword stop."}
		var response := {"request_id": revision, "mode": "local", "order": order}
		world._on_order_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(response).to_utf8_buffer(), revision)
		await _frames(5)
		_check(world.active_assignments.is_empty() and _same_positions(world, stopped), "a late reply after reserved stop cannot restart soldiers")
	for prompt: String in ["stop soldier_01", "do not stop", "stop."]:
		world.submit_order(prompt)
		_check(world.last_error.contains("SANDBOX_SERVICE_URL"), "a sentence or punctuation containing stop follows normal interpretation instead of the reserved keyword")
	world.reset_sandbox()
	world.run_offline_example()
	world.controls.order_input.text = " sToP "
	world.controls.order_input.grab_focus()
	await get_tree().process_frame
	var revision := world.request_revision
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter, true)
	await get_tree().process_frame
	enter = enter.duplicate()
	enter.pressed = false
	get_viewport().push_input(enter, true)
	await get_tree().process_frame
	_check(world.request_revision == revision + 1 and world.active_assignments.is_empty() and _all_states(world, "idle") and world._pending_request == null, "typing stop and pressing Enter stops locally through the actual text field")
	world.controls.order_input.release_focus()
	world._service_valid = service_valid
	world.reset_sandbox()

func _group_order(ids: Array[String], name: String) -> Dictionary:
	return {"action": "create_group", "soldier_ids": ids.duplicate(), "start": null, "end": null, "facing": null, "group_name": name, "message": "Scripted group creation; no model was used."}

func _follow_order(ids: Array[String]) -> Dictionary:
	return {"action": "follow_player", "soldier_ids": ids.duplicate(), "start": null, "end": null, "facing": null, "group_name": null, "message": "Scripted following test; no model was used."}

func _patrol_order(ids: Array[String], start: String = "A", end: String = "B") -> Dictionary:
	return {"action": "patrol", "soldier_ids": ids.duplicate(), "start": start, "end": end, "facing": null, "group_name": null, "message": "Scripted patrol test; no model was used."}

func _task_for(world: SoldierSandbox, soldier_id: String) -> Variant:
	return world.tasks.get(world.soldier_tasks.get(soldier_id, ""))

func _test_groups_and_recurring_tasks(world: SoldierSandbox, ids: Array[String]) -> void:
	world.reset_sandbox()
	var alpha: Array[String] = [ids[0], ids[1]]
	var beta: Array[String] = [ids[-2], ids[-1]]
	var before := _positions(world)
	_check(world.execute_order(_group_order(alpha, "Alpha")), "a named group can be created with a normalized name")
	_check(world.groups.get("alpha") == alpha and world.tasks.is_empty() and _same_positions(world, before), "group creation changes membership without creating a task or moving soldiers")
	_check(world.execute_order(_group_order(beta, "beta")), "a second independent group can be created")
	var context := world.order_context()
	_check(context["groups"]["all"].size() == 12 and context["groups"]["alpha"] == alpha and context["groups"]["beta"] == beta, "request context contains immutable all and named selections")
	context["groups"]["alpha"].clear()
	_check(world.groups["alpha"] == alpha, "request context is a copy rather than a mutable group reference")
	var saved_groups := world.groups.duplicate(true)
	for name: String in ["all", "ALPHA", "", "bad name", "a_group_name_longer_than_twenty_four"]:
		_check(not world.execute_order(_group_order(alpha, name)) and world.groups == saved_groups, "reserved, duplicate and invalid group names leave existing groups unchanged")
	_check(not world.execute_order(_group_order([], "empty")), "an empty named group is rejected")
	_check(not world.execute_order(_group_order([ids[0], ids[0]], "repeated")), "repeated group members are rejected")
	_check(not world.execute_order(_group_order(["unknown"], "unknown")), "unknown group members are rejected")
	for index in range(6):
		_check(world.execute_order(_group_order(alpha, "team_%d" % index)), "bounded overlapping named groups can be created")
	_check(world.groups.size() == 8 and not world.execute_order(_group_order(beta, "ninth")), "a ninth named group is rejected")
	world.stop_orders()
	_check(world.groups.size() == 8, "Stop preserves named groups")
	world.reset_sandbox()
	_check(world.groups.is_empty() and world.order_context()["groups"].size() == 1, "Reset clears named groups while retaining derived all")
	await _test_concurrent_follow_and_patrol(world, ids, alpha, beta)
	await _test_preserved_line_follow(world, ids)
	world.reset_sandbox()

func _test_concurrent_follow_and_patrol(world: SoldierSandbox, ids: Array[String], alpha: Array[String], beta: Array[String]) -> void:
	world.reset_sandbox()
	world.player.global_position = SoldierSandbox.DEFAULT_LANDMARKS["C"]
	world.player.facing = Vector2.UP
	world.execute_order(_group_order(alpha, "alpha"))
	world.execute_order(_group_order(beta, "beta"))
	var accepted := world.execute_order(_follow_order(alpha), "Scripted following — not an LLM")
	_check(accepted, "a selected group can begin following the player")
	if not accepted:
		printerr("  Follow acceptance: ", world.last_error)
		world.reset_sandbox()
		return
	var follow: Variant = _task_for(world, alpha[0])
	_check(follow != null and follow.action == "follow_player" and follow.soldier_ids == alpha, "following owns exactly its selected soldiers")
	if follow == null:
		world.reset_sandbox()
		return
	var offsets: Dictionary = follow.follow_offsets.duplicate(true)
	_check(await _wait_for_members(world, alpha), "followers physically catch up while the player is stationary")
	_check(world.tasks.has(world.soldier_tasks.get(alpha[0], "")), "catching up does not complete the following task")
	var leader_before := world.player.global_position
	Input.action_press("sandbox_up")
	await _checked_frames(world, 15)
	Input.action_release("sandbox_up")
	Input.action_press("sandbox_right")
	await _checked_frames(world, 15)
	Input.action_release("sandbox_right")
	_check(world.player.global_position.distance_to(leader_before) > 10.0, "the follow test moves the actual player through input")
	_check(await _wait_for_members(world, alpha), "followers catch up after player movement and a turn")
	_check(follow.follow_offsets == offsets and not _overlap_seen, "following keeps stable slots and avoids both soldiers and the leader")
	world._refresh_progress()
	_check(world.controls.progress_label.text.to_lower().contains("follow") and not world.controls.progress_label.text.contains("movement complete"), "stationary following remains labelled as an ongoing task")
	accepted = world.execute_order(_patrol_order(beta), "Scripted patrol — not an LLM")
	_check(accepted, "a second group can patrol while the first follows")
	if not accepted:
		printerr("  Patrol acceptance: ", world.last_error)
		world.reset_sandbox()
		return
	var patrol: Variant = _task_for(world, beta[0])
	var patrol_id := str(world.soldier_tasks.get(beta[0], ""))
	_check(patrol != null and patrol.action == "patrol" and world.tasks.size() == 2 and _task_for(world, alpha[0]) == follow, "independent follow and patrol tasks remain active together")
	if patrol == null:
		world.reset_sandbox()
		return
	var owners := world.soldier_tasks.duplicate()
	_check(world.execute_order(_group_order([alpha[0], beta[0]], "mixed")) and world.soldier_tasks == owners, "creating an overlapping group does not interrupt either task")
	var clarification := {"action": "clarify", "soldier_ids": [], "start": null, "end": null, "facing": null, "group_name": null, "message": "A scripted clarification."}
	_check(world.execute_order(clarification) and world.soldier_tasks == owners, "clarification leaves current task ownership unchanged")
	var invalid := _follow_order(alpha)
	invalid["soldier_ids"] = ["missing"]
	_check(not world.execute_order(invalid) and world.soldier_tasks == owners, "a rejected order does not cancel unrelated tasks")
	var service_valid := world._service_valid
	world._service_valid = false
	world.submit_order("Let alpha follow me.")
	_check(world.soldier_tasks == owners and _task_for(world, alpha[0]) == follow and _task_for(world, beta[0]) == patrol, "a failed interpretation request leaves both tasks running")
	world._service_valid = service_valid
	var cycle := await _wait_for_patrol_legs(world, patrol_id, 3)
	_check(cycle, "patrol physically completes A then B then A")
	if not cycle:
		printerr("  Patrol state: ", patrol.status, " · ", patrol.blocked_reason)
		_print_soldier_states(world)
	_check(world.tasks.has(patrol_id) and patrol.status == "active" and _task_for(world, alpha[0]) == follow and not _overlap_seen, "patrol keeps running after a full cycle and does not finish or overlap followers")
	var stop_selected := {"action": "stop", "soldier_ids": [beta[0]], "start": null, "end": null, "facing": null, "group_name": null, "message": "Stop one patrol member."}
	_check(world.execute_order(stop_selected) and not world.soldier_tasks.has(beta[0]) and _task_for(world, beta[1]) == patrol and _task_for(world, alpha[0]) == follow, "selected Stop removes only one member and preserves the other tasks")
	_check(patrol.soldier_ids == [beta[1]] and not patrol.assignments.has(beta[0]), "partial patrol cancellation removes the soldier from later legs")
	var substitute: Array[String] = [alpha[0]]
	var move := _move_order(substitute)
	move["end"] = "B"
	_check(world.execute_order(move) and _task_for(world, alpha[0]) != follow and _task_for(world, alpha[1]) == follow and _task_for(world, beta[1]) == patrol, "a new movement order replaces only selected participants")
	var revision := world.request_revision
	world.submit_order(" STOP ")
	var stopped := _positions(world)
	await _checked_frames(world, 45)
	_check(world.tasks.is_empty() and world.soldier_tasks.is_empty() and world.active_assignments.is_empty() and _same_positions(world, stopped), "the instant keyword cancels recurring tasks and prevents later updates")
	_check(world.groups.has("alpha") and world.groups.has("beta") and world.groups.has("mixed"), "instant Stop preserves group definitions")
	var stale := {"request_id": revision, "mode": "local", "order": _follow_order(alpha)}
	_check(not world.accept_response(stale, revision) and world.tasks.is_empty(), "a late follow reply cannot restart tasks after instant Stop")
	world.reset_sandbox()

func _test_preserved_line_follow(world: SoldierSandbox, ids: Array[String]) -> void:
	world.reset_sandbox()
	var selected: Array[String] = [ids[0], ids[1], ids[2]]
	world.landmarks["A"] = Vector2(936, 600)
	world.landmarks["B"] = Vector2(936, 648)
	world.landmarks["C"] = Vector2(960, 624)
	var line := {"action": "form_line", "soldier_ids": selected.duplicate(), "start": "A", "end": "B", "facing": "C", "group_name": null, "message": "Prepare a short line for following."}
	var accepted := world.execute_order(line)
	var formed := false
	if accepted:
		formed = await _wait_for_members(world, selected)
	_check(accepted and formed, "a short selected line physically forms before following")
	if not formed:
		_print_soldier_states(world)
		world.reset_sandbox()
		return
	_check(world.tasks.is_empty() and world.soldier_tasks.is_empty(), "a completed line has no running scheduler task")
	var previous := world.active_assignments.duplicate(true)
	var expected := SandboxFormationPlanner.make_follow_offsets(selected, previous, Vector2.RIGHT)
	var occupied := PackedVector2Array()
	for soldier in world.soldiers:
		if not selected.has(soldier.soldier_id):
			occupied.append(soldier.global_position)
	var found := false
	for y in range(576, 673, 16):
		for x in range(904, 969, 16):
			var candidate := Vector2(x, y)
			if not SandboxFormationPlanner.body_fits(world.tiled_loader, candidate):
				continue
			var clear := true
			for soldier in world.soldiers:
				if candidate.distance_to(soldier.global_position) < 16.0:
					clear = false
			if not clear:
				continue
			var plan := SandboxFormationPlanner.plan_follow(selected, _positions(world), candidate, Vector2.UP, expected, world.tiled_loader, occupied)
			if plan["ok"]:
				world.player.global_position = candidate
				world.player.facing = Vector2.UP
				found = true
				break
		if found:
			break
	_check(found, "the map contains a clear leader position for the preserved line")
	if not found:
		world.reset_sandbox()
		return
	accepted = world.execute_order(_follow_order(selected))
	_check(accepted, "a formed line can become a following task")
	var follow: Variant = _task_for(world, selected[0])
	if accepted and follow != null:
		_check(follow.follow_offsets == expected, "following preserves previous line slots rather than replacing them with two columns")
		var caught_up := await _wait_for_members(world, selected)
		_check(caught_up, "the preserved line physically catches up to its leader")
		if not caught_up:
			printerr("  Preserved follow state: ", follow.status, " · ", follow.blocked_reason)
			_print_soldier_states(world)
		_check(not _overlap_seen, "preserved-line following avoids soldier and leader overlap")
		_check(world.tasks.size() == 1 and world.completed_tasks.is_empty(), "following replaces selected completion records without creating extra tasks")
		var saved_slots: Dictionary = follow.follow_offsets.duplicate(true)
		var previous_markers := world.landmarks.duplicate()
		world.landmarks["A"] = world.player.global_position
		world.landmarks["B"] = world.player.global_position + Vector2(0, 8)
		_check(not world.execute_order(_patrol_order(selected)) and _task_for(world, selected[0]) == follow and follow.follow_offsets == saved_slots, "a physically too-short patrol is rejected without cancelling following")
		world.landmarks = previous_markers
		_check(world.set_landmark("C", Vector2(936, 648)) and world.tasks.is_empty() and world.soldier_tasks.is_empty(), "editing a landmark cancels recurring tasks")
	world.reset_sandbox()

func _wait_for_members(world: SoldierSandbox, ids: Array[String], timeout_frames: int = 1500) -> bool:
	for tick in range(timeout_frames):
		await _checked_frames(world, 1)
		var complete := true
		for soldier in world.soldiers:
			if not ids.has(soldier.soldier_id):
				continue
			if soldier.task_state == "blocked":
				return false
			complete = complete and soldier.task_state == "holding" and soldier.global_position.distance_to(soldier.destination) <= SandboxFormationPlanner.ARRIVAL_DISTANCE
		if complete:
			await _checked_frames(world, 1)
			return true
	return false

func _wait_for_patrol_legs(world: SoldierSandbox, task_id: String, legs: int, timeout_frames: int = 3000) -> bool:
	for tick in range(timeout_frames):
		await _checked_frames(world, 1)
		var task: Variant = world.tasks.get(task_id)
		if task == null or task.status == "blocked":
			return false
		if task.leg_count >= legs:
			return true
	return false

func _checked_frames(world: SoldierSandbox, count: int) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame
		if not _positions_do_not_overlap(world):
			_overlap_seen = true

func _test_timeout_reporting(world: SoldierSandbox) -> void:
	world.reset_sandbox()
	world.run_offline_example()
	var soldier := world.soldiers[0]
	soldier._elapsed = soldier._timeout + 1.0
	await _frames(3)
	_check(soldier.task_state == "blocked" and soldier.blocked_reason.contains("Timed out"), "a movement timeout becomes a reported failure instead of a successful arrival")
	world._refresh_progress()
	_check(world.controls.progress_label.text.contains("blocked") and world.controls.progress_label.text.contains(soldier.soldier_id) and not world.controls.progress_label.text.contains("formation complete"), "progress identifies the timed-out soldier without claiming completion")
	world.stop_orders()
	_check(soldier.task_state == "idle" and soldier.blocked_reason.is_empty(), "Stop clears a failed movement task")
	world.reset_sandbox()

func _test_bad_orders_and_replies(world: SoldierSandbox, ids: Array[String]) -> void:
	var valid := {"action": "form_line", "soldier_ids": ids.duplicate(), "start": "A", "end": "B", "facing": "C", "group_name": null, "message": "Fixture line."}
	var old_revision := world.request_revision
	world.stop_orders()
	var revision := world.request_revision
	var response := {"request_id": old_revision, "mode": "fixture", "order": valid}
	_check(not world.accept_response(response, old_revision), "a response from before Stop is ignored")
	_check(world.active_assignments.is_empty() and world.request_revision == revision, "a stale response cannot restart movement")
	response["request_id"] = revision + 1
	_check(not world.accept_response(response, revision), "a response with the wrong echoed ID is rejected")
	response["request_id"] = true
	_check(not world.accept_response(response, revision), "a boolean request ID is rejected")
	response["request_id"] = revision
	response["extra"] = "unexpected"
	_check(not world.accept_response(response, revision), "extra response keys are rejected")
	response.erase("extra")
	response["mode"] = "pretend"
	_check(not world.accept_response(response, revision), "an unknown response mode is rejected")
	response["mode"] = "fixture"
	var malformed := valid.duplicate(true)
	malformed["soldier_ids"] = ["missing", "soldier_02"]
	response["order"] = malformed
	_check(not world.accept_response(response, revision), "a response containing unknown soldiers is rejected")
	world._on_order_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "not json".to_utf8_buffer(), revision)
	_check(world.last_error.contains("invalid JSON") and world.active_assignments.is_empty(), "invalid JSON produces an error without movement")
	world._on_order_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), revision)
	_check(world.last_error.contains("unavailable") and world.active_assignments.is_empty(), "connection failure produces an error without movement")
	var unknown := valid.duplicate(true)
	unknown["action"] = "form_square"
	_check(not world.execute_order(unknown), "unsupported orders do not execute")
	world.landmarks["B"] = world.landmarks["A"] + Vector2(0, 20)
	_check(not world.execute_order(valid) and world.active_assignments.is_empty(), "too-short formations are rejected before movement")
	_check(_all_states(world, "idle"), "rejected orders leave soldiers stopped")
	world.reset_sandbox()

func _move_order(ids: Array[String], facing: Variant = null) -> Dictionary:
	return {"action": "move_to", "soldier_ids": ids.duplicate(), "start": null, "end": "C", "facing": facing, "group_name": null, "message": "Scripted movement test; no model was used."}

func _test_move_orders(world: SoldierSandbox, ids: Array[String]) -> void:
	world.reset_sandbox()
	var markers := world.landmarks.duplicate()
	var accepted := world.execute_order(_move_order(ids), "Scripted movement test — not an LLM")
	_check(accepted and world.active_assignments.size() == 12, "movement assigns all twelve soldiers near C")
	_check(world._active_action == "move_to" and world.controls.status_label.text.contains("near C"), "movement status describes the requested destination instead of a line")
	_check(not world.controls.progress_label.text.contains("movement complete"), "accepting movement does not claim arrival")
	if accepted:
		_check(_move_destinations_fit(world), "movement destinations are reachable, separated and within the bounded area")
		var complete := await _wait_for_formation(world)
		_check(complete, "all twelve soldiers physically arrive near C")
		if not complete:
			_print_soldier_states(world)
		world._refresh_progress()
		_check(world.controls.progress_label.text.contains("12/12 arrived") and world.controls.progress_label.text.contains("movement complete") and not world.controls.progress_label.text.contains("formation complete"), "movement completion is based on actual arrivals and labelled accurately")
		_check(_positions_do_not_overlap(world) and not _overlap_seen, "soldier bodies do not overlap during or after moving near C")
		var held := _positions(world)
		await _frames(45)
		_check(_same_positions(world, held), "soldiers hold their positions after movement")
	_check(world.landmarks == markers, "movement leaves the requested landmarks unchanged")
	world.reset_sandbox()
	var subset: Array[String] = [ids[0], ids[1]]
	var before := _positions(world)
	accepted = world.execute_order(_move_order(subset, "A"), "Scripted subset test — not an LLM")
	_check(accepted and world.active_assignments.size() == 2, "a subset movement assigns only the two requested soldiers")
	if accepted:
		var complete := await _wait_for_formation(world)
		_check(complete, "selected soldiers physically reach C while the others hold")
		if not complete:
			_print_soldier_states(world)
		var direction: Vector2 = world.landmarks["A"] - world.landmarks["C"]
		var facing := Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
		for soldier in world.soldiers:
			if subset.has(soldier.soldier_id):
				_check(soldier.task_state == "holding" and soldier.facing == facing, "%s holds the requested movement facing" % soldier.soldier_id)
			else:
				_check(soldier.global_position.distance_to(before[soldier.soldier_id]) < 0.01 and soldier.task_state == "idle", "%s remains stationary during subset movement" % soldier.soldier_id)
		_check(_move_destinations_fit(world) and _positions_do_not_overlap(world), "subset destinations avoid stationary soldiers and preserve spacing")
	world.reset_sandbox()
	var single: Array[String] = [ids[-1]]
	accepted = world.execute_order(_move_order(single))
	_check(accepted and world.active_assignments.size() == 1, "one soldier can receive a movement order")
	if accepted:
		var complete := await _wait_for_formation(world)
		_check(complete, "one soldier physically reaches its movement destination")
		_check(world.soldiers[-1].final_facing == Vector2.ZERO and world.soldiers[-1].facing.length_squared() > 0.0, "unspecified facing preserves a valid walking direction")
	world.reset_sandbox()
	_check(world.execute_order(_move_order(ids)), "movement can start before cancellation")
	await _frames(20)
	var revision := world.request_revision
	world.stop_orders()
	var stopped := _positions(world)
	await _frames(30)
	_check(world.request_revision > revision and world._active_action.is_empty() and world.active_assignments.is_empty(), "Stop clears movement action and assignments")
	_check(_same_positions(world, stopped) and _all_states(world, "idle"), "stopped movement does not resume")
	var stale := {"request_id": revision, "mode": "local", "order": _move_order(ids)}
	_check(not world.accept_response(stale, revision), "a stale movement reply cannot restart stopped soldiers")
	_check(world.execute_order(_move_order(ids)), "movement can restart after Stop")
	await _frames(15)
	_check(world.set_landmark("C", SoldierSandbox.DEFAULT_LANDMARKS["C"] + Vector2(0, 16)), "movement destination can be edited on open ground")
	_check(world._active_action.is_empty() and world.active_assignments.is_empty() and _all_states(world, "idle"), "moving the destination cancels movement")
	world.reset_sandbox()
	world.landmarks["C"] = Vector2(-100, -100)
	before = _positions(world)
	_check(not world.execute_order(_move_order(ids)), "a blocked movement destination is rejected")
	_check(world.active_assignments.is_empty() and _same_positions(world, before) and _all_states(world, "idle"), "a rejected movement order does not move any soldiers")
	world.reset_sandbox()
	_check(world._active_action.is_empty() and world.landmarks == SoldierSandbox.DEFAULT_LANDMARKS, "Reset clears movement state and restores landmarks")

func _move_destinations_fit(world: SoldierSandbox) -> bool:
	var points: Array[Vector2] = []
	for id: String in world.active_assignments:
		var point: Vector2 = world.active_assignments[id]
		if not SandboxFormationPlanner.body_fits(world.tiled_loader, point) or point.distance_to(world.landmarks["C"]) > SandboxFormationPlanner.MOVE_RADIUS + 0.01:
			return false
		if point.distance_to(world.player.global_position) < SandboxFormationPlanner.MIN_SPACING - 0.01:
			return false
		for soldier in world.soldiers:
			if not world.active_assignments.has(soldier.soldier_id) and point.distance_to(soldier.global_position) < SandboxFormationPlanner.MIN_SPACING - 0.01:
				return false
		for other in points:
			if point.distance_to(other) < SandboxFormationPlanner.MIN_SPACING - 0.01:
				return false
		points.append(point)
	return not points.is_empty()

func _test_http_local_move(world: SoldierSandbox, ids: Array[String]) -> void:
	world.reset_sandbox()
	world.check_service()
	await _wait_for_http(world, "_health_request")
	var ready := world.controls.connection_label.text.contains("Local model ready")
	_check(ready, "real movement interpretation uses the ready local model")
	if not ready:
		return
	world.submit_order("Move to C.")
	await _wait_for_http(world, "_pending_request", 180000)
	_check(world._active_action == "move_to" and world.active_assignments.size() == 12, "the real model interprets move to C as movement of the entire squad")
	if world._active_action == "move_to" and world.active_assignments.size() == 12:
		_check(await _wait_for_formation(world), "all twelve soldiers physically complete the real interpreted movement")
		world._refresh_progress()
		_check(_move_destinations_fit(world) and _positions_do_not_overlap(world), "real-model movement ends at separated nearby positions")
		_check(world.controls.status_label.text.contains("Local model") and world.controls.progress_label.text.contains("movement complete"), "real movement is labelled as local interpretation and actual completion")
	else:
		printerr("  Local movement result: ", world.controls.status_label.text)
	world.reset_sandbox()
	var before := _positions(world)
	world.submit_order("Move only soldier_01 and soldier_02 to C.")
	await _wait_for_http(world, "_pending_request", 180000)
	var selected: Array[String] = [ids[0], ids[1]]
	var subset := world._active_action == "move_to" and world.active_assignments.size() == 2 and world.active_assignments.has(selected[0]) and world.active_assignments.has(selected[1])
	_check(subset, "the real model preserves an explicit movement subset")
	if subset:
		_check(await _wait_for_formation(world), "the interpreted subset physically reaches its destinations")
		for soldier in world.soldiers:
			if not selected.has(soldier.soldier_id):
				_check(soldier.global_position.distance_to(before[soldier.soldier_id]) < 0.01, "%s remains stationary during the interpreted subset order" % soldier.soldier_id)
	else:
		printerr("  Local subset result: ", world.controls.status_label.text)
	world.stop_orders()

func _test_local_responses(world: SoldierSandbox, ids: Array[String]) -> void:
	world._health_revision += 1
	var health := {"mode": "local", "model": "qwen3.5:4b", "ready": true, "request_timeout": 150, "protocol_version": 2, "supported_actions": ["form_line", "move_to", "stop", "clarify", "follow_player", "patrol", "create_group"]}
	world._on_health_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(health).to_utf8_buffer(), world._health_revision)
	_check(world.controls.connection_label.text.contains("Local model ready") and world.controls.connection_label.text.contains("qwen3.5:4b"), "local readiness displays the actual model without a cloud label")
	_check(world._request_timeout == 150.0, "local inference allows a bounded longer timeout")
	health["ready"] = false
	health["error"] = "Install the selected local model."
	world._on_health_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(health).to_utf8_buffer(), world._health_revision)
	_check(world.controls.connection_label.text.contains("not ready") and not world.controls.connection_label.text.contains("ANTHROPIC"), "missing local models do not request a cloud API key")
	health["ready"] = true
	health["request_timeout"] = 900
	world._on_health_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(health).to_utf8_buffer(), world._health_revision)
	_check(world._request_timeout == 150.0, "an excessive service timeout cannot remove the client limit")
	var order := {"action": "stop", "soldier_ids": ids.duplicate(), "start": null, "end": null, "facing": null, "group_name": null, "message": "Stop everyone."}
	var response := {"request_id": world.request_revision, "mode": "local", "order": order}
	_check(world.accept_response(response, world.request_revision), "validated local-model responses are accepted")
	_check(world.controls.status_label.text.contains("Local model") and not world.controls.status_label.text.contains("Fixture"), "local interpretation is not labelled as a fixed example")
	var revision := world.request_revision
	world.stop_orders()
	_check(not world.accept_response(response, revision), "late local-model replies are ignored after Stop")

func _test_http_local(world: SoldierSandbox) -> void:
	world.reset_sandbox()
	world.check_service()
	await _wait_for_http(world, "_health_request")
	var ready := world.controls.connection_label.text.contains("Local model ready")
	_check(ready, "real model integration uses a ready local order service")
	if not ready:
		printerr("  The local model was not ready; no cloud or fixture order was sent.")
		return
	world.submit_order("Arrange everyone in a line from A to B, facing C.")
	await _wait_for_http(world, "_pending_request", 180000)
	_check(world.active_assignments.size() == 12, "a real local-model interpretation assigns all twelve soldiers")
	if world.active_assignments.size() != 12:
		printerr("  Local order result: ", world.controls.status_label.text)
	_check(world.controls.status_label.text.contains("Local model"), "the real response is labelled as local model interpretation")
	if world.active_assignments.size() == 12:
		var complete := await _wait_for_formation(world)
		_check(complete, "all twelve soldiers physically complete the line interpreted by the local model")
		if not complete:
			_print_soldier_states(world)
		var direction: Vector2 = world.landmarks["C"] - (world.landmarks["A"] + world.landmarks["B"]) * 0.5
		var expected := Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
		_check(world.soldiers.all(func(soldier: SandboxSoldier) -> bool: return soldier.task_state == "holding" and soldier.facing == expected), "the local interpretation preserves the requested shared facing toward C")
	world.stop_orders()

func _test_http_fixture(world: SoldierSandbox) -> void:
	world.reset_sandbox()
	world.check_service()
	await _wait_for_http(world, "_health_request")
	var fixture := world.controls.connection_label.text.contains("Fixture service")
	_check(fixture, "HTTP integration uses the explicitly labelled fixture service")
	if not fixture:
		printerr("  HTTP fixture service was not available; no cloud order was sent.")
		return
	world.submit_order("Please arrange every soldier along A–B and have them look toward C.")
	var revision := world.request_revision
	_check(is_instance_valid(world._pending_request), "text submission creates a real HTTP request")
	await _wait_for_http(world, "_pending_request")
	_check(world.request_revision == revision and world.active_assignments.size() == 12, "the HTTP fixture response passes validation and assigns twelve soldiers")
	_check(world.controls.connection_label.text.contains("fixed response, not an LLM"), "HTTP fixture mode is not presented as language-model interpretation")
	var complete := await _wait_for_formation(world)
	_check(complete, "soldiers complete a formation received through HTTPRequest")
	if not complete:
		_print_soldier_states(world)
	world.stop_orders()

func _wait_for_http(world: SoldierSandbox, property: String, timeout_msec: int = 10000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while is_instance_valid(world.get(property)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not is_instance_valid(world.get(property)), "%s finishes within the local-service timeout" % property)

func _wait_for_formation(world: SoldierSandbox) -> bool:
	if world.active_assignments.is_empty():
		return false
	for tick in range(2400):
		await get_tree().physics_frame
		await get_tree().process_frame
		if not _positions_do_not_overlap(world):
			_overlap_seen = true
		var moving := false
		var complete := true
		for soldier in world.soldiers:
			if not world.active_assignments.has(soldier.soldier_id):
				continue
			moving = moving or soldier.task_state == "moving"
			complete = complete and soldier.task_state == "holding" and soldier.global_position.distance_to(soldier.destination) <= SandboxFormationPlanner.ARRIVAL_DISTANCE
		if complete:
			await get_tree().physics_frame
			await get_tree().process_frame
			return true
		if not moving:
			return false
	return false

func _capture_screenshot() -> void:
	var path := OS.get_environment("SANDBOX_SCREENSHOT")
	if path.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image != null and not image.is_empty(), "rendered sandbox screenshot contains an image")
	if image != null and not image.is_empty():
		_check(image.save_png(path) == OK, "sandbox screenshot saves to the requested path")

func _campaign_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for property in GameState.get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name: String = property["name"]
		var value: Variant = GameState.get(name)
		snapshot[name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return snapshot

func _positions(world: SoldierSandbox) -> Dictionary:
	var positions: Dictionary = {}
	for soldier in world.soldiers:
		positions[soldier.soldier_id] = soldier.global_position
	return positions

func _same_positions(world: SoldierSandbox, expected: Dictionary) -> bool:
	for soldier in world.soldiers:
		if not expected.has(soldier.soldier_id) or soldier.global_position.distance_to(expected[soldier.soldier_id]) > 0.05:
			return false
	return true

func _all_states(world: SoldierSandbox, state: String) -> bool:
	return world.soldiers.all(func(soldier: SandboxSoldier) -> bool: return soldier.task_state == state)

func _positions_do_not_overlap(world: SoldierSandbox) -> bool:
	var leader := Rect2(world.player.global_position + Vector2(-4, -6), Vector2(8, 6)).grow(-0.15)
	for first in world.soldiers.size():
		var a := Rect2(world.soldiers[first].global_position + Vector2(-4, -6), Vector2(8, 6)).grow(-0.15)
		if a.intersects(leader):
			return false
		for second in range(first + 1, world.soldiers.size()):
			var b := Rect2(world.soldiers[second].global_position + Vector2(-4, -6), Vector2(8, 6)).grow(-0.15)
			if a.intersects(b):
				return false
	return true

func _has_unique_ids(ids: Array[String]) -> bool:
	var seen: Array[String] = []
	for id in ids:
		if seen.has(id):
			return false
		seen.append(id)
	return true

func _unique_points(points: Array[Vector2]) -> bool:
	for first in points.size():
		for second in range(first + 1, points.size()):
			if points[first].distance_to(points[second]) < 0.01:
				return false
	return true

func _print_soldier_states(world: SoldierSandbox) -> void:
	for soldier in world.soldiers:
		printerr("  %s: %s at %s, destination %s, distance %.2f, reason %s" % [soldier.soldier_id, soldier.task_state, soldier.global_position, soldier.destination, soldier.global_position.distance_to(soldier.destination), soldier.blocked_reason])
		if soldier.task_state == "blocked":
			var next: Vector2 = soldier._path[soldier._path_index] if soldier._path_index < soldier._path.size() else soldier.destination
			printerr("    Next waypoint: %s, path index %d/%d, retries %d" % [next, soldier._path_index, soldier._path.size(), soldier._retries])

func _frames(count: int) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("  FAIL: %s" % description)

func _finish() -> void:
	print("Sandbox smoke: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
