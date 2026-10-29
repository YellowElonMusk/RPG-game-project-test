# Story 068: Reduce Flashing halves the campfire flicker's swing

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings
**ADR Decision Summary**: ADR-0005 §3's Camp practicals (the campfire) carry a luminance flicker driven by `mode_time`; ADR-0009 §7–§8 delivers `reduce_flashing` live through the `FlashSettings` view, which this story's flicker computation reads to halve its swing, independent of the `FlashGate` request/refuse path used for discrete transitions.
**ADR Version**: ADR-0005 2026-10-22, ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API. This is a continuous per-frame luminance modulation (the flicker), distinct from `FlashGate`'s discrete transition-booking model (§12) — Reduce Flashing here scales an amplitude rather than refusing a booking.

**Control Manifest Rules (this layer)**:
- Required: World shaders (the sky card's clouds included) read `mode_time` only, never `TIME` (ADR-0005 §7) — the flicker is mode-time driven like every other ambient motion
- Required: No consumer holds `SettingsService` directly; `FlashSettings` is the narrow view (ADR-0009 §7)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-63 [L]** (P-06) (Reduce Flashing on flicker) GIVEN Camp with Reduce Flashing On, THEN the campfire flicker's luminance swing is half its swing with the setting Off, within 1e-4, on every frame.

---

## Implementation Notes

*Derived from ADR-0005 and ADR-0009 Implementation Guidelines:*

The campfire's flicker is a continuous luminance modulation on `mode_time` (§3, §7), not a `FlashGate`-booked transition; Reduce Flashing scales its swing amplitude by a fixed factor of one-half, read live from the `FlashSettings` view (ADR-0009 §7).
- The halving is a constant factor applied to the flicker's amplitude term, not a change to its frequency or mean luminance — the comparison is "swing On vs. swing Off", not the absolute luminance values.
- Because the setting is read live (ADR-0009 §7, `value_changed`), a change mid-flicker should take effect from the next frame's amplitude, consistent with how every other comfort setting applies (ADR-0005 §6 Screen Shake/Reduce Motion, story 056's speed settings).
- This is distinct from the campfire's declared `FlashSourceDecl` (if any) under `FlashGate` — the flicker's continuous swing and a discrete flash transition are two different mechanisms on the same light.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-059-flash-coverage-declared-for-every-source.md`: the campfire's `FlashGate` declaration, if it also has discrete transitions
- `story-060-composite-frame-flash-analysis.md`: composited flash-rate measurement across whole scripted sequences

---

## Files

- `src/presentation/diorama_stage.gd`
- `data/presentation/profiles/camp.tres`
- `tests/unit/presentation/reduce_flashing_flicker_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/reduce_flashing_flicker_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: the settings service (ADR-0009, not built)
- Unlocks: None
