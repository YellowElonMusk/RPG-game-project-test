extends SceneTree
## Builds the game icon from the Clerk's base frame: head and shoulders,
## scaled up with nearest filtering onto a round night-sky badge. Writes
## assets/icon/icon_<size>.png (16, 32, 48, 64, 128, 256); pack the .ico
## with `py tools/art/pack_ico.py`.
##
##   godot --headless --path . -s res://tools/art/make_icon.gd

const SOURCE: String = "res://assets/sprites/enemies/clerk/clerk_base.png"
const OUT_DIR: String = "res://assets/icon/"
const SIZES: Array[int] = [16, 32, 48, 64, 128, 256]
const BADGE: Color = Color("#1d2140")
const RIM: Color = Color("#f2ead8")
## The crop square's side, in head heights (head and shoulders).
const HEAD_TO_SIDE: float = 2.1
## The top fraction of the sprite searched for the head.
const HEAD_ZONE: float = 0.4
## Space above the head, as a fraction of the crop's side.
const TOP_MARGIN: float = 0.12


func _initialize() -> void:
	var src: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	src.convert(Image.FORMAT_RGBA8)
	# The head: the bounding box of the blue skin in the sprite's top part
	# (the legs are blue too).
	var used: Rect2i = src.get_used_rect()
	var head := Rect2i()
	for y: int in range(used.position.y, used.position.y + int(used.size.y * HEAD_ZONE)):
		for x: int in src.get_width():
			var p: Color = src.get_pixel(x, y)
			if p.a > 0.5 and p.b > p.r + 0.15 and p.b > 0.5:
				head = Rect2i(x, y, 1, 1) if head.size == Vector2i.ZERO else head.expand(Vector2i(x, y))
	head.size += Vector2i.ONE
	# A square around it: the head and the shoulders below.
	var side: int = int(head.size.y * HEAD_TO_SIDE)
	var origin := Vector2i(head.get_center().x - side / 2, head.position.y - int(side * TOP_MARGIN))
	var crop := Image.create(side, side, false, Image.FORMAT_RGBA8)
	crop.blit_rect(src, Rect2i(origin, Vector2i(side, side)), Vector2i.ZERO)
	for size: int in SIZES:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c: float = (size - 1) / 2.0
		var r: float = size / 2.0
		var rim: float = maxf(1.0, size / 32.0)
		for y: int in size:
			for x: int in size:
				var d: float = Vector2(x - c, y - c).length()
				if d <= r - rim:
					img.set_pixel(x, y, BADGE)
				elif d <= r:
					img.set_pixel(x, y, RIM)
		var art: Image = crop.duplicate()
		art.resize(size, size, Image.INTERPOLATE_NEAREST if size >= 64 else Image.INTERPOLATE_BILINEAR)
		img.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i.ZERO)
		# Keep the badge round: clear what the art put outside the circle.
		for y: int in size:
			for x: int in size:
				if Vector2(x - c, y - c).length() > r:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + "icon_%d.png" % size))
	print("make_icon: wrote %d sizes" % SIZES.size())
	quit()
