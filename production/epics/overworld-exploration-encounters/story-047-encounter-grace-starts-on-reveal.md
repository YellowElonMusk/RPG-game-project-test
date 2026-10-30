# Story 047: Encounter grace starts on transition_finished, never on_thawed

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (`transition_finished` signal)
**ADR Decision Summary**: Step 2 of the thaw, on `transition_finished` once the scene is revealed, starts `encounter_grace_s`; Victory, Fled, any map load and a redirect all start grace the same way.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `transition_finished` is a foundational `GameStateMachine` signal (ADR-0002 Key Interfaces); HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: Two-step thaw — grace starts on `transition_finished`, step 2, never in `on_thawed` — ADR-0012 §5
- Forbidden: Never start grace before the reveal; never skip grace on a map load or redirect
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-20a [L] (R7)** GIVEN Victory, Fled, any map load or a redirect, THEN grace starts on `transition_finished`, not on `on_thawed`. An overlapping eligible symbol starts no encounter at `encounter_grace_s − dt` after that, and does start one at `encounter_grace_s + dt`.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 7 ("Step 2, on transition_finished"):*

- Drive all four triggers in separate fixtures — Victory, Fled, a plain map load, and a checkpoint redirect — and assert grace's start timestamp is pinned to `transition_finished`, never to the earlier `on_thawed` call (where one exists; a map load and a redirect have no `on_thawed` at all, which the fixture should reflect rather than paper over).
- Overlap an eligible (Patrol) symbol with the leader through the grace window; apply the GDD timing rule: no encounter at `encounter_grace_s − dt` after `transition_finished`, and an encounter **does** start at `encounter_grace_s + dt`.
- This confirms invariant I3 holds operationally: `(encounter_grace_s − t_react) · (walk_speed − v_chase) ≥ 2·body_radius` exists precisely so a player who reacts at `t_react` can clear a symbol before grace ends — the fixture does not need to assert I3 itself (that is `OverworldConfig.validate()`'s job), only that grace's timing matches the formula it depends on.

---

## Out of Scope

- `story-048-timers-freeze-under-overlays.md`: what happens to grace while an overlay or transition is running.
- `story-042-two-symbols-contact-tiebreak.md`: the losing symbol's switch to Returning when grace starts.

---

## Files

- `src/overworld/overworld_mode.gd`
- `tests/unit/overworld/overworld_mode_encounter_grace_timing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_encounter_grace_timing_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (full suite 824/824, 2026-10-29)

---

## Dependencies

- Depends on: `story-043-victory-respawn-policy.md`, `story-044-fled-symbol-stun-and-push.md`
- Unlocks: `story-048-timers-freeze-under-overlays.md`, `story-049-thaw-preserves-mid-chase-snapshot.md`

---

## Completion Notes

**Completed**: 2026-10-29 (implemented, awaiting /story-done)
- `grace_active` is now a property over `_grace_left`, started only in `_on_transition_finished(OVERWORLD)` (thaw, map load and redirect alike), ticked on ow_dt at the start of `step_frame`. `pending_thaw` set in `on_thawed`, cleared there. `grace_starts` diagnostic.
- Test: `tests/unit/overworld/overworld_mode_encounter_grace_timing_test.gd` (5 cases).
- Status synced 2026-10-30 from commit 523dc33.
