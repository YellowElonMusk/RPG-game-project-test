## The single door through which Presentation writes a global shader uniform
## (ADR-0005 Decision §4, Key Interfaces `global_uniform_sink.gd`). Nothing
## else may call `RenderingServer.global_shader_parameter_set()` directly,
## and nothing may read a global back from `RenderingServer` at all --
## `global_shader_parameter_get()` returns `null` at runtime on 4.7.2
## (observed, ADR-0005 §4), so there is no readback path here either.
##
## This base class IS the production sink: it writes straight through to
## `RenderingServer`. A test double subclasses and overrides `set_global()`
## to record instead of writing a real global (the same shape as
## `SceneLoader`'s pattern in `src/game_state/scene_loader.gd`).
##
## TODO(sprite-camera-presentation): `PresentationDirector` does not call
## this yet -- the per-frame `mode_time`/`actor_rim_color`/
## `actor_rim_strength` writes are story 010's scope
## (menu-freeze-stops-every-presentation-clock). This story only wires the
## constructor-injected reference through `PresentationDirector.setup()` so
## the shape matches ADR-0005 §4 now.
class_name GlobalUniformSink extends RefCounted


## Writes one global shader uniform. The production default calls
## `RenderingServer.global_shader_parameter_set()`; a test double overrides
## this to record `name`/`value` instead.
func set_global(name: StringName, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(name, value)
