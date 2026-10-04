class_name GameUI
extends CanvasLayer

signal travel_requested(destination: String)
signal station_area_requested(area: String)
signal station_action_requested(action: String)

const INK := Color("1c1730")
const PANEL := Color(0.07, 0.065, 0.12, 0.94)
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const CYAN := Color("5fd6d3")
const RED := Color("d94b4b")
const RECRUIT_PAGE_SIZE := 10
const NORTH_REGION_Y := 352.0

var health_bar: ProgressBar
var status_label: Label
var location_label: Label
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
var _recruit_page := 0
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
	if service_id != _active_service_id:
		_recruit_page = 0
	_active_service_id = service_id
	_active_service_name = display_name
	_open_modal(display_name)
	match service_id:
		"food", "north_food": _build_food_shop(service_id == "north_food")
		"forge", "north_forge", "river_forge", "clothing", "north_clothing": _build_gear_shop(service_id)
		"work_office", "mercenary", "north_mercenary": _build_job_board(service_id)
		"river_market": _build_river_market()
		"travel": _build_travel_agency()
		"river_library": _build_river_library()
		"river_town_hall": _build_river_town_hall()
		"military_hq": _build_military_hq()
		"station_ship": _build_station_ship()
		"station_depot": _build_station_depot()
		"station_barracks": _build_station_barracks()
		"station_canteen": _build_station_canteen()
		"station_track", "station_spar", "station_squad_spar", "station_range", "station_cannon_start", "station_tnt_pile", "station_cannon", "station_trap_pad": _build_station_training(service_id)
		"player_bed", "player_chest", "recruit_bed", "recruit_chest", "barracks_exit": _build_barracks_fixture(service_id)
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
		if GameState.equipment.values().has(item_id) or (item_id == "practice_mine" and GameState.military_trap_equipped):
			suffix = "  [equipped]"
		var assigned := GameState.reserved_item_count(item_id) - (1 if GameState.equipment.values().has(item_id) else 0)
		if assigned > 0:
			suffix += "  [squad x%d]" % assigned
		var button_text := "%s x%d%s" % [definition.get("name", item_id), amount, suffix]
		if item_id == "practice_mine":
			var action_text := "Unequip" if GameState.military_trap_equipped else "Equip"
			var mine_button := _add_action_button("%s — %s" % [button_text, action_text], func() -> void:
				if not GameState.military_equip_practice_mine(not GameState.military_trap_equipped):
					GameState.notify("The practice mine can only be equipped during an active trap drill.")
				_refresh_inventory_panel()
			)
			mine_button.disabled = GameState.current_planet != "station" or GameState.military_stage != "trap" or not GameState.military_trap_round_active
		elif kind in ["weapon", "armor", "clothing"]:
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
	if GameState.current_planet == "station":
		_add_heading("Military training")
		_add_body(_station_stage_title())
		_add_body("Where: %s" % _station_stage_hint())
		_add_body("Civilian jobs remain saved and can be continued after returning to Brudet.")
	if GameState.active_jobs.is_empty():
		if GameState.current_planet != "station":
			_add_body("You have no active jobs. Visit the market or Town Hall." if GameState.current_planet == "brudet" else "You have no active jobs. Visit the WORK office or mercenary center.")
	else:
		var job_ids := GameState.active_jobs.keys()
		job_ids.sort()
		for job_id: String in job_ids:
			var definition := GameData.job(job_id)
			var tracked := job_id == GameState.tracked_job_id
			_add_heading("%s%s" % [definition.get("name", job_id), " [tracked]" if tracked else ""])
			_add_body(String(definition.get("description", "")))
			var hint := String(definition.get("location_hint", ""))
			if not hint.is_empty():
				_add_body("Where: %s" % hint)
			_add_body("Progress: %d / %d%s   Reward: %d gold\nReturn to: %s" % [int(GameState.active_jobs[job_id]), int(definition.get("target", 1)), " — ready" if GameState.active_job_ready(job_id) else "", int(definition.get("reward", 0)), String(definition.get("issuer", "work_office")).replace("_", " ").capitalize()])
			if not tracked:
				_add_action_button("Track %s" % definition.get("name", job_id), func() -> void: GameState.track_job(job_id); _refresh_jobs_panel())
			if job_id == GameState.team_job_id:
				var issuer := "northern mercenary center" if job_id == GameState.CAMP_JOB else ("first-village mercenary center" if job_id == GameState.ROAD_JOB else "Brudet Town Hall")
				_add_body("The squad mission cannot be abandoned after deployment." if GameState.squad_deployed else "Recruit two villagers at the %s before deploying." % issuer)
				if GameState.squad_deployed:
					_add_team_roster(false)
			if job_id != GameState.team_job_id or not GameState.squad_deployed:
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
	location_label = _label("", 11, CREAM)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(location_label)

	var job_panel := _panel_at(Vector2(404, 7), Vector2(228, 62))
	root.add_child(job_panel)
	job_label = _label("", 9, CREAM)
	job_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_panel.add_child(job_label)

	var notice_panel := _panel_at(Vector2(80, 75), Vector2(480, 52), CYAN)
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

	var controls := _label("WASD move   E interact   SPACE attack / place mine   I pack   J jobs   H eat   1/2/3 switch   Q/R/T orders   F5/F9 save/load", 6, Color(0.92, 0.88, 0.78, 0.92))
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
	GameState.military_changed.connect(_refresh_job)
	GameState.squad_changed.connect(_refresh_squad)
	GameState.notification_requested.connect(_show_notification)

