extends Node

## The embassy to Engineeria: Julius's people on Pomidor, the Council meeting,
## Chvarak, the ambush on the diplomatic ship, the crash and Davor.

var checks := 0
var failures := 0
var game: Node
var ui: GameUI
var state := GameState

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	var save_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	if data_home.is_empty() or not save_path.begins_with(data_home + "/"):
		_check(false, "the embassy smoke test requires an isolated XDG_DATA_HOME")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.get_node_or_null("GameUI") as GameUI
	if ui == null or game.world == null:
		_check(false, "main scene starts with UI and a world")
		_finish()
		return
	state.notify("First notice")
	state.notify("Second notice")
	_check(ui.notification_label.text == "Second notice" and ui.notification_label.get_meta("panel").visible and ui.notification_label.get_parent().get_child_count() == 1, "a new notice replaces the previous notice rather than drawing two lines")
	ui.play_scene([{"speaker": "Test", "text": "A scene begins."}])
	_check(ui.scene_playing() and not ui.notification_label.get_meta("panel").visible, "a dialogue scene hides the preceding notice")
	ui.cancel_scene()
	if not await _pomidor():
		_finish()
		return
	if not await _chvarak():
		_finish()
		return
	if not await _engineeria():
		_finish()
		return
	_finish()

# ---- Pomidor ----

