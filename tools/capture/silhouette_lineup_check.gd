## The measurement behind story 037 (GDD sprite-camera-presentation AC-33,
## Visual and Animation Requirements "Silhouette test"; art bible Principle 1;
## ADR-0005 §1): every character's black-fill silhouette, in the facing its
## battle role shows, at battle height and as a 32 px thumbnail, and the GDD's
## lineup test run as a machine proxy.
##
## The GDD's test is human: "at least 2 of 3 reviewers, shown only the fill,
## pick the character from a lineup of 6". That verdict is the art director's
## (AC-33 is [VF]). The proxy here keeps the GDD's numbers and replaces each
## reviewer with one probe pose of the character (story 037's "identifiable
## by outline alone from at least 2 of 3 reference ... poses"): the probe is
## compared with a lineup of 6 reference silhouettes (the character's own and
## the 5 others closest to the probe, the hardest lineup the roster allows),
## and it "picks" the one it overlaps most (IoU, feet-aligned). A tie with
## another character is a wrong pick. The proxy invents no threshold; it
## flags a silhouette a reviewer would likely confuse, it does not sign off.
##
## Pure and headless (images in, numbers out), like `TexelGridCheck`;
## `silhouette_sheet_capture.gd` feeds it every shipped sprite set and writes
## the sheet.
class_name SilhouetteLineupCheck
extends RefCounted

## GDD "Silhouette test": the thumbnail size, in pixels (longest side).
const THUMB_PX: int = 32
## GDD "Silhouette test": the lineup a reviewer picks from.
const LINEUP_SIZE: int = 6
## GDD "Silhouette test": reviewers per character (here, probe poses).
const REVIEWERS: int = 3
## GDD "Silhouette test": correct picks needed to pass.
const PASS_VOTES: int = 2
## The window height "battle height" is taken at: the capture tool's
## reference 1920x1080 (GDD AC-32), where `T` = 3 with the shipped config.
const SHEET_LINES: int = 1080
## A frame texel is opaque when its 8-bit alpha is above this (the actor
## shader's alpha cut at 0.5; same value as `TexelGridCheck.ALPHA_CUT_8`).
const ALPHA_CUT_8: int = 127
## Squad poses (AC-33: `back` facing, idle and `victory`).
const SQUAD_POSES: Array[StringName] = [&"idle", &"victory"]
## Enemy poses (AC-33: `front` facing). AC-33 names no enemy pose; idle and
## the attack wind-up (the art bible's reaction frame) are shown.
const ENEMY_POSES: Array[StringName] = [&"idle", &"attack"]


## The black-fill silhouette of `frame`: an L8 mask, 255 where the texel's
## alpha passes the cut, 0 elsewhere. Colour is ignored.
static func mask(frame: Image) -> Image:
	var src: Image = frame.duplicate()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var sd: PackedByteArray = src.get_data()
	var out := PackedByteArray()
	out.resize(w * h)
	for i: int in w * h:
		out[i] = 255 if sd[i * 4 + 3] > ALPHA_CUT_8 else 0
	return Image.create_from_data(w, h, false, Image.FORMAT_L8, out)


## The tight box of `m`'s marked pixels; `Rect2i()` when none is marked.
static func opaque_bounds(m: Image) -> Rect2i:
	var w: int = m.get_width()
	var h: int = m.get_height()
	var d: PackedByteArray = _l8(m).get_data()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y: int in h:
		for x: int in w:
			if d[y * w + x] > 127:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## `m` at battle height: every texel a `t x t` block (GDD `texel_scale`;
## story 039 measured that the screen draws exactly this).
static func scaled(m: Image, t: int) -> Image:
	var out: Image = _l8(m).duplicate()
	var k: int = maxi(1, t)
	out.resize(m.get_width() * k, m.get_height() * k, Image.INTERPOLATE_NEAREST)
	return out


## `m` as a `px` thumbnail: its opaque bounds fitted so the longest side is
## `px` (aspect kept), each thumbnail pixel marked when at least half of the
## source area it covers is marked. A blank mask gives one empty pixel.
static func thumbnail(m: Image, px: int = THUMB_PX) -> Image:
	var b: Rect2i = opaque_bounds(m)
	if b.size.x <= 0:
		return Image.create(1, 1, false, Image.FORMAT_L8)
	var s: float = float(px) / float(maxi(b.size.x, b.size.y))
	var tw: int = maxi(1, roundi(b.size.x * s))
	var th: int = maxi(1, roundi(b.size.y * s))
	var src: PackedByteArray = _l8(m).get_data()
	var sw: int = m.get_width()
	var out := PackedByteArray()
	out.resize(tw * th)
	for ty: int in th:
		var y0: float = b.position.y + float(ty) * b.size.y / th
		var y1: float = b.position.y + float(ty + 1) * b.size.y / th
		for tx: int in tw:
			var x0: float = b.position.x + float(tx) * b.size.x / tw
			var x1: float = b.position.x + float(tx + 1) * b.size.x / tw
			var covered: float = 0.0
			for sy: int in range(floori(y0), ceili(y1)):
				var hy: float = minf(y1, sy + 1.0) - maxf(y0, float(sy))
				if hy <= 0.0:
					continue
				for sx: int in range(floori(x0), ceili(x1)):
					var hx: float = minf(x1, sx + 1.0) - maxf(x0, float(sx))
					if hx > 0.0 and src[sy * sw + sx] > 127:
						covered += hx * hy
			out[ty * tw + tx] = 255 if covered >= 0.5 * (x1 - x0) * (y1 - y0) - 0.000001 else 0
	return Image.create_from_data(tw, th, false, Image.FORMAT_L8, out)


