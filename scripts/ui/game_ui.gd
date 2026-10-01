class_name GameUI
extends CanvasLayer

const INK := Color("1c1730")
const PANEL := Color(0.07, 0.065, 0.12, 0.94)
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const CYAN := Color("5fd6d3")
const RED := Color("d94b4b")

var health_bar: ProgressBar
var status_label: Label
var equipment_label: Label
var job_label: Label
var squad_label: Label
var squad_panel: PanelContainer
var notification_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var modal_overlay: ColorRect
var modal_panel: PanelContainer
var modal_content: VBoxContainer
var _notification_timer: Timer
var _active_service_id := ""
var _active_service_name := ""
var _squad_refresh_elapsed := 0.0

func _process(delta: float) -> void:
	if not GameState.squad_deployed:
		return
	_squad_refresh_elapsed += delta
	if _squad_refresh_elapsed >= 0.5:
		_squad_refresh_elapsed = 0.0
		_refresh_squad()

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_ui")
	_build_hud()
	_build_modal()
	_connect_state()
	_refresh_all()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jobs"):
		open_jobs()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and modal_overlay.visible:
		close_modal()
		get_viewport().set_input_as_handled()

func set_interaction_prompt(text: String) -> void:
	prompt_label.text = "[E] %s" % text if not text.is_empty() else ""
	prompt_panel.visible = not text.is_empty()

func open_service(service_id: String, display_name: String) -> void:
	_active_service_id = service_id
	_active_service_name = display_name
	_open_modal(display_name)
	match service_id:
		"food": _build_food_shop()
		"forge": _build_gear_shop(false)
		"clothing": _build_gear_shop(true)
		"work_office", "mercenary": _build_job_board(service_id)
		"travel": _build_travel_agency()
		_: _add_body("This service is not available yet.")
	_add_close_button()

func open_inventory() -> void:
	if modal_overlay.visible and _active_service_id == "inventory":
		close_modal()
		return
	_active_service_id = "inventory"
	_active_service_name = "Inventory & Equipment"
	_open_modal(_active_service_name)
	_add_body("Gold: %d    Health: %d/%d" % [GameState.gold, GameState.health, GameState.max_health])
	var item_ids := GameState.inventory.keys()
	item_ids.sort()
	if item_ids.is_empty():
		_add_body("Your pack is empty.")
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		var amount := int(GameState.inventory[item_id])
		var definition := GameData.item(item_id)
		var kind := String(definition.get("kind", ""))
		var suffix := ""
		if GameState.equipment.values().has(item_id):
			suffix = "  [equipped]"
		var button_text := "%s x%d%s" % [definition.get("name", item_id), amount, suffix]
		if kind in ["weapon", "armor", "clothing"]:
			_add_action_button(button_text, func() -> void: GameState.equip_item(item_id); _refresh_inventory_panel())
		elif kind == "food":
			_add_action_button(button_text + " — use", func() -> void: GameState.use_food(item_id); _refresh_inventory_panel())
		else:
			_add_body(button_text)
	_add_close_button()

func open_jobs() -> void:
	if modal_overlay.visible and _active_service_id == "jobs_detail":
		close_modal()
		return
	_active_service_id = "jobs_detail"
	_active_service_name = "Current Jobs"
	_open_modal(_active_service_name)
	if GameState.active_jobs.is_empty():
		_add_body("You have no active jobs. Visit the WORK office or mercenary center.")
	else:
		var job_ids := GameState.active_jobs.keys()
		job_ids.sort()
		for job_id: String in job_ids:
			var definition := GameData.job(job_id)
			var tracked := job_id == GameState.tracked_job_id
			_add_heading("%s%s" % [definition.get("name", job_id), " [tracked]" if tracked else ""])
			_add_body(String(definition.get("description", "")))
			_add_body("Progress: %d / %d%s   Reward: %d gold\nReturn to: %s" % [int(GameState.active_jobs[job_id]), int(definition.get("target", 1)), " — ready" if GameState.active_job_ready(job_id) else "", int(definition.get("reward", 0)), String(definition.get("issuer", "work_office")).replace("_", " ").capitalize()])
			if not tracked:
				_add_action_button("Track %s" % definition.get("name", job_id), func() -> void: GameState.track_job(job_id); _refresh_jobs_panel())
			if job_id == GameState.CAMP_JOB:
				_add_body("The squad mission cannot be abandoned after deployment." if GameState.squad_deployed else "Recruit two villagers at the mercenary center before deploying.")
				if GameState.squad_deployed:
					_add_camp_roster(false)
			if job_id != GameState.CAMP_JOB or not GameState.squad_deployed:
				_add_action_button("Abandon %s" % definition.get("name", job_id), func() -> void: GameState.abandon_job(job_id); _refresh_jobs_panel())
	_add_close_button()

