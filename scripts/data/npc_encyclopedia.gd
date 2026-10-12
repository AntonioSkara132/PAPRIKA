class_name NpcEncyclopedia
extends RefCounted

const CATEGORIES := ["Wildlife", "Other hostiles", "Hackers", "Republic forces", "Residents & staff", "Allies"]

const HOSTILES := [
	["wolf", "Wildlife", "Paprika", "art/concepts/source/wolf.png", "A great wolf prowling beyond the village paths."],
	["zombie", "Other hostiles", "Paprika", "assets/art/zombie.png", "An undead wanderer found outside the settled fields."],
	["zombie_bear", "Wildlife", "Paprika", "assets/art/zombie_bear.png", "A large bear that still roams after death."],
	["armed_zombie", "Other hostiles", "Paprika", "assets/art/river_planet/armed_zombie.png", "A zombie carrying a weapon."],
	["armored_zombie", "Other hostiles", "Paprika", "assets/art/river_planet/armored_zombie.png", "A zombie whose armor absorbs part of a hit."],
	["bandit_spear", "Other hostiles", "Paprika / Brudet", "assets/art/bandit.png", "A bandit who keeps opponents at spear length."],
	["bandit_bow", "Other hostiles", "Paprika / Brudet", "assets/art/bandit.png", "A bandit who attacks from a distance with a bow."],
	["bandit_sword", "Other hostiles", "Paprika / Brudet", "assets/art/bandit.png", "A bandit who closes in with a sword."],
	["hacker", "Hackers", "Paprika / Chvarak", "assets/art/hacker.png", "A dangerous fighter capable of far more than ordinary combat."],
	["phase_hacker", "Hackers", "Brudet / Chvarak", "assets/art/hacker.png", "A hacker who changes position during a fight."],
	["finling", "Wildlife", "Brudet", "assets/art/river_planet/finling.png", "A small creature found near Brudet's water."],
	["lake_maw", "Wildlife", "Brudet", "assets/art/river_planet/lake_maw.png", "A heavy predator of the lakeside."],
	["river_serpent", "Wildlife", "Brudet", "assets/art/river_planet/river_serpent.png", "A river predator that can strike from a distance."],
	["collector", "Other hostiles", "Pomidor", "assets/art/pomidor/collector_0.png", "An enforcer sent to collect debts."],
	["forest_beast", "Wildlife", "Engineeria", "assets/art/engineeria/forest_beast.png", "A fast predator in Engineeria's forest."],
	["sea_creature", "Wildlife", "Skoljka", "assets/art/skoljka/sea_creature.png", "A hostile creature in the waters around Skoljka."],
	["company_crew", "Other hostiles", "Skoljka", "assets/art/skoljka/company_crew.png", "An armed company worker guarding its operations."],
	["company_assassin", "Other hostiles", "Skoljka", "assets/art/skoljka/company_crew_tool.png", "An attacker encountered during Skoljka's troubles."],
	["republic_archer", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_soldier.png", "A Republic soldier who fires from range."],
	["republic_spearman", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_soldier_2.png", "A Republic soldier armed with a spear."],
	["republic_swordsman", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_soldier_3.png", "A Republic soldier who fights with a sword."],
	["republic_guardsman", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_guardsman.png", "A heavily armored Republic defender."],
]

const PEOPLE := [
	["villager", "Resident", "Residents & staff", "Paprika / Brudet", "art/concepts/source/villager1.png", "Residents tend fields, trade, and follow their daily routes.", "Health 12  ·  Walking speed 30"],
	["rabbit", "Rabbit", "Wildlife", "Paprika", "art/concepts/source/rabbit.png", "A quick animal that can be caught or hunted.", "Walking speed 24  ·  Fleeing speed 42"],
	["chvarak_farmer", "Mountain farmer", "Residents & staff", "Chvarak", "assets/art/chvarak/farmer_0.png", "Farmers work Chvarak's mountain fields and pastures.", "Combat stats not defined"],
	["cow", "Cow", "Wildlife", "Chvarak", "assets/art/chvarak/cow_0.png", "Cattle graze in the mountain pastures.", "Combat stats not defined"],
	["pig", "Pig", "Wildlife", "Chvarak", "assets/art/chvarak/pig_0.png", "Pigs live around Chvarak's farms.", "Combat stats not defined"],
	["chvarak_guard", "Port guard", "Allies", "Chvarak", "assets/art/chvarak/chvarak_guard.png", "A guard stationed near the mountain port.", "Combat stats not defined"],
	["ship_guard", "Ship guard", "Allies", "Chvarak", "assets/art/chvarak/ship_guard_0.png", "A guard protecting a ship's crew.", "Stats vary by encounter"],
	["councillor", "Councillor", "Residents & staff", "Pomidor", "assets/art/pomidor/councillor_pomidor_0.png", "One of the delegates serving on the Confederation's council.", "Combat stats not defined"],
	["secretary", "Secretary", "Residents & staff", "Pomidor", "assets/art/pomidor/secretary_economy.png", "A council-appointed official responsible for an area of government.", "Combat stats not defined"],
	["council_guard", "Council guard", "Allies", "Pomidor", "assets/art/pomidor/council_guard.png", "A guard at the council buildings.", "Combat stats not defined"],
	["engineer", "Engineer", "Residents & staff", "Engineeria", "assets/art/engineeria/davor.png", "An Engineeria resident working among the city's workshops.", "Combat stats not defined"],
	["skoljka_citizen", "Skoljka resident", "Residents & staff", "Skoljka", "assets/art/skoljka/person_citizen_0.png", "A resident living in Skoljka's underwater city.", "Combat stats not defined"],
	["skoljka_worker", "Pump worker", "Residents & staff", "Skoljka", "assets/art/skoljka/person_worker_0.png", "A worker keeping the city's machinery running.", "Combat stats not defined"],
	["skoljka_staff", "City staff", "Residents & staff", "Skoljka", "assets/art/skoljka/person_port_officer.png", "Port and service staff help the city operate.", "Combat stats not defined"],
	["recruit", "Military recruit", "Allies", "Training station", "assets/art/space_military_base/station_recruit_elia.png", "A recruit training alongside the player.", "Stats vary by training exercise"],
	["station_staff", "Station staff", "Residents & staff", "Training station", "assets/art/space_military_base/confederation_officer.png", "Officers and staff oversee training at the station.", "Combat stats not defined"],
	["confederation_soldier", "Confederation soldier", "Allies", "Artichoke", "assets/art/artichoke/objects/front_soldier.png", "A soldier serving at the Artichoke front.", "Combat stats not defined for stationary troops"],
	["squad_soldier", "Squad soldier", "Allies", "Artichoke", "assets/art/artichoke/objects/front_soldier_2.png", "A squad member who follows orders and fights alongside the player.", "Base health 30  ·  Movement speed 74  ·  Equipment and damage vary"],
]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in HOSTILES:
		var enemy_id: String = row[0]
		if GameData.enemy(enemy_id).is_empty():
			continue
		result.append({"id": enemy_id, "name": GameData.enemy(enemy_id).get("name", enemy_id), "category": row[1], "location": row[2], "image": "res://" + row[3], "intro": row[4], "enemy_id": enemy_id})
	result.append({"id": "martin_spy", "name": "Martin's Spy", "category": "Other hostiles", "location": "Skoljka", "image": "res://assets/art/skoljka/company_crew.png", "intro": "A spy sent by Martin to guard the pump chambers.", "enemy_id": "company_crew"})
	for row in PEOPLE:
		result.append({"id": row[0], "name": row[1], "category": row[2], "location": row[3], "image": "res://" + row[4], "intro": row[5], "facts": row[6]})
	return result

static func stats(entry: Dictionary) -> String:
	if not entry.has("enemy_id"):
		return String(entry.get("facts", "Combat stats not defined"))
	var definition := GameData.enemy(String(entry["enemy_id"]))
	var reward: int = 0 if entry["id"] == "company_assassin" else int(definition.get("reward", 0))
	var text := "Level %d  ·  Health %d  ·  Damage %d\nSpeed %s  ·  Armor %d  ·  Reward %d gold" % [definition.get("level", 0), definition.get("max_health", 0), definition.get("damage", 0), str(definition.get("speed", 0)), definition.get("armor", 0), reward]
	if definition.has("reach"):
		text += "\nReach %s" % str(definition["reach"])
	if entry["id"] in ["bandit_spear", "bandit_bow", "bandit_sword"]:
		text += "\nCamp bandits use these weapon profiles; rewards depend on encounter."
	if entry["id"] == "hacker":
		text += "\nChvarak encounter: level 7, 150 health, 24 damage."
	elif entry["id"] == "phase_hacker":
		text += "\nChvarak encounter: level 7, 130 health, 18 damage."
	return text
