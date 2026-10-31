extends SceneTree
## P-15 / AC-64 benchmark (story sprite-camera-presentation 069,
## TR-presentation-016; ADR-0005 §11): nothing compiles a rendering pipeline
## in play. Two stages in one script:
##
##   1. Launcher (`--headless`, so it never opens a rendering device and never
##      rewrites a cache): deletes the engine's Vulkan pipeline cache
##      (`user://vulkan/pipelines.*.cache`) and both compiled-shader caches
##      (`res://.godot/shader_cache/`, `user://shader_cache/`), then launches
##      stage 2 as a fresh windowed process and returns its exit code.
##
##        godot --headless --path . -s res://tools/capture/pipeline_compile_benchmark.gd -- --empty-cache [--out=res://production/qa/benchmarks/] [--size=1280x720]
##
##   2. Measured run (windowed, a GPU; `--measure`): boots the real
##      `GameRoot` into the main viewport, waits for Boot (its warm-up stage
##      included) to reach an idle Title, reads the five
##      `Performance.PIPELINE_COMPILATIONS_*` monitors, plays the scripted
##      state cycle (New Game -> Overworld; Menu open/close; a Battle with two
##      squad attacks and the enemy's hits, the Menu over it, Victory and the
##      results confirm; the Bureaucratia boss takeover, Defeat, the Defeat
##      Prompt, Retry, Victory; the Megacorp boss takeover and Victory; Camp
##      and setting out), reads the monitors again, then runs the negative
##      control (an un-warmed Environment preset and an un-warmed material
##      switched on in the live Overworld). `viewport_set_measure_render_time`
##      is on throughout; every frame's CPU+GPU render time feeds the spike
##      guard (`performance.frame_time_worst_ms`, 33 ms).
##
## Writes `measurements.json` (counters before/after per step, worst frames,
## control result, device, cache state, driver caches present) into `--out`.
## Exit 0 iff `PipelineCompileCheck.verdict()` passes.
##
## A release export is the AC's target; run stage 2 against the exported
## binary with the same arguments once an export preset exists (story 069's
## write-up has the command).

const DEFAULT_OUT: String = "res://production/qa/benchmarks/"
const GAME_ROOT_SCENE: String = "res://src/game_state/game_root.tscn"
const SAVE_DIR: String = "user://pipeline_benchmark_saves"
const FRAME_TIME_WORST_MS: float = 33.0
## Frames each settled state is held on screen (ADR-0005 §11: >= 2).
const HOLD_FRAMES: int = 20
## A wait gives up after this many frames (a stuck flow fails the run).
const WAIT_CAP: int = 2400
## The measured run quits with code 2 after this long, whatever happened.
const WATCHDOG_S: float = 420.0

var _out_dir: String = DEFAULT_OUT
var _root_node: GameRoot = null
var _vp: RID
var _step: String = "boot"
## Per frame: the cycle's render times (ms) and their step labels.
var _cycle_ms: PackedFloat32Array = PackedFloat32Array()
var _recording: bool = false
var _worst_by_step: Dictionary = {}
var _wall_worst_by_step: Dictionary = {}
var _last_usec: int = 0
var _steps: Array[Dictionary] = []
var _flow_errors: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			args[a.substr(2)] = ""
	_out_dir = String(args.get("out", DEFAULT_OUT))
	if args.has("empty-cache"):
		quit(_launch(args))
		return
	if DisplayServer.get_name() == "headless":
		printerr("pipeline_compile_benchmark: the measured run needs a window; use --empty-cache to launch it")
		quit(1)
		return
	var dims: PackedStringArray = String(args.get("size", "1280x720")).split("x")
	var size := Vector2i(int(dims[0]), int(dims[1]))
	DisplayServer.window_set_size(size)
	root.size = size
	await _measure(args)


# --- Stage 1: the empty-cache launcher -------------------------------------

