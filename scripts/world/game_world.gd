class_name GameWorld
extends Node2D

const MAP_PATH := "res://maps/paprika.tmj"
const VILLAGE_OFFSET := Vector2(512, 352)
const VILLAGER_COUNT := 25
const CAMP_SPAWNS := [Vector2(285, 231), Vector2(318, 251), Vector2(351, 238)]
const CAMP_TEXTURE := "res://assets/art/bandit.png"
const REPATH_SECONDS := 0.45

signal squad_control_changed

var tiled_loader: TiledLoader
var actors_root: Node2D
var player: Player
var _camera: Camera2D
var _villager_count := 0
var _rabbit_count := 0
var _squad_ai: Dictionary = {}
var _camp_marker: Node2D
var _hacker_spawn: Dictionary = {}

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	tiled_loader.service_requested.connect(_on_service_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(MAP_PATH):
		push_error("Paprika map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	_spawn_population_to_target()
	if player == null:
		_spawn_player(VILLAGE_OFFSET + Vector2(326, 268), "res://art/concepts/source/player.png")
	GameState.squad_changed.connect(_sync_squad)
	_sync_squad()

func capture_player_position() -> void:
	if player != null:
		GameState.player_position = player.global_position
	for villager_id in GameState.squad_recruits:
		var villager := find_villager(villager_id)
		if villager != null:
			var member: Dictionary = GameState.squad_members[villager_id]
			member["position"] = [villager.global_position.x, villager.global_position.y]
			GameState.squad_members[villager_id] = member

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = GameState.player_position
	_squad_ai.clear()
	for actor in actors_root.get_children():
		if actor is Enemy and actor.enemy_id == "camp_bandit":
			actor.queue_free()
	_sync_hacker()
	for villager_id in GameState.squad_recruits:
		var villager := find_villager(villager_id)
		if villager != null:
			var position_data: Array = GameState.squad_members[villager_id]["position"]
			villager.global_position = Vector2(float(position_data[0]), float(position_data[1]))
	_sync_squad()

func _sync_hacker() -> void:
	if _hacker_spawn.is_empty():
		return
	var defeated := GameState.defeated_persistent_enemies.has(String(_hacker_spawn["id"]))
	var found := false
	for actor in actors_root.get_children():
		if actor is Enemy and actor.enemy_id == "hacker" and not actor.is_queued_for_deletion():
			if defeated:
				actor.queue_free()
			else:
				found = true
	if not defeated and not found:
		_spawn_enemy("hacker", _hacker_spawn["position"], String(_hacker_spawn["texture"]), String(_hacker_spawn["id"]))

func find_villager(villager_id: String) -> Villager:
	for actor in actors_root.get_children():
		if actor is Villager and actor.villager_id == villager_id:
			return actor
	return null

func recruit(villager_id: String) -> bool:
	var villager := find_villager(villager_id)
	return villager != null and GameState.recruit_villager(villager_id, villager.global_position)

func controlled_actor() -> CharacterBody2D:
	if GameState.controlled_member_id != "player":
		var villager := find_villager(GameState.controlled_member_id)
		if villager != null and GameState.squad_deployed and not GameState.recruit_recovering(villager.villager_id):
			return villager
	return player

func select_member(slot: int) -> bool:
	if slot < 0 or slot > 2:
		return false
	var member_id := "player"
	if slot > 0:
		if not GameState.squad_deployed or slot > GameState.squad_recruits.size():
			return false
		member_id = GameState.squad_recruits[slot - 1]
	return GameState.set_controlled_member(member_id)

func issue_order(order: String) -> void:
	if not GameState.squad_deployed or not GameState.SQUAD_ORDERS.has(order):
		return
	var active := controlled_actor()
	if active == null:
		return
	if GameState.controlled_member_id != "player":
		GameState.set_squad_order("player", order, player.global_position)
	for villager_id in GameState.squad_recruits:
		if villager_id == GameState.controlled_member_id:
			continue
		var villager := find_villager(villager_id)
		if villager != null:
			GameState.set_squad_order(villager_id, order, villager.global_position)
	_squad_ai.clear()
	GameState.notify("Squad order: %s." % order.capitalize())

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.squad_deployed or get_tree().paused or player == null or player.ui_is_open():
		return
	var actions := ["party_player", "party_first", "party_second"]
	for slot in actions.size():
		if event.is_action_pressed(actions[slot]):
			select_member(slot)
			get_viewport().set_input_as_handled()
			return
	for order in ["follow", "hold", "attack"]:
		if event.is_action_pressed("order_" + order):
			issue_order(order)
			get_viewport().set_input_as_handled()
			return

func _sync_squad() -> void:
	if player == null:
		return
	for actor in actors_root.get_children():
		if not actor is Villager:
			continue
		var villager := actor as Villager
		villager.squad_member = GameState.squad_deployed and GameState.squad_recruits.has(villager.villager_id)
		villager.collision_layer = 4 | 64 if villager.squad_member and not GameState.recruit_recovering(villager.villager_id) else 4
		if villager.squad_member and not GameState.recruit_recovering(villager.villager_id):
			villager.add_to_group("party_target")
		else:
			villager.remove_from_group("party_target")
		if not villager.squad_member:
			villager.resume_routine()
	if _camera != null:
		var active := controlled_actor()
		if active != null and _camera.get_parent() != active:
			_camera.reparent(active)
			_camera.position = Vector2(0, -24)
			_camera.make_current()
	if get_tree().get_first_node_in_group("game_ui") != null:
		player._update_nearest_interactable()
	_sync_camp()
	squad_control_changed.emit()

func _sync_camp() -> void:
	var active := GameState.squad_deployed and GameState.active_jobs.has(GameState.CAMP_JOB)
	if not active:
		if is_instance_valid(_camp_marker):
			_camp_marker.queue_free()
			_camp_marker = null
		for actor in actors_root.get_children():
			if actor is Enemy and actor.enemy_id == "camp_bandit":
				actor.queue_free()
		return
	if not is_instance_valid(_camp_marker):
		_build_camp_marker()
	for index in GameState.CAMP_IDS.size():
		var stable_id: String = GameState.CAMP_IDS[index]
		if GameState.camp_defeated_ids.has(stable_id):
			continue
		var exists := false
		for actor in actors_root.get_children():
			if actor is Enemy and actor.persistent_id == stable_id and not actor.is_queued_for_deletion():
				exists = true
				break
		if not exists:
			var position := _camp_walk_position(CAMP_SPAWNS[index])
			_spawn_enemy("camp_bandit", position, CAMP_TEXTURE, stable_id)

func _camp_walk_position(desired: Vector2) -> Vector2:
	var path := tiled_loader.get_walk_path(Player.RESPAWN_POSITION, desired)
	if not path.is_empty():
		return path[-1]
	return desired

func _build_camp_marker() -> void:
	_camp_marker = Node2D.new()
	_camp_marker.name = "BanditCamp"
	_camp_marker.position = Vector2(320, 210)
	_camp_marker.z_index = 40
	actors_root.add_child(_camp_marker)
	var tent := Polygon2D.new()
	tent.polygon = PackedVector2Array([Vector2(-28, 5), Vector2(-14, -18), Vector2(2, 5)])
	tent.color = Color("855043")
	_camp_marker.add_child(tent)
	var fire := Polygon2D.new()
	fire.polygon = PackedVector2Array([Vector2(14, 3), Vector2(20, -9), Vector2(25, 3)])
	fire.color = Color("f6a94a")
	_camp_marker.add_child(fire)
	var label := Label.new()
	label.text = "BANDIT CAMP"
	label.position = Vector2(-31, -37)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("f6d391"))
	_camp_marker.add_child(label)

func step_squad_actor(actor: CharacterBody2D, delta: float) -> void:
	if player.ui_is_open() or get_tree().paused:
		actor.velocity = Vector2.ZERO
		return
	var member_id := "player" if actor == player else (actor as Villager).villager_id
	if actor is Villager and GameState.recruit_recovering(member_id):
		actor.velocity = Vector2.ZERO
		return
	if GameState.controlled_member_id == member_id:
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		actor.velocity = movement * Player.SPEED
		if actor is Villager and movement.length_squared() > 0.01:
			(actor as Villager).facing = _cardinal(movement)
		actor.move_and_slide()
	else:
		_step_squad_ai(actor, member_id, delta)
	actor.global_position.x = clampf(actor.global_position.x, 6.0, tiled_loader.map_size.x - 6.0)
	actor.global_position.y = clampf(actor.global_position.y, 8.0, tiled_loader.map_size.y - 6.0)
	actor.z_index = 100 + int(actor.global_position.y)
	if actor is Villager:
		var member: Dictionary = GameState.squad_members[member_id]
		member["position"] = [actor.global_position.x, actor.global_position.y]
		GameState.squad_members[member_id] = member

func _step_squad_ai(actor: CharacterBody2D, member_id: String, delta: float) -> void:
	var order := GameState.player_order if member_id == "player" else String(GameState.squad_members[member_id]["order"])
	if order == "hold":
		actor.velocity = Vector2.ZERO
		return
	var target := nearest_hostile(actor.global_position, 90.0) if order == "attack" else null
	var leader := controlled_actor()
	var destination := leader.global_position if leader != null else actor.global_position
	if target != null:
		destination = target.global_position
		var direction := destination - actor.global_position
		if direction.length_squared() > 0.01:
			face_actor(actor, direction)
		var reach := _actor_reach(member_id)
		if direction.length() <= reach:
			actor.velocity = Vector2.ZERO
			attack_as(actor)
			return
	else:
		var offset := Vector2(-16, 13) if member_id == "player" else Vector2(14 if GameState.squad_recruits.find(member_id) == 0 else -14, 13)
		destination += offset
		if actor.global_position.distance_to(destination) < 18.0:
			actor.velocity = Vector2.ZERO
			return
	var state: Dictionary = _squad_ai.get(member_id, {"path": PackedVector2Array(), "index": 0, "repath": 0.0})
	state["repath"] = float(state["repath"]) - delta
	if float(state["repath"]) <= 0.0:
		state["path"] = tiled_loader.get_walk_path(actor.global_position, destination)
		state["index"] = 0
		state["repath"] = REPATH_SECONDS
	var path: PackedVector2Array = state["path"]
	while int(state["index"]) < path.size() and actor.global_position.distance_to(path[int(state["index"])]) < 4.0:
		state["index"] = int(state["index"]) + 1
	if int(state["index"]) < path.size():
		var direction := path[int(state["index"])] - actor.global_position
		face_actor(actor, direction)
		actor.velocity = direction.normalized() * (Player.SPEED * 0.78)
		actor.move_and_slide()
	else:
		actor.velocity = Vector2.ZERO
	_squad_ai[member_id] = state

func nearest_hostile(origin: Vector2, radius: float) -> Enemy:
	var nearest: Enemy
	var best := radius
	for node in get_tree().get_nodes_in_group("damageable"):
		if node is Enemy and node.visible and not node.is_queued_for_deletion():
			var distance := origin.distance_to(node.global_position)
			if distance < best:
				nearest = node
				best = distance
	return nearest

func face_actor(actor: CharacterBody2D, direction: Vector2) -> void:
	if actor == player:
		player.facing = _cardinal(direction)
	elif actor is Villager:
		(actor as Villager).facing = _cardinal(direction)

func _cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0 else Vector2.UP

func _actor_reach(member_id: String) -> float:
	var weapon := GameState.weapon_definition() if member_id == "player" else GameData.item(String(GameState.squad_members[member_id]["weapon"]))
	return float(weapon.get("reach", 24.0))

func attack_as(actor: CharacterBody2D) -> void:
	if actor == player:
		var enemy := nearest_hostile(player.global_position, _actor_reach("player"))
		if enemy != null:
			player._attack(enemy)
		return
	var villager := actor as Villager
	if villager == null or GameState.recruit_recovering(villager.villager_id) or not GameState.squad_deployed:
		return
	var member: Dictionary = GameState.squad_members[villager.villager_id]
	var weapon := GameData.item(String(member["weapon"]))
	if villager.attack_cooldown > 0.0:
		return
	villager.attack_cooldown = float(weapon.get("cooldown", 0.55))
	var damage: int = {1: 4, 2: 10, 3: 24}.get(int(weapon.get("power", 1)), 4)
	var reach := float(weapon.get("reach", 24.0))
	if bool(weapon.get("ranged", false)):
		var projectile := Projectile.new()
		actors_root.add_child(projectile)
		projectile.configure(villager.global_position + villager.facing * 10.0 + Vector2(0, -7), villager.facing, damage, 190.0, reach, true)
	else:
		var enemy := nearest_hostile(villager.global_position, reach)
		if enemy != null and villager.facing.dot((enemy.global_position - villager.global_position).normalized()) >= 0.15:
			enemy.take_damage(damage, villager.global_position)
		villager.show_swing(reach)

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, persistent_id: String) -> void:
	match kind:
		"player":
			if player == null:
				GameState.player_position = position
				_spawn_player(position, variant)
		"villager":
			_spawn_villager(position, variant, persistent_id)
		"rabbit":
			_spawn_rabbit(position, variant, persistent_id)
		"enemy":
			var enemy_kind := variant.get_file().get_basename()
			_spawn_enemy(enemy_kind, position, variant, persistent_id)

