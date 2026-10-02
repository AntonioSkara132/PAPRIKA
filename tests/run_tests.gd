extends SceneTree

const GameStateScript := preload("res://scripts/state/game_state.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run("new game resets state", _test_new_game)
	_run("unaffordable purchase is atomic", _test_unaffordable_purchase)
	_run("buy and equip", _test_buy_and_equip)
	_run("armor reduces damage", _test_armor)
	_run("field regrowth", _test_field_regrowth)
	_run("field job pays once", _test_field_job)
	_run("five rabbits pay reward", _test_rabbit_job)
	_run("wrong event is ignored", _test_wrong_event)
	_run("wrong issuer cannot claim", _test_wrong_issuer)
	_run("unique hacker job cannot repeat", _test_unique_job)
	_run("multiple jobs progress independently", _test_simultaneous_jobs)
	_run("hacker defeat unlocks camp without bounty", _test_camp_unlock)
	_run("camp casualties are unique and reward pays once", _test_camp_casualties)
	_run("recruits, equipment and orders", _test_squad_equipment)
	_run("buy enough gear for two recruits", _test_buy_another_squad_gear)
	_run("downed recruit recovers", _test_recruit_recovery)
	_run("save migration and validation", _test_saves)
	_run("northern food and clothing", _test_northern_products)
	_run("travel fare is not an item purchase", _test_travel_fare)
	_run("planet travel and fare", _test_planet_travel)
	_run("deployed squad cannot travel", _test_deployed_travel)
	print("GameState: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _run(name: String, test: Callable) -> void:
	var failures_before := _failures
	test.call()
	print("%s %s" % ["PASS" if _failures == failures_before else "FAIL", name])


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("  FAIL: %s" % description)


func _test_new_game() -> void:
	var state := GameStateScript.new()
	state.gold = 99
	state.health = 1
	state.max_health = 30
	state.inventory = {"wood_sword": 2}
	state.equipment = {"weapon": "wood_sword", "armor": "wood_armor", "clothing": "red_tunic"}
	state.active_jobs = {"field_work": 4, "rabbit_catch": 1}
	state.tracked_job_id = "rabbit_catch"
	state.completed_unique_jobs.append("hacker_bounty")
	state.player_position = Vector2(7, 8)
	state.field_regrowth["plot"] = 50.0
	state.defeated_persistent_enemies.append("hacker")
	state.play_seconds = 70.0
	state.current_planet = "brudet"
	state.planet_positions["brudet"] = [7.0, 8.0]
	state.fishing_ready_at = 90.0
	state.start_new_game()
	_check(state.max_health == GameData.STARTING_MAX_HEALTH and state.health == state.max_health, "new game restores full starting health")
	_check(state.gold == 0 and state.inventory == {"stick": 1, "bread": 1}, "new game restores starting gold and inventory")
	_check(state.equipment == {"weapon": "stick", "armor": "", "clothing": ""}, "new game restores starting equipment")
	_check(state.active_jobs.is_empty() and state.tracked_job_id == "" and state.completed_unique_jobs.is_empty(), "new game clears jobs")
	_check(state.player_position == Vector2(320, 220) and state.field_regrowth.is_empty(), "new game resets position and regrowth")
	_check(state.defeated_persistent_enemies.is_empty() and state.play_seconds == 0.0, "new game clears enemy history and play time")
	_check(state.current_planet == "paprika" and state.planet_positions["brudet"] == [1450.0, 706.0] and state.fishing_ready_at == 0.0, "new game restores Paprika and resets the Brudet arrival and fishing cooldown")
	state.free()


func _test_unaffordable_purchase() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_gold(19)
	var before_inventory: Dictionary = state.inventory.duplicate(true)
	var before_equipment: Dictionary = state.equipment.duplicate(true)
	_check(not state.buy_item("wood_sword"), "cannot buy a 20-gold sword with 19 gold")
	_check(state.gold == 19 and state.inventory == before_inventory and state.equipment == before_equipment, "failed purchase leaves gold, inventory, and equipment unchanged")
	state.free()


func _test_buy_and_equip() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_gold(50)
	_check(state.buy_item("wood_sword"), "can buy a wooden sword")
	_check(state.gold == 30 and int(state.inventory.get("wood_sword", 0)) == 1, "purchase deducts 20 gold and adds one sword")
	_check(state.equip_item("wood_sword"), "owned sword can be equipped")
	_check(state.equipment["weapon"] == "wood_sword" and int(state.inventory.get("wood_sword", 0)) == 1, "equipped sword remains in inventory")
	state.free()


func _test_armor() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.add_item("wood_armor") and state.equip_item("wood_armor"), "wood armor can be added and equipped")
	_check(state.armor_protection() == 1, "wood armor protects against one damage")
	_check(state.damage_player(4) == 3 and state.health == 17, "four raw damage becomes three health loss")
	_check(state.damage_player(1) == 0 and state.health == 17, "armor blocks one raw damage completely")
	state.free()


func _test_field_regrowth() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.field_is_ready("plot_a") and state.field_is_ready("plot_b"), "untouched fields are ready")
	state.mark_field_harvested("plot_a")
	_check(not state.field_is_ready("plot_a") and is_equal_approx(state.field_seconds_remaining("plot_a"), GameData.FIELD_REGROWTH_SECONDS), "harvested field begins regrowth")
	state._process(45.0)
	_check(not state.field_is_ready("plot_a") and is_equal_approx(state.field_seconds_remaining("plot_a"), GameData.FIELD_REGROWTH_SECONDS - 45.0), "manual process reduces regrowth time")
	state._process(GameData.FIELD_REGROWTH_SECONDS - 45.0)
	_check(state.field_is_ready("plot_a") and state.field_seconds_remaining("plot_a") == 0.0 and state.field_is_ready("plot_b"), "field returns to ready without changing other fields")
	_check(is_equal_approx(state.play_seconds, GameData.FIELD_REGROWTH_SECONDS), "manual process advances play time")
	state.free()


