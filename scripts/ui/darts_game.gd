class_name DartsGame
extends Control

## Darts at Smokva against Krešo: three rounds of three darts, the higher total
## wins. The aim drifts like an unsteady hand; the arrow keys pull it back and
## Space throws. Krešo aims at the treble 20 and sometimes misses badly.

signal closed

const VIEW := Vector2(640, 360)
const CENTER := Vector2(214, 186)
## The board's radius in pixels; a real board is 170 mm to the outer double ring.
const BOARD_RADIUS := 128.0
const MM := BOARD_RADIUS / 170.0
const BULL := 6.35
const OUTER_BULL := 15.9
const TREBLE_IN := 99.0
const TREBLE_OUT := 107.0
const DOUBLE_IN := 162.0
const DOUBLE_OUT := 170.0
## Board numbers clockwise from the top.
const NUMBERS := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const ROUNDS := 3
const DARTS_PER_TURN := 3
const AIM_SPEED := 120.0
## How far the hand drifts from where the player holds it, in pixels.
const SWAY := 18.0
const KRESO_SPREAD := 16.0
const KRESO_DELAY := 0.7

const INK := Color("1c1730")
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const MUTED := Color("b6adbf")
const RED := Color("c8352c")
const GREEN := Color("2f8f4e")
const BLACK := Color("1e1b22")
const SISAL := Color("e8dcb8")

var opponent := "Krešo"
var rng := RandomNumberGenerator.new()
## "player", "kreso" or "over".
var turn := "player"
var round_number := 1
var darts_thrown := 0
var scores := {"player": 0, "kreso": 0}
var turn_darts: Array = []
var last_text := ""
var aim := Vector2.ZERO
var _time := 0.0
var _kreso_wait := 0.0

func _ready() -> void:
	add_to_group("ui_modal")
	add_to_group("bar_game")
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	restart()

func restart() -> void:
	turn = "player"
	round_number = 1
	darts_thrown = 0
	scores = {"player": 0, "kreso": 0}
	turn_darts.clear()
	aim = Vector2(0, -BOARD_RADIUS * 0.6)
	last_text = "Your throw. Hold the aim steady and let go."
	queue_redraw()

## Where the dart would land now: the held aim plus the hand's drift.
func sight() -> Vector2:
	return CENTER + aim + Vector2(sin(_time * 1.7) + 0.5 * sin(_time * 4.1 + 1.0), cos(_time * 1.3 + 0.4) + 0.5 * sin(_time * 3.3)) * SWAY * 0.67

func _process(delta: float) -> void:
	_time += delta
	if turn == "player":
		var steer := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
		aim = (aim + steer * AIM_SPEED * delta).limit_length(BOARD_RADIUS * 1.15)
	elif turn == "kreso":
		_kreso_wait -= delta
		if _kreso_wait <= 0.0:
			_kreso_throw()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		close()
	elif event.is_action_pressed("attack") or event.is_action_pressed("interact"):
		if turn == "player":
			throw_at(sight() + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)))
		elif turn == "over":
			restart()
	else:
		return
	get_viewport().set_input_as_handled()

func close() -> void:
	closed.emit()
	queue_free()

## Score of a dart at `point` on the screen, with the name of the bed it hit.
static func score_at(point: Vector2) -> Array:
	var offset := (point - CENTER) / MM
	var distance := offset.length()
	if distance > DOUBLE_OUT:
		return [0, "Off the board"]
	if distance <= BULL:
		return [50, "Bullseye!"]
	if distance <= OUTER_BULL:
		return [25, "Outer bull"]
	var angle := fposmod(rad_to_deg(atan2(offset.x, -offset.y)) + 9.0, 360.0)
	var number: int = NUMBERS[int(angle / 18.0) % 20]
	if distance >= TREBLE_IN and distance <= TREBLE_OUT:
		return [number * 3, "Treble %d!" % number]
	if distance >= DOUBLE_IN:
		return [number * 2, "Double %d" % number]
	return [number, str(number)]

func throw_at(point: Vector2) -> int:
	var result := score_at(point)
	var points: int = result[0]
	scores[turn] += points
	turn_darts.append({"at": point, "who": turn})
	var who := "You" if turn == "player" else opponent
	last_text = "%s: %s (%d)" % [who, result[1], points]
	darts_thrown += 1
	if darts_thrown >= DARTS_PER_TURN:
		_next_turn()
	elif turn == "kreso":
		_kreso_wait = KRESO_DELAY
	return points

func _next_turn() -> void:
	darts_thrown = 0
	if turn == "player":
		turn = "kreso"
		_kreso_wait = KRESO_DELAY * 1.5
	else:
		round_number += 1
		if round_number > ROUNDS:
			turn = "over"
			var mine: int = scores["player"]
			var his: int = scores["kreso"]
			if mine > his:
				last_text = "You win, %d to %d!\n%s: \"The board is crooked. I'll fix it tomorrow. Don't tell anyone.\"" % [mine, his, opponent]
			elif his > mine:
				last_text = "%s wins, %d to %d.\n%s: \"Skill. Pure skill. That's a beer you owe me.\"" % [opponent, his, mine, opponent]
			else:
				last_text = "A draw at %d.\n%s: \"A draw. Suspicious. Who sent you?\"" % [mine, opponent]
			return
		turn = "player"
		turn_darts.clear()

