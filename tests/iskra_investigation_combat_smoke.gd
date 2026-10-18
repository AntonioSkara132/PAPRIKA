extends Node

const Data = preload("res://scripts/world/iskra_investigation_data.gd")

var game: Node
var world: IskraWorld
var investigation: RefCounted
var encounters: RefCounted
var ui: GameUI
var checks := 0
var failures := 0
var live_hits := {"player": 0, "davor": 0, "allies": 0}
var live_phases := 0
var live_teleports := 0
var live_respawns := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		_check(false, "isolated save directory required")
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
	investigation = world.investigation
	encounters = investigation.encounters
	Engine.time_scale = 2.0
	_check(world.davor.max_health == 260 and world.davor.strike_damage == 30 and world.davor.speed == 100.0 and world.davor.can_leap and world.davor.get_up_seconds == 10.0, "Davor keeps existing strength and abilities")
	await _assassin_cases()
	await _live_capture()
	await _gang_cases()
	await _banishing_roko()
	await _live_assault()
	_finish()

func _assassin_cases() -> void:
	_reset()
	_enter("hall")
	world.davor.set_physics_process(false)
	_check(encounters.begin_assassin("davor"), "false officer prepares one arrow when Davor is insisted upon")
	var attacker: Node2D = encounters.enemies.assassin
	_check(attacker.mode == "shoot" and attacker.is_in_group("damageable"), "attacker remains physically vulnerable before firing")
	var before := attacker.global_position
	world.player.global_position = world.marker("inv_hall_arrival")
	await get_tree().create_timer(0.3).timeout
	_check(attacker.global_position.distance_to(before) > 5.0, "attacker walks toward service exit")
	ui.play_scene([{"speaker": "Test", "text": "The chase pauses for dialogue."}])
	before = attacker.global_position
	var remaining := float(GameState.iskra_investigation_state.assassin_seconds)
	await get_tree().create_timer(0.4).timeout
	_check(attacker.global_position == before and GameState.iskra_investigation_state.assassin_seconds == remaining, "dialogue pauses chase movement and clock")
	ui.cancel_scene()
	world.player.global_position = world.tiled_loader.nearest_walkable_position(attacker.global_position + Vector2(0, 20))
	_check(encounters.capture_assassin(), "nearby player catches fleeing attacker")
	_check(investigation.has("assassin_captured") and attacker.mode == "captured" and not attacker.is_in_group("damageable"), "capture records outcome and removes combat targeting")
	_check(not encounters.capture_assassin(), "capture cannot repeat")
	_check(encounters.evidence_position().distance_to(attacker.global_position) < 1.0, "captured uniform remains at physical capture position")
	await _save_reload()
	_check(investigation.has("assassin_captured") and encounters.enemies.assassin.mode == "captured", "capture and actor location survive reload")
	_reset()
	_enter("hall")
	world.davor.set_physics_process(false)
	_check(encounters.begin_assassin("order"), "requesting written order starts arrow attack")
	attacker = encounters.enemies.assassin
	_check(attacker.mode == "shoot", "officer prepares arrow after false summons fails")
	attacker.take_damage(999, world.player.global_position)
	_check(investigation.has("assassin_killed") and not investigation.has("assassin_captured"), "lethal damage produces exclusive death outcome")
	var evidence: Vector2 = encounters.evidence_position()
	await _save_reload()
	_check(not encounters.enemies.has("assassin") and encounters.evidence_position() == evidence, "dead attacker stays dead and uniform remains after reload")
	_reset()
	_enter("hall")
	world.davor.set_physics_process(false)
	_check(encounters.begin_assassin("davor"), "start physical escape case")
	attacker = encounters.enemies.assassin
	world.player.global_position = world.marker("inv_hall_room12")
	var elapsed := 0.0
	while elapsed < 18.0 and not investigation.has("assassin_escaped"):
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	_check(investigation.has("assassin_escaped"), "attacker physically reaches service exit")
	_check(encounters.evidence_position().distance_to(world.marker("inv_hall_escape")) < 1.0, "escaping attacker leaves uniform at service exit")
	_check(not investigation.has("assassin_killed") and not investigation.has("assassin_captured"), "escape outcome excludes death and capture")
	await _save_reload()
	_check(not encounters.enemies.has("assassin") and investigation.has("assassin_escaped"), "escaped attacker is not spawned again")
	_reset()
	_enter("hall")
	world.davor.set_physics_process(false)
	encounters.begin_assassin("order")
	attacker = encounters.enemies.assassin
	attacker.take_damage(60, world.player.global_position)
	_check(attacker.mode == "surrendered" and not attacker.is_in_group("damageable"), "wounded surviving attacker surrenders")
	world.player.global_position = world.tiled_loader.nearest_walkable_position(attacker.global_position + Vector2(0, 20))
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == attacker, "surrendered attacker is selectable with E")
	await _capture("attacker_surrender")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	_check(investigation.has("assassin_captured"), "E interaction captures surrendered attacker")
	ui.cancel_scene()

