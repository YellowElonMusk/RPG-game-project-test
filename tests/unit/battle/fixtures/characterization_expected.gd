## Pinned future record IDs and seeds for the content-migration epic's
## characterization tests (ADR-0001 Migration Step 0). Every value here is
## read once from today's shipped code and copied as a literal — never a
## reference to a factory's own `const` (a test that read
## `BureaucratiaRule.CLERK_MAX_HP` would pass vacuously and break silently
## when story 030 deletes it). Later Step 0 stories (002-008) add their own
## blocks of expected per-ID values below the ID lists; this story only
## builds the skeleton: the three ID lists `BattleContentSeam` resolves, and
## the seed constants characterization tests seed their `RandomNumberGenerator`
## from, so nothing here is ever time- or RNG-dependent.
##
## Usage example:
## [codeblock]
## for id in CharacterizationExpected.ENEMY_IDS:
##     var enemy: Combatant = BattleContentSeam.enemy(id)
## [/codeblock]
class_name CharacterizationExpected
extends RefCounted

## Bureaucratia's two enemy types, then MegaCorp's three (src/battle/factions/
## bureaucratia.gd, megacorp.gd).
const ENEMY_IDS: Array[String] = [
	"enemy_clerk", "enemy_supervisor",
	"enemy_security_drone", "enemy_middle_manager", "enemy_ceo",
]

## The 9 named attacks (Bureaucratia's 5, then MegaCorp's 4 — each rule's
## private `_named_attack()` calls, pinned by this story since neither rule
## exposes a move-by-ID lookup today), then the squad's 5 Specials
## (src/battle/squad/specials.gd). 14 total.
const MOVE_IDS: Array[String] = [
	"move_pen_jab", "move_red_tape", "move_late_fee", "move_mass_audit", "move_final_notice",
	"move_laser_scan", "move_upsell", "move_layoffs", "move_hostile_takeover",
	"move_speak_to_the_manager", "move_family_meal", "move_appetizer",
	"move_viral_stunt", "move_home_run",
]

## Bureaucratia's permit-ban rule, then MegaCorp's billing rule.
const RULE_IDS: Array[String] = ["rule_bureaucratia_permit", "rule_megacorp_billing"]

## Seeds later characterization tests pass to their `RandomNumberGenerator`,
## never a literal inline in the test itself, so every seeded test in this
## epic draws from one named place. Story 002 onward adds more as needed.
const SEED_A: int = 1
const SEED_B: int = 2
