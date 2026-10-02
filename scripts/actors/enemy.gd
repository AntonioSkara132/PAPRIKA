class_name Enemy
extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, TELEGRAPH, RECOVER, RETURN }

const RESPAWN_SECONDS := 75.0

var enemy_id := "wolf"
var persistent_id := ""
var definition: Dictionary = {}
var max_health := 10
var health := 10
var spawn_position := Vector2.ZERO
var state := State.IDLE
var _state_time := 0.0
var _attack_cooldown := 0.0
var _patrol_target := Vector2.ZERO
var _sprite: Sprite2D
var _label: Label
var _collision: CollisionShape2D
var _rng := RandomNumberGenerator.new()
var _built := false
var _defeated := false
var _respawn_timer := 0.0
var _river_path := PackedVector2Array()
var _river_path_index := 0
var _river_repath_timer := 0.0

func configure(kind: String, texture_path: String, position_in_world: Vector2, stable_id: String) -> void:
	enemy_id = kind
	persistent_id = stable_id
	definition = GameData.enemy(enemy_id)
	max_health = int(definition.get("max_health", 10))
	health = max_health
	spawn_position = position_in_world
	global_position = position_in_world
	_rng.seed = abs(stable_id.hash()) + 211
	_build(texture_path)
	_choose_patrol()

func _ready() -> void:
	add_to_group("damageable")
	if not _built:
		configure("wolf", "res://art/concepts/source/wolf.png", global_position, str(get_instance_id()))
	if GameState.defeated_persistent_enemies.has(persistent_id):
		queue_free()

func _build(texture_path: String) -> void:
	if _built:
		return
	_built = true
	collision_layer = 8
	collision_mask = 1 | 2 | 64
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 7)
	_collision.shape = shape
	_collision.position = Vector2(0, -3.5)
	add_child(_collision)
	_label = Label.new()
	_label.text = "%s  Lv.%d" % [definition.get("name", enemy_id.capitalize()), int(definition.get("level", 1))]
	_label.position = Vector2(-36, -32)
	_label.size = Vector2(72, 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("f7f1dd"))
	_label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	add_child(_label)
	if enemy_id == "hacker":
		_sprite.modulate = Color(0.85, 0.42, 1.0)
	elif enemy_id == "zombie":
		_sprite.modulate = Color(0.55, 0.86, 0.58)
	elif enemy_id == "zombie_bear":
		_sprite.scale = Vector2(1.45, 1.45)
		_sprite.modulate = Color(0.54, 0.72, 0.50)
	elif enemy_id in ["bandit", "camp_bandit"]:
		_sprite.modulate = Color(0.95, 0.62, 0.50) if enemy_id == "bandit" else Color(1.0, 0.35, 0.28)
	elif _is_river_monster():
		_sprite.modulate = _base_modulate()

