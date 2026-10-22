# ADR-0002: Game State & Scene Flow — Scene Architecture and ChapterFlow Ownership

## Status
Proposed

## Date
2026-10-21

## Last Verified
2026-10-21

## Decision Makers
User (autonomous mode — decisions logged in `production/session-logs/decision-log.md`), Claude (orchestrating session), reviewed by godot-specialist and technical-director (TD-ADR)

## Summary
Game State & Scene Flow needs a concrete Godot mechanism for its one-mode-plus-overlay-stack model, for freezing the Overworld around battles, and for Retry without a scene load. Decided: a pure `RefCounted` `GameStateMachine` (no scene tree, fully injectable, the same convention as `BattleCore`) driven by a persistent root scene, `GameRoot`, that swaps mode scenes under a `ModeHost` node, keeps overlays in a separate `OverlayHost`, and freezes the Overworld by detaching its live node instead of serializing it. `ChapterFlow` keeps its fight sequencing as the stand-in Overworld until Overworld Exploration ships, and gives up battle construction and retry to Game State and the Battle mode.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH — post-LLM-cutoff version. The specific APIs this decision leans on (`Node.add_child`/`remove_child`, `Node.process_mode`, `PackedScene.instantiate()`, `ResourceLoader.load()`, `CanvasLayer`, `RefCounted` signals) are fundamental 4.0-era APIs, LOW risk on their own, but **none is covered by `docs/engine-reference/godot/`** (no Core module exists) — see Verification Required |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (no `modules/core.md` exists; `modules/input.md` and `modules/ui.md` are relevant to the routing and focus notes only) |
| **Post-Cutoff APIs Used** | `@abstract` on the `GameMode` base class (4.5, documented in `current-best-practices.md`). 4.7's "an override of a typed method inherits its return type" applies to every `GameMode` override (each needs an explicit `return`). No other post-cutoff API is used. `SceneTree.change_scene_to_file()` / `change_scene_to_packed()` and `ResourceLoader.load_threaded_*` are deliberately **not** used: NOT SOURCEABLE — not covered by `docs/engine-reference/godot/**` |
| **Verification Required** | Items (1) and (2) were **empirically verified on 4.7.2.stable, headless, 2026-10-21** (godot-specialist throwaway spike in the session scratchpad, outside the project): (1) across `remove_child()` → wait → `add_child()`, `_ready()` fired once in total and `_enter_tree`/`_exit_tree` once per move; a `Timer`'s `time_left` did not change during a 0.3 s detached wait and resumed afterwards. (2) A node-bound `create_tween()` Tween froze while detached and again while `ModeHost.process_mode = PROCESS_MODE_DISABLED`, and resumed after; `is_valid()` stayed true. The `Timer` also froze while disabled. A `RefCounted` class declaring enums and signals, and both one-line and two-line `@abstract class_name` forms, parsed and worked. **Still open:** (3) an `AnimationPlayer` under a disabled `ModeHost` stops; not measured, inferred from the same `process_mode` mechanism. Confirm it in Migration Step 1 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data Definitions storage format) — **Accepted**. Boot waits on `ContentCatalog.state`; Encounter descriptor validation uses `has_record()`; `TransitionConfig` follows ADR-0001's `Resource`/`.tres`, data-only rules |
| **Enables** | Input System ADR (must provide the `ActionSource` contract defined below, or supersede that section explicitly); Sprite & Camera Presentation ADR (consumes `mode_entered` and the `ModeHost` layout); Overworld Exploration & Encounters ADR (implements the `GameMode` freeze hooks and replaces `ChapterFlow`); Save/Load & Settings ADR (`is_save_safe()`) |
| **Blocks** | Game State & Scene Flow epic (all stories); Overworld Exploration & Encounters epic (one of its 3 prerequisite ADRs); the `ChapterFlow` refactor (Migration Plan Steps 2-3) |
| **Ordering Note** | Migration Step 0 (characterization tests of today's `ChapterFlow`) must land before Step 2 touches `chapter_flow.gd`. Full catalog validation of `enemy_ids` waits on ADR-0001's enemy-record migration; until then it is off behind a named interim flag (Decision §8). `tests/` and gdUnit4 do not exist yet, so `/test-setup` comes first. The Input System ADR does not have to be Accepted before Game State is implemented: Game State is built and tested against a synthetic `ActionSource` (GDD Acceptance Criteria already require one) |

## Context

### Problem Statement
`design/gdd/game-state-scene-flow.md` fully specifies *what* Game State & Scene Flow does: six modes, three stacked overlays, a fixed transitions table, one transition at a time, an exact Overworld freeze/restore around battles, Retry with no scene load, and six announcement signals. It explicitly leaves *how* to this ADR (GDD Open Question 4: "autoload state machine, scene swapping, how the overworld is frozen (kept in the tree vs. serialized)"). Three things make the decision urgent now:

1. Overworld Exploration & Encounters, the system the user wants after Content Data Definitions, cannot start until this ADR, the Input System ADR and the Sprite & Camera ADR are Accepted (`architecture.md`, Required ADRs).
2. `ChapterFlow` (`src/chapters/chapter_flow.gd`, shipped in Story 006) already does a slice of this system's designed job — it constructs every `BattleCore`, sequences fights, and runs its own retry-from-snapshot. `architecture.md` Open Question QQ-01 assigns resolving that overlap to this ADR.
3. `BattleCore.retry_battle()` is an alias for `start_battle()` with `reset_squad = true`, i.e. a full heal. The GDD's Retry restores the squad to the state *at the start of that battle*, which differs as soon as HP carries over between fights (ChapterFlow works around this with its own `_fight_start_snapshot`). Some system has to own that snapshot.

### Constraints
- **Architecture Principle 4** (`architecture.md`): "One door in, per system", with exactly one bounded exception — `ContentCatalog` is an autoload only because it is read-only after `Ready`. Game State is mutable and is named as the system that "must not cite this exception". A mutable `GameState` autoload is therefore off the table unless Principle 4 is formally revised.
- **Coding standards**: dependency injection over singletons; every public method unit-testable; gameplay values data-driven.
- **GDD Acceptance Criteria** require driving the system headlessly "through its request API with stubbed neighbors: a stub Content catalog, a stub Battle reporting outcomes, an injectable clock, a scene-loader spy, and a synthetic input source". The mechanism must make all five injectable.
- **Project convention**: `BattleCore` and `ChapterFlow` are `RefCounted` with no scene-tree dependency, so they can be driven headlessly. Data flow is synchronous and single-threaded (`architecture.md`, Data Flow 2).
- **Input System GDD rule 2**: Input knows nothing about modes; Game State routes actions and applies the lock. Input must not depend on Game State.
- **Registry stances (ADR-0001)**: `ContentCatalog` owns content records (read-only after Ready); content records never hold direct `Resource` references.
- **Team/timeline**: solo developer with AI agents; MVP scope is the linear chapter (3 fights + boss) for two factions, with Overworld not yet built.

### Requirements
- One current mode plus a stacked overlay set, changed only through `request_transition`, `open_overlay` and `close_overlay`, with the GDD's six signals in their fixed order (TR-gamestate-001).
- One transition at a time, no queue except Quit; input locked from start of *out* to end of *in*; a failed swap rolls back to the source mode (TR-gamestate-002).
- Freeze and restore the Overworld exactly around Battle; validate the Encounter descriptor before entry (TR-gamestate-003).
- Retry from the battle's start snapshot with no scene load; Retreat to the last camp visited, dropping the frozen Overworld (TR-gamestate-004).
- Boot waits for `ContentCatalog`: Ready → Title, Failed → terminal Content Error (TR-gamestate-005).
- Per-type transition timings and budgets from data; clock and scene loader injectable; Menu stops mode time; overruns logged, never skipped (TR-gamestate-006).
- Transition budgets: 0.5 s (Retry) to 1.5 s (fade with a map load), from the GDD Formulas.

## Decision

Game State & Scene Flow is split into a **pure logic core** and a **thin scene-tree shell**, joined by injected interfaces.

**1. `GameStateMachine` (logic core, `RefCounted`).** Owns the current mode, the overlay stack, the transitions table, the transition lifecycle (phases *out → swap → in*), the input lock, the Quit-wait flag, the deferred-Menu flag, the frozen-Overworld *handle*, the battle-start snapshot *handle*, the current Encounter descriptor, and `last_camp_id`. It declares the GDD's six signals. It has no scene-tree dependency: time advances only when its owner calls `tick(delta)`, and every side effect goes through an injected collaborator (scene loader, transition presenter, catalog, quit hook, logger). This is the object every test drives, and it is what every other system holds a reference to. It is created once by `GameRoot` and injected into every mode, overlay and Presentation-layer service — never looked up by name and never an autoload.

**2. `GameRoot` (shell, the project's main scene, `res://src/game_state/game_root.tscn`).** A persistent `Node` that is never swapped out. *(Amendment pending, ADR-0004: `GameRoot._enter_tree()` calls only `ContentBootstrap.run()`; everything below is built in `_ready()`.)* It builds the `GameStateMachine` and its production collaborators, calls `machine.tick(delta)` from `_process` (with `process_mode = PROCESS_MODE_ALWAYS`), and owns the scene layout:

```
GameRoot (Node, PROCESS_MODE_ALWAYS)        ← composition root; never freed
├── ModeHost (Node)                          ← exactly 0 or 1 live mode child
│   └── <current mode scene>                 ← extends GameMode
├── OverlayHost (CanvasLayer, layer 10)      ← overlay stack, top = last child
│   └── <overlay scenes>                     ← extend GameOverlay
├── TransitionLayer (CanvasLayer, layer 20)  ← UI Framework's wipe/fade/flash presenter
└── Services (Node)                          ← Presentation, Audio Manager, etc.;
                                                each gets the machine via setup()
```

**3. Mode swap = child swap under `ModeHost`.** `SceneTree.change_scene_to_*` is not used: it frees the current scene, which would destroy the Overworld instead of freezing it, and would take overlays, services and the machine with it. The production `SceneLoader` resolves a mode's `PackedScene` path from `TransitionConfig`, loads it with `ResourceLoader.load()` and instantiates it, all synchronously during the *swap* phase (MVP scenes are small; the GDD's 0.60 s `t_swap` ceiling is the guard). The loader interface is poll-based (`begin_swap` / `poll_swap`), so a threaded loader can replace it later without changing the machine. That later change needs its own API verification, since `load_threaded_*` is NOT SOURCEABLE here today.

**4. Overworld freeze = detach, don't serialize.** On Overworld → Battle, the loader calls the mode's `on_freezing()` hook, then `ModeHost.remove_child(overworld)` and keeps the instance alive in memory, unparented. Detaching removes it from rendering, physics (including Jolt, so the Overworld's bodies cannot collide with the battle diorama), processing and input in one step, and preserves every field exactly. That makes the GDD's "restored exactly as it was" true by construction, not by a serializer that has to be complete. On Victory or Fled the battle scene is freed, the same instance is re-added, and `on_thawed(encounter_id, outcome)` runs **after** `mode_entered(OVERWORLD)`. That is where the Overworld resolves the encounter and applies story flags (GDD Edge Cases: "the restore itself is always exact"). On Retreat, or on Quit to Title, the detached instance is `free()`d explicitly, since an unparented node is not freed by its old parent.

**5. Menu stops time = disable `ModeHost`.** While the Menu overlay is open, `ModeHost.process_mode = PROCESS_MODE_DISABLED`, which stops `_process`, `_physics_process`, `Timer`s, `AnimationPlayer`s and node-bound `Tween`s for the whole mode subtree (Timers and Tweens verified on 4.7.2; `AnimationPlayer` is verification item 3). The mode stays visible, so the art bible's "frozen, blurred diorama behind flat UI" shows through. `SceneTree.paused` is not used: it is global, and pausing it would also stop Audio Manager and the overlay unless every service opted out. The machine's own `mode_time` (exposed for tests, AC-20) stops advancing while the Menu is open. Dialogue does **not** disable `ModeHost`: it blocks input only (GDD rule 11).

**6. Input routing.** The machine is the only consumer of the Input System's action signals (through the `ActionSource` contract below). For each discrete action it drops the action while a transition runs, and otherwise delivers it to the top overlay or, with no overlay open, to the current mode via `handle_action()`. Continuous movement is polled, not routed, and the lock is enforced by the machine instead of by convention: a mode calls `machine.get_move_vector(self)`. The machine forwards to the `ActionSource` and returns `Vector2.ZERO` unless the caller owns input. A caller does not own input during a transition or while any overlay is open. Modes never hold a reference to the Input System. `focus_lost` and `device_lost` open the Menu where allowed, are deferred until `transition_finished` during a transition, and are ignored in Boot and Content Error (GDD Edge Cases).

**7. Retry = snapshot handed back, no load.** At battle entry the machine asks the Battle mode for `capture_start_snapshot() -> RefCounted` *after* the Battle mode has built its `BattleCore` from the descriptor, and stores the opaque handle. Defeat opens the Defeat Prompt; Retry runs the Battle → Battle row (flash, all four transition signals fire with `from == to == BATTLE`) and the swap phase calls `restore_start_snapshot(handle)` on the **same** Battle scene instance, with no loader call. The Battle mode (Turn Battle System's presentation side) owns what the snapshot contains (party stats, items, states, enemy group, and whether RNG state is included — GDD Open Question 2), which generalizes `ChapterFlow._fight_start_snapshot`. `BattleCore.retry_battle()` stays for the standalone debug harness but must not be used for Retry under Game State, because it full-heals the squad.

A `null` snapshot returned at battle entry is a swap failure and triggers rollback (the base `GameMode.capture_start_snapshot()` returns `null`, so a Battle mode that forgets to override it fails loudly instead of losing Retry).

**HP/MP carryover contract.** Under Game State the Battle mode always calls `BattleCore.start_battle(false)`, never the full-reset default. The `Combatant`s in `BattleEntryPayload.party` are the requester's own instances and are changed in place, so damage taken in a fight is still there after Victory or Fled. A full restore happens only on Retreat, which Camp performs on entry. Clearing per-fight transients (`is_defending`, `is_stunned`, `vulnerable_rounds_left`) stays with the requester: `ChapterFlow` keeps `_clear_squad_transients()` and runs it before building each descriptor.

**8. `ChapterFlow` ownership (resolves QQ-01): Game State becomes the parent; ChapterFlow becomes the interim Overworld.** Until Overworld Exploration & Encounters ships, the Overworld mode slot is filled by a placeholder `ChapterMode` scene (extends `GameMode`) that holds a `ChapterFlow`. `ChapterFlow` keeps exactly the parts that are *encounter sequencing* — which fight comes next, its enemy roster, boss detection, HP/MP carryover between fights, `chapter_won`. It loses the parts that are Game State's or Battle's: it stops constructing `BattleCore`, stops listening to `battle_ended`, and loses `_fight_start_snapshot`/`_restore_squad_snapshot` and the `fight_lost` → retry loop. Instead it builds an `EncounterDescriptor` and the `ChapterMode` calls `machine.request_transition(Mode.BATTLE, BattleEntryPayload)`; when `on_thawed(encounter_id, outcome)` reports Victory, it advances. A Defeat never reaches it, since Retry/Retreat happen entirely inside Game State and Battle. Until Camp & Party Management exists, `ChapterMode` builds every descriptor with `retreat_allowed = false`, so the Defeat Prompt offers only Retry and no "no camp" content error is logged on each loss.

Today the chapter's enemies come from code factories (`BureaucratiaRule.make_clerk()` etc.), not catalog records, so `has_record()` validation of `enemy_ids` would reject every chapter fight. Until ADR-0001's enemy-record migration lands, the production descriptor validator runs with a named interim flag, `TransitionConfig.validate_enemy_ids_against_catalog = false`. It still checks every other descriptor field (non-empty `encounter_id` and `enemy_ids`, known `faction_id`). The flag is deleted, and full validation becomes unconditional, in Migration Step 3 or when the enemy migration lands, whichever comes first. When Overworld Exploration ships, `ChapterMode` and `ChapterFlow` are deleted, and the fight sequence becomes encounter data. Replacing ChapterFlow outright now was rejected: it would leave the MVP with no playable loop until Overworld exists. Wrapping it unchanged was rejected because two systems would then construct battles and run retries.

**9. Transition timings are data.** A single `TransitionConfig` `Resource` (`data/config/transition_config.tres`, script `src/game_state/transition_config.gd`) holds, per transition type (`battle_wipe`, `battle_wipe_reverse`, `retry_flash`, `fade`, `none`), `t_out`, `t_in` and `transition_budget`, plus the mode → `PackedScene` path table and the overlay → path table. It follows ADR-0001's data-only rules (no logic, no `Resource`-typed exports: scene paths are `String`), but it is a **project config**, like Content Data's own `ERROR_SCREEN_CAP`, and not a catalog record type: it is loaded directly by `GameRoot._ready()` with `ResourceLoader.load()`, because the Boot → Title fade needs it before any catalog-dependent code runs. The transitions *table* (which from → to pairs are legal, and which transition type each uses) is a game rule from the GDD, not a tuning value, so it is a `const` in `GameStateMachine`.

**10. Boot.** The machine starts in `BOOT`. On each tick in Boot it reads the injected catalog's `state`. By ADR-0001 the `ContentCatalog` autoload has already run `load_all()` in its `_ready()`, so this normally resolves on the first tick. *(Amendment pending, ADR-0004: replace with "`GameRoot._enter_tree()` has already run `ContentBootstrap.run()`, which registers every vocabulary and validator and then loads". Measured on 4.7.2, the autoload's `_ready()` runs after the main scene's `_enter_tree()`, so the original premise did not hold.)* `READY` triggers the Boot → Title fade and `FAILED` the instant Boot → Content Error. Content Error is terminal: every request except Quit returns `REJECTED_TERMINAL`. Reading the catalog's status here is internal to Boot and is not the presentation-polls-state pattern GDD rule 4 forbids.

### Architecture Diagram

```
                ┌───────────────────────── GameRoot (main scene) ─────────────────────────┐
 Input System ──► ActionSource signals ─┐                                                  │
 (autoload or    action_pressed(...)   │   ┌───────────────── GameStateMachine ───────────┐│
  node, per its  focus_lost/device_lost └──►│ mode · overlay stack · phase · input lock    ││
  own ADR)                                  │ frozen_overworld (handle) · battle snapshot  ││
                                            │ tick(delta) ◄── GameRoot._process            ││
 ContentCatalog ── state / has_record ─────►│ request_transition · open/close_overlay      ││
 (ADR-0001)                                 │ report_battle_outcome · choose_retry/retreat ││
                                            └───┬──────────────┬──────────────┬────────────┘│
                                     SceneLoader│  Transition- │   6 signals  │             │
                                                ▼  Presenter   ▼              ▼             │
                                   ModeHost ─ swap/detach   TransitionLayer  Services      │
                                   OverlayHost ─ push/pop   (UI Framework)   (Presentation,│
                                                                              Audio, …)    │
                └──────────────────────────────────────────────────────────────────────────┘

 Overworld → Battle:  OUT ─► SWAP[ on_freezing · remove_child(OW) · load+add Battle ·
                                   validate descriptor · capture_start_snapshot ] ─► IN
 Battle → Overworld:  OUT ─► SWAP[ free Battle · add_child(OW) ] ─► IN ─► on_thawed(id, outcome)
 Retry (Battle→Battle): OUT ─► SWAP[ restore_start_snapshot(handle) — no loader call ] ─► IN
```

### Key Interfaces

```gdscript
## src/game_state/game_state_machine.gd
class_name GameStateMachine extends RefCounted

enum Mode { BOOT, CONTENT_ERROR, TITLE, OVERWORLD, BATTLE, CAMP }
enum OverlayKind { DIALOGUE, MENU, DEFEAT_PROMPT }
enum Phase { IDLE, OUT, SWAP, IN }
enum RequestResult { OK, REJECTED_BUSY, REJECTED_INVALID_PAIR, REJECTED_TERMINAL,
                     REJECTED_OVERLAY_BLOCKS, REJECTED_INVALID_PAYLOAD }
enum BattleResult { VICTORY, FLED, DEFEAT }

# The GDD's six announcements (Rule 4), names unchanged.
signal transition_started(from: Mode, to: Mode)
signal mode_exited(from: Mode)
signal mode_entered(to: Mode)
signal transition_finished(to: Mode)
signal overlay_opened(kind: OverlayKind)
signal overlay_closed(kind: OverlayKind)

func _init(loader: SceneLoader, presenter: TransitionPresenter, config: TransitionConfig,
        catalog: Object, quit_hook: Callable, log: GameStateLog) -> void

# One door in (GDD Rule 2)
func request_transition(target: Mode, payload: RefCounted = null) -> RequestResult
func open_overlay(kind: OverlayKind, payload: RefCounted = null) -> RequestResult
func close_overlay() -> RequestResult
func request_quit() -> RequestResult          # waits for a running transition (Rule 12)

# Battle reporting (called by the Battle mode / Defeat Prompt)
func report_battle_outcome(result: BattleResult) -> RequestResult
func report_results_done() -> RequestResult   # Victory waits for this (AC-12)
func choose_retry() -> RequestResult
func choose_retreat() -> RequestResult

# Driving and queries
func tick(delta: float) -> void
func bind_action_source(source: Object) -> void   # any Object meeting the ActionSource contract
func is_input_owner(receiver: Object) -> bool
func get_move_vector(caller: Object) -> Vector2   # Vector2.ZERO unless caller owns input
func is_save_safe() -> bool                   # Overworld/Camp, no overlay but Menu, IDLE
var current_mode: Mode:            get
var overlay_stack: Array[OverlayKind]: get    # copy; bottom first
var phase: Phase:                  get
var mode_time: float:              get        # stops while Menu is open (AC-20)
var last_camp_id: String:          get

## src/game_state/game_mode.gd — every mode scene's root script
@abstract class_name GameMode extends Node
func setup(machine: GameStateMachine, payload: RefCounted) -> void   # before add_child
@abstract func handle_action(action: StringName, pressed: bool) -> bool  # true = consumed
func on_freezing() -> void                                    # Overworld only, before detach
func on_thawed(encounter_id: String, result: GameStateMachine.BattleResult) -> void  # Overworld only, after mode_entered
func capture_start_snapshot() -> RefCounted                   # Battle only; base returns null = swap failure
func restore_start_snapshot(snapshot: RefCounted) -> void     # Battle only

## src/game_state/game_overlay.gd
@abstract class_name GameOverlay extends Control
func setup(machine: GameStateMachine, payload: RefCounted) -> void
@abstract func handle_action(action: StringName, pressed: bool) -> bool

## Injected collaborators (production versions live beside the machine; tests stub them)
class_name SceneLoader extends RefCounted
enum SwapStatus { PENDING, DONE, FAILED }
func begin_swap(from: int, to: int, payload: RefCounted) -> void
func poll_swap() -> SwapStatus
func rollback_swap() -> void                  # restore the source mode (AC-10)

## Fire-and-forget: the machine's tick timing is authoritative. The presenter never
## signals completion and never blocks or extends a phase.
class_name TransitionPresenter extends RefCounted   # UI Framework implements the visuals
func play_out(transition_type: StringName, duration: float) -> void
func play_in(transition_type: StringName, duration: float) -> void

## ActionSource is a signal-and-method CONTRACT, not a required base class. The Input
## ADR may satisfy it directly or through an adapter in GameRoot (bind_action_source
## takes any Object exposing these members). Names from input-system.md.
#   signal action_pressed(action: StringName)
#   signal action_released(action: StringName)
#   signal focus_lost()
#   signal device_lost()
#   func get_move_vector() -> Vector2
# Deliberately NOT consumed by Game State: action_held, device_restored, focus_gained,
# active_device_changed (UI Framework's concern).

## Payloads (provisional fields per GDD Rule 6 until Overworld/Turn Battle ADRs)
class_name EncounterDescriptor extends RefCounted
var encounter_id: String
var enemy_ids: PackedStringArray
var battle_stage_id: String
var faction_id: String
var is_boss: bool
var can_flee: bool
var retreat_allowed: bool

class_name BattleEntryPayload extends RefCounted
var descriptor: EncounterDescriptor
var party: Array[Combatant]   # interim, until Squad Roster & Recruitment owns the party
```

### Implementation Guidelines
- `GameStateMachine` must extend `RefCounted` and must never reference the scene tree, `get_tree()`, an autoload by name, `Time`, or `Engine`. Time enters only through `tick(delta)`; the catalog, loader, presenter, quit hook and logger enter only through `_init`.
- Game State must never be an autoload. Any system that needs it receives the `GameStateMachine` instance through `setup()` from `GameRoot`. Architecture Principle 4's autoload exception is for read-only state and does not cover this system.
- No system other than `GameStateMachine` (through its `SceneLoader`) may add, remove or free children of `ModeHost` or `OverlayHost`, or set their `process_mode`.
- `SceneTree.change_scene_to_file()`, `change_scene_to_packed()` and `reload_current_scene()` must never be called anywhere in the project. `GameRoot` is the only main scene.
- `SceneTree.paused` must never be used to implement the Menu's time stop; disable `ModeHost` instead.
- A transition request while `phase != IDLE` must return `REJECTED_BUSY` and change no state, except `request_quit()`, which sets a flag that fires the quit hook once, after `transition_finished`.
- Signals must fire in exactly this order for a transition: `transition_started` (start of OUT), `mode_exited` (start of SWAP), `mode_entered` (end of SWAP), `transition_finished` (end of IN). Input unlocks after `transition_finished` is emitted, so the first action after it is delivered (AC-8).
- When `t_swap` runs past `transition_budget - t_out - t_in`, the IN phase must still wait for the swap to finish, and the machine must log a performance warning with the transition type and measured `t_swap`. A budget is never enforced by skipping work.
- A swap failure (`poll_swap() == FAILED`, or descriptor validation failing) must call `rollback_swap()`, re-attach any detached Overworld, play IN back into the source mode, unlock input and log an error. Validating the descriptor before any detach is preferred, so most failures never need a rollback.
- A detached Overworld must be freed explicitly on Retreat, on Quit to Title and in `GameRoot._exit_tree()`; tests must assert no orphan nodes (gdUnit4 exit 101 is a failure for this system).
- Every `GameMode`/`GameOverlay` override with a typed return must end in an explicit `return` (Godot 4.7 typed-return inheritance).
- Mode scripts must tolerate `_exit_tree()`/`_enter_tree()` without `_ready()` re-running: put one-time setup in `_ready()` and anything tied to tree membership (e.g. connecting to world-level signals) in `_enter_tree()`/`_exit_tree()`.
- A mode reads movement only through `machine.get_move_vector(self)`; discrete actions arrive only through `handle_action()`. Modes and overlays must never reference the Input System or connect to its signals directly.
- `TransitionPresenter` calls are fire-and-forget; phase timing comes only from `tick()`.
- Under Game State the Battle mode must call `BattleCore.start_battle(false)` and must never call `retry_battle()`.
- Mode and overlay scene paths, transition timings and budgets come from `TransitionConfig`; tests read thresholds from the config, never literals (GDD Acceptance Criteria preamble).
- After Step 2 of the Migration Plan, `ChapterFlow` must not construct `BattleCore`, connect to `battle_ended`, or hold a fight-start snapshot.

## Alternatives Considered

### Alternative 1: `GameState` autoload + `SceneTree.change_scene_to_packed()`
- **Description**: The textbook Godot pattern. A `GameState` autoload holds the mode and overlay stack and calls `change_scene_to_packed()` for each mode change; overlays live in a second autoload's `CanvasLayer`.
- **Pros**: Least code; familiar; every script can reach the state machine.
- **Cons**: A mutable autoload is exactly what Architecture Principle 4 forbids, and it makes the "stub everything" Acceptance Criteria harder (tests would have to replace a global). `change_scene_*` frees the current scene, so the Overworld freeze would need full serialization of map, NPC, enemy and party state long before Save/Load exists. The API is NOT SOURCEABLE in this repo's engine reference. Retry would still need its own non-scene path.
- **Rejection Reason**: Violates Principle 4, and turns "freeze" into a serialization project the MVP does not need yet.

### Alternative 2: One `SubViewport` per mode, all kept alive
- **Description**: Each mode lives in its own `SubViewport` (its own `World3D`); switching mode toggles which viewport is shown and updated. Freeze is stopping a viewport's updates.
- **Pros**: Strong isolation, since worlds cannot collide; the frozen Overworld is trivially preserved; the blurred-diorama Menu backdrop is a texture.
- **Cons**: Input must be forwarded into viewports; Sprite & Camera Presentation would have to manage per-viewport environments and lighting, right where 4.6 (glow before tonemapping, D3D12 default) and 4.7 (HDR output, `AreaLight3D`) add HIGH-risk rendering changes; every mode's memory is resident all the time; and it adds a layer every future system must understand.
- **Rejection Reason**: Buys isolation that detaching already gives the one mode that needs it, at the cost of rendering risk in the most uncertain part of the engine.

### Alternative 3: Child-swap, but freeze by serializing the Overworld to a snapshot
- **Description**: The same `GameRoot`/`ModeHost` layout, but the Overworld is freed on battle entry and rebuilt from a `capture_snapshot()` dictionary afterwards.
- **Pros**: Snapshot doubles as save data; memory during battles is lower.
- **Cons**: "Restored exactly" then depends on every Overworld field being serialized and every rebuild being faithful — a whole bug class the GDD's AC-11 exists to catch. It also forces Overworld to define its save format before Save/Load's own ADR.
- **Rejection Reason**: Detaching makes exact restore free now. Overworld will still need `capture_snapshot()` for Save/Load, but that belongs to the Save/Load ADR and is not a battle-transition concern.

### Alternative 4 (ChapterFlow): replace now, or wrap unchanged
- **Description**: (a) Delete `ChapterFlow` and wait for Overworld to provide encounters; (b) leave `ChapterFlow` as is and have Game State call into it.
- **Rejection Reason**: (a) leaves the MVP without a playable loop until Overworld ships. (b) keeps two owners of battle construction and two different retry semantics (ChapterFlow's snapshot vs `BattleCore.retry_battle()`'s full heal), which is the overlap QQ-01 asked to remove.

## Consequences

### Positive
- Every GDD Acceptance Criterion that is marked [L] can run headlessly against `GameStateMachine` with stubs, with no scene tree, which is the same testability `BattleCore` already has.
- Exact Overworld restore holds by construction (the instance is never rebuilt), and detaching also takes the Overworld out of Jolt's world during battles.
- Retry needs no load and no new `BattleCore` allocation path in the machine. The battle-start snapshot has one owner, so the full-heal behavior of `retry_battle()` can no longer leak into a carried-over-HP fight.
- Principle 4 holds: the only autoload stays the read-only `ContentCatalog`.
- QQ-01 is closed with a dated exit: `ChapterFlow` survives only as the stand-in Overworld and is deleted when Overworld ships.
- The poll-based `SceneLoader` lets threaded loading arrive later without touching the machine.

### Negative
- More files than the autoload pattern: the machine, `GameRoot`, two abstract base classes, three collaborator interfaces and two payload classes.
- Every system that needs Game State has to be handed it by `GameRoot` (plumbing through `setup()`), rather than reaching a global.
- The frozen Overworld stays resident in memory during battles (acceptable at this game's scale; see Performance).
- Mode scripts must be written to survive leaving and re-entering the tree without `_ready()` re-running, which is an easy rule to forget.
- `ChapterFlow` is refactored again (Story 006 code), and the chapter demo scene has to move under `GameRoot`.
- `BattleEntryPayload.party` is a stop-gap: until Squad Roster & Recruitment exists, the requester supplies the party.

## Risks
- **Detach/re-attach behavior is not in the engine reference** (Timers, Tweens, `_ready()` not re-running). *Mitigation*: verified empirically on 4.7.2 (Engine Compatibility); `AnimationPlayer` remains to be confirmed in Migration Step 1.
- **`Tween.is_running()` stays `true` while a tween is frozen** (bound node detached, or an ancestor disabled), as observed on 4.7.2. *Mitigation*: no freeze, thaw or watchdog code may use `is_running()` to decide whether a tween is progressing; use the mode's own bookkeeping.
- **`@abstract` is checked by the parser, not at runtime**: calling `.new()` directly on an abstract script produced an instance with no error on 4.7.2. *Mitigation*: nothing instantiates `GameMode`/`GameOverlay` directly; test stubs must subclass them, and the abstract marker is not a safety net.
- **Out of scope, flagged for Audio Manager** (hosted under `Services`): 4.7 changed `AudioStreamPlayer2D/3D.area_mask` default to `0` (`breaking-changes.md`), so `audio_bus_override` areas need the mask set to layer 1.
- **`PROCESS_MODE_DISABLED` might not stop every time source** (e.g. a shader using `TIME`, or a `GPUParticles3D`). *Mitigation*: the GDD only requires mode *logic* time to stop (animations, timers, ambient motion); shader `TIME` and particles are presentation the art bible blurs anyway. Sprite & Camera's ADR must state whether ambient shaders read a mode-time uniform instead of `TIME`.
- **4.6 dual-focus**: when an overlay opens, keyboard/gamepad focus must move into it, and return on close. *Mitigation*: Game State only emits `overlay_opened`/`overlay_closed`; focus handoff belongs to the UI Framework and is tracked under `architecture.md` QQ-03. Not solved here.
- **Synchronous loading may overrun the 1.0 s battle-wipe budget** once real dioramas exist. *Mitigation*: overruns are logged (AC-26); the threaded loader is the planned escape hatch behind the same interface, after its APIs are verified.
- **The Input ADR may choose different signal names** than `ActionSource`. *Mitigation*: `ActionSource` is a consumer-side contract; the Input ADR either conforms or supersedes this section by name. `GameRoot` is the one place an adapter would go.
- **Orphan nodes** from a detached Overworld that is never freed. *Mitigation*: explicit frees (Implementation Guidelines) plus gdUnit4's orphan detection (exit 101) treated as failure.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-scene-flow.md | TR-gamestate-001 — one mode plus stacked overlays, changed only via `request_transition`/`open_overlay`/`close_overlay`; 6 signals in fixed order (Rules 1, 2, 4) | `GameStateMachine` is the only writer of mode/overlay state; it exposes exactly those three entry points plus battle reporting, and declares the six signals with a fixed emission order (Implementation Guidelines) |
| game-state-scene-flow.md | TR-gamestate-002 — one transition at a time, no queue except Quit; input locked out→in; failed swap rolls back (Rule 3, Edge Cases) | `phase` gate returns `REJECTED_BUSY`; Quit flag; input dropped while `phase != IDLE`; `SceneLoader.rollback_swap()` and re-attach on failure |
| game-state-scene-flow.md | TR-gamestate-003 — freeze/restore Overworld around Battle; validate Encounter descriptor before entry (Rules 5, 6) | Detach/re-attach of the live Overworld instance; `EncounterDescriptor` validated against `ContentCatalog.has_record()` before any detach |
| game-state-scene-flow.md | TR-gamestate-004 — Retry from battle start snapshot, no scene load; Retreat to last camp, drop snapshot (Rule 8) | `capture_start_snapshot`/`restore_start_snapshot` on the same Battle instance with no loader call; Retreat frees the detached Overworld and targets `last_camp_id` (or the region default camp) |
| game-state-scene-flow.md | TR-gamestate-005 — Boot waits for ContentCatalog; Failed → terminal Content Error (Rule 13) | Boot reads the injected catalog's `state`; Content Error returns `REJECTED_TERMINAL` for everything but Quit |
| game-state-scene-flow.md | TR-gamestate-006 — timings/budgets from data; injectable clock and loader; Menu stops mode time; overruns logged (Formulas, Rule 10) | `TransitionConfig` resource; `tick(delta)` and `SceneLoader` injection; `ModeHost` disabled while Menu open and `mode_time` frozen; overrun warning, never a skip |
| game-state-scene-flow.md | Rule 11 — Dialogue blocks the mode beneath; a follow-up transition runs after the overlay closes | Dialogue is an overlay (input ownership) without disabling `ModeHost`; transition requests while an overlay other than Menu-to-Title is open return `REJECTED_OVERLAY_BLOCKS` |
| game-state-scene-flow.md | Edge Cases — focus lost / device lost opens the Menu, deferred during transitions, ignored in Boot/Content Error | `ActionSource.focus_lost`/`device_lost` handled by the machine with a deferred-Menu flag |
| input-system.md | Rule 2 — Input knows nothing about modes; Game State routes actions and applies the lock | The machine is the sole consumer of `ActionSource`; Input has no reference to Game State |
| content-data-definitions.md | Game State is a hard dependent: Boot starts/waits on the load; Content Error screen | Boot logic above; Content Error is a mode scene showing Content Data's error screen |

## Performance Implications
- **CPU**: Negligible. `tick()` does a few comparisons per frame; signals fire a handful of times per transition. No per-frame allocation.
- **Memory**: During a battle both the detached Overworld and the battle diorama are resident. At MVP scale (one map, a few NPCs, sprite-based dioramas) that is low-single-digit MB; revisit when Overworld maps exist.
- **Load Time**: Synchronous `ResourceLoader.load()` + `instantiate()` inside the swap phase, bounded by the GDD's per-type budgets (0.5 s Retry, 1.0 s battle wipes, 1.5 s fades). Retry and Battle → Overworld load nothing (the Overworld is re-attached, not reloaded). `ResourceLoader`'s cache makes repeat battle-stage loads cheap.
- **Network**: None.

## Migration Plan
0. **Characterization tests first.** Run `/test-setup` (gdUnit4 and `tests/` do not exist yet). Then pin today's `ChapterFlow` behavior in `tests/unit/chapters/`: the fight order (3 regular + boss), per-faction rosters, HP/MP carryover, and boss win → `chapter_won`. The retry semantics are pinned too, as a record of what moves to Battle's snapshot.
1. **Build Game State standalone.** `src/game_state/` — machine, base classes, interfaces, payloads, `TransitionConfig` + `data/config/transition_config.tres`. Unit tests in `tests/unit/game_state/` cover every [L] Acceptance Criterion with stubs. Run the verification spike (Engine Compatibility) in this step.
2. **Re-parent ChapterFlow and wire `GameRoot`, as one story and one commit,** so the playable chapter loop never breaks in between:
   - Remove `BattleCore` construction, the `battle_ended` connection, the snapshot/restore pair and the `fight_lost` retry loop from `chapter_flow.gd`. Add descriptor building (with `retreat_allowed = false`) and an `advance_on_victory()` entry point.
   - Create `ChapterMode` (stand-in Overworld), a Battle mode scene wrapping `BattleCore` + `BattleHud` that implements the snapshot hooks and the carryover contract, and minimal Title, Content Error and Defeat Prompt scenes.
   - Set `run/main_scene` to `game_root.tscn` (currently intentionally unset).
   - Rewrite `chapter_flow_demo.gd` to boot through `GameRoot`, or delete it (a file deletion, so ask first): once ChapterFlow no longer builds battles it cannot run alone. `battle_hud_demo.tscn` and `battle_debug_harness.tscn` stay as standalone harnesses.
   - Step 0's sequencing and carryover tests must still pass unchanged; the retry tests move to the Battle mode.
3. **Remove the interim validation flag** (`validate_enemy_ids_against_catalog`) once ADR-0001's enemy-record migration lands, which must happen before Step 4.
4. **Retire on Overworld.** When Overworld Exploration & Encounters ships, delete `ChapterMode` and `ChapterFlow`; the fight sequence becomes encounter data under ADR-0001.

## Validation Criteria
- Every [L] Acceptance Criterion in `game-state-scene-flow.md` (AC-1 to AC-23) passes headlessly in `tests/unit/game_state/` against stubs, with no orphan nodes.
- AC-24 [I] passes in `tests/integration/game_state/`, and AC-25 screenshots are retained in `production/qa/evidence/`.
- AC-26 [P]: the median of N runs per transition type is within its `TransitionConfig` budget on the development PC, and an injected slow swap logs a warning while IN still waits.
- The verification spike's three checks pass on 4.7.2, with the results recorded in this ADR's Engine Compatibility row.
- Code review finds no `change_scene_*`, no `SceneTree.paused`, no Game State autoload, and no `BattleCore` construction outside the Battle mode.
- Step 0 characterization tests pass unchanged after the ChapterFlow refactor.

## Related
- Depends on: `docs/architecture/adr-0001-content-data-storage-format.md` (Accepted)
- Design: `design/gdd/game-state-scene-flow.md` (closes its Open Question 4), `design/gdd/input-system.md`, `design/gdd/content-data-definitions.md`
- Architecture: `docs/architecture/architecture.md` — closes QQ-01 (ChapterFlow overlap) and the "Scene-transition implementation mechanism" Open Question; upholds Principle 4
- Code: `src/chapters/chapter_flow.gd`, `src/battle/battle_core.gd` (`retry_battle()` full-heal caveat)
- Upcoming: Input System ADR (`ActionSource`), Sprite & Camera Presentation ADR (`ModeHost`, `mode_entered`, shader time), Overworld Exploration ADR (`GameMode` freeze hooks), Save/Load ADR (`is_save_safe()`, Overworld `capture_snapshot()`)

## Review History
- 2026-10-21 — **godot-specialist** (engine validation): APPROVE with minor notes. Headless spike on 4.7.2 verified detach/re-attach state retention and Timer/Tween freezing (Engine Compatibility). Its notes on `Tween.is_running()`, runtime `@abstract` and the `area_mask` default were folded into Risks.
- 2026-10-21 — **technical-director** (TD-ADR): CONCERNS, 10 findings, all revised in this draft: `retreat_allowed = false` in the stand-in; HP/MP carryover contract; an interim enemy-ID validation flag; Migration Steps 2 and 3 merged and the demo rewritten or deleted; `machine.get_move_vector()`; `ActionSource` as a contract, not a base class; typed `on_thawed` and a null-snapshot failure; fire-and-forget presenter; registry and `architecture.md` follow-ups; a stale verification reference.
- 2026-10-21 — **amendments proposed** while this ADR is still Proposed, as annotations only:
  - ADR-0004 (Content Boot Ordering) changes §2 (`GameRoot._enter_tree()` runs `ContentBootstrap.run()`) and §10 (the catalog load timing premise).
  - ADR-0003 (Input System) implements the `ActionSource` contract unchanged. It adds the `nav_*` derived actions routed through `action_pressed`, and the `TransitionLayer` `MOUSE_FILTER_STOP` blocker during transitions.
- Acceptance pending: run `/architecture-review` in a fresh session, then `/architecture-decision accept ADR-0002`. ADR-0003 and ADR-0004 both depend on it.
