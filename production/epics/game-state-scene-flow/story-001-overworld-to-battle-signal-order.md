# Story 001: Overworld → Battle fires exactly the four transition signals, once each, in order

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (it carries the shared scaffold every later story reuses)
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001` (primary), `TR-gamestate-006` (`tick`-driven, injected collaborators)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§1, §3, Key Interfaces, Implementation Guidelines); ADR-0008 §2 amendment (`pre_setup`, noted only); ADR-0009 §6 amendment (`payload_commit`, noted only)
**ADR Decision Summary**: Game State is a pure `RefCounted` `GameStateMachine`, driven only by `tick(delta)` with every collaborator injected through `_init`. A transition runs OUT → SWAP → IN and emits `transition_started`, `mode_exited`, `mode_entered`, `transition_finished` at fixed points.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0008 2026-10-22 · ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `@abstract class_name GameMode extends Node` and `@abstract class_name GameOverlay extends Control` use the 4.5 `@abstract` annotation (one- and two-line forms verified on 4.7.2). `@abstract` is parser-only: `.new()` on the base succeeds silently, so every test double **must subclass**. 4.7 typed-return inheritance means every typed override needs an explicit `return`.

**Control Manifest Rules (this layer)**:
- Required: "Split into a pure logic core (`GameStateMachine`, `RefCounted`) and a thin scene-tree shell (`GameRoot`), joined by injected interfaces."
- Required: "`GameStateMachine` must never reference the scene tree, `get_tree()`, an autoload by name, `Time`, or `Engine`."
- Required: "Signals fire in exactly this order for a transition: `transition_started` … → `transition_finished`."
- Required: "Every `GameMode`/`GameOverlay` override with a typed return ends in an explicit `return`."
- Guardrail: "`GameStateMachine.tick()`: a few comparisons per frame, no per-frame allocation."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-5 [L]** GIVEN Overworld → Battle, THEN exactly these signals fire, once each, in this order: `transition_started`, `mode_exited`, `mode_entered`, `transition_finished` (overlay signals are not counted).

---

## Implementation Notes

*Derived from ADR-0002 §1, §3, Key Interfaces and Implementation Guidelines, plus the QA gate (RC-1):*

- **The machine (§1).** `RefCounted`. It owns the mode, the overlay stack, the phase, the input lock, the Quit-wait flag, the deferred-Menu flag, the frozen-Overworld handle, the battle-snapshot handle, the current descriptor and `last_camp_id`. It never references the scene tree, `get_tree()`, an autoload by name, `Time` or `Engine`. Time enters only through `tick(delta)`; collaborators enter only through `_init(loader, presenter, config, catalog, quit_hook, log, flash_gate = null)`.
- **Enums and read-only state.** `Mode`, `OverlayKind`, `Phase`, `RequestResult`, `BattleResult`; the six signals; read-only `current_mode`, `overlay_stack` (a copy, bottom first) and `phase`.
- **Emission points are fixed.** `transition_started` at the start of OUT, `mode_exited` at the start of SWAP, `mode_entered` at the end of SWAP, `transition_finished` at the end of IN. Phase lengths come from the `TransitionConfig` row for the pair's transition type (`battle_wipe` here). SWAP lasts until `poll_swap()` returns `DONE`.
- **Pinned tick rule (QA RC-1 c; write it in the `tick` doc comment).** A phase ends on the first `tick` where the accumulated phase time is `>= duration - 1e-9`. Overshoot is **not** carried into the next phase. In SWAP, `tick(delta)` adds `delta` to `t_swap` and **then** polls. `transition_time` is the sum of the deltas of the ticks that ran each phase.
- **The transitions table is a `const` in `GameStateMachine`** (§9: "a game rule from the GDD, not a tuning value"). Write it in full here, every row with its type (`fade`, `battle_wipe`, `battle_wipe_reverse`, `retry_flash`, `none`). Story 002 anchors it to the GDD and story 003 tests its complement. Outcome-driven rows (Battle → Overworld/Battle/Camp) and the exit row are reachable **only through their trigger calls**, never through `request_transition()` (draft §2 item 7, accepted).
- **Presenter.** `play_out(type, t_out, capped)` at the start of OUT, `play_in(type, t_in, capped)` at the start of IN. It is fire-and-forget and never signals back; the test asserts no completion callback was requested.
- `flash_gate` defaults to `null` ("never capped"). Flash booking lands in story 017.
- **Read-only debug state (QA RC-1 b).** Expose one documented `get_debug_state() -> Dictionary` with `mode`, `overlay_stack`, `phase`, `frozen_overworld_id` (instance ID or 0), `battle_snapshot_id`, `last_camp_id`, `quit_pending`, `menu_deferred`, `pending_outcome`. It returns a fresh dictionary and is never written through. `game_state_probe.gd` compares two of these; tests never read `_private` members.
- **Ordered recorder (QA RC-1 a).** `tests/unit/game_state/doubles/sequence_recorder.gd` connects to all six machine signals and is also handed to the quit spy, the stub loader, the stub presenter and the stub modes. Each appends `{event, args}` to one shared array. Every before/after assertion in this epic compares indices in that array (gdUnit4's signal monitor counts but does not order across signals).
- **Doubles, created once and reused** (`tests/unit/game_state/doubles/`): `stub_scene_loader.gd` (counts `begin_swap`; scriptable PENDING ×n / DONE / FAILED), `stub_transition_presenter.gd`, `stub_catalog.gd` (scriptable `state`, `has_record`), `synthetic_action_source.gd` (the ADR-0002 `ActionSource` contract: `action_pressed`, `action_released`, `focus_lost`, `device_lost`, `get_move_vector()`), `spy_game_state_log.gd` (structured `{level, code, context}`), `quit_spy.gd`, `stub_flash_gate.gd`, `stub_overworld_mode.gd` / `stub_battle_mode.gd` / `stub_camp_mode.gd` (subclass `GameMode`), `stub_overlay.gd` (subclasses `GameOverlay`), `sequence_recorder.gd`, and `game_state_fixtures.gd` (factories for `EncounterDescriptor`, `BattleEntryPayload`, the Overworld snapshot and `TransitionConfig`). **Thresholds come from a `TransitionConfig` fixture, never literals.**
- **"Rejected"** everywhere in this epic means: a non-`OK` `RequestResult` **and** `get_debug_state()` unchanged. Logged errors are asserted on structured fields (`code`, `context`), never on wording.
- **Interface additions (draft §2 item 6).** ADR-0002's `SceneLoader` has only `begin_swap`/`poll_swap`/`rollback_swap`. Add `push_overlay`, `pop_overlay`, `set_mode_time_stopped`, `free_frozen_overworld`, `current_mode_node` to the interface and record them in Completion Notes for the batched technical-director annotation to ADR-0002.
- `pre_setup` / `payload_commit` are production `SceneLoader` concerns (ADR-0008 §2, ADR-0009 §6). The base `GameMode`/`GameOverlay` stay unchanged and name no Presentation type; mention them in the interface doc comment only.
- `TransitionConfig` here holds fields only: per-type `t_out`, `t_in`, `transition_budget`; mode and overlay path tables as `String`; `validate_enemy_ids_against_catalog: bool = false`. Load-time validation is story 006.
- Doc comments on every public API. Every test that creates a `Node` uses `auto_free()`; gdUnit4 exit 101 (orphans) is a failure.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the GDD anchor for the transitions table and every row's trigger.
- Story 006: `TransitionConfig.validate()` and the measured `transition_time`.
- Story 010: input routing and the lock.
- Story 017: flash-gate booking.

---

## Files

- `src/game_state/game_state_machine.gd`
- `src/game_state/game_mode.gd`, `src/game_state/game_overlay.gd` (abstract bases, Key Interfaces verbatim)
- `src/game_state/scene_loader.gd` (interface: `SwapStatus`, `begin_swap`, `poll_swap`, `rollback_swap`, plus the proposed additions)
- `src/game_state/transition_presenter.gd` (fire-and-forget interface)
- `src/game_state/game_state_log.gd` (structured `error(code, context)` / `warning(code, context)`)
- `src/game_state/transition_config.gd` (fields only)
- `src/game_state/encounter_descriptor.gd`, `src/game_state/battle_entry_payload.gd`
- `tests/unit/game_state/doubles/*.gd` (every double above, including `sequence_recorder.gd`)
- `tests/unit/game_state/game_state_probe.gd`
- `tests/unit/game_state/game_state_signal_order_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: `sequence_recorder.gd`, read-only `get_debug_state()`, pinned tick rule). The developer implements against these — do not invent new test cases during implementation.*

- **AC-5**: `game_state_signal_order_test.gd :: test_overworld_to_battle_fires_four_signals_in_order`
  - Given: a machine built from `game_state_fixtures` with the stub loader scripted `[PENDING, DONE]`, the stub presenter, `cfg` = the fixture `TransitionConfig`, and a `sequence_recorder` on all six signals. The machine is placed in OVERWORLD through the fixture path (Boot → Title → Overworld with a READY stub catalog), then the recorder is cleared.
  - When: `request_transition(BATTLE, fixtures.valid_battle_entry())` returns `OK`; tick by `cfg` battle_wipe `t_out`; tick twice in SWAP; tick by `cfg` battle_wipe `t_in`.
  - Then: recorder events == `[transition_started(OVERWORLD, BATTLE), mode_exited(OVERWORLD), mode_entered(BATTLE), transition_finished(BATTLE)]`, each exactly once; no `overlay_opened`/`overlay_closed`; `presenter.play_out` called once with `(&"battle_wipe", t_out, false)` at an index before `mode_exited`, `play_in` once with `(&"battle_wipe", t_in, false)` after `mode_entered`; `phase == IDLE`; `current_mode == BATTLE`.
  - Edge cases: ticks of 1/60 s instead of whole-phase ticks give the same sequence (bounded loop, max 600 ticks); the machine source contains no `get_tree`/`Time`/`Engine` reference (code-review checklist item, not a runtime test); `GameMode.new()` on the base succeeds silently (documents why stubs subclass) and `stub_overworld_mode` is a `GameMode`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_signal_order_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-001-install-gdunit4.md`
- Unlocks: every other Step 1 story (002–031); directly `story-004`, `story-006`, `story-008`, `story-010`, `story-014` in `production/epics/game-state-scene-flow/`
