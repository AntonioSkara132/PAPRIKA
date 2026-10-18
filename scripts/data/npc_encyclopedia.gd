class_name NpcEncyclopedia
extends RefCounted

const CATEGORIES := ["Allies", "Cauliflower Confederation", "Engineeria", "Republic forces", "Julius Organization", "Other hostiles", "Wildlife"]

const HOSTILES := [
	["wolf", "Wildlife", "Paprika", "art/concepts/source/wolf.png", "A great wolf prowling beyond the village paths."],
	["zombie", "Other hostiles", "Paprika", "assets/art/zombie.png", "An undead wanderer found outside the settled fields."],
	["zombie_bear", "Wildlife", "Paprika", "assets/art/zombie_bear.png", "A large bear that still roams after death."],
	["armed_zombie", "Other hostiles", "Paprika", "assets/art/river_planet/armed_zombie.png", "A zombie carrying a weapon."],
	["armored_zombie", "Other hostiles", "Paprika", "assets/art/river_planet/armored_zombie.png", "A zombie whose armor absorbs part of a hit."],
	["bandit_spear", "Other hostiles", "Paprika / Brudet", "assets/art/bandit.png", "A bandit who keeps opponents at spear length."],
	["bandit_bow", "Other hostiles", "Paprika / Brudet", "assets/art/bandit.png", "A bandit who attacks from a distance with a bow."],
	["bandit_sword", "Other hostiles", "Paprika / Brudet", "assets/art/bandit.png", "A bandit who closes in with a sword."],
	["hacker", "Other hostiles", "Paprika / Chvarak", "assets/art/hacker.png", "A dangerous fighter capable of far more than ordinary combat."],
	["phase_hacker", "Other hostiles", "Brudet / Chvarak", "assets/art/hacker.png", "A hacker who changes position during a fight."],
	["finling", "Wildlife", "Brudet", "assets/art/river_planet/finling.png", "A small creature found near Brudet's water."],
	["lake_maw", "Wildlife", "Brudet", "assets/art/river_planet/lake_maw.png", "A heavy predator of the lakeside."],
	["river_serpent", "Wildlife", "Brudet", "assets/art/river_planet/river_serpent.png", "A river predator that can strike from a distance."],
	["collector", "Julius Organization", "Pomidor", "assets/art/pomidor/collector_0.png", "An enforcer sent to collect debts."],
	["forest_beast", "Wildlife", "Engineeria", "assets/art/engineeria/forest_beast.png", "A fast predator in Engineeria's forest."],
	["sea_creature", "Wildlife", "Skoljka", "assets/art/skoljka/sea_creature.png", "A hostile creature in the waters around Skoljka."],
	["company_crew", "Republic forces", "Skoljka", "assets/art/skoljka/company_crew.png", "An armed company worker guarding its operations."],
	["company_assassin", "Republic forces", "Skoljka", "assets/art/skoljka/company_crew_tool.png", "An attacker encountered during Skoljka's troubles."],
	["republic_archer", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_soldier.png", "A Republic soldier who fires from range."],
	["republic_spearman", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_soldier_2.png", "A Republic soldier armed with a spear."],
	["republic_swordsman", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_soldier_3.png", "A Republic soldier who fights with a sword."],
	["republic_guardsman", "Republic forces", "Artichoke", "assets/art/artichoke/objects/republic_guardsman.png", "A heavily armored Republic defender."],
]

const PEOPLE := [
	["villager", "Resident", "Cauliflower Confederation", "Paprika / Brudet", "art/concepts/source/villager1.png", "Residents tend fields, trade, and follow their daily routes.", "Health 12  ·  Walking speed 30"],
	["rabbit", "Rabbit", "Wildlife", "Paprika", "art/concepts/source/rabbit.png", "A quick animal that can be caught or hunted.", "Walking speed 24  ·  Fleeing speed 42"],
	["chvarak_farmer", "Mountain farmer", "Cauliflower Confederation", "Chvarak", "assets/art/chvarak/farmer_0.png", "Farmers work Chvarak's mountain fields and pastures.", "Combat stats not defined"],
	["cow", "Cow", "Wildlife", "Chvarak", "assets/art/chvarak/cow_0.png", "Cattle graze in the mountain pastures.", "Combat stats not defined"],
	["pig", "Pig", "Wildlife", "Chvarak", "assets/art/chvarak/pig_0.png", "Pigs live around Chvarak's farms.", "Combat stats not defined"],
	["chvarak_guard", "Port guard", "Cauliflower Confederation", "Chvarak", "assets/art/chvarak/chvarak_guard.png", "A guard stationed near the mountain port.", "Combat stats not defined"],
	["ship_guard", "Ship guard", "Cauliflower Confederation", "Chvarak", "assets/art/chvarak/ship_guard_0.png", "A guard protecting a ship's crew.", "Stats vary by encounter"],
	["councillor", "Councillor", "Cauliflower Confederation", "Pomidor", "assets/art/pomidor/councillor_pomidor_0.png", "One of the delegates serving on the Confederation's council.", "Combat stats not defined"],
	["secretary", "Secretary", "Cauliflower Confederation", "Pomidor", "assets/art/pomidor/secretary_economy.png", "A council-appointed official responsible for an area of government.", "Combat stats not defined"],
	["council_guard", "Council guard", "Cauliflower Confederation", "Pomidor", "assets/art/pomidor/council_guard.png", "A guard at the council buildings.", "Combat stats not defined"],
	["engineer", "Engineer", "Engineeria", "Engineeria", "assets/art/engineeria/davor.png", "An Engineeria resident working among the city's workshops.", "Combat stats not defined"],
	["skoljka_citizen", "Skoljka resident", "Engineeria", "Skoljka", "assets/art/skoljka/person_citizen_0.png", "A resident living in Skoljka's underwater city.", "Combat stats not defined"],
	["skoljka_worker", "Pump worker", "Engineeria", "Skoljka", "assets/art/skoljka/person_worker_0.png", "A worker keeping the city's machinery running.", "Combat stats not defined"],
	["skoljka_staff", "City staff", "Engineeria", "Skoljka", "assets/art/skoljka/person_port_officer.png", "Port and service staff help the city operate.", "Combat stats not defined"],
	["recruit", "Military recruit", "Cauliflower Confederation", "Training station", "assets/art/space_military_base/station_recruit_elia.png", "A recruit training alongside the player.", "Stats vary by training exercise"],
	["station_staff", "Station staff", "Cauliflower Confederation", "Training station", "assets/art/space_military_base/confederation_officer.png", "Officers and staff oversee training at the station.", "Combat stats not defined"],
	["confederation_soldier", "Confederation soldier", "Cauliflower Confederation", "Artichoke", "assets/art/artichoke/objects/front_soldier.png", "A soldier serving at the Artichoke front.", "Combat stats not defined for stationary troops"],
	["squad_soldier", "Squad soldier", "Cauliflower Confederation", "Artichoke", "assets/art/artichoke/objects/front_soldier_2.png", "A squad member who follows orders and fights alongside the player.", "Base health 30  ·  Movement speed 74  ·  Equipment and damage vary"],
	["davor", "Davor", "Allies", "Engineeria", "assets/art/engineeria/davor.png", "An old man who saved the player's life on Rudnik and travels with them. Martin calls him the Special Party; he was once a Republic agent.", "Health 260  ·  Sword and bow  ·  Can leap at enemies  ·  When knocked down, food revives him; if left behind, he is carried back to the arrival point"],
	["veki", "Veki", "Allies", "Iskra", "assets/art/iskra/npcs/veki.png", "A hired pilot who flies people and cargo around Iskra. Crazy enough to fly the party to Breece.", "Health 140  ·  Sword  ·  Paid 1000 gold, 1000 more owed after the return to Cauliflower"],
	["mara", "Mara", "Engineeria", "Iskra", "assets/art/iskra/npcs/library_archivist.png", "The receptionist at Hotel Kinova. She took a bribe to tell two strangers when the player would return to room 12.", "Combat stats not defined"],
	["iskra_resident", "Iskra resident", "Engineeria", "Iskra", "assets/art/iskra/npcs/canal_worker.png", "Workers, couriers and punks walk Iskra's streets between the canals, markets and parks.", "Combat stats not defined"],
	["iskra_police", "Police clerk", "Engineeria", "Iskra", "assets/art/iskra/npcs/police_clerk.png", "Clerks at the police post register visitors; the quartermaster keeps the uniform issue register.", "Combat stats not defined"],
	["toma", "Toma", "Engineeria", "Iskra", "assets/art/iskra/npcs/punk_crust.png", "The Green Squirrels' recruiter, who hands out jobs and can arrange a meeting with the boss.", "Combat stats not defined"],
	["ves", "Ves", "Julius Organization", "Iskra", "assets/art/iskra/npcs/punk_braces.png", "The Red Pelicans' recruiter. The Pelicans handle Julius's business on Iskra.", "Combat stats not defined"],
	["sena", "Sena", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/squirrel_boss.png", "The Green Squirrel boss, who protects the gang's members and trades favours for information.", "Health 55  ·  Damage 6  ·  Armor 1"],
	["vlado", "Vlado", "Julius Organization", "Iskra", "assets/art/iskra/investigation/npcs/pelican_boss.png", "The Red Pelican boss.", "Combat stats not defined"],
	["jaro", "Jaro", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/contract_handler.png", "The Green Squirrel who privately arranged the assassination contract.", "Combat stats not defined"],
	["borin", "Borin", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/uniform_owner.png", "The owner of the police uniform used in the attack at Hotel Kinova.", "Combat stats not defined"],
	["false_police", "False police officer", "Other hostiles", "Iskra", "assets/art/iskra/investigation/npcs/police_attacker.png", "A hired attacker in a borrowed police uniform who came to room 12.", "Health 70  ·  Damage 7  ·  Speed 82"],
	["squirrel_guard", "Green Squirrel guard", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/squirrel_guard.png", "A guard at the Green Squirrels' office. Every Squirrel guard wears armor: two tvrdium, two iron, two bronze.", "Health 38  ·  Damage 8  ·  Armor 2 (bronze) or 3 (iron)"],
	["pelican_guard", "Red Pelican guard", "Julius Organization", "Iskra", "assets/art/iskra/investigation/npcs/pelican_guard.png", "A guard at the Red Pelicans' office. Half of them wear iron armor.", "Health 38  ·  Damage 8  ·  Armor 1, or 3 in iron"],
	["tvrdium_guard", "Tvrdium guard", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/squirrel_tv_guard.png", "A Squirrel guard armed with a tvrdium blade. Two wear tvrdium armor and one wears iron.", "Health 38  ·  Damage 14  ·  Armor 5 (tvrdium) or 3 (iron)  ·  Longer reach"],
	["roko", "Roko", "Julius Organization", "Iskra", "assets/art/iskra/investigation/npcs/pelican_hacker.png", "The Red Pelicans' hacker, far stronger than the hackers of Paprika and Brudet.", "Level 8  ·  Health 480  ·  Damage 30  ·  Speed 76  ·  Armor 3"],
	["iva_most", "Iva Most", "Cauliflower Confederation", "Iskra", "assets/art/iskra/investigation/npcs/cauliflower_secretary.png", "The Confederation's Secretary of Diplomacy, who came to Iskra to find the lost embassy and left 2000 gold for the journey to Breece.", "Combat stats not defined"],
	["diplomatic_secretary", "Diplomatic Secretary", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/diplomatic_secretary.png", "Engineeria's Diplomatic Secretary, who received the embassy's letters at the Tower.", "Combat stats not defined"],
	["board_nation", "Zvonimir Dom", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_nation.png", "Head of Nation. Coordinates the work of the other Heads and leads the Board.", "Combat stats not defined"],
	["board_technology", "Nikola Struja", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_technology.png", "Head of Technology. Keeps the City Computer's records.", "Combat stats not defined"],
	["board_architecture", "Vedrana Luk", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_architecture.png", "Head of Architecture. Wants to learn how Breece builds defended cities.", "Combat stats not defined"],
	["board_navy", "Kresimir Sidro", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_navy.png", "Head of Navy. Engineeria's ships carry freight and passengers, not war.", "Combat stats not defined"],
	["board_demographics", "Ljerka Popis", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_demographics.png", "Head of Demographics. Keeps the census of every person in Iskra.", "Combat stats not defined"],
	["board_finance", "Dubravka Riznic", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_finance.png", "Head of Finance. Guards the treasury and Engineeria's trade with the Confederation.", "Combat stats not defined"],
	["board_defense", "Branko Stit", "Engineeria", "Iskra", "assets/art/iskra/investigation/npcs/board_defense.png", "Head of Defense. Does not trust Davor.", "Combat stats not defined"],
]

## Subgroup inside each entry's category. Entries listed in ALSO_IN appear
## in a second category as well, under the same subgroup.
const SUBGROUPS := {
	"davor": "Companions",
	"veki": "Companions",
	"villager": "Paprika & Brudet",
	"chvarak_farmer": "Chvarak",
	"chvarak_guard": "Chvarak",
	"ship_guard": "Chvarak",
	"councillor": "Pomidor Council",
	"secretary": "Pomidor Council",
	"council_guard": "Pomidor Council",
	"iva_most": "Pomidor Council",
	"recruit": "Army",
	"station_staff": "Army",
	"confederation_soldier": "Army",
	"squad_soldier": "Army",
	"diplomatic_secretary": "Engineering Board",
	"iskra_resident": "Iskra",
	"iskra_police": "Iskra",
	"mara": "Iskra",
	"borin": "Iskra",
	"toma": "Green Squirrels",
	"sena": "Green Squirrels",
	"jaro": "Green Squirrels",
	"squirrel_guard": "Green Squirrels",
	"tvrdium_guard": "Green Squirrels",
	"ves": "Red Pelicans",
	"vlado": "Red Pelicans",
	"roko": "Red Pelicans",
	"pelican_guard": "Red Pelicans",
	"engineer": "Skoljka",
	"skoljka_citizen": "Skoljka",
	"skoljka_worker": "Skoljka",
	"skoljka_staff": "Skoljka",
	"republic_archer": "Republic army",
	"republic_spearman": "Republic army",
	"republic_swordsman": "Republic army",
	"republic_guardsman": "Republic army",
	"martin_spy": "Martin's men",
	"company_crew": "Martin's men",
	"company_assassin": "Martin's men",
	"collector": "Debt collectors",
	"hacker": "Hackers",
	"phase_hacker": "Hackers",
	"bandit_spear": "Bandits",
	"bandit_bow": "Bandits",
	"bandit_sword": "Bandits",
	"zombie": "Undead",
	"armed_zombie": "Undead",
	"armored_zombie": "Undead",
	"false_police": "Hired attackers",
	"wolf": "Paprika",
	"rabbit": "Paprika",
	"zombie_bear": "Paprika",
	"finling": "Brudet",
	"lake_maw": "Brudet",
	"river_serpent": "Brudet",
	"cow": "Chvarak",
	"pig": "Chvarak",
	"forest_beast": "Engineeria",
	"sea_creature": "Skoljka",
	"board_nation": "Engineering Board",
	"board_technology": "Engineering Board",
	"board_architecture": "Engineering Board",
	"board_navy": "Engineering Board",
	"board_demographics": "Engineering Board",
	"board_finance": "Engineering Board",
	"board_defense": "Engineering Board",
}

const ALSO_IN := {"ves": "Engineeria", "vlado": "Engineeria", "roko": "Engineeria", "pelican_guard": "Engineeria"}

const SUBGROUP_ORDER := ["Companions", "Paprika & Brudet", "Paprika", "Brudet", "Chvarak", "Pomidor Council", "Army", "Engineering Board", "Iskra", "Green Squirrels", "Red Pelicans", "Engineeria", "Skoljka", "Republic army", "Martin's men", "Debt collectors", "Hackers", "Bandits", "Undead", "Hired attackers"]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in HOSTILES:
		var enemy_id: String = row[0]
		if GameData.enemy(enemy_id).is_empty():
			continue
		result.append({"id": enemy_id, "name": GameData.enemy(enemy_id).get("name", enemy_id), "category": row[1], "location": row[2], "image": "res://" + row[3], "intro": row[4], "enemy_id": enemy_id})
	result.append({"id": "martin_spy", "name": "Martin's Spy", "category": "Republic forces", "location": "Skoljka", "image": "res://assets/art/skoljka/company_crew.png", "intro": "A spy sent by Martin to guard the pump chambers.", "enemy_id": "company_crew"})
	for row in PEOPLE:
		result.append({"id": row[0], "name": row[1], "category": row[2], "location": row[3], "image": "res://" + row[4], "intro": row[5], "facts": row[6]})
	for entry in result.duplicate():
		entry["subgroup"] = SUBGROUPS.get(entry["id"], "Other")
		if ALSO_IN.has(entry["id"]):
			var copy: Dictionary = entry.duplicate()
			copy["category"] = ALSO_IN[entry["id"]]
			result.append(copy)
	return result

static func subgroups(category: String) -> Array[String]:
	var found: Array[String] = []
	for entry in entries():
		if entry["category"] == category and not found.has(entry["subgroup"]):
			found.append(entry["subgroup"])
	found.sort_custom(func(a: String, b: String) -> bool: return SUBGROUP_ORDER.find(a) < SUBGROUP_ORDER.find(b))
	return found

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
