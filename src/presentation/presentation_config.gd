## Presentation data (ADR-0005 §5): the texel scale, the follow camera and
## the GDD Tuning Knobs, plus the GDD's full load-rule list (`validate()`,
## story 061). The profile and sprite-set tables and
## `data/config/presentation_config.tres` are later stories' scope; widen
## this file in place there rather than duplicating it.
class_name PresentationConfig
extends Resource

## The logical sprite resolution's height (GDD `texel_scale`; 360 by
## creative-director ruling 4, D3).
@export var texel_base_lines: int = 360
## The single humanoid sprite frame height in texels (GDD rule 2, 48-64).
## Large-alien frame heights are integer multiples of it.
@export var humanoid_height_px: int = 0

## The Overworld follow camera's fixed knobs (GDD `follow_camera`, ADR-0005
## §6; story 023). `FollowCamera.from_config()` reads these -- never
## literals (Control Manifest, this layer).
@export_group("Follow Camera")
## Camera height above the ground plane, in meters (`h`). 12.0 m, the
## Overworld GDD's OQ-1 proposal: the lowest round height that clears
## `chase_visibility` (I14) at every dz and tau in their safe ranges (story
## 099; 10.0 m fails at every aspect).
@export var follow_camera_height: float = 12.0
## Fixed pitch below the horizon, in degrees (`pitch`).
@export var follow_camera_pitch_degrees: float = 30.0
## Vertical field of view at 16:9, in degrees, before `F_v_eff` widening (`F_v`).
@export var follow_camera_fov_degrees: float = 20.0
## Dead-zone half-size as a fraction of the footprint's half-extent per axis
## (`dz`; Tuning Knobs: 8-12%, default 10%).
@export_range(0.08, 0.12, 0.01) var follow_camera_dead_zone_fraction: float = 0.10
## Time to cover 63% of the remaining excess, in seconds (`tau`; Tuning
## Knobs: 0.15-0.18, default 0.17).
@export_range(0.15, 0.18, 0.01) var follow_camera_tau: float = 0.17
## Largest frame step used by the ease, in seconds (`dt_max`; Tuning Knobs:
## 0.05-0.10, default 0.10).
@export_range(0.05, 0.10, 0.01) var follow_camera_dt_max: float = 0.10
## How far below the horizon the footprint's far edge must stay at 4:3, in
## degrees (`horizon_margin`; Tuning Knobs: 3-10, default 5).
@export_range(3.0, 10.0, 0.5) var follow_camera_horizon_margin_degrees: float = 5.0
## The tallest overworld actor's card height, in metres (`H_max`; I14's near
## blur bound subtracts `H_max * sin(pitch)`). Placeholder until the sprite
## sets are authored.
@export var overworld_card_height_max_m: float = 2.0

## The battle camera and `battle_framing`'s load bounds (GDD `battle_framing`,
## ADR-0005 §6; stories 006, 022, 046, 050). Per-stage values (`h_cam`,
## `horizon_frac`, slot depths) live on each `BattleStage`, not here.
@export_group("Battle Framing")
## Vertical field of view at 16:9, in degrees (`F_v`, `battle_fov`). Set by
## the Step 1 spike; 20 degrees is the GDD worked example's value.
@export var battle_fov_degrees: float = 20.0
## The battle camera's near plane, in metres (`size = h_near` is measured on
## it). Never changes in a fight.
@export var battle_camera_near: float = 0.05
## The battle camera's far plane, in metres.
@export var battle_camera_far: float = 200.0
## Smallest share of any actor's quad that must stay visible at the default
## battle camera (`actor_visible_min`; Tuning Knobs: 0.85-0.95).
@export_range(0.85, 0.95, 0.01) var actor_visible_min: float = 0.90
## Gap in view depth between the farthest slot and where the background blur
## begins, in metres (`dof_margin`; Tuning Knobs: 0.5-2.0).
@export_range(0.5, 2.0, 0.1) var dof_margin: float = 1.0
## Smallest share of the frame the sky must cover on a boss stage
## (`sky_share_min`; Tuning Knobs: 0.15-0.30). `battle_framing` checks the
## necessary bound `horizon_frac >= sky_share_min`.
@export_range(0.15, 0.30, 0.01) var sky_share_min: float = 0.20

