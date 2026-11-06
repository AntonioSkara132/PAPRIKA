class_name SpaceRockWorld
extends GameWorld

## R-7: a grey rock off the old survey lanes where Davor asks the Lasta to stop
## on the way to Breece. Built by tools/build_space_rock_world.py.
##
## The chapter has three stages, kept in story flags:
## 1. Landed: Veki stays with the Lasta, Davor walks with the player to the
##    cave. Near the cave mouth Martin's ship lands, Veki flies off, and
##    Martin's soldiers attack in waves. When the player is worn down, or most
##    of the soldiers are beaten, Martin steps in, strikes the player down and
##    takes Davor (GameState.DAVOR_TAKEN_FLAG). His men shut the player in
##    the cave behind a heap of rocks.
## 2. Alone: the player wakes hurt in the dark cave. The rocks are too heavy
##    to move. At the grave the Voice in the Dark offers to merge, and the
##    player becomes a Brine (GameState.BRINE_FLAG).
## 3. Rescued: the cave is lit for the player now and a Brine can push the
##    rocks out. Outside, Veki lands the Lasta with two hackers aboard: they
##    caught him, and he bought his way back by promising them treasure in
##    the cave. The player and Veki fight them off. Boarding the Lasta sets
##    course for the Republic planet where Martin took Davor; that flight is
##    the next chapter and not in the game yet, so the player stays on R-7.
##
## A fight in progress is not saved; after a load the raid starts again from
## the landing, and the hackers come again when the player is outside.

const ROCK_MAP := "res://maps/space_rock.tmj"
const ART := "res://assets/art/rock/"
const FLAG_PREFIX := "rock_"
## The surface and the cave in map pixels (tools/build_space_rock_world.py).
const SURFACE_RECT := Rect2(0, 0, 960, 600)
const CAVE_RECT := Rect2(192, 792, 576, 352)
## Ships, top left in map pixels and the ground they block while landed.
const LASTA_AT := Vector2(80, 332)
const LASTA_BASE := Rect2(100, 412, 180, 32)
const MARTIN_SHIP_AT := Vector2(540, 256)
const MARTIN_SHIP_BASE := Rect2(556, 316, 240, 32)
## Martin's soldiers come in waves; the next wave lands when one is left.
const WAVES := [
	["republic_swordsman", "republic_spearman", "republic_archer", "republic_swordsman"],
	["republic_guardsman", "republic_spearman", "republic_archer", "republic_swordsman", "republic_spearman"],
	["republic_guardsman", "republic_guardsman", "republic_archer", "republic_archer", "republic_swordsman", "republic_spearman"],
]
## Martin steps in after this many soldiers are down, or when the player's
## health falls to MARTIN_HEALTH_SHARE of the maximum.
const MARTIN_AFTER_KILLS := 12
const MARTIN_HEALTH_SHARE := 0.3
const RAID_TRIGGER_DISTANCE := 96.0
## The rocks sealing the cave mouth from inside, and the ground they block.
const SEALED_ROCKS_AT := Vector2(192, 1080)
const SEALED_ROCKS_BASE := Rect2(192, 1084, 96, 60)

