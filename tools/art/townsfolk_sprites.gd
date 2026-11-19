extends SceneTree
## Placeholder townsfolk (overworld NPCs) until real civilian art exists:
## squad base frames, palette-swapped to muted coats so they read as
## background extras, not the squad. Cropped to the drawn pixels, so the
## frame's bottom row is the feet. Writes assets/sprites/townsfolk/.
##
##   godot --headless --path . -s res://tools/art/townsfolk_sprites.gd

const OUT_DIR: String = "res://assets/sprites/townsfolk/"
## [source base frame, coat tint].
const VARIANTS: Array = [
	["res://assets/sprites/squad/karen/karen_base.png", Color("#8a93a8")],
	["res://assets/sprites/squad/florida_man/florida_man_base.png", Color("#a8957a")],
	["res://assets/sprites/squad/rush_hour_commuter/rush_hour_commuter_base.png", Color("#7f9a88")],
	["res://assets/sprites/squad/michelin_chef/michelin_chef_base.png", Color("#9a8296")],
]
## How far each pixel moves from its own colour toward the tinted grey.
const SWAP: float = 0.7


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i: int in VARIANTS.size():
		var src: Image = Image.load_from_file(ProjectSettings.globalize_path(String(VARIANTS[i][0])))
		src.convert(Image.FORMAT_RGBA8)
		var img: Image = src.get_region(src.get_used_rect())
		var tint: Color = VARIANTS[i][1]
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a == 0.0:
					continue
				var l: float = c.get_luminance()
				var swapped := Color(l * tint.r * 1.25, l * tint.g * 1.25, l * tint.b * 1.25, c.a)
				img.set_pixel(x, y, c.lerp(swapped, SWAP))
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + "townsfolk_%d.png" % (i + 1)))
	print("townsfolk_sprites: wrote %d" % VARIANTS.size())
	quit()
