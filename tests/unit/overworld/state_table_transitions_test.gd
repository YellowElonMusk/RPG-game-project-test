## Story 097, AC-37 (GDD States and Transitions): over every row of the
## table, each entry produces its state and each listed exit its target, as
## `OverworldMode.table_state()` reports it. A rejected encounter returns to
## Exploring with contact pending; a failed map load restores the old map.
## The café's chapter-end prompt is its own row, distinct from CampPrompt.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _AT: Vector2 = ProbeFixture.OPEN_SPOT
const _AHEAD: Vector2 = ProbeFixture.OPEN_SPOT + Vector2(0.0, -1.0)
const _DT: float = 1.0 / 60.0
const S := OverworldMode.TableState


func test_exploring_after_placement_and_reveal() -> void:
	assert_int(_mode([]).table_state()).is_equal(S.EXPLORING)


func test_npc_line_interacts_and_closing_returns_to_exploring() -> void:
	var mode: OverworldMode = _facing([ProbeFixture.npc(_AHEAD)])
	mode.confirm()
	assert_int(mode.table_state()).is_equal(S.INTERACTING)
	_machine(mode).close_overlay()
	assert_int(mode.table_state()).is_equal(S.EXPLORING)


func test_gag_line_interacts_and_a_change_stays_exploring() -> void:
	var mode: OverworldMode = _facing([ProbeFixture.gag(_AHEAD)])
	mode.confirm()
	assert_int(mode.table_state()).is_equal(S.INTERACTING)
	_machine(mode).close_overlay()
	# A change plays its change and stays in Exploring: no overlay (story 118).
	var gag: GagInteractable = ProbeFixture.gag(_AHEAD, GagInteractable.Response.CHANGE)
	var changer: OverworldMode = _facing([gag])
	changer.confirm()
	assert_array(_machine(changer).overlay_stack).is_empty()
	assert_int(changer.table_state()).is_equal(S.EXPLORING)
	assert_object(changer.probe()).is_not_same(gag)


func test_failed_checkpoint_interacts_then_redirects_then_explores() -> void:
	var mode: OverworldMode = _mode([])
	mode.add_checkpoint(_checkpoint(CheckpointMarker.FailureOutcome.REDIRECT))
	mode.confirm_checkpoint(&"cp_state_fixture")
	assert_int(mode.table_state()).is_equal(S.INTERACTING)
	_machine(mode).close_overlay()
	assert_int(mode.table_state()).is_equal(S.REDIRECTING)
	_run_to_idle(_machine(mode))
	assert_int(mode.table_state()).is_equal(S.EXPLORING)
	assert_float(mode.get_grace_left()).is_equal(mode.config.encounter_grace_s)


func test_met_checkpoint_opens_and_stays_exploring() -> void:
	var mode: OverworldMode = _mode([])
	var cp: CheckpointMarker = _checkpoint(CheckpointMarker.FailureOutcome.REDIRECT)
	mode.add_checkpoint(cp)
	mode.world_state.set_flag(cp.requirement_flag)
	mode.confirm_checkpoint(cp.marker_id)
	assert_bool(mode.is_checkpoint_open(cp.marker_id)).is_true()
	assert_int(mode.table_state()).is_equal(S.EXPLORING)


func test_encounter_outcome_checkpoint_and_static_confirm_start_encounters() -> void:
	var spy := RequestSpyMachine.new()
	var mode: OverworldMode = _mode([ProbeFixture.static_symbol(_AHEAD)], spy)
	var cp: CheckpointMarker = _checkpoint(CheckpointMarker.FailureOutcome.ENCOUNTER)
	mode.add_checkpoint(cp)
	mode.confirm_checkpoint(cp.marker_id)
	assert_int(mode.table_state()).is_equal(S.FROZEN)
	var again: OverworldMode = _mode([ProbeFixture.static_symbol(_AHEAD)], RequestSpyMachine.new())
	ProbeFixture.stand(again, _AT, Vector2.UP)
	again.confirm()
	assert_int(again.table_state()).is_equal(S.FROZEN)


func test_accepted_encounter_freezes_and_rejected_returns_to_exploring() -> void:
	var spy := RequestSpyMachine.new()
	var mode: OverworldMode = _mode([], spy)
	var source: EncounterSource = mode.get_encounter_sources()[0]
	spy.scripted.append(GameStateMachine.RequestResult.REJECTED_BUSY)
	mode.start_encounter(source.enc_id, source)
	assert_int(mode.table_state()).is_equal(S.EXPLORING)
	assert_bool(source.brain.contact_pending).is_true()
	mode.start_encounter(source.enc_id, source)
	assert_int(mode.table_state()).is_equal(S.FROZEN)


