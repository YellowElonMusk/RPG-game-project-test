## A command a combatant can choose on their turn: Attack, Defend, or a
## Special. This story only needs the generic plumbing for Specials (MP
## cost, target, resolve) — individual special effects are Story 003's scope.
##
## Usage example:
## [codeblock]
## var attack := Move.make_attack()
## var defend := Move.make_defend()
## var test_special := Move.new("Test Special", Move.Category.SPECIAL, 4, 0,
##     Move.TargetType.SINGLE_ENEMY)
## [/codeblock]
class_name Move
extends RefCounted

## Move categories. Specials are a distinct category from Attack/Defend per
## Acceptance Criterion 7; what a given special *does* is out of this
## story's scope.
enum Category { ATTACK, DEFEND, SPECIAL }

## Who a move can legally target. "Enemy"/"ally" are relative to the acting
## combatant's side, so the same move definition works for squad and enemy
## actors alike.
enum TargetType { SELF, SINGLE_ENEMY, SINGLE_ALLY }

var display_name: String
var category: Category
var mp_cost: int
## Move strength for damage-category resolution (Stats & Damage F3). Unused
## by Defend and by Specials (no effect is defined yet).
var power: int
var target_type: TargetType


func _init(p_display_name: String, p_category: Category, p_mp_cost: int,
		p_power: int, p_target_type: TargetType) -> void:
	display_name = p_display_name
	category = p_category
	mp_cost = p_mp_cost
	power = p_power
	target_type = p_target_type


## The basic Attack every combatant has: 0 MP cost, power 10 (Stats & Damage
## F3's "power 10 = basic attack"), targets one foe.
static func make_attack() -> Move:
	return Move.new("Attack", Category.ATTACK, 0, 10, TargetType.SINGLE_ENEMY)


## The basic Defend every combatant has: 0 MP cost, halves incoming damage
## until the user's next turn (DamageCalculator applies the F5 modifier).
static func make_defend() -> Move:
	return Move.new("Defend", Category.DEFEND, 0, 0, TargetType.SELF)