func _live_capture() -> void:
	_reset()
	_enter("hall")
	world.player.global_position = world.marker("inv_hall_attacker") + Vector2(0, 32)
	world._move_davor()
	world.davor.get_up()
	world.davor.health = world.davor.max_health
	world.davor.set_physics_process(true)
	_check(encounters.begin_assassin("order"), "written-order choice starts capture attempt with Davor active")
	await get_tree().process_frame
	Input.action_press("move_right")
	await get_tree().create_timer(0.15).timeout
	_release_movement()
	var attacker: Node2D = encounters.enemies.assassin
	var origin := world.player.global_position
	var elapsed := 0.0
	while elapsed < 12.0 and is_instance_valid(attacker) and attacker.mode in ["attack", "flee", "surrendered"]:
		_release_movement()
		var offset := attacker.global_position - world.player.global_position
		if offset.length() > 25.0:
			var path: PackedVector2Array = world.tiled_loader.get_walk_path(world.player.global_position, attacker.global_position)
			if path.size() > 1:
				offset = path[1] - world.player.global_position
			_move_input(offset)
		if attacker.mode in ["flee", "surrendered"]:
			_send_action("interact")
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_release_movement()
	_check(investigation.has("assassin_captured"), "normal movement and E capture attacker with unchanged Davor fighting")
	_check(world.player.global_position.distance_to(origin) > 5.0, "capture attempt physically approaches the attacker")
	if is_instance_valid(attacker) and attacker.mode == "captured":
		var health: int = attacker.health
		_check(world.davor._choose_target(180.0) != attacker, "Davor immediately excludes captured attacker from targeting")
		await get_tree().create_timer(1.5).timeout
		_check(attacker.health == health and health > 0, "captured attacker survives Davor and arrows already in flight")
		await _capture("live_capture")
	print("LIVE_CAPTURE seconds=", elapsed, " captured=", investigation.has("assassin_captured"), " phase=", GameState.iskra_investigation_state.get("assassin_phase"), " player=", world.player.global_position, " attacker=", attacker.global_position if is_instance_valid(attacker) else Vector2.ZERO)
	await _capture("live_capture_outcome")

