extends SceneTree

const GameStateScript := preload("res://scripts/state/game_state.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run("new game resets state", _test_new_game)
	_run("unaffordable purchase is atomic", _test_unaffordable_purchase)
	_run("buy and equip", _test_buy_and_equip)
	_run("sell an entire produce stack", _test_bulk_sales)
	_run("armor reduces damage", _test_armor)
	_run("armor can be removed without being sold", _test_unequip_armor)
	_run("field regrowth", _test_field_regrowth)
	_run("field job pays once", _test_field_job)
	_run("five rabbits pay reward", _test_rabbit_job)
	_run("wrong event is ignored", _test_wrong_event)
	_run("wrong issuer cannot claim", _test_wrong_issuer)
	_run("unique hacker job cannot repeat", _test_unique_job)
	_run("multiple jobs progress independently", _test_simultaneous_jobs)
	_run("road claim unlocks camp and camp claim unlocks hacker", _test_camp_unlock)
	_run("southern road squad kills and repeatable reward", _test_road_cleanup)
	_run("northern camp casualties are unique and reward pays once", _test_camp_casualties)
	_run("recruits, equipment and orders", _test_squad_equipment)
	_run("buy enough gear for two recruits", _test_buy_another_squad_gear)
	_run("downed recruit recovers", _test_recruit_recovery)
	_run("save migration and validation", _test_saves)
	_run("northern food and clothing", _test_northern_products)
	_run("travel fare is not an item purchase", _test_travel_fare)
	_run("planet travel and fare", _test_planet_travel)
	_run("deployed squad cannot travel", _test_deployed_travel)
	_run("embassy travel to Chvarak and Engineeria", _test_embassy_travel)
	_run("Brudet teams and local recruits", _test_brudet_teams)
	_run("Brudet solo hacker and team exclusion", _test_brudet_solo_hacker)
	_run("military enlistment, chest and six drills", _test_military_training)
	_run("combat job location hints", _test_combat_job_hints)
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
	state.camp_unlocked = true
	state.player_position = Vector2(7, 8)
	state.field_regrowth["plot"] = 50.0
	state.defeated_persistent_enemies.append("hacker")
	state.play_seconds = 70.0
	state.current_planet = "brudet"
	state.planet_positions["brudet"] = [7.0, 8.0]
	state.fishing_ready_at = 90.0
	state.team_job_id = "brudet_monster_team"
	state.team_defeated_ids.append("brudet_team_monster_0")
	state.legacy_camp_roster = true
	state.military_cannon_round_active = true
	state.military_cannon_phase = "loaded"
	state.military_trap_round_active = true
	state.military_trap_equipped = true
	state.military_trap_mine_position = [1.0, 2.0]
	state.start_new_game()
	_check(state.max_health == GameData.STARTING_MAX_HEALTH and state.health == state.max_health, "new game restores full starting health")
	_check(state.gold == 0 and state.inventory == {"stick": 1, "bread": 1}, "new game restores starting gold and inventory")
	_check(state.equipment == {"weapon": "stick", "armor": "", "clothing": ""}, "new game restores starting equipment")
	_check(state.active_jobs.is_empty() and state.tracked_job_id == "" and state.completed_unique_jobs.is_empty() and state.team_job_id == "" and state.team_defeated_ids.is_empty() and not state.legacy_camp_roster and not state.camp_unlocked, "new game clears jobs and camp unlock")
	_check(state.player_position == Vector2(320, 220) and state.field_regrowth.is_empty(), "new game resets position and regrowth")
	_check(state.defeated_persistent_enemies.is_empty() and state.play_seconds == 0.0, "new game clears enemy history and play time")
	_check(not state.military_cannon_round_active and state.military_cannon_phase == "empty" and not state.military_trap_round_active and not state.military_trap_equipped and state.military_trap_mine_position.is_empty(), "new game clears unfinished station rounds and mine state")
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


func _test_bulk_sales() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_item("potato", 13)
	var initial_gold := state.gold
	_check(state.sell_all_items("potato") and int(state.inventory.get("potato", 0)) == 0 and state.gold == initial_gold + 26, "thirteen potatoes sell together for thirteen times the unit price")
	_check(not state.sell_all_items("potato") and state.gold == initial_gold + 26, "an empty stack cannot be sold again")
	state.add_item("embassy_letters")
	_check(not state.sell_all_items("embassy_letters") and int(state.inventory.get("embassy_letters", 0)) == 1, "key items remain unsellable in bulk")
	state.free()


func _test_unequip_armor() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_item("wood_armor")
	_check(state.equip_item("wood_armor") and state.unequip_armor() and String(state.equipment["armor"]).is_empty() and int(state.inventory["wood_armor"]) == 1, "armor stays in the pack after removal")
	_check(state.equip_item("wood_armor") and state.equipment["armor"] == "wood_armor", "armor can be put back on")
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
	_check(not state.accept_job("hacker_bounty"), "Paprika hacker bounty is locked before the camp reward")
	state.camp_unlocked = true
	state.completed_unique_jobs.append(state.CAMP_JOB)
	_check(state.accept_job("hacker_bounty"), "hacker bounty can be accepted after the camp reward")
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
	_check(not state.camp_unlocked and not state.accept_job(state.CAMP_JOB) and not state.accept_job("hacker_bounty"), "fresh game locks the camp and Paprika hacker bounty")
	state.defeated_persistent_enemies.append("hacker_forest")
	_check(state.hacker_defeated() and not state.accept_job(state.CAMP_JOB), "a hacker defeat alone does not unlock the camp in a new game")
	state.defeated_persistent_enemies.clear()
	_check(state.accept_job(state.ROAD_JOB) and state.recruit_villager("resident_00", Vector2(830, 1368)) and state.recruit_villager("villager1_37", Vector2(840, 1368)) and state.deploy_squad(), "road squad deploys before unlocking the camp")
	for enemy_id in state.ROAD_IDS:
		state.record_road_defeat(enemy_id)
	_check(state.active_job_ready(state.ROAD_JOB) and not state.camp_unlocked and not state.accept_job(state.CAMP_JOB), "road kills without claiming the reward do not unlock the camp")
	_check(state.claim_job("mercenary", state.ROAD_JOB) and state.camp_unlocked and state.accept_job(state.CAMP_JOB), "claiming the road reward unlocks the northern camp")
	_check(not state.accept_job("hacker_bounty"), "accepted camp does not yet unlock the Paprika hacker")
	_check(state.recruit_villager("resident_24", Vector2(1126, 390)) and state.recruit_villager("resident_25", Vector2(1250, 255)) and state.deploy_squad(), "northern camp squad deploys after the road reward")
	for enemy_id in state.CAMP_IDS:
		state.record_camp_defeat(enemy_id)
	_check(state.active_job_ready(state.CAMP_JOB) and not state.accept_job("hacker_bounty"), "camp kills without the claim do not unlock the hacker bounty")
	_check(state.claim_job("north_mercenary", state.CAMP_JOB) and state.accept_job("hacker_bounty"), "claiming the camp reward unlocks the solo Paprika hacker bounty")
	state.free()


func _test_road_cleanup() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(state.ROAD_IDS == ["zombie_260", "zombie_262", "zombie_264"] and GameData.job(state.ROAD_JOB).get("issuer") == "mercenary", "southern mercenary office issues the three marked road zombies")
	_check(state.accept_job(state.ROAD_JOB) and state.team_job_id == state.ROAD_JOB, "road squad job is available before the hacker defeat")
	state.defeated_persistent_enemies.append("hacker_forest")
	_check(not state.accept_job(state.CAMP_JOB), "an active road squad prevents accepting the northern camp squad")
	_check(not state.record_road_defeat(state.ROAD_IDS[0]) and not state.record_event("team_target_defeated", 3), "road kills cannot count before deployment or through generic events")
	_check(not state.recruit_villager("resident_24", Vector2.ZERO) and state.recruit_villager("resident_00", Vector2(830, 1368)), "southern mission refuses a northern recruit and accepts the first-village resident")
	_check(not state.deploy_squad() and state.recruit_villager("villager1_37", Vector2(840, 1368)) and state.deploy_squad(), "two distinct southern recruits deploy for the road")
	_check(not state.recruit_villager("villager2_38", Vector2.ZERO) and not state.claim_job("mercenary", state.ROAD_JOB), "deployed roster is fixed and incomplete road job cannot be claimed")
	_check(not state.record_road_defeat("zombie_261") and not state.record_road_defeat(state.CAMP_IDS[0]) and not state.record_team_defeat(state.ROAD_IDS[0]), "unmarked zombies, camp bandits and the Brudet recorder cannot advance road progress")
	for index in state.ROAD_IDS.size():
		var enemy_id: String = state.ROAD_IDS[index]
		_check(state.record_road_defeat(enemy_id), "marked road zombie %d advances the mission" % (index + 1))
		_check(not state.record_road_defeat(enemy_id) and int(state.active_jobs[state.ROAD_JOB]) == index + 1, "same road zombie cannot count twice")
	_check(state.active_job_ready(state.ROAD_JOB) and state.team_defeated_ids == state.ROAD_IDS, "three distinct deployed road kills complete the job")
	_check(not state.claim_job("north_mercenary", state.ROAD_JOB) and not state.claim_job("work_office", state.ROAD_JOB), "other offices cannot pay the road reward")
	var reward := int(GameData.job(state.ROAD_JOB)["reward"])
	_check(state.claim_job("mercenary", state.ROAD_JOB) and state.gold == reward, "southern mercenary office pays the road reward")
	_check(state.team_job_id == "" and state.team_defeated_ids.is_empty() and not state.squad_deployed and state.squad_recruits.is_empty() and not state.completed_unique_jobs.has(state.ROAD_JOB) and state.camp_unlocked, "claiming releases the repeatable road squad and unlocks the camp")
	_check(not state.claim_job("mercenary", state.ROAD_JOB) and state.gold == reward and state.accept_job(state.ROAD_JOB), "claim cannot repeat until a new road mission is accepted")
	_check(state.active_jobs[state.ROAD_JOB] == 0 and state.team_defeated_ids.is_empty() and not state.record_road_defeat(state.ROAD_IDS[0]), "repeat starts at zero and requires a new deployment")
	_check(state.recruit_villager("resident_00", Vector2(830, 1368)) and state.recruit_villager("villager1_37", Vector2(840, 1368)) and state.deploy_squad() and state.record_road_defeat(state.ROAD_IDS[0]), "road targets can count again on a newly deployed mission")
	state.free()


func _test_camp_casualties() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
	_check(GameData.job(state.CAMP_JOB).get("issuer") == "north_mercenary" and state.accept_job(state.CAMP_JOB), "northern mercenary office issues the unlocked camp mission")
	_check(not state.record_camp_defeat(state.CAMP_IDS[0]) and not state.record_event("camp_bandit_defeated", 3), "camp kills cannot count before deployment or through generic events")
	_check(not state.recruit_villager("resident_00", Vector2(830, 1368)) and not state.recruit_villager("villager1_37", Vector2.ZERO), "camp rejects southern villagers")
	_check(state.recruit_villager("resident_24", Vector2(1126, 390)) and state.recruit_villager("resident_25", Vector2(1250, 255)) and state.deploy_squad(), "two northern recruits allow camp deployment")
	_check(not state.claim_job("north_mercenary", state.CAMP_JOB), "camp reward cannot be claimed before the bandits are defeated")
	_check(not state.record_camp_defeat("bandit_forest") and not state.record_camp_defeat("unknown"), "other bandits cannot advance the camp mission")
	for index in state.CAMP_IDS.size():
		var enemy_id: String = state.CAMP_IDS[index]
		_check(state.record_camp_defeat(enemy_id), "unique camp bandit %d advances the mission" % (index + 1))
		_check(not state.record_camp_defeat(enemy_id) and int(state.active_jobs[state.CAMP_JOB]) == index + 1, "same camp bandit cannot count twice")
	_check(state.active_job_ready(state.CAMP_JOB) and state.camp_defeated_ids.size() == 3, "exactly three distinct camp kills complete the mission")
	_check(not state.claim_job("work_office", state.CAMP_JOB) and not state.claim_job("mercenary", state.CAMP_JOB), "work office and southern mercenary office cannot pay the camp reward")
	var reward := int(GameData.job(state.CAMP_JOB)["reward"])
	_check(state.claim_job("north_mercenary", state.CAMP_JOB) and state.gold == reward, "northern mercenary office pays the camp reward once")
	_check(not state.squad_deployed and state.squad_recruits.is_empty() and state.completed_unique_jobs.has(state.CAMP_JOB), "claiming releases the squad and records unique completion")
	_check(not state.claim_job("north_mercenary", state.CAMP_JOB) and not state.accept_job(state.CAMP_JOB) and state.gold == reward, "camp reward cannot be claimed or accepted a second time")
	state.free()


func _test_squad_equipment() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(not state.recruit_villager("resident_00", Vector2.ZERO) and not state.deploy_squad(), "recruitment and deployment require an active squad mission")
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
	state.accept_job(state.CAMP_JOB)
	_check(not state.recruit_villager("not_a_villager", Vector2.ZERO) and not state.recruit_villager("resident_00", Vector2.ZERO), "unknown and southern villagers cannot join northern camp team")
	_check(state._valid_recruit_id("resident_25", "paprika") and not state._valid_recruit_id("resident_26", "paprika"), "northern recruit IDs extend through resident_25")
	_check(state.recruit_villager("resident_24", Vector2(1126, 390)), "first northern villager joins the squad")
	_check(not state.recruit_villager("resident_24", Vector2.ZERO) and not state.deploy_squad(), "same villager cannot join twice and one recruit cannot deploy")
	_check(state.recruit_villager("resident_25", Vector2(1250, 255)) and not state.recruit_villager("resident_23", Vector2.ZERO), "squad holds exactly two distinct villagers")
	_check(state.dismiss_recruit("resident_25") and state.recruit_villager("resident_23", Vector2(1130, 410)), "recruit can be replaced before deployment")
	_check(state.add_item("wood_sword") and state.equip_recruit("resident_24", "weapon", "wood_sword"), "first recruit can equip one owned sword")
	_check(state.reserved_item_count("wood_sword") == 1 and not state.equip_recruit("resident_23", "weapon", "wood_sword") and not state.equip_item("wood_sword"), "one sword cannot be equipped by several squad members")
	_check(not state.sell_item("wood_sword") and not state.remove_item("wood_sword"), "equipped sword cannot be sold or removed")
	_check(state.add_item("wood_sword") and state.equip_recruit("resident_23", "weapon", "wood_sword") and state.reserved_item_count("wood_sword") == 2, "second sword allows the other recruit to equip one")
	_check(state.add_item("wood_armor") and state.equip_recruit("resident_23", "armor", "wood_armor"), "owned armor can be assigned to a recruit")
	_check(not state.equip_recruit("resident_24", "armor", "wood_armor") and not state.equip_recruit("resident_24", "weapon", "wood_armor"), "armor requires a spare copy and cannot be assigned as a weapon")
	_check(state.deploy_squad() and not state.dismiss_recruit("resident_24"), "deployment locks the two-person roster")
	_check(state.set_controlled_member("resident_23") and state.controlled_member_id == "resident_23", "either recruit can be controlled")
	_check(state.set_squad_order("player", "hold", Vector2(12, 34)) and state.player_order == "hold" and state.player_hold_position == [12.0, 34.0], "player hold order remembers its location")
	_check(state.set_squad_order("resident_24", "attack", Vector2(44, 55)) and state.squad_members["resident_24"]["order"] == "attack", "recruit receives attack order")
	_check(not state.set_squad_order("resident_24", "invalid", Vector2.ZERO), "invalid orders are refused")
	state.free()


func _test_transfer_player_gear() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
	state.accept_job(state.CAMP_JOB)
	state.recruit_villager("resident_24", Vector2(1126, 390))
	state.recruit_villager("resident_25", Vector2(1250, 255))
	_check(state.equip_recruit("resident_24", "weapon", "stick") and state.equipment["weapon"] == "" and state.weapon_definition().is_empty(), "giving away the only starting weapon leaves the player unarmed")
	_check(not state.equip_item("stick") and state.reserved_item_count("stick") == 1, "the player cannot equip the recruit's only stick")
	_check(state.save_game() and state.load_game() and state.equipment["weapon"] == "" and state.squad_members["resident_24"]["weapon"] == "stick", "an unarmed player and the recruit's weapon survive a save and reload")
	_check(state.equip_recruit("resident_24", "weapon", "militia_club") and state.equip_item("stick"), "returning the recruit's weapon makes it available to the player")
	state.add_item("iron_sword")
	state.equip_item("iron_sword")
	_check(state.equip_recruit("resident_24", "weapon", "iron_sword"), "the player's only equipped sword can be transferred to a recruit")
	_check(state.equipment["weapon"] == "" and state.weapon_definition().is_empty() and state.squad_members["resident_24"]["weapon"] == "iron_sword" and state.reserved_item_count("iron_sword") == 1 and int(state.inventory["iron_sword"]) == 1, "the player loses the weapon and the one owned copy belongs to the recruit")
	_check(not state.equip_recruit("resident_25", "weapon", "iron_sword"), "the other recruit cannot reuse the transferred sword")
	_check(state.equip_item("stick") and state.equipment["weapon"] == "stick", "the player can equip a spare weapon after the transfer")
	state.add_item("wood_armor")
	state.equip_item("wood_armor")
	_check(state.equip_recruit("resident_24", "armor", "wood_armor") and state.equipment["armor"] == "" and state.squad_members["resident_24"]["armor"] == "wood_armor", "transferring equipped armor removes it from the player")
	_check(not state.sell_item("iron_sword") and state.save_game(), "a transferred weapon remains reserved and the state can be saved")
	state.free()


func _test_buy_another_squad_gear() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
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
	state.camp_unlocked = true
	state.accept_job(state.CAMP_JOB)
	state.recruit_villager("resident_24", Vector2(1126, 390))
	state.recruit_villager("resident_25", Vector2(1250, 255))
	state.deploy_squad()
	_check(state.damage_recruit("resident_24", 5) and int(state.squad_members["resident_24"]["health"]) == 19, "recruit takes nonfatal damage")
	_check(state.heal_recruit("resident_24", "bread") and int(state.inventory.get("bread", 0)) == 0, "food heals recruit and consumes one inventory item")
	_check(state.set_controlled_member("resident_24") and state.damage_recruit("resident_24", 999), "controlled recruit can be downed")
	_check(state.recruit_recovering("resident_24") and state.controlled_member_id == "player", "downed recruit returns control to player")
	_check(not state.damage_recruit("resident_24", 1) and not state.heal_recruit("resident_24", "bread") and not state.set_controlled_member("resident_24"), "downed recruit cannot fight, eat or be controlled")
	state._process(state.RECOVERY_SECONDS - 0.1)
	_check(state.recruit_recovering("resident_24"), "recruit still recovers just before deadline")
	state._process(0.2)
	_check(not state.recruit_recovering("resident_24") and int(state.squad_members["resident_24"]["health"]) == int(state.squad_members["resident_24"]["max_health"]), "recruit returns at full health after recovery")
	_check(state.set_controlled_member("resident_24"), "recovered recruit can be controlled again")
	state.free()


func _test_military_training() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(not state.enlist_military(Vector2.ZERO) and state.travel_fare("station") == -1, "station enlistment begins on Brudet, not Paprika")
	state.add_gold(1000)
	_check(state.travel_to("brudet", Vector2(370, 260)), "player reaches Brudet before enlistment")
	state.add_item("iron_sword")
	state.add_item("iron_sword")
	state.add_item("wood_armor")
	state.add_item("red_tunic")
	state.equip_item("iron_sword")
	state.equip_item("wood_armor")
	state.equip_item("red_tunic")
	var original_items: Dictionary = state.inventory.duplicate(true)
	var original_equipment: Dictionary = state.equipment.duplicate(true)
	state.accept_job("brudet_monster_team")
	state.accept_job("river_patrol")
	state.accept_job("rabbit_catch")
	state.recruit_villager("villager_river_01_45", Vector2(1500, 730))
	_check(not state.enlist_military(Vector2(1510, 740)) and state.current_planet == "brudet", "enlistment cannot move a recruit or their reserved gear")
	state.dismiss_recruit("villager_river_01_45")
	_check(state.enlist_military(Vector2(1510, 740)) and state.gold == 0 and state.current_planet == "station" and state.player_position == state.MILITARY_ARRIVAL and state.military_stage == "depot", "free enlistment remembers Brudet and starts at the depot")
	_check(not state.return_from_military(Vector2.ZERO) and not state.military_complete_drill("run") and not state.military_store_gear(), "station exit and drills require the training sequence")
	_check(state.military_claim_uniform() and not state.military_claim_uniform() and state.inventory.get("military_uniform") == 1 and state.equipment["clothing"] == "military_uniform", "depot issues exactly one green uniform")
	_check(state.enter_military_barracks(Vector2(245, 395)) and state.player_position == state.MILITARY_BARRACKS_ARRIVAL and state.current_area == "barracks", "barracks entrance keeps the exterior position")
	_check(not state.military_complete_drill("run") and not state.military_withdraw_gear(), "unsecured equipment cannot skip storage or withdraw early")
	_check(state.military_store_gear() and not state.military_store_gear() and state.military_stage == "run" and state.inventory == {"military_uniform": 1} and state.equipment == {"weapon": "", "armor": "", "clothing": "military_uniform"}, "chest atomically transfers personal items including equipped gear without transferring gold")
	_check(state.military_storage == original_items and state.military_stored_equipment == original_equipment and state.gold == 0, "chest preserves exact item counts and equipped choices")
	state.remember_player_position(Vector2(268, 355))
	_check(state.exit_military_barracks(Vector2(268, 355)) and state.player_position == Vector2(245, 395), "leaving the barracks restores the exterior position")
	_check(not state.military_complete_drill("range") and state.military_complete_drill("run") and not state.military_complete_drill("run") and state.weapon_definition() == GameData.item("training_club") and state.inventory == {"military_uniform": 1, "training_club": 1} and state.equipment["weapon"] == "training_club", "run issues and equips one owned practice club for sparring")
	_check(state.military_complete_drill("spar") and state.military_stage == "squad" and state.max_health == GameData.STARTING_MAX_HEALTH, "sparring does not grant the squad-bout health increase")
	_check(state.military_complete_drill("squad") and state.military_stage == "range" and state.max_health == 24 and state.health == 24, "the squad bout raises maximum health to 24 and grants four health")
	_check(state.weapon_definition() == GameData.item("training_bow") and state.inventory == {"military_uniform": 1, "training_bow": 1} and state.military_complete_drill("range") and state.inventory == {"military_uniform": 1} and state.military_meal_credits == 4, "range swaps club for one bow and returns it after the drill")
	_check(not state.record_event("river_monster_defeated") and not state.record_event("rabbit_caught") and state.active_jobs["river_patrol"] == 0 and state.active_jobs["rabbit_catch"] == 0, "training does not advance civilian jobs from either planet")
	_check(not state.military_record_cannon_hit("cannon_target_0") and state.military_start_cannon_round() and not state.military_start_cannon_round(), "cannon requires one active round before loading a shot")
	_check(not state.military_load_cannon() and not state.military_record_cannon_hit("cannon_target_0"), "cannon cannot load or record an empty shot")
	_check(state.military_take_cannon_charge() and not state.military_take_cannon_charge() and state.military_load_cannon() and not state.military_load_cannon(), "cannon charge must be carried and loaded in order")
	_check(state.military_record_cannon_hit("cannon_target_0") and not state.military_record_cannon_hit("cannon_target_0") and not state.military_record_cannon_hit("unknown"), "cannon accepts one hit per marked target")
	_check(state.military_take_cannon_charge() and state.military_load_cannon() and state.military_record_cannon_hit("cannon_target_2"), "second cannon shot records another distinct target")
	_check(state.military_take_cannon_charge() and state.military_load_cannon() and state.military_record_cannon_hit("cannon_target_1"), "third cannon shot completes the target set")
	_check(state.military_stage == "trap" and state.military_cannon_hits.size() == 3 and not state.military_cannon_round_active and state.military_cannon_phase == "empty", "third distinct cannon hit clears its round and advances to trap")
	_check(not state.military_record_trap_step("trap_0"), "trap steps require a live round and a placed practice mine")
	for step_id in ["trap_0", "trap_1", "trap_2"]:
		_check(state.military_start_trap_round() and not state.military_start_trap_round() and state.inventory.get("practice_mine", 0) == 1, "trap round issues one practice mine without duplication")
		var mine_definition := GameData.item("practice_mine")
		_check(mine_definition.get("kind") == "training" and mine_definition.get("station_only") == true and mine_definition.get("buy") == 0 and mine_definition.get("sell") == 0 and not state.equip_item("practice_mine") and state.equipment.size() == 3, "practice mine is station-only training gear outside the three equipment slots")
		_check(not state.military_record_trap_step(step_id), "held mine cannot trigger the dummy step")
		_check(state.military_equip_practice_mine() and state.military_trap_equipped and state.military_equip_practice_mine(), "repeated equip requests keep the held mine equipped")
		_check(not state.military_place_practice_mine(Vector2(INF, 700)) and state.military_trap_equipped, "non-finite placement leaves the mine equipped")
		_check(state.military_place_practice_mine(Vector2(500, 700)) and state.inventory.get("practice_mine", 0) == 0 and state.military_trap_mine_placed() and not state.military_trap_equipped, "placement consumes the held item and records its position")
		_check(not state.military_place_practice_mine(Vector2(520, 700)), "a placed practice mine cannot be placed a second time")
		if step_id == "trap_0":
			_check(state.military_restart_trap_round() and state.inventory.get("practice_mine", 0) == 1 and not state.military_trap_mine_placed() and not state.military_trap_equipped, "restart returns one placed mine to inventory")
			_check(state.military_restart_trap_round() and state.inventory.get("practice_mine", 0) == 1, "restarting an already-held mine does not duplicate it")
			_check(state.military_equip_practice_mine() and state.military_place_practice_mine(Vector2(500, 700)), "returned mine can be equipped and placed again")
		var wrong_step := "trap_2" if step_id != "trap_2" else "trap_1"
		_check(not state.military_record_trap_step(wrong_step) and state.military_record_trap_step(step_id), "only the next ordered step triggers the placed mine")
		_check(not state.military_trap_round_active and not state.military_trap_mine_placed() and state.inventory.get("practice_mine", 0) == 0, "triggering consumes the round without leaving a mine")
	_check(state.military_stage == "sleep" and state.military_trap_progress == 3 and state.military_meal_credits == 6, "third physical trap step advances and awards the sixth meal")
	_check(not state.inventory.has("practice_mine") and state.equipment.size() == 3, "practice mine does not persist after the drill or occupy equipment")
	_check(not state.return_from_military(Vector2.ZERO) and not state.military_sleep(), "return and sleep require entering the barracks")
	_check(state.military_eat_meal() and state.military_meal_credits == 5 and state.health == state.max_health, "exterior canteen serves one earned meal even at full health")
	_check(state.enter_military_barracks(Vector2(252, 402)) and state.player_position == Vector2(268, 355) and not state.military_eat_meal() and not state.military_withdraw_gear(), "barracks position persists; meals stay in the canteen and gear stays locked")
	state.damage_player(9)
	_check(state.military_sleep() and state.health == 28 and state.max_health == 28 and state.military_stage == "graduated", "sleep heals to 28 and graduates after all six drills")
	state.damage_player(2)
	_check(state.military_sleep() and state.health == state.max_health and state.military_meal_credits == 5, "later nights restore health without granting more credits")
	_check(state.exit_military_barracks(Vector2(260, 344)) and state.return_from_military(Vector2(246, 397)) and state.current_planet == "brudet" and state.player_position == Vector2(1510, 740) and state.military_storage == original_items, "graduation permits free return while personal gear remains stored")
	_check(state.enlist_military(Vector2(1520, 750)) and state.military_stage == "graduated" and state.inventory.get("military_uniform") == 1 and not state.military_claim_uniform(), "re-enlistment retains graduation without another uniform")
	_check(state.enter_military_barracks(Vector2(246, 397)) and state.military_withdraw_gear() and state.inventory.get("iron_sword") == 2 and state.equipment == original_equipment and state.military_storage.is_empty() and not state.military_withdraw_gear(), "return visit withdraws exact stored counts and previous equipment once")
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
			_run("transfer equipped gear to a recruit", _test_transfer_player_gear)
			_test_save_migration(state)
			_test_planet_save(state)
			_test_brudet_save(state)
			_test_road_save(state)
			_test_solo_save(state)
			_test_legacy_hacker_save(state)
			_test_legacy_brudet_hacker_save(state)
			_test_military_save(state)
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
	_check(state.save_game(), "saving a schema-one migration writes schema nine")
	var saved_data = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	var saved_jobs: Dictionary = saved_data.get("active_jobs", {}) if saved_data is Dictionary else {}
	_check(saved_data is Dictionary and saved_data.get("schema") == GameStateScript.SAVE_SCHEMA and saved_jobs.size() == 2 and int(saved_jobs.get("field_work", -1)) == 3 and int(saved_jobs.get("rabbit_catch", -1)) == 2 and saved_data.get("tracked_job_id") == "field_work", "schema-nine save contains each job and tracked selection")
	_check(saved_data is Dictionary and saved_data.get("field_regrowth", {}).has("paprika:51:74") and not saved_data.get("field_regrowth", {}).has("paprika:51:122"), "schema-nine field keys are not shifted twice on save")
	_check(saved_data is Dictionary and saved_data.get("squad_recruits") == [] and saved_data.get("squad_deployed") == false and saved_data.get("camp_defeated_ids") == [] and saved_data.get("legacy_camp_roster") == false and saved_data.get("camp_unlocked") == false, "migration initializes empty squad, camp progress and camp unlock")
	var backup_data = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_BACKUP_PATH))
	_check(backup_data is Dictionary and backup_data.get("schema") == 1, "previous schema-one save stays in the backup")
	state.start_new_game()
	_check(state.load_game() and state.active_jobs == {"field_work": 3, "rabbit_catch": 2} and state.tracked_job_id == "field_work", "loading schema nine restores both jobs and tracked selection")
	_check(state.player_position == Vector2(790, 1383) and state.field_regrowth.has("paprika:51:74") and not state.field_regrowth.has("paprika:51:122"), "reloading schema nine does not shift the southern position or field again")
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
		var missing_unlock: Dictionary = saved_data.duplicate(true)
		missing_unlock.erase("camp_unlocked")
		_check(not state._valid_save(missing_unlock), "schema-nine save requires camp_unlocked")
		for invalid_value in [0, "false", null]:
			var invalid_unlock: Dictionary = saved_data.duplicate(true)
			invalid_unlock["camp_unlocked"] = invalid_value
			_check(not state._valid_save(invalid_unlock), "schema-nine camp_unlocked must be a boolean")
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
	_check(state.save_game(), "schema-two fixture can be saved as schema nine")
	var migrated_two = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	var migrated_jobs: Dictionary = migrated_two.get("active_jobs", {}) if migrated_two is Dictionary else {}
	_check(migrated_two is Dictionary and migrated_two.get("schema") == GameStateScript.SAVE_SCHEMA and migrated_two.get("tracked_job_id") == "rabbit_catch" and migrated_jobs.size() == 2 and int(migrated_jobs.get("field_work", -1)) == 3 and int(migrated_jobs.get("rabbit_catch", -1)) == 2, "schema-two jobs survive schema-nine serialization")
	var previous_two = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_BACKUP_PATH))
	_check(previous_two is Dictionary and previous_two.get("schema") == 2, "schema-two source is kept in the backup")
	_test_schema_three_mission(state)


