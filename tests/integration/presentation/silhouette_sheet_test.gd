## Story 037 (GDD sprite-camera-presentation AC-33; art bible Principle 1;
## ADR-0005 §1): the black-fill silhouette sheet built from every shipped
## sprite set, and the lineup proxy run over it.
##
## `silhouette_sheet_capture.gd`'s `build()` takes the shipped sets and `T`
## and returns the per-character poses, battle-height and 32 px silhouettes
## and the proxy verdicts. These cases fail when a shipped character is
## missing a pose AC-33 shows, when a pose would be shown by a fallback, or
## when a character's silhouette fails the 2-of-3 lineup proxy at either
## size. The proxy does not replace the art director's AC-33 verdict.
extends GdUnitTestSuite

const SheetCapture := preload("res://tools/capture/silhouette_sheet_capture.gd")


func _build() -> Dictionary:
	var cfg: PresentationConfig = PresentationValidators.load_config()
	var t: int = SpriteProjection.texel_scale(SilhouetteLineupCheck.SHEET_LINES, cfg.texel_base_lines)
	return SheetCapture.build(PresentationValidators.load_sprite_sets(), t)


func test_every_shipped_character_has_every_pose_ac33_shows_in_its_role_facing() -> void:
	# Arrange / Act
	var r: Dictionary = _build()
	# Assert: all nine shipped sets, none missing a pose.
	var chars: Dictionary = r["characters"]
	assert_int(chars.size()).is_equal(PresentationValidators.load_sprite_sets().size())
	assert_int(chars.size()).is_greater_equal(SilhouetteLineupCheck.LINEUP_SIZE)
	var missing := PackedStringArray()
	for id: StringName in chars:
		missing.append_array(chars[id]["missing"])
	assert_int(missing.size()).override_failure_message(str(missing)).is_equal(0)


func test_squad_is_back_facing_and_enemies_front_facing_none_mirrored() -> void:
	var chars: Dictionary = _build()["characters"]
	for id: StringName in chars:
		var c: Dictionary = chars[id]
		var want: StringName = &"back" if c["is_squad"] else &"front"
		assert_that(c["facing"]).override_failure_message(String(id)).is_equal(want)
		for pose: StringName in c["mirrored"]:
			assert_bool(c["mirrored"][pose]).override_failure_message("%s %s" % [id, pose]).is_false()


func test_battle_height_silhouettes_are_the_frame_at_t_per_texel() -> void:
	var r: Dictionary = _build()
	var t: int = r["t"]
	assert_int(t).is_greater_equal(1)
	for id: StringName in r["characters"]:
		var c: Dictionary = r["characters"][id]
		var ref: Image = c["reference_frame"]
		var big: Image = c["battle_height"][0]
		assert_that(big.get_size()).override_failure_message(String(id)).is_equal(ref.get_size() * t)
		var th: Image = c["thumb"][0]
		assert_int(maxi(th.get_width(), th.get_height())).is_equal(SilhouetteLineupCheck.THUMB_PX)


func test_every_shipped_character_passes_the_lineup_proxy_at_both_sizes() -> void:
	# Arrange / Act
	var r: Dictionary = _build()
	# Assert
	for size: String in ["battle_height", "thumb_32"]:
		var v: Dictionary = r["verdict"][size]
		assert_bool(v["pass"]).override_failure_message("%s: %s" % [size, v["failures"]]).is_true()


func test_characters_are_in_set_id_order_so_the_sheet_layout_is_stable() -> void:
	# StringName sorting is not alphabetical; the sheet's documented order is.
	var keys: Array = _build()["characters"].keys()
	var names: Array = keys.map(func(k: StringName) -> String: return String(k))
	var sorted: Array = names.duplicate()
	sorted.sort()
	assert_array(names).is_equal(sorted)
