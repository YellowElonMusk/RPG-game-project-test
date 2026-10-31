extends SceneTree
## Story 039's [C] checks (GDD sprite-camera-presentation AC-35, TR-presentation-001;
## ADR-0005 §2, §6, §13). Renders the real modes in the capture tool's
## offscreen `SubViewport` (`PresentationCapture.setup()`), so every sprite
## reads the measured size from `get_viewport().size` exactly as in play:
##
##   Whole-pixel texels: two Battle scenes (Bureaucratia with four enemies,
##   the MegaCorp boss stage) at every `TexelGridCheck.WHOLE_PIXEL_SIZES`.
##   Each sprite is rendered alone (the others hidden, UI hidden) in the ID
##   pass, the unlit-albedo pass and the lit frame; `TexelGridCheck` judges
##   the unlit pass (one colour per `T x T` block on the expected grid, near
##   and far blocks the same size) and the lit pass (ΔE spread <= 3).
##
##   Coverage: Battle and the Overworld at `TexelGridCheck.COVERAGE_SIZES`
##   (16:9, 21:9, 4:3). Every actor's texels lie inside the frame, and the ID
##   pass of the whole scene has no clear-class pixel. Battle's sky is its
##   backdrop canvas layer (`background_mode = BG_CANVAS`), so in its ID pass
##   the backdrop is drawn flat in the `SKY` class colour; the Overworld uses
##   its own geometry as-is.
##
## Records which sprite path shipped (the clip-space card of ADR-0005 §2 or the
## §2 fallback billboard), read from the actor material. Needs a window and a
## GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/texel_scale_capture.gd [-- --out=res://dir/ --only=overworld]
##
## Writes per-size lit/unlit/ID frames, a crop per sprite row, and
## `measurements.json`. Exit 0 iff every check passes.

const DEFAULT_OUT: String = "res://production/qa/evidence/story-039-texel-scale-holds-across-resolutions/"
const SETTLE_FRAMES: int = 3
const OVERWORLD_MAP: String = "map_paris_town_placeholder"
const BATTLES: Array[Dictionary] = [
	{"name": "bureaucratia", "faction": "faction_bureaucratia", "boss": false,
			"enemies": ["enemy_clerk", "enemy_middle_manager", "enemy_supervisor", "enemy_clerk"]},
	{"name": "megacorp_boss", "faction": "faction_megacorp", "boss": true,
			"enemies": ["enemy_security_drone", "enemy_ceo", "enemy_security_drone"]},
]
const _FLAT_SHADER: String = """shader_type canvas_item;
uniform vec4 flat_color : source_color = vec4(1.0);
void fragment() { COLOR = vec4(flat_color.rgb, 1.0); }
"""

var _pc: PresentationCapture
var _vp: SubViewport
var _out: String
var _catalog: ContentCatalogService


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_out = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_catalog = BattleCatalog.shipped()
	var boot: ContentBootResult = ContentBootstrap.run(_catalog)
	if boot == null or _catalog.state != ContentCatalogService.State.READY:
		printerr("texel_scale_capture: content boot failed: %s" % [_catalog.report])
		quit(1)
		return
	_pc = PresentationCapture.new()
	root.add_child(_pc)
	var settings: Dictionary = _pc.setup()
	_vp = _pc.get_viewport_node()
	var report: Dictionary = {"tool": "tools/capture/texel_scale_capture.gd", "ac": "AC-35",
			"viewport_settings": settings, "lit_spread_max": TexelGridCheck.LIT_SPREAD_MAX,
			"battle": {}, "overworld": {}}
	var all_pass: bool = true
	var only: String = String(args.get("only", ""))
	for b: Dictionary in BATTLES:
		if only == "overworld":
			continue
		var entry: Dictionary = await _battle(b)
		report["battle"][b["name"]] = entry
		all_pass = all_pass and bool(entry["pass"])
	var ow: Dictionary = await _overworld()
	report["overworld"] = ow
	all_pass = all_pass and bool(ow["pass"])
	report["result"] = "PASS" if all_pass else "FAIL"
	var f := FileAccess.open(_out.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))
	f.close()
	print("texel_scale_capture: %s -> %s" % [report["result"], _out])
	quit(0 if all_pass else 1)


