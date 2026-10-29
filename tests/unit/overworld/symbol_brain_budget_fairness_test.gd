## Story 028 (AC-9j, GDD rule 5 "Query budget"): notice searches, chase
## repaths and Returning paths share `repath_per_frame_max` per frame through
## a round-robin cursor -- every request is served within `ceil(N / B)`
## frames, the oldest deferred request first, whatever the marker order.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _GRID_SIZE: Vector2i = Vector2i(18, 18)
const _LEADER: Vector2 = Vector2(8.5, 8.5)
const _PATROL_SPOTS: Array[Vector2] = [
	Vector2(6.5, 8.5), Vector2(10.5, 8.5), Vector2(8.5, 6.5), Vector2(8.5, 10.5)]
const _RETURNER_START: Vector2 = Vector2(2.5, 2.5)
const _RETURNER_LEADER: Vector2 = Vector2(4.5, 2.5)
const _CHASER_START: Vector2 = Vector2(13.5, 2.5)
const _CHASER_LEADER: Vector2 = Vector2(15.5, 2.5)


func test_budget_serves_oldest_deferred_first_whatever_the_order() -> void:
	_assert_queue_order(OverworldConfig.new())


func test_budget_serves_oldest_deferred_first_with_custom_budget() -> void:
	var cfg := OverworldConfig.new()
	cfg.repath_per_frame_max = 3
	_assert_queue_order(cfg)


func test_mixed_substates_all_served_within_bound() -> void:
	_assert_mixed_served(OverworldConfig.new())


func test_mixed_substates_all_served_within_bound_with_custom_budget() -> void:
	var cfg := OverworldConfig.new()
	cfg.repath_per_frame_max = 3
	_assert_mixed_served(cfg)


## A notice query the budget defers counts as "not noticed this frame".
func test_deferred_notice_is_not_noticed_this_frame() -> void:
	var cfg := OverworldConfig.new()
	var grid := _grid()
	var budget := QueryBudget.new(cfg.repath_per_frame_max)
	budget.begin_frame()
	for i in cfg.repath_per_frame_max:
		assert_bool(budget.request(-100 - i)).is_true()
	var brain := _patrol_brain(_PATROL_SPOTS[0])
	brain.step(_DT, _LEADER, grid, false, cfg, budget)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	assert_int(brain.queries_granted).is_equal(0)
	budget.begin_frame()
	brain.step(_DT, _LEADER, grid, false, cfg, budget)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)


## Pure `QueryBudget`: N requesters ask on frame 1, in reverse marker order;
## on every later frame a new interloper asks first. Each original is still
## served within `ceil(N / B)` frames, in the order it was deferred.
func _assert_queue_order(cfg: OverworldConfig) -> void:
	var b: int = cfg.repath_per_frame_max
	var n: int = 3 * b + 1
	var bound: int = ceili(float(n) / float(b))
	var budget := QueryBudget.new(b)
	var served_frame: Dictionary[int, int] = {}
	var served_order: Array[int] = []
	var deferral_order: Array[int] = []
	for frame in range(1, bound + 2):
		budget.begin_frame()
		if frame > 1:
			budget.request(1000 + frame)  # Interloper: must not jump the queue.
		for k in n:
			var id: int = n - 1 - k
			if served_frame.has(id):
				continue
			if budget.request(id):
				served_frame[id] = frame
				served_order.append(id)
			elif frame == 1:
				deferral_order.append(id)
		assert_int(budget.granted_this_frame).is_less_equal(b)
	assert_int(served_frame.size()).is_equal(n)
	for id: int in served_frame:
		assert_int(served_frame[id]).is_less_equal(bound)
	# After frame 1's free grants, the deferred ones are served oldest first.
	assert_array(served_order.slice(b)).is_equal(deferral_order)


## Six symbols request on the same frame: four Patrol notice searches, one
## Returning path and one chase repath. Every one is granted within
## `ceil(N / B)` frames and no frame grants more than B.
func _assert_mixed_served(cfg: OverworldConfig) -> void:
	var grid := _grid()
	var brains: Array[SymbolBrain] = []
	for spot: Vector2 in _PATROL_SPOTS:
		brains.append(_patrol_brain(spot))
	# Returning: notice its own leader unbudgeted, then grace starts.
	var returner := _patrol_brain(_RETURNER_START)
	returner.step(_DT, _RETURNER_LEADER, grid, false, cfg)
	assert_int(returner.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
	returner.on_grace_started()
	assert_int(returner.sub_state).is_equal(SymbolBrain.SubState.RETURNING)
	brains.append(returner)
	# Chasing, past `repath_s`, about to see its target cell change.
	var chaser := _patrol_brain(_CHASER_START)
	chaser.facing = SymbolBrain.nearest_facing(_CHASER_LEADER - _CHASER_START, -1)
	var t: float = 0.0
	while t < cfg.notice_delay_s + cfg.repath_s + 0.1:
		chaser.step(_DT, _CHASER_LEADER, grid, false, cfg)
		t += _DT
	assert_int(chaser.sub_state).is_equal(SymbolBrain.SubState.CHASING)
	brains.append(chaser)
	var n: int = brains.size()
	var bound: int = ceili(float(n) / float(cfg.repath_per_frame_max))
	var before: Array[int] = []
	for brain in brains:
		before.append(brain.queries_granted)
	var served: Array[int] = []
	served.resize(n)
	served.fill(-1)
	var budget := QueryBudget.new(cfg.repath_per_frame_max)
	for frame in range(1, bound + 1):
		budget.begin_frame()
		for i in n:
			brains[i].step(_DT, _LEADER, grid, false, cfg, budget)
			if served[i] < 0 and brains[i].queries_granted > before[i]:
				served[i] = frame
		assert_int(budget.granted_this_frame).is_less_equal(cfg.repath_per_frame_max)
	for i in n:
		assert_int(served[i]).is_between(1, bound)
	assert_int(chaser.repaths_run).is_greater(0)


func _patrol_brain(spot: Vector2) -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([spot]), SymbolBrain.PathMode.LOOP, 1)
	brain.facing = SymbolBrain.nearest_facing(_LEADER - spot, -1)
	return brain


func _grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
