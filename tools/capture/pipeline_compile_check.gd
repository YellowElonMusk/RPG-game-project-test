## AC-64 (story sprite-camera-presentation 069, TR-presentation-016; ADR-0005
## §11): nothing compiles a rendering pipeline in play. Pure, headless-testable
## pieces of the check; `pipeline_compile_benchmark.gd` drives the windowed run.
##
## The contract, per run: the five `Performance.PIPELINE_COMPILATIONS_*`
## monitors read before and after the scripted state cycle are unchanged, no
## frame of the cycle exceeds `frame_time_worst_ms` (the backstop for
## post-effect pipelines the counters don't see), and the negative control (an
## un-warmed feature switched on after the cycle) is caught by a counter or by
## the spike guard, so the measurement is shown to discriminate.
##
## Usage example:
## [codeblock]
## var before: Dictionary = PipelineCompileCheck.read_counters()
## # ... the scripted state cycle ...
## var cycle: Dictionary = PipelineCompileCheck.delta(before, PipelineCompileCheck.read_counters())
## var v: Dictionary = PipelineCompileCheck.verdict(cycle, frame_ms, 33.0, control_delta, control_worst_ms)
## print(v["pass"])
## [/codeblock]
class_name PipelineCompileCheck
extends RefCounted

## Counter name -> `Performance` monitor (all five probed on 4.7.2: 34..38).
const MONITORS: Dictionary = {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

## The engine's Vulkan pipeline cache lives in `user://vulkan/` as
## `pipelines.<renderer>.<device>[.editor].cache` (confirmed on 4.7.2,
## RTX 4080 SUPER, 2026-10-31).
const PIPELINE_CACHE_DIR: String = "user://vulkan"
## The engine's compiled-shader caches: the project's (development runs) and
## the user-data one.
const SHADER_CACHE_DIRS: Array[String] = ["res://.godot/shader_cache", "user://shader_cache"]


## Every monitor's current value, as ints.
static func read_counters() -> Dictionary:
	var out: Dictionary = {}
	for k: String in MONITORS:
		out[k] = int(Performance.get_monitor(MONITORS[k]))
	return out


## `after - before` per counter.
static func delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in MONITORS:
		out[k] = int(after.get(k, 0)) - int(before.get(k, 0))
	return out


## The sum of a delta's counters.
static func total(d: Dictionary) -> int:
	var n: int = 0
	for k: String in d:
		n += int(d[k])
	return n


## The AC-64 verdict. `cycle_delta`: the counters across the cycle;
## `frame_ms`: every measured frame of the cycle; `limit_ms`:
## `frame_time_worst_ms`; `control_delta` / `control_worst_ms`: the negative
## control's counters and worst frame. A run with no measured frames never
## passes.
static func verdict(cycle_delta: Dictionary, frame_ms: PackedFloat32Array, limit_ms: float,
		control_delta: Dictionary, control_worst_ms: float) -> Dictionary:
	var worst: float = 0.0
	var over: int = 0
	for t: float in frame_ms:
		worst = maxf(worst, t)
		if t > limit_ms:
			over += 1
	var unchanged: bool = total(cycle_delta) == 0
	var no_spike: bool = not frame_ms.is_empty() and over == 0
	var discriminates: bool = total(control_delta) > 0 or control_worst_ms > limit_ms
	return {
		"cycle_unchanged": unchanged,
		"no_spike": no_spike,
		"frames_measured": frame_ms.size(),
		"frames_over_limit": over,
		"worst_frame_ms": worst,
		"limit_ms": limit_ms,
		"control_discriminates": discriminates,
		"pass": unchanged and no_spike and discriminates,
	}


## True for a file name the engine writes as its Vulkan pipeline cache.
static func is_engine_pipeline_cache(file_name: String) -> bool:
	return file_name.begins_with("pipelines.") and file_name.ends_with(".cache")
