class_name Projectile
extends Area2D

var direction := Vector2.RIGHT
var speed := 180.0
var damage := 4
var max_distance := 160.0
var from_player := true
var _travelled := 0.0
var _origin := Vector2.ZERO
var _hit_ids: Dictionary = {}

func configure(origin: Vector2, travel_direction: Vector2, attack_damage: int, travel_speed: float, attack_range: float, player_owned: bool) -> void:
	global_position = origin
	_origin = origin
	direction = travel_direction.normalized()
	damage = attack_damage
	speed = travel_speed
	max_distance = attack_range
	from_player = player_owned
	collision_layer = 0
	collision_mask = 1 | (8 | 32 if from_player else 2 | 4 | 64)
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 2.5
	collision.shape = shape
	add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-4, -2), Vector2(5, 0), Vector2(-4, 2)])
	visual.color = Color("f5c34c") if from_player else Color("da52ff")
	visual.rotation = direction.angle()
	add_child(visual)
	z_index = 900

func _physics_process(delta: float) -> void:
	var movement := direction * speed * delta
	position += movement
	_travelled += movement.length()
	if _travelled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is CollisionObject2D and (body.collision_layer & collision_mask) == 0:
		return
	if _hit_ids.has(body.get_instance_id()):
		return
	_hit_ids[body.get_instance_id()] = true
	if body.has_method("take_damage"):
		var world := get_tree().get_first_node_in_group("game_world")
		if body is Node2D and world != null and world.has_method("shot_blocked") and world.shot_blocked(_origin, (body as Node2D).global_position):
			world.show_cover_hit(global_position)
		else:
			body.take_damage(damage, global_position)
	queue_free()
