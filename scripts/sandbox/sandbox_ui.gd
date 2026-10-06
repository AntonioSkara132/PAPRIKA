class_name SandboxUI
extends CanvasLayer

signal order_submitted(prompt: String)
signal landmark_selected(id: String)
signal stop_requested
signal reset_requested
signal demo_requested
signal connection_retry_requested

const INK := Color("1c1730")
const PANEL := Color(0.07, 0.065, 0.12, 0.94)
const CREAM := Color("f7f1dd")
const GOLD := Color("f5c34c")
const CYAN := Color("5fd6d3")
const RED := Color("ef7777")

var order_input: LineEdit
var status_label: Label
var progress_label: Label
var connection_label: Label
var groups_label: Label
var tasks_label: Label
var _landmark_buttons: Dictionary = {}
var _send_button: Button

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "SandboxControls"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_header(root)
	_build_details(root)
	_build_order_panel(root)
	set_landmarks({}, "")
	set_connection("Checking local order service…")
	set_status("Create groups, follow in formation, or patrol A–B. Type stop for immediate cancellation.")
	set_groups({})
	set_task_list([])
	set_progress("12 soldiers ready · campaign saves are not used")

func _build_header(root: Control) -> void:
	var panel := _panel(root, false)
	panel.name = "HeaderPanel"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	content.add_child(title_row)
	var title := _label("SOLDIER SANDBOX", 13, GOLD)
	title_row.add_child(title)
	connection_label = _label("", 10, CYAN)
	connection_label.mouse_filter = Control.MOUSE_FILTER_PASS
	connection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	connection_label.clip_text = true
	connection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(connection_label)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 5)
	buttons.add_theme_constant_override("v_separation", 3)
	content.add_child(buttons)
	for id: String in ["A", "B", "C"]:
		var button := _button("Place " + id)
		button.toggle_mode = true
		button.tooltip_text = "Select " + id + ", then click the map to place or move that landmark."
		button.pressed.connect(_choose_landmark.bind(id))
		buttons.add_child(button)
		_landmark_buttons[id] = button
	var stop := _button("Stop")
	stop.tooltip_text = "Stop every task and cancel any pending model reply immediately. Typing stop does the same."
	stop.pressed.connect(func() -> void:
		_release_text_focus()
		stop_requested.emit()
	)
	buttons.add_child(stop)
	var reset := _button("Reset")
	reset.tooltip_text = "Stop all tasks, clear named groups, and restore starting positions and landmarks."
	reset.pressed.connect(func() -> void:
		_release_text_focus()
		reset_requested.emit()
	)
	buttons.add_child(reset)
	var demo := _button("Offline example")
	demo.tooltip_text = "Run the fixed line A–B example. This does not contact or use an LLM."
	demo.pressed.connect(func() -> void:
		_release_text_focus()
		demo_requested.emit()
	)
	buttons.add_child(demo)
	var reconnect := _button("Reconnect")
	reconnect.tooltip_text = "Check the local order service again."
	reconnect.pressed.connect(func() -> void:
		_release_text_focus()
		connection_retry_requested.emit()
	)
	buttons.add_child(reconnect)
	var hints := _label("WASD/arrows move · T type · click to place selected landmark · Esc cancel", 10, CREAM)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hints)

func _build_details(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TaskPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("57506d")))
	panel.offset_left = 8
	panel.offset_right = 230
	panel.offset_top = 86
	panel.offset_bottom = 248
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)
	content.add_child(_label("GROUPS", 10, GOLD))
	groups_label = _label("", 10, CREAM)
	groups_label.name = "NamedGroups"
	groups_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	groups_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(groups_label)
	content.add_child(_label("RUNNING TASKS", 10, GOLD))
	tasks_label = _label("", 10, CYAN)
	tasks_label.name = "ActiveTasks"
	tasks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tasks_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(tasks_label)

