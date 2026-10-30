## Production `SceneLoader` (ADR-0002 §3, §4; story 014). Owns the single
## live child under `ModeHost`: resolves a mode's scene path from
## `TransitionConfig.mode_scene_paths`, loads and instantiates synchronously
## during SWAP (§3 — MVP scenes are small, so `poll_swap()` always reports
## `DONE` on its very first call). Overworld freeze is detach, never
## serialize (§4): `on_freezing()` runs, then `ModeHost.remove_child()`, and
## the same instance is kept alive, unparented, until the return trip
## re-adds it.
##
## Story 030 adds the real `push_overlay`/`pop_overlay` into `OverlayHost`:
## resolve the overlay path from `TransitionConfig.overlay_scene_paths`,
## instantiate, call `_overlay_pre_setup` (no-op default, `Callable(node)`
## per ADR-0008 §2's amendment), then `node.setup(machine, payload)`, then
## add as the last child of `OverlayHost` (top of stack). Popping frees the
## top. The machine itself is late-bound through `set_machine()`, since this
## loader is a constructor argument of `GameStateMachine` and is built first
## (the same chicken-and-egg note as `_pre_setup` below).
class_name ModeHostSceneLoader extends SceneLoader

var _mode_host: Node
var _overlay_host: Node
var _config: TransitionConfig
var _log: GameStateLog

## Late-bound once the machine exists. Needed only by `push_overlay()`, to
## call `node.setup(machine, payload)` (ADR-0002 Key Interfaces); mode swaps
## still resolve `setup()` through the `_pre_setup` closure below, unchanged
## by this story.
var _machine: GameStateMachine = null

## `(node: GameOverlay) -> void`, called right after a new overlay scene is
## instantiated and before `setup()` (ADR-0008 §2 amendment to ADR-0002:
## `pre_setup: Callable(node)`, distinct in arity from the mode `_pre_setup`
## below since it predates any payload need — `setup()` itself still gets
## the payload). Defaults to a no-op. `GameRoot` binds the production
## version to `UiService.inject(node)`; tests skip it.
var _overlay_pre_setup: Callable

## The live overlay stack, bottom first — last entry is the real top child
## of `OverlayHost`.
var _overlay_nodes: Array[GameOverlay] = []

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

## `OVERWORLD -> OVERWORLD` map change (ADR-0012 §2): the old instance,
## detached but alive until the new one succeeds, and whether the new one
## failed, so `rollback_swap()` can re-add it.
var _replaced_overworld: GameMode = null
var _map_swap_failed: bool = false
var _swap_status: SwapStatus = SwapStatus.DONE
## ADR-0009 §6 (amendment to ADR-0002): `(payload) -> bool`, called in SWAP
## before the target mode is instantiated. `GameRoot` binds it to
## `SaveService.commit_if_loaded`; false fails the swap, so a Continue that
## cannot commit rolls back to Title with nothing built.
var save_commit: Callable = Callable()


func _init(mode_host: Node, config: TransitionConfig, log_sink: GameStateLog,
		pre_setup: Callable = Callable(), payload_commit: Callable = Callable(),
		overlay_host: Node = null, overlay_pre_setup: Callable = Callable()) -> void:
	_mode_host = mode_host
	_config = config
	_log = log_sink
	_pre_setup = pre_setup
	_payload_commit = payload_commit
	_overlay_host = overlay_host
	_overlay_pre_setup = overlay_pre_setup


## Late-bound by the caller right after `GameStateMachine.new(self, ...)`
## (the same pattern as connecting `machine.mode_entered` to
## `on_mode_entered()` elsewhere), so `push_overlay()` can call
## `node.setup(machine, payload)`.
func set_machine(machine: GameStateMachine) -> void:
	_machine = machine


## Synchronous per ADR-0002 §3: every case below finishes before this
## returns, so `poll_swap()` always reports `DONE` on its first call.
func begin_swap(from: int, to: int, payload: RefCounted) -> void:
	_swap_status = SwapStatus.DONE
	if save_commit.is_valid() and payload != null and not bool(save_commit.call(payload)):
		_swap_status = SwapStatus.FAILED
		return
	if from == GameStateMachine.Mode.OVERWORLD and to == GameStateMachine.Mode.BATTLE:
		_freeze_overworld_and_enter_battle(payload)
	elif from == GameStateMachine.Mode.BATTLE and to == GameStateMachine.Mode.OVERWORLD:
		_thaw_overworld()
	elif from == GameStateMachine.Mode.OVERWORLD and to == GameStateMachine.Mode.OVERWORLD:
		_swap_overworld_map(payload)
	else:
		_generic_swap(to, payload)


## `DONE`, or `FAILED` after a map change whose new Overworld could not
## build its map (the machine then calls `rollback_swap()`).
func poll_swap() -> SwapStatus:
	return _swap_status


## Re-attaches a frozen Overworld, if any, and frees a half-built node from
## the failed swap (AC-10). Story 012 owns this case's test coverage. A
## failed map change re-adds the old Overworld instead (ADR-0012 §2).
func rollback_swap() -> void:
	if _map_swap_failed:
		_map_swap_failed = false
		if is_instance_valid(_current_mode_node_ref) and _current_mode_node_ref != _replaced_overworld:
			if _current_mode_node_ref.get_parent() == _mode_host:
				_mode_host.remove_child(_current_mode_node_ref)
			_current_mode_node_ref.queue_free()
		if _replaced_overworld != null:
			_mode_host.add_child(_replaced_overworld)
		_current_mode_node_ref = _replaced_overworld
		_replaced_overworld = null
		return
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


## Story 030 (QA RC-4): resolves `kind`'s path from
## `TransitionConfig.overlay_scene_paths`, instantiates, runs
## `_overlay_pre_setup(node)`, then `node.setup(machine, payload)`, then adds
## as the last child of `OverlayHost` — the new top of the stack. A missing
## `OverlayHost`, an unmapped `kind`, a load failure or a wrong scene root
## type is logged and skipped rather than throwing, matching
## `_instantiate_mode()`'s error handling below.
func push_overlay(kind: int, payload: RefCounted) -> void:
	if _overlay_host == null:
		_log.error(&"overlay_host_missing", {"kind": kind})
		return
	var path: String = String(_config.overlay_scene_paths.get(kind, ""))
	if path.is_empty():
		_log.error(&"overlay_scene_path_missing", {"kind": kind})
		return
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if scene == null:
		_log.error(&"overlay_scene_load_failed", {"kind": kind, "path": path})
		return
	var node: GameOverlay = scene.instantiate() as GameOverlay
	if node == null:
		_log.error(&"overlay_scene_wrong_type", {"kind": kind, "path": path})
		return
	if _overlay_pre_setup.is_valid():
		_overlay_pre_setup.call(node)
	node.setup(_machine, payload)
	_overlay_host.add_child(node)
	_overlay_nodes.append(node)


## Frees the top overlay (the last child of `OverlayHost`). A no-op if the
## stack is empty.
func pop_overlay() -> void:
	if _overlay_nodes.is_empty():
		return
	var node: GameOverlay = _overlay_nodes.pop_back()
	_overlay_host.remove_child(node)
	node.queue_free()


## The live `GameOverlay` node at the top of the stack, or `null` if none.
func current_overlay_node() -> Node:
	if _overlay_nodes.is_empty():
		return null
	return _overlay_nodes.back()


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


## `OVERWORLD -> OVERWORLD` (ADR-0012 §2, annotation on ADR-0002): detach
## the old instance, add the new one with its `MapEntryPayload`, and free
## the old one only when the new one built its map. Otherwise the swap
## reports `FAILED` and `rollback_swap()` re-adds the old one, so `ModeHost`
## never holds two live modes and a missing map scene leaves the party
## where it was.
func _swap_overworld_map(payload: RefCounted) -> void:
	var old: GameMode = _current_mode_node_ref if is_instance_valid(_current_mode_node_ref) else null
	if old != null:
		_mode_host.remove_child(old)
	var node: GameMode = _instantiate_mode(GameStateMachine.Mode.OVERWORLD, payload)
	if node != null:
		_mode_host.add_child(node)
	_current_mode_node_ref = node
	if node == null or node.swap_failed():
		_replaced_overworld = old
		_map_swap_failed = true
		_swap_status = SwapStatus.FAILED
		return
	if old != null:
		old.queue_free()


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
