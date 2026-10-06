extends SceneTree

var _planner: Variant
var _navigation_script: GDScript
var _substituting_script: GDScript
var _candidate_substituting_script: GDScript
var _assignment_substituting_script: GDScript
var _checks := 0
var _failures := 0
const IDS: Array[String] = ["soldier_01", "soldier_02", "soldier_03"]
const MARKERS := {"A": Vector2(40, 40), "B": Vector2(88, 40), "C": Vector2(64, 88)}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_planner = load("res://scripts/sandbox/formation_planner.gd")
	var source := "extends TiledLoader\n\nfunc build_grid() -> void:\n\tmap_size = Vector2(256, 256)\n\t_navigation = _new_navigation_grid()\n"
	_navigation_script = GDScript.new()
	_navigation_script.source_code = source
	_check(_navigation_script.reload() == OK, "test navigation loads after campaign autoload initialization")
	_substituting_script = GDScript.new()
	_substituting_script.source_code = source + "\nfunc get_walk_path(start: Vector2, destination: Vector2) -> PackedVector2Array:\n\treturn PackedVector2Array([start, destination + Vector2(16, 0)])\n"
	_check(_substituting_script.reload() == OK, "substituting-path test navigation loads")
	_candidate_substituting_script = GDScript.new()
	_candidate_substituting_script.source_code = source + "\nfunc get_walk_path(start: Vector2, destination: Vector2) -> PackedVector2Array:\n\tvar path := super.get_walk_path(start, destination)\n\tif start == Vector2(128, 128) and destination != start and not path.is_empty():\n\t\tpath[-1] = destination + Vector2(16, 0)\n\treturn path\n"
	_check(_candidate_substituting_script.reload() == OK, "candidate-substitution test navigation loads")
	_assignment_substituting_script = GDScript.new()
	_assignment_substituting_script.source_code = source + "\nfunc get_walk_path(start: Vector2, destination: Vector2) -> PackedVector2Array:\n\tvar path := super.get_walk_path(start, destination)\n\tif start != Vector2(128, 128) and destination != Vector2(128, 128) and not path.is_empty():\n\t\tpath[-1] = destination + Vector2(16, 0)\n\treturn path\n"
	_check(_assignment_substituting_script.reload() == OK, "assignment-substitution test navigation loads")
	_test_order_validation()
	_test_move_validation()
	_test_recurring_and_group_validation()
	_test_assignment()
	_test_line_planning()
	_test_move_planning()
	_test_occupied_routes()
	_test_follow_offsets()
	_test_follow_planning()
	await _test_follow_retargeting()
	print("Sandbox unit: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _line(ids: Array[String] = ["soldier_01", "soldier_02"]) -> Dictionary:
	return {"action": "form_line", "soldier_ids": ids.duplicate(), "start": "A", "end": "B", "facing": "C", "message": "Arrange the selected soldiers along A–B.", "group_name": null}

func _valid(order: Variant, markers: Dictionary = MARKERS) -> bool:
	return _planner.validate_order(order, IDS, markers)["ok"]

func _test_order_validation() -> void:
	var order := _line()
	_check(_valid(order), "a seven-key line order with known IDs and landmarks is accepted")
	var validated: Dictionary = _planner.validate_order(order, IDS, MARKERS)
	validated["order"]["soldier_ids"].append("soldier_03")
	_check(order["soldier_ids"].size() == 2, "validated orders are copied instead of changing the response")
	for invalid in [null, "form a line", 12, true, [], {}]:
		_check(not _valid(invalid), "non-order input %s is rejected" % str(invalid))
	for key in _planner.ORDER_KEYS:
		var missing := order.duplicate(true)
		missing.erase(key)
		_check(not _valid(missing), "missing %s is rejected" % key)
	var extra := order.duplicate(true)
	extra["code"] = "do not execute"
	_check(not _valid(extra), "an unexpected order key is rejected")
	for action in ["square", "attack", "Form_Line", "", 1, false, null]:
		var bad := order.duplicate(true)
		bad["action"] = action
		_check(not _valid(bad), "unsupported or wrongly typed action %s is rejected" % str(action))
	var attack := {"action": "attack", "soldier_ids": ["soldier_01"], "start": null, "end": null, "facing": null, "message": "Attack.", "group_name": null}
	_check(_valid(attack), "an attack without a place is valid")
	var attack_at := attack.duplicate(true)
	attack_at["end"] = "B"
	_check(_valid(attack_at), "an attack around a landmark is valid")
	for field in ["start", "facing"]:
		var bad := attack.duplicate(true)
		bad[field] = "A"
		_check(not _valid(bad), "an attack with a %s landmark is rejected" % field)
	var nobody := attack.duplicate(true)
	nobody["soldier_ids"] = []
	_check(not _valid(nobody), "an attack without soldiers is rejected")
	for selected in [[], ["soldier_01"], ["soldier_01", "soldier_01"], ["soldier_01", "unknown"], [1, "soldier_02"], [true, "soldier_02"], "all", null]:
		var bad := order.duplicate(true)
		bad["soldier_ids"] = selected
		_check(not _valid(bad), "invalid soldier selection %s is rejected" % str(selected))
	for key in ["start", "end", "facing"]:
		for reference in ["missing", 12, false, []]:
			var bad := order.duplicate(true)
			bad[key] = reference
			_check(not _valid(bad), "invalid %s reference %s is rejected" % [key, str(reference)])
	var same := order.duplicate(true)
	same["end"] = "A"
	_check(not _valid(same), "a line cannot use the same landmark twice")
	var no_facing := order.duplicate(true)
	no_facing["facing"] = null
	_check(_valid(no_facing), "facing may be omitted with a null value")
	var missing_landmark := MARKERS.duplicate()
	missing_landmark.erase("B")
	_check(not _valid(order, missing_landmark), "a referenced but unplaced landmark is rejected")
	for message in [null, 5, false, [], "", " \t\n ", "x".repeat(501)]:
		var bad := order.duplicate(true)
		bad["message"] = message
		_check(not _valid(bad), "invalid or oversized explanation is rejected")
	var maximum := order.duplicate(true)
	maximum["message"] = "x".repeat(500)
	_check(_valid(maximum), "a 500-character explanation is accepted")
	var stop := {"action": "stop", "soldier_ids": ["soldier_02"], "start": null, "end": null, "facing": null, "message": "Stop this soldier.", "group_name": null}
	_check(_valid(stop), "a stop order can select one known soldier")
	var empty_stop := stop.duplicate(true)
	empty_stop["soldier_ids"] = []
	_check(not _valid(empty_stop), "a stop order needs a soldier")
	var clarification := {"action": "clarify", "soldier_ids": [], "start": null, "end": null, "facing": null, "message": "Place the intended landmark.", "group_name": null}
	_check(_valid(clarification), "a clarification with no assignments is accepted")
	var assigned_clarification := clarification.duplicate(true)
	assigned_clarification["soldier_ids"] = ["soldier_01"]
	_check(not _valid(assigned_clarification), "a clarification cannot assign a soldier")
	for base in [stop, clarification]:
		for key in ["start", "end", "facing"]:
			var bad: Dictionary = base.duplicate(true)
			bad[key] = "A"
			_check(not _valid(bad), "%s cannot contain a %s landmark" % [base["action"], key])

func _move(ids: Array[String] = ["soldier_01"], target: String = "C", facing: Variant = null) -> Dictionary:
	return {"action": "move_to", "soldier_ids": ids.duplicate(), "start": null, "end": target, "facing": facing, "message": "Move the selected soldiers near the landmark.", "group_name": null}

func _test_move_validation() -> void:
	var order := _move()
	_check(_valid(order), "a move order accepts one soldier and a destination without a start landmark")
	_check(_valid(_move(IDS, "B", "A")), "a move order accepts multiple soldiers and an explicit facing landmark")
	var validated: Dictionary = _planner.validate_order(order, IDS, MARKERS)
	validated["order"]["soldier_ids"].append("soldier_02")
	_check(order["soldier_ids"].size() == 1, "validated move selections do not modify the response")
	for selected in [[], ["unknown"], ["soldier_01", "soldier_01"], [true], [1], "all", null]:
		var bad := order.duplicate(true)
		bad["soldier_ids"] = selected
		_check(not _valid(bad), "a move order rejects invalid selection %s" % str(selected))
	for reference in ["A", 1, false, [], {}]:
		var bad := order.duplicate(true)
		bad["start"] = reference
		_check(not _valid(bad), "a move order requires null start rather than %s" % str(reference))
	for key in ["end", "facing"]:
		for reference in ["missing", 1, false, [], {}]:
			var bad := order.duplicate(true)
			bad[key] = reference
			_check(not _valid(bad), "a move order rejects invalid %s reference %s" % [key, str(reference)])
	var missing_end := order.duplicate(true)
	missing_end["end"] = null
	_check(not _valid(missing_end), "a move order requires a destination")
	var missing_markers := MARKERS.duplicate()
	missing_markers.erase("C")
	_check(not _valid(order, missing_markers), "a move order rejects an unplaced destination")
	for key in _planner.ORDER_KEYS:
		var missing := order.duplicate(true)
		missing.erase(key)
		_check(not _valid(missing), "a move order still requires the %s field" % key)
	var extra := order.duplicate(true)
	extra["target"] = "C"
	_check(not _valid(extra), "a move order does not add another destination field")
	var same := _move(["soldier_01"], "C", "C")
	_check(_valid(same), "a move order permits a facing landmark coincident with its destination")

func _recurring(action: String, ids: Array[String] = ["soldier_01"], group_name: Variant = null) -> Dictionary:
	return {"action": action, "soldier_ids": ids.duplicate(), "start": "A" if action == "patrol" else null, "end": "B" if action == "patrol" else null, "facing": null, "message": "Sandbox task validation test.", "group_name": group_name}

func _test_recurring_and_group_validation() -> void:
	_check(_valid(_recurring("follow_player")), "following accepts one soldier without landmark fields")
	_check(_valid(_recurring("patrol", IDS)), "patrol accepts multiple soldiers and ordered distinct endpoints")
	var reversed := _recurring("patrol")
	reversed["start"] = "B"
	reversed["end"] = "A"
	var checked: Dictionary = _planner.validate_order(reversed, IDS, MARKERS)
	_check(checked["ok"] and checked["order"]["start"] == "B" and checked["order"]["end"] == "A", "validation preserves patrol endpoint order")
	for action in ["follow_player", "patrol", "create_group"]:
		var order := _recurring(action, IDS, "alpha" if action == "create_group" else null)
		for selected in [[], ["unknown"], ["soldier_01", "soldier_01"], [true], "all", null]:
			var invalid := order.duplicate(true)
			invalid["soldier_ids"] = selected
			_check(not _valid(invalid), "%s rejects invalid participants %s" % [action, str(selected)])
		for key in _planner.ORDER_KEYS:
			var missing := order.duplicate(true)
			missing.erase(key)
			_check(not _valid(missing), "%s requires the %s field" % [action, key])
	for action in ["follow_player", "create_group"]:
		for key in ["start", "end", "facing"]:
			var invalid := _recurring(action, IDS, "alpha" if action == "create_group" else null)
			invalid[key] = "A"
			_check(not _valid(invalid), "%s cannot contain a %s landmark" % [action, key])
	for key in ["start", "end"]:
		for value in [null, false, 1, "missing", []]:
			var invalid := _recurring("patrol")
			invalid[key] = value
			_check(not _valid(invalid), "patrol rejects invalid %s landmark %s" % [key, str(value)])
	var same := _recurring("patrol")
	same["end"] = "A"
	_check(not _valid(same), "patrol requires different endpoint IDs")
	var facing := _recurring("patrol")
	facing["facing"] = "C"
	_check(not _valid(facing), "patrol cannot contain a facing landmark")
	var creation := _recurring("create_group", IDS, "AlPhA_2")
	var groups := {"all": IDS.duplicate(), "beta": ["soldier_02"]}
	var original_groups := groups.duplicate(true)
	checked = _planner.validate_order(creation, IDS, MARKERS, groups)
	_check(checked["ok"] and checked["order"]["group_name"] == "alpha_2", "group names are normalized to lowercase")
	_check(creation["group_name"] == "AlPhA_2" and groups == original_groups, "group validation changes neither the response nor existing membership")
	for name in [null, false, 12, [], "", "all", "ALL", "a b", "a!", "1alpha", "_alpha", " alpha", "alpha ", "alpha\n", "álpha", "a".repeat(25)]:
		_check(not _valid(_recurring("create_group", IDS, name)), "group creation rejects invalid or reserved name %s" % str(name))
	for name in ["a", "alpha-2", "alpha_2", "a".repeat(24)]:
		_check(_valid(_recurring("create_group", IDS, name)), "group creation accepts valid bounded name %s" % name)
	_check(not _planner.validate_order(_recurring("create_group", IDS, "BeTa"), IDS, MARKERS, groups)["ok"], "group creation rejects an existing normalized name")
	var full := {"all": IDS.duplicate()}
	for index in range(8):
		full["group%d" % index] = ["soldier_01"]
	_check(not _planner.validate_order(_recurring("create_group", IDS, "newgroup"), IDS, MARKERS, full)["ok"], "an eighth existing named group prevents creating a ninth")
	full.erase("group7")
	_check(_planner.validate_order(_recurring("create_group", IDS, "newgroup"), IDS, MARKERS, full)["ok"], "the derived all group does not consume a named-group slot")
	full.erase("all")
	full["group7"] = ["soldier_01"]
	_check(not _planner.validate_order(_recurring("create_group", IDS, "newgroup"), IDS, MARKERS, full)["ok"], "group count remains bounded when all is omitted")
	for order in [_line(), _move(), _recurring("follow_player"), _recurring("patrol"), {"action": "stop", "soldier_ids": ["soldier_01"], "start": null, "end": null, "facing": null, "message": "Stop.", "group_name": null}, {"action": "clarify", "soldier_ids": [], "start": null, "end": null, "facing": null, "message": "Clarify.", "group_name": null}]:
		order["group_name"] = "alpha"
		_check(not _valid(order), "%s requires a null group name" % order["action"])

func _test_assignment() -> void:
	_check(_planner.minimum_assignment([]).is_empty(), "empty assignment has no matches")
	_check(_planner.minimum_assignment([[4.0]]) == [0], "one soldier receives the only position")
	var costs := [[10.0, 1.0, 7.0], [2.0, 9.0, 8.0], [8.0, 5.0, 3.0]]
	var matching: Array[int] = _planner.minimum_assignment(costs)
	_check(matching == [1, 0, 2], "assignment finds the exact known minimum")
	_check(is_equal_approx(_assignment_cost(costs, matching), 6.0), "minimum travel cost is computed correctly")
	var equal := [[1.0, 1.0, 1.0], [1.0, 1.0, 1.0], [1.0, 1.0, 1.0]]
	var stable: Array[int] = _planner.minimum_assignment(equal)
	_check(_unique(stable) and stable.size() == 3, "equal costs still assign each position once")
	_check(_planner.minimum_assignment(equal) == stable, "equal-cost assignments are deterministic")
	var random := RandomNumberGenerator.new()
	random.seed = 74321
	for sample in range(20):
		var matrix: Array = []
		for row in range(4):
			var entries: Array[float] = []
			for column in range(4):
				entries.append(float(random.randi_range(0, 100)))
			matrix.append(entries)
		var result: Array[int] = _planner.minimum_assignment(matrix)
		_check(result.size() == 4 and _unique(result), "random assignment %d uses distinct positions" % sample)
		_check(is_equal_approx(_assignment_cost(matrix, result), _brute_minimum(matrix, 0, [])), "random assignment %d matches exhaustive search" % sample)
	_check(is_equal_approx(_planner.path_length(Vector2.ZERO, PackedVector2Array([Vector2(3, 4), Vector2(6, 8)])), 10.0), "route cost includes the distance to the first waypoint")

func _test_line_planning() -> void:
	var navigation: Variant = _navigation_script.new()
	navigation.build_grid()
	get_root().add_child(navigation)
	var positions := {"soldier_01": Vector2(88, 88), "soldier_02": Vector2(40, 88), "soldier_03": Vector2(64, 88)}
	var order := _line()
	var plan: Dictionary = _planner.plan_line(order, positions, MARKERS, navigation)
	_check(plan["ok"], "an open line is planned")
	if plan["ok"]:
		_check(plan["slots"] == PackedVector2Array([MARKERS["A"], MARKERS["B"]]), "line endpoints are preserved exactly")
		_check(plan["assignments"]["soldier_01"] == MARKERS["B"] and plan["assignments"]["soldier_02"] == MARKERS["A"], "soldier assignment reduces travel instead of following ID order")
		for id: String in plan["paths"]:
			var path: PackedVector2Array = plan["paths"][id]
			_check(not path.is_empty() and path[-1] == plan["assignments"][id], "%s route reaches its exact assigned position" % id)
	var reversed_order := _line(["soldier_02", "soldier_01"])
	var reversed_plan: Dictionary = _planner.plan_line(reversed_order, positions, MARKERS, navigation)
	_check(reversed_plan["ok"] and reversed_plan["assignments"] == plan.get("assignments", {}), "reordering IDs does not change stable assignment")
	var three: Dictionary = _planner.plan_line(_line(IDS), positions, MARKERS, navigation)
	_check(three["ok"] and three["slots"] == PackedVector2Array([Vector2(40, 40), Vector2(64, 40), Vector2(88, 40)]), "three soldiers receive evenly spaced positions at minimum spacing")
	var short_markers := MARKERS.duplicate()
	short_markers["B"] = Vector2(63, 40)
	_check(not _planner.plan_line(order, positions, short_markers, navigation)["ok"], "a line shorter than minimum spacing is rejected")
	var invalid_markers := MARKERS.duplicate()
	invalid_markers["A"] = Vector2(INF, 40)
	_check(not _planner.plan_line(order, positions, invalid_markers, navigation)["ok"], "nonfinite line endpoints are rejected")
	var invalid_positions := positions.duplicate()
	invalid_positions["soldier_01"] = Vector2(NAN, 40)
	_check(not _planner.plan_line(order, invalid_positions, MARKERS, navigation)["ok"], "nonfinite soldier positions are rejected")
	_check(_planner.body_fits(navigation, Vector2(40, 40)), "an open position fits a soldier")
	_check(not _planner.body_fits(navigation, Vector2(-1, 40)), "out-of-map positions cannot hold soldiers")
	_check(not _planner.body_fits(navigation, Vector2(NAN, 40)), "nonfinite positions cannot hold soldiers")
	navigation._navigation.set_point_solid(Vector2i(1, 2), true)
	_check(not _planner.body_fits(navigation, Vector2(32, 40)), "footprint probes reject a position beside a blocked cell")
	navigation._navigation.set_point_solid(Vector2i(1, 2), false)
	navigation._navigation.set_point_solid(Vector2i(4, 2), true)
	_check(not _planner.plan_line(_line(IDS), positions, MARKERS, navigation)["ok"], "a blocked intermediate line position is rejected")
	navigation._navigation.set_point_solid(Vector2i(4, 2), false)
	for y in range(16):
		navigation._navigation.set_point_solid(Vector2i(6, y), true)
	var isolated_markers := {"A": Vector2(136, 40), "B": Vector2(184, 40), "C": Vector2(160, 88)}
	_check(not _planner.plan_line(order, positions, isolated_markers, navigation)["ok"], "walkable but disconnected line positions are rejected")
	navigation.free()
	var substituting: Variant = _substituting_script.new()
	substituting.build_grid()
	get_root().add_child(substituting)
	_check(not _planner.plan_line(order, positions, MARKERS, substituting)["ok"], "nonempty paths ending at substituted positions are rejected")
	substituting.free()

func _test_move_planning() -> void:
	var navigation: Variant = _navigation_script.new()
	navigation.build_grid()
	get_root().add_child(navigation)
	var markers := {"A": Vector2(40, 40), "B": Vector2(88, 40), "C": Vector2(128, 128)}
	var positions := {"soldier_01": Vector2(40, 40), "soldier_02": Vector2(64, 40), "soldier_03": Vector2(88, 40)}
	var original_positions := positions.duplicate()
	var original_markers := markers.duplicate()
	var single: Dictionary = _planner.plan_move(_move(), positions, markers, navigation)
	_check(single["ok"], "one soldier can move to an open landmark")
	if single["ok"]:
		_check(single["slots"] == PackedVector2Array([markers["C"]]), "one unoccupied destination is the landmark itself")
		_check(single["assignments"].size() == 1 and single["assignments"].has("soldier_01"), "a single move assigns only the selected soldier")
		_check(single["paths"]["soldier_01"][-1] == markers["C"], "the single move reaches the exact landmark")
	var plan: Dictionary = _planner.plan_move(_move(IDS), positions, markers, navigation)
	_check(plan["ok"], "multiple soldiers can move into separated nearby positions")
	if plan["ok"]:
		_check(plan["slots"] == PackedVector2Array([Vector2(128, 128), Vector2(128, 104), Vector2(104, 128)]), "equidistant slots use deterministic vertical then horizontal tie-breaking")
		_check_move_destinations(plan, IDS, markers["C"], PackedVector2Array(), "three-soldier move")
	var reversed: Dictionary = _planner.plan_move(_move(["soldier_03", "soldier_02", "soldier_01"]), positions, markers, navigation)
	_check(reversed["ok"] and reversed["assignments"] == plan.get("assignments", {}), "reordering a move selection preserves the minimum-cost assignment")
	var occupied := PackedVector2Array([markers["C"], markers["C"] + Vector2(24, 0)])
	var around_actors: Dictionary = _planner.plan_move(_move(IDS), positions, markers, navigation, occupied)
	_check(around_actors["ok"], "a move can select nearby positions around stationary actors")
	if around_actors["ok"]:
		_check_move_destinations(around_actors, IDS, markers["C"], occupied, "occupied-area move")
	var already_there := positions.duplicate()
	already_there["soldier_01"] = markers["C"]
	var arrived: Dictionary = _planner.plan_move(_move(), already_there, markers, navigation)
	_check(arrived["ok"] and arrived["assignments"]["soldier_01"] == markers["C"], "a soldier already at the landmark receives a valid zero-distance assignment")
	var empty := _move()
	empty["soldier_ids"] = []
	_check_move_failure(_planner.plan_move(empty, positions, markers, navigation), "empty move selections do not create assignments")
	for value in [Vector2(INF, 128), Vector2(NAN, 128), Vector2(-1, 128), Vector2(128, 256)]:
		var bad_markers := markers.duplicate()
		bad_markers["C"] = value
		_check_move_failure(_planner.plan_move(_move(), positions, bad_markers, navigation), "invalid destination %s is rejected before assignment" % str(value))
	for value in [Vector2(INF, 40), Vector2(NAN, 40), Vector2(-1, 40)]:
		var bad_positions := positions.duplicate()
		bad_positions["soldier_01"] = value
		_check_move_failure(_planner.plan_move(_move(), bad_positions, markers, navigation), "invalid movement start %s is rejected" % str(value))
	var missing_position := positions.duplicate()
	missing_position.erase("soldier_01")
	_check_move_failure(_planner.plan_move(_move(), missing_position, markers, navigation), "a missing selected position is reported rather than indexed")
	_check_move_failure(_planner.plan_move(_move(), positions, markers, navigation, PackedVector2Array([Vector2(NAN, 128)])), "nonfinite occupied positions are rejected")
	navigation._navigation.set_point_solid(Vector2i(8, 8), true)
	_check_move_failure(_planner.plan_move(_move(IDS), positions, markers, navigation), "a blocked landmark is not replaced with a nearby location")
	navigation._navigation.set_point_solid(Vector2i(8, 8), false)
	var no_space := PackedVector2Array()
	for y in range(-4, 5):
		for x in range(-4, 5):
			no_space.append(markers["C"] + Vector2(x, y) * _planner.MIN_SPACING)
	_check_move_failure(_planner.plan_move(_move(IDS), positions, markers, navigation, no_space), "occupied nearby space rejects the entire movement order")
	var many_ids: Array[String] = []
	var many_positions: Dictionary = {}
	for index in range(12):
		var id := "soldier_%02d" % (index + 1)
		many_ids.append(id)
		many_positions[id] = Vector2(24 + (index % 6) * 24, 24 + floori(float(index) / 6.0) * 24)
	var twelve: Dictionary = _planner.plan_move(_move(many_ids), many_positions, markers, navigation)
	_check(twelve["ok"], "all twelve soldiers receive nearby movement destinations")
	if twelve["ok"]:
		_check_move_destinations(twelve, many_ids, markers["C"], PackedVector2Array(), "twelve-soldier move")
	for index in range(12, 50):
		var id := "soldier_%02d" % (index + 1)
		many_ids.append(id)
		many_positions[id] = Vector2(40, 40)
	_check_move_failure(_planner.plan_move(_move(many_ids), many_positions, markers, navigation), "a bounded search rejects groups larger than the nearby slot capacity")
	for y in range(16):
		navigation._navigation.set_point_solid(Vector2i(6, y), true)
	_check_move_failure(_planner.plan_move(_move(IDS), positions, markers, navigation), "a destination disconnected from selected soldiers rejects the whole order")
	var mixed_positions := positions.duplicate()
	mixed_positions["soldier_01"] = Vector2(152, 128)
	_check_move_failure(_planner.plan_move(_move(["soldier_01", "soldier_02"]), mixed_positions, markers, navigation), "one unreachable soldier prevents movement of an otherwise reachable selected soldier")
	var right_positions: Dictionary = {}
	var right_ids: Array[String] = []
	for index in range(12):
		var id := "soldier_%02d" % (index + 1)
		right_ids.append(id)
		right_positions[id] = Vector2(152, 128)
	var same_area: Dictionary = _planner.plan_move(_move(right_ids), right_positions, markers, navigation)
	_check(same_area["ok"], "nearby slots can be found on the destination side of a wall")
	if same_area["ok"]:
		var on_destination_side := true
		for slot: Vector2 in same_area["slots"]:
			on_destination_side = on_destination_side and slot.x >= 112.0
		_check(on_destination_side, "movement does not use close slots across an impassable wall")
		_check_move_destinations(same_area, right_ids, markers["C"], PackedVector2Array(), "connected-area move")
	for y in range(16):
		for x in range(16):
			navigation._navigation.set_point_solid(Vector2i(x, y), true)
	for y in range(7, 9):
		for x in range(7, 9):
			navigation._navigation.set_point_solid(Vector2i(x, y), false)
	var small_area := {"soldier_01": markers["C"], "soldier_02": Vector2(136, 136)}
	_check_move_failure(_planner.plan_move(_move(["soldier_01", "soldier_02"]), small_area, markers, navigation), "walkable but insufficient terrain space rejects the whole movement order")
	_check(positions == original_positions and markers == original_markers, "successful and rejected movement plans leave actor positions and landmarks unchanged")
	navigation.free()
	var substituting: Variant = _substituting_script.new()
	substituting.build_grid()
	get_root().add_child(substituting)
	_check_move_failure(_planner.plan_move(_move(), positions, markers, substituting), "substituted routes to the landmark are rejected")
	substituting.free()
	var candidate_substituting: Variant = _candidate_substituting_script.new()
	candidate_substituting.build_grid()
	get_root().add_child(candidate_substituting)
	_check_move_failure(_planner.plan_move(_move(["soldier_01", "soldier_02"]), positions, markers, candidate_substituting), "substituted anchor-to-candidate paths do not count as reachable slots")
	candidate_substituting.free()
	var assignment_substituting: Variant = _assignment_substituting_script.new()
	assignment_substituting.build_grid()
	get_root().add_child(assignment_substituting)
	_check_move_failure(_planner.plan_move(_move(["soldier_01", "soldier_02"]), positions, markers, assignment_substituting), "substituted actor-to-slot paths cannot produce a partial assignment")
	assignment_substituting.free()

func _check_move_destinations(plan: Dictionary, ids: Array[String], target: Vector2, occupied: PackedVector2Array, description: String) -> void:
	var slots: PackedVector2Array = plan["slots"]
	_check(slots.size() == ids.size() and plan["assignments"].size() == ids.size() and plan["paths"].size() == ids.size(), "%s provides exactly one destination and path per selected soldier" % description)
	var separated := true
	var nearby := true
	var clear := true
	for index in slots.size():
		nearby = nearby and slots[index].is_finite() and slots[index].distance_to(target) <= _planner.MOVE_RADIUS
		for other in range(index):
			separated = separated and slots[index].distance_to(slots[other]) >= _planner.MIN_SPACING
		for point in occupied:
			clear = clear and slots[index].distance_to(point) >= _planner.MIN_SPACING
	_check(nearby, "%s keeps every slot within the bounded landmark area" % description)
	_check(separated, "%s keeps assigned positions at least 24 pixels apart" % description)
	_check(clear, "%s keeps destinations clear of stationary actors" % description)
	for id in ids:
		var path: PackedVector2Array = plan["paths"][id]
		_check(not path.is_empty() and path[-1].distance_to(plan["assignments"][id]) < 0.1, "%s gives %s an exact route to its assigned position" % [description, id])

func _check_move_failure(result: Dictionary, description: String) -> void:
	_check(not result["ok"] and not result.has("assignments") and not result.has("paths") and not result.has("slots"), description)

func _test_occupied_routes() -> void:
	var navigation: Variant = _navigation_script.new()
	navigation.build_grid()
	get_root().add_child(navigation)
	navigation._navigation.set_point_solid(Vector2i(3, 7), true)
	var start := Vector2(40, 40)
	var destination := Vector2(200, 200)
	var occupied := PackedVector2Array([Vector2(120, 120), Vector2(152, 136)])
	var original_occupied := occupied.duplicate()
	var original_solids := _grid_solids(navigation)
	var normal: PackedVector2Array = navigation.get_walk_path(start, destination)
	_check(not normal.is_empty() and normal[-1] == destination, "occupied-route tests start with a reachable exact destination")
	_check(normal.find(occupied[0]) >= 0, "the normal route crosses a position occupied by a stationary actor")
	var no_actors: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, PackedVector2Array())
	_check(no_actors == normal, "an empty occupied list preserves the normal route exactly")
	_check(_grid_solids(navigation) == original_solids, "an empty occupied list does not change terrain cells")
	var route: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, occupied)
	_check(not route.is_empty() and route[-1].distance_to(destination) < 0.1, "an occupied-position route reaches the exact available destination")
	_check(route != normal and _route_avoids_centers(route, occupied, 14.0), "an occupied-position route avoids blocked actor-cell centers")
	_check(_grid_solids(navigation) == original_solids and navigation._navigation.is_point_solid(Vector2i(3, 7)), "successful temporary avoidance restores open cells and preserves existing terrain obstacles")
	_check(occupied == original_occupied, "route avoidance does not modify the caller's occupied positions")
	var between_actors := Vector2(120.04, 124.23)
	var exit_destination := Vector2(144, 112)
	var adjacent_actors := PackedVector2Array([Vector2(118.52, 113.34), Vector2(118.79, 135.16)])
	var escape: PackedVector2Array = navigation.get_walk_path_avoiding(between_actors, exit_destination, adjacent_actors, 11.0)
	_check(not escape.is_empty() and escape[-1] == exit_destination, "a soldier can leave a start cell whose center is occupied by another actor")
	_check(not escape.is_empty() and escape[0].x > between_actors.x and escape[0].distance_to(Vector2(120, 120)) >= 0.1, "a retry advances toward the available exit rather than an unsafe center or a snapped backwards start")
	_check(_grid_solids(navigation) == original_solids, "allowing departure from an actor-blocked start does not change terrain navigation")
	var corner_actor := PackedVector2Array([Vector2(96, 96)])
	var corner_route: PackedVector2Array = navigation.get_walk_path_avoiding(Vector2(88, 88), Vector2(120, 120), corner_actor, 11.0)
	_check(not corner_route.is_empty() and corner_route[-1] == Vector2(120, 120), "a route around an actor standing on a cell corner reaches its destination")
	_check(_route_segments_clear(Vector2(88, 88), corner_route, corner_actor, 8.0), "a route never steps diagonally through an actor standing on a cell corner")
	_check(_grid_solids(navigation) == original_solids, "blocking an actor's own cell is temporary")
	var duplicates: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, PackedVector2Array([occupied[0], occupied[0]]))
	_check(not duplicates.is_empty() and _route_avoids_centers(duplicates, PackedVector2Array([occupied[0]]), 14.0), "repeated occupied positions still produce a route around the actor")
	_check(_grid_solids(navigation) == original_solids, "repeated occupied positions do not leave temporary terrain changes")
	var zero_clearance: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, occupied, 0.0)
	_check(zero_clearance == normal and _grid_solids(navigation) == original_solids, "zero clearance does not block cells or change the normal route")
	navigation.position = Vector2(16, 32)
	var translated: PackedVector2Array = navigation.get_walk_path_avoiding(start + navigation.position, destination + navigation.position, PackedVector2Array([occupied[0] + navigation.position]))
	_check(not translated.is_empty() and translated[-1] == destination + navigation.position, "translated navigation retains the requested world-space endpoint")
	_check(_route_avoids_centers(translated, PackedVector2Array([occupied[0] + navigation.position]), 14.0) and _grid_solids(navigation) == original_solids, "translated navigation avoids world-space actor positions and restores its grid")
	navigation.position = Vector2.ZERO
	var blocked_destination: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, PackedVector2Array([destination]))
	_check(blocked_destination.is_empty() or blocked_destination[-1].distance_to(destination) >= 0.1, "an actor-blocked destination is not falsely reported as an exact arrival route")
	_check(_grid_solids(navigation) == original_solids, "destination substitution or failure restores temporary actor cells")
	navigation._navigation.set_point_solid(Vector2i(12, 12), true)
	var blocked_solids := _grid_solids(navigation)
	var terrain_destination: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, occupied)
	_check(terrain_destination.is_empty() or terrain_destination[-1].distance_to(destination) >= 0.1, "a terrain-blocked destination is not falsely reported as an exact arrival route")
	_check(_grid_solids(navigation) == blocked_solids and navigation._navigation.is_point_solid(Vector2i(12, 12)), "temporary avoidance preserves a destination blocked by permanent terrain")
	navigation._navigation.set_point_solid(Vector2i(12, 12), false)
	var no_route: PackedVector2Array = navigation.get_walk_path_avoiding(start, Vector2(248, 248), PackedVector2Array([Vector2(128, 128)]), 150.0)
	_check(no_route.is_empty(), "occupied cells disconnect the valid start from an available destination without inventing a route")
	_check(_grid_solids(navigation) == original_solids, "a failed route restores every temporarily blocked cell")
	_check(navigation.get_walk_path(start, destination) == normal, "normal navigation still works after temporary avoidance makes a route impossible")
	for clearance in [-1.0, NAN, INF]:
		var invalid: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, occupied, clearance)
		_check(invalid.is_empty() and _grid_solids(navigation) == original_solids, "invalid clearance %s rejects routing without changing terrain" % str(clearance))
	for arguments in [[Vector2(NAN, 40), destination, occupied], [start, Vector2(INF, 200), occupied], [start, destination, PackedVector2Array([Vector2(NAN, 120)])]]:
		var invalid: PackedVector2Array = navigation.get_walk_path_avoiding(arguments[0], arguments[1], arguments[2])
		_check(invalid.is_empty() and _grid_solids(navigation) == original_solids, "nonfinite route or occupied positions are rejected without terrain changes")
	for arguments in [[Vector2(-1, 40), destination], [start, Vector2(256, 200)]]:
		var out_of_bounds: PackedVector2Array = navigation.get_walk_path_avoiding(arguments[0], arguments[1], occupied)
		_check(out_of_bounds.is_empty() and _grid_solids(navigation) == original_solids, "out-of-map routing failures restore cells changed for stationary actors")
	var outside_actor: PackedVector2Array = navigation.get_walk_path_avoiding(start, destination, PackedVector2Array([Vector2(-1000, -1000)]))
	_check(outside_actor == normal and _grid_solids(navigation) == original_solids, "an actor outside the navigation area does not change an available route")
	navigation.free()

