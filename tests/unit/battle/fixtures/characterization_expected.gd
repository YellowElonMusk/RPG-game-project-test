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

## Story 005: reseeded fresh for every entry in `DAMAGE_CASES` (AC-1's own
## "reseed per case"), never a continuing sequence across cases.
const DAMAGE_SEED: int = 3

## Story 006: seeds the Bureaucratia hunker branch's `rng.randi_range()` jab
## target and the neutral `FactionRule`'s own random-target pick. Both are
## the first (and only) draw from this seed against the 4-member fixture
## squad in `SQUAD_KAREN, SQUAD_CHEF, SQUAD_FLORIDA_MAN, SQUAD_BAGUETTE_
## THROWER` order, which is why they land on the same squad index and the
## same resulting `rng.state` -- one draw from an identical seed, same
## reasoning as story 005's shared `DAMAGE_CASE_RNG_STATE`.
const RULE_SEED: int = 4
const PEN_JAB_TARGET_INDEX: int = 1
const NEUTRAL_TARGET_INDEX: int = 1
const RULE_RNG_STATE_AFTER_ONE_DRAW: int = -7485862620809337107

## Story 007: both rules' banner/tooltip text and colours (ADR-0011 §1/§5,
## before these move into `faction_rule`/`faction` records), pinned under the
## "en" locale. Strings are literal copies, including the exact em dash
## (U+2014) -- never a reference to either class's own string. Colours are
## the `Color.to_html(false)` lowercase hex form (no `#`).
const BUREAUCRATIA_BANNER_TEXT: Dictionary = {
	1: "BUREAUCRATIA — Special moves need a government permit. It arrives in 3 rounds. Attack and Defend only, for both sides.",
	2: "BUREAUCRATIA — Special moves need a government permit. It arrives in 2 rounds. Attack and Defend only, for both sides.",
	3: "BUREAUCRATIA — Special moves need a government permit. It arrives in 1 round. Attack and Defend only, for both sides.",
	4: "PERMIT GRANTED — All-out war! Special moves are allowed for both sides.",
}
const BUREAUCRATIA_TOOLTIP_TEXT: Dictionary = {
	1: "Bureaucratia requires a government permit before anyone can use a Special move. Attack and Defend only until it arrives.",
	2: "Bureaucratia requires a government permit before anyone can use a Special move. Attack and Defend only until it arrives.",
	3: "Bureaucratia requires a government permit before anyone can use a Special move. Attack and Defend only until it arrives.",
	4: "The permit arrived: Special moves are now allowed for both sides.",
}
const BUREAUCRATIA_BANNER_COLOR_HTML: Dictionary = {
	1: "d23a2e", 2: "d23a2e", 3: "d23a2e", 4: "b07a12",
}
const BUREAUCRATIA_IDENTITY_COLOR_HTML: String = "d23a2e"

const MEGACORP_BANNER_TEXT: String = "MEGACORP — Subscription billing. Every squad member pays 1 MP at the end of each round. At 0 MP you're SUSPENDED: basic Attack only."
const MEGACORP_TOOLTIP_TEXT: String = "MegaCorp bills every squad member 1 MP at the end of each round. Reaching 0 MP suspends you to basic Attack only until you have MP again."
const MEGACORP_IDENTITY_COLOR_HTML: String = "19c2d6"
const MEGACORP_SUSPENDED_NOTE: String = "SUSPENDED: out of MP. Basic Attack only until MP is regained."

## The neutral `FactionRule` fallback's identity colour, pinned as the
## control case (ADR-0011 §1 later changes this default -- out of scope here).
const NEUTRAL_IDENTITY_COLOR_HTML: String = "4a5a8a"

## Story 002: the squad's four named specialists, as the prototype built them
## (prototypes/battle-concept/battle.gd `_make_data()`). This is test fixture
## data, not migrated content — no production code defines these stat blocks
## (squad members have no factory today) — so there is no "factory const" this
## could vacuously reference; it is a literal copy of the prototype's values,
## read once.
const SQUAD_KAREN: Dictionary = {
	"name": "Karen", "max_hp": 34, "max_mp": 12, "attack": 12, "defense": 9, "speed": 11,
}
const SQUAD_CHEF: Dictionary = {
	"name": "Michelin Chef", "max_hp": 30, "max_mp": 14, "attack": 11, "defense": 7, "speed": 10,
}
const SQUAD_FLORIDA_MAN: Dictionary = {
	"name": "Florida Man", "max_hp": 38, "max_mp": 10, "attack": 14, "defense": 8, "speed": 12,
}
const SQUAD_BAGUETTE_THROWER: Dictionary = {
	"name": "Baguette Thrower", "max_hp": 32, "max_mp": 12, "attack": 15, "defense": 7, "speed": 13,
}

