extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene loads")
	if scene == null:
		get_tree().quit(1)
		return
	var game := scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().physics_frame
	var world := game.get_node_or_null("PaprikaWorld") as GameWorld
	_check(world != null, "world starts")
	if world == null:
		get_tree().quit(1)
		return
	_check(world.tiled_loader.map_size == Vector2(1664, 1920), "Paprika has a 104-by-120-tile map with a long central forest")
	_check(world.player != null and world.player.global_position.distance_to(Vector2(838, 1386)) < 18.0, "player starts below the southern village square")
	_check(world.player.get_node_or_null("Camera") is Camera2D, "player has a working camera")
	_check_visual_map(world)
	var villagers := 0
	var farmers: Array[Villager] = []
	var rabbits := 0
	var enemies := 0
	for actor in world.actors_root.get_children():
		if actor is Villager:
			villagers += 1
			if actor.is_farmer:
				farmers.append(actor)
		elif actor is Rabbit:
			rabbits += 1
		elif actor is Enemy:
			enemies += 1
	_check(villagers == 40, "15 southern and 25 northern villagers are active")
	_check(farmers.size() >= 4, "both settlements have common-field farmers")
	_check(rabbits >= 5, "the forest has at least five rabbits")
	_check(enemies >= 8, "the extended forest has wolves, monsters, a bandit and a hacker")
	_check_forest_rabbits(world)
	_check_forest_enemies(world)
	var farm_targets := world.tiled_loader.get_common_field_positions()
	var reachable_farmers := 0
	var routes_with_blocked_waypoints := 0
	var walking_farmer: Villager
	var walking_destination := Vector2.ZERO
	for farmer in farmers:
		if farm_targets.is_empty():
			break
		var destination: Vector2 = farm_targets[0]
		for point in farm_targets:
			if farmer.global_position.distance_squared_to(point) < farmer.global_position.distance_squared_to(destination):
				destination = point
		var route := world.tiled_loader.get_walk_path(farmer.global_position, destination)
		for waypoint in route:
			var cell := Vector2i(floori(waypoint.x / world.tiled_loader.tile_size.x), floori(waypoint.y / world.tiled_loader.tile_size.y))
			if world.tiled_loader._navigation.is_point_solid(cell):
				routes_with_blocked_waypoints += 1
				break
		if not route.is_empty() and route[-1].distance_to(destination) < 2.0:
			reachable_farmers += 1
			if walking_farmer == null:
				walking_farmer = farmer
				walking_destination = destination
	_check(reachable_farmers >= 2, "at least two farmers can route from the village to common fields")
	_check(routes_with_blocked_waypoints == 0, "farmer paths avoid static collision cells")
	if walking_farmer != null:
		walking_farmer._target = walking_destination
		walking_farmer._working_target = true
		walking_farmer._wait_time = 0.0
		walking_farmer._refresh_path()
		var initial_position := walking_farmer.global_position
		for tick in range(240):
			walking_farmer._physics_process(1.0 / 60.0)
		_check(walking_farmer.global_position.distance_to(initial_position) > 20.0, "farmer walks along the route instead of staying against a building")
		walking_farmer._animate_work(0.25, true)
		_check(walking_farmer._hoe.visible, "farmer uses a visible hoe while working")
		walking_farmer._animate_work(0.0, false)
	_check_villager_routines(world)

	var fields: Array[FieldPlot] = []
	var private_field: FieldPlot
	var services: Dictionary = {}
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is FieldPlot:
			if node.is_common:
				fields.append(node)
			else:
				private_field = node
		elif node is WorldService:
			services[node.service_id] = node
	_check(fields.size() >= 50, "many common plots are ready for field work")
	_check(private_field != null, "private field exists")
	var entrances_reachable := true
	_check(not services.has("iron_gear"), "no separate iron outfitter remains in Paprika")
	for service_id in ["food", "forge", "clothing", "work_office", "mercenary", "north_mercenary", "travel"]:
		_check(services.has(service_id), "%s can be visited" % service_id)
		if services.has(service_id):
			var door: Vector2 = services[service_id].get_interaction_position()
			var route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, door + Vector2(0, 9))
			if route.is_empty() or route[-1].distance_to(door) > Player.INTERACTION_DISTANCE:
				entrances_reachable = false
	_check(entrances_reachable, "original service entrances remain reachable from the village")
	_check_northern_village(world, services, fields)
	if not fields.is_empty() and private_field != null:
		var common_route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, fields[0].global_position)
		var private_route := world.tiled_loader.get_walk_path(Vector2(832, 320), private_field.global_position)
		_check(not common_route.is_empty() and common_route[-1].distance_to(fields[0].global_position) < 16.0, "public field stays reachable through its fence gates")
		_check(not private_route.is_empty() and private_route[-1].distance_to(private_field.global_position) < 16.0, "private garden stays reachable through its fence gates")
	var forest_entry := Vector2(832, 150)
	var north_route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, forest_entry)
	var return_route := world.tiled_loader.get_walk_path(forest_entry, Player.RESPAWN_POSITION)
	_check(not north_route.is_empty() and not return_route.is_empty(), "the dark northern forest has a route in and back to town")
	var state := GameState
	_check(state != null, "GameState autoload is present")
	if state == null:
		get_tree().quit(1)
		return

	var private_inventory := state.inventory.duplicate(true)
	private_field.interact(world.player)
	_check(state.inventory == private_inventory, "private plots cannot be harvested without permission")
	_check(state.accept_job("field_work") and state.accept_job("rabbit_catch") and state.accept_job("forest_patrol") and state.track_job("field_work"), "three work and mercenary jobs can run together")
	var north_field: FieldPlot
	var south_plots: Array[FieldPlot] = []
	for plot in fields:
		if plot.global_position.y < 352.0 and north_field == null:
			north_field = plot
		elif plot.global_position.y >= 1120.0 and south_plots.size() < 4:
			south_plots.append(plot)
	if north_field != null:
		north_field.interact(world.player)
	_check(north_field != null and int(state.active_jobs["field_work"]) == 1, "a northern common crop advances the field job")
	for plot in south_plots:
		plot.interact(world.player)
	_check(int(state.active_jobs["field_work"]) == 5 and state.active_job_ready("field_work"), "harvests in both villages finish the field job")
	_check(int(state.active_jobs["rabbit_catch"]) == 0 and int(state.active_jobs["forest_patrol"]) == 0, "field work does not advance unrelated missions")
	if north_field != null:
		_check(not north_field.get_interaction_text().begins_with("Harvest"), "harvested northern crop shows regrowth")
	_check(state.claim_job("work_office", "field_work") and state.gold == 10, "work office pays exactly 10 gold")
	_check(state.active_jobs.has("rabbit_catch") and state.active_jobs.has("forest_patrol"), "field reward does not remove other missions")
	_check(not state.claim_job("work_office", "field_work") and state.gold == 10, "field job cannot pay twice")
	state._process(120.0)
	if north_field != null:
		north_field._process(0.0)
		_check(state.field_is_ready(north_field.field_id), "northern field becomes ready after 120 simulated seconds")

	var ui := game.get_node_or_null("GameUI") as GameUI
	_check(ui != null, "dynamic HUD starts")
	if ui != null:
		ui.open_service("travel", "Paprika Travel Agency")
		_check(ui.modal_overlay.visible and state.gold == 10, "travel agency opens without charging")
		ui.close_modal()
		ui.open_service("forge", "Forge")
		_check(ui.modal_overlay.visible and state.gold == 10, "forge opens with the current gold balance")
		ui.close_modal()
		ui.open_service("work_office", "Village Work Office")
		var field_button := _find_button(ui.modal_content, "Help in the Common Fields")
		_check(field_button != null, "work board shows repeatable jobs alongside active missions")
		if field_button != null:
			field_button.pressed.emit()
			_check(state.active_jobs.size() == 3 and int(state.active_jobs["field_work"]) == 0, "job board accepts new work without dropping other missions")
		ui.close_modal()
		ui.open_jobs()
		var track_button := _find_button(ui.modal_content, "Track Clear Forest Monsters")
		_check(track_button != null, "job list lets the player select which mission to track")
		if track_button != null:
			track_button.pressed.emit()
			_check(state.tracked_job_id == "forest_patrol" and ui.job_label.text.contains("Clear Forest Monsters"), "tracked job changes on the HUD")
		ui.close_modal()

	var food_service: WorldService = services.get("food")
	if ui != null and food_service != null:
		var door := food_service.get_interaction_position()
		var near_private_field := door + Vector2(-6, -11)
		var closest_private_distance := 1000.0
		for candidate in get_tree().get_nodes_in_group("interactable"):
			if candidate is FieldPlot and not candidate.is_common:
				closest_private_distance = minf(closest_private_distance, near_private_field.distance_to(candidate.global_position))
		_check(closest_private_distance > Player.INTERACTION_DISTANCE, "private crops no longer overlap the food shop entrance")
		var overlapping_plot := FieldPlot.new()
		world.tiled_loader.add_child(overlapping_plot)
		overlapping_plot.configure("test:private", "potato", false, null, null, null)
		overlapping_plot.global_position = door + Vector2(-6, -20)
		_check(near_private_field.distance_to(overlapping_plot.global_position) < near_private_field.distance_to(door), "test crop is closer than the shop entrance")
		world.player.global_position = near_private_field
		world.player._update_nearest_interactable()
		_check(world.player._current_interactable == food_service, "food shop takes priority if a private crop is placed nearby")
		var use_key := InputEventAction.new()
		use_key.action = "interact"
		use_key.pressed = true
		world.player._unhandled_input(use_key)
		_check(ui.modal_overlay.visible and ui._active_service_id == "food", "pressing E at the shop entrance opens the food menu")
		ui.close_modal()
		overlapping_plot.free()
		world.player.global_position = Player.RESPAWN_POSITION

	var forest_rabbits: Array[Rabbit] = []
	for actor in world.actors_root.get_children():
		if actor is Rabbit:
			forest_rabbits.append(actor)
	_check(forest_rabbits.size() >= 6, "enough rabbits for both hunting and the catch job")
	if forest_rabbits.size() >= 6:
		var prey := forest_rabbits[0]
		_check(prey.collision_layer == 32 and (prey.collision_mask & 16) != 0, "rabbit has a distinct projectile hit layer and cannot cross water")
		world.player.global_position = prey.global_position + Vector2(-16, 0)
		world.player.facing = Vector2.RIGHT
		_check(world.player._nearest_damageable(24) == prey, "a nearby rabbit can be targeted with a melee weapon")
		world.player._attack()
		_check(int(state.inventory.get("rabbit_meat", 0)) == 1 and int(state.active_jobs["rabbit_catch"]) == 0, "hunting gives meat without counting as catching")
		for index in range(1, 6):
			forest_rabbits[index].interact(world.player)
		_check(int(state.active_jobs["rabbit_catch"]) == 5 and state.active_job_ready("rabbit_catch"), "five nonlethal catches complete rabbit job")
		if ui != null:
			ui.open_service("work_office", "Village Work Office")
			var rabbit_claim := _find_button(ui.modal_content, "Catch Five Rabbits")
			_check(rabbit_claim != null and rabbit_claim.text.contains("CLAIM"), "work board shows a claim for the completed untracked rabbit job")
			if rabbit_claim != null:
				rabbit_claim.pressed.emit()
			ui.close_modal()
		_check(not state.active_jobs.has("rabbit_catch") and state.gold == 35, "work board pays the untracked rabbit job without changing tracked mission")
		_check(state.active_jobs.has("forest_patrol") and int(state.active_jobs["forest_patrol"]) == 0 and state.tracked_job_id == "forest_patrol", "mercenary mission stays tracked after claiming village jobs")
		prey._physics_process(Rabbit.HUNT_RESPAWN_SECONDS + 0.1)
		_check(prey.visible and prey.is_in_group("damageable") and prey.is_in_group("interactable"), "hunted rabbit respawns huntable and catchable")
		world.player.global_position = prey.global_position + Vector2(-40, 0)
		world.player._update_nearest_interactable()
		_check(world.player._current_interactable == prey, "rabbit catch prompt is available from forty pixels")
		_check(state.sell_item("rabbit_meat") and state.gold == 42, "rabbit meat can be sold at the food shop")
		if ui != null:
			ui.open_service("forge", "Forge")
			var sword_button := _find_button(ui.modal_content, "Buy another Wooden Sword")
			_check(sword_button != null, "forge offers a wooden sword")
			if sword_button != null:
				sword_button.pressed.emit()
				var equip_sword := _find_button(ui.modal_content, "Equip Wooden Sword")
				_check(equip_sword != null and not equip_sword.disabled, "owned sword can be equipped separately from buying it")
				if equip_sword != null:
					equip_sword.pressed.emit()
				_check(state.gold == 22 and state.equipment["weapon"] == "wood_sword", "forge purchase and equip retain their prices")
			ui.open_service("clothing", "Clothing & Armor")
			var tunic_button := _find_button(ui.modal_content, "Buy another Red Villager Tunic")
			_check(tunic_button != null, "clothing shop offers medieval outfits")
			if tunic_button != null:
				tunic_button.pressed.emit()
				var equip_tunic := _find_button(ui.modal_content, "Equip Red Villager Tunic")
				_check(equip_tunic != null and not equip_tunic.disabled, "purchased outfit can be equipped")
				if equip_tunic != null:
					equip_tunic.pressed.emit()
				_check(state.gold == 4 and state.equipment["clothing"] == "red_tunic", "clothing purchase and equip retain their prices")
				_check(world.player._sprite.texture.resource_path.ends_with("player_red.png"), "the outfit changes the visible player sprite")
			ui.close_modal()

	if ui != null:
		_check_northern_shops(ui, world)

	var wolf: Enemy
	for actor in world.actors_root.get_children():
		if actor is Enemy and actor.enemy_id == "wolf":
			wolf = actor
			break
	_check(wolf != null, "wolf spawns in forest")
	var gold_before := state.gold
	if wolf != null:
		wolf.take_damage(999)
		_check(state.gold > gold_before, "defeating a forest wolf awards gold")
		_check(not wolf.visible and not wolf.is_in_group("damageable"), "defeated wolf leaves combat until respawn")
		wolf._physics_process(Enemy.RESPAWN_SECONDS + 0.1)
		_check(wolf.visible and wolf.health == wolf.max_health and wolf.is_in_group("damageable"), "repeatable forest enemies return after a cooldown")

	var hacker: Enemy
	for actor in world.actors_root.get_children():
		if actor is Enemy and actor.enemy_id == "hacker":
			hacker = actor
			break
	_check(hacker != null, "the level-five hacker is in the forest")
	if hacker != null:
		hacker.global_position = world.player.global_position + Vector2(35, 0)
		var hostile := Projectile.new()
		world.actors_root.add_child(hostile)
		hostile.configure(world.player.global_position + Vector2(12, 0), Vector2.LEFT, 18, 130.0, 180.0, false)
		state.health = 4
		world.player._invulnerability = 0.0
		world.player.take_damage(20, hacker.global_position)
		_check(state.health == state.max_health and world.player.global_position == Player.RESPAWN_POSITION, "player wakes in the village with full health")
		_check(hacker.global_position == hacker.spawn_position and hacker.state == Enemy.State.IDLE, "hacker returns to its forest spawn after player defeat")
		_check(hostile.is_queued_for_deletion(), "hostile projectiles do not follow a respawning player")

	# The save destination is isolated by XDG_DATA_HOME in the test invocation.
	var test_home := OS.get_environment("XDG_DATA_HOME")
	var save_path: String = ProjectSettings.globalize_path(state.SAVE_PATH)
	if test_home.is_empty() or not save_path.begins_with(test_home + "/"):
		_check(false, "set XDG_DATA_HOME to a temporary directory for the save test")
	else:
		state.player_position = Vector2(789, 615)
		var saved_jobs: Dictionary = state.active_jobs.duplicate(true)
		var saved_tracking: String = state.tracked_job_id
		_check(state.save_game(), "save game succeeds")
		state.gold = 1
		state.inventory.clear()
		state.active_jobs.clear()
		state.tracked_job_id = ""
		state.player_position = Vector2.ZERO
		_check(state.load_game(), "saved game loads")
		_check(state.gold == gold_before + 4 and state.player_position == Vector2(789, 615), "gold and position survive reload")
		_check(state.active_jobs == saved_jobs and state.tracked_job_id == saved_tracking and state.active_jobs.size() == 2, "two active missions and the tracked mission survive reload")
		_check(int(state.inventory.get("potato", 0)) + int(state.inventory.get("carrot", 0)) + int(state.inventory.get("tomato", 0)) + int(state.inventory.get("grape", 0)) >= 5, "harvested inventory survives reload")

	await _check_squad_mission(world)
	var debug_key := InputEventKey.new()
	debug_key.physical_keycode = KEY_F6
	debug_key.pressed = true
	var before_debug := state.gold
	game._unhandled_input(debug_key)
	_check(InputMap.has_action("debug_gold") == OS.is_debug_build(), "testing-gold shortcut exists only in debug builds")
	_check(state.gold == before_debug + (100_000 if OS.is_debug_build() else 0), "F6 grants testing gold only in debug builds")
	print("Paprika world: %d checks, %d failures" % [checks, failures])
	remove_child(game)
	game.free()
	get_tree().quit(0 if failures == 0 else 1)

