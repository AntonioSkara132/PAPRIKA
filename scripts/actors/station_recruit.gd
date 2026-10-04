class_name StationRecruit
extends CharacterBody2D

signal training_hit(recruit_id: String, team: String, damage: int)
signal training_defeated(recruit_id: String, team: String)

const WALK_SPEED := 35.0
const TRAINING_SPEED := 53.0
const GENERAL_LINES := [
	"That was a long day. I think I'll sit down before supper.",
	"The instructor notices everything, even when they seem to be looking away.",
	"I hate our training instructor. Somehow they can spot a crooked step from across the field.",
	"Long day of training to go. Let's get through it together.",
	"I thought the running track would be the easy part. I was wrong.",
	"We should get to the canteen before the good bread is gone.",
	"I keep forgetting which barracks door is ours.",
	"We train together, then we all get to go home together.",
]
const STAGE_LINES := {
	"depot": ["They measured my uniform twice and still gave me the wrong sleeve length.", "Meet us at the barracks once you've visited the depot."],
	"barracks": ["I labeled my footlocker so I wouldn't pick up someone else's things.", "The bunks are narrow, but at least they're ours."],
	"run": ["Keep a little energy for the last marker.", "I counted the checkpoints twice and still missed one turn."],
	"spar": ["The sparring partner moves faster than they look.", "A clean practice hit counts; nobody needs an injury."],
	"squad": ["Give us a clear order and we'll move with you.", "Holding position is harder than rushing forward."],
	"range": ["The moving targets never wait for me to aim.", "I can hear the range bell from the barracks."],
	"cannon": ["The training cannon is just part of the course; I prefer the running track.", "That painted target is bigger than it looks from here."],
	"trap": ["The moving dummy is our last test today.", "The dummy only triggers the toy practice mine after you place it on the lane."],
	"sleep": ["The drills are done. I'm headed for my bunk.", "A little sleep will make tomorrow much easier."],
	"graduated": ["We made it through the course. Supper tastes better now.", "I hope we can all share another quiet evening after this."],
}
const ORIGIN_LINES := {
	"Paprika": ["Oh, you're from Paprika too? I thought I recognized you from the market.", "I miss the smell of fresh bread by Paprika's common fields.", "Back home I knew every path between the forge and the square."],
	"Brudet": ["The fish stew here tastes nothing like Brudet's.", "I miss watching the boats drift under the bridges.", "They served something they called river fish. My family would disagree."],
	"Confederation": ["When this is over, come to my hometown. I'll buy you a glass of spiced plum fizz.", "At home the evening markets stay open until the lanterns go out.", "The station is busier than any street where I grew up."],
}

var recruit_id := ""
var recruit_name := ""
var origin := ""
var interaction_text := "Talk"
var facing := Vector2.DOWN
var training_team := ""
var training_health := 0
var training_active := false
var training_down := false
var training_order := "follow"
var training_focus := Vector2.ZERO
var home_position := Vector2.ZERO
var _navigation: TiledLoader
var _stops: Array[Vector2] = []
var _stop_index := 0
var _wait := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _arena := Vector2.ZERO
var _training_destination := Vector2.ZERO
var _attack_timer := 0.0
var _repath_timer := 0.0
var _sprite: Sprite2D
var _name_label: Label
var _last_line := ""
var _dialogue_index := 0

