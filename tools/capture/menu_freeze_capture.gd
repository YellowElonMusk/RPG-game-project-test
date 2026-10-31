extends SceneTree
## Story 010's [C] half (GDD sprite-camera-presentation AC-8; ADR-0005 §7):
## a live, windowed check that the Menu freezes the world layer. Boots the
## real `BattleMode` under a stand-in `ModeHost`, adds a moving-particle
## fixture to the stage, starts a squad Attack and stops mid-wind-up (case
## a). Then:
##
##   menu open   -- `ModeHost` disabled (what `ModeHostSceneLoader` does) and
##                  `stage.set_ambient_paused(true)` (what the Director does
##                  on `overlay_opened(MENU)`); two main-viewport grabs 1 s
##                  of real time apart must be pixel-identical;
##   control     -- the same two grabs with the Menu closed must differ, so
##                  the check can fail.
##
## No Menu panel is drawn here (the overlay is UI, outside `ModeHost`), so
## the whole frame is the world layer. Needs a window and a GPU, never
## `--headless`:
##
##   godot --path . -s res://tools/capture/menu_freeze_capture.gd [-- --out=<dir>]
##
## Writes `open_a.png`, `open_b.png`, `closed_a.png`, `closed_b.png`, the two
## diff masks and `measurements.json`. Exit 0 iff open is identical and the
## control differs.

const SIZE := Vector2i(1280, 720)
const DEFAULT_OUT: String = "res://production/qa/evidence/menu-freeze-stops-every-presentation-clock/"
## Real seconds between the two grabs of a pair (the AC's 1 s).
const GRAB_GAP_S: float = 1.0
## Per-channel tolerance for "identical": 0 (pixel-identical).
const TOLERANCE: int = 0


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
		printerr("menu_freeze_capture: content boot failed: %s" % [catalog.report])
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
	var host := Node.new()
	host.name = "ModeHost"
	root.add_child(host)
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	host.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	for i: int in 60:
		await process_frame
	mode.settle_replay()
	var view: BattleView = mode.get_node(^"%BattleView")
	_add_particle_fixture(stage, view.get_sprite(mode.battle.enemies[0]))
	for i: int in 60:
		await process_frame
	# Case (a): a squad Attack through the real command menu, mid-wind-up.
	for i: int in 2:
		mode.handle_action(InputActions.CONFIRM, true)
		mode.handle_action(InputActions.CONFIRM, false)
	var guard: int = 0
	while (mode.replay.get_current_plan() == null or mode.replay.get_windup_progress() <= 0.0) and guard < 600:
		await process_frame
		guard += 1
	var windup_at_open: float = mode.replay.get_windup_progress()
	var impact_at_open: float = mode.replay.get_post_impact_time()

	# Menu open: the loader's ModeHost disable and the Director's pause.
	host.process_mode = Node.PROCESS_MODE_DISABLED
	stage.set_ambient_paused(true)
	var open_a: Image = await _grab()
	await create_timer(GRAB_GAP_S).timeout
	var open_b: Image = await _grab()
	var windup_after: float = mode.replay.get_windup_progress()

	# Control: Menu closed.
	stage.set_ambient_paused(false)
	host.process_mode = Node.PROCESS_MODE_INHERIT
	var closed_a: Image = await _grab()
	await create_timer(GRAB_GAP_S).timeout
	var closed_b: Image = await _grab()

	var open_diff: Dictionary = PresentationCapture.diff_mask(open_a, open_b, TOLERANCE)
	var closed_diff: Dictionary = PresentationCapture.diff_mask(closed_a, closed_b, TOLERANCE)
	DirAccess.make_dir_recursive_absolute(out_dir)
	open_a.save_png(out_dir.path_join("open_a.png"))
	open_b.save_png(out_dir.path_join("open_b.png"))
	closed_a.save_png(out_dir.path_join("closed_a.png"))
	closed_b.save_png(out_dir.path_join("closed_b.png"))
	(open_diff["image"] as Image).save_png(out_dir.path_join("open_diff.png"))
	(closed_diff["image"] as Image).save_png(out_dir.path_join("closed_diff.png"))
	var passed: bool = int(open_diff["pixels"]) == 0 and int(closed_diff["pixels"]) > 0
	var m: Dictionary = {
		"tool": "tools/capture/menu_freeze_capture.gd",
		"size": [open_a.get_width(), open_a.get_height()],
		"grab_gap_s": GRAB_GAP_S,
		"tolerance": TOLERANCE,
		"case": "a (mid-wind-up)",
		"windup_progress_at_open": windup_at_open,
		"post_impact_at_open": impact_at_open,
		"windup_progress_after_1s_open": windup_after,
		"particles_fixture": stage.particles_in_scene().size(),
		"open_diff_pixels": open_diff["pixels"],
		"closed_diff_pixels": closed_diff["pixels"],
		"closed_diff_share": closed_diff["share"],
		"result": "PASS" if passed else "FAIL",
	}
	var f := FileAccess.open(out_dir.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "  ", true))
	f.close()
	print("menu_freeze_capture: %s open_diff=%d closed_diff=%d -> %s" % [
			m["result"], open_diff["pixels"], closed_diff["pixels"], out_dir])
	host.queue_free()
	quit(0 if passed else 1)


## A bright, steadily rising particle column beside `anchor`, on the set
## layer: a moving fixture the frozen grabs must hold still.
func _add_particle_fixture(stage: DioramaStage, anchor: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.name = "MenuFreezeParticleFixture"
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 0.9
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.05, 0.05)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.draw_pass_1 = quad
	p.amount = 48
	p.lifetime = 2.0
	p.layers = DioramaStage.LAYER_SET
	var at: Vector3 = anchor.position if anchor != null else Vector3(0.0, 0.0, -6.0)
	p.position = at + Vector3(1.0, 0.2, 0.0)
	stage.add_child(p)
	p.emitting = true


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
