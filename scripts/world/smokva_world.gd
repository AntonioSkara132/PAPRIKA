class_name SmokvaWorld
extends GameWorld

## Smokva: Krešo's bar on a space rock in the Sea of Propuh, modelled on Caffe
## bar Smokva in Ždrelac. Built by tools/build_smokva_world.py from the
## approved concept (tools/create_smokva_concept.py).
##
## Two lobes joined by a stone bridge: the landing pad with the Lasta on the
## west lobe, the bar and its walled yard on the east one. The bar is a single
## room: the counter and the drinks at the top right, the couch under the TV at
## the top left, table soccer and darts on the left. Krešo plays darts and
## table soccer with the player (scripts/ui/darts_game.gd and
## scripts/ui/table_soccer_game.gd).
##
## Krešo is greedy and cheap but fun, with a strange sense of humour; he likes
## beer and is a little paranoid and delusional. The eight hackers from
## tools/create_hacker_designs.py drink here and can be talked to; each has a
## few lines that come round in turn.
##
## The story here: the player asks Krešo about the Republic ship that took
## Davor, and he points them to Donat, a grumpy young rank 12 hacker at the
## second table. Three of the hackers are the Purple Parrots, a gang on
## Julius's payroll (Puffa, Luster their leader, and Ruff, each with a purple
## feather). When the player goes to Donat they step in: Julius wants the
## player, and whatever the player answers, it comes to a fight. Donat wants
## no part of it. Krešo throws everyone out, and in the yard, just before the
## fight, the player and Donat switch bodies by accident, which forces him to
## fight. During the fight they switch again every SWITCH_SECONDS; both bodies
## flicker shortly before, and a switch waits while Donat's body is down. They
## switch back for good once the fight ends. The other five hackers watch.
## Afterwards Donat duels the player in their own bodies, tells them the ship
## went to Bavarin, and joins. The fighters and their powers are in
## scripts/actors/smokva_brawler.gd and scripts/actors/donat_fighter.gd.
##
## Neither fight is saved halfway: the flags record only finished steps, so a
## load goes back to before the fight and the player starts it again by
## talking to Donat. The Lasta flies here from R-7 or Otpornik, and Otpornik is
## not offered again from Smokva.

const SMOKVA_MAP := "res://maps/smokva.tmj"
const ART := "res://assets/art/smokva/"
const FLAG_PREFIX := "smokva_"
const DartsGameScript = preload("res://scripts/ui/darts_game.gd")
const TableSoccerScript = preload("res://scripts/ui/table_soccer_game.gd")
## The rock and the room in map pixels (tools/build_smokva_world.py).
const OUTSIDE_RECT := Rect2(0, 0, 960, 600)
const ROOM_RECT := Rect2(280, 792, 400, 280)
## Drinks at the bar: price in gold, health restored, and what Krešo says.
const DRINKS := {
	"beer": {"name": "Beer", "price": 6, "health": 5,
		"line": "Six gold. (He counts it twice and bites one coin.) Cheers. I'll have one too, to keep you company. You're paying for that one as well."},
	"pelinkovac": {"name": "Pelinkovac", "price": 9, "health": 10,
		"line": "Pelinkovac. Forty herbs. I know thirty-nine of them. The fortieth is a secret, and a secret costs extra. Nine gold."},
	"cedevita": {"name": "Cedevita", "price": 4, "health": 3,
		"line": "Cedevita, orange. Four gold: two for the powder, one for the water, one for stirring. I stirred it very well."},
}
## The hackers drinking at Smokva: sprite (assets/art/smokva/hackers/), name and
## the lines they say, one per talk, in turn.
const HACKERS := {
	"aquarium": {"name": "Fishbowl", "lines": [
		"Don't tap the glass. Server gets nervous. Server is the fish.",
		"Server is my backup. Everything I know, I told him first. He forgets it in three seconds, so it's very secure.",
		"Krešo charges me for the water every time I top up the bowl. He calls it a cover charge.",
	]},
	"big_puffer": {"name": "Puffa", "lines": [
		"Mmf. Mmf mmf mmf.",
		"(He pulls the zip down an inch.) I said the jacket is the right size. (He zips it back up.)",
		"Mmmf! (He points at the dartboard, then at himself, then gives you a thumbs up.)",
	]},
	"grills": {"name": "Floppy", "lines": [
		"One point four four megabytes on my chest. My whole life's work. Fits nicely.",
		"The hat? I can't see a thing. Hacking is all done by feel.",
		"Krešo owes me three beers from darts. He says the board was wet. The board is indoors.",
	]},
	"fur_ruff": {"name": "Ruff", "lines": [
		"The nose is not a joke, darling. It's a red light. It means stop looking at me.",
		"Three chains: one for work, one for play and one in case the other two get stolen.",
		"Krešo says the jukebox listens to us. I unplugged it twice. It still plays.",
	]},
	"cap_stack": {"name": "Fivecap", "lines": [
		"Five caps, one for each project. When a project is done, a cap comes off. It hasn't happened yet.",
		"Number 4. Four what? Just 4.",
		"Table soccer with Krešo? He spins the rods. Everybody knows. Nobody says.",
	]},
	"cable_durag": {"name": "Plug", "lines": [
		"This is Ekran. Say hello, Ekran. (The monitor grins at you.)",
		"Plug the cables in and I run all night. That's not a figure of speech.",
		"Out here the only network is the stars. Slow, but honest.",
	]},
	"rainbow_clown": {"name": "Bonbon", "lines": [
		"Honk. That's hello. Honking is free; at Smokva nothing else is.",
		"My headphones play one song, the same one as the jukebox. We're in sync.",
		"I asked Krešo for a glass of water. He charged me for the glass.",
	]},
	"chandelier": {"name": "Luster", "lines": [
		"Luster, like the lamp. It's on my head so people know where the party is.",
		"Every ring is from a different job. Don't ask which job.",
		"Krešo says the fig tree is watching us. I've been watching it back. Nothing yet.",
	]},
}
## Where the hackers stop on their rounds, at half size like the concept art:
## "room" points are from the bar's top left, "yard" points from the rock's.
## Chairs stand 7 to the side of each table; a hacker at a chair is at the
## table. Krešo's end of the counter (stools 140 to 160) stays free for the
## player.
const PLACES := {
	"table_1_left": ["room", Vector2(115, 69)], "table_3_right": ["room", Vector2(145, 91)],
	"table_4_right": ["room", Vector2(179, 93)], "table_5_left": ["room", Vector2(117, 113)],
	"table_6_right": ["room", Vector2(163, 115)],
	"stool_120": ["room", Vector2(120, 55)], "stool_130": ["room", Vector2(130, 55)],
	"stool_170": ["room", Vector2(170, 55)], "stool_180": ["room", Vector2(180, 55)],
	"stool_190": ["room", Vector2(190, 55)],
	"jukebox": ["room", Vector2(107, 27)], "couch": ["room", Vector2(20, 31)],
	"darts_line": ["room", Vector2(78, 112)], "darts_watch": ["room", Vector2(80, 124)],
	"soccer_low": ["room", Vector2(22, 88)], "soccer_high": ["room", Vector2(20, 52)],
	"garden_1": ["yard", Vector2(305, 217)], "garden_2": ["yard", Vector2(341, 203)],
	"garden_3": ["yard", Vector2(283, 239)],
	"lounge_1": ["yard", Vector2(409, 151)], "lounge_2": ["yard", Vector2(437, 155)],
	"swing": ["yard", Vector2(314, 174)],
	"donat_seat": ["room", Vector2(165, 71)],
}
## Each hacker's round: places and how many seconds they stay at each.
const ROUTINES := {
	"aquarium": [["table_1_left", 25.0], ["jukebox", 6.0], ["stool_120", 14.0]],
	"big_puffer": [["stool_130", 30.0], ["darts_line", 14.0]],
	"grills": [["table_5_left", 22.0], ["darts_watch", 16.0], ["stool_170", 12.0]],
	"fur_ruff": [["couch", 30.0], ["table_3_right", 20.0], ["jukebox", 8.0]],
	"chandelier": [["table_4_right", 28.0], ["stool_180", 14.0], ["lounge_1", 25.0]],
	"cable_durag": [["lounge_2", 30.0], ["swing", 14.0], ["garden_2", 20.0]],
	"rainbow_clown": [["garden_1", 25.0], ["soccer_low", 20.0], ["stool_190", 12.0]],
	"cap_stack": [["garden_3", 25.0], ["soccer_high", 20.0], ["table_6_right", 15.0]],
}