func _selected_ids(ids: Array[String]) -> Array[String]:
	return ids

func _test_follow_offsets() -> void:
	var offsets: Dictionary = _planner.make_follow_offsets(IDS)
	_check(offsets == {"soldier_01": Vector2(-12, 32), "soldier_02": Vector2(12, 32), "soldier_03": Vector2(0, 56)}, "default follow offsets use two columns with a centered last soldier")
	_check(_planner.make_follow_offsets(_selected_ids(["soldier_03", "soldier_01", "soldier_02"])) == offsets, "default follow identities are stable when input IDs are reordered")
	_check(_planner.make_follow_offsets(_selected_ids(["soldier_02"])) == {"soldier_02": Vector2(0, 32)}, "one follower remains directly behind the leader")
	_check(_planner.make_follow_offsets(_selected_ids([])).is_empty() and _planner.make_follow_offsets(_selected_ids(["soldier_01", "soldier_01"])).is_empty(), "empty or repeated follow IDs cannot generate slots")
	var line := {"soldier_01": Vector2(40, 40), "soldier_02": Vector2(88, 40), "soldier_03": Vector2(64, 40)}
	var original_line := line.duplicate()
	var preserved: Dictionary = _planner.make_follow_offsets(IDS, line, Vector2.DOWN)
	_check(preserved == {"soldier_01": Vector2(-24, 32), "soldier_02": Vector2(24, 32), "soldier_03": Vector2(0, 32)}, "following preserves line geometry and each soldier's existing slot identity")
	_check(line == original_line, "capturing follow offsets does not change the original line assignments")
	var subset: Dictionary = _planner.make_follow_offsets(_selected_ids(["soldier_01", "soldier_02"]), line, Vector2.DOWN)
	_check(subset["soldier_01"].distance_to(subset["soldier_02"]) == 48.0, "following a line subset preserves its actual spacing rather than compacting it")
	_check(_planner.make_follow_offsets(IDS, {"soldier_01": Vector2(40, 40)}, Vector2.DOWN) == offsets, "a selection missing from the previous line uses the documented default formation")
	_check(_planner.make_follow_offsets(IDS, line, Vector2.ZERO) == offsets, "a previous line without a facing direction uses the documented default")
	var sloping := {"soldier_01": Vector2(40, 40), "soldier_02": Vector2(64, 64), "soldier_03": Vector2(88, 88)}
	var rotated: Dictionary = _planner.make_follow_offsets(IDS, sloping, Vector2(1, -1))
	var behind := true
	for offset: Vector2 in rotated.values():
		behind = behind and offset.is_finite() and offset.y >= _planner.FOLLOW_REAR_CLEARANCE
	_check(behind and is_equal_approx(rotated["soldier_01"].distance_to(rotated["soldier_03"]), sloping["soldier_01"].distance_to(sloping["soldier_03"])), "rotated line offsets retain distances and start behind the leader")

