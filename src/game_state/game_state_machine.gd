## Pure logic core for Game State & Scene Flow (ADR-0002 §1). `RefCounted`:
## it never references the scene tree, `get_tree()`, an autoload by name,
## `Time`, or `Engine`. Time enters only through `tick(delta)`; every
## collaborator enters only through `_init`. Created once by `GameRoot` and
## injected into every mode, overlay and Presentation-layer service — never
## looked up by name and never an autoload.
class_name GameStateMachine extends RefCounted

enum Mode { BOOT, CONTENT_ERROR, TITLE, OVERWORLD, BATTLE, CAMP }
enum OverlayKind { DIALOGUE, MENU, DEFEAT_PROMPT }
enum Phase { IDLE, OUT, SWAP, IN }
enum RequestResult { OK, REJECTED_BUSY, REJECTED_INVALID_PAIR, REJECTED_TERMINAL,
		REJECTED_OVERLAY_BLOCKS, REJECTED_INVALID_PAYLOAD }
enum BattleResult { VICTORY, FLED, DEFEAT }

## No accumulated phase time ever needs to land exactly on a float duration:
## a phase ends on the first `tick()` where the accumulated phase time is
## `>= duration - _PHASE_EPSILON`. Overshoot is not carried into the next phase.
const _PHASE_EPSILON: float = 1e-9

## The transitions table (ADR-0002 §9): a game rule from the GDD, not a
## tuning value. Anchored against the GDD's Modes transitions table by
## story-002's `test_table_matches_gdd`; every enumerated transition type
## (`fade`, `battle_wipe`, `battle_wipe_reverse`, `retry_flash`, `none`)
## appears at least once. Outcome-driven rows (Battle -> Overworld/Battle/Camp)
## are reachable only through `report_battle_outcome()` / `report_results_done()`
## / `choose_retry()` / `choose_retreat()`, never through `request_transition()`
## (draft §2 item 7, accepted) — see `_REQUESTABLE_TARGETS` below.
## Every mode's row to `TITLE` (story 025, ADR-0002 §4/§5 ruling 2026-10-23)
## is `fade` -- the Menu's Quit to Title, never requestable through the
## ordinary `_REQUESTABLE_TARGETS` path (see below), only through
## `request_transition(TITLE)` while `MENU` is the top overlay. Overworld's row
## to itself (story 002, GDD "move to another map or region") is an ordinary
## fresh-instance swap through `request_transition()`, distinct from the
## in-mode fade's same-instance checkpoint redirect (`request_in_mode_fade()`,
## ADR-0002 §11, story 028) which never appears in this table.
const _TRANSITION_TYPES: Dictionary = {
	Mode.BOOT: {Mode.TITLE: &"fade", Mode.CONTENT_ERROR: &"none"},
	Mode.TITLE: {Mode.OVERWORLD: &"fade"},
	Mode.OVERWORLD: {Mode.BATTLE: &"battle_wipe", Mode.CAMP: &"fade", Mode.TITLE: &"fade",
			Mode.OVERWORLD: &"fade"},
	Mode.BATTLE: {Mode.OVERWORLD: &"battle_wipe_reverse", Mode.BATTLE: &"retry_flash",
			Mode.CAMP: &"fade", Mode.TITLE: &"fade"},
	Mode.CAMP: {Mode.OVERWORLD: &"fade", Mode.TITLE: &"fade"},
}

## The subset of `_TRANSITION_TYPES` legal through `request_transition()`'s
## ordinary (no-overlay) path. Boot's two rows are internal (driven by
## `tick()` reading the catalog); Battle's outbound rows are outcome-driven
## (see above); every mode's row to `TITLE` is reachable only through the
## Menu's Quit to Title (`request_transition()`'s overlay-stack branch),
## deliberately absent here.
const _REQUESTABLE_TARGETS: Dictionary = {
	Mode.TITLE: [Mode.OVERWORLD],
	Mode.OVERWORLD: [Mode.BATTLE, Mode.CAMP, Mode.OVERWORLD],
	Mode.CAMP: [Mode.OVERWORLD],
}

## Flash-gate source IDs (ADR-0002 amendment, ruling 2026-10-23): one
## `StringName` constant per flashing transition type, passed to
## `FlashGate.request()` so the gate can tell bookings apart.
const FLASH_SOURCE_RETRY: StringName = &"retry_flash"
const FLASH_SOURCE_BATTLE_WIPE: StringName = &"battle_wipe"
const FLASH_SOURCE_BATTLE_WIPE_REVERSE: StringName = &"battle_wipe_reverse"

## Story 024: the action that opens the Menu overlay (ADR-0003 `InputActions`).
const _MENU_ACTION: StringName = InputActions.MENU

