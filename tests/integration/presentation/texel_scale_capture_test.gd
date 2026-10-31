## Story 039 (GDD sprite-camera-presentation AC-35; ADR-0005 §2, §13): the
## whole-pixel texel measurement the windowed capture
## (`tools/capture/texel_scale_capture.gd`) relies on, and the shipped art
## put through it headless.
##
## `TexelGridCheck.check_sprite()` takes one sprite's frame, its
## `SpriteProjection` rectangle, `T`, its ID-pass image and a colour pass, and
## counts every way a texel can fail to be a whole `T x T` block of one
## colour on the expected grid. The shipped cases render each shipped sprite
## set's frames with the actor shader's own fragment rule (texel UV from
## `FRAGCOORD` and `sprite_rect`, nearest sampling, alpha cut at 0.5) at every
## AC-35 resolution, with `T` from the shipped config, so a change that broke
## the rule or the art's alpha would fail here before a capture is run.
extends GdUnitTestSuite

const ID_ACTOR := Color8(0, 0, 128)
const BG := Color8(0, 0, 0)


## A small frame: an opaque 3x4 body with two colours, transparent margin.
func _frame() -> Image:
	var img := Image.create(5, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(1, 1, 3, 4), Color8(200, 40, 40))
	img.fill_rect(Rect2i(1, 1, 3, 1), Color8(26, 20, 24))
	img.set_pixel(2, 3, Color8(240, 220, 90))
	return img


## The actor shader's fragment rule on the CPU: every pixel of `rect` samples
## the texel at `floor(((px + 0.5) - rect.pos) / rect.size * frame_size)`
## (mirrored when `flip`), and is drawn only where its alpha passes 0.5.
## Returns `{"id": Image, "colour": Image}` of `size`.
func _render(frame: Image, rect: Rect2i, flip: bool, size: Vector2i) -> Dictionary:
	var id_img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var colour := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	id_img.fill(BG)
	colour.fill(BG)
	var fw: int = frame.get_width()
	var fh: int = frame.get_height()
	var area: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, size))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var uv := Vector2((float(x) + 0.5 - rect.position.x) / rect.size.x,
					(float(y) + 0.5 - rect.position.y) / rect.size.y)
			if flip:
				uv.x = 1.0 - uv.x
			var c: Color = frame.get_pixel(mini(floori(uv.x * fw), fw - 1), mini(floori(uv.y * fh), fh - 1))
			if c.a > 0.5:
				id_img.set_pixel(x, y, ID_ACTOR)
				colour.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	return {"id": id_img, "colour": colour}


func _check(frame: Image, rect: Rect2i, t: int, flip: bool, size: Vector2i) -> Dictionary:
	var r: Dictionary = _render(frame, rect, flip, size)
	return TexelGridCheck.check_sprite(frame, rect, t, flip, r["id"], ID_ACTOR, r["colour"])


func test_an_exact_t_scaled_quad_is_whole_uniform_blocks_of_size_t() -> void:
	# Arrange: T = 3, quad = frame * 3 on whole pixels.
	var f: Image = _frame()
	# Act
	var m: Dictionary = _check(f, Rect2i(10, 7, 15, 18), 3, false, Vector2i(40, 32))
	# Assert
	assert_int(int(m["opaque_texels"])).is_equal(12)
	var faults: int = int(m["split"]) + int(m["bleed"]) + int(m["outside"]) + int(m["stray"]) \
			+ int(m["nonuniform"]) + int(m["inconsistent"])
	assert_int(faults).is_equal(0)
	assert_that(m["block"]).is_equal(Vector2i(3, 3))
	assert_float(float(m["max_spread"])).is_equal(0.0)
	assert_bool(TexelGridCheck.whole_pixel_verdict({"near": m}, 3)["pass"]).is_true()


func test_a_mirrored_quad_passes_against_the_mirrored_grid() -> void:
	var m: Dictionary = _check(_frame(), Rect2i(4, 2, 10, 12), 2, true, Vector2i(24, 20))
	assert_int(int(m["split"]) + int(m["bleed"]) + int(m["inconsistent"])).is_equal(0)
	assert_that(m["block"]).is_equal(Vector2i(2, 2))


