## Content-migration story 024 (merged with 025; ADR-0001 Migration Step 3;
## ADR-0011 §5): the five roster factories build their Combatants from their
## Enemy records through `EnemyAdapter`, tagged with `record_id`, and fail
## loudly (never falling back to the old constants) when a record is missing.
## Expected values are read from the catalog record itself.
extends GdUnitTestSuite

## Record ID -> its roster factory.
func _factories() -> Dictionary:
	return {
		"enemy_clerk": BureaucratiaRule.make_clerk,
		"enemy_supervisor": BureaucratiaRule.make_supervisor,
		"enemy_security_drone": MegaCorpRule.make_security_drone,
		"enemy_middle_manager": MegaCorpRule.make_middle_manager,
		"enemy_ceo": MegaCorpRule.make_ceo,
	}


func before() -> void:
	BattleContentSeam.ensure_catalog()


func test_factories_copy_their_records_with_record_id() -> void:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	var factories: Dictionary = _factories()
	for id: String in factories:
		var rec: EnemyData = catalog.get_record(&"enemy", id) as EnemyData
		var enemy: Combatant = (factories[id] as Callable).call() as Combatant
		assert_object(enemy).override_failure_message(id).is_not_null()
		assert_str(enemy.record_id).is_equal(id)
		assert_str(enemy.display_name).is_equal(rec.display_name)
		assert_int(enemy.max_hp).is_equal(rec.max_hp)
		assert_int(enemy.max_mp).is_equal(rec.max_mp)
		assert_int(enemy.attack).is_equal(rec.attack)
		assert_int(enemy.defense).is_equal(rec.defense)
		assert_int(enemy.speed).is_equal(rec.speed)
		assert_bool(enemy.is_boss).is_equal(rec.is_boss)
		assert_bool(enemy.is_enemy).is_true()
		assert_int(enemy.hp).is_equal(rec.max_hp)
		assert_array(Array(enemy.move_ids)).is_empty()


func test_two_calls_are_not_the_same_instance() -> void:
	assert_object(BureaucratiaRule.make_clerk()).is_not_same(BureaucratiaRule.make_clerk())
	assert_object(MegaCorpRule.make_ceo()).is_not_same(MegaCorpRule.make_ceo())


func test_from_record_null_is_null_with_push_error() -> void:
	await assert_error(func() -> void: EnemyAdapter.from_record(null)) \
			.is_push_error("EnemyAdapter.from_record: null record.")
	assert_object(EnemyAdapter.from_record(null)).is_null()


func test_unknown_id_is_null_missing_id_no_fallback() -> void:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	assert_object(EnemyAdapter.from_catalog(catalog, "enemy_nope")).is_null()
	assert_str(String(catalog.last_lookup_error)).is_equal("missing_id")


func test_record_id_is_immutable_after_construction() -> void:
	var clerk: Combatant = BureaucratiaRule.make_clerk()
	clerk.record_id = "enemy_other"
	assert_str(clerk.record_id).is_equal("enemy_clerk")


func test_middle_manager_ai_branch_still_upsells() -> void:
	var squad: Array[Combatant] = [Combatant.new("Fixture", 30, 10, 10, 8, 10, false)]
	var actions: Array = MegaCorpRule.new().choose_enemy_action(
			MegaCorpRule.make_middle_manager(), squad, 1, RandomNumberGenerator.new())
	var expected: MoveData = BattleCatalog.shipped().get_record(&"move", "move_upsell") as MoveData
	assert_str((actions[0]["move"] as Move).display_name).is_equal(expected.display_name)
