## Story 006, AC-33: `transition_time` sums the three phases as measured from
## accumulated `tick()` deltas, and a budget below `t_out + t_in` is a
## load-time error naming the transition type. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-006-transition-time-and-budget-check.md` --
## no new cases invented.
extends GdUnitTestSuite


func test_transition_time_sums_phases() -> void:
	# Arrange: a machine already in OVERWORLD, its battle_wipe row overridden
	# to the GDD worked example (t_out 0.35, t_in 0.30); stub loader PENDING
	# on the first SWAP poll, DONE on the second.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	GameStateFixtures.add_row(cfg, &"battle_wipe", 0.35, 0.30)
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)

	# Act
	machine.tick(0.35)   # ends OUT
	machine.tick(0.10)   # SWAP poll #1: PENDING
	machine.tick(0.10)   # SWAP poll #2: DONE -- t_swap == 0.20
	machine.tick(0.30)   # ends IN

	# Assert
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_float(machine.last_transition_time).is_equal_approx(0.85, 1e-6)
	assert_float(machine.last_t_swap).is_equal_approx(0.20, 1e-6)


func test_transition_time_matches_within_one_frame_at_sixty_hz() -> void:
	# Edge case: OUT and IN are driven by 1/60s ticks instead of one
	# whole-phase tick each (SWAP is still driven by its two scripted polls --
	# its length comes from `poll_swap()`, not elapsed time, so there is
	# nothing to quantize there). The measured transition_time is still
	# within one frame of 0.85 (60 Hz quantization: overshoot on the final
	# tick of a phase is not carried).
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	GameStateFixtures.add_row(cfg, &"battle_wipe", 0.35, 0.30)
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])

	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)

	const FRAME: float = 1.0 / 60.0
	var ticks: int = 0
	while machine.phase == GameStateMachine.Phase.OUT and ticks < 600:
		machine.tick(FRAME)
		ticks += 1
	machine.tick(0.10)   # SWAP poll #1: PENDING
	machine.tick(0.10)   # SWAP poll #2: DONE -- t_swap == 0.20, same as the main scenario
	ticks = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(FRAME)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()

	assert_float(machine.last_transition_time).is_between(0.85 - FRAME, 0.85 + FRAME)


func test_budget_below_phases_logs_error() -> void:
	# Arrange: a valid `fade` row, plus `retry_flash` whose budget is under
	# its own t_out + t_in (0.65).
	var cfg: TransitionConfig = GameStateFixtures.transition_config_with(&"fade", 0.2, 0.2)
	GameStateFixtures.add_row(cfg, &"retry_flash", 0.35, 0.30, 0.5)
	var spy_log := SpyGameStateLog.new()

	# Act
	var ok: bool = cfg.validate(spy_log)

	# Assert
	assert_bool(ok).is_false()
	assert_int(spy_log.entries.size()).is_equal(1)
	assert_str(String(spy_log.entries[0]["code"])).is_equal("budget_below_phases")
	assert_str(String(spy_log.entries[0]["context"]["type"])).is_equal("retry_flash")


func test_budget_equal_to_phases_sum_logs_no_error() -> void:
	# Edge case: strict `<` -- budget == t_out + t_in exactly is not an error.
	var cfg: TransitionConfig = GameStateFixtures.transition_config_with(
			&"retry_flash", 0.35, 0.30, 0.65)
	var spy_log := SpyGameStateLog.new()

	var ok: bool = cfg.validate(spy_log)

	assert_bool(ok).is_true()
	assert_array(spy_log.entries).is_empty()


func test_budget_check_skips_none_row() -> void:
	# Edge case: a `none` row with no budget is skipped even though, read
	# literally, its budget would be under its phases' sum.
	var cfg: TransitionConfig = GameStateFixtures.transition_config_with(&"fade", 0.2, 0.2)
	GameStateFixtures.add_row(cfg, &"none", 0.1, 0.1, 0.0)
	var spy_log := SpyGameStateLog.new()

	var ok: bool = cfg.validate(spy_log)

	assert_bool(ok).is_true()
	assert_array(spy_log.entries).is_empty()


func test_budget_below_phases_does_not_stop_at_first_bad_row() -> void:
	# Edge case: two bad rows produce two entries, not one.
	var cfg: TransitionConfig = GameStateFixtures.transition_config_with(
			&"retry_flash", 0.35, 0.30, 0.5)
	GameStateFixtures.add_row(cfg, &"battle_wipe_reverse", 0.3, 0.25, 0.4)
	var spy_log := SpyGameStateLog.new()

	var ok: bool = cfg.validate(spy_log)

	assert_bool(ok).is_false()
	assert_int(spy_log.entries.size()).is_equal(2)
	var logged_types: Array[String] = []
	for entry: Dictionary in spy_log.entries:
		assert_str(String(entry["code"])).is_equal("budget_below_phases")
		logged_types.append(String(entry["context"]["type"]))
	logged_types.sort()
	assert_array(logged_types).is_equal(["battle_wipe_reverse", "retry_flash"])
