## The lighting rig a 3D mode scene owns (ADR-0005 Decision §3, abridged here
## to the key/rim/set/fill setup Story 003's AC needs, plus Story 008's
## `active_diorama_stage` group membership so `PresentationDirector` can find
## the live stage on `mode_entered`). Camera and the sky card remain later
## stories' scope (§6 camera stories, the capture tool's sky card) -- this
## file owns the light rig, the profile pipeline and group membership only.
##
## The rig is fixed at `_ready()`, never from profile data (ADR-0005 §3, §5):
## `key_light` is culled to `ACTORS` and never casts shadows (only the key
## and tagged practicals light actors -- the spike's verification item 12);
## `set_light` and `fill_light` are culled to `SET`; `set_light` is the only
## shadow caster. The `WorldEnvironment`'s ambient is pinned to 0 -- the
## set's fill comes from `fill_light`, and actors take no ambient at all
## (actor shadow casting itself is Story 020's scope, not this file's).
class_name DioramaStage
extends Node3D

## Cull mask bit for the set (sky card, practicals, blob shadows).
const LAYER_SET := 1
## Cull mask bit for actors (`CharacterSprite` instances).
const LAYER_ACTORS := 2
## Group every live stage joins on `_enter_tree()` (ADR-0005 §3). At most one
## member at a time -- ADR-0002 keeps exactly one mode in the tree.
## `PresentationDirector` is the only reader, and only on `mode_entered`.
const GROUP: StringName = &"active_diorama_stage"
## A blob shadow's ground depth as a multiple of its width (see
## `place_blob_shadow()`).
const BLOB_DEPTH_RATIO: float = 2.0

## This stage's entry profile id (ADR-0005 §3): the owning mode sets it
## before the stage enters the tree. Every battle stage enters on `battle`
## (never a `boss_<faction>` entry profile -- the boss light is always a
## later `request_profile()`, never this). `PresentationDirector` reads it
## on `mode_entered`, resolving it through its own profile lookup.
@export var profile_id: StringName

## The actor key light. Culled to `ACTORS` only, never casts shadows.
@export var key_light: DirectionalLight3D
## The set light. Culled to `SET` only; the scene's only shadow caster.
@export var set_light: DirectionalLight3D
## The fill light. Culled to `SET` only, never casts shadows.
@export var fill_light: DirectionalLight3D
## The stage's environment. Ambient is pinned to 0 at `_ready()`.
@export var world_environment: WorldEnvironment

## The blended rim color currently applied to actors (read by
## `PresentationDirector` to drive the `actor_rim_color` global uniform).
var current_rim_color: Color = Color.WHITE
## The blended rim strength currently applied to actors (`actor_rim_strength`).
var current_rim_strength: float = 0.0

var _resolver: Callable

## Where this stage reports a content error at runtime (an unknown profile id
## on a debug run that skipped boot validation, story 032): `call(message)`.
## Defaults to `push_error`; tests inject a recorder.
var error_sink: Callable = func(message: String) -> void: push_error(message)

## The narrow Reduce Flashing view (ADR-0009 §7), injected by the owning
## mode; read live every frame by the campfire flicker (story 068). Null
## reads as Off.
var flash_settings: FlashSettings
## The narrow Presentation settings view (ADR-0009 §7), injected by the
## owning mode; Reduce Motion is read live from it (story 048). Null reads
## as Off.
var presentation_settings: PresentationSettings

## Second flicker partial's frequency ratio and phase (an irregular,
## non-repeating-looking fire; fixed shape constants, not tuning knobs).
const _FLICKER_RATIO_2: float = 2.71
const _FLICKER_PHASE_2: float = 1.3
const _FLICKER_WEIGHT_2: float = 0.5

## The mode's one camera (ADR-0005 §3, §6). A battle stage drives it as the
## level shift-lens battle camera after `configure_battle_camera()`; Camp
## and Title leave it fixed as authored (Camp may be pitched) -- no hit or
## party move ever touches a fixed camera (story 007).
@export var camera: Camera3D

var _battle_stage: BattleStage
var _battle_config: PresentationConfig
var _battle_viewport: Vector2i
var _battle_base_shift: Vector2 = Vector2.ZERO
var _punch_px: Vector2i = Vector2i.ZERO


