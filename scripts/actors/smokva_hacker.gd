class_name SmokvaHacker
extends StationStaff

## A hacker at Smokva on a daily round: they walk from stop to stop (a chair at
## a table, a bar stool, the dartboard, the couch...) and stay at each for a
## while. Stops can be in the bar or the yard; to change sides they walk to the
## door and come out of the other one. They stand still while a scene or a menu
## is open. During the fight in the yard the onlookers are held in one place.

const WALK_SPEED := 34.0

var world: SmokvaWorld
## Each stop is {"at": Vector2 in map pixels, "wait": seconds}.
var route: Array = []
var stop_index := 0
var wait_left := 0.0
## True while the hacker stands where `hold_at` put them.
var held := false
var _path := PackedVector2Array()
var _path_index := 0
var _path_goal := Vector2.INF

func start_route(owner_world: SmokvaWorld, stops: Array, first_wait: float) -> void:
	world = owner_world
	route = stops
	stop_index = 0
	global_position = route[0]["at"]
	wait_left = first_wait
	stop_index = 1 % route.size()
	z_index = 100 + int(global_position.y)

func _process(delta: float) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui") as GameUI
	if ui != null and (ui.scene_playing() or ui.modal_overlay.visible):
		return
	if world != null and world.bar_game_open():
		return
	step(delta)

## Where the hacker is going now.
func current_stop() -> Vector2:
	return route[stop_index]["at"]

func waiting() -> bool:
	return wait_left > 0.0

## Puts the hacker at `at` and keeps them there until `release`.
func hold_at(at: Vector2) -> void:
	held = true
	global_position = at
	_path_goal = Vector2.INF
	z_index = 100 + int(global_position.y)

## Sends a held hacker back on their round, to the stop they were going to.
func release() -> void:
	held = false
	_path_goal = Vector2.INF

func step(delta: float) -> void:
	if route.is_empty() or world == null or held:
		return
	if wait_left > 0.0:
		wait_left -= delta
		return
	var goal := current_stop()
	var inside := world.in_room(global_position)
	if world.in_room(goal) != inside:
		var door := world.marker("room_door") if inside else world.marker("bar_door")
		if global_position.distance_to(door) < 2.0:
			global_position = world.marker("bar_door") if inside else world.marker("room_entry")
			_path_goal = Vector2.INF
		else:
			_walk_toward(door, delta)
		return
	if global_position.distance_to(goal) < 1.0:
		global_position = goal
		wait_left = float(route[stop_index]["wait"])
		stop_index = (stop_index + 1) % route.size()
		return
	_walk_toward(goal, delta)

func _walk_toward(goal: Vector2, delta: float) -> void:
	if _path_goal != goal:
		_path_goal = goal
		var loader := world.tiled_loader
		var from := loader.nearest_walkable_position(global_position)
		var to := loader.nearest_walkable_position(goal)
		_path = loader.get_walk_path(from, to) if from.is_finite() and to.is_finite() else PackedVector2Array()
		# The last steps go straight onto the chair or stool, off the walking grid.
		_path.append(goal)
		_path_index = 0
	var budget := WALK_SPEED * delta
	while budget > 0.0 and _path_index < _path.size():
		var target := _path[_path_index]
		var distance := global_position.distance_to(target)
		if distance <= budget:
			global_position = target
			budget -= distance
			_path_index += 1
		else:
			global_position += (target - global_position) / distance * budget
			budget = 0.0
	z_index = 100 + int(global_position.y)
