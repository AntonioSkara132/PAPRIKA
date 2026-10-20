class_name BattleGeneral
extends Node
## Lets the player command one army of the battle sandbox with typed orders, the
## way the squad is commanded in the Artichoke defense. Every block is one
## "soldier" for the order service (soldier 1, soldier 2, ...) and has a name
## such as "left spears" or "first line centre"; blocks of one kind also form a
## group ("spearmen", "cavalry", ...). Named places are clicked on the field and
## named with "mark here as ford". There is no limit on places; the first eight
## are the letters A to H the service knows, later ones L9, L10, ... are read
## only by the game.
##
## Simple orders are read here without the service: "spearmen to the ford",
## "first line attack", "cavalry attack at the ford", "rangers hold",
## "archers to the hill" (bowmen, longbowmen and rangers), "infantry hold"
## (everyone on foot), "melee attack" (spears, swords and cavalry),
## "swordsmen retreat", "everyone form a line from the ford to the hill".
## Several orders can be typed at once, separated by commas. "define fallback
## as: spearmen to the ridge, archers to the hill" (or "mark command fallback
## as: ...") saves them under a name; typing "fallback" then gives them all,
## and "forget command fallback" removes it.
## Anything else goes to the order service when it is running.

signal message(text: String)

const SERVICE_LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H"]
const PLACE_TOKEN := "[A-H]|L\\d+"  # how a place looks in rewritten order text
const RESERVED_WORDS := ["all", "everyone", "everybody", "soldier", "soldiers", "group", "here", "there", "line", "stop", "halt", "hold", "attack", "charge", "move", "go", "to", "and", "between", "from", "at", "mark", "forget", "retreat", "withdraw", "back", "facing", "face", "the", "a", "advance", "form"]
const KIND_GROUPS := {"spear": "spearmen", "sword": "swordsmen", "archer": "archers", "longbow": "longbowmen", "ranger": "rangers", "horse": "cavalry"}
# groups that cover several kinds: "archers to the ford" moves bowmen,
# longbowmen and rangers alike
const WIDE_GROUPS := {"archers": ["archer", "longbow", "ranger"], "infantry": ["spear", "sword", "archer", "longbow", "ranger"], "melee": ["spear", "sword", "horse"]}
const GROUP_WORDS := {"spears": "spearmen", "spearman": "spearmen", "swords": "swordsmen", "swordmen": "swordsmen", "swordsman": "swordsmen", "archer": "archers", "bowmen": "archers", "bowman": "archers", "shooters": "archers", "missile": "archers", "bows": "archers", "foot": "infantry", "footmen": "infantry", "meele": "melee", "mele": "melee", "longbows": "longbowmen", "longbowman": "longbowmen", "ranger": "rangers", "horse": "cavalry", "horsemen": "cavalry", "riders": "cavalry", "knights": "cavalry"}
const LINE_WORDS := ["first", "second", "third", "fourth", "fifth"]
const BLOCK_GAP := 20.0  # space between neighbouring blocks placed by one order

var battle: Node2D
var places: Dictionary = {}  # place id (A-H, then L9, L10, ...) -> Vector2
var place_names: Dictionary = {}  # place id -> name
var groups: Dictionary = {}  # name -> Array of soldier ids
var saved_commands: Dictionary = {}  # name -> the order text it stands for
var here := Vector2.INF  # the last point clicked on the field
var client: SquadOrderClient
var bar: LineEdit
var feedback: Label  # the last answer and Tab completions, just above the order bar
var _completion := {}  # "stem", "prefix", "matches", "index" while Tab cycles
var _ids: Dictionary = {}  # soldier id -> block index
var _names: Dictionary = {}  # soldier id -> block name without the team

func _init(owner_battle: Node2D) -> void:
	battle = owner_battle

