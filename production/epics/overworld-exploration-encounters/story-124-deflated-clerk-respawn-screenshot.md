# Story 124: A Clerk respawned onto a liberated street shows the deflated variant

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: ADR-0012 fixes that region liberation deactivates every symbol while a respawned Clerk still carries a visual variant; ADR-0005 owns the upright-card sprite rendering this screenshot captures.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface — a sprite-variant capture using the already-probed `CharacterSprite`/presentation pipeline.

**Control Manifest Rules (this layer)**:
- Required: none directly (a visual-variant check, not a coded rule).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-51b [VF] (R9)** A retained screenshot of a Clerk respawned onto a liberated street, showing the deflated variant.

---

## Implementation Notes

*Derived from GDD rule 9 (Local liberation, "Permanence") and the Minimal MVP animation set:*

- A liberated marker stays liberated when its Clerk respawns, and when a later stage raise reactivates its area; the Clerk itself still respawns per its `respawn` policy (rule 9 "Permanence").
- A Clerk respawned onto a liberated street uses a **deflated** look — a sheepish pose, no clipboard flourish — with **unchanged behaviour** (rule 5's "The deflated variant changes the look only, never this behaviour").
- The animation set names this as its own patrol variant: "a deflated patrol variant for a Clerk respawned onto a liberated street (sheepish pose, no clipboard flourish; may reuse patrol frames with a different prop)."
- Setup: liberate a street's marker, let its symbol's `respawn` policy bring the Clerk back, and capture it mid-patrol on that liberated street.
- This is independent of whole-region liberation (rule 17's presentation override): the street can be locally liberated without the whole region being liberated yet.
- Retain the screenshot in `production/qa/evidence/` with the art-director sign-off in `production/qa/evidence/signoff-overworld.md` (test plan O-10).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Region-wide liberation and the liberated presentation override (rule 17) — out of this writer's range (AC-27 series).
- The respawn policy's timing/conditions themselves — covered by the local liberation stories earlier in the epic (outside this writer's range).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No new source files — captures the existing deflated-variant sprite once a Clerk respawns onto a liberated street.
- `production/qa/evidence/` (retained screenshot)
- `production/qa/evidence/signoff-overworld.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: a retained screenshot in `production/qa/evidence/` plus sign-off in `production/qa/evidence/signoff-overworld.md`. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-065-stage-visual-capture-saturation-and-contrast.md` (AC-27, stage visuals capture setup), local liberation and Clerk respawn behaviour (outside this writer's range)
- Unlocks: None
