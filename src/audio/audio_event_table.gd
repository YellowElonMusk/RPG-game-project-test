## The Audio Manager's data table (systems index #20): every music, ambience
## and SFX id mapped to an ordered list of candidate files. The first file
## that exists wins, so a real asset listed ahead of its placeholder replaces
## it the moment it is dropped into `res://assets/audio/` -- no code or data
## change. An id with no existing file plays nothing (the manager logs it
## once).
##
## Usage example:
## [codeblock]
## var table: AudioEventTable = AudioEventTable.load_default()
## var path: String = table.resolve(AudioEventTable.Kind.SFX, &"ui_confirm", ResourceLoader.exists)
## [/codeblock]
class_name AudioEventTable
extends Resource

## Which column an id lives in; each plays on its own player(s) and bus.
enum Kind { MUSIC, AMBIENCE, SFX }

const DEFAULT_PATH: String = "res://data/config/audio_events.tres"

## Looping tracks and one-shot stings, on the Music bus. A `stg_` id plays
## once; every other music id loops.
@export var music: Dictionary[String, PackedStringArray] = {}
## Looping beds under the music (occupation stages' `ambience_bed_id`), on
## the Music bus at `ambience_db`.
@export var ambience: Dictionary[String, PackedStringArray] = {}
## One-shots on the SFX bus.
@export var sfx: Dictionary[String, PackedStringArray] = {}
## Mix offsets in dB per column (the assets carry their own loudness).
@export var music_db: float = 0.0
@export var ambience_db: float = -6.0
@export var sfx_db: float = 0.0
## Music crossfade length in seconds.
@export var crossfade_s: float = 0.8


## The table at `DEFAULT_PATH`, or an empty one when it is missing.
static func load_default() -> AudioEventTable:
	if ResourceLoader.exists(DEFAULT_PATH):
		var table: AudioEventTable = ResourceLoader.load(DEFAULT_PATH) as AudioEventTable
		if table != null:
			return table
	return AudioEventTable.new()


## The column for `kind`.
func column(kind: Kind) -> Dictionary[String, PackedStringArray]:
	match kind:
		Kind.MUSIC:
			return music
		Kind.AMBIENCE:
			return ambience
	return sfx


## True if `id` is listed under `kind` (whether or not a file exists).
func has_id(kind: Kind, id: StringName) -> bool:
	return column(kind).has(String(id))


## The listed candidate paths for `id`, in order (empty when unlisted).
func candidates(kind: Kind, id: StringName) -> PackedStringArray:
	return column(kind).get(String(id), PackedStringArray())


## The first candidate `exists` accepts, or "" (`exists` is `(String) ->
## bool`, `ResourceLoader.exists` in production; tests pass a fake).
func resolve(kind: Kind, id: StringName, exists: Callable) -> String:
	for path: String in candidates(kind, id):
		if bool(exists.call(path)):
			return path
	return ""


## True if a `music` id is a one-shot sting rather than a loop.
static func is_sting(id: StringName) -> bool:
	return String(id).begins_with("stg_")
