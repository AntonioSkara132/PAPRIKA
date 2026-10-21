class_name CoderBossCommands
extends RefCounted
## The command language the coder boss writes, and the rules every command must
## pass before the arena runs it. One command per line:
##   say "text"                          the boss speaks
##   wait SECONDS                        pause before the next command (up to 4)
##   set_tiles X0 Y0 X1 Y1 TYPE [SECONDS] turn a rectangle into FLOOR, WALL, PIT
##                                        or LAVA; it changes back after SECONDS
##                                        (default 8, at most 15)
##   move_boss X Y                       the boss jumps to a floor tile
##   shield SECONDS                      hits do nothing to the boss for up to 3
##                                        seconds; the arena decides when it is ready
## In set_tiles, X may be written PX, PX+N or PX-N and Y as PY, PY+N or PY-N:
## those are counted from the player's tile at the moment the change is shown,
## not when the plan was written, so the boss can aim at where the player is.
## Lines the parser does not understand, and commands that break a rule, are
## dropped with a reason; the rest still run.

enum { FLOOR, WALL, PIT, LAVA, ANCHOR }
const TYPE_NAMES := {"FLOOR": FLOOR, "WALL": WALL, "PIT": PIT, "LAVA": LAVA}
const MAX_COMMANDS := 8  # say lines do not count
const MAX_AREA := 48
const MAX_WAIT := 4.0
const MAX_DURATION := 15.0
const DEFAULT_DURATION := 8.0
const MAX_SHIELD := 3.0

## Returns {"commands": [Dictionary], "errors": [String]}. `grid` is an array of
## rows of tile types; anchors and the border can never be changed.
static func parse(text: String, grid: Array) -> Dictionary:
	var commands: Array = []
	var errors: Array = []
	var rows := grid.size()
	var cols: int = grid[0].size() if rows > 0 else 0
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("```") or line.is_empty() or line.begins_with("#"):
			continue
		var words := line.split(" ", false)
		var name := words[0].to_lower()
		if name != "say" and commands.filter(func(c): return c["op"] != "say").size() >= MAX_COMMANDS:
			errors.append("too many commands, dropped: %s" % line)
			continue
		match name:
			"say":
				var said := line.substr(3).strip_edges().trim_prefix("\"").trim_suffix("\"")
				if said.is_empty():
					errors.append("say needs text: %s" % line)
				else:
					commands.append({"op": "say", "text": said.left(120), "line": line})
			"wait":
				if words.size() != 2 or not words[1].is_valid_float():
					errors.append("wait needs seconds: %s" % line)
				else:
					commands.append({"op": "wait", "seconds": clampf(words[1].to_float(), 0.0, MAX_WAIT), "line": line})
			"set_tiles":
				if words.size() < 6 or words.size() > 7:
					errors.append("set_tiles needs X0 Y0 X1 Y1 TYPE [SECONDS]: %s" % line)
					continue
				var ends: Array = []
				for i in range(1, 5):
					ends.append(_coord(words[i], "PX" if i % 2 == 1 else "PY"))
				var type_name := words[5].to_upper()
				if null in ends or not TYPE_NAMES.has(type_name):
					errors.append("set_tiles has a bad coordinate or type: %s" % line)
					continue
				if ends[0][0] != ends[2][0] or ends[1][0] != ends[3][0]:
					errors.append("set_tiles mixes player-relative and fixed ends on one axis: %s" % line)
					continue
				var w := absi(ends[2][1] - ends[0][1]) + 1
				var h := absi(ends[3][1] - ends[1][1]) + 1
				if w * h > MAX_AREA:
					errors.append("set_tiles larger than %d tiles: %s" % [MAX_AREA, line])
					continue
				var fixed := Rect2i(mini(ends[0][1], ends[2][1]), mini(ends[1][1], ends[3][1]), w, h)
				if not ends[0][0] and (fixed.position.x < 1 or fixed.end.x > cols - 1):
					errors.append("set_tiles outside the arena: %s" % line)
					continue
				if not ends[1][0] and (fixed.position.y < 1 or fixed.end.y > rows - 1):
					errors.append("set_tiles outside the arena: %s" % line)
					continue
				var duration := DEFAULT_DURATION
				if words.size() == 7:
					if not words[6].is_valid_float():
						errors.append("set_tiles has bad seconds: %s" % line)
						continue
					duration = clampf(words[6].to_float(), 1.0, MAX_DURATION)
				commands.append({"op": "set_tiles", "ends": ends, "type": TYPE_NAMES[type_name], "duration": duration, "line": line})
			"move_boss":
				if words.size() != 3 or not words[1].is_valid_int() or not words[2].is_valid_int():
					errors.append("move_boss needs X Y: %s" % line)
					continue
				var cell := Vector2i(words[1].to_int(), words[2].to_int())
				if cell.x < 1 or cell.y < 1 or cell.x > cols - 2 or cell.y > rows - 2 or grid[cell.y][cell.x] not in [FLOOR, ANCHOR]:
					errors.append("move_boss needs a floor tile: %s" % line)
					continue
				commands.append({"op": "move_boss", "cell": cell, "line": line})
			"shield":
				if words.size() != 2 or not words[1].is_valid_float():
					errors.append("shield needs seconds: %s" % line)
				else:
					commands.append({"op": "shield", "seconds": clampf(words[1].to_float(), 0.5, MAX_SHIELD), "line": line})
			_:
				errors.append("unknown command: %s" % line)
	return {"commands": commands, "errors": errors}

