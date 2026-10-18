extends RefCounted

const ROOM_FARE := 20
const ROOM_NUMBER := 12
const ROOM_RECT := Rect2(64, 2816, 384, 256)
const LOBBY_RECT := Rect2(3520, 2816, 384, 256)
const HIDDEN_DOORS := ["hotel_door", "hotel_stairs", "hotel_lobby_door"]
const CITY_HEIGHT := 2608
const LETTERS := "embassy_letters"
const SERVICES := {
	"hotel": ["Mara — Hotel Kinova", "library_archivist"],
	"hotel_door": ["Enter Hotel Kinova", "library_archivist"],
	"hotel_stairs": ["Go up to room 12", "civic_engineer"],
	"hotel_lobby_door": ["Leave Hotel Kinova", "civic_engineer"],
	"hotel_laundry": ["Kinova linen shelf", "dock_mechanic"],
	"park_vendor": ["Rina — Park Kitchen", "market_keeper"],
	"red_pelican": ["Ves — Red Pelicans", "punk_braces"],
	"green_squirrel": ["Toma — Green Squirrels", "punk_crust"],
	"park_witness": ["Eda — Park Musician", "punk_stripes"],
	"workshop": ["Boro — Workshop", "dock_mechanic"],
	"courier": ["Leko — Dock Courier", "canal_worker"],
	"hotel_room_bed": ["Your bed — room 12", "civic_engineer"],
	"hotel_room_chest": ["Your chest — room 12", "civic_engineer"],
	"hotel_room_exit": ["Return to Kinova reception", "civic_engineer"],
}

var world: Node2D

func _init(owner_world: Node2D) -> void:
	world = owner_world

func has_flag(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has("iskra_" + flag)

func set_flag(flag: String) -> void:
	world._set_flag("iskra_" + flag)

func in_room() -> bool:
	return ROOM_RECT.has_point(world.player.global_position)

func in_lobby() -> bool:
	return LOBBY_RECT.has_point(world.player.global_position)

func _near(id: String) -> bool:
	return not world.taxi_active and world.player.global_position.distance_to(world.marker(id)) <= 48.0

func setup() -> void:
	for id: String in SERVICES:
		var entry: Array = SERVICES[id]
		var staff := StationStaff.new()
		staff.configure("iskra:" + id, entry[0], "res://assets/art/iskra/npcs/%s.png" % entry[1], world.marker(id))
		if id.begins_with("hotel_room_") or id == "hotel_laundry" or id in HIDDEN_DOORS:
			staff.get_child(0).visible = false
			staff.interaction_text = entry[0]
		world.actors_root.add_child(staff)
		staff.service_requested.connect(world._on_service_requested)
		world.story_people[id] = staff
		if not id.begins_with("hotel_room_") and id not in HIDDEN_DOORS:
			var label := Label.new()
			label.text = {"hotel": "HOTEL KINOVA", "hotel_laundry": "LINEN", "park_vendor": "PARK KITCHEN", "red_pelican": "RED PELICANS", "green_squirrel": "GREEN SQUIRRELS", "park_witness": "EDA", "workshop": "WORKSHOP", "courier": "LEKO"}[id]
			label.position = Vector2(-70, -36)
			label.size = Vector2(140, 14)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 8)
			label.add_theme_color_override("font_color", Color("f5d88d"))
			staff.add_child(label)
	world.story_people["tower"].display_name = "Tower Guard"
	world.story_people["tower"].interaction_text = "Speak to the Tower guard"

func refresh_location() -> void:
	var indoors := in_room() or in_lobby()
	world._camera.limit_left = 0
	world._camera.limit_right = int(world.tiled_loader.map_size.x)
	world._camera.limit_top = 0 if not indoors else 2704
	world._camera.limit_bottom = CITY_HEIGHT if not indoors else 3184
	if in_room():
		world._camera.limit_left = -128
		world._camera.limit_right = 640
	elif in_lobby():
		world._camera.limit_left = int(LOBBY_RECT.position.x) - 32
		world._camera.limit_right = int(LOBBY_RECT.end.x) + 32
		world._camera.limit_top = int(LOBBY_RECT.position.y) - 32
		world._camera.limit_bottom = int(LOBBY_RECT.end.y) + 32
	world._camera.reset_smoothing()
	world.player.respawn_position = world.marker("hotel_room_arrival") if has_flag("room_rented") else world.marker("respawn")
	world.player.respawn_location_name = "Hotel Kinova, room 12" if has_flag("room_rented") else "Iskra passenger dock"
	var ui := _ui()
	if ui != null:
		ui.refresh_location()

