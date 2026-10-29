## Story 001 (AC-1a): a leader walking at full tilt covers exactly
## `walk_speed * Sigma(dt)` metres, within 1e-4.
## Story 002 (AC-1b): speed scales linearly with input magnitude below 1, and
## clamps to `walk_speed` at magnitude 1.4 (a diagonal keyboard vector before
## `InputResolver.get_move_vector()`'s own normalization) -- proving
## `GroundMover.step()`'s `limit_length(1)` clamp composes correctly with
## ADR-0003's diagonal normalization rather than double-scaling.
extends GdUnitTestSuite

const _N_FRAMES: int = 37
## 37 * 0.013 = 0.481s -- not a clean threshold (test harness timing rule).
const _DT: float = 0.013


func test_full_tilt_move_matches_walk_speed_times_elapsed_time() -> void:
	_assert_full_tilt_displacement(OverworldConfig.new())


## Formula test harness rule: run once more against a non-default config.
func test_full_tilt_move_matches_walk_speed_times_elapsed_time_with_custom_speed() -> void:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 3.1
	_assert_full_tilt_displacement(cfg)


## AC-1b, first half: magnitude 0.5 (partial stick tilt) scales speed down
## proportionally.
func test_partial_tilt_speed_scales_linearly_with_magnitude() -> void:
	_assert_speed_for_magnitude(OverworldConfig.new(), 0.5)


## Formula test harness rule: run once more against a non-default config.
func test_partial_tilt_speed_scales_linearly_with_magnitude_with_custom_speed() -> void:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 3.1
	_assert_speed_for_magnitude(cfg, 0.5)


## AC-1b, second half: magnitude 1.4 (a diagonal keyboard vector before
## normalising) clamps to full `walk_speed` rather than overshooting it.
func test_magnitude_above_one_clamps_to_full_walk_speed() -> void:
	_assert_speed_for_magnitude(OverworldConfig.new(), 1.4, 1.0)


## Formula test harness rule: run once more against a non-default config.
func test_magnitude_above_one_clamps_to_full_walk_speed_with_custom_speed() -> void:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 3.1
	_assert_speed_for_magnitude(cfg, 1.4, 1.0)


func _assert_full_tilt_displacement(cfg: OverworldConfig) -> void:
	var pos: Vector2 = Vector2.ZERO
	var input_vec: Vector2 = Vector2.DOWN  # full tilt, magnitude 1
	var elapsed: float = 0.0
	for _i in range(_N_FRAMES):
		var result: GroundMover.MoveResult = GroundMover.step(
				pos, input_vec, _DT, null, cfg, cfg.walk_speed, 0)
		pos = result.position
		elapsed += _DT
	var expected_distance: float = cfg.walk_speed * elapsed
	assert_float(pos.distance_to(Vector2.ZERO)).is_equal_approx(expected_distance, 1e-4)


## Asserts one `GroundMover.step()` call with a pre-normalization input
## `magnitude` covers `expected_scale * cfg.walk_speed * dt` metres --
## `expected_scale` defaults to `magnitude` itself (the unclamped, <=1 case);
## pass it explicitly (1.0) to assert the `limit_length(1)` clamp fires for
## magnitude > 1.
func _assert_speed_for_magnitude(cfg: OverworldConfig, magnitude: float, expected_scale: float = -1.0) -> void:
	var scale: float = magnitude if expected_scale < 0.0 else expected_scale
	var input_vec: Vector2 = Vector2.DOWN * magnitude
	var result: GroundMover.MoveResult = GroundMover.step(
			Vector2.ZERO, input_vec, _DT, null, cfg, cfg.walk_speed, 0)
	var expected_distance: float = scale * cfg.walk_speed * _DT
	assert_float(result.distance_moved).is_equal_approx(expected_distance, 1e-4)