var markers: Dictionary = {}
var davor: RaidSoldier
var veki: StationStaff
var lasta_sprite: Sprite2D
var martin_ship_sprite: Sprite2D
var cave_light: Sprite2D
var voice_sprite: Sprite2D
var sealed_rocks: Sprite2D
var _sealed_rocks_body: StaticBody2D
var raid_active := false
var raid_kills := 0
var raid_wave := 0
var martin_coming := false
var _raiders: Array = []
var _lasta_body: StaticBody2D
var _martin_ship_body: StaticBody2D
var _staged: Array[Node2D] = []
var _spots: Dictionary = {}
var hacker_fight_active := false
var veki_fighter: RaidSoldier
var _hackers: Array = []
const HACKERS := [
	["void_hacker", "hacker.png", Vector2(-40, 28)],
	["hacker_trooper", "hacker_trooper.png", Vector2(16, 36)],
]

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	add_child(tiled_loader)
	if not tiled_loader.load_map(ROCK_MAP):
		push_error("R-7 map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROCK_MAP))
	for layer: Dictionary in data["layers"]:
		if layer["name"] == "Markers":
			for point: Dictionary in layer["objects"]:
				markers[point["name"]] = Vector2(point["x"], point["y"])
	_spawn_player(GameState.ROCK_ARRIVAL, "res://art/concepts/source/player.png")
	player.respawn_position = marker("respawn")
	player.respawn_location_name = "R-7"
	_spawn_ships()
	_spawn_cave_art()
	_spawn_spots()
	GameState.health_changed.connect(_on_health_changed)
	apply_loaded_state()
	call_deferred("_arrival_scene")

func marker(id: String) -> Vector2:
	return Vector2(markers.get(id, GameState.ROCK_ARRIVAL))

func has_flag(id: String) -> bool:
	return GameState.defeated_persistent_enemies.has(FLAG_PREFIX + id)

func set_flag(id: String) -> void:
	if not has_flag(id):
		GameState.defeated_persistent_enemies.append(FLAG_PREFIX + id)
		GameState.military_changed.emit()

## "landed" before Martin's raid, "alone" until the merge, then "rescued".
func stage() -> String:
	if GameState.is_brine():
		return "rescued"
	if GameState.davor_taken():
		return "alone"
	return "landed"

func in_cave(at: Vector2 = Vector2.INF) -> bool:
	var spot := player.global_position if at == Vector2.INF and player != null else at
	return spot.y >= CAVE_RECT.position.y - 96.0

func refresh_camera() -> void:
	if _camera == null:
		return
	var rect := CAVE_RECT if in_cave() else SURFACE_RECT
	var view := get_viewport_rect().size / _camera.zoom
	var grow := Vector2(maxf(0.0, view.x - rect.size.x), maxf(0.0, view.y - rect.size.y)) / 2.0
	_camera.limit_left = int(rect.position.x - grow.x)
	_camera.limit_right = int(rect.end.x + grow.x)
	_camera.limit_top = int(rect.position.y - grow.y)
	_camera.limit_bottom = int(rect.end.y + grow.y)
	_camera.reset_smoothing()

func location_title() -> String:
	return "R-7 · THE CAVE" if in_cave() else "R-7 · SURFACE"

func story_status_text() -> String:
	match stage():
		"landed":
			if raid_active:
				return "Martin's soldiers are attacking. Fight beside Davor (%d down)." % raid_kills
			return "Follow Davor to the cave under the old scaffolding. Veki waits with the Lasta."
		"alone":
			return "Martin took Davor and his men shut you in the cave. Find a way out."
	if not rocks_pushed():
		return "Push the rocks out of the cave mouth."
	if not has_flag("hackers_beaten"):
		return "Two hackers came down the Lasta's ramp after Veki. Fight them off (%d left)." % _hackers.size() if hacker_fight_active else "Go out to the Lasta."
	return "Veki is back with the Lasta. Board her and go after Davor."

## True once a Brine has pushed the sealing rocks out of the cave mouth.
func rocks_pushed() -> bool:
	return has_flag("rocks_pushed")

func cave_sealed() -> bool:
	return GameState.davor_taken() and not rocks_pushed()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if stage() == "landed":
		return marker("arrival")
	if saved.is_finite() and tiled_loader.is_walkable_position(saved) and (in_cave(saved) or not cave_sealed()) and not SEALED_ROCKS_BASE.grow(8.0).has_point(saved):
		return saved
	return marker("cave_wake") if cave_sealed() else marker("wake")

func capture_player_position() -> void:
	GameState.remember_player_position(player.global_position)

func apply_loaded_state() -> void:
	_end_raid()
	_end_hacker_fight()
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	_sync_stage()
	refresh_camera()
	if hackers_due() and not in_cave():
		call_deferred("start_hacker_fight")

## The hackers come once the rocks are pushed out, until they are beaten.
func hackers_due() -> bool:
	return GameState.is_brine() and rocks_pushed() and not has_flag("hackers_beaten")

## Who and what is on the rock for the current stage.
func _sync_stage() -> void:
	var current := stage()
	var lasta_here := current == "landed" or (current == "rescued" and rocks_pushed())
	var veki_here := current == "landed" or has_flag("hackers_beaten")
	_set_ship(lasta_sprite, _lasta_body, lasta_here)
	_set_ship(martin_ship_sprite, _martin_ship_body, false)
	if current == "landed":
		if davor == null:
			_spawn_davor()
		davor.global_position = tiled_loader.nearest_walkable_position(player.global_position + Vector2(-24, 16))
		davor.set_order("follow")
	elif davor != null:
		davor.queue_free()
		davor = null
	if veki_here and veki == null:
		veki = StationStaff.new()
		veki.name = "Veki"
		veki.configure("rock:veki", "Veki", "res://assets/art/iskra/npcs/veki.png", marker("veki_post"))
		actors_root.add_child(veki)
		veki.service_requested.connect(func(_id: String, _title: String) -> void: _talk_to_veki())
	elif not veki_here and veki != null:
		veki.queue_free()
		veki = null
	if cave_light != null:
		cave_light.visible = GameState.is_brine()
	if sealed_rocks != null:
		sealed_rocks.visible = cave_sealed()
		(_sealed_rocks_body.get_child(0) as CollisionShape2D).set_deferred("disabled", not cave_sealed())

func _on_player_respawned() -> void:
	super._on_player_respawned()
	refresh_camera()

# ---------- art ----------

func _sprite_at(texture: String, top_left: Vector2, scale_by: float, bottom_y: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + texture) as Texture2D if not texture.begins_with("res://") else load(texture) as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_by, scale_by)
	sprite.position = top_left
	sprite.z_index = 100 + int(bottom_y)
	add_child(sprite)
	return sprite

