## The turn-based battle state machine: squad vs. enemies, Attack/Defend/
## Special, MP, knockouts, win/loss and retry. Faction rules (Story 002's
## Bureaucratia permit ban, Story 004's MegaCorp billing) are not coded here:
## BattleCore consults an injected FactionRule (see `faction_rule`), which
## defaults to the neutral FactionRule base. No HUD is implemented here —
## Story 005 owns the real battle HUD; this class only reports BattleOutcome
## records a HUD can read.
##
## BattleCore has no scene-tree dependency (RefCounted, not Node), so it can
## be constructed and driven entirely from a unit test or a headless script.
## Its RNG is injected, never global (Stats & Damage GDD F6).
## Not thread-safe: drive it from one thread (normally the main thread).
##
## Usage example:
## [codeblock]
## var squad: Array[Combatant] = [Combatant.new("Hero", 30, 10, 12, 8, 10, false)]
## var enemies: Array[Combatant] = [Combatant.new("Grunt", 20, 0, 10, 6, 8, true)]
## var battle := BattleCore.new(squad, enemies)
## battle.start_battle()
## while battle.state == BattleCore.State.SQUAD_TURN:
##     battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
## print(battle.state)  # BattleCore.State.WON or .LOST
## [/codeblock]
class_name BattleCore
extends RefCounted

enum State { SQUAD_TURN, ENEMY_TURN, WON, LOST }

## Emitted when it becomes a squad member's turn to act (the enemy phase
## resolves without stepping through individual turns).
signal turn_started(combatant: Combatant)
## Emitted once per resolved action, squad or enemy side alike.
signal action_resolved(outcome: BattleOutcome)
## Emitted when a round completes and the next one begins.
signal round_advanced(round_number: int)
## Emitted exactly once when the battle ends. `won` is true on an enemy
## wipeout, false on a squad wipeout.
signal battle_ended(won: bool)

var squad: Array[Combatant] = []
var enemies: Array[Combatant] = []
var rng: RandomNumberGenerator
var round_number: int = 1
var state: State = State.SQUAD_TURN
## Full history of resolved outcomes this battle, in order. A later HUD
## story can read this directly instead of only listening to the signal.
var outcome_log: Array[BattleOutcome] = []
## This battle's faction rule. It decides whether Specials are allowed each
## round and what each enemy does on its turn. It is never null: with no rule
## injected, it is the neutral FactionRule base (Specials always allowed,
## random basic Attack).
var faction_rule: FactionRule

var _active_squad_index: int = 0


func _init(p_squad: Array[Combatant], p_enemies: Array[Combatant],
		p_rng: RandomNumberGenerator = null, p_faction_rule: FactionRule = null) -> void:
	squad = p_squad
	enemies = p_enemies
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	faction_rule = p_faction_rule if p_faction_rule != null else FactionRule.new()


## Resets every combatant to full HP/MP and starts the battle at round 1,
## squad turn. Also doubles as the retry entry point (Acceptance Criterion
## 6): calling this again after a loss restores the exact starting state,
## with no permadeath and no lost progress.
##
## `reset_squad` defaults to true — the original full-reset behavior every
## existing call site relies on (a single standalone battle always wants its
## squad at full HP/MP). Pass false to carry the squad's current HP/MP into
## this battle instead: enemies are still fully reset and first-turn
## selection still runs as normal, but against the squad's current (not
## reset) HP, so a squad member already knocked out in a previous fight is
## correctly skipped rather than being revived and then picked as the active
## turn-taker. Added for Story 006's chapter flow, which must carry HP/MP
## between a chapter's fights without reviving anyone mid-chapter.
func start_battle(reset_squad: bool = true) -> void:
	if reset_squad:
		for combatant in squad:
			combatant.reset_for_battle()
	for combatant in enemies:
		combatant.reset_for_battle()
	round_number = 1
	outcome_log.clear()
	_active_squad_index = 0
	_skip_to_living_squad_member()
	if state == State.SQUAD_TURN:
		turn_started.emit(get_active_combatant())


## Alias for start_battle(), named for the retry call site's intent.
## Example: [code]battle.battle_ended.connect(func(won): if not won: battle.retry_battle())[/code]
func retry_battle() -> void:
	start_battle()


## Clears every per-fight transient on `party` (`is_defending`, `is_stunned`,
## `vulnerable_rounds_left`) without touching HP/MP (ADR-0010 §7's named
## writers list). The Battle mode calls this before every `start_battle(false)`
## -- both on first entry and on Retry (ADR-0002 §7 amendment; ADR-0006 §5
## step 2) -- because `start_battle(false)` leaves the party's own state
## untouched, so a Defend or debuff left over from the previous fight would
## otherwise carry into this one. Replaces the retired
## `ChapterFlow._clear_squad_transients()`.
## Example: [code]BattleCore.clear_transients(party)[/code]
static func clear_transients(party: Array[Combatant]) -> void:
	for combatant in party:
		combatant.is_defending = false
		combatant.is_stunned = false
		combatant.vulnerable_rounds_left = 0


