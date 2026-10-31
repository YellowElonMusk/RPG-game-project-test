extends SceneTree
## AC-67 (story sprite-camera-presentation 072, TR-presentation-024): the
## squad is never tinted by a faction's boss flood. Boots `BattleMode` on a
## boss encounter exactly as `battle_capture.gd` does, plays the replay out
## (the real first-encounter takeover ends on its `boss_<faction>` light),
## freezes the mode and captures the same stage under `battle` and under
## every shipped `boss_<faction>` profile: the only variable is the profile.
## Each squad member's own pixels (its exclusive ID-pass mask, rendered with
## the actor card's real projection) are diffed in CIEDE2000 against the
## Battle capture; `CaptureChecks.squad_tint_verdict` judges them.
##
## Two controls prove the check is not vacuous: a sensitivity control (the
## key light off must change the squad's pixels) and a negative control
## (each boss profile with its faction set colour on the key light, the
## failure the story names: faction colour on a light that reaches actors)
## must both FAIL. A Set/Fill cull-mask leak is also captured and recorded as
## an observation (in the shipped rig those lights strike the card's unlit
## side). Everything is restored afterwards. Needs a window and a GPU, never
## `--headless`:
##
##   godot --path . -s res://tools/capture/squad_tint_capture.gd [-- --encounter=enc_paris_supervisor --size=1920x1080 --out=res://dir/]
##
## Writes `<profile>.png` (the measured frame, UI hidden), `<profile>_ui.png`
## (the same frame with the UI, for eyes), `id_actors.png`, `mask_<member>.png`
## and `measurements.json`. Exit 0 when every faction passes and the negative
## control fails; 1 otherwise.

