class_name EngineeriaWorld
extends GameWorld

## Rudnik, the mining planet of Engineeria where the diplomatic ship came down.
##
## The player wakes by the wreck beside the three dead envoys and takes Iva
## Most's letters. Forest beasts come out of the trees behind them, and the
## only way out is to run for the chimney smoke in the northeast. Entering the
## clearing round the house brings Davor out to kill the beasts; he then joins
## the player and sends them east to the Rudnik mining port.
##
## The port's wall has no gap. The player goes through the wicket gate by
## ringing the bell outside or pulling the lever inside, which moves them to the
## other side; Davor jumps the wall after them. Inside, the mine lift's winch
## has broken a gear with four miners below. The player inspects the lift,
## fetches a spare gear from the maintenance shed, repairs the winch and runs
## two trips of the cage, and the ore ship's captain then promises them and
## Davor two seats on the next run. Boarding the ship then takes them to
## Skoljka, the sea city that buys Rudnik's ore; there is no ship back.
##
## The chase is never saved halfway. Being downed, or loading a save made
## during it, puts the player back by the wreck and starts it again. Once the
## player has reached the clearing, being downed wakes them at Davor's door with
## the beasts dead, and once they have been inside the port, by its gate.
## Every finished step of the rescue is a saved flag; a cage trip in progress
## is not saved and starts again.

const ENGINEERIA_MAP := "res://maps/engineeria.tmj"
## Set when the player has taken the letters from the wreck.
const LETTERS_FLAG := "engineeria_letters_taken"
## Set when Davor joins the player.
const DAVOR_FLAG := "davor_met"
const LETTERS_ITEM := "embassy_letters"
## The rescue at the port, one flag per finished step, in order.
const PORT_FLAG := "rudnik_port_entered"
const LIFT_FLAG := "rudnik_lift_inspected"
const GEAR_FLAG := "rudnik_gear_taken"
const WINCH_FLAG := "rudnik_winch_repaired"
const TRIP_FLAG := "rudnik_trip_1"
const RESCUED_FLAG := "rudnik_workers_rescued"
const PASSAGE_FLAG := GameState.PASSAGE_FLAG
## Set when the player sails for Skoljka on the ore ship.
const SAILED_FLAG := "rudnik_sailed"
const GEAR_ITEM := "winch_gear"
const RESCUE_REWARD := 60
const STORY_SERVICE_PREFIX := "rudnik_story:"
const STORY_PEOPLE := {
	"foreman": "Foreman Zora",
	"captain": "Captain Bruno",
	"dispatcher": "Dispatcher Tin",
	"gatekeeper": "Gatekeeper Mirko",
	"resident_0": "Ana",
	"resident_1": "Kruno",
	"miner_0": "Miner Ante",
	"miner_1": "Miner Dora",
	"miner_2": "Miner Josip",
	"miner_3": "Miner Nela",
}
## The port inside its wall; tools/build_engineeria_world.py PORT, less the wall.
const PORT_RECT := Rect2(1712, 80, 624, 608)
## The wicket gate in the west wall: the bell outside, the lever inside, and
## where each one puts the player down on the far side.
const GATE_BELL := Vector2(1682, 328)
const GATE_LEVER := Vector2(1726, 328)
const GATE_INSIDE := Vector2(1736, 344)
const GATE_OUTSIDE := Vector2(1672, 344)
## A cage trip takes TRIP_SECONDS with the player beside the winch. Halfway up
## the brake slips, and the player has BRAKE_SECONDS to hold it at the winch.
const TRIP_SECONDS := 10.0
const BRAKE_AT := 5.0
const BRAKE_SECONDS := 3.0
const WINCH_REACH := 72.0
## Davor is put beside the player when he has been this far off for CATCH_UP_SECONDS.
const CATCH_UP_DISTANCE := 320.0
const CATCH_UP_SECONDS := 8.0
## Beasts that prowl the forest round the port; they keep to their ground and
## cannot pass the wall. Cells.
const PROWLER_CELLS := [Vector2i(99, 56), Vector2i(122, 61), Vector2i(140, 62)]
## The mown clearing round Davor's yard; tools/build_engineeria_world.py CLEARING.
const CLEARING_RECT := Rect2(1120, 32, 384, 336)
## Davor's front door, and the gap in the yard's south fence.
const DAVOR_DOOR := Vector2(1330, 202)
const YARD_GATE := Vector2(1336, 296)
## Where the player wakes after being downed once Davor travels with them.
const HOUSE_FRONT := Vector2(1336, 232)
## The chimney smoke the player runs for; progress is measured towards it.
const SMOKE_POINT := Vector2(1336, 300)
const BEAST_TEXTURE := "res://assets/art/engineeria/forest_beast.png"
const DAVOR_TEXTURE := "res://assets/art/engineeria/davor.png"
const FIRST_GROUP := 3
const SECOND_GROUP := 3
## The second group comes this many seconds after the first.
const SECOND_GROUP_SECONDS := 9.0
## A beast comes out at the player's side when they have not got PROGRESS_STEP
## pixels closer to the smoke in STALL_SECONDS.
const STALL_SECONDS := 6.0
const PROGRESS_STEP := 48.0
const MAX_BEASTS := 8
## Beasts come out of the trees this far behind the player.
const SPAWN_DISTANCE := 190.0
## When Davor comes out, beasts farther than this from the player go back into the forest.
const RESCUE_RADIUS := 360.0
## Beasts this close to Davor during the rescue turn on him and leave the player.
const DAVOR_DRAW_RADIUS := 90.0
## Davor: an old man, about level 8, with no armor, an ordinary sword and a bow.
const DAVOR_LEVEL := 8
const DAVOR_HEALTH := 260
## Two strikes kill a forest beast (90 health, no armor).
const DAVOR_DAMAGE := 45
const DAVOR_STRIKE_SECONDS := 0.6
const DAVOR_SPEED := 100.0
const DAVOR_SIGHT := 140.0
const DAVOR_BOW_RANGE := 150.0
const DAVOR_GET_UP_SECONDS := 10.0

