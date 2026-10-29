# Story 069: Nothing compiles a rendering pipeline in play, measured

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §11's measured contract records every `Performance.PIPELINE_COMPILATIONS_*` monitor before and after a scripted state cycle, run from an empty shader cache after Boot's main-viewport warm-up stage, with a negative control and a frame-time spike guard because some post-effect pipelines don't register on the counters.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Both engine shader/pipeline caches default to `true` on 4.7.2 and stay there — the harness instead deletes the Vulkan pipeline cache files under `user://` and `.godot/shader_cache/` before each run (§11, exact paths confirmed in Step 1 / P-15). Driver-level caches (NVIDIA, Mesa/RADV, Steam's Fossilize) are invisible to the counters and are not cleared by the harness, so the counters — not wall-clock timing — remain the measure. Toggling glow and switching the tonemapper left the counters at 0 on 4.7.2 (probed), hence the required negative control and frame-time spike guard.

**Control Manifest Rules (this layer)**:
- Required: Boot warms every (mode, profile) combination's compiling parameters and every in-play canvas material, in the MAIN viewport, never a differently-configured `SubViewport` (ADR-0005 §11)
- Required: AC-64's "empty shader cache" state deletes the engine's Vulkan pipeline cache in `user://` and `.godot/shader_cache/`; both engine cache settings stay at their shipped `true` (ADR-0005 §11)
- Guardrail: No frame of the scripted state cycle exceeds `frame_time_worst_ms` (33 ms)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-64 [P]** (P-15) (nothing compiles in play) In a windowed release export on the development PC, after Boot's warm-up, from a freshly launched export with an empty shader cache:
  - the scripted state cycle (each mode's entry; Battle, every faction's boss takeover, Victory and Defeat; Camp; Menu open and close) leaves every `Performance.PIPELINE_COMPILATIONS_*` counter unchanged;
  - no frame exceeds 33 ms (`performance.frame_time_worst_ms`).

  A fixture preset that switches an un-warmed feature makes the counters rise, as a negative control.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This builds the P-15 benchmark harness: a windowed release export, an empty-cache launch (the harness deletes the Vulkan pipeline cache and `.godot/shader_cache/` first), a scripted cycle through every mode entry, both factions' boss takeovers, Victory, Defeat, Camp and a Menu open/close, with `RenderingServer.viewport_set_measure_render_time` on throughout.
- The five `Performance.PIPELINE_COMPILATIONS_*` monitors (canvas, mesh, surface, draw, specialization) are read before and after the cycle; the cycle must leave every one of them unchanged, proving Boot's warm-up (§11) already covered every combination the cycle visits.
- The frame-time spike guard is a second, independent check over the same run: no frame exceeds 33 ms. It exists because some post-effect pipelines (glow, tonemapper switches) left the counters at 0 on 4.7.2 even though they compiled something — the spike guard is the backstop for whatever the counters can't see.
- The required negative control is a fixture preset that deliberately switches to an un-warmed combination; it must make at least one counter rise, proving the measurement actually discriminates rather than always reading zero.
- The benchmark record (P-mm, device, counters before/after, worst frame time, which driver caches were present) is retained, not just a pass/fail flag.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-051-rendering-constraints.md`: the project-settings half this measurement assumes is already correct
- Boot's warm-up stage itself (built by an earlier `src/presentation/`/`src/boot/` story) — this story only measures its effect

---

## Files

- `tools/capture/pipeline_compile_benchmark.gd`
- `production/qa/benchmarks/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- A retained benchmark record in `production/qa/benchmarks/` (counters before/after, worst frame time, negative-control result) — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-*.md` (the spike confirms the compiling-parameter list and cache file locations); `production/epics/sprite-camera-presentation/story-051-rendering-constraints.md` (the project settings this measurement assumes)
- Unlocks: None
