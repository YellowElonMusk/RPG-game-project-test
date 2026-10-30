## Story 010, AC-6 (GDD rule 2): the saved world state holds no follower
## data, and after a load the followers are rebuilt in formation behind the
## leader. The roster-order half ("followers equal the roster order minus
## the leader") waits for the Squad Roster system: the view tints followers
## by slot today (TODO(squad-roster)).
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")


func test_the_save_holds_no_follower_data() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	mode.step_frame(1.0 / 60.0, Vector2.RIGHT)
	var machine: GameStateMachine = GameStateFixtures.make_machine_in_overworld()["machine"]
	var service: SaveService = auto_free(SaveService.new())
	var fs := MemorySaveFileSystem.new()
	service.setup(machine, null, fs, SaveConfig.new(),
			SaveBootstrap.participants(machine, mode.world_state, Callable()), func() -> int: return 0)
	assert_int(service.save_to_slot(1)).is_equal(SaveService.SaveResult.OK)
	var text: String = (fs.files[service.slot_path(1)] as String).to_lower()
	assert_bool(text.contains("follower")).is_false()
	assert_bool(text.contains("trail")).is_false()


func test_followers_are_rebuilt_in_formation_on_a_continue() -> void:
	# A Continue goes through load_map + the saved position; the followers
	# come from the trail snap, never from the save.
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var ws: WorldState = mode.world_state
	var at: Vector2 = Vector2(12.0, 14.5)
	ws.party_pos = at
	ws.party_facing = Vector2.RIGHT
	mode.set("_continuing", true)
	mode.call("_continue_from_save")
	var followers: Array[Vector2] = mode.get_follower_positions()
	assert_int(followers.size()).is_equal(mode.config.max_followers)
	for i: int in followers.size():
		assert_vector(followers[i]).is_equal_approx(
				at - Vector2.RIGHT * float(i + 1) * mode.config.follower_spacing_m, Vector2.ONE * 1e-4)
