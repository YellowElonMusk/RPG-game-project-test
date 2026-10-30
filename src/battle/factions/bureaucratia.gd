## Bureaucratia's faction rule (design/game-brief.md MVP feature 3; Story
## 002): specials are banned for both sides until the permit arrives, and
## Bureaucratia hunkers down meanwhile, focusing anyone at half HP or lower.
## Also owns this chapter's enemy roster: Clerks and the Supervisor boss
## ("he *is* the manager").
##
## Plugs into BattleCore through its `faction_rule` hook (see FactionRule).
## BattleCore itself has no Bureaucratia-specific code.
##
## Reference: prototypes/battle-concept/battle.gd iteration 2
## (`_specials_allowed`, `_bureaucratia_act`). The constants below are that
## prototype's playtested values (PLAYTEST-LOG.md Playtest 1). They are
## reimplemented here, not imported.
##
## Usage example:
## [codeblock]
## var enemies: Array[Combatant] = [
##     BureaucratiaRule.make_clerk(), BureaucratiaRule.make_clerk(),
##     BureaucratiaRule.make_supervisor(),
## ]
## var battle := BattleCore.new(squad, enemies, null, BureaucratiaRule.new())
## [/codeblock]
class_name BureaucratiaRule
extends FactionRule

## Specials are banned for rounds 1..PERMIT_ROUNDS and allowed from
## PERMIT_ROUNDS + 1 on, so round 4 is the first round either side may use
## one (Acceptance Criteria 1-2).
const PERMIT_ROUNDS: int = 3

## A squad member at or below this fraction of max HP is weak enough that
## the officials stop hunkering down and focus them (Acceptance Criteria 3-4).
const LOW_HP_THRESHOLD: float = 0.5

## While specials are banned: the weak jab made while hunkered down, and the
## full attack on a weakened squad member.
const HUNKER_JAB_POWER: int = 5
const FOCUS_ATTACK_POWER: int = 10

## After the permit arrives: the officials' named moves. They are ATTACK
## category, not SPECIAL, because the core's SPECIAL branch has no effect
## yet (Story 003).
const LATE_FEE_POWER: int = 16
const MASS_AUDIT_POWER: int = 8
const FINAL_NOTICE_POWER: int = 18

const CLERK_DISPLAY_NAME: String = "Clerk"
const CLERK_MAX_HP: int = 40
const CLERK_ATTACK: int = 11
const CLERK_DEFENSE: int = 6
const CLERK_SPEED: int = 8

const SUPERVISOR_DISPLAY_NAME: String = "Supervisor"
const SUPERVISOR_MAX_HP: int = 110
const SUPERVISOR_ATTACK: int = 15
const SUPERVISOR_DEFENSE: int = 10
const SUPERVISOR_SPEED: int = 9


## A regular Bureaucratia enemy for this chapter's non-boss fights
## (Acceptance Criterion 5). It has no MP of its own.
## Example: [code]var clerk := BureaucratiaRule.make_clerk()[/code]
## Built from the `enemy_clerk` record (content-migration story 024); the
## constants above are unused until story 030 deletes them.
static func make_clerk() -> Combatant:
	return EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_clerk")


## The Bureaucratia boss. He has more HP than a Clerk (Acceptance Criterion 6)
## and is flagged `is_boss`, which makes him "the manager" for is_manager()
## (Acceptance Criterion 7).
## Example: [code]var boss := BureaucratiaRule.make_supervisor()[/code]
## Built from the `enemy_supervisor` record (content-migration story 024).
static func make_supervisor() -> Combatant:
	return EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_supervisor")


## True if `combatant` is immune to moves that target "the manager", because
## they already are the manager (Acceptance Criterion 7). It is keyed off the
## general Combatant.is_boss flag. Any "target the manager" effect, such as
## Karen's stun in Story 003, must check this and do nothing when it is true.
## This story adds only the check, not the effect.
## Example: [code]if not BureaucratiaRule.is_manager(target): apply_stun(target)[/code]
static func is_manager(combatant: Combatant) -> bool:
	return combatant.is_boss


