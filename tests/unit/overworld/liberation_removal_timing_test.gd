## Story 060, AC-26a (GDD rules 9, 7): an on-screen liberated marker's
## removal has not started before `transition_finished`, has started after
## it, and is complete, with its cells freed, at `transition_finished +
## liberation_duration_s + dt` on the mode clock. An off-screen one is
## removed in `on_thawed`, cells freed then. A Dialogue due from the same
## battle opens after the on-screen removal ends.
extends GdUnitTestSuite

const _CLERK: String = "enc_paris_clerks_east"
const _QUEUE_AT: Vector2 = Vector2(13.0, 14.5)
const _DT: float = 1.0 / 60.0


func test_on_screen_removal_runs_from_the_reveal() -> void:
	var mode: OverworldMode = _mode(_QUEUE_AT + Vector2(-2.0, 0.0))
	var queue: GagInteractable = _queue(mode)
	var cell: Vector2i = mode.get_walk_grid().cell_of(_QUEUE_AT)
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_false()
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	# Before the reveal: still standing, still blocking.
	assert_bool(mode.is_removing(queue)).is_true()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_false()
	_reveal(mode)
	mode.tick_timed_text(mode.config.liberation_duration_s - _DT)
	assert_bool(mode.is_removing(queue)).is_true()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_false()
	mode.tick_timed_text(2.0 * _DT)
	assert_bool(mode.is_removing(queue)).is_false()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_true()


func test_off_screen_removal_happens_in_on_thawed() -> void:
	var mode: OverworldMode = _mode(Vector2(1.5, 1.5))
	var cell: Vector2i = mode.get_walk_grid().cell_of(_QUEUE_AT)
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	assert_bool(mode.is_removing(_queue(mode))).is_false()
	assert_bool(mode.get_walk_grid().is_walkable(cell)).is_true()
	_reveal(mode)
	assert_str(mode.payoff_card_text).contains("Street cleared: Rue des Fixtures")


func test_a_dialogue_from_the_battle_waits_for_the_removal() -> void:
	var mode: OverworldMode = _mode(_QUEUE_AT + Vector2(-2.0, 0.0))
	# Longer than any payoff card, so the removal is what the line waits on.
	mode.config.liberation_duration_s = 30.0
	(mode.get("_after_payoff_card") as Array).append("A line from the battle.")
	mode.on_thawed(_CLERK, GameStateMachine.BattleResult.VICTORY)
	_reveal(mode)
	mode.tick_timed_text(mode.config.liberation_duration_s - _DT)
	assert_array(mode.lines_said).is_empty()
	mode.tick_timed_text(2.0 * _DT)
	assert_array(mode.lines_said).is_equal(["A line from the battle."])


func _reveal(mode: OverworldMode) -> void:
	(mode.get("_machine") as GameStateMachine).transition_finished.emit(GameStateMachine.Mode.OVERWORLD)


func _queue(mode: OverworldMode) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.marker_id == &"queue_fixture":
			return gag
	return null


func _mode(leader: Vector2) -> OverworldMode:
	var queue := GagInteractable.new()
	queue.marker_id = &"queue_fixture"
	queue.text = "A queue."
	queue.liberate_symbol = _CLERK
	queue.blocked_rect = Rect2(_QUEUE_AT - Vector2(0.5, 0.5), Vector2.ONE)
	queue.street_label = "Rue des Fixtures"
	queue.position = Vector3(_QUEUE_AT.x, 0.0, _QUEUE_AT.y)
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([queue]))
	mode.set_leader_position(leader)
	return mode
