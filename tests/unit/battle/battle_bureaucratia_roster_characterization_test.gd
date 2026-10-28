## Story 003 (ADR-0001 Migration Step 0; ADR-0011 §5): pins the Clerk and
## Supervisor stat blocks against today's `BureaucratiaRule` factories, built
## only through `BattleContentSeam.enemy()`. Pinned values live in
## `CharacterizationExpected.ENEMY_STATS`, read once from today's code — never
## a reference to `BureaucratiaRule`'s own consts.
extends GdUnitTestSuite

const _IDS: Array[String] = ["enemy_clerk", "enemy_supervisor"]


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


## Edge case: two calls for the same id return different objects.
func test_two_calls_for_the_same_id_return_different_objects() -> void:
	for id: String in _IDS:
		assert_object(BattleContentSeam.enemy(id)).override_failure_message(id) \
				.is_not_same(BattleContentSeam.enemy(id))


## Edge case: damaging one instance (through the seam) leaves the other at
## full HP — there is no shared state between two `seam.enemy()` calls.
func test_damaging_one_instance_leaves_the_other_at_full_hp() -> void:
	for id: String in _IDS:
		var a: Combatant = BattleContentSeam.enemy(id)
		var b: Combatant = BattleContentSeam.enemy(id)

		BattleContentSeam.arrange_vitals(a, 1, 0)

		assert_int(a.hp).override_failure_message(id).is_equal(1)
		assert_int(b.hp).override_failure_message(id).is_equal(b.max_hp)
