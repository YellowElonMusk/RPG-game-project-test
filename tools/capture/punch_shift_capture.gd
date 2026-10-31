extends SceneTree
## Story 025's [C] check (GDD sprite-camera-presentation AC-21b; ADR-0005 §6,
## §13): on a Battle capture at a hit-punch's peak and one with no punch, the
## ID pass of every near actor (the squad), far actor (the enemies) and set
## element (the blob shadows, the battle's 3D set geometry) is displaced by
## the same whole number of pixels, `A_peak` in the punch direction.
##
## Boots the real `BattleMode` on `enc_paris_clerks_hall`, settles it, then
## freezes it and, for each case, sets the stage's punch offset to
## `HitPunch.offset_px(0, D, A_peak, dir)` (`t = 0` is the peak), runs one
## presentation frame (`BattleView.present()`, so every sprite re-projects
## exactly as in play) and renders the ID pass in the main viewport through
## `PresentationCapture.apply_id_overrides()`. `PunchShiftCheck` measures
## each actor's region and the set region against the no-punch frame.
## Needs a window and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/punch_shift_capture.gd [-- --out=<dir>]
##
## Writes `id_none.png`, `id_<case>.png`, `final_<case>.png` and
## `measurements.json`. Exit 0 iff every case passes.

const SIZE := Vector2i(1280, 720)
const DEFAULT_OUT: String = "res://production/qa/evidence/punch-displaces-the-id-pass-by-whole-pixels/"
## Frames rendered after each setup before reading back.
const SETTLE_FRAMES: int = 3

var _pc: PresentationCapture


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var out_dir: String = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	var boot: ContentBootResult = ContentBootstrap.run(catalog)
	if boot == null or catalog.state != ContentCatalogService.State.READY:
		printerr("punch_shift_capture: content boot failed: %s" % [catalog.report])
		quit(1)
		return
	var rec: EncounterData = catalog.get_record(&"encounter", "enc_paris_clerks_hall") as EncounterData
	var d := EncounterDescriptor.new()
	d.encounter_id = rec.id
	d.enemy_ids = rec.enemy_ids
	d.battle_stage_id = rec.battle_stage_id
	d.faction_id = rec.faction_id
	d.is_boss = rec.is_boss
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = ChapterFlow.build_squad(catalog)
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	root.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	for i: int in 60:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	_pc = PresentationCapture.new()
	root.add_child(_pc)
	var view: BattleView = mode.get_node(^"%BattleView")
	var cfg: PresentationConfig = mode.presentation_config
	var h: int = stage.battle_viewport_height()
	var radius: int = HitPunch.full_amplitude(cfg.punch_amplitude_big, h) + 2
	var border := Rect2i(Vector2i(radius, radius), SIZE - Vector2i(2 * radius, 2 * radius))

	DirAccess.make_dir_recursive_absolute(out_dir)
	var none: Dictionary = await _render(mode, stage, view, Vector2i.ZERO)
	(none["id"] as Image).save_png(out_dir.path_join("id_none.png"))
	var regions: Dictionary = _regions(mode, view, none["rects"], none["id"], radius, border)

	var cases: Array[Dictionary] = [
		{"name": "big_up", "a_beat": cfg.punch_amplitude_big, "dir": Vector2.UP},
		{"name": "big_down", "a_beat": cfg.punch_amplitude_big, "dir": Vector2.DOWN},
		{"name": "normal_up", "a_beat": cfg.punch_amplitude_normal, "dir": Vector2.UP},
	]
	var report: Dictionary = {"tool": "tools/capture/punch_shift_capture.gd", "size": [SIZE.x, SIZE.y],
			"h_screen": h, "search_radius": radius, "regions": {}, "cases": {}}
	for name: String in regions:
		var rr: Rect2i = regions[name]["rect"]
		report["regions"][name] = {"class": regions[name]["class"], "rect": [rr.position.x, rr.position.y, rr.size.x, rr.size.y]}
	var all_pass: bool = true
	for c: Dictionary in cases:
		var a_peak: int = HitPunch.peak_amplitude(HitPunch.full_amplitude(float(c["a_beat"]), h),
				PresentationSettings.ScreenShake.FULL, false)
		var punch: Vector2i = HitPunch.offset_px(0.0, cfg.punch_duration, a_peak, c["dir"])
		var shot: Dictionary = await _render(mode, stage, view, punch)
		(shot["id"] as Image).save_png(out_dir.path_join("id_%s.png" % c["name"]))
		(shot["final"] as Image).save_png(out_dir.path_join("final_%s.png" % c["name"]))
		var results: Dictionary = {}
		for name: String in regions:
			var cls: String = regions[name]["class"]
			results[name] = PunchShiftCheck.best_shift(
					PresentationCapture.tag_mask(none["id"], cls)["image"],
					PresentationCapture.tag_mask(shot["id"], cls)["image"],
					regions[name]["rect"], radius)
		var v: Dictionary = PunchShiftCheck.verdict(results, punch)
		all_pass = all_pass and bool(v["pass"])
		var rows: Dictionary = {}
		for name: String in results:
			var m: Dictionary = results[name]
			rows[name] = {"shift": [m["shift"].x, m["shift"].y], "mismatch": m["mismatch"],
					"runner_up": m["runner_up"], "pixels": m["pixels"]}
		report["cases"][c["name"]] = {"a_beat": c["a_beat"], "a_peak": a_peak, "dir": [c["dir"].x, c["dir"].y],
				"punch_px": [punch.x, punch.y], "lens_shift": [stage.camera.frustum_offset.x, stage.camera.frustum_offset.y],
				"measured": rows, "pass": v["pass"], "failures": v["failures"]}
		print("punch_shift_capture: %s A_peak %d punch %s -> %s %s" % [c["name"], a_peak, punch,
				"PASS" if v["pass"] else "FAIL", v["failures"]])
	report["result"] = "PASS" if all_pass else "FAIL"
	var f := FileAccess.open(out_dir.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))
	f.close()
	print("punch_shift_capture: %s -> %s" % [report["result"], out_dir])
	mode.queue_free()
	quit(0 if all_pass else 1)


