extends Node

signal health_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal inventory_changed
signal equipment_changed
signal job_changed
signal squad_changed
signal notification_requested(message: String)
signal save_finished(success: bool)
signal military_changed

const SAVE_PATH := "user://paprika_save.json"
const SAVE_BACKUP_PATH := "user://paprika_save.backup.json"
const SAVE_SCHEMA := 12
const POMIDOR_SAVE_SCHEMA := 12
const ARTICHOKE_SAVE_SCHEMA := 11
const MILITARY_ROUND_SAVE_SCHEMA := 10
const STATION_SAVE_SCHEMA := 9
const CAMP_UNLOCK_SAVE_SCHEMA := 8
const PAPRIKA_LOCAL_RECRUIT_SCHEMA := 7
const BRUDET_TEAM_SAVE_SCHEMA := 6
const PAPRIKA_LAYOUT_SCHEMA := 5
const PLANET_SAVE_SCHEMA := 4
const SQUAD_SAVE_SCHEMA := 3
const PAPRIKA_OLD_SOUTH_Y := 352.0
const PAPRIKA_OLD_SOUTH_ROW := 22
const PAPRIKA_LAYOUT_SHIFT := 768.0
const PAPRIKA_FIELD_ROW_SHIFT := 48
const PLANETS := ["paprika", "brudet", "station", "artichoke", "pomidor"]
const ARTICHOKE_PLANETS := ["paprika", "brudet", "station", "artichoke"]
const STATION_PLANETS := ["paprika", "brudet", "station"]
const LEGACY_PLANETS := ["paprika", "brudet"]
const BRUDET_ARRIVAL := Vector2(1450, 706)
const MILITARY_ARRIVAL := Vector2(224, 384)
const MILITARY_BARRACKS_ARRIVAL := Vector2(256, 340)
const ARTICHOKE_ARRIVAL := Vector2(304, 134)
const POMIDOR_ARRIVAL := Vector2(976, 1102)
## Set on Artichoke when General Hickey promotes the player to Captain; it opens
## the flight to Pomidor.
const POMIDOR_UNLOCK_FLAG := "artichoke_captain"
const MILITARY_STAGES := ["none", "depot", "barracks", "run", "spar", "squad", "range", "cannon", "trap", "sleep", "graduated"]
const MILITARY_DRILLS := ["run", "spar", "squad", "range", "cannon", "trap"]
const MILITARY_TRAINING_WEAPONS := ["training_club", "training_bow"]
const MILITARY_CANNON_TARGETS := ["cannon_target_0", "cannon_target_1", "cannon_target_2"]
const MILITARY_CANNON_PHASES := ["empty", "carried", "loaded"]
const MILITARY_TRAP_STEPS := ["trap_0", "trap_1", "trap_2"]
const MILITARY_TRAP_ITEM := "practice_mine"
const CAMP_JOB := "bandit_camp"
const CAMP_IDS := ["camp_bandit_0", "camp_bandit_1", "camp_bandit_2"]
const ROAD_JOB := "road_cleanup"
const ROAD_IDS := ["zombie_260", "zombie_262", "zombie_264"]
const BRUDET_SOLO_HACKER_JOB := "brudet_hacker_solo"
const BRUDET_SOLO_HACKER_ID := "brudet_solo_hacker_0"
const PAPRIKA_TEAM_IDS := {"road_cleanup": ROAD_IDS, "bandit_camp": CAMP_IDS}
const BRUDET_TEAM_IDS := {
	"brudet_monster_team": ["brudet_team_monster_0", "brudet_team_monster_1", "brudet_team_monster_2"],
	"brudet_bandit_team": ["brudet_team_bandit_0", "brudet_team_bandit_1", "brudet_team_bandit_2"],
	"brudet_hacker_team": ["brudet_team_hacker_0"],
}
const SQUAD_ORDERS := ["follow", "hold", "attack"]
const RECOVERY_SECONDS := 30.0

var max_health: int = GameData.STARTING_MAX_HEALTH
var health: int = GameData.STARTING_MAX_HEALTH
var gold: int = 0
var inventory: Dictionary = {"stick": 1, "bread": 1}
var equipment: Dictionary = {"weapon": "stick", "armor": "", "clothing": ""}
var active_jobs: Dictionary = {}
var tracked_job_id: String = ""
var completed_unique_jobs: Array[String] = []
var camp_unlocked: bool = false
var player_position := Vector2(320, 220)
var current_planet := "paprika"
var planet_positions: Dictionary = {"paprika": [320.0, 220.0], "brudet": [BRUDET_ARRIVAL.x, BRUDET_ARRIVAL.y], "station": [MILITARY_ARRIVAL.x, MILITARY_ARRIVAL.y], "artichoke": [ARTICHOKE_ARRIVAL.x, ARTICHOKE_ARRIVAL.y], "pomidor": [POMIDOR_ARRIVAL.x, POMIDOR_ARRIVAL.y]}
var current_area := "exterior"
var military_barracks_position := [MILITARY_BARRACKS_ARRIVAL.x, MILITARY_BARRACKS_ARRIVAL.y]
var military_stage := "none"
var military_storage: Dictionary = {}
var military_stored_equipment: Dictionary = {"weapon": "", "armor": "", "clothing": ""}
var military_meal_credits := 0
var military_cannon_hits: Array[String] = []
var military_trap_progress := 0
var military_cannon_round_active := false
var military_cannon_phase := "empty"
var military_trap_round_active := false
var military_trap_equipped := false
var military_trap_mine_position: Array = []
var station_enlisted: bool:
	get:
		return military_stage != "none"
var station_graduated: bool:
	get:
		return military_stage == "graduated"
var training_stage: String:
	get:
		return military_stage
var canteen_credits: int:
	get:
		return military_meal_credits
var station_barracks_position: Array:
	get:
		return military_barracks_position
var field_regrowth: Dictionary = {}
var defeated_persistent_enemies: Array[String] = []
var play_seconds: float = 0.0
var fishing_ready_at: float = 0.0
var squad_recruits: Array[String] = []
var squad_members: Dictionary = {}
var squad_deployed := false
var controlled_member_id := "player"
var player_order := "follow"
var player_hold_position := [0.0, 0.0]
var camp_defeated_ids: Array[String] = []
var team_job_id := ""
var team_defeated_ids: Array[String] = []
var legacy_camp_roster := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	play_seconds += delta
	var ready_fields: Array[String] = []
	for field_id: String in field_regrowth:
		field_regrowth[field_id] = maxf(0.0, float(field_regrowth[field_id]) - delta)
		if float(field_regrowth[field_id]) <= 0.0:
			ready_fields.append(field_id)
	for field_id in ready_fields:
		field_regrowth.erase(field_id)
	var recovered := false
	for villager_id in squad_recruits:
		var member: Dictionary = squad_members.get(villager_id, {})
		if float(member.get("recover_until", 0.0)) > 0.0 and play_seconds >= float(member["recover_until"]):
			member["recover_until"] = 0.0
			member["health"] = int(member.get("max_health", 24))
			squad_members[villager_id] = member
			recovered = true
	if recovered:
		squad_changed.emit()

func start_new_game() -> void:
	max_health = GameData.STARTING_MAX_HEALTH
	health = max_health
	gold = 0
	inventory = {"stick": 1, "bread": 1}
	equipment = {"weapon": "stick", "armor": "", "clothing": ""}
	active_jobs.clear()
	tracked_job_id = ""
	completed_unique_jobs.clear()
	camp_unlocked = false
	player_position = Vector2(320, 220)
	current_planet = "paprika"
	planet_positions = {"paprika": [player_position.x, player_position.y], "brudet": [BRUDET_ARRIVAL.x, BRUDET_ARRIVAL.y], "station": [MILITARY_ARRIVAL.x, MILITARY_ARRIVAL.y], "artichoke": [ARTICHOKE_ARRIVAL.x, ARTICHOKE_ARRIVAL.y], "pomidor": [POMIDOR_ARRIVAL.x, POMIDOR_ARRIVAL.y]}
	current_area = "exterior"
	military_barracks_position = [MILITARY_BARRACKS_ARRIVAL.x, MILITARY_BARRACKS_ARRIVAL.y]
	military_stage = "none"
	military_storage.clear()
	military_stored_equipment = {"weapon": "", "armor": "", "clothing": ""}
	military_meal_credits = 0
	military_cannon_hits.clear()
	military_trap_progress = 0
	military_cannon_round_active = false
	military_cannon_phase = "empty"
	military_trap_round_active = false
	military_trap_equipped = false
	military_trap_mine_position.clear()
	field_regrowth.clear()
	defeated_persistent_enemies.clear()
	play_seconds = 0.0
	fishing_ready_at = 0.0
	squad_recruits.clear()
	squad_members.clear()
	squad_deployed = false
	controlled_member_id = "player"
	player_order = "follow"
	player_hold_position = [0.0, 0.0]
	camp_defeated_ids.clear()
	team_job_id = ""
	team_defeated_ids.clear()
	legacy_camp_roster = false
	_emit_all()

