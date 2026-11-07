class_name ShipBattle
extends Control

## A ship battle in space, seen from above, in the style of the sea battles in
## Sid Meier's Pirates!: the player steers a ship (`player_id`, the Lasta
## unless set) and fires TNT from its sides. The arrow keys (or WASD) turn and speed up or slow down; Q fires the
## left side, E the right side, and Space whichever side faces the enemy. Each
## side reloads on its own. A ship's nose and tail have no launchers, so the
## fight is about turning a side to the enemy before it does the same to you.
##
## A dust current crosses the arena: inside it every ship drifts along it, so
## flying with it is faster than flying against it.
##
## The enemy ship and its weapons come from GameData.SHIPS (`enemy_id`):
## - The Purple Parrots keep off the Lasta's nose or tail, out of her side
##   wedges, fire pairs of aimed light bolts when they face her, and up close
##   glow their lamps and let out a spiralling ring of bolts. At their flee
##   share they run along the current and get away; they cannot be sunk, and
##   the battle is won when they leave the arena.
## - The scrap thieves come straight at the Lasta, throw sprays of scrap when
##   they face her, and their claw tears plates off her when the ships touch.
##   At 0 hull their engine dies, they drift, and the battle is won.
## - The hackers who attack the Council's diplomatic ship keep off its nose or
##   tail and fire teal bolts, and from "harpoon_first" seconds on they fire a
##   harpoon on a cable whenever they face it. The harpoon flies straight and
##   slowly, so turning away makes it miss. When it hits, or when the ships
##   touch, they are fastened to it and the battle ends "harpooned". After
##   "close_in_after" seconds they come straight in. If their hull falls to
##   "board_share" first, their ship is wrecked but a phase hacker jumps
##   across anyway, and the battle ends "boarded". Either way they board.
## The battle is lost when the player's hull reaches 0.
##
## GameWorld.open_ship_battle() sets `enemy_id`, `player_id`, `lines` and
## `crew` and connects `finished`. The battle frees itself after emitting
## `finished` with "won", "lost", "harpooned" or "boarded".

signal finished(result: String)

const VIEW := Vector2(640, 360)
const ARENA := Rect2(0, 0, 1600, 1000)
const TNT_SPEED := 150.0
## Barrels slow down as they fly; this is the share of speed lost a second.
const TNT_DRAG := 0.55
const TNT_FUSE := 1.3
## How far a bursting barrel reaches past a ship's edge.
const TNT_BURST := 14.0
## Angle between neighbouring barrels in one broadside, in radians.
const TNT_FAN := 0.11
const BOLT_SPEED := 190.0
const BOLT_LIFE := 1.8
## How close the Parrots must be, and how directly they must face the Lasta,
## to fire aimed bolts.
const BOLT_RANGE := 280.0
const BOLT_AIM := 0.35
const RING_RANGE := 150.0
const RING_WARN_SECONDS := 0.9
const RING_BOLTS := 8
const RING_SPEED := 110.0
## How fast ring bolts curve, in radians a second; this makes the spiral.
const RING_TURN := 1.2
## Scrap sprays: how directly the thieves must face the Lasta to throw, the
## half-angle of the fan in radians, and the pieces' mean speed.
const SCRAP_AIM := 0.5
const SCRAP_SPREAD := 0.35
const SCRAP_SPEED := 150.0
const RAM_DAMAGE := 4
const RAM_COOLDOWN := 0.8
## A disabled ship's drift and spin lose this share a second.
const DRIFT_DECAY := 0.5
const FLEE_SPEED_SCALE := 1.4
## Seconds a fleeing ship takes at most to get away, even if it is cornered.
const FLEE_SECONDS := 10.0
const RADIO_SECONDS := 3.5
const SIDE_HINT_SECONDS := 9.0
## Seconds the end banner shows before `finished`.
const END_SECONDS := 2.5
const DUST_COUNT := 260
## How directly the hackers must face the player's ship to fire the harpoon.
const HARPOON_AIM := 0.3
## A harpoon flies this many times its range before it counts as a miss.
const HARPOON_REACH := 1.4
## How fast a harpooned ship is reeled in, in battle pixels a second.
const HARPOON_PULL := 40.0
const PHASE_SECONDS := 0.8
## The states in which the battle is over and only the end banner plays.
const END_STATES := ["won", "lost", "harpooned", "boarded"]

const INK := Color("1c1730")
const SPACE := Color("110f26")
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const MUTED := Color("b6adbf")
const RED := Color("c8352c")
const GREEN := Color("5c9a5a")
const PURPLE := Color("8a4fd0")
const LAVENDER := Color("b49be8")
const BOLT := Color("fff2a8")
const SCRAP_GREY := Color("a8a4a0")
const SCRAP_RUST := Color("8a4a2c")
const CABLE := Color("9696a8")
const PHASE := Color("5fd6d3")

