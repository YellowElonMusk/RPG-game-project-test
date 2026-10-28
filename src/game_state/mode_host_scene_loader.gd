## Production `SceneLoader` (ADR-0002 §3, §4; story 014). Owns the single
## live child under `ModeHost`: resolves a mode's scene path from
## `TransitionConfig.mode_scene_paths`, loads and instantiates synchronously
## during SWAP (§3 — MVP scenes are small, so `poll_swap()` always reports
## `DONE` on its very first call). Overworld freeze is detach, never
## serialize (§4): `on_freezing()` runs, then `ModeHost.remove_child()`, and
## the same instance is kept alive, unparented, until the return trip
## re-adds it. Overlay push/pop into the real `OverlayHost` is story 030, so
## this file inherits the base `SceneLoader`'s overlay no-ops unchanged.
class_name ModeHostSceneLoader extends SceneLoader

var _mode_host: Node
var _config: TransitionConfig
var _log: GameStateLog

## `(mode: GameMode, payload: RefCounted) -> void`, called right after a new
## mode scene is instantiated and before `add_child()`. This loader has no
## reference to `GameStateMachine` (it is itself a constructor argument of
## the machine, so it is built first) — the production call site binds a
## closure here to run `mode.setup(machine, payload)`. Defaults to a no-op,
## so a test that does not care about `setup()` can ignore this entirely.
var _pre_setup: Callable

## `() -> int`, called once per Battle -> Overworld thaw to learn the
## `GameStateMachine.BattleResult` for `on_thawed()`. This is this story's
## resolution of a real gap: `GameStateMachine.report_battle_outcome()` /
## `report_results_done()` both call `begin_swap(BATTLE, OVERWORLD, null)` —
## the outcome never reaches `begin_swap`'s own `payload` argument, for
## either Victory or Fled (verified by reading `game_state_machine.gd`,
## committed story 001). An invalid Callable, or a `-1` return, skips
## `on_thawed()` and logs a warning — "no-op" by default, per the
## Implementation Notes. Flagged in story 014's Completion Notes as a
## deviation worth an ADR-0002 amendment once story 015/016 land, since
## those stories are the ones that will actually own the outcome value.
var _payload_commit: Callable

var _current_mode_node_ref: GameMode = null
var _frozen_overworld: GameMode = null
var _pending_encounter_id: String = ""

var _pending_thaw_overworld: GameMode = null
var _pending_thaw_result: int = -1


func _init(mode_host: Node, config: TransitionConfig, log_sink: GameStateLog,
		pre_setup: Callable = Callable(), payload_commit: Callable = Callable()) -> void:
	_mode_host = mode_host
	_config = config
	_log = log_sink
	_pre_setup = pre_setup
	_payload_commit = payload_commit


## Synchronous per ADR-0002 §3: every case below finishes before this
## returns, so `poll_swap()` always reports `DONE` on its first call.
func begin_swap(from: int, to: int, payload: RefCounted) -> void:
	if from == GameStateMachine.Mode.OVERWORLD and to == GameStateMachine.Mode.BATTLE:
		_freeze_overworld_and_enter_battle(payload)
	elif from == GameStateMachine.Mode.BATTLE and to == GameStateMachine.Mode.OVERWORLD:
		_thaw_overworld()
	else:
		_generic_swap(to, payload)


func poll_swap() -> SwapStatus:
	return SwapStatus.DONE


## Re-attaches a frozen Overworld, if any, and frees a half-built node from
## the failed swap (AC-10). Story 012 owns this case's test coverage.
func rollback_swap() -> void:
	if _frozen_overworld == null:
		return
	if is_instance_valid(_current_mode_node_ref) and _current_mode_node_ref != _frozen_overworld:
		_mode_host.remove_child(_current_mode_node_ref)
		_current_mode_node_ref.queue_free()
	_mode_host.add_child(_frozen_overworld)
	_current_mode_node_ref = _frozen_overworld
	_frozen_overworld = null


