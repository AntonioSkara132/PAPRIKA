class_name SlashArc
extends Node2D

## Donat's slash, drawn on the ground at his feet. It hits everyone within
## `reach` in the half circle in front of him (up to 90 degrees to either side
## of `facing`). As a warning it shows that half circle in faint red; as the
## slash itself, a pale blade sweeps across it from one side to the other and
## fades.

const SWEEP_SECONDS := 0.12
const FADE_SECONDS := 0.18
## Ground is seen from above at an angle, so the half circle is drawn flattened.
const FLATTEN := 0.75

var facing := Vector2.RIGHT
var reach := 34.0
var warning := false
## How far the blade has swept, from 0 to 1.
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()
## Alternate slashes sweep from opposite sides.
var from_left := true

## True when `point` is in the half circle of radius `reach` in front of
## `origin`, facing `toward`. `slack` lets a target whose feet are just outside
## still be hit by the blade's edge.
static func hits(origin: Vector2, toward: Vector2, slash_reach: float, point: Vector2, slack: float = 5.0) -> bool:
	var offset := point - origin
	return offset.length() <= slash_reach + slack and offset.dot(toward) >= 0.0

## A red warning of the area, left at `at` until it is freed.
static func warn(parent: Node, at: Vector2, toward: Vector2, slash_reach: float) -> SlashArc:
	var arc := SlashArc.new()
	arc.warning = true
	arc.facing = toward.normalized()
	arc.reach = slash_reach
	arc.global_position = at
	arc.z_index = 899
	parent.add_child(arc)
	arc.global_position = at
	arc.modulate.a = 0.0
	arc.create_tween().tween_property(arc, "modulate:a", 1.0, 0.15)
	return arc

## The slash itself: it sweeps, fades and frees itself.
static func swing(parent: Node, at: Vector2, toward: Vector2, slash_reach: float, left_first: bool) -> SlashArc:
	var arc := SlashArc.new()
	arc.facing = toward.normalized()
	arc.reach = slash_reach
	arc.from_left = left_first
	arc.z_index = 950
	parent.add_child(arc)
	arc.global_position = at
	var tween := arc.create_tween()
	tween.tween_property(arc, "progress", 1.0, SWEEP_SECONDS)
	tween.tween_property(arc, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(arc.queue_free)
	return arc

func _point(angle: float, radius: float) -> Vector2:
	var at := Vector2.from_angle(angle) * radius
	return Vector2(at.x, at.y * FLATTEN)

func _draw() -> void:
	var middle := facing.angle()
	if warning:
		var area := PackedVector2Array([Vector2.ZERO])
		for i in 17:
			area.append(_point(middle - PI * 0.5 + PI * i / 16.0, reach))
		draw_colored_polygon(area, Color(1.0, 0.2, 0.2, 0.32))
		area.append(Vector2.ZERO)
		draw_polyline(area, Color(1.0, 0.35, 0.35, 0.95), 1.5)
		return
	var start := middle - PI * 0.5 if from_left else middle + PI * 0.5
	var direction := 1.0 if from_left else -1.0
	var tip := start + direction * PI * progress
	# A blade-shaped crescent: thick near its leading edge and thin along the trail.
	var trail := maxf(0.0, PI * progress - 1.4)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / steps
		var angle := start + direction * lerpf(trail, PI * progress, t)
		outer.append(_point(angle, reach))
		inner.append(_point(angle, reach * lerpf(0.92, 0.55, t)))
	inner.reverse()
	var crescent := outer + inner
	if crescent.size() >= 3 and progress > 0.02:
		draw_colored_polygon(crescent, Color(0.86, 0.95, 1.0, 0.85))
		draw_polyline(outer, Color(1.0, 1.0, 1.0, 0.95), 1.0)
	draw_line(_point(tip, reach * 0.4), _point(tip, reach + 2.0), Color(1.0, 1.0, 1.0), 2.0)
