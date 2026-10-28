## Story 003/merged story 004 (ADR-0001 Migration Step 0; ADR-0011 §5): pins
## the Security Drone, Middle Manager and CEO stat blocks against today's
## `MegaCorpRule` factories, built only through `BattleContentSeam.enemy()`.
## `display_name` matters here: today's MegaCorp AI branches on
## `enemy.display_name == "Middle Manager"` (story 026 moves this to
## `record_id`; story 006's AI pins prove the result is unchanged). Pinned
## values live in `CharacterizationExpected.ENEMY_STATS`, read once from
## today's code — never a reference to `MegaCorpRule`'s own consts.
extends GdUnitTestSuite

const _IDS: Array[String] = ["enemy_security_drone", "enemy_middle_manager", "enemy_ceo"]


func test_stat_blocks_equal_the_pin_after_reset() -> void:
	for id: String in _IDS:
		var pin: Dictionary = CharacterizationExpected.ENEMY_STATS[id]
		var enemy: Combatant = BattleContentSeam.enemy(id)
		enemy.reset_for_battle()

		assert_str(enemy.display_name).override_failure_message(id).is_equal(pin["display_name"])
		assert_int(enemy.max_hp).override_failure_message(id).is_equal(pin["max_hp"])
		assert_int(enemy.max_mp).override_failure_message(id).is_equal(pin["max_mp"])
		assert_int(enemy.attack).override_failure_message(id).is_equal(pin["attack"])
		assert_int(enemy.defense).override_failure_message(id).is_equal(pin["defense"])
		assert_int(enemy.speed).override_failure_message(id).is_equal(pin["speed"])
		assert_bool(enemy.is_enemy).override_failure_message(id).is_true()
		assert_bool(enemy.is_boss).override_failure_message(id).is_equal(pin["is_boss"])
		assert_int(enemy.hp).override_failure_message(id).is_equal(pin["max_hp"])
		assert_int(enemy.mp).override_failure_message(id).is_equal(pin["max_mp"])


## Edge case: `display_name == "Middle Manager"` is pinned exactly — today's
## MegaCorp AI keys off this exact string.
func test_middle_manager_display_name_is_pinned_exactly() -> void:
	assert_str(BattleContentSeam.enemy("enemy_middle_manager").display_name).is_equal("Middle Manager")


## Edge case: repeated calls return distinct instances.
func test_repeated_calls_return_distinct_instances() -> void:
	for id: String in _IDS:
		assert_object(BattleContentSeam.enemy(id)).override_failure_message(id) \
				.is_not_same(BattleContentSeam.enemy(id))
