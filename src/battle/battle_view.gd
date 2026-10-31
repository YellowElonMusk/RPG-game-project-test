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


## Builds the sprites and backdrop for `battle`. Call once, from
## `BattleMode.setup()` (before or after entering the tree). `catalog`
## resolves each combatant's record (`record_id`) to its `sprite_set_id`;
## `sprite_sets` defaults to the shipped sets.
func setup(battle: BattleCore, replay: BattleReplayController, descriptor: EncounterDescriptor,
		config: PresentationConfig, catalog: ContentCatalogService = null,
		sprite_sets: Dictionary[StringName, SpriteSetData] = {}) -> void:
	_config = config
	_replay = replay
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


func _ready() -> void:
	_try_configure_camera()


func _process(delta: float) -> void:
	_mode_time += delta
	present()


## One presentation frame: every sprite's frame for the current replay state.
## Public so capture tools can drive it.
func present() -> void:
	var plan: BeatPlan = _replay.get_current_plan() if _replay != null else null
	for c: Combatant in _sprites:
		_show(c, plan)


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
