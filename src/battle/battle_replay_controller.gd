## Holds every `BattleCore` signal in emission order and replays it as
## timed beats on its own clocks, never mutating `BattleCore` (ADR-0006
## Battle Replay Ownership; GDD sprite-camera-presentation P-04/P-05, AC-13,
## AC-14, AC-23, AC-38, AC-39). Only the Battle mode's `_process` calls
## `advance()`; presentation reads the three clocks and the displayed state.
##
## Usage example:
## [codeblock]
## var replay := BattleReplayController.new(battle, windup_fn, ko_landing_fn, config)
## replay.enqueue_reveal_gate()
## battle.start_battle(false)
## replay.resync()
## # transition_finished(BATTLE):
## replay.open_reveal_gate()
## # Battle mode _process:
## replay.advance(delta)
## [/codeblock]
class_name BattleReplayController
extends RefCounted

## Controller state (ADR-0006 §3).
enum State { IDLE, GATED, PLAYING, DISPOSED }
## The two boss takeover holds.
enum HoldKind { TAKEOVER_FULL, TAKEOVER_SETTLE }

## Event tolerance in seconds (ADR-0006 §4).
const EPSILON: float = 1e-6

enum _Kind { GATE, HOLD, OUTCOME, ROUND, TURN, END }

## The first HOLD or OUTCOME of a replay starts.
signal replay_started()
## The replay ends, before the TURN/END marker that ends it is released.
signal replay_finished()
## `cancel_pending_replay()` discarded something.
signal replay_cancelled()
## `resync()` replaced the displayed state with the live state.
signal display_resynced()
## The latch changed.
signal latch_changed(latched: bool)
## `is_press_effective()` changed.
signal press_effective_changed(effective: bool)
## A HOLD entry starts.
signal hold_started(kind: HoldKind, boss: Combatant)
## A HOLD entry ends.
signal hold_finished(kind: HoldKind)
## An OUTCOME starts; its wind-up clock is 0.
signal beat_started(plan: BeatPlan)
## The wind-up reached the impact; the post-impact clock is 0.
signal beat_impact(plan: BeatPlan)
## The beat ended; displayed state is already the beat's snapshot.
signal beat_finished(plan: BeatPlan)
## A ROUND marker was released.
signal round_advanced_after_replay(round_number: int)
## A TURN marker was released.
signal turn_started_after_replay(combatant: Combatant)
## An END marker was released.
signal battle_ended_after_replay(won: bool)

var _battle: BattleCore
var _windup: Callable
var _ko_landing: Callable
var _config: PresentationConfig
var _state: State = State.IDLE
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _impacted: bool = false
var _windup_progress: float = 0.0
var _post_impact_time: float = 0.0
var _elapsed: float = 0.0
var _hold_time: float = 0.0
var _latched: bool = false
var _battle_speed_on: bool = false
var _speed_up_boss: bool = false
var _replay_running: bool = false
var _effective: bool = false
var _boss: Combatant
## Most recently released snapshot: {"displays": Combatant -> CombatantDisplay, "round": int}.
var _displayed: Dictionary = {"displays": {}, "round": 0}
## Most recently recorded snapshot (the "previous snapshot" for plans).
var _recorded: Dictionary = {"displays": {}, "round": 0}


## `windup(plan: BeatPlan) -> float`: 1x wind-up seconds, or -1.0 if the actor
## has no action animation. `ko_landing(combatant: Combatant) -> float`: 1x
## seconds from knockout start to its land_frame. Defaults exist only so
## test doubles can construct it; the Battle mode always passes all four.
func _init(battle: BattleCore = null, windup: Callable = Callable(),
		ko_landing: Callable = Callable(), config: PresentationConfig = null) -> void:
	_battle = battle
	_windup = windup
	_ko_landing = ko_landing
	_config = config
	if _battle == null:
		return
	_battle.action_resolved.connect(_on_action_resolved)
	_battle.round_advanced.connect(_on_round_advanced)
	_battle.turn_started.connect(_on_turn_started)
	_battle.battle_ended.connect(_on_battle_ended)
	_recorded = _take_snapshot()
	_displayed = _recorded


# --- Queue control -----------------------------------------------------------

## Queues a reveal gate; nothing behind it starts until `open_reveal_gate()`.
func enqueue_reveal_gate() -> void:
	_enqueue({"kind": _Kind.GATE})


