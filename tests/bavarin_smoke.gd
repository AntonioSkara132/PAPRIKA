extends Node

## Bavarin: the flight from Smokva, the canyon and the oasis village, Veki's
## bombs, sneaking past the searchlights and sentries in the sandstorm, the
## climb over the broken wall, the bombs on the warships, the fight with Martin
## and his men with the body switch, and Davor freed. Set BAVARIN_SCREENSHOT_DIR
## to save screenshots when the test runs with a window.

var game: Node
var world: BavarinWorld
var ui: GameUI
var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "Bavarin tests require an isolated save directory")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	for flag: String in [GameState.OTPORNIK_UNLOCK_FLAG, GameState.ROCK_UNLOCK_FLAG, "otpornik_arrival", GameState.DAVOR_TAKEN_FLAG, GameState.SMOKVA_UNLOCK_FLAG,
			"smokva_parrots_beaten", "smokva_donat_joined", GameState.BAVARIN_UNLOCK_FLAG]:
		GameState.defeated_persistent_enemies.append(flag)
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH
	# By Bavarin the player is a Brine (R-7).
	GameState.become_brine()
	GameState.restore_health()

	game._on_story_travel_requested("bavarin")
	await get_tree().process_frame
	world = game.world as BavarinWorld
	_check(world != null and GameState.current_planet == "bavarin" and world.tiled_loader.map_loaded, "the Lasta flies to Bavarin")
	if world == null:
		_finish()
		return
	ui.cancel_scene()
	_check(world.player.global_position.distance_to(GameState.BAVARIN_ARRIVAL) < 1.0, "the party lands in the canyon")
	_check(world.location_title() == "BAVARIN · THE CANYON", "canyon title")
	_check(world._canyon_lasta.visible and not world._landed_lasta.visible, "the Lasta is in the canyon")
	_check(is_instance_valid(world.donat_fighter) and world.donat_fighter.order == "follow", "Donat walks with the player")
	_check(world.story_status_text().contains("Veki"), "the status says to talk to Veki")
	await _capture("canyon")

	_check_map()
	_check_people()
	await _check_bombs_given()
	await _check_find_davor()
	await _check_watch()
	await _check_climb_and_bombs()
	await _check_fight()
	await _check_ending()
	_finish()

func _check_map() -> void:
	for id in ["veki_post", "lasta_spot", "villager_0", "villager_1", "villager_2", "villager_3", "villager_4", "off_duty", "well", "wreck", "arch", "gate_guard_0", "dunes_start", "breach_out"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("arrival"), world.marker(id)).is_empty(), "walk path from the canyon to " + id)
	for id in ["bomb_flagship", "bomb_escort", "davor", "fight_player", "fight_donat", "martin_stand", "man_0", "man_4", "man_7", "lasta_veki", "lasta_door"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("breach_in"), world.marker(id)).is_empty(), "walk path inside the wall to " + id)
	_check(world.tiled_loader.get_walk_path(world.marker("arrival"), world.marker("breach_in")).is_empty(), "the base cannot be walked into without climbing")
	_check(not world.watched(world.marker("dunes_start")) and world.watched(world.marker("breach_out")) and world.in_base(world.marker("breach_in")), "the dunes checkpoint is out of the watch")
	_check(world.sentries.size() == 6 and world.searchlights.size() == 3, "six sentries and three searchlights")
	for id: String in BavarinWorld.SPOTS:
		_check(world.marker(id) != GameState.BAVARIN_ARRIVAL or id == "arrival", "a marker for the spot " + id)

