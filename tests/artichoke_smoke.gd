extends Node

## Travels from the training station to Artichoke and back, and checks the map,
## its blocked terrain, the soldiers, quick save/load and old-save migration.
## The story section checks reporting to Captain Vela, the Arms kit, bandages,
## the Mess, mine duty under shelling and the trench assault with its promotion.
## The trench raid section checks the officer, the six-soldier squad and its
## Q/R/T orders, trench cover, artillery, minefields, field mines, barbed wire,
## raid failure and destroying the Republic battery. The defense section checks
## the Republic counterattack: waves, artillery support, breaches and saving the win.
## The fleet section checks General Hickey and mining the four Republic warships.

const ROUTE_TARGETS := {
	"no man's land": Vector2(760, 520),
	"the occupied village": Vector2(1290, 600),
	"inside the Republic base": Vector2(1224, 1000),
	"the southwest battery": Vector2(250, 880),
}
const BLOCKED_POINTS := {
	"cliff face": Vector2(1416, 216),
	"frozen sea": Vector2(664, 1240),
	"Republic wall": Vector2(1176, 795),
}

var checks := 0
var failures := 0
var _messages: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	var save_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	if data_home.is_empty() or not save_path.begins_with(data_home + "/"):
		_check(false, "artichoke smoke requires an isolated XDG_DATA_HOME")
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
	# Fullscreen at 1920x1080 stretches the game 3x; the HUD stays at the 2x size.
	ui.apply_ui_scale(2.0 / 3.0)
	var job_box := ui.job_label.get_parent() as Control
	var squad_box := ui.squad_panel
	var modal_box := ui.modal_overlay.get_child(0) as Control
	_check(is_equal_approx(ui.scale.x, 2.0 / 3.0) and job_box.position.is_equal_approx(Vector2(724, 7)) and squad_box.position.is_equal_approx(Vector2(8, 470)) and is_equal_approx(squad_box.size.x, 944.0) and modal_box.position.is_equal_approx(Vector2(265, 125)) and ui.modal_overlay.size.is_equal_approx(Vector2(960, 540)), "in fullscreen the HUD keeps its windowed size and its boxes stay at the same edges")
	ui.apply_ui_scale(1.0)
	_check(job_box.position.is_equal_approx(Vector2(404, 7)) and is_equal_approx(squad_box.size.x, 624.0), "back in a 1280x720 window the HUD is laid out as before")
	var state := GameState
	state.notification_requested.connect(func(message: String) -> void: _messages.append(message))
	_check(state.travel_fare("artichoke") < 0 and not state.can_travel("artichoke"), "Artichoke cannot be reached from Paprika")

	# A recruit still in training cannot be deployed.
	state.current_planet = "station"
	state.current_area = "exterior"
	state.military_stage = "cannon"
	_check(game._switch_world("station") and game.world is StationWorld, "the training station loads")
	_check(not state.can_travel("artichoke"), "recruits in training are not sent to Artichoke")
	ui.open_service("station_ship", "Military Transport")
	var deploy := _find_button(ui.modal_content, "Deploy to Artichoke")
	_check(deploy != null and deploy.disabled, "the station ship shows a disabled deployment before graduation")
	ui.close_modal()

	# The state a recruit has after all six drills and the night in the barracks.
	state.military_stage = "graduated"
	state.military_cannon_hits.assign(state.MILITARY_CANNON_TARGETS.duplicate())
	state.military_trap_progress = state.MILITARY_TRAP_STEPS.size()
	var gold_before := state.gold
	ui.open_service("station_ship", "Military Transport")
	deploy = _find_button(ui.modal_content, "Deploy to Artichoke")
	_check(deploy != null and not deploy.disabled, "graduates can deploy to Artichoke from the station ship")
	if deploy == null:
		_finish(game)
		return
	deploy.pressed.emit()
	await get_tree().process_frame
	var front := game.world as ArtichokeWorld
	_check(front != null and state.current_planet == "artichoke" and state.gold == gold_before, "deployment reaches Artichoke for free")
	if front == null:
		_finish(game)
		return
	var loader := front.tiled_loader
	var arrival := front.player.global_position
	_check(arrival.distance_to(state.ARTICHOKE_ARRIVAL) < 1.0 and loader.is_walkable_position(arrival), "the player arrives on walkable cleared ground at Cauliflower Base")
	_check(front.player.respawn_location_name == "Cauliflower Base" and front.player.respawn_position == state.ARTICHOKE_ARRIVAL, "defeat on Artichoke returns the player to Cauliflower Base")
	_check(ui.location_label.text == "ARTICHOKE FRONT" and ui.job_label.text.contains("ARTICHOKE"), "the HUD names the Artichoke front")
	_check(loader.map_size == Vector2(96 * 16, 84 * 16), "the Artichoke map is 96 by 84 tiles")

	_check(front.soldiers("confederation").size() == 25 and front.soldiers("republic").size() == 15 and front.soldiers("republic").all(func(soldier: Node2D) -> bool: return not front.AIRFIELD_AREA.has_point(soldier.global_position)), "23 Confederation soldiers, their officer, the cook and 15 New Republic soldiers hold their positions, none on the airfield")
	var all_soldiers_placed := true
	for soldier in front.soldiers("confederation") + front.soldiers("republic"):
		if soldier.get_texture() == null:
			all_soldiers_placed = false
	_check(all_soldiers_placed, "every soldier has a sprite")
	var counts := _object_counts(loader)
	_check(int(counts.get("warship_escort", 0)) + int(counts.get("warship_scout", 0)) == 4 and int(counts.get("republic_warship_escort", 0)) == 3, "both bases have escort ships")
	_check(int(counts.get("destroyed_house", 0)) == 5 and int(counts.get("plateau_house", 0)) == 4, "no man's land has ruined houses and the high ground has houses")
	_check(not counts.has("landing_pad"), "ships stand on cleared ground with no landing pads")

	for label in BLOCKED_POINTS:
		_check(not loader.is_walkable_position(BLOCKED_POINTS[label]), "the %s blocks movement" % label)
	for label in ROUTE_TARGETS:
		var target := _open_point_near(loader, ROUTE_TARGETS[label])
		var route: PackedVector2Array = loader.get_walk_path(state.ARTICHOKE_ARRIVAL, target)
		_check(loader.is_walkable_position(target) and not route.is_empty() and route[-1].distance_to(target) < 17.0, "a walking route leads from the arrival to %s" % label)

	# Talking to a Confederation soldier; the New Republic soldiers do not talk.
	var soldier: FrontSoldier
	for candidate in front.soldiers("confederation"):
		if candidate.service_id.is_empty():
			soldier = candidate
			break
	front.player.global_position = _open_point_near(loader, soldier.global_position)
	front.player._update_nearest_interactable()
	_messages.clear()
	_check(front.player._current_interactable == soldier, "a Confederation soldier can be approached")
	_interact(front.player)
	_check(_messages.size() == 1 and _messages[0].begins_with("Confederation soldier:"), "a Confederation soldier answers when spoken to")
	_check(not front.soldiers("republic")[0].is_in_group("interactable"), "New Republic soldiers cannot be spoken to")

	# Quick save and quick load keep the Artichoke position.
	var saved_spot := _open_point_near(loader, Vector2(760, 520))
	front.player.global_position = saved_spot
	_check(_quick_save(game), "quick save on Artichoke writes a valid current-schema save")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(saved is Dictionary and saved.get("current_planet") == "artichoke" and saved.get("planet_positions", {}).size() == state.PLANETS.size(), "the save records Artichoke and every planet position")
	front.player.global_position = state.ARTICHOKE_ARRIVAL
	_quick_load(game)
	await get_tree().process_frame
	_check(game.world == front and front.player.global_position.distance_to(saved_spot) < 0.5, "quick load restores the Artichoke position")
	if saved is Dictionary:
		var untrained: Dictionary = saved.duplicate(true)
		untrained["military_stage"] = "depot"
		_check(not state._valid_save(untrained), "a save on Artichoke without graduation is rejected")
		var missing: Dictionary = saved.duplicate(true)
		missing["planet_positions"].erase("artichoke")
		_check(not state._valid_save(missing), "a current save needs the Artichoke position")

	await _check_story(game, front, ui)
	if game.world == front:
		await _check_raid(game, front, ui)
	if game.world == front:
		await _check_defense(game, front, ui)
	if game.world == front:
		await _check_ships(game, front, ui)
	if game.world != front:
		_finish(game)
		return

	# The flagship flies back to the station; the Artichoke position is kept for the next deployment.
	_check(_interact_service(front, ui, "artichoke_ship"), "E at the flagship opens the Military Transport")
	var back := _find_button(ui.modal_content, "Return to the training station")
	_check(back != null and not back.disabled, "the flagship offers the return to the training station")
	if back == null:
		_finish(game)
		return
	var departure := front.player.global_position
	back.pressed.emit()
	await get_tree().process_frame
	_check(game.world is StationWorld and state.current_planet == "station" and ui.location_label.text == "TRAINING STATION", "the flagship returns to the training station")
	var stored: Array = state.planet_positions["artichoke"]
	_check(Vector2(float(stored[0]), float(stored[1])).distance_to(departure) < 0.5, "the Artichoke departure position is stored")
	ui.open_service("station_ship", "Military Transport")
	deploy = _find_button(ui.modal_content, "Deploy to Artichoke")
	if deploy != null:
		deploy.pressed.emit()
		await get_tree().process_frame
	_check(game.world is ArtichokeWorld and game.world.player.global_position.distance_to(departure) < 0.5, "a second deployment arrives where the player left Artichoke")
	if game.world is ArtichokeWorld:
		var again := game.world as ArtichokeWorld
		var wrecked := again.cannons().size() == 2
		for cannon in again.cannons():
			wrecked = wrecked and not cannon.intact
		_check(wrecked and again.battery_cleared() and again.republic_units().is_empty(), "a new Artichoke visit shows both guns wrecked and no battery garrison")
		_check(again.fire_republic_salvo().is_empty() and again.front_status_text().contains("front is quiet"), "the silenced battery fires no more shells and the front stays quiet")
		var wrecks := again.warships().size() == 4
		for ship in again.warships():
			wrecks = wrecks and not ship.intact
		_check(wrecks and again.officer().get_interaction_text() == "Talk to General Hickey", "a new visit shows the wrecked fleet and General Hickey in command")

	_check_migration(saved)
	_finish(game)