## The Purple Parrots: their hacker id, the enemy they fight as and their sprite with the feather.
const PARROTS := {
	"big_puffer": {"enemy": "parrot_puffa", "art": "hackers/parrot_puffa.png"},
	"chandelier": {"enemy": "parrot_luster", "art": "hackers/parrot_luster.png"},
	"fur_ruff": {"enemy": "parrot_ruff", "art": "hackers/parrot_ruff.png"},
}
## Where everyone stands for the fight in the yard, from the bar door, in map pixels.
const FIGHT_PLAYER := Vector2(-16, 64)
const FIGHT_DONAT := Vector2(16, 64)
const FIGHT_PARROTS := [Vector2(-56, 150), Vector2(0, 170), Vector2(56, 150)]
## The five hackers who do not fight watch from round the yard.
const WATCH_PLACES := ["garden_1", "garden_2", "garden_3", "lounge_1", "swing"]
## The duel ends when Donat is down to this share of his health (his guard is
## broken) or when the player has stood this many seconds.
const DUEL_GUARD_SHARE := 0.6
const DUEL_HOLD_SECONDS := 45.0
## In the fight with the Parrots only one of them attacks at a time; the turn
## passes on after this many seconds.
const PARROT_TURN_SECONDS := 5.0
## Where Donat watches from before the fight, among the watchers, from the bar door.
const FIGHT_DONAT_WATCH := Vector2(100, 70)
## In the fight the player and Donat switch bodies every SWITCH_SECONDS; both
## bodies flicker for the last SWITCH_WARN_SECONDS before it.
const SWITCH_SECONDS := 8.0
const SWITCH_WARN_SECONDS := 2.0
## What Donat shouts at each switch, in turn.
const SWITCH_BARKS := ["AGAIN?!", "Give it back!", "Stop DOING that!", "Your body smells like fish."]
## How often the player's body, driven by Donat, looks for a new path.
const BODY_REPATH_SECONDS := 0.4
## What Donat says before anyone asks him about the ship, in turn.
const DONAT_LINES := [
	"Busy. Being the strongest on this rock is a full-time job.",
	"Everyone here's beaten. Some of them twice. It's boring.",
	"Krešo says I scare away customers. Not my fault they're soft.",
]

## What Krešo says when the player comes to the bar, one per visit, in turn.
const KRESO_LINES := [
	"Welcome to Smokva. Beer is six gold. Water is seven; water has to be shipped in.",
	"Don't lean on the counter. The Republic can hear through wood. I read that somewhere. Or I dreamed it.",
	"This is my fourth beer. The first three were quality control.",
	"See the fig tree outside? Only one in the whole Sea. People have tried to steal it. I sleep with one eye on it.",
	"Your pilot, Veki. He looked at my fridge like he knows something. Does he know something?",
	"A tab? No tabs. The last man with a tab turned into a space rock. That's how R-7 got there.",
]
## Krešo's greeting the first time the player talks to him.
const KRESO_EYES_LINES := [
	["Krešo", "Funny eyes. When did you go blind? HA!"],
	["Krešo", "You remind me of some fucker that used to drink here, years back. Same eyes."],
	["You", "Who was he?"],
	["Krešo", "Oh, that was a long time ago. Don't really remember. (He wipes the same glass for a long time.)"],
]

## The photo on the bar wall, top left in assets/art/smokva/room.png pixels
## (tools/create_davor_photo_concept.py). The room is drawn at twice that size.
const PHOTO_FRAME_AT := Vector2(60, 6)
const PHOTO := ART + "davor_photo.png"

## The Lasta on the pad, top left in map pixels.
const LASTA_AT := Vector2(46, 262)
## Radio lines in the ship battle with the Purple Parrots (scripts/ship_battle/ship_battle.gd).
const PARROT_BATTLE_LINES := {
	"start": [["Luster", "Did you think Julius would let you just fly off? He still wants that face."],
		["Donat", "Give me the left guns. I'm not here for the right."],
		["Veki", "Same keys as always: Q left, E right. Give them a side."]],
	"side_open": [["Veki", "They're off our {side}. Fire!"]],
	"hit": [["Donat", "They scratched your ugly ship. Good. Now hit them back."]],
	"low": [["Veki", "She can't take much more of this!"]],
	"flee": [["Luster", "Julius will hear about this! Into the current, go, go!"]],
	"won": [["Veki", "They dived into the current. Let them run."]],
	"lost": [["Veki", "We're losing air. I'm taking her down. Now!"]],
}

