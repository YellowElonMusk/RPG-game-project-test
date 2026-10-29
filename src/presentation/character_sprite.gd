## Per-sprite integration of `SpriteProjection`'s pure math (ADR-0005
## Decision §1-2): owns the `AnimatedSprite3D` node and its own
## `ShaderMaterial` instance (one per sprite -- a sampler can't be an
## `instance uniform`), and keeps that material's uniforms equal to
## `SpriteProjection`'s direct output on every frame (AC-2). `node scale`
## stays `(1, 1, 1)` and the node is never rotated (§1), before, during and
## after a hit-punch and a replay.
##
## Mirroring (`no_mirror` animation substitution) is Story 005's scope --
## this story always flips via the `flip_h` shader uniform. Authoring the
## actual `sprite_actor.gdshader` (vertex/fragment, rim, lighting) is
## `godot-shader-specialist`'s domain; this script only assigns
## `material_override` and calls `set_shader_parameter()`.
class_name CharacterSprite
extends AnimatedSprite3D

## The stage's upright-card camera, set by the owning `DioramaStage`/mode.
## Projection uniforms are skipped (logged once) while this is null.
@export var card_camera: Camera3D

var _config: PresentationConfig
var _material: ShaderMaterial
var _mirrored: bool = false
var _warned_no_camera: bool = false


## Assigns `sprite_frames`, creates this sprite's own `ShaderMaterial`
## instance (carrying over any shader already authored on
## `material_override`), resets node transform and stops playback.
## `stop()` resets `frame` to 0 (probed 4.7.2, ADR-0005 §1) -- called
## exactly ONCE here, never again while frames are stepped.
func setup(frames: SpriteFrames, config: PresentationConfig) -> void:
	sprite_frames = frames
	_config = config
	var existing_shader: Shader = null
	if material_override is ShaderMaterial:
		existing_shader = (material_override as ShaderMaterial).shader
	_material = ShaderMaterial.new()
	_material.shader = existing_shader
	material_override = _material
	scale = Vector3.ONE
	rotation = Vector3.ZERO
	stop()


## Sets a beat-driven frame (ADR-0006 clocks): `animation` only when it
## changes, THEN `frame` via `set_frame_and_progress`, AND the frame
## texture uniform, all in this one call (ADR-0005 §1 call order).
func show_frame(animation_id: StringName, facing: StringName, mirrored: bool, frame: int) -> void:
	var resolved: StringName = StringName("%s_%s" % [animation_id, facing])
	if animation != resolved:
		animation = resolved
	set_frame_and_progress(frame, 0.0)
	_mirrored = mirrored
	_update_shader_uniforms()


## Steps ambient (idle/walk) frames on mode time; beat-driven frames always
## come from `show_frame()`, never from this node's own playback (§1).
func step_ambient(_mode_dt: float) -> void:
	_update_shader_uniforms()


## Returns the sprite to its idle frame (on `BattleReplayController.display_resynced`).
func reset_to_idle() -> void:
	set_frame_and_progress(0, 0.0)
	_update_shader_uniforms()


## Recomputes this frame's projection through `SpriteProjection` and writes
## the shader uniforms it feeds (AC-2: these equal `SpriteProjection`'s
## direct output on every frame).
func _update_shader_uniforms() -> void:
	if _material == null or _config == null:
		return
	if card_camera == null:
		if not _warned_no_camera:
			push_warning("CharacterSprite: card_camera not set, skipping projection uniforms")
			_warned_no_camera = true
		return
	var viewport_size: Vector2i = get_viewport().size
	var cam_state: SpriteProjection.CameraState = SpriteProjection.CameraState.from_camera3d(
			card_camera, viewport_size)
	var frame_size: Vector2i = _current_frame_size()
	var rect: Rect2i = SpriteProjection.screen_rect(
			global_position, cam_state, frame_size, viewport_size, _config.texel_base_lines)
	var normal: Vector3 = SpriteProjection.card_normal(cam_state)
	_material.set_shader_parameter(&"sprite_rect", Rect2(rect))
	_material.set_shader_parameter(&"viewport_size", Vector2(viewport_size))
	_material.set_shader_parameter(&"foot_anchor", global_position)
	_material.set_shader_parameter(&"card_normal", normal)
	_material.set_shader_parameter(&"flip_h", _mirrored)


## The current animation frame's texel size, read from its `Texture2D`.
func _current_frame_size() -> Vector2i:
	if sprite_frames == null or animation == &"" or not sprite_frames.has_animation(animation):
		return Vector2i.ZERO
	var tex: Texture2D = sprite_frames.get_frame_texture(animation, frame)
	if tex == null:
		return Vector2i.ZERO
	return tex.get_size()
