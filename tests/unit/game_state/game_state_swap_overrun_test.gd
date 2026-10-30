## Story 007, AC-26 (slow-swap half): a slow swap makes IN wait, and one
## `swap_over_budget` warning is logged when the swap reaches DONE. Written to
## the QA Test Cases in
## `production/epics/game-state-scene-flow/story-007-slow-swap-waits-and-warns.md`.
## The allowance is `budget - t_out - t_in`, computed from the config fixture.
extends GdUnitTestSuite

const _STEP: float = 0.05

## Case 0: the default fixture row; case 1: a non-default `battle_wipe` row
## (t_out, t_in, budget), per the build brief's formula rule.
const _CONFIG_CASES: Array = [
	[[]],
	[[0.2, 0.1, 0.5]],
]


func test_in_waits_and_warning_logged(row: Array, test_parameters := _CONFIG_CASES) -> void:
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var presenter: StubTransitionPresenter = env["presenter"]
	var cfg: TransitionConfig = env["config"]
	var game_log: SpyGameStateLog = env["log"]
	if not row.is_empty():
		GameStateFixtures.add_row(cfg, &"battle_wipe", row[0], row[1], row[2])
	var t_out: float = cfg.t_out[&"battle_wipe"]
	var allowance: float = cfg.transition_budget[&"battle_wipe"] - t_out - cfg.t_in[&"battle_wipe"]
	var pending_ticks: int = ceili((allowance + 0.2) / _STEP)
	var scripted: Array[SceneLoader.SwapStatus] = []
	for i in range(pending_ticks):
		scripted.append(SceneLoader.SwapStatus.PENDING)
	scripted.append(SceneLoader.SwapStatus.DONE)
	loader.script_results(scripted)
	game_log.entries.clear()
	recorder.clear()
	var polls_before: int = loader.poll_count

	assert_int(machine.request_transition(GameStateMachine.Mode.BATTLE,
			GameStateFixtures.valid_battle_entry())).is_equal(GameStateMachine.RequestResult.OK)
	machine.tick(t_out)   # ends OUT
	var play_in_before: int = presenter.play_in_calls.size()
	for i in range(pending_ticks):
		machine.tick(_STEP)
		assert_int(machine.phase).override_failure_message("tick %d" % i).is_equal(
				GameStateMachine.Phase.SWAP)
		assert_int(presenter.play_in_calls.size()).is_equal(play_in_before)
	assert_int(_count(game_log, &"swap_over_budget")).override_failure_message(
			"warned before DONE").is_equal(0)
	machine.tick(_STEP)   # DONE
	_run_to_idle(machine)

	var warnings: Array = game_log.entries.filter(
			func(entry: Dictionary) -> bool: return entry["code"] == &"swap_over_budget")
	assert_int(warnings.size()).is_equal(1)
	assert_str(String(warnings[0]["level"])).is_equal("warning")
	assert_str(String(warnings[0]["context"]["type"])).is_equal("battle_wipe")
	assert_float(warnings[0]["context"]["t_swap"]).is_equal_approx((pending_ticks + 1) * _STEP, 1e-6)
	assert_int(loader.poll_count - polls_before).is_equal(pending_ticks + 1)
	assert_int(recorder.index_of(&"transition_finished")).is_greater(recorder.index_of(&"play_in"))
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)


func test_swap_equal_to_allowance_not_warned() -> void:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var cfg: TransitionConfig = env["config"]
	var game_log: SpyGameStateLog = env["log"]
	var t_out: float = cfg.t_out[&"battle_wipe"]
	var allowance: float = cfg.transition_budget[&"battle_wipe"] - t_out - cfg.t_in[&"battle_wipe"]
	game_log.entries.clear()

	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	machine.tick(t_out)
	machine.tick(allowance)   # one poll, DONE: t_swap == allowance exactly
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IN)
	_run_to_idle(machine)

	assert_float(machine.last_t_swap).is_equal(allowance)
	assert_int(_count(game_log, &"swap_over_budget")).is_equal(0)


func test_retry_flash_overrun_still_warned() -> void:
	# Retry loads nothing (t_swap == 0), so an overrun there means the budget
	# leaves a negative allowance: still warned, never skipped.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	var game_log: SpyGameStateLog = env["log"]
	var t_phase: float = cfg.t_out[&"retry_flash"]
	GameStateFixtures.add_row(cfg, &"retry_flash", t_phase, t_phase, t_phase)
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub
	machine.request_transition(GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	_run_to_idle(machine)
	machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
	game_log.entries.clear()

	assert_int(machine.choose_retry()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var warnings: Array = game_log.entries.filter(
			func(entry: Dictionary) -> bool: return entry["code"] == &"swap_over_budget")
	assert_int(warnings.size()).is_equal(1)
	assert_str(String(warnings[0]["context"]["type"])).is_equal("retry_flash")
	assert_object(battle_stub.restored_snapshot).is_not_null()


func _count(game_log: SpyGameStateLog, code: StringName) -> int:
	return game_log.entries.filter(func(entry: Dictionary) -> bool: return entry["code"] == code).size()


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).is_true()
