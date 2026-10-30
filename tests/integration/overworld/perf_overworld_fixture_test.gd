## Story 133 (TR-overworld-005, test plan O-08 / OW-T01): the
## `perf_overworld` fixture, the `no_contact` / `no_giveup` /
## `notice_cache_off` debug flags, the leader-oscillation hook, the per-frame
## `step_symbols()` timer, its `Performance` custom monitor and the CSV
## logger work as specified. Measures nothing against the budget (story 114).
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0
const _CSV_DIR: String = "user://perf_133_test"
const _FIXED_FRAME_MS: float = 16.0


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(_CSV_DIR)
	if dir != null:
		for f: String in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(_CSV_DIR)
	if Performance.has_custom_monitor(OverworldPerfProbe.MONITOR_ID):
		Performance.remove_custom_monitor(OverworldPerfProbe.MONITOR_ID)


func _spec(path: String) -> PerfOverworldSpec:
	return (load(path) as PerfOverworldSpec).duplicate()


func _mode(cfg: OverworldConfig) -> OverworldMode:
	var env: Dictionary = GameStateFixtures.make_machine_in_overworld()
	var mode := OverworldMode.new()
	mode.config = cfg
	mode.setup(env["machine"] as GameStateMachine, null)
	var catalog := RecordCatalogDouble.new()
	catalog.add(&"encounter", RecordCatalogDouble.make_encounter(PerfOverworldFixture.ENC_ID))
	mode.encounter_catalog = catalog
	return auto_free(mode)


func _count_in(mode: OverworldMode, sub: SymbolBrain.SubState) -> int:
	var n: int = 0
	for b: SymbolBrain in mode.get_symbol_brains():
		if b.sub_state == sub:
			n += 1
	return n


func _queries(mode: OverworldMode) -> int:
	var q: int = 0
	for b: SymbolBrain in mode.get_symbol_brains():
		q += b.queries_granted
	return q


func _expected_n(spec: PerfOverworldSpec, cfg: OverworldConfig) -> int:
	var w: int = spec.grid_size.x * spec.grid_size.y
	if spec.perf_case == PerfOverworldSpec.PerfCase.FENCED:
		w -= spec.grid_size.x - 1
	var d_min: int = cfg.d_min_dungeon if spec.map_record.density_type == "dungeon" else cfg.d_min_overworld
	return floori(float(w) / d_min + 0.5)


func test_fixture_record_is_stage_3_with_three_followers_and_tilt_shift() -> void:
	for path: String in [PerfOverworldFixture.CHASE_SPEC_PATH, PerfOverworldFixture.FENCED_SPEC_PATH]:
		var spec: PerfOverworldSpec = _spec(path)
		assert_str(spec.map_record.id).is_equal("map_perf_overworld")
		assert_int(spec.map_record.base_stage).is_equal(3)
		assert_int(spec.follower_count).is_equal(3)
		assert_bool(spec.tilt_shift).is_true()


func test_symbol_count_defaults_to_n_max_for_default_and_tuned_config() -> void:
	var tuned := OverworldConfig.new()
	tuned.d_min_dungeon = 60
	tuned.d_min_overworld = 100
	for cfg: OverworldConfig in [OverworldConfig.new(), tuned]:
		for path: String in [PerfOverworldFixture.CHASE_SPEC_PATH, PerfOverworldFixture.FENCED_SPEC_PATH]:
			var spec: PerfOverworldSpec = _spec(path)
			var mode: OverworldMode = _mode(cfg)
			PerfOverworldFixture.new().populate(mode, spec)
			assert_int(mode.get_encounter_sources().size()).is_equal(_expected_n(spec, cfg))


func test_symbol_count_override_wins() -> void:
	var spec: PerfOverworldSpec = _spec(PerfOverworldFixture.CHASE_SPEC_PATH)
	spec.symbol_count = 7
	var mode: OverworldMode = _mode(OverworldConfig.new())
	PerfOverworldFixture.new().populate(mode, spec)
	assert_int(mode.get_encounter_sources().size()).is_equal(7)


func test_chase_case_with_flags_keeps_every_symbol_chasing_and_never_freezes() -> void:
	var cfg := OverworldConfig.new()
	PerfOverworldFixture.apply_debug_flags(cfg)
	var mode: OverworldMode = _mode(cfg)
	mode.grace_active = false
	var fixture := PerfOverworldFixture.new()
	fixture.populate(mode, _spec(PerfOverworldFixture.CHASE_SPEC_PATH))
	var n: int = mode.get_encounter_sources().size()
	var frames: int = ceili((cfg.notice_delay_s + cfg.giveup_s) * 2.0 / _DT)
	for f: int in frames:
		fixture.step(mode, f, _DT, false)
	assert_int(mode.get_state()).is_equal(OverworldMode.State.EXPLORING)
	assert_int(_count_in(mode, SymbolBrain.SubState.CHASING)).is_equal(n)
	# Leader far away: every chase is "beyond", yet no_giveup holds it.
	mode.set_leader_position(Vector2(0.5, 0.5))
	for f: int in ceili(cfg.giveup_s * 2.0 / _DT):
		fixture.step(mode, f, _DT, false)
	assert_int(_count_in(mode, SymbolBrain.SubState.CHASING)).is_equal(n)