## Rule 10 (ADR-0002 §6, §10): the modes the Menu overlay may open over,
## checked by the machine's own `action_pressed(&"menu")` interception (story
## 024) ahead of the full overlay "can open over" table (story 023, deferred
## pending Dialogue). Battle is on this list regardless of what overlay (if
## any) already sits on top of it, so the Menu opens over the Defeat Prompt
## too (story 030).
const _MENU_ALLOWED_MODES: Array[Mode] = [Mode.OVERWORLD, Mode.CAMP, Mode.BATTLE]

## Rule 10 (ADR-0002 §5-§6, story 029): the Menu's entries by mode, pinned
## order. Battle (including Battle with the Defeat Prompt on top) is cut down
## to settings and quit; Overworld and Camp get the full menu.
const _MENU_ENTRIES_BATTLE: Array[StringName] = [&"settings", &"quit"]
const _MENU_ENTRIES_FULL: Array[StringName] = [
	&"pause", &"party", &"codex", &"settings", &"quit"]

## The transition types that flash, and each one's source id. `fade` and
## `none` are absent on purpose: ADR-0002 §11 forbids `fade` from ever
## consulting the gate, and `none` never plays anything.
const _FLASH_SOURCE_BY_TYPE: Dictionary = {
	&"retry_flash": FLASH_SOURCE_RETRY,
	&"battle_wipe": FLASH_SOURCE_BATTLE_WIPE,
	&"battle_wipe_reverse": FLASH_SOURCE_BATTLE_WIPE_REVERSE,
}

# The GDD's six announcements (Rule 4), names unchanged.
signal transition_started(from: Mode, to: Mode)
signal mode_exited(from: Mode)
signal mode_entered(to: Mode)
signal transition_finished(to: Mode)
signal overlay_opened(kind: OverlayKind)
signal overlay_closed(kind: OverlayKind)

var current_mode: Mode:
	get:
		return _current_mode

## Copy, bottom first.
var overlay_stack: Array[OverlayKind]:
	get:
		return _overlay_stack.duplicate()

var phase: Phase:
	get:
		return _phase

## Stops advancing while the Menu overlay is open (AC-20).
var mode_time: float:
	get:
		return _mode_time

## Read-only to everyone but the machine (ADR-0002 §11, control manifest). A
## plain GDScript property with only a getter still accepts assignment into
## its own storage, so this setter explicitly rejects an outside write: it
## logs and never assigns. The machine writes `_last_camp_id` directly,
## bypassing this setter (`register_camp()`, and `CampEntryPayload` handling).
var last_camp_id: String:
	get:
		return _last_camp_id
	set(value):
		_log.warning(&"last_camp_write_rejected", {"attempted": value})

## Measured sum of OUT + SWAP + IN's actual accumulated `tick()` time for the
## most recently finished transition (ADR-0002 §9, story 006). Used by
## story 007 (overrun warning) and story 037 (hardware benchmark).
var last_transition_time: float:
	get:
		return _last_transition_time

## Measured SWAP-phase time for the most recently finished transition. Zero
## for an in-mode fade's zero-length SWAP (ADR-0002 §11).
var last_t_swap: float:
	get:
		return _last_t_swap

## Tick-accumulated clock that, unlike `mode_time`, never stops (not even
## while the Menu is open) and is never read from `Time` (ADR-0002 amendment,
## ruling 2026-10-23). Passed to `FlashGate.request()`.
var real_time: float:
	get:
		return _real_time

var _current_mode: Mode = Mode.BOOT
var _phase: Phase = Phase.IDLE
var _overlay_stack: Array[OverlayKind] = []
var _mode_time: float = 0.0
var _real_time: float = 0.0
var _last_camp_id: String = ""
var _quit_pending: bool = false
## Latch (story 011, ADR-0002 §11 ruling 2026-10-23): `true` once the quit
## hook has fired, so it never fires a second time in the machine's lifetime.
var _quit_fired: bool = false
var _menu_deferred: bool = false
var _pending_outcome: int = -1   # BattleResult, or -1 for "none pending"

## The result of the most recent Battle -> Overworld return (VICTORY or FLED),
## set as that return transition begins; -1 before the first. GameRoot feeds
## it to ModeHostSceneLoader as its result getter, so the thawed Overworld's
## on_thawed() receives it (story 014: the return swap carries no payload).
var last_battle_result: int = -1
var _frozen_overworld: Node = null
var _battle_snapshot: RefCounted = null
var _current_descriptor: EncounterDescriptor = null
var _action_source: Object = null

var _pending_from_mode: Mode = Mode.BOOT
var _pending_to_mode: Mode = Mode.BOOT
var _pending_payload: RefCounted = null
var _pending_transition_type: StringName = &""
var _pending_capped: bool = false
var _in_mode_fade_active: bool = false
var _in_mode_fade_callback: Callable = Callable()
var _current_t_out: float = 0.0
var _current_t_in: float = 0.0
var _t_swap: float = 0.0
var _phase_elapsed: float = 0.0
var _out_phase_elapsed: float = 0.0
var _last_transition_time: float = 0.0
var _last_t_swap: float = 0.0

