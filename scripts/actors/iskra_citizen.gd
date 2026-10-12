class_name IskraCitizen
extends SkoljkaCitizen

var _ui: GameUI

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("iskra_citizen")
	collision_layer = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_ui):
		_ui = get_tree().get_first_node_in_group("game_ui") as GameUI
	if _ui != null and (_ui.scene_playing() or _ui.modal_overlay.visible or _ui.order_bar.visible):
		velocity = Vector2.ZERO
		return
	super._physics_process(delta)
