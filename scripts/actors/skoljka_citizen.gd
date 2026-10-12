class_name SkoljkaCitizen
extends CharacterBody2D

signal service_requested(service_id: String, display_name: String)

const WALK_SPEED := 38.0
const ESCORT_SPEED := 76.0

var citizen_id := ""
var home_position := Vector2.ZERO
var display_name := ""
var service_id := ""
var interaction_text := "Talk"
var _navigation: TiledLoader
var _stops := PackedVector2Array()
var _stop_index := 0
var _wait := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _repath := 0.0
var _target: Node2D
var _escort_slot := 0
var _mode := "wait"

func configure(id: String, title: String, texture_path: String, position: Vector2, navigation: TiledLoader) -> void:
	citizen_id = id
	display_name = title
	service_id = "skoljka:" + id
	interaction_text = "Talk to %s" % title
	global_position = position
	home_position = position
	_navigation = navigation
	collision_layer = 4
	collision_mask = 1
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	if sprite.texture != null:
		sprite.position = Vector2(-sprite.texture.get_width() * 0.5, -sprite.texture.get_height() + 2)
	add_child(sprite)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 6)
	collision.shape = box
	collision.position = Vector2(0, -3)
	add_child(collision)
	z_index = 100 + int(position.y)

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("skoljka_citizen")

func get_interaction_text() -> String:
	return interaction_text

func interact(_actor: Node) -> void:
	service_requested.emit(service_id, display_name)

func set_route(stops: PackedVector2Array) -> void:
	_stops = stops
	_stop_index = 0
	_wait = 0.0
	_mode = "routine" if stops.size() > 1 else "wait"
	_path.clear()
	_path_index = 0

func wait_at(position: Vector2) -> void:
	global_position = position
	_target = null
	_mode = "wait"
	_path.clear()
	_path_index = 0
	velocity = Vector2.ZERO
	z_index = 100 + int(position.y)

func follow_for_rescue(target: Node2D, slot: int) -> void:
	_target = target
	_escort_slot = slot
	_mode = "escort"
	_repath = 0.0
	_path.clear()
	_path_index = 0

func is_escorting() -> bool:
	return _mode == "escort"

func _physics_process(delta: float) -> void:
	z_index = 100 + int(global_position.y)
	if _navigation == null:
		return
	if _mode == "escort":
		if not is_instance_valid(_target):
			velocity = Vector2.ZERO
			return
		var distance := global_position.distance_to(_target.global_position)
		if distance < 21.0 + _escort_slot * 5.0:
			velocity = Vector2.ZERO
			return
		_walk_to(_target.global_position, ESCORT_SPEED, delta)
	elif _mode == "routine" and not _stops.is_empty():
		if _wait > 0.0:
			_wait -= delta
			velocity = Vector2.ZERO
			return
		var destination := _stops[_stop_index]
		if global_position.distance_to(destination) < 7.0:
			_stop_index = (_stop_index + 1) % _stops.size()
			_wait = 1.6 + float(_stop_index % 3)
			velocity = Vector2.ZERO
			return
		_walk_to(destination, WALK_SPEED, delta)
	else:
		velocity = Vector2.ZERO

func _walk_to(destination: Vector2, speed: float, delta: float) -> void:
	_repath -= delta
	if _path.is_empty() or _repath <= 0.0 or _path[-1].distance_to(destination) > 20.0:
		_path = _navigation.get_walk_path(global_position, destination)
		_path_index = 0
		_repath = 0.7
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 5.0:
		_path_index += 1
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return
	var offset := _path[_path_index] - global_position
	velocity = offset.normalized() * minf(speed, offset.length() * 12.0)
	move_and_slide()