func _check_people() -> void:
	for i in BavarinWorld.VILLAGERS.size():
		var person := world.actors_root.get_node_or_null("Villager_%d" % i) as StationStaff
		_check(person != null, "villager %d is in the village" % i)
		if person != null:
			person.interact(world.player)
			_check(_scene_texts() == String(BavarinWorld.VILLAGERS[i]["line"]), "villager %d says their line" % i)
			ui.cancel_scene()
	var guard := world.actors_root.get_node_or_null("GateGuard_0") as StationStaff
	guard.interact(world.player)
	_check(_scene_texts().contains("closed"), "the gate guard turns the player away")
	ui.cancel_scene()
	_check(not world.davor.visible and not world.davor.is_in_group("interactable"), "Davor is not by the Lasta yet")
	_check(not world.donat.is_in_group("interactable"), "only Donat the fighter is about")

func _check_bombs_given() -> void:
	world.talk_to_veki()
	_check(_scene_texts().contains("Bombs. Stick one on the hull"), "Veki explains the bombs")
	_skip()
	await get_tree().process_frame
	_check(world.has_flag("bombs_given"), "Veki gives the bombs")
	_check(world.story_status_text().contains("Find out where Davor"), "the status sends the player to find Davor")
	world.talk_to_veki()
	_check(_scene_texts().contains("Ask around the village"), "Veki sends the player to the village")
	ui.cancel_scene()

## The off-duty soldier, the date wine and where Davor is held.
func _check_find_davor() -> void:
	_check(not world.climb_wall(true) and _scene_texts().contains("Find out where they keep him") and not world.has_flag("wall_climbed"), "Donat will not climb before they know where Davor is")
	ui.cancel_scene()
	world.player.global_position = world.marker("dunes_start")
	var seller := world.actors_root.get_node("Villager_%d" % BavarinWorld.WINE_SELLER) as StationStaff
	seller.interact(world.player)
	_check(ui._scene_choices.is_empty(), "no wine for sale before the soldier asks for it")
	ui.cancel_scene()
	var soldier := world.actors_root.get_node("OffDutySoldier") as StationStaff
	soldier.interact(world.player)
	_check(_scene_texts().contains("date wine"), "the soldier wants date wine")
	_skip()
	await get_tree().process_frame
	_check(world.has_flag("soldier_thirsty") and world.story_status_text().contains("date wine"), "the status sends the player for wine")
	GameState.gold = BavarinWorld.WINE_PRICE + 5
	seller.interact(world.player)
	_check(ui._scene_choices.size() == 2 and _scene_texts().contains("gold a bottle"), "the date villager sells wine")
	_skip_lines()
	ui._end_scene(ui._scene_choices[0]["action"])
	await get_tree().process_frame
	_check(world.has_flag("wine_bought") and GameState.gold == 5, "a bottle of date wine costs %d gold" % BavarinWorld.WINE_PRICE)
	ui.cancel_scene()
	_check(not world.buy_wine(), "one bottle at a time")
	# Asking about the prisoner straight away wastes the bottle.
	soldier.interact(world.player)
	_check(ui._scene_choices.size() == 2, "the drunk soldier can be asked two things")
	_skip_lines()
	ui._end_scene(ui._scene_choices[0]["action"])
	await get_tree().process_frame
	_check(_scene_texts().contains("You're spies") and not world.has_flag("davor_located"), "asked about the prisoner first, he turns nasty")
	_skip()
	await get_tree().process_frame
	_check(not world.has_flag("wine_bought"), "and the bottle is gone")
	# Without the gold, the villager gives the second bottle away.
	_check(world.buy_wine() and GameState.gold == 5 and world.has_flag("wine_bought"), "a bottle for free when the player cannot pay")
	ui.cancel_scene()
	soldier.interact(world.player)
	_skip_lines()
	ui._end_scene(ui._scene_choices[1]["action"])
	await get_tree().process_frame
	_check(_scene_texts().contains("Banishing Sword") and ui._scene_choices.size() == 2, "he talks about Martin and his sword")
	_skip_lines()
	ui._end_scene(ui._scene_choices[0]["action"])
	await get_tree().process_frame
	_check(_scene_texts().contains("chained to the post"), "then he says where Davor is")
	_skip()
	await get_tree().process_frame
	_check(world.has_flag("davor_located") and not world.has_flag("wine_bought"), "Davor is located")
	_check(world.story_status_text().contains("crumbled wall"), "the status points at the broken wall")
	world.talk_to_veki()
	_check(_scene_texts().contains("Two bombs to go"), "Veki reminds the player of the bombs")
	ui.cancel_scene()
	soldier.interact(world.player)
	_check(ui._scene_choices.is_empty(), "afterwards the soldier just chats")
	ui.cancel_scene()

