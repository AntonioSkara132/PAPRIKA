class_name InventoryView
extends PanelContainer

const ItemIcons = preload("res://scripts/data/item_icons.gd")
const INK := Color("1c1730")
const PANEL := Color("151321")
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const CYAN := Color("5fd6d3")

var _ui: CanvasLayer
var _root: Control
var _grid: GridContainer
var _scroll: ScrollContainer
var _preview: Control
var _slots: VBoxContainer
var _summary: Label
var _detail: Control
var _confirm_layer: Control
var _selected_id := ""
var _buttons: Dictionary = {}

func setup(ui: CanvasLayer) -> void:
	_ui = ui

func _ready() -> void:
	name = "InventoryPanel"
	position = Vector2(36, 25)
	size = Vector2(568, 310)
	add_theme_stylebox_override("panel", _style(PANEL, GOLD))
	_build()
	visible = false
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.equipment_changed.connect(_on_inventory_changed)

func open() -> void:
	_dismiss_drop()
	visible = true
	refresh()

func refresh() -> void:
	if not visible:
		return
	var scroll_y := _scroll.scroll_vertical
	var focused := get_viewport().gui_get_focus_owner()
	var restore_focus := focused != null and is_ancestor_of(focused)
	var previous := _selected_id
	var item_ids := _item_ids()
	if previous != GameState.BASIC_ARROW and not item_ids.has(previous):
		_selected_id = String(item_ids[0]) if not item_ids.is_empty() else GameState.BASIC_ARROW
	_build_grid(item_ids)
	_build_loadout()
	_build_detail()
	_scroll.set_deferred("scroll_vertical", scroll_y)
	if restore_focus and _buttons.has(_selected_id):
		(_buttons[_selected_id] as Button).grab_focus.call_deferred()

func _on_inventory_changed() -> void:
	if visible and not _confirm_layer.visible:
		refresh.call_deferred()

func _build() -> void:
	_root = Control.new()
	_root.name = "InventoryContents"
	_root.custom_minimum_size = Vector2(554, 298)
	add_child(_root)
	_label("INVENTORY", Vector2(8, 4), Vector2(145, 19), 14, GOLD)
	_summary = _label("", Vector2(155, 7), Vector2(334, 17), 10, CREAM)
	var close := _button("X  Esc", Vector2(493, 5), Vector2(55, 20), func() -> void: _ui.close_modal())
	close.name = "InventoryClose"
	_label("EQUIPPED", Vector2(9, 30), Vector2(165, 17), 11, GOLD)
	_label("BACKPACK", Vector2(190, 30), Vector2(341, 17), 11, GOLD)
	var divider := ColorRect.new()
	divider.position = Vector2(181, 30)
	divider.size = Vector2(1, 260)
	divider.color = Color("57506d")
	_root.add_child(divider)
	_preview = Control.new()
	_preview.name = "PlayerPreview"
	_preview.position = Vector2(14, 50)
	_preview.size = Vector2(156, 90)
	_root.add_child(_preview)
	_slots = VBoxContainer.new()
	_slots.name = "EquippedSlots"
	_slots.position = Vector2(9, 151)
	_slots.size = Vector2(163, 116)
	_slots.add_theme_constant_override("separation", 3)
	_root.add_child(_slots)
	_scroll = ScrollContainer.new()
	_scroll.name = "BackpackScroll"
	_scroll.position = Vector2(190, 49)
	_scroll.size = Vector2(351, 145)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "BackpackGrid"
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)
	_detail = Control.new()
	_detail.name = "ItemDetails"
	_detail.position = Vector2(190, 201)
	_detail.size = Vector2(354, 92)
	_root.add_child(_detail)
	_confirm_layer = Control.new()
	_confirm_layer.name = "DropConfirmation"
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_confirm_layer)
	_confirm_layer.visible = false

func _item_ids() -> Array:
	var result := GameState.inventory.keys()
	result.sort_custom(func(a: String, b: String) -> bool: return String(GameData.item(a).get("name", a)) < String(GameData.item(b).get("name", b)))
	return result

