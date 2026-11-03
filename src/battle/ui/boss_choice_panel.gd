## The post-boss choice (narrative bible §6.2, established by the user
## 2026-10-29; game concept MVP item 6): after an alien boss is beaten, and
## only then, the player picks "Finish him off" (human street cred) or "Let
## him go" (alien points). Then a result line and Continue. Behind the menu
## input guard, so mashing Confirm through the results screen never picks.
##
## Usage example:
## [codeblock]
## var panel := BossChoicePanel.new(func() -> float: return mode_time, 0.15)
## add_child(panel)
## panel.chosen.connect(_on_choice)      # true = finished
## panel.continued.connect(_on_done)
## panel.ask("Supervisor")
## [/codeblock]
class_name BossChoicePanel
extends Control

## The player chose: `finished` true = "Finish him off".
signal chosen(finished: bool)
## Continue after the result line (once per `ask()`).
signal continued()

const COLOR_BACKING: Color = Color("#2a2d40")
const COLOR_BORDER: Color = Color("#f2ead8")
const COLOR_GOO: Color = Color("#b06ce0")

## The input guard; re-opened when the result line replaces the choice.
var guard: MenuGuard = null

var _title: Label = null
var _result: Label = null
var _finish: Button = null
var _spare: Button = null
var _continue: Button = null
var _boss_name: String = ""
var _phase: int = 0  # 0 hidden, 1 choosing, 2 result


func _init(clock: Callable, guard_seconds: float) -> void:
	name = "BossChoicePanel"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	guard = MenuGuard.new(clock, func() -> Array[StringName]: return [], guard_seconds)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The upper band, over the sky: the boss stands centre stage, and a
	# "Finish him off" has to be seen turning him into goo.
	center.anchor_top = 0.1
	center.anchor_bottom = 0.4
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACKING
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	_title = _label(22)
	box.add_child(_title)
	_result = _label(17)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(300, 0)
	box.add_child(_result)
	_finish = _button("Finish him off", true)
	_spare = _button("Let him go", false)
	box.add_child(_finish)
	box.add_child(_spare)
	_finish.focus_neighbor_bottom = _finish.get_path_to(_spare)
	_spare.focus_neighbor_top = _spare.get_path_to(_finish)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.focus_mode = Control.FOCUS_ALL
	_continue.pressed.connect(_on_continue)
	box.add_child(_continue)


## Asks the choice about `boss_name`.
func ask(boss_name: String) -> void:
	_boss_name = boss_name
	_phase = 1
	_title.text = "The %s is beaten." % boss_name
	_result.visible = false
	_finish.visible = true
	_spare.visible = true
	_continue.visible = false
	visible = true
	guard.open(self)
	if _finish.is_inside_tree():
		_finish.grab_focus()


## The text of the result line (tests).
func result_text() -> String:
	return _result.text


## The two choice buttons and Continue (tests).
func finish_button() -> Button:
	return _finish


func spare_button() -> Button:
	return _spare


func continue_button() -> Button:
	return _continue


## `true` = consumed. Guard first; Confirm presses the focused button; up and
## down move between the two choices.
func handle_action(action: StringName, pressed: bool) -> bool:
	if not visible:
		return false
	if guard.filter(action, pressed) != MenuGuard.Verdict.PASS or not pressed:
		return true
	match action:
		InputActions.CONFIRM:
			InterimFocusNav.route_confirm(self)
		InputActions.NAV_UP:
			if _phase == 1:
				_finish.grab_focus()
		InputActions.NAV_DOWN:
			if _phase == 1:
				_spare.grab_focus()
	return true


func _process(_delta: float) -> void:
	if visible:
		guard.tick()


func _on_choice(finished: bool) -> void:
	if _phase != 1:
		return
	_phase = 2
	_finish.visible = false
	_spare.visible = false
	_result.visible = true
	_result.text = ("The %s bursts into a pile of purple goo.\nHuman street cred +1" if finished
			else "The %s scuttles off, muttering about paperwork.\nAlien points +1") % _boss_name
	_continue.visible = true
	guard.open(self)
	if _continue.is_inside_tree():
		_continue.grab_focus()
	chosen.emit(finished)


func _on_continue() -> void:
	if _phase != 2:
		return
	_phase = 0
	visible = false
	continued.emit()


func _button(text: String, finished: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(_on_choice.bind(finished))
	return b


static func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", COLOR_BORDER)
	return l
