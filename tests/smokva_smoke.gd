extends Node

## Smokva: the flight from R-7, the yard and the bar, Krešo's darts and table
## soccer, the fight with the Purple Parrots and the duel with Donat, and
## Otpornik closing behind the party. Set SMOKVA_SCREENSHOT_DIR to
## save screenshots when the test runs with a window.

var game: Node
var world: SmokvaWorld
var ui: GameUI
var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "Smokva tests require an isolated save directory")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	GameState.defeated_persistent_enemies.append(GameState.PASSAGE_FLAG)
	for flag: String in SkoljkaWorld.FLAGS:
		GameState.defeated_persistent_enemies.append(flag)
	for flag: String in [GameState.OTPORNIK_UNLOCK_FLAG, GameState.ROCK_UNLOCK_FLAG, "otpornik_arrival"]:
		GameState.defeated_persistent_enemies.append(flag)
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH
	GameState.restore_health()
	_check(not GameState.smokva_course_set(), "Smokva is not reached before the course is set")

	# The flight from R-7 sets the course; Otpornik is not offered again.
	game._on_story_travel_requested("rock")
	await get_tree().process_frame
	var rock := game.world as SpaceRockWorld
	_check(rock != null, "the party is on R-7")
	ui.cancel_scene()
	rock.fly_to_smokva()
	await get_tree().process_frame
	world = game.world as SmokvaWorld
	_check(world != null and GameState.current_planet == "smokva" and world.tiled_loader.map_loaded, "the Lasta flies to Smokva")
	if world == null:
		_finish()
		return
	_check(GameState.smokva_course_set(), "the course for Smokva is recorded")
	_check(world.player.global_position == GameState.SMOKVA_ARRIVAL, "the party lands on the pad")
	_check(not ui.scene_playing(), "no story scene plays on landing")
	_check(world.location_title() == "SMOKVA · THE YARD" and not world.in_room(), "yard title")
	_check(world.lasta_sprite.visible and world.kreso_sprite != null and world.veki != null, "the Lasta, Veki and Krešo are here")
	await _capture("yard")

	for id in ["lasta", "veki_post", "dock_sign", "olive", "swing", "fig", "lounge", "bar_door"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("arrival"), world.marker(id)).is_empty(), "walk path from the pad to " + id)
	for id in ["bar", "couch", "jukebox", "darts", "table_soccer", "wc_door", "room_door"]:
		_check(not world.tiled_loader.get_walk_path(world.marker("room_entry"), world.marker(id)).is_empty(), "walk path in the bar to " + id)
	for id: String in SmokvaWorld.SPOTS:
		world.player.global_position = world.marker(id)
		world.player._update_nearest_interactable()
		_check(world.player._current_interactable != null, "something to use at " + id)

	world._talk_to_veki()
	_check(ui.scene_playing() and ui._scene_choices.is_empty(), "Veki does not offer Otpornik")
	ui.cancel_scene()
	GameState.health = 3
	world._on_spot("swing")
	_check(GameState.health == GameState.max_health, "the swing restores health")
	ui.cancel_scene()

	# Into the bar and back.
	world._on_spot("bar_door")
	_check(world.in_room() and world.player.global_position == world.marker("room_entry"), "the door leads into the bar")
	_check(world.location_title() == "SMOKVA · THE BAR", "bar title")
	_check(world._camera.limit_left >= int(SmokvaWorld.ROOM_RECT.position.x) - 200 and world._camera.limit_top >= int(SmokvaWorld.ROOM_RECT.position.y) - 100, "the camera stays on the bar")
	world.player.global_position = world.marker("bar")
	await _capture("bar")
	world._on_spot("room_door")
	_check(not world.in_room() and world.player.global_position == world.marker("bar_door"), "the door leads back to the yard")
	world._on_spot("bar_door")

	# Krešo at the bar.
	world._on_spot("bar")
	_check(ui.scene_playing() and ui._scene_choices.size() == 5 and String(ui._scene_choices[3]["label"]) == "Ask about a Republic ship", "Krešo offers darts, table soccer, drinks and news of the ship")
	_check(String(ui._scene_lines[0]["text"]) == SmokvaWorld.KRESO_LINES[0], "Krešo starts with his first line")
	var darts_choice: Callable = ui._scene_choices[0]["action"]
	ui.cancel_scene()
	darts_choice.call()
	_check(world.bar_game_open() and world.bar_game is DartsGame, "Krešo's choice opens darts")
	world.close_bar_game()
	await get_tree().process_frame
	world._talk_to_kreso()
	_check(String(ui._scene_lines[0]["text"]) == SmokvaWorld.KRESO_LINES[1], "Krešo's next visit has a new line")
	ui.cancel_scene()

	# Drinks.
	world.drinks_menu()
	_check(ui.scene_playing() and ui._scene_choices.size() == 4, "Krešo sells beer, Pelinkovac and Cedevita")
	await _capture("drinks")
	ui.cancel_scene()
	GameState.gold = 0
	GameState.health = 5
	_check(not world.buy_drink("beer") and GameState.health == 5, "no gold, no beer")
	ui.cancel_scene()
	GameState.add_gold(20)
	_check(world.buy_drink("beer") and GameState.gold == 14 and GameState.health == 10, "a beer costs 6 and restores 5 health")
	ui.cancel_scene()
	_check(world.buy_drink("pelinkovac") and GameState.gold == 5 and GameState.health == 20, "Pelinkovac costs 9 and restores 10")
	ui.cancel_scene()
	_check(world.buy_drink("cedevita") and GameState.gold == 1 and GameState.health == 23, "Cedevita costs 4 and restores 3")
	ui.cancel_scene()
	_check(not world.buy_drink("cedevita") and GameState.gold == 1, "Krešo gives no credit")
	ui.cancel_scene()
	GameState.restore_health()

	# The hackers.
	_check(world.hackers.size() == 8, "all eight hackers are at Smokva")
	for id: String in SmokvaWorld.PARROTS:
		_check((world.hackers[id].get_child(0) as Sprite2D).texture.resource_path.ends_with(String(SmokvaWorld.PARROTS[id]["art"])), id + " wears the Parrots' feather")
	for id: String in SmokvaWorld.PLACES:
		var spot := world.place(id)
		var ground := world.tiled_loader.nearest_walkable_position(spot)
		_check(ground.is_finite() and ground.distance_to(spot) <= 24.0, id + " is next to walkable floor")
		var entry := world.marker("room_entry" if world.in_room(spot) else "arrival")
		_check(not world.tiled_loader.get_walk_path(entry, ground).is_empty(), "walk path to " + id)
	var seats := 0
	for id: String in SmokvaWorld.ROUTINES:
		for stop: Array in SmokvaWorld.ROUTINES[id]:
			if String(stop[0]).begins_with("table_") or String(stop[0]).begins_with("stool_") or String(stop[0]).begins_with("garden_") or String(stop[0]).begins_with("lounge_"):
				seats += 1
		_check(String(SmokvaWorld.ROUTINES[id][0][0]).contains("table") or String(SmokvaWorld.ROUTINES[id][0][0]).contains("stool") or String(SmokvaWorld.ROUTINES[id][0][0]) in ["couch", "garden_1", "garden_2", "garden_3", "lounge_1", "lounge_2"], id + " starts sitting down")
	_check(seats >= 14, "most stops are at a table or the counter")
	for id: String in SmokvaWorld.HACKERS:
		var hacker: SmokvaHacker = world.hackers[id]
		var name: String = SmokvaWorld.HACKERS[id]["name"]
		_check(hacker.global_position == world.place(String(SmokvaWorld.ROUTINES[id][0][0])) and hacker.waiting(), name + " starts at their first stop")
		_check(hacker.get_interaction_text() == "Talk to " + name, name + " can be talked to")
		hacker.wait_left = 1000.0
		world.player.global_position = hacker.global_position + Vector2(0, 12)
		world.player._update_nearest_interactable()
		_check(world.player._current_interactable == hacker, name + " is the nearest thing to talk to")
		hacker.interact(world.player)
		_check(ui.scene_playing() and String(ui._scene_lines[0]["speaker"]) == name and ui._scene_lines[0]["focus"] == hacker, name + " speaks")
		var first := String(ui._scene_lines[0]["text"])
		if id in ["aquarium", "rainbow_clown"]:
			await _capture("hacker_" + id)
		ui.cancel_scene()
		world.talk_to_hacker(id)
		_check(String(ui._scene_lines[0]["text"]) != first, name + " says something new the second time")
		ui.cancel_scene()
		# A full round: every stop in order, through the door when it is on the other side.
		var visited := []
		hacker.wait_left = 0.0
		for i in 20000:
			var was_waiting := hacker.waiting()
			hacker.step(0.05)
			if hacker.waiting() and not was_waiting:
				visited.append(hacker.global_position)
				hacker.wait_left = 0.0
			if visited.size() > SmokvaWorld.ROUTINES[id].size():
				break
		var expected := []
		for stop: Array in SmokvaWorld.ROUTINES[id]:
			expected.append(world.place(String(stop[0])))
		expected = expected.slice(1) + expected.slice(0, 2)
		_check(visited == expected, name + " walks the whole round and comes back")
	# Talking to a hacker or opening a game stops them where they are.
	var luster: SmokvaHacker = world.hackers["chandelier"]
	luster.wait_left = 0.0
	luster.stop_index = 2
	world.talk_to_hacker("chandelier")
	var held := luster.global_position
	for i in 10:
		await get_tree().process_frame
	_check(luster.global_position == held, "a hacker stands still while you talk")
	ui.cancel_scene()
	for i in 10:
		await get_tree().process_frame
	_check(luster.global_position != held, "and walks on afterwards")
	await _capture("hackers_walking")
	world.player.global_position = world.marker("bar")

	# Darts scoring.
	var c := DartsGame.CENTER
	var mm := DartsGame.MM
	_check(DartsGame.score_at(c)[0] == 50, "the bullseye scores 50")
	_check(DartsGame.score_at(c + Vector2(10.0 * mm, 0))[0] == 25, "the outer bull scores 25")
	_check(DartsGame.score_at(c + Vector2(0, -103.0 * mm))[0] == 60, "the treble 20 scores 60")
	_check(DartsGame.score_at(c + Vector2(0, 166.0 * mm))[0] == 6, "the double 3 scores 6")
	_check(DartsGame.score_at(c + Vector2(140.0 * mm, 0))[0] == 6, "a single 6 on the right")
	_check(DartsGame.score_at(c + Vector2(0, -180.0 * mm))[0] == 0, "a miss scores nothing")

	# A full game of darts.
	var darts := world.open_darts() as DartsGame
	await get_tree().process_frame
	_check(darts != null and darts.is_visible_in_tree() and darts.is_in_group("ui_modal"), "darts open over the bar")
	var before := world.player.global_position
	Input.action_press("move_right")
	for i in 10:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(world.player.global_position.distance_to(before) < 1.0, "the player stands still while playing")
	darts.throw_at(c)
	_check(darts.scores["player"] == 50 and darts.turn == "player" and darts.darts_thrown == 1, "a bullseye counts for the player")
	darts.throw_at(c + Vector2(0, -103.0 * mm))
	darts.throw_at(c + Vector2(0, -180.0 * mm))
	_check(darts.scores["player"] == 110 and darts.turn == "kreso", "after three darts Krešo throws")
	await _capture("darts")
	for round_index in 3:
		while darts.turn == "kreso":
			darts._kreso_throw()
		if darts.turn == "player":
			for i in 3:
				darts.throw_at(c)
	_check(darts.turn == "over" and darts.round_number > DartsGame.ROUNDS, "three rounds end the game")
	_check(darts.scores["player"] == 110 + 300, "the player's total adds up")
	_check(darts.last_text.contains("win") or darts.last_text.contains("draw"), "the result is shown")
	await _capture("darts_over")
	darts.restart()
	_check(darts.turn == "player" and darts.scores["player"] == 0 and darts.round_number == 1, "darts can be played again")
	await _press("pause")
	_check(not world.bar_game_open() and not get_tree().paused, "Esc leaves darts without pausing the game")

	# Table soccer.
	var soccer := world.open_table_soccer() as TableSoccerGame
	await get_tree().process_frame
	_check(soccer != null and soccer.is_visible_in_tree() and world.bar_game == soccer, "table soccer opens")
	_check(soccer.men(0).size() == 1 and soccer.men(3).size() == 5 and soccer.men(7).size() == 1, "the rods have 1, 2, 3 and 5 men")
	soccer.offsets["red"] = 1000.0
	for man: Vector2 in soccer.men(3):
		_check(TableSoccerGame.FIELD.has_point(man), "a man stays on the table")
	soccer.offsets["red"] = 0.0
	# A shot into the right goal scores for the player.
	soccer._pause_time = 0.0
	soccer.ball = Vector2(TableSoccerGame.FIELD.end.x - 20.0, TableSoccerGame.FIELD.get_center().y)
	soccer.velocity = Vector2(400, 0)
	soccer.offsets["blue"] = 200.0
	for i in 10:
		soccer.step(1.0 / 60.0)
	_check(soccer.goals["red"] == 1, "a ball in the right goal counts for the player")
	# A kick sends the ball forward.
	var man: Vector2 = soccer.men(3)[2]
	soccer.ball = man + Vector2(-(TableSoccerGame.BALL_RADIUS + TableSoccerGame.MAN_RADIUS) + 1.0, 0)
	soccer.velocity = Vector2.ZERO
	soccer.kick("red")
	soccer.step(1.0 / 60.0)
	_check(soccer.velocity.x > 300.0, "a kick shoots the ball toward Krešo's goal")
	await _capture("table_soccer")
	soccer.goals["red"] = TableSoccerGame.WIN_GOALS - 1
	soccer._goal("red")
	_check(soccer.over and soccer.message.contains("win"), "five goals win the game")
	soccer.restart()
	_check(not soccer.over and soccer.goals["red"] == 0, "table soccer can be played again")
	# Left to itself, the game keeps going without the ball sticking.
	soccer.restart()
	for i in 1800:
		soccer.step(1.0 / 60.0)
		soccer._kreso_moves(1.0 / 60.0)
		_check_quiet(TableSoccerGame.FIELD.grow(8.0).has_point(soccer.ball), "the ball stays on the table")
	await _press("pause")
	_check(not world.bar_game_open() and not get_tree().paused, "Esc leaves table soccer")

	# Saving in the bar.
	world.player.global_position = world.marker("couch")
	world.capture_player_position()
	_check(GameState.save_game(), "saving at Smokva")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(saved is Dictionary and int(saved["schema"]) == GameState.SAVE_SCHEMA and saved["current_planet"] == "smokva" and GameState._valid_save(saved), "the save records Smokva")
	var no_course: Dictionary = saved.duplicate(true)
	no_course["defeated_persistent_enemies"].erase(GameState.SMOKVA_UNLOCK_FLAG)
	_check(not GameState._valid_save(no_course), "a Smokva save needs the course set")
	world.open_darts()
	_check(game._load_saved_game(), "loading the Smokva save")
	world = game.world as SmokvaWorld
	_check(world != null and world.in_room() and not world.bar_game_open(), "the load puts the player in the bar with no game open")
	_check(world.player.global_position.distance_to(world.marker("couch")) < 1.0, "the load keeps the position")

	await _story()
	if world == null:
		_finish()
		return

	# Otpornik's helm no longer matters: once at Smokva the Lasta does not go back.
	world._talk_to_veki()
	_check(ui._scene_choices.is_empty(), "no flight back to Otpornik")
	ui.cancel_scene()
	_finish()