var _loader: SceneLoader
var _presenter: TransitionPresenter
var _config: TransitionConfig
var _catalog: Object
var _quit_hook: Callable
var _log: GameStateLog
var _flash_gate: FlashGatePort = null
var _mark_unsaved: Callable = Callable()


## Every collaborator is injected here and nowhere else. `catalog` is typed
## `Object` (duck-typed, not `ContentCatalogService`) so this file never
## hard-depends on it. `flash_gate` is typed against the `FlashGatePort`
## interface (story 017; ADR-0005's own `FlashGate` does not exist yet) and
## defaults to `null`, meaning "never capped" for tests that don't exercise
## flashes.
## `mark_unsaved` (story 020, ADR-0002 §11) stands in for a future
## `SaveService.mark_unsaved()` (ADR-0009) until SaveService exists; it
## defaults to an invalid `Callable`, so a test that does not exercise
## `register_camp()`'s unsaved-progress marking can ignore it entirely.
func _init(loader: SceneLoader, presenter: TransitionPresenter, config: TransitionConfig,
		catalog: Object, quit_hook: Callable, log_sink: GameStateLog,
		flash_gate: FlashGatePort = null, mark_unsaved: Callable = Callable()) -> void:
	_loader = loader
	_presenter = presenter
	_config = config
	_catalog = catalog
	_quit_hook = quit_hook
	_log = log_sink
	_flash_gate = flash_gate
	_mark_unsaved = mark_unsaved


## One door in (GDD Rule 2). Legal only for the non-outcome-driven pairs in
## `_REQUESTABLE_TARGETS`, with one exception (story 025, ADR-0002 §4/§5
## ruling 2026-10-23): `request_transition(TITLE)` is also legal while
## `MENU` is the top overlay -- the Menu's own Quit to Title, the only
## transition the Menu is allowed to start. Every other target is rejected
## with `REJECTED_OVERLAY_BLOCKS` while any overlay is open, Menu or not.
func request_transition(target: Mode, payload: RefCounted = null) -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	if _phase != Phase.IDLE:
		return RequestResult.REJECTED_BUSY
	if not _overlay_stack.is_empty():
		if target == Mode.TITLE and _overlay_stack.back() == OverlayKind.MENU:
			return _quit_to_title()
		return RequestResult.REJECTED_OVERLAY_BLOCKS
	var targets: Array = _REQUESTABLE_TARGETS.get(_current_mode, [])
	if not targets.has(target):
		return RequestResult.REJECTED_INVALID_PAIR
	# Story 013, ADR-0002 §8: the Encounter descriptor is validated at request
	# time, before OUT and before any detach -- an invalid descriptor returns
	# REJECTED_INVALID_PAYLOAD here and never reaches _begin_transition(), so
	# it never needs rollback_swap(). `as` safely yields null for a null or
	# wrongly-typed payload, which the validator treats the same as "missing".
	if target == Mode.BATTLE:
		if not EncounterValidator.validate(payload as BattleEntryPayload, _config, _catalog, _log):
			return RequestResult.REJECTED_INVALID_PAYLOAD
	var transition_type: StringName = _TRANSITION_TYPES[_current_mode][target]
	_begin_transition(_current_mode, target, transition_type, payload)
	return RequestResult.OK


## Story 025, AC-20: opening `MENU` disables `ModeHost` through the injected
## loader (`set_mode_time_stopped(true)`), which is also what stops
## `mode_time` in `tick()` from the player-visible side. Dialogue and the
## Defeat Prompt never touch it (GDD rule 11).
func open_overlay(kind: OverlayKind, payload: RefCounted = null) -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	if _phase != Phase.IDLE:
		return RequestResult.REJECTED_BUSY
	_overlay_stack.append(kind)
	_loader.push_overlay(kind, payload)
	if kind == OverlayKind.MENU:
		_loader.set_mode_time_stopped(true)
	overlay_opened.emit(kind)
	return RequestResult.OK


## Story 025, AC-20: closing `MENU` re-enables `ModeHost`
## (`set_mode_time_stopped(false)`). Popping any other overlay leaves it
## untouched. Story 005: Content Error is terminal, so this is rejected
## before the busy/empty-stack checks below, same as every other entry point.
func close_overlay() -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	# Story 008: busy is checked before every other rejection, including an
	# empty overlay stack.
	if _phase != Phase.IDLE:
		return RequestResult.REJECTED_BUSY
	if _overlay_stack.is_empty():
		return RequestResult.REJECTED_INVALID_PAIR
	var kind: OverlayKind = _overlay_stack.pop_back()
	_loader.pop_overlay()
	if kind == OverlayKind.MENU:
		_loader.set_mode_time_stopped(false)
	overlay_closed.emit(kind)
	return RequestResult.OK


