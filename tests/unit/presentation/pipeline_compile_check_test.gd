## Story sprite-camera-presentation 069 (AC-64, TR-presentation-016): nothing
## compiles a rendering pipeline in play. The measurement needs a window and a
## GPU (`tools/capture/pipeline_compile_benchmark.gd`, record in
## `production/qa/benchmarks/`); this suite checks what the verdict is
## computed from: the five monitors, the counter delta, the spike guard, the
## negative control and the empty-cache file list.
extends GdUnitTestSuite


func _counters(canvas: int, mesh: int, surface: int, draw: int, spec: int) -> Dictionary:
	return {"canvas": canvas, "mesh": mesh, "surface": surface, "draw": draw, "specialization": spec}


func test_monitors_name_all_five_pipeline_counters() -> void:
	assert_array(PipelineCompileCheck.MONITORS.keys()).contains_exactly_in_any_order(
			["canvas", "mesh", "surface", "draw", "specialization"])
	assert_int(int(PipelineCompileCheck.MONITORS["canvas"])).is_equal(Performance.PIPELINE_COMPILATIONS_CANVAS)
	assert_int(int(PipelineCompileCheck.MONITORS["specialization"])).is_equal(
			Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)


func test_read_counters_returns_an_int_per_monitor() -> void:
	var c: Dictionary = PipelineCompileCheck.read_counters()
	assert_int(c.size()).is_equal(5)
	for k: String in c:
		assert_bool(c[k] is int).is_true()


func test_delta_unchanged_counters_is_all_zero() -> void:
	var d: Dictionary = PipelineCompileCheck.delta(_counters(3, 1, 9, 2, 9), _counters(3, 1, 9, 2, 9))
	assert_int(PipelineCompileCheck.total(d)).is_equal(0)


func test_delta_one_risen_counter_reports_only_it() -> void:
	var d: Dictionary = PipelineCompileCheck.delta(_counters(3, 1, 9, 2, 9), _counters(3, 1, 11, 2, 9))
	assert_int(int(d["surface"])).is_equal(2)
	assert_int(PipelineCompileCheck.total(d)).is_equal(2)


func test_verdict_clean_cycle_quiet_frames_and_rising_control_passes() -> void:
	var v: Dictionary = PipelineCompileCheck.verdict(
			_counters(0, 0, 0, 0, 0), PackedFloat32Array([5.0, 12.0, 33.0]), 33.0, _counters(0, 0, 1, 0, 0), 0.0)
	assert_bool(bool(v["pass"])).is_true()
	assert_float(float(v["worst_frame_ms"])).is_equal(33.0)


func test_verdict_one_compile_in_the_cycle_fails() -> void:
	var v: Dictionary = PipelineCompileCheck.verdict(
			_counters(0, 0, 0, 0, 1), PackedFloat32Array([5.0]), 33.0, _counters(0, 0, 1, 0, 0), 0.0)
	assert_bool(bool(v["cycle_unchanged"])).is_false()
	assert_bool(bool(v["pass"])).is_false()


func test_verdict_frame_over_limit_fails() -> void:
	var v: Dictionary = PipelineCompileCheck.verdict(
			_counters(0, 0, 0, 0, 0), PackedFloat32Array([5.0, 33.5]), 33.0, _counters(1, 0, 0, 0, 0), 0.0)
	assert_bool(bool(v["no_spike"])).is_false()
	assert_bool(bool(v["pass"])).is_false()


func test_verdict_control_caught_by_spike_only_still_discriminates() -> void:
	var v: Dictionary = PipelineCompileCheck.verdict(
			_counters(0, 0, 0, 0, 0), PackedFloat32Array([5.0]), 33.0, _counters(0, 0, 0, 0, 0), 40.0)
	assert_bool(bool(v["control_discriminates"])).is_true()


func test_verdict_silent_control_fails_the_run() -> void:
	var v: Dictionary = PipelineCompileCheck.verdict(
			_counters(0, 0, 0, 0, 0), PackedFloat32Array([5.0]), 33.0, _counters(0, 0, 0, 0, 0), 10.0)
	assert_bool(bool(v["control_discriminates"])).is_false()
	assert_bool(bool(v["pass"])).is_false()


func test_verdict_no_frames_measured_never_passes() -> void:
	var v: Dictionary = PipelineCompileCheck.verdict(
			_counters(0, 0, 0, 0, 0), PackedFloat32Array(), 33.0, _counters(0, 1, 0, 0, 0), 0.0)
	assert_bool(bool(v["pass"])).is_false()


func test_is_engine_pipeline_cache_matches_vulkan_pipeline_files_only() -> void:
	assert_bool(PipelineCompileCheck.is_engine_pipeline_cache(
			"pipelines.forward_plus.nvidia_geforce_rtx_4080_super.cache")).is_true()
	assert_bool(PipelineCompileCheck.is_engine_pipeline_cache(
			"pipelines.forward_plus.nvidia_geforce_rtx_4080_super.editor.cache")).is_true()
	assert_bool(PipelineCompileCheck.is_engine_pipeline_cache("settings.cfg")).is_false()
	assert_bool(PipelineCompileCheck.is_engine_pipeline_cache("pipelines.txt")).is_false()