func _ready() -> void:
	client = SquadOrderClient.new()
	add_child(client)
	client.order_ready.connect(_on_service_order)
	client.order_failed.connect(func(text: String) -> void: message.emit(text))
	var layer := CanvasLayer.new()
	add_child(layer)
	bar = LineEdit.new()
	bar.placeholder_text = "order, e.g. spearmen to the ford · Enter send · Esc close"
	bar.add_theme_font_size_override("font_size", 14)
	bar.visible = false
	layer.add_child(bar)
	bar.text_submitted.connect(_on_submitted)
	bar.text_changed.connect(func(_text: String) -> void: _completion.clear())
	feedback = Label.new()
	feedback.add_theme_font_size_override("font_size", 13)
	feedback.add_theme_color_override("font_outline_color", Color.BLACK)
	feedback.add_theme_constant_override("outline_size", 4)
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	layer.add_child(feedback)
	message.connect(func(text: String) -> void: feedback.text = text)
	get_viewport().size_changed.connect(_place_bar)
	_place_bar()

func _place_bar() -> void:
	var size := get_viewport().get_visible_rect().size
	bar.position = Vector2(8, size.y - 40)
	bar.size = Vector2(minf(700.0, size.x - 16), 32)
	feedback.position = Vector2(8, size.y - 100)
	feedback.size = Vector2(minf(900.0, size.x - 16), 56)

func typing() -> bool:
	return bar.visible

func open_bar(prefill: String = "") -> void:
	bar.visible = true
	bar.text = prefill
	bar.grab_focus()
	bar.caret_column = prefill.length()

func close_bar() -> void:
	bar.visible = false
	_completion.clear()
	bar.release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or battle.player_team < 0:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		open_bar()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not bar.visible or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		close_bar()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB:
		complete()
		get_viewport().set_input_as_handled()

## Every word or phrase Tab can complete: blocks, groups, places and order words.
func vocabulary() -> Array[String]:
	var words: Array[String] = ["everyone", "attack", "charge", "attack at", "hold", "retreat", "withdraw", "fall back", "form a line from", "facing", "mark here as", "forget", "stop"]
	for id: String in _ids:
		if standing_ids().has(id):
			words.append(_names[id])
	for group: String in groups:
		words.append(group)
	for k in LINE_WORDS.size():
		if groups.has("line%d" % (k + 1)):
			words.append("%s line" % LINE_WORDS[k])
	for letter: String in place_names:
		words.append("the " + place_names[letter])
	for command_name: String in saved_commands:
		words.append(command_name)
	words.append("define")
	return words

## Completes the words before the cursor; pressing Tab again shows the next match.
func complete() -> void:
	if _completion.is_empty():
		var before := bar.text.left(bar.caret_column)
		var words := before.split(" ")
		var found: Array[String] = []
		var stem := ""
		# try the last three, two, then one words, so "left sp" finds "left spears"
		for count in range(mini(3, words.size()), 0, -1):
			var prefix := " ".join(words.slice(words.size() - count)).to_lower()
			if prefix.strip_edges().is_empty():
				continue
			for word in vocabulary():
				if word.begins_with(prefix) and word != prefix and not found.has(word):
					found.append(word)
			if not found.is_empty():
				stem = " ".join(words.slice(0, words.size() - count))
				break
		if found.is_empty():
			message.emit("Nothing to complete. Try a block, group or place name.")
			return
		found.sort()
		_completion = {"stem": stem, "rest": bar.text.substr(bar.caret_column), "matches": found, "index": -1}
	_completion["index"] = (_completion["index"] + 1) % _completion["matches"].size()
	var pick: String = _completion["matches"][_completion["index"]]
	var head: String = (_completion["stem"] + " " if not _completion["stem"].is_empty() else "") + pick + " "
	var saved := _completion
	bar.text = head + _completion["rest"]
	bar.caret_column = head.length()
	_completion = saved
	if saved["matches"].size() > 1:
		feedback.text = "Tab: " + " · ".join(saved["matches"])

func _on_submitted(text: String) -> void:
	close_bar()
	submit(text)

## A click on the field: remember the spot and offer to name it.
func click(point: Vector2) -> void:
	here = point
	open_bar("mark here as ")

# --- the commanded army ---------------------------------------------------

