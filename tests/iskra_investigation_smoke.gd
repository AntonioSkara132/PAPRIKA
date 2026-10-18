extends Node

var game: Node
var world: Node2D
var story: RefCounted
var ui: GameUI
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		_check(false, "isolated saves required")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	game._on_story_travel_requested("iskra")
	await get_tree().process_frame
	world = game.world
	if world.get("investigation") == null:
		_check(false, "investigation controller loaded")
		_finish()
		return
	story = world.investigation
	for outcome in ["captured", "killed", "escaped"]:
		await _reset()
		await _hotel_attack(outcome)
		_check(story.has("assassin_" + outcome), "attacker outcome recorded: " + outcome)
		world.player.global_position = story.people.inv_hall_evidence.global_position
		_check(story.examine_uniform(), "uniform recoverable after " + outcome)
		ui.cancel_scene()
		_check(not story.has("uniform_found"), "cancelled coat examination grants no evidence")
		story.examine_uniform()
		_end()
		_check(story.has("uniform_found"), "completed coat examination records tag")
		_save("attacker " + outcome)
	for route in ["squirrel", "direct", "pelican"]:
		await _reset()
		await _hotel_attack("killed")
		world.player.global_position = story.people.inv_hall_evidence.global_position
		story.examine_uniform()
		_end()
		await _reach_boss()
		_check(not story.ready_for_deduction(), "boss's initial account does not give away Mara")
		_check(not story.has("mara_confessed") and not story.has("timing_clue"), "watchers and return time are withheld at offer")
		_at("inv_hall_neighbor")
		_check(not story.enter_site("neighbor"), "neighboring room inaccessible before deduction")
		_end()
		if route == "squirrel":
			_at("inv_squirrel_boss")
			_check(story.accept_deal(), "Squirrel bargain can be accepted")
			_end()
			_check(not story.hostile("pelican"), "accepting deal alone does not start hostilities")
			_at("inv_rendezvous")
			var previous_armor: String = str(GameState.equipment.get("armor", ""))
			_check(story.issue_equipment(), "tvrdium issued at rendezvous")
			_check(GameState.inventory.get("banishing_arrow", 0) == 1, "one Banishing Arrow comes with the armor")
			_end()
			_check(GameState.inventory.get("tvrdium_armor", 0) == 1 and str(GameState.equipment.get("armor", "")) == previous_armor, "issued armor is real inventory without forced equip")
			_save("rendezvous reward")
			_check(not story.issue_equipment() and GameState.inventory.get("tvrdium_armor", 0) == 1, "rendezvous reward cannot repeat after load")
			world.gang_jobs.set_flag("shipment_pelican")
			world.gang_jobs.set_flag("shipment_delivered")
		elif route == "pelican":
			_at("inv_squirrel_boss")
			story.accept_deal()
			_end()
			_at("inv_rendezvous")
			story.issue_equipment()
			_end()
			_at("inv_pelican_entry")
			_check(story.enter_site("pelican"), "player can visit Pelican boss instead of assault")
			_at("inv_pelican_boss")
			_check(story.warn_pelicans(), "warning opens supported alternative")
			_end()
			_check(not story.hostile("pelican") and not story.hostile("squirrel"), "warning is not falsely recorded as an attack")
			_check(GameState.inventory.get("tvrdium_armor", 0) == 1, "warning Pelicans does not confiscate armor")
			_at("inv_rendezvous")
			_check(not story.issue_equipment(), "betrayal cannot obtain another set of armor")
		else:
			world.gang_jobs.set_flag("rescue_job")
			world.gang_jobs.set_flag("rescue_extracted")
			_at("inv_squirrel_boss")
		if route != "direct":
			_at("inv_rendezvous")
		_check(story.start_assault(route), "start real " + route + " encounter")
		_check(story.room() == ("pelican" if route == "squirrel" else "squirrel"), "assault enters correct physical office")
		_check(story.encounters.enemies.size() >= 4, "assault has physical hostile actors")
		if route != "direct":
			_check(story.encounters.allies.size() == 3, "supported route has three actual allies")
		if route == "pelican":
			_check(story.has("betrayed_after_equipment"), "Squirrels recognize equipment betrayal on confrontation")
		await _capture("assault_" + route)
		_save("active " + route + " fight")
		world.davor.set_physics_process(false)
		# Two passes: Roko only becomes vulnerable once his guards are down.
		for pass_index in 2:
			for actor_id in story.encounters.enemies.keys():
				if actor_id != "squirrel_boss":
					var actor: Variant = story.encounters.enemies.get(actor_id)
					if is_instance_valid(actor):
						actor.take_damage(9999, world.player.global_position)
			await get_tree().process_frame
			story.encounters.step(0.01)
		_check(story.has("contract_access"), "combat completion grants access, not automatic testimony: " + route)
		_check(not story.has("timing_clue"), "fight alone does not grant unread contract clue")
		if route == "squirrel":
			_check(story.has("hacker_killed") and story.hostile("pelican"), "hacker death and Pelican hostility recorded")
			_at("red_pelican")
			world.gang_jobs._recruiter("pelican")
			_check(_has_choice("Settle earned shipment payment") and not _has_choice("Accept shipment"), "hostile recruiter permits earned debt, no new work")
			_choose("Settle earned shipment payment")
			_end()
			_check(GameState.gold == 180 and not world.gang_jobs.claim_shipment(), "earned shipment debt paid once after hostility")
			_at("inv_squirrel_entry")
			_check(story.enter_site("squirrel"), "return for promised information")
		elif route == "direct":
			_at("green_squirrel")
			world.gang_jobs._recruiter("squirrel")
			_check(_has_choice("Settle earned rescue payment") and not _has_choice("Ask about our captured"), "hostile Squirrels retain earned rescue debt")
			_choose("Settle earned rescue payment")
			_end()
			_check(GameState.gold == 220 and not world.gang_jobs.claim_rescue(), "earned rescue debt paid once")
			_at("inv_squirrel_entry")
			story.enter_site("squirrel")
		else:
			var boss: Variant = story.encounters.enemies.get("squirrel_boss")
			if is_instance_valid(boss):
				world.player.global_position = boss.global_position + Vector2(0, 12)
			_check(story.encounters.finish_surrendered_boss(), "boss can die without losing records route")
			await get_tree().process_frame
		if route == "pelican":
			_at("inv_squirrel_record")
			_check(story.read_contract(), "dead boss leaves accessible contract record")
		else:
			_at("inv_squirrel_handler")
			_check(story.question_contract(), "contract participant provides account")
		ui.cancel_scene()
		_check(not story.has("timing_clue"), "cancelled account does not grant return-time clue")
		if route == "pelican":
			story.read_contract()
		else:
			story.question_contract()
		_end()
		_check(story.ready_for_deduction(), "all approaches supply facts needed for deduction")
		_save("contract evidence " + route)
		if route == "direct":
			_at("tower")
			_check(story.question_secretary(), "Secretary interview remains available")
			_end()
			_check(story.check_secretary(), "Secretary's account is checkable")
			ui.cancel_scene()
			_check(not story.has("secretary_checked"), "cancelled document check grants no conclusion")
			story.check_secretary()
			_end()
			_check(story.has("secretary_checked"), "completed document check recorded")
		else:
			_check(not story.has("secretary_questioned"), "Secretary interview is optional")
		await _deduce_and_finish(route)
		_check(world.davor.max_health == 260 and world.davor.strike_damage == 30 and world.davor.can_leap, "Davor strength retained through " + route)
	await _closed_contracts()
	await _change_approach()
	_finish()

