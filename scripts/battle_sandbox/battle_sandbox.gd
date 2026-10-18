extends Node2D
## A standalone battle of two armies, separate from the rest of the game.
## Each side fights in blocks: spearmen in the centre, swordsmen on both wings and
## archers at the back. A block keeps its shape the way "follow in formation" does
## in the sandbox: every soldier has an offset from the block's leader point,
## made by SandboxFormationPlanner.make_follow_offsets, and the whole block turns
## and advances together. Losses lower a block's morale; a broken block runs away.
## Run it with: godot --path . res://scenes/battle_sandbox.tscn
## Controls: arrows/WASD pan, mouse wheel zoom, Space pause, R restart, 1-3 speed.

const FIELD := Vector2(1400, 760)
const BODY := preload("res://assets/art/player_plain.png")
const TEAM_COLORS := [Color("4f83cf"), Color("cf4f55")]
const TEAM_NAMES := ["Confederation", "Republic"]
const KINDS := {
	"spear": {"hp": 34, "damage": 10, "reach": 22.0, "cooldown": 1.0, "speed": 30.0, "armor": 2, "engage": 30.0, "leash": 10.0},
	"sword": {"hp": 30, "damage": 9, "reach": 13.0, "cooldown": 0.75, "speed": 40.0, "armor": 3, "engage": 45.0, "leash": 40.0},
	"archer": {"hp": 20, "damage": 7, "reach": 200.0, "cooldown": 1.7, "speed": 34.0, "armor": 0, "engage": 200.0, "leash": 0.0},
}
## Blocks per side: kind, soldiers, files (soldiers per rank), lateral and rear position
## of the block centre relative to the army's front centre.
const ARMY := [
	["spear", 40, 20, 0.0, 0.0],
	["sword", 15, 5, -170.0, 10.0],
	["sword", 15, 5, 170.0, 10.0],
	["archer", 30, 15, 0.0, 85.0],
]
const FILE_SPACING := 11.0
const RANK_SPACING := 12.0
const RETARGET_TIME := 0.4
const ARROW_SPEED := 260.0
const TURN_RATE := 0.35  # radians per second a block can wheel
const OPENING_VOLLEYS := 4.0  # seconds the melee blocks wait while archers shoot
const BREAK_MORALE := 30.0

var units: Array[Dictionary] = []
var blocks: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var corpses: Array[Dictionary] = []
var camera: Camera2D
var label: Label
var speed := 1.0
var paused := false
var winner := -1
var clock := 0.0

func _ready() -> void:
	camera = Camera2D.new()
	camera.position = FIELD * 0.5
	camera.zoom = Vector2(0.48, 0.48)
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)
	_spawn()

func _spawn() -> void:
	units.clear()
	blocks.clear()
	arrows.clear()
	corpses.clear()
	winner = -1
	clock = 0.0
	for team in 2:
		var heading := Vector2.RIGHT if team == 0 else Vector2.LEFT
		var lateral := heading.orthogonal()
		var front := FIELD * 0.5 - heading * 260.0
		for entry in ARMY:
			_spawn_block(team, entry, front, heading, lateral)

