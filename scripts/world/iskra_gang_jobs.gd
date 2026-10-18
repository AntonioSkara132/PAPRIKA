extends RefCounted

const Search = preload("res://scripts/world/iskra_collector_search.gd")
const Pressure = preload("res://scripts/world/iskra_job_pressure.gd")
const Guard = preload("res://scripts/actors/iskra_gang_guard.gd")
const Citizen = preload("res://scripts/actors/iskra_citizen.gd")
const ROOMS := {"freight": Rect2(640, 2816, 640, 352), "holding": Rect2(1408, 2816, 640, 352)}
const SHIPMENT_REWARDS := {"pelican": 80, "squirrel": 90}
const STOPS := {"park": "veki_park", "freight": "veki_freight", "holding": "veki_holding", "pelican": "delivery_pelican", "squirrel": "delivery_squirrel"}
const SERVICES := {
	"freight_office": ["Jela — Freight Clerk", "library_archivist"],
	"freight_side": ["Freight service hatch", "dock_mechanic"],
	"holding_office": ["Pelican Store 6 — watchman", "tower_guard"],
	"holding_side": ["Store 6 — service entrance", "dock_mechanic"],
	"collector_neighbor": ["Nera — Western Lodging", "market_keeper"],
	"gang_freight_manifest": ["Freight manifest desk", "library_archivist"],
	"gang_freight_crate_a": ["Shipment K-17 — crate A", "dock_mechanic"],
	"gang_freight_crate_b": ["Shipment K-17 — crate B", "dock_mechanic"],
	"gang_freight_exit": ["Freight front door", "dock_mechanic"],
	"gang_freight_side": ["Freight service door", "dock_mechanic"],
	"gang_holding_exit": ["Store 6 — front door", "dock_mechanic"],
	"gang_holding_side": ["Store 6 — service door", "dock_mechanic"],
	"gang_holding_lock": ["Prisoner lock", "dock_mechanic"],
	"gang_holding_stash": ["Hidden money box", "dock_mechanic"],
}
var search: RefCounted
var pressure: RefCounted
var world: Node2D
var chapter: RefCounted
var veki: StationStaff
var collector: IskraCitizen
var prisoners: Array[IskraCitizen] = []
var guards: Array[Enemy] = []
const WATCH_RADIUS := 116.0
const PATROL_SPEED := 44.0
const PATROL_ROUTES := [
	[Vector2(192, 224), Vector2(336, 224), Vector2(336, 112), Vector2(160, 112)],
	[Vector2(400, 208), Vector2(560, 208), Vector2(560, 112), Vector2(256, 112), Vector2(256, 208)],
]
var guard_marks: Array[Node2D] = []
var patrol_stops: Array[int] = [1, 1]
var patrol_paths: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var carrying: Sprite2D
var _veki_stop := "park"
var _alarm := false
var _stash_alarm := false
var _davor_paused := false

func _init(owner_world: Node2D) -> void:
	world = owner_world
	chapter = world.chapter

