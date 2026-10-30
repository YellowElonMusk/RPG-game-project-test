## Story 132, AC-55 (GDD Edge Cases): a resize to an aspect narrower than
## 4:3 logs exactly one warning and the game runs on; a blocker freed while
## a symbol's path ran round it invalidates the stored path and the notice
## cache at once, and the symbol's next repath, in its own turn, crosses the
## freed cells (nothing is recomputed out of turn).
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
## A 16 x 9 open grid; a wall on column 8, rows 0-4, with the leader east of
## it and the symbol west: the path runs round the wall's south end.
const _SIZE: Vector2i = Vector2i(16, 9)
const _SYMBOL: Vector2 = Vector2(5.5, 1.5)
const _LEADER: Vector2 = Vector2(12.5, 1.5)


func test_one_warning_per_narrow_resize_and_none_for_supported_aspects() -> void:
	var camera: FollowCamera = auto_free(FollowCamera.from_config(PresentationConfig.new()))
	for aspect: float in [4.0 / 3.0, 16.0 / 9.0, 21.0 / 9.0]:
		assert_bool(camera.note_resize(aspect)).is_false()
	assert_int(camera.narrow_aspect_warnings).is_equal(0)
	assert_bool(camera.note_resize(1.0)).is_true()
	assert_int(camera.narrow_aspect_warnings).is_equal(1)
	# The game runs on: the camera still steps at the narrow aspect.
	var stepped: Vector2 = camera.advance(Vector2(5.0, 5.0), _DT, 1.0, Vector2.ZERO, Vector2(40.0, 40.0))
	assert_bool(stepped.is_finite()).is_true()
	assert_int(camera.narrow_aspect_warnings).is_equal(1)
	assert_bool(camera.note_resize(0.9)).is_true()
	assert_int(camera.narrow_aspect_warnings).is_equal(2)


func test_a_freed_blocker_invalidates_at_once_and_is_used_on_the_next_turn() -> void:
	var cfg := OverworldConfig.new()
	# Wide notice and give-up radii, so the detour round the wall is noticed
	# and chased (this test is about path invalidation, not notice range).
	cfg.symbol_chase_m = 8.0
	cfg.notice_path_cap_m = 14.0
	cfg.symbol_giveup_m = 30.0
	var grid := _grid()
	var wall: Array[Vector2i] = []
	for y: int in 5:
		wall.append(Vector2i(8, y))
	grid.set_blocked(wall, true)
	var brain := SymbolBrain.new(PackedVector2Array([_SYMBOL]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.Facing.SE
	# Notice: the route installed then runs round the wall's end.
	var frames: int = 0
	while brain.sub_state != SymbolBrain.SubState.CHASING and frames < 300:
		brain.step(_DT, _LEADER, grid, false, cfg)
		frames += 1
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	assert_bool(_route_crosses_column(brain, 8, 5)).override_failure_message("route not round the wall").is_false()
	var repaths: int = brain.repaths_run
	# Free the wall: the route and notice cache are stale at once...
	grid.set_blocked(wall, false)
	assert_int(int(brain.get("_route_revision"))).is_not_equal(grid.revision())
	assert_bool(int(brain.get("_cache_rev")) != grid.revision() or not bool(brain.get("_cache_valid"))).is_true()
	# ...but no repath before its turn (`repath_s` since the last).
	var since: float = float(brain.get("_since_repath"))
	var turn_in: int = ceili((cfg.repath_s - since) / _DT)
	for i: int in maxi(turn_in - 2, 0):
		brain.step(_DT, _LEADER, grid, false, cfg)
		assert_int(brain.repaths_run).is_equal(repaths)
	frames = 0
	while brain.repaths_run == repaths and frames < 120:
		brain.step(_DT, _LEADER, grid, false, cfg)
		frames += 1
	assert_int(brain.repaths_run).is_equal(repaths + 1)
	# The new route crosses the freed column above the old wall end.
	assert_bool(_route_crosses_column(brain, 8, 5) or brain.get("_route").is_empty()).is_true()
	assert_int(int(brain.get("_route_revision"))).is_equal(grid.revision())


## True when the symbol's stored route (from its position) passes through
## column `x` above row `below_y`: through the wall's cells, not round them.
func _route_crosses_column(brain: SymbolBrain, x: int, below_y: int) -> bool:
	var points: Array[Vector2] = [brain.position]
	for w: Vector2 in brain.get("_route"):
		points.append(w)
	for i: int in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		for s: int in 21:
			var p: Vector2 = a.lerp(b, s / 20.0)
			if floori(p.x) == x and floori(p.y) < below_y:
				return true
	return false


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_SIZE.x * _SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