const DEFAULT_OUT: String = "res://production/qa/evidence/squad-never-tinted/"
const PROFILE_DIR: String = "res://data/presentation/profiles/"
## Frames rendered after each setup change before reading back.
const SETTLE_FRAMES: int = 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var enc_id: String = String(args.get("encounter", "enc_paris_supervisor"))
	var out_dir: String = String(args.get("out", DEFAULT_OUT))
	var dims: PackedStringArray = String(args.get("size", "1920x1080")).split("x")
	var size := Vector2i(int(dims[0]), int(dims[1]))
	DisplayServer.window_set_size(size)
	root.size = size

	var mode: BattleMode = _boot_battle(enc_id)
	if mode == null:
		quit(1)
		return
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	# The takeover's own end state, before anything is re-applied.
	var takeover_profile: String = _profile_name_of(stage)
	# Frozen from here: no idle frame, blend or tween moves between captures.
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var tool := PresentationCapture.new()
	root.add_child(tool)
	var members: Array[GeometryInstance3D] = _squad_sprites(stage)
	var m: Dictionary = {"tool": "tools/capture/squad_tint_capture.gd", "ac": "AC-67",
			"encounter": enc_id, "size": [size.x, size.y],
			"limits": {"mean_max": CaptureChecks.SQUAD_TINT_MEAN_MAX,
					"p95_max": CaptureChecks.SQUAD_TINT_P95_MAX, "percentile": "nearest-rank 95th"},
			"takeover_end": {"profile_on_stage": takeover_profile, "blend_p": stage.blend_p()},
			"members": [], "factions": {}}
	for g: GeometryInstance3D in members:
		(m["members"] as Array).append(String(g.name))
	if members.is_empty():
		printerr("squad_tint_capture: no squad sprites found")
		quit(1)
		return

	# The real takeover's last frame, as the flow left it.
	var takeover_img: Image = await _grab_world(stage)
	await _save_ui_frame(out_dir, "takeover_end")

	# Per-member exclusive masks (actor geometry is identical in every pass).
	var masks: Array[Image] = CaptureChecks.exclusive_masks(await _member_masks(tool, stage, members, out_dir))
	for i: int in members.size():
		masks[i].save_png(ProjectSettings.globalize_path(out_dir.path_join("mask_%s.png" % members[i].name)))

	var battle_img: Image = await _capture_profile(stage, "battle", out_dir)
	var all_pass: bool = true
	var boss_ids: Array[String] = _boss_profile_ids()
	for boss_id: String in boss_ids:
		var img: Image = await _capture_profile(stage, boss_id, out_dir)
		var entry: Dictionary = _judge(battle_img, img, members, masks)
		m["factions"][boss_id] = entry
		all_pass = all_pass and bool(entry["pass"])
	# The real takeover against Battle (the same faction, reached by the flow).
	var flow_entry: Dictionary = _judge(battle_img, takeover_img, members, masks)
	m["takeover_end"]["verdict"] = flow_entry
	all_pass = all_pass and bool(flow_entry["pass"])

	# Sensitivity control: with the key light off, the squad's pixels must
	# change; a zero here means the frames are stale or actors take no light,
	# and the AC-67 pass above would be vacuous.
	stage.apply_profile(_resolve_profile(&"battle"), 0.0)
	var old_key: float = stage.key_light.light_energy
	stage.key_light.light_energy = 0.0
	var dark: Image = await _grab_world(stage)
	dark.save_png(ProjectSettings.globalize_path(out_dir.path_join("sensitivity_key_off.png")))
	stage.key_light.light_energy = old_key
	var sens: Dictionary = _judge(battle_img, dark, members, masks)
	var sensitive: bool = not bool(sens["pass"])
	m["sensitivity_control"] = {"fixture": "KeyLight energy 0", "expected": "FAIL",
			"responds": sensitive, "result": sens}

	# Observation, not a gate: Set/Fill with ACTORS added to their cull masks.
	# In the shipped rig they strike the card's unlit side (N.L <= 0), so the
	# leak alone does not tint the squad; recorded so a rig change shows up.
	var old_set: int = stage.set_light.light_cull_mask
	var old_fill: int = stage.fill_light.light_cull_mask
	stage.set_light.light_cull_mask = DioramaStage.LAYER_SET | DioramaStage.LAYER_ACTORS
	stage.fill_light.light_cull_mask = DioramaStage.LAYER_SET | DioramaStage.LAYER_ACTORS
	var leaks: Dictionary = {}
	for boss_id: String in boss_ids:
		var leak: Image = await _capture_profile(stage, boss_id, out_dir, "cull_leak_")
		leaks[boss_id] = _judge(battle_img, leak, members, masks)
	stage.set_light.light_cull_mask = old_set
	stage.fill_light.light_cull_mask = old_fill
	m["cull_leak_observation"] = {"fixture": "SetLight and FillLight cull masks include ACTORS",
			"results": leaks}

	# Negative control: the faction flood on a light that reaches actors --
	# each boss profile with its key carrying its own faction set colour.
	var neg: Dictionary = {}
	for boss_id: String in boss_ids:
		var tinted := _resolve_profile(StringName(boss_id)).duplicate() as LightingProfile
		tinted.key_color = tinted.set_color
		stage.apply_profile(tinted, 0.0)
		var img: Image = await _grab_world(stage)
		img.save_png(ProjectSettings.globalize_path(out_dir.path_join("negative_control_%s.png" % boss_id)))
		neg[boss_id] = _judge(battle_img, img, members, masks)
	stage.apply_profile(_resolve_profile(&"battle"), 0.0)
	var neg_failed: bool = true
	for boss_id: String in neg:
		neg_failed = neg_failed and not bool((neg[boss_id] as Dictionary)["pass"])
	m["negative_control"] = {"fixture": "boss profile with key_color = its faction set_color",
			"expected": "FAIL", "all_failed": neg_failed, "results": neg}
	m["pass"] = all_pass
	m["negative_control_discriminates"] = neg_failed
	m["sensitivity_control_responds"] = sensitive

	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir.path_join("measurements.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "  ", true))
	f.close()
	print("squad_tint_capture: AC-67 %s; negative control %s; wrote %s" % [
			"PASS" if all_pass else "FAIL", "FAILS as expected" if neg_failed else "DID NOT FAIL", out_dir])
	print("squad_tint_capture: sensitivity control %s" % ("responds" if sensitive else "DID NOT RESPOND"))
	quit(0 if all_pass and neg_failed and sensitive else 1)


## Boots `BattleMode` on `enc_id` with the shipped squad (the real content
## boot, as `battle_capture.gd`), Battle light applied. Null on failure.
func _boot_battle(enc_id: String) -> BattleMode:
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	var boot: ContentBootResult = ContentBootstrap.run(catalog)
	if boot == null or catalog.state != ContentCatalogService.State.READY:
		printerr("squad_tint_capture: content boot failed: %s" % [catalog.report])
		return null
	var rec: EncounterData = catalog.get_record(&"encounter", enc_id) as EncounterData
	if rec == null:
		printerr("squad_tint_capture: unknown encounter %s" % enc_id)
		return null
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
	return mode


## Every shipped `boss_<faction>` profile id, sorted.
func _boss_profile_ids() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(PROFILE_DIR):
		if file.begins_with("boss_") and file.ends_with(".tres"):
			out.append(file.get_basename())
	out.sort()
	return out


## Which shipped profile the stage's current values equal, or "blend".
func _profile_name_of(stage: DioramaStage) -> String:
	if stage.current_values == null:
		return "none"
	for file: String in DirAccess.get_files_at(PROFILE_DIR):
		if not file.ends_with(".tres"):
			continue
		var p: LightingProfile = load(PROFILE_DIR + file) as LightingProfile
		if p.set_color.is_equal_approx(stage.current_values.set_color) \
				and p.fill_color.is_equal_approx(stage.current_values.fill_color) \
				and is_equal_approx(p.set_energy, stage.current_values.set_energy):
			return file.get_basename()
	return "blend"


## The stage's actor sprites named `Squad<slot>` (BattleView's naming).
func _squad_sprites(stage: DioramaStage) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in stage.find_children("Squad*", "GeometryInstance3D", true, false):
		if not String(n.name).ends_with("Shadow"):
			out.append(n as GeometryInstance3D)
	return out


## Applies `profile_id` at blend 0 (and the rim globals the Director would
## write), then grabs the world with the UI hidden plus a UI frame for eyes.
func _capture_profile(stage: DioramaStage, profile_id: String, out_dir: String,
		prefix: String = "") -> Image:
	stage.apply_profile(_resolve_profile(StringName(profile_id)), 0.0)
	var img: Image = await _grab_world(stage)
	img.save_png(ProjectSettings.globalize_path(out_dir.path_join("%s%s.png" % [prefix, profile_id])))
	if prefix.is_empty():
		await _save_ui_frame(out_dir, profile_id)
	return img


## The frame with every canvas item hidden (no HUD over the squad).
func _grab_world(stage: DioramaStage) -> Image:
	RenderingServer.global_shader_parameter_set(PresentationDirector.RIM_COLOR_GLOBAL, stage.current_rim_color)
	RenderingServer.global_shader_parameter_set(PresentationDirector.RIM_STRENGTH_GLOBAL, stage.current_rim_strength)
	root.canvas_cull_mask = 0
	var img: Image = await _grab()
	root.canvas_cull_mask = 0xFFFFFFFF
	return img


func _save_ui_frame(out_dir: String, frame_name: String) -> void:
	var img: Image = await _grab()
	img.save_png(ProjectSettings.globalize_path(out_dir.path_join("%s_ui.png" % frame_name)))


## One ID-pass `actor` mask per member, rendered with only that member's
## actor geometry visible (so an overlapping neighbour never lands in it).
func _member_masks(tool: PresentationCapture, stage: DioramaStage,
		members: Array[GeometryInstance3D], out_dir: String) -> Array[Image]:
	var cam: Camera3D = stage.camera
	var old_env: Environment = cam.environment
	cam.environment = PresentationCapture._flat_environment()
	var restore: Dictionary = tool.apply_id_overrides(stage, DioramaStage.LAYER_ACTORS)
	root.canvas_cull_mask = 0
	var id_all: Image = await _grab()
	id_all.save_png(ProjectSettings.globalize_path(out_dir.path_join("id_actors.png")))
	var actor_geo: Array[GeometryInstance3D] = []
	for n: Node in stage.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if (g.layers & DioramaStage.LAYER_ACTORS) != 0:
			actor_geo.append(g)
	var layers: Dictionary = {}
	for g: GeometryInstance3D in actor_geo:
		layers[g] = g.layers
	var out: Array[Image] = []
	for member: GeometryInstance3D in members:
		for g: GeometryInstance3D in actor_geo:
			g.layers = layers[g] if g == member else 0
		var img: Image = await _grab()
		out.append(PresentationCapture.tag_mask(img, PresentationCapture.CLASS_ACTOR)["image"] as Image)
	for g: GeometryInstance3D in actor_geo:
		g.layers = layers[g]
	root.canvas_cull_mask = 0xFFFFFFFF
	PresentationCapture.restore_overrides(restore)
	cam.environment = old_env
	return out


func _judge(battle: Image, boss: Image, members: Array[GeometryInstance3D],
		masks: Array[Image]) -> Dictionary:
	var stats: Dictionary = {}
	for i: int in members.size():
		stats[String(members[i].name)] = CaptureChecks.masked_delta_e(battle, boss, masks[i])
	var verdict: Dictionary = CaptureChecks.squad_tint_verdict(stats)
	return {"pass": verdict["pass"], "failures": verdict["failures"], "members": stats}


func _grab() -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile
