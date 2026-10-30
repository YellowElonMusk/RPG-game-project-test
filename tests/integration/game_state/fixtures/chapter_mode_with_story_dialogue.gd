## Story 036 (QA-pinned stub dialogue requester): stands in for `ChapterMode`
## on a Victory that triggers story dialogue. There is no `ChapterMode`
## class_name in the project yet (the chapter runs in the OVERWORLD row), so
## this extends the `StubOverworldMode` GameMode double, the same base every
## game_state test uses for the Overworld slot.
## `on_thawed` calls `super.on_thawed(...)`, then tries to open the Dialogue
## overlay. That runs inside `mode_entered(OVERWORLD)`, before
## `transition_finished`, so the machine is busy and rejects it
## (ADR-0002 §4). The requester then retries once on
## `transition_finished(OVERWORLD)`. The future Dialogue epic replaces this.
class_name ChapterModeWithStoryDialogue extends StubOverworldMode

## Result of the attempt made inside `on_thawed`; -1 until it runs.
var thaw_attempt_result: int = -1
## Result of the retry on `transition_finished(OVERWORLD)`; -1 until it runs.
var retry_result: int = -1

var _machine: GameStateMachine = null


## Keeps the machine so `on_thawed` can request the overlay.
func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine


## Victory only: story dialogue is a Victory consequence. Any other result
## behaves exactly like the base double.
func on_thawed(encounter_id: String, result: GameStateMachine.BattleResult) -> void:
	super.on_thawed(encounter_id, result)
	if _machine == null or result != GameStateMachine.BattleResult.VICTORY:
		return
	thaw_attempt_result = _machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)
	if thaw_attempt_result == GameStateMachine.RequestResult.OK:
		return
	_machine.transition_finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)


func _on_transition_finished(to: GameStateMachine.Mode) -> void:
	if to != GameStateMachine.Mode.OVERWORLD:
		return
	retry_result = _machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)