func _test_field_job() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.accept_job("field_work"), "field job can be accepted")
	for i in range(4):
		_check(state.record_event("common_crop_harvested"), "field harvest %d counts" % (i + 1))
	_check(int(state.active_jobs.get(state.tracked_job_id, 0)) == 4 and not state.active_job_ready(), "four harvests are not enough")
	_check(state.record_event("common_crop_harvested") and state.active_job_ready(), "fifth harvest completes the job")
	state.record_event("common_crop_harvested")
	_check(int(state.active_jobs.get(state.tracked_job_id, 0)) == 5, "extra harvest does not exceed target")
	_check(state.claim_job("work_office"), "completed field job can be claimed")
	_check(state.gold == 10 and state.tracked_job_id == "", "field job awards exactly 10 gold and clears itself")
	_check(not state.claim_job("work_office") and state.gold == 10, "same completion cannot be claimed twice")
	state.free()


func _test_rabbit_job() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.accept_job("rabbit_catch"), "rabbit job can be accepted")
	for i in range(5):
		_check(state.record_event("rabbit_caught"), "rabbit %d counts" % (i + 1))
	_check(int(state.active_jobs.get(state.tracked_job_id, 0)) == 5 and state.active_job_ready(), "five rabbits complete the job")
	_check(state.claim_job("work_office") and state.gold == 25, "rabbit job awards 25 gold")
	state.free()


func _test_wrong_event() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.accept_job("field_work")
	_check(not state.record_event("rabbit_caught"), "rabbit event does not count for field job")
	_check(int(state.active_jobs.get(state.tracked_job_id, 0)) == 0 and not state.active_job_ready(), "unrelated event leaves field job at zero")
	state.free()


func _test_wrong_issuer() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.accept_job("forest_patrol")
	for i in range(3):
		state.record_event("monster_defeated")
	_check(state.active_job_ready(), "three defeated monsters complete patrol")
	_check(not state.claim_job("work_office"), "work office cannot pay mercenary patrol")
	_check(state.gold == 0 and state.tracked_job_id == "forest_patrol" and int(state.active_jobs.get(state.tracked_job_id, 0)) == 3, "wrong issuer leaves reward and progress unchanged")
	_check(state.claim_job("mercenary") and state.gold == 65, "mercenary pays patrol reward")
	state.free()


func _test_unique_job() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.accept_job("hacker_bounty"), "hacker bounty can be accepted")
	_check(state.record_event("hacker_defeated") and state.active_job_ready(), "hacker defeat completes bounty")
	_check(state.claim_job("mercenary") and state.gold == 500, "hacker bounty awards 500 gold")
	_check(state.completed_unique_jobs.has("hacker_bounty"), "claimed hacker bounty is recorded")
	_check(not state.accept_job("hacker_bounty") and state.tracked_job_id == "" and state.gold == 500, "hacker bounty cannot be accepted again")
	state.free()


func _test_simultaneous_jobs() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.accept_job("field_work") and state.accept_job("rabbit_catch") and state.accept_job("forest_patrol"), "jobs from two offices can be active together")
	_check(state.active_jobs.size() == 3 and state.tracked_job_id == "forest_patrol", "accepting a job keeps earlier jobs and tracks the new one")
	_check(not state.accept_job("field_work") and state.active_jobs.size() == 3, "the same job cannot be accepted twice")
	state.record_event("common_crop_harvested", 2)
	state.record_event("rabbit_caught", 5)
	_check(state.active_jobs == {"field_work": 2, "rabbit_catch": 5, "forest_patrol": 0}, "each event advances only its matching job")
	_check(state.active_job_ready("rabbit_catch") and not state.active_job_ready("field_work"), "an untracked job can be ready for payment")
	_check(not state.claim_job("mercenary", "rabbit_catch") and state.gold == 0, "mercenary office cannot pay a work-office job")
	_check(state.claim_job("work_office", "rabbit_catch") and state.gold == 25, "claiming one job pays it without dropping other jobs")
	_check(state.active_jobs == {"field_work": 2, "forest_patrol": 0} and state.tracked_job_id == "forest_patrol", "claiming an untracked job preserves tracked progress")
	_check(state.track_job("field_work") and state.tracked_job_id == "field_work", "player can choose a different tracked job")
	_check(not state.track_job("rabbit_catch") and state.tracked_job_id == "field_work", "a claimed job cannot be tracked")
	state.record_event("monster_defeated", 3)
	_check(state.active_job_ready("forest_patrol") and not state.active_job_ready("field_work"), "mercenary progress does not change the field job")
	state.abandon_job("field_work")
	_check(state.active_jobs == {"forest_patrol": 3} and state.tracked_job_id == "forest_patrol", "abandoning the tracked job keeps other jobs and chooses one to track")
	_check(state.claim_job("mercenary", "forest_patrol") and state.gold == 90 and state.active_jobs.is_empty() and state.tracked_job_id == "", "claiming the last job clears tracking")
	_check(state.accept_job("rabbit_catch") and state.active_jobs["rabbit_catch"] == 0, "repeatable jobs can be accepted again after payment")
	state.free()


