extends SceneTree
## AC-48 (story sprite-camera-presentation 052, TR-presentation-003/002): no
## emissive source bleeds through an actor's silhouette. Boots every AC-32
## lighting state that has a 3D scene (the real content boot, as
## `ui_tint_capture.gd`), freezes it and renders the ID pass twice: once as
## is (the actor silhouette: `actor` and `symbol` pixels) and once with every
## actor hidden and every emissive set source drawn in the reserved emissive
## colour (`EmissiveBleedCheck`). An emissive pixel inside the silhouette
## fails; one beside it passes.
##
##   battle               Battle (Clerks' Hall), squad turn;
##   boss_bureaucratia    the shipped Bureaucratia boss, takeover played out;
##   boss_megacorp        an ad-hoc MegaCorp boss fight, takeover played out;
##   victory_peak         the frame the Victory blend completes;
##   defeat               the Defeat light;
##   overworld            the Paris town map, the party at its entry point.
##
## Title and Camp have no 3D scene in the shipped game (both are 2D modes), so
## they are recorded as blocked, not passed.
##
## Three controls on the Battle stage prove the check is not vacuous:
##   control_behind            an emissive quad straight behind a squad
##                             member                          -> must FAIL;
##   control_beside            the same quad beside the squad (the Camp fire
##                             case)                           -> must PASS,
##                             with emissive pixels on screen;
##   control_actor_lighting    the behind quad under an `actor_lighting`
##                             practical                       -> must PASS.
##
## Needs a window and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/emissive_bleed_capture.gd [-- --size=1920x1080 --out=res://dir/]
##
## Writes per capture `<name>_final.png`, `<name>_id.png`,
## `<name>_silhouette.png`, `<name>_actors_hidden.png`, `<name>_bleed.png`
## and one `measurements.json`. Exit 0 when every capture passes and every
## control behaves as expected; 1 otherwise.

const DEFAULT_OUT: String = "res://production/qa/evidence/no-emissive-behind-actor/"
const SETTLE_FRAMES: int = 3
const VICTORY_STEP: float = 1.0 / 240.0
const MEGACORP_ENEMIES: Array[String] = ["enemy_ceo", "enemy_security_drone"]
const MEGACORP_FACTION: String = "faction_megacorp"
const OVERWORLD_MAP: String = "map_paris_town_placeholder"
## [state, encounter id ("" = ad-hoc MegaCorp boss), what to do].
const BATTLE_STATES: Array = [
	["battle", "enc_paris_clerks_hall", "menu"],
	["boss_bureaucratia", "enc_paris_supervisor", "menu"],
	["boss_megacorp", "", "menu"],
	["victory_peak", "enc_paris_clerks_hall", "victory"],
	["defeat", "enc_paris_clerks_hall", "defeat"],
]
## AC-32 states with no 3D scene to capture in the shipped game.
const BLOCKED_STATES: Dictionary = {
	"title": "TitleMode is a 2D Control scene: no DioramaStage, no actors",
	"camp": "InterimCampMode is a 2D card: no Camp diorama, no campfire practical yet",
}
## Control quad edge (m) and distances (m) behind / beside the squad member.
const CONTROL_SIZE: float = 1.4
const CONTROL_BEHIND_M: float = 1.5
## The beside control's quad edge (m): small enough to sit in the gap between
## two neighbouring squad members at the same depth.
const CONTROL_BESIDE_SIZE: float = 0.5

