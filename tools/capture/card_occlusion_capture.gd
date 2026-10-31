extends SceneTree
## Story 073's [C] capture (GDD AC-68 [C], P-09; ADR-0005 §2, §13): upright-
## card occlusion under the pitched Overworld camera. Boots the real
## `OverworldMode` in the capture tool's `SubViewport`, keeps only the party
## leader, and builds the AC-68 fixture around it from `SpriteProjection`:
##
##   wall  a 3 x 3 m slab whose front face stands 0.5 m behind the leader's
##         upright card (through `card_plane_point()`, normal `card_normal()`);
##   prop  a 2 m wide box 5 cm in front of the card, just tall enough that its
##         top edge on screen sits above the sprite's bottom 2 texels.
##
## Every pass is taken from one frozen frame (the mode's processing is off):
## the ID pass of the leader alone, with the fixture, and the fixture with the
## leader hidden. `CardOcclusionCheck.verdict()` judges them. Two negative
## controls rerun the fixture pass with the card shader's plane pushed 0.7 m
## back (behind the wall) and 0.3 m forward (in front of the prop); each must
## FAIL, or the capture fails. Camp has no 3D scene, so no Camp capture exists.
##
## Needs a window and a GPU, never `--headless`:
##
##   godot --path . -s res://tools/capture/card_occlusion_capture.gd [-- --out=res://dir/]
##
## Exit 0 iff the shipped card passes and both controls fail.

const DEFAULT_OUT: String = "res://production/qa/evidence/upright-card-occlusion/"
const SETTLE_FRAMES: int = 3
const SIZE := Vector2i(1920, 1080)
const OVERWORLD_MAP: String = "map_paris_town_placeholder"
const WALL_BEHIND_M: float = 0.5
const PROP_GAP_M: float = 0.05
const PROP_DEPTH_M: float = 0.2
const PROP_MARGIN_M: float = 0.01
## Negative controls: card plane offsets along the card normal (metres).
const CONTROLS: Dictionary = {"card_behind_wall": 0.7, "card_in_front_of_prop": -0.3}
const _PLANE_LINE: String = "vec3 plane_point = _card_plane_point(inv_projection, VIEW_MATRIX);"

var _pc: PresentationCapture
var _vp: SubViewport
var _out: String


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
	var catalog: ContentCatalogService = BattleCatalog.shipped()
	ContentBootstrap.run(catalog)
	if catalog.state != ContentCatalogService.State.READY:
		printerr("card_occlusion_capture: content boot failed: %s" % [catalog.report])
		quit(1)
		return
	_pc = PresentationCapture.new()
	_pc.capture_size = SIZE
	root.add_child(_pc)
	var settings: Dictionary = _pc.setup()
	_vp = _pc.get_viewport_node()
	var report: Dictionary = await _overworld()
	report["viewport_settings"] = settings
	report["camp"] = {"status": "blocked", "reason": "Camp has no 3D scene or camera yet (no DioramaStage)"}
	var f := FileAccess.open(_out.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))
	f.close()
	print("card_occlusion_capture: %s -> %s" % [report["result"], _out])
	quit(0 if report["result"] == "PASS" else 1)


