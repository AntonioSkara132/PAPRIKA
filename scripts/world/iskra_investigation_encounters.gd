extends RefCounted

const Data = preload("res://scripts/world/iskra_investigation_data.gd")
const Fighter = preload("res://scripts/actors/iskra_investigation_enemy.gd")
const Ally = preload("res://scripts/actors/iskra_investigation_ally.gd")
const BanishingArrow = preload("res://scripts/actors/iskra_banishing_arrow.gd")

var _investigation: WeakRef
var investigation: RefCounted:
	get:
		return _investigation.get_ref()
var world: Node2D
var enemies: Dictionary = {}
var allies: Dictionary = {}
var arrow: Node2D
var player_arrow: Node2D
var _visible_site := ""
var _restoring := false
var _davor_paused := false
var _davor_was_processing := false

func _init(owner_investigation: RefCounted) -> void:
	_investigation = weakref(owner_investigation)
	world = owner_investigation.world

func setup() -> void:
	apply_loaded_state()

func _state() -> Dictionary:
	return GameState.iskra_investigation_state

func _has(flag: String) -> bool:
	return investigation.has(flag)

func _site() -> String:
	for site: String in Data.ROOMS:
		if Data.ROOMS[site].has_point(world.player.global_position):
			return site
	return ""

func _actors() -> Dictionary:
	if not _state().has("actors"):
		_state()["version"] = Data.VERSION
		_state()["actors"] = {}
	return _state()["actors"]

func _saved(actor_id: String) -> Dictionary:
	return _actors().get(actor_id, {})

func _dead(actor_id: String) -> bool:
	return GameState.defeated_persistent_enemies.has("story_iskra_inv_" + actor_id) or (_saved(actor_id).has("health") and float(_saved(actor_id).health) <= 0.0)

func _safe_point(point: Vector2, fallback: Vector2, site: String) -> Vector2:
	if not point.is_finite() or (not site.is_empty() and not Data.ROOMS[site].has_point(point)) or not world.tiled_loader.is_walkable_position(point):
		return fallback
	return point

func _save_enemy(actor_id: String, actor: Variant) -> void:
	if not is_instance_valid(actor):
		return
	_actors()[actor_id] = {"x": actor.global_position.x, "y": actor.global_position.y, "health": actor.health, "alive": actor.health > 0 and actor.mode != "escaped", "mode": actor.mode}
	if actor_id == "assassin" and actor.mode in ["shoot", "attack", "flee", "surrendered", "captured", "escaped"]:
		_state()["assassin_phase"] = actor.mode

func capture_state() -> void:
	if is_instance_valid(arrow):
		_state()["banishing_arrow"] = arrow.snapshot()
	for actor_id: String in enemies.keys():
		if is_instance_valid(enemies[actor_id]):
			_save_enemy(actor_id, enemies[actor_id])
		else:
			enemies.erase(actor_id)
	for actor_id: String in allies:
		var ally: Variant = allies[actor_id]
		if is_instance_valid(ally):
			_actors()[actor_id] = {"x": ally.global_position.x, "y": ally.global_position.y, "health": ally.health, "down": ally.down, "alive": not ally.down, "mode": "down" if ally.down else "hold" if ally.staged else "follow"}

func _retire(actor: Variant) -> void:
	if not is_instance_valid(actor):
		return
	actor.set_physics_process(false)
	for group in ["damageable", "party_target", "interactable"]:
		actor.remove_from_group(group)
	actor.queue_free()

func _restore_davor_processing() -> void:
	if _davor_paused and is_instance_valid(world.davor):
		world.davor.set_physics_process(_davor_was_processing)
	_davor_paused = false

func _pause_davor_for_dialogue() -> void:
	var in_encounter := _visible_site in ["hall", "squirrel", "pelican"] and not enemies.is_empty()
	if in_encounter and world.player.ui_is_open():
		if not _davor_paused:
			_davor_was_processing = world.davor.is_physics_processing()
			_davor_paused = true
		world.davor.set_physics_process(false)
		world.davor.velocity = Vector2.ZERO
	else:
		_restore_davor_processing()

