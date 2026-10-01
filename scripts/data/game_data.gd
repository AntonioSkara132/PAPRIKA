class_name GameData
extends RefCounted

const STARTING_MAX_HEALTH := 20
const FIELD_REGROWTH_SECONDS := 120.0
const TRAVEL_FARE := 1000

const ITEMS := {
	"potato": {"name": "Potato", "kind": "produce", "buy": 0, "sell": 2},
	"carrot": {"name": "Carrot", "kind": "produce", "buy": 0, "sell": 2},
	"tomato": {"name": "Tomato", "kind": "produce", "buy": 0, "sell": 3},
	"grape": {"name": "Grapes", "kind": "produce", "buy": 0, "sell": 3},
	"rabbit_meat": {"name": "Rabbit Meat", "kind": "produce", "buy": 0, "sell": 7},
	"bread": {"name": "Bread", "kind": "food", "buy": 5, "sell": 2, "heal": 6},
	"stew": {"name": "Vegetable Stew", "kind": "food", "buy": 12, "sell": 5, "heal": 14},
	"stick": {"name": "Sturdy Stick", "kind": "weapon", "buy": 0, "power": 1, "reach": 24.0, "cooldown": 0.52},
	"militia_club": {"name": "Militia Club", "kind": "weapon", "buy": 0, "power": 1, "reach": 24.0, "cooldown": 0.55},
	"wood_sword": {"name": "Wooden Sword", "kind": "weapon", "buy": 20, "power": 1, "reach": 27.0, "cooldown": 0.40},
	"bronze_sword": {"name": "Bronze Sword", "kind": "weapon", "buy": 85, "power": 2, "reach": 29.0, "cooldown": 0.36},
	"iron_sword": {"name": "Iron Sword", "kind": "weapon", "buy": 250, "power": 3, "reach": 31.0, "cooldown": 0.32},
	"wood_spear": {"name": "Wooden Spear", "kind": "weapon", "buy": 32, "power": 1, "reach": 42.0, "cooldown": 0.65},
	"bronze_spear": {"name": "Bronze Spear", "kind": "weapon", "buy": 110, "power": 2, "reach": 46.0, "cooldown": 0.60},
	"iron_spear": {"name": "Iron Spear", "kind": "weapon", "buy": 300, "power": 3, "reach": 50.0, "cooldown": 0.54},
	"wood_bow": {"name": "Wooden Bow", "kind": "weapon", "buy": 45, "power": 1, "reach": 150.0, "cooldown": 0.72, "ranged": true},
	"bronze_bow": {"name": "Bronze Bow", "kind": "weapon", "buy": 135, "power": 2, "reach": 170.0, "cooldown": 0.66, "ranged": true},
	"iron_bow": {"name": "Iron Bow", "kind": "weapon", "buy": 340, "power": 3, "reach": 190.0, "cooldown": 0.58, "ranged": true},
	"wood_armor": {"name": "Wooden Armor", "kind": "armor", "buy": 30, "protection": 1},
	"bronze_armor": {"name": "Bronze Armor", "kind": "armor", "buy": 120, "protection": 2},
	"iron_armor": {"name": "Iron Armor", "kind": "armor", "buy": 360, "protection": 3},
	"red_tunic": {"name": "Red Villager Tunic", "kind": "clothing", "buy": 18, "color": "red"},
	"blue_tunic": {"name": "Blue Villager Tunic", "kind": "clothing", "buy": 18, "color": "blue"},
	"green_tunic": {"name": "Green Villager Tunic", "kind": "clothing", "buy": 18, "color": "green"},
}

const JOBS := {
	"field_work": {
		"name": "Help in the Common Fields",
		"description": "Harvest five ready crops in the common fields.",
		"event": "common_crop_harvested",
		"target": 5,
		"reward": 10,
		"issuer": "work_office",
		"repeatable": true,
	},
	"rabbit_catch": {
		"name": "Catch Five Rabbits",
		"description": "Catch five rabbits in the forest without harming them.",
		"event": "rabbit_caught",
		"target": 5,
		"reward": 25,
		"issuer": "work_office",
		"repeatable": true,
	},
	"forest_patrol": {
		"name": "Clear Forest Monsters",
		"description": "Defeat three monsters threatening the forest road.",
		"event": "monster_defeated",
		"target": 3,
		"reward": 65,
		"issuer": "mercenary",
		"repeatable": true,
	},
	"bandit_bounty": {
		"name": "Bandit Bounty",
		"description": "Defeat a bandit beyond the old forest sign.",
		"event": "bandit_defeated",
		"target": 1,
		"reward": 110,
		"issuer": "mercenary",
		"repeatable": true,
	},
	"hacker_bounty": {
		"name": "The Hacker",
		"description": "Defeat the level-five hacker. Iron equipment is advised.",
		"event": "hacker_defeated",
		"target": 1,
		"reward": 500,
		"issuer": "mercenary",
		"repeatable": false,
	},
	"bandit_camp": {
		"name": "Clear the Bandit Camp",
		"description": "Recruit two villagers and defeat three distinct bandits at their camp.",
		"event": "camp_bandit_defeated",
		"target": 3,
		"reward": 350,
		"issuer": "mercenary",
		"repeatable": false,
	},
}

const ENEMIES := {
	"wolf": {"name": "Great Wolf", "level": 2, "max_health": 15, "damage": 4, "speed": 48.0, "event": "monster_defeated", "reward": 4},
	"zombie": {"name": "Zombie", "level": 2, "max_health": 20, "damage": 5, "speed": 31.0, "event": "monster_defeated", "reward": 5},
	"zombie_bear": {"name": "Zombified Bear", "level": 2, "max_health": 32, "damage": 7, "speed": 35.0, "event": "monster_defeated", "reward": 10},
	"bandit": {"name": "Bandit", "level": 3, "max_health": 38, "damage": 9, "speed": 52.0, "event": "bandit_defeated", "reward": 20},
	"camp_bandit": {"name": "Camp Bandit", "level": 3, "max_health": 32, "damage": 7, "speed": 45.0, "event": "bandit_defeated", "reward": 12},
	"hacker": {"name": "Hacker", "level": 5, "max_health": 110, "damage": 18, "speed": 58.0, "event": "hacker_defeated", "reward": 100},
}

const CROP_BY_TILE_ID := {
	8: "potato",
	9: "carrot",
	10: "tomato",
	11: "grape",
}

static func item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func job(job_id: String) -> Dictionary:
	return JOBS.get(job_id, {})

static func enemy(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, {})
