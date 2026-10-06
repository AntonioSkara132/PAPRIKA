class_name SandboxSoldier
extends StationSoldier

const MOVE_SPEED := 52.0
const FOLLOW_SPEED := 104.0
# The 8×6 collider has a five-pixel half-diagonal; add half a pixel of clearance.
const AVOIDANCE_RADIUS := 5.5
const AVOIDANCE_OFFSET := Vector2(0, -3)

var task_state := "idle"
var destination := Vector2.ZERO
var final_facing := Vector2.DOWN
var blocked_reason := ""
var avoidance_map: RID
var route_provider: Callable
var _avoidance: NavigationAgent2D
var _elapsed := 0.0
var _timeout := 0.0
var _stuck_seconds := 0.0
var _last_position := Vector2.ZERO
var _retries := 0
var _move_speed := MOVE_SPEED
var _continuous := false

func _ready() -> void:
	add_to_group("sandbox_soldier")
	collision_mask = 1 | 2 | 4
	_avoidance = NavigationAgent2D.new()
	_avoidance.name = "SoldierAvoidance"
	_avoidance.avoidance_enabled = true
	_avoidance.radius = AVOIDANCE_RADIUS
	_avoidance.neighbor_distance = 48.0
	_avoidance.max_neighbors = 16
	_avoidance.max_speed = MOVE_SPEED
	_avoidance.time_horizon_agents = 0.7
	_avoidance.avoidance_priority = 1.0
	add_child(_avoidance)
	_avoidance.set_navigation_map(avoidance_map)
	_avoidance.velocity_computed.connect(_on_safe_velocity)
	queue_redraw()

func assign_position(point: Vector2, path: PackedVector2Array, facing_direction: Vector2, speed: float = MOVE_SPEED, continuous: bool = false) -> void:
	_move_speed = speed if is_finite(speed) and speed > 0.0 else MOVE_SPEED
	_continuous = continuous
	if _avoidance != null:
		_avoidance.max_speed = _move_speed
	destination = point
	final_facing = facing_direction
	_path = path.duplicate()
	_path_index = 0
	_elapsed = 0.0
	_timeout = maxf(15.0, SandboxFormationPlanner.path_length(global_position, path) / _move_speed * 3.0 + 10.0)
	_stuck_seconds = 0.0
	_last_position = global_position
	_retries = 0
	blocked_reason = ""
	task_state = "moving"
	_avoidance.avoidance_priority = 0.5
	queue_redraw()

func retarget_position(point: Vector2, path: PackedVector2Array, facing_direction: Vector2) -> void:
	if task_state == "blocked":
		return
	destination = point
	final_facing = facing_direction
	_path = path.duplicate()
	_path_index = 0
	if global_position.distance_to(destination) > SandboxFormationPlanner.ARRIVAL_DISTANCE:
		task_state = "moving"
		if _avoidance != null:
			_avoidance.avoidance_priority = 0.5
	else:
		task_state = "holding"
		velocity = Vector2.ZERO
		if _avoidance != null:
			_set_avoidance_velocity(Vector2.ZERO)
			_avoidance.avoidance_priority = 1.0
		_face(final_facing)
	queue_redraw()

func stop() -> void:
	_move_speed = MOVE_SPEED
	_continuous = false
	task_state = "idle"
	_path.clear()
	velocity = Vector2.ZERO
	blocked_reason = ""
	if _avoidance != null:
		_avoidance.max_speed = MOVE_SPEED
		_set_avoidance_velocity(Vector2.ZERO)
		_avoidance.avoidance_priority = 1.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	z_index = 100 + int(global_position.y)
	if task_state != "moving":
		velocity = Vector2.ZERO
		_set_avoidance_velocity(Vector2.ZERO)
		return
	_elapsed += delta
	if global_position.distance_to(destination) <= SandboxFormationPlanner.ARRIVAL_DISTANCE:
		task_state = "holding"
		velocity = Vector2.ZERO
		_set_avoidance_velocity(Vector2.ZERO)
		_avoidance.avoidance_priority = 1.0
		_face(final_facing)
		queue_redraw()
		return
	if not _continuous and _elapsed > _timeout:
		_block("Timed out before reaching the assigned position.")
		return
	if global_position.distance_to(_last_position) < 2.0:
		_stuck_seconds += delta
	else:
		_stuck_seconds = 0.0
		_last_position = global_position
		_retries = 0
	if _stuck_seconds > 2.0:
		_retries += 1
		_stuck_seconds = 0.0
		if _retries > 3:
			_block("Movement is blocked by terrain or another soldier.")
			return
		_path = route_provider.call(global_position, destination) if route_provider.is_valid() else _navigation.get_walk_path(global_position, destination)
		_path_index = 0
		if _path.is_empty() or _path[-1].distance_to(destination) > 0.1:
			_block("The assigned position is no longer reachable.")
			return
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 2.0:
		_path_index += 1
	var target := destination if _path_index >= _path.size() else _path[_path_index]
	var offset := target - global_position
	var desired := offset.normalized() * minf(_move_speed, offset.length() / maxf(delta, 0.001))
	_set_avoidance_velocity(desired)

func _set_avoidance_velocity(desired: Vector2) -> void:
	# These agents follow AStar routes, so submit avoidance updates without requesting NavigationAgent paths.
	NavigationServer2D.agent_set_position(_avoidance.get_rid(), global_position + AVOIDANCE_OFFSET)
	NavigationServer2D.agent_set_velocity(_avoidance.get_rid(), desired)

func _on_safe_velocity(safe_velocity: Vector2) -> void:
	if task_state != "moving":
		return
	velocity = safe_velocity
	if velocity.length_squared() > 0.1:
		_face(velocity)
	move_and_slide()

func _face(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	facing = Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
	_sprite.flip_h = facing.x < 0.0

func _block(reason: String) -> void:
	task_state = "blocked"
	blocked_reason = reason
	velocity = Vector2.ZERO
	_set_avoidance_velocity(Vector2.ZERO)
	_avoidance.avoidance_priority = 1.0
	queue_redraw()

func _draw() -> void:
	var color := Color("c9c3a4")
	if task_state == "moving":
		color = Color("f2cd73")
	elif task_state == "holding":
		color = Color("99d58b")
	elif task_state == "blocked":
		color = Color("ff8e7f")
	draw_arc(Vector2(0, 1), 5.0, 0.0, TAU, 12, color, 1.0)
