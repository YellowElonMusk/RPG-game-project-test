## The Battle mode: wraps `BattleCore` + `BattleHud` and owns Retry's start
## snapshot (ADR-0002 §7, ADR-0006 §5, ADR-0010 §3/§5/§7). Built once per
## battle entry and kept alive for the whole fight including every Retry
## (ADR-0010 §6: one `BattleCore` for its whole life) -- `GameStateMachine`
## always calls `restore_start_snapshot()` on this same instance, never
## instantiates a new one for a Retry.
##
## Owns the fight's `BattleReplayController` (ADR-0006 §5; sprite-camera
## story 033, GDD sprite-camera-presentation AC-29): the HUD and command menu
## listen only to its gated `*_after_replay` signals, so after a command the
## turn plays back beat by beat and the menu reopens only when the next turn
## is released. The outcome reaches Game State only after the last beat and
## the end-of-fight hold (`victory_hold`/`defeat_hold`, on mode time). Steps
## still owned by later stories stay marked TODO(battle-replay).
class_name BattleMode extends GameMode

## Presentation tuning for the replay clocks and end-of-fight holds. Set
## before `setup()` to inject a non-default config (tests); the defaults
## live in `PresentationConfig` itself.
var presentation_config: PresentationConfig = PresentationConfig.new()

## The fight's replay controller (ADR-0006), read-only. `null` when entry
## failed to build.
var replay: BattleReplayController:
	get:
		return _replay

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
var _replay: BattleReplayController = null
## Seconds left in the end-of-fight hold; negative when no hold is running.
var _end_hold_left: float = -1.0
var _end_won: bool = false
## The hit-punch (GDD rule 8; ADR-0005 §6): started on each beat's impact,
## advanced on mode time, written to the stage's lens shift every frame.
var _hit_punch: HitPunch = null
var _stage: DioramaStage = null


## Not `@onready`: `ModeHostSceneLoader` calls `setup()` before `add_child()`
## (ADR-0002 Implementation Notes; same note as `TitleMode.setup()`), and the
## `%` unique-name lookup does not need tree membership.
func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	_hud = %BattleHud
	_stage = %DioramaStage
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
	# ADR-0006 §5 steps 4-6: the controller, the reveal gate and (boss
	# fights) the takeover hold sit ahead of the first turn marker. No sprite
	# animations exist yet, so both callables are empty: every beat takes
	# the debug path (`beat_min`), which needs no animation data.
	# TODO(sprite-camera): pass the real windup / ko_landing callables once
	# battle sprites exist.
	_replay = BattleReplayController.new(_battle, Callable(), Callable(), presentation_config)
	_replay.enqueue_reveal_gate()
	if entry.descriptor.is_boss:
		_replay.enqueue_takeover(_find_boss(_battle.enemies),
				BattleReplayController.HoldKind.TAKEOVER_FULL)
	_replay.battle_ended_after_replay.connect(_on_battle_ended_after_replay)
	_hit_punch = HitPunch.new(presentation_config)
	_replay.beat_impact.connect(_on_beat_impact)
	_battle.start_battle(false)
	_replay.resync()
	%BattleView.setup(_battle, _replay, entry.descriptor, presentation_config)
	_hud.setup(_battle, _replay)
	_command_menu.setup(_battle, _replay)
	if _machine != null:
		_machine.transition_finished.connect(_on_transition_finished)


## Drives the replay and the end-of-fight hold on mode time (ADR-0006 §4/§5).
func _process(delta: float) -> void:
	step_replay(delta)


## One mode-time step: advances the replay, then the end-of-fight hold.
## Public so tests and capture tools can drive the clock explicitly.
func step_replay(delta: float) -> void:
	if _replay != null:
		_replay.advance(delta)
	_step_punch(delta)
	if _end_hold_left < 0.0:
		return
	_end_hold_left -= delta
	if _end_hold_left <= BattleReplayController.EPSILON:
		_end_hold_left = -1.0
		_report_outcome(_end_won)


## True while the replay or the end-of-fight hold still has something to play.
func is_presenting() -> bool:
	if _end_hold_left >= 0.0:
		return true
	return _replay != null and _replay.get_state() == BattleReplayController.State.PLAYING


## Plays the queued replay and the end-of-fight hold to the end at once, in
## `follow_camera_dt_max` steps (tests and debug tooling only; never called
## by the game itself). Does not open a closed reveal gate.
func settle_replay() -> void:
	var guard: int = 0
	while is_presenting() and guard < 10000:
		step_replay(presentation_config.follow_camera_dt_max)
		guard += 1


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
	# ADR-0006 §5 "Retry" step 1.
	_replay.cancel_pending_replay()
	if _hit_punch != null:
		_hit_punch.cancel()
		_step_punch(0.0)
	_end_hold_left = -1.0
	_awaiting_results_done = false
	start.restore_into(_party)
	BattleCore.clear_transients(_party)
	# TODO(battle-replay): (ADR-0006 §5 "Retry" step 3): request the retry-flash light through
	# stage.request_profile(), blended or hidden by
	# machine.is_transition_flash_capped(), once Presentation exists.
	# TODO(battle-replay): (ADR-0006 §5 "Retry" steps 4-5): reveal gate / takeover hold.
	# The controller is IDLE after the cancel, so this first turn marker is
	# released at once and reopens the command menu (story 040 owns the rest).
	_battle.start_battle(false)
	_replay.resync()
	_hud.refresh()


## Rule 8: one punch per beat, on its impact. The view shifts toward the
## side that was hit -- up into the enemy line when the squad lands a blow,
## down into the squad when an enemy does.
func _on_beat_impact(plan: BeatPlan) -> void:
	var dir: Vector2 = Vector2.DOWN if plan.actor.is_enemy else Vector2.UP
	plan.start_punch(_hit_punch, _replay.get_boss_combatant(), dir)


func _step_punch(delta: float) -> void:
	if _hit_punch == null or _stage == null:
		return
	# Offset first: a punch started this frame shows at t = 0 (rule 8).
	_stage.set_punch_offset_px(_hit_punch.current_offset_px(_stage.battle_viewport_height()))
	_hit_punch.advance(delta)


func _has_exactly_one_boss(enemies: Array[Combatant]) -> bool:
	var count: int = 0
	for enemy: Combatant in enemies:
		if enemy.is_boss:
			count += 1
	return count == 1


func _find_boss(enemies: Array[Combatant]) -> Combatant:
	for enemy: Combatant in enemies:
		if enemy.is_boss:
			return enemy
	return null


## The reveal gate opens when the swap into Battle finishes (ADR-0006 §5).
func _on_transition_finished(to: GameStateMachine.Mode) -> void:
	if to == GameStateMachine.Mode.BATTLE and _replay != null:
		_replay.open_reveal_gate()


## ADR-0006 §5 "End of the fight": the last beat has played; start the
## end-of-fight hold, after which the outcome is reported.
func _on_battle_ended_after_replay(won: bool) -> void:
	_end_won = won
	_end_hold_left = presentation_config.victory_hold if won else presentation_config.defeat_hold


## Reporting after the hold (ADR-0010 §5/§6): Victory waits for the end
## banner's confirm (AC-12) before `report_results_done()`; Defeat reports at
## once and Game State opens the Defeat Prompt.
func _report_outcome(won: bool) -> void:
	if won:
		_awaiting_results_done = true
		_machine.report_battle_outcome(GameStateMachine.BattleResult.VICTORY)
	else:
		_machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
