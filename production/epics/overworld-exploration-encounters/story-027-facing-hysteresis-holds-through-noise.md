# Story 027: Facing hysteresis holds through directional noise and while stopped

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: A symbol's logical facing snaps to the displayed sprite facing (the four diagonals) with a 45°+5° hysteresis band: the facing changes only when the movement direction is more than 50° from the current diagonal, and a symbol that is not moving (turn pause, Noticing, contact pending, Stunned) keeps its last facing rather than reacting to noise.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure angle-comparison logic inside `SymbolBrain`; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "facing snapped to the displayed facing with 45°+5° hysteresis and held while stopped" — source: ADR-0012 §5
- Required: "A symbol's logical facing is its movement direction, **snapped to the displayed sprite facing**... The snap has hysteresis: the facing changes only when the movement direction is more than 45° + 5° from the current diagonal" — source: GDD rule 5

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-9i [L] (R5, facing hysteresis)** GIVEN a symbol moving exactly along a screen axis (between two diagonals), with ±1e-6 noise added to its direction each frame for 10 s, THEN its facing never changes. GIVEN a stopped symbol (turn pause, Noticing, contact pending, Stunned), THEN its facing never changes. The facing changes only when the direction is more than 50° from the current diagonal.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 5's Facing clause:*

GDD rule 5: "The snap has hysteresis: the facing changes only when the
movement direction is more than 45° + 5° from the current diagonal, and a
symbol that is not moving (turn pause, Noticing, contact pending, Stunned)
keeps its last facing. When a turn lands exactly between two diagonals, the
one nearer the previous facing wins; if still tied, the lower index (NE 0,
SE 1, SW 2, NW 3)."

- **Noise rejection**: drive the symbol's movement direction exactly along a screen axis (equidistant between two of the four displayed diagonals) with ±1e-6 jitter added every frame, for 10 s of simulated time at both `dt = 1/60 s` and `dt_max`; assert the displayed facing never flips even once. This directly tests the "nearer the previous facing wins" tie-break — jitter this small can never cross the 50° threshold, but it is exactly the kind of noise a naive nearest-diagonal recompute (with no hysteresis and no previous-facing tie-break) would flicker on.
- **Held while stopped**: for each of turn pause, Noticing, contact pending and Stunned, hold the symbol stationary and assert the stored facing is frozen at whatever it was on entry to that state, regardless of any (irrelevant, since not moving) direction vector.
- **Threshold boundary**: separately, drive a direction more than 50° from the current diagonal and confirm the facing *does* flip — proving the hysteresis band's edge is exactly 45° + 5°, not some looser approximation.
- This story is the symbol-facing analogue of story 009's follower-facing hysteresis, but the two use unrelated mechanisms (angular dead zone here vs. arc-length lookahead there) and must not share an implementation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: the turn-pause flip itself (old facing until the pause ends) — a timed event, not the ongoing hysteresis tested here.
- Story 009: follower facing (a different, arc-length-based mechanism).

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_facing_hysteresis_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_facing_hysteresis_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (full suite 726/726, 2026-10-29)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-026-facing-tracks-leader-with-turn-pause.md`
- Unlocks: None

---

## Completion Notes

**Implemented**: 2026-10-29
- `SymbolBrain.snap_facing(current, dir)` keeps `current` unless `dir` is more than 45 + `FACING_HYSTERESIS_DEG` (5) degrees off it. Otherwise it returns `nearest_facing(dir, current)`, where a tie goes to the diagonal nearer the previous one, then to the lower index. A zero `dir` keeps the facing. Only movement legs and the end of a turn pause update the facing, so Noticing, Stunned and the turn pause hold it.
- Tests: `tests/unit/overworld/symbol_brain_facing_hysteresis_test.gd` (7): +-1e-6 noise on all 4 screen axes for 10 s at 1/60 and `dt_max`, a moving patrol along a noisy x-axis polyline, the band edge at +-0.01 degrees for every diagonal, zero direction, Stunned, Noticing, turn pause.

**Deviations**:
- The 5-degree margin is a named rule constant in `SymbolBrain`, not an `OverworldConfig` field, because the GDD lists no Tuning Knob for it.
- "Contact pending" has no sub-state yet. TODO(overworld) for the contact story.
