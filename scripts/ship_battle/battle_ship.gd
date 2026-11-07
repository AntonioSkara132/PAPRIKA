class_name BattleShip
extends RefCounted

## One ship in a ship battle (scripts/ship_battle/ship_battle.gd), seen from
## above. Its numbers come from GameData.SHIPS. The nose points along
## `heading`; TNT leaves only from the two sides, so a ship has to turn a side
## to its target to hit it.

## How far either side of a side's straight-out direction its TNT can be
## aimed, in radians: 50 degrees.
const SIDE_WEDGE := 0.87

var id := ""
var display_name := ""
var texture: Texture2D
var position := Vector2.ZERO
## Radians; 0 is the nose pointing right on screen.
var heading := 0.0
## Speed along the nose, without the current.
var speed := 0.0
var max_speed := 70.0
var accel := 40.0
var turn_rate := 1.5
var radius := 16.0
var hull := 100
var max_hull := 100
var launchers := 0
var tnt_damage := 0
var reload_seconds := 3.6
## Seconds until each side can fire again; 0 is loaded.
var reload := {"left": 0.0, "right": 0.0}
## The current's push this frame, kept so the battle can draw and test it.
var drift := Vector2.ZERO
## Seconds left of the white flash after a hit.
var hit_flash := 0.0

func _init(ship_id: String, at: Vector2, facing: float) -> void:
	var definition := GameData.ship(ship_id)
	id = ship_id
	display_name = String(definition.get("name", ship_id))
	texture = load(String(definition.get("art", ""))) as Texture2D if definition.has("art") else null
	position = at
	heading = facing
	max_speed = float(definition.get("max_speed", max_speed))
	accel = float(definition.get("accel", accel))
	turn_rate = float(definition.get("turn_rate", turn_rate))
	radius = float(definition.get("radius", radius))
	max_hull = int(definition.get("hull", max_hull))
	hull = max_hull
	launchers = int(definition.get("launchers", 0))
	tnt_damage = int(definition.get("tnt_damage", 0))
	reload_seconds = float(definition.get("reload", reload_seconds))

func forward() -> Vector2:
	return Vector2.from_angle(heading)

## Straight out from `side` ("left" or "right"). With y pointing down the
## screen, left of the nose is a quarter turn back from it.
func side_direction(side: String) -> Vector2:
	return Vector2.from_angle(heading + (-PI / 2.0 if side == "left" else PI / 2.0))

## The side whose wedge `point` is in, or "" when it is off the nose or tail.
func side_facing(point: Vector2) -> String:
	var to_point := point - position
	if to_point.length() < 0.01:
		return ""
	for side in ["left", "right"]:
		if absf(side_direction(side).angle_to(to_point)) <= SIDE_WEDGE:
			return side
	return ""

## Where each TNT launcher on `side` sits, spread along the hull.
func launcher_points(side: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in launchers:
		var along := (float(i) - float(launchers - 1) / 2.0) * radius * 0.8
		points.append(position + forward() * along + side_direction(side) * radius * 0.55)
	return points

func ready_to_fire(side: String) -> bool:
	return launchers > 0 and float(reload[side]) <= 0.0

## Share of the reload done on `side`: 1 when loaded.
func loaded_share(side: String) -> float:
	return 1.0 - clampf(float(reload[side]) / reload_seconds, 0.0, 1.0)

## Turns toward `steer` (-1 left, 1 right) and speeds up or slows down toward
## `throttle` (-1 to 1). Ships turn more slowly when nearly stopped.
func steer_and_move(steer: float, throttle: float, current: Vector2, delta: float) -> void:
	var grip := 0.45 + 0.55 * (clampf(speed / max_speed, 0.0, 1.0) if max_speed > 0.0 else 0.0)
	heading = wrapf(heading + clampf(steer, -1.0, 1.0) * turn_rate * grip * delta, -PI, PI)
	if throttle > 0.0:
		speed = minf(max_speed, speed + accel * throttle * delta)
	elif throttle < 0.0:
		speed = maxf(0.0, speed + accel * 1.5 * throttle * delta)
	drift = current
	position += (forward() * speed + current) * delta
	for side in reload:
		reload[side] = maxf(0.0, float(reload[side]) - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

func take_hit(amount: int, lowest: int = 0) -> void:
	hull = maxi(lowest, hull - amount)
	hit_flash = 0.18

func sunk() -> bool:
	return hull <= 0