var _catalog: ContentCatalogService = null
var _tool: PresentationCapture = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var out_dir: String = String(args.get("out", DEFAULT_OUT))
	var dims: PackedStringArray = String(args.get("size", "1920x1080")).split("x")
	var size := Vector2i(int(dims[0]), int(dims[1]))
	DisplayServer.window_set_size(size)
	root.size = size
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_tool = PresentationCapture.new()
	root.add_child(_tool)

	var m: Dictionary = {"tool": "tools/capture/emissive_bleed_capture.gd", "ac": "AC-48",
			"size": [size.x, size.y], "emissive_colour": "#" + EmissiveBleedCheck.emissive_colour().to_html(false),
			"states": {}, "blocked": BLOCKED_STATES, "controls": {}}
	var all_pass: bool = true
	for row: Array in BATTLE_STATES:
		var state: String = row[0]
		var mode: BattleMode = await _boot_scene(String(row[1]), String(row[2]))
		if mode == null:
			printerr("emissive_bleed_capture: %s: boot failed" % state)
			quit(1)
			return
		var stage: DioramaStage = mode.get_node(^"%DioramaStage")
		var entry: Dictionary = await _measure(stage, state, out_dir)
		m["states"][state] = entry
		all_pass = all_pass and bool(entry["pass"])
		_report(state, entry)
		if state == "battle":
			m["controls"] = await _controls(stage, out_dir)
		await _free_node(mode)

	var ow: OverworldMode = await _boot_overworld()
	var ow_stage: DioramaStage = _find_stage(ow)
	var ow_entry: Dictionary = await _measure(ow_stage, "overworld", out_dir)
	m["states"]["overworld"] = ow_entry
	all_pass = all_pass and bool(ow_entry["pass"])
	_report("overworld", ow_entry)
	await _free_node(ow)

	var c: Dictionary = m["controls"]
	var controls_ok: bool = not c.is_empty() \
			and not bool(c["control_behind"]["pass"]) \
			and bool(c["control_beside"]["pass"]) and int(c["control_beside"]["emissive_pixels"]) > 0 \
			and bool(c["control_actor_lighting"]["pass"]) and int(c["control_actor_lighting"]["exempt_sources"]) > 0
	m["pass"] = all_pass
	m["controls_behave"] = controls_ok
	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir.path_join("measurements.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "  ", true))
	f.close()
	print("emissive_bleed_capture: AC-48 %s on %d captured state(s); controls %s; blocked: %s; wrote %s" % [
			"PASS" if all_pass else "FAIL", (m["states"] as Dictionary).size(),
			"behave" if controls_ok else "DO NOT BEHAVE", ", ".join(BLOCKED_STATES.keys()), out_dir])
	quit(0 if all_pass and controls_ok else 1)


## One frozen capture: the ID pass as is (silhouette) and with the actors
## hidden and emissive sources recoloured (emissive mask), and their overlap.
func _measure(stage: DioramaStage, cap_name: String, out_dir: String) -> Dictionary:
	var vp: Viewport = root
	var cam: Camera3D = vp.get_camera_3d()
	var final: Image = await _grab()
	_save(final, out_dir, "%s_final" % cap_name)

	# Classify before the ID overrides replace the materials.
	var sources: Array[GeometryInstance3D] = []
	var exempt: Array[GeometryInstance3D] = []
	var actors: Array[GeometryInstance3D] = []
	for n: Node in stage.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var cls: String = PresentationCapture.class_of(g, DioramaStage.LAYER_ACTORS, stage)
		if cls == PresentationCapture.CLASS_ACTOR or cls == "symbol":
			actors.append(g)
		elif EmissiveBleedCheck.is_emissive(g, DioramaStage.LAYER_ACTORS):
			if EmissiveBleedCheck.is_actor_lighting(g, stage):
				exempt.append(g)
			else:
				sources.append(g)

	var old_env: Environment = cam.environment
	cam.environment = PresentationCapture._flat_environment()
	var restore: Dictionary = _tool.apply_id_overrides(stage, DioramaStage.LAYER_ACTORS)
	vp.canvas_cull_mask = 0
	var id: Image = await _grab()
	var actor_mask: Image = PresentationCapture.tag_mask(id, PresentationCapture.CLASS_ACTOR)["image"]
	var symbol_mask: Image = PresentationCapture.tag_mask(id, "symbol")["image"]
	var silhouette: Image = _union(actor_mask, symbol_mask)
	# Once more with the actors hidden and every emissive source recoloured.
	var layers: Dictionary = {}
	for g: GeometryInstance3D in actors:
		layers[g] = g.layers
		g.layers = 0
	for g: GeometryInstance3D in sources:
		var mat := g.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(&"id_color", EmissiveBleedCheck.emissive_colour())
	var hidden: Image = await _grab()
	PresentationCapture.restore_layers(layers)
	PresentationCapture.restore_overrides(restore)
	vp.canvas_cull_mask = 0xFFFFFFFF
	cam.environment = old_env

	var emissive: Dictionary = EmissiveBleedCheck.colour_mask(hidden, EmissiveBleedCheck.emissive_colour())
	var sil_px: int = PresentationCapture.tag_mask(id, PresentationCapture.CLASS_ACTOR)["pixels"] \
			+ PresentationCapture.tag_mask(id, "symbol")["pixels"]
	var b: Dictionary = EmissiveBleedCheck.bleed(silhouette, emissive["image"])
	_save(id, out_dir, "%s_id" % cap_name)
	_save(silhouette, out_dir, "%s_silhouette" % cap_name)
	_save(hidden, out_dir, "%s_actors_hidden" % cap_name)
	_save(b["image"], out_dir, "%s_bleed" % cap_name)
	var result: Dictionary = {"silhouette_pixels": sil_px, "bleed_pixels": b["pixels"],
			"emissive_pixels": emissive["pixels"], "emissive_sources": sources.size(),
			"exempt_sources": exempt.size(), "actors": actors.size(),
			"source_names": _names(sources), "exempt_names": _names(exempt)}
	var v: Dictionary = EmissiveBleedCheck.verdict(result)
	result["pass"] = v["pass"]
	result["failures"] = v["failures"]
	return result


## The three controls on the frozen Battle stage (see the file doc).
func _controls(stage: DioramaStage, out_dir: String) -> Dictionary:
	var out: Dictionary = {}
	var cam: Camera3D = root.get_camera_3d()
	var squad: Array[Node3D] = []
	for n: Node in stage.find_children("Squad*", "GeometryInstance3D", true, false):
		if not String(n.name).ends_with("Shadow"):
			squad.append(n as Node3D)
	if squad.is_empty():
		return out
	# The member nearest the screen centre (behind) and the two leftmost
	# neighbours (beside: the quad goes in the gap between them).
	squad.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return cam.unproject_position(a.global_position).x < cam.unproject_position(b.global_position).x)
	var centre: Node3D = squad[0]
	var mid: float = float(root.size.x) * 0.5
	for s: Node3D in squad:
		if absf(cam.unproject_position(s.global_position).x - mid) \
				< absf(cam.unproject_position(centre.global_position).x - mid):
			centre = s
	var left_a: Node3D = squad[0]
	var left_b: Node3D = squad[mini(1, squad.size() - 1)]
	var fwd: Vector3 = -cam.global_basis.z
	var lift: Vector3 = Vector3.UP * CONTROL_SIZE * 0.5

	var behind: MeshInstance3D = _emissive_quad(cam)
	stage.add_child(behind)
	behind.global_position = centre.global_position + fwd * CONTROL_BEHIND_M + lift
	out["control_behind"] = await _measure(stage, "control_behind", out_dir)
	out["control_behind"]["fixture"] = "emissive quad %.1f m behind %s" % [CONTROL_BEHIND_M, centre.name]
	out["control_behind"]["expected"] = "FAIL"

	var scale: float = CONTROL_BESIDE_SIZE / CONTROL_SIZE
	behind.scale = Vector3(scale, scale, 1.0)
	behind.global_position = (left_a.global_position + left_b.global_position) * 0.5 \
			+ Vector3.UP * CONTROL_BESIDE_SIZE
	out["control_beside"] = await _measure(stage, "control_beside", out_dir)
	out["control_beside"]["fixture"] = "emissive quad %.1f m wide between %s and %s, same depth" % [
			CONTROL_BESIDE_SIZE, left_a.name, left_b.name]
	out["control_beside"]["expected"] = "PASS with emissive pixels"
	stage.remove_child(behind)
	behind.free()

	var practical := OmniLight3D.new()
	practical.name = "CampfirePractical"
	practical.light_energy = 0.0
	practical.light_cull_mask = DioramaStage.LAYER_SET | DioramaStage.LAYER_ACTORS
	practical.set_meta(EmissiveBleedCheck.META_ACTOR_LIGHTING, true)
	stage.add_child(practical)
	var fire: MeshInstance3D = _emissive_quad(cam)
	practical.add_child(fire)
	fire.global_position = centre.global_position + fwd * CONTROL_BEHIND_M + lift
	out["control_actor_lighting"] = await _measure(stage, "control_actor_lighting", out_dir)
	out["control_actor_lighting"]["fixture"] = "the behind quad under an OmniLight3D tagged actor_lighting"
	out["control_actor_lighting"]["expected"] = "PASS (exempt)"
	stage.remove_child(practical)
	practical.free()
	for k: String in out:
		print("emissive_bleed_capture: %s %s (bleed %d px, emissive %d px)" % [k,
				"PASS" if bool(out[k]["pass"]) else "FAIL", int(out[k]["bleed_pixels"]), int(out[k]["emissive_pixels"])])
	return out