func status() -> String:
	var objective := ""
	if not has_flag("arrival"):
		objective = "Speak to the officer at the passenger dock."
	elif not has_flag("registered"):
		objective = "Register at the police post west of the Tower."
	elif not has_flag("tower_closed_seen"):
		objective = "Ask the guard at the Tower for an audience."
	elif not has_flag("morning"):
		objective = "The Tower opens in the morning. Explore Punk Park.\n" + ("Sleep in your bed at Hotel Kinova, room 12, when ready." if has_flag("room_rented") else "Rent room 12 at Hotel Kinova, west of Punk Park — 20 gold.")
	elif not has_flag("audience_complete"):
		objective = "Morning: take the sealed letters to the Tower guard."
	elif not has_flag("hotel_cover_confirmed"):
		objective = "The Board is considering the embassy request.\nSpeak to Mara at Kinova; Engineeria covers room 12 and meals."
	elif world.investigation != null and world.investigation.has("veki_hired"):
		objective = "Veki will fly you to Breece.\nTake the passenger line to Otpornik and buy an interplanetary ship there."
	elif world.investigation != null and world.investigation.has("board_met"):
		objective = "The Board refused military help but approved a visit to Breece."
	else:
		objective = "Provisional diplomat — Board decision pending.\nRoom 12 and meals at Hotel Kinova are covered."
	var jobs: Array[String] = []
	if has_flag("vendor_job") and not has_flag("vendor_paid"):
		jobs.append("Rina: " + ("return the speaker coil to Punk Park" if has_flag("vendor_coil") else "collect the speaker coil at Boro's workshop, north of the park"))
	if has_flag("pelican_job") and not has_flag("pelican_paid") and not has_flag("pelican_returned") and not has_flag("pelican_cancelled"):
		jobs.append("Ves: " + ("return to the Red Pelicans for 25 gold" if has_flag("pelican_delivered") else "take the envelope to Leko on the civilian dock, or return it"))
	if has_flag("linen_job") and not has_flag("room_rented"):
		jobs.append("Kinova: " + ("return the linen to Mara for room credit" if has_flag("linen_taken") else "collect fresh linen from the shelf just west of reception"))
	return objective + ("\n" + "\n".join(jobs) if not jobs.is_empty() else "")

func handle(key: String) -> bool:
	match key:
		"dock_officer":
			if world.investigation != null and world.investigation.dock_menu():
				return true
			_scene([_line("Dock Officer", "Welcome to Iskra. Register at the police post west of the Tower of Engineering. The city keeps its lamps on through the night; public offices keep ordinary hours.")], func() -> void: set_flag("arrival"))
		"police":
			if world.investigation != null and world.investigation.police_menu():
				return true
			if not has_flag("arrival"):
				_tell("Police Clerk", "Speak to the officer at the passenger dock first.")
			else:
				_scene([_line("Police Clerk", "Two arrivals from Skoljka: you and Davor. Your registration is in order. The Tower guard can tell you when the diplomatic office receives visitors.")], func() -> void: set_flag("registered"))
		"tower": _tower()
		"hotel": _hotel()
		"hotel_door": enter_lobby()
		"hotel_stairs": enter_stairs()
		"hotel_lobby_door": leave_lobby()
		"hotel_laundry": _linen()
		"hotel_room_bed": _bed()
		"hotel_room_chest": _storage()
		"hotel_room_exit": leave_room()
		"park_vendor": _vendor()
		"workshop": _workshop()
		"red_pelican": _pelican()
		"courier": _courier()
		"green_squirrel": _squirrel()
		"park_witness": _witness()
		"park":
			_tell("Punk Park", "Music, painted walls and colored lamps fill this corner of Iskra. Rina runs the little kitchen; Eda plays near the southern path. Ves and Toma keep separate tables. They do not get along.")
		_: return false
	return true

