## Story 059, AC-55 (TR-presentation-015; ADR-0005 §9, §12): every
## flash-capable source in the shipped data is declared gated, reserved,
## exempt-by-area or exempt-by-swing, with its transitions on a named clock.
## A source declared exempt whose data exceeds its exemption fails boot
## validation; a gated source's capped variant has no general and no red
## transition, or covers less than `flash_area_min`; the dusk starfield is
## area-exempt below `flash_area_min`. Fixtures are factory functions; the
## shipped set is loaded from `data/presentation/flash_sources/`.
extends GdUnitTestSuite

const CONFIG_DEFAULTS := preload("res://src/presentation/presentation_config.gd")


func _config() -> PresentationConfig:
	return CONFIG_DEFAULTS.new()


func _t(offset: float, rising: bool, area: float = 1.0, red: bool = false) -> FlashTransition:
	var t := FlashTransition.new()
	t.offset = offset
	t.rising = rising
	t.area = area
	t.red = red
	return t


## A valid gated source: one ↑↓ pair over the whole window, capped to a swell.
func _gated(id: StringName = &"fixture_gated") -> FlashSourceDecl:
	var d := FlashSourceDecl.new()
	d.source_id = id
	d.flash_class = FlashSourceDecl.CLASS_GATED
	d.clock = FlashSourceDecl.CLOCK_REPLAY
	d.transitions = [_t(0.0, true), _t(0.1, false)]
	d.capped_luma_swing = 0.05
	d.capped_red_change = 0.0
	d.capped_area = 1.0
	return d


func _errors_for(d: FlashSourceDecl) -> PackedStringArray:
	return PresentationValidators.validate_flash_source(d, _config())


func _assert_one(d: FlashSourceDecl, rule: String) -> void:
	var errors := _errors_for(d)
	assert_int(errors.size()).override_failure_message("%s" % [errors]).is_equal(1)
	if errors.size() != 1:
		return
	assert_str(errors[0]).starts_with(rule)
	assert_str(errors[0]).contains(String(d.source_id))


# --- shipped data -----------------------------------------------------------

func test_shipped_declarations_pass_and_cover_every_listed_source() -> void:
	var decls := PresentationValidators.load_flash_sources()
	var errors := PresentationValidators.validate_flash_sources(decls, _config())
	assert_array(Array(errors)).override_failure_message("%s" % [errors]).is_empty()
	var ids: Array[StringName] = []
	for d: FlashSourceDecl in decls:
		ids.append(d.source_id)
	for id: StringName in PresentationValidators.REQUIRED_FLASH_SOURCES:
		assert_bool(ids.has(id)).override_failure_message("no declaration for %s" % id).is_true()


func test_required_list_names_game_state_flash_sources() -> void:
	for id: StringName in [GameStateMachine.FLASH_SOURCE_RETRY, GameStateMachine.FLASH_SOURCE_BATTLE_WIPE,
			GameStateMachine.FLASH_SOURCE_BATTLE_WIPE_REVERSE]:
		assert_bool(PresentationValidators.REQUIRED_FLASH_SOURCES.has(id)).is_true()


func test_shipped_sources_each_have_a_legal_class_and_named_clock() -> void:
	for d: FlashSourceDecl in PresentationValidators.load_flash_sources():
		assert_bool(FlashSourceDecl.CLASSES.has(d.flash_class)).is_true()
		assert_bool(FlashSourceDecl.CLOCKS.has(d.clock)).override_failure_message(
				"%s clock '%s'" % [d.source_id, d.clock]).is_true()


func test_shipped_dusk_starfield_is_area_exempt_below_area_min() -> void:
	var starfield: FlashSourceDecl = null
	for d: FlashSourceDecl in PresentationValidators.load_flash_sources():
		if d.source_id == &"dusk_starfield":
			starfield = d
	assert_object(starfield).is_not_null()
	if starfield == null:
		return
	assert_str(String(starfield.flash_class)).is_equal(String(FlashSourceDecl.CLASS_EXEMPT_AREA))
	assert_float(starfield.max_area).is_less(_config().flash_area_min)


func test_shipped_gated_capped_variants_are_not_flashes() -> void:
	var config := _config()
	for d: FlashSourceDecl in PresentationValidators.load_flash_sources():
		if d.flash_class != FlashSourceDecl.CLASS_GATED:
			continue
		var swell: bool = d.capped_luma_swing < config.flash_luma_delta \
				and d.capped_red_change <= FlashSourceDecl.RED_CHANGE_MAX
		assert_bool(swell or d.capped_area < config.flash_area_min).override_failure_message(
				"%s capped variant still flashes" % d.source_id).is_true()


# --- coverage ---------------------------------------------------------------

func test_missing_required_source_is_an_error() -> void:
	var required: Array[StringName] = [&"fixture_gated", &"fixture_absent"]
	var errors := PresentationValidators.validate_flash_sources([_gated()], _config(), required)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).starts_with(PresentationValidators.RULE_FLASH_COVERAGE)
	assert_str(errors[0]).contains("fixture_absent")


func test_duplicate_source_is_an_error() -> void:
	var required: Array[StringName] = []
	var errors := PresentationValidators.validate_flash_sources([_gated(), _gated()], _config(), required)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("declared twice")


# --- class and clock --------------------------------------------------------

func test_valid_gated_fixture_passes() -> void:
	assert_array(Array(_errors_for(_gated()))).is_empty()


func test_unnamed_clock_is_an_error() -> void:
	var d := _gated()
	d.clock = &""
	_assert_one(d, PresentationValidators.RULE_FLASH_CLOCK)