## The replay knobs (GDD `replay_time`, ADR-0006 §9; story 061). Ranges are
## the GDD's Tuning Knobs safe ranges; they are chained so every in-range
## combination passes `validate()`'s range-guaranteed rules.
@export_group("Battle Replay")
## Wind-up speed once latched (`ff_mult`).
@export_range(2.0, 2.5, 0.01) var ff_mult: float = 2.0
## Wind-up speed with Faster battle animations On (`battle_speed_mult`).
@export_range(1.25, 1.75, 0.01) var battle_speed_mult: float = 1.5
## How long a plain reaction frame is held clean, in seconds (`reaction_hold`).
@export_range(0.20, 0.30, 0.01) var reaction_hold: float = 0.25
## The shortest knockout hold, in seconds (`ko_hold`).
@export_range(0.40, 0.60, 0.01) var ko_hold: float = 0.50
## The shortest a beat may play after speed-up, in seconds (`beat_min`).
@export_range(0.40, 0.50, 0.01) var beat_min: float = 0.40
## Hit-punch duration, in seconds (`D`).
@export_range(0.08, 0.12, 0.01) var punch_duration: float = 0.10
## Hit-punch peak shift for a normal beat, in screen px at 1080p
## (`A_beat` normal; GDD Tuning Knobs "Camera and punch").
@export_range(2.0, 4.0, 0.5) var punch_amplitude_normal: float = 3.0
## Hit-punch peak shift for a big beat (a knockout, or a hit by the
## encounter's boss), in screen px at 1080p (`A_beat` big).
@export_range(6.0, 8.0, 0.5) var punch_amplitude_big: float = 7.0
## The blob shadow's width, in texels of the actor's frame (rule 12; the
## "foot width" `shadow_offset` is a fraction of). Screen-constant like the
## sprite, so it is converted to metres per actor depth.
@export_range(16, 64, 1) var shadow_width_texels: int = 30
## How far the blob sits along the set light's ground direction, as a
## fraction of its width (`shadow_offset`; GDD Tuning Knobs: 0-0.5).
@export_range(0.0, 0.5, 0.01) var shadow_offset: float = 0.20

## The lighting beats (GDD Tuning Knobs, "Lighting beats").
@export_group("Lighting Beats")
## The first-encounter boss takeover blend, in seconds (`blend_boss`).
@export_range(0.60, 1.00, 0.01) var blend_boss: float = 0.90
## The boss intro pose hold after the takeover blend, in seconds (`boss_hold`).
@export_range(0.60, 1.20, 0.01) var boss_hold: float = 0.90
## The Retry settle on the boss's intro pose, in seconds (`boss_retry_hold`).
@export_range(0.20, 0.40, 0.01) var boss_retry_hold: float = 0.30
## The Victory blend, in seconds (`blend_victory`).
@export_range(0.25, 0.35, 0.01) var blend_victory: float = 0.30
## The Defeat blend, in seconds (`blend_defeat`).
@export_range(0.25, 0.35, 0.01) var blend_defeat: float = 0.30
## How long the fanfare poses are seen, in seconds (`victory_hold`).
@export_range(0.35, 0.60, 0.01) var victory_hold: float = 0.40
## How long the curtain-call poses are seen, in seconds (`defeat_hold`).
@export_range(0.35, 0.60, 0.01) var defeat_hold: float = 0.40
## How long the Victory light takes to settle after the burst, in seconds.
@export_range(0.30, 0.50, 0.01) var victory_settle: float = 0.40

## Set brightness levels (GDD `set_brightness_and_blur`).
@export_group("Set Brightness")
## Battle set brightness relative to native (`set_brightness_battle`).
@export_range(0.60, 0.75, 0.01) var set_brightness_battle: float = 0.70
## Boss takeover set brightness (`set_brightness_boss`).
@export_range(0.75, 0.85, 0.01) var set_brightness_boss: float = 0.85
## Set brightness at the Victory burst's peak (`set_brightness_victory`).
@export_range(0.90, 0.95, 0.01) var set_brightness_victory: float = 0.90
## Set brightness the Victory light settles at (`set_brightness_victory_settle`).
@export_range(0.75, 0.85, 0.01) var set_brightness_victory_settle: float = 0.85
## Set brightness outside the Defeat spotlight (`set_brightness_defeat`).
@export_range(0.30, 0.50, 0.01) var set_brightness_defeat: float = 0.40
## Set light energy over flooded fill energy in a boss takeover; must exceed
## every non-boss preset's set:fill ratio (checked, not range-guaranteed).
@export_range(4.0, 6.0, 0.1) var set_key_fill_ratio_boss: float = 4.0