func test_chase_case_without_flags_contacts_and_freezes() -> void:
	var mode: OverworldMode = _mode(OverworldConfig.new())
	mode.grace_active = false
	var fixture := PerfOverworldFixture.new()
	fixture.populate(mode, _spec(PerfOverworldFixture.CHASE_SPEC_PATH))
	var frames: int = ceili((mode.config.notice_delay_s + mode.config.giveup_s) * 2.0 / _DT)
	for f: int in frames:
		fixture.step(mode, f, _DT, false)
		if mode.get_state() != OverworldMode.State.EXPLORING:
			break
	assert_int(mode.get_state()).is_equal(OverworldMode.State.FROZEN)


func test_giveup_reverts_chase_without_no_giveup() -> void:
	var cfg := OverworldConfig.new()
	PerfOverworldFixture.apply_debug_flags(cfg)
	var mode: OverworldMode = _mode(cfg)
	mode.grace_active = false
	var fixture := PerfOverworldFixture.new()
	fixture.populate(mode, _spec(PerfOverworldFixture.CHASE_SPEC_PATH))
	for f: int in ceili(cfg.notice_delay_s * 2.0 / _DT):
		fixture.step(mode, f, _DT, false)
	cfg.no_giveup = false
	mode.set_leader_position(Vector2(0.5, 0.5))
	for f: int in ceili(cfg.giveup_s * 2.0 / _DT):
		fixture.step(mode, f, _DT, false)
	assert_int(_count_in(mode, SymbolBrain.SubState.CHASING)).is_equal(0)


func _fenced_queries_per_frame(oscillate: bool, cache_off: bool) -> Array[int]:
	var cfg := OverworldConfig.new()
	PerfOverworldFixture.apply_debug_flags(cfg, cache_off)
	var mode: OverworldMode = _mode(cfg)
	mode.grace_active = false
	var fixture := PerfOverworldFixture.new()
	fixture.populate(mode, _spec(PerfOverworldFixture.FENCED_SPEC_PATH))
	var out: Array[int] = []
	for f: int in 60:
		var before: int = _queries(mode)
		fixture.step(mode, f, _DT, oscillate)
		out.append(_queries(mode) - before)
	assert_int(_count_in(mode, SymbolBrain.SubState.PATROL)).is_equal(mode.get_encounter_sources().size())
	return out


func test_fenced_case_oscillation_runs_a_search_every_frame() -> void:
	var per_frame: Array[int] = _fenced_queries_per_frame(true, false)
	for q: int in per_frame.slice(1):
		assert_int(q).is_greater(0)


func test_fenced_case_cache_off_runs_a_search_every_frame() -> void:
	var per_frame: Array[int] = _fenced_queries_per_frame(false, true)
	for q: int in per_frame.slice(1):
		assert_int(q).is_greater(0)


func test_fenced_case_cache_on_still_leader_stops_searching() -> void:
	var per_frame: Array[int] = _fenced_queries_per_frame(false, false)
	assert_int(per_frame.slice(10).max()).is_equal(0)


func test_probe_records_each_frame_feeds_monitor_and_writes_csv() -> void:
	var cfg := OverworldConfig.new()
	PerfOverworldFixture.apply_debug_flags(cfg)
	var mode: OverworldMode = _mode(cfg)
	var fixture := PerfOverworldFixture.new()
	fixture.populate(mode, _spec(PerfOverworldFixture.FENCED_SPEC_PATH))
	var probe := OverworldPerfProbe.new()
	probe.frame_ms_source = func() -> float: return _FIXED_FRAME_MS
	probe.attach(mode)
	probe.register_monitor()
	assert_bool(Performance.has_custom_monitor(OverworldPerfProbe.MONITOR_ID)).is_true()
	var frames: int = 30
	for f: int in frames:
		fixture.step(mode, f, _DT, true)
	assert_int(probe.frame_count()).is_equal(frames)
	assert_float(probe.overworld_ms[0]).is_greater_equal(0.0)
	assert_float(Performance.get_custom_monitor(OverworldPerfProbe.MONITOR_ID)) \
			.is_equal_approx(probe.last_overworld_ms, 1e-9)
	var path: String = OverworldPerfProbe.csv_path("s133", _CSV_DIR)
	assert_int(probe.write_csv(path)).is_equal(OK)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert_int(lines.size()).is_equal(frames + 1)
	assert_str(lines[0]).is_equal(OverworldPerfProbe.CSV_HEADER)
	assert_str(lines[1].split(",")[1]).is_equal("%.4f" % _FIXED_FRAME_MS)
	probe.detach(mode)
	fixture.step(mode, frames, _DT, true)
	assert_int(probe.frame_count()).is_equal(frames)
	probe.unregister_monitor()
	assert_bool(Performance.has_custom_monitor(OverworldPerfProbe.MONITOR_ID)).is_false()


func test_probe_quantile_is_nearest_rank_and_default_csv_dir() -> void:
	var probe := OverworldPerfProbe.new()
	assert_float(probe.quantile_ms(0.99)).is_equal(0.0)
	for i: int in 100:
		probe.overworld_ms.append(float(i + 1))
	assert_float(probe.quantile_ms(0.99)).is_equal(99.0)
	assert_float(probe.quantile_ms(0.5)).is_equal(50.0)
	assert_str(OverworldPerfProbe.csv_path("a")).is_equal(
			"res://production/qa/evidence/perf/overworld_a.csv")