func _check_watch() -> void:
	# The storm cycle.
	world.storm_time = 0.0
	_check(world.storm_phase() == "calm", "the storm starts calm")
	world.storm_time = BavarinWorld.SANDSTORM_CALM + 0.5
	_check(world.storm_phase() == "warning", "a warning before the gust")
	world.storm_time = BavarinWorld.SANDSTORM_CALM + BavarinWorld.SANDSTORM_WARN + 1.0
	_check(world.storm_phase() == "gust", "the gust")
	_check(is_equal_approx(world.cone_length(), BavarinWorld.CONE_LENGTH * BavarinWorld.GUST_CONE) and world.light_radii().x < BavarinWorld.LIGHT_RADII.x, "the gust shrinks the cones and the lights")
	world.storm_time = 0.0
	world.step_watch(0.0)
	_check(world.cone_length() == BavarinWorld.CONE_LENGTH, "full cones when calm")

	# A sentry sees the player in its cone.
	var sentry: BavarinWorld.BavarinSentry = world.sentries[1]
	world.player.global_position = sentry.global_position + sentry.looking() * 40.0
	world.suspicion = 0.0
	world._grace = 0.0
	_check(world.seen_by() == sentry.name, "a sentry sees the player in front of it")
	world.step_stealth(0.2)
	_check(world.suspicion > 0.0 and world._alarm_label.visible and world.times_caught == 0, "a moment in sight only raises suspicion")
	world.player.global_position = sentry.global_position - sentry.looking() * 40.0
	_check(world.seen_by() == "", "a sentry does not see behind it")
	world.step_stealth(1.0)
	_check(world.suspicion == 0.0, "suspicion wears off out of sight")
	world.player.global_position = sentry.global_position + sentry.looking() * 40.0
	await _capture("seen")
	world.step_stealth(0.3)
	world.step_stealth(0.3)
	_check(world.times_caught == 1 and world.player.global_position == world.marker("dunes_start"), "seen for half a second, the player starts again at the edge of the dunes")
	_check(world.seen_by() == "", "nobody sees the player straight after the restart")
	world._grace = 0.0
	# Out of the watched ground nobody raises the alarm.
	world.player.global_position = world.marker("villager_0")
	_check(world.seen_by() == "", "nobody watches the village")

	# The gust lets the player stand further off.
	world.player.global_position = sentry.global_position + sentry.looking() * 70.0
	_check(world.seen_by() == sentry.name, "seen at 70 px when calm")
	world.storm_time = BavarinWorld.SANDSTORM_CALM + BavarinWorld.SANDSTORM_WARN + 1.0
	_check(world.seen_by() == "", "not seen at 70 px in the gust")
	world.storm_time = 0.0

	# Walls cut the cones short.
	var walled := false
	var space := world.get_world_2d().direct_space_state
	for s: BavarinWorld.BavarinSentry in world.sentries:
		for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
			var eye := s.eye()
			var direction := Vector2.from_angle(angle)
			for distance in [30.0, 50.0, 70.0]:
				var spot: Vector2 = eye + direction * distance + Vector2(0, 6)
				if walled or not world.watched(spot) or space.intersect_ray(PhysicsRayQueryParameters2D.create(eye, spot + Vector2(0, -6), 1)).is_empty():
					continue
				s.facing = direction
				s.look_angle = 0.0
				world.player.global_position = spot
				_check(world.seen_by() == "", "a wall hides the player from a sentry")
				walled = true
	_check(walled, "a sentry with a wall in front of it")

	# A searchlight.
	var light: BavarinWorld.BavarinSearchlight = world.searchlights[0]
	world.step_watch(0.0)
	world.player.global_position = light.spot
	_check(world.seen_by() == "searchlight", "the searchlight finds the player")
	world.player.global_position = light.spot + Vector2(BavarinWorld.LIGHT_RADII.x * 1.4, 0)
	_check(world.seen_by() != "searchlight", "outside the spot the light misses")
	var before: Vector2 = light.spot
	world.step_watch(1.0)
	_check(light.spot != before, "the searchlight sweeps")
	world.step_stealth(1.0)
	world.player.global_position = world.marker("dunes_start")
	world.suspicion = 0.0
	_check(world.story_status_text().contains("crumbled wall"), "nothing changed in the story")

	# The world runs the watch itself while the player is free to move.
	var sentry_at := sentry.global_position
	world.player.global_position = world.marker("dunes_start")
	for i in 30:
		await get_tree().physics_frame
	_check(sentry.global_position != sentry_at or sentry.pause > 0.0, "sentries walk their routes")

