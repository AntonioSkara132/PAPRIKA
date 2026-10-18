extends RefCounted

const Guard = preload("res://scripts/actors/iskra_gang_guard.gd")
const LIMITS := {"shipment": 18.75, "rescue": 11.25}
var _jobs: WeakRef
var jobs: RefCounted:
	get:
		return _jobs.get_ref()
var world: Node2D
var enemies: Dictionary = {}
var _last_second := -1
var _resume_queued := false

func _init(owner_jobs: RefCounted) -> void:
	_jobs = weakref(owner_jobs)
	world = jobs.world

func remaining(job: String) -> float:
	return float(GameState.iskra_gang_state.get(job + "_seconds", LIMITS[job]))

func started(job: String) -> bool:
	return GameState.iskra_gang_state.has(job + "_seconds")

func active(job: String) -> bool:
	if not started(job):
		return false
	if job == "shipment":
		return not jobs.has("shipment_delivered") and not jobs.has("shipment_paid") and not (jobs.has("shipment_loaded_a") and jobs.has("shipment_loaded_b"))
	return jobs.has("rescue_freed") and not jobs.has("rescue_extracted") and not jobs.has("rescue_ransom")

func migrate_timing() -> void:
	var old_scale := float(GameState.iskra_gang_state.get("pressure_version", 1.0)) < 2.0
	for job: String in LIMITS:
		var key := job + "_seconds"
		if GameState.iskra_gang_state.has(key):
			var saved := float(GameState.iskra_gang_state[key])
			GameState.iskra_gang_state[key] = clampf(saved / 4.0 if old_scale else saved, 0.0, LIMITS[job])
	GameState.iskra_gang_state["pressure_version"] = 2.0

func begin(job: String) -> void:
	migrate_timing()
	if job == "rescue" and jobs.has("rescue_ransom"):
		return
	if not started(job):
		GameState.iskra_gang_state[job + "_seconds"] = LIMITS[job]
	var warning := "The inspection crew" if jobs.side() == "pelican" else "The returning warehouse crew"
	var text := "%s will be here in %.2f seconds. I am watching the entrance while Veki prepares the ship. Get both crates aboard. If they arrive, the front door will be guarded; the service door is still an escape route." % [warning, remaining(job)]
	if job == "rescue":
		text = "The lock alarm reached the outer post. I will hold the main entrance, but they can come around the service side. You have %.2f seconds before that group arrives. Bring both prisoners to Veki. The money is optional." % remaining(job)
	if remaining(job) <= 0:
		text = "The extra guards are already here. I will cover the main entrance. Use the service door or fight your way out; the contract is still possible."
	jobs._scene("Davor — from outside", text, Callable())

func reset_runtime() -> void:
	for enemy in enemies.values():
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

func restore() -> void:
	migrate_timing()
	reset_runtime()
	if not started("shipment") and (jobs.has("shipment_carried_a") or jobs.has("shipment_carried_b") or jobs.has("shipment_loaded_a") or jobs.has("shipment_loaded_b")):
		GameState.iskra_gang_state["shipment_seconds"] = LIMITS.shipment
	if not started("rescue") and jobs.has("rescue_freed") and not jobs.has("rescue_ransom"):
		GameState.iskra_gang_state["rescue_seconds"] = LIMITS.rescue
	position_davor()
	if world.get_tree().get_first_node_in_group("game_world") != world:
		if not _resume_queued:
			_resume_queued = true
			_show_resume.call_deferred()
	else:
		_show_resume()

func _show_resume() -> void:
	_resume_queued = false
	if jobs == null or not is_instance_valid(world) or not world.is_inside_tree():
		return
	for job: String in LIMITS:
		if active(job):
			jobs._scene("Davor", "We resume with %.2f seconds on the %s job. %s Close this message when ready; reading it does not use time." % [remaining(job), job, "Guards have arrived, but we can still escape through the service door." if remaining(job) <= 0 else "I am still covering the entrance."], Callable())