var markers: Dictionary = {}
var veki: StationStaff
var kreso_sprite: Sprite2D
var lasta_sprite: Sprite2D
var bar_game: Control
var _game_layer: CanvasLayer
var _spots: Dictionary = {}
var hackers: Dictionary = {}
var _talks: Dictionary = {}
## Donat at his table, or by the Lasta once he has joined.
var donat: StationStaff
var parrot_fight_active := false
var duel_active := false
var duel_time := 0.0
## The Parrots fighting in the yard (Ruff's decoy is not counted).
var _parrots: Array = []
var donat_fighter: DonatFighter
var donat_duel: SmokvaBrawler
var _fight_ending := false
## The Parrot whose turn it is to attack, and how long the turn has left.
var parrot_turn: Object
var _parrot_turn_time := 0.0
## True from the yard scene before the fight until the Parrots come at the player.
var yard_standoff := false
## True while the player is in Donat's body and Donat is in the player's.
var bodies_switched := false
## Seconds until the next switch; it waits at 0 while Donat's body is down.
var switch_time := 0.0
var _switch_count := 0
var _flicker: Tween
## The walking route of the player's body while Donat drives it.
var _body_path := PackedVector2Array()
var _body_path_index := 0
var _body_repath := 0.0

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	add_child(tiled_loader)
	if not tiled_loader.load_map(SMOKVA_MAP):
		push_error("Smokva map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SMOKVA_MAP))
	for layer: Dictionary in data["layers"]:
		if layer["name"] == "Markers":
			for point: Dictionary in layer["objects"]:
				markers[point["name"]] = Vector2(point["x"], point["y"])
	_spawn_player(GameState.SMOKVA_ARRIVAL, "res://art/concepts/source/player.png")
	player.respawn_position = marker("respawn")
	player.respawn_location_name = "Smokva"
	lasta_sprite = _sprite_at("res://assets/art/otpornik/lasta.png", LASTA_AT, 1.0, LASTA_AT.y + 112.0)
	lasta_sprite.name = "Lasta"
	kreso_sprite = _sprite_at(ART + "kreso.png", marker("kreso") - Vector2(8, 22), 1.0, marker("kreso").y)
	kreso_sprite.name = "Krešo"
	var frame := _sprite_at(ART + "photo_frame.png", ROOM_RECT.position + PHOTO_FRAME_AT * 2.0, 2.0, ROOM_RECT.position.y)
	frame.name = "PhotoFrame"
	veki = StationStaff.new()
	veki.name = "Veki"
	veki.configure("smokva:veki", "Veki", "res://assets/art/iskra/npcs/veki.png", marker("veki_post"))
	actors_root.add_child(veki)
	veki.service_requested.connect(func(_id: String, _title: String) -> void: _talk_to_veki())
	_spawn_spots()
	_spawn_hackers()
	_spawn_donat()
	GameState.health_changed.connect(_on_health_changed)
	_game_layer = CanvasLayer.new()
	_game_layer.name = "BarGames"
	_game_layer.layer = 1001
	add_child(_game_layer)
	apply_loaded_state()

func marker(id: String) -> Vector2:
	return Vector2(markers.get(id, GameState.SMOKVA_ARRIVAL))

func in_room(at: Vector2 = Vector2.INF) -> bool:
	var spot := player.global_position if at == Vector2.INF and player != null else at
	return spot.y >= ROOM_RECT.position.y - 96.0

func refresh_camera() -> void:
	if _camera == null:
		return
	var rect := ROOM_RECT if in_room() else OUTSIDE_RECT
	var view := get_viewport_rect().size / _camera.zoom
	var grow := Vector2(maxf(0.0, view.x - rect.size.x), maxf(0.0, view.y - rect.size.y)) / 2.0
	_camera.limit_left = int(rect.position.x - grow.x)
	_camera.limit_right = int(rect.end.x + grow.x)
	_camera.limit_top = int(rect.position.y - grow.y)
	_camera.limit_bottom = int(rect.end.y + grow.y)
	_camera.reset_smoothing()

func location_title() -> String:
	return "SMOKVA · THE BAR" if in_room() else "SMOKVA · THE YARD"

func story_status_text() -> String:
	if yard_standoff:
		return "You are in Donat's body."
	if parrot_fight_active:
		return "Fight the Purple Parrots (%d left). You are in %s." % [_parrots.size(), "Donat's body" if bodies_switched else "your own body"]
	if duel_active:
		return "Duel with Donat: break his guard, or stay on your feet for %d seconds." % ceili(maxf(0.0, DUEL_HOLD_SECONDS - duel_time))
	if has_flag("ship_battle_won"):
		return "The Parrots got away into the current. Talk to Veki to fly to Bavarin."
	if has_flag("donat_joined"):
		return "Donat has joined you. The Republic ship went to Bavarin. Talk to Veki to take off."
	if has_flag("parrots_beaten"):
		return "Donat wants a duel. Talk to him at his table."
	if has_flag("asked_ship"):
		return "Ask Donat, at the second table in the bar, about the Republic ship."
	return "Krešo's bar. Darts and table soccer are inside." if not in_room() else "Talk to Krešo at the bar, or play darts or table soccer."

func has_flag(id: String) -> bool:
	return GameState.defeated_persistent_enemies.has(FLAG_PREFIX + id)

func set_flag(id: String) -> void:
	if not has_flag(id):
		GameState.defeated_persistent_enemies.append(FLAG_PREFIX + id)
		GameState.military_changed.emit()

## True when the player killed Roko, the Red Pelicans' hacker, on Iskra.
func killed_roko() -> bool:
	for flag in ["pelican_cleared", "hacker_killed"]:
		if GameState.defeated_persistent_enemies.has("iskra_investigation_" + flag):
			return true
	return false

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if saved.is_finite() and tiled_loader.is_walkable_position(saved):
		return saved
	return marker("arrival")

func capture_player_position() -> void:
	GameState.remember_player_position(player.global_position)

func apply_loaded_state() -> void:
	close_bar_game()
	close_ship_battle()
	_end_fights()
	_sync_story()
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	refresh_camera()

func _on_player_respawned() -> void:
	super._on_player_respawned()
	refresh_camera()

func _sprite_at(texture: String, top_left: Vector2, scale_by: float, bottom_y: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture) as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_by, scale_by)
	sprite.position = top_left
	sprite.z_index = 100 + int(bottom_y)
	add_child(sprite)
	return sprite

# ---------- places ----------

## Invisible places to interact with outside and in the bar.
class BarSpot extends Node2D:
	signal used(id: String)
	var spot_id := ""
	var text := ""

	func _ready() -> void:
		add_to_group("interactable")

	func get_interaction_text() -> String:
		return text

	func interact(_actor: Node) -> void:
		used.emit(spot_id)

const SPOTS := {
	"lasta": "Look at the Lasta",
	"dock_sign": "Read the sign",
	"olive": "Look at the olive tree",
	"swing": "Sit on the swing",
	"fig": "Look at the fig tree",
	"lounge": "Look at the lounge",
	"bar_door": "Go into the bar",
	"room_door": "Go out to the yard",
	"bar": "Talk to Krešo",
	"couch": "Sit on the couch",
	"jukebox": "Look at the jukebox",
	"darts": "Play darts",
	"table_soccer": "Play table soccer",
	"wc_door": "Look at the door",
	"photo": "Look at the photo",
}

