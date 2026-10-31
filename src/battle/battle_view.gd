## The battle's diorama view (ADR-0005 §1, §6, §9): the faction backdrop, the
## level battle camera, and one `CharacterSprite` per combatant standing on
## its `BattleStage` slot -- squad on slots `0 .. 3` facing `back`, enemies on
## the following slots facing `front`. Frames come from each record's
## `SpriteSetData` and are read only through the replay's display snapshots
## and the current `BeatPlan`, never the live `Combatant` (AC-14).
##
## Per frame: the current beat's actor shows its action (move-specific art
## when authored, else `attack`; `defend` for Defend) on the beat's clock,
## and its reactors show `hit`; otherwise a combatant at 0 HP shows the
## `knockout` landing frame, a defending one the `defend` brace, and the rest
## the `idle` loop on mode time.
##
## Each combatant also gets one blob shadow (rule 12, story 020) kept the
## same on-screen width as its sprite, and every HIT/KNOCKOUT reactor gets an
## `impact_burst` at mid-body on the beat's impact.
##
## Usage example:
## [codeblock]
## view.setup(core, replay, descriptor, presentation_config)
## [/codeblock]
class_name BattleView
extends Node

## Squad sets face away from the camera, enemies toward it (asset list §3).
const SQUAD_FACING: StringName = &"back"
const ENEMY_FACING: StringName = &"front"
## Stage slots `0 .. SQUAD_SLOTS - 1` are the squad's; enemies follow.
const SQUAD_SLOTS: int = 4
## Where the stage and backdrop content live.
const STAGE_PATH := "res://data/presentation/stages/%s.tres"
const DEFAULT_STAGE: StringName = &"battle_default"
const BOSS_STAGE: StringName = &"battle_boss"
const BACKDROP_PATH := "res://assets/backgrounds/bg_battle_%s%s.png"
## The impact burst strip (SpriteForge GE, asset list §5) and its playback.
const IMPACT_BURST_PATH := "res://assets/vfx/impact_burst.png"
const IMPACT_BURST_FPS: float = 16.0
## Bursts sit this far in front of their target so they draw over it (m).
const VFX_DEPTH_BIAS: float = 0.05
## The burst's flash source (`data/presentation/flash_sources/`).
const IMPACT_BURST_SOURCE: StringName = &"vfx_impact_burst"
## The capped variant (GDD rule 13): the same shape pulled toward a dim warm
## grey, a soft swell under `flash_luma_delta` (declared as the source's
## `capped_luma_swing`). Not an alpha fade: the sprite shader cuts alpha at
## 0.5, so a faded burst would vanish instead.
const CAPPED_TINT: Color = Color(0.45, 0.40, 0.36)
const CAPPED_MIX: float = 0.8

## The mode's diorama stage; its `camera` becomes the battle camera.
@export var stage: DioramaStage
## Parent of the spawned `CharacterSprite`s.
@export var actor_root: Node3D
## Full-screen backdrop, drawn as the environment's canvas background.
@export var backdrop: TextureRect
## The `sprite_actor` shader each sprite's own material uses.
@export var sprite_shader: Shader

var _battle_stage: BattleStage
var _config: PresentationConfig
var _replay: BattleReplayController
var _sprites: Dictionary[Combatant, CharacterSprite] = {}
var _sets: Dictionary[Combatant, SpriteSetData] = {}
var _mode_time: float = 0.0
var _camera_configured: bool = false
var _shadows: Dictionary[Combatant, MeshInstance3D] = {}
var _burst_set: SpriteSetData
## The flash gate every burst asks first (ADR-0005 §12); null plays uncapped.
var flash_gate: FlashGate = null
var _burst_frames: SpriteFrames
var _burst_frames_capped: SpriteFrames
## Live bursts: sprite -> seconds played.
var _bursts: Dictionary[CharacterSprite, float] = {}
var _squad_size: int = 0