## Radio lines by event, each a list of [speaker, text]. Events: "start",
## "side_open" ({side} becomes "left (Q)" or "right (E)"), "hit", "low",
## "flee", "harpoon" (each time one is fired, when the radio is free),
## "harpoon_miss", "won", "lost", "harpooned", "boarded".
var lines: Dictionary = {}
## Names shown in the HUD for the crew.
var crew: Array = ["You", "Veki", "Donat"]
## The enemy ship in GameData.SHIPS.
var enemy_id := "parrot_ship"
## The player's ship in GameData.SHIPS.
var player_id := "lasta"
## True once the enemy's engine is dead and it drifts.
var enemy_disabled := false

var player: BattleShip
var enemy: BattleShip
var enemy_definition: Dictionary = {}
var player_definition: Dictionary = {}
## "fight", "flee", or one of END_STATES.
var state := "fight"
var paused := false
var camera := Vector2.ZERO
## The dust current: a band from `current_from` to `current_to`.
var current_from := Vector2(0, 860)
var current_to := Vector2(1600, 160)
var current_width := 170.0
var current_strength := 34.0
## {pos, vel, fuse, owner, damage, spin}
var tnt: Array = []
## Enemy shots: {pos, vel, life, damage, turn, kind}; kind is "bolt" or
## "scrap", and scrap pieces also have a "spin" angle for drawing.
var bolts: Array = []
## {pos, time, size}
var bursts: Array = []
## Smoke left behind the fleeing ship: {pos, time}.
var smoke: Array = []
## The harpoon in flight, {pos, vel, life}; empty when there is none.
var harpoon: Dictionary = {}
var harpoon_wait := 0.0
## Teal flashes where a phase hacker leaves and lands: {pos, time}.
var phase_flashes: Array = []
var radio_line: Array = []
var radio_time := 0.0
var _radio_queue: Array = []
var bolt_wait := 1.5
var ring_wait := 4.0
var ring_warning := 0.0
var scrap_wait := 1.0
## Spin of the disabled enemy, in radians a second.
var _drift_spin := 0.0
var _ram_wait := 0.0
var _flee_time := 0.0
var _end_time := 0.0
var _side_hint_wait := 2.0
var _smoke_wait := 0.0
var _said: Dictionary = {}
var _dust: Array = []
var _stars: Array = []
var _time := 0.0
var rng := RandomNumberGenerator.new()

static func ensure_input_actions() -> void:
	for pair in [["ship_fire_left", KEY_Q], ["ship_fire_right", KEY_E]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		if InputMap.action_get_events(pair[0]).is_empty():
			var key := InputEventKey.new()
			key.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], key)

func _ready() -> void:
	add_to_group("ui_modal")
	add_to_group("ship_battle")
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_input_actions()
	rng.seed = 7
	for i in 140:
		_stars.append([Vector2(rng.randf() * VIEW.x, rng.randf() * VIEW.y), rng.randf_range(0.2, 0.6), rng.randf() < 0.15])
	for i in DUST_COUNT:
		_dust.append([rng.randf(), rng.randf_range(-0.5, 0.5), rng.randf_range(0.6, 1.4)])
	rng.randomize()
	if player == null:
		start(enemy_id)

## Places the player's ship and the enemy ship and starts the radio.
func start(ship_id: String = "parrot_ship") -> void:
	enemy_id = ship_id
	player_definition = GameData.ship(player_id)
	player = BattleShip.new(player_id, Vector2(420, 620), -0.35)
	player.speed = player.max_speed * 0.5
	enemy = BattleShip.new(enemy_id, Vector2(980, 330), PI * 0.85)
	enemy.speed = enemy.max_speed * 0.6
	enemy_definition = GameData.ship(enemy_id)
	enemy_disabled = false
	state = "fight"
	_time = 0.0
	tnt.clear()
	bolts.clear()
	bursts.clear()
	smoke.clear()
	harpoon.clear()
	phase_flashes.clear()
	harpoon_wait = float(enemy_definition.get("harpoon_first", 0.0))
	_said.clear()
	_follow_camera()
	_say("start")