func _gang_cases() -> void:
	_reset()
	_enter("squirrel")
	world.davor.set_physics_process(false)
	_check(encounters.enemies.size() == 6, "six visible Squirrel guards surround neutral boss meeting")
	var tvrdium := 0
	for actor in encounters.enemies.values():
		_check(actor.mode == "idle" and not actor.is_in_group("damageable"), "meeting guard does not attack before player choice")
		if actor.definition.damage == 14:
			tvrdium += 1
	_check(tvrdium == 3, "three of six guards have stronger tvrdium weapons")
	_check(encounters.begin_fight("direct"), "direct boss confrontation begins")
	_check(encounters.enemies.size() == 7 and encounters.allies.is_empty(), "direct fight has boss and six guards without hired allies")
	_check(not encounters.begin_fight("direct"), "repeating attack choice does not reset encounter")
	world.davor.set_physics_process(true)
	ui.play_scene([{"speaker": "Test", "text": "Everyone pauses during this conversation."}])
	encounters.step(0.0)
	var davor_position := world.davor.global_position
	await get_tree().create_timer(0.4).timeout
	if world.davor.global_position != davor_position or world.davor.is_physics_processing():
		print("DIALOGUE_PAUSE before=", davor_position, " after=", world.davor.global_position, " physics=", world.davor.is_physics_processing(), " ui=", world.player.ui_is_open(), " mode=", encounters._visible_site, " paused=", encounters._davor_paused, " leap=", world.davor.leaping())
	_check(world.davor.global_position == davor_position and not world.davor.is_physics_processing(), "Davor also pauses during encounter dialogue")
	ui.cancel_scene()
	encounters.step(0.0)
	_check(world.davor.is_physics_processing(), "dialogue restores Davor's prior processing state")
	world.davor.set_physics_process(false)
	var guard: Node2D = encounters.enemies.squirrel_guard_0
	guard.take_damage(5, world.player.global_position)
	var saved_health: int = guard.health
	await _save_reload()
	world.davor.set_physics_process(false)
	_check(encounters.enemies.squirrel_guard_0.health == saved_health, "injured guard health survives reload")
	_check(GameState.iskra_investigation_state.encounter == "squirrel", "active confrontation survives reload")
	GameState.iskra_investigation_state.actors.squirrel_guard_0.x = GameState.ISKRA_ARRIVAL.x
	GameState.iskra_investigation_state.actors.squirrel_guard_0.y = GameState.ISKRA_ARRIVAL.y
	GameState.iskra_investigation_state.actors.squirrel_guard_0.mode = "captured"
	encounters.apply_loaded_state()
	_check(encounters.enemies.squirrel_guard_0.global_position == world.marker("inv_squirrel_guard_0"), "saved guard outside its own room returns to its room marker")
	_check(encounters.enemies.squirrel_guard_0.mode == "attack", "saved guard mode cannot make active confrontation unwinnable")
	guard = encounters.enemies.squirrel_guard_0
	guard.take_damage(999, Vector2.ZERO)
	var gold := GameState.gold
	await get_tree().process_frame
	await _save_reload()
	world.davor.set_physics_process(false)
	_check(not encounters.enemies.has("squirrel_guard_0") and GameState.gold == gold, "dead guard does not revive or pay twice")
	_enter("owner")
	_check(encounters.enemies.is_empty() and encounters.allies.is_empty(), "retreat removes remote encounter actors")
	_enter("squirrel")
	world.davor.set_physics_process(false)
	_check(not encounters.enemies.has("squirrel_guard_0"), "return after retreat preserves completed guard death")
	for id: String in encounters.enemies.keys():
		if id.begins_with("squirrel_guard_"):
			encounters.enemies[id].take_damage(999, Vector2.ZERO)
	_check(investigation.has("squirrel_cleared"), "defeating all six guards resolves confrontation")
	var boss: Node2D = encounters.enemies.squirrel_boss
	_check(boss.mode == "surrendered" and not boss.is_in_group("damageable"), "ordinary boss surrenders after losing guards")
	world.player.global_position = world.tiled_loader.nearest_walkable_position(boss.global_position + Vector2(0, 20))
	world._move_davor()
	world.davor.set_physics_process(false)
	await _capture("squirrel_surrender")
	ui.cancel_scene()
	_check(encounters.finish_surrendered_boss(), "player can choose lethal boss outcome")
	_check(investigation.has("squirrel_boss_killed"), "boss death recorded for evidence fallback")
	await _save_reload()
	_check(not encounters.enemies.has("squirrel_boss"), "dead boss remains absent after load")
	_reset()
	investigation.set_flag("pelicans_warned")
	_enter("squirrel")
	world.davor.set_physics_process(false)
	_check(encounters.begin_fight("pelican"), "Pelican-backed confrontation starts")
	_check(encounters.allies.size() == 3, "Pelican boss supplies three ordinary allies")
	var ally: Node2D = encounters.allies.pelican_ally_0
	var before := ally.global_position
	await get_tree().create_timer(0.6).timeout
	_check(ally.global_position.distance_to(before) > 5.0, "support fighter physically advances toward hostile guards")
	_check(ally.max_health == 38 and ally.strike_damage == 8 and not ally.can_leap, "support remains ordinary rather than hacker strength")
	ally.take_damage(999, Vector2.ZERO)
	await _save_reload()
	world.davor.set_physics_process(false)
	_check(encounters.allies.pelican_ally_0.down and encounters.allies.pelican_ally_0.health == 0, "downed ally does not heal on reload")
	_check(not encounters.allies.pelican_ally_0.is_in_group("party_target"), "downed ally is excluded from enemy targets")
	GameState.iskra_investigation_state.actors.pelican_ally_1.x = GameState.ISKRA_ARRIVAL.x
	GameState.iskra_investigation_state.actors.pelican_ally_1.y = GameState.ISKRA_ARRIVAL.y
	encounters.apply_loaded_state()
	_check(encounters.allies.pelican_ally_1.global_position == world.marker("inv_squirrel_ally_1"), "saved ally outside encounter room returns to its support marker")
	var dead_id := "squirrel_guard_5"
	encounters.enemies[dead_id].take_damage(999, Vector2.ZERO)
	encounters.on_respawn()
	world.davor.set_physics_process(false)
	_check(world.player.global_position == world.marker("inv_squirrel_arrival"), "knockout returns to safe encounter entrance")
	_check(not encounters.enemies.has(dead_id), "knockout does not revive defeated guards")
	_check(encounters.allies.pelican_ally_0.down, "knockout preserves downed supporting fighter")
	_reset()
	investigation.set_flag("deal_accepted")
	world.player.global_position = world.marker("inv_rendezvous")
	encounters.stage_allies("squirrel")
	_check(encounters.allies.size() == 3, "Squirrel allies assemble at rendezvous")
	for member in encounters.allies.values():
		_check(member.staged and not member.fights, "rendezvous ally waits for explicit assault")
	encounters.stage_allies("pelican")
	_check(encounters.allies.has("pelican_ally_0") and not encounters.allies.has("squirrel_ally_0"), "changing sides removes the former faction's allies")
	_enter("pelican")
	world.davor.set_physics_process(false)
	_check(encounters.begin_fight("squirrel"), "Squirrel-supported assault starts at Pelican rooms")
	_check(encounters.allies.has("squirrel_ally_0") and not encounters.allies.has("pelican_ally_0"), "chosen assault has only its matching support")
	var hacker: Node2D = encounters.enemies.pelican_hacker
	_check(hacker.max_health == Data.HACKER_STATS.max_health and hacker.definition.damage == Data.HACKER_STATS.damage and hacker.enemy_id == "phase_hacker", "named hacker retains later strength and phase behavior")
	_check(hacker.max_health > 150 and hacker.definition.damage >= 24, "Pelican hacker exceeds early and Chvarak hacker profiles")
	_check(hacker._display_name() == Data.HACKER_STATS.name, "named hacker does not display generic phase-hacker title")
	var hacker_position := hacker.global_position
	hacker._phase_destination = Data.ROOMS.squirrel.get_center()
	hacker._finish_phase()
	_check(hacker.global_position == hacker_position, "hacker teleport cannot leave its encounter interior")
	await _roko_powers(hacker)
	await _capture("pelican_assault")
	for actor_id: String in encounters.enemies.keys():
		if actor_id != "pelican_hacker":
			encounters.enemies[actor_id].take_damage(999, Vector2.ZERO)
	_check(hacker.mode == "idle" and not hacker.is_in_group("damageable"), "Roko waits at the far wall while guards stand")
	encounters.step(0.0)
	_check(hacker.mode == "attack", "Roko joins the fight once his guards are down")
	hacker.take_damage(9999, Vector2.ZERO)
	encounters.step(0.0)
	_check(investigation.has("pelican_cleared") and investigation.has("hacker_killed"), "hacker and defender defeat completes agreed assault")
	await _save_reload()
	_check(encounters.enemies.is_empty(), "completed assault does not respawn enemies")
	_check(Data.valid_state(GameState.iskra_investigation_state), "all captured encounter state passes strict save validation")

