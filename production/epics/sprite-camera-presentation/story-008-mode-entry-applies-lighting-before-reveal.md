# Story 008: Every mode entry applies its lighting profile fully before the transition reveals it

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `PresentationDirector` applies the entry profile at `blend_time = 0` on `mode_entered`, hidden behind the wipe, except on a same-mode row (Retry) where it rebinds but does not re-apply, because the Battle mode already set the Retry light during SWAP.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; relies on `ModeHost`'s `mode_entered` announcement (ADR-0002) firing at the end of SWAP, before the reveal.

**Control Manifest Rules (this layer)**:
- Required: `PresentationDirector` applies the entry profile at `blend_time = 0` on `mode_entered`, hidden behind the wipe; it skips the apply on a same-mode row (Retry) because the owning mode already set the light during SWAP — source: ADR-0005
- Required: `LightingProfile` and `PresentationConfig` are data (`.tres`). Every lighting/FOV/camera/texel/timing value comes from them, never literals — source: ADR-0005
- Forbidden: Never let a mode scene light itself with no Director — there must be one always-processing owner of the global uniforms — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-6 [I]** (P-06) GIVEN each Game State mode entry, THEN on the frame `mode_entered` is handled, while the transition still covers the screen, every lighting parameter its preset does **not** declare animated equals the target preset within 1e-4. Over the next 120 frames, with no blend requested, none of those parameters changes. Parameters declared animated (campfire flicker, ambient motion) stay inside their declared range on every frame.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3–§4:*

- On `mode_entered(to)`, which fires at the end of SWAP before the reveal, the Director takes the group's single `DioramaStage`, calls `stage.bind_profiles(resolver)`, and applies `profiles[stage.profile_id]` with `blend_time = 0`.
- It learns `from`/`to` from `transition_started(from, to)`: on a same-mode row (Battle → Battle for Retry) it rebinds but does **not** apply the entry profile, because the Battle mode already set the Retry light during SWAP.
- Every battle stage enters on `battle` (never a `boss_*` entry profile), so a first-encounter takeover always has a "from" light to blend out of.
- Parameters declared animated (campfire flicker, ambient motion) are exempt from the "unchanged" check and stay inside their declared range instead.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009 (`production/epics/sprite-camera-presentation/story-009-lighting-blend-completes-without-popping.md`): the `lighting_blend` formula's own timing behaviour
- Story 026 (`production/epics/sprite-camera-presentation/story-026-lighting-blend-formula-is-exact.md`): `lighting_blend` as a pure formula

---

## Files

- `src/presentation/presentation_director.gd`
- `src/presentation/diorama_stage.gd`
- `tests/integration/presentation/mode_entry_lighting_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/mode_entry_lighting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-003-actor-key-and-rim-lighting-only.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-009-lighting-blend-completes-without-popping.md`, `production/epics/sprite-camera-presentation/story-026-lighting-blend-formula-is-exact.md`
