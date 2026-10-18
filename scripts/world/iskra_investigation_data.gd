extends RefCounted

const VERSION := 1
const FLAG_PREFIX := "iskra_investigation_"
const MAP_SIZE := Vector2(4400, 4032)
const ROOMS := {
	"hall": Rect2(2112, 2816, 640, 352),
	"owner": Rect2(2816, 2816, 640, 352),
	"neighbor": Rect2(2816, 3232, 384, 256),
	"squirrel": Rect2(64, 3392, 896, 544),
	"pelican": Rect2(1056, 3392, 896, 544),
	"board": Rect2(3264, 3216, 1088, 800),
}
const EXITS := {"hall": "hotel", "owner": "inv_owner_entry", "neighbor": "inv_hall_neighbor", "squirrel": "inv_squirrel_entry", "pelican": "inv_pelican_entry", "board": "tower"}
## Sena pays for the Pelican assault with tvrdium armor. Saves from before the swap keep the tvrdium sword they were given.
const ARMOR := "tvrdium_armor"
const ARROW := "banishing_arrow"
const GUARD_COUNTS := {"squirrel": 6, "pelican": 6}
## Roko joins the Pelican fight when his guards are down or the player comes this close.
const HACKER_WAKE_DISTANCE := 96.0
const HACKER_STATS := {"name": "Roko — Pelican Hacker", "level": 8, "max_health": 480, "damage": 30, "speed": 76.0, "armor": 3, "reward": 0, "event": "iskra_investigation_enemy_defeated"}
const ACTOR_IDS := ["assassin", "squirrel_boss", "contract_handler", "pelican_hacker", "squirrel_guard_0", "squirrel_guard_1", "squirrel_guard_2", "squirrel_guard_3", "squirrel_guard_4", "squirrel_guard_5", "pelican_guard_0", "pelican_guard_1", "pelican_guard_2", "pelican_guard_3", "pelican_guard_4", "pelican_guard_5", "squirrel_ally_0", "squirrel_ally_1", "squirrel_ally_2", "pelican_ally_0", "pelican_ally_1", "pelican_ally_2"]
const ACTOR_MODES := ["idle", "shoot", "attack", "flee", "surrendered", "captured", "dead", "escaped", "follow", "hold", "down"]

static func npc_texture(role: String) -> String:
	return "res://assets/art/iskra/investigation/npcs/%s.png" % role

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not value.is_empty() and (not _number(value.get("version")) or float(value["version"]) != VERSION):
		return false
	for key in value:
		match key:
			"version":
				if not _number(value[key]) or float(value[key]) != VERSION:
					return false
			"site":
				if not value[key] is String or (value[key] != "" and not ROOMS.has(value[key])):
					return false
			"route", "allies_faction":
				if not value[key] is String or value[key] not in ["", "squirrel", "direct", "pelican"]:
					return false
			"encounter":
				if not value[key] is String or value[key] not in ["", "assassin", "squirrel", "pelican"]:
					return false
			"assassin_phase":
				if not value[key] is String or value[key] not in ["", "waiting", "shoot", "attack", "flee", "surrendered", "captured", "killed", "escaped"]:
					return false
			"banishing_arrow":
				if not _valid_arrow(value[key]):
					return false
			"assassin_seconds":
				if not _bounded(value[key], 0.0, 300.0):
					return false
			"evidence_x", "evidence_y":
				if not _coordinate(value[key], String(key).ends_with("y")):
					return false
			"actors":
				if not value[key] is Dictionary or value[key].size() > ACTOR_IDS.size():
					return false
				for actor_id in value[key]:
					if actor_id not in ACTOR_IDS or not _valid_actor(value[key][actor_id]):
						return false
			_:
				return false
	return true

static func _valid_arrow(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if value.size() != 5:
		return false
	for key in ["x", "y", "dx", "dy", "remaining"]:
		if not value.has(key) or not _number(value[key]):
			return false
	if not ROOMS.hall.grow(16.0).has_point(Vector2(value.x, value.y)):
		return false
	return is_equal_approx(Vector2(value.dx, value.dy).length_squared(), 1.0) and _bounded(value.remaining, 0.0, 720.0)

static func _valid_actor(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		match key:
			"x", "y":
				if not _coordinate(value[key], String(key).ends_with("y")):
					return false
			"health", "seconds":
				if not _bounded(value[key], 0.0, 5000.0):
					return false
			"down", "alive":
				if not value[key] is bool:
					return false
			"mode":
				if not value[key] is String or value[key] not in ACTOR_MODES:
					return false
			_:
				return false
	return true

static func _coordinate(value: Variant, vertical: bool) -> bool:
	return _number(value) and float(value) >= 0.0 and float(value) < (MAP_SIZE.y if vertical else MAP_SIZE.x)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _bounded(value: Variant, minimum: float, maximum: float) -> bool:
	return _number(value) and float(value) >= minimum and float(value) <= maximum
