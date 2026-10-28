## Pinned record-only field values for the content-migration epic's migrated
## `.tres` records (ADR-0001 Migration Step 2 and later). Shared across
## stories 013-019; each story adds only its own block below. Not gated by
## story 009's characterization-regression gate (that gate covers the
## characterization seam's pinned behaviour, not these authored records).
## Identity colours are not duplicated here -- they are asserted against the
## already-frozen `CharacterizationExpected.*_IDENTITY_COLOR_HTML`.
##
## Usage example:
## [codeblock]
## var faction: FactionData = ResourceLoader.load(
##         "res://data/factions/faction_bureaucratia.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
## assert(faction.base_shape == MigratedRecordsExpected.BUREAUCRATIA_BASE_SHAPE)
## [/codeblock]
class_name MigratedRecordsExpected
extends RefCounted

# --- Story 013: faction_bureaucratia, faction_megacorp ---

const BUREAUCRATIA_ID: String = "faction_bureaucratia"
const MEGACORP_ID: String = "faction_megacorp"

const ALIEN_KIND: String = "alien"

const BUREAUCRATIA_BASE_SHAPE: String = "square"
const MEGACORP_BASE_SHAPE: String = "wedge"

const BUREAUCRATIA_DISPLAY_NAME: String = "Bureaucratia"
const MEGACORP_DISPLAY_NAME: String = "MegaCorp"

const BUREAUCRATIA_RULE_ID: String = "rule_bureaucratia_permit"
const MEGACORP_RULE_ID: String = "rule_megacorp_billing"

const BUREAUCRATIA_BACKUP_ICON_ID: String = "icon_faction_bureaucratia"
const MEGACORP_BACKUP_ICON_ID: String = "icon_faction_megacorp"

## Compliance Clerk per the overworld GDD; MegaCorp has no shipped patrol (Q9).
const BUREAUCRATIA_PATROL_ARCHETYPE_ID: String = "patrol_compliance_clerk"
const MEGACORP_PATROL_ARCHETYPE_ID: String = ""

# --- Story 014: the nine enemy named-attack moves ---

## Every named-attack move id (ADR-0001 Migration Step 2).
const NAMED_ATTACK_IDS: PackedStringArray = [
	"move_pen_jab", "move_red_tape", "move_late_fee", "move_mass_audit", "move_final_notice",
	"move_laser_scan", "move_upsell", "move_layoffs", "move_hostile_takeover",
]

const NAMED_ATTACK_TARGET_TYPE: String = "single_enemy"
const NAMED_ATTACK_COST: int = 0
const NAMED_ATTACK_EFFECT_TYPE: String = "damage"

## move id -> {display_name, power}, read once from today's shipped
## `_named_attack()` calls (`bureaucratia.gd`, `megacorp.gd`) and copied as
## literals -- never a reference to those files' own `const`s (ADR-0001
## Step 0 rationale: a vacuous pass that breaks silently once story 030
## deletes them).
const NAMED_ATTACKS: Dictionary = {
	"move_pen_jab": {"display_name": "Pen Jab", "power": 5},
	"move_red_tape": {"display_name": "Red Tape", "power": 10},
	"move_late_fee": {"display_name": "Late Fee", "power": 16},
	"move_mass_audit": {"display_name": "Mass Audit", "power": 8},
	"move_final_notice": {"display_name": "Final Notice", "power": 18},
	"move_laser_scan": {"display_name": "Laser Scan", "power": 11},
	"move_upsell": {"display_name": "Upsell", "power": 6},
	"move_layoffs": {"display_name": "Layoffs", "power": 8},
	"move_hostile_takeover": {"display_name": "Hostile Takeover", "power": 18},
}

# --- Story 015 (merged with 016): the five Bureaucratia/MegaCorp enemies ---
# Record ids, stat blocks, display names and is_boss are already frozen in
# `CharacterizationExpected.ENEMY_IDS` / `ENEMY_STATS` (story 003) -- only the
# record-only fields (faction_id, move_ids, reward, sprite_set_id) go here.

const ENEMY_SPRITE_SET_ID: String = "sprite_placeholder"
const ENEMY_AI_PROFILE_ID: String = ""
const ENEMY_REWARD_XP: int = 0
const ENEMY_REWARD_MONEY: int = 0

## enemy id -> faction id and the AI's reachable move_ids, in the shipped
## rule's branch order (the rule's own params, story 017, decide which one is
## used; the AI never reads `move_ids`).
const ENEMY_FACTION_AND_MOVES: Dictionary = {
	"enemy_clerk": {"faction_id": "faction_bureaucratia",
			"move_ids": ["move_pen_jab", "move_red_tape", "move_late_fee"]},
	"enemy_supervisor": {"faction_id": "faction_bureaucratia",
			"move_ids": ["move_pen_jab", "move_red_tape", "move_mass_audit", "move_final_notice"]},
	"enemy_security_drone": {"faction_id": "faction_megacorp",
			"move_ids": ["move_laser_scan"]},
	"enemy_middle_manager": {"faction_id": "faction_megacorp",
			"move_ids": ["move_upsell"]},
	"enemy_ceo": {"faction_id": "faction_megacorp",
			"move_ids": ["move_layoffs", "move_hostile_takeover"]},
}

