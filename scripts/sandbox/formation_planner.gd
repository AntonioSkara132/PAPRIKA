class_name SandboxFormationPlanner
extends RefCounted

const MIN_SPACING := 24.0
const MOVE_RADIUS := 96.0
const ARRIVAL_DISTANCE := 2.0
const UNREACHABLE_COST := 1.0e12
const FOLLOW_REAR_CLEARANCE := 32.0
const MAX_NAMED_GROUPS := 8
const ORDER_KEYS := ["action", "soldier_ids", "start", "end", "facing", "message", "group_name"]

static func validate_order(value: Variant, known_ids: Array[String], landmarks: Dictionary, groups: Dictionary = {}) -> Dictionary:
	if not value is Dictionary or value.size() != ORDER_KEYS.size():
		return _failure("The service returned an invalid order object.")
	for key in ORDER_KEYS:
		if not value.has(key):
			return _failure("The order is missing %s." % key)
	if not value["action"] is String or value["action"] not in ["form_line", "move_to", "follow_player", "patrol", "create_group", "stop", "clarify", "attack"]:
		return _failure("The sandbox does not support this action.")
	if not value["message"] is String or value["message"].strip_edges().is_empty() or value["message"].length() > 500:
		return _failure("The order explanation is invalid.")
	if not value["soldier_ids"] is Array or value["soldier_ids"].size() > known_ids.size():
		return _failure("The soldier list is invalid.")
	var selected: Array[String] = []
	for id in value["soldier_ids"]:
		if not id is String or not known_ids.has(id) or selected.has(id):
			return _failure("The order contains an unknown or repeated soldier ID.")
		selected.append(id)
	var action: String = value["action"]
	var group_name: Variant = value["group_name"]
	if action == "create_group":
		if not group_name is String:
			return _failure("A group needs a name.")
		group_name = group_name.to_lower()
		var pattern := RegEx.new()
		pattern.compile("^[a-z][a-z0-9_-]{0,23}$")
		var matched := pattern.search(group_name)
		if matched == null or matched.get_string() != group_name or group_name == "all":
			return _failure("Use a group name of up to 24 ASCII letters, digits, underscores or hyphens, starting with a letter; all is reserved.")
		var named_count := 0
		for existing in groups:
			if existing is String and existing.to_lower() == group_name:
				return _failure("That group name already exists.")
			if existing != "all":
				named_count += 1
		if named_count >= MAX_NAMED_GROUPS:
			return _failure("The sandbox supports at most eight named groups.")
	elif group_name != null:
		return _failure("Only group creation can contain a group name.")
	if action == "form_line":
		if selected.size() < 2:
			return _failure("A line needs at least two soldiers.")
		for key in ["start", "end"]:
			if not value[key] is String or not landmarks.has(value[key]):
				return _failure("Place the requested %s landmark first." % key)
		if value["start"] == value["end"]:
			return _failure("Choose two different line endpoints.")
		if value["facing"] != null and (not value["facing"] is String or not landmarks.has(value["facing"])):
			return _failure("The facing landmark does not exist.")
	elif action == "move_to":
		if selected.is_empty():
			return _failure("A move order needs at least one soldier.")
		if value["start"] != null:
			return _failure("A move order cannot contain a start landmark.")
		if not value["end"] is String or not landmarks.has(value["end"]):
			return _failure("Place the requested destination landmark first.")
		if value["facing"] != null and (not value["facing"] is String or not landmarks.has(value["facing"])):
			return _failure("The facing landmark does not exist.")
	elif action == "patrol":
		if selected.is_empty():
			return _failure("A patrol needs at least one soldier.")
		for key in ["start", "end"]:
			if not value[key] is String or not landmarks.has(value[key]):
				return _failure("Place the requested patrol %s landmark first." % key)
		if value["start"] == value["end"]:
			return _failure("Choose two different patrol endpoints.")
		if value["facing"] != null:
			return _failure("Patrol orders do not contain a facing landmark.")
	elif action == "attack":
		if selected.is_empty():
			return _failure("An attack needs at least one soldier.")
		if value["start"] != null or value["facing"] != null:
			return _failure("An attack order can only name the place to fight around.")
		if value["end"] != null and (not value["end"] is String or not landmarks.has(value["end"])):
			return _failure("Place the requested attack landmark first.")
	else:
		for key in ["start", "end", "facing"]:
			if value[key] != null:
				return _failure("This action cannot reference landmarks.")
		if action != "clarify" and selected.is_empty():
			return _failure("This action needs at least one soldier.")
		if action == "clarify" and not selected.is_empty():
			return _failure("A clarification cannot assign soldiers.")
	var order: Dictionary = value.duplicate(true)
	order["group_name"] = group_name
	return {"ok": true, "order": order}

