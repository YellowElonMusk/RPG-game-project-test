## Story 037 (GDD sprite-camera-presentation AC-33, Visual and Animation
## Requirements "Silhouette test"; art bible Principle 1): the pure
## measurement behind the black-fill silhouette sheet. `SilhouetteLineupCheck`
## turns a frame into a black-fill mask (alpha cut only, no colour), scales it
## to battle height (`T` per texel) or fits it into a 32 px thumbnail, scores
## two silhouettes by overlap (IoU, feet-aligned), and runs the GDD's lineup
## test as a machine proxy: 3 probe poses stand in for the 3 reviewers, each
## picks the closest of a lineup of 6, and a character passes on 2 of 3.
## Synthetic images only.
extends GdUnitTestSuite

const OPAQUE := Color(0.2, 0.7, 0.1, 1.0)


func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## A frame with `rects` filled opaque.
func _frame(w: int, h: int, rects: Array[Rect2i]) -> Image:
	var img := _blank(w, h)
	for r: Rect2i in rects:
		img.fill_rect(r, OPAQUE)
	return img


func _mask(w: int, h: int, rects: Array[Rect2i]) -> Image:
	return SilhouetteLineupCheck.mask(_frame(w, h, rects))


func _count(mask: Image) -> int:
	var n: int = 0
	for y: int in mask.get_height():
		for x: int in mask.get_width():
			if mask.get_pixel(x, y).r > 0.5:
				n += 1
	return n


# --- mask -------------------------------------------------------------------

func test_mask_marks_texels_above_the_alpha_cut_and_ignores_colour() -> void:
	# Arrange: alpha 128 (kept), alpha 127 (cut), and two different colours.
	var img := _blank(4, 1)
	img.set_pixel(0, 0, Color8(255, 0, 0, 255))
	img.set_pixel(1, 0, Color8(0, 0, 255, 128))
	img.set_pixel(2, 0, Color8(0, 255, 0, 127))
	# Act
	var m: Image = SilhouetteLineupCheck.mask(img)
	# Assert
	assert_bool(m.get_pixel(0, 0).r > 0.5).is_true()
	assert_bool(m.get_pixel(1, 0).r > 0.5).is_true()
	assert_bool(m.get_pixel(2, 0).r > 0.5).is_false()
	assert_bool(m.get_pixel(3, 0).r > 0.5).is_false()


func test_opaque_bounds_is_the_tight_box_and_empty_for_a_blank_mask() -> void:
	var m: Image = _mask(10, 8, [Rect2i(2, 3, 4, 2), Rect2i(7, 1, 1, 1)])
	assert_that(SilhouetteLineupCheck.opaque_bounds(m)).is_equal(Rect2i(2, 1, 6, 4))
	assert_that(SilhouetteLineupCheck.opaque_bounds(_mask(5, 5, []))).is_equal(Rect2i())


# --- sizes ------------------------------------------------------------------

func test_battle_height_scales_every_texel_to_a_t_by_t_block() -> void:
	# Arrange: a 4x6 frame with one opaque texel at (1, 2); T = 3.
	var m: Image = _mask(4, 6, [Rect2i(1, 2, 1, 1)])
	# Act
	var big: Image = SilhouetteLineupCheck.scaled(m, 3)
	# Assert: frame * T, and the texel is exactly the block (3..5, 6..8).
	assert_that(big.get_size()).is_equal(Vector2i(12, 18))
	assert_int(_count(big)).is_equal(9)
	assert_that(SilhouetteLineupCheck.opaque_bounds(big)).is_equal(Rect2i(3, 6, 3, 3))


func test_thumbnail_fits_the_silhouette_in_32_px_keeping_its_aspect() -> void:
	# Arrange: a 16 x 64 opaque column in a 128 x 128 frame (a boss-sized frame).
	var m: Image = _mask(128, 128, [Rect2i(40, 50, 16, 64)])
	# Act
	var th: Image = SilhouetteLineupCheck.thumbnail(m)
	# Assert: longest side 32, aspect 1:4 kept, fully filled.
	assert_that(th.get_size()).is_equal(Vector2i(8, 32))
	assert_int(_count(th)).is_equal(8 * 32)


func test_thumbnail_keeps_a_pixel_only_when_at_least_half_its_area_is_filled() -> void:
	# Arrange: 64 x 64 bounds (two corner texels pin the box); a 2x2 block
	# maps to one thumbnail pixel. One block 2/4 filled, one 1/4 filled.
	var m: Image = _mask(64, 64, [Rect2i(0, 0, 1, 1), Rect2i(63, 63, 1, 1),
			Rect2i(10, 10, 2, 1), Rect2i(20, 20, 1, 1)])
	# Act
	var th: Image = SilhouetteLineupCheck.thumbnail(m)
	# Assert
	assert_that(th.get_size()).is_equal(Vector2i(32, 32))
	assert_bool(th.get_pixel(5, 5).r > 0.5).is_true()
	assert_bool(th.get_pixel(10, 10).r > 0.5).is_false()


