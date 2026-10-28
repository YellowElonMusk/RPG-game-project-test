## Story 032's retry semantics, moved to the Battle mode (ADR-0002 Migration
## Step 2; Implementation Notes): a loss restores the squad to *this fight's
## own* starting hp/mp (not a full heal, and not some earlier chapter state),
## and the retried fight's enemies are back at full HP, on the same
## `BattleCore`. Expected values unchanged from the retired
## tests/unit/chapters/chapter_flow_retry_test.gd (Story 033 Completion Notes).
extends GdUnitTestSuite


func test_loss_restores_fight_start_state() -> void:
	# Arrange: a BattleMode built directly (no GameStateMachine involved --
	# capture/restore are called straight through, as the machine itself
	# would), with a squad already below full so the fight-start snapshot
	# captures those values, not full HP.
	var mode: BattleMode = preload("res://src/battle/battle_mode.tscn").instantiate() as BattleMode
	auto_free(mode)
	var squad: Array[Combatant] = [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 10, 12, 8, 10, false),
	]
	squad[0].hp = 18
	squad[0].mp = 4
	var descriptor := EncounterDescriptor.new()
	descriptor.encounter_id = "bureaucratia_fight_0"
	descriptor.enemy_ids = PackedStringArray(["enemy_clerk"])
	descriptor.faction_id = "faction_bureaucratia"
	descriptor.is_boss = false
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = squad
	mode.setup(null, payload)
	assert_object(mode.battle).override_failure_message(
			"BattleMode failed to build from a valid descriptor").is_not_null()

	var snapshot: RefCounted = mode.capture_start_snapshot()
	assert_object(snapshot).is_not_null()

	# Act: damage the squad further mid-fight, then retry.
	squad[0].hp = 5
	squad[0].mp = 1
	mode.battle.enemies[0].hp = 0

	var battle_before: BattleCore = mode.battle
	mode.restore_start_snapshot(snapshot)

	# Assert: squad restored to the fight-start snapshot, not the damaged
	# values and not a full heal.
	assert_int(squad[0].hp).override_failure_message(
			"fight-start hp restored on loss, not a full heal").is_equal(18)
	assert_int(squad[0].mp).override_failure_message(
			"fight-start mp restored on loss, not a full heal").is_equal(4)

	# The retry stays on the same BattleCore and gets a fresh full-HP roster.
	assert_bool(is_same(mode.battle, battle_before)).override_failure_message(
			"Retry rebuilt the BattleCore instead of reusing it").is_true()
	for enemy: Combatant in mode.battle.enemies:
		assert_int(enemy.hp).override_failure_message(
				"%s is reset to full hp on retry" % enemy.display_name).is_equal(enemy.max_hp)
