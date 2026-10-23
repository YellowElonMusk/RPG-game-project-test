# Story 026: A Failed catalog keeps Game State in its boot state, never reaching overworld or battle

> **Epic**: Content Catalog
> **Status**: Blocked — BLOCKED: depends on `production/epics/game-state-scene-flow/` (`GameRoot`, `GameStateMachine` and the Boot → Content Error rule belong to that epic). Not ADR-blocked: every governing ADR is Accepted.
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (States: Game State waits for Ready); ADR-0004: Content Boot Ordering (§2: the load completes in `GameRoot._enter_tree()`; Boot reads the terminal state on its first tick). The mode contract itself is ADR-0002's, owned by the other epic.
**ADR Decision Summary**: `ContentBootstrap.run()` runs in `GameRoot._enter_tree()`, so the catalog is terminal before anything under `GameRoot` initializes. Boot reads the terminal state and goes to Title on Ready or Content Error on Failed; it never enters Overworld or Battle with a Failed catalog.
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: ADR-0004 verified on 4.7.2 that an autoload's `_ready()` runs after the main scene's `_enter_tree()`. The test relies on that order only as a safety net.

**Control Manifest Rules (this layer)**:
- Required (once unblocked): "Game State & Scene Flow must wait for Ready before leaving the boot state." "`GameRoot._enter_tree()` calls only `ContentBootstrap.run()`." "Tests must assert no orphan nodes (gdUnit4 exit 101 is a failure for this system)."
- Forbidden: any Game State transition into gameplay on a non-Ready catalog.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-23** GIVEN a catalog that ends Failed, WHEN the game boots, THEN Game State & Scene Flow remains in its boot state and never enters the overworld or battle state.

---

## Implementation Notes

*Derived from ADR-0004 §2 and EPIC.md scope:*

- A tracking entry, so `/story-readiness` surfaces AC-23 when `game-state-scene-flow`'s boot story exists. This epic's part is already done once story 009 ships: `ContentCatalogService.state == FAILED` is terminal and readable.
- The integration test needs `GameRoot` to accept a data root (passed through to `ContentBootstrap.run(catalog, data_root)`, story 002), so it can boot on a Failed fixture. That injection point is the owning epic's decision.
- Test location: `tests/integration/content_data/` or `tests/integration/game_state/`; the owning epic decides.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `game-state-scene-flow`: `GameRoot`, `GameStateMachine`, the Boot and Content Error modes.
- Story 025: what the Content Error screen shows.

---

## Files

- None in this epic's code root. Once unblocked:
- `tests/integration/content_data/content_data_failed_boot_test.gd` (or under `tests/integration/game_state/`)
- Reuses `tests/unit/content_data/fixtures/one_error_rest_valid/` (story 009)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE, DEFERRED until `GameRoot` exists). The developer implements against these — do not invent new test cases during implementation.*

- **AC-23 / T1**: Boot never leaves for gameplay on a Failed catalog.
  - Given: a Failed-guaranteed fixture at an injected data root, and `GameRoot` instantiated in a gdUnit4 scene runner.
  - When: the runner advances 30 process frames past the point where Boot would normally transition.
  - Then:
    - the current mode is Boot / Content Error
    - a signal monitor recorded no `mode_entered` for Overworld or Battle
    - no orphan nodes remain (control manifest: gdUnit4 exit 101 counts as a failure)
  - Edge cases: the same runner with `valid_one_of_each` reaches Title, which proves the test can tell the two outcomes apart.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/content_data/content_data_failed_boot_test.gd` (or the owning epic's `tests/integration/game_state/` equivalent) — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-009-one-error-fails-catalog.md`, and the `production/epics/game-state-scene-flow/` boot-state story (not yet created; re-check that epic once its stories exist)
- Unlocks: None
