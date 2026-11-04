extends SceneTree
## Recruits evidence (design/narrative/recruits.md): a London battle with the
## Rush-Hour Commuter and the Street Mime swapped into the party (the
## Commuter first, so the command window lists its specials), then the Menu's Party
## screen over it with the bench marked. Needs a window and a GPU:
##
##   godot --path . -s res://tools/capture/recruits_capture.gd -- --out=<dir>

const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = "user://recruits_capture"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	ContentBootstrap.run(catalog)
	if catalog.state != ContentCatalogService.State.READY:
		printerr("recruits_capture: content boot failed")
		quit(1)
		return
	var store := SquadStore.new()
	store.rebuild(catalog)
	for m: Combatant in store.squad:
		Leveling.apply_level(m, 7, catalog)
		m.hp = m.max_hp
		m.mp = m.max_mp
	var ws := WorldState.new()
	ws.set_flag("paris_liberated")
	ws.set_flag("london_liberated")
	store.sync_recruits(ws, catalog)
	store.swap(0, 4)  # Rush-Hour Commuter leads (recruits join in id order)
	store.swap(2, 5)  # Street Mime in
	var rec: EncounterData = catalog.get_record(&"encounter", "enc_london_ceo") as EncounterData
	var d := EncounterDescriptor.new()
	d.encounter_id = rec.id
	d.enemy_ids = rec.enemy_ids
	d.battle_stage_id = rec.battle_stage_id
	d.faction_id = rec.faction_id
	d.is_boss = rec.is_boss
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = store.active_party()
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	root.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 40:
		await process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _save(out_dir.path_join("01-battle-with-recruits.png"))
	# The Menu's Party screen over the fight, the bench marked.
	var menu := InterimMenu.new()
	menu.world_state = ws
	menu.item_catalog = catalog
	menu.party = store.squad
	var mp := MenuPayload.new()
	mp.entries = [&"pause", &"party", &"quit"]
	menu.setup(null, mp)
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	layer.add_child(menu)
	menu.button_for(&"party").emit_signal(&"pressed")
	for i: int in 10:
		await process_frame
	await _save(out_dir.path_join("02-party-screen-bench.png"))
	# A benched starter's screen: "Bring into the party...".
	menu._show_member(store.squad[4])
	for i: int in 6:
		await process_frame
	await _save(out_dir.path_join("03-member-swap-option.png"))
	quit(0)


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("recruits_capture: wrote ", path)
