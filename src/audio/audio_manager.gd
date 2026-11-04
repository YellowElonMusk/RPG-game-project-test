## The Audio Manager (systems index #20): music with crossfades, one ambience
## bed and pooled SFX, all looked up by id in an `AudioEventTable`. Music and
## ambience play on the `Music` bus and SFX on the `SFX` bus, the buses the
## Settings volumes drive (`SettingsViews.apply_audio`). An id with no file
## plays nothing and is logged once; nothing here ever errors on a missing
## asset.
##
## `GameRoot` builds one under `Services` and routes contexts to it; modes
## get it injected (never an autoload).
##
## Usage example:
## [codeblock]
## var audio := AudioManager.new()
## add_child(audio)
## audio.setup(AudioEventTable.load_default())
## audio.play_music([&"mus_paris_town", &"mus_ow_town"])
## audio.play_sfx(&"ui_confirm")
## [/codeblock]
class_name AudioManager
extends Node

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Silence, in dB, at either end of a fade.
const SILENT_DB: float = -60.0
## Simultaneous one-shots before the oldest is cut.
const SFX_VOICES: int = 8
## The same SFX id is not restarted within this many seconds (text blips,
## mashed presses).
const SFX_REPEAT_GAP_S: float = 0.03

## The beatbox battle score's seam (design/gdd/beatbox-battle-score.md, not
## built): `(EncounterDescriptor) -> bool`. When set and it returns true it
## owns the fight's music; otherwise the floor pulse placeholder plays.
var battle_music_provider: Callable = Callable()
## Picks the battle track (seed it in tests).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## The music id playing (or fading in), &"" for none.
var current_music_id: StringName = &""
## The ambience id playing, &"" for none.
var current_ambience_id: StringName = &""
## Every SFX id played, in order (tests and the headless play log).
var sfx_log: Array[StringName] = []
## Ids that resolved to no file, each logged once.
var missing_ids: Array[String] = []

var _table: AudioEventTable = AudioEventTable.new()
var _exists: Callable = Callable(ResourceLoader, &"exists")
var _load: Callable = Callable()
var _streams: Dictionary[String, AudioStream] = {}
## Two music players: `_music_in` fades up, `_music_out` fades down.
var _music_in: AudioStreamPlayer = null
var _music_out: AudioStreamPlayer = null
var _fade_left: float = 0.0
## The full volume each music player fades to/from (battle tracks carry
## `battle_music_db`, everything else `music_db`).
var _music_in_db: float = 0.0
var _music_out_db: float = 0.0
var _ambience: AudioStreamPlayer = null
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _clock: float = 0.0
var _last_played: Dictionary[StringName, float] = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load = AudioManager._load_stream
	_music_in = _player(MUSIC_BUS)
	_music_out = _player(MUSIC_BUS)
	_ambience = _player(MUSIC_BUS)
	for i: int in SFX_VOICES:
		_sfx.append(_player(SFX_BUS))


## `exists` is `(String) -> bool` and `load` is `(String) -> AudioStream`;
## tests pass fakes, production keeps `ResourceLoader`.
func setup(table: AudioEventTable, exists: Callable = Callable(), load: Callable = Callable()) -> void:
	_table = table if table != null else AudioEventTable.new()
	if exists.is_valid():
		_exists = exists
	if load.is_valid():
		_load = load


func _process(delta: float) -> void:
	advance(delta)


## Advances the crossfade and the SFX repeat clock (tests call it by hand).
func advance(delta: float) -> void:
	_clock += delta
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(0.0, _fade_left - delta)
	var t: float = 1.0 - (_fade_left / maxf(_table.crossfade_s, 0.001))
	_music_in.volume_db = lerpf(SILENT_DB, _music_in_db, t)
	_music_out.volume_db = lerpf(_music_out_db, SILENT_DB, t)
	if _fade_left <= 0.0:
		_music_out.stop()
		_music_out.stream = null


## True while a crossfade runs.
func is_fading() -> bool:
	return _fade_left > 0.0


## The incoming music player's volume (tests).
func music_volume_db() -> float:
	return _music_in.volume_db