## Builds the sprites and backdrop for `battle`. Call once, from
## `BattleMode.setup()` (before or after entering the tree). `catalog`
## resolves each combatant's record (`record_id`) to its `sprite_set_id`;
## `sprite_sets` defaults to the shipped sets.
func setup(battle: BattleCore, replay: BattleReplayController, descriptor: EncounterDescriptor,
		config: PresentationConfig, catalog: ContentCatalogService = null,
		sprite_sets: Dictionary[StringName, SpriteSetData] = {}) -> void:
	_config = config
	_replay = replay
	_burst_set = _make_burst_set()
	if _burst_set != null:
		_burst_frames = _burst_set.build_sprite_frames()
		_burst_frames_capped = capped_frames(_burst_frames, CAPPED_TINT, CAPPED_MIX)
	_squad_size = battle.squad.size()
	if _replay != null:
		_replay.beat_impact.connect(_on_beat_impact)
		_replay.replay_cancelled.connect(reset_display)
		_replay.display_resynced.connect(reset_display)
	if catalog == null:
		catalog = BattleCatalog.shipped()
	if sprite_sets.is_empty():
		sprite_sets = PresentationValidators.load_sprite_sets()
	var stage_id: StringName = BOSS_STAGE if descriptor.is_boss else DEFAULT_STAGE
	_battle_stage = load(STAGE_PATH % stage_id) as BattleStage
	if backdrop != null:
		backdrop.texture = load_backdrop(descriptor.faction_id, descriptor.is_boss)
	for i: int in battle.squad.size():
		_spawn(battle.squad[i], i, catalog, sprite_sets)
	var enemy_slots: Array[int] = enemy_slots_for(_battle_stage, battle.enemies.size())
	for i: int in mini(battle.enemies.size(), enemy_slots.size()):
		_spawn(battle.enemies[i], enemy_slots[i], catalog, sprite_sets)
	if battle.enemies.size() > enemy_slots.size():
		push_warning("BattleView: stage %s has %d enemy slots for %d enemies"
				% [_battle_stage.stage_id if _battle_stage else &"", enemy_slots.size(), battle.enemies.size()])
	_try_configure_camera()


## The backdrop for `faction_id` (`faction_<name>`), the boss variant when
## `is_boss`; null when none is shipped.
static func load_backdrop(faction_id: String, is_boss: bool) -> Texture2D:
	var path: String = BACKDROP_PATH % [faction_id.trim_prefix("faction_"), "_boss" if is_boss else ""]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The slots `count` enemies stand on: the enemy slots (`SQUAD_SLOTS` on)
## nearest the centre line first, so the first enemy (the boss, in a boss
## encounter) takes the middle; at most as many as the stage has.
static func enemy_slots_for(battle_stage: BattleStage, count: int) -> Array[int]:
	var slots: Array[int] = []
	if battle_stage == null:
		return slots
	for i: int in range(SQUAD_SLOTS, battle_stage.slots.size()):
		slots.append(i)
	slots.sort_custom(func(a: int, b: int) -> bool:
		var da: float = absf(battle_stage.slots[a].x)
		var db: float = absf(battle_stage.slots[b].x)
		return da < db if not is_equal_approx(da, db) else battle_stage.slots[a].x < battle_stage.slots[b].x)
	return slots.slice(0, count)


## The sprite standing in for `c`, or null (tests, capture).
func get_sprite(c: Combatant) -> CharacterSprite:
	return _sprites.get(c) as CharacterSprite


## The controller's `windup` callable (ADR-0006 §1): `plan`'s 1x wind-up,
## from its actor's action animation (`impact_seconds()`), or -1.0 (the
## debug path) when the actor has no sprite set or no valid impact frame.
func windup_seconds(plan: BeatPlan) -> float:
	var c: Combatant = plan.actor
	if not _sets.has(c):
		return -1.0
	var anim_id: StringName = &"attack"
	var move_name: String = ""
	match plan.action_role:
		BeatPlan.ActionRole.DEFEND:
			anim_id = &"defend"
		BeatPlan.ActionRole.SPECIAL:
			anim_id = SpriteSetData.MOVE
			move_name = plan.move_name
	var facing: StringName = ENEMY_FACING if c.is_enemy else SQUAD_FACING
	var r: SpriteSetData.Resolution = _sets[c].resolve(anim_id, facing, move_name, func(_m: String) -> void: pass)
	if r.animation == null:
		return -1.0
	return r.animation.impact_seconds()