func _roko_powers(hacker: Node2D) -> void:
	var guard: Node2D = encounters.enemies.pelican_guard_0
	var point := world.player.global_position
	hacker._trail().walked_to(point)
	_check(is_equal_approx(world.movement_factor(point, world.player), IskraTarTrail.SLOW_FACTOR), "tar halves the MC's walking speed")
	_check(is_equal_approx(world.movement_factor(point, world.davor), IskraTarTrail.SLOW_FACTOR), "tar slows Davor as well")
	_check(is_equal_approx(world.movement_factor(point, guard), 1.0), "guards walk through tar at full speed")
	hacker._trail().walked_to(point + Vector2(10, 0))
	_check(hacker.tar_trail.patches.size() == 1, "tar is dropped only after walking a puddle's width")
	hacker._trail().jumped_to(point + Vector2(200, 0))
	hacker._trail().walked_to(point + Vector2(210, 0))
	_check(hacker.tar_trail.patches.size() == 1, "a teleport leaves no tar along the jump")
	hacker.tar_trail._physics_process(IskraTarTrail.PATCH_SECONDS + 0.1)
	_check(hacker.tar_trail.patches.is_empty() and is_equal_approx(world.movement_factor(point, world.player), 1.0), "tar dries up after six seconds")
	var fired := [0]
	hacker.ring_fired.connect(func(_id: String) -> void: fired[0] += 1)
	var projectiles_before := _hostile_projectiles()
	hacker._start_ring()
	_check(hacker._ring_warning_left > 0.0 and is_instance_valid(hacker._ring_marker), "ring shows a warning before firing")
	hacker._fire_ring()
	_check(fired[0] == 1 and _hostile_projectiles() - projectiles_before == hacker.RING_ARROWS, "ring looses sixteen arrows in every direction")
	for node in world.actors_root.get_children():
		if node is Projectile and not node.from_player:
			node.queue_free()
	# Surrounded by Davor and the MC, Roko teleports to a spot away from both.
	var center: Vector2 = hacker.global_position
	world.player.global_position = center + Vector2(-20, 0)
	world.davor.global_position = center + Vector2(20, 0)
	hacker.set_mode("attack")
	hacker._start_roko_phase(world.player)
	var destination: Vector2 = hacker._phase_destination
	_check(hacker.state == Enemy.State.PHASE_WARNING and destination.distance_to(world.player.global_position) > 44.0 and destination.distance_to(world.davor.global_position) > 44.0, "surrounded Roko teleports clear of his attackers")
	hacker._clear_phase_warning()
	hacker.state = Enemy.State.IDLE
	hacker.set_mode("idle")
	hacker.global_position = center
	world.player.global_position = point
	world._move_davor()

