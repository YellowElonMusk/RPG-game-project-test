## Story 002, AC-3: every row of the GDD's Modes transitions table succeeds
## from its source mode, driven through its own trigger. Written to the QA
## Test Cases in
## `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`
## -- no new cases invented.
extends GdUnitTestSuite

## GDD anchor, transcribed from `design/gdd/game-state-scene-flow.md`
## "States and Transitions" -> "Modes" table. The in-mode fade row (Overworld
## -> Overworld, same instance, checkpoint redirect) is excluded on purpose
## (story 028 owns it) and never appears in `GameStateMachine._TRANSITION_TYPES`.
const _EXPECTED_ROWS: Array = [
	[GameStateMachine.Mode.BOOT, GameStateMachine.Mode.TITLE, &"fade"],
	[GameStateMachine.Mode.BOOT, GameStateMachine.Mode.CONTENT_ERROR, &"none"],
	[GameStateMachine.Mode.TITLE, GameStateMachine.Mode.OVERWORLD, &"fade"],
	[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.BATTLE, &"battle_wipe"],
	[GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.OVERWORLD, &"battle_wipe_reverse"],
	[GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.BATTLE, &"retry_flash"],
	[GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.CAMP, &"fade"],
	[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.CAMP, &"fade"],
	[GameStateMachine.Mode.CAMP, GameStateMachine.Mode.OVERWORLD, &"fade"],
	[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.OVERWORLD, &"fade"],
	[GameStateMachine.Mode.OVERWORLD, GameStateMachine.Mode.TITLE, &"fade"],
	[GameStateMachine.Mode.CAMP, GameStateMachine.Mode.TITLE, &"fade"],
	[GameStateMachine.Mode.BATTLE, GameStateMachine.Mode.TITLE, &"fade"],
]

## One case per row above, plus a second trigger for BATTLE -> OVERWORLD
## (Victory and Fled both reach the same row through different entry points,
## per the Implementation Notes). `trigger_id` selects the branch in
## `test_row_succeeds` below; the case name documents `FROM_TO_trigger`.
const _ROW_CASES: Array = [
	["BOOT_TITLE_catalog_ready", &"boot_title"],
	["BOOT_CONTENT_ERROR_catalog_failed", &"boot_content_error"],
	["TITLE_OVERWORLD_request_transition", &"title_overworld"],
	["OVERWORLD_BATTLE_request_transition", &"overworld_battle"],
	["BATTLE_OVERWORLD_victory_results_done", &"battle_overworld_victory"],
	["BATTLE_OVERWORLD_fled", &"battle_overworld_fled"],
	["BATTLE_BATTLE_retry", &"battle_battle_retry"],
	["BATTLE_CAMP_retreat", &"battle_camp_retreat"],
	["OVERWORLD_CAMP_request_transition", &"overworld_camp"],
	["CAMP_OVERWORLD_request_transition", &"camp_overworld"],
	["OVERWORLD_OVERWORLD_map_change", &"overworld_overworld_map_change"],
	["OVERWORLD_TITLE_menu_quit", &"overworld_title_menu"],
	["CAMP_TITLE_menu_quit", &"camp_title_menu"],
	["BATTLE_TITLE_menu_quit", &"battle_title_menu"],
]

## Instance-level capture bag for the Overworld -> Camp SWAP-ordering
## assertion (`overworld_camp` case): populated by the two signal callbacks
## below, which read `_capture["machine"]` rather than a closed-over local, so
## they can be connected/disconnected per-case without lambdas.
var _capture: Dictionary = {}