func _check_migration(saved) -> void:
	if not saved is Dictionary:
		_check(false, "a current save exists for the migration check")
		return
	var state := GameState
	var station_save: Dictionary = saved.duplicate(true)
	station_save["schema"] = state.MILITARY_ROUND_SAVE_SCHEMA
	station_save["current_planet"] = "station"
	station_save["planet_positions"].erase("artichoke")
	station_save["planet_positions"].erase("pomidor")
	station_save["planet_positions"].erase("chvarak")
	station_save["planet_positions"].erase("engineeria")
	_check(state._valid_save(station_save), "a schema-10 station save without Artichoke stays valid")
	var on_front: Dictionary = station_save.duplicate(true)
	on_front["current_planet"] = "artichoke"
	_check(not state._valid_save(on_front), "a schema-10 save cannot be on Artichoke")
	var file := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(station_save))
	file.close()
	_check(state.load_game() and state.planet_positions.get("artichoke") == [state.ARTICHOKE_ARRIVAL.x, state.ARTICHOKE_ARRIVAL.y], "loading a schema-10 save adds the Artichoke arrival position")

func _check_raid(game: Node, front: ArtichokeWorld, ui: GameUI) -> void:
	var state := GameState
	var loader := front.tiled_loader
	var player := front.player
	# Random salvos would make the damage checks below depend on timing.
	front._shell_timer = INF
	front._counter_timer = INF
	state.restore_health()

	# The battery, its garrison and the map's minefields and wire.
	_check(front.cannons().size() == 2 and front.intact_cannon_count() == 2 and front.cannons()[0].global_position.x < front.cannons()[1].global_position.x, "the southwest battery has two intact Republic cannons")
	var garrison := front.republic_units()
	var archers := 0
	var holding := 0
	for unit in garrison:
		if unit.enemy_id == "republic_archer":
			archers += 1
			if unit.hold_ground:
				holding += 1
	_check(garrison.size() == 8 and archers == 6 and holding == 6, "eight Republic soldiers guard the battery and the archers hold their posts")
	_check(front.minefield_mines().size() == 18, "the six red marks in no man's land hide eighteen mines")
	var wire: Node2D = loader.map_objects("barbed_wire")[0]
	var wire_rect := Rect2(wire.global_position + Vector2(2, 4), TiledLoader.map_object_size(wire) - Vector2(4, 4))
	var marker: Node2D = loader.map_objects("trap_marker")[0]
	var marker_center := marker.global_position + TiledLoader.map_object_size(marker) * 0.5
	_check(loader.is_walkable_position(wire_rect.get_center()) and loader.is_walkable_position(marker_center), "barbed wire and minefield marks can be walked over")
	_check(is_equal_approx(front.movement_factor(wire_rect.get_center()), 0.4) and front.movement_factor(state.ARTICHOKE_ARRIVAL) == 1.0, "barbed wire slows movement to 40 percent")
	var wire_walk := await _walk_right(front, wire_rect.position + Vector2(3, wire_rect.size.y * 0.6))
	var open_walk := await _walk_right(front, state.ARTICHOKE_ARRIVAL)
	_check(open_walk > 8.0 and wire_walk > 0.5 and wire_walk < open_walk * 0.6, "the player walks more slowly through barbed wire")
	var detour := loader.get_walk_path(marker_center + Vector2(-56, 0), marker_center + Vector2(56, 0))
	_check(not detour.is_empty() and _closest_to_mines(front, detour) > FieldMine.TRIGGER_RADIUS, "walking routes go around buried mines")

	# After the assault Captain Vela promotes the player and briefs the raid.
	var captain := front.officer()
	_check(captain != null and captain.get_interaction_text() == "Talk to Captain Vela", "Captain Vela stands at Cauliflower Base")
	player.global_position = _open_point_near(loader, captain.global_position)
	player._update_nearest_interactable()
	_check(player._current_interactable == captain, "the captain can be approached")
	_interact(player)
	_check(ui.modal_overlay.visible and ui._active_service_id == "artichoke_officer", "talking to the captain opens the raid briefing")
	var start_button := _find_button(ui.modal_content, "Lead the trench raid")
	_check(start_button != null and _find_button(ui.modal_content, "Draw") == null and _modal_text(ui).contains("I am promoting you to Officer."), "the captain promotes the player and offers the raid; kit comes from the Arms building")
	ui.close_modal()
	_check(not front.refill_mines() and front.mine_allowance() == 0, "the Arms building issues no field mines for the raid")
	# Three mines left over from earlier, which the player may plant anywhere now.
	state.inventory["field_mine"] = 3
	_check(_quick_save(game), "a save with the service bow and field mines is valid")

	# The raid squad and its orders.
	ui.open_service("artichoke_officer", front.OFFICER_NAME)
	start_button = _find_button(ui.modal_content, "Lead the trench raid")
	if start_button != null:
		start_button.pressed.emit()
	var squad := front.raid_soldiers()
	var weapons := {}
	for raider in squad:
		weapons[raider.weapon] = int(weapons.get(raider.weapon, 0)) + 1
	_check(front.raid_active and squad.size() == 6 and weapons == {"bow": 3, "spear": 2, "sword": 1}, "starting the raid deploys three archers, two spearmen and a swordsman")
	_check(ui.job_label.text.contains("TRENCH RAID") and ui.job_label.text.contains("cannons left: 2") and ui.job_label.text.contains("6/6"), "the HUD shows the raid, the guns left and the raiders standing")
	var all_party := true
	for raider in squad:
		all_party = all_party and raider.is_in_group("party_target") and player.global_position.distance_to(raider.global_position) < 70.0
	_check(all_party, "the raiders appear beside the player and are targets for the Republic")
	for order in ["hold", "attack", "follow"]:
		_messages.clear()
		_press(front, "order_" + order)
		var obeyed := true
		for raider in squad:
			obeyed = obeyed and raider.order == order
		_check(obeyed and _messages.has("Raid squad: %s." % order.capitalize()), "%s orders every raider to %s" % [{"hold": "R", "attack": "T", "follow": "Q"}[order], order])
	var follow_from := player.global_position
	player.global_position = _open_point_near(loader, follow_from + Vector2(0, 90))
	var before := _mean_distance(squad, player.global_position)
	await _physics_frames(90)
	_check(_mean_distance(squad, player.global_position) < before - 20.0, "on follow the raiders walk after the player")

	# Trench cover: long shots at entrenched soldiers hit the parapet.
	var trench_spot := Vector2(17 * 16 + 8, 56 * 16 + 8)
	_check(front.in_trench(trench_spot) and not front.in_trench(Vector2(760, 520)), "the battery trench is recognised as cover")
	front.cover_chance = 1.0
	_check(front.shot_blocked(trench_spot + Vector2(0, -120), trench_spot) and not front.shot_blocked(trench_spot + Vector2(0, -40), trench_spot) and not front.shot_blocked(Vector2(760, 400), Vector2(760, 520)), "only long shots at a soldier in a trench are blocked")
	var target: Enemy = garrison[0]
	target.global_position = trench_spot
	target.hold_ground = true
	var health_before := target.health
	_fire_at(front, trench_spot + Vector2(0, -100), trench_spot)
	await _physics_frames(45)
	var covered := target.health == health_before
	front.cover_chance = 0.0
	_fire_at(front, trench_spot + Vector2(0, -100), trench_spot)
	await _physics_frames(45)
	_check(covered and target.health < health_before, "the trench stops a long shot that hits in the open")
	front.cover_chance = front.TRENCH_COVER_CHANCE

	# Artillery: a warning ring, then damage around the impact.
	state.restore_health()
	var salvo := front.fire_republic_salvo()
	var near_targets := salvo.size() == 2
	for shell in salvo:
		var closest := INF
		for point in front.REPUBLIC_SHELL_TARGETS:
			closest = minf(closest, shell.global_position.distance_to(point))
		near_targets = near_targets and closest <= front.SHELL_SPREAD * 1.42 and shell.get_node_or_null("WarningRing") != null and shell.time_left() > 2.0
	_check(near_targets, "each Republic gun fires one shell at the trenches, marked by a warning ring")
	for shell in salvo:
		shell.queue_free()
	var hit_shell := front.launch_shell(state.ARTICHOKE_ARRIVAL + Vector2(0, 30), true)
	player.global_position = state.ARTICHOKE_ARRIVAL + Vector2(0, 30)
	var hp := state.health
	await _seconds(front.SHELL_WARNING + 0.3)
	_check(not is_instance_valid(hit_shell) and state.health < hp, "a shell hurts the player standing in its ring")
	state.restore_health()
	var counter := front.fire_counter_battery()
	var counter_ok := false
	for point in front.COUNTER_FIRE_TARGETS:
		counter_ok = counter_ok or counter.global_position.distance_to(point) <= front.SHELL_SPREAD * 1.42
	_check(counter_ok, "Confederation guns fire back at the Republic base")
	counter.queue_free()

	# Minefields go off under anyone; the player's mines only under the Republic.
	var mines := front.minefield_mines()
	# The shell hit above leaves the player briefly invulnerable.
	player._invulnerability = 0.0
	player.global_position = mines[0].global_position
	hp = state.health
	await _physics_frames(3)
	_check(state.health < hp and front.minefield_mines().size() == 17, "stepping on a minefield mine sets it off")
	state.restore_health()
	player.global_position = state.ARTICHOKE_ARRIVAL
	var walker: Enemy = garrison[1]
	var walker_health := walker.health
	walker.global_position = mines[3].global_position
	await _physics_frames(3)
	_check(walker.health < walker_health and front.minefield_mines().size() == 16, "Republic soldiers set off minefield mines too")
	ui.open_inventory()
	var ready_button := _find_button(ui.modal_content, "Field Mine x3")
	if ready_button != null:
		ready_button.pressed.emit()
	ui.close_modal()
	_check(player.is_holding_field_mine() and player._held_mine_icon.visible, "a field mine is readied from the inventory and shown in hand")
	var plant_spot := _open_point_near(loader, Vector2(760, 520))
	player.global_position = plant_spot
	_press(player, "attack")
	var planted := front.placed_mines()
	_check(planted.size() == 1 and int(state.inventory.get("field_mine", 0)) == 2 and not planted[0].armed, "Space plants a field mine at the player's feet")
	await _seconds(1.7)
	hp = state.health
	await _physics_frames(3)
	_check(planted[0].armed and is_instance_valid(planted[0]) and state.health == hp, "the planted mine arms and does not go off under the player")
	player.global_position = state.ARTICHOKE_ARRIVAL
	var victim: Enemy = garrison[2]
	var victim_health := victim.health
	victim.global_position = plant_spot
	await _physics_frames(3)
	_check(victim.health < victim_health and front.placed_mines().is_empty(), "a Republic soldier stepping on the field mine sets it off")

	# Raid failure when the player is defeated; damaged guns are repaired.
	front.cannons()[1].take_damage(20)
	player.global_position = _open_point_near(loader, front.BATTERY_CENTER + Vector2(0, -150))
	await _physics_frames(2)
	_check(front.republic_units().size() > 8 and front._reinforcements_sent, "nearing the battery sends Republic reinforcements from the airfield")
	var marching := false
	for unit in front.republic_units():
		if unit.persistent_id.begins_with("artichoke_reinforcement_"):
			marching = marching or unit._march.size() > 1
	_check(marching, "the reinforcements march along a route towards the battery")
	_messages.clear()
	state.health = 1
	player.take_damage(50)
	await _physics_frames(2)
	_check(not front.raid_active and front.raid_soldiers().is_empty() and get_tree().get_nodes_in_group("raid_soldier").all(func(node: Node) -> bool: return node.is_queued_for_deletion()), "the raid fails and the squad is withdrawn when the player is defeated")
	_check(front.republic_units().size() == 8 and front.cannons()[1].health == BatteryCannon.MAX_HEALTH and player.global_position.distance_to(state.ARTICHOKE_ARRIVAL) < 1.0, "after a failed raid the garrison and guns are restored and the player is back at base")

	# A second raid: one gun destroyed with a charge, then every raider is downed.
	state.restore_health()
	_check(front.start_raid() and front.raid_soldiers().size() == 6, "a new raid can be started after a failure")
	var first_gun := front.cannons()[0]
	player.global_position = first_gun.get_interaction_position() + Vector2(0, 12)
	player._update_nearest_interactable()
	_check(player._current_interactable == first_gun and first_gun.get_interaction_text().contains("demolition charge"), "E at a Republic cannon offers to plant a charge")
	_interact(player)
	_check(first_gun.charge_planted and first_gun.intact, "a charge is planted with a fuse")
	player.global_position = state.ARTICHOKE_ARRIVAL
	await _seconds(front.CHARGE_FUSE + 0.3)
	_check(not first_gun.intact and front.intact_cannon_count() == 1 and state.defeated_persistent_enemies.has("artichoke_cannon_0_destroyed"), "the charge destroys the cannon and the loss is recorded")
	_check(front.fire_republic_salvo().size() == 1, "only the standing gun keeps firing")
	_messages.clear()
	for raider in front.raid_soldiers():
		raider.take_damage(100)
	_check(not front.raid_active and _messages.any(func(message: String) -> bool: return message.contains("raid has failed")), "the raid fails when all six raiders are down")
	_check(not first_gun.intact and front.intact_cannon_count() == 1, "a destroyed gun stays destroyed after a failed raid")

	# The third raid silences the battery.
	state.restore_health()
	var gold := state.gold
	front.start_raid()
	var last_gun := front.cannons()[1]
	_check(front.plant_charge(last_gun) and not front.plant_charge(last_gun), "a gun takes one charge at a time")
	await _seconds(front.CHARGE_FUSE + 0.3)
	var returning := not front.raid_soldiers().is_empty()
	for node in get_tree().get_nodes_in_group("raid_soldier"):
		returning = returning or (node as RaidSoldier).returning
	_check(front.battery_cleared() and not front.raid_active and state.gold == gold + front.RAID_REWARD, "destroying both guns completes the raid and pays the reward")
	_check(returning and ui.job_label.text.contains("massing at the airfield"), "the raiders walk back and the HUD warns of the Republic counterattack")
	_check(front.fire_republic_salvo().is_empty(), "the bombardment stops once both guns are destroyed")

	# Destroyed guns are saved.
	_check(_quick_save(game), "a save after the raid is valid")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(saved is Dictionary and saved["defeated_persistent_enemies"].has("artichoke_cannon_0_destroyed") and saved["defeated_persistent_enemies"].has("artichoke_cannon_1_destroyed"), "the save records both destroyed guns")
	state.defeated_persistent_enemies.erase("artichoke_cannon_1_destroyed")
	front.apply_loaded_state()
	_check(front.cannons()[1].intact and front.intact_cannon_count() == 1 and front.republic_units().size() == 8, "state from before the second gun fell restores that gun and its garrison")
	_quick_load(game)
	await get_tree().process_frame
	_check(game.world == front and front.battery_cleared(), "quick load brings back both wrecked guns")