## Names every block of the commanded army and makes the starting groups.
## Called after every new battle.
func take_command() -> void:
	_ids.clear()
	_names.clear()
	groups.clear()
	var lines := {}
	for b in battle.blocks.size():
		if battle.blocks[b]["team"] == battle.player_team:
			add_block(b)
	for id: String in _ids:
		var block: Dictionary = battle.blocks[_ids[id]]
		var line_name: String = block.get("line_name", "")
		if not line_name.is_empty():
			var key := "line%d" % (LINE_WORDS.find(line_name.get_slice(" ", 0)) + 1)
			lines[key] = true
			groups[key] = groups.get(key, []) + [id]

## Gives a block of the commanded army its soldier id, name and kind group.
func add_block(b: int) -> void:
	var id := "soldier_%02d" % (_ids.size() + 1)
	var block: Dictionary = battle.blocks[b]
	var base: String = block.get("line_name", block.get("title", ""))
	if base.is_empty():
		base = "%s %s" % [block["wing"], {"spear": "spears", "sword": "swords", "archer": "archers", "longbow": "longbowmen", "ranger": "rangers", "horse": "cavalry"}[block["kind"]]]
	var name := base
	var n := 2
	while _names.values().has(name):
		name = "%s %d" % [base, n]
		n += 1
	_ids[id] = b
	_names[id] = name
	block["order_name"] = name
	var group: String = KIND_GROUPS[block["kind"]]
	if not WIDE_GROUPS.has(group):
		groups[group] = groups.get(group, []) + [id]
	for wide: String in WIDE_GROUPS:
		if block["kind"] in WIDE_GROUPS[wide]:
			groups[wide] = groups.get(wide, []) + [id]

func block_label(b: int) -> String:
	for id: String in _ids:
		if _ids[id] == b:
			return "%d %s" % [int(id.get_slice("_", 1)), _names[id]]
	return ""

## Soldier ids of the blocks still able to take orders.
func standing_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _ids:
		var b: int = _ids[id]
		if not battle.blocks[b]["broken"] and battle._living(b) > 0:
			result.append(id)
	return result

# --- places ---------------------------------------------------------------

## ["mark", name] for "mark here as ford" or "mark ford here"; ["forget", name]
## for "forget ford"; [] for any other text.
func _place_command(text: String) -> Array:
	var patterns := [
		["mark", "^(mark|name|call)\\s+(here|this\\s+(place|spot))\\s+(as\\s+)?(?<name>.+?)[.!]?$"],
		["mark", "^mark\\s+(?<name>.+?)\\s+here[.!]?$"],
		["forget", "^(forget|unmark)\\s+(place\\s+)?(?<name>.+?)[.!]?$"],
	]
	for entry: Array in patterns:
		var regex := RegEx.new()
		regex.compile("(?i)" + entry[1])
		var found := regex.search(text.strip_edges())
		if found != null:
			return [entry[0], found.get_string("name")]
	return []

func mark_place(raw_name: String, at: Vector2) -> bool:
	if at == Vector2.INF:
		message.emit("Click the field first, then type mark here as <name>.")
		return false
	var place_name := " ".join(raw_name.strip_edges().to_lower().split(" ", false)).trim_prefix("the ")
	var regex := RegEx.new()
	regex.compile("^[a-z]+( [a-z]+){0,2}$")
	if place_name.length() < 2 or place_name.length() > 20 or regex.search(place_name) == null:
		message.emit("A place name is one to three words of letters, e.g. mark here as ford.")
		return false
	for word in place_name.split(" "):
		if RESERVED_WORDS.has(word) or GROUP_WORDS.has(word) or groups.has(word) or word.length() == 1:
			message.emit("\"%s\" means something else in orders; pick another name." % word)
			return false
	var letter := ""
	for existing: String in place_names:
		if place_names[existing] == place_name:
			letter = existing
	if letter.is_empty():
		if rewrite(place_name) != place_name:
			message.emit("\"%s\" already names a block or group; pick another name." % place_name)
			return false
		for free: String in SERVICE_LETTERS:
			if not places.has(free):
				letter = free
				break
		var n := SERVICE_LETTERS.size() + 1
		while letter.is_empty():
			if not places.has("L%d" % n):
				letter = "L%d" % n
			n += 1
	var moved := places.has(letter)
	places[letter] = at
	place_names[letter] = place_name
	message.emit(("Moved the %s." if moved else "Marked the %s. Orders can name it now.") % place_name)
	return true

