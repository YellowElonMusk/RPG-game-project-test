## Story 018, AC-15 (TR-presentation-014; ADR-0005 §9 via ADR-0004
## `register_record_validator`): a sprite set missing a required animation
## from rule 10's table in a facing it uses (a squad set's `victory`
## included) fails Boot with a Content Error naming the set and the
## animation; a missing optional animation falls back with exactly one
## warning; with validation skipped, a `no_mirror` animation with no
## same-facing art shows the checkerboard and is never mirrored. Sets are
## built by factory functions; the catalog checks reuse valid_one_of_each.
extends GdUnitTestSuite

const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")

const VALID_ONE_OF_EACH := "res://tests/unit/content_data/fixtures/valid_one_of_each"
## The character record in valid_one_of_each and the set it names.
const CHARACTER_ID := "char_baguette_thrower"
const CHARACTER_SET := &"sprite_set_baguette"
## The enemy record in valid_one_of_each and the set it names.
const ENEMY_SET := &"sprite_set_drone"


func _anim(id: StringName, facing: StringName, move_name: String = "") -> SpriteAnimationData:
	var anim := SpriteAnimationData.new()
	anim.animation_id = id
	anim.facing = facing
	anim.move_name = move_name
	anim.fps = 10.0
	anim.frame_durations = PackedFloat32Array([1, 1, 1, 1])
	if anim.is_action():
		anim.impact_frame = 2
	if id == &"knockout":
		anim.land_frame = 3
	return anim


## A complete set: every required animation authored in every facing in
## `facings`, plus `victory` (back) when `is_squad`.
func _complete_set(set_id: StringName, is_squad: bool,
		facings: Array[StringName] = [&"front", &"back"]) -> SpriteSetData:
	var s := SpriteSetData.new()
	s.set_id = set_id
	s.is_squad = is_squad
	s.facings_used = facings
	for facing: StringName in facings:
		for id: StringName in SpriteSetData.REQUIRED_BATTLE:
			s.animations.append(_anim(id, facing))
	if is_squad:
		s.animations.append(_anim(SpriteSetData.VICTORY, SpriteSetData.VICTORY_FACING))
	return s


func _without(s: SpriteSetData, id: StringName, facing: StringName) -> SpriteSetData:
	var kept: Array[SpriteAnimationData] = []
	for anim: SpriteAnimationData in s.animations:
		if not (anim.animation_id == id and anim.facing == facing):
			kept.append(anim)
	s.animations = kept
	return s


func _required_errors(s: SpriteSetData, is_boss: bool = false) -> PackedStringArray:
	return PresentationValidators.validate_sprite_set(s, PresentationConfig.new(), is_boss)


# --- required animations -----------------------------------------------------

func test_complete_squad_set_has_no_errors() -> void:
	assert_array(Array(_required_errors(_complete_set(&"sprite_set_full", true)))).is_empty()


func test_each_missing_required_animation_names_set_and_animation() -> void:
	for id: StringName in SpriteSetData.REQUIRED_BATTLE:
		# A front-only set, so no back art can stand in for it.
		var s := _without(_complete_set(&"sprite_set_gap", false, [&"front"]), id, &"front")
		var errors := _required_errors(s)
		assert_int(errors.size()).override_failure_message("%s: %s" % [id, errors]).is_equal(1)
		if errors.size() != 1:
			continue
		assert_str(errors[0]).starts_with(PresentationValidators.RULE_REQUIRED)
		assert_str(errors[0]).contains("sprite_set_gap")
		assert_str(errors[0]).contains(String(id))


func test_missing_in_unused_facing_is_not_an_error() -> void:
	var s := _complete_set(&"sprite_set_front_only", false, [&"front"])
	assert_array(Array(_required_errors(s))).is_empty()


func test_mirrorable_opposite_facing_satisfies_requirement() -> void:
	var s := _without(_complete_set(&"sprite_set_mirror", false), &"hit", &"back")
	assert_array(Array(_required_errors(s))).is_empty()


func test_no_mirror_opposite_facing_does_not_satisfy_requirement() -> void:
	var s := _without(_complete_set(&"sprite_set_nomirror", false), &"hit", &"back")
	s.find(&"hit", &"front").no_mirror = true
	var errors := _required_errors(s)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("hit (back)")


func test_squad_set_without_victory_names_victory() -> void:
	var s := _without(_complete_set(&"sprite_set_squad", true),
			SpriteSetData.VICTORY, SpriteSetData.VICTORY_FACING)
	var errors := _required_errors(s)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("sprite_set_squad")
	assert_str(errors[0]).contains("victory")


func test_enemy_set_without_victory_passes() -> void:
	assert_array(Array(_required_errors(_complete_set(&"sprite_set_enemy", false)))).is_empty()


# --- Boot: the catalog fails on the record naming the set ---------------------

func _load_with_sets(sets: Dictionary[StringName, SpriteSetData]) -> ContentCatalogService:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	PresentationValidators.register_sprite_set_validators(catalog, sets, PresentationConfig.new())
	catalog.load_all(VALID_ONE_OF_EACH)
	return catalog


