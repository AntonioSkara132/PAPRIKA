extends Node2D
## A standalone test fight against a hacker boss who rewrites the arena.
## The boss plans with Claude (see coder_boss_brain.gd); while an answer is on
## its way, or when Claude is unavailable, he runs one of the scripted plans.
## Every terrain change is shown as the boss's code over the tiles for
## WARNING seconds first; hitting the boss during that time cancels it.
## Run it with: godot --path . res://scenes/coder_boss.tscn
## Without Claude: -- --no-ai. Another model: -- --model=claude-sonnet-5-5
## Claude's effort (low by default): -- --effort=medium
## Controls: WASD/arrows move, Space hits the boss when close, R restarts.
## The boss can raise a shield for up to 3 s that stops hits completely,
## including their cancels; a new shield needs SHIELD_COOLDOWN after the last one ends.
## Every fight is logged to user://coder_boss_logs (the full path is printed at start).
## Glitch remembers the current fight through a running summary, and earlier
## fights through lessons.txt in the same folder, which he rewrites after each
## fight from history.jsonl, the record of every finished fight. Delete both
## files to make him forget the player.

const COLS := 30
const ROWS := 18
const TILE := 32
const WARNING := 1.5
const SHIELD_COOLDOWN := 6.0
const CANCEL_COOLDOWN := 2.0  # a hit cancels the boss's newest change at most this often
const LOG_DIR := "user://coder_boss_logs"
## Glitch's notes about the player, rewritten by Claude after every finished fight.
const LESSONS_PATH := "user://coder_boss_logs/lessons.txt"
## One JSON line per finished fight; the game totals them so Glitch's notes rest
## on every fight, not only the last one.
const HISTORY_PATH := "user://coder_boss_logs/history.jsonl"
const JUMP_WINDOW := 3.0  # hits this soon after a jump count against that jump
const BODY := preload("res://assets/art/player_plain.png")
const COLORS := {
	CoderBossCommands.FLOOR: Color("3a3f4b"),
	CoderBossCommands.WALL: Color("8a8fa3"),
	CoderBossCommands.PIT: Color("0c0a14"),
	CoderBossCommands.LAVA: Color("e0562a"),
	CoderBossCommands.ANCHOR: Color("4f83cf"),
}
const ANCHORS := [Vector2i(3, 3), Vector2i(3, 13), Vector2i(25, 3), Vector2i(25, 13), Vector2i(14, 8)]
const SCRIPTED_PLANS := [
	"say \"Your floor is a suggestion.\"\nset_tiles PX-1 PY-1 PX+1 PY+1 PIT 5",
	"say \"Let me fence you in.\"\nset_tiles 8 2 8 15 WALL 8\nwait 1\nset_tiles 20 2 20 15 WALL 8",
	"say \"Hot patch.\"\nset_tiles PX-3 PY-3 PX+3 PY-3 WALL 6\nset_tiles PX-3 PY+3 PX+3 PY+3 WALL 6\nwait 0.5\nset_tiles PX-2 PY-2 PX+2 PY+2 LAVA 5",
	"say \"Catch me.\"\nmove_boss 22 5\nset_tiles 17 3 18 14 PIT 6",
]

