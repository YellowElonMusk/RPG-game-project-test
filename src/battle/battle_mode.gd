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

## The player's presentation settings view (ADR-0009 §7), injected through
## `pre_setup` before `setup()`; null uses the defaults (every comfort
## setting Off). The replay's speed settings follow its `changed` signal and
## apply from the next `advance()` (ADR-0006 §6; story 056), and the
## hit-punch reads Screen Shake and Reduce Motion from it.
var presentation_settings: PresentationSettings = null

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
## The persistent window behind the command menu (story 060 Finding 1; GDD
## rule 13 "Flash limit"): shown for the whole battle so opening and closing
## the menu changes only its contents, never a large dark area.
var _command_window: Control = null
## The menu's command and target panels the window must enclose.
var _command_panels: Array[Control] = []
## True while a window fit waits for the next process frame.
var _fit_queued: bool = false
## The replay indicator (ADR-0008 §12), built in `setup()`.
var _indicator: ReplayIndicator = null
## Refusal feedback for this mode's presses (ADR-0008 §7): a refused latch
## pulses the indicator when it is visible.
var feedback: UiFeedback = UiFeedback.new()
## The refusal pulse's size and length; the shipped config when not injected.
var ui_config: UiConfig = null
## The Victory results screen (XP and money, F9), built in `setup()`.
var _results_panel: ResultsPanel = null
## The post-alien-boss spare-or-finish choice (narrative bible §6.2).
var _boss_choice: BossChoicePanel = null
## Where the choice's reputation goes (GameRoot injects the Overworld's
## WorldState before `setup()`); null (tests, capture) keeps no score.
var world_state: WorldState = null
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
## The flash gate (ADR-0005 §12), injected by GameRoot before setup(); null
## (tests, capture) plays every gated VFX uncapped.
var flash_gate: FlashGate = null
var _stage: DioramaStage = null
var _spotlight: DefeatSpotlight = null
## Mode-time seconds since the end-of-fight hold started (its light's clock).
var _end_hold_time: float = 0.0
var _descriptor: EncounterDescriptor = null
## Mode-time seconds since `setup()`, advanced by `step_replay()`.
var _mode_time: float = 0.0


## Not `@onready`: `ModeHostSceneLoader` calls `setup()` before `add_child()`
## (ADR-0002 Implementation Notes; same note as `TitleMode.setup()`), and the
## `%` unique-name lookup does not need tree membership.
func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	_hud = %BattleHud
	_stage = %DioramaStage
	_command_menu = %BattleCommandMenu
	_command_window = %CommandWindow
	for panel_path: NodePath in [^"%CommandPanel", ^"%TargetPanel"]:
		var panel: Control = _command_menu.get_node(panel_path)
		_command_panels.append(panel)
		panel.resized.connect(_queue_fit_command_window)
	# The first list is built here, before add_child(), where no fit can queue.
	tree_entered.connect(_queue_fit_command_window)
	_command_menu.visibility_changed.connect(_queue_fit_command_window)
	_build_indicator()
	_build_results_panel()
	var entry: BattleEntryPayload = payload as BattleEntryPayload
	if entry == null or entry.descriptor == null:
		return
	_party = entry.party
	_descriptor = entry.descriptor
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
	# fights) the takeover hold sit ahead of the first turn marker.
	# The wind-up and knockout landing come from each combatant's sprite set
	# through the view (impact_frame / land_frame at 1x); a combatant with no
	# set takes the debug path.
	var view: BattleView = %BattleView
	_replay = BattleReplayController.new(_battle, view.windup_seconds, view.ko_landing_seconds,
			presentation_config)
	_replay.enqueue_reveal_gate()
	if entry.descriptor.is_boss:
		_replay.enqueue_takeover(_find_boss(_battle.enemies),
				BattleReplayController.HoldKind.TAKEOVER_FULL)
	_replay.battle_ended_after_replay.connect(_on_battle_ended_after_replay)
	_hit_punch = HitPunch.new(presentation_config, presentation_settings)
	if presentation_settings != null:
		_apply_speed_settings()
		presentation_settings.changed.connect(_apply_speed_settings)
	_replay.beat_impact.connect(_on_beat_impact)
	_replay.hold_started.connect(_on_hold_started)
	_replay.hold_finished.connect(_on_hold_finished)
	if _stage != null:
		# Story 013 (AC-11): a punch requested during a boss takeover is dropped.
		_hit_punch.takeover_active = _stage.is_takeover_active
	_battle.start_battle(false)
	_replay.resync()
	%BattleView.flash_gate = flash_gate
	%BattleView.setup(_battle, _replay, entry.descriptor, presentation_config)
	_hud.setup(_battle, _replay)
	_command_menu.setup(_battle, _replay)
	if _machine != null:
		_machine.transition_finished.connect(_on_transition_finished)
		_machine.transition_started.connect(_on_transition_started)


