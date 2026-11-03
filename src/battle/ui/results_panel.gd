## The Victory results screen (Stats & Damage GDD "Battle results": XP and
## money totals, F9; Sprite & Camera rule 9: it opens with focus on its one
## continue option and nothing submitted, behind the menu input guard). A
## centred navy/cream window over the settled Victory frame. Continue (a
## click, or Confirm routed by `BattleMode`) emits `continued` once.
##
## Usage example:
## [codeblock]
## var panel := ResultsPanel.new(func() -> float: return mode_time, 0.25)
## add_child(panel)
## panel.continued.connect(_on_results_done)
## panel.show_results(44, 30)
## [/codeblock]
class_name ResultsPanel
extends Control

## The player chose Continue (once per `show_results()`).
signal continued()

const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
const COLOR_GOLD: Color = Color("#f2c14e")

## The input guard (GDD rule 9: the results screen is one of the four
## guarded screens). Tests and `BattleMode` read it.
var guard: MenuGuard = null

var _xp_label: Label = null
var _money_label: Label = null
var _continue_button: Button = null
var _done: bool = false


func _init(clock: Callable, guard_seconds: float) -> void:
	name = "ResultsPanel"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	guard = MenuGuard.new(clock, func() -> Array[StringName]: return [], guard_seconds)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACKING
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	box.add_child(_label("Victory!", 26, COLOR_GOLD))
	_xp_label = _label("", 18, COLOR_BORDER)
	box.add_child(_xp_label)
	_money_label = _label("", 18, COLOR_BORDER)
	box.add_child(_money_label)
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.pressed.connect(_continue)
	box.add_child(_continue_button)


## Shows the totals, focuses Continue and starts the input guard.
func show_results(xp: int, money: int) -> void:
	_done = false
	_xp_label.text = "+%d XP" % xp
	_money_label.text = "+%d Money" % money
	visible = true
	guard.open(self)
	if _continue_button.is_inside_tree():
		_continue_button.grab_focus()


## The shown totals' text (tests and capture).
func totals_text() -> String:
	return "%s, %s" % [_xp_label.text, _money_label.text]


## The Continue button (tests).
func continue_button() -> Button:
	return _continue_button


## `true` = consumed. Every action passes the guard first; a guarded press is
## refused, a new Confirm after it continues, everything else is consumed.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not visible:
		return false
	if guard.filter(action, pressed) != MenuGuard.Verdict.PASS:
		return true
	if pressed and action == InputActions.CONFIRM:
		_continue()
	return true


func _process(_delta: float) -> void:
	if visible:
		guard.tick()


func _continue() -> void:
	if _done:
		return
	_done = true
	continued.emit()


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l
