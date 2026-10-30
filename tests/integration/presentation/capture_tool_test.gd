## Story sprite-camera-presentation 002 (ADR-0005 §13, P-09): the capture
## tool's headless-checkable contract. The rendering itself needs a GPU and a
## window (`tools/capture/capture_main.gd`, evidence in
## `production/qa/evidence/story-002-capture-tool/`); this suite checks what
## every pass is built from: the explicit `SubViewport` settings, the ID
## classification and palette, the override/restore cycle, the measurement
## of each pass's image, the glow-hook result and the measurements file.
extends GdUnitTestSuite

## Non-default project values, injected through `read_setting`.
const _NON_DEFAULT: Dictionary = {
	"rendering/anti_aliasing/quality/msaa_3d": 2,
	"rendering/anti_aliasing/quality/screen_space_aa": 1,
	"rendering/anti_aliasing/quality/use_taa": true,
	"rendering/lights_and_shadows/positional_shadow/atlas_size": 8192,
	"rendering/lights_and_shadows/positional_shadow/atlas_16_bits": false,
	"rendering/lights_and_shadows/positional_shadow/atlas_quadrant_0_subdiv": 1,
	"rendering/scaling_3d/scale": 0.5,
}
const _OUT_DIR: String = "user://capture_tool_test/"


func _reader(values: Dictionary) -> Callable:
	return func(key: String, fallback: Variant) -> Variant:
		return values.get(key, fallback)


func test_viewport_settings_project_values_set_explicitly() -> void:
	var vp: SubViewport = auto_free(SubViewport.new())
	var record: Dictionary = PresentationCapture.apply_viewport_settings(vp,
			func(key: String, fallback: Variant) -> Variant: return ProjectSettings.get_setting(key, fallback))
	assert_int(record.size()).is_equal(PresentationCapture.VIEWPORT_SETTINGS.size())
	for row: Array in PresentationCapture.VIEWPORT_SETTINGS:
		var expected: Variant = ProjectSettings.get_setting(String(row[1]), row[2])
		assert_that(vp.get(String(row[0]))).override_failure_message(String(row[0])).is_equal(expected)
		assert_that(record[row[0]]["value"]).is_equal(expected)
	# The ADR's observed trap: the project atlas size, not the SubViewport default.
	assert_int(vp.positional_shadow_atlas_size).is_equal(
			int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 4096)))


func test_viewport_settings_non_default_config_followed() -> void:
	var vp: SubViewport = auto_free(SubViewport.new())
	var record: Dictionary = PresentationCapture.apply_viewport_settings(vp, _reader(_NON_DEFAULT))
	assert_int(vp.msaa_3d).is_equal(_NON_DEFAULT["rendering/anti_aliasing/quality/msaa_3d"])
	assert_int(vp.screen_space_aa).is_equal(_NON_DEFAULT["rendering/anti_aliasing/quality/screen_space_aa"])
	assert_bool(vp.use_taa).is_true()
	assert_int(vp.positional_shadow_atlas_size).is_equal(8192)
	assert_bool(vp.positional_shadow_atlas_16_bits).is_false()
	assert_int(vp.positional_shadow_atlas_quad_0).is_equal(1)
	assert_float(vp.scaling_3d_scale).is_equal_approx(0.5, 1e-6)
	assert_str(String(record["msaa_3d"]["setting"])).is_equal("rendering/anti_aliasing/quality/msaa_3d")


func test_palette_every_class_distinct_and_not_black() -> void:
	var colours: Dictionary = PresentationCapture.palette()
	var classes: Array[String] = PresentationCapture.id_classes()
	assert_int(colours.size()).is_equal(classes.size())
	var seen: Dictionary = {}
	for cls: String in classes:
		var c: Color = colours[cls]
		assert_bool(c.r8 + c.g8 + c.b8 > 0).is_true()
		assert_bool(seen.has(c.to_html())).override_failure_message(cls).is_false()
		seen[c.to_html()] = true
	for tag: String in ["SKY", "notice_slip", "chase_tag", "stun_pose", "checkpoint_open",
			"checkpoint_closed", "safe_paving", "beacon", "camp_sign", "interact_prompt", "symbol"]:
		assert_bool(classes.has(tag)).override_failure_message(tag).is_true()


func test_class_of_tags_layers_and_sky_resolved() -> void:
	var root: Node3D = auto_free(Node3D.new())
	var cue := Node3D.new()
	cue.set_meta(PresentationCapture.META_CAPTURE_ID, "beacon")
	root.add_child(cue)
	var tagged_child := MeshInstance3D.new()
	cue.add_child(tagged_child)
	var sky := MeshInstance3D.new()
	sky.set_meta(PresentationCapture.META_CAPTURE_ID, "sky")
	root.add_child(sky)
	var actor := Sprite3D.new()
	actor.layers = DioramaStage.LAYER_ACTORS
	root.add_child(actor)
	var set_piece := MeshInstance3D.new()
	set_piece.layers = DioramaStage.LAYER_SET
	root.add_child(set_piece)
	var bogus := MeshInstance3D.new()
	bogus.set_meta(PresentationCapture.META_CAPTURE_ID, "not_a_tag")
	root.add_child(bogus)
	var a := DioramaStage.LAYER_ACTORS
	assert_str(PresentationCapture.class_of(tagged_child, a, root)).is_equal("beacon")
	assert_str(PresentationCapture.class_of(sky, a, root)).is_equal("SKY")
	assert_str(PresentationCapture.class_of(actor, a, root)).is_equal(PresentationCapture.CLASS_ACTOR)
	assert_str(PresentationCapture.class_of(set_piece, a, root)).is_equal(PresentationCapture.CLASS_SET)
	assert_str(PresentationCapture.class_of(bogus, a, root)).is_equal(PresentationCapture.CLASS_SET)


