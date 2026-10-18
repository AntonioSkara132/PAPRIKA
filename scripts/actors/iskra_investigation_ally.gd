extends RaidSoldier

var encounter_id := ""
var encounter_bounds := Rect2()
var staged := false

func _physics_process(delta: float) -> void:
	if _world == null or _world.player == null or _world.player.ui_is_open() or get_tree().paused:
		velocity = Vector2.ZERO
		return
	if not staged and not encounter_bounds.has_point(_world.player.global_position):
		velocity = Vector2.ZERO
		return
	super._physics_process(delta)

func _choose_target(reach: float) -> Node2D:
	if not fights or staged:
		return null
	var nearest: Node2D
	var distance := INF
	var sight := ATTACK_SIGHT if order == "attack" else maxf(reach, follow_sight)
	for target in get_tree().get_nodes_in_group("damageable"):
		if not target is Enemy or not is_instance_valid(target) or target.is_queued_for_deletion() or target.health <= 0:
			continue
		if not encounter_bounds.has_point(target.global_position):
			continue
		if not target.persistent_id.begins_with("story_iskra_inv_"):
			continue
		var next_distance := global_position.distance_to(target.global_position)
		if next_distance <= sight and next_distance < distance:
			nearest = target
			distance = next_distance
	return nearest

func restore_condition(saved_health: int, saved_down: bool) -> void:
	health = clampi(saved_health, 0, max_health)
	down = saved_down or health <= 0
	_get_up_left = 0.0
	if down:
		health = 0
		collision_layer = 0
		remove_from_group("party_target")
		_sprite.modulate = Color(0.55, 0.55, 0.62)
		_sprite.rotation = -PI * 0.5
		_sprite.position = Vector2(-_sprite.texture.get_height() * 0.5, 2) if _sprite.texture != null else Vector2.ZERO
	_refresh_health_bar()