## Story 003 (merged story 004): the five enemies' stat blocks, pinned against
## today's `BureaucratiaRule`/`MegaCorpRule` factories, read once and copied as
## literals — never a reference to either class's consts (ADR-0001 Migration
## Step 0; ADR-0011 §5 turns these into `Enemy` records). Covers both the
## Bureaucratia roster (Clerk, Supervisor) and the MegaCorp roster (Security
## Drone, Middle Manager, CEO). `max_mp` is 0 for every enemy today.
const ENEMY_STATS: Dictionary = {
	"enemy_clerk": {
		"display_name": "Clerk", "max_hp": 40, "max_mp": 0,
		"attack": 11, "defense": 6, "speed": 8, "is_boss": false,
	},
	"enemy_supervisor": {
		"display_name": "Supervisor", "max_hp": 110, "max_mp": 0,
		"attack": 15, "defense": 10, "speed": 9, "is_boss": true,
	},
	"enemy_security_drone": {
		"display_name": "Security Drone", "max_hp": 36, "max_mp": 0,
		"attack": 12, "defense": 8, "speed": 10, "is_boss": false,
	},
	"enemy_middle_manager": {
		"display_name": "Middle Manager", "max_hp": 44, "max_mp": 0,
		"attack": 10, "defense": 6, "speed": 8, "is_boss": false,
	},
	"enemy_ceo": {
		"display_name": "CEO", "max_hp": 120, "max_mp": 0,
		"attack": 15, "defense": 10, "speed": 9, "is_boss": true,
	},
}

## Story 002: the five squad specials' Move fields, pinned against today's
## `SquadSpecials` factories (src/battle/squad/specials.gd), read once and
## copied as literals — never a reference to a `SquadSpecials` const, since
## ADR-0007 Migration Step 2 deletes the heal helpers those consts feed.
## `category`/`target_type`/`special_effect` reference `Move`'s own enums,
## not a deleted factory: `Move` is stable plumbing this epic does not touch.
const SPECIALS: Dictionary = {
	"move_speak_to_the_manager": {
		"display_name": "Speak to the Manager", "category": Move.Category.SPECIAL,
		"mp_cost": 4, "power": 0, "target_type": Move.TargetType.SINGLE_ENEMY,
		"special_effect": Move.SpecialEffect.STUN, "effect_rounds": 0,
	},
	"move_family_meal": {
		"display_name": "Family Meal", "category": Move.Category.SPECIAL,
		"mp_cost": 5, "power": 5, "target_type": Move.TargetType.SELF,
		"special_effect": Move.SpecialEffect.HEAL_PARTY, "effect_rounds": 0,
	},
	"move_appetizer": {
		"display_name": "Appetizer", "category": Move.Category.SPECIAL,
		"mp_cost": 3, "power": 10, "target_type": Move.TargetType.SINGLE_ALLY,
		"special_effect": Move.SpecialEffect.HEAL_SINGLE, "effect_rounds": 0,
	},
	"move_viral_stunt": {
		"display_name": "Viral Stunt", "category": Move.Category.SPECIAL,
		"mp_cost": 3, "power": 0, "target_type": Move.TargetType.SINGLE_ENEMY,
		"special_effect": Move.SpecialEffect.DAMAGE_DEBUFF, "effect_rounds": 2,
	},
	"move_home_run": {
		"display_name": "Home Run", "category": Move.Category.SPECIAL,
		"mp_cost": 4, "power": 18, "target_type": Move.TargetType.SINGLE_ENEMY,
		"special_effect": Move.SpecialEffect.DIRECT_DAMAGE, "effect_rounds": 0,
	},
}

## Story 005: the damage matrix, generated once by running every case below
## through BattleCore with a fresh rng.seed = DAMAGE_SEED (RC-2: via
## seam.scripted_rule(), never DamageCalculator.calculate_damage() directly),
## then frozen as literals and the one-off generator deleted -- never derived
## from BureaucratiaRule/MegaCorpRule/DamageCalculator consts. Every case
## draws exactly one random number from its own freshly-seeded generator (the
## tested hit; any filler action before it is deliberately RNG-free -- a
## self-heal or a Defend -- so rng.state afterward is the same single value
## for all 203 cases. This is not a copy/paste error: it is what "exactly one
## draw, same seed" means, and it still catches a pipeline bug that adds or
## removes a draw.
##
## "enemy_side": one entry per (enemy, move) pair, each a Dictionary of
## "<squad-key>:<state>" -> [hp_delta, target_hp] (state is "plain" or
## "defending"). "squad_side": one entry per (squad, move) pair, each
## "<enemy-id>:<state>" -> [hp_delta, target_hp] (state adds "vulnerable").
## Squad keys are the SQUAD_* blocks: karen, chef, florida_man,
## baguette_thrower. "move": "attack" means the generic power-10 Attack;
## any other string is a BattleContentSeam move id.
const DAMAGE_CASE_RNG_STATE: int = -5030687368022391725