func _launch(args: Dictionary) -> int:
	var deleted: PackedStringArray = PackedStringArray()
	var vk: String = ProjectSettings.globalize_path(PipelineCompileCheck.PIPELINE_CACHE_DIR)
	var dir := DirAccess.open(vk)
	if dir != null:
		for f: String in dir.get_files():
			if PipelineCompileCheck.is_engine_pipeline_cache(f) and not f.ends_with(".editor.cache"):
				if DirAccess.remove_absolute(vk.path_join(f)) == OK:
					deleted.append(vk.path_join(f))
	for d: String in PipelineCompileCheck.SHADER_CACHE_DIRS:
		var abs_dir: String = ProjectSettings.globalize_path(d)
		if DirAccess.dir_exists_absolute(abs_dir):
			_remove_tree(abs_dir)
			deleted.append(abs_dir + "/")
	print("pipeline_compile_benchmark: emptied %d cache location(s)" % deleted.size())
	for p: String in deleted:
		print("  deleted ", p)
	var child_args: PackedStringArray = PackedStringArray(["--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tools/capture/pipeline_compile_benchmark.gd", "--", "--measure",
			"--out=%s" % _out_dir, "--size=%s" % String(args.get("size", "1280x720")),
			"--emptied=%s" % ";".join(deleted)])
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), child_args, output, true)
	for chunk: Variant in output:
		for line: String in String(chunk).split("\n"):
			if line.contains("pipeline_compile_benchmark") or line.contains("ERROR"):
				print(line)
	return code


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for f: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


# --- Stage 2: the measured run ---------------------------------------------

