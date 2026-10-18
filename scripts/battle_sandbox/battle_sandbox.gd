extends Node2D
## A standalone battle of two armies, separate from the rest of the game.
## Each side fights in blocks: three spear blocks in the centre, swordsmen on
## both wings, three archer blocks at the back and a small cavalry block on one wing. A block keeps its
## shape the way "follow in formation" does in the sandbox: every soldier has an
## offset from the block's leader point, made by
## SandboxFormationPlanner.make_follow_offsets, and the whole block turns and
## advances together.
## Losses lower a block's morale, and hits from the side or behind lower it much
## more; a broken block runs away. Each army has a general who sends the cavalry
## around a wing, may keep one sword block back, and pulls shaken blocks out of
## the line to recover. Hills, marshes and woods are placed anew on every restart.
## Run it with: godot --path . res://scenes/battle_sandbox.tscn
## Controls: arrows/WASD pan, mouse wheel zoom, Space pause, R restart, 1-3 speed.

const FIELD := Vector2(1600, 1000)
const BODY := preload("res://assets/art/player_plain.png")
const TEAM_COLORS := [Color("4f83cf"), Color("cf4f55")]
const TEAM_NAMES := ["Confederation", "Republic"]
const KINDS := {
	"spear": {"hp": 34, "damage": 10, "reach": 22.0, "cooldown": 1.0, "speed": 30.0, "armor": 2, "engage": 30.0, "leash": 10.0, "turn": 0.35},
	"sword": {"hp": 30, "damage": 9, "reach": 13.0, "cooldown": 0.75, "speed": 40.0, "armor": 3, "engage": 45.0, "leash": 40.0, "turn": 0.45},
	"archer": {"hp": 20, "damage": 7, "reach": 200.0, "cooldown": 1.7, "speed": 34.0, "armor": 0, "engage": 200.0, "leash": 0.0, "turn": 0.5},
	"horse": {"hp": 44, "damage": 11, "reach": 15.0, "cooldown": 0.9, "speed": 75.0, "armor": 2, "engage": 50.0, "leash": 60.0, "turn": 1.2},
}
## Blocks per side: kind, soldiers, files (soldiers per rank), lateral and rear position
## of the block centre relative to the army's front centre. The cavalry's side is
## chosen by the general at the start of each battle.
const ARMY := [
	["spear", 27, 9, -165.0, 0.0],
	["spear", 26, 9, 0.0, 0.0],
	["spear", 27, 9, 165.0, 0.0],
	["sword", 30, 10, -310.0, 10.0],
	["sword", 30, 10, 310.0, 10.0],
	["archer", 14, 7, -165.0, 90.0],
	["archer", 12, 6, 0.0, 90.0],
	["archer", 14, 7, 165.0, 90.0],
	["horse", 20, 10, 430.0, 40.0],
]
const FILE_SPACING := 11.0
const RANK_SPACING := 12.0
const RETARGET_TIME := 0.4
const ARROW_SPEED := 260.0
const OPENING_VOLLEYS := 4.0  # seconds the melee blocks wait while archers shoot
const BREAK_MORALE := 30.0
const WITHDRAW_MORALE := 45.0
const RETURN_MORALE := 70.0
const COMMAND_TIME := 2.0
const CHARGE_REST := 3.0  # a rider who hasn't struck for this long hits as a charge

var units: Array[Dictionary] = []
var blocks: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var corpses: Array[Dictionary] = []
var terrain: Array[Dictionary] = []
var events: Array[String] = []
var camera: Camera2D
var label: Label
var speed := 1.0
var paused := false
var winner := -1
var clock := 0.0
var _command_timer := 0.0
var _event_times := {}

func _ready() -> void:
	camera = Camera2D.new()
	camera.position = FIELD * 0.5
	camera.zoom = Vector2(0.34, 0.34)
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(6, 4)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	layer.add_child(label)
	_spawn()