func _spawn_block(team: int, entry: Array, front: Vector2, heading: Vector2, lateral: Vector2) -> void:
	var kind: String = entry[0]
	var count: int = entry[1]
	var files: int = entry[2]
	var centre: Vector2 = front + lateral * float(entry[3]) * (1.0 if team == 0 else -1.0) - heading * float(entry[4])
	var block_index := blocks.size()
	var ids: Array[String] = []
	var places := {}
	var first := units.size()
	for i in count:
		var file := i % files
		var rank := i / files
		var place := centre + lateral * (file - (files - 1) * 0.5) * FILE_SPACING - heading * rank * RANK_SPACING
		var id := "u%d" % units.size()
		ids.append(id)
		places[id] = place
		var stats: Dictionary = KINDS[kind]
		units.append({
			"id": id, "team": team, "kind": kind, "block": block_index, "pos": place,
			"offset": Vector2.ZERO, "hp": stats["hp"], "alive": true, "fled": false,
			"cooldown": randf_range(0.0, stats["cooldown"]), "target": -1,
			"retarget": randf_range(0.0, RETARGET_TIME), "swing": 0.0, "facing": heading.x,
		})
	# The sandbox's follow formation keeps a line's shape: each soldier gets an
	# offset (sideways, behind) from the leader point.
	var offsets := SandboxFormationPlanner.make_follow_offsets(ids, places, heading)
	for i in count:
		units[first + i]["offset"] = offsets[ids[i]]
	var sample: Dictionary = units[first]
	var leader: Vector2 = sample["pos"] - lateral * sample["offset"].x + heading * sample["offset"].y
	blocks.append({
		"team": team, "kind": kind, "leader": leader, "heading": heading,
		"members": range(first, first + count), "start": count, "morale": 100.0,
		"broken": false, "engaged": false,
	})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: paused = not paused
			KEY_R: _spawn()
			KEY_1: speed = 1.0
			KEY_2: speed = 2.0
			KEY_3: speed = 4.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.3, 0.3), Vector2(4, 4))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.3, 0.3), Vector2(4, 4))

func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): pan.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): pan.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): pan.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): pan.y += 1
	camera.position += pan * 400.0 * delta / camera.zoom.x
	if not paused:
		simulate(minf(delta, 0.05) * speed)
	_update_label()
	queue_redraw()

func simulate(dt: float) -> void:
	clock += dt
	for b in blocks.size():
		_steer_block(b, dt)
	for i in units.size():
		_step_unit(i, dt)
	_separate()
	_fly_arrows(dt)
	_check_winner()

# --- blocks ---------------------------------------------------------------

func _slot(u: Dictionary) -> Vector2:
	var block: Dictionary = blocks[u["block"]]
	var heading: Vector2 = block["heading"]
	return block["leader"] + heading.orthogonal() * u["offset"].x - heading * u["offset"].y

