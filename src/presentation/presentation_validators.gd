## Boot-time content validation for presentation data (ADR-0005 §9, "battle
## stages validated on load"; story 046; sprite sets, stories 018, 062, 066).
## Content-only: it runs over shipped `BattleStage` and `SpriteSetData`
## resources, never a live scene.
class_name PresentationValidators
extends RefCounted

## Where shipped battle stages live.
const STAGES_DIR := "res://data/presentation/stages"
## Where shipped sprite sets live (`SpriteSetData`, one `.tres` per set).
const SPRITE_SETS_DIR := "res://data/presentation/sprite_sets"
## The shipped `PresentationConfig`, when one exists (ADR-0005 §9).
const CONFIG_PATH := "res://data/presentation/presentation_config.tres"
## The explicit checkerboard stand-in (GDD rule 10); never a real set.
const PLACEHOLDER_SET_ID := "sprite_placeholder"
## Rule names each sprite-set error starts with.
const RULE_REQUIRED := "required_animations"
const RULE_IMPACT := "impact_frame"
const RULE_LAND := "land_frame"
const RULE_INTRO_LENGTH := "intro <= boss_hold"
const RULE_DUPLICATE_MOVE := "duplicate move animation"


## Loads every `BattleStage` `.tres` under `dir`, sorted by file name.
static func load_battle_stages(dir: String = STAGES_DIR) -> Array[BattleStage]:
	var out: Array[BattleStage] = []
	var names: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		var file_name: String = f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			names.append(file_name)
	names.sort()
	for file_name: String in names:
		var stage := load(dir.path_join(file_name)) as BattleStage
		if stage != null:
			out.append(stage)
	return out


## Validates every stage with `BattleFraming.validate` (which includes the
## same-depth check, AC-42) and returns every content error, each naming its
## stage; empty means every stage may be used.
static func validate_battle_stages(stages: Array[BattleStage],
		config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	for stage: BattleStage in stages:
		errors.append_array(BattleFraming.validate(stage, config))
	return errors

## Loads the shipped `PresentationConfig` (`CONFIG_PATH`), or its defaults
## when none is shipped yet.
static func load_config(path: String = CONFIG_PATH) -> PresentationConfig:
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path) as PresentationConfig
		if loaded != null:
			return loaded
	return PresentationConfig.new()


## Loads every `SpriteSetData` `.tres` under `dir`, keyed by `set_id`; empty
## when the directory does not exist.
static func load_sprite_sets(dir: String = SPRITE_SETS_DIR) -> Dictionary[StringName, SpriteSetData]:
	var out: Dictionary[StringName, SpriteSetData] = {}
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		var file_name: String = f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			var sprite_set := load(dir.path_join(file_name)) as SpriteSetData
			if sprite_set != null:
				out[sprite_set.set_id] = sprite_set
	return out


