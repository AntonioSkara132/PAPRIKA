class_name BavarinWorld
extends GameWorld

## Bavarin, the desert planet with Martin's base, reached from Smokva after the
## battle with the Purple Parrots (SmokvaWorld._talk_to_veki).
##
## The map (maps/bavarin.tmj, built by tools/build_bavarin_world.py) has the
## canyon where the Lasta hides in the south-west, the oasis village in the
## south, the dunes in the south-east and the walled base in the north and east.
##
## The story here:
## 1. Veki gives the player two bombs he made ("bombs_given"). Each goes on the
##    hull of one of the two warships on the landing pads, so that they cannot
##    follow the Lasta once Davor is free. Nobody knows yet where Davor is held.
## 2. In the village the off-duty soldier talks only over a drink
##    ("soldier_thirsty"). The villager who likes dates sells date wine
##    ("wine_bought"). Asked about Martin first and the prisoner after, the drunk
##    soldier tells where Davor is ("davor_located"); asked about the prisoner
##    straight away, he turns nasty and the bottle is gone.
## 3. The player sneaks over the dunes and climbs the wall where it has crumbled
##    ("wall_climbed"); Donat will not climb before they know where Davor is.
##    Searchlights sweep the sand and the pads, and sentries walk set routes with
##    a view cone each. Every SANDSTORM_CALM seconds a gust blows in and the cones
##    and lights shrink. Seen for SPOT_SECONDS, the player is sent back to the
##    last checkpoint: the edge of the dunes, or inside the wall once it has been
##    climbed. Bombs already planted stay planted.
## 4. Inside, the MC and Donat split up and each carries one bomb ("mc_planted",
##    "donat_planted"). The ally-control keys switch between the player's body (1)
##    and Donat's (2). The body the player leaves stands where it is, and the
##    guards can see it too. With both bombs on the hulls ("bomb_flagship",
##    "bomb_escort") the two are together again.
## 5. At Davor, chained to a post in front of the prison block, Martin comes out
##    with his men, and the player and Donat fight them. 1 and 2 switch bodies
##    again; whoever the player is not in fights on their own. A knock-out starts
##    the fight again. Martin's Banishing Sword and Arrows do not banish the MC,
##    who is a Brine; the first time one hits, the fight stops for a scene
##    ("brine_shrugged"). A Banishing hit knocks Donat out for
##    BANISHED_DOWN_SECONDS.
## 6. When Martin is down to MARTIN_BEATEN_SHARE of his health, Veki sets off the
##    bombs, Martin's men drag him away alive ("martin_beaten"), the player frees
##    Davor ("davor_freed") and Veki lands the Lasta inside the base.
##
## The story steps are flags in GameState.defeated_persistent_enemies with
## FLAG_PREFIX, so saves need nothing new.

const BAVARIN_MAP := "res://maps/bavarin.tmj"
const ART := "res://assets/art/bavarin/"
const OBJ := "res://assets/art/artichoke/objects/"
const FLAG_PREFIX := "bavarin_"
const MAP_RECT := Rect2(0, 0, 1280, 896)

## The base inside its walls, from the concept (tools/create_bavarin_desert_concept.py BASE).
const BASE_OUTLINE := [Vector2(560, 30), Vector2(760, 18), Vector2(980, 22), Vector2(1270, 16), Vector2(1280, 16), Vector2(1280, 560), Vector2(1272, 560), Vector2(1150, 574), Vector2(980, 560), Vector2(840, 572), Vector2(700, 548), Vector2(590, 470), Vector2(540, 300), Vector2(530, 140)]
## Outside the walls, only ground east of this is watched (the dunes).
const WATCHED_FROM_X := 830.0

## How long the player can stay in sight before the alarm.
const SPOT_SECONDS := 0.5
## How fast being seen wears off once out of sight, per second.
const SUSPICION_DECAY := 0.8
## After being sent back, nobody can see the player for this long.
const RESTART_GRACE := 1.5

const CONE_LENGTH := 90.0
const CONE_HALF_ANGLE := 0.5
const CONE_RAYS := 12
const SENTRY_SPEED := 28.0
const SENTRY_PAUSE := 2.4
const SENTRY_TEXTURES := ["republic_soldier_2.png", "republic_soldier_3.png", "republic_soldier.png", "republic_soldier_4.png", "republic_soldier_2.png", "republic_soldier_3.png"]

## The searchlights: the tower each shines from, the two ends of its sweep and
## the seconds for one sweep there and back.
const SEARCHLIGHTS := [
	{"from": Vector2(1012, 500), "a": Vector2(880, 660), "b": Vector2(1120, 690), "period": 8.0},
	{"from": Vector2(1258, 510), "a": Vector2(1260, 650), "b": Vector2(1100, 820), "period": 9.5},
	{"from": Vector2(1130, 40), "a": Vector2(1000, 196), "b": Vector2(1240, 204), "period": 7.0},
]
const LIGHT_RADII := Vector2(36, 20)

## The sandstorm: calm, then a warning, then a gust that shrinks the sentries'
## cones and the searchlights' spots.
const SANDSTORM_CALM := 14.0
const SANDSTORM_WARN := 1.5
const SANDSTORM_GUST := 6.0
const GUST_CONE := 0.5
const GUST_LIGHT := 0.55

## Martin's men: four come out of the prison block with him, and four more from
## the parade ground once only GUARDS_LEFT_FOR_SECOND_WAVE of the first are standing.
const MEN_KINDS := ["republic_tvrdium_guard", "republic_swordsman", "republic_tvrdium_guard", "republic_archer",
	"republic_spearman", "republic_tvrdium_guard", "republic_guardsman", "republic_archer"]
const GUARDS_LEFT_FOR_SECOND_WAVE := 2
const SECOND_WAVE_SECONDS := 30.0
const MARTIN_BEATEN_SHARE := 0.25
## How long a Banishing hit keeps Donat down.
const BANISHED_DOWN_SECONDS := 12.0
const WINE_PRICE := 10
## The villager who likes dates sells the date wine.
const WINE_SELLER := 3
const BODY_REPATH_SECONDS := 0.4

const LASTA_TEXTURE := "res://assets/art/otpornik/lasta.png"
const LASTA_SCALE := 0.75
const CANYON_LASTA_AT := Vector2(40, 718)
const SHIPS := {
	"bomb_flagship": {"texture": "republic_warship_flagship.png", "at": Vector2(980, 78), "light": Vector2(1048, 138), "name": "Martin's ship"},
	"bomb_escort": {"texture": "republic_warship_escort.png", "at": Vector2(1142, 108), "light": Vector2(1192, 152), "name": "the escort"},
}

const VILLAGERS := [
	{"title": "Villager", "art": "res://assets/art/iskra/npcs/market_keeper.png", "line": "In the Sea of Propuh, hackers are everywhere, but I feel safer with the Admin being here."},
	{"title": "Villager", "art": "res://assets/art/iskra/npcs/canal_worker.png", "line": "I hear soldiers can get nasty when they're drunk."},
	{"title": "Villager", "art": "res://assets/art/iskra/npcs/greenhouse_worker.png", "line": "It's always hot in here."},
	{"title": "Villager", "art": "res://assets/art/iskra/npcs/board_officer.png", "line": "I like the dates we have here."},
	{"title": "Villager", "art": "res://assets/art/iskra/npcs/dock_mechanic.png", "line": "I came here because the land was cheap. The Republic is trying to fill this place up, but everyone in the Republic is afraid of the Sea of Propuh. Not many natives here."},
]
const OFF_DUTY_LINES := [
	"Off duty. If the sergeant asks, you never saw me out here.",
	"They doubled the watch since the Admin came back with his prisoner. Searchlights all night. Sand in everything.",
	"The wind's the only thing nobody can order about. When it blows, the lads on the dunes can't see their own boots.",
]
const GATE_LINES := [
	"The base is closed. Turn round.",
	"No visitors. Admin's orders.",
]

const SPOTS := {
	"lasta_spot": "Look at the Lasta",
	"well": "Drink from the well",
	"wreck": "Look at the wreck",
	"arch": "Look at the rock arch",
	"breach_out": "Climb the broken wall",
	"breach_in": "Climb back out over the wall",
	"bomb_flagship": "Plant a bomb on Martin's ship",
	"bomb_escort": "Plant a bomb on the escort",
	"davor": "Go to Davor",
	"lasta_door": "Board the Lasta",
}