func _reset() -> void:
	ui.cancel_scene()
	ui.close_modal()
	story.encounters.clear_runtime()
	for flag: String in GameState.defeated_persistent_enemies.duplicate():
		if flag.begins_with("iskra_investigation_") or flag.begins_with("story_iskra_inv_") or flag.begins_with("iskra_gang_"):
			GameState.defeated_persistent_enemies.erase(flag)
	GameState.iskra_investigation_state.clear()
	GameState.iskra_gang_state.clear()
	GameState.inventory.erase("tvrdium_armor")
	GameState.add_item("iron_sword")
	GameState.equipment.weapon = "iron_sword"
	GameState.gold = 100
	GameState.restore_health()
	for flag in ["arrival", "registered", "tower_closed_seen", "morning", "room_rented", "audience_complete", "hotel_cover_confirmed"]:
		world.chapter.set_flag(flag)
	world.player.global_position = world.marker("hotel")
	GameState.remember_player_position(world.player.global_position)
	world.apply_loaded_state()
	world.davor.set_physics_process(false)
	await get_tree().process_frame

func _hotel_attack(outcome: String) -> void:
	_at("hotel")
	world.chapter._hotel()
	_check(not _has_choice("Go to room 12") and _has_choice("Arrange supper"), "desk has no direct room jump and keeps the evening arrangement")
	_choose("Arrange supper")
	ui.cancel_scene()
	_check(not story.has("evening_arranged"), "cancelling evening arrangement records nothing")
	_check(story.arrange_evening(), "evening can be arranged")
	_end()
	world.gang_jobs.set_flag("shipment_carried_a")
	_check(not story.start_evening(), "carried cargo prevents evening transition")
	world.gang_jobs.clear_flag("shipment_carried_a")
	_check(story.start_evening(), "player deliberately starts evening")
	_end()
	_check(story.room() == "hall" and str(story.get_value("assassin_phase")) == "waiting", "evening leads to physical hotel corridor and summons")
	_check(not story.status().contains("false") and not story.status().contains("attacker"), "pending summons objective does not reveal the officer's intent")
	_save("waiting summons")
	story._summons()
	await _capture("hotel_summons")
	_choose("Ask to see the written order")
	_end()
	world.davor.set_physics_process(false)
	var attacker: Variant = story.encounters.enemies.get("assassin")
	_check(is_instance_valid(attacker), "false officer becomes actual attacker")
	if not is_instance_valid(attacker):
		return
	if outcome == "captured":
		attacker.take_damage(56, world.player.global_position)
		world.player.global_position = attacker.global_position + Vector2(0, 8)
		_check(story.encounters.capture_assassin(), "wounded surrendered attacker can be captured")
	elif outcome == "killed":
		attacker.take_damage(9999, world.player.global_position)
	else:
		world.player.global_position = world.marker("inv_hall_arrival")
		attacker.global_position = world.marker("inv_hall_flee_2")
		attacker.take_damage(1, world.player.global_position)
		var elapsed := 0.0
		while not story.has("assassin_escaped") and elapsed < 10.0:
			await get_tree().create_timer(0.05).timeout
			elapsed += 0.05
	await get_tree().process_frame
	story.sync()

