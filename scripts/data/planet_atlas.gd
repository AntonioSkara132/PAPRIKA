extends RefCounted

# Brudet's library gives these political totals; the unnamed worlds stay unidentified here.
const WORLD_COUNTS := {"New Republic": 24, "Breece": 7, "Engineeria": 5, "Cauliflower Confederation": 6, "Saint Confederation": 5, "Independent": 2}
const PLANETS := [
	{"id": "otpornik", "name": "Otpornik", "faction": "Engineeria", "position": Vector2(40, 28), "terrain": "Terrain unknown", "description": "Its engineering school sheltered engineers from Blockovia after the Destruction of Block. Their rebuilding work helped found Engineeria."},
	{"id": "elektrika", "name": "Elektrika", "faction": "Engineeria", "position": Vector2(108, 28), "terrain": "Terrain unknown", "description": "One of Engineeria's first three planets. Elektrika joined while facing shortages and threats from hackers and the Republic."},
	{"id": "iskra", "name": "Iskra", "faction": "Engineeria", "position": Vector2(180, 28), "terrain": "Artificial city", "description": "Engineeria's artificial capital. Dense neighborhoods, gardens and ship canals surround the brightly lit Tower of Engineering."},
	{"id": "skoljka", "name": "Skoljka", "faction": "Engineeria", "position": Vector2(72, 88), "terrain": "Ocean / underwater city", "description": "An ocean planet with an underwater city built as an immigrant refuge. Pumps, airlocks and glass tunnels connect its neighborhoods."},
	{"id": "rudnik", "name": "Rudnik", "faction": "Engineeria", "position": Vector2(150, 88), "terrain": "Forest / mining port", "description": "A mining planet of broadleaf forests, rocky ledges and dangerous beasts. Cargo ships carry ore from its walled port to other worlds."},
	{"id": "paprika", "name": "Paprika", "faction": "Cauliflower Confederation", "position": Vector2(256, 28), "terrain": "Fields / forest villages", "description": "A founding Confederation planet of farming villages and common fields. A long forest road links its towns; wolves and bandits lurk nearby."},
	{"id": "brudet", "name": "Brudet", "faction": "Cauliflower Confederation", "position": Vector2(326, 28), "terrain": "Rivers / wetlands", "description": "A river world of bridges, fishing waters and wooded marshes. Its city has busy markets and a military headquarters recruiting for training."},
	{"id": "pomidor", "name": "Pomidor", "faction": "Cauliflower Confederation", "position": Vector2(394, 28), "terrain": "Council town", "description": "The Confederation's Council meets here. Narrow lanes, markets and unusual townhouses surround the central square and Council Hall."},
	{"id": "cichvarda", "name": "Cichvarda", "faction": "Cauliflower Confederation", "position": Vector2(256, 88), "terrain": "Terrain unknown", "description": "One of the Confederation's four founding planets in year 83, with two seats on the Big Council. Its landscape is not yet described."},
	{"id": "chvarak", "name": "Chvarak", "faction": "Cauliflower Confederation", "position": Vector2(326, 88), "terrain": "Mountains / farms", "description": "Mountain valleys hold terraced fields and livestock pastures. Ships heading toward Engineeria leave from the northern spaceport."},
	{"id": "artichoke", "name": "Artichoke", "faction": "Cauliflower Confederation", "position": Vector2(394, 88), "terrain": "Snow / frozen coast", "description": "A frozen war front. Artichoke rebelled against Republic drafts and for independence, then joined the Confederation. Trenches cross its snow."},
]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for planet: Dictionary in PLANETS:
		var entry := planet.duplicate(true)
		entry["image"] = "res://assets/art/planet_map/%s.png" % entry["id"]
		entry["known"] = true
		result.append(entry)
	var index := 0
	for row in 4:
		for column in (10 if row % 2 == 0 else 9):
			if index >= unknown_count():
				break
			result.append({"id": "unknown_%02d" % index, "name": "UNKNOWN", "faction": "Unidentified world", "position": Vector2(24 + column * 42 + (18 if row % 2 == 1 else 0), 151 + row * 24), "terrain": "No terrain record", "description": "No named record is available. This marker represents one of the library's other worlds. Its identity and terrain remain unknown.", "image": "res://assets/art/planet_map/unknown.png", "known": false})
			index += 1
	return result

static func world_count() -> int:
	var total := 0
	for count: int in WORLD_COUNTS.values():
		total += count
	return total

static func unknown_count() -> int:
	return world_count() - PLANETS.size()

static func current_id(planet_key: String) -> String:
	return "rudnik" if planet_key == "engineeria" else planet_key

static func current_name(planet_key: String) -> String:
	if planet_key == "station":
		return "Training station (not a planet)"
	for planet: Dictionary in PLANETS:
		if planet["id"] == current_id(planet_key):
			return planet["name"]
	return "Unknown location"
