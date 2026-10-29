## Story 024 (AC-9e, GDD rule 5 notice test opening clause, Returning and
## Stunned rows, rule 7 grace): in Returning, in Stunned, inside the
## re-notice cooldown, and during encounter grace in any sub-state, the
## notice test is never entered (`notice_tests_run` stays 0), whatever the
## leader's position. The leader sits at a guaranteed-notice spot.
extends GdUnitTestSuite

## `renotice_cooldown_s / _DT` is not whole for the default (3) or custom
## (2.5) cooldown (test harness timing rule).
const _DT: float = 0.013
const _FRAMES: int = 120
const _GRID_SIZE: Vector2i = Vector2i(12, 12)
const _ORIGIN: Vector2 = Vector2(5.5, 5.5)


func test_returning_never_runs_notice_test() -> void:
	_assert_deaf_in(SymbolBrain.SubState.RETURNING, false)


func test_stunned_never_runs_notice_test() -> void:
	_assert_deaf_in(SymbolBrain.SubState.STUNNED, false)


func test_grace_never_runs_notice_test_in_any_substate() -> void:
	for s: int in SymbolBrain.SubState.values():
		_assert_deaf_in(s as SymbolBrain.SubState, true)


func test_renotice_cooldown_skips_test_until_it_ends() -> void:
	_assert_cooldown(OverworldConfig.new())


## Formula test harness rule: run once more against a non-default config.
func test_renotice_cooldown_skips_test_until_it_ends_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.renotice_cooldown_s = 2.5
	_assert_cooldown(cfg)


func _assert_deaf_in(state: SymbolBrain.SubState, grace: bool) -> void:
	var cfg := OverworldConfig.new()
	var grid := _open_grid()
	var brain := _stationary_brain()
	brain.sub_state = state
	var leader: Vector2 = _guaranteed_notice_leader(brain, cfg)
	for i in _FRAMES:
		brain.step(_DT, leader, grid, grace, cfg)
	assert_int(brain.notice_tests_run).is_equal(0)
	assert_int(brain.notice_searches_run).is_equal(0)
	# Returning now walks home and rejoins Patrol (story 033); the cooldown
	# keeps it deaf, so only the other states must hold.
	if state != SymbolBrain.SubState.NOTICING and state != SymbolBrain.SubState.RETURNING:
		assert_int(brain.sub_state).is_equal(state)


func _assert_cooldown(cfg: OverworldConfig) -> void:
	var grid := _open_grid()
	var brain := _stationary_brain()
	brain.sub_state = SymbolBrain.SubState.RETURNING
	brain.rejoin_patrol(cfg)
	assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
	var leader: Vector2 = _guaranteed_notice_leader(brain, cfg)
	var cooldown: float = cfg.renotice_cooldown_s
	var frames: int = ceili((cooldown + 2.0 * _DT) / _DT)
	var noticed_after: bool = false
	for k in range(1, frames + 1):
		brain.step(_DT, leader, grid, false, cfg)
		var t: float = k * _DT
		if t <= cooldown - _DT:
			assert_int(brain.notice_tests_run).is_equal(0)
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.PATROL)
		elif t >= cooldown + _DT:
			assert_int(brain.sub_state).is_equal(SymbolBrain.SubState.NOTICING)
			noticed_after = true
	assert_bool(noticed_after).is_true()


## Front half-plane, half the front radius away, open grid: every check of
## the notice test would pass.
func _guaranteed_notice_leader(brain: SymbolBrain, cfg: OverworldConfig) -> Vector2:
	return _ORIGIN + brain.facing_vector() * (0.5 * cfg.symbol_chase_m)


func _stationary_brain() -> SymbolBrain:
	var brain := SymbolBrain.new(PackedVector2Array([_ORIGIN]), SymbolBrain.PathMode.LOOP)
	brain.facing = SymbolBrain.Facing.SE
	return brain


## Fully walkable fixture grid, no `SAFE` cells.
func _open_grid() -> WalkGrid:
	var grid := WalkGrid.new()
	grid.size = _GRID_SIZE
	grid.cell_m = 1.0
	grid.cells.resize(_GRID_SIZE.x * _GRID_SIZE.y)
	grid.cells.fill(WalkGrid.FLAG_WALKABLE)
	return grid