func _build_grid(item_ids: Array) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()
	if item_ids.is_empty():
		_label("Your backpack is empty.", Vector2.ZERO, Vector2(280, 30), 11, CREAM, _grid)
	for value in item_ids:
		var item_id := String(value)
		var amount := int(GameState.inventory[item_id])
		var definition := GameData.item(item_id)
		var button := _button("", Vector2.ZERO, Vector2(50, 43), func() -> void: _select(item_id), _grid)
		button.name = "Item_%s" % item_id
		button.tooltip_text = "%s ×%d" % [definition.get("name", item_id), amount]
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_stylebox_override("normal", _style(Color("352e43") if item_id == _selected_id else Color("282339"), GOLD if item_id == _selected_id else Color("57506d")))
		var icon := _icon(item_id, Vector2(12, 1), Vector2(26, 26), button)
		icon.name = "ItemIcon"
		var qty := _label("×%d" % amount, Vector2(3, 27), Vector2(44, 13), 8, CREAM, button)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var status := "E" if GameState.equipment.values().has(item_id) or item_id == GameState.selected_arrows else "S" if GameState.reserved_item_count(item_id) > 0 else ""
		if not status.is_empty():
			var badge := _label(status, Vector2(39, 0), Vector2(11, 12), 8, CYAN, button)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buttons[item_id] = button

func _select(item_id: String) -> void:
	_selected_id = item_id
	refresh()

func _build_loadout() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	for child in _preview.get_children():
		_preview.remove_child(child)
		child.queue_free()
	_summary.text = "HP %d/%d   GOLD %d" % [GameState.health, GameState.max_health, GameState.gold]
	var backing := ColorRect.new()
	backing.size = _preview.size
	backing.color = Color("292538")
	_preview.add_child(backing)
	var world := get_tree().get_first_node_in_group("game_world")
	var player: Node = world.get("player") if world != null else null
	if player != null:
		var sprite := player.get("_sprite") as Sprite2D
		var armor := player.get("_armor_overlay") as Sprite2D
		if sprite != null and sprite.texture != null:
			var body := _texture(sprite.texture, Vector2(54, 8), Vector2(48, 72), _preview)
			body.name = "PlayerBodyPreview"
		if armor != null and armor.visible and armor.texture != null:
			var plate := _texture(armor.texture, Vector2(54, 8), Vector2(48, 72), _preview)
			plate.name = "PlayerArmorPreview"
			plate.modulate = armor.modulate
	var weapon_id := String(GameState.equipment.get("weapon", ""))
	if not weapon_id.is_empty():
		var held := _icon(weapon_id, Vector2(92, 35), Vector2(32, 32), _preview)
		held.name = "PlayerWeaponPreview"
	for slot: String in ["weapon", "armor", "clothing"]:
		var item_id := String(GameState.equipment.get(slot, ""))
		_add_slot(slot.capitalize(), item_id, "None" if item_id.is_empty() else String(GameData.item(item_id).get("name", item_id)))
	var arrow_id := GameState.selected_arrows
	var ammo_label := "Basic Arrows ∞" if arrow_id == GameState.BASIC_ARROW else "%s ×%d" % [GameData.item(arrow_id).get("name", arrow_id), int(GameState.inventory.get(arrow_id, 0))]
	_add_slot("Arrows", arrow_id, ammo_label)
	var previous_unequip := _root.get_node_or_null("UnequipArmor")
	if previous_unequip != null:
		_root.remove_child(previous_unequip)
		previous_unequip.queue_free()
	var unequip := _button("Unequip armor", Vector2(9, 274), Vector2(163, 18), func() -> void: GameState.unequip_armor(); refresh(), _root)
	unequip.name = "UnequipArmor"
	unequip.disabled = String(GameState.equipment.get("armor", "")).is_empty()

