extends RefCounted

const Data = preload("res://scripts/world/iskra_investigation_data.gd")
const Encounters = preload("res://scripts/world/iskra_investigation_encounters.gd")
## During the meeting the camera zooms out until the dome's copper ring is in view and all nine seated people
## fit above the dialogue box. The top HUD panels are hidden for the same reason.
const BOARD_ZOOM := 0.56
## Centre of the dome inside the Board chamber, matching BOARD_CENTRE in the art script at twice its scale.
const BOARD_CENTRE := Vector2(544, 352)
## The meeting view is lowered from the dome's centre so the ring's top edge sits at the top of the screen.
const BOARD_VIEW_SHIFT := Vector2(0, 43)
## Iva Most's budget for the journey to Breece, and Veki's fee: half paid on hiring, half after the return to Cauliflower.
const BREECE_BUDGET := 2000
const VEKI_ADVANCE := 1000
const VEKI_BALANCE := 1000
## The player camera's normal position above the player's feet.
const CAMERA_OFFSET := Vector2(0, -24)
const TITLES := {"hall": "KINOVA · HALL", "owner": "BORIN'S APARTMENT", "neighbor": "KINOVA · ROOM 13", "squirrel": "SQUIRREL OFFICE", "pelican": "PELICAN OFFICE", "board": "TOWER · BOARD CHAMBER"}
## The seven Heads elected by the Engineering Board, in seat order.
const BOARD_HEADS := {
	"nation": ["Zvonimir Dom", "Head of Nation"],
	"technology": ["Nikola Struja", "Head of Technology"],
	"architecture": ["Vedrana Luk", "Head of Architecture"],
	"navy": ["Kresimir Sidro", "Head of Navy"],
	"demographics": ["Ljerka Popis", "Head of Demographics"],
	"finance": ["Dubravka Riznic", "Head of Finance"],
	"defense": ["Branko Stit", "Head of Defense"],
}
const BOARD_GUESTS := {
	"cauliflower_secretary": ["Iva Most", "Secretary of Diplomacy"],
	"diplomatic_secretary": ["Diplomatic Secretary", ""],
}
const SERVICES := {
	"inv_owner_entry": ["Borin's apartment", "", "Enter Borin's apartment"],
	"inv_squirrel_entry": ["Green Squirrel office", "", "Enter the Green Squirrel office"],
	"inv_pelican_entry": ["Red Pelican office", "", "Enter the Red Pelican office"],
	"inv_rendezvous": ["Gang rendezvous", "", "Meet the assault party"],
	"inv_hall_room12": ["Room 12", "", "Return to your room"],
	"inv_hall_exit": ["Kinova reception", "", "Go down to reception"],
	"inv_hall_neighbor": ["Room 13", "", "Examine the neighboring door"],
	"inv_hall_attacker": ["Police Officer", "police_attacker", "Answer the officer"],
	"inv_hall_evidence": ["Discarded police coat", "", "Examine the police coat"],
	"inv_owner_exit": ["Apartment door", "", "Return to the street"],
	"inv_owner_person": ["Borin — uniform owner", "uniform_owner", "Question Borin"],
	"inv_owner_desk": ["Borin's desk", "", "Examine the payment note"],
	"inv_neighbor_exit": ["Guest corridor", "", "Return to the corridor"],
	"inv_neighbor_record": ["Abandoned luggage", "", "Search the abandoned luggage"],
	"inv_squirrel_exit": ["Office exit", "", "Return to the street"],
	"inv_squirrel_boss": ["Sena — Green Squirrel boss", "squirrel_boss", "Speak to Sena"],
	"inv_squirrel_handler": ["Jaro — contract arranger", "contract_handler", "Question Jaro"],
	"inv_squirrel_record": ["Contract ledger", "", "Read the contract ledger"],
	"inv_pelican_exit": ["Office exit", "", "Return to the street"],
	"inv_pelican_boss": ["Vlado — Red Pelican boss", "pelican_boss", "Speak to Vlado"],
	"inv_board_exit": ["Lift", "", "Take the lift down"],
}

var world: Node2D
var encounters: RefCounted
var people: Dictionary = {}
var _resume_queued := false
var _hints := 0
var _zoom_tween: Tween
## Veki follows the party once hired.
var veki_companion: RaidSoldier

func _init(owner_world: Node2D) -> void:
	world = owner_world
	encounters = Encounters.new(self)

