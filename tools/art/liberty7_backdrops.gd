extends SceneTree
## Paints Liberty-7's PLACEHOLDER battle backdrops (Chapter 4, New York):
## `assets/backgrounds/bg_battle_liberty7.png` (an avenue by parade noon)
## and `bg_battle_liberty7_boss.png` (the same skyline at night under
## fireworks, with a giant star in the sky). Drawn at 320x180 and scaled 2x
## nearest, so it reads as pixels next to the authored backdrops.
## TODO(art): authored backdrops replace these (production/asset-requests/art.md).
##
##   godot --headless --path . -s res://tools/art/liberty7_backdrops.gd

const W: int = 320
const H: int = 180
const ANTHEM := Color("#2F5BEA")
const INK := Color("#1A1418")
const CREAM := Color("#F4EAD2")


func _initialize() -> void:
	_paint(false).save_png(ProjectSettings.globalize_path("res://assets/backgrounds/bg_battle_liberty7.png"))
	_paint(true).save_png(ProjectSettings.globalize_path("res://assets/backgrounds/bg_battle_liberty7_boss.png"))
	print("liberty7 backdrops written")
	quit()


func _paint(boss: bool) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var sky_top := Color("#0E1430") if boss else Color("#4E8FE0")
	var sky_low := Color("#3A2E6A") if boss else Color("#CFE4F6")
	var horizon: int = 118
	for y: int in H:
		for x: int in W:
			var c: Color
			if y < horizon:
				var t: float = float(y) / float(horizon)
				var band: float = floor(t * 8.0 + (0.5 if (x + y) % 2 == 0 else 0.0)) / 8.0
				c = sky_top.lerp(sky_low, band)
			else:
				# The avenue: asphalt with a yellow lane dash, kerbs near the bottom.
				var road := Color("#3C3C44") if boss else Color("#6A6A72")
				c = road.darkened(0.04 if ((x / 2 + y) % 9 == 0) else 0.0)
				if y > 146 and y < 149 and (x / 12) % 2 == 0:
					c = Color("#E8C23A")
				if y >= 172:
					c = Color("#8A8A90") if not boss else Color("#4A4A52")
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if boss else 5
	# Skyline: towers of varied height with lit or dark windows.
	var x0: int = 0
	while x0 < W:
		var w: int = rng.randi_range(14, 30)
		var h: int = rng.randi_range(36, 96)
		var body := Color("#1C2236") if boss else Color("#7C8698").darkened(rng.randf_range(0.0, 0.25))
		_rect(img, Rect2i(x0, horizon - h, w - 2, h), body)
		for wy: int in range(horizon - h + 4, horizon - 4, 6):
			for wx: int in range(x0 + 3, x0 + w - 5, 5):
				var lit: bool = rng.randf() < (0.45 if boss else 0.15)
				_rect(img, Rect2i(wx, wy, 2, 3), Color("#F6D27A") if lit else body.darkened(0.3))
		x0 += w
	# A giant Anthem Blue star (the boss's light show) or a plain sun.
	if boss:
		_star(img, Vector2(160, 46), 30, ANTHEM.lightened(0.2))
		_star(img, Vector2(160, 46), 22, CREAM)
		for i: int in 7:
			_burst(img, Vector2(rng.randi_range(20, W - 20), rng.randi_range(12, 60)),
					rng.randi_range(6, 12), [ANTHEM.lightened(0.3), Color("#E84A4A"), CREAM][i % 3])
	else:
		_disc(img, Vector2(270, 26), 12, Color("#FFF2B8"))
	# Star bunting strung across the avenue.
	for x: int in W:
		var y: int = 70 + int(8.0 * sin(float(x) / float(W) * PI * 3.0))
		img.set_pixel(x, y, INK)
		if x % 10 == 5:
			_tri(img, Vector2i(x, y + 1), ANTHEM if (x / 10) % 2 == 0 else CREAM)
	img.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
	return img


func _star(img: Image, c: Vector2, r: int, col: Color) -> void:
	for y: int in range(int(c.y) - r, int(c.y) + r + 1):
		for x: int in range(int(c.x) - r, int(c.x) + r + 1):
			var d := Vector2(x, y) - c
			var a: float = atan2(d.y, d.x) + PI / 2.0
			var edge: float = r * (0.55 + 0.45 * cos(5.0 * a))
			if x >= 0 and y >= 0 and x < W and y < H and d.length() <= edge:
				img.set_pixel(x, y, col)


func _burst(img: Image, c: Vector2, r: int, col: Color) -> void:
	for i: int in 12:
		var dir := Vector2.RIGHT.rotated(i * TAU / 12.0)
		for s: int in range(r / 2, r):
			var q: Vector2 = c + dir * s
			if q.x >= 0 and q.x < W and q.y >= 0 and q.y < H:
				img.set_pixelv(Vector2i(q), col)


func _tri(img: Image, top: Vector2i, col: Color) -> void:
	for dy: int in 5:
		for dx: int in range(-2 + dy / 2, 3 - dy / 2):
			var p := top + Vector2i(dx, dy)
			if p.x >= 0 and p.x < W and p.y >= 0 and p.y < H:
				img.set_pixelv(p, col)


func _disc(img: Image, c: Vector2, r: int, col: Color) -> void:
	for y: int in range(int(c.y) - r, int(c.y) + r + 1):
		for x: int in range(int(c.x) - r, int(c.x) + r + 1):
			if x >= 0 and y >= 0 and x < W and y < H and Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


func _rect(img: Image, r: Rect2i, col: Color) -> void:
	var clipped := r.intersection(Rect2i(0, 0, W, H))
	if clipped.size.x > 0 and clipped.size.y > 0:
		img.fill_rect(clipped, col)