func _check_forest_rabbits(world: GameWorld) -> void:
	var rabbits_by_id: Dictionary = {}
	for actor in world.actors_root.get_children():
		if actor is Rabbit:
			rabbits_by_id[actor.rabbit_id] = actor
	var added_ids := ["rabbit_509", "rabbit_510", "rabbit_511", "rabbit_512", "rabbit_513"]
	var source = JSON.parse_string(FileAccess.get_file_as_string(GameWorld.MAP_PATH))
	var path_tiles: Array = []
	if source is Dictionary:
		for layer in source["layers"]:
			if String(layer.get("name", "")) == "Paths and Plaza":
				path_tiles = layer["data"]
				break
	var reachable := true
	var placed_off_road := true
	for rabbit_id in added_ids:
		var rabbit: Rabbit = rabbits_by_id.get(rabbit_id)
		_check(rabbit != null and rabbit.visible, "%s keeps its stable mid-forest spawn" % rabbit_id)
		if rabbit == null:
			reachable = false
			placed_off_road = false
			continue
		var spawn := rabbit.home_position
		var cell := Vector2i(floori(spawn.x / 16.0), floori(spawn.y / 16.0))
		var tile_index := cell.y * 104 + cell.x
		var on_pavement := tile_index >= 0 and tile_index < path_tiles.size() and int(path_tiles[tile_index]) != 0
		placed_off_road = placed_off_road and spawn.y >= 600.0 and spawn.y < 1100.0 and not on_pavement
		var road_start := Vector2(832.0, floorf(spawn.y / 16.0) * 16.0 + 8.0)
		var route := world.tiled_loader.get_walk_path(road_start, spawn)
		reachable = reachable and world.tiled_loader.is_walkable_position(spawn) and world.tiled_loader.is_walkable_position(road_start) and not route.is_empty() and route[-1].distance_to(spawn) <= 16.0
	_check(not path_tiles.is_empty() and placed_off_road, "five additional rabbits live on unpaved tiles in the middle of the forest")
	_check(reachable, "every added rabbit has a dry, walkable route from the forest road")