## Frees the detached Overworld instance explicitly (ADR-0002 §4 — Retreat,
## Quit to Title, `GameRoot._exit_tree()`); an unparented node is not freed
## by its old parent.
func free_frozen_overworld() -> void:
	if _frozen_overworld != null:
		_frozen_overworld.queue_free()
		_frozen_overworld = null


## Toggles `ModeHost.process_mode` for the Menu's time stop (ADR-0002 §5,
## story 025): `PROCESS_MODE_DISABLED` while the Menu is open, which freezes
## `_process`/`_physics_process`, `Timer`s, node-bound `Tween`s and
## `AnimationPlayer`s for the whole mode subtree (verified on 4.7.2, this
## story's verification item 3). `PROCESS_MODE_INHERIT` otherwise.
## The engine's global pause flag and global time-scale property are never
## used for this (ADR-0002 §5, Control Manifest Forbidden rule).
func set_mode_time_stopped(stopped: bool) -> void:
	_mode_host.process_mode = Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT


func current_mode_node() -> Node:
	return _current_mode_node_ref


## Connect this to `GameStateMachine.mode_entered` (both `GameRoot` and this
## story's test do). `mode_entered` fires synchronously from inside the
## machine's own SWAP-end handling, before this loader gets another call —
## so the only way to run `on_thawed()` strictly after it (ADR-0002 §4) is
## as a second listener on the same signal, not from `begin_swap`/`poll_swap`.
func on_mode_entered(to: GameStateMachine.Mode) -> void:
	if to != GameStateMachine.Mode.OVERWORLD or _pending_thaw_overworld == null:
		return
	var overworld: GameMode = _pending_thaw_overworld
	var result: int = _pending_thaw_result
	var encounter_id: String = _pending_encounter_id
	_pending_thaw_overworld = null
	_pending_thaw_result = -1
	_pending_encounter_id = ""
	if result == -1:
		_log.warning(&"on_thawed_skipped_no_result", {"encounter_id": encounter_id})
		return
	overworld.on_thawed(encounter_id, result as GameStateMachine.BattleResult)


func _freeze_overworld_and_enter_battle(payload: RefCounted) -> void:
	var overworld: GameMode = _current_mode_node_ref
	if overworld != null:
		overworld.on_freezing()
		_mode_host.remove_child(overworld)
	_frozen_overworld = overworld
	if payload is BattleEntryPayload and (payload as BattleEntryPayload).descriptor != null:
		_pending_encounter_id = (payload as BattleEntryPayload).descriptor.encounter_id
	var battle_node: GameMode = _instantiate_mode(GameStateMachine.Mode.BATTLE, payload)
	if battle_node != null:
		_mode_host.add_child(battle_node)
	_current_mode_node_ref = battle_node


func _thaw_overworld() -> void:
	var battle_node: GameMode = _current_mode_node_ref
	if is_instance_valid(battle_node):
		_mode_host.remove_child(battle_node)
		battle_node.queue_free()
	var overworld: GameMode = _frozen_overworld
	_frozen_overworld = null
	if overworld != null:
		_mode_host.add_child(overworld)
	_current_mode_node_ref = overworld
	_pending_thaw_overworld = overworld
	_pending_thaw_result = _payload_commit.call() as int if _payload_commit.is_valid() else -1


func _generic_swap(to: int, payload: RefCounted) -> void:
	if is_instance_valid(_current_mode_node_ref):
		_mode_host.remove_child(_current_mode_node_ref)
		_current_mode_node_ref.queue_free()
	var node: GameMode = _instantiate_mode(to, payload)
	if node != null:
		_mode_host.add_child(node)
	_current_mode_node_ref = node


func _instantiate_mode(mode: int, payload: RefCounted) -> GameMode:
	var path: String = String(_config.mode_scene_paths.get(mode, ""))
	if path.is_empty():
		return null
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if scene == null:
		_log.error(&"mode_scene_load_failed", {"mode": mode, "path": path})
		return null
	var node: GameMode = scene.instantiate() as GameMode
	if _pre_setup.is_valid():
		_pre_setup.call(node, payload)
	return node
