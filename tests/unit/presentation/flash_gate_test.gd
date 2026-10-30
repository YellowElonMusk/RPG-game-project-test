## Story 029, AC-25 (TR-presentation-015; ADR-0005 §12): `FlashGate` books
## every transition at the real time it lands. The real clock is injected in
## integer microseconds; each source's clock is a fixture reading in seconds.
## Fixture declarations are built per test; the WCAG definitions are checked
## on fixture frame pairs.
extends GdUnitTestSuite

## Real time, µs (an Array so lambdas share it).
var _real: Array[int] = [0]
var _config: PresentationConfig
var _settings: FlashSettings
var _gate: FlashGate


func before_test() -> void:
	_real[0] = 0
	_config = PresentationConfig.new()
	_settings = FlashSettings.new()
	_gate = auto_free(FlashGate.new())


func _t(offset: float, rising: bool) -> FlashTransition:
	var t := FlashTransition.new()
	t.offset = offset
	t.rising = rising
	return t


func _decl(id: StringName, flash_class: StringName, transitions: Array[FlashTransition],
		max_area: float = 0.0) -> FlashSourceDecl:
	var d := FlashSourceDecl.new()
	d.source_id = id
	d.flash_class = flash_class
	d.clock = FlashSourceDecl.CLOCK_REPLAY
	d.transitions = transitions
	d.max_area = max_area
	return d


## The GDD example stamp: ↑ +0.05 s, ↓ +0.15 s.
func _stamp() -> FlashSourceDecl:
	return _decl(&"stamp", FlashSourceDecl.CLASS_GATED, [_t(0.05, true), _t(0.15, false)])


func _setup(decls: Array[FlashSourceDecl]) -> void:
	var by_id: Dictionary[StringName, FlashSourceDecl] = {}
	for d: FlashSourceDecl in decls:
		by_id[d.source_id] = d
	_gate.setup(func() -> int: return _real[0], _config, by_id, _settings)


## A source clock reading `holder[0]` seconds.
func _clock(holder: Array[float]) -> Callable:
	return func() -> float: return holder[0]


func _at(seconds: float) -> void:
	_real[0] = int(round(seconds * 1_000_000.0))


func _request_fresh(id: StringName, real_seconds: float) -> int:
	_at(real_seconds)
	var c: Array[float] = [0.0]
	return _gate.request(id, _clock(c), 1.0)


# --- landing, not request ----------------------------------------------------

func test_third_stamp_refused_by_landing_time() -> void:
	_setup([_stamp()])
	assert_int(_request_fresh(&"stamp", 0.0)).is_not_equal(FlashGate.REFUSED)
	assert_int(_request_fresh(&"stamp", 0.2)).is_not_equal(FlashGate.REFUSED)
	assert_int(_request_fresh(&"stamp", 0.4)).is_equal(FlashGate.REFUSED)
	assert_array(Array(_gate.booked_flash_times())).is_equal([150000, 250000, 350000])


func test_limit_five_allows_all_three_stamps() -> void:
	_config.flash_rate_max = 5.0  # Directly into the gate, not via the load rule.
	_setup([_stamp()])
	for s: float in [0.0, 0.2, 0.4]:
		assert_int(_request_fresh(&"stamp", s)).is_not_equal(FlashGate.REFUSED)


# --- counting ----------------------------------------------------------------

func test_stamp_every_100ms_never_exceeds_limit() -> void:
	_setup([_stamp()])
	for i: int in 100:
		_request_fresh(&"stamp", i * 0.1)
		assert_int(_gate.max_flashes_in_any_window()).is_less_equal(int(_config.flash_rate_max))


func test_n_alternating_transitions_count_n_minus_one() -> void:
	var seq: Array[FlashTransition] = [_t(0.0, true), _t(0.5, false), _t(1.0, true), _t(1.5, false), _t(2.0, true)]
	_setup([_decl(&"seq", FlashSourceDecl.CLASS_RESERVED, seq)])
	var c: Array[float] = [0.0]
	_gate.book_reserved(&"seq", _clock(c), 1.0)
	assert_int(_gate.booked_flash_times().size()).is_equal(4)


# --- refusal -----------------------------------------------------------------

func test_refused_request_books_nothing() -> void:
	_setup([_stamp()])
	_request_fresh(&"stamp", 0.0)
	_request_fresh(&"stamp", 0.2)
	var before := _gate.booked_flash_times()
	assert_int(_request_fresh(&"stamp", 0.4)).is_equal(FlashGate.REFUSED)
	assert_array(Array(_gate.booked_flash_times())).is_equal(Array(before))