func _pomidor() -> bool:
	state.military_stage = "graduated"
	state.military_cannon_hits.assign(state.MILITARY_CANNON_TARGETS.duplicate())
	state.military_trap_progress = state.MILITARY_TRAP_STEPS.size()
	state.defeated_persistent_enemies.append(state.POMIDOR_UNLOCK_FLAG)
	state.current_planet = "artichoke"
	state.current_area = "exterior"
	_check(game._switch_world("artichoke"), "Artichoke loads")
	ui.open_service("artichoke_ship", "Military Transport")
	var fly := _find_button(ui.modal_content, "Fly to Pomidor")
	if fly == null:
		_check(false, "the Artichoke transport flies to Pomidor")
		return false
	fly.pressed.emit()
	await get_tree().process_frame
	var town := game.world as PomidorWorld
	if town == null:
		_check(false, "the player reaches Pomidor")
		return false
	var loader := town.tiled_loader
	_check(town.story_stage() == "report", "the story on Pomidor starts at the report")
	for key in PomidorWorld.STORY_PEOPLE:
		var someone := town.story_person(key)
		_check(someone != null and loader.is_walkable_position(someone.global_position) or someone != null and loader.is_walkable_position(someone.global_position + Vector2(0, 6)), "%s stands on open ground" % key)
	for key in PomidorWorld.ENVOYS:
		_check(not town.story_person(key).visible, "%s is not in town before the Council decides" % key)

	# Before the report the collectors send the player away.
	_talk(town, "mila")
	_check(ui.scene_playing() and _scene_text().contains("Keep walking"), "before the report the collectors send the player on")
	_end_scene()
	town.report_to_council()
	_check(town.story_stage() == "wait" and ui.job_label.text.contains("bell"), "after the report the player waits in town for the bell")

	# Ludo only takes no for an answer.
	_talk(town, "ludo")
	_skip_to_choices()
	var ludo_choices := _scene_choice_labels()
	_check(ludo_choices.size() == 2 and ludo_choices.has("Refuse") and ludo_choices.has("Walk away"), "Ludo's offer can only be refused or walked away from (%s)" % ", ".join(ludo_choices))
	_choose("Refuse")
	_check(state.defeated_persistent_enemies.has(PomidorWorld.LUDO_FLAG) and ui.scene_playing() and _scene_text().contains("any town"), "refusing Ludo is remembered and he says the Organisation is everywhere")
	_end_scene()

	# The smugglers, the doorman and the navy's missing cargo.
	_talk(town, "smuggler_0")
	_end_scene()
	_check(state.defeated_persistent_enemies.has(PomidorWorld.SMUGGLERS_FLAG), "seeing the smugglers' crates is remembered")
	ui.open_service(PomidorWorld.COUNCIL_SERVICE_PREFIX + "secretary_navy", "Navy")
	_check(_has_text(ui.modal_content, "count wrong"), "the Secretary of the Navy knows cargo goes missing")
	ui.close_modal()
	_talk(town, "doorman")
	_check(ui.scene_playing() and _scene_text().contains("Members only"), "the doorman of the red-lantern house turns the player away")
	_end_scene()

	# The collectors: paying ends it.
	var gold_before := state.gold
	_talk(town, "collector_0")
	_skip_to_choices()
	_check(_scene_choice_labels().size() == 3, "the collectors' scene ends with pay, fight or walk away")
	_choose("Pay her debt")
	_check(state.gold == gold_before - PomidorWorld.MILA_DEBT and not town.story_person("collector_0").visible, "paying Mila's debt costs %d gold and the collectors leave" % PomidorWorld.MILA_DEBT)
	_check(ui.scene_playing() and _scene_text().contains("paid"), "Mila thanks the player after the payment")
	_end_scene()
	_check(town.story_stage() == "meeting", "paying the debt lets the Council meet")

	# The collectors again, this time fought: a downed player gets another try.
	state.defeated_persistent_enemies.erase(PomidorWorld.LOAN_FLAG)
	town._sync_story_people()
	_check(town.story_stage() == "wait" and town.story_person("collector_1").visible, "the collectors are back for the fight test")
	_talk(town, "mila")
	_skip_to_choices()
	_choose("Tell them to leave her alone")
	_check(town.collectors().size() == 2 and not town.story_person("collector_0").visible, "telling the collectors to leave turns them into two enemies")
	_check(town.collectors()[0].enemy_id == "collector" and town.collectors()[0].persistent_id.begins_with("story_"), "the collectors fight as Debt Collectors")
	town.player.respawned.emit()
	_check(town.collectors().is_empty() and town.story_person("collector_0").visible and town.story_stage() == "wait", "a downed player finds the collectors back at their posts")
	_talk(town, "mila")
	_skip_to_choices()
	_choose("Tell them to leave her alone")
	var villagers_safe := true
	for collector in town.collectors():
		villagers_safe = villagers_safe and collector._nearest_target() is Player
	_check(villagers_safe, "the collectors go for the player, not the townsfolk")
	for collector in town.collectors().duplicate():
		collector.take_damage(999)
	await get_tree().process_frame
	_check(town.collectors().is_empty() and ui.scene_playing() and _scene_text().contains("down"), "with both collectors down, Mila speaks")
	_check(_scene_has_line("Julius"), "Mila names Julius's people")
	_end_scene()
	_check(town.story_stage() == "meeting" and ui.job_label.text.contains("chamber"), "the bell rings and the objective points to the chamber")

	# The meeting, watched in the chamber.
	_check(_interact_service(town, "pomidor_council_hall") or town.in_council_chamber(), "the player enters the chamber")
	_check(ui.scene_playing() and town.in_council_chamber(), "entering the chamber starts the Council meeting")
	_check(ui.scene_speaker_label.text.contains("Rosa Pelat"), "Councillor Rosa Pelat opens the meeting")
	_check(town.council_person("member_pomidor_0").get_node_or_null("SpeakerMark") != null, "the speaker has a marker over their head")
	ui.advance_scene()
	_check(ui.scene_speaker_label.text.contains("Secretary of Law") and town.council_person("secretary_law").get_node_or_null("SpeakerMark") != null, "the marker moves to the Secretary of Law")
	_check(_scene_text().contains("Julius"), "the Secretary of Law names Julius's organisation")
	var said := ""
	while ui.scene_lines_left() > 0:
		said += _scene_text() + "\n"
		ui.advance_scene()
	said += _scene_text()
	_check(said.contains("draft fails") and said.contains("embassy passes"), "the draft fails and the embassy passes")
	_check(said.contains("Engineeria") and ui.scene_speaker_label.text.contains("Iva Most") and _scene_text().contains("guard my diplomats"), "Iva Most asks the player to guard his diplomats")
	var meeting_choices := _scene_choice_labels()
	_check(meeting_choices == ["Accept", "Not yet"], "the request ends with Accept or Not yet")
	_choose("Not yet")
	_check(town.story_stage() == "request" and not ui.scene_playing(), "Not yet leaves the request open")
	town.leave_council_chamber()
	_check(not ui.scene_playing(), "leaving and entering later does not replay the meeting")
	ui.open_service(PomidorWorld.COUNCIL_SERVICE_PREFIX + "secretary_diplomacy", "Iva Most")
	var agree := _find_button(ui.modal_content, "Agree to guard the diplomats")
	_check(agree != null, "Iva Most asks again at his desk")
	if agree != null:
		agree.pressed.emit()
	_check(town.story_stage() == "embassy", "the player agrees to guard the diplomats")
	_end_scene()
	for key in PomidorWorld.ENVOYS:
		_check(town.story_person(key).visible, "%s waits at the landing ground" % PomidorWorld.STORY_PEOPLE[key])
	_talk(town, "envoy_1")
	_check(ui.scene_playing() and _scene_text().contains("Iskra"), "Nada Grof has been to Iskra")
	_end_scene()
	ui.open_service("pomidor_ship", "Confederation Transport")
	_check(_find_button(ui.modal_content, "Fly to Chvarak with the diplomats") != null, "the transport offers the flight to Chvarak")
	ui.close_modal()
	return true

