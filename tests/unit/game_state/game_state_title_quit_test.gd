## AC-30: Title opens with New Game focused and Continue disabled; Quit opens
## `QuitConfirm` with No focused; `cancel` closes it without quitting; Yes
## calls the injected quit handler exactly once even when confirmed twice in
## one frame. Uses the real `ModeHostSceneLoader` (never `StubSceneLoader`),
## so the production `title_mode.tscn` swap is what is under test -- same
## choice as `game_state_defeat_prompt_focus_test.gd` (story 030). Written to
## the QA Test Cases in
## `production/epics/game-state-scene-flow/story-031-title-focus-and-quit-confirm.md`
## -- no new cases invented.
extends GdUnitTestSuite

const _TITLE_SCENE: String = "res://src/game_state/modes/title_mode.tscn"


func test_title_initial_focus() -> void:
	# Arrange + Act: Boot -> Title, with the real title_mode.tscn mapped.
	var env: Dictionary = _build_title_env(SequenceRecorder.new())
	var loader: ModeHostSceneLoader = env["loader"]
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: New Game focused, Continue disabled.
	var title: TitleMode = loader.current_mode_node() as TitleMode
	assert_object(title).is_not_null()
	var new_game_button: Button = title.get_node("%NewGameButton")
	var continue_button: Button = title.get_node("%ContinueButton")
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), new_game_button)) \
			.override_failure_message("New Game did not have focus on Title").is_true()
	assert_bool(continue_button.disabled).override_failure_message(
			"Continue was not disabled").is_true()


func test_quit_confirm_flow() -> void:
	# Arrange: Title, idle.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_title_env(recorder)
	var loader: ModeHostSceneLoader = env["loader"]
	var source: SyntheticActionSource = env["source"]
	var quit_spy: QuitSpy = env["quit_spy"]
	await get_tree().process_frame
	await get_tree().process_frame

	var title: TitleMode = loader.current_mode_node() as TitleMode
	var quit_button: Button = title.get_node("%QuitButton")
	var quit_confirm: Control = title.get_node("%QuitConfirm")
	# YesButton/NoButton are unique names inside the QuitConfirm sub-scene, so
	# they resolve from it, not from the Title root.
	var yes_button: Button = quit_confirm.get_node("%YesButton")
	var no_button: Button = quit_confirm.get_node("%NoButton")

	# Act: navigate down x3 (New Game -> Continue -> Settings -> Quit), confirm.
	for i in range(3):
		source.press(InputActions.NAV_DOWN)
	source.press(InputActions.CONFIRM)
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: the confirmation opened with No focused.
	assert_bool(quit_confirm.visible).override_failure_message(
			"confirmation did not open after confirm on Quit").is_true()
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), no_button)) \
			.override_failure_message("No was not focused on open").is_true()

	# Act: cancel.
	source.press(InputActions.CANCEL)
	await get_tree().process_frame

	# Assert: closed without quitting, focus back on Quit.
	assert_bool(quit_confirm.visible).override_failure_message(
			"confirmation did not close after cancel").is_false()
	assert_int(quit_spy.call_count).override_failure_message(
			"quit fired after cancel").is_equal(0)
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), quit_button)) \
			.override_failure_message("focus did not return to Quit after cancel").is_true()

	# Act: reopen, move to Yes, confirm x2 in one frame (no await between).
	source.press(InputActions.CONFIRM)
	await get_tree().process_frame
	await get_tree().process_frame
	source.press(InputActions.NAV_UP)
	source.press(InputActions.CONFIRM)
	source.press(InputActions.CONFIRM)

	# Assert: the quit latch absorbed the second confirm.
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), yes_button)) \
			.override_failure_message("Yes was not focused before the double confirm").is_true()
	assert_int(quit_spy.call_count).override_failure_message(
			"Yes confirmed twice in one frame did not call quit exactly once").is_equal(1)


func test_no_confirm_closes_without_quit() -> void:
	# Arrange: the confirmation open, No focused (its default on open).
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_title_env(recorder)
	var loader: ModeHostSceneLoader = env["loader"]
	var source: SyntheticActionSource = env["source"]
	var quit_spy: QuitSpy = env["quit_spy"]
	await get_tree().process_frame
	await get_tree().process_frame

	var title: TitleMode = loader.current_mode_node() as TitleMode
	var quit_button: Button = title.get_node("%QuitButton")
	var quit_confirm: Control = title.get_node("%QuitConfirm")
	var no_button: Button = quit_confirm.get_node("%NoButton")

	quit_button.grab_focus()
	source.press(InputActions.CONFIRM)
	await get_tree().process_frame
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), no_button)) \
			.override_failure_message("No was not focused on open").is_true()

	# Act: confirm on No.
	source.press(InputActions.CONFIRM)
	await get_tree().process_frame

	# Assert: closes, no quit.
	assert_bool(quit_confirm.visible).override_failure_message(
			"confirmation did not close after confirm on No").is_false()
	assert_int(quit_spy.call_count).override_failure_message(
			"quit fired after confirm on No").is_equal(0)
	assert_bool(is_same(get_viewport().gui_get_focus_owner(), quit_button)) \
			.override_failure_message("focus did not return to Quit after No").is_true()


func test_new_game_confirm_requests_overworld() -> void:
	# Arrange: Title, idle, New Game focused.
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _build_title_env(recorder)
	var source: SyntheticActionSource = env["source"]
	await get_tree().process_frame
	await get_tree().process_frame
	recorder.clear()

	# Act: confirm on New Game.
	source.press(InputActions.CONFIRM)

	# Assert: a Title -> Overworld transition started.
	var started_index: int = recorder.index_of(&"transition_started")
	assert_int(started_index).override_failure_message(
			"transition_started did not fire after confirm on New Game").is_greater_equal(0)
	var args: Array = recorder.events[started_index]["args"]
	assert_array(args).is_equal([GameStateMachine.Mode.TITLE, GameStateMachine.Mode.OVERWORLD])


## Builds a machine with the real `ModeHostSceneLoader` (TITLE mapped for
## real; OVERWORLD is left unmapped, same deliberate omission as
## `_build_battle_env()` in `game_state_defeat_prompt_focus_test.gd` -- this
## story only needs a live TITLE node), drives it from BOOT to idle TITLE, and
## binds a synthetic action source.
func _build_title_env(recorder: SequenceRecorder) -> Dictionary:
	var mode_host := Node.new()
	add_child(mode_host)
	auto_free(mode_host)

	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	cfg.mode_scene_paths = {
		GameStateMachine.Mode.TITLE: _TITLE_SCENE,
	}

	var catalog: StubCatalog = GameStateFixtures.make_ready_catalog()
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	# Mode scenes get `setup(machine, payload)` only through the loader's
	# pre_setup closure (ADR-0002 Implementation Notes); the machine is built
	# after the loader, so the closure reads it from a box.
	var machine_box: Array = [null]
	var pre_setup := func(mode: GameMode, payload: RefCounted) -> void:
		mode.setup(machine_box[0], payload)
	var loader := ModeHostSceneLoader.new(mode_host, cfg, game_log, pre_setup)
	var presenter := StubTransitionPresenter.new(recorder)
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	machine_box[0] = machine
	loader.set_machine(machine)
	recorder.attach(machine)

	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	# Boot -> Title (fade): title_mode.tscn is instantiated under mode_host
	# for real.
	machine.tick(0.0)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)

	return {"machine": machine, "loader": loader, "source": source, "quit_spy": quit_spy,
		"config": cfg}


## Bounded 1/60s-tick loop until the transition reaches IDLE, as in every
## other suite in this epic.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