func _test_follow_planning() -> void:
	var navigation: Variant = _navigation_script.new()
	navigation.build_grid()
	get_root().add_child(navigation)
	var positions := {"soldier_01": Vector2(40, 40), "soldier_02": Vector2(64, 40), "soldier_03": Vector2(88, 40)}
	var leader := Vector2(128, 64)
	var offsets: Dictionary = _planner.make_follow_offsets(IDS)
	var original_positions := positions.duplicate()
	var original_offsets := offsets.duplicate()
	var plan: Dictionary = _planner.plan_follow(IDS, positions, leader, Vector2.UP, offsets, navigation)
	_check(plan["ok"], "an open follow formation is planned behind the leader")
	if plan["ok"]:
		_check(plan["assignments"] == {"soldier_01": Vector2(140, 96), "soldier_02": Vector2(116, 96), "soldier_03": Vector2(128, 120)}, "follow planning uses immutable ID offsets instead of minimum-cost reassignment")
		_check_follow_destinations(plan, IDS, leader, "default follow formation")
		var shifted: Dictionary = _planner.plan_follow(_selected_ids(["soldier_03", "soldier_02", "soldier_01"]), positions, leader + Vector2(24, 0), Vector2(0, -3), offsets, navigation)
		var stable: bool = shifted["ok"]
		if stable:
			for id in IDS:
				stable = stable and shifted["assignments"][id] == plan["assignments"][id] + Vector2(24, 0)
		_check(stable, "retargeting a translated leader preserves soldier identities and normalizes heading magnitude")
		var reordered: Dictionary = _planner.plan_follow(_selected_ids(["soldier_02", "soldier_03", "soldier_01"]), positions, leader, Vector2.UP, offsets, navigation)
		_check(reordered["ok"] and reordered["assignments"] == plan["assignments"], "reordered follow participants do not change assigned slots")
		var occupied := PackedVector2Array([plan["assignments"]["soldier_01"]])
		_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, offsets, navigation, occupied), "an occupied follow destination rejects the complete plan without relocating its slot")
	var line := {"soldier_01": Vector2(40, 40), "soldier_02": Vector2(88, 40), "soldier_03": Vector2(64, 40)}
	var line_offsets: Dictionary = _planner.make_follow_offsets(IDS, line, Vector2.DOWN)
	var line_plan: Dictionary = _planner.plan_follow(IDS, positions, Vector2(128, 128), Vector2.RIGHT, line_offsets, navigation)
	_check(line_plan["ok"] and line_plan.get("assignments", {}) == {"soldier_01": Vector2(96, 152), "soldier_02": Vector2(96, 104), "soldier_03": Vector2(96, 128)}, "turning the leader rotates the preserved line without exchanging soldier slots")
	var twelve_ids: Array[String] = []
	var twelve_positions: Dictionary = {}
	for index in range(12):
		var id := "soldier_%02d" % (index + 1)
		twelve_ids.append(id)
		twelve_positions[id] = Vector2(24 + (index % 6) * 24, 24 + floori(float(index) / 6.0) * 24)
	var twelve_offsets: Dictionary = _planner.make_follow_offsets(twelve_ids)
	var twelve: Dictionary = _planner.plan_follow(twelve_ids, twelve_positions, Vector2(128, 32), Vector2.UP, twelve_offsets, navigation)
	_check(twelve["ok"], "all twelve followers fit in an open two-column formation")
	if twelve["ok"]:
		_check_follow_destinations(twelve, twelve_ids, Vector2(128, 32), "twelve-soldier follow formation")
	for heading in [Vector2.ZERO, Vector2(NAN, 1), Vector2(INF, 0)]:
		_check_move_failure(_planner.plan_follow(IDS, positions, leader, heading, offsets, navigation), "invalid follow heading %s rejects the plan" % str(heading))
	_check_move_failure(_planner.plan_follow(IDS, positions, Vector2(NAN, 64), Vector2.UP, offsets, navigation), "a nonfinite leader position rejects following")
	_check_move_failure(_planner.plan_follow(_selected_ids([]), positions, leader, Vector2.UP, offsets, navigation), "an empty follow selection rejects following")
	_check_move_failure(_planner.plan_follow(_selected_ids(["soldier_01", "soldier_01"]), positions, leader, Vector2.UP, offsets, navigation), "a repeated follow ID rejects following")
	_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, offsets, navigation, PackedVector2Array([Vector2(INF, 64)])), "nonfinite occupied positions reject following")
	for value in [Vector2(NAN, 40), Vector2(-1, 40), null]:
		var invalid := positions.duplicate()
		invalid["soldier_01"] = value
		_check_move_failure(_planner.plan_follow(IDS, invalid, leader, Vector2.UP, offsets, navigation), "invalid selected start %s rejects the full follow plan" % str(value))
	for value in [Vector2(NAN, 32), Vector2(0, 8), null]:
		var invalid := offsets.duplicate()
		invalid["soldier_01"] = value
		_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, invalid, navigation), "invalid or leader-overlapping slot %s rejects the follow formation" % str(value))
	var crowded := offsets.duplicate()
	crowded["soldier_02"] = offsets["soldier_01"] + Vector2(1, 0)
	_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, crowded, navigation), "follow slots less than 24 pixels apart reject the complete plan")
	var missing := offsets.duplicate()
	missing.erase("soldier_01")
	_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, missing, navigation), "a missing follow slot rejects following rather than assigning another slot")
	_check_move_failure(_planner.plan_follow(IDS, positions, Vector2(128, 248), Vector2.UP, offsets, navigation), "a formation extending beyond map bounds rejects following")
	navigation._navigation.set_point_solid(Vector2i(8, 6), true)
	_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, offsets, navigation), "a terrain-blocked follow slot rejects the formation atomically")
	navigation._navigation.set_point_solid(Vector2i(8, 6), false)
	for y in range(16):
		navigation._navigation.set_point_solid(Vector2i(6, y), true)
	_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, offsets, navigation), "a disconnected follow formation rejects the plan without partial movement")
	_check(positions == original_positions and offsets == original_offsets, "successful and rejected follow plans leave input positions and offsets unchanged")
	navigation.free()
	var substituting := GDScript.new()
	substituting.source_code = "extends TiledLoader\n\nfunc build_grid() -> void:\n\tmap_size = Vector2(256, 256)\n\t_navigation = _new_navigation_grid()\n\nfunc get_walk_path_avoiding(start: Vector2, destination: Vector2, occupied: PackedVector2Array, clearance: float = 14.0) -> PackedVector2Array:\n\treturn PackedVector2Array([start, destination + Vector2(16, 0)])\n"
	_check(substituting.reload() == OK, "substituted follow-route test navigation loads")
	var substitute_navigation: Variant = substituting.new()
	substitute_navigation.build_grid()
	get_root().add_child(substitute_navigation)
	_check_move_failure(_planner.plan_follow(IDS, positions, leader, Vector2.UP, offsets, substitute_navigation), "a substituted follow route endpoint rejects the complete formation")
	substitute_navigation.free()

