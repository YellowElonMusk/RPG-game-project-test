## Sprite check: plays every exported SpriteForge strip in-engine, one row per
## character, plus the battle backdrops. Not used by the game.
##
## Run:   godot --path . -s res://prototypes/sprite_check/sprite_check.gd
##        keys 1 = squad, 2 = enemies, 3 = backdrops
## Shots: add `-- --shots=<dir>` to save screenshots and quit.
extends SceneTree

const ROOT := "res://assets/sprites"
const ANIMS := ["base", "idle", "attack", "special", "defend", "hurt", "ko", "victory"]
const FPS := {"idle": 4, "attack": 10, "special": 10, "defend": 6, "hurt": 8, "ko": 8, "victory": 8}
const CELL := 136
const LABEL_W := 150

var _shots_dir := ""
var _pages: Array[Node2D] = [Node2D.new(), Node2D.new(), Node2D.new()]   # squad, enemies, backdrops


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var size := Vector2i(LABEL_W + CELL * ANIMS.size() + 20, 60 + CELL * 5)
	DisplayServer.window_set_size(size)
	root.size = size
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color(0.42, 0.42, 0.42))
	for page in _pages:
		root.add_child(page)
	_build_sprites("squad", _pages[0])
	_build_sprites("enemies", _pages[1])
	_build_backdrops()
	_show(0)
	if _shots_dir != "":
		_take_shots.call_deferred()


func _process(_delta: float) -> bool:
	for i in _pages.size():
		if Input.is_key_pressed(KEY_1 + i):
			_show(i)
	return false


func _show(page: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == page


func _label(parent: Node, text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	parent.add_child(l)


func _build_sprites(group: String, page: Node2D) -> void:
	_label(page, "1 = squad   2 = enemies   3 = backdrops", Vector2(8, 8))
	for i in ANIMS.size():
		_label(page, ANIMS[i], Vector2(LABEL_W + i * CELL + 4, 32))
	var y := 56
	for who in DirAccess.get_directories_at(ROOT.path_join(group)):
		_label(page, who, Vector2(8, y + CELL / 2 - 10))
		for i in ANIMS.size():
			var path := ROOT.path_join(group).path_join(who).path_join("%s_%s.png" % [who, ANIMS[i]])
			var cell := Vector2(LABEL_W + i * CELL, y)
			if not ResourceLoader.exists(path):
				_label(page, "-", cell + Vector2(60, CELL / 2 - 10))
				continue
			page.add_child(_strip(load(path), ANIMS[i], cell))
		y += CELL


func _strip(tex: Texture2D, anim: String, cell: Vector2) -> AnimatedSprite2D:
	var h := tex.get_height()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", FPS.get(anim, 1))
	for f in tex.get_width() / h:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(f * h, 0, h, h)
		frames.add_frame(&"default", a)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.centered = false
	var scale := 2 if h <= 64 else 1     # integer scale only: 64 -> 128, 128 -> 128
	s.scale = Vector2(scale, scale)
	s.position = cell
	s.play()
	return s


func _build_backdrops() -> void:
	var files := Array(DirAccess.get_files_at("res://assets/backgrounds")).filter(
			func(f: String) -> bool: return f.ends_with(".png"))
	for i in files.size():
		var s := Sprite2D.new()
		s.texture = load("res://assets/backgrounds/" + files[i])
		s.centered = false
		s.scale = Vector2(0.9, 0.9)
		s.position = Vector2(8 + (i % 2) * 590, 10 + (i / 2) * 350)
		_pages[2].add_child(s)
		_label(_pages[2], files[i], s.position + Vector2(4, 4))


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	for page in _pages.size():
		_show(page)
		for n in (3 if page < 2 else 1):
			await create_timer(0.37).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_shots_dir.path_join("page%d_%d.png" % [page + 1, n]))
	quit()
