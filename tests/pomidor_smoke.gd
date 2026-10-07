extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	var save_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	if data_home.is_empty() or not save_path.begins_with(data_home + "/"):
		_check(false, "Pomidor smoke requires an isolated XDG_DATA_HOME")
		_finish(null)
		return
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	var ui := game.get_node_or_null("GameUI") as GameUI
	if ui == null or game.world == null:
		_check(false, "main scene starts with UI and a world")
		_finish(game)
		return
	var state := GameState

	# A graduate on Artichoke before General Hickey's promotion.
	state.military_stage = "graduated"
	state.military_cannon_hits.assign(state.MILITARY_CANNON_TARGETS.duplicate())
	state.military_trap_progress = state.MILITARY_TRAP_STEPS.size()
	state.current_planet = "artichoke"
	state.current_area = "exterior"
	_check(game._switch_world("artichoke") and game.world is ArtichokeWorld, "Artichoke loads")
	_check(not state.can_travel("pomidor") and state.travel_fare("pomidor") == 0, "Pomidor stays closed before the promotion to Captain")
	ui.open_service("artichoke_ship", "Military Transport")
	_check(_find_button(ui.modal_content, "Fly to Pomidor") == null, "the Artichoke transport does not offer Pomidor before the promotion")
	ui.close_modal()

	state.defeated_persistent_enemies.append(state.POMIDOR_UNLOCK_FLAG)
	var gold_before := state.gold
	ui.open_service("artichoke_ship", "Military Transport")
	var fly := _find_button(ui.modal_content, "Fly to Pomidor")
	_check(fly != null, "a Captain can fly to Pomidor from the Artichoke transport")
	if fly == null:
		_finish(game)
		return
	fly.pressed.emit()
	await get_tree().process_frame
	var town := game.world as PomidorWorld
	_check(town != null and state.current_planet == "pomidor" and state.gold == gold_before, "the flight reaches Pomidor for free")
	if town == null:
		_finish(game)
		return
	var loader := town.tiled_loader
	_check(town.player.global_position.distance_to(state.POMIDOR_ARRIVAL) <= 24.0 and loader.is_walkable_position(town.player.global_position), "the player lands on walkable ground at the landing field")
	_check(town.player.respawn_location_name == "Pomidor", "respawn belongs to Pomidor")
	_check(ui.location_label.text == "POMIDOR", "the location title names Pomidor")

	# The town is dense, with streets between the rows of houses.
	var houses := 0
	var services: Dictionary = {}
	for node in loader._object_root.get_children():
		if node is WorldService:
			services[node.service_id] = node
		elif String(node.name).begins_with("townhouse") or String(node.name).begins_with("row_house") or String(node.name).begins_with("pomidor_house"):
			houses += 1
	for id in ["pomidor_council_hall", "chamber_exit", "pomidor_library", "pomidor_market", "pomidor_forge", "pomidor_clothing", "beer_hall", "pomidor_ship"]:
		_check(services.has(id), "the map has the %s service" % id)
	var townsfolk := 0
	for actor in town.actors_root.get_children():
		if actor is Villager:
			townsfolk += 1
			if townsfolk <= 3:
				_check(actor.routine_role.begins_with("pomidor_") and not actor.villager_name.is_empty(), "%s has a Pomidor routine" % actor.villager_id)
	_check(townsfolk >= 20, "Pomidor's streets have at least 20 townsfolk (%d)" % townsfolk)
	var arrival := town.player.global_position
	for id in ["pomidor_council_hall", "pomidor_library", "pomidor_market", "beer_hall", "pomidor_clothing", "pomidor_forge"]:
		if not services.has(id):
			continue
		var door: Vector2 = services[id].get_interaction_position()
		var path := loader.get_walk_path(arrival, _open_point_near(loader, door))
		_check(not path.is_empty() and path[-1].distance_to(_open_point_near(loader, door)) < 20.0, "a street leads from the landing field to %s" % id)

	# The Council Hall door leads into the chamber, and the chamber doors lead back out.
	_check(_interact_service(town, ui, "pomidor_council_hall") or town.in_council_chamber(), "E at the Council Hall door enters the chamber")
	_check(town.in_council_chamber() and loader.is_walkable_position(town.player.global_position) and ui.location_label.text == "COUNCIL CHAMBER", "the player stands on the chamber floor and the title names the chamber")
	var outside := loader.get_walk_path(town.player.global_position, arrival)
	_check(outside.is_empty() or outside[-1].distance_to(arrival) > 20.0, "the chamber walls close it off from the town")
	_check(town.council_keys().size() == 18, "the chamber seats 12 councillors and 6 Secretaries")
	var per_planet: Dictionary = {}
	for key in town.council_keys():
		var person := town.council_person(key)
		_check(person != null and town.in_council_chamber(person.global_position), "%s sits in the chamber" % key)
		var seat: Dictionary = PomidorWorld.COUNCIL[key]
		if seat.has("planet"):
			per_planet[seat["planet"]] = int(per_planet.get(seat["planet"], 0)) + 1
	_check(per_planet.size() == 6 and per_planet.values().all(func(n: int) -> bool: return n == 2), "the Big Council has two members from each of the six planets")

	# Talking to the Secretary of the Army records the report and pays from the treasury.
	var army := town.council_person("secretary_army")
	town.player.global_position = _open_point_near(loader, army.global_position + Vector2(0, 14))
	town.player._update_nearest_interactable()
	_check(town.player._current_interactable == army, "the Secretary of the Army is the nearest person to talk to")
	_interact(town.player)
	var report := _find_button(ui.modal_content, "Report what was done on Artichoke")
	_check(ui.modal_overlay.visible and report != null, "the Secretary of the Army asks for the Artichoke report")
	gold_before = state.gold
	if report != null:
		report.pressed.emit()
	_check(town.reported_to_council() and state.gold == gold_before + PomidorWorld.REPORT_REWARD, "the report is recorded and paid once")
	_check(_find_button(ui.modal_content, "Report what was done on Artichoke") == null and _has_text(ui.modal_content, "has your report"), "after the report the Secretary answers differently")
	_check(not town.report_to_council() and state.gold == gold_before + PomidorWorld.REPORT_REWARD, "a second report pays nothing")
	ui.open_service(PomidorWorld.COUNCIL_SERVICE_PREFIX + "secretary_gold", "Gold")
	_check(_has_text(ui.modal_content, "common treasury"), "the Secretary of Gold talks about the treasury")
	ui.open_service(PomidorWorld.COUNCIL_SERVICE_PREFIX + "secretary_economy", "Economy")
	_check(_has_text(ui.modal_content, "markets") and _has_text(ui.modal_content, "timber"), "the Secretary of the Economy runs the markets and watches resources")
	ui.close_modal()

	_check(_interact_service(town, ui, "chamber_exit") or not town.in_council_chamber(), "E at the chamber doors leaves the chamber")
	_check(not town.in_council_chamber() and town.player.global_position.distance_to(town.hall_door()) < 40.0, "the player comes out at the Council Hall door")

	# Services in town.
	_check(_interact_service(town, ui, "pomidor_library") and _has_text(ui.modal_content, "year 83") and _has_text(ui.modal_content, "draft rates"), "the library tells the founding and Artichoke's rebellion")
	state.add_gold(100)
	_check(_interact_service(town, ui, "pomidor_clothing"), "the clothier opens")
	var buy := _find_button(ui.modal_content, "Buy another Orange Pomidor Tunic")
	if buy != null:
		buy.pressed.emit()
	var equip := _find_button(ui.modal_content, "Equip Orange Pomidor Tunic")
	if equip != null:
		equip.pressed.emit()
	_check(state.equipment.get("clothing", "") == "orange_tunic" and town.player._sprite.texture.resource_path.ends_with("player_orange.png"), "the orange tunic is bought, worn and drawn")
	_check(_interact_service(town, ui, "beer_hall") and _find_button(ui.modal_content, "Mug of Ale") != null, "the beer hall serves ale")
	_check(_interact_service(town, ui, "pomidor_market") and _find_button(ui.modal_content, "Tomato Soup") != null, "the market sells Pomidor food")
	_check(_interact_service(town, ui, "pomidor_forge") and _find_button(ui.modal_content, "Iron Sword") != null, "the forge sells iron weapons")

	# Save and reload on Pomidor.
	ui.close_modal()
	state.player_position = town.player.global_position
	_check(state.save_game(), "saving on Pomidor succeeds")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(saved is Dictionary and int(saved["schema"]) == state.SAVE_SCHEMA and saved["current_planet"] == "pomidor" and saved["planet_positions"].has("pomidor") and state._valid_save(saved), "the save records Pomidor")
	var without_unlock: Dictionary = saved.duplicate(true)
	without_unlock["defeated_persistent_enemies"].erase(state.POMIDOR_UNLOCK_FLAG)
	_check(not state._valid_save(without_unlock), "a save on Pomidor without the Captain promotion is rejected")
	var old: Dictionary = saved.duplicate(true)
	old["schema"] = state.ARTICHOKE_SAVE_SCHEMA
	old["current_planet"] = "artichoke"
	old["planet_positions"].erase("pomidor")
	old["planet_positions"].erase("chvarak")
	old["planet_positions"].erase("engineeria")
	_check(state._valid_save(old), "a schema-11 save without Pomidor is still valid")
	var before_embassy: Dictionary = saved.duplicate(true)
	before_embassy["schema"] = state.POMIDOR_SAVE_SCHEMA
	before_embassy["planet_positions"].erase("chvarak")
	before_embassy["planet_positions"].erase("engineeria")
	_check(state._valid_save(before_embassy), "a schema-12 save on Pomidor without Chvarak and Engineeria is still valid")
	var on_chvarak: Dictionary = before_embassy.duplicate(true)
	on_chvarak["current_planet"] = "chvarak"
	_check(not state._valid_save(on_chvarak), "a schema-12 save cannot be on Chvarak")
	FileAccess.open(state.SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(before_embassy))
	_check(state.load_game() and state.current_planet == "pomidor" and state.planet_positions.get("chvarak") == [state.CHVARAK_ARRIVAL.x, state.CHVARAK_ARRIVAL.y] and state.planet_positions.get("engineeria") == [state.ENGINEERIA_ARRIVAL.x, state.ENGINEERIA_ARRIVAL.y], "loading a schema-12 save adds the Chvarak and Engineeria arrival positions")
	town.apply_loaded_state()

	# The transport flies back to Artichoke and to Brudet.
	ui.open_service("pomidor_ship", "Confederation Transport")
	var back := _find_button(ui.modal_content, "Fly to Brudet")
	_check(back != null and _find_button(ui.modal_content, "Fly to Artichoke") != null, "the Pomidor transport flies to Artichoke and Brudet")
	gold_before = state.gold
	if back != null:
		back.pressed.emit()
	await get_tree().process_frame
	_check(game.world is BrudetWorld and state.gold == gold_before, "the flight to Brudet is free")
	_finish(game)

func _open_point_near(loader: TiledLoader, point: Vector2) -> Vector2:
	for offset in [Vector2(0, 10), Vector2(0, -10), Vector2(12, 0), Vector2(-12, 0), Vector2(0, 18), Vector2(18, 0), Vector2(-18, 0), Vector2(0, -18)]:
		if loader.is_walkable_position(point + offset):
			return point + offset
	return point

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

func _interact_service(world: Node, ui: GameUI, id: String) -> bool:
	ui.close_modal()
	var fixture := _service(world, id)
	if fixture == null:
		return false
	world.player.global_position = _open_point_near(world.tiled_loader, fixture.get_interaction_position())
	world.player._update_nearest_interactable()
	if world.player._current_interactable != fixture:
		return false
	_interact(world.player)
	return id in ["pomidor_council_hall", "chamber_exit"] or ui.modal_overlay.visible and ui._active_service_id == id

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

func _finish(game: Node) -> void:
	print("Pomidor world: %d checks, %d failures" % [checks, failures])
	if game != null:
		remove_child(game)
		game.free()
	get_tree().quit(0 if failures == 0 else 1)
