# Story 013: A punch requested during a boss-takeover blend or hold is dropped, never deferred

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: A punch requested directly during a boss-takeover blend or its hold is dropped outright — not queued, not replayed later — because the replay never releases a beat before the takeover ends.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is a pure gating rule on `DioramaStage.set_punch_offset_px`.

**Control Manifest Rules (this layer)**:
- Required: Battle camera: `frustum_offset` carries lens shift + hit-punch; the punch is the only per-frame change on the battle camera — source: ADR-0005
- Forbidden: Never defer a dropped punch — a punch requested during a boss-takeover blend or hold plays neither then nor later — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-11 [L]** (P-04) GIVEN a punch requested directly (bypassing the replay, which never releases a beat before the takeover ends, AC-45) during a boss-takeover blend or its hold, THEN it is dropped: no punch plays, then or later, and nothing is deferred.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3 and §6:*

- The boss-takeover blend and its hold are driven by the Battle mode's `clock` `Callable` into `stage.request_profile()`/`apply_profile()` (ADR-0006 §5 step 3); while that clock is active, a punch request must be rejected with no side effect, not queued.
- "Dropped" means the request leaves no trace: no later frame plays it, and no counter or buffer holds it for replay once the takeover ends.
- In practice this state never arises through the normal replay path (AC-45: the replay never releases a beat before the takeover ends) — this test exercises the direct, bypassing path explicitly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012 (`production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`): normal per-beat punch gating outside a takeover

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

**Status**: [x] `tests/unit/presentation/hit_punch_test.gd` (33 cases, 4 new for AC-11) passes (2026-10-31). Battle mode must bind `punch.takeover_active = stage.is_takeover_active` and set `stage.takeover_hold_active` over `boss_hold`

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`
- Unlocks: None
