# Story 123: The optional_teach bark fires on proximity, never blocks movement, and re-arms

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-018 — player-facing overworld text, including barks — is the closest match; no TR names the proximity-trigger logic itself.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012 leaves the bark as GDD rule 16/19 UI content (P14 Confirm-Gated Text legibility, without the gate); this story is the proximity-trigger and re-arm logic no script in ADR-0012's Key Interfaces names explicitly.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: No new engine surface — pure distance/state logic driven by `ow_dt`.

**Control Manifest Rules (this layer)**:
- Required: "All overworld logic steps on one clock `ow_dt`, accumulated only in Exploring" (ADR-0012 §2) — the bark's distance check and the name-card wait must use mode time, not wall time.
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-51d [L] (R16)** The `optional_teach` bark fires when the leader comes within `interact_reach_m · 2` of its speaker, with no input, and never blocks movement. It does not fire again until the leader has moved beyond twice that distance, then fires again on re-entry. `confirm` at the speaker shows the same line. A bark due while the name card shows waits until the card has faded.

---

## Implementation Notes

*Derived from GDD rule 16 ("Clerks are optional: the teaching beat") and the UI Requirements bark-window row:*

- Trigger: a proximity bark from the `optional_teach` speaker, shown in an opaque bark window (P14 legibility, without the `confirm` gate), fires when the leader comes within `interact_reach_m · 2` of the speaker — **with no input required**, and it must never block movement (non-blocking, input-transparent, per the UI Requirements table).
- Re-arm: once fired, it does not fire again until the leader has moved **beyond twice that distance** (i.e. beyond `interact_reach_m · 4`... re-read precisely: "beyond twice that distance" means beyond `2 · (interact_reach_m · 2)`), then fires again on re-entry within `interact_reach_m · 2`.
- `confirm` at the speaker independently shows the same line (the speaker "also answers `confirm` with the same line" — UI Requirements), regardless of the proximity bark's own armed/fired state.
- Ordering with the name card: a bark due while the map name card still shows must wait until the card has faded (UI Requirements bark-window row; consistent with story 111's name-card timing).
- The speaker itself must sit within `interact_reach_m · 2` of a critical-path cell, before the first notice radius along it (checked in CI by story 119) — this story assumes that placement is already valid and tests the trigger/re-arm state machine itself.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 119 (`story-119-faction-clue-placement-ordering.md`): where the `optional_teach` speaker is allowed to sit relative to the first patrol and the critical path.
- Story 111 (`story-111-map-name-card-timing.md`): the name card's own timing — this story only checks the bark waits for it.
- Story 130 (`story-130-timed-text-hold-and-overlay-pause.md`): the bark window's shared `text_hold(text)` duration once it has fired.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/overworld_mode.gd` (proximity bark trigger, re-arm distance, name-card wait)
- `tests/unit/overworld/optional_teach_bark_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/overworld/optional_teach_bark_test.gd` — must exist and pass.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-119-faction-clue-placement-ordering.md`, `production/epics/overworld-exploration-encounters/story-111-map-name-card-timing.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-130-timed-text-hold-and-overlay-pause.md`

## Completion Notes (2026-10-30)

- `NpcSpawn.optional_teach`; the segment café regular carries it. The bark goes out on `OverworldMode.barked` and shows in the placeholder bark label (story 130 owns the real window).
- The name card (story 111) is not built; `OverworldMode.name_card_showing` is the hook it sets, and a bark due meanwhile waits for it.
