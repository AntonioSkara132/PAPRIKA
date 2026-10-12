extends Control

const Atlas = preload("res://scripts/data/planet_atlas.gd")
const VIEW_SIZE := Vector2(620, 340)
const CHART_ORIGIN := Vector2(12, 62)
const CHART_SIZE := Vector2(426, 248)
const INK := Color("11111d")
const CREAM := Color("f7f1dd")
const MUTED := Color("b6adbf")
const GOLD := Color("f5c34c")
const ENGINEERIA := Color("dfaa65")
const CAULIFLOWER := Color("9dcc86")

signal close_requested

var buttons: Dictionary = {}
var selected_id := ""
var current_planet_id := ""
var entries_by_id: Dictionary = {}
var detail_name: Label
var detail_faction: Label
var detail_terrain: Label
var detail_description: Label
var detail_status: Label
var detail_image: TextureRect
var location_label: Label
var close_button: Button

func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label("PLANET MAP", Vector2(14, 8), Vector2(220, 22), 17, CREAM)
	location_label = _label("", Vector2(15, 31), Vector2(430, 15), 9, MUTED)
	_label("ENGINEERIA · NW", Vector2(19, 47), Vector2(194, 14), 10, ENGINEERIA)
	_label("CAULIFLOWER · NE", Vector2(244, 47), Vector2(194, 14), 10, CAULIFLOWER)
	_label("UNKNOWN WORLDS · %d" % Atlas.unknown_count(), CHART_ORIGIN + Vector2(9, 121), Vector2(250, 14), 9, MUTED)
	_label("Click a planet · Arrow keys / Tab browse · Enter selects", Vector2(14, 317), Vector2(330, 14), 9, MUTED)
	_label("Library census · schematic, not to scale", Vector2(350, 317), Vector2(260, 14), 9, MUTED)
	close_button = Button.new()
	close_button.name = "CloseMap"
	close_button.text = "Close  [M / Esc]"
	close_button.position = Vector2(489, 10)
	close_button.size = Vector2(116, 25)
	close_button.add_theme_font_size_override("font_size", 11)
	close_button.add_theme_color_override("font_color", CREAM)
	close_button.add_theme_stylebox_override("normal", _style(Color("302b3a"), Color("766449")))
	close_button.add_theme_stylebox_override("hover", _style(Color("50402d"), GOLD))
	close_button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)
	_build_details()
	for entry: Dictionary in Atlas.entries():
		entries_by_id[entry["id"]] = entry
		_add_planet(entry)
	_set_focus_routes()

func show_map(planet_key: String) -> void:
	current_planet_id = Atlas.current_id(planet_key)
	location_label.text = "Current location: %s  ·  %d worlds in the library census" % [Atlas.current_name(planet_key), Atlas.world_count()]
	visible = true
	select_planet(current_planet_id if buttons.has(current_planet_id) else "paprika")
	(buttons[selected_id] as Button).grab_focus()
	queue_redraw()

func _draw() -> void:
	draw_style_box(_style(Color("16141f"), Color("b38a48")), Rect2(Vector2.ZERO, VIEW_SIZE))
	draw_rect(Rect2(CHART_ORIGIN, CHART_SIZE), INK)
	draw_rect(Rect2(CHART_ORIGIN + Vector2(1, 0), Vector2(209, 116)), Color(0.24, 0.18, 0.13, 0.22))
	draw_rect(Rect2(CHART_ORIGIN + Vector2(219, 0), Vector2(206, 116)), Color(0.15, 0.23, 0.15, 0.22))
	draw_rect(Rect2(450, 44, 158, 266), Color("23202c"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	for index in 100:
		var point := CHART_ORIGIN + Vector2(rng.randi_range(2, 423), rng.randi_range(1, 244))
		draw_rect(Rect2(point, Vector2.ONE), Color("494455") if index % 4 else Color("807181"))
	draw_line(CHART_ORIGIN + Vector2(215, 5), CHART_ORIGIN + Vector2(215, 113), Color("39323e"))
	if entries_by_id.has(current_planet_id):
		var point: Vector2 = CHART_ORIGIN + entries_by_id[current_planet_id]["position"] + Vector2(22, -17)
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -3), point + Vector2(3, 0), point + Vector2(0, 3), point + Vector2(-3, 0)]), GOLD)

