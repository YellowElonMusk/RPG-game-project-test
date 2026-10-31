extends SceneTree
## Story 060's [C] run (GDD sprite-camera-presentation AC-55b; test plan
## P-13; ADR-0005 §12): scripted battle sequences recorded frame by frame
## from a windowed run, each final composited frame (world and UI together,
## the root viewport) fed to `FlashAnalyser`. Every sequence runs with Reduce
## Flashing Off and On (the gate's `FlashSettings`). Run it with a fixed
## frame step so every grabbed frame is exactly 1/60 s of game time:
##
##   godot --path . --fixed-fps 60 -s res://tools/capture/flash_sequence_capture.gd [-- --only=hits_1x,victory --out=<dir>]
##
## The real `BattleMode` boots under a stand-in `ModeHost` with a real
## `FlashGate` on a frame clock (frame n = n/60 s), so the impact bursts ask
## the gate exactly as in the game. Game State's battle wipe IN and retry
## flash are reproduced with the shipped `InterimFadePresenter` on their
## `TransitionConfig` durations and requested from the same gate. A Menu is
## the loader's ModeHost disable plus the Director's ambient pause (as
## `menu_freeze_capture.gd`); no Menu panel is drawn.
##
## Negative control: `neg_strobe` lays a full-screen white/black strobe
## (5 Hz) over a 1x hit sequence and must FAIL. Observation:
## `obs_gate_bypassed` is the latched sequence with no gate (bursts always
## full). `obs_fast_menu` is the 1x hit sequence with a 0.25 s pick per
## command (the command menu panel toggling fast). Writes per run `luma_plot.png`, `contact_sheet.png`, up to four
## full frames at events, and one `measurements.json`. Exit 0 iff every
## sequence passes (and Reduce Flashing On has no flash outside the boss
## flood) and the negative control fails.

const SIZE := Vector2i(1280, 720)
const FPS: int = 60
const ANALYSIS_H: int = 90
const DEFAULT_OUT: String = "res://production/qa/evidence/composite-flash-sequences/"
const ENC_PLAIN: String = "enc_paris_clerks_hall"
const ENC_BOSS: String = "enc_paris_supervisor"
const SHEET_EVERY: int = 12
const SHEET_COLS: int = 10
const MAX_EVENT_SHOTS: int = 4
## Frames the screen stays covered before the wipe's IN starts.
const COVERED_FRAMES: int = 6
## Frames a scripted player takes to choose once a command menu appears
## (0.6 s: a deliberate human pick of Attack and a target).
const DECISION_FRAMES: int = 36
## The fast-input observation: 0.25 s per pick (just past `input_guard`).
const FAST_DECISION_FRAMES: int = 15
## The Menu's length in the menu sequence (1 s).
const MENU_FRAMES: int = 60
## Strobe half-period in frames (5 Hz full cycle).
const STROBE_HALF: int = 6

const SEQUENCES: Array[String] = ["boss_takeover", "hits_1x", "hits_latched", "victory",
		"defeat_retry", "menu_during_replay"]

var _catalog: ContentCatalogService
var _decls: Dictionary[StringName, FlashSourceDecl] = {}
var _config := PresentationConfig.new()
var _transitions: TransitionConfig
var _out_dir: String = ""

