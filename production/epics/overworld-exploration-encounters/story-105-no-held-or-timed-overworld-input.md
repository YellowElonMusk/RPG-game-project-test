# Story 105: No overworld flow requires a hold or a timed press

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0003: Input System (the bindings table this audit reads)
**ADR Decision Summary**: Rule 1's "no run button, held or toggled" commitment generalises to every overworld flow: the accessibility commitment forbids any held or timed-press requirement anywhere on the map, and every flow must complete with discrete presses plus `move` alone.
**ADR Version**: ADR-0012 2026-10-23 · ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The audit reads `InputResolver`'s compiled binding table (ADR-0003), which does not use Godot's `InputMap` and is HIGH risk only because Input changed across 4.5 (SDL3 gamepad driver), 4.6 (dual focus) and 4.7 (keyboard/mouse device IDs) — none of those changes affects whether a binding is a hold or a timed press, which this story treats as a static, engine-independent audit.

**Control Manifest Rules (this layer)**:
- Required: "There is no run button, held or toggled. The accessibility commitment forbids held inputs, and MVP maps are short enough that walking is not a chore" — source: GDD rule 1

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-43 [L] (accessibility)** No overworld action requires a hold or a timed press (input-map audit). Every flow completes with discrete presses plus `move`.

---

## Implementation Notes

*Derived from GDD rule 1 and the Visual/Audio Requirements `[A11Y]` commitment:*

- Audit the overworld's binding usage for `move`, `confirm`, `cancel` and `menu` across every flow this GDD defines: interaction (rule 3), the checkpoint redirect (rule 10), the camp prompt and chapter-end prompt (UI Requirements), and the Dialogue-close consume (rule 3, P2). None may require a hold or a timed window to register.
- The one place a hold is checked and explicitly rejected elsewhere in this epic is AC-7d (story outside this range): `confirm` held for 10 frames closes an overlay without starting a new interaction — that is a **debounce**, not a required hold, and is out of scope here.
- Assert every flow is completable using only discrete presses plus continuous `move` input — never a press-and-wait or a timed combo.
- This is a static audit over the flow definitions and the bindings table, not a runtime simulation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The `confirm`-held debounce after closing an overlay (AC-7d, outside this range).
- The Input System's own binding-table compilation and device tracking (Foundation layer, done).

---

## Files

- `tests/unit/overworld/no_held_or_timed_input_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/no_held_or_timed_input_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-010-input-locked-during-transition.md`
- Unlocks: None further in this epic

## Completion Notes (2026-10-30)

- Static audit: the source of the overworld's input handlers (`OverworldMode`, the interim Dialogue, the interim Camp) contains no press-duration or window reads (`is_action_pressed`, `echo`, hold timers and similar). An injected `Input.is_action_pressed` fails it.
- Flow audit: interaction and its close, the checkpoint redirect, the camp prompt (Yes / No / cancel) and the chapter-end prompt each complete with single press-and-release pairs.
- The Dialogue's 0.15 s `input_guard` is a debounce (a confirm inside it is refused, a later one works); no flow requires waiting for it.