func _centre(b: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for i in blocks[b]["members"]:
		if units[i]["alive"]:
			sum += units[i]["pos"]
			n += 1
	return sum / n if n > 0 else blocks[b]["leader"]

func _living(b: int) -> int:
	var n := 0
	for i in blocks[b]["members"]:
		if units[i]["alive"]:
			n += 1
	return n

func _steer_block(b: int, dt: float) -> void:
	var block: Dictionary = blocks[b]
	if block["broken"] or _living(b) == 0:
		return
	if not block["engaged"]:
		block["morale"] = minf(100.0, block["morale"] + 1.5 * dt)
	var centre := _centre(b)
	var enemy := _nearest_enemy_to(centre, block["team"])
	if enemy < 0:
		return
	var enemy_pos: Vector2 = units[enemy]["pos"]
	var distance := centre.distance_to(enemy_pos)
	block["engaged"] = distance < 45.0
	# wheel the whole block toward the nearest enemy, a little at a time
	var heading: Vector2 = block["heading"]
	var wanted := heading.angle_to(enemy_pos - centre)
	var turn := clampf(wanted, -TURN_RATE * dt, TURN_RATE * dt)
	if absf(wanted) > 0.15:
		# rotate around the block's centre so the soldiers don't swing around the leader point
		block["leader"] = centre + (block["leader"] - centre).rotated(turn)
		block["heading"] = heading.rotated(turn)
	var stats: Dictionary = KINDS[block["kind"]]
	var advance := 0.0
	match block["kind"]:
		"archer":
			if distance > stats["reach"] * 0.9:
				advance = 1.0
			elif distance < 120.0:
				advance = -1.0
		"spear":
			if clock > OPENING_VOLLEYS and distance > 26.0:
				advance = 1.0
		"sword":
			if clock > OPENING_VOLLEYS + 1.0 and distance > 18.0:
				advance = 1.0
	# a block whose soldiers fall behind their places waits for them
	if advance > 0.0 and _spread(b) > 10.0:
		advance *= 0.3
	block["leader"] += block["heading"] * advance * stats["speed"] * 0.8 * dt

func _spread(b: int) -> float:
	var total := 0.0
	var n := 0
	for i in blocks[b]["members"]:
		var u: Dictionary = units[i]
		if u["alive"] and u["target"] < 0:
			total += u["pos"].distance_to(_slot(u))
			n += 1
	return total / n if n > 0 else 0.0

func _lose_morale(b: int, amount: float) -> void:
	var block: Dictionary = blocks[b]
	if block["broken"]:
		return
	block["morale"] -= amount
	if block["morale"] < BREAK_MORALE:
		block["broken"] = true
		# a block running away shakes the rest of its army and heartens the enemy
		for other in blocks.size():
			if other != b and not blocks[other]["broken"]:
				if blocks[other]["team"] == block["team"]:
					_lose_morale(other, 18.0)
				else:
					blocks[other]["morale"] = minf(100.0, blocks[other]["morale"] + 10.0)

# --- soldiers -------------------------------------------------------------

func _step_unit(i: int, dt: float) -> void:
	var u: Dictionary = units[i]
	if not u["alive"]:
		return
	var block: Dictionary = blocks[u["block"]]
	var stats: Dictionary = KINDS[u["kind"]]
	u["cooldown"] = maxf(0.0, u["cooldown"] - dt)
	u["swing"] = maxf(0.0, u["swing"] - dt)
	if block["broken"]:
		var home := Vector2.LEFT if u["team"] == 0 else Vector2.RIGHT
		u["pos"] += (home + Vector2(0, randf_range(-0.3, 0.3))) * stats["speed"] * 1.3 * dt
		u["facing"] = home.x
		if u["pos"].x < -10.0 or u["pos"].x > FIELD.x + 10.0:
			u["alive"] = false
			u["fled"] = true
		return
	u["retarget"] -= dt
	if u["retarget"] <= 0.0:
		u["retarget"] = RETARGET_TIME
		u["target"] = -1
		var nearest := _nearest_enemy_to(u["pos"], u["team"])
		var slot := _slot(u)
		if nearest >= 0 and units[nearest]["pos"].distance_to(u["pos"]) <= stats["engage"] \
				and (u["kind"] == "archer" or units[nearest]["pos"].distance_to(slot) <= stats["engage"] + stats["leash"]):
			u["target"] = nearest
	var target: int = u["target"]
	if target >= 0 and not units[target]["alive"]:
		target = -1
		u["target"] = -1
	var goal := _slot(u)
	if target >= 0:
		var to_target: Vector2 = units[target]["pos"] - u["pos"]
		u["facing"] = signf(to_target.x) if absf(to_target.x) > 1.0 else u["facing"]
		var distance := to_target.length()
		if u["kind"] != "archer" and distance > stats["reach"] * 0.85:
			goal = units[target]["pos"]
		if distance <= stats["reach"] and u["cooldown"] <= 0.0:
			_attack(i, target)
	else:
		u["facing"] = signf(block["heading"].x) if absf(block["heading"].x) > 0.1 else u["facing"]
	var to_goal: Vector2 = goal - u["pos"]
	if to_goal.length() > 1.5:
		# soldiers behind their place hurry a little to close up the ranks
		var hurry := 1.4 if target < 0 and to_goal.length() > 8.0 else 1.0
		u["pos"] += to_goal.normalized() * minf(to_goal.length(), stats["speed"] * hurry * dt)

func _attack(i: int, target: int) -> void:
	var u: Dictionary = units[i]
	var stats: Dictionary = KINDS[u["kind"]]
	u["cooldown"] = stats["cooldown"] * randf_range(0.85, 1.15)
	if u["kind"] == "archer":
		var aim: Vector2 = units[target]["pos"] + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		arrows.append({"from": u["pos"] + Vector2(0, -12), "to": aim, "t": 0.0,
			"time": u["pos"].distance_to(aim) / ARROW_SPEED, "team": u["team"], "damage": stats["damage"]})
	else:
		u["swing"] = 0.18
		_hit(target, stats["damage"])

func _nearest_enemy_to(point: Vector2, team: int) -> int:
	var best := -1
	var best_d := INF
	for j in units.size():
		var other: Dictionary = units[j]
		if other["alive"] and other["team"] != team:
			var d: float = point.distance_squared_to(other["pos"])
			if blocks[other["block"]]["broken"]:
				d *= 4.0  # chase runners only when no one is still fighting nearby
			if d < best_d:
				best_d = d
				best = j
	return best

func _hit(index: int, damage: int) -> void:
	var u: Dictionary = units[index]
	if not u["alive"]:
		return
	u["hp"] -= maxi(1, damage - int(KINDS[u["kind"]]["armor"]))
	if u["hp"] <= 0:
		u["alive"] = false
		corpses.append({"pos": u["pos"], "team": u["team"]})
		var b: int = u["block"]
		_lose_morale(b, 120.0 / blocks[b]["start"])

func _separate() -> void:
	# Push overlapping soldiers apart, using a coarse grid so only neighbours are compared.
	var cell := 12.0
	var grid := {}
	for i in units.size():
		if units[i]["alive"]:
			var key := Vector2i(units[i]["pos"] / cell)
			if not grid.has(key):
				grid[key] = []
			grid[key].append(i)
	for i in units.size():
		var u: Dictionary = units[i]
		if not u["alive"]:
			continue
		var key := Vector2i(u["pos"] / cell)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for j in grid.get(key + Vector2i(dx, dy), []):
					if j <= i:
						continue
					var offset: Vector2 = units[j]["pos"] - u["pos"]
					var d := offset.length()
					if d < 9.0:
						var push := (offset / d) * (9.0 - d) * 0.5 if d > 0.01 else Vector2(randf_range(-1, 1), randf_range(-1, 1))
						u["pos"] -= push
						units[j]["pos"] += push
		if not blocks[u["block"]]["broken"]:
			u["pos"] = u["pos"].clamp(Vector2(8, 24), FIELD - Vector2(8, 4))

func _fly_arrows(dt: float) -> void:
	for arrow in arrows:
		arrow["t"] += dt
	var landed := arrows.filter(func(a): return a["t"] >= a["time"])
	arrows = arrows.filter(func(a): return a["t"] < a["time"])
	for arrow in landed:
		for j in units.size():
			var u: Dictionary = units[j]
			if u["alive"] and u["team"] != arrow["team"] and u["pos"].distance_to(arrow["to"]) < 8.0:
				_hit(j, arrow["damage"])
				break

func _check_winner() -> void:
	if winner >= 0:
		return
	var fighting := fighting_counts()
	if fighting[0] == 0 or fighting[1] == 0:
		winner = 0 if fighting[0] > 0 else 1

## Soldiers still in the fight: alive and in a block that hasn't broken.
func fighting_counts() -> Array:
	var counts := [0, 0]
	for u in units:
		if u["alive"] and not blocks[u["block"]]["broken"]:
			counts[u["team"]] += 1
	return counts

func _update_label() -> void:
	var lines := []
	for team in 2:
		var parts := []
		for b in blocks.size():
			var block: Dictionary = blocks[b]
			if block["team"] == team:
				var state := "RUNNING" if block["broken"] else "morale %d" % int(block["morale"])
				parts.append("%s %d (%s)" % [block["kind"], _living(b), state])
		lines.append("%s: %s" % [TEAM_NAMES[team], ", ".join(parts)])
	if winner >= 0:
		lines.append("%s holds the field. R to restart" % TEAM_NAMES[winner])
	lines.append("Space pause%s · 1-3 speed (x%d) · R restart · arrows pan · wheel zoom" % [" (PAUSED)" if paused else "", int(speed)])
	label.text = "\n".join(lines)

func _draw() -> void:
	draw_rect(Rect2(Vector2(-400, -400), FIELD + Vector2(800, 800)), Color("6f9c5e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 500:
		var p := Vector2(rng.randf() * FIELD.x, rng.randf() * FIELD.y)
		draw_rect(Rect2(p, Vector2(2, 1)), Color("8db574"))
	for c in corpses:
		draw_rect(Rect2(c["pos"] + Vector2(-7, -4), Vector2(14, 5)), TEAM_COLORS[c["team"]].darkened(0.45))
	var order := []
	for i in units.size():
		if units[i]["alive"]:
			order.append(i)
	order.sort_custom(func(a, b): return units[a]["pos"].y < units[b]["pos"].y)
	for i in order:
		_draw_unit(units[i])
	for b in blocks.size():
		if not blocks[b]["broken"] and _living(b) > 0:
			var foot := _centre(b) + Vector2(0, -24)
			draw_line(foot, foot + Vector2(0, -20), Color("5a4026"), 1.0)
			draw_rect(Rect2(foot + Vector2(0, -20), Vector2(10, 7)), TEAM_COLORS[blocks[b]["team"]].lightened(0.2))
	for arrow in arrows:
		var k: float = arrow["t"] / arrow["time"]
		var p: Vector2 = arrow["from"].lerp(arrow["to"], k) + Vector2(0, -sin(k * PI) * 30.0)
		var dir: Vector2 = (arrow["to"] - arrow["from"]).normalized()
		draw_line(p - dir * 5.0, p + dir * 2.0, Color("3a2a1a"), 1.0)

func _draw_unit(u: Dictionary) -> void:
	var broken: bool = blocks[u["block"]]["broken"]
	var team_color: Color = TEAM_COLORS[u["team"]]
	if broken:
		team_color = team_color.lerp(Color.WHITE, 0.4)
	var pos: Vector2 = u["pos"]
	var facing: float = u["facing"]
	draw_set_transform(pos + Vector2(-8.0 * facing, -22), 0.0, Vector2(facing, 1))
	draw_texture(BODY, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	# team tunic and helmet so both armies read at a glance
	draw_rect(Rect2(pos + Vector2(-5, -13), Vector2(10, 7)), team_color)
	draw_rect(Rect2(pos + Vector2(-4, -23), Vector2(8, 3)), team_color.darkened(0.3))
	if broken:
		return  # weapons dropped
	var hand := pos + Vector2(5 * facing, -10)
	var swinging: bool = u["swing"] > 0.0
	match u["kind"]:
		"spear":
			var tip := hand + Vector2(18 * facing, -10 + (8 if swinging else 0))
			draw_line(hand, tip, Color("8a6a40"), 1.0)
			draw_line(tip, tip + (tip - hand).normalized() * 3, Color("d7e6ea"), 2.0)
		"sword":
			var angle := 0.6 if swinging else -1.0
			draw_line(hand, hand + Vector2(cos(angle) * 9 * facing, sin(angle) * 9), Color("d7e6ea"), 2.0)
		"archer":
			var start := -PI * 0.5 if facing > 0 else PI * 0.5
			draw_arc(hand + Vector2(2 * facing, 0), 6.0, start, start + PI, 8, Color("8a6a40"), 1.0)
	var hp_ratio := float(u["hp"]) / float(KINDS[u["kind"]]["hp"])
	if hp_ratio < 1.0:
		draw_rect(Rect2(pos + Vector2(-6, -27), Vector2(12, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(pos + Vector2(-6, -27), Vector2(12 * hp_ratio, 2)), Color("f5c34c"))
