## Save/Load (ADR-0009 §2-6): hashed two-line JSON slot files, written
## atomically, each holding one section per registered `SaveParticipant`.
## Loading is read + verify + migrate (`read_slot`), then a side-effect-free
## `preflight` that stages every participant, then `commit_if_loaded` in the
## SWAP of Title's Continue transition. Lives under `GameRoot/Services`;
## not an autoload.
##
## Settings (ADR-0009 §7-8) are a separate `SettingsService`, not built yet
## (TODO(save-load)).
##
## Usage example:
## [codeblock]
## var result := save_service.save_to_slot(1)          # at a safe moment
## var loaded := save_service.preflight(save_service.read_slot(1))
## if loaded.is_ok():
##     machine.request_transition(GameStateMachine.Mode.OVERWORLD, loaded)
## [/codeblock]
class_name SaveService
extends Node

enum SaveResult { OK, NOT_SAFE_MOMENT, CAPTURE_FAILED, WRITE_FAILED, VERIFY_FAILED, RENAME_FAILED }
enum LoadStatus { OK, EMPTY, CORRUPT, TOO_NEW, WRONG_FORMAT, TOO_LARGE, STAGE_FAILED }

const FORMAT: String = "gbtyp_save"
const FORMAT_VERSION: int = 1

var _machine: GameStateMachine = null
var _catalog: Object = null
var _fs: SaveFileSystem = null
var _config: SaveConfig = null
var _participants: Array[SaveParticipant] = []
var _unix_clock: Callable = Callable()
var _playtime_s: float = 0.0
var _dirty: bool = false
## Sections of the last load no participant owns, written back on the next
## save so a downgrade-then-upgrade loses nothing (ADR-0009 §6).
var _unknown_sections: Dictionary = {}


## Wires the service. A `save_key` collision is a boot error (§3).
func setup(machine: GameStateMachine, catalog: Object, fs: SaveFileSystem, config: SaveConfig,
		participants: Array[SaveParticipant], unix_clock: Callable) -> void:
	_machine = machine
	_catalog = catalog
	_fs = fs
	_config = config
	_unix_clock = unix_clock
	_participants.clear()
	var keys: Dictionary = {}
	for p: SaveParticipant in participants:
		if keys.has(p.save_key()):
			push_error("SaveService: duplicate save_key '%s'" % p.save_key())
			continue
		keys[p.save_key()] = true
		_participants.append(p)
	_fs.ensure_dirs(_config.save_dir)


func slot_path(slot: int) -> String:
	return _config.save_dir.path_join("slot_%d.json" % slot)


func _backup_path(slot: int) -> String:
	return _config.save_dir.path_join("slot_%d.bak.json" % slot)


func _temp_path(slot: int) -> String:
	return _config.save_dir.path_join("slot_%d.tmp.json" % slot)


## Writes every participant to slot `slot` (§4-5): refused unless Game State
## says this is a safe moment; capture, stringify the body once, hash it,
## write a temp file, verify it byte for byte, keep the old file as `.bak`,
## then rename. A failure at any step leaves the previous file intact.
func save_to_slot(slot: int) -> SaveResult:
	if _machine != null and not _machine.is_save_safe():
		return SaveResult.NOT_SAFE_MOMENT
	var sections: Dictionary = {}
	var summary: Dictionary = {}
	for p: SaveParticipant in _participants:
		var data: Variant = p.capture()
		if not (data is Dictionary):
			return SaveResult.CAPTURE_FAILED
		sections[String(p.save_key())] = {"v": p.schema_version(), "data": data}
		summary.merge(p.summary_fields(), true)
	for key: String in _unknown_sections:
		if not sections.has(key):
			sections[key] = _unknown_sections[key]
	var envelope: Dictionary = {
		"game_version": _config.game_version,
		"saved_at_unix": int(_unix_clock.call()) if _unix_clock.is_valid() else 0,
		"playtime_s": _playtime_s,
		"summary": summary,
		"sections": sections,
	}
	var body: String = JSON.stringify(envelope, "", true)
	var header: String = JSON.stringify({"format": FORMAT, "version": FORMAT_VERSION,
			"body_sha256": body.sha256_text(), "body_bytes": body.to_utf8_buffer().size()}, "", true)
	var text: String = header + "\n" + body
	if not _fs.write_text(_temp_path(slot), text):
		return SaveResult.WRITE_FAILED
	var back: Variant = _fs.read_text(_temp_path(slot), _config.max_file_bytes)
	if not (back is String) or back != text:
		return SaveResult.VERIFY_FAILED
	if _fs.exists(slot_path(slot)) and not _fs.rename(slot_path(slot), _backup_path(slot)):
		return SaveResult.RENAME_FAILED
	if not _fs.rename(_temp_path(slot), slot_path(slot)):
		return SaveResult.RENAME_FAILED
	_dirty = false
	return SaveResult.OK


## Reads, verifies and migrates slot `slot` (§2, §6). No side effects. A
## missing main file falls back to its `.bak` (a crash between the renames).
func read_slot(slot: int) -> LoadedSave:
	var loaded := LoadedSave.new()
	loaded.slot = slot
	var path: String = slot_path(slot)
	if not _fs.exists(path) and _fs.exists(_backup_path(slot)):
		path = _backup_path(slot)
		loaded.from_backup = true
	if not _fs.exists(path):
		loaded.status = LoadStatus.EMPTY
		return loaded
	var text: Variant = _fs.read_text(path, _config.max_file_bytes)
	if not (text is String):
		loaded.status = LoadStatus.TOO_LARGE
		return loaded
	_decode(text as String, loaded)
	return loaded


