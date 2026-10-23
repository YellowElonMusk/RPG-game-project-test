# Story 020: A stick just under `menu_stick_threshold` after the deadzone rescale gives no menu step, and just over it gives one

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`, `TR-input-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§4 `menu_stick_threshold`, §8); ADR-0008: UI Framework (Depends On: the UI reads `InputConfig.menu_stick_threshold` for its held-direction mirror)
**ADR Decision Summary**: A stick becomes a menu direction when its rescaled per-axis output crosses `InputConfig.menu_stick_threshold`; crossing it is the menu "press" (step 0 immediately), and dropping back under it is the release.
**ADR Version**: ADR-0003 2026-10-21; ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Required: "**`action_pressed`/`action_released` fire on edges ... `nav_*` are derived actions, never bound directly**"
- Guardrail: negligible work per `tick`.

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-9** A stick at `menu_stick_threshold − 1e-6` (after the deadzone rescale) along an axis produces no menu step; at `menu_stick_threshold + 1e-6` it produces one.

---

## Implementation Notes

*Derived from ADR-0003 §4, §8 and the GDD Tuning Knobs:*

- **Threshold.** The threshold applies to the **rescaled** output along the axis (GDD Tuning Knobs: "Applied after the deadzone rescale"). The test inverts the formula to find the raw value giving `threshold ± 1e-6` after rescale: `raw = deadzone + target × (1 − deadzone)`. Both values come from config, plus a `NON_DEFAULT` run.
- **What crossing means.** Crossing the threshold is the menu-direction "press" and fires step 0 immediately (inside `feed_event`). Dropping back under it is the release and stops repeat.
- **Per axis.** The threshold is compared per axis on the rescaled vector's component, not on the vector length.
- **Move vector sign convention (pinned).** `move_up` = (0, −1), so `left_y` negative past the threshold gives `nav_up`. *Ruling 2026-10-23, to be recorded in ADR-0003 §8 by technical-director; ADR-0012 owner to confirm.*
- **Re-centre latch.** ADR-0003 §1's per-axis "re-centre before counting" latches belong to focus return (story 025). Don't require re-centring here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 025: the re-centre latch after focus return.
- Story 018: the repeat schedule (reused here).

---

## Files

- `src/input/input_resolver.gd` (stick → menu direction)
- `tests/unit/input/input_menu_repeat_test.gd` (shared with story 018)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

**AC-9** — the stick menu threshold is applied after the rescale.

```
Test: the stick menu threshold is applied after the rescale
Given: R, cfg ∈ {DEFAULT, NON_DEFAULT}, raw(t) = cfg.deadzone + t × (1 − cfg.deadzone)
When:  (a) pad_axis left_x at raw(threshold − 1e-6), then tick through repeat_delay; (b) a fresh R, left_x at raw(threshold + 1e-6)
Then:  (a) no nav_*; (b) exactly one nav_right inside feed_event, and the repeat follows story 018's schedule while held
Edge cases:
  - left_y negative past the threshold gives nav_up (y-down convention)
  - dropping back under the threshold stops the repeat
  - the threshold is per axis: raw (0.5, 0.5) at DEFAULT (rescaled per-axis component below 0.60) gives no step
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_menu_repeat_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-005-radial-deadzone.md`
  - `production/epics/input-system/story-018-menu-repeat-timing.md`
- Unlocks: None
