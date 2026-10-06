class_name RaidSoldier
extends CharacterBody2D

## A Confederation soldier deployed with the player for the trench raid on Artichoke.
## Q (follow) keeps it in formation behind the player, R (hold) keeps it where the
## order was given and T (attack) sends it at the nearest Republic soldier or cannon.
## Typed orders in the counterattack add a hold at a given point, a patrol
## between two points and a hunt: the soldier goes after the nearest attacker
## anywhere on the field, or only those around a given point, and waits there
## when none are left. In every order it attacks enemies already within its
## weapon's reach: archers shoot arrows, spearmen and swordsmen strike up close.

signal downed(soldier_id: String)

const SPEED := 74.0
const MAX_HEALTH := 30
const ATTACK_SIGHT := 210.0
const REPATH_SECONDS := 0.5
## A hunt at a point takes on attackers within this distance of the point.
const HUNT_AREA := 150.0
## Formation places behind the player for follow, one per squad slot.
const FOLLOW_SLOTS := [Vector2(-18, 16), Vector2(18, 16), Vector2(-34, 30), Vector2(34, 30), Vector2(-12, 40), Vector2(12, 40)]

var soldier_id := ""
var soldier_name := "Soldier"
## "bow", "spear" or "sword".
var weapon := "bow"
var health := MAX_HEALTH
## "follow", "hold", "attack", "patrol" or "hunt".
var order := "follow"
var hold_point := Vector2.ZERO
## The two ends of a patrol; hold_point is the end the soldier is walking to.
var patrol_points := PackedVector2Array()
## Where a hunt takes place; Vector2.INF hunts across the whole field.
var hunt_point := Vector2.INF
## What the soldier is doing, in words, for the HUD.
var task_label := "follow"
var facing := Vector2.DOWN
var down := false
var returning := false
var slot := 0
var _cooldown := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _path_goal := Vector2.INF
var _repath := 0.0
var _sprite: Sprite2D
## A health bar instead of a name label: six name labels in formation overlap.
var _health_bar: Line2D
var _world: GameWorld

func configure(id: String, display_name: String, texture_path: String, position: Vector2, weapon_kind: String, formation_slot: int, world: GameWorld) -> void:
	soldier_id = id
	soldier_name = display_name
	weapon = weapon_kind
	slot = formation_slot
	_world = world
	global_position = position
	hold_point = position
	collision_layer = 4 | 64
	collision_mask = 1 | 16
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	var gear := Line2D.new()
	gear.width = 2.0
	gear.z_index = 2
	match weapon:
		"bow":
			gear.points = PackedVector2Array([Vector2(9, -19), Vector2(13, -16), Vector2(15, -12), Vector2(13, -8), Vector2(9, -6), Vector2(9, -19)])
			gear.default_color = Color("ba8953")
		"spear":
			gear.points = PackedVector2Array([Vector2(7, -5), Vector2(10, -23), Vector2(10, -26)])
			gear.default_color = Color("dfd9b8")
		_:
			gear.points = PackedVector2Array([Vector2(7, -5), Vector2(11, -12), Vector2(13, -20)])
			gear.default_color = Color("d7e3e4")
	add_child(gear)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 6)
	collision.shape = box
	collision.position = Vector2(0, -3)
	add_child(collision)
	var bar_back := Line2D.new()
	bar_back.width = 3.0
	bar_back.default_color = Color("1c1730")
	bar_back.points = PackedVector2Array([Vector2(-9, -30), Vector2(9, -30)])
	bar_back.z_index = 3
	add_child(bar_back)
	_health_bar = Line2D.new()
	_health_bar.width = 2.0
	_health_bar.default_color = Color("7fd36b")
	_health_bar.z_index = 4
	add_child(_health_bar)
	_refresh_health_bar()

func _ready() -> void:
	add_to_group("party_target")
	add_to_group("raid_soldier")

func set_order(next_order: String) -> void:
	order = next_order
	hold_point = global_position
	patrol_points = PackedVector2Array()
	hunt_point = Vector2.INF
	task_label = next_order
	_path_goal = Vector2.INF

## Walks to `point` and holds there.
func hold_at(point: Vector2, label: String) -> void:
	set_order("hold")
	hold_point = point
	task_label = label

## Walks to `first`, then back and forth between the two points.
func patrol_between(first: Vector2, second: Vector2, label: String) -> void:
	set_order("patrol")
	patrol_points = PackedVector2Array([first, second])
	hold_point = first
	task_label = label

## Goes after attackers: the nearest anywhere when `area` is Vector2.INF,
## otherwise those around `area`. With nobody to fight it waits at `wait_point`.
func hunt(area: Vector2, wait_point: Vector2, label: String) -> void:
	set_order("hunt")
	hunt_point = area
	hold_point = wait_point
	task_label = label

## Walks back to `point` and leaves the field there; used when the raid ends.
func return_to(point: Vector2) -> void:
	returning = true
	hold_point = point
	_path_goal = Vector2.INF
	remove_from_group("party_target")