func test_boot_with_complete_sets_is_ready() -> void:
	var sets: Dictionary[StringName, SpriteSetData] = {
		CHARACTER_SET: _complete_set(CHARACTER_SET, true),
		ENEMY_SET: _complete_set(ENEMY_SET, false),
	}
	var catalog := _load_with_sets(sets)
	assert_int(catalog.state).override_failure_message("report: %s" % [catalog.report]) \
			.is_equal(ContentCatalogService.State.READY)


func test_boot_with_missing_required_animation_is_content_error() -> void:
	var sets: Dictionary[StringName, SpriteSetData] = {
		CHARACTER_SET: _without(_complete_set(CHARACTER_SET, true), &"defend", &"front"),
		ENEMY_SET: _complete_set(ENEMY_SET, false),
	}
	sets[CHARACTER_SET].find(&"defend", &"back").no_mirror = true
	var catalog := _load_with_sets(sets)

	assert_int(catalog.state).is_equal(ContentCatalogService.State.FAILED)
	var errors: Array = ReportFilters.errors(catalog.report)
	assert_int(errors.size()).override_failure_message("report: %s" % [catalog.report]).is_equal(1)
	if errors.size() != 1:
		return
	var entry: Dictionary = errors[0]
	assert_str(entry["record_id"]).is_equal(CHARACTER_ID)
	assert_str(String(entry["field"])).is_equal("sprite_set_id")
	assert_str(entry["message"]).contains(String(CHARACTER_SET))
	assert_str(entry["message"]).contains("defend")


func test_boot_ignores_unknown_and_placeholder_set_ids() -> void:
	var sets: Dictionary[StringName, SpriteSetData] = {}
	var catalog := _load_with_sets(sets)
	assert_int(catalog.state).is_equal(ContentCatalogService.State.READY)
	var validator := PresentationValidators.make_record_validator(sets, PresentationConfig.new())
	var record := CharacterData.new()
	record.sprite_set_id = PresentationValidators.PLACEHOLDER_SET_ID
	assert_array(validator.call(record)).is_empty()


# --- optional animations: rule 10's fallback, exactly one warning -------------

func _resolve_counting(s: SpriteSetData, id: StringName, facing: StringName,
		move_name: String = "") -> Array:
	var warnings: Array[String] = []
	var r := s.resolve(id, facing, move_name, func(m: String) -> void: warnings.append(m))
	return [r, warnings]


func test_missing_status_falls_back_to_hit_with_one_warning() -> void:
	var s := _complete_set(&"sprite_set_opt", false)
	var out := _resolve_counting(s, &"status", &"front")
	var r: SpriteSetData.Resolution = out[0]
	var warnings: Array[String] = out[1]
	assert_bool(r.fell_back).is_true()
	assert_bool(r.placeholder).is_false()
	assert_str(String(r.animation.animation_id)).is_equal("hit")
	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains("sprite_set_opt")
	assert_str(warnings[0]).contains("status")


func test_missing_move_falls_back_to_attack_with_one_warning() -> void:
	var out := _resolve_counting(_complete_set(&"sprite_set_opt", false), &"move", &"back", "Baguette Bat")
	var r: SpriteSetData.Resolution = out[0]
	assert_str(String(r.animation.animation_id)).is_equal("attack")
	assert_int((out[1] as Array).size()).is_equal(1)
	assert_str((out[1] as Array)[0]).contains("Baguette Bat")


func test_missing_heal_holds_current_pose_with_one_warning() -> void:
	var out := _resolve_counting(_complete_set(&"sprite_set_opt", false), &"heal", &"front")
	var r: SpriteSetData.Resolution = out[0]
	assert_bool(r.hold_current).is_true()
	assert_object(r.animation).is_null()
	assert_int((out[1] as Array).size()).is_equal(1)


func test_missing_optional_animations_are_not_boot_errors() -> void:
	# The complete set has no status/heal/move art at all.
	assert_array(Array(_required_errors(_complete_set(&"sprite_set_opt", true)))).is_empty()


func test_authored_and_mirrored_hits_never_warn() -> void:
	var s := _without(_complete_set(&"sprite_set_hit", false), &"hit", &"back")
	var direct := _resolve_counting(s, &"hit", &"front")
	var mirrored := _resolve_counting(s, &"hit", &"back")
	assert_int((direct[1] as Array).size()).is_equal(0)
	assert_int((mirrored[1] as Array).size()).is_equal(0)
	assert_bool((mirrored[0] as SpriteSetData.Resolution).mirrored).is_true()


# --- debug path: validation skipped -------------------------------------------

func test_skipped_validation_no_mirror_shows_placeholder_never_mirrored() -> void:
	# A set that would fail Boot: `hit` only in back, marked no_mirror.
	var s := _without(_complete_set(&"sprite_set_debug", false), &"hit", &"front")
	s.find(&"hit", &"back").no_mirror = true
	var out := _resolve_counting(s, &"hit", &"front")
	var r: SpriteSetData.Resolution = out[0]
	assert_bool(r.placeholder).is_true()
	assert_bool(r.mirrored).is_false()
	assert_object(r.animation).is_null()
	assert_int((out[1] as Array).size()).is_equal(1)