func clear_runtime() -> void:
	_restore_davor_processing()
	_retire(arrow)
	arrow = null
	_retire(player_arrow)
	player_arrow = null
	for actor in enemies.values():
		_retire(actor)
	for actor in allies.values():
		_retire(actor)
	enemies.clear()
	allies.clear()

func refresh_room() -> void:
	capture_state()
	apply_loaded_state()

func apply_loaded_state() -> void:
	_restoring = true
	clear_runtime()
	_visible_site = _site()
	if _visible_site == "hall":
		_restore_assassin()
		var flight: Dictionary = _state().get("banishing_arrow", {})
		if not flight.is_empty():
			investigation.set_flag("banishing_arrow_fired")
			_spawn_arrow(Vector2(flight.x, flight.y), Vector2(flight.dx, flight.dy), float(flight.remaining))
	elif _visible_site in ["squirrel", "pelican"]:
		_restore_gang(_visible_site)
	elif _state().get("allies_faction", "") in ["squirrel", "pelican"] and _state().get("encounter", "").is_empty() and not _has("squirrel_cleared") and not _has("pelican_cleared"):
		var faction := str(_state().allies_faction)
		if world.player.global_position.distance_to(world.marker("inv_rendezvous")) < 240.0:
			_spawn_allies(faction, "", true)
	_restoring = false

func _profile(actor_id: String) -> Dictionary:
	if actor_id == "assassin":
		return {"name": "False Police Officer", "max_health": 70, "damage": 7, "speed": 82.0, "armor": 0, "reach": 25.0, "attack_cooldown": 0.9, "reward": 0, "event": "iskra_investigation_enemy_defeated"}
	if actor_id == "pelican_hacker":
		return Data.HACKER_STATS.duplicate()
	if actor_id == "squirrel_boss":
		return {"name": "Squirrel Boss", "max_health": 55, "damage": 6, "speed": 48.0, "armor": 1, "reach": 25.0, "reward": 0, "event": "iskra_investigation_enemy_defeated"}
	var index := int(actor_id.get_slice("_", 2))
	var tvrdium := actor_id.begins_with("squirrel_guard_") and index < 3
	# Armor matches the item protection values: tvrdium 5, iron 3, bronze 2.
	var armor := 1
	if actor_id.begins_with("squirrel_guard_"):
		armor = [5, 5, 3, 3, 2, 2][index]
	elif actor_id.begins_with("pelican_guard_") and index < 3:
		armor = 3
	return {"name": "Tvrdium Guard" if tvrdium else "Squirrel Guard" if actor_id.begins_with("squirrel") else "Pelican Guard", "max_health": 38, "damage": 14 if tvrdium else 8, "speed": 53.0, "armor": armor, "reach": 34.0 if tvrdium else 26.0, "attack_cooldown": 0.95, "reward": 0, "event": "iskra_investigation_enemy_defeated"}

func _role(actor_id: String) -> String:
	if actor_id == "assassin":
		return "police_attacker"
	if actor_id.begins_with("squirrel_guard_"):
		return "squirrel_tv_guard" if int(actor_id.get_slice("_", 2)) < 3 else "squirrel_guard"
	if actor_id.begins_with("pelican_guard_"):
		return "pelican_guard"
	return actor_id