static func plan_line(order: Dictionary, positions: Dictionary, landmarks: Dictionary, navigation: TiledLoader) -> Dictionary:
	var start: Vector2 = landmarks[order["start"]]
	var end: Vector2 = landmarks[order["end"]]
	if not start.is_finite() or not end.is_finite():
		return _failure("The line endpoints must be finite positions.")
	var ids: Array[String] = []
	for id in order["soldier_ids"]:
		ids.append(id)
	ids.sort()
	if start.distance_to(end) < MIN_SPACING * (ids.size() - 1):
		return _failure("The line is too short: %d soldiers need at least %d pixels between A and B." % [ids.size(), ceili(MIN_SPACING * (ids.size() - 1))])
	var slots := PackedVector2Array()
	for index in ids.size():
		var slot := start.lerp(end, float(index) / float(ids.size() - 1))
		if not body_fits(navigation, slot):
			return _failure("Line position %d is blocked. Move an endpoint; the requested line has not been changed." % (index + 1))
		slots.append(slot)
	return _assign_slots(ids, positions, slots, navigation, "Not every soldier can reach the requested line. No soldiers have been moved.")

static func plan_move(order: Dictionary, positions: Dictionary, landmarks: Dictionary, navigation: TiledLoader, occupied: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var target: Vector2 = landmarks[order["end"]]
	if not target.is_finite():
		return _failure("The movement destination must be a finite position.")
	if not body_fits(navigation, target):
		return _failure("The movement destination is blocked or outside the map.")
	var ids: Array[String] = []
	for id in order["soldier_ids"]:
		ids.append(id)
	ids.sort()
	if ids.is_empty():
		return _failure("A move order needs at least one soldier.")
	for point in occupied:
		if not point.is_finite():
			return _failure("Occupied positions must be finite.")
	for id in ids:
		var from_value: Variant = positions.get(id)
		if not from_value is Vector2 or not from_value.is_finite() or not navigation.is_walkable_position(from_value):
			return _failure("%s cannot start a route from its current position." % id)
		var path := navigation.get_walk_path(from_value, target)
		if not _reaches_position(path, target):
			return _failure("%s cannot reach the requested destination. No soldiers have been moved." % id)
	var offsets: Array[Vector2] = []
	var steps := floori(MOVE_RADIUS / MIN_SPACING)
	for y in range(-steps, steps + 1):
		for x in range(-steps, steps + 1):
			var offset := Vector2(x, y) * MIN_SPACING
			if offset.length_squared() <= MOVE_RADIUS * MOVE_RADIUS:
				offsets.append(offset)
	offsets.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		if left.length_squared() != right.length_squared():
			return left.length_squared() < right.length_squared()
		return left.y < right.y if left.y != right.y else left.x < right.x
	)
	var slots := PackedVector2Array()
	for offset in offsets:
		var slot := target + offset
		if not body_fits(navigation, slot):
			continue
		var clear := true
		for point in occupied:
			if slot.distance_to(point) < MIN_SPACING:
				clear = false
				break
		if not clear or not _reaches_position(navigation.get_walk_path(target, slot), slot):
			continue
		slots.append(slot)
		if slots.size() == ids.size():
			break
	if slots.size() != ids.size():
		return _failure("There is not enough reachable space within %d pixels of %s. No soldiers have been moved." % [int(MOVE_RADIUS), order["end"]])
	return _assign_slots(ids, positions, slots, navigation, "Not every soldier can reach the requested movement positions. No soldiers have been moved.")