func _check_forest_enemies(world: GameWorld) -> void:
	var road_ids: Dictionary = {}
	var road_monsters := 0
	var off_road_monsters := 0
	var ambient_bandit: Enemy
	for actor in world.actors_root.get_children():
		if not actor is Enemy or not actor.visible:
			continue
		var enemy := actor as Enemy
		if enemy.persistent_id == "bandit_232":
			ambient_bandit = enemy
		var forest := enemy.spawn_position.y >= 400.0 and enemy.spawn_position.y < 1100.0
		if not forest:
			continue
		var beside_road := absf(enemy.spawn_position.x - 832.0) <= 220.0
		if enemy.enemy_id in ["zombie", "zombie_bear"] and beside_road:
			road_monsters += 1
			road_ids[enemy.persistent_id] = true
		if enemy.enemy_id in ["wolf", "zombie", "zombie_bear"] and absf(enemy.spawn_position.x - 832.0) >= 260.0:
			off_road_monsters += 1
	_check(road_monsters == GameState.ROAD_IDS.size() and road_ids.size() == GameState.ROAD_IDS.size(), "the road has exactly three distinct marked monsters, without extra zombie spawns")
	for target_id in GameState.ROAD_IDS:
		_check(road_ids.has(target_id), "road target %s is visible beside the road" % target_id)
	_check(off_road_monsters >= 4, "additional wolves and zombies inhabit the forest away from the road")
	_check(ambient_bandit != null and ambient_bandit.enemy_id in ["bandit_spear", "bandit_bow", "bandit_sword"] and ambient_bandit._weapon_visual != null and ambient_bandit._weapon_visual.points.size() >= 2 and int(ambient_bandit.definition.get("armor", 0)) > 0, "original Paprika bandit keeps its stable ID and now wears armor and carries a role-specific weapon")
	if ambient_bandit != null:
		var spawn := ambient_bandit.spawn_position
		var south_route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, spawn)
		_check(spawn.y > 800.0 and spawn.distance_to(Player.RESPAWN_POSITION) < 650.0 and not south_route.is_empty() and south_route[-1].distance_to(spawn) <= 16.0, "southern bandit bounty has a walkable approach near the first village")
		var source = JSON.parse_string(FileAccess.get_file_as_string(GameWorld.MAP_PATH))
		var path_tiles: Array = []
		var map_width := 0
		if source is Dictionary:
			map_width = int(source.get("width", 0))
			for layer in source["layers"]:
				if String(layer.get("name", "")) == "Paths and Plaza":
					path_tiles = layer["data"]
					break
		var cell := Vector2i(floori(spawn.x / 16.0), floori(spawn.y / 16.0))
		var tile_index := cell.y * map_width + cell.x
		_check(map_width > 0 and tile_index >= 0 and tile_index < path_tiles.size() and int(path_tiles[tile_index]) == 0 and world.tiled_loader.is_walkable_position(spawn), "southern bandit stands on a walkable unpaved forest tile")

func _check_northern_shops(ui: GameUI, world: GameWorld) -> void:
	var state := GameState
	state.add_gold(2000)
	ui.open_service("north_food", "Northern Food Shop")
	for name in ["Rye Bread", "Berry Pie", "Smoked Fish"]:
		_check(_find_button(ui.modal_content, name) != null, "northern food shop stocks %s" % name)
	var bread := _find_button(ui.modal_content, "Rye Bread")
	if bread != null:
		bread.pressed.emit()
		_check(int(state.inventory.get("rye_bread", 0)) == 1, "northern food purchase enters shared inventory")
	ui.open_service("forge", "Forge")
	for name in ["Wooden Sword", "Wooden Spear", "Wooden Bow", "Wooden Armor"]:
		_check(_find_button(ui.modal_content, "Buy another " + name) != null, "southern forge stocks %s" % name)
	for name in ["Bronze Sword", "Iron Sword", "Iron Spear", "Iron Bow", "Iron Armor"]:
		_check(_find_button(ui.modal_content, "Buy another " + name) == null, "southern forge does not stock %s" % name)
	ui.open_service("clothing", "Clothing & Armor")
	_check(_find_button(ui.modal_content, "Iron Armor") == null, "southern clothing shop does not sell iron armor")
	ui.open_service("north_clothing", "Northern Clothing")
	var cloth := _find_button(ui.modal_content, "Buy Purple Cloth")
	var tunic := _find_button(ui.modal_content, "Buy another Purple Villager Tunic")
	_check(cloth != null and tunic != null, "northern clothing shop offers cloth trading and a purple tunic")
	if cloth != null:
		cloth.pressed.emit()
		_check(int(state.inventory.get("purple_cloth", 0)) == 1, "purple cloth enters inventory as trade goods")
	if tunic != null:
		tunic = _find_button(ui.modal_content, "Buy another Purple Villager Tunic")
		tunic.pressed.emit()
		var equip_tunic := _find_button(ui.modal_content, "Equip Purple Villager Tunic")
		if equip_tunic != null:
			equip_tunic.pressed.emit()
		_check(state.equipment["clothing"] == "purple_tunic" and world.player._sprite.texture.resource_path.ends_with("northern_village/player_purple.png"), "purple tunic changes player appearance")
	ui.open_service("north_forge", "Northern Forge")
	for name in ["Bronze Sword", "Bronze Spear", "Bronze Bow", "Bronze Armor"]:
		_check(_find_button(ui.modal_content, "Buy another " + name) != null, "northern forge stocks %s" % name)
	for name in ["Wooden Sword", "Iron Sword", "Iron Spear", "Iron Bow", "Iron Armor"]:
		_check(_find_button(ui.modal_content, "Buy another " + name) == null, "northern forge does not stock %s" % name)
	var sword := _find_button(ui.modal_content, "Buy another Bronze Sword")
	if sword != null:
		sword.pressed.emit()
		sword = _find_button(ui.modal_content, "Buy another Bronze Sword")
		sword.pressed.emit()
		_check(int(state.inventory.get("bronze_sword", 0)) == 2, "buy-another action stocks two independent bronze swords")
	ui.close_modal()

