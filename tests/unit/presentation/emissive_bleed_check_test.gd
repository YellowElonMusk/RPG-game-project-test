## Story sprite-camera-presentation 052 (AC-48, TR-presentation-003/002): no
## emissive source bleeds through an actor's silhouette. The measurement needs
## a GPU and a window (`tools/capture/emissive_bleed_capture.gd`, evidence in
## `production/qa/evidence/no-emissive-behind-actor/`); this suite checks what
## the verdict is computed from: which geometry counts as emissive, the
## `actor_lighting` exemption, the reserved mask colour, the silhouette x
## emissive overlap and the AC-48 verdict (an invalid capture never passes).
extends GdUnitTestSuite


## A `w` x `h` L8 mask, white inside `rect`.
func _mask(w: int, h: int, rect: Rect2i) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	img.fill_rect(rect, Color.WHITE)
	return img


## A set-layer quad with `mat` as its override.
func _set_quad(mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = auto_free(MeshInstance3D.new())
	mi.mesh = QuadMesh.new()
	mi.layers = DioramaStage.LAYER_SET
	mi.material_override = mat
	return mi


func _emissive_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	return mat


func test_is_emissive_standard_material_with_emission_true() -> void:
	assert_bool(EmissiveBleedCheck.is_emissive(_set_quad(_emissive_material()), DioramaStage.LAYER_ACTORS)).is_true()


func test_is_emissive_plain_material_false() -> void:
	assert_bool(EmissiveBleedCheck.is_emissive(_set_quad(StandardMaterial3D.new()), DioramaStage.LAYER_ACTORS)).is_false()


func test_is_emissive_surface_material_with_emission_true() -> void:
	var mi: MeshInstance3D = _set_quad(null)
	mi.set_surface_override_material(0, _emissive_material())
	assert_bool(EmissiveBleedCheck.is_emissive(mi, DioramaStage.LAYER_ACTORS)).is_true()


func test_is_emissive_shader_writing_emission_true() -> void:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nvoid fragment() {\n\tALBEDO = vec3(0.1);\n\tEMISSION = vec3(4.0);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	assert_bool(EmissiveBleedCheck.is_emissive(_set_quad(mat), DioramaStage.LAYER_ACTORS)).is_true()


func test_is_emissive_tagged_ancestor_true() -> void:
	var parent: Node3D = auto_free(Node3D.new())
	parent.set_meta(PresentationCapture.META_CAPTURE_ID, EmissiveBleedCheck.EMISSIVE_TAG)
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	parent.add_child(mi)
	assert_bool(EmissiveBleedCheck.is_emissive(mi, DioramaStage.LAYER_ACTORS)).is_true()


func test_is_emissive_actor_card_rim_emission_false() -> void:
	# The actor shader writes EMISSION for its rim: an actor is never a source.
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/presentation/shaders/sprite_actor.gdshader") as Shader
	var mi: MeshInstance3D = _set_quad(mat)
	mi.layers = DioramaStage.LAYER_ACTORS
	assert_bool(EmissiveBleedCheck.is_emissive(mi, DioramaStage.LAYER_ACTORS)).is_false()


func test_is_actor_lighting_tagged_ancestor_true() -> void:
	var practical: OmniLight3D = auto_free(OmniLight3D.new())
	practical.set_meta(EmissiveBleedCheck.META_ACTOR_LIGHTING, true)
	var fire := MeshInstance3D.new()
	practical.add_child(fire)
	assert_bool(EmissiveBleedCheck.is_actor_lighting(fire)).is_true()


func test_is_actor_lighting_untagged_false() -> void:
	var fire: MeshInstance3D = auto_free(MeshInstance3D.new())
	assert_bool(EmissiveBleedCheck.is_actor_lighting(fire)).is_false()


func test_emissive_colour_not_in_id_palette() -> void:
	var c: Color = EmissiveBleedCheck.emissive_colour()
	for cls: String in PresentationCapture.palette():
		assert_bool((PresentationCapture.palette()[cls] as Color).is_equal_approx(c)).is_false()
	assert_bool(c.is_equal_approx(Color.BLACK)).is_false()


func test_colour_mask_marks_only_that_colour() -> void:
	var img := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	img.set_pixel(1, 0, EmissiveBleedCheck.emissive_colour())
	img.set_pixel(2, 0, PresentationCapture.palette()["actor"] as Color)
	var m: Dictionary = EmissiveBleedCheck.colour_mask(img, EmissiveBleedCheck.emissive_colour())
	assert_int(int(m["pixels"])).is_equal(1)
	assert_float((m["image"] as Image).get_pixel(1, 0).r).is_equal(1.0)
	assert_float((m["image"] as Image).get_pixel(2, 0).r).is_equal(0.0)


func test_bleed_emissive_beside_silhouette_zero() -> void:
	# The Camp fire beside the squad: emissive pixels next to, not inside.
	var b: Dictionary = EmissiveBleedCheck.bleed(_mask(10, 4, Rect2i(0, 0, 4, 4)), _mask(10, 4, Rect2i(5, 0, 5, 4)))
	assert_int(int(b["pixels"])).is_equal(0)


func test_bleed_emissive_behind_silhouette_counts_overlap() -> void:
	var b: Dictionary = EmissiveBleedCheck.bleed(_mask(10, 4, Rect2i(0, 0, 4, 4)), _mask(10, 4, Rect2i(2, 0, 6, 4)))
	assert_int(int(b["pixels"])).is_equal(8)
	assert_float((b["image"] as Image).get_pixel(3, 0).r).is_equal(1.0)
	assert_float((b["image"] as Image).get_pixel(5, 0).r).is_equal(0.0)


func test_bleed_mismatched_sizes_zero() -> void:
	var b: Dictionary = EmissiveBleedCheck.bleed(_mask(4, 4, Rect2i(0, 0, 4, 4)), _mask(8, 4, Rect2i(0, 0, 8, 4)))
	assert_int(int(b["pixels"])).is_equal(0)


func test_verdict_no_bleed_passes() -> void:
	var v: Dictionary = EmissiveBleedCheck.verdict({"silhouette_pixels": 900, "bleed_pixels": 0})
	assert_bool(bool(v["pass"])).is_true()


func test_verdict_bleed_fails() -> void:
	var v: Dictionary = EmissiveBleedCheck.verdict({"silhouette_pixels": 900, "bleed_pixels": 1})
	assert_bool(bool(v["pass"])).is_false()
	assert_int((v["failures"] as PackedStringArray).size()).is_equal(1)


func test_verdict_no_actor_pixels_invalid_fails() -> void:
	var v: Dictionary = EmissiveBleedCheck.verdict({"silhouette_pixels": 0, "bleed_pixels": 0})
	assert_bool(bool(v["pass"])).is_false()
	assert_str(String((v["failures"] as PackedStringArray)[0])).contains("invalid capture")