func _test_schema_three_mission(state) -> void:
	state.start_new_game()
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
	_check(state.accept_job(state.CAMP_JOB), "schema-three mission fixture accepts the unlocked camp job")
	_check(state.recruit_villager("resident_24", Vector2(1126, 390)) and state.recruit_villager("resident_25", Vector2(1250, 255)), "camp fixture begins with two northern recruit IDs")
	_check(state.add_item("wood_sword") and state.equip_recruit("resident_25", "weapon", "wood_sword") and state.deploy_squad() and state.record_camp_defeat(state.CAMP_IDS[0]), "schema-three fixture has equipped recruits and one camp casualty")
	state.player_position = Vector2(830, 600)
	state.planet_positions["paprika"] = [830.0, 600.0]
	state.field_regrowth = {"paprika:52:30": 60.0, "paprika:54:11": 45.0}
	_check(state.set_squad_order("player", "hold", Vector2(760, 340)) and state.set_squad_order("resident_24", "hold", Vector2(818, 610)) and state.set_squad_order("resident_25", "hold", Vector2(1250, 255)), "schema-three fixture records southern, office-approach and northern holds")
	_check(state.save_game(), "deployed squad fixture can be saved")
	var legacy = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if not legacy is Dictionary:
		_check(false, "deployed squad fixture is readable")
		return
	legacy["schema"] = 3
	legacy["squad_recruits"][0] = "resident_00"
	legacy["squad_members"]["resident_00"] = legacy["squad_members"]["resident_24"]
	legacy["squad_members"].erase("resident_24")
	legacy["squad_members"]["resident_00"]["position"] = [830.0, 600.0]
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
	_check(state.squad_recruits == ["resident_00", "resident_25"] and state.legacy_camp_roster and state.camp_unlocked and state.squad_members["resident_25"]["weapon"] == "wood_sword" and state.inventory["wood_sword"] == 1, "deployed legacy mixed camp roster keeps both identities and reserved equipment")
	_check(state.current_planet == "paprika" and state.player_position == Vector2(830, 1368) and state.fishing_ready_at == 0.0, "schema-three save moves its southern player position and defaults to Paprika")
	_check(state.player_hold_position == [760.0, 1108.0] and state.squad_members["resident_00"]["position"] == [830.0, 1368.0] and state.squad_members["resident_00"]["hold_position"] == [818.0, 1378.0], "schema-three migration moves player and recruit holds, including the old office approach")
	_check(state.squad_members["resident_25"]["position"] == [1250.0, 255.0] and state.squad_members["resident_25"]["hold_position"] == [1250.0, 255.0], "schema-three migration keeps a northern recruit in place")
	_check(state.field_regrowth == {"paprika:52:78": 60.0, "paprika:54:11": 45.0}, "schema-three migration moves only southern field keys")
	_check(state.save_game(), "schema-three deployed mission migrates to schema nine")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(migrated is Dictionary and migrated.get("schema") == GameStateScript.SAVE_SCHEMA and migrated.get("squad_deployed") == true and migrated.get("legacy_camp_roster") == true and migrated.get("camp_unlocked") == true and migrated.get("fishing_ready_at") == 0.0, "schema-nine migration preserves deployed mixed squad and initializes fishing cooldown")
	state.start_new_game()
	_check(state.load_game() and state.legacy_camp_roster and state.squad_recruits == ["resident_00", "resident_25"] and state.player_position == Vector2(830, 1368) and state.player_hold_position == [760.0, 1108.0] and state.squad_members["resident_00"]["position"] == [830.0, 1368.0] and state.field_regrowth.has("paprika:52:78"), "reloading the grandfathered squad does not shift coordinates a second time")
	_check(not state.recruit_villager("resident_01", Vector2.ZERO) and not state.dismiss_recruit("resident_00"), "grandfathered deployed roster stays fixed")
	_test_undeployed_legacy_camp(state, migrated)


