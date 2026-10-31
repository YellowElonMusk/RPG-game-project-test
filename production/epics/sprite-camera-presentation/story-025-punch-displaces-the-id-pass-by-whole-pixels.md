# Story 025: A hit-punch displaces every near, far and set-element pixel by the same whole-pixel amount

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31) -- [C] `tools/capture/punch_shift_capture.gd` PASS (A_peak 5 up/down, 2 up: every near, far and set region moved exactly A_peak, 0 mismatched px); `tests/unit/presentation/punch_shift_check_test.gd` 5/5; full suite 1903/1903 exit 0; lead sign-off owed
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`, `TR-presentation-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Because the punch is a pure `frustum_offset` shift, every near actor, far actor and set element must be displaced in the capture tool's ID pass by exactly the same whole number of pixels, `A_peak`, in the punch direction, at a punch's peak versus a frame with none.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `[C]` clause, explicitly marked Pending until the capture tool exists (story 002). The ID pass is per-class override materials rendered on the same frame (§13).

**Control Manifest Rules (this layer)**:
- Required: The capture tool sets `SubViewport` MSAA, screen-space AA and the positional shadow atlas size explicitly — source: ADR-0005
- Forbidden: Never use a translation or rotation shake — a translation moves near and far depths by different amounts, which is exactly what this AC would catch as a failure — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-21b [C]** (P-09) (pure shift; Pending: capture tool) On a Battle capture at a punch's peak and one with no punch, the ID pass of every near actor, far actor and set element is displaced by the same whole number of pixels, `A_peak` in the punch direction.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 and §13:*

- Because `frustum_offset` shifts the whole camera's clip-space output rather than any individual object, a pure pixel shift of every depth (near actor, far actor, set element alike) is the direct, provable consequence of the architecture — this story's job is to prove it with the capture tool, not to implement new displacement logic.
- Uses the capture tool's ID pass (per-class override materials, same frame) to render two captures: one at a punch's peak amplitude, one with no punch, and diffs every tagged class's pixels for a uniform whole-pixel offset equal to `A_peak` in the punch direction.
- If the capture tool's glow-input hook (item 15) failed in story 001/002, that failure does not block this AC — the ID pass is a separate pass from the glow hook.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 024 (`production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`): the offset formula's own headless correctness

---

## Files

- `tools/capture/presentation_capture.gd`
- `src/presentation/diorama_stage.gd`
- `production/qa/evidence/punch-displaces-the-id-pass-by-whole-pixels/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: a retained screenshot/measurement in `production/qa/evidence/punch-displaces-the-id-pass-by-whole-pixels/` + sign-off in `production/qa/evidence/punch-displaces-the-id-pass-by-whole-pixels-evidence.md`

**Status**: [x] `production/qa/evidence/punch-displaces-the-id-pass-by-whole-pixels/` (id_none, id_big_up/down, id_normal_up, final_*, measurements.json, stamp.txt) + `production/qa/evidence/punch-displaces-the-id-pass-by-whole-pixels-evidence.md`; lead sign-off owed

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-002-capture-tool.md`, `production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`
- Unlocks: None
