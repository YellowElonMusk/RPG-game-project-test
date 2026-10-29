# PROTOTYPE - NOT FOR PRODUCTION
# Throwaway engine spike for story-001-windowed-engine-spike. Builds a minimal
# diorama and exercises ADR-0005 verification items (12)-(16), plus a
# frustum_offset sign re-measurement at 16:9 and 16:10. Run windowed; it
# screenshots itself and quits. Nothing here is production code.
extends SceneTree

const OUT_DIR := "res://production/qa/evidence/story-001-windowed-engine-spike/"
const SET_LAYER := 1    # bit 1 ("SET")
const ACTOR_LAYER := 2  # bit 2 ("ACTORS")

# Spike-chosen tuning knobs (AC: battle_fov, h_cam, horizon_frac, slot depths,
# humanoid_height_px "are set" -- values here are the spike's working numbers,
# not final production balance).
const BATTLE_FOV_DEG := 32.0
const NEAR := 0.3
const FAR := 50.0
const HORIZON_FRAC := 0.42
const H_CAM := 1.0
const SLOT_DEPTHS := [4.0, 6.0, 8.5]  # view depth from the battle camera
const HUMANOID_HEIGHT_PX := 120

var sprite: AnimatedSprite3D
var sprite_mat: ShaderMaterial
var frame_tex_a: ImageTexture
var frame_tex_b: ImageTexture
var key_light: DirectionalLight3D
var set_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var sky_mat: ShaderMaterial
var battle_cam: Camera3D
var overworld_cam: Camera3D
var env: Environment
var cam_attrs: CameraAttributesPractical
var glow_effect: GlowProbeEffect

class GlowProbeEffect:
	extends CompositorEffect
	var result: Array = []
	var ran := false

	func _render_callback(_effect_callback_type: int, render_data: RenderData) -> void:
		if ran:
			return
		ran = true
		var buffers := render_data.get_render_scene_buffers()
		if buffers == null:
			result.append("render_scene_buffers is null")
			return
		if not (buffers is RenderSceneBuffersRD):
			result.append("render_scene_buffers is not RenderSceneBuffersRD: %s" % buffers)
			return
		var rb := buffers as RenderSceneBuffersRD
		for ctx in ["forward_clustered", "forward_mobile", "render_buffers", ""]:
			for name in ["glow", "glow_texture", "glow_map"]:
				var has := rb.has_texture(ctx, name)
				if has:
					result.append("FOUND glow texture at context='%s' name='%s'" % [ctx, name])
		var color_tex := rb.get_color_texture()
		result.append("get_color_texture() at callback=%d valid=%s" % [_effect_callback_type, color_tex != null])
		if result.is_empty():
			result.append("no glow-named texture found via has_texture() at any guessed context/name")


func _initialize() -> void:
	_run()


