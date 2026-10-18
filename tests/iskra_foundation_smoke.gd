extends Node

const Data = preload("res://scripts/world/iskra_investigation_data.gd")

class DamageProbe extends Node2D:
	var damage := 0
	func take_damage(amount: int, _source := Vector2.ZERO) -> void:
		damage += amount

var checks := 0
var failures := 0
var game: Node

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
	game.game_ui.cancel_scene()
	game.world.player.set_physics_process(false)
	_check(Data.valid_state({}), "old saves may omit investigation data")
	var state := {
		"version": 1, "site": "hall", "route": "pelican", "allies_faction": "pelican",
		"encounter": "squirrel", "assassin_phase": "escaped", "assassin_seconds": 3.25,
		"evidence_x": 2200.0, "evidence_y": 3000.0,
		"actors": {"assassin": {"x": 2200.0, "y": 3000.0, "health": 0, "alive": false, "down": false, "mode": "escaped", "seconds": 0},
			"pelican_ally_0": {"x": 224.0, "y": 3600.0, "health": 18, "alive": true, "down": false, "mode": "follow", "seconds": 0}},
	}
	_check(Data.valid_state(state), "complete typed encounter state is valid")
	for invalid in [null, [], 3, {"unknown": 1}, {"version": 2}, {"version": true}, {"site": "unknown"}, {"site": []}, {"route": "both"}, {"encounter": "owner"}, {"assassin_phase": "teleported"}, {"assassin_seconds": -1}, {"assassin_seconds": INF}, {"evidence_x": NAN}, {"evidence_y": 99999}, {"actors": []}, {"actors": {"nobody": {}}}, {"actors": {"assassin": {"damage": 500}}}, {"actors": {"assassin": {"health": -1}}}, {"actors": {"assassin": {"health": INF}}}, {"actors": {"assassin": {"down": 1}}}, {"actors": {"assassin": {"mode": "unknown"}}}]:
		if invalid is Dictionary and not invalid.has("version"):
			invalid["version"] = Data.VERSION
		_check(not Data.valid_state(invalid), "reject malformed investigation state " + str(invalid))
	_check(not Data.valid_state({"site": "hall"}), "populated state requires a version")
	_check(Data.valid_state({"version": 1}), "empty versioned state is valid")
	for outside in [{"evidence_x": Data.MAP_SIZE.x}, {"evidence_y": Data.MAP_SIZE.y}, {"evidence_x": -0.1}, {"actors": {"assassin": {"x": Data.MAP_SIZE.x}}}, {"actors": {"assassin": {"y": Data.MAP_SIZE.y}}}]:
		outside["version"] = Data.VERSION
		_check(not Data.valid_state(outside), "reject outside-map coordinates " + str(outside))
	var edge := {"version": 1, "evidence_x": Data.MAP_SIZE.x - 0.5, "evidence_y": Data.MAP_SIZE.y - 0.5}
	_check(Data.valid_state(edge), "finite coordinates strictly inside map remain valid")
	for item_id in GameData.ITEMS:
		var definition := GameData.item(item_id)
		if definition.get("kind", "") == "weapon" and item_id != "tvrdium_sword":
			var expected: int = {1: 4, 2: 10, 3: 24}.get(int(definition.get("power", 1)), 4)
			_check(GameData.weapon_damage(definition) == expected, "unchanged weapon damage: " + item_id)
	_check(GameData.weapon_damage(GameData.item("tvrdium_sword")) == 40, "tvrdium has real 40 damage rather than power fallback")
	var target := DamageProbe.new()
	game.world.actors_root.add_child(target)
	target.global_position = game.world.player.global_position + Vector2(8, 0)
	for item_id in ["wood_sword", "bronze_sword", "iron_sword", "tvrdium_sword"]:
		GameState.add_item(item_id)
		_check(GameState.equip_item(item_id), "equip " + item_id)
		target.damage = 0
		game.world.player._attack_cooldown = 0.0
		game.world.player._attack(target)
		_check(target.damage == GameData.weapon_damage(GameData.item(item_id)), "actual player attack uses " + item_id + " damage")
	GameState.iskra_investigation_state = state.duplicate(true)
	GameState.add_item(Data.ARMOR)
	_check(GameState.equip_item(Data.ARMOR), "equip the tvrdium armor Sena pays with")
	_check(GameState.armor_protection() == 5, "tvrdium armor stops five damage per hit, two more than iron")
	GameState.defeated_persistent_enemies.append(Data.FLAG_PREFIX + "equipment_issued")
	_check(GameState.save_game(), "new state and armor save successfully")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(GameState._valid_save(saved), "saved investigation validates after JSON round trip")
	GameState.iskra_investigation_state.clear()
	_check(GameState.load_game(), "load investigation save")
	_check(GameState.iskra_investigation_state == saved["iskra_investigation_state"], "load preserves all actor and route values")
	_check(GameState.inventory.get(Data.ARMOR, 0) == 1 and GameState.equipment.armor == Data.ARMOR, "issued armor remains owned and worn after load")
	_check(GameState.inventory.get("tvrdium_sword", 0) == 1, "a tvrdium sword from an older save stays valid")
	_check(GameState.defeated_persistent_enemies.has(Data.FLAG_PREFIX + "equipment_issued"), "equipment issue receipt persists independently of inventory")
	var before := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	GameState.iskra_investigation_state = {"version": 1, "route": "invalid"}
	_check(not GameState.save_game(), "invalid runtime state cannot overwrite a valid save")
	_check(FileAccess.get_file_as_string(GameState.SAVE_PATH) == before, "failed validation preserves previous save")
	var legacy := saved.duplicate(true)
	legacy.erase("iskra_investigation_state")
	_check(GameState._valid_save(legacy), "schema15 save without new optional field remains valid")
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameState.load_game() and GameState.iskra_investigation_state.is_empty(), "loading older save clears previous investigation runtime state")
	GameState.iskra_investigation_state = state.duplicate(true)
	GameState.start_new_game()
	_check(GameState.iskra_investigation_state.is_empty(), "new game clears investigation data")
	_finish()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])

func _finish() -> void:
	print("Iskra foundations: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