func _tower() -> void:
	if world.investigation != null and world.investigation.secretary_menu():
		return
	if not has_flag("registered"):
		_tell("Tower Guard", "Register with the police before requesting an audience.")
	elif not has_flag("morning"):
		_scene([
			_line("Tower Guard", "The Tower is closed to visitors. The diplomatic office opens in the morning. No, not even for a captain."),
			_line("Davor", "Morning, then. We could both use a meal."),
			_line("Tower Guard", "Try Punk Park if you need work or supper. Hotel Kinova is west of it, along the same street. Mara usually has a room."),
		], func() -> void: set_flag("tower_closed_seen"))
	elif has_flag("audience_complete"):
		_tell("Tower Guard", "The Diplomatic Secretary has sent the letters to the Engineering Board. There is no decision yet. Any message for you will go to room 12 at Hotel Kinova.")
	elif not has_flag("room_rented"):
		_tell("Tower Guard", "The diplomatic office needs a local address for its reply. Arrange your room at Hotel Kinova first.")
	elif int(GameState.inventory.get(LETTERS, 0)) < 1:
		_tell("Tower Guard", "The Secretary needs the sealed embassy letters you recovered on Rudnik. Bring the originals; an account of the journey is not a diplomatic request.")
	else:
		_tell("Tower Guard", "The diplomatic office is open. The Secretary can see you and your companion now.", [
			{"label": "Attend the audience", "action": audience},
			{"label": "Come back later", "action": Callable()},
		])

func audience() -> bool:
	if not _near("tower") or not has_flag("morning") or not has_flag("registered") or not has_flag("room_rented") or has_flag("audience_complete") or int(GameState.inventory.get(LETTERS, 0)) < 1:
		return false
	_scene([
		_line("", "The guard leads you to the diplomatic office. The Secretary looks up from a stack of dispatches."),
		_line("Diplomatic Secretary", "You say you guarded a Confederation embassy. Where are the envoys?"),
		_line("You", "Dead. Our ship was boarded, then brought down on Rudnik. I recovered these letters from the wreck. The Council's seals are intact."),
		_line("Diplomatic Secretary", "I can examine a seal. It does not establish your authority to speak for the Council, or prove who attacked you."),
		_line("Davor", "The captain has come a long way. Hear them out."),
		_line("Diplomatic Secretary", "Davor? You might have sent word."),
		_line("Davor", "We had trouble finding a ship."),
		_line("Diplomatic Secretary", "Very well. Tell me what happened, from Artichoke onward."),
		_line("", "You describe the war, the Council's request, the lost embassy and the sabotage on Skoljka. The Secretary records your account, then accepts the sealed letters."),
		_line("Diplomatic Secretary", "I will put the letters before the Engineering Board. Hearing your request is not a promise to enter the war. Until they decide, you have provisional diplomatic status."),
		_line("Diplomatic Secretary", "Where are you staying?"),
		_line("You", "Hotel Kinova."),
		_line("Diplomatic Secretary", "Room number?"),
		_line("You", "Twelve. Davor and I share it."),
		_line("Diplomatic Secretary", "I will notify reception. Engineeria will cover your room and meals while the Board considers your request. Stay in that room; we will send any messages there."),
	], _finish_audience)
	return true

func _finish_audience() -> void:
	if has_flag("audience_complete") or not has_flag("morning") or not has_flag("room_rented") or not GameState.remove_item(LETTERS):
		return
	set_flag("tower_received")
	set_flag("audience_complete")
	GameState.notify("Provisional diplomatic status. Engineeria covers Hotel Kinova, room 12, and meals.")

func _hotel() -> void:
	if has_flag("audience_complete") and not has_flag("hotel_cover_confirmed"):
		_scene([_line("Mara", "The diplomatic office sent word. Engineeria is paying for room twelve and your meals from now on. Same room, same key. Leave any messages for the Secretary with me.")], func() -> void: set_flag("hotel_cover_confirmed"))
		return
	var choices: Array = []
	var text := "Room twelve has two beds and a lockable chest. Twenty gold for the night, for both of you. We are just west of Punk Park."
	if has_flag("room_rented"):
		text = "Room twelve is yours. Your things will stay in the chest. The stairs are by the lobby door; rest when you are ready."
	else:
		choices.append({"label": "Rent room 12 — use linen-work credit" if has_flag("linen_credit") else "Rent room 12 — 20 gold", "action": rent_room})
		if has_flag("linen_taken") and not has_flag("linen_credit"):
			choices.append({"label": "Give Mara the fresh linen", "action": _finish_linen})
		elif not has_flag("linen_credit"):
			choices.append({"label": "Ask about work for the room", "action": _offer_linen})
	if world.gang_jobs != null and world.gang_jobs.has("hunt_flight_clue") and not world.gang_jobs.has("hunt_hotel_clue"):
		choices.append({"label": "Ask about Miro's lodging", "action": world.gang_jobs.offer_hotel_clue})
	if world.investigation != null:
		world.investigation.add_hotel_choices(choices)
	choices.append({"label": "Leave reception", "action": Callable()})
	_tell("Mara — Hotel Kinova", text, choices)

