## Story 068, AC-27d (GDD rule 13, the walk home): after a boss Victory and
## its post-battle Dialogue, the next transition is a map change to the
## segment's dungeon-side EntryPoint, liberated, with the dungeon exit taped
## off. Entering Town advances step A to B, and the chapter ends only from
## Yes in the café's "End the chapter here?" prompt on step B (No focused;
## No or `cancel` returns to free roam). `cancel` and `menu` during the
## Dialogue and the fade, and a Save -> Continue in the free roam, all
## still lead to the same segment load and café end. Drives real GameRoots.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _SAVE_DIR: String = "user://test_saves_068"
const _CHAMBER: String = "map_paris_boss_chamber_placeholder"
const _SEGMENT: String = "map_paris_segment_placeholder"
const _TOWN: String = "map_paris_town_placeholder"
const _DT: float = 1.0 / 60.0


func before_test() -> void:
	_clear_saves()


func after_test() -> void:
	_clear_saves()


func test_boss_victory_walks_home_to_the_cafe_end() -> void:
	var root: GameRoot = _new_game()
	_beat_the_boss(root)
	var segment: OverworldMode = _walk_home_lands_liberated(root)
	_town_then_cafe_end(root, segment)


func test_save_and_continue_in_the_free_roam_keeps_the_walk_home() -> void:
	var root: GameRoot = _new_game()
	_beat_the_boss(root)
	var segment: OverworldMode = _walk_home_lands_liberated(root)
	segment.step_frame(_DT, Vector2.ZERO)
	assert_int(root.save_service().save_to_slot(1)).is_equal(SaveService.SaveResult.OK)
	root.queue_free()
	await get_tree().process_frame
	var again: GameRoot = _boot()
	(again.current_mode_node() as TitleMode)._on_continue_pressed()
	_run_to_idle(again.machine)
	var back: OverworldMode = again.current_mode_node() as OverworldMode
	back.set_process(false)
	assert_str(back.get_map().map_id).is_equal(_SEGMENT)
	assert_str(again.world_state.chapter_step).is_equal("step_walk_home_a")
	_assert_taped(back)
	_town_then_cafe_end(again, back)


func test_the_cafe_on_step_a_only_offers_rest() -> void:
	var root: GameRoot = _new_game()
	var town: OverworldMode = root.current_mode_node() as OverworldMode
	root.world_state.chapter_step = "step_walk_home_a"
	_stand_at_cafe(town)
	town.handle_action(InputActions.CONFIRM, true)
	assert_bool(town.camp_prompt_is_chapter_end).is_false()
	assert_int(town.camp_prompt_focus).is_equal(OverworldMode.CampChoice.YES)
	town.handle_action(InputActions.CANCEL, true)
	assert_int(town.chapter_end_calls).is_equal(0)


