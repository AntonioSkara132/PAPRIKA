extends Node

const RiverScript = preload("res://scripts/world/brudet_world.gd")
const TargetScript = preload("res://scripts/world/practice_target.gd")
const MIN_HOSTILE_HOME_DISTANCE := 160.0
const ORIGINAL_WESTERN_LAKE_AREA := Rect2(0, 400, 752, 560)
const SOUTHEAST_LAKE_AREA := Rect2(2176, 1280, 384, 432)

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
	_check(river.tiled_loader.map_size.x > 1792.0 and river.tiled_loader.map_size.y > 1280.0 and int(river.tiled_loader.map_size.x) % 16 == 0 and int(river.tiled_loader.map_size.y) % 16 == 0, "Brudet extends beyond 112 by 80 tiles to give its wilderness room")
	_check(river.player.global_position.distance_to(state.BRUDET_ARRIVAL) <= 48.0 and river.player.respawn_location_name == "Brudet", "arrival and respawn belong to Brudet")
	_check(river.tiled_loader.is_walkable_position(river.player.global_position), "Brudet arrival is walkable")

	var residents: Array[Villager] = []
	var enemies: Array[Enemy] = []
	var distinct_ids: Dictionary = {}
	var distinct_names: Dictionary = {}
	var fisher_count := 0
	var armed_zombies := 0
	var armored_zombies := 0
	var ordinary_zombies := 0
	var ambient_enemies: Array[Enemy] = []
	var armored_sample: Enemy
	for actor in river.actors_root.get_children():
		if actor is Villager:
			residents.append(actor)
			distinct_ids[actor.villager_id] = true
			distinct_names[actor.villager_name] = true
			if actor.routine_role == "fisher":
				fisher_count += 1
		elif actor is Enemy:
			ambient_enemies.append(actor)
			if actor.enemy_id in ["finling", "lake_maw", "river_serpent"]:
				enemies.append(actor)
			elif actor.enemy_id == "zombie":
				ordinary_zombies += 1
			elif actor.enemy_id == "armed_zombie":
				armed_zombies += 1
				_check(actor._weapon_visual != null and actor._weapon_visual.points.size() >= 2, "armed zombie carries a visible weapon")
			elif actor.enemy_id == "armored_zombie":
				armored_zombies += 1
				if armored_sample == null:
					armored_sample = actor
				_check(actor._weapon_visual != null and actor._weapon_visual.points.size() >= 2 and int(actor.definition.get("armor", 0)) > 0, "armored zombie carries a weapon and has armor")
	_check(residents.size() == 30 and distinct_ids.size() == 30 and distinct_names.size() >= 25, "thirty distinct Brudet residents have stable identities")
	_check(fisher_count >= 4 and enemies.size() >= 3, "fishermen and fishlike enemies inhabit Brudet")
	var western_lake_monsters: Array[String] = []
	for enemy in enemies:
		if ORIGINAL_WESTERN_LAKE_AREA.has_point(enemy.spawn_position):
			western_lake_monsters.append(enemy.persistent_id)
	_check(western_lake_monsters.is_empty(), "original western lake and shore have no ambient fishlike monster spawns%s" % (" — %s" % str(western_lake_monsters) if not western_lake_monsters.is_empty() else ""))
	_check(ordinary_zombies >= 2 and armed_zombies >= 2 and armored_zombies >= 2, "ordinary, armed and armored zombies roam Brudet's exterior")
	var ordinary_outside := 0
	var nearby_hostiles: Array[String] = []
	for enemy in ambient_enemies:
		var nearest_home := _nearest_home_distance(enemy.spawn_position, residents)
		if nearest_home < MIN_HOSTILE_HOME_DISTANCE:
			nearby_hostiles.append("%s (%dpx)" % [enemy.persistent_id, roundi(nearest_home)])
		elif enemy.enemy_id == "zombie":
			ordinary_outside += 1
	_check(not ambient_enemies.is_empty() and nearby_hostiles.is_empty(), "all ambient hostiles spawn at least %d px from resident homes%s" % [int(MIN_HOSTILE_HOME_DISTANCE), " — %s" % str(nearby_hostiles) if not nearby_hostiles.is_empty() else ""])
	_check(ordinary_outside >= 2, "at least two ordinary zombies remain outside settled streets")
	if armored_sample != null:
		var original_health := armored_sample.health
		armored_sample.take_damage(5)
		_check(original_health - armored_sample.health == 5 - int(armored_sample.definition["armor"]), "armored zombie reduces but does not ignore weapon damage")
		armored_sample.health = original_health
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
	if source is Dictionary:
		_check(int(source.get("width", 0)) > 112 and int(source.get("height", 0)) > 80 and Vector2(int(source["width"]), int(source["height"])) * 16.0 == river.tiled_loader.map_size, "Tiled and runtime agree on expanded Brudet dimensions")
	var bridges: Array[Vector2] = []
	var water: Dictionary = {}
	var buildings := 0
	var ponds := 0
	var southeast_pond_objects := 0
	var southeast_pond_object_id := -1
	var city_positions: Array[Vector2] = []
	var townhouse_positions: Array[Vector2] = []
	var wilderness_positions: Array[Vector2] = []
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
					city_positions.append(Vector2(float(obj["x"]), float(obj["y"])))
					townhouse_positions.append(Vector2(float(obj["x"]) + float(obj["width"]) * 0.5, float(obj["y"]) - 2.0))
				elif name in ["river_market", "river_library", "river_town_hall", "river_forge", "military_hq", "travel"]:
					city_positions.append(Vector2(float(obj["x"]), float(obj["y"])))
				elif name in ["olive_tree", "reed_cluster", "swamp_pool", "tree_marsh_willow"]:
					wilderness_positions.append(Vector2(float(obj["x"]), float(obj["y"])))
				elif name == "fishing_pond":
					ponds += 1
					var pond_door := Vector2(float(obj["x"]) + float(obj["width"]) * 0.5, float(obj["y"]) + 3.0)
					if SOUTHEAST_LAKE_AREA.has_point(pond_door):
						southeast_pond_objects += 1
						southeast_pond_object_id = int(obj["id"])
	_check(bridges.size() >= 2 and buildings >= 12, "two bridges and at least twelve townhouses define the city")
	var city_bounds := _check_compact_city_and_wilderness(river, city_positions, wilderness_positions, bridges)
	_check_resident_homes(river, residents, townhouse_positions, bridges, city_bounds)
	_check(ponds >= 2, "multiple fishing ponds are placed around Brudet")
	_check(not water.is_empty(), "river and lake have a water collision layer")
	var villagers_blocked_by_water := true
	for resident in residents:
		villagers_blocked_by_water = villagers_blocked_by_water and (resident.collision_mask & 16) != 0
	_check(river.tiled_loader._water_body != null and river.tiled_loader._water_body.collision_layer == 16 and (river.player.collision_mask & 16) != 0 and villagers_blocked_by_water, "water collision blocks player and civilian villagers")
	if not water.is_empty():
		var width := int(source["width"])
		var blocked := 0
		var western_lake_cells := 0
		var river_column := floori(bridges[0].x / 16.0) if not bridges.is_empty() else width / 2
		var tiles: Array = water["data"]
		for index in tiles.size():
			if int(tiles[index]) == 0:
				continue
			blocked += 1
			if index % width < river_column - 12:
				western_lake_cells += 1
			var sample := Vector2((index % width + 0.5) * 16.0, (index / width + 0.5) * 16.0)
			if blocked <= 20:
				_check(not river.tiled_loader.is_walkable_position(sample), "water cell %d blocks movement" % blocked)
		_check(blocked >= 200 and western_lake_cells >= 150, "main river and broad western lake contain substantial water terrain")
		await _check_river_navigation(river, enemies, bridges)
		_check_southeast_lake(river, enemies, water, width)
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

	_check_river_combat(river, enemies, residents)
	var services: Dictionary = {}
	var southeast_ponds: Array[WorldService] = []
	for node in river.tiled_loader._object_root.get_children():
		if node is WorldService:
			if not services.has(node.service_id):
				services[node.service_id] = node
			if node.service_id == "fishing_pond" and SOUTHEAST_LAKE_AREA.has_point(node.get_interaction_position()):
				southeast_ponds.append(node)
	_check(southeast_pond_objects == 1 and southeast_ponds.size() == 1, "one Tiled fishing pond becomes one usable service on the southeastern lake shore")
	if southeast_ponds.size() == 1:
		var lake_pond := southeast_ponds[0]
		_check(southeast_pond_object_id == 964 and lake_pond.get_interaction_position().distance_to(Vector2(2232, 1369)) < 1.0, "Tiled fishing pond ID 964 instantiates at the southeastern dry-shore entrance")
		var shore_approach := lake_pond.get_interaction_position() + Vector2(0, 12)
		var pond_route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, shore_approach)
		var water_nearby := false
		for x_offset in range(-48, 65, 16):
			for y_offset in range(-48, 65, 16):
				var nearby := shore_approach + Vector2(x_offset, y_offset)
				if SOUTHEAST_LAKE_AREA.has_point(nearby) and not river.tiled_loader.is_walkable_position(nearby) and river.tiled_loader.is_amphibious_walkable_position(nearby):
					water_nearby = true
		_check(river.tiled_loader.is_walkable_position(shore_approach) and not pond_route.is_empty() and pond_route[-1].distance_to(shore_approach) <= 16.0 and water_nearby, "southeastern pond has a reachable dry entrance within 64 px of lake water")
	for service_id in ["river_market", "river_library", "river_town_hall", "river_forge", "military_hq", "travel", "fishing_pond"]:
		_check(services.has(service_id), "%s is interactive" % service_id)
		if services.has(service_id):
			var service: WorldService = services[service_id]
			var approach: Vector2 = service.get_interaction_position() + Vector2(0, 12)
			var route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, approach)
			_check(not route.is_empty() and route[-1].distance_to(service.get_interaction_position()) < Player.INTERACTION_DISTANCE, "%s can be reached from arrival" % service_id)
	ui.open_service("river_forge", "Brudet Forge")
	for item_name in ["Iron Sword", "Iron Spear", "Iron Bow", "Iron Armor"]:
		_check(_find_button(ui.modal_content, "Buy another " + item_name) != null, "Brudet forge stocks %s" % item_name)
	for item_name in ["Wooden Sword", "Bronze Sword", "Wooden Spear", "Bronze Spear", "Wooden Bow", "Bronze Bow"]:
		_check(_find_button(ui.modal_content, "Buy another " + item_name) == null, "Brudet forge does not stock %s" % item_name)
	ui.open_service("river_library", "Brudet Library")
	_check(_has_text(ui.modal_content, "Blockovia") and _has_text(ui.modal_content, "fishing rod") and _has_text(ui.modal_content, "Military Headquarters"), "library offers Craft history and useful local advice")
	_check(_has_text(ui.modal_content, "Paprika and Brudet belong to the Cauliflower Confederation"), "library identifies Brudet and Paprika as Confederation planets")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	_check(_has_text(ui.modal_content, "stone bridges"), "town hall describes river-city landmarks")
	ui.open_service("military_hq", "Military Headquarters")
	_check(_find_button(ui.modal_content, "Join the Military") != null and _find_button(ui.modal_content, "Clear River Monsters") == null and _has_text(ui.modal_content, "regular ship") and _has_text(ui.modal_content, "depot"), "headquarters offers direct station enlistment while Town Hall keeps civilian missions")
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
		var pond: WorldService = southeast_ponds[0] if not southeast_ponds.is_empty() else services["fishing_pond"]
		river.player.global_position = pond.get_interaction_position() + Vector2(0, 12)
		river.player._update_nearest_interactable()
		_check(southeast_ponds.size() == 1 and river.player._current_interactable == pond, "E targets the new fishing service on the southeast lake shore")
		var interact_key := InputEventKey.new()
		interact_key.physical_keycode = KEY_E
		interact_key.pressed = true
		river.player._unhandled_input(interact_key)
		_check(southeast_ponds.size() == 1 and int(state.inventory.get("river_fish", 0)) == 1 and int(state.active_jobs.get("fishing_work", 0)) == 1, "E at the southeast lake catches fish and advances the market job")
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

	for team_job: String in ["brudet_monster_team", "brudet_bandit_team"]:
		ui.open_service("river_town_hall", "Brudet Town Hall")
		var job_name: String = String(GameData.job(team_job).get("name", team_job))
		var offer := _find_button(ui.modal_content, job_name)
		_check(offer != null and not offer.disabled, "%s is offered at Town Hall" % team_job)
		if offer == null:
			continue
		offer.pressed.emit()
		_check(state.team_job_id == team_job and state.active_jobs.has(team_job) and not state.squad_deployed, "Town Hall starts %s before deployment" % team_job)
		_check_job_direction(ui, team_job)
		ui.open_service("river_town_hall", "Brudet Town Hall")
		for other_job: String in ["brudet_monster_team", "brudet_bandit_team"]:
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
			var recruit := river.find_villager(recruit_id)
			if recruit != null:
				var member_health := int(state.squad_members[recruit_id]["health"])
				var civilian_health := recruit.civilian_health
				recruit._invulnerability = 0.0
				recruit.take_damage(1, recruit.global_position + Vector2(-20, 0))
				_check(int(state.squad_members[recruit_id]["health"]) < member_health and recruit.civilian_health == civilian_health and recruit._civilian_flee_time <= 0.0, "deployed recruit takes squad damage without civilian fear or fleeing")
		await get_tree().process_frame
		var expected_ids: Array = state.BRUDET_TEAM_IDS[team_job]
		var targets: Dictionary = {}
		for actor in river.actors_root.get_children():
			if actor is Enemy and expected_ids.has(actor.persistent_id) and not actor.is_queued_for_deletion():
				targets[actor.persistent_id] = actor
		_check(targets.size() == expected_ids.size(), "%s spawns its distinct marked targets" % team_job)
		var exterior_routes := true
		var exterior_locations := true
		var nearby_targets: Array[String] = []
		var target_kinds: Dictionary = {}
		var assigned_area: Rect2 = RiverScript.TEAM_SPAWN_AREAS.get(team_job, Rect2())
		for target in targets.values():
			var enemy := target as Enemy
			target_kinds[enemy.enemy_id] = true
			var route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, enemy.spawn_position)
			var hall: WorldService = services.get("river_town_hall")
			var hall_route := river.tiled_loader.get_walk_path(hall.get_interaction_position(), enemy.spawn_position) if hall != null else PackedVector2Array()
			exterior_routes = exterior_routes and not route.is_empty() and route[-1].distance_to(enemy.spawn_position) <= 16.0 and not hall_route.is_empty() and hall_route[-1].distance_to(enemy.spawn_position) <= 16.0
			exterior_locations = exterior_locations and assigned_area.has_point(enemy.spawn_position) and not city_bounds.grow(48.0).has_point(enemy.spawn_position)
			var nearest_home := _nearest_home_distance(enemy.spawn_position, residents)
			if nearest_home < MIN_HOSTILE_HOME_DISTANCE:
				nearby_targets.append("%s (%dpx)" % [enemy.persistent_id, roundi(nearest_home)])
		_check(exterior_routes, "%s exterior targets remain walkable from arrival and Town Hall" % team_job)
		_check(exterior_locations, "%s targets appear outside the city rather than beside Town Hall" % team_job)
		_check(nearby_targets.is_empty(), "%s targets spawn outside resident patrol areas%s" % [team_job, " — %s" % str(nearby_targets) if not nearby_targets.is_empty() else ""])
		if team_job == "brudet_bandit_team":
			var camp := river.actors_root.get_node_or_null("BrudetBanditCamp") as Node2D
			var camp_route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, camp.global_position) if camp != null else PackedVector2Array()
			_check(camp != null and camp.visible and camp.get_child_count() >= 2 and not camp_route.is_empty() and camp_route[-1].distance_to(camp.global_position) < 48.0, "exterior bandit camp has visible shelter and a walkable approach")
			_check(target_kinds.has("bandit_spear") and target_kinds.has("bandit_bow") and target_kinds.has("bandit_sword"), "exterior bandits use red spear, blue bow and purple sword combat roles")
			var bow_bandit: Enemy
			for target in targets.values():
				var bandit := target as Enemy
				_check(bandit._weapon_visual != null and bandit._weapon_visual.points.size() >= 2 and bandit._sprite.modulate == bandit._base_modulate(), "%s shows its color and weapon" % bandit.enemy_id)
				if bandit.enemy_id == "bandit_bow":
					bow_bandit = bandit
			if bow_bandit != null:
				var player_position := river.player.global_position
				river.player.global_position = bow_bandit.global_position + Vector2(36, 0)
				bow_bandit.state = Enemy.State.CHASE
				bow_bandit._attack_cooldown = 0.0
				bow_bandit._physics_process(1.0 / 60.0)
				_check(bow_bandit._is_ranged() and bow_bandit.state == Enemy.State.TELEGRAPH and bow_bandit._state_time > 0.3, "blue bow bandit warns before shooting")
				bow_bandit._physics_process(0.5)
				var bow_shots := 0
				for actor in river.actors_root.get_children():
					if actor is Projectile and not actor.is_queued_for_deletion():
						bow_shots += 1
						actor.queue_free()
				_check(bow_shots >= 1, "blue bow bandit fires a ranged projectile")
				bow_bandit.reset_after_player_defeat()
				river.player.global_position = player_position
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

	await _check_solo_hacker(river, ui, residents, city_bounds, services)
	await _check_legacy_hacker_team(river, ui, residents)
	var blocked_west_bank := _find_blocked_west_bank_tree(river, source, bridges)
	_check(blocked_west_bank != Vector2.ZERO, "a west-bank tree provides a blocked land save coordinate")
	if blocked_west_bank != Vector2.ZERO:
		state.player_position = blocked_west_bank
		_check(state.save_game() and state.load_game(), "blocked west-bank saved position loads")
		river.apply_loaded_state()
		var corrected_west_bank := river.player.global_position
		var west_bank_route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, corrected_west_bank)
		_check(river.tiled_loader.is_walkable_position(corrected_west_bank) and corrected_west_bank.distance_to(blocked_west_bank) <= 128.0 and corrected_west_bank.x < bridges[0].x - 48.0 and not west_bank_route.is_empty(), "blocked west-bank save reopens nearby rather than moving to the eastern arrival")
	var river_position := river.player.global_position
	_check(river.tiled_loader.is_walkable_position(river_position), "saved Brudet travel position remains walkable")
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

