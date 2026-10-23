# Story 004: Boot goes to Title on a Ready catalog and to Content Error on a Failed one

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§10); ADR-0004: Content Boot Ordering (§2)
**ADR Decision Summary**: Boot reads the injected catalog's state each tick: Ready → the Boot → Title `fade`; Failed → the instant Boot → Content Error (`none`). ADR-0004 completes the load in `GameRoot._enter_tree()`, so Boot normally resolves on its first tick, but the machine must not assume it.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine against `stub_catalog.gd`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`GameRoot._enter_tree()` calls only `ContentBootstrap.run()`. Everything else is built in `GameRoot._ready()`" (why Boot normally sees a terminal state).
- Forbidden: "Never let `src/data/` import `src/boot/` …" (the machine may not reference `src/boot/` either, ADR-0004).
- Forbidden: "Never lazy-load the catalog on the first lookup."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-1 [L]** GIVEN a stub catalog that becomes Ready, WHEN Boot runs, THEN the mode becomes Title. GIVEN a stub that becomes Failed, THEN the mode becomes Content Error.

---

## Implementation Notes

*Derived from ADR-0002 §10 and ADR-0004 §2:*

- The machine starts in `BOOT`. On each tick in Boot it reads the **injected** catalog's `state`: `READY` → the Boot → Title `fade`; `FAILED` → the instant Boot → Content Error (`none`: zero-length phases, but the four signals still fire in order); `UNLOADED` / `LOADING` / `VALIDATING` → stay in Boot.
- Reading the catalog's status is internal to Boot, "not the presentation-polls-state pattern GDD rule 4 forbids" (§10).
- The stub covers "becomes Ready **later**" (several ticks in `LOADING`).
- The machine compares against `ContentCatalogService.State` (Foundation → Foundation, allowed). It never imports anything under `src/boot/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: behaviour once in Content Error.
- Story 035: the real `GameRoot` boot and the Content Error scene.
- `production/epics/content-catalog/story-026-failed-catalog-blocks-boot.md`: the integration test on a real catalog.

---

## Files

- `src/game_state/game_state_machine.gd` (Boot tick)
- `tests/unit/game_state/game_state_boot_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: `game_state_boot_test.gd :: test_ready_catalog_goes_to_title` / `test_failed_catalog_goes_to_content_error`
  - Given: a fresh machine (mode BOOT); `stub_catalog.state` scripted (a) READY, (b) FAILED, (c) LOADING ×5 then READY.
  - When: tick in fixed steps until `phase == IDLE` after a transition (bounded, max 600 ticks).
  - Then: (a) `current_mode == TITLE` via `fade` (presenter got `&"fade"`); (b) `current_mode == CONTENT_ERROR`, presenter got `&"none"` with zero durations, and the four signals fired in order; (c) the mode stays BOOT with no signal for the 5 LOADING ticks, then TITLE.
  - Edge cases: UNLOADED and VALIDATING behave like LOADING; the stub catalog's State values mirror `ContentCatalogService.State` (enum compared, not ints); the machine script does not preload anything under `src/boot/` (code-review item).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_boot_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-001-overworld-to-battle-signal-order.md`, `production/epics/content-catalog/story-002-load-one-of-each-type.md` (the `ContentCatalogService.State` values the stub mirrors)
- Unlocks: `production/epics/game-state-scene-flow/story-005-content-error-rejects-all-but-quit.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/content-catalog/story-026-failed-catalog-blocks-boot.md` (together with 035)