func _check_northern_village(world: GameWorld, services: Dictionary, fields: Array[FieldPlot]) -> void:
	var north_services := ["north_food", "north_forge", "north_clothing", "north_mercenary"]
	var original_position := world.player.global_position
	var ui := get_tree().get_first_node_in_group("game_ui") as GameUI
	for service_id in north_services:
		_check(services.has(service_id), "%s opens in the northern village" % service_id)
		if not services.has(service_id):
			continue
		var door: Vector2 = services[service_id].get_interaction_position()
		var route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, door + Vector2(0, 18))
		_check(not route.is_empty() and route[-1].distance_to(door) < Player.INTERACTION_DISTANCE, "%s has a reachable entrance" % service_id)
		if not route.is_empty() and route[-1].distance_to(door) < Player.INTERACTION_DISTANCE:
			world.player.global_position = route[-1]
			world.player._update_nearest_interactable()
			_check(world.player._current_interactable == services[service_id], "%s door selects its own service" % service_id)
			if ui != null and world.player._current_interactable == services[service_id]:
				var use_key := InputEventAction.new()
				use_key.action = "interact"
				use_key.pressed = true
				world.player._unhandled_input(use_key)
				_check(ui.modal_overlay.visible and ui._active_service_id == service_id, "E opens the %s menu" % service_id)
				ui.close_modal()
	world.player.global_position = original_position
	_check(services.has("travel") and services["travel"].global_position.y < 450.0, "the sole travel agency has moved north")
	var north_fields := 0
	var south_fields := 0
	for field in fields:
		if field.global_position.y < 450.0:
			north_fields += 1
		else:
			south_fields += 1
	_check(north_fields >= 10 and south_fields >= 50, "both settlements contain harvestable common plots")
	var north_square := Vector2(790, 286)
	var south_square := Vector2(810, 1372)
	var between_villages := world.tiled_loader.get_walk_path(south_square, north_square)
	var back_to_south := world.tiled_loader.get_walk_path(north_square, south_square)
	_check(south_square.distance_to(north_square) > 1000.0, "the settlements are separated by more than a thousand pixels")
	_check(not between_villages.is_empty() and between_villages[-1].distance_to(north_square) <= 8.0, "the southern square has a route ending at the northern square")
	_check(not back_to_south.is_empty() and back_to_south[-1].distance_to(south_square) <= 8.0, "the northern square has a return route ending at the southern square")
	var gate := Vector2(840, 184)
	var north_crop := Vector2(872, 184)
	var gate_route := world.tiled_loader.get_walk_path(Vector2(832, 150), gate)
	var crop_route := world.tiled_loader.get_walk_path(gate, north_crop)
	_check(not gate_route.is_empty() and gate_route[-1].distance_to(gate) <= 8.0 and not crop_route.is_empty() and crop_route[-1].distance_to(north_crop) <= 8.0, "northern common-field gate connects the road and planted rows")
	var north_homes_walkable := true
	var north_homes_connected := true
	var distinct_north_homes: Dictionary = {}
	for actor in world.actors_root.get_children():
		if actor is Villager and actor.home_position.y < 450.0:
			distinct_north_homes[actor.home_position] = true
			north_homes_walkable = north_homes_walkable and world.tiled_loader.is_walkable_position(actor.home_position)
			var route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, actor.home_position)
			north_homes_connected = north_homes_connected and not route.is_empty() and route[-1].distance_to(actor.home_position) <= 8.0
	_check(north_homes_walkable and north_homes_connected and distinct_north_homes.size() == 25, "all 25 northern homes are distinct, open and connected to the southern village")

func _check_villager_routines(world: GameWorld) -> void:
	var role_counts := {"farmer": 0, "market": 0, "craft": 0, "runner": 0, "neighbor": 0}
	var stable_ids: Dictionary = {}
	var reachable_services: Dictionary = {}
	var reachable_stops := true
	var selected_routes := true
	var neighbor: Villager
	var runner: Villager
	var farmer: Villager
	var southern_count := 0
	var northern_count := 0
	var northern_farmers := 0
	var southern_farmers := 0
	var regions_local := true
	for actor in world.actors_root.get_children():
		if not actor is Villager:
			continue
		var resident := actor as Villager
		stable_ids[resident.villager_id] = true
		var northern := resident.home_position.y < 450.0
		if northern:
			northern_count += 1
			if resident.is_farmer:
				northern_farmers += 1
		else:
			southern_count += 1
			if resident.is_farmer:
				southern_farmers += 1
		for field in resident._field_points:
			if (field.y < 450.0) != northern:
				regions_local = false
		role_counts[resident.routine_role] = int(role_counts.get(resident.routine_role, 0)) + 1
		if resident.routine_role == "neighbor" and neighbor == null:
			neighbor = resident
		if resident.routine_role == "runner" and runner == null:
			runner = resident
		if resident.is_farmer and farmer == null:
			farmer = resident
		var available_stops := 0
		for stop in resident.routine_stops:
			var position: Vector2 = stop["position"]
			var route := world.tiled_loader.get_walk_path(resident.home_position, position)
			if not route.is_empty() and route[-1].distance_to(position) <= 8.0:
				available_stops += 1
				if String(stop["kind"]) not in ["home", "square"]:
					reachable_services["%s:%s" % [resident.routine_role, stop["kind"]]] = true
		if available_stops < 2:
			reachable_stops = false
		var chosen := world.tiled_loader.get_walk_path(resident.global_position, resident._target)
		if chosen.is_empty() or chosen[-1].distance_to(resident._target) > 8.0:
			selected_routes = false
	_check(stable_ids.size() == 40 and role_counts["farmer"] >= 4, "villagers keep 40 unique stable IDs and multiple farmers")
	_check(southern_count == 15 and northern_count == 25, "southern and northern resident homes have the requested 15/25 split")
	_check(northern_farmers >= 1 and southern_farmers >= 1 and regions_local, "farmers use common fields in their own settlement")
	var original_ids_present := true
	for index in range(26):
		original_ids_present = original_ids_present and stable_ids.has("resident_%02d" % index)
	_check(original_ids_present, "existing resident IDs survive and northern residents extend through resident_25")
	var original_map_ids := 0
	for object_id in range(37, 51):
		for stable_id in stable_ids:
			if String(stable_id).ends_with("_%d" % object_id):
				original_map_ids += 1
	_check(original_map_ids == 14, "all 14 original Tiled villager identities remain recruitable")
	_check(role_counts["market"] >= 2 and role_counts["craft"] >= 2 and role_counts["runner"] >= 2 and role_counts["neighbor"] >= 2, "four civilian occupations are represented")
	_check(reachable_stops and selected_routes, "resident destinations and selected routes are reachable")
	var service_kinds := ["market:food", "market:clothing", "craft:forge", "craft:work", "runner:work", "runner:travel", "neighbor:food"]
	_check(service_kinds.all(func(key: String) -> bool: return reachable_services.has(key)), "civilian errands can reach each assigned service")
	if neighbor != null:
		var original_stops: Array[Dictionary] = neighbor.routine_stops.duplicate(true)
		neighbor.routine_stops = [{"kind": "blocked", "position": Vector2(-100, -100), "wait": 1.0},
			{"kind": "square", "position": Vector2(810, 1372), "wait": 2.0}]
		neighbor._routine_index = 0
		neighbor._choose_next_target()
		_check(neighbor.activity_kind == "square" and neighbor._target == Vector2(810, 1372), "blocked destination is skipped for a reachable square stop")
		neighbor._wait_time = 2.0
		neighbor._animate_activity(0.25, true)
		_check(neighbor._activity_prop.visible and not neighbor._hoe.visible, "nonfarmer has a visible idle gesture without a hoe")
		neighbor.suspend_routine()
		_check(neighbor._was_squad_member and not neighbor._activity_prop.visible, "deployment immediately suspends civilian gestures")
		neighbor.squad_member = true
		neighbor.squad_member = false
		neighbor.resume_routine()
		_check(not neighbor._was_squad_member and neighbor._can_reach(neighbor._target), "immediate release resumes a reachable routine")
		neighbor.configure_routine("neighbor", original_stops)
	if runner != null:
		var original_position := runner.global_position
		var errand: Vector2 = runner.routine_stops[1]["position"]
		runner._target = errand
		runner._wait_time = 0.0
		runner._refresh_path()
		for tick in range(240):
			runner._physics_process(1.0 / 60.0)
		_check(runner.global_position.distance_to(original_position) > 20.0, "runner walks an errand instead of staying near home")
		runner.global_position = original_position
		runner.configure_routine("runner", runner.routine_stops.duplicate(true))
	if farmer != null:
		farmer._routine_index = 3
		farmer._choose_next_target()
		_check(not farmer._working_target and farmer.activity_kind in ["home", "square"], "farmers take breaks between field visits")
		farmer._routine_index = 0
		farmer._choose_next_target()
		_check(farmer._working_target and farmer.activity_kind == "field", "farmers return to common field work")