func _measure(args: Dictionary) -> void:
	var boot_usec: int = Time.get_ticks_usec()
	# A script error mid-cycle would leave the window open forever.
	create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		printerr("pipeline_compile_benchmark: watchdog fired at step %s" % _step)
		quit(2))
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_clear_saves()
	var packed: PackedScene = load(GAME_ROOT_SCENE) as PackedScene
	_root_node = packed.instantiate() as GameRoot
	_root_node.save_dir_override = SAVE_DIR
	root.add_child(_root_node)
	var m: GameStateMachine = _root_node.machine

	# Boot (its warm-up stage included) to an idle, settled Title.
	_step = "boot"
	await _wait_mode(GameStateMachine.Mode.TITLE)
	await _hold(HOLD_FRAMES)
	var boot_s: float = float(Time.get_ticks_usec() - boot_usec) / 1000000.0
	var before: Dictionary = PipelineCompileCheck.read_counters()
	var boot_counters: Dictionary = before.duplicate()
	_recording = true

	await _do("title_new_game_to_overworld", func() -> void:
		(_root_node.current_mode_node() as TitleMode)._on_new_game_pressed())
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _hold(HOLD_FRAMES)
	await _menu_open_close("overworld_menu")

	# Battle: two squad attacks (hits) and the enemies' hits back, Menu, Victory.
	await _battle_from_record("battle_entry", "enc_paris_clerks_hall")
	await _attack_round("battle_hit_1")
	await _attack_round("battle_hit_2")
	await _menu_open_close("battle_menu")
	await _force_and_finish("battle_victory", DebugLaunchArgs.VICTORY)

	# Bureaucratia boss: takeover, Defeat, Defeat Prompt, Retry, Victory.
	await _battle_from_record("boss_bureaucratia_takeover", "enc_paris_supervisor")
	await _force_and_finish("boss_bureaucratia_defeat", DebugLaunchArgs.DEFEAT)
	await _do("boss_bureaucratia_retry", func() -> void: m.choose_retry())
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	await _wait_squad_turn()
	await _hold(HOLD_FRAMES)
	await _force_and_finish("boss_bureaucratia_victory", DebugLaunchArgs.VICTORY)

	# Megacorp boss (no shipped encounter record yet: the ad-hoc fight story
	# 038 uses), takeover and Victory.
	var mega := EncounterDescriptor.new()
	mega.encounter_id = "enc_pipeline_benchmark_megacorp"
	mega.enemy_ids = PackedStringArray(["enemy_ceo", "enemy_security_drone"])
	mega.battle_stage_id = "stage_chapter_interim"
	mega.faction_id = "faction_megacorp"
	mega.is_boss = true
	await _battle(("boss_megacorp_takeover"), mega)
	await _force_and_finish("boss_megacorp_victory", DebugLaunchArgs.VICTORY)

	# Camp, and setting out again.
	var camp := CampEntryPayload.new()
	camp.camp_id = "camp_paris_pre_dungeon"
	await _do("camp_entry", func() -> void:
		_expect_ok("camp_entry", m.request_transition(GameStateMachine.Mode.CAMP, camp)))
	await _wait_mode(GameStateMachine.Mode.CAMP)
	await _hold(HOLD_FRAMES)
	await _menu_open_close("camp_menu")
	await _do("camp_set_out", func() -> void:
		var camp_mode: InterimCampMode = _root_node.current_mode_node() as InterimCampMode
		if camp_mode != null:
			camp_mode.handle_action(InputActions.CONFIRM, true)
		else:
			_flow_errors.append("camp_set_out: not in Camp"))
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _hold(HOLD_FRAMES)

	_recording = false
	var after: Dictionary = PipelineCompileCheck.read_counters()
	var cycle: Dictionary = PipelineCompileCheck.delta(before, after)

	# Negative control: an un-warmed preset switched on in the live Overworld.
	var control: Dictionary = await _negative_control()

	var v: Dictionary = PipelineCompileCheck.verdict(cycle, _cycle_ms, FRAME_TIME_WORST_MS,
			control["delta"], float(control["worst_ms"]))
	v["pass"] = bool(v["pass"]) and _flow_errors.is_empty()
	var rec: Dictionary = {
		"tool": "tools/capture/pipeline_compile_benchmark.gd",
		"benchmark": "P-15", "ac": "AC-64", "story": "sprite-camera-presentation 069",
		"date": Time.get_datetime_string_from_system(true),
		"build": "release export" if not OS.is_debug_build() else "development run (debug binary, windowed)",
		"engine": Engine.get_version_info()["string"],
		"device": {
			"adapter": RenderingServer.get_video_adapter_name(),
			"vendor": RenderingServer.get_video_adapter_vendor(),
			"api_version": RenderingServer.get_video_adapter_api_version(),
			"driver": OS.get_video_adapter_driver_info(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"window": [root.size.x, root.size.y],
		},
		"cache_state": {
			"emptied_before_launch": String(args.get("emptied", "")).split(";", false),
			"empty_cache_launch": args.has("emptied"),
			"pipeline_cache_enable": ProjectSettings.get_setting("rendering/rendering_device/pipeline_cache/enable"),
			"shader_cache_enabled": ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled"),
			"driver_caches_present": _driver_caches(),
		},
		"boot_seconds_to_title": boot_s,
		"boot_warmup": _root_node.warmup_report,
		"counters_after_boot": boot_counters,
		"counters_before_cycle": before,
		"counters_after_cycle": after,
		"cycle_delta": cycle,
		"steps": _steps,
		"worst_render_ms_by_step": _worst_by_step,
		"worst_wall_frame_ms_by_step": _wall_worst_by_step,
		"negative_control": control,
		"flow_errors": _flow_errors,
		"verdict": v,
		"result": "PASS" if bool(v["pass"]) else "FAIL",
	}
	var out_abs: String = ProjectSettings.globalize_path(_out_dir)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var f := FileAccess.open(out_abs.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rec, "  ", false))
	f.close()
	print("pipeline_compile_benchmark: %s cycle_delta=%s worst_render_ms=%.2f control=%s flow_errors=%d -> %s" % [
			rec["result"], cycle, float(v["worst_frame_ms"]), control["delta"], _flow_errors.size(), out_abs])
	_root_node.queue_free()
	await process_frame
	_clear_saves()
	quit(0 if bool(v["pass"]) else 1)