func test_frozen_thaws_to_exploring_on_the_reveal() -> void:
	var spy := RequestSpyMachine.new()
	var mode: OverworldMode = _mode([], spy)
	var source: EncounterSource = mode.get_encounter_sources()[0]
	mode.start_encounter(source.enc_id, source)
	mode.on_thawed(source.enc_id, GameStateMachine.BattleResult.VICTORY)
	assert_int(mode.table_state()).is_equal(S.FROZEN)
	spy.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	assert_int(mode.table_state()).is_equal(S.EXPLORING)


func test_camp_prompt_rest_and_cancel() -> void:
	var mode: OverworldMode = _facing([ProbeFixture.camp(_AHEAD)])
	mode.confirm()
	assert_int(mode.table_state()).is_equal(S.CAMP_PROMPT)
	mode.handle_action(InputActions.CANCEL, true)
	assert_int(mode.table_state()).is_equal(S.EXPLORING)
	mode.confirm()
	mode.handle_action(InputActions.CONFIRM, true)
	assert_int(mode.camp_requests).is_equal(1)


func test_the_final_step_cafe_is_the_chapter_end_prompt_row() -> void:
	var camp: CampSpot = ProbeFixture.camp(_AHEAD)
	camp.is_region_default = true
	var mode: OverworldMode = _facing([camp])
	var steps := ChapterSteps.new()
	var step := ChapterStep.new()
	step.id = "step_fixture_final"
	steps.steps = [step] as Array[ChapterStep]
	mode.set_chapter_steps(steps)
	mode.world_state.chapter_step = step.id
	mode.confirm()
	assert_int(mode.table_state()).is_equal(S.CHAPTER_END_PROMPT)
	mode.handle_action(InputActions.CANCEL, true)
	assert_int(mode.table_state()).is_equal(S.EXPLORING)
	assert_int(mode.chapter_end_calls).is_equal(0)


func test_menu_pauses_and_closing_it_explores() -> void:
	var mode: OverworldMode = _mode([])
	_machine(mode).open_overlay(GameStateMachine.OverlayKind.MENU)
	assert_int(mode.table_state()).is_equal(S.PAUSED)
	_machine(mode).close_overlay()
	assert_int(mode.table_state()).is_equal(S.EXPLORING)


func test_map_change_and_a_failed_load_restores_the_old_map() -> void:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = "user://test_saves_097"
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	town.set_process(false)
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new("map_fixture_missing", &"nowhere"))).is_equal(GameStateMachine.RequestResult.OK)
	assert_int(town.table_state()).is_equal(S.MAP_CHANGING)
	_run_to_idle(root.machine)
	assert_bool(is_same(root.current_mode_node(), town)).is_true()
	assert_int(town.table_state()).is_equal(S.EXPLORING)
	# A good map change: the new map is revealed into Exploring.
	root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new("map_paris_segment_placeholder", &"from_town"))
	_run_to_idle(root.machine)
	var segment: OverworldMode = root.current_mode_node() as OverworldMode
	assert_int(segment.table_state()).is_equal(S.EXPLORING)


func _checkpoint(outcome: CheckpointMarker.FailureOutcome) -> CheckpointMarker:
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = &"cp_state_fixture"
	cp.requirement_flag = "fixture_state_permit"
	cp.failure_outcome = outcome
	cp.failure_line = "Not without a permit."
	cp.linked_encounter_id = "enc_paris_clerks_west"
	cp.blocked_rect = Rect2(11, 12, 2, 1)
	cp.position = Vector3(12.0, 0.0, 12.5)
	cp.return_marker = _AT
	cp.return_facing = Vector2.DOWN
	return cp


func _facing(extras: Array) -> OverworldMode:
	var mode: OverworldMode = _mode(extras)
	ProbeFixture.stand(mode, _AT, Vector2.UP)
	return mode


func _mode(extras: Array, machine: GameStateMachine = null) -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode(extras, machine))
	mode.grace_active = false
	return mode


func _machine(mode: OverworldMode) -> GameStateMachine:
	return mode.get("_machine")


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message("transition did not finish").is_true()