func has(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has("iskra_gang_" + flag)

func set_flag(flag: String) -> void:
	world._set_flag("iskra_gang_" + flag)

func clear_flag(flag: String) -> void:
	GameState.defeated_persistent_enemies.erase("iskra_gang_" + flag)

func near(id: String, radius: float = 48.0) -> bool:
	return not world.taxi_active and world.player.global_position.distance_to(world.marker(id)) <= radius

func _near_veki() -> bool:
	return not world.taxi_active and world.player.global_position.distance_to(veki.global_position) <= 56.0

func side() -> String:
	return "pelican" if has("shipment_pelican") else ("squirrel" if has("shipment_squirrel") else "")

func room() -> String:
	for id: String in ROOMS:
		if ROOMS[id].has_point(world.player.global_position):
			return id
	return ""

func setup() -> void:
	pressure = Pressure.new(self)
	for id: String in SERVICES:
		var entry: Array = SERVICES[id]
		var staff := _staff(id, entry[0], entry[1], world.marker(id))
		if id.begins_with("gang_") or id in ["freight_side", "holding_side"]:
			staff.get_child(0).visible = false
			staff.interaction_text = entry[0]
		if id.contains("crate_") or id.ends_with("stash"):
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/art/iskra/gang_crate.png")
			sprite.position = Vector2(0, -8)
			staff.add_child(sprite)
	veki = _staff("veki", "Veki — hired pilot", "veki", world.marker("veki_park"))
	collector = _person("collector", "Miro — missing collector", "night_watch", "collector_hideout")
	search = Search.new(self)
	search.setup()
	prisoners.append(_person("prisoner_a", "Jana — Green Squirrels", "greenhouse_worker", "gang_holding_prisoner_a"))
	prisoners.append(_person("prisoner_b", "Zel — Green Squirrels", "canal_worker", "gang_holding_prisoner_b"))
	carrying = Sprite2D.new()
	carrying.texture = load("res://assets/art/iskra/gang_crate.png")
	carrying.position = Vector2(9, -10)
	world.player.add_child(carrying)
	for id in ["gang_holding_guard_a", "gang_holding_guard_b"]:
		var mark := Node2D.new()
		mark.position = ROOMS.holding.position + PATROL_ROUTES[guard_marks.size()][0]
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = Color(0.9, 0.6, 0.2, 0.65)
		for i in 33:
			line.add_point(Vector2.from_angle(TAU * i / 32.0) * WATCH_RADIUS)
		mark.add_child(line)
		var body := Sprite2D.new()
		body.texture = load("res://assets/art/iskra/npcs/tower_guard.png")
		body.position.y = -10
		mark.add_child(body)
		var label := Label.new()
		label.text = "PATROL"
		label.position = Vector2(-30, -28)
		label.add_theme_font_size_override("font_size", 8)
		mark.add_child(label)
		mark.z_index = 100 + int(mark.position.y)
		world.actors_root.add_child(mark)
		guard_marks.append(mark)
	sync()

func _staff(id: String, title: String, role: String, position: Vector2) -> StationStaff:
	var staff := StationStaff.new()
	staff.configure("iskra:" + id, title, "res://assets/art/iskra/npcs/%s.png" % role, position)
	world.actors_root.add_child(staff)
	staff.service_requested.connect(world._on_service_requested)
	world.story_people[id] = staff
	var label := Label.new()
	label.text = title
	label.position = Vector2(-85, -34)
	label.size = Vector2(170, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("f5d88d"))
	staff.add_child(label)
	return staff

func _person(id: String, title: String, role: String, marker: String) -> IskraCitizen:
	var actor := Citizen.new()
	actor.configure(id, title, "res://assets/art/iskra/npcs/%s.png" % role, world.marker(marker), world.tiled_loader)
	actor.service_id = "iskra:" + id
	world.actors_root.add_child(actor)
	actor.service_requested.connect(world._on_service_requested)
	world.story_people[id] = actor
	return actor

func _tell(speaker: String, text: String, choices: Array = []) -> void:
	chapter._tell(speaker, text, choices)

func _scene(speaker: String, text: String, done: Callable) -> void:
	chapter._scene([chapter._line(speaker, text)], done)

func _choice(label: String, action: Callable) -> Dictionary:
	return {"label": label, "action": action}

func handle(id: String) -> bool:
	match id:
		"red_pelican": _recruiter("pelican")
		"green_squirrel": _recruiter("squirrel")
		"veki": _veki_menu()
		"freight_office": _freight_office()
		"freight_side": enter_freight(true)
		"gang_freight_manifest": _manifest()
		"gang_freight_crate_a": take_crate(0)
		"gang_freight_crate_b": take_crate(1)
		"gang_freight_exit", "gang_freight_side": leave_site("freight", id.ends_with("side"))
		"holding_office": _holding_office()
		"holding_side": enter_holding("sneak")
		"gang_holding_lock": _unlock_menu()
		"gang_holding_stash": _stash_menu()
		"gang_holding_exit", "gang_holding_side": leave_site("holding", id.ends_with("side"))
		"collector_neighbor": _neighbor()
		"collector": _collector_menu()
		"rival_collector": search.encounter()
		"prisoner_a", "prisoner_b":
			_tell("Jana" if id == "prisoner_a" else "Zel", "Veki's ship is outside. Watch the moving guards and stay outside their amber sight circles. There is a money box by the back shelves, but we can leave it. Toma promised to pay for us, not just the money.")
		_: return false
	return true

func _hostile(faction: String) -> bool:
	return world.investigation != null and world.investigation.hostile(faction)

func cancel_for_hostility(faction: String) -> void:
	if side() == faction and not has("shipment_delivered") and not has("shipment_paid"):
		set_flag("shipment_cancelled")
		for suffix in ["a", "b"]:
			clear_flag("shipment_loaded_" + suffix)
		GameState.iskra_gang_state.erase("shipment_seconds")
	if faction == "pelican":
		if has("hunt_job") and not has("hunt_paid") and not has("hunt_money") and not has("hunt_bribe"):
			set_flag("hunt_refused")
			set_flag("hunt_cancelled")
			search.restore()
		if chapter.has_flag("pelican_job") and not chapter.has_flag("pelican_delivered") and not chapter.has_flag("pelican_paid"):
			chapter.set_flag("pelican_cancelled")
	elif has("rescue_job") and not has("rescue_extracted"):
		set_flag("rescue_cancelled")
		clear_flag("rescue_job")
		GameState.iskra_gang_state.erase("rescue_seconds")
		_clear_guards()
	pressure.reset_runtime()
	sync()

func _hostile_recruiter(faction: String) -> void:
	var choices: Array = []
	if side() == faction and has("shipment_delivered") and not has("shipment_paid"):
		choices.append(_choice("Settle earned shipment payment", claim_shipment))
	if faction == "pelican":
		if chapter.has_flag("pelican_delivered") and not chapter.has_flag("pelican_paid"):
			choices.append(_choice("Settle earned envelope payment", chapter._pelican))
		if not has("hunt_paid") and (has("hunt_money") or has("hunt_bribe")):
			choices.append(_choice("Settle the completed collector account", report_hunt))
	elif has("rescue_extracted") and not has("rescue_paid"):
		choices.append(_choice("Settle earned rescue payment", claim_rescue))
	choices.append(_choice("Leave", Callable()))
	_tell("Ves" if faction == "pelican" else "Toma", "You attacked our people. There will be no new work, and unfinished contracts are closed. I will settle a debt for work already completed, once. Then leave.", choices)

func _recruiter(faction: String) -> void:
	if _hostile(faction):
		_hostile_recruiter(faction)
		return
	var title := "Ves — Red Pelicans" if faction == "pelican" else "Toma — Green Squirrels"
	if faction == "squirrel":
		chapter.set_flag("squirrels_met")
	var text: String
	var choices: Array = []
	if faction == "pelican" and chapter.has_flag("pelican_job") and not chapter.has_flag("pelican_paid") and not chapter.has_flag("pelican_returned"):
		choices.append(_choice("Ask about the envelope delivery", chapter._pelican))
	if has("shipment_cancelled"):
		text = "The K-17 shipment contract closed when you attacked the gang that hired you. There is no second contract for those crates."
	elif side().is_empty():
		text = "The Red Pelicans handle Julius's business on Iskra. We need two crates of undeclared ship parts moved out of freight. It is smuggling, not an innocent delivery. Veki's flight is included. This is paid work, not membership." if faction == "pelican" else "The Green Squirrels answer to neither Julius nor his Pelicans. We want their two crates of ship parts. This is theft. We sell them and take their customers. Veki's flight is included; you are not joining us."
		choices.append(_choice("Accept shipment for %s — %d gold" % ["Pelicans" if faction == "pelican" else "Squirrels", SHIPMENT_REWARDS[faction]], func() -> void: accept_shipment(faction)))
	elif has("shipment_delivered") or has("shipment_paid"):
		if faction == side():
			text = "Our receiver has both K-17 crates. The shipment is finished."
			if has("shipment_paid"):
				text += " You have been paid as agreed."
			else:
				text += " Your payment is waiting."
				choices.append(_choice("Collect shipment payment", claim_shipment))
		else:
			text = "You delivered K-17 to the Squirrels. Those were our parts. Do not expect a shipment payment from me." if faction == "pelican" else "You delivered K-17 to the Pelicans. We missed that opportunity. I will not pay for their delivery."
	else:
		text = "You took the K-17 contract with the %s." % side().capitalize()
		if faction != side():
			text += " I will not offer a second contract for the same crates."
		elif has("shipment_loaded_a") and has("shipment_loaded_b"):
			text += " Both crates are aboard. Ask Veki to take them to our receiver."
		else:
			text += " Collect the two marked crates at freight and load them on Veki's ship. Davor watches the entrance while Veki prepares to leave."
	if chapter.has_flag("audience_complete"):
		if faction == "pelican":
			if not has("hunt_job"):
				choices.append(_choice("Ask about the missing collector — 100 gold", _offer_hunt))
			elif has("hunt_refused"):
				text += "\nYou refused the collector contract. That matter is closed."
			elif has("hunt_paid"):
				text += "\nThe collector's account has been settled."
			elif has("hunt_money") or has("hunt_bribe") or has("hunt_escort"):
				choices.append(_choice("Report on Miro", report_hunt))
			else:
				text += "\nAsk Veki about Miro's last flight, then Mara about his lodging, and Nera at the western workers' lodging at No Questions."
		else:
			if not has("rescue_job"):
				choices.append(_choice("Ask about our captured people — 120 gold", _offer_rescue))
			elif has("rescue_extracted") and not has("rescue_paid"):
				choices.append(_choice("Claim the rescue reward", claim_rescue))
			elif has("rescue_paid"):
				text += "\nJana and Zel are safe. They owe the Squirrels for getting them out."
			else:
				text += "\nVeki can fly you to Store 6. Pay the ransom, use the service entrance or fight the ordinary guards. Bring both people back."
	else:
		text += "\nThere may be more work after you finish your business at the Tower."
	if world.investigation != null:
		world.investigation.add_recruiter_choices(faction, choices)
	choices.append(_choice("Leave", Callable()))
	_tell(title, text, choices)

func accept_shipment(faction: String) -> bool:
	if faction not in SHIPMENT_REWARDS or _hostile(faction) or has("shipment_cancelled") or not near("red_pelican" if faction == "pelican" else "green_squirrel") or not side().is_empty():
		return false
	set_flag("shipment_" + faction)
	_tell("Ves" if faction == "pelican" else "Toma", "Two crates, marked K-17 A and B. Meet Veki west of Punk Park's taxi pad. He will take you to freight. Nobody is paying you to hurt the warehouse staff.")
	return true

func _veki_menu() -> void:
	set_flag("veki_met")
	var choices: Array = []
	var text := "Veki. I fly people and cargo. The gangs hire the ship, not my loyalty. I know the docks; tell me what you are carrying before we take off."
	if world.investigation != null:
		text = world.investigation.add_veki_choices(choices, text)
	if has("hunt_job") and not has("hunt_flight_clue") and not has("hunt_cancelled"):
		choices.append(_choice("Ask about Miro's last flight", func() -> void: _scene("Veki", "I took Miro from freight to Kinova's street. Brown coat, red account book. He asked Mara for a cheap bed. That was before anyone hired you to find him.", func() -> void: set_flag("hunt_flight_clue"))))
	if has("shipment_carried_a") or has("shipment_carried_b"):
		choices.append(_choice("Load the carried K-17 crate", load_crate))
	if not side().is_empty() and not has("shipment_paid") and not has("shipment_cancelled"):
		if not has("shipment_loaded_a") or not has("shipment_loaded_b"):
			choices.append(_choice("Fly to freight — contract covers fare", func() -> void: fly("freight")))
		else:
			choices.append(_choice("Fly to the %s receiving pad" % side().capitalize(), func() -> void: fly(side())))
		if _veki_stop == side() and not has("shipment_delivered"):
			choices.append(_choice("Unload both crates for the %s" % side().capitalize(), deliver_shipment))
	if has("rescue_job") and not has("rescue_paid") and not has("rescue_extracted"):
		choices.append(_choice("Fly to Store 6", func() -> void: fly("holding")))
	if _veki_stop != "park":
		choices.append(_choice("Fly back to Punk Park", func() -> void: fly("park")))
	elif has("rescue_freed") and not has("rescue_extracted"):
		choices.append(_choice("Finish extraction here with both prisoners", finish_rescue_at_park))
	choices.append(_choice("Stay here", Callable()))
	_tell("Veki", text, choices)

func _freight_office() -> void:
	if has("shipment_cancelled"):
		_tell("Jela", "The collection order was withdrawn. There is no active K-17 contract for you.")
		return
	if search.running() and (side().is_empty() or has("shipment_delivered") or has("shipment_paid")):
		_tell("Jela", search.hint())
		return
	if side().is_empty():
		_tell("Jela", "Freight lists and inspections. You need a collection job before entering the warehouse.")
		return
	if not has("inspection_seen"):
		_scene("Jela", "The original receiving pad is closed for inspection. K-17 is still inside. The manifest desk has the approved alternate pad. Collect the crates separately and load them on your pilot's ship.", func() -> void: set_flag("inspection_seen"))
		return
	var choices: Array = []
	if side() == "pelican":
		choices.append(_choice("Show collection order and enter", func() -> void: enter_freight(false)))
	else:
		choices.append(_choice("Pay clerk 10 gold to look away", bribe_freight))
		choices.append(_choice("Ask about another entrance", func() -> void: _tell("Jela", "The service hatch is south along this dock. I did not give you permission. Once inside, do not touch any other customer's crates.")))
	choices.append(_choice("Leave", Callable()))
	_tell("Jela", "The approved alternate pad is on the manifest. Veki knows how to reach it.", choices)

func bribe_freight() -> bool:
	if has("shipment_cancelled") or not near("freight_office") or side() != "squirrel" or not has("inspection_seen"):
		return false
	if not has("freight_bribed"):
		if not GameState.spend_gold(10):
			_tell("Jela", "No coin, no favor. The service hatch is still there; it is your decision.")
			return false
		set_flag("freight_bribed")
	return enter_freight(false)

func enter_freight(service: bool) -> bool:
	if escorting():
		GameState.notify("Finish the escort before entering another warehouse.")
		return false
	if has("shipment_cancelled") or side().is_empty() or has("shipment_delivered") or not near("freight_side" if service else "freight_office"):
		return false
	if not has("inspection_seen"):
		_tell("", "Read the inspection notice with Jela at the freight office first.")
		return false
	if not service and side() == "squirrel" and not has("freight_bribed"):
		return false
	_move("gang_freight_side" if service else "gang_freight_arrival")
	return true

func _manifest() -> void:
	if side().is_empty():
		return
	_scene("Freight manifest", "K-17: two crates of undeclared drive couplings. Original pad closed. Pelican receiver: southern civilian dock. Squirrel receiver: market service pad. Davor will watch outside while Veki prepares the ship. Taking the FIRST crate starts an 18.75-second loading window before the crew arrives. Reading and planning take no time. If you are late, expect guards, not cancellation. Only the contracted buyer will pay.", func() -> void: set_flag("manifest_read"))

func take_crate(index: int) -> bool:
	var suffix := "a" if index == 0 else "b"
	if has("shipment_cancelled") or index not in [0, 1] or not near("gang_freight_crate_" + suffix) or side().is_empty() or not has("manifest_read") or has("shipment_delivered"):
		GameState.notify("Read the freight manifest before collecting K-17.")
		return false
	if _veki_stop != "freight":
		GameState.notify("Bring Veki and the ship to freight before taking a crate. You can inspect the warehouse first.")
		return false
	if has("shipment_loaded_" + suffix) or has("shipment_carried_a") or has("shipment_carried_b"):
		GameState.notify("Carry one crate at a time. Load it on Veki's ship outside.")
		return false
	set_flag("shipment_carried_" + suffix)
	sync()
	if not pressure.started("shipment"):
		pressure.begin("shipment")
	else:
		GameState.notify("Carrying K-17 %s. Take it to Veki on the freight dock." % suffix.to_upper())
	return true

func load_crate() -> bool:
	if not _near_veki():
		return false
	for suffix in ["a", "b"]:
		if has("shipment_carried_" + suffix):
			clear_flag("shipment_carried_" + suffix)
			set_flag("shipment_loaded_" + suffix)
			sync()
			_tell("Veki", "Crate %s is aboard. %s" % [suffix.to_upper(), "Both crates are loaded. Choose our receiving pad." if has("shipment_loaded_a") and has("shipment_loaded_b") else "One more to collect."])
			return true
	return false

func deliver_shipment() -> bool:
	if not _near_veki() or side().is_empty() or _veki_stop != side() or not has("shipment_loaded_a") or not has("shipment_loaded_b") or has("shipment_delivered"):
		return false
	set_flag("shipment_delivered")
	_tell("Veki", "The receiver has both crates and has signed for them. We can go back to Punk Park. Collect your payment from the gang that hired you.")
	return true

func claim_shipment() -> bool:
	var faction := side()
	if faction.is_empty() or not near("red_pelican" if faction == "pelican" else "green_squirrel") or not has("shipment_delivered") or has("shipment_paid"):
		return false
	set_flag("shipment_paid")
	GameState.add_gold(SHIPMENT_REWARDS[faction])
	_tell("Ves" if faction == "pelican" else "Toma", "Paid as agreed. You worked one job. You have not joined us, and Veki remains a hired pilot.")
	return true

func _offer_hunt() -> void:
	_tell("Ves", "Miro took a collection purse and an account book. Find him and bring him back alive: one hundred gold. He is an ordinary collector, not a hacker. Start with Veki's flight records. No killing contract.", [_choice("Accept the search", accept_hunt), _choice("Not now", Callable())])

func accept_hunt() -> bool:
	if _hostile("pelican") or not near("red_pelican") or not chapter.has_flag("audience_complete") or has("hunt_job"):
		return false
	set_flag("hunt_job")
	search.start()
	sync()
	return true

func offer_hotel_clue() -> void:
	_tell("Mara", "Before you go upstairs, you asked about a visitor named Miro?", [_choice("Ask where Miro stayed", func() -> void: _scene("Mara", "He could not afford Kinova. I sent him to Nera at the western workers' lodging at No Questions, south of the nature park. He was looking over his shoulder, but he paid for his meal.", func() -> void: set_flag("hunt_hotel_clue"))), _choice("Not now", Callable())])

func _neighbor() -> void:
	if has("hunt_hotel_clue") and not has("hunt_paid"):
		_scene("Nera", "Miro paid for a bed here in the western workers' lodging at No Questions. He walks up and down the lane between the nature park and the western greenhouse, stopping halfway along it. " + search.hint(), func() -> void: set_flag("hunt_route_known"); sync())
	else:
		_tell("Nera", "Cheap beds for greenhouse and market workers. I do not give out tenants' whereabouts to anyone who asks.")

func _collector_menu() -> void:
	if not has("hunt_job") or has("hunt_paid") or has("hunt_refused"):
		return
	if collector.global_position.distance_to(world.player.global_position) > 48:
		return
	set_flag("hunt_found")
	if (has("hunt_rival_custody") or has("hunt_rival_delivered")) and not has("hunt_rival_released"):
		search.encounter()
		return
	if has("hunt_escape_pending"):
		_tell("Miro", "I am heading to the departing crew at the western market landing pad. Keep Radan away from me until I get there.")
		return
	if has("hunt_escort"):
		_tell("Miro", "I will come. Take me to Ves at Punk Park. Keep me with you; do not leave me at a taxi pad.")
		return
	_tell("Miro", "I took the purse to buy passage away from Julius. The book names every shop we squeeze. Ves wants it back more than he wants me. You can take me in, take the purse and let me go, or take forty gold and say I left Iskra.", [
		_choice("Bring Miro back alive", func() -> void: decide_hunt("escort")),
		_choice("Recover purse and book; let Miro escape", func() -> void: decide_hunt("money")),
		_choice("Accept 40 gold and agree to lie", func() -> void: decide_hunt("bribe")),
		_choice("Refuse to finish the contract", func() -> void: decide_hunt("refused")),
		_choice("Think about it", Callable()),
	])

func decide_hunt(outcome: String) -> bool:
	if outcome not in ["escort", "money", "bribe", "refused"] or not has("hunt_found") or collector.global_position.distance_to(world.player.global_position) > 48 or hunt_decided():
		return false
	set_flag("hunt_" + outcome)
	if outcome == "bribe":
		GameState.add_gold(40)
	if outcome == "escort":
		collector.follow_for_rescue(world.player, 0)
	elif outcome in ["money", "bribe"]:
		search.begin_escape()
		_tell("Miro", "I am walking to the departing crew at the western market landing pad. Radan is still searching; keep him from catching me on the way.")
	else:
		collector.wait_at(collector.global_position)
	sync()
	return true

func hunt_decided() -> bool:
	return has("hunt_escort") or has("hunt_money") or has("hunt_bribe") or has("hunt_refused") or has("hunt_paid")

func report_hunt() -> bool:
	if not near("red_pelican") or has("hunt_paid") or has("hunt_refused"):
		return false
	if not search.can_report():
		return false
	var reward := 0
	var text := ""
	if has("hunt_rival_delivered") and not has("hunt_money") and not has("hunt_bribe"):
		_tell("Ves", "Radan already delivered Miro. I cannot pay you a capture bounty for his work. If you want to free Miro afterward, that is your decision.")
		if has("hunt_escort") and collector.global_position.distance_to(world.marker("red_pelican")) <= 88:
			set_flag("hunt_paid")
			sync()
			return true
		return false
	if has("hunt_escort"):
		if collector.global_position.distance_to(world.marker("red_pelican")) > 88:
			_tell("Ves", "Bring Miro here. I pay for the collector, not a promise that he is somewhere behind you.")
			return false
		reward = 100
		text = "Miro, you and I have accounts to discuss. Your escort gets one hundred gold. This does not make the captain a Pelican."
	elif has("hunt_money"):
		reward = 55
		text = "The purse and book are here, but you let Miro leave. Fifty-five gold for what you recovered. Next time, tell me before changing the agreement." if not has("hunt_rival_delivered") else "You recovered the purse and book; Radan brought Miro in. Fifty-five gold for the money and records, not a capture bounty."
	elif has("hunt_bribe"):
		reward = 10
		text = "Left the planet, you say? Ten gold for your time. No capture, no bounty. I will ask the port myself." if not has("hunt_rival_delivered") else "Radan brought Miro in. Your story about him leaving does not fit. Ten gold for the search, not a capture bounty. We are done."
	else:
		return false
	set_flag("hunt_paid")
	GameState.add_gold(reward)
	sync()
	_tell("Ves", text)
	return true

func _offer_rescue() -> void:
	_tell("Toma", "Jana and Zel tried to rob a Pelican office. They are being held in Store 6, in the southern courtyard west of the central canal. Bring both back and I pay one hundred twenty gold, whether or not you recover the money. Veki's flight is paid. They will owe us for this. The captors are ordinary guards, not hackers.", [_choice("Accept the rescue", accept_rescue), _choice("Not now", Callable())])

func accept_rescue() -> bool:
	if _hostile("squirrel") or has("rescue_cancelled") or not near("green_squirrel") or not chapter.has_flag("audience_complete") or has("rescue_job"):
		return false
	set_flag("rescue_job")
	sync()
	return true

func _holding_office() -> void:
	if not has("rescue_job") or has("rescue_extracted"):
		_tell("Watchman", "Store 6 is private. Move along.")
		return
	_tell("Watchman", "The two thieves? Fifty gold for both, and they leave alive. Otherwise you are not coming through this door.", [
		_choice("Pay ransom — 50 gold" if not has("rescue_ransom") else "Show paid ransom receipt", pay_ransom),
		_choice("Fight the guards and enter", func() -> void: enter_holding("fight")),
		_choice("Leave and look for another entrance", Callable()),
	])

func pay_ransom() -> bool:
	if not near("holding_office") or not has("rescue_job") or has("rescue_extracted"):
		return false
	if not has("rescue_ransom"):
		if not GameState.spend_gold(50):
			_tell("Watchman", "No payment, no release. The service yard is around the building, but my men will stop anyone they spot.")
			return false
		set_flag("rescue_ransom")
	pressure.ransom()
	_clear_guards()
	return enter_holding("ransom")

func enter_holding(mode: String) -> bool:
	if escorting() and room().is_empty():
		GameState.notify("Finish the current escort before entering Store 6.")
		return false
	if mode not in ["sneak", "fight", "ransom"] or not has("rescue_job") or has("rescue_extracted") or not near("holding_side" if mode == "sneak" else "holding_office"):
		return false
	if mode == "ransom" and not has("rescue_ransom"):
		return false
	_move("gang_holding_side" if mode == "sneak" else "gang_holding_arrival")
	if mode == "fight":
		start_alarm()
	elif mode == "sneak":
		GameState.notify("Two guards patrol the cells and service corridor. Their amber circles show sight range; shelves block their view. Wait for an opening. The service door is on the right.")
	sync()
	return true

func _unlock_menu() -> void:
	if not has("rescue_job") or has("rescue_extracted"):
		return
	if _alarm and not has("rescue_guards_cleared"):
		_tell("", "The guards are attacking. Deal with them before opening the lock.")
		return
	_tell("Jana", "The latch is on your side. Open it and we will follow. Unless you paid our ransom, opening it starts a 11.25-second escape window. Davor holds the main entrance, but reinforcements can come around him. Bring both of us to Veki; the money is optional.", [_choice("Release Jana and Zel", release_prisoners), _choice("Wait", Callable())])

func release_prisoners() -> bool:
	if _veki_stop != "holding":
		GameState.notify("Bring Veki's ship to Store 6 before opening the lock. It is safe to prepare first.")
		return false
	if not near("gang_holding_lock") or not has("rescue_job") or has("rescue_freed") or has("rescue_extracted") or (_alarm and not has("rescue_guards_cleared")):
		return false
	set_flag("rescue_freed")
	for i in prisoners.size():
		prisoners[i].follow_for_rescue(world.player, i)
	if not has("rescue_ransom"):
		pressure.begin("rescue")
	else:
		GameState.notify("The ransom is honored. Lead both prisoners to Veki; there is no escape alarm.")
	return true

func _stash_menu() -> void:
	if not has("rescue_freed") or has("rescue_stash") or has("rescue_extracted"):
		_tell("", "A locked money box behind the shelves. Get the prisoners out first.")
		return
	if _stash_alarm:
		if not has("rescue_stash_guard_down"):
			_tell("Zel", "The guard heard the lock. We can still leave without the money.")
		else:
			_tell("Zel", "The box is open. Take the recovered money for Toma?", [_choice("Recover the money", take_stash), _choice("Leave it", Callable())])
		return
	_tell("Zel", "That is the money we hid. The lock has a bell; breaking it will bring another armed guard. Toma pays for our rescue even if we leave it.", [_choice("Break the lock and risk another guard", start_stash_alarm), _choice("Leave the money", Callable())])

func start_stash_alarm() -> bool:
	if not near("gang_holding_stash") or not has("rescue_freed") or has("rescue_stash") or _stash_alarm:
		return false
	_stash_alarm = true
	set_flag("rescue_stash_opening")
	_spawn_guard("stash", "gang_holding_stash_guard")
	return true

func take_stash() -> bool:
	if not near("gang_holding_stash") or not has("rescue_freed") or not has("rescue_stash_guard_down") or has("rescue_stash"):
		return false
	set_flag("rescue_stash")
	_tell("Zel", "That is all of it. Now the ship. Toma will pay another forty for getting the purse back.")
	return true

func finish_rescue_at_park() -> bool:
	if not _near_veki() or _veki_stop != "park" or not has("rescue_freed") or has("rescue_extracted"):
		return false
	for prisoner in prisoners:
		if prisoner.global_position.distance_to(veki.global_position) > 96:
			_tell("Veki", "Bring both Jana and Zel here. I will not mark the rescue finished while one is missing.")
			return false
	set_flag("rescue_extracted")
	for i in prisoners.size():
		prisoners[i].wait_at(world.tiled_loader.nearest_walkable_position(world.marker("green_squirrel") + Vector2(28 + 20 * i, 20)))
	sync()
	return true

func claim_rescue() -> bool:
	if not near("green_squirrel") or not has("rescue_extracted") or has("rescue_paid"):
		return false
	set_flag("rescue_paid")
	GameState.add_gold(120 + (40 if has("rescue_stash") else 0))
	_tell("Toma", "Both back alive. One hundred twenty gold, as promised." + (" Forty more for the money." if has("rescue_stash") else " You left the money. I said I would pay for our people, and I meant it.") + " Jana, Zel: we will discuss what you owe the gang tomorrow.")
	return true

func escorting() -> bool:
	return (has("hunt_escort") and not has("hunt_paid")) or (has("rescue_freed") and not has("rescue_extracted"))

func busy_travel() -> bool:
	return escorting() or has("shipment_carried_a") or has("shipment_carried_b")

func passengers() -> Array[IskraCitizen]:
	var result: Array[IskraCitizen] = []
	if has("hunt_escort") and not has("hunt_paid"):
		result.append(collector)
	if has("rescue_freed") and not has("rescue_extracted"):
		result.append_array(prisoners)
	return result

func fly(destination: String) -> bool:
	if not _near_veki() or not STOPS.has(destination) or destination == _veki_stop or room() != "":
		return false
	if destination == "freight" and (has("shipment_cancelled") or side().is_empty() or has("shipment_delivered")):
		return false
	if destination in ["pelican", "squirrel"] and (has("shipment_cancelled") or destination != side() or not has("shipment_loaded_a") or not has("shipment_loaded_b") or has("shipment_delivered")):
		return false
	if destination == "holding" and (not has("rescue_job") or has("rescue_extracted")):
		return false
	if has("shipment_carried_a") or has("shipment_carried_b"):
		_tell("Veki", "Load that crate before we take off.")
		return false
	var riders := passengers()
	for actor in riders:
		if actor.global_position.distance_to(veki.global_position) > 96:
			_tell("Veki", "Bring everyone to the ship. I will not leave someone behind.")
			return false
	if has("rescue_freed") and not has("rescue_extracted") and destination != "park":
		_tell("Veki", "Let us get Jana and Zel back to Punk Park first.")
		return false
	var target: Vector2 = world.marker(STOPS[destination])
	if not world.start_flight(target, "Veki — " + destination.capitalize(), func() -> void:
		for stop: String in STOPS:
			clear_flag("veki_at_" + stop)
		_veki_stop = destination
		set_flag("veki_at_" + destination)
		for i in riders.size():
			riders[i].wait_at(world.tiled_loader.nearest_walkable_position(target + Vector2(24 + i * 20, 16)))
			riders[i].follow_for_rescue(world.player, i)
			riders[i].visible = true
			riders[i].set_physics_process(true)
		if destination == "park" and has("rescue_freed") and not has("rescue_extracted"):
			set_flag("rescue_extracted")
			for i in prisoners.size():
				prisoners[i].wait_at(world.tiled_loader.nearest_walkable_position(world.marker("green_squirrel") + Vector2(28 + 20 * i, 20)))
		sync()):
		return false
	for actor in riders:
		actor.visible = false
		actor.set_physics_process(false)
	veki.visible = false
	return true

func leave_site(site: String, service: bool) -> bool:
	if room() != site or not near("gang_" + site + ("_side" if service else "_exit")):
		return false
	for actor in passengers():
		if actor.global_position.distance_to(world.player.global_position) > 80:
			GameState.notify("Wait for your companions to reach this door.")
			return false
	if not service and pressure.front_blocked(site):
		GameState.notify("An armed guard blocks the front door. Defeat them or use the service door on the right.")
		return false
	var destination := site + ("_side" if service else "_office")
	_move(destination, true)
	return true

func _move(marker: String, bring_followers: bool = false) -> void:
	world.player.global_position = world.marker(marker)
	world.player.velocity = Vector2.ZERO
	world._move_davor()
	if bring_followers:
		var riders := passengers()
		for i in riders.size():
			riders[i].wait_at(world.tiled_loader.nearest_walkable_position(world.player.global_position + Vector2(24 + i * 20, 16)))
			riders[i].follow_for_rescue(world.player, i)
	GameState.remember_player_position(world.player.global_position)
	chapter.refresh_location()
	refresh_camera()

func refresh_camera() -> void:
	var site := room()
	if site.is_empty():
		return
	var rect: Rect2 = ROOMS[site]
	world._camera.limit_left = int(rect.position.x) - 32
	world._camera.limit_right = int(rect.end.x) + 32
	world._camera.limit_top = int(rect.position.y) - 32
	world._camera.limit_bottom = int(rect.end.y) + 32
	world._camera.reset_smoothing()
	var ui: GameUI = chapter._ui()
	if ui != null:
		ui.refresh_location()

func start_alarm() -> void:
	if _alarm or has("rescue_guards_cleared") or not has("rescue_job"):
		return
	_alarm = true
	set_flag("rescue_alarm")
	_spawn_guard("a", "gang_holding_guard_a")
	guards.back().global_position = guard_marks[0].global_position
	_spawn_guard("b", "gang_holding_guard_b")
	guards.back().global_position = guard_marks[1].global_position
	GameState.notify("The watchmen spotted you. Pelican swordsmen are attacking.")
	sync()

func _spawn_guard(id: String, marker: String) -> void:
	var guard := Guard.new()
	guard.configure("bandit_sword", "res://assets/art/iskra/npcs/tower_guard.png", world.marker(marker), "story_iskra_gang_" + id)
	guard.definition.merge({"name": "Pelican guard", "level": 3, "max_health": 38, "damage": 5, "reward": 0, "event": "iskra_guard_defeated"}, true)
	guard.max_health = 38
	guard.health = 38
	guard.guard_radius = 620.0
	guard.defeated.connect(func(_persistent_id: String) -> void:
		set_flag("rescue_guard_" + id + "_down" if id != "stash" else "rescue_stash_guard_down")
		if has("rescue_guard_a_down") and has("rescue_guard_b_down"):
			set_flag("rescue_guards_cleared")
		sync())
	world.actors_root.add_child(guard)
	guards.append(guard)

func _clear_guards(reset_flags: bool = true) -> void:
	for guard in guards:
		if is_instance_valid(guard):
			guard.queue_free()
	guards.clear()
	_alarm = false
	_stash_alarm = false
	patrol_stops = [1, 1]
	patrol_paths = [PackedVector2Array(), PackedVector2Array()]
	for i in guard_marks.size():
		guard_marks[i].position = ROOMS.holding.position + PATROL_ROUTES[i][0]
	if reset_flags:
		for flag in ["rescue_guard_a_down", "rescue_guard_b_down", "rescue_stash_guard_down", "rescue_alarm", "rescue_stash_opening"]:
			clear_flag(flag)

func on_respawn() -> void:
	_clear_guards()
	if not has("rescue_extracted"):
		clear_flag("rescue_freed")
		clear_flag("rescue_guards_cleared")
	if has("hunt_escort") and not has("hunt_paid"):
		clear_flag("hunt_escort")
	apply_loaded_state()

func capture_state() -> void:
	search.capture()
	if has("rescue_freed") and not has("rescue_extracted"):
		for i in prisoners.size():
			var key := "prisoner_" + ("a" if i == 0 else "b")
			GameState.iskra_gang_state[key + "_x"] = prisoners[i].global_position.x
			GameState.iskra_gang_state[key + "_y"] = prisoners[i].global_position.y

func apply_loaded_state() -> void:
	_clear_guards(false)
	_veki_stop = "park"
	for stop: String in STOPS:
		if has("veki_at_" + stop):
			_veki_stop = stop
	if room() == "holding" and not has("rescue_extracted") and not pressure.started("rescue"):
		# Older untimed raids resume outside; timed escapes retain their progress.
		clear_flag("rescue_freed")
		clear_flag("rescue_guards_cleared")
		world.player.global_position = world.marker("holding_side")
		GameState.remember_player_position(world.player.global_position)
		world._move_davor()
	for i in prisoners.size():
		var pos: Vector2 = world.marker("gang_holding_prisoner_" + ("a" if i == 0 else "b"))
		if has("rescue_extracted"):
			pos = world.tiled_loader.nearest_walkable_position(world.marker("green_squirrel") + Vector2(28 + 20 * i, 20))
		elif has("rescue_freed"):
			var key := "prisoner_" + ("a" if i == 0 else "b")
			var saved := Vector2(float(GameState.iskra_gang_state.get(key + "_x", world.player.global_position.x + 24 + 20 * i)), float(GameState.iskra_gang_state.get(key + "_y", world.player.global_position.y + 16)))
			pos = world.tiled_loader.nearest_walkable_position(saved)
		prisoners[i].wait_at(pos)
		prisoners[i].set_physics_process(true)
		if has("rescue_freed") and not has("rescue_extracted"):
			prisoners[i].follow_for_rescue(world.player, i)
	collector.wait_at(world.marker("collector_hideout"))
	collector.set_physics_process(true)
	if has("hunt_escort") and not has("hunt_paid"):
		collector.wait_at(world.tiled_loader.nearest_walkable_position(world.player.global_position + Vector2(24, 16)))
		collector.follow_for_rescue(world.player, 0)
	if room() == "holding" and pressure.started("rescue"):
		_alarm = has("rescue_alarm")
		if _alarm and not has("rescue_guards_cleared"):
			for suffix in ["a", "b"]:
				if not has("rescue_guard_" + suffix + "_down"):
					_spawn_guard(suffix, "gang_holding_guard_" + suffix)
		_stash_alarm = has("rescue_stash_opening")
		if _stash_alarm and not has("rescue_stash_guard_down") and not has("rescue_stash"):
			_spawn_guard("stash", "gang_holding_stash_guard")
	search.restore()
	pressure.restore()
	sync()

func _show(actor: Node2D, visible: bool) -> void:
	actor.visible = visible
	if visible:
		actor.add_to_group("interactable")
	else:
		actor.remove_from_group("interactable")

func sync() -> void:
	veki.global_position = world.marker(STOPS[_veki_stop])
	veki.z_index = 100 + int(veki.global_position.y)
	# Once hired for Breece, Veki travels with the party instead of waiting at his ship.
	_show(veki, not world.taxi_active and not (world.investigation != null and world.investigation.has("veki_hired")))
	for suffix in ["a", "b"]:
		_show(world.story_people["gang_freight_crate_" + suffix], not has("shipment_cancelled") and not has("shipment_loaded_" + suffix) and not has("shipment_carried_" + suffix))
	carrying.visible = has("shipment_carried_a") or has("shipment_carried_b")
	var searching := has("hunt_job") and not has("hunt_paid") and not has("hunt_refused")
	_show(collector, searching and not has("hunt_escape_safe") and (not hunt_decided() or has("hunt_escort") or has("hunt_escape_pending") or has("hunt_rival_custody") or has("hunt_rival_delivered")))
	if search != null:
		search._visible()
	for prisoner in prisoners:
		_show(prisoner, has("rescue_job") and not world.taxi_active)
	for mark in guard_marks:
		mark.visible = has("rescue_job") and not has("rescue_extracted") and not has("rescue_ransom") and not has("rescue_guards_cleared") and not _alarm

func step(delta: float) -> void:
	pressure.step(delta)
	search.step(delta)
	var dialogue_open: bool = world.player.ui_is_open()
	if dialogue_open and not room().is_empty() and world.davor.is_physics_processing():
		world.davor.set_physics_process(false)
		_davor_paused = true
	elif _davor_paused and not dialogue_open:
		_davor_paused = false
		if not world.taxi_active:
			world.davor.set_physics_process(true)
	if dialogue_open or world.taxi_active or world.get_tree().paused:
		return
	if room() == "holding" and has("rescue_job") and not has("rescue_ransom") and not has("rescue_guards_cleared") and not _alarm:
		_step_patrols(delta)
		var watched: Array[Node2D] = [world.player]
		if has("rescue_freed"):
			watched.append_array(prisoners)
		for actor in watched:
			for mark in guard_marks:
				if patrol_can_see(mark.global_position, actor.global_position):
					start_alarm()
					return

func patrol_can_see(origin: Vector2, target: Vector2) -> bool:
	var distance := origin.distance_to(target)
	if distance > WATCH_RADIUS:
		return false
	# Sample more finely than a navigation cell; walls and shelving block sight.
	var samples := maxi(1, ceili(distance / 4.0))
	for i in range(samples + 1):
		if not world.tiled_loader.is_walkable_position(origin.lerp(target, float(i) / samples)):
			return false
	return true

func _step_patrols(delta: float) -> void:
	for i in guard_marks.size():
		var mark := guard_marks[i]
		if patrol_paths[i].is_empty():
			var destination: Vector2 = ROOMS.holding.position + PATROL_ROUTES[i][patrol_stops[i]]
			patrol_paths[i] = world.tiled_loader.get_walk_path(mark.global_position, destination)
		var remaining := PATROL_SPEED * delta
		while remaining > 0.0 and not patrol_paths[i].is_empty():
			var destination := patrol_paths[i][0]
			var distance := mark.global_position.distance_to(destination)
			var travel := minf(distance, remaining)
			mark.global_position = mark.global_position.move_toward(destination, travel)
			remaining -= travel
			if distance <= travel:
				patrol_paths[i].remove_at(0)
		if patrol_paths[i].is_empty():
			patrol_stops[i] = (patrol_stops[i] + 1) % PATROL_ROUTES[i].size()
		mark.z_index = 100 + int(mark.global_position.y)

func status() -> String:
	var jobs: Array[String] = []
	if not side().is_empty() and not has("shipment_paid") and not has("shipment_cancelled"):
		if has("shipment_delivered"):
			jobs.append("Shipment: collect payment from " + ("Ves" if side() == "pelican" else "Toma") + " in Punk Park.")
		elif has("shipment_loaded_a") and has("shipment_loaded_b"):
			jobs.append("Shipment: ask Veki to fly to the %s pad and unload." % side().capitalize())
		elif has("shipment_carried_a") or has("shipment_carried_b"):
			jobs.append("Shipment: carry this crate outside and load it on Veki's ship.")
		else:
			jobs.append("Shipment: ask the freight clerk about entry, read the manifest and load both K-17 crates on Veki's ship.")
	if has("hunt_job") and not has("hunt_paid") and not has("hunt_refused"):
		if has("hunt_escort"):
			jobs.append("Collector: escort Miro to Ves in Punk Park. Veki can carry him too.")
		elif has("hunt_escape_pending"):
			jobs.append("Collector: keep Radan away while Miro walks to the departing crew at the western market landing pad.")
		elif has("hunt_rival_custody") or has("hunt_rival_delivered"):
			jobs.append("Collector: " + search.hint())
		elif has("hunt_money") or has("hunt_bribe"):
			jobs.append("Collector: report to Ves in Punk Park.")
		elif has("hunt_found") or has("hunt_route_known"):
			jobs.append("Collector: search the lane between the nature park and western greenhouse; Miro walks between its north and south ends.")
		elif has("hunt_hotel_clue"):
			jobs.append("Collector: ask Nera at the western workers' lodging at No Questions, south of the nature park.")
		elif has("hunt_flight_clue"):
			jobs.append("Collector: ask Mara at Kinova about Miro.")
		else:
			jobs.append("Collector: ask Veki about Miro's last flight.")
	if has("rescue_job") and not has("rescue_paid"):
		jobs.append("Rescue: " + ("claim Toma's reward in Punk Park." if has("rescue_extracted") else "lead Jana AND Zel to Veki outside Store 6; fly back to Punk Park." if has("rescue_freed") else "Veki flies to Store 6. Ransom 50 gold, sneak via service entrance, or fight. Open prisoner lock."))
	if not jobs.is_empty():
		var locations := {"park": "west of Punk Park taxi pad", "freight": "freight dock", "holding": "outside Store 6", "pelican": "southern civilian dock", "squirrel": "market service pad"}
		jobs.append("Veki: " + str(locations[_veki_stop]) + ".")
	if pressure != null and not pressure.status().is_empty():
		jobs.append(pressure.status())
	return "\n".join(jobs)
