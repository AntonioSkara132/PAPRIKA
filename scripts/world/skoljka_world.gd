class_name SkoljkaWorld
extends GameWorld

## The underwater city of Skoljka. Mission progress is saved as story flags;
## floods and timed sequences restart from their current mission step.

const Citizen = preload("res://scripts/actors/skoljka_citizen.gd")
const SKOLJKA_MAP := "res://maps/skoljka.tmj"
const SUIT_TEXTURE := "res://assets/art/skoljka/diving_suit.png"
const DAVOR_TEXTURE := "res://assets/art/engineeria/davor.png"
const CREW_TEXTURE := "res://assets/art/skoljka/company_crew.png"
const CREATURE_TEXTURE := "res://assets/art/skoljka/sea_creature.png"
const FLAGS := [
	"skoljka_arrival", "skoljka_housing_fixed", "skoljka_pumps_restarted",
	"skoljka_relay_proved", "skoljka_workers_rescued", "skoljka_intake_repaired",
	"skoljka_depot_evidence", "skoljka_climax_won", "skoljka_aftermath",
]
const AIR_MAX := 30.0
const AIR_DAMAGE_SECONDS := 1.0
const AIR_DAMAGE := 2
const SUIT_SPEED := 0.62
const SUIT_DAMAGE_SCALE := 0.65
const CLIMAX_SECONDS := 18.0
const ASSASSINATION_FLAG := "skoljka_assassination_survived"
const DAVOR_RECOGNIZED_FLAG := "skoljka_ina_recognized_davor"
const WORKER_NAMES := ["Niko", "Dena", "Pavel", "Sera"]
const CITIZEN_NAMES := {
	"seeker": "Mira", "resident_0": "Arel", "resident_1": "Besa", "resident_2": "Ina",
	"citizen_0": "Tala", "citizen_1": "Lumi", "citizen_2": "Oren", "citizen_3": "Vesa",
	"citizen_4": "Ivo", "citizen_5": "Pela", "citizen_6": "Rada", "citizen_7": "Sena",
}