## Plays the first id in `ids` that has a file, crossfading from the current
## track. The id already playing is left alone. No id with a file: the
## current track fades out. Stings (`stg_`) play once; the rest loop.
func play_music(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var stream: AudioStream = _stream(AudioEventTable.Kind.MUSIC, id)
		if stream == null:
			continue
		if id == current_music_id and _music_in.playing:
			return
		_crossfade_to(id, stream)
		return
	stop_music()


## Fades the current track out.
func stop_music() -> void:
	if current_music_id == &"" and not _music_in.playing:
		return
	_crossfade_to(&"", null)


## Starts the ambience bed `id` (&"" stops it). A missing bed is silent.
func play_ambience(id: StringName) -> void:
	if id == current_ambience_id and (id == &"" or _ambience.playing):
		return
	current_ambience_id = id
	_ambience.stop()
	var stream: AudioStream = null if id == &"" else _stream(AudioEventTable.Kind.AMBIENCE, id)
	if stream == null:
		return
	_ambience.stream = _looped(stream)
	_ambience.volume_db = _table.ambience_db
	_ambience.play()


## Plays the one-shot `id` on a free voice (the oldest is cut when all are
## busy). Missing ids are silent.
func play_sfx(id: StringName) -> void:
	if id == &"":
		return
	if _last_played.has(id) and _clock - _last_played[id] < SFX_REPEAT_GAP_S:
		return
	_last_played[id] = _clock
	sfx_log.append(id)
	var stream: AudioStream = _stream(AudioEventTable.Kind.SFX, id)
	if stream == null:
		return
	var voice: AudioStreamPlayer = _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	voice.stream = stream
	voice.volume_db = _table.sfx_db
	voice.play()


## Battle music for `descriptor`: the beatbox score when its provider takes
## it, else a random track from `battle_music_dir`, else the floor pulse.
func play_battle_music(descriptor: EncounterDescriptor) -> void:
	if battle_music_provider.is_valid() and bool(battle_music_provider.call(descriptor)):
		current_music_id = &"beatbox"
		return
	var tracks: PackedStringArray = battle_tracks()
	if not tracks.is_empty():
		var path: String = tracks[rng.randi_range(0, tracks.size() - 1)]
		var stream: AudioStream = _battle_stream(path)
		if stream != null:
			_crossfade_to(StringName("battle:" + path.get_file()), stream)
			return
	play_music([AudioIds.BX_FLOOR_PULSE])


## The battle tracks in the table's `battle_music_dir`, sorted (so a seeded
## `rng` picks the same one every run).
func battle_tracks() -> PackedStringArray:
	var out := PackedStringArray()
	if _table.battle_music_dir.is_empty() or not DirAccess.dir_exists_absolute(_table.battle_music_dir):
		return out
	for file: String in DirAccess.get_files_at(_table.battle_music_dir):
		if file.get_extension().to_lower() in ["mp3", "ogg", "wav"]:
			out.append(_table.battle_music_dir.path_join(file))
	out.sort()
	return out


## Loads a battle track. MP3s are read straight from disk, so a dropped-in
## file plays without an editor import; anything else goes through `_load`.
func _battle_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if path.get_extension().to_lower() == "mp3":
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			stream = mp3
	else:
		stream = _load.call(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: could not load battle track '%s'" % path)
	_streams[path] = stream
	return stream


## The bus a player of each column uses (tests check the routing).
func bus_of(kind: AudioEventTable.Kind) -> StringName:
	match kind:
		AudioEventTable.Kind.SFX:
			return _sfx[0].bus
		AudioEventTable.Kind.AMBIENCE:
			return _ambience.bus
	return _music_in.bus


## The stream `id` resolves to, cached; null (logged once) when no listed
## file exists.
func _stream(kind: AudioEventTable.Kind, id: StringName) -> AudioStream:
	var key: String = "%d:%s" % [kind, id]
	if _streams.has(key):
		return _streams[key]
	var path: String = _table.resolve(kind, id, _exists)
	var stream: AudioStream = null
	if not path.is_empty():
		stream = _load.call(path) as AudioStream
	if stream == null and not key in missing_ids:
		missing_ids.append(key)
		push_warning("AudioManager: no file for %s id '%s'" % [AudioEventTable.Kind.keys()[kind], id])
	_streams[key] = stream
	return stream


func _crossfade_to(id: StringName, stream: AudioStream) -> void:
	# The outgoing player takes the current track from wherever its fade is.
	var swap: AudioStreamPlayer = _music_out
	_music_out = _music_in
	_music_in = swap
	_music_in.stop()
	_music_out_db = _music_in_db
	_music_in_db = _table.battle_music_db if String(id).begins_with("battle:") else _table.music_db
	current_music_id = id
	if stream != null:
		_music_in.stream = stream if AudioEventTable.is_sting(id) else _looped(stream)
		_music_in.volume_db = SILENT_DB
		_music_in.play()
	else:
		_music_in.stream = null
	_fade_left = _table.crossfade_s
	if _fade_left <= 0.0:
		_fade_left = 0.0001


## `stream` set to loop whole: a WAV loops its full length, an OGG/MP3
## sets its own `loop`.
static func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in stream:
		stream.set("loop", true)
	return stream


static func _load_stream(path: String) -> AudioStream:
	return ResourceLoader.load(path) as AudioStream


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p