## A menu panel resized: fit the window on the next process frame, once the
## containers have sorted. A panel's first layout pass measures its wrapped
## buttons at near-zero width (600+ px tall for that one pass); fitting then
## would lock that height in.
func _queue_fit_command_window() -> void:
	if _fit_queued or not is_inside_tree():
		return
	_fit_queued = true
	get_tree().process_frame.connect(_fit_command_window, CONNECT_ONE_SHOT)


## Grows the command window upward to the visible panel's settled height (the
## window and the panels share the same bottom inset). Grow-only: shrinking
## back on a shorter list would itself be a large-area swing each turn.
func _fit_command_window() -> void:
	_fit_queued = false
	if _command_window == null or not is_instance_valid(_command_menu):
		return
	for panel: Control in _command_panels:
		if panel.is_visible_in_tree() and panel.size.y > _command_window.size.y:
			_command_window.offset_top = _command_window.offset_bottom - panel.size.y


## The shipped bindings the indicator's prompts are labelled from.
const BINDINGS_PATH: String = "res://data/bindings/bindings_default.tres"


## The replay indicator (tests and capture tools).
func replay_indicator() -> ReplayIndicator:
	return _indicator


## Builds the indicator above the command menu, keyboard prompts by default.
## TODO(ui-service): the UI service will set its glyphs from the Input
## System's active device and re-label on `active_device_changed`.
func _build_indicator() -> void:
	if _indicator != null:
		return
	_indicator = ReplayIndicator.new()
	var bindings: InputBindings = load(BINDINGS_PATH) as InputBindings
	_indicator.glyphs = PromptGlyphs.new(bindings)
	add_child(_indicator)
	_indicator.indicator_clicked.connect(_on_indicator_clicked)
	feedback.refused.connect(_on_refused)


## Builds the results screen above everything else in the mode, hidden.
func _build_results_panel() -> void:
	if _results_panel != null:
		return
	_results_panel = ResultsPanel.new(func() -> float: return _mode_time, presentation_config.input_guard)
	add_child(_results_panel)
	_results_panel.continued.connect(_on_results_continued)
	_boss_choice = BossChoicePanel.new(func() -> float: return _mode_time, presentation_config.input_guard)
	add_child(_boss_choice)
	_boss_choice.chosen.connect(_on_boss_chosen)
	_boss_choice.continued.connect(_report_results_done)


## The results screen's Continue: Victory's results are done (Game State
## AC-12: the return to the Overworld starts only now).
func _on_results_continued() -> void:
	if _offers_boss_choice():
		_results_panel.visible = false
		_boss_choice.ask(_find_boss(_battle.enemies).display_name)
		return
	_report_results_done()


func _report_results_done() -> void:
	if not _awaiting_results_done or _machine == null:
		return
	_awaiting_results_done = false
	_machine.report_results_done()


## The spare-or-finish choice follows an alien boss only (narrative bible
## §6.2: ordinary fights and human bosses get no prompt).
func _offers_boss_choice() -> bool:
	if _descriptor == null or not _descriptor.is_boss or _battle == null or _find_boss(_battle.enemies) == null:
		return false
	var faction: Resource = BattleCatalog.shipped().get_record(&"faction", _descriptor.faction_id)
	return faction != null and String(faction.get(&"kind")) == "alien"


