# Story 133: Build the perf_overworld fixture, debug flags and the step_symbols() performance monitor

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-005 commits "symbol stepping plus queries ≤ 2 ms p99 on GTX 1080 and Steam Deck" — this tooling story is what makes that number measurable.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's performance budget for `step_symbols()` has no way to be measured without a dedicated fixture map, debug flags to hold symbols in a persistent state, and a timing hook — this story is the GDD's "Tooling owed" item for AC-46.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Uses `Time.get_ticks_usec()` and a `Performance` custom monitor — both pre-cutoff APIs; no new engine surface.

**Control Manifest Rules (this layer)**:
- Guardrail: "Overworld symbol stepping + notice searches + repaths: ≤ 2.0 ms per frame at p99 on the GTX 1080-class PC and the Steam Deck" (control manifest, `performance.per_system.overworld_ms` in `project.yaml`, ADR-0012 Performance, this AC) — this story builds the instrument that measures against this guardrail; it does not itself need to hit the budget.
- Required: "Overworld tests live in `tests/unit/overworld/`... with fixture grids and an injected clock and RNG" (control manifest, ADR-0012 Guidelines) — the `perf_overworld` fixture follows the same fixture conventions.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story (tooling story per the story map; delivers the GDD's AC-46 Tooling-owed item, test plan OW-T01):*

- [ ] Delivers: the `perf_overworld` fixture map; debug flags `no_contact`, `no_giveup`, `notice_cache_off`; the leader-oscillation test hook; a per-frame `step_symbols()` timer and `Performance` custom monitor; a CSV logger. Unblocks AC-46 (story 114).

---

## Implementation Notes

*Derived from the test plan's O-08 procedure and Tooling stories table (OW-T01):*

- **`perf_overworld` fixture map**: stage 3, exterior, authored so N (symbol count) can be set to equal the shipped dungeon's `N_max` at stage 3 (computed from its record by `symbol_density`); 3 followers; the stage's full civilian count; tilt-shift on.
- **Debug flags**: `no_contact` (disables contact so a Chasing symbol never triggers a battle and states persist for the whole run) and `no_giveup` (disables the give-up test so Chasing never reverts to Returning) — both needed for Case A (chase) to stay valid for the full 120 s measured window. `notice_cache_off` disables the per-symbol notice-waypoint cache as an alternative to the leader-oscillation hook for Case B.
- **Leader-oscillation test hook**: for Case B (fenced patrol), moves the leader back and forth between two adjacent cells every frame, so the notice cache misses and the bounded search actually runs every frame (rather than hitting the cache and under-measuring the budget).
- **Per-frame `step_symbols()` timer**: measured with `Time.get_ticks_usec()` around the call that steps every symbol, runs notice queries and repaths for the frame; write the duration to a CSV row per frame.
- **`Performance` custom monitor**: expose the same `overworld_ms` value live via `Performance.add_custom_monitor()`, so it can be watched during a run, not only read from the log afterward.
- **CSV logger**: per-run CSV with per-frame frame time and `overworld_ms`, written to `production/qa/evidence/perf/`.
- Not in this story's scope: the release export preset (`commands.build` is unset per the test plan) and the shipped dungeon record needed to compute `N_max` — both are separate blockers on AC-46 (story 114) that this tooling alone does not remove.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 114 (`story-114-overworld-performance-benchmark.md`): actually running the benchmark on the two named devices and recording pass/fail against the budget.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `data/maps/map_perf_overworld.tres` (fixture map record)
- `src/overworld/overworld_config.gd` (debug flags `no_contact`, `no_giveup`, `notice_cache_off`)
- `src/overworld/overworld_mode.gd` (`step_symbols()` timer, leader-oscillation hook, CSV logger)
- `tests/integration/overworld/perf_overworld_fixture_test.gd`
- `production/qa/evidence/perf/` (CSV output location)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/overworld/perf_overworld_fixture_test.gd` OR a playtest/tooling validation doc confirming the fixture, flags and monitor work as specified — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-017-zone-rate-zero-on-every-mvp-map.md` (AC-8, `WalkGrid`/`OverworldConfig` foundation), `story-030-cross-component-query-budget.md` (AC-9h, query budget the monitor measures)
- Unlocks: `production/epics/overworld-exploration-encounters/story-114-overworld-performance-benchmark.md`