# -- Battle ------------------------------------------------------------------

func _battle(b: Dictionary) -> Dictionary:
	var d := EncounterDescriptor.new()
	d.encounter_id = String(b["name"])
	d.enemy_ids = PackedStringArray(b["enemies"])
	d.faction_id = String(b["faction"])
	d.is_boss = bool(b["boss"])
	var payload := BattleEntryPayload.new()
	payload.descriptor = d
	payload.party = ChapterFlow.build_squad(_catalog)
	var mode: BattleMode = (load("res://src/battle/battle_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, payload)
	_vp.size = TexelGridCheck.WHOLE_PIXEL_SIZES[0]
	_vp.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"%DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	mode._on_transition_finished(GameStateMachine.Mode.BATTLE)
	for i: int in 90:
		await process_frame
	mode.settle_replay()
	for i: int in 30:
		await process_frame
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	var view: BattleView = mode.get_node(^"%BattleView")
	var ui: Dictionary = _hide_ui(mode, mode.get_node(^"BackdropLayer"))
	var sprites: Dictionary = {}
	for c: Combatant in mode.battle.squad + mode.battle.enemies:
		var s: CharacterSprite = view.get_sprite(c)
		if s != null and s.visible:
			sprites["%s:%s" % ["far" if c.is_enemy else "near", s.name]] = s
	var entry: Dictionary = {"enemies": b["enemies"], "sprite_path": _sprite_path(sprites),
			"whole_pixel": {}, "coverage": {}, "pass": true}
	var sizes: Array[Vector2i] = TexelGridCheck.WHOLE_PIXEL_SIZES.duplicate()
	for c: Vector2i in TexelGridCheck.COVERAGE_SIZES:
		if not sizes.has(c):
			sizes.append(c)
	for size: Vector2i in sizes:
		_vp.size = size
		await process_frame
		view.present()
		var t: int = SpriteProjection.texel_scale(_vp.size.y, mode.presentation_config.texel_base_lines)
		var tag: String = "battle_%s_%dx%d" % [b["name"], size.x, size.y]
		var whole: bool = TexelGridCheck.WHOLE_PIXEL_SIZES.has(size)
		var per: Dictionary = await _per_sprite(stage, sprites, t, whole, tag)
		if whole:
			var v_unlit: Dictionary = TexelGridCheck.whole_pixel_verdict(per["unlit"], t)
			var v_lit: Dictionary = TexelGridCheck.lit_spread_verdict(per["lit"])
			entry["whole_pixel"]["%dx%d" % [size.x, size.y]] = {"T": t, "unlit": _rows(per["unlit"]),
					"lit": _rows(per["lit"]), "unlit_verdict": v_unlit, "lit_verdict": v_lit}
			entry["pass"] = bool(entry["pass"]) and bool(v_unlit["pass"]) and bool(v_lit["pass"])
			print("texel_scale_capture: %s T=%d unlit %s lit %s %s %s" % [tag, t,
					"PASS" if v_unlit["pass"] else "FAIL", "PASS" if v_lit["pass"] else "FAIL",
					v_unlit["failures"], v_lit["failures"]])
		if TexelGridCheck.COVERAGE_SIZES.has(size):
			var cov: Dictionary = await _battle_id_all(mode, stage, tag)
			var v_cov: Dictionary = TexelGridCheck.coverage_verdict(int(cov["none"]), per["id"])
			entry["coverage"]["%dx%d" % [size.x, size.y]] = {"T": t, "id_classes": cov["classes"],
					"sprites": _rows(per["id"]), "verdict": v_cov}
			entry["pass"] = bool(entry["pass"]) and bool(v_cov["pass"])
			print("texel_scale_capture: %s coverage %s %s" % [tag, "PASS" if v_cov["pass"] else "FAIL",
					v_cov["failures"]])
	_restore_visible(ui)
	_vp.remove_child(mode)
	mode.free()
	return entry


## The ID pass of the whole battle scene with the backdrop canvas drawn flat
## in the `SKY` colour. Returns `{"none": n, "classes": measure_id()}`.
func _battle_id_all(mode: BattleMode, stage: DioramaStage, tag: String) -> Dictionary:
	var colours: Dictionary = PresentationCapture.palette()
	var backdrop: CanvasItem = mode.get_node(^"BackdropLayer/Backdrop")
	var old_mat: Material = backdrop.material
	var flat := ShaderMaterial.new()
	flat.shader = Shader.new()
	flat.shader.code = _FLAT_SHADER
	flat.set_shader_parameter(&"flat_color", colours["SKY"])
	backdrop.material = flat
	var env: Environment = PresentationCapture._flat_environment()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	var cam: Camera3D = stage.camera
	var old_env: Environment = cam.environment
	cam.environment = env
	var restore: Dictionary = _pc.apply_id_overrides(stage, DioramaStage.LAYER_ACTORS)
	var img: Image = await _grab()
	PresentationCapture.restore_overrides(restore)
	cam.environment = old_env
	backdrop.material = old_mat
	img.save_png(_out.path_join("%s_id.png" % tag))
	var classes: Dictionary = PresentationCapture.measure_id(img)
	return {"none": int(classes["none"]["pixels"]), "classes": _class_counts(classes)}


# -- Overworld ---------------------------------------------------------------

func _overworld() -> Dictionary:
	var mode: OverworldMode = (load("res://src/overworld/overworld_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, MapEntryPayload.new(OVERWORLD_MAP, &""))
	_vp.size = TexelGridCheck.COVERAGE_SIZES[0]
	_vp.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	for i: int in 60:
		await process_frame
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	var view: OverworldView = mode.get_node(^"OverworldView")
	var ui: Dictionary = _hide_ui(mode, null)
	var party: Dictionary = {"near:leader": view.leader_sprite}
	for i: int in view.follower_sprites.size():
		if view.follower_sprites[i].visible:
			party["near:follower_%d" % (i + 1)] = view.follower_sprites[i]
	var entry: Dictionary = {"map": OVERWORLD_MAP, "sprite_path": _sprite_path(party), "coverage": {},
			"symbols_observation": {}, "set_cut_observation": {}, "pass": true}
	var cfg: PresentationConfig = PresentationValidators.load_config()
	for size: Vector2i in TexelGridCheck.COVERAGE_SIZES:
		_vp.size = size
		await process_frame
		if view.get_camera() != null:
			view.get_camera().snap_to(mode.get_leader_position())
		view._process(0.0)
		var t: int = SpriteProjection.texel_scale(_vp.size.y, cfg.texel_base_lines)
		var tag: String = "overworld_%dx%d" % [size.x, size.y]
		var per: Dictionary = await _per_sprite(stage, party, t, false, tag)
		# The whole scene: lit frame for eyes, then its ID pass.
		var lit: Image = await _grab()
		lit.save_png(_out.path_join("%s_lit.png" % tag))
		var cam: Camera3D = stage.camera if stage.camera != null else _vp.get_camera_3d()
		var old_env: Environment = cam.environment
		cam.environment = PresentationCapture._flat_environment()
		var restore: Dictionary = _pc.apply_id_overrides(mode, DioramaStage.LAYER_ACTORS)
		var id_img: Image = await _grab()
		PresentationCapture.restore_overrides(restore)
		cam.environment = old_env
		id_img.save_png(_out.path_join("%s_id.png" % tag))
		var classes: Dictionary = PresentationCapture.measure_id(id_img)
		var v_cov: Dictionary = TexelGridCheck.coverage_verdict(int(classes["none"]["pixels"]), per["id"])
		entry["coverage"]["%dx%d" % [size.x, size.y]] = {"T": t, "id_classes": _class_counts(classes),
				"sprites": _rows(per["id"]), "verdict": v_cov}
		# AC-35 [VF] "cutting into the set", measured: texels of an actor drawn
		# alone that set geometry covers (not a frame-bounds failure).
		var cut: Dictionary = {}
		for key: String in per["id"]:
			if int(per["id"][key]["split"]) > 0:
				cut[key] = int(per["id"][key]["split"])
		entry["set_cut_observation"]["%dx%d" % [size.x, size.y]] = cut
		entry["pass"] = bool(entry["pass"]) and bool(v_cov["pass"])
		# Symbols may stand partly off-screen in play (walking in from an edge):
		# recorded, not judged.
		var sym: Dictionary = {}
		var frame := Rect2i(Vector2i.ZERO, size)
		for brain: Variant in view.get_symbol_sprites():
			var s := view.get_symbol_sprites()[brain] as CharacterSprite
			if s == null or not s.visible:
				continue
			var r := Rect2i((s.material_override as ShaderMaterial).get_shader_parameter(&"sprite_rect"))
			if r.intersects(frame):
				sym[String(s.name)] = {"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
						"inside": frame.encloses(r)}
		entry["symbols_observation"]["%dx%d" % [size.x, size.y]] = sym
		print("texel_scale_capture: %s coverage %s %s" % [tag, "PASS" if v_cov["pass"] else "FAIL",
				v_cov["failures"]])
	_restore_visible(ui)
	_vp.remove_child(mode)
	mode.free()
	return entry


# -- Shared ------------------------------------------------------------------

## Renders each sprite alone (the others hidden): the ID pass, then (when
## `whole`) the unlit-albedo and lit frames, and measures each with
## `TexelGridCheck.check_sprite`. Returns `{"id": {...}, "unlit": {...},
## "lit": {...}}` keyed like `sprites`. Saves the unlit and lit frames of
## the whole row set and a crop of the first near and far sprite.
func _per_sprite(stage: DioramaStage, sprites: Dictionary, t: int, whole: bool, tag: String) -> Dictionary:
	var id_colour: Color = PresentationCapture.palette()[PresentationCapture.CLASS_ACTOR]
	var out: Dictionary = {"id": {}, "unlit": {}, "lit": {}}
	if whole:
		(await _grab()).save_png(_out.path_join("%s_lit.png" % tag))
		(await _grab_unlit(stage, sprites)).save_png(_out.path_join("%s_unlit.png" % tag))
	var cropped: Dictionary = {}
	for key: String in sprites:
		var s: CharacterSprite = sprites[key]
		for other: String in sprites:
			(sprites[other] as Node3D).visible = other == key
		var mat := s.material_override as ShaderMaterial
		var rect := Rect2i(mat.get_shader_parameter(&"sprite_rect"))
		var flip: bool = bool(mat.get_shader_parameter(&"flip_h"))
		var frame: Image = (mat.get_shader_parameter(&"frame_tex") as Texture2D).get_image()
		var cam: Camera3D = stage.camera if stage.camera != null else _vp.get_camera_3d()
		var old_env: Environment = cam.environment
		cam.environment = PresentationCapture._flat_environment()
		var restore: Dictionary = _pc.apply_id_overrides(stage, DioramaStage.LAYER_ACTORS)
		var id_img: Image = await _grab()
		PresentationCapture.restore_overrides(restore)
		cam.environment = old_env
		out["id"][key] = TexelGridCheck.check_sprite(frame, rect, t, flip, id_img, id_colour)
		out["id"][key]["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		if s.card_camera != null:
			var a: Vector2 = SpriteProjection.project_to_screen(s.global_position,
					SpriteProjection.CameraState.from_camera3d(s.card_camera, _vp.size), _vp.size)
			out["id"][key]["anchor_px"] = [a.x, a.y]
		if whole:
			var unlit: Image = await _grab_unlit(stage, sprites)
			var lit: Image = await _grab()
			out["unlit"][key] = TexelGridCheck.check_sprite(frame, rect, t, flip, id_img, id_colour, unlit)
			out["lit"][key] = TexelGridCheck.check_sprite(frame, rect, t, flip, id_img, id_colour, lit)
			var row: String = key.get_slice(":", 0)
			if not cropped.has(row):
				cropped[row] = true
				var area: Rect2i = rect.grow(2 * t).intersection(Rect2i(Vector2i.ZERO, _vp.size))
				unlit.get_region(area).save_png(_out.path_join("%s_crop_%s_unlit.png" % [tag, key.replace(":", "_")]))
				lit.get_region(area).save_png(_out.path_join("%s_crop_%s_lit.png" % [tag, key.replace(":", "_")]))
	for key: String in sprites:
		(sprites[key] as Node3D).visible = true
	return out


## The unlit-albedo frame for actors. `Viewport.DEBUG_DRAW_UNSHADED` draws the
## actor card shader pure black on 4.7.2 (observed in this story's first run:
## every actor pixel #000000), so it cannot show a texel's colour. Instead each
## actor gets its card shader's unlit variant (same vertex() projection and
## alpha cut, `render_mode unshaded`, no emission) under the capture tool's
## flat linear environment: each pixel is then its texel's albedo.
func _grab_unlit(stage: DioramaStage, sprites: Dictionary) -> Image:
	var cam: Camera3D = stage.camera if stage.camera != null else _vp.get_camera_3d()
	var old_env: Environment = cam.environment
	cam.environment = PresentationCapture._flat_environment()
	var restore: Dictionary = {}
	var shaders: Dictionary = {}
	for key: String in sprites:
		var s: CharacterSprite = sprites[key]
		var src := s.material_override as ShaderMaterial
		if not PresentationCapture.is_actor_card_material(src):
			continue
		if not shaders.has(src.shader):
			var sh := Shader.new()
			sh.code = unlit_actor_shader_code(src.shader.code)
			shaders[src.shader] = sh
		var mat := ShaderMaterial.new()
		mat.shader = shaders[src.shader]
		for u: StringName in PresentationCapture.uniform_names(src.shader.code):
			mat.set_shader_parameter(u, src.get_shader_parameter(u))
		restore[s] = src
		s.material_override = mat
	var img: Image = await _grab()
	PresentationCapture.restore_overrides(restore)
	cam.environment = old_env
	return img


## The actor card shader `code` made unlit: `render_mode unshaded` (cull and
## shadows as the ID variant) and `EMISSION` zeroed at the end of fragment(),
## so the rim never tints a texel. Projection and alpha cut are untouched.
static func unlit_actor_shader_code(code: String) -> String:
	var re := RegEx.create_from_string("render_mode[^;]*;")
	var out: String = re.sub(code, "render_mode unshaded, cull_disabled, shadows_disabled;", false)
	var close: int = out.rfind("}")
	if close < 0:
		return out
	return out.substr(0, close) + "\tEMISSION = vec3(0.0);\n" + out.substr(close)


## Which sprite path shipped: the ADR-0005 §2 clip-space card when every
## actor material is the card shader, else the fallback billboard.
func _sprite_path(sprites: Dictionary) -> String:
	for key: String in sprites:
		if not PresentationCapture.is_actor_card_material((sprites[key] as GeometryInstance3D).material_override):
			return "fallback billboard (ADR-0005 §2 reserve)"
	return "clip-space card (ADR-0005 §2, sprite_actor.gdshader)"


## Hides every UI layer and top-level Control under `mode` except `keep`.
## Returns `{CanvasItem or CanvasLayer: old visible}`.
func _hide_ui(mode: Node, keep: Node) -> Dictionary:
	var restore: Dictionary = {}
	for n: Node in _all_under(mode):
		if n == keep or (keep != null and keep.is_ancestor_of(n)):
			continue
		if n is CanvasLayer:
			restore[n] = (n as CanvasLayer).visible
			(n as CanvasLayer).visible = false
		elif n is Control and n.get_parent() == mode:
			restore[n] = (n as Control).visible
			(n as Control).visible = false
		elif n is Label3D:
			restore[n] = (n as Label3D).visible
			(n as Label3D).visible = false
	return restore


func _restore_visible(restore: Dictionary) -> void:
	for n: Variant in restore:
		if is_instance_valid(n):
			n.set("visible", restore[n])


func _all_under(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c: Node in n.get_children():
		out.append(c)
		out.append_array(_all_under(c))
	return out


func _rows(results: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in results:
		var m: Dictionary = (results[key] as Dictionary).duplicate()
		var b: Vector2i = m["block"]
		m["block"] = [b.x, b.y]
		out[key] = m
	return out


func _class_counts(classes: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cls: String in classes:
		if int(classes[cls]["pixels"]) > 0:
			out[cls] = int(classes[cls]["pixels"])
	return out


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


func _grab() -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()