func _run() -> void:
	var root := get_root()
	_build_scene(root)
	await process_frame
	await process_frame

	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)

	battle_cam.make_current()
	_apply_battle_frustum(root.size)

	# --- Item 12: ambient_light_disabled + key-only actor lighting ---
	_set_frame(0, false)
	_set_profile("battle")
	await process_frame
	await process_frame
	_capture(root, OUT_DIR + "ambient_key_only_lit.png")
	key_light.visible = false
	await process_frame
	await process_frame
	_capture(root, OUT_DIR + "ambient_key_only_dark.png")
	key_light.visible = true
	await process_frame

	# --- Item 13: manual frame stepping (own playback stopped) ---
	_set_frame(0, false)
	await process_frame
	_capture(root, OUT_DIR + "frame_step_0.png")
	_set_frame(1, false)
	await process_frame
	_capture(root, OUT_DIR + "frame_step_1.png")

	# --- Item 14: flip-based mirroring in the shader ---
	_set_frame(0, false)
	await process_frame
	_capture(root, OUT_DIR + "flip_normal.png")
	_set_frame(0, true)
	await process_frame
	_capture(root, OUT_DIR + "flip_mirrored.png")
	_set_frame(0, false)
	await process_frame

	# --- battle / boss_* / camp profiles ---
	_set_profile("battle")
	await process_frame
	_capture(root, OUT_DIR + "battle.png")

	_set_profile("boss_bureaucratia")
	await process_frame
	_capture(root, OUT_DIR + "boss_takeover.png")

	_set_profile("camp")
	await process_frame
	_capture(root, OUT_DIR + "camp.png")
	_set_profile("battle")

	# --- Pitched overworld camera, sprite against a wall ---
	overworld_cam.make_current()
	_set_profile("overworld")
	await process_frame
	await process_frame
	_capture(root, OUT_DIR + "overworld_pitched_wall.png")

	# --- Near/far rows (depth staging; constant-T rescale is NOT re-derived here) ---
	battle_cam.make_current()
	_set_profile("battle")
	await process_frame
	_capture(root, OUT_DIR + "near_far_rows.png")

	# --- frustum_offset sign re-measurement at 16:9 and 16:10 ---
	await _measure_offset_sign(root, "16:9")
	print("ASPECT 16:9 size=", root.size, " frustum_offset=", battle_cam.frustum_offset, " cam.size=", battle_cam.size)
	root.size = Vector2i(1280, 800)
	await process_frame
	await process_frame
	_apply_battle_frustum(root.size)
	await process_frame
	_capture(root, OUT_DIR + "battle_16x10.png")
	await _measure_offset_sign(root, "16:10")
	print("ASPECT 16:10 size=", root.size, " frustum_offset=", battle_cam.frustum_offset, " cam.size=", battle_cam.size)
	root.size = Vector2i(1280, 720)
	await process_frame
	_apply_battle_frustum(root.size)
	await process_frame

	# --- Item 16: pipeline compilation counters ---
	await _measure_pipeline_counters()

	# --- Item 15: glow-before-tonemap compositor hook ---
	await _probe_glow_hook(root)

	print("SPIKE DONE")
	quit()


func _measure_offset_sign(root: Window, label: String) -> void:
	# Renders with frustum_offset.y at 0 and at +d, then finds the vertical image
	# shift that best aligns three columns. Positive shift = image moved down.
	var base := battle_cam.frustum_offset
	var d: float = 0.1 * battle_cam.size
	battle_cam.frustum_offset = Vector2(base.x, 0.0)
	await process_frame
	await process_frame
	var a := root.get_texture().get_image()
	battle_cam.frustum_offset = Vector2(base.x, d)
	await process_frame
	await process_frame
	var b := root.get_texture().get_image()
	battle_cam.frustum_offset = base
	await process_frame
	var h := a.get_height()
	var w := a.get_width()
	var best := 0
	var best_err := INF
	for s in range(-150, 151):
		var err := 0.0
		var n := 0
		for y in range(160, h - 160, 2):
			for x in [w / 2 - 40, w / 2, w / 2 + 120]:
				err += absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y + s).get_luminance())
				n += 1
		err /= n
		if err < best_err:
			best_err = err
			best = s
	var expected_px: float = d / battle_cam.size * h
	print("SIGN %s: frustum_offset.y +%.5f (size %.5f) -> image shift %d px (positive = down), |expected| %.1f px, err %.4f" % [label, d, battle_cam.size, best, expected_px, best_err])


func _make_frame(variant: int) -> ImageTexture:
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(10, 56):
		for x in range(10, 22):
			img.set_pixel(x, y, Color(0.2, 0.5, 0.9, 1.0))
	for y in range(2, 10):
		for x in range(12, 20):
			img.set_pixel(x, y, Color(0.9, 0.8, 0.6, 1.0))
	# Asymmetric marker on the RIGHT side only, so flip_h is visibly obvious.
	for y in range(14, 20):
		for x in range(22, 28):
			img.set_pixel(x, y, Color(1.0, 0.0, 0.0, 1.0))
	if variant == 1:
		# Frame 1 differs visibly from frame 0 for the manual-stepping check.
		for y in range(30, 36):
			for x in range(4, 10):
				img.set_pixel(x, y, Color(1.0, 1.0, 0.0, 1.0))
	return ImageTexture.create_from_image(img)


