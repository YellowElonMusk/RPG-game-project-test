# Story 003: Every from → to pair not in the transitions table is rejected

> **Epic**: Game State & Scene Flow
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§9 table as `const`; Key Interfaces `REJECTED_INVALID_PAIR`)
**ADR Decision Summary**: The transitions table is a game rule held as a `const`. A request for a pair not in it returns `REJECTED_INVALID_PAIR`, logs an error and changes no state.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A transition request while `phase != IDLE` returns `REJECTED_BUSY` and changes no state" (the same no-change probe is reused for invalid pairs).
- Required: "Split into a pure logic core … joined by injected interfaces" (the log is injected; the test reads the spy).
- Guardrail: none specific (no per-frame work).

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [x] **AC-4 [L]** Parametrized over every from → to pair *not* in the table: the request is rejected.

---

## Implementation Notes

*Derived from ADR-0002 §9 and the QA gate:*

- Generate the complement **from `Mode` × `Mode` minus the machine's own `TRANSITIONS`** at test time. Do not hand-list it: a row added to the table drops out of this test automatically, and a row removed is tested automatically. Story 002's GDD anchor keeps the `const` honest.
- Each case places the machine in the source mode through a fixture path (never by writing private state), calls `request_transition(to)`, and expects the exact code: **`REJECTED_TERMINAL` when the source is Content Error, `REJECTED_INVALID_PAIR` otherwise** (not "either").
- The outcome-driven rows requested **directly** through `request_transition` (Battle → Overworld/Battle/Camp) are also rejected (draft §2 item 7, accepted). Add them as explicit cases with a comment citing that decision.
- Assert the generated case count equals `36 − TRANSITIONS.size()` so an enum change is noticed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the rows that succeed.
- Story 005: every other entry point in Content Error.

---

## Files

- `tests/unit/game_state/game_state_invalid_pairs_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE, expected code tightened). The developer implements against these — do not invent new test cases during implementation.*

- **AC-4**: `game_state_invalid_pairs_test.gd :: test_pair_not_in_table_rejected` (parameterized over `Mode × Mode − TRANSITIONS`)
  - Given: the machine placed in `from` through the fixture path; `probe_before = get_debug_state()`.
  - When: `request_transition(to, a payload valid for to where one exists)`.
  - Then: result == (`REJECTED_TERMINAL` if `from == CONTENT_ERROR` else `REJECTED_INVALID_PAIR`); one error log entry with `code == &"invalid_pair"` (`context.from`, `context.to`); `get_debug_state() == probe_before`; no signal recorded.
  - Edge cases: explicit cases BATTLE→OVERWORLD, BATTLE→BATTLE, BATTLE→CAMP via direct `request_transition` → `REJECTED_INVALID_PAIR` (comment cites draft §2 item 7); `to == BOOT` from every mode; TITLE→TITLE; the generated case count == `36 − |TRANSITIONS|` is asserted.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_invalid_pairs_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing: `tests/unit/game_state/game_state_invalid_pairs_test.gd` (game_state unit 184/184; with overworld + game_state integration 242/242, 2026-10-30)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-30
- request_transition() now logs one error `invalid_pair` {from, to} on every invalid pair, including every request from Content Error (code stays REJECTED_TERMINAL there).
- Complement generated from Mode x Mode - _TRANSITION_TYPES (23 cases, asserted == 36 - |table|); outcome-driven Battle rows covered explicitly.
- Files: src/game_state/game_state_machine.gd, tests/unit/game_state/game_state_invalid_pairs_test.gd