func travel_fare(destination: String) -> int:
	if current_planet == "brudet" and destination == "station":
		return 0
	if current_planet == "station" and destination == "brudet":
		return 0
	if current_planet == "station" and destination == "artichoke" or current_planet == "artichoke" and destination == "station":
		return 0
	if current_planet == "artichoke" and destination == "pomidor" or current_planet == "pomidor" and destination in ["artichoke", "brudet"]:
		return 0
	if current_planet == "paprika" and destination == "brudet":
		return GameData.TRAVEL_FARE
	if current_planet == "brudet" and destination == "paprika":
		return GameData.TRAVEL_FARE
	return -1

func can_travel(destination: String) -> bool:
	var fare := travel_fare(destination)
	if fare < 0:
		notify("That destination is unavailable.")
		return false
	if squad_deployed:
		notify("Finish the deployed squad mission before traveling.")
		return false
	if not squad_recruits.is_empty():
		notify("Dismiss your recruits before traveling.")
		return false
	if current_planet == "station" and (current_area != "exterior" or military_stage != "graduated"):
		notify("Finish training and sleep in the barracks before leaving the station.")
		return false
	if destination == "artichoke" and military_stage != "graduated":
		notify("Only graduated soldiers are sent to the Artichoke front.")
		return false
	if destination == "pomidor" and not defeated_persistent_enemies.has(POMIDOR_UNLOCK_FLAG):
		notify("Only officers sent by General Hickey fly to Pomidor.")
		return false
	if gold < fare:
		notify("You need %d gold to travel to %s." % [fare, destination.capitalize()])
		return false
	return true

func remember_player_position(position: Vector2) -> void:
	player_position = position
	if current_planet == "station" and current_area == "barracks":
		military_barracks_position = [position.x, position.y]
	else:
		planet_positions[current_planet] = [position.x, position.y]

func travel_to(destination: String, departure_position: Vector2) -> bool:
	if not can_travel(destination):
		return false
	var fare := travel_fare(destination)
	planet_positions[current_planet] = [departure_position.x, departure_position.y]
	current_planet = destination
	current_area = "exterior"
	if destination == "station" and military_stage == "none":
		military_stage = "depot"
		military_changed.emit()
	var arrival: Array = planet_positions[destination]
	player_position = Vector2(float(arrival[0]), float(arrival[1]))
	if fare > 0:
		gold -= fare
		gold_changed.emit(gold)
	return true

func enlist_military(departure_position: Vector2) -> bool:
	return travel_to("station", departure_position)

func return_from_military(departure_position: Vector2) -> bool:
	return travel_to("brudet", departure_position)

func enter_military_barracks(departure_position: Vector2) -> bool:
	if current_planet != "station" or current_area != "exterior":
		return false
	planet_positions["station"] = [departure_position.x, departure_position.y]
	current_area = "barracks"
	player_position = Vector2(float(military_barracks_position[0]), float(military_barracks_position[1]))
	military_changed.emit()
	return true

func exit_military_barracks(departure_position: Vector2) -> bool:
	if current_planet != "station" or current_area != "barracks":
		return false
	military_barracks_position = [departure_position.x, departure_position.y]
	current_area = "exterior"
	var arrival: Array = planet_positions["station"]
	player_position = Vector2(float(arrival[0]), float(arrival[1]))
	military_changed.emit()
	return true

func change_station_area(area: String, departure: Vector2) -> bool:
	if area == "barracks":
		return enter_military_barracks(departure)
	if area == "exterior":
		return exit_military_barracks(departure)
	return false

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		notify("You need %d gold." % amount)
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func add_item(item_id: String, amount: int = 1) -> bool:
	if not GameData.ITEMS.has(item_id) or amount <= 0:
		return false
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	inventory_changed.emit()
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	var owned := int(inventory.get(item_id, 0))
	if amount <= 0 or owned - amount < reserved_item_count(item_id):
		return false
	owned -= amount
	if owned == 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = owned
	inventory_changed.emit()
	return true

func buy_item(item_id: String) -> bool:
	var definition := GameData.item(item_id)
	if definition.is_empty() or int(definition.get("buy", 0)) <= 0:
		notify("That item is not for sale.")
		return false
	var price := int(definition["buy"])
	if gold < price:
		notify("You need %d gold for %s." % [price, definition["name"]])
		return false
	gold -= price
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	gold_changed.emit(gold)
	inventory_changed.emit()
	notify("Bought %s." % definition["name"])
	return true

func sell_item(item_id: String) -> bool:
	var definition := GameData.item(item_id)
	var price := int(definition.get("sell", 0))
	if definition.is_empty() or price <= 0 or not remove_item(item_id):
		notify("You cannot sell that item.")
		return false
	add_gold(price)
	notify("Sold %s for %d gold." % [definition["name"], price])
	return true

func equip_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) <= 0:
		notify("You do not own that item.")
		return false
	var definition := GameData.item(item_id)
	var kind := String(definition.get("kind", ""))
	if equipment.get(kind, "") != item_id and reserved_item_count(item_id) >= int(inventory.get(item_id, 0)):
		notify("Each equipped item needs its own inventory copy.")
		return false
	if kind == "weapon":
		equipment["weapon"] = item_id
	elif kind == "armor":
		equipment["armor"] = item_id
	elif kind == "clothing":
		equipment["clothing"] = item_id
	else:
		return false
	equipment_changed.emit()
	notify("Equipped %s." % definition["name"])
	return true

func use_food(item_id: String) -> bool:
	var definition := GameData.item(item_id)
	if definition.get("kind", "") != "food" or health >= max_health:
		return false
	if not remove_item(item_id):
		return false
	health = mini(max_health, health + int(definition.get("heal", 0)))
	health_changed.emit(health, max_health)
	notify("Bandaged your wounds." if item_id == "bandage" else "Ate %s." % definition["name"])
	return true

func military_claim_uniform() -> bool:
	if current_planet != "station" or current_area != "exterior" or military_stage != "depot":
		return false
	# The depot issues one uniform per enlistment history, not one per visit.
	if int(inventory.get("military_uniform", 0)) != 0 or military_storage.has("military_uniform"):
		return false
	inventory["military_uniform"] = 1
	military_stored_equipment["clothing"] = equipment.get("clothing", "")
	equipment["clothing"] = "military_uniform"
	military_stage = "barracks"
	inventory_changed.emit()
	equipment_changed.emit()
	military_changed.emit()
	return true

func military_store_gear() -> bool:
	if current_planet != "station" or current_area != "barracks" or military_stage != "barracks" or not military_storage.is_empty():
		return false
	if equipment.get("clothing", "") != "military_uniform" or int(inventory.get("military_uniform", 0)) != 1 or not squad_recruits.is_empty():
		return false
	var stored: Dictionary = {}
	for item_id in inventory:
		if item_id == "military_uniform":
			continue
		if item_id == MILITARY_TRAP_ITEM or MILITARY_TRAINING_WEAPONS.has(item_id) or reserved_item_count(String(item_id)) > int(inventory[item_id]):
			return false
		stored[item_id] = inventory[item_id]
	military_storage = stored
	military_stored_equipment["weapon"] = equipment.get("weapon", "")
	military_stored_equipment["armor"] = equipment.get("armor", "")
	inventory = {"military_uniform": 1}
	equipment = {"weapon": "", "armor": "", "clothing": "military_uniform"}
	military_stage = "run"
	inventory_changed.emit()
	equipment_changed.emit()
	military_changed.emit()
	return true

func military_withdraw_gear() -> bool:
	if current_planet != "station" or current_area != "barracks" or military_stage != "graduated" or military_storage.is_empty():
		return false
	for item_id in military_storage:
		inventory[item_id] = int(inventory.get(item_id, 0)) + int(military_storage[item_id])
	military_storage.clear()
	for slot in ["weapon", "armor", "clothing"]:
		equipment[slot] = military_stored_equipment[slot]
	military_stored_equipment = {"weapon": "", "armor": "", "clothing": ""}
	inventory_changed.emit()
	equipment_changed.emit()
	military_changed.emit()
	return true

func _military_weapon_for_stage(stage: String) -> String:
	if stage in ["spar", "squad"]:
		return "training_club"
	if stage == "range":
		return "training_bow"
	return ""

func military_training_weapon() -> bool:
	if current_planet != "station" or current_area != "exterior" or MILITARY_STAGES.find(military_stage) < MILITARY_STAGES.find("run") or military_stage == "graduated":
		return false
	if inventory.get("military_uniform", 0) != 1 or equipment.get("clothing", "") != "military_uniform":
		return false
	var expected := _military_weapon_for_stage(military_stage)
	var equipped := String(equipment.get("weapon", ""))
	if not equipped.is_empty() and not MILITARY_TRAINING_WEAPONS.has(equipped):
		return false
	for item_id in MILITARY_TRAINING_WEAPONS:
		var owned := int(inventory.get(item_id, 0))
		if owned != (1 if equipped == item_id else 0):
			return false
	if equipped == expected:
		return true
	if not equipped.is_empty():
		inventory.erase(equipped)
	if not expected.is_empty():
		inventory[expected] = 1
	equipment["weapon"] = expected
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func _military_training_ready() -> bool:
	if current_planet != "station" or current_area != "exterior" or equipment.get("clothing", "") != "military_uniform" or equipment.get("armor", "") != "":
		return false
	var expected := _military_weapon_for_stage(military_stage)
	if equipment.get("weapon", "") != expected:
		return false
	var expected_inventory: Dictionary = {"military_uniform": 1}
	if not expected.is_empty():
		expected_inventory[expected] = 1
	if military_stage == "trap" and military_trap_round_active and not military_trap_mine_placed():
		expected_inventory[MILITARY_TRAP_ITEM] = 1
	return inventory == expected_inventory