# Per-run state.
var _frame_no: int = 0
var _analyser: FlashAnalyser
var _tiles: Array[Image] = []
var _shots: int = 0
var _run_dir: String = ""
var _mode: BattleMode
var _host: Node
var _gate: FlashGate
var _fade: InterimFadePresenter
var _layer: CanvasLayer
var _auto_latch: bool = false
var _decision_frames: int = DECISION_FRAMES
var _flood_spans: Array[Vector2i] = []
var _flood_start: int = -1
var _requests: Array[Dictionary] = []
var _notes: Array[String] = []
var _latches: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_out_dir = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	_catalog = BattleCatalog.shipped()
	var boot: ContentBootResult = ContentBootstrap.run(_catalog)
	if boot == null or _catalog.state != ContentCatalogService.State.READY:
		printerr("flash_sequence_capture: content boot failed: %s" % [_catalog.report])
		quit(1)
		return
	for decl: FlashSourceDecl in PresentationValidators.load_flash_sources():
		_decls[decl.source_id] = decl
	_transitions = load("res://data/config/transition_config.tres") as TransitionConfig
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var runs: Array[Dictionary] = []
	for seq: String in SEQUENCES:
		if not only.is_empty() and not only.has(seq):
			continue
		for rf_on: bool in [false, true]:
			runs.append(await _record(seq, rf_on, true))
	if only.is_empty() or only.has("neg_strobe"):
		runs.append(await _record("neg_strobe", false, true))
	if only.is_empty() or only.has("obs_gate_bypassed"):
		runs.append(await _record("obs_gate_bypassed", false, false))
	if only.is_empty() or only.has("obs_fast_menu"):
		runs.append(await _record("obs_fast_menu", false, true))

	var all_pass := true
	var neg_failed := true
	var has_neg := false
	for r: Dictionary in runs:
		if r["sequence"] == "neg_strobe":
			has_neg = true
			neg_failed = not bool(r["pass"])
		elif not String(r["sequence"]).begins_with("obs_"):
			all_pass = all_pass and bool(r["pass"])
	var m: Dictionary = {
		"tool": "tools/capture/flash_sequence_capture.gd + tools/capture/flash_analyser.gd",
		"ac": "AC-55b", "procedure": "P-13", "size": [SIZE.x, SIZE.y], "fps": FPS,
		"analysis_h": ANALYSIS_H, "flash_rate_max": _config.flash_rate_max,
		"flash_luma_delta": _config.flash_luma_delta, "flash_area_min": _config.flash_area_min,
		"engine": Engine.get_version_info()["string"], "adapter": RenderingServer.get_video_adapter_name(),
		"all_sequences_pass": all_pass,
		"negative_control_fails": neg_failed if has_neg else null,
		"runs": runs,
	}
	var f := FileAccess.open(_out_dir.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "  ", false))
	f.close()
	for r: Dictionary in runs:
		print("flash_sequence_capture: %-20s RF=%-3s frames=%4d general_max=%d red_max=%d outside_flood=%d -> %s" % [
				r["sequence"], "On" if r["reduce_flashing"] else "Off", r["frames"],
				r["general_max_per_window"], r["red_max_per_window"],
				(r["flashes_outside_flood"] as Array).size(), "PASS" if r["pass"] else "FAIL"])
	print("flash_sequence_capture: sequences %s; negative control %s; wrote %s" % [
			"PASS" if all_pass else "FAIL",
			("FAILS as expected" if neg_failed else "DID NOT FAIL") if has_neg else "not run", _out_dir])
	quit(0 if all_pass and (neg_failed or not has_neg) else 1)


## Boots, plays and analyses one sequence; returns its record.
func _record(seq: String, rf_on: bool, use_gate: bool) -> Dictionary:
	var run_name: String = "%s_rf_%s" % [seq, "on" if rf_on else "off"]
	_run_dir = _out_dir.path_join(run_name)
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_frame_no = 0
	_analyser = FlashAnalyser.new(FPS, _config.flash_luma_delta, _config.flash_area_min, _config.flash_rate_max)
	_tiles.clear()
	_shots = 0
	_auto_latch = seq == "hits_latched" or seq == "obs_gate_bypassed"
	_decision_frames = FAST_DECISION_FRAMES if seq == "obs_fast_menu" else DECISION_FRAMES
	_flood_spans.clear()
	_flood_start = -1
	_requests.clear()
	_notes.clear()
	_latches = 0
	var enc: String = ENC_BOSS if seq == "boss_takeover" else ENC_PLAIN
	if not _boot(enc, rf_on, use_gate):
		return {"sequence": seq, "reduce_flashing": rf_on, "pass": false, "frames": 0,
				"general_max_per_window": -1, "red_max_per_window": -1, "flashes_outside_flood": [],
				"error": "boot failed"}
	await _reveal()
	match seq:
		"boss_takeover":
			await _until(func() -> bool: return _flood_start < 0 and not _flood_spans.is_empty(), 1200)
			await _hold(60)
		"hits_1x", "hits_latched", "obs_gate_bypassed", "obs_fast_menu":
			for i: int in 4:
				await _attack()
			await _settle()
		"victory":
			for e: Combatant in _mode.battle.enemies:
				e.hp = 1
			for i: int in 8:
				if _mode.battle.state == BattleCore.State.WON:
					break
				await _attack()
			await _settle()
			_notes.append("results screen not built (UI Framework): the run ends on the Victory hold; no confetti or victory burst source is wired yet")
		"defeat_retry":
			var snapshot: RefCounted = _mode.capture_start_snapshot()
			await _hold(30)
			DebugLaunchArgs.force_outcome(_mode.battle, DebugLaunchArgs.DEFEAT)
			await _settle()
			await _retry(snapshot)
			await _hold(90)
			_notes.append("Defeat card stamp not built (UI Framework); retry flash reproduced with InterimFadePresenter; no machine, so restore_start_snapshot takes the uncapped (instant) light path even when the gate caps the flash")
		"menu_during_replay":
			await _attack()
			await _until(func() -> bool: return _mode.replay.get_windup_progress() > 0.0, 600)
			_host.process_mode = Node.PROCESS_MODE_DISABLED
			(_mode.get_node(^"%DioramaStage") as DioramaStage).set_ambient_paused(true)
			await _hold(MENU_FRAMES)
			(_mode.get_node(^"%DioramaStage") as DioramaStage).set_ambient_paused(false)
			_host.process_mode = Node.PROCESS_MODE_INHERIT
			await _settle()
			_notes.append("Menu = ModeHost disabled + ambient pause for 1 s mid-wind-up; the Menu backdrop panel is not built")
		"neg_strobe":
			var strobe := ColorRect.new()
			strobe.set_anchors_preset(Control.PRESET_FULL_RECT)
			strobe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_layer.add_child(strobe)
			for i: int in 120:
				strobe.color = Color.WHITE if (i / STROBE_HALF) % 2 == 0 else Color.BLACK
				await _step()
			strobe.queue_free()
			await _hold(30)
	var result: Dictionary = _finish(seq, rf_on, use_gate, enc)
	await _teardown()
	return result


