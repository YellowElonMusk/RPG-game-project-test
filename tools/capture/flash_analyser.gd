## The flash analyser (story 060; GDD sprite-camera-presentation AC-55b and
## Formulas `flash_gate`; test plan P-13; ADR-0005 §12). A frame-sequence
## analyser over the **final composited frames** (world and UI together),
## sampled at a fixed frame rate. It measures on screen what `FlashGate`
## guarantees by booking: no closed one-second window holds more than
## `flash_rate_max` flashes.
##
## Definitions (the GDD's, on linear R, G, B as WCAG 2.2 defines them):
##   general  a change in relative luminance of at least `luma_delta` whose
##            darker state is below 0.80;
##   red      a change of more than 20 in `(R - G - B) * 320` (clamped at 0)
##            where either state is saturated red (`R / (R + G + B) >= 0.8`);
##   area     a change counts only where it covers at least `area_min` of
##            some 10° window, `(4/9)·H × (1/3)·H` pixels, anywhere on screen.
##
## Per pixel, a swing is tracked from its running extreme, so a slow ramp of
## any length is **one** transition and a frame-to-frame jitter under the
## threshold is none. A pixel's transition stays "live" for
## `coincidence_frames` frames, so a large change whose pixels cross the
## threshold a frame or two apart is still judged as one area. A transition
## **event** (per kind and direction) is the frame on which its live area
## first reaches `area_min` in some window. A flash is an event that opposes
## the event before it of the same kind (the gate's conservative N − 1 rule).
## Flashes are counted per closed one-second window `[t, t + 1 s]`, general
## and red separately.
##
## Pure and headless: images in, numbers out, like `TexelGridCheck`. The
## windowed `flash_sequence_capture.gd` feeds it real frames.
##
## Usage example:
## [codeblock]
## var a := FlashAnalyser.new(60, cfg.flash_luma_delta, cfg.flash_area_min, cfg.flash_rate_max)
## for img: Image in grabs:
##     a.add_frame(FlashAnalyser.to_analysis(img, 90))
## if not a.passes():
##     print(a.summary())
## [/codeblock]
class_name FlashAnalyser
extends RefCounted

## Kind of a general (luminance) transition.
const GENERAL: StringName = &"general"
## Kind of a red transition.
const RED: StringName = &"red"
## A general transition's darker state must be below this (WCAG).
const GENERAL_DARKER_MAX: float = 0.80
## A pixel is saturated red when `R / (R + G + B)` (linear) is at least this.
const RED_SATURATION_MIN: float = 0.8
## A red transition changes `(R - G - B) * 320` by more than this.
const RED_CHANGE_MAX: float = 20.0
## Tolerance in the passing direction of every threshold.
const EPSILON: float = 1e-6

const _NONE: int = 0
const _UP: int = 1
const _DOWN: int = 2

var _fps: int
var _luma_delta: float
var _area_min: float
var _rate_max: float
var _coincidence: int

var _w: int = 0
var _h: int = 0
var _frames: int = 0
var _lut := PackedFloat32Array()
var _luma_series := PackedFloat32Array()
var _events: Array[Dictionary] = []

# Per pixel, per kind (0 general, 1 red): running extremes, last direction,
# frame of the last registered transition.
var _lo: Array[PackedFloat32Array] = []
var _hi: Array[PackedFloat32Array] = []
var _lo_sat: Array[PackedByteArray] = []
var _hi_sat: Array[PackedByteArray] = []
var _dir: Array[PackedByteArray] = []
var _at: Array[PackedInt32Array] = []
# Per kind and direction: whether the previous frame already counted.
var _counted: Array[bool] = [false, false, false, false]
# Per kind: the last event's direction (_NONE before any).
var _last_event_dir: Array[int] = [_NONE, _NONE]
var _flashes: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]


## `fps` is the capture rate; the thresholds are the GDD's
## (`flash_luma_delta`, `flash_area_min`, `flash_rate_max`).
func _init(fps: int = 60, luma_delta: float = 0.10, area_min: float = 0.25,
		rate_max: float = 3.0, coincidence_frames: int = 3) -> void:
	_fps = fps
	_luma_delta = luma_delta
	_area_min = area_min
	_rate_max = rate_max
	_coincidence = maxi(1, coincidence_frames)
	_lut.resize(256)
	for i: int in 256:
		var c: float = float(i) / 255.0
		_lut[i] = c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