func _military_finish_drill(next_stage: String) -> void:
	military_stage = next_stage
	military_training_weapon()
	military_meal_credits += 1
	military_changed.emit()

func military_complete_drill(drill: String) -> bool:
	if not _military_training_ready() or not drill in ["run", "spar", "squad", "range"] or military_stage != drill:
		return false
	var next_stage: String = MILITARY_STAGES[MILITARY_STAGES.find(drill) + 1]
	_military_finish_drill(next_stage)
	return true

func military_start_cannon_round() -> bool:
	if not _military_training_ready() or military_stage != "cannon" or military_cannon_round_active:
		return false
	military_cannon_round_active = true
	military_cannon_phase = "empty"
	military_changed.emit()
	return true

func military_take_cannon_charge() -> bool:
	if not _military_training_ready() or military_stage != "cannon" or not military_cannon_round_active or military_cannon_phase != "empty":
		return false
	military_cannon_phase = "carried"
	military_changed.emit()
	return true

func military_load_cannon() -> bool:
	if not _military_training_ready() or military_stage != "cannon" or not military_cannon_round_active or military_cannon_phase != "carried":
		return false
	military_cannon_phase = "loaded"
	military_changed.emit()
	return true

func military_record_cannon_hit(target_id: String) -> bool:
	if not _military_training_ready() or military_stage != "cannon" or not military_cannon_round_active or military_cannon_phase != "loaded" or not MILITARY_CANNON_TARGETS.has(target_id) or military_cannon_hits.has(target_id):
		return false
	military_cannon_hits.append(target_id)
	military_cannon_phase = "empty"
	if military_cannon_hits.size() == MILITARY_CANNON_TARGETS.size():
		military_cannon_round_active = false
		_military_finish_drill("trap")
	else:
		military_changed.emit()
	return true

func military_start_trap_round() -> bool:
	if not _military_training_ready() or military_stage != "trap" or military_trap_round_active or military_trap_equipped or military_trap_mine_placed() or inventory.has(MILITARY_TRAP_ITEM):
		return false
	military_trap_round_active = true
	inventory[MILITARY_TRAP_ITEM] = 1
	inventory_changed.emit()
	military_changed.emit()
	return true

func military_equip_practice_mine(equipped: bool = true) -> bool:
	if not _military_training_ready() or military_stage != "trap" or not military_trap_round_active or military_trap_mine_placed() or int(inventory.get(MILITARY_TRAP_ITEM, 0)) != 1:
		return false
	if military_trap_equipped == equipped:
		return true
	military_trap_equipped = equipped
	equipment_changed.emit()
	military_changed.emit()
	return true

func military_place_practice_mine(position: Vector2) -> bool:
	if not _military_training_ready() or military_stage != "trap" or not military_trap_round_active or not military_trap_equipped or military_trap_mine_placed() or int(inventory.get(MILITARY_TRAP_ITEM, 0)) != 1 or not position.is_finite():
		return false
	inventory.erase(MILITARY_TRAP_ITEM)
	military_trap_mine_position = [position.x, position.y]
	military_trap_equipped = false
	inventory_changed.emit()
	equipment_changed.emit()
	military_changed.emit()
	return true

func military_trap_mine_placed() -> bool:
	return military_trap_round_active and _valid_point(military_trap_mine_position)

func military_restart_trap_round() -> bool:
	if not _military_training_ready() or military_stage != "trap" or not military_trap_round_active:
		return false
	var returned_mine := military_trap_mine_placed()
	if returned_mine:
		if inventory.has(MILITARY_TRAP_ITEM):
			return false
		inventory[MILITARY_TRAP_ITEM] = 1
		military_trap_mine_position.clear()
		military_trap_equipped = false
		inventory_changed.emit()
	equipment_changed.emit()
	military_changed.emit()
	return true

func military_record_trap_step(step_id: String) -> bool:
	if not _military_training_ready() or military_stage != "trap" or not military_trap_round_active or not military_trap_mine_placed() or military_trap_progress >= MILITARY_TRAP_STEPS.size() or MILITARY_TRAP_STEPS[military_trap_progress] != step_id:
		return false
	military_trap_progress += 1
	military_trap_round_active = false
	military_trap_equipped = false
	military_trap_mine_position.clear()
	if military_trap_progress == MILITARY_TRAP_STEPS.size():
		_military_finish_drill("sleep")
	else:
		military_changed.emit()
	return true

func military_eat_meal() -> bool:
	if current_planet != "station" or current_area != "exterior" or military_meal_credits <= 0:
		return false
	military_meal_credits -= 1
	# The canteen serves a meal rather than creating an inventory item.
	health = mini(max_health, health + 10)
	health_changed.emit(health, max_health)
	military_changed.emit()
	return true

func military_sleep() -> bool:
	if current_planet != "station" or current_area != "barracks" or not military_stage in ["sleep", "graduated"]:
		return false
	restore_health()
	military_stage = "graduated"
	military_changed.emit()
	return true

func issue_military_uniform() -> bool:
	return military_claim_uniform()

func store_military_belongings() -> bool:
	return military_store_gear()

func withdraw_military_belongings() -> bool:
	return military_withdraw_gear()

func redeem_military_meal() -> bool:
	return military_eat_meal()

func sleep_in_barracks() -> bool:
	return military_sleep()

func station_checkpoint_done(checkpoint_id: String) -> bool:
	if not MILITARY_DRILLS.has(checkpoint_id):
		return false
	return MILITARY_STAGES.find(military_stage) > MILITARY_STAGES.find(checkpoint_id)

func station_complete_checkpoint(checkpoint_id: String, result: Dictionary = {}) -> bool:
	if checkpoint_id in ["run", "spar", "squad", "range"]:
		return military_complete_drill(checkpoint_id)
	if checkpoint_id == "cannon":
		return military_record_cannon_hit(String(result.get("target_id", "")))
	if checkpoint_id == "trap":
		return military_record_trap_step(String(result.get("step_id", "")))
	return false

func heal_recruit(villager_id: String, item_id: String) -> bool:
	if not squad_recruits.has(villager_id) or recruit_recovering(villager_id):
		return false
	var member: Dictionary = squad_members[villager_id]
	var food := GameData.item(item_id)
	if food.get("kind", "") != "food" or int(member["health"]) >= int(member["max_health"]) or not remove_item(item_id):
		return false
	member["health"] = mini(int(member["max_health"]), int(member["health"]) + int(food.get("heal", 0)))
	squad_members[villager_id] = member
	squad_changed.emit()
	return true

func weapon_definition() -> Dictionary:
	return GameData.item(String(equipment.get("weapon", "stick")))

func armor_protection() -> int:
	var armor_id := String(equipment.get("armor", ""))
	return int(GameData.item(armor_id).get("protection", 0))

func damage_player(raw_damage: int) -> int:
	var applied := maxi(0, raw_damage - armor_protection())
	if applied == 0:
		notify("Your armor blocked the hit.")
		return 0
	health = maxi(0, health - applied)
	health_changed.emit(health, max_health)
	return applied

func restore_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func hacker_defeated() -> bool:
	for enemy_id in defeated_persistent_enemies:
		if enemy_id.begins_with("hacker_"):
			return true
	return false

func _clear_paprika_hacker_defeats() -> void:
	for enemy_id in defeated_persistent_enemies.duplicate():
		if enemy_id.begins_with("hacker_"):
			defeated_persistent_enemies.erase(enemy_id)


func team_planet(job_id: String) -> String:
	if PAPRIKA_TEAM_IDS.has(job_id):
		return "paprika"
	if BRUDET_TEAM_IDS.has(job_id):
		return "brudet"
	return ""

func team_recruit_region(job_id: String) -> String:
	return "south" if job_id == ROAD_JOB else ("north" if job_id == CAMP_JOB else "brudet")

func recruit_villager(villager_id: String, position: Vector2) -> bool:
	if team_job_id.is_empty() or not active_jobs.has(team_job_id) or current_planet != team_planet(team_job_id) or squad_deployed or squad_recruits.size() >= 2 or squad_recruits.has(villager_id) or not _valid_recruit_id(villager_id, current_planet):
		return false
	if current_planet == "paprika" and _paprika_recruit_region(villager_id) != team_recruit_region(team_job_id):
		return false
	squad_recruits.append(villager_id)
	squad_members[villager_id] = {
		"health": 24, "max_health": 24, "weapon": "militia_club", "armor": "",
		"order": "follow", "position": [position.x, position.y],
		"hold_position": [position.x, position.y], "recover_until": 0.0,
	}
	squad_changed.emit()
	return true

func dismiss_recruit(villager_id: String) -> bool:
	if squad_deployed or not squad_recruits.has(villager_id):
		return false
	squad_recruits.erase(villager_id)
	squad_members.erase(villager_id)
	squad_changed.emit()
	return true