## One frame; records its render time (CPU + GPU, ms) while the cycle runs.
func _tick() -> void:
	await process_frame
	var now: int = Time.get_ticks_usec()
	var wall_ms: float = float(now - _last_usec) / 1000.0 if _last_usec > 0 else 0.0
	_last_usec = now
	if not _recording:
		return
	var ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_vp) \
			+ RenderingServer.viewport_get_measured_render_time_gpu(_vp)
	_cycle_ms.append(ms)
	_worst_by_step[_step] = maxf(float(_worst_by_step.get(_step, 0.0)), ms)
	_wall_worst_by_step[_step] = maxf(float(_wall_worst_by_step.get(_step, 0.0)), wall_ms)


func _hold(n: int) -> void:
	for i: int in n:
		await _tick()


## Starts a labelled step: runs `action`, records the counters it moved once
## the following step begins.
func _do(label: String, action: Callable) -> void:
	_begin_step(label)
	action.call()
	await _tick()


func _begin_step(label: String) -> void:
	if not _steps.is_empty():
		var prev: Dictionary = _steps[-1]
		prev["delta"] = PipelineCompileCheck.delta(prev["at_start"], PipelineCompileCheck.read_counters())
	_step = label
	_steps.append({"step": label, "at_start": PipelineCompileCheck.read_counters()})


func _wait_mode(mode: GameStateMachine.Mode) -> void:
	var m: GameStateMachine = _root_node.machine
	var n: int = 0
	while not (m.phase == GameStateMachine.Phase.IDLE and m.current_mode == mode) and n < WAIT_CAP:
		await _tick()
		n += 1
	if n >= WAIT_CAP:
		var bm: BattleMode = _root_node.current_mode_node() as BattleMode
		_flow_errors.append("%s: never reached mode %d (at mode %d, phase %d, overlays %s, pending %s, presenting %s)" % [
				_step, mode, m.current_mode, m.phase, m.overlay_stack, m.get("_pending_outcome"),
				bm.is_presenting() if bm != null else false])


func _menu_open_close(label: String) -> void:
	var m: GameStateMachine = _root_node.machine
	var payload := MenuPayload.new()
	var entries: Array[StringName] = [&"settings", &"quit"]
	if m.current_mode != GameStateMachine.Mode.BATTLE:
		entries = [&"pause", &"party", &"codex", &"settings", &"quit"]
	payload.entries = entries
	await _do(label + "_open", func() -> void:
		_expect_ok(label + "_open", m.open_overlay(GameStateMachine.OverlayKind.MENU, payload)))
	await _hold(HOLD_FRAMES)
	await _do(label + "_close", func() -> void: _expect_ok(label + "_close", m.close_overlay()))
	await _hold(HOLD_FRAMES)


func _battle_from_record(label: String, enc_id: String) -> void:
	var rec: EncounterData = _root_node.catalog().get_record(&"encounter", enc_id) as EncounterData
	await _battle(label, OverworldMode.build_descriptor(rec))


func _battle(label: String, d: EncounterDescriptor) -> void:
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	# The Overworld's own party source, as a symbol contact builds it.
	var ow: OverworldMode = _root_node.current_mode_node() as OverworldMode
	if ow != null and ow.party_source.is_valid():
		payload.party.assign(ow.party_source.call())
	else:
		_flow_errors.append("%s: no Overworld party source" % label)
	await _do(label, func() -> void:
		_expect_ok(label, _root_node.machine.request_transition(GameStateMachine.Mode.BATTLE, payload)))
	await _wait_mode(GameStateMachine.Mode.BATTLE)
	await _wait_squad_turn()
	await _hold(HOLD_FRAMES)


