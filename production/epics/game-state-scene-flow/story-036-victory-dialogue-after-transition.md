# Story 036: A Victory that triggers story dialogue opens Dialogue only after transition_finished(Overworld)

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§4: `on_thawed` after `mode_entered(OVERWORLD)`; Validation Criteria: "AC-24 [I] passes in `tests/integration/game_state/`"); GDD Edge Cases ("A story dialogue never opens over a half-revealed scene")
**ADR Decision Summary**: `on_thawed` runs after `mode_entered` but before `transition_finished`, while the machine is still busy, so a Dialogue open attempted there is rejected; the requester retries on `transition_finished(OVERWORLD)`.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Runs under the real `GameRoot` + `ChapterMode` + Battle mode. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Signals fire in exactly this order for a transition …"
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` …" (the overlay case, story 008).
- Required: "A detached Overworld is freed explicitly … Tests must assert no orphan nodes."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-24 [I]** (with Dialogue) GIVEN a Victory that triggers story dialogue, THEN the Dialogue overlay opens only after `transition_finished(Overworld)`.

---

## Implementation Notes

*Derived from ADR-0002 §4 and the QA gate:*

- The Dialogue system does not exist. **Pinned (QA):** the stub dialogue requester is a test subclass, `chapter_mode_with_story_dialogue.gd`, that extends `ChapterMode`, calls `super.on_thawed(...)`, then attempts `open_overlay(DIALOGUE)`. That call must return `REJECTED_BUSY` (a transition is running). The subclass retries on `transition_finished(OVERWORLD)`, and that call succeeds.
- `stub_dialogue_overlay.tscn` is a `GameOverlay` registered in a test `TransitionConfig` overlay table, and it is pushed through story 030's production overlay push.
- Runs under the real `GameRoot` (or story 035's integration harness) with a scripted Victory; that is what makes it Integration.
- No orphans on teardown: the frozen Overworld was re-attached and the Battle mode freed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 027: the machine-level close-then-request rule.
- The Dialogue epic (future), which will reuse this harness.

---

## Files

- `tests/integration/game_state/game_state_victory_dialogue_test.gd`
- `tests/integration/game_state/fixtures/chapter_mode_with_story_dialogue.gd`
- `tests/integration/game_state/fixtures/stub_dialogue_overlay.tscn`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; the requester subclass pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-24**: `game_state_victory_dialogue_test.gd :: test_dialogue_after_transition_finished`
  - Given: `GameRoot` (or the integration harness from 035) with the test `ChapterMode` subclass and `stub_dialogue_overlay.tscn` registered in a test `TransitionConfig` overlay table; a scripted Victory.
  - When: Victory → `report_results_done` → return to Overworld.
  - Then: the attempt inside `on_thawed` returned `REJECTED_BUSY`; the retry on `transition_finished(OVERWORLD)` returned `OK`; recorder `index(overlay_opened(DIALOGUE)) > index(transition_finished(OVERWORLD))`.
  - Edge cases: no orphans on teardown; the Battle node is freed.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/game_state/game_state_victory_dialogue_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-015-victory-waits-for-results.md`, `production/epics/game-state-scene-flow/story-027-dialogue-closes-before-transition.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md` (production overlay push), `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`
- Unlocks: None (the Dialogue epic will reuse the harness)
