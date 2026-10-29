## Story 138 (AC-138a-d; stories 007, 080, 081): the real `GameRoot` boots
## New Game into Town; walking into Town's MapExit runs Game State's
## `OVERWORLD -> OVERWORLD` fresh-instance map change to the segment's
## EntryPoint, and back. Drives the production `GameStateMachine` the way
## `playable_overworld_loop_test.gd` does.
extends GdUnitTestSuite

const _GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const _DATA_ROOT: String = "res://data"
const _TOWN_ID: String = "map_paris_town_placeholder"
const _SEG_ID: String = "map_paris_segment_placeholder"
const _CLERKS: Array[String] = ["enc_paris_clerks_west", "enc_paris_clerks_east"]
const _DT: float = 1.0 / 60.0
## Frames a walk toward an exit may take before the test gives up.
const _WALK_FRAMES_MAX: int = 240


func test_town_exit_arrives_at_segment_entry_with_followers_snapped() -> void:
	var root: GameRoot = _boot()
	var town: OverworldMode = _new_game(root)
	var seg: OverworldMode = _walk_through_exit(root, town, Vector2.RIGHT)
	assert_bool(is_same(seg, town)).is_false()
	assert_str(seg.get_map().map_id).is_equal(_SEG_ID)
	assert_bool(is_same(seg.world_state, root.world_state)).is_true()
	assert_str(root.world_state.map_id).is_equal(_SEG_ID)
	var entry: EntryPoint = seg.get_map().find_entry_point(&"from_town")
	assert_object(entry).is_not_null()
	_assert_party_at_entry(seg, entry)


func test_segment_exit_returns_to_town_entry() -> void:
	var root: GameRoot = _boot()
	var seg: OverworldMode = _walk_through_exit(root, _new_game(root), Vector2.RIGHT)
	var town: OverworldMode = _walk_through_exit(root, seg, Vector2.LEFT)
	assert_str(town.get_map().map_id).is_equal(_TOWN_ID)
	assert_str(root.world_state.map_id).is_equal(_TOWN_ID)
	_assert_party_at_entry(town, town.get_map().find_entry_point(&"from_segment"))


func test_held_move_after_arrival_does_not_refire() -> void:
	var root: GameRoot = _boot()
	var seg: OverworldMode = _walk_through_exit(root, _new_game(root), Vector2.RIGHT)
	var frames: int = ceili(2.0 / _DT)
	for i: int in frames:
		seg.step_frame(_DT, Vector2.RIGHT)
	assert_int(seg.exit_requests).is_equal(0)
	assert_int(root.machine.phase).is_equal(GameStateMachine.Phase.IDLE)
	assert_bool(is_same(root.current_mode_node(), seg)).is_true()


func test_leader_placed_inside_exit_fires_only_after_leaving_and_reentering() -> void:
	var root: GameRoot = _boot()
	var seg: OverworldMode = _walk_through_exit(root, _new_game(root), Vector2.RIGHT)
	var rect: Rect2 = seg.get_map().map_exits()[0].trigger_rect
	seg.set_leader_position(rect.get_center())
	for i: int in 10:
		seg.step_frame(_DT, Vector2.ZERO)
	seg.step_frame(_DT, Vector2.DOWN * 0.1)
	assert_int(seg.exit_requests).is_equal(0)
	seg.set_leader_position(Vector2(rect.end.x + 0.5, rect.get_center().y))
	for i: int in _WALK_FRAMES_MAX:
		if seg.exit_requests > 0:
			break
		seg.step_frame(_DT, Vector2.LEFT)
	assert_int(seg.exit_requests).is_equal(1)
	assert_int(root.machine.phase).is_not_equal(GameStateMachine.Phase.IDLE)


func test_town_has_no_symbols_and_segment_has_both_clerks() -> void:
	var root: GameRoot = _boot()
	var town: OverworldMode = _new_game(root)
	assert_int(town.get_map().symbol_markers().size()).is_equal(0)
	assert_int(town.get_encounter_sources().size()).is_equal(0)
	var seg: OverworldMode = _walk_through_exit(root, town, Vector2.RIGHT)
	var ids: Array[String] = []
	for source: EncounterSource in seg.get_encounter_sources():
		ids.append(source.enc_id)
	ids.sort()
	var expected: Array[String] = _CLERKS.duplicate()
	expected.sort()
	assert_array(ids).is_equal(expected)


