extends Node

var checks := 0
var failures := 0
var game: Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(data_home + "/"):
		_check(false, "tests require an isolated save directory")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await _test_weapon_switch()
	_test_map_depths()
	await _test_rendered_occlusion()
	_finish()

func _test_weapon_switch() -> void:
	var player: Player = game.world.player
	var binding := InputMap.action_get_events("switch_weapon")[0] as InputEventKey
	_check(binding != null and binding.physical_keycode == KEY_V, "V is the weapon-switch shortcut")
	GameState.inventory = {"iron_sword": 1, "wood_bow": 1, "bread": 1}
	GameState.equipment = {"weapon": "iron_sword", "armor": "", "clothing": ""}
	var original_inventory := GameState.inventory.duplicate()
	var event := InputEventKey.new()
	event.keycode = KEY_V
	event.physical_keycode = KEY_V
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
	_check(GameState.equipment.weapon == "wood_bow", "pressing V equips the next available weapon")
	_check(GameState.inventory == original_inventory, "switching consumes no items")
	player._attack_cooldown = 0.8
	_switch(player)
	_check(GameState.equipment.weapon == "iron_sword" and is_equal_approx(player._attack_cooldown, 0.8), "switch wraps around without resetting attack cooldown")
	game.game_ui.open_inventory()
	_switch(player)
	_check(GameState.equipment.weapon == "iron_sword", "inventory blocks quick switching")
	game.game_ui.close_modal()
	get_tree().paused = true
	_switch(player)
	_check(GameState.equipment.weapon == "iron_sword", "pause blocks quick switching")
	get_tree().paused = false
	game.game_ui.play_scene([{"speaker": "Test", "text": "Keep the current weapon during dialogue."}])
	_switch(player)
	_check(GameState.equipment.weapon == "iron_sword", "dialogue blocks quick switching")
	game.game_ui.cancel_scene()
	GameState.squad_recruits.assign(["test_recruit"])
	GameState.squad_members = {"test_recruit": {"weapon": "wood_bow", "armor": ""}}
	_check(not GameState.cycle_weapon() and GameState.equipment.weapon == "iron_sword", "a recruit's only copy is excluded")
	GameState.inventory.wood_bow = 2
	_check(GameState.cycle_weapon() and GameState.equipment.weapon == "wood_bow", "an extra copy of an assigned weapon is available")
	GameState.squad_recruits.clear()
	GameState.squad_members.clear()
	GameState.inventory = {"iron_sword": 1}
	GameState.equipment.weapon = ""
	_check(GameState.cycle_weapon() and GameState.equipment.weapon == "iron_sword", "unarmed player can equip the only available weapon")
	_check(not GameState.cycle_weapon(), "a single equipped weapon stays selected")
	GameState.inventory.clear()
	GameState.equipment.weapon = ""
	_check(not GameState.cycle_weapon(), "empty inventory is handled without an error")
	GameState.inventory = {"iron_sword": 1, "wood_bow": 1}
	GameState.equipment.weapon = "iron_sword"
	player.hold_field_mine(true)
	_switch(player)
	_check(not player.is_holding_field_mine() and GameState.equipment.weapon == "wood_bow", "switching puts away a readied field mine")
	event.pressed = true
	event.echo = true
	player._unhandled_input(event)
	_check(GameState.equipment.weapon == "wood_bow", "holding V does not repeat the switch")

func _switch(player: Player) -> void:
	var event := InputEventAction.new()
	event.action = "switch_weapon"
	event.pressed = true
	player._unhandled_input(event)

func _test_map_depths() -> void:
	var objects: Node = game.world.tiled_loader.get_node("MapObjects")
	var services := 0
	var static_objects := 0
	for object in objects.get_children():
		var object_name := String(object.get_meta("object_name", ""))
		if object_name in TiledLoader.GROUND_OBJECTS or object_name.begins_with("landing_pad"):
			_check(object.z_index == 50, "walkable decoration stays below actors: " + object_name)
			continue
		if object is WorldService:
			services += 1
			var sprite := object.get_node("Sprite") as Sprite2D
			_check(object.z_index == 100 + int(object.position.y + sprite.texture.get_height() * sprite.scale.y), "service depth uses actor offset: " + object.name)
		elif object is Node2D and object.name != "ground_backdrop":
			static_objects += 1
			var sprite := object.get_child(0) as Sprite2D
			_check(object.z_index == 100 + int(object.position.y + sprite.texture.get_height() * sprite.scale.y), "scenery depth uses actor offset: " + object.name)
	_check(services > 0 and static_objects > 0, "both service buildings and ordinary scenery were checked")

func _test_rendered_occlusion() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "occlusion pixel checks require a graphical renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var loader := TiledLoader.new()
	viewport.add_child(loader)
	loader._build_roots()
	var building_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	building_image.fill(Color.GREEN)
	loader._create_static_object("iskra_scenery", ImageTexture.create_from_image(building_image), Vector2(32, 32), Vector2(64, 64), 96)
	var actor := Node2D.new()
	actor.position = Vector2(64, 88)
	actor.z_index = 100 + int(actor.position.y)
	var actor_image := Image.create(8, 24, false, Image.FORMAT_RGBA8)
	actor_image.fill(Color.RED)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(actor_image)
	sprite.centered = false
	sprite.position = Vector2(-4, -22)
	actor.add_child(sprite)
	viewport.add_child(actor)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_check(image.get_pixel(64, 80).is_equal_approx(Color.GREEN), "building covers the actor when their feet are behind it")
	actor.position.y = 104
	actor.z_index = 100 + int(actor.position.y)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	_check(image.get_pixel(64, 90).is_equal_approx(Color.RED), "actor draws in front after walking past the building base")
	loader._create_static_object("ground_backdrop", ImageTexture.create_from_image(building_image), Vector2(32, 32), Vector2(64, 64), 96)
	_check(loader.get_node("MapObjects/ground_backdrop").z_index == -10, "ground backdrops stay below actors and scenery")
	loader.get_node("MapObjects/iskra_scenery").visible = false
	loader._create_static_object("stone_bridge", ImageTexture.create_from_image(building_image), Vector2(32, 32), Vector2(64, 64), 96)
	actor.position.y = 88
	actor.z_index = 100 + int(actor.position.y)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	_check(image.get_pixel(64, 80).is_equal_approx(Color.RED), "walking on the back half of a bridge does not hide the actor")
	for object_name: String in TiledLoader.GROUND_OBJECTS:
		_check(loader._object_depth(object_name, 1000) == 50, "flat scenery stays beneath actors: " + object_name)
	_check(loader._object_depth("landing_pad_taxi_dock", 1000) == 50, "taxi pads stay beneath actors")
	viewport.queue_free()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL " + description)

func _finish() -> void:
	get_tree().paused = false
	print("Weapon and occlusion smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
