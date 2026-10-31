## AC-48 (story sprite-camera-presentation 052, TR-presentation-003/002): no
## emissive source bleeds through an actor's silhouette. Pure, headless-testable
## pieces of the check; `emissive_bleed_capture.gd` renders the images.
##
## The check, per capture: the actor silhouette is the ID pass's `actor` (and
## `symbol`) pixels with the actors shown; the emissive mask is the same ID pass
## rendered once more with every actor hidden and every emissive set source
## drawn in `emissive_colour()`. A pixel in both is an emissive source standing
## behind an actor (its glow would bleed round the silhouette): a failure.
## Emissive pixels beside an actor are outside its silhouette, so they pass.
##
## What is emissive (ADR-0005 §3: "glow takes only emissive set lights"):
## geometry off the actor layer that carries the `capture_id` tag `emissive`
## (on itself or an ancestor), or whose material emits: a `BaseMaterial3D`
## with `emission_enabled`, or a `ShaderMaterial` whose shader writes
## `EMISSION`. Actor geometry is never a source (the actor card's rim is
## written to `EMISSION`). A source under a node tagged `actor_lighting`
## (node metadata, ADR-0005 §3, the campfire) is exempt, as the story's
## implementation notes allow.
class_name EmissiveBleedCheck
extends RefCounted

## The `capture_id` tag (ADR-0005 §14 metadata) marking emissive set geometry
## the material test cannot see (a texture-driven unshaded sign, say).
const EMISSIVE_TAG: String = "emissive"
## Node metadata (truthy) marking a practical that is meant to light actors
## (ADR-0005 §3). Emissive geometry at or under it is exempt from AC-48.
const META_ACTOR_LIGHTING: StringName = &"actor_lighting"
## The ID-palette channel levels (`PresentationCapture`'s), so the reserved
## colour survives the same read-back snapping.
const _LEVELS: Array[int] = [0, 128, 255]
## Max per-channel distance for a pixel to count as a colour (as the ID pass).
const _TOLERANCE: int = 24


## Whether `geo` is an emissive set source (see the class doc).
static func is_emissive(geo: GeometryInstance3D, actor_layer: int) -> bool:
	if (geo.layers & actor_layer) != 0:
		return false
	var n: Node = geo
	while n != null:
		if String(n.get_meta(PresentationCapture.META_CAPTURE_ID, "")) == EMISSIVE_TAG:
			return true
		n = n.get_parent()
	if _material_emits(geo.material_override):
		return true
	var mi := geo as MeshInstance3D
	if mi != null:
		var count: int = mi.get_surface_override_material_count()
		for i: int in count:
			if _material_emits(mi.get_surface_override_material(i)):
				return true
			if mi.mesh != null and i < mi.mesh.get_surface_count() \
					and _material_emits(mi.mesh.surface_get_material(i)):
				return true
	return false


## Whether `n` or an ancestor (up to `stop_at`) is tagged `actor_lighting`.
static func is_actor_lighting(n: Node, stop_at: Node = null) -> bool:
	var walk: Node = n
	while walk != null:
		if bool(walk.get_meta(META_ACTOR_LIGHTING, false)):
			return true
		if walk == stop_at:
			break
		walk = walk.get_parent()
	return false


## The colour emissive sources are drawn in for the emissive mask: the first
## 0/128/255 level triplet that is neither black nor an ID-palette class.
static func emissive_colour() -> Color:
	var used: Array[Color] = []
	var pal: Dictionary = PresentationCapture.palette()
	for cls: String in pal:
		used.append(pal[cls] as Color)
	for r: int in _LEVELS:
		for g: int in _LEVELS:
			for b: int in _LEVELS:
				if r + g + b == 0:
					continue
				var c := Color8(r, g, b)
				if not used.has(c):
					return c
	return Color.BLACK


## L8 mask of the pixels of `img` within the ID tolerance of `colour` on
## every channel: `{"image": Image, "pixels": n}`.
static func colour_mask(img: Image, colour: Color) -> Dictionary:
	var rgba: Image = _rgba8(img)
	var w: int = rgba.get_width()
	var h: int = rgba.get_height()
	var data: PackedByteArray = rgba.get_data()
	var px := PackedByteArray()
	px.resize(w * h)
	var n: int = 0
	var cr: int = colour.r8
	var cg: int = colour.g8
	var cb: int = colour.b8
	for i: int in w * h:
		var j: int = i * 4
		if absi(data[j] - cr) <= _TOLERANCE and absi(data[j + 1] - cg) <= _TOLERANCE \
				and absi(data[j + 2] - cb) <= _TOLERANCE:
			px[i] = 255
			n += 1
	return {"image": Image.create_from_data(w, h, false, Image.FORMAT_L8, px), "pixels": n}


## The pixels both masks mark (red channel above half): emissive inside a
## silhouette. `{"image": L8 Image, "pixels": n}`; different sizes give 0.
static func bleed(silhouette: Image, emissive: Image) -> Dictionary:
	var rs: Image = _rgba8(silhouette)
	var re: Image = _rgba8(emissive)
	var w: int = rs.get_width()
	var h: int = rs.get_height()
	var px := PackedByteArray()
	px.resize(w * h)
	var n: int = 0
	if re.get_size() == rs.get_size():
		var ds: PackedByteArray = rs.get_data()
		var de: PackedByteArray = re.get_data()
		for i: int in w * h:
			if ds[i * 4] > 127 and de[i * 4] > 127:
				px[i] = 255
				n += 1
	return {"image": Image.create_from_data(w, h, false, Image.FORMAT_L8, px), "pixels": n}


## AC-48's verdict over one capture's `{"silhouette_pixels": n,
## "bleed_pixels": n}`: `{"pass": bool, "failures": PackedStringArray}`. A
## capture with no actor pixels is invalid and fails rather than passing
## vacuously.
static func verdict(result: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	if int(result.get("silhouette_pixels", 0)) <= 0:
		failures.append("no actor silhouette pixels (invalid capture)")
	elif int(result.get("bleed_pixels", 0)) > 0:
		failures.append("%d emissive pixel(s) inside an actor's silhouette" % int(result["bleed_pixels"]))
	return {"pass": failures.is_empty(), "failures": failures}


static func _material_emits(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).emission_enabled
	var sm := mat as ShaderMaterial
	if sm != null and sm.shader != null:
		return RegEx.create_from_string("\\bEMISSION\\s*[+\\-*/]?=").search(sm.shader.code) != null
	return false


static func _rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img
	var c: Image = img.duplicate() as Image
	c.convert(Image.FORMAT_RGBA8)
	return c