func test_id_overrides_applied_then_restored() -> void:
	var tool: PresentationCapture = auto_free(PresentationCapture.new())
	var root: Node3D = auto_free(Node3D.new())
	var original := StandardMaterial3D.new()
	var mesh := MeshInstance3D.new()
	mesh.material_override = original
	mesh.set_meta(PresentationCapture.META_CAPTURE_ID, "symbol")
	root.add_child(mesh)
	var sprite := Sprite3D.new()
	sprite.layers = DioramaStage.LAYER_ACTORS
	sprite.texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	root.add_child(sprite)
	var restore: Dictionary = tool.apply_id_overrides(root, DioramaStage.LAYER_ACTORS)
	var colours: Dictionary = PresentationCapture.palette()
	var m_mat := mesh.material_override as ShaderMaterial
	var s_mat := sprite.material_override as ShaderMaterial
	assert_object(m_mat).is_not_null()
	assert_object(s_mat).is_not_null()
	assert_bool((m_mat.get_shader_parameter(&"id_color") as Color).is_equal_approx(colours["symbol"])).is_true()
	assert_bool((s_mat.get_shader_parameter(&"id_color") as Color).is_equal_approx(colours["actor"])).is_true()
	assert_bool(s_mat.get_shader_parameter(&"use_mask")).is_true()
	assert_bool(m_mat.get_shader_parameter(&"use_mask")).is_false()
	PresentationCapture.restore_overrides(restore)
	assert_object(mesh.material_override).is_same(original)
	assert_object(sprite.material_override).is_null()


func test_measure_id_counts_each_class() -> void:
	var colours: Dictionary = PresentationCapture.palette()
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	img.fill_rect(Rect2i(0, 0, 5, 2), colours["SKY"])           # 10 px
	img.fill_rect(Rect2i(2, 5, 3, 4), colours["beacon"])        # 12 px
	var near_actor: Color = colours["actor"]
	near_actor.r8 = clampi(near_actor.r8 + 3, 0, 255)           # read-back rounding
	img.set_pixel(9, 9, near_actor)
	img.set_pixel(8, 9, Color8(60, 60, 60))                     # AA edge
	var m: Dictionary = PresentationCapture.measure_id(img)
	assert_int(m["SKY"]["pixels"]).is_equal(10)
	assert_array(m["SKY"]["bbox"]).is_equal([0, 0, 5, 2])
	assert_int(m["beacon"]["pixels"]).is_equal(12)
	assert_array(m["beacon"]["bbox"]).is_equal([2, 5, 3, 4])
	assert_int(m["actor"]["pixels"]).is_equal(1)
	assert_int(m["unclassified"]["pixels"]).is_equal(1)
	assert_int(m["none"]["pixels"]).is_equal(100 - 10 - 12 - 1 - 1)
	assert_float(m["beacon"]["share"]).is_equal_approx(0.12, 1e-6)
	assert_int(m["symbol"]["pixels"]).is_equal(0)


func test_diff_mask_marks_changed_pixels_only() -> void:
	var a := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	a.fill(Color(0.5, 0.5, 0.5))
	var b: Image = a.duplicate() as Image
	b.fill_rect(Rect2i(0, 0, 3, 2), Color(0.2, 0.2, 0.2))
	b.set_pixel(7, 3, Color8(129, 128, 128))  # within tolerance
	var d: Dictionary = PresentationCapture.diff_mask(a, b)
	assert_int(d["pixels"]).is_equal(6)
	var mask: Image = d["image"]
	assert_float(mask.get_pixel(0, 0).r).is_equal(1.0)
	assert_float(mask.get_pixel(7, 3).r).is_equal(0.0)


func test_measure_opaque_ui_pixels() -> void:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(1, 7, 4, 2), Color(1, 1, 1, 0.5))
	var m: Dictionary = PresentationCapture.measure_opaque(img)
	assert_int(m["pixels"]).is_equal(8)
	assert_array(m["bbox"]).is_equal([1, 7, 4, 2])


func test_glow_hook_pending_names_item_15() -> void:
	var g: Dictionary = PresentationCapture.probe_glow_hook()
	assert_int(g["item"]).is_equal(15)
	# Spike 2026-10-29 recorded item (15) FAIL on 4.7.2: the tool records Pending.
	assert_str(g["status"]).is_equal(PresentationCapture.GLOW_PENDING)
	assert_str(g["reason"]).contains("item (15)")


func test_write_result_writes_pngs_and_measurements() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var result: Dictionary = {"images": {"id": img, "ui": img},
			"measurements": {"passes": {"glow_input": PresentationCapture.probe_glow_hook()}}}
	assert_int(PresentationCapture.write_result(result, _OUT_DIR)).is_equal(OK)
	var dir: String = ProjectSettings.globalize_path(_OUT_DIR)
	assert_bool(FileAccess.file_exists(dir.path_join("id.png"))).is_true()
	assert_bool(FileAccess.file_exists(dir.path_join("ui.png"))).is_true()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("measurements.json")))
	assert_str(parsed["passes"]["glow_input"]["status"]).is_equal(PresentationCapture.GLOW_PENDING)
	for f: String in ["id.png", "ui.png", "measurements.json"]:
		DirAccess.remove_absolute(dir.path_join(f))