func _refresh_all() -> void:
	refresh_location()
	_refresh_status()
	_refresh_job()
	_refresh_squad()

func refresh_location() -> void:
	match GameState.current_planet:
		"brudet": location_label.text = "BRUDET RIVER CITY"
		"station": location_label.text = "MILITARY BARRACKS" if GameState.current_area == "barracks" else "TRAINING STATION"
		_: location_label.text = "PAPRIKA VILLAGE"
	_refresh_job()

func _refresh_status() -> void:
	health_bar.max_value = GameState.max_health
	health_bar.value = GameState.health
	status_label.text = "YOU HP %d/%d    GOLD %d" % [GameState.health, GameState.max_health, GameState.gold]
	var weapon_id := String(GameState.equipment.get("weapon", ""))
	var weapon: String = GameData.item(weapon_id).get("name", "Unarmed") if not weapon_id.is_empty() else "Unarmed"
	var armor_id := String(GameState.equipment.get("armor", ""))
	var armor: String = GameData.item(armor_id).get("name", "No armor") if not armor_id.is_empty() else "No armor"
	equipment_label.text = "YOUR GEAR: %s | %s" % [weapon, armor]

func _refresh_job() -> void:
	_refresh_squad()
	if GameState.current_planet == "station":
		job_label.text = "TRAINING — J TO VIEW\n%s\n%s" % [_station_stage_title(), _station_stage_hint()]
		return
	if GameState.active_jobs.is_empty():
		job_label.text = "JOBS\nNo active jobs — visit Town Hall or market" if GameState.current_planet == "brudet" else "JOBS\nNo active jobs — visit WORK"
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

func _build_food_shop(northern: bool = false) -> void:
	_add_body("Fresh food and produce trading. Food restores health.")
	_add_heading("Buy")
	for item_id in (["rye_bread", "berry_pie", "smoked_fish"] if northern else ["bread", "stew"]):
		var definition := GameData.item(item_id)
		_add_action_button("%s — %d gold" % [definition["name"], definition["buy"]], func() -> void: GameState.buy_item(item_id); _reopen_service())
	_add_heading("Sell produce")
	for item_id in ["potato", "carrot", "tomato", "grape", "rabbit_meat"]:
		var definition := GameData.item(item_id)
		var owned := int(GameState.inventory.get(item_id, 0))
		var button := _add_action_button("%s x%d — sell for %d" % [definition["name"], owned, definition["sell"]], func() -> void: GameState.sell_item(item_id); _reopen_service())
		button.disabled = owned <= 0

