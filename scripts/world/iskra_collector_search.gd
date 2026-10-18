extends RefCounted

const Guard = preload("res://scripts/actors/iskra_gang_guard.gd")
const ROUTE := ["collector_neighbor", "collector_market", "collector_dispatch", "collector_route_north", "collector_hideout", "collector_route_south"]
const LOCATION_VERSION := 1
const HIDING_ROUTE := ["collector_hideout", "collector_route_north", "collector_route_south"]
var _jobs: WeakRef
var jobs: RefCounted:
	get:
		return _jobs.get_ref()
var world: Node2D
var rival: IskraCitizen
var fighter: Enemy
var escape_target: Node2D
var _target := ""
var _miro_stop := -1

func _init(owner_jobs: RefCounted) -> void:
	_jobs = weakref(owner_jobs)
	world = jobs.world

func setup() -> void:
	escape_target = Node2D.new()
	escape_target.position = world.marker("collector_escape")
	world.actors_root.add_child(escape_target)
	rival = jobs._person("rival_collector", "Radan — Pelican collector", "canal_worker", "collector_rival_start")

func get_value(key: String, fallback: float = 0.0) -> float:
	return float(GameState.iskra_gang_state.get("search_" + key, fallback))

func put(key: String, value: float) -> void:
	GameState.iskra_gang_state["search_" + key] = value

func running() -> bool:
	return jobs.has("hunt_job") and not jobs.has("hunt_paid") and not jobs.has("hunt_refused")

func start() -> void:
	put("version", LOCATION_VERSION)
	put("stage", 0)
	put("wait", 0)
	rival.wait_at(world.marker("collector_rival_start"))
	jobs.collector.wait_at(world.marker("collector_hideout"))
	_patrol()
	_target = ""
	capture()
	jobs._tell("Ves", "Radan is already checking the west-side lodging house at No Questions, then the western market stalls and the nature park's northwest corner. He is an ordinary collector, but he knows those streets. Reach Miro first if you want a private conversation. If Radan catches him, you can still intercept them before the collection point by Textiles.")

func _patrol() -> void:
	var stops := PackedVector2Array()
	for id in HIDING_ROUTE:
		stops.append(world.marker(id))
	jobs.collector.set_route(stops)
	jobs.collector._wait = 12.0
	_miro_stop = jobs.collector._stop_index

func _walk_rival(marker: String) -> void:
	if _target == marker:
		return
	_target = marker
	var point: Vector2 = world.marker(marker)
	rival.set_route(PackedVector2Array([point, point]))
	rival._wait = 0.0

func _visible() -> void:
	jobs._show(rival, running() and not jobs.has("hunt_rival_down") and not is_instance_valid(fighter))

func capture() -> void:
	if rival == null or not jobs.has("hunt_job"):
		return
	var position: Vector2 = fighter.global_position if is_instance_valid(fighter) and jobs.has("hunt_intercept_fight") else rival.global_position
	put("rival_x", position.x)
	put("rival_y", position.y)
	if is_instance_valid(fighter) and jobs.has("hunt_intercept_fight"):
		put("fighter_health", fighter.health)
	put("miro_x", jobs.collector.global_position.x)
	put("miro_y", jobs.collector.global_position.y)
	put("miro_stop", jobs.collector._stop_index)
	put("miro_wait", maxf(0.0, jobs.collector._wait))

func migrate_location() -> void:
	if get_value("version") >= LOCATION_VERSION:
		return
	put("version", LOCATION_VERSION)
	if not jobs.has("hunt_job"):
		return
	# Existing contracts keep decisions, rewards, search progress and combat health.
	# An actor in the old search district resumes at the matching western stop.
	var stage := clampi(int(get_value("stage")), 0, ROUTE.size() - 1)
	var rival_position: Vector2 = world.marker(ROUTE[stage])
	var miro_position: Vector2 = world.marker(HIDING_ROUTE[clampi(int(get_value("miro_stop")), 0, HIDING_ROUTE.size() - 1)])
	if jobs.has("hunt_rival_delivered"):
		rival_position = world.marker("collector_holding")
		miro_position = world.tiled_loader.nearest_walkable_position(rival_position + Vector2(24, 16))
	elif jobs.has("hunt_rival_custody") or jobs.has("hunt_intercept_fight") or jobs.has("hunt_rival_released"):
		rival_position = world.tiled_loader.nearest_walkable_position(miro_position + Vector2(32, 0))
	elif jobs.has("hunt_escape_safe"):
		miro_position = world.marker("collector_escape")
	put("rival_x", rival_position.x)
	put("rival_y", rival_position.y)
	# A player-led escort may already be anywhere in the city; do not separate it.
	if not jobs.has("hunt_escort"):
		put("miro_x", miro_position.x)
		put("miro_y", miro_position.y)