func _reach_boss() -> void:
	_at("police")
	_check(not story.records_counter() and not story.has("uniform_identified"), "main police clerk does not give the owner")
	_at("police_records")
	_check(story.records_counter(), "eastern quartermaster opens the issue register")
	_end()
	_check(story.has("uniform_identified"), "eastern quartermaster identifies the owner")
	ui.cancel_scene()
	_end()
	_end()
	_at("inv_owner_entry")
	_check(story.enter_site("owner"), "enter uniform owner's apartment")
	await _capture("owner_apartment")
	_at("inv_owner_desk")
	_check(story.examine_owner_desk(), "payment note links uniform to Squirrel contact")
	_end()
	_save("uniform owner evidence")
	_at("green_squirrel")
	world.gang_jobs._recruiter("squirrel")
	_check(_has_choice("Ask for the boss") and _has_choice("Accept shipment"), "investigation preserves optional gang menu")
	_choose("Ask for the boss")
	_end()
	_at("inv_squirrel_entry")
	_check(story.enter_site("squirrel"), "Squirrel office accessible without gang jobs")
	_check(story.encounters.enemies.size() == 6, "six visible neutral Squirrel guards protect boss")
	_at("inv_squirrel_boss")
	story.handle("inv_squirrel_boss")
	_end()
	_check(story.has("boss_met") and story.has("accent_clue"), "boss offers bargain and foreign-accent observation")
	story.handle("inv_squirrel_boss")
	await _capture("squirrel_offer")
	await _key(KEY_E, 101)
	_check(not ui.scene_playing() and not story.has("deal_accepted") and not story.hostile("squirrel"), "E exits boss menu without accepting or attacking")