## A camera-facing, set-layer, emissive quad (the control source).
func _emissive_quad(cam: Camera3D) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(CONTROL_SIZE, CONTROL_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 4.0
	var mi := MeshInstance3D.new()
	mi.name = "EmissiveControl"
	mi.mesh = q
	mi.material_override = mat
	mi.layers = DioramaStage.LAYER_SET
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.basis = cam.global_basis
	return mi


func _report(state: String, e: Dictionary) -> void:
	print("emissive_bleed_capture: %s %s (silhouette %d px, emissive %d px from %d source(s), bleed %d px)" % [
			state, "PASS" if bool(e["pass"]) else "FAIL", int(e["silhouette_pixels"]),
			int(e["emissive_pixels"]), int(e["emissive_sources"]), int(e["bleed_pixels"])])


## Boots `BattleMode` into one state and freezes it (as `ui_tint_capture.gd`).
func _boot_scene(enc_id: String, what: String) -> BattleMode:
	var mode: BattleMode = _boot_battle(enc_id)
	if mode == null:
		return null
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	match what:
		"defeat":
			DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.DEFEAT)
			mode.settle_replay()
			for i: int in 30:
				await process_frame
		"victory":
			DebugLaunchArgs.force_outcome(mode.battle, DebugLaunchArgs.VICTORY)
			mode.set_process(false)
			var guard: int = 0
			while guard < 100000:
				mode.step_replay(VICTORY_STEP)
				guard += 1
				if mode._end_hold_left >= 0.0 \
						and mode._end_hold_clock() >= mode.presentation_config.blend_victory:
					break
			for i: int in 5:
				await process_frame
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	return mode