func _kreso_throw() -> void:
	# Krešo goes for the treble 20; now and then the dart slips.
	var target := CENTER + Vector2(0, -(TREBLE_IN + TREBLE_OUT) * 0.5 * MM)
	var spread := KRESO_SPREAD * (2.2 if rng.randf() < 0.15 else 1.0)
	throw_at(target + Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread)))

# ---------- drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.05, 0.04, 0.09, 0.92))
	draw_rect(Rect2(CENTER - Vector2(150, 150), Vector2(300, 300)), Color("4e2c20"))
	draw_rect(Rect2(CENTER - Vector2(150, 150), Vector2(300, 300)), Color("2a1812"), false, 3.0)
	draw_circle(CENTER, BOARD_RADIUS + 14, BLACK)
	for i in 20:
		var a0 := deg_to_rad(i * 18.0 - 9.0 - 90.0)
		var a1 := a0 + deg_to_rad(18.0)
		var dark := i % 2 == 0
		_ring_sector(OUTER_BULL, TREBLE_IN, a0, a1, BLACK if dark else SISAL)
		_ring_sector(TREBLE_IN, TREBLE_OUT, a0, a1, RED if dark else GREEN)
		_ring_sector(TREBLE_OUT, DOUBLE_IN, a0, a1, BLACK if dark else SISAL)
		_ring_sector(DOUBLE_IN, DOUBLE_OUT, a0, a1, RED if dark else GREEN)
		var mid := (a0 + a1) * 0.5
		var label_at := CENTER + Vector2(cos(mid), sin(mid)) * (BOARD_RADIUS + 8) - Vector2(6, -4)
		draw_string(get_theme_default_font(), label_at, str(NUMBERS[i]), HORIZONTAL_ALIGNMENT_CENTER, 12, 9, CREAM)
	draw_circle(CENTER, OUTER_BULL * MM, GREEN)
	draw_circle(CENTER, BULL * MM, RED)
	for dart: Dictionary in turn_darts:
		var at: Vector2 = dart["at"]
		var mine: bool = dart["who"] == "player"
		draw_line(at, at + Vector2(9, 5), Color("d9d4c7"), 2.0)
		draw_rect(Rect2(at + Vector2(8, 3), Vector2(4, 4)), GOLD if mine else Color("6fb7ff"))
		draw_circle(at, 1.5, INK)
	if turn == "player":
		var s := sight()
		draw_arc(s, 7, 0, TAU, 20, CREAM, 1.0)
		draw_line(s - Vector2(11, 0), s - Vector2(4, 0), CREAM)
		draw_line(s + Vector2(4, 0), s + Vector2(11, 0), CREAM)
		draw_line(s - Vector2(0, 11), s - Vector2(0, 4), CREAM)
		draw_line(s + Vector2(0, 4), s + Vector2(0, 11), CREAM)
	_draw_panel()

func _ring_sector(r0: float, r1: float, a0: float, a1: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 6
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		points.append(CENTER + Vector2(cos(a), sin(a)) * r1 * MM)
	for k in range(steps, -1, -1):
		var a := lerpf(a0, a1, float(k) / steps)
		points.append(CENTER + Vector2(cos(a), sin(a)) * r0 * MM)
	draw_colored_polygon(points, color)

func _draw_panel() -> void:
	var font := get_theme_default_font()
	var x := 400.0
	draw_rect(Rect2(x - 12, 40, 236, 290), Color("23202c"))
	draw_rect(Rect2(x - 12, 40, 236, 290), Color("766449"), false, 1.0)
	draw_string(font, Vector2(x, 66), "DARTS AT SMOKVA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	draw_string(font, Vector2(x, 90), "Round %d of %d" % [mini(round_number, ROUNDS), ROUNDS], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	draw_string(font, Vector2(x, 122), "You", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	draw_string(font, Vector2(x + 140, 122), str(scores["player"]), HORIZONTAL_ALIGNMENT_RIGHT, 60, 13, CREAM)
	draw_string(font, Vector2(x, 144), opponent, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6fb7ff"))
	draw_string(font, Vector2(x + 140, 144), str(scores["kreso"]), HORIZONTAL_ALIGNMENT_RIGHT, 60, 13, CREAM)
	var whose := "Your throw: dart %d of %d" % [darts_thrown + 1, DARTS_PER_TURN] if turn == "player" else ("%s is throwing..." % opponent if turn == "kreso" else "Game over")
	draw_string(font, Vector2(x, 176), whose, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CREAM)
	draw_multiline_string(font, Vector2(x, 200), last_text, HORIZONTAL_ALIGNMENT_LEFT, 212, 11, -1, CREAM)
	var help := "Space: play again   Esc: leave" if turn == "over" else "Arrows / WASD: steady the aim\nSpace: throw   Esc: leave"
	draw_multiline_string(font, Vector2(x, 290), help, HORIZONTAL_ALIGNMENT_LEFT, 212, 10, -1, MUTED)