func test_thumbnail_of_a_blank_mask_is_one_empty_pixel() -> void:
	var th: Image = SilhouetteLineupCheck.thumbnail(_mask(8, 8, []))
	assert_that(th.get_size()).is_equal(Vector2i(1, 1))
	assert_int(_count(th)).is_equal(0)


# --- overlap ----------------------------------------------------------------

func test_overlap_of_the_same_shape_anywhere_in_its_frame_is_one() -> void:
	# The silhouette is compared feet-aligned, so where the art sits in its
	# frame does not matter.
	var a: Image = _mask(20, 20, [Rect2i(2, 4, 6, 10), Rect2i(8, 4, 3, 2)])
	var b: Image = _mask(30, 24, [Rect2i(15, 12, 6, 10), Rect2i(21, 12, 3, 2)])
	assert_float(SilhouetteLineupCheck.overlap(a, b)).is_equal_approx(1.0, 0.0001)


func test_overlap_of_a_tall_and_a_wide_shape_is_their_iou_feet_aligned() -> void:
	# Arrange: 2 x 8 column and 8 x 2 slab, both bottom-centred: they share
	# a 2 x 2 square. Union = 16 + 16 - 4 = 28.
	var tall: Image = _mask(10, 10, [Rect2i(4, 1, 2, 8)])
	var wide: Image = _mask(10, 10, [Rect2i(1, 7, 8, 2)])
	# Act / Assert
	assert_float(SilhouetteLineupCheck.overlap(tall, wide)).is_equal_approx(4.0 / 28.0, 0.0001)


func test_overlap_with_a_blank_mask_is_zero() -> void:
	var a: Image = _mask(10, 10, [Rect2i(1, 1, 3, 3)])
	assert_float(SilhouetteLineupCheck.overlap(a, _mask(10, 10, []))).is_equal(0.0)


# --- lineup -----------------------------------------------------------------

## Eight distinct silhouettes keyed a..h: rectangles of growing width.
func _gallery() -> Dictionary:
	var g: Dictionary = {}
	var ids: Array[StringName] = [&"a", &"b", &"c", &"d", &"e", &"f", &"g", &"h"]
	for i: int in ids.size():
		g[ids[i]] = _mask(40, 40, [Rect2i(2, 10, 2 + i * 4, 20)])
	return g


func test_a_lineup_holds_the_character_and_its_five_closest_others() -> void:
	# Arrange
	var g: Dictionary = _gallery()
	# Act: probe = c's own silhouette.
	var r: Dictionary = SilhouetteLineupCheck.lineup(g[&"c"], g, &"c")
	# Assert: 6 entries, c among them, the two least like c (a: IoU 0.2,
	# h: 0.33) left out.
	var lineup: Array = r["lineup"]
	assert_int(lineup.size()).is_equal(SilhouetteLineupCheck.LINEUP_SIZE)
	assert_bool(lineup.has(&"c")).is_true()
	assert_bool(lineup.has(&"a")).is_false()
	assert_bool(lineup.has(&"h")).is_false()
	assert_that(r["picked"]).is_equal(&"c")
	assert_bool(r["correct"]).is_true()


func test_a_probe_closer_to_another_character_picks_it_and_is_wrong() -> void:
	# Arrange: a pose of c that is exactly d's shape.
	var g: Dictionary = _gallery()
	var pose: Image = (g[&"d"] as Image).duplicate()
	# Act
	var r: Dictionary = SilhouetteLineupCheck.lineup(pose, g, &"c")
	# Assert
	assert_that(r["picked"]).is_equal(&"d")
	assert_bool(r["correct"]).is_false()


func test_a_tie_with_another_character_is_not_a_correct_pick() -> void:
	# Arrange: two characters with identical silhouettes (grunt clones).
	var g: Dictionary = {&"x": _mask(20, 20, [Rect2i(5, 5, 6, 10)]),
			&"y": _mask(20, 20, [Rect2i(2, 2, 6, 10)])}
	# Act
	var r: Dictionary = SilhouetteLineupCheck.lineup(g[&"x"], g, &"x")
	# Assert
	assert_bool(r["correct"]).is_false()


