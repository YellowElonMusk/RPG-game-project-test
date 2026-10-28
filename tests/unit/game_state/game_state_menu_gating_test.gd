## Story 024, AC-22: the machine turns `action_pressed(&"menu")` into a Menu
## open itself, before any routing to the mode or overlay, and only where
## rule 10 allows it (Overworld, Camp, Battle) while idle. Every other case --
## a running transition, Boot, Title or Content Error -- drops the request:
## no overlay opens, the debug state is unchanged and the action never
## reaches whatever mode or overlay is live. Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-024-menu-input-gating.md`
## -- no new cases invented.
extends GdUnitTestSuite

## TODO(input-system epic, ADR-0003): switch to `InputActions.MENU` once it
## lands -- there is no constant to reference yet (mirrors the machine's own
## TODO on `_MENU_ACTION`).
const _MENU_ACTION: StringName = &"menu"

const _REJECTED_CASES: Array = [
	["BOOT"], ["CONTENT_ERROR"], ["TITLE"], ["OUT"], ["SWAP"], ["IN"],
]


func test_menu_input_rejected(case_name: String, test_parameters := _REJECTED_CASES) -> void:
	# Arrange: the machine in the given state, a counting stub mode live
	# under the loader (so a leak would be caught even though none is
	# expected), a synthetic source bound.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_case_env(case_name, recorder)
	var machine: GameStateMachine = env["machine"]
	var mode: StubBattleMode = env["mode"]
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	recorder.clear()
	var probe_before: Dictionary = machine.get_debug_state()

	# Act
	source.press(_MENU_ACTION)

	# Assert: no overlay_opened recorded, debug state unchanged, the mode
	# never saw &"menu".
	var opened_events: Array = recorder.events.filter(
			func(e: Dictionary) -> bool: return e["event"] == &"overlay_opened")
	assert_array(opened_events).override_failure_message(
			case_name + ": overlay_opened fired for a rejected menu press").is_empty()
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message(
					case_name + ": debug state changed after a rejected menu press").is_true()
	assert_int(mode.handle_action_count).override_failure_message(
			case_name + ": the mode received \"menu\"").is_equal(0)


