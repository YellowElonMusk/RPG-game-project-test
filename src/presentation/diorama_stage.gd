## The lighting rig a 3D mode scene owns (ADR-0005 Decision §3, abridged here
## to the key/rim/set/fill setup Story 003's AC needs). Camera, sky card and
## the `active_diorama_stage` group membership are later stories' scope
## (§6 camera stories, the capture tool's sky card, ADR §3's `mode_entered`
## wiring) -- this file only owns the light rig and the profile pipeline.
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


func _ready() -> void:
	_configure_light_rig()


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


## Resolves `id` through the bound resolver and applies it (the owning mode's
## call, never the Director's -- ADR-0005 §3 "one door"). `clock` and the
## blend itself belong to Story 009/026; this story applies the profile's
## final values immediately.
## TODO(sprite-camera-presentation): tween/clock-driven blending over
## `blend_time` lands in Story 009 (lighting_blend) and Story 026 (the exact
## formula) -- accepted here so the call shape matches ADR-0005 §3 now.
func request_profile(id: StringName, blend_time: float, clock: Callable = Callable()) -> void:
	if not _resolver.is_valid():
		push_error("DioramaStage: request_profile() called before bind_profiles()")
		return
	var profile: LightingProfile = _resolver.call(id)
	if profile == null:
		push_error("DioramaStage: unknown lighting profile '%s'" % id)
		return
	apply_profile(profile, blend_time)


## Applies `profile`'s light and rim values to the rig (the Director's call
## only -- ADR-0005 §3). Cull masks, shadow casters and the set light's angle
## are never touched here (`_configure_light_rig()`'s job).
func apply_profile(profile: LightingProfile, _blend_time: float) -> void:
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
