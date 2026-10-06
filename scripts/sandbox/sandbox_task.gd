class_name SandboxTask
extends RefCounted

var id := ""
var action := ""
var soldier_ids: Array[String] = []
var assignments: Dictionary = {}
var paths: Dictionary = {}
var slots := PackedVector2Array()
var status := "active"
var source := ""
var blocked_reason := ""
var endpoint := ""
var leg_count := 0
var follow_offsets: Dictionary = {}
var order: Dictionary = {}
var facing := Vector2.ZERO
var leader_position := Vector2.ZERO
var heading := Vector2.DOWN
var update_timer := 0.0
var retry_count := 0

func _init(task_id: String = "", value: Dictionary = {}, source_label: String = "") -> void:
	id = task_id
	order = value.duplicate(true)
	action = str(value.get("action", ""))
	source = source_label
	for soldier_id: String in value.get("soldier_ids", []):
		soldier_ids.append(soldier_id)

func remove_soldiers(ids: Array[String]) -> void:
	for soldier_id in ids:
		soldier_ids.erase(soldier_id)
		assignments.erase(soldier_id)
		paths.erase(soldier_id)
		follow_offsets.erase(soldier_id)
	order["soldier_ids"] = soldier_ids.duplicate()
	slots = PackedVector2Array()
	for point: Vector2 in assignments.values():
		slots.append(point)

func is_continuous() -> bool:
	return action in ["follow_player", "patrol"]