## Intersection over union of two silhouettes placed feet-aligned: each
## mask's opaque bounds bottom-centred on the same point, as two characters
## standing on one floor. 0.0 when either is blank.
static func overlap(a: Image, b: Image) -> float:
	var ra: Rect2i = opaque_bounds(a)
	var rb: Rect2i = opaque_bounds(b)
	if ra.size.x <= 0 or rb.size.x <= 0:
		return 0.0
	var cw: int = maxi(ra.size.x, rb.size.x)
	var ch: int = maxi(ra.size.y, rb.size.y)
	var canvas := PackedByteArray()
	canvas.resize(cw * ch)
	var n_a: int = _stamp(canvas, cw, ch, a, ra, 1)
	var n_b: int = _stamp(canvas, cw, ch, b, rb, 2)
	var both: int = 0
	for v: int in canvas:
		if v == 3:
			both += 1
	var union: int = n_a + n_b - both
	return float(both) / float(union) if union > 0 else 0.0


## One lineup (GDD: a reviewer shown only the fill picks from 6). `gallery`
## maps character id -> reference mask; the lineup is `self_id` plus the
## `size - 1` others whose reference overlaps `probe` most (ties by id).
## Returns `{"lineup": Array[StringName], "picked": id, "correct": bool,
## "scores": {id: IoU}, "self_score": f, "best_other": id, "best_other_score": f}`.
## A tie between `self_id` and another character is not correct.
static func lineup(probe: Image, gallery: Dictionary, self_id: StringName,
		size: int = LINEUP_SIZE) -> Dictionary:
	var scores: Dictionary = {}
	var others: Array = []
	for id: Variant in gallery:
		scores[id] = overlap(probe, gallery[id])
		if StringName(id) != self_id:
			others.append(StringName(id))
	others.sort_custom(func(x: StringName, y: StringName) -> bool:
		var sx: float = scores[x]
		var sy: float = scores[y]
		return sx > sy if sx != sy else String(x) < String(y))
	var chosen: Array[StringName] = []
	if gallery.has(self_id):
		chosen.append(self_id)
	for id: StringName in others:
		if chosen.size() >= size:
			break
		chosen.append(id)
	var self_score: float = float(scores.get(self_id, 0.0))
	var best_other: StringName = &""
	var best_other_score: float = -1.0
	for id: StringName in chosen:
		if id != self_id and float(scores[id]) > best_other_score:
			best_other = id
			best_other_score = scores[id]
	var correct: bool = gallery.has(self_id) and self_score > best_other_score
	var picked: StringName = self_id if correct else best_other
	return {"lineup": chosen, "picked": picked, "correct": correct, "scores": scores,
			"self_score": self_score, "best_other": best_other,
			"best_other_score": maxf(best_other_score, 0.0)}


## The proxy verdict for one character: each of its `REVIEWERS` probes runs
## one `lineup()`; it passes with at least `PASS_VOTES` correct picks (and
## fails outright with fewer than `REVIEWERS` probes).
## Returns `{"votes": n, "pass": bool, "picks": Array[Dictionary]}`.
static func character_verdict(probes: Array[Image], gallery: Dictionary,
		self_id: StringName) -> Dictionary:
	var votes: int = 0
	var picks: Array[Dictionary] = []
	for p: Image in probes:
		var r: Dictionary = lineup(p, gallery, self_id)
		picks.append(r)
		if r["correct"]:
			votes += 1
	return {"votes": votes, "pass": probes.size() >= REVIEWERS and votes >= PASS_VOTES, "picks": picks}


