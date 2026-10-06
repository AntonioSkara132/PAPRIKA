class_name SandboxPlayer
extends Player

const DEFAULT_ZOOM := Vector2(0.6, 0.6)

var controls: SandboxUI
var avoidance_map: RID
var avoidance_obstacle: NavigationObstacle2D
var _obstacle_offset := Vector2.ZERO

func _ready() -> void:
	add_to_group("sandbox_player")
	collision_mask |= 4
	var camera := get_node("Camera") as Camera2D
	camera.zoom = DEFAULT_ZOOM
	camera.position = Vector2(0, -40)
	if avoidance_map.is_valid():
		for child in get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var rectangle := child.shape as RectangleShape2D
				_obstacle_offset = child.position
				avoidance_obstacle = NavigationObstacle2D.new()
				avoidance_obstacle.name = "PlayerAvoidance"
				avoidance_obstacle.radius = (rectangle.size * 0.5).length() + 0.5
				avoidance_obstacle.avoidance_enabled = true
				avoidance_obstacle.position = _obstacle_offset
				add_child(avoidance_obstacle)
				avoidance_obstacle.set_navigation_map(avoidance_map)
				break

func _physics_process(delta: float) -> void:
	if controls != null and controls.is_typing():
		velocity = Vector2.ZERO
		_update_avoidance(Vector2.ZERO)
		return
	var direction := Input.get_vector("sandbox_left", "sandbox_right", "sandbox_up", "sandbox_down")
	velocity = direction * SPEED
	if direction.length_squared() > 0.01:
		facing = _cardinal(direction)
		_sprite.flip_h = facing.x < 0.0
	var previous := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x, map_bounds.position.x + 6, map_bounds.end.x - 6)
	global_position.y = clampf(global_position.y, map_bounds.position.y + 8, map_bounds.end.y - 6)
	z_index = 100 + int(global_position.y)
	_update_avoidance((global_position - previous) / maxf(delta, 0.001))

func _update_avoidance(actual_velocity: Vector2) -> void:
	if avoidance_obstacle != null:
		avoidance_obstacle.global_position = to_global(_obstacle_offset)
		avoidance_obstacle.velocity = actual_velocity

func _unhandled_input(_event: InputEvent) -> void:
	pass
