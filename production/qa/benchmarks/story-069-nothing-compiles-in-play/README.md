# Benchmark: Story 069, nothing compiles a rendering pipeline in play (P-15, AC-64)

Story: `production/epics/sprite-camera-presentation/story-069-nothing-compiles-in-play.md`
Record: `measurements.json` (this folder). Date: 2026-11-03. Engine 4.7.2 editor binary (`Godot_v4.7.2-stable_win64_console.exe`), Vulkan Forward+, RTX 4080 SUPER, windowed 1280x720.

```
godot --headless --path . -s res://tools/capture/pipeline_compile_benchmark.gd -- --empty-cache --out=res://production/qa/benchmarks/story-069-nothing-compiles-in-play/
```

**Verdict: PASS on the editor binary.** The AC's target is a windowed **release export**. There is no export preset yet, so that run is still owed (see Open).

## Result

| Check | Result |
|---|---|
| Empty-cache launch | The Vulkan pipeline cache and both compiled-shader caches were deleted before the measured run. Driver caches were not cleared; `driver_caches_present` records which ones existed. |
| Boot warm-up | 9 profiles, 3.61 s. Counters after Boot: canvas 2, surface 8, specialization 6. |
| Scripted cycle: every `PIPELINE_COMPILATIONS_*` delta | canvas 0, mesh 0, surface 0, draw 0, specialization **0**. PASS |
| Worst render frame (CPU+GPU, the 33 ms guard) | 8.86 ms. PASS |
| Negative control (un-warmed Environment preset and material, live Overworld) | surface **+9**, specialization **+7**: the counters rise as required. PASS |
| Flow errors | 0 |

Stability: three consecutive runs after the fixes below all passed (worst render 2.89, 9.07 and 8.86 ms).

## What the first runs found, and the fixes

1. **The boss Defeat compiled one pipeline in play** (`boss_bureaucratia_defeat`: specialization +1). The warm-up lit the Defeat spotlight under one profile and never played a Defeat. Lighting the spotlight under every profile was not enough on its own. `PipelineWarmup` now also loses each warm-up battle at speed (`_play_defeat`): the squad's knockouts, the blend to `defeat` and the spotlight, as in play. It does this without `DebugLaunchArgs`' debug-build gate, and the shared warm-up squad's HP is restored afterwards. Cost: Boot's warm-up went from 2.4 s to 3.6 s.
2. **Intermittent flow cascade (15 flow errors).** The game opens the Menu by itself when its window loses focus (story 026). A focus change mid-run froze a battle under that Menu, and every later step failed. A measured run that depended on window focus could not be trusted, so the benchmark now unbinds the machine's input source (`_unbind_action_source()`). The script drives every step itself, including its own Menu opens and closes.

## Observations (not part of the AC's verdict)

- **Wall-clock frames over 33 ms at scene swaps:** `battle_entry` 54 ms, `boss_bureaucratia_takeover` 52 ms, `boss_megacorp_takeover` 42 ms. These are the Battle scene being instantiated during the transition's SWAP, while the screen is covered. Render time in the same steps stays under 9 ms and the compile counters do not move. This is a loading hitch, not a pipeline compile. The 880 ms frame in the record is under `negative_control.parts.material_fixture`: the control's deliberate compile, outside the cycle.
- The Menu has no scene yet (`overlay_scene_path_missing` for kind 1). Menu open and close are therefore measured as the mode-time freeze, with no panel drawn.

## Open

- **Release export run (the AC's target):** add an export preset, then run stage 2 against the exported binary with the same arguments (see the tool's header comment).
- Lead review of the swap-time wall-clock frames above.
