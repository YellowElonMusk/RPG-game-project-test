## Story 006 (AC-4): `FollowerTrail` replays the leader's recorded path at
## fixed arc-length spacing, for up to 3 followers. Tests the pure unit
## directly (black-box, against the leader's known walked polyline rather
## than the implementation's own internals) and, separately, that
## `OverworldMode.step_followers()` wires it in without disturbing
## `_process()`'s own contract -- story 005's `follower_no_collision_test.gd`
## already locks `_process()` down to leader-movement only, and this story
## must not regress that.
extends GdUnitTestSuite

const _DT_SMALL: float = 1.0 / 60.0
const _DT_MAX: float = 0.10
const _TEST_SPEED_MPS: float = 2.0
const _LEG_1_M: float = 5.0
const _LEG_2_M: float = 5.0
const _N_FOLLOWERS: int = 3


## GDD worked example (Formulas, `follower_trail`): a 0.10 s frame moves the
## leader 0.35 m at `_TEST_SPEED_MPS`=3.5 m/s and appends two points, 0.15 m
## apart, at the default `trail_sample_m`.
func test_single_frame_appends_two_points_matching_worked_example() -> void:
	var trail := FollowerTrail.new()
	var cfg := OverworldConfig.new()
	trail.reset(Vector2.ZERO)

	trail.step(Vector2.RIGHT * 0.35, _N_FOLLOWERS, cfg)

	assert_int(trail.buffer_length()).is_equal(2)


## GDD worked example: spacing 0.9, sample 0.15, 3 followers give `N_buf` =
## 20. Walking far past the point where every follower's history exists
## proves the buffer caps there rather than growing with frame count.
func test_buffer_caps_at_worked_example_n_buf() -> void:
	_assert_buffer_caps_at_n_buf(OverworldConfig.new())


## Formula test harness rule: run the `N_buf` check once more against a
## non-default config.
func test_buffer_caps_at_n_buf_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.follower_spacing_m = 0.8
	cfg.trail_sample_m = 0.1
	_assert_buffer_caps_at_n_buf(cfg)


## AC-4, main check, at `dt` = 1/60 s: every follower lies on the leader's
## walked polyline (a 90-degree-corner path) at arc length
## `(i + 1) * follower_spacing_m` behind the leader, within
## `trail_sample_m / 2`, and never farther than `trail_sample_m / 2` from
## the polyline itself.
func test_followers_hold_formula_spacing_at_small_dt() -> void:
	_assert_trail_matches_formula(OverworldConfig.new(), _DT_SMALL)


## AC-4, same check at `dt` = `dt_max` (0.10 s) -- the bound must hold
## however long the frame is, not only at a smooth 60 fps.
func test_followers_hold_formula_spacing_at_dt_max() -> void:
	_assert_trail_matches_formula(OverworldConfig.new(), _DT_MAX)


## Formula test harness rule: run the main AC-4 check once more against a
## non-default config.
func test_followers_hold_formula_spacing_with_custom_config() -> void:
	var cfg := OverworldConfig.new()
	cfg.follower_spacing_m = 0.8
	cfg.trail_sample_m = 0.1
	_assert_trail_matches_formula(cfg, _DT_SMALL)


## AC-4, fourth bullet: when the leader stops (unchanged `leader_pos`), every
## follower stops on the same frame -- calling `step()` again with no
## movement appends no new trail points and returns the exact same
## positions.
func test_leader_stopping_holds_follower_positions() -> void:
	var cfg := OverworldConfig.new()
	var trail := FollowerTrail.new()
	var leader_pos := Vector2.ZERO
	for _i in range(50):
		leader_pos += Vector2.RIGHT * 0.1
		trail.step(leader_pos, _N_FOLLOWERS, cfg)

	var positions_before: Array[Vector2] = trail.step(leader_pos, _N_FOLLOWERS, cfg)
	var positions_after: Array[Vector2] = trail.step(leader_pos, _N_FOLLOWERS, cfg)

	assert_array(positions_after).is_equal(positions_before)


## `OverworldMode.step_followers()` wires `FollowerTrail` in faithfully:
## driving the mode's leader through `_process()` and its trail through
## `step_followers()` each frame matches calling `FollowerTrail.step()`
## directly with the same leader positions.
func test_overworld_mode_step_followers_matches_trail_directly() -> void:
	var cfg := OverworldConfig.new()
	var mode: OverworldMode = _make_moving_mode(cfg)
	var trail := FollowerTrail.new()

	for _i in range(10):
		mode._process(_DT_SMALL)
		mode.step_followers(_N_FOLLOWERS)
		var direct: Array[Vector2] = trail.step(mode.get_leader_position(), _N_FOLLOWERS, cfg)
		assert_array(mode.get_follower_positions()).is_equal(direct)


## Regression guard (story 005, `follower_no_collision_test.gd`):
## `_process()` alone, without a `step_followers()` call, never touches
## `_follower_positions` -- the trail is a separate, explicitly-driven call,
## not a hidden side effect of leader movement.
func test_process_alone_does_not_touch_follower_positions() -> void:
	var cfg := OverworldConfig.new()
	var mode: OverworldMode = _make_moving_mode(cfg)
	var fixed_position := Vector2(10.0, 10.0)
	mode.set_follower_positions([fixed_position])

	for _i in range(5):
		mode._process(_DT_SMALL)

	assert_array(mode.get_follower_positions()).is_equal([fixed_position])


