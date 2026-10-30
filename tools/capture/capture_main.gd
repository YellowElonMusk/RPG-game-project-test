extends SceneTree
## Windowed entry point for `PresentationCapture` (ADR-0005 §13; story
## sprite-camera-presentation 002). Needs a window and a GPU, never
## `--headless`:
##
##   godot --path . -s res://tools/capture/capture_main.gd
##   godot --path . -s res://tools/capture/capture_main.gd -- --scene=res://path/scene.tscn --out=res://dir/
##
## Without `--scene` it captures a built-in fixture diorama that exercises
## every pass (set, actor, sky card, tagged cues, a set-light shadow, glow, a
## UI panel). With `--scene` the scene's first `DirectionalLight3D` named
## `SetLight` (or the live `DioramaStage.set_light`) is the shadow-mask light.
## Writes `<pass>.png` plus `measurements.json` into the output directory
## (default: the story-002 evidence folder). Exit 0 on success, 1 on failure.
## `--fixture=cues` adds one node per §14 capture-ID tag and a wall half in
## front of the beacon (story overworld 134).

const DEFAULT_OUT: String = "res://production/qa/evidence/story-002-capture-tool/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var out_dir: String = String(args.get("out", DEFAULT_OUT))
	var scene: Node = null
	var set_light: DirectionalLight3D = null
	if args.has("scene"):
		var packed: PackedScene = load(String(args["scene"])) as PackedScene
		if packed == null:
			printerr("capture_main: cannot load scene %s" % args["scene"])
			quit(1)
			return
		scene = packed.instantiate()
		var stage: DioramaStage = _find_stage(scene)
		set_light = stage.set_light if stage != null else scene.find_child("SetLight", true, false) as DirectionalLight3D
	else:
		scene = _fixture()
		if String(args.get("fixture", "")) == "cues":
			_add_cue_fixture(scene)
		set_light = scene.get_node(^"SetLight") as DirectionalLight3D

	var tool := PresentationCapture.new()
	root.add_child(tool)
	var result: Dictionary = await tool.capture(scene, set_light, DioramaStage.LAYER_ACTORS)
	var err: Error = PresentationCapture.write_result(result, out_dir)
	scene.free()
	if err != OK:
		printerr("capture_main: writing %s failed: %s" % [out_dir, error_string(err)])
		quit(1)
		return
	print("capture_main: wrote %s (glow_input: %s)" % [out_dir,
			result["measurements"]["passes"]["glow_input"]["status"]])
	quit(0)


func _find_stage(n: Node) -> DioramaStage:
	if n is DioramaStage:
		return n as DioramaStage
	for c: Node in n.get_children():
		var s: DioramaStage = _find_stage(c)
		if s != null:
			return s
	return null


## A small diorama that exercises every pass.
func _fixture() -> Node3D:
	var s := Node3D.new()
	s.name = "CaptureFixture"
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.2, 7.0)
	cam.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	cam.fov = 40.0
	cam.current = true
	s.add_child(cam)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	s.add_child(we)
	var set_light := DirectionalLight3D.new()
	set_light.name = "SetLight"
	set_light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	set_light.shadow_enabled = true
	set_light.light_cull_mask = DioramaStage.LAYER_SET
	s.add_child(set_light)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, -20.0, 0.0)
	key.light_cull_mask = DioramaStage.LAYER_ACTORS
	s.add_child(key)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(14.0, 14.0)
	s.add_child(_mesh("Floor", floor_mesh, Vector3.ZERO, Color(0.55, 0.5, 0.42), ""))
	var sky := QuadMesh.new()
	sky.size = Vector2(60.0, 24.0)
	s.add_child(_mesh("SkyCard", sky, Vector3(0.0, 6.0, -18.0), Color(0.45, 0.65, 0.95), "sky"))
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.6, 0.8)
	s.add_child(_mesh("Beacon", box, Vector3(2.4, 0.8, -0.5), Color(0.9, 0.8, 0.2), "beacon"))
	var cyl := CylinderMesh.new()
	cyl.height = 1.2
	s.add_child(_mesh("Checkpoint", cyl, Vector3(-2.6, 0.6, -1.0), Color(0.3, 0.8, 0.4), "checkpoint_open"))
	s.add_child(_sprite("Actor", Vector3(-0.6, 0.9, 0.5), Color(0.85, 0.2, 0.6), ""))
	s.add_child(_sprite("Symbol", Vector3(0.9, 0.9, -2.0), Color(0.2, 0.4, 0.9), "symbol"))
	var ui := CanvasLayer.new()
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.1, 0.85)
	panel.position = Vector2(40.0, 600.0)
	panel.size = Vector2(420.0, 80.0)
	ui.add_child(panel)
	var label := Label.new()
	label.text = "UI layer (capture fixture)"
	label.position = Vector2(60.0, 625.0)
	ui.add_child(label)
	s.add_child(ui)
	return s


func _mesh(node_name: String, mesh: Mesh, at: Vector3, colour: Color, tag: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = at
	mi.layers = DioramaStage.LAYER_SET
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	if tag == "sky":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	if not tag.is_empty():
		mi.set_meta(PresentationCapture.META_CAPTURE_ID, tag)
	return mi


func _sprite(node_name: String, at: Vector3, colour: Color, tag: String) -> Sprite3D:
	var img := Image.create(24, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(4, 2, 16, 44), colour)
	var sp := Sprite3D.new()
	sp.name = node_name
	sp.texture = ImageTexture.create_from_image(img)
	sp.pixel_size = 0.04
	sp.position = at
	sp.layers = DioramaStage.LAYER_ACTORS
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not tag.is_empty():
		sp.set_meta(PresentationCapture.META_CAPTURE_ID, tag)
	return sp


## Story overworld 134: one cue per remaining §14 tag, and a set wall that
## hides about half of the beacon (so `id_set_hidden` shows it whole).
func _add_cue_fixture(s: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.4)
	var cues: Array = [["NoticeSlip", "notice_slip", Vector3(-3.6, 2.2, 0.0)],
			["ChaseTag", "chase_tag", Vector3(-2.6, 2.2, 0.0)],
			["StunPose", "stun_pose", Vector3(-1.6, 2.2, 0.0)],
			["CheckpointClosed", "checkpoint_closed", Vector3(-0.6, 2.2, 0.0)],
			["CampSign", "camp_sign", Vector3(0.4, 2.2, 0.0)],
			["InteractPrompt", "interact_prompt", Vector3(1.4, 2.2, 0.0)]]
	for c: Array in cues:
		s.add_child(_mesh(String(c[0]), quad, c[2] as Vector3, Color(0.8, 0.8, 0.8), String(c[1])))
	var paving := PlaneMesh.new()
	paving.size = Vector2(2.0, 1.2)
	s.add_child(_mesh("SafePaving", paving, Vector3(-1.0, 0.02, 2.0), Color(0.7, 0.7, 0.75), "safe_paving"))
	var wall := BoxMesh.new()
	wall.size = Vector3(0.5, 2.4, 0.2)
	s.add_child(_mesh("OccludingWall", wall, Vector3(2.4, 1.2, 0.4), Color(0.6, 0.55, 0.5), ""))
