## Story 001 (AC-1a): a leader walking at full tilt covers exactly
## `walk_speed * Sigma(dt)` metres, within 1e-4.
## Story 002 (AC-1b): speed scales linearly with input magnitude below 1, and
## clamps to `walk_speed` at magnitude 1.4 (a diagonal keyboard vector before
## `InputResolver.get_move_vector()`'s own normalization) -- proving
## `GroundMover.step()`'s `limit_length(1)` clamp composes correctly with
## ADR-0003's diagonal normalization rather than double-scaling.
## Story 003 (AC-1c): no action besides `move` changes the leader's speed.
## Drives `OverworldMode` through its real call path -- actions via the
## machine's bound `SyntheticActionSource`, movement via
## `machine.get_move_vector(self)` inside `_process()` -- rather than calling
## `GroundMover.step()` directly, so a regression that makes `handle_action()`
## or `_process()` branch on a discrete action is caught here, not just at
## the formula level.
extends GdUnitTestSuite

const _N_FRAMES: int = 37
## 37 * 0.013 = 0.481s -- not a clean threshold (test harness timing rule).
const _DT: float = 0.013

## gdUnit4 single-arg parametrized case wrapping (`[[a], [b]]`).
const _AC1C_ACTIONS: Array = [[InputActions.CONFIRM], [InputActions.CANCEL], [InputActions.MENU]]


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


## AC-1c, discrete press: `action` pressed then released within one frame
## does not change that frame's `distance_moved`. Calls `mode.handle_action()`
## directly rather than routing through a bound `SyntheticActionSource` and
## the full `GameStateMachine` dispatch -- `_on_source_action_pressed()`
## intercepts `menu` before dispatch and opens the pause overlay itself
## (game-state-scene-flow stories 024/025), which would then zero
## `get_move_vector()` by design (input ownership moves to the overlay). That
## is a real, intentional pause-on-menu behavior this story does not own;
## calling `handle_action()` directly isolates exactly the call path AC-1c
## does own -- whether `OverworldMode` itself ever lets a discrete action
## reach `GroundMover`.
func test_discrete_press_does_not_change_leader_speed(action: StringName, test_parameters := _AC1C_ACTIONS) -> void:
	var cfg := OverworldConfig.new()
	var mode: OverworldMode = _make_mode_in_overworld(cfg)

	mode.handle_action(action, true)
	mode.handle_action(action, false)
	var distance: float = _step_and_get_distance(mode, _DT)
	assert_float(distance).is_equal_approx(cfg.walk_speed * _DT, 1e-4)


## AC-1c, held: `action` left held (pressed, no release) across several
## frames does not change any frame's `distance_moved`.
func test_held_across_frames_does_not_change_leader_speed(action: StringName, test_parameters := _AC1C_ACTIONS) -> void:
	_assert_held_does_not_change_speed(OverworldConfig.new(), action)


## Formula test harness rule: run once more against a non-default config.
func test_held_across_frames_does_not_change_leader_speed_with_custom_speed(
		action: StringName, test_parameters := _AC1C_ACTIONS) -> void:
	var cfg := OverworldConfig.new()
	cfg.walk_speed = 3.1
	_assert_held_does_not_change_speed(cfg, action)


## AC-1c, any combination/order: holding all three discrete actions together,
## then releasing them in a different order, never changes `distance_moved`.
func test_all_three_actions_in_any_order_does_not_change_leader_speed() -> void:
	var cfg := OverworldConfig.new()
	var mode: OverworldMode = _make_mode_in_overworld(cfg)
	var expected_distance: float = cfg.walk_speed * _DT

	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.MENU, true)
	assert_float(_step_and_get_distance(mode, _DT)).is_equal_approx(expected_distance, 1e-4)

	mode.handle_action(InputActions.CANCEL, true)
	assert_float(_step_and_get_distance(mode, _DT)).is_equal_approx(expected_distance, 1e-4)

	mode.handle_action(InputActions.MENU, false)
	assert_float(_step_and_get_distance(mode, _DT)).is_equal_approx(expected_distance, 1e-4)

	mode.handle_action(InputActions.CONFIRM, false)
	mode.handle_action(InputActions.CANCEL, false)
	assert_float(_step_and_get_distance(mode, _DT)).is_equal_approx(expected_distance, 1e-4)


func _assert_held_does_not_change_speed(cfg: OverworldConfig, action: StringName) -> void:
	var mode: OverworldMode = _make_mode_in_overworld(cfg)
	var expected_distance: float = cfg.walk_speed * _DT

	mode.handle_action(action, true)
	for _i in range(_N_FRAMES):
		var distance: float = _step_and_get_distance(mode, _DT)
		assert_float(distance).is_equal_approx(expected_distance, 1e-4)
	mode.handle_action(action, false)


## Builds a real `OverworldMode`, wired into a real `GameStateMachine` already
## settled in Overworld (`GameStateFixtures.make_machine_in_overworld()`) and
## installed as the loader's current mode node, so `machine.is_input_owner(mode)`
## holds and `_process()`'s `machine.get_move_vector(self)` call resolves to a
## fixed, full-tilt move vector (`Vector2.DOWN`) the same as it would in-game
## (ADR-0012 §2) -- a `SyntheticActionSource` is bound only to supply that
## vector; AC-1c's actions are driven straight into `handle_action()` instead
## (see `test_discrete_press_does_not_change_leader_speed()`'s doc comment).
func _make_mode_in_overworld(cfg: OverworldConfig) -> OverworldMode:
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


## Calls `OverworldMode._process(dt)` directly (no running `SceneTree` in a
## headless unit test) and returns the step's `distance_moved`.
func _step_and_get_distance(mode: OverworldMode, dt: float) -> float:
	mode._process(dt)
	return mode.get_last_distance_moved()


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