func restore() -> void:
	migrate_location()
	if is_instance_valid(fighter):
		fighter.queue_free()
	fighter = null
	_target = ""
	var rival_position := Vector2(get_value("rival_x", world.marker("collector_rival_start").x), get_value("rival_y", world.marker("collector_rival_start").y))
	rival.wait_at(world.tiled_loader.nearest_walkable_position(rival_position))
	if running():
		var fallback: Vector2 = jobs.collector.global_position if jobs.has("hunt_escort") else world.marker("collector_hideout")
		var miro_position := Vector2(get_value("miro_x", fallback.x), get_value("miro_y", fallback.y))
		jobs.collector.wait_at(world.tiled_loader.nearest_walkable_position(miro_position))
		if jobs.has("hunt_escort"):
			jobs.collector.follow_for_rescue(world.player, 0)
		elif jobs.has("hunt_rival_custody"):
			jobs.collector.follow_for_rescue(rival, 0)
		elif jobs.has("hunt_escape_pending"):
			_escape_route()
		elif not jobs.hunt_decided() and not jobs.has("hunt_rival_delivered"):
			_patrol()
			jobs.collector._stop_index = clampi(int(get_value("miro_stop")), 0, HIDING_ROUTE.size() - 1)
			jobs.collector._wait = get_value("miro_wait", 12)
			_miro_stop = jobs.collector._stop_index
		if jobs.has("hunt_intercept_fight") and not jobs.has("hunt_rival_down"):
			_spawn_fighter()
	_visible()

func step(delta: float) -> void:
	if not running():
		rival.wait_at(rival.global_position)
		if jobs.has("hunt_paid") or jobs.has("hunt_refused"):
			jobs.collector.wait_at(jobs.collector.global_position)
		_visible()
		return
	if world.get_tree().paused or world.player.ui_is_open() or world.taxi_active:
		return
	if not jobs.has("hunt_escape_pending") and jobs.collector._mode == "routine" and jobs.collector._stop_index != _miro_stop:
		_miro_stop = jobs.collector._stop_index
		jobs.collector._wait = 12.0
	if not jobs.has("hunt_found") and world.player.global_position.distance_to(jobs.collector.global_position) <= 56:
		jobs.set_flag("hunt_found")
		GameState.notify("Davor: Brown coat, red book. That is Miro. Speak to him before Radan reaches him.")
	if jobs.has("hunt_escape_pending") and jobs.collector.global_position.distance_to(world.marker("collector_escape")) < 30:
		jobs.clear_flag("hunt_escape_pending")
		jobs.set_flag("hunt_escape_safe")
		jobs.collector.wait_at(jobs.collector.global_position)
		GameState.notify("Miro reached the departing crew at the western market landing pad. Report to Ves.")
		jobs.sync()
	if jobs.has("hunt_escort") or jobs.has("hunt_escape_safe") or jobs.has("hunt_rival_down") or jobs.has("hunt_intercept_fight") or jobs.has("hunt_rival_released"):
		rival.wait_at(rival.global_position)
		capture()
		_visible()
		return
	if jobs.has("hunt_rival_custody"):
		_walk_rival("collector_holding")
		if rival.global_position.distance_to(world.marker("collector_holding")) < 24 and jobs.collector.global_position.distance_to(world.marker("collector_holding")) < 55:
			jobs.clear_flag("hunt_rival_custody")
			jobs.clear_flag("hunt_escape_pending")
			jobs.set_flag("hunt_rival_delivered")
			rival.wait_at(world.marker("collector_holding"))
			jobs.collector.wait_at(world.tiled_loader.nearest_walkable_position(world.marker("collector_holding") + Vector2(24, 16)))
			GameState.notify("Radan delivered Miro to the collection point by Textiles. No capture bounty is yours, but you can still negotiate or free Miro there.")
	elif jobs.has("hunt_rival_delivered"):
		rival.wait_at(rival.global_position)
	else:
		var stage := clampi(int(get_value("stage")), 0, ROUTE.size() - 1)
		var destination: String = ROUTE[stage]
		_walk_rival(destination)
		if rival.global_position.distance_to(world.marker(destination)) < 24:
			rival.wait_at(rival.global_position)
			put("wait", get_value("wait") + delta)
			if get_value("wait") >= 10.0:
				put("wait", 0)
				put("stage", stage + 1 if stage < ROUTE.size() - 1 else 3)
				_target = ""
		if rival.global_position.distance_to(jobs.collector.global_position) < 32:
			var path: PackedVector2Array = world.tiled_loader.get_walk_path(rival.global_position, jobs.collector.global_position)
			if not path.is_empty() and path.size() < 6:
				jobs.set_flag("hunt_rival_custody")
				jobs.set_flag("hunt_found")
				jobs.collector.follow_for_rescue(rival, 0)
				_target = ""
				GameState.notify("Radan caught Miro in the western streets. Intercept them before the collection point by Textiles, or arrange a release there.")
	capture()
	_visible()

