class_name TableSoccerGame
extends Control

## Table soccer at Smokva against Krešo, seen from above. The player plays red,
## defends the left goal and moves all four red rods together with the arrow
## keys; Space kicks. Krešo plays blue. The first to five goals wins.

signal closed

const VIEW := Vector2(640, 360)
const FIELD := Rect2(70, 70, 500, 250)
const GOAL_HEIGHT := 76.0
const BALL_RADIUS := 5.0
const MAN_RADIUS := 7.0
const WIN_GOALS := 5
## Rods from left to right: team, number of men and the gap between them, as on
## a real table (goalie, defence, the other side's attack, midfield, ...).
const RODS := [
	["red", 1, 0.0], ["red", 2, 96.0], ["blue", 3, 72.0], ["red", 5, 46.0],
	["blue", 5, 46.0], ["red", 3, 72.0], ["blue", 2, 96.0], ["blue", 1, 0.0],
]
const PLAYER_SPEED := 300.0
const KRESO_SPEED := 190.0
const KICK_SECONDS := 0.16
const KICK_SPEED := 430.0
const MAX_SPEED := 520.0
const FRICTION := 0.55
## A ball resting this long out of reach is put back in the middle.
const STUCK_SECONDS := 2.5

const INK := Color("1c1730")
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const MUTED := Color("b6adbf")
const RED_TEAM := Color("d4433a")
const BLUE_TEAM := Color("3d6fd6")

var opponent := "Krešo"
var rng := RandomNumberGenerator.new()
var ball := Vector2.ZERO
var velocity := Vector2.ZERO
var offsets := {"red": 0.0, "blue": 0.0}
var kick_timer := {"red": 0.0, "blue": 0.0}
var goals := {"red": 0, "blue": 0}
var message := ""
var over := false
var _kreso_kick_cooldown := 0.0
var _kreso_target := 0.0
var _kreso_think := 0.0
var _slow_time := 0.0
var _pause_time := 0.0

func _ready() -> void:
	add_to_group("ui_modal")
	add_to_group("bar_game")
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	restart()

func restart() -> void:
	goals = {"red": 0, "blue": 0}
	offsets = {"red": 0.0, "blue": 0.0}
	over = false
	serve()
	message = "First to %d goals. Kick with Space." % WIN_GOALS