## Donat, the Purple Parrots, their powers, the fight in the yard and the duel.
func _story() -> void:
	ui.cancel_scene()
	# By Smokva the player is a Brine.
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH + GameState.BRINE_MAX_HEALTH_BONUS
	GameState.restore_health()
	world.player.global_position = world.marker("bar")
	var donat := world.donat
	_check(donat != null and donat.global_position == world.place("donat_seat") and donat.get_interaction_text() == "Talk to Donat", "Donat sits at the second table")
	world.talk_to_donat()
	_check(String(ui._scene_lines[0]["text"]) == SmokvaWorld.DONAT_LINES[0] and ui._scene_choices.is_empty(), "before the question Donat is busy being the strongest")
	ui.cancel_scene()

	# Krešo's joke and his pointer to Donat.
	world.ask_about_ship()
	var texts := _scene_texts()
	_check(world.has_flag("asked_ship") and texts.contains("Who do you think I am? Ahaaa") and texts.contains("You can ask that guy"), "Krešo jokes, then points to Donat")
	_check(ui._scene_lines[ui._scene_lines.size() - 1]["focus"] == donat, "the scene shows Donat")
	_skip()

	# The slash covers the half circle in front.
	_check(SlashArc.hits(Vector2.ZERO, Vector2.RIGHT, 34.0, Vector2(30, 0)), "a slash hits in front")
	_check(SlashArc.hits(Vector2.ZERO, Vector2.RIGHT, 34.0, Vector2(0, 30)) and SlashArc.hits(Vector2.ZERO, Vector2.RIGHT, 34.0, Vector2(0, -30)), "and 90 degrees to either side")
	_check(not SlashArc.hits(Vector2.ZERO, Vector2.RIGHT, 34.0, Vector2(-10, 5)), "but not behind")
	_check(not SlashArc.hits(Vector2.ZERO, Vector2.RIGHT, 34.0, Vector2(60, 0)), "or out of reach")

	# The confrontation: Fivecap first, then the Parrots; the Roko line only for his killer.
	world.talk_to_donat()
	_check(String(ui._scene_lines[0]["speaker"]) == "Fivecap" and String(ui._scene_lines[0]["text"]).contains("Who are you? Never seen you around"), "Fivecap asks who you are")
	texts = _scene_texts()
	_check(texts.contains("Julius has a proposition for you") and not texts.contains("Roko") and ui._scene_choices.size() == 2, "the Parrots bring Julius's proposition")
	_check(world.hackers["chandelier"].held and world.hackers["chandelier"].global_position.distance_to(donat.global_position) < 60.0, "the Parrots come over to Donat's table")
	await _capture("parrots_confront")
	ui.cancel_scene()
	GameState.defeated_persistent_enemies.append("iskra_investigation_hacker_killed")
	world.talk_to_donat()
	texts = _scene_texts()
	_check(String(ui._scene_lines[0]["speaker"]) != "Fivecap", "Fivecap asks only once")
	_check(texts.contains("Are you the guy who killed Roko?") and texts.contains("Julius wants to talk to you") and ui._scene_choices.size() == 2, "Roko's killer is wanted by Julius")
	# Accepting is a trap, refusing is a fight; either way Krešo throws everyone out.
	_choose(1)
	_check(_scene_texts().contains("whether you come back"), "going with them is a trap")
	_skip()
	texts = _scene_texts()
	_check(texts.contains("Not my table, not my problem") and texts.contains("Not in my bar! Outside!") and texts.contains("Who pays for the chairs?"), "Donat stays out of it and Krešo throws everyone out")
	_skip()
	GameState.defeated_persistent_enemies.erase("iskra_investigation_hacker_killed")

	# In the yard, before the fight, the player and Donat switch bodies.
	var fighter := world.donat_fighter
	_check(world.yard_standoff and not world.parrot_fight_active and world._parrots.is_empty(), "the Parrots wait for the scene to end")
	_check(fighter != null and world.bodies_switched and fighter.controlled and world.controlled_actor() == fighter, "the player is in Donat's body")
	_check(world._camera.get_parent() == fighter, "the camera follows Donat's body")
	_check(fighter.global_position.distance_to(world.player.global_position) > 60.0, "Donat's body stands with the watchers")
	_check(_scene_texts().contains("wet bread") and _scene_texts().contains("Get the face"), "Donat wakes up in the player's body")
	var donat_lines := ui._scene_lines.filter(func(line) -> bool: return line["speaker"] == "Donat")
	_check(not donat_lines.is_empty() and donat_lines.all(func(line) -> bool: return line["focus"] == world.player), "Donat speaks from the player's body")
	_check(world.hackers["chandelier"].visible and not world.in_room(world.hackers["chandelier"].global_position), "Luster stands in the yard during the scene")
	await _capture("body_switch")
	_skip()

	# The fight in the yard.
	_check(world.parrot_fight_active and not world.in_room(), "the fight is in the yard")
	_check(world._parrots.size() == 3 and world.donat_fighter != null and not donat.visible, "the three Parrots against the player and Donat")
	var names := []
	for enemy: SmokvaBrawler in world._parrots:
		names.append(enemy.enemy_id)
		_check(enemy.relentless and enemy.persistent_id.begins_with("story_") and world.tiled_loader.is_walkable_position(enemy.global_position), enemy.enemy_id + " stands on the yard")
		_check(enemy._label.position.y == SmokvaBrawler.LABEL_HEIGHT, enemy.enemy_id + "'s name is above the hat")
	names.sort()
	_check(names == ["parrot_luster", "parrot_puffa", "parrot_ruff"], "Puffa, Luster and Ruff fight")
	_check(GameData.enemy("parrot_ruff")["level"] == 9 and GameData.enemy("parrot_puffa")["level"] == 10 and GameData.enemy("parrot_luster")["level"] == 11 and GameData.enemy("donat_duel")["level"] == 12, "ranks 9, 10, 11 and 12")
	var watching := 0
	for id: String in world.hackers:
		if SmokvaWorld.PARROTS.has(id):
			_check(not world.hackers[id].visible, id + " leaves the table to fight")
		elif world.hackers[id].held and not world.in_room(world.hackers[id].global_position):
			watching += 1
	_check(watching == 5, "the other five watch from the yard")
	var body_start := world.player.global_position
	for i in 30:
		await get_tree().physics_frame
	await _capture("parrot_fight")
	var at_player := world._parrots.filter(func(enemy) -> bool: return enemy.focus_target == world.player)
	var at_donat := world._parrots.filter(func(enemy) -> bool: return enemy.focus_target == world.donat_fighter)
	_check(at_player.size() == 1 and at_player[0] == world.parrot_turn and at_donat.size() == 2, "one Parrot at a time goes for the player's body, the others for Donat's")
	var caller := _parrot("parrot_luster")
	_check(is_instance_valid(caller._shout) and caller._shout.text == "Puffa, now!", "Luster calls the turns")
	_check(world.player.global_position.distance_to(body_start) > 10.0, "Donat moves the player's body by himself")

	# The movement keys move Donat's body and the attack key makes it slash.
	world.player.facing = Vector2.DOWN
	var donat_start := fighter.global_position
	Input.action_press("move_left")
	for i in 20:
		await get_tree().physics_frame
	Input.action_release("move_left")
	_check(fighter.global_position.x < donat_start.x - 10.0 and fighter.facing.x < -0.9, "the movement keys move Donat's body")
	fighter._cooldown = 0.0
	await _press("attack")
	_check(fighter._cooldown > 0.0, "the attack key makes Donat's body slash")

	# Both bodies flicker before a switch; then the player is back in their own.
	world.switch_time = SmokvaWorld.SWITCH_WARN_SECONDS - 0.05
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(world._flicker != null and world._flicker.is_running(), "both bodies flicker before the switch")
	world.switch_time = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not world.bodies_switched and not fighter.controlled and world.controlled_actor() == world.player and world._camera.get_parent() == world.player, "the bodies switch back")
	_check(world._flicker == null and fighter.modulate == Color.WHITE and world.player.modulate == Color.WHITE, "the flicker stops at the switch")
	var bark := fighter.get_node_or_null("Bark") as Label
	_check(bark != null and bark.text == "AGAIN?!", "Donat complains from his own body")
	_check(world.switch_time > SmokvaWorld.SWITCH_SECONDS - 0.2 and SmokvaWorld.SWITCH_SECONDS == 8.0, "the next switch is 8 seconds away")
	_check(world.story_status_text().contains("your own body"), "the status says whose body the player is in")
	# A switch waits while Donat's body is down.
	fighter.knock_down()
	world.switch_time = 0.01
	for i in 10:
		await get_tree().physics_frame
	_check(not world.bodies_switched and fighter.down, "no switch while Donat's body is down")
	fighter.get_up()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(world.bodies_switched and fighter.controlled and world._camera.get_parent() == fighter, "the switch comes once he is up")
	bark = world.player.get_node_or_null("Bark") as Label
	_check(bark != null and bark.text == "Give it back!", "Donat complains from the player's body")
	# The powers below are tried with the player in their own body.
	world._set_switched(false)
	world.switch_time = 100000.0

	var puffa := _parrot("parrot_puffa")
	var luster := _parrot("parrot_luster")
	var ruff := _parrot("parrot_ruff")
	var player := world.player
	# Each power is tried alone: the others wait on the landing pad meanwhile.
	var pad := [Vector2(-30, 0), Vector2(0, 0), Vector2(30, 0), Vector2(0, 24)]
	var fighters: Array = [puffa, luster, ruff, world.donat_fighter]
	for i in fighters.size():
		fighters[i].process_mode = Node.PROCESS_MODE_DISABLED
		fighters[i].global_position = world.marker("arrival") + pad[i]

	# Puffa: a warning line, then a dash along it; into a wall he is dazed.
	puffa.process_mode = Node.PROCESS_MODE_INHERIT
	puffa.global_position = _open_area(110.0)
	var open_spot := _open_line(puffa, 110.0)
	_check(open_spot.is_finite(), "room for Puffa's dash")
	player.global_position = open_spot
	player._invulnerability = 0.0
	GameState.restore_health()
	puffa._power_cooldown = 0.0
	puffa.state = Enemy.State.CHASE
	_check(puffa._try_power(player) and puffa.power_state == SmokvaBrawler.Power.WARN and puffa._warning is Line2D, "Puffa puffs up and a line shows his dash")
	await _capture("puffa_warning")
	var before := GameState.health
	for i in 70:
		await get_tree().physics_frame
	_check(GameState.health < before, "Puffa's dash hits whoever stays on the line")
	_check(not is_instance_valid(puffa._warning), "the warning goes when he dashes")
	var wall := _wall_direction(puffa)
	_check(wall != Vector2.ZERO, "a wall near Puffa")
	player.global_position = puffa.global_position - wall * 120.0
	puffa.power_state = SmokvaBrawler.Power.DAZED
	puffa._power_time = 10.0
	# The physics server learns the player's new place on the next step.
	await get_tree().physics_frame
	await get_tree().physics_frame
	puffa._dash_direction = wall
	puffa._dash_left = 200.0
	puffa._dash_hit = false
	puffa.power_state = SmokvaBrawler.Power.ACTIVE
	for i in 60:
		await get_tree().physics_frame
		if puffa.dazed():
			break
	_check(puffa.dazed() and puffa._stars != null, "running into a wall dazes Puffa")
	await _capture("puffa_dazed")
	for i in int(SmokvaBrawler.DAZE_SECONDS * 60) + 10:
		await get_tree().physics_frame
	_check(not puffa.dazed(), "the daze wears off")
	puffa.process_mode = Node.PROCESS_MODE_DISABLED

	# Luster: the candles glow, then eight bolts spiral outward.
	luster.process_mode = Node.PROCESS_MODE_INHERIT
	luster.global_position = _open_area(SmokvaBrawler.BOLT_RANGE * 0.5)
	player.global_position = luster.global_position + Vector2(0, 60)
	luster._power_cooldown = 0.0
	luster.state = Enemy.State.CHASE
	_check(luster._try_power(player) and luster.power_state == SmokvaBrawler.Power.WARN, "Luster's candles glow before the bolts")
	player.global_position = luster.global_position + Vector2(0, 400)
	for i in int(SmokvaBrawler.BOLT_WARN_SECONDS * 60) + 3:
		await get_tree().physics_frame
	var bolts := _bolts()
	_check(bolts.size() == SmokvaBrawler.BOLT_COUNT, "eight light bolts")
	var starts := {}
	for bolt: SpiralBolt in bolts:
		starts[bolt] = bolt.angle
	for i in 30:
		await get_tree().physics_frame
	await _capture("luster_spiral")
	# Bolts that met furniture are gone; every one still flying spirals.
	var flying := 0
	var spiralling := 0
	for bolt in bolts:
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion():
			continue
		flying += 1
		if bolt.radius > SpiralBolt.START_RADIUS + 20.0 and absf(bolt.angle - float(starts[bolt])) > 0.5 and bolt.global_position.distance_to(bolt.centre) > 20.0:
			spiralling += 1
	_check(flying >= SmokvaBrawler.BOLT_COUNT / 2 and spiralling == flying, "the bolts move outward and turn round him")
	for i in 150:
		await get_tree().physics_frame
	_check(_bolts().is_empty(), "the bolts fade out at the end of their range")
	luster.process_mode = Node.PROCESS_MODE_DISABLED

	# Ruff: at half health a decoy without the feather; it pops after one hit.
	ruff.process_mode = Node.PROCESS_MODE_INHERIT
	ruff.take_damage(ruff.max_health / 2 + 20)
	var decoy := ruff.decoy
	_check(ruff.split_done and decoy != null and decoy.is_decoy, "Ruff splits at half health")
	_check(decoy._sprite.texture.resource_path.ends_with("hackers/fur_ruff.png") and ruff._sprite.texture.resource_path.ends_with("parrot_ruff.png"), "only the real Ruff keeps the feather")
	_check(decoy._label.text == ruff._label.text, "the decoy carries the same name and health")
	await _capture("ruff_decoy")
	decoy.take_damage(1)
	_check(decoy.is_queued_for_deletion() and ruff.health > 0, "the decoy pops after one hit")
	ruff.take_damage(5)
	_check(not is_instance_valid(ruff.decoy) or ruff.decoy.is_queued_for_deletion(), "Ruff splits only once")
	ruff.process_mode = Node.PROCESS_MODE_DISABLED

	# Between attacks Luster and Puffa back away instead of walking in.
	for enemy: SmokvaBrawler in [luster, puffa]:
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		world.parrot_turn = enemy
		world._parrot_turn_time = 100.0
		enemy.global_position = _open_area(110.0)
		enemy._power_cooldown = 100.0
		enemy._aimed_cooldown = 100.0
		enemy.power_state = SmokvaBrawler.Power.NONE
		enemy.state = Enemy.State.CHASE
		player.global_position = _open_line(enemy, 40.0)
		GameState.restore_health()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var start := enemy.global_position.distance_to(player.global_position)
		for i in 60:
			await get_tree().physics_frame
		_check(enemy.pressing and enemy.global_position.distance_to(player.global_position) > start + 15.0, enemy.enemy_id + " keeps his distance")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

	# Ruff works round to the side of whoever he fights.
	ruff.process_mode = Node.PROCESS_MODE_INHERIT
	world.parrot_turn = ruff
	world._parrot_turn_time = 100.0
	ruff.global_position = _open_area(60.0)
	player.global_position = ruff.global_position + Vector2(0, -40)
	player.facing = Vector2.DOWN
	ruff._flank_time = 0.0
	ruff._attack_cooldown = 100.0
	ruff.state = Enemy.State.CHASE
	await get_tree().physics_frame
	await get_tree().physics_frame
	var flanked := false
	for i in 90:
		await get_tree().physics_frame
		if (ruff.global_position - player.global_position).normalized().dot(player.facing) < 0.35:
			flanked = true
			break
	_check(flanked, "Ruff gets round to the player's side")
	ruff.process_mode = Node.PROCESS_MODE_DISABLED

	# Close attacks: a jab or, now and then, a heavy blow that leaves an opening.
	ruff.state = Enemy.State.TELEGRAPH
	for i in 80:
		ruff._after_base_step(Enemy.State.CHASE)
		if ruff._heavy:
			break
	_check(ruff._heavy and int(ruff.definition["damage"]) == int(round(ruff._base_damage * SmokvaBrawler.HEAVY_DAMAGE_SHARE)) and is_equal_approx(ruff._state_time, SmokvaBrawler.HEAVY_WARN_SECONDS), "now and then a slow heavy blow")
	ruff.state = Enemy.State.RECOVER
	ruff._after_base_step(Enemy.State.TELEGRAPH)
	_check(is_equal_approx(ruff._state_time, SmokvaBrawler.HEAVY_OPEN_SECONDS) and int(ruff.definition["damage"]) == ruff._base_damage, "which leaves him open afterwards")
	ruff.state = Enemy.State.CHASE

	# Hurt, Puffa dashes twice and Luster's spiral turns both ways.
	world.parrot_turn = puffa
	world._parrot_turn_time = 100.0
	puffa.global_position = _open_area(110.0)
	player.global_position = _open_line(puffa, 90.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	puffa.health = puffa.max_health / 2
	puffa._second_dash = false
	puffa._finish_dash(0.4)
	_check(puffa.power_state == SmokvaBrawler.Power.WARN and puffa._second_dash, "hurt, Puffa dashes again at once")
	puffa._finish_dash(0.4)
	_check(puffa.power_state == SmokvaBrawler.Power.OPEN, "but not a third time")
	puffa._clear_warning()
	puffa._end_power()
	puffa.health = puffa.max_health
	luster.health = luster.max_health / 2
	luster._fire_bolts()
	var rings := _bolts()
	_check(rings.size() == SmokvaBrawler.BOLT_COUNT * 2, "hurt, Luster sends two rings turning opposite ways")
	_check(rings.all(func(bolt) -> bool: return bolt.collision_mask & 16 != 0), "furniture stops his bolts")
	for bolt: Node in rings:
		bolt.queue_free()
	luster.health = luster.max_health

	# Donat's slash on the player's side hits every Parrot in front of him.
	for node: Node in fighters:
		node.process_mode = Node.PROCESS_MODE_INHERIT
	fighter = world.donat_fighter
	fighter.global_position = _open_area(40.0)
	fighter._cooldown = 0.0
	fighter.facing = Vector2.RIGHT
	puffa.global_position = fighter.global_position + Vector2(20, -8)
	luster.global_position = fighter.global_position + Vector2(18, 10)
	ruff.global_position = fighter.global_position + Vector2(-20, 0)
	var health_before := [puffa.health, luster.health, ruff.health]
	fighter._strike(puffa)
	_check(puffa.health < health_before[0] and luster.health < health_before[1] and ruff.health == health_before[2], "Donat's slash hits both Parrots in front and not the one behind")
	await _capture("donat_slash")

	# Knocked out: Krešo wakes the player and the fight starts again.
	GameState.health = 3
	player._invulnerability = 0.0
	player.take_damage(200)
	_check(GameState.health == 1, "a knockout in the fight leaves the player standing")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_scene_texts().contains("Up! Up!") and not world.parrot_fight_active and not world.bodies_switched, "Krešo wakes the player in their own body")
	_skip()
	_check(world.yard_standoff and world.bodies_switched and _scene_texts().contains("Another white flash") and not _scene_texts().contains("wet bread"), "the next round starts with a short switch scene")
	_skip()
	_check(world.parrot_fight_active and world._parrots.size() == 3 and GameState.health == GameState.max_health, "and they go again")

	# Saving mid-fight keeps only the finished steps.
	world.capture_player_position()
	_check(GameState.save_game(), "saving during the fight")
	_check(game._load_saved_game(), "loading it")
	world = game.world as SmokvaWorld
	_check(world != null and not world.parrot_fight_active and world._parrots.is_empty() and world.hackers.size() == 8, "the load is from before the fight")
	_check(not world.bodies_switched and world.controlled_actor() == world.player and world._camera.get_parent() == world.player, "and the player is in their own body")
	ui.cancel_scene()
	world.talk_to_donat()
	_check(String(ui._scene_lines[0]["speaker"]) != "Fivecap" and _scene_texts().contains("Julius"), "talking to Donat brings the Parrots again")
	_choose(0)
	_check(_scene_texts().contains("Wrong answer"), "refusing starts the fight")
	_skip()
	_skip()
	_skip()
	_check(world.parrot_fight_active, "the fight is on again")

	# Beating the Parrots.
	for enemy: SmokvaBrawler in world._parrots.duplicate():
		enemy.take_damage(100000)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(world.has_flag("parrots_beaten") and not world.parrot_fight_active, "the Parrots are beaten")
	_check(world.hackers.size() == 5 and not world.hackers.has("chandelier"), "the Parrots leave Smokva")
	var held_left := 0
	for id: String in world.hackers:
		if world.hackers[id].held:
			held_left += 1
	_check(held_left == 0, "the onlookers go back to their rounds")
	_check(_scene_texts().contains("Never. Do that. Again.") and _scene_texts().contains("In my own body") and ui._scene_choices.size() == 2, "Donat wants a duel")
	_check(not world.bodies_switched and world._camera.get_parent() == world.player and not is_instance_valid(world.donat_fighter), "the bodies switch back for good")

	# The duel.
	_choose(0)
	_check(world.duel_active and world.donat_duel != null and world.donat_duel.enemy_id == "donat_duel", "the duel starts")
	var duel := world.donat_duel
	player = world.player
	duel.global_position = player.global_position + Vector2(24, 0)
	duel._power_cooldown = 0.0
	duel.state = Enemy.State.CHASE
	GameState.restore_health()
	player._invulnerability = 0.0
	_check(duel._try_power(player) and duel._warning is SlashArc, "a red half circle warns of Donat's slash")
	await _capture("duel_warning")
	before = GameState.health
	for i in int(SmokvaBrawler.SLASH_WARN_SECONDS * 60) + 4:
		await get_tree().physics_frame
	_check(GameState.health < before, "the slash hits the player in front of him")
	await _capture("duel_slash")
	for i in 60:
		await get_tree().physics_frame
	player._invulnerability = 0.0
	duel.global_position = player.global_position + Vector2(24, 0)
	duel._power_cooldown = 0.0
	duel.power_state = SmokvaBrawler.Power.NONE
	duel.state = Enemy.State.CHASE
	duel._try_power(player)
	player.global_position = duel.global_position - duel._dash_direction * 28.0
	before = GameState.health
	for i in int(SmokvaBrawler.SLASH_WARN_SECONDS * 60) + 4:
		await get_tree().physics_frame
	_check(GameState.health == before, "stepping behind him dodges the slash")
	_check(duel._attack_cooldown > 0.0, "the slash is his only attack")

	# Donat circles just outside his reach, then steps in to slash.
	for i in 60:
		await get_tree().physics_frame
	duel._clear_warning()
	duel.power_state = SmokvaBrawler.Power.NONE
	duel.state = Enemy.State.CHASE
	duel._step_out = 0.0
	duel._stepping_in = false
	duel._step_in_wait = 100.0
	player.global_position = _open_area(80.0)
	duel.global_position = _walkable_round(player.global_position, 70.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start_angle := (duel.global_position - player.global_position).angle()
	for i in 90:
		await get_tree().physics_frame
	var apart := duel.global_position.distance_to(player.global_position)
	_check(apart > duel._attack_reach() and apart < duel._attack_reach() + SmokvaBrawler.DONAT_CIRCLE + 16.0, "Donat circles just outside his reach")
	_check(absf(angle_difference(start_angle, (duel.global_position - player.global_position).angle())) > 0.3, "and moves round the player")
	duel._step_in_wait = 0.0
	var stepped_in := false
	for i in 120:
		await get_tree().physics_frame
		if duel.power_state == SmokvaBrawler.Power.WARN:
			stepped_in = true
			break
	_check(stepped_in, "then he steps in to slash")
	for i in 90:
		await get_tree().physics_frame

	# A feint: the half circle flickers out and no blade comes.
	duel._clear_warning()
	duel.power_state = SmokvaBrawler.Power.NONE
	duel._step_in_wait = 100.0
	duel.global_position = player.global_position + Vector2(24, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	GameState.restore_health()
	player._invulnerability = 0.0
	duel._start_slash_warning(player, true)
	before = GameState.health
	for i in int((SmokvaBrawler.FEINT_SECONDS + 0.15) * 60) + 3:
		await get_tree().physics_frame
	_check(GameState.health == before and duel.power_state == SmokvaBrawler.Power.NONE and duel._step_out > 0.0, "a feint ends without a blow and he steps back")

	# Hurt, Donat stops feinting and slashes twice.
	duel.global_position = player.global_position + Vector2(24, 0)
	duel._step_out = 0.0
	duel.health = int(duel.max_health * 0.7)
	await get_tree().physics_frame
	await get_tree().physics_frame
	GameState.restore_health()
	player._invulnerability = 0.0
	duel._start_slash_warning(player)
	for i in int(SmokvaBrawler.SLASH_WARN_SECONDS * 60) + 3:
		await get_tree().physics_frame
	_check(duel._second_slash and duel.power_state == SmokvaBrawler.Power.WARN and duel._warning is SlashArc, "hurt, Donat slashes a second time at once")
	await _capture("duel_second_slash")
	for i in 60:
		await get_tree().physics_frame
	GameState.restore_health()
	duel.take_damage(100000)
	_check(duel.health == 1 and is_instance_valid(duel) and not duel.is_queued_for_deletion(), "Donat does not go down")
	await get_tree().physics_frame
	await get_tree().process_frame
	texts = _scene_texts()
	_check(world.has_flag("donat_joined") and not world.duel_active and texts.contains("It wasn't luck"), "breaking his guard ends the duel")
	_check(texts.contains("Bavarin") and texts.contains("Then I'm coming") and texts.contains("In your own face"), "Donat says the ship went to Bavarin and comes along")
	_skip()
	_check(world.donat.visible and world.donat.global_position.distance_to(world.marker("veki_post")) < 60.0, "Donat waits by the Lasta")
	world._talk_to_veki()
	_check(_scene_texts().contains("Bavarin"), "Veki talks of Bavarin")
	ui.cancel_scene()

	# The other two endings of the duel.
	world.player.global_position = world.marker("bar_door") + Vector2(0, 80)
	GameState.defeated_persistent_enemies.erase(SmokvaWorld.FLAG_PREFIX + "donat_joined")
	_check(world.start_duel(), "a second duel for the other endings")
	world.duel_time = SmokvaWorld.DUEL_HOLD_SECONDS
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(_scene_texts().contains("annoying to hit") and world.has_flag("donat_joined"), "holding out also ends it")
	ui.cancel_scene()
	GameState.defeated_persistent_enemies.erase(SmokvaWorld.FLAG_PREFIX + "donat_joined")
	world.start_duel()
	world.player._invulnerability = 0.0
	GameState.health = 2
	world.player.take_damage(200)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameState.health > 1 and _scene_texts().contains("Got you") and world.has_flag("donat_joined"), "losing the duel does not stop the story")
	_skip()

func _parrot(kind: String) -> SmokvaBrawler:
	for enemy: SmokvaBrawler in world._parrots:
		if enemy.enemy_id == kind:
			return enemy
	return null

func _bolts() -> Array:
	return world.actors_root.get_children().filter(func(node) -> bool: return node is SpiralBolt and not node.is_queued_for_deletion())

## A walkable spot `distance` from `enemy` that it can dash to unblocked.
func _open_line(enemy: SmokvaBrawler, distance: float) -> Vector2:
	for i in 16:
		var spot := enemy.global_position + Vector2.from_angle(TAU * i / 16.0) * distance
		if world.tiled_loader.is_walkable_position(spot) and enemy._clear_line(spot):
			return spot
	return Vector2.INF

## A walkable spot `distance` from `centre`.
func _walkable_round(centre: Vector2, distance: float) -> Vector2:
	for i in 16:
		var spot := centre + Vector2.from_angle(TAU * i / 16.0) * distance
		if world.tiled_loader.is_walkable_position(spot):
			return spot
	return centre + Vector2(distance, 0)

## The yard spot near the fight with the most open ground round it, out to `radius`.
func _open_area(radius: float) -> Vector2:
	var space := world.get_world_2d().direct_space_state
	var best := world.marker("bar_door") + Vector2(0, 120)
	var best_open := -1
	for x in range(-160, 161, 16):
		for y in range(40, 241, 16):
			var spot: Vector2 = world.marker("bar_door") + Vector2(x, y)
			if not world.tiled_loader.is_walkable_position(spot):
				continue
			var open := 0
			for i in 16:
				var ray := PhysicsRayQueryParameters2D.create(spot, spot + Vector2.from_angle(TAU * i / 16.0) * radius, SmokvaBrawler.DASH_BLOCKERS)
				if space.intersect_ray(ray).is_empty():
					open += 1
			if open > best_open:
				best = spot
				best_open = open
	return best

## A direction from `enemy` in which a wall stands within dashing distance.
func _wall_direction(enemy: SmokvaBrawler) -> Vector2:
	var best := Vector2.ZERO
	var nearest := INF
	for i in 16:
		var direction := Vector2.from_angle(TAU * i / 16.0)
		var ray := PhysicsRayQueryParameters2D.create(enemy.global_position + Vector2(0, -3), enemy.global_position + direction * 160.0 + Vector2(0, -3), SmokvaBrawler.DASH_BLOCKERS, [enemy.get_rid()])
		var hit := world.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and enemy.global_position.distance_to(hit["position"]) < nearest:
			nearest = enemy.global_position.distance_to(hit["position"])
			best = direction
	return best

func _scene_texts() -> String:
	var all := []
	for line: Dictionary in ui._scene_lines:
		all.append(String(line["text"]))
	return "\n".join(all)

## Goes to the scene's last line without ending it.
func _skip_lines() -> void:
	while ui.scene_playing() and ui.scene_lines_left() > 0:
		ui.advance_scene()

## Plays the scene to its end, as if the player clicked through it.
func _skip() -> void:
	_skip_lines()
	if ui.scene_playing() and ui._scene_choices.is_empty():
		ui.advance_scene()

func _choose(index: int) -> void:
	_skip_lines()
	ui._end_scene(ui._scene_choices[index]["action"])

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
	var directory := OS.get_environment("SMOKVA_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))

var _quiet_failed := {}

func _check_quiet(ok: bool, message: String) -> void:
	if ok or _quiet_failed.has(message):
		return
	_quiet_failed[message] = true
	_check(false, message)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + message)

func _finish() -> void:
	print("Smokva smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