func _spawn_spots() -> void:
	for id: String in SPOTS:
		var spot := BarSpot.new()
		spot.name = "Spot_" + id
		spot.spot_id = id
		spot.text = SPOTS[id]
		spot.global_position = marker(id)
		actors_root.add_child(spot)
		spot.used.connect(_on_spot)
		_spots[id] = spot

func move_player(to: Vector2) -> void:
	player.global_position = to
	player.velocity = Vector2.ZERO
	GameState.remember_player_position(to)
	refresh_camera()
	var ui := _ui()
	if ui != null:
		ui.refresh_location()

func _on_spot(id: String) -> void:
	match id:
		"lasta": _tell("", "The Lasta stands on the pad with her ramp down. Veki is beside her.")
		"dock_sign": _tell("", "SMOKVA, painted in gold on an old plank. Under it, smaller: \"Landing free. Drinks are not.\"")
		"olive": _tell("", "An old olive tree in a round bed, its trunk twisted like rope. A lamp in the grass lights it from below.")
		"swing":
			GameState.restore_health()
			_tell("", "You sit on the swing under its green canopy and rock for a while. The flags flutter over the yard. You feel rested.")
		"fig": _tell("", "A young fig tree in the lawn. The bar is named after it, or it was planted for the name. Nobody remembers which.")
		"lounge": _tell("", "Barrel tables on artificial grass under a dark awning. Purple and cyan lamps shine up into the trees.")
		"bar_door": move_player(marker("room_entry"))
		"room_door": move_player(marker("bar_door"))
		"bar": _talk_to_kreso()
		"couch":
			GameState.restore_health()
			_tell("", "You sink into the couch under the TV. A match from some other planet is on, with the sound off. You feel rested.")
		"jukebox": _tell("", "The jukebox glows pink. Most of the buttons are worn blank. The one that still works plays the same old song.")
		"darts": open_darts()
		"table_soccer": open_table_soccer()
		"wc_door": _tell("", "WC. Someone has written \"The Republic sits here too\" on the door in chalk.")
		"photo": look_at_photo()

# ---------- people ----------

func _ui() -> GameUI:
	return get_tree().get_first_node_in_group("game_ui") as GameUI

func _line(speaker: String, text: String) -> Dictionary:
	var focus: Node2D = veki if speaker == "Veki" else null
	if speaker == "Donat":
		focus = player if bodies_switched else _donat_body()
	for id: String in hackers:
		if HACKERS[id]["name"] == speaker:
			focus = hackers[id]
	return {"speaker": speaker, "text": text, "focus": focus}

## Whichever Donat is in the world now: the fighter, the duellist or the one who talks.
func _donat_body() -> Node2D:
	if is_instance_valid(donat_fighter):
		return donat_fighter
	if is_instance_valid(donat_duel):
		return donat_duel
	return donat

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

## The next line in turn for `who`, counting talks since the world loaded.
func next_line(who: String, lines: Array) -> String:
	var count: int = _talks.get(who, 0)
	_talks[who] = count + 1
	return String(lines[count % lines.size()])

func _talk_to_kreso() -> void:
	var choices := [
		_choice("Play darts", open_darts),
		_choice("Play table soccer", open_table_soccer),
		_choice("Buy a drink", drinks_menu),
	]
	if not has_flag("donat_joined"):
		choices.append(_choice("Ask about a Republic ship", ask_about_ship))
	if has_flag("photo_seen"):
		choices.append(_choice("Ask about the photo", ask_about_photo))
	choices.append(_choice("Not now", Callable()))
	if not has_flag("kreso_eyes"):
		# The first time, Krešo notices the Brine's eyes. Years ago a young
		# Brine drank here with Davor, and Krešo won't say more about it.
		set_flag("kreso_eyes")
		_scene(KRESO_EYES_LINES.map(func(line: Array) -> Dictionary: return _line(line[0], line[1])), Callable(), choices)
		return
	_tell("Krešo", next_line("kreso", KRESO_LINES), choices)

## The faded photo between the TV and the back door: Davor at about 40 and the
## Voice at about 20, a Brine already, drinking at this counter years ago. Only
## the white eyes give him away; nobody names him.
func look_at_photo() -> void:
	set_flag("photo_seen")
	var lines := [
		_photo_line("", "A faded photo in a wooden frame. Two men drinking at this counter, years ago."),
		_photo_line("", "One of them is Davor, his beard still brown. The other is a young man with white eyes."),
		_photo_line("", "Behind the counter, a younger Krešo is wiping a glass."),
		_line("", "On the back, in Krešo's handwriting: \"SMOKVA. D. and the kid. Their tab is still open!! – K.\""),
	]
	if has_flag("donat_joined"):
		lines.append(_line("Donat", "(Looking over your shoulder.) That one with the cap has my eyes. ...Weird. Whatever."))
	_scene(lines)

func _photo_line(speaker: String, text: String) -> Dictionary:
	var line := _line(speaker, text)
	line["picture"] = PHOTO
	return line

func ask_about_photo() -> void:
	_scene([
		_line("Krešo", "What photo? There's no photo there. There's never been a photo."),
		_line("Krešo", "(He wipes the same glass for a long time.) ...They never paid, you know. Either of them."),
	])

## Krešo makes a joke of it, then sends the player to Donat.
func ask_about_ship() -> void:
	if has_flag("asked_ship"):
		_scene([
			_line("Krešo", "Ask the red-haired one, I told you. Do I look like a map? Maps are cheaper than me."),
			_line("Donat", "(Donat, at the second table, doesn't look up.)"),
		])
		return
	set_flag("asked_ship")
	_scene([
		_line("You", "Has a Republic ship come past here? Navy hull, a gold stripe."),
		_line("Krešo", "Right, I know of a Republic ship. Who do you think I am? Ahaaa. Like I know everything."),
		_line("Krešo", "(He looks left, then right, then at the fridge.) I know nothing. Knowing things is how they get you."),
		_line("Krešo", "You can ask that guy. Red hair, second table. He ran into them not long ago. Good luck getting a word out of him; he bites."),
		_line("Donat", "(At the second table, a young hacker in an orange hoodie is eating chips and glaring at nobody.)"),
	], func() -> void: GameState.notify("Ask Donat about the Republic ship."))

func drinks_menu() -> void:
	var choices := []
	for id: String in DRINKS:
		choices.append(_choice("%s (%d gold)" % [DRINKS[id]["name"], DRINKS[id]["price"]], buy_drink.bind(id)))
	choices.append(_choice("Nothing", Callable()))
	_tell("Krešo", "Beer, Pelinkovac or Cedevita. Prices are on the board. The board is in my head.", choices)