func deploy_squad() -> bool:
	if team_job_id.is_empty() or not active_jobs.has(team_job_id) or current_planet != team_planet(team_job_id) or squad_deployed or squad_recruits.size() != 2:
		return false
	squad_deployed = true
	squad_changed.emit()
	notify("Squad assembled. Lead them to the forest bandit camp." if team_job_id == CAMP_JOB else "Squad assembled. Follow the mission markers and clear the targets.")
	return true

func set_controlled_member(member_id: String) -> bool:
	if member_id != "player":
		if not squad_deployed or not squad_recruits.has(member_id) or recruit_recovering(member_id):
			return false
	if controlled_member_id == member_id:
		return true
	controlled_member_id = member_id
	squad_changed.emit()
	return true

func set_squad_order(member_id: String, order: String, at: Vector2) -> bool:
	if not squad_deployed or not SQUAD_ORDERS.has(order) or (member_id != "player" and not squad_recruits.has(member_id)):
		return false
	if member_id == "player":
		player_order = order
		player_hold_position = [at.x, at.y]
	else:
		var member: Dictionary = squad_members[member_id]
		member["order"] = order
		member["hold_position"] = [at.x, at.y]
		squad_members[member_id] = member
	squad_changed.emit()
	return true

func recruit_recovering(villager_id: String) -> bool:
	var member: Dictionary = squad_members.get(villager_id, {})
	return int(member.get("health", 1)) <= 0 or float(member.get("recover_until", 0.0)) > play_seconds

func damage_recruit(villager_id: String, raw_damage: int) -> bool:
	if not squad_deployed or not squad_recruits.has(villager_id) or recruit_recovering(villager_id):
		return false
	var member: Dictionary = squad_members[villager_id]
	var protection := int(GameData.item(String(member.get("armor", ""))).get("protection", 0))
	var applied := maxi(0, raw_damage - protection)
	if applied == 0:
		return false
	member["health"] = maxi(0, int(member["health"]) - applied)
	if int(member["health"]) == 0:
		member["recover_until"] = play_seconds + RECOVERY_SECONDS
		member["order"] = "follow"
		if controlled_member_id == villager_id:
			controlled_member_id = "player"
		notify("%s is recovering in the city." % villager_id if current_planet == "brudet" else "%s is recovering in the village." % villager_id)
	squad_members[villager_id] = member
	squad_changed.emit()
	return true

func equip_recruit(villager_id: String, slot: String, item_id: String) -> bool:
	if not squad_recruits.has(villager_id) or not slot in ["weapon", "armor"]:
		return false
	if not item_id.is_empty() and String(GameData.item(item_id).get("kind", "")) != slot:
		return false
	if slot == "weapon" and item_id.is_empty():
		item_id = "militia_club"
	var member: Dictionary = squad_members[villager_id]
	if member[slot] == item_id:
		return true
	if item_id != "militia_club" and not item_id.is_empty() and reserved_item_count(item_id) >= int(inventory.get(item_id, 0)):
		if int(inventory.get(item_id, 0)) <= 0 or equipment.get(slot, "") != item_id:
			notify("Each equipped item needs its own inventory copy.")
			return false
		equipment[slot] = ""
		equipment_changed.emit()
	member[slot] = item_id
	squad_members[villager_id] = member
	squad_changed.emit()
	inventory_changed.emit()
	return true

func reserved_item_count(item_id: String) -> int:
	var count := 0
	for equipped in equipment.values():
		if equipped == item_id:
			count += 1
	for villager_id in squad_recruits:
		for slot in ["weapon", "armor"]:
			if squad_members[villager_id][slot] == item_id:
				count += 1
	return count

func record_camp_defeat(enemy_id: String) -> bool:
	if not squad_deployed or team_job_id != CAMP_JOB or not active_jobs.has(CAMP_JOB) or not CAMP_IDS.has(enemy_id) or camp_defeated_ids.has(enemy_id):
		return false
	camp_defeated_ids.append(enemy_id)
	if not defeated_persistent_enemies.has(enemy_id):
		defeated_persistent_enemies.append(enemy_id)
	active_jobs[CAMP_JOB] = camp_defeated_ids.size()
	job_changed.emit()
	if active_job_ready(CAMP_JOB):
		notify("Camp cleared. Return to the northern mercenary center for your reward.")
	return true

func record_road_defeat(enemy_id: String) -> bool:
	if not squad_deployed or team_job_id != ROAD_JOB or not active_jobs.has(ROAD_JOB) or not ROAD_IDS.has(enemy_id) or team_defeated_ids.has(enemy_id):
		return false
	team_defeated_ids.append(enemy_id)
	active_jobs[ROAD_JOB] = team_defeated_ids.size()
	job_changed.emit()
	if active_job_ready(ROAD_JOB):
		notify("Road cleared. Return to the first-village mercenary center for your reward.")
	return true

func record_solo_hacker_defeat(enemy_id: String) -> bool:
	if enemy_id != BRUDET_SOLO_HACKER_ID or current_planet != "brudet" or not active_jobs.has(BRUDET_SOLO_HACKER_JOB) or not team_job_id.is_empty() or active_job_ready(BRUDET_SOLO_HACKER_JOB):
		return false
	active_jobs[BRUDET_SOLO_HACKER_JOB] = 1
	job_changed.emit()
	notify("Teleporting hacker defeated. Return to Brudet Town Hall for your reward.")
	return true


func record_team_defeat(enemy_id: String) -> bool:
	if not squad_deployed or not BRUDET_TEAM_IDS.has(team_job_id) or not active_jobs.has(team_job_id):
		return false
	if not BRUDET_TEAM_IDS[team_job_id].has(enemy_id) or team_defeated_ids.has(enemy_id):
		return false
	team_defeated_ids.append(enemy_id)
	active_jobs[team_job_id] = team_defeated_ids.size()
	job_changed.emit()
	if active_job_ready(team_job_id):
		notify("Cleanup complete. Return to Brudet Town Hall for your reward.")
	return true

func _release_squad() -> void:
	team_job_id = ""
	team_defeated_ids.clear()
	legacy_camp_roster = false
	squad_deployed = false
	squad_recruits.clear()
	squad_members.clear()
	controlled_member_id = "player"
	player_order = "follow"
	player_hold_position = [0.0, 0.0]
	squad_changed.emit()

func _valid_recruit_id(villager_id: String, planet: String) -> bool:
	var parts := villager_id.split("_")
	if planet == "brudet":
		if parts.size() != 4 or parts[0] != "villager" or parts[1] != "river" or not String(parts[2]).is_valid_int() or not String(parts[3]).is_valid_int():
			return false
		var index := int(parts[2])
		return index >= 1 and index <= 30 and parts[2] == "%02d" % index and int(parts[3]) == index + 44
	if planet != "paprika" or parts.size() != 2 or not String(parts[1]).is_valid_int():
		return false
	if parts[0] == "resident":
		return int(parts[1]) >= 0 and int(parts[1]) <= 25 and parts[1] == "%02d" % int(parts[1])
	var object_id := int(parts[1])
	return object_id >= 37 and object_id <= 50 and parts[0] == "villager%d" % ((object_id - 37) % 6 + 1)

func _paprika_recruit_region(villager_id: String) -> String:
	if not _valid_recruit_id(villager_id, "paprika"):
		return ""
	if villager_id.begins_with("resident_") and villager_id != "resident_00":
		return "north"
	return "south"

func accept_job(job_id: String) -> bool:
	var definition := GameData.job(job_id)
	if definition.is_empty():
		return false
	if job_id == "brudet_hacker_team":
		notify("That squad mission is no longer offered. Ask for the solo hacker bounty instead.")
		return false
	if bool(definition.get("team", false)) and (not team_job_id.is_empty() or active_jobs.has(BRUDET_SOLO_HACKER_JOB) or current_planet != team_planet(job_id)):
		notify("Finish or abandon your current solo hacker or squad mission first." if not team_job_id.is_empty() or active_jobs.has(BRUDET_SOLO_HACKER_JOB) else "This squad mission belongs on another planet.")
		return false
	if job_id == BRUDET_SOLO_HACKER_JOB and (current_planet != "brudet" or not team_job_id.is_empty()):
		notify("Visit Brudet without an active squad mission for the solo hacker bounty.")
		return false
	if job_id == CAMP_JOB and not camp_unlocked:
		notify("Clear the marked forest road zombies and claim that reward to unlock the bandit camp mission.")
		return false
	if job_id == "hacker_bounty" and not completed_unique_jobs.has(CAMP_JOB) and not active_jobs.has(job_id):
		notify("Claim the bandit camp reward before accepting the hacker bounty.")
		return false
	if active_jobs.has(job_id):
		notify("That job is already active.")
		return false
	if not bool(definition.get("repeatable", false)) and completed_unique_jobs.has(job_id):
		notify("That job is already complete.")
		return false
	if job_id == "hacker_bounty":
		_clear_paprika_hacker_defeats()
	active_jobs[job_id] = 0
	tracked_job_id = job_id
	if bool(definition.get("team", false)):
		team_job_id = job_id
		team_defeated_ids.clear()
	job_changed.emit()
	var hint := String(definition.get("location_hint", ""))
	notify("Accepted: %s. %s" % [definition["name"], hint] if not hint.is_empty() else "Accepted: %s" % definition["name"])
	return true

