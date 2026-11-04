extends SceneTree
## Makes Liberty-7's PLACEHOLDER enemy battle sprites (Chapter 4): each
## enemy borrows a MegaCorp enemy's strips, recoloured to one flat fill
## (shaded by the source's brightness) inside the Outline Ink edge, the same
## treatment as `recruit_placeholder_sprites.gd`. Writes
## `assets/sprites/enemies/<id>/<id>_<clip>.png`. Re-run after editing ENEMIES:
##
##   godot --headless --path . -s res://tools/art/liberty7_placeholder_sprites.gd

const INK := Color("#1A1418")
## enemy id -> [source enemy id, fill colour, clips]. Anthem Blue family.
const ENEMIES: Dictionary = {
	"star_trooper": ["middle_manager", "#2F5BEA", ["idle", "attack", "hurt", "ko", "base"]],
	"eagle_drone": ["security_drone", "#C9D3F2", ["idle", "attack", "hurt", "ko", "base"]],
	"super_patriot": ["ceo", "#1E3FB0", ["idle", "attack", "hurt", "ko", "special", "base"]],
}


func _initialize() -> void:
	for id: String in ENEMIES:
		var src: String = ENEMIES[id][0]
		var fill := Color(String(ENEMIES[id][1]))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/enemies/%s" % id))
		for clip: String in ENEMIES[id][2]:
			var img := Image.load_from_file(ProjectSettings.globalize_path(
					"res://assets/sprites/enemies/%s/%s_%s.png" % [src, src, clip]))
			if img == null:
				push_error("missing %s %s" % [src, clip])
				continue
			img.convert(Image.FORMAT_RGBA8)
			var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
			for y: int in img.get_height():
				for x: int in img.get_width():
					var c: Color = img.get_pixel(x, y)
					if c.a < 0.5:
						continue
					var edge: bool = false
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var p: Vector2i = Vector2i(x, y) + d
						if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height() \
								or img.get_pixelv(p).a < 0.5:
							edge = true
					var shade: float = 0.55 + 0.45 * c.get_luminance()
					out.set_pixel(x, y, INK if edge else Color(fill.r * shade, fill.g * shade, fill.b * shade, 1.0))
			out.save_png(ProjectSettings.globalize_path("res://assets/sprites/enemies/%s/%s_%s.png" % [id, id, clip]))
	print("liberty7 placeholder sprites written")
	quit()
