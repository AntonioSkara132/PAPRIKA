extends Node2D

signal finished(body: Node)

const SPEED := 150.0
const RANGE := 720.0

var direction := Vector2.RIGHT
## Zero makes this the one-hit Banishing Arrow; above zero it deals normal damage.
var damage := 0
var remaining := RANGE
## The MC's arrow flies past the MC and stops at enemies; the assassin's flies past Davor and stops at the MC and allies.
var from_player := false
var _shooter_rid := RID()
var _finished := false

func configure(point: Vector2, heading: Vector2, distance: float = RANGE) -> void:
	global_position = point
	direction = heading.normalized()
	remaining = distance
	rotation = direction.angle()
	z_index = 900

func _draw() -> void:
	if damage > 0:
		draw_line(Vector2(-14, 0), Vector2(5, 0), Color("4a2a20"), 4.0)
		draw_line(Vector2(-12, 0), Vector2(5, 0), Color("e0a060"), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(1, -3), Vector2(1, 3)]), Color("d95a4a"))
		return
	draw_line(Vector2(-16, 0), Vector2(5, 0), Color("642584"), 5.0)
	draw_line(Vector2(-14, 0), Vector2(5, 0), Color("f5eaff"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(1, -4), Vector2(1, 4)]), Color("e08aff"))
	draw_line(Vector2(-14, -3), Vector2(-10, 0), Color("e08aff"), 2.0)
	draw_line(Vector2(-14, 3), Vector2(-10, 0), Color("e08aff"), 2.0)

func fire_as_player(shooter: CollisionObject2D) -> void:
	from_player = true
	_shooter_rid = shooter.get_rid()

func snapshot() -> Dictionary:
	return {"x": global_position.x, "y": global_position.y, "dx": direction.x, "dy": direction.y, "remaining": remaining}

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if _finished or player == null or player.ui_is_open() or get_tree().paused:
		return
	var distance := minf(SPEED * delta, remaining)
	var destination := global_position + direction * distance
	var exclude: Array[RID] = []
	if from_player:
		exclude.append(_shooter_rid)
	else:
		for davor in get_tree().get_nodes_in_group("iskra_davor"):
			exclude.append((davor as CollisionObject2D).get_rid())
	var ray := PhysicsRayQueryParameters2D.create(global_position, destination, (1 | 4 | 8 | 64) if from_player else (1 | 2 | 4 | 64), exclude)
	ray.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position = hit.position
		_finish(hit.collider)
		return
	global_position = destination
	remaining -= distance
	if remaining <= 0.0:
		_finish(null)

func _finish(body: Node) -> void:
	if _finished:
		return
	_finished = true
	set_physics_process(false)
	visible = false
	finished.emit(body)
	if body is Player:
		if damage > 0:
			body.take_damage(damage, global_position)
		else:
			body.take_banishing_hit()
	elif body is RaidSoldier:
		body.take_damage(damage if damage > 0 else body.health + body.armor, global_position)
	elif body is Enemy and body.has_method("take_banishing_hit"):
		body.take_banishing_hit()
	queue_free()
