## Story 070, AC-28a (GDD rule 10): with the requirement met, `confirm`
## opens the checkpoint, frees its cells, and it stays open across a save
## and load. With the requirement already met when the map loads, it stays
## closed until `confirm`.
extends GdUnitTestSuite

const _CP: StringName = &"cp_fixture_met"
const _FLAG: String = "fixture_met_permit"
const _CELLS: Array[Vector2i] = [Vector2i(5, 4), Vector2i(6, 4)]


func test_confirm_with_the_requirement_met_opens_and_frees_the_cells() -> void:
	var mode: OverworldMode = _mode(WorldState.new())
	mode.world_state.set_flag(_FLAG)
	_assert_cells(mode, false)
	mode.confirm_checkpoint(_CP)
	assert_bool(mode.is_checkpoint_open(_CP)).is_true()
	_assert_cells(mode, true)


func test_an_opened_checkpoint_stays_open_across_save_and_load() -> void:
	var mode: OverworldMode = _mode(WorldState.new())
	mode.world_state.set_flag(_FLAG)
	mode.confirm_checkpoint(_CP)
	var restored := WorldState.new()
	restored.from_dict(_through_json(mode.world_state.to_dict()))
	var again: OverworldMode = _mode(restored)
	assert_bool(again.is_checkpoint_open(_CP)).is_true()
	_assert_cells(again, true)


func test_a_requirement_met_before_the_load_stays_closed_until_confirm() -> void:
	var ws := WorldState.new()
	ws.set_flag(_FLAG)
	var mode: OverworldMode = _mode(ws)
	assert_bool(mode.is_checkpoint_open(_CP)).is_false()
	_assert_cells(mode, false)
	mode.confirm_checkpoint(_CP)
	assert_bool(mode.is_checkpoint_open(_CP)).is_true()
	_assert_cells(mode, true)


func _assert_cells(mode: OverworldMode, walkable: bool) -> void:
	for cell: Vector2i in _CELLS:
		assert_bool(mode.get_walk_grid().is_walkable(cell)).is_equal(walkable)


## The participant's stage reads JSON numbers back as floats; emulate it.
func _through_json(d: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	parsed["party_pos"] = Vector2(parsed["party_pos"][0], parsed["party_pos"][1])
	parsed["party_facing"] = Vector2(parsed["party_facing"][0], parsed["party_facing"][1])
	return parsed


func _mode(ws: WorldState) -> OverworldMode:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			RequestSpyMachine.new(), OverworldConfig.new(), Vector2(5.5, 6.5), []))
	mode.world_state = ws
	var cp: CheckpointMarker = auto_free(CheckpointMarker.new())
	cp.marker_id = _CP
	cp.requirement_flag = _FLAG
	cp.failure_outcome = CheckpointMarker.FailureOutcome.REDIRECT
	cp.blocked_rect = Rect2(5, 4, 2, 1)
	cp.position = Vector3(5.5, 0.0, 5.3)
	cp.return_marker = Vector2(5.5, 8.0)
	mode.add_checkpoint(cp)
	return mode
