class_name EngineeriaWorld
extends GameWorld

## The forest in Engineeria where the diplomatic ship came down.
##
## The player wakes by the wreck beside the three dead envoys and takes Iva
## Most's letters. Forest beasts come out of the trees behind them, and the
## only way out is to run for the chimney smoke in the northeast. Entering the
## clearing round the house brings Davor out to kill the beasts; he then joins
## the player for the road to Iskra.
##
## The chase is never saved halfway. Being downed, or loading a save made
## during it, puts the player back by the wreck and starts it again. Once the
## player has reached the clearing, being downed wakes them at Davor's door with
## the beasts dead.

const ENGINEERIA_MAP := "res://maps/engineeria.tmj"
## Set when the player has taken the letters from the wreck.
const LETTERS_FLAG := "engineeria_letters_taken"
## Set when Davor joins the player.
const DAVOR_FLAG := "davor_met"
const LETTERS_ITEM := "embassy_letters"
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
	if _has_flag(DAVOR_FLAG):
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
	return "ENGINEERIA" if _has_flag(DAVOR_FLAG) else "UNKNOWN FOREST"

## Objective text for the HUD panel in the top right.
func story_status_text() -> String:
	if _has_flag(DAVOR_FLAG):
		return "ENGINEERIA\nTravel to Iskra with Davor"
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
	if _has_flag(DAVOR_FLAG):
		_spawn_davor(_nearby_open_position(player.global_position + Vector2(-18, 16)))
		_davor_follows()
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
	for beast in _beasts:
		if is_instance_valid(beast):
			beast.queue_free()
	_beasts.clear()
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
		_davor_line("You're in Engineeria, if nobody told you. The far side of it from anywhere that matters. Iskra is a long road from here."),
		{"speaker": "", "text": "His eyes go to the sealed letters in your hand and stay there for a moment. He doesn't ask about them."},
		_davor_line("Whatever you carry was going to Iskra, I expect. Nobody flies a white ship out here to look at the trees."),
		_davor_line("The forest roads are no place to walk alone, with those things about and whoever knocked your ship out of the sky. I'll take you to Iskra myself."),
		_davor_line("Don't thank me. I've sat in that house long enough. Let me bank the fire and fetch my pack."),
	], davor_joins)

## Davor joins the player for the road to Iskra.
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
	GameState.notify("Davor joins you. He will walk with you to Iskra.")

func _davor_follows() -> void:
	var someone := davor()
	if someone != null:
		someone.set_order("follow")
		someone.task_label = "walk with you"

# ---- being downed, saving and loading ----

func _on_player_respawned() -> void:
	super._on_player_respawned()
	if _has_flag(DAVOR_FLAG):
		var someone := davor()
		if someone != null and not someone.down:
			someone.global_position = _nearby_open_position(HOUSE_FRONT + Vector2(-18, 16))
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
