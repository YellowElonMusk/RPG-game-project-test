# Story 053: The Defeat spotlight centres on the party's formation

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-004`, `TR-presentation-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §4's `PresentationDirector` applies the `defeat` `LightingProfile` on `mode_entered`/the Defeat blend; §3's light rig (`KeyLight`, rim) is what every party actor is lit and rimmed by, so the Defeat spotlight must reuse exactly those per-actor key/rim strengths regardless of party size.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new post-cutoff API is used; this is a data/placement computation (the spotlight's ground-plane centre) layered on the existing `DioramaStage` light rig and `request_profile`/tween blend path (§3).

**Control Manifest Rules (this layer)**:
- Required: `LightingProfile` and `PresentationConfig` are data (`.tres`); every lighting value comes from them, never literals (ADR-0005 §5)
- Required: Without a `clock`, a profile blends with a tween on itself, which freezes under the Menu with everything else in the mode (ADR-0005 §3) — Defeat uses this path
- Guardrail: Actor key/rim strengths never change between Battle and Defeat beyond what the lighting blend itself produces

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-49 [L]** (P-06) (Defeat spotlight) GIVEN Defeat with party rows of 1, 2, 3 and 4 members, THEN the spotlight's ground-plane centre equals the party row's formation centre within 1e-4 m, and every party actor's key and rim strengths equal their Battle values.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

The Defeat profile's spotlight is a `KeyLight`/rim configuration aimed at the party formation's own centre, not a fixed point in the stage (§3, §5). The formation centre is the mean ground-plane position of the living party row for the row size in play (1–4 members); this story computes that centre and feeds it into the same light-rig placement the Battle profile already uses, so key and rim strengths read identically between Battle and Defeat.
- `DioramaStage` (or a pure helper beside `SpriteProjection`) computes the ground-plane centre from the party row's actor anchors, for 1, 2, 3 and 4 members.
- The Defeat blend uses the tween path (no `clock`), per §3, and freezes under the Menu like every other mode-time-driven blend.
- Key and rim strengths are read from the same `LightingProfile` fields the Battle profile uses — this story does not introduce new knobs, only the centring computation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Victory profile and its own blend (a separate acceptance criterion, not in this batch)
- The Defeat Prompt's menu-guard behaviour (`story-058-menu-input-guard.md`)

---

## Files

- `src/presentation/diorama_stage.gd`
- `data/presentation/profiles/defeat.tres`
- `tests/unit/presentation/defeat_spotlight_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/defeat_spotlight_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: None
