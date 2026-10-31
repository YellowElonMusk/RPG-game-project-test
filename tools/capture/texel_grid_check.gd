## The measurement behind story 039 (GDD sprite-camera-presentation AC-35;
## ADR-0005 §2, §13): every sprite texel covers exactly one `T x T` block of
## screen pixels on the grid its `SpriteProjection` rectangle defines, each
## block is one colour (unlit) or within a small ΔE spread (lit), the near
## and far rows' blocks are the same size, and every actor lies inside the
## frame with no clear-colour pixel in the ID pass.
##
## Pure and headless (images in, numbers out), like `PunchShiftCheck`; the
## windowed `texel_scale_capture.gd` feeds it real ID, unlit-albedo and lit
## frames of each sprite rendered alone.
class_name TexelGridCheck
extends RefCounted

## AC-35 "Lit spread": the largest CIEDE2000 difference allowed between any
## two pixels of one texel's block in the normal lit mode. An acceptance
## threshold fixed by the GDD's AC text, not a tuning knob.
const LIT_SPREAD_MAX: float = 3.0
## AC-35 "Whole-pixel texels": the window sizes the Battle scene is measured at.
const WHOLE_PIXEL_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900),
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
## AC-35 "Coverage": 16:9, 21:9 and 4:3 at 1080 lines (Battle and Overworld).
const COVERAGE_SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1440, 1080)]
## Per-channel distance from the ID colour still counted as that class (the
## capture tool's `_LEVEL_TOLERANCE`).
const ID_TOLERANCE: int = 24
## A frame texel is opaque when its 8-bit alpha is above this (the actor
## shader's alpha cut at 0.5).
const ALPHA_CUT_8: int = 127


## Checks one sprite. `frame` is its current frame texture; `rect` its
## `sprite_rect` (screen px); `t` the texel scale; `flip` its shader mirror;
## `id_img` an ID pass with this sprite drawn in `id_colour` (and no other
## actor); `colour_img` (optional) the unlit or lit frame of the same render.
## Returns:
##   opaque_texels  texels with alpha above the cut;
##   split          opaque texels whose block is not wholly this sprite's;
##   bleed          transparent texels whose block holds any of its pixels;
##   outside        opaque texels whose block is not wholly inside the image;
##   stray          its pixels outside `rect` (within `rect` grown by 2T);
##   nonuniform     opaque, whole blocks of more than one colour;
##   inconsistent   uniform blocks whose source colour renders differently
##                  elsewhere in the same sprite (a texel sampled off-grid);
##   source_colours, rendered_colours  distinct colours of its opaque texels
##                  and of its whole blocks in `colour_img` (-1 without one): a
##                  many-coloured sprite drawn flat proves nothing;
##   max_spread     the largest ΔE between two pixels of one block;
##   block          the measured texel size: its pixels' bounding box over
##                  the frame's opaque bounds (-1 on an axis when not whole).
static func check_sprite(frame: Image, rect: Rect2i, t: int, flip: bool, id_img: Image,
		id_colour: Color, colour_img: Image = null) -> Dictionary:
	var fr: Image = _rgba8(frame)
	var ids: Image = _rgba8(id_img)
	var fd: PackedByteArray = fr.get_data()
	var idd: PackedByteArray = ids.get_data()
	var w: int = ids.get_width()
	var h: int = ids.get_height()
	var cd := PackedByteArray()
	if colour_img != null and colour_img.get_size() == ids.get_size():
		cd = _rgba8(colour_img).get_data()
	var fw: int = fr.get_width()
	var fh: int = fr.get_height()
	var img_rect := Rect2i(0, 0, w, h)
	var want := Vector3i(id_colour.r8, id_colour.g8, id_colour.b8)
	var out: Dictionary = {"opaque_texels": 0, "split": 0, "bleed": 0, "outside": 0, "stray": 0,
			"nonuniform": 0, "inconsistent": 0, "max_spread": 0.0, "block": Vector2i.ZERO}
	var rendered: Dictionary = {}
	var sources: Dictionary = {}
	var mapping: Dictionary = {}
	for v: int in fh:
		for col: int in fw:
			var u: int = fw - 1 - col if flip else col
			var opaque: bool = fd[(v * fw + u) * 4 + 3] > ALPHA_CUT_8
			var block := Rect2i(rect.position + Vector2i(col * t, v * t), Vector2i(t, t))
			if opaque:
				out["opaque_texels"] += 1
			if not img_rect.encloses(block):
				if opaque:
					out["outside"] += 1
				continue
			var covered: int = 0
			var colours: Dictionary = {}
			for y: int in range(block.position.y, block.end.y):
				for x: int in range(block.position.x, block.end.x):
					var j: int = (y * w + x) * 4
					if _is_id(idd, j, want):
						covered += 1
					if opaque and not cd.is_empty():
						colours[(cd[j] << 16) | (cd[j + 1] << 8) | cd[j + 2]] = true
			if not opaque:
				if covered > 0:
					out["bleed"] += 1
				continue
			if covered != t * t:
				out["split"] += 1
				continue
			if cd.is_empty():
				continue
			var k0: int = (v * fw + u) * 4
			sources[(fd[k0] << 16) | (fd[k0 + 1] << 8) | fd[k0 + 2]] = true
			for ck: Variant in colours:
				rendered[ck] = true
			if colours.size() > 1:
				out["nonuniform"] += 1
				out["max_spread"] = maxf(float(out["max_spread"]), _spread(colours.keys()))
			else:
				var k: int = (v * fw + u) * 4
				var src: int = (fd[k] << 16) | (fd[k + 1] << 8) | fd[k + 2]
				var got: int = int(colours.keys()[0])
				if mapping.has(src) and int(mapping[src]) != got:
					out["inconsistent"] += 1
				else:
					mapping[src] = got
	out["source_colours"] = sources.size()
	out["rendered_colours"] = rendered.size() if not cd.is_empty() else -1
	# Stray pixels and the measured block size, around the rect.
	var area: Rect2i = rect.grow(2 * t).intersection(img_rect)
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if not _is_id(idd, (y * w + x) * 4, want):
				continue
			if not rect.has_point(Vector2i(x, y)):
				out["stray"] += 1
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var used: Rect2i = fr.get_used_rect()
	if hi.x >= 0 and used.size.x > 0 and used.size.y > 0:
		var seen: Vector2i = hi - lo + Vector2i.ONE
		out["block"] = Vector2i(seen.x / used.size.x if seen.x % used.size.x == 0 else -1,
				seen.y / used.size.y if seen.y % used.size.y == 0 else -1)
	return out


