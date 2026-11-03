## Stand-in overworld art: `PlaceholderActorFrames.from_sprite_set()` cuts a
## battle sprite set's idle strip into the looping `idle_down` clip the
## overworld shows, and returns null when the set has no idle in the facing
## asked for (the view then falls back to the tinted placeholder).
extends GdUnitTestSuite

const _FRAME: Vector2i = Vector2i(8, 8)
const _FRAMES: int = 4


## A set with one `idle` in `facing`: a strip of `_FRAMES` frames, frame i
## filled with grey level i / 10 so each cut can be told apart.
func _set_with_idle(facing: StringName) -> SpriteSetData:
	var img := Image.create(_FRAME.x * _FRAMES, _FRAME.y, false, Image.FORMAT_RGBA8)
	for i: int in _FRAMES:
		img.fill_rect(Rect2i(i * _FRAME.x, 0, _FRAME.x, _FRAME.y), Color(i / 10.0, i / 10.0, i / 10.0, 1.0))
	var anim := SpriteAnimationData.new()
	anim.animation_id = &"idle"
	anim.facing = facing
	anim.fps = 4.0
	anim.frame_durations = PackedFloat32Array([1, 1, 2, 1])
	anim.strip = ImageTexture.create_from_image(img)
	var sprite_set := SpriteSetData.new()
	sprite_set.facings_used = [facing]
	sprite_set.animations = [anim]
	return sprite_set


func test_idle_strip_becomes_looping_idle_down_clip() -> void:
	var frames: SpriteFrames = PlaceholderActorFrames.from_sprite_set(_set_with_idle(&"back"), &"back")
	assert_object(frames).is_not_null()
	assert_bool(frames.has_animation(PlaceholderActorFrames.IDLE_DOWN)).is_true()
	assert_int(frames.get_frame_count(PlaceholderActorFrames.IDLE_DOWN)).is_equal(_FRAMES)
	assert_bool(frames.get_animation_loop(PlaceholderActorFrames.IDLE_DOWN)).is_true()
	assert_float(frames.get_animation_speed(PlaceholderActorFrames.IDLE_DOWN)).is_equal(4.0)
	assert_float(frames.get_frame_duration(PlaceholderActorFrames.IDLE_DOWN, 2)).is_equal(2.0)
	for i: int in _FRAMES:
		var tex: Texture2D = frames.get_frame_texture(PlaceholderActorFrames.IDLE_DOWN, i)
		assert_vector(Vector2(tex.get_size())).is_equal(Vector2(_FRAME))
		assert_float(tex.get_image().get_pixel(1, 1).r).is_equal_approx(i / 10.0, 0.01)


func test_null_when_the_facing_has_no_idle() -> void:
	assert_object(PlaceholderActorFrames.from_sprite_set(_set_with_idle(&"front"), &"back")).is_null()


func test_null_for_no_set() -> void:
	assert_object(PlaceholderActorFrames.from_sprite_set(null, &"back")).is_null()