## Sets `punch`, runs one presentation frame, and grabs the lit frame and the
## ID pass. Returns `{"final", "id": Image, "rects": {Combatant: Rect2i}}`
## (each sprite's projected rect this frame).
func _render(mode: BattleMode, stage: DioramaStage, view: BattleView, punch: Vector2i) -> Dictionary:
	stage.set_punch_offset_px(punch)
	view.present()
	var rects: Dictionary = {}
	for c: Combatant in mode.battle.squad + mode.battle.enemies:
		var s: CharacterSprite = view.get_sprite(c)
		if s != null:
			var r: Rect2 = (s.material_override as ShaderMaterial).get_shader_parameter(&"sprite_rect")
			rects[c] = Rect2i(r)
	root.canvas_cull_mask = 0xFFFFFFFF
	var final_img: Image = await _grab()
	var cam: Camera3D = stage.camera
	var old_env: Environment = cam.environment
	cam.environment = PresentationCapture._flat_environment()
	var restore: Dictionary = _pc.apply_id_overrides(stage, DioramaStage.LAYER_ACTORS)
	root.canvas_cull_mask = 0
	var id_img: Image = await _grab()
	PresentationCapture.restore_overrides(restore)
	cam.environment = old_env
	root.canvas_cull_mask = 0xFFFFFFFF
	return {"final": final_img, "id": id_img, "rects": rects}


## One region per actor (its no-punch rect grown by `radius`; `near:` for
## the squad, `far:` for enemies) and one for the set class (the bounding
## box of its no-punch mask, grown), each clipped to `border` so nothing
## shifts in or out of the frame.
func _regions(mode: BattleMode, view: BattleView, rects: Dictionary, id_none: Image, radius: int,
		border: Rect2i) -> Dictionary:
	var out: Dictionary = {}
	for c: Combatant in rects:
		var key: String = "%s:%s" % ["far" if c.is_enemy else "near", view.get_sprite(c).name]
		out[key] = {"class": PresentationCapture.CLASS_ACTOR,
				"rect": (rects[c] as Rect2i).grow(radius).intersection(border)}
	var set_mask: Dictionary = PresentationCapture.tag_mask(id_none, PresentationCapture.CLASS_SET)
	if int(set_mask["pixels"]) > 0:
		var used: Rect2i = PunchShiftCheck.content_rect(set_mask["image"])
		out["set:blob_shadows"] = {"class": PresentationCapture.CLASS_SET,
				"rect": used.grow(radius).intersection(border)}
	return out


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


func _grab() -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
