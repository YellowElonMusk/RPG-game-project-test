# Story 037: Every transition type meets its budget over 30 runs on the min-spec PC and the Steam Deck

> **Epic**: Game State & Scene Flow
> **Status**: Blocked — BLOCKED: needs the `project.yaml` `min_spec` hardware (a GTX 1080-class PC; the development PC is an RTX 4080 SUPER) and a Steam Deck run, which needs a Linux export preset (`commands.build` is `[TO BE CONFIGURED]`). The harness can be built against 035 before then.
> **Layer**: Foundation
> **Type**: Integration (the GDD's [P] performance evidence; the template has no Performance type)
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Performance Implications: synchronous load bounded by the per-type budgets, Retry and Battle → Overworld load nothing; Validation Criteria; Risks: "Synchronous loading may overrun the 1.0 s battle-wipe budget once real dioramas exist")
**ADR Decision Summary**: Swap-phase loads are synchronous and bounded by `TransitionConfig`'s per-type budgets. The GDD tightens the ADR's check: median within budget **and** max within 1.5× budget, on the named min-spec PC **and** a Steam Deck.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real `ResourceLoader.load` + `instantiate` timing; Vulkan on the Deck under gamescope.

**Control Manifest Rules (this layer)**:
- Guardrail: "Swap phase load: bounded by `TransitionConfig`'s per-type budgets (0.5 s Retry, 1.0 s battle wipes, 1.5 s fades); an overrun logs a warning and never skips work."
- Required: "Mode/overlay scene paths, transition timings and budgets come from `TransitionConfig` data, never literals."
- Guardrail (global): `target_framerate: 60` / `frame_budget_ms: 16.6` (transitions must not hitch the frame).

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-26 [P]** *(part: the hardware benchmark)* "On the `project.yaml` `min_spec` machine (GTX 1080-class PC, named in the log), each transition type is run 30 times: the median `transition_time` is within its configured `transition_budget` and the maximum is within 1.5 × `transition_budget`. The same runs repeat on a Steam Deck (named in the log), since `min_spec` also requires the Deck to run smoothly." (The slow-swap half is story 007.)

---

## Implementation Notes

*Derived from ADR-0002 Performance Implications and the QA gate:*

- Measure `last_transition_time` (story 006) per run for each type: `battle_wipe`, `battle_wipe_reverse`, `retry_flash`, and `fade` (each of camp, map change, title, retreat, and the in-mode fade). **`none` is dropped**: the GDD Budgets table has no row for it.
- Budgets come from the shipped `data/config/transition_config.tres`, never literals.
- **Run protocol (QA fix):** one fresh process per (machine, type); 30 consecutive runs; **no warm-up discarded** (run 1 is the cold load the player actually sees and counts toward the max); the log also records run 1 separately.
- **The GDD's thresholds govern.** ADR-0002's Validation Criteria still say "on the development PC" and are stale; flagged to technical-director.
- Log the machine's GPU/CPU name and OS so the evidence names each machine.
- Expect battle-wipe numbers to be optimistic until real dioramas exist: record the caveat, and re-run when ADR-0005's stages land.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the headless slow-swap test.
- The Linux export preset (`commands.build`): release/devops setup.

---

## Files

- `tests/performance/game_state/game_state_transition_budget_bench.gd`
- `production/qa/evidence/game-state-037-transition-bench-[machine]-[date].md` (one per machine; names the machine, lists every run)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: `none` dropped, run protocol pinned, GDD thresholds govern). **DEFERRED** (manual verification note): needs the min-spec PC and a Steam Deck; run manually per machine. The developer implements against these — do not invent new test cases during implementation.*

- **AC-26 (hardware)**: `tests/performance/game_state/game_state_transition_budget_bench.gd` (DEFERRED; run manually per machine)
  - Setup: the shipped `transition_config.tres`; a release-mode export on the named machine; the harness drives each type through the machine API (`battle_wipe`, `battle_wipe_reverse`, `retry_flash`, `fade` for camp / map change / title / retreat / in-mode fade).
  - Verify: 30 runs per type in a fresh process; `median(last_transition_time) <= cfg budget(type)` and `max <= 1.5 × cfg budget(type)`, for every type, on both machines.
  - Pass condition: every type passes on both machines, and each evidence file names the GPU/CPU/OS and lists every run (run 1 flagged).
  - Edge cases: the battle-wipe caveat (placeholder dioramas) is recorded, with a re-run trigger when ADR-0005 stages land.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration (performance)
**Required evidence**:
- Integration: `tests/performance/game_state/game_state_transition_budget_bench.gd` plus `production/qa/evidence/game-state-037-transition-bench-[machine]-[date].md` for the min-spec PC and the Steam Deck. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-006-transition-time-and-budget-check.md`, `production/epics/game-state-scene-flow/story-007-slow-swap-waits-and-warns.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`; min-spec hardware and a Linux export preset
- Unlocks: None (closes GDD Open Question 5, budgets validated on hardware)