func _test_undeployed_legacy_camp(state, deployed_save: Variant) -> void:
	if not deployed_save is Dictionary:
		return
	var schema_eight: Dictionary = deployed_save.duplicate(true)
	schema_eight["schema"] = 8
	schema_eight["planet_positions"].erase("station")
	schema_eight["planet_positions"].erase("artichoke")
	schema_eight["planet_positions"].erase("pomidor")
	schema_eight["planet_positions"].erase("chvarak")
	schema_eight["planet_positions"].erase("engineeria")
	for change in ["missing", "false", "wrong_type"]:
		var invalid: Dictionary = schema_eight.duplicate(true)
		match change:
			"missing": invalid.erase("legacy_camp_roster")
			"false": invalid["legacy_camp_roster"] = false
			"wrong_type": invalid["legacy_camp_roster"] = "yes"
		_check(not state._valid_save(invalid), "schema-eight deployed mixed camp roster rejects %s permission" % change)
	var schema_seven: Dictionary = schema_eight.duplicate(true)
	schema_seven["schema"] = 7
	schema_seven["planet_positions"].erase("station")
	schema_seven["planet_positions"].erase("artichoke")
	schema_seven["planet_positions"].erase("pomidor")
	schema_seven["planet_positions"].erase("chvarak")
	schema_seven["planet_positions"].erase("engineeria")
	schema_seven.erase("camp_unlocked")
	_check(state._valid_save(schema_seven), "schema-seven mixed deployed camp save remains valid without the new unlock field")
	var invalid_seven: Dictionary = schema_seven.duplicate(true)
	invalid_seven["legacy_camp_roster"] = false
	_check(not state._valid_save(invalid_seven), "schema-seven locality rules still require grandfathering for mixed camp rosters")
	var deployed_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(deployed_file != null, "schema-seven deployed camp fixture can be written")
	if deployed_file != null:
		deployed_file.store_string(JSON.stringify(schema_seven))
		deployed_file.close()
		state.start_new_game()
		_check(state.load_game() and state.camp_unlocked and state.legacy_camp_roster and state.squad_recruits == ["resident_00", "resident_25"], "schema-seven deployed mixed squad retains old hacker entitlement and roster")
		_check(state.save_game(), "schema-seven deployed camp migrates to schema nine")
	var legacy: Dictionary = schema_seven.duplicate(true)
	legacy["schema"] = 6
	legacy["squad_deployed"] = false
	legacy["active_jobs"][state.CAMP_JOB] = 0
	legacy["camp_defeated_ids"] = []
	legacy["defeated_persistent_enemies"].erase(state.CAMP_IDS[0])
	legacy["legacy_camp_roster"] = false
	_check(state._valid_save(legacy), "schema-six undeployed mixed camp roster remains a valid older save")
	var file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "schema-six undeployed camp fixture can be written")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.start_new_game()
	_check(state.load_game() and not state.squad_deployed and state.squad_recruits == ["resident_25"] and not state.squad_members.has("resident_00") and not state.legacy_camp_roster and state.camp_unlocked, "migration dismisses undeployed southern recruit and keeps the old camp entitlement")
	_check(state.team_job_id == state.CAMP_JOB and state.active_jobs[state.CAMP_JOB] == 0 and state.recruit_villager("resident_24", Vector2(1126, 390)) and not state.recruit_villager("resident_00", Vector2.ZERO), "migrated camp can refill its northern roster but cannot recruit southern villagers")
	_check(state.save_game(), "migrated undeployed camp roster saves as schema nine")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and saved.get("schema") == GameStateScript.SAVE_SCHEMA and saved.get("squad_recruits") == ["resident_25", "resident_24"] and saved.get("legacy_camp_roster") == false and saved.get("camp_unlocked") == true, "schema-nine save records the retained northern recruits and historic camp entitlement")
	if saved is Dictionary:
		var locked: Dictionary = saved.duplicate(true)
		locked["camp_unlocked"] = false
		_check(not state._valid_save(locked), "schema-nine save rejects an active camp with no camp unlock")


