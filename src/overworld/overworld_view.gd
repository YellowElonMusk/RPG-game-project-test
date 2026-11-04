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
## Stand-in art: battle sprite sets whose idle strip the leader, followers
## and symbols show (`PlaceholderActorFrames.from_sprite_set()`). Null = the
## tinted placeholder above. Squad sets face right (`back`), enemy sets
## face left (`front`); a sprite mirrors when it walks the other way.
@export var leader_sprite_set: SpriteSetData
@export var follower_sprite_sets: Array[SpriteSetData] = []
@export var symbol_sprite_set: SpriteSetData

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
## CharacterSprite -> true when its stand-in art faces left (enemy `front`
## sets); only sprites showing a sprite set are keys.
var _art_faces_left: Dictionary = {}
## CharacterSprite -> whether it is currently drawn mirrored.
var _mirrored: Dictionary = {}
## Every shipped sprite set by id, loaded on the first symbol that names one.
var _sprite_sets: Dictionary[StringName, SpriteSetData] = {}
## Sideways motion per frame, in metres, below which a sprite keeps its turn.
const TURN_EPSILON_M: float = 0.001
## The placeholder camp prompt (`_build_prompt()`).
var _prompt_label: Label = null
## Interact prompt text per `OverworldMode.probe_kind()` (placeholder for
## the kind icons, story 015).
const INTERACT_TEXT: Dictionary = {
	&"talk": "[Confirm] Talk",
	&"look": "[Confirm] Look",
	&"rest": "[Confirm] Rest",
	&"ticket": "[Confirm] Take a ticket",
	&"fight": "[Confirm] Challenge",
	&"check": "[Confirm] Check",
}
## How long a bark stays up, in seconds (placeholder for `text_hold`).
@export var bark_hold_s: float = 2.5
var _interact_label: Label = null
## The `probe()` result the interact prompt is drawn for this frame, or
## null when hidden (story 015).
var interact_target: Object = null
## Height above a target's feet the prompt is drawn at, in metres.
@export var prompt_height_m: float = 1.6
var _bark_label: Label = null
var _bark_left: float = 0.0
var _name_card_label: Label = null
var _payoff_card_label: Label = null
## Onboarding: the controls strip, bottom left, while any part is due.
var _controls_label: Label = null


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
	mode.presentation = presentation_config
	mode.party_placed.connect(_on_party_placed)
	mode.barked.connect(_on_barked)
	_camera = FollowCamera.from_config(presentation_config)
	_camera.name = "FollowCamera"
	stage.add_child(_camera)
	_camera.current = true
	_setup_sprite(leader_sprite, leader_tint, leader_sprite_set, &"back")
	for i: int in follower_sprites.size():
		var sprite: CharacterSprite = follower_sprites[i]
		sprite.visible = i < follower_count
		var follower_set: SpriteSetData = follower_sprite_sets[i] if i < follower_sprite_sets.size() else null
		_setup_sprite(sprite, follower_tints[i % follower_tints.size()], follower_set, &"back")
	_build_prompt()
	_camera.snap_to(mode.get_leader_position())
	_present(0.0)


func _process(delta: float) -> void:
	_present(delta)


func _setup_sprite(sprite: CharacterSprite, tint: Color, sprite_set: SpriteSetData = null,
		facing: StringName = &"back") -> void:
	sprite.card_camera = _camera
	sprite.layers = DioramaStage.LAYER_ACTORS
	var frames: SpriteFrames = PlaceholderActorFrames.from_sprite_set(sprite_set, facing)
	if frames == null:
		frames = PlaceholderActorFrames.make(tint, placeholder_size_px)
	else:
		_art_faces_left[sprite] = facing == &"front"
	sprite.setup(frames, presentation_config)


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
	_camera.held = mode.is_dialogue_open()
	_camera.advance(mode.get_leader_position(), delta, aspect, bounds.position, bounds.end)
	_camera.apply_transform(FollowCamera.compute_footprint(
			_camera.height, _camera.pitch_degrees, _camera.fov_degrees, aspect))

	_update_prompt()
	_update_interact_prompt(delta)
	_place(leader_sprite, mode.get_leader_position(), delta)
	var followers: Array[Vector2] = mode.get_follower_positions()
	for i: int in mini(followers.size(), follower_sprites.size()):
		_place(follower_sprites[i], followers[i], delta)
	sync_symbol_sprites(delta)