var markers: Dictionary = {}
var veki: StationStaff
var donat: StationStaff
var davor: StationStaff
var donat_fighter: DonatFighter
var martin: MartinBoss
var men: Array = []
var _second_wave_left: Array = []
var _second_wave_time := 0.0
var fight_active := false
## "men" while Martin's men are up, then "duel" against Martin alone.
var fight_stage := ""
var _fight_ending := false
var _fight_held := false
var bodies_switched := false
var _body_path := PackedVector2Array()
var _body_path_index := 0
var _body_repath := 0.0

var sentries: Array = []
var searchlights: Array = []
## Seconds the player has been in sight, up to SPOT_SECONDS.
var suspicion := 0.0
var times_caught := 0
var _grace := 0.0
var _alarm_label: Label
## Seconds into the sandstorm's cycle of calm, warning and gust.
var storm_time := 0.0
var _storm_cover: ColorRect
var _storm_label: Label

var _spots: Dictionary = {}
var _talks: Dictionary = {}
var _canyon_lasta: Sprite2D
var _landed_lasta: Sprite2D
var _landed_lasta_body: StaticBody2D
var _ships: Dictionary = {}
var _bomb_lights: Dictionary = {}
var _ship_fires: Array = []
var _chained_davor: Sprite2D
var _chain: Line2D
var _drill: Array = []
var _shown_title := ""

func _ready() -> void:
	add_to_group("game_world")
	actors_root = Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	tiled_loader = TiledLoader.new()
	tiled_loader.name = "TiledWorld"
	add_child(tiled_loader)
	if not tiled_loader.load_map(BAVARIN_MAP):
		push_error("Bavarin map could not be loaded.")
		return
	move_child(tiled_loader, 0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAVARIN_MAP))
	for layer: Dictionary in data["layers"]:
		if layer["name"] == "Markers":
			for point: Dictionary in layer["objects"]:
				markers[point["name"]] = Vector2(point["x"], point["y"])
	_spawn_player(GameState.BAVARIN_ARRIVAL, "res://art/concepts/source/player.png")
	player.respawn_position = marker("respawn")
	player.respawn_location_name = "the canyon"
	var dusk := CanvasModulate.new()
	dusk.name = "Dusk"
	dusk.color = Color(0.94, 0.82, 0.74)
	add_child(dusk)
	_spawn_scenery()
	_spawn_people()
	_spawn_spots()
	_spawn_watch()
	_spawn_storm()
	GameState.health_changed.connect(_on_health_changed)
	apply_loaded_state()

func marker(id: String) -> Vector2:
	return Vector2(markers.get(id, GameState.BAVARIN_ARRIVAL))

func refresh_camera() -> void:
	if _camera == null:
		return
	_camera.limit_left = int(MAP_RECT.position.x)
	_camera.limit_top = int(MAP_RECT.position.y)
	_camera.limit_right = int(MAP_RECT.end.x)
	_camera.limit_bottom = int(MAP_RECT.end.y)
	_camera.reset_smoothing()

func in_base(at: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(at, PackedVector2Array(BASE_OUTLINE))

## True where the sentries and searchlights can raise the alarm: the dunes east
## of the village and everything inside the walls.
func watched(at: Vector2) -> bool:
	return in_base(at) or at.x >= WATCHED_FROM_X

func location_title() -> String:
	var at := player.global_position if player != null else GameState.BAVARIN_ARRIVAL
	if in_base(at):
		return "BAVARIN · THE BASE"
	if at.x < 330.0:
		return "BAVARIN · THE CANYON"
	if at.x < WATCHED_FROM_X:
		return "BAVARIN · THE OASIS"
	return "BAVARIN · THE DUNES"

func bombs_planted() -> int:
	return int(has_flag("bomb_flagship")) + int(has_flag("bomb_escort"))

func story_status_text() -> String:
	if fight_active:
		if fight_stage == "duel":
			return "The duel with Martin. Donat is down. Purple on the ground is his Banishing Sword or Arrow; red is where he lands from a jump."
		return "Fight Martin's men (%d standing). Press 1 for your body, 2 for Donat's. You are in %s." % [men.size() + _second_wave_left.size(), "Donat's body" if bodies_switched else "your own body"]
	if has_flag("martin_beaten"):
		return "Davor is free and Martin's ships are burning. Veki has landed the Lasta in the base."
	if bombs_planted() == 2:
		return "Both bombs are planted. Get to Davor, chained in front of the prison block."
	if has_flag("wall_climbed"):
		return "Split up: you and Donat each plant one bomb on a warship (%d/2). Press 1 for your body, 2 for Donat's; the one you leave stands still and can be seen. You are in %s." % [bombs_planted(), "Donat's body" if bodies_switched else "your own body"]
	if has_flag("davor_located"):
		return "Davor is in the cells, chained to the post in front of them at dusk. Sneak over the dunes to the crumbled wall in the south-east corner of the base. Move when the sandstorm blows."
	if has_flag("wine_bought"):
		return "Take the date wine to the off-duty soldier in the village. Ask carefully."
	if has_flag("soldier_thirsty"):
		return "The off-duty soldier wants a drink before he talks. The villager who likes dates sells date wine."
	if has_flag("bombs_given"):
		return "Find out where Davor is held. Someone in the village may know."
	return "The Lasta is hidden in the canyon. Talk to Veki."

func has_flag(id: String) -> bool:
	return GameState.defeated_persistent_enemies.has(FLAG_PREFIX + id)

func set_flag(id: String) -> void:
	if not has_flag(id):
		GameState.defeated_persistent_enemies.append(FLAG_PREFIX + id)
		GameState.military_changed.emit()

func _clear_flag(id: String) -> void:
	if has_flag(id):
		GameState.defeated_persistent_enemies.erase(FLAG_PREFIX + id)
		GameState.military_changed.emit()

func _safe_loaded_position(saved: Vector2) -> Vector2:
	if saved.is_finite() and tiled_loader.is_walkable_position(saved):
		return saved
	return marker("arrival")

func capture_player_position() -> void:
	GameState.remember_player_position(player.global_position)

func apply_loaded_state() -> void:
	close_ship_battle()
	_end_fight()
	player.global_position = _safe_loaded_position(GameState.player_position)
	GameState.player_position = player.global_position
	_sync_story()
	refresh_camera()

func _on_player_respawned() -> void:
	super._on_player_respawned()
	refresh_camera()

func _sprite_at(texture: String, top_left: Vector2, scale_by: float, bottom_y: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture) as Texture2D
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

func _walkable(at: Vector2) -> Vector2:
	var spot := tiled_loader.nearest_walkable_position(at)
	return spot if spot.is_finite() else at

# ---------- scenery the story changes ----------

func _spawn_scenery() -> void:
	var lasta_size := Vector2(220, 112) * LASTA_SCALE
	_canyon_lasta = _sprite_at(LASTA_TEXTURE, CANYON_LASTA_AT, LASTA_SCALE, CANYON_LASTA_AT.y + lasta_size.y)
	_canyon_lasta.name = "LastaCanyon"
	var landing := marker("lasta_landing")
	_landed_lasta = _sprite_at(LASTA_TEXTURE, landing, LASTA_SCALE, landing.y + lasta_size.y)
	_landed_lasta.name = "LastaLanded"
	_landed_lasta_body = _blocker(Rect2(landing.x + 18, landing.y + lasta_size.y - 14, 130, 14))
	for id: String in SHIPS:
		var ship: Dictionary = SHIPS[id]
		var texture := load(OBJ + String(ship["texture"])) as Texture2D
		var sprite := _sprite_at(OBJ + String(ship["texture"]), ship["at"], 1.0, Vector2(ship["at"]).y + texture.get_height())
		sprite.name = "Warship_" + id
		_ships[id] = sprite
	# Davor, chained to the post in front of the prison block.
	_chained_davor = _sprite_at("res://assets/art/engineeria/davor.png", marker("davor") - Vector2(9, 24), 1.0, marker("davor").y)
	_chained_davor.name = "ChainedDavor"
	_chained_davor.modulate = Color(0.86, 0.84, 0.9)
	_chain = Line2D.new()
	_chain.name = "Chain"
	_chain.width = 1.0
	_chain.default_color = Color("8d939e")
	_chain.points = PackedVector2Array([marker("post") + Vector2(0, -12), marker("davor") + Vector2(5, -10)])
	_chain.z_index = 100 + int(marker("davor").y) + 1
	add_child(_chain)
	# Soldiers drilling on the parade ground; they leave once Martin is beaten.
	var textures := ["republic_soldier.png", "republic_soldier_2.png", "republic_soldier_3.png"]
	for row in 2:
		for column in 4:
			var at := Vector2(770 + column * 34, 290 + row * 40)
			var soldier := _sprite_at(OBJ + String(textures[(row + column) % 3]), at - Vector2(8, 24), 1.0, at.y)
			soldier.name = "Drill_%d_%d" % [row, column]
			var tween := soldier.create_tween().set_loops()
			tween.tween_interval(0.4 + 0.1 * column)
			tween.tween_property(soldier, "position:y", at.y - 26.0, 0.18)
			tween.tween_property(soldier, "position:y", at.y - 24.0, 0.18)
			tween.tween_interval(0.6)
			_drill.append(soldier)

## Puts the Lasta, the ships, Davor and the people where the finished story steps leave them.
func _sync_story() -> void:
	var beaten := has_flag("martin_beaten")
	_canyon_lasta.visible = not beaten
	_landed_lasta.visible = beaten
	for child in _landed_lasta_body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not beaten)
	for id: String in SHIPS:
		_set_bomb_light(id, has_flag(id) and not beaten)
	if beaten and _ship_fires.is_empty():
		_burn_ships()
	_chained_davor.visible = not has_flag("davor_freed")
	_chain.visible = _chained_davor.visible
	for soldier: Sprite2D in _drill:
		soldier.visible = not beaten
	if is_instance_valid(veki):
		veki.global_position = marker("lasta_veki") if beaten else marker("veki_post")
		veki.z_index = 100 + int(veki.global_position.y)
	_show_staff(davor, has_flag("davor_freed"))
	davor.global_position = _walkable(marker("lasta_veki") + Vector2(32, 6))
	davor.z_index = 100 + int(davor.global_position.y)
	_show_staff(donat, beaten)
	donat.global_position = _walkable(marker("lasta_veki") + Vector2(-26, 12))
	donat.z_index = 100 + int(donat.global_position.y)
	if beaten:
		if is_instance_valid(donat_fighter):
			_set_switched(false)
			donat_fighter.queue_free()
			donat_fighter = null
	elif not fight_active:
		_spawn_follower()
	for sentry: BavarinSentry in sentries:
		sentry.visible = not beaten
		sentry.cone.visible = not beaten
	for light: BavarinSearchlight in searchlights:
		light.visible = not beaten
	_refresh_spots()
	_refresh_status()

