## Story 032 (ADR-0002 Migration Step 0, check 5): pins the retry semantics as
## a record of what moves to the Battle mode's snapshot in Story 034 -- a
## loss restores the squad to *that fight's own* starting hp/mp (not a full
## heal, and not the chapter's original starting state), and the retried
## fight gets a fresh full-HP enemy roster.
##
## Marked to move to tests/unit/battle/ in Story 034 (Implementation Notes,
## ADR-0010 §7).
extends GdUnitTestSuite


func test_loss_restores_start_state() -> void:
	# Arrange: fight 0 carries in a squad already below full, so fight 0's
	# own start snapshot (taken at _start_fight(0), before start()'s caller
	# can observe it) captures these values, not full HP.
	var rng := RandomNumberGenerator.new()
	rng.seed = ChapterFlowExpected.SEED
	var squad: Array[Combatant] = ChapterFlowExpected.make_squad()
	squad[0].hp = 18
	squad[0].mp = 4
	var probe := ChapterFlowProbe.new(ChapterFlow.FACTION_BUREAUCRATIA, squad, rng)
	probe.start()

	# Act: damage the squad further mid-fight, then lose.
	squad[0].hp = 5
	squad[0].mp = 1
	probe.lose_current()

	# Assert: squad restored to the fight-start snapshot, not the damaged
	# values and not a full heal.
	var hp_mp: Array[Dictionary] = probe.squad_hp_mp()
	assert_int(hp_mp[0]["hp"]).override_failure_message(
			"fight-start hp restored on loss, not a full heal").is_equal(18)
	assert_int(hp_mp[0]["mp"]).override_failure_message(
			"fight-start mp restored on loss, not a full heal").is_equal(4)
	assert_int(probe.fight_lost_count).override_failure_message(
			"fight_lost emitted exactly once").is_equal(1)

	# The retry stays on the same fight index and gets a fresh full-HP roster.
	var fight: Dictionary = probe.current_fight()
	assert_int(fight["index"]).override_failure_message(
			"retry stays on the same fight index").is_equal(0)
	for enemy: Combatant in probe.chapter.current_battle.enemies:
		assert_int(enemy.hp).override_failure_message(
				"%s is reset to full hp on retry" % enemy.display_name).is_equal(enemy.max_hp)