# ---- Chvarak and the ambush ----

func _chvarak() -> bool:
	ui.open_service("pomidor_ship", "Confederation Transport")
	var fly := _find_button(ui.modal_content, "Fly to Chvarak with the diplomats")
	var gold_before := state.gold
	if fly != null:
		fly.pressed.emit()
	await get_tree().process_frame
	var port := game.world as ChvarakWorld
	_check(port != null and state.current_planet == "chvarak" and state.gold == gold_before, "the transport flies to Chvarak for free")
	if port == null:
		return false
	var loader := port.tiled_loader
	_check(port.player.global_position.distance_to(state.CHVARAK_ARRIVAL) <= 24.0 and loader.is_walkable_position(port.player.global_position), "the player lands on walkable ground by the transport")
	_check(ui.location_label.text == "CHVARAK" and ui.job_label.text.contains("diplomatic ship"), "the title names Chvarak and the objective names the ship")
	_check(port.player.respawn_location_name == "Chvarak", "respawn belongs to Chvarak")

	# A farming planet: pastures with cows and pigs, farmers, a ramp down from the shelf.
	var animals := port.farm_animals()
	var cows := animals.filter(func(a: FarmAnimal) -> bool: return a.animal_id.begins_with("cow"))
	var pigs := animals.filter(func(a: FarmAnimal) -> bool: return a.animal_id.begins_with("pig"))
	_check(cows.size() >= 6 and pigs.size() >= 3, "the pastures hold cows and pigs (%d, %d)" % [cows.size(), pigs.size()])
	_check(animals.all(func(a: FarmAnimal) -> bool: return a.pasture.has_point(a.global_position) and not a.is_in_group("damageable")), "every animal stands inside its pasture and cannot be attacked")
	var farmers := 0
	for actor in port.actors_root.get_children():
		if actor is Villager and actor.routine_role.begins_with("chvarak_"):
			farmers += 1
	_check(farmers >= 10, "farmers and herders work the valley (%d)" % farmers)
	var valley := Vector2(32 * 16, 30 * 16)
	var down := loader.get_walk_path(port.player.global_position, valley)
	_check(not down.is_empty() and down[-1].distance_to(valley) < 20.0, "a road leads from the pad down the ramp to the valley")
	_check(not loader.is_walkable_position(Vector2(12 * 16, 18 * 16 + 8)) and not loader.is_walkable_position(Vector2(20 * 16, 4 * 16)), "the shelf's cliff and the mountains block the way")
	var pasture := Vector2(44 * 16, 24 * 16)
	var into_pasture := loader.get_walk_path(port.player.global_position, pasture)
	_check(into_pasture.is_empty() or into_pasture[-1].distance_to(pasture) > 20.0, "the fences keep the player out of the pastures")
	var to_ship := loader.get_walk_path(port.player.global_position, ChvarakWorld.BOARD_POSITION)
	_check(not to_ship.is_empty() and to_ship[-1].distance_to(ChvarakWorld.BOARD_POSITION) < 20.0, "the player can walk to the diplomatic ship's ramp")
	var into_ship := loader.get_walk_path(port.player.global_position, ChvarakWorld.SHIP_ENTRY)
	_check(into_ship.is_empty() or into_ship[-1].distance_to(ChvarakWorld.SHIP_ENTRY) > 20.0, "the ship's room cannot be walked into")
	for key in ChvarakWorld.ENVOYS:
		_check(port.story_person(key).visible and port.story_person(key).is_in_group("interactable"), "%s came along to Chvarak" % ChvarakWorld.STORY_PEOPLE[key])
	_talk(port, "guard")
	_check(ui.scene_playing() and _scene_text().contains("cows"), "the port guard talks about the cows")
	_end_scene()
	_check(_interact_service(port, "chvarak_terminal") and ui.scene_playing(), "the terminal clerk talks")
	_end_scene()
	ui.open_service("chvarak_ship", "Confederation Transport")
	_check(_find_button(ui.modal_content, "Fly to Pomidor") != null, "the transport flies back to Pomidor")
	ui.close_modal()

	# Boarding.
	_check(_interact_service(port, "diplomatic_ship") and ui.scene_playing(), "E at the diplomatic ship asks to board")
	_skip_to_choices()
	_check(_scene_choice_labels() == ["Board the ship", "Not yet"], "boarding offers Board and Not yet")
	_choose("Not yet")
	_check(not port.flying() and not port.on_ship(), "Not yet keeps the player on the pad")
	_interact_service(port, "diplomatic_ship")
	_skip_to_choices()
	_choose("Board the ship")
	_check(port.flying() and port.on_ship() and ui.location_label.text == "DIPLOMATIC SHIP", "the player boards and the title names the ship")
	_check(loader.is_walkable_position(port.player.global_position), "the player stands on the ship's floor")
	_check(port.ship_guards().size() == 2, "two ship guards are on board")
	for key in ChvarakWorld.ENVOYS:
		var envoy := port.story_person(key)
		_check(port.on_ship(envoy.global_position) and not envoy.is_in_group("interactable") and not envoy.is_in_group("party_target"), "%s sits in the cabin and cannot be targeted" % ChvarakWorld.STORY_PEOPLE[key])
	_check(ui.scene_playing() and port.flight_time() < 0.0, "the take-off lines play before the flight clock starts")
	_end_scene()
	_check(port.flight_time() == 0.0, "the flight clock starts after the take-off lines")

	# A save in flight keeps the player on the pad.
	port.capture_player_position()
	state.remember_player_position(state.player_position)
	_check(state.save_game(), "saving in flight succeeds")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	var saved_position := Vector2(float(saved["player_position"][0]), float(saved["player_position"][1])) if saved is Dictionary else Vector2.INF
	_check(saved is Dictionary and saved["current_planet"] == "chvarak" and saved_position.distance_to(ChvarakWorld.BOARD_POSITION) < 1.0 and state._valid_save(saved), "the save in flight records the pad, not the ship")
	port.player.global_position = ChvarakWorld.SHIP_ENTRY

	port.advance_flight(ChvarakWorld.ALARM_SECONDS + 0.5)
	_check(port.ambushers().size() == 2 and ui.job_label.text.contains("hatch"), "the alarm sounds and two hackers come through the hatch")
	_check(port.ambushers().all(func(e: Enemy) -> bool: return e.persistent_id.begins_with("story_ambush_") and port.on_ship(e.global_position)), "the hackers board inside the ship")
	_check(port.ambushers().all(func(e: Enemy) -> bool: return int(e.definition["damage"]) == ChvarakWorld.AMBUSH_DAMAGE[e.enemy_id] and int(GameData.enemy(e.enemy_id)["damage"]) > int(e.definition["damage"])), "the boarding hackers hit softer than Paprika's hacker")
	port.advance_flight(14.0)
	_check(port.ambushers().size() >= 3 and port.ambushers().any(func(e: Enemy) -> bool: return e.enemy_id == "phase_hacker"), "the second group brings a phase hacker")

	# Loading the save ends the flight back on the pad.
	_check(state.load_game(), "the save made in flight loads")
	port.apply_loaded_state()
	await get_tree().process_frame
	_check(not port.flying() and not port.on_ship() and port.player.global_position.distance_to(ChvarakWorld.BOARD_POSITION) < 24.0, "loading puts the player back on the pad")
	_check(port.ambushers().is_empty() and port.ship_guards().is_empty(), "loading clears the hackers and the ship guards")
	_check(not state.defeated_persistent_enemies.has(PomidorWorld.DEPARTED_FLAG), "the embassy has not left yet after the load")

	# Board again and sit out the whole flight: the ship goes down after FLIGHT_SECONDS.
	_interact_service(port, "diplomatic_ship")
	_skip_to_choices()
	_choose("Board the ship")
	_end_scene()
	port.advance_flight(ChvarakWorld.FLIGHT_SECONDS + 0.5)
	_check(state.defeated_persistent_enemies.has(state.CRASH_FLAG) and ui.scene_playing() and _scene_has_line("falling"), "the ship goes down after %d seconds of flight" % int(ChvarakWorld.FLIGHT_SECONDS))
	_end_scene()
	for frame in 3:
		await get_tree().process_frame
	_check(game.world is EngineeriaWorld and state.current_planet == "engineeria", "the crash moves the story to Engineeria")

	# Quick load goes back to the save on the pad.
	_quick_load()
	await get_tree().process_frame
	port = game.world as ChvarakWorld
	_check(port != null and state.current_planet == "chvarak" and not state.defeated_persistent_enemies.has(state.CRASH_FLAG) and not port.flying(), "quick load returns to the pad before the crash")
	if port == null:
		return false

	# Board again; being downed in the fight brings the ship down.
	_interact_service(port, "diplomatic_ship")
	_skip_to_choices()
	_choose("Board the ship")
	_end_scene()
	port.advance_flight(ChvarakWorld.ALARM_SECONDS + 0.5)
	port.player._invulnerability = 0.0
	port.player.take_damage(9999, port.player.global_position)
	_check(state.defeated_persistent_enemies.has(PomidorWorld.DEPARTED_FLAG) and state.defeated_persistent_enemies.has(state.CRASH_FLAG), "being downed in the fight brings the ship down")
	_check(port.ambushers().is_empty() and ui.scene_playing() and _scene_has_line("falling"), "the crash clears the fight and plays the fall")
	_end_scene()
	return true

