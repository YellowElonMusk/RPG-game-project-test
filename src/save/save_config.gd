## Save/Load knobs (ADR-0009 §1, §4). The Save/Load GDD (not yet written)
## owns the final values; these are the ADR's defaults.
class_name SaveConfig
extends Resource

## Where slot files live.
@export var save_dir: String = "user://saves"
## Number of slots (`slot_<n>.json`, n in 1..slot_count).
@export var slot_count: int = 3
## Files larger than this are refused before parsing (4 MiB).
@export var max_file_bytes: int = 4 * 1024 * 1024
## The build written into each save (shown in bug reports).
@export var game_version: String = "0.1.0"