func _check_job_direction(ui: GameUI, job_id: String) -> void:
	var hint := String(GameData.job(job_id).get("location_hint", ""))
	_check(not hint.is_empty() and ui.notification_label.text.contains(hint), "%s acceptance notice names its destination" % job_id)
	ui.open_jobs()
	_check(not hint.is_empty() and _has_text(ui.modal_content, hint), "%s job list keeps its destination visible" % job_id)
	ui.close_modal()

func _check_solo_hacker(river: BrudetWorld, ui: GameUI, residents: Array[Villager], city_bounds: Rect2, services: Dictionary) -> void:
	var state := GameState
	var job_id := state.BRUDET_SOLO_HACKER_JOB
	var target_id := state.BRUDET_SOLO_HACKER_ID
	ui.open_service("river_town_hall", "Brudet Town Hall")
	_check(_find_button(ui.modal_content, "Teleporting Hacker Squad") == null and not state.accept_job("brudet_hacker_team"), "Town Hall no longer issues a new hacker squad contract")
	var offer := _find_button(ui.modal_content, String(GameData.job(job_id).get("name", job_id)))
	_check(offer != null and not offer.disabled and _find_button(ui.modal_content, "Recruit ") == null, "Town Hall offers the teleporting hacker as a solo job")
	if offer == null or offer.disabled:
		ui.close_modal()
		return
	offer.pressed.emit()
	_check(state.active_jobs.has(job_id) and state.team_job_id.is_empty() and state.squad_recruits.is_empty() and not state.squad_deployed, "solo hacker job starts without recruiting or deploying a squad")
	_check_job_direction(ui, job_id)
	var target: Enemy
	var solo_count := 0
	for actor in river.actors_root.get_children():
		if actor is Enemy and actor.persistent_id == target_id and not actor.is_queued_for_deletion():
			target = actor
			solo_count += 1
	_check(solo_count == 1 and target != null and target.enemy_id == "phase_hacker" and _has_text(target, "SOLO TARGET"), "solo job spawns one distinctly marked teleporting hacker")
	if target == null:
		state.abandon_job(job_id)
		return
	var arrival_route := river.tiled_loader.get_walk_path(state.BRUDET_ARRIVAL, target.spawn_position)
	var hall: WorldService = services.get("river_town_hall")
	var hall_route := river.tiled_loader.get_walk_path(hall.get_interaction_position(), target.spawn_position) if hall != null else PackedVector2Array()
	var assigned_area: Rect2 = RiverScript.TEAM_SPAWN_AREAS["brudet_hacker_team"]
	_check(assigned_area.has_point(target.spawn_position) and not city_bounds.grow(48.0).has_point(target.spawn_position) and _nearest_home_distance(target.spawn_position, residents) >= MIN_HOSTILE_HOME_DISTANCE, "solo hacker spawns outside town and at least 160 px from resident homes")
	_check(not arrival_route.is_empty() and arrival_route[-1].distance_to(target.spawn_position) <= 16.0 and not hall_route.is_empty() and hall_route[-1].distance_to(target.spawn_position) <= 16.0, "solo hacker remains reachable from arrival and Town Hall")
	river.capture_player_position()
	_check(state.save_game() and state.load_game(), "active solo hacker job saves and loads")
	river.apply_loaded_state()
	await get_tree().process_frame
	var restored: Enemy
	var restored_count := 0
	for actor in river.actors_root.get_children():
		if actor is Enemy and actor.persistent_id == target_id and not actor.is_queued_for_deletion():
			restored = actor
			restored_count += 1
	_check(state.active_jobs.has(job_id) and not state.active_job_ready(job_id) and not state.squad_deployed and restored_count == 1, "reload restores one undefeated solo hacker without a squad")
	if restored == null:
		state.abandon_job(job_id)
		return
	_check_phase_hacker(river, restored)
	restored.take_damage(999)
	_check(state.active_job_ready(job_id) and restored.is_queued_for_deletion() and not state.team_defeated_ids.has(target_id), "defeating the marked solo hacker completes only its solo job")
	await get_tree().process_frame
	river._sync_solo_hacker()
	var remaining := 0
	for actor in river.actors_root.get_children():
		if actor is Enemy and actor.persistent_id == target_id and not actor.is_queued_for_deletion():
			remaining += 1
	_check(remaining == 0, "completed solo target does not respawn before reward claim")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	var claim := _find_button(ui.modal_content, String(GameData.job(job_id).get("name", job_id)))
	_check(claim != null and claim.text.contains("CLAIM"), "Town Hall offers the completed solo hacker reward")
	var before_claim := state.gold
	if claim != null:
		claim.pressed.emit()
	_check(state.gold == before_claim + int(GameData.job(job_id)["reward"]) and not state.active_jobs.has(job_id) and state.team_job_id.is_empty(), "solo hacker reward pays without releasing or requiring a squad")
	ui.close_modal()

