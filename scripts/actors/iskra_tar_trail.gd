class_name IskraTarTrail
extends Node2D

## Tar puddles Roko leaves where he walks. Anyone but an enemy standing in one moves at SLOW_FACTOR.

const PATCH_SPACING := 24.0
const PATCH_SECONDS := 6.0
const FADE_SECONDS := 1.0
const MAX_PATCHES := 20
const SLOW_FACTOR := 0.5
## Puddles are drawn and tested as flattened ellipses so they read as lying on the floor.
const RADIUS := Vector2(14.0, 9.0)

var patches: Array[Dictionary] = []
var _last_drop := Vector2.INF

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 2
	add_to_group("tar_trail")

## Called each frame Roko walks; drops a new puddle every PATCH_SPACING of travel.
func walked_to(point: Vector2) -> void:
	if _last_drop != Vector2.INF and _last_drop.distance_to(point) < PATCH_SPACING:
		return
	_last_drop = point
	patches.append({"position": point, "left": PATCH_SECONDS})
	if patches.size() > MAX_PATCHES:
		patches.pop_front()
	queue_redraw()

## A teleport leaves no tar between the two spots.
func jumped_to(point: Vector2) -> void:
	_last_drop = point

func covers(point: Vector2) -> bool:
	for patch in patches:
		var offset: Vector2 = (point - patch.position) / RADIUS
		if offset.length_squared() <= 1.0:
			return true
	return false

func clear() -> void:
	patches.clear()
	_last_drop = Vector2.INF
	queue_redraw()

func _physics_process(delta: float) -> void:
	if patches.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.ui_is_open():
		return
	for patch in patches:
		patch.left -= delta
	patches = patches.filter(func(patch: Dictionary) -> bool: return patch.left > 0.0)
	queue_redraw()

func _draw() -> void:
	for patch in patches:
		var alpha := clampf(float(patch.left) / FADE_SECONDS, 0.0, 1.0)
		draw_set_transform(patch.position, 0.0, RADIUS / RADIUS.x)
		draw_circle(Vector2.ZERO, RADIUS.x, Color(0.10, 0.07, 0.09, 0.78 * alpha))
		draw_circle(Vector2(-3, -2), RADIUS.x * 0.45, Color(0.42, 0.20, 0.48, 0.45 * alpha))
	draw_set_transform(Vector2.ZERO)
