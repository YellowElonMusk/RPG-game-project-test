## Interim Dialogue overlay: one line in a box at the bottom of the screen,
## closed by `confirm` (stories 071, 091). Every action is consumed while
## it is open (GDD Overworld rule 3, Lockouts). A `confirm` within
## `input_guard_s` of opening is refused (P2 Guarded Menu), and a confirm
## still held from the previous screen sends no new press, so neither skips
## the line. Replaced by the Dialogue, Banter & Quests system (#17).
class_name InterimLineDialogue extends GameOverlay

var _machine: GameStateMachine = null
var _guard_left: float = 0.0
## The shown line (tests).
var text: String = ""


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	var line: DialogueLinePayload = payload as DialogueLinePayload
	if line == null:
		line = DialogueLinePayload.new()
	text = line.text if line.speaker.is_empty() else "%s: %s" % [line.speaker, line.text]
	_guard_left = line.input_guard_s
	(%Line as Label).text = text


func _process(delta: float) -> void:
	_guard_left = maxf(0.0, _guard_left - delta)


## Advances the guard clock by hand (tests run without frames).
func advance_guard(seconds: float) -> void:
	_guard_left = maxf(0.0, _guard_left - seconds)


func handle_action(action: StringName, pressed: bool) -> bool:
	if action == InputActions.CONFIRM and pressed and _guard_left <= 0.0 and _machine != null:
		_machine.close_overlay()
	return true
