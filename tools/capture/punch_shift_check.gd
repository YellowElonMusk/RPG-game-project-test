## The measurement behind story 025 (GDD sprite-camera-presentation AC-21b;
## ADR-0005 §6, §13): the hit-punch is a pure `frustum_offset` lens shift, so
## every near actor, far actor and set element in the capture tool's ID pass
## must move by one and the same whole number of pixels, `A_peak` in the
## punch direction, between a frame with no punch and the punch's peak. A
## translation or rotation shake would move near and far depths by different
## amounts, and no single whole-pixel shift would match them exactly.
##
## Pure and headless (images in, numbers out), so it is unit-tested; the
## windowed capture (`punch_shift_capture.gd`) feeds it real ID-pass frames.
class_name PunchShiftCheck
extends RefCounted


## The whole-pixel shift `d` (|d.x|, |d.y| <= `radius`) that best maps image
## `a` onto image `b` inside `region` (in `b`'s coordinates, clipped to the
## image): the number of pixels `p` in `region` whose RGBA in `b` differs
## from `a` at `p - d` (outside `a` matches only black) is
## `mismatch`, minimised. Returns `{"shift": Vector2i, "mismatch": int,
## "runner_up": int (the second-best shift's mismatch: 0 means ambiguous,
## e.g. an empty region), "pixels": int (non-black pixels of `b`
## in the region)}`. Ties keep the smaller |d|, then the first found.
static func best_shift(a: Image, b: Image, region: Rect2i, radius: int) -> Dictionary:
	var ra: Image = _rgba8(a)
	var rb: Image = _rgba8(b)
	var r: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, rb.get_size()))
	var da: PackedByteArray = ra.get_data()
	var db: PackedByteArray = rb.get_data()
	var wa: int = ra.get_width()
	var ha: int = ra.get_height()
	var wb: int = rb.get_width()
	var pixels: int = 0
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var j: int = (y * wb + x) * 4
			if db[j] != 0 or db[j + 1] != 0 or db[j + 2] != 0:
				pixels += 1
	var candidates: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			candidates.append(Vector2i(dx, dy))
	candidates.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return absi(p.x) + absi(p.y) < absi(q.x) + absi(q.y))
	var best: Vector2i = Vector2i.ZERO
	var best_n: int = -1
	var second_n: int = -1
	for d: Vector2i in candidates:
		# Stop counting once this shift can no longer beat the runner-up.
		var cap: int = second_n if second_n >= 0 else -1
		var n: int = 0
		for y: int in range(r.position.y, r.end.y):
			var sy: int = y - d.y
			for x: int in range(r.position.x, r.end.x):
				var sx: int = x - d.x
				var j: int = (y * wb + x) * 4
				var same: bool
				if sx < 0 or sy < 0 or sx >= wa or sy >= ha:
					same = db[j] == 0 and db[j + 1] == 0 and db[j + 2] == 0
				else:
					var i: int = (sy * wa + sx) * 4
					same = da[i] == db[j] and da[i + 1] == db[j + 1] and da[i + 2] == db[j + 2] \
							and da[i + 3] == db[j + 3]
				if not same:
					n += 1
			if cap >= 0 and n > cap:
				break
		if best_n < 0 or n < best_n:
			second_n = best_n
			best_n = n
			best = d
		elif second_n < 0 or n < second_n:
			second_n = n
	return {"shift": best, "mismatch": best_n, "runner_up": second_n, "pixels": pixels}


## Passes iff `results` (name -> a `best_shift()` result) is non-empty and
## every entry has `shift == expected`, `mismatch == 0`, some pixels and an
## unambiguous best (`runner_up > 0`). Returns `{"pass": bool, "failures":
## Array[String]}`.
static func verdict(results: Dictionary, expected: Vector2i) -> Dictionary:
	var failures: Array[String] = []
	if results.is_empty():
		failures.append("nothing measured")
	for name: Variant in results:
		var m: Dictionary = results[name]
		if int(m["pixels"]) <= 0:
			failures.append("%s: no pixels in its region" % name)
		elif int(m["runner_up"]) <= 0:
			failures.append("%s: ambiguous shift" % name)
		if m["shift"] != expected:
			failures.append("%s: moved %s, expected %s" % [name, m["shift"], expected])
		if int(m["mismatch"]) != 0:
			failures.append("%s: %d pixels do not match any single shift" % [name, m["mismatch"]])
	return {"pass": failures.is_empty(), "failures": failures}


## The bounding box of `img`'s non-black pixels (any RGB channel non-zero;
## alpha ignored, so an L8 class mask works), or an empty rect.
static func content_rect(img: Image) -> Rect2i:
	var rgba: Image = _rgba8(img)
	var data: PackedByteArray = rgba.get_data()
	var w: int = rgba.get_width()
	var lo := Vector2i(w, rgba.get_height())
	var hi := Vector2i(-1, -1)
	for i: int in w * rgba.get_height():
		if data[i * 4] != 0 or data[i * 4 + 1] != 0 or data[i * 4 + 2] != 0:
			var p := Vector2i(i % w, i / w)
			lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
			hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


static func _rgba8(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img
	var c: Image = img.duplicate() as Image
	c.convert(Image.FORMAT_RGBA8)
	return c
