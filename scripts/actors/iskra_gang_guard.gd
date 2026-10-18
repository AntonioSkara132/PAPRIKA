extends Enemy

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.ui_is_open():
		velocity = Vector2.ZERO
		return
	super._physics_process(delta)