## Squad members with HP above 0, in turn order.
## Example: [code]var alive := battle.get_living_squad()[/code]
func get_living_squad() -> Array[Combatant]:
	var living: Array[Combatant] = []
	for combatant in squad:
		if not combatant.is_knocked_out():
			living.append(combatant)
	return living


## Enemies with HP above 0, in turn order. Only these are legal Attack targets.
## Example: [code]battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])[/code]
func get_living_enemies() -> Array[Combatant]:
	var living: Array[Combatant] = []
	for combatant in enemies:
		if not combatant.is_knocked_out():
			living.append(combatant)
	return living


## The squad member whose turn it currently is, or null outside SQUAD_TURN.
## Example: [code]var actor := battle.get_active_combatant()[/code]
func get_active_combatant() -> Combatant:
	if state != State.SQUAD_TURN or _active_squad_index >= squad.size():
		return null
	return squad[_active_squad_index]


## Resolves one action for the active squad combatant: Attack damages
## `target`, Defend halves incoming damage until the actor's next turn, and
## a Special spends its MP cost and resolves its `special_effect` (Story 003:
## stun, heal-party, heal-single, damage-debuff, or direct-damage — see
## `src/battle/squad/specials.gd`).
##
## Returns the BattleOutcome for this action, or null if the action was
## illegal (wrong turn, a Special while faction_rule bans Specials this round,
## a move faction_rule.move_allowed() rejects (e.g. MegaCorp suspension —
## Story 004), insufficient MP, or an invalid/knocked-out target) — in which
## case no state changes.
##
## When this ends the squad's actions for the round, the enemy phase and
## any following round advance happen synchronously inside this call; their
## outcomes are appended to outcome_log and emitted via action_resolved, not
## returned here.
##
## Example:
## [codeblock]
## var outcome := battle.submit_action(Move.make_attack(), battle.get_living_enemies()[0])
## if outcome != null:
##     print(outcome.hp_delta)
## [/codeblock]
func submit_action(move: Move, target: Combatant = null) -> BattleOutcome:
	if state != State.SQUAD_TURN:
		push_error("BattleCore.submit_action called outside SQUAD_TURN")
		return null
	var actor := get_active_combatant()
	if actor == null:
		push_error("BattleCore.submit_action called with no active combatant")
		return null
	if move.category == Move.Category.SPECIAL and not faction_rule.specials_allowed(round_number):
		push_error("BattleCore.submit_action: %s is a Special, and Specials are banned in round %d" % [
			move.display_name, round_number])
		return null
	if not faction_rule.move_allowed(actor, move):
		push_error("BattleCore.submit_action: %s is not allowed for %s right now (faction rule)" % [
			move.display_name, actor.display_name])
		return null
	if not actor.can_afford(move.mp_cost):
		push_error("BattleCore.submit_action: %s cannot afford %s (needs %d MP, has %d)" % [
			actor.display_name, move.display_name, move.mp_cost, actor.mp])
		return null
	var resolved_target := _validate_and_resolve_target(actor, move, target)
	if move.target_type != Move.TargetType.SELF and resolved_target == null:
		push_error("BattleCore.submit_action: invalid target for %s" % move.display_name)
		return null

	var outcome := _resolve_move(actor, move, resolved_target)

	if _check_battle_end():
		return outcome

	_active_squad_index += 1
	_skip_to_living_squad_member()
	if state == State.SQUAD_TURN:
		turn_started.emit(get_active_combatant())
	else:
		_run_enemy_phase()
	return outcome


func _validate_and_resolve_target(actor: Combatant, move: Move, target: Combatant) -> Combatant:
	match move.target_type:
		Move.TargetType.SELF:
			return null
		Move.TargetType.SINGLE_ENEMY:
			if target == null or target.is_knocked_out() or not _are_foes(actor, target):
				return null
			return target
		Move.TargetType.SINGLE_ALLY:
			if target == null or target.is_knocked_out() or _are_foes(actor, target):
				return null
			return target
	return null


func _are_foes(a: Combatant, b: Combatant) -> bool:
	return a.is_enemy != b.is_enemy