## Waits for a running transition (Rule 12): fires the quit hook immediately
## when idle, otherwise once, after the next `transition_finished`. Latched
## (story 011, ADR-0002 §11 ruling 2026-10-23): the hook fires at most once
## per machine lifetime, so every call after the first does nothing but
## return `OK` -- repeated calls during a transition never stack, and a
## later idle call never fires the hook again.
func request_quit() -> RequestResult:
	if _quit_fired:
		return RequestResult.OK
	if _phase == Phase.IDLE:
		_quit_fired = true
		_quit_hook.call()
	else:
		_quit_pending = true
	return RequestResult.OK


## Fourth entry point next to `request_transition`, `open_overlay` and
## `close_overlay` (ADR-0002 §11, revision 2026-10-23, in effect). Fades the
## current mode out and back in without a swap. Legal only in Overworld, idle,
## with no overlay open.
func request_in_mode_fade(callback: Callable) -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	# Story 008: busy is checked before the mode/overlay checks below, so a
	# running transition always rejects with REJECTED_BUSY, never REJECTED_INVALID_PAIR.
	if _phase != Phase.IDLE:
		return RequestResult.REJECTED_BUSY
	if _current_mode != Mode.OVERWORLD:
		return RequestResult.REJECTED_INVALID_PAIR
	if not _overlay_stack.is_empty():
		return RequestResult.REJECTED_OVERLAY_BLOCKS
	if not callback.is_valid():
		return RequestResult.REJECTED_INVALID_PAYLOAD
	_in_mode_fade_callback = callback
	_begin_transition(_current_mode, _current_mode, &"fade", null, true)
	return RequestResult.OK


## Second input to `last_camp_id` (ADR-0002 §11, story 020): the current
## Overworld mode calls this while walking past a camp, with no mode change.
## Legal only while `current_mode == OVERWORLD` and `phase == IDLE`; an empty
## `camp_id`, any other mode, or a running transition is logged and ignored.
## Emits no signal, and marks unsaved progress for ADR-0009 via the injected
## `_mark_unsaved` hook until SaveService exists.
func register_camp(camp_id: String) -> void:
	if camp_id.is_empty():
		_log.warning(&"empty_camp_id", {})
		return
	if _current_mode != Mode.OVERWORLD or _phase != Phase.IDLE:
		_log.warning(&"register_camp_wrong_mode", {"mode": _current_mode, "phase": _phase})
		return
	_last_camp_id = camp_id
	if _mark_unsaved.is_valid():
		_mark_unsaved.call()


## Called by the Battle mode / Defeat Prompt. Victory waits for
## `report_results_done()` (AC-12, story 015); Defeat opens the Defeat Prompt
## overlay. A second outcome report while one is already pending (Victory
## waiting on the results screen, or Defeat waiting on the prompt) is a
## programming error and is rejected without disturbing the first (story 015).
## Fled on a descriptor with `can_flee = false` is rejected as a Turn Battle
## bug (AC-13, story 016): nothing changes and the battle continues. With
## `can_flee = true` (or no descriptor), Fled starts the return at once --
## no results wait, unlike Victory.
func report_battle_outcome(result: BattleResult) -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	# Story 008 / GDD Edge Cases: reporting an outcome during a transition is
	# a programming error distinct from reporting in the wrong mode, so it is
	# logged separately before the mode check runs.
	if _phase != Phase.IDLE:
		_log.error(&"outcome_during_transition", {"result": result})
		return RequestResult.REJECTED_BUSY
	if _current_mode != Mode.BATTLE:
		return RequestResult.REJECTED_BUSY
	if _pending_outcome != -1:
		_log.error(&"outcome_already_pending", {"result": result, "pending": _pending_outcome})
		return RequestResult.REJECTED_BUSY
	match result:
		BattleResult.VICTORY:
			_pending_outcome = result
		BattleResult.FLED:
			if _current_descriptor != null and not _current_descriptor.can_flee:
				_log.error(&"fled_not_allowed", {"encounter_id": _current_descriptor.encounter_id})
				return RequestResult.REJECTED_INVALID_PAYLOAD
			_pending_outcome = -1
			last_battle_result = BattleResult.FLED
			_begin_transition(Mode.BATTLE, Mode.OVERWORLD,
					_TRANSITION_TYPES[Mode.BATTLE][Mode.OVERWORLD], null)
		BattleResult.DEFEAT:
			_pending_outcome = result
			var prompt_payload := DefeatPromptPayload.new()
			prompt_payload.offers_retreat = _offers_retreat()
			_overlay_stack.append(OverlayKind.DEFEAT_PROMPT)
			_loader.push_overlay(OverlayKind.DEFEAT_PROMPT, prompt_payload)
			overlay_opened.emit(OverlayKind.DEFEAT_PROMPT)
	return RequestResult.OK


## Starts the Battle -> Overworld `battle_wipe_reverse` (AC-12, story 015).
## Rejected when no Victory is pending -- a programming error, logged.
## Story 005: Content Error is terminal and is checked first.
func report_results_done() -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	if _pending_outcome != BattleResult.VICTORY:
		_log.error(&"results_done_no_pending_victory", {"pending": _pending_outcome})
		return RequestResult.REJECTED_INVALID_PAIR
	_pending_outcome = -1
	last_battle_result = BattleResult.VICTORY
	_begin_transition(Mode.BATTLE, Mode.OVERWORLD,
			_TRANSITION_TYPES[Mode.BATTLE][Mode.OVERWORLD], null)
	return RequestResult.OK


