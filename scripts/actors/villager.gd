class_name Villager
extends CharacterBody2D

const WALK_SPEED := 30.0
const NORTH_REGION_Y := 352.0

var villager_id: String = ""
var villager_name: String = "Villager"
var home_position := Vector2.ZERO
var routine_points: Array[Vector2] = []
var routine_role := "neighbor"
var routine_stops: Array[Dictionary] = []
var activity_kind := ""
var interaction_text := "Talk"
var is_farmer := false
var squad_member := false
var facing := Vector2.DOWN
var attack_cooldown := 0.0
var _invulnerability := 0.0
var _was_squad_member := false
var _target := Vector2.ZERO
var _wait_time := 0.0
var _sprite: Sprite2D
var _sprite_base_position := Vector2.ZERO
var _hoe: Line2D
var _activity_prop: Line2D
var _navigation: TiledLoader
var _field_points: Array[Vector2] = []
var _path := PackedVector2Array()
var _path_index := 0
var _path_dirty := true
var _working_target := false
var _work_phase := 0.0
var _gesture_phase := 0.0
var _stuck_time := 0.0
var _routine_index := 0
var _dwell_time := 2.0
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
const ROLE_DIALOGUE := {
	"farmer": ["The common field gates stay open for everyone.", "I work the rows, then rest by the square."],
	"market": ["I help carry food between the stalls and the clothing shop.", "The food shop buys crops and rabbit meat."],
	"craft": ["I bring supplies to the forge and check the work board.", "A better sword helps, but armor matters too."],
	"runner": ["I take messages between the work office and travel agency.", "The travel fare is one thousand gold; other planets are not open yet."],
	"neighbor": ["We meet at the square between errands.", "The forest road is safer with a friend and armor."],
	"fisher": ["The pond is busiest at dawn. A fishing rod and patience are all you need.", "I lower my line where the reeds meet the bank."],
	"river_farmer": ["The terraces above the river keep our crops watered.", "Good soil and a steady river make a fine harvest."],
	"river_market": ["The river market sells everything we bring in from the boats.", "Fresh fish travels quickly from the bank to the market."],
	"river_neighbor": ["Brudet's bridges keep both riverbanks close.", "I like reading by the river library after work."],
}

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

func configure_fields(field_positions: Array[Vector2], northern: bool) -> void:
	_field_points.clear()
	is_farmer = false
	if _navigation == null:
		_navigation = get_tree().get_first_node_in_group("tiled_world") as TiledLoader
	if _navigation == null or abs(villager_id.hash()) % 4 != 0:
		return
	var first_field_y := INF
	for point in field_positions:
		if (point.y < NORTH_REGION_Y) == northern:
			first_field_y = minf(first_field_y, point.y)
	if first_field_y == INF:
		return
	for point in field_positions:
		if (point.y < NORTH_REGION_Y) == northern and point.y <= first_field_y + _navigation.tile_size.y * 5.0:
			_field_points.append(point)
	is_farmer = not _field_points.is_empty()

func configure_routine(role: String, stops: Array[Dictionary]) -> void:
	routine_role = role
	_configure_activity_prop()
	routine_stops.clear()
	for stop in stops:
		if stop.has("position"):
			routine_stops.append(stop)
	_routine_index = abs(villager_id.hash()) % maxi(1, routine_stops.size())
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
	_activity_prop = Line2D.new()
	_activity_prop.width = 1.5
	_activity_prop.visible = false
	_activity_prop.z_index = 2
	add_child(_activity_prop)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(7, 5)
	collision.shape = shape
	collision.position = Vector2(0, -2.5)
	add_child(collision)

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)
	if squad_member:
		_was_squad_member = true
		_animate_work(0.0, false)
		_animate_activity(0.0, false)
		var world := get_parent().get_parent() as GameWorld
		if world != null:
			world.step_squad_actor(self, delta)
		return
	if _wait_time > 0.0:
		_wait_time -= delta
		velocity = Vector2.ZERO
		_animate_work(delta, _working_target)
		_animate_activity(delta, not _working_target and activity_kind not in ["", "home"])
		if _wait_time <= 0.0:
			_animate_work(0.0, false)
			_animate_activity(0.0, false)
			_choose_next_target()
	else:
		_animate_work(0.0, false)
		_animate_activity(0.0, false)
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
	if _path.is_empty() or _path[-1].distance_to(_target) > 8.0:
		_path.clear()
		_working_target = false
		activity_kind = ""
		_wait_time = 0.8

func _follow_path(delta: float) -> void:
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 3.0:
		_path_index += 1
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		_wait_time = _dwell_time + _rng.randf_range(0.0, 1.2)
		return
	var offset := _path[_path_index] - global_position
	facing = Vector2(signf(offset.x), 0) if absf(offset.x) > absf(offset.y) else Vector2(0, signf(offset.y))
	velocity = offset.normalized() * WALK_SPEED
	var previous_position := global_position
	move_and_slide()
	if global_position.distance_to(previous_position) < 0.05:
		_stuck_time += delta
		if _stuck_time >= 1.0:
			velocity = Vector2.ZERO
			_path.clear()
			_working_target = false
			activity_kind = ""
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

