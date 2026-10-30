## Story 099, AC-39 (GDD Formulas `chase_visibility`, I14): with the
## presentation example camera (pitch 30°, F_v 20°, dz 10%, tau 0.17), h 10 m
## fails naming the binding aspect and edge; h 11.5 m passes at 4:3, 16:9
## and 21:9. The tilt-shift bounds fail when the far blur begins before
## `d_cam(+s_blur)`, when the near blur ends past `d_cam(-s_blur) -
## H_max*sin(pitch)`, and when a bound is right from the focus but wrong
## from the leader at the dead-zone edge. The shipped config passes.
extends GdUnitTestSuite


func test_h_10_fails_naming_each_binding_aspect_and_edge() -> void:
	var errors: PackedStringArray = ChaseVisibility.validate(OverworldConfig.new(), _camera(10.0))
	var text: String = "\n".join(errors)
	assert_int(errors.size()).is_equal(3)
	assert_str(text).contains("at 4:3 the side edge R_e 4.26")
	assert_str(text).contains("at 16:9 the near edge R_e 4.27")
	assert_str(text).contains("at 21:9 the near edge R_e 4.27")


func test_h_11_5_passes_at_every_aspect() -> void:
	assert_array(Array(ChaseVisibility.validate(OverworldConfig.new(), _camera(11.5)))).is_empty()


func test_h_11_5_fails_at_4_3_at_the_knob_ceilings() -> void:
	var cam: PresentationConfig = _camera(11.5)
	cam.follow_camera_dead_zone_fraction = 0.12
	cam.follow_camera_tau = 0.18
	var errors: PackedStringArray = ChaseVisibility.validate(OverworldConfig.new(), cam)
	assert_str("\n".join(errors)).contains("at 4:3 the side edge R_e 4.68")


func test_far_blur_beginning_before_d_cam_s_blur_fails() -> void:
	var cam: PresentationConfig = _camera(11.5)
	var cfg := OverworldConfig.new()
	var far: float = ChaseVisibility.d_cam(_worst_blur(cfg, cam), cam)
	var ok: LightingProfile = _profile(-1.0, far + 0.01)
	assert_array(Array(ChaseVisibility.validate(cfg, cam, ok))).is_empty()
	var bad: LightingProfile = _profile(-1.0, far - 0.1)
	assert_str("\n".join(ChaseVisibility.validate(cfg, cam, bad))).contains("dof_far_begin")


func test_near_blur_ending_past_the_card_top_fails() -> void:
	var cam: PresentationConfig = _camera(11.5)
	var cfg := OverworldConfig.new()
	var pitch: float = deg_to_rad(cam.follow_camera_pitch_degrees)
	var limit: float = ChaseVisibility.d_cam(-_worst_blur(cfg, cam), cam) \
			- cam.overworld_card_height_max_m * sin(pitch)
	assert_array(Array(ChaseVisibility.validate(cfg, cam, _profile(limit - 0.01, -1.0)))).is_empty()
	assert_str("\n".join(ChaseVisibility.validate(cfg, cam, _profile(limit + 0.1, -1.0)))) \
			.contains("dof_near_end")


func test_a_far_bound_right_from_the_focus_but_wrong_from_the_leader_fails() -> void:
	var cam: PresentationConfig = _camera(11.5)
	var cfg := OverworldConfig.new()
	# Sharp out to see_m from the focus, but not out to s_blur (the leader can
	# sit dz_y + walk_speed*tau ahead of the focus).
	var from_focus: float = ChaseVisibility.d_cam(cfg.see_m(), cam)
	assert_float(from_focus).is_less(ChaseVisibility.d_cam(_worst_blur(cfg, cam), cam))
	var errors: PackedStringArray = ChaseVisibility.validate(cfg, cam, _profile(-1.0, from_focus + 0.01))
	assert_str("\n".join(errors)).contains("dof_far_begin")


func test_the_shipped_config_passes_at_every_aspect() -> void:
	for path: String in ["res://data/presentation/profiles/overworld.tres",
			"res://data/presentation/profiles/overworld_liberated.tres"]:
		var errors: PackedStringArray = ChaseVisibility.validate(OverworldConfig.new(),
				PresentationConfig.new(), load(path) as LightingProfile)
		assert_array(Array(errors)).override_failure_message("%s: %s" % [path, errors]).is_empty()


func test_s_blur_matches_the_gdd_default() -> void:
	# GDD: at the defaults s_blur = 4.70 + 0.54 + 0.595 = 5.84 m (16:9, h 10).
	assert_float(ChaseVisibility.blur_reach(OverworldConfig.new(), _camera(10.0), 16.0 / 9.0)) \
			.is_equal_approx(5.84, 0.01)


## The largest `s_blur` over the aspects (4:3's taller `a_near`).
func _worst_blur(cfg: OverworldConfig, cam: PresentationConfig) -> float:
	var worst: float = 0.0
	for aspect: float in ChaseVisibility.ASPECTS:
		worst = maxf(worst, ChaseVisibility.blur_reach(cfg, cam, aspect))
	return worst


func _camera(h: float) -> PresentationConfig:
	var cam := PresentationConfig.new()
	cam.follow_camera_height = h
	cam.follow_camera_pitch_degrees = 30.0
	cam.follow_camera_fov_degrees = 20.0
	cam.follow_camera_dead_zone_fraction = 0.10
	cam.follow_camera_tau = 0.17
	return cam


## A profile blurring near up to `near_end` and far from `far_begin`; a
## negative value leaves that blur off.
func _profile(near_end: float, far_begin: float) -> LightingProfile:
	var p := LightingProfile.new()
	p.dof_near_enabled = near_end >= 0.0
	p.dof_near_distance = maxf(near_end, 0.0)
	p.dof_far_enabled = far_begin >= 0.0
	p.dof_far_distance = maxf(far_begin, 0.0)
	return p
