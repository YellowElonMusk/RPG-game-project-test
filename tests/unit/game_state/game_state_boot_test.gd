## Story 004, AC-1: Boot reads the injected catalog's `state` each tick --
## never assuming its first tick sees a terminal value -- and resolves to
## Title on Ready or to Content Error on Failed. Written to the QA Test Cases
## in
## `production/epics/game-state-scene-flow/story-004-boot-to-title-or-content-error.md`
## -- no new cases invented.
extends GdUnitTestSuite

## (a) the catalog is already Ready on Boot's first tick; (c) it becomes Ready
## only after several ticks in a non-terminal state. UNLOADED and VALIDATING
## are mixed in with LOADING per the story's Edge Cases note that all three
## behave alike.
const _READY_CASES: Array = [
	["immediate_ready", []],
	["ready_after_non_terminal_ticks", [
		ContentCatalogService.State.UNLOADED, ContentCatalogService.State.LOADING,
		ContentCatalogService.State.VALIDATING, ContentCatalogService.State.LOADING,
		ContentCatalogService.State.LOADING,
	]],
]

## Counts `transition_started` while a case's non-terminal ticks run, so the
## assertion that none fired early does not depend on signal-handler ordering.
var _started_count: int = 0


func test_ready_catalog_goes_to_title(case_name: String, pre_states: Array,
		test_parameters := _READY_CASES) -> void:
	# Arrange: a fresh BOOT machine over a stub catalog that starts UNLOADED.
	var env: Dictionary = _fresh_boot_machine()
	var machine: GameStateMachine = env["machine"]
	var catalog: StubCatalog = env["catalog"]
	var presenter: StubTransitionPresenter = env["presenter"]

	_started_count = 0
	machine.transition_started.connect(_on_transition_started)

	# Act: one tick per scripted non-terminal state -- mode must stay BOOT and
	# no transition may start before the catalog turns terminal.
	for state: ContentCatalogService.State in pre_states:
		catalog.state = state
		machine.tick(1.0 / 60.0)
		assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
				GameStateMachine.Mode.BOOT)
		assert_int(_started_count).override_failure_message(
				case_name + ": no transition before the catalog is terminal").is_equal(0)

	catalog.state = ContentCatalogService.State.READY
	machine.tick(0.0)
	_run_to_idle(machine)

	# Assert: Title, reached through exactly one `fade`.
	assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
			GameStateMachine.Mode.TITLE)
	assert_int(presenter.play_out_calls.size()).override_failure_message(case_name).is_equal(1)
	assert_bool(presenter.play_out_calls[0]["type"] == &"fade").override_failure_message(
			case_name).is_true()


func test_failed_catalog_goes_to_content_error() -> void:
	# Arrange: a fresh BOOT machine over a stub catalog scripted FAILED.
	var env: Dictionary = _fresh_boot_machine()
	var machine: GameStateMachine = env["machine"]
	var catalog: StubCatalog = env["catalog"]
	var presenter: StubTransitionPresenter = env["presenter"]
	catalog.state = ContentCatalogService.State.FAILED

	var order: Array[StringName] = []
	machine.transition_started.connect(func(_from: int, _to: int) -> void:
			order.append(&"transition_started"))
	machine.mode_exited.connect(func(_from: int) -> void: order.append(&"mode_exited"))
	machine.mode_entered.connect(func(_to: int) -> void: order.append(&"mode_entered"))
	machine.transition_finished.connect(func(_to: int) -> void:
			order.append(&"transition_finished"))

	# Act
	machine.tick(0.0)
	_run_to_idle(machine)

	# Assert: Content Error, through a zero-duration `none`, with the four
	# signals fired in order.
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CONTENT_ERROR)
	assert_int(presenter.play_out_calls.size()).is_equal(1)
	assert_bool(presenter.play_out_calls[0]["type"] == &"none").is_true()
	assert_float(presenter.play_out_calls[0]["duration"]).is_equal(0.0)
	assert_bool(presenter.play_in_calls[0]["type"] == &"none").is_true()
	assert_float(presenter.play_in_calls[0]["duration"]).is_equal(0.0)
	assert_array(order).is_equal([
		&"transition_started", &"mode_exited", &"mode_entered", &"transition_finished",
	])


## A fresh BOOT machine over a stub catalog starting UNLOADED, with its own
## doubles (not the shared Overworld fixture, which already runs Boot -> Title).
func _fresh_boot_machine() -> Dictionary:
	var loader := StubSceneLoader.new()
	var presenter := StubTransitionPresenter.new()
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog := StubCatalog.new()
	var quit_spy := QuitSpy.new()
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	return {"machine": machine, "loader": loader, "presenter": presenter,
			"config": cfg, "catalog": catalog, "log": game_log, "quit_spy": quit_spy}


func _on_transition_started(_from: int, _to: int) -> void:
	_started_count += 1


## Bounded 1/60s-tick loop until the transition reaches IDLE, as in every
## other test in this suite.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
