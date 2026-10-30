# Story 019: Changing the held direction mid-repeat fires one immediate step and restarts the timer from `repeat_delay`

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`, `TR-input-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§8)
**ADR Decision Summary**: A change of held menu direction counts as a new press: one immediate `nav_*` step for the new direction, and the repeat timer restarts from `repeat_delay`, all from `InputConfig`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**`action_pressed`/`action_released` fire on edges ... `nav_*` are derived actions, never bound directly**"
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, ...) are a project config (`InputConfig`)"
- Guardrail: negligible work per `tick`.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-8** Changing the held direction mid-repeat fires one immediate step and restarts the timer from `repeat_delay`.

---

## Implementation Notes

*Derived from ADR-0003 §8 and the GDD Edge Cases:*

- **What counts as a change.** GDD Edge Cases: "a new direction pressed, or one of two opposing keys released so a single direction remains". That counts as a new press: one immediate step for the new direction, with `k` reset to 0.
- **Change time (pinned).** The change resets `elapsed` to 0 at the `feed_event` that causes it; the next step is due `repeat_delay` after that event.
- **The AC is tested with unambiguous changes only:**
  - (a) down released and right pressed in the same frame: an immediate `nav_right`, the next one at `repeat_delay` after the change, no `nav_down` after the change;
  - (b) left + right held (cancelled, no steps; this is the GDD edge case "menu repeat stops for that axis"), then left released: an immediate `nav_right`.
- **Perpendicular press while a direction is held (recommended reading, owner to confirm).** The GDD supports two readings ("menu repeat stops for *that axis*" against "*the* repeat timer restarts"): per-axis independent repeat, or a single repeat stream. Recommended reading (QL-STORY-READY 2026-10-23): **a single stream, where the newest direction is the held direction** — so pressing right while down repeats stops `nav_down` and starts `nav_right` at k = 0. *game-designer to confirm.* Implement to the recommended reading; no automated test asserts the perpendicular case until the ruling is recorded (it is not part of this story's done gate, and a test must not decide it).
- Expected times come from config, plus a `NON_DEFAULT` run.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: the base repeat schedule.
- Story 006: the move-vector side of opposite-direction cancellation.

---

## Files

- `src/input/input_resolver.gd` (direction-change handling)
- `tests/unit/input/input_menu_repeat_test.gd` (shared with story 018)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: unambiguous change cases only, change time pinned, perpendicular case escalated with a recommended reading). The developer implements against these — do not invent new test cases during implementation.*

**AC-8** — a direction change fires an immediate step and restarts from `repeat_delay`.

```
Test: a direction change fires an immediate step and restarts from repeat_delay
Given: R, cfg ∈ {DEFAULT, NON_DEFAULT}; S held for M ticks, with M past at least 2 repeats
When:  in one frame, release S and press D; then tick(DT) until repeat_delay + 2 × repeat_interval after the change
Then:  nav_right fires inside the feed_event for D (before any tick); the next nav_right is at the first tick n with n × DT + EPS_T >= repeat_delay measured from the change; no nav_down after the change
Edge cases: none
```

```
Test: releasing one of two opposed keys counts as a new press
Given: R; A and D held for 2 × repeat_delay (no nav_left or nav_right during it)
When:  release A
Then:  an immediate nav_right, then the repeat schedule from repeat_delay after the release
Edge cases:
  - pressing D while A repeats stops the x-axis repeat immediately (no further nav_left)
```

OPEN (not in the done gate): a perpendicular press while a direction is held — game-designer to rule; recommended reading is a single stream (newest direction wins).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_menu_repeat_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30; tests/unit/input 240/240, single-dir run, tag sin3)

---

## Dependencies

- Depends on: `production/epics/input-system/story-018-menu-repeat-timing.md`
- Unlocks: None

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin3).*

- **Files**: `tests/unit/input/input_menu_repeat_test.gd` (story 019 section). No source change: `_update_nav()` (single stream, newest direction wins) already met AC-8.
- **Tests** (DEFAULT and NON_DEFAULT): down released + right pressed fires nav_right inside feed_event, then the schedule from repeat_delay after the change, no nav_down; A+D cancelled (no steps), releasing A fires nav_right then the schedule; pressing D while A repeats stops the x-axis repeat.
- **Deviations**: the perpendicular-press case stays untested, as the story says (game-designer ruling OPEN). The implementation follows the recommended single-stream reading.
