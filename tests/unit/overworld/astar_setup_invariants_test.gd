## Story 131, AC-59 (pathing setup; the A* half): after the bake,
## `AStarGrid2D.is_dirty()` is false before every query, and `region`,
## `cell_size` and `offset` never change across queries and `set_blocked`
## calls; a `set_blocked` round trip on one cell leaves every other cell's
## solid flag unchanged. (The animation-frame clause waits on animated
## overworld sprites; the placeholder sprites show one static frame.)
extends GdUnitTestSuite


func test_queries_never_see_a_dirty_or_reshaped_astar() -> void:
	var grid: WalkGrid = _segment_grid()
	grid.find_path(_legal(grid, false), _legal(grid, true))
	var astar: AStarGrid2D = grid.get("_astar")
	var region: Rect2i = astar.region
	var cell_size: Vector2 = astar.cell_size
	var offset: Vector2 = astar.offset
	var cells: Array[Vector2i] = [Vector2i(12, 5), Vector2i(12, 6), Vector2i(13, 6)]
	for i: int in 6:
		grid.set_blocked(cells, i % 2 == 0)
		grid.find_path(_legal(grid, false), _legal(grid, true))
		assert_bool(astar.is_dirty()).is_false()
		assert_bool(grid.get("_astar") == astar).override_failure_message("A* was rebuilt").is_true()
		assert_object(astar.region).is_equal(region)
		assert_vector(astar.cell_size).is_equal(cell_size)
		assert_vector(astar.offset).is_equal(offset)


func test_a_set_blocked_round_trip_touches_only_its_cell() -> void:
	var grid: WalkGrid = _segment_grid()
	grid.find_path(_legal(grid, false), _legal(grid, true))
	var astar: AStarGrid2D = grid.get("_astar")
	var before: Dictionary = _solids(grid, astar)
	var cell := Vector2i(12, 5)
	grid.set_blocked([cell] as Array[Vector2i], true)
	grid.find_path(_legal(grid, false), _legal(grid, true))
	var during: Dictionary = _solids(grid, astar)
	for c: Vector2i in before:
		if c != cell:
			assert_bool(during[c]).override_failure_message("%s changed while blocking %s" % [c, cell]).is_equal(before[c])
	assert_bool(during[cell]).is_true()
	grid.set_blocked([cell] as Array[Vector2i], false)
	grid.find_path(_legal(grid, false), _legal(grid, true))
	assert_dict(_solids(grid, astar)).is_equal(before)


## The first (or last) symbol-legal cell in row order: a valid query end.
func _legal(grid: WalkGrid, last: bool) -> Vector2i:
	var found := Vector2i(-1, -1)
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			if grid.is_symbol_legal(Vector2i(x, y)):
				if not last:
					return Vector2i(x, y)
				found = Vector2i(x, y)
	return found


func _solids(grid: WalkGrid, astar: AStarGrid2D) -> Dictionary:
	var out: Dictionary = {}
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			out[Vector2i(x, y)] = astar.is_point_solid(Vector2i(x, y))
	return out


func _segment_grid() -> WalkGrid:
	var map: OverworldMap = auto_free((load("res://data/maps/paris_segment_placeholder.tscn") as PackedScene).instantiate())
	return map.bake_walk_grid(OverworldConfig.new())
