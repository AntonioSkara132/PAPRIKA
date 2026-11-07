class_name OtpornikWorld
extends GameWorld

## Otpornik: the passenger port, the used-ship yards and the town below the
## university. The party comes here from Iskra to buy an interplanetary ship.
## The university is scenery; none of its buildings can be entered.
##
## The Lasta's three floors are in open space below the port on the same map
## (built by tools/build_otpornik_world.py). Ladders, the hatch, the stairs and
## the airlock move the player, Davor and Veki between them.
##
## The first flight to R-7 from the helm is a ship battle against the scrap
## thieves from the yards (fly_to_rock()). A win sets the "scrap_battle_won"
## flag and flies on; a loss brings the Lasta back to the pad and the helm
## offers the flight again. The battle is not saved halfway.

const OTPORNIK_MAP := "res://maps/otpornik.tmj"
const FLAG_PREFIX := "otpornik_"
const LASTA_PRICE := 2000
const YARD_PAY := 250
const YARD_RUNS := 5
const SCAVENGERS := [
	["yard_scavenger_sword", "res://assets/art/iskra/npcs/punk_leather.png"],
	["yard_scavenger_spear", "res://assets/art/iskra/npcs/punk_denim.png"],
	["yard_scavenger_bow", "res://assets/art/iskra/npcs/punk_crust.png"],
	["yard_scavenger_sword", "res://assets/art/iskra/npcs/punk_tartan.png"],
]
## Location titles of the Lasta's floors.
## The Lasta's floors lie below this line, in the open space under the port.
const ROOM_TOP := 1888.0
## The port and each floor of the Lasta in map pixels, as built by
## tools/build_otpornik_world.py. The camera stays inside the current one.
const PORT_RECT := Rect2(0, 0, 2560, 1792)
const ROOM_RECTS := {
	"ship_deck": Rect2(64, 1984, 576, 224),
	"ship_upper": Rect2(960, 1984, 576, 288),
	"ship_lower": Rect2(1856, 1984, 384, 224),
}
const ROOM_TITLES := {"ship_deck": "LASTA · TOP DECK", "ship_upper": "LASTA · CONTROL ROOM", "ship_lower": "LASTA · BUNKS AND STORE"}
const RESIDENT_LINES := [
	"Half the town studied at the university, and the other half fixes what the students break.",
	"The copper towers hum before a storm. The High-Voltage Lab says it is an experiment; we say it is the weather.",
	"The engineers from Blockovia came with nothing. Now their grandchildren run the yards.",
	"Cafe Ohm burns its coffee on purpose. Students drink it before exams.",
	"The beach is nice, but do not walk past the cliff. There is nothing under it but space.",
	"Scrap thieves come over the yard fence at night. The foreman pays anyone who can chase them off.",
	"Every ship in Engineeria passed through these yards at least once, for building or for mending.",
	"The university keeps its gates shut to visitors this term. Exams, they say.",
]
## Radio lines in the scrap thieves' battle, on the first flight to R-7. The
## player learned the controls from Klara on the Chvarak diplomatic ship, so
## Veki only reminds them. See ShipBattle.lines for the events.
const SCRAP_BATTLE_LINES := {
	"start": [["Veki", "You've fired ship launchers before? Good. Same keys here."],
		["Veki", "Q fires left, E fires right, Space the side facing them."],
		["Veki", "The Lasta has three launchers a side. Make them count."],
		["Thief", "Nice plates on that old tub. We'll take them, thanks!"]],
	"side_open": [["Veki", "They're off our {side}. Fire!"]],
	"hit": [["Veki", "That claw tore a plate off! Don't let them touch us."],
		["Davor", "They're slow. Turn away and give them a side."]],
	"low": [["Veki", "She can't take much more of this!"]],
	"won": [["Veki", "Their engine's dead. They're not going anywhere."]],
	"lost": [["Veki", "Too many holes. I'm turning back to Otpornik!"]],
}