## A drink restores a little health. Krešo takes the money first.
func buy_drink(id: String) -> bool:
	var drink: Dictionary = DRINKS[id]
	if not GameState.spend_gold(int(drink["price"])):
		_tell("Krešo", "No gold, no %s. I'm not a charity, I'm a bar. Charities don't have darts." % drink["name"])
		return false
	GameState.health = mini(GameState.max_health, GameState.health + int(drink["health"]))
	GameState.health_changed.emit(GameState.health, GameState.max_health)
	_tell("Krešo", String(drink["line"]))
	return true

func _spawn_hackers() -> void:
	for id: String in HACKERS:
		if PARROTS.has(id) and has_flag("parrots_beaten"):
			continue
		var hacker := SmokvaHacker.new()
		hacker.name = "Hacker_" + id
		var stops := []
		for stop: Array in ROUTINES[id]:
			stops.append({"at": place(String(stop[0])), "wait": float(stop[1])})
		var art := ART + (String(PARROTS[id]["art"]) if PARROTS.has(id) else "hackers/%s.png" % id)
		hacker.configure(id, HACKERS[id]["name"], art, stops[0]["at"])
		actors_root.add_child(hacker)
		# Everyone starts at their first stop, part of the way through the stay.
		hacker.start_route(self, stops, float(stops[0]["wait"]) * randf_range(0.2, 1.0))
		hacker.service_requested.connect(func(hacker_id: String, _title: String) -> void: talk_to_hacker(hacker_id))
		hackers[id] = hacker

## A place from PLACES in map pixels.
func place(id: String) -> Vector2:
	var entry: Array = PLACES[id]
	var origin := ROOM_RECT.position if entry[0] == "room" else Vector2.ZERO
	return origin + Vector2(entry[1]) * 2.0

func talk_to_hacker(id: String) -> void:
	var hacker: Dictionary = HACKERS[id]
	_tell(String(hacker["name"]), next_line(id, hacker["lines"]))

## Before Donat joins, the Lasta goes nowhere from Smokva; Otpornik is behind
## the party now. With Donat aboard, Veki takes off, and the Purple Parrots'
## ship is waiting (start_ship_battle). After the battle the Lasta is back on
## the pad for repairs, and Veki flies the party on to Bavarin (BavarinWorld).
func _talk_to_veki() -> void:
	if has_flag("ship_battle_won"):
		_tell("Veki", "The hull is patched, more or less. I'll set her down in a canyon south of Martin's base, where nobody looks. Bavarin?", [
			_choice("Fly to Bavarin", func() -> void: story_travel_requested.emit("bavarin")),
			_choice("Not yet", Callable()),
		])
	elif has_flag("donat_joined"):
		_tell("Veki", "Bavarin. A Republic base. I would rather fly into a sun, but a sun has never taken Davor. Shall we go?", [
			_choice("Take off", start_ship_battle),
			_choice("Not yet", Callable()),
		])
	else:
		_tell("Veki", "The drive is warm. Otpornik is behind us now; the Republic will be watching that port.")
		GameState.notify("The rest of the Sea of Propuh is not in the game yet.")

# ---------- the ship battle with the Purple Parrots ----------

## The Lasta lifts off, and the Parrots' ship comes out of the dust current.
func start_ship_battle() -> void:
	if ship_battle_open():
		return
	_scene([
		_line("", "The Lasta lifts off the pad. Smokva's fig tree shrinks to a dot."),
		_line("Veki", "Company. A purple ship, coming out of the current. Is that a beak on the nose?"),
		_line("Donat", "Purple Parrots. Of course it is. They never learn."),
	], open_parrot_battle)

func open_parrot_battle() -> ShipBattle:
	return open_ship_battle("parrot_ship", PARROT_BATTLE_LINES, ["You", "Veki", "Donat"], _ship_battle_finished)

func _ship_battle_finished(result: String) -> void:
	if result == "won":
		set_flag("ship_battle_won")
		_scene([
			_line("Luster", "(On the radio, crackling.) Julius will hear about this. Julius hears about everything."),
			_line("Veki", "They're gone into the current. And our hull has more holes than Krešo's excuses."),
			_line("Veki", "I'm taking her back down to Smokva to patch her. Then Bavarin."),
			_line("Donat", "Fine. Not because I'm scared of them. Because your ship is ugly AND broken."),
		])
	else:
		_scene([
			_line("Veki", "We're down. Back on Smokva's pad, and still breathing. That's the good news."),
			_line("Donat", "Turn a SIDE to them. The nose has no guns. Even I know that, and I don't even like ships."),
			_line("Veki", "Talk to me when you want another go."),
		])

# ---------- bar games ----------

func bar_game_open() -> bool:
	return bar_game != null and is_instance_valid(bar_game)

func open_darts() -> Control:
	return _open_bar_game(DartsGameScript.new())

func open_table_soccer() -> Control:
	return _open_bar_game(TableSoccerScript.new())

func _open_bar_game(game: Control) -> Control:
	close_bar_game()
	bar_game = game
	game.name = "BarGame"
	_game_layer.add_child(game)
	game.closed.connect(func() -> void: bar_game = null)
	return game

func close_bar_game() -> void:
	if bar_game_open():
		bar_game.queue_free()
	bar_game = null

# ---------- the story: Donat and the Purple Parrots ----------

func _spawn_donat() -> void:
	donat = StationStaff.new()
	donat.name = "Donat"
	donat.configure("donat", "Donat", ART + "donat.png", place("donat_seat"))
	actors_root.add_child(donat)
	donat.service_requested.connect(func(_id: String, _title: String) -> void: talk_to_donat())
	_sync_story()

## Puts Donat and the Parrots where the finished story steps leave them.
func _sync_story() -> void:
	if donat != null:
		donat.visible = true
		donat.global_position = marker("veki_post") + Vector2(40, 8) if has_flag("donat_joined") else place("donat_seat")
		donat.z_index = 100 + int(donat.global_position.y)
	for id: String in PARROTS:
		if has_flag("parrots_beaten") and hackers.has(id):
			hackers[id].queue_free()
			hackers.erase(id)
	for id: String in hackers:
		hackers[id].visible = true
		if hackers[id].held:
			hackers[id].release()

func talk_to_donat() -> void:
	if has_flag("donat_joined"):
		_tell("Donat", "Bavarin. Tell your pilot to hurry. And don't stand so close to me.")
	elif has_flag("parrots_beaten"):
		_tell("Donat", "You owe me a duel. In the yard, in my own body, so it's fair. Ready?", [
			_choice("Ready", start_duel),
			_choice("Not yet", Callable()),
		])
	elif has_flag("asked_ship"):
		confront_parrots()
	else:
		_tell("Donat", next_line("donat", DONAT_LINES))

