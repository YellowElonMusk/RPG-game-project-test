# Story 026: Noticing faces the leader, and sharp turns pause in a look-back pose on the old facing

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: A Noticing symbol's facing snaps to point at the leader; at a `pingpong` end or a `loop` vertex turning by more than 90°, the symbol pauses `turn_pause_s` in a look-back pose, holding its **old** facing (and therefore the old half-planes) until the pause ends, when the flip happens. A vertex turning 90° or less causes no pause, and a leader exactly on the half-plane boundary counts as in front.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure angle/timer logic inside `SymbolBrain`; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "the turn pause (old facing until the flip); facing snapped to the displayed facing with 45°+5° hysteresis and held while stopped" — source: ADR-0012 §5
- Required: "A symbol's logical facing is snapped to its displayed facing" — source: ADR-0012 §2

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-9g [L] (R5, facing and turns)** GIVEN Noticing, THEN the symbol's facing points at the leader (snapped to the displayed facing). GIVEN a `pingpong` end, and separately a `loop` vertex turning by more than 90°, THEN the symbol is stationary in its look-back pose from arrival to `turn_pause_s − dt` with the **old** facing deciding the half-planes, and its facing has flipped at `turn_pause_s + dt`. A `loop` vertex turning by 90° or less causes no pause. GIVEN the leader exactly on the half-plane boundary, THEN the front radius applies.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's Patrol row, Noticing row and the Facing clause:*

GDD rule 5, Patrol row: "At each `pingpong` end, and at each `loop` vertex
that turns by more than 90°, it pauses for `turn_pause_s` in a look-back pose
before its facing flips, so a player sneaking behind it gets a warning.
During the pause the **old** facing still decides the half-planes; the flip
happens at the pause's end." The Facing clause: "A leader exactly on the
dividing line (dot product 0) counts as in front."

- **Noticing facing**: step into Noticing and assert the symbol's logical facing (snapped to the displayed diagonal) points at the leader's position on that same frame.
- **Turn pause timing**: use the harness's timing rule (`dt` chosen so `turn_pause_s / dt` is not whole); assert the symbol is stationary with the **old** facing from arrival through `turn_pause_s − dt`, and has flipped to the new facing at `turn_pause_s + dt`. Test both a `pingpong` end and a `loop` vertex turning more than 90°.
- **No pause below the threshold**: a `loop` vertex turning exactly 90° or less must cause zero pause — the symbol continues through without stopping or changing its half-plane reference.
- **Boundary case**: with the leader exactly on the dividing line between front and rear half-planes (dot product of facing and leader-offset equals 0), the front radius (`symbol_chase_m`) must apply, not the rear one.
- `turn_pause_s` default 0.9 s, safe range 0.9–1.4 (Tuning Knobs) — use the formula value, never a literal, and re-run once with a non-default value per the harness rule.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 020: ordinary Patrol traversal with no pause (turns ≤ 90°).
- Story 027: the facing hysteresis that prevents flicker on an axis-aligned heading, a distinct mechanism from the turn-pause flip tested here.
- Story 021: the Noticing→Chasing timer itself (this story only tests the facing snap during Noticing, not the delay).

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_turn_pause_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_turn_pause_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-020-patrol-loop-and-pingpong-traversal.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-027-facing-hysteresis-holds-through-noise.md`
