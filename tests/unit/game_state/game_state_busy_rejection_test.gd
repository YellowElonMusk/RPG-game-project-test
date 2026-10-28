## Story 008, AC-6: a running transition rejects any other transition or
## overlay request with REJECTED_BUSY, before any other check, and changes
## nothing. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-008-busy-transition-rejects-requests.md` --
## no new cases invented. `request_quit()` is deliberately not parametrized
## here: it is accepted during a transition (story 011), not rejected.
extends GdUnitTestSuite

## Every (phase, request) combination from the QA Test Cases: phase in
## {OUT, SWAP, IN}; request each of request_transition, the three overlay
## kinds opening, close_overlay, request_in_mode_fade and report_battle_outcome.
const _PHASE_REQUEST_PAIRS: Array = [
	["OUT", "request_transition"], ["OUT", "open_overlay_dialogue"], ["OUT", "open_overlay_menu"],
	["OUT", "open_overlay_defeat_prompt"], ["OUT", "close_overlay"], ["OUT", "request_in_mode_fade"],
	["OUT", "report_battle_outcome"],
	["SWAP", "request_transition"], ["SWAP", "open_overlay_dialogue"], ["SWAP", "open_overlay_menu"],
	["SWAP", "open_overlay_defeat_prompt"], ["SWAP", "close_overlay"], ["SWAP", "request_in_mode_fade"],
	["SWAP", "report_battle_outcome"],
	["IN", "request_transition"], ["IN", "open_overlay_dialogue"], ["IN", "open_overlay_menu"],
	["IN", "open_overlay_defeat_prompt"], ["IN", "close_overlay"], ["IN", "request_in_mode_fade"],
	["IN", "report_battle_outcome"],
]


func test_request_during_phase_rejected(phase_name: String, request_name: String,
		test_parameters := _PHASE_REQUEST_PAIRS) -> void:
	# Arrange: Overworld -> Battle in progress, stopped in the given phase.
	var state: Dictionary = _arrange_stopped_in_phase(phase_name)
	var machine: GameStateMachine = state["machine"]
	var recorder: SequenceRecorder = state["recorder"]
	var game_log: SpyGameStateLog = state["log"]
	var probe_before: Dictionary = machine.get_debug_state()
	var events_before: int = recorder.events.size()

	# Act
	var result: GameStateMachine.RequestResult = _issue_request(machine, request_name)

	# Assert: rejected busy, nothing changed, no extra signal recorded.
	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after a rejected request").is_true()
	assert_int(recorder.events.size()).is_equal(events_before)

	if request_name == "report_battle_outcome":
		var last_entry: Dictionary = game_log.entries[game_log.entries.size() - 1]
		assert_bool(last_entry["code"] == &"outcome_during_transition").override_failure_message(
				"expected outcome_during_transition logged, got %s" % [last_entry.get("code")]).is_true()

	# Edge case: the running transition still completes normally afterwards.
	_finish_transition_to_idle(machine)


## Drives the Overworld -> Battle transition and stops it in `phase_name`
## (`"OUT"`, `"SWAP"` or `"IN"`), with the stub loader held PENDING for SWAP.
func _arrange_stopped_in_phase(phase_name: String) -> Dictionary:
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	var game_log: SpyGameStateLog = env["log"]
	recorder.clear()
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)

	match phase_name:
		"OUT":
			pass   # already stopped at the start of OUT
		"SWAP":
			machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
			machine.tick(1.0 / 60.0)                   # poll #1: PENDING, held
		"IN":
			machine.tick(cfg.t_out[&"battle_wipe"])   # ends OUT -> SWAP
			machine.tick(1.0 / 60.0)                   # poll #1: PENDING, held
			machine.tick(1.0 / 60.0)                   # poll #2: DONE -> begins IN
		_:
			assert_bool(false).override_failure_message(
					"unknown phase_name: %s" % phase_name).is_true()

	var expected_phase: GameStateMachine.Phase = GameStateMachine.Phase.OUT
	if phase_name == "SWAP":
		expected_phase = GameStateMachine.Phase.SWAP
	elif phase_name == "IN":
		expected_phase = GameStateMachine.Phase.IN
	assert_int(machine.phase).is_equal(expected_phase)

	return {"machine": machine, "loader": loader, "cfg": cfg, "recorder": recorder, "log": game_log}


## Issues the one `request_name` under test against `machine`.
func _issue_request(machine: GameStateMachine, request_name: String) -> GameStateMachine.RequestResult:
	match request_name:
		"request_transition":
			return machine.request_transition(GameStateMachine.Mode.CAMP, null)
		"open_overlay_dialogue":
			return machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE, null)
		"open_overlay_menu":
			return machine.open_overlay(GameStateMachine.OverlayKind.MENU, null)
		"open_overlay_defeat_prompt":
			return machine.open_overlay(GameStateMachine.OverlayKind.DEFEAT_PROMPT, null)
		"close_overlay":
			return machine.close_overlay()
		"request_in_mode_fade":
			return machine.request_in_mode_fade(func() -> void: pass)
		"report_battle_outcome":
			return machine.report_battle_outcome(GameStateMachine.BattleResult.VICTORY)
		_:
			assert_bool(false).override_failure_message(
					"unknown request_name: %s" % request_name).is_true()
			return GameStateMachine.RequestResult.REJECTED_INVALID_PAIR


## Bounded 1/60s-tick loop (as in the signal-order test) until the transition
## that was stopped mid-flight reaches IDLE in BATTLE.
func _finish_transition_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
