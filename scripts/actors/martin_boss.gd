class_name MartinBoss
extends Enemy

## Martin, the Republic Admin, in the fight in front of the prison block on
## Bavarin (scripts/world/bavarin_world.gd). He fights with a Banishing Sword and
## Banishing Arrows, and he jumps. Each attack shows on the ground before it lands:
##
## - the Banishing Sword: a purple half circle in front of him, towards his target,
##   when the target is close. SWORD_WARN seconds later he swings; everyone in the
##   half circle is hit. Get behind him or out of reach.
## - the Banishing Arrow: a thin purple line towards a target that is further off.
##   ARROW_WARN seconds later the arrow flies along it, and walls stop it. Below
##   ANGRY_SHARE of his health he looses three in a fan.
## - the jump: he crouches and a red circle marks where his target stands. He lands
##   there JUMP_CROUCH + JUMP_AIR seconds later and everyone inside the circle is
##   hit. He cannot be hit in the air. Below ANGRY_SHARE he jumps more often.
##
## Sword and arrow hits are Banishing hits: `banishing_hit` tells the world, which
## decides what they do (the MC is a Brine and only takes the damage; Donat is
## knocked out). Without a listener they are ordinary hits.
##
## Martin is not killed here. His health never drops below 1, and the world ends
## the fight once it falls to a quarter (BavarinWorld.MARTIN_BEATEN_SHARE).

signal banishing_hit(target: Node2D, damage: int)

const SWORD_REACH := 42.0
const SWORD_WARN := 0.55
const SWORD_EVERY := 2.8
const ARROW_WARN := 0.8
const ARROW_EVERY := 4.5
const ARROW_LENGTH := 300.0
const ARROW_SPEED := 240.0
const ARROW_FAN := 0.24
const ARROW_MIN_DISTANCE := 70.0
const JUMP_CROUCH := 0.45
const JUMP_AIR := 0.6
const JUMP_HEIGHT := 30.0
const JUMP_RADIUS := 44.0
const JUMP_EVERY := 7.0
const JUMP_EVERY_ANGRY := 4.2
const JUMP_FROM := 110.0
const ANGRY_SHARE := 0.6
const BLADE_COLOR := Color("c58aff")
const WARN_COLOR := Color(1.0, 0.22, 0.18, 0.42)
const BANISH_WARN_COLOR := Color(0.72, 0.3, 1.0, 0.42)

## "sword", "arrow", "crouch" or "air" while one is under way, "" otherwise.
var special := ""
var special_left := 0.0
var aim := Vector2.RIGHT
var jump_from := Vector2.ZERO
var jump_to := Vector2.ZERO
var _sword_wait := 1.5
var _arrow_wait := 3.0
var _jump_wait := 5.0
var _warning: Node2D
var _layer_before_jump := 0

func _build_gear() -> void:
	_weapon_visual = Line2D.new()
	_weapon_visual.width = 2.0
	_weapon_visual.z_index = 2
	_weapon_visual.points = PackedVector2Array([Vector2(7, -4), Vector2(9, -14), Vector2(11, -26)])
	_weapon_visual.default_color = BLADE_COLOR
	add_child(_weapon_visual)

## Below ANGRY_SHARE of his health he jumps more often and looses three arrows at once.
func angry() -> bool:
	return health <= int(max_health * ANGRY_SHARE)

func _physics_process(delta: float) -> void:
	if _defeated:
		super._physics_process(delta)
		return
	if special != "":
		velocity = Vector2.ZERO
		special_left -= delta
		if special == "air":
			_step_air()
		if special_left <= 0.0:
			_release_special()
		z_index = 100 + int(global_position.y)
		return
	_sword_wait = maxf(0.0, _sword_wait - delta)
	_arrow_wait = maxf(0.0, _arrow_wait - delta)
	_jump_wait = maxf(0.0, _jump_wait - delta)
	var target := _nearest_target()
	if target != null and state not in [State.TELEGRAPH, State.RECOVER]:
		var offset := target.global_position - global_position
		var distance := offset.length()
		if distance <= SWORD_REACH and _sword_wait <= 0.0:
			start_sword(offset)
			return
		if _jump_wait <= 0.0 and (distance >= JUMP_FROM or (angry() and distance > SWORD_REACH)):
			start_jump(target.global_position)
			return
		if _arrow_wait <= 0.0 and distance >= ARROW_MIN_DISTANCE and distance <= ARROW_LENGTH:
			start_arrow(offset)
			return
	super._physics_process(delta)

