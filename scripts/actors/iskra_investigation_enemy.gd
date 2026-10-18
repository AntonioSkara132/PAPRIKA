extends Enemy

signal interacted(actor_id: String)
signal yielded(actor_id: String)
signal fled(actor_id: String)
signal damaged(actor_id: String, amount: int, source_position: Vector2)
signal phased(actor_id: String)
signal phase_completed(actor_id: String)
signal ring_fired(actor_id: String)

## Roko's ring: after a short warning he looses arrows in every direction at anyone close by.
const RING_ARROWS := 16
const RING_DAMAGE := 18
const RING_WARNING_SECONDS := 0.6
const RING_COOLDOWN := 5.0
const RING_TRIGGER_DISTANCE := 90.0
const RING_ARROW_SPEED := 140.0
const RING_ARROW_RANGE := 220.0
## Two attackers this close count as surrounding Roko, and he teleports out.
const SURROUNDED_DISTANCE := 44.0
const ROKO_PHASE_COOLDOWN := 4.5
## Roko's anti-Banishing ward: the first WARD damage he takes breaks it. Until then a Banishing Arrow does nothing to him.
const WARD := 120

var actor_id := ""
var encounter_id := ""
var encounter_bounds := Rect2()
var mode := "idle"
var escape_goal := Vector2.ZERO
var _stalled := 0.0
var _escape_reported := false
var tar_trail: IskraTarTrail
var _ring_warning_left := 0.0
var _ring_cooldown := 3.0
var _ring_marker: Line2D

func _ready() -> void:
	super._ready()
	set_mode(mode)

func set_mode(next_mode: String) -> void:
	mode = next_mode
	velocity = Vector2.ZERO
	_attack_target = null
	if mode in ["shoot", "attack", "flee"]:
		add_to_group("damageable")
	else:
		remove_from_group("damageable")
	if actor_id == "assassin" and mode in ["flee", "surrendered"]:
		add_to_group("interactable")
	elif actor_id == "squirrel_boss" and mode == "surrendered":
		add_to_group("interactable")
	else:
		remove_from_group("interactable")
	if _built:
		_sprite.modulate = Color("e6cf9f") if mode == "surrendered" else _base_modulate()
		_label.text = _display_name() + (" — surrendered" if mode == "surrendered" else "")
		_label.visible = mode == "surrendered"

func get_interaction_text() -> String:
	if actor_id == "assassin":
		return "Capture the attacker" if mode == "surrendered" else "Catch the fleeing attacker"
	return "Question the Squirrel boss"

func interact(_actor: Node) -> void:
	interacted.emit(actor_id)

func surrender() -> void:
	if health <= 0 or mode in ["dead", "captured", "escaped", "surrendered"]:
		return
	_clear_phase_warning()
	set_mode("surrendered")
	yielded.emit(actor_id)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.ui_is_open() or get_tree().paused or mode not in ["attack", "flee"]:
		velocity = Vector2.ZERO
		return
	if mode == "flee":
		if global_position.distance_to(escape_goal) <= 12.0:
			set_mode("escaped")
			visible = false
			collision_layer = 0
			if not _escape_reported:
				_escape_reported = true
				fled.emit(actor_id)
			return
		var before := global_position
		_move_toward(escape_goal, float(definition.get("speed", 66.0)))
		_stalled = _stalled + delta if before.distance_to(global_position) < 0.2 else 0.0
		if _stalled >= 0.7 and player.global_position.distance_to(global_position) <= 48.0 and can_be_reached_by(player.global_position):
			surrender()
		z_index = 100 + int(global_position.y)
		return
	if _is_roko() and _roko_step(delta):
		z_index = 100 + int(global_position.y)
		return
	super._physics_process(delta)
	if _is_roko() and velocity.length_squared() > 1.0:
		_trail().walked_to(global_position)

func _is_roko() -> bool:
	return actor_id == "pelican_hacker" and mode == "attack" and health > 0

func _trail() -> IskraTarTrail:
	if not is_instance_valid(tar_trail):
		tar_trail = IskraTarTrail.new()
		add_child(tar_trail)
	return tar_trail

