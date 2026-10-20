## A command a combatant can choose on their turn: Attack, Defend, or a
## Special. Generic plumbing (MP cost, target, resolve) was Story 001's scope;
## Story 003 adds `SpecialEffect`, the field that tells BattleCore which
## effect a given Special resolves to (stun, heal, damage-debuff, or direct
## damage) without a separate system parallel to Attack/Defend.
##
## Usage example:
## [codeblock]
## var attack := Move.make_attack()
## var defend := Move.make_defend()
## var test_special := Move.new("Test Special", Move.Category.SPECIAL, 4, 0,
##     Move.TargetType.SINGLE_ENEMY, Move.SpecialEffect.STUN)
## [/codeblock]
class_name Move
extends RefCounted

## Move categories. Specials are a distinct category from Attack/Defend per
## Acceptance Criterion 7; what a given special *does* is `special_effect`
## (Story 003).
enum Category { ATTACK, DEFEND, SPECIAL }

## Who a move can legally target. "Enemy"/"ally" are relative to the acting
## combatant's side, so the same move definition works for squad and enemy
## actors alike.
enum TargetType { SELF, SINGLE_ENEMY, SINGLE_ALLY }

## Which effect a SPECIAL move resolves to (Story 003, `src/battle/squad/
## specials.gd`). Meaningless outside `category == SPECIAL`, where it stays
## NONE. STUN/HEAL_PARTY/HEAL_SINGLE/DIRECT_DAMAGE read `power` (where
## applicable) as their magnitude; DAMAGE_DEBUFF reads `effect_rounds` as its
## duration instead (its magnitude is a DamageCalculator constant, mirroring
## how Defend's -50% is a constant rather than per-move data).
enum SpecialEffect { NONE, STUN, HEAL_PARTY, HEAL_SINGLE, DAMAGE_DEBUFF, DIRECT_DAMAGE }

var display_name: String
var category: Category
var mp_cost: int
## Move strength for damage-category resolution (Stats & Damage F3) and for
## heal resolution (F4). Unused by Defend, by STUN, and by DAMAGE_DEBUFF
## (Story 003) — those effects carry no power value of their own.
var power: int
var target_type: TargetType
## Only meaningful when `category == SPECIAL` (see `SpecialEffect`).
var special_effect: SpecialEffect
## Effect duration in rounds. Only meaningful for `SpecialEffect.DAMAGE_DEBUFF`
## (Florida Man's Viral Stunt); 0 for every other move.
var effect_rounds: int


func _init(p_display_name: String, p_category: Category, p_mp_cost: int,
		p_power: int, p_target_type: TargetType,
		p_special_effect: SpecialEffect = SpecialEffect.NONE,
		p_effect_rounds: int = 0) -> void:
	display_name = p_display_name
	category = p_category
	mp_cost = p_mp_cost
	power = p_power
	target_type = p_target_type
	special_effect = p_special_effect
	effect_rounds = p_effect_rounds


## The basic Attack every combatant has: 0 MP cost, power 10 (Stats & Damage
## F3's "power 10 = basic attack"), targets one foe.
static func make_attack() -> Move:
	return Move.new("Attack", Category.ATTACK, 0, 10, TargetType.SINGLE_ENEMY)


## The basic Defend every combatant has: 0 MP cost, halves incoming damage
## until the user's next turn (DamageCalculator applies the F5 modifier).
static func make_defend() -> Move:
	return Move.new("Defend", Category.DEFEND, 0, 0, TargetType.SELF)