## Shows or hides someone to talk to; a hidden one cannot be talked to either.
func _show_staff(staff: StationStaff, on: bool) -> void:
	staff.visible = on
	if on and not staff.is_in_group("interactable"):
		staff.add_to_group("interactable")
	elif not on and staff.is_in_group("interactable"):
		staff.remove_from_group("interactable")

func _set_bomb_light(id: String, on: bool) -> void:
	if on and not _bomb_lights.has(id):
		var light := Polygon2D.new()
		light.name = "BombLight_" + id
		light.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		light.color = Color(1.0, 0.2, 0.15)
		light.position = SHIPS[id]["light"]
		light.z_index = 1500
		add_child(light)
		var tween := light.create_tween().set_loops()
		tween.tween_property(light, "modulate:a", 0.15, 0.4)
		tween.tween_property(light, "modulate:a", 1.0, 0.4)
		_bomb_lights[id] = light
	elif not on and _bomb_lights.has(id):
		_bomb_lights[id].queue_free()
		_bomb_lights.erase(id)

## The two warships after the bombs: blackened hulls with fire on them.
func _burn_ships() -> void:
	for id: String in SHIPS:
		var ship: Sprite2D = _ships[id]
		ship.modulate = Color(0.42, 0.36, 0.34)
		var size := ship.texture.get_size()
		for i in 4:
			var flame := Polygon2D.new()
			flame.name = "Fire"
			flame.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -12), Vector2(5, 0)])
			flame.color = Color(1.0, 0.55 + 0.1 * (i % 2), 0.15)
			flame.position = ship.position + Vector2(size.x * (0.2 + 0.2 * i), size.y * (0.45 + 0.1 * (i % 2)))
			flame.z_index = ship.z_index + 1
			add_child(flame)
			var tween := flame.create_tween().set_loops()
			tween.tween_property(flame, "scale", Vector2(1.2, 1.5), 0.2 + 0.05 * i)
			tween.tween_property(flame, "scale", Vector2(0.9, 0.8), 0.2 + 0.05 * i)
			_ship_fires.append(flame)

# ---------- people ----------

func _spawn_people() -> void:
	veki = StationStaff.new()
	veki.name = "Veki"
	veki.configure("bavarin:veki", "Veki", "res://assets/art/iskra/npcs/veki.png", marker("veki_post"))
	actors_root.add_child(veki)
	veki.service_requested.connect(func(_id: String, _title: String) -> void: talk_to_veki())
	donat = StationStaff.new()
	donat.name = "Donat"
	donat.configure("bavarin:donat", "Donat", "res://assets/art/smokva/donat.png", marker("lasta_veki"))
	actors_root.add_child(donat)
	donat.service_requested.connect(func(_id: String, _title: String) -> void: talk_to_donat())
	davor = StationStaff.new()
	davor.name = "Davor"
	davor.configure("bavarin:davor", "Davor", "res://assets/art/engineeria/davor.png", marker("lasta_veki"))
	actors_root.add_child(davor)
	davor.service_requested.connect(func(_id: String, _title: String) -> void: talk_to_davor())
	for i in VILLAGERS.size():
		var person := StationStaff.new()
		person.name = "Villager_%d" % i
		person.configure("bavarin:villager_%d" % i, String(VILLAGERS[i]["title"]), String(VILLAGERS[i]["art"]), marker("villager_%d" % i))
		actors_root.add_child(person)
		var line := String(VILLAGERS[i]["line"])
		if i == WINE_SELLER:
			person.service_requested.connect(func(_id: String, _title: String) -> void: talk_to_wine_seller())
		else:
			person.service_requested.connect(func(_id: String, _title: String) -> void: _tell("Villager", line))
	var off_duty := StationStaff.new()
	off_duty.name = "OffDutySoldier"
	off_duty.configure("bavarin:off_duty", "Off-duty soldier", OBJ + "republic_soldier_4.png", marker("off_duty"))
	actors_root.add_child(off_duty)
	off_duty.service_requested.connect(func(_id: String, _title: String) -> void: talk_to_off_duty())
	for i in 2:
		var guard := StationStaff.new()
		guard.name = "GateGuard_%d" % i
		guard.configure("bavarin:gate_guard_%d" % i, "Gate guard", OBJ + "republic_guardsman.png", marker("gate_guard_%d" % i))
		actors_root.add_child(guard)
		guard.service_requested.connect(func(_id: String, _title: String) -> void: _tell("Gate guard", next_line("gate", GATE_LINES)))

## Donat walks with the player while they sneak in.
func _spawn_follower() -> void:
	if is_instance_valid(donat_fighter):
		return
	donat_fighter = DonatFighter.new()
	donat_fighter.name = "DonatFighter"
	donat_fighter.configure("donat", "Donat", "res://assets/art/smokva/donat.png", _walkable(player.global_position + Vector2(-18, 16)), "sword", 0, self)
	donat_fighter.max_health = 320
	donat_fighter.health = 320
	donat_fighter.armor = 3
	donat_fighter.speed = 92.0
	donat_fighter.strike_damage = int(GameData.enemy("donat_duel").get("damage", 28))
	donat_fighter.strike_cooldown = 1.1
	donat_fighter.get_up_seconds = 5.0
	actors_root.add_child(donat_fighter)
	donat_fighter._refresh_health_bar()
	donat_fighter.set_order("follow")

## Brings Donat to the player when he has fallen behind or the player climbed the wall.
func _bring_donat() -> void:
	if is_instance_valid(donat_fighter) and not fight_active:
		donat_fighter.global_position = _walkable(player.global_position + Vector2(-18, 16))
		donat_fighter.velocity = Vector2.ZERO
		donat_fighter._path_goal = Vector2.INF

func _ui() -> GameUI:
	return get_tree().get_first_node_in_group("game_ui") as GameUI

func _line(speaker: String, text: String) -> Dictionary:
	var focus: Node2D = null
	match speaker:
		"Veki":
			focus = veki
		"Donat":
			if bodies_switched:
				focus = player
			elif is_instance_valid(donat_fighter):
				focus = donat_fighter
			else:
				focus = donat
		"Davor":
			focus = davor if davor.visible else null
		"Martin":
			focus = martin if is_instance_valid(martin) else null
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

