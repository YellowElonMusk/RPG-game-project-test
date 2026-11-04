## The Audio Manager's event ids and the pure rules that pick a context's
## music (systems index #20). Every id here has a row in
## `data/config/audio_events.tres`; the overworld's own six SFX ids are
## `OverworldSfx.ALL`.
class_name AudioIds
extends RefCounted

# -- SFX ----------------------------------------------------------------------
const UI_MOVE: StringName = &"ui_move"
const UI_CONFIRM: StringName = &"ui_confirm"
const UI_CANCEL: StringName = &"ui_cancel"
## The soft tick for a refused or early press (`UiFeedback.refused`).
const UI_REFUSED: StringName = &"ui_refused"
const UI_TEXT_BLIP: StringName = &"ui_text_blip"
const UI_SAVE: StringName = &"ui_save"
const UI_BUY: StringName = &"ui_buy"
const BT_ENCOUNTER_START: StringName = &"bt_encounter_start"
const BT_HIT: StringName = &"bt_hit"
## A big punch (a knockout, or the boss acting). The game has no critical
## hits, so `bt_crit` is listed for later but nothing fires it.
const BT_HIT_HEAVY: StringName = &"bt_hit_heavy"
const BT_CRIT: StringName = &"bt_crit"
const BT_HEAL: StringName = &"bt_heal"
const BT_KO_SQUAD: StringName = &"bt_ko_squad"
const BT_KO_ENEMY: StringName = &"bt_ko_enemy"
const BT_FLEE: StringName = &"bt_flee"
## The level-up chime on the results screen (an SFX, so the Victory sting
## on the Music bus keeps playing under it).
const BT_LEVEL_UP: StringName = &"bt_level_up"

# -- Music --------------------------------------------------------------------
const MUS_TITLE: StringName = &"mus_title"
const MUS_CREDITS: StringName = &"mus_credits"
const MUS_CAMP: StringName = &"mus_camp"
## Fights have no background music (user ruling, audio.md §0): the beatbox
## score is the fight's music. Until it exists this quiet floor pulse plays.
const BX_FLOOR_PULSE: StringName = &"bx_floor_pulse"
const STG_VICTORY: StringName = &"stg_victory"
const STG_VICTORY_BOSS: StringName = &"stg_victory_boss"
const STG_DEFEAT: StringName = &"stg_defeat"

# -- Ambience -----------------------------------------------------------------
const AMB_CAMP: StringName = &"amb_camp_cafe"

## The four map kinds a map id names (`map_<city>_<kind>[_placeholder]`).
const MAP_KINDS: PackedStringArray = ["boss_chamber", "town", "segment", "dungeon"]


## `{city, kind}` from a map id such as `map_paris_boss_chamber_placeholder`;
## both "" when the id does not follow the pattern.
static func parse_map_id(map_id: String) -> Dictionary:
	var rest: String = map_id.trim_prefix("map_").trim_suffix("_placeholder")
	if rest == map_id:
		return {"city": "", "kind": ""}
	for kind: String in MAP_KINDS:
		if rest.ends_with("_" + kind):
			return {"city": rest.trim_suffix("_" + kind), "kind": kind}
	return {"city": "", "kind": ""}


## The overworld music ids to try, most specific first: the city's own
## track for this map kind (or its liberated track), then the generic
## overworld track for the kind, then the generic town track.
## Example: `overworld_music("map_london_dungeon_placeholder", false)` ->
## `[mus_london_dungeon, mus_ow_dungeon, mus_ow_town]`.
static func overworld_music(map_id: String, liberated: bool) -> Array[StringName]:
	var parts: Dictionary = parse_map_id(map_id)
	var city: String = parts["city"]
	var kind: String = parts["kind"]
	var ids: Array[StringName] = []
	if liberated:
		if not city.is_empty():
			ids.append(StringName("mus_%s_liberated" % city))
		ids.append(&"mus_ow_liberated")
	if not city.is_empty():
		ids.append(StringName("mus_%s_%s" % [city, kind]))
	if not kind.is_empty():
		ids.append(StringName("mus_ow_%s" % kind))
	if not &"mus_ow_town" in ids:
		ids.append(&"mus_ow_town")
	return ids


## The victory sting for a won fight.
static func victory_sting(is_boss: bool) -> Array[StringName]:
	var ids: Array[StringName] = [STG_VICTORY]
	if is_boss:
		ids.push_front(STG_VICTORY_BOSS)
	return ids


## The SFX for one battle beat's impact, or &"" for none: a knockout beats
## a heal beats a hit; a big punch is the heavy hit.
static func beat_sfx(plan: BeatPlan) -> StringName:
	if plan == null:
		return &""
	if plan.knockout:
		for c: Variant in plan.reactions:
			if plan.reactions[c] == BeatPlan.Reaction.KNOCKOUT:
				return BT_KO_ENEMY if (c as Combatant).is_enemy else BT_KO_SQUAD
	for c: Variant in plan.reactions:
		if plan.reactions[c] == BeatPlan.Reaction.HEAL:
			return BT_HEAL
	if plan.punch:
		return BT_HIT_HEAVY if plan.big_punch else BT_HIT
	return &""


## The UI SFX for an input action pressed while a menu, overlay or battle
## has the input, or &"" for none.
static func ui_sfx(action: StringName) -> StringName:
	if action in [InputActions.NAV_UP, InputActions.NAV_DOWN, InputActions.NAV_LEFT,
			InputActions.NAV_RIGHT, InputActions.MOVE_UP, InputActions.MOVE_DOWN,
			InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT]:
		return UI_MOVE
	if action == InputActions.CONFIRM:
		return UI_CONFIRM
	if action == InputActions.CANCEL:
		return UI_CANCEL
	return &""