func _boot_battle(enc_id: String) -> BattleMode:
	if _catalog == null:
		var catalog: ContentCatalogService = BattleCatalog.shipped()
		var boot: ContentBootResult = ContentBootstrap.run(catalog)
		if boot == null or catalog.state != ContentCatalogService.State.READY:
			printerr("emissive_bleed_capture: content boot failed: %s" % [catalog.report])
			return null
		_catalog = catalog
	var d := EncounterDescriptor.new()
	if enc_id.is_empty():
		d.encounter_id = "adhoc_megacorp_boss"
		d.enemy_ids = PackedStringArray(MEGACORP_ENEMIES)
		d.faction_id = MEGACORP_FACTION
		d.is_boss = true
	else:
		var rec: EncounterData = _catalog.get_record(&"encounter", enc_id) as EncounterData
		if rec == null:
			printerr("emissive_bleed_capture: unknown encounter %s" % enc_id)
			return null
		d.encounter_id = rec.id
		d.enemy_ids = rec.enemy_ids
		d.battle_stage_id = rec.battle_stage_id
		d.faction_id = rec.faction_id
		d.is_boss = rec.is_boss
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = ChapterFlow.build_squad(_catalog)
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	root.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	return mode


## The Overworld on the town map at its entry point, `overworld` light, frozen.
func _boot_overworld() -> OverworldMode:
	var mode: OverworldMode = (load("res://src/overworld/overworld_mode.tscn") as PackedScene).instantiate() as OverworldMode
	mode.setup(null, MapEntryPayload.new(OVERWORLD_MAP, &""))
	root.add_child(mode)
	var stage: DioramaStage = _find_stage(mode)
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	for i: int in 30:
		await process_frame
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	return mode


func _find_stage(n: Node) -> DioramaStage:
	for c: Node in n.find_children("*", "Node3D", true, false):
		if c is DioramaStage:
			return c as DioramaStage
	return null


func _free_node(n: Node) -> void:
	root.remove_child(n)
	n.free()
	for i: int in 3:
		await process_frame


static func _union(a: Image, b: Image) -> Image:
	var ra: Image = a.duplicate() as Image
	ra.convert(Image.FORMAT_L8)
	var rb: Image = b.duplicate() as Image
	rb.convert(Image.FORMAT_L8)
	var da: PackedByteArray = ra.get_data()
	var db: PackedByteArray = rb.get_data()
	for i: int in da.size():
		da[i] = maxi(da[i], db[i])
	return Image.create_from_data(ra.get_width(), ra.get_height(), false, Image.FORMAT_L8, da)


static func _names(geos: Array[GeometryInstance3D]) -> Array[String]:
	var out: Array[String] = []
	for g: GeometryInstance3D in geos:
		out.append(String(g.name))
	return out


func _save(img: Image, out_dir: String, file_name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(out_dir.path_join("%s.png" % file_name)))


func _grab() -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile
