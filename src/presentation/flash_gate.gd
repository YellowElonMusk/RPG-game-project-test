## The one gate every large-area luminance source goes through (ADR-0005
## §12; GDD rule 13 and Formulas `flash_gate`; story 029). Transitions are
## booked at the real time they **land**, never at request time: a source
## declares each transition (its `FlashSourceDecl`) as an offset `o` on its
## own clock, and lands it at `t_land = now + (o - c_now) / rate`,
## integrated over any known rate schedule. A booked transition is a flash
## when it opposes the booked transition before it; no closed one-second
## window may hold more than `flash_rate_max` flashes. The real clock is
## injected (integer microseconds), so the Menu never resets the window.
##
## Usage example:
## [codeblock]
## var gate := FlashGate.new()
## gate.setup(Time.get_ticks_usec, config, decls, settings)
## var handle := gate.request(&"vfx_faction_stamp", replay.clock_seconds, replay.rate)
## if handle == FlashGate.REFUSED:
##     play_capped_variant()
## [/codeblock]
class_name FlashGate
extends Node

## Returned by `request()` and `begin_exempt()` when refused.
const REFUSED: int = -1
## The counting window, in microseconds.
const WINDOW_US: int = 1_000_000
## Landed transitions older than this are forgotten.
const HISTORY_US: int = 2 * WINDOW_US
## A general transition's darker state must be below this (WCAG).
const GENERAL_DARKER_MAX: float = 0.80
## A pixel is saturated red when `R / (R + G + B)` (linear) is at least this.
const RED_SATURATION_MIN: float = 0.8


## One declared transition of a booking.
class Transition extends RefCounted:
	## Offset on the source's own clock, seconds.
	var offset: float = 0.0
	## True for ↑, false for ↓.
	var rising: bool = true
	## Booked landing time (real, µs); meaningless while `frozen`.
	var land_us: int = 0
	## True while the source's clock is frozen (rate 0): held unbooked.
	var frozen: bool = false
	## While frozen: the source-clock seconds left until it lands.
	var remain: float = 0.0
	## Booking order, the tie-break for equal landing times.
	var seq: int = 0


## One request's bookings.
class Booking extends RefCounted:
	var source_id: StringName = &""
	var clock: Callable
	var reserved: bool = false
	## True once the source must finish in its capped variant.
	var capped: bool = false
	## In offset order.
	var transitions: Array[Transition] = []


var _real_clock: Callable
var _config: PresentationConfig
var _decls: Dictionary[StringName, FlashSourceDecl] = {}
var _settings: FlashSettings
var _bookings: Dictionary[int, Booking] = {}
var _exempt: Dictionary[int, float] = {}
var _next_handle: int = 1
var _next_seq: int = 0


## Injects the real clock (`() -> int` microseconds), the config (for
## `flash_rate_max` and `flash_area_min`), every source declaration keyed by
## `source_id`, and the Reduce Flashing setting.
func setup(real_clock: Callable, config: PresentationConfig,
		decls: Dictionary[StringName, FlashSourceDecl], settings: FlashSettings) -> void:
	_real_clock = real_clock
	_config = config
	_decls = decls
	_settings = settings


## Books gated source `source_id`'s transitions iff no closed one-second
## window would then hold more than `flash_rate_max` flashes (a window the
## request leaves no worse is not held against it). `clock` returns the
## source's clock reading in seconds; `rate` is its current rate against
## real time; `schedule` lists known future rate changes as
## `Vector2(clock_reading, new_rate)`. Returns a handle, or `REFUSED`: the
## caller plays the capped variant, and nothing is booked. With Reduce
## Flashing On every request is refused.
func request(source_id: StringName, clock: Callable, rate: float,
		schedule: Array[Vector2] = []) -> int:
	var decl: FlashSourceDecl = _decls.get(source_id)
	if decl == null:
		push_error("FlashGate.request(%s): no FlashSourceDecl; refused." % source_id)
		return REFUSED
	if _settings != null and _settings.reduce_flashing():
		return REFUSED
	var now: int = _now()
	_prune(now)
	var booking := _make_booking(decl, clock, rate, schedule, false, now)
	if not _allowed(booking.transitions, []):
		return REFUSED
	return _store(booking)


## Books reserved source `source_id` (the boss flood) unconditionally; the
## sources around it yield. Returns its handle.
func book_reserved(source_id: StringName, clock: Callable, rate: float,
		schedule: Array[Vector2] = []) -> int:
	var decl: FlashSourceDecl = _decls.get(source_id)
	if decl == null:
		push_error("FlashGate.book_reserved(%s): no FlashSourceDecl." % source_id)
		return REFUSED
	var now: int = _now()
	_prune(now)
	return _store(_make_booking(decl, clock, rate, schedule, true, now))