func _build_scene(root: Window) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_energy = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX

	cam_attrs = CameraAttributesPractical.new()

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.camera_attributes = cam_attrs
	root.add_child(world_env)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 16)
	ground.mesh = pm
	ground.layers = SET_LAYER
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.3, 0.3, 0.32)
	ground.material_override = ground_mat
	root.add_child(ground)

	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(10, 5, 0.3)
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 2.5, -4)
	wall.layers = SET_LAYER
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.4, 0.35, 0.3)
	wall.material_override = wall_mat
	root.add_child(wall)

	key_light = DirectionalLight3D.new()
	key_light.light_cull_mask = ACTOR_LAYER
	key_light.shadow_enabled = false
	key_light.light_energy = 1.3
	key_light.light_color = Color(1.0, 0.95, 0.85)
	key_light.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(key_light)

	set_light = DirectionalLight3D.new()
	set_light.light_cull_mask = SET_LAYER
	set_light.shadow_enabled = true
	set_light.light_energy = 1.0
	set_light.light_color = Color(1.0, 0.9, 0.7)
	set_light.rotation_degrees = Vector3(-55, -20, 0)
	root.add_child(set_light)

	fill_light = DirectionalLight3D.new()
	fill_light.light_cull_mask = SET_LAYER
	fill_light.shadow_enabled = false
	fill_light.light_energy = 0.4
	fill_light.light_color = Color(0.5, 0.6, 0.9)
	fill_light.rotation_degrees = Vector3(40, 150, 0)
	root.add_child(fill_light)

	var sky := MeshInstance3D.new()
	var sky_mesh := QuadMesh.new()
	sky_mesh.size = Vector2(60, 24)
	sky.mesh = sky_mesh
	sky.position = Vector3(0, 8, -20)
	sky.layers = SET_LAYER
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://prototypes/sprite_camera_spike/shaders/sky_card_spike.gdshader")
	sky.material_override = sky_mat
	root.add_child(sky)

	frame_tex_a = _make_frame(0)
	frame_tex_b = _make_frame(1)
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", frame_tex_a)
	frames.add_frame(&"idle", frame_tex_b)
	frames.set_animation_speed(&"idle", 0.0)

	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.pixel_size = 0.02
	sprite.layers = ACTOR_LAYER
	sprite.position = Vector3(0, 1.0, 0)
	sprite_mat = ShaderMaterial.new()
	sprite_mat.shader = load("res://prototypes/sprite_camera_spike/shaders/sprite_actor_spike.gdshader")
	sprite.material_override = sprite_mat
	root.add_child(sprite)
	sprite.stop()  # ADR §1: stop() once in setup(); never again while stepping frames.

	battle_cam = Camera3D.new()
	battle_cam.projection = Camera3D.PROJECTION_FRUSTUM
	battle_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	battle_cam.near = NEAR
	battle_cam.far = FAR
	battle_cam.position = Vector3(0, H_CAM, 6)  # looks down -Z at the sprite (pitch 0, yaw 0)
	root.add_child(battle_cam)

	overworld_cam = Camera3D.new()
	overworld_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	overworld_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	overworld_cam.fov = 50.0
	overworld_cam.near = 0.1
	overworld_cam.far = 100.0
	root.add_child(overworld_cam)
	overworld_cam.look_at_from_position(Vector3(3.5, 3.2, 2.5), sprite.position, Vector3.UP)

	# Near/far row sprites (depth staging only -- not the clip-space quad).
	for i in range(SLOT_DEPTHS.size()):
		var s := AnimatedSprite3D.new()
		s.sprite_frames = frames
		s.animation = &"idle"
		s.pixel_size = 0.02
		s.layers = ACTOR_LAYER
		s.position = Vector3((i - 1) * 2.0 - 0.8, 1.0, 6.0 - SLOT_DEPTHS[i])
		var m := ShaderMaterial.new()
		m.shader = sprite_mat.shader
		m.set_shader_parameter("frame_tex", frame_tex_a)
		m.set_shader_parameter("flip_h", false)
		s.material_override = m
		root.add_child(s)
		s.stop()


