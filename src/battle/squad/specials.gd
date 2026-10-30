## The squad's four named Specials (design/game-brief.md MVP feature 2;
## Story 003): Karen's *Speak to the Manager*, the Five-Star Chef's *Family
## Meal* and *Appetizer*, Florida Man's *Viral Stunt*, and the Baguette
## Thrower's *Home Run*.
##
## Each factory builds a plain `Move` (`category == Move.Category.SPECIAL`)
## that BattleCore already knows how to cost, target and resolve (Story 001);
## `Move.special_effect` tells `BattleCore._resolve_move()` which of the
## static helpers below to run. This file holds the effects themselves —
## BattleCore stays the only place that *dispatches* them, so there is no
## second system parallel to Attack/Defend.
##
## Reference: prototypes/battle-concept/battle.gd (iteration 2/3) has a prior
## version of these four. Reimplemented here, not imported — see that
## prototype's "regen" Family Meal vs. this file's instant F4 heal (this
## story's Acceptance Criteria want the latter).
##
## Usage example:
## [codeblock]
## var karen := Combatant.new("Karen", 34, 12, 12, 9, 11, false)
## var move := SquadSpecials.make_speak_to_the_manager()
## # BattleCore.submit_action(move, target) spends MP and resolves it;
## # the effect itself runs through SquadSpecials.apply_stun().
## [/codeblock]
## Content-migration story 028: the five factories adapt their Move records
## (`move_speak_to_the_manager` etc.) through `MoveAdapter`; the cost/power
## constants below are unused until story 030 deletes them.
class_name SquadSpecials
extends RefCounted

## Karen's stun: spends MP, targets one enemy.
const SPEAK_TO_MANAGER_MP_COST: int = 4

## The Chef's single-target heal: spends MP, heals one chosen ally (F4).
const APPETIZER_MP_COST: int = 3
const APPETIZER_POWER: int = 10

## The Chef's party-wide heal: spends MP, heals every living squad member (F4).
const FAMILY_MEAL_MP_COST: int = 5
const FAMILY_MEAL_POWER: int = 5

## Florida Man's damage-taken debuff: spends MP, no power of its own — its
## magnitude is DamageCalculator.VULNERABLE_PCT, its duration is this many
## rounds (Move.effect_rounds).
const VIRAL_STUNT_MP_COST: int = 3
const VIRAL_STUNT_ROUNDS: int = 2

## The Baguette Thrower's direct-damage special: spends MP, same damage
## pipeline as Attack (DamageCalculator.calculate_damage()) with its own power.
const HOME_RUN_MP_COST: int = 4
const HOME_RUN_POWER: int = 18

## Attack scaling for the heal formula (Stats & Damage GDD F4): attack this
## high adds +100% to a heal's base power. Same constant as the prototype's
## HEAL_ATTACK_SCALE.
const HEAL_ATTACK_SCALE: float = 50.0


## Karen's *Speak to the Manager*: stuns one enemy (it loses its next turn),
## no effect on a boss (Acceptance Criteria 1-2).
static func make_speak_to_the_manager() -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), "move_speak_to_the_manager")


## The Five-Star Chef's *Family Meal*: heals every living squad member at once
## using F4 (Acceptance Criterion 3). Targets SELF (like Defend) since it has
## no single external target to pick.
static func make_family_meal() -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), "move_family_meal")


## The Five-Star Chef's *Appetizer*: heals one chosen ally using F4
## (Acceptance Criterion 4) — Family Meal's single-target sibling.
static func make_appetizer() -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), "move_appetizer")


## Florida Man's *Viral Stunt*: makes one enemy take more damage for
## VIRAL_STUNT_ROUNDS rounds (Acceptance Criterion 5).
static func make_viral_stunt() -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), "move_viral_stunt")


## The Baguette Thrower's *Home Run*: deals damage to one enemy through the
## same pipeline as Attack, with its own power (Acceptance Criterion 6).
static func make_home_run() -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), "move_home_run")


## Stats & Damage GDD F4 base heal, rounded half up (F7's rounding rule
## applies to heals too). Heals never draw from the RNG (F6: heal_variance is
## 0), so this is fully deterministic.
## Example: [code]SquadSpecials.calculate_heal(10, chef)[/code]
static func calculate_heal(power: int, healer: Combatant) -> int:
	var attack_eff := float(maxi(1, healer.attack))
	var base: float = float(power) * (1.0 + attack_eff / HEAL_ATTACK_SCALE)  # F4
	return int(floorf(base + 0.5))  # F7 round-half-up


## Family Meal's effect: heals every living member of `members` using F4,
## scaled off `healer`'s attack. Returns the total HP actually restored
## across the whole group (BattleCore reports this as one BattleOutcome with
## `target = null`, the same null-target convention Defend already uses for
## a self-only move with no single external target).
static func heal_party(healer: Combatant, members: Array[Combatant], power: int) -> int:
	var amount := calculate_heal(power, healer)
	var total := 0
	for member in members:
		if not member.is_knocked_out():
			total += member.heal(amount)
	return total


## Appetizer's effect: heals one target using F4, scaled off `healer`'s
## attack. Returns the HP actually restored.
static func heal_single(healer: Combatant, target: Combatant, power: int) -> int:
	return target.heal(calculate_heal(power, healer))


## Speak to the Manager's effect: stuns `target` so BattleCore skips its next
## turn, unless `target` is the manager (Acceptance Criterion 2). Reuses
## BureaucratiaRule.is_manager() — Story 002's boss/manager flag — rather
## than a second one-off immunity check. Returns true if the stun landed.
static func apply_stun(target: Combatant) -> bool:
	if BureaucratiaRule.is_manager(target):
		return false
	target.is_stunned = true
	return true


## Viral Stunt's effect: marks `target` vulnerable (extra damage taken,
## DamageCalculator.VULNERABLE_PCT) for `rounds` rounds.
static func apply_vulnerable(target: Combatant, rounds: int) -> void:
	target.vulnerable_rounds_left = rounds