## A coordinate word: [true, offset] for PX/PY forms, [false, value] for a number, null if neither.
static func _coord(word: String, player_name: String) -> Variant:
	var upper := word.to_upper()
	if upper.is_valid_int():
		return [false, upper.to_int()]
	if not upper.begins_with(player_name):
		return null
	var rest := upper.substr(player_name.length())
	if rest.is_empty():
		return [true, 0]
	if rest.is_valid_int() and (rest.begins_with("+") or rest.begins_with("-")):
		return [true, rest.to_int()]
	return null

## The tiles a set_tiles command covers right now, clamped inside the border,
## without anchors. Returns the rectangle under "rect" and the tiles under "cells".
static func resolve(command: Dictionary, grid: Array, player: Vector2i) -> Dictionary:
	var ends: Array = command["ends"]
	var xs: Array[int] = []
	var ys: Array[int] = []
	for i in 4:
		var base := (player.x if i % 2 == 0 else player.y) if ends[i][0] else 0
		(xs if i % 2 == 0 else ys).append(base + ends[i][1])
	var cols: int = grid[0].size()
	var rows := grid.size()
	var x0 := clampi(mini(xs[0], xs[1]), 1, cols - 2)
	var x1 := clampi(maxi(xs[0], xs[1]), 1, cols - 2)
	var y0 := clampi(mini(ys[0], ys[1]), 1, rows - 2)
	var y1 := clampi(maxi(ys[0], ys[1]), 1, rows - 2)
	var cells: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if grid[y][x] != ANCHOR:
				cells.append(Vector2i(x, y))
	return {"rect": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), "cells": cells}

static func grid_text(grid: Array, player: Vector2i, boss: Vector2i) -> String:
	var chars := {FLOOR: ".", WALL: "#", PIT: "o", LAVA: "~", ANCHOR: "A"}
	var lines: Array[String] = []
	for y in grid.size():
		var line := ""
		for x in grid[y].size():
			if Vector2i(x, y) == player:
				line += "P"
			elif Vector2i(x, y) == boss:
				line += "B"
			else:
				line += chars[grid[y][x]]
		lines.append("%2d %s" % [y, line])
	var header := "   "
	for x in grid[0].size():
		header += str(x % 10)
	return header + "\n" + "\n".join(lines)
