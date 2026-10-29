# Story 035: the battle benchmark holds its frame-time and draw-call budget on both target devices

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: On a GTX 1080-class desktop at 1920×1080 and on Steam Deck at 1280×800, a scripted battle (8 actors, a boss takeover restarted every 2.0 s, vsync off, 5 runs of 600 frames after a 120-frame warm-up) must hold p99 frame time at or below 16.6 ms and no frame over 33 ms, with 3D draw calls at or below 300 and canvas draw calls at or below 100 on every measured frame; a failure on either device fails the criterion.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Draw-call and frame-time counters (`RenderingServer.viewport_set_measure_render_time`, `Performance` monitors) are used elsewhere in this ADR (§11) and are probed on 4.7.2. The Steam Deck run must be a **native Linux export**, never the Windows build under Proton (ADR-0005 §10) — this is a hard constraint on how the benchmark harness is built, not an optional convenience.

**Control Manifest Rules (this layer)**:
- Guardrail: "Battle draw calls: at most **300** for all 3D passes (including `SetLight`'s shadow cascades) plus at most **100** for canvas/HUD (400 total, counted separately)" (Performance Guardrails, ADR-0005, `project.yaml` `performance.draw_call_limit`).
- Guardrail: "Frame time: p99 ≤ **16.6 ms**, worst ≤ **33 ms** over a scripted battle, on a GTX 1080-class desktop at 1920×1080 and on Steam Deck at 1280×800" (Performance Guardrails, ADR-0005, `project.yaml`).
- Required: "The Steam Deck build is a native Linux export (Godot's `Linux` preset, x86_64), never the Windows build under Proton" (Backend, output and AA, ADR-0005 §10).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-31 [P]** (P-14) On each binding device, a GTX 1080-class desktop (8 GB RAM) at 1920×1080 and a Steam Deck at 1280×800 (native Linux export), in a windowed release export, the battle benchmark (8 actors, a boss takeover restarted every 2.0 s of mode time, vsync off, 5 runs of 600 frames after a 120-frame warm-up) meets these: the 99th-percentile frame time over all runs is at most 16.6 ms (`performance.frame_time_p99_ms`); no frame in any run exceeds 33 ms (`performance.frame_time_worst_ms`); on every measured frame, 3D draw calls stay at or below 300 and canvas draw calls at or below 100, counted separately (`battle_draw_call_budget`). A failure on either device fails the criterion. A 3840×2160 run on the desktop is measured and reported, but doesn't gate. Peak RAM and VRAM are reported so a memory ceiling can be set.

---

## Implementation Notes

*Derived from ADR-0005 Performance Implications and §11 (the measured contract):*

- The benchmark harness is the same family of tooling as the compile-contract measurement (§11): it scripts a battle through 5 runs of 600 frames after a 120-frame warm-up, with vsync off, restarting the boss takeover every 2.0 s of mode time to keep the scene representative of its most expensive state.
- Draw calls are counted separately for 3D (including `SetLight`'s shadow cascades — the only shadow-casting light) and canvas/HUD, matching `project.yaml`'s `performance.draw_call_limit` split (300 + 100 = 400 total, never summed before the check).
- 2160p is measured and reported on the desktop target but does **not** gate — the harness must still run and record it, but a regression there alone does not fail this story.
- Peak RAM and VRAM are reported, not gated (`performance.memory_ceiling_mb` is unset in `project.yaml` — ADR-0005 Performance Implications explicitly defers setting a ceiling until this data exists).
- A failure on **either** device fails the whole criterion — the harness must run both configurations in the same story's evidence, not ship a desktop-only pass as sufficient.
- This benchmark exercises the real `battle_fov`, `h_cam`, slot depths and `humanoid_height_px` the spike settles — it cannot be meaningfully run before those values exist.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-039-texel-scale-holds-across-resolutions.md`: the texel-grid correctness this benchmark's frames are rendered at (a different, non-performance AC).
- The compile-contract measurement itself (AC-64, a separate story outside this writer's range) — this story only needs that no pipeline compiles mid-benchmark, not to prove it from scratch.
- Setting `performance.memory_ceiling_mb` (deferred; this story only reports the numbers).

---

## Files

- `tools/capture/presentation_capture.gd` (benchmark harness reuses its `SubViewport` setup)
- `tests/integration/presentation/battle_performance_benchmark.gd`
- `production/qa/benchmarks/sprite-camera-presentation-p14.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/battle_performance_benchmark.gd` OR playtest doc; plus the retained benchmark record in `production/qa/benchmarks/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-001-windowed-engine-spike.md` (settles `battle_fov`, slot depths and `humanoid_height_px`, including the Steam Deck native-export run); boss stages (content, not yet authored); the full battle stage (presentation director, diorama stage, character sprites) existing end to end
- Unlocks: None
