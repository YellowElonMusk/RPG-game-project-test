# Story 045: a comfort-setting change mid-punch applies on the very next frame

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-007`, `TR-presentation-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings (Screen Shake, Reduce Motion)
**ADR Decision Summary**: The hit-punch adds a whole-pixel offset to `frustum_offset`, scaled with window height, honouring Screen Shake and Reduce Motion; the six comfort settings must be read from the settings service and applied live, never requiring a restart or re-entry to take effect.
**ADR Version**: ADR-0005 2026-10-22; ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's HIGH rendering risk through the `frustum_offset` punch mechanism (§6, probed pixel-exact). The settings-live-update path itself (ADR-0009 §7, `value_changed` signal plus the debounced write) introduces no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "**Hit-punch.** The punch adds `(px_x · h_near / H, −px_y · h_near / H)` to `frustum_offset`... With these signs the image moves by `(−px_x, −px_y)` on screen" (Cameras, ADR-0005 §6).
- Required: "No consumer holds `SettingsService`. Each gets its narrow view... `SettingsService` imports no Presentation or Feature type" (Save/Load & Settings, ADR-0009 §7).
- Forbidden: "Never set the battle camera's `h_offset`/`v_offset` (they stay 0), and never use a translation or rotation shake — a translation moves near and far depths by different amounts; the punch is `frustum_offset` only" (ADR-0005).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-41 [L]** (P-04) (setting change mid-punch) GIVEN a running punch, WHEN Screen Shake changes to Off (or Reduce Motion turns On), THEN the next frame's offset is 0. WHEN it changes to Reduced, THEN the next frame's offset uses the new `A_peak` at the unchanged elapsed `t`.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 (Cameras — Hit-punch) and the comfort-settings TR-presentation-022 contract:*

- The punch's offset is a pure function of elapsed time `t` and an amplitude `A_peak` (presumably a decay curve against `t`, scaled by `A_peak`) — this story's test freezes `t` at a running value, flips the setting, and asserts the **very next frame's** computed offset reflects the new setting at the **same, unchanged `t`** (Off/Reduce Motion On → 0; Reduced → the new `A_peak` at that `t`), never a frame of transition or a restart of `t` to 0.
- "Off" and "Reduce Motion turning On" both force the offset to exactly 0 — this story's test must check both settings independently reach the same zeroed result, not assume testing one covers the other.
- This settings value reaches the punch computation through `PresentationSettings`, the narrow view ADR-0009 §7 builds in the composition root — this story's production code must read the live value through that view (or an injected stub matching its shape in the test), never hold `SettingsService` directly.
- Because the punch only ever modifies `frustum_offset` (never `h_offset`/`v_offset`, never a translation/rotation shake), "the next frame's offset" is unambiguous: it is the exact `frustum_offset` contribution for that frame, independent of the lens-shift term, which this test isolates by holding the lens-shift component fixed and varying only the punch term.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-048-reduce-motion-zeroes-ambient-motion.md`: Reduce Motion's effect on ambient set motion and the Victory confetti (this story is punch-only).
- `story-050-camera-holds-every-slot-in-view-at-every-aspect.md`: the lens-shift/aspect side of `frustum_offset` (unrelated to the punch amplitude).
- Building `PresentationSettings`/`SettingsService` itself (ADR-0009, not yet built — this story depends on it, does not implement it).

---

## Files

- `src/presentation/sprite_projection.gd`
- `tests/unit/presentation/punch_setting_change_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/punch_setting_change_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] `tests/unit/presentation/punch_setting_change_test.gd` (6 cases) passes -- behaviour already in `HitPunch.current_offset_px` (live `A_peak`); test added (2026-10-31)

---

## Dependencies

- Depends on: the settings service (ADR-0009, `src/save/settings_service.gd`, not yet built); `story-001-windowed-engine-spike.md` (settles the punch's pixel-to-`frustum_offset` mapping)
- Unlocks: None