func hint() -> String:
	if not running():
		return "That search is closed. Radan is no longer following this contract."
	if jobs.has("hunt_escape_safe"):
		return "Miro reached the departing crew at the western market landing pad. Radan is no longer searching."
	if jobs.has("hunt_rival_released"):
		return "You took responsibility for Miro. Radan is no longer searching."
	if jobs.has("hunt_intercept_fight"):
		return "Radan is guarding Miro where you confronted him, not checking another lead."
	if jobs.has("hunt_rival_delivered"):
		return "Radan brought Miro to the collection point in front of Textiles, southwest of the nature park."
	if jobs.has("hunt_rival_custody"):
		return "Radan has Miro and is walking south to the collection point in front of Textiles."
	if jobs.has("hunt_rival_down") or jobs.has("hunt_escort"):
		return "Radan is no longer searching."
	var names := ["the west-side lodging house at No Questions", "the western market stalls", "the nature park's northwest corner", "the northern end of the nature park's west lane", "the passage between the nature park and greenhouse", "the lane's southern end at the park's southwest corner"]
	var stage := clampi(int(get_value("stage")), 0, names.size() - 1)
	return "Radan is %s %s. Miro keeps walking up and down the lane between the nature park and the western greenhouse, stopping halfway along it. Look for his brown coat and red book." % ["checking" if get_value("wait") > 0 else "walking toward", names[stage]]

func encounter() -> void:
	if not running():
		return
	if not jobs.has("hunt_rival_custody") and not jobs.has("hunt_rival_delivered"):
		jobs._tell("Radan", "Ves hired you too? I am checking the western streets. " + hint(), [jobs._choice("Leave", Callable())])
		return
	var price := 45 if jobs.has("hunt_rival_delivered") else 20
	jobs._tell("Radan", "I have Miro. " + ("I already delivered him. Ves owes you no capture bounty. You can pay for a private release or fight me for him." if jobs.has("hunt_rival_delivered") else "We can discuss custody here, before I reach the collection point by Textiles."), [
		jobs._choice("Demand custody under Ves's contract", func() -> void: intercept("demand")),
		jobs._choice("Negotiate a private release — %d gold" % price, func() -> void: intercept("negotiate")),
		jobs._choice("Fight Radan to free Miro", func() -> void: intercept("fight")),
		jobs._choice("Leave", Callable()),
	])

func intercept(mode: String) -> bool:
	if not running() or rival.global_position.distance_to(world.player.global_position) > 60 or (not jobs.has("hunt_rival_custody") and not jobs.has("hunt_rival_delivered")):
		return false
	if mode == "demand":
		if jobs.has("hunt_rival_delivered"):
			jobs._tell("Radan", "The delivery is already recorded. Your contract does not override it. Negotiate or try to force a release.")
			return false
		_transfer()
		jobs._tell("Radan", "You have the contract too. Take custody, then. I will tell Ves who took responsibility.")
	elif mode == "negotiate":
		if not GameState.spend_gold(45 if jobs.has("hunt_rival_delivered") else 20):
			jobs._tell("Radan", "You cannot pay that. You can still challenge me; I will not pretend this is a friendly favor.")
			return false
		_transfer()
	elif mode == "fight":
		if jobs.has("hunt_intercept_fight"):
			return false
		jobs.set_flag("hunt_intercept_fight")
		jobs.collector.wait_at(jobs.collector.global_position)
		rival.wait_at(rival.global_position)
		_spawn_fighter()
	else:
		return false
	return true

func _spawn_fighter() -> void:
	fighter = Guard.new()
	fighter.configure("bandit_sword", "res://assets/art/iskra/npcs/canal_worker.png", rival.global_position, "story_iskra_rival_collector")
	fighter.definition.merge({"name": "Radan — collector", "max_health": 42, "damage": 5, "reward": 0, "event": "iskra_guard_defeated"}, true)
	fighter.max_health = 42
	fighter.health = clampi(int(get_value("fighter_health", 42)), 1, 42)
	fighter.defeated.connect(func(_id: String) -> void:
		jobs.set_flag("hunt_rival_down")
		_transfer())
	world.actors_root.add_child(fighter)
	_visible()

func _transfer() -> void:
	jobs.clear_flag("hunt_rival_custody")
	jobs.clear_flag("hunt_intercept_fight")
	jobs.set_flag("hunt_rival_released")
	jobs.set_flag("hunt_found")
	rival.wait_at(rival.global_position)
	_target = ""
	jobs.collector.wait_at(jobs.collector.global_position)
	if jobs.has("hunt_money") or jobs.has("hunt_bribe"):
		begin_escape()
	else:
		# A private conversation keeps the original four decisions available.
		jobs._tell("Miro", "You got him away from me. Talk to me here before deciding what to do.")
	capture()
	jobs.sync()

func begin_escape() -> void:
	jobs.set_flag("hunt_escape_pending")
	_escape_route()

func _escape_route() -> void:
	jobs.collector.follow_for_rescue(escape_target, 0)
	_miro_stop = -1

func can_report() -> bool:
	if jobs.has("hunt_escape_pending"):
		jobs._tell("Ves", "You have not finished your account of Miro yet. Decide what to do about Radan, or let Miro reach the departing crew before reporting.")
		return false
	return true