## Story 005: Content Error is terminal and is checked first.
func choose_retry() -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	if _pending_outcome != BattleResult.DEFEAT:
		return RequestResult.REJECTED_INVALID_PAIR
	_pending_outcome = -1
	_close_defeat_prompt()
	_begin_transition(Mode.BATTLE, Mode.BATTLE,
			_TRANSITION_TYPES[Mode.BATTLE][Mode.BATTLE], null)
	return RequestResult.OK


## Story 005: Content Error is terminal and is checked first.
func choose_retreat() -> RequestResult:
	if _current_mode == Mode.CONTENT_ERROR:
		return RequestResult.REJECTED_TERMINAL
	if _pending_outcome != BattleResult.DEFEAT:
		return RequestResult.REJECTED_INVALID_PAIR
	if not _offers_retreat():
		return RequestResult.REJECTED_INVALID_PAYLOAD
	_pending_outcome = -1
	_close_defeat_prompt()
	var payload := CampEntryPayload.new()
	payload.camp_id = _last_camp_id
	_begin_transition(Mode.BATTLE, Mode.CAMP,
			_TRANSITION_TYPES[Mode.BATTLE][Mode.CAMP], payload)
	return RequestResult.OK


## The only way time advances. A phase ends on the first `tick()` where the
## accumulated phase time is `>= duration - _PHASE_EPSILON`; overshoot is not
## carried into the next phase. In SWAP, `tick(delta)` adds `delta` to the
## swap-elapsed total and then polls — SWAP lasts until `poll_swap()` returns
## `DONE`, not until a duration elapses.
func tick(delta: float) -> void:
	_real_time += delta
	if not (OverlayKind.MENU in _overlay_stack):
		_mode_time += delta
	match _phase:
		Phase.IDLE:
			if _current_mode == Mode.BOOT:
				_tick_boot()
		Phase.OUT:
			_phase_elapsed += delta
			if _phase_elapsed >= _current_t_out - _PHASE_EPSILON:
				_end_out_phase()
		Phase.SWAP:
			_t_swap += delta
			var status: SceneLoader.SwapStatus = _loader.poll_swap()
			if status == SceneLoader.SwapStatus.DONE:
				_end_swap_phase_success()
			elif status == SceneLoader.SwapStatus.FAILED:
				_end_swap_phase_failure(&"loader_failed")
		Phase.IN:
			_phase_elapsed += delta
			if _phase_elapsed >= _current_t_in - _PHASE_EPSILON:
				_end_in_phase()


## Any `Object` meeting the `ActionSource` contract (signal-and-method, not a
## required base class). The machine is the only consumer (ADR-0002 §6):
## connects `action_pressed`, `action_released`, `focus_lost` and
## `device_lost` for routing; `action_held`, `device_restored`,
## `focus_gained` and `active_device_changed` are deliberately left
## unconnected (UI Framework's concern). Rebinding disconnects the previous
## source first, so a caller never ends up delivering through two sources.
func bind_action_source(source: Object) -> void:
	if _action_source != null and is_instance_valid(_action_source):
		_unbind_action_source()
	_action_source = source
	if _action_source == null:
		return
	_action_source.connect(&"action_pressed", _on_source_action_pressed)
	_action_source.connect(&"action_released", _on_source_action_released)
	_action_source.connect(&"focus_lost", _on_source_focus_lost)
	_action_source.connect(&"device_lost", _on_source_device_lost)


## `true` only while `phase == IDLE` and no overlay is open, for the live
## mode node under `ModeHost`. An open overlay owns input instead (routing
## to it is `_dispatch_discrete_action`'s concern, not ownership).
func is_input_owner(receiver: Object) -> bool:
	if _phase != Phase.IDLE:
		return false
	if not _overlay_stack.is_empty():
		return false
	return receiver == _loader.current_mode_node()


## `Vector2.ZERO` unless `caller` owns input.
func get_move_vector(caller: Object) -> Vector2:
	if not is_input_owner(caller):
		return Vector2.ZERO
	if _action_source == null:
		return Vector2.ZERO
	return _action_source.get_move_vector()


## Overworld/Camp, no overlay but Menu, idle.
func is_save_safe() -> bool:
	if _phase != Phase.IDLE:
		return false
	if _current_mode != Mode.OVERWORLD and _current_mode != Mode.CAMP:
		return false
	if _overlay_stack.is_empty():
		return true
	return _overlay_stack.size() == 1 and _overlay_stack[0] == OverlayKind.MENU


## True between `transition_started` and `transition_finished` of an in-mode
## fade (ADR-0002 §11).
func is_in_mode_fade() -> bool:
	return _in_mode_fade_active


