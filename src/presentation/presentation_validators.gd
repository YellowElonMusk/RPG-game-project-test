## Boot-time content validation for presentation data (ADR-0005 §9, "battle
## stages validated on load"; story 046; sprite sets, stories 018, 062, 066;
## flash sources, story 059). Content-only: it runs over shipped
## `BattleStage`, `SpriteSetData` and `FlashSourceDecl` resources, never a
## live scene.
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

## Where shipped flash source declarations live (`FlashSourceDecl`).
const FLASH_SOURCES_DIR := "res://data/presentation/flash_sources"
## Every flash-capable source the GDD lists (rule 13 "Flash limit"; AC-55):
## this system's victory burst, boss flood, attack and comedy VFX and the
## dusk starfield; Game State's retry flash, wipes and fade; the UI's Menu
## backdrop, Defeat stamp and results opening (ADR-0008 §8); camp flicker.
const REQUIRED_FLASH_SOURCES: Array[StringName] = [
	&"victory_burst", &"boss_flood",
	&"vfx_impact_burst", &"vfx_faction_stamp", &"vfx_confetti", &"vfx_hit_spark",
	&"dusk_starfield", &"campfire_flicker",
	&"retry_flash", &"battle_wipe", &"battle_wipe_reverse", &"fade",
	&"ui_menu_backdrop_open", &"ui_menu_backdrop_close", &"ui_defeat_stamp", &"ui_results_open",
]
## Rule names each flash-source error starts with.
const RULE_FLASH_COVERAGE := "flash source declared"
const RULE_FLASH_CLASS := "flash class"
const RULE_FLASH_CLOCK := "flash clock named"
const RULE_FLASH_TRANSITIONS := "flash transitions"
const RULE_FLASH_CAPPED := "capped variant"
const RULE_FLASH_EXEMPT_AREA := "exempt by area"
const RULE_FLASH_EXEMPT_SWING := "exempt by swing"
const RULE_FLASH_RESERVED := "reserved sequence within flash_rate_max"


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
## `sprite_placeholder` pass here (`sprite_set_exists`, story 034, checks them).
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


## Rule name of the boss-preset existence check (story 032, AC-28).
const RULE_BOSS_PROFILE_EXISTS := "boss_profile_exists"
## Where a content root keeps its lighting-profile table (ADR-0005 §5).
const PROFILES_SUBDIR := "presentation/profiles"


## `boss_<faction>` for faction record id `faction_<faction>` (ADR-0005 §3).
static func boss_profile_id(faction_id: String) -> StringName:
	return StringName("boss_" + faction_id.trim_prefix("faction_"))


## Every lighting-profile id under `dir` (file base names), as a set; empty
## when `dir` does not exist.
static func load_profile_ids(dir: String) -> Dictionary:
	var ids: Dictionary = {}
	if not DirAccess.dir_exists_absolute(dir):
		return ids
	for f: String in DirAccess.get_files_at(dir):
		var file_name: String = f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			ids[StringName(file_name.get_basename())] = true
	return ids


## A `faction` record validator: an alien faction whose `boss_<faction>`
## profile is not in `profile_ids` is one error on field `id` (ADR-0005 §9).
static func make_boss_profile_validator(profile_ids: Dictionary) -> Callable:
	return func(record: Resource) -> Array:
		var out: Array = []
		if str(record.get(&"kind")) != "alien":
			return out
		var faction_id: String = str(record.get(&"id"))
		var boss_id: StringName = boss_profile_id(faction_id)
		if not profile_ids.has(boss_id):
			out.append({"severity": &"error", "field": "id", "message":
					"%s -- alien faction %s has no lighting preset %s" % [
						RULE_BOSS_PROFILE_EXISTS, faction_id, boss_id]})
		return out


## Rule name of the sprite-set existence check (story 034, AC-30).
const RULE_SPRITE_SET_EXISTS := "sprite_set_exists"
## Where a content root keeps its sprite-set table (ADR-0005 §5).
const SPRITE_SETS_SUBDIR := "presentation/sprite_sets"