func _banishing_roko() -> void:
	_reset()
	GameState.add_item("banishing_arrow")
	_check(not encounters.fire_player_arrow() and GameState.inventory.get("banishing_arrow", 0) == 1, "Banishing Arrow is kept when there is no fight")
	investigation.set_flag("deal_accepted")
	_enter("pelican")
	_check(encounters.begin_fight("squirrel"), "start Pelican fight for Banishing Arrow")
	for actor_id: String in encounters.enemies.keys():
		if actor_id != "pelican_hacker":
			encounters.enemies[actor_id].take_damage(999, Vector2.ZERO)
	encounters.step(0.0)
	var hacker: Node2D = encounters.enemies.pelican_hacker
	_check(hacker.mode == "attack" and hacker.ward_left() == hacker.WARD, "Roko starts the fight with his ward intact")
	hacker.set_physics_process(false)
	world.davor.set_physics_process(false)
	for ally in encounters.allies.values():
		ally.set_physics_process(false)
		ally.global_position = hacker.global_position + Vector2(0, 90)
	# Davor stands closest to Roko, so Roko is fighting Davor and cannot dodge.
	world.davor.global_position = hacker.global_position + Vector2(0, 26)
	world.player.global_position = hacker.global_position + Vector2(-70, 0)
	world.player.facing = Vector2.RIGHT
	_check(encounters.fire_player_arrow() and GameState.inventory.get("banishing_arrow", 0) == 0, "F spends the single Banishing Arrow")
	await _arrow_lands()
	_check(hacker.health == hacker.max_health, "an intact ward swallows the Banishing Arrow")
	_check(not encounters.fire_player_arrow(), "no second arrow without another in the inventory")
	hacker.take_damage(hacker.WARD + 10, world.davor.global_position)
	_check(hacker.ward_left() == 0 and hacker.health > 0, "damage breaks the ward before it kills Roko")
	# Roko fighting the MC sees the arrow and teleports away.
	world.davor.global_position = hacker.global_position + Vector2(0, 120)
	_check(hacker.dodge_banishing(world.player), "Roko dodges an arrow while he is fighting the MC")
	hacker._clear_phase_warning()
	hacker.state = Enemy.State.CHASE
	world.davor.global_position = hacker.global_position + Vector2(0, 26)
	_check(not hacker.dodge_banishing(world.player), "Roko cannot dodge while he is fighting Davor")
	GameState.add_item("banishing_arrow")
	encounters.fire_player_arrow()
	await _arrow_lands()
	encounters.step(0.0)
	# The finished fight removes Roko, so only the recorded death is checked.
	_check((not is_instance_valid(hacker) or hacker.health == 0) and investigation.has("hacker_killed") and investigation.has("pelican_cleared"), "Banishing Arrow kills Roko once his ward is broken")
	_check(GameState.health == GameState.max_health, "the MC's arrow does not hit the MC")

