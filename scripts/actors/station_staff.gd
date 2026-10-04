class_name StationStaff
extends Node2D

signal service_requested(service_id: String, display_name: String)

var service_id := ""
var display_name := ""
var interaction_text := "Talk"

func configure(id: String, title: String, texture_path: String, position: Vector2) -> void:
	service_id = id
	display_name = title
	interaction_text = "Talk to %s" % title
	global_position = position
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	if sprite.texture != null:
		sprite.position = Vector2(-sprite.texture.get_width() * 0.5, -sprite.texture.get_height() + 2)
	add_child(sprite)
	z_index = 100 + int(position.y)

func _ready() -> void:
	add_to_group("interactable")

func get_interaction_text() -> String:
	return interaction_text

func interact(_actor: Node) -> void:
	service_requested.emit(service_id, display_name)
