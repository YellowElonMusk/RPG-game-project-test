## The battle hit-punch (GDD `design/gdd/sprite-camera-presentation.md`,
## rule 8 and Formulas `hit_punch`; ADR-0005 §6). Owned by the Battle mode,
## never by `DioramaStage`: the mode calls `on_impact` on a beat's impact
## frame (ADR-0006 beat clock), `advance` once per frame with the unscaled
## (1x) frame time, and writes `current_offset_px` to
## `DioramaStage.set_punch_offset_px`. The punch is a camera lens shift only;
## no actor is ever moved, scaled or rotated (story 014).
##
## Stories 012 (gating), 021 (comfort settings), 024 (formula), 055 (resize).
class_name HitPunch
extends RefCounted

## The window height `A_beat` is authored at (GDD: "px at 1080p"). A formula
## constant of the `hit_punch` definition, not a tuning knob.
const REFERENCE_HEIGHT: int = 1080

## Emitted when a punch starts, with its `A_beat` (px at 1080p) and `dir`.
signal started(a_beat: float, dir: Vector2)

## Durations and amplitudes (`punch_duration`, `punch_amplitude_*`).
var config: PresentationConfig
## The comfort settings, read live each frame (AC-41); null reads as Full
## with Reduce Motion Off.
var settings: PresentationSettings
## Punches started so far (diagnostics and tests).
var started_count: int = 0
## Punch requests refused because another was still running (never expected:
## `D < reaction_hold` is validated at load, rule 8).
var refused_count: int = 0

var _running: bool = false
var _elapsed: float = 0.0
var _a_beat: float = 0.0
var _dir: Vector2 = Vector2.ZERO


func _init(p_config: PresentationConfig, p_settings: PresentationSettings = null) -> void:
	config = p_config
	settings = p_settings


## `A_full = round(A_beat * H_screen / 1080)`, round half away from zero.
static func full_amplitude(a_beat: float, h_screen: int) -> int:
	return _round_half_away(a_beat * float(h_screen) / float(REFERENCE_HEIGHT))


## `A_peak` after the comfort settings: Full -> `A_full`; Reduced ->
## `max(1, floor(A_full / 2))` when `A_full > 0`, else 0; Off or Reduce
## Motion On -> 0 (GDD `hit_punch`, AC-18).
static func peak_amplitude(a_full: int, screen_shake: PresentationSettings.ScreenShake,
		reduce_motion: bool) -> int:
	if reduce_motion or screen_shake == PresentationSettings.ScreenShake.OFF:
		return 0
	if screen_shake == PresentationSettings.ScreenShake.REDUCED:
		return maxi(1, floori(float(a_full) / 2.0)) if a_full > 0 else 0
	return a_full


## `offset(t) = round(dir * A_peak * (1 - t/D)^2)` for `0 <= t < D`, else 0,
## per component, round half away from zero (AC-21). `dir` is a unit
## horizontal or vertical vector, in screen pixels with y down.
static func offset_px(t: float, d: float, a_peak: int, dir: Vector2) -> Vector2i:
	if t < 0.0 or t >= d or d <= 0.0:
		return Vector2i.ZERO
	var k: float = 1.0 - t / d
	var v: Vector2 = dir * float(a_peak) * k * k
	return Vector2i(_round_half_away(v.x), _round_half_away(v.y))


## `A_beat` for a beat's outcome, or 0.0 for no punch (AC-10): only an
## outcome that lowers the target's HP punches (`hp_delta < 0`); a heal,
## Defend, Speak to the Manager, Viral Stunt or 0-damage Attack does not. A
## knockout, or a beat whose actor is the encounter's boss, is big.
static func beat_amplitude(hp_delta: int, knocked_out: bool, actor_is_boss: bool,
		p_config: PresentationConfig) -> float:
	if hp_delta >= 0:
		return 0.0
	if knocked_out or actor_is_boss:
		return p_config.punch_amplitude_big
	return p_config.punch_amplitude_normal


## Call on a beat's impact frame: starts the punch the outcome calls for (at
## most one per beat) and returns whether one started. The offset is non-zero
## on this same frame (`t = 0`).
func on_impact(hp_delta: int, knocked_out: bool, actor_is_boss: bool, dir: Vector2) -> bool:
	var a_beat: float = beat_amplitude(hp_delta, knocked_out, actor_is_boss, config)
	if a_beat <= 0.0:
		return false
	return start(a_beat, dir)


## Starts a punch of `a_beat` px at 1080p in `dir`, with `t = 0`. Refused
## (returns false, warns) while another punch is still running, so punches
## never overlap even under a latched `ff_mult` replay (AC-21).
func start(a_beat: float, dir: Vector2) -> bool:
	if is_running():
		refused_count += 1
		push_warning("HitPunch: a punch was requested while another is running; dropped (rule 8)")
		return false
	_running = true
	_elapsed = 0.0
	_a_beat = a_beat
	_dir = dir
	started_count += 1
	started.emit(a_beat, dir)
	return true


## Advances the running punch by `dt` seconds of 1x time (`t` is never sped
## up by `ff_mult`, GDD `hit_punch` `t`). Not called while the Menu freezes
## mode time, so the punch holds exactly.
func advance(dt: float) -> void:
	if not _running:
		return
	_elapsed += dt
	if _elapsed >= config.punch_duration:
		_running = false


## Whether a punch is still running (`t < D`).
func is_running() -> bool:
	return _running


## The running punch's elapsed time `t`, in seconds.
func elapsed() -> float:
	return _elapsed if _running else 0.0


## Ends any punch at once (Retry display reset, leaving mid-replay).
func cancel() -> void:
	_running = false
	_elapsed = 0.0


## This frame's offset in whole screen pixels (y down) at window height
## `h_screen` (full window pixels). `A_peak` is recomputed on every call from
## the current height and settings, so a resize or a settings change applies
## on the next frame with `t` unchanged (AC-41, AC-51).
func current_offset_px(h_screen: int) -> Vector2i:
	if not _running:
		return Vector2i.ZERO
	return offset_px(_elapsed, config.punch_duration, current_peak(h_screen), _dir)


## The running punch's `A_peak` at `h_screen` under the current settings.
func current_peak(h_screen: int) -> int:
	var shake: PresentationSettings.ScreenShake = PresentationSettings.ScreenShake.FULL
	var reduce: bool = false
	if settings != null:
		shake = settings.screen_shake
		reduce = settings.reduce_motion
	return peak_amplitude(full_amplitude(_a_beat, h_screen), shake, reduce)


static func _round_half_away(value: float) -> int:
	if value >= 0.0:
		return int(floor(value + 0.5))
	return -int(floor(-value + 0.5))