func _build_gear_shop(service_id: String) -> void:
	var sections: Dictionary
	match service_id:
		"clothing":
			_add_body("Southern clothes and wooden armor for forest travel.")
			sections = {"Clothing": ["red_tunic", "blue_tunic", "green_tunic"], "Armor": ["wood_armor"]}
		"north_clothing":
			_add_body("Northern tailoring and bronze armor for forest travel.")
			sections = {"Clothing": ["purple_tunic"], "Armor": ["bronze_armor"]}
		"north_forge":
			_add_body("Bronze swords, spears, bows, and armor.")
			sections = {"Swords": ["bronze_sword"], "Spears": ["bronze_spear"], "Bows": ["bronze_bow"], "Armor": ["bronze_armor"]}
		"river_forge":
			_add_body("Brudet's iron swords, spears, bows, and armor.")
			sections = {"Swords": ["iron_sword"], "Spears": ["iron_spear"], "Bows": ["iron_bow"], "Armor": ["iron_armor"]}
		_:
			_add_body("Wooden swords, spears, bows, and armor.")
			sections = {"Swords": ["wood_sword"], "Spears": ["wood_spear"], "Bows": ["wood_bow"], "Armor": ["wood_armor"]}
	for section: String in sections:
		_add_heading(section)
		for item_id: String in sections[section]:
			var definition := GameData.item(item_id)
			var owned := int(GameState.inventory.get(item_id, 0))
			var equipped := GameState.equipment.values().has(item_id)
			var available := owned - GameState.reserved_item_count(item_id)
			var equip_text := "Equipped %s" % definition["name"] if equipped else "Equip %s (%d available)" % [definition["name"], available]
			var equip_button := _add_action_button(equip_text, func() -> void: GameState.equip_item(item_id); _reopen_service())
			equip_button.disabled = equipped or available <= 0
			_add_action_button("Buy another %s — %d gold" % [definition["name"], int(definition["buy"])], func() -> void: GameState.buy_item(item_id); _reopen_service())
	if service_id == "north_clothing":
		_add_heading("Cloth trading")
		var cloth := GameData.item("purple_cloth")
		_add_action_button("Buy %s — %d gold" % [cloth["name"], cloth["buy"]], func() -> void: GameState.buy_item("purple_cloth"); _reopen_service())
		var owned := int(GameState.inventory.get("purple_cloth", 0))
		var sell_button := _add_action_button("Sell %s x%d — %d gold" % [cloth["name"], owned, cloth["sell"]], func() -> void: GameState.sell_item("purple_cloth"); _reopen_service())
		sell_button.disabled = owned <= 0

func _build_job_board(service_id: String) -> void:
	_add_body("Accept several jobs at once. Return here to claim jobs issued here.")
	match service_id:
		"work_office":
			_add_heading("Village work")
			for job_id in ["field_work", "rabbit_catch"]:
				_add_job_button(job_id)
		"mercenary":
			_add_heading("Southern mercenary jobs")
			for job_id in ["forest_patrol", "bandit_bounty", GameState.ROAD_JOB, "hacker_bounty"]:
				_add_job_button(job_id)
			if GameState.team_job_id == GameState.ROAD_JOB:
				_add_team_roster(true)
		"north_mercenary":
			_add_heading("Northern mercenary mission")
			_add_body("The bandit camp lies west of the middle forest road. Claim the southern road cleanup reward first, then recruit two northern villagers.")
			_add_job_button(GameState.CAMP_JOB)
			if GameState.team_job_id == GameState.CAMP_JOB:
				_add_team_roster(true)

func _build_river_market() -> void:
	_add_body("Fresh catches, river food, and fishing supplies.")
	_add_heading("Buy")
	for item_id in ["fishing_rod", "fish_stew", "olive_bread", "citrus"]:
		var definition := GameData.item(item_id)
		_add_action_button("%s — %d gold" % [definition["name"], definition["buy"]], func() -> void: GameState.buy_item(item_id); _reopen_service())
	_add_heading("Sell")
	for item_id in ["river_fish", "potato", "carrot", "tomato", "grape"]:
		var definition := GameData.item(item_id)
		var owned := int(GameState.inventory.get(item_id, 0))
		var button := _add_action_button("%s x%d — sell for %d" % [definition["name"], owned, definition["sell"]], func() -> void: GameState.sell_item(item_id); _reopen_service())
		button.disabled = owned <= 0
	_add_heading("Fishing work")
	_add_job_button("fishing_work")