func forget_place(raw_name: String) -> bool:
	var place_name := raw_name.strip_edges().to_lower().trim_prefix("the ")
	for letter: String in place_names:
		if place_names[letter] == place_name:
			places.erase(letter)
			place_names.erase(letter)
			message.emit("Forgot the %s." % place_name)
			return true
	message.emit("No place is called %s." % raw_name.strip_edges())
	return false

# --- reading orders -------------------------------------------------------

## Rewrites block names, line names and place names into the words the order
## service knows: "first line left to the ford" becomes "soldier 5 to A".
func rewrite(text: String) -> String:
	var result := " ".join(text.strip_edges().to_lower().split(" ", false))
	var named: Array = place_names.keys()
	named.sort_custom(func(a: String, b: String) -> bool: return place_names[a].length() > place_names[b].length())
	for letter: String in named:
		result = _replace_words(result, "(the )?" + place_names[letter], letter)
	var ids: Array = _names.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return _names[a].length() > _names[b].length())
	for id: String in ids:
		result = _replace_words(result, "(the )?" + _names[id], "soldier %d" % int(id.get_slice("_", 1)))
	for k in LINE_WORDS.size():
		result = _replace_words(result, "(the )?%s line" % LINE_WORDS[k], "line%d" % (k + 1))
	for word: String in GROUP_WORDS:
		result = _replace_words(result, word, GROUP_WORDS[word])
	return result

func _replace_words(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?i)\\b" + pattern + "\\b")
	return regex.sub(text, replacement, true)

func submit(text: String) -> bool:
	text = text.strip_edges()
	if text.is_empty() or battle.player_team < 0:
		return false
	if text.length() > 300:
		message.emit("Type an order of up to 300 characters.")
		return false
	var saved := _saved_command(text)
	if not saved.is_empty():
		return saved[0]
	if saved_commands.has(text.to_lower().trim_suffix(".").trim_suffix("!")):
		return _submit_text(saved_commands[text.to_lower().trim_suffix(".").trim_suffix("!")])
	return _submit_text(text)

## Handles "define fallback as: ...", "mark command fallback as: ..." and
## "forget command fallback".
## [result] when the text was one of them, [] otherwise.
func _saved_command(text: String) -> Array:
	var regex := RegEx.new()
	regex.compile("(?i)^(define(\\s+(command|order|orders))?|(mark|save|name)\\s+(command|order|orders))\\s+(?<name>.+?)\\s+as\\s*:?\\s*(?<body>.*)$")
	var found := regex.search(text)
	if found != null:
		var command_name := " ".join(found.get_string("name").to_lower().split(" ", false))
		var body := found.get_string("body").strip_edges()
		var check := RegEx.new()
		check.compile("^[a-z]+( [a-z]+){0,2}$")
		if check.search(command_name) == null or command_name.length() > 24:
			message.emit("A command name is one to three words of letters, e.g. define fallback as: spearmen to the ridge.")
			return [false]
		if body.is_empty():
			message.emit("Write the orders after the colon, e.g. define %s as: spearmen to the ridge, archers hold." % command_name)
			return [false]
		var replaced := saved_commands.has(command_name)
		saved_commands[command_name] = body
		message.emit("%s command %s. Type %s to give: %s" % ["Changed" if replaced else "Saved", command_name, command_name, body])
		return [true]
	regex.compile("(?i)^(forget|delete|remove)\\s+(command|order)\\s+(?<name>.+?)[.!]?$")
	found = regex.search(text)
	if found != null:
		var command_name := found.get_string("name").strip_edges().to_lower()
		if saved_commands.erase(command_name):
			message.emit("Forgot command %s." % command_name)
			return [true]
		message.emit("No command is called %s." % command_name)
		return [false]
	return []

