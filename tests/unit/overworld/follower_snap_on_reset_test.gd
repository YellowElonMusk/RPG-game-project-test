## Story 007, AC-5a: on a map entry, a teleport, a checkpoint redirect and a
## battle thaw, on that same frame the trail is cleared and the followers sit
## at spacing behind the leader, opposite its facing, on walkable cells; where
## a wall blocks, the remaining followers share the last walkable point (GDD
## rule 2, Edge Cases; ADR-0012 §4/§6).
extends GdUnitTestSuite

const _ENC: String = "enc_fixture_clerk"
const _SYM: String = "sym_fixture_clerk_1"
const _TOWN: String = "res://data/maps/paris_town_placeholder.tscn"
const _START: Vector2 = Vector2(2.5, 2.5)
const _LEADER: Vector2 = Vector2(6.4, 5.5)
const _EPSILON: float = 1e-4
## Frames walked before a reset, so the trail holds history the reset must clear.
const _WALK_FRAMES: int = 30
const _DT: float = 1.0 / 60.0


## A `GameStateMachine` double that records the in-mode fade's callback
## instead of running the fade, so the test runs the swap step itself.
class FadeSpyMachine extends GameStateMachine:
	var fade_callback: Callable = Callable()

	func _init() -> void:
		super(null, null, null, null, Callable(), null)

	func request_in_mode_fade(callback: Callable) -> RequestResult:
		fade_callback = callback
		return RequestResult.OK


func test_teleport_snaps_followers_behind_the_leader() -> void:
	var mode: OverworldMode = _walked_mode(RequestSpyMachine.new(), ContactFixture.open_grid())
	mode.teleport_leader(_LEADER, Vector2.RIGHT)
	_assert_formation(mode, _in_line(_LEADER, Vector2.RIGHT, mode.config))


func test_redirect_snaps_followers_inside_the_fade() -> void:
	var machine := FadeSpyMachine.new()
	var mode: OverworldMode = _walked_mode(machine, ContactFixture.open_grid())
	var before: Array[Vector2] = mode.get_follower_positions()
	assert_int(mode.redirect_leader(_LEADER, Vector2.RIGHT)).is_equal(GameStateMachine.RequestResult.OK)
	# Nothing moves until the fade's swap runs the callback.
	assert_vector(mode.get_leader_position()).is_not_equal(_LEADER)
	assert_array(mode.get_follower_positions()).is_equal(before)
	assert_bool(machine.fade_callback.is_valid()).is_true()
	machine.fade_callback.call()
	assert_vector(mode.get_leader_position()).is_equal_approx(_LEADER, Vector2.ONE * _EPSILON)
	_assert_formation(mode, _in_line(_LEADER, Vector2.RIGHT, mode.config))


func test_battle_thaw_snaps_followers_behind_the_leader() -> void:
	for result: GameStateMachine.BattleResult in [
			GameStateMachine.BattleResult.VICTORY, GameStateMachine.BattleResult.FLED]:
		var mode: OverworldMode = _walked_mode(RequestSpyMachine.new(), ContactFixture.open_grid())
		mode.teleport_leader(_LEADER, Vector2.RIGHT)
		var source: EncounterSource = mode.add_symbol(_ENC,
				ContactFixture.brain([Vector2(10.5, 8.5)], 0, mode.config, true), _SYM)
		assert_int(mode.start_encounter(_ENC, source)).is_equal(GameStateMachine.RequestResult.OK)
		mode.on_thawed(_ENC, result)
		_assert_formation(mode, _in_line(_LEADER, Vector2.RIGHT, mode.config))


func test_map_entry_snaps_followers_behind_the_leader() -> void:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.set_leader_facing(Vector2.RIGHT)
	mode.load_map((load(_TOWN) as PackedScene).instantiate() as OverworldMap)
	var leader: Vector2 = mode.get_leader_position()
	var expected: Array[Vector2] = _walkable_line(mode.get_walk_grid(), leader,
			mode.get_leader_facing(), mode.config)
	_assert_formation(mode, expected)
	for p: Vector2 in mode.get_follower_positions():
		assert_bool(mode.get_walk_grid().is_walkable(mode.get_walk_grid().cell_of(p))).is_true()