func _build_travel_agency() -> void:
	if GameState.current_planet == "brudet":
		_add_body("Return to Paprika for %d gold. Your Paprika position is saved for the return trip." % GameState.travel_fare("paprika"))
		_add_action_button("Return to Paprika — %d gold" % GameState.travel_fare("paprika"), func() -> void: travel_requested.emit("paprika"))
	else:
		_add_body("Visit Brudet, another Cauliflower Confederation planet. Each journey costs %d gold." % GameState.travel_fare("brudet"))
		_add_action_button("Visit Brudet — %d gold" % GameState.travel_fare("brudet"), func() -> void: travel_requested.emit("brudet"))
	_add_body("Dismiss undeployed recruits or finish a deployed squad mission before traveling.")

func _build_river_library() -> void:
	_add_heading("Craft and its history")
	_add_body("Craft is a game people play while hibernating aboard an interstellar voyage. Its roughly fifty flat planets have breathable space between them.")
	_add_body("The New Republic holds twenty-four planets and has its capital on Blockovia. Breece holds seven, Engineria five, the Cauliflower Confederation six, Saint Confederation five, and two worlds are independent.")
	_add_body("The former unified Republic split after the self-modification machine Block was destroyed. Paprika and Brudet belong to the Cauliflower Confederation, which is why ships travel between them.")
	_add_heading("Field guide")
	_add_body("The bridges cross the main river. Water cannot be walked across elsewhere. A fishing rod from the market lets you catch fish at ponds; wait before casting again.")
	_add_body("Buy food or sell a catch at the market; Brudet's forge sells iron equipment. Town Hall offers civilian cleanup jobs outside town. The Military Headquarters offers enlistment at the playable training station and has an arrow target for practice. Save with F5 and load with F9.")

func _build_river_town_hall() -> void:
	_add_body("Welcome to Brudet's river city. The market sells food and fishing rods; the nearby library has local advice and Craft history.")
	_add_body("Cross the river using the stone bridges; river monsters can swim across open water. Town Hall pays for patrols and missions outside the city.")
	_add_heading("Solo work")
	_add_job_button("river_patrol")
	_add_job_button(GameState.BRUDET_SOLO_HACKER_JOB)
	_add_heading("Three-person cleanup squads")
	_add_body("Choose one team job, recruit two local residents, equip them, and deploy. Each job has its own marked targets; finish the job before traveling.")
	for job_id in ["brudet_monster_team", "brudet_bandit_team"]:
		_add_job_button(job_id)
	if GameState.team_job_id == "brudet_hacker_team":
		_add_heading("Existing hacker squad mission")
		_add_job_button(GameState.team_job_id)
	if GameState.BRUDET_TEAM_IDS.has(GameState.team_job_id):
		_add_team_roster(true)

func _build_military_hq() -> void:
	_add_body("The Cauliflower Confederation is recruiting during the war with the Republic. Enlist at the training station before any battlefield assignment.")
	_add_body("Joining takes you straight to the station beside a regular ship. The depot issues a uniform; your bunk and footlocker are in the barracks. Dismiss civilian recruits or finish a deployed squad mission before leaving.")
	_add_body("Practice at the arrow target beside headquarters. Civilian cleanup work remains at Town Hall.")
	_add_action_button("Return to the training station" if GameState.military_stage != "none" else "Join the Military", func() -> void: travel_requested.emit("station"))

func _build_station_ship() -> void:
	var graduated := GameState.military_stage == "graduated"
	_add_body("This regular Confederation ship brought you from Brudet. Your earlier position there is saved.")
	_add_body("Complete the station drills and sleep in your bunk before taking the return trip." if not graduated else "Basic training is complete. Your return to Brudet is free; belongings left in your footlocker remain there until you collect them.")
	var button := _add_action_button("Return to Brudet — free", func() -> void: travel_requested.emit("brudet"))
	button.disabled = not graduated