## Shows the half circle of the Banishing Sword towards `direction`.
func start_sword(direction: Vector2) -> void:
	_begin("sword", SWORD_WARN, direction)
	_sword_wait = SWORD_EVERY
	var arc := Polygon2D.new()
	var points := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		points.append(aim.rotated(lerpf(-PI * 0.5, PI * 0.5, i / 16.0)) * SWORD_REACH)
	arc.polygon = points
	arc.color = BANISH_WARN_COLOR
	_show_warning(arc, global_position)
	_weapon_visual.points = PackedVector2Array([Vector2(-6, -10), Vector2(-10, -20), Vector2(-12, -30)])
	_sprite.modulate = Color(0.85, 0.65, 1.0)

## Shows the line of the Banishing Arrow towards `direction`.
func start_arrow(direction: Vector2) -> void:
	_begin("arrow", ARROW_WARN, direction)
	_arrow_wait = ARROW_EVERY
	var lines := Node2D.new()
	for heading in arrow_headings():
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = BANISH_WARN_COLOR
		line.points = PackedVector2Array([Vector2.ZERO, heading * ARROW_LENGTH])
		lines.add_child(line)
	_show_warning(lines, global_position + Vector2(0, -8))
	_weapon_visual.points = PackedVector2Array([Vector2(8, -22), Vector2(12, -14), Vector2(8, -6)])
	_weapon_visual.default_color = Color("8a5a32")
	_sprite.modulate = Color(0.85, 0.65, 1.0)

## The way each arrow flies: one, or a fan of three when Martin is angry.
func arrow_headings() -> Array:
	if angry():
		return [aim.rotated(-ARROW_FAN), aim, aim.rotated(ARROW_FAN)]
	return [aim]

## Crouches and marks where he will land.
func start_jump(at: Vector2) -> void:
	_begin("crouch", JUMP_CROUCH, at - global_position)
	_jump_wait = JUMP_EVERY_ANGRY if angry() else JUMP_EVERY
	_sword_wait = maxf(_sword_wait, 0.6)
	jump_from = global_position
	jump_to = at
	var world := get_parent().get_parent()
	if world != null and world.has_method("_walkable"):
		jump_to = world._walkable(at)
	var ring := Polygon2D.new()
	ring.polygon = _ellipse(JUMP_RADIUS)
	ring.color = WARN_COLOR
	_show_warning(ring, jump_to)
	_sprite.scale = Vector2(1.15, 0.8)

func _begin(kind: String, seconds: float, direction: Vector2) -> void:
	_clear_warning()
	special = kind
	special_left = seconds
	aim = direction.normalized() if direction.length() > 0.1 else Vector2.RIGHT
	velocity = Vector2.ZERO

func _ellipse(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		points.append(Vector2.from_angle(TAU * i / 32.0) * Vector2(radius, radius * 0.7))
	return points

func _show_warning(shape: Node2D, at: Vector2) -> void:
	_warning = shape
	shape.name = "MartinWarning"
	shape.global_position = at
	shape.z_index = 60
	get_parent().add_child(shape)
	var tween := shape.create_tween().set_loops()
	tween.tween_property(shape, "modulate:a", 0.45, 0.12)
	tween.tween_property(shape, "modulate:a", 1.0, 0.12)

## True when `point` is in the sword's half circle or the landing circle now shown.
func special_hits(point: Vector2) -> bool:
	match special:
		"sword":
			var offset := point - global_position
			return offset.length() <= SWORD_REACH + 4.0 and offset.dot(aim) >= -2.0
		"crouch", "air":
			var offset := point - jump_to
			return Vector2(offset.x / JUMP_RADIUS, offset.y / (JUMP_RADIUS * 0.7)).length() <= 1.0
	return false

func _targets() -> Array:
	return get_tree().get_nodes_in_group("party_target").filter(func(node) -> bool:
		return node is Node2D and node.visible and node.has_method("take_damage"))

func _release_special() -> void:
	match special:
		"sword":
			for node in _targets():
				if special_hits((node as Node2D).global_position):
					hit_with_banishing(node, int(definition.get("sword_damage", 22)))
			_flash_arc()
		"arrow":
			for heading in arrow_headings():
				var arrow := MartinArrow.new()
				arrow.name = "MartinArrow"
				get_parent().add_child(arrow)
				arrow.launch(self, global_position + Vector2(0, -8), heading, int(definition.get("arrow_damage", 18)))
			_weapon_visual.default_color = BLADE_COLOR
		"crouch":
			# Into the air: he cannot be hit until he lands.
			special = "air"
			special_left = JUMP_AIR
			_layer_before_jump = collision_layer
			collision_layer = 0
			_sprite.scale = Vector2.ONE
			return
		"air":
			global_position = jump_to
			_sprite.position.y = _rest_sprite_y()
			collision_layer = _layer_before_jump
			for node in _targets():
				if special_hits((node as Node2D).global_position):
					node.take_damage(int(definition.get("jump_damage", 24)), global_position)
			_flash_ring()
			var world := get_parent().get_parent()
			if world != null and world.has_method("shake_camera"):
				world.shake_camera(0.25, 3.0)
	special = ""
	_clear_warning()
	_sprite.scale = Vector2.ONE
	_sprite.modulate = _base_modulate()
	_weapon_visual.points = PackedVector2Array([Vector2(7, -4), Vector2(9, -14), Vector2(11, -26)])
	state = State.RECOVER
	_state_time = 0.5

func _rest_sprite_y() -> float:
	return -_sprite.texture.get_height() + 2.0 if _sprite.texture != null else 0.0

func _step_air() -> void:
	var t := clampf(1.0 - special_left / JUMP_AIR, 0.0, 1.0)
	global_position = jump_from.lerp(jump_to, t)
	_sprite.position.y = _rest_sprite_y() - sin(t * PI) * JUMP_HEIGHT

## A Banishing hit from the sword or an arrow. The world decides what it does.
func hit_with_banishing(node: Node2D, damage: int) -> void:
	if banishing_hit.get_connections().is_empty():
		node.take_damage(damage, global_position)
	else:
		banishing_hit.emit(node, damage)

func in_air() -> bool:
	return special == "air"

## A purple sweep where the sword went, fading at once.
func _flash_arc() -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.9, 0.75, 1.0)
	for i in 13:
		line.add_point(aim.rotated(lerpf(-PI * 0.5, PI * 0.5, i / 12.0)) * SWORD_REACH * 0.85)
	_fade(line, global_position + Vector2(0, -4))