func test_a_world_scaled_quad_with_a_non_integer_scale_splits_texels() -> void:
	# Rule-2 regression: a quad 17 px wide for a 5-texel frame (3.4 px/texel).
	var f: Image = _frame()
	var r: Dictionary = _render(f, Rect2i(10, 7, 17, 18), false, Vector2i(40, 32))
	var m: Dictionary = TexelGridCheck.check_sprite(f, Rect2i(10, 7, 15, 18), 3, false, r["id"], ID_ACTOR, r["colour"])
	assert_int(int(m["split"]) + int(m["bleed"]) + int(m["stray"]) + int(m["inconsistent"])).is_greater(0)
	assert_bool(TexelGridCheck.whole_pixel_verdict({"near": m}, 3)["pass"]).is_false()


func test_a_quad_one_pixel_off_its_expected_grid_fails() -> void:
	var f: Image = _frame()
	var r: Dictionary = _render(f, Rect2i(11, 7, 15, 18), false, Vector2i(40, 32))
	var m: Dictionary = TexelGridCheck.check_sprite(f, Rect2i(10, 7, 15, 18), 3, false, r["id"], ID_ACTOR, r["colour"])
	assert_int(int(m["split"]) + int(m["bleed"]) + int(m["stray"])).is_greater(0)
	assert_bool(TexelGridCheck.whole_pixel_verdict({"near": m}, 3)["pass"]).is_false()


func test_a_blended_texel_is_counted_nonuniform_and_its_spread_measured() -> void:
	var f: Image = _frame()
	var r: Dictionary = _render(f, Rect2i(10, 7, 15, 18), false, Vector2i(40, 32))
	var colour: Image = r["colour"]
	colour.set_pixel(14, 17, Color8(120, 60, 60))  # one pixel of texel (1, 3)'s block
	var m: Dictionary = TexelGridCheck.check_sprite(f, Rect2i(10, 7, 15, 18), 3, false, r["id"], ID_ACTOR, colour)
	assert_int(int(m["nonuniform"])).is_equal(1)
	assert_float(float(m["max_spread"])).is_greater(TexelGridCheck.LIT_SPREAD_MAX)
	assert_bool(TexelGridCheck.whole_pixel_verdict({"near": m}, 3)["pass"]).is_false()
	assert_bool(TexelGridCheck.lit_spread_verdict({"near": m})["pass"]).is_false()


func test_a_slight_lighting_gradient_inside_a_block_passes_the_lit_spread_only() -> void:
	var f: Image = _frame()
	var r: Dictionary = _render(f, Rect2i(10, 7, 15, 18), false, Vector2i(40, 32))
	var colour: Image = r["colour"]
	colour.set_pixel(14, 17, Color8(201, 41, 40))
	var m: Dictionary = TexelGridCheck.check_sprite(f, Rect2i(10, 7, 15, 18), 3, false, r["id"], ID_ACTOR, colour)
	assert_float(float(m["max_spread"])).is_greater(0.0)
	assert_bool(TexelGridCheck.lit_spread_verdict({"near": m})["pass"]).is_true()


func test_near_and_far_blocks_of_different_sizes_fail_the_verdict() -> void:
	var f: Image = _frame()
	var near: Dictionary = _check(f, Rect2i(2, 2, 15, 18), 3, false, Vector2i(48, 32))
	var far: Dictionary = _check(f, Rect2i(26, 2, 10, 12), 2, false, Vector2i(48, 32))
	var v: Dictionary = TexelGridCheck.whole_pixel_verdict({"near": near, "far": far}, 3)
	assert_bool(v["pass"]).is_false()


func test_a_sprite_past_the_frame_edge_and_a_clear_pixel_fail_coverage() -> void:
	var f: Image = _frame()
	var inside: Dictionary = _check(f, Rect2i(10, 7, 15, 18), 3, false, Vector2i(40, 32))
	var clipped: Dictionary = _check(f, Rect2i(30, 7, 15, 18), 3, false, Vector2i(40, 32))
	assert_int(int(clipped["outside"])).is_greater(0)
	assert_bool(TexelGridCheck.coverage_verdict(0, {"a": inside})["pass"]).is_true()
	assert_bool(TexelGridCheck.coverage_verdict(0, {"a": inside, "b": clipped})["pass"]).is_false()
	assert_bool(TexelGridCheck.coverage_verdict(12, {"a": inside})["pass"]).is_false()


