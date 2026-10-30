## Content-migration stories 023 and 028 (ADR-0001 EffectDescriptor adapter,
## Migration Steps 3-4; ADR-0010 §8): `MoveAdapter.from_record()` maps each of
## the six migrated EffectDescriptor types to its pinned category / special
## effect / power / rounds, refuses anything it cannot represent, and the five
## `SquadSpecials` factories return exactly the adapted squad-special records.
## The six-type cases build in-memory `MoveData` (no file I/O); expected
## values are read from the record the case built, through ADR-0010 §8's table.
extends GdUnitTestSuite

## Record ID -> its `SquadSpecials` factory.
func _special_factories() -> Dictionary:
	return {
		"move_speak_to_the_manager": SquadSpecials.make_speak_to_the_manager,
		"move_family_meal": SquadSpecials.make_family_meal,
		"move_appetizer": SquadSpecials.make_appetizer,
		"move_viral_stunt": SquadSpecials.make_viral_stunt,
		"move_home_run": SquadSpecials.make_home_run,
	}


func before() -> void:
	BattleContentSeam.ensure_catalog()


## In-memory record factory: one descriptor `{type, ...params}`.
func _record(effect: Dictionary, target_type: String = "single_enemy", cost: int = 3,
		display_name: String = "Fixture Move") -> MoveData:
	var rec := MoveData.new()
	rec.id = "move_fixture"
	rec.display_name = display_name
	rec.target_type = target_type
	rec.cost = cost
	rec.effects = [effect]
	return rec


# --- AC-1 (story 023): six types map ---

func test_from_record_six_types_map_to_pinned_fields(effect: Dictionary, category: int,
		special: int, power_key: String, rounds_key: String, test_parameters := [
			[{"type": "damage", "power": 16}, Move.Category.ATTACK, Move.SpecialEffect.NONE, "power", ""],
			[{"type": "stun"}, Move.Category.SPECIAL, Move.SpecialEffect.STUN, "", ""],
			[{"type": "heal_party", "power": 5}, Move.Category.SPECIAL, Move.SpecialEffect.HEAL_PARTY, "power", ""],
			[{"type": "heal_single", "power": 10}, Move.Category.SPECIAL, Move.SpecialEffect.HEAL_SINGLE, "power", ""],
			[{"type": "damage_debuff", "rounds": 2}, Move.Category.SPECIAL, Move.SpecialEffect.DAMAGE_DEBUFF, "", "rounds"],
			[{"type": "direct_damage", "power": 18}, Move.Category.SPECIAL, Move.SpecialEffect.DIRECT_DAMAGE, "power", ""],
		]) -> void:
	var rec: MoveData = _record(effect, "single_ally", 4, "Pinned")
	var move: Move = MoveAdapter.from_record(rec)
	assert_object(move).is_not_null()
	assert_int(move.category).is_equal(category)
	assert_int(move.special_effect).is_equal(special)
	assert_int(move.power).is_equal(int(effect.get(power_key, 0)) if not power_key.is_empty() else 0)
	assert_int(move.effect_rounds).is_equal(int(effect.get(rounds_key, 0)) if not rounds_key.is_empty() else 0)
	assert_int(move.mp_cost).is_equal(rec.cost)
	assert_int(move.target_type).is_equal(Move.TargetType.SINGLE_ALLY)
	assert_str(move.display_name).is_equal(rec.display_name)


func test_from_record_target_type_strings_map(value: String, expected: int, test_parameters := [
		["self", Move.TargetType.SELF],
		["single_enemy", Move.TargetType.SINGLE_ENEMY],
		["single_ally", Move.TargetType.SINGLE_ALLY]]) -> void:
	assert_int(MoveAdapter.from_record(_record({"type": "damage", "power": 1}, value)).target_type) \
			.is_equal(expected)


func test_from_record_unknown_type_is_null_with_push_error() -> void:
	var rec: MoveData = _record({"type": "teleport", "power": 3})
	await assert_error(func() -> void: MoveAdapter.from_record(rec)) \
			.is_push_error("MoveAdapter.from_record(move_fixture): unregistered effect type 'teleport'.")
	assert_object(MoveAdapter.from_record(rec)).is_null()


func test_from_record_two_descriptors_refused() -> void:
	var rec: MoveData = _record({"type": "damage", "power": 3})
	rec.effects.append({"type": "stun"})
	assert_object(MoveAdapter.from_record(rec)).is_null()


func test_from_record_null_record_is_null() -> void:
	assert_object(MoveAdapter.from_record(null)).is_null()


func test_from_record_stun_with_no_power_gives_zero() -> void:
	assert_int(MoveAdapter.from_record(_record({"type": "stun"})).power).is_equal(0)


func test_mutating_returned_move_leaves_record_unchanged() -> void:
	var rec: MoveData = _record({"type": "damage", "power": 7})
	var move: Move = MoveAdapter.from_record(rec)
	move.power = 99
	move.display_name = "Changed"
	assert_int(int(rec.effects[0]["power"])).is_equal(7)
	assert_str(rec.display_name).is_equal("Fixture Move")


func test_from_catalog_missing_id_is_null() -> void:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	assert_object(MoveAdapter.from_catalog(catalog, "move_does_not_exist")).is_null()
	assert_str(String(catalog.last_lookup_error)).is_equal("missing_id")


# --- AC-1 (story 023): both rules' named attacks come from their records ---

func test_named_attacks_match_their_records() -> void:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	for id: String in ["move_pen_jab", "move_red_tape", "move_late_fee", "move_mass_audit",
			"move_final_notice", "move_laser_scan", "move_upsell", "move_layoffs",
			"move_hostile_takeover"]:
		var rec: MoveData = catalog.get_record(&"move", id) as MoveData
		var move: Move = BattleContentSeam.move(id)
		assert_str(move.display_name).is_equal(rec.display_name)
		assert_int(move.power).is_equal(int(rec.effects[0]["power"]))
		assert_int(move.category).is_equal(Move.Category.ATTACK)


# --- AC-1 (story 028): the five specials factories return adapted records ---

func test_specials_factories_equal_adapted_records() -> void:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	var factories: Dictionary = _special_factories()
	for id: String in factories:
		var expected: Move = MoveAdapter.from_record(catalog.get_record(&"move", id) as MoveData)
		var actual: Move = (factories[id] as Callable).call() as Move
		assert_object(actual).override_failure_message(id).is_not_null()
		assert_str(actual.display_name).is_equal(expected.display_name)
		assert_int(actual.category).is_equal(expected.category)
		assert_int(actual.mp_cost).is_equal(expected.mp_cost)
		assert_int(actual.power).is_equal(expected.power)
		assert_int(actual.target_type).is_equal(expected.target_type)
		assert_int(actual.special_effect).is_equal(expected.special_effect)
		assert_int(actual.effect_rounds).is_equal(expected.effect_rounds)


func test_viral_stunt_rounds_come_from_descriptor() -> void:
	var rec: MoveData = BattleCatalog.shipped().get_record(&"move", "move_viral_stunt") as MoveData
	assert_int(SquadSpecials.make_viral_stunt().effect_rounds).is_equal(int(rec.effects[0]["rounds"]))
