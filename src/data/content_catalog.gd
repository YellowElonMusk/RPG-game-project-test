## The content catalog: loads every content record once at boot, validates
## the whole set, then serves immutable lookups for the rest of the session
## (Content Data GDD; ADR-0001, ADR-0004). Registered as the `ContentCatalog`
## autoload in `project.godot` — the one documented exception to
## "dependency injection over singletons". The class name is deliberately
## distinct from the autoload node name (ADR-0004).
##
## All state is set up in field initializers; `_ready()` is intentionally not
## defined because it runs after the bootstrap has already loaded (ADR-0004
## §3). The only production caller of `load_all()` is `ContentBootstrap.run()`.
## The catalog's own unit tests build a fresh instance and call `load_all()`
## on a fixture root directly.
##
## Not thread-safe: load and lookups happen on the main thread only.
##
## Usage example:
## [codeblock]
## # Production (GameRoot._enter_tree, via the bootstrap):
## ContentBootstrap.run(ContentCatalog)
## var rec: FactionData = ContentCatalog.get_record(&"faction", "faction_tech_syndicate")
##
## # A catalog unit test:
## var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
## assert_int(catalog.load_all("res://tests/unit/content_data/fixtures/valid_one_of_each")).is_equal(OK)
## [/codeblock]
class_name ContentCatalogService
extends Node

## Load lifecycle (GDD States and Transitions). READY and FAILED are terminal
## for the session.
enum State { UNLOADED, LOADING, VALIDATING, READY, FAILED }

## Record type → ID prefix and data subdirectory (GDD Rule 1 / F1; ADR-0001,
## ADR-0003 for `bindings`, ADR-0011 for `faction_rule`, ADR-0012 for the
## three overworld types). `load_all()` walks exactly these subdirectories;
## `data/config/` and `data/ui/` are never swept.
const TYPE_TABLE: Dictionary = {
	&"faction": {"prefix": "faction_", "dir": "factions"},
	&"character": {"prefix": "char_", "dir": "characters"},
	&"enemy": {"prefix": "enemy_", "dir": "enemies"},
	&"move": {"prefix": "move_", "dir": "moves"},
	&"quirk_state": {"prefix": "quirk_", "dir": "quirks"},
	&"combo": {"prefix": "combo_", "dir": "combos"},
	&"item": {"prefix": "item_", "dir": "items"},
	&"bindings": {"prefix": "bindings_", "dir": "bindings"},
	&"faction_rule": {"prefix": "rule_", "dir": "faction_rules"},
	&"map": {"prefix": "map_", "dir": "maps"},
	&"encounter": {"prefix": "enc_", "dir": "encounters"},
	&"occupation_stage": {"prefix": "ostage_", "dir": "occupation_stages"},
}

## Current load state. Starts UNLOADED; only `load_all()` changes it.
var state: State = State.UNLOADED

## Outcome of the most recent lookup: `&""` after a success, otherwise
## `&"not_ready"`, `&"unknown_type"` or `&"missing_id"`. A failing lookup also
## returns the type's empty value and calls `push_error()`.
var last_lookup_error: StringName = &""

## The validation report, one entry per problem, in the GDD's Entry shape:
## `severity` (`&"error"` / `&"warning"`), `record_id`, `field` (`&""` when
## the whole record is at fault), `location` `{file_path, record_index}`,
## `message`, `related_locations` (empty unless the problem spans places).
## Tests assert on the structured fields, never on `message`.
var report: Array[Dictionary] = []

## Test seam only: production code never sets this. When it is a valid
## (non-empty) `Callable`, `load_all()` passes each type directory's file
## listing (a `PackedStringArray` of `.tres` paths) through it and loads the
## files in the returned order instead of discovery order. It exists because
## load-order independence cannot be exercised any other way: filename must
## equal `id` (a rename is a validation error) and the filesystem listing order
## is not controllable. The transform must be a fixed permutation, never a
## seeded shuffle (Determinism rule, coding-standards). Default: an empty
## `Callable()`, which is never called.
## Example: [code]catalog.discovery_order_transform = func(listing: PackedStringArray) -> PackedStringArray:
##     var reversed := listing.duplicate()
##     reversed.reverse()
##     return reversed[/code]
var discovery_order_transform: Callable = Callable()

# type StringName → { id String → Resource }. Records are the shared, cached
# instances; lookups hand out duplicate_deep() copies. load_all() rebuilds
# each bucket keyed in ascending-id order once the type is fully loaded, so
# iterating a bucket yields ids sorted without any per-lookup sort.
var _records: Dictionary = {}
# alias String → live id String (one hop, GDD Rule 2).
var _aliases: Dictionary[String, String] = {}
# type StringName → Array of Callable(record) -> Array[Dictionary].
var _validators: Dictionary = {}
# system StringName → PackedStringArray of known EffectDescriptor types.
var _known_effect_types: Dictionary = {}