func _overworld() -> Dictionary:
	var mode: OverworldMode = (load("res://src/overworld/overworld_mode.tscn") as PackedScene).instantiate()
	mode.setup(null, MapEntryPayload.new(OVERWORLD_MAP, &""))
	_vp.add_child(mode)
	var stage: DioramaStage = mode.get_node(^"DioramaStage")
	stage.bind_profiles(_resolve_profile)
	stage.apply_profile(_resolve_profile(stage.profile_id), 0.0)
	for i: int in 60:
		await process_frame
	var view: OverworldView = mode.get_node(^"OverworldView")
	if view.get_camera() != null:
		view.get_camera().snap_to(mode.get_leader_position())
	for i: int in 5:
		await process_frame
	mode.process_mode = Node.PROCESS_MODE_DISABLED
	_hide_ui(mode)
	for s: CharacterSprite in view.follower_sprites:
		s.visible = false
	for brain: Variant in view.get_symbol_sprites():
		(view.get_symbol_sprites()[brain] as Node3D).visible = false

	var leader: CharacterSprite = view.leader_sprite
	var mat := leader.material_override as ShaderMaterial
	var rect := Rect2i(mat.get_shader_parameter(&"sprite_rect"))
	var anchor: Vector3 = mat.get_shader_parameter(&"foot_anchor")
	var cs := SpriteProjection.CameraState.from_camera3d(leader.card_camera, _vp.size)
	var cfg: PresentationConfig = PresentationValidators.load_config()
	var t: int = SpriteProjection.texel_scale(_vp.size.y, cfg.texel_base_lines)
	var frame_size := Vector2i((mat.get_shader_parameter(&"frame_tex") as Texture2D).get_size())
	var expected_rect: Rect2i = SpriteProjection.screen_rect(anchor, cs, frame_size, _vp.size, cfg.texel_base_lines)
	var plane_point: Vector3 = SpriteProjection.card_plane_point(rect, anchor, cs, _vp.size)
	var n: Vector3 = SpriteProjection.card_normal(cs)

	# The prop's height: its back face's top edge just above the band's top edge.
	var band_top := Vector2(float(rect.position.x) + float(rect.size.x) * 0.5,
			float(rect.end.y - CardOcclusionCheck.BAND_TEXELS * t))
	var back_point: Vector3 = plane_point - n * PROP_GAP_M
	var d: Vector3 = _pixel_ray(band_top, cs)
	var hit: Vector3 = cs.transform.origin + d * ((back_point - cs.transform.origin).dot(n) / d.dot(n))
	var prop_h: float = hit.y - anchor.y + PROP_MARGIN_M
	var fixture := Node3D.new()
	fixture.name = "CardOcclusionFixture"
	mode.add_child(fixture)
	var facing := Basis.looking_at(n, Vector3.UP)
	_box(fixture, "Wall", Vector3(3.0, 3.0, 0.1), Transform3D(facing,
			Vector3(plane_point.x, anchor.y + 1.5, plane_point.z) + n * (WALL_BEHIND_M + 0.05)),
			CardOcclusionCheck.WALL_COLOR)
	_box(fixture, "Prop", Vector3(2.0, prop_h, PROP_DEPTH_M), Transform3D(facing,
			Vector3(back_point.x, anchor.y + prop_h * 0.5, back_point.z) - n * (PROP_DEPTH_M * 0.5)),
			CardOcclusionCheck.PROP_COLOR)

	var report: Dictionary = {"tool": "tools/capture/card_occlusion_capture.gd", "ac": "AC-68 [C]",
			"map": OVERWORLD_MAP, "size": [SIZE.x, SIZE.y], "T": t,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"rect_matches_sprite_projection": rect == expected_rect,
			"foot_anchor": [anchor.x, anchor.y, anchor.z], "card_plane_point": [plane_point.x, plane_point.y, plane_point.z],
			"card_normal": [n.x, n.y, n.z], "camera_pitch_deg": rad_to_deg(asin(-(-cs.transform.basis.z).y)),
			"wall_behind_m": WALL_BEHIND_M, "prop_height_m": prop_h, "prop_gap_m": PROP_GAP_M}

	# Lit frame for eyes (the fixture draws flat red / orange).
	(await _grab()).save_png(_out.path_join("overworld_fixture_lit.png"))
	# The ID passes, all from this frozen frame.
	var cam: Camera3D = stage.camera if stage.camera != null else _vp.get_camera_3d()
	var old_env: Environment = cam.environment
	cam.environment = PresentationCapture._flat_environment()
	var restore: Dictionary = _pc.apply_id_overrides(mode, DioramaStage.LAYER_ACTORS)
	_restore_fixture_materials(fixture, restore)
	fixture.visible = false
	var alone: Image = await _grab()
	fixture.visible = true
	var with_fixture: Image = await _grab()
	leader.visible = false
	var behind: Image = await _grab()
	leader.visible = true
	PresentationCapture.restore_overrides(restore)
	var v: Dictionary = CardOcclusionCheck.verdict(alone, with_fixture, behind, rect, t)
	report["shipped"] = v
	_save(alone, "alone", rect, t)
	_save(with_fixture, "fixture", rect, t)
	_save(behind, "behind", rect, t)
	print("card_occlusion_capture: shipped card %s %s" % ["PASS" if v["pass"] else "FAIL", v["failures"]])

	# Negative controls: the same fixture pass with the card plane moved.
	var controls_ok: bool = true
	report["negative_controls"] = {}
	for label: String in CONTROLS:
		var variant := ShaderMaterial.new()
		variant.shader = Shader.new()
		variant.shader.code = mat.shader.code.replace(_PLANE_LINE, _PLANE_LINE
				+ "\n\tplane_point += normalize((VIEW_MATRIX * vec4(card_normal, 0.0)).xyz) * card_test_offset;") \
				.replace("uniform vec4 sprite_rect", "uniform float card_test_offset = 0.0;\nuniform vec4 sprite_rect")
		for u: StringName in PresentationCapture.uniform_names(mat.shader.code):
			variant.set_shader_parameter(u, mat.get_shader_parameter(u))
		variant.set_shader_parameter(&"card_test_offset", float(CONTROLS[label]))
		leader.material_override = variant
		var r2: Dictionary = _pc.apply_id_overrides(mode, DioramaStage.LAYER_ACTORS)
		_restore_fixture_materials(fixture, r2)
		var img: Image = await _grab()
		PresentationCapture.restore_overrides(r2)
		leader.material_override = mat
		var cv: Dictionary = CardOcclusionCheck.verdict(alone, img, behind, rect, t)
		_save(img, "control_%s" % label, rect, t)
		report["negative_controls"][label] = {"offset_m": CONTROLS[label], "verdict": cv,
				"failed_as_expected": not bool(cv["pass"])}
		controls_ok = controls_ok and not bool(cv["pass"])
		print("card_occlusion_capture: control %s %s %s" % [label, "FAIL (expected)" if not cv["pass"] else "PASS (UNEXPECTED)",
				cv["failures"]])
	cam.environment = old_env
	report["result"] = "PASS" if bool(v["pass"]) and controls_ok and bool(report["rect_matches_sprite_projection"]) else "FAIL"
	_vp.remove_child(mode)
	mode.free()
	return report