func _submit_text(text: String) -> bool:
	var place_command := _place_command(text)
	if not place_command.is_empty():
		if place_command[0] == "mark":
			return mark_place(place_command[1], here)
		return forget_place(place_command[1])
	if text.to_lower() in ["stop", "halt", "hold"]:
		return execute({"action": "stop", "soldier_ids": standing_ids(), "start": null, "end": null, "facing": null, "message": "Everyone holds.", "group_name": null}, "typed")
	if text.contains(",") and _submit_several(text):
		return true
	var rewritten := rewrite(text)
	var order := parse(rewritten)
	if order.get("action") == "unknown":
		message.emit("No standing block or group is called %s. Groups: %s." % [order["who"], ", ".join(groups.keys())])
		return false
	if not order.is_empty():
		return execute(order, "read in the game")
	if client.compatible:
		var extra := RegEx.new()
		extra.compile("\\bL\\d+\\b")
		if extra.search(rewritten) != null:
			message.emit("The order service knows only the first eight places. Use one of them, or a simpler order such as spearmen to the ford.")
			return false
		message.emit("Asking the order service…")
		return client.submit(rewritten, order_context())
	message.emit("Could not read that order, and the order service is not running. Try e.g. spearmen to the ford.")
	return false

## Carries out several orders separated by commas: "spearmen to the ford,
## archers hold, cavalry attack". A piece that is not a whole order, such as
## "spearmen" in "spearmen, swordsmen to the ford", joins the next piece.
## Returns false, having done nothing, when no piece is an order the game reads.
func _submit_several(text: String) -> bool:
	var orders: Array[Dictionary] = []
	var buffer := ""
	for piece in text.split(","):
		buffer = piece if buffer.is_empty() else buffer + "," + piece
		var order := parse(rewrite(buffer))
		if not order.is_empty() and order.get("action") != "unknown":
			orders.append(order)
			buffer = ""
	if orders.is_empty():
		return false
	var answers: Array[String] = []
	for order in orders:
		execute(order, "read in the game")
		answers.append(feedback.text)
	if not buffer.strip_edges().is_empty():
		answers.append("Could not read: %s" % buffer.strip_edges())
	message.emit(" ".join(answers))
	return true

## Reads the simple orders without the service. Expects rewritten text.
func parse(text: String) -> Dictionary:
	var who := "(?<who>(everyone|everybody|all|soldier \\d+|[a-z][a-z0-9_-]*)((\\s*,\\s*|\\s+and\\s+)(soldier \\d+|[a-z][a-z0-9_-]*))*)"
	var place := "(?<end>" + PLACE_TOKEN + ")"
	var facing := "(\\s+(and\\s+)?fac(e|ing)\\s+(?<facing>" + PLACE_TOKEN + "))?"
	var forms := [
		["form_line", "^" + who + ",?\\s+form\\s+(a\\s+)?line\\s+(from|between)\\s+(?<start>" + PLACE_TOKEN + ")\\s+(to|and)\\s+" + place + facing + "[.!]?$"],
		["attack", "^" + who + ",?\\s+(attack|charge|advance)(\\s+(the\\s+enemy\\s+)?(at|near|by|on)?\\s*" + place + ")?[.!]?$"],
		["withdraw", "^" + who + ",?\\s+(retreat|withdraw|fall\\s+back|pull\\s+back)[.!]?$"],
		["move_to", "^" + who + ",?\\s+(retreat|withdraw|fall\\s+back|pull\\s+back)\\s+to\\s+" + place + facing + "[.!]?$"],
		["stop", "^" + who + ",?\\s+(hold|stop|halt|stand)(\\s+(fast|here|still|your\\s+ground))?[.!]?$"],
		["move_to", "^(send\\s+)?" + who + ",?\\s+((go|move|march|run|ride|walk)\\s+)?(to|towards?)\\s+" + place + facing + "[.!]?$"],
	]
	for form: Array in forms:
		var regex := RegEx.new()
		regex.compile(form[1])
		var found := regex.search(text)
		if found == null:
			continue
		var ids := _who(found.get_string("who"))
		if ids.is_empty():
			return {"action": "unknown", "who": found.get_string("who")}
		var order := {"action": form[0], "soldier_ids": ids, "start": null, "end": null, "facing": null, "message": text, "group_name": null}
		for key in ["start", "end", "facing"]:
			var value := found.get_string(key)
			if not value.is_empty():
				order[key] = value
		return order
	return {}