func _spawn_enemy(actor_id: String, marker_id: String, site: String, initial_mode: String) -> Enemy:
	if _dead(actor_id):
		return null
	var actor := Fighter.new()
	actor.actor_id = actor_id
	actor.encounter_id = site
	actor.encounter_bounds = Data.ROOMS[site]
	actor.mode = initial_mode
	actor.relentless = true
	actor.guard_radius = Data.ROOMS[site].size.length()
	actor.configure("phase_hacker" if actor_id == "pelican_hacker" else "bandit_bow" if actor_id == "assassin" else "bandit_sword", Data.npc_texture(_role(actor_id)), world.marker(marker_id), "story_iskra_inv_" + actor_id)
	actor.definition.merge(_profile(actor_id), true)
	actor.max_health = int(actor.definition.max_health)
	actor.health = actor.max_health
	if actor_id == "squirrel_boss":
		actor.hold_ground = true
	if actor_id.begins_with("squirrel_guard_") and int(actor_id.get_slice("_", 2)) < 3 and actor._weapon_visual != null:
		actor._weapon_visual.default_color = Color("91ded3")
		actor._weapon_visual.width = 3.0
	var saved := _saved(actor_id)
	if not saved.is_empty():
		actor.global_position = _safe_point(Vector2(saved.get("x", actor.global_position.x), saved.get("y", actor.global_position.y)), world.marker(marker_id), site)
		actor.health = clampi(int(saved.get("health", actor.max_health)), 0, actor.max_health)
	actor.mode = initial_mode
	actor.escape_goal = world.marker("inv_hall_escape")
	world.actors_root.add_child(actor)
	enemies[actor_id] = actor
	actor.defeated.connect(_on_defeated.bind(actor_id))
	actor.yielded.connect(_on_yielded)
	actor.fled.connect(_on_fled)
	actor.interacted.connect(_on_interacted)
	return actor

func _restore_assassin() -> void:
	var phase := str(_state().get("assassin_phase", ""))
	if phase.is_empty() or phase in ["waiting", "killed", "escaped"]:
		return
	if phase == "attack":
		phase = "flee" if _has("banishing_arrow_fired") else "shoot"
		_state()["assassin_phase"] = phase
	_spawn_enemy("assassin", "inv_hall_attacker", "hall", phase)

func arrow_in_flight() -> bool:
	return is_instance_valid(arrow) or not _state().get("banishing_arrow", {}).is_empty()

## Looses the MC's single Banishing Arrow at the nearest enemy in front of them, or straight ahead.
func fire_player_arrow() -> bool:
	if int(GameState.inventory.get(Data.ARROW, 0)) <= 0:
		return false
	if str(_state().get("encounter", "")) == "" or enemies.is_empty():
		GameState.notify("Keep the Banishing Arrow for the fight with Roko. You only have one.")
		return false
	var player: Player = world.player
	var heading: Vector2 = player.facing
	var best := INF
	for actor in enemies.values():
		if not is_instance_valid(actor) or actor.health <= 0:
			continue
		var offset: Vector2 = actor.global_position - player.global_position
		if offset.length() < best and offset.length() <= BanishingArrow.RANGE and player.facing.dot(offset.normalized()) >= 0.15:
			best = offset.length()
			heading = offset.normalized()
	GameState.remove_item(Data.ARROW)
	player_arrow = BanishingArrow.new()
	world.actors_root.add_child(player_arrow)
	player_arrow.configure(player.global_position + Vector2(0, -7) + heading * 10.0, heading)
	player_arrow.fire_as_player(player)
	var hacker: Variant = enemies.get("pelican_hacker")
	if is_instance_valid(hacker) and hacker.dodge_banishing(player):
		GameState.notify("Roko sees the arrow coming and vanishes.")
	return true

func _spawn_arrow(point: Vector2, heading: Vector2, distance: float = BanishingArrow.RANGE) -> void:
	arrow = BanishingArrow.new()
	arrow.configure(point, heading, distance)
	world.actors_root.add_child(arrow)
	arrow.finished.connect(_on_arrow_finished)
	_state()["banishing_arrow"] = arrow.snapshot()

func _on_arrow_finished(_body: Node) -> void:
	arrow = null
	_state()["banishing_arrow"] = {}

