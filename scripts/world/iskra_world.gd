class_name IskraWorld
extends GameWorld

const ISKRA_MAP := "res://maps/iskra.tmj"
const Citizen = preload("res://scripts/actors/iskra_citizen.gd")
const RESIDENT_ROUTE_OFFSETS := [Vector2(80, 0), Vector2(0, 80), Vector2(-80, 0), Vector2(0, -80), Vector2(64, 48), Vector2(-64, 48), Vector2(-64, -48), Vector2(64, -48), Vector2(40, 0), Vector2(0, 40), Vector2(-40, 0), Vector2(0, -40)]
const FLAGS := ["iskra_arrival", "iskra_registered", "iskra_tower_received"]
const TAXI_FARE := 5
const TAXI_PADS := {"dock": "Passenger dock", "tower": "Tower of Engineering", "market": "Market", "park": "Punk Park", "cruiser": "Cruiser gangway"}
const RESIDENT_LINES := [
	"A Cruiser takes years to build. That one stays beside the city until its next patrol.",
	"The Engineering Board elects the heads of our departments for short terms. Their offices are in the Tower.",
	"Rudnik sends ore; Iskra turns it into ship plates, gears and tools. A late ore ship delays half this street.",
	"I have family on Skoljka. It is good to hear the pumps are running again.",
	"The Punk Park is loud after work. The rest of the city prefers ordinary street lamps.",
	"Personal ships use the canals. Take a footbridge if you are walking, or call a taxi at a marked pad.",
	"Tvrdium armor is made here, but the navy has reserved this month's production.",
	"The greenhouse towers grow food under lamps. The cargo boats bring everything else.",
]