## True iff the current transition's flash plays its capped variant (the
## `FlashGate` refused the booking, story 017); false outside a transition.
func is_transition_flash_capped() -> bool:
	return _phase != Phase.IDLE and _pending_capped


## Read-only debug snapshot (QA RC-1 b). Returns a fresh `Dictionary`, never
## written through.
func get_debug_state() -> Dictionary:
	return {
		"mode": _current_mode,
		"overlay_stack": _overlay_stack.duplicate(),
		"phase": _phase,
		"frozen_overworld_id": _frozen_overworld.get_instance_id() if is_instance_valid(_frozen_overworld) else 0,
		"battle_snapshot_id": _battle_snapshot.get_instance_id() if is_instance_valid(_battle_snapshot) else 0,
		"last_camp_id": _last_camp_id,
		"quit_pending": _quit_pending,
		"menu_deferred": _menu_deferred,
		"pending_outcome": _pending_outcome,
	}


func _tick_boot() -> void:
	var cat_state: ContentCatalogService.State = (
			_catalog.get("state") as int) as ContentCatalogService.State
	if cat_state == ContentCatalogService.State.READY:
		_begin_transition(Mode.BOOT, Mode.TITLE, _TRANSITION_TYPES[Mode.BOOT][Mode.TITLE], null)
	elif cat_state == ContentCatalogService.State.FAILED:
		_begin_transition(Mode.BOOT, Mode.CONTENT_ERROR,
				_TRANSITION_TYPES[Mode.BOOT][Mode.CONTENT_ERROR], null)


## `transition_started` at the start of OUT; `presenter.play_out()` alongside it.
func _begin_transition(from: Mode, to: Mode, transition_type: StringName,
		payload: RefCounted, in_mode_fade: bool = false) -> void:
	_pending_from_mode = from
	_pending_to_mode = to
	_pending_payload = payload
	_pending_transition_type = transition_type
	_pending_capped = _book_flash(transition_type)
	_in_mode_fade_active = in_mode_fade
	_phase = Phase.OUT
	_phase_elapsed = 0.0
	_current_t_out = float(_config.t_out.get(transition_type, 0.0))
	_current_t_in = float(_config.t_in.get(transition_type, 0.0))
	transition_started.emit(from, to)
	_presenter.play_out(transition_type, _current_t_out, _pending_capped)


## Books this transition's flash through the injected `FlashGate`, once, at
## the start of OUT (ADR-0002 amendment; ADR-0005 §12). Returns the `capped`
## flag to pass to both `play_out()` and `play_in()`. Non-flashing types
## (`fade`, `none`) and a `null` flash_gate (tests that don't exercise
## flashes) are never capped -- `fade` is never even asked.
func _book_flash(transition_type: StringName) -> bool:
	if _flash_gate == null:
		return false
	if not _FLASH_SOURCE_BY_TYPE.has(transition_type):
		return false
	var source_id: StringName = _FLASH_SOURCE_BY_TYPE[transition_type]
	var handle: int = _flash_gate.request(source_id, _real_time, 1.0)
	return handle == -1


## `mode_exited` at the start of SWAP. The in-mode fade's zero-length SWAP
## (ADR-0002 §11) skips this and the loader entirely. Retry (Battle -> Battle,
## ADR-0002 §7 amendment / ADR-0006 §5) still fires `mode_exited`, but its
## SWAP restores the snapshot instead of calling the loader.
func _end_out_phase() -> void:
	_out_phase_elapsed = _phase_elapsed
	if _in_mode_fade_active:
		_t_swap = 0.0
		var callback: Callable = _in_mode_fade_callback
		_in_mode_fade_callback = Callable()
		if callback.is_valid():
			callback.call()
		else:
			_log.error(&"in_mode_fade_callback_invalid", {})
		_begin_in_phase()
		return
	mode_exited.emit(_pending_from_mode)
	if _pending_from_mode == Mode.BATTLE and _pending_to_mode == Mode.BATTLE:
		_end_retry_swap()
		return
	# Retreat (ADR-0002 §4, §11 -- story 020, QA RC-2): the loader's swap
	# frees the live Battle node; the machine frees the detached Overworld
	# explicitly, since an unparented node is not freed by its old parent.
	if _pending_from_mode == Mode.BATTLE and _pending_to_mode == Mode.CAMP:
		_loader.free_frozen_overworld()
	_phase = Phase.SWAP
	_t_swap = 0.0
	_loader.begin_swap(_pending_from_mode, _pending_to_mode, _pending_payload)


## Retry's SWAP (ADR-0002 §7 amendment, ADR-0006 §5): no `SceneLoader` call.
## Hands the captured handle back to the same Battle-mode instance and
## completes immediately -- there is nothing to poll. `mode_entered(BATTLE)`
## still fires (amendment); listeners must not re-apply entry state over what
## `restore_start_snapshot()` just set.
func _end_retry_swap() -> void:
	_phase = Phase.SWAP
	_t_swap = 0.0
	var battle_node: Object = _loader.current_mode_node()
	if battle_node != null:
		battle_node.restore_start_snapshot(_battle_snapshot)
	_current_mode = Mode.BATTLE
	mode_entered.emit(Mode.BATTLE)
	_begin_in_phase()


