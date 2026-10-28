## Story 033 (ADR-0002 Migration Plan Step 2, Check 3): pins
## `ChapterFlow.build_next_descriptor()`'s fields across every fight index,
## both factions. Never a win-rate or balance assertion -- every expected
## value here is ADR-0010 §3's interim enemy-id table or this story's own
## placeholder fields (Implementation Notes).
extends GdUnitTestSuite

## Fight index 0..3 crossed with both factions (Check 3).
const _CASES: Array = [
	[0, "bureaucratia"], [1, "bureaucratia"], [2, "bureaucratia"], [3, "bureaucratia"],
	[0, "megacorp"], [1, "megacorp"], [2, "megacorp"], [3, "megacorp"],
]

## ADR-0010 §3's interim per-fight enemy ids, keyed "<faction>_<index>".
const _ENEMY_IDS: Dictionary = {
	"bureaucratia_0": ["enemy_clerk"], "bureaucratia_1": ["enemy_clerk"],
	"bureaucratia_2": ["enemy_clerk"], "bureaucratia_3": ["enemy_supervisor"],
	"megacorp_0": ["enemy_security_drone"], "megacorp_1": ["enemy_middle_manager"],
	"megacorp_2": ["enemy_security_drone"], "megacorp_3": ["enemy_ceo"],
}


func test_descriptor_fields(fight_index: int, faction: String, test_parameters := _CASES) -> void:
	# Arrange: advance a fresh ChapterFlow to `fight_index` -- only through
	# the public advance_on_victory(), never a shortcut into a private field.
	var chapter := ChapterFlow.new(faction, ChapterFlowExpected.make_squad())
	chapter.start_chapter()
	for _i in fight_index:
		chapter.advance_on_victory()
	var expected_is_boss: bool = fight_index == ChapterFlow.REGULAR_FIGHT_COUNT
	var key: String = "%s_%d" % [faction, fight_index]

	# Act
	var descriptor: EncounterDescriptor = chapter.build_next_descriptor()

	# Assert
	assert_str(descriptor.encounter_id).override_failure_message(
			"%s fight %d encounter_id is non-empty" % [faction, fight_index]).is_not_empty()
	assert_array(Array(descriptor.enemy_ids)).override_failure_message(
			"%s fight %d enemy_ids" % [faction, fight_index]).is_equal(_ENEMY_IDS[key] as Array)
	assert_str(descriptor.faction_id).override_failure_message(
			"%s fight %d faction_id" % [faction, fight_index]).is_equal(ChapterFlow.FACTION_RECORD_PREFIX + faction)
	assert_bool(descriptor.is_boss).override_failure_message(
			"%s fight %d is_boss" % [faction, fight_index]).is_equal(expected_is_boss)
	assert_bool(descriptor.can_flee).override_failure_message(
			"%s fight %d can_flee" % [faction, fight_index]).is_equal(not expected_is_boss)
	assert_bool(descriptor.retreat_allowed).override_failure_message(
			"%s fight %d retreat_allowed" % [faction, fight_index]).is_false()
	assert_str(descriptor.battle_stage_id).override_failure_message(
			"%s fight %d battle_stage_id" % [faction, fight_index]).is_equal(ChapterFlow.BATTLE_STAGE_ID_INTERIM)


func test_encounter_id_unique_per_fight() -> void:
	# Arrange
	var chapter := ChapterFlow.new(ChapterFlow.FACTION_BUREAUCRATIA, ChapterFlowExpected.make_squad())
	chapter.start_chapter()
	var seen_ids: Dictionary = {}

	# Act / Assert
	for index in (ChapterFlow.REGULAR_FIGHT_COUNT + 1):
		var descriptor: EncounterDescriptor = chapter.build_next_descriptor()
		assert_bool(seen_ids.has(descriptor.encounter_id)).override_failure_message(
				"fight %d encounter_id '%s' reused" % [index, descriptor.encounter_id]).is_false()
		seen_ids[descriptor.encounter_id] = true
		if index < ChapterFlow.REGULAR_FIGHT_COUNT:
			chapter.advance_on_victory()
