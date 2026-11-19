## Run (the Turn Battle GDD's owed Flee section, rigor minimal): a fleeable
## fight lists Run; it succeeds on `BattleConfig.flee_chance` and is
## reported as Fled; a failed attempt passes the actor's turn and changes
## nothing else. A fight that cannot be fled (bosses) has no Run.
extends GdUnitTestSuite


func before() -> void:
	BattleContentSeam.ensure_catalog()


func _mode(can_flee: bool, chance: float) -> BattleMode:
	var mode: BattleMode = auto_free(preload("res://src/battle/battle_mode.tscn").instantiate() as BattleMode)
	var cfg := BattleConfig.new()
	cfg.flee_chance = chance
	mode.battle_config = cfg
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "run_test"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	descriptor.can_flee = can_flee
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 10, 12, 8, 10, false),
	] as Array[Combatant]
	mode.setup(null, payload)
	add_child(mode)
	# The menu opens once the reveal has played (as after the battle wipe).
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	var guard: int = 0
	while mode.is_presenting() and guard < 600:
		mode.step_replay(0.1)
		guard += 1
	return mode


func _run_button(mode: BattleMode) -> Button:
	for b: Node in mode.get_node("%BattleCommandMenu").get_node("%CommandList").find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and (b as Button).text.begins_with("Run"):
			return b as Button
	return null


func test_fleeable_fight_lists_run_last() -> void:
	var mode := _mode(true, 0.75)
	var list: Node = mode.get_node("%BattleCommandMenu").get_node("%CommandList")
	assert_str((list.get_child(list.get_child_count() - 1) as Button).text).is_equal("Run")


func test_fight_that_cannot_be_fled_has_no_run() -> void:
	assert_object(_run_button(_mode(false, 0.75))).is_null()


func test_successful_run_reports_fled_and_ends_no_turn() -> void:
	var mode := _mode(true, 1.0)
	var actor: Combatant = mode.battle.get_active_combatant()

	_run_button(mode).pressed.emit()

	assert_bool(mode.fled).is_true()
	assert_object(mode.battle.get_active_combatant()).is_same(actor)
	assert_int(mode.battle.outcome_log.size()).is_equal(0)


func test_failed_run_passes_the_turn_and_changes_nothing_else() -> void:
	var mode := _mode(true, 0.0)
	var first: Combatant = mode.battle.get_active_combatant()
	var hp: Array[int] = []
	for c: Combatant in mode.battle.squad + mode.battle.enemies:
		hp.append(c.hp)

	_run_button(mode).pressed.emit()

	assert_bool(mode.fled).is_false()
	assert_object(mode.battle.get_active_combatant()).is_not_same(first)
	var last: BattleOutcome = mode.battle.outcome_log.back()
	assert_int(last.category).is_equal(Move.Category.RUN)
	assert_int(last.hp_delta).is_equal(0)
	var i: int = 0
	for c: Combatant in mode.battle.squad + mode.battle.enemies:
		assert_int(c.hp).is_equal(hp[i])
		i += 1