func _test_camp_unlock() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(not state.accept_job(state.CAMP_JOB), "camp job is locked before defeating the hacker")
	state.defeated_persistent_enemies.append("hacker_forest")
	_check(not state.accept_job("hacker_bounty"), "hacker bounty cannot be accepted after defeating its target")
	_check(state.hacker_defeated() and state.accept_job(state.CAMP_JOB), "defeating the hacker unlocks the camp without accepting or claiming its bounty")
	_check(not state.completed_unique_jobs.has("hacker_bounty") and not state.active_jobs.has("hacker_bounty"), "camp unlock does not depend on bounty payment")
	state.free()


func _test_camp_casualties() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	_check(state.accept_job(state.CAMP_JOB), "unlocked camp mission can be accepted")
	_check(not state.record_camp_defeat(state.CAMP_IDS[0]) and not state.record_event("camp_bandit_defeated", 3), "camp kills cannot count before deployment or through generic events")
	_check(state.recruit_villager("resident_00", Vector2(830, 600)) and state.recruit_villager("resident_01", Vector2(845, 600)) and state.deploy_squad(), "two recruits allow camp deployment")
	_check(not state.claim_job("mercenary", state.CAMP_JOB), "camp reward cannot be claimed before the bandits are defeated")
	_check(not state.record_camp_defeat("bandit_forest") and not state.record_camp_defeat("unknown"), "other bandits cannot advance the camp mission")
	for index in state.CAMP_IDS.size():
		var enemy_id: String = state.CAMP_IDS[index]
		_check(state.record_camp_defeat(enemy_id), "unique camp bandit %d advances the mission" % (index + 1))
		_check(not state.record_camp_defeat(enemy_id) and int(state.active_jobs[state.CAMP_JOB]) == index + 1, "same camp bandit cannot count twice")
	_check(state.active_job_ready(state.CAMP_JOB) and state.camp_defeated_ids.size() == 3, "exactly three distinct camp kills complete the mission")
	_check(not state.claim_job("work_office", state.CAMP_JOB), "work office cannot pay the camp reward")
	var reward := int(GameData.job(state.CAMP_JOB)["reward"])
	_check(state.claim_job("mercenary", state.CAMP_JOB) and state.gold == reward, "mercenary pays the camp reward once")
	_check(not state.squad_deployed and state.squad_recruits.is_empty() and state.completed_unique_jobs.has(state.CAMP_JOB), "claiming releases the squad and records unique completion")
	_check(not state.claim_job("mercenary", state.CAMP_JOB) and not state.accept_job(state.CAMP_JOB) and state.gold == reward, "camp reward cannot be claimed or accepted a second time")
	state.free()