static func make_follow_offsets(ids: Array[String], line_assignments: Dictionary = {}, line_facing: Vector2 = Vector2.ZERO) -> Dictionary:
	var selected := ids.duplicate()
	selected.sort()
	if selected.is_empty():
		return {}
	for index in selected.size():
		if selected[index].is_empty() or (index > 0 and selected[index] == selected[index - 1]):
			return {}
	var preserve_line := line_facing.is_finite() and line_facing.length_squared() > 0.01
	var center := Vector2.ZERO
	for id in selected:
		var point: Variant = line_assignments.get(id)
		if not point is Vector2 or not point.is_finite():
			preserve_line = false
			break
		center += point
	var offsets: Dictionary = {}
	if preserve_line:
		center /= float(selected.size())
		var heading := line_facing.normalized()
		var lateral := heading.orthogonal()
		var nearest_rear := INF
		for id in selected:
			var relative: Vector2 = line_assignments[id] - center
			var offset := Vector2(relative.dot(lateral), -relative.dot(heading))
			offsets[id] = offset
			nearest_rear = minf(nearest_rear, offset.y)
		for id in selected:
			offsets[id].y += FOLLOW_REAR_CLEARANCE - nearest_rear
		return offsets
	for index in selected.size():
		var alone := index == selected.size() - 1 and selected.size() % 2 == 1
		var lateral := 0.0 if alone else (float(index % 2) - 0.5) * MIN_SPACING
		offsets[selected[index]] = Vector2(lateral, FOLLOW_REAR_CLEARANCE + floori(float(index) / 2.0) * MIN_SPACING)
	return offsets

