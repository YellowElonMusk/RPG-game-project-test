# Story 011: probe() finds the nearest eligible target with a fixed tie order

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `probe()` is one query that finds the nearest eligible `Interactable`, `NpcSpawn`, `CampSpot` or `confirm`-started Static symbol within `interact_reach_m` of the probe point (`facing · body_radius` ahead of the leader's centre), with a fixed tie order (NPC, CampSpot, Static symbol, Interactable) when two targets are exactly equidistant.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure distance comparison over ground-plane `Vector2`s; no engine API involved.

**Control Manifest Rules (this layer)**:
- Required: "Interaction is one `probe()` (nearest eligible target; ties NPC → CampSpot → Static symbol → Interactable) that drives both the prompt and `confirm`" — source: ADR-0012 §6, GDD rule 3 / AC-7a
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-7a [L] (R3)** GIVEN an NPC, a CampSpot and an Interactable within `interact_reach_m` of the probe point, THEN `confirm` targets the one nearest the probe point. On an exact tie the order is NPC, CampSpot, `confirm`-started Static symbol, Interactable (the fixture includes one of each). GIVEN an unresolved story encounter, THEN its boom checkpoint is never returned. GIVEN a target within reach of the leader's centre but not of the probe point, THEN it is not targeted.

---

## Implementation Notes

*Derived from ADR-0012 §6 and GDD rule 3:*

GDD rule 3 fixes the probe point as "`facing · body_radius` ahead of the
leader's centre" — not the leader's centre itself — which is exactly what the
AC's third clause tests: a target in reach of the centre but not of the
(offset) probe point must be rejected.

- Build a fixture with one of each target kind (NPC, CampSpot, Static symbol started by `confirm`, Interactable) plus an unresolved story-encounter Static symbol's own linked checkpoint, all within `interact_reach_m` of the probe point.
- Distance comparison is to the probe point, not the leader's centre; the nearest wins outright, and only an exact tie falls through to the fixed order NPC → CampSpot → Static symbol → Interactable.
- "While the story encounter is unresolved, its own boom checkpoint is **not** a `probe()` target, so the fight always starts through the Static symbol" (GDD rule 3) — this is a hard exclusion, not a low-priority tie entry; test it as a target that must never be returned regardless of distance.
- The eligibility filter itself (open checkpoints, spent gags, etc.) is story 016's scope — this story's fixture uses only eligible targets so the tie-order and reach logic can be isolated.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: the empty-reach case (nothing in range).
- Story 013: lockouts during transitions/overlays.
- Story 016: per-kind eligibility rules (open checkpoints, spent gags, liberated markers).

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/probe_tie_order_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/probe_tie_order_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-004-wall-slide-and-corner-assist.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-012-confirm-does-nothing-with-no-target.md`, `production/epics/overworld-exploration-encounters/story-013-probe-blocked-during-transition-or-overlay.md`, `production/epics/overworld-exploration-encounters/story-015-interact-prompt-follows-probe-result.md`, `production/epics/overworld-exploration-encounters/story-016-interactable-eligibility-rules.md`