func test_victory_then_walk_to_town_and_back_respawns_per_policy() -> void:
	var root: GameRoot = _boot()
	var seg: OverworldMode = _walk_through_exit(root, _new_game(root), Vector2.RIGHT)
	var machine: GameStateMachine = root.machine
	var source: EncounterSource = seg.get_encounter_sources()[0]
	var rec: EncounterData = root.catalog().get_record(&"encounter", source.enc_id) as EncounterData
	seg.grace_active = false
	seg.set_leader_position(source.brain.position)
	seg.step_frame(_DT, Vector2.ZERO)
	_run_to_idle(machine)
	var battle_mode: BattleMode = root.current_mode_node() as BattleMode
	assert_object(battle_mode).is_not_null()
	DebugLaunchArgs.force_outcome(battle_mode.battle, DebugLaunchArgs.VICTORY)
	assert_int(machine.report_results_done()).is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(machine)
	assert_bool(root.world_state.is_resolved(_SEG_ID, source.symbol_id)).is_true()
	assert_int(seg.get_encounter_sources().size()).is_equal(_CLERKS.size() - 1)
	var town: OverworldMode = _walk_through_exit(root, seg, Vector2.LEFT)
	var again: OverworldMode = _walk_through_exit(root, town, Vector2.RIGHT)
	var respawns: bool = WorldState.respawn_of(rec) == WorldState.Respawn.ON_MAP_REENTER
	assert_bool(root.world_state.is_resolved(_SEG_ID, source.symbol_id)).is_equal(not respawns)
	assert_int(again.get_encounter_sources().size()) \
			.is_equal(_CLERKS.size() if respawns else _CLERKS.size() - 1)


func _assert_party_at_entry(ow: OverworldMode, entry: EntryPoint) -> void:
	var pos: Vector2 = entry.ground_position(ow.get_map())
	assert_vector(ow.get_leader_position()).is_equal_approx(pos, Vector2.ONE * 0.001)
	assert_vector(ow.get_leader_facing()).is_equal_approx(entry.facing.normalized(), Vector2.ONE * 0.001)
	var followers: Array[Vector2] = ow.get_follower_positions()
	assert_int(followers.size()).is_equal(ow.config.max_followers)
	var grid: WalkGrid = ow.get_walk_grid()
	for i: int in followers.size():
		assert_bool(grid.is_walkable(grid.cell_of(followers[i]))).is_true()
		assert_float((followers[i] - pos).dot(entry.facing.normalized())).is_less(0.0)


## Places the leader just outside the map's first exit on the `dir` side and
## walks `dir` until Game State starts the map change; returns the new mode.
func _walk_through_exit(root: GameRoot, ow: OverworldMode, dir: Vector2) -> OverworldMode:
	var rect: Rect2 = ow.get_map().map_exits()[0].trigger_rect
	ow.set_leader_position(rect.get_center() - dir * (rect.size.x * 0.5 + 0.5))
	for i: int in _WALK_FRAMES_MAX:
		if root.machine.phase != GameStateMachine.Phase.IDLE:
			break
		ow.step_frame(_DT, dir)
	assert_int(ow.exit_requests).is_equal(1)
	_run_to_idle(root.machine)
	var next: OverworldMode = root.current_mode_node() as OverworldMode
	assert_object(next).is_not_null()
	next.set_process(false)
	return next


func _boot() -> GameRoot:
	var root: GameRoot = preload(_GAME_ROOT_SCENE).instantiate()
	root.data_root_override = _DATA_ROOT
	add_child(root)
	auto_free(root)
	_run_to_idle(root.machine)
	return root


func _new_game(root: GameRoot) -> OverworldMode:
	assert_int(root.machine.request_transition(GameStateMachine.Mode.OVERWORLD, null)) \
			.is_equal(GameStateMachine.RequestResult.OK)
	_run_to_idle(root.machine)
	var ow: OverworldMode = root.current_mode_node() as OverworldMode
	ow.set_process(false)
	return ow


func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(_DT)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks").is_true()
