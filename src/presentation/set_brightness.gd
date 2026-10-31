## The GDD's `set_brightness_and_blur` formula (`design/gdd/sprite-camera-presentation.md`
## Formulas; story 028, AC-24). Pure and static: every input is a
## `LightingProfile`, the `PresentationConfig` knobs, or a stage's authored
## native energies (`BattleStage.set_energy_native` / `sky_energy_native`).
##
## `B_set = B_native * k_state`, with `k_state` from the config per state and
## the Victory curve for Victory; `B_sky = B_sky_native * k_state` except in the
## boss takeover, whose sky is the flood swatch; `B_fill_boss = B_set /
## set_key_fill_ratio_boss`; `blur = blur_base * (reduce_blur ? reduce_blur_factor : 1)`.
## Victory runs on a 1x tween (ADR-0005 §3), so `t` here is that tween's time.
##
## `state_values()` builds the whole measured lighting state of one frame as a
## `LightingProfile`, which the owning mode applies to its `DioramaStage`.
class_name SetBrightness
extends RefCounted

## The battle-family lighting states (plus `OTHER`, where `k_state = 1`).
enum State { OTHER, BATTLE, BOSS_TAKEOVER, VICTORY, DEFEAT }


## `k_state` for a steady state: Battle, Boss takeover and Defeat read their
## config level; `OTHER` is 1.0. Victory is time-dependent (`victory_k`); this
## returns its settle level for `State.VICTORY`.
static func k_state(state: State, config: PresentationConfig) -> float:
	match state:
		State.BATTLE:
			return config.set_brightness_battle
		State.BOSS_TAKEOVER:
			return config.set_brightness_boss
		State.DEFEAT:
			return config.set_brightness_defeat
		State.VICTORY:
			return config.set_brightness_victory_settle
	return 1.0


## Victory's `k_from`: the set brightness captured on Victory's first frame,
## `set_brightness_boss` after a boss fight, else `set_brightness_battle`.
static func victory_k_from(after_boss: bool, config: PresentationConfig) -> float:
	return config.set_brightness_boss if after_boss else config.set_brightness_battle


## The Victory curve at `t` seconds since Victory began: up from `k_from` to
## `set_brightness_victory` over `blend_victory`, then down to
## `set_brightness_victory_settle` over `victory_settle`, held after.
static func victory_k(t: float, k_from: float, config: PresentationConfig) -> float:
	if t <= config.blend_victory:
		return lerpf(k_from, config.set_brightness_victory,
				smoothstep(0.0, 1.0, clampf(t / config.blend_victory, 0.0, 1.0)))
	return lerpf(config.set_brightness_victory, config.set_brightness_victory_settle,
			smoothstep(0.0, 1.0, minf(1.0, (t - config.blend_victory) / config.victory_settle)))


## The burst's shape `w(t)` in [0, 1]: 0 at `t = 0`, 1 at the peak
## (`blend_victory`), back to 0 at the end of the settle and after, with the
## same smoothstep segments as `victory_k`.
static func victory_shape(t: float, config: PresentationConfig) -> float:
	if t <= config.blend_victory:
		return smoothstep(0.0, 1.0, clampf(t / config.blend_victory, 0.0, 1.0))
	return 1.0 - smoothstep(0.0, 1.0,
			minf(1.0, (t - config.blend_victory) / config.victory_settle))


## The actors' key and rim multiplier over their Battle values during Victory
## ("the same curve shape", GDD `set_brightness_and_blur`): `1 + (peak/k_from
## - 1) * w(t)`, so 1 at `t = 0` and from the end of the settle on, and above 1
## in between (the load rule keeps `set_brightness_victory > k_from`).
static func victory_actor_scale(t: float, k_from: float, config: PresentationConfig) -> float:
	return 1.0 + (config.set_brightness_victory / k_from - 1.0) * victory_shape(t, config)


## `k` for `state` at `t` (only Victory reads `t` and `after_boss`).
static func k_at(state: State, t: float, after_boss: bool, config: PresentationConfig) -> float:
	if state == State.VICTORY:
		return victory_k(t, victory_k_from(after_boss, config), config)
	return k_state(state, config)


## `blur = blur_base * (reduce_blur ? reduce_blur_factor : 1)`. Reduce Blur
## scales blur only; the Menu backdrop's blur uses the same rule, and it is a
## pure function of the live setting, so it applies to a frozen frame at once.
static func blur(blur_base: float, reduce_blur: bool, config: PresentationConfig) -> float:
	return blur_base * (config.reduce_blur_factor if reduce_blur else 1.0)


## The lighting state of one battle-family frame, as a new profile:
## - `base`: the state's own preset (`battle`, `boss_<faction>`, `victory`, `defeat`);
## - `battle`: the stage's Battle preset (the actors' key/rim reference);
## - `flood`: the boss takeover preset the fight ended in, or null after an
##   ordinary fight (Victory then keeps the flood's sky colors);
## - `b_native`/`b_sky_native`: the stage's authored set and sky energies;
## - `reduce_blur`: the live Reduce Blur setting.
## Sets `set_energy`, `sky_energy`, the boss takeover's `fill_energy`, Victory's
## actor key/rim and `dof_amount`; every other field is `base`'s.
static func state_values(state: State, t: float, base: LightingProfile,
		battle: LightingProfile, flood: LightingProfile, b_native: float,
		b_sky_native: float, reduce_blur: bool, config: PresentationConfig) -> LightingProfile:
	var out := base.duplicate() as LightingProfile
	var k: float = k_at(state, t, flood != null, config)
	out.set_energy = b_native * k
	if state == State.BOSS_TAKEOVER:
		out.fill_energy = out.set_energy / config.set_key_fill_ratio_boss
	else:
		out.sky_energy = b_sky_native * k
	if state == State.VICTORY:
		var scale: float = victory_actor_scale(t, victory_k_from(flood != null, config), config)
		out.key_color = battle.key_color
		out.rim_color = battle.rim_color
		out.key_energy = battle.key_energy * scale
		out.rim_strength = battle.rim_strength * scale
		if flood != null:
			out.sky_top = flood.sky_top
			out.sky_bottom = flood.sky_bottom
			out.sky_horizon = flood.sky_horizon
			out.sky_horizon_width = flood.sky_horizon_width
			out.sky_horizon_intensity = flood.sky_horizon_intensity
	out.dof_amount = blur(base.dof_amount, reduce_blur, config)
	return out
