## Fixture environments for AC-53 (story sprite-camera-presentation 057,
## TR-presentation-024): the UI layer is never tinted by the world's
## tonemapper. Capture-only; nothing in the game uses these.
##
## The shipped battle `Environment` uses the linear tonemapper at exposure 1,
## which is the identity on the 8-bit range, so on its own it cannot show a
## tint. The fixtures put the `LightingProfile`'s tone fields (exposure, AgX
## white and contrast, ADR-0005 §5) on a copy of the world's environment with
## the AgX tonemapper, which visibly moves mid-tones:
##
##   `world_agx`         the world tonemapped by AgX, the UI left where the
##                       game draws it (above the 3D, outside the tonemapper);
##                       AC-53 must still PASS here.
##   `ui_through_world`  the negative control: the same AgX world, plus the
##                       UI canvas layers pulled into the 3D background canvas
##                       (`background_canvas_max_layer`), so the UI is drawn
##                       into the world and tonemapped with it. AC-53 must FAIL.
class_name UiTintFixture
extends RefCounted


## A copy of `base` with the AgX tonemapper and `profile`'s exposure, AgX
## white and AgX contrast. The background canvas range is left as it is.
static func world_agx(base: Environment, profile: LightingProfile) -> Environment:
	var env: Environment = base.duplicate() as Environment
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = profile.exposure
	env.tonemap_agx_white = profile.agx_white
	env.tonemap_agx_contrast = profile.agx_contrast
	return env


## The negative-control fixture: `world_agx()` with the background canvas
## extended up to `ui_max_layer` (the highest canvas layer the UI uses), so
## every UI layer is rendered as the 3D background and goes through the
## world's tonemapper.
static func ui_through_world(base: Environment, profile: LightingProfile,
		ui_max_layer: int) -> Environment:
	var env: Environment = world_agx(base, profile)
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = ui_max_layer
	return env