func _build_station_depot() -> void:
	_add_body("Report here for your military-green uniform. Put your civilian belongings in your assigned barracks footlocker before training.")
	_add_action_button("Receive your military uniform", func() -> void: station_action_requested.emit("station_depot"))

func _build_station_barracks() -> void:
	_add_body("Your bunk and footlocker are inside. The other nine beds belong to fellow recruits.")
	_add_action_button("Enter the barracks", func() -> void: station_area_requested.emit("barracks"))

func _build_station_canteen() -> void:
	_add_body("The canteen serves a meal after each completed training drill.")
	_add_body("Meals earned: %d" % int(GameState.military_meal_credits))
	var button := _add_action_button("Collect a meal", func() -> void: station_action_requested.emit("station_canteen"))
	button.disabled = int(GameState.military_meal_credits) <= 0

func _build_station_training(service_id: String) -> void:
	var instructions := {
		"station_track": "Run the marked circuit. Hold Shift to sprint during the timed section.",
		"station_spar": "Spar with a partner. Training hits are nonlethal.",
		"station_squad_spar": "Fight alongside two recruits against three cadets. Order allies with Q, R and T.",
		"station_range": "Use the issued training bow to hit moving targets.",
		"station_cannon_start": "Start the round here. Then press E at the supply pile to take a game-only charge, at the cannon to load it, and again to fire.",
		"station_tnt_pile": "During an active round, press E here to take one game-only charge to the cannon.",
		"station_cannon": "During an active round, press E to load a charge or fire at the marked range target.",
		"station_trap_pad": "Start practice, use I to equip the toy practice mine, then press Space on the dummy's lane.",
	}
	_add_body(String(instructions.get(service_id, "Follow the instructor's directions.")))
	_add_body("Current objective: %s" % _station_stage_title())
	var stage := String(GameState.military_stage)
	var needed := {
		"station_track": "run", "station_spar": "spar", "station_squad_spar": "squad",
		"station_range": "range", "station_cannon_start": "cannon", "station_tnt_pile": "cannon", "station_cannon": "cannon", "station_trap_pad": "trap",
	}
	if service_id == "station_trap_pad" and GameState.military_trap_round_active:
		var restart_button := _add_action_button("Restart practice", func() -> void: station_action_requested.emit("station_trap_restart"))
		restart_button.disabled = stage != "trap"
		return
	var cannon_active := service_id == "station_cannon_start" and GameState.military_cannon_round_active
	var button_text := "Cannon round already active" if cannon_active else "Use training station"
	var button := _add_action_button(button_text, func() -> void: station_action_requested.emit(service_id))
	button.disabled = stage != String(needed.get(service_id, "")) or cannon_active

func _build_barracks_fixture(service_id: String) -> void:
	match service_id:
		"barracks_exit":
			_add_action_button("Leave the barracks", func() -> void: station_area_requested.emit("exterior"))
		"player_chest":
			_add_body("This is your assigned footlocker. Your personal gear stays here during training, with its original counts preserved.")
			var stage := String(GameState.military_stage)
			if stage == "barracks":
				_add_action_button("Store personal belongings", func() -> void: station_action_requested.emit("player_chest"))
			elif stage == "graduated":
				if GameState.military_storage.is_empty():
					_add_body("Your footlocker is empty.")
				else:
					_add_action_button("Retrieve stored belongings", func() -> void: station_action_requested.emit("player_chest"))
			else:
				_add_body("You can retrieve your belongings after completing training and sleeping.")
		"player_bed":
			var stage := String(GameState.military_stage)
			_add_body("Finish every drill before sleeping." if stage not in ["sleep", "graduated"] else "Rest after a long day of training.")
			var button := _add_action_button("Sleep in your bunk", func() -> void: station_action_requested.emit("player_bed"))
			button.disabled = stage not in ["sleep", "graduated"]
		"recruit_bed", "recruit_chest":
			_add_body("This bunk belongs to another recruit. Your bed and footlocker are marked nearby.")