## Fivecap stops the player on the way, then the Parrots step in.
func confront_parrots() -> void:
	_gather_at_donat()
	var lines := []
	if not has_flag("fivecap_met"):
		set_flag("fivecap_met")
		lines.append_array([
			_line("Fivecap", "Hold on. Who are you? Never seen you around."),
			_line("You", "Just passing through."),
			_line("Fivecap", "Nobody passes through Smokva. There's nothing to pass through to. (He whistles at the next table.) Luster! Look who's here."),
		])
	lines.append_array([
		_line("You", "Krešo says you ran into a Republic ship."),
		_line("Donat", "Republic ship? Maybe. Why would I tell you?"),
		_line("", "Three hackers come over and stand round the table. Each wears a purple feather: in Puffa's spikes, in Luster's chandelier, on Ruff's collar."),
	])
	var choices := []
	if killed_roko():
		lines.append_array([
			_line("Luster", "I know that face. Are you the guy who killed Roko?"),
			_line("Ruff", "It is, darling. Look at the eyes. Nobody forgets those eyes."),
			_line("Luster", "Julius wants to talk to you. Now."),
		])
		choices = [
			_choice("I'm not going anywhere with you.", _parrots_refused),
			_choice("Fine. Take me to Julius.", _parrots_trap),
		]
	else:
		lines.append_array([
			_line("Luster", "Easy, Donat. This one's ours. We're the Purple Parrots; we work for Julius."),
			_line("Luster", "And Julius has a proposition for you."),
			_line("Puffa", "Mmf."),
		])
		choices = [
			_choice("I don't work for Julius.", _parrots_refused),
			_choice("What kind of proposition?", _parrots_trap),
		]
	_scene(lines, Callable(), choices)

func _parrots_refused() -> void:
	_scene([
		_line("Luster", "Wrong answer. Julius said to bring you either way."),
		_line("Ruff", "He did say either way, darling."),
	], _donat_stays_out)

func _parrots_trap() -> void:
	_scene([
		_line("Luster", "The kind where you come with us, and Julius decides whether you come back."),
		_line("Ruff", "Hands where we can see them, darling."),
		_line("Puffa", "(He zips his jacket all the way up and cracks his knuckles.) Mmmf."),
	], _donat_stays_out)

## Donat wants no part of it; he goes out only to watch.
func _donat_stays_out() -> void:
	_scene([
		_line("Luster", "Stay out of it, Donat. This is Julius's business."),
		_line("Donat", "Not my table, not my problem. (He doesn't get up.) Don't bleed on my chips."),
		_line("Krešo", "Not in my bar! Outside! All of you! Who pays for the chairs? Not me!"),
		_line("", "Everyone spills out into the yard. Donat comes too, only to watch, with his bag of chips."),
	], start_parrot_fight)

## The Parrots, Donat and the player who have been at his table.
func _gather_at_donat() -> void:
	var seat := place("donat_seat")
	var around := [Vector2(-28, 22), Vector2(0, 30), Vector2(28, 22), Vector2(-44, 4)]
	var ids := ["big_puffer", "chandelier", "fur_ruff", "cap_stack"]
	for i in ids.size():
		if hackers.has(ids[i]):
			hackers[ids[i]].hold_at(_walkable(seat + around[i]))

func _walkable(at: Vector2) -> Vector2:
	var spot := tiled_loader.nearest_walkable_position(at)
	return spot if spot.is_finite() else at

## Everyone goes out to the yard: the player across from the Parrots, Donat
## among the five watchers. The player and Donat switch bodies, and once the
## scene is over the Parrots attack (_parrots_enter).
func start_parrot_fight() -> bool:
	if parrot_fight_active or yard_standoff or has_flag("parrots_beaten"):
		return false
	_end_fights()
	yard_standoff = true
	_fight_ending = false
	GameState.restore_health()
	var door := marker("bar_door")
	move_player(_walkable(door + FIGHT_PLAYER))
	donat.visible = false
	donat_fighter = DonatFighter.new()
	donat_fighter.name = "DonatFighter"
	donat_fighter.configure("donat", "Donat", ART + "donat.png", _walkable(door + FIGHT_DONAT_WATCH), "sword", 1, self)
	donat_fighter.max_health = 320
	donat_fighter.health = 320
	donat_fighter.armor = 3
	donat_fighter.speed = 92.0
	donat_fighter.strike_damage = int(GameData.enemy("donat_duel").get("damage", 28))
	donat_fighter.strike_cooldown = 1.1
	donat_fighter.get_up_seconds = 5.0
	actors_root.add_child(donat_fighter)
	donat_fighter.set_order("attack")
	donat_fighter.facing = (player.global_position - donat_fighter.global_position).normalized()
	var i := 0
	for id: String in PARROTS:
		if hackers.has(id):
			hackers[id].visible = true
			hackers[id].hold_at(_walkable(door + FIGHT_PARROTS[i]))
		i += 1
	var watch := 0
	for id: String in hackers:
		if PARROTS.has(id):
			continue
		hackers[id].hold_at(place(WATCH_PLACES[watch % WATCH_PLACES.size()]))
		watch += 1
	_set_switched(true)
	screen_flash(Color(1, 1, 1, 0.9), 0.7, 0.15)
	var lines := []
	if not has_flag("switched_once"):
		set_flag("switched_once")
		lines = [
			_line("", "Luster raises his hand. Something in you snaps. A white flash."),
			_line("", "You are standing among the watchers, holding a bag of chips. Over there, your own body stares back at you."),
			_line("Donat", "...Why am I over there? Why do my arms feel like wet bread?"),
			_line("You", "I didn't do anything!"),
			_line("Luster", "Don't care. Julius wants that face. Get the face."),
			_line("Donat", "That's MY— no. That's your face. Ugh. Fine! If you get a scratch on my body, you're dead."),
		]
	else:
		lines = [
			_line("", "Another white flash. You're holding the chips again."),
			_line("Donat", "Whose fault was that? Don't answer. Again."),
		]
	_scene(lines, _parrots_enter)
	_refresh_status()
	return true

## The Parrots step forward from where they stood in the scene and the fight begins.
func _parrots_enter() -> void:
	if not yard_standoff or not is_instance_valid(donat_fighter):
		return
	yard_standoff = false
	parrot_fight_active = true
	var door := marker("bar_door")
	var i := 0
	for id: String in PARROTS:
		var at := _walkable(door + FIGHT_PARROTS[i])
		if hackers.has(id):
			at = hackers[id].global_position
			hackers[id].visible = false
		var enemy := SmokvaBrawler.new()
		var stable_id := "story_smokva_" + String(PARROTS[id]["enemy"])
		enemy.name = stable_id
		enemy.configure(String(PARROTS[id]["enemy"]), ART + String(PARROTS[id]["art"]), at, stable_id)
		enemy.relentless = true
		actors_root.add_child(enemy)
		_parrots.append(enemy)
		i += 1
	switch_time = SWITCH_SECONDS
	GameState.notify("Fight the Purple Parrots in Donat's body. Watch for their tricks.")
	_refresh_status()

