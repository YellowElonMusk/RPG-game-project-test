## A single battle participant: squad member or enemy.
##
## Combatant is a plain data/behavior object with no scene-tree dependency,
## so it can be constructed and tested without running the engine's main loop.
##
## Usage example:
## [codeblock]
## var hero := Combatant.new("Recruit", 30, 10, 12, 8, 10, false)
## hero.take_damage(12)
## print(hero.hp)  # 18
## [/codeblock]
class_name Combatant
extends RefCounted

## Display name shown to the player (and later HUD).
var display_name: String

## Base stats (Stats & Damage GDD F1 ranges).
var max_hp: int
var max_mp: int
var attack: int
var defense: int
var speed: int

## True for an enemy-side combatant, false for a squad member.
var is_enemy: bool

## True for a boss-tier enemy. Unused by this story's rules; carried so later
## faction stories (Story 002/004) can key boss-only behavior off it.
var is_boss: bool = false

## Current HP/MP. Clamped to [0, max_*] by take_damage()/heal()/spend_mp().
var hp: int
var mp: int

## Set by the Defend move; halves incoming damage (Stats & Damage F5) until
## this combatant's own next turn starts, when BattleCore clears it.
var is_defending: bool = false

## Set by Karen's Speak to the Manager special (Story 003): this combatant
## loses its next turn. BattleCore clears it the moment that turn is skipped,
## the same "set once, cleared on the next turn" shape as `is_defending`.
var is_stunned: bool = false

## Rounds remaining of Florida Man's Viral Stunt special (Story 003): while
## greater than 0, this combatant takes extra damage (DamageCalculator's F5
## modifier, `VULNERABLE_PCT`). Unlike `is_defending`/`is_stunned`, this ticks
## down once per round (BattleCore._tick_round_effects()), not per turn.
var vulnerable_rounds_left: int = 0


func _init(p_display_name: String, p_max_hp: int, p_max_mp: int, p_attack: int,
		p_defense: int, p_speed: int, p_is_enemy: bool, p_is_boss: bool = false) -> void:
	display_name = p_display_name
	max_hp = p_max_hp
	max_mp = p_max_mp
	attack = p_attack
	defense = p_defense
	speed = p_speed
	is_enemy = p_is_enemy
	is_boss = p_is_boss
	hp = p_max_hp
	mp = p_max_mp


## True once HP has reached 0. A knocked-out combatant is skipped in turn
## order and is not a legal damage target (Acceptance Criterion 4).
func is_knocked_out() -> bool:
	return hp <= 0


## Applies damage, clamping HP to [0, max_hp]. Returns the amount actually
## removed from HP (less than `amount` only when it would overkill).
func take_damage(amount: int) -> int:
	var before: int = hp
	hp = clampi(hp - amount, 0, max_hp)
	return before - hp


## Restores HP, clamping to [0, max_hp]. Returns the amount actually restored.
func heal(amount: int) -> int:
	var before: int = hp
	hp = clampi(hp + amount, 0, max_hp)
	return hp - before


## Spends MP, clamped so it never goes negative. Caller should check
## can_afford() first.
func spend_mp(amount: int) -> void:
	mp = clampi(mp - amount, 0, max_mp)


## True if this combatant has at least `mp_cost` MP.
func can_afford(mp_cost: int) -> bool:
	return mp >= mp_cost


## Resets HP/MP to full and clears transient battle state. Used by
## BattleCore.start_battle() / retry_battle() so a retry has no permadeath
## and no lost progress (Acceptance Criterion 6).
func reset_for_battle() -> void:
	hp = max_hp
	mp = max_mp
	is_defending = false
	is_stunned = false
	vulnerable_rounds_left = 0