func track_job(job_id: String) -> bool:
	if not active_jobs.has(job_id):
		return false
	tracked_job_id = job_id
	job_changed.emit()
	notify("Tracking: %s" % GameData.job(job_id).get("name", job_id))
	return true

func abandon_job(job_id: String = "") -> void:
	var selected := job_id if not job_id.is_empty() else tracked_job_id
	if not active_jobs.has(selected):
		return
	if selected == team_job_id:
		if squad_deployed:
			notify("The squad mission cannot be abandoned after deployment.")
			return
		_release_squad()
		if selected == CAMP_JOB:
			camp_defeated_ids.clear()
	if selected == "hacker_bounty":
		_clear_paprika_hacker_defeats()
	active_jobs.erase(selected)
	if tracked_job_id == selected:
		tracked_job_id = String(active_jobs.keys()[0]) if not active_jobs.is_empty() else ""
	job_changed.emit()
	notify("Job abandoned: %s" % GameData.job(selected).get("name", selected))

func record_event(event_name: String, amount: int = 1) -> bool:
	if current_planet == "station" or event_name in ["camp_bandit_defeated", "team_target_defeated"] or amount <= 0:
		return false
	var matched := false
	for job_id: String in active_jobs.keys():
		var definition := GameData.job(job_id)
		if String(definition.get("event", "")) != event_name or job_id == BRUDET_SOLO_HACKER_JOB:
			continue
		if (definition.get("issuer", "") in ["mercenary", "north_mercenary"] and current_planet != "paprika") or (definition.get("issuer", "") == "river_town_hall" and current_planet != "brudet"):
			continue
		matched = true
		var target := int(definition.get("target", 1))
		var before := int(active_jobs[job_id])
		active_jobs[job_id] = mini(target, before + amount)
		if before < target and int(active_jobs[job_id]) >= target:
			notify("%s complete. Return for your reward." % definition["name"])
	if matched:
		job_changed.emit()
	return matched

func active_job_ready(job_id: String = "") -> bool:
	var selected := job_id if not job_id.is_empty() else tracked_job_id
	if not active_jobs.has(selected):
		return false
	return int(active_jobs[selected]) >= int(GameData.job(selected).get("target", 1))

func claim_job(issuer: String, job_id: String = "") -> bool:
	var selected := job_id if not job_id.is_empty() else tracked_job_id
	var expected_ids: Array = PAPRIKA_TEAM_IDS.get(selected, BRUDET_TEAM_IDS.get(selected, []))
	var defeated_count := camp_defeated_ids.size() if selected == CAMP_JOB else team_defeated_ids.size()
	if not active_job_ready(selected) or (selected == team_job_id and (not squad_deployed or defeated_count != expected_ids.size())):
		notify("The job is not ready to claim.")
		return false
	var definition := GameData.job(selected)
	if String(definition.get("issuer", "")) != issuer:
		notify("Return to the place that issued this job.")
		return false
	var reward := int(definition.get("reward", 0))
	if not bool(definition.get("repeatable", false)):
		completed_unique_jobs.append(selected)
	active_jobs.erase(selected)
	if tracked_job_id == selected:
		tracked_job_id = String(active_jobs.keys()[0]) if not active_jobs.is_empty() else ""
	if selected == team_job_id:
		_release_squad()
	if selected == ROAD_JOB:
		camp_unlocked = true
	add_gold(reward)
	job_changed.emit()
	notify("%s: %d gold earned." % [definition["name"], reward])
	return true

func job_summary(job_id: String = "") -> String:
	var selected := job_id if not job_id.is_empty() else tracked_job_id
	if not active_jobs.has(selected):
		return "No active job"
	var definition := GameData.job(selected)
	return "%s  %d/%d (%d active)" % [definition.get("name", selected), int(active_jobs[selected]), int(definition.get("target", 1)), active_jobs.size()]

func mark_field_harvested(field_id: String) -> void:
	field_regrowth[field_id] = GameData.FIELD_REGROWTH_SECONDS

func field_is_ready(field_id: String) -> bool:
	return not field_regrowth.has(field_id)

func field_seconds_remaining(field_id: String) -> float:
	return float(field_regrowth.get(field_id, 0.0))

func notify(message: String) -> void:
	notification_requested.emit(message)

func save_game() -> bool:
	if current_planet == "station" and current_area == "barracks":
		military_barracks_position = [player_position.x, player_position.y]
	else:
		planet_positions[current_planet] = [player_position.x, player_position.y]
	var data := {
		"schema": SAVE_SCHEMA,
		"current_planet": current_planet,
		"planet_positions": planet_positions,
		"current_area": current_area,
		"military_barracks_position": military_barracks_position,
		"military_stage": military_stage,
		"military_storage": military_storage,
		"military_stored_equipment": military_stored_equipment,
		"military_meal_credits": military_meal_credits,
		"military_cannon_hits": military_cannon_hits,
		"military_trap_progress": military_trap_progress,
		"military_cannon_round_active": military_cannon_round_active,
		"military_cannon_phase": military_cannon_phase,
		"military_trap_round_active": military_trap_round_active,
		"military_trap_equipped": military_trap_equipped,
		"military_trap_mine_position": military_trap_mine_position,
		"health": health,
		"max_health": max_health,
		"gold": gold,
		"inventory": inventory,
		"equipment": equipment,
		"active_jobs": active_jobs,
		"tracked_job_id": tracked_job_id,
		"completed_unique_jobs": completed_unique_jobs,
		"camp_unlocked": camp_unlocked,
		"player_position": [player_position.x, player_position.y],
		"field_regrowth": field_regrowth,
		"defeated_persistent_enemies": defeated_persistent_enemies,
		"play_seconds": play_seconds,
		"fishing_ready_at": fishing_ready_at,
		"squad_recruits": squad_recruits,
		"squad_members": squad_members,
		"squad_deployed": squad_deployed,
		"controlled_member_id": controlled_member_id,
		"player_order": player_order,
		"player_hold_position": player_hold_position,
		"camp_defeated_ids": camp_defeated_ids,
		"team_job_id": team_job_id,
		"team_defeated_ids": team_defeated_ids,
		"legacy_camp_roster": legacy_camp_roster,
	}
	var json_text := JSON.stringify(data, "\t")
	var temp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		notify("Could not write the save file.")
		save_finished.emit(false)
		return false
	file.store_string(json_text)
	file.flush()
	file.close()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(temp_path))
	if not _valid_save(parsed):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		notify("Save validation failed.")
		save_finished.emit(false)
		return false
	var global_save := ProjectSettings.globalize_path(SAVE_PATH)
	var global_backup := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	var global_temp := ProjectSettings.globalize_path(temp_path)
	var had_primary := FileAccess.file_exists(SAVE_PATH)
	if had_primary:
		if FileAccess.file_exists(SAVE_BACKUP_PATH) and DirAccess.remove_absolute(global_backup) != OK:
			notify("Could not replace the backup save.")
			save_finished.emit(false)
			return false
		if DirAccess.rename_absolute(global_save, global_backup) != OK:
			notify("Could not preserve the previous save.")
			save_finished.emit(false)
			return false
	var success := DirAccess.rename_absolute(global_temp, global_save) == OK
	if not success and had_primary:
		DirAccess.rename_absolute(global_backup, global_save)
	notify("Game saved." if success else "Could not finish saving the game.")
	save_finished.emit(success)
	return success

