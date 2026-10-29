# Story 005: Followers never collide, trigger exits or trigger interactions

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-006` (contact is the leader's alone); best-matching — no TR line names followers directly, since the GDD states this settles a point ADR-0012 left open (see below)
**Requirement note**: none of TR-overworld-001..019 names followers explicitly; the closest TRs are TR-overworld-006 (leader-symbol contact), TR-overworld-012 (map exits) and TR-overworld-015 (`probe()`), each of which is implicitly leader-only. Flagging this as a gap for `/architecture-review` to consider a dedicated TR line.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: Only the leader has a position in logic; followers are cosmetic `CharacterSprite`s with no collision and no logic. The GDD states this explicitly: "This serves Pillar 3... It settles the point ADR-0012 left open."
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No physics or collision API is touched — that is the point of the test. Followers are visual-only `CharacterSprite`s.

**Control Manifest Rules (this layer)**:
- Required: "Per-frame order: leader → exits (enter-edge only) → symbols in marker order → swept contact (eligibility after steps) → interaction" — source: ADR-0012 §5 (only the leader participates in any of these checks)
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" — source: ADR-0012 §2, §3

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-3 [L] (R2)** GIVEN a symbol, an exit and an interactable that overlap a follower's position but not the leader's circle, THEN no contact, exit or interaction fires.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and GDD rule 2:*

GDD rule 2 ("Party on the map: leader plus followers") is unambiguous: "Only
the leader has a position in logic. Only the leader collides, triggers
encounters, probes interactions and crosses exits... Followers have no
collision and no logic, and nothing can touch them." This story proves the
negative: placing every trigger type directly on top of a follower's rendered
position must produce zero effect.

- Build a fixture with a symbol, a `MapExit` rectangle and an `Interactable`, each positioned to overlap a follower's current trail position but clear of the leader's `body_radius` circle.
- Step the frame and assert: no `start_encounter` call, no exit request, and `probe()` returns null (or whatever `probe()` would return absent the follower overlap) — i.e. the per-frame order (ADR-0012 §5: leader → exits → symbols → contact → interaction) only ever evaluates the leader's position.
- Followers are rendering-layer `CharacterSprite`s only; this story's test never needs to instantiate one — it only needs the follower's logical position (from the trail formula, story 006) to place the triggers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the follower-trail spacing formula itself.
- Story 004: leader collision against walls.
- Story 010: follower save/load behaviour.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/follower_no_collision_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/follower_no_collision_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-004-wall-slide-and-corner-assist.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-006-follower-trail-spacing-formula.md`, `production/epics/overworld-exploration-encounters/story-010-followers-not-saved-rebuilt-from-roster.md`
