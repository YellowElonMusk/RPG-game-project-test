## One named lighting/tone/DOF state for a `DioramaStage` (ADR-0005 Decision
## §5, Key Interfaces `lighting_profile.gd`). Data plus pure audit helpers
## (story 019's AC-16 checks), no runtime behaviour; load-time validation (`glow_bloom == 0`, `dof_near_enabled ==
## false` in the battle family, etc.) is `PresentationValidators`' job
## (§9, a later story), not this resource's.
##
## `.tres` instances ship under `data/presentation/profiles/` with the MVP
## IDs from §5: `title`, `overworld`, `battle`, `boss_bureaucratia`,
## `boss_megacorp`, `camp`, `victory`, `defeat`. Every `boss_<faction>`
## instance's `key_color` and `rim_color` equal `battle`'s by construction
## (Story 003 AC-1) -- the dusk flood swatch lives in the sky/set/fill fields
## only, never the actor key or rim.
class_name LightingProfile
extends Resource

## The actor key light's color. Never tinted by a boss flood (Story 003 AC-1).
@export var key_color: Color = Color.WHITE
## The actor key light's energy.
@export var key_energy: float = 1.0
## The actor key light's fixed aim. Safe to author per profile: the key
## never casts shadows (ADR-0005 §3), so there is no shadow-popping risk.
@export var key_rotation_deg: Vector3 = Vector3.ZERO

## The set light's color. The set light's angle is never profile data --
## the diorama's sun direction is authored per stage (ADR-0005 §5).
@export var set_color: Color = Color.WHITE
## The set light's energy. The set:fill key:fill ratio is this over `fill_energy`.
@export var set_energy: float = 1.0

## The fill light's color.
@export var fill_color: Color = Color.WHITE
## The fill light's energy.
@export var fill_energy: float = 1.0

## The actor rim light's color. Never tinted by a boss flood (Story 003 AC-1).
@export var rim_color: Color = Color.WHITE
## The actor rim light's strength. Must be above 0 in every shipped preset
## (Story 003 AC-1) -- a rim at 0 strength is indistinguishable from no rim.
@export var rim_strength: float = 0.0

## Sky card vertical gradient, top stop.
@export var sky_top: Color = Color.BLACK
## Sky card vertical gradient, bottom stop.
@export var sky_bottom: Color = Color.BLACK
## Sky card horizon band color. A `boss_<faction>` profile's dusk flood lives here.
@export var sky_horizon: Color = Color.BLACK
## Sky card horizon band width, in the card shader's own units.
@export var sky_horizon_width: float = 0.0
## Sky card horizon band intensity.
@export var sky_horizon_intensity: float = 0.0
## Sky card overall energy scale.
@export var sky_energy: float = 1.0

## `CameraAttributesPractical`/`Environment` exposure.
@export var exposure: float = 1.0
## AgX tonemapper white point.
@export var agx_white: float = 1.0
## AgX tonemapper contrast.
@export var agx_contrast: float = 1.0

## Glow intensity.
@export var glow_intensity: float = 0.0
## Glow threshold. Required (validated non-zero by `PresentationValidators`).
@export var glow_threshold: float = 1.0
## Glow bloom. Must be 0 in every profile (validated by `PresentationValidators`).
@export var glow_bloom: float = 0.0

## Far depth of field enabled.
@export var dof_far_enabled: bool = false
## Far depth of field distance.
@export var dof_far_distance: float = 0.0
## Far depth of field blur amount.
@export var dof_amount: float = 0.0
## Near depth of field enabled. False in every battle-family profile (GDD
## rule 2); may be true in an overworld profile (ADR-0005 §14).
@export var dof_near_enabled: bool = false
## Near depth of field distance (`CameraAttributesPractical.dof_blur_near_distance`).
@export var dof_near_distance: float = 0.0
## Near depth of field transition range.
@export var dof_near_transition: float = 0.0
## Far depth of field transition range.
@export var dof_far_transition: float = 0.0