func _fire_assassin_arrow(actor: Enemy) -> void:
	if not _has("banishing_arrow_fired"):
		var origin := actor.global_position + Vector2(0, -3)
		var heading: Vector2 = world.player.global_position + Vector2(0, -3) - origin
		if heading.is_zero_approx():
			heading = Vector2.DOWN
		investigation.set_flag("banishing_arrow_fired")
		_spawn_arrow(origin, heading)
		GameState.notify("Davor: Don’t let that arrow hit you!!!")
	actor.set_mode("flee")
	_save_enemy("assassin", actor)

func _restore_gang(site: String) -> void:
	var cleared := _has(site + "_cleared")
	var fighting := str(_state().get("encounter", "")) == site and not cleared
	if not cleared:
		for index in Data.GUARD_COUNTS[site]:
			var actor_id := site + "_guard_" + str(index)
			_spawn_enemy(actor_id, "inv_" + actor_id, site, "attack" if fighting else "idle")
	if site == "pelican" and not cleared:
		_spawn_enemy("pelican_hacker", "inv_pelican_hacker", site, "attack" if fighting and _guards_down("pelican") else "idle")
	elif site == "squirrel" and (fighting or cleared or _saved("squirrel_boss").get("mode", "") == "surrendered"):
		var boss := _spawn_enemy("squirrel_boss", "inv_squirrel_boss", site, "surrendered" if cleared else "attack")
		if boss != null and cleared:
			boss.set_mode("surrendered")
	if fighting:
		var faction := str(_state().get("allies_faction", ""))
		if faction in ["squirrel", "pelican"]:
			_spawn_allies(faction, site, false)

func _spawn_allies(faction: String, site: String, staged: bool) -> void:
	for index in 3:
		var actor_id := faction + "_ally_" + str(index)
		var marker_id := "inv_rendezvous_ally_" + str(index) if staged else "inv_" + site + "_ally_" + str(index)
		var ally := Ally.new()
		ally.encounter_id = site
		ally.encounter_bounds = Data.ROOMS.get(site, Rect2())
		ally.staged = staged
		ally.configure(actor_id, ("Squirrel" if faction == "squirrel" else "Pelican") + " ally " + str(index + 1), Data.npc_texture(faction + "_guard"), world.marker(marker_id), ["sword", "spear", "bow"][index], index + 1, world)
		ally.max_health = 38
		ally.health = 38
		ally.armor = 1
		ally.speed = 76.0
		ally.strike_damage = 8
		ally.follow_sight = 180.0
		ally.fights = not staged
		world.actors_root.add_child(ally)
		var saved := _saved(actor_id)
		if not saved.is_empty():
			var point := Vector2(saved.get("x", ally.global_position.x), saved.get("y", ally.global_position.y))
			ally.global_position = _safe_point(point, world.marker(marker_id), site) if not staged else world.marker(marker_id)
			ally.restore_condition(int(saved.get("health", ally.max_health)), bool(saved.get("down", false)))
		if staged:
			ally.hold_at(world.marker(marker_id), "Wait for the assault decision")
		else:
			ally.set_order("attack")
		allies[actor_id] = ally

func stage_allies(faction: String) -> void:
	if faction not in ["", "squirrel", "pelican"]:
		return
	capture_state()
	for actor in allies.values():
		_retire(actor)
	allies.clear()
	_state()["version"] = Data.VERSION
	_state()["allies_faction"] = faction
	if not faction.is_empty():
		_spawn_allies(faction, "", true)

func begin_assassin(_opening: String) -> bool:
	if _site() != "hall" or str(_state().get("assassin_phase", "")) not in ["", "waiting"]:
		return false
	_state()["version"] = Data.VERSION
	_state()["encounter"] = "assassin"
	_state()["assassin_phase"] = "shoot"
	_state()["assassin_seconds"] = 0.0
	investigation.set_flag("attack_started")
	apply_loaded_state()
	var actor: Enemy = enemies.get("assassin")
	if actor == null:
		return false
	_position_assassin_for_shot(actor)
	actor.set_mode(str(_state().assassin_phase))
	capture_state()
	return true