## Scores the choice and, on "Finish him off", turns the boss into a pile
## of purple goo (the whole visual, guardrail 2: no gore beyond goo).
func _on_boss_chosen(finished: bool) -> void:
	if world_state != null:
		if finished:
			world_state.street_cred += 1
		else:
			world_state.alien_points += 1
	if not finished:
		return
	var sprite: CharacterSprite = (%BattleView as BattleView).get_sprite(_find_boss(_battle.enemies))
	if sprite != null:
		sprite.create_tween().tween_property(sprite, "goo", 1.0, 0.35)


## The boss choice (tests and capture).
func boss_choice() -> BossChoicePanel:
	return _boss_choice


## The results screen (tests and capture).
func results_panel() -> ResultsPanel:
	return _results_panel


## Shows the indicator's state for this frame: hidden outside a replay.
func _update_indicator() -> void:
	if _indicator == null:
		return
	_indicator.show_state(ReplayInputRouter.INDICATOR_HIDDEN if _replay == null
			else ReplayInputRouter.indicator_state(_replay))


func _on_indicator_clicked() -> void:
	if _replay == null:
		return
	ReplayInputRouter.route(_replay, ReplayInputRouter.ACTION_INDICATOR_CLICK, _refuse)
	_update_indicator()


## A press that changed nothing (ADR-0006 §6): refusal feedback on the
## indicator when it is visible, tick only otherwise (ADR-0008 §7).
func _refuse() -> void:
	feedback.refuse(_indicator if _indicator != null and _indicator.visible else null)


func _on_refused(control: Control) -> void:
	if ui_config == null:
		ui_config = load(UiConfig.DEFAULT_PATH) as UiConfig
	var reduce_motion: bool = presentation_settings != null and presentation_settings.reduce_motion
	RefusalPulse.play(control, ui_config, reduce_motion)


## ADR-0006 §5 "Retry" and "Exit" (story 040, GDD AC-36): every transition
## that starts from Battle -- Retry's Battle -> Battle, Victory/Fled,
## Retreat, Quit to Title -- discards the queued replay and stops the
## end-of-fight hold at the start of OUT, so nothing plays behind the flash
## or wipe and an outcome is never reported for a battle being left. The
## punch ends on this frame too.
func _on_transition_started(from: GameStateMachine.Mode, _to: GameStateMachine.Mode) -> void:
	if from != GameStateMachine.Mode.BATTLE or _replay == null:
		return
	_replay.cancel_pending_replay()
	_end_hold_left = -1.0
	if _hit_punch != null:
		_hit_punch.cancel()
		_step_punch(0.0)
	_stop_takeover_light()


## A takeover HOLD starts (ADR-0006 §5 step 11; story 030): the stage
## reports a takeover for its whole length (story 013), and on first
## encounter the Battle mode requests `boss_<faction>` over `blend_boss`,
## blended on the hold's own clock so it follows the takeover's speed and
## freezes with it. The settle (Retry) already has its light from SWAP.
func _on_hold_started(kind: BattleReplayController.HoldKind, _boss: Combatant) -> void:
	if _stage == null:
		return
	_stage.takeover_hold_active = true
	if kind == BattleReplayController.HoldKind.TAKEOVER_FULL and _stage.has_profiles():
		_stage.request_profile(_fight_profile_id(), presentation_config.blend_boss, _replay.get_hold_time)


func _on_hold_finished(_kind: BattleReplayController.HoldKind) -> void:
	if _stage != null:
		_stage.takeover_hold_active = false


## An exit or Retry mid-takeover (story 030): the hold flag drops and a
## running clock-driven boss blend is stopped where it is (its clock, the
## cancelled hold, would otherwise read 0 and pull the light back). The next
## mode's entry profile, or Retry's own light, replaces it.
func _stop_takeover_light() -> void:
	if _stage == null:
		return
	_stage.takeover_hold_active = false
	if _stage.is_takeover_active() and _stage.current_values != null:
		_stage.apply_profile(_stage.current_values.duplicate() as LightingProfile, 0.0)