## The next line in turn for `who`, counting talks since the world loaded.
func next_line(who: String, lines: Array) -> String:
	var count: int = _talks.get(who, 0)
	_talks[who] = count + 1
	return String(lines[count % lines.size()])

func talk_to_veki() -> void:
	if has_flag("martin_beaten"):
		_tell("Veki", "Everyone aboard who's coming aboard? Good. I'm still plotting where we go from here.")
		GameState.notify("The rest of the Sea of Propuh is not in the game yet.")
	elif has_flag("bombs_given") and not has_flag("davor_located"):
		_tell("Veki", "Ask around the village. Soldiers come down for water and dates; somebody's heard something.")
	elif has_flag("bombs_given"):
		var left := 2 - bombs_planted()
		if left == 0:
			_tell("Veki", "Both bombs are on. I'll set them off when you've got Davor. Go!")
		else:
			_tell("Veki", "%s to go. One on each hull. Keep out of the lights, and move when the sand blows." % ("One more" if left == 1 else "Two bombs"))
	else:
		give_bombs()

func give_bombs() -> void:
	_scene([
		_line("Veki", "We're down. Nobody looks into this canyon, as long as nobody flies over it."),
		_line("Veki", "Martin's base is north-east of the village. Walls, towers, searchlights. And two warships on the landing pads."),
		_line("Veki", "If we grab Davor and run, those ships are on our tail before we clear the dunes. So I made these."),
		_line("", "Veki hands you two lumps of grey putty wrapped in wire, each with a little red light."),
		_line("Veki", "Bombs. Stick one on the hull of each ship. They go off when I send the signal, and the ships stay on the ground."),
		_line("Donat", "You made bombs. In that ship. While I was sleeping in it."),
		_line("Veki", "They're stable. Mostly. Go over the dunes on the east side; there's a crumbled bit of wall in the south-east corner."),
		_line("Veki", "The sandstorm comes in gusts. When it blows, the guards can barely see their own feet. Move then."),
		_line("Donat", "And where in that fortress is the old man? We can't just open doors until one has him behind it."),
		_line("Veki", "No idea. The village sells the base its water and its dates. Somebody down there knows."),
		_line("Veki", "Find out where he is. Then bombs, then Davor. When it's done, I'll come and get you."),
	], func() -> void:
		set_flag("bombs_given")
		_refresh_spots()
		_refresh_status()
		GameState.notify("Veki gave you two bombs. First find out where Davor is held: try the village."))

## The off-duty soldier talks only over a drink, and only if asked the right way.
func talk_to_off_duty() -> void:
	if not has_flag("bombs_given") or has_flag("davor_located"):
		_tell("Off-duty soldier", next_line("off_duty", OFF_DUTY_LINES))
		return
	if not has_flag("wine_bought"):
		if has_flag("soldier_thirsty"):
			_tell("Off-duty soldier", "Still no bottle? Then still no talking.")
			return
		_scene([
			_line("Off-duty soldier", "Who are you two? You're not from the village."),
			_line("Donat", "Traders. We trade in minding our own business."),
			_line("Off-duty soldier", "Hah. Well, I'm off duty, and off duty I don't talk to strangers with a dry throat."),
			_line("Off-duty soldier", "There's date wine in the village. Bring me a bottle and maybe I remember how to be friendly."),
		], func() -> void:
			set_flag("soldier_thirsty")
			_refresh_spots()
			_refresh_status())
		return
	_scene([
		_line("", "The soldier pulls the cork with his teeth and drinks half the bottle at once."),
		_line("Off-duty soldier", "Ahh. That's the stuff. Sweet as the dates and twice as strong. Go on, then. What do you want?"),
	], Callable(), [
		_choice("Ask about the prisoner", _ask_prisoner_first),
		_choice("Ask about Martin", _ask_about_martin),
	])

func _ask_prisoner_first() -> void:
	_scene([
		_line("Off-duty soldier", "The prisoner? ...Why'd you want to know about the prisoner?"),
		_line("Off-duty soldier", "(He stands up too fast and the stool falls over.) You're spies. Hacker spies! I'll break your... your..."),
		_line("", "He swings at Donat, misses by an arm's length and sits down in the sand. Then he finishes the bottle."),
		_line("Donat", "The villager did say they get nasty when they're drunk."),
		_line("Off-duty soldier", "Get lost. Come back with another bottle and maybe I forget you asked."),
	], func() -> void:
		_clear_flag("wine_bought")
		_refresh_spots()
		_refresh_status()
		GameState.notify("The bottle is gone. Buy another and ask about something else first."))

func _ask_about_martin() -> void:
	_scene([
		_line("Off-duty soldier", "The Admin? Don't get me started. Came back three weeks ago in a mood, doubled the watch, searchlights all night."),
		_line("Off-duty soldier", "He walks about with that purple sword of his. A Banishing Sword, the sergeant says. From the old days. One cut and you're gone, armor or no armor."),
		_line("Off-duty soldier", "And his Tvrdium boys get the good food. The rest of us get dates. Dates for breakfast, dates for dinner."),
	], Callable(), [
		_choice("Ask about the prisoner now", _ask_prisoner_after),
		_choice("Leave him to his bottle", func() -> void:
			_tell("Off-duty soldier", "Suit yourselves. More for me.")),
	])

func _ask_prisoner_after() -> void:
	_scene([
		_line("Off-duty soldier", "The old man with the beard? The one he brought back? Poor sod."),
		_line("Off-duty soldier", "They keep him in the cells, the block in the middle of the base. And every evening the Admin has him chained to the post out front, so the whole base sees what happens to people who cross him."),
		_line("Off-duty soldier", "Every evening. Like now. ...Why am I telling you this? Whatever. It's good wine."),
		_line("Donat", "In front of the cells, chained up, at dusk. Then we go now."),
	], func() -> void:
		set_flag("davor_located")
		_clear_flag("wine_bought")
		_refresh_spots()
		_refresh_status()
		GameState.notify("Davor is chained in front of the prison block in the middle of the base. Sneak in over the dunes."))

## The villager who likes dates, who sells date wine once the soldier has asked for it.
func talk_to_wine_seller() -> void:
	var line := String(VILLAGERS[WINE_SELLER]["line"])
	if not has_flag("soldier_thirsty") or has_flag("davor_located") or has_flag("wine_bought"):
		_tell("Villager", line)
		return
	_tell("Villager", line + " We make wine from them too. %d gold a bottle." % WINE_PRICE, [
		_choice("Buy a bottle of date wine (%d gold)" % WINE_PRICE, buy_wine),
		_choice("Not now", func() -> void: pass),
	])

func buy_wine() -> bool:
	if has_flag("wine_bought") or has_flag("davor_located"):
		return false
	if GameState.spend_gold(WINE_PRICE):
		_tell("Villager", "There you are. Don't drink it all at once.")
	else:
		_tell("Villager", "You haven't got %d gold? ...Take it. You look like you need it more than me." % WINE_PRICE)
	set_flag("wine_bought")
	_refresh_status()
	return true

func talk_to_donat() -> void:
	_tell("Donat", "Your friend talks a lot for someone who's been in chains for weeks. Is he always like this?")

func talk_to_davor() -> void:
	_tell("Davor", "Martin will come back for me. He always comes back. Next time we'll be ready for him.")

# ---------- places ----------

## Invisible places to interact with.
class BavarinSpot extends Node2D:
	signal used(id: String, actor: Node)
	var spot_id := ""
	var text := ""

	func get_interaction_text() -> String:
		return text

	func interact(actor: Node) -> void:
		used.emit(spot_id, actor)

func _spawn_spots() -> void:
	for id: String in SPOTS:
		var spot := BavarinSpot.new()
		spot.name = "Spot_" + id
		spot.spot_id = id
		spot.text = SPOTS[id]
		spot.global_position = marker(id)
		actors_root.add_child(spot)
		spot.used.connect(_on_spot)
		_spots[id] = spot

## Only the places that mean something at this point of the story can be used.
func _refresh_spots() -> void:
	var beaten := has_flag("martin_beaten")
	var open := {
		"lasta_spot": not beaten,
		"well": true,
		"wreck": true,
		"arch": true,
		"breach_out": not beaten,
		"breach_in": not beaten,
		"bomb_flagship": not beaten and has_flag("bombs_given") and not has_flag("bomb_flagship"),
		"bomb_escort": not beaten and has_flag("bombs_given") and not has_flag("bomb_escort"),
		"davor": not has_flag("davor_freed"),
		"lasta_door": beaten,
	}
	for id: String in _spots:
		var spot: BavarinSpot = _spots[id]
		if open.get(id, true):
			if not spot.is_in_group("interactable"):
				spot.add_to_group("interactable")
		elif spot.is_in_group("interactable"):
			spot.remove_from_group("interactable")
	_spots["davor"].text = "Free Davor" if beaten else "Go to Davor"