## Soldier ids for "spearmen and soldier 3", "everyone", "line1". [] when a name
## is unknown.
func _who(text: String) -> Array[String]:
	var result: Array[String] = []
	for part in text.replace(",", " and ").split(" and ", false):
		part = part.strip_edges()
		var ids: Array = []
		if part in ["everyone", "everybody", "all"]:
			ids = standing_ids()
		elif part.begins_with("soldier "):
			ids = ["soldier_%02d" % int(part.get_slice(" ", 1))]
		elif groups.has(part):
			ids = groups[part]
		else:
			return []
		for id: String in ids:
			if _ids.has(id) and not result.has(id) and standing_ids().has(id):
				result.append(id)
	return result

func order_context() -> Dictionary:
	var soldiers: Array = []
	var ids := standing_ids()
	for id in ids:
		var centre: Vector2 = battle._centre(_ids[id])
		soldiers.append({"id": id, "position": [centre.x, centre.y]})
	var group_data: Dictionary = {"all": ids}
	for group_name: String in groups:
		var members: Array = groups[group_name].filter(func(id: String) -> bool: return ids.has(id))
		if not members.is_empty():
			group_data[group_name] = members
	var landmarks: Dictionary = {}
	for letter: String in places:
		if letter in SERVICE_LETTERS:
			landmarks[letter] = [places[letter].x, places[letter].y]
	return {"soldiers": soldiers, "groups": group_data, "landmarks": landmarks}

func _on_service_order(order: Dictionary, source: String) -> void:
	execute(order, source)

# --- carrying orders out --------------------------------------------------

func execute(order: Dictionary, source: String) -> bool:
	var action: String = order.get("action", "")
	# "withdraw" exists only in the battle, so the service's check does not know it
	if action != "withdraw":
		var checked := SandboxFormationPlanner.validate_order(order, standing_ids(), places, groups)
		if not checked["ok"]:
			message.emit(checked["error"])
			return false
	var ids: Array = order.get("soldier_ids", [])
	match action:
		"clarify":
			message.emit(str(order.get("message", "Which blocks, and where?")))
			return false
		"create_group":
			groups[str(order["group_name"]).to_lower()] = ids.duplicate()
			message.emit("Group %s: %s." % [order["group_name"], _list(ids)])
			return true
		"follow_player", "patrol":
			message.emit("There is no %s in a battle; send blocks to a place or let them attack." % ("general on the field to follow" if action == "follow_player" else "patrolling"))
			return false
	if ids.is_empty():
		message.emit("No standing block was named.")
		return false
	var blocks: Array[int] = []
	for id: String in ids:
		blocks.append(_ids[id])
	match action:
		"stop":
			for b in blocks:
				battle.order_hold(b)
			message.emit("%s hold where they stand." % _list(ids))
		"withdraw":
			for b in blocks:
				battle.order_withdraw(b)
			message.emit("%s pull back." % _list(ids))
		"attack":
			for b in blocks:
				battle.order_attack(b, places.get(order["end"], Vector2.INF) if order["end"] != null else Vector2.INF)
			message.emit("%s attack%s." % [_list(ids), (" at the " + place_names[order["end"]]) if order["end"] != null else ""])
		"move_to":
			_place_blocks(blocks, places[order["end"]], places[order["end"]], order["facing"])
			message.emit("%s march to the %s." % [_list(ids), place_names[order["end"]]])
		"form_line":
			_place_blocks(blocks, places[order["start"]], places[order["end"]], order["facing"])
			message.emit("%s form a line from the %s to the %s." % [_list(ids), place_names[order["start"]], place_names[order["end"]]])
		_:
			message.emit("The battle does not use %s orders." % action)
			return false
	if source != "read in the game" and source != "typed":
		message.emit("(%s) %s" % [source, order.get("message", "")])
	return true