## Mode-time seconds since `setup()` (the capped Retry blend's clock).
func _mode_clock() -> float:
	return _mode_time


## The Battle mode is never detached (ADR-0002 §4), so leaving the tree
## means it is being freed: the controller lets go of `BattleCore` and its
## callables (ADR-0006 §8).
func _exit_tree() -> void:
	if _replay != null:
		_replay.dispose()


## Pushes Faster battle animations and Speed up boss entrances to the
## replay; it records them and applies them from the next `advance()`, so a
## change made under the Menu shows on the first frame after it closes.
func _apply_speed_settings() -> void:
	if _replay != null and presentation_settings != null:
		_replay.set_speed_settings(presentation_settings.faster_battle_animations,
				presentation_settings.speed_up_boss_entrances)


## The Defeat spotlight (story 053), or null before a Defeat.
func defeat_spotlight() -> DefeatSpotlight:
	return _spotlight


## Drives the replay and the end-of-fight hold on mode time (ADR-0006 §4/§5).
func _process(delta: float) -> void:
	step_replay(delta)


## One mode-time step: advances the replay, then the end-of-fight hold.
## Public so tests and capture tools can drive the clock explicitly.
func step_replay(delta: float) -> void:
	_mode_time += delta
	if _replay != null:
		_replay.advance(delta)
	if _stage != null:
		_stage.refresh_clock_blend()
	# The punch runs on the replay's clamped step (GDD "One clock"): a slow
	# frame never jumps it by more than dt_max (story 010, AC-8).
	_step_punch(minf(delta, presentation_config.follow_camera_dt_max))
	_update_indicator()
	if _end_hold_left < 0.0:
		return
	_end_hold_left -= delta
	_end_hold_time += delta
	_step_end_light()
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
##
## Before the menu, replay presses route through `ReplayInputRouter`
## (ADR-0006 §6; story 065, GDD AC-60): while replaying, Confirm and
## `fast_forward` latch and Cancel un-latches; while GATED (behind the wipe)
## they are consumed and do nothing, so nothing latches, submits or carries
## over. Only a `pressed` reaches the latch -- a key held from the command's
## own Confirm sends none -- and its release is consumed too.
func handle_action(action: StringName, pressed: bool) -> bool:
	# The results screen owns every press while it is up (its input guard
	# first; GDD rule 9), and only its Continue reports results done.
	if _boss_choice != null and _boss_choice.visible:
		return _boss_choice.handle_action(action, pressed)
	if _results_panel != null and _results_panel.visible:
		return _results_panel.handle_action(action, pressed)
	if _replay != null and _is_replay_press(action) and _replay_owns_input():
		if pressed:
			ReplayInputRouter.route(_replay, action, _refuse)
			_update_indicator()
		return true
	if _command_menu != null and _command_menu.handle_action(action, pressed):
		return true
	return false


## Confirm, `fast_forward` and Cancel: the presses the replay owns.
func _is_replay_press(action: StringName) -> bool:
	return action == InputActions.CONFIRM or action == InputActions.FAST_FORWARD \
			or action == InputActions.CANCEL


