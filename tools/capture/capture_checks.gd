## Pure pass/fail measurements over capture-tool images (ADR-0005 §13, test
## plan P-09) for the GDD's [C] acceptance criteria. Holds no state, touches
## no node and needs no GPU, so every verdict is headless-testable; the
## windowed scripts in `tools/capture/` produce the images and call these.
##
## ΔE is CIEDE2000 throughout (`ColorDifference`, the GDD's ΔE). A mask is an
## image whose red channel is above half where the pixel counts (the L8
## masks `PresentationCapture.tag_mask` returns).
class_name CaptureChecks
extends RefCounted

## AC-67 (story sprite-camera-presentation 072): a squad member's mean ΔE
## between a boss-takeover capture and the same stage's Battle capture may
## not exceed this. An acceptance threshold fixed by the GDD's AC text, not
## a tuning knob.
const SQUAD_TINT_MEAN_MAX: float = 3.0
## AC-67: the 95th-percentile ΔE limit for the same comparison.
const SQUAD_TINT_P95_MAX: float = 6.0
## The percentile AC-67's second limit is taken at (nearest-rank).
const SQUAD_TINT_PERCENTILE: float = 0.95


## ΔE statistics between `a` and `b` over the pixels `mask` marks:
## `{"pixels": n, "mean": f, "p95": f, "max": f}` (all 0 when `n` is 0).
## The percentile is nearest-rank: the `ceil(0.95 n)`-th smallest value.
## Images of different sizes give `pixels` 0.
static func masked_delta_e(a: Image, b: Image, mask: Image) -> Dictionary:
	var ra: Image = _rgba8(a)
	var rb: Image = _rgba8(b)
	var rm: Image = _rgba8(mask)
	var w: int = ra.get_width()
	var h: int = ra.get_height()
	var values := PackedFloat32Array()
	if rb.get_size() == ra.get_size() and rm.get_size() == ra.get_size():
		var da: PackedByteArray = ra.get_data()
		var db: PackedByteArray = rb.get_data()
		var dm: PackedByteArray = rm.get_data()
		for i: int in w * h:
			var j: int = i * 4
			if dm[j] <= 127:
				continue
			values.append(ColorDifference.delta_e_srgb(
					Color8(da[j], da[j + 1], da[j + 2]), Color8(db[j], db[j + 1], db[j + 2])))
	var n: int = values.size()
	if n == 0:
		return {"pixels": 0, "mean": 0.0, "p95": 0.0, "max": 0.0}
	values.sort()
	var total: float = 0.0
	for v: float in values:
		total += v
	var rank: int = clampi(ceili(SQUAD_TINT_PERCENTILE * n) - 1, 0, n - 1)
	return {"pixels": n, "mean": total / float(n), "p95": float(values[rank]), "max": float(values[n - 1])}


## Each mask with every pixel any other mask also marks removed (L8 out):
## a member's pixels where another member overlaps belong to neither, so no
## pixel is ever attributed to the wrong squad member.
static func exclusive_masks(masks: Array[Image]) -> Array[Image]:
	var out: Array[Image] = []
	if masks.is_empty():
		return out
	var size: Vector2i = masks[0].get_size()
	var datas: Array[PackedByteArray] = []
	for m: Image in masks:
		datas.append(_rgba8(m).get_data() if m.get_size() == size else PackedByteArray())
	var count := PackedInt32Array()
	count.resize(size.x * size.y)
	for d: PackedByteArray in datas:
		if d.is_empty():
			continue
		for i: int in size.x * size.y:
			if d[i * 4] > 127:
				count[i] += 1
	for d: PackedByteArray in datas:
		var px := PackedByteArray()
		px.resize(size.x * size.y)
		if not d.is_empty():
			for i: int in size.x * size.y:
				if d[i * 4] > 127 and count[i] == 1:
					px[i] = 255
		out.append(Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, px))
	return out