## Waits until the replay (the takeover included) has played out and the
## squad has the command menu.
func _wait_squad_turn() -> void:
	var n: int = 0
	while n < WAIT_CAP:
		var mode: BattleMode = _root_node.current_mode_node() as BattleMode
		if mode != null and mode.battle != null and mode.battle.state == BattleCore.State.SQUAD_TURN \
				and not mode.is_presenting():
			return
		await _tick()
		n += 1
	var bm: BattleMode = _root_node.current_mode_node() as BattleMode
	_flow_errors.append("%s: squad turn never came (mode %s, battle state %s, presenting %s)" % [_step,
			_root_node.current_mode_node(), bm.battle.state if bm != null and bm.battle != null else -1,
			bm.is_presenting() if bm != null else false])


## One squad Attack through the real command menu (Attack, first target),
## played out in real time with the enemies' replies.
func _attack_round(label: String) -> void:
	var mode: BattleMode = _root_node.current_mode_node() as BattleMode
	await _do(label, func() -> void:
		for i: int in 2:
			mode.handle_action(InputActions.CONFIRM, true)
			mode.handle_action(InputActions.CONFIRM, false))
	var n: int = 0
	while not mode.is_presenting() and n < 60:
		await _tick()
		n += 1
	await _wait_squad_turn()
	await _hold(HOLD_FRAMES)


## Forces the outcome, plays the last beat and the end-of-fight light in real
## time, then: Victory confirms the results and returns to the Overworld;
## Defeat waits on the Defeat Prompt.
func _force_and_finish(label: String, outcome: String) -> void:
	var mode: BattleMode = _root_node.current_mode_node() as BattleMode
	var m: GameStateMachine = _root_node.machine
	await _do(label, func() -> void: DebugLaunchArgs.force_outcome(mode.battle, outcome))
	var n: int = 0
	while m.overlay_stack.is_empty() and m.phase == GameStateMachine.Phase.IDLE \
			and not (outcome == DebugLaunchArgs.VICTORY and _pending_victory(m)) and n < WAIT_CAP:
		await _tick()
		n += 1
	await _hold(HOLD_FRAMES)
	if outcome == DebugLaunchArgs.DEFEAT:
		if not (GameStateMachine.OverlayKind.DEFEAT_PROMPT in m.overlay_stack):
			_flow_errors.append("%s: no Defeat Prompt" % label)
		return
	# The results confirm, pressed again every few frames until it is taken
	# (a press during the end-of-fight hold is consumed by design, story 067).
	await _do(label + "_results_confirm", func() -> void: pass)
	var k: int = 0
	while m.current_mode == GameStateMachine.Mode.BATTLE and m.phase == GameStateMachine.Phase.IDLE \
			and k < WAIT_CAP:
		if k % 15 == 0 and is_instance_valid(mode):
			mode.handle_action(InputActions.CONFIRM, true)
			mode.handle_action(InputActions.CONFIRM, false)
		await _tick()
		k += 1
	await _wait_mode(GameStateMachine.Mode.OVERWORLD)
	await _close_dialogues()
	await _hold(HOLD_FRAMES)


func _pending_victory(m: GameStateMachine) -> bool:
	return m.get("_pending_outcome") == GameStateMachine.BattleResult.VICTORY


## Plays any post-battle / opening Dialogue line to its close.
func _close_dialogues() -> void:
	var m: GameStateMachine = _root_node.machine
	var guard: int = 0
	while GameStateMachine.OverlayKind.DIALOGUE in m.overlay_stack and guard < 20:
		await _hold(HOLD_FRAMES)
		var line: InterimLineDialogue = _root_node.current_overlay_node() as InterimLineDialogue
		if line != null:
			line.advance_guard(1.0)
			line.handle_action(InputActions.CONFIRM, true)
			line.handle_action(InputActions.CONFIRM, false)
		var n: int = 0
		while m.phase != GameStateMachine.Phase.IDLE and n < WAIT_CAP:
			await _tick()
			n += 1
		guard += 1


func _expect_ok(label: String, r: GameStateMachine.RequestResult) -> void:
	if r != GameStateMachine.RequestResult.OK:
		_flow_errors.append("%s: request returned %d" % [label, r])