func _test_squad_equipment() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(not state.recruit_villager("resident_00", Vector2.ZERO) and not state.deploy_squad(), "recruitment and deployment require the camp mission")
	state.defeated_persistent_enemies.append("hacker_forest")
	state.accept_job(state.CAMP_JOB)
	_check(not state.recruit_villager("not_a_villager", Vector2.ZERO), "unknown villagers cannot join")
	_check(state._valid_recruit_id("resident_25") and not state._valid_recruit_id("resident_26"), "northern recruit IDs extend through resident_25")
	_check(state.recruit_villager("resident_00", Vector2(813, 610)), "first villager joins the squad")
	_check(not state.recruit_villager("resident_00", Vector2.ZERO) and not state.deploy_squad(), "same villager cannot join twice and one recruit cannot deploy")
	_check(state.recruit_villager("resident_01", Vector2(844, 613)) and not state.recruit_villager("resident_02", Vector2.ZERO), "squad holds exactly two distinct villagers")
	_check(state.dismiss_recruit("resident_01") and state.recruit_villager("resident_02", Vector2(840, 600)), "recruit can be replaced before deployment")
	_check(state.add_item("wood_sword") and state.equip_recruit("resident_00", "weapon", "wood_sword"), "first recruit can equip one owned sword")
	_check(state.reserved_item_count("wood_sword") == 1 and not state.equip_recruit("resident_02", "weapon", "wood_sword") and not state.equip_item("wood_sword"), "one sword cannot be equipped by several squad members")
	_check(not state.sell_item("wood_sword") and not state.remove_item("wood_sword"), "equipped sword cannot be sold or removed")
	_check(state.add_item("wood_sword") and state.equip_recruit("resident_02", "weapon", "wood_sword") and state.reserved_item_count("wood_sword") == 2, "second sword allows the other recruit to equip one")
	_check(state.add_item("wood_armor") and state.equip_recruit("resident_02", "armor", "wood_armor"), "owned armor can be assigned to a recruit")
	_check(not state.equip_recruit("resident_00", "armor", "wood_armor") and not state.equip_recruit("resident_00", "weapon", "wood_armor"), "armor requires a spare copy and cannot be assigned as a weapon")
	_check(state.deploy_squad() and not state.dismiss_recruit("resident_00"), "deployment locks the two-person roster")
	_check(state.set_controlled_member("resident_02") and state.controlled_member_id == "resident_02", "either recruit can be controlled")
	_check(state.set_squad_order("player", "hold", Vector2(12, 34)) and state.player_order == "hold" and state.player_hold_position == [12.0, 34.0], "player hold order remembers its location")
	_check(state.set_squad_order("resident_00", "attack", Vector2(44, 55)) and state.squad_members["resident_00"]["order"] == "attack", "recruit receives attack order")
	_check(not state.set_squad_order("resident_00", "invalid", Vector2.ZERO), "invalid orders are refused")
	state.free()


func _test_buy_another_squad_gear() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	state.accept_job(state.CAMP_JOB)
	_check(state.recruit_villager("resident_24", Vector2(1126, 390)) and state.recruit_villager("resident_25", Vector2(1250, 255)), "new northern residents can be recruited by stable ID")
	state.add_gold(750)
	_check(state.buy_item("iron_sword") and state.buy_item("iron_sword") and int(state.inventory.get("iron_sword", 0)) == 2, "iron swords can be bought twice")
	_check(state.equip_recruit("resident_24", "weapon", "iron_sword") and state.equip_recruit("resident_25", "weapon", "iron_sword"), "each recruit receives an independent iron sword")
	_check(state.reserved_item_count("iron_sword") == 2 and not state.equip_item("iron_sword") and not state.sell_item("iron_sword"), "two reserved copies cannot be reused by player or sold")
	_check(state.buy_item("iron_sword") and state.equip_item("iron_sword") and state.reserved_item_count("iron_sword") == 3, "buying a third sword equips the player without disarming recruits")
	state.free()


func _test_recruit_recovery() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	state.accept_job(state.CAMP_JOB)
	state.recruit_villager("resident_00", Vector2(813, 610))
	state.recruit_villager("resident_01", Vector2(844, 613))
	state.deploy_squad()
	_check(state.damage_recruit("resident_00", 5) and int(state.squad_members["resident_00"]["health"]) == 19, "recruit takes nonfatal damage")
	_check(state.heal_recruit("resident_00", "bread") and int(state.inventory.get("bread", 0)) == 0, "food heals recruit and consumes one inventory item")
	_check(state.set_controlled_member("resident_00") and state.damage_recruit("resident_00", 999), "controlled recruit can be downed")
	_check(state.recruit_recovering("resident_00") and state.controlled_member_id == "player", "downed recruit returns control to player")
	_check(not state.damage_recruit("resident_00", 1) and not state.heal_recruit("resident_00", "bread") and not state.set_controlled_member("resident_00"), "downed recruit cannot fight, eat or be controlled")
	state._process(state.RECOVERY_SECONDS - 0.1)
	_check(state.recruit_recovering("resident_00"), "recruit still recovers just before deadline")
	state._process(0.2)
	_check(not state.recruit_recovering("resident_00") and int(state.squad_members["resident_00"]["health"]) == int(state.squad_members["resident_00"]["max_health"]), "recruit returns at full health after recovery")
	_check(state.set_controlled_member("resident_00"), "recovered recruit can be controlled again")
	state.free()