func _boot(enc_id: String, rf_on: bool, use_gate: bool) -> bool:
	var rec: EncounterData = _catalog.get_record(&"encounter", enc_id) as EncounterData
	if rec == null:
		return false
	var d := EncounterDescriptor.new()
	d.encounter_id = rec.id
	d.enemy_ids = rec.enemy_ids
	d.battle_stage_id = rec.battle_stage_id
	d.faction_id = rec.faction_id
	d.is_boss = rec.is_boss
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = ChapterFlow.build_squad(_catalog)
	var settings := FlashSettings.new()
	settings.reduce_flashing_on = rf_on
	_gate = FlashGate.new()
	_gate.name = "FlashGate"
	root.add_child(_gate)
	_gate.setup(_frame_clock_us, _config, _decls, settings)
	_host = Node.new()
	_host.name = "ModeHost"
	root.add_child(_host)
	_mode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	if use_gate:
		_mode.flash_gate = _gate
	_mode.setup(null, payload)
	_host.add_child(_mode)
	var stage: DioramaStage = _mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	_mode.replay.hold_started.connect(_on_hold_started)
	_mode.replay.hold_finished.connect(_on_hold_finished)
	_mode.replay.latch_changed.connect(func(on: bool) -> void: _latches += 1 if on else 0)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	root.add_child(_layer)
	_fade = InterimFadePresenter.new(_layer, _transitions)
	return true


## The battle wipe's IN over a covered screen, then the reveal.
func _reveal() -> void:
	var capped: bool = _request(&"battle_wipe", FlashSourceDecl.CLOCK_REAL)
	_fade.play_out(&"battle_wipe", 0.0, capped)
	for i: int in COVERED_FRAMES:
		await _step()
	var t_in: float = float(_transitions.t_in.get(&"battle_wipe", 0.25))
	_fade.play_in(&"battle_wipe", t_in, capped)
	await _hold(roundi(t_in * FPS))
	_mode._on_transition_finished(GameStateMachine.Mode.BATTLE)


## The retry flash (OUT, swap, IN), as Game State plays it.
func _retry(snapshot: RefCounted) -> void:
	var capped: bool = _request(&"retry_flash", FlashSourceDecl.CLOCK_REAL)
	var t_out: float = float(_transitions.t_out.get(&"retry_flash", 0.15))
	var t_in: float = float(_transitions.t_in.get(&"retry_flash", 0.15))
	_fade.play_out(&"retry_flash", t_out, capped)
	await _hold(roundi(t_out * FPS))
	_mode.restore_start_snapshot(snapshot)
	_fade.play_in(&"retry_flash", t_in, capped)
	await _hold(roundi(t_in * FPS))
	_mode._on_transition_finished(GameStateMachine.Mode.BATTLE)


## Asks the gate at the start of OUT (as `GameStateMachine` does) and
## returns `capped`, passed to both `play_out` and `play_in`.
func _request(source: StringName, clock_kind: StringName) -> bool:
	var at: int = _frame_no
	var handle: int = _gate.request(source, func() -> float: return float(at) / FPS, 1.0)
	_requests.append({"source": String(source), "clock": String(clock_kind), "frame": at,
			"capped": handle == FlashGate.REFUSED})
	return handle == FlashGate.REFUSED