var grid: Array = []
var player_pos := Vector2.ZERO
var player_hp := 10
var boss_cell := Vector2i(22, 9)
var boss_hp := 20
var queue: Array = []
var pending: Array = []  # edits waiting out their warning: {cells, type, duration, left, line, rect}
var reverts: Array = []  # applied edits: {cells, old, left}
var speech := ""
var speech_left := 0.0
var wait_left := 0.0
var next_plan := ""
var log_lines: Array[String] = []
var use_brain := true
var brain: CoderBossBrain
var brain_status := "off"
var finished := ""
var _hurt_left := 0.0
var _lava_tick := 0.0
var _attack_left := 0.0
var _history: Array[Vector2i] = []
var _history_tick := 0.0
var _hits_this_plan := 0
var _flicker := 0.0
var _fallback := 0
var _cancel_left := 0.0
var _fight_time := 0.0
var _fight_number := 0
var _log_file: FileAccess
var _idle := 0.0  # seconds the boss has waited for Claude with nothing to run
var lessons := ""
var lessons_brain: CoderBossBrain
# running record of the fight that goes into every snapshot and into the lessons
var _stats := {}
var _plans: Array = []  # {source, summary, dealt, hits}
var _area_time := {}
var _past_fights: Array = []
var _cell_aimed := {}  # Vector2i -> whether the change that made this tile was aimed with PX/PY
var _jump_left := 0.0  # counts down from JUMP_WINDOW after each move_boss
var shield_left := 0.0
var _shield_ready_in := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--no-ai" in args:
		use_brain = false
	if use_brain:
		brain = CoderBossBrain.new()
		for arg in args:
			if arg.begins_with("--model="):
				brain.model = arg.trim_prefix("--model=")
			elif arg.begins_with("--effort="):
				brain.effort = arg.trim_prefix("--effort=")
		add_child(brain)
		brain.plan_ready.connect(_on_plan_ready)
		brain.plan_failed.connect(_on_plan_failed)
		lessons_brain = CoderBossBrain.new()
		lessons_brain.system_prompt = CoderBossBrain.LESSONS_PROMPT
		lessons_brain.model = brain.model
		lessons_brain.effort = brain.effort
		add_child(lessons_brain)
		lessons_brain.plan_ready.connect(_on_lessons_ready)
		lessons_brain.plan_failed.connect(func(reason): _log("lessons not updated: " + reason))
	if FileAccess.file_exists(HISTORY_PATH):
		for line in FileAccess.get_file_as_string(HISTORY_PATH).split("\n", false):
			var fight = JSON.parse_string(line)
			if fight is Dictionary:
				_past_fights.append(fight)
	if FileAccess.file_exists(LESSONS_PATH):
		lessons = FileAccess.get_file_as_string(LESSONS_PATH).strip_edges()
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	restart()

## The arena and its status lines are larger than the game's 640x360 view, so
## scale them down to fit and centre them.
func _fit_to_screen() -> void:
	var view := get_viewport_rect().size
	var needed := Vector2(COLS * TILE, ROWS * TILE + 56)
	var fit := minf(view.x / needed.x, view.y / needed.y)
	scale = Vector2(fit, fit)
	position = (view - needed * fit) / 2

func restart() -> void:
	if _log_file != null and finished == "":
		_log("fight %d abandoned after %.0f s, player %d/10, Glitch %d/20" % [_fight_number, _fight_time, player_hp, boss_hp])
	grid.clear()
	for y in ROWS:
		var row := []
		for x in COLS:
			row.append(CoderBossCommands.WALL if x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1 else CoderBossCommands.FLOOR)
		grid.append(row)
	for a in ANCHORS:
		grid[a.y][a.x] = CoderBossCommands.ANCHOR
	player_pos = _cell_centre(Vector2i(5, 9))
	player_hp = 10
	boss_cell = Vector2i(22, 9)
	boss_hp = 20
	queue.clear()
	pending.clear()
	reverts.clear()
	next_plan = ""
	finished = ""
	log_lines.clear()
	_history.clear()
	_cancel_left = 0.0
	_fight_time = 0.0
	_fight_number += 1
	shield_left = 0.0
	_shield_ready_in = 0.0
	_stats = {"hits": 0, "blocked": 0, "dropped": 0, "shields": 0, "shields_refused": 0, "cancels": 0, "pit": 0, "lava": 0, "near": 0.0, "wall_uses": 0, "pit_uses": 0, "lava_uses": 0,
		"aimed_uses": 0, "fixed_uses": 0, "aimed_damage": 0, "fixed_damage": 0, "jumps": 0, "hits_after_jump": 0}
	_cell_aimed.clear()
	_jump_left = 0.0
	_plans.clear()
	_area_time.clear()
	_open_log()
	_ask_brain()