func _test_saves() -> void:
	var original_xdg_home := OS.get_environment("XDG_DATA_HOME")
	var had_xdg_home := OS.has_environment("XDG_DATA_HOME")
	var had_custom_dir := ProjectSettings.has_setting("application/config/use_custom_user_dir")
	var old_custom_dir = ProjectSettings.get_setting("application/config/use_custom_user_dir", null)
	var had_custom_name := ProjectSettings.has_setting("application/config/custom_user_dir_name")
	var old_custom_name = ProjectSettings.get_setting("application/config/custom_user_dir_name", null)
	var original_save_path := ProjectSettings.globalize_path(GameStateScript.SAVE_PATH)
	var temp_root := OS.get_temp_dir().path_join("paprika-state-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	OS.set_environment("XDG_DATA_HOME", temp_root)
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "PaprikaGameState")
	var isolated_dir := OS.get_user_data_dir()
	var isolated_save := ProjectSettings.globalize_path(GameStateScript.SAVE_PATH)
	var isolated_backup := ProjectSettings.globalize_path(GameStateScript.SAVE_BACKUP_PATH)
	var isolated := isolated_dir.begins_with(temp_root + "/") and isolated_save.begins_with(isolated_dir + "/") and isolated_save != original_save_path
	_check(isolated, "save files resolve inside the temporary directory, not the normal user directory")
	if isolated:
		var directory_error := DirAccess.make_dir_recursive_absolute(isolated_dir)
		_check(directory_error == OK, "temporary save directory can be created")
		if directory_error == OK:
			var state := GameStateScript.new()
			state.start_new_game()
			state.gold = 42
			var save_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
			_check(save_file != null, "corrupt test save can be written")
			if save_file != null:
				save_file.store_string('{"schema": 1, "inventory": 42, "equipment": {}}')
				save_file.close()
				_check(not state.load_game() and state.gold == 42, "invalid inventory structure does not replace live state")
				var backup_file := FileAccess.open(GameStateScript.SAVE_BACKUP_PATH, FileAccess.WRITE)
				_check(backup_file != null, "invalid backup can be written")
				if backup_file != null:
					backup_file.store_string('{"schema": 999, "inventory": {}, "equipment": {}}')
					backup_file.close()
					_check(not state.load_game() and state.gold == 42, "wrong-schema backup does not replace live state")
			_test_save_migration(state)
			_test_planet_save(state)
			state.free()
		for path in [isolated_save, isolated_backup, isolated_save + ".tmp"]:
			if FileAccess.file_exists(path):
				_check(DirAccess.remove_absolute(path) == OK, "temporary save file is removed: %s" % path.get_file())
		_check(DirAccess.remove_absolute(isolated_dir) == OK, "temporary save directory is removed")
		_check(DirAccess.remove_absolute(temp_root) == OK, "temporary root directory is removed")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", old_custom_dir if had_custom_dir else null)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", old_custom_name if had_custom_name else null)
	if had_xdg_home:
		OS.set_environment("XDG_DATA_HOME", original_xdg_home)
	else:
		OS.unset_environment("XDG_DATA_HOME")
	_check(ProjectSettings.globalize_path(GameStateScript.SAVE_PATH) == original_save_path, "normal save path is restored after the test")