func _check_defense(game: Node, front: ArtichokeWorld, ui: GameUI) -> void:
	var state := GameState
	var player := front.player
	front._counter_timer = INF
	state.restore_health()
	player.global_position = state.ARTICHOKE_ARRIVAL
	await _physics_frames(2)

	# Six field mines for the counterattack, counting those already in the ground.
	state.inventory["field_mine"] = 0
	_check(front.mine_allowance() == front.DEFENSE_MINES and front.refill_mines() and int(state.inventory.get("field_mine", 0)) == 6, "the Arms building issues six field mines for the counterattack")
	for index in 2:
		player.global_position = front._nearby_open_position(state.ARTICHOKE_ARRIVAL + Vector2(index * 40 - 20, 30))
		front.place_field_mine()
	_check(front.buried_defense_mines() == 2 and front.mine_allowance() == 4 and not front.refill_mines() and int(state.inventory.get("field_mine", 0)) == 4, "mines buried for the defense count against the six")
	player.global_position = state.ARTICHOKE_ARRIVAL

	# Captain Vela's briefing changes once the battery is gone.
	_check(front.counterattack_ready() and not front.start_raid(), "after the battery falls the counterattack is ready and no new raid starts")
	ui.open_service("artichoke_officer", front.OFFICER_NAME)
	var hold_button := _find_button(ui.modal_content, "Hold the trenches")
	_check(hold_button != null and _find_button(ui.modal_content, "Lead the trench raid") == null, "the captain offers the trench defense instead of the raid")
	if hold_button != null:
		hold_button.pressed.emit()
	var squad := front.raid_soldiers()
	_check(front.defense_active and squad.size() == 6 and front.wave_units().is_empty() and is_equal_approx(front.wave_countdown(), front.FIRST_WAVE_DELAY), "six defenders deploy and the first wave is on its way")
	_check(ui.job_label.text.contains("TRENCH DEFENSE") and ui.job_label.text.contains("Next wave in") and ui.job_label.text.contains("Breaches: 0/3"), "the HUD shows the countdown and breaches")
	_check(not front.refill_mines(), "the Arms building issues no mines during the defense")
	_messages.clear()
	_press(front, "order_hold")
	_check(squad.all(func(raider: RaidSoldier) -> bool: return raider.order == "hold") and _messages.has("Trench squad: Hold."), "R orders the defenders to hold")
	await _physics_frames(30)
	_check(front.wave_countdown() < front.FIRST_WAVE_DELAY - 0.3, "the countdown runs before the first wave")
	await _check_typed_orders(front, ui, squad)

	# A wave marches from the airfield towards both ramps.
	var wave := front.send_wave()
	var west := 0
	for unit in wave:
		var goal: Vector2 = unit._march[unit._march.size() - 1] if not unit._march.is_empty() else Vector2.INF
		if goal.distance_to(front.BREACH_POINTS[0]) < 40.0:
			west += 1
	_check(wave.size() == 4 and west == 4 and front.current_wave() == 1 and _messages.any(func(message: String) -> bool: return message.contains("for the west ramp")), "the first wave of four marches for the announced west ramp")
	var walker: Enemy = wave[0]
	var route_end: Vector2 = walker._march[walker._march.size() - 1]
	var before := walker.global_position.distance_to(route_end)
	await _physics_frames(90)
	_check(walker.global_position.distance_to(route_end) < before - 30.0, "the attackers march up the field")
	var hunter: RaidSoldier = squad[4]
	var nearest_attacker := func() -> float:
		var best := INF
		for unit in front.wave_units():
			best = minf(best, unit.global_position.distance_to(hunter.global_position))
		return best
	var gap: float = nearest_attacker.call()
	_check(front.execute_squad_order({"action": "attack", "soldier_ids": ["soldier_05"], "start": null, "end": null, "facing": null, "message": "ok", "group_name": null}, "test") and hunter.order == "hunt", "an attack order is accepted while a wave is on the field")
	await _physics_frames(60)
	_check(nearest_attacker.call() < gap - 40.0, "the attacking swordsman goes after the nearest attacker beyond his usual sight")

	# Confederation cannons shell the attackers; the shells spare the defenders.
	# Soldiers are paused here so only the shell and the mine change their health.
	state.restore_health()
	for unit in front.wave_units():
		unit.set_physics_process(false)
	for raider in squad:
		raider.set_physics_process(false)
	var support := front.fire_support_shell()
	_check(support != null and support.get_node_or_null("WarningRing") != null, "Confederation cannons fire on the advancing wave with a warning ring")
	if support != null:
		support.queue_free()
	var shelled: Enemy = wave[1]
	var shelled_health := shelled.health
	for unit in wave:
		if unit != shelled:
			unit.global_position = front._nearby_open_position(Vector2(1000, 700) + Vector2(wave.find(unit) * 20, 0))
	var squad_member: RaidSoldier = squad[0]
	squad_member.global_position = shelled.global_position + Vector2(10, 0)
	var member_health := squad_member.health
	front.launch_shell(shelled.global_position, false)
	await _seconds(front.SHELL_WARNING + 0.3)
	_check(shelled.health < shelled_health and squad_member.health == member_health, "a Confederation shell hurts the attackers and not the defenders")

	# A field mine on the attackers' path.
	var mine_spot := front._nearby_open_position(Vector2(760, 520))
	player.global_position = mine_spot
	front.set_field_mine_ready(true)
	_press(player, "attack")
	await _seconds(1.7)
	player.global_position = state.ARTICHOKE_ARRIVAL
	var stepper: Enemy = wave[2]
	var stepper_health := stepper.health
	stepper.global_position = mine_spot
	await _physics_frames(3)
	_check(is_instance_valid(stepper) and stepper.health < stepper_health and front.buried_defense_mines() == 2 and int(state.inventory.get("field_mine", 0)) == 3, "an attacker stepping on a buried mine sets it off")
	for raider in squad:
		raider.set_physics_process(true)

	# Attackers reaching the ramp tops break through; three breaches lose the trenches.
	for unit in front.wave_units():
		unit.queue_free()
	await _physics_frames(1)
	front._wave_timer = 0.01
	await _physics_frames(2)
	wave = front.wave_units()
	var ramp_counts := [0, 0]
	for unit in wave:
		for ramp in 2:
			if unit._march[unit._march.size() - 1].distance_to(front.BREACH_POINTS[ramp]) < 40.0:
				ramp_counts[ramp] += 1
	_check(front.current_wave() == 2 and wave.size() == 6 and ramp_counts == [3, 3] and ui.job_label.text.contains("to the west ramp and the east stairs") and _messages.any(func(message: String) -> bool: return message.contains("6 Republic soldiers march from the airfield for the west ramp and the east stairs")), "the second wave of six splits between the west ramp and the east stairs")
	for index in 2:
		_finish_march(wave[index])
	await _physics_frames(2)
	_check(front.breaches() == 2 and front.defense_active and front.wave_units().size() == 4 and ui.job_label.text.contains("Breaches: 2/3"), "two attackers at the ramp tops count as breaches")
	_messages.clear()
	_finish_march(wave[2])
	await _physics_frames(2)
	_check(not front.defense_active and front.wave_units().is_empty() and front.raid_soldiers().is_empty() and _messages.any(func(message: String) -> bool: return message.contains("broken into the trenches")), "the third breach loses the trenches and clears the field")
	_check(not state.defeated_persistent_enemies.has(front.DEFENSE_FLAG) and front.counterattack_ready(), "a lost defense can be tried again")
	_check(front.buried_defense_mines() == 2 and front.refill_mines() and int(state.inventory.get("field_mine", 0)) == 4, "after a lost defense the Arms building replaces the mine that went off; the two still buried are not replaced")

	# The player's defeat also loses the defense.
	front.start_defense()
	state.health = 1
	player.take_damage(50)
	await _physics_frames(2)
	_check(not front.defense_active and front.raid_soldiers().is_empty(), "the defense fails when the player is defeated")

	# Beating all four waves; fresh soldiers replace the fallen after the third.
	state.restore_health()
	var gold := state.gold
	_check(front.start_defense(), "a new defense starts after a failure")
	for wave_number in front.DEFENSE_WAVES.size():
		front._wave_timer = 0.01
		await _physics_frames(2)
		var expected: int = front.DEFENSE_WAVES[wave_number].size()
		_check(front.current_wave() == wave_number + 1 and front.wave_units().size() == expected, "wave %d brings %d soldiers" % [wave_number + 1, expected])
		var relief_wave: bool = wave_number + 1 == front.RELIEF_AFTER_WAVE
		if relief_wave:
			_messages.clear()
			for slot in [0, 2]:
				front.raid_soldiers()[slot].take_damage(500)
			await _physics_frames(1)
			_check(front.standing_raid_soldiers() == 4, "two defenders fall in the third wave")
		for unit in front.wave_units():
			unit.take_damage(500)
		await _physics_frames(2)
		if relief_wave:
			var defenders := front.raid_soldiers()
			var names: Array = defenders.map(func(raider: RaidSoldier) -> String: return raider.soldier_name)
			_check(defenders.size() == 6 and front.standing_raid_soldiers() == 6 and names.has("Halvard") and names.has("Oskar") and not names.has("Brannock") and not names.has("Corwin"), "Halvard and Oskar replace the two fallen defenders")
			_check(_messages.any(func(message: String) -> bool: return message.contains("Captain Vela sends Halvard and Oskar to replace the fallen.") and message.contains("The last and largest wave comes in 16 seconds, heading for the west ramp and the east stairs")), "the announcement names the fresh soldiers and the last wave's ramps")
			_check(front.squad_groups["bowmen"].has("soldier_01") and front._soldier_for_order_id("soldier_01").soldier_name == "Halvard" and front._soldier_for_order_id("soldier_01").weapon == "bow" and front.rewrite_order_text("Halvard and Oskar hold") == "soldier 1 and soldier 3 hold" and front.rewrite_order_text("Brannock hold") == "Brannock hold", "the fresh soldiers take the fallen soldiers' places in the groups and orders")
		if wave_number < front.DEFENSE_WAVES.size() - 1:
			var pause: float = front.RELIEF_GAP if relief_wave else front.WAVE_GAP
			_check(front.defense_active and front.wave_countdown() <= pause and front.wave_countdown() > pause - 0.5 and front.wave_units().is_empty(), "a pause of %d seconds follows wave %d" % [int(pause), wave_number + 1])
	_check(not front.defense_active and front.counterattack_repelled() and state.gold >= gold + front.DEFENSE_REWARD, "beating the fourth wave wins the defense and pays the reward")
	_check(ui.job_label.text.contains("repairing its warships") and not front.start_defense(), "the HUD sends the player to General Hickey and no new defense starts")
	_check(_messages.any(func(message: String) -> bool: return message.contains("General Hickey has landed")), "the win message says Captain Vela is gone and General Hickey has landed")
	_check(_quick_save(game), "a save after the defense is valid")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(saved is Dictionary and saved["defeated_persistent_enemies"].has(front.DEFENSE_FLAG), "the save records the beaten counterattack")
	player.global_position = state.ARTICHOKE_ARRIVAL