# ---------- the body switch ----------

## Puts the player in Donat's body (`on`) or back in their own. Both bodies
## stop where they are, the camera follows the player, and the next switch is
## SWITCH_SECONDS away.
func _set_switched(on: bool) -> void:
	bodies_switched = on and is_instance_valid(donat_fighter)
	_stop_flicker()
	if is_instance_valid(donat_fighter):
		donat_fighter.controlled = bodies_switched
		donat_fighter.velocity = Vector2.ZERO
	if player != null:
		player.velocity = Vector2.ZERO
	_camera_on(donat_fighter if bodies_switched else player)
	switch_time = SWITCH_SECONDS
	_body_path = PackedVector2Array()
	_body_repath = 0.0
	_refresh_status()

## A switch in the middle of the fight: a white flash, and Donat complains
## from whichever body he is in now.
func switch_bodies() -> void:
	_set_switched(not bodies_switched)
	_switch_count += 1
	screen_flash(Color(1, 1, 1, 0.8), 0.4)
	_bark(player if bodies_switched else donat_fighter, String(SWITCH_BARKS[(_switch_count - 1) % SWITCH_BARKS.size()]))

## Counts down to the next switch. Both bodies flicker for the last
## SWITCH_WARN_SECONDS, and the switch waits while Donat's body is down.
func _tick_body_switch(delta: float) -> void:
	if not is_instance_valid(donat_fighter):
		return
	switch_time = maxf(0.0, switch_time - delta)
	if switch_time <= SWITCH_WARN_SECONDS and _flicker == null:
		_flicker = create_tween().set_loops()
		var bright := Color(1.9, 1.9, 2.2)
		_flicker.tween_property(player, "modulate", bright, 0.12)
		_flicker.parallel().tween_property(donat_fighter, "modulate", bright, 0.12)
		_flicker.tween_property(player, "modulate", Color.WHITE, 0.12)
		_flicker.parallel().tween_property(donat_fighter, "modulate", Color.WHITE, 0.12)
	if switch_time <= 0.0 and not donat_fighter.down:
		switch_bodies()

func _stop_flicker() -> void:
	if _flicker != null:
		_flicker.kill()
		_flicker = null
	for body: Node2D in [player, donat_fighter]:
		if is_instance_valid(body):
			body.modulate = Color.WHITE

func _camera_on(body: Node2D) -> void:
	if _camera == null or not is_instance_valid(body) or _camera.get_parent() == body:
		return
	_camera.reparent(body)
	_camera.position = Vector2(0, -24)
	_camera.make_current()
	refresh_camera()

## A line Donat shouts over `body`, rising and fading.
func _bark(body: Node2D, text: String) -> Label:
	if not is_instance_valid(body):
		return null
	var old := body.get_node_or_null("Bark")
	if old != null:
		old.free()
	var label := Label.new()
	label.name = "Bark"
	label.text = text
	label.position = Vector2(-60, -48)
	label.size = Vector2(120, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 50
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("ffe680"))
	label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	body.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", -60.0, 1.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.8)
	tween.tween_callback(label.queue_free)
	return label

## While the bodies are switched the player's movement keys and attack move
## Donat's body (DonatFighter.controlled), and Donat drives the player's body.
func controlled_actor() -> CharacterBody2D:
	if bodies_switched and is_instance_valid(donat_fighter):
		return donat_fighter
	return super.controlled_actor()

func attack_as(actor: CharacterBody2D) -> void:
	if actor == donat_fighter and is_instance_valid(donat_fighter):
		donat_fighter._strike(null)
		return
	super.attack_as(actor)

## Donat in the player's body: he walks to the nearest Parrot and hits it with
## the player's weapon. With a bow he lines up with it first, since arrows fly
## straight along the way the body faces.
func drive_player_body(body: Player, delta: float) -> bool:
	if not bodies_switched:
		return false
	body.velocity = Vector2.ZERO
	if body.ui_is_open() or get_tree().paused:
		return true
	var target := nearest_hostile(body.global_position, INF)
	if target == null:
		return true
	var weapon := GameState.weapon_definition()
	var reach := float(weapon.get("reach", 24.0))
	var ranged := bool(weapon.get("ranged", false))
	var offset := target.global_position - body.global_position
	var goal := target.global_position
	if ranged:
		var line := _cardinal(offset)
		var across := absf(offset.dot(line.orthogonal()))
		if offset.length() <= reach * 0.8 and across <= 6.0:
			face_actor(body, offset)
			body._attack(target)
			return true
		goal = target.global_position - line * minf(offset.length(), reach * 0.6)
	elif offset.length() <= reach * 0.9:
		face_actor(body, offset)
		body._attack(target)
		return true
	_body_repath -= delta
	if _body_repath <= 0.0 or _body_path_index >= _body_path.size():
		_body_path = tiled_loader.get_walk_path(body.global_position, goal)
		_body_path_index = 1 if _body_path.size() > 1 else 0
		_body_repath = BODY_REPATH_SECONDS
	while _body_path_index < _body_path.size() and body.global_position.distance_to(_body_path[_body_path_index]) < 4.0:
		_body_path_index += 1
	var next := _body_path[_body_path_index] if _body_path_index < _body_path.size() else goal
	var direction := next - body.global_position
	if direction.length() < 1.0:
		return true
	face_actor(body, direction)
	body.velocity = direction.normalized() * Player.SPEED
	body.move_and_slide()
	return true

## Shows the story text again, for a count of Parrots or seconds that changed.
func _refresh_status() -> void:
	var ui := _ui()
	if ui != null:
		ui.refresh_location()

func _physics_process(delta: float) -> void:
	if parrot_fight_active and not _fight_ending:
		var standing := _parrots.size()
		_parrots = _parrots.filter(func(enemy) -> bool: return is_instance_valid(enemy) and (enemy as Enemy).health > 0)
		if _parrots.is_empty():
			parrots_beaten()
		else:
			if _parrots.size() != standing:
				_refresh_status()
			_pass_parrot_turns(delta)
			_tick_body_switch(delta)
	if duel_active and not _fight_ending:
		var seconds := int(duel_time)
		duel_time += delta
		if int(duel_time) != seconds:
			_refresh_status()
		if is_instance_valid(donat_duel) and donat_duel.health <= int(donat_duel.max_health * DUEL_GUARD_SHARE):
			end_duel("guard")
		elif duel_time >= DUEL_HOLD_SECONDS:
			end_duel("held")