func _test_save_migration(state) -> void:
	var legacy_data := {
		"schema": 1,
		"health": 18, "max_health": 20, "gold": 42,
		"inventory": {"stick": 1, "bread": 1},
		"equipment": {"weapon": "stick", "armor": "", "clothing": ""},
		"active_job_id": "field_work", "active_job_progress": 3,
		"completed_unique_jobs": [], "player_position": [790, 615],
		"field_regrowth": {"paprika:51:26": 90.0, "paprika:54:11": 55.0, "brudet:3:30": 20.0}, "defeated_persistent_enemies": [], "play_seconds": 12.0,
	}
	var legacy_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(legacy_file != null, "schema-one save can be written in the isolated directory")
	if legacy_file == null:
		return
	legacy_file.store_string(JSON.stringify(legacy_data))
	legacy_file.close()
	_check(state.load_game() and state.active_jobs == {"field_work": 3} and state.tracked_job_id == "field_work", "schema-one job and progress migrate without being lost")
	_check(state.current_planet == "paprika" and state.player_position == Vector2(790, 1383) and state.planet_positions["paprika"] == [790.0, 1383.0] and state.fishing_ready_at == 0.0, "schema-one save moves the old southern position to the expanded map")
	_check(state.field_regrowth == {"paprika:51:74": 90.0, "paprika:54:11": 55.0, "brudet:3:30": 20.0}, "schema-one migration shifts southern field rows but keeps northern and Brudet field keys")
	_check(state.accept_job("rabbit_catch") and state.track_job("field_work"), "a second job can be added to a migrated save")
	state.record_event("rabbit_caught", 2)
	_check(state.save_game(), "saving a schema-one migration writes schema five")
	var saved_data = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	var saved_jobs: Dictionary = saved_data.get("active_jobs", {}) if saved_data is Dictionary else {}
	_check(saved_data is Dictionary and saved_data.get("schema") == 5 and saved_jobs.size() == 2 and int(saved_jobs.get("field_work", -1)) == 3 and int(saved_jobs.get("rabbit_catch", -1)) == 2 and saved_data.get("tracked_job_id") == "field_work", "schema-five save contains each job and tracked selection")
	_check(saved_data is Dictionary and saved_data.get("field_regrowth", {}).has("paprika:51:74") and not saved_data.get("field_regrowth", {}).has("paprika:51:122"), "schema-five field keys are not shifted twice on save")
	_check(saved_data is Dictionary and saved_data.get("squad_recruits") == [] and saved_data.get("squad_deployed") == false and saved_data.get("camp_defeated_ids") == [], "migration initializes empty squad and camp progress")
	var backup_data = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_BACKUP_PATH))
	_check(backup_data is Dictionary and backup_data.get("schema") == 1, "previous schema-one save stays in the backup")
	state.start_new_game()
	_check(state.load_game() and state.active_jobs == {"field_work": 3, "rabbit_catch": 2} and state.tracked_job_id == "field_work", "loading schema five restores both jobs and tracked selection")
	_check(state.player_position == Vector2(790, 1383) and state.field_regrowth.has("paprika:51:74") and not state.field_regrowth.has("paprika:51:122"), "reloading schema five does not shift the southern position or field again")
	if saved_data is Dictionary:
		var invalid_tracking: Dictionary = saved_data.duplicate(true)
		invalid_tracking["tracked_job_id"] = "hacker_bounty"
		_check(not state._valid_save(invalid_tracking), "tracking an inactive job is not accepted")
		var invalid_progress: Dictionary = saved_data.duplicate(true)
		invalid_progress["active_jobs"]["rabbit_catch"] = 6
		_check(not state._valid_save(invalid_progress), "job progress above its target is not accepted")
		var invalid_job: Dictionary = saved_data.duplicate(true)
		invalid_job["active_jobs"]["unknown_job"] = 0
		_check(not state._valid_save(invalid_job), "unknown jobs are not accepted")
	var invalid_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(invalid_file != null, "primary save can be corrupted in the isolated directory")
	if invalid_file != null:
		invalid_file.store_string('{"schema": 3, "active_jobs": "invalid"}')
		invalid_file.close()
		_check(state.load_game() and state.active_jobs == {"field_work": 3} and state.tracked_job_id == "field_work", "invalid primary loads the earlier schema-one backup")
	var schema_two: Dictionary = legacy_data.duplicate(true)
	schema_two["schema"] = 2
	schema_two.erase("active_job_id")
	schema_two.erase("active_job_progress")
	schema_two["active_jobs"] = {"field_work": 3, "rabbit_catch": 2}
	schema_two["tracked_job_id"] = "rabbit_catch"
	schema_two["player_position"] = [350, 240]
	var schema_two_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(schema_two_file != null, "schema-two fixture can be written")
	if schema_two_file == null:
		return
	schema_two_file.store_string(JSON.stringify(schema_two))
	schema_two_file.close()
	state.start_new_game()
	_check(state.load_game() and state.active_jobs == {"field_work": 3, "rabbit_catch": 2} and state.tracked_job_id == "rabbit_catch", "schema-two save restores simultaneous jobs")
	_check(state.squad_recruits.is_empty() and state.squad_members.is_empty() and not state.squad_deployed and state.controlled_member_id == "player" and state.camp_defeated_ids.is_empty(), "schema-two migration defaults to no squad or camp progress")
	_check(state.current_planet == "paprika" and state.player_position == Vector2(350, 240) and state.planet_positions["paprika"] == [350.0, 240.0] and state.fishing_ready_at == 0.0, "schema-two save keeps a northern Paprika position and has no fishing cooldown")
	_check(state.field_regrowth.has("paprika:51:74") and state.field_regrowth.has("paprika:54:11"), "schema-two migration shifts only fields south of row 21")
	_check(state.save_game(), "schema-two fixture can be saved as schema five")
	var migrated_two = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	var migrated_jobs: Dictionary = migrated_two.get("active_jobs", {}) if migrated_two is Dictionary else {}
	_check(migrated_two is Dictionary and migrated_two.get("schema") == 5 and migrated_two.get("tracked_job_id") == "rabbit_catch" and migrated_jobs.size() == 2 and int(migrated_jobs.get("field_work", -1)) == 3 and int(migrated_jobs.get("rabbit_catch", -1)) == 2, "schema-two jobs survive schema-five serialization")
	var previous_two = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_BACKUP_PATH))
	_check(previous_two is Dictionary and previous_two.get("schema") == 2, "schema-two source is kept in the backup")
	_test_schema_three_mission(state)


