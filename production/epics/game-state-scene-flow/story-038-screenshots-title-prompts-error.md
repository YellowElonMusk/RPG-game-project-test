# Story 038: Retained screenshots of Title, both Defeat Prompts, the Quit confirmation and Content Error

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`, `TR-gamestate-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*
**UX reference**: `design/ux/interaction-patterns.md` P4, P15 (no screen-specific UX specs exist yet)

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§2); ADR-0008: UI Framework (§9 resolution: 1280×720 base, the Deck at 1280×800; §10 accessibility)
**ADR Decision Summary**: The minimal screens this epic builds are reached only through the machine and captured at the base resolution as retained evidence. Their visual pass belongs to the UI Framework epic.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Evidence only; launch through `commands.run`, never Run Current Scene.

**Control Manifest Rules (this layer)**:
- Required (Input): "Every overlay root has a full-screen `MOUSE_FILTER_STOP` backdrop; `TransitionLayer` shows one for the whole transition."
- Required: "Mode/overlay scene paths … come from `TransitionConfig` data" (the screens are reached only through the machine).
- Forbidden: launching a screen with Run Current Scene for evidence.

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-25 [UI]** *(part 1 of 3, the screens this epic builds)* "Retained screenshots: Title (New Game focused, Continue disabled with its lock glyph); Defeat Prompt with and without Retreat (Retry focused); the Quit confirmation (No focused); … Content Error screen."

---

## Implementation Notes

*Derived from ADR-0002 §2, ADR-0008 §9 and the QA gate (RC-6):*

- **Reaching each screen deterministically (QA RC-6).** Story 035 owns the debug-build-only launch arguments (`--debug-force-outcome=defeat`, `--debug-retreat-descriptor`). The evidence file records the exact launch line per shot:
  1. normal launch → Title;
  2. `--debug-force-outcome=defeat` → Defeat Prompt without Retreat;
  3. add `--debug-retreat-descriptor` → Defeat Prompt with Retreat (`ChapterMode` always sends `retreat_allowed = false`, so it is otherwise unreachable);
  4. Title → Quit → confirmation;
  5. `--data-root=` pointing at the content-catalog fixture `one_error_rest_valid` → Content Error.
- Retreat itself stays visually untested until Camp exists (story 040).
- Debug build via `commands.run` at 1280×720. The minimal scenes have no art; that is expected.
- UI evidence is BLOCKING and is not waived at any `qa.level`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 039: the Menu screenshots.
- Story 040: the Camp screenshot.
- `production/epics/content-catalog/story-025-error-screen-on-launch.md`: keeps its own 30-error screenshot.

---

## Files

- `production/qa/evidence/game-state-038-title-[date].png`
- `production/qa/evidence/game-state-038-defeat-prompt-retry-only-[date].png`
- `production/qa/evidence/game-state-038-defeat-prompt-retreat-[date].png`
- `production/qa/evidence/game-state-038-quit-confirm-[date].png`
- `production/qa/evidence/game-state-038-content-error-[date].png`
- `production/qa/evidence/game-state-038-evidence.md` (launch line and setup per shot)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: deterministic launch lines via 035's debug args). **DEFERRED** (manual verification note): needs the running build. The developer implements against these — do not invent new test cases during implementation.*

- **AC-25 (part 1)**: manual check, game-state-038 screens
  - Setup: a debug build via `commands.run` (1280×720); `game-state-038-evidence.md` records the launch line per shot: (1) normal launch → Title; (2) `--debug-force-outcome=defeat` → Defeat Prompt without Retreat; (3) add `--debug-retreat-descriptor` → Defeat Prompt with Retreat; (4) Title → Quit → confirmation; (5) `--data-root=` pointing at content-catalog fixture `one_error_rest_valid` → Content Error.
  - Verify: (1) New Game shows the focus indicator, Continue is visibly disabled with its lock glyph; (2) only Retry, focused; (3) Retry and Retreat, Retry focused; (4) No focused; (5) error text visible, Quit is the only control, no art or faction styling.
  - Pass condition: five PNGs retained in `production/qa/evidence/` with the names in Files, each matching its Verify line; qa-lead confirms.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- UI: the five retained screenshots listed in Files, in `production/qa/evidence/`, plus `game-state-038-evidence.md`. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`, `production/epics/game-state-scene-flow/story-031-title-focus-and-quit-confirm.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`
- Unlocks: None