func move_player(to: Vector2) -> void:
	player.global_position = to
	player.velocity = Vector2.ZERO
	GameState.remember_player_position(to)
	refresh_camera()
	var ui := _ui()
	if ui != null:
		ui.refresh_location()

func _on_spot(id: String, actor: Node = null) -> void:
	if actor != null and actor == donat_fighter and id not in ["bomb_flagship", "bomb_escort"]:
		_bark(donat_fighter, "Do that one yourself. In your own body.")
		return
	match id:
		"lasta_spot":
			_tell("", "The Lasta sits in the shade of the canyon wall, her ramp down and a tarp over her nose. From above she must look like one more rock.")
		"well":
			GameState.restore_health()
			_tell("", "You pull up a bucket from the well. The water is cold and tastes of stone. You feel rested.")
		"wreck":
			_tell("", "The ribs of an old ship stick out of the sand, older than the Republic's base. Nobody has bothered to take it apart.")
		"arch":
			_tell("", "A rock arch the wind has carved. The sand hisses through it.")
		"breach_out":
			climb_wall(true)
		"breach_in":
			climb_wall(false)
		"bomb_flagship", "bomb_escort":
			plant_bomb(id, donat_fighter if actor != null and actor == donat_fighter else player)
		"davor":
			if has_flag("martin_beaten"):
				free_davor()
			else:
				reach_davor()
		"lasta_door":
			_tell("Veki", "Not yet. I'm still working out where we go from here.")
			GameState.notify("The rest of the Sea of Propuh is not in the game yet.")

## Climbs over the crumbled wall: in when `inward`, back out otherwise.
func climb_wall(inward: bool) -> bool:
	if fight_active:
		return false
	if inward and not has_flag("davor_located"):
		_tell("Donat", "Climb into a fortress and then what? Knock on doors? Find out where they keep him first.")
		return false
	if bodies_switched:
		_set_switched(false)
	move_player(marker("breach_in") if inward else marker("breach_out"))
	_bring_donat()
	if inward and not has_flag("wall_climbed"):
		set_flag("wall_climbed")
		_scene([
			_line("", "You find footholds in the crumbled stone and drop down on the other side. Donat lands next to you, grumbling about his knees."),
			_line("Donat", "Two ships, two bombs, two of us. Give me one. You take one ship, I take the other."),
			_line("Donat", "And use that trick of yours. Look through my eyes, walk my legs. I'll stand still and try not to sneeze."),
		], func() -> void:
			GameState.notify("Split up. Press 2 to take over Donat and 1 to go back to your own body. Each of you plants one bomb. If either is seen, you both start again here."))
	_refresh_status()
	return true

## True while the MC and Donat are split up inside the wall, each with a bomb.
func splitting() -> bool:
	return sneaking() and has_flag("wall_climbed") and bombs_planted() < 2

## Plants a bomb on warship `id`. `actor` is the body pressing E: the MC and
## Donat each carry one bomb.
func plant_bomb(id: String, actor: Node2D = null) -> bool:
	if has_flag(id) or not has_flag("bombs_given") or fight_active:
		return false
	var by_donat := actor != null and actor == donat_fighter
	var carried := "donat_planted" if by_donat else "mc_planted"
	if has_flag(carried):
		_bark(actor if actor != null else player, "Mine's on already. The other bomb is with %s." % ("you" if by_donat else "Donat"))
		return false
	set_flag(carried)
	set_flag(id)
	_set_bomb_light(id, true)
	_refresh_spots()
	_refresh_status()
	GameState.notify("%s the bomb against the hull of %s. Its red light starts blinking. (%d/2)" % ["Donat presses" if by_donat else "You press", String(SHIPS[id]["name"]), bombs_planted()])
	if bombs_planted() == 2:
		_set_switched(false)
		if is_instance_valid(donat_fighter):
			donat_fighter.set_order("follow")
		_bark(donat_fighter if is_instance_valid(donat_fighter) else player, "Both on. Now Davor.")
		GameState.notify("Both bombs are planted. Donat comes back to you. Now get to Davor.")
	return true

## At Davor's post: with both bombs planted Martin comes out and the fight starts.
func reach_davor() -> void:
	if fight_active:
		return
	if bombs_planted() < 2:
		_scene([
			_line("Davor", "(Whispering.) Is that you? Don't stand there, they look this way every minute."),
			_line("Donat", "Bombs first. If we take him now, those ships are on us before we're off the ground."),
		])
		return
	if has_flag("men_beaten"):
		_scene([
			_line("Davor", "He's still in there. He'll come out the moment you touch this chain."),
			_line("", "The prison door opens."),
		], start_fight)
		return
	_scene([
		_line("Davor", "(He lifts his head.) You came. You actually came. Who's the grumpy one?"),
		_line("Donat", "The grumpy one is your rescue. Hold still."),
		_line("", "Boots on stone. Martin's men pour out of the guardhouse and spread out round the post."),
		_line("Donat", "I'll take the ugly ones. That's all of them."),
	], start_fight)

# ---------- the watch: sentries and searchlights ----------

## A sentry walking back and forth along a route, looking about at each end.
## Its view cone is cut short by walls, rocks and buildings.
class BavarinSentry extends Node2D:
	var route := PackedVector2Array()
	var target := 1
	var pause := 0.0
	var facing := Vector2.RIGHT
	var look_angle := 0.0
	var cone: Polygon2D
	var _clock := 0.0
	var _sprite: Sprite2D

	func setup(texture_path: String, points: PackedVector2Array, offset_seconds: float) -> void:
		route = points
		global_position = points[0]
		facing = (points[1] - points[0]).normalized()
		_clock = offset_seconds
		_sprite = Sprite2D.new()
		_sprite.texture = load(texture_path) as Texture2D
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.centered = false
		if _sprite.texture != null:
			_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
		add_child(_sprite)
		cone = Polygon2D.new()
		cone.name = "Cone"
		cone.color = Color(1.0, 0.92, 0.55, 0.2)
		cone.z_index = 55

	func step(delta: float) -> void:
		_clock += delta
		if pause > 0.0:
			pause -= delta
			look_angle = sin(_clock * 2.4) * 0.9
		else:
			look_angle = 0.0
			var goal := route[target]
			var offset := goal - global_position
			if offset.length() <= SENTRY_SPEED * delta:
				global_position = goal
				target = (target + 1) % route.size()
				pause = SENTRY_PAUSE
			else:
				facing = offset.normalized()
				global_position += facing * SENTRY_SPEED * delta
		_sprite.flip_h = facing.x < -0.1
		z_index = 100 + int(global_position.y)

	func eye() -> Vector2:
		return global_position + Vector2(0, -6)

	func looking() -> Vector2:
		return facing.rotated(look_angle)

## A searchlight from a tower, its spot sweeping between two points.
class BavarinSearchlight extends Node2D:
	var from := Vector2.ZERO
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var period := 8.0
	var radii := Vector2(36, 20)
	var spot := Vector2.ZERO
	var _clock := 0.0

	func setup(settings: Dictionary, offset_seconds: float) -> void:
		from = settings["from"]
		a = settings["a"]
		b = settings["b"]
		period = float(settings["period"])
		_clock = offset_seconds
		z_index = 1400
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow
		step(0.0, radii)

	func step(delta: float, size: Vector2) -> void:
		_clock += delta
		radii = size
		spot = a.lerp(b, 0.5 - 0.5 * cos(_clock * TAU / period))
		queue_redraw()

	func lights(point: Vector2) -> bool:
		var offset := point - spot
		return Vector2(offset.x / radii.x, offset.y / radii.y).length() <= 1.0

	func _draw() -> void:
		var across := (spot - from).orthogonal().normalized() * radii.x * 0.8
		draw_colored_polygon(PackedVector2Array([from, spot + across, spot - across]), Color(1.0, 0.97, 0.75, 0.07))
		draw_set_transform(spot, 0.0, Vector2(1.0, radii.y / radii.x))
		draw_circle(Vector2.ZERO, radii.x, Color(1.0, 0.97, 0.75, 0.22))
		draw_circle(Vector2.ZERO, radii.x * 0.7, Color(1.0, 0.97, 0.75, 0.12))
		draw_set_transform(Vector2.ZERO)

