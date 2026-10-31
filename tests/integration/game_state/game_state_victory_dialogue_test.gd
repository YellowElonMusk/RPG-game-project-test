## Story 036, AC-24 [I] (ADR-0002 §4; GDD Edge Cases "A story dialogue never
## opens over a half-revealed scene"): a Victory that triggers story dialogue
## opens the Dialogue overlay only after `transition_finished(OVERWORLD)`.
## Real `GameStateMachine` + production `ModeHostSceneLoader` (with an
## `OverlayHost`, story 030's production overlay push) + the real
## `battle_mode.tscn`, same wiring as `game_state_battle_mode_test.gd`
## (story 034). Written to the QA Test Cases in
## production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md
## -- no new cases invented.
extends GdUnitTestSuite


## Breaks each test's machine/loader RefCounted cycle (they leaked otherwise).
func after_test() -> void:
	GameStateFixtures.dispose_tracked()

const _FIXTURES_DIR: String = "res://tests/integration/game_state/fixtures/"
const _BATTLE_MODE_SCENE: String = "res://src/battle/battle_mode.tscn"


## The real roster factories read the shipped catalog (content-migration
## story 024).
func before() -> void:
	BattleContentSeam.ensure_catalog()


func test_dialogue_after_transition_finished() -> void:
	var mode_host := Node.new()
	var overlay_host := Node.new()
	add_child(mode_host)
	add_child(overlay_host)

	var cfg: TransitionConfig = GameStateFixtures.make_transition_config()
	cfg.mode_scene_paths = {
		GameStateMachine.Mode.OVERWORLD: _FIXTURES_DIR + "chapter_mode_with_story_dialogue.tscn",
		GameStateMachine.Mode.BATTLE: _BATTLE_MODE_SCENE,
	}
	cfg.overlay_scene_paths = {
		GameStateMachine.OverlayKind.DIALOGUE: _FIXTURES_DIR + "stub_dialogue_overlay.tscn",
	}

	var recorder := SequenceRecorder.new()
	var game_log := SpyGameStateLog.new()
	var machine_box: Array = [null]
	var pre_setup := func(mode: GameMode, payload: RefCounted) -> void:
		mode.setup(machine_box[0], payload)
	# Same result getter GameRoot binds (story 035): the return swap carries
	# no payload, so on_thawed() reads the machine's last result.
	var result_getter := func() -> int:
		return (machine_box[0] as GameStateMachine).last_battle_result
	var loader := ModeHostSceneLoader.new(
			mode_host, cfg, game_log, pre_setup, result_getter, overlay_host, Callable())
	var machine := GameStateMachine.new(
			loader, StubTransitionPresenter.new(recorder), cfg,
			GameStateFixtures.make_ready_catalog(), QuitSpy.new(recorder).as_callable(), game_log)
	machine_box[0] = machine
	loader.set_machine(machine)
	GameStateFixtures.track(machine)
	machine.mode_entered.connect(loader.on_mode_entered)
	recorder.attach(machine)
	var source := SyntheticActionSource.new()
	machine.bind_action_source(source)

	machine.tick(0.0)
	_run_to_idle(machine)
	machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)
	_run_to_idle(machine)
	var chapter := loader.current_mode_node() as ChapterModeWithStoryDialogue
	assert_object(chapter).is_not_null()

	# Scripted Victory: enter Battle and attack the lone Clerk until it falls.
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "bureaucratia_fight_0"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	descriptor.can_flee = true
	var squad: Array[Combatant] = [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 10, 12, 8, 10, false),
	]
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = squad
	assert_int(machine.request_transition(GameStateMachine.Mode.BATTLE, payload)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	var battle_mode := loader.current_mode_node() as BattleMode
	assert_object(battle_mode).is_not_null()
	var battle: BattleCore = battle_mode.battle
	var rounds: int = 0
	while battle.state == BattleCore.State.SQUAD_TURN and rounds < 100:
		battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
		rounds += 1
	assert_int(battle.state).is_equal(BattleCore.State.WON)
	battle_mode.settle_replay()

	# Victory -> report_results_done (the banner confirm) -> return to Overworld.
	recorder.clear()
	source.press(InputActions.CONFIRM)
	_run_to_idle(machine)

	assert_int(machine.current_mode).is_equal(GameStateMachine.Mode.OVERWORLD)
	assert_object(loader.current_mode_node()).override_failure_message(
			"the frozen Overworld was not re-attached").is_same(chapter)
	assert_int(chapter.thaw_calls.size()).is_equal(1)
	assert_int(chapter.thaw_attempt_result).override_failure_message(
			"the Dialogue open inside on_thawed was not rejected as busy") \
			.is_equal(GameStateMachine.RequestResult.REJECTED_BUSY)
	assert_int(chapter.retry_result).override_failure_message(
			"the retry on transition_finished(OVERWORLD) did not succeed") \
			.is_equal(GameStateMachine.RequestResult.OK)

	var finished_index: int = _index_of_with_arg(
			recorder, &"transition_finished", GameStateMachine.Mode.OVERWORLD)
	var dialogue_index: int = _index_of_with_arg(
			recorder, &"overlay_opened", GameStateMachine.OverlayKind.DIALOGUE)
	assert_int(finished_index).is_greater_equal(0)
	assert_int(dialogue_index).override_failure_message(
			"Dialogue opened at %d, not after transition_finished(OVERWORLD) at %d"
			% [dialogue_index, finished_index]).is_greater(finished_index)
	assert_int(_count_with_arg(recorder, &"overlay_opened",
			GameStateMachine.OverlayKind.DIALOGUE)).override_failure_message(
			"Dialogue opened more than once").is_equal(1)
	assert_object(loader.current_overlay_node()).is_not_null()
	assert_int(overlay_host.get_child_count()).is_equal(1)

	# Edge cases: the Battle node is freed, the frozen Overworld re-attached,
	# and nothing is orphaned on teardown.
	assert_bool(not is_instance_valid(battle_mode) or battle_mode.is_queued_for_deletion()) \
			.override_failure_message("the Battle mode was not freed on return").is_true()
	assert_object(loader.frozen_overworld_node()).is_null()
	assert_object(chapter.get_parent()).is_same(mode_host)
	assert_int(machine.close_overlay()).is_equal(GameStateMachine.RequestResult.OK)
	mode_host.queue_free()
	overlay_host.queue_free()
	await await_idle_frame()
	assert_bool(is_instance_valid(battle_mode)).override_failure_message(
			"the Battle mode survived teardown").is_false()
	assert_bool(is_instance_valid(chapter)).override_failure_message(
			"the re-attached Overworld survived teardown").is_false()


func _index_of_with_arg(recorder: SequenceRecorder, event: StringName, arg: int) -> int:
	for i in range(recorder.events.size()):
		var entry: Dictionary = recorder.events[i]
		if entry["event"] == event and (entry["args"] as Array)[0] == arg:
			return i
	return -1


func _count_with_arg(recorder: SequenceRecorder, event: StringName, arg: int) -> int:
	var count: int = 0
	for entry: Dictionary in recorder.events:
		if entry["event"] == event and (entry["args"] as Array)[0] == arg:
			count += 1
	return count


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