func _test_schema_three_mission(state) -> void:
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	_check(state.accept_job(state.CAMP_JOB), "schema-three mission fixture accepts the unlocked camp job")
	_check(state.recruit_villager("resident_00", Vector2(830, 600)) and state.recruit_villager("resident_25", Vector2(1250, 255)), "schema-three fixture retains old and northern stable recruit IDs")
	_check(state.add_item("wood_sword") and state.equip_recruit("resident_25", "weapon", "wood_sword") and state.deploy_squad() and state.record_camp_defeat(state.CAMP_IDS[0]), "schema-three fixture has equipped recruits and one camp casualty")
	state.player_position = Vector2(830, 600)
	state.planet_positions["paprika"] = [830.0, 600.0]
	state.field_regrowth = {"paprika:52:30": 60.0, "paprika:54:11": 45.0}
	_check(state.set_squad_order("player", "hold", Vector2(760, 340)) and state.set_squad_order("resident_00", "hold", Vector2(818, 610)) and state.set_squad_order("resident_25", "hold", Vector2(1250, 255)), "schema-three fixture records southern, office-approach and northern holds")
	_check(state.save_game(), "deployed squad fixture can be saved")
	var legacy = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if not legacy is Dictionary:
		_check(false, "deployed squad fixture is readable")
		return
	legacy["schema"] = 3
	legacy.erase("current_planet")
	legacy.erase("planet_positions")
	legacy.erase("fishing_ready_at")
	_check(state._valid_save(legacy), "schema-three deployed camp save remains valid")
	var file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "schema-three mission fixture can be written")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.start_new_game()
	_check(state.load_game() and state.squad_deployed and state.active_jobs.get(state.CAMP_JOB) == 1 and state.camp_defeated_ids == [state.CAMP_IDS[0]], "schema-three save restores a deployed midmission squad and camp progress")
	_check(state.squad_recruits == ["resident_00", "resident_25"] and state.squad_members["resident_25"]["weapon"] == "wood_sword" and state.inventory["wood_sword"] == 1, "schema-three save keeps recruit identities and reserved equipment")
	_check(state.current_planet == "paprika" and state.player_position == Vector2(830, 1368) and state.fishing_ready_at == 0.0, "schema-three save moves its southern player position and defaults to Paprika")
	_check(state.player_hold_position == [760.0, 1108.0] and state.squad_members["resident_00"]["position"] == [830.0, 1368.0] and state.squad_members["resident_00"]["hold_position"] == [818.0, 1378.0], "schema-three migration moves player and recruit holds, including the old office approach")
	_check(state.squad_members["resident_25"]["position"] == [1250.0, 255.0] and state.squad_members["resident_25"]["hold_position"] == [1250.0, 255.0], "schema-three migration keeps a northern recruit in place")
	_check(state.field_regrowth == {"paprika:52:78": 60.0, "paprika:54:11": 45.0}, "schema-three migration moves only southern field keys")
	_check(state.save_game(), "schema-three deployed mission migrates to schema five")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(migrated is Dictionary and migrated.get("schema") == 5 and migrated.get("squad_deployed") == true and migrated.get("fishing_ready_at") == 0.0, "schema-five migration preserves deployed squad and initializes fishing cooldown")
	state.start_new_game()
	_check(state.load_game() and state.player_position == Vector2(830, 1368) and state.player_hold_position == [760.0, 1108.0] and state.squad_members["resident_00"]["position"] == [830.0, 1368.0] and state.field_regrowth.has("paprika:52:78"), "reloading the migrated squad does not shift coordinates a second time")


func _test_planet_save(state) -> void:
	state.start_new_game()
	state.add_gold(1200)
	_check(state.travel_to("brudet", Vector2(790, 615)), "planet save fixture reaches Brudet from the old southern village")
	state.remember_player_position(Vector2(1475, 735))
	state.field_regrowth = {"paprika:51:26": 90.0, "brudet:3:30": 20.0}
	state.play_seconds = 20.0
	state.fishing_ready_at = 31.5
	_check(state.save_game(), "Brudet fixture can be saved before migration")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and saved.get("schema") == 5 and saved.get("current_planet") == "brudet" and saved.get("player_position") == [1475.0, 735.0] and saved.get("planet_positions", {}).get("paprika") == [790.0, 615.0] and saved.get("fishing_ready_at") == 31.5, "fixture records both planets and the absolute fishing deadline")
	if not saved is Dictionary:
		return
	saved["schema"] = 4
	var legacy_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(legacy_file != null, "schema-four Brudet fixture can be written")
	if legacy_file == null:
		return
	legacy_file.store_string(JSON.stringify(saved))
	legacy_file.close()
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "brudet" and state.player_position == Vector2(1475, 735) and state.gold == 200 and state.fishing_ready_at == 31.5, "schema-four migration leaves active Brudet position, gold and fishing deadline unchanged")
	_check(state.planet_positions["paprika"] == [790.0, 1383.0], "schema-four migration shifts the inactive Paprika position while on Brudet")
	_check(state.field_regrowth == {"paprika:51:74": 90.0, "brudet:3:30": 20.0}, "schema-four migration shifts Paprika fields without changing Brudet fields")
	_check(state.save_game(), "migrated Brudet game can be saved as schema five")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(migrated is Dictionary and migrated.get("schema") == 5 and migrated.get("planet_positions", {}).get("paprika") == [790.0, 1383.0], "schema-five save keeps the corrected inactive Paprika position")
	state.start_new_game()
	_check(state.load_game() and state.player_position == Vector2(1475, 735) and state.planet_positions["paprika"] == [790.0, 1383.0] and state.field_regrowth.has("paprika:51:74"), "schema-five reload does not shift inactive Paprika coordinates twice")
	state._process(4.0)
	_check(state.play_seconds == 24.0 and state.fishing_ready_at == 31.5, "elapsed play time does not reset the fishing deadline")
	_check(state.travel_to("paprika", Vector2(1475, 735)) and state.player_position == Vector2(790, 1383) and state.fishing_ready_at == 31.5, "free return restores the migrated southern Paprika position without resetting fishing")
	if migrated is Dictionary:
		for field in ["current_planet", "planet_positions", "fishing_ready_at"]:
			var missing: Dictionary = migrated.duplicate(true)
			missing.erase(field)
			_check(not state._valid_save(missing), "schema-five save requires %s" % field)
		var bad_planet: Dictionary = migrated.duplicate(true)
		bad_planet["current_planet"] = "unknown"
		_check(not state._valid_save(bad_planet), "unknown saved planet is rejected")
		var bad_position: Dictionary = migrated.duplicate(true)
		bad_position["planet_positions"]["paprika"] = [100]
		_check(not state._valid_save(bad_position), "incomplete saved planet position is rejected")
		var bad_fishing: Dictionary = migrated.duplicate(true)
		bad_fishing["fishing_ready_at"] = -1.0
		_check(not state._valid_save(bad_fishing), "negative fishing deadline is rejected")


