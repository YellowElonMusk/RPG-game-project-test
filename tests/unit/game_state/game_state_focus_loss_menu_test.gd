## Story 026, AC-23: `focus_lost`/`device_lost` open the Menu at once while
## idle in an allowed mode (Overworld, Camp, Battle -- the Defeat Prompt on
## top counts as allowed), defer it until `transition_finished` during a
## transition (resolved by the destination mode, not the origin), and are
## ignored in Boot with no flag set. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-026-focus-loss-opens-menu.md`
## -- no new cases invented.
extends GdUnitTestSuite

const _SIGNALS: Array = [&"focus_lost", &"device_lost"]

const _IDLE_CASES: Array = [
	[&"focus_lost", "OVERWORLD_IDLE"], [&"focus_lost", "BATTLE_IDLE_DEFEAT_PROMPT"],
	[&"device_lost", "OVERWORLD_IDLE"], [&"device_lost", "BATTLE_IDLE_DEFEAT_PROMPT"],
]

const _TRANSITION_CASES: Array = [
	[&"focus_lost", "OUT"], [&"focus_lost", "SWAP"], [&"focus_lost", "IN"],
	[&"device_lost", "OUT"], [&"device_lost", "SWAP"], [&"device_lost", "IN"],
]


func test_loss_opens_menu(signal_name: StringName, state_name: String,
		test_parameters := _IDLE_CASES) -> void:
	# Arrange: OVERWORLD idle, or BATTLE idle with the Defeat Prompt already
	# on top (ADR-0002 §6 ruling 2026-10-23: the Defeat Prompt counts as
	# allowed, same gate story 024 uses for the menu action).
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var expected_stack: Array[GameStateMachine.OverlayKind] = [GameStateMachine.OverlayKind.MENU]

	if state_name == "BATTLE_IDLE_DEFEAT_PROMPT":
		var mode: StubBattleMode = auto_free(StubBattleMode.new())
		mode.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
		loader.current_mode_node_value = mode
		var battle_result: GameStateMachine.RequestResult = machine.request_transition(
				GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
		assert_int(battle_result).is_equal(GameStateMachine.RequestResult.OK)
		_run_to_idle(machine)
		var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
				GameStateMachine.BattleResult.DEFEAT)
		assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
		expected_stack = [GameStateMachine.OverlayKind.DEFEAT_PROMPT, GameStateMachine.OverlayKind.MENU]

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()

	# Act
	_trigger(source, signal_name)

	# Assert: overlay_opened(MENU) fired synchronously; MENU on top. (The stub
	# loader records push_overlay / set_mode_time_stopped first, so this is
	# "recorded", not "recorded at index 0".)
	assert_int(recorder.index_of(&"overlay_opened")).override_failure_message(
			state_name + "/" + signal_name + ": overlay_opened(MENU) did not fire").is_not_equal(-1)
	assert_array(machine.overlay_stack).override_failure_message(
			state_name + "/" + signal_name + ": MENU is not on top").is_equal(expected_stack)


func test_loss_during_transition_deferred(signal_name: StringName, phase_name: String,
		test_parameters := _TRANSITION_CASES) -> void:
	# Arrange: an Overworld -> Battle battle_wipe stopped mid-flight at
	# phase_name, mirroring `_advance_to_phase()` in
	# `game_state_menu_gating_test.gd`.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var cfg: TransitionConfig = env["config"]
	var mode: StubBattleMode = auto_free(StubBattleMode.new())
	mode.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = mode
	loader.script_results([SceneLoader.SwapStatus.PENDING, SceneLoader.SwapStatus.DONE])
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_advance_to_phase(machine, cfg, phase_name)

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()

	# Act
	_trigger(source, signal_name)

	# Assert: deferred, nothing opened yet.
	assert_bool(machine.get_debug_state()["menu_deferred"]).override_failure_message(
			phase_name + "/" + signal_name + ": menu_deferred not set").is_true()
	assert_int(recorder.index_of(&"overlay_opened")).override_failure_message(
			phase_name + "/" + signal_name + ": overlay_opened fired before transition_finished") \
			.is_equal(-1)

	_run_to_idle(machine)

	# Assert: MENU opens right after transition_finished, flag cleared.
	var finished_index: int = recorder.index_of(&"transition_finished")
	var opened_index: int = recorder.index_of(&"overlay_opened")
	assert_int(finished_index).override_failure_message(
			phase_name + "/" + signal_name + ": transition_finished never fired").is_greater_equal(0)
	assert_int(opened_index).override_failure_message(
			phase_name + "/" + signal_name + ": overlay_opened(MENU) did not follow transition_finished") \
			.is_greater(finished_index)
	assert_bool(machine.get_debug_state()["menu_deferred"]).override_failure_message(
			phase_name + "/" + signal_name + ": menu_deferred not cleared").is_false()
	assert_array(machine.overlay_stack).is_equal(
			[GameStateMachine.OverlayKind.MENU] as Array[GameStateMachine.OverlayKind])