func _check_follow_destinations(plan: Dictionary, ids: Array[String], leader: Vector2, description: String) -> void:
	_check(plan["assignments"].size() == ids.size() and plan["paths"].size() == ids.size() and plan["slots"].size() == ids.size(), "%s assigns one exact route and slot per selected soldier" % description)
	var slots: PackedVector2Array = plan["slots"]
	var clear := true
	for index in slots.size():
		clear = clear and slots[index].distance_to(leader) >= _planner.FOLLOW_REAR_CLEARANCE
		for previous in range(index):
			clear = clear and slots[index].distance_to(slots[previous]) >= _planner.MIN_SPACING - 0.01
	_check(clear, "%s preserves leader clearance and soldier spacing" % description)
	for id in ids:
		var path: PackedVector2Array = plan["paths"][id]
		_check(not path.is_empty() and path[-1].distance_to(plan["assignments"][id]) < 0.1, "%s gives %s a route to its unchanged slot" % [description, id])

func _test_follow_retargeting() -> void:
	var navigation: Variant = _navigation_script.new()
	navigation.build_grid()
	get_root().add_child(navigation)
	var soldier_script: GDScript = load("res://scripts/sandbox/sandbox_soldier.gd")
	var soldier: Variant = soldier_script.new()
	var avoidance_map := NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(avoidance_map, true)
	soldier.avoidance_map = avoidance_map
	var stops: Array[Vector2] = []
	soldier.configure("soldier_01", "res://assets/art/space_military_base/station_soldier_1.png", Vector2(40, 40), navigation, stops)
	get_root().add_child(soldier)
	soldier.set_physics_process(false)
	var target := Vector2(128, 128)
	var path := PackedVector2Array([Vector2(40, 40), target])
	soldier.assign_position(target, path, Vector2.UP, soldier_script.FOLLOW_SPEED, true)
	_check(soldier._move_speed == 104.0 and soldier._avoidance.max_speed == 104.0 and soldier._continuous, "follow catch-up speed applies to walking and avoidance without changing the normal speed")
	_check((soldier.collision_mask & 2) != 0, "sandbox soldiers collide with the player's layer")
	var collider: CollisionShape2D
	for child in soldier.get_children():
		if child is CollisionShape2D:
			collider = child
			break
	_check(collider != null and soldier_script.AVOIDANCE_OFFSET == collider.position and soldier_script.AVOIDANCE_OFFSET == Vector2(0, -3), "soldier avoidance offset matches the physical collider center while destinations remain foot positions")
	soldier._elapsed = soldier._timeout + 1.0
	soldier._physics_process(0.01)
	_check(soldier.task_state == "moving", "continuous following ignores a finite leg's total-lifetime deadline")
	soldier._elapsed = 42.0
	soldier._stuck_seconds = 1.75
	soldier._retries = 2
	soldier._last_position = Vector2(39, 40)
	var deadline: float = soldier._timeout
	var retarget := target + Vector2(24, 0)
	var new_path := PackedVector2Array([Vector2(40, 40), retarget])
	soldier.retarget_position(retarget, new_path, Vector2.RIGHT)
	_check(soldier.destination == retarget and soldier.final_facing == Vector2.RIGHT and soldier._path[-1] == retarget, "retargeting updates the requested destination, path and facing")
	_check(soldier._elapsed == 42.0 and soldier._timeout == deadline and soldier._stuck_seconds == 1.75 and soldier._retries == 2 and soldier._last_position == Vector2(39, 40), "retargeting preserves elapsed time and all no-progress detection state")
	new_path.clear()
	_check(not soldier._path.is_empty(), "retargeting copies the supplied route")
	soldier._stuck_seconds = 2.1
	soldier._retries = 3
	for index in range(4):
		soldier.retarget_position(retarget + Vector2(index, 0), PackedVector2Array([retarget + Vector2(index, 0)]), Vector2.UP)
	soldier._physics_process(0.01)
	_check(soldier.task_state == "blocked" and soldier.blocked_reason.contains("blocked"), "repeated follow retargeting cannot conceal sustained lack of progress")
	var blocked_target: Vector2 = soldier.destination
	soldier.retarget_position(target, path, Vector2.DOWN)
	_check(soldier.task_state == "blocked" and soldier.destination == blocked_target, "retargeting cannot silently revive a blocked follower")
	soldier.stop()
	_check(soldier._move_speed == soldier_script.MOVE_SPEED and soldier._avoidance.max_speed == soldier_script.MOVE_SPEED and not soldier._continuous and soldier.task_state == "idle", "Stop restores finite normal-speed movement and avoidance")
	soldier.assign_position(target, path, Vector2.UP)
	soldier._elapsed = soldier._timeout + 1.0
	soldier._physics_process(0.01)
	_check(soldier.task_state == "blocked" and soldier.blocked_reason.contains("Timed out"), "ordinary assignment retains its finite movement deadline")
	soldier.assign_position(soldier.global_position, PackedVector2Array([soldier.global_position]), Vector2.UP, soldier_script.FOLLOW_SPEED, true)
	soldier._physics_process(0.01)
	_check(soldier.task_state == "holding", "a caught-up follower physically holds its current slot")
	soldier.retarget_position(soldier.global_position, PackedVector2Array([soldier.global_position]), Vector2.RIGHT)
	_check(soldier.task_state == "holding" and soldier.facing == Vector2.RIGHT and soldier.velocity == Vector2.ZERO, "a retarget already reached updates facing without unnecessary movement")
	soldier._elapsed = 5.0
	soldier.retarget_position(target, path, Vector2.DOWN)
	_check(soldier.task_state == "moving" and soldier._elapsed == 5.0 and soldier._move_speed == soldier_script.FOLLOW_SPEED, "a holding follower resumes on a new target without resetting its task progress")
	soldier.stop()
	await process_frame
	soldier.free()
	NavigationServer2D.free_rid(avoidance_map)
	navigation.free()