func _position_assassin_for_shot(actor: Enemy) -> void:
	if actor.global_position.distance_to(world.player.global_position) >= 96.0:
		return
	var away: Vector2 = (actor.global_position - world.player.global_position).normalized()
	var directions := [away, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]
	for distance in [112.0, 144.0]:
		for direction: Vector2 in directions:
			if direction.is_zero_approx():
				continue
			var point: Vector2 = world.tiled_loader.nearest_walkable_position(world.player.global_position + direction * distance)
			if not Data.ROOMS.hall.has_point(point) or point.distance_to(world.player.global_position) < 96.0:
				continue
			var ray := PhysicsRayQueryParameters2D.create(point + Vector2(0, -3), world.player.global_position + Vector2(0, -3), 1)
			if not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			actor.global_position = point
			actor.spawn_position = point
			return

func begin_fight(route: String) -> bool:
	if route not in ["squirrel", "direct", "pelican"]:
		return false
	var site := "pelican" if route == "squirrel" else "squirrel"
	var active := str(_state().get("encounter", ""))
	if _site() != site or _has(site + "_cleared") or active not in ["", site]:
		return false
	if active == site and _state().get("route", "") == route:
		return false
	if route == "squirrel" and not _has("deal_accepted"):
		return false
	if route == "pelican" and not _has("pelicans_warned"):
		return false
	capture_state()
	_state()["version"] = Data.VERSION
	_state()["route"] = route
	_state()["encounter"] = site
	_state()["allies_faction"] = "" if route == "direct" else route
	apply_loaded_state()
	for actor in enemies.values():
		if actor.health > 0:
			actor.set_mode("attack")
	capture_state()
	return true

func _record_evidence(point: Vector2) -> void:
	_state()["evidence_x"] = point.x
	_state()["evidence_y"] = point.y

func evidence_position() -> Vector2:
	return Vector2(_state().get("evidence_x", world.marker("inv_hall_evidence").x), _state().get("evidence_y", world.marker("inv_hall_evidence").y))

func _emit_once(event: String) -> void:
	if _has(event):
		return
	investigation.set_flag(event)
	investigation.on_encounter_event(event)

func _on_defeated(_persistent_id: String, actor_id: String) -> void:
	var actor: Enemy = enemies.get(actor_id)
	if actor == null:
		return
	_save_enemy(actor_id, actor)
	world._set_flag("story_iskra_inv_" + actor_id)
	enemies.erase(actor_id)
	if actor_id == "assassin":
		_state()["assassin_phase"] = "killed"
		_state()["encounter"] = ""
		_record_evidence(actor.global_position)
		_emit_once("assassin_killed")
	elif actor_id == "squirrel_boss":
		_emit_once("squirrel_boss_killed")
	_check_fight_finished()

func _on_yielded(actor_id: String) -> void:
	if actor_id == "assassin":
		_state()["assassin_phase"] = "surrendered"
	_save_enemy(actor_id, enemies.get(actor_id))

func _on_fled(actor_id: String) -> void:
	if actor_id != "assassin":
		return
	var actor: Enemy = enemies.get(actor_id)
	_save_enemy(actor_id, actor)
	_state()["assassin_phase"] = "escaped"
	_state()["encounter"] = ""
	_record_evidence(world.marker("inv_hall_escape"))
	_emit_once("assassin_escaped")

func _on_interacted(actor_id: String) -> void:
	if actor_id == "assassin":
		capture_assassin()
	elif actor_id == "squirrel_boss":
		world._on_service_requested("iskra:inv_squirrel_boss", "Squirrel Boss")

func capture_assassin() -> bool:
	var actor: Enemy = enemies.get("assassin")
	if actor == null or not is_instance_valid(actor) or actor.mode not in ["flee", "surrendered"]:
		return false
	var reach := 44.0 if actor.mode == "surrendered" else 30.0
	if world.player.global_position.distance_to(actor.global_position) > reach or not actor.can_be_reached_by(world.player.global_position):
		GameState.notify("Get closer to the attacker without a wall between you.")
		return false
	actor.set_mode("captured")
	_save_enemy("assassin", actor)
	_state()["assassin_phase"] = "captured"
	_state()["encounter"] = ""
	_record_evidence(actor.global_position)
	_emit_once("assassin_captured")
	return true