## `mode_entered` at the end of SWAP, on `poll_swap() == DONE`. On Overworld
## -> Battle only (ADR-0002 §7), a `null` `capture_start_snapshot()` is itself
## a swap failure (the base `GameMode` returns `null`, so a Battle mode that
## forgets to override it fails loudly) -- checked only when the loader
## reports a live node, so a stub test that never sets `current_mode_node()`
## is unaffected (story 012).
func _end_swap_phase_success() -> void:
	if _pending_from_mode == Mode.OVERWORLD and _pending_to_mode == Mode.BATTLE:
		var battle_node: Object = _loader.current_mode_node()
		if battle_node != null:
			var snapshot: RefCounted = battle_node.capture_start_snapshot()
			if snapshot == null:
				_end_swap_phase_failure(&"capture_snapshot_null")
				return
			_battle_snapshot = snapshot
	_current_mode = _pending_to_mode
	if _pending_payload is BattleEntryPayload:
		_current_descriptor = (_pending_payload as BattleEntryPayload).descriptor
	# ADR-0012 annotation b: CampEntryPayload is the other input to
	# last_camp_id, recorded here during SWAP -- after mode_exited (start of
	# SWAP, _end_out_phase) and before mode_entered (just below). Covers both
	# Overworld -> Camp entry and Battle -> Camp retreat (the latter is a
	# same-value rewrite: choose_retreat() built the payload from this same
	# _last_camp_id).
	if _pending_payload is CampEntryPayload:
		_last_camp_id = (_pending_payload as CampEntryPayload).camp_id
	mode_entered.emit(_pending_to_mode)
	_begin_in_phase()


## A swap failure rolls back: re-attach any detached Overworld (handled by
## `rollback_swap()`), play IN back into the source mode, and log an error
## naming `cause` (`&"loader_failed"` or `&"capture_snapshot_null"`, story 012).
func _end_swap_phase_failure(cause: StringName) -> void:
	_loader.rollback_swap()
	_log.error(&"swap_failed", {"from": _pending_from_mode, "to": _pending_to_mode, "cause": cause})
	mode_entered.emit(_pending_from_mode)
	_pending_to_mode = _pending_from_mode
	_begin_in_phase()


## `presenter.play_in()` at the start of IN.
func _begin_in_phase() -> void:
	_phase = Phase.IN
	_phase_elapsed = 0.0
	_presenter.play_in(_pending_transition_type, _current_t_in, _pending_capped)


## `transition_finished` at the end of IN. Input unlocks once this is
## emitted (AC-8): phase is already `IDLE` by the time listeners run.
func _end_in_phase() -> void:
	_last_t_swap = _t_swap
	_last_transition_time = _out_phase_elapsed + _t_swap + _phase_elapsed
	var finished_mode: Mode = _current_mode
	_phase = Phase.IDLE
	_phase_elapsed = 0.0
	_in_mode_fade_active = false
	transition_finished.emit(finished_mode)
	# Story 026, ADR-0002 §6/§11: resolves a deferred focus/device loss by the
	# destination mode just reached -- opens the Menu only if it permits one,
	# otherwise clears the flag silently (deferred-Menu destination rule).
	if _menu_deferred:
		_menu_deferred = false
		if finished_mode in _MENU_ALLOWED_MODES:
			open_overlay(OverlayKind.MENU, _build_menu_payload())
	if _quit_pending:
		_quit_pending = false
		_quit_fired = true
		_quit_hook.call()


## Story 018, AC-16: computed fresh from the stored descriptor every time it
## is called -- never cached on the machine -- so a Retry (which keeps the
## same descriptor) never carries a stale flag into a later Defeat in the
## same battle. Shared by the Defeat payload and `choose_retreat()`'s guard
## so the two can never disagree.
func _offers_retreat() -> bool:
	return _current_descriptor != null and _current_descriptor.retreat_allowed


## Quit to Title from the Menu (story 025, ADR-0002 §4/§5 ruling 2026-10-23).
## Pops every overlay top-down, emitting `overlay_closed` for each, then
## re-enables `ModeHost` and frees any frozen Overworld -- all before
## `transition_started`, per the ruling -- and begins the ordinary transition
## to `TITLE` from whichever mode is underneath. The caller has already
## checked `_overlay_stack.back() == MENU`.
func _quit_to_title() -> RequestResult:
	while not _overlay_stack.is_empty():
		var kind: OverlayKind = _overlay_stack.pop_back()
		_loader.pop_overlay()
		overlay_closed.emit(kind)
	_loader.set_mode_time_stopped(false)
	_loader.free_frozen_overworld()
	var transition_type: StringName = _TRANSITION_TYPES[_current_mode][Mode.TITLE]
	_begin_transition(_current_mode, Mode.TITLE, transition_type, null)
	return RequestResult.OK


