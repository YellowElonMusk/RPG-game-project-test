## Story 020, AC-17 (GDD rule 12; ADR-0005 §2-§3): only the set light casts
## shadows; every actor casts none and gets exactly one blob, at its foot
## anchor offset by `shadow_offset` along the set light's ground-projected
## direction, in the current lighting profile's `shadow_color`.
extends GdUnitTestSuite


func _stage() -> DioramaStage:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	stage.key_light = DirectionalLight3D.new()
	stage.set_light = DirectionalLight3D.new()
	stage.fill_light = DirectionalLight3D.new()
	stage.add_child(stage.key_light)
	stage.add_child(stage.set_light)
	stage.add_child(stage.fill_light)
	return stage


func test_only_the_set_light_casts_shadows() -> void:
	var stage := _stage()
	stage._ready()
	assert_bool(stage.set_light.shadow_enabled).is_true()
	assert_bool(stage.key_light.shadow_enabled).is_false()
	assert_bool(stage.fill_light.shadow_enabled).is_false()


func test_actor_sprites_cast_no_shadow() -> void:
	var sprite: CharacterSprite = auto_free(CharacterSprite.new())
	sprite.setup(SpriteFrames.new(), PresentationConfig.new())
	assert_int(sprite.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_blob_is_an_unlit_set_layer_mesh_casting_nothing() -> void:
	var blob: MeshInstance3D = auto_free(_stage().make_blob_shadow())
	assert_int(blob.layers).is_equal(DioramaStage.LAYER_SET)
	assert_int(blob.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var mat := blob.material_override as StandardMaterial3D
	assert_int(mat.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_blob_sits_under_the_foot_offset_along_the_set_light() -> void:
	var stage := _stage()
	# A light travelling toward +x (basis -Z points +x after a -90 deg yaw),
	# tilted down: its ground projection is +x.
	stage.set_light.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-40.0), deg_to_rad(-90.0), 0.0)), Vector3.ZERO)
	var dir := stage.set_light_ground_direction()
	assert_float(dir.x).is_equal_approx(1.0, 0.0001)
	assert_float(dir.y).is_equal(0.0)
	var blob: MeshInstance3D = auto_free(stage.make_blob_shadow())
	stage.place_blob_shadow(blob, Vector3(2.0, 0.0, -10.0), 0.5, 0.2)
	assert_vector(blob.position).is_equal_approx(Vector3(2.1, 0.0, -10.0), Vector3.ONE * 0.0001)
	assert_vector(blob.scale).is_equal_approx(Vector3(0.5, 1.0, 0.5 * DioramaStage.BLOB_DEPTH_RATIO), Vector3.ONE * 0.0001)


func test_blob_takes_the_current_profiles_shadow_color() -> void:
	var stage := _stage()
	var profile := LightingProfile.new()
	profile.shadow_color = Color(0.2, 0.1, 0.05, 0.6)
	stage.current_values = profile
	var blob: MeshInstance3D = auto_free(stage.make_blob_shadow())
	stage.place_blob_shadow(blob, Vector3.ZERO, 1.0, 0.0)
	assert_that((blob.material_override as StandardMaterial3D).albedo_color).is_equal(profile.shadow_color)