func test_a_lineup_of_fewer_than_six_characters_uses_them_all() -> void:
	var g: Dictionary = {&"x": _mask(20, 20, [Rect2i(5, 5, 6, 10)]),
			&"y": _mask(20, 20, [Rect2i(2, 2, 12, 4)])}
	var r: Dictionary = SilhouetteLineupCheck.lineup(g[&"x"], g, &"x")
	assert_int((r["lineup"] as Array).size()).is_equal(2)
	assert_bool(r["correct"]).is_true()


func test_two_of_three_correct_probes_pass_and_one_of_three_fails() -> void:
	# Arrange
	var g: Dictionary = _gallery()
	var own: Image = g[&"c"]
	var wrong: Image = g[&"e"]
	var two: Array[Image] = [own, own, wrong]
	var one: Array[Image] = [own, wrong, wrong]
	# Act
	var pass_v: Dictionary = SilhouetteLineupCheck.character_verdict(two, g, &"c")
	var fail_v: Dictionary = SilhouetteLineupCheck.character_verdict(one, g, &"c")
	# Assert
	assert_int(int(pass_v["votes"])).is_equal(2)
	assert_bool(pass_v["pass"]).is_true()
	assert_int(int(fail_v["votes"])).is_equal(1)
	assert_bool(fail_v["pass"]).is_false()


func test_a_character_with_fewer_than_three_probes_fails() -> void:
	var g: Dictionary = _gallery()
	var probes: Array[Image] = [g[&"c"], g[&"c"]]
	assert_bool(SilhouetteLineupCheck.character_verdict(probes, g, &"c")["pass"]).is_false()


func test_the_roster_passes_only_when_every_character_passes_and_none_is_missing() -> void:
	var ok: Dictionary = {&"a": {"pass": true}, &"b": {"pass": true}}
	var bad: Dictionary = {&"a": {"pass": true}, &"b": {"pass": false}}
	assert_bool(SilhouetteLineupCheck.roster_verdict(ok)["pass"]).is_true()
	var v: Dictionary = SilhouetteLineupCheck.roster_verdict(bad)
	assert_bool(v["pass"]).is_false()
	assert_bool(str(v["failures"]).contains("b")).is_true()
	assert_bool(SilhouetteLineupCheck.roster_verdict({})["pass"]).is_false()


# --- poses from a sprite set --------------------------------------------------

func _anim(id: StringName, facing: StringName, frames: Array[Image], no_mirror: bool = false) -> SpriteAnimationData:
	var a := SpriteAnimationData.new()
	a.animation_id = id
	a.facing = facing
	a.no_mirror = no_mirror
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var strip := _blank(w * frames.size(), h)
	var durations := PackedFloat32Array()
	for i: int in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
		durations.append(1.0)
	a.frame_durations = durations
	a.strip = ImageTexture.create_from_image(strip)
	return a


func test_a_squad_set_is_shown_back_facing_in_idle_and_victory() -> void:
	# Arrange
	var s := SpriteSetData.new()
	s.set_id = &"sprite_test_squad"
	s.is_squad = true
	s.facings_used = [&"back"]
	var f0 := _frame(8, 8, [Rect2i(0, 0, 2, 8)])
	var f1 := _frame(8, 8, [Rect2i(0, 0, 4, 8)])
	s.animations.append(_anim(&"idle", &"back", [f0, f1]))
	s.animations.append(_anim(&"victory", &"back", [f1, f0, f1]))
	# Act
	var p: Dictionary = SilhouetteLineupCheck.pose_frames(s)
	# Assert
	assert_that(p["facing"]).is_equal(&"back")
	assert_that(p["poses"]).is_equal([&"idle", &"victory"])
	assert_int((p["frames"][&"idle"] as Array).size()).is_equal(2)
	assert_int((p["frames"][&"victory"] as Array).size()).is_equal(3)
	assert_bool(p["mirrored"][&"victory"]).is_false()
	assert_int((p["missing"] as PackedStringArray).size()).is_equal(0)
	# Frame 1 of victory is f0: a 2-wide column.
	var v1: Image = SilhouetteLineupCheck.mask(p["frames"][&"victory"][1])
	assert_that(SilhouetteLineupCheck.opaque_bounds(v1)).is_equal(Rect2i(0, 0, 2, 8))


func test_an_enemy_set_is_shown_front_facing_in_idle_and_attack() -> void:
	var s := SpriteSetData.new()
	s.set_id = &"sprite_test_enemy"
	var f0 := _frame(8, 8, [Rect2i(0, 0, 2, 8)])
	s.animations.append(_anim(&"idle", &"front", [f0]))
	s.animations.append(_anim(&"attack", &"front", [f0, f0]))
	var p: Dictionary = SilhouetteLineupCheck.pose_frames(s)
	assert_that(p["facing"]).is_equal(&"front")
	assert_that(p["poses"]).is_equal([&"idle", &"attack"])


