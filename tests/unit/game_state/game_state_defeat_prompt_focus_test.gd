## AC-29: the Defeat Prompt opens with Retry focused, `cancel` changes
## nothing, `menu` (or focus loss) opens the system Menu over it and focus
## returns to Retry once the Menu closes, and `confirm` on Retry starts
## `choose_retry()`. Uses the real `ModeHostSceneLoader` and a real
## `OverlayHost` `Node` (never `GameRoot`, never `StubSceneLoader`), so the
## production `push_overlay()`/`pop_overlay()` path is what is under test.
## Written to the QA Test Cases in
## `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`
## -- no new cases invented.
extends GdUnitTestSuite


## Breaks each test's machine/loader RefCounted cycle (they leaked otherwise).
func after_test() -> void:
	GameStateFixtures.dispose_tracked()

const _FIXTURES_DIR: String = "res://tests/unit/game_state/fixtures/"
const _DEFEAT_PROMPT_SCENE: String = "res://src/game_state/overlays/defeat_prompt.tscn"

const _MENU_TRIGGER_CASES: Array = [["menu"], ["focus_lost"]]
const _RETREAT_CASES: Array = [[false], [true]]


func test_prompt_opens_with_retry_focused() -> void:
	# Arrange: BATTLE, idle, no Defeat yet.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_battle_env(recorder, false)
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]

	# Act: Defeat.
	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: the Defeat Prompt is the real top overlay, Retry has focus.
	var prompt: DefeatPrompt = loader.current_overlay_node() as DefeatPrompt
	assert_object(prompt).is_not_null()
	var retry_button: Button = prompt.get_node("%RetryButton")
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), retry_button)) \
			.override_failure_message("Retry did not have focus on open").is_true()


func test_cancel_changes_nothing() -> void:
	# Arrange: the Defeat Prompt open, Retry focused.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_battle_env(recorder, false)
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var source: SyntheticActionSource = env["source"]

	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	await get_tree().process_frame
	await get_tree().process_frame

	var prompt: DefeatPrompt = loader.current_overlay_node() as DefeatPrompt
	var retry_button: Button = prompt.get_node("%RetryButton")
	var probe_before: Dictionary = machine.get_debug_state()

	# Act
	source.press(InputActions.CANCEL)
	await get_tree().process_frame

	# Assert: nothing changed.
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after cancel").is_true()
	assert_object(loader.current_overlay_node()).is_same(prompt)
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), retry_button)) \
			.override_failure_message("focus moved off Retry after cancel").is_true()


func test_menu_over_prompt_and_focus_returns(trigger: String,
		test_parameters := _MENU_TRIGGER_CASES) -> void:
	# Arrange: the Defeat Prompt open, Retry focused.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_battle_env(recorder, false)
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var source: SyntheticActionSource = env["source"]

	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	await get_tree().process_frame
	await get_tree().process_frame

	var prompt: DefeatPrompt = loader.current_overlay_node() as DefeatPrompt
	var retry_button: Button = prompt.get_node("%RetryButton")

	# Act: the Menu opens over the prompt, by whichever trigger.
	if trigger == "menu":
		source.press(InputActions.MENU)
	else:
		source.lose_focus()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: MENU stacked on top of DEFEAT_PROMPT, offering quit.
	var expected_stack: Array[GameStateMachine.OverlayKind] = [
		GameStateMachine.OverlayKind.DEFEAT_PROMPT, GameStateMachine.OverlayKind.MENU]
	assert_array(machine.overlay_stack).override_failure_message(
			trigger + ": MENU did not stack over DEFEAT_PROMPT").is_equal(expected_stack)
	var menu_node: StubOverlay = loader.current_overlay_node() as StubOverlay
	assert_object(menu_node).override_failure_message(
			trigger + ": no stand-in Menu overlay reached the loader").is_not_null()
	var menu_payload: MenuPayload = menu_node.last_setup_payload as MenuPayload
	assert_object(menu_payload).is_not_null()
	assert_bool(menu_payload.entries.has(&"quit")).override_failure_message(
			trigger + ": the Menu's entries did not include quit").is_true()

	# Act: the Menu closes.
	var close_result: GameStateMachine.RequestResult = machine.close_overlay()
	assert_int(close_result).is_equal(GameStateMachine.RequestResult.OK)
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: focus is back on Retry.
	assert_array(machine.overlay_stack).is_equal(
			[GameStateMachine.OverlayKind.DEFEAT_PROMPT] as Array[GameStateMachine.OverlayKind])
	assert_object(loader.current_overlay_node()).is_same(prompt)
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), retry_button)) \
			.override_failure_message(trigger + ": focus did not return to Retry").is_true()