func _check_legacy_hacker_team(river: BrudetWorld, ui: GameUI, residents: Array[Villager]) -> void:
	var state := GameState
	var job_id := "brudet_hacker_team"
	var target_id := "brudet_team_hacker_0"
	_check(state.BRUDET_TEAM_IDS.has(job_id) and state.BRUDET_TEAM_IDS[job_id].has(target_id), "older active Brudet hacker squads retain their target ID")
	state.active_jobs[job_id] = 0
	state.team_job_id = job_id
	state.tracked_job_id = job_id
	state.job_changed.emit()
	var recruited := residents.size() >= 2 and river.recruit(residents[0].villager_id) and river.recruit(residents[1].villager_id)
	_check(recruited and state.deploy_squad(), "an existing hacker squad can still deploy with its saved mission")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	var legacy_offer := _find_button(ui.modal_content, "Teleporting Hacker Squad")
	var conflicting_solo := _find_button(ui.modal_content, "Teleporting Hacker Bounty")
	_check(legacy_offer != null and conflicting_solo != null and conflicting_solo.disabled, "Town Hall displays a legacy active squad and blocks a conflicting solo job")
	ui.close_modal()
	river.capture_player_position()
	_check(state.save_game() and state.load_game(), "legacy active hacker squad survives the current save format")
	river.apply_loaded_state()
	await get_tree().process_frame
	var target: Enemy
	for actor in river.actors_root.get_children():
		if actor is Enemy and actor.persistent_id == target_id and not actor.is_queued_for_deletion():
			target = actor
			break
	_check(state.team_job_id == job_id and state.squad_deployed and target != null and _has_text(target, "TEAM TARGET"), "loaded legacy squad keeps its marked hacker and both recruits")
	if target == null:
		return
	target.take_damage(999)
	_check(state.active_job_ready(job_id) and state.team_defeated_ids.has(target_id), "legacy hacker squad still records its marked target")
	ui.open_service("river_town_hall", "Brudet Town Hall")
	var claim := _find_button(ui.modal_content, "Teleporting Hacker Squad")
	_check(claim != null and claim.text.contains("CLAIM"), "legacy hacker squad retains its Town Hall claim button")
	if claim != null:
		claim.pressed.emit()
	_check(not state.active_jobs.has(job_id) and state.team_job_id.is_empty() and not state.squad_deployed, "claiming a legacy hacker squad reward clears its deployment")
	ui.close_modal()

