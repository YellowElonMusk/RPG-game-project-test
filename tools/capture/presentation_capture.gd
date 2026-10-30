class_name PresentationCapture
extends Node
## The deterministic presentation capture tool (ADR-0005 §13, Migration Step
## 1c, test plan P-09; story sprite-camera-presentation 002). It renders a
## scene in an offscreen `SubViewport` and writes the passes the GDD's [C]
## acceptance criteria measure:
##
##   final        the normal lit frame (reference);
##   id           per-class override materials: `actor`, `set` and the §14
##                capture-ID tags (`SKY`, `notice_slip`, ... `symbol`), each a
##                flat unlit colour from `palette()`;
##   shadow_mask  pixels that change when the set light's shadow is switched
##                off (white = in the set-light shadow);
##   unlit_albedo `Viewport.DEBUG_DRAW_UNSHADED`;
##   ui           the 2D/UI layer alone (3D disabled, transparent background);
##   glow_input   the glow-input hook (item 15), or a recorded "Pending".
##
## Every pass is taken on the same frozen frame: the scene's processing is
## disabled for the whole capture, so only the pass setup differs.
##
## The capture `SubViewport` sets every rendering setting it has from the
## project settings explicitly (`VIEWPORT_SETTINGS`): a `SubViewport` does
## not inherit MSAA, screen-space AA or the positional shadow atlas size
## (ADR-0005 item 8, observed 2048 vs 4096). What it set is recorded in the
## measurements file.
##
## A cue node carries its tag as node metadata `capture_id` (ADR-0005 §14);
## the tag applies to every `GeometryInstance3D` under that node. Untagged
## geometry on the actor cull layer is `actor`, everything else `set`.
##
## Usage: a Visual/Feel tool, run windowed (see `capture_main.gd`):
##
##   godot --path . -s res://tools/capture/capture_main.gd [-- --scene=res://x.tscn --out=res://dir/]

## Node metadata key holding a cue's capture-ID tag (ADR-0005 §14).
const META_CAPTURE_ID: StringName = &"capture_id"
## Class of untagged geometry on the actor cull layer.
const CLASS_ACTOR: String = "actor"
## Class of untagged geometry everywhere else.
const CLASS_SET: String = "set"
## The §14 capture-ID tags, in palette order after `actor` and `set`.
const CAPTURE_TAGS: Array[String] = ["SKY", "notice_slip", "chase_tag", "stun_pose",
		"checkpoint_open", "checkpoint_closed", "safe_paving", "beacon", "camp_sign",
		"interact_prompt", "symbol"]
## Glow-input hook status when the engine offers no readable glow input.
const GLOW_PENDING: String = "Pending"
## Glow-input hook status when a post-glow, pre-tonemap callback exists.
const GLOW_AVAILABLE: String = "available"
## The callback the glow hook needs something after.
const GLOW_LAST_KNOWN_CALLBACK: String = "EFFECT_CALLBACK_TYPE_POST_TRANSPARENT"

## [viewport property, project setting, fallback]. The fallback is used only
## when the project setting does not exist; the value is always assigned.
const VIEWPORT_SETTINGS: Array = [
	["msaa_3d", "rendering/anti_aliasing/quality/msaa_3d", 0],
	["screen_space_aa", "rendering/anti_aliasing/quality/screen_space_aa", 0],
	["use_taa", "rendering/anti_aliasing/quality/use_taa", false],
	["use_debanding", "rendering/anti_aliasing/quality/use_debanding", false],
	["positional_shadow_atlas_size", "rendering/lights_and_shadows/positional_shadow/atlas_size", 4096],
	["positional_shadow_atlas_16_bits", "rendering/lights_and_shadows/positional_shadow/atlas_16_bits", true],
	["positional_shadow_atlas_quad_0", "rendering/lights_and_shadows/positional_shadow/atlas_quadrant_0_subdiv", 2],
	["positional_shadow_atlas_quad_1", "rendering/lights_and_shadows/positional_shadow/atlas_quadrant_1_subdiv", 2],
	["positional_shadow_atlas_quad_2", "rendering/lights_and_shadows/positional_shadow/atlas_quadrant_2_subdiv", 3],
	["positional_shadow_atlas_quad_3", "rendering/lights_and_shadows/positional_shadow/atlas_quadrant_3_subdiv", 4],
	["scaling_3d_mode", "rendering/scaling_3d/mode", 0],
	["scaling_3d_scale", "rendering/scaling_3d/scale", 1.0],
	["mesh_lod_threshold", "rendering/mesh_lod/lod_change/threshold_pixels", 1.0],
]

