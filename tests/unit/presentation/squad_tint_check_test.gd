## Story sprite-camera-presentation 072 (AC-67, TR-presentation-024): the
## squad is never tinted by a faction's boss flood. The measurement itself
## needs a GPU and a window (`tools/capture/squad_tint_capture.gd`, evidence
## in `production/qa/evidence/squad-never-tinted/`); this suite checks what
## the verdict is computed from: the masked ΔE statistics, the per-member
## exclusive masks, the AC-67 verdict, the projection-preserving actor ID
## override, and that no shipped boss profile changes an actor-reaching light.
extends GdUnitTestSuite

const _ACTOR_SHADER: String = "res://src/presentation/shaders/sprite_actor.gdshader"
const _PROFILE_DIR: String = "res://data/presentation/profiles/"


## A `w` x `h` RGBA8 image filled with `c`.
func _solid(w: int, h: int, c: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


## An L8 mask, white inside `rect`.
func _mask(w: int, h: int, rect: Rect2i) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	img.fill_rect(rect, Color.WHITE)
	return img


func test_masked_delta_e_identical_images_zero() -> void:
	var a: Image = _solid(8, 8, Color(0.6, 0.3, 0.2))
	var stats: Dictionary = CaptureChecks.masked_delta_e(a, a.duplicate() as Image, _mask(8, 8, Rect2i(0, 0, 4, 4)))
	assert_int(int(stats["pixels"])).is_equal(16)
	assert_float(float(stats["mean"])).is_equal_approx(0.0, 1e-6)
	assert_float(float(stats["p95"])).is_equal_approx(0.0, 1e-6)


func test_masked_delta_e_only_masked_pixels_counted() -> void:
	var a: Image = _solid(8, 8, Color(0.6, 0.3, 0.2))
	var b: Image = a.duplicate() as Image
	# A strong tint outside the mask must not count.
	b.fill_rect(Rect2i(4, 4, 4, 4), Color(0.1, 0.2, 0.9))
	var stats: Dictionary = CaptureChecks.masked_delta_e(a, b, _mask(8, 8, Rect2i(0, 0, 4, 4)))
	assert_int(int(stats["pixels"])).is_equal(16)
	assert_float(float(stats["max"])).is_equal_approx(0.0, 1e-6)


func test_masked_delta_e_mean_and_p95_from_known_pixels() -> void:
	var base := Color8(153, 77, 51)
	var tinted := Color8(115, 89, 128)
	var de: float = ColorDifference.delta_e_srgb(base, tinted)
	var a: Image = _solid(20, 1, base)
	var b: Image = a.duplicate() as Image
	# 2 of 20 pixels tinted: mean = de / 10; nearest-rank p95 (19th of 20) = de.
	b.set_pixel(0, 0, tinted)
	b.set_pixel(1, 0, tinted)
	var stats: Dictionary = CaptureChecks.masked_delta_e(a, b, _mask(20, 1, Rect2i(0, 0, 20, 1)))
	assert_float(float(stats["mean"])).is_equal_approx(de / 10.0, 0.05)
	assert_float(float(stats["p95"])).is_equal_approx(de, 0.05)
	assert_float(float(stats["max"])).is_equal_approx(de, 0.05)


func test_masked_delta_e_empty_mask_reports_no_pixels() -> void:
	var a: Image = _solid(4, 4, Color.WHITE)
	var stats: Dictionary = CaptureChecks.masked_delta_e(a, a, Image.create(4, 4, false, Image.FORMAT_L8))
	assert_int(int(stats["pixels"])).is_equal(0)


func test_exclusive_masks_overlap_removed_from_both() -> void:
	var masks: Array[Image] = [_mask(8, 4, Rect2i(0, 0, 5, 4)), _mask(8, 4, Rect2i(3, 0, 5, 4))]
	var out: Array[Image] = CaptureChecks.exclusive_masks(masks)
	assert_int(out.size()).is_equal(2)
	# Columns 3-4 belong to both, so to neither.
	assert_float(out[0].get_pixel(2, 0).r).is_equal(1.0)
	assert_float(out[0].get_pixel(3, 0).r).is_equal(0.0)
	assert_float(out[1].get_pixel(4, 0).r).is_equal(0.0)
	assert_float(out[1].get_pixel(5, 0).r).is_equal(1.0)


func test_squad_tint_verdict_within_limits_passes() -> void:
	var stats: Dictionary = {"Squad0": {"pixels": 100, "mean": 2.9, "p95": 5.9},
			"Squad1": {"pixels": 80, "mean": 0.0, "p95": 0.0}}
	var verdict: Dictionary = CaptureChecks.squad_tint_verdict(stats)
	assert_bool(bool(verdict["pass"])).is_true()
	assert_int((verdict["failures"] as PackedStringArray).size()).is_equal(0)


func test_squad_tint_verdict_mean_over_limit_fails() -> void:
	var stats: Dictionary = {"Squad0": {"pixels": 100, "mean": CaptureChecks.SQUAD_TINT_MEAN_MAX + 0.01, "p95": 1.0}}
	var verdict: Dictionary = CaptureChecks.squad_tint_verdict(stats)
	assert_bool(bool(verdict["pass"])).is_false()
	assert_str(String((verdict["failures"] as PackedStringArray)[0])).contains("Squad0")


func test_squad_tint_verdict_p95_over_limit_fails() -> void:
	var stats: Dictionary = {"Squad2": {"pixels": 100, "mean": 0.5, "p95": CaptureChecks.SQUAD_TINT_P95_MAX + 0.01}}
	assert_bool(bool(CaptureChecks.squad_tint_verdict(stats)["pass"])).is_false()


func test_squad_tint_verdict_member_without_pixels_fails() -> void:
	# A member the capture could not see is an invalid capture, never a pass.
	var stats: Dictionary = {"Squad0": {"pixels": 0, "mean": 0.0, "p95": 0.0}}
	assert_bool(bool(CaptureChecks.squad_tint_verdict(stats)["pass"])).is_false()
	assert_bool(bool(CaptureChecks.squad_tint_verdict({})["pass"])).is_false()


func test_actor_id_shader_code_keeps_projection_unshaded() -> void:
	var src: String = (load(_ACTOR_SHADER) as Shader).code
	var code: String = PresentationCapture.actor_id_shader_code(src)
	# The clip-space card projection survives, so the ID silhouette is the
	# card the actor shader really draws.
	assert_str(code).contains("void vertex()")
	assert_str(code).contains("uniform vec4 sprite_rect")
	assert_str(code).contains("render_mode unshaded")
	assert_str(code).not_contains("diffuse_burley")
	assert_str(code).contains("ALBEDO = capture_id_color.rgb;")
	assert_str(code).contains("EMISSION = vec3(0.0);")


func test_id_overrides_actor_card_keeps_projection_uniforms() -> void:
	var tool: PresentationCapture = auto_free(PresentationCapture.new())
	var root: Node3D = auto_free(Node3D.new())
	var sprite := Sprite3D.new()
	sprite.layers = DioramaStage.LAYER_ACTORS
	var mat := ShaderMaterial.new()
	mat.shader = load(_ACTOR_SHADER) as Shader
	mat.set_shader_parameter(&"sprite_rect", Rect2(10, 20, 30, 40))
	sprite.material_override = mat
	root.add_child(sprite)
	var restore: Dictionary = tool.apply_id_overrides(root, DioramaStage.LAYER_ACTORS)
	var id_mat := sprite.material_override as ShaderMaterial
	assert_object(id_mat).is_not_same(mat)
	assert_str(id_mat.shader.code).contains("void vertex()")
	assert_that(id_mat.get_shader_parameter(&"sprite_rect")).is_equal(Rect2(10, 20, 30, 40))
	assert_bool((id_mat.get_shader_parameter(&"capture_id_color") as Color).is_equal_approx(
			PresentationCapture.palette()["actor"])).is_true()
	PresentationCapture.restore_overrides(restore)
	assert_object(sprite.material_override).is_same(mat)


func test_boss_profiles_actor_lights_equal_battle() -> void:
	# Rule 11: the faction tint lives in set/fill/sky only. Every field that
	# reaches an actor (the key, the rim) equals the plain Battle profile's.
	var battle := load(_PROFILE_DIR + "battle.tres") as LightingProfile
	var bosses: int = 0
	for file: String in DirAccess.get_files_at(_PROFILE_DIR):
		if not (file.begins_with("boss_") and file.ends_with(".tres")):
			continue
		bosses += 1
		var p := load(_PROFILE_DIR + file) as LightingProfile
		assert_bool(p.key_color.is_equal_approx(battle.key_color)).override_failure_message(file).is_true()
		assert_float(p.key_energy).override_failure_message(file).is_equal_approx(battle.key_energy, 1e-6)
		assert_bool(p.key_rotation_deg.is_equal_approx(battle.key_rotation_deg)).override_failure_message(file).is_true()
		assert_bool(p.rim_color.is_equal_approx(battle.rim_color)).override_failure_message(file).is_true()
		assert_float(p.rim_strength).override_failure_message(file).is_equal_approx(battle.rim_strength, 1e-6)
	assert_int(bosses).is_greater_equal(2)
