## Story 023, AC-21: Dialogue never opens over the Menu (and is not queued);
## the Menu opens over Dialogue; each overlay kind opens only over the modes
## in the GDD Overlays table (`REJECTED_INVALID_PAIR` otherwise, ruling
## 2026-10-23). Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-023-dialogue-menu-precedence.md`.
extends GdUnitTestSuite


func test_dialogue_rejected_over_menu() -> void:
	# Arrange: OVERWORLD with the Menu open.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	assert_int(machine.open_overlay(GameStateMachine.OverlayKind.MENU)).is_equal(
			GameStateMachine.RequestResult.OK)
	var probe_before: Dictionary = machine.get_debug_state()

	# Act
	var result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.DIALOGUE)

	# Assert: blocked, nothing changed, and closing the Menu opens nothing.
	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_OVERLAY_BLOCKS)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())).is_true()
	recorder.clear()
	assert_int(machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)
	assert_array(machine.overlay_stack).is_empty()
	assert_int(recorder.index_of(&"overlay_opened")).is_equal(-1)


func test_menu_over_dialogue_ok() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	assert_int(machine.open_overlay(GameStateMachine.OverlayKind.DIALOGUE)).is_equal(
			GameStateMachine.RequestResult.OK)

	var result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)

	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	var expected: Array[GameStateMachine.OverlayKind] = [
		GameStateMachine.OverlayKind.DIALOGUE, GameStateMachine.OverlayKind.MENU]
	assert_array(machine.overlay_stack).is_equal(expected)


## Edge cases: (mode, overlay kind) pairs the Overlays table does not allow.
const _NOT_ALLOWED_CASES: Array = [
	[GameStateMachine.Mode.BATTLE, GameStateMachine.OverlayKind.DIALOGUE],
	[GameStateMachine.Mode.TITLE, GameStateMachine.OverlayKind.DIALOGUE],
	[GameStateMachine.Mode.BOOT, GameStateMachine.OverlayKind.DIALOGUE],
	[GameStateMachine.Mode.OVERWORLD, GameStateMachine.OverlayKind.DEFEAT_PROMPT],
]


func test_overlay_not_allowed_over_mode_rejected(mode: int, kind: int,
		test_parameters := _NOT_ALLOWED_CASES) -> void:
	var machine: GameStateMachine = _machine_in(mode)
	assert_int(machine.current_mode).is_equal(mode)
	var probe_before: Dictionary = machine.get_debug_state()

	var result: GameStateMachine.RequestResult = machine.open_overlay(kind)

	assert_int(result).is_equal(GameStateMachine.RequestResult.REJECTED_INVALID_PAIR)
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())).is_true()


func _machine_in(mode: int) -> GameStateMachine:
	if mode == GameStateMachine.Mode.BOOT or mode == GameStateMachine.Mode.TITLE:
		var machine := GameStateMachine.new(StubSceneLoader.new(), StubTransitionPresenter.new(),
				GameStateFixtures.make_transition_config(), GameStateFixtures.make_ready_catalog(),
				QuitSpy.new().as_callable(), SpyGameStateLog.new())
		if mode == GameStateMachine.Mode.TITLE:
			machine.tick(0.0)
			_run_to_idle(machine)
		return machine
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine_ow: GameStateMachine = env["machine"]
	if mode == GameStateMachine.Mode.BATTLE:
		var loader: StubSceneLoader = env["loader"]
		var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
		battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
		loader.current_mode_node_value = battle_stub
		machine_ow.request_transition(GameStateMachine.Mode.BATTLE,
				GameStateFixtures.valid_battle_entry())
		_run_to_idle(machine_ow)
	return machine_ow


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).is_true()