func _spawn_player(position: Vector2, texture_path: String) -> void:
	player = Player.new()
	player.name = "Player"
	player.configure(texture_path, position, Rect2(Vector2.ZERO, tiled_loader.map_size))
	actors_root.add_child(player)
	_camera = player.get_node_or_null("Camera") as Camera2D
	player.prompt_changed.connect(_on_prompt_changed)
	player.respawned.connect(_on_player_respawned)

func _spawn_villager(position: Vector2, texture_path: String, stable_id: String) -> void:
	var villager := Villager.new()
	villager.name = "Villager_%s" % stable_id
	villager.configure(texture_path, stable_id, position, _routine_points())
	actors_root.add_child(villager)
	_villager_count += 1

func _spawn_rabbit(position: Vector2, texture_path: String, stable_id: String) -> void:
	var rabbit := Rabbit.new()
	rabbit.name = "Rabbit_%s" % stable_id
	rabbit.configure(texture_path, stable_id, position)
	actors_root.add_child(rabbit)
	_rabbit_count += 1

func _spawn_enemy(kind: String, position: Vector2, texture_path: String, stable_id: String) -> void:
	if kind == "hacker":
		_hacker_spawn = {"position": position, "texture": texture_path, "id": stable_id}
	var enemy := Enemy.new()
	enemy.name = "%s_%s" % [kind.capitalize(), stable_id]
	enemy.configure(kind, texture_path, position, stable_id)
	actors_root.add_child(enemy)