func _check_climb_and_bombs() -> void:
	world.player.global_position = world.marker("breach_out")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world._spots["breach_out"], "the broken wall can be climbed")
	world._on_spot("breach_out")
	_check(world.has_flag("wall_climbed") and world.player.global_position == world.marker("breach_in"), "the player climbs over the wall")
	_check(world.donat_fighter.global_position.distance_to(world.player.global_position) < 40.0, "Donat climbs over too")
	_check(_scene_texts().contains("Two ships, two bombs, two of us"), "Donat splits the bombs")
	_check(world.location_title() == "BAVARIN · THE BASE", "base title")
	_check(world.splitting(), "they split up inside the wall")
	ui.cancel_scene()
	await _capture("inside")
	world._grace = 0.0
	var sentry: BavarinWorld.BavarinSentry = world.sentries[3]
	world.player.global_position = sentry.global_position + sentry.looking() * 30.0
	world.step_stealth(0.6)
	_check(world.player.global_position == world.marker("breach_in"), "seen inside, the player starts again inside the wall")

	world.reach_davor()
	_check(_scene_texts().contains("Bombs first") and not world.fight_active, "Davor waits until the bombs are planted")
	ui.cancel_scene()

	# Split up: Donat stays where he is left.
	world.player.global_position = world.marker("breach_in")
	world._bring_donat()
	world._grace = 2.0
	var donat_at := world.donat_fighter.global_position
	world.player.global_position = world.marker("breach_in") + Vector2(-60, 0)
	for i in 20:
		await get_tree().physics_frame
	_check(world.donat_fighter.order == "hold" and world.donat_fighter.global_position.distance_to(donat_at) < 6.0, "split up, Donat waits where he was left")
	await _press("party_first")
	_check(world.bodies_switched and world._camera.get_parent() == world.donat_fighter and world.story_status_text().contains("Donat's body"), "2 takes over Donat while sneaking")
	var body_at := world.player.global_position
	for i in 20:
		await get_tree().physics_frame
	_check(world.player.global_position == body_at, "the MC's body stands still meanwhile")
	# The guards can see the body that was left behind.
	world._grace = 0.0
	world.player.global_position = sentry.global_position + sentry.looking() * 30.0
	_check(world.seen_by() == sentry.name and world.spotted == world.player, "a sentry spots the body the player left")
	world.player.global_position = world.marker("dunes_start")
	world.donat_fighter.global_position = sentry.global_position + sentry.looking() * 30.0
	_check(world.seen_by() == sentry.name and world.spotted == world.donat_fighter, "and Donat's")
	world.step_stealth(0.6)
	_check(not world.bodies_switched and world.player.global_position == world.marker("breach_in") and world.donat_fighter.global_position.distance_to(world.player.global_position) < 40.0, "caught, both start again inside the wall")
	world._grace = 2.0

	# Each plants one bomb.
	_check(world.plant_bomb("bomb_flagship", world.player), "the MC's bomb goes on Martin's ship")
	_check(world._bomb_lights.has("bomb_flagship") and not world._spots["bomb_flagship"].is_in_group("interactable"), "its light blinks on the hull")
	_check(not world.plant_bomb("bomb_flagship", world.donat_fighter), "only one bomb on a ship")
	_check(not world.plant_bomb("bomb_escort", world.player) and world.bombs_planted() == 1, "the MC has no second bomb")
	world._set_switched(true)
	world.donat_fighter.global_position = world.marker("bomb_escort")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world._spots["bomb_escort"], "the escort's hull is in reach of Donat")
	world.player._current_interactable.interact(world.controlled_actor())
	_check(world.bombs_planted() == 2 and world.has_flag("donat_planted") and world.has_flag("mc_planted"), "Donat plants the second bomb")
	_check(not world.bodies_switched and not world.splitting() and world.donat_fighter.order == "follow", "then they are together again")
	_check(world.story_status_text().contains("Davor"), "the status sends the player to Davor")
	await _press("party_first")
	_check(not world.bodies_switched, "no switching once the bombs are on")

	# Being caught keeps the bombs.
	world._grace = 0.0
	world.player.global_position = sentry.global_position + sentry.looking() * 30.0
	world.step_stealth(0.6)
	_check(world.bombs_planted() == 2 and world._bomb_lights.size() == 2, "the bombs stay on the hulls after the alarm")

	# A reload keeps the bombs and the wall.
	world.player.global_position = world.marker("breach_in")
	world.capture_player_position()
	_check(GameState.save_game(), "saving at Bavarin")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(saved is Dictionary and saved["current_planet"] == "bavarin" and GameState._valid_save(saved), "the save records Bavarin")
	var locked: Dictionary = saved.duplicate(true)
	locked["defeated_persistent_enemies"].erase(GameState.BAVARIN_UNLOCK_FLAG)
	_check(not GameState._valid_save(locked), "a Bavarin save needs the Parrots' battle won")
	var legacy: Dictionary = saved.duplicate(true)
	legacy["schema"] = GameState.SMOKVA_SAVE_SCHEMA
	legacy["current_planet"] = "smokva"
	legacy["planet_positions"].erase("bavarin")
	_check(GameState._valid_save(legacy), "schema 18 saves from before Bavarin stay valid")
	legacy["current_planet"] = "bavarin"
	_check(not GameState._valid_save(legacy), "a schema 18 save cannot be on Bavarin")
	_check(game._load_saved_game(), "loading the Bavarin save")
	world = game.world as BavarinWorld
	_check(world != null and world.player.global_position.distance_to(world.marker("breach_in")) < 1.0, "the load keeps the position")
	_check(world._bomb_lights.size() == 2 and world.has_flag("wall_climbed"), "the load keeps the bombs")
	ui.cancel_scene()