func _spawn() -> void:
	units.clear()
	blocks.clear()
	arrows.clear()
	corpses.clear()
	events.clear()
	_event_times.clear()
	winner = -1
	clock = 0.0
	_command_timer = 0.0
	_place_terrain()
	for team in 2:
		var heading := Vector2.RIGHT if team == 0 else Vector2.LEFT
		var lateral := heading.orthogonal()
		var front := FIELD * 0.5 - heading * 300.0
		var cavalry_side := 1.0 if randf() < 0.5 else -1.0
		for entry in ARMY:
			var side := cavalry_side if entry[0] == "horse" else 1.0
			_spawn_block(team, entry, front, heading, lateral, side)
		_plan_battle(team)

func _place_terrain() -> void:
	terrain.clear()
	var kinds := ["hill", "hill", "marsh", "wood"]
	if randf() < 0.5:
		kinds.append("wood")
	for kind in kinds:
		for attempt in 20:
			var centre := Vector2(randf_range(FIELD.x * 0.32, FIELD.x * 0.68), randf_range(120.0, FIELD.y - 120.0))
			var radius := randf_range(70.0, 120.0) if kind == "hill" else randf_range(50.0, 85.0)
			var clear := true
			for other in terrain:
				if centre.distance_to(other["centre"]) < radius + other["radius"] + 20.0:
					clear = false
			if clear:
				terrain.append({"kind": kind, "centre": centre, "radius": radius, "seed": randi()})
				break

func ground_at(point: Vector2) -> String:
	for feature in terrain:
		if point.distance_to(feature["centre"]) < feature["radius"]:
			return feature["kind"]
	return ""

func _ground_speed(point: Vector2, kind: String) -> float:
	match ground_at(point):
		"marsh": return 0.4 if kind == "horse" else 0.55
		"wood": return 0.5 if kind == "horse" else 0.75
		"hill": return 0.85
	return 1.0

func _spawn_block(team: int, entry: Array, front: Vector2, heading: Vector2, lateral: Vector2, side: float) -> void:
	var kind: String = entry[0]
	var count: int = entry[1]
	var files: int = entry[2]
	var mirror := 1.0 if team == 0 else -1.0
	var centre: Vector2 = front + lateral * float(entry[3]) * mirror * side - heading * float(entry[4])
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
			"rest": CHARGE_REST,
		})
	# The sandbox's follow formation keeps a line's shape: each soldier gets an
	# offset (sideways, behind) from the leader point.
	var offsets := SandboxFormationPlanner.make_follow_offsets(ids, places, heading)
	for i in count:
		units[first + i]["offset"] = offsets[ids[i]]
	var sample: Dictionary = units[first]
	var leader: Vector2 = sample["pos"] - lateral * sample["offset"].x + heading * sample["offset"].y
	var side_offset := lateral.dot(centre - front)
	var wing := "centre" if absf(side_offset) < 1.0 else ("left" if side_offset < 0.0 else "right")
	blocks.append({
		"team": team, "kind": kind, "wing": wing, "leader": leader, "heading": heading,
		"members": range(first, first + count), "start": count, "morale": 100.0,
		"broken": false, "engaged": false, "order": "advance", "waypoints": [],
		"goal_block": -1, "withdrawn_once": false,
	})

func block_name(b: int) -> String:
	var block: Dictionary = blocks[b]
	var short := "Blue" if block["team"] == 0 else "Red"
	var kind: String = {"spear": "spears", "sword": "swords", "archer": "archers", "horse": "cavalry"}[block["kind"]]
	return "%s %s%s" % [short, (block["wing"] + " ") if block["kind"] != "horse" else "", kind]

func _event(text: String, key: String = "", every: float = 0.0) -> void:
	if key != "":
		if clock < _event_times.get(key, -INF) + every:
			return
		_event_times[key] = clock
	events.append("%3ds  %s" % [int(clock), text])
	if events.size() > 6:
		events.pop_front()

# --- generals -------------------------------------------------------------

