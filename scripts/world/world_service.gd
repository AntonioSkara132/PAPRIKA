class_name WorldService
extends StaticBody2D

signal service_requested(service_id: String, display_name: String)

var service_id: String = ""
var display_name: String = ""
var interaction_text: String = ""
var _interaction_local := Vector2.ZERO

func configure(texture: Texture2D, size: Vector2, new_service_id: String, new_display_name: String, door_ratio: float = 0.5) -> void:
	service_id = new_service_id
	display_name = new_display_name
	interaction_text = "Visit %s" % display_name
	_interaction_local = Vector2(size.x * door_ratio, size.y + 3.0)
	collision_layer = 1
	collision_mask = 0
	add_to_group("interactable")
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var wall_height := maxf(7.0, size.y * 0.18)
	if is_equal_approx(door_ratio, 0.5):
		var side_width := maxf(8.0, size.x * 0.34)
		_add_rect_collision(Vector2(side_width, wall_height), Vector2(side_width * 0.5, size.y - wall_height * 0.5 - 4.0))
		_add_rect_collision(Vector2(side_width, wall_height), Vector2(size.x - side_width * 0.5, size.y - wall_height * 0.5 - 4.0))
	else:
		var opening_half := maxf(7.0, size.x * 0.16)
		var left_width := maxf(0.0, size.x * door_ratio - opening_half)
		var right_start := minf(size.x, size.x * door_ratio + opening_half)
		if left_width >= 4.0:
			_add_rect_collision(Vector2(left_width, wall_height), Vector2(left_width * 0.5, size.y - wall_height * 0.5 - 4.0))
		if size.x - right_start >= 4.0:
			_add_rect_collision(Vector2(size.x - right_start, wall_height), Vector2((right_start + size.x) * 0.5, size.y - wall_height * 0.5 - 4.0))
	_add_rect_collision(Vector2(size.x * 0.72, maxf(6.0, size.y * 0.12)), Vector2(size.x * 0.5, size.y * 0.64))

func _add_rect_collision(size: Vector2, center: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	add_child(collision)

func get_interaction_text() -> String:
	return interaction_text

func get_interaction_position() -> Vector2:
	return global_position + _interaction_local

func interact(_player: Node) -> void:
	service_requested.emit(service_id, display_name)