func _deduce_and_finish(route: String) -> void:
	_at("hotel")
	_check(story.open_deduction(), "typed deduction opens after evidence")
	_check(ui.text_prompt_open() and get_tree().paused, "deduction pauses game")
	_check(not story.answer_name("").accepted and not story.answer_name("Veki").accepted, "empty/unrelated answers are harmless")
	_check(not story.answer_name("Secretary").accepted and not story.has("mara_named"), "Secretary is plausible but not an automatic conviction")
	ui.close_modal()
	_check(not story.has("mara_named"), "cancelled prompt does not finish deduction")
	_check(story.open_deduction(), "deduction can be reopened")
	var names := {"squirrel": "  mArA! ", "direct": "the receptionist", "pelican": "maar"}
	await get_tree().process_frame
	var input := _find_input(ui.modal_content)
	_check(input != null, "deduction has a visible text field")
	if input != null:
		input.grab_focus()
		for character in names[route]:
			await _key(character.to_upper().unicode_at(0), character.unicode_at(0))
		_check(input.text == names[route], "actual key events enter the intended answer")
		await _capture("deduction_" + route)
		await _key(KEY_ENTER)
	_check(story.has("mara_named") and not ui.text_prompt_open() and not get_tree().paused, "accepted name closes prompt and restores gameplay")
	_check(not story.has("mara_confessed"), "naming Mara does not grant confession")
	_check(story.question_mara(), "question Mara after deduction")
	ui.cancel_scene()
	_check(not story.has("mara_confessed"), "cancelled questioning does not reveal neighboring guests")
	story.question_mara()
	_end()
	_check(story.has("mara_confessed"), "completed questioning reveals bribery and room13")
	_at("hotel")
	_check(story.enter_site("hall"), "return to guest corridor")
	_at("inv_hall_neighbor")
	_check(story.enter_site("neighbor"), "Mara's spare key opens neighboring room")
	_at("inv_neighbor_record")
	# Routes share one inventory, so compare counts rather than absolute amounts.
	var letters_before := int(GameState.inventory.get("martin_letter", 0))
	var credentials_before := int(GameState.inventory.get("board_credentials", 0))
	_check(story.search_neighbor(), "search neighboring guests' luggage")
	ui.cancel_scene()
	_check(not story.has("martin_letter") and int(GameState.inventory.get("martin_letter", 0)) == letters_before, "cancelled search does not grant the letter")
	story.search_neighbor()
	_end()
	_check(story.has("martin_letter") and int(GameState.inventory.get("martin_letter", 0)) == letters_before + 1 and story.status().contains("Martin ordered the attack"), "the luggage holds Martin's letter and the HUD names him")
	_check(not story.search_neighbor(), "the letter is found once")
	_save("letter found " + route)
	_check(story.has("martin_letter"), "the letter persists")
	await _capture("investigation_" + route)
	_check(not story.board_menu(), "the Board has not called before the night's rest")
	_at("tower")
	_check(not story.enter_site("board") and story.room() != "board", "the Board chamber stays closed before the summons")
	_check(story.rest_in_room(), "resting after the letter brings the Board's summons")
	_end()
	_check(story.has("board_summoned") and story.status().contains("Board is waiting"), "the Board summons the MC to the Tower")
	_check(not story.rest_in_room(), "the summons comes once")
	_at("tower")
	_check(not story.attend_board(), "the Board meeting does not start at the Tower door")
	_check(story.board_menu() and ui.scene_playing(), "the Tower guard offers the lift to the Board chamber")
	ui.cancel_scene()
	var gold_before := GameState.gold
	_check(story.go_to_board() and story.room() == "board" and ui.scene_playing(), "the lift takes the MC to the Board chamber and the meeting starts")
	_check(story.location_title() == "TOWER · BOARD CHAMBER", "the HUD names the Board chamber")
	_check(world.player.global_position.distance_to(world.marker("inv_board_mc_stand")) < 2.0 and world.davor.global_position.distance_to(world.marker("inv_board_davor_stand")) < 2.0, "the MC and Davor stand at the open end of the table")
	var seated := 0
	for key: String in story.BOARD_HEADS.keys() + story.BOARD_GUESTS.keys():
		var person: Node2D = story.people.get("inv_board_" + key)
		if person != null and person.visible and person.global_position.distance_to(world.marker("inv_board_" + key)) < 2.0:
			seated += 1
	_check(seated == 9, "all seven Heads, Iva Most and the Diplomatic Secretary are in the chamber")
	_check(world._camera.zoom.x > story.BOARD_ZOOM, "the camera starts close when the lift opens")
	await get_tree().create_timer(1.5).timeout
	await _capture("board_meeting_" + route)
	_check(is_equal_approx(world._camera.zoom.x, story.BOARD_ZOOM) and not ui.top_panels_visible(), "the camera pulls back over the table and the top HUD is hidden")
	ui.cancel_scene()
	_check(not story.has("board_met") and int(GameState.inventory.get("board_credentials", 0)) == credentials_before, "cancelling the Board meeting decides nothing")
	_save("board chamber " + route)
	_check(story.room() == "board" and not story.has("board_met"), "save/load inside the Board chamber keeps the MC there")
	_check(world._camera.zoom == Vector2.ONE and world._camera.position == story.CAMERA_OFFSET, "loading inside the chamber returns the camera to the MC")
	_at("inv_board_finance")
	_check(story.handle("inv_board_finance") and not story.has("board_met"), "other Heads send the MC to the Head of Nation before the meeting")
	_at("inv_board_nation")
	story.handle("inv_board_nation")
	_check(ui.scene_playing(), "the Head of Nation restarts a cancelled meeting")
	_end()
	_check(story.has("board_met") and int(GameState.inventory.get("board_credentials", 0)) == credentials_before + 1, "the Board refuses military help but issues credentials for Breece")
	_check(GameState.gold == gold_before + story.BREECE_BUDGET, "Iva Most leaves 2000 gold for the journey")
	await get_tree().create_timer(1.5).timeout
	_check(world._camera.zoom == Vector2.ONE and world._camera.position == story.CAMERA_OFFSET, "the camera returns to the MC after the meeting")
	_check(ui.top_panels_visible(), "the top HUD panels return after the meeting")
	_check(story.status().contains("pilot") and world.chapter.status().contains("visit to Breece"), "the HUD sends the MC to find a pilot for Breece")
	_check(not story.attend_board(), "the Board meeting happens once")
	var remarks := 0
	for key: String in story.BOARD_HEADS.keys() + story.BOARD_GUESTS.keys():
		_at("inv_board_" + key)
		story.handle("inv_board_" + key)
		if ui.scene_playing() and story.BOARD_REMARKS.has(key):
			remarks += 1
		ui.cancel_scene()
	_check(remarks == 9, "every Head and both Secretaries have a remark after the meeting")
	_check(int(GameState.inventory.get("board_credentials", 0)) == credentials_before + 1, "talking to the Board afterwards gives no extra credentials")
	_at("inv_board_exit")
	story.handle("inv_board_exit")
	_check(story.room().is_empty() and world.player.global_position.distance_to(world.marker("tower")) < 2.0, "the lift returns the MC to the Tower door")
	_check(world._camera.zoom == Vector2.ONE, "the normal zoom returns outside the chamber")
	_check(story.go_to_board() and story.room() == "board" and not ui.scene_playing(), "the MC can return to the chamber without repeating the meeting")
	_check(GameState.gold == gold_before + story.BREECE_BUDGET, "talking to the Board afterwards gives no extra gold")
	_at("tower")
	world.gang_jobs._veki_menu()
	_check(_has_choice("Ask Veki to fly to Breece"), "after the Board meeting Veki can be asked to fly to Breece")
	_choose("Ask Veki to fly to Breece")
	_advance_to("Pay Veki 1000 gold")
	ui.cancel_scene()
	_check(not story.has("veki_hired") and GameState.gold == gold_before + story.BREECE_BUDGET, "cancelling Veki's offer pays nothing")
	var savings := GameState.gold
	GameState.gold = story.VEKI_ADVANCE - 1
	_check(not story.hire_veki() and not story.has("veki_hired") and GameState.gold == story.VEKI_ADVANCE - 1, "Veki will not fly without the first 1000 gold")
	_end()
	GameState.gold = savings
	world.gang_jobs._veki_menu()
	_choose("Ask Veki to fly to Breece")
	_advance_to("Pay Veki 1000 gold")
	_choose("Pay Veki 1000 gold")
	_end()
	_check(story.has("veki_hired") and GameState.gold == savings - story.VEKI_ADVANCE, "Veki takes 1000 gold now and the rest after Cauliflower")
	_check(story.status().contains("passenger dock") and world.chapter.status().contains("Otpornik"), "the HUD sends the MC and Veki to the passenger dock")
	_check(story.veki_companion != null and story.veki_companion.visible and not world.gang_jobs.veki.visible, "Veki joins the party and leaves his post at Punk Park")
	_at("dock_officer")
	story.veki_companion.global_position = world.player.global_position + Vector2(400, 0)
	world.chapter.handle("dock_officer")
	_end()
	_check(not story.has("otpornik_passes"), "the Dock Officer wants Veki present before issuing passes")
	story.place_veki()
	_check(story.veki_companion.global_position.distance_to(world.player.global_position) < 80.0, "Veki stays beside the MC")
	world.chapter.handle("dock_officer")
	ui.cancel_scene()
	_check(not story.has("otpornik_passes"), "cancelling at the dock issues nothing")
	world.chapter.handle("dock_officer")
	_end()
	_check(story.has("otpornik_passes") and story.status().contains("Otpornik"), "the Dock Officer issues passes to Otpornik")
	world.gang_jobs._veki_menu()
	_check(not _has_choice("Ask Veki to fly to Breece"), "Veki is hired only once")
	ui.cancel_scene()
	_check(not story.hire_veki() and GameState.gold == savings - story.VEKI_ADVANCE, "Veki is paid only once")
	_save("board met " + route)
	_check(story.has("board_met") and int(GameState.inventory.get("board_credentials", 0)) == credentials_before + 1, "the Board decision persists")
	_check(story.has("veki_hired") and GameState.gold == savings - story.VEKI_ADVANCE and story.has("otpornik_passes"), "Veki's hiring, payment and the passes persist")
	_check(story.veki_companion != null and story.veki_companion.visible and not world.gang_jobs.veki.visible, "Veki is still in the party after loading")