static func plan_follow(ids: Array[String], positions: Dictionary, leader_position: Vector2, heading: Vector2, offsets: Dictionary, navigation: TiledLoader, occupied: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	if ids.is_empty() or not leader_position.is_finite() or not heading.is_finite() or heading.length_squared() < 0.01:
		return _failure("Following needs soldiers, a finite leader position and a direction.")
	var selected := ids.duplicate()
	selected.sort()
	var direction := heading.normalized()
	var lateral := direction.orthogonal()
	var slots := PackedVector2Array()
	var assignments: Dictionary = {}
	var paths: Dictionary = {}
	var route_occupied := occupied.duplicate()
	for point in occupied:
		if not point.is_finite():
			return _failure("Occupied positions must be finite.")
	if not route_occupied.has(leader_position):
		route_occupied.append(leader_position)
	for id in selected:
		if assignments.has(id):
			return _failure("A follow selection cannot repeat a soldier.")
		var from: Variant = positions.get(id)
		var offset: Variant = offsets.get(id)
		if not from is Vector2 or not from.is_finite() or not navigation.is_walkable_position(from):
			return _failure("%s cannot start a follow route from its current position." % id)
		if not offset is Vector2 or not offset.is_finite() or offset.y < FOLLOW_REAR_CLEARANCE - 0.01:
			return _failure("The follow formation needs finite positions behind the leader.")
		var target: Vector2 = leader_position + lateral * offset.x - direction * offset.y
		if not body_fits(navigation, target) or target.distance_to(leader_position) < FOLLOW_REAR_CLEARANCE - 0.01:
			return _failure("The requested follow formation does not fit on open ground behind the leader.")
		for other in slots:
			if target.distance_to(other) < MIN_SPACING - 0.01:
				return _failure("Follow formation positions need at least 24 pixels of spacing.")
		for point in occupied:
			if target.distance_to(point) < MIN_SPACING:
				return _failure("Another actor or reserved position blocks the follow formation.")
		var path := navigation.get_walk_path_avoiding(from, target, route_occupied, SandboxSoldier.AVOIDANCE_RADIUS * 2.0)
		if not _reaches_position(path, target):
			return _failure("Not every soldier can reach the requested follow formation.")
		assignments[id] = target
		paths[id] = path
		slots.append(target)
	return {"ok": true, "assignments": assignments, "paths": paths, "slots": slots}

static func _assign_slots(ids: Array[String], positions: Dictionary, slots: PackedVector2Array, navigation: TiledLoader, unreachable_message: String) -> Dictionary:
	var costs: Array = []
	var routes: Array = []
	for id in ids:
		var from_value: Variant = positions.get(id)
		if not from_value is Vector2 or not from_value.is_finite() or not navigation.is_walkable_position(from_value):
			return _failure("%s cannot start a route from its current position." % id)
		var from: Vector2 = from_value
		var row: Array[float] = []
		var route_row: Array[PackedVector2Array] = []
		for slot in slots:
			var path := navigation.get_walk_path(from, slot)
			var reaches_slot := _reaches_position(path, slot)
			row.append(path_length(from, path) if reaches_slot else UNREACHABLE_COST)
			route_row.append(path)
		costs.append(row)
		routes.append(route_row)
	var matching := minimum_assignment(costs)
	var assignments: Dictionary = {}
	var paths: Dictionary = {}
	for index in ids.size():
		var column: int = matching[index]
		if float(costs[index][column]) >= UNREACHABLE_COST:
			return _failure(unreachable_message)
		assignments[ids[index]] = slots[column]
		paths[ids[index]] = routes[index][column]
	return {"ok": true, "assignments": assignments, "paths": paths, "slots": slots}

static func _reaches_position(path: PackedVector2Array, point: Vector2) -> bool:
	return not path.is_empty() and path[-1].distance_to(point) < 0.1

static func body_fits(navigation: TiledLoader, point: Vector2) -> bool:
	if not point.is_finite():
		return false
	for offset in [Vector2.ZERO, Vector2(-4, -6), Vector2(4, -6), Vector2(-4, 0), Vector2(4, 0)]:
		if not navigation.is_walkable_position(point + offset):
			return false
	return true

static func path_length(start: Vector2, path: PackedVector2Array) -> float:
	var length := 0.0
	var previous := start
	for point in path:
		length += previous.distance_to(point)
		previous = point
	return length

static func minimum_assignment(costs: Array) -> Array[int]:
	var count := costs.size()
	var u: Array[float] = []
	var v: Array[float] = []
	var p: Array[int] = []
	var way: Array[int] = []
	u.resize(count + 1)
	v.resize(count + 1)
	p.resize(count + 1)
	way.resize(count + 1)
	u.fill(0.0)
	v.fill(0.0)
	p.fill(0)
	way.fill(0)
	for row in range(1, count + 1):
		p[0] = row
		var column := 0
		var minimum: Array[float] = []
		var used: Array[bool] = []
		minimum.resize(count + 1)
		used.resize(count + 1)
		minimum.fill(INF)
		used.fill(false)
		while true:
			used[column] = true
			var current_row := p[column]
			var delta := INF
			var next_column := 0
			for candidate in range(1, count + 1):
				if used[candidate]:
					continue
				var cost := float(costs[current_row - 1][candidate - 1]) - u[current_row] - v[candidate]
				if cost < minimum[candidate]:
					minimum[candidate] = cost
					way[candidate] = column
				if minimum[candidate] < delta:
					delta = minimum[candidate]
					next_column = candidate
			for candidate in range(count + 1):
				if used[candidate]:
					u[p[candidate]] += delta
					v[candidate] -= delta
				else:
					minimum[candidate] -= delta
			column = next_column
			if p[column] == 0:
				break
		while column != 0:
			var previous_column := way[column]
			p[column] = p[previous_column]
			column = previous_column
	var matching: Array[int] = []
	matching.resize(count)
	for column in range(1, count + 1):
		matching[p[column] - 1] = column - 1
	return matching

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
