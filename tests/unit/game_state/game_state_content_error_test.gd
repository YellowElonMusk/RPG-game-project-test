## Story 005, AC-2: Content Error is terminal -- every entry point except
## `request_quit()` returns `REJECTED_TERMINAL` and changes nothing, the quit
## hook fires at most once per machine lifetime (the latch), and focus/device
## loss is ignored without setting the deferred-Menu flag. Written to the QA
## Test Cases in
## `production/epics/game-state-scene-flow/story-005-content-error-rejects-all-but-quit.md`
## -- no new cases invented.
extends GdUnitTestSuite

## One row per entry point under test. `request_transition` is exercised
## against every `Mode`, `open_overlay` against every `OverlayKind`, and
## `report_battle_outcome` against every `BattleResult`; the remaining entry
## points take no argument (`arg_variant` is `null` and ignored).
const _CASES: Array = [
	["request_transition_boot", &"request_transition", GameStateMachine.Mode.BOOT],
	["request_transition_content_error", &"request_transition", GameStateMachine.Mode.CONTENT_ERROR],
	["request_transition_title", &"request_transition", GameStateMachine.Mode.TITLE],
	["request_transition_overworld", &"request_transition", GameStateMachine.Mode.OVERWORLD],
	["request_transition_battle", &"request_transition", GameStateMachine.Mode.BATTLE],
	["request_transition_camp", &"request_transition", GameStateMachine.Mode.CAMP],
	["open_overlay_dialogue", &"open_overlay", GameStateMachine.OverlayKind.DIALOGUE],
	["open_overlay_menu", &"open_overlay", GameStateMachine.OverlayKind.MENU],
	["open_overlay_defeat_prompt", &"open_overlay", GameStateMachine.OverlayKind.DEFEAT_PROMPT],
	["close_overlay", &"close_overlay", null],
	["request_in_mode_fade", &"request_in_mode_fade", null],
	["report_battle_outcome_victory", &"report_battle_outcome", GameStateMachine.BattleResult.VICTORY],
	["report_battle_outcome_fled", &"report_battle_outcome", GameStateMachine.BattleResult.FLED],
	["report_battle_outcome_defeat", &"report_battle_outcome", GameStateMachine.BattleResult.DEFEAT],
	["report_results_done", &"report_results_done", null],
	["choose_retry", &"choose_retry", null],
	["choose_retreat", &"choose_retreat", null],
]


func test_every_request_rejected_terminal(case_name: String, entry_point_id: StringName,
		arg_variant: Variant, test_parameters := _CASES) -> void:
	# Arrange: a fresh machine already in CONTENT_ERROR (stub catalog FAILED).
	var recorder := SequenceRecorder.new()
	var env: Dictionary = _fresh_content_error_machine(recorder)
	var machine: GameStateMachine = env["machine"]

	# Act / Assert: the entry point rejected 3 times, with one tick between
	# calls, the debug state unchanged after each.
	for i: int in range(3):
		var probe_before: Dictionary = machine.get_debug_state()
		var result: GameStateMachine.RequestResult = _invoke_entry_point(
				machine, entry_point_id, arg_variant)
		assert_int(result).override_failure_message(
				"%s call %d" % [case_name, i]).is_equal(GameStateMachine.RequestResult.REJECTED_TERMINAL)
		assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
				.override_failure_message(
						"%s call %d: debug state changed after a rejected call" % [case_name, i]) \
				.is_true()
		machine.tick(1.0 / 60.0)

	# Assert: nothing reached the loader, presenter or quit hook.
	assert_array(recorder.events).override_failure_message(
			case_name + ": recorder should stay empty in Content Error").is_empty()


func test_register_camp_ignored() -> void:
	# Arrange: CONTENT_ERROR.
	var env: Dictionary = _fresh_content_error_machine()
	var machine: GameStateMachine = env["machine"]
	var game_log: SpyGameStateLog = env["log"]

	# Act / Assert: register_camp("camp_a") x3 -- unchanged, one more log
	# entry and an unchanged debug state after each call.
	for i: int in range(3):
		var probe_before: Dictionary = machine.get_debug_state()
		machine.register_camp("camp_a")
		assert_str(machine.last_camp_id).override_failure_message(
				"call %d" % i).is_equal("")
		assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
				.override_failure_message(
						"call %d: debug state changed after an ignored register_camp" % i).is_true()
		assert_int(_count_log_code(game_log, &"register_camp_wrong_mode")).override_failure_message(
				"call %d" % i).is_equal(i + 1)


