class_name FieldPlot
extends Area2D

var field_id: String = ""
var crop_id: String = ""
var is_common: bool = true
var interaction_text: String = ""
var crop_sprite: Sprite2D
var ready_texture: Texture2D
var soil_texture: Texture2D
var _last_ready := true

func configure(new_field_id: String, new_crop_id: String, common: bool, sprite: Sprite2D, ready: Texture2D, soil: Texture2D) -> void:
	field_id = new_field_id
	crop_id = new_crop_id
	is_common = common
	crop_sprite = sprite
	ready_texture = ready
	soil_texture = soil
	collision_layer = 16
	collision_mask = 0
	add_to_group("interactable")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	collision.shape = shape
	add_child(collision)
	_refresh_visual(true)

func _process(_delta: float) -> void:
	var ready := GameState.field_is_ready(field_id)
	if ready != _last_ready:
		_refresh_visual(ready)

func get_interaction_text() -> String:
	if not is_common:
		return "Private field"
	if not GameState.field_is_ready(field_id):
		return "%s regrows in %d seconds" % [_crop_name(), ceili(GameState.field_seconds_remaining(field_id))]
	return "Harvest %s" % _crop_name()

func interact(_player: Node) -> void:
	if not is_common:
		GameState.notify("This is a private field. Ask the owner before harvesting.")
		return
	if not GameState.field_is_ready(field_id):
		GameState.notify("That crop is still regrowing.")
		return
	GameState.mark_field_harvested(field_id)
	GameState.add_item(crop_id)
	GameState.record_event("common_crop_harvested")
	GameState.notify("Harvested %s." % _crop_name())
	_refresh_visual(false)

func _refresh_visual(ready: bool) -> void:
	_last_ready = ready
	if crop_sprite != null:
		crop_sprite.texture = ready_texture if ready else soil_texture
		crop_sprite.modulate = Color.WHITE if ready else Color(0.72, 0.72, 0.72)
	interaction_text = get_interaction_text()

func _crop_name() -> String:
	return String(GameData.item(crop_id).get("name", crop_id.capitalize()))
