class_name Player
extends CharacterBody2D

signal prompt_changed(text: String)
signal position_changed(position: Vector2)
signal respawned

const SPEED := 90.0
const INTERACTION_DISTANCE := 31.0
const RESPAWN_POSITION := Vector2(838, 620)

var facing := Vector2.DOWN
var map_bounds := Rect2(0, 0, 640, 368)
var _sprite: Sprite2D
var _armor_overlay: Sprite2D
var _attack_cooldown := 0.0
var _invulnerability := 0.0
var _position_report_timer := 0.0
var _prompt_scan_timer := 0.0
var _current_interactable: Node2D
var _last_prompt := ""
var _built := false

func configure(texture_path: String, spawn_position: Vector2, bounds: Rect2) -> void:
	global_position = spawn_position
	map_bounds = bounds
	_build(texture_path)

func _ready() -> void:
	add_to_group("player")
	if not _built:
		_build("res://art/concepts/source/player.png")
	GameState.equipment_changed.connect(_refresh_appearance)
	_refresh_appearance()

func _build(texture_path: String) -> void:
	if _built:
		return
	_built = true
	collision_layer = 2
	collision_mask = 1
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	_armor_overlay = Sprite2D.new()
	_armor_overlay.name = "ArmorOverlay"
	_armor_overlay.position = _sprite.position
	_armor_overlay.centered = false
	_armor_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_armor_overlay.visible = false
	add_child(_armor_overlay)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 6)
	collision.shape = shape
	collision.position = Vector2(0, -3)
	add_child(collision)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(0, -24)
	camera.position_smoothing_enabled = false
	camera.limit_left = int(map_bounds.position.x)
	camera.limit_top = int(map_bounds.position.y)
	camera.limit_right = int(map_bounds.end.x)
	camera.limit_bottom = int(map_bounds.end.y)
	camera.limit_smoothed = false
	add_child(camera)

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_prompt_scan_timer -= delta
	if _prompt_scan_timer <= 0.0:
		_prompt_scan_timer = 0.10
		_update_nearest_interactable()
	if _ui_is_open():
		velocity = Vector2.ZERO
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * SPEED
	if input_direction.length_squared() > 0.01:
		facing = _cardinal(input_direction)
	move_and_slide()
	global_position.x = clampf(global_position.x, map_bounds.position.x + 6, map_bounds.end.x - 6)
	global_position.y = clampf(global_position.y, map_bounds.position.y + 8, map_bounds.end.y - 6)
	z_index = 100 + int(global_position.y)
	_position_report_timer -= delta
	if _position_report_timer <= 0.0:
		_position_report_timer = 0.5
		GameState.player_position = global_position
		position_changed.emit(global_position)

func _unhandled_input(event: InputEvent) -> void:
	if _ui_is_open():
		return
	if event.is_action_pressed("interact"):
		_update_nearest_interactable()
		if is_instance_valid(_current_interactable) and _current_interactable.has_method("interact"):
			_current_interactable.interact(self)
		else:
			GameState.notify("There is nothing nearby to interact with.")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack"):
		_attack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_food"):
		if not GameState.use_food("bread"):
			GameState.use_food("stew")
		get_viewport().set_input_as_handled()

func _attack() -> void:
	if _attack_cooldown > 0.0:
		return
	var weapon := GameState.weapon_definition()
	var power := int(weapon.get("power", 1))
	var attack_damage: int = {1: 4, 2: 10, 3: 24}.get(power, 4)
	var reach := float(weapon.get("reach", 24.0))
	_attack_cooldown = float(weapon.get("cooldown", 0.5))
	if bool(weapon.get("ranged", false)):
		var projectile := Projectile.new()
		get_parent().add_child(projectile)
		projectile.configure(global_position + facing * 10.0 + Vector2(0, -7), facing, attack_damage, 190.0, reach, true)
	else:
		var target := _nearest_damageable(reach)
		if target != null:
			target.take_damage(attack_damage, global_position)
		_show_melee_swing(reach)

func _nearest_damageable(reach: float) -> Node2D:
	var best: Node2D
	var best_distance := reach + 0.01
	for candidate in get_tree().get_nodes_in_group("damageable"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var node := candidate as Node2D
		if not node.is_visible_in_tree():
			continue
		var offset := node.global_position - global_position
		var distance := offset.length()
		if distance <= best_distance and distance > 0.01 and facing.dot(offset.normalized()) >= 0.15:
			best = node
			best_distance = distance
	return best

func _show_melee_swing(reach: float) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 0.80, 0.30, 0.9)
	line.points = PackedVector2Array([facing * 7.0 + Vector2(0, -7), facing * reach + Vector2(0, -7)])
	line.z_index = 950
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)

func take_damage(raw_damage: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if _invulnerability > 0.0 or GameState.health <= 0:
		return
	var applied := GameState.damage_player(raw_damage)
	if applied <= 0:
		return
	_invulnerability = 0.65
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.45, 0.45)
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.30)
	if GameState.health <= 0:
		_respawn()

func _respawn() -> void:
	global_position = RESPAWN_POSITION
	GameState.player_position = global_position
	GameState.restore_health()
	respawned.emit()
	GameState.notify("You were defeated and woke up safely in Paprika village.")

func _update_nearest_interactable() -> void:
	var best: Node2D
	var best_distance := 46.0
	var best_priority := 1
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate is Node2D or candidate == self or not is_instance_valid(candidate):
			continue
		var node := candidate as Node2D
		if not node.is_visible_in_tree():
			continue
		var interaction_position := node.global_position
		if node.has_method("get_interaction_position"):
			interaction_position = node.get_interaction_position()
		var distance := global_position.distance_to(interaction_position)
		var allowed_distance := 45.0 if node is Rabbit else INTERACTION_DISTANCE
		var priority := 0 if node is WorldService else 1
		if distance <= allowed_distance and (priority < best_priority or (priority == best_priority and distance < best_distance)):
			best = node
			best_distance = distance
			best_priority = priority
	_current_interactable = best
	var next_prompt := ""
	if best != null:
		if best.has_method("get_interaction_text"):
			next_prompt = String(best.get_interaction_text())
		else:
			next_prompt = String(best.get("interaction_text"))
	if next_prompt != _last_prompt:
		_last_prompt = next_prompt
		prompt_changed.emit(next_prompt)

func _refresh_appearance() -> void:
	var outfit := String(GameState.equipment.get("clothing", ""))
	var color_name := String(GameData.item(outfit).get("color", ""))
	var texture_path := "res://assets/art/player_%s.png" % color_name
	if not color_name.is_empty() and ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path) as Texture2D
	else:
		_sprite.texture = load("res://art/concepts/source/player.png") as Texture2D
	var armor_id := String(GameState.equipment.get("armor", ""))
	_armor_overlay.visible = not armor_id.is_empty()
	if _armor_overlay.visible:
		_armor_overlay.texture = load("res://assets/art/player_armor_overlay.png") as Texture2D
		match armor_id:
			"wood_armor": _armor_overlay.modulate = Color("ad824f")
			"bronze_armor": _armor_overlay.modulate = Color("e5b578")
			"iron_armor": _armor_overlay.modulate = Color("d7e6ea")
			_: _armor_overlay.modulate = Color.WHITE

func _ui_is_open() -> bool:
	for node in get_tree().get_nodes_in_group("ui_modal"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false

func _cardinal(value: Vector2) -> Vector2:
	if absf(value.x) > absf(value.y):
		return Vector2.RIGHT if value.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if value.y > 0.0 else Vector2.UP