var markers: Dictionary = {}
var davor: RaidSoldier
var veki: RaidSoldier
var people: Dictionary = {}
var drive_sprite: Sprite2D
var _drive_frames: Array[Texture2D] = []
var _drive_time := 0.0
var _yard_enemies: Array = []
var _ship_spots: Array[Node2D] = []

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(OTPORNIK_MAP):
		push_error("Otpornik map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OTPORNIK_MAP))
	for layer: Dictionary in data["layers"]:
		if layer["name"] == "Markers":
			for point: Dictionary in layer["objects"]:
				markers[point["name"]] = Vector2(point["x"], point["y"])
	_spawn_player(GameState.OTPORNIK_ARRIVAL, "res://art/concepts/source/player.png")
	player.respawn_position = marker("respawn")
	player.respawn_location_name = "Otpornik passenger terminal"
	_spawn_companions()
	_spawn_staff()
	_spawn_ship_spots()
	_spawn_drive()
	apply_loaded_state()
	call_deferred("_arrival_scene")

func marker(id: String) -> Vector2:
	return Vector2(markers.get(id, GameState.OTPORNIK_ARRIVAL))

func has_flag(id: String) -> bool:
	return GameState.defeated_persistent_enemies.has(FLAG_PREFIX + id)

func set_flag(id: String) -> void:
	if not has_flag(id):
		GameState.defeated_persistent_enemies.append(FLAG_PREFIX + id)
		GameState.military_changed.emit()

func yard_runs_done() -> int:
	var count := 0
	for run in YARD_RUNS:
		if has_flag("yard_paid_%d" % run):
			count += 1
	return count

## The floor of the Lasta the player stands on, or "" in the port.
func current_room(at: Vector2 = Vector2.INF) -> String:
	var spot := player.global_position if at == Vector2.INF and player != null else at
	if spot.y < ROOM_TOP:
		return ""
	for room: String in ROOM_RECTS:
		if spot.x < (ROOM_RECTS[room] as Rect2).end.x + 64.0:
			return room
	return "ship_lower"

## Keeps the camera inside the port or the current floor. A floor narrower or
## shorter than the view is centred, with open space round it.
func refresh_camera() -> void:
	if _camera == null:
		return
	var room := current_room()
	var rect: Rect2 = PORT_RECT if room.is_empty() else ROOM_RECTS[room]
	var view := get_viewport_rect().size / _camera.zoom
	var grow := Vector2(maxf(0.0, view.x - rect.size.x), maxf(0.0, view.y - rect.size.y)) / 2.0
	_camera.limit_left = int(rect.position.x - grow.x)
	_camera.limit_right = int(rect.end.x + grow.x)
	_camera.limit_top = int(rect.position.y - grow.y)
	_camera.limit_bottom = int(rect.end.y + grow.y)
	_camera.reset_smoothing()

func location_title() -> String:
	var room := current_room()
	return ROOM_TITLES[room] if not room.is_empty() else "OTPORNIK — SPACEPORT"

func story_status_text() -> String:
	if GameState.davor_taken():
		return "Martin took Davor on R-7. Find out where his ship went."
	if has_flag("lasta_bought"):
		return "The Lasta is yours. Talk to Veki at the helm when you are ready to fly."
	var text := "Buy an interplanetary ship at the Ship Broker: the Lasta costs %d gold." % LASTA_PRICE
	if GameState.gold < LASTA_PRICE:
		text += "\nEarn the rest from the Yard Foreman at the construction bay (%d/%d jobs)." % [yard_runs_done(), YARD_RUNS]
	if not _yard_enemies.is_empty():
		text += "\nYard job: drive the scavengers out of the construction bay (%d left)." % _yard_enemies.size()
	return text

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if saved.is_finite() and tiled_loader.is_walkable_position(saved) and (has_flag("lasta_bought") or current_room(saved).is_empty()):
		return saved
	return marker("arrival")

func capture_player_position() -> void:
	GameState.remember_player_position(player.global_position)

func apply_loaded_state() -> void:
	close_ship_battle()
	_clear_yard_job()
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	_place_companions()
	refresh_camera()

func _on_player_respawned() -> void:
	_clear_yard_job()
	super._on_player_respawned()
	_place_companions()
	refresh_camera()

# ---------- party ----------

func _spawn_companions() -> void:
	_spawn_veki()
	# After R-7, Martin has Davor.
	if GameState.davor_taken():
		return
	davor = RaidSoldier.new()
	davor.name = "Davor"
	davor.configure("davor", "Davor", "res://assets/art/engineeria/davor.png", GameState.OTPORNIK_ARRIVAL, "sword", 0, self)
	davor.max_health = 260
	davor.health = 260
	davor.speed = 100.0
	davor.strike_damage = 30
	davor.strike_cooldown = 0.6
	davor.follow_sight = 140.0
	davor.can_leap = true
	davor.get_up_seconds = 0.0
	actors_root.add_child(davor)
	GameState.apply_davor_health(davor)

func _spawn_veki() -> void:
	veki = RaidSoldier.new()
	veki.name = "Veki"
	veki.configure("veki", "Veki", "res://assets/art/iskra/npcs/veki.png", GameState.OTPORNIK_ARRIVAL, "sword", 1, self)
	veki.max_health = 140
	veki.health = 140
	veki.speed = 100.0
	actors_root.add_child(veki)

## Davor and Veki stand beside the player after arrival, a load or a change of floor.
func _place_companions() -> void:
	for pair in [[davor, Vector2(-24, 16)], [veki, Vector2(24, 16)]]:
		var companion: RaidSoldier = pair[0]
		if companion == null:
			continue
		companion.global_position = tiled_loader.nearest_walkable_position(player.global_position + pair[1])
		companion.velocity = Vector2.ZERO
		companion.set_order("follow")

func _unhandled_input(event: InputEvent) -> void:
	if veki != null and player != null and not get_tree().paused and not player.ui_is_open():
		for order in ["follow", "hold", "attack"]:
			if event.is_action_pressed("order_" + order):
				for companion in [davor, veki]:
					if companion != null and not companion.down:
						companion.set_order(order)
				var names := "Davor and Veki" if davor != null else "Veki"
				GameState.notify(names + {"follow": ": following you.", "hold": ": holding this position.", "attack": ": attacking nearby enemies."}[order])
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)