func _grid_solids(navigation: Variant) -> Array[bool]:
	var result: Array[bool] = []
	var region: Rect2i = navigation._navigation.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			result.append(navigation._navigation.is_point_solid(Vector2i(x, y)))
	return result

func _route_avoids_centers(path: PackedVector2Array, occupied: PackedVector2Array, clearance: float) -> bool:
	for waypoint in path:
		for point in occupied:
			if waypoint.distance_to(point) < clearance:
				return false
	return true

func _route_segments_clear(start: Vector2, path: PackedVector2Array, occupied: PackedVector2Array, clearance: float) -> bool:
	var previous := start
	for waypoint in path:
		for point in occupied:
			if Geometry2D.get_closest_point_to_segment(point, previous, waypoint).distance_to(point) < clearance:
				return false
		previous = waypoint
	return true

func _unique(values: Array[int]) -> bool:
	var seen: Array[int] = []
	for value in values:
		if seen.has(value):
			return false
		seen.append(value)
	return true

func _assignment_cost(costs: Array, matching: Array[int]) -> float:
	var total := 0.0
	for row in matching.size():
		total += float(costs[row][matching[row]])
	return total

func _brute_minimum(costs: Array, row: int, used: Array[int]) -> float:
	if row == costs.size():
		return 0.0
	var minimum := INF
	for column in costs.size():
		if used.has(column):
			continue
		var next := used.duplicate()
		next.append(column)
		minimum = minf(minimum, float(costs[row][column]) + _brute_minimum(costs, row + 1, next))
	return minimum

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("  FAIL: %s" % description)