func _blocker(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
	return body

func _spawn_ships() -> void:
	lasta_sprite = _sprite_at("res://assets/art/otpornik/lasta.png", LASTA_AT, 1.0, LASTA_BASE.end.y)
	lasta_sprite.name = "Lasta"
	_lasta_body = _blocker(LASTA_BASE)
	martin_ship_sprite = _sprite_at("martin_ship.png", MARTIN_SHIP_AT, 2.0, MARTIN_SHIP_BASE.end.y)
	martin_ship_sprite.name = "MartinShip"
	_martin_ship_body = _blocker(MARTIN_SHIP_BASE)

func _set_ship(sprite: Sprite2D, body: StaticBody2D, landed: bool) -> void:
	sprite.visible = landed
	sprite.modulate.a = 1.0
	for child in body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not landed)

## The lit cave, shown once the player sees in the dark as a Brine, and the Voice.
func _spawn_cave_art() -> void:
	cave_light = _sprite_at("cave_lit.png", CAVE_RECT.position, 2.0, 0.0)
	cave_light.name = "CaveLit"
	cave_light.z_index = -9
	voice_sprite = _sprite_at("voice.png", marker("voice") + Vector2(-45, -146), 1.5, marker("voice").y + 4.0)
	voice_sprite.name = "Voice"
	voice_sprite.visible = false
	sealed_rocks = _sprite_at("sealed_rocks.png", SEALED_ROCKS_AT, 2.0, SEALED_ROCKS_BASE.end.y)
	sealed_rocks.name = "SealedRocks"
	_sealed_rocks_body = _blocker(SEALED_ROCKS_BASE)

func _spawn_davor() -> void:
	davor = RaidSoldier.new()
	davor.name = "Davor"
	davor.configure("davor", "Davor", "res://assets/art/engineeria/davor.png", player.global_position, "sword", 0, self)
	davor.max_health = 260
	davor.health = 260
	davor.speed = 100.0
	davor.strike_damage = 30
	davor.strike_cooldown = 0.6
	davor.follow_sight = 140.0
	davor.can_leap = true
	davor.get_up_seconds = 4.0
	actors_root.add_child(davor)
	GameState.apply_davor_health(davor)
	if davor.down:
		davor.get_up()

