## The Settings screen (ADR-0009 §7; 2026-11-04): one row per setting, then
## Back. Confirm or right steps a row's value forward, left steps it back;
## each step is written through `SettingsService.set_value()` and applies
## live. Back (or cancel) flushes the file and emits `closed`. Used as a
## child panel by Title and by the Menu overlay, which forward their
## actions here while it is open.
##
## Usage example:
## [codeblock]
## var panel := SettingsPanel.new()
## panel.setup(settings_service)
## add_child(panel)
## panel.closed.connect(func() -> void: panel.queue_free())
## [/codeblock]
class_name SettingsPanel
extends Control

## Back was chosen (the file is already flushed).
signal closed

## Row order and labels: [key, label].
const ROWS: Array = [
	[&"master_volume", "Master volume"],
	[&"music_volume", "Music volume"],
	[&"sfx_volume", "Sound effects volume"],
	[&"text_speed", "Text speed"],
	[&"display_fullscreen", "Fullscreen"],
	[&"display_vsync", "V-Sync"],
	[&"faster_battle_animations", "Faster battle animations"],
	[&"speed_up_boss_entrances", "Speed up boss entrances"],
	[&"screen_shake", "Screen shake"],
	[&"reduce_motion", "Reduce motion"],
	[&"reduce_flashing", "Reduce flashing"],
]
const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
const DIM: Color = Color(0.0, 0.0, 0.0, 0.55)

var _service: SettingsService = null
var _schema: SettingsSchema = SettingsSchema.new()
var _box: VBoxContainer = null
var _buttons: Array[Button] = []
var _row_by_key: Dictionary[StringName, Button] = {}
var _back: Button = null


func setup(service: SettingsService) -> void:
	_service = service
	_build()


## The button showing `key`'s row (tests).
func row(key: StringName) -> Button:
	return _row_by_key.get(key, null)


## The Back button (tests).
func back_button() -> Button:
	return _back


## The text a row shows for `key` right now ("Text speed: Fast").
func row_text(key: StringName) -> String:
	for r: Array in ROWS:
		if r[0] == key:
			return "%s: %s" % [r[1], value_text(key, _service.get_value(key))]
	return ""


## How a value reads on screen: On/Off, a percentage or a capitalised word.
static func value_text(key: StringName, value: Variant) -> String:
	if value is bool:
		return "On" if value else "Off"
	if String(key).ends_with("_volume"):
		return "%d%%" % int(value)
	return str(value).capitalize()


## Steps `key` one value forward (`dir` 1) or back (-1), wrapping enums and
## bools, clamping volumes.
func step(key: StringName, dir: int) -> void:
	var current: Variant = _service.get_value(key)
	var r: Vector2i = _schema.range_of(key)
	if r != Vector2i.ZERO:
		_service.set_value(key, clampi(int(current) + dir * SettingsSchema.VOLUME_STEP, r.x, r.y))
	else:
		var options: Array = _schema.options_of(key)
		var i: int = options.find(current)
		_service.set_value(key, options[posmod(i + dir, options.size())])
	_refresh()


## `true` = consumed. Cancel is Back; left/right step the focused row.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	match action:
		InputActions.CANCEL:
			close()
		InputActions.CONFIRM:
			InterimFocusNav.route_confirm(self)
		InputActions.NAV_UP:
			InterimFocusNav.route_direction(self, SIDE_TOP)
		InputActions.NAV_DOWN:
			InterimFocusNav.route_direction(self, SIDE_BOTTOM)
		InputActions.NAV_LEFT, InputActions.NAV_RIGHT:
			var key: StringName = _focused_key()
			if key != &"":
				step(key, -1 if action == InputActions.NAV_LEFT else 1)
	return true


## Writes the file and emits `closed`.
func close() -> void:
	if _service != null:
		_service.flush()
	closed.emit()


func _ready() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACKING
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 8)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", COLOR_BORDER)
	outer.add_child(title)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 4)
	outer.add_child(_box)
	for r: Array in ROWS:
		var key: StringName = r[0]
		var button := _add_button("")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(step.bind(key, 1))
		_row_by_key[key] = button
	_back = _add_button("Back")
	_back.pressed.connect(close)
	var hint := Label.new()
	hint.text = "Left / right to change"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", 13)
	hint.add_theme_color_override(&"font_color", COLOR_BORDER.darkened(0.3))
	outer.add_child(hint)
	for i: int in _buttons.size():
		var up: NodePath = _buttons[i].get_path_to(_buttons[i - 1]) if i > 0 else NodePath()
		var down: NodePath = _buttons[i].get_path_to(_buttons[i + 1]) if i < _buttons.size() - 1 else NodePath()
		_buttons[i].focus_neighbor_top = up
		_buttons[i].focus_neighbor_bottom = down
	_refresh()


func _add_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	_box.add_child(button)
	_buttons.append(button)
	return button


func _refresh() -> void:
	for key: StringName in _row_by_key:
		_row_by_key[key].text = row_text(key)


func _focused_key() -> StringName:
	var vp: Viewport = get_viewport()
	var owner: Control = vp.gui_get_focus_owner() if vp != null else null
	for key: StringName in _row_by_key:
		if _row_by_key[key] == owner:
			return key
	return &""