func _check_road_mission(world: GameWorld, ui: GameUI) -> void:
	var state := GameState
	ui.open_service("mercenary", "Mercenary Center")
	var road_button := _find_button(ui.modal_content, "Clear the Forest Road")
	_check(road_button != null and not road_button.disabled, "southern mercenary center offers the road squad mission")
	_check(_find_button(ui.modal_content, "Clear the Bandit Camp") == null, "southern board does not issue the northern camp mission")
	if road_button == null:
		ui.close_modal()
		return
	road_button.pressed.emit()
	_check(state.team_job_id == state.ROAD_JOB and state.active_jobs.has(state.ROAD_JOB), "road mission starts at the southern mercenary center")
	_check_job_direction(ui, state.ROAD_JOB)
	ui.open_service("mercenary", "Mercenary Center")
	var south: Array[Villager] = []
	var north: Villager
	for actor in world.actors_root.get_children():
		if actor is Villager:
			if actor.home_position.y < GameWorld.NORTH_REGION_Y and north == null:
				north = actor
			elif actor.home_position.y >= GameWorld.NORTH_REGION_Y:
				south.append(actor)
	_check(south.size() == 15 and north != null, "road mission has fifteen southern residents and separate northern residents")
	_check(north != null and _find_button(ui.modal_content, "(" + north.villager_id + ")") == null, "southern board excludes northern villagers")
	if south.size() < 2 or north == null:
		ui.close_modal()
		return
	_check(not world.recruit(north.villager_id), "road squad rejects a northern recruit")
	for index in 2:
		var recruit := _find_button(ui.modal_content, "(" + south[index].villager_id + ")")
		_check(recruit != null, "southern roster offers recruit %s" % south[index].villager_id)
		if recruit != null:
			recruit.pressed.emit()
	_check(state.squad_recruits.size() == 2, "road squad recruits two southern residents")
	var deploy := _find_button(ui.modal_content, "Deploy squad")
	_check(deploy != null and not deploy.disabled, "southern board can deploy the road squad")
	if deploy != null:
		deploy.pressed.emit()
	ui.close_modal()
	_check(state.squad_deployed, "southern recruits deploy for the road cleanup")
	if not state.squad_deployed:
		return
	var targets: Dictionary = {}
	for actor in world.actors_root.get_children():
		if actor is Enemy and state.ROAD_IDS.has(actor.persistent_id) and not actor.is_queued_for_deletion():
			targets[actor.persistent_id] = actor
	_check(targets.size() == state.ROAD_IDS.size(), "the road squad uses three existing enemies rather than spawning duplicates")
	for target_id in state.ROAD_IDS:
		if not targets.has(target_id):
			continue
		var target: Enemy = targets[target_id]
		_check(target.get_node_or_null("RoadTargetMarker") != null, "%s receives a road mission marker" % target_id)
		target.take_damage(999)
		_check(state.team_defeated_ids.count(target_id) == 1 and not target.visible, "%s is counted once and stays down during the mission" % target_id)
		if state.team_defeated_ids.size() == 1:
			world.capture_player_position()
			_check(state.save_game() and state.load_game(), "partly cleared road mission saves and loads")
			world.apply_loaded_state()
			await get_tree().process_frame
			_check(state.team_job_id == state.ROAD_JOB and state.squad_deployed and state.team_defeated_ids == [target_id], "reload keeps road targets and southern recruits without duplication")
	_check(state.active_job_ready(state.ROAD_JOB) and state.team_defeated_ids.size() == state.ROAD_IDS.size(), "exactly three distinct road kills complete the mission")
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	var camp_before_claim := _find_button(ui.modal_content, "Clear the Bandit Camp")
	_check(camp_before_claim != null and camp_before_claim.disabled and not state.camp_unlocked, "road defeats alone do not unlock the camp before the southern reward is claimed")
	ui.close_modal()
	var reward := int(GameData.job(state.ROAD_JOB)["reward"])
	var before_claim := state.gold
	_check(not state.claim_job("north_mercenary", state.ROAD_JOB) and state.gold == before_claim and state.active_jobs.has(state.ROAD_JOB), "northern board cannot pay the completed southern road mission")
	ui.open_service("mercenary", "Mercenary Center")
	var claim := _find_button(ui.modal_content, "Clear the Forest Road")
	_check(claim != null and claim.text.contains("CLAIM"), "southern board offers the completed road reward")
	if claim != null:
		claim.pressed.emit()
	ui.close_modal()
	_check(state.gold == before_claim + reward and not state.squad_deployed and not state.active_jobs.has(state.ROAD_JOB), "southern mercenary pays road reward and releases the squad")
	_check(state.camp_unlocked and not state.completed_unique_jobs.has(state.CAMP_JOB), "claiming the southern road reward unlocks the northern camp mission")