# --- Story 017: rule_bureaucratia_permit, rule_megacorp_billing ---

const BUREAUCRATIA_RULE_CLASS: StringName = &"bureaucratia_permit"
const MEGACORP_RULE_CLASS: StringName = &"megacorp_billing"

const BUREAUCRATIA_RULE_PARAMS: Dictionary = {
	"permit_rounds": 3,
	"low_hp_threshold": 0.5,
	"hunker_jab_move": "move_pen_jab",
	"focus_attack_move": "move_red_tape",
	"late_fee_move": "move_late_fee",
	"mass_audit_move": "move_mass_audit",
	"final_notice_move": "move_final_notice",
}
const MEGACORP_RULE_PARAMS: Dictionary = {
	"bill_mp": 1,
	"laser_scan_move": "move_laser_scan",
	"upsell_move": "move_upsell",
	"layoffs_move": "move_layoffs",
	"hostile_takeover_move": "move_hostile_takeover",
	"role.enemy_security_drone": "laser_scan",
	"role.enemy_middle_manager": "upsell",
}

## Compared as a set (order not pinned).
const BUREAUCRATIA_RULE_REF_IDS: PackedStringArray = [
	"move_pen_jab", "move_red_tape", "move_late_fee", "move_mass_audit", "move_final_notice",
	"enemy_clerk", "enemy_supervisor",
]
const MEGACORP_RULE_REF_IDS: PackedStringArray = [
	"move_laser_scan", "move_upsell", "move_layoffs", "move_hostile_takeover",
	"enemy_security_drone", "enemy_middle_manager", "enemy_ceo",
]

const BUREAUCRATIA_RULE_TEXT_KEYS: PackedStringArray = [
	"banner_locked_one", "banner_locked_other", "banner_unlocked", "tooltip_locked", "tooltip_unlocked",
]
const MEGACORP_RULE_TEXT_KEYS: PackedStringArray = ["banner", "tooltip", "note_suspended"]
const BUREAUCRATIA_RULE_COLOR_KEYS: PackedStringArray = ["banner_unlocked"]

# --- Story 018 (merged with 019): the five squad specials and four characters ---
# Display names and mp costs are already frozen in `CharacterizationExpected.SPECIALS`
# / `SQUAD_*` (story 002) -- only the record-only values go here: the literal
# descriptor dict as the `.tres` stores it, target_type strings and move_ids.

const SPECIAL_MOVE_IDS: PackedStringArray = [
	"move_speak_to_the_manager", "move_family_meal", "move_appetizer", "move_viral_stunt", "move_home_run",
]

## move id -> {target_type (string, Content Data's own vocabulary, not
## Move.TargetType), effects (the single descriptor, exactly as authored --
## stun/damage_debuff carry no power key; story 028's adapter supplies 0)}.
const SPECIALS_RECORD_ONLY: Dictionary = {
	"move_speak_to_the_manager": {"target_type": "single_enemy", "effects": [{"type": "stun"}]},
	"move_family_meal": {"target_type": "self", "effects": [{"type": "heal_party", "power": 5}]},
	"move_appetizer": {"target_type": "single_ally", "effects": [{"type": "heal_single", "power": 10}]},
	"move_viral_stunt": {"target_type": "single_enemy", "effects": [{"type": "damage_debuff", "rounds": 2}]},
	"move_home_run": {"target_type": "single_enemy", "effects": [{"type": "direct_damage", "power": 18}]},
}

const CHARACTER_IDS: PackedStringArray = [
	"char_karen", "char_michelin_chef", "char_florida_man", "char_baguette_thrower",
]

## char id -> this character's starting move_ids (ADR-0001 Migration Step 4;
## Q1, approved: sourced from prototypes/battle-concept/battle.gd iteration 3,
## moved as-is). Stat blocks are the already-frozen `CharacterizationExpected.
## SQUAD_*` dicts, matched to these same ids by the test.
const CHARACTER_MOVE_IDS: Dictionary = {
	"char_karen": ["move_speak_to_the_manager"],
	"char_michelin_chef": ["move_appetizer", "move_family_meal"],
	"char_florida_man": ["move_viral_stunt"],
	"char_baguette_thrower": ["move_home_run"],
}

## Q1's sourceless fields (RC-3, QA's revised criterion): left empty, none in
## `CharacterData.REQUIRED_FIELDS`. `nation_id` stays empty rather than
## inventing a human_nation Faction with no source anywhere in the shipped
## code or the prototype -- unlike the squad's own stats, a nation would be
## pure invention, not "moved as-is". Flagged for technical-director review.
const CHARACTER_EMPTY_FIELDS: PackedStringArray = [
	"nation_id", "archetype_line", "signature_move_id", "sprite_set_id", "portrait_id",
]