func _arrow_lands() -> void:
	for frame in 120:
		if not is_instance_valid(encounters.player_arrow):
			return
		await get_tree().physics_frame

func _hostile_projectiles() -> int:
	var count := 0
	for node in world.actors_root.get_children():
		if node is Projectile and not node.from_player and not node.is_queued_for_deletion():
			count += 1
	return count

func _live_assault() -> void:
	_reset()
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH
	GameState.restore_health()
	GameState.add_item("iron_sword")
	GameState.add_item("tvrdium_armor")
	GameState.add_item("bandage", 10)
	GameState.equip_item("iron_sword")
	GameState.equip_item("tvrdium_armor")
	investigation.set_flag("deal_accepted")
	_enter("pelican")
	world.player._invulnerability = 0.0
	_check(GameState.max_health == 28 and world.player.damage_scale == 1.0, "live assault uses normal captain health and unscaled incoming damage")
	var foods_before := _food_count()
	world.davor.get_up()
	world.davor.health = world.davor.max_health
	world.davor.fights = true
	world.davor.set_physics_process(true)
	world.player.respawned.connect(func() -> void: live_respawns += 1)
	live_respawns = 0
	_check(encounters.begin_fight("squirrel"), "start live assault at normal player and companion stats")
	for actor in encounters.enemies.values():
		actor.damaged.connect(_live_damage)
	encounters.enemies.pelican_hacker.phased.connect(func(_id: String) -> void: live_phases += 1)
	encounters.enemies.pelican_hacker.phase_completed.connect(func(_id: String) -> void: live_teleports += 1)
	var rings := [0]
	encounters.enemies.pelican_hacker.ring_fired.connect(func(_id: String) -> void: rings[0] += 1)
	# The fight comes to the player, so measure the path walked rather than the distance from the start.
	var last_position := world.player.global_position
	var walked := 0.0
	var largest_step := 0.0
	var elapsed := 0.0
	var screenshot_taken := false
	while elapsed < 55.0 and not investigation.has("pelican_cleared"):
		var target: Node2D
		var distance := INF
		for actor in encounters.enemies.values():
			if not is_instance_valid(actor) or actor.health <= 0:
				continue
			var next_distance: float = world.player.global_position.distance_to(actor.global_position)
			if next_distance < distance:
				target = actor
				distance = next_distance
		if target == null:
			break
		var offset := target.global_position - world.player.global_position
		_release_movement()
		if distance > 24.0:
			var path: PackedVector2Array = world.tiled_loader.get_walk_path(world.player.global_position, target.global_position)
			if path.size() > 1:
				offset = path[1] - world.player.global_position
			_move_input(offset)
		elif world.player.facing.dot(offset.normalized()) < 0.2:
			_move_input(offset)
		if distance <= float(GameState.weapon_definition().get("reach", 24.0)) and world.player.facing.dot((target.global_position - world.player.global_position).normalized()) >= 0.15:
			_send_action("attack")
		if GameState.health <= 20:
			_send_action("use_food")
		if not screenshot_taken and live_phases > 0:
			await _capture("live_hacker_assault")
			screenshot_taken = true
		var respawns_before := live_respawns
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
		var step := world.player.global_position.distance_to(last_position)
		last_position = world.player.global_position
		if live_respawns == respawns_before:
			walked += step
			largest_step = maxf(largest_step, step)
	_release_movement()
	_check(investigation.has("pelican_cleared"), "normal sword, Davor and allies win a real-time assault")
	_check(walked > 80.0 and largest_step < 24.0, "player walks through the combat rooms rather than teleporting to enemies")
	_check(live_hits.player > 0, "normal player attack input damages an opponent")
	_check(live_hits.davor > 0, "unchanged Davor lands normal melee attacks")
	_check(live_hits.allies > 0, "ordinary supporting fighters land normal melee attacks")
	_check(live_phases > 0, "named hacker warns before phasing in actual combat")
	_check(live_teleports > 0, "named hacker completes a physical teleport during actual combat")
	_check(rings[0] > 0, "Roko fires his arrow ring in actual combat")
	print("LIVE_ASSAULT seconds=", elapsed, " walked=", roundi(walked), " largest_step=", snappedf(largest_step, 0.1), " rings=", rings[0], " hits=", live_hits, " phases=", live_phases, " teleports=", live_teleports, " respawns=", live_respawns, " health=", GameState.health, "/", GameState.max_health, " armor=", GameState.equipment.get("armor", ""), " damage_scale=", world.player.damage_scale, " food_consumed=", foods_before - _food_count())
	await _capture("live_assault_complete")

