## The SpriteForge sprite sets shipped under `data/presentation/sprite_sets/`
## (ADR-0005 §1 and §9): every character and enemy record names one, each
## passes rule 10's boot validators, and `build_sprite_frames()` slices
## every strip into `<animation_id>_<facing>` clips of equal-width frames.
extends GdUnitTestSuite

const SQUAD_IDS: Array[String] = ["char_karen", "char_michelin_chef", "char_florida_man", "char_baguette_thrower"]
const ENEMY_IDS: Array[String] = ["enemy_clerk", "enemy_supervisor", "enemy_security_drone",
		"enemy_middle_manager", "enemy_ceo"]


func _sets() -> Dictionary[StringName, SpriteSetData]:
	return PresentationValidators.load_sprite_sets()


func _record(path: String) -> Resource:
	return load(path)


func test_every_character_and_enemy_names_a_shipped_set() -> void:
	var sets := _sets()
	for id: String in SQUAD_IDS:
		var rec := _record("res://data/characters/%s.tres" % id) as CharacterData
		assert_bool(sets.has(StringName(rec.sprite_set_id))).override_failure_message(
				"%s names %s" % [id, rec.sprite_set_id]).is_true()
		assert_bool(sets[StringName(rec.sprite_set_id)].is_squad).is_true()
	for id: String in ENEMY_IDS:
		var rec := _record("res://data/enemies/%s.tres" % id) as EnemyData
		assert_bool(sets.has(StringName(rec.sprite_set_id))).override_failure_message(
				"%s names %s" % [id, rec.sprite_set_id]).is_true()


func test_every_shipped_set_passes_boot_validation() -> void:
	var sets := _sets()
	var config := PresentationValidators.load_config()
	assert_int(sets.size()).is_equal(SQUAD_IDS.size() + ENEMY_IDS.size())
	for id: String in ENEMY_IDS:
		var rec := _record("res://data/enemies/%s.tres" % id) as EnemyData
		var errors := PresentationValidators.validate_sprite_set(
				sets[StringName(rec.sprite_set_id)], config, rec.is_boss)
		assert_array(Array(errors)).override_failure_message("%s: %s" % [id, errors]).is_empty()
	for id: String in SQUAD_IDS:
		var rec := _record("res://data/characters/%s.tres" % id) as CharacterData
		var errors := PresentationValidators.validate_sprite_set(
				sets[StringName(rec.sprite_set_id)], config, false)
		assert_array(Array(errors)).override_failure_message("%s: %s" % [id, errors]).is_empty()


func test_every_shipped_animation_has_a_strip_that_divides_into_its_frames() -> void:
	for sprite_set: SpriteSetData in _sets().values():
		for anim: SpriteAnimationData in sprite_set.animations:
			var label := "%s %s" % [sprite_set.set_id, SpriteSetData.label_for(anim.animation_id, anim.move_name)]
			assert_object(anim.strip).override_failure_message(label).is_not_null()
			if anim.strip == null:
				continue
			assert_int(anim.strip.get_width() % anim.frame_count()).override_failure_message(label).is_equal(0)
			# SpriteForge frames are square (64 squad and grunts, 128 bosses).
			assert_int(anim.frame_region(0).size.x).override_failure_message(label).is_equal(anim.strip.get_height())


func test_build_sprite_frames_names_clips_by_role_and_facing() -> void:
	var sprite_set: SpriteSetData = _sets()[&"sprite_karen"]
	var frames := sprite_set.build_sprite_frames()
	for clip: StringName in [&"idle_back", &"attack_back", &"defend_back", &"hit_back",
			&"knockout_back", &"victory_back", &"move_speak_to_the_manager_back"]:
		assert_bool(frames.has_animation(clip)).override_failure_message(String(clip)).is_true()
	assert_bool(frames.has_animation(&"default")).is_false()
	assert_bool(frames.get_animation_loop(&"idle_back")).is_true()
	assert_bool(frames.get_animation_loop(&"attack_back")).is_false()


func test_build_sprite_frames_slices_the_strip_in_order() -> void:
	var anim := SpriteAnimationData.new()
	anim.animation_id = &"attack"
	anim.facing = &"front"
	anim.fps = 10.0
	anim.frame_durations = PackedFloat32Array([1, 2, 1])
	anim.impact_frame = 1
	# Three 32 px columns, each filled with its own colour.
	var img := Image.create(96, 32, false, Image.FORMAT_RGBA8)
	var colours: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
	for i: int in colours.size():
		img.fill_rect(Rect2i(i * 32, 0, 32, 32), colours[i])
	anim.strip = ImageTexture.create_from_image(img)
	var s := SpriteSetData.new()
	s.animations.append(anim)
	var frames := s.build_sprite_frames()
	assert_int(frames.get_frame_count(&"attack_front")).is_equal(3)
	assert_float(frames.get_animation_speed(&"attack_front")).is_equal(10.0)
	assert_float(frames.get_frame_duration(&"attack_front", 1)).is_equal(2.0)
	# Each frame is a standalone texture of one column (the shader samples it
	# whole), not an atlas region of the strip.
	var second := frames.get_frame_texture(&"attack_front", 1)
	assert_bool(second is AtlasTexture).is_false()
	assert_that(second.get_size()).is_equal(Vector2(32, 32))
	assert_that(second.get_image().get_pixel(16, 16)).is_equal(Color.GREEN)


func test_frame_region_is_empty_without_a_strip_or_out_of_range() -> void:
	var anim := SpriteAnimationData.new()
	anim.frame_durations = PackedFloat32Array([1, 1])
	assert_that(anim.frame_region(0)).is_equal(Rect2i())
	anim.strip = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	assert_that(anim.frame_region(1)).is_equal(Rect2i(32, 0, 32, 32))
	assert_that(anim.frame_region(2)).is_equal(Rect2i())
