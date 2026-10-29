# Story 122: Confirm at a clue poster or decree gag shows its LocText verbatim

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

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's Implementation Guidelines require player-facing overworld text (posters, decrees, cards, barks) to be `LocText`; GDD rule 16 commits that the Dialogue overlay shows that string verbatim on `confirm`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No new engine surface — a text-display assertion.

**Control Manifest Rules (this layer)**:
- Required: "Player-facing text (posters, decrees, cards, barks) must be `LocText` (ADR-0013)" (ADR-0012 Implementation Guidelines).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-51c [L] (R16)** On `confirm` at a clue poster or a decree gag, the Dialogue overlay shows the record's `LocText` string verbatim, through the localization path (ADR-0013), at the current text size.

---

## Implementation Notes

*Derived from GDD rule 16 ("Text in the world is also text on screen"):*

- Every clue poster and decree gag carries its text as a `LocText` string in its record. The sprite's painted text is a bonus, not the source of truth.
- On `confirm`, the Dialogue overlay must show that string **verbatim** — not paraphrased, not truncated — so it scales with the text-size setting, is localized through the ADR-0013 path, and reaches a screen reader.
- This applies identically to clue posters (`clue` response) and decree gags (rule 8's `decree_gag` marker kind, always eligible for `confirm`, rule 8/16).
- Assert at more than one text-size setting (the GDD's UI Requirements names "current text size" — test at default and at least one larger scale) to catch truncation.
- This story tests the display mechanism only; which text each record carries is a content/narrative concern (story 121).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 118 (`story-118-gag-response-behavior.md`): which gag response type fires (`line` / `change` / `clue`) — this story only checks the verbatim display once Dialogue opens.
- Story 121 (`story-121-narrative-guardrail-signoff-checklist.md`): whether the text content itself passes the tone checklist.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_mode.gd` (Dialogue overlay invocation with the record's `LocText`)
- `tests/unit/overworld/gag_loctext_display_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/gag_loctext_display_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-118-gag-response-behavior.md`
- Unlocks: None
