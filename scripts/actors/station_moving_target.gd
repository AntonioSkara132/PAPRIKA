class_name StationMovingTarget
extends StaticBody2D

signal player_shot_hit(target_id: String)

const TARGET_TEXTURE := "res://assets/art/river_planet/arrow_target.png"

var target_id := ""
var moving := false
var shootable := true
var travel_speed := 42.0
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _direction := 1.0
var _sprite: Sprite2D

func configure(id: String, start: Vector2, finish: Vector2, is_shootable: bool = true) -> void:
	target_id = id
	global_position = start
	_start = start
	_end = finish
	shootable = is_shootable
	collision_layer = 32 if shootable else 0
	collision_mask = 0
	_sprite = Sprite2D.new()
	_sprite.texture = load(TARGET_TEXTURE) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	_sprite.modulate = Color("f1d796") if shootable else Color("a8d6e8")
	add_child(_sprite)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14, 21)
	collision.position = Vector2(0, -10)
	collision.shape = box
	add_child(collision)

func _ready() -> void:
	if shootable:
		add_to_group("damageable")
	z_index = 100 + int(global_position.y)

func _physics_process(delta: float) -> void:
	if _ui_modal_is_open() or not moving:
		return
	var goal := _end if _direction > 0.0 else _start
	global_position = global_position.move_toward(goal, travel_speed * delta)
	if global_position.distance_to(goal) < 1.0:
		_direction *= -1.0
	z_index = 100 + int(global_position.y)

func restart() -> void:
	global_position = _start
	_direction = 1.0
	moving = true

func _ui_modal_is_open() -> bool:
	for node in get_tree().get_nodes_in_group("ui_modal"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false

func take_damage(_amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if not shootable or not moving:
		return
	# A melee swing also calls take_damage. Only a live player projectile counts at the range.
	var projectile_parent := get_parent()
	for node in projectile_parent.get_children():
		if node is Projectile and node.from_player and node.global_position.distance_to(source_position) < 5.0:
			moving = false
			_sprite.modulate = Color("fdf7b0")
			player_shot_hit.emit(target_id)
			return