func _check_phase_hacker(river: BrudetWorld, hacker: Enemy) -> void:
	var origin := hacker.global_position
	var player_position := river.player.global_position
	var nearby := Vector2.ZERO
	for offset in [Vector2(50, 0), Vector2(-50, 0), Vector2(0, 50), Vector2(0, -50)]:
		var candidate: Vector2 = origin + offset
		if river.tiled_loader.is_walkable_position(candidate) and not river.tiled_loader.get_walk_path(origin, candidate).is_empty():
			nearby = candidate
			break
	_check(nearby != Vector2.ZERO, "phase hacker has a walkable nearby player position")
	if nearby == Vector2.ZERO:
		return
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
	river.player.global_position = player_position

func _nearest_home_distance(position: Vector2, residents: Array[Villager]) -> float:
	var distance := INF
	for resident in residents:
		distance = minf(distance, position.distance_to(resident.home_position))
	return distance

func _check_resident_homes(river: BrudetWorld, residents: Array[Villager], townhouse_positions: Array[Vector2], bridges: Array[Vector2], eastern_city: Rect2) -> void:
	if bridges.is_empty() or townhouse_positions.is_empty():
		_check(false, "resident homes have a bridge and townhouse positions to compare")
		return
	var eastern_residents := 0
	var western_residents := 0
	var walkable_and_connected := true
	var homes_near_settlements := true
	for resident in residents:
		var home := resident.home_position
		var route := river.tiled_loader.get_walk_path(GameState.BRUDET_ARRIVAL, home)
		walkable_and_connected = walkable_and_connected and river.tiled_loader.is_walkable_position(home) and not route.is_empty() and route[-1].distance_to(home) <= 8.0
		if home.x > bridges[0].x + 32.0:
			eastern_residents += 1
			homes_near_settlements = homes_near_settlements and eastern_city.grow(128.0).has_point(home)
		elif home.x < bridges[0].x - 32.0:
			western_residents += 1
			var nearest_western_home := INF
			for house in townhouse_positions:
				if house.x < bridges[0].x - 32.0:
					nearest_western_home = minf(nearest_western_home, home.distance_to(house))
			homes_near_settlements = homes_near_settlements and nearest_western_home <= 330.0
	_check(eastern_residents >= 20 and western_residents >= 6 and eastern_residents + western_residents == residents.size(), "east-bank residents and west-bank fishing families have separate homes")
	_check(walkable_and_connected, "all thirty Brudet resident homes are dry, open and reachable from arrival")
	_check(homes_near_settlements, "residents remain within the east town or west fishing settlement rather than deep wilderness")

