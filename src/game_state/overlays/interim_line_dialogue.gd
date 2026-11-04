## Dialogue overlay (stories 071, 091; Dialogue system, systems index #17):
## a conversation box at the bottom of the screen with the speaker's name,
## the line revealed letter by letter, and the line's choices.
##
## `confirm` while a line is still revealing shows it whole; `confirm` on a
## whole line goes to the next one, and on the last line closes the box.
## Choices are picked with up/down and `confirm` (or a click). Every action
## is consumed while the box is open (GDD Overworld rule 3, Lockouts). A
## `confirm` within `input_guard_s` of opening, or of the choices appearing,
## is refused (P2 Guarded Menu), so a mashed press never skips a line or
## picks an answer.
class_name InterimLineDialogue extends GameOverlay

## Letters revealed per second; 0 or less shows each line whole at once.
@export var chars_per_s: float = 45.0

var _machine: GameStateMachine = null
var _guard_s: float = 0.15
var _guard_left: float = 0.0
var _run: ConversationRunner = null
var _revealed: float = 0.0
var _choice_index: int = 0
var _choice_buttons: Array[Button] = []
var _choices_shown: bool = false
## The shown line as "Speaker: text" (or the bare text without a speaker).
## Tests read it.
var text: String = ""
## Every line shown, in order, as `text` (tests).
var shown_lines: PackedStringArray = PackedStringArray()


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	var line: DialogueLinePayload = payload as DialogueLinePayload
	if line == null:
		line = DialogueLinePayload.new()
	_guard_s = line.input_guard_s
	_guard_left = _guard_s
	_run = ConversationRunner.new(line.to_conversation(), line.has_flag, line.set_flag, line.speaker_name)
	# ADR-0013 §1: a code-set control is translated exactly once. The lines
	# arrive already localized (story 122), so the labels must not look them
	# up again; set before the first text assignment.
	for label: Control in [%Line, %Speaker]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_show_line()


func _process(delta: float) -> void:
	_tick(delta)


## Advances the overlay's clocks by hand (tests run without frames): the
## confirm guard and the letter reveal.
func advance_guard(seconds: float) -> void:
	_tick(seconds)


## Shows the current line whole (tests; the same as a confirm mid-reveal).
func reveal_all() -> void:
	_revealed = float(_line_length())
	_apply_reveal()


## Plays the rest of the conversation as fast `confirm`s would, picking the
## first choice at every question, until the box closes (tests).
func skip_to_end() -> void:
	var presses: int = 0
	while _run != null and not _run.is_finished() and presses < ConversationRunner.MAX_STEPS:
		_tick(_guard_s + 1.0)
		reveal_all()
		_guard_left = 0.0
		_confirm()
		presses += 1


## `true` while the current line is still revealing.
func is_revealing() -> bool:
	return chars_per_s > 0.0 and _revealed < float(_line_length())


## The current line's choice labels (empty for none, or while revealing).
func choice_labels() -> PackedStringArray:
	var out := PackedStringArray()
	if _choices_shown:
		for choice: DialogueChoice in _run.choices():
			out.append(choice.label)
	return out


## The highlighted choice.
func choice_index() -> int:
	return _choice_index


func handle_action(action: StringName, pressed: bool) -> bool:
	if not pressed or _run == null:
		return true
	match action:
		InputActions.CONFIRM:
			_confirm()
		InputActions.NAV_UP, InputActions.MOVE_UP:
			_move_choice(-1)
		InputActions.NAV_DOWN, InputActions.MOVE_DOWN:
			_move_choice(1)
	return true


func _confirm() -> void:
	if _guard_left > 0.0:
		return
	if is_revealing():
		reveal_all()
		return
	if _choices_shown:
		_pick(_choice_index)
		return
	_run.advance()
	_after_step()


func _pick(i: int) -> void:
	if not _choices_shown or _guard_left > 0.0:
		return
	_run.choose(i)
	_after_step()


func _after_step() -> void:
	if _run.is_finished():
		if _machine != null:
			_machine.close_overlay()
		return
	_show_line()


func _move_choice(step: int) -> void:
	if not _choices_shown or _choice_buttons.is_empty():
		return
	_choice_index = clampi(_choice_index + step, 0, _choice_buttons.size() - 1)
	_highlight()


func _tick(seconds: float) -> void:
	_guard_left = maxf(0.0, _guard_left - seconds)
	if _run == null or not is_revealing():
		return
	_revealed = minf(float(_line_length()), _revealed + seconds * chars_per_s)
	_apply_reveal()


func _show_line() -> void:
	var who: String = _run.speaker()
	text = _run.text() if who.is_empty() else "%s: %s" % [who, _run.text()]
	shown_lines.append(text)
	(%Speaker as Label).text = who
	(%Speaker as Label).visible = not who.is_empty()
	(%Line as Label).text = _run.text()
	_revealed = 0.0 if chars_per_s > 0.0 else float(_line_length())
	_clear_choices()
	_apply_reveal()


func _apply_reveal() -> void:
	var whole: bool = not is_revealing()
	(%Line as Label).visible_characters = -1 if whole else int(_revealed)
	(%More as Label).visible = whole and _run.choices().is_empty()
	if whole and not _choices_shown and not _run.choices().is_empty():
		_show_choices()


func _show_choices() -> void:
	_choices_shown = true
	_choice_index = 0
	_guard_left = _guard_s
	var box: VBoxContainer = %Choices
	var options: Array[DialogueChoice] = _run.choices()
	for i: int in options.size():
		var button := Button.new()
		button.text = options[i].label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_pick.bind(i))
		box.add_child(button)
		_choice_buttons.append(button)
	box.visible = true
	_highlight()


func _clear_choices() -> void:
	_choices_shown = false
	for button: Button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()
	(%Choices as Control).visible = false


func _highlight() -> void:
	for i: int in _choice_buttons.size():
		var label: String = _run.choices()[i].label
		_choice_buttons[i].text = ("▶ " if i == _choice_index else "    ") + label
	if is_inside_tree() and _choice_index < _choice_buttons.size():
		_choice_buttons[_choice_index].grab_focus()


func _line_length() -> int:
	return _run.text().length() if _run != null else 0