## The opening plan: where the cavalry goes and whether one sword block waits.
func _plan_battle(team: int) -> void:
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		if block["team"] != team or block["kind"] != "horse":
			continue
		# the enemy army may not be spawned yet, so the first command picks the actual block
		block["order"] = "flank"
		block["goal_block"] = -2 if randf() < 0.7 else -3  # -2 archers, -3 swords; the ones nearer our riders
	var swords: Array[int] = []
	for b in blocks.size():
		if blocks[b]["team"] == team and blocks[b]["kind"] == "sword":
			swords.append(b)
	if not swords.is_empty() and randf() < 0.5:
		var reserve: int = swords.pick_random()
		blocks[reserve]["order"] = "hold"
		blocks[reserve]["reserve"] = true

func _resolve_cavalry_goal(b: int) -> void:
	var block: Dictionary = blocks[b]
	var wanted: int = block["goal_block"]
	if wanted >= 0:
		return
	var choice := -1
	for other in blocks.size():
		var target: Dictionary = blocks[other]
		if target["team"] == block["team"]:
			continue
		if (wanted == -2 and target["kind"] == "archer") or (wanted == -3 and target["kind"] == "sword"):
			if choice < 0 or _centre(other).distance_to(block["leader"]) < _centre(choice).distance_to(block["leader"]):
				choice = other
	block["goal_block"] = choice
	if choice < 0:
		block["order"] = "advance"
		return
	# ride around the outside of the enemy line, then turn in behind the target
	var goal := _centre(choice)
	var side := signf(block["leader"].y - FIELD.y * 0.5)
	if side == 0.0:
		side = 1.0
	var enemy_heading: Vector2 = blocks[choice]["heading"]
	var outside := clampf(goal.y + side * 330.0, 40.0, FIELD.y - 40.0)
	block["waypoints"] = [
		Vector2(block["leader"].x + enemy_heading.x * -120.0, outside),
		Vector2(goal.x - enemy_heading.x * 140.0, outside),
		Vector2(goal.x - enemy_heading.x * 120.0, goal.y),
	]
	_event("%s rides around the %s flank toward %s" % [block_name(b), "southern" if side > 0 else "northern", block_name(choice)])

func _command(team: int) -> void:
	# the weakest spear block decides when the reserve is needed
	var spear_morale := 100.0
	var line_engaged := false
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		if block["team"] == team and block["kind"] == "spear":
			spear_morale = minf(spear_morale, block["morale"] if not block["broken"] else 0.0)
			line_engaged = line_engaged or block["engaged"]
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		if block["team"] != team or block["broken"] or _living(b) == 0:
			continue
		if block["kind"] == "horse" and block["order"] == "flank" and block["goal_block"] < 0:
			_resolve_cavalry_goal(b)
		if block.get("reserve", false) and block["order"] == "hold":
			if spear_morale < 70.0 or clock > 35.0 or (line_engaged and clock > 20.0):
				block["order"] = "advance"
				block["reserve"] = false
				_event("%s, held in reserve, now joins the fight" % block_name(b))
		elif block["order"] == "withdraw" and block["morale"] >= RETURN_MORALE:
			block["order"] = "advance"
			_event("%s has steadied and returns to the line" % block_name(b))
		elif block["order"] in ["advance", "hold"] and block["kind"] != "archer" and not block["withdrawn_once"] and block["morale"] < WITHDRAW_MORALE:
			block["order"] = "withdraw"
			block["withdrawn_once"] = true
			block["waypoints"] = []
			_event("%s pulls back to recover" % block_name(b))

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

func _turn_toward(b: int, point: Vector2, dt: float) -> void:
	var block: Dictionary = blocks[b]
	var centre := _centre(b)
	var heading: Vector2 = block["heading"]
	var wanted := heading.angle_to(point - centre)
	if absf(wanted) <= 0.15:
		return
	var rate: float = KINDS[block["kind"]]["turn"]
	var turn := clampf(wanted, -rate * dt, rate * dt)
	# rotate around the block's centre so the soldiers don't swing around the leader point
	block["leader"] = centre + (block["leader"] - centre).rotated(turn)
	block["heading"] = heading.rotated(turn)