func _migrate_old_paprika_layout(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	if int(migrated["schema"]) >= PLANET_SAVE_SCHEMA:
		var positions: Dictionary = migrated["planet_positions"]
		positions["paprika"] = _migrate_old_paprika_point(positions["paprika"])
	if int(migrated["schema"]) < PLANET_SAVE_SCHEMA or String(migrated.get("current_planet", "paprika")) == "paprika":
		migrated["player_position"] = _migrate_old_paprika_point(migrated["player_position"])
	if int(migrated["schema"]) >= SQUAD_SAVE_SCHEMA:
		for villager_id in migrated["squad_members"]:
			var member: Dictionary = migrated["squad_members"][villager_id]
			member["position"] = _migrate_old_paprika_point(member["position"])
			member["hold_position"] = _migrate_old_paprika_point(member["hold_position"])
		migrated["player_hold_position"] = _migrate_old_paprika_point(migrated["player_hold_position"])
	var timers: Dictionary = {}
	for field_id in migrated["field_regrowth"]:
		var new_id := String(field_id)
		var parts := new_id.split(":")
		if parts.size() == 3 and parts[0] == "paprika" and parts[1].is_valid_int() and parts[2].is_valid_int() and int(parts[2]) >= PAPRIKA_OLD_SOUTH_ROW:
			new_id = "paprika:%s:%d" % [parts[1], int(parts[2]) + PAPRIKA_FIELD_ROW_SHIFT]
		timers[new_id] = migrated["field_regrowth"][field_id]
	migrated["field_regrowth"] = timers
	return migrated

func _migrate_old_paprika_point(point: Array) -> Array:
	var x := float(point[0])
	var y := float(point[1])
	# Players could stand beside the old work-office door just above the inserted rows.
	var near_old_work_office := x >= 712.0 and x <= 808.0 and y >= 330.0 and y < PAPRIKA_OLD_SOUTH_Y
	return [x, y + PAPRIKA_LAYOUT_SHIFT] if y >= PAPRIKA_OLD_SOUTH_Y or near_old_work_office else point.duplicate()

func load_game() -> bool:
	var source := SAVE_PATH
	if not FileAccess.file_exists(source):
		source = SAVE_BACKUP_PATH
	if not FileAccess.file_exists(source):
		notify("No save file exists yet.")
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not _valid_save(data) and FileAccess.file_exists(SAVE_BACKUP_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_BACKUP_PATH))
	if not _valid_save(data):
		notify("The save file is invalid.")
		return false
	if int(data["schema"]) < PAPRIKA_LAYOUT_SCHEMA:
		data = _migrate_old_paprika_layout(data)
	max_health = maxi(1, int(data.get("max_health", GameData.STARTING_MAX_HEALTH)))
	health = clampi(int(data.get("health", max_health)), 0, max_health)
	gold = maxi(0, int(data.get("gold", 0)))
	inventory = data.get("inventory", {"stick": 1}).duplicate(true)
	for item_id in inventory:
		inventory[item_id] = int(inventory[item_id])
	equipment = data.get("equipment", {"weapon": "stick", "armor": "", "clothing": ""}).duplicate(true)
	active_jobs.clear()
	if int(data.get("schema", -1)) == 1:
		var legacy_job := String(data.get("active_job_id", ""))
		if not legacy_job.is_empty():
			active_jobs[legacy_job] = int(data.get("active_job_progress", 0))
		tracked_job_id = legacy_job
	else:
		for job_id in data.get("active_jobs", {}):
			active_jobs[job_id] = int(data["active_jobs"][job_id])
		tracked_job_id = String(data.get("tracked_job_id", ""))
	completed_unique_jobs.clear()
	for job_id in data.get("completed_unique_jobs", []):
		completed_unique_jobs.append(String(job_id))
	var pos: Array = data.get("player_position", [320, 220])
	player_position = Vector2(float(pos[0]), float(pos[1])) if pos.size() >= 2 else Vector2(320, 220)
	current_planet = String(data.get("current_planet", "paprika"))
	planet_positions = data.get("planet_positions", {"paprika": [player_position.x, player_position.y], "brudet": [BRUDET_ARRIVAL.x, BRUDET_ARRIVAL.y]}).duplicate(true)
	if int(data["schema"]) < STATION_SAVE_SCHEMA:
		planet_positions["station"] = [MILITARY_ARRIVAL.x, MILITARY_ARRIVAL.y]
	if int(data["schema"]) < ARTICHOKE_SAVE_SCHEMA:
		planet_positions["artichoke"] = [ARTICHOKE_ARRIVAL.x, ARTICHOKE_ARRIVAL.y]
	if int(data["schema"]) < POMIDOR_SAVE_SCHEMA:
		planet_positions["pomidor"] = [POMIDOR_ARRIVAL.x, POMIDOR_ARRIVAL.y]
	current_area = String(data.get("current_area", "exterior"))
	military_barracks_position = data.get("military_barracks_position", [MILITARY_BARRACKS_ARRIVAL.x, MILITARY_BARRACKS_ARRIVAL.y]).duplicate()
	military_stage = String(data.get("military_stage", "none"))
	military_storage = data.get("military_storage", {}).duplicate(true)
	for item_id in military_storage:
		military_storage[item_id] = int(military_storage[item_id])
	military_stored_equipment = data.get("military_stored_equipment", {"weapon": "", "armor": "", "clothing": ""}).duplicate(true)
	military_meal_credits = int(data.get("military_meal_credits", 0))
	military_cannon_hits.clear()
	for target_id in data.get("military_cannon_hits", []):
		military_cannon_hits.append(String(target_id))
	military_trap_progress = int(data.get("military_trap_progress", 0))
	if int(data["schema"]) >= MILITARY_ROUND_SAVE_SCHEMA:
		military_cannon_round_active = bool(data["military_cannon_round_active"])
		military_cannon_phase = String(data["military_cannon_phase"])
		military_trap_round_active = bool(data["military_trap_round_active"])
		military_trap_equipped = bool(data["military_trap_equipped"])
		military_trap_mine_position = data["military_trap_mine_position"].duplicate()
	else:
		military_cannon_round_active = false
		military_cannon_phase = "empty"
		military_trap_round_active = false
		military_trap_equipped = false
		military_trap_mine_position.clear()
	if current_area == "exterior":
		planet_positions[current_planet] = [player_position.x, player_position.y]
	field_regrowth = data.get("field_regrowth", {}).duplicate(true)
	defeated_persistent_enemies.clear()
	for enemy_id in data.get("defeated_persistent_enemies", []):
		defeated_persistent_enemies.append(String(enemy_id))
	camp_unlocked = bool(data["camp_unlocked"]) if int(data["schema"]) >= CAMP_UNLOCK_SAVE_SCHEMA else (hacker_defeated() or active_jobs.has(CAMP_JOB) or completed_unique_jobs.has(CAMP_JOB))
	play_seconds = maxf(0.0, float(data.get("play_seconds", 0.0)))
	fishing_ready_at = float(data.get("fishing_ready_at", 0.0))
	squad_recruits.clear()
	for villager_id in data.get("squad_recruits", []):
		squad_recruits.append(String(villager_id))
	squad_members = data.get("squad_members", {}).duplicate(true)
	squad_deployed = bool(data.get("squad_deployed", false))
	controlled_member_id = String(data.get("controlled_member_id", "player"))
	player_order = String(data.get("player_order", "follow"))
	player_hold_position = data.get("player_hold_position", [0.0, 0.0]).duplicate()
	camp_defeated_ids.clear()
	for enemy_id in data.get("camp_defeated_ids", []):
		camp_defeated_ids.append(String(enemy_id))
	team_job_id = String(data.get("team_job_id", CAMP_JOB if active_jobs.has(CAMP_JOB) else ""))
	team_defeated_ids.clear()
	for enemy_id in data.get("team_defeated_ids", []):
		team_defeated_ids.append(String(enemy_id))
	legacy_camp_roster = bool(data.get("legacy_camp_roster", false))
	if int(data["schema"]) < BRUDET_TEAM_SAVE_SCHEMA and current_planet == "brudet" and not squad_recruits.is_empty():
		_release_squad()
		team_job_id = CAMP_JOB if active_jobs.has(CAMP_JOB) else ""
	if int(data["schema"]) < PAPRIKA_LOCAL_RECRUIT_SCHEMA and team_job_id == CAMP_JOB and current_planet == "paprika":
		for villager_id in squad_recruits.duplicate():
			if _paprika_recruit_region(villager_id) == "north":
				continue
			if squad_deployed:
				legacy_camp_roster = true
			else:
				squad_recruits.erase(villager_id)
				squad_members.erase(villager_id)
	_emit_all()
	notify("Game loaded.")
	return true

