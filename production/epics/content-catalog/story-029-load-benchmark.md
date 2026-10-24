# Story 029: 500 generated records load and validate with a median under 1.0 s over 10 runs (advisory)

> **Epic**: Content Catalog
> **Status**: Deferred (2026-10-24): load-time benchmark; build when content volume grows
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (F5 performance budget; loads once at boot)
**ADR Decision Summary**: The catalog loads once at boot and every record stays resident. F5: `performance_pass = median(load_time_samples) < LOAD_TIME_BUDGET`, with `BENCHMARK_RECORD_COUNT` (200–2000, default 500) and `LOAD_TIME_BUDGET` (0.5–2.0 s, default 1.0 s) as benchmark-config knobs. Provisional: the target hardware is an Open Question.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load()` defaults to `CACHE_MODE_REUSE`, which would make later runs in the same process measure the cache. Run each sample in a fresh engine process (control manifest: "Run each verification or characterization pass in a fresh engine process"). Time with `Time.get_ticks_usec()`.

**Control Manifest Rules (this layer)**:
- Required: "ContentCatalog load + validation: median of 10 runs on 500 generated records under 1.0 s on the development PC (provisional)" (GDD F5 / AC-25). "Run each verification or characterization pass in a fresh engine process."
- Forbidden: running the benchmark as a unit test (the GDD says it is a benchmark).
- Guardrail: "ContentCatalog: loads once at boot, never per frame; every record stays resident for the session."

---

## Acceptance Criteria

*From GDD `design/gdd/content-data-definitions.md`, scoped to this story:*

- [ ] **AC-25** GIVEN a generated catalog of 500 valid records, WHEN it is loaded and validated (file reading and validation, excluding engine startup) on the machine named in the benchmark log (target: the `project.yaml` `min_spec` GTX 1080-class PC), THEN the median of 10 runs is under 1 second. ADVISORY until run on that machine. Run as a benchmark, not as a unit test. *Provisional: the target hardware is an Open Question.*

---

## Implementation Notes

*Derived from GDD F5 and Tuning Knobs:*

- `res://tools/ci/benchmark-content-load.gd` (`extends SceneTree`), two modes:
  - `--generate=<dir>`: writes `BENCHMARK_RECORD_COUNT` valid records across all 12 types with a deterministic generator (no random seed; IDs and values derived from the index), with every reference resolving. Write into a scratch directory outside `res://data` and outside `tests/` (e.g. `user://benchmark_content/`, or a gitignored `res://.benchmark/`), so the generated set is never committed or discovered by gdUnit4.
  - `--measure --data-root=<dir>`: one sample. Start the timer after autoloads are up (in `_initialize()`), run `ContentBootstrap.run(catalog, data_root)`, stop when the state is terminal, print the sample in seconds, and exit 1 if the catalog is not `READY`.
- A driver (the same script with `--runs=10`, spawning children via `OS.execute`) collects 10 fresh-process samples, prints the median and compares it against `LOAD_TIME_BUDGET`.
- Knobs: read `BENCHMARK_RECORD_COUNT` and `LOAD_TIME_BUDGET` from a benchmark config resource (`res://tools/ci/benchmark_config.tres`, defaults 500 and 1.0), never from literals in the script.
- Gate: ADVISORY. It never blocks `/story-done` or `/gate-check`. Record and surface the result.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Running on the `min_spec` machine: logged as provisional until that hardware is available (GDD Open Question).

---

## Files

- `tools/ci/benchmark-content-load.gd`
- `tools/ci/benchmark_config.tres`
- `production/qa/smoke-[date].md` (or a benchmark log) with the result

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23: ADEQUATE, ADVISORY). The developer implements against these — do not invent new test cases during implementation.*

- **AC-25**: Median load + validation time for 500 records.
  - Setup: run `tools/ci/benchmark-content-load.gd` to generate 500 valid records covering all 12 types, with a deterministic generator.
  - Verify: run 10 **fresh** headless processes. In each, the timer starts after autoloads are up and stops when `state == READY`. Record the 10 samples, the median, the machine (CPU, GPU, RAM, storage) and the commit in `production/qa/smoke-[date].md` or a benchmark log.
  - Pass condition: the median is below `LOAD_TIME_BUDGET` (read from config, default 1.0 s). Mark the result "provisional: not min_spec" unless it ran on a GTX 1080-class machine (`project.yaml` `min_spec`). The result never blocks `/story-done`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: the benchmark result in `production/qa/smoke-[date].md` (or a benchmark log): 10 samples, median, machine, commit. Gate level: ADVISORY.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-027-headless-validate-content.md`
- Unlocks: None