func _steer_block(b: int, dt: float) -> void:
	var block: Dictionary = blocks[b]
	if block["broken"] or _living(b) == 0:
		return
	if block["order"] == "withdraw":
		block["morale"] = minf(100.0, block["morale"] + 4.0 * dt)
	elif not block["engaged"]:
		block["morale"] = minf(100.0, block["morale"] + 1.5 * dt)
	var centre := _centre(b)
	var enemy := _nearest_enemy_to(centre, block["team"])
	if enemy < 0:
		return
	var enemy_pos: Vector2 = units[enemy]["pos"]
	var distance := centre.distance_to(enemy_pos)
	block["engaged"] = distance < 45.0
	var stats: Dictionary = KINDS[block["kind"]]
	var advance := 0.0
	var waypoints: Array = block["waypoints"]
	if block["order"] == "flank" and not waypoints.is_empty():
		var point: Vector2 = waypoints[0]
		if centre.distance_to(point) < 40.0:
			waypoints.pop_front()
			if waypoints.is_empty():
				_event("%s charges into %s from behind!" % [block_name(b), block_name(block["goal_block"])] if block["goal_block"] >= 0 else "%s charges" % block_name(b))
		_turn_toward(b, point, dt)
		advance = 1.0
	elif block["order"] == "flank" and block["goal_block"] >= 0 and not blocks[block["goal_block"]]["broken"] and _living(block["goal_block"]) > 0:
		var goal := _centre(block["goal_block"])
		_turn_toward(b, goal, dt)
		advance = 1.0 if centre.distance_to(goal) > 15.0 else 0.0
	elif block["order"] == "flank" and block["goal_block"] >= 0:
		block["order"] = "advance"
	if block["order"] == "withdraw":
		_turn_toward(b, enemy_pos, dt)
		advance = -0.7 if distance < 170.0 else 0.0
	elif block["order"] == "hold":
		_turn_toward(b, enemy_pos, dt)
	elif block["order"] == "advance":
		_turn_toward(b, enemy_pos, dt)
		match block["kind"]:
			"archer":
				var reach: float = stats["reach"] + (40.0 if ground_at(centre) == "hill" else 0.0)
				if distance > reach * 0.9:
					advance = 1.0
				elif distance < 120.0:
					advance = -1.0
			"spear":
				if clock > OPENING_VOLLEYS and distance > 26.0:
					advance = 1.0
			"sword", "horse":
				if clock > OPENING_VOLLEYS + 1.0 and distance > 18.0:
					advance = 1.0
	# a block whose soldiers fall behind their places waits for them
	if advance > 0.0 and _spread(b) > (25.0 if block["kind"] == "horse" else 10.0):
		advance *= 0.3
	block["leader"] += block["heading"] * advance * stats["speed"] * 0.8 * _ground_speed(centre, block["kind"]) * dt

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
		_event("%s breaks and runs!" % block_name(b))
		# a block running away shakes the rest of its army and heartens the enemy
		for other in blocks.size():
			if other != b and not blocks[other]["broken"]:
				if blocks[other]["team"] == block["team"]:
					_lose_morale(other, 12.0)
				else:
					blocks[other]["morale"] = minf(100.0, blocks[other]["morale"] + 10.0)

# --- soldiers -------------------------------------------------------------

