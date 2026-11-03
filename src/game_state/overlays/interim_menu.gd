## INTERIM Menu overlay (ADR-0002 §5-§6; story 029's `MenuPayload`): a
## centred navy/cream window listing exactly the payload's entries, over a
## light dim. "Resume" closes the Menu, and "Quit to Title" requests Title
## (legal while the Menu is on top). Party, Codex and Settings are shown
## disabled until their screens exist. Cancel closes the Menu; the menu key
## does too, handled by the machine.
##
## It exists because the overlay had no scene at all: focus loss or the menu
## key pushed a MENU entry with nothing behind it, the mode clock froze, and
## every press was dropped, so the game soft-locked. Stands in for the UI
## Framework's Menu screen (ADR-0008), with the same INTERIM focus handling
## as `DefeatPrompt`.
class_name InterimMenu extends GameOverlay

## Entry id -> [label, enabled].
const ENTRIES: Dictionary = {
	&"pause": ["Resume", true],
	&"party": ["Party (coming soon)", false],
	&"codex": ["Codex (coming soon)", false],
	&"settings": ["Settings (coming soon)", false],
	&"quit": ["Quit to Title", true],
}
const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
## The world dim behind the window (the Menu backdrop source, ADR-0005 §12).
const DIM: Color = Color(0.0, 0.0, 0.0, 0.35)

var _machine: GameStateMachine = null
var _entries: Array[StringName] = []
var _buttons: Array[Button] = []
var _button_by_entry: Dictionary[StringName, Button] = {}


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	var menu_payload := payload as MenuPayload
	if menu_payload != null:
		_entries.assign(menu_payload.entries)
	else:
		_entries.assign([&"pause", &"quit"])
	_build()


## The entry ids shown, in order (tests).
func entries() -> Array[StringName]:
	return _entries


## The button for `entry`, or null (tests).
func button_for(entry: StringName) -> Button:
	return _button_by_entry.get(entry, null)


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
	panel.custom_minimum_size = Vector2(260, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", COLOR_BORDER)
	box.add_child(title)
	# A Menu without "pause" (Battle: settings, quit) still opens on Resume,
	# never on Quit to Title: the safe default focus (GDD rule 9). Resume is
	# not a payload entry, so `entries()` stays the exact AC-31 list.
	var shown: Array[StringName] = _entries.duplicate()
	if not shown.has(&"pause"):
		shown.push_front(&"pause")
	for entry: StringName in shown:
		var spec: Array = ENTRIES.get(entry, [String(entry).capitalize(), false])
		var button := Button.new()
		button.text = spec[0]
		button.disabled = not bool(spec[1])
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_entry.bind(entry))
		box.add_child(button)
		_buttons.append(button)
		_button_by_entry[entry] = button
	for i: int in _buttons.size():
		var up: NodePath = _buttons[i].get_path_to(_buttons[i - 1]) if i > 0 else NodePath()
		var down: NodePath = _buttons[i].get_path_to(_buttons[i + 1]) if i < _buttons.size() - 1 else NodePath()
		_buttons[i].focus_neighbor_top = up
		_buttons[i].focus_neighbor_bottom = down


## INTERIM (as `DefeatPrompt._ready()`): focuses the first enabled entry.
func _ready() -> void:
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return


## `true` = consumed. Cancel closes the Menu; Confirm and directions route
## through `InterimFocusNav`; everything else is consumed and ignored.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed:
		return true
	match action:
		InputActions.CANCEL:
			_close()
		InputActions.CONFIRM:
			InterimFocusNav.route_confirm(self)
		InputActions.NAV_UP:
			InterimFocusNav.route_direction(self, SIDE_TOP)
		InputActions.NAV_DOWN:
			InterimFocusNav.route_direction(self, SIDE_BOTTOM)
	return true


func _on_entry(entry: StringName) -> void:
	match entry:
		&"pause":
			_close()
		&"quit":
			if _machine != null:
				_machine.request_transition(GameStateMachine.Mode.TITLE)


func _close() -> void:
	if _machine != null:
		_machine.close_overlay()
