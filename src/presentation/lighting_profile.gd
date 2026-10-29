## One named lighting/tone/DOF state for a `DioramaStage` (ADR-0005 Decision
## §5, Key Interfaces `lighting_profile.gd`). Data only -- no methods, no
## validation; load-time validation (`glow_bloom == 0`, `dof_near_enabled ==
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

## Default blend time when a mode requests this profile with no explicit
## `blend_time` override (ADR-0005 §3, `request_profile`).
@export var blend_time: float = 0.5
