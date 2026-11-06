class_name SmokvaBrawler
extends Enemy

## The hackers who fight at Smokva: the three Purple Parrots and Donat in his
## duel with the player. Each has a power, and every power is shown before it
## hits and can be avoided:
##
## - Puffa (parrot_puffa) puffs up and a line shows where he will dash. He
##   charges straight along it; stepping off the line dodges him, and if he
##   runs into a wall or the yard's furniture he is dazed for DAZE_SECONDS.
## - Ruff (parrot_ruff), once he is down to half health, vanishes in a puff of
##   smoke and comes back as two: himself and a decoy without the purple
##   feather. The decoy fights too but pops after one hit.
## - Luster (parrot_luster), the leader, makes the candles on his chandelier
##   glow, then lets out a ring of eight light bolts that spirals outward
##   (scripts/actors/spiral_bolt.gd). Walls and furniture stop the bolts.
## - Donat (donat_duel) has no other attack than his slash: a red half circle
##   in front of him warns of it, then the blade sweeps across it and hits
##   whoever is still inside (scripts/actors/slash_arc.gd). Getting behind him
##   or out of reach dodges it. He does not go down in the duel; the world ends
##   the duel before that.
##
## They do not simply walk at the player. Between attacks each keeps to the
## distance that suits him:
##
## - Luster backs away and circles at LUSTER_DISTANCE, throwing single aimed
##   bolts.
## - Puffa backs off and sidesteps at PUFFA_DISTANCE until his dash is ready,
##   and backs straight off after each close attack to line it up.
## - When furniture stands between either of them and the target, he walks
##   round it towards the target instead. Anyone who comes within reach of
##   them is hit back up close.
## - Ruff works round to the side or back of whoever he fights before he
##   strikes. After the split he and the decoy come from opposite sides.
## - Donat circles just outside his reach, steps in to slash and steps out
##   again. Sometimes the slash is a feint: the half circle flickers out and
##   no blade comes.
##
## The Parrots' close attacks are a quick jab or, now and then, a slow heavy
## blow (HEAVY_WARN_SECONDS of red wind-up) that leaves them open afterwards.
## In the fight with the Parrots, smokva_world.gd sends one Parrot at a time
## at the player and the other two at Donat. A Parrot with no one to attack
## (`pressing` false, while Donat is down) circles the player at
## WAIT_DISTANCE. When hurt, each fights harder: Puffa below half health dashes twice
## in a row, Luster's spiral turns both ways at once, and Donat below
## DONAT_FURY_SHARE of his health stops feinting and slashes twice.

signal decoy_made(decoy: SmokvaBrawler)

enum Power { NONE, WARN, ACTIVE, DAZED, OPEN }

const DASH_WARN_SECONDS := 0.6
## The warning before Puffa's second dash, when he dashes twice.
const SECOND_DASH_WARN_SECONDS := 0.4
const DASH_SPEED := 280.0
const DASH_LENGTH := 170.0
const DASH_COOLDOWN := 4.5
const DAZE_SECONDS := 1.5
const BOLT_WARN_SECONDS := 0.7
const BOLT_COUNT := 8
const BOLT_RANGE := 170.0
const BOLT_COOLDOWN := 6.0
const SLASH_WARN_SECONDS := 0.4
## The warning before Donat's second slash, when he slashes twice.
const SECOND_SLASH_WARN_SECONDS := 0.25
## After a slash Donat stays open this long: the moment to hit him.
const SLASH_OPEN_SECONDS := 0.6
const DECOY_SPREAD := 28.0
const LABEL_HEIGHT := -46.0
## What stops Puffa's dash and Luster's bolts: walls and the yard's furniture.
const DASH_BLOCKERS := 1 | 16