func rent_room() -> bool:
	if not _near("hotel") or has_flag("room_rented"):
		return false
	if not has_flag("linen_credit") and not GameState.spend_gold(ROOM_FARE):
		_tell("Mara", "If you are short, Rina at Punk Park needs a delivery. Or bring me the clean linen from our shelf to the west and I can put twenty gold of work against the room.")
		return false
	set_flag("room_rented")
	_tell("Mara", "Here is your key. Room twelve, two beds. Use the chest for your belongings. The stairs are past the desk when you want them.")
	return true

func _offer_linen() -> void:
	_scene([_line("Mara", "Carry the clean linen from the shelf just west of reception back to me. I will credit twenty gold against your room. No fee, and no debt. The credit is for lodging, not cash.")], func() -> void: set_flag("linen_job"))

func _linen() -> void:
	if has_flag("linen_job") and not has_flag("linen_taken") and not has_flag("room_rented"):
		_scene([_line("", "You take two neatly tied bundles of clean linen. Bring them back to Mara at reception.")], func() -> void: set_flag("linen_taken"))
	else:
		_tell("", "Fresh linen for Hotel Kinova. Ask Mara at reception before taking it.")

func _finish_linen() -> void:
	if not _near("hotel") or not has_flag("linen_taken") or has_flag("linen_credit") or has_flag("room_rented"):
		return
	_scene([_line("Mara", "Thank you. That pays for room twelve. Tell me when you want the key; your lodging credit will wait.")], func() -> void: set_flag("linen_credit"))

func enter_lobby() -> bool:
	if world.gang_jobs != null and world.gang_jobs.busy_travel():
		GameState.notify("Finish carrying cargo or escorting people before going inside.")
		return false
	if not _near("hotel_door"):
		return false
	_move_to("hotel_lobby_arrival")
	return true

func leave_lobby() -> bool:
	if not _near("hotel_lobby_door"):
		return false
	_move_to("hotel_door")
	return true

func enter_stairs() -> bool:
	if world.gang_jobs != null and world.gang_jobs.busy_travel():
		GameState.notify("Finish carrying cargo or escorting people before returning to your room.")
		return false
	if not _near("hotel_stairs"):
		return false
	if not has_flag("room_rented"):
		_tell("", "The stairs lead to the guest rooms. Rent a room from Mara first.")
		return true
	_move_to("hotel_room_arrival")
	return true

func leave_room() -> bool:
	if not _near("hotel_room_exit"):
		return false
	if world.investigation != null and world.investigation.has("attack_started"):
		world.investigation._move("inv_hall_room12")
	else:
		_move_to("hotel_stairs")
	return true

func _move_to(id: String) -> void:
	if world.investigation != null:
		world.investigation.encounters.capture_state()
	world.player.global_position = world.marker(id)
	world.player.velocity = Vector2.ZERO
	world._move_davor()
	GameState.remember_player_position(world.player.global_position)
	refresh_location()
	if world.investigation != null:
		world.investigation.encounters.refresh_room()
		world.investigation.refresh_location()

func _bed() -> void:
	if not has_flag("room_rented") or not in_room():
		return
	if not has_flag("tower_closed_seen"):
		_tell("Davor", "We should ask at the Tower before turning in. Perhaps someone is still there.")
		return
	_tell("Your bed — room 12", "Sleep until morning? You can still finish the city jobs tomorrow." if not has_flag("morning") else "Rest in your own bed? The Board will send word when it has a decision.", [
		{"label": "Sleep until morning" if not has_flag("morning") else "Rest and recover", "action": sleep_in_room},
		{"label": "Keep exploring", "action": Callable()},
	])