func _build_order_panel(root: Control) -> void:
	var panel := _panel(root, true)
	panel.name = "OrderPanel"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	content.add_child(input_row)
	order_input = LineEdit.new()
	order_input.name = "OrderInput"
	order_input.placeholder_text = "Create Alpha, follow in formation, patrol A–B, or stop"
	order_input.tooltip_text = "Submit separately: 'create Alpha with soldiers 1 to 6', 'Alpha follow me in formation', 'Beta patrol between A and B'. Exact stop stops everyone without a model."
	order_input.max_length = 2000
	order_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_input.custom_minimum_size.y = 24
	order_input.add_theme_font_size_override("font_size", 12)
	order_input.add_theme_color_override("font_color", CREAM)
	order_input.add_theme_color_override("font_placeholder_color", Color("a9a2b8"))
	order_input.add_theme_color_override("caret_color", GOLD)
	order_input.add_theme_color_override("selection_color", Color("3b696f"))
	order_input.add_theme_stylebox_override("normal", _style(Color("211c32"), Color("57506d")))
	order_input.add_theme_stylebox_override("focus", _style(Color("211c32"), CYAN))
	order_input.text_submitted.connect(_submit)
	order_input.gui_input.connect(_on_order_gui_input)
	input_row.add_child(order_input)
	_send_button = _button("Send")
	_send_button.custom_minimum_size.x = 56
	_send_button.tooltip_text = "Send a text order. A newer submission replaces a pending request."
	_send_button.pressed.connect(func() -> void: _submit(order_input.text))
	input_row.add_child(_send_button)
	status_label = _label("", 11, CREAM)
	status_label.name = "OrderStatus"
	status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 27
	status_label.max_lines_visible = 2
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(status_label)
	progress_label = _label("", 10, CYAN)
	progress_label.name = "OrderProgress"
	progress_label.mouse_filter = Control.MOUSE_FILTER_PASS
	progress_label.clip_text = true
	progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(progress_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and is_typing():
		_release_text_focus()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_T and not is_typing():
		order_input.grab_focus()
		get_viewport().set_input_as_handled()

func _on_order_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_release_text_focus()
		order_input.accept_event()

func set_status(text: String, is_error: bool = false) -> void:
	status_label.text = text
	status_label.tooltip_text = text
	status_label.add_theme_color_override("font_color", RED if is_error else CREAM)

func set_progress(text: String) -> void:
	progress_label.text = text
	progress_label.tooltip_text = text

func set_groups(groups: Dictionary) -> void:
	var lines: Array[String] = []
	var names: Array = groups.keys()
	names.sort()
	for group_name: String in names:
		var ids: Array = groups[group_name]
		if group_name == "all":
			lines.append("all: %d soldiers" % ids.size())
		else:
			var members: Array[String] = []
			for id: String in ids:
				members.append(id.trim_prefix("soldier_"))
			lines.append("%s: %s" % [group_name, ", ".join(members)])
	groups_label.text = "\n".join(lines) if not lines.is_empty() else "No named groups."
	groups_label.tooltip_text = groups_label.text

func set_task_list(lines: Array[String]) -> void:
	tasks_label.text = "\n\n".join(lines) if not lines.is_empty() else "No running tasks."
	tasks_label.tooltip_text = tasks_label.text

func set_connection(text: String) -> void:
	connection_label.text = text
	connection_label.tooltip_text = text

func set_landmarks(landmarks: Dictionary, selected: String) -> void:
	for id: String in _landmark_buttons:
		var button: Button = _landmark_buttons[id]
		button.text = "Place " + id + (" ✓" if landmarks.has(id) else "")
		button.set_pressed_no_signal(id == selected)
		button.add_theme_color_override("font_color", CYAN if id == selected else CREAM)

func set_busy(busy: bool) -> void:
	_send_button.text = "Replace" if busy else "Send"
	_send_button.tooltip_text = "Submit a newer order instead of waiting for this reply." if busy else "Send a text order."

func is_typing() -> bool:
	return is_instance_valid(order_input) and order_input.has_focus()

func _choose_landmark(id: String) -> void:
	_release_text_focus()
	landmark_selected.emit(id)

func _submit(text: String) -> void:
	var prompt := text.strip_edges()
	if prompt.is_empty():
		set_status("Type an order before sending it.", true)
		order_input.grab_focus()
		return
	if prompt.length() > 2000:
		set_status("Keep the order within 2,000 characters.", true)
		return
	_release_text_focus()
	order_submitted.emit(prompt)

func _release_text_focus() -> void:
	if is_instance_valid(order_input):
		order_input.release_focus()

func _panel(root: Control, at_bottom: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("57506d")))
	root.add_child(panel)
	panel.anchor_right = 1.0
	panel.offset_left = 8
	panel.offset_right = -8
	if at_bottom:
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_top = -90
		panel.offset_bottom = -8
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		panel.offset_top = 8
		panel.offset_bottom = 78
		panel.grow_vertical = Control.GROW_DIRECTION_END
	return panel

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 22
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("29253b"), Color("57506d")))
	button.add_theme_stylebox_override("hover", _style(GOLD, GOLD))
	button.add_theme_stylebox_override("pressed", _style(CYAN, CYAN))
	button.add_theme_stylebox_override("focus", _style(Color("29253b"), CYAN))
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", INK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
