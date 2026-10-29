## Minimal stub: only the fields `SpriteProjection`/`CharacterSprite` read
## for Story 004 (AC-2). ADR-0005 §5 defines the full `PresentationConfig`
## (profile table, sprite-set table, every GDD Tuning Knob, load
## validation) -- that full resource and its `data/config/presentation_config.tres`
## are a later story's scope; widen this file in place there rather than
## duplicating it.
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
## Camera height above the ground plane, in meters (`h`).
@export var follow_camera_height: float = 10.0
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
