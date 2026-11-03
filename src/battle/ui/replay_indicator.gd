## The replay indicator (ADR-0008 §12; GDD sprite-camera-presentation rule 9,
## UI requirements "Replay indicator"; interaction pattern P11): a small
## prompt shown for the whole replay, boss takeover included, in one of
## ADR-0006's three states. Active reads "[fast_forward] Speed up", latched
## reads "Speeding up · [Cancel] Stop", and passive reads a dimmed "Playing
## the turn". The glyphs come from the current device. Hidden outside a
## replay.
##
## A pointer press emits `indicator_clicked()`, which the Battle mode routes
## as `ReplayInputRouter.ACTION_INDICATOR_CLICK`, never as `confirm`. Not
## focusable. It sits in the bottom-right corner, below the enemy column and
## clear of the actors' band.
##
## Usage example:
## [codeblock]
## var indicator := ReplayIndicator.new()
## indicator.glyphs = PromptGlyphs.new(bindings)
## add_child(indicator)
## indicator.indicator_clicked.connect(_on_indicator_clicked)
## indicator.show_state(ReplayInputRouter.indicator_state(controller))
## [/codeblock]
class_name ReplayIndicator
extends PanelContainer

## A pointer press on the indicator (ADR-0006: its own event, never confirm).
signal indicator_clicked()

## Navy window and cream text (art bible "navy and cream windows"; the same
## values as `BattleHud.COLOR_PANEL` / `COLOR_TEXT`).
const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
const COLOR_TEXT: Color = Color("#f2ead8")
## The passive state's dimmed text: still at least 4.5:1 on the backing (AC-69).
const COLOR_TEXT_PASSIVE: Color = Color("#b4ad9f")
const FONT_SIZE: int = 16
## Inset from the screen's bottom-right corner, in px.
const MARGIN_PX: float = 16.0

## Labels for the prompts' actions; null shows the action names.
var glyphs: PromptGlyphs = null

var _label: Label = null
var _state: StringName = ReplayInputRouter.INDICATOR_HIDDEN


func _init() -> void:
	name = "ReplayIndicator"
	visible = false
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -MARGIN_PX
	offset_bottom = -MARGIN_PX
	offset_left = -MARGIN_PX
	offset_top = -MARGIN_PX
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACKING
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	add_theme_stylebox_override(&"panel", style)
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	add_child(_label)


## Shows `state` (a `ReplayInputRouter.INDICATOR_*` value); hidden for
## `INDICATOR_HIDDEN`. Cheap to call every frame: it only repaints on change.
func show_state(state: StringName) -> void:
	if state == _state:
		return
	_state = state
	visible = state != ReplayInputRouter.INDICATOR_HIDDEN
	if not visible:
		return
	_label.text = text_for(state)
	_label.add_theme_color_override(&"font_color",
			COLOR_TEXT_PASSIVE if state == ReplayInputRouter.INDICATOR_PASSIVE else COLOR_TEXT)
	_fit()


## The state shown now.
func current_state() -> StringName:
	return _state


## The prompt text for `state` with this indicator's glyphs.
func text_for(state: StringName) -> String:
	match state:
		ReplayInputRouter.INDICATOR_ACTIVE:
			return "[%s] Speed up" % _glyph(InputActions.FAST_FORWARD)
		ReplayInputRouter.INDICATOR_LATCHED:
			return "Speeding up · [%s] Stop" % _glyph(InputActions.CANCEL)
		ReplayInputRouter.INDICATOR_PASSIVE:
			return "Playing the turn"
	return ""


## The text colour `state` draws in (AC-69 measures it against the backing).
static func text_color_for(state: StringName) -> Color:
	return COLOR_TEXT_PASSIVE if state == ReplayInputRouter.INDICATOR_PASSIVE else COLOR_TEXT


## Repaints the current state's text, e.g. after the device or glyphs change.
func refresh_text() -> void:
	if visible:
		_label.text = text_for(_state)
		_fit()


## Keeps the bottom-right corner pinned and grows the box left and up to the
## text: `reset_size()` keeps the top-left instead, pushing a longer prompt
## off the right edge of the screen.
func _fit() -> void:
	var min_size: Vector2 = get_combined_minimum_size()
	offset_right = -MARGIN_PX
	offset_bottom = -MARGIN_PX
	offset_left = offset_right - min_size.x
	offset_top = offset_bottom - min_size.y


func _glyph(action: StringName) -> String:
	return glyphs.label(action) if glyphs != null else String(action)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		indicator_clicked.emit()
