## Story 128, AC-56 (GDD rule 0, SAFE bake): a cell whose nearest point lies
## 0.01 m inside a safe-zone source's radius is tagged `SAFE` even though
## its centre is outside; a cell 0.01 m outside is not. Checked for an
## EntryPoint, a MapExit rectangle and a CampSpot at `safe_radius_m`, and a
## checkpoint return marker at `return_safe_radius_m`, each read from a map
## built in code through `OverworldMap.safe_sources()`.
extends GdUnitTestSuite

const _GRID: Vector2i = Vector2i(24, 12)
## The probed cell: column 18 on row 5, nearest point x = 18.0.
const _CELL: Vector2i = Vector2i(18, 5)
const _ROW_Y: float = 5.5
const _MARGIN: float = 0.01


func test_entry_point_boundary() -> void:
	var cfg := OverworldConfig.new()
	_assert_boundary(cfg.safe_radius_m, func(map: OverworldMap, x: float) -> void:
		var entry := EntryPoint.new()
		entry.marker_id = &"from_test"
		entry.position = Vector3(x, 0.0, _ROW_Y)
		map.add_child(entry))


func test_map_exit_rectangle_boundary() -> void:
	var cfg := OverworldConfig.new()
	# The rectangle's right edge sits at x; its centre is 1 m further left.
	_assert_boundary(cfg.safe_radius_m, func(map: OverworldMap, x: float) -> void:
		var exit := MapExit.new()
		exit.marker_id = &"exit_test"
		exit.trigger_rect = Rect2(x - 2.0, _ROW_Y - 0.5, 2.0, 1.0)
		map.add_child(exit))


func test_camp_spot_boundary() -> void:
	var cfg := OverworldConfig.new()
	_assert_boundary(cfg.safe_radius_m, func(map: OverworldMap, x: float) -> void:
		var camp := CampSpot.new()
		camp.marker_id = &"camp_test"
		camp.position = Vector3(x, 0.0, _ROW_Y)
		map.add_child(camp))


func test_return_marker_boundary_uses_the_smaller_radius() -> void:
	var cfg := OverworldConfig.new()
	_assert_boundary(cfg.return_safe_radius_m, func(map: OverworldMap, x: float) -> void:
		var cp := CheckpointMarker.new()
		cp.marker_id = &"cp_test"
		cp.position = Vector3(1.5, 0.0, 1.5)
		cp.return_marker = Vector2(x, _ROW_Y)
		map.add_child(cp))


func test_rect_distance_is_between_nearest_points() -> void:
	assert_float(WalkGrid.rect_distance(Rect2(0, 0, 1, 1), Rect2(3, 0, 1, 1))).is_equal_approx(2.0, 1e-6)
	assert_float(WalkGrid.rect_distance(Rect2(0, 0, 1, 1), Rect2(4, 5, 0, 0))).is_equal_approx(5.0, 1e-6)
	assert_float(WalkGrid.rect_distance(Rect2(0, 0, 2, 2), Rect2(1, 1, 3, 3))).is_equal(0.0)


## Places a source (via `place(map, x)`) whose nearest point to `_CELL`
## (x = 18.0) is `radius - _MARGIN` away, then `radius + _MARGIN` away, and
## asserts `_CELL` is SAFE only in the first case, with its centre (18.5)
## outside the radius both times.
func _assert_boundary(radius: float, place: Callable) -> void:
	var cfg := OverworldConfig.new()
	for inside: bool in [true, false]:
		var source_x: float = float(_CELL.x) - (radius - _MARGIN if inside else radius + _MARGIN)
		var map := OverworldMap.new()
		place.call(map, source_x)
		var grid: WalkGrid = _open_grid()
		grid.apply_safe_sources(map.safe_sources(cfg))
		map.free()
		var centre_d: float = float(_CELL.x) + 0.5 - source_x
		assert_float(centre_d).is_greater(radius)
		assert_bool(grid.is_safe(_CELL)).override_failure_message(
				"source %.2f m from the cell's nearest point: expected SAFE = %s"
				% [float(_CELL.x) - source_x, inside]).is_equal(inside)


func _open_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID
	grid.cell_m = 1.0
	grid.cells.resize(_GRID.x * _GRID.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
