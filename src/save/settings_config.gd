## Where settings live and how they map onto the systems that read them
## (ADR-0009 §7). Defaults here; no .tres needed.
class_name SettingsConfig
extends Resource

## The one settings file (machine-wide, never per slot).
@export var path: String = "user://settings.json"
## Files larger than this are refused before parsing.
@export var max_file_bytes: int = 64 * 1024
## Changes are written this long after the last one (real seconds).
@export var write_delay_s: float = 0.5
## Text speed -> dialogue typewriter characters per second (0 = instant).
@export var text_speed_cps: Dictionary[String, float] = {
	"slow": 25.0,
	"normal": 45.0,
	"fast": 90.0,
	"instant": 0.0,
}
## Volume key -> audio bus name.
@export var volume_buses: Dictionary[String, String] = {
	"master_volume": "Master",
	"music_volume": "Music",
	"sfx_volume": "SFX",
}