func test_table_matches_gdd() -> void:
	# Arrange/Act: flatten GameStateMachine._TRANSITION_TYPES into the same
	# (from, to) -> type shape as _EXPECTED_ROWS.
	var actual: Dictionary = {}
	for from_mode: int in GameStateMachine._TRANSITION_TYPES:
		var row: Dictionary = GameStateMachine._TRANSITION_TYPES[from_mode]
		for to_mode: int in row:
			actual[Vector2i(from_mode, to_mode)] = row[to_mode]

	var expected: Dictionary = {}
	for case: Array in _EXPECTED_ROWS:
		expected[Vector2i(case[0], case[1])] = case[2]

	# Assert: same set of (from, to) pairs, and each row's type matches the GDD.
	assert_int(actual.size()).override_failure_message(
			"GameStateMachine._TRANSITION_TYPES has a different row count than the GDD").is_equal(
			expected.size())
	for key: Vector2i in expected:
		assert_bool(actual.has(key)).override_failure_message(
				"missing row from=%d to=%d" % [key.x, key.y]).is_true()
		if actual.has(key):
			assert_that(actual[key]).override_failure_message(
					"row from=%d to=%d has transition type %s, GDD says %s" %
					[key.x, key.y, actual[key], expected[key]]).is_equal(expected[key])


func test_row_succeeds(case_name: String, trigger_id: StringName,
		test_parameters := _ROW_CASES) -> void:
	match trigger_id:
		&"boot_title":
			var env: Dictionary = _machine_fresh_boot(true)
			var machine: GameStateMachine = env["machine"]
			machine.tick(0.0)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.TITLE)

		&"boot_content_error":
			var env: Dictionary = _machine_fresh_boot(false)
			var machine: GameStateMachine = env["machine"]
			machine.tick(0.0)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.CONTENT_ERROR)

		&"title_overworld":
			var env: Dictionary = _machine_at_title()
			var machine: GameStateMachine = env["machine"]
			var result: GameStateMachine.RequestResult = machine.request_transition(
					GameStateMachine.Mode.OVERWORLD, null)
			assert_int(result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.OVERWORLD)

		&"overworld_battle":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			var loader: StubSceneLoader = env["loader"]
			var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
			battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
			loader.current_mode_node_value = battle_stub
			var result: GameStateMachine.RequestResult = machine.request_transition(
					GameStateMachine.Mode.BATTLE, GameStateFixtures.valid_battle_entry())
			assert_int(result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.BATTLE)

		&"battle_overworld_victory":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_enter_battle(machine, env["loader"], true, false)
			var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
					GameStateMachine.BattleResult.VICTORY)
			assert_int(outcome_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			assert_int(machine.current_mode).override_failure_message(
					case_name + ": Victory waits for report_results_done").is_equal(
					GameStateMachine.Mode.BATTLE)
			var results_result: GameStateMachine.RequestResult = machine.report_results_done()
			assert_int(results_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.OVERWORLD)

		&"battle_overworld_fled":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_enter_battle(machine, env["loader"], true, false)
			var fled_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
					GameStateMachine.BattleResult.FLED)
			assert_int(fled_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.OVERWORLD)

		&"battle_battle_retry":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			var loader: StubSceneLoader = env["loader"]
			_enter_battle(machine, loader, true, false)
			var begin_swap_before: int = loader.begin_swap_count
			var defeat_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
					GameStateMachine.BattleResult.DEFEAT)
			assert_int(defeat_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			var retry_result: GameStateMachine.RequestResult = machine.choose_retry()
			assert_int(retry_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.BATTLE)
			assert_int(loader.begin_swap_count).override_failure_message(
					case_name + ": Retry must not call begin_swap (zero loads)").is_equal(
					begin_swap_before)

		&"battle_camp_retreat":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			var loader: StubSceneLoader = env["loader"]
			machine.register_camp("camp_a")
			_enter_battle(machine, loader, true, true)
			var defeat_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
					GameStateMachine.BattleResult.DEFEAT)
			assert_int(defeat_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			var retreat_result: GameStateMachine.RequestResult = machine.choose_retreat()
			assert_int(retreat_result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.CAMP)
			assert_str(machine.last_camp_id).override_failure_message(case_name).is_equal("camp_a")

		&"overworld_camp":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_capture.clear()
			_capture["machine"] = machine
			machine.mode_exited.connect(_on_capture_mode_exited)
			machine.mode_entered.connect(_on_capture_mode_entered)
			var payload := CampEntryPayload.new()
			payload.camp_id = "camp_a"
			var result: GameStateMachine.RequestResult = machine.request_transition(
					GameStateMachine.Mode.CAMP, payload)
			assert_int(result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			machine.mode_exited.disconnect(_on_capture_mode_exited)
			machine.mode_entered.disconnect(_on_capture_mode_entered)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.CAMP)
			assert_str(machine.last_camp_id).override_failure_message(case_name).is_equal("camp_a")
			assert_str(_capture.get("at_exit", "unset")).override_failure_message(
					case_name + ": last_camp_id must not be set yet at mode_exited").is_equal("")
			assert_str(_capture.get("at_entry", "unset")).override_failure_message(
					case_name + ": last_camp_id must already be camp_a by mode_entered").is_equal(
					"camp_a")

		&"camp_overworld":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_enter_camp(machine, "camp_a")
			var result: GameStateMachine.RequestResult = machine.request_transition(
					GameStateMachine.Mode.OVERWORLD, null)
			assert_int(result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.OVERWORLD)

		&"overworld_overworld_map_change":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			var loader: StubSceneLoader = env["loader"]
			var begin_swap_before: int = loader.begin_swap_count
			var result: GameStateMachine.RequestResult = machine.request_transition(
					GameStateMachine.Mode.OVERWORLD, null)
			assert_int(result).override_failure_message(case_name).is_equal(
					GameStateMachine.RequestResult.OK)
			_run_to_idle(machine)
			assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
					GameStateMachine.Mode.OVERWORLD)
			assert_int(loader.begin_swap_count).override_failure_message(
					case_name + ": a map change is a fresh instance -- the loader must be asked"
					).is_equal(begin_swap_before + 1)

		&"overworld_title_menu":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_quit_to_title_via_menu(machine, case_name)

		&"camp_title_menu":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_enter_camp(machine, "camp_a")
			_quit_to_title_via_menu(machine, case_name)

		&"battle_title_menu":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			var machine: GameStateMachine = env["machine"]
			_enter_battle(machine, env["loader"], true, false)
			_quit_to_title_via_menu(machine, case_name)

		_:
			assert_bool(false).override_failure_message(
					"unknown trigger_id: %s" % trigger_id).is_true()

	# Every row ends IDLE (shared across every branch above).
	assert_int(_last_machine_phase).override_failure_message(case_name).is_equal(
			GameStateMachine.Phase.IDLE)