var markers: Dictionary = {}
var story_people: Dictionary = {}
var davor: RaidSoldier
var _begin_queued := false
var _air := AIR_MAX
var _air_damage_timer := AIR_DAMAGE_SECONDS
var _climax_time := -1.0
var _valves_done: Array[int] = []
var _relay_done: Array[int] = []
var _depot_route := ""
var _depot_alerted := false
var _depot_watchers: Array[Node2D] = []
var _assassin_active := false
var _assassin: Enemy
var _cutoffs_done: Array[int] = []
var _guard_phase := false
var _escort_active := false
var _last_workers_near := -1
var _suit_on := false
var _active_airlock := ""
var _interactions: Dictionary = {}
var _last_location_title := ""
var _last_air_percent := 100
var _last_climax_second := -1

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	tiled_loader.service_requested.connect(_on_service_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(SKOLJKA_MAP):
		push_error("Skoljka map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	_load_markers()
	if player == null:
		_spawn_player(GameState.SKOLJKA_ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	_spawn_story_interactions()
	_spawn_davor(_nearby_open_position(player.global_position + Vector2(-20, 16)))
	_sync_world_state()
	_configure_citizens()
	_queue_begin()

func _load_markers() -> void:
	var file := FileAccess.open(SKOLJKA_MAP, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	for layer_value in parsed.get("layers", []):
		if String(layer_value.get("name", "")) != "Markers":
			continue
		for object_value in layer_value.get("objects", []):
			var object: Dictionary = object_value
			markers[String(object.get("name", ""))] = Vector2(float(object.get("x", 0)), float(object.get("y", 0)))
		return

func marker(name: String) -> Vector2:
	return Vector2(markers.get(name, Vector2.ZERO))

func capture_player_position() -> void:
	if player != null:
		GameState.remember_player_position(player.global_position)

func apply_loaded_state() -> void:
	if player == null:
		return
	_suit_on = false
	_active_airlock = ""
	player.set_costume_texture("")
	player.damage_scale = 1.0
	_air = AIR_MAX
	_air_damage_timer = AIR_DAMAGE_SECONDS
	_last_air_percent = 100
	_climax_time = -1.0
	_last_climax_second = -1
	_valves_done.clear()
	_relay_done.clear()
	_clear_story_crew()
	_depot_route = ""
	_depot_alerted = false
	_assassin_active = false
	_assassin = null
	_guard_phase = false
	_cutoffs_done.clear()
	_escort_active = false
	_last_workers_near = -1
	if davor != null and is_instance_valid(davor):
		davor.set_order("follow")
	_sync_world_state()
	_configure_citizens()
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	_refresh_location_title()
	_queue_begin()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if story_step() == 7:
		return _nearby_open_position(marker("depot_front_inside" if not _has_flag(ASSASSINATION_FLAG) else "pump_console"))
	if story_step() == 6 and saved.x >= 104.0 * 16.0 and saved.x < 134.0 * 16.0 and saved.y >= 24.0 * 16.0 and saved.y < 50.0 * 16.0:
		return _nearby_open_position(marker("depot_front_outside"))
	if saved.y >= 1600.0:
		var west := saved.distance_to(marker("seabed_west_land")) <= saved.distance_to(marker("seabed_east_land"))
		return _nearby_open_position(marker("airlock_west_stand" if west else "airlock_east_stand"))
	if saved.is_finite() and tiled_loader.is_walkable_position(saved):
		return saved
	return _nearby_open_position(marker("airlock_west_stand") if story_step() >= 6 else marker("workers_safe") if story_step() >= 4 else marker("housing_safe") if story_step() >= 2 else GameState.SKOLJKA_ARRIVAL)

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	_set_respawn_point()

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, persistent_id: String) -> void:
	if kind == "story":
		var services := {
			"port_officer": ["port_officer", "Port Officer"], "company_clerk": ["company_clerk", "Company Clerk"],
			"councillor": ["council", "Councillor"], "company_rep": ["company_rep", "Company Representative"],
			"crew_lead": ["crew_lead", "Crew Lead"], "pumpmaster": ["pumpmaster", "Pumpmaster"],
			"technician": ["technician", "Technician"], "engineer": ["engineer", "Engineer"],
		}
		if CITIZEN_NAMES.has(persistent_id) or persistent_id.begins_with("worker_"):
			var title := String(CITIZEN_NAMES.get(persistent_id, ""))
			if persistent_id.begins_with("worker_"):
				var worker_index := int(persistent_id.trim_prefix("worker_"))
				if worker_index < 0 or worker_index >= WORKER_NAMES.size():
					return
				title = WORKER_NAMES[worker_index]
			var citizen := Citizen.new()
			citizen.name = "SkoljkaStory_%s" % persistent_id
			citizen.configure(persistent_id, title, variant, position, tiled_loader)
			if persistent_id == "citizen_0":
				citizen.service_id = "skoljka_food"
			elif persistent_id == "citizen_1":
				citizen.service_id = "skoljka_clothing"
			actors_root.add_child(citizen)
			citizen.service_requested.connect(_on_service_requested)
			story_people[persistent_id] = citizen
			return
		if not services.has(persistent_id):
			return
		var entry: Array = services[persistent_id]
		var staff := StationStaff.new()
		staff.name = "SkoljkaStory_%s" % persistent_id
		staff.configure("skoljka:" + String(entry[0]), String(entry[1]), variant, position)
		actors_root.add_child(staff)
		staff.service_requested.connect(_on_service_requested)
		story_people[persistent_id] = staff
		return
	super._on_actor_spawn_requested(kind, position, variant, persistent_id)

func _set_respawn_point() -> void:
	if player == null:
		return
	var step := story_step()
	var respawn := marker("lift_top")
	var name := "Skoljka dock"
	if step >= 2:
		respawn = marker("housing_safe")
		name = "Skoljka housing"
	if step >= 4:
		respawn = marker("workers_safe")
		name = "the lower works"
	if step >= 6:
		respawn = marker("airlock_west_stand")
		name = "the west airlock"
	if step == 7:
		respawn = marker("depot_front_inside" if not _has_flag(ASSASSINATION_FLAG) else "pump_console")
		name = "the company depot" if not _has_flag(ASSASSINATION_FLAG) else "pump control"
	player.respawn_position = _nearby_open_position(respawn)
	player.respawn_location_name = name
	player.respawn_notice = ""

func story_step() -> int:
	for index in FLAGS.size():
		if not _has_flag(FLAGS[index]):
			return index
	return FLAGS.size()

func location_title() -> String:
	if player == null:
		return "SKOLJKA"
	if player.global_position.y < 384.0:
		return "SKOLJKA DOCK"
	if player.global_position.y > 1600.0:
		return "SEABED"
	if player.global_position.y > 1280.0:
		return "LOWER WORKS"
	return "SKOLJKA"

func _refresh_location_title() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	_last_location_title = location_title()
	if ui != null and ui.has_method("refresh_location"):
		ui.refresh_location()

func story_status_text() -> String:
	var status := "SKOLJKA\nThe company has been expelled"
	match story_step():
		0: status = "SKOLJKA DOCK\nSpeak with the port officer"
		1: status = "SKOLJKA\nTake the lift down to the plaza" if player.global_position.y < 384.0 else "HOUSING\nFind the leak: close the inner door, then repair the seal"
		2: status = "PUMP WORKS\nTurn four valves west to east, then use the pump console"
		3: status = "RELAY HALL\nTrace five relay racks in order"
		4:
			if _escort_active:
				status = "LOWER WORKS\nLead the workers back to the junction (%d/4 nearby)" % _workers_near_safety()
			elif _has_flag("skoljka_lower_a_drained") and _has_flag("skoljka_lower_b_drained"):
				status = "LOWER WORKS\nThe west route is dry. Speak to Niko and the trapped workers in the west airlock"
			else:
				status = "LOWER WORKS\nFour workers are trapped in the west airlock. Drain sections A and B"
		5: status = "SEABED\nRepair the west intake and recover evidence" if _suit_on else "LOWER WORKS\nThe workers are safe. Reach the west airlock for a diving suit"
		6: status = "SEABED\nCollect the stamped company part" if int(GameState.inventory.get("skoljka_company_part", 0)) == 0 else "COMPANY DEPOT\nFind the repair orders"
		7:
			if not _has_flag(ASSASSINATION_FLAG):
				status = "COMPANY DEPOT\nMartin's assassin is waiting outside. Defeat them or escape to the plaza" if _assassin_active else "COMPANY DEPOT\nTake the repair orders out of the depot; Martin's spies may be waiting"
			elif not _guard_phase:
				status = "PUMP CONTROL\nUse the pump console to confront the company guards"
			elif _cutoffs_done.size() < 4:
				status = "PUMP CHAMBERS\nDefeat each pair of spies and disconnect their cutoff box (%d/4)" % _cutoffs_done.size()
			else:
				status = "RELAY HALL\nUse the relay console to begin reconnecting the five racks" if _climax_time < 0.0 else "RELAY HALL\n%d seconds left — links %d/5" % [ceili(_climax_time), _relay_done.size()]
		8: status = "COUNCIL\nPresent the evidence and demand the company leave"
		9: status = "SKOLJKA\nThe company has been expelled. Speak to the port officer for passage to Iskra"
	if _suit_on:
		status += "\nAIR %d%%" % roundi(air_fraction() * 100.0)
	return status

func movement_factor(_at: Vector2) -> float:
	return SUIT_SPEED if _suit_on else 1.0

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_step_air(delta)
	if _climax_time >= 0.0:
		_climax_time -= delta
		var seconds := ceili(_climax_time)
		if seconds != _last_climax_second:
			_last_climax_second = seconds
			GameState.military_changed.emit()
		if _climax_time <= 0.0:
			_fail_climax()
	if _escort_active:
		var nearby := _workers_near_safety()
		if nearby != _last_workers_near:
			_last_workers_near = nearby
			GameState.military_changed.emit()
		if player.global_position.distance_to(marker("workers_safe")) < 85.0 and nearby == WORKER_NAMES.size():
			_complete_worker_rescue()
	if story_step() == 7 and not _has_flag(ASSASSINATION_FLAG):
		var outside_depot := player.global_position.x < 104.0 * 16.0 or player.global_position.y > 50.0 * 16.0
		if not _assassin_active and outside_depot and not player.ui_is_open():
			_start_assassination()
		elif _assassin_active and player.global_position.distance_to(marker("plaza_centre")) < 90.0:
			_survive_assassination(true)
	if _depot_route == "sneak" and story_step() == 6 and not _depot_alerted:
		for index in range(4):
			if player.global_position.distance_to(marker("crew_patrol_%d" % index)) < 56.0:
				depot_detected()
				break
	if davor != null and is_instance_valid(davor) and not davor.down and davor.order == "follow":
		if not _suit_on and davor.global_position.distance_to(player.global_position) > 310.0:
			var catch_up_position := tiled_loader.nearest_walkable_position(player.global_position + Vector2(-18, 16))
			if catch_up_position.is_finite():
				davor.global_position = catch_up_position

	var title := location_title()
	if title != _last_location_title:
		_last_location_title = title
		_refresh_location_title()

func _step_air(delta: float) -> void:
	if not _in_low_air(player.global_position):
		_air = AIR_MAX
		_air_damage_timer = AIR_DAMAGE_SECONDS
		if _suit_on and _last_air_percent != 100:
			_last_air_percent = 100
			GameState.military_changed.emit()
		return
	_air = maxf(0.0, _air - delta * (0.45 if _suit_on else 1.0))
	if _suit_on:
		var percent := roundi(air_fraction() * 100.0)
		if percent != _last_air_percent:
			_last_air_percent = percent
			GameState.military_changed.emit()
	_air_damage_timer -= delta
	if _air <= 0.0 and _air_damage_timer <= 0.0:
		_air_damage_timer = AIR_DAMAGE_SECONDS
		player.take_damage(AIR_DAMAGE, Vector2.ZERO, true)

func _in_low_air(position: Vector2) -> bool:
	return position.y >= 1280.0

func air_fraction() -> float:
	return _air / AIR_MAX

func has_diving_suit() -> bool:
	return _suit_on

func _spawn_story_interactions() -> void:
	var entries := {
		"port_officer": ["port_officer", "Port Officer", "person_port_officer"],
		"company_clerk": ["company_clerk", "Company Clerk", "person_company_clerk"],
		"lift_top": ["lift_top", "Pressure Lift", "lift_head"],
		"lift_bottom": ["lift_bottom", "Pressure Lift", "lift_head"],
		"plaza_centre": ["plaza", "Plaza", "shell_statue"],
		"housing_entry": ["housing", "Housing", "housing_0"],
		"leak_point": ["leak", "Leaking Pod", "intake_broken"],
		"housing_lever": ["housing_lever", "Housing Lever", "door_lever"],
		"pump_console": ["pump_console", "Pump Console", "console"],
		"cutoff_0": ["cutoff_0", "Company Cutoff 1", "gauge_panel"],
		"cutoff_1": ["cutoff_1", "Company Cutoff 2", "gauge_panel"],
		"cutoff_2": ["cutoff_2", "Company Cutoff 3", "gauge_panel"],
		"cutoff_3": ["cutoff_3", "Company Cutoff 4", "gauge_panel"],
		"pressure_log": ["pressure_log", "Pressure Log", "gauge_panel"],
		"valve_0": ["valve_0", "Valve 1", "valve"], "valve_1": ["valve_1", "Valve 2", "valve"],
		"valve_2": ["valve_2", "Valve 3", "valve"], "valve_3": ["valve_3", "Valve 4", "valve"],
		"relay_console": ["relay_console", "Relay Console", "console"],
		"rack_0": ["rack_0", "Relay Rack 1", "relay_rack_0"], "rack_1": ["rack_1", "Relay Rack 2", "relay_rack_1"],
		"rack_2": ["rack_2", "Relay Rack 3", "relay_rack_2"], "rack_3": ["rack_3", "Relay Rack 4", "relay_rack_0"],
		"rack_4": ["rack_4", "Lower Relay Rack", "relay_rack_1"],
		"lower_entry": ["lower_entry", "Lower Works", "airlock"],
		"lower_a_console": ["lower_a", "Section A Console", "console"],
		"lower_b_console": ["lower_b", "Section B Console", "console"],
		"air_0": ["air_0", "Air Station", "air_station"], "air_1": ["air_1", "Air Station", "air_station"], "air_2": ["air_2", "Air Station", "air_station"],
		"airlock_west": ["suit_west", "West Airlock", "airlock"],
		"airlock_east": ["suit_east", "East Airlock", "airlock"],
		"seabed_west_hatch": ["return_west", "West Hatch", "airlock"],
		"seabed_east_hatch": ["return_east", "East Hatch", "airlock"],
		"intake": ["intake", "Broken Intake", "intake_broken"],
		"evidence": ["evidence", "Company Part", "company_crates"],
		"depot_front_outside": ["depot", "Company Depot", "company_sign"],
		"depot_records": ["depot_records", "Repair Orders", "depot_shelf"],
		"council_spot": ["council", "City Council", "person_councillor"],
		"frame_window_view": ["frame", "Sealed Dock", "frame_window"],
	}
	for key in entries:
		if not markers.has(key):
			continue
		var entry: Array = entries[key]
		var staff := StationStaff.new()
		staff.name = "Skoljka_%s" % key
		staff.configure("skoljka:" + String(entry[0]), String(entry[1]), "res://assets/art/skoljka/%s.png" % String(entry[2]), marker(key))
		if String(key).begins_with("cutoff_"):
			staff.interaction_text = "Disconnect %s" % String(entry[1])
		actors_root.add_child(staff)
		staff.service_requested.connect(_on_service_requested)
		_interactions[String(entry[0])] = staff

func _on_service_requested(service_id: String, display_name: String) -> void:
	if service_id.begins_with("skoljka:"):
		_handle_interaction(service_id.trim_prefix("skoljka:"))
		return
	super._on_service_requested(service_id, display_name)

func _handle_interaction(id: String) -> void:
	match id:
		"port_officer": _port_officer()
		"company_clerk": _company_clerk()
		"seeker": _talk_seeker()
		"resident_0", "resident_1", "resident_2": _talk_resident(id)
		"citizen_0", "citizen_1", "citizen_2", "citizen_3", "citizen_4", "citizen_5", "citizen_6", "citizen_7": _talk_citizen(id)
		"worker_0", "worker_1", "worker_2", "worker_3": _talk_worker(int(id.trim_prefix("worker_")))
		"company_rep": _tell("Company Representative", "We are here to keep the machinery running. You should leave the records to our staff.")
		"crew_lead": _tell("Crew Lead", "The depot is company property. Show a work order or stay outside.")
		"pumpmaster": _tell("Pumpmaster", "The valves run west to east. The council has already asked us to isolate the two flooded sections.")
		"technician": _tell("Technician", "The relay path doubles back where it should not. I can arrange a maintenance order for the depot.")
		"engineer": _tell("Engineer", "That's not ours to talk about.")
		"resident": _plaza()
		"worker": _tell("Worker", "The air stations are at the junction and the middle intake room.")
		"lift_top", "lift_bottom": _lift()
		"plaza": _plaza()
		"housing": _housing()
		"leak", "housing_lever": _fix_housing(id)
		"pump_console": _pump_console()
		"cutoff_0", "cutoff_1", "cutoff_2", "cutoff_3": _disconnect_cutoff(int(id.get_slice("_", 1)))
		"pressure_log": _pressure_log()
		"valve_0", "valve_1", "valve_2", "valve_3": _turn_valve(int(id.get_slice("_", 1)))
		"relay_console": _relay_console()
		"rack_0", "rack_1", "rack_2", "rack_3", "rack_4": trace_relay(int(id.get_slice("_", 1)))
		"lower_entry": _lower_entry()
		"lower_a", "lower_b": _drain_section(id)
		"air_0", "air_1", "air_2": _refill_air()
		"suit_west", "suit_east": _toggle_suit(id)
		"return_west", "return_east": _return_from_seabed(id == "return_west")
		"intake": _repair_intake()
		"evidence": _take_evidence()
		"depot": _depot_entry()
		"depot_records": _take_orders()
		"council": _council()
		"frame": _frame()

func _port_officer() -> void:
	if _has_flag(GameState.ISKRA_UNLOCK_FLAG):
		_play([{"speaker": "Port Officer", "text": "The council has arranged two seats on the ship to Iskra. Are you and Davor ready?"}], Callable(), [
			{"label": "Board the ship to Iskra", "action": sail_to_iskra},
			{"label": "Stay on Skoljka", "action": Callable()},
		])
		return
	if story_step() > 0:
		_tell("Port Officer", "The city is below the lift. Keep to the marked routes; the outer water is deep.")
		return
	_play([
		{"speaker": "Port Officer", "text": "You came in with the ore ship. The lower works have a leak, and the company has offered to handle it."},
		{"speaker": "Davor", "text": "Let us see the pumps first. We can decide who is helping after that."},
		{"speaker": "Company Clerk", "text": "I'll note your names for the maintenance record."},
		{"speaker": "Port Officer", "text": "Take the pressure lift to the plaza. The housing quarter is west of it."},
	], func() -> void:
		_set_flag(FLAGS[0])
		_sync_world_state())

func sail_to_iskra() -> bool:
	if not _has_flag(GameState.ISKRA_UNLOCK_FLAG):
		return false
	_play([
		{"speaker": "Port Officer", "text": "Two seats to Iskra, paid by the council. The captain is waiting at the hatch."},
		{"speaker": "", "text": "Skoljka's cranes disappear beneath the clouds. When the ship finally slows, a city of metal plates and lit windows fills the ports."},
		{"speaker": "Davor", "text": "Iskra. We should register at the dock before we go to the Tower."},
	], func() -> void: story_travel_requested.emit("iskra"))
	return true

func _company_clerk() -> void:
	if story_step() < 6:
		_tell("Company Clerk", "We brought spare seals on the last ship. Keeping them nearby seemed sensible, given the old pipes.")
	else:
		_tell("Company Clerk", "Our maintenance records are in the depot. Everything was filed properly.")

func _lift() -> void:
	if story_step() == 0:
		_tell("Pressure Lift", "The port officer is waiting for you.")
		return
	if player.global_position.y < 360.0:
		player.global_position = _nearby_open_position(marker("lift_bottom"))
	else:
		player.global_position = _nearby_open_position(marker("lift_top"))
	player.velocity = Vector2.ZERO
	if davor != null and is_instance_valid(davor) and davor.order == "follow":
		davor.global_position = tiled_loader.nearest_walkable_position(player.global_position + Vector2(-18, 16))
		davor.velocity = Vector2.ZERO
		davor.set_order("follow")
	GameState.player_position = player.global_position
	_refresh_location_title()

func _configure_citizens() -> void:
	for id in CITIZEN_NAMES:
		var citizen := story_people.get(id) as Citizen
		if citizen == null:
			continue
		if String(id).begins_with("resident_") and not _has_flag(FLAGS[1]):
			citizen.wait_at(citizen.home_position)
			continue
		var stops := PackedVector2Array()
		var index := 0
		while markers.has("%s_stop_%d" % [id, index]):
			var destination := marker("%s_stop_%d" % [id, index])
			if tiled_loader.is_walkable_position(destination):
				stops.append(destination)
			index += 1
		if stops.size() > 1:
			citizen.set_route(stops)
	for index in WORKER_NAMES.size():
		var worker := story_people.get("worker_%d" % index) as Citizen
		if worker == null:
			continue
		if _has_flag(FLAGS[4]):
			worker.wait_at(_nearby_open_position(marker("niko_reunion" if index == 0 else "worker_safe_%d" % index)))
		else:
			worker.wait_at(worker.home_position)

func _workers_near_safety() -> int:
	var count := 0
	for index in WORKER_NAMES.size():
		var worker := story_people.get("worker_%d" % index) as Citizen
		if worker != null and worker.global_position.distance_to(marker("workers_safe")) < 72.0:
			count += 1
	return count

func _talk_worker(index: int) -> void:
	var worker_name: String = WORKER_NAMES[index]
	if _has_flag(FLAGS[4]):
		var safe_lines := [
			"Mira has heard I'm safe. We'll have supper together when the shift ends.",
			"The air station is working again. I can breathe without counting every minute.",
			"We left the spare seals where we found them. Someone brought them here before the leak.",
			"I can go back to checking the pipes once my hands stop shaking.",
		]
		_tell(worker_name, safe_lines[index])
		return
	if not _has_flag("skoljka_lower_a_drained") or not _has_flag("skoljka_lower_b_drained"):
		_tell(worker_name, "We can see the junction, but the pressure doors are still shut. Drain both sections first.")
		return
	if _escort_active:
		_tell(worker_name, "We're following you. Please stay with us until we reach the junction.")
		return
	if index != 0:
		var lines := ["", "Niko kept the hatch shut while the others found air.",
			"The company had spare seals down here before the alarm. I thought that was odd.",
			"I can walk. Lead us back past the drained section."]
		_tell(worker_name, lines[index])
		return
	_play([
		{"speaker": "Niko", "text": "Mira sent you? We were trapped when the pressure doors shut. All four of us are here."},
		{"speaker": "Dena", "text": "The route to the junction is dry now. Please stay close while we walk back."},
	], func() -> void: _start_worker_escort())

func _start_worker_escort() -> void:
	if story_step() != 4 or not _has_flag("skoljka_lower_a_drained") or not _has_flag("skoljka_lower_b_drained"):
		return
	_escort_active = true
	_last_workers_near = -1
	for index in WORKER_NAMES.size():
		var worker := story_people.get("worker_%d" % index) as Citizen
		if worker != null:
			worker.follow_for_rescue(player, index)
	GameState.military_changed.emit()

func _complete_worker_rescue() -> void:
	_escort_active = false
	_last_workers_near = -1
	for index in WORKER_NAMES.size():
		var worker := story_people.get("worker_%d" % index) as Citizen
		if worker != null:
			worker.wait_at(worker.global_position)
	_set_flag(FLAGS[4])
	_sync_world_state()
	var niko := story_people.get("worker_0") as Citizen
	if niko != null:
		niko.set_route(PackedVector2Array([marker("niko_reunion"), marker("seeker_stop_0")]))
	_play([
		{"speaker": "Niko", "text": "Everyone made it back. Mira will be waiting at the plaza; I'll go tell her myself."},
		{"speaker": "Davor", "text": "The workers are safe. The west airlock is open, and the intake outside still needs repair."},
	])

func _talk_seeker() -> void:
	if _has_flag(FLAGS[4]):
		_tell("Mira", "Niko made it out with the other workers. I'll meet him here when he comes up from the junction.")
	elif story_step() >= 4:
		_tell("Mira", "My brother Niko and three others are trapped in the west airlock. The pressure doors won't let them back to the junction.")
	else:
		_tell("Mira", "Niko went to check the west intake with three workers. The shift ended, but none of them came home.")

func _talk_resident(id: String) -> void:
	if id == "resident_2" and _has_flag(FLAGS[1]) and not _has_flag(DAVOR_RECOGNIZED_FLAG) and davor != null and is_instance_valid(davor) and davor.global_position.distance_to(player.global_position) < 80.0:
		_set_flag(DAVOR_RECOGNIZED_FLAG)
		_play([
			{"speaker": "Ina", "text": "Your face seems familiar. Have we met before?"},
			{"speaker": "Davor", "text": "I don't think so. Glad the water's gone from your home."},
		])
		return
	var lines_before := {
		"resident_0": "I moved the blankets above the waterline. Can you close the pressure door before the pod fills?",
		"resident_1": "The aquarium cracked when the pressure fell. My children are waiting in the next room.",
		"resident_2": "I heard the pump knock twice before the leak started. The company said that was normal.",
	}
	var lines_after := {
		"resident_0": "The floor is dry again. I can put the blankets back where they belong.",
		"resident_1": "The children can come home now. I'll mend the aquarium after supper.",
		"resident_2": "The pump still makes that knock. You should ask its keeper what changed.",
	}
	_tell(String(CITIZEN_NAMES[id]), String((lines_after if _has_flag(FLAGS[1]) else lines_before)[id]))

func _talk_citizen(id: String) -> void:
	var early := {
		"citizen_0": "The company ordered meals for a night repair shift before anyone reported a leak.",
		"citizen_1": "I dyed a few coats the color of sea glass. Workers need clothes that look like home, not company overalls.",
		"citizen_2": "The garden lamps dimmed just before the pressure alarm. They don't usually run on the same line.",
		"citizen_3": "I carry messages between the plaza and housing. Today everybody has asked about the lower works.",
		"citizen_4": "The west housing pod has families in it. They need a dry way out, not another company notice.",
		"citizen_5": "The market will be open at supper, even if the pumps take all day.",
		"citizen_6": "These valves usually fail one at a time. Four at once is hard to explain.",
		"citizen_7": "The council has asked for repair records. The company says they are all at its depot.",
	}
	var late := {
		"citizen_0": "The rescued workers have a table waiting. Niko's sister saved his favorite broth.",
		"citizen_1": "I kept the shop open while the hatches were shut. People still need ordinary things.",
		"citizen_2": "The garden lights are steady now. The children came back to see the fish.",
		"citizen_3": "I've carried the news to housing: four people came out of the west airlock alive.",
		"citizen_4": "The families in the housing pod helped the workers find dry clothes.",
		"citizen_5": "The market stayed open. Someone has to keep the city fed.",
		"citizen_6": "I won't sign off on those pumps until I see who changed the relay settings.",
		"citizen_7": "The council is ready to hear what the company filed before the breakdown.",
	}
	_tell(String(CITIZEN_NAMES[id]), String((late if _has_flag(FLAGS[4]) else early)[id]))

func _plaza() -> void:
	if story_step() < 2:
		_tell("Resident", "The leak is in the west housing pod. Close the inner pressure door before opening the outer one.")
	elif story_step() < FLAGS.size():
		_tell("Resident", "The company crews keep asking to take control of the pumps. Please find out why they came prepared.")
	else:
		_tell("Resident", "The city is quieter without the company crews at every hatch.")

func _housing() -> void:
	if story_step() < 2:
		_tell("Resident", "The leak is drawing water through the pod. Use the housing lever, then inspect the damaged seal.")
	else:
		_tell("Resident", "The housing pod is safe now. Thank you for staying to help.")

func _fix_housing(id: String) -> void:
	if story_step() != 1:
		_tell("Door Lever", "The housing pressure system is stable.")
		return
	if id == "housing_lever":
		_set_group("housing_inner", true)
		_set_group("housing_leak", true)
		if not _has_flag("skoljka_housing_inner_closed"):
			_set_flag("skoljka_housing_inner_closed")
			(_interactions["housing_lever"] as Node2D).visible = false
			_tell("You", "The inner door seals behind you. The damaged seal is at the flooded pod's edge.")
		return
	if not _has_flag("skoljka_housing_inner_closed"):
		_tell("You", "Water is pushing against the inner door. Close that first.")
		return
	_set_group("housing_leak", false)
	_set_flag(FLAGS[1])
	_sync_world_state()
	_configure_citizens()
	_play([{"speaker": "Pumpmaster", "text": "That stopped it. The main pump room is under the plaza. Four valves, in sequence, before the console will restart."}])

func _pressure_log() -> void:
	if story_step() < 7:
		_tell("Pressure Log", "The west housing line lost pressure before the flood alarm sounded. The log does not say why.")
	else:
		_tell("Pressure Log", "The early pressure drop matches the repair orders filed at the company depot.")

func _pump_console() -> void:
	if story_step() == 7:
		if not _has_flag(ASSASSINATION_FLAG):
			_tell("Pumpmaster", "Martin's assassin followed you from the depot. Lose them or defeat them first.")
		elif not _guard_phase:
			_play([
				{"speaker": "Pumpmaster", "text": "The pumps you repaired still run. Martin's spies wired four cutoff boxes into their relay controls; a remote command could stop the pumps again. Two spies guard each box. Defeat them and disconnect the boxes. Leave the valves alone."},
				{"speaker": "Davor", "text": "Niko's gone back to the junction. I'll stay with the four rescued workers. You take care of the spies in the pump chambers."},
			], _start_guard_phase)
		else:
			_tell("Pumpmaster", "Martin's spies can shut off the pumps through those four boxes. Disconnect them, then reconnect the relay; the valves you repaired are fine.")
		return
	if story_step() < 2:
		_tell("Pumpmaster", "The valves are stuck. Turn the four in order, west to east, then come back here.")
	elif story_step() == 2:
		if _valves_done.size() < 4:
			_tell("Pumpmaster", "The valves are still out of order. Start at the western pump and follow the line east.")
			return
		_set_flag(FLAGS[2])
		_sync_world_state()
		_play([{"speaker": "Pumpmaster", "text": "The pumps are running again. The relay hall's lights still don't match the control board."}])
	else:
		_tell("Pumpmaster", "The main pump is turning. The relay hall is east through the works.")

func _turn_valve(index: int) -> void:
	if story_step() >= 7:
		GameState.notify("This pump is already running. Disconnect the company's cutoff box instead." if story_step() == 7 else "This pump is already running.")
		return
	if story_step() != 2:
		_tell("Pump Worker", "No one is asking us to restart that line yet.")
		return
	if index != _valves_done.size():
		_valves_done.clear()
		_tell("Pump Worker", "The gauges jump. Start over at the west valve and work east.")
		return
	_valves_done.append(index)
	_tell("You", "Valve %d turns into place. %d of 4." % [index + 1, _valves_done.size()])

func _relay_console() -> void:
	if story_step() < 3:
		_tell("Technician", "The relay path has been rewired. Trace the lamps from the console through each rack in order.")
	elif story_step() < 7:
		_tell("Technician", "The recorded route is west to east, then through the lower rack and back to the console.")
	elif story_step() == 7:
		if not _has_flag(ASSASSINATION_FLAG) or _cutoffs_done.size() != 4:
			_tell("Technician", "First secure all four company cutoff boxes in the pump chambers. Start at the pump console.")
		elif _climax_time < 0.0:
			_play([{"speaker": "Technician", "text": "The cutoff boxes are disconnected. Reconnect the five racks along the route you traced earlier. You have %d seconds after starting before the backup link trips; the pumps keep running on local control." % int(CLIMAX_SECONDS)}], Callable(), [
				{"label": "Start reconnecting", "action": start_climax},
				{"label": "Not yet", "action": Callable()},
			])
		else:
			GameState.notify("Reconnect the racks in order: %d of 5 links restored." % _relay_done.size())
	else:
		_tell("Technician", "The city controls its relay again. Your pump repairs are still holding.")

func trace_relay(index: int) -> bool:
	if story_step() != 3 and story_step() != 7:
		return false
	if story_step() == 7 and _climax_time < 0.0:
		return false
	var expected := [0, 1, 2, 3, 4]
	if index != _relay_done.size() or index < 0 or index >= expected.size():
		_relay_done.clear()
		return false
	_relay_done.append(index)
	if story_step() == 7:
		GameState.military_changed.emit()
		if _relay_done.size() == expected.size():
			_finish_climax()
	if _relay_done.size() == expected.size() and story_step() == 3:
		_set_flag(FLAGS[3])
		_sync_world_state()
	return true

func _lower_entry() -> void:
	if story_step() < 4:
		_tell("Worker", "Sections A and B need to be isolated at their consoles. The west airlock leads to the intake outside.")
		return
	_set_group("lower_works", false)
	player.global_position = _nearby_open_position(marker("lower_entry"))

func _drain_section(which: String) -> void:
	if story_step() < 4:
		_tell("Worker", "The section can't be drained until the pumps are back online.")
		return
	var flood := "lower_a" if which == "lower_a" else "lower_b"
	_set_group(flood, false)
	if not _has_flag("skoljka_" + flood + "_drained"):
		_set_flag("skoljka_" + flood + "_drained")
	if _has_flag("skoljka_lower_a_drained") and _has_flag("skoljka_lower_b_drained"):
		_sync_world_state()
		_tell("Console", "Both pressure routes are dry. Four workers are waiting in the west airlock; find them and lead them to the junction.")
	else:
		_tell("Console", "Section %s is draining. Isolate the other section before entering the west airlock." % flood.trim_prefix("lower_"))

func _refill_air() -> void:
	_air = AIR_MAX
	_last_air_percent = 100
	_air_damage_timer = AIR_DAMAGE_SECONDS
	GameState.military_changed.emit()
	_tell("Air Station", "Your air is full.")

func _toggle_suit(id: String) -> void:
	if story_step() < 5:
		_tell("Airlock", "The outer hatch stays sealed until the lower works are safe.")
		return
	if _suit_on:
		_suit_on = false
		_active_airlock = ""
		player.set_costume_texture("")
		player.damage_scale = 1.0
		player.global_position = _nearby_open_position(marker("airlock_west_stand" if id == "suit_west" else "airlock_east_stand"))
		_set_group("hatch_west" if id == "suit_west" else "hatch_east", true)
		if davor != null and is_instance_valid(davor):
			davor.set_order("follow")
		_air = AIR_MAX
		_tell("Airlock", "You take off the diving suit and hang it on the rack.")
	else:
		_suit_on = true
		_active_airlock = "west" if id == "suit_west" else "east"
		player.set_costume_texture(SUIT_TEXTURE)
		player.damage_scale = SUIT_DAMAGE_SCALE
		_air = AIR_MAX
		var destination := "seabed_west_hatch" if id == "suit_west" else "seabed_east_hatch"
		_set_group("hatch_west" if id == "suit_west" else "hatch_east", false)
		if davor != null and is_instance_valid(davor):
			davor.hold_at(_nearby_open_position(marker("airlock_west_stand" if id == "suit_west" else "airlock_east_stand")), "Airlock")
		player.global_position = _nearby_open_position(marker(destination.replace("_hatch", "_land")))
		_tell("Airlock", "The suit seals. Keep an eye on the air gauge; Davor will wait inside.")
	_set_respawn_point()
	_refresh_location_title()

func _return_from_seabed(west: bool) -> void:
	if not _suit_on:
		_tell("Airlock", "The hatch is sealed from this side. Wear the suit to open it.")
		return
	player.global_position = _nearby_open_position(marker("airlock_west_stand" if west else "airlock_east_stand"))
	_set_group("hatch_west" if west else "hatch_east", true)
	if davor != null and is_instance_valid(davor):
		davor.set_order("follow")
	_suit_on = false
	_active_airlock = ""
	player.set_costume_texture("")
	player.damage_scale = 1.0
	_air = AIR_MAX
	_set_respawn_point()
	_refresh_location_title()

func _repair_intake() -> void:
	if _has_flag(FLAGS[5]):
		_tell("You", "The new seal is holding. The intake is running smoothly.")
		return
	if not _suit_on:
		_tell("Broken Intake", "The intake is outside the hull. Put on the diving suit at the airlock first.")
		return
	if story_step() < 5:
		_tell("Broken Intake", "The housing around the intake has cracked. The replacement seal should be in the toolbox beside it.")
		return
	_set_flag(FLAGS[5])
	_sync_world_state()
	_tell("You", "The new seal holds. The intake stops shuddering, and a stamped company part falls free from the pipework.")

func _take_evidence() -> void:
	if story_step() < 6:
		_tell("You", "A stamped metal part is lodged in the wreckage. The intake repair will make it safe to reach.")
		return
	if int(GameState.inventory.get("skoljka_company_part", 0)) == 0:
		GameState.add_item("skoljka_company_part")
	_tell("You", "You take the stamped company part as evidence.")

func _depot_entry() -> void:
	if story_step() < 6:
		_tell("Company Clerk", "The depot is restricted to maintenance staff.")
		return
	if story_step() >= 7:
		player.global_position = _nearby_open_position(marker("depot_front_inside"))
		return
	_play([
		{"speaker": "Technician", "text": "I can give you a work order. Or you can use the service entrance and keep out of sight."},
	], Callable(), [
		{"label": "Use the work order", "action": func() -> void: _enter_depot("talk")},
		{"label": "Sneak in", "action": func() -> void: _enter_depot("sneak")},
		{"label": "Not yet", "action": Callable()},
	])

func _enter_depot(route: String) -> void:
	_depot_route = route
	_depot_alerted = false
	_clear_depot_watchers()
	if route == "talk" and int(GameState.inventory.get("skoljka_forged_work_order", 0)) == 0:
		GameState.add_item("skoljka_forged_work_order")
	_set_group("depot_front", false)
	player.global_position = _nearby_open_position(marker("depot_front_inside"))
	if route == "sneak":
		_show_depot_watchers()
		_tell("Technician", "The crew is watching the marked aisles. Keep out of sight and reach the records.")
	else:
		_tell("Company Clerk", "The work order checks out. Records are at the back of the depot.")

func depot_detected() -> void:
	if story_step() == 6 and _depot_route == "sneak" and not _depot_alerted:
		_depot_alerted = true
		_clear_depot_watchers()
		_spawn_crew(marker("crew_patrol_0"), "story_skoljka_depot_patrol_0")
		_spawn_crew(marker("crew_patrol_1"), "story_skoljka_depot_detected_0")
		_spawn_crew(marker("crew_patrol_2"), "story_skoljka_depot_patrol_2")
		_tell("Company Crew", "You are not on the work list. The crew blocks the records aisle.")

func _company_crew_alive() -> bool:
	for actor in actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("story_skoljka_depot_") and actor.health > 0 and not actor.is_queued_for_deletion():
			return true
	return false

func _take_orders() -> void:
	if _depot_route == "sneak" and _company_crew_alive():
		_tell("You", "The crew is still watching the records. Clear the aisle before taking the orders.")
		return
	if _has_flag(FLAGS[6]):
		_tell("You", "You already have the repair orders.")
		return
	if int(GameState.inventory.get("skoljka_company_part", 0)) <= 0:
		_tell("Records Clerk", "You need the stamped company part from the west intake before these records can be tied to the failures.")
		return
	if story_step() < 6:
		_tell("Records Clerk", "These are current maintenance orders. Nothing unusual is listed.")
		return
	_set_flag(FLAGS[6])
	_clear_depot_watchers()
	if int(GameState.inventory.get("skoljka_repair_orders", 0)) == 0:
		GameState.add_item("skoljka_repair_orders")
	_set_group("depot_back", false)
	_sync_world_state()
	_play([{"speaker": "You", "text": "The orders were filed before the failures. Someone scheduled the repairs before the pumps broke."}, {"speaker": "Davor", "text": "A second order names you as the target. Martin sent spies to kill you; watch the depot exit, then secure the relay controls."}])

func _start_assassination() -> void:
	_assassin_active = true
	if story_step() != 7 or _has_flag(ASSASSINATION_FLAG):
		_assassin_active = false
		return
	var spawn_marker := "assassin_front" if player.global_position.x < 104.0 * 16.0 else "assassin_back"
	var position := _nearby_open_position(marker(spawn_marker))
	_assassin = Enemy.new()
	_assassin.name = "MartinsAssassin"
	_assassin.configure("company_assassin", "res://assets/art/skoljka/company_crew_tool.png", position, "story_skoljka_assassin")
	_assassin.definition["name"] = "Martin's Assassin"
	_assassin._label.text = "Martin's Assassin  Lv.%d" % int(_assassin.definition.get("level", 1))
	_assassin.focus_target = player
	_assassin.relentless = true
	_assassin.definition["reward"] = 0
	_assassin._attack_cooldown = 1.0
	var attacker := _assassin
	_assassin.defeated.connect(func(_id: String) -> void: _assassin_defeated.call_deferred(attacker))
	actors_root.add_child(_assassin)
	GameState.notify("Martin's assassin waits outside the depot! Fight or escape to the plaza.")
	GameState.military_changed.emit()

func _assassin_defeated(attacker: Enemy) -> void:
	if attacker == _assassin:
		_survive_assassination(false)

func _survive_assassination(escaped: bool) -> void:
	if not _assassin_active or story_step() != 7:
		return
	_assassin_active = false
	if is_instance_valid(_assassin) and escaped:
		_assassin.queue_free()
	_assassin = null
	_set_flag(ASSASSINATION_FLAG)
	_sync_world_state()
	GameState.notify("You escape the attacker. Secure the relay before taking the orders to the council." if escaped else "The assassin is down. Secure the relay before taking the orders to the council.")

func _council() -> void:
	if story_step() < 8:
		_tell("Councillor", "Bring us the repair orders and secure the relay controls. The company cannot keep control of both records and machinery.")
		return
	if story_step() == 8:
		_set_flag(FLAGS[8])
		GameState.add_gold(120)
		_sync_world_state()
		_play([{"speaker": "Councillor", "text": "The orders were written before the faults. The company must leave the city."}, {"speaker": "Davor", "text": "They came prepared for trouble, and the residents have proof. That's enough for today."}, {"speaker": "Councillor", "text": "You have our thanks. The port officer has arranged two seats to Iskra for you and Davor. Speak to the officer when you are ready to leave."}])
	else:
		_tell("Councillor", "The company has left. Speak to the port officer at the dock when you and Davor are ready to sail to Iskra.")

func _frame() -> void:
	_tell("Engineer", "That's not ours to talk about.")

func _start_guard_phase() -> void:
	if story_step() != 7 or not _has_flag(ASSASSINATION_FLAG) or _guard_phase:
		return
	_guard_phase = true
	_cutoffs_done.clear()
	var niko := story_people.get("worker_0") as Citizen
	if niko != null:
		niko.wait_at(_nearby_open_position(marker("worker_safe_0")))
	if davor != null and is_instance_valid(davor):
		var workers_post := _nearby_open_position(marker("workers_safe"))
		davor.global_position = workers_post
		davor.hold_at(workers_post, "Guard the rescued workers")
	for chamber in range(4):
		for slot in range(2):
			var stable_id := "story_skoljka_climax_%d_%d" % [chamber, slot]
			_spawn_crew(marker("crew_climax_%d_%d" % [chamber, slot]), stable_id)
			for actor in actors_root.get_children():
				if actor is Enemy and actor.persistent_id == stable_id and not actor.is_queued_for_deletion():
					actor.definition["reward"] = 0
					actor.definition["name"] = "Martin's Spy"
					actor._label.text = "Martin's Spy  Lv.%d" % int(actor.definition.get("level", 1))
					actor.guard_radius = 92.0
	GameState.military_changed.emit()

func _chamber_guards_alive(chamber: int) -> bool:
	for actor in actors_root.get_children():
		if actor is Enemy and actor.health > 0 and not actor.is_queued_for_deletion() and String(actor.persistent_id).begins_with("story_skoljka_climax_%d_" % chamber):
			return true
	return false

func _disconnect_cutoff(chamber: int) -> void:
	if story_step() != 7 or not _guard_phase:
		GameState.notify("Start at the pump console before disconnecting the company's equipment.")
		return
	if _cutoffs_done.has(chamber):
		GameState.notify("This cutoff box is already disconnected.")
		return
	if _chamber_guards_alive(chamber):
		GameState.notify("Martin's spies are protecting this box. Defeat both first.")
		return
	_cutoffs_done.append(chamber)
	if _interactions.has("cutoff_%d" % chamber):
		(_interactions["cutoff_%d" % chamber] as Node2D).visible = false
	GameState.notify("Cutoff %d disconnected. %d of 4 secured." % [chamber + 1, _cutoffs_done.size()])
	GameState.military_changed.emit()

func start_climax() -> void:
	if story_step() != 7 or not _has_flag(ASSASSINATION_FLAG) or not _guard_phase or _cutoffs_done.size() != 4 or _climax_time >= 0.0:
		return
	_climax_time = CLIMAX_SECONDS
	_last_climax_second = ceili(_climax_time)
	_relay_done.clear()
	GameState.military_changed.emit()

func _finish_climax() -> void:
	if story_step() != 7 or _climax_time < 0.0 or _relay_done.size() != 5 or _cutoffs_done.size() != 4:
		return
	_climax_time = -1.0
	_set_flag(FLAGS[7])
	if davor != null and is_instance_valid(davor):
		davor.set_order("follow")
	_clear_story_crew()
	_sync_world_state()
	_configure_citizens()
	_play([{"speaker": "Technician", "text": "The relay is back under city control. Your earlier pump repairs held throughout. Take the orders to the council."}])

func _reset_finale() -> void:
	_climax_time = -1.0
	_last_climax_second = -1
	_guard_phase = false
	_cutoffs_done.clear()
	_relay_done.clear()
	if davor != null and is_instance_valid(davor):
		davor.set_order("follow")
	for actor in actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("story_skoljka_climax_"):
			actor.queue_free()
	_configure_citizens()

func _fail_climax() -> void:
	_reset_finale()
	_sync_world_state()
	player.global_position = _nearby_open_position(marker("pump_console"))
	GameState.notify("The backup link tripped. The pumps still run locally, but Martin's spies have restored their boxes. Restart at pump control.")
	GameState.military_changed.emit()

func _show_depot_watchers() -> void:
	for index in range(4):
		var watcher := Node2D.new()
		watcher.name = "DepotWatcher_%d" % index
		watcher.global_position = marker("crew_patrol_%d" % index)
		watcher.z_index = 100 + int(watcher.global_position.y)
		var ring := Line2D.new()
		ring.width = 1.0
		ring.default_color = Color(1.0, 0.55, 0.25, 0.45)
		ring.z_index = -1
		for point in range(33):
			var angle := float(point) * TAU / 32.0
			ring.add_point(Vector2.from_angle(angle) * 56.0)
		watcher.add_child(ring)
		var sprite := Sprite2D.new()
		sprite.texture = load(CREW_TEXTURE) as Texture2D
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.position = Vector2(-9, -24)
		watcher.add_child(sprite)
		actors_root.add_child(watcher)
		_depot_watchers.append(watcher)

func _clear_depot_watchers() -> void:
	for watcher in _depot_watchers:
		if is_instance_valid(watcher):
			watcher.queue_free()
	_depot_watchers.clear()

func _clear_story_crew() -> void:
	_clear_depot_watchers()
	for actor in actors_root.get_children():
		if actor is Enemy and String(actor.persistent_id).begins_with("story_skoljka_"):
			actor.queue_free()

func _spawn_crew(position: Vector2, stable_id: String) -> void:
	if not position.is_finite():
		return
	for actor in actors_root.get_children():
		if actor is Enemy and actor.persistent_id == stable_id and not actor.is_queued_for_deletion():
			return
	var enemy := Enemy.new()
	enemy.name = "CompanyCrew_%s" % stable_id
	enemy.configure("company_crew", CREW_TEXTURE, _nearby_open_position(position), stable_id)
	actors_root.add_child(enemy)

func _spawn_creature(position: Vector2, stable_id: String) -> void:
	if GameState.defeated_persistent_enemies.has(stable_id):
		return
	for actor in actors_root.get_children():
		if actor is Enemy and actor.persistent_id == stable_id and not actor.is_queued_for_deletion():
			return
	var enemy := Enemy.new()
	enemy.name = "SeaCreature_%s" % stable_id
	enemy.configure("sea_creature", CREATURE_TEXTURE, _nearby_open_position(position), stable_id)
	actors_root.add_child(enemy)

func _spawn_davor(position: Vector2) -> void:
	davor = RaidSoldier.new()
	davor.name = "Davor"
	davor.configure("davor", "Davor", DAVOR_TEXTURE, position, "sword", 0, self)
	davor.max_health = 260
	davor.health = 260
	davor.armor = 0
	davor.speed = 100.0
	davor.strike_damage = 45
	davor.strike_cooldown = 0.6
	davor.follow_sight = 140.0
	davor.bow_range = 150.0
	davor.can_leap = true
	davor.get_up_seconds = 10.0
	actors_root.add_child(davor)

func _sync_world_state() -> void:
	if tiled_loader == null or not tiled_loader.map_loaded:
		return
	_set_group("housing_leak", not _has_flag(FLAGS[1]))
	_set_group("housing_west", false)
	_set_group("housing_inner", _has_flag("skoljka_housing_inner_closed") and not _has_flag(FLAGS[1]))
	if _interactions.has("housing_lever"):
		(_interactions["housing_lever"] as Node2D).visible = not _has_flag("skoljka_housing_inner_closed")
	_set_group("pumps", not _has_flag(FLAGS[1]))
	_set_group("lower_works", not _has_flag(FLAGS[3]))
	_set_group("lower_a", not _has_flag("skoljka_lower_a_drained"))
	_set_group("lower_b", not _has_flag("skoljka_lower_b_drained"))
	_set_group("lower_a_west", not _has_flag("skoljka_lower_a_drained"))
	_set_group("lower_a_east", not _has_flag("skoljka_lower_a_drained"))
	_set_group("lower_b_west", not _has_flag("skoljka_lower_b_drained"))
	_set_group("lower_b_east", not _has_flag("skoljka_lower_b_drained"))
	_set_group("hatch_west", not (_suit_on and _active_airlock == "west"))
	_set_group("hatch_east", not (_suit_on and _active_airlock == "east"))
	_set_group("depot_front", story_step() < 6 or (story_step() == 6 and _depot_route.is_empty()))
	_set_group("depot_back", not _has_flag(FLAGS[6]))
	for person in story_people.values():
		if is_instance_valid(person):
			person.visible = true
	if not _has_flag(FLAGS[5]):
		_spawn_creature(marker("creature_0"), "skoljka_creature_0")
		_spawn_creature(marker("creature_1"), "skoljka_creature_1")
		_spawn_creature(marker("creature_2"), "skoljka_creature_2")
	else:
		for actor in actors_root.get_children():
			if actor is Enemy and actor.enemy_id == "sea_creature":
				actor.queue_free()
	for index in range(4):
		if _interactions.has("cutoff_%d" % index):
			(_interactions["cutoff_%d" % index] as Node2D).visible = story_step() == 7 and _has_flag(ASSASSINATION_FLAG) and not _cutoffs_done.has(index)
	_set_respawn_point()

func _set_group(id: String, blocked: bool) -> void:
	if tiled_loader != null and tiled_loader.has_group(id):
		tiled_loader.set_group_blocked(id, blocked)

func _begin() -> void:
	_begin_queued = false
	_sync_world_state()
	if not _has_flag(FLAGS[0]):
		player.global_position = _nearby_open_position(GameState.SKOLJKA_ARRIVAL)
		GameState.player_position = player.global_position
		_tell("Port Officer", "Talk to the port officer to find out why the company is here.")

func _queue_begin() -> void:
	if _begin_queued:
		return
	_begin_queued = true
	call_deferred("_begin")

func _on_player_respawned() -> void:
	super._on_player_respawned()
	_suit_on = false
	_active_airlock = ""
	player.set_costume_texture("")
	player.damage_scale = 1.0
	_air = AIR_MAX
	_climax_time = -1.0
	_last_climax_second = -1
	_valves_done.clear()
	_relay_done.clear()
	_depot_route = ""
	_depot_alerted = false
	_assassin_active = false
	_assassin = null
	_guard_phase = false
	_cutoffs_done.clear()
	_escort_active = false
	_clear_story_crew()
	if davor != null and is_instance_valid(davor):
		davor.set_order("follow")
	_sync_world_state()
	_configure_citizens()
	_refresh_location_title()

func _has_flag(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has(flag)

func _set_flag(flag: String) -> void:
	if not _has_flag(flag):
		GameState.defeated_persistent_enemies.append(flag)
		GameState.military_changed.emit()

func _tell(speaker: String, text: String) -> void:
	_play([{"speaker": speaker, "text": text}])

func _play(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("play_scene"):
		ui.play_scene(lines, finished, choices)
	else:
		for line: Dictionary in lines:
			GameState.notify(String(line.get("text", "")))
		if finished.is_valid():
			finished.call()