func finish_surrendered_boss() -> bool:
	var boss: Enemy = enemies.get("squirrel_boss")
	if not _has("squirrel_cleared") or boss == null or not is_instance_valid(boss) or boss.mode != "surrendered":
		return false
	if world.player.global_position.distance_to(boss.global_position) > 48.0 or not boss.can_be_reached_by(world.player.global_position):
		return false
	return boss.execute_surrendered()

func _guards_down(site: String) -> bool:
	for index in Data.GUARD_COUNTS[site]:
		if not _dead(site + "_guard_" + str(index)):
			return false
	return true

## Roko waits at the far side of his office until his guards fall or the player walks up to him.
func _wake_hacker() -> void:
	var hacker: Enemy = enemies.get("pelican_hacker")
	if str(_state().get("encounter", "")) != "pelican" or not is_instance_valid(hacker) or hacker.mode != "idle":
		return
	if _guards_down("pelican") or world.player.global_position.distance_to(hacker.global_position) < Data.HACKER_WAKE_DISTANCE:
		hacker.set_mode("attack")
		GameState.notify("Roko steps away from the far wall to fight.")

func _check_fight_finished() -> void:
	var site := str(_state().get("encounter", ""))
	if site not in ["squirrel", "pelican"] or _has(site + "_cleared"):
		return
	for index in Data.GUARD_COUNTS[site]:
		if not _dead(site + "_guard_" + str(index)):
			return
	if site == "pelican" and not _dead("pelican_hacker"):
		return
	if site == "squirrel":
		var boss: Enemy = enemies.get("squirrel_boss")
		if is_instance_valid(boss) and boss.health > 0:
			boss.surrender()
	capture_state()
	_state()["encounter"] = ""
	for ally in allies.values():
		if is_instance_valid(ally):
			ally.fights = false
			ally.set_order("follow")
	_emit_once(site + "_cleared")

func step(_delta: float) -> void:
	if _restoring or investigation == null:
		return
	if _site() != _visible_site:
		refresh_room()
	_pause_davor_for_dialogue()
	if world.get_tree().paused or world.player.ui_is_open() or world.taxi_active:
		return
	var actor: Enemy = enemies.get("assassin")
	if is_instance_valid(actor) and actor.mode == "shoot":
		_fire_assassin_arrow(actor)
	_wake_hacker()
	_check_fight_finished()

func on_respawn() -> void:
	capture_state()
	var site := str(_state().get("encounter", ""))
	if site == "assassin" or (site.is_empty() and _state().get("site", "") == "hall"):
		site = "hall"
	if site not in Data.ROOMS:
		apply_loaded_state()
		return
	world.player.global_position = world.marker("inv_" + site + "_arrival")
	world.player.velocity = Vector2.ZERO
	_state()["site"] = site
	for actor_id: String in _actors():
		var saved: Dictionary = _actors()[actor_id]
		if float(saved.get("health", 0)) <= 0.0:
			continue
		var marker_id := ""
		if actor_id == "assassin" and site == "hall":
			marker_id = "inv_hall_attacker"
		elif actor_id.begins_with(site + "_guard_") or actor_id == site + "_boss" or actor_id == site + "_hacker":
			marker_id = "inv_" + actor_id
		elif actor_id.contains("_ally_"):
			marker_id = "inv_" + site + "_ally_" + actor_id.get_slice("_", 2)
		if not marker_id.is_empty() and world.markers.has(marker_id):
			saved["x"] = world.marker(marker_id).x
			saved["y"] = world.marker(marker_id).y
	GameState.remember_player_position(world.player.global_position)
	world._move_davor()
	apply_loaded_state()