# ---- Engineeria ----

func _engineeria() -> bool:
	for frame in 3:
		await get_tree().process_frame
	var forest := game.world as EngineeriaWorld
	_check(forest != null and state.current_planet == "engineeria", "the player wakes up on Engineeria")
	if forest == null:
		return false
	var loader := forest.tiled_loader
	var player := forest.player
	_check(ui.location_label.text == "UNKNOWN FOREST" and player.respawn_location_name == "the crash site", "the title is UNKNOWN FOREST and being downed wakes the player by the wreck")
	_check(player.global_position.distance_to(state.ENGINEERIA_ARRIVAL) < 4.0 and loader.is_walkable_position(player.global_position), "the player wakes on open ground by the wreck")
	_check(loader.map_objects("wreck").size() == 1 and loader.map_objects("envoy_lying_0").size() == 1 and loader.map_objects("envoy_lying_1").size() == 1 and loader.map_objects("envoy_lying_2").size() == 1, "the wreck and the three envoys lie at the crash site")
	_check(ui.scene_playing() and _scene_has_line("None of the three is breathing") and _scene_has_line("letters") and forest.beasts().is_empty(), "the crash scene plays before any beast comes")

	# The map: a path to the smoke, and a ledge, a stream and thickets that block.
	var to_smoke := loader.get_walk_path(player.global_position, EngineeriaWorld.SMOKE_POINT)
	_check(not to_smoke.is_empty() and to_smoke[-1].distance_to(EngineeriaWorld.SMOKE_POINT) < 20.0, "the forest can be crossed on foot from the wreck to Davor's gate")
	_check(not loader.is_walkable_position(Vector2(50 * 16 + 8, 36 * 16 + 8)) and loader.is_walkable_position(Vector2(67 * 16 + 8, 36 * 16 + 8)), "the ledge blocks the way except at its ramp")
	_check(not loader.is_walkable_position(Vector2(40 * 16 + 8, 10 * 16 + 8)) and not loader.is_walkable_position(Vector2(8, 300)), "the stream and the thickets round the map block the way")
	_check(not loader.is_walkable_position(Vector2(76 * 16 + 8, 5 * 16 + 8)), "Davor's fence blocks the way")

	_end_scene()
	_check(int(state.inventory.get("embassy_letters", 0)) == 1 and state.defeated_persistent_enemies.has(EngineeriaWorld.LETTERS_FLAG), "the player takes Iva Most's letters")
	_check(not state.sell_item("embassy_letters") and int(state.inventory.get("embassy_letters", 0)) == 1, "the letters cannot be sold")
	_check(forest.chasing() and forest.beasts().size() == EngineeriaWorld.FIRST_GROUP and ui.job_label.text.contains("Run to the smoke"), "three beasts come out and the objective is to run to the smoke")
	var beasts := forest.beasts()
	_check(beasts.all(func(b: Enemy) -> bool: return b.relentless and b.persistent_id.begins_with("story_beast_") and b.enemy_id == "forest_beast" and loader.is_walkable_position(b.global_position)), "the beasts are relentless forest beasts on open ground")
	_check(beasts.all(func(b: Enemy) -> bool: return b.global_position.distance_to(player.global_position) > 120.0), "the beasts come out of the trees away from the player")
	_check(int(GameData.enemy("forest_beast")["level"]) == 6 and float(GameData.enemy("forest_beast")["speed"]) < Player.SPEED, "a forest beast is level 6 and slower than the player")

	# The beasts keep chasing far from where they came out.
	var beast := beasts[0]
	var start := beast.global_position
	player.global_position = _open_point_near(loader, Vector2(30 * 16, 50 * 16))
	var gap := beast.global_position.distance_to(player.global_position)
	for frame in 90:
		player._invulnerability = 1.0
		await get_tree().physics_frame
	_check(is_instance_valid(beast) and beast.state == Enemy.State.CHASE and beast.global_position.distance_to(player.global_position) < gap - 40.0, "a beast keeps chasing the player across the forest")
	_check(is_instance_valid(beast) and beast.global_position.distance_to(start) > 60.0, "the beast is not held to where it came out")

	# A second group follows, and more come at the sides while the player stands still.
	# The real frames above may already have brought one beast at the side.
	forest.advance_chase(EngineeriaWorld.SECOND_GROUP_SECONDS)
	_check(forest._second_group_sent and forest.beasts().size() >= EngineeriaWorld.FIRST_GROUP + EngineeriaWorld.SECOND_GROUP, "a second group of beasts comes after %d seconds" % int(EngineeriaWorld.SECOND_GROUP_SECONDS))
	var before := forest.beasts().size()
	forest.advance_chase(EngineeriaWorld.STALL_SECONDS + 0.5)
	_check(forest.beasts().size() == before + 1, "a beast comes out at the side when the player stops")
	forest.advance_chase(EngineeriaWorld.STALL_SECONDS * 4.0)
	_check(forest.beasts().size() == EngineeriaWorld.MAX_BEASTS, "no more than %d beasts chase at once" % EngineeriaWorld.MAX_BEASTS)

	# Being downed starts the chase again by the wreck.
	player._invulnerability = 0.0
	player.take_damage(9999, player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.global_position.distance_to(state.ENGINEERIA_ARRIVAL) < 4.0 and forest.chasing() and forest.beasts().size() == EngineeriaWorld.FIRST_GROUP, "being downed wakes the player by the wreck and the chase starts again")
	_check(int(state.inventory.get("embassy_letters", 0)) == 1 and not ui.scene_playing(), "the player keeps the letters and the crash scene does not repeat")

	# A save during the chase loads by the wreck with the chase starting again.
	player.global_position = _open_point_near(loader, Vector2(30 * 16, 50 * 16))
	forest.capture_player_position()
	state.remember_player_position(state.player_position)
	_check(state.save_game(), "saving during the chase succeeds")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	var saved_position := Vector2(float(saved["player_position"][0]), float(saved["player_position"][1])) if saved is Dictionary else Vector2.INF
	_check(saved is Dictionary and saved["current_planet"] == "engineeria" and saved_position.distance_to(state.ENGINEERIA_ARRIVAL) < 1.0 and state._valid_save(saved), "the save during the chase records the wreck")
	forest.advance_chase(EngineeriaWorld.SECOND_GROUP_SECONDS)
	_quick_load()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game.world == forest and forest.chasing() and forest.beasts().size() == EngineeriaWorld.FIRST_GROUP and player.global_position.distance_to(state.ENGINEERIA_ARRIVAL) < 4.0, "loading starts the chase again by the wreck")

	# Reaching the clearing brings Davor out of the house.
	var davor := _reach_clearing(forest)
	_check(davor != null and forest.rescuing() and not forest.chasing(), "entering the clearing brings the old man out of the house")
	if davor == null:
		return false
	_check(forest.beasts().size() == 2 and ui.job_label.text.contains("old man"), "beasts far behind go back into the forest and the objective names the old man")
	_check(davor.max_health == EngineeriaWorld.DAVOR_HEALTH and davor.armor == 0 and davor.speed == EngineeriaWorld.DAVOR_SPEED and davor.can_leap, "Davor has 260 health, no armor, speed 100 and can leap")
	_check((davor.get_node("NameLabel") as Label).text == "Old Man  Lv.8", "he is an old man of level 8 until he gives his name")

	# Being downed now wakes the player at his door, not back at the wreck.
	player._invulnerability = 0.0
	player.take_damage(9999, player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.global_position.distance_to(EngineeriaWorld.HOUSE_FRONT) < 4.0 and forest.beasts().is_empty() and not forest.chasing() and forest.davor() == davor, "being downed after the old man comes out wakes the player at his door with the beasts dead")
	for frame in 30:
		await get_tree().physics_frame
		if ui.scene_playing():
			break
	_check(ui.scene_playing() and _scene_has_line("Davor. This is my house"), "the old man then introduces himself")

	# Loading the save from the chase drops the introduction and starts the chase again.
	_quick_load()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not ui.scene_playing() and forest.chasing() and forest.davor() == null and not state.defeated_persistent_enemies.has(EngineeriaWorld.DAVOR_FLAG) and player.global_position.distance_to(state.ENGINEERIA_ARRIVAL) < 4.0, "loading during the introduction starts the chase again by the wreck")
	_check(player.respawn_location_name == "the crash site", "being downed wakes the player by the wreck again")

	davor = _reach_clearing(forest)
	if davor == null:
		_check(false, "the old man comes out a second time")
		return false
	var gold_before := state.gold
	var drawn := false
	for frame in 900:
		player._invulnerability = 1.0
		await get_tree().physics_frame
		drawn = drawn or forest.beasts().any(func(b: Enemy) -> bool: return b.focus_target == davor)
		if forest.beasts().is_empty():
			break
	_check(drawn, "the beasts near Davor turn on him")
	_check(forest.beasts().is_empty() and not davor.down, "Davor kills the beasts")
	_check(state.gold > gold_before, "the beasts he kills still pay their gold")
	for frame in 400:
		await get_tree().physics_frame
		if ui.scene_playing():
			break
	_check(ui.scene_playing() and _scene_has_line("Engineeria") and _scene_has_line("Iskra") and _scene_has_line("doesn't ask"), "Davor introduces himself, names Engineeria and Iskra, and asks nothing about the letters")
	_check(String(ui._scene_lines[1]["speaker"]) == "Old Man" and String(ui._scene_lines[2]["speaker"]) == "Davor", "he is the old man until he gives his name")
	_end_scene()
	_check(state.defeated_persistent_enemies.has(EngineeriaWorld.DAVOR_FLAG) and davor.order == "follow" and davor.is_in_group("party_target"), "Davor joins and follows the player")
	_check(ui.location_label.text == "ENGINEERIA" and ui.job_label.text.contains("Travel to Iskra with Davor"), "the title names Engineeria and the objective is the road to Iskra")
	_check((davor.get_node("NameLabel") as Label).text == "Davor  Lv.8" and player.respawn_location_name == "Davor's house", "his label gives his name and being downed now wakes the player at his house")

	# Davor leaps the ledge rather than walk round by the ramp.
	var above := _open_point_near(loader, Vector2(50 * 16 + 8, 32 * 16 + 8))
	var below := _open_point_near(loader, Vector2(50 * 16 + 8, 39 * 16 + 8))
	var walk_round := loader.get_walk_path(below, above)
	var walk_length := 0.0
	for index in range(1, walk_round.size()):
		walk_length += walk_round[index - 1].distance_to(walk_round[index])
	_check(walk_length > below.distance_to(above) * 3.0, "walking round the ledge is far longer than the straight line")
	player.global_position = above
	davor.global_position = below
	var leapt := false
	for frame in 240:
		player._invulnerability = 1.0
		await get_tree().physics_frame
		leapt = leapt or davor.leaping()
		if leapt and not davor.leaping() and davor.global_position.y < 35 * 16:
			break
	_check(leapt and not davor.leaping() and davor.global_position.y < 35 * 16 and loader.is_walkable_position(davor.global_position), "Davor leaps up the ledge and lands on open ground")

	# Downed, he gets up again.
	davor.take_damage(9999)
	_check(davor.down and not davor.is_in_group("party_target"), "Davor can be downed")
	for step in 11:
		davor._physics_process(1.0)
	_check(not davor.down and davor.health == davor.max_health and davor.is_in_group("party_target"), "Davor gets up again after ten seconds")

	# Save and load after he joins.
	player.global_position = _open_point_near(loader, Vector2(60 * 16, 30 * 16))
	forest.capture_player_position()
	state.remember_player_position(state.player_position)
	_check(state.save_game(), "saving with Davor succeeds")
	_quick_load()
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded_davor := forest.davor()
	_check(loaded_davor != null and loaded_davor.order == "follow" and loaded_davor.global_position.distance_to(player.global_position) < 48.0, "loading keeps Davor at the player's side")
	_check(player.global_position.distance_to(Vector2(60 * 16, 30 * 16)) < 24.0 and not forest.chasing() and forest.beasts().is_empty(), "loading keeps the player where they saved and the chase stays over")
	return true