## Registers the EffectDescriptor `type` vocabulary an owning system
## interprets (ADR-0001 Rule 4; ADR-0004 §4). Must be called before
## `load_all()` starts; a later call is rejected with `push_error()`.
## Example: [code]catalog.register_known_effect_types(&"turn_battle", PackedStringArray(["stun", "heal_party"]))[/code]
func register_known_effect_types(system: StringName, types: PackedStringArray) -> void:
	if state != State.UNLOADED:
		push_error("ContentCatalog.register_known_effect_types(%s): rejected, load_all() has already started." % system)
		return
	_known_effect_types[system] = types


## Registers a pure per-record validator for `type` (ADR-0004 §4). The
## callable receives the loaded record and returns `Array[Dictionary]` entries
## with `severity`, `field`, `message` and optional `related_locations`; the
## catalog fills `record_id` and `location` and appends them to `report`. An
## empty array means valid. Must be called before `load_all()` starts; a later
## call is rejected with `push_error()`.
## Example: [code]catalog.register_record_validator(&"bindings", InputBindingsValidator.validate)[/code]
func register_record_validator(type: StringName, validator: Callable) -> void:
	if state != State.UNLOADED:
		push_error("ContentCatalog.register_record_validator(%s): rejected, load_all() has already started." % type)
		return
	if not _validators.has(type):
		_validators[type] = []
	(_validators[type] as Array).append(validator)


## Loads every record under `data_root`'s type subdirectories (TYPE_TABLE),
## runs validation over the complete set, and settles in READY or FAILED.
## Returns `OK` on READY, `FAILED` on FAILED, and `ERR_ALREADY_IN_USE`
## (changing nothing) on any call after the first. Never fails fast: every
## problem is collected into `report`. A missing type directory is not an
## error. Only `ContentBootstrap.run()` calls this in production; the
## catalog's own unit tests call it on a fixture root.
## Example: [code]var err: Error = catalog.load_all("res://tests/unit/content_data/fixtures/valid_one_of_each")[/code]
func load_all(data_root: String = "res://data") -> Error:
	if state != State.UNLOADED:
		return ERR_ALREADY_IN_USE
	state = State.LOADING

	for type: StringName in TYPE_TABLE:
		var bucket: Dictionary = {}
		var type_dir: String = data_root.path_join(TYPE_TABLE[type]["dir"])
		var listing: PackedStringArray = _discover_tres_files(type_dir)
		if discovery_order_transform.is_valid():
			listing = discovery_order_transform.call(listing)
		for file_path: String in listing:
			_load_one(type, file_path, bucket)

		# Sort once per type here, never per lookup (TR-content-004; ADR-0001
		# Rule 9). String `<` is a case-sensitive ordinal comparison, so the
		# order is the same on every platform and never depends on the
		# listing order above.
		var ids: Array = bucket.keys()
		ids.sort()
		var sorted_bucket: Dictionary = {}
		for id: String in ids:
			sorted_bucket[id] = bucket[id]
		_records[type] = sorted_bucket

	state = State.VALIDATING
	var error_count: int = 0
	for entry: Dictionary in report:
		if entry["severity"] == &"error":
			error_count += 1

	if error_count > 0:
		state = State.FAILED
		return FAILED
	state = State.READY
	return OK


## Returns a `duplicate_deep()` copy of the record `id` of `type`, or `null`
## with `last_lookup_error` set (`not_ready`, `unknown_type`, `missing_id`)
## and `push_error()` called. Consumers copy values into their own runtime
## objects; nothing writes back into the catalog.
## Example: [code]var rec: MoveData = catalog.get_record(&"move", "move_notarize_strike")[/code]
func get_record(type: StringName, id: String) -> Resource:
	if not _check_lookup(type, "get_record"):
		return null
	var bucket: Dictionary = _records[type]
	if not bucket.has(id):
		last_lookup_error = &"missing_id"
		push_error("ContentCatalog.get_record(%s, %s): no such record." % [type, id])
		return null
	last_lookup_error = &""
	return (bucket[id] as Resource).duplicate_deep()


## True if a record `id` of `type` is loaded. `false` with
## `last_lookup_error` set and `push_error()` called when the catalog is not
## READY, the type is unknown, or the id is missing.
## Example: [code]if catalog.has_record(&"item", item_id): ...[/code]
func has_record(type: StringName, id: String) -> bool:
	if not _check_lookup(type, "has_record"):
		return false
	var bucket: Dictionary = _records[type]
	if not bucket.has(id):
		last_lookup_error = &"missing_id"
		push_error("ContentCatalog.has_record(%s, %s): no such record." % [type, id])
		return false
	last_lookup_error = &""
	return true