## Photosensitivity safety (GDD `flash_gate`).
@export_group("Flash Safety")
## Most flashes in any one-second window (`flash_rate_max`); never above 3.
@export_range(1.0, 3.0, 0.5) var flash_rate_max: float = 3.0
## General-transition luminance threshold. A constant: anything but
## `FLASH_LUMA_DELTA` fails load validation.
@export var flash_luma_delta: float = 0.10
## Smallest counted area of a 10-degree window. A constant: anything but
## `FLASH_AREA_MIN` fails load validation.
@export var flash_area_min: float = 0.25


## The required value of `flash_luma_delta` (GDD `flash_gate`).
const FLASH_LUMA_DELTA: float = 0.10
## The required value of `flash_area_min` (GDD `flash_gate`).
const FLASH_AREA_MIN: float = 0.25
## The largest `flash_rate_max` WCAG allows.
const FLASH_RATE_CEILING: float = 3.0
## Tolerance every load rule allows in its passing direction (GDD
## `replay_time`, "Load-time validation").
const RULE_EPSILON: float = 1e-6

## Load rule names (GDD Formulas `replay_time`, "Load-time validation").
## Every content error `validate()` returns starts with one of these.
const RULE_PRESS_HELPS := "battle_speed_mult <= ff_mult - 0.25"
## See `RULE_PRESS_HELPS`.
const RULE_DEBUG_WINDUP := "reaction_hold <= beat_min - 0.10"
## See `RULE_PRESS_HELPS`.
const RULE_REACTION_KO := "reaction_hold <= ko_hold"
## See `RULE_PRESS_HELPS`.
const RULE_PUNCH := "D < reaction_hold"
## See `RULE_PRESS_HELPS`.
const RULE_DT_MAX := "dt_max < beat_min"
## See `RULE_PRESS_HELPS`.
const RULE_RETRY_HOLD := "boss_retry_hold <= blend_boss + boss_hold"
## See `RULE_PRESS_HELPS`.
const RULE_VICTORY_HOLD := "blend_victory <= victory_hold"
## See `RULE_PRESS_HELPS`.
const RULE_DEFEAT_HOLD := "blend_defeat <= defeat_hold"
## See `RULE_PRESS_HELPS`.
const RULE_BATTLE_BOSS := "set_brightness_battle <= set_brightness_boss"
## See `RULE_PRESS_HELPS`.
const RULE_VICTORY_SETTLE := "set_brightness_victory_settle <= set_brightness_victory"
## See `RULE_PRESS_HELPS`.
const RULE_VICTORY_BURST := "set_brightness_victory >= set_brightness_boss + 0.05"
## See `RULE_PRESS_HELPS`.
const RULE_FLASH_SEQUENCES := "capped variants and reserved sequences within flash_rate_max"
## See `RULE_PRESS_HELPS`.
const RULE_KEY_FILL := "set_key_fill_ratio_boss > every non-boss preset's set key:fill ratio"
## See `RULE_PRESS_HELPS`.
const RULE_FLASH_CONSTANTS := "flash_rate_max <= 3, flash_luma_delta = 0.10, flash_area_min = 0.25"
## See `RULE_PRESS_HELPS`.
const RULE_HORIZON := "pitch - F_v_eff(4:3)/2 >= horizon_margin"