func _closed_contracts() -> void:
	await _reset()
	world.gang_jobs.set_flag("shipment_squirrel")
	world.gang_jobs.set_flag("rescue_job")
	story.set_flag("hostile_squirrel")
	world.gang_jobs.cancel_for_hostility("squirrel")
	_check(world.gang_jobs.has("shipment_cancelled") and world.gang_jobs.has("rescue_cancelled"), "unfinished Squirrel contracts close explicitly")
	_at("green_squirrel")
	_check(not world.gang_jobs.accept_shipment("squirrel") and not world.gang_jobs.accept_rescue(), "hostility cannot be bypassed by direct acceptance calls")
	_check(not world.gang_jobs.status().contains("K-17") and not world.gang_jobs.status().contains("Rescue:"), "closed contracts leave active objective list")
	_at("freight_office")
	_check(not world.gang_jobs.bribe_freight() and not world.gang_jobs.enter_freight(false), "withdrawn shipment cannot be reopened at warehouse")
	world.gang_jobs.set_flag("hunt_job")
	story.set_flag("hostile_pelican")
	world.gang_jobs.cancel_for_hostility("pelican")
	_check(world.gang_jobs.has("hunt_cancelled") and not world.gang_jobs.search.running(), "unfinished collector hunt closes without reward")
	_save("closed optional contracts")
	await _reset()
	story.set_flag("boss_met")
	world.chapter.set_flag("pelican_job")
	_at("red_pelican")
	world.gang_jobs._recruiter("pelican")
	_check(_has_choice("Ask about the envelope delivery") and _has_choice("Ask to speak to the Pelican boss"), "old envelope save preserves investigation and delivery choices together")
	ui.cancel_scene()
	GameState.defeated_persistent_enemies.erase("iskra_pelican_job")