func _step_unit(i: int, dt: float) -> void:
	var u: Dictionary = units[i]
	if not u["alive"]:
		return
	var block: Dictionary = blocks[u["block"]]
	var stats: Dictionary = KINDS[u["kind"]]
	var ground := _ground_speed(u["pos"], u["kind"])
	u["cooldown"] = maxf(0.0, u["cooldown"] - dt)
	u["swing"] = maxf(0.0, u["swing"] - dt)
	u["rest"] += dt
	if block["broken"]:
		var home := Vector2.LEFT if u["team"] == 0 else Vector2.RIGHT
		u["pos"] += (home + Vector2(0, randf_range(-0.3, 0.3))) * stats["speed"] * 1.3 * ground * dt
		u["facing"] = home.x
		if u["pos"].x < -10.0 or u["pos"].x > FIELD.x + 10.0:
			u["alive"] = false
			u["fled"] = true
		return
	u["retarget"] -= dt
	if u["retarget"] <= 0.0:
		u["retarget"] = RETARGET_TIME
		u["target"] = -1
		var engage: float = stats["engage"]
		if u["kind"] == "archer" and ground_at(u["pos"]) == "hill":
			engage += 40.0
		# riders on their way around a flank only fight what gets in the way
		if block["order"] == "flank" and not block["waypoints"].is_empty():
			engage = stats["reach"] + 4.0
		var nearest := _nearest_enemy_to(u["pos"], u["team"])
		var slot := _slot(u)
		if nearest >= 0 and units[nearest]["pos"].distance_to(u["pos"]) <= engage \
				and (u["kind"] == "archer" or units[nearest]["pos"].distance_to(slot) <= engage + stats["leash"]):
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
		var reach: float = stats["reach"] + (40.0 if u["kind"] == "archer" and ground_at(u["pos"]) == "hill" else 0.0)
		if u["kind"] != "archer" and distance > reach * 0.85:
			goal = units[target]["pos"]
		if distance <= reach and u["cooldown"] <= 0.0:
			_attack(i, target)
	else:
		u["facing"] = signf(block["heading"].x) if absf(block["heading"].x) > 0.1 else u["facing"]
	var to_goal: Vector2 = goal - u["pos"]
	if to_goal.length() > 1.5:
		# soldiers behind their place hurry a little to close up the ranks
		var hurry := 1.4 if target < 0 and to_goal.length() > 8.0 else 1.0
		u["pos"] += to_goal.normalized() * minf(to_goal.length(), stats["speed"] * hurry * ground * dt)

func _attack(i: int, target: int) -> void:
	var u: Dictionary = units[i]
	var stats: Dictionary = KINDS[u["kind"]]
	u["cooldown"] = stats["cooldown"] * randf_range(0.85, 1.15)
	if u["kind"] == "archer":
		var aim: Vector2 = units[target]["pos"] + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		arrows.append({"from": u["pos"] + Vector2(0, -12), "to": aim, "t": 0.0,
			"time": u["pos"].distance_to(aim) / ARROW_SPEED, "team": u["team"], "damage": stats["damage"]})
		return
	u["swing"] = 0.18
	var damage: float = stats["damage"]
	var shock := 0.0
	# a rider who has been moving rather than fighting hits as a charge, except in mud and trees
	if u["kind"] == "horse" and u["rest"] >= CHARGE_REST and ground_at(u["pos"]) not in ["marsh", "wood"]:
		damage *= 2.5
		shock = 3.0
	# fighting downhill helps
	if ground_at(u["pos"]) == "hill" and ground_at(units[target]["pos"]) != "hill":
		damage += 2.0
	u["rest"] = 0.0
	_hit(target, damage, u["pos"], shock)

## Where the blow came from matters: from the side or behind it hurts more,
## and it shakes the block far more than a blow from the front.
func _hit(index: int, damage: float, from: Vector2, shock: float = 0.0) -> void:
	var u: Dictionary = units[index]
	if not u["alive"]:
		return
	var b: int = u["block"]
	var block: Dictionary = blocks[b]
	var morale_loss := shock
	if not block["broken"]:
		var direction: Vector2 = (from - u["pos"]).normalized()
		var front: float = direction.dot(block["heading"])
		if front < -0.3:
			damage *= 1.5
			morale_loss += 1.5
			_event("%s is attacked from behind" % block_name(b), "rear%d" % b, 8.0)
		elif front < 0.5:
			damage *= 1.2
			morale_loss += 0.6
			_event("%s is attacked on the flank" % block_name(b), "flank%d" % b, 8.0)
	u["hp"] -= maxi(1, int(round(damage)) - int(KINDS[u["kind"]]["armor"]))
	if u["hp"] <= 0:
		u["alive"] = false
		corpses.append({"pos": u["pos"], "team": u["team"], "kind": u["kind"]})
		morale_loss += 120.0 / block["start"]
	if morale_loss > 0.0:
		_lose_morale(b, morale_loss)

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
		# trees catch half the arrows aimed at soldiers among them
		if ground_at(arrow["to"]) == "wood" and randf() < 0.5:
			continue
		for j in units.size():
			var u: Dictionary = units[j]
			if u["alive"] and u["team"] != arrow["team"] and u["pos"].distance_to(arrow["to"]) < 8.0:
				_hit(j, arrow["damage"], arrow["from"])
				break