## Runs the GDD's full load-rule list (story 061, ADR-0005 §5/§9) and returns
## one content error per broken rule, each starting with the rule's name
## (`RULE_*`); empty means the config passes. Every comparison allows
## `RULE_EPSILON` in its passing direction, so a config exactly on a
## boundary passes; the key:fill rule alone is strict ("at or below" fails).
##
## The data the ranges can't guarantee is injected:
## - `non_boss_profiles`: every non-boss `LightingProfile`, for the key:fill rule;
## - `reserved_sequences`: each scripted reserved flash sequence as its
##   alternating transition offsets at 1x, in seconds; checked at 1x,
##   `battle_speed_mult` and `ff_mult`;
## - `capped_variants`: each capped variant's declared frames as
##   `{"general": bool, "red": bool, "area": float}`.
## TODO(sprite-camera-presentation): register with `ContentBootstrap` (ADR-0005 §9)
## once ADR-0004 gains a config-level (non-record) validator hook and a
## shipped `presentation_config.tres` exists; `register_record_validator`
## is per catalog record type and `PresentationConfig` is not a record. Then
## FlashGate's source
## declarations (§12) replace the plain sequence/variant inputs.
func validate(non_boss_profiles: Array[LightingProfile] = [],
		reserved_sequences: Array[PackedFloat64Array] = [],
		capped_variants: Array[Dictionary] = []) -> PackedStringArray:
	var errors := PackedStringArray()
	_check(errors, battle_speed_mult <= ff_mult - 0.25 + RULE_EPSILON, RULE_PRESS_HELPS)
	_check(errors, reaction_hold <= beat_min - 0.10 + RULE_EPSILON, RULE_DEBUG_WINDUP)
	_check(errors, reaction_hold <= ko_hold + RULE_EPSILON, RULE_REACTION_KO)
	_check(errors, punch_duration <= reaction_hold + RULE_EPSILON, RULE_PUNCH)
	_check(errors, follow_camera_dt_max <= beat_min + RULE_EPSILON, RULE_DT_MAX)
	_check(errors, boss_retry_hold <= blend_boss + boss_hold + RULE_EPSILON, RULE_RETRY_HOLD)
	_check(errors, blend_victory <= victory_hold + RULE_EPSILON, RULE_VICTORY_HOLD)
	_check(errors, blend_defeat <= defeat_hold + RULE_EPSILON, RULE_DEFEAT_HOLD)
	_check(errors, set_brightness_battle <= set_brightness_boss + RULE_EPSILON, RULE_BATTLE_BOSS)
	_check(errors, set_brightness_victory_settle <= set_brightness_victory + RULE_EPSILON,
			RULE_VICTORY_SETTLE)
	_check(errors, set_brightness_victory >= set_brightness_boss + 0.05 - RULE_EPSILON,
			RULE_VICTORY_BURST)
	_check(errors, _flash_sequences_pass(reserved_sequences, capped_variants), RULE_FLASH_SEQUENCES)
	var key_fill_ok := true
	for profile: LightingProfile in non_boss_profiles:
		if profile.fill_energy <= 0.0 \
				or set_key_fill_ratio_boss <= profile.set_energy / profile.fill_energy:
			key_fill_ok = false
	_check(errors, key_fill_ok, RULE_KEY_FILL)
	_check(errors, flash_rate_max <= FLASH_RATE_CEILING + RULE_EPSILON
			and absf(flash_luma_delta - FLASH_LUMA_DELTA) <= RULE_EPSILON
			and absf(flash_area_min - FLASH_AREA_MIN) <= RULE_EPSILON, RULE_FLASH_CONSTANTS)
	var f_v_eff: float = FovMath.effective_vertical_fov_degrees(
			follow_camera_fov_degrees, 4.0 / 3.0)
	_check(errors, follow_camera_pitch_degrees - f_v_eff * 0.5
			>= follow_camera_horizon_margin_degrees - RULE_EPSILON, RULE_HORIZON)
	return errors


func _check(errors: PackedStringArray, ok: bool, rule: String) -> void:
	if not ok:
		errors.append("%s -- PresentationConfig load rule failed" % rule)


## Capped variants: no general and no red transition, unless below
## `flash_area_min`. Reserved sequences: at most `flash_rate_max` flashes in
## any closed one-second window, at 1x, `battle_speed_mult` and `ff_mult`
## (GDD `flash_gate`).
func _flash_sequences_pass(reserved_sequences: Array[PackedFloat64Array],
		capped_variants: Array[Dictionary]) -> bool:
	for variant: Dictionary in capped_variants:
		var flashing: bool = bool(variant.get("general", false)) or bool(variant.get("red", false))
		if flashing and float(variant.get("area", 1.0)) >= flash_area_min - RULE_EPSILON:
			return false
	for offsets: PackedFloat64Array in reserved_sequences:
		for speed: float in [1.0, battle_speed_mult, ff_mult]:
			if max_flashes_in_window(offsets, speed) > flash_rate_max + RULE_EPSILON:
				return false
	return true


## The most flashes landing in any closed one-second window when `offsets`
## (alternating transitions, seconds at 1x) play at `speed` (GDD
## `flash_gate`: N alternating transitions are N-1 flashes, so the first
## transition is never one).
static func max_flashes_in_window(offsets: PackedFloat64Array, speed: float) -> int:
	var lands: Array[float] = []
	for o: float in offsets:
		lands.append(o / speed)
	lands.sort()
	var best: int = 0
	for i: int in range(1, lands.size()):
		var count: int = 0
		for j: int in range(i, lands.size()):
			if lands[j] <= lands[i] + 1.0 + RULE_EPSILON:
				count += 1
		best = maxi(best, count)
	return best
