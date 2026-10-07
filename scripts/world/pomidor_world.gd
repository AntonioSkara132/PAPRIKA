class_name PomidorWorld
extends GameWorld

## Pomidor, where the Council of all six Confederation planets meets.
##
## The Council chamber is a walled room in the southwest corner of the same map.
## The Council Hall door moves the player into it and the chamber doors move
## them back out, so the chamber needs no scene or save area of its own.

const POMIDOR_MAP := "res://maps/pomidor.tmj"
const COUNCIL_SERVICE_PREFIX := "pomidor_council:"
const POMIDOR_NAMES := [
	"Rosa", "Dino", "Lucia", "Marko", "Petra", "Sandi", "Vesna", "Tino", "Zora", "Bruno",
	"Ines", "Kosta", "Mila", "Nino", "Olga", "Paolo", "Rada", "Silvio", "Tea", "Vito",
	"Ana", "Boris", "Cvita", "Dragan", "Ela", "Franko", "Gita", "Hrvoje", "Iva", "Jure",
	"Klara", "Lovro", "Maja", "Neno", "Ora", "Pino",
]

## Who sits in the chamber, keyed by the map object name after its prefix.
## Big Council members carry their planet; Secretaries carry their office.
const COUNCIL := {
	"member_paprika_0": {"name": "Councillor Ilka Vrba", "planet": "Paprika"},
	"member_paprika_1": {"name": "Councillor Teo Marn", "planet": "Paprika"},
	"member_pomidor_0": {"name": "Councillor Rosa Pelat", "planet": "Pomidor"},
	"member_pomidor_1": {"name": "Councillor Dino Sugo", "planet": "Pomidor"},
	"member_brudet_0": {"name": "Councillor Neri Valo", "planet": "Brudet"},
	"member_brudet_1": {"name": "Councillor Ana Brod", "planet": "Brudet"},
	"member_artichoke_0": {"name": "Councillor Jarek Stan", "planet": "Artichoke"},
	"member_artichoke_1": {"name": "Councillor Oleh Kardo", "planet": "Artichoke"},
	"member_cichvarda_0": {"name": "Councillor Mirna Ceh", "planet": "Cichvarda"},
	"member_cichvarda_1": {"name": "Councillor Bo Cichy", "planet": "Cichvarda"},
	"member_chvarak_0": {"name": "Councillor Dag Hvar", "planet": "Chvarak"},
	"member_chvarak_1": {"name": "Councillor Lira Kost", "planet": "Chvarak"},
	"secretary_army": {"name": "Secretary of the Army Marko Vojnic", "office": "army"},
	"secretary_gold": {"name": "Secretary of Gold Zlata Kun", "office": "gold"},
	"secretary_law": {"name": "Secretary of Law Pravdan Ruz", "office": "law"},
	"secretary_economy": {"name": "Secretary of the Economy Lena Trg", "office": "economy"},
	"secretary_diplomacy": {"name": "Secretary of Diplomacy Iva Most", "office": "diplomacy"},
	"secretary_navy": {"name": "Secretary of the Navy and Transport Luka Plov", "office": "navy"},
}
## Set once the player has reported on Artichoke to the Secretary of the Army.
const REPORTED_FLAG := "pomidor_reported_to_council"
const REPORT_REWARD := 300
## Story flags after the report, in order. The Council meets once the player has
## dealt with the collectors in the lane behind the beer hall.
const LOAN_FLAG := "pomidor_loan_shark_dealt"
const MEETING_FLAG := "pomidor_council_met"
const EMBASSY_FLAG := "pomidor_embassy_accepted"
## Set on Chvarak when the diplomatic ship takes off.
const DEPARTED_FLAG := "embassy_departed"
const SMUGGLERS_FLAG := "pomidor_smugglers_seen"
const LUDO_FLAG := "pomidor_ludo_refused"
const MILA_DEBT := 80
const STORY_SERVICE_PREFIX := "pomidor_story:"
const STORY_PEOPLE := {
	"mila": "Mila",
	"collector_0": "Collector Sava",
	"collector_1": "Collector Brk",
	"smuggler_0": "Tonko",
	"smuggler_1": "Rik",
	"ludo": "Ludo",
	"doorman": "Doorman",
	"envoy_0": "Envoy Petar Lis",
	"envoy_1": "Envoy Nada Grof",
	"envoy_2": "Envoy Oto Ban",
}
const ENVOYS := ["envoy_0", "envoy_1", "envoy_2"]
## The chamber's floor inside its walls; tools/build_pomidor_world.py CHAMBER.
const CHAMBER_RECT := Rect2(48, 752, 320, 384)

