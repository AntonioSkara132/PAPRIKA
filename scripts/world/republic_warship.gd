class_name RepublicWarship
extends StaticBody2D

## A Republic warship landed at the airfield on Artichoke. During General Hickey's
## fleet strike the player plants field mines on its hull with E: an escort needs
## one mine and the flagship three. When the last mine is planted the world lights
## a short fuse and the ship is destroyed. Arrows and blows do nothing to the hull.
## The body is on the enemy layer so Confederation shots stop on it.

signal destroyed(ship_id: String)

var ship_id := ""
var display_name := "Republic warship"
var mines_needed := 1
var mines_planted := 0
var intact := true
var _map_sprite: Node2D
var _label: Label

## `map_object` is the ship's sprite holder from the map; `size` is its sprite size.
func configure(id: String, ship_name: String, needed: int, map_object: Node2D, size: Vector2) -> void:
	ship_id = id
	display_name = ship_name
	mines_needed = needed
	_map_sprite = map_object
	# The node sits at the hull's lower middle so the player can reach it from the side.
	global_position = map_object.global_position + Vector2(size.x * 0.5, size.y - 10)
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(size.x * 0.7, size.y * 0.4)
	collision.shape = box
	collision.position = Vector2(0, -size.y * 0.2)
	add_child(collision)
	_label = Label.new()
	_label.position = Vector2(-60, -size.y + 2)
	_label.size = Vector2(120, 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("ffd27a"))
	_label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	add_child(_label)
	z_index = 900

func _ready() -> void:
	add_to_group("republic_warship")

## Offers the hull for mining with E; only while the fleet strike runs.
func set_open_for_mines(open: bool) -> void:
	if open and intact and not fully_mined():
		add_to_group("interactable")
	else:
		remove_from_group("interactable")

func get_interaction_text() -> String:
	return "Plant a field mine on the %s (%d/%d)" % [display_name, mines_planted, mines_needed]

func get_interaction_position() -> Vector2:
	return global_position

func interact(_actor: Node) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world != null and world.has_method("plant_ship_mine"):
		world.call("plant_ship_mine", self)

## Arrows and blows stop on the hull without harming it.
func take_damage(_amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	pass

## Counts one more mine on the hull. Returns true when it was the last one needed.
func add_mine() -> bool:
	mines_planted = mini(mines_needed, mines_planted + 1)
	_label.visible = true
	_label.text = "%s %d/%d mines" % [display_name, mines_planted, mines_needed]
	if mines_planted >= mines_needed:
		remove_from_group("interactable")
		return true
	return false

func fully_mined() -> bool:
	return mines_planted >= mines_needed

func destroy() -> void:
	if not intact:
		return
	show_wrecked()
	destroyed.emit(ship_id)

## Takes the mines back off an intact hull, e.g. after a failed strike.
func restore() -> void:
	intact = true
	mines_planted = 0
	collision_layer = 8
	_label.visible = false
	remove_from_group("interactable")
	if is_instance_valid(_map_sprite):
		_map_sprite.modulate = Color.WHITE
		_map_sprite.rotation_degrees = 0.0

## Shows the burnt-out hull without reporting a new kill, e.g. after loading a save.
func show_wrecked() -> void:
	intact = false
	mines_planted = mines_needed
	collision_layer = 0
	_label.visible = false
	remove_from_group("interactable")
	if is_instance_valid(_map_sprite):
		_map_sprite.modulate = Color(0.30, 0.28, 0.32)
		_map_sprite.rotation_degrees = 2.0
