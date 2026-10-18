extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", description)

func _run() -> void:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	var ui: GameUI = game.game_ui
	var player: Player = game.world.player
	ui.open_inventory()
	await get_tree().process_frame
	var view: InventoryView = ui.inventory_panel
	_check(view.visible and not ui.modal_panel.visible, "the inventory has its own panel")
	_check(view.find_child("Item_stick", true, false) != null, "the backpack contains the starting weapon")
	var icon := view.find_child("ItemIcon", true, false) as TextureRect
	_check(icon != null and icon.texture != null, "backpack items have artwork")
	_check(view.find_child("PlayerBodyPreview", true, false) != null, "player preview is drawn")
	GameState.add_item("iron_armor")
	GameState.add_item("iron_sword")
	GameState.equip_item("iron_armor")
	GameState.equip_item("iron_sword")
	view.refresh()
	_check(view.find_child("PlayerArmorPreview", true, false) != null, "worn armor appears on preview")
	_check(view.find_child("PlayerWeaponPreview", true, false) != null, "equipped weapon appears on preview")
	_check(not GameState.can_discard_item("iron_sword"), "the one equipped weapon cannot be discarded")
	GameState.add_item("iron_sword")
	_check(GameState.discard_item("iron_sword") and GameState.inventory["iron_sword"] == 1, "only a spare equipped weapon can be discarded")
	GameState.add_item("embassy_letters")
	_check(not GameState.discard_item("embassy_letters"), "story items cannot be discarded")
	GameState.add_item("military_uniform")
	_check(not GameState.discard_item("military_uniform"), "issued uniforms cannot be discarded")
	GameState.add_item("berry_pie", 3)
	view._select("berry_pie")
	view._confirm_drop(1)
	_check(view.find_child("CancelDrop", true, false) != null, "drop requests confirmation")
	(view.find_child("CancelDrop", true, false) as Button).pressed.emit()
	_check(GameState.inventory["berry_pie"] == 3, "cancelled drop keeps the item")
	view._confirm_drop(1)
	(view.find_child("ConfirmDrop", true, false) as Button).pressed.emit()
	_check(GameState.inventory["berry_pie"] == 2, "confirmed drop removes one")
	_check(GameState.discard_item("berry_pie", 2) and not GameState.inventory.has("berry_pie"), "the free stack can be discarded")
	GameState.add_gold(200)
	_check(GameState.buy_arrow_bundle("bronze_arrow"), "the bronze forge bundle can be bought")
	_check(GameState.buy_arrow_bundle("iron_arrow"), "the iron forge bundle can be bought")
	_check(GameState.inventory["bronze_arrow"] == 10 and GameState.inventory["iron_arrow"] == 10 and GameState.gold == 65, "bundle quantities and prices")
	_check(not GameState.buy_item("bronze_arrow"), "ordinary shops cannot sell one arrow")
	_check(not GameState.buy_arrow_bundle("basic_arrow"), "unlimited basic arrows cannot be purchased")
	_check(not GameState.buy_arrow_bundle("iron_arrow") and GameState.gold == 65, "an unaffordable bundle changes nothing")
	GameState.add_item("wood_bow")
	GameState.equip_item("wood_bow")
	_check(GameState.select_arrows("bronze_arrow"), "bronze arrows can be selected")
	ui.close_modal()
	player.set("_attack_cooldown", 0.0)
	player._attack()
	var shot := _last_shot(player)
	_check(shot != null and shot.damage == 10 and shot.max_distance == 150.0, "wood bow fires bronze damage at wood range")
	_check(GameState.inventory["bronze_arrow"] == 9, "a fired arrow is consumed")
	player._attack()
	_check(GameState.inventory["bronze_arrow"] == 9, "cooldown does not consume an arrow")
	GameState.add_item("iron_bow")
	GameState.equip_item("iron_bow")
	GameState.select_arrows("iron_arrow")
	player.set("_attack_cooldown", 0.0)
	player._attack()
	shot = _last_shot(player)
	_check(shot != null and shot.damage == 15 and shot.max_distance == 190.0, "iron bow retains range while iron arrow determines damage")
	_check(GameState.inventory["iron_arrow"] == 9, "iron arrow is consumed once")
	GameState.remove_item("iron_arrow", 8)
	player.set("_attack_cooldown", 0.0)
	player._attack()
	shot = _last_shot(player)
	_check(shot != null and shot.damage == 15 and GameState.selected_arrows == GameState.BASIC_ARROW, "last iron arrow fires then returns to basic")
	player.set("_attack_cooldown", 0.0)
	player._attack()
	shot = _last_shot(player)
	_check(shot != null and shot.damage == 4, "basic arrows remain unlimited")
	GameState.select_arrows("bronze_arrow")
	# The issued uniform cannot exist before enlistment in a valid save.
	GameState.inventory.erase("military_uniform")
	_check(GameState.save_game(), "selected arrows can be saved")
	var save_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(save_data.get("selected_arrows", "") == "bronze_arrow", "selection is written to the save")
	save_data.erase("selected_arrows")
	_check(GameState._valid_save(save_data), "older saves without arrow selection remain valid")
	GameState.select_arrows(GameState.BASIC_ARROW)
	_check(GameState.load_game() and GameState.selected_arrows == "bronze_arrow", "selected arrows reload")
	ui.open_inventory()
	ui.open_jobs()
	_check(not view.visible and ui.modal_panel.visible, "switching to jobs closes the inventory panel")
	ui.open_inventory()
	ui.open_planet_map()
	_check(not view.visible and ui.planet_map.visible, "switching to map closes the inventory panel")
	print("Inventory smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _last_shot(player: Player) -> Projectile:
	var shot: Projectile
	for node in player.get_parent().get_children():
		if node is Projectile:
			shot = node
	return shot
