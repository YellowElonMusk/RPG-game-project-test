extends SceneTree
## Makes the recruits' PLACEHOLDER battle sprites (recruits.md): each
## recruit borrows a starting member's strips, recoloured to one flat fill
## (shaded by the source's brightness) inside the Outline Ink edge, so the
## animation timing works and nobody mistakes it for final art. Writes
## `assets/sprites/squad/<id>/<id>_<clip>.png`. Re-run after editing RECRUITS:
##
##   godot --headless --path . -s res://tools/art/recruit_placeholder_sprites.gd

const CLIPS: Array[String] = ["idle", "attack", "defend", "hurt", "ko", "victory", "special", "base"]
const INK := Color("#1A1418")
## recruit id -> [source squad id, fill colour]. No faction colours.
const RECRUITS: Dictionary = {
	"street_mime": ["karen", "#D9D6CF"],
	"rush_hour_commuter": ["baguette_thrower", "#8A96A6"],
	"infomercial_host": ["florida_man", "#F6C37A"],
	"boxing_kangaroo": ["baguette_thrower", "#B0703C"],
	"goalie": ["michelin_chef", "#3E8E7E"],
	"fitness_instructor": ["karen", "#7BD389"],
}


func _initialize() -> void:
	for id: String in RECRUITS:
		var src: String = RECRUITS[id][0]
		var fill := Color(String(RECRUITS[id][1]))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/squad/%s" % id))
		for clip: String in CLIPS:
			var img := Image.load_from_file(ProjectSettings.globalize_path(
					"res://assets/sprites/squad/%s/%s_%s.png" % [src, src, clip]))
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
			out.save_png(ProjectSettings.globalize_path("res://assets/sprites/squad/%s/%s_%s.png" % [id, id, clip]))
	print("recruit placeholder sprites written")
	quit()