## Typed orders: starting groups, the request context, text rewriting, and
## interpreted orders turned into soldier tasks. The order service is not running
## in this test, so orders are passed in as the service would return them.
func _check_typed_orders(front: ArtichokeWorld, ui: GameUI, squad: Array[RaidSoldier]) -> void:
	var groups := front.squad_groups
	_check(groups.get("bowmen") == ["soldier_01", "soldier_02", "soldier_04"] and groups.get("spearmen") == ["soldier_03", "soldier_06"] and groups.get("swordsmen") == ["soldier_05"], "the defense starts with bowmen, spearmen and swordsmen groups")
	var context := front.squad_order_context()
	_check(context["soldiers"].size() == 6 and context["groups"].size() == 4 and context["groups"]["all"].size() == 6 and context["landmarks"].keys() == ["A", "B", "C"], "the order context lists six soldiers, the groups and three places")
	_check(front.rewrite_order_text("Send Petra and the archers to the east stairs") == "Send soldier 4 and the bowmen to B" and front.rewrite_order_text("swordmen hold the centre trench") == "swordsmen hold C" and front.rewrite_order_text("spearmen patrol between the west ramp and the stairs") == "spearmen patrol between A and B", "place names, soldier names and group spellings are rewritten for the order service")
	_check(front._letters_to_places("A line needs at least two soldiers.") == "A line needs at least two soldiers." and front._letters_to_places("3 soldiers move to A.") == "3 soldiers move to the west ramp.", "replies name the places but keep the article A")
	_check(front.place_markers_visible(), "the three order places are marked on the map")

	# Enter opens the order bar and stops the player; Escape closes it.
	var open := InputEventAction.new()
	open.action = "order_type"
	open.pressed = true
	ui._input(open)
	_check(ui.order_bar.visible and ui.order_input.has_focus() and front.player.ui_is_open(), "Enter opens the order bar and pauses the player's controls")
	_check(is_equal_approx(Engine.time_scale, ui.TYPING_TIME_SCALE), "the game runs at a quarter speed while the order bar is open")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	ui._input(escape)
	_check(not ui.order_bar.visible and not front.player.ui_is_open() and Engine.time_scale == 1.0, "Escape closes the order bar and the game runs at full speed again")
	# Tab completes order words, groups, names and places; Tab again shows the next match.
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	ui._input(open)
	ui.order_input.text = "bow"
	ui._input(tab)
	var first_tab := ui.order_input.text
	ui.order_input.text = "spearmen go to west r"
	ui._completion_index = -1
	ui._input(tab)
	var place_tab := ui.order_input.text
	ui.order_input.text = "f"
	ui._completion_index = -1
	ui._input(tab)
	var cycle_one := ui.order_input.text
	ui._input(tab)
	var cycle_two := ui.order_input.text
	_check(first_tab == "bowmen " and place_tab == "spearmen go to west ramp " and cycle_one == "follow " and cycle_two == "follow me ", "Tab completes order words and places, and Tab again shows the next match")
	_check(ui.order_bar.visible, "Tab keeps the order bar open")
	ui._input(escape)
	# Up and Down step through the orders sent this session.
	ui._on_order_text_submitted("hold")
	ui._on_order_text_submitted("hold")
	ui._on_order_text_submitted("stop")
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	up.pressed = true
	var down := InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	ui._input(open)
	ui._input(up)
	var last := ui.order_input.text
	ui._input(up)
	var before_last := ui.order_input.text
	ui._input(up)
	var oldest := ui.order_input.text
	ui._input(down)
	ui._input(down)
	var past_newest := ui.order_input.text
	_check(last == "stop" and before_last == "hold" and oldest == "hold" and past_newest == "" and ui.order_history.size() == 2, "Up shows earlier orders, repeats are kept once, and Down past the newest clears the bar")
	ui._input(escape)
	front.issue_order("follow")
	front.order_client.cancel()
	front.order_client.compatible = false
	_messages.clear()
	ui._on_order_text_submitted("bowmen to the west ramp")
	_check(_messages.any(func(message: String) -> bool: return message.contains("order service is not running")), "without the order service a typed order says so and Q/R/T still work")

	var order := func(action: String, ids: Array, start: Variant, end: Variant, message: String = "ok", group_name: Variant = null) -> Dictionary:
		return {"action": action, "soldier_ids": ids, "start": start, "end": end, "facing": null, "message": message, "group_name": group_name}
	var bowmen: Array[RaidSoldier] = [squad[0], squad[1], squad[3]]
	var spearmen: Array[RaidSoldier] = [squad[2], squad[5]]
	var swordsman: RaidSoldier = squad[4]
	var centre: Vector2 = front.ORDER_PLACES["C"]
	var before := _mean_distance(bowmen, centre)
	_messages.clear()
	_check(front.execute_squad_order(order.call("move_to", groups["bowmen"], null, "C"), "test"), "a move order for the bowmen is accepted")
	var spaced := true
	for first in bowmen:
		for second in bowmen:
			if first != second and first.hold_point.distance_to(second.hold_point) < 23.9:
				spaced = false
	_check(bowmen.all(func(raider: RaidSoldier) -> bool: return raider.order == "hold" and raider.hold_point.distance_to(centre) <= 96.0 and raider.task_label == "centre trench") and spaced and _messages.has("The bowmen: to the centre trench. (test)"), "the bowmen get separate places at the centre trench")
	_check(front.execute_squad_order(order.call("patrol", groups["spearmen"], "A", "B"), "test"), "a patrol order for the spearmen is accepted")
	_check(spearmen.all(func(raider: RaidSoldier) -> bool: return raider.order == "patrol" and raider.patrol_points[0].distance_to(front.ORDER_PLACES["A"]) <= 96.0 and raider.patrol_points[1].distance_to(front.ORDER_PLACES["B"]) <= 96.0), "the spearmen patrol between the west ramp and the east stairs")
	_check(front.execute_squad_order(order.call("follow_player", ["soldier_05"], null, null), "test") and swordsman.order == "follow" and _messages.has("The swordsmen: follow you."), "the swordsman follows the player")
	await _physics_frames(60)
	_check(_mean_distance(bowmen, centre) < before - 20.0, "the bowmen walk towards the centre trench")
	_check(ui.job_label.text.contains("Bowmen: centre trench") and ui.job_label.text.contains("Spearmen: patrol west ramp–east stairs") and ui.job_label.text.contains("Swordsmen: follow"), "the HUD lists each group's task")

	_messages.clear()
	_check(not front.execute_squad_order(order.call("move_to", ["soldier_09"], null, "A"), "test") and _messages.any(func(message: String) -> bool: return message.begins_with("Order not carried out")), "an order naming an unknown soldier is refused")
	_check(not front.execute_squad_order(order.call("move_to", ["soldier_01"], null, "D"), "test"), "an order naming an unknown place is refused")
	_check(front.execute_squad_order(order.call("clarify", [], null, null, "Where should they go? Name landmark A, B or C."), "test") and _messages.has("Squad: Where should they go? Name landmark the west ramp, the east stairs or the centre trench."), "a clarification is shown with the place names")
	_check(front.execute_squad_order(order.call("create_group", ["soldier_01", "soldier_03"], null, null, "ok", "left"), "test") and front.squad_groups.get("left") == ["soldier_01", "soldier_03"] and front.squad_order_context()["groups"].has("left"), "a typed order can create a new group")
	_messages.clear()
	_check(front.execute_squad_order(order.call("move_to", ["soldier_01", "soldier_03"], null, "B"), "test") and _messages.has("Group left: to the east stairs. (test)"), "a group the player made is named as a group")
	_messages.clear()
	_check(not front.execute_squad_order(order.call("form_line", context["groups"]["all"], "A", "C"), "test") and _messages.has("Order not carried out: the ground between west ramp and centre trench is not open for a line of 6. Try two other places or fewer soldiers."), "a line the trench cannot hold is refused with advice that fits the fixed places")
	_check(front.execute_squad_order(order.call("form_line", context["groups"]["all"], "A", "B"), "test") and squad.all(func(raider: RaidSoldier) -> bool: return raider.order == "hold" and raider.task_label == "line west ramp–east stairs"), "a line along the trench is accepted")

	# Attack: the nearest attackers anywhere, or those around a named place.
	_messages.clear()
	_check(front.execute_squad_order(order.call("attack", groups["bowmen"], null, null), "test") and bowmen.all(func(raider: RaidSoldier) -> bool: return raider.order == "hunt" and not raider.hunt_point.is_finite() and raider.task_label == "attack") and _messages.has("The bowmen: attack. (test) No attackers on the field yet; they wait for the next wave."), "an attack order sends the bowmen after the nearest attackers")
	_check(front.execute_squad_order(order.call("attack", groups["spearmen"], null, "B"), "test") and spearmen.all(func(raider: RaidSoldier) -> bool: return raider.order == "hunt" and raider.hunt_point == front.ORDER_PLACES["B"] and raider.hold_point.distance_to(front.ORDER_PLACES["B"]) <= 96.0 and raider.task_label == "attack east stairs") and _messages.has("The spearmen: attack at the east stairs. (test) No attackers on the field yet; they wait for the next wave."), "an attack at a place sends the spearmen to fight around the east stairs")
	await _physics_frames(2)
	_check(ui.job_label.text.contains("Bowmen: attack") and ui.job_label.text.contains("Spearmen: attack east stairs"), "the HUD shows the attack tasks")
	var bad_attack: Dictionary = order.call("attack", ["soldier_01"], "A", "B")
	_check(not front.execute_squad_order(bad_attack, "test"), "an attack with a start place is refused")

	# Places the player marks: typed, handled without the service, and used like A to C.
	var player := front.player
	var player_spot := player.global_position
	var tower := front._nearby_open_position(Vector2(330, 300))
	player.global_position = tower
	_messages.clear()
	_check(front.submit_squad_text("mark here as Tower") and front.order_places.get("D") == tower and front.order_place_names.get("D") == "tower" and _messages.has("Marked this spot as the tower. Orders can name it now."), "mark here as tower names the player's spot as place D without the order service")
	_check(front.squad_order_context()["landmarks"].keys() == ["A", "B", "C", "D"] and front.rewrite_order_text("Bowmen to the tower") == "Bowmen to D" and front._letters_to_places("2 soldiers move to D.") == "2 soldiers move to the tower.", "the marked place goes to the order service as D and replies name it")
	await _physics_frames(2)
	_check(ui.job_label.text.contains("Marked places: tower") and front._place_markers.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion()).size() == 4, "the marked place is labelled on the map and listed in the HUD")
	for refused in ["mark here as archers", "mark here as the west ramp", "mark here as attack post", "mark here as Petra", "mark here as x", "mark here as tower2"]:
		_check(not front.submit_squad_text(refused) and front.order_places.size() == 4, "%s is refused" % refused)
	player.global_position = tower + Vector2(10, 0)
	_check(not front.submit_squad_text("name this place hill") and front.order_places.size() == 4, "a place too close to another is refused")
	_messages.clear()
	_check(front.execute_squad_order(order.call("move_to", ["soldier_05"], null, "D"), "test") and swordsman.hold_point.distance_to(tower) <= 96.0 and swordsman.task_label == "tower" and _messages.has("The swordsmen: to the tower. (test)"), "soldiers can be sent to the marked place")
	var extra_spots := [Vector2(250, 300), Vector2(420, 290), Vector2(620, 296), Vector2(700, 290)]
	var extra_names := ["mill", "crater", "north gate", "well"]
	for index in extra_spots.size():
		_check(front.mark_place(extra_names[index], front._nearby_open_position(extra_spots[index])), "place %s is marked" % extra_names[index])
	_messages.clear()
	_check(not front.mark_place("bunker", front._nearby_open_position(Vector2(560, 330))) and _messages.has("Five places are already marked. Forget one first, e.g. forget tower."), "a sixth marked place is refused")
	_check(front.mark_place("tower", front._nearby_open_position(Vector2(560, 330))) and front.order_places["D"] != tower, "marking a name again moves it")
	_check(front.rewrite_order_text("spearmen patrol between the north gate and the tower") == "spearmen patrol between G and D", "longer marked names are matched before shorter ones")
	_check(not front.submit_squad_text("forget the west ramp") and front.order_places.has("A"), "the fixed places cannot be forgotten")
	for place_name in ["tower"] + extra_names:
		_check(front.submit_squad_text("forget the %s" % place_name), "forget %s removes it" % place_name)
	_check(front.order_places.keys() == ["A", "B", "C"] and front.rewrite_order_text("go to the tower") == "go to the tower", "forgotten places are no longer rewritten")
	player.global_position = player_spot

	_check(front.execute_squad_order(order.call("stop", ["soldier_03", "soldier_06"], null, null), "test") and spearmen.all(func(raider: RaidSoldier) -> bool: return raider.order == "hold" and raider.patrol_points.is_empty()), "stop makes the selected soldiers hold where they stand")
	_check(front.submit_squad_text("stop") and squad.all(func(raider: RaidSoldier) -> bool: return raider.order == "hold"), "typing stop holds everyone without the order service")
	front.squad_groups.erase("left")