## The required negative control: features no shipped profile or material
## uses (so Boot never warms them) switched on in the live Overworld. Each
## part's counters and worst render frame are recorded separately.
func _negative_control() -> Dictionary:
	_recording = false
	var out: Dictionary = {"parts": {}}
	var total_delta: Dictionary = PipelineCompileCheck.delta({}, {})
	var worst: float = 0.0
	var mode: Node = _root_node.current_mode_node()
	var we: WorldEnvironment = _find_world_env(mode) if mode != null else null
	var cam: Camera3D = root.get_camera_3d()

	# Part 1: an Environment preset (SSAO, SSIL, fog and volumetric fog on).
	var c0: Dictionary = PipelineCompileCheck.read_counters()
	if we != null and we.environment != null:
		var env: Environment = we.environment
		env.ssao_enabled = true
		env.ssil_enabled = true
		env.fog_enabled = true
		env.volumetric_fog_enabled = true
	var w1: float = await _control_frames()
	var d1: Dictionary = PipelineCompileCheck.delta(c0, PipelineCompileCheck.read_counters())
	out["parts"]["environment_preset"] = {"fixture": "SSAO + SSIL + fog + volumetric fog on the live WorldEnvironment",
			"found_environment": we != null, "delta": d1, "worst_ms": w1}

	# Part 2: an un-warmed material (clearcoat, rim, subsurface, alpha + depth
	# pre-pass, double-sided) on a quad in front of the camera.
	var c1: Dictionary = PipelineCompileCheck.read_counters()
	var mi := MeshInstance3D.new()
	mi.name = "PipelineBenchmarkNegativeControl"
	mi.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.6, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.clearcoat_enabled = true
	mat.rim_enabled = true
	mat.subsurf_scatter_enabled = true
	mat.anisotropy_enabled = true
	mi.material_override = mat
	if cam != null:
		root.add_child(mi)
		mi.global_transform = Transform3D(Basis(), cam.global_position - cam.global_basis.z * 4.0)
	var w2: float = await _control_frames()
	var d2: Dictionary = PipelineCompileCheck.delta(c1, PipelineCompileCheck.read_counters())
	out["parts"]["material_fixture"] = {"fixture": "StandardMaterial3D: alpha depth pre-pass, cull off, clearcoat, rim, SSS, anisotropy",
			"camera_found": cam != null,
			"in_view": cam != null and cam.is_position_in_frustum(mi.global_position),
			"mode": str(mode), "delta": d2, "worst_ms": w2}
	if mi.is_inside_tree():
		mi.queue_free()
	else:
		mi.free()
	for k: String in total_delta:
		total_delta[k] = int(d1[k]) + int(d2[k])
	worst = maxf(w1, w2)
	out["delta"] = total_delta
	out["worst_ms"] = worst
	out["expected"] = "a counter rises (or a frame exceeds the limit)"
	return out


func _control_frames() -> float:
	var worst: float = 0.0
	for i: int in 30:
		await process_frame
		worst = maxf(worst, RenderingServer.viewport_get_measured_render_time_cpu(_vp)
				+ RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	return worst


func _find_world_env(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n as WorldEnvironment
	for c: Node in n.get_children():
		var w: WorldEnvironment = _find_world_env(c)
		if w != null:
			return w
	return null


## Which driver-level shader caches exist on this machine (ADR-0005 §11:
## invisible to the counters, not cleared, recorded).
func _driver_caches() -> Dictionary:
	var local: String = OS.get_environment("LOCALAPPDATA")
	var out: Dictionary = {}
	for p: String in [local.path_join("NVIDIA/DXCache"), local.path_join("NVIDIA/GLCache"),
			(local + "Low").path_join("NVIDIA/PerDriverVersion/DXCache"),
			local.path_join("AMD/VkCache"), local.path_join("AMD/DxcCache"),
			local.path_join("D3DSCache")]:
		out[p] = DirAccess.dir_exists_absolute(p)
	return out


func _clear_saves() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)