## Opens the gate at the head of the queue. Markers behind it are released
## at once; a timed entry starts on the next `advance()`.
func open_reveal_gate() -> void:
	if _state != State.GATED or _queue.is_empty():
		return
	_queue.pop_front()
	_state = State.PLAYING
	_release_markers()
	_settle_idle_state()
	_update_effective()


## Queues a boss takeover HOLD and records `boss` as the fight's boss.
func enqueue_takeover(boss: Combatant, kind: HoldKind) -> void:
	_boss = boss
	_enqueue({"kind": _Kind.HOLD, "hold_kind": kind, "boss": boss})


# --- Clock -------------------------------------------------------------------

## Advances the entry in progress by the mode-time `delta` (ADR-0006 §4):
## guard, clamp to `dt_max`, step (at most one event), release markers,
## start the next entry. Leftover time past an event is dropped.
func advance(delta: float) -> void:
	if _state == State.DISPOSED or _state == State.GATED or _state == State.IDLE:
		return
	assert(_config != null, "BattleReplayController.advance() needs a PresentationConfig")
	var dt: float = clampf(delta, 0.0, _config.follow_camera_dt_max)
	if not _current.is_empty():
		_step_current(dt)
	if _current.is_empty():
		_release_markers()
		_start_next()
	_update_effective()


# --- Input and settings ------------------------------------------------------

## Sets the latch; false (refuse the press) unless PLAYING, unlatched and
## press-effective.
func request_latch() -> bool:
	if _state != State.PLAYING or _latched or not is_press_effective():
		return false
	_latched = true
	latch_changed.emit(true)
	_update_effective()
	return true


## Clears the latch; false (refuse the press) unless latched and
## press-effective.
func clear_latch() -> bool:
	if not _latched or not is_press_effective():
		return false
	_latched = false
	latch_changed.emit(false)
	_update_effective()
	return true


## Applies Faster battle animations and Speed up boss entrances from the
## next `advance()`.
func set_speed_settings(battle_speed_on: bool, speed_up_boss: bool) -> void:
	_battle_speed_on = battle_speed_on
	_speed_up_boss = speed_up_boss
	_update_effective()


# --- Queries -----------------------------------------------------------------

## The controller state.
func get_state() -> State:
	return _state


## True exactly while PLAYING.
func is_replaying() -> bool:
	return _state == State.PLAYING


## True while the one-level latch is set.
func is_latched() -> bool:
	return _latched


## True iff some remaining time depends on the latch (ADR-0006 §6): a
## non-debug wind-up, a TAKEOVER_SETTLE hold, or a TAKEOVER_FULL hold with
## Speed up boss entrances On. Post-impact holds never count.
func is_press_effective() -> bool:
	if _state != State.PLAYING:
		return false
	if not _current.is_empty():
		if _current["kind"] == _Kind.OUTCOME:
			var plan: BeatPlan = _current["plan"]
			if not _impacted and not plan.is_debug_path():
				return true
		elif _hold_counts(_current):
			return true
	for entry: Dictionary in _queue:
		if entry["kind"] == _Kind.OUTCOME and not (entry["plan"] as BeatPlan).is_debug_path():
			return true
		if entry["kind"] == _Kind.HOLD and _hold_counts(entry):
			return true
	return false


## The plan in progress, or null.
func get_current_plan() -> BeatPlan:
	if not _current.is_empty() and _current["kind"] == _Kind.OUTCOME:
		return _current["plan"]
	return null


## 1x seconds of wind-up played.
func get_windup_progress() -> float:
	return _windup_progress if get_current_plan() != null else 0.0


## Unscaled seconds since `beat_impact`; 0 before it.
func get_post_impact_time() -> float:
	return _post_impact_time if (get_current_plan() != null and _impacted) else 0.0


## The HOLD clock in seconds; 0 unless a HOLD is in progress.
func get_hold_time() -> float:
	if not _current.is_empty() and _current["kind"] == _Kind.HOLD:
		return _hold_time
	return 0.0


## The fight's boss, or null.
func get_boss_combatant() -> Combatant:
	return _boss