## Re-books `handle`'s unlanded transitions at `rate` (0: frozen by the
## Menu, held unbooked but counted as pending at their resume-time landing).
## Returns false when the re-booking would exceed the limit: the source's
## not-yet-started transitions are dropped and it finishes capped; its
## closing transitions (ending a landed opposite transition of the same
## handle) always stay booked. A reserved handle always succeeds.
func set_rate(handle: int, rate: float, schedule: Array[Vector2] = []) -> bool:
	var booking: Booking = _bookings.get(handle)
	if booking == null:
		return false
	var now: int = _now()
	_prune(now)
	var c_now: float = booking.clock.call()
	var landed: Array[Transition] = []
	var unlanded: Array[Transition] = []
	for t: Transition in booking.transitions:
		if _is_landed(t, now):
			landed.append(t)
		else:
			unlanded.append(t)
	var closing: Array[Transition] = []
	for i: int in booking.transitions.size():
		var t: Transition = booking.transitions[i]
		if i > 0 and unlanded.has(t) and landed.has(booking.transitions[i - 1]) \
				and booking.transitions[i - 1].rising != t.rising:
			closing.append(t)
	for t: Transition in unlanded:
		_place(t, now, c_now, rate, schedule)
	if booking.reserved or rate <= 0.0 or _allowed(unlanded, unlanded):
		return true
	var kept: Array[Transition] = landed.duplicate()
	kept.append_array(closing)
	booking.transitions = kept
	booking.capped = true
	return false


## Removes `handle`'s unlanded transitions (a discarded source). Landed
## ones stay in the window's history.
func cancel(handle: int) -> void:
	var booking: Booking = _bookings.get(handle)
	if booking == null:
		return
	var now: int = _now()
	var kept: Array[Transition] = []
	for t: Transition in booking.transitions:
		if _is_landed(t, now):
			kept.append(t)
	booking.transitions = kept


## Starts area-exempt source `source_id`: exempt only while the summed
## declared area of every playing exempt effect stays below
## `flash_area_min`. Returns a handle, or `REFUSED`: the caller requests the
## gate as a gated source instead.
func begin_exempt(source_id: StringName) -> int:
	var decl: FlashSourceDecl = _decls.get(source_id)
	if decl == null:
		return REFUSED
	var total: float = decl.max_area
	for area: float in _exempt.values():
		total += area
	if total >= _config.flash_area_min - PresentationConfig.RULE_EPSILON:
		return REFUSED
	var handle: int = _next_handle
	_next_handle += 1
	_exempt[handle] = decl.max_area
	return handle


## Ends an exempt effect started by `begin_exempt()`.
func end_exempt(handle: int) -> void:
	_exempt.erase(handle)


## True once `handle` must finish in its capped variant (a failed `set_rate`).
func is_capped(handle: int) -> bool:
	var booking: Booking = _bookings.get(handle)
	return booking != null and booking.capped


## Every booked flash's landing time (µs), ascending; frozen transitions at
## their pending resume-time landing.
func booked_flash_times() -> PackedInt64Array:
	return PackedInt64Array(_flash_times(_all_transitions([])))


## The most booked flashes in any closed one-second window.
func max_flashes_in_any_window() -> int:
	var flashes: Array[int] = _flash_times(_all_transitions([]))
	var best: int = 0
	for w: int in flashes:
		best = maxi(best, _count(flashes, w))
	return best


## Number of booked (unlanded or landed, unpruned) transitions of `handle`.
func transition_count(handle: int) -> int:
	var booking: Booking = _bookings.get(handle)
	return 0 if booking == null else booking.transitions.size()


# --- WCAG definitions (GDD `flash_gate`), on linear R, G, B -----------------

## Relative luminance of a linear color (WCAG 2.2).
static func relative_luminance(linear: Color) -> float:
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


## A general transition: a change of at least `delta` in relative luminance
## whose darker state is below 0.80.
static func is_general_transition(luma_a: float, luma_b: float, delta: float = 0.10) -> bool:
	return absf(luma_a - luma_b) >= delta - PresentationConfig.RULE_EPSILON \
			and minf(luma_a, luma_b) < GENERAL_DARKER_MAX


## True when a linear color is saturated red: `R / (R + G + B) >= 0.8`.
static func is_saturated_red(linear: Color) -> bool:
	var total: float = linear.r + linear.g + linear.b
	return total > 0.0 and linear.r / total >= RED_SATURATION_MIN


## `(R - G - B) * 320`, negative values clamped to 0 (linear values).
static func red_value(linear: Color) -> float:
	return maxf(0.0, (linear.r - linear.g - linear.b) * 320.0)


## A red transition: either state saturated red and `red_value` changing by
## more than `FlashSourceDecl.RED_CHANGE_MAX`. Takes **linear** colors.
static func is_red_transition(linear_a: Color, linear_b: Color) -> bool:
	return (is_saturated_red(linear_a) or is_saturated_red(linear_b)) \
			and absf(red_value(linear_a) - red_value(linear_b)) > FlashSourceDecl.RED_CHANGE_MAX