func _check_fight() -> void:
	world.player.global_position = world.marker("davor")
	world.player._update_nearest_interactable()
	_check(world.player._current_interactable == world._spots["davor"], "Davor's post is in reach")
	world._on_spot("davor")
	_check(_scene_texts().contains("pour out"), "Martin's men come out")
	_skip()
	await get_tree().process_frame
	_check(world.fight_active and world.fight_stage == "men" and not is_instance_valid(world.martin) and world.men.size() == 4, "first four men, and no Martin yet")
	_check(world.donat_fighter.order == "attack" and not world.sentries[3].visible, "Donat fights, the sentries are gone")
	var tvrdium := 0
	for kind in BavarinWorld.MEN_KINDS:
		tvrdium += int(kind == "republic_tvrdium_guard")
	_check(BavarinWorld.MEN_KINDS.size() == 8 and tvrdium == 3, "eight men, three in Tvrdium armor")
	_check(GameData.enemy("republic_tvrdium_guard")["armor"] > GameData.enemy("republic_guardsman")["armor"], "Tvrdium armor is the strongest")
	await _capture("fight")
	# The checks below take their time; the player only takes damage where it is checked.
	world.player.damage_scale = 0.0

	# The body switch.
	await _press("party_first")
	_check(world.bodies_switched and world.controlled_actor() == world.donat_fighter and world._camera.get_parent() == world.donat_fighter, "2 puts the player in Donat's body")
	await _press("party_player")
	_check(not world.bodies_switched and world.controlled_actor() == world.player and world._camera.get_parent() == world.player, "1 puts the player back")
	world._set_switched(true)
	var body_at := world.player.global_position
	for i in 20:
		await get_tree().physics_frame
	_check(world.player.global_position != body_at, "Donat moves the player's body while switched")
	world._set_switched(false)

	# A knock-out against the men starts that part again.
	world.player.damage_scale = 1.0
	world.player._invulnerability = 0.0
	world.player.take_damage(99999)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameState.health >= 1 and _scene_texts().contains("Up! Get up!"), "Davor shouts the player up after a knock-out")
	_skip()
	await get_tree().process_frame
	_check(world.fight_active and world.fight_stage == "men" and world.men.size() == 4 and GameState.health == GameState.max_health, "the fight with the men starts again")
	world.player.damage_scale = 0.0

	# The second wave.
	for enemy in world.men.duplicate():
		enemy.take_damage(9999)
	for i in 4:
		await get_tree().physics_frame
	_check(world.men.size() == 4 and world._second_wave_left.is_empty(), "four more men come from the parade ground")
	var kinds := []
	for enemy in world.men:
		kinds.append(enemy.enemy_id)
	_check(kinds.has("republic_guardsman") and kinds.has("republic_tvrdium_guard"), "the second wave has a guardsman and a Tvrdium guard")

	# With the men down, Martin comes out and banishes Donat.
	for enemy in world.men.duplicate():
		enemy.take_damage(9999)
	for i in 4:
		await get_tree().physics_frame
	_check(world.has_flag("men_beaten") and is_instance_valid(world.martin), "with his men down, Martin comes out")
	_check(_scene_texts().contains("You again? Didn't you learn your lesson last time?"), "Martin's line")
	_check(world._fight_held and not world.martin.is_physics_processing(), "the fight waits during the scene")
	_skip()
	await get_tree().process_frame
	_check(_scene_texts().contains("Banishing Arrow") and world.donat_fighter.down, "Martin's Banishing Arrow drops Donat")
	_skip()
	await get_tree().process_frame
	_check(world.fight_stage == "duel" and not world._fight_held and world.martin.is_physics_processing(), "then the duel")
	await _press("party_first")
	_check(not world.bodies_switched, "Donat's body cannot be taken in the duel")
	for i in 30:
		await get_tree().physics_frame
	_check(world.donat_fighter.down, "Donat stays down")
	_check(world.story_status_text().contains("duel"), "the status tells of the duel")

	# Martin's attacks.
	var martin := world.martin
	martin.set_physics_process(false)
	world.player.global_position = martin.global_position + Vector2(30, 0)
	world.player._invulnerability = 0.0
	world.player.damage_scale = 1.0
	GameState.restore_health()
	martin.start_sword(Vector2.RIGHT)
	_check(martin.special == "sword" and is_instance_valid(martin._warning), "the Banishing Sword shows on the ground first")
	_check(martin.special_hits(world.player.global_position) and not martin.special_hits(martin.global_position + Vector2(-30, 0)), "the sword's half circle is in front of him only")
	var health := GameState.health
	martin._release_special()
	_check(GameState.health < health and GameState.health > 0, "the Banishing Sword only hurts the MC")
	_check(world.has_flag("brine_shrugged") and _scene_texts().contains("Was that supposed to do something?") and _scene_texts().contains("Brine"), "the first Banishing hit stops the fight for the Brine scene")
	_check(world._fight_held, "the fight waits during it")
	await _capture("brine")
	_skip()
	await get_tree().process_frame
	_check(not world._fight_held and world.fight_active, "and goes on after")
	martin.set_physics_process(false)
	world.player._invulnerability = 0.0
	health = GameState.health
	martin.start_sword(Vector2.RIGHT)
	_release(martin)
	_check(GameState.health < health and not ui.scene_playing(), "later Banishing hits are ordinary hits")
	world.player._invulnerability = 0.0
	health = GameState.health
	martin.start_sword(Vector2.LEFT)
	_release(martin)
	_check(GameState.health == health, "behind him the sword misses")

	# The Banishing Arrow, across open ground.
	var shot := _open_line(120.0)
	martin.global_position = shot[0]
	world.player.global_position = shot[1]
	world.player._invulnerability = 0.0
	GameState.restore_health()
	health = GameState.health
	martin.start_arrow(shot[1] - shot[0])
	_check(martin.special == "arrow" and martin.arrow_headings().size() == 1, "one arrow at full health")
	_release(martin)
	var arrows := world.actors_root.get_children().filter(func(node) -> bool: return node is MartinBoss.MartinArrow)
	_check(arrows.size() == 1, "the arrow flies")
	for i in 60:
		await get_tree().physics_frame
	_check(GameState.health < health and world.actors_root.get_children().filter(func(node) -> bool: return node is MartinBoss.MartinArrow).is_empty(), "the arrow hits the player")
	martin.health = int(martin.max_health * 0.5)
	_check(martin.angry() and martin.arrow_headings().size() == 3, "three arrows when he is angry")
	martin.health = martin.max_health

	# The jump.
	world.player._invulnerability = 0.0
	GameState.restore_health()
	health = GameState.health
	var target := world.player.global_position
	martin.start_jump(target)
	_check(martin.special == "crouch" and martin.special_hits(target) and not martin.special_hits(target + Vector2(80, 0)), "a red circle shows where he will land")
	martin._release_special()
	_check(martin.in_air() and martin.collision_layer == 0, "he is in the air")
	var before := martin.health
	martin.take_damage(50)
	_check(martin.health == before, "he cannot be hit in the air")
	martin._step_air()
	martin._release_special()
	_check(martin.global_position.distance_to(martin.jump_to) < 1.0 and not martin.in_air() and martin.collision_layer != 0, "he lands on the circle")
	_check(GameState.health < health, "the landing hits whoever is inside")

	# A Banishing hit on Donat knocks him out.
	world.donat_fighter.revive(world.donat_fighter.max_health)
	world.donat_fighter.get_up_seconds = 5.0
	martin.hit_with_banishing(world.donat_fighter, 18)
	_check(world.donat_fighter.down and world.donat_fighter.get_up_seconds == 0.0, "a Banishing hit floors Donat for good")
	world.player.damage_scale = 0.0
	martin.take_damage(99999)
	_check(martin.health >= 1 and is_instance_valid(martin) and not martin.is_queued_for_deletion(), "Martin cannot be killed")
	martin.health = martin.max_health
	martin.set_physics_process(true)

	# A knock-out in the duel starts only the duel again.
	world.player.damage_scale = 1.0
	world.player._invulnerability = 0.0
	world.player.take_damage(99999)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_scene_texts().contains("Martin raises his sword again"), "knocked out in the duel")
	_skip()
	await get_tree().process_frame
	_skip()
	await get_tree().process_frame
	_check(world.fight_active and world.fight_stage == "duel" and world.men.is_empty() and is_instance_valid(world.martin) and world.martin.health == world.martin.max_health and world.donat_fighter.down, "the duel starts again, without the men")
	world.player.damage_scale = 0.0

