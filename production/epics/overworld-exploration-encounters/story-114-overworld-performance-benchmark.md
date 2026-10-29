# Story 114: Symbol stepping and queries hold their frame budget on the min-spec PC and Steam Deck

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012 commits symbol stepping, notice queries and repaths together to ≤ 2 ms per frame at p99, on both the GTX 1080-class min spec and the Steam Deck, measured by a custom `Performance` monitor around `step_symbols()`.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Probed: 4-connected component relabel on 60×60 with 25% walls costs ~0.83 ms per full pass; an unreachable `get_id_path` query costs ~0.1–0.39 ms desktop (expect ~3× on the Deck) (ADR-0012 Engine Compatibility items 7, 12). These probes are the basis for the ≤ 2 ms budget this story measures against, not a new probe.

**Control Manifest Rules (this layer)**:
- Guardrail: "Overworld symbol stepping + notice searches + repaths: ≤ 2.0 ms per frame at p99 on the GTX 1080-class PC and the Steam Deck" (control manifest, source `performance.per_system.overworld_ms` in `project.yaml`, ADR-0012 Performance, this AC).
- Guardrail: "Component relabel: one full pass costs ~0.83 ms on 60×60 (probed); batch `set_blocked` and relabel at most once per frame" (control manifest, ADR-0012 §2).
- Required: none beyond the symbol-AI rules this benchmark exercises unmodified.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-46 [P]** In a release export (not the editor), on a named GTX 1080-class PC (`project.yaml` `min_spec`; the machine is recorded in the log) and on a Steam Deck (1280×800): the `perf_overworld` fixture map (Tooling owed), at stage 3, exterior, with N equal to the **shipped dungeon's** `N_max` at stage 3, 3 followers, the stage's full civilian count and tilt-shift on; debug flags disable contact and give-up. Case A (chase): every symbol chases a leader on a scripted loop. Case B (fenced patrol): every symbol patrols with the leader inside its radius behind a long detour, oscillating between two adjacent cells (or `notice_cache_off`), so the bounded search runs every frame. Each case is a 120 s run after a 10 s warm-up, vsync off, pipelines pre-warmed. **Pass:** p99 frame time ≤ `frame_time_p99_ms` and worst frame ≤ `frame_time_worst_ms`; symbol stepping, notice queries and repaths together ≤ 2 ms per frame at p99, measured by a custom `Performance` monitor around `step_symbols()`. **Record:** the log is kept in `production/qa/evidence/perf/`.

---

## Implementation Notes

*Derived from ADR-0012 Performance and the test plan's O-08 procedure:*

This story runs the benchmark; it must not change `SymbolBrain`, `WalkGrid` or the notice/repath budget to pass it. A failing run is a finding against those systems, not against this story.

- Devices: the named GTX 1080-class PC (`project.yaml` `platform.min_spec`; record machine, driver and OS) at 1920×1080, and a Steam Deck native export at 1280×800.
- Build: a windowed release export, vsync off, pipelines pre-warmed by Boot warm-up (ADR-0005 §11) — not the editor, not headless.
- Case A is valid only if every symbol is Chasing on every measured frame; Case B is valid only if notice queries equal `repath_per_frame_max` on every measured frame (the bounded search really runs, per the round-robin cursor in `SymbolBrain`).
- 10 s warm-up, 120 s measured, 3 runs per case per device (test plan O-08); any failing run fails the story.
- `overworld_ms` is the duration of `step_symbols()` (symbol stepping, notice queries and repaths) in microseconds, timed with `Time.get_ticks_usec()`, written per frame by the OW-T01 hook (story 133) and exposed live as a `Performance` custom monitor.
- Gates: p99 frame time ≤ `frame_time_p99_ms` (16.6 default), worst frame ≤ `frame_time_worst_ms` (33 default), p99 `overworld_ms` ≤ `performance.per_system.overworld_ms` (2.0 default) — on both devices, both cases.
- Record a CSV per run plus a summary in `production/qa/evidence/perf/overworld-[date].md`.
- Gate level: BLOCKING at the Vertical Slice gate; **NOT ASSESSED** until story 133 ships, and separately **NOT ASSESSED** without a shipped dungeon record to compute `N_max` or a release export preset.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 133 (`story-133-overworld-performance-fixture-tooling.md`): the `perf_overworld` fixture map, the debug flags, the oscillation hook and the `step_symbols()` timer/monitor this story measures with.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No new source files — runs the OW-T01 harness (story 133) against the shipped dungeon record.
- `production/qa/evidence/perf/overworld-[date].md` (CSV + summary)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: benchmark log in `production/qa/evidence/perf/`. BLOCKING at the Vertical Slice gate; **NOT ASSESSED** until story 133 ships.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-133-overworld-performance-fixture-tooling.md`, a shipped dungeon map record (outside this epic's story range), a release export preset (`commands.build`, outside this epic)
- Unlocks: None