func close_modal() -> void:
	modal_overlay.visible = false
	_active_service_id = ""
	_active_service_name = ""

func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var status_panel := _panel_at(Vector2(8, 7), Vector2(198, 62))
	root.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 1)
	status_panel.add_child(status_box)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(176, 10)
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _style(Color("342536"), Color("11101b")))
	health_bar.add_theme_stylebox_override("fill", _style(RED, RED))
	status_box.add_child(health_bar)
	status_label = _label("", 10, CREAM)
	status_box.add_child(status_label)
	equipment_label = _label("", 8, GOLD)
	status_box.add_child(equipment_label)

	var title_panel := _panel_at(Vector2(246, 7), Vector2(148, 24), GOLD)
	root.add_child(title_panel)
	var title := _label("PAPRIKA VILLAGE", 11, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(title)

	var job_panel := _panel_at(Vector2(404, 7), Vector2(228, 62))
	root.add_child(job_panel)
	job_label = _label("", 9, CREAM)
	job_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_panel.add_child(job_label)

	var notice_panel := _panel_at(Vector2(112, 75), Vector2(416, 39), CYAN)
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice_panel)
	notification_label = _label("", 10, CREAM)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_panel.add_child(notification_label)
	notice_panel.visible = false
	notification_label.set_meta("panel", notice_panel)
	_notification_timer = Timer.new()
	_notification_timer.one_shot = true
	_notification_timer.timeout.connect(func() -> void: notice_panel.visible = false)
	add_child(_notification_timer)

	prompt_panel = _panel_at(Vector2(177, 326), Vector2(286, 26), CREAM)
	root.add_child(prompt_panel)
	prompt_label = _label("", 10, CREAM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false

	squad_panel = _panel_at(Vector2(8, 290), Vector2(624, 33), CYAN)
	squad_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(squad_panel)
	squad_label = _label("", 9, CREAM)
	squad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	squad_panel.add_child(squad_label)
	squad_panel.visible = false

	var controls := _label("WASD move   E interact   SPACE attack   I pack   J jobs   H eat   1/2/3 switch   Q/R/T orders   F5/F9 save/load", 7, Color(0.92, 0.88, 0.78, 0.92))
	controls.position = Vector2(8, 349)
	controls.size = Vector2(624, 10)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(controls)

func _build_modal() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.name = "ModalOverlay"
	modal_overlay.position = Vector2.ZERO
	modal_overlay.size = Vector2(640, 360)
	modal_overlay.color = Color(0.02, 0.015, 0.04, 0.64)
	modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	modal_overlay.add_to_group("ui_modal")
	add_child(modal_overlay)
	modal_panel = _panel_at(Vector2(105, 35), Vector2(430, 292), GOLD)
	modal_overlay.add_child(modal_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	modal_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	modal_content = VBoxContainer.new()
	modal_content.custom_minimum_size = Vector2(390, 0)
	modal_content.add_theme_constant_override("separation", 4)
	scroll.add_child(modal_content)
	modal_overlay.visible = false

func _connect_state() -> void:
	GameState.health_changed.connect(func(_current: int, _maximum: int) -> void: _refresh_status())
	GameState.gold_changed.connect(func(_amount: int) -> void: _refresh_status())
	GameState.inventory_changed.connect(_refresh_status)
	GameState.equipment_changed.connect(_refresh_status)
	GameState.job_changed.connect(_refresh_job)
	GameState.squad_changed.connect(_refresh_squad)
	GameState.notification_requested.connect(_show_notification)

func _refresh_all() -> void:
	_refresh_status()
	_refresh_job()
	_refresh_squad()

func _refresh_status() -> void:
	health_bar.max_value = GameState.max_health
	health_bar.value = GameState.health
	status_label.text = "YOU HP %d/%d    GOLD %d" % [GameState.health, GameState.max_health, GameState.gold]
	var weapon: String = GameData.item(String(GameState.equipment.get("weapon", "stick"))).get("name", "Stick")
	var armor_id := String(GameState.equipment.get("armor", ""))
	var armor: String = GameData.item(armor_id).get("name", "No armor") if not armor_id.is_empty() else "No armor"
	equipment_label.text = "YOUR GEAR: %s | %s" % [weapon, armor]

func _refresh_job() -> void:
	_refresh_squad()
	if GameState.active_jobs.is_empty():
		job_label.text = "JOBS\nNo active jobs — visit WORK"
		return
	var job_id := GameState.tracked_job_id
	var definition := GameData.job(job_id)
	var ready := " — CLAIM" if GameState.active_job_ready(job_id) else ""
	job_label.text = "JOBS (%d) — J TO VIEW\n%s\n%d / %d%s" % [GameState.active_jobs.size(), definition.get("name", job_id), int(GameState.active_jobs[job_id]), int(definition.get("target", 1)), ready]

func _refresh_squad() -> void:
	squad_panel.visible = GameState.squad_deployed
	if not GameState.squad_deployed:
		return
	var active_name := _member_name(GameState.controlled_member_id)
	var summaries: Array[String] = []
	if GameState.controlled_member_id != "player":
		summaries.append("[1] You %d/%d %s" % [GameState.health, GameState.max_health, GameState.player_order])
	for index in GameState.squad_recruits.size():
		var villager_id: String = GameState.squad_recruits[index]
		var member: Dictionary = GameState.squad_members.get(villager_id, {})
		var health := "%d/%d" % [int(member.get("health", 0)), int(member.get("max_health", 24))]
		var order := "direct control" if villager_id == GameState.controlled_member_id else String(member.get("order", "follow"))
		if GameState.recruit_recovering(villager_id):
			order = "recovering %ds" % ceili(float(member["recover_until"]) - GameState.play_seconds)
		summaries.append("[%d] %s %s %s" % [index + 2, _member_name(villager_id), health, order])
	squad_label.text = "SQUAD  Active: %s (direct control)  |  Q Follow  R Hold  T Attack\n%s" % [active_name, "    |    ".join(summaries)]

func _show_notification(message: String) -> void:
	notification_label.text = message
	var panel := notification_label.get_meta("panel") as Control
	panel.visible = true
	_notification_timer.start(3.6)

func _open_modal(title: String) -> void:
	for child in modal_content.get_children():
		child.queue_free()
	modal_overlay.visible = true
	_add_heading(title)

func _build_food_shop() -> void:
	_add_body("Fresh food and produce trading. Food restores health.")
	_add_heading("Buy")
	for item_id in ["bread", "stew"]:
		var definition := GameData.item(item_id)
		_add_action_button("%s — %d gold" % [definition["name"], definition["buy"]], func() -> void: GameState.buy_item(item_id); _reopen_service())
	_add_heading("Sell produce")
	for item_id in ["potato", "carrot", "tomato", "grape", "rabbit_meat"]:
		var definition := GameData.item(item_id)
		var owned := int(GameState.inventory.get(item_id, 0))
		var button := _add_action_button("%s x%d — sell for %d" % [definition["name"], owned, definition["sell"]], func() -> void: GameState.sell_item(item_id); _reopen_service())
		button.disabled = owned <= 0

func _build_gear_shop(clothing_shop: bool) -> void:
	var sections := {}
	if clothing_shop:
		_add_body("Medieval clothes and fitted armor for forest travel.")
		sections = {
			"Clothing": ["red_tunic", "blue_tunic", "green_tunic"],
			"Armor": ["wood_armor", "bronze_armor", "iron_armor"],
		}
	else:
		_add_body("Swords, spears, and bows. Each tier gives stronger attacks.")
		sections = {
			"Swords": ["wood_sword", "bronze_sword", "iron_sword"],
			"Spears": ["wood_spear", "bronze_spear", "iron_spear"],
			"Bows": ["wood_bow", "bronze_bow", "iron_bow"],
		}
	for section: String in sections:
		_add_heading(section)
		for item_id: String in sections[section]:
			var definition := GameData.item(item_id)
			var owned := int(GameState.inventory.get(item_id, 0)) > 0
			var equipped := GameState.equipment.values().has(item_id)
			var label_text := "%s" % definition["name"]
			if equipped:
				label_text += " — equipped"
			elif owned:
				label_text += " — equip"
			else:
				label_text += " — %d gold" % int(definition["buy"])
			_add_action_button(label_text, func() -> void: _buy_or_equip(item_id))

func _build_job_board(service_id: String) -> void:
	_add_body("Accept several jobs at once. Return here to claim jobs issued here.")
	if service_id == "work_office":
		_add_heading("Village work")
		for job_id in ["field_work", "rabbit_catch"]:
			_add_job_button(job_id)
	else:
		_add_heading("Mercenary bounties")
		for job_id in ["forest_patrol", "bandit_bounty", "hacker_bounty", GameState.CAMP_JOB]:
			_add_job_button(job_id)
		if GameState.active_jobs.has(GameState.CAMP_JOB):
			_add_camp_roster(true)

func _build_travel_agency() -> void:
	_add_body("A ship ticket to a neighboring Cauliflower Confederation planet costs %d gold." % GameData.TRAVEL_FARE)
	_add_body("No destination is available in this version of Craft. Your gold will not be charged.")
	var unavailable := _add_action_button("Destinations unavailable — keep your gold", func() -> void: GameState.notify("Paprika is the only available planet for now."))
	unavailable.disabled = false

func _add_job_button(job_id: String) -> void:
	var definition := GameData.job(job_id)
	var text_value := "%s — %d gold" % [definition["name"], definition["reward"]]
	if GameState.active_jobs.has(job_id):
		text_value += " — CLAIM" if GameState.active_job_ready(job_id) else " — %d/%d" % [int(GameState.active_jobs[job_id]), int(definition["target"])]
	elif not bool(definition.get("repeatable", false)) and GameState.completed_unique_jobs.has(job_id):
		text_value += " — completed"
	elif job_id == "hacker_bounty" and GameState.hacker_defeated():
		text_value = "%s — already defeated" % definition["name"]
	elif job_id == GameState.CAMP_JOB and not GameState.hacker_defeated():
		text_value += " — locked: defeat the hacker"
	var button := _add_action_button(text_value, func() -> void: _job_action(job_id))
	button.tooltip_text = String(definition.get("description", ""))
	button.disabled = (not bool(definition.get("repeatable", false)) and GameState.completed_unique_jobs.has(job_id)) or (job_id == "hacker_bounty" and GameState.hacker_defeated() and not GameState.active_jobs.has(job_id)) or (job_id == GameState.CAMP_JOB and not GameState.hacker_defeated())

func _job_action(job_id: String) -> void:
	if GameState.active_jobs.has(job_id):
		if GameState.active_job_ready(job_id):
			GameState.claim_job(_active_service_id, job_id)
		else:
			GameState.track_job(job_id)
	else:
		GameState.accept_job(job_id)
	_reopen_service()

func _add_camp_roster(at_mercenary: bool) -> void:
	_add_heading("Three-person squad")
	if GameState.squad_deployed:
		_add_body("Defeat all three camp bandits in the northwest forest. Camp: %d/3. Return here to claim the reward when all three fall." % GameState.camp_defeated_ids.size())
	else:
		_add_body("Choose exactly two villagers below, equip them from your pack, then deploy. The mission cannot be abandoned after deployment.")
	for index in GameState.squad_recruits.size():
		var villager_id: String = GameState.squad_recruits[index]
		var member: Dictionary = GameState.squad_members.get(villager_id, {})
		var state := ""
		if GameState.squad_deployed:
			state = "  HP %d/%d  %s" % [int(member.get("health", 0)), int(member.get("max_health", 24)), String(member.get("order", "follow"))]
			if GameState.recruit_recovering(villager_id):
				state += "  recovering (%ds)" % maxi(0, ceili(float(member.get("recover_until", 0.0)) - GameState.play_seconds))
		_add_body("[%d] %s (%s)%s" % [index + 2, _member_name(villager_id), villager_id, state])
		_add_body("Weapon: %s  |  Armor: %s" % [_gear_name(String(member.get("weapon", "militia_club"))), _gear_name(String(member.get("armor", "")))])
		if at_mercenary:
			if not GameState.squad_deployed:
				_add_action_button("Dismiss %s" % _member_name(villager_id), func() -> void: GameState.dismiss_recruit(villager_id); _reopen_service())
			_add_recruit_gear_buttons(villager_id, "weapon")
			_add_recruit_gear_buttons(villager_id, "armor")
	if not at_mercenary:
		return
	if GameState.squad_deployed:
		return
	if GameState.squad_recruits.size() == 2:
		_add_action_button("Deploy squad — lead them to the northwest camp", func() -> void: GameState.deploy_squad(); _reopen_service())
		return
	_add_heading("Available villagers (%d/2 recruited)" % GameState.squad_recruits.size())
	var world := _world()
	if world == null or world.actors_root == null:
		_add_body("Villagers are unavailable. Return after the world loads.")
		return
	var villagers: Array[Villager] = []
	for actor in world.actors_root.get_children():
		if actor is Villager and not GameState.squad_recruits.has(actor.villager_id):
			villagers.append(actor)
	villagers.sort_custom(func(a: Villager, b: Villager) -> bool:
		return a.villager_name < b.villager_name or (a.villager_name == b.villager_name and a.villager_id < b.villager_id)
	)
	for villager in villagers:
		var villager_id := villager.villager_id
		_add_action_button("Recruit %s (%s)" % [villager.villager_name, villager_id], func() -> void: _recruit(villager_id))

func _add_recruit_gear_buttons(villager_id: String, slot: String) -> void:
	var member: Dictionary = GameState.squad_members.get(villager_id, {})
	var current_id := String(member.get(slot, ""))
	var default_id := "militia_club" if slot == "weapon" else ""
	if current_id != default_id:
		_add_action_button("%s: %s (remove)" % [slot.capitalize(), _gear_name(current_id)], func() -> void: _equip_recruit(villager_id, slot, default_id))
	var item_ids := GameState.inventory.keys()
	item_ids.sort()
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		if String(GameData.item(item_id).get("kind", "")) != slot or item_id == current_id:
			continue
		var available := int(GameState.inventory[item_id]) - GameState.reserved_item_count(item_id)
		var button := _add_action_button("%s: %s (%d available)" % [slot.capitalize(), _gear_name(item_id), available], func() -> void: _equip_recruit(villager_id, slot, item_id))
		button.disabled = available <= 0

func _world() -> GameWorld:
	var world := get_tree().get_first_node_in_group("game_world") as GameWorld
	if world == null:
		world = get_parent().get_node_or_null("PaprikaWorld") as GameWorld
	return world

func _member_name(member_id: String) -> String:
	if member_id == "player":
		return "You"
	var world := _world()
	if world != null:
		var villager := world.find_villager(member_id)
		if villager != null:
			return villager.villager_name
	return member_id

func _gear_name(item_id: String) -> String:
	return String(GameData.item(item_id).get("name", "None")) if not item_id.is_empty() else "None"

func _recruit(villager_id: String) -> void:
	var world := _world()
	if world != null and world.recruit(villager_id):
		GameState.notify("%s joined your squad." % _member_name(villager_id))
	_reopen_service()

func _equip_recruit(villager_id: String, slot: String, item_id: String) -> void:
	if GameState.equip_recruit(villager_id, slot, item_id):
		GameState.notify("%s equipped: %s." % [_member_name(villager_id), _gear_name(item_id)])
	_reopen_service()

func _buy_or_equip(item_id: String) -> void:
	if int(GameState.inventory.get(item_id, 0)) > 0:
		GameState.equip_item(item_id)
	elif GameState.buy_item(item_id):
		GameState.equip_item(item_id)
	_reopen_service()

func _reopen_service() -> void:
	if _active_service_id in ["food", "forge", "clothing", "work_office", "mercenary", "travel"]:
		open_service(_active_service_id, _active_service_name)
	elif _active_service_id == "inventory":
		_refresh_inventory_panel()

func _refresh_inventory_panel() -> void:
	_active_service_id = ""
	open_inventory()

func _refresh_jobs_panel() -> void:
	_active_service_id = ""
	open_jobs()

func _add_heading(text_value: String) -> void:
	var heading := _label(text_value, 13, GOLD)
	heading.custom_minimum_size = Vector2(0, 20)
	modal_content.add_child(heading)

func _add_body(text_value: String) -> void:
	var body := _label(text_value, 10, CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(380, 18)
	modal_content.add_child(body)

func _add_action_button(text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(380, 24)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("29253b"), Color("57506d")))
	button.add_theme_stylebox_override("hover", _style(GOLD, GOLD))
	button.add_theme_stylebox_override("pressed", _style(CYAN, CYAN))
	button.pressed.connect(action)
	modal_content.add_child(button)
	return button

func _add_close_button() -> void:
	_add_action_button("Close  [Esc]", close_modal)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", INK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _panel_at(panel_position: Vector2, panel_size: Vector2, border: Color = Color("57506d")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = panel_position
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(PANEL, border))
	return panel

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