func test_confirm_on_retry_calls_choose_retry(offers_retreat: bool,
		test_parameters := _RETREAT_CASES) -> void:
	# Arrange: the Defeat Prompt open, built with the offers_retreat case
	# under test.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_battle_env(recorder, offers_retreat)
	var machine: GameStateMachine = env["machine"]
	var loader: ModeHostSceneLoader = env["loader"]
	var source: SyntheticActionSource = env["source"]

	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)
	await get_tree().process_frame
	await get_tree().process_frame

	var prompt: DefeatPrompt = loader.current_overlay_node() as DefeatPrompt
	var retry_button: Button = prompt.get_node("%RetryButton")
	var retreat_button: Button = prompt.get_node_or_null("%RetreatButton")

	# Edge case: the Retreat button is absent when offers_retreat is false,
	# present (and not focused) when true.
	if offers_retreat:
		assert_object(retreat_button).override_failure_message(
				"Retreat button missing when offers_retreat is true").is_not_null()
		assert_bool(is_same(get_viewport().gui_get_focus_owner(), retreat_button)) \
				.override_failure_message("Retreat was focused, not Retry").is_false()
	else:
		assert_object(retreat_button).override_failure_message(
				"Retreat button present when offers_retreat is false").is_null()

	recorder.clear()

	# Act: confirm on Retry.
	source.press(InputActions.CONFIRM)

	# Assert: the choose_retry path started.
	var started_index: int = recorder.index_of(&"transition_started")
	assert_int(started_index).override_failure_message(
			"transition_started did not fire after confirm on Retry").is_greater_equal(0)
	var args: Array = recorder.events[started_index]["args"]
	assert_array(args).is_equal([GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.BATTLE])
	assert_object(retry_button).is_not_null()


## Builds a machine with the real `ModeHostSceneLoader` (BATTLE and the
## Defeat Prompt/Menu overlay scenes mapped for real; Title and Overworld
## are left unmapped, same deliberate omission as `_run_round_trip()` in
## `game_state_overworld_freeze_test.gd`), drives it from BOOT to idle
## BATTLE with a descriptor whose `retreat_allowed` is `retreat_allowed`,
## and binds a synthetic action source.
func _build_battle_env(recorder: SequenceRecorder, retreat_allowed: bool) -> Dictionary:
	var mode_host := Node.new()
	add_child(mode_host)
	auto_free(mode_host)
	var overlay_host := Node.new()
	add_child(overlay_host)
	auto_free(overlay_host)

	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	cfg.mode_scene_paths = {
		GameStateMachine.Mode.BATTLE: _FIXTURES_DIR + "stub_battle_mode.tscn",
	}
	cfg.overlay_scene_paths = {
		GameStateMachine.OverlayKind.DEFEAT_PROMPT: _DEFEAT_PROMPT_SCENE,
		GameStateMachine.OverlayKind.MENU: _FIXTURES_DIR + "stub_overlay.tscn",
	}

	var catalog: StubCatalog = GameStateFixtures.make_ready_catalog()
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var outcome_box: Array = [-1]
	var pre_setup := func(mode: GameMode, _payload: RefCounted) -> void:
		if mode is StubBattleMode:
			(mode as StubBattleMode).snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log, pre_setup,
			func() -> int: return outcome_box[0], overlay_host)
	var presenter := StubTransitionPresenter.new(recorder)
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	loader.set_machine(machine)
	GameStateFixtures.track(machine)
	recorder.attach(machine)
	machine.mode_entered.connect(loader.on_mode_entered)

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	# Boot -> Title (fade): Title has no scene mapped, so the loader no-ops
	# the swap (no node to add/remove).
	machine.tick(0.0)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)

	# Title -> Overworld (fade): Overworld also has no scene mapped -- this
	# story only needs a live BATTLE node.
	var overworld_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.OVERWORLD, null)
	assert_int(overworld_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)

	# Story 021: Retreat is offered only with a camp to go to.
	machine.register_camp("camp_a")

	# Overworld -> Battle (battle_wipe): stub_battle_mode.tscn is instantiated
	# under mode_host for real.
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.retreat_allowed = retreat_allowed
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = []
	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	return {"machine": machine, "loader": loader, "source": source, "config": cfg}


## Bounded 1/60s-tick loop until the transition reaches IDLE, as in every
## other suite in this epic.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
