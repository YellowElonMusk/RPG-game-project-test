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
## Mode time spent in the current ambient animation (`step_ambient`).
var _ambient_time: float = 0.0


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
	# Rule 12: actors cast no light shadows; their blob is their only shadow.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3.ONE
	rotation = Vector3.ZERO
	stop()


## Sets a beat-driven frame (ADR-0006 clocks): `animation` only when it
## changes, THEN `frame` via `set_frame_and_progress`, AND the frame
## texture uniform, all in this one call (ADR-0005 §1 call order).
## `no_mirror` is the animation's own flag (ADR-0005 §1, Story 005 AC-3):
## WHEN both `mirrored` and `no_mirror` are true, the authored
## `<animation_id>_<facing>_mirrored` clip is used in place of the shader
## flip, and the shader's `flip_h` uniform stays false. An unflagged
## animation always mirrors by the shader flip when `mirrored` is true,
## even within a set that has other `no_mirror` animations.
func show_frame(animation_id: StringName, facing: StringName, mirrored: bool,
		no_mirror: bool, frame: int) -> void:
	var uses_authored_mirror: bool = mirrored and no_mirror
	var suffix: String = "_mirrored" if uses_authored_mirror else ""
	var resolved: StringName = StringName("%s_%s%s" % [animation_id, facing, suffix])
	if animation != resolved:
		animation = resolved
		_ambient_time = 0.0
	set_frame_and_progress(frame, 0.0)
	_mirrored = mirrored and not no_mirror
	_update_shader_uniforms()


## Steps ambient (idle/walk) frames on mode time (ADR-0005 §1; story 011):
## the owner calls this every frame with that frame's `mode_time` delta, so
## the Menu (which stops mode time) holds the frame while Dialogue and the
## Defeat Prompt (which don't) let it advance. The frame follows the
## animation's `SpriteFrames` speed and per-frame durations, looping when
## the animation loops. Beat-driven animations are never stepped here: their
## frames always come from `show_frame()`, never this node's own playback.
func step_ambient(mode_dt: float) -> void:
	if is_ambient_animation(animation) and mode_dt > 0.0 and sprite_frames != null \
			and sprite_frames.has_animation(animation):
		_ambient_time += mode_dt
		var f: int = ambient_frame_at(sprite_frames, animation, _ambient_time)
		if f != frame:
			set_frame_and_progress(f, 0.0)
	_update_shader_uniforms()


## Whether `animation_name` (`<id>_<facing>[_mirrored]`) is ambient: idle or walk.
static func is_ambient_animation(animation_name: StringName) -> bool:
	var s: String = String(animation_name)
	return s.begins_with("idle_") or s.begins_with("walk_")


## The frame of `anim` at `t` seconds of ambient time: frames last
## `duration / speed` seconds each; a looping animation wraps, a one-shot
## holds its last frame.
static func ambient_frame_at(frames: SpriteFrames, anim: StringName, t: float) -> int:
	var count: int = frames.get_frame_count(anim)
	var speed: float = frames.get_animation_speed(anim)
	if count <= 1 or speed <= 0.0:
		return 0
	var total: float = 0.0
	for i: int in count:
		total += frames.get_frame_duration(anim, i)
	var units: float = t * speed
	if frames.get_animation_loop(anim):
		units = fmod(units, total)
	elif units >= total:
		return count - 1
	var acc: float = 0.0
	for i: int in count:
		acc += frames.get_frame_duration(anim, i)
		if units < acc - 1e-6:
			return i
	return 0 if frames.get_animation_loop(anim) else count - 1


## Returns the sprite to its idle frame (on `BattleReplayController.display_resynced`).
func reset_to_idle() -> void:
	set_frame_and_progress(0, 0.0)
	_ambient_time = 0.0
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
	# `setup()` and `show_frame()` may run before this node is in the tree
	# (mode scenes are set up before add_child), so no viewport exists yet.
	# The next update after entering the tree writes the uniforms.
	if not is_inside_tree():
		return
	var viewport_size: Vector2i = get_viewport().size
	var cam_state: SpriteProjection.CameraState = SpriteProjection.CameraState.from_camera3d(
			card_camera, viewport_size)
	var frame_tex: Texture2D = _current_frame_texture()
	var frame_size: Vector2i = frame_tex.get_size() if frame_tex != null else Vector2i.ZERO
	var rect: Rect2i = SpriteProjection.screen_rect(
			global_position, cam_state, frame_size, viewport_size, _config.texel_base_lines)
	var normal: Vector3 = SpriteProjection.card_normal(cam_state)
	_material.set_shader_parameter(&"sprite_rect", Rect2(rect))
	_material.set_shader_parameter(&"viewport_size", Vector2(viewport_size))
	_material.set_shader_parameter(&"foot_anchor", global_position)
	_material.set_shader_parameter(&"card_normal", normal)
	_material.set_shader_parameter(&"flip_h", _mirrored)
	if frame_tex != null:
		_material.set_shader_parameter(&"frame_tex", frame_tex)


## The current animation frame's `Texture2D`, or `null` before `setup()`
## or once `sprite_frames`/`animation` disagree (defensive). The shader's
## `frame_tex` uniform (ADR-0005 §2) and this node's culling bounds both
## read frame size from this, so it is fetched once per update.
func _current_frame_texture() -> Texture2D:
	if sprite_frames == null or animation == &"" or not sprite_frames.has_animation(animation):
		return null
	return sprite_frames.get_frame_texture(animation, frame)