const DAMAGE_CASES: Dictionary = {
	"enemy_side": [
		{"enemy": "enemy_clerk", "move": "move_pen_jab", "results": {
			"karen:plain": [-3, 31],
			"karen:defending": [-2, 32],
			"chef:plain": [-3, 27],
			"chef:defending": [-2, 28],
			"florida_man:plain": [-3, 35],
			"florida_man:defending": [-2, 36],
			"baguette_thrower:plain": [-3, 29],
			"baguette_thrower:defending": [-2, 30],
		}},
		{"enemy": "enemy_clerk", "move": "move_red_tape", "results": {
			"karen:plain": [-6, 28],
			"karen:defending": [-3, 31],
			"chef:plain": [-7, 23],
			"chef:defending": [-3, 27],
			"florida_man:plain": [-6, 32],
			"florida_man:defending": [-3, 35],
			"baguette_thrower:plain": [-7, 25],
			"baguette_thrower:defending": [-3, 29],
		}},
		{"enemy": "enemy_supervisor", "move": "move_pen_jab", "results": {
			"karen:plain": [-5, 29],
			"karen:defending": [-2, 32],
			"chef:plain": [-5, 25],
			"chef:defending": [-3, 27],
			"florida_man:plain": [-5, 33],
			"florida_man:defending": [-2, 36],
			"baguette_thrower:plain": [-5, 27],
			"baguette_thrower:defending": [-3, 29],
		}},
		{"enemy": "enemy_supervisor", "move": "move_red_tape", "results": {
			"karen:plain": [-9, 25],
			"karen:defending": [-5, 29],
			"chef:plain": [-10, 20],
			"chef:defending": [-5, 25],
			"florida_man:plain": [-10, 28],
			"florida_man:defending": [-5, 33],
			"baguette_thrower:plain": [-10, 22],
			"baguette_thrower:defending": [-5, 27],
		}},
		{"enemy": "enemy_clerk", "move": "move_late_fee", "results": {
			"karen:plain": [-10, 24],
			"karen:defending": [-5, 29],
			"chef:plain": [-11, 19],
			"chef:defending": [-5, 25],
			"florida_man:plain": [-10, 28],
			"florida_man:defending": [-5, 33],
			"baguette_thrower:plain": [-11, 21],
			"baguette_thrower:defending": [-5, 27],
		}},
		{"enemy": "enemy_supervisor", "move": "move_mass_audit", "results": {
			"karen:plain": [-7, 27],
			"karen:defending": [-4, 30],
			"chef:plain": [-8, 22],
			"chef:defending": [-4, 26],
			"florida_man:plain": [-8, 30],
			"florida_man:defending": [-4, 34],
			"baguette_thrower:plain": [-8, 24],
			"baguette_thrower:defending": [-4, 28],
		}},
		{"enemy": "enemy_supervisor", "move": "move_final_notice", "results": {
			"karen:plain": [-17, 17],
			"karen:defending": [-8, 26],
			"chef:plain": [-18, 12],
			"chef:defending": [-9, 21],
			"florida_man:plain": [-18, 20],
			"florida_man:defending": [-9, 29],
			"baguette_thrower:plain": [-18, 14],
			"baguette_thrower:defending": [-9, 23],
		}},
		{"enemy": "enemy_security_drone", "move": "move_laser_scan", "results": {
			"karen:plain": [-8, 26],
			"karen:defending": [-4, 30],
			"chef:plain": [-8, 22],
			"chef:defending": [-4, 26],
			"florida_man:plain": [-8, 30],
			"florida_man:defending": [-4, 34],
			"baguette_thrower:plain": [-8, 24],
			"baguette_thrower:defending": [-4, 28],
		}},
		{"enemy": "enemy_middle_manager", "move": "move_upsell", "results": {
			"karen:plain": [-3, 31],
			"karen:defending": [-2, 32],
			"chef:plain": [-4, 26],
			"chef:defending": [-2, 28],
			"florida_man:plain": [-3, 35],
			"florida_man:defending": [-2, 36],
			"baguette_thrower:plain": [-4, 28],
			"baguette_thrower:defending": [-2, 30],
		}},
		{"enemy": "enemy_ceo", "move": "move_layoffs", "results": {
			"karen:plain": [-7, 27],
			"karen:defending": [-4, 30],
			"chef:plain": [-8, 22],
			"chef:defending": [-4, 26],
			"florida_man:plain": [-8, 30],
			"florida_man:defending": [-4, 34],
			"baguette_thrower:plain": [-8, 24],
			"baguette_thrower:defending": [-4, 28],
		}},
		{"enemy": "enemy_ceo", "move": "move_hostile_takeover", "results": {
			"karen:plain": [-17, 17],
			"karen:defending": [-8, 26],
			"chef:plain": [-18, 12],
			"chef:defending": [-9, 21],
			"florida_man:plain": [-18, 20],
			"florida_man:defending": [-9, 29],
			"baguette_thrower:plain": [-18, 14],
			"baguette_thrower:defending": [-9, 23],
		}},
		{"enemy": "enemy_clerk", "move": "attack", "results": {
			"karen:plain": [-6, 28],
			"karen:defending": [-3, 31],
			"chef:plain": [-7, 23],
			"chef:defending": [-3, 27],
			"florida_man:plain": [-6, 32],
			"florida_man:defending": [-3, 35],
			"baguette_thrower:plain": [-7, 25],
			"baguette_thrower:defending": [-3, 29],
		}},
		{"enemy": "enemy_supervisor", "move": "attack", "results": {
			"karen:plain": [-9, 25],
			"karen:defending": [-5, 29],
			"chef:plain": [-10, 20],
			"chef:defending": [-5, 25],
			"florida_man:plain": [-10, 28],
			"florida_man:defending": [-5, 33],
			"baguette_thrower:plain": [-10, 22],
			"baguette_thrower:defending": [-5, 27],
		}},
		{"enemy": "enemy_security_drone", "move": "attack", "results": {
			"karen:plain": [-7, 27],
			"karen:defending": [-3, 31],
			"chef:plain": [-8, 22],
			"chef:defending": [-4, 26],
			"florida_man:plain": [-7, 31],
			"florida_man:defending": [-4, 34],
			"baguette_thrower:plain": [-8, 24],
			"baguette_thrower:defending": [-4, 28],
		}},
		{"enemy": "enemy_middle_manager", "move": "attack", "results": {
			"karen:plain": [-5, 29],
			"karen:defending": [-3, 31],
			"chef:plain": [-6, 24],
			"chef:defending": [-3, 27],
			"florida_man:plain": [-6, 32],
			"florida_man:defending": [-3, 35],
			"baguette_thrower:plain": [-6, 26],
			"baguette_thrower:defending": [-3, 29],
		}},
		{"enemy": "enemy_ceo", "move": "attack", "results": {
			"karen:plain": [-9, 25],
			"karen:defending": [-5, 29],
			"chef:plain": [-10, 20],
			"chef:defending": [-5, 25],
			"florida_man:plain": [-10, 28],
			"florida_man:defending": [-5, 33],
			"baguette_thrower:plain": [-10, 22],
			"baguette_thrower:defending": [-5, 27],
		}},
	],
	"squad_side": [
		{"squad": "karen", "move": "attack", "results": {
			"enemy_clerk:plain": [-8, 32],
			"enemy_clerk:defending": [-4, 36],
			"enemy_clerk:vulnerable": [-12, 28],
			"enemy_supervisor:plain": [-7, 103],
			"enemy_supervisor:defending": [-3, 107],
			"enemy_supervisor:vulnerable": [-10, 100],
			"enemy_security_drone:plain": [-7, 29],
			"enemy_security_drone:defending": [-4, 32],
			"enemy_security_drone:vulnerable": [-11, 25],
			"enemy_middle_manager:plain": [-8, 36],
			"enemy_middle_manager:defending": [-4, 40],
			"enemy_middle_manager:vulnerable": [-12, 32],
			"enemy_ceo:plain": [-7, 113],
			"enemy_ceo:defending": [-3, 117],
			"enemy_ceo:vulnerable": [-10, 110],
		}},
		{"squad": "chef", "move": "attack", "results": {
			"enemy_clerk:plain": [-7, 33],
			"enemy_clerk:defending": [-4, 36],
			"enemy_clerk:vulnerable": [-11, 29],
			"enemy_supervisor:plain": [-6, 104],
			"enemy_supervisor:defending": [-3, 107],
			"enemy_supervisor:vulnerable": [-9, 101],
			"enemy_security_drone:plain": [-6, 30],
			"enemy_security_drone:defending": [-3, 33],
			"enemy_security_drone:vulnerable": [-10, 26],
			"enemy_middle_manager:plain": [-7, 37],
			"enemy_middle_manager:defending": [-4, 40],
			"enemy_middle_manager:vulnerable": [-11, 33],
			"enemy_ceo:plain": [-6, 114],
			"enemy_ceo:defending": [-3, 117],
			"enemy_ceo:vulnerable": [-9, 111],
		}},
		{"squad": "florida_man", "move": "attack", "results": {
			"enemy_clerk:plain": [-10, 30],
			"enemy_clerk:defending": [-5, 35],
			"enemy_clerk:vulnerable": [-15, 25],
			"enemy_supervisor:plain": [-8, 102],
			"enemy_supervisor:defending": [-4, 106],
			"enemy_supervisor:vulnerable": [-12, 98],
			"enemy_security_drone:plain": [-9, 27],
			"enemy_security_drone:defending": [-4, 32],
			"enemy_security_drone:vulnerable": [-13, 23],
			"enemy_middle_manager:plain": [-10, 34],
			"enemy_middle_manager:defending": [-5, 39],
			"enemy_middle_manager:vulnerable": [-15, 29],
			"enemy_ceo:plain": [-8, 112],
			"enemy_ceo:defending": [-4, 116],
			"enemy_ceo:vulnerable": [-12, 108],
		}},
		{"squad": "baguette_thrower", "move": "attack", "results": {
			"enemy_clerk:plain": [-11, 29],
			"enemy_clerk:defending": [-5, 35],
			"enemy_clerk:vulnerable": [-16, 24],
			"enemy_supervisor:plain": [-9, 101],
			"enemy_supervisor:defending": [-4, 106],
			"enemy_supervisor:vulnerable": [-13, 97],
			"enemy_security_drone:plain": [-10, 26],
			"enemy_security_drone:defending": [-5, 31],
			"enemy_security_drone:vulnerable": [-15, 21],
			"enemy_middle_manager:plain": [-11, 33],
			"enemy_middle_manager:defending": [-5, 39],
			"enemy_middle_manager:vulnerable": [-16, 28],
			"enemy_ceo:plain": [-9, 111],
			"enemy_ceo:defending": [-4, 116],
			"enemy_ceo:vulnerable": [-13, 107],
		}},
		{"squad": "baguette_thrower", "move": "move_home_run", "results": {
			"enemy_clerk:plain": [-19, 21],
			"enemy_clerk:defending": [-10, 30],
			"enemy_clerk:vulnerable": [-29, 11],
			"enemy_supervisor:plain": [-16, 94],
			"enemy_supervisor:defending": [-8, 102],
			"enemy_supervisor:vulnerable": [-24, 86],
			"enemy_security_drone:plain": [-18, 18],
			"enemy_security_drone:defending": [-9, 27],
			"enemy_security_drone:vulnerable": [-26, 10],
			"enemy_middle_manager:plain": [-19, 25],
			"enemy_middle_manager:defending": [-10, 34],
			"enemy_middle_manager:vulnerable": [-29, 15],
			"enemy_ceo:plain": [-16, 104],
			"enemy_ceo:defending": [-8, 112],
			"enemy_ceo:vulnerable": [-24, 96],
		}},
	],
}