## Story 137 (AC-137b): one placeholder `CharacterSprite` per registered
## symbol, placed at its `SymbolBrain` position; a symbol the mode dropped
## (Victory) loses its sprite. Called every presentation frame.
func sync_symbol_sprites(mode_dt: float = 0.0) -> void:
	if symbol_root == null or _camera == null:
		return
	var live: Array[SymbolBrain] = mode.get_symbol_brains()
	var sources: Dictionary = {}
	for source: EncounterSource in mode.get_encounter_sources():
		sources[source.brain] = source
	for brain: SymbolBrain in _symbol_sprites.keys():
		if not live.has(brain):
			var gone: CharacterSprite = _symbol_sprites[brain]
			_symbol_sprites.erase(brain)
			_art_faces_left.erase(gone)
			_mirrored.erase(gone)
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
			_setup_sprite(sprite, symbol_tint, _symbol_set_for(sources.get(brain) as EncounterSource), &"front")
			_symbol_sprites[brain] = sprite
		_place(sprite, brain.position, mode_dt)
		# Story 134 (ADR-0005 §14): the sprite's capture-ID follows its cue.
		CaptureIdTags.tag(sprite, CaptureIdTags.symbol_tag(brain.sub_state))


## The sprite set a symbol draws: the one its encounter's lead enemy names
## (`OverworldMode.symbol_sprite_set()`; a deflated id with no art of its own
## falls back to the plain one), else `symbol_sprite_set`.
func _symbol_set_for(source: EncounterSource) -> SpriteSetData:
	var set_id: String = mode.symbol_sprite_set(source) if source != null else ""
	if set_id.is_empty():
		return symbol_sprite_set
	if _sprite_sets.is_empty():
		_sprite_sets = PresentationValidators.load_sprite_sets()
	var found: SpriteSetData = _sprite_sets.get(StringName(set_id))
	if found == null:
		found = _sprite_sets.get(StringName(set_id.trim_suffix(mode.config.deflated_sprite_suffix)))
	return found if found != null else symbol_sprite_set


## The live symbol sprites, keyed by `SymbolBrain` (tests).
func get_symbol_sprites() -> Dictionary:
	return _symbol_sprites.duplicate()


## Places `sprite` and steps its ambient idle by `mode_dt`, this frame's
## mode-time delta (sprite-camera story 011): this view runs under `ModeHost`,
## so the Menu stops it while Dialogue lets it run. The idle clip is set only
## when it changes, so its frame is never reset to 0 each frame.
##
## Stand-in art (`_art_faces_left`) turns to face its walk: a sprite moving
## against the way its art faces is mirrored, and keeps the last turn while
## standing or moving straight up or down.
func _place(sprite: CharacterSprite, ground: Vector2, mode_dt: float = 0.0) -> void:
	var dx: float = ground.x - sprite.position.x
	sprite.position = ground_to_world(ground)
	var mirrored: bool = _mirrored.get(sprite, false)
	if _art_faces_left.has(sprite) and absf(dx) > TURN_EPSILON_M:
		mirrored = (dx > 0.0) == bool(_art_faces_left[sprite])
	if sprite.animation != PlaceholderActorFrames.IDLE_DOWN or mirrored != _mirrored.get(sprite, false):
		_mirrored[sprite] = mirrored
		var keep: int = sprite.frame if sprite.animation == PlaceholderActorFrames.IDLE_DOWN else 0
		sprite.show_frame(&"idle", &"down", mirrored, false, keep)
	sprite.step_ambient(mode_dt)


func _viewport_aspect() -> float:
	var size: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	if size.y <= 0.0:
		return 16.0 / 9.0
	return size.x / size.y


## Placeholder "Rest here?" camp prompt (GDD States CampPrompt; story 113):
## a centred label, Yes or No marked as focused. The final P15 widget and
## its screenshots are story 108's.
func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PromptLayer"
	add_child(layer)
	_prompt_label = Label.new()
	_prompt_label.name = "CampPrompt"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-160.0, -120.0)
	_prompt_label.size = Vector2(320.0, 64.0)
	_prompt_label.add_theme_font_size_override(&"font_size", 28)
	_prompt_label.visible = false
	layer.add_child(_prompt_label)
	_build_hud_labels(layer)


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	var camp: CampSpot = mode.get_camp_prompt_camp()
	_prompt_label.visible = camp != null
	if camp != null:
		var yes: bool = mode.camp_prompt_focus == OverworldMode.CampChoice.YES
		# Story 068: the café on the final step asks to end the chapter.
		var question: String = "End the chapter here?" if mode.camp_prompt_is_chapter_end else "Rest here?"
		_prompt_label.text = "%s\n%s   %s" % [question, "[Yes]" if yes else " Yes ", " No " if yes else "[No]"]


## The camp prompt label (tests).
func get_prompt_label() -> Label:
	return _prompt_label


## GDD rule 10 / 13a: a redirect, teleport or thaw snaps the camera to the
## leader under the fade (no smoothing frames, sprite-camera AC-27).
func _on_party_placed(at: Vector2) -> void:
	if _camera != null:
		_camera.snap_to(at)


