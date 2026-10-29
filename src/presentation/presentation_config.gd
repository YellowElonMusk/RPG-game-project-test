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