## A copy of `combatant`'s values from the most recently released snapshot.
func get_display(combatant: Combatant) -> CombatantDisplay:
	var displays: Dictionary = _displayed["displays"]
	if displays.has(combatant):
		return (displays[combatant] as CombatantDisplay).copy()
	return CombatantDisplay.new()


## Shorthand for `get_display(combatant).hp`.
func get_display_hp(combatant: Combatant) -> int:
	return get_display(combatant).hp


## The round of the most recently released snapshot.
func get_display_round() -> int:
	return int(_displayed["round"])


# --- Lifecycle ---------------------------------------------------------------

## Discards the queue, any entry in progress and the latch; returns to IDLE.
## Displayed state is left as it was.
func cancel_pending_replay() -> void:
	if _state == State.DISPOSED:
		return
	var discarded: bool = not _queue.is_empty() or not _current.is_empty()
	_queue.clear()
	_current = {}
	_reset_clocks()
	_replay_running = false
	_state = State.IDLE
	if _latched:
		_latched = false
		latch_changed.emit(false)
	if discarded:
		replay_cancelled.emit()
	_update_effective()


## Re-takes the settled snapshot from live state and displays it. A queued
## or in-progress OUTCOME is a programming error.
func resync() -> void:
	if _state == State.DISPOSED or _battle == null:
		return
	if not _current.is_empty() and _current["kind"] == _Kind.OUTCOME:
		push_error("BattleReplayController.resync(): an OUTCOME is in progress")
		return
	for entry: Dictionary in _queue:
		if entry["kind"] == _Kind.OUTCOME:
			push_error("BattleReplayController.resync(): an OUTCOME is queued")
			return
	_recorded = _take_snapshot()
	_displayed = _recorded
	display_resynced.emit()


## Cancels, disconnects from `BattleCore`, drops the callables and config,
## and enters DISPOSED. Idempotent.
func dispose() -> void:
	if _state == State.DISPOSED:
		return
	cancel_pending_replay()
	if _battle != null:
		if _battle.action_resolved.is_connected(_on_action_resolved):
			_battle.action_resolved.disconnect(_on_action_resolved)
		if _battle.round_advanced.is_connected(_on_round_advanced):
			_battle.round_advanced.disconnect(_on_round_advanced)
		if _battle.turn_started.is_connected(_on_turn_started):
			_battle.turn_started.disconnect(_on_turn_started)
		if _battle.battle_ended.is_connected(_on_battle_ended):
			_battle.battle_ended.disconnect(_on_battle_ended)
	_windup = Callable()
	_ko_landing = Callable()
	_config = null
	_state = State.DISPOSED


# --- BattleCore listeners (read-only) ----------------------------------------

func _on_action_resolved(outcome: BattleOutcome) -> void:
	if _state == State.DISPOSED:
		return
	var snap: Dictionary = _take_snapshot()
	var plan: BeatPlan = BeatPlan.build(outcome, _recorded["displays"], snap["displays"],
			_boss, _windup, _ko_landing, _config)
	_recorded = snap
	_enqueue({"kind": _Kind.OUTCOME, "plan": plan, "snap": snap})


func _on_round_advanced(round_number: int) -> void:
	_on_marker({"kind": _Kind.ROUND, "n": round_number})


func _on_turn_started(combatant: Combatant) -> void:
	_on_marker({"kind": _Kind.TURN, "c": combatant})


func _on_battle_ended(won: bool) -> void:
	_on_marker({"kind": _Kind.END, "won": won})


func _on_marker(entry: Dictionary) -> void:
	if _state == State.DISPOSED:
		return
	var snap: Dictionary = _take_snapshot()
	_recorded = snap
	entry["snap"] = snap
	_enqueue(entry)


# --- Internals ---------------------------------------------------------------

func _enqueue(entry: Dictionary) -> void:
	if _state == State.DISPOSED:
		return
	_queue.append(entry)
	if _state == State.IDLE:
		if _is_marker(entry) and _queue.size() == 1:
			_release_markers()
		else:
			_settle_idle_state()
	_update_effective()


## Sets the state from the queue without starting anything: GATED behind a
## gate, PLAYING with a timed entry pending, IDLE when empty.
func _settle_idle_state() -> void:
	if _current.is_empty() and _queue.is_empty():
		_state = State.IDLE
		_end_replay_if_running()
	elif _current.is_empty() and _queue[0]["kind"] == _Kind.GATE:
		_state = State.GATED
	else:
		_state = State.PLAYING