func _add_planet(entry: Dictionary) -> void:
	var known: bool = entry["known"]
	var button := Button.new()
	button.name = String(entry["id"])
	button.size = Vector2(64, 52) if known else Vector2(24, 24)
	button.position = CHART_ORIGIN + entry["position"] - button.size * 0.5
	button.tooltip_text = "%s — %s" % [entry["name"], entry["terrain"]]
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT))
	button.add_theme_stylebox_override("hover", _style(Color("302b3a"), Color("8c795c")))
	button.add_theme_stylebox_override("pressed", _style(Color("443927"), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD))
	add_child(button)
	var image := TextureRect.new()
	image.texture = load(entry["image"]) as Texture2D
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size = Vector2(32, 32) if known else Vector2(24, 24)
	image.position = Vector2(16, 1) if known else Vector2.ZERO
	button.add_child(image)
	if known:
		var label := _label(entry["name"], Vector2(0, 34), Vector2(64, 16), 10, CREAM, button)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = ""
	button.pressed.connect(select_planet.bind(entry["id"]))
	button.focus_entered.connect(select_planet.bind(entry["id"]))
	buttons[entry["id"]] = button

func _build_details() -> void:
	detail_image = TextureRect.new()
	detail_image.position = Vector2(497, 51)
	detail_image.size = Vector2(64, 64)
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail_image)
	detail_name = _label("", Vector2(460, 116), Vector2(138, 22), 16, CREAM)
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_faction = _label("", Vector2(460, 141), Vector2(138, 29), 10, MUTED)
	detail_faction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_faction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_terrain = _label("", Vector2(460, 166), Vector2(138, 26), 10, GOLD)
	detail_terrain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_terrain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_description = _label("", Vector2(460, 193), Vector2(138, 99), 10, CREAM)
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_status = _label("", Vector2(460, 294), Vector2(138, 14), 9, GOLD)
	detail_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func select_planet(id: String) -> void:
	if not entries_by_id.has(id):
		return
	selected_id = id
	if not (buttons[id] as Button).has_focus():
		(buttons[id] as Button).grab_focus()
	var entry: Dictionary = entries_by_id[id]
	detail_name.text = entry["name"]
	detail_faction.text = entry["faction"]
	detail_faction.modulate = ENGINEERIA if entry["faction"] == "Engineeria" else CAULIFLOWER if entry["faction"] == "Cauliflower Confederation" else Color.WHITE
	detail_terrain.text = entry["terrain"]
	detail_description.text = entry["description"]
	detail_image.texture = load(entry["image"]) as Texture2D
	detail_status.text = "YOU ARE HERE" if id == current_planet_id else "Information only · no travel"
	for key: String in buttons:
		var selected := key == id
		(buttons[key] as Button).add_theme_stylebox_override("normal", _style(Color(0.3, 0.24, 0.15, 0.42) if selected else Color.TRANSPARENT, GOLD if selected else Color.TRANSPARENT))

func _set_focus_routes() -> void:
	var ids := buttons.keys()
	for index in ids.size():
		var button: Button = buttons[ids[index]]
		button.focus_next = button.get_path_to(close_button if index == ids.size() - 1 else buttons[ids[index + 1]])
		button.focus_previous = button.get_path_to(close_button if index == 0 else buttons[ids[index - 1]])
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var nearest: Button
			var score := INF
			for other_id: String in ids:
				var other: Button = buttons[other_id]
				var offset := (other.position + other.size * 0.5) - (button.position + button.size * 0.5)
				var forward := offset.dot(direction)
				if forward <= 1.0:
					continue
				var lateral := absf(offset.cross(direction))
				var distance := forward + lateral * 3.0
				if distance < score:
					score = distance
					nearest = other
			var path := button.get_path_to(nearest if nearest != null else button)
			if direction == Vector2.LEFT:
				button.focus_neighbor_left = path
			elif direction == Vector2.RIGHT:
				button.focus_neighbor_right = path
			elif direction == Vector2.UP:
				button.focus_neighbor_top = path
			else:
				button.focus_neighbor_bottom = path
	close_button.focus_next = close_button.get_path_to(buttons[ids[0]])
	close_button.focus_previous = close_button.get_path_to(buttons[ids[-1]])

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style