func _process(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_R) and finished != "":
		restart()
	if finished == "":
		var dir := Vector2(
			int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		move_player(dir.normalized() * 150.0 * delta)
		if Input.is_physical_key_pressed(KEY_SPACE):
			attack()
	simulate(delta)
	queue_redraw()

## One step of the fight without input, so the smoke test can run it headless.
func simulate(dt: float) -> void:
	if finished != "":
		return
	_flicker += dt
	_hurt_left = maxf(0.0, _hurt_left - dt)
	_attack_left = maxf(0.0, _attack_left - dt)
	_cancel_left = maxf(0.0, _cancel_left - dt)
	_fight_time += dt
	_jump_left = maxf(0.0, _jump_left - dt)
	if shield_left > 0.0:
		shield_left = maxf(0.0, shield_left - dt)
		if shield_left == 0.0:
			_shield_ready_in = SHIELD_COOLDOWN
	else:
		_shield_ready_in = maxf(0.0, _shield_ready_in - dt)
	if player_pos.distance_to(_cell_centre(boss_cell)) < 2.5 * TILE:
		_stats["near"] += dt
	var area := _area_name(_player_cell())
	_area_time[area] = _area_time.get(area, 0.0) + dt
	speech_left = maxf(0.0, speech_left - dt)
	_history_tick += dt
	if _history_tick >= 1.0:
		_history_tick = 0.0
		_history.append(_player_cell())
		if _history.size() > 8:
			_history.pop_front()
	for edit in pending.duplicate():
		edit["left"] -= dt
		if edit["left"] <= 0.0:
			pending.erase(edit)
			_apply(edit)
	for r in reverts.duplicate():
		r["left"] -= dt
		if r["left"] <= 0.0:
			reverts.erase(r)
			for i in r["cells"].size():
				var c: Vector2i = r["cells"][i]
				grid[c.y][c.x] = r["old"][i]
	_run_queue(dt)
	_check_ground(dt)

func _run_queue(dt: float) -> void:
	if wait_left > 0.0:
		wait_left -= dt
		return
	while not queue.is_empty() and wait_left <= 0.0:
		var c: Dictionary = queue.pop_front()
		match c["op"]:
			"say":
				speech = c["text"]
				speech_left = 3.0
			"wait":
				wait_left = c["seconds"]
			"set_tiles":
				var area := CoderBossCommands.resolve(c, grid, _player_cell())
				var aimed: bool = c["ends"].any(func(e): return e[0])
				pending.append({"cells": area["cells"], "type": c["type"], "duration": c["duration"], "left": WARNING, "line": c["line"], "rect": area["rect"], "aimed": aimed})
				wait_left = 0.3
			"move_boss":
				boss_cell = c["cell"]
				_stats["jumps"] += 1
				_jump_left = JUMP_WINDOW
			"shield":
				if shield_left > 0.0 or _shield_ready_in > 0.0:
					_stats["shields_refused"] += 1
					_log("shield not ready: %s" % c["line"])
				else:
					shield_left = c["seconds"]
					_stats["shields"] += 1
	if queue.is_empty() and pending.is_empty() and wait_left <= 0.0:
		_idle += dt
		_start_next_plan()

func _start_next_plan() -> void:
	var text := next_plan
	next_plan = ""
	if text.is_empty():
		if use_brain and brain.busy and _idle < 4.0:
			return
		text = SCRIPTED_PLANS[_fallback % SCRIPTED_PLANS.size()]
		_fallback += 1
		_log("scripted plan")
	var parsed := CoderBossCommands.parse(text, grid)
	var dropped: Array = []
	for e in parsed["errors"]:
		_log("rejected: " + e)
		if e.begins_with("too many commands"):
			dropped.append(e.trim_prefix("too many commands, dropped: "))
	_stats["dropped"] += dropped.size()
	queue = parsed["commands"]
	var shown: Array = queue.filter(func(c): return c["op"] != "say").map(func(c): return c["line"])
	_plans.append({"source": "a scripted" if text in SCRIPTED_PLANS else "your", "summary": "; ".join(shown), "dealt": 0, "hits": 0, "dropped": dropped})
	_idle = 0.0
	_hits_this_plan = 0
	_ask_brain()

func _ask_brain() -> void:
	if not use_brain or brain.busy or not next_plan.is_empty():
		return
	brain_status = "thinking"
	brain.request(snapshot())

func _on_plan_ready(text: String) -> void:
	brain_status = "ready"
	next_plan = text
	_log("Claude plan (%.1f s):\n%s" % [brain.last_seconds, text.strip_edges()])

func _on_plan_failed(reason: String) -> void:
	brain_status = "failed: " + reason
	_log(brain_status)
	use_brain = false  # stay on scripted plans for the rest of this run

func snapshot() -> String:
	var lines := ["Arena (%d columns, %d rows):" % [COLS, ROWS], CoderBossCommands.grid_text(grid, _player_cell(), boss_cell)]
	lines.append("Player health %d/10, your health %d/20." % [player_hp, boss_hp])
	if shield_left > 0.0:
		lines.append("Your shield is up for %.1f more seconds, then needs %.0f s before the next one." % [shield_left, SHIELD_COOLDOWN])
	else:
		lines.append("Your shield is ready." if _shield_ready_in <= 0.0 else "Your shield is ready in %.1f s." % _shield_ready_in)
	lines.append("Player cells over the last seconds, oldest first: %s" % str(_history))
	lines.append("Player hit you %d times during your last plan." % _hits_this_plan)
	lines.append(fight_summary())
	if not _past_fights.is_empty():
		lines.insert(0, history_summary() + "\n")
	if not lessons.is_empty():
		lines.insert(0, "Your notes from earlier fights against this player:\n%s\n" % lessons)
	var recent := log_lines.slice(maxi(0, log_lines.size() - 6))
	if not recent.is_empty():
		lines.append("Recent events:\n" + "\n".join(recent))
	lines.append("Write your next plan.")
	return "\n".join(lines)

func _apply(edit: Dictionary) -> void:
	var old: Array = []
	var type_key: String = {CoderBossCommands.WALL: "wall_uses", CoderBossCommands.PIT: "pit_uses", CoderBossCommands.LAVA: "lava_uses"}.get(edit["type"], "")
	if not type_key.is_empty():
		_stats[type_key] += 1
		_stats["aimed_uses" if edit.get("aimed", false) else "fixed_uses"] += 1
	for c in edit["cells"]:
		old.append(grid[c.y][c.x])
		if c != boss_cell:
			grid[c.y][c.x] = edit["type"]
			_cell_aimed[c] = edit.get("aimed", false)
	reverts.append({"cells": edit["cells"], "old": old, "left": edit["duration"]})

func move_player(step: Vector2) -> void:
	for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
		var next: Vector2 = player_pos + axis
		var ok := true
		for corner in [Vector2(-7, -4), Vector2(7, -4), Vector2(-7, 8), Vector2(7, 8)]:
			var c := _cell_of(next + corner)
			if grid[c.y][c.x] == CoderBossCommands.WALL or c == boss_cell:
				ok = false
		if ok:
			player_pos = next

func attack() -> void:
	if _attack_left > 0.0 or finished != "":
		return
	_attack_left = 0.4
	if player_pos.distance_to(_cell_centre(boss_cell)) > 52.0:
		return
	if shield_left > 0.0:
		_stats["blocked"] += 1
		_log("player hit Glitch's shield")
		return
	boss_hp -= 1
	_hits_this_plan += 1
	var note := ""
	_stats["hits"] += 1
	if _jump_left > 0.0:
		_stats["hits_after_jump"] += 1
	if not _plans.is_empty():
		_plans[-1]["hits"] += 1
	if not pending.is_empty() and _cancel_left <= 0.0:
		# only the change he started typing last; the rest of the plan goes on
		var cancelled: Dictionary = pending.pop_back()
		_cancel_left = CANCEL_COOLDOWN
		_stats["cancels"] += 1
		note = ", cancelled: " + cancelled["line"]
	_log("player hit Glitch, Glitch %d/20%s" % [boss_hp, note])
	if boss_hp <= 0:
		_end("You won. Press R to fight again.", "player won")

func _check_ground(dt: float) -> void:
	var cell := _player_cell()
	match grid[cell.y][cell.x]:
		CoderBossCommands.PIT:
			_hurt(2, "player fell into a pit", _cell_aimed.get(cell, false))
			player_pos = _cell_centre(_nearest_anchor(cell))
		CoderBossCommands.LAVA:
			_lava_tick -= dt
			if _lava_tick <= 0.0:
				_lava_tick = 0.5
				_hurt(1, "player burned in lava", _cell_aimed.get(cell, false))
		CoderBossCommands.WALL:
			# a wall was written on top of the player: push them to an anchor
			player_pos = _cell_centre(_nearest_anchor(cell))
			_log("player was pushed out of a new wall")

func _hurt(amount: int, why: String, aimed: bool = false) -> void:
	if _hurt_left > 0.0:
		return
	_hurt_left = 0.6
	player_hp -= amount
	_stats["pit" if amount == 2 else "lava"] += amount
	_stats["aimed_damage" if aimed else "fixed_damage"] += amount
	if not _plans.is_empty():
		_plans[-1]["dealt"] += amount
	_log("%s, player %d/10" % [why, player_hp])
	if player_hp <= 0:
		_end("Glitch rewrote you. Press R to try again.", "Glitch won")

func _nearest_anchor(from: Vector2i) -> Vector2i:
	var best: Vector2i = ANCHORS[0]
	for a in ANCHORS:
		if Vector2(a - from).length() < Vector2(best - from).length():
			best = a
	return best

func _end(message: String, result: String) -> void:
	finished = message
	_log("fight %d over after %.0f s: %s, player %d/10, Glitch %d/20" % [_fight_number, _fight_time, result, player_hp, boss_hp])
	_record_fight(result)
	if use_brain and not lessons_brain.busy:
		_log("Claude is rewriting the notes about the player")
		lessons_brain.request("Your notes so far:\n%s\n\n%s\n\nThe fight that just ended: %s after %.0f s, player health %d/10, your health %d/20.\n%s" % [
			lessons if not lessons.is_empty() else "(none yet)", history_summary(), result, _fight_time, player_hp, boss_hp, fight_summary(20)])

func _record_fight(result: String) -> void:
	var fight := _stats.duplicate()
	fight["won"] = result == "Glitch won"
	fight["seconds"] = snappedf(_fight_time, 0.1)
	fight["near"] = snappedf(_stats["near"], 0.1)
	fight["player_hp"] = player_hp
	fight["boss_hp"] = boss_hp
	fight["plans"] = _plans.size()
	_past_fights.append(fight)
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(HISTORY_PATH) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(fight))

