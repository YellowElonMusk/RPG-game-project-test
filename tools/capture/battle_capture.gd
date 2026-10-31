extends SceneTree
## Windowed battle screenshot: boots `BattleMode` on a shipped encounter with
## the shipped squad, lets it render, saves PNGs and quits. Needs a window
## and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/battle_capture.gd -- --encounter=enc_paris_supervisor --out=<dir>
##
## Or an ad-hoc fight with no encounter record (e.g. a faction no shipped
## encounter uses yet):
##
##   ... -- --faction=faction_megacorp --enemies=enemy_ceo,enemy_security_drone --boss=1 --name=megacorp_boss
##
## `--encounter` defaults to `enc_paris_clerks_hall`. Writes `<encounter>.png`
## after the reveal (idle), then `<encounter>_attack_<n>.png`, one every ~4
## frames through the squad's first Attack beat (wind-up, impact, reaction).

const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var enc_id: String = String(args.get("encounter", "enc_paris_clerks_hall"))
	var out_dir: String = String(args.get("out", "user://battle_capture"))
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	# The real boot, sprite-set validators included (ADR-0005 §9).
	var boot: ContentBootResult = ContentBootstrap.run(catalog)
	if boot == null or catalog.state != ContentCatalogService.State.READY:
		printerr("battle_capture: content boot failed: %s" % [catalog.report])
		quit(1)
		return
	var d := EncounterDescriptor.new()
	if args.has("enemies"):
		enc_id = String(args.get("name", "adhoc"))
		d.encounter_id = enc_id
		d.enemy_ids = PackedStringArray(String(args["enemies"]).split(","))
		d.faction_id = String(args.get("faction", ""))
		d.is_boss = String(args.get("boss", "0")) == "1"
	else:
		var rec: EncounterData = catalog.get_record(&"encounter", enc_id) as EncounterData
		if rec == null:
			printerr("battle_capture: unknown encounter %s" % enc_id)
			quit(1)
			return
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
	# Stands in for the Director's mode_entered: bind profiles, Battle light.
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	# Stands in for the GameStateMachine swap finishing (no machine here).
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _save(out_dir.path_join("%s.png" % enc_id))
	if String(args.get("defeat", "0")) == "1":
		# The Defeat curtain call (story 053): every squad member down, the
		# replay and end-of-fight hold played out, the spotlight pooled on
		# the party row.
		DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.DEFEAT)
		mode.settle_replay()
		for i: int in 30:
			await process_frame
		await _save(out_dir.path_join("%s_defeat.png" % enc_id))
		quit(0)
		return
	# Attack the first enemy through the real command menu: Attack, then target.
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)
	# A short sequence through the beat (wind-up, impact burst, reaction).
	for shot: int in 8:
		if not mode.is_presenting():
			break
		await _save(out_dir.path_join("%s_attack_%d.png" % [enc_id, shot]))
		for i: int in 4:
			await process_frame
	quit(0)


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("battle_capture: wrote ", path)
