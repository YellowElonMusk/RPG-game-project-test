# Story 068: The walk home runs after the boss Victory, through the liberated streets, to the café

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-013`, `TR-overworld-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: After the boss's post-battle Dialogue, `OverworldMode` advances `chapter_step` to the last act's step A and requests `OVERWORLD` to the segment's dungeon-side EntryPoint, with the dungeon exit taped off; entering Town advances to step B, and only a Yes at the café's P15 prompt ends the chapter.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `process_priority` sorts all nodes globally (probed, 4.7.2) — relevant to this story only insofar as the chapter-step advance must happen on the correct tick relative to `mode_entered`/`transition_finished`; risk otherwise follows ADR-0002's row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: Map change swaps to a fresh instance: it detaches the old mode, adds the new one, and frees the old only on success; all four signals fire with `from == to == OVERWORLD` — source: ADR-0012 §4, ADR-0002 §2
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld load: one single-pass bake plus one component-labelling pass, inside the fade — source: ADR-0012 Performance (Load Time)

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-27d [I] (R13, walk home)** GIVEN a boss Victory, THEN after the post-battle Dialogue the next transition is a map change to the overworld segment's dungeon-side EntryPoint with the liberated presentation; the segment's exit to the dungeon is disabled and shows the "FERMÉ POUR RESTRUCTURATION" tape; the current leg ends at the Town café CampSpot. A spy shows that chapter-end is called only from Yes in the "End the chapter here?" prompt at the café on the final step (B). Entering Town during step A advances the step to B. Pressing `cancel` and `menu` during the post-battle Dialogue and the fade, and Save → Continue during the free roam, each still lead to the segment load and the same café end. In the prompt, No has the default focus and No or `cancel` returns to the free roam.

---

## Implementation Notes

*Derived from GDD rule 13 ("The walk home") and ADR-0012 §4 ("Region end"):*

- After the boss's post-battle story Dialogue, `OverworldMode` advances `world_state.chapter_step` to the last act's first step (A) and requests `OVERWORLD` with a `MapEntryPayload` to the overworld segment's dungeon-side EntryPoint.
- That map loads liberated (story-066); the segment's exit to the dungeon is disabled through `set_blocked` with the in-world "FERMÉ POUR RESTRUCTURATION" tape blocker (no crowd, guardrail 6), so the dungeon and boss chamber cannot be re-entered.
- Entering Town advances `chapter_step` from A to B. The leg's end is the Town café CampSpot.
- Chapter-end fires only from **Yes** in the café's P15 "End the chapter here?" prompt on step B — **No** is focused by default, with its own verb and `accessibility_name` ("End chapter"), never the camp's "Rest"; No or `cancel` returns to free roam.
- Integration-test robustness against the real Game State: `cancel`/`menu` presses during the post-battle Dialogue and the fade, and a Save → Continue during the free roam, must each still resolve to the same segment load and the same café end.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-066-region-liberation-presentation-override-on-load: the liberated presentation itself (AC-27b)
- story-069-liberated-fields-and-dungeon-route-block: the data-level route-block proof (AC-27e)

---

## Files

- `src/overworld/overworld_mode.gd` (chapter-step advance, walk-home sequencing, café P15 prompt wiring)
- `src/overworld/world_state.gd` (`chapter_step`)
- `tests/integration/overworld/walk_home_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/walk_home_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-066-region-liberation-presentation-override-on-load.md`, `production/epics/game-state-scene-flow/` (done)
- Unlocks: `production/epics/overworld-exploration-encounters/story-069-liberated-fields-and-dungeon-route-block.md`