func _flash_ring() -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.95, 0.75)
	for point in _ellipse(JUMP_RADIUS):
		line.add_point(point)
	line.add_point(line.points[0])
	_fade(line, global_position)

func _fade(line: Line2D, at: Vector2) -> void:
	line.global_position = at
	line.z_index = 950
	get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)

func _clear_warning() -> void:
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null

## Lands at once and drops whatever he was about to do; used when the fight stops.
func cancel_special() -> void:
	if special == "air" or special == "crouch":
		global_position = jump_to if special == "air" else global_position
		if special == "air":
			collision_layer = _layer_before_jump
	special = ""
	_clear_warning()
	if _sprite != null:
		_sprite.scale = Vector2.ONE
		_sprite.position.y = _rest_sprite_y()
		_sprite.modulate = _base_modulate()

func _exit_tree() -> void:
	_clear_warning()

## Like Enemy.take_damage, but Martin's health stops at 1 and he cannot be hit in
## the air: the world ends the fight before then, and he is dragged away alive.
func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if health <= 1 or special == "air":
		return
	var applied := GameData.armored_damage(amount, int(definition.get("armor", 0)))
	health = maxi(1, health - applied)
	_label.visible = true
	_label.text = "%s  Lv.%d  %d/%d" % [_display_name(), int(definition.get("level", 1)), health, max_health]
	if special == "":
		_sprite.modulate = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", _base_modulate(), 0.22)


## A Banishing Arrow from Martin: flies straight, stops at walls, and hits the
## first of the party it reaches.
class MartinArrow extends Node2D:
	const HIT_RADIUS := 9.0
	var shooter: MartinBoss
	var direction := Vector2.RIGHT
	var damage := 18
	var remaining := MartinBoss.ARROW_LENGTH

	func launch(from_martin: MartinBoss, at: Vector2, heading: Vector2, amount: int) -> void:
		shooter = from_martin
		global_position = at
		direction = heading.normalized()
		damage = amount
		rotation = direction.angle()
		z_index = 900

	func _draw() -> void:
		draw_line(Vector2(-16, 0), Vector2(5, 0), Color("642584"), 5.0)
		draw_line(Vector2(-14, 0), Vector2(5, 0), Color("f5eaff"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(1, -4), Vector2(1, 4)]), Color("e08aff"))

	func _physics_process(delta: float) -> void:
		var step := minf(MartinBoss.ARROW_SPEED * delta, remaining)
		var next := global_position + direction * step
		var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, next, 1))
		for node in get_tree().get_nodes_in_group("party_target"):
			if not node is Node2D or not node.visible or not node.has_method("take_damage"):
				continue
			var body := (node as Node2D).global_position + Vector2(0, -8)
			var closest := Geometry2D.get_closest_point_to_segment(body, global_position, next)
			if closest.distance_to(body) <= HIT_RADIUS:
				if is_instance_valid(shooter):
					shooter.hit_with_banishing(node, damage)
				else:
					node.take_damage(damage, global_position)
				queue_free()
				return
		if not wall.is_empty():
			queue_free()
			return
		global_position = next
		remaining -= step
		if remaining <= 0.0:
			queue_free()