func _valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var schema = data.get("schema", -1)
	if not _is_number(schema) or float(schema) != float(int(schema)) or int(schema) not in [1, 2, SQUAD_SAVE_SCHEMA, PLANET_SAVE_SCHEMA, PAPRIKA_LAYOUT_SCHEMA, BRUDET_TEAM_SAVE_SCHEMA, PAPRIKA_LOCAL_RECRUIT_SCHEMA, CAMP_UNLOCK_SAVE_SCHEMA, STATION_SAVE_SCHEMA, MILITARY_ROUND_SAVE_SCHEMA, ARTICHOKE_SAVE_SCHEMA, POMIDOR_SAVE_SCHEMA]:
		return false
	schema = int(schema)
	var item_counts = data.get("inventory", null)
	var gear = data.get("equipment", null)
	var location = data.get("player_position", null)
	var timers = data.get("field_regrowth", null)
	if not item_counts is Dictionary or not gear is Dictionary or not location is Array or not timers is Dictionary:
		return false
	if location.size() != 2 or not _is_number(location[0]) or not _is_number(location[1]):
		return false
	if schema >= PLANET_SAVE_SCHEMA:
		var planet = data.get("current_planet", null)
		var positions = data.get("planet_positions", null)
		var allowed_planets: Array = PLANETS if schema >= POMIDOR_SAVE_SCHEMA else ARTICHOKE_PLANETS if schema >= ARTICHOKE_SAVE_SCHEMA else STATION_PLANETS if schema >= STATION_SAVE_SCHEMA else LEGACY_PLANETS
		if not planet is String or not allowed_planets.has(planet) or not positions is Dictionary or positions.size() != allowed_planets.size():
			return false
		for planet_id in allowed_planets:
			if not positions.has(planet_id) or not _valid_point(positions[planet_id]):
				return false
		if schema < BRUDET_TEAM_SAVE_SCHEMA and planet == "brudet" and data.get("squad_deployed", false):
			return false
		var fishing_time = data.get("fishing_ready_at", null)
		if not _is_number(fishing_time) or float(fishing_time) < 0.0:
			return false
	for number_field in ["health", "max_health", "gold", "play_seconds"]:
		if not _is_number(data.get(number_field, null)) or float(data[number_field]) < 0.0:
			return false
	if float(data["max_health"]) < 1.0 or float(data["health"]) > float(data["max_health"]):
		return false
	for item_id in item_counts:
		if not GameData.ITEMS.has(item_id) or not _is_number(item_counts[item_id]) or float(item_counts[item_id]) < 0.0:
			return false
		if schema >= STATION_SAVE_SCHEMA and float(item_counts[item_id]) != float(int(item_counts[item_id])):
			return false
	for slot in ["weapon", "armor", "clothing"]:
		var equipped = gear.get(slot, null)
		if not equipped is String or (not equipped.is_empty() and (not GameData.ITEMS.has(equipped) or int(item_counts.get(equipped, 0)) < 1)):
			return false
	var jobs: Dictionary = {}
	var tracked: String = ""
	if schema == 1:
		var legacy_job = data.get("active_job_id", null)
		var legacy_progress = data.get("active_job_progress", null)
		if not legacy_job is String or not _is_number(legacy_progress) or float(legacy_progress) < 0.0:
			return false
		if not legacy_job.is_empty():
			jobs[legacy_job] = legacy_progress
			tracked = legacy_job
		elif float(legacy_progress) != 0.0:
			return false
	else:
		var saved_jobs = data.get("active_jobs", null)
		var saved_tracking = data.get("tracked_job_id", null)
		if not saved_jobs is Dictionary or not saved_tracking is String:
			return false
		jobs = saved_jobs
		tracked = saved_tracking
	if not tracked.is_empty() and not jobs.has(tracked):
		return false
	if tracked.is_empty() and not jobs.is_empty():
		return false
	for job_id in jobs:
		var progress = jobs[job_id]
		if (schema < SQUAD_SAVE_SCHEMA and job_id == CAMP_JOB) or (schema < BRUDET_TEAM_SAVE_SCHEMA and BRUDET_TEAM_IDS.has(job_id)) or (schema < PAPRIKA_LOCAL_RECRUIT_SCHEMA and job_id == ROAD_JOB) or (schema < CAMP_UNLOCK_SAVE_SCHEMA and job_id == BRUDET_SOLO_HACKER_JOB):
			return false
		if not job_id is String or not GameData.JOBS.has(job_id) or not _is_number(progress):
			return false
		if float(progress) < 0.0 or float(progress) > float(GameData.job(job_id).get("target", 0)) or float(progress) != float(int(progress)):
			return false
	for field_id in timers:
		if not field_id is String or not _is_number(timers[field_id]) or float(timers[field_id]) < 0.0:
			return false
	var unique_jobs = data.get("completed_unique_jobs", null)
	var defeated = data.get("defeated_persistent_enemies", null)
	if not unique_jobs is Array or not defeated is Array:
		return false
	if schema >= CAMP_UNLOCK_SAVE_SCHEMA and not data.get("camp_unlocked", null) is bool:
		return false
	for completed_id in unique_jobs:
		if not completed_id is String or not GameData.JOBS.has(completed_id):
			return false
		if (schema < SQUAD_SAVE_SCHEMA and completed_id == CAMP_JOB) or (schema < CAMP_UNLOCK_SAVE_SCHEMA and completed_id == BRUDET_SOLO_HACKER_JOB):
			return false
		if jobs.has(completed_id) and not bool(GameData.job(completed_id).get("repeatable", false)):
			return false
	for enemy_id in defeated:
		if not enemy_id is String:
			return false
	if schema >= SQUAD_SAVE_SCHEMA and not _valid_squad_save(data, jobs, item_counts, gear):
		return false
	if schema >= STATION_SAVE_SCHEMA and not _valid_military_save(data, item_counts, gear):
		return false
	return true

func _valid_military_save(data: Dictionary, item_counts: Dictionary, gear: Dictionary) -> bool:
	var schema := int(data["schema"])
	var cannon_round_active := false
	var cannon_phase := "empty"
	var trap_round_active := false
	var trap_equipped := false
	var trap_position: Array = []
	if schema >= MILITARY_ROUND_SAVE_SCHEMA:
		var saved_cannon_active = data.get("military_cannon_round_active", null)
		var saved_cannon_phase = data.get("military_cannon_phase", null)
		var saved_trap_active = data.get("military_trap_round_active", null)
		var saved_trap_equipped = data.get("military_trap_equipped", null)
		var saved_trap_position = data.get("military_trap_mine_position", null)
		if not saved_cannon_active is bool or not saved_cannon_phase is String or not saved_trap_active is bool or not saved_trap_equipped is bool or not saved_trap_position is Array:
			return false
		cannon_round_active = saved_cannon_active
		cannon_phase = saved_cannon_phase
		trap_round_active = saved_trap_active
		trap_equipped = saved_trap_equipped
		trap_position = saved_trap_position
		if not MILITARY_CANNON_PHASES.has(cannon_phase) or (not trap_position.is_empty() and not _valid_point(trap_position)):
			return false
	elif item_counts.has(MILITARY_TRAP_ITEM):
		return false
	var trap_mine_placed := not trap_position.is_empty()
	var has_held_trap_mine := item_counts.has(MILITARY_TRAP_ITEM) and int(item_counts[MILITARY_TRAP_ITEM]) == 1
	var stage = data.get("military_stage", null)
	var area = data.get("current_area", null)
	var storage = data.get("military_storage", null)
	var stored_gear = data.get("military_stored_equipment", null)
	var credits = data.get("military_meal_credits", null)
	var hits = data.get("military_cannon_hits", null)
	var trap = data.get("military_trap_progress", null)
	if not stage is String or not MILITARY_STAGES.has(stage) or not area is String or not area in ["exterior", "barracks"]:
		return false
	if not _valid_point(data.get("military_barracks_position", null)) or not storage is Dictionary or not stored_gear is Dictionary or stored_gear.size() != 3:
		return false
	if not _is_number(credits) or float(credits) != float(int(credits)) or int(credits) < 0 or not hits is Array or not _is_number(trap) or float(trap) != float(int(trap)) or int(trap) < 0 or int(trap) > MILITARY_TRAP_STEPS.size():
		return false
	var stage_index := MILITARY_STAGES.find(stage)
	var drills_done := clampi(stage_index - MILITARY_STAGES.find("run"), 0, MILITARY_DRILLS.size())
	if int(credits) > drills_done:
		return false
	if stage == "none" and (data["current_planet"] == "station" or area != "exterior"):
		return false
	if stage != "none" and stage != "graduated" and data["current_planet"] != "station":
		return false
	if area == "barracks" and data["current_planet"] != "station":
		return false
	if data["current_planet"] == "artichoke" and stage != "graduated":
		return false
	if data["current_planet"] == "pomidor" and not Array(data.get("defeated_persistent_enemies", [])).has(POMIDOR_UNLOCK_FLAG):
		return false
	if schema >= MILITARY_ROUND_SAVE_SCHEMA:
		if (not cannon_round_active and cannon_phase != "empty") or (cannon_round_active and stage != "cannon") or (stage != "cannon" and cannon_phase != "empty"):
			return false
		if (stage != "cannon" and cannon_round_active) or (trap_round_active and stage != "trap") or (stage != "trap" and (trap_round_active or trap_equipped or trap_mine_placed)):
			return false
		if trap_equipped and (not trap_round_active or trap_mine_placed or not has_held_trap_mine):
			return false
		if trap_round_active:
			if trap_mine_placed:
				if item_counts.has(MILITARY_TRAP_ITEM) or trap_equipped:
					return false
			elif not has_held_trap_mine:
				return false
		elif item_counts.has(MILITARY_TRAP_ITEM):
			return false
	if stage == "none" and (not storage.is_empty() or item_counts.has("military_uniform") or credits != 0):
		return false
	for item_id in storage:
		if item_id in ["military_uniform", MILITARY_TRAP_ITEM] or MILITARY_TRAINING_WEAPONS.has(item_id) or not GameData.ITEMS.has(item_id) or not _is_number(storage[item_id]) or float(storage[item_id]) != float(int(storage[item_id])) or int(storage[item_id]) <= 0:
			return false
	for slot in ["weapon", "armor", "clothing"]:
		var equipped = stored_gear.get(slot, null)
		if not equipped is String or MILITARY_TRAINING_WEAPONS.has(equipped) or (not equipped.is_empty() and (not GameData.ITEMS.has(equipped) or GameData.item(equipped).get("kind", "") != slot)):
			return false
		if not equipped.is_empty():
			var from_storage: bool = stage_index >= MILITARY_STAGES.find("run") and not (stage == "graduated" and storage.is_empty())
			var personal: Dictionary = storage if from_storage else item_counts
			if int(personal.get(equipped, 0)) < 1:
				return false
	if stage in ["none", "depot"] or (stage == "graduated" and storage.is_empty()):
		if stored_gear != {"weapon": "", "armor": "", "clothing": ""}:
			return false
	if stage == "depot" and (not storage.is_empty() or item_counts.has("military_uniform")):
		return false
	if stage == "barracks" and not storage.is_empty():
		return false
	if stage_index >= MILITARY_STAGES.find("barracks") and stage != "graduated":
		if int(item_counts.get("military_uniform", 0)) != 1 or gear.get("clothing", "") != "military_uniform":
			return false
	var expected_training_weapon := _military_weapon_for_stage(stage)
	if stage == "graduated" or stage_index < MILITARY_STAGES.find("run"):
		expected_training_weapon = ""
	for item_id in MILITARY_TRAINING_WEAPONS:
		if int(item_counts.get(item_id, 0)) != (1 if item_id == expected_training_weapon else 0) or (item_counts.has(item_id) and item_id != expected_training_weapon):
			return false
	if stage == "graduated" and MILITARY_TRAINING_WEAPONS.has(gear.get("weapon", "")):
		return false
	if stage_index >= MILITARY_STAGES.find("run") and stage != "graduated":
		var expected_inventory_size := 1 if expected_training_weapon.is_empty() else 2
		if schema >= MILITARY_ROUND_SAVE_SCHEMA and stage == "trap" and trap_round_active and has_held_trap_mine:
			expected_inventory_size += 1
		if item_counts.size() != expected_inventory_size or gear.get("weapon", "") != expected_training_weapon or gear.get("armor", "") != "":
			return false
	var expected_hits: int = 0 if stage_index < MILITARY_STAGES.find("cannon") else (MILITARY_CANNON_TARGETS.size() if stage_index > MILITARY_STAGES.find("cannon") else hits.size())
	if hits.size() != expected_hits or (stage == "cannon" and hits.size() >= MILITARY_CANNON_TARGETS.size()):
		return false
	var seen_hits: Dictionary = {}
	for target_id in hits:
		if not target_id is String or not MILITARY_CANNON_TARGETS.has(target_id) or seen_hits.has(target_id):
			return false
		seen_hits[target_id] = true
	if stage_index < MILITARY_STAGES.find("trap") and int(trap) != 0 or stage == "trap" and int(trap) >= MILITARY_TRAP_STEPS.size() or stage_index > MILITARY_STAGES.find("trap") and int(trap) != MILITARY_TRAP_STEPS.size():
		return false
	return true