## Edge case (QA): minimum damage (1) is reached and clamped, independent of
## variance. Not one of the 203 shipped-stat-block cases above (none of them
## naturally floors) -- a minimal-attack combatant (atk 1) vs. the Supervisor
## (def 10), so the base damage is far below 1 before the +/-10% variance is
## even applied. attacker: Combatant.new("Weakling", 20, 0, 1, 0, 5, false).
const DAMAGE_FLOOR_CASE: Dictionary = {
	"target_enemy": "enemy_supervisor", "hp_delta": -1, "target_hp": 109,
	"rng_state": -5030687368022391725,
}

## Story 008: whole scripted fights, run once against the shipped rosters and
## shipped rules under `ScriptedFightCommands.BUREAUCRATIA`/`MEGACORP`, then
## frozen (ADR-0001 Migration Step 0, ADR-0010 Migration Step 1). `ROUND_CAP`
## is the safety stop shared by both fights; neither is expected to reach it.
const ROUND_CAP: int = 20
const SEED_FIGHT_B: int = 5
const SEED_FIGHT_M: int = 6

## Story 008 carryover case: a second fight started with `start_battle(false)`
## after the squad's vitals were arranged (Karen knocked out, Chef at 10 HP /
## 3 MP), Clerk, Clerk, Supervisor under the permit rule, `SEED_FIGHT_B`,
## every turn an Attack on the first living enemy until `battle_ended`.
## Neither fight above leaves a living squad member to carry over (both end
## in a total wipe), so this case arranges its own end-of-fight vitals.
const CARRYOVER_FIGHT: Dictionary = {
	"chef_hp": 10, "chef_mp": 3,
	"commands_consumed": 13, "won": false, "final_round": 7,
	"rng_state": -4141046269618259410, "outcome_log_size": 31,
}