func sleep_in_room() -> bool:
	if not _near("hotel_room_bed") or not has_flag("room_rented") or not has_flag("tower_closed_seen"):
		return false
	if has_flag("morning"):
		if world.investigation != null and world.investigation.rest_in_room():
			return true
		GameState.restore_health()
		_tell("", "You rest. Downstairs, cups and plates clatter in Kinova's kitchen.")
	else:
		_scene([_line("", "You lock the door. Davor takes the other bed. The city lamps shine through the shutters long after the music has stopped."), _line("", "Morning. There are footsteps in the corridor and breakfast downstairs. The Tower's public offices are open.")], func() -> void:
			set_flag("morning")
			GameState.restore_health()
			refresh_location())
	return true

func hotel_meal() -> bool:
	if not _near("hotel") or not has_flag("room_rented") or GameState.health >= GameState.max_health:
		GameState.notify("You are already rested and fed." if GameState.health >= GameState.max_health else "Rent your room first.")
		return false
	if not has_flag("audience_complete") and not GameState.spend_gold(5):
		return false
	GameState.restore_health()
	_tell("Mara", "A hot meal for each of you. The diplomatic office covers it." if has_flag("audience_complete") else "Two hot meals. Take a seat.")
	return true

func _storage() -> void:
	if not _near("hotel_room_chest") or not has_flag("room_rented"):
		return
	var ui := _ui()
	if ui == null:
		return
	ui._active_service_id = "iskra_room_storage"
	ui._open_modal("Kinova room 12 — your chest")
	ui._add_body("Store spare belongings here. Equipped items and embassy letters stay with you. Contents are saved with the game.")
	ui._add_heading("In your pack")
	for item_id: String in GameState.inventory:
		var count := int(GameState.inventory[item_id]) - GameState.reserved_item_count(item_id)
		if count > 0 and GameData.item(item_id).get("kind", "") != "key":
			ui._add_action_button("Store %s × %d" % [GameData.item(item_id)["name"], count], func() -> void: transfer_storage(item_id, true); _storage())
	ui._add_heading("In the chest")
	if GameState.iskra_storage.is_empty():
		ui._add_body("Empty")
	for item_id: String in GameState.iskra_storage:
		ui._add_action_button("Take %s × %d" % [GameData.item(item_id)["name"], GameState.iskra_storage[item_id]], func() -> void: transfer_storage(item_id, false); _storage())
	ui._add_close_button()

func transfer_storage(item_id: String, deposit: bool) -> bool:
	if not _near("hotel_room_chest") or not has_flag("room_rented") or not GameData.ITEMS.has(item_id) or GameData.item(item_id).get("kind", "") == "key":
		return false
	if deposit:
		var count := int(GameState.inventory.get(item_id, 0)) - GameState.reserved_item_count(item_id)
		if count <= 0 or not GameState.remove_item(item_id, count):
			return false
		GameState.iskra_storage[item_id] = int(GameState.iskra_storage.get(item_id, 0)) + count
	else:
		var count := int(GameState.iskra_storage.get(item_id, 0))
		if count <= 0:
			return false
		GameState.iskra_storage.erase(item_id)
		GameState.add_item(item_id, count)
	return true

func _vendor() -> void:
	if has_flag("vendor_paid"):
		_tell("Rina", "That coil saved tonight's kitchen announcements. Thank you. If you need a bed, Kinova is west along the street.")
	elif has_flag("vendor_coil"):
		_scene([_line("Rina", "The speaker coil! Now people will hear me when their supper is ready. Thirty gold, as promised. It is ordinary work, whatever Ves says about my prices.")], func() -> void:
			if not has_flag("vendor_paid"):
				set_flag("vendor_paid")
				GameState.add_gold(30))
	elif has_flag("vendor_job"):
		_tell("Rina", "Boro at the workshop north of Punk Park has my speaker coil. Bring it back here. Thirty gold when it arrives.")
	else:
		_tell("Rina", "Want honest work? Boro has repaired my speaker coil. His workshop is north of the park, near the forge. Bring it here and I will pay thirty gold.", [{"label": "Collect the speaker coil", "action": func() -> void: set_flag("vendor_job")}, {"label": "Not now", "action": Callable()}])

func _workshop() -> void:
	if has_flag("vendor_job") and not has_flag("vendor_coil"):
		_scene([_line("Boro", "Rina sent you? Here is her coil. It is repaired, not new. Tell her not to put the speaker beside the soup pot again.")], func() -> void: set_flag("vendor_coil"))
	else:
		_tell("Boro", "Repairs for the park kitchens and the canal boats. If Rina needs her speaker coil, she can send someone to collect it.")