func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if down or returning or amount <= 0:
		return
	health = maxi(0, health - amount)
	_refresh_health_bar()
	if health == 0:
		down = true
		velocity = Vector2.ZERO
		collision_layer = 0
		remove_from_group("party_target")
		_sprite.modulate = Color(0.55, 0.55, 0.62)
		_sprite.rotation = -PI * 0.5
		_sprite.position = Vector2(-_sprite.texture.get_height() * 0.5, 2) if _sprite.texture != null else Vector2.ZERO
		downed.emit(soldier_id)
		return
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.3)

func _physics_process(delta: float) -> void:
	z_index = 100 + int(global_position.y)
	if down or _world == null or _world.player == null:
		velocity = Vector2.ZERO
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_repath -= delta
	if returning:
		if global_position.distance_to(hold_point) < 10.0:
			queue_free()
		else:
			_walk_to(hold_point, SPEED)
		return
	var reach := _reach()
	var target := _choose_target(reach)
	if target != null:
		if order == "hunt" and not hunt_point.is_finite():
			hold_point = global_position
		var offset := target.global_position - global_position
		var in_reach := offset.length() <= reach * (0.85 if is_archer() else 1.0)
		if in_reach:
			facing = offset.normalized()
			velocity = Vector2.ZERO
			_strike(target)
			return
		if order in ["attack", "hunt"]:
			_walk_to(target.global_position, SPEED)
			return
	match order:
		"hunt":
			# Wait at the hunt place, or where the last fight ended.
			if global_position.distance_to(hold_point) > 6.0:
				_walk_to(hold_point, SPEED)
			else:
				velocity = Vector2.ZERO
		"patrol":
			if global_position.distance_to(hold_point) <= 6.0:
				hold_point = patrol_points[1] if hold_point == patrol_points[0] else patrol_points[0]
			_walk_to(hold_point, SPEED)
		"hold":
			if global_position.distance_to(hold_point) > 6.0:
				_walk_to(hold_point, SPEED)
			else:
				velocity = Vector2.ZERO
		_:
			var leader := _world.player.global_position
			var goal: Vector2 = leader + FOLLOW_SLOTS[slot % FOLLOW_SLOTS.size()]
			if global_position.distance_to(goal) > 10.0:
				_walk_to(goal, SPEED * (1.25 if global_position.distance_to(leader) > 70.0 else 1.0))
			else:
				velocity = Vector2.ZERO

func _choose_target(reach: float) -> Node2D:
	if order == "hunt":
		var close: Node2D = _world.nearest_hostile(global_position, reach)
		if close != null:
			return close
		if hunt_point.is_finite():
			return _world.nearest_hostile(hunt_point, HUNT_AREA)
		return _world.nearest_hostile(global_position, INF)
	var sight := ATTACK_SIGHT if order == "attack" else reach
	var enemy: Node2D = _world.nearest_hostile(global_position, sight)
	if enemy != null:
		return enemy
	if order == "attack" and _world.has_method("nearest_intact_cannon"):
		return _world.call("nearest_intact_cannon", global_position, ATTACK_SIGHT * 0.6)
	return null

func _strike(target: Node2D) -> void:
	if _cooldown > 0.0:
		return
	if is_archer():
		_cooldown = 1.15
		var projectile := Projectile.new()
		get_parent().add_child(projectile)
		var origin := global_position + Vector2(0, -8)
		projectile.configure(origin, (target.global_position + Vector2(0, -4) - origin).normalized(), 7, 200.0, _reach() + 20.0, true)
	else:
		_cooldown = 1.1 if weapon == "spear" else 0.9
		if target.has_method("take_damage"):
			target.take_damage(9 if weapon == "spear" else 10, global_position)
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.8, 0.96, 0.76, 0.9)
		line.points = PackedVector2Array([facing * 7.0 + Vector2(0, -7), facing * _reach() + Vector2(0, -7)])
		line.z_index = 950
		add_child(line)
		var tween := create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.14)
		tween.tween_callback(line.queue_free)

func is_archer() -> bool:
	return weapon == "bow"

func _reach() -> float:
	match weapon:
		"bow":
			return 150.0
		"spear":
			return 40.0
	return 26.0

func _walk_to(goal: Vector2, speed: float) -> void:
	var navigation := _world.tiled_loader
	if _repath <= 0.0 or _path_goal.distance_to(goal) > 12.0 or _path_index >= _path.size():
		_path = navigation.get_walk_path(global_position, goal)
		# Skip the centre of the current cell so a repath never walks backwards.
		_path_index = 1 if _path.size() > 1 else 0
		_path_goal = goal
		_repath = REPATH_SECONDS
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 4.0:
		_path_index += 1
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return
	var direction := _path[_path_index] - global_position
	facing = direction.normalized()
	velocity = facing * speed * _world.movement_factor(global_position)
	move_and_slide()

func _refresh_health_bar() -> void:
	if _health_bar != null:
		var fraction := float(health) / MAX_HEALTH
		_health_bar.points = PackedVector2Array([Vector2(-8, -30), Vector2(-8 + 16.0 * fraction, -30)])
		_health_bar.default_color = Color("7fd36b") if fraction > 0.5 else Color("e8b04a") if fraction > 0.25 else Color("e0524a")
		_health_bar.get_parent().get_child(_health_bar.get_index() - 1).visible = health > 0
