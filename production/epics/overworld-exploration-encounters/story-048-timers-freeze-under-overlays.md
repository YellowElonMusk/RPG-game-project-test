# Story 048: Grace, notice, give-up, cooldown and stun timers freeze under overlays and transitions

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0002: Game State & Scene Flow (overlay stack, `mode_time`)
**ADR Decision Summary**: `ow_dt` accumulates only while the mode is in Exploring, so every symbol and grace timer is driven by it and freezes exactly when Exploring is suspended — the Menu, Dialogue, the CampPrompt or any transition.
**ADR Version**: ADR-0012 2026-10-23; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `mode_time` stopping while the Menu is open is a documented `GameStateMachine` property (ADR-0002 Key Interfaces); HIGH risk follows ADR-0002's own rating.

**Control Manifest Rules (this layer)**:
- Required: All overworld logic steps on one clock `ow_dt = min(delta, dt_max)`, accumulated only in Exploring — ADR-0012 §2
- Forbidden: Never advance a symbol's timers outside Exploring; never use `Engine.time_scale`
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-20b [L] (R7)** Grace, notice, give-up, cooldown and stun timers do not advance while the Menu, Dialogue or CampPrompt is open, or while a transition runs.

---

## Implementation Notes

*Derived from ADR-0012 §2 ("One clock") and GDD States and Transitions ("Symbol sub-states and grace timers advance only in Exploring"):*

- For each of grace, the notice delay, the give-up timer, the re-notice cooldown and the stun timer: start the timer, then open each overlay kind in turn (Menu, Dialogue, CampPrompt) and separately run a transition, and assert the timer's recorded value does not change by even one `dt` while suspended.
- Resume Exploring after each suspension and assert the timer continues from **exactly** where it left off — not reset, not fast-forwarded.
- This is a single shared mechanism (`ow_dt` gating), so one parametrized test over the five timer kinds × four suspension kinds is preferable to twenty near-duplicate fixtures, provided the harness's injectable mode clock makes that practical.
- No `Engine.time_scale` is used anywhere (ADR-0012 §2) — assert the production code path does not touch it, if the test harness can observe that; otherwise this is an implementation-notes-only reminder for the reviewer.

---

## Out of Scope

- `story-047-encounter-grace-starts-on-reveal.md`: when grace starts.
- `story-033-returning-to-resume-point.md`, `story-045-stunned-symbol-grants-no-encounter.md`: the specific timers' own semantics once running.

---

## Files

- `src/overworld/overworld_mode.gd`
- `src/overworld/symbol_brain.gd`
- `tests/unit/overworld/overworld_mode_timers_freeze_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/overworld/overworld_mode_timers_freeze_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing (full suite 824/824, 2026-10-29)

---

## Dependencies

- Depends on: `story-047-encounter-grace-starts-on-reveal.md`
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-29 (implemented, awaiting /story-done)
- `OverworldMode.is_exploring()` gates `step_frame`: not Frozen, no overlay (counted from overlay_opened/closed), no transition (transition_started to transition_finished; seeded from `machine.phase` in setup) and no CampPrompt (`set_camp_prompt_open`, TODO: CampSpot flow). No Engine.time_scale anywhere.
- Interpretation: a transition ends with transition_finished, which by rule 7 restarts grace and turns Noticing/Chasing into Returning, so those three cases assert the freeze and then the rule-7 outcome rather than an exact resume.
- Test: `tests/unit/overworld/overworld_mode_timers_freeze_test.gd` (5 timers x 4 suspensions).
- Status synced 2026-10-30 from commit 523dc33.
