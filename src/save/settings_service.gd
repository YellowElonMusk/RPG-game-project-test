## The player's settings (ADR-0009 §7): one JSON file, validated field by
## field against `SettingsSchema`, written a moment after the last change
## and flushed on quit, window close and focus loss. Knows no consumer:
## `SettingsViews` (composition root) turns `value_changed` into each
## system's own view.
##
## Usage example:
## [codeblock]
## var settings := SettingsService.new()
## services.add_child(settings)
## settings.setup(SaveFileSystem.new(), SettingsConfig.new(), SettingsSchema.new(),
##         func() -> float: return Time.get_ticks_msec() / 1000.0)
## settings.set_value(&"text_speed", "fast")
## [/codeblock]
class_name SettingsService
extends Node

const FORMAT: String = "gbtyp_settings"
const FORMAT_VERSION: int = 1

## A setting changed (after validation).
signal value_changed(key: StringName)

var _fs: SaveFileSystem = null
var _config: SettingsConfig = null
var _schema: SettingsSchema = null
var _clock: Callable
var _values: Dictionary[StringName, Variant] = {}
var _dirty: bool = false
var _dirty_at: float = 0.0
## Fields that failed validation on load (key names), for tests and logs.
var rejected_on_load: PackedStringArray = []


func setup(fs: SaveFileSystem, config: SettingsConfig, schema: SettingsSchema, real_clock: Callable) -> void:
	_fs = fs
	_config = config
	_schema = schema
	_clock = real_clock
	_load()


func get_value(key: StringName) -> Variant:
	return _values.get(key, _schema.default_of(key) if _schema.has_key(key) else null)


## Validates and stores `value`; false (and no change) when it is illegal.
## Emits `value_changed` and schedules a write when the value differs.
func set_value(key: StringName, value: Variant) -> bool:
	var v: Variant = _schema.coerce(key, value)
	if v == null:
		return false
	if _values.get(key) == v:
		return true
	_values[key] = v
	_dirty = true
	_dirty_at = _now()
	value_changed.emit(key)
	return true


## True when a change has not been written yet.
func is_dirty() -> bool:
	return _dirty


## Writes now if anything changed (temp file, verify, rename).
func flush() -> void:
	if not _dirty or _fs == null:
		return
	var body: Dictionary = {}
	for key: StringName in _values:
		body[String(key)] = _values[key]
	var text: String = JSON.stringify({"format": FORMAT, "version": FORMAT_VERSION, "body": body}, "\t")
	var temp: String = _config.path + ".tmp"
	if not _fs.write_text(temp, text) or _fs.read_text(temp, _config.max_file_bytes) != text \
			or not _fs.rename(temp, _config.path):
		push_warning("SettingsService: could not write %s" % _config.path)
		return
	_dirty = false


func _process(_delta: float) -> void:
	if _dirty and _now() - _dirty_at >= _config.write_delay_s:
		flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_PREDELETE:
		if _config != null:
			flush()


func _load() -> void:
	_values.clear()
	rejected_on_load.clear()
	for key: StringName in _schema.keys():
		_values[key] = _schema.default_of(key)
	var text: Variant = _fs.read_text(_config.path, _config.max_file_bytes) if _fs.exists(_config.path) else null
	if not (text is String):
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or parsed.get("format") != FORMAT or not (parsed.get("body") is Dictionary):
		push_warning("SettingsService: %s is not a settings file; using defaults" % _config.path)
		return
	var body: Dictionary = parsed["body"]
	for raw_key: Variant in body:
		var key := StringName(str(raw_key))
		if not _schema.has_key(key):
			continue
		var v: Variant = _schema.coerce(key, body[raw_key])
		if v == null:
			rejected_on_load.append(String(key))
			push_warning("SettingsService: %s has an invalid value; using the default" % key)
			continue
		_values[key] = v


func _now() -> float:
	return float(_clock.call()) if _clock.is_valid() else 0.0