func _spawn_watch() -> void:
	var i := 0
	while markers.has("sentry_%d_0" % i):
		var route := PackedVector2Array()
		var k := 0
		while markers.has("sentry_%d_%d" % [i, k]):
			route.append(marker("sentry_%d_%d" % [i, k]))
			k += 1
		var sentry := BavarinSentry.new()
		sentry.name = "Sentry_%d" % i
		sentry.setup(OBJ + String(SENTRY_TEXTURES[i % SENTRY_TEXTURES.size()]), route, i * 1.7)
		actors_root.add_child(sentry)
		add_child(sentry.cone)
		sentries.append(sentry)
		i += 1
	for j in SEARCHLIGHTS.size():
		var light := BavarinSearchlight.new()
		light.name = "Searchlight_%d" % j
		light.setup(SEARCHLIGHTS[j], j * 2.3)
		add_child(light)
		searchlights.append(light)
	_alarm_label = Label.new()
	_alarm_label.name = "Alarm"
	_alarm_label.position = Vector2(-20, -46)
	_alarm_label.size = Vector2(40, 14)
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alarm_label.z_index = 60
	_alarm_label.add_theme_font_size_override("font_size", 12)
	_alarm_label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	_alarm_label.add_theme_constant_override("shadow_offset_x", 1)
	_alarm_label.add_theme_constant_override("shadow_offset_y", 1)
	_alarm_label.visible = false
	player.add_child(_alarm_label)

func _spawn_storm() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Sandstorm"
	layer.layer = 4
	add_child(layer)
	_storm_cover = ColorRect.new()
	_storm_cover.color = Color(0.86, 0.7, 0.46)
	_storm_cover.modulate.a = 0.0
	_storm_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_storm_cover)
	_storm_label = Label.new()
	_storm_label.position = Vector2(8, 56)
	_storm_label.add_theme_font_size_override("font_size", 8)
	_storm_label.add_theme_color_override("font_color", Color("ffe6a8"))
	_storm_label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	_storm_label.add_theme_constant_override("shadow_offset_x", 1)
	_storm_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_storm_label)

## "calm", "warning" or "gust", from where the storm is in its cycle.
func storm_phase() -> String:
	var t := fmod(storm_time, SANDSTORM_CALM + SANDSTORM_WARN + SANDSTORM_GUST)
	if t < SANDSTORM_CALM:
		return "calm"
	if t < SANDSTORM_CALM + SANDSTORM_WARN:
		return "warning"
	return "gust"

func cone_length() -> float:
	return CONE_LENGTH * (GUST_CONE if storm_phase() == "gust" else 1.0)

func light_radii() -> Vector2:
	return LIGHT_RADII * (GUST_LIGHT if storm_phase() == "gust" else 1.0)

## Moves the sentries, the lights and the storm on by `delta` seconds.
func step_watch(delta: float) -> void:
	storm_time += delta
	var phase := storm_phase()
	var near_watch := player != null and (player.global_position.x >= WATCHED_FROM_X - 200.0 or in_base(player.global_position))
	_storm_cover.modulate.a = move_toward(_storm_cover.modulate.a, {"calm": 0.0, "warning": 0.1, "gust": 0.38}[phase] if near_watch else 0.0, delta * 0.8)
	_storm_label.text = {"calm": "", "warning": "The wind is rising...", "gust": "SANDSTORM: the guards can hardly see"}[phase] if near_watch else ""
	var space := get_world_2d().direct_space_state
	var length := cone_length()
	for sentry: BavarinSentry in sentries:
		sentry.step(delta)
		var points := PackedVector2Array([sentry.eye()])
		var looking := sentry.looking()
		for r in CONE_RAYS + 1:
			var direction := looking.rotated(lerpf(-CONE_HALF_ANGLE, CONE_HALF_ANGLE, float(r) / CONE_RAYS))
			var end := sentry.eye() + direction * length
			var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(sentry.eye(), end, 1))
			points.append(hit["position"] if not hit.is_empty() else end)
		sentry.cone.polygon = points
	var radii := light_radii()
	for light: BavarinSearchlight in searchlights:
		light.step(delta, radii)

## The bodies the guards can spot: the player's, and Donat's while the two are split up.
func watched_bodies() -> Array:
	var bodies: Array = [player]
	if splitting() and is_instance_valid(donat_fighter):
		bodies.append(donat_fighter)
	return bodies

## Who can see the player or Donat now: a sentry's node name, "searchlight", or "".
## `spotted` is set to the body that was seen.
var spotted: Node2D

func seen_by() -> String:
	spotted = null
	if player == null or _grace > 0.0:
		return ""
	var space := get_world_2d().direct_space_state
	var length := cone_length()
	for watched_body: Node2D in watched_bodies():
		if not watched(watched_body.global_position):
			continue
		var body := watched_body.global_position + Vector2(0, -6)
		for sentry: BavarinSentry in sentries:
			var offset := body - sentry.eye()
			if offset.length() > length or offset.length() < 0.1:
				continue
			if absf(sentry.looking().angle_to(offset)) > CONE_HALF_ANGLE:
				continue
			if space.intersect_ray(PhysicsRayQueryParameters2D.create(sentry.eye(), body, 1)).is_empty():
				spotted = watched_body
				return sentry.name
		for light: BavarinSearchlight in searchlights:
			if light.lights(watched_body.global_position):
				spotted = watched_body
				return "searchlight"
	return ""

## Builds up or wears off being seen, and sends the player back once seen for SPOT_SECONDS.
func step_stealth(delta: float) -> void:
	_grace = maxf(0.0, _grace - delta)
	var seer := seen_by()
	if seer != "":
		suspicion += delta
	else:
		suspicion = maxf(0.0, suspicion - delta * SUSPICION_DECAY)
	_alarm_label.visible = suspicion > 0.0
	if is_instance_valid(spotted) and _alarm_label.get_parent() != spotted:
		_alarm_label.reparent(spotted, false)
	_alarm_label.text = "!" if seer != "" and suspicion >= SPOT_SECONDS * 0.6 else "?"
	_alarm_label.add_theme_color_override("font_color", Color("ff5a4a") if _alarm_label.text == "!" else Color("ffe680"))
	for sentry: BavarinSentry in sentries:
		sentry.cone.color = Color(1.0, 0.3, 0.25, 0.3) if seer == sentry.name else Color(1.0, 0.92, 0.55, 0.2)
	if suspicion >= SPOT_SECONDS:
		caught(seer)

## The alarm: the player is sent back to the last checkpoint.
func caught(seer: String) -> void:
	times_caught += 1
	suspicion = 0.0
	_grace = RESTART_GRACE
	_alarm_label.visible = false
	for sentry: BavarinSentry in sentries:
		if sentry.name == seer:
			_bark(sentry, "Intruder!")
	screen_flash(Color(1.0, 0.15, 0.1, 0.55), 0.7, 0.1)
	var inside := has_flag("wall_climbed")
	var who := "Donat was" if spotted != null and spotted == donat_fighter else "You were"
	if bodies_switched:
		_set_switched(false)
	_alarm_label.reparent(player, false)
	move_player(marker("breach_in") if inside else marker("dunes_start"))
	_bring_donat()
	if is_instance_valid(donat_fighter) and splitting():
		donat_fighter.hold_at(donat_fighter.global_position, "wait")
	GameState.notify("Intruder! %s seen%s. You both slip away and start again %s." % [who, " in the searchlight" if seer == "searchlight" else "", "inside the wall" if inside else "at the edge of the dunes"])

func sneaking() -> bool:
	return not fight_active and not has_flag("martin_beaten")