func _step_current(dt: float) -> void:
	if _current["kind"] == _Kind.HOLD:
		var duration: float = _hold_duration(_current["hold_kind"])
		_hold_time += dt * _hold_speed(_current["hold_kind"])
		if _hold_time >= duration - EPSILON:
			var kind: HoldKind = _current["hold_kind"]
			_current = {}
			hold_finished.emit(kind)
		return
	var plan: BeatPlan = _current["plan"]
	_elapsed += dt
	if not _impacted:
		_windup_progress += dt * _beat_speed(plan)
		if _windup_progress >= _windup_target(plan) - EPSILON:
			_impacted = true
			_post_impact_time = 0.0
			beat_impact.emit(plan)
		return
	_post_impact_time += dt
	if _post_impact_time >= plan.hold - EPSILON and _elapsed >= _config.beat_min - EPSILON:
		_displayed = _current["snap"]
		_current = {}
		beat_finished.emit(plan)


func _release_markers() -> void:
	while not _queue.is_empty() and _is_marker(_queue[0]):
		var entry: Dictionary = _queue.pop_front()
		_displayed = entry["snap"]
		match entry["kind"]:
			_Kind.ROUND:
				round_advanced_after_replay.emit(int(entry["n"]))
			_Kind.TURN:
				_end_replay_if_running()
				turn_started_after_replay.emit(entry["c"])
			_Kind.END:
				_end_replay_if_running()
				battle_ended_after_replay.emit(bool(entry["won"]))


func _start_next() -> void:
	if _queue.is_empty():
		_state = State.IDLE
		_end_replay_if_running()
		return
	var head: Dictionary = _queue[0]
	if head["kind"] == _Kind.GATE:
		_state = State.GATED
		return
	_queue.pop_front()
	_state = State.PLAYING
	_reset_clocks()
	_current = head
	if not _replay_running:
		_replay_running = true
		replay_started.emit()
	if head["kind"] == _Kind.HOLD:
		hold_started.emit(head["hold_kind"], head["boss"])
		return
	var plan: BeatPlan = head["plan"]
	beat_started.emit(plan)
	if _windup_target(plan) <= EPSILON:
		_impacted = true
		beat_impact.emit(plan)


func _end_replay_if_running() -> void:
	if not _replay_running:
		return
	_replay_running = false
	if _latched:
		_latched = false
		latch_changed.emit(false)
	replay_finished.emit()


func _update_effective() -> void:
	var now: bool = is_press_effective()
	if now != _effective:
		_effective = now
		press_effective_changed.emit(now)


func _reset_clocks() -> void:
	_impacted = false
	_windup_progress = 0.0
	_post_impact_time = 0.0
	_elapsed = 0.0
	_hold_time = 0.0


func _plain_speed() -> float:
	return maxf(_config.ff_mult if _latched else 1.0,
			_config.battle_speed_mult if _battle_speed_on else 1.0)


func _beat_speed(plan: BeatPlan) -> float:
	return 1.0 if plan.is_debug_path() else _plain_speed()


func _windup_target(plan: BeatPlan) -> float:
	if plan.is_debug_path():
		return _config.beat_min - _config.reaction_hold
	return plan.windup_1x


func _hold_speed(kind: HoldKind) -> float:
	if kind == HoldKind.TAKEOVER_FULL and not _speed_up_boss:
		return 1.0
	return _plain_speed()


func _hold_duration(kind: HoldKind) -> float:
	if kind == HoldKind.TAKEOVER_FULL:
		return _config.blend_boss + _config.boss_hold
	return _config.boss_retry_hold


func _hold_counts(entry: Dictionary) -> bool:
	return entry["hold_kind"] == HoldKind.TAKEOVER_SETTLE or _speed_up_boss


func _is_marker(entry: Dictionary) -> bool:
	var k: int = entry["kind"]
	return k == _Kind.ROUND or k == _Kind.TURN or k == _Kind.END


func _take_snapshot() -> Dictionary:
	var displays: Dictionary = {}
	for c: Combatant in _battle.squad + _battle.enemies:
		displays[c] = CombatantDisplay.from_combatant(c)
	return {"displays": displays, "round": _battle.round_number}