func _process(delta: float) -> void:
	if not paused:
		step(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		paused = not paused
	elif paused:
		pass
	elif event.is_action_pressed("ship_fire_left"):
		fire("left")
	elif event.is_action_pressed("ship_fire_right"):
		fire("right")
	elif event.is_action_pressed("attack"):
		fire(side_toward_enemy())
	elif event is InputEventKey and (event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_up") or event.is_action("move_down")):
		# Steering is read in step(); keep the keys from reaching the HUD.
		pass
	elif event.is_action_pressed("inventory") or event.is_action_pressed("jobs") or event.is_action_pressed("encyclopedia") or event.is_action_pressed("planet_map") or event.is_action_pressed("order_type") or event.is_action_pressed("order_follow"):
		pass
	else:
		return
	get_viewport().set_input_as_handled()

## Advances the battle by `delta` seconds.
func step(delta: float) -> void:
	_time += delta
	if is_over():
		_end_time += delta
		if enemy_disabled:
			_drift(delta)
		elif state == "harpooned":
			_reel_in(delta)
		_tick_effects(delta)
		_tick_radio(delta)
		if _end_time >= END_SECONDS:
			_finish()
		return
	var steer := Input.get_axis("move_left", "move_right")
	var throttle := Input.get_axis("move_down", "move_up")
	player.steer_and_move(steer, throttle, current_at(player.position), delta)
	_keep_in_arena(player)
	_enemy_turn(delta)
	_ram(delta)
	_tick_tnt(delta)
	_tick_bolts(delta)
	_tick_harpoon(delta)
	_tick_effects(delta)
	_side_hint(delta)
	_tick_radio(delta)
	_follow_camera()
	if player.sunk() and not is_over():
		_end("lost")

func is_over() -> bool:
	return state in END_STATES

# ---------- the current ----------

func current_direction() -> Vector2:
	return (current_to - current_from).normalized()

## Distance from `point` to the middle line of the current.
func distance_to_current(point: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, current_from, current_to))

## The current's push at `point`: strongest in the middle, gone at the edges.
func current_at(point: Vector2) -> Vector2:
	var half := current_width / 2.0
	var distance := distance_to_current(point)
	if distance >= half:
		return Vector2.ZERO
	return current_direction() * current_strength * (1.0 - 0.5 * pow(distance / half, 2.0))

# ---------- the player's guns ----------

## Fires every launcher on `side` if it is loaded. Returns true when it fired.
func fire(side: String) -> bool:
	if not (state == "fight" or state == "flee") or side == "" or not player.ready_to_fire(side):
		return false
	var points := player.launcher_points(side)
	for i in points.size():
		var spread := (float(i) - float(points.size() - 1) / 2.0) * TNT_FAN * (-1.0 if side == "left" else 1.0)
		var direction := player.side_direction(side).rotated(spread)
		tnt.append({"pos": points[i], "vel": direction * TNT_SPEED + player.forward() * player.speed + player.drift,
			"fuse": TNT_FUSE + rng.randf_range(-0.08, 0.08), "owner": player, "damage": player.tnt_damage, "spin": rng.randf_range(-6.0, 6.0), "angle": player.heading})
	player.reload[side] = player.reload_seconds
	return true

## The side facing the enemy, or the loaded side nearer to it when the enemy
## is off the nose or tail.
func side_toward_enemy() -> String:
	var side := player.side_facing(enemy.position)
	if side != "":
		return side
	var cross := player.forward().cross(enemy.position - player.position)
	side = "right" if cross > 0.0 else "left"
	return side

func _tick_tnt(delta: float) -> void:
	for barrel: Dictionary in tnt.duplicate():
		barrel["pos"] += barrel["vel"] * delta
		barrel["vel"] *= maxf(0.0, 1.0 - TNT_DRAG * delta)
		barrel["fuse"] -= delta
		barrel["angle"] += barrel["spin"] * delta
		var touched := false
		for ship: BattleShip in [player, enemy]:
			if ship != barrel["owner"] and ship.position.distance_to(barrel["pos"]) <= ship.radius + 3.0:
				touched = true
		if touched or barrel["fuse"] <= 0.0:
			_burst(barrel)
			tnt.erase(barrel)

func _burst(barrel: Dictionary) -> void:
	bursts.append({"pos": barrel["pos"], "time": 0.0, "size": TNT_BURST + 6.0})
	for ship: BattleShip in [player, enemy]:
		if ship != barrel["owner"] and ship.position.distance_to(barrel["pos"]) <= ship.radius + TNT_BURST:
			_damage(ship, int(barrel["damage"]))

func _damage(ship: BattleShip, amount: int) -> void:
	if not (state == "fight" or state == "flee"):
		return
	# A ship that flees always gets away, and one whose crew boards anyway is
	# wrecked at its board share, so neither hull reaches 0.
	ship.take_hit(amount, 1 if ship == enemy and (flees() or boards()) else 0)
	if ship == enemy and boards() and enemy.hull <= enemy.max_hull * float(enemy_definition.get("board_share", 0.0)):
		_wreck_and_board()
	elif ship == enemy and enemy.sunk():
		# The engine dies: the ship keeps its last speed and starts to spin.
		enemy_disabled = true
		_drift_spin = rng.randf_range(0.8, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
		_end("won")
	elif ship == player:
		if player.hull <= player.max_hull * 0.7:
			_say("hit")
		if player.hull <= player.max_hull * 0.35:
			_say("low")

# ---------- the enemy ----------

## True when the enemy runs at its flee share instead of being disabled at 0 hull.
func flees() -> bool:
	return float(enemy_definition.get("flee_share", 0.0)) > 0.0

## True when the enemy's crew boards the player's ship once their own ship is
## wrecked at its board share.
func boards() -> bool:
	return float(enemy_definition.get("board_share", 0.0)) > 0.0

## The enemy's tactic now: "close_in" once "close_in_after" seconds have passed.
func current_tactic() -> String:
	var after := float(enemy_definition.get("close_in_after", 0.0))
	if after > 0.0 and _time >= after:
		return "close_in"
	return String(enemy_definition.get("tactic", "standoff"))

## The enemy's ship is wrecked and drifts; a phase hacker jumps from it onto
## the player's ship with a cable for the others.
func _wreck_and_board() -> void:
	enemy_disabled = true
	_drift_spin = rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	phase_flashes.append({"pos": enemy.position, "time": 0.0})
	phase_flashes.append({"pos": player.position - player.forward() * player.radius * 0.5, "time": -0.25})
	_end("boarded")

func _enemy_colour() -> Color:
	return Color(String(enemy_definition.get("colour", "b49be8")))

func _enemy_turn(delta: float) -> void:
	var to_player := player.position - enemy.position
	var distance := to_player.length()
	var desired := enemy.heading
	var throttle := 1.0
	if state == "flee":
		_flee_time += delta
		desired = current_direction().angle()
		_smoke_wait -= delta
		if _smoke_wait <= 0.0:
			_smoke_wait = 0.12
			smoke.append({"pos": enemy.position - enemy.forward() * enemy.radius, "time": 0.0})
	elif current_tactic() == "close_in":
		# Straight at the Lasta, easing off when the claw is about to touch her.
		desired = to_player.angle()
		if distance < player.radius + enemy.radius + 20.0:
			throttle = 0.4
		_enemy_guns(delta, to_player, distance)
	else:
		# Stand off the Lasta's nose or tail, whichever is nearer, out of her side wedges.
		var keep := float(enemy_definition.get("keep_distance", 150.0))
		var nose := player.position + player.forward() * keep
		var tail := player.position - player.forward() * keep
		var spot := nose if enemy.position.distance_to(nose) < enemy.position.distance_to(tail) else tail
		if enemy.position.distance_to(spot) > 50.0:
			desired = (spot - enemy.position).angle()
		else:
			desired = to_player.angle()
			throttle = 0.25
		_enemy_guns(delta, to_player, distance)
	if state == "fight" and flees() and enemy.hull <= enemy.max_hull * float(enemy_definition.get("flee_share", 0.0)):
		state = "flee"
		ring_warning = 0.0
		enemy.max_speed *= FLEE_SPEED_SCALE
		_say("flee")
	var steer := clampf(angle_difference(enemy.heading, desired) * 2.5, -1.0, 1.0)
	enemy.steer_and_move(steer, throttle, current_at(enemy.position), delta)
	if state == "flee":
		if not ARENA.grow(60.0).has_point(enemy.position) or _flee_time >= FLEE_SECONDS:
			_end("won")
	else:
		_keep_in_arena(enemy)

## Fires the enemy's weapons; each one exists only when its damage is set in
## GameData.SHIPS.
func _enemy_guns(delta: float, to_player: Vector2, distance: float) -> void:
	bolt_wait -= delta
	ring_wait -= delta
	scrap_wait -= delta
	var facing := absf(enemy.forward().angle_to(to_player))
	if enemy_definition.has("ring_damage"):
		if ring_warning > 0.0:
			ring_warning -= delta
			if ring_warning <= 0.0:
				ring_warning = 0.0
				_fire_ring()
			return
		if ring_wait <= 0.0 and distance <= RING_RANGE:
			ring_warning = RING_WARN_SECONDS
			return
	if enemy_definition.has("bolt_damage") and bolt_wait <= 0.0 and distance <= BOLT_RANGE and facing <= BOLT_AIM:
		bolt_wait = float(enemy_definition.get("bolt_cooldown", 2.6))
		# Aim a little ahead of where the Lasta is going.
		var lead := (player.forward() * player.speed + player.drift) * (distance / BOLT_SPEED) * 0.6
		var aim := (player.position + lead - enemy.position).normalized()
		for spread in [-0.06, 0.06]:
			bolts.append({"pos": enemy.position + enemy.forward() * enemy.radius, "vel": aim.rotated(spread) * BOLT_SPEED,
				"life": BOLT_LIFE, "damage": int(enemy_definition["bolt_damage"]), "turn": 0.0, "kind": "bolt"})
	if enemy_definition.has("scrap_damage") and scrap_wait <= 0.0 and distance <= float(enemy_definition.get("scrap_range", 140.0)) and facing <= SCRAP_AIM:
		_fire_scrap()
	if enemy_definition.has("harpoon_speed"):
		harpoon_wait -= delta
		if harpoon.is_empty() and harpoon_wait <= 0.0 and distance <= float(enemy_definition.get("harpoon_range", 160.0)) and facing <= HARPOON_AIM:
			_fire_harpoon(to_player)

## Fires the harpoon straight at where the player's ship is now, without
## leading it, so a ship that turns away makes it miss.
func _fire_harpoon(to_player: Vector2) -> void:
	harpoon_wait = float(enemy_definition.get("harpoon_cooldown", 8.0))
	var speed := float(enemy_definition.get("harpoon_speed", 130.0))
	harpoon = {"pos": enemy.position + enemy.forward() * enemy.radius, "vel": to_player.normalized() * speed,
		"life": float(enemy_definition.get("harpoon_range", 160.0)) * HARPOON_REACH / speed}
	if _radio_queue.is_empty():
		_say("harpoon", false)

func _tick_harpoon(delta: float) -> void:
	if harpoon.is_empty():
		return
	harpoon["pos"] += harpoon["vel"] * delta
	harpoon["life"] -= delta
	if player.position.distance_to(harpoon["pos"]) <= player.radius + 2.0:
		harpoon.clear()
		_end("harpooned")
	elif harpoon["life"] <= 0.0:
		harpoon.clear()
		_say("harpoon_miss")

## The harpooned ship is reeled in until the two hulls touch.
func _reel_in(delta: float) -> void:
	var apart := player.position - enemy.position
	enemy.heading = apart.angle()
	if apart.length() > player.radius + enemy.radius + 2.0:
		enemy.position += apart.normalized() * minf(HARPOON_PULL * delta, apart.length() - player.radius - enemy.radius - 2.0)

func _fire_ring() -> void:
	ring_wait = float(enemy_definition.get("ring_cooldown", 7.0))
	for i in RING_BOLTS:
		var direction := Vector2.from_angle(enemy.heading + TAU * i / RING_BOLTS)
		bolts.append({"pos": enemy.position + direction * enemy.radius, "vel": direction * RING_SPEED,
			"life": BOLT_LIFE * 1.3, "damage": int(enemy_definition["ring_damage"]), "turn": RING_TURN, "kind": "bolt"})

## A spray of scrap thrown out of the hopper in the ship's nose: a fan of
## slow pieces that fall short when the Lasta is far.
func _fire_scrap() -> void:
	scrap_wait = float(enemy_definition.get("scrap_cooldown", 2.2))
	var reach := float(enemy_definition.get("scrap_range", 140.0))
	var pieces := int(enemy_definition.get("scrap_pieces", 6))
	for i in pieces:
		var direction := enemy.forward().rotated(rng.randf_range(-SCRAP_SPREAD, SCRAP_SPREAD))
		var speed := SCRAP_SPEED + rng.randf_range(-30.0, 30.0)
		bolts.append({"pos": enemy.position + enemy.forward() * enemy.radius, "vel": direction * speed + enemy.forward() * enemy.speed,
			"life": reach / speed, "damage": int(enemy_definition["scrap_damage"]), "turn": 0.0, "kind": "scrap", "spin": rng.randf() * TAU})

func _tick_bolts(delta: float) -> void:
	for bolt: Dictionary in bolts.duplicate():
		bolt["vel"] = Vector2(bolt["vel"]).rotated(float(bolt["turn"]) * delta)
		bolt["pos"] += bolt["vel"] * delta
		bolt["life"] -= delta
		if player.position.distance_to(bolt["pos"]) <= player.radius:
			_damage(player, int(bolt["damage"]))
			bursts.append({"pos": bolt["pos"], "time": 0.0, "size": 8.0})
			bolts.erase(bolt)
		elif bolt["life"] <= 0.0:
			bolts.erase(bolt)

## Ships that touch are pushed apart, and both are hurt.
func _ram(delta: float) -> void:
	_ram_wait = maxf(0.0, _ram_wait - delta)
	var apart := enemy.position - player.position
	var overlap := player.radius + enemy.radius - apart.length()
	if overlap <= 0.0:
		return
	var push := apart.normalized() if apart.length() > 0.01 else Vector2.RIGHT
	player.position -= push * overlap / 2.0
	enemy.position += push * overlap / 2.0
	if enemy_definition.has("harpoon_speed"):
		# Alongside, the hackers fasten the harpoon by hand.
		_end("harpooned")
		return
	if _ram_wait <= 0.0:
		_ram_wait = RAM_COOLDOWN
		# A claw tears plates off the Lasta; without one both ships take the ram.
		_damage(player, int(enemy_definition.get("claw_damage", RAM_DAMAGE)))
		_damage(enemy, RAM_DAMAGE)
		player.speed *= 0.5
		enemy.speed *= 0.5

func _keep_in_arena(ship: BattleShip) -> void:
	var inside := ship.position.clamp(ARENA.position + Vector2.ONE * ship.radius, ARENA.end - Vector2.ONE * ship.radius)
	if inside != ship.position:
		ship.position = inside
		ship.speed *= 0.9

## Moves the disabled enemy: it slows down and spins, trailing smoke.
func _drift(delta: float) -> void:
	var decay := maxf(0.0, 1.0 - DRIFT_DECAY * delta)
	enemy.speed *= decay
	_drift_spin *= decay
	enemy.heading += _drift_spin * delta
	enemy.position += (enemy.forward() * enemy.speed + current_at(enemy.position)) * delta
	_keep_in_arena(enemy)
	_smoke_wait -= delta
	if _smoke_wait <= 0.0:
		_smoke_wait = 0.15
		smoke.append({"pos": enemy.position + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), "time": 0.0})

func _end(result: String) -> void:
	state = result
	_end_time = 0.0
	tnt.clear()
	bolts.clear()
	harpoon.clear()
	_say(result)

func _finish() -> void:
	var result := state
	state = "over"
	finished.emit(result)
	queue_free()

# ---------- radio and hints ----------

func _say(event: String, once: bool = true) -> void:
	if once and _said.has(event):
		return
	_said[event] = true
	for line: Array in lines.get(event, []):
		_radio_queue.append(line)

func _side_hint(delta: float) -> void:
	_side_hint_wait -= delta
	if _side_hint_wait > 0.0 or state != "fight":
		return
	var side := player.side_facing(enemy.position)
	if side != "" and player.ready_to_fire(side) and player.position.distance_to(enemy.position) <= 240.0:
		_side_hint_wait = SIDE_HINT_SECONDS
		for line: Array in lines.get("side_open", []):
			_radio_queue.append([line[0], String(line[1]).replace("{side}", "left (Q)" if side == "left" else "right (E)")])

func _tick_radio(delta: float) -> void:
	radio_time -= delta
	if radio_time <= 0.0:
		radio_line = []
		if not _radio_queue.is_empty():
			radio_line = _radio_queue.pop_front()
			radio_time = RADIO_SECONDS

func _tick_effects(delta: float) -> void:
	for burst: Dictionary in bursts.duplicate():
		burst["time"] += delta
		if burst["time"] >= 0.4:
			bursts.erase(burst)
	for puff: Dictionary in smoke.duplicate():
		puff["time"] += delta
		if puff["time"] >= 2.4:
			smoke.erase(puff)
	for flash: Dictionary in phase_flashes.duplicate():
		flash["time"] += delta
		if flash["time"] >= PHASE_SECONDS:
			phase_flashes.erase(flash)

func _follow_camera() -> void:
	camera = (player.position - VIEW / 2.0).clamp(ARENA.position, ARENA.end - VIEW)

# ---------- drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), SPACE)
	_draw_stars()
	_draw_current()
	for puff: Dictionary in smoke:
		var t: float = puff["time"] / 2.4
		draw_circle(Vector2(puff["pos"]) - camera, 3.0 + 4.0 * t, Color(0.55, 0.53, 0.6, 0.7 * (1.0 - t)))
	if state == "fight" or state == "flee":
		_draw_side_wedges()
	if state == "harpooned":
		draw_line(enemy.position + enemy.forward() * enemy.radius - camera, player.position - camera, CABLE, 1.5)
	_draw_ship(enemy)
	_draw_ship(player)
	if not harpoon.is_empty():
		_draw_harpoon()
	for flash: Dictionary in phase_flashes:
		var t: float = float(flash["time"]) / PHASE_SECONDS
		if t >= 0.0:
			draw_arc(Vector2(flash["pos"]) - camera, 4.0 + 14.0 * t, 0.0, TAU, 20, Color(PHASE, 1.0 - t), 2.0)
			draw_circle(Vector2(flash["pos"]) - camera, 6.0 * (1.0 - t), Color(CREAM, 0.8 * (1.0 - t)))
	if ring_warning > 0.0:
		var glow := 1.0 - ring_warning / RING_WARN_SECONDS
		for side in ["left", "right"]:
			var lamp := enemy.position + enemy.side_direction(side) * enemy.radius * 0.9 - camera
			draw_circle(lamp, 3.0 + 5.0 * glow, Color(BOLT, 0.35 + 0.5 * glow))
	for barrel: Dictionary in tnt:
		draw_set_transform(Vector2(barrel["pos"]) - camera, float(barrel["angle"]), Vector2.ONE)
		draw_rect(Rect2(-4, -2.5, 8, 5), RED)
		draw_rect(Rect2(-4, -0.5, 8, 1), INK)
		draw_set_transform(Vector2.ZERO)
		if fmod(_time * 10.0, 1.0) < 0.5:
			draw_rect(Rect2(Vector2(barrel["pos"]) - camera + Vector2(-1, -5), Vector2(2, 2)), GOLD)
	for bolt: Dictionary in bolts:
		if bolt.get("kind", "bolt") == "scrap":
			# A tumbling bit of plate: grey with a rust edge.
			draw_set_transform(Vector2(bolt["pos"]) - camera, float(bolt["spin"]) + _time * 7.0, Vector2.ONE)
			draw_rect(Rect2(-2.5, -2, 5, 4), SCRAP_RUST)
			draw_rect(Rect2(-1.5, -1, 3, 2), SCRAP_GREY)
			draw_set_transform(Vector2.ZERO)
		else:
			var colour := _bolt_colour()
			draw_circle(Vector2(bolt["pos"]) - camera, 4.0, Color(colour, 0.25))
			draw_circle(Vector2(bolt["pos"]) - camera, 2.0, colour)
	for burst: Dictionary in bursts:
		var t: float = burst["time"] / 0.4
		draw_circle(Vector2(burst["pos"]) - camera, float(burst["size"]) * (0.4 + 0.6 * t), Color(GOLD, 0.8 * (1.0 - t)))
		draw_circle(Vector2(burst["pos"]) - camera, float(burst["size"]) * 0.5 * (1.0 - t), Color(RED, 0.9 * (1.0 - t)))
	_draw_enemy_marker()
	_draw_hud()

## The banner shown when the battle is over.
func end_banner() -> String:
	match state:
		"won", "boarded":
			return String(enemy_definition.get("beaten_text", "THEY ARE BEATEN"))
		"harpooned":
			return String(enemy_definition.get("harpoon_text", "HARPOONED"))
		"lost":
			return String(player_definition.get("lost_text", "%s CAN'T TAKE MORE" % player.display_name.to_upper()))
	return ""

func _bolt_colour() -> Color:
	return Color(String(enemy_definition["bolt_colour"])) if enemy_definition.has("bolt_colour") else BOLT

## The harpoon in flight: a slack cable back to the hackers' nose and a barbed head.
func _draw_harpoon() -> void:
	var head := Vector2(harpoon["pos"]) - camera
	var nose := enemy.position + enemy.forward() * enemy.radius - camera
	var sag := (head - nose).orthogonal().normalized() * minf(10.0, head.distance_to(nose) * 0.1)
	var cable := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		cable.append(nose.lerp(head, t) + sag * sin(t * PI))
	draw_polyline(cable, CABLE, 1.0)
	var along := Vector2(harpoon["vel"]).normalized()
	var across := along.orthogonal()
	draw_colored_polygon(PackedVector2Array([head + along * 6.0, head + across * 3.0, head - across * 3.0]), Color("6e6c78"))
	draw_line(head - along * 3.0 + across * 4.0, head, CREAM, 1.0)
	draw_line(head - along * 3.0 - across * 4.0, head, CREAM, 1.0)

func _draw_stars() -> void:
	for star: Array in _stars:
		var at: Vector2 = star[0] - camera * float(star[1])
		at = Vector2(fposmod(at.x, VIEW.x), fposmod(at.y, VIEW.y))
		draw_rect(Rect2(at, Vector2(2, 2) if star[2] else Vector2.ONE), Color(CREAM, 0.5 + 0.4 * float(star[1])))

func _draw_current() -> void:
	var direction := current_direction()
	var across := direction.orthogonal()
	var length := current_from.distance_to(current_to)
	for grain: Array in _dust:
		var along := fposmod(float(grain[0]) + _time * current_strength * 1.6 * float(grain[2]) / length, 1.0)
		var at := current_from + direction * along * length + across * float(grain[1]) * current_width - camera
		if Rect2(Vector2(-8, -8), VIEW + Vector2(16, 16)).has_point(at):
			draw_line(at, at + direction * 5.0 * float(grain[2]), Color(LAVENDER, 0.25 + 0.2 * float(grain[2])))

func _draw_side_wedges() -> void:
	for side in ["left", "right"]:
		if not player.ready_to_fire(side):
			continue
		var out := player.side_direction(side)
		for edge in [-BattleShip.SIDE_WEDGE, BattleShip.SIDE_WEDGE]:
			var ray := out.rotated(edge)
			for i in range(3, 12):
				draw_rect(Rect2(player.position + ray * (i * 11.0) - camera, Vector2.ONE), Color(GOLD, 0.5))

func _draw_ship(ship: BattleShip) -> void:
	if ship == null or ship.texture == null:
		return
	var tint := Color(1.0, 0.55, 0.55) if ship.hit_flash > 0.0 else Color.WHITE
	draw_set_transform(ship.position - camera, ship.heading, Vector2.ONE)
	draw_texture(ship.texture, -ship.texture.get_size() / 2.0, tint)
	draw_set_transform(Vector2.ZERO)

## An arrow at the edge of the screen pointing to the enemy when it is off it.
func _draw_enemy_marker() -> void:
	var at := enemy.position - camera
	if Rect2(Vector2.ZERO, VIEW).has_point(at):
		return
	var center := VIEW / 2.0
	var direction := (at - center).normalized()
	var edge := center + direction * minf(absf((VIEW.x / 2.0 - 16.0) / direction.x) if absf(direction.x) > 0.001 else INF, absf((VIEW.y / 2.0 - 16.0) / direction.y) if absf(direction.y) > 0.001 else INF)
	var side := direction.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([edge + direction * 8.0, edge + side, edge - side]), _enemy_colour())