## Runs Roko's own powers before the shared hacker behaviour. True while he is busy with one.
func _roko_step(delta: float) -> bool:
	_ring_cooldown = maxf(0.0, _ring_cooldown - delta)
	if _ring_warning_left > 0.0:
		velocity = Vector2.ZERO
		_ring_warning_left -= delta
		if _ring_warning_left <= 0.0:
			_fire_ring()
		return true
	if state == State.PHASE_WARNING:
		return false
	if _ring_cooldown <= 0.0 and not _hostiles_within(RING_TRIGGER_DISTANCE).is_empty():
		_start_ring()
		return true
	if _phase_cooldown <= 0.0 and _hostiles_within(SURROUNDED_DISTANCE).size() >= 2:
		_start_phase(_nearest_target())
		return state == State.PHASE_WARNING
	return false

func _hostiles_within(distance: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("party_target"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.visible:
			continue
		if encounter_bounds.has_point(candidate.global_position) and global_position.distance_to(candidate.global_position) < distance:
			found.append(candidate)
	return found

func _start_ring() -> void:
	_ring_warning_left = RING_WARNING_SECONDS
	velocity = Vector2.ZERO
	_ring_marker = Line2D.new()
	_ring_marker.width = 2.0
	_ring_marker.default_color = Color(1.0, 0.25, 0.2, 0.85)
	var points := PackedVector2Array()
	for index in 25:
		points.append(Vector2.from_angle(TAU * index / 24.0) * Vector2(18.0, 11.0))
	_ring_marker.points = points
	_ring_marker.z_index = 950
	add_child(_ring_marker)
	var tween := _ring_marker.create_tween()
	tween.tween_property(_ring_marker, "scale", Vector2(1.6, 1.6), RING_WARNING_SECONDS)

func reset_after_player_defeat() -> void:
	_clear_ring_warning()
	if is_instance_valid(tar_trail):
		tar_trail.clear()
	super.reset_after_player_defeat()

func _clear_ring_warning() -> void:
	_ring_warning_left = 0.0
	if is_instance_valid(_ring_marker):
		_ring_marker.queue_free()
	_ring_marker = null

func _fire_ring() -> void:
	_clear_ring_warning()
	_ring_cooldown = RING_COOLDOWN
	var origin := global_position + Vector2(0, -8)
	var turn := _rng.randf_range(0.0, TAU / RING_ARROWS)
	for index in RING_ARROWS:
		var projectile := Projectile.new()
		get_parent().add_child(projectile)
		projectile.configure(origin, Vector2.from_angle(turn + TAU * index / RING_ARROWS), RING_DAMAGE, RING_ARROW_SPEED, RING_ARROW_RANGE, false)
	ring_fired.emit(actor_id)

func can_be_reached_by(point: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(point + Vector2(0, -4), global_position + Vector2(0, -4), 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _nearest_target() -> Node2D:
	var nearest: Node2D
	var distance := INF
	for candidate in get_tree().get_nodes_in_group("party_target"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.visible:
			continue
		if not encounter_bounds.has_point(candidate.global_position):
			continue
		var next_distance := global_position.distance_squared_to(candidate.global_position)
		if next_distance < distance:
			nearest = candidate
			distance = next_distance
	return nearest

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if mode not in ["shoot", "attack", "flee"]:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.ui_is_open():
		return
	var before := health
	var warded := ward_left() > 0
	super.take_damage(amount, source_position)
	if health < before:
		damaged.emit(actor_id, before - health, source_position)
	if warded and ward_left() == 0 and health > 0:
		_sprite.modulate = _base_modulate()
		GameState.notify("Roko's anti-Banishing ward breaks. The Banishing Arrow can reach him now.")
	elif ward_left() > 0:
		_label.text += "  ward %d" % ward_left()
	if health > 0 and actor_id == "assassin":
		if health <= 14:
			surrender()
		else:
			set_mode("flee")

## Ward left on Roko. Health only falls during a fight, so the ward is read from it and needs no saved field.
func ward_left() -> int:
	if actor_id != "pelican_hacker":
		return 0
	return maxi(0, WARD - (max_health - health))

## A Banishing Arrow kills outright, unless Roko's ward still holds or this enemy is not fighting yet.
func take_banishing_hit() -> bool:
	if health <= 0 or mode not in ["shoot", "attack", "flee"]:
		GameState.notify("The Banishing Arrow is spent on %s, who is not in the fight." % _display_name())
		return false
	if ward_left() > 0:
		GameState.notify("Roko's ward swallows the Banishing Arrow.")
		return false
	health = 0
	damaged.emit(actor_id, max_health, global_position)
	_die()
	return true

## Roko sees the arrow coming when he is fighting the MC and teleports clear of it.
func dodge_banishing(player: Node2D) -> bool:
	if not _is_roko() or state == State.PHASE_WARNING or _ring_warning_left > 0.0 or _nearest_target() != player:
		return false
	_start_roko_phase(player, true)
	return state == State.PHASE_WARNING

func execute_surrendered() -> bool:
	if mode != "surrendered" or health <= 0:
		return false
	health = 0
	_die()
	return true

func _die() -> void:
	if mode == "dead":
		return
	mode = "dead"
	_clear_ring_warning()
	if is_instance_valid(tar_trail):
		tar_trail.clear()
	remove_from_group("interactable")
	super._die()

func _start_phase(target: Node2D) -> void:
	if actor_id == "pelican_hacker":
		_start_roko_phase(target)
		return
	super._start_phase(target)
	if state == State.PHASE_WARNING and not encounter_bounds.grow(-16.0).has_point(_phase_destination):
		_clear_phase_warning()
		state = State.RECOVER
		_state_time = 0.35
	elif state == State.PHASE_WARNING:
		phased.emit(actor_id)

## Roko picks his teleport spot instead of landing at random. Surrounded, he jumps to
## the spot furthest from everyone that still lets him shoot the MC. Otherwise he
## lands near the MC on the side away from Davor and the allies.
func _start_roko_phase(target: Node2D, force_escape: bool = false) -> void:
	_phase_cooldown = ROKO_PHASE_COOLDOWN
	var world := get_parent().get_parent() as GameWorld
	if world == null or world.tiled_loader == null or target == null:
		return
	var space := get_world_2d().direct_space_state
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var aim := player if player != null and encounter_bounds.has_point(player.global_position) else target
	var hostiles := _hostiles_within(INF)
	var escaping := force_escape or _hostiles_within(SURROUNDED_DISTANCE).size() >= 2
	var best := Vector2.INF
	var best_score := -INF
	for attempt in 24:
		var candidate: Vector2
		if escaping:
			candidate = global_position + Vector2.from_angle(_rng.randf_range(-PI, PI)) * _rng.randf_range(70.0, 130.0)
		else:
			candidate = aim.global_position + Vector2.from_angle(_rng.randf_range(-PI, PI)) * _rng.randf_range(48.0, 80.0)
		if not encounter_bounds.grow(-16.0).has_point(candidate) or not _phase_spot_clear(candidate, world.tiled_loader, space):
			continue
		var sees_aim := _clear_line(candidate, aim.global_position, space)
		if not escaping and not sees_aim:
			continue
		var score := 0.0
		var nearest := INF
		for hostile in hostiles:
			if hostile != aim or escaping:
				nearest = minf(nearest, candidate.distance_to(hostile.global_position))
		score = nearest if nearest < INF else 0.0
		if escaping and sees_aim:
			score += 40.0
		if score > best_score:
			best_score = score
			best = candidate
	if best == Vector2.INF:
		return
	_begin_phase_warning(best)
	phased.emit(actor_id)

func _clear_line(from: Vector2, to: Vector2, space: PhysicsDirectSpaceState2D) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from + Vector2(0, -4), to + Vector2(0, -4), 1, [get_rid()])
	return space.intersect_ray(ray).is_empty()

func _finish_phase() -> void:
	if not encounter_bounds.grow(-16.0).has_point(_phase_destination):
		_clear_phase_warning()
		state = State.RECOVER
		_state_time = 0.35
		return
	var before := global_position
	super._finish_phase()
	if global_position != before:
		if is_instance_valid(tar_trail):
			tar_trail.jumped_to(global_position)
		phase_completed.emit(actor_id)

func _display_name() -> String:
	return str(definition.get("name", "Guard"))

func _base_modulate() -> Color:
	return Color(0.72, 0.86, 1.0) if ward_left() > 0 else Color.WHITE