func test_reduce_flashing_refuses_every_gated_request() -> void:
	_settings.reduce_flashing_on = true
	_setup([_stamp()])
	assert_int(_request_fresh(&"stamp", 0.0)).is_equal(FlashGate.REFUSED)
	assert_int(_gate.booked_flash_times().size()).is_equal(0)


# --- reserved ----------------------------------------------------------------

func test_reserved_books_when_gated_would_be_refused_and_gated_then_yields() -> void:
	var flood := _decl(&"flood", FlashSourceDecl.CLASS_RESERVED, [_t(0.05, true)])
	_setup([_stamp(), flood])
	_request_fresh(&"stamp", 0.0)
	_request_fresh(&"stamp", 0.2)
	_at(0.4)
	var c: Array[float] = [0.0]
	assert_int(_gate.request(&"stamp", _clock(c), 1.0)).is_equal(FlashGate.REFUSED)
	assert_int(_gate.book_reserved(&"flood", _clock(c), 1.0)).is_not_equal(FlashGate.REFUSED)
	assert_bool(Array(_gate.booked_flash_times()).has(450000)).is_true()
	assert_int(_request_fresh(&"stamp", 0.5)).is_equal(FlashGate.REFUSED)


func test_reserved_sequence_over_limit_fails_boot_validation() -> void:
	var too_many: Array[FlashTransition] = [
		_t(0.0, true), _t(0.1, false), _t(0.2, true), _t(0.3, false), _t(0.4, true)]
	var d := _decl(&"flood", FlashSourceDecl.CLASS_RESERVED, too_many)
	d.clock = FlashSourceDecl.CLOCK_MODE
	var errors := PresentationValidators.validate_flash_source(d, _config)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).starts_with(PresentationValidators.RULE_FLASH_RESERVED)


# --- menu ----------------------------------------------------------------------

func _menu(id: StringName) -> FlashSourceDecl:
	return _decl(id, FlashSourceDecl.CLASS_GATED, [_t(0.0, true), _t(0.05, false)])


func test_menu_open_close_does_not_reset_window() -> void:
	_setup([_stamp(), _menu(&"menu_open"), _menu(&"menu_close")])
	_request_fresh(&"stamp", 0.0)
	_request_fresh(&"stamp", 0.2)
	assert_int(_gate.max_flashes_in_any_window()).is_equal(3)
	# The Menu's own transitions are gated too, refused here: capped, nothing booked.
	assert_int(_request_fresh(&"menu_open", 0.4)).is_equal(FlashGate.REFUSED)
	assert_int(_request_fresh(&"menu_close", 0.5)).is_equal(FlashGate.REFUSED)
	assert_int(_request_fresh(&"stamp", 0.6)).is_equal(FlashGate.REFUSED)
	assert_int(_gate.booked_flash_times().size()).is_equal(3)


# --- frozen source -------------------------------------------------------------

func test_frozen_stamp_counts_pending_and_its_close_always_lands() -> void:
	var r := _decl(&"reserved_burst", FlashSourceDecl.CLASS_RESERVED,
			[_t(0.0, false), _t(0.1, true), _t(0.2, false)])
	_setup([_stamp(), _menu(&"menu_open"), _menu(&"menu_close"), r])
	var stamp_clock: Array[float] = [0.0]
	var stamp: int = _gate.request(&"stamp", _clock(stamp_clock), 1.0)
	assert_int(stamp).is_not_equal(FlashGate.REFUSED)
	# The Menu freezes the stamp between its ↑ (landed at 0.05) and its ↓.
	_at(0.1)
	stamp_clock[0] = 0.1
	assert_bool(_gate.set_rate(stamp, 0.0)).is_true()
	_request_fresh(&"menu_open", 0.1)
	# Three flashes land near 3.0 s; the frozen ↓ is pending at 3.05 s.
	_at(2.5)
	var r_clock: Array[float] = [0.0]
	_gate.book_reserved(&"reserved_burst", _clock(r_clock), 1.0)
	# The Menu's close is judged with the pending ↓ in: refused, capped.
	assert_int(_request_fresh(&"menu_close", 3.0)).is_equal(FlashGate.REFUSED)
	# On resume the ↓ re-books with reserved priority and lands.
	_gate.set_rate(stamp, 1.0)
	assert_int(_gate.transition_count(stamp)).is_equal(2)
	assert_bool(_gate.is_capped(stamp)).is_false()
	assert_int(_gate.max_flashes_in_any_window()).is_less_equal(int(_config.flash_rate_max))


# --- clock rate ----------------------------------------------------------------

func _two_flash() -> FlashSourceDecl:
	return _decl(&"two_flash", FlashSourceDecl.CLASS_GATED,
			[_t(0.0, true), _t(0.5, false), _t(1.0, true), _t(1.5, false)])