## The controller's `ko_landing` callable (ADR-0006 §1): seconds at 1x from
## `c`'s knockout start to its `land_frame`; 0.0 without one.
func ko_landing_seconds(c: Combatant) -> float:
	if not _sets.has(c):
		return 0.0
	var facing: StringName = ENEMY_FACING if c.is_enemy else SQUAD_FACING
	var r: SpriteSetData.Resolution = _sets[c].resolve(&"knockout", facing, "", func(_m: String) -> void: pass)
	if r.animation == null:
		return 0.0
	return maxf(r.animation.land_seconds(), 0.0)


## The party row's foot anchors in stage space, one per squad member in
## slot order (`0 .. squad size - 1`), whether or not a sprite spawned for
## it. Empty before `setup()`.
func party_anchors() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _battle_stage == null:
		return out
	for i: int in mini(_squad_size, mini(SQUAD_SLOTS, _battle_stage.slots.size())):
		out.append(_battle_stage.slot_anchor(i))
	return out


## Resets the beat-driven display (ADR-0006 §8, Retry and exit): drops every
## impact burst and shows each combatant's pose for the displayed state at
## once (`idle` after a Retry's resync, knockout poses included).
func reset_display() -> void:
	for burst: CharacterSprite in _bursts.keys():
		burst.queue_free()
	_bursts.clear()
	if _replay != null:
		present()


func _ready() -> void:
	_try_configure_camera()


func _process(delta: float) -> void:
	_mode_time += delta
	present()
	_step_bursts(delta)


## One presentation frame: every sprite's frame for the current replay state.
## Public so capture tools can drive it.
func present() -> void:
	var plan: BeatPlan = _replay.get_current_plan() if _replay != null else null
	for c: Combatant in _sprites:
		_show(c, plan)
		_place_shadow(c)
	_follow_punch()


func _show(c: Combatant, plan: BeatPlan) -> void:
	var facing: StringName = ENEMY_FACING if c.is_enemy else SQUAD_FACING
	var anim_id: StringName = &"idle"
	var move_name: String = ""
	var seconds: float = _mode_time
	var hold_last: bool = false
	if plan != null and (plan.actor == c or plan.reactions.has(c)):
		seconds = _replay.get_windup_progress() + _replay.get_post_impact_time()
	if plan != null and plan.actor == c:
		match plan.action_role:
			BeatPlan.ActionRole.DEFEND:
				anim_id = &"defend"
			BeatPlan.ActionRole.SPECIAL:
				anim_id = SpriteSetData.MOVE
				move_name = plan.move_name
			_:
				anim_id = &"attack"
	elif plan != null and plan.reactions.get(c, -1) in [BeatPlan.Reaction.HIT, BeatPlan.Reaction.KNOCKOUT]:
		anim_id = &"hit"
	else:
		var shown: CombatantDisplay = _replay.get_display(c) if _replay != null else null
		if shown != null and shown.hp <= 0:
			anim_id = &"knockout"
			hold_last = true
		elif shown != null and shown.is_defending:
			anim_id = &"defend"
			hold_last = true
	var r: SpriteSetData.Resolution = _sets[c].resolve(anim_id, facing, move_name, func(_m: String) -> void: pass)
	if r.animation == null:
		return
	var anim: SpriteAnimationData = r.animation
	var frame: int = frame_at(anim, seconds)
	if hold_last:
		frame = anim.land_frame if anim.land_frame >= 0 else anim.frame_count() - 1
	_sprites[c].show_frame(SpriteSetData.clip_id(anim.animation_id, anim.move_name), anim.facing,
			r.mirrored, anim.no_mirror, frame)


## The frame `seconds` into `anim` at 1x: looping for `idle`, else held on
## the last frame once it ends.
static func frame_at(anim: SpriteAnimationData, seconds: float) -> int:
	var total: float = anim.duration_seconds()
	if anim.frame_count() == 0 or total <= 0.0:
		return 0
	var t: float = fposmod(seconds, total) if anim.animation_id == &"idle" else seconds
	for i: int in range(anim.frame_count() - 1, -1, -1):
		if t >= anim.seconds_before(i):
			return i
	return 0