## Report to Captain Vela, draw the kit, mine duty and the trench assault.
func _check_story(game: Node, front: ArtichokeWorld, ui: GameUI) -> void:
	var state := GameState
	var loader := front.tiled_loader
	var player := front.player
	front._shell_timer = INF
	state.restore_health()
	_check(front.story_stage() == "report" and ui.job_label.text.contains("Report to Captain Vela"), "a new arrival is told to report to Captain Vela")

	# The Arms building issues nothing before the player reports in.
	_check(_interact_service(front, ui, "artichoke_arms"), "E at the Arms building opens it")
	_check(_find_button(ui.modal_content, "Draw your kit") == null and _modal_text(ui).contains("Report to Captain Vela first"), "the quartermaster sends a new arrival to Captain Vela first")
	ui.close_modal()
	_check(not front.draw_kit(), "no kit is issued before reporting in")

	var captain := front.officer()
	player.global_position = _open_point_near(loader, captain.global_position)
	player._update_nearest_interactable()
	_interact(player)
	_check(_modal_text(ui).contains("Where have you been soldier, taking a piss huh?") and _modal_text(ui).contains("you are on mine placing duty"), "Captain Vela greets the new arrival and sends them to the Arms building")
	ui.close_modal()
	await _physics_frames(1)
	_check(front.story_stage() == "kit" and ui.job_label.text.contains("Arms building"), "reporting in moves the HUD on to the Arms building")

	# The kit: bow, spear, three field mines and two bandages.
	state.inventory.erase("service_bow")
	state.inventory.erase("iron_spear")
	state.inventory.erase("wood_armor")
	state.equipment["armor"] = ""
	state.inventory.erase("field_mine")
	state.inventory.erase("bandage")
	_check(_interact_service(front, ui, "artichoke_arms"), "the Arms building opens after reporting in")
	var kit := _find_button(ui.modal_content, "Draw your kit")
	_check(kit != null, "the quartermaster offers the kit")
	if kit != null:
		kit.pressed.emit()
	_check(state.inventory.has("service_bow") and state.inventory.has("iron_spear") and int(state.inventory.get("field_mine", 0)) == 3 and int(state.inventory.get("bandage", 0)) == 2, "the kit is a service bow, an iron spear, three field mines and two bandages")
	_check(state.equipment["weapon"] == "service_bow" and front.story_stage() == "mines" and not front.draw_kit(), "the issued bow is equipped, and the kit is issued once")
	_check(state.inventory.has("wood_armor") and state.equipment["armor"] == "wood_armor" and state.armor_protection() == 1, "the kit includes wooden armor, worn at once")
	_check(_interact_service(front, ui, "artichoke_arms"), "the Arms building opens again")
	var mines_button := _find_button(ui.modal_content, "Field mines (carry up to 3)")
	_check(mines_button != null and mines_button.disabled and _find_button(ui.modal_content, "Bandages (up to 2)") != null, "later visits offer field mines and bandages, up to what the kit holds")
	ui.close_modal()

	# A bandage heals 20; the Mess heals fully, but not during a mission.
	state.health = state.max_health - 30
	_check(state.use_food("bandage") and state.health == state.max_health - 10 and int(state.inventory.get("bandage", 0)) == 1, "a bandage heals 20 health")
	_check(front.refill_bandages() and int(state.inventory.get("bandage", 0)) == 2, "the Arms building replaces a used bandage")
	var cook: FrontSoldier
	for soldier in front.soldiers("confederation"):
		if soldier.service_id == front.MESS_SERVICE:
			cook = soldier
	_check(cook != null and cook.get_interaction_text() == "Talk to Mess", "the cook stands by the Mess")
	_check(_interact_service(front, ui, "artichoke_mess"), "E at the Mess opens it")
	var meal := _find_button(ui.modal_content, "Eat a hot meal")
	if meal != null:
		meal.pressed.emit()
	_check(state.health == state.max_health, "a hot meal at the Mess heals fully")

	# Mine duty: three marked spots under Republic shelling.
	ui.open_service("artichoke_officer", front.OFFICER_NAME)
	var duty := _find_button(ui.modal_content, "Go out on mine duty")
	_check(duty != null, "Captain Vela sends the player on mine duty")
	if duty != null:
		duty.pressed.emit()
	front._shell_timer = INF
	_check(front.mine_duty_active and front.mine_spot_markers_visible() and front.open_mine_spots().size() == 3 and ui.job_label.text.contains("MINE DUTY"), "mine duty marks three spots and the HUD tracks them")
	state.health = state.max_health - 10
	_check(not front.eat_mess_meal() and state.health == state.max_health - 10, "the Mess serves no meal during a mission")
	var shells := front.fire_republic_salvo()
	var on_spots := not shells.is_empty()
	for shell in shells:
		var near := false
		for spot in front.open_mine_spots():
			near = near or shell.global_position.distance_to(spot) <= front.SHELL_SPREAD * 1.2
		on_spots = on_spots and near
		shell.queue_free()
	_check(on_spots, "during mine duty the Republic battery shells the open spots")
	_check(not front.refill_mines(), "the Arms building issues no mines during mine duty")
	player.global_position = front._nearby_open_position(Vector2(760, 520))
	_check(not front.place_field_mine() and front.placed_mines().is_empty() and int(state.inventory.get("field_mine", 0)) == 3 and front.open_mine_spots().size() == 3, "during mine duty a mine can only go on a marked spot")
	player.global_position = front.mine_spots[0]
	front.place_field_mine()
	_check(front.open_mine_spots().size() == 2 and front.mine_duty_active, "a mine on a marked spot lays it")
	state.health = 1
	player.take_damage(50)
	await _physics_frames(2)
	_check(not front.mine_duty_active and front.open_mine_spots().size() == 2 and not front.mine_spot_markers_visible(), "falling ends mine duty and keeps the spot already laid")
	state.inventory["field_mine"] = 0
	_check(front.mine_allowance() == 2 and front.refill_mines() and int(state.inventory.get("field_mine", 0)) == 2, "after a failed duty the Arms building issues one mine for each open spot")
	state.restore_health()
	_check(front.start_mine_duty(), "mine duty can be started again")
	front._shell_timer = INF
	var gold := state.gold
	for index in [1, 2]:
		player.global_position = front.mine_spots[index]
		front.place_field_mine()
	_check(not front.mine_duty_active and front.story_stage() == "assault" and state.gold == gold + front.MINE_DUTY_REWARD, "laying the last spot finishes mine duty and pays the reward")
	player.global_position = state.ARTICHOKE_ARRIVAL
	for mine in front.placed_mines():
		mine.queue_free()

	# The trench assault: a randomly marked Republic soldier must fall.
	ui.open_service("artichoke_officer", front.OFFICER_NAME)
	_check(_modal_text(ui).contains("Huh, you survived. You are tougher than the last one."), "Captain Vela announces the assault")
	var join := _find_button(ui.modal_content, "Join the assault")
	if join != null:
		join.pressed.emit()
	var defenders := front.assault_units()
	var target := front.assault_target()
	_check(front.assault_active and defenders.size() == 6 and front.raid_soldiers().size() == 6 and target != null and defenders.has(target) and target.get_node_or_null("TargetMark") != null, "six Republic soldiers hold the forward trench and one is marked TARGET")
	_check(ui.job_label.text.contains("TRENCH ASSAULT"), "the HUD shows the assault")
	var trench_ok := true
	for unit in defenders:
		trench_ok = trench_ok and loader.is_walkable_position(unit.global_position) and unit.global_position.x > 960.0 and unit.global_position.x < 1240.0
	_check(trench_ok, "the Republic soldiers stand in the forward trench")
	for raider in front.raid_soldiers():
		raider.take_damage(500)
	await _physics_frames(1)
	_check(not front.assault_active and front.assault_units().is_empty() and front.raid_soldiers().is_empty() and front.story_stage() == "assault", "the assault fails when all six soldiers are down")
	_check(front.start_assault(), "the assault can be started again")
	defenders = front.assault_units()
	target = front.assault_target()
	var bystander: Enemy = defenders[0] if defenders[0] != target else defenders[1]
	bystander.take_damage(500)
	await _physics_frames(2)
	_check(front.assault_active and front.assault_units().size() == 5, "other Republic soldiers can fall without ending the assault")
	gold = state.gold
	target.take_damage(500)
	await _physics_frames(2)
	_check(not front.assault_active and front.assault_units().is_empty() and front.story_stage() == "raid" and front.is_officer() and state.gold >= gold + front.ASSAULT_REWARD, "the marked soldier's fall wins the assault, pays the reward and promotes the player")
	_check(front.republic_units().size() == 8, "only the battery garrison stays on the field after the assault")
	player.global_position = state.ARTICHOKE_ARRIVAL
	await _physics_frames(2)

