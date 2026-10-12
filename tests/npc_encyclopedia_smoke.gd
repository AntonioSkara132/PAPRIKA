extends Node

const NpcEncyclopedia = preload("res://scripts/data/npc_encyclopedia.gd")

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)

func _run() -> void:
	var entries := NpcEncyclopedia.entries()
	var ids := {}
	for entry in entries:
		var id: String = entry["id"]
		check(not ids.has(id), "Duplicate entry " + id)
		ids[id] = true
		check(ResourceLoader.exists(entry["image"]), "Missing image " + id)
		check(not String(entry["intro"]).is_empty(), "Missing introduction " + id)
		check(NpcEncyclopedia.CATEGORIES.has(entry["category"]), "Unknown category " + id)
		check(not NpcEncyclopedia.stats(entry).is_empty(), "Missing facts " + id)
	for enemy_id in GameData.ENEMIES:
		check(ids.has(enemy_id) or enemy_id in ["bandit", "camp_bandit"], "Missing hostile " + enemy_id)
	check(NpcEncyclopedia.stats(_find(entries, "hacker")).contains("150 health, 24 damage"), "Chvarak hacker stats")
	check(NpcEncyclopedia.stats(_find(entries, "villager")).contains("Health 12"), "Civilian stats")
	check(NpcEncyclopedia.stats(_find(entries, "councillor")).contains("not defined"), "Undefined civilian combat stats")
	var main: Node2D = load("res://scripts/main.gd").new()
	main._ensure_input_actions()
	check(InputMap.has_action("encyclopedia"), "Shortcut is registered")
	var ui := GameUI.new()
	add_child(ui)
	await get_tree().process_frame
	ui.open_encyclopedia()
	check(ui.modal_overlay.visible, "Encyclopedia opens")
	check(ui._active_service_id == "encyclopedia_categories", "Category page")
	ui._show_encyclopedia_list("Wildlife")
	check(ui._active_service_id == "encyclopedia_list", "List page")
	ui._show_encyclopedia_entry(_find(entries, "wolf"))
	check(ui._active_service_id == "encyclopedia_entry", "Detail page")
	check(ui.modal_content.get_node_or_null("EntryImage") != null, "Detail image")
	ui.close_modal()
	check(not ui.modal_overlay.visible, "Encyclopedia closes")
	var key := InputEventAction.new()
	key.action = "encyclopedia"
	key.pressed = true
	ui._input(key)
	check(ui._active_service_id == "encyclopedia_categories", "Shortcut opens category page")
	ui._input(key)
	check(not ui.modal_overlay.visible, "Shortcut toggles encyclopedia off")
	ui.scene_panel.visible = true
	ui._input(key)
	check(not ui.modal_overlay.visible, "Shortcut does not interrupt dialogue")
	ui.scene_panel.visible = false
	ui.order_bar.visible = true
	ui._input(key)
	check(not ui.modal_overlay.visible, "Shortcut does not interrupt typed orders")
	main.free()
	print("NPC encyclopedia: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _find(entries: Array[Dictionary], id: String) -> Dictionary:
	for entry in entries:
		if entry["id"] == id:
			return entry
	return {}