func _resolve_move(actor: Combatant, move: Move, target: Combatant) -> BattleOutcome:
	var hp_delta: int = 0
	var mp_delta: int = 0
	var target_knocked_out: bool = false

	if move.mp_cost > 0:
		actor.spend_mp(move.mp_cost)
		mp_delta = -move.mp_cost

	match move.category:
		Move.Category.ATTACK:
			hp_delta = -_apply_damage(actor, target, move.power)
			target_knocked_out = target.is_knocked_out()
		Move.Category.DEFEND:
			actor.is_defending = true
		Move.Category.SPECIAL:
			match move.special_effect:
				Move.SpecialEffect.STUN:
					SquadSpecials.apply_stun(target)
				Move.SpecialEffect.HEAL_PARTY:
					var side := get_living_enemies() if actor.is_enemy else get_living_squad()
					hp_delta = SquadSpecials.heal_party(actor, side, move.power)
				Move.SpecialEffect.HEAL_SINGLE:
					hp_delta = SquadSpecials.heal_single(actor, target, move.power)
				Move.SpecialEffect.DAMAGE_DEBUFF:
					SquadSpecials.apply_vulnerable(target, move.effect_rounds)
				Move.SpecialEffect.DIRECT_DAMAGE:
					hp_delta = -_apply_damage(actor, target, move.power)
					target_knocked_out = target.is_knocked_out()
				Move.SpecialEffect.NONE:
					pass  # No effect — not a real Special (shouldn't normally happen).

	var outcome := BattleOutcome.new(actor, move.display_name, move.category,
			target, hp_delta, mp_delta, target_knocked_out, round_number)
	outcome_log.append(outcome)
	action_resolved.emit(outcome)
	return outcome


## Shared by Move.Category.ATTACK and Move.SpecialEffect.DIRECT_DAMAGE (Home
## Run): runs the same damage pipeline (Stats & Damage F3/F5/F6/F7) so the
## two call sites can't drift apart. Returns the HP actually removed.
func _apply_damage(attacker: Combatant, defender: Combatant, power: int) -> int:
	var amount: int = DamageCalculator.calculate_damage(attacker, defender, power, rng)
	return defender.take_damage(amount)


func _skip_to_living_squad_member() -> void:
	while _active_squad_index < squad.size() and squad[_active_squad_index].is_knocked_out():
		_active_squad_index += 1
	if _active_squad_index < squad.size():
		# Defend lasts "until their next turn": this is that turn starting.
		squad[_active_squad_index].is_defending = false
		state = State.SQUAD_TURN
	else:
		state = State.ENEMY_TURN


## Each living enemy takes its turn in order. faction_rule.choose_enemy_action()
## chooses the turn, which may be several actions (for example Defend, then
## Attack). The actions resolve in sequence. An action whose target is already
## knocked out is skipped. A stunned enemy (Karen's Speak to the Manager,
## Story 003) skips its whole turn once and the flag clears, the same
## "set once, cleared on the next turn" shape is_defending uses.
func _run_enemy_phase() -> void:
	state = State.ENEMY_TURN
	for enemy in enemies:
		if enemy.is_knocked_out():
			continue
		var living_squad := get_living_squad()
		if living_squad.is_empty():
			break
		enemy.is_defending = false
		if enemy.is_stunned:
			enemy.is_stunned = false
			continue
		var actions: Array = faction_rule.choose_enemy_action(enemy, living_squad, round_number, rng)
		for action: Dictionary in actions:
			var move: Move = action.get("move")
			var target: Combatant = action.get("target")
			if target != null and target.is_knocked_out():
				continue
			_resolve_move(enemy, move, target)
			if _check_battle_end():
				return
	_tick_round_effects()
	faction_rule.apply_round_upkeep(get_living_squad())
	_advance_round()


## Decrements Viral Stunt's per-round debuff (Story 003) for every combatant,
## squad and enemies alike, once per round. Unlike is_defending/is_stunned
## (cleared on the owner's next turn), this is round-based, so it ticks here
## rather than in _skip_to_living_squad_member()/_run_enemy_phase()'s per-turn
## clears.
func _tick_round_effects() -> void:
	for combatant in squad + enemies:
		if combatant.vulnerable_rounds_left > 0:
			combatant.vulnerable_rounds_left -= 1


func _advance_round() -> void:
	round_number += 1
	_active_squad_index = 0
	_skip_to_living_squad_member()
	round_advanced.emit(round_number)
	if state == State.SQUAD_TURN:
		turn_started.emit(get_active_combatant())


func _check_battle_end() -> bool:
	if get_living_enemies().is_empty():
		state = State.WON
		battle_ended.emit(true)
		return true
	if get_living_squad().is_empty():
		state = State.LOST
		battle_ended.emit(false)
		return true
	return false
