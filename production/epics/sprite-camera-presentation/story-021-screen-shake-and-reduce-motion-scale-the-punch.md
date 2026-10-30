# Story 021: Screen Shake and Reduce Motion settings zero or halve the hit-punch offset

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`, `TR-presentation-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation (primary), ADR-0009: Save/Load & Settings (comfort-setting delivery)
**ADR Decision Summary**: The hit-punch amplitude is read live from the comfort settings: Screen Shake Off, or Reduce Motion On at any Screen Shake setting, forces the offset to 0; Reduced halves `A_peak` (floored, minimum 1 when `A_full > 0`) at the same duration. The settings themselves arrive through ADR-0009's narrow `PresentationSettings` view, never a held `SettingsService` reference.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0005's camera risk is HIGH; ADR-0009's settings-delivery risk is LOW–MEDIUM. The settings service itself is not yet built (TR-presentation-022 is explicitly **partial** pending it) — named as a dependency, not a blocker.

**Control Manifest Rules (this layer)**:
- Required: No consumer holds `SettingsService`. Each gets its narrow view (`UiSettings`, `FlashSettings`, `PresentationSettings`); the Battle mode gets `PresentationSettings` through `pre_setup` — source: ADR-0009 §7
- Forbidden: Never set the battle camera's `h_offset`/`v_offset`, and never use a translation or rotation shake — the punch is `frustum_offset` only — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-18 [L]** (P-04) GIVEN Screen Shake Off, or Reduce Motion On at any Screen Shake setting, THEN the punch offset is always 0. GIVEN Reduced, THEN `A_peak = max(1, floor(A_full / 2))` whenever `A_full > 0`, with the same duration; at 720p with `A_beat = 2` it is 1, not 0.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 and ADR-0009 §7:*

- The punch amplitude calculation reads `A_full` from `PresentationConfig`/the beat plan as today, then applies the comfort-setting scaling before writing to `frustum_offset`: Off or Reduce Motion On → 0; Reduced → `max(1, floor(A_full / 2))`; Full → `A_full` unchanged.
- The Battle mode receives `PresentationSettings` as `var presentation_settings` through `pre_setup` (ADR-0009 §7) — presentation code must read the setting through that narrow view, never hold or query `SettingsService` directly.
- Duration is unaffected by Screen Shake/Reduce Motion; only amplitude scales.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012 (`production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`): when a punch fires
- Story 024 (`production/epics/sprite-camera-presentation/story-024-hit-punch-formula-is-pixel-exact.md`): the unscaled `hit_punch` formula itself

---

## Files

- `src/presentation/presentation_settings.gd`
- `src/presentation/hit_punch.gd`
- `tests/unit/presentation/hit_punch_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/hit_punch_test.gd` — must exist and pass

**Status**: [x] `tests/unit/presentation/hit_punch_test.gd` created and passing (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-012-one-hit-punch-per-beat-on-impact.md`, the settings service (ADR-0009, not yet built)
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30. `PresentationSettings` (`src/presentation/presentation_settings.gd`, the ADR-0009 §7 narrow view: `screen_shake` Off/Reduced/Full, `reduce_motion`) is injected into `HitPunch` and read live every frame. Off or Reduce Motion On -> 0; Reduced -> `max(1, floor(A_full/2))` when `A_full > 0`; duration unchanged. Tests: every Off/Reduce-Motion combination stays 0 at 720-2160p, Reduced peak at four heights, 720p A_beat=2 -> 1, same running frames under Reduced, and a mid-punch settings change applying next frame with t unchanged. **Deviation**: no SettingsService exists, so `src/boot/settings_views.gd` was not created; the caller injects the values. TODO for the ADR-0009 epic: fill the view from the service and pass it via the Battle mode's `pre_setup`.
