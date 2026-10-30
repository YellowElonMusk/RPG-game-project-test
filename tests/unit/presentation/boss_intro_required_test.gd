## Story 062, AC-57 (ADR-0005 §9): a boss's sprite set with no `front`
## `intro` is a boot content error naming the set. The check runs through
## the `enemy` record validator `ContentBootstrap.run()` registers, on the
## `is_boss` enemy an encounter names as its boss, so every encounter that
## references that boss reports the same set.
extends GdUnitTestSuite

const BOSS_SET := &"sprite_set_supervisor"


func _anim(id: StringName, facing: StringName) -> SpriteAnimationData:
	var anim := SpriteAnimationData.new()
	anim.animation_id = id
	anim.facing = facing
	anim.fps = 10.0
	anim.frame_durations = PackedFloat32Array([1, 1, 1, 1])
	if anim.is_action():
		anim.impact_frame = 2
	if id == &"knockout":
		anim.land_frame = 3
	return anim


## An enemy set complete in `front`, with an `intro` in `intro_facing`
## (none when `&""`).
func _boss_set(intro_facing: StringName) -> SpriteSetData:
	var s := SpriteSetData.new()
	s.set_id = BOSS_SET
	s.facings_used = [&"front"]
	for id: StringName in SpriteSetData.REQUIRED_BATTLE:
		s.animations.append(_anim(id, &"front"))
	if intro_facing != &"":
		s.animations.append(_anim(SpriteSetData.INTRO, intro_facing))
	return s


func _enemy(is_boss: bool) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.is_boss = is_boss
	enemy.sprite_set_id = String(BOSS_SET)
	return enemy


func _errors_for(s: SpriteSetData, is_boss: bool) -> Array:
	var sets: Dictionary[StringName, SpriteSetData] = {BOSS_SET: s}
	var validator := PresentationValidators.make_record_validator(sets, PresentationConfig.new())
	return validator.call(_enemy(is_boss))


func test_boss_with_front_intro_passes() -> void:
	assert_array(_errors_for(_boss_set(&"front"), true)).is_empty()


func test_boss_without_intro_is_content_error_naming_set() -> void:
	var errors := _errors_for(_boss_set(&""), true)
	assert_int(errors.size()).is_equal(1)
	if errors.size() != 1:
		return
	assert_str(String(errors[0]["severity"])).is_equal("error")
	assert_str(errors[0]["field"]).is_equal("sprite_set_id")
	assert_str(errors[0]["message"]).contains(String(BOSS_SET))
	assert_str(errors[0]["message"]).contains("intro (front)")


func test_boss_with_back_intro_only_is_content_error() -> void:
	# A mirrored back intro is not an authored front one.
	assert_int(_errors_for(_boss_set(&"back"), true).size()).is_equal(1)


func test_non_boss_without_intro_passes() -> void:
	assert_array(_errors_for(_boss_set(&""), false)).is_empty()


func test_every_referencing_record_reports_the_same_set() -> void:
	var a := _errors_for(_boss_set(&""), true)
	var b := _errors_for(_boss_set(&""), true)
	assert_str(a[0]["message"]).is_equal(b[0]["message"])