## The 10° window, `(4/9)·H × (1/3)·H` pixels, for frame height `h`.
static func window_size(h: int) -> Vector2i:
	return Vector2i(maxi(1, roundi(4.0 * h / 9.0)), maxi(1, roundi(h / 3.0)))


## `img` box-filtered by halving (2 × 2 means) while its height is at least
## twice `target_h`, as RGB8: the analysis frame. Means are taken on the
## sRGB bytes; exact on flat areas, approximate on edges.
static func to_analysis(img: Image, target_h: int) -> Image:
	var out: Image = img.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8 and out.get_format() != Image.FORMAT_RGB8:
		out.convert(Image.FORMAT_RGBA8)
	while out.get_height() >= 2 * target_h and out.get_width() >= 2:
		out.shrink_x2()
	out.convert(Image.FORMAT_RGB8)
	return out


## Analyses the next frame (any size; every frame must be the same size).
func add_frame(img: Image) -> void:
	var frame: Image = img
	if frame.get_format() != Image.FORMAT_RGB8:
		frame = img.duplicate() as Image
		frame.convert(Image.FORMAT_RGB8)
	if _frames == 0:
		_allocate(frame.get_width(), frame.get_height())
	var data: PackedByteArray = frame.get_data()
	var n: int = _w * _h
	var f: int = _frames
	var luma_sum: float = 0.0
	var fresh: bool = false
	var g_lo: PackedFloat32Array = _lo[0]
	var g_hi: PackedFloat32Array = _hi[0]
	var g_dir: PackedByteArray = _dir[0]
	var g_at: PackedInt32Array = _at[0]
	var r_lo: PackedFloat32Array = _lo[1]
	var r_hi: PackedFloat32Array = _hi[1]
	var rl_sat: PackedByteArray = _lo_sat[1]
	var rh_sat: PackedByteArray = _hi_sat[1]
	var r_dir: PackedByteArray = _dir[1]
	var r_at: PackedInt32Array = _at[1]
	var delta: float = _luma_delta - EPSILON
	for i: int in n:
		var r: float = _lut[data[i * 3]]
		var g: float = _lut[data[i * 3 + 1]]
		var b: float = _lut[data[i * 3 + 2]]
		var y: float = 0.2126 * r + 0.7152 * g + 0.0722 * b
		luma_sum += y
		var total: float = r + g + b
		var sat: int = 1 if total > 0.0 and r / total >= RED_SATURATION_MIN - EPSILON else 0
		var rv: float = maxf(0.0, (r - g - b) * 320.0)
		if f == 0:
			g_lo[i] = y
			g_hi[i] = y
			r_lo[i] = rv
			r_hi[i] = rv
			rl_sat[i] = sat
			rh_sat[i] = sat
			continue
		# General.
		if y < g_lo[i]:
			g_lo[i] = y
		if y > g_hi[i]:
			g_hi[i] = y
		var d: int = g_dir[i]
		if d != _UP and y - g_lo[i] >= delta and g_lo[i] < GENERAL_DARKER_MAX:
			g_dir[i] = _UP
			g_at[i] = f
			g_lo[i] = y
			g_hi[i] = y
			fresh = true
		elif d != _DOWN and g_hi[i] - y >= delta and y < GENERAL_DARKER_MAX:
			g_dir[i] = _DOWN
			g_at[i] = f
			g_lo[i] = y
			g_hi[i] = y
			fresh = true
		# Red.
		if rv < r_lo[i]:
			r_lo[i] = rv
			rl_sat[i] = sat
		if rv > r_hi[i]:
			r_hi[i] = rv
			rh_sat[i] = sat
		d = r_dir[i]
		if d != _UP and rv - r_lo[i] > RED_CHANGE_MAX and (sat == 1 or rl_sat[i] == 1):
			r_dir[i] = _UP
			r_at[i] = f
			r_lo[i] = rv
			r_hi[i] = rv
			rl_sat[i] = sat
			rh_sat[i] = sat
			fresh = true
		elif d != _DOWN and r_hi[i] - rv > RED_CHANGE_MAX and (sat == 1 or rh_sat[i] == 1):
			r_dir[i] = _DOWN
			r_at[i] = f
			r_lo[i] = rv
			r_hi[i] = rv
			rl_sat[i] = sat
			rh_sat[i] = sat
			fresh = true
	_lo[0] = g_lo
	_hi[0] = g_hi
	_dir[0] = g_dir
	_at[0] = g_at
	_lo[1] = r_lo
	_hi[1] = r_hi
	_lo_sat[1] = rl_sat
	_hi_sat[1] = rh_sat
	_dir[1] = r_dir
	_at[1] = r_at
	_luma_series.append(luma_sum / float(n))
	if f > 0:
		_judge_area(f, fresh)
	_frames += 1