## Distances each fighter keeps between attacks.
const LUSTER_DISTANCE := 100.0
const PUFFA_DISTANCE := 95.0
## How long Puffa backs off after a close attack, to line up his dash.
const PUFFA_BACK_OFF_SECONDS := 0.9
## Within its reach plus this, a fighter that keeps its distance fights back
## up close instead.
const CAUGHT_MARGIN := 10.0
## How far to the side of his target Ruff gets before he strikes.
const RUFF_FLANK := 30.0
## After this long trying to get round, Ruff comes straight in.
const RUFF_FLANK_SECONDS := 3.0
## How far outside his reach Donat circles.
const DONAT_CIRCLE := 14.0
## How long Donat backs off after a slash or a feint.
const STEP_OUT_SECONDS := 0.45
const FEINT_CHANCE := 0.3
## How long a feint shows before it flickers out.
const FEINT_SECONDS := 0.3
## Below this share of his health Donat stops feinting and slashes twice.
const DONAT_FURY_SHARE := 0.8
## Where a Parrot whose turn it is not circles.
const WAIT_DISTANCE := 90.0

const HEAVY_CHANCE := 0.35
const HEAVY_WARN_SECONDS := 0.6
const HEAVY_DAMAGE_SHARE := 1.5
## How long a Parrot stays open after a heavy blow.
const HEAVY_OPEN_SECONDS := 0.9
const AIMED_BOLT_COOLDOWN := 1.8
const AIMED_BOLT_SPEED := 150.0
const AIMED_BOLT_RANGE := 180.0

var power_state := Power.NONE
var _power_time := 0.0
var _power_cooldown := 2.5
var _dash_direction := Vector2.ZERO
var _dash_left := 0.0
var _dash_hit := false
var _warning: Node2D
var _stars: Node2D
var _bolt_turn := 1.0
var _slash_left_first := true
## Ruff splits only once.
var split_done := false
var is_decoy := false
var decoy: SmokvaBrawler
## For a decoy: the real Ruff, whose other side it takes.
var original: SmokvaBrawler
## False while another Parrot has the turn: this one circles and waits.
var pressing := true
## 1 or -1: which way round the target this fighter circles.
var _orbit := 1.0
var _orbit_flip := 2.0
## 1 or -1: which side of the target Ruff goes for.
var flank_side := 1.0
var _flank_time := 0.0
var _heavy := false
var _base_damage := 0
var _aimed_cooldown := 1.0
var _step_in_wait := 1.0
var _stepping_in := false
var _step_out := 0.0
var _feint := false
var _second_slash := false
var _second_dash := false
var _shout: Label

func configure(kind: String, texture_path: String, position_in_world: Vector2, stable_id: String) -> void:
	super.configure(kind, texture_path, position_in_world, stable_id)
	is_decoy = kind == "parrot_ruff_decoy"
	_base_damage = int(definition.get("damage", 20))
	_orbit = 1.0 if _rng.randf() < 0.5 else -1.0
	flank_side = 1.0 if _rng.randf() < 0.5 else -1.0
	if kind == "parrot_puffa":
		# His dash is what he is for; it is ready soon after the fight starts.
		_power_cooldown = 1.2
	# The hacker sprites are 36 pixels tall; the name goes above the hat.
	_label.position.y = LABEL_HEIGHT

func _physics_process(delta: float) -> void:
	if health <= 0 or _defeated:
		return
	_power_cooldown = maxf(0.0, _power_cooldown - delta)
	_aimed_cooldown = maxf(0.0, _aimed_cooldown - delta)
	if enemy_id == "donat_duel":
		# The slash is Donat's only attack; the ordinary strike never comes round.
		_attack_cooldown = 1.0
	if power_state != Power.NONE:
		_power_time -= delta
		_step_power(delta)
		z_index = 100 + int(global_position.y)
		return
	var before := state
	if state not in [State.TELEGRAPH, State.RECOVER, State.PHASE_WARNING]:
		var target := _nearest_target()
		if target != null and pressing and enemy_id != "donat_duel" and _try_power(target):
			z_index = 100 + int(global_position.y)
			return
		if target != null and _move_between_attacks(target, delta):
			z_index = 100 + int(global_position.y)
			return
	super._physics_process(delta)
	_after_base_step(before)