# ---------- places ----------

## Invisible places to interact with on the rock and in the cave.
class RockSpot extends Node2D:
	signal used(id: String)
	var spot_id := ""
	var text_for := Callable()

	func _ready() -> void:
		add_to_group("interactable")

	func get_interaction_text() -> String:
		return String(text_for.call()) if text_for.is_valid() else ""

	func interact(_actor: Node) -> void:
		if not get_interaction_text().is_empty():
			used.emit(spot_id)

func _spawn_spots() -> void:
	var texts := {
		"lasta": func() -> String: return "Board the Lasta" if stage() == "rescued" else ("Look at the Lasta" if stage() == "landed" else ""),
		"cave_mouth": func() -> String: return "" if stage() == "landed" else "Go into the cave",
		"cave_entry": func() -> String: return "Push the rocks" if cave_sealed() else "Go out to the surface",
		"camp": func() -> String: return "Look at Davor's old camp",
		"triangle": func() -> String: return "Look at the mark on the wall",
		"grave": func() -> String: return "Look at the cairn",
	}
	for id: String in texts:
		var spot := RockSpot.new()
		spot.name = "Spot_" + id
		spot.spot_id = id
		spot.text_for = texts[id]
		spot.global_position = marker(id)
		if id == "cave_entry":
			# Above the rocks, where the player can stand while they block the way.
			spot.global_position.y = SEALED_ROCKS_BASE.position.y - 12.0
		actors_root.add_child(spot)
		spot.used.connect(_on_spot)
		_spots[id] = spot

func move_player(to: Vector2) -> void:
	player.global_position = to
	player.velocity = Vector2.ZERO
	GameState.remember_player_position(to)
	refresh_camera()
	var ui := _ui()
	if ui != null:
		ui.refresh_location()

func _on_spot(id: String) -> void:
	match id:
		"lasta":
			if stage() == "rescued":
				_talk_to_veki()
			else:
				_tell("", "The Lasta stands on her legs with the drive ticking over. Veki is at the ramp, watching the sky.")
		"cave_mouth": move_player(marker("cave_entry"))
		"cave_entry": _cave_exit()
		"camp": _scene([
			_line("", "A bedroll, a cold ring of stones and a crate with an empty lamp in it. Two pages are nailed to the rock."),
			_line("", "The first, in Davor's hand: \"I buried him here, where the Republic will not look. The mask stays with him.\""),
			_line("", "The second: \"If I do not come back, whoever reads this should go to the end of the tunnel and talk to him. He listens.\""),
		])
		"triangle": _tell("", "A gold Republic triangle painted on the wall, half scraped off. Someone tried to take the Republic out of this place.")
		"grave":
			if GameState.is_brine():
				_tell("", "The cairn is only stones and a cracked mask now. The light that lived here is with you.")
			else:
				_voice_scene()

# ---------- scenes ----------

func _ui() -> GameUI:
	return get_tree().get_first_node_in_group("game_ui") as GameUI

func _line(speaker: String, text: String) -> Dictionary:
	var focus: Node2D = davor if speaker == "Davor" else veki if speaker == "Veki" else null
	return {"speaker": speaker, "text": text, "focus": focus}

func _scene(lines: Array, finished: Callable = Callable(), choices: Array = []) -> void:
	var ui := _ui()
	if ui != null:
		ui.play_scene(lines, finished, choices)
	else:
		for line: Dictionary in lines:
			GameState.notify(String(line["text"]))
		if finished.is_valid():
			finished.call()

func _tell(speaker: String, text: String, choices: Array = []) -> void:
	_scene([_line(speaker, text)], Callable(), choices)