## AC-3 (exit rows): Quit from Title directly, and from the Menu open over
## each of Overworld, Camp and Battle -- the exit row covers both halves of
## the GDD's "Title / Menu -> (exit)".
const _EXIT_CASES: Array = [
	["TITLE_exit", &"title"],
	["OVERWORLD_menu_exit", &"overworld"],
	["CAMP_menu_exit", &"camp"],
	["BATTLE_menu_exit", &"battle"],
]


func test_exit_rows(case_name: String, source: StringName, test_parameters := _EXIT_CASES) -> void:
	var machine: GameStateMachine
	var quit_spy: QuitSpy

	match source:
		&"title":
			var env: Dictionary = _machine_at_title()
			machine = env["machine"]
			quit_spy = env["quit_spy"]
		&"overworld":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			machine = env["machine"]
			quit_spy = env["quit_spy"]
			machine.open_overlay(GameStateMachine.OverlayKind.MENU)
		&"camp":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			machine = env["machine"]
			quit_spy = env["quit_spy"]
			_enter_camp(machine, "camp_a")
			machine.open_overlay(GameStateMachine.OverlayKind.MENU)
		&"battle":
			var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
			machine = env["machine"]
			quit_spy = env["quit_spy"]
			_enter_battle(machine, env["loader"], true, false)
			machine.open_overlay(GameStateMachine.OverlayKind.MENU)
		_:
			assert_bool(false).override_failure_message(
					"unknown source: %s" % source).is_true()
			return

	var result: GameStateMachine.RequestResult = machine.request_quit()
	assert_int(result).override_failure_message(case_name).is_equal(
			GameStateMachine.RequestResult.OK)
	assert_int(quit_spy.call_count).override_failure_message(case_name).is_equal(1)