# ---- helpers ----

func _talk(world: Node, key: String) -> void:
	ui.close_modal()
	var someone: Node2D = world.story_person(key)
	world.player.global_position = _open_point_near(world.tiled_loader, someone.global_position + Vector2(0, 14))
	world.player._update_nearest_interactable()
	if world.player._current_interactable != someone:
		world.talk_to(key)
		return
	_interact(world.player)

func _scene_text() -> String:
	return ui.scene_text_label.text

func _scene_has_line(text: String) -> bool:
	return ui._scene_lines.any(func(line: Dictionary) -> bool: return String(line.get("text", "")).contains(text))

func _skip_to_choices() -> void:
	while ui.scene_playing() and ui.scene_lines_left() > 0:
		ui.advance_scene()

func _end_scene() -> void:
	var guard := 0
	while ui.scene_playing() and guard < 60:
		guard += 1
		if ui.scene_lines_left() == 0 and not ui._scene_choices.is_empty():
			var last := ui.scene_buttons.get_child(ui.scene_buttons.get_child_count() - 1) as Button
			last.pressed.emit()
		else:
			ui.advance_scene()

func _scene_choice_labels() -> Array:
	var labels := []
	for child in ui.scene_buttons.get_children():
		if child is Button and not child.is_queued_for_deletion():
			labels.append(child.text)
	return labels

