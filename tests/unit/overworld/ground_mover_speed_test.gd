## Story 001 (AC-1a): a leader walking at full tilt covers exactly
## `walk_speed * Sigma(dt)` metres, within 1e-4.
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
