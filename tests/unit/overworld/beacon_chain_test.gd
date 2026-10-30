## Story 112, AC-45c (GDD Overworld rule 19): only the current leg's beacon
## chain is lit, its last beacon on the leg's end; the objective line equals
## the step's objective; the optional arrow follows the walk-grid path's next
## segment toward the next beacon and hides while it is on screen.
extends GdUnitTestSuite

const STEP_SEGMENT: String = "step_reach_prefecture"
const STEP_HOME: String = "step_walk_home_a"
const STEP_TOWN: String = "step_leave_town"
const END_TO_DUNGEON: StringName = &"bc_segment_to_dungeon_end"
const END_HOME: StringName = &"bc_segment_home_end"
const EXTRA_ID: StringName = &"bc_s112_extra"
## The extra beacon, two cells east of the open spot on the same row.
const EXTRA_AT: Vector2 = ProbeFixture.OPEN_SPOT + Vector2(2.5, 0.0)


func _beacon(id: StringName, leg: String, order: int, at: Vector2) -> WaypointBeacon:
	var bc := WaypointBeacon.new()
	bc.marker_id = id
	bc.leg_id = leg
	bc.order = order
	bc.position = Vector3(at.x, 0.0, at.y)
	return bc


func _mode_on(step_id: String, extras: Array = []) -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode(extras))
	mode.world_state.chapter_step = step_id
	mode.refresh_beacons()
	return mode


func _lit_ids(mode: OverworldMode) -> Array[StringName]:
	var out: Array[StringName] = []
	for bc: WaypointBeacon in mode.get_map().beacons():
		if bc.lit:
			out.append(bc.marker_id)
	return out


## Open grid with a wall at column 2, rows 0..3 (open only at row 4).
func _walled_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = Vector2i(5, 5)
	grid.cell_m = 1.0
	grid.cells.resize(25)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	for y: int in 4:
		grid.cells[y * 5 + 2] = 0
	return grid


# --- Lit chain ---------------------------------------------------------------

func test_current_leg_chain_lit_others_unlit() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT)
	assert_str(mode.current_leg_id()).is_equal("segment_to_dungeon")
	assert_array(_lit_ids(mode)).contains_exactly([END_TO_DUNGEON])


func test_step_change_moves_the_lit_chain() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT)
	mode.world_state.chapter_step = STEP_HOME
	mode.refresh_beacons()
	assert_array(_lit_ids(mode)).contains_exactly([END_HOME])


func test_step_on_another_map_lights_nothing() -> void:
	var mode: OverworldMode = _mode_on(STEP_TOWN)
	assert_str(mode.current_leg_id()).is_empty()
	assert_array(_lit_ids(mode)).is_empty()
	assert_object(mode.next_beacon()).is_null()


func test_lit_chain_is_ordered_and_ends_on_the_leg_end() -> void:
	var extra := _beacon(EXTRA_ID, "segment_to_dungeon", 0, EXTRA_AT)
	var mode: OverworldMode = _mode_on(STEP_SEGMENT, [extra])
	var chain: Array[WaypointBeacon] = mode.lit_chain()
	assert_int(chain.size()).is_equal(2)
	assert_str(String(chain[0].marker_id)).is_equal(String(EXTRA_ID))
	assert_str(String(chain[-1].marker_id)).is_equal(String(END_TO_DUNGEON))
	assert_bool(extra.lit).is_true()


func test_lit_changed_signal_fires_on_toggle() -> void:
	var bc: WaypointBeacon = auto_free(WaypointBeacon.new())
	var seen: Array = []
	bc.lit_changed.connect(func(on: bool) -> void: seen.append(on))
	bc.lit = true
	bc.lit = true
	bc.lit = false
	assert_array(seen).contains_exactly([true, false])


# --- Objective line ----------------------------------------------------------

func test_objective_line_equals_each_steps_objective() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT)
	for step: ChapterStep in mode.chapter_steps().steps:
		mode.world_state.chapter_step = step.id
		assert_str(mode.objective_line()).is_equal(step.objective)


func test_objective_line_empty_without_a_step() -> void:
	var mode: OverworldMode = _mode_on("")
	assert_str(mode.objective_line()).is_empty()


# --- Arrow -------------------------------------------------------------------

func test_arrow_hidden_by_default() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT,
			[_beacon(EXTRA_ID, "segment_to_dungeon", 0, EXTRA_AT)])
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	assert_bool(mode.show_next_destination).is_false()
	assert_bool(mode.next_destination_arrow().visible).is_false()