## A squad Attack on the first target through the real command menu.
func _attack() -> void:
	await _until(func() -> bool:
		return _mode.battle.state == BattleCore.State.SQUAD_TURN and not _mode.is_presenting() \
				and _mode.replay.get_state() == BattleReplayController.State.IDLE, 900)
	if _mode.battle.state != BattleCore.State.SQUAD_TURN:
		return
	await _hold(_decision_frames)
	for i: int in 2:
		_mode.handle_action(InputActions.CONFIRM, true)
		_mode.handle_action(InputActions.CONFIRM, false)
	await _step()


## Steps until the replay and the end hold are done, then 30 more frames.
func _settle() -> void:
	await _until(func() -> bool: return not _mode.is_presenting(), 1800)
	await _hold(30)


func _until(done: Callable, max_frames: int) -> void:
	var n: int = 0
	while not bool(done.call()) and n < max_frames:
		await _step()
		n += 1


func _hold(frames: int) -> void:
	for i: int in frames:
		await _step()


## One frame: grab the composited frame, analyse it, keep evidence.
func _step() -> void:
	if _auto_latch and _mode.replay.is_replaying() and not _mode.replay.is_latched():
		_mode.handle_action(InputActions.CONFIRM, true)
		_mode.handle_action(InputActions.CONFIRM, false)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var small: Image = FlashAnalyser.to_analysis(img, ANALYSIS_H)
	var before: int = _analyser.events().size()
	_analyser.add_frame(small)
	if _frame_no % SHEET_EVERY == 0:
		_tiles.append(small)
	if _analyser.events().size() > before and _shots < MAX_EVENT_SHOTS:
		img.save_png(_run_dir.path_join("event_%04d.png" % _frame_no))
		_shots += 1
	_frame_no += 1


func _frame_clock_us() -> int:
	return int(_frame_no * 1_000_000 / FPS)


func _on_hold_started(kind: BattleReplayController.HoldKind, _boss: Combatant) -> void:
	if kind == BattleReplayController.HoldKind.TAKEOVER_FULL:
		_flood_start = _frame_no


func _on_hold_finished(_kind: BattleReplayController.HoldKind) -> void:
	if _flood_start >= 0:
		_flood_spans.append(Vector2i(_flood_start, _frame_no - 1))
		_flood_start = -1


func _finish(seq: String, rf_on: bool, use_gate: bool, enc: String) -> Dictionary:
	var s: Dictionary = _analyser.summary()
	var outside: PackedInt32Array = _analyser.flashes_outside(_flood_spans)
	var rf_ok: bool = not rf_on or outside.is_empty()
	var flashes := PackedInt32Array(_analyser.flash_frames(FlashAnalyser.GENERAL))
	flashes.append_array(_analyser.flash_frames(FlashAnalyser.RED))
	FlashAnalyser.plot(_analyser.luma_series(), _analyser.events(), flashes, FPS).save_png(
			_run_dir.path_join("luma_plot.png"))
	_contact_sheet().save_png(_run_dir.path_join("contact_sheet.png"))
	var spans: Array = []
	for sp: Vector2i in _flood_spans:
		spans.append([sp.x, sp.y])
	return {
		"sequence": seq, "encounter": enc, "reduce_flashing": rf_on, "gate": use_gate,
		"frames": _frame_no, "seconds": float(_frame_no) / FPS, "decision_s": float(_decision_frames) / FPS, "latches_engaged": _latches,
		"mode_time_s": _mode._mode_time,
		"gate_requests": _requests.duplicate(true),
		"gate_booked_max_per_window": _gate.max_flashes_in_any_window(),
		"boss_flood_spans": spans,
		"general_max_per_window": s["general_worst_window"]["count"],
		"red_max_per_window": s["red_worst_window"]["count"],
		"flashes_outside_flood": Array(outside),
		"reduce_flashing_only_flood": rf_ok,
		"analysis": s,
		"notes": _notes.duplicate(),
		"pass": bool(s["pass"]) and rf_ok,
	}


func _contact_sheet() -> Image:
	if _tiles.is_empty():
		return Image.create(1, 1, false, Image.FORMAT_RGB8)
	var tw: int = _tiles[0].get_width()
	var th: int = _tiles[0].get_height()
	var rows: int = ceili(float(_tiles.size()) / SHEET_COLS)
	var sheet := Image.create(tw * SHEET_COLS, th * rows, false, Image.FORMAT_RGB8)
	for i: int in _tiles.size():
		sheet.blit_rect(_tiles[i], Rect2i(0, 0, tw, th), Vector2i((i % SHEET_COLS) * tw, (i / SHEET_COLS) * th))
	return sheet


func _teardown() -> void:
	_mode = null
	_host.queue_free()
	_layer.queue_free()
	_gate.queue_free()
	for i: int in 3:
		await process_frame


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile
