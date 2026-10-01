class_name WorldService
extends StaticBody2D

signal service_requested(service_id: String, display_name: String)

var service_id: String = ""
var display_name: String = ""
var interaction_text: String = ""
var _interaction_local := Vector2.ZERO

func configure(texture: Texture2D, size: Vector2, new_service_id: String, new_display_name: String) -> void:
	service_id = new_service_id
	display_name = new_display_name
	interaction_text = "Visit %s" % display_name
	_interaction_local = Vector2(size.x * 0.5, size.y + 3.0)
	collision_layer = 1
	collision_mask = 0
	add_to_group("interactable")
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	# Leave a center opening at the visible door while blocking the building walls.
	var wall_height := maxf(7.0, size.y * 0.18)
	var side_width := maxf(8.0, size.x * 0.34)
	_add_rect_collision(Vector2(side_width, wall_height), Vector2(side_width * 0.5, size.y - wall_height * 0.5 - 4.0))
	_add_rect_collision(Vector2(side_width, wall_height), Vector2(size.x - side_width * 0.5, size.y - wall_height * 0.5 - 4.0))
	# The upper footprint prevents walking through the back of the building.
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
