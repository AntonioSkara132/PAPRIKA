class_name Rabbit
extends CharacterBody2D

const WANDER_SPEED := 24.0
const FLEE_SPEED := 42.0
const FLEE_DISTANCE := 42.0
const RESPAWN_SECONDS := 20.0
const HUNT_RESPAWN_SECONDS := 35.0

var rabbit_id: String = ""
var home_position := Vector2.ZERO
var interaction_text := "Catch rabbit (E) or hunt (attack)"
var _sprite: Sprite2D
var _collision: CollisionShape2D
var _rng := RandomNumberGenerator.new()
var _wander_direction := Vector2.ZERO
var _wander_timer := 0.0
var _respawn_timer := 0.0
var _caught := false
var _built := false

func configure(texture_path: String, stable_id: String, spawn_position: Vector2) -> void:
	rabbit_id = stable_id
	home_position = spawn_position
	global_position = spawn_position
	_rng.seed = abs(stable_id.hash()) + 97
	_build(texture_path)

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("damageable")
	if not _built:
		configure("res://art/concepts/source/rabbit.png", str(get_instance_id()), global_position)

func _build(texture_path: String) -> void:
	if _built:
		return
	_built = true
	collision_layer = 32
	collision_mask = 1 | 16
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 9)
	_collision.shape = shape
	_collision.position = Vector2(0, -4.5)
	add_child(_collision)

func _physics_process(delta: float) -> void:
	if _caught:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) < FLEE_DISTANCE:
		velocity = (global_position - player.global_position).normalized() * FLEE_SPEED
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = _rng.randf_range(1.0, 3.2)
			_wander_direction = Vector2.from_angle(_rng.randf_range(0.0, TAU))
		velocity = _wander_direction * WANDER_SPEED
	move_and_slide()
	if global_position.distance_to(home_position) > 85.0:
		global_position = global_position.move_toward(home_position, FLEE_SPEED * delta)
	z_index = 100 + int(global_position.y)

func get_interaction_text() -> String:
	return interaction_text

func interact(_player: Node) -> void:
	if _caught:
		return
	GameState.record_event("rabbit_caught")
	GameState.notify("Rabbit caught without harm. This counts toward the catch job.")
	_despawn(RESPAWN_SECONDS)

func take_damage(_amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if _caught:
		return
	GameState.add_item("rabbit_meat")
	GameState.notify("Hunted a rabbit. Sell the meat at the food shop.")
	_despawn(HUNT_RESPAWN_SECONDS)

func _despawn(seconds: float) -> void:
	_caught = true
	_respawn_timer = seconds
	visible = false
	remove_from_group("interactable")
	remove_from_group("damageable")
	_collision.set_deferred("disabled", true)

func _respawn() -> void:
	_caught = false
	global_position = home_position + Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(-22.0, 22.0))
	visible = true
	add_to_group("interactable")
	add_to_group("damageable")
	_collision.set_deferred("disabled", false)
