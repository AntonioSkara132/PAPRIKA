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
	_check(world.tiled_loader.map_size == Vector2(1664, 1152), "forest map is larger than the concept view")
	_check(world.player != null and world.player.global_position.distance_to(Vector2(838, 618)) < 18.0, "player starts below village square")
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
	_check(villagers == 25, "exactly 25 villagers are active")
	_check(farmers.size() >= 2, "multiple villagers have common-field work routines")
	_check(rabbits >= 5, "the forest has at least five rabbits")
	_check(enemies >= 5, "the forest has wolves, monsters, a bandit and a hacker")
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
	for service_id in ["food", "forge", "clothing", "work_office", "mercenary", "travel"]:
		_check(services.has(service_id), "%s can be visited" % service_id)
		if services.has(service_id):
			var door: Vector2 = services[service_id].get_interaction_position()
			var route := world.tiled_loader.get_walk_path(Player.RESPAWN_POSITION, door + Vector2(0, 9))
			if route.is_empty() or route[-1].distance_to(door) > Player.INTERACTION_DISTANCE:
				entrances_reachable = false
	_check(entrances_reachable, "all six service entrances remain reachable from the village")
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
	for i in range(5):
		fields[i].interact(world.player)
	_check(int(state.active_jobs["field_work"]) == 5 and state.active_job_ready("field_work"), "five harvests finish the field job")
	_check(int(state.active_jobs["rabbit_catch"]) == 0 and int(state.active_jobs["forest_patrol"]) == 0, "field work does not advance unrelated missions")
	_check(not fields[0].get_interaction_text().begins_with("Harvest"), "harvested crop shows regrowth")
	_check(state.claim_job("work_office", "field_work") and state.gold == 10, "work office pays exactly 10 gold")
	_check(state.active_jobs.has("rabbit_catch") and state.active_jobs.has("forest_patrol"), "field reward does not remove other missions")
	_check(not state.claim_job("work_office", "field_work") and state.gold == 10, "field job cannot pay twice")
	state._process(120.0)
	fields[0]._process(0.0)
	_check(state.field_is_ready(fields[0].field_id), "field becomes ready after 120 simulated seconds")

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
		world.player.global_position = Vector2(838, 618)

	var forest_rabbits: Array[Rabbit] = []
	for actor in world.actors_root.get_children():
		if actor is Rabbit:
			forest_rabbits.append(actor)
	_check(forest_rabbits.size() >= 6, "enough rabbits for both hunting and the catch job")
	if forest_rabbits.size() >= 6:
		var prey := forest_rabbits[0]
		_check(prey.collision_layer == 32, "rabbit has a distinct projectile hit layer")
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
			var sword_button := _find_button(ui.modal_content, "Wooden Sword")
			_check(sword_button != null, "forge offers a wooden sword")
			if sword_button != null:
				sword_button.pressed.emit()
				_check(state.gold == 22 and state.equipment["weapon"] == "wood_sword", "forge button buys and equips the sword")
			ui.open_service("clothing", "Clothing & Armor")
			var tunic_button := _find_button(ui.modal_content, "Red Villager Tunic")
			_check(tunic_button != null, "clothing shop offers medieval outfits")
			if tunic_button != null:
				tunic_button.pressed.emit()
				_check(state.gold == 4 and state.equipment["clothing"] == "red_tunic", "clothing purchase equips an outfit")
				_check(world.player._sprite.texture.resource_path.ends_with("player_red.png"), "the outfit changes the visible player sprite")
			ui.close_modal()

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

	print("Paprika world: %d checks, %d failures" % [checks, failures])
	remove_child(game)
	game.free()
	get_tree().quit(0 if failures == 0 else 1)

func _check_visual_map(world: GameWorld) -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string(GameWorld.MAP_PATH))
	_check(source is Dictionary, "the playable Tiled map remains valid JSON")
	if not source is Dictionary:
		return
	var detail: Dictionary = {}
	var objects: Array = []
	for layer_value in source["layers"]:
		if String(layer_value.get("name", "")) == "Field Boundaries and Forest Details":
			detail = layer_value
		elif String(layer_value.get("type", "")) == "objectgroup":
			objects = layer_value.get("objects", [])
	_check(not detail.is_empty() and detail["data"].size() == 104 * 72, "Tiled has a full-size boundary and forest-detail layer")
	if not detail.is_empty():
		var fences := 0
		var forest_details := 0
		for tile in detail["data"]:
			if int(tile) in [14, 15]:
				fences += 1
			elif int(tile) in [19, 20]:
				forest_details += 1
		_check(fences >= 80 and forest_details >= 30, "fields have visible fences and the forest has debris")
	var ground: Array = source["layers"][0]["data"]
	var dark_grass := 0
	for tile in ground:
		if int(tile) in [17, 18]:
			dark_grass += 1
	_check(dark_grass >= 500, "forest ground darkens beyond the village")
	var forest_signs := 0
	var common_signs := 0
	var private_signs := 0
	var warning_signs := 0
	var sign_clearance := true
	for object_value in objects:
		var placed: Dictionary = object_value
		var name := String(placed.get("name", ""))
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
	_check(forest_signs == 4 and sign_clearance, "all four full-width FOREST signs are clear of buildings and trees")
	_check(common_signs == 2 and private_signs == 1 and warning_signs == 1, "common fields, private gardens and forest danger have signs")
	var visible_forest_signs := 0
	for object in world.tiled_loader._object_root.get_children():
		var sprite := object.get_child(0) as Sprite2D
		if sprite != null and sprite.texture != null and sprite.texture.resource_path.ends_with("/forest_sign.png") and sprite.texture.get_width() == 48:
			visible_forest_signs += 1
	_check(visible_forest_signs == 4, "runtime loads all four wider FOREST sign sprites")

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
