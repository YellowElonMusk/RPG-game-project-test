## Story 066, AC-61 (ADR-0005 §9; ADR-0006 §1 `windup`/`ko_landing`): each
## frame-data rule ends boot in a content error naming the set and the
## animation: `impact_frame` missing or equal to the frame count on an
## `attack`/`defend`, `land_frame` likewise on a `knockout`, an `intro`
## longer than `boss_hold` at 1x, and two move animations keyed by the same
## move name. Fixtures use the AC's worked example: durations 1, 1, 2, 1 at
## 10 fps, so `impact_frame` 3 gives w_i = 0.4 s and `land_frame` 2 gives
## k_i = 0.2 s.
extends GdUnitTestSuite

const SET_ID := &"sprite_set_frames"
const DURATIONS := [1.0, 1.0, 2.0, 1.0]
const FPS := 10.0


func _anim(id: StringName, move_name: String = "") -> SpriteAnimationData:
	var anim := SpriteAnimationData.new()
	anim.animation_id = id
	anim.facing = &"front"
	anim.move_name = move_name
	anim.fps = FPS
	anim.frame_durations = PackedFloat32Array(DURATIONS)
	if anim.is_action():
		anim.impact_frame = 3
	if id == &"knockout":
		anim.land_frame = 2
	return anim


func _valid_set() -> SpriteSetData:
	var s := SpriteSetData.new()
	s.set_id = SET_ID
	s.facings_used = [&"front"]
	for id: StringName in SpriteSetData.REQUIRED_BATTLE:
		s.animations.append(_anim(id))
	return s


func _errors(s: SpriteSetData, config: PresentationConfig = PresentationConfig.new()) -> PackedStringArray:
	return PresentationValidators.validate_frame_data(s, config)


func _assert_one_error(s: SpriteSetData, rule: String, animation: String,
		config: PresentationConfig = PresentationConfig.new()) -> void:
	var errors := _errors(s, config)
	assert_int(errors.size()).override_failure_message("%s" % [errors]).is_equal(1)
	if errors.size() != 1:
		return
	assert_str(errors[0]).starts_with(rule)
	assert_str(errors[0]).contains(String(SET_ID))
	assert_str(errors[0]).contains(animation)


# --- worked example ---------------------------------------------------------

func test_worked_example_windup_and_landing() -> void:
	var attack := _anim(&"attack")
	var knockout := _anim(&"knockout")
	assert_float(attack.impact_seconds()).is_equal_approx(0.4, 0.0001)
	assert_float(knockout.land_seconds()).is_equal_approx(0.2, 0.0001)


func test_valid_set_has_no_errors() -> void:
	assert_array(Array(_errors(_valid_set()))).is_empty()


# --- impact_frame -----------------------------------------------------------

func test_attack_and_defend_without_impact_frame_error() -> void:
	for id: StringName in [&"attack", &"defend"]:
		var s := _valid_set()
		s.find(id, &"front").impact_frame = SpriteAnimationData.NO_FRAME
		_assert_one_error(s, PresentationValidators.RULE_IMPACT, String(id))


func test_impact_frame_equal_to_frame_count_errors() -> void:
	for id: StringName in [&"attack", &"defend"]:
		var s := _valid_set()
		s.find(id, &"front").impact_frame = DURATIONS.size()
		_assert_one_error(s, PresentationValidators.RULE_IMPACT, String(id))


func test_impact_frame_on_last_frame_passes() -> void:
	var s := _valid_set()
	s.find(&"attack", &"front").impact_frame = DURATIONS.size() - 1
	assert_array(Array(_errors(s))).is_empty()


# --- land_frame -------------------------------------------------------------

func test_knockout_without_land_frame_errors() -> void:
	var s := _valid_set()
	s.find(&"knockout", &"front").land_frame = SpriteAnimationData.NO_FRAME
	_assert_one_error(s, PresentationValidators.RULE_LAND, "knockout")


func test_land_frame_equal_to_frame_count_errors() -> void:
	var s := _valid_set()
	s.find(&"knockout", &"front").land_frame = DURATIONS.size()
	_assert_one_error(s, PresentationValidators.RULE_LAND, "knockout")


# --- intro vs boss_hold -----------------------------------------------------

func test_intro_longer_than_boss_hold_errors() -> void:
	var config := PresentationConfig.new()
	var s := _valid_set()
	var intro := _anim(SpriteSetData.INTRO)
	# Total ticks 5 at 10 fps = 0.5 s; set boss_hold just under it.
	intro.fps = 5.0 / (config.boss_hold + 0.01)
	s.animations.append(intro)
	_assert_one_error(s, PresentationValidators.RULE_INTRO_LENGTH, "intro", config)


func test_intro_exactly_boss_hold_passes() -> void:
	var config := PresentationConfig.new()
	var s := _valid_set()
	var intro := _anim(SpriteSetData.INTRO)
	intro.fps = 5.0 / config.boss_hold
	s.animations.append(intro)
	assert_array(Array(_errors(s, config))).is_empty()


# --- duplicate move names ---------------------------------------------------

func test_duplicate_move_name_errors() -> void:
	var s := _valid_set()
	s.animations.append(_anim(SpriteSetData.MOVE, "Baguette Bat"))
	s.animations.append(_anim(SpriteSetData.MOVE, "Baguette Bat"))
	_assert_one_error(s, PresentationValidators.RULE_DUPLICATE_MOVE, "Baguette Bat")


func test_distinct_move_names_pass() -> void:
	var s := _valid_set()
	s.animations.append(_anim(SpriteSetData.MOVE, "Baguette Bat"))
	s.animations.append(_anim(SpriteSetData.MOVE, "Appetizer"))
	assert_array(Array(_errors(s))).is_empty()


# --- reaches Boot -----------------------------------------------------------

func test_frame_data_error_reaches_the_record_validator() -> void:
	var s := _valid_set()
	s.find(&"attack", &"front").impact_frame = SpriteAnimationData.NO_FRAME
	var sets: Dictionary[StringName, SpriteSetData] = {SET_ID: s}
	var record := EnemyData.new()
	record.sprite_set_id = String(SET_ID)
	var errors: Array = PresentationValidators.make_record_validator(sets, PresentationConfig.new()).call(record)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]["message"]).starts_with(PresentationValidators.RULE_IMPACT)
