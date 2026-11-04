## A one-time tutorial card before round 1 (Onboarding, systems index #21):
## a short title in the card's colour, two or three lines, and OK. Cards
## queue; Confirm (after the menu input guard) shows the next, and the last
## emits `finished`. `BattleMode` routes every action here while it is up.
##
## Usage example:
## [codeblock]
## var card := TutorialCard.new(func() -> float: return mode_time, 0.25)
## add_child(card)
## card.finished.connect(_open_gate)
## card.show_cards([["How to fight", "Pick a command...", Color.WHITE]])
## [/codeblock]
class_name TutorialCard
extends Control

## The last card was dismissed (once per `show_cards()`).
signal finished()

const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
const DIM: Color = Color(0.0, 0.0, 0.0, 0.45)

## The input guard (a mashed Confirm from the previous screen never
## dismisses a card unread). Tests read it.
var guard: MenuGuard = null

var _queue: Array = []
var _title: Label = null
var _body: Label = null
var _ok: Button = null
var _style: StyleBoxFlat = null


func _init(clock: Callable, guard_seconds: float) -> void:
	name = "TutorialCard"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	guard = MenuGuard.new(clock, func() -> Array[StringName]: return [], guard_seconds)
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
	_style = StyleBoxFlat.new()
	_style.bg_color = COLOR_BACKING
	_style.border_color = COLOR_BORDER
	_style.set_border_width_all(3)
	_style.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", _style)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	_title = _label(26)
	box.add_child(_title)
	_body = _label(20)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(576, 0)
	box.add_child(_body)
	_ok = Button.new()
	_ok.text = "OK"
	_ok.focus_mode = Control.FOCUS_ALL
	_ok.pressed.connect(_advance)
	box.add_child(_ok)


## Shows `cards` in order, each `[title, body, colour]`. An empty list
## emits `finished` at once.
func show_cards(cards: Array) -> void:
	_queue = cards.duplicate()
	if _queue.is_empty():
		visible = false
		finished.emit()
		return
	_show_next()


## The title shown now (tests, captures).
func title_text() -> String:
	return _title.text


## The body shown now (tests, captures).
func body_text() -> String:
	return _body.text


## Cards still queued after the one showing (tests).
func remaining() -> int:
	return _queue.size()


## `true` = consumed. Every action passes the guard first; Confirm then
## dismisses the card, everything else is consumed.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not visible:
		return false
	if guard.filter(action, pressed) != MenuGuard.Verdict.PASS:
		return true
	if pressed and action == InputActions.CONFIRM:
		_advance()
	return true


func _process(_delta: float) -> void:
	if visible:
		guard.tick()


func _show_next() -> void:
	var card: Array = _queue.pop_front()
	_title.text = String(card[0])
	_body.text = String(card[1])
	var colour: Color = card[2] if card.size() > 2 and card[2] is Color else COLOR_BORDER
	_title.add_theme_color_override(&"font_color", colour)
	_style.border_color = colour
	visible = true
	guard.open(self)
	if _ok.is_inside_tree():
		_ok.grab_focus()


func _advance() -> void:
	if not visible:
		return
	if _queue.is_empty():
		visible = false
		finished.emit()
	else:
		_show_next()


static func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", COLOR_BORDER)
	return l