## §14 interior travelling light enabled. The light always exists on the
## stage; this toggles its energy, not its presence.
@export var travel_light_enabled: bool = false
## §14 interior travelling light color.
@export var travel_light_color: Color = Color.WHITE
## §14 interior travelling light energy (0 when `travel_light_enabled` is false).
@export var travel_light_energy: float = 0.0
## §14 interior travelling light range.
@export var travel_light_range: float = 0.0
## §14 interior travelling light shadow casting. Fixed per profile, never
## changed at runtime.
@export var travel_light_shadow: bool = false

## Blob shadow tint (ADR-0005 §3).
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)

## The actor-lighting practical's (the campfire's) flicker (ADR-0005 §3/§7;
## story 068): its luminance multiplier on mode time. The mean level.
@export var practical_flicker_mean: float = 1.0
## Peak-to-peak luminance swing around the mean; 0 = no flicker. Must stay
## below `flash_luma_delta` (GDD `flash_gate`, "exempt by swing").
## Halved with Reduce Flashing On (AC-63).
@export var practical_flicker_swing: float = 0.0
## The flicker's base frequency, in Hz of mode time.
@export var practical_flicker_rate: float = 0.0

## Default blend time when a mode requests this profile with no explicit
## `blend_time` override (ADR-0005 §3, `request_profile`).
@export var blend_time: float = 0.5


## Tolerance for "equals the config's" color checks (per channel).
const COLOR_EPSILON: float = 1e-4


## Every light color in this profile that AC-16's faction audit covers, by
## field name: the actor key and rim, the set and fill lights, and the
## interior travelling light. Sky colors are not lights (the sky card is unlit).
func light_colors() -> Dictionary:
	return {
		&"key_color": key_color,
		&"set_color": set_color,
		&"fill_color": fill_color,
		&"rim_color": rim_color,
		&"travel_light_color": travel_light_color,
	}


## Whether preset `id` may carry faction color in its light: only a boss
## takeover (`boss_*`) or an occupied overworld stage (`occupied_*`) (GDD rule 11).
static func is_faction_light_preset(id: String) -> bool:
	return id.begins_with("boss_") or id.begins_with("occupied_")


## AC-16's squad check (story 019): the profile's rim color equals the
## config's `squad_rim_color` within `COLOR_EPSILON`. One error per breach,
## naming `id`; empty means it passes. Outline Ink is not profile data at all,
## so no profile can vary it.
static func squad_look_errors(id: String, profile: LightingProfile,
		config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _colors_equal(profile.rim_color, config.squad_rim_color):
		errors.append("%s: rim_color %s differs from the squad rim %s" % [
				id, profile.rim_color, config.squad_rim_color])
	return errors


## AC-16's faction audit (story 019): outside `boss_*`/`occupied_*`, no light
## color within `config.faction_light_de_min` (CIEDE2000) of any signature
## color; in every preset, `shadow_color` at least that far from each.
## `signature_colors` maps a faction id to its signature `Color`. One error
## per breach; empty means the preset passes.
static func faction_color_errors(id: String, profile: LightingProfile,
		signature_colors: Dictionary, config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var de_min: float = config.faction_light_de_min
	for faction: Variant in signature_colors:
		var signature: Color = signature_colors[faction]
		if not is_faction_light_preset(id):
			var lights: Dictionary = profile.light_colors()
			for field: Variant in lights:
				var de: float = ColorDifference.delta_e_srgb(lights[field], signature)
				if de < de_min:
					errors.append("%s: %s is ΔE %.2f from %s's signature color (min %.1f)" % [
							id, field, de, faction, de_min])
		var shadow_de: float = ColorDifference.delta_e_srgb(profile.shadow_color, signature)
		if shadow_de < de_min:
			errors.append("%s: shadow_color is ΔE %.2f from %s's signature color (min %.1f)" % [
					id, shadow_de, faction, de_min])
	return errors


static func _colors_equal(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOR_EPSILON and absf(a.g - b.g) <= COLOR_EPSILON \
			and absf(a.b - b.b) <= COLOR_EPSILON and absf(a.a - b.a) <= COLOR_EPSILON
