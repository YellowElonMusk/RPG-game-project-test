# Story 118: Each gag response type behaves as specified

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-015 — the single `probe()`/`confirm` interaction path a gag response fires through — is the closest match.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's `OverworldMode.probe()` drives both the interact prompt and `confirm`; a `gag` Interactable's response fires through that same path, per GDD rule 16.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Pure interaction logic; no new engine surface.

**Control Manifest Rules (this layer)**:
- Required: "One `probe()` picks the nearest eligible target... and drives both the interact prompt and confirm" (ADR-0012 §6, GDD rule 3 / AC-7a) — a gag's `confirm` must go through this same path, never a bespoke input check.
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-49b [L] (R16)** Each gag response type behaves as specified. `line` opens Dialogue. `change` plays its change without an overlay and saves it as opened. `clue` opens Dialogue and adds one rumour. A `recruit_remark` reference is optional, and the record validates with or without one.

---

## Implementation Notes

*Derived from GDD rule 16 (Gags, clues, teaching and recruit remarks):*

A gag is an `Interactable` kind, `gag`. On `confirm`, it gives exactly one of three responses, chosen in data:

- **`line`**: opens the Dialogue overlay with a dialogue beat (the joke). Uses the same Interacting/Dialogue state as an NPC line (States and Transitions).
- **`change`**: plays a small state change (a notice torn down, tape cut) **without** opening an overlay, and saves the change as opened — this stays in `Exploring` the whole time (States and Transitions: "A gag with a `change` response → plays its change, stays in Exploring").
- **`clue`**: opens Dialogue **and** adds one Codex rumour (rule 7a). The clue's text is also shown as on-screen art without interacting where the marker is tagged `faction_clue` — that ordering/placement guarantee is story 119, not this one.
- **Text on screen is text in the world**: whichever response opens Dialogue, the overlay must show the record's `LocText` string verbatim (localized, screen-reader reachable) — the display mechanism itself is story 122; this story only checks which response type fires which behaviour.
- `recruit_remark` is an optional reference any Interactable (including a gag) may carry; the record must validate whether or not it is present. Attaching the remark to Dialogue/Banter's comment system is out of scope — Dialogue has no epic yet, named as a dependency.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 117 (`story-117-clutter-marker-gag-or-blocker-validation.md`): whether every active marker *has* a valid response at all.
- Story 119 (`story-119-faction-clue-placement-ordering.md`): where a `faction_clue`-tagged marker must sit on the critical path.
- Story 122 (`story-122-clue-and-decree-loctext-display.md`): the verbatim `LocText` display mechanism itself.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_mode.gd` (gag response dispatch: `line` / `change` / `clue`)
- `data/encounters/` and `data/maps/` (gag marker records, `recruit_remark` optional field)
- `tests/unit/overworld/gag_response_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/gag_response_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-117-clutter-marker-gag-or-blocker-validation.md`, `story-016-interactable-eligibility-rules.md` (AC-7f, interaction eligibility), Dialogue (no epic yet, named as a dependency per the GDD)
- Unlocks: `production/epics/overworld-exploration-encounters/story-122-clue-and-decree-loctext-display.md`
