# Story 108: Retained screenshots cover the interact prompt, name card, payoff card, bark window, camp prompts and the next-destination arrow

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-018`, `TR-overworld-015`, `TR-overworld-013` (no single TR covers every element in this list — these three are the closest-matching combination: player-facing text, the probe-driven prompt, and the camp/chapter-end prompts)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: The Overworld's on-map UI (UI Requirements table) is limited to a small set of non-blocking, input-transparent elements the mode itself drives — the interact prompt, the map name card, the payoff card, the bark window, the two P15 prompts, the optional next-destination arrow, and the Menu's objective line — each shown verbatim from `LocText` where it carries text.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: No new engine surface; these are UI-canvas elements (outside tilt-shift and depth of field, per UI Requirements), captured on the Steam Deck's reported `pad_style` `xbox` (`input-system.md` rule 4).

**Control Manifest Rules (this layer)**:
- Required: "Player-facing overworld text (posters, decrees, cards, barks) is `LocText`" — source: ADR-0012 Guidelines, ADR-0013
- Required: "Interaction is one `probe()` … that drives both the prompt and `confirm`" — source: ADR-0012 §6

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-45 [UI]** Retained screenshots of:
  - the interact prompt with each of its four kind icons, on keyboard, on one gamepad style, and on the Steam Deck (which reports `pad_style` `xbox`, `input-system.md` rule 4), at the default and the largest text size;
  - the map name card at a normal stage and with the liberated subtitle;
  - the payoff card, the bark window and a decree gag's text, each on the Steam Deck at text scale 1.0 and 1.5;
  - the camp prompt with Yes focused, and the chapter-end prompt with No focused;
  - the optional next-destination arrow;
  - the Menu objective line.

---

## Implementation Notes

*Derived from GDD UI Requirements and rule 19 ("Where to go next"):*

- **Interact prompt**: one composite element per kind icon — speech bubble (NPC), cup (camp), hand (object/gag), ticket (a `confirm`-started fight) — captured on keyboard, one gamepad style and the Steam Deck (`pad_style` `xbox`), at default and largest text size (eight-icon-combination coverage, since the pip scales with the text-size setting).
- **Map name card**: once at a normal stage, once with the liberated subtitle (rule 17) — never showing the stage word either time.
- **Payoff card, bark window, a decree gag's text**: each on the Steam Deck at text scale 1.0 and 1.5, since all three are timed, non-blocking, opaque-panel elements sized by `text_hold(text)`.
- **Camp prompt**: with **Yes** focused (its default, rule per UI Requirements). **Chapter-end prompt**: with **No** focused (its own default, since the step cannot be undone, rule 13).
- **Next-destination arrow**: the optional "Show next destination" setting on, mid-leg, pointing along the walk-grid path.
- **Menu objective line**: the current chapter step's `objective_text`.
- Every screenshot must be **retained** in `production/qa/evidence/` — a captured-then-discarded screenshot is not evidence (coding-standards.md).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The name card's own timing proof (AC-45b) and the beacon-chain/objective-line logic proof (AC-45c), both outside this range.
- The contrast measurements for the prompt and event cues (stories 106, 107 — this story only captures what those already proved legible).

---

## Files

- `production/qa/evidence/` (retained screenshots; the UI elements themselves are implemented by their own stories, e.g. `story-111-map-name-card-timing.md`, `story-113-camp-prompt-cancel-and-focus.md`)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- A retained screenshot of each screen/element listed above, in `production/qa/evidence/`. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-091-permit-counter-static-behavior.md`, `story-111-map-name-card-timing.md` (AC-45b, map name card timing), `story-113-camp-prompt-cancel-and-focus.md` (AC-45d, camp prompt focus)
- Unlocks: None further in this epic