func _valid_squad_save(data: Dictionary, jobs: Dictionary, item_counts: Dictionary, gear: Dictionary) -> bool:
	var recruits = data.get("squad_recruits", null)
	var members = data.get("squad_members", null)
	var deployed = data.get("squad_deployed", null)
	var controlled = data.get("controlled_member_id", null)
	var order = data.get("player_order", null)
	var hold = data.get("player_hold_position", null)
	var casualties = data.get("camp_defeated_ids", null)
	if not recruits is Array or not members is Dictionary or not deployed is bool or not controlled is String or not order is String or not _valid_point(hold) or not casualties is Array:
		return false
	if recruits.size() > 2 or recruits.size() != members.size() or not SQUAD_ORDERS.has(order):
		return false
	var schema := int(data["schema"])
	var team_id = data.get("team_job_id", CAMP_JOB if jobs.has(CAMP_JOB) else "")
	var team_ids = data.get("team_defeated_ids", [])
	if schema >= BRUDET_TEAM_SAVE_SCHEMA and (not team_id is String or not team_ids is Array):
		return false
	if schema >= PAPRIKA_LOCAL_RECRUIT_SCHEMA and not data.get("legacy_camp_roster", null) is bool:
		return false
	if schema >= BRUDET_TEAM_SAVE_SCHEMA:
		var active_team_jobs := 0
		for job_id in jobs:
			if bool(GameData.job(job_id).get("team", false)):
				active_team_jobs += 1
		if active_team_jobs > 1 or (not team_id.is_empty()) != (active_team_jobs == 1):
			return false
		if schema >= CAMP_UNLOCK_SAVE_SCHEMA and jobs.has(BRUDET_SOLO_HACKER_JOB) and active_team_jobs > 0:
			return false
		if not team_id.is_empty() and (not jobs.has(team_id) or not bool(GameData.job(team_id).get("team", false))):
			return false
		if not team_id.is_empty() and (deployed or not recruits.is_empty()) and String(data["current_planet"]) != team_planet(team_id):
			return false
		if deployed and (team_id.is_empty() or recruits.size() != 2):
			return false
		if team_id.is_empty() and (not recruits.is_empty() or deployed):
			return false
	else:
		if deployed and (not jobs.has(CAMP_JOB) or recruits.size() != 2):
			return false
		if not jobs.has(CAMP_JOB) and (not recruits.is_empty() or deployed):
			return false
	if schema >= PAPRIKA_LOCAL_RECRUIT_SCHEMA and bool(data["legacy_camp_roster"]) and (team_id != CAMP_JOB or not deployed):
		return false
	if jobs.has(CAMP_JOB) or data["completed_unique_jobs"].has(CAMP_JOB):
		if schema >= CAMP_UNLOCK_SAVE_SCHEMA:
			if not data["camp_unlocked"]:
				return false
		else:
			var hacker_found := false
			for enemy_id in data["defeated_persistent_enemies"]:
				if String(enemy_id).begins_with("hacker_"):
					hacker_found = true
			if not hacker_found:
				return false
	if controlled != "player" and (not deployed or not recruits.has(controlled)):
		return false
	var reserved: Dictionary = {}
	for item_id in gear.values():
		if item_id != "":
			reserved[item_id] = int(reserved.get(item_id, 0)) + 1
	for villager_id in recruits:
		if not villager_id is String or not _valid_recruit_id(villager_id, "paprika" if schema < BRUDET_TEAM_SAVE_SCHEMA else String(data["current_planet"])) or not members.has(villager_id):
			return false
		if schema >= PAPRIKA_LOCAL_RECRUIT_SCHEMA and String(data["current_planet"]) == "paprika" and _paprika_recruit_region(villager_id) != team_recruit_region(team_id) and not bool(data["legacy_camp_roster"]):
			return false
		var member = members[villager_id]
		if not member is Dictionary or not _valid_point(member.get("position", null)) or not _valid_point(member.get("hold_position", null)):
			return false
		if not _is_number(member.get("health", null)) or not _is_number(member.get("max_health", null)) or not _is_number(member.get("recover_until", null)):
			return false
		if float(member["max_health"]) < 1.0 or float(member["health"]) < 0.0 or float(member["health"]) > float(member["max_health"]) or float(member["recover_until"]) < 0.0:
			return false
		if float(member["health"]) != float(int(member["health"])) or float(member["max_health"]) != float(int(member["max_health"])):
			return false
		if (int(member["health"]) == 0 and float(member["recover_until"]) <= 0.0) or (int(member["health"]) > 0 and float(member["recover_until"]) > float(data["play_seconds"])):
			return false
		if not SQUAD_ORDERS.has(member.get("order", null)):
			return false
		for slot in ["weapon", "armor"]:
			var item_id = member.get(slot, null)
			if not item_id is String or (slot == "weapon" and item_id.is_empty()):
				return false
			if item_id == "militia_club" and slot == "weapon":
				continue
			if not item_id.is_empty():
				if String(GameData.item(item_id).get("kind", "")) != slot:
					return false
				reserved[item_id] = int(reserved.get(item_id, 0)) + 1
		if controlled == villager_id and (int(member["health"]) <= 0 or float(member["recover_until"]) > float(data["play_seconds"])):
			return false
	for item_id in reserved:
		if int(reserved[item_id]) > int(item_counts.get(item_id, 0)):
			return false
	if casualties.size() > CAMP_IDS.size() or (not jobs.has(CAMP_JOB) and not casualties.is_empty() and not data["completed_unique_jobs"].has(CAMP_JOB)):
		return false
	var seen: Dictionary = {}
	for enemy_id in casualties:
		if not enemy_id is String or not CAMP_IDS.has(enemy_id) or seen.has(enemy_id):
			return false
		seen[enemy_id] = true
	if jobs.has(CAMP_JOB) and (int(jobs[CAMP_JOB]) != casualties.size() or (not deployed and not casualties.is_empty())):
		return false
	if data["completed_unique_jobs"].has(CAMP_JOB) and casualties.size() != CAMP_IDS.size():
		return false
	for enemy_id in CAMP_IDS:
		if data["defeated_persistent_enemies"].has(enemy_id) != casualties.has(enemy_id):
			return false
	if schema >= BRUDET_TEAM_SAVE_SCHEMA:
		if team_id == CAMP_JOB or team_id.is_empty():
			if not team_ids.is_empty():
				return false
		else:
			var expected_ids: Array = BRUDET_TEAM_IDS.get(team_id, ROAD_IDS if team_id == ROAD_JOB and schema >= PAPRIKA_LOCAL_RECRUIT_SCHEMA else [])
			if expected_ids.is_empty() or team_ids.size() > expected_ids.size() or not deployed and not team_ids.is_empty():
				return false
			var seen_team: Dictionary = {}
			for enemy_id in team_ids:
				if not enemy_id is String or not expected_ids.has(enemy_id) or seen_team.has(enemy_id):
					return false
				seen_team[enemy_id] = true
			if int(jobs[team_id]) != team_ids.size():
				return false
	return true

func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _is_number(value[0]) and _is_number(value[1])

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _emit_all() -> void:
	health_changed.emit(health, max_health)
	gold_changed.emit(gold)
	inventory_changed.emit()
	equipment_changed.emit()
	job_changed.emit()
	military_changed.emit()