## One Parrot at a time goes for the player; the other two fight Donat, or,
## while he is down, circle the player and wait. The turn goes round every
## PARROT_TURN_SECONDS, or at once when the Parrot whose turn it is goes down.
## Luster calls the turns while he is standing; the last Parrot left always
## goes for the player. Ruff's decoy does what Ruff does.
func _pass_parrot_turns(delta: float) -> void:
	_parrot_turn_time -= delta
	var current := _parrots.find(parrot_turn) if is_instance_valid(parrot_turn) else -1
	if _parrot_turn_time <= 0.0 or current == -1:
		var next: SmokvaBrawler = _parrots[(current + 1) % _parrots.size()]
		parrot_turn = next
		_parrot_turn_time = PARROT_TURN_SECONDS
		if _parrots.size() > 1:
			var caller: SmokvaBrawler = next
			for enemy: SmokvaBrawler in _parrots:
				if enemy.enemy_id == "parrot_luster":
					caller = enemy
			caller.shout("My turn!" if caller == next else "%s, now!" % next.definition.get("name", ""))
	var standing_donat: Node2D = donat_fighter if is_instance_valid(donat_fighter) and donat_fighter.is_in_group("party_target") else null
	for enemy: SmokvaBrawler in _parrots:
		var turn := enemy == parrot_turn
		var target: Node2D = player if turn else standing_donat
		enemy.focus_target = target
		enemy.pressing = target != null
		if is_instance_valid(enemy.decoy):
			enemy.decoy.focus_target = target
			enemy.decoy.pressing = enemy.pressing

## A hit that would knock the player out ends the round instead: in the fight
## with the Parrots Krešo wakes them and they go again; in the duel Donat wins.
func _on_health_changed(health: int, max_health: int) -> void:
	if (not parrot_fight_active and not duel_active) or _fight_ending or health > 0:
		return
	GameState.health = 1
	GameState.health_changed.emit.call_deferred(1, max_health)
	_fight_ending = true
	if parrot_fight_active:
		call_deferred("_parrots_win")
	else:
		call_deferred("end_duel", "down")

func _parrots_win() -> void:
	_end_fights()
	_scene([
		_line("", "The yard spins and goes dark. Then a bucket of cold water hits you in the face."),
		_line("Krešo", "Up! Up! I've got money on you. Not much. Some."),
		_line("", "You are back in your own body, soaking wet. Across the yard the Parrots are catching their breath."),
	], start_parrot_fight)

func parrots_beaten() -> void:
	set_flag("parrots_beaten")
	var at := donat_fighter.global_position if is_instance_valid(donat_fighter) else marker("bar_door") + FIGHT_DONAT
	_end_fights()
	screen_flash(Color(1, 1, 1, 0.8), 0.5)
	_sync_story()
	donat.visible = true
	donat.global_position = at
	GameState.restore_health()
	_scene([
		_line("", "Luster pulls himself up by the fence, his chandelier hanging off one ear."),
		_line("Luster", "Julius will hear about this. Julius hears about everything."),
		_line("", "The three Parrots limp over the bridge to the landing pad. A minute later a little purple ship lifts off the far side of the rock."),
		_line("", "A last white flash, and you are back in your own body. This time it stays that way."),
		_line("Donat", "Never. Do that. Again."),
		_line("Donat", "(He checks his hands, front and back.) You owe me. Duel. Now. In my own body, so it's fair."),
	], Callable(), [
		_choice("Let's go", start_duel),
		_choice("Not yet", func() -> void:
			_sync_story()
			GameState.notify("Talk to Donat at his table when you're ready for the duel.")),
	])

## Donat against the player in the yard. Losing does not stop the story.
func start_duel() -> bool:
	if duel_active or not has_flag("parrots_beaten") or has_flag("donat_joined"):
		return false
	_end_fights()
	duel_active = true
	duel_time = 0.0
	_fight_ending = false
	GameState.restore_health()
	var door := marker("bar_door")
	move_player(_walkable(door + FIGHT_PLAYER + Vector2(0, 40)))
	donat.visible = false
	donat_duel = SmokvaBrawler.new()
	donat_duel.name = "story_smokva_donat_duel"
	donat_duel.configure("donat_duel", ART + "donat.png", _walkable(door + FIGHT_PARROTS[1]), "story_smokva_donat_duel")
	donat_duel.relentless = true
	actors_root.add_child(donat_duel)
	GameState.notify("Duel with Donat. Break his guard, or stay on your feet for %d seconds." % int(DUEL_HOLD_SECONDS))
	_refresh_status()
	return true

## Ends the duel: "guard" when the player broke Donat's guard, "held" when
## they stood long enough, "down" when Donat won. He joins either way.
func end_duel(how: String) -> void:
	if not duel_active:
		return
	var at := donat_duel.global_position if is_instance_valid(donat_duel) else marker("bar_door")
	_end_fights()
	set_flag("donat_joined")
	donat.visible = true
	donat.global_position = at
	GameState.restore_health()
	var lines := []
	match how:
		"guard":
			lines = [
				_line("", "Your blow knocks Donat's blade wide, and for a moment he is wide open."),
				_line("Donat", "(He stares at his blade.) Lucky. That was luck. ...Fine. It wasn't luck."),
			]
		"held":
			lines = [
				_line("Donat", "(He steps back and lowers the blade.) %d seconds. You're annoying to hit. That's not a compliment." % int(DUEL_HOLD_SECONDS)),
			]
		_:
			lines = [
				_line("", "You land on your back in the grass. Donat's blade stops a finger's width from your nose."),
				_line("Donat", "Got you. In my own body, the way it should be."),
			]
	lines.append_array([
		_line("You", "The Republic ship."),
		_line("Donat", "(He sighs.) Navy hull, gold stripe, guns on the nose. I flew up for a closer look and they nearly shot my wing off."),
		_line("Donat", "It went to Bavarin. A Republic base. Nobody goes there on purpose."),
		_line("You", "I'm going there. They took someone from me."),
		_line("Donat", "Then I'm coming."),
		_line("Donat", "Not because I like you. If that happens again, I want to be close enough to punch you. In your own face."),
	])
	_scene(lines, func() -> void:
		_sync_story()
		GameState.notify("Donat joined you. He waits by the Lasta."))

## Clears both fights away without deciding anything; used between rounds and on load.
func _end_fights() -> void:
	# The camera goes back to the player's body before Donat's is freed.
	_set_switched(false)
	yard_standoff = false
	for enemy in _parrots:
		if is_instance_valid(enemy):
			if is_instance_valid(enemy.decoy):
				enemy.decoy.queue_free()
			enemy.queue_free()
	_parrots.clear()
	parrot_turn = null
	_parrot_turn_time = 0.0
	for node in [donat_fighter, donat_duel]:
		if is_instance_valid(node):
			node.queue_free()
	donat_fighter = null
	donat_duel = null
	for node in actors_root.get_children():
		if node is Projectile or node is SlashArc:
			node.queue_free()
	parrot_fight_active = false
	duel_active = false
	_refresh_status()