func _test_planet_save(state) -> void:
	state.start_new_game()
	state.add_gold(2200)
	_check(state.travel_to("brudet", Vector2(790, 615)), "planet save fixture reaches Brudet from the old southern village")
	state.remember_player_position(Vector2(1475, 735))
	state.field_regrowth = {"paprika:51:26": 90.0, "brudet:3:30": 20.0}
	state.play_seconds = 20.0
	state.fishing_ready_at = 31.5
	_check(state.save_game(), "Brudet fixture can be saved before migration")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and saved.get("schema") == GameStateScript.SAVE_SCHEMA and saved.get("current_planet") == "brudet" and saved.get("player_position") == [1475.0, 735.0] and saved.get("planet_positions", {}).get("paprika") == [790.0, 615.0] and saved.get("fishing_ready_at") == 31.5, "schema-nine fixture records both civilian planets and the absolute fishing deadline")
	if not saved is Dictionary:
		return
	saved["schema"] = 4
	saved["planet_positions"].erase("station")
	saved["planet_positions"].erase("artichoke")
	saved["planet_positions"].erase("pomidor")
	saved["planet_positions"].erase("chvarak")
	saved["planet_positions"].erase("engineeria")
	var legacy_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(legacy_file != null, "schema-four Brudet fixture can be written")
	if legacy_file == null:
		return
	legacy_file.store_string(JSON.stringify(saved))
	legacy_file.close()
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "brudet" and state.player_position == Vector2(1475, 735) and state.gold == 1200 and state.fishing_ready_at == 31.5, "schema-four migration leaves active Brudet position, gold and fishing deadline unchanged")
	_check(state.planet_positions["paprika"] == [790.0, 1383.0], "schema-four migration shifts the inactive Paprika position while on Brudet")
	_check(state.field_regrowth == {"paprika:51:74": 90.0, "brudet:3:30": 20.0}, "schema-four migration shifts Paprika fields without changing Brudet fields")
	_check(state.save_game(), "migrated Brudet game can be saved as schema nine")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(migrated is Dictionary and migrated.get("schema") == GameStateScript.SAVE_SCHEMA and migrated.get("planet_positions", {}).get("paprika") == [790.0, 1383.0], "schema-nine save keeps the corrected inactive Paprika position")
	state.start_new_game()
	_check(state.load_game() and state.player_position == Vector2(1475, 735) and state.planet_positions["paprika"] == [790.0, 1383.0] and state.field_regrowth.has("paprika:51:74"), "schema-nine reload does not shift inactive Paprika coordinates twice")
	state._process(4.0)
	_check(state.play_seconds == 24.0 and state.fishing_ready_at == 31.5, "elapsed play time does not reset the fishing deadline")
	_check(state.travel_to("paprika", Vector2(1475, 735)) and state.gold == 200 and state.player_position == Vector2(790, 1383) and state.fishing_ready_at == 31.5, "paid return restores the migrated southern Paprika position without resetting fishing")
	if migrated is Dictionary:
		for field in ["current_planet", "planet_positions", "fishing_ready_at"]:
			var missing: Dictionary = migrated.duplicate(true)
			missing.erase(field)
			_check(not state._valid_save(missing), "schema-nine save requires %s" % field)
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
	_check(state.travel_fare("paprika") == 1000 and not state.travel_to("paprika", Vector2(1505, 748)) and state.gold == 0 and state.current_planet == "brudet" and state.planet_positions["brudet"] == [1505.0, 748.0], "unaffordable return preserves Brudet state")
	state.add_gold(1000)
	_check(state.travel_to("paprika", Vector2(1505, 748)) and state.gold == 0 and state.player_position == Vector2(1050, 240), "return trip costs 1000 and restores departure position on Paprika")
	_check(state.planet_positions["brudet"] == [1505.0, 748.0], "return saves the Brudet position")
	_check(not state.travel_to("paprika", Vector2.ZERO) and state.gold == 0, "same-planet travel is rejected without charging gold")
	state.add_gold(1000)
	_check(state.travel_to("brudet", Vector2(1075, 267)) and state.gold == 0 and state.player_position == Vector2(1505, 748) and state.planet_positions["paprika"] == [1075.0, 267.0], "later outbound trip charges again and restores the saved Brudet position")
	state.free()