## Joins `GROUP` (ADR-0005 §3) so `PresentationDirector` can find this stage
## on `mode_entered`, including re-entry (e.g. the Overworld re-attached after
## a Battle retreat), and makes the stage's camera current.
func _enter_tree() -> void:
	add_to_group(GROUP)
	if camera != null:
		camera.current = true


## Turns `camera` into the level shift-lens battle camera for `stage`
## (ADR-0005 §6; story 006): `PROJECTION_FRUSTUM`, `KEEP_HEIGHT`, pitch 0,
## `h_offset`/`v_offset` 0, placed by `stage.camera_transform()`. After this
## only `size` (on resize) and `frustum_offset` (base shift + punch) change.
## Inside the tree it follows the viewport's `size_changed`.
func configure_battle_camera(stage: BattleStage, config: PresentationConfig,
		viewport_size: Vector2i) -> void:
	if camera == null:
		push_error("DioramaStage: configure_battle_camera() without a camera")
		return
	_battle_stage = stage
	_battle_config = config
	_punch_px = Vector2i.ZERO
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.near = config.battle_camera_near
	camera.far = config.battle_camera_far
	camera.transform = stage.camera_transform()
	on_viewport_resized(viewport_size)
	if is_inside_tree() and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


## Whether this stage drives a battle camera (else its camera is fixed).
func is_battle_camera() -> bool:
	return _battle_stage != null and camera != null


## Recomputes the battle camera's `size = h_near` and base lens shift for a
## `viewport_size` window, keeping any running punch (ADR-0005 §6). A fixed
## camera ignores it.
func on_viewport_resized(viewport_size: Vector2i) -> void:
	if not is_battle_camera() or viewport_size.y <= 0:
		return
	_battle_viewport = viewport_size
	var aspect: float = float(viewport_size.x) / float(viewport_size.y)
	var size: float = BattleFraming.h_near(_battle_config.battle_camera_near,
			_battle_config.battle_fov_degrees, aspect)
	camera.size = size
	_battle_base_shift = BattleFraming.base_lens_shift(_battle_stage.horizon_frac, size)
	_apply_lens_shift()


## Sets this frame's `hit_punch` offset, in whole screen pixels (y down);
## `Vector2i.ZERO` ends the punch. The battle camera's `frustum_offset`
## becomes the base shift plus the punch's lens shift -- its transform,
## `near`, `size` and `keep_aspect` are untouched. On a fixed (Camp/Title)
## camera this is a no-op (story 007: the punch path is battle-only).
## While a boss takeover is on (its clock-driven blend toward a `boss_*`
## profile, or the hold after it, see `takeover_hold_active`), the punch
## offset is forced to zero (story 013, AC-11).
func apply_hit_punch(punch_px: Vector2i) -> void:
	if not is_battle_camera():
		return
	_punch_px = Vector2i.ZERO if is_takeover_active() else punch_px
	_apply_lens_shift()


## Set by the Battle mode for the boss takeover's hold (`boss_hold`, after the
## blend completes) and cleared when the hold ends (ADR-0006 §5): with the
## clock-driven blend, it makes up the whole takeover window.
var takeover_hold_active: bool = false


## Whether a boss takeover is running (story 013, AC-11): a clock-driven
## blend toward a `boss_*` profile that has not reached `p = 1`, or the hold
## after it (`takeover_hold_active`). A punch requested now is dropped, never
## deferred (`HitPunch.takeover_active`).
func is_takeover_active() -> bool:
	if takeover_hold_active:
		return true
	return _blend_clock.is_valid() and is_blending() and String(_blend_id).begins_with("boss_")


## The battle camera's base lens shift (no punch) at the current window.
func battle_base_shift() -> Vector2:
	return _battle_base_shift


## ADR-0005's name for `apply_hit_punch`: sets this frame's punch, in whole
## screen pixels (y down). The stage owns no punch timer; the owning mode's
## `HitPunch` (story 012) supplies the offset every frame.
func set_punch_offset_px(offset: Vector2i) -> void:
	apply_hit_punch(offset)


## The punch currently applied, in whole screen pixels (y down).
func punch_offset_px() -> Vector2i:
	return _punch_px