func _panel(rect: Rect2, edge: Color) -> void:
	draw_rect(rect, Color(INK, 0.85))
	draw_rect(rect, edge, false, 1.0)

func _bar(rect: Rect2, share: float, fill: Color) -> void:
	draw_rect(rect, Color(INK))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(share, 0.0, 1.0), rect.size.y)), fill)
	draw_rect(rect, CREAM, false, 1.0)

func _text(at: Vector2, text: String, color: Color = CREAM, font_size: int = 11, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(get_theme_default_font(), at, text, align, width, font_size, color)

func _draw_hud() -> void:
	# The hull bar starts after the ship's name, so a long name widens the panel.
	var hull_label := "%s HULL" % player.display_name.to_upper()
	var bar_x := maxf(92.0, 20.0 + get_theme_default_font().get_string_size(hull_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	_panel(Rect2(8, 8, bar_x + 64.0, 52), GOLD)
	_text(Vector2(14, 21), hull_label)
	_bar(Rect2(bar_x, 13, 66, 7), float(player.hull) / player.max_hull, GREEN)
	_text(Vector2(14, 36), "CREW %d" % crew.size())
	_text(Vector2(14, 52), "LEFT")
	_bar(Rect2(42, 46, 40, 6), player.loaded_share("left"), GOLD if player.ready_to_fire("left") else RED)
	_text(Vector2(88, 52), "RIGHT")
	_bar(Rect2(126, 46, bar_x - 60.0, 6), player.loaded_share("right"), GOLD if player.ready_to_fire("right") else RED)
	var enemy_colour := _enemy_colour()
	_panel(Rect2(472, 8, 160, 30), enemy_colour)
	_text(Vector2(478, 21), ("WRECKED" if state == "boarded" else "ENGINE DEAD") if enemy_disabled else enemy.display_name.to_upper(), enemy_colour)
	_bar(Rect2(478, 26, 148, 6), float(enemy.hull) / enemy.max_hull, enemy_colour.darkened(0.25))
	_panel(Rect2(8, 334, 252, 18), GOLD)
	_text(Vector2(14, 347), "Q fire left   E fire right   SHOT: TNT")
	_panel(Rect2(540, 334, 92, 18), LAVENDER)
	_text(Vector2(546, 347), "CURRENT", LAVENDER)
	var arrow_at := Vector2(612, 343)
	var direction := current_direction()
	draw_line(arrow_at - direction * 8.0, arrow_at + direction * 8.0, LAVENDER, 1.5)
	draw_colored_polygon(PackedVector2Array([arrow_at + direction * 10.0, arrow_at + direction * 4.0 + direction.orthogonal() * 4.0, arrow_at + direction * 4.0 - direction.orthogonal() * 4.0]), LAVENDER)
	if not radio_line.is_empty():
		var speaker := String(radio_line[0])
		var line := ("%s: %s" % [speaker.to_upper(), radio_line[1]]) if speaker != "" else String(radio_line[1])
		# Lines from anyone outside the crew come from the enemy ship.
		var from_enemy := speaker != "" and not crew.has(speaker)
		_panel(Rect2(96, 300, 448, 24), enemy_colour if from_enemy else GOLD)
		_text(Vector2(96, 316), line, enemy_colour if from_enemy else CREAM, 11, HORIZONTAL_ALIGNMENT_CENTER, 448)
	if is_over():
		var banner := end_banner()
		var colour := GOLD if state == "won" or state == "boarded" else RED
		_panel(Rect2(170, 150, 300, 40), colour)
		_text(Vector2(170, 175), banner, colour, 16, HORIZONTAL_ALIGNMENT_CENTER, 300)
	if paused:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(INK, 0.6))
		_text(Vector2(0, 176), "Paused. Esc to go on.", CREAM, 16, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)