func _spawn(c: Combatant, slot: int, catalog: ContentCatalogService,
		sprite_sets: Dictionary[StringName, SpriteSetData]) -> void:
	if _battle_stage == null or slot >= _battle_stage.slots.size():
		push_warning("BattleView: no stage slot %d for %s" % [slot, c.display_name])
		return
	var set_id := StringName(_sprite_set_id(c, catalog))
	var sprite_set: SpriteSetData = sprite_sets.get(set_id) as SpriteSetData
	if sprite_set == null:
		push_warning("BattleView: %s has no sprite set '%s'" % [c.display_name, set_id])
		return
	var sprite := CharacterSprite.new()
	sprite.name = "%s%d" % ["Enemy" if c.is_enemy else "Squad", slot]
	var mat := ShaderMaterial.new()
	mat.shader = sprite_shader
	sprite.material_override = mat
	sprite.layers = DioramaStage.LAYER_ACTORS
	sprite.card_camera = stage.camera if stage != null else null
	sprite.position = _battle_stage.slot_anchor(slot)
	if actor_root != null:
		actor_root.add_child(sprite)
	sprite.setup(sprite_set.build_sprite_frames(), _config)
	_sprites[c] = sprite
	_sets[c] = sprite_set
	if stage != null:
		var blob: MeshInstance3D = stage.make_blob_shadow()
		blob.name = "%sShadow" % sprite.name
		stage.add_child(blob)
		_shadows[c] = blob
		_place_shadow(c)
	_show(c, null)


static func _sprite_set_id(c: Combatant, catalog: ContentCatalogService) -> String:
	if c.record_id.is_empty() or catalog == null:
		return ""
	var rec: Resource = catalog.get_record(&"enemy" if c.is_enemy else &"character", c.record_id)
	return str(rec.get(&"sprite_set_id")) if rec != null else ""


func _try_configure_camera() -> void:
	if _camera_configured or _battle_stage == null or stage == null or not is_inside_tree():
		return
	stage.configure_battle_camera(_battle_stage, _config, get_viewport().size)
	_camera_configured = true


## Metres per screen pixel at view depth `z` under the level battle camera
## (`z / f_px`), at the current window; 0 before the camera is configured.
func _metres_per_px(z: float) -> float:
	if _config == null or not is_inside_tree():
		return 0.0
	var vp: Vector2i = get_viewport().size
	if vp.y <= 0:
		return 0.0
	var f: float = BattleFraming.f_px(_config.battle_fov_degrees, float(vp.x) / float(vp.y), vp.y)
	return z / f if f > 0.0 else 0.0


## Screen pixels per texel (`T`, ADR-0005 §2) at the current window.
func _texel_px() -> int:
	if _config == null or not is_inside_tree():
		return 1
	return maxi(1, get_viewport().size.y / _config.texel_base_lines)


func _place_shadow(c: Combatant) -> void:
	var blob: MeshInstance3D = _shadows.get(c) as MeshInstance3D
	if blob == null:
		return
	var sprite: CharacterSprite = _sprites[c]
	var width_m: float = float(_config.shadow_width_texels * _texel_px()) * _metres_per_px(-sprite.position.z)
	blob.visible = width_m > 0.0
	if blob.visible:
		stage.place_blob_shadow(blob, sprite.position, width_m, _config.shadow_offset)


## Starts an impact burst on every reactor the beat hits (rule 9's impact).
## Each burst asks the flash gate first (`vfx_impact_burst`, gated); a
## refusal -- the flash limit, or Reduce Flashing On -- plays the capped
## variant. The burst plays on this view's mode time at 1x.
func _on_beat_impact(plan: BeatPlan) -> void:
	if _burst_set == null:
		return
	for c: Combatant in plan.reactions:
		if plan.reactions[c] in [BeatPlan.Reaction.HIT, BeatPlan.Reaction.KNOCKOUT] and _sprites.has(c):
			_spawn_burst(c, not burst_allowed())


## Asks the gate for one impact burst: true plays the full variant. No gate
## (tests, capture) always allows.
func burst_allowed() -> bool:
	if flash_gate == null:
		return true
	return flash_gate.request(IMPACT_BURST_SOURCE, func() -> float: return _mode_time, 1.0) != FlashGate.REFUSED