## General Hickey and the strike on the four Republic warships.
func _check_ships(game: Node, front: ArtichokeWorld, ui: GameUI) -> void:
	var state := GameState
	var player := front.player
	state.restore_health()
	player.global_position = state.ARTICHOKE_ARRIVAL
	await _physics_frames(2)
	var general := front.officer()
	_check(front.story_stage() == "ships" and general != null and general.get_interaction_text() == "Talk to General Hickey" and not general.is_queued_for_deletion(), "General Hickey replaces Captain Vela after the defense")
	ui.open_service("artichoke_officer", front.officer_name())
	_check(_modal_text(ui).contains("Captain Vela deserted during the trench attacks") and _modal_text(ui).contains("highest-ranked soldier") and _modal_text(ui).contains("destroy the warships first") and _find_button(ui.modal_content, "Lead the strike") != null, "General Hickey explains the desertion and orders the strike on the warships")
	ui.close_modal()

	# The command change follows the saved flags.
	state.defeated_persistent_enemies.erase(front.DEFENSE_FLAG)
	front.apply_loaded_state()
	_check(front.officer().get_interaction_text() == "Talk to Captain Vela", "state from before the defense brings Captain Vela back")
	state.defeated_persistent_enemies.append(front.DEFENSE_FLAG)
	front.apply_loaded_state()
	_check(front.officer().get_interaction_text() == "Talk to General Hickey", "state after the defense puts General Hickey in command")

	var ships := front.warships()
	var flagship: RepublicWarship
	var escorts: Array[RepublicWarship] = []
	for ship in ships:
		if ship.mines_needed == 3:
			flagship = ship
		else:
			escorts.append(ship)
	_check(ships.size() == 4 and flagship != null and escorts.size() == 3 and escorts.all(func(ship: RepublicWarship) -> bool: return ship.mines_needed == 1 and ship.intact), "the airfield has three escorts needing one mine and a flagship needing three")
	_check(not flagship.is_in_group("interactable") and not front.plant_ship_mine(flagship), "the hulls cannot be mined before the strike")
	state.inventory["field_mine"] = 1
	_check(not front.start_ships(), "the strike needs six field mines")
	state.equip_item("wood_armor")
	_check(front.issue_strike_armor() and state.equipment.get("armor", "") == "bronze_armor", "Arms issues bronze armor for the strike and the player wears it")
	_check(front.mine_allowance() == 6 and front.refill_mines() and int(state.inventory.get("field_mine", 0)) == 6, "the Arms building issues six field mines for the strike")
	_check(front.start_ships() and front.ships_active and front.fleet_guards().size() == 10, "the strike starts and ten Republic guards stand at the airfield")
	_check(ui.job_label.text.contains("FLEET STRIKE") and ui.job_label.text.contains("4/4"), "the HUD shows the strike and the ships left")
	for guard in front.fleet_guards():
		guard.set_physics_process(false)
	var sapper := front.sapper()
	_check(front.raid_soldiers().size() == 8 and sapper != null and sapper.soldier_name == front.SAPPER_NAME and not sapper.fights and not front.raid_soldiers().has(sapper), "eight soldiers and a sapper who does not fight go on the strike")
	_check(ui.job_label.text.contains("protect " + front.SAPPER_NAME) and ui.job_label.text.contains("Alarm in") and ui.job_label.text.contains("8/8"), "the HUD shows the sapper, the alarm countdown and eight soldiers")
	_check(not flagship.is_in_group("interactable") and not front.plant_ship_mine(flagship), "only the sapper plants mines")
	var strike_context := front.squad_order_context()
	_check(front.accepts_typed_orders() and strike_context["soldiers"].size() == 8 and strike_context["groups"]["all"].size() == 8 and ui.job_label.text.contains("Enter: typed order"), "typed orders work on the strike for all eight soldiers")
	_check(front.submit_squad_text("mark here as gate") and front.order_place_names.values().has("gate") and front.submit_squad_text("forget gate") and not front.order_place_names.values().has("gate"), "the player can mark and forget a place on the strike")
	front._on_typed_order_ready({"action": "attack", "soldier_ids": ["soldier_01", "soldier_02", "soldier_04"], "start": null, "end": "A", "facing": null, "group_name": null, "message": "3 soldiers attack at A."}, "test")
	_check(front.group_task_text().contains("Bowmen: attack west ramp"), "an interpreted order is carried out on the strike")
	front.issue_order("follow")
	# A following bowman stops shooting and comes back once the player is too far away.
	var bowman: RaidSoldier = front.raid_soldiers()[0]
	var leash_guard: Enemy = front.fleet_guards()[0]
	leash_guard.set_physics_process(false)
	var leash_home := front.player.global_position
	bowman.global_position = front._nearby_open_position(leash_home + Vector2(0, 30))
	leash_guard.global_position = front._nearby_open_position(bowman.global_position + Vector2(60, 0))
	await _physics_frames(2)
	var shooting := not bowman.rejoining and bowman.velocity == Vector2.ZERO
	front.player.global_position = front._nearby_open_position(leash_home + Vector2(0, -140))
	await _physics_frames(2)
	var called_back := bowman.rejoining and bowman.velocity.length() > 0.0
	front.player.global_position = leash_home
	bowman.global_position = front._nearby_open_position(leash_home + bowman.FOLLOW_SLOTS[bowman.slot])
	await _physics_frames(2)
	_check(shooting and called_back and not bowman.rejoining, "a following soldier fights nearby enemies, walks back when the player is too far, and fights again once back")
	leash_guard.take_damage(999)
	await _physics_frames(2)

	# The sapper walks to the nearest ship that still needs a mine and plants it.
	sapper.global_position = front._nearby_open_position(escorts[0].get_interaction_position() + Vector2(0, 14))
	front._sapper_ship = null
	await _physics_frames(3)
	_check(front.sapper_ship() == escorts[0] and ui.job_label.text.contains("mining the"), "the sapper goes to the nearest ship that still needs a mine")
	await _seconds(2.0)
	_check(escorts[0].mines_planted == 0 and int(state.inventory.get("field_mine", 0)) == 6, "a mine takes the sapper several seconds")
	_check(sapper.health == front.SAPPER_HEALTH and sapper.armor == front.SAPPER_ARMOR, "Vuk has 60 health and armor 2")
	var sapper_health := sapper.health
	sapper.take_damage(1)
	await _physics_frames(2)
	_check(front._sapper_left > front.SAPPER_PLANT_TIME - 0.2 and sapper.health == sapper_health - 1, "a hit makes the sapper start the mine again")
	await _seconds(front.SAPPER_PLANT_TIME + 0.4)
	_check(escorts[0].fully_mined() and int(state.inventory.get("field_mine", 0)) == 5, "the sapper plants one of the player's mines and lights the escort's fuse")
	sapper.set_physics_process(false)
	sapper.global_position = state.ARTICHOKE_ARRIVAL
	await _seconds(front.CHARGE_FUSE + 0.3)
	_check(not escorts[0].intact and state.defeated_persistent_enemies.has(front.SHIP_FLAG % ships.find(escorts[0])) and front.intact_ship_count() == 3, "the escort is destroyed and the loss is recorded")
	var guardsmen := front.fleet_guards().filter(func(unit: Enemy) -> bool: return unit.enemy_id == "republic_guardsman")
	_check(front.fleet_alarm_raised() and guardsmen.size() == 1 and ui.job_label.text.contains("ALARM"), "the first burning ship raises the alarm and one armored guardsman marches out first")
	front._step_fleet_reinforcements(front.FLEET_GUARDSMAN_GAPS[0])
	front._step_fleet_reinforcements(front.FLEET_GUARDSMAN_GAPS[0])
	front._step_fleet_reinforcements(front.FLEET_GUARDSMAN_GAPS[0])
	var sent := front._fleet_reinforcements.map(func(unit: Enemy) -> String: return unit.enemy_id)
	_check(sent.count("republic_guardsman") == 1 + 2 + 2 + 4 and sent.size() > 11 and sent.has("republic_archer") and sent.has("republic_spearman") and sent.has("republic_swordsman"), "guardsmen follow in groups of two, two and four, with archers, spearmen and swordsmen between them")
	guardsmen = front.fleet_guards().filter(func(unit: Enemy) -> bool: return unit.enemy_id == "republic_guardsman")
	_check(guardsmen.all(func(unit: Enemy) -> bool: return unit.max_health == 60 and int(unit.definition.get("damage", 0)) == 8 and int(unit.definition.get("armor", 0)) == 4), "guardsmen have more health and heavier armor than other Republic soldiers")
	var player_spot := front.player.global_position
	front.player.global_position = front._nearby_open_position(escorts[2].get_interaction_position() + Vector2(0, 20))
	front._send_reinforcement("republic_guardsman", 0, 1)
	var runner: Enemy = front._fleet_reinforcements.back()
	var route_end: Vector2 = runner._march[runner._march.size() - 1]
	_check(route_end.distance_to(sapper.global_position) < 40.0 and route_end.distance_to(front.player.global_position) > 100.0, "reinforcements march to Vuk, not to the player")
	front.player.global_position = player_spot
	for guard in front.fleet_guards():
		guard.set_physics_process(false)

	# The flagship takes three; the strike fails when the sapper falls.
	await _sapper_plant(front, flagship)
	await _sapper_plant(front, flagship)
	_check(flagship.mines_planted == 2 and flagship.intact and not flagship.fully_mined(), "two mines on the flagship are not enough")
	state.add_item("field_mine")
	_check(front._finish_ship_mine(escorts[1]) and escorts[1].fully_mined(), "a mine on an escort lights its fuse")
	_messages.clear()
	sapper.take_damage(999)
	await _physics_frames(2)
	_check(not front.ships_active and flagship.mines_planted == 0 and flagship.intact and escorts[0].intact and front.intact_ship_count() == 4 and not state.defeated_persistent_enemies.has(front.SHIP_FLAG % ships.find(escorts[0])) and front.fleet_guards().is_empty() and front.raid_soldiers().is_empty() and front.sapper() == null and _messages.any(func(message: String) -> bool: return message.contains("nobody else can plant")), "the strike fails when the sapper falls; the Republic repairs the destroyed escort and clears the flagship's mines")
	await _seconds(front.CHARGE_FUSE + 0.3)
	_check(escorts[1].intact and front.intact_ship_count() == 4 and not state.defeated_persistent_enemies.has(front.SHIP_FLAG % ships.find(escorts[1])), "a fuse still burning when the strike fails does not destroy the repaired ship")
	front.refill_mines()
	_check(front.start_ships() and not front.fleet_alarm_raised(), "the strike can be started again, with the alarm reset")
	for guard in front.fleet_guards():
		guard.set_physics_process(false)
	for count in 3:
		await _sapper_plant(front, flagship)
	_check(flagship.fully_mined() and flagship.intact, "the third mine lights the flagship's fuse")
	await _sapper_plant(front, escorts[0])
	await _sapper_plant(front, escorts[1])
	await _sapper_plant(front, escorts[2])
	front.sapper().set_physics_process(false)
	front.sapper().global_position = state.ARTICHOKE_ARRIVAL
	var gold := state.gold
	_messages.clear()
	await _seconds(front.CHARGE_FUSE + 0.3)
	_check(front.intact_ship_count() == 0 and not front.ships_active and front.story_stage() == "debrief" and state.gold >= gold + front.FLEET_REWARD, "destroying every warship wins the strike and pays the reward")
	_check(_messages.any(func(message: String) -> bool: return message.contains("General Hickey sends")), "General Hickey reports the burning fleet")
	# General Hickey's debrief promotes the player to Captain and sends them to Pomidor.
	_check(front.player_rank() == "Officer" and ui.job_label.text.contains("Report to General Hickey"), "after the fleet strike the HUD sends the Officer to General Hickey")
	ui.open_service("artichoke_officer", front.officer_name())
	var debrief := _modal_text(ui)
	_check(_find_button(ui.modal_content, "Lead the strike") == null and debrief.contains("bravery") and debrief.contains("From today you are Captain") and debrief.contains("Go to Pomidor"), "General Hickey praises the player, promotes them to Captain and sends them to Pomidor")
	ui.close_modal()
	_check(front.story_stage() == "done" and front.player_rank() == "Captain" and ui.job_label.text.contains("front is quiet") and ui.job_label.text.contains("Council on Pomidor"), "the HUD shows the quiet front and the Captain's order to report to the Council on Pomidor")
	ui.open_service("artichoke_officer", front.officer_name())
	_check(_modal_text(ui).contains("Still here, Captain?"), "later visits remind the Captain of the Council")
	ui.close_modal()

	# Wrecks and the promotion are saved.
	_check(_quick_save(game), "a save after the strike is valid")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
	_check(saved is Dictionary and saved["defeated_persistent_enemies"].has(front.FLEET_FLAG) and saved["defeated_persistent_enemies"].has(front.CAPTAIN_FLAG) and saved["defeated_persistent_enemies"].has(front.SHIP_FLAG % ships.find(flagship)), "the save records the destroyed fleet and the promotion")
	for flag in [front.CAPTAIN_FLAG, front.FLEET_FLAG, front.SHIP_FLAG % ships.find(flagship)]:
		state.defeated_persistent_enemies.erase(flag)
	front.apply_loaded_state()
	_check(flagship.intact and front.intact_ship_count() == 1 and front.story_stage() == "ships", "state from before the flagship fell restores it")
	_quick_load(game)
	await get_tree().process_frame
	_check(game.world == front and front.intact_ship_count() == 0 and front.story_stage() == "done" and front.player_rank() == "Captain", "quick load brings back the wrecked fleet and the Captain's rank")

	# A save made before the story existed, with a cannon down, skips the new early steps.
	var flags: Array = state.defeated_persistent_enemies.duplicate()
	state.defeated_persistent_enemies.assign(["artichoke_cannon_0_destroyed"])
	front.apply_loaded_state()
	_check(front.story_stage() == "raid" and front.is_officer(), "an older save with a destroyed cannon starts at the raid")
	state.defeated_persistent_enemies.assign(flags)
	front.apply_loaded_state()
	player.global_position = state.ARTICHOKE_ARRIVAL

