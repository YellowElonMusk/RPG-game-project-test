# Story 100: Swept contact fires at every approach angle and lateral offset, and never lets a frame skip through a wall

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: Contact is a swept-circle test over the frame's displacement (`min over t of |(c_L0 − c_S0) + t·(Δ_L − Δ_S)| ≤ 2·body_radius`), never a physics query, and `frame_step_safety` (I11, `walk_speed · dt_max < cell_m`) guarantees no frame carries the leader through a one-cell wall.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure vector math (`t* = clamp(−(a·b)/|b|², 0, 1)`), no physics query of any kind — the control manifest's physics ban applies to the whole Overworld, and this test is the proof that the swept math replaces it without a separate speed limit.

**Control Manifest Rules (this layer)**:
- Required: "**Per-frame order** (Exploring): move the leader → check map exits … → step symbols in marker order → swept contact (eligibility read after the steps) → interaction requests" — source: ADR-0012 §5
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-40 [L] (Edge Cases, swept contact)** GIVEN a 0.25 s frame (injected `dt`), THEN movement and every timer advance by exactly `dt_max`. Over a fixture set of approach angles 0°–90° in 15° steps, lateral offsets 0 to 2·`body_radius` and both bodies at full speed, every pair whose closest approach is ≤ 2·`body_radius` produces contact, and no other pair does. GIVEN zero relative displacement (`|b|² < 1e-8`), THEN contact equals `|a| ≤ 2·body_radius` with no division. A leader at `walk_speed` never crosses a 1-cell wall.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD Formulas ("frame_step_safety … and swept contact"):*

- Inject `dt = 0.25` s; assert movement and every timer advance by exactly `dt_max`, never the raw 0.25 s (`frame_step_safety`'s clamp).
- Fixture matrix: approach angles 0°–90° in 15° steps × lateral offsets 0 to 2·`body_radius`, both bodies moving at full speed for the frame. For each pair, compute `t* = clamp(−(a·b)/|b|², 0, 1)` with `a = c_L0 − c_S0`, `b = Δ_L − Δ_S`; assert contact fires exactly when the closest approach over `t ∈ [0,1]` is `≤ 2·body_radius`, and never otherwise.
- Zero-relative-displacement case (`|b|² < 1e-8`, e.g. a Noticing symbol and a motionless leader): assert contact equals `|a| ≤ 2·body_radius`, computed with no division (the `|b|²` branch must be taken, not a near-zero divide).
- Separately assert `walk_speed · dt_max < cell_m` (I11) holds and that a leader moving at `walk_speed` for one frame never ends up on the far side of a one-cell wall.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The give-up timing that consumes this contact test's result (story 101).
- `path_dist`'s own upper-bound proof (story 102).

---

## Files

- `src/overworld/ground_mover.gd`
- `tests/unit/overworld/swept_contact_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/swept_contact_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-098-config-invariants-i1-i18.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-101-symbol-speeds-escape-timing.md`
