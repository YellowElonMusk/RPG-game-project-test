# Story 048: Reduce Motion zeroes the punch and ambient set motion, and swaps in the still confetti

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-022`, `TR-presentation-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings (Reduce Motion)
**ADR Decision Summary**: The hit-punch honours Screen Shake and Reduce Motion (§6); ambient motion is driven by the `mode_time` global uniform (§7), and Reduce Motion must zero ambient set-motion parameters and swap the Victory confetti to a still variant, while leaving lighting blends, sprite animation and the follow camera unaffected.
**ADR Version**: ADR-0005 2026-10-22; ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's HIGH rendering risk through the `mode_time`-driven ambient shader uniforms this setting must zero. No new post-cutoff API beyond what §7 already establishes.

**Control Manifest Rules (this layer)**:
- Required: "World shaders (the sky card's clouds included) read `mode_time` only, never `TIME`" (Clocks and layering, ADR-0005 §7–§8, §11) — the ambient-motion parameters this setting zeroes are `mode_time`-driven shader uniforms, confirming this story touches no stray `TIME`-based animation.
- Required: "No consumer holds `SettingsService`. Each gets its narrow view" (Save/Load & Settings, ADR-0009 §7).
- Forbidden: "Never set the battle camera's `h_offset`/`v_offset`... the punch is `frustum_offset` only" (ADR-0005) — the punch-zeroing half of this AC must zero the `frustum_offset` contribution, never introduce a new camera property to suppress it.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-44 [L]** (P-06) (Reduce Motion) GIVEN Reduce Motion On, THEN the punch offset is 0, ambient set motion parameters are 0, and the Victory confetti is the still variant. Lighting blends, sprite animation and the follow camera behave exactly as with it Off.

---

## Implementation Notes

*Derived from ADR-0005 Decision §6 (punch), §7 (ambient `mode_time`) and the comfort-settings contract (TR-presentation-022):*

- **Punch**: with Reduce Motion On, the punch's `frustum_offset` contribution is 0 on every frame, regardless of elapsed `t` — this is the same zeroing outcome `story-045` tests for a *mid-punch setting change*; this story tests the *steady-state* case (the setting already On before any punch starts), which is a distinct assertion (no transition to verify, just "always 0").
- **Ambient set motion**: parameters driven by `mode_time` in the sky card's cloud scroll and any other authored ambient motion (§7) must read 0 for their motion-amplitude terms specifically — not stop advancing `mode_time` itself (which would also freeze lighting blends and sprite animation, violating this AC's explicit "lighting blends, sprite animation and the follow camera behave exactly as with it Off" clause). Reduce Motion zeroes *amplitudes*, never the clock.
- **Victory confetti**: a content-level swap to a still (non-animated) variant, selected by the same live Reduce Motion read — this is a data/asset selection, not a physics or particle-system change, and must apply live (no re-entry required), per the comfort-settings contract.
- **The "unaffected" clause is the trap this test must catch**: a naive implementation that gates ambient motion through the same code path as lighting blends or sprite frame-stepping could accidentally freeze one of those too — this story's test explicitly asserts lighting blend progress, sprite frame advancement and follow-camera position tracking are all identical with Reduce Motion On vs Off, holding everything else constant.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-045-setting-change-mid-punch.md`: the mid-punch transition case for Screen Shake/Reduce Motion (this story is the steady-state case).
- `story-029-flash-gate-books-transitions-at-landing-time.md`: Reduce Flashing (a separate comfort setting).
- `story-028-set-brightness-and-blur-match-lighting-states.md`: Reduce Blur (also separate).

---

## Files

- `src/presentation/sprite_projection.gd`
- `src/presentation/diorama_stage.gd`
- `tests/unit/presentation/reduce_motion_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/reduce_motion_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] `tests/unit/presentation/reduce_motion_test.gd` (4 cases) passes (2026-10-31). Amplitude helper + confetti id swap on `DioramaStage`; sky-card/foliage shaders and the still-confetti art do not exist yet, so nothing consumes them

---

## Dependencies

- Depends on: the settings service (ADR-0009, `src/save/settings_service.gd`, not yet built); the Victory confetti's still variant (art asset, not yet authored)
- Unlocks: None