func test_an_actor_inside_the_frame_with_a_texel_hidden_by_the_set_passes_coverage_only() -> void:
	# Coverage is about the frame's bounds; a texel the set covers (the feet
	# under a pitched camera) is AC-35's [VF] "cutting into the set", not a
	# clipped silhouette, and is still a whole-pixel failure.
	var f: Image = _frame()
	var r: Dictionary = _render(f, Rect2i(10, 7, 15, 18), false, Vector2i(40, 32))
	var id_img: Image = r["id"]
	id_img.fill_rect(Rect2i(10, 21, 15, 1), Color8(0, 0, 255))  # bottom pixel row is set
	var m: Dictionary = TexelGridCheck.check_sprite(f, Rect2i(10, 7, 15, 18), 3, false, id_img, ID_ACTOR, r["colour"])
	assert_int(int(m["split"])).is_equal(3)
	assert_bool(TexelGridCheck.coverage_verdict(0, {"a": m})["pass"]).is_true()
	assert_bool(TexelGridCheck.whole_pixel_verdict({"a": m}, 3)["pass"]).is_false()


func test_a_flat_colour_pass_of_a_many_coloured_sprite_is_vacuous_and_fails() -> void:
	# The engine's DEBUG_DRAW_UNSHADED draws the actor card black: every block
	# is then "one colour" without proving anything.
	var f: Image = _frame()
	var r: Dictionary = _render(f, Rect2i(10, 7, 15, 18), false, Vector2i(40, 32))
	var black := Image.create(40, 32, false, Image.FORMAT_RGBA8)
	black.fill(Color.BLACK)
	var m: Dictionary = TexelGridCheck.check_sprite(f, Rect2i(10, 7, 15, 18), 3, false, r["id"], ID_ACTOR, black)
	assert_int(int(m["nonuniform"]) + int(m["inconsistent"])).is_equal(0)
	assert_bool(TexelGridCheck.whole_pixel_verdict({"a": m}, 3)["pass"]).is_false()


func test_an_empty_measurement_never_passes_vacuously() -> void:
	var nothing := Image.create(40, 32, false, Image.FORMAT_RGBA8)
	var m: Dictionary = TexelGridCheck.check_sprite(_frame(), Rect2i(10, 7, 15, 18), 3, false, nothing, ID_ACTOR, nothing)
	assert_bool(TexelGridCheck.whole_pixel_verdict({"a": m}, 3)["pass"]).is_false()
	assert_bool(TexelGridCheck.whole_pixel_verdict({}, 3)["pass"]).is_false()
	assert_bool(TexelGridCheck.coverage_verdict(0, {})["pass"]).is_false()


func test_every_shipped_sprite_frame_is_whole_blocks_at_every_ac35_resolution() -> void:
	# Arrange: the shipped config's texel_base_lines and every shipped set's
	# idle frame 0 in each facing it ships, near the frame's corner.
	var cfg: PresentationConfig = PresentationValidators.load_config()
	var sets: Dictionary = PresentationValidators.load_sprite_sets()
	assert_int(sets.size()).is_greater(0)
	for size: Vector2i in TexelGridCheck.WHOLE_PIXEL_SIZES:
		var t: int = SpriteProjection.texel_scale(size.y, cfg.texel_base_lines)
		var results: Dictionary = {}
		for set_id: StringName in sets:
			var s: SpriteSetData = sets[set_id]
			for facing: StringName in s.facings_used:
				var anim: SpriteAnimationData = s.find(&"idle", facing)
				if anim == null or anim.strip == null:
					continue
				var frame: Image = anim.strip.get_image().get_region(anim.frame_region(0))
				frame.convert(Image.FORMAT_RGBA8)
				var fs: Vector2i = frame.get_size()
				# Corner placement: one pixel in from the bottom-right corner.
				var rect := Rect2i(fs.x * 3 * t + 1 - fs.x * t, 1, fs.x * t, fs.y * t)
				var canvas := Vector2i(rect.end.x + 1, rect.end.y + 1)
				results["%s_%s" % [set_id, facing]] = _check(frame, rect, t, facing == &"back", canvas)
		# Act
		var v: Dictionary = TexelGridCheck.whole_pixel_verdict(results, t)
		# Assert
		assert_bool(v["pass"]).override_failure_message("%s: %s" % [size, v["failures"]]).is_true()