## Every boot content error for one sprite set (ADR-0005 §9, GDD rule 10),
## each starting with its `RULE_*` name and naming the set and animation:
## required animations per facing used (`victory` for squad sets, `intro`
## in `front` when `is_boss_set`), `impact_frame` on every action
## animation, `land_frame` on every `knockout`, `intro` no longer than
## `config.boss_hold` at 1x, and no duplicate move-specific names.
static func validate_sprite_set(sprite_set: SpriteSetData, config: PresentationConfig,
		is_boss_set: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(validate_required_animations(sprite_set, is_boss_set))
	errors.append_array(validate_frame_data(sprite_set, config))
	return errors


## Rule 10's required table only (stories 018, 062).
static func validate_required_animations(sprite_set: SpriteSetData, is_boss_set: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	for facing: StringName in sprite_set.facings_used:
		for anim_id: StringName in SpriteSetData.REQUIRED_BATTLE:
			if not sprite_set.has_in_facing(anim_id, facing):
				errors.append(_missing(sprite_set, anim_id, facing))
	if sprite_set.is_squad and not sprite_set.has_in_facing(SpriteSetData.VICTORY, SpriteSetData.VICTORY_FACING):
		errors.append(_missing(sprite_set, SpriteSetData.VICTORY, SpriteSetData.VICTORY_FACING))
	# Story 062: bosses face front for the takeover, so only an authored
	# front intro counts (a mirrored back intro is not one).
	if is_boss_set and sprite_set.find(SpriteSetData.INTRO, SpriteSetData.INTRO_FACING) == null:
		errors.append(_missing(sprite_set, SpriteSetData.INTRO, SpriteSetData.INTRO_FACING))
	return errors


## Frame-data rules only (story 066): `impact_frame`, `land_frame`, `intro`
## length vs `config.boss_hold`, duplicate move names (per facing).
static func validate_frame_data(sprite_set: SpriteSetData, config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_moves: Dictionary[String, bool] = {}
	for anim: SpriteAnimationData in sprite_set.animations:
		if anim == null:
			continue
		var label: String = SpriteSetData.label_for(anim.animation_id, anim.move_name)
		if anim.is_action() and anim.impact_seconds() < 0.0:
			errors.append("%s -- sprite set %s, animation %s (%s): impact_frame %d not in 0..%d" % [
					RULE_IMPACT, sprite_set.set_id, label, anim.facing, anim.impact_frame, anim.frame_count() - 1])
		if anim.animation_id == &"knockout" and anim.land_seconds() < 0.0:
			errors.append("%s -- sprite set %s, animation %s (%s): land_frame %d not in 0..%d" % [
					RULE_LAND, sprite_set.set_id, label, anim.facing, anim.land_frame, anim.frame_count() - 1])
		if anim.animation_id == SpriteSetData.INTRO \
				and anim.duration_seconds() > config.boss_hold + PresentationConfig.RULE_EPSILON:
			errors.append("%s -- sprite set %s, animation %s (%s): %.3f s > boss_hold %.3f s" % [
					RULE_INTRO_LENGTH, sprite_set.set_id, label, anim.facing,
					anim.duration_seconds(), config.boss_hold])
		if anim.animation_id == SpriteSetData.MOVE:
			var key: String = "%s|%s" % [anim.move_name, anim.facing]
			if seen_moves.has(key):
				errors.append("%s -- sprite set %s, animation %s (%s) keyed twice" % [
						RULE_DUPLICATE_MOVE, sprite_set.set_id, label, anim.facing])
			seen_moves[key] = true
	return errors


## A catalog record validator (ADR-0004 `register_record_validator`) for a
## `character` or `enemy` record: when its `sprite_set_id` names a set in
## `sets`, every `validate_sprite_set` error becomes one error on field
## `sprite_set_id`. A boss set is an `is_boss` enemy's set. Unknown ids and
## `sprite_placeholder` pass here (`sprite_set_exists` is story 030).
static func make_record_validator(sets: Dictionary[StringName, SpriteSetData],
		config: PresentationConfig) -> Callable:
	return func(record: Resource) -> Array:
		var out: Array = []
		var set_id := StringName(str(record.get(&"sprite_set_id")))
		if set_id == &"" or String(set_id) == PLACEHOLDER_SET_ID or not sets.has(set_id):
			return out
		var is_boss_set: bool = record is EnemyData and (record as EnemyData).is_boss
		for e: String in validate_sprite_set(sets[set_id], config, is_boss_set):
			out.append({"severity": &"error", "field": "sprite_set_id", "message": e})
		return out


## Registers the sprite-set validators on `catalog` for `character` and
## `enemy` records (ADR-0005 §9 via ADR-0004). Must run before `load_all()`.
static func register_sprite_set_validators(catalog: ContentCatalogService,
		sets: Dictionary[StringName, SpriteSetData], config: PresentationConfig) -> void:
	var validator: Callable = make_record_validator(sets, config)
	catalog.register_record_validator(&"character", validator)
	catalog.register_record_validator(&"enemy", validator)


static func _missing(sprite_set: SpriteSetData, anim_id: StringName, facing: StringName) -> String:
	return "%s -- sprite set %s is missing required animation %s (%s)" % [
			RULE_REQUIRED, sprite_set.set_id, anim_id, facing]