func _find_blocked_west_bank_tree(river: BrudetWorld, source: Variant, bridges: Array[Vector2]) -> Vector2:
	if not source is Dictionary or bridges.is_empty():
		return Vector2.ZERO
	var chosen := Vector2.ZERO
	var closest := INF
	for layer in source.get("layers", []):
		if String(layer.get("type", "")) != "objectgroup":
			continue
		for object in layer.get("objects", []):
			if String(object.get("name", "")) != "olive_tree":
				continue
			var candidate := Vector2(float(object["x"]) + float(object["width"]) * 0.52, float(object["y"]) - 5.0)
			if candidate.x >= bridges[0].x - 120.0 or river.tiled_loader.is_walkable_position(candidate) or river.tiled_loader.is_amphibious_walkable_position(candidate):
				continue
			var distance := candidate.distance_squared_to(bridges[0])
			if distance < closest:
				closest = distance
				chosen = candidate
	return chosen

func _check_compact_city_and_wilderness(river: BrudetWorld, city_positions: Array[Vector2], wilderness_positions: Array[Vector2], bridges: Array[Vector2]) -> Rect2:
	if city_positions.is_empty() or bridges.is_empty():
		_check(false, "city homes, services and bridges have map positions")
		return Rect2()
	var eastern_city: Array[Vector2] = []
	var western_hamlet := 0
	for position in city_positions:
		if position.x > bridges[0].x + 32.0:
			eastern_city.append(position)
		else:
			western_hamlet += 1
	_check(eastern_city.size() >= 20 and western_hamlet >= 4, "east-bank settlement and west-bank fishing hamlet both remain inhabited")
	if eastern_city.is_empty():
		return Rect2()
	var minimum := eastern_city[0]
	var maximum := eastern_city[0]
	for position in eastern_city:
		minimum.x = minf(minimum.x, position.x)
		minimum.y = minf(minimum.y, position.y)
		maximum.x = maxf(maximum.x, position.x)
		maximum.y = maxf(maximum.y, position.y)
	var city := Rect2(minimum, maximum - minimum)
	var map_size := river.tiled_loader.map_size
	var compact := city.size.x <= minf(850.0, map_size.x * 0.55) and city.size.y <= minf(850.0, map_size.y * 0.68) and city.size.x * city.size.y <= map_size.x * map_size.y * 0.30
	_check(compact, "east-bank homes and civic services form a compact town while the fishing hamlet stays west")
	var beyond_city := city.grow(48.0)
	var outside := 0
	var north := 0
	var south := 0
	var west := 0
	var east := 0
	for position in wilderness_positions:
		if beyond_city.has_point(position):
			continue
		outside += 1
		if position.y < beyond_city.position.y:
			north += 1
		if position.y > beyond_city.end.y:
			south += 1
		if position.x < beyond_city.position.x:
			west += 1
		if position.x > beyond_city.end.x:
			east += 1
	_check(wilderness_positions.size() >= 220 and outside >= wilderness_positions.size() * 0.65, "willows, olive trees, reeds and pools form dense wilderness mainly outside the eastern town")
	_check(north >= 8 and south >= 8 and west >= 8 and east >= 8, "nature surrounds the settlement on all four sides")
	return city

