class_name Enemy
extends CharacterBody2D

signal defeated(persistent_id: String)

enum State { IDLE, PATROL, CHASE, TELEGRAPH, RECOVER, RETURN, PHASE_WARNING }

const RESPAWN_SECONDS := 75.0
const PHASE_COOLDOWN := 6.0
const PHASE_WARNING_SECONDS := 0.55
const PHASE_LEASH := 150.0
const CIVILIAN_SIGHT := 112.0

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
var _phase_cooldown := 2.0
var _phase_destination := Vector2.ZERO
var _phase_warning: ColorRect
var _attack_target: Node2D
var _weapon_visual: Line2D
## Soldiers that hold a trench fire from where they stand instead of walking up to a target.
var hold_ground := false
var _march := PackedVector2Array()
var _march_index := 0
## Walking route for Republic soldiers, so a chase goes round cliffs and walls.
var _ground_path := PackedVector2Array()
var _ground_path_index := 0
var _ground_repath_timer := 0.0

func configure(kind: String, texture_path: String, position_in_world: Vector2, stable_id: String) -> void:
	enemy_id = kind
	var team_bandit := stable_id.begins_with("camp_bandit_") or stable_id.begins_with("brudet_team_bandit_")
	if kind == "bandit" or (kind == "camp_bandit" and team_bandit):
		enemy_id = ["bandit_spear", "bandit_bow", "bandit_sword"][int(stable_id.get_slice("_", stable_id.get_slice_count("_") - 1)) % 3]
	persistent_id = stable_id
	definition = GameData.enemy(enemy_id).duplicate()
	if kind == "bandit":
		definition["reward"] = int(GameData.enemy(kind).get("reward", 12))
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
	collision_mask = 1 | 2 | 64 if _is_river_monster() else 1 | 2 | 16 | 64
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
	_label.text = "%s  Lv.%d" % [_display_name(), int(definition.get("level", 1))]
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
	elif enemy_id == "phase_hacker":
		_sprite.modulate = Color(0.30, 0.95, 0.92)
	elif enemy_id == "zombie":
		_sprite.modulate = Color(0.55, 0.86, 0.58)
	elif enemy_id == "zombie_bear":
		_sprite.scale = Vector2(1.45, 1.45)
		_sprite.modulate = Color(0.54, 0.72, 0.50)
	else:
		_sprite.modulate = _base_modulate()
	_build_gear()

func _build_gear() -> void:
	if enemy_id not in ["bandit_spear", "bandit_bow", "bandit_sword", "armed_zombie", "armored_zombie", "republic_archer", "republic_spearman", "republic_swordsman"]:
		return
	_weapon_visual = Line2D.new()
	_weapon_visual.width = 2.0
	_weapon_visual.z_index = 2
	match enemy_id:
		"bandit_spear", "republic_spearman":
			_weapon_visual.points = PackedVector2Array([Vector2(7, -5), Vector2(10, -23), Vector2(10, -26)])
			_weapon_visual.default_color = Color("dfd9b8")
		"bandit_bow", "republic_archer":
			_weapon_visual.points = PackedVector2Array([Vector2(9, -19), Vector2(13, -16), Vector2(15, -12), Vector2(13, -8), Vector2(9, -6), Vector2(9, -19)])
			_weapon_visual.default_color = Color("ba8953")
		"bandit_sword", "armed_zombie", "armored_zombie", "republic_swordsman":
			_weapon_visual.points = PackedVector2Array([Vector2(7, -5), Vector2(11, -12), Vector2(13, -20)])
			_weapon_visual.default_color = Color("d7e3e4")
		_:
			return
	add_child(_weapon_visual)
	if enemy_id == "armored_zombie":
		var armor := Polygon2D.new()
		armor.polygon = PackedVector2Array([Vector2(-7, -18), Vector2(6, -18), Vector2(8, -9), Vector2(-8, -9)])
		armor.color = Color("a97843")
		armor.z_index = 1
		add_child(armor)