## Frames analysed so far.
func frame_count() -> int:
	return _frames


## Every transition event, in order: `{frame, kind, rising, coverage}`
## (coverage: the largest live share of one 10° window on that frame).
func events() -> Array[Dictionary]:
	return _events


## Frames on which a flash of `kind` (`GENERAL` or `RED`) landed.
func flash_frames(kind: StringName) -> PackedInt32Array:
	return _flashes[_kind_index(kind)]


## The most flashes of `kind` in any closed one-second window.
func max_flashes_in_window(kind: StringName) -> int:
	return int(worst_window(kind)["count"])


## The closed one-second window holding the most flashes of `kind`:
## `{start_frame, count}` (start -1 when there are none).
func worst_window(kind: StringName) -> Dictionary:
	var fl: PackedInt32Array = flash_frames(kind)
	var best: int = 0
	var start: int = -1
	for i: int in fl.size():
		var n: int = 0
		for j: int in range(i, fl.size()):
			if fl[j] - fl[i] <= _fps:
				n += 1
		if n > best:
			best = n
			start = fl[i]
	return {"start_frame": start, "count": best}


## True when no closed one-second window holds more than `rate_max`
## general flashes, nor more than `rate_max` red flashes.
func passes() -> bool:
	return max_flashes_in_window(GENERAL) <= _rate_max + EPSILON \
			and max_flashes_in_window(RED) <= _rate_max + EPSILON


## Every flash frame (either kind, ascending) outside all `spans`
## (inclusive frame ranges `Vector2i(first, last)`).
func flashes_outside(spans: Array[Vector2i]) -> PackedInt32Array:
	var all: Array[int] = []
	for k: int in 2:
		for fr: int in _flashes[k]:
			all.append(fr)
	all.sort()
	var out := PackedInt32Array()
	for fr: int in all:
		var inside := false
		for s: Vector2i in spans:
			if fr >= s.x and fr <= s.y:
				inside = true
				break
		if not inside:
			out.append(fr)
	return out


## Mean relative luminance of each frame, in order.
func luma_series() -> PackedFloat32Array:
	return _luma_series


## A JSON-ready summary of the run.
func summary() -> Dictionary:
	var ev: Array = []
	for e: Dictionary in _events:
		ev.append({"frame": e["frame"], "t_s": float(e["frame"]) / _fps, "kind": String(e["kind"]),
				"rising": e["rising"], "coverage": snappedf(float(e["coverage"]), 0.001)})
	return {
		"frames": _frames, "fps": _fps, "analysis_size": [_w, _h],
		"window_px": [window_size(_h).x, window_size(_h).y],
		"luma_delta": _luma_delta, "area_min": _area_min, "rate_max": _rate_max,
		"coincidence_frames": _coincidence,
		"events": ev,
		"general_flash_frames": Array(flash_frames(GENERAL)),
		"red_flash_frames": Array(flash_frames(RED)),
		"general_worst_window": worst_window(GENERAL),
		"red_worst_window": worst_window(RED),
		"mean_luma_min": _min_of(_luma_series), "mean_luma_max": _max_of(_luma_series),
		"pass": passes(),
	}


