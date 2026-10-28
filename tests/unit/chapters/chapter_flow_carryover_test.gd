## Story 032 (ADR-0002 Migration Step 0): pins HP/MP carryover between fights
## (check 3 -- "fight N+1 starts at fight N's end HP/MP") and the effect of
## `_clear_squad_transients()` at the start of each new fight (check 6 --
## is_defending/is_stunned/vulnerable_rounds_left are cleared, hp/mp are not
## touched).
extends GdUnitTestSuite


func test_hp_mp_carry() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = ChapterFlowExpected.SEED
	var squad: Array[Combatant] = ChapterFlowExpected.make_squad()
	var probe := ChapterFlowProbe.new(ChapterFlow.FACTION_BUREAUCRATIA, squad, rng)
	probe.start()

	# Act: set the squad's hp/mp mid-fight 0, then win it.
	squad[0].hp = 11
	squad[0].mp = 2
	squad[1].hp = 20
	squad[1].mp = 5
	probe.win_current()

	# Assert: fight 1 starts at exactly those values.
	var hp_mp: Array[Dictionary] = probe.squad_hp_mp()
	assert_int(hp_mp[0]["hp"]).override_failure_message("member 0 hp carries over").is_equal(11)
	assert_int(hp_mp[0]["mp"]).override_failure_message("member 0 mp carries over").is_equal(2)
	assert_int(hp_mp[1]["hp"]).override_failure_message("member 1 hp carries over").is_equal(20)
	assert_int(hp_mp[1]["mp"]).override_failure_message("member 1 mp carries over").is_equal(5)


func test_clear_squad_transients_resets_combat_flags_on_new_fight() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = ChapterFlowExpected.SEED
	var squad: Array[Combatant] = ChapterFlowExpected.make_squad()
	var probe := ChapterFlowProbe.new(ChapterFlow.FACTION_BUREAUCRATIA, squad, rng)
	probe.start()

	# Act: leave fight 0's transient combat flags set, then win it -- fight
	# 1's _start_fight() calls _clear_squad_transients() before anything else.
	squad[0].is_defending = true
	squad[1].is_stunned = true
	squad[0].vulnerable_rounds_left = 2
	probe.win_current()

	# Assert
	assert_bool(squad[0].is_defending).override_failure_message(
			"is_defending cleared on the new fight").is_false()
	assert_bool(squad[1].is_stunned).override_failure_message(
			"is_stunned cleared on the new fight").is_false()
	assert_int(squad[0].vulnerable_rounds_left).override_failure_message(
			"vulnerable_rounds_left cleared on the new fight").is_equal(0)
