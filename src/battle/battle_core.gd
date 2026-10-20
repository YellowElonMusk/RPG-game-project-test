## The turn-based battle state machine: squad vs. enemies, Attack/Defend/
## Special, MP, knockouts, win/loss and retry. No faction rule (permit ban,
## billing) is implemented here — Stories 002/004 add those on top. No HUD
## is implemented here — Story 005 owns the real battle HUD; this class only
## reports BattleOutcome records a HUD can read.
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

var _active_squad_index: int = 0


func _init(p_squad: Array[Combatant], p_enemies: Array[Combatant],
		p_rng: RandomNumberGenerator = null) -> void:
	squad = p_squad
	enemies = p_enemies
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Resets every combatant to full HP/MP and starts the battle at round 1,
## squad turn. Also doubles as the retry entry point (Acceptance Criterion
## 6): calling this again after a loss restores the exact starting state,
## with no permadeath and no lost progress.
func start_battle() -> void:
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
## a Special spends its MP cost and resolves its target with no further
## effect (Acceptance Criterion 7 — effects are Story 003's scope).
##
## Returns the BattleOutcome for this action, or null if the action was
## illegal (wrong turn, insufficient MP, or an invalid/knocked-out target) —
## in which case no state changes.
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
			var amount: int = DamageCalculator.calculate_damage(actor, target, move.power, rng)
			var removed: int = target.take_damage(amount)
			hp_delta = -removed
			target_knocked_out = target.is_knocked_out()
		Move.Category.DEFEND:
			actor.is_defending = true
		Move.Category.SPECIAL:
			pass  # Plumbing only — no effect defined yet (Story 003).

	var outcome := BattleOutcome.new(actor, move.display_name, move.category,
			target, hp_delta, mp_delta, target_knocked_out, round_number)
	outcome_log.append(outcome)
	action_resolved.emit(outcome)
	return outcome


func _skip_to_living_squad_member() -> void:
	while _active_squad_index < squad.size() and squad[_active_squad_index].is_knocked_out():
		_active_squad_index += 1
	if _active_squad_index < squad.size():
		# Defend lasts "until their next turn": this is that turn starting.
		squad[_active_squad_index].is_defending = false
		state = State.SQUAD_TURN
	else:
		state = State.ENEMY_TURN


## Placeholder enemy AI: every living enemy makes a basic power-10 Attack on
## a random living squad member. Deliberately neutral — faction AI (Story
## 002's hunker-down, Story 004's drones) replaces or extends this.
func _run_enemy_phase() -> void:
	state = State.ENEMY_TURN
	for enemy in enemies:
		if enemy.is_knocked_out():
			continue
		var living_squad := get_living_squad()
		if living_squad.is_empty():
			break
		enemy.is_defending = false
		var target: Combatant = living_squad[rng.randi_range(0, living_squad.size() - 1)]
		_resolve_move(enemy, Move.make_attack(), target)
		if _check_battle_end():
			return
	_advance_round()


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