func _spawn_population_to_target() -> void:
	var textures := [
		"res://art/concepts/source/villager1.png",
		"res://art/concepts/source/villager2.png",
		"res://art/concepts/source/villager3.png",
		"res://art/concepts/source/villager4.png",
		"res://art/concepts/source/villager5.png",
		"res://art/concepts/source/villager6.png",
	]
	var safe_points := [
		Vector2(145, 145), Vector2(175, 170), Vector2(240, 145), Vector2(270, 175),
		Vector2(340, 150), Vector2(375, 175), Vector2(430, 150), Vector2(485, 175),
		Vector2(140, 235), Vector2(185, 260), Vector2(235, 245), Vector2(280, 275),
		Vector2(340, 245), Vector2(390, 275), Vector2(440, 250), Vector2(500, 270),
		Vector2(125, 315), Vector2(190, 325), Vector2(250, 320), Vector2(315, 318),
		Vector2(380, 320), Vector2(445, 315), Vector2(525, 305),
	]
	var needed := VILLAGER_COUNT - _villager_count
	for index in needed:
		var base: Vector2 = safe_points[index % safe_points.size()]
		var ring: int = index / safe_points.size()
		var offset := Vector2((ring * 7 + index * 3) % 17 - 8, (ring * 11 + index * 5) % 13 - 6)
		_spawn_villager(base + offset + VILLAGE_OFFSET, textures[index % textures.size()], "resident_%02d" % index)

func _routine_points() -> Array[Vector2]:
	var points: Array[Vector2] = [
		Vector2(320, 270), Vector2(250, 185), Vector2(385, 185),
		Vector2(210, 290), Vector2(430, 250), Vector2(470, 160), Vector2(315, 310),
		Vector2(130, 275), Vector2(605, 825), Vector2(730, 850),
	]
	for index in points.size():
		points[index] += VILLAGE_OFFSET if index < 8 else Vector2.ZERO
	return points

func _on_player_respawned() -> void:
	for actor in actors_root.get_children():
		if actor is Enemy:
			actor.reset_after_player_defeat()
		elif actor is Projectile and not actor.from_player:
			actor.queue_free()

func _on_prompt_changed(text: String) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_interaction_prompt"):
		ui.set_interaction_prompt(text)

func _on_service_requested(service_id: String, display_name: String) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("open_service"):
		ui.open_service(service_id, display_name)
	else:
		GameState.notify("%s is not ready yet." % display_name)
