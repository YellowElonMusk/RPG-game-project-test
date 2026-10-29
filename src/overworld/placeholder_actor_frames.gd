## Generated placeholder `SpriteFrames` for overworld actors (story 136;
## final art comes from `design/art/asset-list.md`). One `idle_down` clip of
## one frame: a solid body with a lighter head and a 1-texel dark outline,
## so it reads against the set.
## TODO(art): replace with authored sprite sheets once the asset list lands.
class_name PlaceholderActorFrames
extends RefCounted

## The single clip `make()` authors; `CharacterSprite.show_frame(&"idle",
## &"down", ...)` resolves to it.
const IDLE_DOWN: StringName = &"idle_down"


## Builds frames of `size_px` texels tinted `body`. Pure: no file I/O.
static func make(body: Color, size_px: Vector2i) -> SpriteFrames:
	var img := Image.create(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var head_h: int = size_px.y / 3
	var outline := Color(0.08, 0.06, 0.06, 1.0)
	var head: Color = body.lightened(0.45)
	for y: int in size_px.y:
		for x: int in size_px.x:
			var in_head: bool = y < head_h and x >= size_px.x / 4 and x < size_px.x - size_px.x / 4
			var in_body: bool = y >= head_h
			if not (in_head or in_body):
				continue
			var edge: bool = x == 0 or x == size_px.x - 1 or y == size_px.y - 1 or y == 0 \
					or (in_head and (x == size_px.x / 4 or x == size_px.x - size_px.x / 4 - 1)) \
					or (in_body and y == head_h)
			img.set_pixel(x, y, outline if edge else (head if in_head else body))
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(IDLE_DOWN)
	frames.set_animation_loop(IDLE_DOWN, false)
	frames.add_frame(IDLE_DOWN, ImageTexture.create_from_image(img))
	return frames
