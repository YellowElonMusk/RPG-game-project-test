# Story 129: Symbols, followers and civilians never block or push each other; a touched symbol resumes from its contact point

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`, `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: ADR-0012's `SymbolBrain` never resolves collision against other actors (no physics engine); ADR-0005 fixes that followers are cosmetic trail sprites with their own depth sorting, not physical bodies either.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface — confirms the absence of any collision resolution between actor types, consistent with the "no physics engine" invariant already probed.

**Control Manifest Rules (this layer)**:
- Forbidden: "Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D" (control manifest, ADR-0012 §2, §3) — symbols/followers/civilians not colliding is a direct consequence of this ban, which this story asserts behaviourally.
- Required: "Symbol AI lives in the pure `SymbolBrain`... Static `start_on`" (control manifest, ADR-0012 §5) — the resume-point write belongs in `SymbolBrain`'s contact handling.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-57 [L] (R5, misc.)** Two symbols, a follower and a civilian occupying the same point never block or push one another. A symbol touched during Patrol stores its patrol position at contact as its resume point and resumes from it after a Fled battle.

---

## Implementation Notes

*Derived from GDD rule 5 ("Symbols and each other") and the Formulas' `path_dist`/contact definitions:*

- "Symbols and each other": symbols do not collide with each other, with followers, or with civilians (rule 5). Two symbols, a follower and a civilian may all occupy the same point with no push, no block, no stacking resolution.
- Contact resume point: "A symbol touched during Patrol stores its patrol position as its resume point" (rule 5, "Contact"). This happens specifically when contact occurs **during Patrol** (not Noticing or Chasing, where the resume point was already set earlier when the symbol left Patrol — see rule 5's `Returning` row: "the point on its patrol path where it left Patrol").
- After a Fled battle (`Stunned` → `Returning` → `Patrol`), the symbol must resume Patrol from that stored resume point, in the direction it was going, not from its pre-contact position if that differs.
- This is distinct from the Stunned push (Edge Cases: "If the flee push meets a wall..."), which moves the symbol after `on_thawed`; the resume point is a stored patrol-path position, independent of where the push leaves it physically — Returning walks it back to the resume point regardless.
- Test with a fixture where two symbols' patrol paths cross the same cell, plus a follower and a civilian stacked on it, and assert none of the four displace or block another.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Stunned push itself and its 4-connected stepping (Edge Cases, "If the flee push meets a wall...") — outside this writer's range.
- Follower trail formation and spacing (`follower_trail`, AC-4/AC-5a-c, outside this writer's range).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/symbol_brain.gd` (resume-point storage on Patrol contact; no collision resolution against other actors)
- `tests/unit/overworld/symbol_non_collision_and_resume_test.gd`
- `tests/unit/overworld/patrol_resume_point_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/symbol_non_collision_and_resume_test.gd` and `tests/unit/overworld/patrol_resume_point_test.gd` — must exist and pass.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-020-patrol-loop-and-pingpong-traversal.md` (AC-9a, Patrol sub-state), `story-033-returning-to-resume-point.md` (AC-10c, Returning sub-state)
- Unlocks: None

## Completion Notes (2026-10-30)

- Behaviour already existed (symbols move only on the walk grid; NPCs and followers never mark it; `on_contact()` stores the resume point). This story adds the evidence test.
- Two crossing patrols, run together, match each running alone on every frame, and they do overlap. An NPC (the civilian stand-in until civilians exist) and stacked followers leave the cell walkable and symbol-legal.
- A symbol touched mid-patrol, then Fled and pushed away, walks back to its contact point and resumes with the same next waypoint and direction.
- Mutation checked: not storing the resume point on contact fails a test here.