## Puts the sapper beside `ship` and lets him plant one mine without the wait.
func _sapper_plant(front: ArtichokeWorld, ship: RepublicWarship) -> void:
	var sapper := front.sapper()
	sapper.set_physics_process(false)
	sapper.global_position = ship.get_interaction_position() + Vector2(0, 14)
	front._sapper_ship = ship
	front._sapper_health = sapper.health
	front._sapper_left = 0.01
	await _physics_frames(2)

func _modal_text(ui: GameUI) -> String:
	var parts: Array[String] = []
	for node in ui.modal_content.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)

func _finish_march(unit: Enemy) -> void:
	unit.global_position = unit._march[unit._march.size() - 1]
	unit._march_index = unit._march.size()

func _walk_right(front: ArtichokeWorld, from: Vector2) -> float:
	front.player.global_position = from
	front.player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	Input.action_press("move_right")
	await _physics_frames(10)
	Input.action_release("move_right")
	return front.player.global_position.x - from.x

func _closest_to_mines(front: ArtichokeWorld, path: PackedVector2Array) -> float:
	var closest := INF
	for mine in front.minefield_mines():
		for index in range(1, path.size()):
			closest = minf(closest, Geometry2D.get_closest_point_to_segment(mine.global_position, path[index - 1], path[index]).distance_to(mine.global_position))
	return closest