func _physics_process(delta: float) -> void:
	if _defeated:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	_state_time = maxf(0.0, _state_time - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_river_repath_timer = maxf(0.0, _river_repath_timer - delta)
	var player := _nearest_party_target()
	if player == null:
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(player.global_position)
	_label.visible = distance < 92.0 or health < max_health
	if enemy_id == "hacker" and distance < 170.0 and _attack_cooldown <= 0.0:
		_fire_hacker_projectile(player)
		_attack_cooldown = 1.25
	if state not in [State.TELEGRAPH, State.RECOVER]:
		if distance < 112.0 and global_position.distance_to(spawn_position) < 190.0:
			state = State.CHASE
		elif global_position.distance_to(spawn_position) > 155.0:
			state = State.RETURN
		elif state == State.CHASE and distance >= 112.0:
			_choose_patrol()
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				_choose_patrol()
		State.PATROL:
			_move_toward(_patrol_target, float(definition.get("speed", 35.0)) * 0.45)
			if global_position.distance_to(_patrol_target) < 5.0:
				state = State.IDLE
				_state_time = _rng.randf_range(1.0, 2.8)
		State.CHASE:
			if distance <= 18.0 and _attack_cooldown <= 0.0:
				state = State.TELEGRAPH
				_state_time = 0.28 if enemy_id != "hacker" else 0.18
				velocity = Vector2.ZERO
				_sprite.modulate = Color(1.0, 0.35, 0.35)
			else:
				_move_toward(player.global_position, float(definition.get("speed", 35.0)))
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				if global_position.distance_to(player.global_position) <= 23.0 and player.has_method("take_damage"):
					player.take_damage(int(definition.get("damage", 3)), global_position)
				_attack_cooldown = 1.0
				state = State.RECOVER
				_state_time = 0.42
				_sprite.modulate = _base_modulate()
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				state = State.CHASE
		State.RETURN:
			_move_toward(spawn_position, float(definition.get("speed", 35.0)))
			if global_position.distance_to(spawn_position) < 5.0:
				_choose_patrol()
	z_index = 100 + int(global_position.y)

func _nearest_party_target() -> Node2D:
	var nearest: Node2D
	var best := INF
	for candidate in get_tree().get_nodes_in_group("party_target"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			nearest = candidate
			best = distance
	return nearest

func _move_toward(target: Vector2, movement_speed: float) -> void:
	if _is_river_monster():
		var navigation := _river_navigation()
		if navigation != null:
			if _river_repath_timer <= 0.0:
				_river_path = navigation.get_walk_path(global_position, target)
				_river_path_index = 0
				_river_repath_timer = 0.6
			while _river_path_index < _river_path.size() and global_position.distance_to(_river_path[_river_path_index]) < 5.0:
				_river_path_index += 1
			if _river_path_index < _river_path.size():
				target = _river_path[_river_path_index]
			else:
				velocity = Vector2.ZERO
				return
	velocity = (target - global_position).normalized() * movement_speed
	move_and_slide()

func _choose_patrol() -> void:
	if _is_river_monster() and is_inside_tree():
		var navigation := _river_navigation()
		if navigation != null:
			for attempt in 8:
				var candidate := spawn_position + Vector2(_rng.randf_range(-38.0, 38.0), _rng.randf_range(-28.0, 28.0))
				if navigation.is_walkable_position(candidate) and not navigation.get_walk_path(spawn_position, candidate).is_empty():
					_patrol_target = candidate
					state = State.PATROL
					return
			_patrol_target = spawn_position
			state = State.IDLE
			_state_time = 1.0
			return
	_patrol_target = spawn_position + Vector2(_rng.randf_range(-38.0, 38.0), _rng.randf_range(-28.0, 28.0))
	state = State.PATROL

func _is_river_monster() -> bool:
	return enemy_id in ["finling", "lake_maw", "river_serpent"]

func _river_navigation() -> TiledLoader:
	var world := get_parent().get_parent() as GameWorld
	return world.tiled_loader if world != null else null

func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if health <= 0:
		return
	health = maxi(0, health - maxi(0, amount))
	_label.visible = true
	_label.text = "%s  Lv.%d  %d/%d" % [definition.get("name", enemy_id.capitalize()), int(definition.get("level", 1)), health, max_health]
	_sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _base_modulate(), 0.22)
	if health <= 0:
		_die()

func _die() -> void:
	remove_from_group("damageable")
	var reward := int(definition.get("reward", 0))
	GameState.add_gold(reward)
	GameState.record_event("river_monster_defeated" if _is_river_monster() else String(definition.get("event", "monster_defeated")))
	if enemy_id == "camp_bandit":
		GameState.record_camp_defeat(persistent_id)
	GameState.notify("Defeated %s. Found %d gold." % [definition.get("name", enemy_id), reward])
	if enemy_id in ["hacker", "camp_bandit"]:
		if enemy_id == "hacker" and not GameState.defeated_persistent_enemies.has(persistent_id):
			GameState.defeated_persistent_enemies.append(persistent_id)
			GameState.notify("Bandit camp mission unlocked at the mercenary center.")
		queue_free()
	else:
		_defeated = true
		_respawn_timer = RESPAWN_SECONDS
		visible = false
		collision_layer = 0
		_collision.set_deferred("disabled", true)

func _respawn() -> void:
	for actor in get_tree().get_nodes_in_group("party_target"):
		if actor is Node2D and actor.global_position.distance_to(spawn_position) < 75.0:
			_respawn_timer = 5.0
			return
	_defeated = false
	health = max_health
	global_position = spawn_position
	_sprite.modulate = _base_modulate()
	_label.text = "%s  Lv.%d" % [definition.get("name", enemy_id.capitalize()), int(definition.get("level", 1))]
	_label.visible = false
	collision_layer = 8
	_collision.set_deferred("disabled", false)
	add_to_group("damageable")
	_choose_patrol()
	visible = true

func reset_after_player_defeat() -> void:
	if _defeated or health <= 0:
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	_attack_cooldown = 1.0
	_state_time = 1.0
	state = State.IDLE
	_sprite.modulate = _base_modulate()
	_label.visible = false

func _fire_hacker_projectile(player: Node2D) -> void:
	var projectile := Projectile.new()
	get_parent().add_child(projectile)
	projectile.configure(global_position + Vector2(0, -8), (player.global_position - global_position).normalized(), int(definition.get("damage", 18)), 130.0, 190.0, false)

func _base_modulate() -> Color:
	match enemy_id:
		"hacker": return Color(0.85, 0.42, 1.0)
		"zombie": return Color(0.55, 0.86, 0.58)
		"zombie_bear": return Color(0.54, 0.72, 0.50)
		"bandit": return Color(0.95, 0.62, 0.50)
		"finling": return Color(0.70, 0.96, 0.87)
		"lake_maw": return Color(0.89, 0.83, 0.67)
		"river_serpent": return Color(0.80, 0.92, 1.0)
		_: return Color.WHITE