func _apply_battle_frustum(viewport_size: Vector2i) -> void:
	var aspect := float(viewport_size.x) / float(viewport_size.y)
	var half_fov := deg_to_rad(BATTLE_FOV_DEG) * 0.5
	var h_near: float = 2.0 * NEAR * tan(half_fov) * maxf(1.0, (16.0 / 9.0) / aspect)
	battle_cam.size = h_near
	var offset_y: float = -(0.5 - HORIZON_FRAC) * h_near
	battle_cam.frustum_offset = Vector2(0.0, offset_y)


func _set_frame(idx: int, flip: bool) -> void:
	sprite.frame = idx
	sprite_mat.set_shader_parameter("frame_tex", frame_tex_a if idx == 0 else frame_tex_b)
	sprite_mat.set_shader_parameter("flip_h", flip)


func _set_profile(id: String) -> void:
	match id:
		"battle":
			key_light.light_color = Color(1.0, 0.95, 0.85)
			key_light.light_energy = 1.3
			sky_mat.set_shader_parameter("sky_top", Color(0.15, 0.1, 0.3))
			sky_mat.set_shader_parameter("sky_bottom", Color(0.5, 0.3, 0.5))
			sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.8, 0.4))
			env.glow_intensity = 0.8
		"boss_bureaucratia":
			key_light.light_color = Color(0.9, 0.5, 0.9)
			key_light.light_energy = 1.6
			sky_mat.set_shader_parameter("sky_top", Color(0.4, 0.0, 0.3))
			sky_mat.set_shader_parameter("sky_bottom", Color(0.9, 0.2, 0.3))
			sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.5, 0.2))
			env.glow_intensity = 1.4
		"camp":
			key_light.light_color = Color(1.0, 0.85, 0.6)
			key_light.light_energy = 0.9
			sky_mat.set_shader_parameter("sky_top", Color(0.05, 0.05, 0.2))
			sky_mat.set_shader_parameter("sky_bottom", Color(0.2, 0.15, 0.3))
			sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.6, 0.3))
			env.glow_intensity = 0.6
		"overworld":
			key_light.light_color = Color(1.0, 0.95, 0.8)
			key_light.light_energy = 1.1
			sky_mat.set_shader_parameter("sky_top", Color(0.3, 0.5, 0.8))
			sky_mat.set_shader_parameter("sky_bottom", Color(0.8, 0.85, 0.6))
			sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.9, 0.6))


func _capture(root: Window, path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("CAPTURED ", path)


func _measure_pipeline_counters() -> void:
	var before := _pipeline_snapshot()
	print("PIPELINE before: ", before)

	# Believed non-compiling parameters (§11): energies, colors, glow intensity.
	key_light.light_energy = 2.0
	key_light.light_color = Color(1, 1, 1)
	env.glow_intensity = 1.9
	await process_frame
	await process_frame
	var after_noncompiling := _pipeline_snapshot()
	print("PIPELINE after non-compiling change (energy/color/glow intensity): ", after_noncompiling)

	# Believed compiling parameters (§11): glow enabled toggle, a light's shadow_enabled.
	env.glow_enabled = not env.glow_enabled
	set_light.shadow_enabled = not set_light.shadow_enabled
	await process_frame
	await process_frame
	var after_compiling := _pipeline_snapshot()
	print("PIPELINE after compiling change (glow_enabled + shadow_enabled toggle): ", after_compiling)


func _pipeline_snapshot() -> Dictionary:
	return {
		"canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		"mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		"surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		"draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		"specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
	}


func _probe_glow_hook(root: Window) -> void:
	glow_effect = GlowProbeEffect.new()
	glow_effect.effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	glow_effect.access_resolved_color = true
	var comp := Compositor.new()
	comp.compositor_effects = [glow_effect]
	battle_cam.compositor = comp
	battle_cam.make_current()
	await process_frame
	await process_frame
	await process_frame
	print("GLOW PROBE RESULT: ", glow_effect.result)
	print("GLOW PROBE NOTE: EFFECT_CALLBACK_TYPE enum max is POST_TRANSPARENT (4); no callback type exists between glow and tonemapping (both run in the engine's internal post-process chain after every CompositorEffect hook).")
