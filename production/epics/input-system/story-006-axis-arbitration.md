# Story 006: Opposite directions cancel on an axis, the larger stick or d-pad magnitude wins, and the d-pad wins a tie

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§3 why `InputMap` is not used, §8)
**ADR Decision Summary**: The resolver arbitrates the move vector per axis between digital (key/d-pad) and analog (rescaled stick) sources — rules `InputMap` cannot express because it merges devices. Diagonal normalization runs after arbitration.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**The binding table is the resolver's own dictionary, matched by `physical_keycode` / `JoyButton` / `JoyAxis` / `MouseButton`**, never `InputMap`"
- Required: "**`InputResolver` (`RefCounted`) owns the binding table, held set, move vector and device state, with no scene-tree dependency.**"
- Forbidden: "**Never use Godot's `InputMap`/`Input` singleton for gameplay actions** — it merges devices and can't express the GDD's per-axis arbitration rules"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [x] **AC-6** Opposite directions held together give 0 on that axis. Stick and d-pad on the same axis: the larger magnitude wins. At equal magnitude, the d-pad wins.

---

## Implementation Notes

*Derived from ADR-0003 §3, §8 and the GDD Edge Cases:*

- **Per-axis arbitration.** Digital = (+1 if any positive digital source held) + (−1 if any negative held), so opposites give 0. Compute the analog component from story 005's rescaled stick. On each axis, take the source with the larger absolute value. **On a tie the digital (d-pad/key) wins**. With the d-pad at magnitude 1, a tie means the rescaled stick is also at 1, so the observable difference is the **sign** when they point opposite ways. Test exactly that: stick full right with d-pad left gives −1.
- **Opposite digital directions plus a deflected stick (recommended reading, owner to confirm).** The GDD does not say what happens when opposite digital directions cancel to 0 **and** a stick is deflected on that axis (GDD Edge Cases says "`move.x` = 0"). Recommended reading (QL-STORY-READY 2026-10-23): a digital 0 from cancellation counts as magnitude 0, so a deflected stick wins that axis. "Opposite directions give 0" is asserted with no stick deflection. *GDD owner / game-designer to confirm.* If the owner prefers "cancellation forces 0", the edge case "d-pad left + d-pad right + stick at 0.5 right gives x == 0.5" flips to 0.
- **Two pads.** The stick term per axis is the pad stick with the larger absolute rescaled value.
- **Move vector sign convention (pinned).** `move_right` → (+1, 0), `move_left` → (−1, 0), `move_up` → (0, −1), `move_down` → (0, +1) (y-down). *Ruling 2026-10-23, to be recorded in ADR-0003 §8 by technical-director; ADR-0012 owner to confirm.*
- **Diagonal normalization.** Apply it after arbitration (story 004), only if the length is > 1.
- Assert the result as the composed `get_move_vector()`. The menu-repeat half of the GDD edge case ("menu repeat stops for that axis") is tested in story 019.
- To place the stick at a rescaled value s, the test inverts the formula: `raw = deadzone + s × (1 − deadzone)`, from cfg.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 019: menu repeat stopping when an axis cancels.
- Story 005: the rescale itself.

---

## Files

- `src/input/input_resolver.gd`
- `tests/unit/input/input_axis_arbitration_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: cancellation-plus-stick reading (recommended, owner to confirm), two-pad stick rule). The developer implements against these — do not invent new test cases during implementation.*

**AC-6** — opposite cancel, larger magnitude wins, d-pad wins a tie.

```
Test: opposite digital directions cancel on that axis
Given: R with DEFAULT
When:  hold A+D (and, parametrized, W+S, left+right arrows, d-pad left+right, and key left with d-pad right)
Then:  that axis is 0 and the other axis is unaffected (W+A+D gives (0, −1))
Edge cases: none
```

```
Test: the larger magnitude wins per axis
Given: R, with the stick rescaled to s = 0.5 to the right (raw from the inverted formula at cfg)
When:  (a) the stick alone; (b) the stick plus d-pad left
Then:  (a) x == s; (b) x == −1 (digital magnitude 1 > s)
Edge cases:
  - per axis: the stick on x and the d-pad on y compose to (s, ±1) before normalization, then normalize per story 004 only if the length is > 1
  - runs with NON_DEFAULT
```

```
Test: the d-pad wins a tie
Given: R, stick raw (1, 0) (rescaled 1)
When:  hold d-pad left
Then:  x == −1
Edge cases:
  - d-pad left + d-pad right + stick at 0.5 right gives x == 0.5 (recommended reading; flips to 0 under the alternative)
  - two pads with sticks 0.3 and −0.7 on x give −0.7
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_axis_arbitration_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-004-digital-move-magnitude.md`
  - `production/epics/input-system/story-005-radial-deadzone.md`
- Unlocks: `production/epics/input-system/story-018-menu-repeat-timing.md`

---

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin).*

- **Files**: `src/input/input_resolver.gd` (per-axis arbitration in `get_move_vector()`; `_analog_vector()` takes the larger stick across pads); `tests/unit/input/input_axis_arbitration_test.gd`
- **Tests**: 16 cases (8 x DEFAULT/NON_DEFAULT). Input dir 145/145; full suite 1266/1266, exit 0.
- **Deviations**: Implements the recommended reading (digital cancellation counts as magnitude 0, so a deflected stick wins); game-designer still to confirm.