func _beat_the_boss(root: GameRoot) -> void:
	var chamber: OverworldMode = _go(root, _CHAMBER, &"from_dungeon")
	var source: EncounterSource = chamber.get_encounter_sources()[0]
	chamber.grace_active = false
	chamber.set_leader_position(source.brain.position + Vector2(0.0, 1.0))
	var frames: int = 0
	while root.machine.phase == GameStateMachine.Phase.IDLE and frames < 120:
		chamber.step_frame(_DT, Vector2.UP)
		frames += 1
	_run_to_idle(root.machine)
	DebugLaunchArgs.force_outcome((root.current_mode_node() as BattleMode).battle, DebugLaunchArgs.VICTORY)
	assert_int(root.machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	# The post-battle Dialogue is up on the reveal; cancel and menu are
	# swallowed, and only its confirm (past the input guard) closes it.
	assert_array(root.machine.overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	var line: InterimLineDialogue = root.current_overlay_node() as InterimLineDialogue
	assert_str(line.text).contains("resignation")
	assert_str(root.world_state.chapter_step).is_equal("step_leave_town")
	line.handle_action(InputActions.CANCEL, true)
	line.handle_action(InputActions.MENU, true)
	assert_array(root.machine.overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	line.advance_guard(0.2)
	line.handle_action(InputActions.CONFIRM, true)
	# The next transition is the walk home's map change, already under way.
	assert_int(root.machine.phase).is_not_equal(GameStateMachine.Phase.IDLE)
	assert_str(root.world_state.chapter_step).is_equal("step_walk_home_a")
	# Presses during the fade change nothing.
	root.machine.tick(_DT)
	var fading: Node = root.current_mode_node()
	if fading is OverworldMode:
		(fading as OverworldMode).handle_action(InputActions.CANCEL, true)
		(fading as OverworldMode).handle_action(InputActions.MENU, true)
	_run_to_idle(root.machine)


func _walk_home_lands_liberated(root: GameRoot) -> OverworldMode:
	var segment: OverworldMode = root.current_mode_node() as OverworldMode
	segment.set_process(false)
	assert_str(segment.get_map().map_id).is_equal(_SEGMENT)
	var entry: EntryPoint = segment.get_map().find_entry_point(&"from_dungeon")
	assert_vector(segment.get_leader_position()).is_equal(entry.ground_position(segment.get_map()))
	assert_str(String(segment.presentation_profile_id)).is_equal("overworld_liberated")
	assert_int(segment.get_encounter_sources().size()).is_equal(0)
	_assert_taped(segment)
	return segment


func _assert_taped(segment: OverworldMode) -> void:
	assert_bool(segment.get_map().get_node("PlaceholderSet/Tape_exit_to_dungeon").visible).is_true()
	var grid: WalkGrid = segment.get_walk_grid()
	assert_bool(grid.is_walkable(Vector2i(21, 1))).is_false()
	assert_bool(grid.is_walkable(Vector2i(22, 1))).is_false()


func _town_then_cafe_end(root: GameRoot, segment: OverworldMode) -> void:
	# Step A's leg ends at the Town exit; entering Town advances to B.
	var town: OverworldMode = _go(root, _TOWN, &"from_segment")
	assert_str(root.world_state.chapter_step).is_equal("step_walk_home_b")
	var leg: CriticalPathLeg = (root.catalog().get_record(&"map", _TOWN) as MapData).critical_path[1]
	assert_str(leg.to).is_equal("camp_cafe")
	_stand_at_cafe(town)
	var ends: Array = []
	town.chapter_end_requested.connect(func() -> void: ends.append(true))
	# No is focused: confirm closes with nothing.
	town.handle_action(InputActions.CONFIRM, true)
	assert_bool(town.camp_prompt_is_chapter_end).is_true()
	assert_int(town.camp_prompt_focus).is_equal(OverworldMode.CampChoice.NO)
	town.handle_action(InputActions.CONFIRM, true)
	assert_object(town.get_camp_prompt_camp()).is_null()
	# cancel closes with nothing.
	town.handle_action(InputActions.CONFIRM, true)
	town.handle_action(InputActions.CANCEL, true)
	assert_object(town.get_camp_prompt_camp()).is_null()
	assert_int(town.chapter_end_calls).is_equal(0)
	assert_int(town.camp_requests).is_equal(0)
	# Yes ends the chapter, once.
	town.handle_action(InputActions.CONFIRM, true)
	town.handle_action(InputActions.MOVE_LEFT, true)
	town.handle_action(InputActions.CONFIRM, true)
	assert_int(town.chapter_end_calls).is_equal(1)
	assert_array(ends).has_size(1)
	assert_int(town.camp_requests).is_equal(0)


func _stand_at_cafe(town: OverworldMode) -> void:
	var cafe: Vector2 = town.get_map().camp_spots()[0].ground_position(town.get_map())
	town.set_leader_position(cafe + Vector2(0.0, 1.0))
	town.set_leader_facing(Vector2.UP)


func _new_game() -> GameRoot:
	var root: GameRoot = _boot()
	(root.current_mode_node() as TitleMode)._on_new_game_pressed()
	_run_to_idle(root.machine)
	(root.current_mode_node() as OverworldMode).set_process(false)
	return root


func _go(root: GameRoot, map_id: String, entry: StringName) -> OverworldMode:
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD,
			MapEntryPayload.new(map_id, entry))).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var mode: OverworldMode = root.current_mode_node() as OverworldMode
	mode.set_process(false)
	mode.tick_timed_text(60.0)
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
	assert_bool(ticks < 600).override_failure_message("transition did not finish").is_true()


func _clear_saves() -> void:
	var dir := DirAccess.open(_SAVE_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)