## Drops the ball in the middle of the table, rolling to a random side.
func serve() -> void:
	ball = FIELD.get_center()
	velocity = Vector2(rng.randf_range(60.0, 110.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(-120.0, 120.0))
	_slow_time = 0.0
	_pause_time = 0.6

func rod_x(index: int) -> float:
	return FIELD.position.x + FIELD.size.x * (index + 0.5) / RODS.size()

## How far a rod's men can slide up or down from the middle.
func rod_travel(index: int) -> float:
	var count: int = RODS[index][1]
	var spread: float = RODS[index][2] * (count - 1)
	return (FIELD.size.y - spread) * 0.5 - MAN_RADIUS - 2.0

func men(index: int) -> Array:
	var team: String = RODS[index][0]
	var count: int = RODS[index][1]
	var gap: float = RODS[index][2]
	var travel := rod_travel(index)
	var shift := clampf(offsets[team], -travel, travel)
	var result := []
	for k in count:
		result.append(Vector2(rod_x(index), FIELD.get_center().y + (k - (count - 1) * 0.5) * gap + shift))
	return result

func _process(delta: float) -> void:
	if over:
		queue_redraw()
		return
	var largest := 0.0
	for i in RODS.size():
		largest = maxf(largest, rod_travel(i))
	offsets["red"] = clampf(offsets["red"] + Input.get_axis("move_up", "move_down") * PLAYER_SPEED * delta, -largest, largest)
	_kreso_moves(delta)
	for team in kick_timer:
		kick_timer[team] = maxf(0.0, kick_timer[team] - delta)
	if _pause_time > 0.0:
		_pause_time -= delta
	else:
		step(delta)
	queue_redraw()

## Moves the ball one step: walls, men and goals.
func step(delta: float) -> void:
	ball += velocity * delta
	velocity *= pow(FRICTION, delta)
	var top := FIELD.position.y + BALL_RADIUS
	var bottom := FIELD.end.y - BALL_RADIUS
	if ball.y < top or ball.y > bottom:
		ball.y = clampf(ball.y, top, bottom)
		velocity.y = -velocity.y * 0.85
	var in_mouth := absf(ball.y - FIELD.get_center().y) < GOAL_HEIGHT * 0.5 - BALL_RADIUS
	if ball.x < FIELD.position.x + BALL_RADIUS:
		if in_mouth:
			_goal("blue")
			return
		ball.x = FIELD.position.x + BALL_RADIUS
		velocity.x = absf(velocity.x) * 0.85
	elif ball.x > FIELD.end.x - BALL_RADIUS:
		if in_mouth:
			_goal("red")
			return
		ball.x = FIELD.end.x - BALL_RADIUS
		velocity.x = -absf(velocity.x) * 0.85
	for i in RODS.size():
		var team: String = RODS[i][0]
		for man: Vector2 in men(i):
			var apart := ball - man
			var reach := BALL_RADIUS + MAN_RADIUS + (4.0 if kick_timer[team] > 0.0 else 0.0)
			if apart.length() >= reach:
				continue
			var away := apart.normalized() if apart.length() > 0.01 else Vector2(1.0 if team == "red" else -1.0, 0.0)
			ball = man + away * reach
			if kick_timer[team] > 0.0:
				var forward := 1.0 if team == "red" else -1.0
				velocity = Vector2(forward, clampf(apart.y / reach, -0.8, 0.8) + rng.randf_range(-0.15, 0.15)).normalized() * KICK_SPEED
			else:
				velocity = velocity.bounce(away) * 0.8 if velocity.dot(away) < 0.0 else velocity
				velocity += away * 30.0
	velocity = velocity.limit_length(MAX_SPEED)
	if velocity.length() < 25.0:
		_slow_time += delta
		if _slow_time > STUCK_SECONDS:
			message = "The ball stopped out of reach. Krešo drops it back in the middle."
			serve()
	else:
		_slow_time = 0.0

func kick(team: String) -> void:
	if kick_timer[team] <= 0.0:
		kick_timer[team] = KICK_SECONDS

func _goal(team: String) -> void:
	goals[team] += 1
	if goals[team] >= WIN_GOALS:
		over = true
		message = ("You win, %d to %d! %s: \"The rods are bent. Somebody bent them at night.\"" % [goals["red"], goals["blue"], opponent]) if team == "red" else ("%s wins, %d to %d. %s: \"Rematch costs a beer. Losing is free.\"" % [opponent, goals["blue"], goals["red"], opponent])
		return
	message = "Goal! You score." if team == "red" else "Goal for %s." % opponent
	serve()

## Krešo slides the blue rods to put a man in the ball's path, a little late,
## and kicks when the ball comes close to one of his men.
func _kreso_moves(delta: float) -> void:
	_kreso_think -= delta
	if _kreso_think <= 0.0:
		_kreso_think = rng.randf_range(0.08, 0.2)
		var best_rod := -1
		var best_distance := INF
		for i in RODS.size():
			if RODS[i][0] != "blue":
				continue
			# The rods the ball has not passed yet, coming toward the blue goal.
			var ahead := rod_x(i) - ball.x
			var distance := absf(ahead) + (0.0 if ahead > -10.0 else 400.0)
			if distance < best_distance:
				best_distance = distance
				best_rod = i
		if best_rod >= 0:
			var nearest := INF
			for man: Vector2 in men(best_rod):
				if absf(man.y - ball.y) < absf(nearest):
					nearest = ball.y - man.y
			_kreso_target = offsets["blue"] + nearest + rng.randf_range(-6.0, 6.0)
	var step_size := KRESO_SPEED * delta
	offsets["blue"] += clampf(_kreso_target - offsets["blue"], -step_size, step_size)
	_kreso_kick_cooldown -= delta
	if _kreso_kick_cooldown <= 0.0:
		for i in RODS.size():
			if RODS[i][0] != "blue":
				continue
			for man: Vector2 in men(i):
				if man.distance_to(ball) < BALL_RADIUS + MAN_RADIUS + 10.0 and ball.x < man.x + 6.0:
					kick("blue")
					_kreso_kick_cooldown = rng.randf_range(0.3, 0.55)
					return

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		close()
	elif event.is_action_pressed("attack") or event.is_action_pressed("interact"):
		if over:
			restart()
		else:
			kick("red")
	else:
		return
	get_viewport().set_input_as_handled()

func close() -> void:
	closed.emit()
	queue_free()

# ---------- drawing ----------

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.05, 0.04, 0.09, 0.92))
	draw_rect(FIELD.grow(14), Color("4e2c20"))
	draw_rect(FIELD.grow(14), Color("2a1812"), false, 3.0)
	draw_rect(FIELD, Color("2f7d45"))
	for k in 10:
		if k % 2 == 0:
			draw_rect(Rect2(FIELD.position.x + FIELD.size.x * k / 10.0, FIELD.position.y, FIELD.size.x / 10.0, FIELD.size.y), Color("348a4c"))
	var line := Color(0.92, 0.95, 0.9, 0.8)
	draw_rect(FIELD, line, false, 1.0)
	draw_line(Vector2(FIELD.get_center().x, FIELD.position.y), Vector2(FIELD.get_center().x, FIELD.end.y), line)
	draw_arc(FIELD.get_center(), 30, 0, TAU, 32, line)
	for side in [FIELD.position.x, FIELD.end.x]:
		var goal_rect := Rect2(side - (10.0 if side == FIELD.position.x else 0.0), FIELD.get_center().y - GOAL_HEIGHT * 0.5, 10, GOAL_HEIGHT)
		draw_rect(goal_rect, Color("11111d"))
		var box_w := 40.0
		var box_x: float = side if side == FIELD.position.x else side - box_w
		draw_rect(Rect2(box_x, FIELD.get_center().y - 55, box_w, 110), line, false, 1.0)
	for i in RODS.size():
		var x := rod_x(i)
		draw_line(Vector2(x, FIELD.position.y - 14), Vector2(x, FIELD.end.y + 14), Color("c9ccd6"), 2.0)
		var team: String = RODS[i][0]
		var color := RED_TEAM if team == "red" else BLUE_TEAM
		var kicking: bool = kick_timer[team] > 0.0
		var forward := 1.0 if team == "red" else -1.0
		for man: Vector2 in men(i):
			var feet := man + Vector2(forward * (9.0 if kicking else 4.0), 0)
			draw_rect(Rect2(feet - Vector2(2, 3), Vector2(4, 6)), INK)
			draw_rect(Rect2(man - Vector2(4, 6), Vector2(8, 12)), color)
			draw_rect(Rect2(man - Vector2(4, 6), Vector2(8, 12)), INK, false, 1.0)
			draw_circle(man, 3.0, Color("e2b48a"))
	draw_circle(ball + Vector2(1, 2), BALL_RADIUS, Color(0, 0, 0, 0.35))
	draw_circle(ball, BALL_RADIUS, CREAM)
	draw_arc(ball, BALL_RADIUS, 0, TAU, 16, INK)
	draw_string(font, Vector2(70, 34), "TABLE SOCCER AT SMOKVA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	draw_string(font, Vector2(330, 34), "You  %d" % goals["red"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, RED_TEAM)
	draw_string(font, Vector2(400, 34), ":", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)
	draw_string(font, Vector2(412, 34), "%d  %s" % [goals["blue"], opponent], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BLUE_TEAM)
	draw_string(font, Vector2(70, 52), message, HORIZONTAL_ALIGNMENT_LEFT, 500, 11, CREAM)
	var help := "Space: play again   Esc: leave" if over else "Up / Down: move your red rods   Space: kick   Esc: leave"
	draw_string(font, Vector2(70, 348), help, HORIZONTAL_ALIGNMENT_LEFT, 500, 10, MUTED)
