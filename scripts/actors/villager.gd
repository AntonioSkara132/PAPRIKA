class_name Villager
extends CharacterBody2D

const WALK_SPEED := 30.0

var villager_id: String = ""
var villager_name: String = "Villager"
var home_position := Vector2.ZERO
var routine_points: Array[Vector2] = []
var interaction_text := "Talk"
var is_farmer := false
var _target := Vector2.ZERO
var _wait_time := 0.0
var _sprite: Sprite2D
var _sprite_base_position := Vector2.ZERO
var _hoe: Line2D
var _navigation: TiledLoader
var _field_points: Array[Vector2] = []
var _path := PackedVector2Array()
var _path_index := 0
var _path_dirty := true
var _working_target := false
var _work_phase := 0.0
var _stuck_time := 0.0
var _rng := RandomNumberGenerator.new()
var _built := false

const FIRST_NAMES := [
	"Mara", "Tovin", "Elia", "Bram", "Sera", "Niko", "Vela", "Orin", "Dena", "Pavel",
	"Iris", "Milo", "Rina", "Cal", "Anya", "Teo", "Lina", "Jori", "Petra", "Galen",
]
const DIALOGUE := [
	"The common fields belong to everyone. Work honestly and Paprika will feed you.",
	"Spaceships look modern, but the forge still makes the best tools by hand.",
	"Do not follow the forest road too far without armor.",
	"The travel fare is one thousand gold. Most villagers never leave Paprika.",
	"They say a hacker is hiding beyond the old trees. I would not test that story.",
	"Crops return quickly here. Craft was never built to obey ordinary physics.",
]

func configure(texture_path: String, stable_id: String, spawn_position: Vector2, points: Array[Vector2] = []) -> void:
	villager_id = stable_id
	home_position = spawn_position
	global_position = spawn_position
	routine_points.clear()
	for point in points:
		if absf(point.x - home_position.x) <= 350.0 and absf(point.y - home_position.y) <= 150.0:
			routine_points.append(point)
	_rng.seed = abs(stable_id.hash()) + 31
	villager_name = FIRST_NAMES[_rng.randi_range(0, FIRST_NAMES.size() - 1)]
	interaction_text = "Talk to %s" % villager_name
	_build(texture_path)
	_choose_next_target()

func _ready() -> void:
	add_to_group("interactable")
	if not _built:
		configure("res://art/concepts/source/villager1.png", str(get_instance_id()), global_position)
	_navigation = get_tree().get_first_node_in_group("tiled_world") as TiledLoader
	if _navigation != null and abs(villager_id.hash()) % 4 == 0:
		var field_positions := _navigation.get_common_field_positions()
		var first_field_y := INF
		for point in field_positions:
			first_field_y = minf(first_field_y, point.y)
		for point in field_positions:
			if point.y <= first_field_y + _navigation.tile_size.y * 5.0:
				_field_points.append(point)
		is_farmer = not _field_points.is_empty()
		if is_farmer:
			_choose_next_target()

func _build(texture_path: String) -> void:
	if _built:
		return
	_built = true
	collision_layer = 4
	collision_mask = 1
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	_sprite_base_position = _sprite.position
	add_child(_sprite)
	_hoe = Line2D.new()
	_hoe.points = PackedVector2Array([Vector2(3, -9), Vector2(10, -15), Vector2(7, -16), Vector2(13, -16)])
	_hoe.width = 1.5
	_hoe.default_color = Color("9b724b")
	_hoe.visible = false
	add_child(_hoe)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(7, 5)
	collision.shape = shape
	collision.position = Vector2(0, -2.5)
	add_child(collision)

func _physics_process(delta: float) -> void:
	if _wait_time > 0.0:
		_wait_time -= delta
		velocity = Vector2.ZERO
		_animate_work(delta, _working_target)
		if _wait_time <= 0.0:
			_animate_work(0.0, false)
			_choose_next_target()
	else:
		_animate_work(0.0, false)
		if _path_dirty:
			_refresh_path()
		if _wait_time <= 0.0:
			_follow_path(delta)
	z_index = 100 + int(global_position.y)

func _refresh_path() -> void:
	_path_dirty = false
	if _navigation == null:
		_navigation = get_tree().get_first_node_in_group("tiled_world") as TiledLoader
	_path = _navigation.get_walk_path(global_position, _target) if _navigation != null else PackedVector2Array()
	_path_index = 0
	_stuck_time = 0.0
	if _path.is_empty():
		_working_target = false
		_wait_time = 0.8

func _follow_path(delta: float) -> void:
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 3.0:
		_path_index += 1
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		_wait_time = _rng.randf_range(2.4, 4.8) if _working_target else _rng.randf_range(1.6, 4.8)
		return
	var offset := _path[_path_index] - global_position
	velocity = offset.normalized() * WALK_SPEED
	var previous_position := global_position
	move_and_slide()
	if global_position.distance_to(previous_position) < 0.05:
		_stuck_time += delta
		if _stuck_time >= 1.0:
			velocity = Vector2.ZERO
			_working_target = false
			_wait_time = 0.8
	else:
		_stuck_time = 0.0

func _animate_work(delta: float, working: bool) -> void:
	_hoe.visible = working
	if working:
		_work_phase += delta * 8.0
		_hoe.rotation = sin(_work_phase) * 0.16
		_sprite.position = _sprite_base_position + Vector2(0.0, sin(_work_phase * 2.0))
	else:
		_hoe.rotation = 0.0
		_sprite.position = _sprite_base_position

func get_interaction_text() -> String:
	return interaction_text

func interact(_player: Node) -> void:
	var line: String = DIALOGUE[abs((villager_id + str(int(GameState.play_seconds / 10.0))).hash()) % DIALOGUE.size()]
	GameState.notify("%s: %s" % [villager_name, line])

func _choose_next_target() -> void:
	_working_target = is_farmer and not _field_points.is_empty() and _rng.randf() < 0.75
	if _working_target:
		_target = _field_points[_rng.randi_range(0, _field_points.size() - 1)]
	elif not routine_points.is_empty() and _rng.randf() < 0.60:
		_target = routine_points[_rng.randi_range(0, routine_points.size() - 1)]
	else:
		_target = home_position + Vector2(_rng.randf_range(-42.0, 42.0), _rng.randf_range(-30.0, 30.0))
	_path_dirty = true
	_path.clear()
	_path_index = 0