var _chasing := false
var _chase_time := 0.0
var _second_group_sent := false
var _stall_time := 0.0
var _closest_to_smoke := INF
var _beasts: Array[Enemy] = []
var _beast_count := 0
var _davor: RaidSoldier
## True from Davor coming out of the house until his introduction is read.
var _rescue := false
var _rescue_time := 0.0
var _begin_queued := false
var _story: Dictionary = {}
var _gate_bell: StationStaff
var _gate_lever: StationStaff
var _prowlers: Array[Enemy] = []
## Seconds into the current cage trip, or -1 with no trip running.
var _trip_time := -1.0
## Seconds left to hold the brake, or -1 while it holds.
var _brake_left := -1.0
var _davor_far_time := 0.0

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
	if not tiled_loader.load_map(ENGINEERIA_MAP):
		push_error("Engineeria map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	_spawn_gate()
	if player == null:
		_spawn_player(GameState.ENGINEERIA_ARRIVAL, "res://art/concepts/source/player.png")
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.squad_changed.connect(_sync_squad)
	_sync_squad()
	_queue_begin()

func _spawn_player(position: Vector2, texture_path: String) -> void:
	super._spawn_player(position, texture_path)
	_set_respawn_point()

func _set_respawn_point() -> void:
	if player == null:
		return
	if _has_flag(PORT_FLAG):
		player.respawn_position = GATE_INSIDE
		player.respawn_location_name = "the Rudnik port gate"
		player.respawn_notice = ""
	elif _has_flag(DAVOR_FLAG):
		player.respawn_position = HOUSE_FRONT
		player.respawn_location_name = "Davor's house"
		player.respawn_notice = ""
	elif _rescue:
		player.respawn_position = HOUSE_FRONT
		player.respawn_location_name = "the old man's house"
		player.respawn_notice = "You come to on the grass by the old man's door. The beasts are dead."
	else:
		player.respawn_position = GameState.ENGINEERIA_ARRIVAL
		player.respawn_location_name = "the crash site"
		player.respawn_notice = "You come to beside the wreck. In the trees, the howling starts again." if _has_flag(LETTERS_FLAG) else ""

# ---- queries ----

func location_title() -> String:
	if not _has_flag(DAVOR_FLAG):
		return "UNKNOWN FOREST"
	return "RUDNIK PORT" if in_port(player.global_position if player != null else Vector2.ZERO) else "RUDNIK"

## Objective text for the HUD panel in the top right.
func story_status_text() -> String:
	if _has_flag(PASSAGE_FLAG):
		return "RUDNIK\nBoard the ore ship on the pad\nwhen you are ready to sail"
	if _has_flag(RESCUED_FLAG):
		return "RUDNIK\nAsk Captain Bruno at the ore ship\nabout passage"
	if trip_running():
		return "RUDNIK\nThe cage is coming up\nHold the brake if it slips!" if _brake_left >= 0.0 else "RUDNIK\nThe cage is coming up\nStay by the winch"
	if _has_flag(WINCH_FLAG):
		return "RUDNIK\nRun the lift to bring up the miners\n(%d of 2 trips)" % (1 if _has_flag(TRIP_FLAG) else 0)
	if _has_flag(GEAR_FLAG):
		return "RUDNIK\nFit the winch gear at the mine lift"
	if _has_flag(LIFT_FLAG):
		return "RUDNIK\nFetch a spare winch gear\nfrom the maintenance shed"
	if _has_flag(PORT_FLAG):
		return "RUDNIK\nSee what is wrong at the mine lift"
	if _has_flag(DAVOR_FLAG):
		return "RUDNIK\nFollow the road east to the mining port\nRing the bell at the gate"
	if _rescue:
		return "UNKNOWN FOREST\nAn old man is fighting the beasts"
	if _has_flag(LETTERS_FLAG):
		return "UNKNOWN FOREST\nRun to the smoke\nin the northeast"
	return "UNKNOWN FOREST\nThe ship is down"

func chasing() -> bool:
	return _chasing

func rescuing() -> bool:
	return _rescue

func beasts() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for beast in _beasts:
		if is_instance_valid(beast) and not beast.is_queued_for_deletion() and beast.health > 0:
			alive.append(beast)
	return alive

func davor() -> RaidSoldier:
	return _davor if is_instance_valid(_davor) and not _davor.is_queued_for_deletion() else null

func in_clearing(position: Vector2) -> bool:
	return CLEARING_RECT.has_point(position)

func in_port(position: Vector2) -> bool:
	return PORT_RECT.has_point(position)

func story_person(key: String) -> StationStaff:
	return _story.get(key, null)

func gate_bell() -> StationStaff:
	return _gate_bell

func gate_lever() -> StationStaff:
	return _gate_lever

func prowlers() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for beast in _prowlers:
		if is_instance_valid(beast) and not beast.is_queued_for_deletion():
			alive.append(beast)
	return alive

func trip_running() -> bool:
	return _trip_time >= 0.0

func brake_slipping() -> bool:
	return _brake_left >= 0.0

func _has_flag(flag: String) -> bool:
	return GameState.defeated_persistent_enemies.has(flag)

func _set_flag(flag: String) -> void:
	if not _has_flag(flag):
		GameState.defeated_persistent_enemies.append(flag)
	GameState.military_changed.emit()

# ---- scenes ----

func _play(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("play_scene"):
		ui.play_scene(lines, finished, choices)
	else:
		for line: Dictionary in lines:
			GameState.notify(String(line["text"]))
		if finished.is_valid():
			finished.call()

## A line Davor speaks; he is "Old Man" until he gives his name.
func _davor_line(text: String, named: bool = true) -> Dictionary:
	return {"speaker": "Davor" if named else "Old Man", "text": text, "focus": davor()}

## Sets up the current step of the story once the world is in the tree. Called
## after arriving, loading and being downed.
func _queue_begin() -> void:
	if _begin_queued:
		return
	_begin_queued = true
	call_deferred("_begin")

func _begin() -> void:
	_begin_queued = false
	_clear_fighters()
	_set_respawn_point()
	_refresh_location_title()
	_sync_story_people()
	if _has_flag(DAVOR_FLAG):
		_spawn_davor(_nearby_open_position(player.global_position + Vector2(-18, 16)))
		_davor_follows()
		_spawn_prowlers()
	elif _has_flag(LETTERS_FLAG):
		start_chase()
	else:
		_crash_scene()

func _crash_scene() -> void:
	player.global_position = GameState.ENGINEERIA_ARRIVAL
	GameState.player_position = player.global_position
	var cover := screen_flash(Color.BLACK, 1.6, 0.4)
	cover.modulate.a = 1.0
	_play([
		{"speaker": "", "text": "Smoke. Heat on one side of your face, and wet leaves under the other."},
		{"speaker": "", "text": "The diplomatic ship lies broken in two at the end of a long scar through the trees. Nothing moves inside it."},
		{"speaker": "", "text": "Petar Lis was thrown clear of the hull. Nada Grof and Oto Ban lie a little further on. None of the three is breathing."},
		{"speaker": "", "text": "Petar's case has split open beside him. Iva Most's letters are inside, the Council seal unbroken."},
		{"speaker": "", "text": "You take the letters. There is nobody else left to carry them."},
		{"speaker": "", "text": "Away to the northeast, a thin line of smoke rises over the trees: a chimney, not a fire."},
		{"speaker": "", "text": "Something howls in the forest behind you. Something else answers it, closer."},
	], take_letters)

## The player takes Iva Most's letters from the wreck, and the chase starts.
func take_letters() -> void:
	if _has_flag(LETTERS_FLAG):
		return
	if int(GameState.inventory.get(LETTERS_ITEM, 0)) <= 0:
		GameState.add_item(LETTERS_ITEM)
	GameState.notify("Took the Sealed Embassy Letters.")
	_set_flag(LETTERS_FLAG)
	_set_respawn_point()
	start_chase()

# ---- the chase ----

func start_chase() -> void:
	if _has_flag(DAVOR_FLAG) or not _has_flag(LETTERS_FLAG):
		return
	_clear_fighters()
	_chasing = true
	_chase_time = 0.0
	_second_group_sent = false
	_stall_time = 0.0
	_closest_to_smoke = player.global_position.distance_to(SMOKE_POINT)
	_spawn_beasts_behind(FIRST_GROUP)
	GameState.notify("Beasts break out of the trees behind you. Run for the smoke!")
	GameState.military_changed.emit()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if _chasing:
		_step_chase(delta)
	elif _rescue:
		_step_rescue(delta)
	elif _has_flag(DAVOR_FLAG):
		_step_trip(delta)
		_step_davor_catch_up(delta)

func _step_chase(delta: float) -> void:
	if in_clearing(player.global_position):
		_davor_comes_out()
		return
	_chase_time += delta
	if not _second_group_sent and _chase_time >= SECOND_GROUP_SECONDS:
		_second_group_sent = true
		_spawn_beasts_behind(SECOND_GROUP)
	var left := player.global_position.distance_to(SMOKE_POINT)
	if left < _closest_to_smoke - PROGRESS_STEP:
		_closest_to_smoke = left
		_stall_time = 0.0
	else:
		_stall_time += delta
		if _stall_time >= STALL_SECONDS:
			_stall_time = 0.0
			_closest_to_smoke = minf(_closest_to_smoke, left)
			_spawn_beast_at_side()

## Runs the chase forward; used by the tests.
func advance_chase(seconds: float) -> void:
	var step := 0.25
	var left := seconds
	while left > 0.0 and _chasing:
		_step_chase(minf(step, left))
		left -= step

func _spawn_beasts_behind(count: int) -> void:
	var away := (player.global_position - SMOKE_POINT).normalized()
	for index in count:
		var angle := (index - (count - 1) * 0.5) * 0.45
		_spawn_beast(_open_point_near(player.global_position + away.rotated(angle) * SPAWN_DISTANCE))

func _spawn_beast_at_side() -> void:
	if beasts().size() >= MAX_BEASTS:
		return
	var toward := (SMOKE_POINT - player.global_position).normalized()
	var side := toward.rotated(PI * 0.5 if _beast_count % 2 == 0 else -PI * 0.5)
	_spawn_beast(_open_point_near(player.global_position + side * SPAWN_DISTANCE * 0.8))
	GameState.notify("Another beast comes crashing through the undergrowth.")

func _open_point_near(point: Vector2) -> Vector2:
	var map_rect := Rect2(Vector2(40, 40), tiled_loader.map_size - Vector2(80, 80))
	point = point.clamp(map_rect.position, map_rect.end)
	if in_clearing(point):
		point.y = CLEARING_RECT.end.y + 24.0
	return _nearby_open_position(point)

func _spawn_beast(position: Vector2) -> void:
	if beasts().size() >= MAX_BEASTS:
		return
	_beast_count += 1
	var beast := Enemy.new()
	beast.configure("forest_beast", BEAST_TEXTURE, position, "story_beast_%d_%d" % [Time.get_ticks_msec(), _beast_count])
	beast.name = "ForestBeast_%d" % _beast_count
	beast.relentless = true
	actors_root.add_child(beast)
	_beasts.append(beast)

func _clear_fighters() -> void:
	_chasing = false
	_rescue = false
	_trip_time = -1.0
	_brake_left = -1.0
	for beast in _beasts + _prowlers:
		if is_instance_valid(beast):
			beast.queue_free()
	_beasts.clear()
	_prowlers.clear()
	if is_instance_valid(_davor):
		_davor.queue_free()
	_davor = null
	for projectile in actors_root.get_children():
		if projectile is Projectile:
			projectile.queue_free()

# ---- Davor ----

func _spawn_davor(position: Vector2) -> void:
	_davor = RaidSoldier.new()
	_davor.name = "Davor"
	_davor.configure("davor", "Davor", DAVOR_TEXTURE, position, "sword", 0, self)
	_davor.max_health = DAVOR_HEALTH
	_davor.health = DAVOR_HEALTH
	_davor.armor = 0
	_davor.speed = DAVOR_SPEED
	_davor.strike_damage = DAVOR_DAMAGE
	_davor.strike_cooldown = DAVOR_STRIKE_SECONDS
	_davor.follow_sight = DAVOR_SIGHT
	_davor.bow_range = DAVOR_BOW_RANGE
	_davor.can_leap = true
	_davor.get_up_seconds = DAVOR_GET_UP_SECONDS
	var label := Label.new()
	label.name = "NameLabel"
	label.text = "%s  Lv.%d" % ["Davor" if _has_flag(DAVOR_FLAG) else "Old Man", DAVOR_LEVEL]
	label.position = Vector2(-36, -42)
	label.size = Vector2(72, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("f5c34c"))
	label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_davor.add_child(label)
	actors_root.add_child(_davor)

func _refresh_davor_label() -> void:
	var someone := davor()
	if someone == null:
		return
	var label := someone.get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = "%s  Lv.%d" % ["Davor" if _has_flag(DAVOR_FLAG) else "Old Man", DAVOR_LEVEL]

## The player reached the clearing: Davor comes out of the house and goes after the beasts.
func _davor_comes_out() -> void:
	_chasing = false
	_rescue = true
	_rescue_time = 0.0
	for beast in beasts():
		if beast.global_position.distance_to(player.global_position) > RESCUE_RADIUS:
			beast.queue_free()
	_spawn_davor(DAVOR_DOOR)
	_davor.hunt(Vector2.INF, YARD_GATE, "fight the beasts")
	_set_respawn_point()
	GameState.notify("The house door bangs open. An old man with a sword comes out at a run.")
	GameState.military_changed.emit()

func _step_rescue(delta: float) -> void:
	_rescue_time += delta
	var someone := davor()
	if someone == null:
		return
	if not beasts().is_empty():
		for beast in beasts():
			if beast.focus_target == null and beast.global_position.distance_to(someone.global_position) < DAVOR_DRAW_RADIUS:
				beast.focus_target = someone
		return
	if someone.order != "follow":
		someone.set_order("follow")
		_rescue_time = 0.0
	# Once the beasts are dead he walks over, and the introduction starts.
	if someone.global_position.distance_to(player.global_position) < 64.0 or _rescue_time > 5.0:
		_rescue = false
		_davor_intro()

## Runs the rescue forward; used by the tests.
func advance_rescue(seconds: float) -> void:
	var step := 0.25
	var left := seconds
	while left > 0.0 and _rescue:
		_step_rescue(minf(step, left))
		left -= step

func _davor_intro() -> void:
	_play([
		{"speaker": "", "text": "The old man wipes his blade on the grass and looks you over: the torn uniform, the burns, the smoke still rising in the southwest."},
		_davor_line("Sixlegs don't come this close to the house as a rule. They smelled the fire, I think. And you.", false),
		_davor_line("Davor. This is my house, and that was my fence you were running at."),
		_davor_line("A ship came down this morning. The whole forest heard it. Did anyone else walk out of it?"),
		{"speaker": "", "text": "You tell him about Petar Lis, Nada Grof and Oto Ban."},
		_davor_line("I'm sorry. I'll go down with a shovel. The beasts won't leave them be otherwise."),
		_davor_line("You're on Rudnik, if nobody told you. A mining rock of Engineeria, the far side of it from anywhere that matters. Iskra is a long way from here."),
		{"speaker": "", "text": "His eyes go to the sealed letters in your hand and stay there for a moment. He doesn't ask about them."},
		_davor_line("Whatever you carry was going to Iskra, I expect. Nobody flies a white ship out here to look at the trees."),
		_davor_line("Nothing leaves Rudnik but ore. The port is down the road east of here, behind a good wall. The ore ships go out from there, and they go towards Iskra in the end."),
		_davor_line("The forest is no place to walk alone, with those things about and whoever knocked your ship out of the sky. I'll come with you, and I'll see you to Iskra myself."),
		_davor_line("Don't thank me. I've sat in that house long enough. Let me bank the fire and fetch my pack."),
	], davor_joins)

## Davor joins the player and they set off for the port.
func davor_joins() -> void:
	_rescue = false
	_set_flag(DAVOR_FLAG)
	_set_respawn_point()
	if davor() == null:
		_spawn_davor(_nearby_open_position(player.global_position + Vector2(-18, 16)))
	_davor_follows()
	_refresh_davor_label()
	_refresh_location_title()
	GameState.record_event("davor_joined")
	_spawn_prowlers()
	GameState.notify("Davor joins you. Follow the road east to the Rudnik mining port.")

func _davor_follows() -> void:
	var someone := davor()
	if someone != null:
		someone.set_order("follow")
		someone.task_label = "walk with you"

# ---- being downed, saving and loading ----

func _on_player_respawned() -> void:
	super._on_player_respawned()
	if _has_flag(DAVOR_FLAG):
		if trip_running():
			_trip_failed("The cage slides back down to the bottom while you are out. The miners are shaken but unhurt.")
		var someone := davor()
		if someone != null and not someone.down:
			someone.global_position = _nearby_open_position(player.respawn_position + Vector2(-18, 16))
		return
	if _rescue and davor() != null:
		# Davor finished the beasts while the player was down; the introduction
		# starts as soon as he is at their side.
		for beast in beasts():
			beast.queue_free()
		_beasts.clear()
		if davor().down:
			davor().get_up()
		davor().global_position = _nearby_open_position(HOUSE_FRONT + Vector2(-18, 16))
		return
	_queue_begin()

func apply_loaded_state() -> void:
	_clear_fighters()
	if player != null:
		player.global_position = _safe_loaded_position(GameState.player_position)
		GameState.player_position = player.global_position
	_squad_ai.clear()
	_sync_squad()
	_queue_begin()

func capture_player_position() -> void:
	super.capture_player_position()
	# The chase is never saved halfway: a save during it starts it again by the wreck.
	if _has_flag(LETTERS_FLAG) and not _has_flag(DAVOR_FLAG):
		GameState.player_position = GameState.ENGINEERIA_ARRIVAL

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if not saved.is_finite():
		saved = GameState.ENGINEERIA_ARRIVAL
	if tiled_loader.is_walkable_position(saved):
		return saved
	return _nearby_open_position(saved)

func _refresh_location_title() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("refresh_location"):
		ui.refresh_location()

# ---- the Rudnik port ----

func _on_actor_spawn_requested(kind: String, position: Vector2, variant: String, stable_id: String) -> void:
	if kind != "story":
		super._on_actor_spawn_requested(kind, position, variant, stable_id)
		return
	if not STORY_PEOPLE.has(stable_id):
		push_error("Unknown story person on the Rudnik map: %s" % stable_id)
		return
	var someone := StationStaff.new()
	someone.name = "story_" + stable_id
	someone.configure(STORY_SERVICE_PREFIX + stable_id, String(STORY_PEOPLE[stable_id]), variant, position)
	someone.service_requested.connect(_on_service_requested)
	actors_root.add_child(someone)
	_story[stable_id] = someone

## The bell outside the gate and the lever inside it; neither has collision.
func _spawn_gate() -> void:
	_gate_bell = StationStaff.new()
	_gate_bell.name = "GateBell"
	_gate_bell.configure("rudnik_gate_bell", "Gate Bell", "res://assets/art/engineeria/gate_bell.png", GATE_BELL)
	_gate_bell.interaction_text = "Ring the gate bell"
	_gate_bell.service_requested.connect(_on_service_requested)
	actors_root.add_child(_gate_bell)
	_gate_lever = StationStaff.new()
	_gate_lever.name = "GateLever"
	_gate_lever.configure("rudnik_gate_lever", "Gate Lever", "res://assets/art/engineeria/gate_lever.png", GATE_LEVER)
	_gate_lever.interaction_text = "Pull the gate lever"
	_gate_lever.service_requested.connect(_on_service_requested)
	actors_root.add_child(_gate_lever)

## The miners show once the cage has brought them up.
func _sync_story_people() -> void:
	_set_present("miner_0", _has_flag(TRIP_FLAG))
	_set_present("miner_1", _has_flag(TRIP_FLAG))
	_set_present("miner_2", _has_flag(RESCUED_FLAG))
	_set_present("miner_3", _has_flag(RESCUED_FLAG))

func _set_present(key: String, present: bool) -> void:
	var someone := story_person(key)
	if someone == null:
		return
	someone.visible = present
	if present and not someone.is_in_group("interactable"):
		someone.add_to_group("interactable")
	elif not present:
		someone.remove_from_group("interactable")

func _spawn_prowlers() -> void:
	if not prowlers().is_empty():
		return
	for index in PROWLER_CELLS.size():
		var cell: Vector2i = PROWLER_CELLS[index]
		var beast := Enemy.new()
		beast.configure("forest_beast", BEAST_TEXTURE, _nearby_open_position(Vector2(cell) * 16.0 + Vector2(8, 8)), "rudnik_prowler_%d" % index)
		beast.name = "Prowler_%d" % index
		actors_root.add_child(beast)
		_prowlers.append(beast)

func _on_service_requested(service_id: String, display_name: String) -> void:
	if service_id.begins_with(STORY_SERVICE_PREFIX):
		talk_to(service_id.trim_prefix(STORY_SERVICE_PREFIX))
		return
	match service_id:
		"rudnik_gate_bell": ring_gate_bell()
		"rudnik_gate_lever": pull_gate_lever()
		"rudnik_lift": use_lift()
		"rudnik_shed": search_shed()
		"rudnik_dispatch": _look_at_dispatch()
		"rudnik_ore_ship": _look_at_ore_ship()
		_: super._on_service_requested(service_id, display_name)

func _line(key: String, text: String) -> Dictionary:
	if key.is_empty():
		return {"speaker": "", "text": text}
	return {"speaker": String(STORY_PEOPLE[key]), "text": text, "focus": story_person(key)}

## Davor's line, or nothing when he is not here to say it.
func _davor_aside(text: String) -> Array:
	return [_davor_line(text)] if davor() != null else []

## The gatekeeper opens the wicket from inside and lets the player through.
func ring_gate_bell() -> void:
	if not _has_flag(DAVOR_FLAG):
		GameState.notify("Nobody answers the bell.")
		return
	if _has_flag(PORT_FLAG):
		_pass_gate(GATE_INSIDE, "The gatekeeper lets you in and bars the wicket behind you.")
		return
	_play([
		{"speaker": "", "text": "The bell clangs. A shutter opens in the wicket, and a face in an orange helmet looks you over."},
		_line("gatekeeper", "Davor! Out of the woods at last. And who's this, in a uniform nobody here wears?"),
		_davor_line("Off the ship that came down this morning. The only one who walked out of it. Open up, Mirko, before the sixlegs smell us."),
		_line("gatekeeper", "Come in quick, then. The wall's the only reason any of us are alive out here."),
		_line("gatekeeper", "Mind, nobody's in a mood for guests. The mine lift broke this morning with four of ours at the bottom. Zora's at the headframe."),
	], func() -> void:
		_set_flag(PORT_FLAG)
		_set_respawn_point()
		_pass_gate(GATE_INSIDE, "The wicket bangs shut behind you. Davor goes over the wall rather than wait for it."))

func pull_gate_lever() -> void:
	_pass_gate(GATE_OUTSIDE, "The wicket swings open long enough for you to slip out, then slams shut.")

## Moves the player to the other side of the wall. The wall is never opened, so
## nothing can follow them through except Davor, who jumps it.
func _pass_gate(destination: Vector2, notice: String) -> void:
	player.global_position = destination
	GameState.player_position = destination
	_davor_far_time = 0.0
	_refresh_location_title()
	GameState.notify(notice)
	GameState.military_changed.emit()

func talk_to(key: String) -> void:
	match key:
		"foreman": _talk_foreman()
		"captain": _talk_captain()
		"dispatcher":
			_play([
				_line("dispatcher", "Don't lean on the racks. Every lamp in there is a relay or a latch, and the whole hall is one machine."),
				_line("dispatcher", "It counts the ore, keeps the pad schedule and talks to the Cruisers when they pass overhead. No chips here, nor anywhere. Just blocks, and a lot of them."),
				_line("dispatcher", "On Iskra they have machines that fill a whole district. This one is small. It still took four years to build."),
			])
		"gatekeeper":
			_play([_line("gatekeeper", "Pull the lever by the wicket when you want out. Ring the bell to come back, and don't dawdle on the road.")])
		"resident_0":
			_play([_line("resident_0", "Beasts again on the south road last night. They sniff along the wall till dawn and never find a way in. Good wall.")])
		"resident_1":
			_play([_line("resident_1", "Ore ship every ten days, if the lift's working. When it isn't, nothing leaves. Not ore, not us.")])
		"miner_0", "miner_1", "miner_2", "miner_3":
			_play([_line(key, "Dark down there, with the cage stuck and the lamps going. Thank you. I'll buy you a drink when the ship's paid us.")])

func _talk_foreman() -> void:
	if _has_flag(RESCUED_FLAG):
		_play([_line("foreman", "All four up and breathing. Bruno's at the ship; he owes you as much as I do. Go and tell him I said so.")])
	elif _has_flag(WINCH_FLAG):
		_play([_line("foreman", "The winch is yours. Stay at it while the cage comes up, and if the brake slips, hold it.")])
	elif _has_flag(GEAR_FLAG):
		_play([_line("foreman", "That's the gear. Fit it to the winch at the headframe, and mind your fingers.")])
	elif _has_flag(LIFT_FLAG):
		_play([_line("foreman", "The spares are in the maintenance shed, west of the headframe. A drive gear, about the size of your head.")])
	else:
		_inspect_lift()

## The player looks at the broken winch and Zora tells them what happened.
func _inspect_lift() -> void:
	_play([
		{"speaker": "", "text": "The lift cage hangs off the headframe on its cable. The winch beside it is still, and teeth from its drive gear lie in the dust."},
		_line("foreman", "Drive gear stripped this morning, with the cage at the bottom and four of my miners in the lower gallery."),
		_line("foreman", "They're safe for now. The air's good. But the ladder shaft caved in years ago, so the cage is the only way up."),
		_line("foreman", "There's a spare gear in the maintenance shed. I can't leave the shaft, and my fitters are all below. Will you fetch it?"),
	] + _davor_aside("Go on. I'll stand at the shaft with Zora."), func() -> void:
		_set_flag(LIFT_FLAG))

func use_lift() -> void:
	if trip_running():
		if brake_slipping():
			_brake_left = -1.0
			GameState.notify("You throw your weight on the brake lever. The cable stops slipping, and the cage climbs on.")
			GameState.military_changed.emit()
		else:
			GameState.notify("The cage is on its way up. Stay by the winch.")
		return
	if _has_flag(RESCUED_FLAG):
		_play([{"speaker": "", "text": "The winch hums. The cage is back at the bottom, where the night shift will need it."}])
	elif _has_flag(WINCH_FLAG):
		start_trip()
	elif _has_flag(GEAR_FLAG):
		_repair_winch()
	elif _has_flag(LIFT_FLAG):
		GameState.notify("The winch won't turn without a new drive gear. The spares are in the maintenance shed.")
	else:
		_inspect_lift()

func _repair_winch() -> void:
	_play([
		{"speaker": "", "text": "You knock the broken gear off its shaft and drive the new one home. Zora sets the keys and checks the mesh by hand."},
		_line("foreman", "It'll hold. The brake's worn, though, so stay at the winch while the cage comes up. Two at a time; the cage won't take more."),
	], func() -> void:
		if _has_flag(WINCH_FLAG):
			return
		GameState.remove_item(GEAR_ITEM)
		_set_flag(WINCH_FLAG))

func search_shed() -> void:
	if not _has_flag(LIFT_FLAG):
		_play([{"speaker": "", "text": "Racks of spare parts, labelled in a careful hand. You don't know what you're looking for yet."}])
	elif _has_flag(GEAR_FLAG):
		_play([{"speaker": "", "text": "The rack where the spare drive gear hung is empty."}])
	else:
		_play([
			{"speaker": "", "text": "The spare drive gear hangs on a hook at the back, still greased and wrapped in sacking. It is heavier than it looks."},
		], func() -> void:
			if _has_flag(GEAR_FLAG):
				return
			if int(GameState.inventory.get(GEAR_ITEM, 0)) <= 0:
				GameState.add_item(GEAR_ITEM)
			GameState.notify("Took the Winch Gear.")
			_set_flag(GEAR_FLAG))

## The player starts the winch; the trip runs in _step_trip.
func start_trip() -> void:
	if trip_running() or not _has_flag(WINCH_FLAG) or _has_flag(RESCUED_FLAG):
		return
	_trip_time = 0.0
	_brake_left = -1.0
	GameState.notify("The winch takes the strain and the cable starts to wind. Stay by the winch.")
	GameState.military_changed.emit()

func _step_trip(delta: float) -> void:
	if not trip_running():
		return
	var lift := _lift_point()
	if lift.is_finite() and player.global_position.distance_to(lift) > WINCH_REACH:
		_trip_failed("You left the winch. The brake lets go and the cage runs back to the bottom.")
		return
	if _brake_left >= 0.0:
		_brake_left -= delta
		if _brake_left < 0.0:
			_trip_failed("The brake slips all the way. The cage runs back down to the bottom.")
		return
	var before := _trip_time
	_trip_time += delta
	if before < BRAKE_AT and _trip_time >= BRAKE_AT:
		_brake_left = BRAKE_SECONDS
		GameState.notify("The cable shrieks and starts to slip! Hold the brake at the winch!")
		GameState.military_changed.emit()
	elif _trip_time >= TRIP_SECONDS:
		_finish_trip()

## Runs the cage trip forward; used by the tests.
func advance_trip(seconds: float) -> void:
	var step := 0.25
	var left := seconds
	while left > 0.0 and trip_running():
		_step_trip(minf(step, left))
		left -= step

func _trip_failed(notice: String) -> void:
	_trip_time = -1.0
	_brake_left = -1.0
	GameState.notify(notice + " Start the winch again.")
	GameState.military_changed.emit()

func _finish_trip() -> void:
	_trip_time = -1.0
	_brake_left = -1.0
	if not _has_flag(TRIP_FLAG):
		_set_flag(TRIP_FLAG)
		_sync_story_people()
		_play([
			{"speaker": "", "text": "The cage clanks up into the light. Two miners stumble out, blinking, and Zora counts them twice."},
			_line("foreman", "Ante, Dora. Good. Send it down again; Josip and Nela are waiting."),
		])
		return
	if _has_flag(RESCUED_FLAG):
		return
	_set_flag(RESCUED_FLAG)
	_sync_story_people()
	GameState.add_gold(RESCUE_REWARD)
	_play([
		{"speaker": "", "text": "The second trip brings up the last two. The yard is suddenly full of people shouting and slapping backs."},
		_line("foreman", "All four. I don't know where you came from, but I'm glad of it."),
		_line("foreman", "Here, from the mine purse. %d gold. And go and see Bruno at the ore ship. He needs that lift as badly as we do." % RESCUE_REWARD),
	] + _davor_aside("Well done. That's our ride out, if Bruno is the man I remember."))

func _talk_captain() -> void:
	if _has_flag(PASSAGE_FLAG):
		_play([_line("captain", "Two seats, as promised. The holds are full. Come up the ramp when you're ready and we cast off.")])
	elif _has_flag(RESCUED_FLAG):
		_play([
			_line("captain", "So you're the one who got the cage running. Without that lift, my holds stay empty and nobody here gets paid."),
			_davor_line("We need to get off this rock, Bruno. Towards Iskra, as far as you're going."),
			_line("captain", "I go as far as Skoljka, a planet on. The sea city buys our ore for its pumps. It's not Iskra, but it's closer than here, and ships go from Skoljka to Iskra."),
			_line("captain", "Two seats, then, for you and the old man. Free. The holds will be full by the time you've said your goodbyes. Come aboard when you're ready."),
		], func() -> void:
			if _has_flag(PASSAGE_FLAG):
				return
			_set_flag(PASSAGE_FLAG)
			GameState.record_event("rudnik_passage_earned")
			GameState.notify("Captain Bruno will take you and Davor on the next ore run."))
	else:
		_play([
			_line("captain", "No passengers. Not that it matters: with the lift broken, there's no ore, and with no ore, this ship sits on the pad."),
			_line("captain", "Get those miners up and talk to me then."),
		])

func _look_at_ore_ship() -> void:
	if _has_flag(PASSAGE_FLAG):
		_play([
			{"speaker": "", "text": "The ore ship sits low on the pad with full holds. The hatch is open, and Captain Bruno's crew are stowing the last of the lines."},
		] + _davor_aside("Nothing more to keep us here. Say the word."), Callable(), [
			{"label": "Sail on the ore ship", "action": sail_to_skoljka},
			{"label": "Not yet", "action": Callable()},
		])
	else:
		_play([{"speaker": "", "text": "A squat grey ore ship with orange pods along its belly. The hatch is sealed, and the loaders stand idle beside the rails."}])

## The player and Davor board the ore ship and sail for Skoljka.
func sail_to_skoljka() -> bool:
	if not _has_flag(PASSAGE_FLAG) or trip_running():
		return false
	_play([
		{"speaker": "", "text": "The hatch closes behind you. The ore ship shudders off the pad, and Rudnik's forest drops away under the ports."},
		{"speaker": "", "text": "Three days in a passenger cabin the size of a cupboard. Davor sleeps most of it, or pretends to."},
		_line("captain", "There she is. Skoljka. Most of it's under the water; what you see is only the dock."),
		{"speaker": "", "text": "Below, a grey sea runs in long storm swells. On it sits a ring of orange cranes and a single landing pad, and under them a city you cannot see."},
	], func() -> void:
		_set_flag(SAILED_FLAG)
		GameState.record_event("rudnik_sailed")
		story_travel_requested.emit("skoljka"))
	return true

func _look_at_dispatch() -> void:
	_play([
		{"speaker": "", "text": "The dispatch engine fills its hall: rack after rack of blue lamps, each one a relay, clicking in long waves as the machine thinks."},
	] + _davor_aside("They've doubled the carry racks since... since these were new, I mean. Come on."))

## The position at the lift's winch, where the player stands to run it.
func _lift_point() -> Vector2:
	var map_objects := tiled_loader.get_node_or_null("MapObjects")
	if map_objects != null:
		for node in map_objects.get_children():
			if node is WorldService and node.service_id == "rudnik_lift":
				return node.get_interaction_position()
	return Vector2.INF

## Davor jumps walls to follow, but when he is far from the player and not
## jumping for a while, as when the straight line crosses a building, he is
## put beside them.
func _step_davor_catch_up(delta: float) -> void:
	var someone := davor()
	if someone == null or someone.down or someone.leaping() or someone.order != "follow":
		_davor_far_time = 0.0
		return
	if someone.global_position.distance_to(player.global_position) < CATCH_UP_DISTANCE:
		_davor_far_time = 0.0
		return
	_davor_far_time += delta
	if _davor_far_time >= CATCH_UP_SECONDS:
		_davor_far_time = 0.0
		someone.global_position = _nearby_open_position(player.global_position + Vector2(-18, 16))