## A `character`/`enemy` record validator: a non-empty `sprite_set_id` that
## is neither in `set_ids` nor the reserved checkerboard `PLACEHOLDER_SET_ID`
## is one error on field `sprite_set_id`, naming the record (ADR-0005 §9).
## An empty id is left to the catalog's own field checks.
static func make_sprite_set_exists_validator(set_ids: Dictionary) -> Callable:
	return func(record: Resource) -> Array:
		var out: Array = []
		var set_id: String = str(record.get(&"sprite_set_id"))
		if set_id.is_empty() or set_id == PLACEHOLDER_SET_ID or set_ids.has(StringName(set_id)):
			return out
		out.append({"severity": &"error", "field": "sprite_set_id", "message":
				"%s -- %s names unknown sprite set %s" % [
					RULE_SPRITE_SET_EXISTS, str(record.get(&"id")), set_id]})
		return out


## Registers the presentation existence validators for `data_root` (ADR-0005
## §9). A table lives beside the records under the same root
## (`<data_root>/presentation/...`); a root without that table (a content-data
## fixture with no presentation half) gets no existence check for it. Must run
## before `load_all()`.
static func register_existence_validators(catalog: ContentCatalogService, data_root: String) -> void:
	var profiles_dir: String = data_root.path_join(PROFILES_SUBDIR)
	if DirAccess.dir_exists_absolute(profiles_dir):
		catalog.register_record_validator(&"faction",
				make_boss_profile_validator(load_profile_ids(profiles_dir)))
	var sets_dir: String = data_root.path_join(SPRITE_SETS_SUBDIR)
	if DirAccess.dir_exists_absolute(sets_dir):
		var set_ids: Dictionary = {}
		for id: StringName in load_sprite_sets(sets_dir).keys():
			set_ids[id] = true
		var exists: Callable = make_sprite_set_exists_validator(set_ids)
		catalog.register_record_validator(&"character", exists)
		catalog.register_record_validator(&"enemy", exists)


static func _missing(sprite_set: SpriteSetData, anim_id: StringName, facing: StringName) -> String:
	return "%s -- sprite set %s is missing required animation %s (%s)" % [
			RULE_REQUIRED, sprite_set.set_id, anim_id, facing]


## Loads every `FlashSourceDecl` `.tres` under `dir`, sorted by file name.
static func load_flash_sources(dir: String = FLASH_SOURCES_DIR) -> Array[FlashSourceDecl]:
	var out: Array[FlashSourceDecl] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		var file_name: String = f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			names.append(file_name)
	names.sort()
	for file_name: String in names:
		var decl := load(dir.path_join(file_name)) as FlashSourceDecl
		if decl != null:
			out.append(decl)
	return out


## Every boot content error for the flash source declarations (ADR-0005 §9,
## §12; story 059, AC-55), each starting with its `RULE_FLASH_*` name and
## naming the source: every id in `required` declared exactly once; a legal
## class and a named clock; well-formed transitions; a gated source's capped
## variant with no general and no red transition, or below `flash_area_min`;
## an area-exempt source whose declared and transition areas stay below
## `flash_area_min`; a swing-exempt source with no transitions and a peak
## swing below the thresholds; a reserved source's sequence within
## `flash_rate_max` at 1x, `battle_speed_mult` and `ff_mult`.
static func validate_flash_sources(decls: Array[FlashSourceDecl], config: PresentationConfig,
		required: Array[StringName] = REQUIRED_FLASH_SOURCES) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for decl: FlashSourceDecl in decls:
		if seen.has(decl.source_id):
			errors.append("%s -- flash source %s is declared twice" % [RULE_FLASH_COVERAGE, decl.source_id])
		seen[decl.source_id] = true
		errors.append_array(validate_flash_source(decl, config))
	for id: StringName in required:
		if not seen.has(id):
			errors.append("%s -- flash source %s has no declaration" % [RULE_FLASH_COVERAGE, id])
	return errors


