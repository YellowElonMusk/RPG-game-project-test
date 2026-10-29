# Story 091: The Permit Counter notices nothing, barks once, and only `confirm` starts its fight

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-004`, `TR-overworld-015`, `TR-overworld-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (Fled handling for a Static symbol; automatic Dialogue with P2's `input_guard` after `transition_finished`)
**ADR Decision Summary**: The Permit Counter is a `Static` `EncounterSymbol` with `start_on = confirm`: it never notices, is never stunned or pushed, and only a fresh `confirm` press (never contact) starts or restarts its fight; a Fled result places the leader at its return marker under the wipe and opens an automatic, input-guarded Dialogue on reveal.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The automatic Dialogue's `input_guard` relies on the Input System's one-`pressed`-per-press guarantee (ADR-0003, HIGH risk, post-cutoff SDL3/device-ID changes) so a `confirm` held or mashed from battle cannot bleed through; this story only consumes that guarantee, it does not implement it.

**Control Manifest Rules (this layer)**:
- Required: "Symbol AI lives in the pure `SymbolBrain` (sub-states, … Static `start_on`)" — source: ADR-0012 §5
- Required: "Interaction is one `probe()` (nearest eligible target; ties NPC → CampSpot → Static symbol → Interactable) that drives both the prompt and `confirm`" — source: ADR-0012 §6
- Required: "Player-facing overworld text (posters, decrees, cards, barks) is `LocText`" — source: ADR-0012 Guidelines, ADR-0013

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-33d [L] (R13a)** The Permit Counter is Static and notices nothing. Contact with it starts nothing on any frame over 10 s of overlap, and the first contact plays the "Take a number." bark once; `confirm` at it starts its encounter, and the prompt shows the ticket icon. After Fled: it is not stunned or pushed, the leader is at its return marker in a `SAFE` cell when the wipe reveals, the "number called" line opens as an automatic Dialogue on `transition_finished` and a `confirm` held from the battle does not skip it (`input_guard`), the checkpoint stays closed, and no encounter starts until a new `confirm`. Victory opens the checkpoint and it never respawns. Its camp decree is inactive before the leader first has the Counter on screen and active after.

---

## Implementation Notes

*Derived from ADR-0012 §5, §6 and GDD rule 13a ("The story encounter"):*

- **Static, deaf.** The brain never leaves `STATIC`; the notice test never runs for it (rule 5).
- **Contact does nothing.** `start_on = confirm` means `contact_eligible()` is always false for it, so 10 s of overlap starts nothing — only touching it does nothing, by design (guardrail 1).
- **The bark.** The first contact (touch, not `confirm`) plays "Take a number." exactly once, ever, tying back to the camp decree — never a repeating line.
- **Starting it.** `confirm` at it (through `probe()`, rule 3's tie order placing a `confirm`-started Static symbol ahead of plain Interactables) calls `start_encounter()`; the prompt shows the **ticket** kind icon (UI Requirements).
- **Fled.** Not stunned or pushed (Static symbols are never pushed, rule 5 / Edge Cases). Under the wipe the leader is placed at its return marker, in a `SAFE` cell, facing away. On `transition_finished` the "Your number was called…" line opens as an **automatic** Dialogue with P2's `input_guard`, so a `confirm` still held or mashed from the battle cannot skip it. The checkpoint stays closed; only a fresh `confirm` (press, release, press) restarts the fight.
- **Victory.** Opens the checkpoint; `respawn = never` means it is never fought again.
- **Camp decree.** First-sight-triggered (rule 13a), inactive before the leader has first had the Counter on screen, active after — not gated on a stage raise.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The story encounter's un-bypassable placement proof (story 084).
- Story-flag ordering after its Victory (story 092).

---

## Files

- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/symbol_brain_static_story_encounter_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/symbol_brain_static_story_encounter_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-084-story-encounter-not-routable-around.md`, `production/epics/game-state-scene-flow/story-027-dialogue-closes-before-transition.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-092-story-flag-order-after-battle.md`, `production/epics/overworld-exploration-encounters/story-097-state-table-transitions.md`, `production/epics/overworld-exploration-encounters/story-108-ui-screenshots-prompts-cards-and-prompts.md`

## Completion Notes (2026-10-29)

- **Deviation:** the camp decree gag marker does not exist yet (gags are stories 016/122). The first-sight trigger is built: the first frame the Counter is within the camera visibility edge sets `seen:<symbol_id>` (`OverworldMode.is_first_seen()`), which the decree will read.
- The ticket prompt and the bark window are placeholder labels in `OverworldView` (stories 015 and 130 own the real widgets). Evidence: `production/qa/evidence/story-091-permit-counter/`.
