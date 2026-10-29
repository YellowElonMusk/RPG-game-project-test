# Story 113: The camp prompt's cancel does nothing, and Yes has default focus

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow
**ADR Decision Summary**: ADR-0012 defines the `CampPrompt` state and when it opens; ADR-0002 (§11 revision) fixes `register_camp()` as the only way `last_camp_id` gets written, and that Game State — not the mode — remains the single writer.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Pure UI-state logic (focus default, `cancel` handling); no new engine surface. Risk inherited from ADR-0002.

**Control Manifest Rules (this layer)**:
- Required: "`last_camp_id`... must be written only by the machine, from `CampEntryPayload` or `register_camp()`" (ADR-0012 §4, ADR-0002 annotation (c)) — the prompt's Yes path must go through `register_camp`/the Camp request, never write state itself on `cancel`.
- Forbidden: none specific beyond the general physics ban.
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-45d [L] (UI)** In the camp prompt, `cancel` closes it with no camp request, and Yes has the default focus.

---

## Implementation Notes

*Derived from ADR-0012 and the States and Transitions table:*

- `CampPrompt` opens on `confirm` at a CampSpot (the P15 "Rest here?" prompt), **except** the café on the chapter's final step, where `confirm` opens the P15 "End the chapter here?" prompt instead (rule 13) — that variant is out of scope here (see story 113's sibling AC-45 screenshots, story 108, outside this writer's range).
- `cancel` at the "Rest here?" prompt: closes the prompt, issues **no** camp request, and returns to `Exploring`. No rest is needed and no state changes (UI Requirements: "Yes / No. Yes has the default focus... `cancel` acts as No and closes the prompt without doing anything").
- Default focus: **Yes**, because the player already chose to press `confirm` on the camp, and resting costs nothing (UI Requirements rationale, P15's Used In list).
- No rest cost, no fade, no `register_camp()` call on `cancel` — only on Yes does the Camp request proceed (the mode exits per the `CampPrompt` row of States and Transitions).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 108 (`story-108-ui-screenshots-prompts-cards-and-prompts.md`, AC-45, outside this writer's range): the retained screenshot of the camp prompt with Yes focused, and the chapter-end prompt with No focused.
- The chapter-end prompt's own behaviour on the final step's café (rule 13) — a different prompt instance, not this AC.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_mode.gd` (`CampPrompt` state: `cancel` handling, default focus)
- `tests/unit/overworld/camp_prompt_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/camp_prompt_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Game State & Scene Flow (`production/epics/game-state-scene-flow/`, Done, `register_camp`/§11)
- Unlocks: None
