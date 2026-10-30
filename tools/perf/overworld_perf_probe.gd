## Story 133 (TR-overworld-005, test plan O-08 / OW-T01): the per-frame
## `step_symbols()` timer, its live `Performance` custom monitor and the
## per-run CSV logger. Emits observations only -- the p99 against the
## 2.0 ms budget is read by story 114, never judged here.
##
## Usage example:
## [codeblock]
## var probe := OverworldPerfProbe.new()
## probe.attach(mode)            # OverworldMode.step_timer -> record_step
## probe.register_monitor()      # Debugger > Monitors > overworld/overworld_ms
## # ... run the window ...
## probe.write_csv(OverworldPerfProbe.csv_path("case_a"))
## probe.unregister_monitor()
## [/codeblock]
class_name OverworldPerfProbe
extends RefCounted

## The custom monitor's ID (shown under "overworld" in the debugger).
const MONITOR_ID: StringName = &"overworld/overworld_ms"
## Where run CSVs go (story 133 Implementation Notes).
const CSV_DIR: String = "res://production/qa/evidence/perf"
## CSV header row.
const CSV_HEADER: String = "frame,frame_ms,overworld_ms"

## Returns the current frame time in ms. Default: the engine's process
## time; tests inject a fixed source.
var frame_ms_source: Callable = _engine_frame_ms
## Per-frame frame time, ms (one entry per recorded step).
var frame_ms: PackedFloat64Array = PackedFloat64Array()
## Per-frame symbol-step time, ms.
var overworld_ms: PackedFloat64Array = PackedFloat64Array()
## The last recorded `overworld_ms` (what the monitor shows).
var last_overworld_ms: float = 0.0


## Hooks this probe onto `mode`'s symbol-step timer.
func attach(mode: OverworldMode) -> void:
	mode.step_timer = record_step


## Removes the hook from `mode`.
func detach(mode: OverworldMode) -> void:
	mode.step_timer = Callable()


## One frame's symbol-step duration in microseconds (from
## `Time.get_ticks_usec()`): appends a CSV row.
func record_step(usec: int) -> void:
	last_overworld_ms = float(usec) / 1000.0
	overworld_ms.append(last_overworld_ms)
	frame_ms.append(float(frame_ms_source.call()))


## The monitor's value source.
func get_overworld_ms() -> float:
	return last_overworld_ms


## Adds the `overworld_ms` custom monitor (replacing a stale one).
func register_monitor() -> void:
	unregister_monitor()
	Performance.add_custom_monitor(MONITOR_ID, get_overworld_ms)


## Removes the custom monitor if present.
func unregister_monitor() -> void:
	if Performance.has_custom_monitor(MONITOR_ID):
		Performance.remove_custom_monitor(MONITOR_ID)


## Frames recorded.
func frame_count() -> int:
	return overworld_ms.size()


## The `q` quantile (0-1, nearest rank) of `overworld_ms`; 0 when empty.
## An observation for the report, not a verdict.
func quantile_ms(q: float) -> float:
	if overworld_ms.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = overworld_ms.duplicate()
	sorted.sort()
	var rank: int = clampi(ceili(q * sorted.size()) - 1, 0, sorted.size() - 1)
	return sorted[rank]


## The CSV text: header, then `frame,frame_ms,overworld_ms` per frame.
func to_csv() -> String:
	var lines := PackedStringArray([CSV_HEADER])
	for i: int in overworld_ms.size():
		lines.append("%d,%.4f,%.4f" % [i, frame_ms[i], overworld_ms[i]])
	return "\n".join(lines) + "\n"


## Writes the CSV to `path`, creating its folder. Returns the error.
func write_csv(path: String) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_csv())
	file.close()
	return OK


## `<dir>/overworld_<run_tag>.csv`.
static func csv_path(run_tag: String, dir: String = CSV_DIR) -> String:
	return dir.path_join("overworld_%s.csv" % run_tag)


func _engine_frame_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