func _test_northern_products() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	for item_id in ["rye_bread", "berry_pie", "smoked_fish"]:
		var definition := GameData.item(item_id)
		_check(definition.get("kind", "") == "food" and int(definition.get("buy", 0)) > 0 and int(definition.get("heal", 0)) > 0, "%s is purchasable healing food" % item_id)
		state.health = 1
		if state.add_item(item_id):
			_check(state.use_food(item_id) and state.health > 1 and not state.inventory.has(item_id), "%s restores health and is consumed" % item_id)
	var cloth := GameData.item("purple_cloth")
	_check(cloth.get("kind", "") == "trade" and int(cloth.get("buy", 0)) > 0 and int(cloth.get("sell", 0)) > 0, "purple cloth can be traded but has no crafting recipe")
	_check(state.add_item("purple_cloth") and not state.equip_item("purple_cloth") and not state.use_food("purple_cloth"), "purple cloth cannot be worn or eaten")
	_check(GameData.item("purple_tunic").get("kind", "") == "clothing" and state.add_item("purple_tunic") and state.equip_item("purple_tunic"), "purple tunic is a wearable garment")
	state.free()


func _test_travel_fare() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_gold(GameData.TRAVEL_FARE)
	var before_inventory: Dictionary = state.inventory.duplicate(true)
	_check(GameData.item("travel_fare").is_empty() and not state.buy_item("travel_fare"), "travel fare is not a purchasable inventory item")
	_check(state.gold == GameData.TRAVEL_FARE and state.inventory == before_inventory, "attempted item purchase does not spend fare")
	_check(state.spend_gold(GameData.TRAVEL_FARE) and state.gold == 0, "generic gold payment can spend the fare")
	state.free()


func _test_planet_travel() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_gold(999)
	var original_inventory: Dictionary = state.inventory.duplicate(true)
	_check(state.travel_fare("brudet") == 1000 and state.travel_fare("paprika") == -1, "Paprika only offers the 1000-gold Brudet trip")
	_check(not state.travel_to("brudet", Vector2(1050, 240)) and state.gold == 999 and state.current_planet == "paprika" and state.planet_positions["paprika"] == [320.0, 220.0], "unaffordable trip changes neither gold nor planet positions")
	state.add_gold(1)
	_check(not state.travel_to("unknown", Vector2(1050, 240)) and state.gold == 1000 and state.current_planet == "paprika", "unknown destination does not charge a fare")
	_check(state.travel_to("brudet", Vector2(1050, 240)) and state.gold == 0 and state.current_planet == "brudet" and state.player_position == Vector2(1450, 706), "successful outbound trip charges exactly 1000 gold and reaches Brudet arrival")
	_check(state.planet_positions["paprika"] == [1050.0, 240.0] and state.inventory == original_inventory, "outbound trip remembers Paprika position without changing inventory")
	state.remember_player_position(Vector2(1505, 748))
	_check(state.travel_fare("paprika") == 0 and state.travel_to("paprika", Vector2(1505, 748)) and state.gold == 0 and state.player_position == Vector2(1050, 240), "return trip is free and restores departure position on Paprika")
	_check(state.planet_positions["brudet"] == [1505.0, 748.0], "return saves the Brudet position")
	_check(not state.travel_to("paprika", Vector2.ZERO) and state.gold == 0, "same-planet travel is rejected without charging gold")
	state.add_gold(1000)
	_check(state.travel_to("brudet", Vector2(1075, 267)) and state.gold == 0 and state.player_position == Vector2(1505, 748) and state.planet_positions["paprika"] == [1075.0, 267.0], "later outbound trip charges again and restores the saved Brudet position")
	state.free()


func _test_deployed_travel() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_gold(1000)
	state.defeated_persistent_enemies.append("hacker_forest")
	state.accept_job(state.CAMP_JOB)
	state.recruit_villager("resident_00", Vector2(830, 600))
	state.recruit_villager("resident_25", Vector2(1250, 255))
	_check(state.deploy_squad(), "two camp recruits can deploy before the travel check")
	_check(not state.can_travel("brudet") and not state.travel_to("brudet", Vector2(1050, 240)), "deployed squad cannot leave Paprika")
	_check(state.gold == 1000 and state.current_planet == "paprika" and state.player_position == Vector2(320, 220) and state.planet_positions["paprika"] == [320.0, 220.0] and state.squad_deployed, "blocked trip preserves fare, position and squad deployment")
	state.free()