func test_latch_rebooks_compressed_landings() -> void:
	_setup([_two_flash()])
	var c: Array[float] = [0.0]
	_at(0.2)
	var h: int = _gate.request(&"two_flash", _clock(c), 1.0)
	_at(0.3)
	c[0] = 0.1
	assert_bool(_gate.set_rate(h, 2.0)).is_true()
	assert_array(Array(_gate.booked_flash_times())).is_equal([500000, 750000, 1000000])


func test_latch_over_limit_keeps_closing_drops_the_rest() -> void:
	var x := _decl(&"x", FlashSourceDecl.CLASS_GATED, [_t(0.0, false), _t(0.1, true)])
	_setup([x, _two_flash()])
	_request_fresh(&"x", 0.0)
	var c: Array[float] = [0.0]
	_at(0.2)
	var h: int = _gate.request(&"two_flash", _clock(c), 1.0)
	assert_int(h).is_not_equal(FlashGate.REFUSED)
	_at(0.3)
	c[0] = 0.1
	assert_bool(_gate.set_rate(h, 2.0)).is_false()
	assert_bool(_gate.is_capped(h)).is_true()
	assert_int(_gate.transition_count(h)).is_equal(2)
	assert_array(Array(_gate.booked_flash_times())).is_equal([100000, 500000])


func test_scheduled_rate_change_lands_within_one_frame() -> void:
	var d := _decl(&"windup", FlashSourceDecl.CLASS_GATED, [_t(0.0, false), _t(0.5, true)])
	_setup([d])
	var schedule: Array[Vector2] = [Vector2(0.3, 1.0)]
	var c: Array[float] = [0.0]
	_gate.request(&"windup", _clock(c), 2.0, schedule)
	var predicted: int = _gate.booked_flash_times()[0]
	assert_int(predicted).is_equal(350000)
	# Simulate frames: wind-up at 2x until clock 0.3, then the hold at 1x.
	var dt: float = 1.0 / 60.0
	var real: float = 0.0
	var clock: float = 0.0
	while clock < 0.5:
		clock += dt * (2.0 if clock < 0.3 else 1.0)
		real += dt
	assert_float(absf(real - predicted / 1_000_000.0)).is_less_equal(dt)


# --- capped means capped -------------------------------------------------------

func test_saturated_red_capped_variant_fails_boot_validation() -> void:
	var d := _stamp()
	d.capped_luma_swing = 0.02
	d.capped_red_change = 200.0
	var errors := PresentationValidators.validate_flash_source(d, _config)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).starts_with(PresentationValidators.RULE_FLASH_CAPPED)


# --- aggregation ---------------------------------------------------------------

func test_exempt_sparks_aggregate_to_the_gate() -> void:
	var spark := _decl(&"spark", FlashSourceDecl.CLASS_EXEMPT_AREA, [], 0.10)
	var tiny := _decl(&"tiny", FlashSourceDecl.CLASS_EXEMPT_AREA, [], 0.04)
	_setup([spark, tiny])
	assert_int(_gate.begin_exempt(&"spark")).is_not_equal(FlashGate.REFUSED)
	assert_int(_gate.begin_exempt(&"spark")).is_not_equal(FlashGate.REFUSED)
	assert_int(_gate.begin_exempt(&"spark")).is_equal(FlashGate.REFUSED)
	assert_int(_gate.begin_exempt(&"tiny")).is_not_equal(FlashGate.REFUSED)


func test_end_exempt_frees_area() -> void:
	var spark := _decl(&"spark", FlashSourceDecl.CLASS_EXEMPT_AREA, [], 0.10)
	_setup([spark])
	var a: int = _gate.begin_exempt(&"spark")
	_gate.begin_exempt(&"spark")
	_gate.end_exempt(a)
	assert_int(_gate.begin_exempt(&"spark")).is_not_equal(FlashGate.REFUSED)


# --- definitions -----------------------------------------------------------------

func test_general_transition_definition() -> void:
	assert_bool(FlashGate.is_general_transition(0.78, 0.89)).is_true()
	assert_bool(FlashGate.is_general_transition(0.78, 0.87)).is_false()
	assert_bool(FlashGate.is_general_transition(0.82, 0.93)).is_false()


func test_red_transition_uses_linear_values() -> void:
	var gamma := Color(0.9, 0.2, 0.2)
	var black := Color(0.0, 0.0, 0.0)
	# The encodings disagree: not a red transition on gamma values...
	assert_bool(FlashGate.is_red_transition(gamma, black)).is_false()
	# ...but one on linear values, which is what counts.
	assert_bool(FlashGate.is_red_transition(gamma.srgb_to_linear(), black)).is_true()


func test_area_definition() -> void:
	assert_bool(FlashGate.counts_by_area(0.26)).is_true()
	assert_bool(FlashGate.counts_by_area(0.24)).is_false()
