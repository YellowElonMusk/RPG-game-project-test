# Story 121: Every narrative guardrail item has a passing sign-off entry

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-018 — player-facing overworld text — is the closest match; no TR names the narrative sign-off process itself.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012 commits every piece of player-facing overworld text to `LocText`; GDD rule 18 is the tone-checklist process that gates all of it before it ships, recorded in the narrative sign-off file.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No engine surface — a content review and sign-off record.

**Control Manifest Rules (this layer)**:
- Required: none directly (this is a content/process gate).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-51 [N] (R8, R18)** The narrative sign-off record has a passing entry for every item in rule 18's scope: every faction × stage content set, the decree gags, the story encounter's lines, the recruit remarks, the boss chamber, the post-battle story Dialogue, the liberated set and the other player-facing text rule 18 lists. Every entry ticks (a); each faction × stage set and each liberated set also ticks (a2) and (b)–(d); each line-only item also ticks the lines-only composite read; each clue also ticks (e). Each entry records the art-director's co-signature on (a) and (a2) where they apply, and carries the content hash. Paris ships at least three recruit remarks, at least one of which ribs the squad, and the record confirms that every liberation reaction tagged `ribs_squad` really ribs the squad.

---

## Implementation Notes

*Derived from GDD rule 18 (Narrative guardrails and sign-off):*

- Scope (rule 18 "Scope"): every faction × stage content set (clutter, civilians, lines, decree gags), every clue, the story encounter's lines, the recruit remarks, the boss chamber, the post-battle story Dialogue, the liberated set, and every other player-facing overworld text: payoff cards, map names and name-card subtitles, street names, checkpoint denial lines, `objective_text`, barks and the chapter-end prompt.
- Ticks (rule 18 "Tone checklist"):
  - **every entry** ticks (a) — nothing from guardrail 6's exclusion list;
  - **each faction × stage set and each map's liberated set** also ticks (a2) — the composite test passes on the set's highest-stage capture plus all its lines — plus (b) at least one item where Bureaucratia has a point, (c) at least one where the Parisians look ridiculous, (d) at least one where the squad looks ridiculous;
  - **a line-only item** (decree, card, denial line, bark, Dialogue) ticks (a) plus the lines-only composite read (guardrail 6's composite question asked of its text alone);
  - **a clue** also ticks (e) — the comprehension check (covered in full by story 120 for Paris's clue).
- Each entry: item ID, reviewer(s), the applicable ticks, date, and the reviewed content's hash. The **art-director co-signs (a) and (a2)**, since half of the exclusion list is visual.
- Fail path: a set that fails is reworked and re-checked — it does not ship with a waiver.
- Paris-specific content minimum: at least three recruit remarks ship, at least one of which ribs the squad itself (Pillar 2). Confirm every liberation reaction tagged `ribs_squad` (AC-26e, outside this writer's range) actually ribs the squad, not just carries the tag.
- Record in `design/gdd/reviews/overworld-narrative-signoff.md`, one entry per item.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 120 (`story-120-faction-clue-narrative-signoff-and-comprehension.md`): the Paris clue's own entry, including its (e) comprehension check — this story covers every *other* item in rule 18's scope.
- Story 122 (`story-122-clue-and-decree-loctext-display.md`): the technical display mechanism for clue/decree text — this story only checks the content's tone passed review.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No source files — a content review and sign-off record.
- `design/gdd/reviews/overworld-narrative-signoff.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: narrative sign-off record `design/gdd/reviews/overworld-narrative-signoff.md`, one entry per item in scope. BLOCKING (the GDD evidence-tag table marks `[N]` BLOCKING).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-120-faction-clue-narrative-signoff-and-comprehension.md`, `story-121-narrative-guardrail-signoff-checklist.md` content from across the epic's faction × stage, boss, and liberation stories (outside this writer's range)
- Unlocks: None