func _close_defeat_prompt() -> void:
	if not _overlay_stack.is_empty() and _overlay_stack.back() == OverlayKind.DEFEAT_PROMPT:
		_overlay_stack.pop_back()
		_loader.pop_overlay()
		overlay_closed.emit(OverlayKind.DEFEAT_PROMPT)


func _unbind_action_source() -> void:
	for signal_name: StringName in [&"action_pressed", &"action_released", &"focus_lost", &"device_lost"]:
		var callable: Callable = _callable_for_source_signal(signal_name)
		if _action_source.is_connected(signal_name, callable):
			_action_source.disconnect(signal_name, callable)


func _callable_for_source_signal(signal_name: StringName) -> Callable:
	match signal_name:
		&"action_pressed":
			return _on_source_action_pressed
		&"action_released":
			return _on_source_action_released
		&"focus_lost":
			return _on_source_focus_lost
		_:
			return _on_source_device_lost


## Story 024, ADR-0002 §6/§10 ruling 2026-10-23: `&"menu"` is intercepted
## here, before any routing -- it never reaches `_dispatch_discrete_action`,
## so the mode and any open overlay never see it, whether or not the Menu
## actually opens.
func _on_source_action_pressed(action: StringName) -> void:
	if action == _MENU_ACTION:
		_handle_menu_action()
		return
	_dispatch_discrete_action(action, true)


func _on_source_action_released(action: StringName) -> void:
	_dispatch_discrete_action(action, false)


## Story 026, ADR-0002 §6/§11: `focus_lost` and `device_lost` share the same
## machine-level response.
func _on_source_focus_lost() -> void:
	_handle_focus_or_device_lost()


## Story 026: see `_on_source_focus_lost()`.
func _on_source_device_lost() -> void:
	_handle_focus_or_device_lost()


## Story 026, ADR-0002 §6/§11: idle in an allowed mode (Overworld, Camp,
## Battle -- the Defeat Prompt on top counts as allowed, same gate as
## `_handle_menu_action()`) opens the Menu at once, unless it is already the
## top overlay, in which case this is a no-op (a second loss never stacks a
## second Menu). Idle in any other mode (Boot, Content Error, Title) is
## ignored, with no flag set (shared with story 005). Mid-transition this
## defers instead of ignoring: `_menu_deferred` is set unconditionally,
## regardless of which mode the transition started from -- `_end_in_phase()`
## resolves it by the *destination* mode once `transition_finished` fires
## (the deferred-Menu destination rule, pinned 2026-10-23: a destination that
## does not permit the Menu, e.g. TITLE, clears the flag silently instead of
## opening it).
func _handle_focus_or_device_lost() -> void:
	if _phase != Phase.IDLE:
		_menu_deferred = true
		return
	if not (_current_mode in _MENU_ALLOWED_MODES):
		return
	if not _overlay_stack.is_empty() and _overlay_stack.back() == OverlayKind.MENU:
		return
	open_overlay(OverlayKind.MENU, _build_menu_payload())


## Dropped while `phase != IDLE` (AC-8). Otherwise delivered to the top
## overlay's `handle_action` when one is open, or to the current mode's when
## none is (ADR-0002 §6). With a multi-entry stack (story 022, AC-19), the
## loader's `current_overlay_node()` is always the top of that stack, so a
## single lookup here is already correct at any depth; only the top ever
## receives input.
## Story 024, AC-22: turns `&"menu"` into `open_overlay(MENU)` itself, only
## while `IDLE` and only in `_MENU_ALLOWED_MODES` -- a running transition,
## Boot, Title or Content Error silently drops the request instead of
## calling `open_overlay()`, which would otherwise need the full overlay
## "can open over" table that story 023 (deferred) has not built yet.
func _handle_menu_action() -> void:
	if _phase != Phase.IDLE:
		return
	if not (_current_mode in _MENU_ALLOWED_MODES):
		return
	open_overlay(OverlayKind.MENU, _build_menu_payload())


## Story 029, AC-31: the Menu's payload for the mode it is about to open
## over. Every call site above has already checked `_current_mode in
## _MENU_ALLOWED_MODES`, so Battle is the only case singled out here --
## Overworld and Camp share the full menu.
func _build_menu_payload() -> MenuPayload:
	var payload := MenuPayload.new()
	if _current_mode == Mode.BATTLE:
		payload.entries = _MENU_ENTRIES_BATTLE.duplicate()
	else:
		payload.entries = _MENU_ENTRIES_FULL.duplicate()
	return payload


func _dispatch_discrete_action(action: StringName, pressed: bool) -> void:
	if _phase != Phase.IDLE:
		return
	if not _overlay_stack.is_empty():
		var overlay: Object = _loader.current_overlay_node()
		if overlay != null:
			overlay.handle_action(action, pressed)
		return
	var mode: Object = _loader.current_mode_node()
	if mode != null:
		mode.handle_action(action, pressed)