func _choice(label: String, action: Callable) -> Dictionary:
	return {"label": label, "action": action}

func _arrival_scene() -> void:
	if has_flag("arrival") or stage() != "landed":
		return
	set_flag("arrival")
	_scene([
		_line("", "The Lasta sets down on a grey rock far off the survey lanes. Old Republic scaffolding stands over a hole in the ridge."),
		_line("Davor", "R-7. It has not changed. Nobody comes here, and that is why I chose it."),
		_line("Veki", "I stay with the Lasta and keep the drive warm. This rock has no beacon. If anything comes, I want to see it first."),
		_line("Davor", "The cave is under the scaffolding. Come with me, kid."),
	], func() -> void: GameState.notify("Follow Davor to the cave under the scaffolding."))

func _talk_to_veki() -> void:
	match stage():
		"landed":
			_tell("Veki", "I keep the drive warm. Go with Davor. Whatever he left here, he wants you to see it.")
		"rescued":
			_scene([_line("Veki", "The drive is warm. Say the word and we go after Davor.")], Callable(), [
				_choice("Board the Lasta and go after Davor", leave_rock),
				_choice("Stay on R-7", Callable()),
			])

## The flight to the Republic planet is the next chapter. Until it exists the
## Lasta stays on R-7 and this only says so.
func leave_rock() -> void:
	_scene([
		_line("Veki", "A navy ship with a gold stripe flies for the Republic. Martin will take Davor to one of their cities."),
		_line("Veki", "We set course for the Republic."),
	], func() -> void: GameState.notify("The flight to the Republic is the next chapter. It is not in the game yet."))

# ---------- the raid ----------

func _process(_delta: float) -> void:
	if player == null:
		return
	if stage() == "landed" and not raid_active and not martin_coming and has_flag("arrival"):
		var ui := _ui()
		if player.global_position.distance_to(marker("cave_mouth")) <= RAID_TRIGGER_DISTANCE and (ui == null or not ui.scene_playing()):
			start_raid()
	if raid_active and not martin_coming:
		_raiders = _raiders.filter(func(enemy) -> bool: return is_instance_valid(enemy) and (enemy as Enemy).health > 0)
		if raid_kills >= MARTIN_AFTER_KILLS or (davor != null and davor.down):
			martin_steps_in()
		elif _raiders.size() <= 1 and raid_wave < WAVES.size():
			_spawn_wave()
	if hacker_fight_active:
		_hackers = _hackers.filter(func(enemy) -> bool: return is_instance_valid(enemy) and (enemy as Enemy).health > 0)
		if _hackers.is_empty():
			_hackers_beaten()

