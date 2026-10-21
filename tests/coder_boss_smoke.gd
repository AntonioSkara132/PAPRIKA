extends SceneTree
## Checks the coder boss's command rules, then runs the arena headless on its
## scripted plans (no Claude) and checks that terrain changes and reverts.

func _init() -> void:
	var failures := 0
	var grid: Array = []
	for y in 18:
		var row := []
		for x in 30:
			row.append(CoderBossCommands.WALL if x == 0 or y == 0 or x == 29 or y == 17 else CoderBossCommands.FLOOR)
		grid.append(row)
	grid[3][3] = CoderBossCommands.ANCHOR
	var relative := CoderBossCommands.parse("set_tiles PX-1 PY-1 PX+1 PY+1 LAVA\nset_tiles PX 2 4 4 PIT", grid)
	if relative["commands"].size() != 1 or relative["errors"].size() != 1:
		failures += 1
		print("FAIL relative parse ", relative)
	else:
		var area := CoderBossCommands.resolve(relative["commands"][0], grid, Vector2i(1, 5))
		if area["rect"] != Rect2i(1, 4, 2, 3) or area["cells"].size() != 6:
			failures += 1
			print("FAIL relative resolve ", area["rect"])
	var parsed := CoderBossCommands.parse("```\nsay \"hi\"\nset_tiles 2 2 4 4 PIT 5\nset_tiles 0 0 3 3 WALL\nset_tiles 1 1 20 10 LAVA\nfly away\nmove_boss 0 5\nwait 9\n```", grid)
	var ops: Array = parsed["commands"].map(func(c): return c["op"])
	if ops != ["say", "set_tiles", "wait"]:
		failures += 1
		print("FAIL parsed ops ", ops, " errors ", parsed["errors"])
	elif Vector2i(3, 3) in CoderBossCommands.resolve(parsed["commands"][1], grid, Vector2i.ZERO)["cells"] or CoderBossCommands.resolve(parsed["commands"][1], grid, Vector2i.ZERO)["cells"].size() != 8:
		failures += 1
		print("FAIL anchor not skipped")
	elif parsed["commands"][2]["seconds"] != CoderBossCommands.MAX_WAIT:
		failures += 1
		print("FAIL wait not capped")
	if parsed["errors"].size() != 4:
		failures += 1
		print("FAIL expected 4 errors, got ", parsed["errors"])

	var arena: Node2D = load("res://scripts/coder_boss/coder_boss_arena.gd").new()
	arena.use_brain = false
	root.add_child(arena)
	await process_frame
	arena.use_brain = false
	var changed := false
	for i in 400:
		arena.simulate(0.05)
		for row in arena.grid:
			if CoderBossCommands.PIT in row or CoderBossCommands.LAVA in row or row.count(CoderBossCommands.WALL) > 2:
				changed = true
	if not changed:
		failures += 1
		print("FAIL scripted plans never changed the terrain")
	for a in arena.ANCHORS:
		if arena.grid[a.y][a.x] != CoderBossCommands.ANCHOR:
			failures += 1
			print("FAIL anchor overwritten at ", a)
	for i in 400:
		arena.simulate(0.05)
	print("player hp %d after 40 s of scripted plans" % arena.player_hp)
	# a hit cancels only the newest waiting change, and only once per CANCEL_COOLDOWN
	arena.queue.clear()
	arena.pending.clear()
	arena.player_pos = arena._cell_centre(arena.boss_cell + Vector2i(-1, 0))
	for line in ["first", "second", "third"]:
		arena.pending.append({"cells": [], "type": CoderBossCommands.PIT, "duration": 1.0, "left": 9.0, "line": line, "rect": Rect2i()})
	arena._cancel_left = 0.0
	arena._attack_left = 0.0
	arena.attack()
	arena._attack_left = 0.0
	arena.attack()
	var left: Array = arena.pending.map(func(e): return e["line"])
	if left != ["first", "second"] or arena.boss_hp != 18:
		failures += 1
		print("FAIL cancel rule left ", left, " boss hp ", arena.boss_hp)
	# a shield stops hits and their cancels, then needs a cooldown
	arena.restart()
	arena.queue = CoderBossCommands.parse("shield 2\nshield 2", arena.grid)["commands"]
	arena.simulate(0.01)
	arena.pending = [{"cells": [], "type": CoderBossCommands.WALL, "duration": 1.0, "left": 1.0, "line": "kept", "rect": Rect2i()}]
	arena.player_pos = arena._cell_centre(arena.boss_cell) + Vector2(20, 0)
	arena._attack_left = 0.0
	arena.attack()
	if arena.boss_hp != 20 or arena.pending.size() != 1 or arena._stats["blocked"] != 1 or arena._stats["shields_refused"] != 1:
		failures += 1
		print("FAIL shield: hp %d pending %d stats %s" % [arena.boss_hp, arena.pending.size(), arena._stats])
	for i in 300:
		arena.simulate(0.01)
	arena.player_pos = arena._cell_centre(arena.boss_cell) + Vector2(20, 0)
	arena._attack_left = 0.0
	arena.attack()
	if arena.boss_hp != 19 or arena._shield_ready_in <= 0.0:
		failures += 1
		print("FAIL shield end: hp %d ready in %.1f" % [arena.boss_hp, arena._shield_ready_in])
	# the history summary totals every fight it is given
	arena._past_fights = [{"won": true, "seconds": 30.0, "player_hp": 0, "boss_hp": 12, "hits": 8, "jumps": 4, "lava": 6, "lava_uses": 10, "pit": 4, "pit_uses": 5},
		{"won": false, "seconds": 20.0, "player_hp": 6, "boss_hp": 0, "hits": 20, "jumps": 0, "lava": 0, "lava_uses": 5, "pit": 0, "pit_uses": 5}]
	var summary: String = arena.history_summary()
	if not "you won 1, the player won 1" in summary or not "lava 6 damage in 15 uses" in summary or not "pits 4 damage in 10 uses" in summary:
		failures += 1
		print("FAIL history summary:\n", summary)
	print("FAILURES: %d" % failures)
	quit(failures)
