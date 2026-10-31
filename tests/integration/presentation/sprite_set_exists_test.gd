## Story 034, AC-30 (ADR-0005 §9 `sprite_set_exists`): a character or enemy
## record whose `sprite_set_id` is not in the root's sprite-set table ends
## boot in Content Error naming the record; the reserved checkerboard
## placeholder id `sprite_placeholder` is always known, so a root whose
## records all use it boots READY (the state Boot needs to reach Title).
## Fixture roots copy content-data's `valid_one_of_each` and add a
## `presentation/sprite_sets` table holding one shipped set (`sprite_clerk`).
extends GdUnitTestSuite

const _UNKNOWN_ROOT := "res://tests/integration/presentation/fixtures/sprite_set_unknown"
const _PLACEHOLDER_ROOT := "res://tests/integration/presentation/fixtures/sprite_set_placeholder"


func _boot(root: String) -> ContentCatalogService:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	ContentBootstrap.run(catalog, root)
	return catalog


func _report_text(catalog: ContentCatalogService) -> String:
	var lines: PackedStringArray = []
	for entry: Dictionary in catalog.report:
		lines.append(str(entry))
	return "\n".join(lines)


func test_unknown_sprite_set_id_on_character_and_enemy_ends_boot_in_content_error() -> void:
	var catalog := _boot(_UNKNOWN_ROOT)
	var text: String = _report_text(catalog)
	assert_int(catalog.state).override_failure_message(text) \
			.is_equal(ContentCatalogService.State.FAILED)
	assert_bool(text.contains(PresentationValidators.RULE_SPRITE_SET_EXISTS)).override_failure_message(text).is_true()
	# Both halves: the character record and the (migrated) enemy record.
	assert_bool(text.contains("char_baguette_thrower")).is_true()
	assert_bool(text.contains("sprite_set_baguette")).is_true()
	assert_bool(text.contains("enemy_bureaucrat_drone")).is_true()
	assert_bool(text.contains("sprite_set_drone")).is_true()


func test_checkerboard_placeholder_id_boots_ready() -> void:
	var catalog := _boot(_PLACEHOLDER_ROOT)
	assert_int(catalog.state).override_failure_message(_report_text(catalog)) \
			.is_equal(ContentCatalogService.State.READY)


func test_validator_passes_known_ids_and_the_placeholder_and_flags_the_rest() -> void:
	var validator: Callable = PresentationValidators.make_sprite_set_exists_validator(
			{&"sprite_clerk": true})
	var known := CharacterData.new()
	known.id = "char_x"
	known.sprite_set_id = "sprite_clerk"
	var placeholder := CharacterData.new()
	placeholder.id = "char_y"
	placeholder.sprite_set_id = PresentationValidators.PLACEHOLDER_SET_ID
	var unknown := EnemyData.new()
	unknown.id = "enemy_z"
	unknown.sprite_set_id = "sprite_nobody"
	assert_array(validator.call(known)).is_empty()
	assert_array(validator.call(placeholder)).is_empty()
	var errors: Array = validator.call(unknown)
	assert_int(errors.size()).is_equal(1)
	assert_str(String(errors[0]["field"])).is_equal("sprite_set_id")


## The shipped data's every character and enemy names a shipped set.
func test_shipped_data_boots_ready_with_the_existence_check() -> void:
	var catalog := _boot("res://data")
	assert_int(catalog.state).override_failure_message(_report_text(catalog)) \
			.is_equal(ContentCatalogService.State.READY)