func position_davor() -> bool:
	var site: String = jobs.room()
	if site.is_empty():
		return false
	var point: Vector2 = world.marker(site + "_office")
	world.davor.global_position = world.tiled_loader.nearest_walkable_position(point + Vector2(-24, 16))
	world.davor.velocity = Vector2.ZERO
	world.davor.hold_at(world.davor.global_position, "Cover warehouse entrance")
	return true

func step(delta: float) -> void:
	if _resume_queued or world.get_tree().paused or world.player.ui_is_open() or world.taxi_active:
		return
	if not jobs.room().is_empty() and world.davor.order != "hold":
		position_davor()
	for job: String in LIMITS:
		if not active(job):
			continue
		var before := remaining(job)
		var after := maxf(0.0, before - delta)
		GameState.iskra_gang_state[job + "_seconds"] = after
		for fraction in [0.5, 0.2]:
			var key := "pressure_" + job + ("_half" if fraction == 0.5 else "_last")
			if after <= float(LIMITS[job]) * fraction and not jobs.has(key):
				jobs.set_flag(key)
				GameState.notify("Davor: %d seconds. %s" % [ceili(after), "Veki is ready; finish loading." if job == "shipment" else "They are splitting up. Leave the money if you need to."])
		if after <= 0 and not jobs.has("pressure_" + job + "_expired"):
			jobs.set_flag("pressure_" + job + "_expired")
			GameState.notify("Davor: I have the main entrance. Two guards went around the side. Keep moving; we can still get out!")
		_ensure_encounter(job)
		if ceili(after) != _last_second:
			_last_second = ceili(after)
			GameState.military_changed.emit()

func _ensure_encounter(job: String) -> void:
	var site := "freight" if job == "shipment" else "holding"
	if jobs.room() != site:
		return
	if remaining(job) <= float(LIMITS[job]) * 0.5:
		# Davor fights this group outside. Others use a different entrance.
		_spawn(job + "_outside_a", site + "_office", Vector2(32, 16))
		_spawn(job + "_outside_b", site + "_office", Vector2(48, -16))
	if remaining(job) <= 0:
		_spawn(job + "_inside_a", "gang_" + site + "_arrival", Vector2(40, -24))
		_spawn(job + "_inside_b", "gang_" + site + "_side", Vector2(-48, -24))

func _spawn(id: String, marker: String, offset: Vector2) -> void:
	if jobs.has("pressure_down_" + id) or enemies.has(id):
		return
	var enemy := Guard.new()
	var position: Vector2 = world.tiled_loader.nearest_walkable_position(world.marker(marker) + offset)
	enemy.configure("bandit_sword", "res://assets/art/iskra/npcs/tower_guard.png", position, "story_iskra_pressure_" + id)
	enemy.definition.merge({"name": "Dock guard" if id.begins_with("shipment") else "Pelican reinforcement", "max_health": 30, "damage": 4, "reward": 0, "event": "iskra_guard_defeated"}, true)
	enemy.max_health = 30
	enemy.health = 30
	enemy.guard_radius = 650.0
	enemy.defeated.connect(func(_id: String) -> void: jobs.set_flag("pressure_down_" + id))
	world.actors_root.add_child(enemy)
	enemies[id] = enemy

func front_blocked(site: String) -> bool:
	var job := "shipment" if site == "freight" else "rescue"
	if not active(job) or remaining(job) > 0:
		return false
	_ensure_encounter(job)
	return not jobs.has("pressure_down_" + job + "_inside_a")

func ransom() -> void:
	for id: String in enemies.keys():
		if id.begins_with("rescue"):
			if is_instance_valid(enemies[id]):
				enemies[id].queue_free()
			enemies.erase(id)

func status() -> String:
	var lines: Array[String] = []
	for job: String in LIMITS:
		if active(job):
			lines.append("%s: %.2fs" % ["Loading window" if job == "shipment" else "Escape window", remaining(job)] if remaining(job) > 0 else "Extra guards: fight or use the service exit.")
	return "\n".join(lines)