func test_a_pose_authored_only_in_the_other_facing_is_shown_shader_flipped() -> void:
	# Arrange: victory exists only `front`; the squad needs `back`.
	var s := SpriteSetData.new()
	s.set_id = &"sprite_test_squad"
	s.is_squad = true
	s.facings_used = [&"back"]
	var left := _frame(8, 8, [Rect2i(0, 0, 2, 8)])
	s.animations.append(_anim(&"idle", &"back", [left]))
	s.animations.append(_anim(&"victory", &"front", [left]))
	# Act
	var p: Dictionary = SilhouetteLineupCheck.pose_frames(s)
	# Assert: mirrored, and the column moved to the right edge.
	assert_bool(p["mirrored"][&"victory"]).is_true()
	var m: Image = SilhouetteLineupCheck.mask(p["frames"][&"victory"][0])
	assert_that(SilhouetteLineupCheck.opaque_bounds(m)).is_equal(Rect2i(6, 0, 2, 8))


func test_a_no_mirror_pose_is_never_flipped_and_is_reported_missing() -> void:
	# Arrange: victory is `no_mirror`, authored only `front`; the squad needs `back`.
	var s := SpriteSetData.new()
	s.set_id = &"sprite_test_squad"
	s.is_squad = true
	s.facings_used = [&"back"]
	var f := _frame(8, 8, [Rect2i(0, 0, 2, 8)])
	s.animations.append(_anim(&"idle", &"back", [f]))
	s.animations.append(_anim(&"victory", &"front", [f], true))
	# Act
	var p: Dictionary = SilhouetteLineupCheck.pose_frames(s)
	# Assert
	assert_bool((p["frames"] as Dictionary).has(&"victory")).is_false()
	assert_bool(str(p["missing"]).contains("victory")).is_true()


func test_probes_are_the_last_idle_frame_and_two_frames_of_the_second_pose() -> void:
	# Arrange: idle [i0, i1, i2]; victory [v0, v1, v2, v3] -> probes i2, v0, v2.
	var frames: Dictionary = {}
	var idle: Array[Image] = []
	var vic: Array[Image] = []
	for i: int in 3:
		idle.append(_frame(8, 8, [Rect2i(0, 0, 1, 1 + i)]))
	for i: int in 4:
		vic.append(_frame(8, 8, [Rect2i(0, 0, 2, 1 + i)]))
	frames[&"idle"] = idle
	frames[&"victory"] = vic
	var p: Dictionary = {"poses": [&"idle", &"victory"], "frames": frames}
	# Act
	var probes: Array[Image] = SilhouetteLineupCheck.probe_frames(p)
	var ref: Image = SilhouetteLineupCheck.reference_frame(p)
	# Assert
	assert_int(probes.size()).is_equal(SilhouetteLineupCheck.REVIEWERS)
	assert_that(probes[0]).is_same(idle[2])
	assert_that(probes[1]).is_same(vic[0])
	assert_that(probes[2]).is_same(vic[2])
	assert_that(ref).is_same(idle[0])


# --- sheet ------------------------------------------------------------------

func test_a_sheet_row_draws_masks_black_on_white_feet_aligned() -> void:
	# Arrange: a 2x4 and a 3x2 mask.
	var a: Image = _mask(2, 4, [Rect2i(0, 0, 2, 4)])
	var b: Image = _mask(3, 2, [Rect2i(0, 0, 3, 2)])
	# Act: gap 1.
	var row: Image = SilhouetteLineupCheck.compose_row([a, b], 1)
	# Assert: width 1 + 2 + 1 + 3 + 1, height 1 + 4 + 1; b sits on the floor.
	assert_that(row.get_size()).is_equal(Vector2i(8, 6))
	assert_that(row.get_pixel(0, 0)).is_equal(Color.WHITE)
	assert_that(row.get_pixel(1, 1)).is_equal(Color.BLACK)
	assert_that(row.get_pixel(4, 4)).is_equal(Color.BLACK)
	assert_that(row.get_pixel(4, 2)).is_equal(Color.WHITE)


func test_stacked_rows_are_left_aligned_on_white() -> void:
	var r1: Image = SilhouetteLineupCheck.compose_row([_mask(2, 2, [Rect2i(0, 0, 2, 2)])], 1)
	var r2: Image = SilhouetteLineupCheck.compose_row([_mask(5, 1, [Rect2i(0, 0, 5, 1)])], 1)
	var sheet: Image = SilhouetteLineupCheck.stack_rows([r1, r2])
	assert_that(sheet.get_size()).is_equal(Vector2i(7, 7))
	assert_that(sheet.get_pixel(5, 1)).is_equal(Color.WHITE)
