class_name PracticeTarget
extends StaticBody2D

const TARGET_TEXTURE := "res://assets/art/river_planet/arrow_target.png"

var health := 20
var _sprite: Sprite2D
var _label: Label

func _ready() -> void:
	add_to_group("damageable")
	collision_layer = 32
	collision_mask = 0
	_sprite = Sprite2D.new()
	_sprite.texture = load(TARGET_TEXTURE) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(13, 18)
	collision.shape = shape
	collision.position = Vector2(0, -9)
	add_child(collision)
	_label = Label.new()
	_label.text = "PRACTICE TARGET"
	_label.position = Vector2(-42, -34)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("f6d391"))
	_label.visible = false
	add_child(_label)
	z_index = 100 + int(global_position.y)

func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	health = maxi(0, health - amount)
	_label.text = "HIT!  %d/20" % health
	_label.visible = true
	_sprite.modulate = Color("fff2a7")
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.18)
	if health == 0:
		GameState.notify("Bullseye! The practice target is reset.")
		health = 20
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if is_instance_valid(_label):
			_label.visible = false
	)
