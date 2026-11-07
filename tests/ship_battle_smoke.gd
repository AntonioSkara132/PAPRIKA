extends Node

## Ship battle checks: the Lasta's sides, firing and reloading, TNT damage,
## the dust current, the Parrots' bolts and ring, ramming, the escape, a lost
## battle, and the scrap thieves: closing in, scrap sprays, the claw and the
## dead engine; the Council's diplomatic ship as the player's ship and the
## hackers: their harpoon hitting and missing, the hackers coming straight in
## after a time, fastening on when the ships touch and jumping across when
## their ship is wrecked. Set BATTLE_SCREENSHOT_DIR to save screenshots when the test
## runs with a window.

const STEP := 1.0 / 60.0

var checks := 0
var failures := 0
var layer: CanvasLayer

func _ready() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)

func _run() -> void:
	var main: Node2D = load("res://scripts/main.gd").new()
	main._ensure_input_actions()
	main.free()
	layer = CanvasLayer.new()
	add_child(layer)
	var battle := _new_battle()
	await get_tree().process_frame
	check(battle.player.display_name == "Lasta" and battle.player.hull == 100, "The Lasta starts with a full hull")
	check(battle.enemy.display_name == "Purple Parrots" and battle.enemy.hull == 120, "The Parrots start with a full hull")
	check(battle.state == "fight", "The battle starts as a fight")
	check(battle.player.texture != null and battle.enemy.texture != null, "Both ships have sprites")
	_step(battle, 0.05)
	check(not battle.radio_line.is_empty() and battle.radio_line[0] == "Veki", "Veki speaks first on the radio")
	await _capture(battle, "ship_battle_start")

	# Sides: nose pointing right, left is up the screen.
	_hold(battle, Vector2(300, 500), 0.0, Vector2(900, 300), PI)
	check(battle.player.side_direction("left").is_equal_approx(Vector2.UP), "Left side points up when the nose points right")
	check(battle.player.side_facing(Vector2(300, 400)) == "left", "A point above is off the left side")
	check(battle.player.side_facing(Vector2(300, 600)) == "right", "A point below is off the right side")
	check(battle.player.side_facing(Vector2(400, 500)) == "", "A point ahead is off the nose, where there are no launchers")
	check(battle.player.launcher_points("left").size() == 3, "Three launchers a side")

	# Firing and reloading.
	check(battle.fire("left"), "The loaded left side fires")
	check(battle.tnt.size() == 3, "A broadside is three barrels")
	check(not battle.fire("left"), "The left side cannot fire while it reloads")
	check(battle.player.ready_to_fire("right"), "The right side reloads on its own")
	_step(battle, battle.player.reload_seconds + 0.1)
	check(battle.player.ready_to_fire("left"), "The left side reloads")

	# TNT hits a ship off the side.
	battle = _new_battle()
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), 0.0, Vector2(400, 440), PI)
	_freeze_enemy(battle)
	check(battle.fire("left"), "Fires at the Parrots off the left side")
	_step(battle, 1.6)
	check(battle.tnt.is_empty(), "Every barrel bursts")
	check(battle.enemy.hull <= 120 - battle.player.tnt_damage * 2, "Two or more barrels hit the Parrots (hull %d)" % battle.enemy.hull)
	check(battle.player.hull == 100, "The Lasta's own TNT does not hurt her (hull %d, enemy at %s, Lasta at %s)" % [battle.player.hull, battle.enemy.position, battle.player.position])

	# Barrels fired away from the enemy miss.
	battle = _new_battle()
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), 0.0, Vector2(400, 440), PI)
	_freeze_enemy(battle)
	battle.fire("right")
	await _capture(battle, "ship_battle_broadside", 0.25)
	_step(battle, 1.6)
	check(battle.enemy.hull == 120, "A broadside from the far side misses")

	# Space fires the side facing the enemy.
	_hold(battle, Vector2(400, 500), 0.0, Vector2(400, 600), PI)
	check(battle.side_toward_enemy() == "left" or battle.side_toward_enemy() == "right", "Space always picks a side")
	check(battle.side_toward_enemy() == "right", "Space picks the side facing the enemy")
	_hold(battle, Vector2(400, 500), 0.0, Vector2(400, 440), PI)
	_step(battle, battle.player.reload_seconds + 0.1)
	var space := InputEventAction.new()
	space.action = "attack"
	space.pressed = true
	battle._input(space)
	check(not battle.player.ready_to_fire("left") and battle.player.ready_to_fire("right"), "Space fired the left side, toward the Parrots")
	var key_e := InputEventAction.new()
	key_e.action = "ship_fire_right"
	key_e.pressed = true
	battle._input(key_e)
	check(not battle.player.ready_to_fire("right"), "E fires the right side")
	check(InputMap.action_get_events("ship_fire_left").size() == 1, "Q is bound to firing left")

	# The current.
	var middle: Vector2 = (battle.current_from + battle.current_to) / 2.0
	check(is_equal_approx(battle.current_at(middle).length(), battle.current_strength), "The current is strongest in its middle")
	check(battle.current_at(middle + battle.current_direction().orthogonal() * battle.current_width).is_zero_approx(), "No current outside the band")
	var with_current := BattleShip.new("lasta", middle, battle.current_direction().angle())
	var against := BattleShip.new("lasta", middle, battle.current_direction().angle() + PI)
	for ship: BattleShip in [with_current, against]:
		ship.speed = ship.max_speed
		for i in 60:
			ship.steer_and_move(0.0, 1.0, battle.current_at(middle), STEP)
	check(with_current.position.distance_to(middle) > against.position.distance_to(middle) + 30.0, "Flying with the current is faster than against it")

	# Steering.
	_hold(battle, Vector2(400, 500), 0.0, Vector2(1200, 900), PI)
	_freeze_enemy(battle)
	Input.action_press("move_right")
	_step(battle, 0.5)
	Input.action_release("move_right")
	check(battle.player.heading > 0.3, "Right turns the Lasta clockwise")
	var speed_before := battle.player.speed
	Input.action_press("move_up")
	_step(battle, 0.5)
	Input.action_release("move_up")
	check(battle.player.speed > speed_before, "Up speeds the Lasta up")
	Input.action_press("move_down")
	_step(battle, 3.0)
	Input.action_release("move_down")
	check(battle.player.speed == 0.0, "Down slows her to a stop")
	battle.player.position = Vector2(-50, -50)
	_step(battle, STEP)
	check(BattleShip.new("lasta", Vector2.ZERO, 0.0) != null and battle.ARENA.has_point(battle.player.position), "The Lasta stays inside the arena")

	# The Parrots' aimed bolts.
	battle = _new_battle()
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), PI / 2.0, Vector2(600, 500), PI)
	battle.bolt_wait = 0.0
	battle.ring_wait = 100.0
	battle.enemy.speed = 0.0
	battle.player.speed = 0.0
	_step(battle, STEP)
	check(battle.bolts.size() == 2, "The Parrots fire two bolts when they face the Lasta")
	_step(battle, 1.2)
	check(battle.player.hull < 100, "Their bolts hurt the Lasta (hull %d)" % battle.player.hull)

	# The ring: lamps glow first, then eight curving bolts.
	battle = _new_battle()
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), PI / 2.0, Vector2(500, 500), PI / 2.0)
	battle.ring_wait = 0.0
	battle.bolt_wait = 100.0
	battle.enemy.max_speed = 0.0
	battle.enemy.speed = 0.0
	_step(battle, STEP)
	check(battle.ring_warning > 0.0 and battle.bolts.is_empty(), "The lamps glow before the ring")
	await _capture(battle, "ship_battle_ring_warning", 0.6)
	_step(battle, battle.RING_WARN_SECONDS)
	check(battle.bolts.size() == battle.RING_BOLTS, "The ring is eight bolts")
	check(battle.bolts.all(func(bolt: Dictionary) -> bool: return float(bolt["turn"]) != 0.0), "Ring bolts curve into a spiral")
	await _capture(battle, "ship_battle_ring", 0.4)

	# Ramming hurts both ships.
	battle = _new_battle()
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), 0.0, Vector2(420, 500), PI)
	_freeze_enemy(battle)
	_step(battle, STEP)
	check(battle.player.hull == 100 - battle.RAM_DAMAGE and battle.enemy.hull == 120 - battle.RAM_DAMAGE, "A ram hurts both ships")
	check(battle.player.position.distance_to(battle.enemy.position) >= battle.player.radius + battle.enemy.radius - 0.5, "Rammed ships are pushed apart")

	# The Parrots keep off the Lasta's sides while she flies straight.
	battle = _new_battle()
	await get_tree().process_frame
	_hold(battle, Vector2(300, 700), -0.35, Vector2(900, 300), PI)
	battle.bolt_wait = 100.0
	battle.ring_wait = 100.0
	var in_wedge := 0
	for i in 480:
		battle.player.hull = 100
		battle.step(STEP)
		if battle.player.side_facing(battle.enemy.position) != "" and battle.player.position.distance_to(battle.enemy.position) < 260.0:
			in_wedge += 1
	check(in_wedge < 240, "The Parrots spend most of the time off the Lasta's nose or tail (%d of 480 frames in a side wedge)" % in_wedge)

	# The escape.
	battle = _new_battle()
	await get_tree().process_frame
	var results: Array = []
	battle.finished.connect(func(result: String) -> void: results.append(result))
	battle._damage(battle.enemy, 1000)
	check(battle.enemy.hull == 1, "The Parrots' hull never reaches 0")
	_step(battle, STEP)
	check(battle.state == "flee", "Badly hurt, the Parrots flee")
	check(battle._radio_queue.any(func(line: Array) -> bool: return line[0] == "Luster"), "Luster shouts on the radio as they flee")
	await _capture(battle, "ship_battle_flee", 1.5)
	var waited := 0.0
	while battle.state == "flee" and waited < 12.0:
		battle.player.hull = 100
		_step(battle, 0.25)
		waited += 0.25
	check(battle.state == "won", "The battle is won when they get away")
	await _capture(battle, "ship_battle_won")
	_step(battle, battle.END_SECONDS + 0.1)
	check(results == ["won"], "finished reports a won battle once")
	await get_tree().process_frame
	check(not is_instance_valid(battle), "The battle frees itself")

	# A lost battle.
	battle = _new_battle()
	await get_tree().process_frame
	results = []
	battle.finished.connect(func(result: String) -> void: results.append(result))
	battle._damage(battle.player, 1000)
	_step(battle, STEP)
	check(battle.state == "lost", "The battle is lost at hull 0")
	check(battle.end_banner() == "THE LASTA CAN'T TAKE MORE", "The lost banner comes from the Lasta's ship data")
	check(not battle.fire("left"), "No firing after the battle")
	_step(battle, battle.END_SECONDS + 0.1)
	check(results == ["lost"], "finished reports a lost battle")

	# The scrap thieves.
	battle = _new_battle("scrap_ship")
	await get_tree().process_frame
	check(battle.enemy.display_name == "Scrap Thieves" and battle.enemy.hull == 70, "The scrap thieves start with a full hull")
	check(not battle.flees(), "The scrap thieves do not flee")
	_hold(battle, Vector2(400, 500), PI / 2.0, Vector2(800, 500), PI / 2.0)
	battle.player.max_speed = 0.0
	battle.player.speed = 0.0
	battle.scrap_wait = 100.0
	var start_distance := battle.player.position.distance_to(battle.enemy.position)
	# They start facing away, so they swing round in an arc first.
	_step(battle, 8.0)
	check(battle.player.position.distance_to(battle.enemy.position) < start_distance - 150.0, "The scrap thieves come straight at the Lasta (%.0f to %.0f)" % [start_distance, battle.player.position.distance_to(battle.enemy.position)])
	check(battle.bolts.is_empty() and battle.ring_warning == 0.0, "The scrap thieves have no bolts or ring")

	battle = _new_battle("scrap_ship")
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), PI / 2.0, Vector2(520, 500), PI)
	_freeze_enemy(battle)
	battle.scrap_wait = 0.0
	_step(battle, STEP)
	check(battle.bolts.size() == 6 and battle.bolts.all(func(piece: Dictionary) -> bool: return piece["kind"] == "scrap"), "The thieves throw a spray of six pieces of scrap")
	await _capture(battle, "ship_battle_scrap_spray", 0.3)
	_step(battle, 1.2)
	check(battle.player.hull < 100 and battle.player.hull >= 100 - 6 * 2, "Scrap hurts the Lasta a little (hull %d)" % battle.player.hull)

	battle = _new_battle("scrap_ship")
	await get_tree().process_frame
	_hold(battle, Vector2(800, 500), PI / 2.0, Vector2(400, 500), 0.0)
	_freeze_enemy(battle)
	battle.scrap_wait = 0.0
	_step(battle, STEP)
	check(battle.bolts.is_empty(), "No scrap is thrown when the Lasta is out of reach")

	battle = _new_battle("scrap_ship")
	await get_tree().process_frame
	_hold(battle, Vector2(400, 500), 0.0, Vector2(430, 500), PI)
	_freeze_enemy(battle)
	battle.scrap_wait = 100.0
	_step(battle, STEP)
	check(battle.player.hull == 100 - 8 and battle.enemy.hull == 70 - battle.RAM_DAMAGE, "The claw hurts the Lasta more than a ram (hull %d)" % battle.player.hull)

	battle = _new_battle("scrap_ship")
	await get_tree().process_frame
	results = []
	battle.finished.connect(func(result: String) -> void: results.append(result))
	battle.enemy.speed = battle.enemy.max_speed
	battle._damage(battle.enemy, 1000)
	check(battle.enemy.hull == 0 and battle.enemy_disabled and battle.state == "won", "At 0 hull the thieves' engine dies and the battle is won")
	var heading := battle.enemy.heading
	var drift_from := battle.enemy.position
	await _capture(battle, "ship_battle_scrap_won", 1.0)
	check(battle.enemy.position != drift_from and battle.enemy.heading != heading, "The dead ship drifts and spins")
	check(battle.enemy.speed < battle.enemy.max_speed * 0.7, "The dead ship slows down")
	var hull_after := battle.player.hull
	battle._damage(battle.player, 50)
	check(battle.player.hull == hull_after, "Nothing is hurt after the battle is won")
	_step(battle, battle.END_SECONDS)
	check(results == ["won"], "finished reports the win over the thieves")

	# The Council's diplomatic ship against the hackers.
	battle = _new_battle("hacker_ship", "diplomatic_ship")
	await get_tree().process_frame
	check(battle.player.display_name == "Council Ship" and battle.player.hull == 90 and battle.player.launcher_points("left").size() == 2, "player_id puts the player in the diplomatic ship: 90 hull, two launchers a side")
	check(battle.enemy.display_name == "Hackers" and battle.enemy.hull == 160 and battle.player.texture != null and battle.enemy.texture != null, "The hackers' ship has 160 hull, and both ships have sprites")
	check(battle._bolt_colour() == Color("5fd6d3") and battle.harpoon_wait == 22.0, "The hackers' bolts are teal and their first harpoon waits 22 seconds")
	await _capture(battle, "ship_battle_hackers", 0.5)
	_hold(battle, Vector2(500, 500), PI / 2.0, Vector2(620, 500), PI)
	_freeze_enemy(battle)
	_step(battle, 1.0)
	check(battle.harpoon.is_empty(), "No harpoon before harpoon_first")

	# A harpoon that hits.
	battle.harpoon_wait = 0.0
	_step(battle, STEP)
	check(not battle.harpoon.is_empty() and battle._radio_queue.any(func(line: Array) -> bool: return line[1] == "Harpoon!"), "Facing the ship and in range, the hackers fire the harpoon, and the radio warns")
	await _capture(battle, "ship_battle_harpoon", 0.3)
	results = []
	battle.finished.connect(func(result: String) -> void: results.append(result))
	_step(battle, 1.2)
	check(battle.state == "harpooned" and battle.end_banner() == "HARPOONED", "A harpoon that hits ends the battle: HARPOONED")
	check(battle.player.hull == 90, "The harpoon does no damage")
	var gap := battle.player.position.distance_to(battle.enemy.position)
	await _capture(battle, "ship_battle_harpooned", 1.0)
	check(battle.player.position.distance_to(battle.enemy.position) < gap, "The harpooned ship is reeled in")
	_step(battle, battle.END_SECONDS)
	check(results == ["harpooned"], "finished reports harpooned")

	# A harpoon that misses: the ship has moved out of its line.
	battle = _new_battle("hacker_ship", "diplomatic_ship")
	await get_tree().process_frame
	_hold(battle, Vector2(500, 500), PI / 2.0, Vector2(620, 500), PI)
	_freeze_enemy(battle)
	battle.harpoon_wait = 0.0
	_step(battle, STEP)
	check(not battle.harpoon.is_empty(), "The harpoon is fired")
	battle.player.position = Vector2(500, 300)
	_step(battle, 2.0)
	check(battle.harpoon.is_empty() and battle.state == "fight" and battle._said.has("harpoon_miss"), "A harpoon that misses is reeled back, and the fight goes on")
	check(battle.harpoon_wait > 0.0, "The next harpoon has to wait")

	# Touching the hackers' ship fastens it on.
	battle = _new_battle("hacker_ship", "diplomatic_ship")
	await get_tree().process_frame
	_hold(battle, Vector2(500, 500), 0.0, Vector2(525, 500), PI)
	_freeze_enemy(battle)
	_step(battle, STEP)
	check(battle.state == "harpooned" and battle.player.hull == 90 and battle.enemy.hull == 160, "Touching the hackers' ship ends the battle harpooned, without ram damage")

	# They keep their distance, then come straight in after close_in_after.
	battle = _new_battle("hacker_ship", "diplomatic_ship")
	await get_tree().process_frame
	_hold(battle, Vector2(800, 500), 0.0, Vector2(970, 500), PI)
	battle.player.max_speed = 0.0
	battle.player.speed = 0.0
	battle.bolt_wait = 100.0
	battle.harpoon_wait = 100.0
	check(battle.current_tactic() == "standoff", "The hackers start by keeping their distance")
	_step(battle, 4.0)
	check(battle.state == "fight" and battle.player.position.distance_to(battle.enemy.position) > 80.0, "Standing off, they stay away from the ship (%.0f)" % battle.player.position.distance_to(battle.enemy.position))
	battle._time = 75.5
	check(battle.current_tactic() == "close_in", "After 75 seconds they come straight in")
	_step(battle, 8.0)
	check(battle.state == "harpooned", "Coming in, they reach the ship and fasten on")

	# Wrecking their ship: the hackers jump across anyway.
	battle = _new_battle("hacker_ship", "diplomatic_ship")
	await get_tree().process_frame
	results = []
	battle.finished.connect(func(result: String) -> void: results.append(result))
	battle._damage(battle.enemy, 100)
	check(battle.state == "fight" and battle.enemy.hull == 60, "Above the board share the fight goes on")
	battle._damage(battle.enemy, 1000)
	check(battle.state == "boarded" and battle.enemy.hull >= 1 and battle.enemy_disabled, "At the board share their ship is wrecked and drifts")
	check(battle.phase_flashes.size() == 2 and battle.end_banner() == "THEY'RE COMING ACROSS", "A phase hacker jumps across: THEY'RE COMING ACROSS")
	await _capture(battle, "ship_battle_boarded", 0.5)
	_step(battle, battle.END_SECONDS)
	check(results == ["boarded"], "finished reports boarded")

	# The diplomatic ship's own lost banner.
	battle = _new_battle("hacker_ship", "diplomatic_ship")
	await get_tree().process_frame
	battle._damage(battle.player, 1000)
	_step(battle, STEP)
	check(battle.state == "lost" and battle.end_banner() == "THEY'RE COMING ALONGSIDE", "The diplomatic ship's lost banner comes from its ship data")
	await _capture(battle, "ship_battle_council_lost")

	# Pausing.
	battle = _new_battle()
	await get_tree().process_frame
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	battle._input(escape)
	check(battle.paused, "Esc pauses the battle")
	battle.set_process(true)
	var position := battle.player.position
	await get_tree().process_frame
	await get_tree().process_frame
	check(battle.player.position == position, "Nothing moves while paused")
	await _capture(battle, "ship_battle_paused")
	battle._input(escape)
	check(not battle.paused, "Esc again goes on")
	battle.queue_free()

	print("Ship battle: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _new_battle(enemy_id: String = "parrot_ship", player_id: String = "lasta") -> ShipBattle:
	for child in layer.get_children():
		child.queue_free()
	var battle := ShipBattle.new()
	battle.enemy_id = enemy_id
	battle.player_id = player_id
	battle.lines = {
		"start": [["Veki", "Turn a side to them."]],
		"side_open": [["Veki", "Fire {side}!"]],
		"flee": [["Luster", "Julius will hear of this!"]],
		"harpoon": [["Klara", "Harpoon!"]],
		"harpoon_miss": [["Klara", "Missed us."]],
	}
	layer.add_child(battle)
	battle.set_process(false)
	return battle

func _hold(battle: ShipBattle, player_at: Vector2, player_heading: float, enemy_at: Vector2, enemy_heading: float) -> void:
	battle.player.position = player_at
	battle.player.heading = player_heading
	battle.enemy.position = enemy_at
	battle.enemy.heading = enemy_heading

func _freeze_enemy(battle: ShipBattle) -> void:
	battle.enemy.max_speed = 0.0
	battle.enemy.speed = 0.0
	battle.enemy.turn_rate = 0.0
	battle.player.max_speed = maxf(battle.player.max_speed, 0.0)
	battle.player.speed = 0.0
	battle.bolt_wait = 100.0
	battle.ring_wait = 100.0

func _step(battle: ShipBattle, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and is_instance_valid(battle):
		battle.step(minf(STEP, left))
		left -= STEP

## Steps the battle `seconds` further, then saves a screenshot.
func _capture(battle: ShipBattle, label: String, seconds: float = 0.0) -> void:
	_step(battle, seconds)
	var directory := OS.get_environment("BATTLE_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	battle.queue_redraw()
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