func _test_embassy_travel() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.current_planet = "pomidor"
	state.defeated_persistent_enemies.append(state.POMIDOR_UNLOCK_FLAG)
	var gold := state.gold
	_check(state.travel_fare("chvarak") == 0 and not state.can_travel("chvarak"), "the transport flies to Chvarak only once the embassy is accepted")
	state.defeated_persistent_enemies.append(state.EMBASSY_FLAG)
	_check(state.travel_to("chvarak", Vector2(900, 500)) and state.current_planet == "chvarak" and state.gold == gold and state.player_position == state.CHVARAK_ARRIVAL, "with the embassy the flight to Chvarak is free and lands by the transport")
	_check(state.travel_fare("engineeria") == -1 and not state.can_travel("engineeria"), "no transport flies to Engineeria")
	_check(state.save_game(), "a save on Chvarak with the embassy accepted is written")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and state._valid_save(saved), "a save on Chvarak with the embassy accepted is valid")
	if saved is Dictionary:
		var early: Dictionary = saved.duplicate(true)
		early["defeated_persistent_enemies"].erase(state.EMBASSY_FLAG)
		_check(not state._valid_save(early), "a save on Chvarak without the embassy is rejected")
	state.defeated_persistent_enemies.append(state.CRASH_FLAG)
	_check(state.story_travel("engineeria", Vector2(700, 300)) and state.current_planet == "engineeria" and state.gold == gold and state.player_position == state.ENGINEERIA_ARRIVAL, "the crash takes the player to Engineeria without a fare")
	_check(state.planet_positions["chvarak"] == [700.0, 300.0], "the crash remembers where the player left Chvarak")
	_check(state.travel_fare("chvarak") == -1 and state.travel_fare("pomidor") == -1 and not state.can_travel("pomidor"), "Engineeria has no way off yet")
	_check(state.save_game(), "a save on Engineeria after the crash is written")
	saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and state._valid_save(saved), "a save on Engineeria after the crash is valid")
	if saved is Dictionary:
		var before_crash: Dictionary = saved.duplicate(true)
		before_crash["defeated_persistent_enemies"].erase(state.CRASH_FLAG)
		_check(not state._valid_save(before_crash), "a save on Engineeria without the crash is rejected")
	state.current_planet = "pomidor"
	_check(not state.can_travel("chvarak"), "after the crash the transport no longer flies to Chvarak")
	state.free()


func _test_deployed_travel() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	state.add_gold(1000)
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
	state.accept_job(state.CAMP_JOB)
	state.recruit_villager("resident_24", Vector2(1126, 390))
	state.recruit_villager("resident_25", Vector2(1250, 255))
	_check(state.deploy_squad(), "two northern camp recruits can deploy before the travel check")
	_check(not state.can_travel("brudet") and not state.travel_to("brudet", Vector2(1050, 240)), "deployed squad cannot leave Paprika")
	_check(state.gold == 1000 and state.current_planet == "paprika" and state.player_position == Vector2(320, 220) and state.planet_positions["paprika"] == [320.0, 220.0] and state.squad_deployed, "blocked trip preserves fare, position and squad deployment")
	state.start_new_game()
	state.add_gold(1000)
	state.defeated_persistent_enemies.append("hacker_forest")
	state.camp_unlocked = true
	_check(state.accept_job(state.CAMP_JOB) and state.recruit_villager("resident_24", Vector2(1126, 390)), "camp team can recruit before deployment")
	_check(not state.can_travel("brudet") and not state.travel_to("brudet", Vector2(1050, 240)) and state.gold == 1000, "one undeployed recruit also blocks travel")
	state.dismiss_recruit("resident_24")
	_check(state.travel_to("brudet", Vector2(1050, 240)) and state.team_job_id == state.CAMP_JOB and state.active_jobs.has(state.CAMP_JOB), "empty undeployed team may travel without losing its mission")
	state.free()


func _test_brudet_teams() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(not state.accept_job("brudet_monster_team"), "Brudet team job cannot start on Paprika")
	_check(state.accept_job("bandit_bounty") and not state.accept_job("hacker_bounty"), "Paprika bandit bounty remains available before the camp reward, but hacker bounty does not")
	state.add_gold(1000)
	_check(state.travel_to("brudet", Vector2(1050, 240)), "team fixture travels to Brudet")
	_check(not state.recruit_villager("resident_00", Vector2.ZERO) and not state.recruit_villager("villager_river_01_45", Vector2.ZERO), "recruits require an active local team job")
	_check(not state.record_event("bandit_defeated") and not state.record_event("hacker_defeated") and state.active_jobs["bandit_bounty"] == 0, "Brudet bandit and hacker kills cannot progress the Paprika bounty")
	_check(state.accept_job("brudet_monster_team"), "Brudet monster team job can be accepted")
	_check(state.team_job_id == "brudet_monster_team" and not state.accept_job("brudet_bandit_team") and not state.accept_job(state.CAMP_JOB), "only one team job can be active")
	_check(not state.recruit_villager("resident_00", Vector2.ZERO) and state.recruit_villager("villager_river_01_45", Vector2(1400, 710)), "Brudet mission rejects Paprika recruit and accepts a local villager")
	_check(not state.deploy_squad() and state.recruit_villager("villager_river_02_46", Vector2(1420, 710)) and state.deploy_squad(), "two distinct Brudet villagers are required to deploy")
	_check(not state.record_team_defeat("brudet_team_bandit_0") and not state.record_event("monster_defeated", 3), "other targets and generic events do not progress the team job")
	for index in state.BRUDET_TEAM_IDS["brudet_monster_team"].size():
		var enemy_id: String = state.BRUDET_TEAM_IDS["brudet_monster_team"][index]
		_check(state.record_team_defeat(enemy_id) and not state.record_team_defeat(enemy_id), "each monster target counts once: %s" % enemy_id)
	_check(state.team_defeated_ids.size() == 3 and state.active_job_ready("brudet_monster_team"), "three distinct monsters finish the team job")
	_check(not state.claim_job("mercenary", "brudet_monster_team"), "wrong issuer cannot pay Brudet team job")
	var reward := int(GameData.job("brudet_monster_team")["reward"])
	_check(state.claim_job("river_town_hall", "brudet_monster_team") and state.gold == reward, "town hall pays the monster team reward once")
	_check(state.team_job_id == "" and state.team_defeated_ids.is_empty() and not state.squad_deployed, "claiming releases Brudet team and clears target history")
	_check(not state.claim_job("river_town_hall", "brudet_monster_team") and state.accept_job("brudet_monster_team"), "monster team job repeats after claiming, without a second payment")
	_check(state.active_jobs["brudet_monster_team"] == 0 and state.team_defeated_ids.is_empty(), "repeat starts with no target progress")
	state.abandon_job("brudet_monster_team")
	_check(state.accept_job("brudet_bandit_team"), "abandoning a team job permits another Brudet team")
	state.abandon_job("brudet_bandit_team")
	_check(not state.accept_job("brudet_hacker_team") and state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "legacy hacker squad is unavailable for new acceptance, but solo bounty is offered")
	state.free()


func _test_brudet_solo_hacker() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	_check(not state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "Brudet solo hacker cannot be accepted on Paprika")
	state.add_gold(GameData.TRAVEL_FARE)
	_check(state.travel_to("brudet", Vector2(1050, 240)) and state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "Brudet Town Hall offers a solo hacker bounty")
	_check(GameData.job(state.BRUDET_SOLO_HACKER_JOB).get("event") == "hacker_defeated" and GameData.job(state.BRUDET_SOLO_HACKER_JOB).get("target_id") == state.BRUDET_SOLO_HACKER_ID, "solo bounty names the new marked hacker")
	_check(not state.accept_job("brudet_monster_team") and not state.accept_job("brudet_bandit_team") and not state.accept_job("brudet_hacker_team"), "an active solo hacker bounty blocks every Brudet squad job")
	_check(not state.record_event("hacker_defeated") and not state.record_solo_hacker_defeat("brudet_team_hacker_0") and not state.record_solo_hacker_defeat("unknown"), "generic kills and legacy hacker ID do not advance the solo bounty")
	_check(not state.active_job_ready(state.BRUDET_SOLO_HACKER_JOB) and state.record_solo_hacker_defeat(state.BRUDET_SOLO_HACKER_ID), "the marked Brudet hacker completes the solo bounty")
	_check(not state.record_solo_hacker_defeat(state.BRUDET_SOLO_HACKER_ID) and int(state.active_jobs[state.BRUDET_SOLO_HACKER_JOB]) == 1, "marked hacker cannot count twice")
	_check(not state.claim_job("mercenary", state.BRUDET_SOLO_HACKER_JOB), "Paprika mercenary cannot pay a Brudet bounty")
	var reward := int(GameData.job(state.BRUDET_SOLO_HACKER_JOB)["reward"])
	_check(state.claim_job("river_town_hall", state.BRUDET_SOLO_HACKER_JOB) and state.gold == reward and state.team_job_id == "", "Town Hall pays solo reward without requiring a squad")
	_check(not state.claim_job("river_town_hall", state.BRUDET_SOLO_HACKER_JOB) and state.accept_job(state.BRUDET_SOLO_HACKER_JOB) and state.active_jobs[state.BRUDET_SOLO_HACKER_JOB] == 0, "repeatable solo bounty restarts without paying twice")
	state.abandon_job(state.BRUDET_SOLO_HACKER_JOB)
	_check(state.accept_job("brudet_monster_team") and not state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "active Brudet squad blocks solo hacker acceptance")
	state.abandon_job("brudet_monster_team")
	_check(state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "abandoning the squad permits solo bounty acceptance")
	state.add_gold(GameData.TRAVEL_FARE)
	_check(state.travel_to("paprika", Vector2(1450, 706)) and not state.accept_job(state.ROAD_JOB), "active Brudet solo bounty blocks a Paprika squad after travel")
	state.free()


func _test_combat_job_hints() -> void:
	var state := GameStateScript.new()
	state.start_new_game()
	var notifications: Array[String] = []
	state.notification_requested.connect(func(message: String) -> void: notifications.append(message))
	for job_id in ["forest_patrol", "bandit_bounty", state.ROAD_JOB, state.CAMP_JOB, "hacker_bounty", "river_patrol", "brudet_monster_team", "brudet_bandit_team", "brudet_hacker_team", state.BRUDET_SOLO_HACKER_JOB]:
		var hint := String(GameData.job(job_id).get("location_hint", ""))
		_check(not hint.is_empty() and hint.length() > 20, "%s has a useful combat destination hint" % job_id)
	_check(state.accept_job("bandit_bounty") and notifications.back().contains(String(GameData.job("bandit_bounty")["location_hint"])), "accepted combat job includes its destination hint")
	_check(state.accept_job("field_work") and not notifications.back().contains("Search"), "non-combat work keeps the short acceptance notification")
	state.free()