## Starts this fighter's power at `target` when it is ready and in range.
func _try_power(target: Node2D) -> bool:
	var distance := global_position.distance_to(target.global_position)
	match enemy_id:
		"parrot_puffa":
			if _power_cooldown <= 0.0 and distance > 44.0 and distance < 150.0 and _clear_line(target.global_position):
				_second_dash = false
				_start_dash_warning(target, DASH_WARN_SECONDS)
				return true
		"parrot_luster":
			if _power_cooldown <= 0.0 and distance < 140.0:
				_start_bolt_warning()
				return true
		"donat_duel":
			if distance <= _attack_reach():
				if _power_cooldown <= 0.0:
					_start_slash_warning(target)
				else:
					velocity = Vector2.ZERO
				return true
	return false

# ---------- Moving between attacks ----------

## Moves this fighter the way that suits it while it is not attacking. False
## means it wants to close in and strike, which the ordinary chase does.
func _move_between_attacks(target: Node2D, delta: float) -> bool:
	var distance := global_position.distance_to(target.global_position)
	_orbit_flip -= delta
	if _orbit_flip <= 0.0:
		_orbit = -_orbit
		_orbit_flip = _rng.randf_range(1.5, 3.5)
	var handled := false
	# Whoever comes within reach gets hit back, whatever the plan was.
	var caught := distance <= _attack_reach() + CAUGHT_MARGIN
	if not pressing:
		handled = not caught
		if handled:
			_circle(target, WAIT_DISTANCE, 0.7, delta)
	else:
		match enemy_id:
			"parrot_luster", "parrot_puffa":
				handled = not caught
				if enemy_id == "parrot_puffa" and _step_out > 0.0:
					# After a jab he backs straight off to line up his dash.
					_step_out -= delta
					_circle(target, PUFFA_DISTANCE, 1.0, delta)
					_tick(delta, distance)
					return true
				if handled:
					var clear := _clear_line(target.global_position)
					if not clear:
						# Furniture in the way: round it, towards the target.
						_move_toward(target.global_position, float(definition.get("speed", 50.0)))
					elif enemy_id == "parrot_luster":
						_fire_aimed_bolt(target, distance)
						_circle(target, LUSTER_DISTANCE, 0.85, delta)
					else:
						# He backs off and sidesteps until his dash is ready.
						_circle(target, PUFFA_DISTANCE, 0.8, delta)
			"parrot_ruff", "parrot_ruff_decoy":
				handled = _flank(target, distance, delta)
			"donat_duel":
				handled = _duel_footwork(target, distance, delta)
	if handled:
		_tick(delta, distance)
	return handled