## Totals over every finished fight, counted by the game so they stay exact.
func history_summary() -> String:
	if _past_fights.is_empty():
		return "No finished fights against this player yet."
	var total := {}
	for fight in _past_fights:
		for key in fight:
			if fight[key] is float or fight[key] is int or fight[key] is bool:
				total[key] = total.get(key, 0.0) + float(fight[key])
	var n := _past_fights.size()
	var per := func(damage: String, uses: String) -> String:
		return "%d damage in %d uses (%.2f per use)" % [total.get(damage, 0.0), total.get(uses, 0.0), total.get(damage, 0.0) / maxf(1.0, total.get(uses, 0.0))]
	var lines := ["History of all %d finished fights: you won %d, the player won %d. Average length %.0f s; average player health at the end %.1f/10." % [
		n, total.get("won", 0.0), n - int(total.get("won", 0.0)), total.get("seconds", 0.0) / n, total.get("player_hp", 0.0) / n]]
	lines.append("Damage you dealt: lava %s; pits %s; walls used %d times (they deal no damage)." % [
		per.call("lava", "lava_uses"), per.call("pit", "pit_uses"), total.get("wall_uses", 0.0)])
	lines.append("Changes aimed with PX/PY: %s. Changes at fixed coordinates: %s." % [
		per.call("aimed_damage", "aimed_uses"), per.call("fixed_damage", "fixed_uses")])
	lines.append("The player hit you %.1f times per fight and stayed within 2 tiles of you %d%% of the time. You jumped %d times; %.2f hits per jump landed in the %d s after it." % [
		total.get("hits", 0.0) / n, int(100.0 * total.get("near", 0.0) / maxf(1.0, total.get("seconds", 0.0))), total.get("jumps", 0.0),
		total.get("hits_after_jump", 0.0) / maxf(1.0, total.get("jumps", 0.0)), JUMP_WINDOW])
	lines.append("Your shield blocked %d hits in %d shields; %d shield commands came too early. %d commands were dropped for being over the limit of 8." % [
		total.get("blocked", 0.0), total.get("shields", 0.0), total.get("shields_refused", 0.0), total.get("dropped", 0.0)])
	lines.append("Last fights, oldest first:")
	for fight in _past_fights.slice(maxi(0, n - 5)):
		lines.append("- %s in %.0f s, player %d/10, you %d/20, %d hits taken, %d jumps" % [
			"you won" if fight.get("won", false) else "player won", fight.get("seconds", 0.0), fight.get("player_hp", 0), fight.get("boss_hp", 0), fight.get("hits", 0), fight.get("jumps", 0)])
	return "\n".join(lines)