var markers: Dictionary = {}
var davor: RaidSoldier
var story_people: Dictionary = {}
var traffic: Array[Dictionary] = []
var taxi_active := false
var _taxi_departure := Vector2.ZERO
var _taxi_ship: Sprite2D
var _taxi_tween: Tween

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	tiled_loader.actor_spawn_requested.connect(_on_actor_spawn_requested)
	add_child(tiled_loader)
	if not tiled_loader.load_map(ISKRA_MAP):
		push_error("Iskra map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ISKRA_MAP))
	for layer: Dictionary in data["layers"]:
		if layer["name"] == "Markers":
			for point: Dictionary in layer["objects"]:
				markers[point["name"]] = Vector2(point["x"], point["y"])
	_spawn_player(GameState.ISKRA_ARRIVAL, "res://art/concepts/source/player.png")
	player.respawn_position = marker("respawn")
	player.respawn_location_name = "Iskra passenger dock"
	_spawn_davor()
	_spawn_interactions()
	_configure_residents()
	_spawn_traffic()
	apply_loaded_state()

func marker(id: String) -> Vector2:
	return Vector2(markers.get(id, GameState.ISKRA_ARRIVAL))

func location_title() -> String:
	return "ISKRA"

func story_step() -> int:
	for index in FLAGS.size():
		if not GameState.defeated_persistent_enemies.has(FLAGS[index]):
			return index
	return FLAGS.size()

func story_status_text() -> String:
	return ["Speak to the officer at the passenger dock.", "Register at the police post west of the Tower of Engineering.", "Report to the clerk at the Tower of Engineering.", "The Board has received your request. Explore Iskra while you wait."][story_step()]

func _safe_loaded_position(saved: Vector2) -> Vector2:
	return saved if saved.is_finite() and tiled_loader.is_walkable_position(saved) else marker("arrival")

func capture_player_position() -> void:
	GameState.remember_player_position(_taxi_departure if taxi_active else player.global_position)

func apply_loaded_state() -> void:
	_cancel_taxi()
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	_move_davor()

func _on_player_respawned() -> void:
	_cancel_taxi()
	super._on_player_respawned()
	_move_davor()

func _move_davor() -> void:
	davor.global_position = tiled_loader.nearest_walkable_position(player.global_position + Vector2(-24, 16))
	davor.velocity = Vector2.ZERO
	davor.set_order("follow")

func _spawn_davor() -> void:
	davor = RaidSoldier.new()
	davor.name = "Davor"
	davor.configure("davor", "Davor", "res://assets/art/engineeria/davor.png", GameState.ISKRA_ARRIVAL, "sword", 0, self)
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

func _on_actor_spawn_requested(kind: String, position: Vector2, texture: String, id: String) -> void:
	if kind != "story":
		return
	var resident := Citizen.new()
	resident.configure(id, "Iskra Resident", texture, position, tiled_loader)
	resident.service_id = "iskra:" + id
	actors_root.add_child(resident)
	resident.service_requested.connect(_on_service_requested)
	story_people[id] = resident

func _configure_residents() -> void:
	for id: String in story_people:
		var resident := story_people[id] as IskraCitizen
		if resident == null:
			continue
		var start := tiled_loader.nearest_walkable_position(resident.home_position)
		if not start.is_finite() or start.distance_to(resident.home_position) > 96.0:
			continue
		start = (start / 16.0).floor() * 16.0 + Vector2(8, 8)
		var stops := PackedVector2Array([start])
		var seed_value := absi(id.hash())
		for slot in RESIDENT_ROUTE_OFFSETS.size():
			var offset: Vector2 = RESIDENT_ROUTE_OFFSETS[(slot + seed_value) % RESIDENT_ROUTE_OFFSETS.size()]
			var destination := tiled_loader.nearest_walkable_position(start + offset)
			if not destination.is_finite():
				continue
			destination = (destination / 16.0).floor() * 16.0 + Vector2(8, 8)
			if not tiled_loader.is_walkable_position(destination) or destination.distance_to(start) > 112.0:
				continue
			var too_close := false
			for stop in stops:
				too_close = too_close or destination.distance_to(stop) < 28.0
			for service_id: String in story_people:
				if story_people[service_id] is StationStaff and destination.distance_to(story_people[service_id].global_position) < 28.0:
					too_close = true
			if too_close:
				continue
			if not _resident_path_fits(stops[-1], destination, start) or not _resident_path_fits(destination, start, start):
				continue
			stops.append(destination)
			if stops.size() == 3:
				break
		if stops.size() > 1:
			resident.wait_at(start)
			resident.home_position = start
			resident.set_route(stops)
			resident._stop_index = 1
			resident._wait = float(seed_value % 7) * .15

func _resident_path_fits(start: Vector2, destination: Vector2, home: Vector2) -> bool:
	var path := tiled_loader.get_walk_path(start, destination)
	if path.is_empty():
		return false
	var length := 0.0
	for index in path.size():
		if path[index].distance_to(home) > 144.0:
			return false
		if index > 0:
			length += path[index-1].distance_to(path[index])
	return length <= 240.0

func _spawn_interactions() -> void:
	var entries := {"dock_officer": "Dock Officer", "police": "Police Clerk", "tower": "Tower Clerk", "food": "Food Hall", "forge": "Forge & Armor", "library": "Iskra Library", "farm": "Automated Farms", "park": "Punk Park", "nature_park": "Nature Park", "cruiser": "Navy Cruiser"}
	for id: String in TAXI_PADS:
		entries["taxi_" + id] = "%s air taxi" % TAXI_PADS[id]
	for id: String in entries:
		var staff := StationStaff.new()
		var roles := {"dock_officer": "board_officer", "police": "police_clerk", "tower": "civic_engineer", "food": "market_keeper", "forge": "dock_mechanic", "library": "library_archivist", "farm": "greenhouse_worker", "park": "park_artist", "nature_park": "greenhouse_worker", "cruiser": "tower_guard"}
		var image: String = roles.get(id, "sky_courier")
		staff.configure("iskra:" + id, entries[id], "res://assets/art/iskra/npcs/%s.png" % image, marker(id))
		if id in ["library", "farm", "park", "nature_park", "cruiser"]:
			staff.interaction_text = "Read about %s" % entries[id]
		if id.begins_with("taxi_"):
			staff.interaction_text = "Call air taxi — %d gold" % TAXI_FARE
		actors_root.add_child(staff)
		staff.service_requested.connect(_on_service_requested)
		story_people[id] = staff

func _on_service_requested(id: String, title: String) -> void:
	if taxi_active:
		return
	var key := id.trim_prefix("iskra:")
	if key.begins_with("taxi_"):
		_taxi_menu(key.trim_prefix("taxi_"))
		return
	if key.begins_with("resident_"):
		_tell(title, RESIDENT_LINES[int(key.trim_prefix("resident_")) % RESIDENT_LINES.size()])
		return
	match key:
		"dock_officer":
			_set_flag(FLAGS[0])
			_tell(title, "Welcome to Iskra. Register at the police post west of the Tower of Engineering, then take your request to the Tower clerk. The marked pads offer air taxis for five gold.")
		"police":
			if story_step() < 1:
				_tell(title, "First speak to the officer at the passenger dock.")
			else:
				_set_flag(FLAGS[1])
				_tell(title, "Two arrivals from Skoljka: you and Davor. You are registered. Take your account of the company to the Tower of Engineering.")
		"tower":
			if story_step() < 2:
				_tell(title, "Please register with the police before requesting an audience.")
			else:
				_set_flag(FLAGS[2])
				_tell(title, "Your request is recorded. The Engineering Board will hear your account of Skoljka later. You and Davor may visit the city while you wait.")
		"food", "forge":
			var ui := get_tree().get_first_node_in_group("game_ui")
			if ui != null:
				ui.open_service("iskra_" + key, title)
		"library": _tell("Iskra Library", "Engineeria's engineers built Iskra as an artificial planet. It became the nation's capital and most populous member. The Engineering Board meets in the Tower of Engineering; each elected department head serves a short term.")
		"farm": _tell("Automated Farms", "Greenhouse towers grow vegetables under lamps. Water and nutrients circulate through the trays; the maintenance crews check every pump each morning.")
		"park": _tell("Punk Park", "Music, painted walls and colored lamps fill this corner of Iskra. Keep the footpaths clear and leave room beside the landing pad.")
		"nature_park": _tell("Nature Park", "Real soil, grass and trees, carried here from Engineeria's other planets. The gardeners tend the roots beneath the paths. Sit a while; the warm lamps stay on after the shops close.")
		"cruiser": _tell("Navy Cruiser", "The cruiser lies parallel to the city's edge, tied to three piers. Its deck is closed to visitors while the crew prepares for patrol.")

func _set_flag(id: String) -> void:
	if not GameState.defeated_persistent_enemies.has(id):
		GameState.defeated_persistent_enemies.append(id)
		GameState.military_changed.emit()

func _tell(speaker: String, text: String, choices: Array = []) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null:
		ui.play_scene([{"speaker": speaker, "text": text}], Callable(), choices)
	else:
		GameState.notify(text)

func _taxi_menu(origin: String) -> void:
	var choices: Array = []
	for destination: String in TAXI_PADS:
		if destination != origin:
			choices.append({"label": "%s — %d gold" % [TAXI_PADS[destination], TAXI_FARE], "action": func() -> void: ride_taxi(origin, destination)})
	choices.append({"label": "Stay here", "action": Callable()})
	_tell("Taxi Pilot", "Where are you and your companion going? Five gold covers both seats.", choices)

func ride_taxi(origin: String, destination: String) -> bool:
	if taxi_active or not TAXI_PADS.has(origin) or not TAXI_PADS.has(destination) or origin == destination:
		return false
	if player.global_position.distance_to(marker("taxi_" + origin)) > 96.0:
		return false
	if not GameState.spend_gold(TAXI_FARE):
		GameState.notify("You need %d gold for the air taxi." % TAXI_FARE)
		return false
	taxi_active = true
	_taxi_departure = player.global_position
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.visible = false
	davor.visible = false
	davor.set_physics_process(false)
	_taxi_ship = Sprite2D.new()
	_taxi_ship.texture = load("res://assets/art/iskra/ship_2.png")
	_taxi_ship.scale = Vector2(2, 2)
	_taxi_ship.z_index = 4000
	_taxi_ship.position = marker("taxi_" + origin)
	add_child(_taxi_ship)
	var camera := Camera2D.new()
	camera.zoom = _camera.zoom
	_taxi_ship.add_child(camera)
	camera.make_current()
	GameState.notify("Flying to %s with Davor." % TAXI_PADS[destination])
	_taxi_tween = create_tween()
	_taxi_tween.tween_property(_taxi_ship, "position", marker("taxi_" + destination), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_taxi_tween.tween_callback(func() -> void:
		player.global_position = marker("taxi_" + destination)
		_cancel_taxi()
		_move_davor()
		GameState.remember_player_position(player.global_position)
		GameState.notify("Arrived at %s." % TAXI_PADS[destination]))
	return true

func _cancel_taxi() -> void:
	if _taxi_tween != null and _taxi_tween.is_running():
		_taxi_tween.kill()
	if is_instance_valid(_taxi_ship):
		_taxi_ship.queue_free()
	_taxi_ship = null
	taxi_active = false
	if player != null:
		player.visible = true
		player.set_physics_process(true)
		_camera.make_current()
	if davor != null:
		davor.visible = true
		davor.set_physics_process(true)

func _spawn_traffic() -> void:
	var routes := [PackedVector2Array([Vector2(0, 520), Vector2(300, 500), Vector2(620, 466), Vector2(910, 474), Vector2(1220, 486), Vector2(1800, 496)]), PackedVector2Array([Vector2(0, 912), Vector2(330, 930), Vector2(620, 896), Vector2(928, 900), Vector2(1240, 918), Vector2(1800, 908)]), PackedVector2Array([Vector2(910, 474), Vector2(890, 700), Vector2(928, 900), Vector2(910, 1250)])]
	for i in range(24):
		var route: PackedVector2Array = routes[i % routes.size()].duplicate()
		for j in route.size():
			route[j] = (route[j] + Vector2(0, 60)) * 2
		if i % 2 == 1:
			route.reverse()
		var curve := Curve2D.new()
		for point in route:
			curve.add_point(point)
		var ship := Sprite2D.new()
		ship.texture = load("res://assets/art/iskra/ship_%d.png" % (i % 6))
		ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ship.scale = Vector2(2, 2)
		ship.z_index = 3900
		add_child(ship)
		traffic.append({"sprite": ship, "curve": curve, "distance": curve.get_baked_length() * float(i) / 24.0, "speed": 50.0 + i % 5 * 8})

func _process(delta: float) -> void:
	for craft in traffic:
		var curve: Curve2D = craft["curve"]
		craft["distance"] = fmod(float(craft["distance"]) + delta * float(craft["speed"]), curve.get_baked_length())
		var ship: Sprite2D = craft["sprite"]
		ship.position = curve.sample_baked(craft["distance"])
		var next := curve.sample_baked(minf(float(craft["distance"]) + 3.0, curve.get_baked_length()))
		ship.flip_h = next.x < ship.position.x
