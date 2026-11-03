extends SceneTree
## The Victory results screen in the real BattleMode: boots the five-Clerk
## `enc_paris_clerks_keen` and the boss fight, forces Victory, plays the end
## hold out and saves `results_<encounter>.png`. Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/results_capture.gd [-- --out=res://dir/]

const DEFAULT_OUT: String = "res://production/qa/evidence/results-screen/"
const SIZE := Vector2i(1280, 720)
const ENCOUNTERS: Array[String] = ["enc_paris_clerks_keen", "enc_paris_supervisor"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = DEFAULT_OUT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	ContentBootstrap.run(catalog)
	var ok: bool = true
	for enc_id: String in ENCOUNTERS:
		var payload := BattleEntryPayload.new()
		payload.descriptor = OverworldMode.build_descriptor(catalog.get_record(&"encounter", enc_id) as EncounterData)
		payload.party = ChapterFlow.build_squad(catalog)
		var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
		mode.setup(null, payload)
		root.add_child(mode)
		var stage: DioramaStage = mode.get_node(^"%DioramaStage")
		stage.bind_profiles(func(id: StringName) -> LightingProfile:
				return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile)
		mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
		mode.set_process(false)
		for i: int in 20:
			await process_frame
		mode.settle_replay()
		DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.VICTORY)
		mode.settle_replay()
		for i: int in 10:
			await process_frame
		var shown: bool = mode.results_panel().visible
		ok = ok and shown
		print("results_capture: %s shown=%s %s" % [enc_id, shown, mode.results_panel().totals_text()])
		for i: int in 3:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join("results_%s.png" % enc_id)))
		root.remove_child(mode)
		mode.free()
		await process_frame
	quit(0 if ok else 1)
