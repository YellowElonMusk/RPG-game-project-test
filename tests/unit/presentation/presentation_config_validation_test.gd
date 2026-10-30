## Story 061, AC-56: `PresentationConfig.validate()` is the GDD's full load
## rule list (Formulas `replay_time`, "Load-time validation"). Each fixture
## breaks exactly one rule by 0.01 and must produce exactly one content error
## naming that rule; a fixture exactly on each boundary passes; every corner
## of the range-chained knobs passes; all-min and all-max configs pass (bar
## the key:fill and horizon rules, which ranges can't guarantee). Fixtures
## are factory functions computed from the base config, run against the
## default config and once against the non-default all-max config. Knob
## ranges are read from the resource's own `@export_range` hints.
extends GdUnitTestSuite

const _MARGIN := 0.01
const _C := preload("res://src/presentation/presentation_config.gd")

## Range-chained knob groups: no rule spans two groups, so every corner of
## the full knob space passes iff every corner of each group does.
const _CHAINED_GROUPS: Array[Array] = [
	[&"battle_speed_mult", &"ff_mult"],
	[&"reaction_hold", &"beat_min", &"ko_hold", &"punch_duration", &"follow_camera_dt_max"],
	[&"boss_retry_hold", &"blend_boss", &"boss_hold"],
	[&"blend_victory", &"victory_hold"],
	[&"blend_defeat", &"defeat_hold"],
	[&"set_brightness_battle", &"set_brightness_boss", &"set_brightness_victory",
			&"set_brightness_victory_settle"],
	[&"flash_rate_max"],
]


## `{name: Vector2(min, max)}` for every `@export_range` knob.
func _ranges() -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in PresentationConfig.new().get_property_list():
		if int(prop["hint"]) == PROPERTY_HINT_RANGE and int(prop["type"]) == TYPE_FLOAT:
			var parts: PackedStringArray = String(prop["hint_string"]).split(",")
			out[StringName(prop["name"])] = Vector2(float(parts[0]), float(parts[1]))
	return out


func _extreme(use_max: bool) -> PresentationConfig:
	var config := PresentationConfig.new()
	var ranges: Dictionary = _ranges()
	for key: StringName in ranges:
		config.set(key, (ranges[key] as Vector2).y if use_max else (ranges[key] as Vector2).x)
	return config


func _bases() -> Array[PresentationConfig]:
	return [PresentationConfig.new(), _extreme(true)]


func _profile_with_ratio(ratio: float) -> LightingProfile:
	var profile := LightingProfile.new()
	profile.fill_energy = 1.0
	profile.set_energy = ratio
	return profile


## Alternating transitions 0.6 s apart at 1x: within 3 flashes/s at 1x and
## at the largest `battle_speed_mult`, over the limit at `ff_mult` >= 2.
func _fast_sequence() -> PackedFloat64Array:
	return PackedFloat64Array([0.0, 0.6, 1.2, 1.8, 2.4, 3.0])


## The rule each break case `i` of `_apply_break()` must name.
const _BREAK_RULES: Array[String] = [
	_C.RULE_PRESS_HELPS, _C.RULE_DEBUG_WINDUP, _C.RULE_REACTION_KO, _C.RULE_PUNCH,
	_C.RULE_DT_MAX, _C.RULE_RETRY_HOLD, _C.RULE_VICTORY_HOLD, _C.RULE_DEFEAT_HOLD,
	_C.RULE_BATTLE_BOSS, _C.RULE_VICTORY_SETTLE, _C.RULE_VICTORY_BURST,
	_C.RULE_FLASH_SEQUENCES, _C.RULE_FLASH_SEQUENCES, _C.RULE_KEY_FILL, _C.RULE_KEY_FILL,
	_C.RULE_FLASH_CONSTANTS, _C.RULE_FLASH_CONSTANTS, _C.RULE_FLASH_CONSTANTS, _C.RULE_HORIZON,
]
## Number of exact-boundary cases in `_apply_boundary()`.
const _BOUNDARY_CASES := 13


## Breaks rule `_BREAK_RULES[i]` on `c` by `_MARGIN`, computed from `c`'s own
## values; returns `[profiles, reserved_sequences, capped_variants]`.
func _apply_break(c: PresentationConfig, i: int) -> Array:
	match i:
		0: c.battle_speed_mult = c.ff_mult - 0.25 + _MARGIN
		1: c.reaction_hold = c.beat_min - 0.10 + _MARGIN
		2: c.ko_hold = c.reaction_hold - _MARGIN
		3: c.punch_duration = c.reaction_hold + _MARGIN
		4: c.follow_camera_dt_max = c.beat_min + _MARGIN
		5: c.boss_retry_hold = c.blend_boss + c.boss_hold + _MARGIN
		6: c.blend_victory = c.victory_hold + _MARGIN
		7: c.blend_defeat = c.defeat_hold + _MARGIN
		8: c.set_brightness_battle = c.set_brightness_boss + _MARGIN
		9: c.set_brightness_victory_settle = c.set_brightness_victory + _MARGIN
		10:
			c.set_brightness_victory = c.set_brightness_boss + 0.05 - _MARGIN
			c.set_brightness_victory_settle = minf(c.set_brightness_victory_settle,
					c.set_brightness_victory)
		11: return [[], [], [{"general": false, "red": true, "area": c.flash_area_min + _MARGIN}]]
		12: return [[], [_fast_sequence()], []]
		13: return [[_profile_with_ratio(c.set_key_fill_ratio_boss)], [], []]
		14: return [[_profile_with_ratio(c.set_key_fill_ratio_boss + _MARGIN)], [], []]
		15: c.flash_rate_max = _C.FLASH_RATE_CEILING + _MARGIN
		16: c.flash_luma_delta = _C.FLASH_LUMA_DELTA + _MARGIN
		17: c.flash_area_min = _C.FLASH_AREA_MIN + _MARGIN
		18: c.follow_camera_horizon_margin_degrees = _horizon_slack(c) + _MARGIN
	return [[], [], []]


