extends SceneTree
## Paints Influencia's PLACEHOLDER battle backdrops (Chapter 3, Sydney):
## `assets/backgrounds/bg_battle_influencia.png` (harbour by day) and
## `bg_battle_influencia_boss.png` (the same harbour at a magenta sunset with
## a giant ring light in the sky). Drawn at 320x180 and scaled 2x nearest, so
## it reads as pixels next to the authored MegaCorp/Bureaucratia backdrops.
## TODO(art): authored backdrops replace these (production/asset-requests/art.md).
##
##   godot --headless --path . -s res://tools/art/influencia_backdrops.gd

const W: int = 320
const H: int = 180
const MAGENTA := Color("#E83E9C")
const INK := Color("#1A1418")


func _initialize() -> void:
	_paint(false).save_png(ProjectSettings.globalize_path("res://assets/backgrounds/bg_battle_influencia.png"))
	_paint(true).save_png(ProjectSettings.globalize_path("res://assets/backgrounds/bg_battle_influencia_boss.png"))
	print("influencia backdrops written")
	quit()


func _paint(boss: bool) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var sky_top := Color("#3B1A4A") if boss else Color("#5FB4E6")
	var sky_low := Color("#F08A9C") if boss else Color("#BFE6F2")
	var horizon: int = 104
	for y: int in H:
		for x: int in W:
			var c: Color
			if y < horizon:
				# Banded sky (pixel dithering between bands).
				var t: float = float(y) / float(horizon)
				var band: float = floor(t * 8.0 + (0.5 if (x + y) % 2 == 0 else 0.0)) / 8.0
				c = sky_top.lerp(sky_low, band)
			elif y < 132:
				var sea := Color("#7A2E6A") if boss else Color("#1F7FA8")
				var wave: bool = (x + (y * 7)) % 23 < 2
				c = sea.lightened(0.25) if wave else sea.darkened(float(y - horizon) * 0.01)
			else:
				var sand := Color("#C98E6A") if boss else Color("#E8CF9A")
				c = sand.darkened(0.06 if ((x / 3 + y / 2) % 7 == 0) else 0.0)
			img.set_pixel(x, y, c)
	# Sun or the giant boss ring light.
	if boss:
		_ring(img, Vector2(160, 52), 34, 27, Color("#FFF4EC"))
		_ring(img, Vector2(160, 52), 27, 24, MAGENTA)
	else:
		_disc(img, Vector2(258, 30), 14, Color("#FFF2B8"))
	# Harbour bridge: a dark arch and deck across the horizon.
	var steel := Color("#2A2236") if boss else Color("#3A4A5A")
	for x: int in range(30, 210):
		var t: float = float(x - 30) / 180.0
		var arch_y: int = horizon - 6 - int(26.0 * sin(t * PI))
		for y: int in range(arch_y, arch_y + 3):
			img.set_pixel(x, y, steel)
		img.set_pixel(x, horizon - 6, steel)
		img.set_pixel(x, horizon - 5, steel)
		if x % 10 == 0:
			for y: int in range(arch_y, horizon - 5):
				img.set_pixel(x, y, steel)
	for px: int in [26, 32, 206, 212]:
		_rect(img, Rect2i(px, horizon - 22, 6, 18), steel.lightened(0.15))
	# Floating notification bubbles: Feed Magenta circles with a white dot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if boss else 3
	for i: int in 9:
		var p := Vector2(rng.randi_range(12, W - 12), rng.randi_range(10, horizon - 30))
		var r: int = rng.randi_range(4, 8)
		_disc(img, p, r + 1, INK)
		_disc(img, p, r, MAGENTA)
		_disc(img, p + Vector2(r * 0.35, -r * 0.35), max(1, r / 3), Color.WHITE)
	# Billboards on the shore: magenta frames around a circle logo.
	for bx: int in [236, 280]:
		_rect(img, Rect2i(bx, 70, 34, 26), INK)
		_rect(img, Rect2i(bx + 1, 71, 32, 24), MAGENTA.darkened(0.2) if boss else Color("#F7B6D8"))
		_disc(img, Vector2(bx + 17, 83), 7, MAGENTA)
		_rect(img, Rect2i(bx + 15, 96, 4, 8), INK)
	# Palm silhouettes in the foreground corners.
	for base: Vector2i in [Vector2i(14, 178), Vector2i(304, 178)]:
		for y: int in range(120, 178):
			img.set_pixel(base.x + int((178 - y) * 0.12), y, INK)
			img.set_pixel(base.x + 1 + int((178 - y) * 0.12), y, INK)
		var top := Vector2(base.x + 7, 120)
		for a: int in 7:
			var dir := Vector2.RIGHT.rotated(PI + a * PI / 6.0)
			for s: int in 18:
				var q: Vector2 = top + dir * s + Vector2(0, s * s * 0.03)
				if q.x >= 0 and q.x < W and q.y >= 0 and q.y < H:
					img.set_pixelv(Vector2i(q), INK)
	img.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
	return img


func _disc(img: Image, c: Vector2, r: int, col: Color) -> void:
	for y: int in range(int(c.y) - r, int(c.y) + r + 1):
		for x: int in range(int(c.x) - r, int(c.x) + r + 1):
			if x >= 0 and y >= 0 and x < W and y < H and Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


func _ring(img: Image, c: Vector2, r_out: int, r_in: int, col: Color) -> void:
	for y: int in range(int(c.y) - r_out, int(c.y) + r_out + 1):
		for x: int in range(int(c.x) - r_out, int(c.x) + r_out + 1):
			var d: float = Vector2(x, y).distance_to(c)
			if x >= 0 and y >= 0 and x < W and y < H and d <= r_out and d >= r_in:
				img.set_pixel(x, y, col)


func _rect(img: Image, r: Rect2i, col: Color) -> void:
	img.fill_rect(r.intersection(Rect2i(0, 0, W, H)), col)