func _check_river_combat(river: BrudetWorld, enemies: Array[Enemy], residents: Array[Villager]) -> void:
	var serpent: Enemy
	for enemy in enemies:
		if enemy.enemy_id == "river_serpent":
			serpent = enemy
			break
	_check(serpent != null, "river serpent patrols Brudet's waterways")
	if serpent != null:
		var player_position := river.player.global_position
		river.player.global_position = serpent.global_position + Vector2(32, 0)
		serpent.state = Enemy.State.CHASE
		serpent._attack_cooldown = 0.0
		serpent._physics_process(1.0 / 60.0)
		_check(serpent.state == Enemy.State.TELEGRAPH and serpent._state_time > 0.4 and serpent._sprite.modulate == Color(1.0, 0.35, 0.35), "river serpent warns before its ranged attack")
		serpent._physics_process(0.6)
		var projectiles := 0
		for actor in river.actors_root.get_children():
			if actor is Projectile and not actor.is_queued_for_deletion():
				projectiles += 1
				_check((actor.collision_mask & 2) != 0 and (actor.collision_mask & 4) != 0 and (actor.collision_mask & 8) == 0, "serpent projectile can hit player and civilians but not other monsters")
				actor.queue_free()
		_check(projectiles >= 1 and serpent.state == Enemy.State.RECOVER, "serpent fires a projectile after the warning")
		serpent.reset_after_player_defeat()
		river.player.global_position = player_position
	if not residents.is_empty():
		var civilian := residents[0]
		var civilian_health := civilian.civilian_health
		var source := civilian.global_position + Vector2(-20, 0)
		civilian._invulnerability = 0.0
		civilian.take_damage(1, source)
		_check(civilian.civilian_health == civilian_health - 1 and civilian._civilian_flee_time > 0.0 and not civilian.squad_member, "civilian becomes frightened and flees after an attack")
		var flee_route := river.tiled_loader.get_walk_path(civilian.global_position, civilian._target)
		_check(not flee_route.is_empty() and flee_route[-1].distance_to(civilian._target) <= 8.0 and civilian._target.distance_to(source) > civilian.global_position.distance_to(source), "frightened civilian chooses a reachable position farther from the attack")
		civilian._invulnerability = 0.0
		civilian.take_damage(999, source)
		_check(civilian._civilian_recovery_time > 0.0 and civilian.global_position == civilian.home_position and not civilian.is_civilian_target(), "downed civilian returns home and cannot be attacked during recovery")
		civilian._physics_process(Villager.CIVILIAN_RECOVERY_SECONDS + 0.1)
		_check(civilian.civilian_health == Villager.CIVILIAN_MAX_HEALTH and civilian.is_civilian_target(), "civilian recovers fully at home")

