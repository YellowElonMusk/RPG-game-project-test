# Story 068: The walk home runs after the boss Victory, through the liberated streets, to the café

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
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

- [x] **AC-27d [I] (R13, walk home)** GIVEN a boss Victory, THEN after the post-battle Dialogue the next transition is a map change to the overworld segment's dungeon-side EntryPoint with the liberated presentation; the segment's exit to the dungeon is disabled and shows the "FERMÉ POUR RESTRUCTURATION" tape; the current leg ends at the Town café CampSpot. A spy shows that chapter-end is called only from Yes in the "End the chapter here?" prompt at the café on the final step (B). Entering Town during step A advances the step to B. Pressing `cancel` and `menu` during the post-battle Dialogue and the fade, and Save → Continue during the free roam, each still lead to the segment load and the same café end. In the prompt, No has the default focus and No or `cancel` returns to the free roam.

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
- `tests/integration/overworld/walk_home_after_boss_victory_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/walk_home_after_boss_victory_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-066-region-liberation-presentation-override-on-load.md`, `production/epics/game-state-scene-flow/` (done)
- Unlocks: `production/epics/overworld-exploration-encounters/story-069-liberated-fields-and-dungeon-route-block.md`

## Completion Notes (2026-10-30)

- `WorldState.chapter_step` is new: saved, staged by the participant, and set to the opening step on New Game.
- A boss Victory that liberates the region queues the walk home. The boss's `post_battle_line` (a new `EncounterData` LocText field, added to the Content Data GDD) opens as a Dialogue on the reveal. Its close starts step A (`ChapterSteps.last_act_from`) and requests the map change to `last_act_entry_id` (the segment's `from_dungeon`). A request Game State refuses is retried every frame.
- Entering the next step's map advances the step, but only within the last act.
- On the final step, the region default camp opens the chapter-end prompt instead of "Rest here?": No is focused, and only Yes calls `_end_chapter()`.
- `_end_chapter()` emits `chapter_end_requested` and counts `chapter_end_calls`. What ending a chapter does is not designed, so GameRoot does not listen yet (TODO dialogue-quests).
- The dungeon exit tape is story 069's `MapExit.closed_when_flag`.
- Owed:
  - The post-battle line needs rule-18 narrative sign-off (AC-51). Done 2026-10-30: revised to fit 120 characters (`production/qa/evidence/signoff-overworld.md`).
  - The prompt's `accessibility_name` waits on the accessibility layer. The view shows the "End the chapter here?" text.
- `boss_stays_resolved_through_retreat_and_continue_test.gd` now closes the post-battle Dialogue. `content_data_loc_fields_test.gd` no longer lists EncounterData as text-free.
- Mutations checked: no walk home queued, no step advance, Yes focused by default, `chapter_step` not saved, and no tape each fail a test here.