func start_raid() -> bool:
	if raid_active or stage() != "landed":
		return false
	raid_active = true
	raid_kills = 0
	raid_wave = 0
	_set_ship(martin_ship_sprite, _martin_ship_body, true)
	martin_ship_sprite.position = MARTIN_SHIP_AT + Vector2(0, -420)
	create_tween().tween_property(martin_ship_sprite, "position", MARTIN_SHIP_AT, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_scene([
		_line("Davor", "The door slab is where I left it. Good. Inside there is someone you should meet."),
		_line("", "A roar comes over the ridge. A navy ship with a gold stripe drops out of the dark and lands on the far side of the rock."),
		_line("Veki", "(on the radio) That is a Republic ship, and its guns are on the Lasta! I cannot hold her here. I am lifting off. I will come back for you, I swear it!"),
		_line("Davor", "Martin's ship. He followed us. Stay close to me and keep your back to the ridge."),
	], _veki_flies_off)
	return true

func _veki_flies_off() -> void:
	if veki != null:
		veki.queue_free()
		veki = null
	_lasta_body.get_child(0).set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(lasta_sprite, "position", LASTA_AT + Vector2(-60, -480), 1.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(lasta_sprite, "modulate:a", 0.0, 1.8)
	tween.tween_callback(func() -> void:
		lasta_sprite.visible = false
		lasta_sprite.position = LASTA_AT)
	if raid_active and raid_wave == 0:
		_spawn_wave()
	GameState.notify("Martin's soldiers are coming. Fight beside Davor.")

func _spawn_wave() -> void:
	var kinds: Array = WAVES[raid_wave]
	for i in kinds.size():
		var enemy := Enemy.new()
		var stable_id := "story_rock_raider_%d_%d" % [raid_wave, i]
		enemy.name = stable_id
		var spot := marker("raider_%d" % ((i + raid_wave * 3) % 8))
		enemy.configure(String(kinds[i]), "res://assets/art/artichoke/objects/republic_soldier%s.png" % ("" if i % 7 == 0 else "_%d" % (i % 7 + 1)), spot, stable_id)
		enemy.relentless = true
		actors_root.add_child(enemy)
		enemy.defeated.connect(func(_id: String) -> void: raid_kills += 1)
		_raiders.append(enemy)
	raid_wave += 1

## Keeps the player standing during the raid: a hit that would knock them out,
## or one that leaves them worn down, brings Martin in instead.
func _on_health_changed(health: int, max_health: int) -> void:
	if not raid_active or martin_coming:
		return
	if health <= 0:
		GameState.health = 1
		GameState.health_changed.emit.call_deferred(1, max_health)
	if GameState.health <= maxi(4, int(max_health * MARTIN_HEALTH_SHARE)):
		martin_steps_in()

func martin_steps_in() -> void:
	if martin_coming or not raid_active:
		return
	martin_coming = true
	call_deferred("_martin_scene")

func _martin_scene() -> void:
	for enemy in _raiders:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_raiders.clear()
	if davor != null:
		if davor.down:
			davor.get_up()
		davor.global_position = marker("davor_taken")
		davor.velocity = Vector2.ZERO
		davor.hold_at(marker("davor_taken"), "hold")
	player.global_position = marker("wake")
	player.velocity = Vector2.ZERO
	refresh_camera()
	var martin := _sprite_at("martin.png", marker("martin_ramp") - Vector2(9, 24), 1.0, marker("martin_ramp").y)
	martin.name = "Martin"
	_staged.append(martin)
	var stop := marker("martin") - Vector2(9, 24)
	var walk := create_tween()
	walk.tween_property(martin, "position", stop, 1.8)
	walk.tween_callback(func() -> void: martin.z_index = 100 + int(marker("martin").y))
	for i in 4:
		var at: Vector2 = marker("martin") + Vector2(-60 + i * 40, 40 + (i % 2) * 16)
		var soldier := _sprite_at("res://assets/art/artichoke/objects/republic_soldier_%d.png" % (i + 2), at - Vector2(8, 24), 1.0, at.y)
		_staged.append(soldier)
	_scene([
		_line("", "A man in a long navy coat comes down the ramp. His soldiers step back to let him through."),
		_line("Martin", "Davor. The best of the Admins, hiding on a rock nobody remembers."),
		_line("Davor", "Martin. You followed us from Otpornik."),
		_line("Martin", "You bought a ship with Council gold. Brokers keep books, and the Republic reads them."),
		_line("Martin", "Whatever you buried here stays buried. You are coming home with me."),
		_line("Davor", "Leave the kid out of it. He has nothing to do with this."),
		_line("Martin", "Then he dies with nothing. Put him in that cave and close it. No ship, no help, no air worth breathing. The rock will finish him for me."),
		_line("", "Davor draws his sword. Martin's rod flashes, and the ground comes up hard."),
	], _davor_taken)

func _davor_taken() -> void:
	screen_flash(Color(1, 1, 1), 0.4)
	screen_flash(Color(0, 0, 0), 1.2, 1.4)
	for node in _staged:
		if is_instance_valid(node):
			node.queue_free()
	_staged.clear()
	raid_active = false
	martin_coming = false
	GameState.defeated_persistent_enemies.append(GameState.DAVOR_TAKEN_FLAG)
	GameState.davor_health = -1
	GameState.health = maxi(1, int(GameState.max_health * 0.25))
	GameState.health_changed.emit(GameState.health, GameState.max_health)
	GameState.military_changed.emit()
	_sync_stage()
	move_player(marker("cave_wake"))
	_scene([
		_line("", "You wake in the dark, with stone under your cheek and the taste of blood in your mouth."),
		_line("", "Martin's men dragged you into the cave and rolled rocks across the mouth. The only light is from the moss in the cracks."),
		_line("", "Your ribs burn with every breath. Davor is gone, and nobody knows you are here."),
	], func() -> void: GameState.notify("You are shut in the cave Davor came for. Look around."))

## A raid in progress is not saved, and a load starts it again.
func _end_raid() -> void:
	for enemy in _raiders:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_raiders.clear()
	for node in _staged:
		if is_instance_valid(node):
			node.queue_free()
	_staged.clear()
	raid_active = false
	martin_coming = false
	if lasta_sprite != null:
		lasta_sprite.position = LASTA_AT

func _cave_exit() -> void:
	if not cave_sealed():
		move_player(marker("wake"))
		if hackers_due() and not hacker_fight_active:
			start_hacker_fight()
		return
	if not GameState.is_brine():
		_tell("You", "These rocks are too heavy.")
		return
	set_flag("rocks_pushed")
	_sync_stage()
	_scene([
		_line("", "You set your shoulder against the rocks. They are as heavy as before, but you are not."),
		_line("", "The heap grinds, tips and rolls out of the cave mouth. Grey light falls into the tunnel."),
	], _cave_exit)

# ---------- the hackers ----------

## Veki lands the Lasta with the two hackers who caught him. He promised them
## treasure in the cave so they would let him come back; they follow him down
## the ramp, and he fights beside the player.
func start_hacker_fight() -> bool:
	if hacker_fight_active or not hackers_due():
		return false
	hacker_fight_active = true
	_sync_stage()
	lasta_sprite.position = LASTA_AT + Vector2(-60, -480)
	lasta_sprite.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(lasta_sprite, "position", LASTA_AT, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var ramp := marker("lasta")
	veki_fighter = RaidSoldier.new()
	veki_fighter.name = "VekiFighter"
	veki_fighter.configure("veki", "Veki", "res://assets/art/iskra/npcs/veki.png", ramp, "sword", 1, self)
	veki_fighter.max_health = 140
	veki_fighter.health = 140
	veki_fighter.speed = 100.0
	veki_fighter.get_up_seconds = 5.0
	actors_root.add_child(veki_fighter)
	veki_fighter.set_order("attack")
	for i in HACKERS.size():
		var data: Array = HACKERS[i]
		var enemy := Enemy.new()
		var stable_id := "story_rock_hacker_%d" % i
		enemy.name = stable_id
		enemy.configure(String(data[0]), ART + String(data[1]), tiled_loader.nearest_walkable_position(ramp + data[2]), stable_id)
		enemy.relentless = true
		actors_root.add_child(enemy)
		_hackers.append(enemy)
	var veki_line := func(text: String) -> Dictionary: return {"speaker": "Veki", "text": text, "focus": veki_fighter}
	_scene([
		_line("", "The Lasta comes down over the ridge and settles on her legs. The ramp opens, and Veki walks down first with his hands up."),
		_line("", "Two figures follow him: one in dotted pyjamas and a nightcap, one in a dotted jumpsuit. Neither wears Republic colours."),
		veki_line.call("You are alive! Listen. These two caught me behind the rock. I told them there was treasure hidden in this cave. It was the only way they would let me come back for you."),
		_line("Pyjama Hacker", "So the pilot was not lying about the cave. Out of the way, boy. Whatever is buried in there is ours."),
		_line("You", "The only thing in that cave was meant for me."),
		veki_line.call("Hackers fight like nothing you have seen. Be careful!"),
	], func() -> void: GameState.notify("Fight off the hackers with Veki."))
	return true

func _hackers_beaten() -> void:
	hacker_fight_active = false
	set_flag("hackers_beaten")
	var at := veki_fighter.global_position if veki_fighter != null else marker("veki_post")
	_end_hacker_fight()
	_sync_stage()
	if veki != null:
		veki.global_position = tiled_loader.nearest_walkable_position(at)
	_scene([
		_line("Veki", "Was that you? You threw him across the rock like a sack of beans."),
		_line("Veki", "So there was treasure in that cave after all. What happened to your eyes? And where is Davor?"),
		_line("You", "Martin took Davor. And in the cave, someone helped me."),
		_line("Veki", "Tell me on the way. Where there are two hackers, there are more, so we should not stay here."),
	], func() -> void: GameState.notify("Talk to Veki to board the Lasta."))

func _end_hacker_fight() -> void:
	for enemy in _hackers:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_hackers.clear()
	hacker_fight_active = false
	if veki_fighter != null:
		veki_fighter.queue_free()
		veki_fighter = null

# ---------- the Voice ----------

func _voice_scene() -> void:
	var lines := [
		_line("", "At the end of the tunnel, stones are piled into a cairn. A cracked iron mask is set in it. Its Admin badge has been scratched off."),
		_line("", "You sit down against the stones. Your hands are shaking."),
		_line("You", "Davor is gone. Martin will kill him, and I just lay there in the dust."),
		_line("You", "Everyone at home... I said I would protect them. I could not even protect one old man."),
		_line("You", "Veki is not coming back. Nobody comes to R-7. I am going to die in this hole."),
		_line("", "The dark answers."),
		_line("Voice in the Dark", "Not yet, you are not."),
		_line("", "Pale light gathers over the cairn: the outline of a tall soldier, with lines running across its chest like circuits."),
		_line("Voice in the Dark", "Davor did not bring you to this rock to look at a grave. He brought you to me. There is a reason for that."),
		_line("You", "Who are you?"),
		_line("Voice in the Dark", "Someone Davor buried. Someone the Republic made, and then wanted back. Leave it at that for now."),
		_line("Voice in the Dark", "I can help you. I have unfinished business with the Republic myself, and I cannot walk out of this cave alone."),
		_line("Voice in the Dark", "But there is a price. You would give up a part of yourself, and I would lose a part of me as well. Neither of us gets it back."),
		_line("Voice in the Dark", "Are you willing?"),
	]
	if has_flag("voice_met"):
		lines = [
			_line("", "The light still waits over the cairn."),
			_line("Voice in the Dark", "Are you willing?"),
		]
	set_flag("voice_met")
	voice_sprite.visible = true
	voice_sprite.modulate.a = 0.0
	create_tween().tween_property(voice_sprite, "modulate:a", 1.0, 1.5)
	_scene(lines, Callable(), [
		_choice("\"I would do anything.\"", merge_with_voice),
		_choice("\"Not yet.\"", Callable()),
	])

func merge_with_voice() -> bool:
	if not GameState.become_brine():
		return false
	screen_flash(Color(0.78, 0.92, 1.0), 2.0, 0.6)
	var fade := create_tween()
	fade.tween_property(voice_sprite, "modulate:a", 0.0, 2.0)
	fade.tween_callback(func() -> void: voice_sprite.visible = false)
	_sync_stage()
	_scene([
		_line("", "The light pours off the cairn and into you. It is cold, then it burns, then it is quiet."),
		_line("", "When it is over, you can see the cave as clearly as by day. Your wounds have closed."),
		_line("Voice in the Dark", "There. Each of us is a little less than we were, and together a good deal more."),
		_line("Voice in the Dark", "You are a Brine now. Go and find Davor. I am with you."),
		_line("", "Outside, something hums: an old drive, coming down."),
	], func() -> void: GameState.notify("You are a Brine: +%d max health and stronger attacks. Push the rocks out of the cave mouth." % GameState.BRINE_MAX_HEALTH_BONUS))
	return true