func _add_slot(slot: String, item_id: String, title: String) -> void:
	var row := _button("", Vector2.ZERO, Vector2(163, 24), func() -> void: _select(GameState.BASIC_ARROW if slot == "Arrows" or item_id.is_empty() else item_id), _slots)
	row.name = "Equipped%s" % slot
	row.tooltip_text = "%s: %s" % [slot, title]
	if not item_id.is_empty():
		_icon(item_id, Vector2(3, 2), Vector2(20, 20), row)
	var label := _label("%s: %s" % [slot, title], Vector2(25, 3), Vector2(134, 19), 9, CREAM, row)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if _selected_id.is_empty():
		_label("Select an item.", Vector2.ZERO, Vector2(340, 20), 11, CREAM, _detail)
		return
	if _selected_id == GameState.BASIC_ARROW:
		_label("Basic Arrows ∞", Vector2.ZERO, Vector2(344, 18), 11, GOLD, _detail)
		_label("Unlimited · 4 damage with any bow", Vector2(0, 20), Vector2(343, 18), 9, CREAM, _detail)
		var basics := _button("Use Basic Arrows", Vector2(0, 47), Vector2(145, 19), func() -> void: GameState.select_arrows(GameState.BASIC_ARROW); refresh(), _detail)
		basics.disabled = GameState.selected_arrows == GameState.BASIC_ARROW
		return
	var definition := GameData.item(_selected_id)
	if definition.is_empty():
		return
	var owned := int(GameState.inventory.get(_selected_id, 0))
	_label("%s ×%d" % [definition.get("name", _selected_id), owned], Vector2.ZERO, Vector2(343, 18), 11, GOLD, _detail)
	var kind := String(definition.get("kind", ""))
	var info := ""
	match kind:
		"weapon": info = "Damage %d · Reach %d · Recovery %.2fs" % [4 if bool(definition.get("ranged", false)) else GameData.weapon_damage(definition), int(definition.get("reach", 24)), float(definition.get("cooldown", 0.5))]
		"armor": info = "Armor %d" % int(definition.get("protection", 0))
		"food": info = "Restores %d health" % int(definition.get("heal", 0))
		"ammo": info = "%d damage with any bow · %d left" % [int(definition.get("damage", 0)), owned]
		"potion": info = "+%d extra health; food does not refill it" % GameData.LIFE_POTION_HEALTH
		"key": info = "Story item · cannot be discarded"
	if bool(definition.get("ranged", false)):
		info = "Range %d · %.2fs · damage from arrows" % [int(definition.get("reach", 0)), float(definition.get("cooldown", 0.5))]
	var reserved := GameState.reserved_item_count(_selected_id)
	if reserved > 0:
		info += " · %d equipped/assigned" % reserved
	_label(info, Vector2(0, 19), Vector2(348, 26), 9, CREAM, _detail).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_x := 0
	if kind in ["weapon", "armor", "clothing"]:
		var equip := _button("Equip", Vector2(action_x, 45), Vector2(67, 20), func() -> void: GameState.equip_item(_selected_id); refresh(), _detail)
		equip.disabled = GameState.equipment.values().has(_selected_id) or GameState.free_item_count(_selected_id) <= 0
	elif kind == "ammo":
		var arrow := _button("Use Arrows", Vector2(action_x, 45), Vector2(94, 20), func() -> void: GameState.select_arrows(_selected_id); refresh(), _detail)
		arrow.disabled = GameState.selected_arrows == _selected_id
	elif kind == "food":
		var use := _button("Eat" if _selected_id != "bandage" else "Use", Vector2(action_x, 45), Vector2(65, 20), func() -> void: GameState.use_food(_selected_id); refresh(), _detail)
		use.disabled = GameState.health >= GameState.max_health
		action_x += 70
		if GameState.davor_wounded():
			_button("Give to Davor", Vector2(action_x, 45), Vector2(116, 20), func() -> void: GameState.feed_davor(_selected_id); refresh(), _detail)
	elif kind == "potion":
		var drink := _button("Drink", Vector2(action_x, 45), Vector2(67, 20), func() -> void: GameState.drink_life_potion(); refresh(), _detail)
		drink.disabled = GameState.potion_health > 0
	elif _selected_id == "practice_mine":
		var mine := _button("Unequip" if GameState.military_trap_equipped else "Equip", Vector2(0, 45), Vector2(80, 20), func() -> void: GameState.military_equip_practice_mine(not GameState.military_trap_equipped); refresh(), _detail)
		mine.disabled = GameState.current_planet != "station" or GameState.military_stage != "trap" or not GameState.military_trap_round_active
	elif _selected_id == "field_mine":
		var world := get_tree().get_first_node_in_group("game_world")
		var holding: bool = world != null and world.get("player") != null and world.player.has_method("is_holding_field_mine") and world.player.is_holding_field_mine()
		var field := _button("Put away" if holding else "Ready", Vector2(0, 45), Vector2(85, 20), func() -> void: world.set_field_mine_ready(not holding); refresh(), _detail)
		field.disabled = world == null or not world.has_method("set_field_mine_ready")
	var free := GameState.free_item_count(_selected_id)
	var drop_one := _button("Drop 1", Vector2(0, 69), Vector2(77, 19), func() -> void: _confirm_drop(1), _detail)
	drop_one.disabled = not GameState.can_discard_item(_selected_id)
	drop_one.tooltip_text = "Permanently discard one copy; it will not appear on the ground."
	if free > 1:
		var drop_all := _button("Drop all free (%d)" % free, Vector2(83, 69), Vector2(154, 19), func() -> void: _confirm_drop(GameState.free_item_count(_selected_id)), _detail)
		drop_all.disabled = not GameState.can_discard_item(_selected_id)