## AC-35 "Whole-pixel texels" over `{name: check_sprite() result}` at one
## size: every sprite measured, no split, bleed, outside, stray, non-uniform
## or inconsistent block, and every sprite's measured block `(t, t)` -- so the
## near and far rows' blocks are the same size. Returns `{"pass": bool,
## "failures": PackedStringArray}`; nothing measured fails.
static func whole_pixel_verdict(results: Dictionary, t: int) -> Dictionary:
	var failures := PackedStringArray()
	if results.is_empty():
		failures.append("nothing measured")
	for name: Variant in results:
		var m: Dictionary = results[name]
		if int(m["opaque_texels"]) <= 0 or m["block"] == Vector2i.ZERO:
			failures.append("%s: no sprite pixels (invalid capture)" % name)
			continue
		for key: String in ["split", "bleed", "outside", "stray", "nonuniform", "inconsistent"]:
			if int(m[key]) > 0:
				failures.append("%s: %d %s texel(s)" % [name, int(m[key]), key])
		if int(m.get("source_colours", 0)) > 1 and int(m.get("rendered_colours", -1)) == 1:
			failures.append("%s: the colour pass draws it in one flat colour (vacuous)" % name)
		if m["block"] != Vector2i(t, t):
			failures.append("%s: blocks measure %s, expected %s" % [name, m["block"], Vector2i(t, t)])
	return {"pass": failures.is_empty(), "failures": failures}


## AC-35 "Lit spread" over `{name: check_sprite() result}` from lit frames:
## every sprite measured and each block's internal ΔE spread <= `limit`.
static func lit_spread_verdict(results: Dictionary, limit: float = LIT_SPREAD_MAX) -> Dictionary:
	var failures := PackedStringArray()
	if results.is_empty():
		failures.append("nothing measured")
	for name: Variant in results:
		var m: Dictionary = results[name]
		if int(m["opaque_texels"]) <= 0:
			failures.append("%s: no sprite pixels (invalid capture)" % name)
		elif float(m["max_spread"]) > limit:
			failures.append("%s: block ΔE spread %.2f > %.1f" % [name, float(m["max_spread"]), limit])
	return {"pass": failures.is_empty(), "failures": failures}


## AC-35 "Coverage": no ID-pass pixel is the clear class (`none_pixels` 0),
## and every sprite in `results` was measured with no texel outside the
## frame. A texel the set covers (`split`) is inside the frame: it is the
## [VF] "cutting into the set" concern and the whole-pixel verdict's, not
## this one's, so it is reported by the caller rather than judged here.
static func coverage_verdict(none_pixels: int, results: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	if none_pixels > 0:
		failures.append("%d ID-pass pixel(s) are the clear class" % none_pixels)
	if results.is_empty():
		failures.append("no actor measured")
	for name: Variant in results:
		var m: Dictionary = results[name]
		if int(m["opaque_texels"]) <= 0:
			failures.append("%s: no sprite pixels (invalid capture)" % name)
		if int(m["outside"]) > 0:
			failures.append("%s: %d texel(s) outside the frame" % [name, int(m["outside"])])
	return {"pass": failures.is_empty(), "failures": failures}


## The largest pairwise ΔE among packed 0xRRGGBB colours.
static func _spread(keys: Array) -> float:
	var best: float = 0.0
	for i: int in keys.size():
		var a: int = int(keys[i])
		var ca := Color8((a >> 16) & 255, (a >> 8) & 255, a & 255)
		for j: int in range(i + 1, keys.size()):
			var b: int = int(keys[j])
			best = maxf(best, ColorDifference.delta_e_srgb(ca, Color8((b >> 16) & 255, (b >> 8) & 255, b & 255)))
	return best


static func _is_id(data: PackedByteArray, j: int, want: Vector3i) -> bool:
	return absi(data[j] - want.x) <= ID_TOLERANCE and absi(data[j + 1] - want.y) <= ID_TOLERANCE \
			and absi(data[j + 2] - want.z) <= ID_TOLERANCE


static func _rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img
	var c: Image = img.duplicate() as Image
	c.convert(Image.FORMAT_RGBA8)
	return c