func _choose(label: String) -> void:
	for child in ui.scene_buttons.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.text.begins_with(label):
			child.pressed.emit()
			return
	_check(false, "the scene offers %s" % label)

func _open_point_near(loader: TiledLoader, point: Vector2) -> Vector2:
	for offset in [Vector2(0, 10), Vector2(0, -10), Vector2(12, 0), Vector2(-12, 0), Vector2(0, 18), Vector2(18, 0), Vector2(-18, 0), Vector2(0, -18)]:
		if loader.is_walkable_position(point + offset):
			return point + offset
	return point

## Puts the player in Davor's clearing with two beasts close behind and steps
## the chase once, which brings Davor out.
func _reach_clearing(forest: EngineeriaWorld) -> RaidSoldier:
	var loader := forest.tiled_loader
	forest.player.global_position = _open_point_near(loader, EngineeriaWorld.SMOKE_POINT + Vector2(0, 40))
	var close := forest.beasts()
	close[0].global_position = _open_point_near(loader, forest.player.global_position + Vector2(-60, 50))
	close[1].global_position = _open_point_near(loader, forest.player.global_position + Vector2(60, 50))
	forest.advance_chase(0.25)
	return forest.davor()

func _quick_load() -> void:
	var event := InputEventAction.new()
	event.action = "quick_load"
	event.pressed = true
	game._unhandled_input(event)

func _interact(player: Player) -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)

func _service(world: Node, id: String) -> WorldService:
	for fixture in world.tiled_loader._object_root.get_children():
		if fixture is WorldService and fixture.service_id == id:
			return fixture
	return null

func _interact_service(world: Node, id: String) -> bool:
	ui.close_modal()
	var fixture := _service(world, id)
	if fixture == null:
		return false
	world.player.global_position = _open_point_near(world.tiled_loader, fixture.get_interaction_position())
	world.player._update_nearest_interactable()
	if world.player._current_interactable != fixture:
		return false
	_interact(world.player)
	return true

func _find_button(node: Node, label: String) -> Button:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button and child.text.contains(label):
			return child
		var nested := _find_button(child, label)
		if nested != null:
			return nested
	return null

func _has_text(node: Node, text: String) -> bool:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label and child.text.contains(text):
			return true
		if _has_text(child, text):
			return true
	return false

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		printerr("FAIL ", description)

func _finish() -> void:
	print("Embassy: %d checks, %d failures" % [checks, failures])
	if game != null:
		remove_child(game)
		game.free()
	get_tree().quit(0 if failures == 0 else 1)