func _test_brudet_save(state) -> void:
	state.start_new_game()
	state.add_gold(1000)
	_check(state.travel_to("brudet", Vector2(830, 1368)) and state.accept_job("brudet_bandit_team"), "Brudet save fixture accepts bandit team job")
	_check(state.recruit_villager("villager_river_01_45", Vector2(1400, 710)) and state.recruit_villager("villager_river_02_46", Vector2(1420, 710)) and state.deploy_squad(), "Brudet save fixture deploys local villagers")
	_check(state.record_team_defeat("brudet_team_bandit_0") and state.save_game(), "midmission Brudet team can be saved")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and saved.get("schema") == GameStateScript.SAVE_SCHEMA and saved.get("team_job_id") == "brudet_bandit_team" and saved.get("team_defeated_ids") == ["brudet_team_bandit_0"], "schema-nine save records Brudet team and casualty")
	if not saved is Dictionary:
		return
	var schema_six: Dictionary = saved.duplicate(true)
	schema_six["schema"] = 6
	schema_six["planet_positions"].erase("station")
	schema_six["planet_positions"].erase("artichoke")
	schema_six["planet_positions"].erase("pomidor")
	schema_six["planet_positions"].erase("chvarak")
	schema_six["planet_positions"].erase("engineeria")
	schema_six.erase("legacy_camp_roster")
	_check(state._valid_save(schema_six), "schema-six deployed Brudet team remains valid without schema-nine roster field")
	var schema_six_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(schema_six_file != null, "schema-six Brudet fixture can be written")
	if schema_six_file == null:
		return
	schema_six_file.store_string(JSON.stringify(schema_six))
	schema_six_file.close()
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "brudet" and state.team_job_id == "brudet_bandit_team" and state.squad_deployed and state.team_defeated_ids == ["brudet_team_bandit_0"], "schema-six reload restores deployed Brudet team and unique progress")
	_check(state.squad_recruits == ["villager_river_01_45", "villager_river_02_46"] and not state.legacy_camp_roster and not state.record_team_defeat("brudet_team_bandit_0"), "schema-six local recruit identities and counted target survive reload")
	_check(state.save_game(), "schema-six Brudet team migrates to schema nine")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(migrated is Dictionary and migrated.get("schema") == GameStateScript.SAVE_SCHEMA and migrated.get("team_defeated_ids") == ["brudet_team_bandit_0"] and migrated.get("legacy_camp_roster") == false, "schema-nine save keeps Brudet casualty and defaults legacy permission to false")
	if saved is Dictionary:
		var schema_five: Dictionary = saved.duplicate(true)
		schema_five["schema"] = 5
		schema_five["planet_positions"].erase("station")
		schema_five["planet_positions"].erase("artichoke")
		schema_five["planet_positions"].erase("pomidor")
		schema_five["planet_positions"].erase("chvarak")
		schema_five["planet_positions"].erase("engineeria")
		schema_five["current_planet"] = "paprika"
		schema_five["player_position"] = [830.0, 1368.0]
		schema_five["planet_positions"]["paprika"] = [830.0, 1368.0]
		schema_five["active_jobs"] = {}
		schema_five["tracked_job_id"] = ""
		schema_five["squad_deployed"] = false
		schema_five["squad_recruits"] = []
		schema_five["squad_members"] = {}
		schema_five["controlled_member_id"] = "player"
		schema_five["team_job_id"] = ""
		schema_five["team_defeated_ids"] = []
		schema_five["field_regrowth"] = {"paprika:51:74": 90.0}
		var file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
		_check(file != null, "schema-five Paprika fixture can be written")
		if file != null:
			file.store_string(JSON.stringify(schema_five))
			file.close()
			state.start_new_game()
			_check(state.load_game() and state.player_position == Vector2(830, 1368) and state.field_regrowth.has("paprika:51:74") and not state.field_regrowth.has("paprika:51:122"), "schema-five Paprika coordinates and fields do not migrate a second time")


func _test_road_save(state) -> void:
	state.start_new_game()
	_check(state.accept_job(state.ROAD_JOB) and state.recruit_villager("resident_00", Vector2(830, 1368)) and state.recruit_villager("villager1_37", Vector2(840, 1368)) and state.deploy_squad(), "road save fixture deploys two southern recruits")
	_check(state.record_road_defeat(state.ROAD_IDS[0]) and state.save_game(), "deployed road team with one marked kill can be saved")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and saved.get("schema") == GameStateScript.SAVE_SCHEMA and saved.get("team_job_id") == state.ROAD_JOB and saved.get("team_defeated_ids") == ["zombie_260"] and saved.get("legacy_camp_roster") == false, "schema-nine road save records mission, marked kill and roster permission")
	if not saved is Dictionary:
		return
	state.start_new_game()
	_check(state.load_game() and state.team_job_id == state.ROAD_JOB and state.squad_deployed and state.squad_recruits == ["resident_00", "villager1_37"] and state.active_jobs[state.ROAD_JOB] == 1 and state.team_defeated_ids == ["zombie_260"], "schema-nine reload restores southern road team and unique kill progress")
	_check(not state.record_road_defeat(state.ROAD_IDS[0]) and not state.record_road_defeat("zombie_261"), "duplicate and unmarked road kills remain rejected after reload")
	var missing_permission: Dictionary = saved.duplicate(true)
	missing_permission.erase("legacy_camp_roster")
	_check(not state._valid_save(missing_permission), "schema-nine save requires a legacy roster boolean")
	var wrong_permission: Dictionary = saved.duplicate(true)
	wrong_permission["legacy_camp_roster"] = true
	_check(not state._valid_save(wrong_permission), "road squad cannot use camp roster permission")
	var wrong_roster: Dictionary = saved.duplicate(true)
	wrong_roster["squad_recruits"][1] = "resident_24"
	wrong_roster["squad_members"]["resident_24"] = wrong_roster["squad_members"]["villager1_37"]
	wrong_roster["squad_members"].erase("villager1_37")
	_check(not state._valid_save(wrong_roster), "schema-nine road squad cannot contain a northern recruit")
	var duplicate: Dictionary = saved.duplicate(true)
	duplicate["team_defeated_ids"].append(state.ROAD_IDS[0])
	duplicate["active_jobs"][state.ROAD_JOB] = 2
	_check(not state._valid_save(duplicate), "schema-nine save rejects a duplicate marked road kill")
	var wrong_target: Dictionary = saved.duplicate(true)
	wrong_target["team_defeated_ids"][0] = "zombie_261"
	_check(not state._valid_save(wrong_target), "schema-nine save rejects an unmarked road zombie")
	var wrong_progress: Dictionary = saved.duplicate(true)
	wrong_progress["active_jobs"][state.ROAD_JOB] = 2
	_check(not state._valid_save(wrong_progress), "schema-nine road progress must match the unique marked kills")
	var undeployed: Dictionary = saved.duplicate(true)
	undeployed["squad_deployed"] = false
	_check(not state._valid_save(undeployed), "schema-nine save rejects road kills without deployment")
	var old_schema: Dictionary = saved.duplicate(true)
	old_schema["schema"] = 6
	old_schema["planet_positions"].erase("station")
	old_schema["planet_positions"].erase("artichoke")
	old_schema["planet_positions"].erase("pomidor")
	old_schema["planet_positions"].erase("chvarak")
	old_schema["planet_positions"].erase("engineeria")
	old_schema.erase("legacy_camp_roster")
	_check(not state._valid_save(old_schema), "road cleanup cannot appear in a schema-six save")
	var schema_seven: Dictionary = saved.duplicate(true)
	schema_seven["schema"] = 7
	schema_seven["planet_positions"].erase("station")
	schema_seven["planet_positions"].erase("artichoke")
	schema_seven["planet_positions"].erase("pomidor")
	schema_seven["planet_positions"].erase("chvarak")
	schema_seven["planet_positions"].erase("engineeria")
	schema_seven.erase("camp_unlocked")
	_check(state._valid_save(schema_seven), "schema-seven road save remains valid without the new camp unlock field")
	var legacy_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(legacy_file != null, "schema-seven road fixture can be written")
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify(schema_seven))
		legacy_file.close()
		state.start_new_game()
		_check(state.load_game() and state.team_job_id == state.ROAD_JOB and state.squad_deployed and state.team_defeated_ids == [state.ROAD_IDS[0]] and not state.camp_unlocked, "schema-seven road progress survives migration without prematurely unlocking the camp")
	_check(state.record_road_defeat(state.ROAD_IDS[1]) and state.record_road_defeat(state.ROAD_IDS[2]) and state.claim_job("mercenary", state.ROAD_JOB), "reloaded road squad finishes and claims at the southern office")
	_check(state.save_game(), "claimed road job can be saved without active team progress")
	var claimed = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(claimed is Dictionary and claimed.get("team_job_id") == "" and claimed.get("team_defeated_ids") == [] and claimed.get("camp_unlocked") == true and not claimed.get("active_jobs", {}).has(state.ROAD_JOB), "schema-nine road claim saves the camp unlock and releases recruits")
	state.start_new_game()
	_check(state.load_game() and state.camp_unlocked and state.accept_job(state.CAMP_JOB), "road claim unlock persists after reloading schema nine")
	_check(state.recruit_villager("resident_24", Vector2(1126, 390)) and state.recruit_villager("resident_25", Vector2(1250, 255)) and state.deploy_squad(), "reloaded camp can deploy without an earlier hacker defeat")
	for enemy_id in state.CAMP_IDS:
		state.record_camp_defeat(enemy_id)
	_check(state.claim_job("north_mercenary", state.CAMP_JOB) and state.save_game(), "claimed camp saves without a previous hacker defeat")
	var paid_camp = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(paid_camp is Dictionary and paid_camp.get("schema") == GameStateScript.SAVE_SCHEMA and paid_camp.get("completed_unique_jobs", []).has(state.CAMP_JOB) and not paid_camp.get("defeated_persistent_enemies", []).has("hacker_forest") and state._valid_save(paid_camp), "schema-nine completed camp needs the road unlock, not an old hacker kill")
	state.start_new_game()
	_check(state.load_game() and state.accept_job("hacker_bounty"), "schema-nine paid camp reload unlocks Paprika hacker bounty")


