## Story 005, AC-3: a `no_mirror` animation on the mirrored side uses its
## authored `<id>_<facing>_mirrored` clip instead of the shader flip, while
## the same set's unflagged animations still mirror by the shader flip.
## Drives `CharacterSprite.show_frame()` directly (ADR-0005 §1) against a
## real `sprite_actor.gdshader` material, so the shader this story also
## builds is exercised through the one door that ever touches it.
extends GdUnitTestSuite

const CharacterSprite := preload("res://src/presentation/character_sprite.gd")
const PresentationConfig := preload("res://src/presentation/presentation_config.gd")
const _SHADER := preload("res://src/presentation/shaders/sprite_actor.gdshader")

## (mirrored, no_mirror, expected_animation_suffix, expected_flip_h).
const _MIRROR_CASES: Array = [
	[true, true, "_mirrored", false],
	[false, true, "", false],
	[true, false, "", true],
	[false, false, "", false],
]


## A `CharacterSprite` wired the way `character_sprite.tscn` would: the
## real shader on `material_override` (carried over by `setup()`), a
## `SpriteFrames` with both the plain and `_mirrored` clips, and a camera
## so `_update_shader_uniforms()` has what it needs.
func _build_sprite() -> CharacterSprite:
	var sprite: CharacterSprite = CharacterSprite.new()
	add_child(sprite)
	auto_free(sprite)

	var material := ShaderMaterial.new()
	material.shader = _SHADER
	sprite.material_override = material
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	sprite.card_camera = camera

	var frames := SpriteFrames.new()
	var tex: Texture2D = ImageTexture.create_from_image(
			Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for anim_id: StringName in [&"wave_front", &"wave_front_mirrored", &"idle_front"]:
		frames.add_animation(anim_id)
		frames.add_frame(anim_id, tex)

	sprite.setup(frames, PresentationConfig.new())
	return sprite


func test_show_frame_resolves_animation_and_flip_per_no_mirror_rule(
		mirrored: bool, no_mirror: bool, suffix: String, expected_flip: bool,
		test_parameters := _MIRROR_CASES) -> void:
	var sprite: CharacterSprite = _build_sprite()

	sprite.show_frame(&"wave", &"front", mirrored, no_mirror, 0)

	assert_str(String(sprite.animation)).is_equal("wave_front%s" % suffix)
	var material: ShaderMaterial = sprite.material_override as ShaderMaterial
	assert_bool(material.get_shader_parameter(&"flip_h")).is_equal(expected_flip)


## The AC's own wording: a `no_mirror` animation on the mirrored side uses
## its authored art and is not mirrored, while the same set's unflagged
## `idle` still mirrors by the shader flip.
func test_no_mirror_animation_authored_while_unflagged_animation_in_same_set_still_flips() -> void:
	var sprite: CharacterSprite = _build_sprite()
	var material: ShaderMaterial = sprite.material_override as ShaderMaterial

	sprite.show_frame(&"wave", &"front", true, true, 0)
	assert_str(String(sprite.animation)).is_equal("wave_front_mirrored")
	assert_bool(material.get_shader_parameter(&"flip_h")).is_false()

	sprite.show_frame(&"idle", &"front", true, false, 0)
	assert_str(String(sprite.animation)).is_equal("idle_front")
	assert_bool(material.get_shader_parameter(&"flip_h")).is_true()


## Glue the shader needs to render anything at all: `show_frame()` sets the
## shader's `frame_tex` uniform to the resolved animation's current frame
## (ADR-0005 §1: "it sets the frame texture uniform in the same call").
func test_show_frame_sets_frame_texture_uniform_to_current_frame() -> void:
	var sprite: CharacterSprite = _build_sprite()
	var material: ShaderMaterial = sprite.material_override as ShaderMaterial

	sprite.show_frame(&"wave", &"front", false, false, 0)

	var expected_tex: Texture2D = sprite.sprite_frames.get_frame_texture(&"wave_front", 0)
	assert_bool(is_same(material.get_shader_parameter(&"frame_tex"), expected_tex)).is_true()