func _station_stage_title() -> String:
	var stage := String(GameState.military_stage)
	var titles := {
		"depot": "Get your uniform at the depot",
		"barracks": "Store your belongings in the barracks",
		"run": "Run the training-field circuit",
		"spar": "Spar with a partner",
		"squad": "Train in a three-on-three squad bout",
		"range": "Shoot the moving targets",
		"cannon": "Practice at the cannon range",
		"trap": "Equip the toy practice mine and place it in the dummy's lane",
		"sleep": "Sleep in your barracks bed",
		"graduated": "Basic training complete",
	}
	return String(titles.get(stage, "Report to the station instructor"))

func _station_stage_hint() -> String:
	var hints := {
		"depot": "Depot east of the landing pad",
		"barracks": "Your footlocker inside the barracks, west of the depot",
		"run": "Running field south of the landing pad",
		"spar": "Sparring ring south of the courtyard",
		"squad": "Squad ring east of the sparring ring",
		"range": "Moving-target range in the eastern training grounds",
		"cannon": "Cannon range flag, supply pile and cannon in the southeast range",
		"trap": "Trap practice pad south of the squad ring; use I and Space",
		"sleep": "Your bed inside the barracks",
		"graduated": "Regular ship by the landing pad for a free return",
	}
	return String(hints.get(GameState.military_stage, "Military Headquarters on Brudet"))

func _add_job_button(job_id: String) -> void:
	var definition := GameData.job(job_id)
	var active := GameState.active_jobs.has(job_id)
	var complete := not bool(definition.get("repeatable", false)) and GameState.completed_unique_jobs.has(job_id)
	var camp_locked := job_id == GameState.CAMP_JOB and not GameState.camp_unlocked and not active
	var hacker_locked := job_id == "hacker_bounty" and not GameState.completed_unique_jobs.has(GameState.CAMP_JOB) and not active
	var team_conflict := bool(definition.get("team", false)) and not GameState.team_job_id.is_empty() and GameState.team_job_id != job_id
	var solo_conflict := (job_id == GameState.BRUDET_SOLO_HACKER_JOB and not GameState.team_job_id.is_empty()) or (bool(definition.get("team", false)) and GameState.active_jobs.has(GameState.BRUDET_SOLO_HACKER_JOB))
	var text_value := "%s — %d gold" % [definition["name"], definition["reward"]]
	if active:
		text_value += " — CLAIM" if GameState.active_job_ready(job_id) else " — %d/%d" % [int(GameState.active_jobs[job_id]), int(definition["target"])]
	elif complete:
		text_value += " — completed"
	elif camp_locked:
		text_value += " — locked: claim road cleanup"
	elif hacker_locked:
		text_value += " — locked: clear the bandit camp"
	elif team_conflict or solo_conflict:
		text_value += " — finish current mission"
	var button := _add_action_button(text_value, func() -> void: _job_action(job_id))
	button.tooltip_text = String(definition.get("description", ""))
	button.disabled = complete or camp_locked or hacker_locked or team_conflict or (solo_conflict and not active)
	if active and not String(definition.get("location_hint", "")).is_empty():
		_add_body("Where: %s" % definition["location_hint"])

func _job_action(job_id: String) -> void:
	if GameState.active_jobs.has(job_id):
		if GameState.active_job_ready(job_id):
			GameState.claim_job(_active_service_id, job_id)
		else:
			GameState.track_job(job_id)
	else:
		GameState.accept_job(job_id)
	_reopen_service()