## Two walkable points `length` apart with no wall between them, near the fight.
func _open_line(length: float) -> Array:
	var space := world.get_world_2d().direct_space_state
	var centre := world.marker("fight_player")
	for radius in [0.0, 30.0, 60.0, 90.0]:
		for angle in 8:
			var from: Vector2 = centre + Vector2.from_angle(angle * TAU / 8.0) * radius
			for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				var to: Vector2 = from + direction * length
				if world.tiled_loader.is_walkable_position(from) and world.tiled_loader.is_walkable_position(to) and space.intersect_ray(PhysicsRayQueryParameters2D.create(from + Vector2(0, -8), to + Vector2(0, -8), 1)).is_empty():
					return [from, to]
	_check(false, "open ground for the arrow")
	return [centre, centre + Vector2(length, 0)]

## Lets the attack now shown on the ground land.
func _release(martin: MartinBoss) -> void:
	martin._release_special()

func _check_ending() -> void:
	world.martin.health = int(world.martin.max_health * 0.2)
	for i in 3:
		await get_tree().physics_frame
	_check(world.has_flag("martin_beaten") and _scene_texts().contains("Veki's bombs blow the hulls"), "at a quarter of his health the bombs go off")
	_check(not world._ship_fires.is_empty() and world._bomb_lights.is_empty(), "the warships burn")
	_check(_scene_texts().contains("drag him back"), "Martin is dragged away alive")
	await _capture("bombs")
	_skip()
	await get_tree().process_frame
	_check(not world.fight_active and not is_instance_valid(world.martin) and world.men.is_empty(), "the fight is over")
	_check(not is_instance_valid(world.donat_fighter) and world.donat.visible, "Donat stops fighting")
	_check(not world.sentries[0].visible and not world._drill[0].visible, "the soldiers have run")
	_check(world._spots["davor"].text == "Free Davor", "Davor can be freed")
	world._on_spot("davor")
	_check(world.has_flag("davor_freed") and GameState.davor_health == -1, "Davor is freed")
	_skip()
	await get_tree().process_frame
	_check(world.davor.visible and world.davor.is_in_group("interactable") and not world._chained_davor.visible, "Davor stands free by the Lasta")
	_check(world._landed_lasta.visible and not world._canyon_lasta.visible, "Veki lands the Lasta in the base")
	_check(GameState.defeated_persistent_enemies.has(GameState.DAVOR_TAKEN_FLAG), "the old R-7 flag is left as it was")
	for i in 100:
		await get_tree().physics_frame
	await _capture("free")
	world.talk_to_veki()
	_check(_scene_texts().contains("plotting"), "Veki has no course yet")
	ui.cancel_scene()
	world.capture_player_position()
	_check(GameState.save_game() and game._load_saved_game(), "saving and loading after the rescue")
	world = game.world as BavarinWorld
	_check(world.davor.visible and world._landed_lasta.visible and not world._ship_fires.is_empty() and not is_instance_valid(world.donat_fighter), "the load keeps the rescue")

func _scene_texts() -> String:
	var all := []
	for line: Dictionary in ui._scene_lines:
		all.append(String(line["text"]))
	return "\n".join(all)

func _skip_lines() -> void:
	while ui.scene_playing() and ui.scene_lines_left() > 0:
		ui.advance_scene()

func _skip() -> void:
	_skip_lines()
	if ui.scene_playing() and ui._scene_choices.is_empty():
		ui.advance_scene()

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	for i in 3:
		await get_tree().process_frame

func _capture(label: String) -> void:
	var directory := OS.get_environment("BAVARIN_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	# Long enough for flashes from the step before to fade. The watch and the
	# fight wait meanwhile, so the checks after the picture see what they expect.
	world.set_physics_process(false)
	for node in world.actors_root.get_children():
		node.set_physics_process(false)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	world.set_physics_process(true)
	for node in world.actors_root.get_children():
		node.set_physics_process(true)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + message)

func _finish() -> void:
	print("Bavarin smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
