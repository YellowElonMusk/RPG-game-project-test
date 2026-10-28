## Story 009, AC-7: of two transition requests issued in the same frame (no
## tick() between them), the first is accepted and leaves IDLE synchronously
## inside the accepting call; the second sees a busy machine and is rejected,
## never touching state. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-009-same-frame-requests-first-wins.md`
## -- no new cases invented.
extends GdUnitTestSuite

## Three same-frame pairs: which request goes first, what the second call is,
## and the winning mode once the accepted transition runs to IDLE. Covers the
## main scenario (BATTLE then CAMP), the QA's reversed-order edge case (CAMP
## then BATTLE) and its open_overlay(MENU)-as-second-call edge case.
const _SAME_FRAME_CASES: Array = [
	["transition_battle", "transition_camp", "BATTLE"],
	["transition_camp", "transition_battle", "CAMP"],
	["transition_battle", "open_overlay_menu", "BATTLE"],
]


func test_first_accepted_second_rejected(first_action: String, second_action: String,
		expected_winner: String, test_parameters := _SAME_FRAME_CASES) -> void:
	# Arrange: Overworld, IDLE, recorder cleared of the setup's own events.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	recorder.clear()
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)

	# Act: the first request, with no tick() before the second.
	var first_result: GameStateMachine.RequestResult = _issue_action(machine, first_action)
	assert_int(first_result).is_equal(GameStateMachine.RequestResult.OK)

	# Assert: the machine left IDLE synchronously inside the accepting call,
	# and transition_started is already recorded before the second call fires.
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.OUT)
	assert_int(recorder.index_of(&"transition_started")).is_equal(0)
	var events_after_first: int = recorder.events.size()

	# Act: the second request, same frame -- no tick() between the two calls.
	var second_result: GameStateMachine.RequestResult = _issue_action(machine, second_action)

	# Assert: rejected busy, no new recorded event, and the second request's
	# target/kind never appears in any recorded signal argument.
	assert_int(second_result).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)
	assert_int(recorder.events.size()).is_equal(events_after_first)
	assert_bool(_value_recorded(recorder, _forbidden_value(second_action))) \
			.override_failure_message("the rejected request's target/kind was recorded anyway").is_false()

	# Assert: running the accepted transition to IDLE lands on the expected winner.
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(_mode_from_name(expected_winner))


## Issues one named action against `machine`, with a valid payload where one
## is required.
func _issue_action(machine: GameStateMachine, action: String) -> GameStateMachine.RequestResult:
	match action:
		"transition_battle":
			return machine.request_transition(
					GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
		"transition_camp":
			return machine.request_transition(GameStateMachine.Mode.CAMP, null)
		"open_overlay_menu":
			return machine.open_overlay(GameStateMachine.OverlayKind.MENU, null)
		_:
			assert_bool(false).override_failure_message("unknown action: %s" % action).is_true()
			return GameStateMachine.RequestResult.REJECTED_INVALID_PAIR


## The Mode or OverlayKind value `action` would have introduced had it been
## accepted -- the value the test asserts never appears in any recorded
## signal argument once the request is rejected.
func _forbidden_value(action: String) -> int:
	match action:
		"transition_battle":
			return GameStateMachine.Mode.BATTLE
		"transition_camp":
			return GameStateMachine.Mode.CAMP
		"open_overlay_menu":
			return GameStateMachine.OverlayKind.MENU
		_:
			assert_bool(false).override_failure_message("unknown action: %s" % action).is_true()
			return -1


func _mode_from_name(mode_name: String) -> GameStateMachine.Mode:
	match mode_name:
		"BATTLE":
			return GameStateMachine.Mode.BATTLE
		"CAMP":
			return GameStateMachine.Mode.CAMP
		_:
			assert_bool(false).override_failure_message("unknown mode name: %s" % mode_name).is_true()
			return GameStateMachine.Mode.OVERWORLD


## True if `value` appears anywhere inside any recorded event's args array.
func _value_recorded(recorder: SequenceRecorder, value: int) -> bool:
	for event in recorder.events:
		for arg in event["args"]:
			if int(arg) == value:
				return true
	return false


## Bounded 1/60s-tick loop until the transition reaches IDLE.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