## The window height the battle camera was last sized for, in full window
## pixels (`H_screen` for `HitPunch.current_offset_px`); 0 before configure.
func battle_viewport_height() -> int:
	return _battle_viewport.y


## A new blob shadow for one actor (rule 12; story 020): a flat, unlit,
## chunky pixel ellipse on the ground plane, on `SET`, casting nothing.
## Add it under the stage and keep it placed with `place_blob_shadow()`.
func make_blob_shadow() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = _blob_texture()
	mat.albedo_color = _shadow_color()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var blob := MeshInstance3D.new()
	blob.mesh = plane
	blob.material_override = mat
	blob.layers = LAYER_SET
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return blob


## Places `blob` under `foot_anchor` (stage space, on the ground), `width_m`
## wide and `BLOB_DEPTH_RATIO` times as deep (the level battle camera sees
## the ground at a grazing angle, so a round blob would read as a line), offset by `offset_frac * width_m` along the set
## light's ground-projected direction, in the current profile's
## `shadow_color` (AC-17).
func place_blob_shadow(blob: MeshInstance3D, foot_anchor: Vector3, width_m: float,
		offset_frac: float) -> void:
	blob.position = Vector3(foot_anchor.x, 0.0, foot_anchor.z) \
			+ set_light_ground_direction() * offset_frac * width_m
	blob.scale = Vector3(width_m, 1.0, width_m * BLOB_DEPTH_RATIO)
	(blob.material_override as StandardMaterial3D).albedo_color = _shadow_color()


## The set light's travel direction projected onto the ground (unit, y 0):
## the way the diorama's own shadows fall. `Vector3.ZERO` without a set
## light or for a light pointing straight down.
func set_light_ground_direction() -> Vector3:
	if set_light == null:
		return Vector3.ZERO
	var d: Vector3 = -set_light.global_transform.basis.z if set_light.is_inside_tree() \
			else -set_light.transform.basis.z
	d.y = 0.0
	return d.normalized() if d.length() > 0.0001 else Vector3.ZERO


func _shadow_color() -> Color:
	return current_values.shadow_color if current_values != null else LightingProfile.new().shadow_color


static var _blob_tex: Texture2D


## A 16x8 hard-edged ellipse (white; the material tints it): chunky texels,
## no soft falloff (GDD rule 12, "toy block" style).
static func _blob_texture() -> Texture2D:
	if _blob_tex == null:
		var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
		for y: int in 8:
			for x: int in 16:
				var nx: float = (x + 0.5 - 8.0) / 8.0
				var ny: float = (y + 0.5 - 4.0) / 4.0
				img.set_pixel(x, y, Color(1, 1, 1, 1) if nx * nx + ny * ny <= 1.0 else Color(1, 1, 1, 0))
		_blob_tex = ImageTexture.create_from_image(img)
	return _blob_tex


func _apply_lens_shift() -> void:
	camera.frustum_offset = _battle_base_shift + BattleFraming.punch_lens_shift(
			_punch_px, camera.size, _battle_viewport.y)


func _on_viewport_size_changed() -> void:
	# Full window pixels, never get_visible_rect() (logical units under the UI
	# refit; ADR-0005 §1, ADR-0008 §9). Idempotent: it fires twice per refit.
	on_viewport_resized(get_viewport().size)


func _ready() -> void:
	_configure_light_rig()


func _exit_tree() -> void:
	remove_from_group(GROUP)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)


## Pins the light rig's cull masks and shadow casters (ADR-0005 §3). Runs
## once; a profile never touches cull mask, shadow-caster assignment or the
## set light's angle -- those are stage-authored, not profile data (§5).
func _configure_light_rig() -> void:
	if key_light != null:
		key_light.light_cull_mask = LAYER_ACTORS
		key_light.shadow_enabled = false
	if set_light != null:
		set_light.light_cull_mask = LAYER_SET
		set_light.shadow_enabled = true
	if fill_light != null:
		fill_light.light_cull_mask = LAYER_SET
		fill_light.shadow_enabled = false
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ambient_light_energy = 0.0


## Stores the profile resolver (`PresentationDirector`, on `mode_entered`).
## `resolver.call(id: StringName) -> LightingProfile` returns null for an
## unknown ID (ADR-0005 §3).
func bind_profiles(resolver: Callable) -> void:
	_resolver = resolver