## Spreads the blocks side by side from `from` to `to` (one point for a move),
## each facing the facing place, or the enemy when none is given.
func _place_blocks(blocks: Array[int], from: Vector2, to: Vector2, facing: Variant) -> void:
	var centre := (from + to) * 0.5
	var heading: Vector2
	if facing != null and places.has(facing):
		heading = (places[facing] - centre).normalized()
	else:
		heading = (battle.enemy_centre(battle.player_team) - centre).normalized()
	if heading == Vector2.ZERO:
		heading = Vector2.RIGHT if battle.player_team == 0 else Vector2.LEFT
	var widths: Array[float] = []
	var total := 0.0
	for b in blocks:
		widths.append(battle.block_width(b))
		total += widths[-1]
	var along := heading.orthogonal()
	var span := 0.0
	if from != to:
		along = (to - from).normalized()
		span = from.distance_to(to)
	var gap := BLOCK_GAP if blocks.size() < 2 or span <= total else (span - total) / (blocks.size() - 1)
	var length := total + gap * (blocks.size() - 1)
	# blocks nearer `from` go first, so blocks crossing each other is rare
	var order := range(blocks.size())
	order.sort_custom(func(a: int, b: int) -> bool: return battle._centre(blocks[a]).dot(along) < battle._centre(blocks[b]).dot(along))
	var cursor := -length * 0.5
	for k in order:
		var spot := centre + along * (cursor + widths[k] * 0.5)
		battle.order_move(blocks[k], spot, heading)
		cursor += widths[k] + gap

func _list(ids: Array) -> String:
	var names: Array = []
	for id: String in ids:
		names.append(_names.get(id, id))
	if names.size() > 4:
		return "%d blocks" % names.size()
	return ", ".join(names).capitalize() if names.size() == 1 else ", ".join(names)

# --- drawing --------------------------------------------------------------

func draw_on(canvas: Node2D) -> void:
	var font := ThemeDB.fallback_font
	for letter: String in places:
		var point: Vector2 = places[letter]
		canvas.draw_arc(point, 26.0, 0.0, TAU, 32, Color("f5c34c"), 5.0)
		canvas.draw_string_outline(font, point + Vector2(-120, -36), place_names[letter], HORIZONTAL_ALIGNMENT_CENTER, 240, 40, 8, Color.BLACK)
		canvas.draw_string(font, point + Vector2(-120, -36), place_names[letter], HORIZONTAL_ALIGNMENT_CENTER, 240, 40, Color("f5c34c"))
	if here != Vector2.INF:
		canvas.draw_line(here + Vector2(-8, -8), here + Vector2(8, 8), Color.WHITE, 2.0)
		canvas.draw_line(here + Vector2(-8, 8), here + Vector2(8, -8), Color.WHITE, 2.0)
	for id: String in _ids:
		var b: int = _ids[id]
		if battle.blocks[b]["broken"] or battle._living(b) == 0:
			continue
		var top: Vector2 = battle._centre(b) + Vector2(0, -52)
		canvas.draw_string_outline(font, top + Vector2(-100, 0), block_label(b), HORIZONTAL_ALIGNMENT_CENTER, 200, 24, 6, Color.BLACK)
		canvas.draw_string(font, top + Vector2(-100, 0), block_label(b), HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color.WHITE)
		var block: Dictionary = battle.blocks[b]
		if block.get("retiring", false) and block.has("home_leader"):
			canvas.draw_dashed_line(battle._centre(b), block["home_leader"], Color(1, 1, 1, 0.5), 2.0, 8.0)

func _process(_delta: float) -> void:
	feedback.visible = battle.player_team >= 0 and not feedback.text.is_empty()

func status_lines() -> Array[String]:
	var result: Array[String] = []
	var names: Array = []
	for letter: String in places:
		names.append(place_names[letter])
	result.append("You command %s. Click the field and type mark here as <name> to name a place. Enter: type an order. Places: %s" % [["Blue", "Red"][battle.player_team], ", ".join(names) if not names.is_empty() else "none yet"])
	if not saved_commands.is_empty():
		result.append("Saved commands: %s" % ", ".join(saved_commands.keys()))
	result.append("Groups: %s · lines: line1-line4 or first line … · order service: %s" % [", ".join(groups.keys().filter(func(g: String) -> bool: return not g.begins_with("line"))), client.status])
	return result