func _test_solo_save(state) -> void:
	state.start_new_game()
	state.add_gold(GameData.TRAVEL_FARE)
	_check(state.travel_to("brudet", Vector2(1050, 240)) and state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "solo hacker save fixture accepts the Brudet bounty")
	_check(state.record_solo_hacker_defeat(state.BRUDET_SOLO_HACKER_ID) and state.save_game(), "completed solo hacker bounty saves without a squad")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(saved is Dictionary and saved.get("schema") == GameStateScript.SAVE_SCHEMA and saved.get("active_jobs", {}).get(state.BRUDET_SOLO_HACKER_JOB) == 1 and saved.get("team_job_id") == "", "schema-nine save keeps the completed solo bounty")
	if not saved is Dictionary:
		return
	var old_schema: Dictionary = saved.duplicate(true)
	old_schema["schema"] = 7
	old_schema["planet_positions"].erase("station")
	old_schema["planet_positions"].erase("artichoke")
	old_schema["planet_positions"].erase("pomidor")
	old_schema["planet_positions"].erase("chvarak")
	old_schema["planet_positions"].erase("engineeria")
	old_schema.erase("camp_unlocked")
	_check(not state._valid_save(old_schema), "new solo hacker bounty cannot appear in a schema-seven save")
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "brudet" and state.active_job_ready(state.BRUDET_SOLO_HACKER_JOB) and not state.record_solo_hacker_defeat(state.BRUDET_SOLO_HACKER_ID), "reloaded solo completion does not count the target again")
	_check(state.claim_job("river_town_hall", state.BRUDET_SOLO_HACKER_JOB) and state.accept_job(state.BRUDET_SOLO_HACKER_JOB) and state.active_jobs[state.BRUDET_SOLO_HACKER_JOB] == 0, "claimed solo bounty restarts after reload")


func _test_legacy_hacker_save(state) -> void:
	state.start_new_game()
	_check(state.save_game(), "base save for a pre-schema-nine hacker bounty can be written")
	var legacy = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if not legacy is Dictionary:
		_check(false, "legacy Paprika hacker fixture is readable")
		return
	legacy["schema"] = 7
	legacy["planet_positions"].erase("station")
	legacy["planet_positions"].erase("artichoke")
	legacy["planet_positions"].erase("pomidor")
	legacy["planet_positions"].erase("chvarak")
	legacy["planet_positions"].erase("engineeria")
	legacy.erase("camp_unlocked")
	legacy["active_jobs"] = {"hacker_bounty": 0}
	legacy["tracked_job_id"] = "hacker_bounty"
	_check(state._valid_save(legacy), "schema-seven active Paprika hacker bounty remains valid before a camp claim")
	var file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "schema-seven active hacker fixture can be written")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.start_new_game()
	_check(state.load_game() and state.active_jobs.has("hacker_bounty") and not state.camp_unlocked, "old active hacker bounty stays active without granting a new camp entitlement")
	_check(state.record_event("hacker_defeated") and state.claim_job("mercenary", "hacker_bounty"), "old active hacker bounty can still finish and pay")
	_check(state.save_game(), "claimed legacy hacker bounty migrates to schema nine")
	var claimed = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(claimed is Dictionary and claimed.get("schema") == GameStateScript.SAVE_SCHEMA and claimed.get("camp_unlocked") == false and claimed.get("completed_unique_jobs", []).has("hacker_bounty"), "legacy hacker claim survives schema-nine serialization without an invented road claim")
	state.start_new_game()
	_check(state.save_game(), "base save for old hacker-defeat camp entitlement can be written")
	var defeated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if not defeated is Dictionary:
		return
	defeated["schema"] = 7
	defeated["planet_positions"].erase("station")
	defeated["planet_positions"].erase("artichoke")
	defeated["planet_positions"].erase("pomidor")
	defeated["planet_positions"].erase("chvarak")
	defeated["planet_positions"].erase("engineeria")
	defeated.erase("camp_unlocked")
	defeated["defeated_persistent_enemies"] = ["hacker_forest"]
	var old_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(old_file != null, "schema-seven defeated-hacker fixture can be written")
	if old_file == null:
		return
	old_file.store_string(JSON.stringify(defeated))
	old_file.close()
	state.start_new_game()
	_check(state.load_game() and state.camp_unlocked and state.accept_job(state.CAMP_JOB), "old hacker defeat retains its camp entitlement during migration")
	var paid_camp: Dictionary = defeated.duplicate(true)
	paid_camp["completed_unique_jobs"] = [state.CAMP_JOB]
	paid_camp["camp_defeated_ids"] = state.CAMP_IDS.duplicate()
	paid_camp["defeated_persistent_enemies"].append_array(state.CAMP_IDS)
	_check(state._valid_save(paid_camp), "schema-seven paid-camp save with an early hacker kill is valid")
	var paid_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(paid_file != null, "schema-seven paid-camp fixture can be written")
	if paid_file == null:
		return
	paid_file.store_string(JSON.stringify(paid_camp))
	paid_file.close()
	state.start_new_game()
	_check(state.load_game() and state.completed_unique_jobs.has(state.CAMP_JOB) and state.hacker_defeated(), "old camp claim and early hacker kill migrate together")
	_check(state.accept_job("hacker_bounty") and not state.defeated_persistent_enemies.has("hacker_forest"), "old early hacker kill cannot block the unlocked bounty and its target can respawn")
	_check(state.record_event("hacker_defeated") and state.active_job_ready("hacker_bounty"), "unpaid hacker bounty can be ready before abandonment")
	state.defeated_persistent_enemies.append("hacker_forest")
	state.abandon_job("hacker_bounty")
	_check(not state.active_jobs.has("hacker_bounty") and not state.defeated_persistent_enemies.has("hacker_forest") and state.accept_job("hacker_bounty"), "abandoning an unpaid hacker bounty clears its persistent target and permits accepting it again")


func _test_legacy_brudet_hacker_save(state) -> void:
	state.start_new_game()
	state.add_gold(GameData.TRAVEL_FARE)
	_check(state.travel_to("brudet", Vector2(1050, 240)) and state.accept_job("brudet_bandit_team"), "legacy Brudet hacker fixture starts with a valid team save")
	_check(state.recruit_villager("villager_river_01_45", Vector2(1400, 710)) and state.recruit_villager("villager_river_02_46", Vector2(1420, 710)) and state.deploy_squad() and state.save_game(), "Brudet legacy fixture preserves deployed local recruits")
	var legacy = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if not legacy is Dictionary:
		_check(false, "legacy Brudet hacker fixture is readable")
		return
	legacy["schema"] = 7
	legacy["planet_positions"].erase("station")
	legacy["planet_positions"].erase("artichoke")
	legacy["planet_positions"].erase("pomidor")
	legacy["planet_positions"].erase("chvarak")
	legacy["planet_positions"].erase("engineeria")
	legacy.erase("camp_unlocked")
	legacy["active_jobs"] = {"brudet_hacker_team": 0}
	legacy["tracked_job_id"] = "brudet_hacker_team"
	legacy["team_job_id"] = "brudet_hacker_team"
	_check(state._valid_save(legacy), "schema-seven active legacy hacker squad remains valid")
	var file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "schema-seven hacker squad fixture can be written")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.start_new_game()
	_check(state.load_game() and state.team_job_id == "brudet_hacker_team" and state.squad_deployed and state.squad_recruits.size() == 2, "legacy deployed hacker squad keeps its job and recruits")
	_check(not state.accept_job(state.BRUDET_SOLO_HACKER_JOB) and state.record_team_defeat("brudet_team_hacker_0"), "active legacy hacker squad excludes solo bounty and can defeat its original target")
	_check(state.save_game(), "active legacy hacker squad serializes as schema nine")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(migrated is Dictionary and migrated.get("schema") == GameStateScript.SAVE_SCHEMA and migrated.get("team_job_id") == "brudet_hacker_team" and migrated.get("team_defeated_ids") == ["brudet_team_hacker_0"], "schema nine keeps old active hacker squad progress")
	_check(state.claim_job("river_town_hall", "brudet_hacker_team") and not state.accept_job("brudet_hacker_team") and state.accept_job(state.BRUDET_SOLO_HACKER_JOB), "legacy hacker squad can claim once; only solo bounty can start next")
	_check(state.save_game(), "new solo bounty can be saved after claiming the old hacker squad")
	var solo = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(solo is Dictionary and solo.get("active_jobs", {}).has(state.BRUDET_SOLO_HACKER_JOB) and solo.get("team_job_id") == "", "schema-nine solo bounty is independent of the old team targets")
	var invalid_both: Dictionary = solo.duplicate(true) if solo is Dictionary else {}
	if solo is Dictionary:
		invalid_both["active_jobs"]["brudet_monster_team"] = 0
		_check(not state._valid_save(invalid_both), "schema-nine save rejects simultaneous solo and team missions")