func _add_team_roster(at_issuer: bool) -> void:
	var job_id := GameState.team_job_id
	if job_id.is_empty():
		return
	_add_heading("Three-person squad — %s" % GameData.job(job_id).get("name", job_id))
	if GameState.squad_deployed:
		if job_id == GameState.CAMP_JOB:
			_add_body("Defeat all three bandits at the forest camp. Camp: %d/3. Return here to claim the reward when all three fall." % GameState.camp_defeated_ids.size())
		else:
			var target_ids: Array = GameState.ROAD_IDS if job_id == GameState.ROAD_JOB else GameState.BRUDET_TEAM_IDS[job_id]
			_add_body("Clear the marked targets: %d/%d. Return to %s for your reward." % [GameState.team_defeated_ids.size(), target_ids.size(), "this mercenary center" if job_id == GameState.ROAD_JOB else "Town Hall"])
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
		if at_issuer:
			if not GameState.squad_deployed:
				_add_action_button("Dismiss %s" % _member_name(villager_id), func() -> void: GameState.dismiss_recruit(villager_id); _reopen_service())
			_add_recruit_gear_buttons(villager_id, "weapon")
			_add_recruit_gear_buttons(villager_id, "armor")
	if not at_issuer:
		return
	if GameState.squad_deployed:
		return
	if GameState.squad_recruits.size() == 2:
		var destination := "forest camp" if job_id == GameState.CAMP_JOB else ("road targets" if job_id == GameState.ROAD_JOB else "marked cleanup targets")
		_add_action_button("Deploy squad — lead them to the %s" % destination, func() -> void: GameState.deploy_squad(); _reopen_service())
		return
	_add_heading("Available villagers (%d/2 recruited)" % GameState.squad_recruits.size())
	var world := _world()
	if world == null or world.actors_root == null:
		_add_body("Villagers are unavailable. Return after the world loads.")
		return
	var villagers: Array[Villager] = []
	var region := GameState.team_recruit_region(job_id)
	for actor in world.actors_root.get_children():
		if actor is Villager and not GameState.squad_recruits.has(actor.villager_id):
			var resident := actor as Villager
			if GameState.current_planet == "brudet" or (resident.home_position.y < NORTH_REGION_Y) == (region == "north"):
				villagers.append(resident)
	villagers.sort_custom(func(a: Villager, b: Villager) -> bool: return a.villager_id < b.villager_id)
	var page_count := maxi(1, ceili(float(villagers.size()) / RECRUIT_PAGE_SIZE))
	_recruit_page = clampi(_recruit_page, 0, page_count - 1)
	_add_body("%s villagers — page %d/%d" % [region.capitalize(), _recruit_page + 1, page_count])
	for index in range(_recruit_page * RECRUIT_PAGE_SIZE, mini((_recruit_page + 1) * RECRUIT_PAGE_SIZE, villagers.size())):
		var villager := villagers[index]
		var villager_id := villager.villager_id
		_add_action_button("Recruit %s (%s)" % [villager.villager_name, villager_id], func() -> void: _recruit(villager_id))
	if _recruit_page > 0:
		_add_action_button("Previous villagers", func() -> void: _turn_recruit_page(-1))
	if _recruit_page + 1 < page_count:
		_add_action_button("Next villagers", func() -> void: _turn_recruit_page(1))

func _turn_recruit_page(direction: int) -> void:
	_recruit_page += direction
	_reopen_service()

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
		var from_player: bool = available <= 0 and GameState.equipment.get(slot, "") == item_id
		var label := "%s: %s (take from you)" % [slot.capitalize(), _gear_name(item_id)] if from_player else "%s: %s (%d available)" % [slot.capitalize(), _gear_name(item_id), available]
		var button := _add_action_button(label, func() -> void: _equip_recruit(villager_id, slot, item_id))
		button.disabled = available <= 0 and not from_player

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
	var was_equipped_by_player: bool = GameState.equipment.get(slot, "") == item_id
	if GameState.equip_recruit(villager_id, slot, item_id):
		var message := "%s equipped: %s." % [_member_name(villager_id), _gear_name(item_id)]
		if was_equipped_by_player and GameState.equipment.get(slot, "") != item_id:
			message += " You no longer have that %s equipped." % slot
		GameState.notify(message)
	_reopen_service()

func _reopen_service() -> void:
	if _active_service_id in ["food", "north_food", "forge", "north_forge", "river_forge", "clothing", "north_clothing", "work_office", "mercenary", "north_mercenary", "military_hq", "river_market", "river_library", "river_town_hall", "travel"]:
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