## What the ordinary enemy step counts down and shows, for steps this fighter
## takes on its own.
func _tick(delta: float, distance: float) -> void:
	_state_time = maxf(0.0, _state_time - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_ground_repath_timer = maxf(0.0, _ground_repath_timer - delta)
	_label.visible = distance < 92.0 or health < max_health
	spawn_position = global_position
	state = State.CHASE

## Moves round `target`, closing in or backing off towards `want` from it.
## Goes the other way round when a wall, furniture or the edge of the
## walkable ground is in the way, and walks at the target when both ways are
## blocked: cornered, it comes out fighting.
func _circle(target: Node2D, want: float, speed_share: float, delta: float) -> void:
	var away := global_position - target.global_position
	var distance := away.length()
	var outward := away / distance if distance > 0.01 else Vector2.RIGHT
	var radial := clampf((want - distance) / 24.0, -1.0, 1.0)
	var round_share := 1.0 - absf(radial) * 0.6
	var direction := (outward * radial + outward.orthogonal() * _orbit * round_share).normalized()
	var speed := float(definition.get("speed", 50.0)) * speed_share
	var world := get_parent().get_parent() as GameWorld
	if world != null:
		speed *= world.movement_factor(global_position, self)
		var ground := world.tiled_loader
		# Off the walk grid already (at its edge), any step is allowed.
		if ground != null and ground.is_walkable_position(global_position) and not ground.is_walkable_position(global_position + direction * 8.0):
			var other := (outward * radial - outward.orthogonal() * _orbit * round_share).normalized()
			if ground.is_walkable_position(global_position + other * 8.0):
				_turn_round()
				direction = other
			else:
				_move_toward(target.global_position, speed)
				return
	velocity = direction * speed
	var start := global_position
	move_and_slide()
	if get_slide_collision_count() > 0 and global_position.distance_to(start) < speed * delta * 0.5:
		_turn_round()

func _turn_round() -> void:
	_orbit = -_orbit
	_orbit_flip = _rng.randf_range(1.5, 3.5)

## Which way `target` looks; a target that does not say is taken to face this fighter.
func _target_facing(target: Node2D) -> Vector2:
	var looking = target.get("facing")
	if looking is Vector2 and looking != Vector2.ZERO:
		return (looking as Vector2).normalized()
	return (global_position - target.global_position).normalized()

## Ruff gets to the side or back of his target before he strikes. False once
## he is there, or once he has tried for RUFF_FLANK_SECONDS.
func _flank(target: Node2D, distance: float, delta: float) -> bool:
	_flank_time += delta
	if _flank_time >= RUFF_FLANK_SECONDS:
		return false
	var looking := _target_facing(target)
	var side := flank_side
	if is_decoy and is_instance_valid(original):
		side = -original.flank_side
	var spot := target.global_position + looking.orthogonal() * side * RUFF_FLANK - looking * 6.0
	var from_side := (global_position - target.global_position).normalized().dot(looking) < 0.35
	if (distance <= _attack_reach() + 6.0 and from_side) or global_position.distance_to(spot) < 8.0:
		return false
	_move_toward(spot, float(definition.get("speed", 50.0)))
	return true

## Donat circles just outside his reach, then steps in and slashes, then backs
## off. Someone who walks into his reach gets slashed straight away.
func _duel_footwork(target: Node2D, distance: float, delta: float) -> bool:
	var reach := _attack_reach()
	if _step_out > 0.0:
		_step_out -= delta
		_circle(target, reach + DONAT_CIRCLE + 20.0, 1.0, delta)
		return true
	if distance <= reach and (_stepping_in or distance <= reach - 4.0) and _power_cooldown <= 0.0:
		_stepping_in = false
		_step_in_wait = _rng.randf_range(0.6, 1.4)
		_start_slash_warning(target, not _furious() and _rng.randf() < FEINT_CHANCE)
		return true
	if _stepping_in:
		_move_toward(target.global_position, float(definition.get("speed", 62.0)) * 1.6)
		return true
	_step_in_wait -= delta
	if _step_in_wait <= 0.0 and _power_cooldown <= 0.0:
		_stepping_in = true
	_circle(target, reach + DONAT_CIRCLE, 0.9, delta)
	return true

func _furious() -> bool:
	return health <= int(max_health * DONAT_FURY_SHARE)

## Luster's single aimed bolt, thrown while he keeps his distance.
func _fire_aimed_bolt(target: Node2D, distance: float) -> void:
	if _aimed_cooldown > 0.0 or distance < 50.0 or distance > AIMED_BOLT_RANGE - 10.0:
		return
	_aimed_cooldown = AIMED_BOLT_COOLDOWN
	var bolt := Projectile.new()
	get_parent().add_child(bolt)
	var origin := global_position + Vector2(0, -12)
	bolt.configure(origin, (target.global_position + Vector2(0, -3) - origin).normalized(), int(definition.get("bolt_damage", 14)), AIMED_BOLT_SPEED, AIMED_BOLT_RANGE, false)
	bolt.collision_mask |= DASH_BLOCKERS
	for child in bolt.get_children():
		if child is Polygon2D:
			child.color = Color(1.0, 0.92, 0.55)

## Picks a jab or a heavy blow when the ordinary step starts a close attack,
## and leaves a heavy blow's opening after it lands.
func _after_base_step(before: State) -> void:
	if before != State.TELEGRAPH and state == State.TELEGRAPH:
		_heavy = _rng.randf() < HEAVY_CHANCE
		definition["damage"] = int(round(_base_damage * HEAVY_DAMAGE_SHARE)) if _heavy else _base_damage
		if _heavy:
			_state_time = HEAVY_WARN_SECONDS
			_sprite.modulate = Color(1.0, 0.12, 0.12)
			create_tween().tween_property(_sprite, "scale", Vector2(1.12, 1.06), HEAVY_WARN_SECONDS * 0.9)
	elif before == State.TELEGRAPH and state == State.RECOVER:
		if _heavy:
			_state_time = HEAVY_OPEN_SECONDS
			_sprite.scale = Vector2.ONE
		_heavy = false
		definition["damage"] = _base_damage
		_flank_time = 0.0
		if enemy_id == "parrot_ruff":
			flank_side = -flank_side
		elif enemy_id == "parrot_puffa":
			_step_out = PUFFA_BACK_OFF_SECONDS

## A few words over this fighter's head that float up and fade.
func shout(text: String) -> void:
	if is_instance_valid(_shout):
		_shout.queue_free()
	_shout = Label.new()
	_shout.text = text
	_shout.position = Vector2(-50, LABEL_HEIGHT - 12)
	_shout.size = Vector2(100, 14)
	_shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout.add_theme_font_size_override("font_size", 8)
	_shout.add_theme_color_override("font_color", Color("ffe680"))
	_shout.add_theme_color_override("font_shadow_color", Color("1c1730"))
	_shout.add_theme_constant_override("shadow_offset_x", 1)
	_shout.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_shout)
	var tween := _shout.create_tween()
	tween.tween_property(_shout, "position:y", LABEL_HEIGHT - 22, 1.4)
	tween.parallel().tween_property(_shout, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tween.tween_callback(_shout.queue_free)

# ---------- Powers ----------

func _step_power(delta: float) -> void:
	match power_state:
		Power.WARN:
			velocity = Vector2.ZERO
			if _power_time <= 0.0:
				_release_power()
		Power.ACTIVE:
			_step_dash(delta)
		Power.DAZED, Power.OPEN:
			velocity = Vector2.ZERO
			if _power_time <= 0.0:
				_end_power()

func _release_power() -> void:
	match enemy_id:
		"parrot_puffa":
			_clear_warning()
			power_state = Power.ACTIVE
			_dash_left = DASH_LENGTH
			_dash_hit = false
		"parrot_luster":
			_clear_warning()
			_fire_bolts()
			power_state = Power.OPEN
			_power_time = 0.45
		"donat_duel":
			if _feint:
				_end_feint()
				return
			_clear_warning()
			_slash()
			var target := _nearest_target()
			if _furious() and not _second_slash and target != null:
				# The second slash comes from the other side, with a shorter warning.
				_second_slash = true
				_start_slash_warning(target, false, SECOND_SLASH_WARN_SECONDS)
				return
			_second_slash = false
			power_state = Power.OPEN
			_power_time = SLASH_OPEN_SECONDS

func _end_power() -> void:
	power_state = Power.NONE
	state = State.CHASE
	_sprite.scale = Vector2.ONE
	_sprite.modulate = _base_modulate()
	if is_instance_valid(_stars):
		_stars.queue_free()
	_stars = null
	if enemy_id == "donat_duel":
		_step_out = STEP_OUT_SECONDS

func _clear_warning() -> void:
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null

## True when no wall or furniture stands between this fighter and `point`.
func _clear_line(point: Vector2) -> bool:
	return _blocked_at(point).is_empty()

## Where the first wall or piece of furniture on the way to `point` is, as
## seen by Puffa's body, which is wider than a ray: three rays, at his middle
## and at both sides.
func _blocked_at(point: Vector2) -> Dictionary:
	var side := (point - global_position).normalized().orthogonal() * 5.0
	var nearest := {}
	for offset in [Vector2.ZERO, side, -side]:
		var ray := PhysicsRayQueryParameters2D.create(global_position + offset + Vector2(0, -3), point + offset + Vector2(0, -3), DASH_BLOCKERS, [get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and (nearest.is_empty() or global_position.distance_to(hit["position"]) < global_position.distance_to(nearest["position"])):
			nearest = hit
	return nearest

# ---------- Puffa's dash ----------

func _start_dash_warning(target: Node2D, warn_seconds: float) -> void:
	power_state = Power.WARN
	_power_time = warn_seconds
	_power_cooldown = DASH_COOLDOWN
	_dash_direction = (target.global_position - global_position).normalized()
	var end := global_position + _dash_direction * DASH_LENGTH
	var wall := _blocked_at(end)
	if not wall.is_empty():
		end = global_position + _dash_direction * global_position.distance_to(Vector2(wall["position"]) + Vector2(0, 3))
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = Color(1.0, 0.25, 0.25, 0.35)
	line.points = PackedVector2Array([global_position + Vector2(0, -3), end + Vector2(0, -3)])
	line.z_index = 899
	get_parent().add_child(line)
	_warning = line
	# He puffs up before he goes.
	create_tween().tween_property(_sprite, "scale", Vector2(1.15, 1.08), warn_seconds * 0.8)

func _step_dash(delta: float) -> void:
	var step := minf(DASH_SPEED * delta, _dash_left)
	_dash_left -= step
	var collision := move_and_collide(_dash_direction * step)
	if collision != null:
		var body := collision.get_collider()
		if body is Node and (body as Node).is_in_group("party_target") and body.has_method("take_damage"):
			if not _dash_hit:
				_dash_hit = true
				body.take_damage(int(definition.get("dash_damage", definition.get("damage", 24))), global_position)
			_finish_dash(0.4)
		else:
			_daze()
		return
	if _dash_left <= 0.0:
		_finish_dash(0.4)

func _finish_dash(rest: float) -> void:
	_sprite.scale = Vector2.ONE
	# Below half health he turns and goes again at once.
	if health <= max_health / 2 and not _second_dash:
		var target := _nearest_target()
		if target != null and global_position.distance_to(target.global_position) > 30.0 and _clear_line(target.global_position):
			_second_dash = true
			_start_dash_warning(target, SECOND_DASH_WARN_SECONDS)
			return
	power_state = Power.OPEN
	_power_time = rest

func _daze() -> void:
	power_state = Power.DAZED
	_power_time = DAZE_SECONDS
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color(0.7, 0.72, 0.9)
	# Three little stars circle over his head.
	_stars = Node2D.new()
	# Round his head, below the name.
	_stars.position = Vector2(0, -27)
	_stars.scale = Vector2(1.0, 0.4)
	var spin := Node2D.new()
	_stars.add_child(spin)
	for i in 3:
		var star := Polygon2D.new()
		star.polygon = PackedVector2Array([Vector2(0, -3), Vector2(1, -1), Vector2(3, 0), Vector2(1, 1), Vector2(0, 3), Vector2(-1, 1), Vector2(-3, 0), Vector2(-1, -1)])
		star.color = Color("ffe680")
		star.position = Vector2.from_angle(TAU * i / 3.0) * 10.0
		spin.add_child(star)
	add_child(_stars)
	spin.create_tween().set_loops().tween_property(spin, "rotation", TAU, 0.6).from(0.0)
	shake_hit()

func shake_hit() -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world != null and world.has_method("shake_camera"):
		world.shake_camera(0.2, 2.0)

func dazed() -> bool:
	return power_state == Power.DAZED

# ---------- Ruff's decoy ----------

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_decoy:
		if health > 0 and amount > 0:
			health = 0
			_pop()
		return
	super.take_damage(amount, source_position)
	if enemy_id == "parrot_ruff" and not split_done and health > 0 and health <= max_health / 2:
		_split()

func _split() -> void:
	split_done = true
	var world := get_parent().get_parent() as GameWorld
	var spots := [global_position + Vector2(-DECOY_SPREAD, 0), global_position + Vector2(DECOY_SPREAD, 0)]
	if world != null and world.tiled_loader != null:
		for i in spots.size():
			var spot: Vector2 = world.tiled_loader.nearest_walkable_position(spots[i])
			if spot.is_finite():
				spots[i] = spot
	if randf() < 0.5:
		spots.reverse()
	_smoke(global_position)
	decoy = SmokvaBrawler.new()
	decoy.name = persistent_id + "_decoy"
	decoy.configure("parrot_ruff_decoy", "res://assets/art/smokva/hackers/fur_ruff.png", spots[1], persistent_id + "_decoy")
	decoy.relentless = true
	decoy.original = self
	decoy.pressing = pressing
	get_parent().add_child(decoy)
	# Same name and the same health on the label: only the feather tells them apart.
	decoy._label.text = _label.text
	decoy._label.visible = true
	global_position = spots[0]
	velocity = Vector2.ZERO
	state = State.RECOVER
	_state_time = 0.4
	_flank_time = 0.0
	decoy_made.emit(decoy)

func _pop() -> void:
	_smoke(global_position)
	remove_from_group("damageable")
	queue_free()

func _smoke(at: Vector2) -> void:
	for i in 6:
		var puff := Polygon2D.new()
		var points := PackedVector2Array()
		for j in 8:
			points.append(Vector2.from_angle(TAU * j / 8.0) * 5.0)
		puff.polygon = points
		puff.color = Color(0.82, 0.8, 0.86, 0.85)
		puff.position = at + Vector2.from_angle(TAU * i / 6.0) * 4.0 + Vector2(0, -12)
		puff.z_index = 950
		get_parent().add_child(puff)
		var tween := puff.create_tween()
		tween.tween_property(puff, "position", puff.position + Vector2.from_angle(TAU * i / 6.0) * 10.0 + Vector2(0, -6), 0.45)
		tween.parallel().tween_property(puff, "scale", Vector2(1.8, 1.8), 0.45)
		tween.parallel().tween_property(puff, "modulate:a", 0.0, 0.45)
		tween.tween_callback(puff.queue_free)

func _die() -> void:
	if enemy_id == "donat_duel":
		# Donat does not go down in the duel; the world ends it long before that.
		health = 1
		return
	_clear_warning()
	if is_instance_valid(decoy):
		decoy._pop()
	super._die()

# ---------- Luster's spiral ----------

func _start_bolt_warning() -> void:
	power_state = Power.WARN
	_power_time = BOLT_WARN_SECONDS
	_power_cooldown = BOLT_COOLDOWN
	# The candles on the chandelier glow brighter and brighter.
	var glow := create_tween().set_loops(2)
	glow.tween_property(_sprite, "modulate", Color(1.7, 1.55, 0.9), BOLT_WARN_SECONDS * 0.25)
	glow.tween_property(_sprite, "modulate", Color(1.2, 1.1, 0.8), BOLT_WARN_SECONDS * 0.25)
	# Eight sparks show where the bolts will leave from.
	var sparks := Node2D.new()
	sparks.position = global_position + Vector2(0, -12)
	sparks.z_index = 899
	for i in BOLT_COUNT:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(0, -1.5), Vector2(1.5, 0), Vector2(0, 1.5), Vector2(-1.5, 0)])
		spark.color = Color(1.0, 0.95, 0.6)
		spark.position = Vector2.from_angle(TAU * i / BOLT_COUNT) * SpiralBolt.START_RADIUS
		sparks.add_child(spark)
	get_parent().add_child(sparks)
	sparks.scale = Vector2(0.3, 0.3)
	sparks.create_tween().tween_property(sparks, "scale", Vector2.ONE, BOLT_WARN_SECONDS)
	_warning = sparks

func _fire_bolts() -> void:
	_sprite.modulate = _base_modulate()
	var centre := global_position + Vector2(0, -12)
	var offset := randf() * TAU
	# Below half health a second ring turns the other way at the same time.
	var turns := [_bolt_turn, -_bolt_turn] if health <= max_health / 2 else [_bolt_turn]
	for turn: float in turns:
		for i in BOLT_COUNT:
			var bolt := SpiralBolt.new()
			get_parent().add_child(bolt)
			bolt.launch(centre, offset + TAU * i / BOLT_COUNT, int(definition.get("bolt_damage", 14)), BOLT_RANGE, turn)
			bolt.collision_mask |= DASH_BLOCKERS
	# The next ring turns the other way.
	_bolt_turn = -_bolt_turn

# ---------- Donat's slash ----------

## Shows where Donat will slash. A feint shows the same and then flickers out.
func _start_slash_warning(target: Node2D, feint: bool = false, warn_seconds: float = SLASH_WARN_SECONDS) -> void:
	power_state = Power.WARN
	_feint = feint
	_power_time = FEINT_SECONDS if feint else warn_seconds
	_power_cooldown = 0.3 if feint else float(definition.get("attack_cooldown", 1.1))
	_dash_direction = (target.global_position - global_position).normalized()
	_clear_warning()
	_warning = SlashArc.warn(get_parent(), global_position, _dash_direction, _attack_reach())
	# He draws the blade back.
	var tween := create_tween()
	tween.tween_property(_sprite, "position:x", _sprite.position.x - _dash_direction.x * 2.0, _power_time)

## The feint: the half circle flickers and goes, no blade comes, and he hops back.
func _end_feint() -> void:
	_feint = false
	var arc := _warning
	_warning = null
	if is_instance_valid(arc):
		var flicker := arc.create_tween()
		flicker.tween_property(arc, "modulate:a", 0.2, 0.05)
		flicker.tween_property(arc, "modulate:a", 1.0, 0.05)
		flicker.tween_property(arc, "modulate:a", 0.0, 0.08)
		flicker.tween_callback(arc.queue_free)
	create_tween().tween_property(_sprite, "position", _sprite_rest(), 0.1)
	power_state = Power.OPEN
	_power_time = 0.15

## Where the sprite sits when Donat is not drawing back or lunging.
func _sprite_rest() -> Vector2:
	return Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2) if _sprite.texture != null else Vector2.ZERO

func _slash() -> void:
	var at := global_position
	SlashArc.swing(get_parent(), at, _dash_direction, _attack_reach(), _slash_left_first)
	_slash_left_first = not _slash_left_first
	# A short lunge into the swing.
	var rest := _sprite_rest()
	var tween := create_tween()
	tween.tween_property(_sprite, "position", rest + _dash_direction * 3.0, 0.06)
	tween.tween_property(_sprite, "position", rest, 0.2)
	for candidate in get_tree().get_nodes_in_group("party_target"):
		if candidate is Node2D and candidate.visible and candidate.has_method("take_damage") and SlashArc.hits(at, _dash_direction, _attack_reach(), (candidate as Node2D).global_position):
			candidate.take_damage(int(definition.get("damage", 28)), at)

func reset_after_player_defeat() -> void:
	_clear_warning()
	power_state = Power.NONE
	_sprite.scale = Vector2.ONE
	_heavy = false
	definition["damage"] = _base_damage
	_feint = false
	_second_slash = false
	_stepping_in = false
	_step_out = 0.0
	super.reset_after_player_defeat()
