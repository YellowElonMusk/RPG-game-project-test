## Story 005 (AC-3): a symbol, a map exit and an interactable positioned
## over a follower's cosmetic position never affect anything the leader-only
## path computes. No symbol/exit/interactable detection exists yet in this
## epic (stories 011, 038, 040 and 074+ build those) -- the fixtures below
## are local doubles standing in for an `EncounterSymbol`, a `MapExit`
## rectangle and an `Interactable`'s probe reach (ADR-0012 §3 record shapes),
## used only to prove the follower-position model `OverworldMode` gains in
## this story (positions only, no sprites -- stories 006-010 extend it) is
## never read by `_process()`, the only per-frame hook that exists today.
## ADR-0012 §5's per-frame order (leader -> exits -> symbols -> contact ->
## interaction) keys off the leader alone; this is the structural
## precondition those future checks must preserve.
extends GdUnitTestSuite

const _DT: float = 0.016

## Clear of the leader's circle at the origin by well outside any plausible
## `body_radius` (GDD Tuning Knobs safe range 0.25-0.40 m).
const _FOLLOWER_POS: Vector2 = Vector2(10.0, 10.0)

## Fixture trigger shapes, all centred on `_FOLLOWER_POS`.
const _SYMBOL_CENTER: Vector2 = Vector2(10.0, 10.0)
const _SYMBOL_RADIUS: float = 0.3
const _EXIT_RECT: Rect2 = Rect2(Vector2(9.5, 9.5), Vector2(1.0, 1.0))
const _INTERACTABLE_POINT: Vector2 = Vector2(10.0, 10.0)
const _INTERACT_REACH_M: float = 0.5


## Sanity (non-vacuous setup): every fixture overlaps `_FOLLOWER_POS` and
## none overlaps the leader's start position (the origin), proving this
## scenario is a faithful instance of AC-3's "overlap a follower's position
## but not the leader's circle."
func test_fixture_trigger_shapes_overlap_follower_but_not_leader_circle() -> void:
	var cfg := OverworldConfig.new()
	var leader_pos: Vector2 = Vector2.ZERO

	assert_bool(_circle_contains(_FOLLOWER_POS, _SYMBOL_CENTER, _SYMBOL_RADIUS)).is_true()
	assert_bool(_EXIT_RECT.has_point(_FOLLOWER_POS)).is_true()
	assert_bool(_within_reach(_FOLLOWER_POS, _INTERACTABLE_POINT, _INTERACT_REACH_M)).is_true()

	assert_bool(_circle_contains(leader_pos, _SYMBOL_CENTER, cfg.body_radius)).is_false()
	assert_bool(_EXIT_RECT.has_point(leader_pos)).is_false()
	assert_bool(_within_reach(leader_pos, _INTERACTABLE_POINT, _INTERACT_REACH_M)).is_false()


## GDD rule 2: "Followers have no collision and no logic." `_process()`
## never steps, clamps or otherwise touches `_follower_positions` -- a
## position set through `set_follower_positions()` comes back unchanged
## after any number of frames, trigger fixtures overlapping it or not.
func test_follower_position_unchanged_after_process() -> void:
	var mode: OverworldMode = _make_moving_mode(OverworldConfig.new())
	mode.set_follower_positions([_FOLLOWER_POS])

	for _i in range(5):
		mode._process(_DT)

	assert_array(mode.get_follower_positions()).is_equal([_FOLLOWER_POS])


## AC-3: a symbol, an exit and an interactable sitting on top of a
## follower's position produce zero effect on the leader-only path. No
## symbol/exit/interactable check exists yet to call directly, so this
## proves the precondition those future checks (stories 011, 038, 040,
## 074+) will rely on -- the leader's real, non-zero movement through
## `_process()` is bit-for-bit identical whether or not the mode's cosmetic
## follower positions sit inside trigger geometry, because `_process()`
## never reads `_follower_positions` at all.
func test_trigger_overlap_on_follower_position_does_not_affect_leader_processing() -> void:
	var cfg := OverworldConfig.new()
	var mode_clear: OverworldMode = _make_moving_mode(cfg)
	var mode_overlap: OverworldMode = _make_moving_mode(cfg)
	mode_overlap.set_follower_positions([_FOLLOWER_POS])

	var distance_clear: float = 0.0
	var distance_overlap: float = 0.0
	for _i in range(10):
		mode_clear._process(_DT)
		mode_overlap._process(_DT)
		distance_clear += mode_clear.get_last_distance_moved()
		distance_overlap += mode_overlap.get_last_distance_moved()

	# Non-vacuous: the leader actually moved, so an accidental read of
	# `_follower_positions` inside `_process()` has real displacement to
	# corrupt.
	assert_float(distance_clear).is_greater(0.0)
	assert_float(distance_overlap).is_equal_approx(distance_clear, 1e-5)
	assert_vector(mode_overlap.get_leader_position()).is_equal_approx(
			mode_clear.get_leader_position(), Vector2(1e-5, 1e-5))


func _circle_contains(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_to(center) <= radius


func _within_reach(point: Vector2, target: Vector2, reach: float) -> bool:
	return point.distance_to(target) <= reach


## Builds a real `OverworldMode` wired into a real `GameStateMachine` already
## settled in Overworld, bound so `machine.get_move_vector(self)` resolves to
## a fixed, full-tilt move vector (`Vector2.DOWN`) the same way
## `ground_mover_speed_test.gd`'s `_make_mode_in_overworld()` does, so the
## leader actually moves frame to frame instead of sitting idle at the
## origin.
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
