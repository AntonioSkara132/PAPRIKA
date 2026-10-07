class_name FarmAnimal
extends Node2D

## A cow or pig that wanders inside its pasture. It has no collision and nothing
## can attack it; the fence around the pasture keeps the player out.

const SPEED := 12.0

var animal_id := ""
## The pasture inside its fence, in world coordinates.
var pasture := Rect2()
var _sprite: Sprite2D
var _target := Vector2.ZERO
var _wait := 0.0
var _rng := RandomNumberGenerator.new()

func configure(id: String, texture_path: String, position_in_world: Vector2, pasture_rect: Rect2) -> void:
	animal_id = id
	name = "animal_" + id
	global_position = position_in_world
	pasture = pasture_rect
	_rng.seed = abs(id.hash()) + 17
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	_target = global_position
	_wait = _rng.randf_range(0.5, 4.0)

func _process(delta: float) -> void:
	z_index = 100 + int(global_position.y)
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_choose_target()
		return
	var offset := _target - global_position
	if offset.length() < 1.5:
		_wait = _rng.randf_range(2.0, 7.0)
		return
	# The sprites face right; walking left mirrors them.
	if absf(offset.x) > 0.5:
		_sprite.flip_h = offset.x < 0.0
		_sprite.position.x = -_sprite.texture.get_width() * 0.5 if _sprite.texture != null else 0.0
	global_position += offset.normalized() * minf(SPEED * delta, offset.length())

func _choose_target() -> void:
	var step := Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-24.0, 24.0))
	var goal := global_position + step
	if pasture.has_area():
		goal = goal.clamp(pasture.position, pasture.end)
	_target = goal
