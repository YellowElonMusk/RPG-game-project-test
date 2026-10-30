# Story 092: Liberation flags, on-screen removal, Dialogue and the stage effect apply in a fixed order

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-010`, `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (the `on_thawed` / `transition_finished` two-step order)
**ADR Decision Summary**: A Victory that sets both a liberation flag and a story flag applies them across the two-step thaw in a fixed order — liberation state under the wipe, on-screen removal on reveal, Dialogue only after removal finishes, and the stage effect deferred to the affected map's next load.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Relies on the probed `transition_started`/`transition_finished` signal ordering from ADR-0002's Foundation-layer spike; no new engine surface here.

**Control Manifest Rules (this layer)**:
- Required: "Two-step thaw: all state changes in `on_thawed` under the wipe; on `transition_finished`, grace and Noticing/Chasing → Returning after every transition, but on-screen liberation and the payoff card only when `pending_thaw` is set" — source: ADR-0012 §5

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-34 [I] (R14)** GIVEN a Victory that sets a liberation flag and a story flag, THEN these happen in order:
  1. liberation state is written in `on_thawed`;
  2. on-screen removal starts on `transition_finished`;
  3. Dialogue opens after the removal ends;
  4. the stage effect appears only on the next load.

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD rule 14 ("Story flags after battle"):*

- Fixture: a Victory whose record both sets a `liberation_flag` (rule 9) and triggers a stage-raising story flag (rule 8), e.g. a symbol linked to a marker, where beating it also advances a flag in the interim story-flag registry.
- Assert, with a spy on each step, this exact order:
  1. `on_thawed`: liberation state is written to `WorldState` (rule 7 step 1, rule 9 "Timing").
  2. `transition_finished`: on-screen removal begins — gated by `OverworldMode`'s own `pending_thaw` flag, set in `on_thawed` and cleared here (rule 7 step 2).
  3. Story Dialogue opens only once the on-screen removal has finished (or at once if there is none) — `game-state-scene-flow.md` Edge Cases.
  4. The stage effect of the newly-set flag is invisible this visit; it appears only when the affected map is next loaded (rule 8, "When it applies").
- No step may be observed out of order or interleaved with another.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Permit Counter's own Fled/Victory branch (story 091).
- The general save/load round trip of liberated sets and story flags (story 095).

---

## Files

- `tests/integration/overworld/story_flag_order_after_battle_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/overworld/story_flag_order_after_battle_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-091-permit-counter-static-behavior.md`, `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-096-continue-resets-symbols-to-patrol-origin.md`

## Completion Notes (2026-10-30)

- The four steps were each built in stories 059/060 (liberation in `on_thawed`, removal from the reveal, Dialogue after removal) and 053/054 (stage on load). This integration test runs them together on the shipped segment for one Victory over the east Clerk, which liberates the on-screen queue and adds its clue rumour with a stub line.
- The fixture map record raises the stage on that clue flag, so step 4 is observable: still stage 2 this visit, stage 3 on the next load.
- Mutation checked: starting the removal in `on_thawed` instead of at the reveal fails this test.