## Channel levels the ID palette uses; read-back snaps to the nearest.
const _LEVELS: Array[int] = [0, 128, 255]
## Max per-channel distance from a level for a pixel to be classified.
const _LEVEL_TOLERANCE: int = 24

const _ID_SHADER_CODE: String = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 id_color : source_color = vec4(1.0);
uniform sampler2D id_mask : source_color, filter_nearest;
uniform bool use_mask = false;
void fragment() {
	ALBEDO = id_color.rgb;
	ALPHA = use_mask ? texture(id_mask, UV).a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## Render size of the capture `SubViewport`.
var capture_size: Vector2i = Vector2i(1280, 720)
## Frames rendered after each pass setup before reading back.
var settle_frames: int = 3
## Reads a project setting: `(key: String, fallback: Variant) -> Variant`.
var read_setting: Callable = func(key: String, fallback: Variant) -> Variant:
	return ProjectSettings.get_setting(key, fallback)

var _viewport: SubViewport = null
var _id_shader: Shader = null


## Builds the capture `SubViewport` (a child of this node) and applies the
## explicit settings. Returns the settings record (see `apply_viewport_settings`).
func setup() -> Dictionary:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "CaptureViewport"
		add_child(_viewport)
	_viewport.size = capture_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	return apply_viewport_settings(_viewport, read_setting)


## The capture `SubViewport`, or null before `setup()`.
func get_viewport_node() -> SubViewport:
	return _viewport


## Assigns every `VIEWPORT_SETTINGS` property on `vp` from `read` and
## returns `{property: {"setting": key, "value": assigned}}`.
static func apply_viewport_settings(vp: SubViewport, read: Callable) -> Dictionary:
	var record: Dictionary = {}
	for row: Array in VIEWPORT_SETTINGS:
		var value: Variant = read.call(String(row[1]), row[2])
		vp.set(String(row[0]), value)
		record[String(row[0])] = {"setting": row[1], "value": vp.get(String(row[0]))}
	return record


## Every ID class in palette order: `actor`, `set`, then `CAPTURE_TAGS`.
static func id_classes() -> Array[String]:
	var out: Array[String] = [CLASS_ACTOR, CLASS_SET]
	out.append_array(CAPTURE_TAGS)
	return out


## `{class: Color}`: each class a distinct colour whose channels are 0, 128
## or 255 (black is reserved for "nothing rendered").
static func palette() -> Dictionary:
	var classes: Array[String] = id_classes()
	var out: Dictionary = {}
	var i: int = 0
	for r: int in _LEVELS.size():
		for g: int in _LEVELS.size():
			for b: int in _LEVELS.size():
				if r + g + b == 0 or i >= classes.size():
					continue
				out[classes[i]] = Color8(_LEVELS[r], _LEVELS[g], _LEVELS[b])
				i += 1
	return out


## Normalises a `capture_id` value: `sky` (the sky card's tag) becomes `SKY`;
## an unknown tag returns "".
static func normalise_tag(raw: String) -> String:
	if raw.to_upper() == "SKY":
		return "SKY"
	return raw if CAPTURE_TAGS.has(raw) else ""


## The ID class of `geo`: the nearest `capture_id` on it or an ancestor
## (stopping at `stop_at`), else `actor` when it is on `actor_layer`, else `set`.
static func class_of(geo: GeometryInstance3D, actor_layer: int, stop_at: Node = null) -> String:
	var n: Node = geo
	while n != null:
		if n.has_meta(META_CAPTURE_ID):
			var tag: String = normalise_tag(String(n.get_meta(META_CAPTURE_ID)))
			if not tag.is_empty():
				return tag
		if n == stop_at:
			break
		n = n.get_parent()
	return CLASS_ACTOR if (geo.layers & actor_layer) != 0 else CLASS_SET


## Gives every `GeometryInstance3D` under `scene_root` its class's flat ID
## material. Returns the restore map `{GeometryInstance3D: Material or null}`
## for `restore_overrides`. Sprites keep their alpha cut-out (the frame's
## texture alpha).
func apply_id_overrides(scene_root: Node, actor_layer: int) -> Dictionary:
	var colours: Dictionary = palette()
	var restore: Dictionary = {}
	for geo: GeometryInstance3D in _geometry_under(scene_root):
		restore[geo] = geo.material_override
		var mat := ShaderMaterial.new()
		mat.shader = _get_id_shader()
		mat.set_shader_parameter(&"id_color", colours[class_of(geo, actor_layer, scene_root)])
		var tex: Texture2D = _sprite_texture(geo)
		mat.set_shader_parameter(&"use_mask", tex != null)
		if tex != null:
			mat.set_shader_parameter(&"id_mask", tex)
		geo.material_override = mat
	return restore


## Puts back the materials `apply_id_overrides` replaced.
static func restore_overrides(restore: Dictionary) -> void:
	for geo: Variant in restore:
		if is_instance_valid(geo):
			(geo as GeometryInstance3D).material_override = restore[geo] as Material


## Counts an ID-pass image: `{class: {"pixels": n, "share": n / total,
## "bbox": [x, y, w, h]}}` for every class, plus `"none"` (black) and
## `"unclassified"` (anti-aliased edges, anything off-palette).
static func measure_id(img: Image) -> Dictionary:
	var by_key: Dictionary = {}
	var colours: Dictionary = palette()
	for cls: String in colours:
		by_key[_level_key(colours[cls] as Color)] = cls
	var counts: Dictionary = {}
	var boxes: Dictionary = {}
	var rgba: Image = _rgba8(img)
	var data: PackedByteArray = rgba.get_data()
	var w: int = rgba.get_width()
	var total: int = w * rgba.get_height()
	for i: int in total:
		var key: int = _snap_key(data[i * 4], data[i * 4 + 1], data[i * 4 + 2])
		var cls: String = "unclassified"
		if key == 0:
			cls = "none"
		elif by_key.has(key):
			cls = by_key[key]
		counts[cls] = int(counts.get(cls, 0)) + 1
		var x: int = i % w
		var y: int = i / w
		if boxes.has(cls):
			var r: Rect2i = boxes[cls]
			boxes[cls] = r.expand(Vector2i(x, y)).merge(Rect2i(x, y, 1, 1))
		else:
			boxes[cls] = Rect2i(x, y, 1, 1)
	var out: Dictionary = {}
	var names: Array[String] = id_classes()
	names.append_array(["none", "unclassified"])
	for cls: String in names:
		var n: int = int(counts.get(cls, 0))
		var box: Rect2i = boxes.get(cls, Rect2i())
		out[cls] = {"pixels": n, "share": float(n) / float(total) if total > 0 else 0.0,
				"bbox": [box.position.x, box.position.y, box.size.x, box.size.y]}
	return out


## The difference mask of two same-size images: white where any channel
## differs by more than `tolerance` (0-255), black elsewhere. Returns
## `{"image": Image, "pixels": n, "share": n / total}`.
static func diff_mask(a: Image, b: Image, tolerance: int = 2) -> Dictionary:
	var ra: Image = _rgba8(a)
	var rb: Image = _rgba8(b)
	var w: int = ra.get_width()
	var h: int = ra.get_height()
	var da: PackedByteArray = ra.get_data()
	var db: PackedByteArray = rb.get_data()
	var mask := PackedByteArray()
	mask.resize(w * h)
	var n: int = 0
	if rb.get_width() == w and rb.get_height() == h:
		for i: int in w * h:
			var j: int = i * 4
			if absi(da[j] - db[j]) > tolerance or absi(da[j + 1] - db[j + 1]) > tolerance \
					or absi(da[j + 2] - db[j + 2]) > tolerance:
				mask[i] = 255
				n += 1
	var out_img: Image = Image.create_from_data(w, h, false, Image.FORMAT_L8, mask)
	return {"image": out_img, "pixels": n, "share": float(n) / float(w * h) if w * h > 0 else 0.0}


## Opaque-pixel count and bounding box of a transparent-background image
## (the UI-alone pass): `{"pixels": n, "share": f, "bbox": [x, y, w, h]}`.
static func measure_opaque(img: Image) -> Dictionary:
	var rgba: Image = _rgba8(img)
	var used: Rect2i = rgba.get_used_rect()
	var data: PackedByteArray = rgba.get_data()
	var total: int = rgba.get_width() * rgba.get_height()
	var n: int = 0
	for i: int in total:
		if data[i * 4 + 3] > 0:
			n += 1
	return {"pixels": n, "share": float(n) / float(total) if total > 0 else 0.0,
			"bbox": [used.position.x, used.position.y, used.size.x, used.size.y]}


## The glow-input hook (ADR-0005 item 15): looks for a `CompositorEffect`
## callback after `POST_TRANSPARENT` (where the glow input before
## tonemapping would be readable). Returns `{"status": GLOW_AVAILABLE,
## "callback": name}` or `{"status": GLOW_PENDING, "item": 15, "reason": ...}`.
static func probe_glow_hook() -> Dictionary:
	if not ClassDB.class_exists("CompositorEffect"):
		return {"status": GLOW_PENDING, "item": 15,
				"reason": "item (15): CompositorEffect does not exist on this engine"}
	var last: int = ClassDB.class_get_integer_constant("CompositorEffect", GLOW_LAST_KNOWN_CALLBACK)
	for c: String in ClassDB.class_get_enum_constants("CompositorEffect", "EffectCallbackType", true):
		var v: int = ClassDB.class_get_integer_constant("CompositorEffect", c)
		if v > last and not c.ends_with("_MAX") and c != "EFFECT_CALLBACK_TYPE_ANY":
			return {"status": GLOW_AVAILABLE, "item": 15, "callback": c}
	return {"status": GLOW_PENDING, "item": 15,
			"reason": "item (15): no CompositorEffect callback after POST_TRANSPARENT, so the glow input before tonemapping is not readable (spike 2026-10-29 FAIL)"}


## Renders every pass of `scene_root` (moved into the capture viewport for
## the duration, then handed back to its old parent) and returns the result:
## `{"images": {pass: Image}, "measurements": Dictionary}`. `set_light` may be
## null (no shadow mask then). Call `setup()` first; needs a rendering
## device, so it is meaningful only in a windowed run.
func capture(scene_root: Node, set_light: DirectionalLight3D, actor_layer: int) -> Dictionary:
	var settings: Dictionary = setup()
	var old_parent: Node = scene_root.get_parent()
	if old_parent != null:
		old_parent.remove_child(scene_root)
	_viewport.add_child(scene_root)
	var old_mode: ProcessMode = scene_root.process_mode
	scene_root.process_mode = Node.PROCESS_MODE_DISABLED
	var images: Dictionary = {}
	var m: Dictionary = {"tool": "tools/capture/presentation_capture.gd", "size": [capture_size.x, capture_size.y],
			"viewport_settings": settings, "passes": {}}

	_viewport.canvas_cull_mask = 0xFFFFFFFF
	images["final"] = await _grab()

	# ID pass: flat override materials, a neutral camera environment, no UI.
	var cam: Camera3D = _viewport.get_camera_3d()
	var old_env: Environment = cam.environment if cam != null else null
	if cam != null:
		cam.environment = _flat_environment()
	var restore: Dictionary = apply_id_overrides(scene_root, actor_layer)
	_viewport.canvas_cull_mask = 0
	images["id"] = await _grab()
	restore_overrides(restore)
	if cam != null:
		cam.environment = old_env
	m["passes"]["id"] = {"file": "id.png", "palette": _palette_html(), "classes": measure_id(images["id"])}

	# Set-light shadow mask: shadow on vs off, UI hidden.
	if set_light != null:
		var lit: Image = await _grab()
		var was: bool = set_light.shadow_enabled
		set_light.shadow_enabled = not was
		var other: Image = await _grab()
		set_light.shadow_enabled = was
		var diff: Dictionary = diff_mask(lit, other) if was else diff_mask(other, lit)
		images["shadow_mask"] = diff["image"]
		m["passes"]["shadow_mask"] = {"file": "shadow_mask.png", "light": str(set_light.get_path()),
				"shadow_enabled_in_scene": was, "pixels": diff["pixels"], "share": diff["share"]}
	else:
		m["passes"]["shadow_mask"] = {"status": "skipped", "reason": "no set light given"}

	# Unlit albedo.
	_viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	images["unlit_albedo"] = await _grab()
	_viewport.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	m["passes"]["unlit_albedo"] = {"file": "unlit_albedo.png"}

	# UI alone.
	_viewport.canvas_cull_mask = 0xFFFFFFFF
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	images["ui"] = await _grab()
	_viewport.disable_3d = false
	_viewport.transparent_bg = false
	m["passes"]["ui"] = measure_opaque(images["ui"])
	m["passes"]["ui"]["file"] = "ui.png"

	m["passes"]["final"] = {"file": "final.png"}
	m["passes"]["glow_input"] = probe_glow_hook()

	scene_root.process_mode = old_mode
	_viewport.remove_child(scene_root)
	if old_parent != null:
		old_parent.add_child(scene_root)
	return {"images": images, "measurements": m}


## Writes each pass image as `<pass>.png` and the measurements as
## `measurements.json` into `out_dir` (created if missing). Returns OK or
## the first error.
static func write_result(result: Dictionary, out_dir: String) -> Error:
	var dir: String = ProjectSettings.globalize_path(out_dir)
	var err: Error = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return err
	var images: Dictionary = result.get("images", {})
	for pass_name: String in images:
		err = (images[pass_name] as Image).save_png(dir.path_join("%s.png" % pass_name))
		if err != OK:
			return err
	var f := FileAccess.open(dir.path_join("measurements.json"), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(result.get("measurements", {}), "  ", true))
	f.close()
	return OK


func _grab() -> Image:
	for i: int in settle_frames:
		await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


func _get_id_shader() -> Shader:
	if _id_shader == null:
		_id_shader = Shader.new()
		_id_shader.code = _ID_SHADER_CODE
	return _id_shader


static func _flat_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_enabled = false
	return env


static func _palette_html() -> Dictionary:
	var out: Dictionary = {}
	var colours: Dictionary = palette()
	for cls: String in colours:
		out[cls] = "#" + (colours[cls] as Color).to_html(false)
	return out


static func _geometry_under(n: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if n is GeometryInstance3D:
		out.append(n as GeometryInstance3D)
	for c: Node in n.get_children():
		out.append_array(_geometry_under(c))
	return out


static func _sprite_texture(geo: GeometryInstance3D) -> Texture2D:
	if geo is Sprite3D:
		return (geo as Sprite3D).texture
	if geo is AnimatedSprite3D:
		var s := geo as AnimatedSprite3D
		if s.sprite_frames != null and s.sprite_frames.has_animation(s.animation):
			return s.sprite_frames.get_frame_texture(s.animation, s.frame)
	return null


static func _rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img
	var c: Image = img.duplicate() as Image
	c.convert(Image.FORMAT_RGBA8)
	return c


static func _snap(v: int) -> int:
	for li: int in _LEVELS.size():
		if absi(v - _LEVELS[li]) <= _LEVEL_TOLERANCE:
			return li
	return -1


## 0 = black, -1 = off-palette, else a 1-based level-triplet key.
static func _snap_key(r: int, g: int, b: int) -> int:
	var sr: int = _snap(r)
	var sg: int = _snap(g)
	var sb: int = _snap(b)
	if sr < 0 or sg < 0 or sb < 0:
		return -1
	return sr * 9 + sg * 3 + sb


static func _level_key(c: Color) -> int:
	return _snap_key(c.r8, c.g8, c.b8)