func test_menu_input_opens_in_allowed_modes() -> void:
	# Arrange: OVERWORLD, idle. One counting double is reused as the loader's
	# current_mode_node() across every mode below -- a double's identity is
	# irrelevant to the machine, and its snapshot is set up front since the
	# Battle stage needs one.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(recorder)
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode: StubBattleMode = auto_free(StubBattleMode.new())
	mode.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = mode
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	var expected_menu_only: Array[GameStateMachine.OverlayKind] = [
		GameStateMachine.OverlayKind.MENU]
	recorder.clear()

	# Act / Assert: OVERWORLD.
	source.press(_MENU_ACTION)
	assert_array(machine.overlay_stack).override_failure_message(
			"overworld: menu did not open").is_equal(expected_menu_only)
	assert_int(mode.handle_action_count).override_failure_message(
			"overworld: the mode received menu").is_equal(0)
	assert_int(machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)

	# Act / Assert: CAMP.
	var camp_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP, null)
	assert_int(camp_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)
	source.press(_MENU_ACTION)
	assert_array(machine.overlay_stack).override_failure_message(
			"camp: menu did not open").is_equal(expected_menu_only)
	assert_int(mode.handle_action_count).override_failure_message(
			"camp: the mode received menu").is_equal(0)
	assert_int(machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)

	# Act / Assert: BATTLE.
	var back_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.OVERWORLD, null)
	assert_int(back_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	var battle_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
	assert_int(battle_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	source.press(_MENU_ACTION)
	assert_array(machine.overlay_stack).override_failure_message(
			"battle: menu did not open").is_equal(expected_menu_only)
	assert_int(mode.handle_action_count).override_failure_message(
			"battle: the mode received menu").is_equal(0)

	# Act / Assert: BATTLE with the Defeat Prompt already on top -- the Menu
	# still opens, stacking above it (ADR-0002 §6 ruling 2026-10-23: this is
	# what lets the Menu open over the Defeat Prompt, story 030).
	assert_int(machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)
	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	source.press(_MENU_ACTION)
	var expected_stacked: Array[GameStateMachine.OverlayKind] = [
		GameStateMachine.OverlayKind.DEFEAT_PROMPT, GameStateMachine.OverlayKind.MENU]
	assert_array(machine.overlay_stack).override_failure_message(
			"battle+defeat prompt: menu did not stack on top").is_equal(expected_stacked)
	assert_int(mode.handle_action_count).override_failure_message(
			"battle+defeat prompt: the mode received menu").is_equal(0)

	# Edge case: direct open_overlay(MENU) during a transition -> REJECTED_BUSY.
	var busy_recorder := SequenceRecorder.new()
	var busy_env: Dictionary = GameStateFixtures.make_machine_in_overworld(busy_recorder)
	var busy_machine: GameStateMachine = busy_env["machine"]
	var busy_result: GameStateMachine.RequestResult = busy_machine.request_transition(
			GameStateMachine.Mode.CAMP, null)
	assert_int(busy_result).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(busy_machine.phase).is_equal(GameStateMachine.Phase.OUT)
	var busy_menu_result: GameStateMachine.RequestResult = busy_machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(busy_menu_result).is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)

	# Edge case: direct open_overlay(MENU) in CONTENT_ERROR -> REJECTED_TERMINAL.
	var terminal_env: Dictionary = _build_content_error_env(SequenceRecorder.new())
	var terminal_machine: GameStateMachine = terminal_env["machine"]
	var terminal_result: GameStateMachine.RequestResult = terminal_machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(terminal_result).is_equal(GameStateMachine.RequestResult.REJECTED_TERMINAL)


## Dispatches to the builder for `case_name` ("BOOT", "CONTENT_ERROR",
## "TITLE", or a Phase name for a machine stopped mid-transition).
func _build_case_env(case_name: String, recorder: SequenceRecorder) -> Dictionary:
	match case_name:
		"BOOT":
			return _build_boot_env(recorder)
		"CONTENT_ERROR":
			return _build_content_error_env(recorder)
		"TITLE":
			return _build_title_env(recorder)
		_:
			return _build_transition_phase_env(case_name, recorder)


## A fresh machine left in BOOT (catalog UNLOADED, never ticked past
## construction), mirroring `_fresh_boot_machine()` in `game_state_boot_test.gd`.
func _build_boot_env(recorder: SequenceRecorder) -> Dictionary:
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
	var mode: StubBattleMode = auto_free(StubBattleMode.new())
	loader.current_mode_node_value = mode
	return {"machine": machine, "mode": mode}


## A fresh machine driven from BOOT to CONTENT_ERROR, mirroring
## `_fresh_content_error_machine()` in `game_state_content_error_test.gd`.
func _build_content_error_env(recorder: SequenceRecorder) -> Dictionary:
	var loader := StubSceneLoader.new(recorder)
	var presenter := StubTransitionPresenter.new(recorder)
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog := StubCatalog.new()
	catalog.state = ContentCatalogService.State.FAILED
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	recorder.attach(machine)
	machine.tick(0.0)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CONTENT_ERROR)
	var mode: StubBattleMode = auto_free(StubBattleMode.new())
	loader.current_mode_node_value = mode
	return {"machine": machine, "mode": mode}


## A fresh machine driven from BOOT to TITLE (catalog READY), mirroring
## `test_ready_catalog_goes_to_title` in `game_state_boot_test.gd`.
func _build_title_env(recorder: SequenceRecorder) -> Dictionary:
	var loader := StubSceneLoader.new(recorder)
	var presenter := StubTransitionPresenter.new(recorder)
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog: StubCatalog = GameStateFixtures.make_ready_catalog()
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	recorder.attach(machine)
	machine.tick(0.0)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)
	var mode: StubBattleMode = auto_free(StubBattleMode.new())
	loader.current_mode_node_value = mode
	return {"machine": machine, "mode": mode}


## A machine stopped mid-flight in `phase_name` ("OUT", "SWAP" or "IN") of an
## Overworld -> Battle `battle_wipe`, mirroring `_advance_to_phase()` in
## `game_state_input_lock_test.gd`.
func _build_transition_phase_env(phase_name: String, recorder: SequenceRecorder) -> Dictionary:
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
	return {"machine": machine, "mode": mode}


## Advances `machine` from freshly-requested OUT to the given phase_name.
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