## Story 008: whole scripted fights against each faction's shipped roster,
## run once with `ScriptedFightCommands.BUREAUCRATIA`/`MEGACORP` against the
## shipped rules and frozen (ADR-0001 Migration Step 0; ADR-0010 Migration
## Step 1). Roster order (both fights): index 0-3 are the fixture squad
## (karen, chef, florida_man, baguette_thrower), 4-6 are the three enemies
## in construction order. `resolved_log` mirrors `BattleContentSeam.
## resolved_log(battle)`'s own field names, with `actor`/`target` as roster
## indices (`null` for a self-only move). `hp_snapshots[i]` is every
## combatant's `[hp, mp]`, in roster order, immediately after
## `resolved_log[i]` -- one row per resolved entry, not per raw outcome_log
## entry (today the two coincide). `signal_log_codes` is the signal order as
## one character per emission -- T=turn_started, A=action_resolved,
## R=round_advanced, E=battle_ended -- the same order
## `turn_started`/`action_resolved`/`round_advanced`/`battle_ended` actually
## fired in. Both fights lose (`won = false`): the shipped squad cannot beat
## either boss at these stat blocks -- the open balance question this epic
## does not resolve -- and that loss is what is pinned, not "fixed".
const BUREAUCRATIA_FIGHT: Dictionary = {
	"commands_consumed": 33, "won": false, "final_round": 11,
	"rng_state": 3778046631671448364,
	"signal_log_codes": "TATATATAAAAAAARTATATATAAAAARTATATATAAAAARTATATATAAAAARTATATATAARTATATAAAARTATATAARTATAAARTATAARTAARTAAE",
	"resolved_log": [
		{"actor": 0, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 1, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -10, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -10, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 4, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 4, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -3, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 5, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 5, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 6, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 6, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -5, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 1, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -5, "mp_delta": 0, "target_knocked_out": true, "round_number": 2},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 5, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 5, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -3, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 6, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 6, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 1, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -5, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -5, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 5, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 5, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 6, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 6, "move_name": "Pen Jab", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -5, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 0, "move_name": "Speak to the Manager", "category": Move.Category.SPECIAL, "target": 5, "hp_delta": 0, "mp_delta": -4, "target_knocked_out": false, "round_number": 4},
		{"actor": 1, "move_name": "Family Meal", "category": Move.Category.SPECIAL, "target": null, "hp_delta": 18, "mp_delta": -5, "target_knocked_out": false, "round_number": 4},
		{"actor": 2, "move_name": "Viral Stunt", "category": Move.Category.SPECIAL, "target": 5, "hp_delta": 0, "mp_delta": -3, "target_knocked_out": false, "round_number": 4},
		{"actor": 3, "move_name": "Home Run", "category": Move.Category.SPECIAL, "target": 5, "hp_delta": -16, "mp_delta": -4, "target_knocked_out": true, "round_number": 4},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 4},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 1, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 4},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 4},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 4},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 1, "move_name": "Appetizer", "category": Move.Category.SPECIAL, "target": 0, "hp_delta": 9, "mp_delta": -3, "target_knocked_out": false, "round_number": 5},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 6, "move_name": "Final Notice", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -17, "mp_delta": 0, "target_knocked_out": true, "round_number": 5},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 1, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 1, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 7},
		{"actor": 1, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 7},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 7},
		{"actor": 6, "move_name": "Final Notice", "category": Move.Category.ATTACK, "target": 1, "hp_delta": -14, "mp_delta": 0, "target_knocked_out": true, "round_number": 7},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 8},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 8},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 8},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 8},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 9},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 9},
		{"actor": 6, "move_name": "Final Notice", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -13, "mp_delta": 0, "target_knocked_out": true, "round_number": 9},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 10},
		{"actor": 6, "move_name": "Mass Audit", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 10},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 11},
		{"actor": 6, "move_name": "Final Notice", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -11, "mp_delta": 0, "target_knocked_out": true, "round_number": 11},
	],
	"hp_snapshots": [
		[[34, 12], [30, 14], [38, 10], [32, 12], [40, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [38, 10], [32, 12], [33, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [38, 10], [32, 12], [23, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [38, 10], [32, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [38, 10], [32, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [35, 10], [32, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [35, 10], [32, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [35, 10], [28, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [35, 10], [28, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [30, 10], [28, 12], [13, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [30, 10], [28, 12], [9, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [30, 10], [28, 12], [5, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [30, 10], [28, 12], [0, 0], [40, 0], [110, 0]],
		[[34, 12], [30, 14], [30, 10], [28, 12], [0, 0], [34, 0], [110, 0]],
		[[34, 12], [30, 14], [30, 10], [28, 12], [0, 0], [34, 0], [110, 0]],
		[[31, 12], [30, 14], [30, 10], [28, 12], [0, 0], [34, 0], [110, 0]],
		[[31, 12], [30, 14], [30, 10], [28, 12], [0, 0], [34, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [28, 12], [0, 0], [34, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [28, 12], [0, 0], [30, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [28, 12], [0, 0], [26, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [28, 12], [0, 0], [21, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [28, 12], [0, 0], [16, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [28, 12], [0, 0], [16, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [24, 12], [0, 0], [16, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [24, 12], [0, 0], [16, 0], [110, 0]],
		[[27, 12], [30, 14], [30, 10], [19, 12], [0, 0], [16, 0], [110, 0]],
		[[27, 8], [30, 14], [30, 10], [19, 12], [0, 0], [16, 0], [110, 0]],
		[[33, 8], [30, 9], [36, 10], [25, 12], [0, 0], [16, 0], [110, 0]],
		[[33, 8], [30, 9], [36, 7], [25, 12], [0, 0], [16, 0], [110, 0]],
		[[33, 8], [30, 9], [36, 7], [25, 8], [0, 0], [0, 0], [110, 0]],
		[[25, 8], [30, 9], [36, 7], [25, 8], [0, 0], [0, 0], [110, 0]],
		[[25, 8], [22, 9], [36, 7], [25, 8], [0, 0], [0, 0], [110, 0]],
		[[25, 8], [22, 9], [29, 7], [25, 8], [0, 0], [0, 0], [110, 0]],
		[[25, 8], [22, 9], [29, 7], [17, 8], [0, 0], [0, 0], [110, 0]],
		[[25, 8], [22, 9], [29, 7], [17, 8], [0, 0], [0, 0], [104, 0]],
		[[34, 8], [22, 6], [29, 7], [17, 8], [0, 0], [0, 0], [104, 0]],
		[[34, 8], [22, 6], [29, 7], [17, 8], [0, 0], [0, 0], [95, 0]],
		[[34, 8], [22, 6], [29, 7], [17, 8], [0, 0], [0, 0], [87, 0]],
		[[34, 8], [22, 6], [29, 7], [0, 8], [0, 0], [0, 0], [87, 0]],
		[[34, 8], [22, 6], [29, 7], [0, 8], [0, 0], [0, 0], [81, 0]],
		[[34, 8], [22, 6], [29, 7], [0, 8], [0, 0], [0, 0], [75, 0]],
		[[34, 8], [22, 6], [29, 7], [0, 8], [0, 0], [0, 0], [67, 0]],
		[[26, 8], [22, 6], [29, 7], [0, 8], [0, 0], [0, 0], [67, 0]],
		[[26, 8], [14, 6], [29, 7], [0, 8], [0, 0], [0, 0], [67, 0]],
		[[26, 8], [14, 6], [21, 7], [0, 8], [0, 0], [0, 0], [67, 0]],
		[[26, 8], [14, 6], [21, 7], [0, 8], [0, 0], [0, 0], [61, 0]],
		[[26, 8], [14, 6], [21, 7], [0, 8], [0, 0], [0, 0], [55, 0]],
		[[26, 8], [14, 6], [21, 7], [0, 8], [0, 0], [0, 0], [46, 0]],
		[[26, 8], [0, 6], [21, 7], [0, 8], [0, 0], [0, 0], [46, 0]],
		[[26, 8], [0, 6], [21, 7], [0, 8], [0, 0], [0, 0], [39, 0]],
		[[26, 8], [0, 6], [21, 7], [0, 8], [0, 0], [0, 0], [30, 0]],
		[[19, 8], [0, 6], [21, 7], [0, 8], [0, 0], [0, 0], [30, 0]],
		[[19, 8], [0, 6], [13, 7], [0, 8], [0, 0], [0, 0], [30, 0]],
		[[19, 8], [0, 6], [13, 7], [0, 8], [0, 0], [0, 0], [24, 0]],
		[[19, 8], [0, 6], [13, 7], [0, 8], [0, 0], [0, 0], [15, 0]],
		[[19, 8], [0, 6], [0, 7], [0, 8], [0, 0], [0, 0], [15, 0]],
		[[19, 8], [0, 6], [0, 7], [0, 8], [0, 0], [0, 0], [8, 0]],
		[[11, 8], [0, 6], [0, 7], [0, 8], [0, 0], [0, 0], [8, 0]],
		[[11, 8], [0, 6], [0, 7], [0, 8], [0, 0], [0, 0], [2, 0]],
		[[0, 8], [0, 6], [0, 7], [0, 8], [0, 0], [0, 0], [2, 0]],
	],
}

const MEGACORP_FIGHT: Dictionary = {
	"commands_consumed": 21, "won": false, "final_round": 8,
	"rng_state": -3845889014642347552,
	"signal_log_codes": "TATATATAAAAAARTATATATAAARTATATAAAAARTATATAARTATAAARTATAARTAARTAAE",
	"resolved_log": [
		{"actor": 0, "move_name": "Speak to the Manager", "category": Move.Category.SPECIAL, "target": 4, "hp_delta": 0, "mp_delta": -4, "target_knocked_out": false, "round_number": 1},
		{"actor": 1, "move_name": "Family Meal", "category": Move.Category.SPECIAL, "target": null, "hp_delta": 0, "mp_delta": -5, "target_knocked_out": false, "round_number": 1},
		{"actor": 2, "move_name": "Viral Stunt", "category": Move.Category.SPECIAL, "target": 4, "hp_delta": 0, "mp_delta": -3, "target_knocked_out": false, "round_number": 1},
		{"actor": 3, "move_name": "Home Run", "category": Move.Category.SPECIAL, "target": 4, "hp_delta": -29, "mp_delta": -4, "target_knocked_out": false, "round_number": 1},
		{"actor": 5, "move_name": "Upsell", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -3, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 1, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 1},
		{"actor": 0, "move_name": "Defend", "category": Move.Category.DEFEND, "target": null, "hp_delta": 0, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 1, "move_name": "Appetizer", "category": Move.Category.SPECIAL, "target": 0, "hp_delta": 11, "mp_delta": -3, "target_knocked_out": false, "round_number": 2},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 4, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": true, "round_number": 2},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -11, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 5, "move_name": "Upsell", "category": Move.Category.ATTACK, "target": 1, "hp_delta": -3, "mp_delta": 0, "target_knocked_out": false, "round_number": 2},
		{"actor": 6, "move_name": "Hostile Takeover", "category": Move.Category.ATTACK, "target": 1, "hp_delta": -18, "mp_delta": 0, "target_knocked_out": true, "round_number": 2},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -10, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 5, "move_name": "Upsell", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -4, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 3},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 5, "hp_delta": -5, "mp_delta": 0, "target_knocked_out": true, "round_number": 4},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 4},
		{"actor": 3, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -9, "mp_delta": 0, "target_knocked_out": false, "round_number": 4},
		{"actor": 6, "move_name": "Hostile Takeover", "category": Move.Category.ATTACK, "target": 3, "hp_delta": -11, "mp_delta": 0, "target_knocked_out": true, "round_number": 4},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -8, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 5},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 2, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 6},
		{"actor": 6, "move_name": "Hostile Takeover", "category": Move.Category.ATTACK, "target": 2, "hp_delta": -14, "mp_delta": 0, "target_knocked_out": true, "round_number": 6},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 7},
		{"actor": 6, "move_name": "Layoffs", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -7, "mp_delta": 0, "target_knocked_out": false, "round_number": 7},
		{"actor": 0, "move_name": "Attack", "category": Move.Category.ATTACK, "target": 6, "hp_delta": -6, "mp_delta": 0, "target_knocked_out": false, "round_number": 8},
		{"actor": 6, "move_name": "Hostile Takeover", "category": Move.Category.ATTACK, "target": 0, "hp_delta": -12, "mp_delta": 0, "target_knocked_out": true, "round_number": 8},
	],
	"hp_snapshots": [
		[[34, 8], [30, 14], [38, 4], [32, 12], [36, 0], [44, 0], [120, 0]],
		[[34, 8], [30, 9], [38, 4], [32, 12], [36, 0], [44, 0], [120, 0]],
		[[34, 8], [30, 9], [38, 1], [32, 12], [36, 0], [44, 0], [120, 0]],
		[[34, 8], [30, 9], [38, 1], [32, 8], [7, 0], [44, 0], [120, 0]],
		[[31, 8], [30, 9], [38, 1], [32, 8], [7, 0], [44, 0], [120, 0]],
		[[23, 8], [30, 9], [38, 1], [32, 8], [7, 0], [44, 0], [120, 0]],
		[[23, 8], [21, 9], [38, 1], [32, 8], [7, 0], [44, 0], [120, 0]],
		[[23, 8], [21, 9], [30, 1], [32, 8], [7, 0], [44, 0], [120, 0]],
		[[23, 8], [21, 9], [30, 1], [24, 8], [7, 0], [44, 0], [120, 0]],
		[[23, 7], [21, 8], [30, 0], [24, 7], [7, 0], [44, 0], [120, 0]],
		[[34, 7], [21, 5], [30, 0], [24, 7], [7, 0], [44, 0], [120, 0]],
		[[34, 7], [21, 5], [30, 0], [24, 7], [0, 0], [44, 0], [120, 0]],
		[[34, 7], [21, 5], [30, 0], [24, 7], [0, 0], [33, 0], [120, 0]],
		[[34, 7], [18, 5], [30, 0], [24, 7], [0, 0], [33, 0], [120, 0]],
		[[34, 7], [0, 5], [30, 0], [24, 7], [0, 0], [33, 0], [120, 0]],
		[[34, 6], [0, 5], [30, 0], [24, 6], [0, 0], [24, 0], [120, 0]],
		[[34, 6], [0, 5], [30, 0], [24, 6], [0, 0], [15, 0], [120, 0]],
		[[34, 6], [0, 5], [30, 0], [24, 6], [0, 0], [5, 0], [120, 0]],
		[[34, 6], [0, 5], [30, 0], [20, 6], [0, 0], [5, 0], [120, 0]],
		[[26, 6], [0, 5], [30, 0], [20, 6], [0, 0], [5, 0], [120, 0]],
		[[26, 6], [0, 5], [21, 0], [20, 6], [0, 0], [5, 0], [120, 0]],
		[[26, 6], [0, 5], [21, 0], [11, 6], [0, 0], [5, 0], [120, 0]],
		[[26, 5], [0, 5], [21, 0], [11, 5], [0, 0], [0, 0], [120, 0]],
		[[26, 5], [0, 5], [21, 0], [11, 5], [0, 0], [0, 0], [111, 0]],
		[[26, 5], [0, 5], [21, 0], [11, 5], [0, 0], [0, 0], [102, 0]],
		[[26, 5], [0, 5], [21, 0], [0, 5], [0, 0], [0, 0], [102, 0]],
		[[26, 4], [0, 5], [21, 0], [0, 5], [0, 0], [0, 0], [96, 0]],
		[[26, 4], [0, 5], [21, 0], [0, 5], [0, 0], [0, 0], [88, 0]],
		[[19, 4], [0, 5], [21, 0], [0, 5], [0, 0], [0, 0], [88, 0]],
		[[19, 4], [0, 5], [14, 0], [0, 5], [0, 0], [0, 0], [88, 0]],
		[[19, 3], [0, 5], [14, 0], [0, 5], [0, 0], [0, 0], [82, 0]],
		[[19, 3], [0, 5], [14, 0], [0, 5], [0, 0], [0, 0], [75, 0]],
		[[19, 3], [0, 5], [0, 0], [0, 5], [0, 0], [0, 0], [75, 0]],
		[[19, 2], [0, 5], [0, 0], [0, 5], [0, 0], [0, 0], [69, 0]],
		[[12, 2], [0, 5], [0, 0], [0, 5], [0, 0], [0, 0], [69, 0]],
		[[12, 1], [0, 5], [0, 0], [0, 5], [0, 0], [0, 0], [63, 0]],
		[[0, 1], [0, 5], [0, 0], [0, 5], [0, 0], [0, 0], [63, 0]],
	],
}