## Every character must pass; an empty roster fails.
## `per` maps id -> a `character_verdict()` (only `pass` is read).
static func roster_verdict(per: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	for id: Variant in per:
		if not bool((per[id] as Dictionary).get("pass", false)):
			failures.append(String(id))
	if per.is_empty():
		failures.append("no characters")
	return {"pass": failures.is_empty(), "failures": failures}


## The frames AC-33 shows for `s`, from its `SpriteFrames`
## (`build_sprite_frames()`, the art as played): a squad set in `back`
## facing, idle and `victory`; any other set in `front`, idle and attack.
## A pose authored only in the other facing is shown mirrored (the shader
## flip's effect: the frame flipped horizontally); a `no_mirror` pose is
## never flipped (ADR-0005 §1, rule 3): it is reported missing.
## Returns `{"facing", "poses": Array[StringName], "frames": {pose: Array[Image]},
## "mirrored": {pose: bool}, "missing": PackedStringArray}`.
static func pose_frames(s: SpriteSetData) -> Dictionary:
	var facing: StringName = SpriteSetData.VICTORY_FACING if s.is_squad else SpriteSetData.INTRO_FACING
	var poses: Array[StringName] = SQUAD_POSES if s.is_squad else ENEMY_POSES
	var sf: SpriteFrames = s.build_sprite_frames()
	var frames: Dictionary = {}
	var mirrored: Dictionary = {}
	var missing := PackedStringArray()
	for pose: StringName in poses:
		# Rule 10's runtime path; a fallback or placeholder is not this pose's art.
		var r: SpriteSetData.Resolution = s.resolve(pose, facing, "", func(_m: String) -> void: pass)
		if r.fell_back or r.placeholder or r.animation == null:
			missing.append("%s %s (%s)" % [s.set_id, pose, facing])
			continue
		var clip: StringName = SpriteSetData.clip_name(r.animation.animation_id, r.animation.facing)
		if not sf.has_animation(clip) or sf.get_frame_count(clip) == 0:
			missing.append("%s %s (%s): no art" % [s.set_id, pose, facing])
			continue
		var imgs: Array[Image] = []
		for i: int in sf.get_frame_count(clip):
			var img: Image = sf.get_frame_texture(clip, i).get_image()
			img.convert(Image.FORMAT_RGBA8)
			if r.mirrored:
				img.flip_x()
			imgs.append(img)
		frames[pose] = imgs
		mirrored[pose] = r.mirrored
	return {"facing": facing, "poses": poses, "frames": frames, "mirrored": mirrored, "missing": missing}


## The three probe frames of a `pose_frames()` result (the proxy's three
## "reviewers"): the first pose's last frame, and the second pose's first
## and middle frames. Fewer when a pose is missing.
static func probe_frames(p: Dictionary) -> Array[Image]:
	var out: Array[Image] = []
	var poses: Array = p["poses"]
	var frames: Dictionary = p["frames"]
	if poses.size() < 2:
		return out
	if frames.has(poses[0]):
		var first: Array = frames[poses[0]]
		out.append(first[first.size() - 1])
	if frames.has(poses[1]):
		var second: Array = frames[poses[1]]
		out.append(second[0])
		out.append(second[second.size() / 2])
	return out


## The lineup's reference silhouette: the first pose's (idle) first frame;
## null when it is missing.
static func reference_frame(p: Dictionary) -> Image:
	var poses: Array = p["poses"]
	var frames: Dictionary = p["frames"]
	if poses.is_empty() or not frames.has(poses[0]):
		return null
	return (frames[poses[0]] as Array)[0]


## One sheet row: each mask drawn black on white, left to right, `gap` px
## apart and around, bottoms on one floor line.
static func compose_row(masks: Array, gap: int) -> Image:
	var w: int = gap
	var h: int = 0
	for m: Image in masks:
		w += m.get_width() + gap
		h = maxi(h, m.get_height())
	var out := Image.create(maxi(1, w), h + 2 * gap, false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	var x: int = gap
	for m: Image in masks:
		var d: PackedByteArray = _l8(m).get_data()
		var mw: int = m.get_width()
		var mh: int = m.get_height()
		var top: int = gap + h - mh
		for y: int in mh:
			for xx: int in mw:
				if d[y * mw + xx] > 127:
					out.set_pixel(x + xx, top + y, Color.BLACK)
		x += mw + gap
	return out


## Rows stacked top to bottom, left-aligned, on white.
static func stack_rows(rows: Array) -> Image:
	var w: int = 1
	var h: int = 0
	for r: Image in rows:
		w = maxi(w, r.get_width())
		h += r.get_height()
	var out := Image.create(w, maxi(1, h), false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	var y: int = 0
	for r: Image in rows:
		var rr: Image = r.duplicate()
		rr.convert(Image.FORMAT_RGBA8)
		out.blit_rect(rr, Rect2i(Vector2i.ZERO, rr.get_size()), Vector2i(0, y))
		y += rr.get_height()
	return out


## Marks `m`'s pixels into `canvas` (`cw` x `ch`) with `bit`, its bounds `r`
## bottom-centred; returns how many it marked.
static func _stamp(canvas: PackedByteArray, cw: int, ch: int, m: Image, r: Rect2i, bit: int) -> int:
	var d: PackedByteArray = _l8(m).get_data()
	var mw: int = m.get_width()
	var ox: int = (cw - r.size.x) / 2 - r.position.x
	var oy: int = ch - r.size.y - r.position.y
	var n: int = 0
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if d[y * mw + x] > 127:
				canvas[(y + oy) * cw + x + ox] |= bit
				n += 1
	return n


static func _l8(m: Image) -> Image:
	if m.get_format() == Image.FORMAT_L8:
		return m
	var c: Image = m.duplicate()
	c.convert(Image.FORMAT_L8)
	return c