func test_focus_and_device_loss_ignored() -> void:
	# Arrange: CONTENT_ERROR, synthetic source bound.
	var env: Dictionary = _fresh_content_error_machine()
	var machine: GameStateMachine = env["machine"]
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	var opened_kinds: Array[GameStateMachine.OverlayKind] = []
	machine.overlay_opened.connect(
			func(kind: GameStateMachine.OverlayKind) -> void: opened_kinds.append(kind))

	# Act: focus_lost x3, device_lost x3, then 10 ticks.
	for i: int in range(3):
		source.lose_focus()
	for i: int in range(3):
		source.lose_device()
	for i: int in range(10):
		machine.tick(1.0 / 60.0)

	# Assert: no overlay opened; the deferred-Menu flag never set.
	assert_array(opened_kinds).is_empty()
	assert_bool(machine.get_debug_state()["menu_deferred"]).is_false()

	# A later tick still opens nothing.
	machine.tick(1.0 / 60.0)
	assert_array(opened_kinds).is_empty()
	assert_bool(machine.get_debug_state()["menu_deferred"]).is_false()


func test_quit_only_accepted() -> void:
	# Arrange: CONTENT_ERROR with a quit spy.
	var env: Dictionary = _fresh_content_error_machine()
	var machine: GameStateMachine = env["machine"]
	var quit_spy: QuitSpy = env["quit_spy"]

	# Act: request_quit() x3.
	for i: int in range(3):
		var result: GameStateMachine.RequestResult = machine.request_quit()
		assert_int(result).override_failure_message("call %d" % i).is_equal(
				GameStateMachine.RequestResult.OK)

	# Assert: the quit hook fired exactly once (the latch).
	assert_int(quit_spy.call_count).is_equal(1)

	# Edge cases: synthetic action_pressed(&"menu") and (&"confirm") reach no
	# receiver -- the stub loader's current_mode_node()/current_overlay_node()
	# default to null, so dispatch has nothing to call, and the debug state is
	# unaffected.
	var probe_before: Dictionary = machine.get_debug_state()
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)
	source.press(&"menu")
	source.press(&"confirm")
	assert_bool(GameStateProbe.states_equal(probe_before, machine.get_debug_state())) \
			.override_failure_message("debug state changed after an undelivered action").is_true()


## Dispatches to the entry point named `entry_point_id` with `arg_variant`
## where one applies; the no-argument entry points ignore it.
func _invoke_entry_point(machine: GameStateMachine, entry_point_id: StringName,
		arg_variant: Variant) -> GameStateMachine.RequestResult:
	match entry_point_id:
		&"request_transition":
			return machine.request_transition(arg_variant as GameStateMachine.Mode, null)
		&"open_overlay":
			return machine.open_overlay(arg_variant as GameStateMachine.OverlayKind, null)
		&"close_overlay":
			return machine.close_overlay()
		&"request_in_mode_fade":
			return machine.request_in_mode_fade(Callable(self, "_noop_fade_callback"))
		&"report_battle_outcome":
			return machine.report_battle_outcome(arg_variant as GameStateMachine.BattleResult)
		&"report_results_done":
			return machine.report_results_done()
		&"choose_retry":
			return machine.choose_retry()
		_:
			return machine.choose_retreat()


## A valid `Callable` for `request_in_mode_fade()` -- never actually called,
## since Content Error rejects before touching it.
func _noop_fade_callback() -> void:
	pass


## True count of `log_sink` entries carrying `code`.
func _count_log_code(log_sink: SpyGameStateLog, code: StringName) -> int:
	var count: int = 0
	for entry: Dictionary in log_sink.entries:
		if entry["code"] == code:
			count += 1
	return count


## A fresh machine driven from BOOT to CONTENT_ERROR through the real
## catalog path (stub catalog scripted FAILED), never a shortcut that sets
## `current_mode` directly -- mirrors `_fresh_boot_machine()` in
## `game_state_boot_test.gd`. The recorder (if given) is attached before the
## Boot -> Content Error transition and cleared after, so a caller sees only
## events from its own scenario.
func _fresh_content_error_machine(recorder: SequenceRecorder = null) -> Dictionary:
	var loader := StubSceneLoader.new(recorder)
	var presenter := StubTransitionPresenter.new(recorder)
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog := StubCatalog.new()
	catalog.state = ContentCatalogService.State.FAILED
	var quit_spy := QuitSpy.new(recorder)
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	if recorder != null:
		recorder.attach(machine)

	machine.tick(0.0)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CONTENT_ERROR)

	if recorder != null:
		recorder.clear()
	return {"machine": machine, "loader": loader, "presenter": presenter,
			"config": cfg, "catalog": catalog, "log": game_log, "quit_spy": quit_spy}


## Bounded 1/60s-tick loop until the transition reaches IDLE, as in every
## other test in this suite.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