## A plot of the mean luminance per frame (white line), each event (a tick:
## up green, down orange, red kind magenta) and each flash (a full-height
## red bar), with a grid line every second. For eyes, not for judging.
static func plot(series: PackedFloat32Array, ev: Array[Dictionary], flashes: PackedInt32Array,
		fps: int, height: int = 200) -> Image:
	var w: int = maxi(1, series.size())
	var img := Image.create(w, height, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.08, 0.1))
	for x: int in range(0, w, fps):
		for y: int in height:
			img.set_pixel(x, y, Color(0.25, 0.25, 0.3))
	for y_frac: float in [0.1, 0.8]:
		var yy: int = clampi(height - 1 - int(y_frac * (height - 1)), 0, height - 1)
		for x: int in w:
			img.set_pixel(x, yy, Color(0.3, 0.3, 0.45))
	for fr: int in flashes:
		if fr < w:
			for y: int in height:
				img.set_pixel(fr, y, Color(0.9, 0.1, 0.1))
	for e: Dictionary in ev:
		var x: int = int(e["frame"])
		if x >= w:
			continue
		var c: Color = Color(1, 0, 1) if e["kind"] == RED else (Color(0.2, 0.9, 0.3) if e["rising"] else Color(1.0, 0.6, 0.1))
		for y: int in range(0, 12):
			img.set_pixel(x, y, c)
	for x: int in w:
		var yv: int = clampi(height - 1 - int(series[x] * (height - 1)), 0, height - 1)
		img.set_pixel(x, yv, Color.WHITE)
	return img


# --- internals ---------------------------------------------------------------

func _allocate(w: int, h: int) -> void:
	_w = w
	_h = h
	var n: int = w * h
	for k: int in 2:
		var lo := PackedFloat32Array()
		lo.resize(n)
		var hi := PackedFloat32Array()
		hi.resize(n)
		var ls := PackedByteArray()
		ls.resize(n)
		var hs := PackedByteArray()
		hs.resize(n)
		var dr := PackedByteArray()
		dr.resize(n)
		var at := PackedInt32Array()
		at.resize(n)
		at.fill(-1_000_000)
		_lo.append(lo)
		_hi.append(hi)
		_lo_sat.append(ls)
		_hi_sat.append(hs)
		_dir.append(dr)
		_at.append(at)


## Records an event for each kind and direction whose live area first
## reaches `area_min` of some window on frame `f`.
func _judge_area(f: int, fresh: bool) -> void:
	var win: Vector2i = window_size(_h)
	var need: float = _area_min * float(win.x * win.y) - EPSILON
	for k: int in 2:
		for d: int in [_UP, _DOWN]:
			var slot: int = k * 2 + (d - 1)
			var cov: float = 0.0
			if fresh or _counted[slot]:
				cov = _coverage(k, d, f, win, need)
			var counts: bool = cov * float(win.x * win.y) >= need
			if counts and not _counted[slot]:
				_record(f, k, d, cov)
			_counted[slot] = counts


func _record(f: int, k: int, d: int, cov: float) -> void:
	_events.append({"frame": f, "kind": GENERAL if k == 0 else RED, "rising": d == _UP, "coverage": cov})
	if _last_event_dir[k] != _NONE and _last_event_dir[k] != d:
		_flashes[k].append(f)
	_last_event_dir[k] = d


## Largest share of one window covered by live pixels of kind `k` whose last
## transition went `d`; 0 when the total is under `need`.
func _coverage(k: int, d: int, f: int, win: Vector2i, need: float) -> float:
	var dirs: PackedByteArray = _dir[k]
	var at: PackedInt32Array = _at[k]
	var stride: int = _w + 1
	var sat := PackedInt32Array()
	sat.resize(stride * (_h + 1))
	var total: int = 0
	for y: int in _h:
		var row: int = 0
		for x: int in _w:
			var i: int = y * _w + x
			if dirs[i] == d and f - at[i] < _coincidence:
				row += 1
				total += 1
			sat[(y + 1) * stride + x + 1] = sat[y * stride + x + 1] + row
	if float(total) < need:
		return 0.0
	var best: int = 0
	for y: int in range(0, _h - win.y + 1):
		for x: int in range(0, _w - win.x + 1):
			var s: int = sat[(y + win.y) * stride + x + win.x] - sat[y * stride + x + win.x] \
					- sat[(y + win.y) * stride + x] + sat[y * stride + x]
			if s > best:
				best = s
	return float(best) / float(win.x * win.y)


static func _kind_index(kind: StringName) -> int:
	return 1 if kind == RED else 0


static func _min_of(a: PackedFloat32Array) -> float:
	var m: float = INF
	for v: float in a:
		m = minf(m, v)
	return 0.0 if a.is_empty() else m


static func _max_of(a: PackedFloat32Array) -> float:
	var m: float = -INF
	for v: float in a:
		m = maxf(m, v)
	return 0.0 if a.is_empty() else m