func _configure_activity_prop() -> void:
	if _activity_prop == null:
		return
	match routine_role:
		"market":
			_activity_prop.points = PackedVector2Array([Vector2(-5, -11), Vector2(-5, -15), Vector2(4, -15), Vector2(4, -11), Vector2(-5, -11)])
			_activity_prop.default_color = Color("d2a361")
		"craft":
			_activity_prop.points = PackedVector2Array([Vector2(2, -16), Vector2(2, -8), Vector2(-3, -16), Vector2(7, -16)])
			_activity_prop.default_color = Color("a8b4b0")
		"runner":
			_activity_prop.points = PackedVector2Array([Vector2(-4, -15), Vector2(5, -15), Vector2(5, -10), Vector2(-4, -10), Vector2(-4, -15)])
			_activity_prop.default_color = Color("d8c396")
		"fisher":
			_activity_prop.points = PackedVector2Array([Vector2(5, -6), Vector2(11, -24), Vector2(19, -24), Vector2(20, -13)])
			_activity_prop.default_color = Color("b9d9d1")
		"river_farmer":
			_activity_prop.points = PackedVector2Array([Vector2(4, -9), Vector2(10, -17), Vector2(12, -14)])
			_activity_prop.default_color = Color("b2c874")
		"river_market":
			_activity_prop.points = PackedVector2Array([Vector2(-5, -11), Vector2(-5, -15), Vector2(4, -15), Vector2(4, -11), Vector2(-5, -11)])
			_activity_prop.default_color = Color("d2a361")
		"river_neighbor":
			_activity_prop.points = PackedVector2Array([Vector2(-4, -15), Vector2(4, -15), Vector2(4, -10), Vector2(-4, -10)])
			_activity_prop.default_color = Color("d8c396")
		_:
			_activity_prop.points = PackedVector2Array([Vector2(3, -13), Vector2(7, -15), Vector2(9, -12)])
			_activity_prop.default_color = Color("f0c491")

func _animate_activity(delta: float, active: bool) -> void:
	_activity_prop.visible = active and not squad_member
	if _activity_prop.visible:
		_gesture_phase += delta * 3.0
		_activity_prop.rotation = sin(_gesture_phase) * 0.12
	else:
		_activity_prop.rotation = 0.0

func suspend_routine() -> void:
	_was_squad_member = true
	velocity = Vector2.ZERO
	_animate_work(0.0, false)
	_animate_activity(0.0, false)

func resume_routine() -> void:
	if not _was_squad_member:
		return
	_was_squad_member = false
	_path_dirty = true
	_path.clear()
	_path_index = 0
	_wait_time = 0.0
	activity_kind = ""
	_choose_next_target()

func take_damage(raw_damage: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if not squad_member or _invulnerability > 0.0 or GameState.recruit_recovering(villager_id):
		return
	if not GameState.damage_recruit(villager_id, raw_damage):
		return
	_invulnerability = 0.6
	if GameState.recruit_recovering(villager_id):
		global_position = home_position
		velocity = Vector2.ZERO
		var member: Dictionary = GameState.squad_members[villager_id]
		member["position"] = [home_position.x, home_position.y]
		GameState.squad_members[villager_id] = member
	elif _sprite != null:
		_sprite.modulate = Color(1.0, 0.45, 0.45)
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.30)

func show_swing(reach: float) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.8, 0.96, 0.76, 0.9)
	line.points = PackedVector2Array([facing * 7.0 + Vector2(0, -7), facing * reach + Vector2(0, -7)])
	line.z_index = 950
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)

func get_interaction_text() -> String:
	return interaction_text

func interact(_player: Node) -> void:
	var lines: Array = ROLE_DIALOGUE.get(routine_role, DIALOGUE)
	var line: String = lines[abs((villager_id + str(int(GameState.play_seconds / 10.0))).hash()) % lines.size()]
	GameState.notify("%s: %s" % [villager_name, line])

func _choose_next_target() -> void:
	if not routine_stops.is_empty():
		for attempt in range(maxi(5, routine_stops.size())):
			var stop: Dictionary
			if is_farmer and not _field_points.is_empty() and _routine_index % 4 != 3:
				stop = {"kind": "field", "position": _field_points[_rng.randi_range(0, _field_points.size() - 1)], "wait": 3.2}
			else:
				var stop_index := (_routine_index / 4) % routine_stops.size() if is_farmer else _routine_index % routine_stops.size()
				stop = routine_stops[stop_index]
			_routine_index += 1
			var destination: Vector2 = stop["position"]
			if _can_reach(destination):
				_target = destination
				activity_kind = String(stop["kind"])
				_working_target = activity_kind == "field"
				_dwell_time = float(stop["wait"])
				_path_dirty = true
				_path.clear()
				_path_index = 0
				return
		_target = global_position
		activity_kind = ""
		_working_target = false
		_path.clear()
		_path_dirty = false
		_wait_time = 1.2
		return
	_working_target = is_farmer and not _field_points.is_empty() and _rng.randf() < 0.75
	if _working_target:
		_target = _field_points[_rng.randi_range(0, _field_points.size() - 1)]
	elif not routine_points.is_empty() and _rng.randf() < 0.60:
		_target = routine_points[_rng.randi_range(0, routine_points.size() - 1)]
	else:
		_target = home_position + Vector2(_rng.randf_range(-42.0, 42.0), _rng.randf_range(-30.0, 30.0))
	activity_kind = "field" if _working_target else ""
	_dwell_time = 3.2 if _working_target else 2.0
	_path_dirty = true
	_path.clear()
	_path_index = 0

func _can_reach(destination: Vector2) -> bool:
	if _navigation == null:
		return false
	var route := _navigation.get_walk_path(global_position, destination)
	return not route.is_empty() and route[-1].distance_to(destination) <= 8.0