func _change_approach() -> void:
	await _reset()
	story.set_flag("owner_link")
	story.set_flag("boss_met")
	_at("inv_squirrel_boss")
	_check(story.start_assault("direct"), "begin direct confrontation before changing approach")
	var guard: Variant = story.encounters.enemies.get("squirrel_guard_0")
	guard.take_damage(10, world.player.global_position)
	var remaining: int = guard.health
	_at("inv_pelican_entry")
	_check(story.enter_site("pelican"), "leave unfinished direct fight to seek support")
	_at("inv_pelican_boss")
	_check(story.warn_pelicans(), "Pelicans hear warning during direct confrontation")
	_end()
	_check(story.get_value("route") == "direct", "warning preserves active fight's route until support arrives")
	_at("inv_rendezvous")
	_check(story.start_assault("pelican"), "Pelican allies join an existing confrontation")
	_check(story.encounters.enemies.squirrel_guard_0.health == remaining and story.encounters.allies.size() == 3, "support preserves wounded defenders and adds three allies")
	_at("inv_rendezvous")
	_check(not story.start_assault("pelican"), "repeated assault cannot restart encounter")
	_check(story.get_value("encounter") == "squirrel" and not story.hostile("pelican"), "rejected assault leaves existing fight and friendly faction intact")
	_save("changed approach")