func _mean_distance(squad: Array[RaidSoldier], point: Vector2) -> float:
	var total := 0.0
	for raider in squad:
		total += raider.global_position.distance_to(point)
	return total / maxf(1.0, squad.size())

func _fire_at(front: ArtichokeWorld, origin: Vector2, target: Vector2) -> void:
	var shot := Projectile.new()
	front.actors_root.add_child(shot)
	shot.configure(origin, (target + Vector2(0, -3) - origin).normalized(), 10, 400.0, origin.distance_to(target) + 30.0, true)

func _press(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)

func _physics_frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame

func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true, true).timeout

func _object_counts(loader: TiledLoader) -> Dictionary:
	var counts := {}
	for child in loader._object_root.get_children():
		var name := String(child.get_meta("object_name", child.name))
		counts[name] = int(counts.get(name, 0)) + 1
	return counts

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
	var at := fixture.get_interaction_position()
	world.player.global_position = _open_point_near(world.tiled_loader, at)
	world.player._update_nearest_interactable()
	if world.player._current_interactable != fixture:
		return false
	_interact(world.player)
	return ui.modal_overlay.visible and ui._active_service_id == id

func _quick_save(game: Node) -> bool:
	var event := InputEventAction.new()
	event.action = "quick_save"
	event.pressed = true
	game._unhandled_input(event)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	return saved is Dictionary and int(saved.get("schema", -1)) == GameState.SAVE_SCHEMA and GameState._valid_save(saved)

func _quick_load(game: Node) -> void:
	var event := InputEventAction.new()
	event.action = "quick_load"
	event.pressed = true
	game._unhandled_input(event)

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

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		printerr("FAIL ", description)

func _finish(game: Node) -> void:
	print("Artichoke smoke: %d checks, %d failures" % [checks, failures])
	if game != null:
		remove_child(game)
		game.free()
	get_tree().quit(0 if failures == 0 else 1)