## Specials are banned for both sides until the permit arrives after round
## PERMIT_ROUNDS (Acceptance Criteria 1-2).
## Example: [code]rule.specials_allowed(4)  # true[/code]
func specials_allowed(round_number: int) -> bool:
	return round_number > PERMIT_ROUNDS


## Bureaucratia's enemy turn.
##
## While specials are banned (Acceptance Criteria 3-4):
## - If every living squad member is above half HP, the official hunkers down
##   (Defend, which halves incoming damage) and also makes a weak jab at a
##   random squad member.
## - Otherwise the official skips defending and attacks the weakest squad
##   member (the lowest HP fraction, which is at or below half).
##
## After the permit arrives, the officials use the prototype's named moves:
## - Clerks use "Late Fee" on the weakest squad member.
## - The Supervisor uses "Mass Audit" on every squad member in even rounds,
##   and "Final Notice" on the weakest in odd rounds.
## Example: [code]var actions := rule.choose_enemy_action(clerk, battle.get_living_squad(), 1, battle.rng)[/code]
func choose_enemy_action(enemy: Combatant, living_squad: Array[Combatant],
		round_number: int, rng: RandomNumberGenerator) -> Array:
	var weakest: Combatant = _weakest(living_squad)

	if specials_allowed(round_number):
		if enemy.is_boss:
			if round_number % 2 == 0:
				var actions: Array = []
				for member in living_squad:
					actions.append({"move": _named_attack("move_mass_audit"),
							"target": member})
				return actions
			return [{"move": _named_attack("move_final_notice"), "target": weakest}]
		return [{"move": _named_attack("move_late_fee"), "target": weakest}]

	if _hp_fraction(weakest) <= LOW_HP_THRESHOLD:
		return [{"move": _named_attack("move_red_tape"), "target": weakest}]

	var jab_target: Combatant = living_squad[rng.randi_range(0, living_squad.size() - 1)]
	return [
		{"move": Move.make_defend(), "target": null},
		{"move": _named_attack("move_pen_jab"), "target": jab_target},
	]


# Builds a named attack from its Move record through MoveAdapter
# (content-migration story 023). TODO(content-migration): story 026 reads the
# move IDs from the rule record's params in `_configure()`.
func _named_attack(move_id: String) -> Move:
	return MoveAdapter.from_catalog(BattleCatalog.shipped(), move_id)


func _weakest(combatants: Array[Combatant]) -> Combatant:
	var weakest: Combatant = combatants[0]
	for combatant in combatants:
		if _hp_fraction(combatant) < _hp_fraction(weakest):
			weakest = combatant
	return weakest


func _hp_fraction(combatant: Combatant) -> float:
	return float(combatant.hp) / float(maxi(1, combatant.max_hp))


## Banner headline for the permit countdown/granted states (Acceptance
## Criterion 3; Story 005).
## Example: [code]rule.get_banner_text(1)  # "...arrives in 3 rounds..."[/code]
func get_banner_text(round_number: int) -> String:
	if specials_allowed(round_number):
		return "PERMIT GRANTED — All-out war! Special moves are allowed for both sides."
	var rounds_left: int = PERMIT_ROUNDS - round_number + 1
	return "BUREAUCRATIA — Special moves need a government permit. It arrives in %d round%s. Attack and Defend only, for both sides." % [
		rounds_left, "" if rounds_left == 1 else "s"]


## Bureaucratia's stamp red (art bible), stable for the whole fight (Story 005).
func get_identity_color() -> Color:
	return Color("#D23A2E")


## Stamp red while the permit is pending, the "all-out war" amber once it's
## granted (Story 005) — unlike get_identity_color(), this does vary by round.
func get_banner_color(round_number: int) -> Color:
	return Color("#b07a12") if specials_allowed(round_number) else get_identity_color()


## Plain-language explanation of the permit rule for tooltips (Story 005).
func get_tooltip_text(round_number: int) -> String:
	if specials_allowed(round_number):
		return "The permit arrived: Special moves are now allowed for both sides."
	return "Bureaucratia requires a government permit before anyone can use a Special move. Attack and Defend only until it arrives."