func _physics_process(delta: float) -> void:
	if _defeated:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	_state_time = maxf(0.0, _state_time - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_phase_cooldown = maxf(0.0, _phase_cooldown - delta)
	_river_repath_timer = maxf(0.0, _river_repath_timer - delta)
	_ground_repath_timer = maxf(0.0, _ground_repath_timer - delta)
	var target := _nearest_target()
	if _marching() and state not in [State.TELEGRAPH, State.RECOVER] and (target == null or global_position.distance_to(target.global_position) >= _sight()):
		_step_march()
		z_index = 100 + int(global_position.y)
		return
	if target == null:
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(target.global_position)
	_label.visible = distance < 92.0 or health < max_health
	if enemy_id in ["hacker", "phase_hacker"] and state != State.PHASE_WARNING and distance < 170.0 and _attack_cooldown <= 0.0:
		_fire_hostile_projectile(target, 130.0, 190.0)
		_attack_cooldown = 1.25
	if state not in [State.TELEGRAPH, State.RECOVER, State.PHASE_WARNING]:
		var sight := _sight()
		if global_position.distance_to(spawn_position) > 190.0:
			state = State.RETURN
		elif distance < sight:
			state = State.CHASE
		elif global_position.distance_to(spawn_position) > 155.0:
			state = State.RETURN
		elif state == State.CHASE:
			_choose_patrol()
	if enemy_id == "phase_hacker" and state == State.CHASE and distance < 125.0 and distance > 24.0 and _phase_cooldown <= 0.0:
		_start_phase(target)
	match state:
		State.PHASE_WARNING:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				_finish_phase()
		State.IDLE:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				_choose_patrol()
		State.PATROL:
			if not hold_ground:
				_move_toward(_patrol_target, float(definition.get("speed", 35.0)) * 0.45)
			if hold_ground or global_position.distance_to(_patrol_target) < 5.0:
				state = State.IDLE
				_state_time = _rng.randf_range(1.0, 2.8)
		State.CHASE:
			if distance <= _attack_reach() and _attack_cooldown <= 0.0:
				_attack_target = target
				state = State.TELEGRAPH
				_state_time = 0.52 if enemy_id == "river_serpent" else (0.42 if enemy_id == "bandit_bow" else (0.18 if enemy_id == "hacker" else 0.28))
				velocity = Vector2.ZERO
				_sprite.modulate = Color(1.0, 0.35, 0.35)
			elif hold_ground:
				velocity = Vector2.ZERO
			else:
				_move_toward(target.global_position, float(definition.get("speed", 35.0)))
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				if is_instance_valid(_attack_target) and not _attack_target.is_queued_for_deletion() and _attack_target.visible and global_position.distance_to(_attack_target.global_position) <= _attack_reach() + 5.0:
					if _is_ranged():
						_fire_hostile_projectile(_attack_target, 165.0 if enemy_id == "bandit_bow" else 145.0, _attack_reach() + 22.0)
					elif _attack_target.has_method("take_damage"):
						_attack_target.take_damage(int(definition.get("damage", 3)), global_position)
				_attack_target = null
				_attack_cooldown = float(definition.get("attack_cooldown", 1.0))
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

func _start_phase(target: Node2D) -> void:
	_phase_cooldown = PHASE_COOLDOWN
	var world := get_parent().get_parent() as GameWorld
	if world == null or world.tiled_loader == null:
		return
	var navigation := world.tiled_loader
	var space := get_world_2d().direct_space_state
	for attempt in 16:
		var angle := _rng.randf_range(-PI, PI)
		var radius := _rng.randf_range(32.0, 65.0)
		var candidate := target.global_position + Vector2.from_angle(angle) * radius
		if candidate.distance_to(spawn_position) > PHASE_LEASH:
			continue
		var clear := true
		for offset in [Vector2.ZERO, Vector2(-6, -5), Vector2(6, -5), Vector2(-6, 2), Vector2(6, 2)]:
			if not navigation.is_walkable_position(candidate + offset):
				clear = false
				break
		if not clear:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = _collision.shape
		query.transform = Transform2D(0.0, candidate + _collision.position)
		query.collision_mask = 1 | 2 | 8 | 16 | 64
		query.exclude = [get_rid()]
		if not space.intersect_shape(query, 1).is_empty():
			continue
		_phase_destination = candidate
		state = State.PHASE_WARNING
		_state_time = PHASE_WARNING_SECONDS
		velocity = Vector2.ZERO
		_phase_warning = ColorRect.new()
		_phase_warning.color = Color(1.0, 0.15, 0.65, 0.75)
		_phase_warning.size = Vector2(16, 10)
		_phase_warning.position = candidate - _phase_warning.size * 0.5
		_phase_warning.z_index = 100 + int(candidate.y)
		get_parent().add_child(_phase_warning)
		var tween := create_tween()
		tween.tween_property(_phase_warning, "modulate:a", 0.25, PHASE_WARNING_SECONDS * 0.5)
		tween.tween_property(_phase_warning, "modulate:a", 1.0, PHASE_WARNING_SECONDS * 0.5)
		return

func _finish_phase() -> void:
	_clear_phase_warning()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.transform = Transform2D(0.0, _phase_destination + _collision.position)
	query.collision_mask = 1 | 2 | 8 | 16 | 64
	query.exclude = [get_rid()]
	var world := get_parent().get_parent() as GameWorld
	if world != null and world.tiled_loader != null and world.tiled_loader.is_walkable_position(_phase_destination) and get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		global_position = _phase_destination
	state = State.RECOVER
	_state_time = 0.35

func _clear_phase_warning() -> void:
	if is_instance_valid(_phase_warning):
		_phase_warning.queue_free()
	_phase_warning = null

func _is_ranged() -> bool:
	return bool(definition.get("ranged", false))

func _sight() -> float:
	return 150.0 if _is_ranged() else 112.0

## Walks the given route, fighting anyone met on the way, and then guards its end.
func march_along(route: PackedVector2Array) -> void:
	_march = route
	_march_index = 0
	hold_ground = false

func _marching() -> bool:
	return _march_index < _march.size()

## True once a soldier sent with `march_along` has walked its whole route.
func march_finished() -> bool:
	return not _march.is_empty() and not _marching()

func _step_march() -> void:
	while _march_index < _march.size() and global_position.distance_to(_march[_march_index]) < 5.0:
		_march_index += 1
	if not _marching():
		velocity = Vector2.ZERO
		spawn_position = global_position
		_choose_patrol()
		return
	state = State.PATROL
	_move_toward(_march[_march_index], float(definition.get("speed", 35.0)) * 0.8)
	# The leash follows the column, so soldiers met on the road are chased from here.
	spawn_position = global_position

func _attack_reach() -> float:
	return float(definition.get("reach", 18.0))

func _nearest_party_target() -> Node2D:
	var nearest: Node2D
	var best := INF
	for candidate in get_tree().get_nodes_in_group("party_target"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.visible:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			nearest = candidate
			best = distance
	return nearest

func _nearest_target() -> Node2D:
	var nearest := _nearest_party_target()
	var best := global_position.distance_squared_to(nearest.global_position) if nearest != null else INF
	if global_position.distance_to(spawn_position) < 190.0:
		for candidate in get_tree().get_nodes_in_group("civilian"):
			if not candidate is Villager or not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.is_civilian_target():
				continue
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best and distance <= CIVILIAN_SIGHT * CIVILIAN_SIGHT and _can_see_civilian(candidate):
				nearest = candidate
				best = distance
	return nearest

func _can_see_civilian(candidate: Node2D) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _move_toward(target: Vector2, movement_speed: float) -> void:
	if _is_river_monster():
		var navigation := _river_navigation()
		if navigation != null:
			if _river_repath_timer <= 0.0:
				_river_path = navigation.get_amphibious_path(global_position, target)
				_river_path_index = 0
				_river_repath_timer = 0.6
			while _river_path_index < _river_path.size() and global_position.distance_to(_river_path[_river_path_index]) < 5.0:
				_river_path_index += 1
			if _river_path_index < _river_path.size():
				target = _river_path[_river_path_index]
			else:
				velocity = Vector2.ZERO
				return
	var world := get_parent().get_parent() as GameWorld
	if world != null and enemy_id.begins_with("republic_") and world.tiled_loader != null and global_position.distance_to(target) > 20.0:
		if _ground_repath_timer <= 0.0 or _ground_path.is_empty() or _ground_path[_ground_path.size() - 1].distance_to(target) > 16.0:
			_ground_path = world.tiled_loader.get_walk_path(global_position, target)
			# The first point is the centre of the current cell; walking back to it
			# on every repath makes the soldier swing in place.
			_ground_path_index = 1 if _ground_path.size() > 1 else 0
			_ground_repath_timer = 0.5
		while _ground_path_index < _ground_path.size() and global_position.distance_to(_ground_path[_ground_path_index]) < 4.0:
			_ground_path_index += 1
		if _ground_path_index < _ground_path.size():
			target = _ground_path[_ground_path_index]
	if world != null:
		movement_speed *= world.movement_factor(global_position)
	velocity = (target - global_position).normalized() * movement_speed
	move_and_slide()

func _choose_patrol() -> void:
	if _is_river_monster() and is_inside_tree():
		var navigation := _river_navigation()
		if navigation != null:
			for attempt in 8:
				var candidate := spawn_position + Vector2(_rng.randf_range(-38.0, 38.0), _rng.randf_range(-28.0, 28.0))
				if navigation.is_amphibious_walkable_position(candidate) and not navigation.get_amphibious_path(spawn_position, candidate).is_empty():
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
	var applied := maxi(1, amount - int(definition.get("armor", 0))) if amount > 0 else 0
	health = maxi(0, health - applied)
	_label.visible = true
	_label.text = "%s  Lv.%d  %d/%d" % [_display_name(), int(definition.get("level", 1)), health, max_health]
	_sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _base_modulate(), 0.22)
	if health <= 0:
		_die()

func _die() -> void:
	_clear_phase_warning()
	remove_from_group("damageable")
	var reward := int(definition.get("reward", 0))
	GameState.add_gold(reward)
	GameState.record_event("river_monster_defeated" if _is_river_monster() else String(definition.get("event", "monster_defeated")))
	if enemy_id == "camp_bandit" or persistent_id.begins_with("camp_bandit_"):
		GameState.record_camp_defeat(persistent_id)
	if persistent_id.begins_with("brudet_team_"):
		GameState.record_team_defeat(persistent_id)
	if persistent_id == GameState.BRUDET_SOLO_HACKER_ID:
		GameState.record_solo_hacker_defeat(persistent_id)
	if GameState.ROAD_IDS.has(persistent_id):
		GameState.record_road_defeat(persistent_id)
	GameState.notify("Defeated %s. Found %d gold." % [definition.get("name", enemy_id), reward])
	defeated.emit(persistent_id)
	var hacker_bounty_ready := enemy_id == "hacker" and GameState.active_job_ready("hacker_bounty")
	if hacker_bounty_ready and not GameState.defeated_persistent_enemies.has(persistent_id):
		GameState.defeated_persistent_enemies.append(persistent_id)
	if hacker_bounty_ready or (enemy_id == "hacker" and GameState.completed_unique_jobs.has("hacker_bounty")) or enemy_id == "camp_bandit" or persistent_id.begins_with("camp_bandit_") or persistent_id.begins_with("brudet_team_") or persistent_id == GameState.BRUDET_SOLO_HACKER_ID or persistent_id.begins_with("artichoke_"):
		queue_free()
	else:
		_defeated = true
		_respawn_timer = RESPAWN_SECONDS
		visible = false
		collision_layer = 0
		_collision.set_deferred("disabled", true)

func restore_road_defeat() -> void:
	if _defeated:
		return
	_clear_phase_warning()
	_attack_target = null
	_defeated = true
	health = 0
	_respawn_timer = 5.0
	visible = false
	collision_layer = 0
	_collision.set_deferred("disabled", true)
	remove_from_group("damageable")

func _respawn() -> void:
	if GameState.ROAD_IDS.has(persistent_id) and GameState.team_job_id == GameState.ROAD_JOB and GameState.team_defeated_ids.has(persistent_id):
		_respawn_timer = 5.0
		return
	for actor in get_tree().get_nodes_in_group("party_target"):
		if actor is Node2D and actor.global_position.distance_to(spawn_position) < 75.0:
			_respawn_timer = 5.0
			return
	_defeated = false
	health = max_health
	global_position = spawn_position
	_sprite.modulate = _base_modulate()
	_label.text = "%s  Lv.%d" % [_display_name(), int(definition.get("level", 1))]
	_label.visible = false
	collision_layer = 8
	_collision.set_deferred("disabled", false)
	add_to_group("damageable")
	_choose_patrol()
	visible = true

func reset_after_player_defeat() -> void:
	if _defeated or health <= 0:
		return
	_clear_phase_warning()
	_phase_cooldown = PHASE_COOLDOWN
	global_position = spawn_position
	velocity = Vector2.ZERO
	_attack_cooldown = 1.0
	_state_time = 1.0
	state = State.IDLE
	_sprite.modulate = _base_modulate()
	_label.visible = false

func _fire_hostile_projectile(target: Node2D, speed: float, reach: float) -> void:
	var projectile := Projectile.new()
	get_parent().add_child(projectile)
	var origin := global_position + Vector2(0, -8)
	projectile.configure(origin, (target.global_position + Vector2(0, -3) - origin).normalized(), int(definition.get("damage", 18)), speed, reach, false)

func _display_name() -> String:
	return "Phase Hacker" if enemy_id == "phase_hacker" else String(definition.get("name", enemy_id.capitalize()))

func _base_modulate() -> Color:
	match enemy_id:
		"hacker": return Color(0.85, 0.42, 1.0)
		"phase_hacker": return Color(0.30, 0.95, 0.92)
		"zombie": return Color(0.55, 0.86, 0.58)
		"armed_zombie": return Color(0.58, 0.77, 0.53)
		"armored_zombie": return Color(0.66, 0.71, 0.58)
		"zombie_bear": return Color(0.54, 0.72, 0.50)
		"bandit": return Color(0.95, 0.62, 0.50)
		"camp_bandit": return Color(1.0, 0.35, 0.28)
		"bandit_spear": return Color(1.0, 0.35, 0.28)
		"bandit_bow": return Color(0.36, 0.65, 1.0)
		"bandit_sword": return Color(0.77, 0.42, 0.95)
		"finling": return Color(0.70, 0.96, 0.87)
		"lake_maw": return Color(0.89, 0.83, 0.67)
		"river_serpent": return Color(0.80, 0.92, 1.0)
		_: return Color.WHITE
