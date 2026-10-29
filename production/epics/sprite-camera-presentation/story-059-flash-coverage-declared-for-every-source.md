# Story 059: Every flash-capable source is declared and classified

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §12's `FlashGate` requires every large-area luminance source to carry a `FlashSourceDecl` (class, clock, transitions, capped variant, exempt area), validated at boot including every scripted reserved sequence at 1×, the largest `battle_speed_mult` and the largest `ff_mult`.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; this is boot-time data validation over `FlashSourceDecl` resources. The validators run as part of ADR-0004's `register_record_validator` registration (ADR-0005 §9), already wired by the Boot story — this story adds the flash-specific rules and the declarations for every named source.

**Control Manifest Rules (this layer)**:
- Required: Every large-area luminance source must have a `FlashSourceDecl` and book through `FlashGate.request()`/`book_reserved()`; a discarded source's booking must be cancelled via `FlashGate.cancel()` (ADR-0005 §12)
- Required: Every flash source declaration is validated at boot, including every scripted reserved sequence at 1×, the largest `battle_speed_mult`, and the largest `ff_mult` (ADR-0005 §9, §12)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-55 [L]** (P-05) (flash coverage) Every flash-capable source in the shipped data is declared gated, reserved, exempt-by-area or exempt-by-swing, with its transitions. The sources are:
  - the victory burst and the boss flood;
  - each attack and comedy VFX;
  - Game State's retry flash, wipes and fades;
  - the Menu backdrop's open and close, the Defeat card's stamp, and the results screen's opening.

  A fixture source declared exempt whose data exceeds its exemption fails boot validation. A gated source refused by the gate plays its capped variant, whose declared frames have no general transition and no red transition, or cover less than `flash_area_min`. Every source's transitions are declared on a named clock (mode, replay or real). A dusk-flood starfield is declared exempt-by-area, and its summed area is below `flash_area_min`.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

Every listed source gets a `FlashSourceDecl` resource under `data/presentation/flash_sources/` naming its class (gated/reserved/area-exempt/swing-exempt), its clock (`MODE`/`REPLAY`/`REAL`), its transitions and, for gated sources, a capped variant whose declared frames hold no general or red transition, or whose area is below `flash_area_min` (§12).
- The boss flood and victory burst are typically `reserved` (always booked, §12 `book_reserved`); attack/comedy VFX are `gated` and request through `FlashGate.request()`.
- Game State's retry flash, wipes and fades, and the Menu backdrop open/close, Defeat stamp and results opening are declared alongside the presentation sources — ADR-0008 §8 already names the four UI flash IDs (`ui_menu_backdrop_open`, `ui_menu_backdrop_close`, `ui_defeat_stamp`, `ui_results_open`); this story adds their `FlashSourceDecl`s.
- The dusk-flood starfield is `exempt-by-area` with its summed area recorded and checked against `flash_area_min` at boot.
- Boot validation (§9) must exercise every reserved sequence at 1×, at the largest `battle_speed_mult`, and at the largest `ff_mult`, since a reserved sequence's declared frames are a worst-case bound across every speed it can run at.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-060-composite-frame-flash-analysis.md`: measures the *composited* frame-rate limit (`flash_rate_max`) against these declarations, rather than validating the declarations themselves
- `story-068-reduce-flashing-halves-campfire-flicker.md`: the Reduce Flashing comfort setting's effect on one specific source's swing

---

## Files

- `src/presentation/flash_gate.gd`
- `data/presentation/flash_sources/`
- `tests/unit/presentation/flash_coverage_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/flash_coverage_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/sprite-camera-presentation/story-060-composite-frame-flash-analysis.md` (needs these declarations to exist before it can analyse composited sequences)