func simulate(dt: float) -> void:
	clock += dt
	_command_timer -= dt
	if _command_timer <= 0.0:
		_command_timer = COMMAND_TIME
		for team in 2:
			_command(team)
	for b in blocks.size():
		_steer_block(b, dt)
	for i in units.size():
		_step_unit(i, dt)
	_separate()
	_fly_arrows(dt)
	_check_winner()

func _check_winner() -> void:
	if winner >= 0:
		return
	var fighting := fighting_counts()
	if fighting[0] == 0 or fighting[1] == 0:
		winner = 0 if fighting[0] > 0 else 1
		_event("%s holds the field" % TEAM_NAMES[winner])

## Soldiers still in the fight: alive and in a block that hasn't broken.
func fighting_counts() -> Array:
	var counts := [0, 0]
	for u in units:
		if u["alive"] and not blocks[u["block"]]["broken"]:
			counts[u["team"]] += 1
	return counts

# --- input and drawing ----------------------------------------------------

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
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.25, 0.25), Vector2(4, 4))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.25, 0.25), Vector2(4, 4))

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

func _update_label() -> void:
	var lines := []
	for team in 2:
		var alive := 0
		var parts := []
		for b in blocks.size():
			if blocks[b]["team"] == team:
				var block: Dictionary = blocks[b]
				var state := "ran" if block["broken"] else ("%d%%" % int(block["morale"]))
				if block["order"] != "advance" and not block["broken"]:
					state += " " + block["order"]
				parts.append("%s %d %s" % [block["kind"], _living(b), state])
				alive += _living(b)
		lines.append("%s %d: %s" % [TEAM_NAMES[team], alive, " · ".join(parts)])
	lines.append_array(events)
	lines.append("Space pause%s · 1-3 speed x%d · R new battle · arrows pan · wheel zoom" % [" (PAUSED)" if paused else "", int(speed)])
	label.text = "\n".join(lines)