## A short shout over `body`, rising and fading.
func _bark(body: Node2D, text: String) -> Label:
	if not is_instance_valid(body):
		return null
	var old := body.get_node_or_null("Bark")
	if old != null:
		old.free()
	var label := Label.new()
	label.name = "Bark"
	label.text = text
	label.position = Vector2(-60, -48)
	label.size = Vector2(120, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 50
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("ffe680"))
	label.add_theme_color_override("font_shadow_color", Color("1c1730"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	body.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", -60.0, 1.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.8)
	tween.tween_callback(label.queue_free)
	return label

# ---------- the fight with Martin ----------

func start_fight() -> bool:
	if fight_active or has_flag("martin_beaten") or bombs_planted() < 2:
		return false
	_end_fight()
	fight_active = true
	_fight_ending = false
	suspicion = 0.0
	_alarm_label.visible = false
	GameState.restore_health()
	move_player(marker("fight_player"))
	_spawn_follower()
	donat_fighter.global_position = marker("fight_donat")
	donat_fighter.revive(donat_fighter.max_health)
	donat_fighter.set_order("attack")
	donat_fighter.get_up_seconds = 5.0
	for sentry: BavarinSentry in sentries:
		sentry.visible = false
		sentry.cone.visible = false
	if has_flag("men_beaten"):
		_start_duel()
		return true
	fight_stage = "men"
	for i in 4:
		men.append(_spawn_man(i))
	_second_wave_left = [4, 5, 6, 7]
	_second_wave_time = SECOND_WAVE_SECONDS
	GameState.notify("Fight Martin's men. Press 1 to fight in your own body, 2 to take over Donat's.")
	_refresh_status()
	return true

## Martin comes out of the prison block and stands in the doorway.
func _spawn_martin() -> void:
	martin = MartinBoss.new()
	martin.name = "story_bavarin_martin"
	martin.configure("martin_admin", "res://assets/art/rock/martin.png", marker("martin_stand"), "story_bavarin_martin")
	martin.relentless = true
	actors_root.add_child(martin)
	martin.banishing_hit.connect(_on_banishing_hit)

## All of Martin's men are down: Martin comes out and banishes Donat.
func _men_beaten() -> void:
	_fight_ending = true
	set_flag("men_beaten")
	_set_switched(false)
	_spawn_martin()
	_hold_fight(true)
	_scene([
		_line("", "The last of the guards goes down. For a moment the yard is quiet."),
		_line("", "Then the prison door opens. Martin steps out with a purple sword at his hip and a bow in his hand."),
		_line("Martin", "You again? Didn't you learn your lesson last time?"),
		_line("Donat", "Oh good, the boss. Leave him to me, I'll—"),
	], func() -> void:
		_banish_donat_scripted()
		_scene([
			_line("", "Martin looses an arrow. It glows purple, and it takes Donat in the chest. Donat drops like a sack."),
			_line("Davor", "A Banishing Arrow! Donat!"),
			_line("Donat", "(Face down in the sand.) ...Not gone. Can't feel... anything. Hit him for me. Hard."),
			_line("Martin", "That's your friend done. Now it's just you and me."),
		], func() -> void:
			_fight_ending = false
			_hold_fight(false)
			_start_duel()))

## Donat lies where the arrow dropped him for the rest of the fight.
func _banish_donat_scripted() -> void:
	if not is_instance_valid(donat_fighter):
		return
	var arrow := Line2D.new()
	arrow.width = 2.0
	arrow.default_color = MartinBoss.BLADE_COLOR
	arrow.points = PackedVector2Array([martin.global_position + Vector2(0, -8), donat_fighter.global_position + Vector2(0, -8)]) if is_instance_valid(martin) else PackedVector2Array()
	add_child(arrow)
	arrow.z_index = 950
	var tween := arrow.create_tween()
	tween.tween_property(arrow, "modulate:a", 0.0, 0.5)
	tween.tween_callback(arrow.queue_free)
	_banish_donat()

func _banish_donat() -> void:
	if not is_instance_valid(donat_fighter):
		return
	if bodies_switched:
		_set_switched(false)
	donat_fighter.get_up_seconds = 0.0
	if not donat_fighter.down:
		donat_fighter.knock_down()
	donat_fighter._sprite.modulate = Color(0.7, 0.55, 0.9)
	screen_flash(Color(0.7, 0.3, 1.0, 0.4), 0.4)

## The duel: Martin against the player alone, with Donat down beside the post.
func _start_duel() -> void:
	fight_stage = "duel"
	if not is_instance_valid(martin):
		_spawn_martin()
	if is_instance_valid(donat_fighter) and not donat_fighter.down:
		donat_fighter.global_position = marker("fight_donat")
		_banish_donat()
	GameState.notify("The duel with Martin. Watch the ground: purple is his Banishing Sword and Arrows, red is where he lands.")
	_refresh_status()

## Stops everyone in the fight while a scene plays in the middle of it, and
## starts them again afterwards.
func _hold_fight(on: bool) -> void:
	var nodes: Array = men.duplicate()
	nodes.append(martin)
	nodes.append(donat_fighter)
	for node in actors_root.get_children() + get_children():
		if node is MartinBoss.MartinArrow or node is Projectile:
			nodes.append(node)
	for node in nodes:
		if is_instance_valid(node):
			node.set_physics_process(not on)
			if node is CharacterBody2D:
				(node as CharacterBody2D).velocity = Vector2.ZERO
	if on and is_instance_valid(martin):
		martin.cancel_special()
	_fight_held = on

## Martin's sword and arrows banish whoever they hit, except a Brine.
func _on_banishing_hit(target: Node2D, damage: int) -> void:
	if target == player:
		player.take_damage(damage, martin.global_position if is_instance_valid(martin) else Vector2.ZERO)
		if not has_flag("brine_shrugged") and fight_active and not _fight_ending and GameState.health > 0:
			_brine_shrugs()
		return
	if target == donat_fighter:
		_banish_donat()
		_bark(donat_fighter, "Banished... no. Just... floored.")
		return
	target.take_damage(damage, martin.global_position if is_instance_valid(martin) else Vector2.ZERO)

## The first Banishing hit on the MC: nothing happens, and Martin cannot believe it.
func _brine_shrugs() -> void:
	set_flag("brine_shrugged")
	_hold_fight(true)
	_scene([
		_line("", "The purple light goes right through you. It tingles a little. That's all."),
		_line("Martin", "...What? One touch of Banishing and anyone is gone. Anyone!"),
		_line("You", "Was that supposed to do something?"),
		_line("Donat", "(Still face down.) Look at the eyes, genius. White. A Brine. Your fancy toys don't work on Brines."),
		_line("Davor", "Ha! Look at his face! Oh, I wish I had a picture of that face."),
		_line("Martin", "A Brine. ...Fine. Then I'll cut you up the ordinary way. It just takes longer."),
	], func() -> void:
		_hold_fight(false))

func _spawn_man(index: int) -> Enemy:
	var kind := String(MEN_KINDS[index])
	var texture := OBJ + "republic_soldier_%d.png" % (index % 3 + 5)
	if kind == "republic_tvrdium_guard":
		texture = ART + "tvrdium_guard.png"
	elif kind == "republic_guardsman":
		texture = OBJ + "republic_guardsman.png"
	var stable_id := "story_bavarin_man_%d" % index
	var enemy := Enemy.new()
	enemy.name = stable_id
	enemy.configure(kind, texture, _walkable(marker("man_%d" % index)), stable_id)
	enemy.relentless = true
	actors_root.add_child(enemy)
	return enemy

func _send_second_wave() -> void:
	for index: int in _second_wave_left:
		men.append(_spawn_man(index))
	_second_wave_left.clear()
	if not men.is_empty():
		_bark(men[0], "Over here! All of you!")
	_refresh_status()

## Puts the player in Donat's body (`on`) or back in their own.
func _set_switched(on: bool) -> void:
	var was := bodies_switched
	bodies_switched = on and is_instance_valid(donat_fighter) and not donat_fighter.down and (fight_stage == "men" if fight_active else splitting())
	if is_instance_valid(donat_fighter):
		donat_fighter.controlled = bodies_switched
		donat_fighter.velocity = Vector2.ZERO
	if player != null:
		player.velocity = Vector2.ZERO
	_camera_on(donat_fighter if bodies_switched else player)
	_body_path = PackedVector2Array()
	_body_repath = 0.0
	if was != bodies_switched:
		screen_flash(Color(1, 1, 1, 0.5), 0.25)
	_refresh_status()

func _camera_on(body: Node2D) -> void:
	if _camera == null or not is_instance_valid(body) or _camera.get_parent() == body:
		return
	_camera.reparent(body)
	_camera.position = Vector2(0, -24)
	_camera.make_current()
	refresh_camera()

func _unhandled_input(event: InputEvent) -> void:
	var can_switch := (fight_active and not _fight_ending) or splitting()
	if can_switch and player != null and not player.ui_is_open() and not get_tree().paused:
		if event.is_action_pressed("party_player"):
			_set_switched(false)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("party_first"):
			if fight_stage == "duel":
				_bark(player, "Donat's out. This one's mine.")
			elif is_instance_valid(donat_fighter) and donat_fighter.down:
				_bark(donat_fighter, "I'm down! Give me a second!")
			else:
				_set_switched(true)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

## While the player is in Donat's body, the movement keys and attack move it
## (DonatFighter.controlled), and Donat drives the player's body.
func controlled_actor() -> CharacterBody2D:
	if bodies_switched and is_instance_valid(donat_fighter):
		return donat_fighter
	return super.controlled_actor()

func attack_as(actor: CharacterBody2D) -> void:
	if actor == donat_fighter and is_instance_valid(donat_fighter):
		donat_fighter._strike(null)
		return
	super.attack_as(actor)

## Donat in the player's body: he walks to the nearest enemy and hits it with
## the player's weapon. With a bow he lines up with it first, since arrows fly
## straight along the way the body faces.
func drive_player_body(body: Player, delta: float) -> bool:
	if not bodies_switched:
		return false
	body.velocity = Vector2.ZERO
	# While they are split up, the body the player left stands still.
	if body.ui_is_open() or get_tree().paused or not fight_active:
		return true
	var target := nearest_hostile(body.global_position, INF)
	if target == null:
		return true
	var weapon := GameState.weapon_definition()
	var reach := float(weapon.get("reach", 24.0))
	var ranged := bool(weapon.get("ranged", false))
	var offset := target.global_position - body.global_position
	var goal := target.global_position
	if ranged:
		var line := _cardinal(offset)
		var across := absf(offset.dot(line.orthogonal()))
		if offset.length() <= reach * 0.8 and across <= 6.0:
			face_actor(body, offset)
			body._attack(target)
			return true
		goal = target.global_position - line * minf(offset.length(), reach * 0.6)
	elif offset.length() <= reach * 0.9:
		face_actor(body, offset)
		body._attack(target)
		return true
	_body_repath -= delta
	if _body_repath <= 0.0 or _body_path_index >= _body_path.size():
		_body_path = tiled_loader.get_walk_path(body.global_position, goal)
		_body_path_index = 1 if _body_path.size() > 1 else 0
		_body_repath = BODY_REPATH_SECONDS
	while _body_path_index < _body_path.size() and body.global_position.distance_to(_body_path[_body_path_index]) < 4.0:
		_body_path_index += 1
	var next := _body_path[_body_path_index] if _body_path_index < _body_path.size() else goal
	var direction := next - body.global_position
	if direction.length() < 1.0:
		return true
	face_actor(body, direction)
	body.velocity = direction.normalized() * Player.SPEED
	body.move_and_slide()
	return true

func _refresh_status() -> void:
	var ui := _ui()
	if ui != null:
		ui.refresh_location()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	# The title follows the player from the canyon to the oasis, the dunes and the base.
	var title := location_title()
	if title != _shown_title:
		_shown_title = title
		_refresh_status()
	if fight_active:
		if not _fight_ending:
			_step_fight(delta)
		return
	if has_flag("martin_beaten"):
		return
	if player.ui_is_open() or get_tree().paused:
		return
	step_watch(delta)
	step_stealth(delta)
	if splitting():
		# Split up, Donat stays where he was left while the player is not in him.
		if is_instance_valid(donat_fighter) and not bodies_switched and donat_fighter.order != "hold":
			donat_fighter.hold_at(donat_fighter.global_position, "wait")
	elif is_instance_valid(donat_fighter) and donat_fighter.global_position.distance_to(player.global_position) > 160.0:
		# Donat is carried along if he falls far behind.
		_bring_donat()

func _step_fight(delta: float) -> void:
	if _fight_held:
		return
	if fight_stage == "duel":
		if is_instance_valid(martin) and martin.health <= int(martin.max_health * MARTIN_BEATEN_SHARE) and not martin.in_air():
			martin_beaten()
		return
	var standing := men.size()
	men = men.filter(func(enemy) -> bool: return is_instance_valid(enemy) and (enemy as Enemy).health > 0)
	_second_wave_time -= delta
	if not _second_wave_left.is_empty() and (men.size() <= GUARDS_LEFT_FOR_SECOND_WAVE or _second_wave_time <= 0.0):
		_send_second_wave()
	elif men.size() != standing:
		_refresh_status()
	if bodies_switched and is_instance_valid(donat_fighter) and donat_fighter.down:
		_set_switched(false)
		_bark(player, "Donat's down!")
	if men.is_empty() and _second_wave_left.is_empty():
		_men_beaten()

## A hit that would knock the player out ends the round instead, and Davor shouts them up again.
func _on_health_changed(health: int, max_health: int) -> void:
	if not fight_active or _fight_ending or health > 0:
		return
	GameState.health = 1
	GameState.health_changed.emit.call_deferred(1, max_health)
	_fight_ending = true
	call_deferred("_fight_lost")

func _fight_lost() -> void:
	var fight_stage_lost := fight_stage
	_end_fight()
	_scene([
		_line("", "The flat of Martin's sword cracks across your back and the ground comes up hard." if fight_stage_lost == "duel" else "A guard's boot catches you in the ribs and the ground comes up hard."),
		_line("Davor", "Up! Get up! He's not done, and neither are you!"),
		_line("", "You drag yourself up. Martin raises his sword again." if fight_stage_lost == "duel" else "You drag yourself up. Martin's men close in again."),
	], start_fight)

## Martin is down to a quarter of his health: the bombs go off, his men drag
## him away, and Davor is freed.
func martin_beaten() -> void:
	if not fight_active or _fight_ending:
		return
	_fight_ending = true
	set_flag("martin_beaten")
	for node in [martin] + men:
		if is_instance_valid(node):
			node.set_physics_process(false)
			(node as Enemy).velocity = Vector2.ZERO
	if is_instance_valid(martin):
		martin.cancel_special()
	screen_flash(Color(1.0, 0.75, 0.4, 0.9), 1.2, 0.2)
	shake_camera(1.2, 6.0)
	_set_switched(false)
	for id: String in SHIPS:
		_set_bomb_light(id, false)
	_burn_ships()
	_scene([
		_line("", "Martin staggers back and drops to one knee, the purple light of his sword flickering. Then the landing pads go up."),
		_line("", "Veki's bombs blow the hulls of both warships open. Fire rolls over the pads."),
		_line("Martin", "My ship! ...You'll pay for this. The Admins don't forget."),
		_line("", "Two of his men grab Martin under the arms and drag him back into the prison block. The rest run for the fire."),
		_line("Donat", "Running. Of course they're running."),
	], _after_fight)

func _after_fight() -> void:
	_end_fight()
	_sync_story()
	GameState.restore_health()
	GameState.notify("Martin is beaten. Free Davor from his chain.")

func free_davor() -> void:
	if has_flag("davor_freed") or not has_flag("martin_beaten"):
		return
	set_flag("davor_freed")
	GameState.davor_health = -1
	_scene([
		_line("", "You knock the pin out of the chain, and Davor's hands come free."),
		_line("Davor", "Took you long enough. ...Thank you. Both of you."),
		_line("Donat", "Don't thank me. Thank me by never being kidnapped again."),
		_line("Veki", "(On the radio.) Ships burning, Republic running, and nobody shooting at me. Coming down!"),
	], land_lasta)

## Veki brings the Lasta down south of the parade ground.
func land_lasta() -> void:
	_sync_story()
	var landing := marker("lasta_landing")
	_landed_lasta.position = landing + Vector2(0, -360)
	var tween := create_tween()
	tween.tween_property(_landed_lasta, "position", landing, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void: shake_camera(0.3, 2.0))
	GameState.notify("Davor is free. The rest of the Sea of Propuh is not in the game yet.")

## Clears the fight away without deciding anything; used between rounds and on load.
func _end_fight() -> void:
	if bodies_switched:
		_set_switched(false)
	bodies_switched = false
	if is_instance_valid(martin):
		martin.queue_free()
	martin = null
	for enemy in men:
		if is_instance_valid(enemy):
			enemy.queue_free()
	men.clear()
	_second_wave_left.clear()
	for node in get_children() + actors_root.get_children():
		if node is Projectile or node is SlashArc or node is MartinBoss.MartinArrow or (node is Node2D and String(node.name).begins_with("MartinWarning")):
			node.queue_free()
	fight_active = false
	fight_stage = ""
	_fight_held = false
	if is_instance_valid(donat_fighter):
		donat_fighter.controlled = false
		donat_fighter.revive(donat_fighter.max_health)
		donat_fighter.set_order("follow")
	_camera_on(player)
	_refresh_status()
