class_name StationSoldier
extends CharacterBody2D

const WALK_SPEED := 26.0
const LINES := [
	"The transport apron is busy again. It is good to hear an engine instead of the range bell.",
	"I am taking the long path past the canteen before the next watch.",
	"Those ships by the northeast apron are staying parked today.",
	"The training crew painted the targets bright enough for everyone to see.",
	"The cook saved a warm loaf for the evening shift.",
	"The station feels quieter when the recruits are at their lessons.",
]

var soldier_id := ""
var interaction_text := "Talk"
var facing := Vector2.DOWN
var _navigation: TiledLoader
var _stops: Array[Vector2] = []
var _stop_index := 0
var _wait := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _sprite: Sprite2D
var _dialogue_index := 0

func configure(id: String, texture_path: String, position: Vector2, navigation: TiledLoader, stops: Array[Vector2]) -> void:
	soldier_id = id
	interaction_text = "Talk to station soldier"
	global_position = position
	_navigation = navigation
	_stops = stops.duplicate()
	if _stops.is_empty():
		_stops.append(position)
	_stop_index = absi(soldier_id.hash()) % _stops.size()
	_dialogue_index = absi(soldier_id.hash()) % LINES.size()
	collision_layer = 4
	collision_mask = 1
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 6)
	collision.shape = box
	collision.position = Vector2(0, -3)
	add_child(collision)

func _ready() -> void:
	add_to_group("interactable")

func get_interaction_text() -> String:
	return interaction_text

func interact(_actor: Node) -> void:
	_dialogue_index = (_dialogue_index + 1 + absi(soldier_id.hash()) % 3) % LINES.size()
	GameState.notify("Station soldier: %s" % LINES[_dialogue_index])

func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector2.ZERO
		return
	if _stops.is_empty():
		return
	var destination := _stops[_stop_index]
	if global_position.distance_to(destination) < 7.0:
		_stop_index = (_stop_index + 1) % _stops.size()
		_wait = 1.4 + float(absi(soldier_id.hash() + _stop_index) % 4) * 0.6
		_path.clear()
		return
	_move_to(destination)
	z_index = 100 + int(global_position.y)

func _move_to(destination: Vector2) -> void:
	if _navigation == null:
		return
	if _path.is_empty() or _path[-1].distance_to(destination) > 12.0:
		_path = _navigation.get_walk_path(global_position, destination)
		_path_index = 0
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 4.0:
		_path_index += 1
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return
	var direction := _path[_path_index] - global_position
	if direction.length_squared() > 1.0:
		facing = Vector2(signf(direction.x), 0.0) if absf(direction.x) >= absf(direction.y) else Vector2(0.0, signf(direction.y))
		velocity = direction.normalized() * minf(WALK_SPEED, direction.length() * 12.0)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
