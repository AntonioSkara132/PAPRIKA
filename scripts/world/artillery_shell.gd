class_name ArtilleryShell
extends Node2D

## A timed blast with a warning. A red ring marks the blast area for `warning`
## seconds and `on_impact` is then called with the blast point, which applies the
## damage. Artillery shells show a ball dropping in during the last half second;
## a demolition charge shows the charge sitting in the ring instead.

const FALL_SECONDS := 0.5
const FALL_HEIGHT := 150.0

var radius := 30.0
var _warning := 2.2
var _elapsed := 0.0
var _on_impact: Callable
var _ring: Line2D
var _ball: Sprite2D
var _done := false
var _falling := true

func launch(target: Vector2, blast_radius: float, warning: float, on_impact: Callable, falling: bool = true) -> void:
	_falling = falling
	global_position = target
	radius = blast_radius
	_warning = maxf(FALL_SECONDS, warning)
	_on_impact = on_impact
	z_index = 960 + int(target.y)
	_ring = Line2D.new()
	_ring.name = "WarningRing"
	var points := ArtilleryShell.circle(radius, 20)
	points.append(points[0])
	_ring.points = points
	_ring.width = 1.5
	_ring.default_color = Color(0.95, 0.25, 0.2, 0.85)
	add_child(_ring)
	var cross := Line2D.new()
	cross.points = PackedVector2Array([Vector2(-4, -3), Vector2(4, 3), Vector2.ZERO, Vector2(4, -3), Vector2(-4, 3)])
	cross.width = 1.5
	cross.default_color = _ring.default_color
	_ring.add_child(cross)
	_ball = Sprite2D.new()
	_ball.name = "Shell"
	_ball.texture = load("res://assets/art/space_military_base/station_cannonball.png") as Texture2D
	_ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball.visible = not falling
	if not falling:
		_ball.texture = load("res://assets/art/space_military_base/station_tnt_pile.png") as Texture2D
		_ball.scale = Vector2(0.45, 0.45)
		_ball.position = Vector2(0, -5)
	add_child(_ball)

func time_left() -> float:
	return maxf(0.0, _warning - _elapsed)

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_ring.modulate.a = 0.55 + 0.45 * absf(sin(_elapsed * 7.0))
	var falling := _warning - _elapsed
	if _falling and falling <= FALL_SECONDS:
		_ball.visible = true
		_ball.position = Vector2(0, -FALL_HEIGHT * maxf(0.0, falling) / FALL_SECONDS)
	if _elapsed >= _warning:
		_done = true
		if _on_impact.is_valid():
			_on_impact.call(global_position)
		queue_free()

static func circle(circle_radius: float, points: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in points:
		var angle := TAU * float(index) / float(points)
		polygon.append(Vector2(cos(angle), sin(angle) * 0.62) * circle_radius)
	return polygon