## The content errors for one declaration (see `validate_flash_sources`).
static func validate_flash_source(decl: FlashSourceDecl, config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var id: StringName = decl.source_id
	if not FlashSourceDecl.CLASSES.has(decl.flash_class):
		errors.append("%s -- flash source %s: unknown class '%s'" % [RULE_FLASH_CLASS, id, decl.flash_class])
	if not FlashSourceDecl.CLOCKS.has(decl.clock):
		errors.append("%s -- flash source %s: clock '%s' is not mode, replay or real" % [
				RULE_FLASH_CLOCK, id, decl.clock])
	var previous: float = -INF
	for t: FlashTransition in decl.transitions:
		if t == null or t.offset < 0.0 or t.offset < previous or t.area <= 0.0 or t.area > 1.0:
			errors.append("%s -- flash source %s: a transition is null, negative, out of offset order or has area outside (0, 1]" % [
					RULE_FLASH_TRANSITIONS, id])
			break
		previous = t.offset
	var needs_transitions: bool = decl.flash_class == FlashSourceDecl.CLASS_GATED \
			or decl.flash_class == FlashSourceDecl.CLASS_RESERVED
	if needs_transitions and decl.transitions.is_empty():
		errors.append("%s -- flash source %s: a %s source declares no transitions" % [
				RULE_FLASH_TRANSITIONS, id, decl.flash_class])
	match decl.flash_class:
		FlashSourceDecl.CLASS_GATED:
			# A luminance-only cap is not a cap (GDD `flash_gate` "Capped variants").
			var below_thresholds: bool = decl.capped_luma_swing < config.flash_luma_delta \
					and decl.capped_red_change <= FlashSourceDecl.RED_CHANGE_MAX
			if not below_thresholds \
					and decl.capped_area >= config.flash_area_min - PresentationConfig.RULE_EPSILON:
				errors.append("%s -- flash source %s: swing %.3f, red change %.1f over area %.2f is still a flash" % [
						RULE_FLASH_CAPPED, id, decl.capped_luma_swing, decl.capped_red_change, decl.capped_area])
		FlashSourceDecl.CLASS_EXEMPT_AREA:
			var widest: float = decl.max_area
			for t: FlashTransition in decl.transitions:
				if t != null:
					widest = maxf(widest, t.area)
			if widest > decl.max_area \
					or decl.max_area >= config.flash_area_min - PresentationConfig.RULE_EPSILON:
				errors.append("%s -- flash source %s: area %.3f is not below flash_area_min %.2f (declared max %.3f)" % [
						RULE_FLASH_EXEMPT_AREA, id, widest, config.flash_area_min, decl.max_area])
		FlashSourceDecl.CLASS_EXEMPT_SWING:
			if not decl.transitions.is_empty() or decl.peak_luma_swing >= config.flash_luma_delta \
					or decl.peak_red_change > FlashSourceDecl.RED_CHANGE_MAX:
				errors.append("%s -- flash source %s: swing %.3f, red change %.1f, %d transitions" % [
						RULE_FLASH_EXEMPT_SWING, id, decl.peak_luma_swing, decl.peak_red_change,
						decl.transitions.size()])
		FlashSourceDecl.CLASS_RESERVED:
			for speed: float in [1.0, config.battle_speed_mult, config.ff_mult]:
				var flashes: int = max_flashes_in_window(decl.transitions, speed)
				if flashes > config.flash_rate_max + PresentationConfig.RULE_EPSILON:
					errors.append("%s -- flash source %s: %d flashes in one second at %.2fx" % [
							RULE_FLASH_RESERVED, id, flashes, speed])
					break
	return errors


## The most flashes landing in any closed one-second window when
## `transitions` play at `speed` (GDD `flash_gate` "Counting": a transition
## is a flash when it opposes the one before it).
static func max_flashes_in_window(transitions: Array[FlashTransition], speed: float) -> int:
	var flash_lands: Array[float] = []
	for i: int in range(1, transitions.size()):
		if transitions[i] != null and transitions[i - 1] != null \
				and transitions[i].rising != transitions[i - 1].rising:
			flash_lands.append(transitions[i].offset / speed)
	flash_lands.sort()
	var best: int = 0
	for i: int in flash_lands.size():
		var count: int = 0
		for j: int in range(i, flash_lands.size()):
			if flash_lands[j] <= flash_lands[i] + 1.0 + PresentationConfig.RULE_EPSILON:
				count += 1
		best = maxi(best, count)
	return best
