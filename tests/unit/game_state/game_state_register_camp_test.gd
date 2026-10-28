## Story 020, AC-28: `register_camp` is the second input to `last_camp_id`,
## legal only in Overworld/IDLE; a later Retreat goes to the camp it set, and
## an outside write to `last_camp_id` is rejected. Written to the QA Test
## Cases in
## `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`
## -- no new cases invented.
extends GdUnitTestSuite


func test_walk_past_registers_and_retreat_goes_there() -> void:
	# Arrange: OVERWORLD, IDLE; an unsaved-progress spy.
	var recorder := SequenceRecorder.new()
	# No recorder here: this spy's own call must not register as a "signal
	# recorded by register_camp" below -- its count is read separately.
	var unsaved_spy := UnsavedProgressSpy.new()
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld(
			recorder, null, unsaved_spy.as_callable())
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	recorder.clear()

	# Act: register_camp while OVERWORLD/IDLE.
	machine.register_camp("camp_b")

	# Assert: last_camp_id set immediately, no signal recorded, dirty spy
	# marked once.
	assert_str(machine.last_camp_id).is_equal("camp_b")
	assert_int(recorder.events.size()).is_equal(0)
	assert_int(unsaved_spy.call_count).is_equal(1)

	# Act: Overworld -> Battle (retreat_allowed true), then Defeat.
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub

	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.retreat_allowed = true
	payload.descriptor = descriptor
	payload.party = []

	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	var outcome_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(outcome_result).is_equal(GameStateMachine.RequestResult.OK)

	# Act: choose_retreat(), run to IDLE.
	var retreat_result: GameStateMachine.RequestResult = machine.choose_retreat()
	assert_int(retreat_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)

	# Assert: the begin_swap payload is a CampEntryPayload with
	# camp_id == "camp_b"; free_frozen_overworld called once; mode CAMP.
	var camp_payload: CampEntryPayload = loader.last_begin_swap_args[2] as CampEntryPayload
	assert_object(camp_payload).is_not_null()
	assert_str(camp_payload.camp_id).is_equal("camp_b")
	assert_int(loader.free_frozen_overworld_count).is_equal(1)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)


func test_outside_write_rejected() -> void:
	# Arrange: OVERWORLD, IDLE, a camp already registered.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var game_log: SpyGameStateLog = env["log"]
	machine.register_camp("camp_a")

	# Act: a write from outside the machine.
	machine.last_camp_id = "hacked"

	# Assert: value unchanged, rejection logged.
	assert_str(machine.last_camp_id).is_equal("camp_a")
	var found: bool = false
	for entry: Dictionary in game_log.entries:
		if entry["code"] == &"last_camp_write_rejected":
			found = true
	assert_bool(found).override_failure_message(
			"expected a last_camp_write_rejected log entry").is_true()


func test_register_ignored_outside_overworld() -> void:
	# Case: TITLE (before the Title -> Overworld request) -- a fresh machine
	# driven only through Boot -> Title.
	var loader_title := StubSceneLoader.new()
	var presenter_title := StubTransitionPresenter.new()
	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	var catalog_title: StubCatalog = GameStateFixtures.make_ready_catalog()
	var log_title := SpyGameStateLog.new()
	var machine_title := GameStateMachine.new(
			loader_title, presenter_title, cfg, catalog_title, Callable(), log_title)
	machine_title.tick(0.0)
	machine_title.tick(cfg.t_out[&"fade"])
	machine_title.tick(0.0)
	machine_title.tick(cfg.t_in[&"fade"])
	assert_int(machine_title.current_mode).is_equal(GameStateMachine.Mode.TITLE)
	machine_title.register_camp("camp_title")
	assert_str(machine_title.last_camp_id).is_equal("")
	assert_bool(_has_log_code(log_title, &"register_camp_wrong_mode")).is_true()

	# Arrange: OVERWORLD, IDLE baseline for the remaining cases.
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var game_log: SpyGameStateLog = env["log"]

	# Case: empty string in OVERWORLD/IDLE is ignored.
	machine.register_camp("")
	assert_str(machine.last_camp_id).is_equal("")
	assert_bool(_has_log_code(game_log, &"empty_camp_id")).is_true()

	# Case: BATTLE is not OVERWORLD -- ignored.
	var battle_stub: StubBattleMode = auto_free(StubBattleMode.new())
	battle_stub.snapshot_to_return = GameStateFixtures.make_overworld_snapshot()
	loader.current_mode_node_value = battle_stub
	var payload := BattleEntryPayload.new()
	var descriptor: EncounterDescriptor = GameStateFixtures.make_encounter_descriptor()
	descriptor.retreat_allowed = true
	payload.descriptor = descriptor
	payload.party = []
	var entry_result: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.BATTLE)

	machine.register_camp("camp_c")
	assert_str(machine.last_camp_id).is_equal("")

	# Case: OVERWORLD with phase != IDLE -- report Fled to start the return
	# transition, then register mid-transition (phase OUT), ignored.
	var fled_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.FLED)
	assert_int(fled_result).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(machine.phase).is_not_equal(GameStateMachine.Phase.IDLE)
	machine.register_camp("camp_d")
	assert_str(machine.last_camp_id).is_equal("")
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)

	# Edge case: a later register_camp in OVERWORLD/IDLE overwrites.
	machine.register_camp("camp_c")
	assert_str(machine.last_camp_id).is_equal("camp_c")

	# Case: CAMP -- register a second camp, Retreat there, then ignored
	# while in CAMP.
	machine.register_camp("camp_e")
	var entry_result_2: GameStateMachine.RequestResult = machine.request_transition(
			GameStateMachine.Mode.BATTLE, payload)
	assert_int(entry_result_2).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	var defeat_result: GameStateMachine.RequestResult = machine.report_battle_outcome(
			GameStateMachine.BattleResult.DEFEAT)
	assert_int(defeat_result).is_equal(GameStateMachine.RequestResult.OK)
	var retreat_result: GameStateMachine.RequestResult = machine.choose_retreat()
	assert_int(retreat_result).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.CAMP)

	machine.register_camp("camp_f")
	assert_str(machine.last_camp_id).is_equal("camp_e")
	assert_bool(_has_log_code(game_log, &"register_camp_wrong_mode")).is_true()


## True if `log_sink` recorded at least one entry with `code`.
func _has_log_code(log_sink: SpyGameStateLog, code: StringName) -> bool:
	for entry: Dictionary in log_sink.entries:
		if entry["code"] == code:
			return true
	return false


## Bounded 1/60s-tick loop until the transition reaches IDLE.
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