func _check_squad_mission(world: GameWorld) -> void:
	var state := GameState
	state.start_new_game()
	state.player_position = Player.RESPAWN_POSITION
	world.apply_loaded_state()
	var ui := get_tree().get_first_node_in_group("game_ui") as GameUI
	_check(ui != null, "camp mission has a mercenary board")
	if ui == null:
		return
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	var locked_button := _find_button(ui.modal_content, "Clear the Bandit Camp")
	_check(locked_button != null and locked_button.disabled and locked_button.text.contains("locked"), "northern camp starts locked until the road reward is claimed")
	ui.close_modal()
	_check(not state.accept_job(state.CAMP_JOB), "camp cannot be accepted before road cleanup pays out")
	ui.open_service("mercenary", "Mercenary Center")
	var locked_hacker := _find_button(ui.modal_content, "The Hacker")
	_check(locked_hacker != null and locked_hacker.disabled, "solo Paprika hacker bounty starts locked until the camp reward is claimed")
	ui.close_modal()
	var hacker: Enemy
	for actor in world.actors_root.get_children():
		if actor is Enemy and actor.enemy_id == "hacker" and not actor.is_queued_for_deletion():
			hacker = actor
			break
	_check(hacker != null, "hacker remains available for the early-defeat test")
	if hacker == null:
		return
	hacker.take_damage(999)
	_check(not hacker.visible and not state.hacker_defeated() and not state.camp_unlocked and not state.active_jobs.has("hacker_bounty"), "defeating the hacker early neither unlocks the camp nor completes the locked bounty")
	hacker._physics_process(Enemy.RESPAWN_SECONDS + 0.1)
	_check(hacker.visible and hacker.health == hacker.max_health and hacker.is_in_group("damageable"), "the early-defeated hacker respawns for the later solo bounty")
	await _check_road_mission(world, ui)
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	var available_button := _find_button(ui.modal_content, "Clear the Bandit Camp")
	_check(available_button != null and not available_button.disabled, "claiming road cleanup makes the northern camp mission available")
	if available_button != null and not available_button.disabled:
		available_button.pressed.emit()
	_check(state.active_jobs.has(state.CAMP_JOB), "camp mission accepts from the northern board")
	_check_job_direction(ui, state.CAMP_JOB)
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	var first := world.find_villager("resident_01")
	var second := world.find_villager("resident_02")
	var southerner := world.find_villager("resident_00")
	_check(first != null and second != null and southerner != null and first != second, "northern recruits and a southern resident have distinct stable IDs")
	if first == null or second == null or southerner == null:
		return
	_check(first.home_position.y < GameWorld.NORTH_REGION_Y and second.home_position.y < GameWorld.NORTH_REGION_Y, "camp recruits live in the northern village")
	_check(_find_button(ui.modal_content, "(" + southerner.villager_id + ")") == null and not world.recruit(southerner.villager_id), "northern board excludes and rejects southern villagers")
	var next_button := _find_button(ui.modal_content, "Next villagers")
	_check(next_button != null, "northern village roster has another page")
	if next_button != null:
		next_button.pressed.emit()
		var previous_button := _find_button(ui.modal_content, "Previous villagers")
		_check(previous_button != null, "northern roster can return to its first page")
		if previous_button != null:
			previous_button.pressed.emit()
	var first_recruit := _find_button(ui.modal_content, "(" + first.villager_id + ")")
	_check(first_recruit != null and first_recruit.text.begins_with("Recruit "), "northern board lists its first villager")
	if first_recruit != null:
		first_recruit.pressed.emit()
	var second_recruit := _find_button(ui.modal_content, "(" + second.villager_id + ")")
	_check(second_recruit != null and second_recruit.text.begins_with("Recruit "), "northern board lists its second villager")
	if second_recruit != null:
		second_recruit.pressed.emit()
	_check(state.squad_recruits == [first.villager_id, second.villager_id], "northern board recruits exactly two local villagers")
	_check(not world.recruit(first.villager_id) and not world.recruit("not_a_villager"), "duplicate and unknown recruits are rejected")
	var deploy_button := _find_button(ui.modal_content, "Deploy squad")
	_check(deploy_button != null and not deploy_button.disabled, "mercenary board offers deployment with two recruits")
	if deploy_button != null:
		deploy_button.pressed.emit()
	ui.close_modal()
	_check(state.squad_deployed and first.squad_member and second.squad_member, "deploy button activates both northern villagers as squad members")
	if not state.squad_deployed:
		return
	var marker := world.actors_root.get_node_or_null("BanditCamp") as Node2D
	var marker_route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, marker.global_position) if marker != null else PackedVector2Array()
	_check(marker != null and marker.visible and marker.get_child_count() >= 2, "deployed camp has a visible tent and fire marker")
	_check(marker != null and marker.global_position.y >= 500.0 and marker.global_position.y <= 1050.0 and absf(marker.global_position.x - 832.0) > 300.0 and not marker_route.is_empty() and marker_route[-1].distance_to(marker.global_position) < 40.0, "camp lies deep off the forest road but has a walkable approach")
	var suspended_index := first._routine_index
	_check(first._was_squad_member and not first._activity_prop.visible and not first._hoe.visible, "deployed recruit suspends civilian activity before a physics tick")
	first._physics_process(1.0 / 60.0)
	_check(first._routine_index == suspended_index, "squad control does not advance a civilian itinerary")
	_check(first.is_in_group("party_target") and second.is_in_group("party_target"), "enemy targeting includes deployed recruits")
	var camp: Array[Enemy] = _live_camp_bandits(world)
	_check(camp.size() == 3, "three distinct camp bandits spawn on deployment")
	var camp_ids: Dictionary = {}
	var camp_kinds: Dictionary = {}
	var all_routes := true
	for enemy in camp:
		camp_ids[enemy.persistent_id] = true
		camp_kinds[enemy.enemy_id] = true
		var path := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, enemy.spawn_position)
		if path.is_empty() or path[-1].distance_to(enemy.spawn_position) > 18.0:
			all_routes = false
	_check(camp_ids.size() == 3 and camp_ids.has(state.CAMP_IDS[0]) and camp_ids.has(state.CAMP_IDS[1]) and camp_ids.has(state.CAMP_IDS[2]), "camp bandits have unique persistent identities")
	_check(camp_kinds.has("bandit_spear") and camp_kinds.has("bandit_bow") and camp_kinds.has("bandit_sword"), "camp contains distinct red-spear, blue-bow and purple-sword bandits")
	_check(all_routes, "every camp spawn is reachable from the village")
	_check_transferred_weapon_attack(world, first, camp)
	_check(world.controlled_actor() == world.player and world.select_member(1) and world.controlled_actor() == first, "control switches from player to first recruit")
	_check(first.get_node_or_null("Camera") is Camera2D and world.select_member(2) and world.controlled_actor() == second and second.get_node_or_null("Camera") is Camera2D, "camera follows the selected recruit")
	_check(world.select_member(0) and world.controlled_actor() == world.player and world.player.get_node_or_null("Camera") is Camera2D, "control and camera return to the player")
	var party_key := InputEventAction.new()
	party_key.action = "party_first"
	party_key.pressed = true
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	world._unhandled_input(party_key)
	_check(world.controlled_actor() == world.player, "party hotkey does not change control while a menu is open")
	var attack_key := InputEventAction.new()
	attack_key.action = "order_attack"
	attack_key.pressed = true
	world._unhandled_input(attack_key)
	_check(state.squad_members[first.villager_id]["order"] == "follow", "order hotkey does not act while a menu is open")
	ui.close_modal()
	world._unhandled_input(party_key)
	_check(world.controlled_actor() == first and first.get_node_or_null("Camera") is Camera2D, "party hotkey selects first recruit after menu closes")
	world._unhandled_input(attack_key)
	_check(state.player_order == "attack" and state.squad_members[second.villager_id]["order"] == "attack", "order hotkey commands uncontrolled allies after menu closes")
	var player_key := InputEventAction.new()
	player_key.action = "party_player"
	player_key.pressed = true
	world._unhandled_input(player_key)
	_check(world.controlled_actor() == world.player, "party hotkey can restore player control")
	world.issue_order("hold")
	_check(state.squad_members[first.villager_id]["order"] == "hold" and state.squad_members[second.villager_id]["order"] == "hold", "hold command reaches both uncontrolled recruits")
	var hold_position := first.global_position
	world.step_squad_actor(first, 1.0 / 60.0)
	_check(first.global_position.distance_to(hold_position) < 0.1, "recruit stays in place on hold order")
	first.global_position = world.player.global_position + Vector2(-70, 0)
	world.issue_order("follow")
	_check(state.squad_members[first.villager_id]["order"] == "follow" and state.squad_members[second.villager_id]["order"] == "follow", "follow command changes both orders")
	var initial_follow_distance := first.global_position.distance_to(world.player.global_position)
	for tick in range(45):
		world.step_squad_actor(first, 1.0 / 60.0)
	_check(first.global_position.distance_to(world.player.global_position) < initial_follow_distance - 8.0, "following recruit moves toward the controlled player")
	world.issue_order("attack")
	_check(state.squad_members[first.villager_id]["order"] == "attack" and state.squad_members[second.villager_id]["order"] == "attack", "attack command changes both orders")
	if not camp.is_empty():
		var target: Enemy = camp[0]
		var original_position := target.global_position
		target.global_position = first.global_position + Vector2(-10, 0)
		_check(target._nearest_party_target() == first, "camp bandit targets a nearer squad member rather than the player")
		_check(world.nearest_hostile(first.global_position, 30.0) == target, "squad targeting finds the nearby camp bandit")
		first.facing = Vector2.LEFT
		var before_attack := target.health
		world.step_squad_actor(first, 1.0 / 60.0)
		_check(target.health < before_attack, "attack order makes recruit strike a nearby hostile")
		world.issue_order("hold")
		var friendly := Projectile.new()
		world.actors_root.add_child(friendly)
		friendly.configure(first.global_position, Vector2.RIGHT, 1, 100.0, 30.0, true)
		_check((friendly.collision_mask & 8) != 0 and (friendly.collision_mask & 64) == 0, "squad projectile can hit enemies but not recruits")
		before_attack = target.health
		friendly._on_body_entered(target)
		_check(target.health < before_attack, "friendly projectile damages a camp bandit")
		var hostile := Projectile.new()
		world.actors_root.add_child(hostile)
		hostile.configure(target.global_position, Vector2.LEFT, 1, 100.0, 30.0, false)
		_check((hostile.collision_mask & 64) != 0 and (hostile.collision_mask & 8) == 0 and (hostile.collision_mask & 2) != 0, "hostile projectile can hit player and recruits but not enemies")
		var recruit_health := int(state.squad_members[first.villager_id]["health"])
		hostile._on_body_entered(first)
		_check(int(state.squad_members[first.villager_id]["health"]) < recruit_health, "hostile projectile damages a deployed recruit")
		target.global_position = original_position
		var recruit_home := first.home_position
		first._invulnerability = 0.0
		first.take_damage(999)
		_check(state.recruit_recovering(first.villager_id) and first.global_position == recruit_home and not first.is_in_group("party_target"), "downed recruit returns home and cannot be targeted")
		state._process(state.RECOVERY_SECONDS + 0.1)
		_check(not state.recruit_recovering(first.villager_id) and int(state.squad_members[first.villager_id]["health"]) == int(state.squad_members[first.villager_id]["max_health"]) and first.is_in_group("party_target"), "recovered recruit rejoins squad at full health")
		target.take_damage(999)
		_check(state.camp_defeated_ids.has(target.persistent_id) and int(state.active_jobs[state.CAMP_JOB]) == 1, "first camp kill is recorded once")
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		_check(false, "set XDG_DATA_HOME before the midmission save test")
		return
	world.issue_order("hold")
	world.capture_player_position()
	var saved_first_position := first.global_position
	_check(state.save_game(), "midmission squad and one camp casualty can be saved")
	state.player_position = Vector2.ZERO
	state.camp_defeated_ids.clear()
	state.squad_members.clear()
	_check(state.load_game(), "midmission squad save loads")
	var restored_position: Array = state.squad_members[first.villager_id]["position"]
	_check(Vector2(float(restored_position[0]), float(restored_position[1])).distance_to(saved_first_position) < 0.01, "reload restores saved recruit position")
	world.apply_loaded_state()
	await get_tree().process_frame
	_check(state.squad_deployed and state.squad_recruits.size() == 2 and state.camp_defeated_ids.size() == 1 and int(state.active_jobs[state.CAMP_JOB]) == 1, "reload restores two recruits and unique camp progress")
	_check(first.global_position.distance_to(saved_first_position) < 5.0, "recruit appears near saved position after one physics frame")
	_check(world.controlled_actor() == world.player, "reload restores player control")
	var north_food: WorldService
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is WorldService and node.service_id == "north_food":
			north_food = node
			break
	if north_food != null:
		var blocked := north_food.global_position + Vector2(12, 62)
		_check(not world.tiled_loader.is_walkable_position(blocked), "new northern shop makes an old map position solid")
		state.player_position = blocked
		var displaced: Dictionary = state.squad_members[second.villager_id]
		displaced["position"] = [blocked.x, blocked.y]
		state.squad_members[second.villager_id] = displaced
		_check(state.save_game() and state.load_game(), "midmission save accepts formerly open coordinates now inside a new shop")
		world.apply_loaded_state()
		_check(world.tiled_loader.is_walkable_position(world.player.global_position) and world.player.global_position.distance_to(blocked) < 150.0, "loaded player moves only far enough to leave a new wall")
		_check(world.tiled_loader.is_walkable_position(second.global_position) and second.global_position.distance_to(blocked) < 150.0, "loaded northern recruit moves out of a new wall")
		_check(first.global_position.distance_to(saved_first_position) < 5.0 and state.camp_defeated_ids.size() == 1, "unblocked recruit position and camp progress survive correction")
		state.player_position = Player.RESPAWN_POSITION
		displaced = state.squad_members[second.villager_id]
		displaced["position"] = [second.home_position.x, second.home_position.y]
		state.squad_members[second.villager_id] = displaced
		world.apply_loaded_state()
	var remaining := _live_camp_bandits(world)
	_check(remaining.size() == 2, "reload spawns only two undefeated camp bandits")
	world.apply_loaded_state()
	await get_tree().process_frame
	remaining = _live_camp_bandits(world)
	var remaining_ids: Dictionary = {}
	for enemy in remaining:
		remaining_ids[enemy.persistent_id] = true
	_check(remaining.size() == 2 and remaining_ids.size() == 2 and not remaining_ids.has(state.camp_defeated_ids[0]), "repeated load does not duplicate camp bandits or resurrect defeated bandit")
	for enemy in remaining:
		enemy.take_damage(999)
	_check(state.active_job_ready(state.CAMP_JOB) and state.camp_defeated_ids.size() == 3, "defeating remaining distinct camp bandits completes the mission")
	ui.open_service("mercenary", "Mercenary Center")
	var hacker_before_claim := _find_button(ui.modal_content, "The Hacker")
	_check(hacker_before_claim != null and hacker_before_claim.disabled and not state.accept_job("hacker_bounty"), "camp kills alone do not unlock the solo hacker bounty before claiming the reward")
	ui.close_modal()
	var reward := int(GameData.job(state.CAMP_JOB)["reward"])
	var before_claim := state.gold
	_check(not state.claim_job("mercenary", state.CAMP_JOB) and state.gold == before_claim and state.active_jobs.has(state.CAMP_JOB), "southern board cannot pay the completed northern camp mission")
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	var claim_button := _find_button(ui.modal_content, "Clear the Bandit Camp")
	_check(claim_button != null and claim_button.text.contains("CLAIM") and not claim_button.disabled, "mercenary board offers claim after all three camp kills")
	if claim_button != null and not claim_button.disabled:
		claim_button.pressed.emit()
	_check(state.gold == before_claim + reward and state.completed_unique_jobs.has(state.CAMP_JOB), "mercenary board pays camp reward once")
	var completed_button := _find_button(ui.modal_content, "Clear the Bandit Camp")
	_check(completed_button != null and completed_button.disabled and completed_button.text.contains("completed"), "claimed camp mission is marked completed on mercenary board")
	ui.close_modal()
	_check(not state.claim_job("north_mercenary", state.CAMP_JOB) and state.gold == before_claim + reward and not state.squad_deployed, "camp reward cannot pay twice and northern squad is released")
	_check(not first.squad_member and not first._was_squad_member and first._can_reach(first._target), "released recruit resumes a reachable civilian stop from the current position")
	await _check_paprika_hacker_bounty(world, ui, hacker)