## The fixture keeps its own flat ID colours: put back what
## `apply_id_overrides` gave it (it sits under the mode).
func _restore_fixture_materials(fixture: Node3D, restore: Dictionary) -> void:
	for c: Node in fixture.get_children():
		var geo := c as GeometryInstance3D
		if restore.has(geo):
			geo.material_override = restore[geo] as Material
			restore.erase(geo)


func _box(parent: Node3D, label: String, size: Vector3, xf: Transform3D, colour: Color) -> void:
	var m := MeshInstance3D.new()
	m.name = label
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = colour
	m.material_override = sm
	m.layers = DioramaStage.LAYER_SET
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.transform = xf


func _pixel_ray(px: Vector2, cs: SpriteProjection.CameraState) -> Vector3:
	var ndc := Vector2(px.x / float(_vp.size.x) * 2.0 - 1.0, 1.0 - px.y / float(_vp.size.y) * 2.0)
	var clip: Vector4 = cs.projection.inverse() * Vector4(ndc.x, ndc.y, 0.5, 1.0)
	return cs.transform.basis * (Vector3(clip.x, clip.y, clip.z) / clip.w)


## Saves the full ID frame and a crop around the sprite, upscaled 4x
## (nearest) so the bottom band reads by eye.
func _save(img: Image, label: String, rect: Rect2i, t: int) -> void:
	img.save_png(_out.path_join("overworld_%s_id.png" % label))
	var area: Rect2i = rect.grow(8 * t).intersection(Rect2i(Vector2i.ZERO, _vp.size))
	var crop: Image = img.get_region(area)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join("overworld_%s_id_crop.png" % label))


func _hide_ui(mode: Node) -> void:
	for n: Node in _all_under(mode):
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
		elif n is Control and n.get_parent() == mode:
			(n as Control).visible = false
		elif n is Label3D:
			(n as Label3D).visible = false


func _all_under(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c: Node in n.get_children():
		out.append(c)
		out.append_array(_all_under(c))
	return out


func _resolve_profile(id: StringName) -> LightingProfile:
	return load("res://data/presentation/profiles/%s.tres" % id) as LightingProfile


func _grab() -> Image:
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()
