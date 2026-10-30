## Story 096, AC-36 (GDD Edge Cases): GIVEN a save made mid-chase with a
## resolved `on_map_reenter` Clerk, WHEN Continue runs, THEN every symbol is
## in Patrol at its origin, the resolved Clerk stays absent, and grace
## starts on the reveal. Two real `GameRoot`s on one test save folder.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_096"
const _SEGMENT: String = "map_paris_segment_placeholder"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear()


func after_test() -> void:
	_clear()


func test_continue_mid_chase_resets_symbols_to_patrol() -> void:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	var seg: OverworldMode = _go(root, _SEGMENT, &"from_town")
	# Beat the first Clerk (on_map_reenter respawn).
	var first: EncounterSource = seg.get_encounter_sources()[0]
	var resolved_id: String = first.symbol_id
	seg.grace_active = false
	seg.set_leader_position(first.brain.position + Vector2(0.0, 1.0))
	var frames: int = 0
	while root.machine.phase == GameStateMachine.Phase.IDLE and frames < 120:
		seg.step_frame(_DT, Vector2.UP)
		frames += 1
	_run_to_idle(root.machine)
	DebugLaunchArgs.force_outcome((root.current_mode_node() as BattleMode).battle, DebugLaunchArgs.VICTORY)
	root.machine.report_results_done()
	_run_to_idle(root.machine)
	assert_bool(root.world_state.is_resolved(_SEGMENT, resolved_id)).is_true()
	# Get the other Clerk chasing, then save mid-chase.
	var other: SymbolBrain = seg.get_encounter_sources()[0].brain
	seg.grace_active = false
	# Ahead of it on its patrol (it walks south from its spawn): in front.
	seg.set_leader_position(other.position + Vector2(0.0, 2.0))
	frames = 0
	while other.sub_state != SymbolBrain.SubState.CHASING and frames < 240:
		seg.step_frame(_DT, Vector2.ZERO)
		frames += 1
	assert_int(other.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	assert_int(root.save_service().save_to_slot(1)).is_equal(SaveService.SaveResult.OK)

	# Relaunch and Continue.
	root.queue_free()
	await get_tree().process_frame
	var again: GameRoot = _boot()
	var title: TitleMode = again.current_mode_node() as TitleMode
	title._on_continue_pressed()
	_run_to_idle(again.machine)
	var back: OverworldMode = again.current_mode_node() as OverworldMode
	assert_str(back.get_map().map_id).is_equal(_SEGMENT)
	assert_int(back.grace_starts).is_greater_equal(1)
	assert_float(back.get_grace_left()).is_equal(back.config.encounter_grace_s)
	var markers: Array[EncounterSymbol] = back.get_map().symbol_markers()
	var sources: Array[EncounterSource] = back.get_encounter_sources()
	assert_int(sources.size()).is_equal(markers.size() - 1)
	for source: EncounterSource in sources:
		assert_str(source.symbol_id).is_not_equal(resolved_id)
		assert_int(source.brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
		assert_vector(source.brain.position).is_equal(markers[source.brain.marker_index].patrol_path[0])


func _go(root: GameRoot, map_id: String, entry: StringName) -> OverworldMode:
	root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, MapEntryPayload.new(map_id, entry))
	_run_to_idle(root.machine)
	var mode: OverworldMode = root.current_mode_node() as OverworldMode
	mode.set_process(false)
	return mode


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = "res://data"
	root.save_dir_override = _SAVE_DIR
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).is_true()


func _clear() -> void:
	var dir := DirAccess.open(_SAVE_DIR)
	if dir != null:
		for f: String in dir.get_files():
			dir.remove(f)