func _check_paprika_hacker_bounty(world: GameWorld, ui: GameUI, hacker: Enemy) -> void:
	var state := GameState
	ui.open_service("mercenary", "Mercenary Center")
	var offer := _find_button(ui.modal_content, "The Hacker")
	_check(offer != null and not offer.disabled and state.completed_unique_jobs.has(state.CAMP_JOB), "claiming the northern camp reward unlocks the solo Paprika hacker bounty")
	if offer == null or offer.disabled:
		ui.close_modal()
		return
	offer.pressed.emit()
	_check(state.active_jobs.has("hacker_bounty") and state.team_job_id.is_empty() and not state.squad_deployed, "solo hacker bounty starts without recruiting a squad")
	_check_job_direction(ui, "hacker_bounty")
	_check(is_instance_valid(hacker) and not hacker.is_queued_for_deletion() and hacker.visible and hacker.health == hacker.max_health, "early-defeated hacker remains available as the later bounty target")
	world.capture_player_position()
	_check(state.save_game() and state.load_game(), "accepted solo Paprika hacker bounty survives saving")
	world.apply_loaded_state()
	await get_tree().process_frame
	_check(state.active_jobs.has("hacker_bounty") and not state.active_job_ready("hacker_bounty") and not state.hacker_defeated(), "solo bounty reload retains its unfinished target")
	if not is_instance_valid(hacker) or hacker.is_queued_for_deletion():
		return
	hacker.take_damage(999)
	_check(state.hacker_defeated() and state.active_job_ready("hacker_bounty") and hacker.is_queued_for_deletion(), "defeating the unlocked hacker completes the solo bounty and prevents another respawn")
	ui.open_service("mercenary", "Mercenary Center")
	var claim := _find_button(ui.modal_content, "The Hacker")
	_check(claim != null and claim.text.contains("CLAIM"), "southern mercenary center offers the solo hacker reward")
	var before_claim := state.gold
	if claim != null:
		claim.pressed.emit()
	_check(state.gold == before_claim + int(GameData.job("hacker_bounty")["reward"]) and state.completed_unique_jobs.has("hacker_bounty") and not state.active_jobs.has("hacker_bounty"), "claiming the solo hacker bounty pays once and marks it completed")
	ui.close_modal()


func _check_job_direction(ui: GameUI, job_id: String) -> void:
	var hint := String(GameData.job(job_id).get("location_hint", ""))
	_check(not hint.is_empty() and ui.notification_label.text.contains(hint), "%s acceptance notice names its destination" % job_id)
	ui.open_jobs()
	_check(not hint.is_empty() and _has_text(ui.modal_content, hint), "%s job list keeps its destination visible" % job_id)
	ui.close_modal()


func _check_transferred_weapon_attack(world: GameWorld, recruit: Villager, camp: Array[Enemy]) -> void:
	if camp.is_empty():
		return
	var state := GameState
	_check(state.add_item("bronze_sword") and state.equip_item("bronze_sword") and state.remove_item("stick"), "player equips a single bronze sword with no spare weapon")
	var ui := get_tree().get_first_node_in_group("game_ui") as GameUI
	_check(ui != null, "recruit equipment can be changed at the mercenary board")
	if ui == null:
		return
	ui.open_service("north_mercenary", "Northern Mercenary Center")
	var transfer := _find_button(ui.modal_content, "Weapon: Bronze Sword (take from you)")
	_check(transfer != null and not transfer.disabled, "mercenary board offers the player's equipped sword to the recruit")
	if transfer != null and not transfer.disabled:
		transfer.pressed.emit()
	ui.close_modal()
	_check(state.equipment["weapon"] == "" and state.squad_members[recruit.villager_id]["weapon"] == "bronze_sword" and state.reserved_item_count("bronze_sword") == 1, "weapon transfer leaves the player unarmed and reserves the recruit's copy")
	var target: Enemy = camp[0]
	var original_target_position := target.global_position
	var original_target_health := target.health
	var original_player_position := world.player.global_position
	var original_player_facing := world.player.facing
	var original_player_cooldown := world.player._attack_cooldown
	var original_recruit_facing := recruit.facing
	var original_recruit_cooldown := recruit.attack_cooldown
	target.global_position = recruit.global_position + Vector2(18, 0)
	world.player.global_position = recruit.global_position
	world.player.facing = Vector2.RIGHT
	recruit.facing = Vector2.RIGHT
	recruit.attack_cooldown = 0.0
	world.player._attack_cooldown = 0.0
	var space_key := InputEventKey.new()
	space_key.physical_keycode = KEY_SPACE
	space_key.pressed = true
	_check(space_key.is_action_pressed("attack") and world.select_member(1), "Space selects the attack action while the first recruit is controlled")
	world.player._unhandled_input(space_key)
	var bronze_damage := maxi(1, 10 - int(target.definition.get("armor", 0)))
	_check(target.health == original_target_health - bronze_damage and is_equal_approx(recruit.attack_cooldown, 0.36), "controlled recruit's Space attack uses the transferred bronze sword's damage and cooldown")
	world.select_member(0)
	var health_after_recruit := target.health
	world.player._unhandled_input(space_key)
	_check(target.health == health_after_recruit and world.player._attack_cooldown == 0.0 and state.weapon_definition().is_empty(), "unarmed player's Space attack cannot use the transferred sword")
	target.global_position = original_target_position
	target.health = original_target_health
	world.player.global_position = original_player_position
	world.player.facing = original_player_facing
	world.player._attack_cooldown = original_player_cooldown
	recruit.facing = original_recruit_facing
	recruit.attack_cooldown = original_recruit_cooldown


