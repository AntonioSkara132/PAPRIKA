class_name SpiralBolt
extends Projectile

## One of Luster's light bolts. Eight leave him at once, evenly spaced round a
## circle, and each moves outward while turning round him, so the ring grows
## and spins. The gaps between bolts widen as the ring grows; the player gets
## through by stepping into a gap or by staying out of range.

const RADIAL_SPEED := 70.0
## Radians per second the ring turns.
const TURN_SPEED := 1.4
const START_RADIUS := 8.0

var centre := Vector2.ZERO
var angle := 0.0
var radius := START_RADIUS
## 1 turns clockwise on screen, -1 the other way.
var turn := 1.0

func launch(at_centre: Vector2, start_angle: float, bolt_damage: int, max_radius: float, turn_direction: float) -> void:
	centre = at_centre
	angle = start_angle
	radius = START_RADIUS
	turn = turn_direction
	configure(centre + Vector2.from_angle(angle) * radius, Vector2.from_angle(angle), bolt_damage, RADIAL_SPEED, max_radius, false)
	# A round spark replaces the arrowhead that Projectile draws.
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()
	var glow := Polygon2D.new()
	glow.polygon = _circle(4.0)
	glow.color = Color(1.0, 0.92, 0.55, 0.45)
	add_child(glow)
	var core := Polygon2D.new()
	core.polygon = _circle(2.0)
	core.color = Color(1.0, 0.98, 0.85)
	add_child(core)

func _circle(r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		points.append(Vector2.from_angle(TAU * i / 8.0) * r)
	return points

func _physics_process(delta: float) -> void:
	radius += RADIAL_SPEED * delta
	angle += TURN_SPEED * turn * delta
	global_position = centre + Vector2.from_angle(angle) * radius
	if radius >= max_distance:
		queue_free()
