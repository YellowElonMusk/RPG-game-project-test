# Story 024: hit_punch's offset formula is pixel-exact and never starts while another punch is running

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The `hit_punch` offset is a pure formula of elapsed time against duration `D` and peak amplitude `A_peak`, producing whole-pixel values that never change sign, never exceed `A_peak`, reach 0 from the first frame at or after `D`, and never overlap a still-running punch even under a latched replay.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is a pure, headless-testable formula, independent of the camera's `frustum_offset` plumbing (story 006) which merely consumes its output.

**Control Manifest Rules (this layer)**:
- Required: Battle camera: `frustum_offset` carries lens shift + hit-punch, computed in whole pixels — source: ADR-0005
- Forbidden: Never let a punch start while another's offset is still non-zero, even under a latched (`ff_mult`) replay — source: GDD `hit_punch` formula, AC-21

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-21 [L]** (P-04) **hit_punch**. The offset function, called directly, equals the formula exactly in whole pixels at 1080p and at 2160p. That includes the tie: `A_peak = 2` at `t = D/2` gives 1 px. In play, sampled at `dt = 1/60` with `D = 0.105` s so that no frame lands on a tie or on `D`:
  - the offset never changes sign and never exceeds `A_peak`;
  - it is 0 from the first frame at or after `D`;
  - it starts on the impact frame.

  Over a full replay latched at `ff_mult`, no punch starts while another is non-zero.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 and the GDD's `hit_punch` formula:*

- The offset function is pure: given `t` (elapsed since the punch started), `D` and `A_peak`, it returns a whole-pixel value with no dependency on the scene tree, testable headlessly at 1080p and 2160p directly.
- The tie case (`t = D/2`) must resolve consistently to 1 px for `A_peak = 2` — this is the half-away-from-zero-style rounding rule the sprite quad also uses (§2), applied here to the punch amplitude curve.
- "No punch starts while another is non-zero" is a latch-level guarantee that must hold even under `ff_mult`-latched replay speed, where beats (and their punches) land closer together in real time.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012 (`production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`): which beats trigger a punch at all, and amplitude selection
- Story 025 (`production/epics/sprite-camera-presentation/story-025-punch-displaces-the-id-pass-by-whole-pixels.md`): the capture-measured confirmation that the punch is a pure pixel shift on screen

---

## Files

- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/hit_punch_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/hit_punch_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-025-punch-displaces-the-id-pass-by-whole-pixels.md`
