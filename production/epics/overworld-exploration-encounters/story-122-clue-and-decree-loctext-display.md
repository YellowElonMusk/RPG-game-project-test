# Story 122: Confirm at a clue poster or decree gag shows its LocText verbatim

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

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

- [x] **AC-51c [L] (R16)** On `confirm` at a clue poster or a decree gag, the Dialogue overlay shows the record's `LocText` string verbatim, through the localization path (ADR-0013), at the current text size.

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

- `src/overworld/overworld_mode.gd` (`gag_text()`: gag text through `TranslationServer.translate` with msgctxt `<marker_id>.<field>`; `confirm_gag` uses it for every response and decrees)
- `src/game_state/overlays/interim_line_dialogue.gd` (line Label set to `AUTO_TRANSLATE_MODE_DISABLED`, ADR-0013 §1)
- `tests/unit/overworld/gag_loctext_display_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/gag_loctext_display_test.gd` — must exist and pass.

**Status**: [x] Created and passing — `gag_loctext_display_test.gd` 5/5 (2026-10-30)

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-118-gag-response-behavior.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30
**Criteria**: 1/1 passing (AC-51c, automated)
**Deviations**:
- `LocText` (ADR-0013 `src/loc/`) does not exist yet, and gags are scene nodes, not records. `OverworldMode.gag_text()` does the same lookup `LocText.of()` will (`TranslationServer.translate(source, "<marker_id>.<field>")`, English fallback); `TODO(localization)` to switch once `src/loc/` lands.
- Out-of-list file: `interim_line_dialogue.gd` now disables auto-translate on its code-set Label (ADR-0013 §1, Verification item 9), otherwise a translated line is looked up a second time and is no longer verbatim.
- No text-size setting exists yet; the test applies the GDD's named scales 1.0 and 1.5 to the overlay's own font size and asserts the full string, no trimming, no clipping, wrap on.
**Test Evidence**: Logic — `tests/unit/overworld/gag_loctext_display_test.gd` (clue + decree verbatim at both scales, both through a test `fr` translation, wrong context ignored).