## Puts `c` exactly on boundary `i` of the range rules.
func _apply_boundary(c: PresentationConfig, i: int) -> void:
	match i:
		0: c.battle_speed_mult = c.ff_mult - 0.25
		1: c.reaction_hold = c.beat_min - 0.10
		2: c.ko_hold = c.reaction_hold
		3: c.punch_duration = c.reaction_hold
		4: c.follow_camera_dt_max = c.beat_min
		5: c.boss_retry_hold = c.blend_boss + c.boss_hold
		6: c.blend_victory = c.victory_hold
		7: c.blend_defeat = c.defeat_hold
		8: c.set_brightness_battle = c.set_brightness_boss
		9: c.set_brightness_victory_settle = c.set_brightness_victory
		10:
			c.set_brightness_victory = c.set_brightness_boss + 0.05
			c.set_brightness_victory_settle = minf(c.set_brightness_victory_settle,
					c.set_brightness_victory)
		11: c.flash_rate_max = _C.FLASH_RATE_CEILING
		12: c.follow_camera_horizon_margin_degrees = _horizon_slack(c)


## `pitch - F_v_eff(4:3)/2` for `c`'s follow camera.
func _horizon_slack(c: PresentationConfig) -> float:
	return c.follow_camera_pitch_degrees - FollowCamera.effective_vertical_fov_degrees(
			c.follow_camera_fov_degrees, 4.0 / 3.0) * 0.5


func _run(c: PresentationConfig, args: Array) -> PackedStringArray:
	var profiles: Array[LightingProfile] = []
	profiles.assign(args[0])
	var sequences: Array[PackedFloat64Array] = []
	sequences.assign(args[1])
	var variants: Array[Dictionary] = []
	variants.assign(args[2])
	return c.validate(profiles, sequences, variants)


func test_default_config_and_shipped_profiles_pass() -> void:
	var profiles: Array[LightingProfile] = []
	for id: String in ["title", "overworld", "overworld_liberated", "battle", "camp", "victory",
			"defeat"]:
		profiles.append(load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile)
	var seqs: Array[PackedFloat64Array] = [PackedFloat64Array([0.0, 1.0, 2.0, 3.0, 4.0])]
	assert_array(Array(PresentationConfig.new().validate(profiles, seqs))).is_empty()


func test_each_broken_rule_gives_one_error_naming_it() -> void:
	for base: PresentationConfig in _bases():
		for i: int in _BREAK_RULES.size():
			var config: PresentationConfig = base.duplicate() as PresentationConfig
			var errors: PackedStringArray = _run(config, _apply_break(config, i))
			assert_int(errors.size()).override_failure_message(
					"case %d %s: %s" % [i, _BREAK_RULES[i], errors]).is_equal(1)
			if errors.size() == 1:
				assert_bool(errors[0].begins_with(_BREAK_RULES[i])) \
						.override_failure_message(errors[0]).is_true()


func test_config_exactly_on_each_boundary_passes() -> void:
	for base: PresentationConfig in _bases():
		for i: int in _BOUNDARY_CASES:
			var c: PresentationConfig = base.duplicate() as PresentationConfig
			_apply_boundary(c, i)
			assert_array(Array(c.validate())) \
					.override_failure_message("boundary %d" % i).is_empty()
		# Flash and key:fill boundaries: a capped red variant just under the
		# area minimum, a reserved sequence landing exactly flash_rate_max
		# flashes in a closed second at ff_mult, and a non-boss ratio just
		# under the boss ratio.
		var cfg: PresentationConfig = base.duplicate() as PresentationConfig
		var spacing: float = cfg.ff_mult / (cfg.flash_rate_max - 1.0)
		var seq := PackedFloat64Array()
		for k: int in 6:
			seq.append(k * spacing)
		var seqs: Array[PackedFloat64Array] = [seq]
		var variants: Array[Dictionary] = [
			{"general": true, "red": true, "area": cfg.flash_area_min - _MARGIN}]
		var profiles: Array[LightingProfile] = [
			_profile_with_ratio(cfg.set_key_fill_ratio_boss - _MARGIN)]
		assert_int(PresentationConfig.max_flashes_in_window(seq, cfg.ff_mult)) \
				.is_equal(int(cfg.flash_rate_max))
		assert_array(Array(cfg.validate(profiles, seqs, variants))).is_empty()


func test_every_corner_of_chained_knobs_passes() -> void:
	var ranges: Dictionary = _ranges()
	for group: Array in _CHAINED_GROUPS:
		for mask: int in 1 << group.size():
			var c := PresentationConfig.new()
			for i: int in group.size():
				var r: Vector2 = ranges[group[i]]
				c.set(group[i], r.y if (mask >> i) & 1 else r.x)
			assert_array(Array(c.validate())) \
					.override_failure_message("%s mask %d" % [group, mask]).is_empty()


func test_all_min_and_all_max_configs_pass_range_guaranteed_rules() -> void:
	for use_max: bool in [false, true]:
		var errors: Array = []
		for e: String in _extreme(use_max).validate():
			if not e.begins_with(_C.RULE_KEY_FILL) and not e.begins_with(_C.RULE_HORIZON):
				errors.append(e)
		assert_array(errors).override_failure_message("max=%s %s" % [use_max, errors]).is_empty()