func _food_count() -> int:
	var count := 0
	for item_id: String in GameState.inventory:
		if GameData.item(item_id).get("kind", "") == "food":
			count += int(GameState.inventory[item_id])
	return count

func _live_damage(_actor_id: String, _amount: int, source: Vector2) -> void:
	if source.distance_to(world.player.global_position) < 1.0:
		live_hits.player += 1
	elif source.distance_to(world.davor.global_position) < 1.0:
		live_hits.davor += 1
	else:
		for ally in encounters.allies.values():
			if is_instance_valid(ally) and source.distance_to(ally.global_position) < 1.0:
				live_hits.allies += 1
				return

func _send_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)

func _move_input(offset: Vector2) -> void:
	if absf(offset.y) > 2.0:
		Input.action_press("move_down" if offset.y > 0 else "move_up")
	elif absf(offset.x) > 1.0:
		Input.action_press("move_right" if offset.x > 0 else "move_left")

func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func _reset() -> void:
	ui.cancel_scene()
	ui.close_modal()
	for flag: String in GameState.defeated_persistent_enemies.duplicate():
		if flag.begins_with(Data.FLAG_PREFIX) or flag.begins_with("story_iskra_inv_"):
			GameState.defeated_persistent_enemies.erase(flag)
	GameState.iskra_investigation_state.clear()
	GameState.restore_health()
	world.player.global_position = world.marker("inv_rendezvous")
	world.player.velocity = Vector2.ZERO
	world.davor.fights = true
	world._move_davor()
	encounters.apply_loaded_state()

func _enter(site: String) -> void:
	ui.cancel_scene()
	ui.close_modal()
	encounters.capture_state()
	world.player.global_position = world.marker("inv_" + site + "_arrival")
	world.player.velocity = Vector2.ZERO
	investigation.set_value("site", site)
	world._move_davor()
	encounters.apply_loaded_state()
	investigation.refresh_location()

func _save_reload() -> void:
	ui.cancel_scene()
	world.capture_player_position()
	_check(GameState.save_game() and GameState.load_game(), "encounter save round trip")
	world.apply_loaded_state()
	await get_tree().process_frame
	ui.cancel_scene()

func _capture(label: String) -> void:
	var directory := OS.get_environment("ISKRA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	ui._hide_notice()
	world._camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("investigation_" + label + ".png"))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])

func _finish() -> void:
	Engine.time_scale = 1.0
	print("Iskra investigation combat: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