var _story: Dictionary = {}
## Collectors turned hostile; empty unless the fight in the lane is on.
var _collectors: Array[Enemy] = []
var _hall_door := Vector2(INF, INF)
var _chamber_entry := Vector2(INF, INF)
var _council: Dictionary = {}

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	tiled_loader.service_requested.connect(_on_service_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(POMIDOR_MAP):
		push_error("Pomidor map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	if player == null:
		_spawn_player(GameState.POMIDOR_ARRIVAL, "res://art/concepts/source/player.png")
	_find_doors()
	player.global_position = _safe_loaded_position(GameState.player_position)
	_assign_town_routines()
	_sync_story_people()
	GameState.squad_changed.connect(_sync_squad)
	_sync_squad()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	player.respawn_position = GameState.POMIDOR_ARRIVAL
	player.respawn_location_name = "Pomidor"

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, stable_id: String) -> void:
	if kind == "story":
		if not STORY_PEOPLE.has(stable_id):
			push_error("Unknown story person on the Pomidor map: %s" % stable_id)
			return
		var someone := StationStaff.new()
		someone.name = "story_" + stable_id
		someone.configure(STORY_SERVICE_PREFIX + stable_id, String(STORY_PEOPLE[stable_id]), variant, position)
		someone.service_requested.connect(_on_service_requested)
		someone.set_meta("texture", variant)
		actors_root.add_child(someone)
		_story[stable_id] = someone
		return
	if kind != "council":
		super._on_actor_spawn_requested(kind, position, variant, stable_id)
		return
	var key := stable_id.trim_prefix("council_")
	if not COUNCIL.has(key):
		push_error("Unknown Council seat on the Pomidor map: %s" % stable_id)
		return
	var person := StationStaff.new()
	person.name = stable_id
	person.configure(COUNCIL_SERVICE_PREFIX + key, String(COUNCIL[key]["name"]), variant, position)
	person.service_requested.connect(_on_service_requested)
	actors_root.add_child(person)
	_council[key] = person

## Council seat keys in the order of the COUNCIL table.
func council_keys() -> Array:
	return COUNCIL.keys()

func council_person(key: String) -> StationStaff:
	return _council.get(key, null)

func _find_doors() -> void:
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	if map_objects == null:
		return
	var exit_node: WorldService
	for node in map_objects.get_children():
		if node is WorldService and node.service_id == "pomidor_council_hall":
			_hall_door = node.get_interaction_position()
		elif node is WorldService and node.service_id == "chamber_exit":
			exit_node = node
	if exit_node == null or not _hall_door.is_finite():
		push_error("The Pomidor Council Hall or its chamber doors are missing.")
		return
	_chamber_entry = _nearby_open_position(exit_node.global_position + Vector2(16, -14))

func in_council_chamber(position: Vector2 = Vector2.INF) -> bool:
	if position == Vector2.INF:
		position = player.global_position if player != null else Vector2.ZERO
	return CHAMBER_RECT.has_point(position)

func hall_door() -> Vector2:
	return _hall_door

func chamber_entry() -> Vector2:
	return _chamber_entry

func enter_council_chamber() -> bool:
	if not _chamber_entry.is_finite() or player == null:
		return false
	player.global_position = _chamber_entry
	GameState.player_position = player.global_position
	_refresh_location_title()
	if story_stage() == "meeting":
		start_meeting()
	else:
		GameState.notify("You enter the Council chamber. The Big Council sits at the long table; the six Secretaries of the Small Council work at their desks.")
	return true

func leave_council_chamber() -> bool:
	if not _hall_door.is_finite() or player == null:
		return false
	player.global_position = _nearby_open_position(_hall_door + Vector2(0, 12))
	GameState.player_position = player.global_position
	_refresh_location_title()
	return true

func _refresh_location_title() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("refresh_location"):
		ui.refresh_location()

func _on_service_requested(service_id: String, display_name: String) -> void:
	if service_id.begins_with(STORY_SERVICE_PREFIX):
		talk_to(service_id.trim_prefix(STORY_SERVICE_PREFIX))
		return
	match service_id:
		"pomidor_council_hall": enter_council_chamber()
		"chamber_exit": leave_council_chamber()
		_: super._on_service_requested(service_id, display_name)

func reported_to_council() -> bool:
	return GameState.defeated_persistent_enemies.has(REPORTED_FLAG)

## The player tells the Secretary of the Army what was done on Artichoke.
func report_to_council() -> bool:
	if reported_to_council():
		return false
	GameState.defeated_persistent_enemies.append(REPORTED_FLAG)
	GameState.add_gold(REPORT_REWARD)
	GameState.record_event("pomidor_reported")
	GameState.notify("The Council heard your report on Artichoke. The Secretary of Gold pays you %d gold from the common treasury." % REPORT_REWARD)
	GameState.military_changed.emit()
	return true

func _has_flag(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has(flag)

func _set_flag(flag: String) -> void:
	if not _has_flag(flag):
		GameState.defeated_persistent_enemies.append(flag)
	# The HUD objective reads the story stage; this signal makes it refresh.
	GameState.military_changed.emit()

## Where the story stands on Pomidor, from the flags already set.
func story_stage() -> String:
	if not reported_to_council():
		return "report"
	if not _has_flag(LOAN_FLAG):
		return "wait"
	if not _has_flag(MEETING_FLAG):
		return "meeting"
	if not _has_flag(EMBASSY_FLAG):
		return "request"
	if not _has_flag(DEPARTED_FLAG):
		return "embassy"
	return "departed"

## Objective text for the HUD panel in the top right.
func story_status_text() -> String:
	match story_stage():
		"report": return "POMIDOR\nReport to the Secretary of the Army\nin the Council Hall"
		"wait": return "POMIDOR\nThe Council meets after today's petitions\nLook around town until the bell rings"
		"meeting": return "POMIDOR\nThe bell has rung\nGo to the Council chamber"
		"request": return "POMIDOR\nIva Most asks you to guard his diplomats\nAnswer him at his desk in the chamber"
		"embassy": return "POMIDOR\nMeet the three envoys at the landing ground\nFly with them to Chvarak"
	return "POMIDOR\nThe embassy has left for Engineeria"

func story_person(key: String) -> StationStaff:
	return _story.get(key, null)

func collectors() -> Array[Enemy]:
	return _collectors

## Shows or hides the people whose part depends on the story stage.
func _sync_story_people() -> void:
	var stage := story_stage()
	for key in ["collector_0", "collector_1"]:
		_set_present(key, not _has_flag(LOAN_FLAG) and _collectors.is_empty())
	for key in ENVOYS:
		_set_present(key, stage == "embassy")

func _set_present(key: String, present: bool) -> void:
	var someone := story_person(key)
	if someone == null:
		return
	someone.visible = present
	if present and not someone.is_in_group("interactable"):
		someone.add_to_group("interactable")
	elif not present:
		someone.remove_from_group("interactable")

func _play(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("play_scene"):
		ui.play_scene(lines, finished, choices)
	else:
		for line: Dictionary in lines:
			GameState.notify(String(line["text"]))
		if finished.is_valid():
			finished.call()

func _line(key: String, text: String) -> Dictionary:
	if key.is_empty():
		return {"speaker": "", "text": text}
	var someone: Node2D = story_person(key) if STORY_PEOPLE.has(key) else council_person(key)
	var speaker := String(STORY_PEOPLE[key]) if STORY_PEOPLE.has(key) else String(COUNCIL[key]["name"])
	return {"speaker": speaker, "text": text, "focus": someone}

func talk_to(key: String) -> void:
	match key:
		"mila", "collector_0", "collector_1": _talk_loan_shark()
		"smuggler_0", "smuggler_1": _talk_smugglers()
		"ludo": _talk_ludo()
		"doorman": _talk_doorman()
		"envoy_0", "envoy_1", "envoy_2": _talk_envoy(key)

# ---- the collectors ----

func _talk_loan_shark() -> void:
	if not _collectors.is_empty():
		return
	if _has_flag(LOAN_FLAG):
		_play([_line("mila", "I still owe them, you know. Not the collectors. The people above them. Everyone in this town owes Julius's people something.")])
		return
	if not reported_to_council():
		_play([
			_line("collector_0", "Private business, friend. Keep walking."),
			_line("mila", "Please, just go. It will be worse for me if you stay."),
		])
		return
	_play([
		_line("collector_0", "Eighty gold, Mila. You had three weeks."),
		_line("mila", "I paid you sixty last month! The loan was only fifty!"),
		_line("collector_1", "That was the interest. The loan is still eighty. And next week it's a hundred."),
		_line("collector_0", "Unless your friend here wants to pay it for you. Do you, friend?"),
	], Callable(), [
		{"label": "Pay her debt — %d gold" % MILA_DEBT, "action": pay_mila_debt},
		{"label": "Tell them to leave her alone", "action": fight_collectors},
		{"label": "Walk away", "action": Callable()},
	])

## Pays Mila's debt; the collectors take the gold and leave.
func pay_mila_debt() -> bool:
	if _has_flag(LOAN_FLAG) or not _collectors.is_empty():
		return false
	if not GameState.spend_gold(MILA_DEBT):
		return false
	for key in ["collector_0", "collector_1"]:
		_set_present(key, false)
	_finish_loan_shark("You paid. They counted it twice and left without a word.")
	return true

## The collectors turn on the player. Both must fall; if the player is downed
## they go back to their posts and Mila waits for another try.
func fight_collectors() -> bool:
	if _has_flag(LOAN_FLAG) or not _collectors.is_empty():
		return false
	for key in ["collector_0", "collector_1"]:
		var someone := story_person(key)
		if someone == null:
			continue
		_set_present(key, false)
		var collector := Enemy.new()
		collector.configure("collector", String(someone.get_meta("texture")), someone.global_position, "story_" + key)
		collector.defeated.connect(func(_id: String) -> void: _on_collector_down.call_deferred())
		actors_root.add_child(collector)
		_collectors.append(collector)
	GameState.notify("The collectors draw their cudgels.")
	return not _collectors.is_empty()

func _on_collector_down() -> void:
	for collector in _collectors:
		if is_instance_valid(collector) and collector.health > 0:
			return
	_collectors.clear()
	_finish_loan_shark("The collectors are down. Mila helps you drag them out of the lane.")

func _end_collector_fight() -> void:
	for collector in _collectors:
		if is_instance_valid(collector):
			collector.queue_free()
	_collectors.clear()
	_sync_story_people()

func _finish_loan_shark(how: String) -> void:
	_play([
		{"speaker": "", "text": how},
		_line("mila", "Thank you. But understand who they work for. Not for themselves. For Julius's people. The Organisation."),
		_line("mila", "It lends to anyone, then takes everything. The bakers pay it, the carters pay it, and the guard looks the other way. There will be other collectors next week."),
	], _after_loan_shark)

func _after_loan_shark() -> void:
	_set_flag(LOAN_FLAG)
	_sync_story_people()
	GameState.notify("The Council Hall bell rings. The Council is ready to meet.")

# ---- the smugglers, Ludo and the doorman ----

func _talk_smugglers() -> void:
	_play([
		_line("smuggler_0", "Crates? These are farm tools. For Chvarak."),
		_line("smuggler_1", "The cargo master has been paid, the guard has been paid, and you were never here. Walk on."),
		{"speaker": "", "text": "One lid is open a crack. Under the straw lies iron: swords with the forge marks filed off."},
	], func() -> void: _set_flag(SMUGGLERS_FLAG))

func _talk_ludo() -> void:
	if _has_flag(LUDO_FLAG):
		_play([_line("ludo", "Changed your mind? No? People who pay well can wait.")])
		return
	_play([
		_line("ludo", "You, with the Artichoke boots. Need iron? Swords, mail, all of it, half the forge's price. Nobody asks where it came from."),
		_line("ludo", "Or forget the iron. A fighter like you could work for people who pay well. Much better than the Confederation pays a Captain."),
	], Callable(), [
		{"label": "Refuse", "action": _refuse_ludo},
		{"label": "Walk away", "action": Callable()},
	])

func _refuse_ludo() -> void:
	_set_flag(LUDO_FLAG)
	_play([_line("ludo", "Suit yourself. If you change your mind, ask for Ludo in any town. We are everywhere.")])

func _talk_doorman() -> void:
	_play([
		_line("doorman", "Closed. Members only."),
		_line("doorman", "No, you are not a member. Keep walking."),
	])

# ---- the Council meeting and the embassy ----

func start_meeting() -> bool:
	if story_stage() != "meeting":
		return false
	_play(meeting_lines(), func() -> void: _set_flag(MEETING_FLAG), [
		{"label": "Accept", "action": accept_embassy},
		{"label": "Not yet", "action": _postpone_embassy},
	])
	return true

func meeting_lines() -> Array:
	return [
		_line("member_pomidor_0", "The Big Council is in session. Captain, you may stay and listen. One question today: Artichoke holds, but the Republic will be back. Do we draft a great army?"),
		_line("secretary_law", "Before the army, the town. This week collectors threatened a woman over a debt two streets from this hall. They take their orders from Julius's organisation, and it is bigger than Pomidor's guard. I can put guards on one street; Julius has people on all of them."),
		_line("secretary_army", "And I have no soldiers to give you for the streets, Pravdan. The front took every one I had. Artichoke held because of a few good fighters, not because we had enough of them."),
		_line("member_artichoke_0", "Then draft them. Every planet sends one in ten. Artichoke already sends more than that."),
		_line("member_artichoke_1", "Without a real army the Republic takes Artichoke back within a year, and then it comes for the rest of you."),
		_line("member_paprika_0", "One in ten from Paprika means one in ten farmers. Who brings in the harvest that feeds your soldiers?"),
		_line("member_brudet_0", "And who pays for it? Brudet paid for the warships last year. We cannot pay that again."),
		_line("secretary_gold", "Neri is right about the numbers. The common treasury can feed and arm the army we have. It cannot pay for a large one."),
		_line("secretary_economy", "Take that many workers off the planets and the markets are empty within a season. A war needs bread and iron as much as it needs soldiers."),
		_line("member_chvarak_0", "Chvarak's herds need herders. We send what we can, and no more."),
		_line("member_pomidor_0", "Then the draft goes to a vote. Those in favour?"),
		{"speaker": "", "text": "Four hands rise: both Artichoke councillors, one from Cichvarda and one from Pomidor. Eight stay down. The draft fails."},
		_line("secretary_diplomacy", "Then let me propose another way. Engineeria is our neighbour, and it has no love for the Republic. Its engineers build what we cannot, and it can spare soldiers. We ask Engineeria for help."),
		_line("member_cichvarda_0", "And what will Engineeria ask from us in return?"),
		_line("secretary_diplomacy", "Trade, mostly. Our grain and timber for their machines and soldiers. I would rather pay Engineeria in grain than pay the Republic in planets."),
		_line("member_pomidor_0", "The embassy to Engineeria goes to a vote."),
		{"speaker": "", "text": "Nine hands rise. Three stay down. The embassy passes."},
		_line("secretary_diplomacy", "I will send three of my diplomats with the Council's letters. The way to Engineeria goes through Chvarak's spaceport and then through open space, where hackers stop ships. Captain, the Confederation is short of fighters. Will you guard my diplomats?"),
	]

func _postpone_embassy() -> void:
	GameState.notify("Iva Most: \"The diplomats leave when you are ready. You will find me at my desk.\"")

## The player agrees to guard Iva Most's three diplomats.
func accept_embassy() -> bool:
	if story_stage() not in ["meeting", "request"]:
		return false
	_set_flag(MEETING_FLAG)
	_set_flag(EMBASSY_FLAG)
	_sync_story_people()
	_play([_line("secretary_diplomacy", "Thank you. Petar Lis, Nada Grof and Oto Ban are waiting at the landing ground. Take the transport to Chvarak with them; the ship to Engineeria leaves from there.")])
	return true

func _talk_envoy(key: String) -> void:
	var lines := {
		"envoy_0": "Petar Lis. I carry the Council's letters. Iva Most says you burned a whole fleet; I hope we will not need anything like that.",
		"envoy_1": "Nada Grof. I lived in Iskra for two years, so I know how Engineeria's court works. Their engineers are proud, and they bargain hard.",
		"envoy_2": "Oto Ban. My first embassy. I have never been past Chvarak. When you are ready, the transport takes us there.",
	}
	_play([_line(key, String(lines[key]))])

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_squad_ai.clear()
	_end_collector_fight()
	_sync_squad()

func _on_player_respawned() -> void:
	super._on_player_respawned()
	if not _collectors.is_empty():
		_end_collector_fight()
		GameState.notify("The collectors went back to Mila. She is still waiting in the lane.")

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if tiled_loader.is_walkable_position(saved):
		return saved
	var tile := Vector2(tiled_loader.tile_size)
	var cell := Vector2(floorf(saved.x / tile.x), floorf(saved.y / tile.y))
	for radius in range(1, 9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := (cell + Vector2(x, y) + Vector2(0.5, 0.5)) * tile
				if tiled_loader.is_walkable_position(candidate):
					return candidate
	return _nearby_open_position(GameState.POMIDOR_ARRIVAL)

func _assign_town_routines() -> void:
	var services: Dictionary = {}
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	for node in map_objects.get_children():
		if node is WorldService:
			services[node.service_id] = (node as WorldService).get_interaction_position()
	var townsfolk: Array[Villager] = []
	for actor in actors_root.get_children():
		if actor is Villager:
			townsfolk.append(actor)
	townsfolk.sort_custom(func(a: Villager, b: Villager) -> bool: return a.villager_id < b.villager_id)
	var fountain := _hall_door + Vector2(0, 80)
	for index in townsfolk.size():
		var person := townsfolk[index]
		person._navigation = tiled_loader
		person.villager_name = POMIDOR_NAMES[index % POMIDOR_NAMES.size()]
		person.interaction_text = "Talk to %s" % person.villager_name
		var role := "pomidor_market" if index % 3 == 0 else ("pomidor_clerk" if index % 3 == 1 else "pomidor_neighbor")
		var stops: Array[Dictionary] = [{"kind": "home", "position": person.home_position, "wait": 2.0}]
		stops.append({"kind": "square", "position": _nearby_open_position(fountain + Vector2((index % 7 - 3) * 18, (index % 3) * 14)), "wait": 3.0})
		var errand := "pomidor_market" if role == "pomidor_market" else ("pomidor_library" if role == "pomidor_clerk" else "beer_hall")
		if services.has(errand):
			stops.append({"kind": "market" if errand == "pomidor_market" else "library", "position": _nearby_open_position(Vector2(services[errand]) + Vector2(0, 10)), "wait": 4.0})
		person.configure_routine(role, stops)