## Every record of `type` as `duplicate_deep()` copies, sorted ascending by
## `id` so every run sees the same order whatever order the filesystem
## listed the files in. The sort happened once in `load_all()`; this only
## walks the bucket. `[]` with `last_lookup_error` set and `push_error()`
## called when the catalog is not READY or the type is unknown. A type with
## zero records returns `[]` successfully.
## Example: [code]for rec in catalog.all_records(&"character"): roster.add(rec)[/code]
func all_records(type: StringName) -> Array[Resource]:
	var out: Array[Resource] = []
	if not _check_lookup(type, "all_records"):
		return out
	var bucket: Dictionary = _records[type]
	for id: String in bucket:
		out.append((bucket[id] as Resource).duplicate_deep())
	last_lookup_error = &""
	return out


## Resolves `id` to its live record ID: an alias resolves one hop (GDD
## Rule 2); a live ID returns itself. `""` with `last_lookup_error` set
## (`not_ready` or `missing_id`) and `push_error()` called otherwise.
## Example: [code]var live_id: String = catalog.resolve_alias(saved_id)[/code]
func resolve_alias(id: String) -> String:
	if state != State.READY:
		last_lookup_error = &"not_ready"
		push_error("ContentCatalog.resolve_alias(%s): catalog is not READY (state %d)." % [id, state])
		return ""
	if _aliases.has(id):
		last_lookup_error = &""
		return _aliases[id]
	for type: StringName in _records:
		if (_records[type] as Dictionary).has(id):
			last_lookup_error = &""
			return id
	last_lookup_error = &"missing_id"
	push_error("ContentCatalog.resolve_alias(%s): neither a live id nor an alias." % id)
	return ""


# Shared READY / known-type gate for the typed lookups. Sets
# last_lookup_error and logs on failure; returns true when the lookup may
# proceed.
func _check_lookup(type: StringName, caller: String) -> bool:
	if state != State.READY:
		last_lookup_error = &"not_ready"
		push_error("ContentCatalog.%s(%s): catalog is not READY (state %d)." % [caller, type, state])
		return false
	if not TYPE_TABLE.has(type):
		last_lookup_error = &"unknown_type"
		push_error("ContentCatalog.%s(%s): unknown record type." % [caller, type])
		return false
	return true


# Lists every `.tres` under dir_path, recursing into subdirectories, through
# ResourceLoader.list_directory() (4.4+; never DirAccess — exported builds
# expose .remap companions). A subdirectory entry carries a trailing "/".
func _discover_tres_files(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: String in ResourceLoader.list_directory(dir_path):
		if entry.ends_with("/"):
			out.append_array(_discover_tres_files(dir_path.path_join(entry.trim_suffix("/"))))
		elif entry.ends_with(".tres"):
			out.append(dir_path.path_join(entry))
	return out


# Loads one record file: the null check, the filename = id check, the
# registered per-type validators, then storage and alias registration. A
# record that fails a check is reported and not stored; loading continues.
func _load_one(type: StringName, file_path: String, bucket: Dictionary) -> void:
	var filename: String = file_path.get_file().get_basename()
	var record: Resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if record == null:
		push_error("ContentCatalog: %s failed to load." % file_path)
		_add_report_entry(&"error", filename, &"", file_path,
				"The file could not be loaded as a Resource.", [])
		return

	var record_id: String = record.get("id")
	if record_id != filename:
		push_error("ContentCatalog: %s declares id %s, which does not match its filename." % [file_path, record_id])
		_add_report_entry(&"error", record_id, &"id", file_path,
				"The filename without extension must equal the record's id.", [])
		return

	for validator: Callable in _validators.get(type, []):
		for raw_entry: Dictionary in validator.call(record):
			_add_report_entry(raw_entry["severity"], record_id, raw_entry["field"], file_path,
					raw_entry["message"], raw_entry.get("related_locations", []))

	bucket[record_id] = record
	for alias: String in record.get("aliases"):
		_aliases[alias] = record_id


# Appends one entry in the GDD's Entry shape. record_index is 0: one record
# per file (ADR-0001).
func _add_report_entry(severity: StringName, record_id: String, field: StringName,
		file_path: String, message: String, related_locations: Array) -> void:
	report.append({
		"severity": severity,
		"record_id": record_id,
		"field": field,
		"location": {"file_path": file_path, "record_index": 0},
		"message": message,
		"related_locations": related_locations,
	})