## AC-67's verdict over `{member_name: masked_delta_e() result}` for one
## faction: `{"pass": bool, "failures": PackedStringArray}`. A member with no
## pixels (or no members at all) is an invalid capture, so it fails rather
## than passing vacuously.
static func squad_tint_verdict(stats_by_member: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	if stats_by_member.is_empty():
		failures.append("no squad member measured")
	for member: Variant in stats_by_member:
		var s: Dictionary = stats_by_member[member]
		if int(s.get("pixels", 0)) <= 0:
			failures.append("%s: no visible actor pixels (invalid capture)" % member)
			continue
		if float(s["mean"]) > SQUAD_TINT_MEAN_MAX:
			failures.append("%s: mean ΔE %.2f > %.1f" % [member, float(s["mean"]), SQUAD_TINT_MEAN_MAX])
		if float(s["p95"]) > SQUAD_TINT_P95_MAX:
			failures.append("%s: p95 ΔE %.2f > %.1f" % [member, float(s["p95"]), SQUAD_TINT_P95_MAX])
	return {"pass": failures.is_empty(), "failures": failures}


static func _rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img
	var c: Image = img.duplicate() as Image
	c.convert(Image.FORMAT_RGBA8)
	return c


# -- Story sprite-camera-presentation 057 (AC-53): the UI is never tinted --

## AC-53: the largest ΔE allowed between the final presented frame and the UI
## layer rendered alone, on every pixel where the UI is opaque. An acceptance
## threshold fixed by the GDD's AC text, not a tuning knob.
const UI_TINT_DELTA_E_MAX: float = 1.0
## Per-channel 8-bit difference still counted as "the same pixel" when the UI
## is rendered alone over black and over white (one level of rounding).
const UI_OPAQUE_TOLERANCE: int = 1


## The opaque-UI mask from the UI layer rendered alone twice, once over a
## black and once over a white background: a pixel is opaque exactly when the
## background does not show through, i.e. both renders agree within
## `tolerance` on every channel. Translucent and empty pixels differ, so they
## are left out (AC-53 scopes the check to full-opacity UI). Returns
## `{"image": L8 Image (white = opaque), "pixels": n}`; images of different
## sizes give `pixels` 0 and an all-black mask.
static func ui_opaque_mask(on_black: Image, on_white: Image,
		tolerance: int = UI_OPAQUE_TOLERANCE) -> Dictionary:
	var rb: Image = _rgba8(on_black)
	var rw: Image = _rgba8(on_white)
	var w: int = rb.get_width()
	var h: int = rb.get_height()
	var px := PackedByteArray()
	px.resize(w * h)
	var n: int = 0
	if rw.get_size() == rb.get_size():
		var db: PackedByteArray = rb.get_data()
		var dw: PackedByteArray = rw.get_data()
		for i: int in w * h:
			var j: int = i * 4
			if absi(db[j] - dw[j]) <= tolerance and absi(db[j + 1] - dw[j + 1]) <= tolerance \
					and absi(db[j + 2] - dw[j + 2]) <= tolerance:
				px[i] = 255
				n += 1
	return {"image": Image.create_from_data(w, h, false, Image.FORMAT_L8, px), "pixels": n}


## AC-53's verdict over one scene's `masked_delta_e()` result (final frame
## vs UI alone, over the opaque-UI mask): `{"pass": bool, "failures":
## PackedStringArray}`. "On every pixel" makes it a max test, not a mean. A
## scene with no opaque UI pixels is an invalid capture and fails.
static func ui_tint_verdict(stats: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	if int(stats.get("pixels", 0)) <= 0:
		failures.append("no opaque UI pixels (invalid capture)")
	elif float(stats["max"]) > UI_TINT_DELTA_E_MAX:
		failures.append("max ΔE %.2f > %.1f (mean %.2f, p95 %.2f over %d px)" % [float(stats["max"]),
				UI_TINT_DELTA_E_MAX, float(stats["mean"]), float(stats["p95"]), int(stats["pixels"])])
	return {"pass": failures.is_empty(), "failures": failures}


## The failure map for evidence: an L8 image, white where `mask` marks the
## pixel and the ΔE between `a` and `b` exceeds `limit`. Returns `{"image":
## Image, "pixels": n}`; mismatched sizes give an all-black map.
static func delta_e_failure_map(a: Image, b: Image, mask: Image, limit: float) -> Dictionary:
	var ra: Image = _rgba8(a)
	var rb: Image = _rgba8(b)
	var rm: Image = _rgba8(mask)
	var w: int = ra.get_width()
	var h: int = ra.get_height()
	var px := PackedByteArray()
	px.resize(w * h)
	var n: int = 0
	if rb.get_size() == ra.get_size() and rm.get_size() == ra.get_size():
		var da: PackedByteArray = ra.get_data()
		var db: PackedByteArray = rb.get_data()
		var dm: PackedByteArray = rm.get_data()
		for i: int in w * h:
			var j: int = i * 4
			if dm[j] <= 127:
				continue
			if ColorDifference.delta_e_srgb(Color8(da[j], da[j + 1], da[j + 2]),
					Color8(db[j], db[j + 1], db[j + 2])) > limit:
				px[i] = 255
				n += 1
	return {"image": Image.create_from_data(w, h, false, Image.FORMAT_L8, px), "pixels": n}