func _pelican() -> void:
	if has_flag("pelican_returned"):
		_tell("Ves", "You returned the envelope. No payment, no further business. Go and listen to Toma's speeches if you like.")
	elif has_flag("pelican_paid"):
		_tell("Ves", "A delivery is a delivery. You have been paid; you have not joined the Red Pelicans. Anything further would be a separate agreement.")
	elif has_flag("pelican_delivered"):
		_scene([_line("Ves", "Leko has the notice. Here is your twenty-five. Julius likes his accounts delivered on time. No, this does not make you one of us.")], func() -> void:
			if not has_flag("pelican_paid"):
				set_flag("pelican_paid")
				GameState.add_gold(25))
	elif has_flag("pelican_job"):
		_tell("Ves", "Leko waits on the civilian dock, south of the passenger landing. Give him the envelope and come back.", [{"label": "Return the envelope; refuse the job", "action": func() -> void: set_flag("pelican_returned")}, {"label": "Keep the delivery", "action": Callable()}])
	else:
		_tell("Ves — Red Pelicans", "Twenty-five gold to deliver an envelope to Leko at the dock. We are the Red Pelicans. Julius backs our business here. One delivery does not mean joining us.", [{"label": "Accept the delivery — 25 gold", "action": func() -> void: set_flag("pelican_job")}, {"label": "Refuse", "action": Callable()}])

func _courier() -> void:
	if has_flag("pelican_job") and not has_flag("pelican_delivered") and not has_flag("pelican_returned") and not has_flag("pelican_cancelled"):
		_tell("Leko", "Ves sent that? Another demand for protection money. Julius's Pelicans call it rent, but they own none of these docks. You can leave the notice, or take it back. I will not pay you to choose.", [{"label": "Leave the envelope", "action": func() -> void: set_flag("pelican_delivered")}, {"label": "Keep it to return to Ves", "action": Callable()}])
	else:
		_tell("Leko", "I carry cargo lists, not protection money. The boats already pay the port authority.")

func _squirrel() -> void:
	_scene([_line("Toma — Green Squirrels", "Ves calls every street an account. The Green Squirrels answer to nobody on Pomidor. Especially not Julius."), _line("You", "Are you offering work?"), _line("Toma", "Not tonight. We are looking for people who can think before swinging a sword. Talk to Leko at the dock before you carry anything for the Pelicans."), _line("Davor", "And what would we owe you?"), _line("Toma", "For a conversation? Nothing. If that changes, I will say so.")], func() -> void: set_flag("squirrels_met"))

func _witness() -> void:
	if not has_flag("stranger_heard"):
		_scene([_line("Eda", "There was a man here asking about two foreigners. An old man and a soldier. You only landed today, didn't you?"), _line("Davor", "What did you tell him?"), _line("Eda", "Nothing. I had not seen you. I remember him, though.")], func() -> void: set_flag("stranger_heard"))
		return
	_tell("Eda", "What did you want to know about the man asking after you?", [
		{"label": "Appearance?", "action": func() -> void: _clue("stranger_coat", "A grey coat with a brass clasp shaped like a hook. No uniform. He kept his right glove on while he counted coins.")},
		{"label": "What did he ask?", "action": func() -> void: _clue("stranger_question", "Which ship brought you, and where visitors from Skoljka usually sleep. He offered money for a room number. I did not have one.")},
		{"label": "Where did he go?", "action": func() -> void: _clue("stranger_route", "North along the eastern canal, toward the freight booths. He spoke to someone under the green awning. I lost sight of them behind a cargo boat.")},
		{"label": "Leave", "action": Callable()},
	])

func _clue(flag: String, text: String) -> void:
	_scene([_line("Eda", text)], func() -> void: set_flag(flag))

func _line(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text, "focus": world.davor if speaker == "Davor" else null}

func _tell(speaker: String, text: String, choices: Array = []) -> void:
	_scene([_line(speaker, text)], Callable(), choices)

func _ui() -> GameUI:
	return world.get_tree().get_first_node_in_group("game_ui") as GameUI

func _scene(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := _ui()
	if ui != null:
		ui.play_scene(lines, finished, choices)