## Tracks the phase most recently observed by a branch of `test_row_succeeds`,
## read by its shared trailing assertion.
var _last_machine_phase: GameStateMachine.Phase = GameStateMachine.Phase.IDLE


func _on_capture_mode_exited(_from: int) -> void:
	var machine: GameStateMachine = _capture["machine"]
	_capture["at_exit"] = machine.last_camp_id


func _on_capture_mode_entered(_to: int) -> void:
	var machine: GameStateMachine = _capture["machine"]
	_capture["at_entry"] = machine.last_camp_id


## A fresh BOOT machine (not the shared Overworld fixture, which already runs
## Boot -> Title). `catalog_ready` picks `READY` or `FAILED`.
func _machine_fresh_boot(catalog_ready: bool) -> Dictionary:
	var loader := StubSceneLoader.new()
	var presenter := StubTransitionPresenter.new()
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog := StubCatalog.new()
	catalog.state = ContentCatalogService.State.READY if catalog_ready \
			else ContentCatalogService.State.FAILED
	var quit_spy := QuitSpy.new()
	var game_log := SpyGameStateLog.new()
	var machine := GameStateMachine.new(
			loader, presenter, cfg, catalog, quit_spy.as_callable(), game_log)
	return {"machine": machine, "loader": loader, "presenter": presenter,
			"config": cfg, "log": game_log, "quit_spy": quit_spy}


## A machine already idle in TITLE, reached only through Boot -> Title.
func _machine_at_title() -> Dictionary:
	var env: Dictionary = _machine_fresh_boot(true)
	var machine: GameStateMachine = env["machine"]
	machine.tick(0.0)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.TITLE)
	return env


## Drives `machine` (already idle in OVERWORLD) into BATTLE with a descriptor
## built for the case: `can_flee` and `retreat_allowed` as given. Returns the
## installed `StubBattleMode`.
func _enter_battle(machine: GameStateMachine, loader: StubSceneLoader,
		can_flee: bool, retreat_allowed: bool) -> StubBattleMode:
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub
	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.can_flee = can_flee
	descriptor.retreat_allowed = retreat_allowed
	payload.descriptor = descriptor
	payload.party = []
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)
	return battle_stub


## Drives `machine` (already idle in OVERWORLD) into CAMP via the ordinary
## Overworld -> Camp row.
func _enter_camp(machine: GameStateMachine, camp_id: String) -> void:
	var payload := CampEntryPayload.new()
	payload.camp_id = camp_id
	var result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.CAMP, payload)
	assert_int(result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)


## Opens the Menu then requests TITLE through it (story 025's Quit to Title),
## and asserts the row finished in TITLE with the overlay stack empty.
func _quit_to_title_via_menu(machine: GameStateMachine, case_name: String) -> void:
	var open_result: GameStateMachine.RequestResult = machine.open_overlay(
			GameStateMachine.OverlayKind.MENU)
	assert_int(open_result).override_failure_message(case_name).is_equal(
			GameStateMachine.RequestResult.OK)
	var quit_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.TITLE, null)
	assert_int(quit_result).override_failure_message(case_name).is_equal(
			GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).override_failure_message(case_name).is_equal(
			GameStateMachine.Mode.TITLE)
	assert_int(machine.overlay_stack.size()).override_failure_message(case_name).is_equal(0)


## Bounded 1/60s-tick loop until the transition reaches IDLE (as in every
## other test in this suite). Also records the phase for `test_row_succeeds`'s
## shared trailing assertion.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
	_last_machine_phase = machine.phase
