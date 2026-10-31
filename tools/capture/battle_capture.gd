extends SceneTree
## Windowed battle screenshot: boots `BattleMode` on a shipped encounter with
## the shipped squad, lets it render, saves PNGs and quits. Needs a window
## and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/battle_capture.gd -- --encounter=enc_paris_supervisor --out=<dir>
##
## `--encounter` defaults to `enc_paris_clerks_hall`. Writes `<encounter>.png`
## after the reveal (idle), then `<encounter>_attack.png` mid-way through the
## squad's first Attack beat.

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
	var rec: EncounterData = catalog.get_record(&"encounter", enc_id) as EncounterData
	if rec == null:
		printerr("battle_capture: unknown encounter %s" % enc_id)
		quit(1)
		return
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
	# Stands in for the GameStateMachine swap finishing (no machine here).
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _save(out_dir.path_join("%s.png" % enc_id))
	# Attack the first enemy through the real command menu: Attack, then target.
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)
	mode.handle_action(InputActions.CONFIRM, true)
	mode.handle_action(InputActions.CONFIRM, false)
	for i: int in 4:
		await process_frame
	if mode.is_presenting():
		await _save(out_dir.path_join("%s_attack.png" % enc_id))
	quit(0)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("battle_capture: wrote ", path)