## How the fight has gone so far, for Glitch: what hurt the player, what the
## player did against him, where they like to be, and how each plan went.
func fight_summary(plan_count: int = 5) -> String:
	var lines := ["Fight so far (%.0f s): the player hit you %d times and cancelled %d of your changes. You dealt %d damage with pits and %d with lava." % [
		_fight_time, _stats["hits"], _stats["cancels"], _stats["pit"], _stats["lava"]]]
	lines.append("Your shield blocked %d hits in %d shields; %d shield commands came while it was not ready and did nothing." % [
		_stats["blocked"], _stats["shields"], _stats["shields_refused"]])
	if _stats["dropped"] > 0:
		lines.append("%d of your commands were dropped because a plan had more than 8. Count them: at most 8 lines besides say." % _stats["dropped"])
	if _fight_time > 0.0:
		var areas: Array = _area_time.keys()
		areas.sort_custom(func(a, b): return _area_time[a] > _area_time[b])
		lines.append("The player spent %d%% of the fight within 2 tiles of you. Time by area: %s." % [
			int(100.0 * _stats["near"] / _fight_time), ", ".join(areas.map(func(a): return "%s %d%%" % [a, int(100.0 * _area_time[a] / _fight_time)]))])
	var recent := _plans.slice(maxi(0, _plans.size() - plan_count))
	if not recent.is_empty():
		lines.append("Your last plans and how they went:")
		for p in recent:
			var line := "- %s plan [%s]: dealt %d damage, you took %d hits" % [p["source"], p["summary"], p["dealt"], p["hits"]]
			if not p["dropped"].is_empty():
				line += "; dropped for being over 8: " + "; ".join(p["dropped"])
			lines.append(line)
	return "\n".join(lines)