func test_arrow_on_points_along_path_with_shape_glyph() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT,
			[_beacon(EXTRA_ID, "segment_to_dungeon", 0, EXTRA_AT)])
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	mode.show_next_destination = true
	var arrow: BeaconGuide.Arrow = mode.next_destination_arrow()
	assert_bool(arrow.visible).is_true()
	assert_vector(arrow.direction).is_equal(Vector2.RIGHT)
	assert_str(String(arrow.target_marker_id)).is_equal(String(EXTRA_ID))
	assert_str(arrow.glyph).is_equal(mode.config.next_destination_glyph)
	assert_str(arrow.glyph).is_not_empty()


func test_arrow_hidden_while_beacon_on_screen() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT,
			[_beacon(EXTRA_ID, "segment_to_dungeon", 0, EXTRA_AT)])
	ProbeFixture.stand(mode, ProbeFixture.OPEN_SPOT, Vector2.RIGHT)
	mode.show_next_destination = true
	mode.beacon_on_screen = func(_at: Vector2) -> bool: return true
	assert_bool(mode.next_destination_arrow().visible).is_false()


func test_reaching_a_beacon_moves_arrow_to_the_next() -> void:
	var mode: OverworldMode = _mode_on(STEP_SEGMENT,
			[_beacon(EXTRA_ID, "segment_to_dungeon", 0, EXTRA_AT)])
	ProbeFixture.stand(mode, EXTRA_AT, Vector2.RIGHT)
	mode.step_frame(0.0, Vector2.ZERO)
	assert_str(String(mode.next_beacon().marker_id)).is_equal(String(END_TO_DUNGEON))


# --- BeaconGuide logic ---------------------------------------------------------

func test_path_direction_goes_around_a_wall_not_through_it() -> void:
	var grid: WalkGrid = _walled_grid()
	var dir: Vector2 = BeaconGuide.new().path_direction(grid, Vector2(0.5, 0.5), Vector2(4.5, 0.5))
	assert_bool(dir.is_zero_approx()).is_false()
	assert_float(dir.y).is_greater(0.0)
	assert_bool(grid.is_walkable(grid.cell_of(Vector2(0.5, 0.5) + dir * grid.cell_m))).is_true()


func test_path_direction_zero_when_runtime_blocked_closes_the_way() -> void:
	var grid: WalkGrid = _walled_grid()
	var guide := BeaconGuide.new()
	assert_bool(guide.path_direction(grid, Vector2(0.5, 0.5), Vector2(4.5, 0.5)).is_zero_approx()).is_false()
	var gap: Array[Vector2i] = [Vector2i(2, 4)]
	grid.set_blocked(gap, true)
	assert_vector(guide.path_direction(grid, Vector2(0.5, 0.5), Vector2(4.5, 0.5))).is_equal(Vector2.ZERO)


func test_advance_progress_uses_reach_radius_from_config() -> void:
	for reach: float in [OverworldConfig.new().beacon_reach_m, 0.4]:
		var root: Node3D = auto_free(Node3D.new())
		var a := _beacon(&"a", "leg", 0, Vector2(0.0, 0.0))
		var b := _beacon(&"b", "leg", 1, Vector2(10.0, 0.0))
		root.add_child(a)
		root.add_child(b)
		var chain: Array[WaypointBeacon] = [a, b]
		var inside: Vector2 = Vector2(reach * 0.9, 0.0)
		var outside: Vector2 = Vector2(reach * 1.1, 0.0)
		assert_int(BeaconGuide.advance_progress(chain, -1, outside, root, reach)).is_equal(-1)
		assert_int(BeaconGuide.advance_progress(chain, -1, inside, root, reach)).is_equal(0)
		# Progress never goes back.
		assert_int(BeaconGuide.advance_progress(chain, 1, inside, root, reach)).is_equal(1)


func test_next_index_clamps_to_the_last_beacon() -> void:
	assert_int(BeaconGuide.next_index(0, -1)).is_equal(-1)
	assert_int(BeaconGuide.next_index(3, -1)).is_equal(0)
	assert_int(BeaconGuide.next_index(3, 2)).is_equal(2)


func test_arrow_shown_needs_setting_direction_and_offscreen() -> void:
	assert_bool(BeaconGuide.arrow_shown(true, Vector2.RIGHT, false)).is_true()
	assert_bool(BeaconGuide.arrow_shown(false, Vector2.RIGHT, false)).is_false()
	assert_bool(BeaconGuide.arrow_shown(true, Vector2.ZERO, false)).is_false()
	assert_bool(BeaconGuide.arrow_shown(true, Vector2.RIGHT, true)).is_false()