func _assert_buffer_caps_at_n_buf(cfg: OverworldConfig) -> void:
	var trail := FollowerTrail.new()
	var leader_pos := Vector2.ZERO
	var total_m: float = float(_N_FOLLOWERS) * cfg.follower_spacing_m + 1.0
	var step_m: float = cfg.trail_sample_m * 0.5
	var walked: float = 0.0
	while walked < total_m:
		leader_pos += Vector2.RIGHT * step_m
		walked += step_m
		trail.step(leader_pos, _N_FOLLOWERS, cfg)

	var expected_n_buf: int = _expected_n_buf(_N_FOLLOWERS, cfg)
	assert_int(trail.buffer_length()).is_equal(expected_n_buf)


## The formula's `N_buf`, computed independently of `FollowerTrail`'s own
## `_buffer_capacity()` so the test doesn't just restate the implementation.
func _expected_n_buf(n_followers: int, cfg: OverworldConfig) -> int:
	const EPSILON: float = 1e-6
	var raw: float = float(n_followers) * cfg.follower_spacing_m / cfg.trail_sample_m - EPSILON
	return int(ceil(raw)) + 2


## Walks a two-leg, 90-degree-corner path (`_LEG_1_M` east, then `_LEG_2_M`
## south) at `dt`-sized steps, checking at every frame -- once the leader
## has walked far enough for every follower's history to exist -- that each
## follower sits on the recorded polyline within `trail_sample_m / 2`, at
## arc length `(i + 1) * follower_spacing_m` behind the leader within the
## same tolerance (GDD AC-4).
func _assert_trail_matches_formula(cfg: OverworldConfig, dt: float) -> void:
	var trail := FollowerTrail.new()
	var waypoints: Array[Vector2] = [Vector2.ZERO]
	var leader_pos := Vector2.ZERO
	var tol: float = cfg.trail_sample_m / 2.0 + 1e-4
	# Only check once the buffer has reached its steady-state `N_buf` --
	# before that, the trail may not yet hold `target_m` of history for the
	# farthest follower, and the documented fallback (hold at the oldest
	# point) is correct there but not what this bound is checking.
	var expected_n_buf: int = _expected_n_buf(_N_FOLLOWERS, cfg)
	var total_walked: float = 0.0

	var legs: Array[Vector2] = [Vector2.RIGHT * _LEG_1_M, Vector2.DOWN * _LEG_2_M]
	for leg in legs:
		var leg_len: float = leg.length()
		var leg_dir: Vector2 = leg / leg_len
		var remaining: float = leg_len
		while remaining > 0.0:
			var step_dt: float = minf(dt, remaining / _TEST_SPEED_MPS)
			var step_m: float = _TEST_SPEED_MPS * step_dt
			leader_pos += leg_dir * step_m
			remaining -= step_m
			total_walked += step_m
			waypoints.append(leader_pos)

			var positions: Array[Vector2] = trail.step(leader_pos, _N_FOLLOWERS, cfg)
			if trail.buffer_length() >= expected_n_buf:
				_assert_followers_on_polyline(positions, waypoints, cfg, tol)

	assert_int(trail.buffer_length()).is_equal(expected_n_buf)


func _assert_followers_on_polyline(
		positions: Array[Vector2], waypoints: Array[Vector2], cfg: OverworldConfig, tol: float) -> void:
	var cum: Array[float] = [0.0]
	for i in range(1, waypoints.size()):
		cum.append(cum[i - 1] + waypoints[i - 1].distance_to(waypoints[i]))
	var total: float = cum[-1]

	for i in range(positions.size()):
		var target_arc_m: float = float(i + 1) * cfg.follower_spacing_m
		var nearest: Dictionary = _nearest_on_polyline(positions[i], waypoints, cum)
		var nearest_distance: float = nearest["distance"]
		assert_float(nearest_distance).is_less_equal(tol)
		var actual_arc_from_tip: float = total - float(nearest["arc_from_start"])
		assert_float(absf(actual_arc_from_tip - target_arc_m)).is_less_equal(tol)


## Closest point on the polyline `waypoints` to `p`, and that point's arc
## length from `waypoints[0]` (`cum` is `waypoints`' cumulative arc length,
## precomputed by the caller once per frame).
func _nearest_on_polyline(p: Vector2, waypoints: Array[Vector2], cum: Array[float]) -> Dictionary:
	var best_dist: float = INF
	var best_arc_from_start: float = 0.0
	for i in range(waypoints.size() - 1):
		var a: Vector2 = waypoints[i]
		var b: Vector2 = waypoints[i + 1]
		var ab: Vector2 = b - a
		var len2: float = ab.length_squared()
		var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var closest: Vector2 = a + ab * t
		var d: float = p.distance_to(closest)
		if d < best_dist:
			best_dist = d
			best_arc_from_start = cum[i] + a.distance_to(closest)
	return {"distance": best_dist, "arc_from_start": best_arc_from_start}


## Builds a real `OverworldMode`, wired into a real `GameStateMachine`
## already settled in Overworld, bound so `machine.get_move_vector(self)`
## resolves to a fixed, full-tilt move vector (`Vector2.DOWN`) -- same
## fixture pattern as `follower_no_collision_test.gd`'s
## `_make_moving_mode()` and `ground_mover_speed_test.gd`'s
## `_make_mode_in_overworld()`.
func _make_moving_mode(cfg: OverworldConfig) -> OverworldMode:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var mode: OverworldMode = auto_free(OverworldMode.new())
	mode.config = cfg
	mode.setup(machine, null)
	loader.current_mode_node_value = mode
	var source := SyntheticActionSource.new()
	source.move_vector = Vector2.DOWN
	machine.bind_action_source(source)
	return mode