func _draw() -> void:
	draw_rect(Rect2(Vector2(-400, -400), FIELD + Vector2(800, 800)), Color("6f9c5e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 700:
		var p := Vector2(rng.randf() * FIELD.x, rng.randf() * FIELD.y)
		draw_rect(Rect2(p, Vector2(2, 1)), Color("8db574"))
	for feature in terrain:
		_draw_feature(feature)
	for c in corpses:
		var size := Vector2(18, 7) if c["kind"] == "horse" else Vector2(14, 5)
		draw_rect(Rect2(c["pos"] - Vector2(size.x * 0.5, 4), size), TEAM_COLORS[c["team"]].darkened(0.45))
	var order := []
	for i in units.size():
		if units[i]["alive"]:
			order.append(i)
	order.sort_custom(func(a, b): return units[a]["pos"].y < units[b]["pos"].y)
	for i in order:
		_draw_unit(units[i])
	for feature in terrain:
		if feature["kind"] == "wood":
			_draw_tree_tops(feature)
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

func _draw_feature(feature: Dictionary) -> void:
	var centre: Vector2 = feature["centre"]
	var radius: float = feature["radius"]
	match feature["kind"]:
		"hill":
			draw_circle(centre, radius, Color("86ad66"))
			draw_arc(centre, radius, 0, TAU, 48, Color("5f8a4c"), 2.0)
			draw_circle(centre + Vector2(-radius * 0.1, -radius * 0.1), radius * 0.6, Color("94b872"))
			draw_arc(centre + Vector2(-radius * 0.1, -radius * 0.1), radius * 0.6, 0, TAU, 40, Color("6f9a56"), 1.0)
		"marsh":
			draw_circle(centre, radius, Color("5b7a55"))
			var rng := RandomNumberGenerator.new()
			rng.seed = feature["seed"]
			for i in 14:
				var p := centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * radius * 0.8
				draw_circle(p, rng.randf_range(6, 14), Color("4a6b6e"))
			for i in 30:
				var p := centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * radius * 0.9
				draw_line(p, p + Vector2(rng.randf_range(-1, 1), -6), Color("9aa25a"), 1.0)
		"wood":
			draw_circle(centre, radius, Color("4f7a44"))

func _draw_tree_tops(feature: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = feature["seed"]
	for i in 22:
		var p: Vector2 = feature["centre"] + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * feature["radius"] * 0.9
		draw_line(p, p + Vector2(0, 8), Color("5a4026"), 2.0)
		draw_circle(p, rng.randf_range(7, 11), Color(0.2, 0.38, 0.2, 0.75))

func _draw_unit(u: Dictionary) -> void:
	var broken: bool = blocks[u["block"]]["broken"]
	var team_color: Color = TEAM_COLORS[u["team"]]
	if broken:
		team_color = team_color.lerp(Color.WHITE, 0.4)
	var pos: Vector2 = u["pos"]
	var facing: float = u["facing"]
	var lift := 0.0
	if u["kind"] == "horse":
		# a stand-in horse: body, neck and legs under the rider
		lift = 7.0
		var coat := Color("6b4a2e")
		draw_rect(Rect2(pos + Vector2(-9, -9), Vector2(18, 6)), coat)
		draw_rect(Rect2(pos + Vector2(8 * facing - (3 if facing < 0 else 0), -14), Vector2(3, 7)), coat)
		draw_rect(Rect2(pos + Vector2(9 * facing - (5 if facing < 0 else 0), -15), Vector2(5, 3)), coat.darkened(0.2))
		for x in [-7, -4, 4, 7]:
			draw_line(pos + Vector2(x, -3), pos + Vector2(x, 0), coat.darkened(0.3), 1.0)
		draw_rect(Rect2(pos + Vector2(-6, -9), Vector2(12, 3)), team_color.darkened(0.2))
	var body := pos + Vector2(0, -lift)
	draw_set_transform(body + Vector2(-8.0 * facing, -22), 0.0, Vector2(facing, 1))
	draw_texture(BODY, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	# team tunic and helmet so both armies read at a glance
	draw_rect(Rect2(body + Vector2(-5, -13), Vector2(10, 7)), team_color)
	draw_rect(Rect2(body + Vector2(-4, -23), Vector2(8, 3)), team_color.darkened(0.3))
	if broken:
		return  # weapons dropped
	var hand := body + Vector2(5 * facing, -10)
	var swinging: bool = u["swing"] > 0.0
	match u["kind"]:
		"spear":
			var tip := hand + Vector2(18 * facing, -10 + (8 if swinging else 0))
			draw_line(hand, tip, Color("8a6a40"), 1.0)
			draw_line(tip, tip + (tip - hand).normalized() * 3, Color("d7e6ea"), 2.0)
		"sword", "horse":
			var angle := 0.6 if swinging else -1.0
			draw_line(hand, hand + Vector2(cos(angle) * 9 * facing, sin(angle) * 9), Color("d7e6ea"), 2.0)
		"archer":
			var start := -PI * 0.5 if facing > 0 else PI * 0.5
			draw_arc(hand + Vector2(2 * facing, 0), 6.0, start, start + PI, 8, Color("8a6a40"), 1.0)
	var hp_ratio := float(u["hp"]) / float(KINDS[u["kind"]]["hp"])
	if hp_ratio < 1.0:
		draw_rect(Rect2(body + Vector2(-6, -27), Vector2(12, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(body + Vector2(-6, -27), Vector2(12 * hp_ratio, 2)), Color("f5c34c"))