## Bark window (rule 13a "Take a number.", rule 16): the mode owns its hold
## (`text_hold`, story 130); this only draws it (`_update_interact_prompt`).
func _on_barked(_text: String, _at: Vector2) -> void:
	pass


## Placeholder interact prompt (GDD rule 3, UI Requirements): the kind of
## what `confirm` would act on, drawn while something is in reach. Story
## 015 replaces it with the icon prompt over the target.
func _update_interact_prompt(delta: float) -> void:
	_draw_timed(_bark_label, mode.bark_text, mode.bark_phase)
	_draw_timed(_name_card_label, mode.name_card_text, mode.name_card_phase)
	_draw_timed(_payoff_card_label, mode.payoff_card_text, mode.payoff_card_phase)
	if _controls_label != null:
		var controls: String = mode.controls_hint_text()
		_controls_label.visible = not controls.is_empty()
		_controls_label.text = controls
	if _interact_label == null:
		return
	# Story 015: one `probe()` per frame, only while Exploring (rule 3
	# lockouts), and the prompt drawn above that same target.
	interact_target = mode.probe() if mode.is_exploring() else null
	_interact_label.visible = interact_target != null
	if interact_target == null or _camera == null:
		return
	_interact_label.text = String(INTERACT_TEXT.get(OverworldMode.kind_of(interact_target), ""))
	var above: Vector3 = ground_to_world(mode.target_position(interact_target)) + Vector3(0.0, prompt_height_m, 0.0)
	_interact_label.position = _camera.unproject_position(above) - _interact_label.size * Vector2(0.5, 1.0)


func _build_hud_labels(layer: CanvasLayer) -> void:
	_interact_label = Label.new()
	_interact_label.name = "InteractPrompt"
	# Story 134: tagged for the capture tool; a CanvasItem, so its mask is
	# the `ui` pass, not the 3D ID pass.
	CaptureIdTags.tag(_interact_label, CaptureIdTags.INTERACT_PROMPT)
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.size = Vector2(320.0, 40.0)
	_interact_label.add_theme_font_size_override(&"font_size", 22)
	_interact_label.visible = false
	layer.add_child(_interact_label)
	_bark_label = Label.new()
	_bark_label.name = "Bark"
	_bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Wide enough for a one-line onboarding hint (2026-11-04); wraps if not.
	_bark_label.position = Vector2(-450.0, 40.0)
	_bark_label.size = Vector2(900.0, 48.0)
	_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark_label.add_theme_font_size_override(&"font_size", 26)
	_bark_label.visible = false
	layer.add_child(_bark_label)
	_name_card_label = Label.new()
	_name_card_label.name = "NameCard"
	_name_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_card_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name_card_label.position = Vector2(-240.0, 96.0)
	_name_card_label.size = Vector2(480.0, 48.0)
	_name_card_label.add_theme_font_size_override(&"font_size", 28)
	_name_card_label.visible = false
	layer.add_child(_name_card_label)
	_payoff_card_label = Label.new()
	_payoff_card_label.name = "PayoffCard"
	_payoff_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_payoff_card_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_payoff_card_label.position = Vector2(-240.0, 160.0)
	_payoff_card_label.size = Vector2(480.0, 48.0)
	_payoff_card_label.add_theme_font_size_override(&"font_size", 24)
	_payoff_card_label.visible = false
	layer.add_child(_payoff_card_label)
	_controls_label = Label.new()
	_controls_label.name = "ControlsHint"
	_controls_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_controls_label.position = Vector2(16.0, -64.0)
	_controls_label.add_theme_font_size_override(&"font_size", 22)
	_controls_label.visible = false
	layer.add_child(_controls_label)
	for label: Label in [_bark_label, _name_card_label, _payoff_card_label, _controls_label]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.1, 0.09, 0.08, 0.92)
		panel.set_content_margin_all(10.0)
		label.add_theme_stylebox_override(&"normal", panel)


## The interact prompt and bark labels (tests).
func get_interact_label() -> Label:
	return _interact_label


func get_bark_label() -> Label:
	return _bark_label


## The onboarding controls strip (tests, captures).
func get_controls_label() -> Label:
	return _controls_label


## Draws one timed text element from the mode's state: hidden, shown, or
## fading (half alpha). Opaque panel (P14 legibility).
func _draw_timed(label: Label, text: String, phase: int) -> void:
	if label == null:
		return
	label.visible = phase != OverworldMode.CardPhase.HIDDEN
	label.text = text
	label.modulate.a = 0.5 if phase == OverworldMode.CardPhase.FADING else 1.0


## The name card label (tests, captures).
func get_name_card_label() -> Label:
	return _name_card_label
