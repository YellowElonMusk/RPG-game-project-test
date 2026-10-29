## The Battle mode: wraps `BattleCore` + `BattleHud` and owns Retry's start
## snapshot (ADR-0002 §7, ADR-0006 §5, ADR-0010 §3/§5/§7). Built once per
## battle entry and kept alive for the whole fight including every Retry
## (ADR-0010 §6: one `BattleCore` for its whole life) -- `GameStateMachine`
## always calls `restore_start_snapshot()` on this same instance, never
## instantiates a new one for a Retry.
##
## No `BattleReplayController` exists yet (ADR-0006 is not implemented): every
## step that ADR-0006 §5 assigns to it is marked TODO(battle-replay) below and skipped. The
## "first entry" and "Retry" orders here are ADR-0006 §5's own orders with
## those steps removed, per this story's Implementation Notes.
class_name BattleMode extends GameMode

## The live `BattleCore`, exposed read-only so a test can drive it directly
## (`battle.submit_action(...)`) without a command-menu UI, which does not
## exist yet (a later story's scope). `null` only when entry failed to build
## (unknown enemy/faction id, or a bad boss count) -- `capture_start_snapshot()`
## then returns `null`, which Game State treats as a swap failure (ADR-0002 §7).
var battle: BattleCore:
	get:
		return _battle

var _battle: BattleCore = null
## The requester's own `Combatant` instances (`BattleEntryPayload.party`),
## never copied -- carryover is these same objects changed in place
## (ADR-0002 §7).
var _party: Array[Combatant] = []
var _machine: GameStateMachine = null
var _hud: BattleHud = null
## The command menu (Story 007): built once per scene instance, like `_hud`.
var _command_menu: BattleCommandMenu = null
## One RNG per Battle-mode instance (ADR-0010 §3): never recreated, never
## restored on Retry, so a retried fight draws fresh variance.
var _rng: RandomNumberGenerator = null
## True from the Victory light (TODO(battle-replay), ADR-0006 §5 -- interim: set directly on
## `battle_ended(true)`) until the player confirms the end banner, so
## `report_results_done()` fires only then (AC-12).
var _awaiting_results_done: bool = false


## Not `@onready`: `ModeHostSceneLoader` calls `setup()` before `add_child()`
## (ADR-0002 Implementation Notes; same note as `TitleMode.setup()`), and the
## `%` unique-name lookup does not need tree membership.
func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	_hud = %BattleHud
	_command_menu = %BattleCommandMenu
	var entry: BattleEntryPayload = payload as BattleEntryPayload
	if entry == null or entry.descriptor == null:
		return
	_party = entry.party
	_rng = RandomNumberGenerator.new()
	var result: BattleFactory.BattleBuildResult = BattleFactory.build(entry, _rng)
	if result.core == null:
		return
	_battle = result.core
	BattleCore.clear_transients(_party)
	if entry.descriptor.is_boss and not _has_exactly_one_boss(_battle.enemies):
		# ADR-0006 §5 step 3: none or more than one boss is a descriptor
		# validation failure -- leave _battle null so capture_start_snapshot()
		# fails the swap (ADR-0002 §7) instead of starting a broken fight.
		_battle = null
		return
	# TODO(battle-replay): (ADR-0006 §5 steps 4-6): construct BattleReplayController, enqueue
	# the reveal gate and (boss fights) the takeover hold, once it exists.
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.start_battle(false)
	_hud.setup(_battle)
	_command_menu.setup(_battle)


## `true` = consumed. The results-done confirm keeps priority while Victory
## is pending (Implementation Notes); the command menu (Story 007) gets
## every other action while it is visible, and hides itself outside
## `SQUAD_TURN` (including while Victory's results confirm is pending).
func handle_action(action: StringName, pressed: bool) -> bool:
	if _awaiting_results_done and pressed and action == InputActions.CONFIRM:
		_awaiting_results_done = false
		_machine.report_results_done()
		return true
	if _command_menu != null and _command_menu.handle_action(action, pressed):
		return true
	return false


## Battle only (ADR-0002 Key Interfaces). `null` is itself a swap failure --
## see the class doc comment.
func capture_start_snapshot() -> RefCounted:
	if _battle == null:
		return null
	return BattleStartSnapshot.capture(_party)


## Retry (ADR-0002 §7, ADR-0010 §5 "Retry"): restores the party's HP/MP from
## the handle, clears transients, and restarts the same `BattleCore` --
## `start_battle(false)` also unconditionally resets every enemy
## (`BattleCore.start_battle()`'s own contract), so the enemy roster needs no
## snapshot of its own.
func restore_start_snapshot(snapshot: RefCounted) -> void:
	var start: BattleStartSnapshot = snapshot as BattleStartSnapshot
	if start == null or _battle == null:
		return
	# TODO(battle-replay): (ADR-0006 §5 "Retry" step 1): controller.cancel_pending_replay(),
	# once it exists.
	start.restore_into(_party)
	BattleCore.clear_transients(_party)
	# TODO(battle-replay): (ADR-0006 §5 "Retry" step 3): request the retry-flash light through
	# stage.request_profile(), blended or hidden by
	# machine.is_transition_flash_capped(), once Presentation exists.
	# TODO(battle-replay): (ADR-0006 §5 "Retry" steps 4-5): reveal gate / takeover hold.
	_battle.start_battle(false)
	# TODO(battle-replay): (ADR-0006 §5 "Retry" step 7): controller.resync(), once it exists.
	_hud.refresh()


func _has_exactly_one_boss(enemies: Array[Combatant]) -> bool:
	var count: int = 0
	for enemy: Combatant in enemies:
		if enemy.is_boss:
			count += 1
	return count == 1


## Interim reporting (ADR-0010 §5/§6; ADR-0006 §5 "End of the fight" without
## the controller's holds -- TODO(battle-replay) once it exists): Victory waits for the end
## banner's confirm (AC-12) before `report_results_done()`; Defeat reports at
## once and Game State opens the Defeat Prompt. Connected before
## `_hud.setup(_battle)` in `setup()`, so this always runs -- and therefore
## `report_battle_outcome()` is always recorded -- before the HUD's own
## `battle_ended` handler repaints the end banner (QA Check 3).
func _on_battle_ended(won: bool) -> void:
	if won:
		_awaiting_results_done = true
		_machine.report_battle_outcome(GameStateMachine.BattleResult.VICTORY)
	else:
		_machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