## `frames` with every texel's colour mixed `mix` of the way to `tint`,
## alpha untouched: the capped variant.
static func capped_frames(frames: SpriteFrames, tint: Color, mix: float) -> SpriteFrames:
	var out := SpriteFrames.new()
	if out.has_animation(&"default"):
		out.remove_animation(&"default")
	for clip: StringName in frames.get_animation_names():
		out.add_animation(clip)
		out.set_animation_speed(clip, frames.get_animation_speed(clip))
		out.set_animation_loop(clip, frames.get_animation_loop(clip))
		for i: int in frames.get_frame_count(clip):
			var img: Image = frames.get_frame_texture(clip, i).get_image()
			img.convert(Image.FORMAT_RGBA8)
			for y: int in img.get_height():
				for x: int in img.get_width():
					var px: Color = img.get_pixel(x, y)
					var c: Color = px.lerp(tint, mix)
					img.set_pixel(x, y, Color(c.r, c.g, c.b, px.a))
			out.add_frame(clip, ImageTexture.create_from_image(img), frames.get_frame_duration(clip, i))
	return out


func _spawn_burst(target: Combatant, capped: bool) -> void:
	var target_sprite: CharacterSprite = _sprites[target]
	var burst := CharacterSprite.new()
	burst.name = "Burst%d" % _bursts.size()
	var mat := ShaderMaterial.new()
	mat.shader = sprite_shader
	burst.material_override = mat
	burst.layers = DioramaStage.LAYER_ACTORS
	burst.card_camera = stage.camera if stage != null else null
	# Centre the 32-texel burst on the target's frame: lift its foot anchor
	# by (frame height - burst height) / 2 texels, in metres at that depth.
	var anim: SpriteAnimationData = _sets[target].find(&"idle", ENEMY_FACING if target.is_enemy else SQUAD_FACING)
	var frame_h: int = anim.frame_region(0).size.y if anim != null else 64
	var burst_h: int = _burst_set.animations[0].frame_region(0).size.y
	var z: float = -target_sprite.position.z - VFX_DEPTH_BIAS
	var lift_m: float = float((frame_h - burst_h) / 2 * _texel_px()) * _metres_per_px(z)
	burst.position = Vector3(target_sprite.position.x, lift_m, -z)
	if actor_root != null:
		actor_root.add_child(burst)
	burst.setup(_burst_frames_capped if capped else _burst_frames, _config)
	burst.show_frame(&"vfx", ENEMY_FACING, false, false, 0)
	_bursts[burst] = 0.0


func _step_bursts(delta: float) -> void:
	for burst: CharacterSprite in _bursts.keys():
		var t: float = _bursts[burst] + delta
		var anim: SpriteAnimationData = _burst_set.animations[0]
		if t >= anim.duration_seconds():
			_bursts.erase(burst)
			burst.queue_free()
			continue
		_bursts[burst] = t
		burst.show_frame(&"vfx", ENEMY_FACING, false, false, frame_at(anim, t))


## The impact burst as a one-animation set (`vfx_front`), or null when the
## strip is not shipped.
static func _make_burst_set() -> SpriteSetData:
	if not ResourceLoader.exists(IMPACT_BURST_PATH):
		return null
	var strip: Texture2D = load(IMPACT_BURST_PATH)
	var anim := SpriteAnimationData.new()
	anim.animation_id = &"vfx"
	anim.facing = ENEMY_FACING
	anim.fps = IMPACT_BURST_FPS
	var frames := PackedFloat32Array()
	frames.resize(strip.get_width() / strip.get_height())
	frames.fill(1.0)
	anim.frame_durations = frames
	anim.strip = strip
	var s := SpriteSetData.new()
	s.set_id = &"vfx_impact_burst"
	s.animations.append(anim)
	return s


## Rule 8: the punch moves the whole view by the same whole pixels. The 3D
## view moves by lens shift; the backdrop is a canvas layer, so its layer
## takes the same offset (oversized in the scene so no edge shows).
func _follow_punch() -> void:
	if backdrop == null or stage == null:
		return
	var layer := backdrop.get_parent() as CanvasLayer
	if layer != null:
		layer.offset = Vector2(stage.punch_offset_px())