func _decode(text: String, loaded: LoadedSave) -> void:
	var cut: int = text.find("\n")
	if cut < 0:
		loaded.status = LoadStatus.CORRUPT
		return
	var header: Variant = JSON.parse_string(text.substr(0, cut))
	if not (header is Dictionary) or header.get("format") != FORMAT:
		loaded.status = LoadStatus.WRONG_FORMAT
		return
	var version: Variant = header.get("version")
	if not (version is float or version is int):
		loaded.status = LoadStatus.WRONG_FORMAT
		return
	if int(version) > FORMAT_VERSION:
		loaded.status = LoadStatus.TOO_NEW
		return
	var body_text: String = text.substr(cut + 1)
	# The hash covers the exact body bytes written, never a re-serialization.
	if body_text.sha256_text() != String(header.get("body_sha256", "")):
		loaded.status = LoadStatus.CORRUPT
		return
	var body: Variant = JSON.parse_string(body_text)
	if not (body is Dictionary) or not (body.get("sections") is Dictionary):
		loaded.status = LoadStatus.CORRUPT
		return
	var sections: Dictionary = body["sections"]
	for key: String in sections:
		var participant: SaveParticipant = _participant(key)
		if participant == null:
			loaded.unknown_sections[key] = sections[key]
			continue
		var section: Variant = sections[key]
		if not (section is Dictionary) or not (section.get("data") is Dictionary):
			loaded.status = LoadStatus.CORRUPT
			return
		var v: int = int(section.get("v", 0))
		if v > participant.schema_version():
			loaded.status = LoadStatus.TOO_NEW
			loaded.report.append("%s: section version %d is newer than %d" % [key, v, participant.schema_version()])
			return
		loaded.sections[key] = participant.migrate(section["data"], v)
	loaded.summary = body.get("summary", {}) if body.get("summary") is Dictionary else {}
	var playtime: Variant = body.get("playtime_s", 0.0)
	loaded.playtime_s = float(playtime) if (playtime is float or playtime is int) else 0.0
	loaded.status = LoadStatus.OK


## Stages every participant against `loaded` (§6). No side effects. Any
## failed stage makes the whole load `STAGE_FAILED`; dropped fields are
## reported. A participant with no section stages from an empty one.
func preflight(loaded: LoadedSave) -> LoadedSave:
	if not loaded.is_ok():
		return loaded
	for p: SaveParticipant in _participants:
		var key: String = String(p.save_key())
		var data: Dictionary = loaded.sections.get(key, {})
		var reader := SaveReader.new(data, _catalog)
		var stage: SaveStage = p.stage(data, reader)
		for d: String in reader.dropped:
			loaded.report.append("%s: %s" % [key, d])
		if stage == null or not stage.ok:
			loaded.status = LoadStatus.STAGE_FAILED
			if stage != null:
				for e: String in stage.errors:
					loaded.report.append("%s: %s" % [key, e])
			continue
		loaded.stages[key] = stage
	return loaded


## Bound into the scene loader's save commit (ADR-0009 §6, ADR-0002
## amendment): for a preflighted `LoadedSave`, resets every participant and
## commits its stage, in registration order. Any other payload is not a
## save and passes through. Returns false only for a load that was never
## preflighted successfully.
func commit_if_loaded(payload: RefCounted) -> bool:
	if not (payload is LoadedSave):
		return true
	var loaded: LoadedSave = payload
	if not loaded.is_ok() or loaded.stages.size() != _participants.size():
		reset_all_to_new_game()
		return false
	for p: SaveParticipant in _participants:
		p.reset_to_new_game()
	for p: SaveParticipant in _participants:
		p.commit(loaded.stages[String(p.save_key())])
	_playtime_s = loaded.playtime_s
	_unknown_sections = loaded.unknown_sections.duplicate(true)
	_dirty = false
	return true


## New Game: every participant to its defaults, playtime zero.
func reset_all_to_new_game() -> void:
	for p: SaveParticipant in _participants:
		p.reset_to_new_game()
	_playtime_s = 0.0
	_unknown_sections = {}
	_dirty = false


## Fed from GameRoot with mode-time deltas (stops under the Menu).
func add_playtime(delta: float) -> void:
	_playtime_s += maxf(0.0, delta)


func playtime_s() -> float:
	return _playtime_s


## Game State's `mark_unsaved` hook, and any participant change.
func mark_unsaved() -> void:
	_dirty = true


## Whether progress has changed since the last save or load (§4).
func has_unsaved_progress() -> bool:
	return _dirty


## `true` when any slot (or its backup) exists, for Title's Continue.
func has_any_save() -> bool:
	for n: int in range(1, _config.slot_count + 1):
		if _fs.exists(slot_path(n)) or _fs.exists(_backup_path(n)):
			return true
	return false


## The lowest slot holding a save, or 0.
func latest_slot() -> int:
	for n: int in range(1, _config.slot_count + 1):
		if _fs.exists(slot_path(n)) or _fs.exists(_backup_path(n)):
			return n
	return 0


func _participant(key: String) -> SaveParticipant:
	for p: SaveParticipant in _participants:
		if String(p.save_key()) == key:
			return p
	return null
