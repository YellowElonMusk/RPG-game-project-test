## The end credits (Faction Reputation & Endings, 2026-11-04): a navy screen
## where the ending's heading, its epilogue and the `CreditsRoll` lines
## scroll up from below. When the last line has scrolled off, or the
## player presses confirm or cancel after the skip guard, it emits
## `finished` once. Title shows it as a child panel when entered with a
## `CreditsPayload`, forwarding its actions here while it is open.
##
## Usage example:
## [codeblock]
## var credits := CreditsPanel.new()
## credits.setup(payload.ending, CreditsRoll.load_default())
## credits.finished.connect(func() -> void: credits.queue_free())
## add_child(credits)
## [/codeblock]
class_name CreditsPanel
extends Control

## The roll ended or was skipped. Emitted once.
signal finished

const COLOR_BACKING: Color = Color("#1b2440")
const COLOR_TEXT: Color = Color("#f4ead2")

var _roll: CreditsRoll = null
var _text: Label = null
var _elapsed: float = 0.0
var _done: bool = false


func setup(ending: EndingData, roll: CreditsRoll) -> void:
	_roll = roll if roll != null else CreditsRoll.new()
	_build(ending)


## The whole text being rolled (tests).
func text() -> String:
	return _text.text if _text != null else ""


## `true` once `finished` has been emitted.
func is_done() -> bool:
	return _done


func _build(ending: EndingData) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = COLOR_BACKING
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var lines: PackedStringArray = PackedStringArray()
	if ending != null:
		lines.append("Ending: %s" % ending.title)
		if not ending.epilogue.is_empty():
			lines.append("")
			lines.append(ending.epilogue)
		lines.append("")
		lines.append("")
	lines.append_array(_roll.lines)
	_text = Label.new()
	_text.text = "\n".join(lines)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override(&"font_size", 22)
	_text.add_theme_color_override(&"font_color", COLOR_TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	_place(0.0)


func _process(delta: float) -> void:
	advance(delta)


## Scrolls by `delta` seconds; ends once the text has left the top.
func advance(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_place(_elapsed)
	if _text.position.y + _text.size.y < 0.0:
		_finish()


## Confirm or cancel skips once the guard has passed; every action is
## consumed while the credits roll.
func handle_action(action: StringName, pressed: bool) -> bool:
	if pressed and (action == InputActions.CONFIRM or action == InputActions.CANCEL) \
			and _elapsed >= _roll.skip_guard_s:
		_finish()
	return true


func _place(t: float) -> void:
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var width: float = minf(view.x - 64.0, 900.0)
	_text.size = Vector2(width, 0.0)
	_text.reset_size()
	_text.size.x = width
	_text.position = Vector2((view.x - width) / 2.0, view.y - t * _roll.scroll_px_per_s)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