func _area_name(cell: Vector2i) -> String:
	var row := "top" if cell.y < ROWS / 3 else ("bottom" if cell.y >= ROWS * 2 / 3 else "middle")
	var column := "left" if cell.x < COLS / 3 else ("right" if cell.x >= COLS * 2 / 3 else "centre")
	return "%s %s" % [row, column]

func _on_lessons_ready(text: String) -> void:
	lessons = text.strip_edges()
	var file := FileAccess.open(LESSONS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(lessons + "\n")
	_log("notes about the player rewritten:\n" + lessons)

func _open_log() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/%s_fight%d.log" % [LOG_DIR, stamp, _fight_number]
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	_log("fight %d started, model %s, log %s" % [_fight_number, "%s, effort %s" % [brain.model, brain.effort] if use_brain else "none (scripted plans)", ProjectSettings.globalize_path(path)])

func _log(text: String) -> void:
	log_lines.append(text)
	print("[coder boss] ", text)
	if _log_file != null:
		_log_file.store_line("%6.1f %s" % [_fight_time, text])
		_log_file.flush()

func _exit_tree() -> void:
	if _log_file != null and finished == "":
		_log("fight %d abandoned after %.0f s, player %d/10, Glitch %d/20" % [_fight_number, _fight_time, player_hp, boss_hp])

func _player_cell() -> Vector2i:
	return _cell_of(player_pos)

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / TILE), 0, COLS - 1), clampi(int(p.y / TILE), 0, ROWS - 1))

func _cell_centre(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) / 2

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for y in ROWS:
		for x in COLS:
			draw_rect(Rect2(x * TILE, y * TILE, TILE - 1, TILE - 1), COLORS[grid[y][x]])
	for edit in pending:
		var on := int(_flicker * 12.0) % 2 == 0
		for c in edit["cells"]:
			draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE - 1, TILE - 1), Color(COLORS[edit["type"]], 0.7 if on else 0.25))
		var r: Rect2i = edit["rect"]
		draw_string(font, Vector2(r.position.x * TILE, r.position.y * TILE - 4), edit["line"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7dff9a"))
	var boss_at := _cell_centre(boss_cell)
	draw_texture_rect(BODY, Rect2(boss_at - Vector2(16, 24), Vector2(32, 48)), false, Color("d04060") if pending.is_empty() else Color("7dff9a"))
	if shield_left > 0.0:
		draw_circle(boss_at, 30.0, Color(0.4, 0.8, 1.0, 0.25))
		draw_arc(boss_at, 30.0, 0.0, TAU, 32, Color("66ccff"), 2.0)
	draw_texture_rect(BODY, Rect2(player_pos - Vector2(16, 24), Vector2(32, 48)), false, Color.WHITE if _hurt_left <= 0.0 else Color("ff8080"))
	if speech_left > 0.0:
		draw_string(font, boss_at + Vector2(-80, -34), speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var hud_y := ROWS * TILE + 20
	draw_string(font, Vector2(8, hud_y), "You %d/10    Glitch %d/20    Claude: %s" % [player_hp, boss_hp, brain_status if use_brain else "off (scripted plans)"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if finished != "":
		draw_string(font, Vector2(8, hud_y + 24), finished, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd34d"))