func _at(id: String) -> void:
	ui.cancel_scene()
	ui.close_modal()
	story._move(id)
	world.davor.set_physics_process(false)

func _save(label: String) -> void:
	ui.cancel_scene()
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "save/load " + label)
	world.apply_loaded_state()
	world.davor.set_physics_process(false)

func _has_choice(prefix: String) -> bool:
	for child in ui.scene_buttons.get_children():
		if child is Button and child.text.begins_with(prefix):
			return true
	return false

func _choose(prefix: String) -> void:
	for child in ui.scene_buttons.get_children():
		if child is Button and child.text.begins_with(prefix):
			child.pressed.emit()
			return
	_check(false, "missing choice " + prefix)

func _advance_to(prefix: String) -> void:
	for i in 40:
		if _has_choice(prefix):
			return
		ui.advance_scene()
	_check(false, "dialogue reaches choice " + prefix)

func _end() -> void:
	for i in 80:
		if not ui.scene_playing():
			return
		ui.advance_scene()
	_check(false, "dialogue finishes")

func _find_input(node: Node) -> LineEdit:
	if node is LineEdit:
		return node
	for child in node.get_children():
		var found := _find_input(child)
		if found != null:
			return found
	return null

func _key(code: int, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])

func _finish() -> void:
	print("Iskra investigation: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