func test_unknown_class_is_an_error() -> void:
	var d := _gated()
	d.flash_class = &"sometimes"
	_assert_one(d, PresentationValidators.RULE_FLASH_CLASS)


func test_default_class_is_gated() -> void:
	assert_str(String(FlashSourceDecl.new().flash_class)).is_equal(String(FlashSourceDecl.CLASS_GATED))


func test_out_of_order_transitions_are_an_error() -> void:
	var d := _gated()
	d.transitions = [_t(0.2, true), _t(0.1, false)]
	_assert_one(d, PresentationValidators.RULE_FLASH_TRANSITIONS)


func test_gated_without_transitions_is_an_error() -> void:
	var d := _gated()
	d.transitions = []
	_assert_one(d, PresentationValidators.RULE_FLASH_TRANSITIONS)


# --- capped variants --------------------------------------------------------

func test_capped_swing_at_luma_delta_is_still_a_flash() -> void:
	var d := _gated()
	d.capped_luma_swing = _config().flash_luma_delta
	_assert_one(d, PresentationValidators.RULE_FLASH_CAPPED)


func test_saturated_red_capped_variant_fails() -> void:
	# A luminance-only cap is not a cap.
	var d := _gated()
	d.capped_luma_swing = 0.02
	d.capped_red_change = 40.0
	_assert_one(d, PresentationValidators.RULE_FLASH_CAPPED)


func test_red_change_at_threshold_is_not_a_red_transition() -> void:
	var d := _gated()
	d.capped_red_change = FlashSourceDecl.RED_CHANGE_MAX
	assert_array(Array(_errors_for(d))).is_empty()


func test_flashing_capped_variant_below_area_min_passes() -> void:
	var d := _gated()
	d.capped_luma_swing = 0.5
	d.capped_red_change = 40.0
	d.capped_area = _config().flash_area_min - 0.01
	assert_array(Array(_errors_for(d))).is_empty()


# --- exemptions -------------------------------------------------------------

func _area_exempt(max_area: float, transition_area: float) -> FlashSourceDecl:
	var d := FlashSourceDecl.new()
	d.source_id = &"fixture_spark"
	d.flash_class = FlashSourceDecl.CLASS_EXEMPT_AREA
	d.clock = FlashSourceDecl.CLOCK_REPLAY
	d.max_area = max_area
	d.transitions = [_t(0.0, true, transition_area), _t(0.05, false, transition_area)]
	return d


func test_area_exempt_below_area_min_passes() -> void:
	assert_array(Array(_errors_for(_area_exempt(0.04, 0.04)))).is_empty()


func test_area_exempt_at_area_min_fails() -> void:
	var a: float = _config().flash_area_min
	_assert_one(_area_exempt(a, a), PresentationValidators.RULE_FLASH_EXEMPT_AREA)


func test_area_exempt_transition_wider_than_declared_fails() -> void:
	_assert_one(_area_exempt(0.04, 0.10), PresentationValidators.RULE_FLASH_EXEMPT_AREA)


func _swing_exempt(swing: float) -> FlashSourceDecl:
	var d := FlashSourceDecl.new()
	d.source_id = &"fixture_flicker"
	d.flash_class = FlashSourceDecl.CLASS_EXEMPT_SWING
	d.clock = FlashSourceDecl.CLOCK_MODE
	d.peak_luma_swing = swing
	return d


func test_swing_exempt_below_delta_passes() -> void:
	assert_array(Array(_errors_for(_swing_exempt(0.06)))).is_empty()


func test_swing_exempt_at_delta_fails() -> void:
	_assert_one(_swing_exempt(_config().flash_luma_delta), PresentationValidators.RULE_FLASH_EXEMPT_SWING)


func test_swing_exempt_with_transitions_fails() -> void:
	var d := _swing_exempt(0.06)
	d.transitions = [_t(0.0, true), _t(0.1, false)]
	_assert_one(d, PresentationValidators.RULE_FLASH_EXEMPT_SWING)


# --- reserved sequences -----------------------------------------------------

func _reserved(offsets: Array[float]) -> FlashSourceDecl:
	var d := FlashSourceDecl.new()
	d.source_id = &"fixture_flood"
	d.flash_class = FlashSourceDecl.CLASS_RESERVED
	d.clock = FlashSourceDecl.CLOCK_MODE
	var rising := true
	var ts: Array[FlashTransition] = []
	for o: float in offsets:
		ts.append(_t(o, rising))
		rising = not rising
	d.transitions = ts
	return d


func test_reserved_within_limit_at_every_speed_passes() -> void:
	# Three flashes 0.4 * ff_mult s apart: still three per second at ff_mult.
	var gap: float = 0.4 * _config().ff_mult
	assert_array(Array(_errors_for(_reserved([0.0, gap, 2.0 * gap, 3.0 * gap])))).is_empty()


func test_reserved_over_limit_only_when_sped_up_fails() -> void:
	# Four flashes 0.4 s apart span 1.2 s at 1x (at most three per second)
	# but land inside one second at battle_speed_mult and ff_mult.
	var d := _reserved([0.0, 0.4, 0.8, 1.2, 1.6])
	assert_int(PresentationValidators.max_flashes_in_window(d.transitions, 1.0)).is_equal(3)
	assert_int(PresentationValidators.max_flashes_in_window(d.transitions, _config().ff_mult)).is_equal(4)
	_assert_one(d, PresentationValidators.RULE_FLASH_RESERVED)


func test_same_direction_transitions_are_not_flashes() -> void:
	var ts: Array[FlashTransition] = [_t(0.0, true), _t(0.1, true), _t(0.2, true)]
	assert_int(PresentationValidators.max_flashes_in_window(ts, 1.0)).is_equal(0)
