## Story 094, AC-35b (GDD rule 15, Edge Cases): a Continue whose saved
## position now lies in a blocked cell (here the dungeon's closed Permit
## Boom) puts the leader on the nearest walkable cell; with none within
## 5 m, on the map's first EntryPoint. A walkable saved position is kept.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _DUNGEON: String = "map_paris_dungeon_placeholder"
## Inside the Permit Boom's blocked rect (16, 21, 2, 2).
const _IN_BOOM: Vector2 = Vector2(16.5, 21.5)


func test_a_blocked_saved_position_moves_to_the_nearest_walkable_cell() -> void:
	var mode: OverworldMode = _continue_at(_IN_BOOM)
	var grid: WalkGrid = mode.get_walk_grid()
	var at: Vector2 = mode.get_leader_position()
	assert_bool(grid.is_walkable(grid.cell_of(_IN_BOOM))).is_false()
	assert_bool(grid.is_walkable(grid.cell_of(at))).is_true()
	assert_float(at.distance_to(_IN_BOOM)).is_less_equal(5.0)
	# Nearest: no walkable cell centre is closer to the saved position.
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			var c := Vector2i(x, y)
			if grid.is_walkable(c):
				assert_float(grid.cell_center(c).distance_to(_IN_BOOM)).is_greater_equal(at.distance_to(_IN_BOOM) - 1e-4)


func test_with_nothing_walkable_within_5_m_the_leader_is_at_the_first_entry_point() -> void:
	var mode: OverworldMode = _continue_at(Vector2(-20.0, -20.0))
	var first: EntryPoint = mode.get_map().entry_points()[0]
	assert_vector(mode.get_leader_position()).is_equal(first.ground_position(mode.get_map()))


func test_a_walkable_saved_position_is_kept() -> void:
	var mode: OverworldMode = _continue_at(Vector2(13.5, 28.5))
	assert_vector(mode.get_leader_position()).is_equal(Vector2(13.5, 28.5))


func _continue_at(pos: Vector2) -> OverworldMode:
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(GameStateFixtures.make_machine_in_overworld()["machine"], null)
	mode.world_state = WorldState.new()
	mode.world_state.map_id = _DUNGEON
	mode.world_state.party_pos = pos
	mode.world_state.party_facing = Vector2.UP
	mode.encounter_catalog = RecordCatalogDouble.new()
	auto_free(mode)
	mode.call(&"_continue_from_save")
	return mode
