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


## Joins `GROUP` (ADR-0005 §3) so `PresentationDirector` can find this stage
## on `mode_entered`, including re-entry (e.g. the Overworld re-attached after
## a Battle retreat).
## TODO(sprite-camera-presentation): `camera.current = true` also belongs here
## (ADR-0005 §3) once this file gains a `camera` export -- a §6 camera
## story's scope, not Story 008's.
func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_configure_light_rig()


func _exit_tree() -> void:
	remove_from_group(GROUP)


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
		push_error("DioramaStage: unknown lighting profile '%s'" % id)
		return
	_start_blend(profile, blend_time, clock)


## Applies `profile` over `blend_time` (the Director's call only, on mode
## entry with `blend_time = 0`, which gives `p = 1` on the first frame --
## ADR-0005 §3). Cull masks, shadow casters and the set light's angle are
## never touched here (`_configure_light_rig()`'s job).
func apply_profile(profile: LightingProfile, blend_time: float) -> void:
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
