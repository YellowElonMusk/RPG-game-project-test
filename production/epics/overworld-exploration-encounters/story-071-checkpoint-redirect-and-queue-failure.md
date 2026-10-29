# Story 071: Redirect and queue failures lock input, snap the party to the return marker and start grace

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: A failed checkpoint closes its Dialogue and calls `machine.request_in_mode_fade(callback)` — a same-instance, zero-length-SWAP transition that places the leader at the return marker, snaps the camera and followers, and writes `WorldState` itself.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `process_priority` sorts all nodes globally (probed, 4.7.2) — the machine ticks before `OverworldMode`'s step, so the fade callback must write `WorldState` itself rather than rely on frame order. Risk follows ADR-0002's row (HIGH).

**Control Manifest Rules (this layer)**:
- Required: A failed checkpoint's redirect closes the Dialogue and then calls `machine.request_in_mode_fade(callback)`; the callback places the leader at the return marker, snaps the camera and followers, and writes `WorldState` itself — source: ADR-0012 §2, §6
- Forbidden: Never write `WorldState` from `OverworldMode._ready()` — source: ADR-0012 §4
- Guardrail: Overworld symbol stepping + notice searches + repaths ≤ 2.0 ms per frame at p99 — source: ADR-0012 Performance, Overworld GDD AC-46

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-28b [L] (R10)** GIVEN an unmet requirement with `redirect` or `queue`, THEN after the line the state is Redirecting, input is locked, and the leader is placed at the return marker facing away. The camera and followers snap, and grace starts on `transition_finished`, when every Noticing or Chasing symbol switches to Returning (rule 7). Every other symbol's sub-state, position and timers equal their pre-redirect values, and no `mode_entered` fires (same-instance transition). `queue` uses no timed or held input.

---

## Implementation Notes

*Derived from GDD rule 10 ("Redirect") and rule 7 ("Grace"):*

- The redirect is an input-locked dip-fade (P9) with no faction color, through the flash gate — a **same-instance** Game State transition: the overworld stays loaded, symbols keep their state, no `mode_entered` fires, Game State still locks input, defers the Menu, reports not save-safe, and emits `transition_finished` (ADR-0002 amendment, §11).
- Under the fade the leader is placed at the checkpoint's return marker, facing away from the checkpoint; the camera snaps, followers snap, and encounter grace starts on reveal — every Noticing or Chasing symbol switches to Returning when grace starts (rule 7).
- `queue` differs from `redirect` only in its dialogue beat (a comedic queue line before the redirect); rule 10: "Never a wait, hold or timed input" — neither outcome uses timed or held input (control manifest "No grind blocks").
- Every return marker is a safe-zone source (rule 0), so a redirect never lands next to a patrol and never sends the player far back.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-070-checkpoint-opens-on-met-requirement: the success branch (AC-28a)
- story-072-checkpoint-encounter-outcome: the `encounter` failure outcome (AC-28c)

---

## Files

- `src/overworld/overworld_mode.gd` (redirect/queue → `request_in_mode_fade` callback)
- `src/overworld/markers/interactable_checkpoint.gd`
- `tests/unit/overworld/checkpoint_redirect_and_queue_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/checkpoint_redirect_and_queue_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-070-checkpoint-opens-on-met-requirement.md`, `production/epics/game-state-scene-flow/` (done; `request_in_mode_fade`)
- Unlocks: `production/epics/overworld-exploration-encounters/story-072-checkpoint-encounter-outcome.md`

## Completion Notes (2026-10-29)

- The line plays through an **interim** Dialogue overlay (`src/game_state/overlays/interim_line_dialogue.gd`, registered for `OverlayKind.DIALOGUE`) until Dialogue, Banter & Quests (#17) is designed. It refuses `confirm` for `input_guard` (0.15 s) after opening (P2).
- `CheckpointMarker.failure_line` holds the line as plain text until LocText exists; an empty one falls back to a default naming the requirement.
- The camera snap is the view snapping on `OverworldMode.party_placed`.
