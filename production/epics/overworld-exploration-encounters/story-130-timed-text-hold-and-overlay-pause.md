# Story 130: The name card, payoff card and bark window each hold for text_hold(text), pausing under overlays

> **Epic**: Overworld Exploration & Encounters
> **Status**: In Progress (2026-10-30): name card and bark window holds done; the payoff card waits for story 050
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
**ADR Decision Summary**: ADR-0012 drives all overworld timed text from `ow_dt`; ADR-0002 owns the overlay/transition state (Dialogue, Menu, transitions) that pauses the hold.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface — timing is computed from accumulated `ow_dt`, consistent with the clock already fixed by ADR-0012 §2.

**Control Manifest Rules (this layer)**:
- Required: "All overworld logic steps on one clock `ow_dt = min(delta, dt_max)`, accumulated only in Exploring" (ADR-0012 §2) — every timed-text hold must be computed from this clock, and must stop accumulating while any overlay or transition takes the mode out of Exploring.
- Forbidden: "Never use... `Engine.time_scale` anywhere" (control manifest, ADR-0012 Ordering Note).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-58 [L] (UI, timed text)** The name card, the payoff card and the bark window each hold for `text_hold(text)` (asserted at `− dt` and `+ dt`), and each hold pauses while any overlay is open. A `clue` Victory's interim stub line opens only after the payoff card has faded.

---

## Implementation Notes

*Derived from the UI Requirements "Timed text" formula:*

- Formula: `text_hold(text) = max(name_card_s, text_hold_base_s + words(text) · text_hold_per_word_s)`. A longer line always gets more reading time (the UI Requirements' example: a 9-word teaching bark holds 3.7 s).
- This story asserts the **shared** mechanism across all three elements — the name card (story 111 covers its trigger conditions specifically), the payoff card, and the bark window (story 123 covers its proximity trigger specifically) — rather than any one element's trigger logic.
- Per the Timing rule: assert fully shown at `text_hold(text) − dt` and fading at `text_hold(text) + dt`, with `dt` chosen so `text_hold(text)/dt` is not a whole number, for each of the three elements independently.
- Pause: each hold pauses while **any** overlay is open (Dialogue, Menu, a transition) — confirm the elapsed-hold accumulator stops, not just that the element stays visible.
- Payoff card interaction with a `clue` Victory: a `clue` payoff's interim stub line is queued until the payoff card has faded, so the card is never hidden under an overlay (UI Requirements, payoff-card row).
- `accessibility_live` is polite for the name card and payoff card (out of scope to automate here, but must not be broken by this story's changes).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 111 (`story-111-map-name-card-timing.md`): the name card's specific trigger (reveal-only, never after thaw/redirect).
- Story 123 (`story-123-optional-teach-bark-trigger.md`): the bark's specific proximity trigger and re-arm distance.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_config.gd` (`text_hold(text)` formula: `name_card_s`, `text_hold_base_s`, `text_hold_per_word_s`)
- `src/overworld/overworld_mode.gd` (shared hold/pause timer for the name card, payoff card and bark window; `clue` payoff queueing)
- `tests/unit/overworld/timed_text_hold_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/timed_text_hold_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-111-map-name-card-timing.md`, `production/epics/overworld-exploration-encounters/story-123-optional-teach-bark-trigger.md`
- Unlocks: None
