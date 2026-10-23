# Story 025: On launch with 30 errors, the player sees the plain-text error screen, never a crash or blank screen

> **Epic**: Content Catalog
> **Status**: Blocked — BLOCKED: depends on `production/epics/game-state-scene-flow/` (the Content Error scene and the Boot → Content Error transition are built there; this epic supplies only the report and story 024's text builder). Not ADR-blocked: every governing ADR is Accepted.
> **Layer**: Foundation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-008`, `TR-content-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (report format); ADR-0004: Content Boot Ordering (the load completes in `GameRoot._enter_tree()`, before Boot reads the terminal state). The scene and mode contract are ADR-0002's (Game State & Scene Flow), owned by the other epic.
**ADR Decision Summary**: A Failed catalog leads to a plain-text Content Error screen listing the first `ERROR_SCREEN_CAP` errors and the log path. The screen uses no art, animation or faction styling, so it works even when the content defining those visuals is what failed.
**ADR Version**: ADR-0001 2026-10-23; ADR-0004 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Defer to the owning epic's engine analysis for the scene and mode machinery. This story adds no engine API.

**Control Manifest Rules (this layer)**:
- Required (once unblocked; owning epic's rules): "`GameRoot._enter_tree()` calls only `ContentBootstrap.run()`." "Mode swap = child swap under `ModeHost`." "Logs, IDs, validation errors and the Content Error screen must not be translated" (ADR-0013).
- Forbidden: building the Content Error scene in this epic.
- Guardrail: the screen is readable at 1280×720 (GDD UI Requirements).

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-22** GIVEN a data set with 30 errors, WHEN the game is launched, THEN the player sees the plain-text error screen (no crash, no blank screen). Evidence: retained screenshot.

---

## Implementation Notes

*Derived from GDD UI Requirements and EPIC.md scope:*

- This story is a tracking entry, so `/story-readiness` surfaces AC-22 once `game-state-scene-flow` has the story that builds the Content Error scene. Do not build a scene here: EPIC.md says "the Content Error *scene* is built by `game-state-scene-flow`".
- What this epic supplies: the Failed terminal state (story 009), the sorted report (story 023) and `ValidationReportText.build_error_screen_text()` / `build_log_text()` with `ContentReportConfig` (story 024). The scene calls them and writes the log file.
- The 30-error data set: a fixture of 30 `.tres` files under `tests/integration/content_data/fixtures/thirty_errors/`, each a root-type Character with one F1 error (zero-padded IDs, as in story 024), pointed at through the data root. How a launched build is pointed at a non-default data root (a command-line user argument read by `GameRoot`) is the owning epic's decision.
- UI evidence is BLOCKING and is not waived at any `qa.level`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `game-state-scene-flow`: the Content Error scene, its Quit action, keyboard and gamepad navigation, the log-file write.
- Story 024: the text builder.

---

## Files

- None in this epic's code root. Evidence only, once unblocked:
- `tests/integration/content_data/fixtures/thirty_errors/` (30 records)
- `production/qa/evidence/content-catalog-025-error-screen-[date].png`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE, DEFERRED until a full build with game-state-scene-flow exists). The developer implements against these — do not invent new test cases during implementation.*

- **AC-22**: The plain-text error screen appears on a 30-error launch.
  - Setup: on a build that contains game-state-scene-flow's Content Error scene, point the data root at the 30-error set (`.tres`, generated with the same zero-padded IDs as story 024). Launch the game normally, not with the editor's Run Current Scene.
  - Verify: observe for 10 seconds.
  - Pass condition:
    - the process has not crashed and the screen is not blank
    - exactly 20 error lines are visible, each with record ID, field and location (GDD UI Requirements)
    - the full log path line is visible on screen, not pushed off (Tuning Knobs, `ERROR_SCREEN_CAP` row)
    - the log file at that path holds 30 entries
  - Retain the screenshot as `production/qa/evidence/content-catalog-025-error-screen-[date].png`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- UI: a retained screenshot of the Content Error screen in `production/qa/evidence/` (`content-catalog-025-error-screen-[date].png`). Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-024-error-screen-text.md`, and the `production/epics/game-state-scene-flow/` story that builds the Content Error scene and mode (not yet created; re-check that epic once its stories exist)
- Unlocks: None