func configure(data: Dictionary, position: Vector2, navigation: TiledLoader, stops: Array[Vector2] = []) -> void:
	recruit_id = String(data.get("id", ""))
	recruit_name = String(data.get("name", "Recruit"))
	origin = String(data.get("origin", "Confederation"))
	global_position = position
	home_position = position
	_navigation = navigation
	_stops = stops.duplicate()
	if _stops.is_empty():
		_stops.append(position)
	_stop_index = absi(recruit_id.hash()) % _stops.size()
	_dialogue_index = absi(recruit_id.hash()) % 17
	interaction_text = "Talk to %s" % recruit_name
	collision_layer = 4
	collision_mask = 1
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(String(data["texture"])) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(9, 7)
	collision.shape = box
	collision.position = Vector2(0, -3.5)
	add_child(collision)
	_name_label = Label.new()
	_name_label.text = recruit_name
	_name_label.position = Vector2(-42, -37)
	_name_label.size = Vector2(84, 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_color", Color("fff1c5"))
	add_child(_name_label)

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("station_recruit")

func get_interaction_text() -> String:
	return interaction_text

func interact(_actor: Node) -> void:
	var stage := _current_stage()
	var choices: Array[String] = []
	for line in ORIGIN_LINES.get(origin, ORIGIN_LINES["Confederation"]):
		choices.append(String(line))
	for line in GENERAL_LINES:
		choices.append(line)
	for line in STAGE_LINES.get(stage, []):
		choices.append(String(line))
	if training_active:
		choices.append("Let's finish this round first. We'll talk afterward.")
	if choices.is_empty():
		return
	_dialogue_index = (_dialogue_index + 1 + absi(recruit_id.hash()) % 3) % choices.size()
	if choices[_dialogue_index] == _last_line:
		_dialogue_index = (_dialogue_index + 1) % choices.size()
	_last_line = choices[_dialogue_index]
	GameState.notify("%s: %s" % [recruit_name, _last_line])

func _current_stage() -> String:
	return String(GameState.military_stage)

func start_training(team: String, arena: Vector2, health: int = 16) -> void:
	training_team = team
	training_active = true
	training_down = false
	training_health = health
	_arena = arena
	training_order = "follow"
	training_focus = global_position
	_training_destination = global_position
	_attack_timer = 0.0
	_repath_timer = 0.0
	_path.clear()
	collision_layer = 8 if team in ["spar", "cadet"] else 4 | 64
	if team in ["spar", "cadet"]:
		add_to_group("damageable")
	else:
		remove_from_group("damageable")
	_sprite.modulate = Color("ffb6a9") if team == "cadet" else (Color("b7e7ff") if team == "ally" else Color("fff2b4"))

func stop_training() -> void:
	training_active = false
	training_down = false
	training_team = ""
	training_health = 0
	collision_layer = 4
	remove_from_group("damageable")
	_sprite.modulate = Color.WHITE
	_path.clear()
	_wait = 0.3
	_stop_index = 0

func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if not training_active or training_down or training_team not in ["spar", "cadet"] or amount <= 0:
		return
	var practice_damage := 1 if training_team == "spar" else amount
	training_health = maxi(0, training_health - practice_damage)
	training_hit.emit(recruit_id, training_team, practice_damage)
	_sprite.modulate = Color.WHITE
	create_tween().tween_property(_sprite, "modulate", Color("ffb6a9") if training_team == "cadet" else Color("fff2b4"), 0.16)
	if training_health == 0:
		_mark_down()

func receive_training_hit(amount: int = 1) -> void:
	if not training_active or training_down or training_team != "ally":
		return
	training_health = maxi(0, training_health - amount)
	if training_health == 0:
		_mark_down()

func _mark_down() -> void:
	training_down = true
	velocity = Vector2.ZERO
	collision_layer = 4
	remove_from_group("damageable")
	_sprite.modulate = Color("828898")
	training_defeated.emit(recruit_id, training_team)

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if training_active:
		_training_step(delta)
	else:
		_routine_step(delta)
	z_index = 100 + int(global_position.y)

func _routine_step(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector2.ZERO
		return
	if _stops.is_empty():
		return
	var destination := _stops[_stop_index]
	if global_position.distance_to(destination) < 8.0:
		_stop_index = (_stop_index + 1) % _stops.size()
		_wait = 1.8 + float(absi(recruit_id.hash()) % 4)
		_path.clear()
		return
	_move_to(destination, WALK_SPEED)

func _training_step(delta: float) -> void:
	if training_down:
		velocity = Vector2.ZERO
		return
	if training_team == "ally":
		if training_order == "hold":
			velocity = Vector2.ZERO
			return
		if global_position.distance_to(training_focus) > (15.0 if training_order == "attack" else 29.0):
			_move_to(training_focus, TRAINING_SPEED)
		else:
			velocity = Vector2.ZERO
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = 0.8 + float(absi(recruit_id.hash()) % 4) * 0.14
		var time := float(Time.get_ticks_msec()) / 1000.0
		var angle := time * 0.8 + float(absi(recruit_id.hash()) % 10) * 1.7
		_training_destination = _arena + Vector2(cos(angle) * 38.0, sin(angle) * 20.0)
		if _navigation != null and not _navigation.is_walkable_position(_training_destination):
			_training_destination = _arena
		_path.clear()
	_move_to(_training_destination, TRAINING_SPEED)

func move_to_training_point(destination: Vector2, speed: float = TRAINING_SPEED) -> void:
	if training_active and not training_down:
		_move_to(destination, speed)

func ready_to_strike() -> bool:
	return training_active and not training_down and _attack_timer <= 0.0

func mark_strike(cooldown: float = 1.0) -> void:
	_attack_timer = cooldown

func _move_to(destination: Vector2, speed: float) -> void:
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
		facing = Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
		velocity = direction.normalized() * minf(speed, direction.length() * 12.0)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