func _check_southeast_lake(river: BrudetWorld, enemies: Array[Enemy], water: Dictionary, map_width: int) -> void:
	var tiles: Array = water["data"]
	var lake_cells := 0
	var first_cell := Vector2i(9999, 9999)
	var last_cell := Vector2i.ZERO
	for index in tiles.size():
		if int(tiles[index]) == 0:
			continue
		var cell := Vector2i(index % map_width, index / map_width)
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * 16.0
		if not SOUTHEAST_LAKE_AREA.has_point(center):
			continue
		lake_cells += 1
		first_cell.x = mini(first_cell.x, cell.x)
		first_cell.y = mini(first_cell.y, cell.y)
		last_cell.x = maxi(last_cell.x, cell.x)
		last_cell.y = maxi(last_cell.y, cell.y)
	_check(lake_cells >= 250 and first_cell.x >= 136 and first_cell.y >= 80 and last_cell.x - first_cell.x >= 16 and last_cell.y - first_cell.y >= 18, "a broad separate monster lake fills the new southeastern Brudet terrain")
	var west: Enemy
	var east: Enemy
	for enemy in enemies:
		if enemy.persistent_id == "finling_77":
			west = enemy
		elif enemy.persistent_id == "lake_maw_80":
			east = enemy
	_check(west != null and east != null and SOUTHEAST_LAKE_AREA.has_point(west.spawn_position) and SOUTHEAST_LAKE_AREA.has_point(east.spawn_position), "former western-lake monsters occupy both shores of the new southeastern lake")
	if west == null or east == null:
		return
	var loader := river.tiled_loader
	var west_shore := Vector2(2264, 1672)
	var east_shore := Vector2(2424, 1672)
	var approach := loader.get_walk_path(GameState.BRUDET_ARRIVAL, west_shore)
	_check(loader.is_walkable_position(west_shore) and not approach.is_empty() and approach[-1].distance_to(west_shore) <= 16.0 and not loader.is_walkable_position(west_shore + Vector2(16, 0)) and loader.is_amphibious_walkable_position(west_shore + Vector2(16, 0)), "new lake has a dry western shore reachable from Brudet and water immediately beyond it")
	_check(loader.is_walkable_position(east_shore) and not loader.is_walkable_position(east_shore + Vector2(-16, 0)) and loader.is_amphibious_walkable_position(east_shore + Vector2(-16, 0)), "new lake has a dry eastern shore beside amphibious water")
	var lake_route := loader.get_amphibious_path(west_shore, east_shore)
	var route_water_cells := 0
	for point in lake_route:
		if SOUTHEAST_LAKE_AREA.has_point(point) and not loader.is_walkable_position(point) and loader.is_amphibious_walkable_position(point):
			route_water_cells += 1
	_check(not lake_route.is_empty() and lake_route[-1].distance_to(east_shore) <= 16.0 and route_water_cells >= 8 and (west.collision_mask & 16) == 0, "southeastern monster route crosses at least eight lake-water cells between dry shores")
	if lake_route.is_empty():
		return
	var original_position := west.global_position
	west.set_physics_process(false)
	west.global_position = west_shore
	west._river_repath_timer = 0.0
	west._river_path.clear()
	var crossed: Dictionary = {}
	for tick in 110:
		west._move_toward(east_shore, float(west.definition.get("speed", 55.0)))
		if SOUTHEAST_LAKE_AREA.has_point(west.global_position) and not loader.is_walkable_position(west.global_position) and loader.is_amphibious_walkable_position(west.global_position):
			var water_cell := Vector2i(floori(west.global_position.x / 16.0), floori(west.global_position.y / 16.0))
			crossed[water_cell] = true
		if crossed.size() >= 3:
			break
	_check(crossed.size() >= 3, "a southeastern lake monster physically swims through several lake-water cells")
	west.global_position = original_position
	west._river_repath_timer = 0.0
	west._river_path.clear()
	west._choose_patrol()
	west.set_physics_process(true)

