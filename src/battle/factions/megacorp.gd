## MegaCorp's faction rule (design/game-brief.md MVP feature 4; Story 004):
## subscription billing. Every squad member is billed a fixed MP charge once
## per round; whoever's MP reaches 0 is "suspended" and may only Attack until
## they have MP again. Also owns this chapter's enemy roster: Security
## Drones, Middle Managers, and the CEO boss.
##
## Plugs into BattleCore through its `faction_rule` hook (see FactionRule),
## via the two per-round/per-action hooks `apply_round_upkeep()` and
## `move_allowed()`. BattleCore itself has no MegaCorp-specific code.
##
## Reference: prototypes/battle-concept/battle.gd iteration 3 (`_is_suspended`,
## `_megacorp_act`, `_end_round()`'s billing block). Reimplemented here, not
## imported.
##
## Usage example:
## [codeblock]
## var enemies: Array[Combatant] = [
##     MegaCorpRule.make_security_drone(), MegaCorpRule.make_middle_manager(),
##     MegaCorpRule.make_ceo(),
## ]
## var battle := BattleCore.new(squad, enemies, null, MegaCorpRule.new())
## [/codeblock]
class_name MegaCorpRule
extends FactionRule

## MP charged to every living squad member once per round (Acceptance
## Criterion 1). This only drains Defend/Special access over time — it never
## blocks Attack (0 MP cost), so a squad member who never regains MP can
## still fight the whole battle (Acceptance Criterion 7). Lowered from the
## prototype's playtested value of 2 (user, 2026-10-21).
const BILL_MP: int = 1

const SECURITY_DRONE_DISPLAY_NAME: String = "Security Drone"
const SECURITY_DRONE_MAX_HP: int = 36
const SECURITY_DRONE_ATTACK: int = 12
const SECURITY_DRONE_DEFENSE: int = 8
const SECURITY_DRONE_SPEED: int = 10

const MIDDLE_MANAGER_DISPLAY_NAME: String = "Middle Manager"
const MIDDLE_MANAGER_MAX_HP: int = 44
const MIDDLE_MANAGER_ATTACK: int = 10
const MIDDLE_MANAGER_DEFENSE: int = 6
const MIDDLE_MANAGER_SPEED: int = 8

const CEO_DISPLAY_NAME: String = "CEO"
const CEO_MAX_HP: int = 120
const CEO_ATTACK: int = 15
const CEO_DEFENSE: int = 10
const CEO_SPEED: int = 9

const LASER_SCAN_POWER: int = 11
const UPSELL_POWER: int = 6
const LAYOFFS_POWER: int = 8
const HOSTILE_TAKEOVER_POWER: int = 18


## A regular MegaCorp enemy for this chapter's non-boss fights (Acceptance
## Criterion 4). It has no MP of its own.
## Example: [code]var drone := MegaCorpRule.make_security_drone()[/code]
## Built from the `enemy_security_drone` record (content-migration story 024,
## merged 025); the constants above are unused until story 030 deletes them.
static func make_security_drone() -> Combatant:
	return EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_security_drone")


## A second regular MegaCorp enemy type for this chapter's non-boss fights
## (Acceptance Criterion 5). It has no MP of its own.
## Example: [code]var manager := MegaCorpRule.make_middle_manager()[/code]
## Built from the `enemy_middle_manager` record (content-migration story 024).
static func make_middle_manager() -> Combatant:
	return EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_middle_manager")


## The MegaCorp boss. He has more HP than a Security Drone or Middle Manager
## (Acceptance Criterion 6) and is flagged `is_boss`.
## Example: [code]var boss := MegaCorpRule.make_ceo()[/code]
## Built from the `enemy_ceo` record (content-migration story 024).
static func make_ceo() -> Combatant:
	return EnemyAdapter.from_catalog(BattleCatalog.shipped(), "enemy_ceo")


## MegaCorp's enemy turn: Security Drones run a Laser Scan on the weakest
## squad member, Middle Managers Upsell (attack) the weakest squad member,
## and the CEO alternates Layoffs (hits everyone, odd rounds) with a Hostile
## Takeover on the weakest squad member (even rounds).
## Example: [code]var actions := rule.choose_enemy_action(drone, battle.get_living_squad(), 1, battle.rng)[/code]
func choose_enemy_action(enemy: Combatant, living_squad: Array[Combatant],
		round_number: int, _rng: RandomNumberGenerator) -> Array:
	var weakest: Combatant = _weakest(living_squad)

	if enemy.is_boss:
		if round_number % 2 == 1:
			var actions: Array = []
			for member in living_squad:
				actions.append({"move": _named_attack("move_layoffs"), "target": member})
			return actions
		return [{"move": _named_attack("move_hostile_takeover"), "target": weakest}]

	if enemy.display_name == MIDDLE_MANAGER_DISPLAY_NAME:
		return [{"move": _named_attack("move_upsell"), "target": weakest}]

	return [{"move": _named_attack("move_laser_scan"), "target": weakest}]


## Every living squad member is billed BILL_MP once per round (Acceptance
## Criterion 1); whoever's MP reaches 0 becomes suspended, enforced by
## move_allowed() below (Acceptance Criterion 2). Reuses Combatant.spend_mp()
## rather than a parallel resource system.
## Example: [code]rule.apply_round_upkeep(battle.get_living_squad())[/code]
func apply_round_upkeep(living_squad: Array[Combatant]) -> void:
	for member in living_squad:
		member.spend_mp(BILL_MP)


## A suspended squad member (0 MP) may only submit Attack — Defend and
## Specials are both rejected (Acceptance Criterion 3). Attack always costs 0
## MP and deals full pipeline damage independent of MP, so this never blocks
## it, keeping a permanently-suspended member able to fight (Acceptance
## Criterion 7).
## Example: [code]rule.move_allowed(member, Move.make_defend())  # false at 0 MP[/code]
func move_allowed(actor: Combatant, move: Move) -> bool:
	return actor.mp > 0 or move.category == Move.Category.ATTACK


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


## Banner headline for the subscription billing rule (Acceptance Criterion
## 6; Story 005). In effect from round 1, so unlike Bureaucratia's this text
## does not vary by round.
func get_banner_text(_round_number: int) -> String:
	return "MEGACORP — Subscription billing. Every squad member pays %d MP at the end of each round. At 0 MP you're SUSPENDED: basic Attack only." % BILL_MP


## MegaCorp Terminal Cyan (art bible), stable for the whole fight (Story 005).
func get_identity_color() -> Color:
	return Color("#19C2D6")


## Plain-language explanation of the billing rule for tooltips (Story 005).
func get_tooltip_text(_round_number: int) -> String:
	return "MegaCorp bills every squad member %d MP at the end of each round. Reaching 0 MP suspends you to basic Attack only until you have MP again." % BILL_MP


## Flags a suspended squad member's card with a plain-language note beyond
## the general billing explanation (Story 005; Acceptance Criterion 3).
func get_combatant_tooltip_note(combatant: Combatant) -> String:
	if not combatant.is_enemy and not combatant.is_knocked_out() and combatant.mp <= 0:
		return "SUSPENDED: out of MP. Basic Attack only until MP is regained."
	return ""
