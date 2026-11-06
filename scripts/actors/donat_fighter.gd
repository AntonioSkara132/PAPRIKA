class_name DonatFighter
extends RaidSoldier

## Donat in the fight with the Purple Parrots. His strike is a slash that hits
## every enemy within SLASH_REACH in the half circle in front of him
## (scripts/actors/slash_arc.gd), not only the one he aimed at.
##
## While the player and Donat have switched bodies (scripts/world/smokva_world.gd)
## the player moves this body with the movement keys and slashes with the
## attack key, and his own fighting AI is off.

const SLASH_REACH := 34.0

## True while the player is in this body.
var controlled := false
var _left_first := true

func _reach() -> float:
	return SLASH_REACH

func _physics_process(delta: float) -> void:
	if not controlled:
		super._physics_process(delta)
		return
	z_index = 100 + int(global_position.y)
	_cooldown = maxf(0.0, _cooldown - delta)
	velocity = Vector2.ZERO
	if down:
		if _get_up_left > 0.0:
			_get_up_left -= delta
			if _get_up_left <= 0.0:
				get_up()
		return
	if _world == null or _world.player == null or _world.player.ui_is_open() or get_tree().paused:
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length_squared() > 0.01:
		facing = movement.normalized()
	velocity = movement * speed
	move_and_slide()

func _strike(_target: Node2D) -> void:
	if _cooldown > 0.0 or down:
		return
	_cooldown = strike_cooldown
	var at := global_position
	SlashArc.swing(get_parent(), at, facing, SLASH_REACH, _left_first)
	_left_first = not _left_first
	for node in get_tree().get_nodes_in_group("damageable"):
		if node is Enemy and node.visible and not node.is_queued_for_deletion() and SlashArc.hits(at, facing, SLASH_REACH, (node as Node2D).global_position):
			node.take_damage(strike_damage, at)
