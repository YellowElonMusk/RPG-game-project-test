# Story 111: The map name card shows only on a map load's reveal

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow
**ADR Decision Summary**: ADR-0012 drives all overworld UI timing from `ow_dt`; ADR-0002 fixes the transitions (map load reveal, thaw, the in-mode redirect fade) that this card must never re-appear after.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface. Timing is driven by `ow_dt`, not wall time, so no post-cutoff API is touched; risk is inherited from ADR-0002's HIGH rating.

**Control Manifest Rules (this layer)**:
- Required: "All overworld logic steps on one clock `ow_dt = min(delta, dt_max)`, accumulated only in Exploring... sprite animation is driven from `ow_dt` too" (ADR-0012 §2).
- Required: "Two-step thaw: all state changes in `on_thawed` under the wipe; on `transition_finished`, grace and Noticing/Chasing → Returning after every transition" (ADR-0012 §5) — the name card's "never after a thaw" rule reads this transition.
- Forbidden: "Never use... `Engine.time_scale` anywhere" (control manifest, ADR-0012 Ordering Note) — timed text holds must use `ow_dt`, not wall time.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-45b [L] (UI)** The map name card appears on a map load's reveal and never after a thaw or a redirect. It is fully shown at `text_hold(text) − dt` after the reveal and fading at `text_hold(text) + dt`. A story Dialogue due on the same load opens after it fades. Its text never contains a stage word.

---

## Implementation Notes

*Derived from ADR-0012, GDD rule 19 (UI Requirements) and the Timing rule:*

The map name card is the GDD's one new UI element without a script in ADR-0012's Key Interfaces; it is owned by `OverworldMode` because only the mode knows whether the current reveal is a map load versus a battle thaw or a checkpoint redirect.

- Trigger: only a map load's reveal (`States and Transitions`: `MapChanging` → `Exploring` on reveal). Never on `Frozen` → `Exploring` (battle thaw) or `Redirecting` → `Exploring` (checkpoint redirect).
- Content: the map's name plus a flavour subtitle from the faction × stage record, or the liberated subtitle once `region_liberation_flag` is set. The text must never contain the stage word (rule 8's "Contested"/"Occupied"/"Saturated" never leak to players).
- Timing: `text_hold(text) = max(name_card_s, text_hold_base_s + words(text) · text_hold_per_word_s)` (UI Requirements, Timed text). Per the Timing rule, assert fully shown at `text_hold(text) − dt` and fading at `text_hold(text) + dt`, with `dt` chosen so `text_hold(text)/dt` is not a whole number.
- Pause rule: the hold pauses while any overlay is open (consistent with the payoff card and bark window sharing the same `text_hold` mechanism).
- Ordering: a story Dialogue due on the same load must wait until the card has faded before it opens (Edge Cases: "If the Map name card and a story Dialogue are both due on the same load").
- `accessibility_live` is polite, so a screen reader announces the card — out of scope for this story's automated test, but do not implement anything that would defeat it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 112 (`story-112-leg-beacon-chain-and-objective-line.md`): the beacon chain and objective line shown independently of the name card.
- Story 130 (`story-130-timed-text-hold-and-overlay-pause.md`): the shared `text_hold(text)` formula assertions across the name card, payoff card and bark window together, and the overlay-pause behaviour in general.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_mode.gd` (name card trigger: reveal-only, never after thaw/redirect)
- `src/overworld/overworld_config.gd` (`text_hold` knobs: `name_card_s`, `text_hold_base_s`, `text_hold_per_word_s`)
- `tests/unit/overworld/name_card_timing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/name_card_timing_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-039-encounter-descriptor-matches-record.md` (AC-14, Integration test of the thaw/transition sequence this card must not re-trigger on), Game State & Scene Flow (`production/epics/game-state-scene-flow/`, Done)
- Unlocks: `production/epics/overworld-exploration-encounters/story-130-timed-text-hold-and-overlay-pause.md`