func _test_military_save(state) -> void:
	state.start_new_game()
	state.add_gold(GameData.TRAVEL_FARE)
	_check(state.travel_to("brudet", Vector2(660, 1250)) and state.save_game(), "Brudet save can become a two-planet fixture")
	var old = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if not old is Dictionary:
		_check(false, "old fixture is readable")
		return
	old["schema"] = 8
	old["planet_positions"].erase("station")
	old["planet_positions"].erase("artichoke")
	old["planet_positions"].erase("pomidor")
	old["planet_positions"].erase("chvarak")
	old["planet_positions"].erase("engineeria")
	for key in ["current_area", "military_barracks_position", "military_stage", "military_storage", "military_stored_equipment", "military_meal_credits", "military_cannon_hits", "military_trap_progress"]:
		old.erase(key)
	_check(state._valid_save(old), "schema-nine save validates with two planets")
	var bad_old: Dictionary = old.duplicate(true)
	bad_old["planet_positions"]["station"] = [224.0, 384.0]
	_check(not state._valid_save(bad_old), "schema nine rejects an added station position")
	var file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "brudet" and state.military_stage == "none" and state.planet_positions["station"] == [224.0, 384.0], "schema nine migrates to fresh military defaults")
	_check(state.enlist_military(Vector2(1500, 720)) and state.military_claim_uniform() and state.enter_military_barracks(Vector2(230, 400)) and state.military_store_gear(), "training fixture stores personal gear")
	state.remember_player_position(Vector2(263, 341))
	_check(state.save_game(), "barracks checkpoint saves")
	var interior = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	_check(interior is Dictionary and interior.get("schema") == GameStateScript.SAVE_SCHEMA and interior.get("player_position") == [263.0, 341.0] and interior.get("planet_positions", {}).get("station") == [230.0, 400.0], "schema nine keeps separate exterior and barracks coordinates")
	state.start_new_game()
	_check(state.load_game() and state.current_area == "barracks" and state.military_storage == {"stick": 1, "bread": 1} and state.planet_positions["station"] == [230.0, 400.0], "barracks reload retains stored items and exterior coordinates")
	_check(state.exit_military_barracks(Vector2(263, 341)) and state.military_complete_drill("run") and state.weapon_definition() == GameData.item("training_club") and state.inventory == {"military_uniform": 1, "training_club": 1} and state.save_game(), "sparring save owns one equipped training club")
	var spar = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if spar is Dictionary:
		var duplicate_club: Dictionary = spar.duplicate(true)
		duplicate_club["inventory"]["training_club"] = 2
		_check(not state._valid_save(duplicate_club), "two training clubs are rejected")
		var missing_club: Dictionary = spar.duplicate(true)
		missing_club["inventory"].erase("training_club")
		_check(not state._valid_save(missing_club), "equipped training club requires its owned copy")
	_check(state.military_complete_drill("spar") and state.military_complete_drill("squad") and state.weapon_definition() == GameData.item("training_bow") and state.inventory == {"military_uniform": 1, "training_bow": 1} and state.save_game(), "range save owns one equipped projectile bow")
	var range_data = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if range_data is Dictionary:
		var double_weapon: Dictionary = range_data.duplicate(true)
		double_weapon["inventory"]["training_club"] = 1
		_check(not state._valid_save(double_weapon), "range cannot keep a second issued training weapon")
		var hidden_weapon: Dictionary = range_data.duplicate(true)
		hidden_weapon["military_storage"]["training_club"] = 1
		_check(not state._valid_save(hidden_weapon), "station-only training gear cannot be deposited in the chest")
		var older_range: Dictionary = range_data.duplicate(true)
		older_range["max_health"] = GameData.STARTING_MAX_HEALTH
		older_range["health"] = GameData.STARTING_MAX_HEALTH - 2
		var older_range_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
		_check(older_range_file != null, "older squad-bout save fixture can be written")
		if older_range_file != null:
			older_range_file.store_string(JSON.stringify(older_range))
			older_range_file.close()
			state.start_new_game()
			_check(state.load_game() and state.military_stage == "range" and state.max_health == 24 and state.health == 18, "older post-bout saves gain the 24-health maximum without healing damage")
	_check(state.military_complete_drill("range") and state.military_start_cannon_round() and state.military_take_cannon_charge() and state.military_load_cannon() and state.save_game(), "loaded cannon round saves before any hit is recorded")
	var cannon = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if cannon is Dictionary:
		_check(state._valid_save(cannon) and cannon.get("schema") == GameStateScript.SAVE_SCHEMA and cannon.get("military_cannon_phase") == "loaded", "schema-ten partial cannon round is valid and stored as loaded")
		var duplicate: Dictionary = cannon.duplicate(true)
		duplicate["military_cannon_hits"] = ["cannon_target_0", "cannon_target_0"]
		_check(not state._valid_save(duplicate), "duplicate cannon targets are rejected")
		var inactive_phase: Dictionary = cannon.duplicate(true)
		inactive_phase["military_cannon_round_active"] = false
		_check(not state._valid_save(inactive_phase), "inactive cannon round cannot keep a carried or loaded phase")
		var wrong_stage: Dictionary = cannon.duplicate(true)
		wrong_stage["military_stage"] = "trap"
		_check(not state._valid_save(wrong_stage), "active cannon round is valid only during cannon practice")
		var doubled: Dictionary = cannon.duplicate(true)
		doubled["inventory"]["stick"] = 1
		_check(not state._valid_save(doubled), "the chest and inventory cannot both hold stored gear")
		var credits: Dictionary = cannon.duplicate(true)
		credits["military_meal_credits"] = 7
		_check(not state._valid_save(credits), "canteen credits cannot exceed earned meals")
		for field in ["current_area", "military_stage", "military_storage", "military_barracks_position", "military_stored_equipment", "military_meal_credits", "military_cannon_hits", "military_trap_progress", "military_cannon_round_active", "military_cannon_phase", "military_trap_round_active", "military_trap_equipped", "military_trap_mine_position"]:
			var missing: Dictionary = cannon.duplicate(true)
			missing.erase(field)
			_check(not state._valid_save(missing), "schema-ten save requires %s" % field)
		state.start_new_game()
		_check(state.load_game() and state.military_cannon_round_active and state.military_cannon_phase == "loaded" and state.military_cannon_hits.is_empty(), "loaded cannon round and unfired progress survive reload")
		var old_station_save: Dictionary = cannon.duplicate(true)
		old_station_save["schema"] = GameStateScript.STATION_SAVE_SCHEMA
		old_station_save["planet_positions"].erase("artichoke")
		old_station_save["planet_positions"].erase("pomidor")
		old_station_save["planet_positions"].erase("chvarak")
		old_station_save["planet_positions"].erase("engineeria")
		old_station_save["military_cannon_hits"] = ["cannon_target_0"]
		for field in ["military_cannon_round_active", "military_cannon_phase", "military_trap_round_active", "military_trap_equipped", "military_trap_mine_position"]:
			old_station_save.erase(field)
		_check(state._valid_save(old_station_save), "schema-nine station save remains valid without round fields")
		var old_file := FileAccess.open(GameStateScript.SAVE_PATH, FileAccess.WRITE)
		_check(old_file != null, "schema-nine station fixture can be written")
		if old_file != null:
			old_file.store_string(JSON.stringify(old_station_save))
			old_file.close()
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "station" and state.military_stage == "cannon" and state.military_cannon_hits == ["cannon_target_0"] and state.planet_positions["station"] == cannon["planet_positions"]["station"] and not state.military_cannon_round_active and state.military_cannon_phase == "empty", "schema-nine station save keeps hit progress and positions with inactive round defaults")
	_check(state.save_game(), "schema-nine station progress can be written in schema ten")
	state.start_new_game()
	_check(state.load_game() and state.military_stage == "cannon" and state.military_cannon_hits == ["cannon_target_0"] and state.military_cannon_phase == "empty" and state.military_meal_credits == 4, "schema-nine cannon progress and inactive default phase survive schema-ten reload")
	_check(state.military_start_cannon_round() and state.military_take_cannon_charge() and state.military_load_cannon() and state.military_record_cannon_hit("cannon_target_1"), "loaded cannon shot records after schema-nine reload")
	_check(state.military_take_cannon_charge() and state.military_load_cannon() and state.military_record_cannon_hit("cannon_target_2"), "remaining cannon hit completes the three-target drill")
	_check(state.military_stage == "trap" and state.military_start_trap_round() and state.save_game(), "held practice mine and active trap round save")
	var held_trap = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if held_trap is Dictionary:
		_check(state._valid_save(held_trap) and held_trap.get("inventory", {}).get("practice_mine") == 1, "held-mine partial trap save is valid")
		var missing_mine: Dictionary = held_trap.duplicate(true)
		missing_mine["inventory"].erase("practice_mine")
		_check(not state._valid_save(missing_mine), "active unplaced trap round requires one inventory mine")
		var doubled_mine: Dictionary = held_trap.duplicate(true)
		doubled_mine["inventory"]["practice_mine"] = 2
		_check(not state._valid_save(doubled_mine), "trap round rejects duplicate held mines")
		var stored_mine: Dictionary = held_trap.duplicate(true)
		stored_mine["military_storage"]["practice_mine"] = 1
		_check(not state._valid_save(stored_mine), "practice mine cannot be moved into the personal chest")
	state.start_new_game()
	_check(state.load_game() and state.military_trap_round_active and not state.military_trap_equipped and state.inventory.get("practice_mine") == 1, "held practice mine survives reload exactly once")
	_check(state.military_equip_practice_mine() and state.military_place_practice_mine(Vector2(880, 1020)) and state.save_game(), "placed practice mine and active trap round save")
	var placed_trap = JSON.parse_string(FileAccess.get_file_as_string(GameStateScript.SAVE_PATH))
	if placed_trap is Dictionary:
		_check(state._valid_save(placed_trap) and not placed_trap.get("inventory", {}).has("practice_mine") and placed_trap.get("military_trap_mine_position") == [880.0, 1020.0], "placed-mine partial trap save is valid")
		var both_mines: Dictionary = placed_trap.duplicate(true)
		both_mines["inventory"]["practice_mine"] = 1
		_check(not state._valid_save(both_mines), "trap save cannot contain held and placed copies")
		var equipped_placed: Dictionary = placed_trap.duplicate(true)
		equipped_placed["military_trap_equipped"] = true
		_check(not state._valid_save(equipped_placed), "placed mine cannot remain equipped")
		var missing_position: Dictionary = placed_trap.duplicate(true)
		missing_position["military_trap_mine_position"] = []
		_check(not state._valid_save(missing_position), "active trap round without a held mine needs a saved position")
	state.start_new_game()
	_check(state.load_game() and state.military_trap_round_active and state.military_trap_mine_placed() and state.inventory.get("practice_mine", 0) == 0, "placed practice mine position survives reload without an inventory copy")
	_check(state.military_record_trap_step("trap_0") and state.save_game(), "first ordered trap step saves without another mine")
	state.start_new_game()
	_check(state.load_game() and state.military_trap_progress == 1 and not state.military_trap_round_active and not state.military_record_trap_step("trap_0"), "trap progress survives reload and requires a new round")
	_check(state.military_start_trap_round() and state.military_equip_practice_mine() and state.military_place_practice_mine(Vector2(900, 1020)) and state.military_record_trap_step("trap_1"), "second ordered trap round completes after a placement")
	_check(state.military_start_trap_round() and state.military_equip_practice_mine() and state.military_place_practice_mine(Vector2(920, 1020)) and state.military_record_trap_step("trap_2") and state.military_stage == "sleep", "third ordered trap round completes training")
	_check(state.enter_military_barracks(Vector2(241, 405)) and state.military_sleep() and state.save_game(), "graduation saves with stored gear")
	state.start_new_game()
	_check(state.load_game() and state.military_stage == "graduated" and state.military_storage == {"stick": 1, "bread": 1}, "graduation reload retains the chest")
	_check(state.exit_military_barracks(Vector2(261, 345)) and state.return_from_military(Vector2(241, 405)) and state.military_storage == {"stick": 1, "bread": 1}, "ship return leaves belongings in the chest")
	_check(state.add_item("wood_sword") and state.equip_item("wood_sword") and state.save_game(), "graduated return can equip new Brudet gear while the chest remains stored")
	state.start_new_game()
	_check(state.load_game() and state.current_planet == "brudet" and state.military_stage == "graduated" and state.military_storage == {"stick": 1, "bread": 1} and state.inventory.get("wood_sword") == 1, "Brudet reload keeps stored gear separate from newly acquired items")
	_check(state.enlist_military(Vector2(1500, 720)) and state.military_stage == "graduated" and state.enter_military_barracks(Vector2(241, 405)) and state.military_withdraw_gear() and state.equipment["weapon"] == "stick" and state.inventory.get("wood_sword") == 1 and state.inventory.get("stick") == 1 and state.save_game(), "return visit restores chest contents once without deleting newly acquired gear")
	state.start_new_game()
	_check(state.load_game() and state.military_stage == "graduated" and state.inventory.get("military_uniform") == 1 and state.inventory.get("stick") == 1 and state.inventory.get("wood_sword") == 1 and state.military_storage.is_empty(), "graduated chest retrieval survives another reload")
