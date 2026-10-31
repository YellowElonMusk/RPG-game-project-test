class_name CardOcclusionCheck
extends RefCounted
## Story 073's [C] measurement (GDD AC-68 [C], P-09; ADR-0005 §2, §13): the
## pure judgement of an upright-card occlusion fixture from three ID passes
## of one frozen frame. Headless-testable; `card_occlusion_capture.gd` takes
## the passes.
##
##   alone    the sprite with the fixture hidden (the set as shipped);
##   fixture  the sprite with the fixture wall and prop shown;
##   behind   the fixture with the sprite hidden (where the wall and the
##            prop are on screen).
##
## The wall and the prop draw in their own flat ID colours (`WALL_COLOR`,
## `PROP_COLOR`, both unused by `PresentationCapture.palette()`), so they are
## told apart from the floor and the rest of the set.

## The fixture wall's ID colour (not in `PresentationCapture.palette()`).
const WALL_COLOR := Color8(255, 0, 0)
## The fixture prop's ID colour (not in `PresentationCapture.palette()`).
const PROP_COLOR := Color8(255, 128, 0)
## The bottom band judged against the prop, in texels (AC-68 [C]).
const BAND_TEXELS: int = 2


## Judges one fixture. Returns `{"pass": bool, "failures": Array[String],
## "upper": n, "upper_wall_behind": n, "upper_missing": n, "band": n,
## "band_behind_prop": n, "band_present": n}`.
static func verdict(alone: Image, fixture: Image, behind: Image, rect: Rect2i, t: int) -> Dictionary:
	var actor: Color = PresentationCapture.palette()[PresentationCapture.CLASS_ACTOR]
	var a: Image = PresentationCapture._rgba8(alone)
	var f: Image = PresentationCapture._rgba8(fixture)
	var b: Image = PresentationCapture._rgba8(behind)
	var frame := Rect2i(Vector2i.ZERO, Vector2i(a.get_width(), a.get_height()))
	var area: Rect2i = rect.intersection(frame)
	var upper_end: int = rect.position.y + rect.size.y / 2
	var band_start: int = rect.end.y - BAND_TEXELS * t
	var r: Dictionary = {"upper": 0, "upper_wall_behind": 0, "upper_missing": 0,
			"band": 0, "band_behind_prop": 0, "band_present": 0}
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if not matches(a.get_pixel(x, y), actor):
				continue
			var shown: bool = matches(f.get_pixel(x, y), actor)
			if y < upper_end:
				r["upper"] += 1
				if matches(b.get_pixel(x, y), WALL_COLOR):
					r["upper_wall_behind"] += 1
				if not shown:
					r["upper_missing"] += 1
			elif y >= band_start:
				r["band"] += 1
				if matches(b.get_pixel(x, y), PROP_COLOR):
					r["band_behind_prop"] += 1
					if shown:
						r["band_present"] += 1
	var failures: Array[String] = []
	if int(r["upper"]) == 0 or int(r["band"]) == 0:
		failures.append("vacuous: no sprite pixels in the upper half or the bottom band")
	if int(r["upper_wall_behind"]) < int(r["upper"]):
		failures.append("invalid fixture: the wall is not behind every upper-half pixel (%d of %d)" \
				% [r["upper_wall_behind"], r["upper"]])
	if int(r["band_behind_prop"]) < int(r["band"]):
		failures.append("invalid fixture: the prop does not cover the bottom %d texels (%d of %d)" \
				% [BAND_TEXELS, r["band_behind_prop"], r["band"]])
	if int(r["upper_missing"]) > 0:
		failures.append("wall cuts the upper half: %d pixels missing" % r["upper_missing"])
	if int(r["band_present"]) > 0:
		failures.append("feet drawn over the prop: %d band pixels present" % r["band_present"])
	r["failures"] = failures
	r["pass"] = failures.is_empty()
	return r


## Whether `c` is `want` within the ID palette's read-back tolerance.
static func matches(c: Color, want: Color) -> bool:
	return absi(c.r8 - want.r8) <= 24 and absi(c.g8 - want.g8) <= 24 and absi(c.b8 - want.b8) <= 24
