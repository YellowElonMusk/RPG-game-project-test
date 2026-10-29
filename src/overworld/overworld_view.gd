## The Overworld's presentation half (story 136; ADR-0012 §4 step 5,
## ADR-0005 §1/§6): places the leader and follower `CharacterSprite`s at the
## mode's ground positions, drives the follower trail, and advances the one
## `FollowCamera`. Reads `OverworldMode`'s state; never writes the leader.
##
## Kept out of `OverworldMode._process()` on purpose: stories 005/006 fix
## that hook as leader-movement only (`follower_no_collision_test.gd`,
## `follower_trail_test.gd`), and `step_followers()` is documented as the
## caller's per-frame call. Runs at `process_priority = 0`, the camera's slot
## in ADR-0012 §2's pinned order (mode -10 first, so this frame's leader
## position is already final).
class_name OverworldView
extends Node

## The mode whose leader and followers this view presents.
@export var mode: OverworldMode
## The stage the camera is parented under (one per scene, ADR-0005 §3).
@export var stage: DioramaStage
## The leader sprite; its `material_override` must already carry
## `sprite_actor.gdshader` (scene-authored) -- `setup()` keeps that shader.
@export var leader_sprite: CharacterSprite
## Follower sprites, nearest first. Only the first `follower_count` are shown.
@export var follower_sprites: Array[CharacterSprite] = []
## How many followers trail the leader (0-3). TODO(ow-epic): read from the
## party roster once it exists (story 008/010); scene-authored until then.
@export_range(0, 3) var follower_count: int = 3
## Camera and texel-scale tuning. TODO(sprite-camera-presentation): inject
## the project `PresentationConfig` once ADR-0009's settings injector exists.
@export var presentation_config: PresentationConfig = PresentationConfig.new()
## Placeholder frame size in texels and the tints for leader, then followers.
@export_group("Placeholder Art")
@export var placeholder_size_px: Vector2i = Vector2i(12, 24)
@export var leader_tint: Color = Color(0.75, 0.2, 0.2)
@export var follower_tints: Array[Color] = [
	Color(0.2, 0.45, 0.8), Color(0.25, 0.65, 0.3), Color(0.8, 0.6, 0.15)]

var _camera: FollowCamera = null
var _last_aspect: float = 0.0

## Where symbol sprites are parented (story 137); null draws no symbols.
@export var symbol_root: Node3D
## The actor shader for symbol sprites' `ShaderMaterial`s.
@export var symbol_shader: Shader
## Placeholder tint for symbol sprites (art placeholder, not a tuning knob).
@export var symbol_tint: Color = Color(0.25, 0.25, 0.3)
## SymbolBrain -> CharacterSprite, one per registered symbol.
var _symbol_sprites: Dictionary = {}


func _init() -> void:
	process_priority = 0


## The live follow camera (built from `presentation_config` in `_ready()`),
## or null before then.
func get_camera() -> FollowCamera:
	return _camera


## A ground-plane point as a world position (`FollowCamera` convention).
static func ground_to_world(ground: Vector2) -> Vector3:
	return Vector3(ground.x, 0.0, ground.y)


func _ready() -> void:
	# Children are ready before their parent: wait for the mode's own
	# `_ready()` (map load, leader spawn) before snapping the camera.
	if not mode.is_node_ready():
		mode.ready.connect(_start, CONNECT_ONE_SHOT)
		set_process(false)
		return
	_start()


func _start() -> void:
	set_process(true)
	_camera = FollowCamera.from_config(presentation_config)
	_camera.name = "FollowCamera"
	stage.add_child(_camera)
	_camera.current = true
	_setup_sprite(leader_sprite, leader_tint)
	for i: int in follower_sprites.size():
		var sprite: CharacterSprite = follower_sprites[i]
		sprite.visible = i < follower_count
		_setup_sprite(sprite, follower_tints[i % follower_tints.size()])
	_camera.snap_to(mode.get_leader_position())
	_present(0.0)


func _process(delta: float) -> void:
	_present(delta)


func _setup_sprite(sprite: CharacterSprite, tint: Color) -> void:
	sprite.card_camera = _camera
	sprite.layers = DioramaStage.LAYER_ACTORS
	sprite.setup(PlaceholderActorFrames.make(tint, placeholder_size_px), presentation_config)


## One presentation frame: trail, camera, then sprites (their uniforms read
## the camera, so it moves first).
func _present(delta: float) -> void:
	mode.step_followers(follower_count)
	var aspect: float = _viewport_aspect()
	if not is_equal_approx(aspect, _last_aspect):
		_camera.apply_fov(aspect)
		_last_aspect = aspect
	var bounds: Rect2 = Rect2()
	var grid: WalkGrid = mode.get_walk_grid()
	if grid != null:
		bounds = OverworldMap.ground_bounds(grid)
	_camera.advance(mode.get_leader_position(), delta, aspect, bounds.position, bounds.end)
	_camera.apply_transform(FollowCamera.compute_footprint(
			_camera.height, _camera.pitch_degrees, _camera.fov_degrees, aspect))

	_place(leader_sprite, mode.get_leader_position())
	var followers: Array[Vector2] = mode.get_follower_positions()
	for i: int in mini(followers.size(), follower_sprites.size()):
		_place(follower_sprites[i], followers[i])
	sync_symbol_sprites()


## Story 137 (AC-137b): one placeholder `CharacterSprite` per registered
## symbol, placed at its `SymbolBrain` position; a symbol the mode dropped
## (Victory) loses its sprite. Called every presentation frame.
func sync_symbol_sprites() -> void:
	if symbol_root == null or _camera == null:
		return
	var live: Array[SymbolBrain] = mode.get_symbol_brains()
	for brain: SymbolBrain in _symbol_sprites.keys():
		if not live.has(brain):
			var gone: CharacterSprite = _symbol_sprites[brain]
			_symbol_sprites.erase(brain)
			gone.queue_free()
	for brain: SymbolBrain in live:
		var sprite: CharacterSprite = _symbol_sprites.get(brain) as CharacterSprite
		if sprite == null:
			sprite = CharacterSprite.new()
			sprite.name = "Symbol%d" % brain.marker_index
			var mat := ShaderMaterial.new()
			mat.shader = symbol_shader
			sprite.material_override = mat
			symbol_root.add_child(sprite)
			_setup_sprite(sprite, symbol_tint)
			_symbol_sprites[brain] = sprite
		_place(sprite, brain.position)


## The live symbol sprites, keyed by `SymbolBrain` (tests).
func get_symbol_sprites() -> Dictionary:
	return _symbol_sprites.duplicate()


func _place(sprite: CharacterSprite, ground: Vector2) -> void:
	sprite.position = ground_to_world(ground)
	sprite.show_frame(&"idle", &"down", false, false, 0)


func _viewport_aspect() -> float:
	var size: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	if size.y <= 0.0:
		return 16.0 / 9.0
	return size.x / size.y
