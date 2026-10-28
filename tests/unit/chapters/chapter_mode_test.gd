## Story 033 (ADR-0002 Migration Plan Step 2's ChapterMode clause; Checks
## 4-5): `ChapterMode` requests its own squad into Battle, and reacts to
## `on_thawed()` by advancing (`VICTORY`) or repeating (`FLED`) the sequence,
## never by calling back into the machine itself (that happens only once the
## machine's own `transition_finished` proves it is no longer busy -- see
## `chapter_mode.gd`'s class doc comment).
extends GdUnitTestSuite


func test_requests_battle_with_own_party() -> void:
	# Arrange: a real machine already idle in Overworld, with ChapterMode set
	# up directly (a unit test of ChapterMode itself, not the scene loader).
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var machine: GameStateMachine = env["machine"]
	var loader: StubSceneLoader = env["loader"]
	var squad: Array[Combatant] = ChapterFlowExpected.make_squad()

	var chapter_mode: ChapterMode = auto_free(ChapterMode.new())
	chapter_mode.squad = squad
	chapter_mode.setup(machine, null)
	# `make_machine_in_overworld()` already drove two real transitions
	# (Boot->Title, Title->Overworld), each its own `begin_swap()` -- the
	# count to compare against is the delta from here, never an absolute 1.
	var begin_swap_count_before: int = loader.begin_swap_count

	# Act: the step starts -- forced through the machine's own real signal
	# (ChapterFlowProbe's convention), never a private method.
	machine.transition_finished.emit(GameStateMachine.Mode.OVERWORLD)
	_run_to_idle(machine)

	# Assert: exactly one BATTLE request, carrying this mode's own squad.
	assert_int(loader.begin_swap_count - begin_swap_count_before).override_failure_message(
			"request_transition(BATTLE) recorded exactly once").is_equal(1)
	var args: Array = loader.last_begin_swap_args
	assert_int(args[1] as int).override_failure_message(
			"begin_swap target is BATTLE").is_equal(GameStateMachine.Mode.BATTLE)
	var payload: BattleEntryPayload = args[2] as BattleEntryPayload
	assert_object(payload).is_not_null()
	assert_int(payload.party.size()).is_equal(squad.size())
	for i in squad.size():
		assert_bool(is_same(payload.party[i], squad[i])).override_failure_message(
				"party[%d] is the mode's own Combatant instance" % i).is_true()


func test_thaw_victory_advances() -> void:
	# Arrange
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var chapter_mode: ChapterMode = auto_free(ChapterMode.new())
	chapter_mode.squad = ChapterFlowExpected.make_squad()
	chapter_mode.setup(env["machine"], null)
	var starting_index: int = chapter_mode.chapter.current_fight_index

	# Act
	chapter_mode.on_thawed("encounter_fixture", GameStateMachine.BattleResult.VICTORY)

	# Assert
	assert_int(chapter_mode.chapter.current_fight_index).override_failure_message(
			"VICTORY advances to the next fight index").is_equal(starting_index + 1)


func test_thaw_fled_repeats() -> void:
	# Arrange
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var chapter_mode: ChapterMode = auto_free(ChapterMode.new())
	chapter_mode.squad = ChapterFlowExpected.make_squad()
	chapter_mode.setup(env["machine"], null)
	var starting_index: int = chapter_mode.chapter.current_fight_index

	# Act
	chapter_mode.on_thawed("encounter_fixture", GameStateMachine.BattleResult.FLED)

	# Assert
	assert_int(chapter_mode.chapter.current_fight_index).override_failure_message(
			"FLED repeats the same fight index").is_equal(starting_index)


func test_thaw_victory_at_boss_emits_chapter_won_once() -> void:
	# Arrange: advance to the boss fight (index REGULAR_FIGHT_COUNT).
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var chapter_mode: ChapterMode = auto_free(ChapterMode.new())
	chapter_mode.squad = ChapterFlowExpected.make_squad()
	chapter_mode.setup(env["machine"], null)
	# A box: GDScript lambdas capture ints by value, so a plain counter would
	# never change outside the lambda.
	var chapter_won_count: Array[int] = [0]
	chapter_mode.chapter.chapter_won.connect(func() -> void: chapter_won_count[0] += 1)
	for _i in ChapterFlow.REGULAR_FIGHT_COUNT:
		chapter_mode.on_thawed("encounter_fixture", GameStateMachine.BattleResult.VICTORY)

	# Act: win the boss fight.
	chapter_mode.on_thawed("encounter_fixture", GameStateMachine.BattleResult.VICTORY)

	# Assert
	assert_int(chapter_won_count[0]).override_failure_message(
			"boss VICTORY emits chapter_won exactly once").is_equal(1)


## Bounded 1/60s-tick loop until the transition reaches IDLE (same pattern as
## `game_state_retreat_offer_test.gd`).
func _run_to_idle(machine: GameStateMachine) -> void:
	var ticks: int = 0
	while machine.phase != GameStateMachine.Phase.IDLE and ticks < 600:
		machine.tick(1.0 / 60.0)
		ticks += 1
	assert_bool(ticks < 600).override_failure_message(
			"transition did not finish within 600 ticks of 1/60s").is_true()
