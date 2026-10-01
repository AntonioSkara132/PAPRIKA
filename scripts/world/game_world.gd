class_name GameWorld
extends Node2D

const MAP_PATH := "res://maps/paprika.tmj"
const VILLAGE_OFFSET := Vector2(512, 352)
const VILLAGER_COUNT := 25

var tiled_loader: TiledLoader
var actors_root: Node2D
var player: Player
var _villager_count := 0
var _rabbit_count := 0

func _ready() -> void:
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

func capture_player_position() -> void:
	if player != null:
		GameState.player_position = player.global_position

func apply_loaded_state() -> void:
	if player != null:
		player.global_position = GameState.player_position

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