## While replaying or GATED the replay owns those presses (ADR-0006 §6);
## during the end-of-fight hold they are consumed and do nothing, so none
## carries into the results screen or the Defeat Prompt (§5; story 067).
func _replay_owns_input() -> bool:
	if _end_hold_left >= 0.0:
		return true
	return _replay.is_replaying() or _replay.get_state() == BattleReplayController.State.GATED


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
	_clear_end_light()
	_awaiting_results_done = false
	start.restore_into(_party)
	BattleCore.clear_transients(_party)
	# ADR-0006 §5 "Retry" step 3: the fight's light back over the Defeat
	# light, hidden behind an uncapped retry flash (blend 0) or blended over
	# blend_defeat when the flash plays capped (story 030). The capped blend
	# runs on mode time, so it is one smooth blend that freezes with the mode.
	_stop_takeover_light()
	if _stage != null and _stage.has_profiles():
		var capped: bool = _machine != null and _machine.is_transition_flash_capped()
		if capped:
			_stage.request_profile(_fight_profile_id(), presentation_config.blend_defeat, _mode_clock)
		else:
			_stage.request_profile(_fight_profile_id(), 0.0)
	# ADR-0006 §5 "Retry" steps 4-5: the retried fight's first turn waits
	# behind a fresh reveal gate (opened by transition_finished(BATTLE) at the
	# end of the retry flash) and, in a boss fight, the takeover settle.
	_replay.enqueue_reveal_gate()
	if _descriptor != null and _descriptor.is_boss:
		_replay.enqueue_takeover(_replay.get_boss_combatant(),
				BattleReplayController.HoldKind.TAKEOVER_SETTLE)
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
	_end_hold_time = 0.0
	_start_end_light(won)


## The Victory or Defeat light (ADR-0006 §5 "End of the fight"; GDD
## "Victory"/"Defeat"). The blend runs on the end-of-fight hold's own
## mode-time clock, so it freezes under the Menu and has always completed
## by the time the hold reports (`blend_* <= *_hold`, load-validated). On
## Defeat the spotlight is aimed at the party row's formation centre (story
## 053) and fades in with the same blend.
func _start_end_light(won: bool) -> void:
	if _stage == null:
		return
	var blend: float = presentation_config.blend_victory if won else presentation_config.blend_defeat
	# A boss Victory keeps the flooded sky (GDD "After a boss fight").
	if won and _descriptor != null and _descriptor.is_boss and _stage.current_values != null:
		_stage.held_sky = _stage.current_values.duplicate() as LightingProfile
	if _stage.has_profiles():
		_stage.request_profile(&"victory" if won else &"defeat", blend, _end_hold_clock)
	if won:
		return
	if _spotlight == null:
		_spotlight = DefeatSpotlight.new()
		_spotlight.name = "DefeatSpotlight"
		_stage.add_child(_spotlight)
		_spotlight.setup(presentation_config)
	_spotlight.aim_at(DefeatSpotlight.formation_centre(%BattleView.party_anchors()))
	_step_end_light()


## The fight's own light: `battle`, or `boss_<faction>` (the takeover's end
## state) in a boss fight.
func _fight_profile_id() -> StringName:
	if _descriptor != null and _descriptor.is_boss:
		return StringName("boss_%s" % _descriptor.faction_id.trim_prefix("faction_"))
	return &"battle"


## The end-of-fight hold's clock: mode-time seconds since it started.
func _end_hold_clock() -> float:
	return _end_hold_time


func _step_end_light() -> void:
	if _stage != null:
		_stage.refresh_clock_blend()
	if _spotlight != null and not _end_won:
		_spotlight.set_progress(DioramaStage.blend_progress(_end_hold_time, presentation_config.blend_defeat))


## Turns the Defeat spotlight off (Retry; story 053).
func _clear_end_light() -> void:
	_end_hold_time = 0.0
	if _spotlight != null:
		_spotlight.set_progress(0.0)


## Reporting after the hold (ADR-0010 §5/§6): Victory waits for the end
## banner's confirm (AC-12) before `report_results_done()`; Defeat reports at
## once and Game State opens the Defeat Prompt. Without a machine (capture
## tools, standalone tests) nothing is reported.
func _report_outcome(won: bool) -> void:
	if won and _results_panel != null and _battle != null:
		var r: Dictionary = BattleRewards.totals(_battle.enemies, BattleCatalog.shipped())
		_results_panel.show_results(int(r["xp"]), int(r["money"]))
	if _machine == null:
		return
	if won:
		_awaiting_results_done = true
		_machine.report_battle_outcome(GameStateMachine.BattleResult.VICTORY)
	else:
		_machine.report_battle_outcome(GameStateMachine.BattleResult.DEFEAT)
