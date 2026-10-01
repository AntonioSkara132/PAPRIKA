extends Node

signal health_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal inventory_changed
signal equipment_changed
signal job_changed
signal notification_requested(message: String)
signal save_finished(success: bool)

const SAVE_PATH := "user://paprika_save.json"
const SAVE_BACKUP_PATH := "user://paprika_save.backup.json"
const SAVE_SCHEMA := 2

var max_health: int = GameData.STARTING_MAX_HEALTH
var health: int = GameData.STARTING_MAX_HEALTH
var gold: int = 0
var inventory: Dictionary = {"stick": 1, "bread": 1}
var equipment: Dictionary = {"weapon": "stick", "armor": "", "clothing": ""}
var active_jobs: Dictionary = {}
var tracked_job_id: String = ""
var completed_unique_jobs: Array[String] = []
var player_position := Vector2(320, 220)
var field_regrowth: Dictionary = {}
var defeated_persistent_enemies: Array[String] = []
var play_seconds: float = 0.0

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

func start_new_game() -> void:
	max_health = GameData.STARTING_MAX_HEALTH
	health = max_health
	gold = 0
	inventory = {"stick": 1, "bread": 1}
	equipment = {"weapon": "stick", "armor": "", "clothing": ""}
	active_jobs.clear()
	tracked_job_id = ""
	completed_unique_jobs.clear()
	player_position = Vector2(320, 220)
	field_regrowth.clear()
	defeated_persistent_enemies.clear()
	play_seconds = 0.0
	_emit_all()

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
	if amount <= 0 or owned < amount:
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
	notify("Ate %s." % definition["name"])
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

func accept_job(job_id: String) -> bool:
	var definition := GameData.job(job_id)
	if definition.is_empty():
		return false
	if active_jobs.has(job_id):
		notify("That job is already active.")
		return false
	if not bool(definition.get("repeatable", false)) and completed_unique_jobs.has(job_id):
		notify("That job is already complete.")
		return false
	active_jobs[job_id] = 0
	tracked_job_id = job_id
	job_changed.emit()
	notify("Accepted: %s" % definition["name"])
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
	active_jobs.erase(selected)
	if tracked_job_id == selected:
		tracked_job_id = String(active_jobs.keys()[0]) if not active_jobs.is_empty() else ""
	job_changed.emit()
	notify("Job abandoned: %s" % GameData.job(selected).get("name", selected))

func record_event(event_name: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var matched := false
	for job_id: String in active_jobs.keys():
		var definition := GameData.job(job_id)
		if String(definition.get("event", "")) != event_name:
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
	if not active_job_ready(selected):
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
	var data := {
		"schema": SAVE_SCHEMA,
		"health": health,
		"max_health": max_health,
		"gold": gold,
		"inventory": inventory,
		"equipment": equipment,
		"active_jobs": active_jobs,
		"tracked_job_id": tracked_job_id,
		"completed_unique_jobs": completed_unique_jobs,
		"player_position": [player_position.x, player_position.y],
		"field_regrowth": field_regrowth,
		"defeated_persistent_enemies": defeated_persistent_enemies,
		"play_seconds": play_seconds,
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
	max_health = maxi(1, int(data.get("max_health", GameData.STARTING_MAX_HEALTH)))
	health = clampi(int(data.get("health", max_health)), 0, max_health)
	gold = maxi(0, int(data.get("gold", 0)))
	inventory = data.get("inventory", {"stick": 1}).duplicate(true)
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
	field_regrowth = data.get("field_regrowth", {}).duplicate(true)
	defeated_persistent_enemies.clear()
	for enemy_id in data.get("defeated_persistent_enemies", []):
		defeated_persistent_enemies.append(String(enemy_id))
	play_seconds = maxf(0.0, float(data.get("play_seconds", 0.0)))
	_emit_all()
	notify("Game loaded.")
	return true

func _valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var schema = data.get("schema", -1)
	if schema != 1 and schema != SAVE_SCHEMA:
		return false
	var item_counts = data.get("inventory", null)
	var gear = data.get("equipment", null)
	var location = data.get("player_position", null)
	var timers = data.get("field_regrowth", null)
	if not item_counts is Dictionary or not gear is Dictionary or not location is Array or not timers is Dictionary:
		return false
	if location.size() != 2 or not _is_number(location[0]) or not _is_number(location[1]):
		return false
	for number_field in ["health", "max_health", "gold", "play_seconds"]:
		if not _is_number(data.get(number_field, null)) or float(data[number_field]) < 0.0:
			return false
	if float(data["max_health"]) < 1.0 or float(data["health"]) > float(data["max_health"]):
		return false
	for item_id in item_counts:
		if not GameData.ITEMS.has(item_id) or not _is_number(item_counts[item_id]) or float(item_counts[item_id]) < 0.0:
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
	for completed_id in unique_jobs:
		if not completed_id is String or not GameData.JOBS.has(completed_id):
			return false
		if jobs.has(completed_id) and not bool(GameData.job(completed_id).get("repeatable", false)):
			return false
	for enemy_id in defeated:
		if not enemy_id is String:
			return false
	return true

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _emit_all() -> void:
	health_changed.emit(health, max_health)
	gold_changed.emit(gold)
	inventory_changed.emit()
	equipment_changed.emit()
	job_changed.emit()