func _confirm_drop(amount: int) -> void:
	for child in _confirm_layer.get_children():
		_confirm_layer.remove_child(child)
		child.queue_free()
	var item_id := _selected_id
	var shade := ColorRect.new()
	shade.size = _root.custom_minimum_size
	shade.color = Color(0.02, 0.015, 0.04, 0.81)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.add_child(shade)
	var box := PanelContainer.new()
	box.position = Vector2(83, 96)
	box.size = Vector2(390, 102)
	box.add_theme_stylebox_override("panel", _style(PANEL, GOLD))
	_confirm_layer.add_child(box)
	var content := Control.new()
	content.custom_minimum_size = Vector2(378, 91)
	box.add_child(content)
	var name := String(GameData.item(item_id).get("name", item_id))
	var question := _label("Drop %d %s permanently?" % [amount, name], Vector2(8, 5), Vector2(357, 25), 12, GOLD, content)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("This item will not appear on the ground or be recoverable.", Vector2(8, 33), Vector2(358, 27), 9, CREAM, content).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cancel := _button("Keep item", Vector2(12, 66), Vector2(125, 20), _dismiss_drop, content)
	cancel.name = "CancelDrop"
	var accept := _button("Drop permanently", Vector2(195, 66), Vector2(173, 20), func() -> void:
		if not GameState.discard_item(item_id, amount):
			GameState.notify("That item cannot be dropped now.")
		_dismiss_drop()
		refresh()
	, content)
	accept.name = "ConfirmDrop"
	_confirm_layer.visible = true
	for button in _root.find_children("*", "Button", true, false):
		if not _confirm_layer.is_ancestor_of(button):
			(button as Button).focus_mode = Control.FOCUS_NONE
	cancel.grab_focus()

func _dismiss_drop() -> void:
	if _confirm_layer == null:
		return
	_confirm_layer.visible = false
	for button in _root.find_children("*", "Button", true, false):
		(button as Button).focus_mode = Control.FOCUS_ALL

func _icon(item_id: String, pos: Vector2, dimensions: Vector2, parent: Control) -> TextureRect:
	var path := ItemIcons.icon_path(item_id)
	var texture := load(path) as Texture2D
	return _texture(texture, pos, dimensions, parent)

func _texture(texture: Texture2D, pos: Vector2, dimensions: Vector2, parent: Control) -> TextureRect:
	var picture := TextureRect.new()
	picture.position = pos
	picture.size = dimensions
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _label(text: String, pos: Vector2, dimensions: Vector2, font_size: int, tint: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _root).add_child(label)
	return label

func _button(text: String, pos: Vector2, dimensions: Vector2, action: Callable, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.custom_minimum_size = dimensions
	button.size = dimensions
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("29253b"), Color("57506d")))
	button.add_theme_stylebox_override("hover", _style(GOLD, GOLD))
	button.add_theme_stylebox_override("pressed", _style(CYAN, CYAN))
	button.pressed.connect(action)
	(parent if parent != null else _root).add_child(button)
	return button

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