func move_party(to: Vector2) -> void:
	player.global_position = to
	player.velocity = Vector2.ZERO
	_place_companions()
	GameState.remember_player_position(to)
	refresh_camera()
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null:
		ui.refresh_location()

# ---------- people ----------

func _on_actor_spawn_requested(kind: String, position: Vector2, texture: String, id: String) -> void:
	if kind != "story":
		return
	var resident := IskraCitizen.new()
	resident.configure(id, "Otpornik Resident", texture, position, tiled_loader)
	resident.service_id = "otpornik:" + id
	actors_root.add_child(resident)
	resident.service_requested.connect(_on_service_requested)
	people[id] = resident

func _spawn_staff() -> void:
	var entries := {
		"terminal": ["Line Clerk", "board_officer"],
		"broker": ["Ship Broker", "civic_engineer"],
		"foreman": ["Yard Foreman", "dock_mechanic"],
		"porter": ["University Porter", "library_archivist"],
	}
	for id: String in entries:
		var staff := StationStaff.new()
		staff.configure("otpornik:" + id, entries[id][0], "res://assets/art/iskra/npcs/%s.png" % entries[id][1], marker(id))
		actors_root.add_child(staff)
		staff.service_requested.connect(_on_service_requested)
		people[id] = staff

## Invisible places to interact with on and around the Lasta.
class ShipSpot extends Node2D:
	signal used(id: String)
	var spot_id := ""
	var text := ""
	var enabled := Callable()

	func _ready() -> void:
		add_to_group("interactable")

	func get_interaction_text() -> String:
		return text if not enabled.is_valid() or enabled.call() else ""

	func interact(_actor: Node) -> void:
		if not enabled.is_valid() or enabled.call():
			used.emit(spot_id)