func _live_camp_bandits(world: GameWorld) -> Array[Enemy]:
	var bandits: Array[Enemy] = []
	for actor in world.actors_root.get_children():
		if actor is Enemy and GameState.CAMP_IDS.has(actor.persistent_id) and not actor.is_queued_for_deletion():
			bandits.append(actor)
	return bandits


func _check_visual_map(world: GameWorld) -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string(GameWorld.MAP_PATH))
	_check(source is Dictionary, "the playable Tiled map remains valid JSON")
	if not source is Dictionary:
		return
	var detail: Dictionary = {}
	var common: Dictionary = {}
	var paths: Dictionary = {}
	var objects: Array = []
	for layer_value in source["layers"]:
		match String(layer_value.get("name", "")):
			"Field Boundaries and Forest Details": detail = layer_value
			"Common Fields": common = layer_value
			"Paths and Plaza": paths = layer_value
		if String(layer_value.get("type", "")) == "objectgroup":
			objects = layer_value.get("objects", [])
	_check(int(source.get("width", 0)) == 104 and int(source.get("height", 0)) == 120, "Tiled stores the expanded 104-by-120-tile map")
	_check(not detail.is_empty() and detail["data"].size() == 104 * 120, "Tiled has a full-size boundary and forest-detail layer")
	if not detail.is_empty():
		var fences := 0
		var forest_details := 0
		for tile in detail["data"]:
			if int(tile) in [14, 15]:
				fences += 1
			elif int(tile) in [19, 20]:
				forest_details += 1
		_check(fences >= 80 and forest_details >= 30, "fields have visible fences and the forest has debris")
	if not detail.is_empty() and not common.is_empty():
		var northern_crop_cells := 0
		var northern_fence_cells := 0
		for y in range(8, 15):
			for x in range(53, 59):
				var index := y * 104 + x
				if int(common["data"][index]) != 0:
					northern_crop_cells += 1
				if int(detail["data"][index]) in [14, 15]:
					northern_fence_cells += 1
		_check(northern_crop_cells >= 10 and northern_fence_cells >= 14, "northern common crop patch has planted rows and a visible fence")
		_check(int(detail["data"][11 * 104 + 53]) == 0, "northern common field has an open road-facing gate")
	if not paths.is_empty():
		var connecting_road := true
		for y in range(22, 70):
			var paved_cells := 0
			for x in range(48, 56):
				if int(paths["data"][y * 104 + x]) != 0:
					paved_cells += 1
			connecting_road = connecting_road and paved_cells >= 2
		_check(connecting_road, "a visible road crosses all 48 rows between the settlements")
	var ground: Array = source["layers"][0]["data"]
	var dark_grass := 0
	var forest_strip_dark := 0
	for index in ground.size():
		if int(ground[index]) in [17, 18]:
			dark_grass += 1
			if index / 104 >= 22 and index / 104 < 70:
				forest_strip_dark += 1
	_check(dark_grass >= 500 and forest_strip_dark >= 4000, "dark forest terrain separates the northern and southern villages")
	var forest_signs := 0
	var common_signs := 0
	var private_signs := 0
	var warning_signs := 0
	var travel_objects := 0
	var moved_travel := false
	var northern_buildings_separated := true
	var northern_fountain := false
	var northern_ships: Dictionary = {}
	var southern_office := false
	var iron_outfitter := false
	var northern_mercenary := 0
	var southern_mercenary := 0
	var unique_ids: Dictionary = {}
	var sign_clearance := true
	for object_value in objects:
		var placed: Dictionary = object_value
		var name := String(placed.get("name", ""))
		unique_ids[placed["id"]] = true
		if name == "travel":
			travel_objects += 1
			moved_travel = int(placed["id"]) == 34 and float(placed["y"]) < 340.0
		if name.begins_with("north_") or name == "travel":
			northern_buildings_separated = northern_buildings_separated and float(placed["y"]) <= 340.0
		if name == "spaceship" and int(placed["id"]) in [35, 219] and float(placed["y"]) >= 390.0 and float(placed["y"]) <= 490.0:
			northern_ships[int(placed["id"])] = true
		if name == "work_office" and int(placed["id"]) == 51:
			southern_office = is_equal_approx(float(placed["y"]), 1122.0)
		if name == "iron_gear_shop":
			iron_outfitter = true
		if name == "mercenary" and float(placed["y"]) > 1100.0:
			southern_mercenary += 1
		if name == "north_mercenary" and float(placed["y"]) < 350.0:
			northern_mercenary += 1
		if name == "fountain" and float(placed["y"]) < 350.0:
			northern_fountain = true
		if name == "common_field_sign":
			common_signs += 1
		elif name == "private_garden_sign":
			private_signs += 1
		elif name == "forest_warning_sign":
			warning_signs += 1
		if name != "forest_sign":
			continue
		forest_signs += 1
		if int(placed.get("width", 0)) != 48 or int(placed.get("height", 0)) != 32:
			sign_clearance = false
		var sign_rect := Rect2(Vector2(float(placed["x"]), float(placed["y"]) - 32.0), Vector2(48, 32))
		for other_value in objects:
			var other: Dictionary = other_value
			var other_name := String(other.get("name", ""))
			if other["id"] == placed["id"] or other_name.begins_with("villager") or other_name in ["player", "rabbit", "wolf", "zombie", "zombie_bear", "bandit", "hacker"]:
				continue
			var other_rect := Rect2(Vector2(float(other["x"]), float(other["y"]) - float(other["height"])), Vector2(float(other["width"]), float(other["height"])))
			if sign_rect.intersects(other_rect):
				sign_clearance = false
	_check(unique_ids.size() == objects.size(), "Tiled object IDs stay unique after the northern expansion")
	_check(travel_objects == 1 and moved_travel, "the existing travel object ID 34 moves north without duplication")
	_check(northern_buildings_separated, "northern shops and agency remain above the new forest")
	_check(northern_ships.size() == 2, "both original spaceships now stand on the northern landing apron")
	_check(southern_office, "original work office ID 51 moves to y=1122 with the southern village")
	_check(not iron_outfitter, "iron outfitter ID 255 is removed from the map")
	_check(southern_mercenary == 1 and northern_mercenary == 1, "each Paprika village has its own mercenary center")
	_check(northern_fountain, "a distinct northern village square has a fountain")
	_check(forest_signs == 4 and sign_clearance, "all four full-width FOREST signs are clear of buildings and trees")
	_check(common_signs == 3 and private_signs == 1 and warning_signs == 3, "both villages' fields and three forest approaches have signs")
	var visible_forest_signs := 0
	for object in world.tiled_loader._object_root.get_children():
		var sprite := object.get_child(0) as Sprite2D
		if sprite != null and sprite.texture != null and sprite.texture.resource_path.ends_with("/forest_sign.png") and sprite.texture.get_width() == 48:
			visible_forest_signs += 1
	_check(visible_forest_signs == 4, "runtime loads all four wider FOREST sign sprites")

func _has_text(container: Node, text_part: String) -> bool:
	for child in container.get_children():
		if child is Label and child.text.contains(text_part):
			return true
		if _has_text(child, text_part):
			return true
	return false

func _find_button(container: Node, text_part: String) -> Button:
	for child in container.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button and String(child.text).contains(text_part):
			return child
		var nested := _find_button(child, text_part)
		if nested != null:
			return nested
	return null

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		printerr("FAIL ", description)
