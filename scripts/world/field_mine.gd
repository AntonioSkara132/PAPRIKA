class_name FieldMine
extends Node2D

## A buried mine on Artichoke. Republic minefield mines (side "minefield") go off
## under anyone; mines the player plants (side "confederation") go off only under
## Republic soldiers. Stepping within TRIGGER_RADIUS of an armed mine detonates it.

signal triggered(mine: FieldMine)

const TRIGGER_RADIUS := 9.0

var side := "minefield"
var armed := false
var _arm_time := 0.0

func configure(at: Vector2, mine_side: String, arm_delay: float, visible_mine: bool) -> void:
	global_position = at
	side = mine_side
	_arm_time = arm_delay
	armed = arm_delay <= 0.0
	z_index = 10 + int(at.y)
	if visible_mine:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load("res://assets/art/space_military_base/station_mine_icon.png") as Texture2D
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(0, -3)
		add_child(sprite)
		sprite.modulate = Color(1, 1, 1, 0.55) if not armed else Color.WHITE

func _physics_process(delta: float) -> void:
	if not armed:
		_arm_time -= delta
		if _arm_time <= 0.0:
			armed = true
			var sprite := get_node_or_null("Sprite") as Sprite2D
			if sprite != null:
				sprite.modulate = Color.WHITE
		return
	for node in get_tree().get_nodes_in_group("damageable"):
		if node is Enemy and node.visible and node.global_position.distance_to(global_position) <= TRIGGER_RADIUS:
			triggered.emit(self)
			return
	if side != "minefield":
		return
	for node in get_tree().get_nodes_in_group("party_target"):
		if node is Node2D and (node as Node2D).visible and (node as Node2D).global_position.distance_to(global_position) <= TRIGGER_RADIUS:
			triggered.emit(self)
			return