func test_wall_stacks_the_remaining_followers_on_the_last_walkable_point() -> void:
	var grid: WalkGrid = ContactFixture.open_grid()
	grid.cells[5 * grid.size.x + 4] = 0  # (4, 5) blocked, 1.4 m behind the leader
	var mode: OverworldMode = _walked_mode(RequestSpyMachine.new(), grid)
	mode.teleport_leader(_LEADER, Vector2.RIGHT)
	var cfg: OverworldConfig = mode.config
	# Samples every trail_sample_m (0.15) behind the leader at x = 6.4: the last
	# one still in cell x = 5 is 9 samples back (x = 5.05); the 10th (4.9) is in the wall.
	var last_walkable := Vector2(_LEADER.x - 9.0 * cfg.trail_sample_m, _LEADER.y)
	var expected: Array[Vector2] = [
		Vector2(_LEADER.x - cfg.follower_spacing_m, _LEADER.y), last_walkable, last_walkable]
	_assert_formation(mode, expected)


func test_every_trigger_resets_identically() -> void:
	var by_teleport: OverworldMode = _walked_mode(RequestSpyMachine.new(), ContactFixture.open_grid())
	by_teleport.teleport_leader(_LEADER, Vector2.UP)
	var machine := FadeSpyMachine.new()
	var by_redirect: OverworldMode = _walked_mode(machine, ContactFixture.open_grid())
	by_redirect.redirect_leader(_LEADER, Vector2.UP)
	machine.fade_callback.call()
	var by_thaw: OverworldMode = _walked_mode(RequestSpyMachine.new(), ContactFixture.open_grid())
	by_thaw.set_leader_position(_LEADER)
	by_thaw.set_leader_facing(Vector2.UP)
	var source: EncounterSource = by_thaw.add_symbol(_ENC,
			ContactFixture.brain([Vector2(10.5, 8.5)], 0, by_thaw.config, true), _SYM)
	by_thaw.start_encounter(_ENC, source)
	by_thaw.on_thawed(_ENC, GameStateMachine.BattleResult.VICTORY)
	var expected: Array[Vector2] = by_teleport.get_follower_positions()
	_assert_formation(by_redirect, expected)
	_assert_formation(by_thaw, expected)


## A mode on `grid` whose leader has walked down from `_START` for
## `_WALK_FRAMES`, so its trail holds history a reset must clear.
func _walked_mode(machine: GameStateMachine, grid: WalkGrid) -> OverworldMode:
	var mode: OverworldMode = auto_free(ContactFixture.make_mode(
			machine, OverworldConfig.new(), _START, [_ENC]))
	mode.set_walk_grid(grid)
	mode.world_state = WorldState.new()
	for i: int in _WALK_FRAMES:
		mode.step_frame(_DT, Vector2.DOWN)
		mode.step_followers(mode.config.max_followers)
	return mode


## The open-ground formation: follower `i` at `(i + 1) * follower_spacing_m`
## straight behind `leader`, opposite `facing`.
func _in_line(leader: Vector2, facing: Vector2, cfg: OverworldConfig) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in cfg.max_followers:
		out.append(leader - facing.normalized() * float(i + 1) * cfg.follower_spacing_m)
	return out


## The same formation on an arbitrary grid: each follower at its spacing
## behind the leader unless a wall comes first, in which case at the last
## walkable `trail_sample_m` sample.
func _walkable_line(grid: WalkGrid, leader: Vector2, facing: Vector2,
		cfg: OverworldConfig) -> Array[Vector2]:
	var back: Vector2 = -facing.normalized()
	var last: Vector2 = leader
	var k: int = 1
	while k * cfg.trail_sample_m <= cfg.max_followers * cfg.follower_spacing_m + _EPSILON:
		var p: Vector2 = leader + back * (k * cfg.trail_sample_m)
		if not grid.is_walkable(grid.cell_of(p)):
			break
		last = p
		k += 1
	var reach: float = leader.distance_to(last)
	var out: Array[Vector2] = []
	for i: int in cfg.max_followers:
		var d: float = float(i + 1) * cfg.follower_spacing_m
		out.append(leader + back * d if d <= reach + _EPSILON else last)
	return out


func _assert_formation(mode: OverworldMode, expected: Array[Vector2]) -> void:
	var got: Array[Vector2] = mode.get_follower_positions()
	assert_int(got.size()).is_equal(expected.size())
	for i: int in expected.size():
		assert_vector(got[i]).override_failure_message(
				"follower %d at %s, expected %s" % [i, got[i], expected[i]]) \
				.is_equal_approx(expected[i], Vector2.ONE * _EPSILON)