func _check_river_navigation(river: BrudetWorld, enemies: Array[Enemy], bridges: Array[Vector2]) -> void:
	if bridges.is_empty():
		_check(false, "river crossing needs at least one bridge landmark")
		return
	var loader := river.tiled_loader
	var crossing := PackedVector2Array()
	var land_route := PackedVector2Array()
	var western_bank := Vector2.ZERO
	var eastern_bank := Vector2.ZERO
	for row_offset in [-160.0, -120.0, -56.0, 120.0, 248.0, 504.0]:
		var west := bridges[0] + Vector2(-72, row_offset)
		var east := bridges[0] + Vector2(72, row_offset)
		if not loader.is_walkable_position(west) or not loader.is_walkable_position(east):
			continue
		var amphibious := loader.get_amphibious_path(west, east)
		var crosses_water := false
		for waypoint in amphibious:
			if not loader.is_walkable_position(waypoint) and loader.is_amphibious_walkable_position(waypoint):
				crosses_water = true
				break
		if crosses_water:
			western_bank = west
			eastern_bank = east
			crossing = amphibious
			land_route = loader.get_walk_path(west, east)
			break
	_check(not crossing.is_empty() and crossing[-1].distance_to(eastern_bank) <= 8.0, "amphibious navigation crosses the river away from a bridge")
	var land_stays_dry := not land_route.is_empty()
	for waypoint in land_route:
		land_stays_dry = land_stays_dry and loader.is_walkable_position(waypoint)
	_check(western_bank != Vector2.ZERO and land_stays_dry and (river.player.collision_mask & 16) != 0, "player navigation and collision keep the player out of river water")
	var fish_ignore_water := false
	for enemy in enemies:
		fish_ignore_water = fish_ignore_water or enemy._is_river_monster() and (enemy.collision_mask & 16) == 0 and enemy._river_navigation() == loader
	_check(fish_ignore_water, "river monsters use amphibious routes and do not collide with water")
	if crossing.is_empty() or enemies.is_empty():
		return
	var fish := enemies[0]
	var fish_position := fish.global_position
	fish.set_physics_process(false)
	fish.global_position = western_bank
	fish._river_repath_timer = 0.0
	fish._river_path.clear()
	var water_cells: Dictionary = {}
	for tick in 240:
		await get_tree().physics_frame
		fish._move_toward(eastern_bank, float(fish.definition.get("speed", 55.0)))
		if not loader.is_walkable_position(fish.global_position) and loader.is_amphibious_walkable_position(fish.global_position):
			var cell := Vector2i(floori(fish.global_position.x / 16.0), floori(fish.global_position.y / 16.0))
			water_cells[cell] = true
		if fish.global_position.distance_to(eastern_bank) <= 12.0:
			break
	_check(water_cells.size() >= 3 and fish.global_position.distance_to(eastern_bank) <= 12.0, "river monster physically crosses several water cells to the opposite bank")
	fish.global_position = fish_position
	fish._river_repath_timer = 0.0
	fish._river_path.clear()
	fish._choose_patrol()
	fish.set_physics_process(true)
	var player_position := river.player.global_position
	river.player.set_physics_process(false)
	river.player.global_position = western_bank
	await get_tree().physics_frame
	for tick in 80:
		await get_tree().physics_frame
		river.player.velocity = Vector2.RIGHT * Player.SPEED
		river.player.move_and_slide()
	_check(river.player.global_position.x < bridges[0].x - 48.0 and river.player.global_position.x > western_bank.x + 4.0 and loader.is_walkable_position(river.player.global_position), "player physically stops at the same water crossing")
	river.player.global_position = player_position
	river.player.velocity = Vector2.ZERO
	river.player.set_physics_process(true)

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
