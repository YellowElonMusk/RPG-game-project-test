extends SceneTree
## Paints the Rat Catchers' PLACEHOLDER battle backdrops (narrative bible
## §6.5: the human resistance lives in disused metro stations):
## `assets/backgrounds/bg_battle_rat_catchers.png` (a tiled platform by work
## lamp) and `bg_battle_rat_catchers_boss.png` (the same station at night,
## lanterns and blank wanted posters). Drawn at 320x180 and scaled 2x
## nearest, like the other painted placeholders. No rubble (guardrail 3): the
## station is closed, not ruined.
## TODO(art): authored backdrops replace these (production/asset-requests/art.md).
##
##   godot --headless --path . -s res://tools/art/rat_catcher_backdrops.gd

const W: int = 320
const H: int = 180


func _initialize() -> void:
	_paint(false).save_png(ProjectSettings.globalize_path("res://assets/backgrounds/bg_battle_rat_catchers.png"))
	_paint(true).save_png(ProjectSettings.globalize_path("res://assets/backgrounds/bg_battle_rat_catchers_boss.png"))
	print("rat catcher backdrops written")
	quit()


func _paint(boss: bool) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var tile := Color("#D9CFB4") if not boss else Color("#8E8670")
	var grout := tile.darkened(0.35)
	var vault := Color("#2A2620") if not boss else Color("#16130F")
	for y: int in H:
		for x: int in W:
			var c: Color
			# The vault: a dark barrel arch over the tiled wall.
			var arch_y: float = 40.0 - 30.0 * (1.0 - pow((float(x) - 160.0) / 160.0, 2.0))
			if y < arch_y + 14:
				c = vault
			elif y < 112:
				# White metro tiles, offset brick bond, with a coloured band.
				var row: int = int((y - 14) / 6)
				var col: int = int((x + (3 if row % 2 == 1 else 0)) / 8)
				c = grout if ((y - 14) % 6 == 0 or (x + (3 if row % 2 == 1 else 0)) % 8 == 0) else tile
				if y >= 70 and y < 76:
					c = Color("#7A5A2E") if not boss else Color("#4E3A1E")
				if (col + row) % 17 == 0:
					c = c.darkened(0.08)
			elif y < 126:
				# Platform edge: a yellow safety line.
				c = Color("#5E5A52") if not boss else Color("#3A3732")
				if y >= 122:
					c = Color("#D8B23A") if not boss else Color("#8C7428")
			else:
				# Platform floor, then the track bed and two rails at the bottom.
				c = Color("#6E6A62") if not boss else Color("#403C36")
				if y >= 160:
					c = Color("#2C2824")
					if y == 166 or y == 167 or y == 174 or y == 175:
						c = Color("#9A9AA2")
				elif (x + y) % 11 == 0:
					c = c.darkened(0.06)
			img.set_pixel(x, y, c)
	# Work lamps (day) or lanterns (night) along the vault.
	for lx: int in range(30, W, 64):
		var glow := Color("#FFE6A0") if not boss else Color("#F6A040")
		_rect(img, Rect2i(lx, 30, 6, 4), glow)
		_rect(img, Rect2i(lx + 2, 22, 2, 8), Color("#1A1418"))
	# Blank paper notices on the tiles: route maps by day, wanted posters by night.
	var poster := Color("#F4EAD2") if not boss else Color("#E8D9A8")
	for px: int in [52, 150, 240]:
		_rect(img, Rect2i(px, 82, 22, 26), Color("#1A1418"))
		_rect(img, Rect2i(px + 1, 83, 20, 24), poster)
		if boss:
			# A rat silhouette on each wanted poster: a body and a tail.
			_rect(img, Rect2i(px + 6, 92, 9, 5), Color("#3A2A1E"))
			_rect(img, Rect2i(px + 14, 90, 3, 3), Color("#3A2A1E"))
			_rect(img, Rect2i(px + 2, 95, 4, 1), Color("#3A2A1E"))
		else:
			for ly: int in range(87, 104, 4):
				_rect(img, Rect2i(px + 4, ly, 14, 1), Color("#7A8CA0"))
	img.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
	return img


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y: int in range(maxi(0, r.position.y), mini(H, r.end.y)):
		for x: int in range(maxi(0, r.position.x), mini(W, r.end.x)):
			img.set_pixel(x, y, c)