func has(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has(Data.FLAG_PREFIX + flag)

func set_flag(flag: String) -> void:
	world._set_flag(Data.FLAG_PREFIX + flag)

func get_value(key: String, fallback: Variant = null) -> Variant:
	return GameState.iskra_investigation_state.get(key, fallback)

func set_value(key: String, value: Variant) -> void:
	GameState.iskra_investigation_state["version"] = Data.VERSION
	GameState.iskra_investigation_state[key] = value

func hostile(faction: String) -> bool:
	return has("hostile_" + faction)

func _services() -> Dictionary:
	var services := SERVICES.duplicate()
	for key: String in BOARD_HEADS:
		var head: Array = BOARD_HEADS[key]
		services["inv_board_" + key] = ["%s — %s" % head, "board_" + key, "Speak to " + head[0]]
	services["inv_board_cauliflower_secretary"] = ["Iva Most — Confederation Secretary of Diplomacy", "cauliflower_secretary", "Speak to Iva Most"]
	services["inv_board_diplomatic_secretary"] = ["Diplomatic Secretary", "diplomatic_secretary", "Speak to the Diplomatic Secretary"]
	return services

func setup() -> void:
	var services := _services()
	for id: String in services:
		var entry: Array = services[id]
		var actor := StationStaff.new()
		var role: String = entry[1]
		var texture: String = Data.npc_texture(role) if not role.is_empty() else "res://assets/art/iskra/npcs/civic_engineer.png"
		actor.configure("iskra:" + id, entry[0], texture, world.marker(id))
		actor.interaction_text = entry[2]
		if role.is_empty():
			actor.get_child(0).visible = false
		if id == "inv_hall_evidence":
			var coat := actor.get_child(0) as Sprite2D
			coat.texture = load("res://assets/art/iskra/investigation/uniform_evidence.png")
			coat.position = Vector2(-12, -22)
			coat.visible = true
		world.actors_root.add_child(actor)
		actor.service_requested.connect(world._on_service_requested)
		world.story_people[id] = actor
		people[id] = actor
	var discussion := StationStaff.new()
	discussion.configure("iskra:inv_davor", "Davor", "res://assets/art/engineeria/davor.png", world.davor.global_position)
	discussion.get_child(0).visible = false
	discussion.interaction_text = "Discuss the investigation with Davor"
	world.actors_root.add_child(discussion)
	discussion.service_requested.connect(world._on_service_requested)
	world.story_people["inv_davor"] = discussion
	people["inv_davor"] = discussion
	encounters.setup()
	sync()

func room() -> String:
	for site: String in Data.ROOMS:
		if Data.ROOMS[site].has_point(world.player.global_position):
			return site
	return ""

func location_title() -> String:
	var site := room()
	if not site.is_empty():
		return TITLES[site]
	return "ISKRA — EVENING" if has("attack_started") else ""

func _near(id: String, radius: float = 52.0) -> bool:
	if world.taxi_active:
		return false
	var point: Vector2 = people[id].global_position if people.has(id) else world.marker(id)
	if id == "inv_squirrel_boss" and is_instance_valid(encounters.enemies.get("squirrel_boss")):
		point = encounters.enemies.squirrel_boss.global_position
	return world.player.global_position.distance_to(point) <= radius

func _busy() -> bool:
	var jobs: RefCounted = world.gang_jobs
	return world.taxi_active or jobs.busy_travel() or (jobs.has("hunt_escape_pending") and not jobs.has("hunt_escape_safe"))

func _available() -> bool:
	return world.chapter.has_flag("audience_complete") and world.chapter.has_flag("room_rented")

func add_hotel_choices(choices: Array) -> void:
	if not _available():
		return
	if not has("evening_arranged"):
		choices.append(_choice("Arrange supper for this evening", arrange_evening))
	elif not has("attack_started"):
		choices.append(_choice("Return to room 12 for the evening", start_evening))
	else:
		choices.append(_choice("Go upstairs to the guest corridor", func() -> void: enter_site("hall")))
		if ready_for_deduction() and not has("mara_named"):
			choices.append(_choice("Discuss the clues with Davor", open_deduction))
		if has("mara_named") and not has("mara_confessed"):
			choices.append(_choice("Question Mara about the evening arrangements", question_mara))
		elif has("mara_confessed"):
			choices.append(_choice("Ask about access to room 13", func() -> void: _tell("Mara", "I gave you the spare key. Room thirteen, next to yours. They left after the attack. Please do not tell them I spoke to you.")))

func add_recruiter_choices(faction: String, choices: Array) -> void:
	if faction == "squirrel" and has("owner_link") and not hostile(faction):
		choices.append(_choice("Ask for the boss about Borin's uniform", func() -> void: _tell("Toma", "Borin dealt with Jaro, not me. Sena runs our office. I will tell the door guard to let you through. This is separate from any work you did for us.", [], func() -> void: set_flag("squirrel_introduced"))))
	elif faction == "pelican" and has("boss_met") and not hostile(faction):
		choices.append(_choice("Ask to speak to the Pelican boss", func() -> void: _tell("Ves", "Vlado receives people at our office. If you have a warning about Roko, tell Vlado directly. Do not bring a Squirrel assault to our door.", [], func() -> void: set_flag("pelican_introduced"))))

func handle(key: String) -> bool:
	if key == "police_records":
		return records_counter()
	if not key.begins_with("inv_"):
		return false
	if not people.has(key) or not _near(key):
		return true
	match key:
		"inv_owner_entry": enter_site("owner")
		"inv_squirrel_entry": enter_site("squirrel")
		"inv_pelican_entry": enter_site("pelican")
		"inv_rendezvous": _rendezvous()
		"inv_hall_room12": _move("hotel_room_arrival")
		"inv_hall_exit", "inv_owner_exit", "inv_neighbor_exit", "inv_squirrel_exit", "inv_pelican_exit": leave_site()
		"inv_hall_neighbor": enter_site("neighbor")
		"inv_hall_attacker": _summons()
		"inv_hall_evidence": examine_uniform()
		"inv_owner_person": _owner()
		"inv_owner_desk": examine_owner_desk()
		"inv_neighbor_record": search_neighbor()
		"inv_squirrel_boss": _squirrel_boss()
		"inv_squirrel_handler": question_contract()
		"inv_squirrel_record": read_contract()
		"inv_pelican_boss": _pelican_boss()
		"inv_davor": _davor_menu()
		"inv_board_exit": leave_site()
		_:
			if key.begins_with("inv_board_"):
				_board_person(key.trim_prefix("inv_board_"))
	return true

func arrange_evening() -> bool:
	if not _near("hotel") or not _available() or has("evening_arranged"):
		return false
	_scene([
		_line("Mara", "Shall I keep supper warm, or are you eating out?"),
		_line("You", "Keep it for us. We will be back after the evening bell, and staying in afterward."),
		_line("Mara", "Two suppers after the bell. I will put them against room twelve. The diplomatic office covers them."),
	], func() -> void: set_flag("evening_arranged"))
	return true

func start_evening() -> bool:
	if not _near("hotel") or not _available() or not has("evening_arranged") or has("attack_started"):
		return false
	if _busy():
		GameState.notify("Finish carrying cargo or helping your escorted companions before turning in.")
		return false
	_scene([
		_line("", "After supper, you and Davor return upstairs. A knock interrupts the quiet of room twelve."),
		_line("Police Officer", "Police business. The captain is required downstairs for questions about the embassy documents."),
		_line("Davor", "The Secretary has the documents. Who sent you?"),
	], func() -> void:
		set_flag("attack_started")
		set_value("assassin_phase", "waiting")
		_move("inv_hall_arrival")
		_summons())
	return true

func _summons() -> void:
	if not has("attack_started") or str(get_value("assassin_phase", "")) != "waiting":
		return
	_tell("Police Officer", "Come downstairs. Alone. We can settle this quickly.", [
		_choice("Ask to see the written order", func() -> void: _attack_opening("order")),
		_choice("Insist that Davor comes too", func() -> void: _attack_opening("davor")),
		_choice("Step into the corridor", func() -> void: _attack_opening("corridor")),
		_choice("Refuse the summons", func() -> void: _attack_opening("refuse")),
		_choice("Keep the door open and wait", Callable()),
	])

func _attack_opening(opening: String) -> void:
	var descriptions := {
		"order": "Instead of producing an order, the officer steps back and raises a bow. A pale arrow is already on the string.",
		"davor": "Davor steps beside you. The officer backs toward the service stairs and raises a bow at you.",
		"corridor": "You step into the passage. The officer raises a bow, with a pale arrow already on the string.",
		"refuse": "You refuse to move. The officer abandons the story and raises a bow at you.",
	}
	_tell("", descriptions[opening], [], func() -> void:
		encounters.begin_assassin(opening)
		sync())

func on_encounter_event(event: String) -> void:
	match event:
		"assassin_captured", "assassin_killed", "assassin_escaped":
			set_flag(event)
			if not encounters.arrow_in_flight():
				GameState.notify("The police coat can identify its owner. Examine it in the guest corridor.")
		"squirrel_cleared":
			set_flag("squirrel_cleared")
			set_flag("contract_access")
			GameState.notify("The Squirrel guards are beaten. Question Jaro or examine the contract ledger.")
		"pelican_cleared":
			set_flag("pelican_cleared")
			set_flag("hacker_killed")
			set_flag("contract_access")
			GameState.notify("Roko is dead. Return to Sena for access to the person who arranged the hotel attack.")
		"squirrel_boss_killed":
			set_flag("squirrel_boss_killed")
			if has("squirrel_cleared"):
				set_flag("contract_access")
	sync()

func attack_resolved() -> bool:
	return has("assassin_captured") or has("assassin_killed") or has("assassin_escaped")

func examine_uniform() -> bool:
	if not attack_resolved() or not _near("inv_hall_evidence"):
		return false
	var text := "The coat has a brass issue tag sewn into its lining: K-214. The attacker used a real police uniform. The quartermaster at the eastern police station keeps the issue register."
	if has("assassin_captured"):
		text += " The captive admits being hired locally, but knows the customer only through a contact. The issue tag is the firmer lead."
	elif has("assassin_escaped"):
		text += " The attacker shed the coat at the service exit. Its owner did not remove the tag."
	_tell("Police coat", text, [], func() -> void: set_flag("uniform_found"))
	return true

func police_menu() -> bool:
	if not has("uniform_found"):
		return false
	var choices: Array = [_choice("Ask who keeps the issue register", redirect_to_records), _choice("Check our registration", func() -> void: _tell("Police Clerk", "Your arrival registration is still valid. The investigation does not cancel it.")), _choice("Leave", Callable())]
	_tell("Police Clerk", "A uniform alone does not make someone a police officer. What have you brought?", choices)
	return true

func redirect_to_records() -> void:
	set_flag("records_directed")
	_tell("Police Clerk", "The issue register is kept by the quartermaster at our eastern station, past the Tower of Engineering. Take the coat's tag there.")
	GameState.notify("Go to the eastern police station: the quartermaster keeps the issue register.")

## The eastern station's quartermaster gives the owner's name and address.
func records_counter() -> bool:
	if not has("uniform_found"):
		_tell("Police Quartermaster", "I keep the issue register. Bring me a police-issued item and I will trace it.")
		return true
	if has("uniform_identified"):
		_tell("Police Quartermaster", "Borin, Flat 4, Lantern Row 12, southwest residential block. That is all the register records.")
		return true
	return identify_uniform()

func identify_uniform() -> bool:
	if not _near("police_records") or not has("uniform_found"):
		return false
	_scene([
		_line("Police Quartermaster", "K-214 was issued to Borin. The officer reported the coat missing after your attack."),
		_line("You", "So Borin was the attacker?"),
		_line("Police Quartermaster", "It identifies the owner, not the wearer. The register gives his address: Borin, Flat 4, Lantern Row 12, in the southwest residential block. Ask what happened to the coat there."),
	], func() -> void: set_flag("uniform_identified"); sync())
	return true

func _owner() -> void:
	if not has("uniform_identified"):
		return
	if has("owner_link"):
		_tell("Borin", "Jaro collected the coat for the Green Squirrels. They said it was for frightening someone into paying a debt. I reported it missing when I heard what happened at Kinova. Sena protects Jaro; ask Toma for access to their office.")
	elif has("owner_receipt"):
		_tell("Borin", "All right. It was not stolen. Jaro paid me for the coat. I did not agree to a murder. They work with the Green Squirrels; Toma will know where to find their boss.", [], func() -> void: set_flag("owner_link"))
	else:
		_tell("Borin", "I reported the coat missing. Someone took it. That is all I know.", [
			_choice("Ask when it went missing", func() -> void: _tell("Borin", "A few days ago. I waited before reporting it. You can look around, but do not break anything.")),
			_choice("Leave the conversation", Callable()),
		])

func examine_owner_desk() -> bool:
	if room() != "owner" or not _near("inv_owner_desk") or not has("uniform_identified"):
		return false
	_tell("Payment note", "A signed note records payment to Borin for the loan of a police coat. The collector signed 'Jaro, Green Squirrels'. It predates the missing-uniform report.", [], func() -> void:
		set_flag("owner_receipt")
		set_flag("owner_link"))
	return true

func _squirrel_boss() -> void:
	if not has("owner_link"):
		return
	if has("squirrel_boss_killed"):
		_tell("", "Sena is dead. The contract ledger and Jaro can still establish who bought the attack.")
		return
	if not has("boss_met"):
		_scene([
			_line("Sena", "Borin's coat? Jaro arranged that job privately. I did not order an attack on you, but I do not hand over my people for nothing."),
			_line("Davor", "Someone in your gang took money to kill the captain. You want a favor?"),
			_line("Sena", "I want Roko dead. The Pelicans' hacker directs their attacks on our people. We have fighters and a tvrdium blade, but they cannot take on Roko alone."),
			_line("Sena", "The customer had a foreign accent. I could not place it. And before you ask: the Secretary of Diplomacy would not come to us for dirty work. That is my judgment, not a witness statement."),
		], func() -> void: set_flag("boss_met"); set_flag("accent_clue"); _squirrel_boss())
		return
	if has("contract_access"):
		var choices: Array = [_choice("Question Jaro about the customer", question_contract), _choice("Read the contract ledger", read_contract)]
		if has("squirrel_cleared") and not has("squirrel_boss_killed"):
			choices.append(_choice("Kill the surrendered boss", func() -> void: encounters.finish_surrendered_boss()))
		choices.append(_choice("Leave", Callable()))
		_tell("Sena", "Jaro is here. The contract ledger is on the desk. You have what you came for.", choices)
		return
	var choices: Array = []
	if not hostile("squirrel") and not has("pelicans_warned"):
		choices.append(_choice("Accept: kill Roko for Jaro's testimony and tvrdium", accept_deal))
	choices.append(_choice("Attack Sena and the guards for the information", _direct_warning))
	choices.append(_choice("Ask what the guards carry", func() -> void: _tell("Sena", "Six guards. Three have tvrdium blades. I would rather send you after Roko than lose people fighting in my own office.")))
	choices.append(_choice("Leave without agreeing", Callable()))
	_tell("Sena", "At the rendezvous you receive the blade and three fighters. Keep the weapon afterward. Kill Roko, and Jaro answers your questions. Or leave. The offer does not require your loyalty to our gang.", choices)

func accept_deal() -> bool:
	if not _near("inv_squirrel_boss") or not has("boss_met") or hostile("squirrel") or has("pelicans_warned") or has("contract_access"):
		return false
	set_flag("deal_accepted")
	set_value("route", "squirrel")
	_tell("Sena", "Meet our people at the marked rendezvous. The tvrdium armor is part of your payment, not a loan. Receiving it does not start the assault; tell the party when you are ready.")
	sync()
	return true

func _direct_warning() -> void:
	_tell("Davor", "Six guards, three with tvrdium. If we attack, the Squirrels will close our unfinished contracts. Earned payments remain debts, but there will be no new work. We can still leave.", [
		_choice("Fight the Squirrel guards", func() -> void: start_assault("direct")),
		_choice("Do not attack", Callable()),
	])

func _pelican_boss() -> void:
	if not has("boss_met"):
		return
	if hostile("pelican"):
		_tell("Vlado", "You came with the Squirrels to kill Roko. There is no agreement between us.")
		return
	var choices: Array = []
	if not has("pelicans_warned"):
		choices.append(_choice("Warn Vlado about Sena's assassination offer", warn_pelicans))
	elif not has("contract_access"):
		choices.append(_choice("Meet the Pelican party at the rendezvous", func() -> void: _tell("Vlado", "Three fighters will meet you there. Go with them to Sena's office. We need the contract arranger alive if possible; the ledger will do if they refuse.")))
	else:
		choices.append(_choice("Report the confrontation", func() -> void: _tell("Vlado", "You warned us and helped deal with Sena's plan. I will include that when I report to Julius. That is not a promise of membership.")))
	choices.append(_choice("Leave", Callable()))
	_tell("Vlado", "Ves said you wanted to discuss a threat to one of our people. Speak plainly.", choices)

func warn_pelicans() -> bool:
	if not _near("inv_pelican_boss") or not has("boss_met") or hostile("pelican") or has("pelicans_warned") or has("hacker_killed"):
		return false
	set_flag("pelicans_warned")
	if str(get_value("encounter", "")).is_empty():
		set_value("route", "pelican")
	encounters.stage_allies("")
	_tell("Vlado", "Sena wants Roko dead? Then we both need answers. I will send three people with you to the Squirrel office. You take part; this is not a favor you can collect while we do the fighting." + (" Keep the armor Sena gave you. When they see whose party you came with, they will know you changed sides." if has("equipment_issued") else " Meet our party at the rendezvous."))
	sync()
	return true

func _rendezvous() -> void:
	var route: String = "pelican" if has("pelicans_warned") else str(get_value("route", ""))
	if route not in ["squirrel", "pelican"] or has("contract_access"):
		_tell("", "The meeting place is quiet. Arrange support with one of the gang bosses first.")
		return
	var choices: Array = []
	if route == "squirrel" and not has("equipment_issued"):
		choices.append(_choice("Take the promised tvrdium armor", issue_equipment))
	else:
		choices.append(_choice("Begin the assault on the %s office" % ("Pelican" if route == "squirrel" else "Squirrel"), func() -> void: _assault_warning(route)))
	choices.append(_choice("Leave; the assault has not started", Callable()))
	var text := "We are the three fighters Sena promised. Take the armor, wear it if you want, and tell us when to attack Roko's office. It is yours afterward." if route == "squirrel" else "Vlado sent three of us. We will go with you into the Squirrel office, not instead of you. Tell us when you are ready."
	encounters.stage_allies(route)
	_tell("Assault party", text, choices)

func issue_equipment() -> bool:
	if not _near("inv_rendezvous") or not has("deal_accepted") or has("equipment_issued") or has("pelicans_warned") or hostile("squirrel"):
		return false
	set_flag("equipment_issued")
	GameState.add_item(Data.ARMOR)
	_issue_arrow()
	_tell("Squirrel fighter", "The armor is yours. Its plates are tvrdium. Put it on from your inventory when you are ready; I have not changed what you are wearing. Sena also sends one Banishing Arrow. Roko wears a ward against it: hurt him until the ward breaks, then press F to loose the arrow. A ward swallows it whole, and you get one. We wait for your order to begin.")
	return true

## The one Banishing Arrow comes with the armor. Saves made after the armor but before the arrow existed get it when the assault starts.
func _issue_arrow() -> void:
	if has("arrow_issued"):
		return
	set_flag("arrow_issued")
	GameState.add_item(Data.ARROW)

func _assault_warning(route: String) -> void:
	var target := "Pelicans" if route == "squirrel" else "Squirrels"
	_tell("Davor", "Starting this assault makes enemies of the %s. Their unfinished contracts will close; already-earned payments can still be settled once. We can leave before the fighting starts." % target, [
		_choice("Start the assault", func() -> void: start_assault(route)),
		_choice("Wait", Callable()),
	])

func start_assault(route: String) -> bool:
	if route not in ["squirrel", "direct", "pelican"] or not has("boss_met") or has("contract_access"):
		return false
	if route == "direct":
		if not _near("inv_squirrel_boss"):
			return false
	elif not _near("inv_rendezvous"):
		return false
	if route == "squirrel" and (not has("equipment_issued") or has("pelicans_warned") or hostile("squirrel")):
		return false
	if route == "pelican" and (not has("pelicans_warned") or hostile("pelican")):
		return false
	if _busy():
		GameState.notify("Finish carrying cargo or escorting your companions before an assault.")
		return false
	var target := "pelican" if route == "squirrel" else "squirrel"
	var active: String = str(get_value("encounter", ""))
	if active not in ["", target]:
		GameState.notify("Resolve or return to your existing fight before starting another assault.")
		return false
	if active == target and str(get_value("route", "")) == route:
		GameState.notify("That assault is already underway. Return through the office entrance to continue.")
		return false
	if route == "squirrel" and not has("arrow_issued"):
		_issue_arrow()
		GameState.notify("Sena's fighters hand you one Banishing Arrow. Break Roko's ward first, then press F.")
	_move("inv_" + target + "_arrival")
	var started: bool = encounters.begin_fight(route)
	if started:
		_make_hostile(target)
		if route == "pelican" and has("equipment_issued"):
			set_flag("betrayed_after_equipment")
	sync()
	return started

func _make_hostile(faction: String) -> void:
	if hostile(faction):
		return
	set_flag("hostile_" + faction)
	world.gang_jobs.cancel_for_hostility(faction)

func question_contract() -> bool:
	if not has("contract_access") or room() != "squirrel" or (not _near("inv_squirrel_handler") and not _near("inv_squirrel_boss")):
		return false
	_scene([
		_line("Jaro", "I took the contract. Sena did not know who the target was when I arranged it. The customer gave me a description, room twelve at Kinova, and instructions to use a police coat."),
		_line("You", "Why that evening?"),
		_line("Jaro", "The customer said you would return after the evening bell and stay in for the night. Those were the exact words. I passed them to the attacker. I do not know how the customer knew."),
		_line("Davor", "Someone knew more than the room number. We should compare that with what we told people."),
	], func() -> void:
		set_flag("contract_questioned")
		set_flag("timing_clue"))
	return true

func read_contract() -> bool:
	if not has("contract_access") or room() != "squirrel" or (not _near("inv_squirrel_record") and not _near("inv_squirrel_boss")):
		return false
	_tell("Contract ledger", "Jaro's entry describes you and Davor, room 12 at Hotel Kinova, and a police disguise. The customer's instruction reads: 'They return after the evening bell and stay in for the night.' No customer's real name appears. Sena's margin note describes a foreign accent they could not place.", [], func() -> void:
		set_flag("contract_records")
		set_flag("accent_clue")
		set_flag("timing_clue"))
	return true

func secretary_menu() -> bool:
	if board_menu():
		return true
	if not has("attack_started") or not world.chapter.has_flag("audience_complete"):
		return false
	var choices: Array = [_choice("Question the Secretary about the hotel information", question_secretary)]
	if has("secretary_questioned"):
		choices.append(_choice("Check the accommodation instruction", check_secretary))
	choices.append(_choice("Ask about the Board's reply", func() -> void: _tell("Tower Guard", "The Engineering Board is still considering the embassy request. Your letters remain in the diplomatic office's custody.")))
	choices.append(_choice("Leave", Callable()))
	_tell("Tower Guard", "The Secretary will hear your account of the attack. The audience and your provisional diplomatic status still stand.", choices)
	return true

func question_secretary() -> bool:
	if not _near("tower") or not has("attack_started"):
		return false
	_scene([
		_line("Diplomatic Secretary", "You told me room twelve. I sent an accommodation authorization to Kinova. I issued no police summons and arranged no questioning at your hotel."),
		_line("You", "Who could read that authorization?"),
		_line("Diplomatic Secretary", "My clerk carried it to reception. The office keeps a copy and the receipt. Examine both. I did not know when you intended to return that evening."),
	], func() -> void: set_flag("secretary_questioned"))
	return true

func check_secretary() -> bool:
	if not _near("tower") or not has("secretary_questioned"):
		return false
	_tell("Office copy and delivery receipt", "The instruction authorizes payment for room twelve and meals. The clerk delivered it to Kinova before the evening arrangements were made. There is no summons or return time. This supports the Secretary's account; it cannot prove what nobody else said privately.", [], func() -> void: set_flag("secretary_checked"))
	return true

func ready_for_deduction() -> bool:
	return has("uniform_found") and has("owner_link") and has("accent_clue") and has("timing_clue")

func _davor_menu() -> void:
	if not attack_resolved():
		return
	var choices: Array = []
	if ready_for_deduction() and not has("mara_named"):
		choices.append(_choice("Name someone to question", open_deduction))
	if has("banishing_arrow_fired"):
		choices.append(_choice("Ask about the Banishing Arrow", explain_banishing_arrow))
	choices.append(_choice("Review what we know", func() -> void: _tell("Davor", evidence_text())))
	choices.append(_choice("Leave", Callable()))
	_tell("Davor", "We should separate what we know from what people want us to believe.", choices)

func explain_banishing_arrow() -> void:
	if not has("banishing_arrow_fired") or not attack_resolved() or encounters.arrow_in_flight():
		return
	set_flag("banishing_arrow_explained")
	_tell("Davor", "A Banishing Arrow. The Admins used them just like Banishing Swords. One hit is enough. Armor won’t save you.")

func evidence_text() -> String:
	var facts: Array[String] = []
	if has("uniform_found"):
		facts.append("The attacker used a real police coat, issue K-214.")
	if has("uniform_identified"):
		facts.append("The equipment register identifies Borin as the coat's owner, not necessarily its wearer.")
	if has("owner_link"):
		facts.append("Jaro of the Green Squirrels paid Borin for the coat.")
	if has("accent_clue"):
		facts.append("The customer had a foreign accent. Sena could not identify it.")
	if has("timing_clue"):
		facts.append("The customer knew we would return after the evening bell and stay in afterward.")
	if has("secretary_checked"):
		facts.append("The Secretary's payment instruction lists the room, not our evening plans.")
	if has("mara_confessed"):
		facts.append("Mara accepted a bribe and rented the neighboring room to two guests asking about us.")
	return "\n".join(facts) if not facts.is_empty() else "We have not established a reliable lead yet."

func open_deduction() -> bool:
	if not ready_for_deduction() or has("mara_named") or (not _near("hotel") and world.player.global_position.distance_to(world.davor.global_position) > 80.0):
		return false
	var ui: GameUI = world.chapter._ui()
	if ui == null:
		return false
	_hints = 0
	ui.open_text_prompt("Davor — compare the clues", "They knew where we were staying and when we would be back. Who should we question?", answer_name, _deduction_hint, "Enter a name")
	return true

func answer_name(text: String) -> Dictionary:
	if not ready_for_deduction() or has("mara_named"):
		return {"accepted": false, "message": "Review the evidence before deciding whom to question."}
	var answer := text.strip_edges().to_lower()
	for punctuation in [".", ",", "!", "?", "'", "\""]:
		answer = answer.replace(punctuation, "")
	while answer.contains("  "):
		answer = answer.replace("  ", " ")
	if answer in ["mara", "receptionist", "the receptionist", "hotel receptionist", "kinova receptionist", "mara the receptionist"] or _one_typo(answer, "mara"):
		set_flag("mara_named")
		GameState.notify("Question Mara at Kinova reception about your evening arrangements.")
		return {"accepted": true, "message": "Mara assigned our room and heard our plans. Let us ask what happened at reception."}
	if answer in ["secretary", "diplomatic secretary", "secretary of diplomacy", "the secretary"]:
		return {"accepted": false, "message": "The Secretary knew the room number. We checked the instruction: it does not contain our evening plans. Who heard those?" if has("secretary_checked") else "That is a reasonable person to question. The Secretary is at the Tower; we can ask what information the office sent."}
	if answer.is_empty():
		return {"accepted": false, "message": "Enter a name, ask for a hint, or leave this question for later."}
	return {"accepted": false, "message": "What did we tell that person? We need someone who could know both the room and our evening plans."}

func _one_typo(answer: String, target: String) -> bool:
	if answer.length() < 3 or answer.length() > 5 or answer.contains(" "):
		return false
	if answer.length() == target.length():
		var differences := 0
		for i in target.length():
			if answer[i] != target[i]:
				differences += 1
		if differences <= 1:
			return true
		for i in range(answer.length() - 1):
			var swapped := answer.substr(0, i) + answer[i + 1] + answer[i] + answer.substr(i + 2)
			if swapped == target:
				return true
	elif answer.length() == target.length() + 1:
		for i in answer.length():
			if answer.erase(i, 1) == target:
				return true
	else:
		for i in target.length():
			if target.erase(i, 1) == answer:
				return true
	return false

func _deduction_hint() -> String:
	_hints += 1
	return "Think about the ordinary conversation where we arranged supper, not only the formal audience." if _hints == 1 else "Who at Hotel Kinova assigned room twelve and heard when we would be back?"

func question_mara() -> bool:
	if not _near("hotel") or not has("mara_named") or has("mara_confessed"):
		return false
	_scene([
		_line("You", "The customer knew we would return after the evening bell and stay in. That is what I told you when we arranged supper."),
		_line("Mara", "People ask about guests all the time. I did not know anyone meant to hurt you."),
		_line("Davor", "Tell us what you did know."),
		_line("Mara", "Two guests described you and asked for the room next to yours. They paid extra. Then they asked when you would be back. I took the money and told them. I thought they wanted a private meeting."),
		_line("Mara", "After the attack I was afraid to tell you. They could come back, and I would lose my job. They rented room thirteen. Here is the spare key. They have gone, but left some luggage."),
	], func() -> void: set_flag("mara_confessed"); sync())
	return true

const MARTIN_LETTER := "One man from Cauliflower and a Special Party arrive today. Watch them. If they stay at a hotel, rent the room beside theirs. When the right moment comes, be ready to terminate both targets. Keep an eye on the Old Man; he could prove problematic.\n— M."

## Older saves that found the front-company slip can search the luggage again for Martin's letter.
func search_neighbor() -> bool:
	if room() != "neighbor" or not _near("inv_neighbor_record") or not has("mara_confessed") or has("martin_letter"):
		return false
	_scene([
		_line("Abandoned luggage", "A room receipt lists two guests under different names. Folded inside a coat is a letter."),
		_line("Letter", MARTIN_LETTER),
		_line("Davor", "M. That is Martin's hand. The Admin himself sent them."),
		_line("You", "The man from Cauliflower is me. The Special Party?"),
		_line("Davor", "Me. Martin knows what I used to be. The Old Man I cannot place. Keep the letter; it proves who ordered the attack. The Board needs to see it."),
	], func() -> void:
		set_flag("neighbor_searched")
		set_flag("martin_letter")
		GameState.add_item("martin_letter")
		GameState.notify("Martin's letter proves he ordered the attack. Rest in room 12; the Board will send word in the morning."))
	return true

## Called when the player rests in room 12. After Martin's letter, morning brings the Board's summons.
func rest_in_room() -> bool:
	if not has("martin_letter") or has("board_summoned"):
		return false
	_scene([
		_line("", "You bolt the door and sleep badly. Davor sits by the window until the lamps outside go pale."),
		_line("Tower Messenger", "Captain? The Engineering Board will see you and Davor at the Tower this morning. A guest from the Confederation has arrived as well."),
	], func() -> void:
		set_flag("board_summoned")
		GameState.restore_health()
		sync())
	return true

func board_menu() -> bool:
	if not has("board_summoned"):
		return false
	var text := "The Board has made its decision. Your credentials will get you a hearing on Breece, but the Tower will not provide a ship." if has("board_met") else "The Engineering Board is waiting for you at the top of the Tower."
	_tell("Tower Guard", text, [
		_choice("Take the lift to the Board chamber", go_to_board),
		_choice("Come back later", Callable()),
	])
	return true

## The lift opens on the chamber; the first time, the meeting starts at once.
func go_to_board() -> bool:
	if not enter_site("board"):
		return false
	if not has("board_met"):
		attend_board()
	return true

## Moves the camera between the player and the wide view of the table; the player stands still during the meeting.
func _board_camera(wide: bool) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var ui: GameUI = world.chapter._ui()
	if ui != null:
		ui.set_top_panels_visible(not wide)
	var centre: Vector2 = Data.ROOMS["board"].position + BOARD_CENTRE + BOARD_VIEW_SHIFT - world.player.global_position
	_zoom_tween = world.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(world._camera, "zoom", Vector2.ONE * (BOARD_ZOOM if wide else 1.0), 1.2)
	_zoom_tween.tween_property(world._camera, "position", centre if wide else CAMERA_OFFSET, 1.2)

func _board_line(key: String, text: String) -> Dictionary:
	var entry: Array = BOARD_HEADS[key] if BOARD_HEADS.has(key) else BOARD_GUESTS[key]
	var speaker: String = entry[0] if String(entry[1]).is_empty() else "%s %s" % [entry[1], entry[0]]
	return {"speaker": speaker, "text": text, "focus": people.get("inv_board_" + key)}

func attend_board() -> bool:
	if room() != "board" or not has("board_summoned") or has("board_met"):
		return false
	world.player.global_position = world.marker("inv_board_mc_stand")
	world.player.velocity = Vector2.ZERO
	world.davor.global_position = world.marker("inv_board_davor_stand")
	world.davor.velocity = Vector2.ZERO
	_board_camera(true)
	_scene([
		_line("", "The lift opens into the top chamber of the Tower, under the great copper dome that sends YellowSand current across the city. Seven Heads sit on raised seats around a copper horseshoe table, above a brass model of Engineeria's five planets. Behind a curved glass wall, the City Computer's consoles glow."),
		_board_line("nation", "Captain, Davor. Stand at the open end of the table. The Board has read the Council's letters. This is the Confederation's Secretary of Diplomacy, Iva Most, who arrived last night after your embassy stopped answering."),
		_board_line("cauliflower_secretary", "I came to find our envoys. Instead I find their captain, and a report that someone tried to murder you in your hotel."),
		_line("You", "Someone did. This was in the room next to ours."),
		_line("", "You lay Martin's letter on the table. It passes from seat to seat."),
		_board_line("technology", "The City Computer has no record of those two guests anywhere but Kinova. They used false names and left the city the same night."),
		_board_line("defense", "An Admin of the Republic ordering killings in our capital. That is a reason to guard our own doors, not to join a war."),
		_board_line("navy", "Our ships carry freight and passengers. Against Republic warships they would not last one battle."),
		_board_line("finance", "Our only open trade is with the Confederation. What reaches the Republic and Breece goes through independent smugglers, and a war would close those routes and empty the treasury in a season."),
		_board_line("nation", "The Board will not risk war with the Republic. The request for military help is refused."),
		_board_line("cauliflower_secretary", "Then the Confederation stands alone."),
		_line("Davor", "Before you close the matter, the Board should know who I was. Martin calls me the Special Party because he knows me. I was a Republic agent before I came to Engineeria."),
		_board_line("defense", "And you want us to trust a former Republic agent?"),
		_line("Davor", "Trust the letter. Martin wants me dead as well. I know how the Republic works. It does not stop at a border because a board voted to stay out. It will come to your door sooner or later."),
		_line("Davor", "Breece holds seven planets against the Republic and is still fighting. Send us there. Learn how Breece does it, and whether an alliance is possible, before the Republic reaches Iskra."),
		_board_line("demographics", "Every person in Iskra is in my census, and almost none of them has held a sword. If the Republic comes, they will look to this table."),
		_board_line("architecture", "Breece builds its cities to be defended. If we ever have to do the same, I would rather learn it from them than from a siege."),
		_line("", "The Heads speak quietly among themselves."),
		_board_line("nation", "No soldiers and no ships. But the Board authorizes a visit to Breece, to learn how they fight and whether they would talk of an alliance. These credentials will get you a hearing."),
		_board_line("navy", "The Tower will not send a ship toward a war. You will have to hire a pilot yourselves."),
		_board_line("cauliflower_secretary", "I will go back to Cauliflower and report everything to the Council: the embassy, Martin's letter, and Breece."),
		_board_line("cauliflower_secretary", "The Council cannot send ships either, but it can pay for the journey. Here are %d gold from the embassy's budget. Spend them on getting to Breece. Good luck, Captain." % BREECE_BUDGET),
	], func() -> void:
		set_flag("board_met")
		GameState.add_item("board_credentials")
		GameState.add_gold(BREECE_BUDGET)
		GameState.notify("Iva Most gave you %d gold for the journey. Engineeria approved a visit to Breece: find a pilot willing to fly there." % BREECE_BUDGET)
		_board_camera(false)
		sync())
	return true

## After the decision each Head speaks about their own work and Breece.
const BOARD_REMARKS := {
	"nation": "The Board's answer stands. Bring back what Breece knows, and this table will listen.",
	"technology": "Breece runs its defenses without a city computer like ours. I would like to know how. Bring back anything written down.",
	"architecture": "Look at Breece's walls and harbors. A city that has held out this long was built for it.",
	"navy": "Find a pilot who knows the long routes. The Republic watches the short ones.",
	"demographics": "Count how many of Breece's people fight and how many keep the cities running. That number matters more than ships.",
	"finance": "An alliance costs money. Find out what Breece would want from us, and what it would give.",
	"defense": "I still do not trust your companion. But if Breece can hold the Republic back, I want to know how.",
	"cauliflower_secretary": "My transport leaves tonight. The Council will hear everything, Captain. Come home with good news from Breece.",
	"diplomatic_secretary": "Your credentials are registered in the Tower's records. Breece will be able to confirm them.",
}

## Veki's main menu shows these choices; the returned text replaces his greeting once he is hired.
func add_veki_choices(choices: Array, text: String) -> String:
	if not _available() or not has("board_met"):
		return text
	if not has("veki_hired"):
		choices.push_front(_choice("Ask Veki to fly to Breece", ask_veki))
		return text
	return "Otpornik first. We take the passenger line there, buy a real ship at the yards and fly it to Breece. You still owe me %d gold when we get back to Cauliflower." % VEKI_BALANCE

func ask_veki() -> bool:
	if not has("board_met") or has("veki_hired"):
		return false
	_scene([
		_line("You", "The Engineering Board approved a visit to Breece, but it will not send a ship. We need a pilot."),
		_line("Veki", "Breece. Past the Republic's patrols, into a war that has lasted longer than I have been flying. Every sensible pilot in Iskra will say no."),
		_line("Davor", "The Board's own Head of Navy said as much."),
		_line("Veki", "Then it is crazy. ...Crazy enough. I will fly you."),
		_line("Veki", "My price is %d gold now, and %d more when you get me back to Cauliflower alive." % [VEKI_ADVANCE, VEKI_BALANCE]),
	], Callable(), [_choice("Pay Veki %d gold" % VEKI_ADVANCE, hire_veki), _choice("Not yet", Callable())])
	return true

func hire_veki() -> bool:
	if not has("board_met") or has("veki_hired"):
		return false
	if not GameState.spend_gold(VEKI_ADVANCE):
		_tell("Veki", "Come back with %d gold. I do not fly on promises." % VEKI_ADVANCE)
		return false
	set_flag("veki_hired")
	_scene([
		_line("Veki", "Good. Now the bad news. My ship is a city hopper. It has no drive for a jump between planets, and its hull would not survive the first one. You need a real Inter Planetary Travel Ship."),
		_line("You", "Where do we buy one?"),
		_line("Veki", "Not on Iskra. Here the yards sell to the Tower and the big freight lines, at prices your Council has never seen. The best place is Otpornik. Its yards build most of Engineeria's ships, and the older ones sell cheap."),
		_line("Davor", "Otpornik. Where the engineers from Blockovia settled after the war."),
		_line("Veki", "We take the passenger line there and fly the new ship to Breece. What you have left will not buy much of a hull, but there is always paid work on Otpornik for people who can fight."),
		_line("Veki", "I am coming with you now. Let's go to the passenger dock."),
	], func() -> void:
		GameState.notify("Veki joined you: %d gold paid, %d more owed after you return to Cauliflower. Go to the passenger dock." % [VEKI_ADVANCE, VEKI_BALANCE]))
	sync()
	return true

func _sync_veki() -> void:
	var hired := _available() and has("veki_hired")
	if hired and veki_companion == null:
		veki_companion = RaidSoldier.new()
		veki_companion.name = "VekiCompanion"
		veki_companion.configure("veki", "Veki", "res://assets/art/iskra/npcs/veki.png", world.player.global_position, "sword", 1, world)
		veki_companion.max_health = 140
		veki_companion.health = 140
		veki_companion.speed = 100.0
		world.actors_root.add_child(veki_companion)
		place_veki()
	if hired and world.gang_jobs != null:
		world.gang_jobs._show(world.gang_jobs.veki, false)
	if veki_companion != null:
		veki_companion.visible = hired and not world.taxi_active
		veki_companion.set_physics_process(veki_companion.visible)

## Puts Veki beside the player after a room change, flight or load.
func place_veki() -> void:
	if veki_companion == null:
		return
	veki_companion.global_position = world.tiled_loader.nearest_walkable_position(world.player.global_position + Vector2(24, 16))
	veki_companion.velocity = Vector2.ZERO
	veki_companion.set_order("follow")

## The Dock Officer issues passes to Otpornik once Veki is with the party.
func dock_menu() -> bool:
	if not _available() or not has("veki_hired"):
		return false
	if has("otpornik_passes"):
		_tell("Dock Officer", "Berth four, the Otpornik line. Your passes are ready whenever you are.")
		return true
	if veki_companion == null or veki_companion.global_position.distance_to(world.player.global_position) > 160.0:
		_tell("Dock Officer", "Passes for Otpornik? Bring your whole party. I issue them to the people standing in front of me.")
		return true
	_scene([
		_line("You", "Three passes on the next line to Otpornik."),
		_line("Dock Officer", "The Captain, Davor and Veki. Board credentials, I see. Then the Tower covers your fares."),
		_line("Veki", "The passenger line is the easy part. The hard part is finding a ship on Otpornik that will survive the trip to Breece."),
		_line("Davor", "Then we start looking as soon as we land."),
		_line("Dock Officer", "Berth four. Your passes are ready whenever you are."),
	], func() -> void:
		set_flag("otpornik_passes")
		GameState.notify("Passes to Otpornik issued. Otpornik is not in the game yet; the Iskra chapter ends here.")
		sync())
	return true

## Before the decision, talking to the Head of Nation restarts a cancelled meeting.
func _board_person(key: String) -> void:
	if has("board_met"):
		_scene([_board_line(key, BOARD_REMARKS[key])])
	elif key == "nation":
		attend_board()
	else:
		_scene([_board_line(key, "Speak to the Head of Nation first. The Board will hear you together.")])

func enter_site(site: String) -> bool:
	if not Data.ROOMS.has(site) or _busy():
		GameState.notify("Finish carrying cargo or escorting your companions before entering.")
		return false
	var entry: String = "hotel" if site == "hall" else "inv_hall_neighbor" if site == "neighbor" else "tower" if site == "board" else "inv_" + site + "_entry"
	if not _near(entry):
		return false
	if (site == "hall" and not has("attack_started")) or (site == "owner" and not has("uniform_identified")) or (site == "squirrel" and not has("owner_link")) or (site == "pelican" and not has("boss_met")) or (site == "board" and not has("board_summoned")):
		_tell("", "You do not have business here yet.")
		return false
	if site == "neighbor" and not has("mara_confessed"):
		_tell("", "Room thirteen is locked. Do not force a guest's door without a reason.")
		return false
	_move("inv_" + site + "_arrival")
	return true

func leave_site() -> bool:
	var site := room()
	if site.is_empty() or not _near("inv_" + site + "_exit"):
		return false
	_move(Data.EXITS[site])
	return true

func _move(marker: String) -> void:
	encounters.capture_state()
	world.player.global_position = world.marker(marker)
	world.player.velocity = Vector2.ZERO
	set_value("site", room())
	world._move_davor()
	GameState.remember_player_position(world.player.global_position)
	world.chapter.refresh_location()
	world.gang_jobs.refresh_camera()
	encounters.refresh_room()
	refresh_location()
	sync()

func position_davor() -> bool:
	place_veki()
	if room().is_empty():
		return false
	world.davor.global_position = world.tiled_loader.nearest_walkable_position(world.player.global_position + Vector2(-24, 16))
	world.davor.velocity = Vector2.ZERO
	world.davor.set_order("follow")
	return true

func refresh_location() -> void:
	var site := room()
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	# A load or world change ends the meeting scene early, so the camera returns to the player here.
	world._camera.zoom = Vector2.ONE
	world._camera.position = CAMERA_OFFSET
	var top_ui: GameUI = world.chapter._ui()
	if top_ui != null:
		top_ui.set_top_panels_visible(true)
	if not site.is_empty():
		var rect: Rect2 = Data.ROOMS[site]
		world._camera.limit_left = int(rect.position.x) - 32
		world._camera.limit_right = int(rect.end.x) + 32
		world._camera.limit_top = int(rect.position.y) - 32
		world._camera.limit_bottom = int(rect.end.y) + 32
		world._camera.reset_smoothing()
	var ui: GameUI = world.chapter._ui()
	if ui != null:
		ui.refresh_location()

func capture_state() -> void:
	if has("attack_started") or not GameState.iskra_investigation_state.is_empty():
		set_value("site", room())
		encounters.capture_state()

func apply_loaded_state() -> void:
	if has("pelican_cleared"):
		set_flag("hacker_killed")
		set_flag("contract_access")
	if has("squirrel_cleared"):
		set_flag("contract_access")
	encounters.apply_loaded_state()
	position_davor()
	refresh_location()
	sync()
	if has("attack_started") and str(get_value("assassin_phase", "")) == "waiting" and room() == "hall" and not _resume_queued:
		_resume_queued = true
		_resume_summons.call_deferred()

func _resume_summons() -> void:
	_resume_queued = false
	if not is_instance_valid(world) or not world.is_inside_tree() or world.get_tree().get_first_node_in_group("game_world") != world:
		return
	var ui: GameUI = world.chapter._ui()
	if ui != null and not ui.scene_playing() and not ui.modal_overlay.visible:
		_summons()

func on_respawn() -> void:
	encounters.on_respawn()
	world.chapter.refresh_location()
	world.gang_jobs.refresh_camera()
	position_davor()
	refresh_location()
	sync()

func _show(actor: Node2D, visible: bool) -> void:
	actor.visible = visible
	if visible:
		actor.add_to_group("interactable")
	else:
		actor.remove_from_group("interactable")

func sync() -> void:
	_sync_veki()
	for id: String in people:
		var visible := true
		match id:
			"inv_hall_attacker": visible = has("attack_started") and str(get_value("assassin_phase", "")) == "waiting"
			"inv_hall_evidence":
				visible = attack_resolved() and not has("uniform_found")
				var point := Vector2(float(get_value("evidence_x", world.marker(id).x)), float(get_value("evidence_y", world.marker(id).y)))
				people[id].global_position = world.tiled_loader.nearest_walkable_position(point)
			"inv_owner_entry": visible = has("uniform_identified")
			"inv_squirrel_handler", "inv_squirrel_record": visible = has("contract_access")
			"inv_squirrel_boss": visible = not has("squirrel_boss_killed") and not is_instance_valid(encounters.enemies.get("squirrel_boss"))
			"inv_pelican_boss": visible = not hostile("pelican")
			"inv_davor": visible = attack_resolved() and not world.taxi_active
			_:
				if id.begins_with("inv_board_") and id != "inv_board_exit":
					visible = has("board_summoned")
		_show(people[id], visible)

func step(delta: float) -> void:
	encounters.step(delta)
	if has("banishing_arrow_fired") and not has("banishing_arrow_explained") and attack_resolved() and not encounters.arrow_in_flight() and not world.player.ui_is_open() and not world.get_tree().paused and not world.taxi_active:
		explain_banishing_arrow()
	if people.has("inv_davor"):
		people.inv_davor.global_position = world.davor.global_position + Vector2(0, 8)
		people.inv_davor.z_index = 100 + int(people.inv_davor.global_position.y)
	sync()

func status() -> String:
	if not _available():
		return ""
	if has("otpornik_passes"):
		return "Otpornik: your passes are ready at the passenger dock. Otpornik is not playable yet."
	if has("veki_hired"):
		return "Breece: go to the passenger dock with Veki for the line to Otpornik."
	if has("board_met"):
		return "Breece: find a pilot willing to fly there."
	if has("board_summoned"):
		return "The Engineering Board is waiting for you at the Tower."
	if has("martin_letter"):
		return "Martin ordered the attack. Rest in room 12; the Board will send word."
	if get_value("encounter", "") == "pelican" or get_value("encounter", "") == "squirrel":
		return "Hotel investigation: the confrontation is underway."
	if attack_resolved():
		return "Hotel investigation: follow the evidence."
	if has("attack_started"):
		return "Hotel Kinova: answer the officer at room twelve." if str(get_value("assassin_phase", "")) == "waiting" else "Hotel Kinova: stop the attacker or follow the evidence left behind."
	# Nothing on the HUD before the attack, so the evening at Kinova stays a surprise.
	return ""

func _line(speaker: String, text: String) -> Dictionary:
	return world.chapter._line(speaker, text)

func _scene(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	world.chapter._scene(lines, finished, choices)

func _tell(speaker: String, text: String, choices: Array = [], finished: Callable = Callable()) -> void:
	_scene([_line(speaker, text)], finished, choices)

func _choice(label: String, action: Callable) -> Dictionary:
	return {"label": label, "action": action}
