extends Node

const RiverScript = preload("res://scripts/world/brudet_world.gd")
const TargetScript = preload("res://scripts/world/practice_target.gd")

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	var save_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	if data_home.is_empty() or not save_path.begins_with(data_home + "/"):
		_check(false, "Brudet save test needs an isolated XDG_DATA_HOME")
		_finish(null)
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main game scene loads for Brudet travel")
	if scene == null:
		_finish(null)
		return
	var game := scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	var state := GameState
	var ui := game.get_node_or_null("GameUI") as GameUI
	_check(ui != null and game.world is GameWorld, "Paprika and its travel UI start")
	if ui == null:
		_finish(game)
		return
	var departure := Vector2(840, 280)
	_check(game.world.tiled_loader.map_size == Vector2(1664, 1920) and game.world.tiled_loader.is_walkable_position(departure), "expanded Paprika map keeps the northern travel departure walkable")
	game.world.player.global_position = departure
	ui.open_service("travel", "Paprika Travel Agency")
	var visit := _find_button(ui.modal_content, "Visit Brudet")
	_check(visit != null and visit.text.contains("1000"), "northern agency offers a 1,000-gold Brudet ticket")
	if visit == null:
		_finish(game)
		return
	visit.pressed.emit()
	_check(game._world_planet == "paprika" and state.gold == 0, "unaffordable trip keeps the player and gold on Paprika")
	state.add_gold(1200)
	visit.pressed.emit()
	await get_tree().process_frame
	var river := game.world as RiverScript
	_check(river != null and state.current_planet == "brudet" and state.gold == 200, "successful travel switches world and charges the fare once")
	if river == null:
		_finish(game)
		return
	_check(not ui.modal_overlay.visible and ui.location_label.text.contains("BRUDET"), "travel closes the menu and updates the location title")
	_check(river.tiled_loader.map_size == Vector2(1792, 1280), "Brudet is a larger 112-by-80-tile world")
	_check(river.player.global_position.distance_to(state.BRUDET_ARRIVAL) <= 48.0 and river.player.respawn_location_name == "Brudet", "arrival and respawn belong to Brudet")
	_check(river.tiled_loader.is_walkable_position(river.player.global_position), "Brudet arrival is walkable")

	var residents: Array[Villager] = []
	var enemies: Array[Enemy] = []
	var distinct_ids: Dictionary = {}
	var distinct_names: Dictionary = {}
	var fisher_count := 0
	for actor in river.actors_root.get_children():
		if actor is Villager:
			residents.append(actor)
			distinct_ids[actor.villager_id] = true
			distinct_names[actor.villager_name] = true
			if actor.routine_role == "fisher":
				fisher_count += 1
		elif actor is Enemy and actor.enemy_id in ["finling", "lake_maw", "river_serpent"]:
			enemies.append(actor)
	_check(residents.size() == 30 and distinct_ids.size() == 30 and distinct_names.size() >= 25, "thirty distinct Brudet residents have stable identities")
	_check(fisher_count >= 4 and enemies.size() >= 3, "fishermen and fishlike enemies inhabit Brudet")
	var heard_republic := false
	var heard_recruiting := false
	for resident in residents:
		for line: String in Villager.ROLE_DIALOGUE.get(resident.routine_role, []):
			if line.contains("Artichoke") and line.contains("Republic"):
				heard_republic = true
			if line.contains("military") and (line.contains("recruiting") or line.contains("enlistment")):
				heard_recruiting = true
	_check(heard_republic and heard_recruiting, "Brudet residents have dialogue about the Republic attack on Artichoke and military recruiting")
	var reachable_monsters := 0
	for enemy in enemies:
		var path := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, enemy.spawn_position)
		if not path.is_empty() and path[-1].distance_to(enemy.spawn_position) <= 40.0:
			reachable_monsters += 1
	_check(reachable_monsters >= 3, "at least three river monsters can be approached from the city")
	_check(river._target != null and river._target is TargetScript, "the Military Headquarters has a practice target")
	var river_fields: Array[FieldPlot] = []
	for plot in river.tiled_loader._field_root.get_children():
		if plot is FieldPlot and plot.is_common:
			river_fields.append(plot)
	_check(river_fields.size() >= 30 and river_fields[0].field_id.begins_with("brudet:"), "Brudet has harvestable crops with planet-specific field IDs")
	if not river_fields.is_empty():
		var first_field := river_fields[0]
		var before_crop := int(state.inventory.get(first_field.crop_id, 0))
		first_field.interact(river.player)
		_check(int(state.inventory.get(first_field.crop_id, 0)) == before_crop + 1 and not state.field_is_ready(first_field.field_id), "Brudet common crops harvest and begin regrowth")

	var source = JSON.parse_string(FileAccess.get_file_as_string(RiverScript.BRUDET_MAP))
	_check(source is Dictionary, "Brudet map is valid Tiled JSON")
	var bridges: Array[Vector2] = []
	var water: Dictionary = {}
	var buildings := 0
	var ponds := 0
	if source is Dictionary:
		for layer in source.get("layers", []):
			if String(layer.get("name", "")) == "Water":
				water = layer
			if String(layer.get("type", "")) != "objectgroup":
				continue
			for obj in layer.get("objects", []):
				var name := String(obj.get("name", ""))
				if name == "stone_bridge":
					bridges.append(Vector2(float(obj["x"]) + float(obj["width"]) * 0.5, float(obj["y"]) - float(obj["height"]) * 0.5))
				elif name == "river_townhouse":
					buildings += 1
				elif name == "fishing_pond":
					ponds += 1
	_check(bridges.size() >= 2 and buildings >= 12, "two bridges and at least twelve townhouses define the city")
	_check(ponds >= 2, "multiple fishing ponds are placed around Brudet")
	_check(not water.is_empty(), "river and lake have a water collision layer")
	if not water.is_empty():
		var width := int(source["width"])
		var blocked := 0
		var western_lake_cells := 0
		var tiles: Array = water["data"]
		for index in tiles.size():
			if int(tiles[index]) == 0:
				continue
			blocked += 1
			if index % width < 45 and index / width >= 32 and index / width < 58:
				western_lake_cells += 1
			var sample := Vector2((index % width + 0.5) * 16.0, (index / width + 0.5) * 16.0)
			if blocked <= 20:
				_check(not river.tiled_loader.is_walkable_position(sample), "water cell %d blocks movement" % blocked)
		_check(blocked >= 200 and western_lake_cells >= 150, "main river and broad western lake contain substantial water terrain")
	for bridge in bridges:
		var west := Vector2(bridge.x - 112, bridge.y)
		var east := Vector2(bridge.x + 112, bridge.y)
		var crossing := river.tiled_loader.get_walk_path(west, east)
		var crosses_deck := false
		for waypoint in crossing:
			if absf(waypoint.x - bridge.x) <= 16.0 and absf(waypoint.y - bridge.y) <= 20.0:
				crosses_deck = true
				break
		_check(river.tiled_loader.is_walkable_position(bridge) and not crossing.is_empty() and crossing[-1].distance_to(east) <= 8.0 and crosses_deck, "bridge at y=%d crosses its own deck between walkable banks" % bridge.y)

	var services: Dictionary = {}
	for node in river.tiled_loader._object_root.get_children():
		if node is WorldService:
			if not services.has(node.service_id):
				services[node.service_id] = node
	for service_id in ["river_market", "river_library", "river_town_hall", "military_hq", "travel", "fishing_pond"]:
		_check(services.has(service_id), "%s is interactive" % service_id)
		if services.has(service_id):
			var service: WorldService = services[service_id]
			var approach: Vector2 = service.get_interaction_position() + Vector2(0, 12)
			var route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, approach)
			_check(not route.is_empty() and route[-1].distance_to(service.get_interaction_position()) < Player.INTERACTION_DISTANCE, "%s can be reached from arrival" % service_id)
	ui.open_service("river_library", "Brudet Library")
	_check(_has_text(ui.modal_content, "Blockovia") and _has_text(ui.modal_content, "fishing rod") and _has_text(ui.modal_content, "Military Headquarters"), "library offers Craft history and useful local advice")
	_check(_has_text(ui.modal_content, "Paprika and Brudet belong to the Cauliflower Confederation"), "library identifies Brudet and Paprika as Confederation planets")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	_check(_has_text(ui.modal_content, "stone bridges"), "town hall describes river-city landmarks")
	ui.open_service("military_hq", "Military Headquarters")
	_check(_find_button(ui.modal_content, "Clear River Monsters") == null and _has_text(ui.modal_content, "training space station") and _has_text(ui.modal_content, "battlefield"), "headquarters only explains future enlistment and training")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	var patrol := _find_button(ui.modal_content, "Clear River Monsters")
	_check(patrol != null, "Town Hall offers river patrol")
	if patrol != null:
		patrol.pressed.emit()
	_check(state.active_jobs.has("river_patrol"), "Brudet patrol can be accepted")
	if river._target != null:
		var before := river._target.health
		river._target.take_damage(4)
		_check(river._target.health < before and not state.active_job_ready("river_patrol"), "practice target reacts to a hit without awarding patrol kills")
		state.add_item("wood_bow")
		state.equip_item("wood_bow")
		river.player.global_position = river._target.global_position + Vector2(-38, 0)
		river.player.facing = Vector2.RIGHT
		var before_arrow := river._target.health
		river.player._attack()
		for tick in range(18):
			await get_tree().physics_frame
		_check(river._target.health < before_arrow, "a fired arrow hits the practice target beside headquarters")
	var fish_before_rod := int(state.inventory.get("river_fish", 0))
	_check(not river.try_fish() and int(state.inventory.get("river_fish", 0)) == fish_before_rod, "fishing requires a purchased rod")
	ui.open_service("river_market", "Brudet Market")
	var rod := _find_button(ui.modal_content, "Fishing Rod")
	var stew := _find_button(ui.modal_content, "Fish Stew")
	var fishing_work := _find_button(ui.modal_content, "Bring in Three Fish")
	_check(rod != null and stew != null and fishing_work != null, "market sells rod and food and offers fishing work")
	if rod != null:
		rod.pressed.emit()
	_check(int(state.inventory.get("fishing_rod", 0)) == 1 and state.gold == 135, "fishing rod costs 65 gold")
	if fishing_work != null:
		fishing_work = _find_button(ui.modal_content, "Bring in Three Fish")
		fishing_work.pressed.emit()
	_check(state.active_jobs.has("fishing_work"), "fishing work runs alongside river patrol")
	ui.close_modal()
	if services.has("fishing_pond"):
		var pond: WorldService = services["fishing_pond"]
		river.player.global_position = pond.get_interaction_position() + Vector2(0, 12)
		pond.interact(river.player)
		_check(int(state.inventory.get("river_fish", 0)) == 1 and int(state.active_jobs.get("fishing_work", 0)) == 1, "E at a pond catches fish and advances the job")
		pond.interact(river.player)
		_check(int(state.inventory.get("river_fish", 0)) == 1, "fishing cooldown prevents immediate second catch")
		state._process(RiverScript.FISHING_COOLDOWN + 0.1)
		river.try_fish()
		state._process(RiverScript.FISHING_COOLDOWN + 0.1)
		river.try_fish()
		_check(int(state.active_jobs.get("fishing_work", 0)) == 3 and state.active_job_ready("fishing_work"), "three catches complete the market job")
		ui.open_service("river_market", "Brudet Market")
		var claim := _find_button(ui.modal_content, "Bring in Three Fish")
		if claim != null:
			claim.pressed.emit()
		_check(not state.active_jobs.has("fishing_work") and state.gold == 165, "market pays the fishing reward")
		ui.close_modal()
	var kills := 0
	for enemy in enemies:
		if kills >= 3:
			break
		enemy.take_damage(999)
		kills += 1
	_check(int(state.active_jobs.get("river_patrol", 0)) == 3 and state.active_job_ready("river_patrol"), "three fishlike monster defeats complete river patrol")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	var claim_patrol := _find_button(ui.modal_content, "Clear River Monsters")
	if claim_patrol != null:
		claim_patrol.pressed.emit()
	_check(not state.active_jobs.has("river_patrol") and state.gold >= 250, "Town Hall pays patrol reward")
	ui.close_modal()

	for team_job: String in state.BRUDET_TEAM_IDS:
		ui.open_service("river_town_hall", "Brudet Town Hall")
		var job_name: String = String(GameData.job(team_job).get("name", team_job))
		var offer := _find_button(ui.modal_content, job_name)
		_check(offer != null and not offer.disabled, "%s is offered at Town Hall" % team_job)
		if offer == null:
			continue
		offer.pressed.emit()
		_check(state.team_job_id == team_job and state.active_jobs.has(team_job) and not state.squad_deployed, "Town Hall starts %s before deployment" % team_job)
		for other_job: String in state.BRUDET_TEAM_IDS:
			if other_job != team_job:
				var other_button := _find_button(ui.modal_content, String(GameData.job(other_job).get("name", other_job)))
				_check(other_button != null and other_button.disabled, "another team job cannot start during %s" % team_job)
		for resident_index in 2:
			var recruit_button := _find_button(ui.modal_content, "Recruit ")
			_check(recruit_button != null, "Town Hall lists a Brudet villager for recruitment")
			if recruit_button != null:
				recruit_button.pressed.emit()
		_check(state.squad_recruits.size() == 2, "Town Hall recruits two Brudet residents for %s" % team_job)
		var deploy_button := _find_button(ui.modal_content, "Deploy squad")
		_check(deploy_button != null, "Town Hall enables deployment with two recruits")
		if deploy_button != null:
			deploy_button.pressed.emit()
		_check(state.squad_deployed, "two Brudet residents deploy for %s" % team_job)
		if state.squad_deployed:
			var recruit_id: String = state.squad_recruits[0]
			_check(state.set_squad_order(recruit_id, "hold", river.player.global_position) and String(state.squad_members[recruit_id]["order"]) == "hold", "Brudet recruit accepts a hold order")
			_check(state.set_squad_order(recruit_id, "follow", river.player.global_position), "Brudet recruit resumes following")
		await get_tree().process_frame
		var expected_ids: Array = state.BRUDET_TEAM_IDS[team_job]
		var targets: Dictionary = {}
		for actor in river.actors_root.get_children():
			if actor is Enemy and expected_ids.has(actor.persistent_id) and not actor.is_queued_for_deletion():
				targets[actor.persistent_id] = actor
		_check(targets.size() == expected_ids.size(), "%s spawns its distinct marked targets" % team_job)
		if team_job == "brudet_hacker_team" and targets.has(expected_ids[0]):
			var hacker: Enemy = targets[expected_ids[0]]
			var origin := hacker.global_position
			var nearby := Vector2.ZERO
			for offset in [Vector2(50, 0), Vector2(-50, 0), Vector2(0, 50), Vector2(0, -50)]:
				var candidate: Vector2 = origin + offset
				if river.tiled_loader.is_walkable_position(candidate) and not river.tiled_loader.get_walk_path(origin, candidate).is_empty():
					nearby = candidate
					break
			_check(nearby != Vector2.ZERO, "phase hacker has a walkable nearby player position")
			if nearby != Vector2.ZERO:
				river.player.global_position = nearby
				hacker._start_phase(river.player)
				_check(hacker.state == Enemy.State.PHASE_WARNING and is_instance_valid(hacker._phase_warning) and hacker._phase_warning.visible, "phase hacker shows a teleport warning")
				_check(hacker._phase_cooldown > 0.0 and hacker.global_position == origin, "phase hacker starts teleport cooldown before moving")
				if hacker.state == Enemy.State.PHASE_WARNING:
					_check(river.tiled_loader.is_walkable_position(hacker._phase_destination), "phase hacker chooses a walkable destination")
					hacker._finish_phase()
					_check(hacker.global_position.distance_to(origin) > 8.0, "phase hacker teleports away from its original position")
					_check(hacker._phase_warning == null, "phase hacker clears the teleport warning")
					var collision := PhysicsShapeQueryParameters2D.new()
					collision.shape = hacker._collision.shape
					collision.transform = Transform2D(0.0, hacker.global_position + hacker._collision.position)
					collision.collision_mask = 1 | 2 | 8 | 64
					collision.exclude = [hacker.get_rid()]
					_check(river.tiled_loader.is_walkable_position(hacker.global_position) and hacker.get_world_2d().direct_space_state.intersect_shape(collision, 1).is_empty(), "phase hacker ends on walkable ground without overlapping a collision")
		for target_id: String in expected_ids:
			if not targets.has(target_id):
				continue
			var target: Enemy = null
			for actor in river.actors_root.get_children():
				if actor is Enemy and actor.persistent_id == target_id and not actor.is_queued_for_deletion():
					target = actor
					break
			_check(target != null, "%s remains available after reload" % target_id)
			if target == null:
				continue
			target.take_damage(999)
			_check(state.team_defeated_ids.has(target_id), "%s defeat records its stable ID" % target_id)
			if state.team_defeated_ids.size() == 1:
				river.capture_player_position()
				_check(state.save_game() and state.load_game(), "%s persists during a partially cleared mission" % team_job)
				river.apply_loaded_state()
				await get_tree().process_frame
				_check(state.team_job_id == team_job and state.squad_deployed and state.team_defeated_ids.has(target_id), "%s reload retains squad and defeated target" % team_job)
		_check(state.active_job_ready(team_job), "%s requires its marked targets" % team_job)
		ui.open_service("river_town_hall", "Brudet Town Hall")
		var claim_team := _find_button(ui.modal_content, job_name)
		if claim_team != null:
			claim_team.pressed.emit()
		_check(not state.active_jobs.has(team_job) and state.team_job_id.is_empty() and state.team_defeated_ids.is_empty(), "Town Hall pays and clears %s" % team_job)
		ui.close_modal()

	var river_position := Vector2(1420, 720)
	river.player.global_position = river_position
	river.capture_player_position()
	_check(state.save_game(), "Brudet position and fishing cooldown save")
	ui.open_service("travel", "Brudet Travel Agency")
	var back := _find_button(ui.modal_content, "Return to Paprika")
	_check(back != null and back.text.contains("1000"), "Brudet agency charges 1,000 gold for return")
	var before_return := state.gold
	if before_return >= 1000:
		state.spend_gold(before_return - 999)
		ui.open_service("travel", "Brudet Travel Agency")
		back = _find_button(ui.modal_content, "Return to Paprika")
	if back != null:
		back.pressed.emit()
	_check(game._world_planet == "brudet" and state.gold < 1000, "unaffordable return leaves the player on Brudet")
	state.add_gold(1000)
	ui.open_service("travel", "Brudet Travel Agency")
	back = _find_button(ui.modal_content, "Return to Paprika")
	var return_balance := state.gold
	if back != null:
		back.pressed.emit()
	await get_tree().process_frame
	_check(game._world_planet == "paprika" and state.current_planet == "paprika" and state.gold == return_balance - 1000, "paid return restores Paprika and charges once")
	_check(game.world.player.global_position.distance_to(departure) < 32.0 and ui.location_label.text.contains("PAPRIKA"), "return recalls unchanged northern departure point and title")
	var south_square := Vector2(810, 1372)
	var road: PackedVector2Array = game.world.tiled_loader.get_walk_path(departure, south_square)
	_check(not road.is_empty() and road[-1].distance_to(south_square) <= 8.0, "returning from Brudet leaves the southern village reachable by the long road")
	state.add_gold(1000)
	ui.open_service("travel", "Paprika Travel Agency")
	var second_ticket := _find_button(ui.modal_content, "Visit Brudet")
	if second_ticket != null:
		second_ticket.pressed.emit()
	await get_tree().process_frame
	_check(game._world_planet == "brudet" and state.gold == return_balance - 1000 and game.world.player.global_position.distance_to(river_position) < 48.0, "second paid trip recalls the saved Brudet position")
	ui.open_service("travel", "Brudet Travel Agency")
	var second_return := _find_button(ui.modal_content, "Return to Paprika")
	if second_return != null:
		second_return.pressed.emit()
	_check(game._world_planet == "brudet", "second return without a fare is refused")
	state.add_gold(1000)
	ui.open_service("travel", "Brudet Travel Agency")
	second_return = _find_button(ui.modal_content, "Return to Paprika")
	if second_return != null:
		second_return.pressed.emit()
	await get_tree().process_frame
	_check(game._world_planet == "paprika" and state.gold == return_balance - 1000, "second paid return charges 1,000 gold")
	var load_key := InputEventAction.new()
	load_key.action = "quick_load"
	load_key.pressed = true
	game._unhandled_input(load_key)
	await get_tree().process_frame
	_check(game._world_planet == "brudet" and state.current_planet == "brudet", "F9 rebuilds Brudet world from its save")
	_check(game.world.player.global_position.distance_to(river_position) < 48.0 and state.fishing_ready_at > 0.0 and state.gold == before_return, "Brudet location, cooldown and gold survive reload")
	_finish(game)

func _find_button(node: Node, label: String) -> Button:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button and child.text.contains(label):
			return child
		var result := _find_button(child, label)
		if result != null:
			return result
	return null

func _has_text(node: Node, text: String) -> bool:
	for child in node.get_children():
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
	print("Brudet world: %d checks, %d failures" % [checks, failures])
	if game != null:
		remove_child(game)
		game.free()
	get_tree().quit(0 if failures == 0 else 1)