func _spawn_ship_spots() -> void:
	var spots := {
		"lasta": "Board the Lasta",
		"ship_deck_hatch": "Climb down the hatch",
		"ship_deck_ladder": "Climb down to the pad",
		"ship_deck_mast": "Look at the mast",
		"ship_upper_airlock": "Leave the ship",
		"ship_upper_ladder": "Climb up to the top deck",
		"ship_upper_stairs": "Go down to the bunks",
		"ship_upper_helm": "Talk to Veki at the helm",
		"ship_upper_drive": "Look at the drive",
		"ship_upper_table": "Look at the star chart",
		"ship_upper_posters": "Look at the posters",
		"ship_lower_stairs": "Go up to the control room",
		"ship_lower_bunk": "Rest in a bunk",
		"ship_lower_captain_bed": "Look at the captain's bed",
		"ship_lower_store": "Look through the store room",
	}
	for id: String in spots:
		var spot := ShipSpot.new()
		spot.name = "Spot_" + id
		spot.spot_id = id
		spot.text = spots[id]
		spot.global_position = marker(id)
		if id == "lasta":
			spot.text = "Look at the old ship on pad 1"
		actors_root.add_child(spot)
		spot.used.connect(_on_ship_spot)
		_ship_spots.append(spot)

func _refresh_lasta_spot() -> void:
	for spot in _ship_spots:
		if spot.spot_id == "lasta":
			spot.text = "Board the Lasta" if has_flag("lasta_bought") else "Look at the old ship on pad 1"

func _spawn_drive() -> void:
	for phase in 4:
		_drive_frames.append(load("res://assets/art/otpornik/drive_%d.png" % phase) as Texture2D)
	drive_sprite = Sprite2D.new()
	drive_sprite.name = "Drive"
	drive_sprite.texture = _drive_frames[0]
	drive_sprite.centered = false
	drive_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drive_sprite.scale = Vector2(2, 2)
	drive_sprite.position = marker("ship_upper_machine")
	drive_sprite.z_index = 100 + int(drive_sprite.position.y + _drive_frames[0].get_height() * 2)
	add_child(drive_sprite)
	_refresh_lasta_spot()

func _process(delta: float) -> void:
	if drive_sprite != null and not _drive_frames.is_empty():
		_drive_time += delta
		drive_sprite.texture = _drive_frames[int(_drive_time * 6.0) % _drive_frames.size()]
	if not _yard_enemies.is_empty():
		_yard_enemies = _yard_enemies.filter(func(enemy) -> bool: return is_instance_valid(enemy) and (enemy as Enemy).health > 0)
		if _yard_enemies.is_empty() and has_flag("yard_active"):
			GameState.notify("The construction bay is clear. Collect your pay from the Yard Foreman.")

# ---------- scenes ----------

func _ui() -> GameUI:
	return get_tree().get_first_node_in_group("game_ui") as GameUI

func _line(speaker: String, text: String) -> Dictionary:
	var focus: Node2D = davor if speaker == "Davor" else veki if speaker == "Veki" else null
	return {"speaker": speaker, "text": text, "focus": focus}

