## Story 032 (ADR-0002 Migration Step 0): pins ChapterFlow's fight order (3
## regular + boss), the per-faction enemy roster at each fight, and that a
## boss win emits chapter_won exactly once (checks 1, 2, 4). Driven entirely
## through ChapterFlowProbe; expected values live in ChapterFlowExpected.
extends GdUnitTestSuite

const _FACTIONS: Array = [["bureaucratia"], ["megacorp"]]


func test_fight_order_and_rosters(faction: String, test_parameters := _FACTIONS) -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = ChapterFlowExpected.SEED
	var probe := ChapterFlowProbe.new(faction, ChapterFlowExpected.make_squad(), rng)
	var expected: Array = ChapterFlowExpected.CHAPTER_EXPECTED[faction]

	# Act / Assert: win fights 0..REGULAR_FIGHT_COUNT-1, recording each
	# fight's index/is_boss/roster before the win that advances it.
	probe.start()
	for i: int in ChapterFlow.REGULAR_FIGHT_COUNT:
		var fight: Dictionary = probe.current_fight()
		assert_int(fight["index"]).override_failure_message(
				"%s fight %d index" % [faction, i]).is_equal(expected[i]["index"])
		assert_bool(fight["is_boss"]).override_failure_message(
				"%s fight %d is_boss" % [faction, i]).is_equal(expected[i]["is_boss"])
		assert_array(fight["enemy_names"]).override_failure_message(
				"%s fight %d enemy_names" % [faction, i]).is_equal(expected[i]["enemy_names"])
		probe.win_current()

	# The boss fight (index REGULAR_FIGHT_COUNT).
	var boss_fight: Dictionary = probe.current_fight()
	assert_int(boss_fight["index"]).override_failure_message(
			"%s boss index" % faction).is_equal(expected[3]["index"])
	assert_bool(boss_fight["is_boss"]).override_failure_message(
			"%s boss is_boss" % faction).is_equal(expected[3]["is_boss"])
	assert_array(boss_fight["enemy_names"]).override_failure_message(
			"%s boss enemy_names" % faction).is_equal(expected[3]["enemy_names"])

	assert_int(probe.chapter_won_count).override_failure_message(
			"%s chapter_won count before the boss win" % faction).is_equal(0)
	probe.win_current()
	assert_int(probe.chapter_won_count).override_failure_message(
			"%s chapter_won count" % faction).is_equal(1)
