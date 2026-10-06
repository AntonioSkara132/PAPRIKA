class_name BatteryCannon
extends StaticBody2D

## A Republic gun at the southwest battery on Artichoke. Shots and blows damage it,
## and a demolition charge planted with E destroys it outright. Its body is on the
## enemy layer so Confederation shots stop on it; the map object keeps blocking
## movement on its own.

signal destroyed(cannon_id: String)

const MAX_HEALTH := 90
## Iron barrels shrug off most of a bullet; a demolition charge is the quick way.
const ARMOR := 5

var cannon_id := ""
var health := MAX_HEALTH
var intact := true
var charge_planted := false
var _map_sprite: Node2D
var _label: Label

## `map_object` is the cannon's sprite holder from the map; `size` is its sprite size.
func configure(id: String, map_object: Node2D, size: Vector2) -> void:
	cannon_id = id
	_map_sprite = map_object
	# The node sits at the cannon's feet so distances match the other actors.
	global_position = map_object.global_position + Vector2(size.x * 0.5, size.y - 4.0)
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(size.x * 0.7, size.y * 0.55)
	collision.shape = box
	collision.position = Vector2(0, -size.y * 0.35)
	add_child(collision)
	_label = Label.new()
	_label.position = Vector2(-50, -size.y - 8)
	_label.size = Vector2(100, 14)
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
	add_to_group("damageable")
	add_to_group("interactable")
	add_to_group("battery_cannon")

func get_interaction_text() -> String:
	return "Plant a demolition charge on the Republic cannon"

func get_interaction_position() -> Vector2:
	return global_position

func interact(_actor: Node) -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world != null and world.has_method("plant_charge"):
		world.call("plant_charge", self)

func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if not intact or amount <= 0:
		return
	health = maxi(0, health - maxi(1, amount - ARMOR))
	_label.visible = true
	_label.text = "Republic cannon %d/%d" % [health, MAX_HEALTH]
	if health == 0:
		destroy()

func repair() -> void:
	if intact:
		health = MAX_HEALTH
		_label.visible = false

func destroy() -> void:
	if not intact:
		return
	show_wrecked()
	destroyed.emit(cannon_id)

## Puts an intact gun back, e.g. after loading a save from before it was destroyed.
func restore() -> void:
	intact = true
	health = MAX_HEALTH
	charge_planted = false
	collision_layer = 8
	_label.visible = false
	add_to_group("damageable")
	add_to_group("interactable")
	if is_instance_valid(_map_sprite):
		_map_sprite.modulate = Color.WHITE
		_map_sprite.rotation_degrees = 0.0

## Shows the wrecked gun without reporting a new kill, e.g. after loading a save.
func show_wrecked() -> void:
	intact = false
	health = 0
	charge_planted = false
	collision_layer = 0
	_label.visible = false
	remove_from_group("damageable")
	remove_from_group("interactable")
	if is_instance_valid(_map_sprite):
		_map_sprite.modulate = Color(0.32, 0.30, 0.34)
		_map_sprite.rotation_degrees = 4.0