## True when a change over `area` (share of a 10° window) counts.
static func counts_by_area(area: float, area_min: float = 0.25) -> bool:
	return area >= area_min - PresentationConfig.RULE_EPSILON


## Real seconds for a source clock to advance from `c_now` to `offset` at
## `rate`, then at each `schedule` change (`Vector2(clock_reading, rate)`).
## -1.0 when the clock is (or becomes) frozen first.
static func seconds_until(offset: float, c_now: float, rate: float, schedule: Array[Vector2]) -> float:
	if offset <= c_now:
		return 0.0
	var changes: Array[Vector2] = schedule.duplicate()
	changes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var seconds: float = 0.0
	var c: float = c_now
	var r: float = rate
	for change: Vector2 in changes:
		if change.x <= c:
			continue  # Already in effect: `rate` is the current rate.
		if offset <= change.x:
			break
		if r <= 0.0:
			return -1.0
		seconds += (change.x - c) / r
		c = change.x
		r = change.y
	if r <= 0.0:
		return -1.0
	return seconds + (offset - c) / r


# --- internals ---------------------------------------------------------------

func _now() -> int:
	return int(_real_clock.call())


func _make_booking(decl: FlashSourceDecl, clock: Callable, rate: float,
		schedule: Array[Vector2], reserved: bool, now: int) -> Booking:
	var booking := Booking.new()
	booking.source_id = decl.source_id
	booking.clock = clock
	booking.reserved = reserved
	var c_now: float = clock.call()
	for declared: FlashTransition in decl.transitions:
		var t := Transition.new()
		t.offset = declared.offset
		t.rising = declared.rising
		t.seq = _next_seq
		_next_seq += 1
		_place(t, now, c_now, rate, schedule)
		booking.transitions.append(t)
	return booking


func _place(t: Transition, now: int, c_now: float, rate: float, schedule: Array[Vector2]) -> void:
	var seconds: float = seconds_until(t.offset, c_now, rate, schedule)
	t.frozen = seconds < 0.0
	if t.frozen:
		t.remain = maxf(0.0, t.offset - c_now)
	else:
		t.land_us = now + int(round(seconds * 1_000_000.0))


func _store(booking: Booking) -> int:
	var handle: int = _next_handle
	_next_handle += 1
	_bookings[handle] = booking
	return handle


## A frozen transition counts as pending at its landing were it resumed now
## at 1x (the resume-time landing for a request evaluated during the freeze).
func _land_of(t: Transition, now: int) -> int:
	return now + int(round(t.remain * 1_000_000.0)) if t.frozen else t.land_us


func _is_landed(t: Transition, now: int) -> bool:
	return not t.frozen and t.land_us <= now


func _all_transitions(excluded: Array[Transition]) -> Array[Transition]:
	var out: Array[Transition] = []
	for booking: Booking in _bookings.values():
		for t: Transition in booking.transitions:
			if not excluded.has(t):
				out.append(t)
	return out


## Flash landing times: each transition, in landing order, that opposes the
## one before it.
func _flash_times(transitions: Array[Transition]) -> Array[int]:
	var now: int = _now()
	var ordered: Array[Transition] = transitions.duplicate()
	ordered.sort_custom(func(a: Transition, b: Transition) -> bool:
		var la: int = _land_of(a, now)
		var lb: int = _land_of(b, now)
		return la < lb or (la == lb and a.seq < b.seq))
	var flashes: Array[int] = []
	for i: int in range(1, ordered.size()):
		if ordered[i].rising != ordered[i - 1].rising:
			flashes.append(_land_of(ordered[i], now))
	return flashes


func _count(flashes: Array[int], window_start: int) -> int:
	var n: int = 0
	for f: int in flashes:
		if f >= window_start and f <= window_start + WINDOW_US:
			n += 1
	return n


## True when booking `candidate` (in place of `excluded`) leaves every
## closed one-second window within `flash_rate_max`, or no worse than it was.
func _allowed(candidate: Array[Transition], excluded: Array[Transition]) -> bool:
	var base: Array[Transition] = _all_transitions(excluded)
	var with_candidate: Array[Transition] = base.duplicate()
	with_candidate.append_array(candidate)
	var f_with: Array[int] = _flash_times(with_candidate)
	var f_without: Array[int] = _flash_times(base)
	for w: int in f_with:
		var n: int = _count(f_with, w)
		if n > _config.flash_rate_max + PresentationConfig.RULE_EPSILON and n > _count(f_without, w):
			return false
	return true


## Forgets bookings whose every transition landed more than `HISTORY_US`
## ago. A booking with anything unlanded keeps its whole history, so a
## closing transition still finds its landed partner after a long freeze.
func _prune(now: int) -> void:
	for handle: int in _bookings.keys():
		var stale := true
		for t: Transition in _bookings[handle].transitions:
			if t.frozen or t.land_us >= now - HISTORY_US:
				stale = false
				break
		if stale:
			_bookings.erase(handle)