func test_loss_in_boot_ignored() -> void:
	# Arrange: a fresh machine in BOOT, idle (catalog UNLOADED), mirroring
	# `_build_boot_env()` in `game_state_menu_gating_test.gd`.
	var recorder := SequenceRecorder.new()
	var loader := StubSceneLoader.new(recorder)
	var presenter := StubTransitionPresenter.new(recorder)
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog := StubCatalog.new()
	catalog.state = ContentCatalogService.State.UNLOADED
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	recorder.attach(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BOOT)

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()

	# Act / Assert: focus lost while BOOT is idle -> nothing happens.
	source.lose_focus()
	assert_int(recorder.index_of(&"overlay_opened")).override_failure_message(
			"boot/idle: overlay_opened fired").is_equal(-1)
	assert_bool(machine.get_debug_state()["menu_deferred"]).override_failure_message(
			"boot/idle: menu_deferred set").is_false()

	# Act / Assert: catalog goes READY -> Boot -> Title starts; losing focus
	# mid-transition defers (edge case: a transition whose destination is
	# TITLE never opens the Menu, and the flag clears silently).
	catalog.state = ContentCatalogService.State.READY
	machine.tick(0.0)
	assert_int(machine.phase).is_equal(GameStateMachine.Phase.OUT)
	source.lose_focus()
	assert_bool(machine.get_debug_state()["menu_deferred"]).override_failure_message(
			"boot->title: menu_deferred not set mid-transition").is_true()
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)
	assert_int(recorder.index_of(&"overlay_opened")).override_failure_message(
			"boot->title: overlay_opened fired for a TITLE destination").is_equal(-1)
	assert_bool(machine.get_debug_state()["menu_deferred"]).override_failure_message(
			"boot->title: menu_deferred not cleared after a TITLE destination").is_false()

	# Edge case: a second loss with the Menu already open -> no second
	# overlay_opened, no duplicate entry on the stack.
	var ow_env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var ow_machine: GameStateMachine = ow_env["machine"]
	var ow_source := SyntheticActionSource.new()
	ow_machine.bind_action_source(ow_source)
	ow_source.lose_focus()
	assert_array(ow_machine.overlay_stack).is_equal(
			[GameStateMachine.OverlayKind.MENU] as Array[GameStateMachine.OverlayKind])
	var opened_count_before: int = 1
	ow_source.lose_focus()
	var opened_events: Array = []
	for kind: GameStateMachine.OverlayKind in ow_machine.overlay_stack:
		opened_events.append(kind)
	assert_array(ow_machine.overlay_stack).override_failure_message(
			"second loss with MENU open stacked a duplicate").is_equal(
					[GameStateMachine.OverlayKind.MENU] as Array[GameStateMachine.OverlayKind])
	assert_int(opened_events.size()).is_equal(opened_count_before)

	# Edge case: loss during the in-mode fade -> Menu opens right after
	# transition_finished (also exercised in story 028).
	var fade_recorder := SequenceRecorder.new()
	var fade_env: Dictionary = GameStateFixtures.make_machine_in_overworld(fade_recorder)
	var fade_machine: GameStateMachine = fade_env["machine"]
	var fade_cfg: TransitionConfig = fade_env["config"]
	var fade_source := SyntheticActionSource.new()
	fade_machine.bind_action_source(fade_source)
	var fade_result: GameStateMachine.RequestResult = fade_machine.request_in_mode_fade(
			func() -> void: pass)
	assert_int(fade_result).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(fade_machine.phase).is_equal(GameStateMachine.Phase.OUT)
	fade_recorder.clear()
	fade_source.lose_device()
	assert_int(fade_recorder.index_of(&"overlay_opened")).is_equal(-1)
	var ticks: int = 0
	while fade_machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		fade_machine.tick(fade_cfg.t_out[&"fade"])
		ticks += 1
	assert_bool(ticks < 600).is_true()
	var fade_finished_index: int = fade_recorder.index_of(&"transition_finished")
	var fade_opened_index: int = fade_recorder.index_of(&"overlay_opened")
	assert_int(fade_finished_index).is_greater_equal(0)
	assert_int(fade_opened_index).override_failure_message(
			"in-mode fade: overlay_opened(MENU) did not follow transition_finished") \
			.is_greater(fade_finished_index)
	assert_array(fade_machine.overlay_stack).is_equal(
			[GameStateMachine.OverlayKind.MENU] as Array[GameStateMachine.OverlayKind])


func _trigger(source: SyntheticActionSource, signal_name: StringName) -> void:
	if signal_name == &"focus_lost":
		source.lose_focus()
	else:
		source.lose_device()


## Advances `machine` from freshly-requested OUT to the given phase_name,
## mirroring `_advance_to_phase()` in `game_state_menu_gating_test.gd`.
func _advance_to_phase(machine: GameStateMachine, cfg: TransitionConfig, phase_name: String) -> void:
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


## Bounded 1/60s-tick loop until the transition reaches IDLE, as in every
## other test in this suite.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