## Whether a profile resolver is bound, so `request_profile()` can resolve
## (false in tools and tests that run a mode without the Director).
func has_profiles() -> bool:
	return _resolver.is_valid()


## Resolves `id` through the bound resolver and blends to it over
## `blend_time` (the owning mode's call, never the Director's -- ADR-0005 §3
## "one door"). With a `clock` (`clock.call() -> float`, seconds), the blend
## runs from that clock and no tween (the boss takeover, ADR-0006); without
## one it runs on a tween on this node, which freezes under the Menu with
## everything else in the mode (stories 009/026).
func request_profile(id: StringName, blend_time: float, clock: Callable = Callable()) -> void:
	if not _resolver.is_valid():
		push_error("DioramaStage: request_profile() called before bind_profiles()")
		return
	var profile: LightingProfile = _resolver.call(id)
	if profile == null:
		error_sink.call("DioramaStage: unknown lighting profile '%s'; the light is unchanged" % id)
		return
	_blend_id = id
	_start_blend(profile, blend_time, clock)


## Applies `profile` over `blend_time` (the Director's call only, on mode
## entry with `blend_time = 0`, which gives `p = 1` on the first frame --
## ADR-0005 §3). Cull masks, shadow casters and the set light's angle are
## never touched here (`_configure_light_rig()`'s job).
func apply_profile(profile: LightingProfile, blend_time: float) -> void:
	_blend_id = &""
	_start_blend(profile, blend_time, Callable())


## The blended values currently on the stage (every `LightingProfile`
## parameter, `lighting_blend`'s `L`); null before the first profile.
var current_values: LightingProfile
## Emitted on the frame a blend reaches `p = 1`.
signal blend_completed

var _blend_from: LightingProfile
var _blend_to: LightingProfile
var _blend_time: float = 0.0
var _blend_clock: Callable
var _blend_clock_start: float = 0.0
var _blend_id: StringName = &""
var _blend_tween: Tween
var _blend_p: float = 1.0


## `lighting_blend`'s `p` (GDD Formulas): `blend_time <= 0` gives 1 (mode
## entry, never NaN); otherwise `smoothstep(0, 1, clamp(t / blend_time, 0, 1))`.
static func blend_progress(t_blend: float, blend_time: float) -> float:
	if blend_time <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, clampf(t_blend / blend_time, 0.0, 1.0))


## `lighting_blend`'s `L` (GDD Formulas): every continuous parameter is
## `lerp(L_from, L_to, p)`, colors in linear space; every discrete parameter
## (the on/off flags) switches to `L_to` when `p >= 0.5`. `p >= 1` returns
## an exact copy of `to`.
static func lighting_blend(from: LightingProfile, to: LightingProfile, p: float) -> LightingProfile:
	if p >= 1.0:
		return to.duplicate() as LightingProfile
	var out := LightingProfile.new()
	for prop: Dictionary in out.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var key: StringName = StringName(prop["name"])
		var a: Variant = from.get(key)
		var b: Variant = to.get(key)
		match typeof(a):
			TYPE_FLOAT:
				out.set(key, lerpf(a, b, p))
			TYPE_VECTOR3:
				out.set(key, (a as Vector3).lerp(b, p))
			TYPE_COLOR:
				out.set(key, (a as Color).srgb_to_linear().lerp(
						(b as Color).srgb_to_linear(), p).linear_to_srgb())
			_:
				out.set(key, b if p >= 0.5 else a)
	return out


## This frame's ambient set-motion amplitudes (ADR-0005 §7; story 048):
## `cloud_scroll`, `foliage_sway`, `water_ripple`, `particle_drift` from
## `config`, all 0 with Reduce Motion On (read live from
## `presentation_settings`; null reads as Off). Amplitudes only: the
## `mode_time` clock that drives them, lighting blends and sprite frames
## keeps running either way (AC-44).
func ambient_motion(config: PresentationConfig) -> Dictionary:
	var s: float = 0.0 if _reduce_motion() else 1.0
	return {
		&"cloud_scroll": config.ambient_cloud_scroll * s,
		&"foliage_sway": config.ambient_foliage_sway * s,
		&"water_ripple": config.ambient_water_ripple * s,
		&"particle_drift": config.ambient_particle_drift * s,
	}


