extends Node

var game: Node
var ui: GameUI
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var home := OS.get_environment("XDG_DATA_HOME")
	if home.is_empty() or not ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(home + "/"):
		_check(false, "isolated saves required")
		_finish()
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	ui = game.game_ui
	ui.cancel_scene()
	var player: Player = game.world.player
	GameState.max_health = 28
	GameState.restore_health()
	GameState.equipment.armor = ""

	_check(not GameState.drink_life_potion() and GameState.potion_health == 0, "no potion to drink without one in the inventory")
	GameState.add_item("life_potion", 2)
	_check(GameState.drink_life_potion() and GameState.potion_health == GameData.LIFE_POTION_HEALTH, "a Life Potion gives sixteen extra health")
	_check(GameState.health == GameState.max_health, "the potion does not change normal health or its maximum")
	_check(not GameState.drink_life_potion() and GameState.inventory.get("life_potion", 0) == 1, "a second dose is refused while one is working")
	GameState.damage_player(10)
	_check(GameState.potion_health == 6 and GameState.health == 28, "damage uses potion health first")
	GameState.damage_player(10)
	_check(GameState.potion_health == 0 and GameState.health == 24, "damage past the potion reaches normal health")
	GameState.add_item("bread")
	GameState.use_food("bread")
	_check(GameState.potion_health == 0 and GameState.health == 28, "food heals normal health but never refills the potion")

	GameState.drink_life_potion()
	GameState.add_item("tvrdium_armor")
	GameState.equip_item("tvrdium_armor")
	GameState.damage_player(8)
	_check(GameState.potion_health == 13, "armor reduces a hit before the potion absorbs it")
	_check(GameState.save_game(), "save with an active potion")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(int(saved.get("potion_health", -1)) == 13 and GameState._valid_save(saved), "potion health is saved and validates")
	var bad := saved.duplicate(true)
	bad["potion_health"] = 99
	_check(not GameState._valid_save(bad), "a save with more potion health than one dose is rejected")
	var old := saved.duplicate(true)
	old.erase("potion_health")
	_check(GameState._valid_save(old), "older saves without potion health still load")
	GameState.potion_health = 0
	_check(GameState.load_game() and GameState.potion_health == 13, "load restores the active potion")

	player._respawn()
	_check(GameState.potion_health == 0, "defeat ends the potion's strength")
	_check(GameState.inventory.get("life_potion", 0) == 0, "both bottles were drunk")
	GameState.add_item("life_potion")
	GameState.drink_life_potion()
	player._invulnerability = 0.0
	player.take_banishing_hit()
	_check(GameState.potion_health == 0, "a Banishing Arrow kills through a Life Potion")
	GameState.add_item("life_potion")
	player._respawn()
	_check(GameState.inventory.get("life_potion", 0) == 1, "unopened bottles keep after defeat")

	ui.open_service("skoljka_apothecary", "Skoljka Apothecary")
	var texts := _modal_text()
	_check(texts.contains("Secret to Long Life") and texts.contains("scientists of Skoljka"), "the apothecary sells it as the Secret to Long Life by Skoljka scientists")
	_check(texts.contains("Life Potion — 120 gold"), "the apothecary lists the Life Potion for 120 gold")
	ui.close_modal()
	var service: Dictionary = game.world.tiled_loader._service_for_object("skoljka_apothecary")
	_check(service.get("id", "") == "skoljka_apothecary", "the Skoljka map stall opens the apothecary")
	_check(FileAccess.get_file_as_string("res://maps/skoljka.tmj").contains("\"name\": \"skoljka_apothecary\""), "the third Skoljka market stall is the apothecary")
	ui.open_service("iskra_food", "Food Hall")
	texts = _modal_text()
	for item_id in ["greenhouse_salad", "dock_dumplings", "copper_pot_roast", "bread", "stew"]:
		_check(texts.contains(GameData.item(item_id).name), "Iskra Food Hall sells " + item_id)
	ui.close_modal()
	GameState.gold = 100
	_check(GameState.buy_item("dock_dumplings") and GameState.gold == 85, "Iskra food can be bought")
	GameState.health = 10
	_check(GameState.use_food("dock_dumplings") and GameState.health == 26, "dock crew dumplings restore sixteen")
	_finish()

func _modal_text() -> String:
	var parts: PackedStringArray = []
	for node in ui.modal_content.find_children("*", "", true, false):
		if node is Button:
			parts.append(node.text)
		elif node is Label or node is RichTextLabel:
			parts.append(node.text)
	return "\n".join(parts)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])

func _finish() -> void:
	print("Life potion: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