func _scene(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := _ui()
	if ui != null:
		ui.play_scene(lines, finished, choices)
	else:
		for line: Dictionary in lines:
			GameState.notify(String(line["text"]))
		if finished.is_valid():
			finished.call()

func _tell(speaker: String, text: String, choices: Array = []) -> void:
	_scene([_line(speaker, text)], Callable(), choices)

func _choice(label: String, action: Callable) -> Dictionary:
	return {"label": label, "action": action}

func _arrival_scene() -> void:
	if has_flag("arrival"):
		return
	set_flag("arrival")
	_scene([
		_line("", "The passenger line sets down on Otpornik in the morning. Past the terminal, the town climbs toward two copper towers."),
		_line("Davor", "Those towers with the lightning between them. Is that the school?"),
		_line("Veki", "The university. Engineeria's best minds, and it keeps its gates shut to people like us. We are here for the yards."),
		_line("Veki", "The Ship Broker's office is the one with the yellow sign, by the control tower. Let's see what your Council's gold buys."),
	], func() -> void: GameState.notify("Find the Ship Broker by the control tower."))

func _on_service_requested(id: String, _title: String) -> void:
	var key := id.trim_prefix("otpornik:")
	if key.begins_with("resident_"):
		_tell("Otpornik Resident", RESIDENT_LINES[int(key.trim_prefix("resident_")) % RESIDENT_LINES.size()])
		return
	match key:
		"terminal": _terminal()
		"broker": _broker()
		"foreman": _foreman()
		"porter": _tell("University Porter", "The university is closed to visitors this term. Lectures, exams and the High-Voltage Lab are for enrolled students only. The town and the yards are open to everyone.")

func _terminal() -> void:
	if GameState.davor_taken():
		_scene([
			_line("Line Clerk", "The passenger line to Iskra leaves from here."),
			_line("Veki", "Iskra can wait. Martin has Davor, and every day we lose, he takes him further away."),
		])
		return
	_tell("Line Clerk", "The passenger line to Iskra leaves from here. Your Tower passes cover the return as well.", [
		_choice("Take the line back to Iskra", func() -> void: story_travel_requested.emit("iskra")),
		_choice("Stay on Otpornik", Callable()),
	])

func _broker() -> void:
	if has_flag("lasta_bought"):
		_tell("Ship Broker", "The Lasta's papers are in your name now. She has flown longer than I have been selling ships. Treat her kindly.")
		return
	var lines := [
		_line("Ship Broker", "Looking for a ship that can jump between planets? Then you are in the right office."),
		_line("Ship Broker", "The one on pad 3 is nearly new: twelve thousand. The one in the repair gantry needs a new drive, so six thousand, and you pay for the drive."),
		_line("Ship Broker", "And the old girl on pad 1, the Lasta. Fifty years in service, rebuilt more times than anyone counted. The drive is sound. %d gold, not a coin less." % LASTA_PRICE),
		_line("Veki", "The Lasta. Patched hull, and someone panelled her inside with wood. But if the drive is sound, she will get us to Breece."),
	]
	if has_flag("broker_met"):
		lines = [_line("Ship Broker", "The Lasta is still on pad 1. %d gold and she is yours." % LASTA_PRICE)]
	set_flag("broker_met")
	_scene(lines, Callable(), [
		_choice("Buy the Lasta — %d gold" % LASTA_PRICE, buy_lasta),
		_choice("Not yet", Callable()),
	])

func buy_lasta() -> bool:
	if has_flag("lasta_bought"):
		return false
	if not GameState.spend_gold(LASTA_PRICE):
		_scene([
			_line("Ship Broker", "You have %d gold. The Lasta costs %d. Come back when you have it all." % [GameState.gold, LASTA_PRICE]),
			_line("Veki", "The Yard Foreman at the construction bay pays fighters to chase scrap thieves out of the yards. That is where the rest of the money is."),
		])
		return false
	set_flag("lasta_bought")
	_refresh_lasta_spot()
	_scene([
		_line("Ship Broker", "Two thousand. Here are her papers and the keys to the airlock. The Lasta is yours."),
		_line("Davor", "Our own ship. Martin will not like that."),
		_line("Veki", "Let's go aboard. I want to see that drive before I fly her anywhere."),
	], func() -> void: GameState.notify("You bought the Lasta. Board her on pad 1."))
	return true

# ---------- yard job ----------

func _foreman() -> void:
	if has_flag("yard_active"):
		if _yard_enemies.is_empty():
			_pay_yard_job()
		else:
			_tell("Yard Foreman", "They are still in the construction bay. %d of them. Get them out and I will pay you." % _yard_enemies.size())
		return
	if has_flag("lasta_bought"):
		_tell("Yard Foreman", "You bought the Lasta? Then you are a ship owner now, not my hired help. Good luck out there.")
		return
	if yard_runs_done() >= YARD_RUNS:
		_tell("Yard Foreman", "The thieves have learned to stay away from my yard. I have no more work for you.")
		return
	_scene([
		_line("Yard Foreman", "Scrap thieves. They come over the fence and strip the plates off the hulls in the construction bay."),
		_line("Yard Foreman", "Drive them out and I pay %d gold. They come back every few hours, so there is more work after that." % YARD_PAY),
	], Callable(), [
		_choice("Clear the construction bay", start_yard_job),
		_choice("Not now", Callable()),
	])

func start_yard_job() -> bool:
	if has_flag("yard_active") or has_flag("lasta_bought") or yard_runs_done() >= YARD_RUNS:
		return false
	set_flag("yard_active")
	var run := yard_runs_done()
	var count := 3 + mini(run, 2)
	for i in count:
		var data: Array = SCAVENGERS[(i + run) % SCAVENGERS.size()]
		var enemy := Enemy.new()
		var stable_id := "story_otpornik_scavenger_%d_%d" % [run, i]
		enemy.name = stable_id
		enemy.configure(String(data[0]), String(data[1]), marker("scavenger_%d" % (i % 6)), stable_id)
		actors_root.add_child(enemy)
		_yard_enemies.append(enemy)
	GameState.notify("%d scrap thieves are stripping hulls in the construction bay." % count)
	return true

func _pay_yard_job() -> void:
	var run := yard_runs_done()
	_remove_flag("yard_active")
	set_flag("yard_paid_%d" % run)
	GameState.add_gold(YARD_PAY)
	_tell("Yard Foreman", "That is the last of them for today. Here are %d gold." % YARD_PAY)
	GameState.notify("The Yard Foreman paid you %d gold." % YARD_PAY)

func _remove_flag(id: String) -> void:
	GameState.defeated_persistent_enemies.erase(FLAG_PREFIX + id)
	GameState.military_changed.emit()

## A job in progress is not saved: after a load or a defeat the foreman offers it again.
func _clear_yard_job() -> void:
	for enemy in _yard_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_yard_enemies.clear()
	if has_flag("yard_active"):
		_remove_flag("yard_active")

# ---------- the Lasta ----------

func _on_ship_spot(id: String) -> void:
	match id:
		"lasta":
			if not has_flag("lasta_bought"):
				_tell("", "An old ship on pad 1, her hull patched with plates of every color. LASTA is painted on the side in faded letters. A card in the airlock window reads: FOR SALE, ASK AT THE SHIP BROKER.")
				return
			_scene([_line("", "The Lasta's ramp is down, and a ladder runs up her side to the top deck.")], Callable(), [
				_choice("Go inside", func() -> void: move_party(marker("ship_upper_airlock"))),
				_choice("Climb to the top deck", func() -> void: move_party(marker("ship_deck_ladder"))),
				_choice("Stay on the pad", Callable()),
			])
		"ship_deck_hatch": move_party(marker("ship_upper_ladder"))
		"ship_deck_ladder": move_party(marker("lasta"))
		"ship_deck_mast": _tell("", "A beacon and a bundle of antenna wire on an iron mast. A sign on the hatch says SEAL BEFORE LAUNCH: the deck is only open while the Lasta stands on the ground.")
		"ship_upper_airlock": move_party(marker("lasta"))
		"ship_upper_ladder": move_party(marker("ship_deck_hatch"))
		"ship_upper_stairs": move_party(marker("ship_lower_stairs"))
		"ship_lower_stairs": move_party(marker("ship_upper_stairs"))
		"ship_upper_helm": _helm()
		"ship_upper_drive": _scene([
			_line("", "Four square cylinders pump on a bed of flagstones. Under them, behind a brass window, the star drive glows."),
			_line("Veki", "Old, but someone kept it oiled. Hear that? Even beat. This drive has made more jumps than both of us together."),
		])
		"ship_upper_table": _tell("", "A star chart is pinned to the map table with a knife. Someone has marked Otpornik, Iskra and Skoljka, and drawn a long dashed line out toward Breece.")
		"ship_upper_posters": _scene([
			_line("", "Faded posters hang between the viewports: a woman in a red swimsuit leaning back on a ringed planet, another waving from a deck chair."),
			_line("Davor", "The last crew had taste."),
			_line("Veki", "The last crew had fifty years of long flights. They stay."),
		])
		"ship_lower_bunk":
			GameState.restore_health()
			if davor != null:
				davor.health = davor.max_health
			_tell("", "You rest for a while in a bunk that smells of old wool and engine oil. You feel fully rested.")
		"ship_lower_captain_bed": _tell("", "A narrow bed in the bow behind a red curtain, with a sea chest at its foot. The captain's place, and the captain is you now.")
		"ship_lower_store": _tell("", "Crates, barrels and a shelf of jars. Most of it is spare plates, bolts and lamp oil. Someone left a sack of dried beans.")

func _helm() -> void:
	if GameState.davor_taken():
		_scene([
			_line("Veki", "Martin's ship went off into the Sea of Propuh. Krešo's bar on Smokva is where the hackers and smugglers drink. Somebody there saw something."),
			_line("Veki", "Fill your pack and rest in the bunks first. Once we are out in the Sea, the Republic will be watching this port. We will not come back."),
		], Callable(), [
			_choice("Set course for Smokva", func() -> void:
				GameState.set_smokva_course()
				story_travel_requested.emit("smokva")),
			_choice("Not yet", Callable()),
		])
		return
	_scene([
		_line("Veki", "She will fly. The console is older than I am, but every gauge works."),
		_line("Veki", "Fill your pack and rest in the bunks below. When you are ready, Breece is a long way out."),
		_line("Davor", "Before Breece, set a course for R-7. A rock off the old survey lanes. I left something there a long time ago."),
		_line("Veki", "R-7? There is nothing out there."),
		_line("Davor", "That is why I left it there."),
	], Callable(), [
		_choice("Fly to R-7", fly_to_rock),
		_choice("Not yet", Callable()),
	])

## The first flight to R-7 is a ship battle: the scrap thieves from the yards
## follow the Lasta out. Once they are beaten, the Lasta flies straight there.
func fly_to_rock() -> void:
	if has_flag("scrap_battle_won"):
		story_travel_requested.emit("rock")
		return
	if ship_battle_open():
		return
	_scene([
		_line("", "The Lasta lifts off pad 1. Otpornik's copper towers drop away below."),
		_line("Davor", "Something is following us. It looks like a heap of hull plates welded together."),
		_line("Veki", "The scrap thieves from the yard. They want the Lasta's plates, and they'll tear them off in flight if they can."),
		_line("Veki", "Good. You have never flown a fight. I'll talk you through it on the way."),
	], open_scrap_battle)

func open_scrap_battle() -> ShipBattle:
	return open_ship_battle("scrap_ship", SCRAP_BATTLE_LINES, ["You", "Veki", "Davor"], _scrap_battle_finished)

func _scrap_battle_finished(result: String) -> void:
	if result == "won":
		set_flag("scrap_battle_won")
		_scene([
			_line("", "The thieves' ship turns slowly in the dark, its engine dead and smoking."),
			_line("Thief", "(On the radio.) Our engine! You owe us an engine!"),
			_line("Veki", "I'll call the port patrol. They'll tow you home, and then they'll ask where all those plates came from."),
			_line("Davor", "Not bad for a first fight. On to R-7."),
		], func() -> void: story_travel_requested.emit("rock"))
	else:
		_scene([
			_line("Veki", "That's enough. I'm turning her round. We are limping back to pad 1."),
			_line("Davor", "They've got half our plates and a smile on their faces."),
			_line("Veki", "Remember: TNT only leaves the sides. Turn a side to them and keep away from that claw. Talk to me at the helm when you want to try again."),
		])