## The Victory confetti effect to play: the still sparkle with Reduce Motion
## On, else the animated confetti (AC-44), read live.
func victory_confetti_id(config: PresentationConfig) -> StringName:
	return config.confetti_still_effect_id if _reduce_motion() else config.confetti_effect_id


func _reduce_motion() -> bool:
	return presentation_settings != null and presentation_settings.reduce_motion


## The campfire flicker's luminance multiplier at `mode_time` (ADR-0005 §7:
## mode time, never `TIME`), from the current profile's `practical_flicker_*`
## values, reading Reduce Flashing live from `flash_settings` (AC-63). With no
## profile yet, 1.0.
func campfire_flicker_luma(mode_time: float) -> float:
	if current_values == null:
		return 1.0
	var reduce: bool = flash_settings != null and flash_settings.reduce_flashing()
	return flicker_luma(mode_time, current_values.practical_flicker_mean,
			current_values.practical_flicker_swing, current_values.practical_flicker_rate, reduce)


## `mean + 0.5 * swing * s * w(t)`, with `w` a two-partial wave normalised to
## [-1, 1] (peak-to-peak never above `swing`) and `s` =
## `PresentationConfig.REDUCED_FLICKER_FACTOR` with Reduce Flashing On, else 1.
## Reduce Flashing scales the swing only: the mean and frequency are unchanged.
static func flicker_luma(t: float, mean: float, swing: float, rate: float,
		reduce_flashing: bool) -> float:
	if swing <= 0.0 or rate <= 0.0:
		return mean
	var s: float = PresentationConfig.REDUCED_FLICKER_FACTOR if reduce_flashing else 1.0
	var phase: float = TAU * rate * t
	var w: float = (sin(phase) + _FLICKER_WEIGHT_2 * sin(phase * _FLICKER_RATIO_2 + _FLICKER_PHASE_2)) \
			/ (1.0 + _FLICKER_WEIGHT_2)
	return mean + 0.5 * swing * s * w


## Whether a blend is still running (`p < 1`).
func is_blending() -> bool:
	return _blend_p < 1.0


## The current blend's `p`.
func blend_p() -> float:
	return _blend_p


## Re-evaluates a clock-driven blend from its clock (called every frame by
## `_process`; public so tests can drive frames). A no-op otherwise.
func refresh_clock_blend() -> void:
	if _blend_clock.is_valid() and is_blending():
		_set_blend_t(float(_blend_clock.call()) - _blend_clock_start)


func _process(_delta: float) -> void:
	refresh_clock_blend()


## Starts a blend from the values on stage now (`L_from` is captured, so a
## blend requested mid-blend starts from the current values, never the old
## target) toward `profile`.
func _start_blend(profile: LightingProfile, blend_time: float, clock: Callable) -> void:
	if _blend_tween != null:
		_blend_tween.kill()
		_blend_tween = null
	_blend_from = current_values if current_values != null else profile
	_blend_to = profile
	_blend_time = blend_time
	_blend_clock = clock
	_blend_clock_start = float(clock.call()) if clock.is_valid() else 0.0
	_blend_p = 0.0
	_set_blend_t(0.0)
	if is_blending() and not clock.is_valid():
		_blend_tween = create_tween()
		_blend_tween.tween_method(_set_blend_t, 0.0, blend_time, blend_time)


func _set_blend_t(t_blend: float) -> void:
	_blend_p = blend_progress(t_blend, _blend_time)
	current_values = lighting_blend(_blend_from, _blend_to, _blend_p)
	_apply_values(current_values)
	if _blend_p >= 1.0:
		_blend_clock = Callable()
		blend_completed.emit()


func _apply_values(profile: LightingProfile) -> void:
	if key_light != null:
		key_light.light_color = profile.key_color
		key_light.light_energy = profile.key_energy
		key_light.rotation_degrees = profile.key_rotation_deg
	if set_light != null:
		set_light.light_color = profile.set_color
		set_light.light_energy = profile.set_energy
	if fill_light != null:
		fill_light.light_color = profile.fill_color
		fill_light.light_energy = profile.fill_energy
	current_rim_color = profile.rim_color
	current_rim_strength = profile.rim_strength
