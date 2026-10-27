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

## Cross-reference schema (TR-content-005; ADR-0001 Rule 3; ADR-0011 §4–§5):
## record type → reference field → `{target_types, list, kind_field?,
## kind_value?}`. `target_types` lists every record type the field may name;
## `kind_field`/`kind_value`, when present, constrain the target's kind.
## `_run_reference_checks()` is the one generic pass that reads it; no field
## gets its own check. Every target id goes through the alias map first.
## Asset-ID fields (`sprite_set_id`, `ai_profile_id`, …) are not references
## and are not listed. Fields are in name order within each type, so the
## report order is deterministic.
## Example: [code]var spec: Dictionary = ContentCatalogService.REFERENCE_SCHEMA[&"character"][&"nation_id"][/code]
const REFERENCE_SCHEMA: Dictionary = {
	&"character": {
		&"move_ids": {"target_types": [&"move"], "list": true},
		&"nation_id": {"target_types": [&"faction"], "list": false, "kind_field": &"kind", "kind_value": "human_nation"},
		&"signature_move_id": {"target_types": [&"move"], "list": false},
	},
	&"enemy": {
		&"faction_id": {"target_types": [&"faction"], "list": false, "kind_field": &"kind", "kind_value": "alien"},
		&"move_ids": {"target_types": [&"move"], "list": true},
	},
	&"faction": {
		&"rule_id": {"target_types": [&"faction_rule"], "list": false},
	},
	&"faction_rule": {
		&"ref_ids": {"target_types": [&"move", &"enemy"], "list": true},
	},
	&"combo": {
		&"required_character_ids": {"target_types": [&"character"], "list": true},
		&"required_state_ids": {"target_types": [&"quirk_state"], "list": true},
	},
	&"map": {
		&"encounter_zone_ids": {"target_types": [&"encounter"], "list": true},
		&"faction_id": {"target_types": [&"faction"], "list": false},
	},
	&"encounter": {
		&"enemy_ids": {"target_types": [&"enemy"], "list": true},
		&"faction_id": {"target_types": [&"faction"], "list": false},
	},
	&"occupation_stage": {
		&"faction_id": {"target_types": [&"faction"], "list": false},
	},
}

## Maximum length of a record `id`, in characters (GDD F1; ADR-0001). A fixed
## constant, deliberately not a tuning knob (GDD Tuning Knobs).
const ID_MAX_LENGTH := 64
## Lowercase snake_case starting with a letter (GDD F1; ADR-0001). A fixed
## constant, deliberately not a tuning knob (GDD Tuning Knobs).
const ID_PATTERN := "^[a-z][a-z0-9_]*$"

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

## Test seam only: production code never sets this. When it is a valid
## (non-empty) `Callable`, `load_all()` calls it once after each file finishes
## loading -- while `state == LOADING` -- passing the file path. It exists
## because `load_all()` is synchronous (Engine Notes), so the Loading state
## has no other seam to observe from outside the call. Never a signal: story
## 021's monitor allows only the catalog's state-change signal during load.
## Default: an empty `Callable()`, which is never called.
## Example: [code]catalog.file_loaded_hook = func(file_path: String) -> void:
##     print("loaded ", file_path)[/code]
var file_loaded_hook: Callable = Callable()

# type StringName → { id String → Resource }. Records are the shared, cached
# instances; lookups hand out duplicate_deep() copies. load_all() rebuilds
# each bucket keyed in ascending-id order once the type is fully loaded, so
# iterating a bucket yields ids sorted without any per-lookup sort.
var _records: Dictionary = {}
# type StringName → { id String → file_path String }: the source file for
# each stored record (ADR-0004 §4). Populated in _load_one() alongside
# _records' bucket; load_all()'s Validating pass reads it once to fill each
# report entry's location, since validators no longer run inside _load_one().
var _record_paths: Dictionary = {}
# id String → Array of every res:// path that declared that id, across all
# types (ADR-0001 Rule 2: ids are unique catalog-wide). Values are plain
# Arrays of Strings: nested typed collections do not parse on 4.7.2. Filled in
# _load_one() before the bucket write, which overwrites on a duplicate id, so no
# location is lost; _check_duplicate_ids() reads it once Validating starts.
var _id_locations: Dictionary[String, Array] = {}
# alias String → live id String (one hop, GDD Rule 2).
var _aliases: Dictionary[String, String] = {}
# alias String → Array of {record_id: String, file_path: String} — every
# record that declared that alias, across all types (ADR-0001: an alias
# belongs to exactly one record and can never shadow a live id). Filled in
# _load_one() for every alias that passes the id-format check; the Validating
# pass's two alias checks each read it once and erase any alias they flag from
# _aliases, so a bad mapping can never reach resolve_alias() or the reference
# pass, even unreachably.
var _alias_locations: Dictionary[String, Array] = {}
# type StringName → Array of Callable(record) -> Array[Dictionary].
var _validators: Dictionary = {}
# system StringName → PackedStringArray of known EffectDescriptor types.
var _known_effect_types: Dictionary = {}
# type StringName → Array of StringName fields registered via
# register_acyclic_field(). Production registers none: no real record type
# references its own type (QL-STORY-READY, 2026-10-24).
var _acyclic_fields: Dictionary = {}
# Engine-written .tres keys the unknown-field scan never reports: they are not
# script exports. Any metadata/* key is skipped by prefix.
const _IGNORED_RESOURCE_KEYS: Dictionary = {
	"script": true, "resource_name": true, "resource_local_to_scene": true,
}
# Faction fields an alien faction may set but a human_nation may not (ADR-0012;
# story 018 adds signature_color, backup_icon_id and rule_id to this list).
const _ALIEN_ONLY_FIELDS: Array[StringName] = [&"patrol_archetype_id"]
# type StringName → {file_path, record_id, names} for the file of that type
# whose path sorts first among those declaring an Object/Resource-typed
# export. Filled while loading; _report_object_typed_exports() reports it once
# Validating starts, so the located file never depends on listing order.
var _object_export_first: Dictionary = {}
# ID_PATTERN compiled once at construction, never per record in _load_one().
var _id_regex: RegEx = _compile_id_regex()
# One top-level `key = ` line of a .tres [resource] section (ADR-0001
# Validation mechanism). Compiled once, like _id_regex.
var _resource_key_regex: RegEx = _compile_resource_key_regex()


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


## Marks the reference field `field` of `type` (a key in
## `REFERENCE_SCHEMA[type]`) as an edge the cycle walk follows (GDD Edge Cases
## "References"; ADR-0001). Only registered fields are cycle-checked;
## cross-type chains such as faction → rule_id → faction_rule → ref_ids →
## enemy → faction_id → faction are legal unless an owner registers them. A
## self-reference on any reference field is an error whether or not it is
## registered. Must be called before `load_all()` starts; a later call is
## rejected with `push_error()`.
## Example: [code]catalog.register_acyclic_field(&"faction", &"rule_id")[/code]
func register_acyclic_field(type: StringName, field: StringName) -> void:
	if state != State.UNLOADED:
		push_error("ContentCatalog.register_acyclic_field(%s, %s): rejected, load_all() has already started." % [type, field])
		return
	if not _acyclic_fields.has(type):
		_acyclic_fields[type] = []
	(_acyclic_fields[type] as Array).append(field)


## Pure depth-first cycle detector over an edge map
## `{record id: Array of target ids}`. Reads no catalog state. Returns each
## cycle once, as an Array of member ids in edge order, rotated to start at the
## member that sorts first (case-sensitive string order); a self-edge is a
## cycle of one. load_all() calls it on the edges of the registered acyclic
## fields, after alias resolution.
## Example: [codeblock]
## var cycles: Array = ContentCatalogService.find_reference_cycles({"node_a": ["node_b"], "node_b": ["node_a"]})
## # cycles == [["node_a", "node_b"]]
## [/codeblock]
static func find_reference_cycles(edges: Dictionary) -> Array:
	# Iterative depth-first walk with an explicit stack: a recursive walk hits
	# GDScript's call-stack limit on a chain of about 1,100 records and then
	# returns no cycles at all, silently.
	var visit_state: Dictionary = {}
	var cycles: Array = []
	var seen_keys: Dictionary = {}
	var nodes: Array = edges.keys()
	nodes.sort()
	for root: String in nodes:
		if visit_state.has(root):
			continue
		# path holds the nodes on the current walk; next_child[i] is the index of
		# path[i]'s next target to visit; path_index maps a node to its slot.
		var path: Array = [root]
		var next_child: Array[int] = [0]
		var path_index: Dictionary = {root: 0}
		visit_state[root] = &"active"
		while not path.is_empty():
			var node: String = path[-1]
			var targets: Array = edges.get(node, [])
			var i: int = next_child[-1]
			if i >= targets.size():
				path.pop_back()
				next_child.pop_back()
				path_index.erase(node)
				visit_state[node] = &"done"
				continue
			next_child[-1] = i + 1
			var target: String = targets[i]
			var target_state: StringName = visit_state.get(target, &"")
			if target_state == &"":
				visit_state[target] = &"active"
				path_index[target] = path.size()
				path.append(target)
				next_child.append(0)
			elif target_state == &"active":
				# A target still on the walk closes a cycle; a done target is a
				# branch already walked, never a new cycle.
				var cycle: Array = _rotate_to_sorted_first(path.slice(path_index[target]))
				var key: String = "|".join(PackedStringArray(cycle))
				if not seen_keys.has(key):
					seen_keys[key] = true
					cycles.append(cycle)
	return cycles


## Loads every record under `data_root`'s type subdirectories (TYPE_TABLE),
## runs validation over the complete set, and settles in READY or FAILED.
## Returns `OK` on READY, `FAILED` on FAILED, and `ERR_ALREADY_IN_USE`
## (changing nothing) on any call after the first. Never fails fast: every
## problem is collected into `report`. A missing type directory is not an
## error. Once Validating starts, the catalog-wide duplicate-id check runs
## first; then the two alias checks (a shadowing alias, a doubly-declared
## alias — ADR-0001); then the generic reference pass (REFERENCE_SCHEMA) and
## the cycle walk over registered acyclic fields; then the Overworld checks
## (one new_game_entry Map, unique (faction_id, stage), alien-only faction
## fields — ADR-0012); then validators run over every stored record in
## TYPE_TABLE order and then each bucket's already-sorted id order (ADR-0004
## §4), so the report order stays deterministic. Only `ContentBootstrap.run()`
## calls this in production; the catalog's own unit tests call it on a
## fixture root.
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
			if file_loaded_hook.is_valid():
				file_loaded_hook.call(file_path)

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
	_check_duplicate_ids()
	_report_object_typed_exports()
	_check_alias_shadowing()
	_check_alias_double_declaration()
	_run_reference_checks()
	_run_cycle_checks()
	_check_new_game_entry_uniqueness()
	_check_occupation_stage_uniqueness()
	_check_alien_only_fields()
	_run_validators()

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


# Catalog-wide id uniqueness (ADR-0001 Rule 2), the first check of the
# Validating pass. Each id held by more than one file is exactly one error,
# never one per file and never "last one wins". Its location is the path that
# sorts first (case-sensitive string order; record_index is always 0, one
# record per file); every other path goes in related_locations in the same
# order. Ids and paths are sorted here, so the result never depends on
# discovery order.
func _check_duplicate_ids() -> void:
	var ids: Array[String] = _id_locations.keys()
	ids.sort()
	for id: String in ids:
		# Nested typed collections do not parse on 4.7.2, so the map holds plain
		# Arrays; assign() copies into a typed one and checks every element.
		var paths: Array[String] = []
		paths.assign(_id_locations[id])
		if paths.size() < 2:
			continue
		paths.sort()
		var related_locations: Array[Dictionary] = []
		for other_path: String in paths.slice(1):
			related_locations.append({"file_path": other_path, "record_index": 0})
		_add_report_entry(&"error", id, &"id", paths[0],
				"This id is declared by more than one record.", related_locations)


# Catalog-wide alias/live-id shadowing (ADR-0001: an alias can never shadow a
# live id). One entry per declaring record -- "it does not matter which
# record sorts first, the declaring record owns the entry" (story 013): unlike
# a duplicate id or a doubly-declared alias, this is not a fact shared equally
# between two records that did the same thing; only the declaring record
# misdeclared anything. A flagged alias is erased from _aliases so it can
# never resolve to the wrong record.
func _check_alias_shadowing() -> void:
	var aliases: Array[String] = _alias_locations.keys()
	aliases.sort()
	for alias: String in aliases:
		if _find_record_type(alias) == &"":
			continue
		var live_path: String = _record_path_of(alias)
		var path_to_record: Dictionary = {}
		var paths: Array[String] = []
		for raw_decl: Variant in (_alias_locations[alias] as Array):
			var decl: Dictionary = raw_decl
			paths.append(decl["file_path"])
			path_to_record[decl["file_path"]] = decl["record_id"]
		paths.sort()
		for declaring_path: String in paths:
			_add_report_entry(&"error", path_to_record[declaring_path], &"aliases", declaring_path,
					"This alias is the same as a live record's id.",
					[{"file_path": live_path, "record_index": 0}])
		_aliases.erase(alias)


# Catalog-wide alias double-declaration (ADR-0001: an alias belongs to
# exactly one record). Same shape as _check_duplicate_ids(): one entry located
# at the first-sorting declaring path, every other declaring path in
# related_locations, sorted. Independent of the shadowing check above -- an
# alias can be both doubly-declared and shadow a live id, and both checks fire
# on it.
func _check_alias_double_declaration() -> void:
	var aliases: Array[String] = _alias_locations.keys()
	aliases.sort()
	for alias: String in aliases:
		var declarations: Array = _alias_locations[alias]
		if declarations.size() < 2:
			continue
		var path_to_record: Dictionary = {}
		var paths: Array[String] = []
		for raw_decl: Variant in declarations:
			var decl: Dictionary = raw_decl
			paths.append(decl["file_path"])
			path_to_record[decl["file_path"]] = decl["record_id"]
		paths.sort()
		var related_locations: Array[Dictionary] = []
		for other_path: String in paths.slice(1):
			related_locations.append({"file_path": other_path, "record_index": 0})
		_add_report_entry(&"error", path_to_record[paths[0]], &"aliases", paths[0],
				"This alias is declared by more than one record.", related_locations)
		_aliases.erase(alias)


# Overworld uniqueness (ADR-0012 §3; story 017): at most one Map sets
# new_game_entry. Same shape as _check_duplicate_ids(): the Map whose path
# sorts first owns the one entry; every other such Map goes in
# related_locations, sorted.
func _check_new_game_entry_uniqueness() -> void:
	var bucket: Dictionary = _records.get(&"map", {})
	var paths_by_id: Dictionary = _record_paths.get(&"map", {})
	var path_to_id: Dictionary = {}
	var paths: Array[String] = []
	for id: String in bucket:
		if (bucket[id] as Resource).get("new_game_entry"):
			var path: String = paths_by_id.get(id, "")
			paths.append(path)
			path_to_id[path] = id
	if paths.size() < 2:
		return
	paths.sort()
	var related_locations: Array[Dictionary] = []
	for other_path: String in paths.slice(1):
		related_locations.append({"file_path": other_path, "record_index": 0})
	_add_report_entry(&"error", path_to_id[paths[0]], &"new_game_entry", paths[0],
			"More than one Map sets new_game_entry.", related_locations)


# Overworld uniqueness (ADR-0012 §3; story 017): no two OccupationStage
# records share one (faction_id, stage) pair. Same shape as
# _check_duplicate_ids(), grouped by pair; the field is "stage".
func _check_occupation_stage_uniqueness() -> void:
	var bucket: Dictionary = _records.get(&"occupation_stage", {})
	var paths_by_id: Dictionary = _record_paths.get(&"occupation_stage", {})
	# Nested typed collections do not parse on 4.7.2: plain Arrays as values.
	var groups: Dictionary = {}
	var path_to_id: Dictionary = {}
	for id: String in bucket:
		var record: Resource = bucket[id]
		var key: String = "%s|%d" % [record.get("faction_id"), int(record.get("stage"))]
		var path: String = paths_by_id.get(id, "")
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(path)
		path_to_id[path] = id
	var keys: Array = groups.keys()
	keys.sort()
	for key: String in keys:
		var paths: Array[String] = []
		paths.assign(groups[key])
		if paths.size() < 2:
			continue
		paths.sort()
		var related_locations: Array[Dictionary] = []
		for other_path: String in paths.slice(1):
			related_locations.append({"file_path": other_path, "record_index": 0})
		_add_report_entry(&"error", path_to_id[paths[0]], &"stage", paths[0],
				"This (faction_id, stage) pair is shared by more than one OccupationStage record.",
				related_locations)


# Alien-only fields (ADR-0012; story 018 extends _ALIEN_ONLY_FIELDS): a
# human_nation Faction that sets any of them gets one error per field, at its
# own file.
func _check_alien_only_fields() -> void:
	var bucket: Dictionary = _records.get(&"faction", {})
	var paths_by_id: Dictionary = _record_paths.get(&"faction", {})
	for id: String in bucket:
		var record: Resource = bucket[id]
		if record.get("kind") != "human_nation":
			continue
		for field: StringName in _ALIEN_ONLY_FIELDS:
			if String(record.get(field)) != "":
				_add_report_entry(&"error", id, field, paths_by_id.get(id, ""),
						"The field %s is alien-only; this faction is a human_nation." % field, [])


# The Validating pass (ADR-0004 §4): runs every registered validator, in
# registration order, over every stored record, after the generic checks in
# _load_one(). Types go in TYPE_TABLE order and ids in each bucket's sorted
# order, so the report order is deterministic. Each entry's location is the
# record's source file from _record_paths, record_index 0. A validator that
# breaks the documented contract (ADR-0004 §4: must return Array[Dictionary]
# entries each carrying severity and field) never crashes the load:
# _run_one_validator() turns the violation into one loud error entry naming
# the validator instead (story 016).
func _run_validators() -> void:
	for type: StringName in TYPE_TABLE:
		var sorted_bucket: Dictionary = _records[type]
		var paths: Dictionary = _record_paths.get(type, {})
		for id: String in sorted_bucket:
			for validator: Callable in _validators.get(type, []):
				_run_one_validator(validator, type, id, sorted_bucket[id], paths.get(id, ""))


# Runs one registered validator once against one stored record and appends
# its entries, filling record_id and location; related_locations defaults to
# [] and message to "". A return that is not an Array, or an entry that is not
# a Dictionary or lacks `severity` or `field`, becomes one error entry (field
# &"", the whole record) naming the validator, so a broken validator fails
# loudly instead of crashing the load.
func _run_one_validator(validator: Callable, type: StringName, record_id: String,
		record: Resource, file_path: String) -> void:
	var raw_result: Variant = validator.call(record)
	if not (raw_result is Array):
		_add_report_entry(&"error", record_id, &"", file_path,
				"Validator %s registered for type %s returned %s, not an Array[Dictionary]."
						% [_describe_validator(validator), type, type_string(typeof(raw_result))], [])
		return
	for raw_entry: Variant in (raw_result as Array):
		if not (raw_entry is Dictionary) or not (raw_entry as Dictionary).has("severity") \
				or not (raw_entry as Dictionary).has("field"):
			_add_report_entry(&"error", record_id, &"", file_path,
					"Validator %s registered for type %s returned an entry missing 'severity' or 'field'."
							% [_describe_validator(validator), type], [])
			continue
		var entry: Dictionary = raw_entry
		_add_report_entry(entry["severity"], record_id, entry["field"], file_path,
				entry.get("message", ""), entry.get("related_locations", []))


# Names a Callable for a broken-validator entry: "Class.method" when it is
# bound to an object, otherwise just the method name.
func _describe_validator(validator: Callable) -> String:
	var obj: Object = validator.get_object()
	if obj == null:
		return String(validator.get_method())
	if obj is Script:
		var script_obj: Script = obj as Script
		var script_name: String = script_obj.get_global_name()
		if script_name.is_empty():
			script_name = script_obj.resource_path.get_file()
		return "%s.%s" % [script_name, validator.get_method()]
	return "%s.%s" % [obj.get_class(), validator.get_method()]


# The generic reference pass (TR-content-005; ADR-0001 Rule 3): every field
# in REFERENCE_SCHEMA on every stored record, types in TYPE_TABLE order and
# ids in sorted order. An empty scalar field declares no reference. Linear in
# the number of references.
func _run_reference_checks() -> void:
	for type: StringName in TYPE_TABLE:
		var schema_for_type: Dictionary = REFERENCE_SCHEMA.get(type, {})
		if schema_for_type.is_empty():
			continue
		var bucket: Dictionary = _records[type]
		var paths: Dictionary = _record_paths.get(type, {})
		for id: String in bucket:
			var record: Resource = bucket[id]
			var file_path: String = paths.get(id, "")
			for field: StringName in schema_for_type:
				var spec: Dictionary = schema_for_type[field]
				if spec["list"]:
					var values: PackedStringArray = record.get(field)
					_check_list_reference_field(id, field, values, spec, file_path)
				else:
					var value: String = record.get(field)
					if value != "":
						_check_reference_value(id, field, value, spec, file_path)


# Checks each distinct value of a list field once, then gives one duplicate
# entry per value that appears more than once. The two checks are independent.
func _check_list_reference_field(record_id: String, field: StringName,
		values: PackedStringArray, spec: Dictionary, file_path: String) -> void:
	var counts: Dictionary = {}
	for value: String in values:
		counts[value] = counts.get(value, 0) + 1
	for value: String in counts:
		_check_reference_value(record_id, field, value, spec, file_path)
		if counts[value] > 1:
			_add_report_entry(&"error", record_id, field, file_path,
					"The value %s appears more than once in this list." % value, [])


# One reference value, resolved through the alias map (one hop). A
# self-reference gives exactly one entry and nothing else is checked for that
# value (story 014 precedence note); otherwise a missing id, a wrong target
# type, or a wrong target kind gives one entry.
func _check_reference_value(record_id: String, field: StringName, value: String,
		spec: Dictionary, file_path: String) -> void:
	var resolved: String = _aliases.get(value, value)
	if resolved == record_id:
		_add_report_entry(&"error", record_id, field, file_path,
				"This field references its own record.", [])
		return
	var target_type: StringName = _find_record_type(resolved)
	if target_type == &"":
		_add_report_entry(&"error", record_id, field, file_path,
				"References %s, which is not a record id." % value, [])
		return
	if not (spec["target_types"] as Array).has(target_type):
		_add_report_entry(&"error", record_id, field, file_path,
				"References %s, a %s record, which is not a type this field may name." % [value, target_type], [])
		return
	if spec.has("kind_field"):
		var target: Resource = (_records[target_type] as Dictionary)[resolved]
		var kind: String = target.get(spec["kind_field"])
		if kind != spec["kind_value"]:
			_add_report_entry(&"error", record_id, field, file_path,
					"References %s, whose kind is %s, not %s." % [value, kind, spec["kind_value"]], [])


# The type holding `id` as a stored record, searched in TYPE_TABLE order;
# &"" when no type holds it.
func _find_record_type(id: String) -> StringName:
	for type: StringName in TYPE_TABLE:
		if (_records[type] as Dictionary).has(id):
			return type
	return &""


# The cycle check: reports each cycle in the registered acyclic fields once.
# The entry is located at the member that sorts first; its field is that
# member's registered field whose name sorts first; the other members follow
# in related_locations in cycle order.
func _run_cycle_checks() -> void:
	var node_fields: Dictionary = {}
	var edges: Dictionary = _build_acyclic_edge_map(node_fields)
	for cycle: Array in find_reference_cycles(edges):
		var first_id: String = cycle[0]
		var first_fields: Array = node_fields[first_id]
		var related_locations: Array[Dictionary] = []
		for member: String in cycle.slice(1):
			related_locations.append({"file_path": _record_path_of(member), "record_index": 0})
		_add_report_entry(&"error", first_id, first_fields[0], _record_path_of(first_id),
				"This record is part of a reference cycle.", related_locations)


# Builds `{record id: Array of target ids}` from the registered acyclic fields,
# after alias resolution, and fills `node_fields` with each record's sorted
# registered fields. Self-edges are left out because the reference pass
# already reports every self-reference.
func _build_acyclic_edge_map(node_fields: Dictionary) -> Dictionary:
	var edges: Dictionary = {}
	for type: StringName in _acyclic_fields:
		var fields: Array = (_acyclic_fields[type] as Array).duplicate()
		fields.sort()
		var bucket: Dictionary = _records.get(type, {})
		for id: String in bucket:
			var record: Resource = bucket[id]
			node_fields[id] = fields
			var targets: Array = edges.get(id, [])
			for field: StringName in fields:
				var raw: Variant = record.get(field)
				var values: Array = []
				if raw is PackedStringArray:
					values.assign(raw)
				elif raw is String and raw != "":
					values.append(raw)
				for value: String in values:
					var resolved: String = _aliases.get(value, value)
					if resolved != id:
						targets.append(resolved)
			edges[id] = targets
	return edges


# Source file of a stored record of any type; "" when it is not stored.
func _record_path_of(id: String) -> String:
	var type: StringName = _find_record_type(id)
	return (_record_paths.get(type, {}) as Dictionary).get(id, "")


# Rotates a cycle, kept in edge order, to start at its member that sorts first.
static func _rotate_to_sorted_first(cycle: Array) -> Array:
	var first := 0
	for i in range(1, cycle.size()):
		if cycle[i] < cycle[first]:
			first = i
	return cycle.slice(first) + cycle.slice(0, first)


# Builds the RegEx for ID_PATTERN; called once from _id_regex's initializer.
func _compile_id_regex() -> RegEx:
	var regex := RegEx.new()
	var err: Error = regex.compile(ID_PATTERN)
	if err != OK:
		# A bad ID_PATTERN would otherwise fail every id silently.
		push_error("ContentCatalog: ID_PATTERN %s does not compile (error %d)." % [ID_PATTERN, err])
	return regex


# Builds the RegEx for one top-level .tres key; called once from
# _resource_key_regex's initializer.
func _compile_resource_key_regex() -> RegEx:
	var regex := RegEx.new()
	var err: Error = regex.compile("^([A-Za-z_][A-Za-z0-9_/]*) = ")
	if err != OK:
		push_error("ContentCatalog: the .tres key pattern does not compile (error %d)." % err)
	return regex


# Loads one record file: the null check, the filename = id check, the id
# format check (GDD F1), then storage (with its source path) and alias
# registration, which applies F1 to each alias. Validators run
# later, in load_all()'s Validating pass (ADR-0004 §4), not here. A record
# that fails a check is reported and not stored; loading continues.
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

	# GDD F1 is one boolean, so an id with several defects gives one entry.
	var prefix: String = TYPE_TABLE[type]["prefix"]
	if _breaks_id_format(record_id, prefix):
		push_error("ContentCatalog: %s has id %s, which breaks the id format rule." % [file_path, record_id])
		_add_report_entry(&"error", record_id, &"id", file_path,
				"The id must be at most %d characters, match %s and start with %s." % [ID_MAX_LENGTH, ID_PATTERN, prefix], [])
		return

	if not _id_locations.has(record_id):
		_id_locations[record_id] = []
	_id_locations[record_id].append(file_path)
	bucket[record_id] = record
	if not _record_paths.has(type):
		_record_paths[type] = {}
	(_record_paths[type] as Dictionary)[record_id] = file_path
	_register_aliases(record_id, record.get("aliases"), prefix, file_path)
	_check_structure(type, record_id, record, file_path)


# The structure checks of ADR-0001's Validation mechanism, run per stored
# record at load: unknown fields, required fields, EffectDescriptor types and
# Object-typed exports. The file's raw text is read here, once (Guardrail: one
# FileAccess read per file, at load only). The vocabulary is complete by now:
# register_known_effect_types() is rejected once load_all() has started.
func _check_structure(type: StringName, record_id: String, record: Resource,
		file_path: String) -> void:
	var text: String = FileAccess.get_file_as_string(file_path)
	# A script's own exports carry both bits; inherited engine properties
	# (`script`, `resource_name`, ...) lack PROPERTY_USAGE_SCRIPT_VARIABLE.
	var export_mask: int = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE
	var exports: Dictionary = {}
	for prop: Dictionary in record.get_property_list():
		if (prop["usage"] & export_mask) == export_mask:
			exports[prop["name"]] = prop
	_check_unknown_fields(text, exports, record_id, file_path)
	_check_required_fields(record, record_id, file_path)
	_check_effect_types(record, exports, record_id, file_path)
	_check_object_typed_exports(type, exports, record_id, file_path)


# Godot drops unknown .tres properties silently, so the raw text is diffed
# against the script's exports: one error per extra top-level key. Engine-written
# keys (`script`, `resource_name`, `resource_local_to_scene`, `metadata/*`) are
# never reported.
func _check_unknown_fields(text: String, exports: Dictionary, record_id: String,
		file_path: String) -> void:
	for key: String in _scan_resource_keys(text):
		if _IGNORED_RESOURCE_KEYS.has(key) or key.begins_with("metadata/"):
			continue
		if not exports.has(key):
			_add_report_entry(&"error", record_id, StringName(key), file_path,
					"The field %s is not declared by the record's script." % key, [])


# Every field in the record script's REQUIRED_FIELDS whose text is empty or
# whitespace-only is one error. A missing key and a wrong-typed value both
# leave the export's default "", so they collapse into this one condition
# (ADR-0001). A script without the constant requires nothing.
func _check_required_fields(record: Resource, record_id: String, file_path: String) -> void:
	var required: Array = (record.get_script() as Script).get_script_constant_map().get("REQUIRED_FIELDS", [])
	for field: StringName in required:
		var value: Variant = record.get(field)
		if value is String and (value as String).strip_edges().is_empty():
			_add_report_entry(&"error", record_id, field, file_path,
					"The required field %s is empty." % field, [])


# Every `effects` entry's `type` must be in the union of the vocabularies
# registered through register_known_effect_types(); each one that is not is an
# error on `effects`. While no system has registered a vocabulary the check is
# skipped: descriptors stay uninterpreted until an owner claims them
# (TR-content-006), so an empty registry cannot judge any type unknown.
func _check_effect_types(record: Resource, exports: Dictionary, record_id: String,
		file_path: String) -> void:
	if _known_effect_types.is_empty() or not exports.has("effects"):
		return
	var known: Dictionary = {}
	for system: StringName in _known_effect_types:
		for effect_type: String in (_known_effect_types[system] as PackedStringArray):
			known[effect_type] = true
	for effect: Dictionary in record.get("effects"):
		var effect_type: String = str(effect.get("type", ""))
		if not known.has(effect_type):
			_add_report_entry(&"error", record_id, &"effects", file_path,
					"The effect type %s is not registered by any owning system." % effect_type, [])


# A record script may not declare an Object/Resource-typed export (ADR-0001
# Implementation Guidelines). Records this file as the type's candidate when
# its path sorts before the current one; _report_object_typed_exports()
# reports only the sorted-first file of each type.
func _check_object_typed_exports(type: StringName, exports: Dictionary, record_id: String,
		file_path: String) -> void:
	var names := PackedStringArray()
	for name: String in exports:
		if (exports[name] as Dictionary)["type"] == TYPE_OBJECT:
			names.append(name)
	if names.is_empty():
		return
	var first: Dictionary = _object_export_first.get(type, {})
	if first.is_empty() or file_path < String(first["file_path"]):
		_object_export_first[type] = {"file_path": file_path, "record_id": record_id, "names": names}


# One error per Object-typed export, located at the file of each type whose
# path sorts first (case-sensitive string order); later files of that type are
# not reported again. Types go in TYPE_TABLE order.
func _report_object_typed_exports() -> void:
	for type: StringName in TYPE_TABLE:
		if not _object_export_first.has(type):
			continue
		var first: Dictionary = _object_export_first[type]
		for name: String in (first["names"] as PackedStringArray):
			_add_report_entry(&"error", first["record_id"], StringName(name), first["file_path"],
					"The export %s is Object-typed; records hold data only." % name, [])


# The top-level keys of a .tres file's [resource] section: each line matching
# _resource_key_regex. Continuation lines of a multi-line Array or Dictionary
# never match (Godot 4.7.2 writes them as `"key": value` or brackets). A String
# holding a newline is written with a literal line break inside the quotes, so
# the scan tracks whether a line starts inside a quoted string (counting
# unescaped `"`) and skips such lines.
func _scan_resource_keys(text: String) -> PackedStringArray:
	var keys := PackedStringArray()
	var in_resource := false
	var in_string := false
	for line: String in text.split("\n"):
		var starts_in_string: bool = in_string
		in_string = _ends_inside_string(line, in_string)
		if starts_in_string:
			continue
		if line.begins_with("["):
			in_resource = line.strip_edges() == "[resource]"
			continue
		if not in_resource:
			continue
		var found: RegExMatch = _resource_key_regex.search(line)
		if found != null:
			keys.append(found.get_string(1))
	return keys


# Whether a quoted string is still open at the end of `line`, given whether it
# was open at its start. A backslash escapes the next character.
static func _ends_inside_string(line: String, open: bool) -> bool:
	var i := 0
	while i < line.length():
		var c: String = line[i]
		if c == "\\" and open:
			i += 2
			continue
		if c == "\"":
			open = not open
		i += 1
	return open


# Registers one stored record's aliases. GDD Rule 8 / F1: an alias is
# validated as an id too. A malformed alias is one error on field "aliases"
# naming the declaring record, and it is not added to the map; several
# malformed aliases on one record give one entry each (never one naming all
# of them). An alias the record already listed is one duplicate-entry error
# and is not recorded again, so the alias checks in the Validating pass see
# each record at most once per alias.
func _register_aliases(record_id: String, aliases: PackedStringArray, prefix: String,
		file_path: String) -> void:
	var seen_aliases: Dictionary = {}
	for alias: String in aliases:
		if _breaks_id_format(alias, prefix):
			push_error("ContentCatalog: %s declares alias %s, which breaks the id format rule." % [file_path, alias])
			_add_report_entry(&"error", record_id, &"aliases", file_path,
					"The alias must be at most %d characters, match %s and start with %s." % [ID_MAX_LENGTH, ID_PATTERN, prefix], [])
			continue
		if seen_aliases.has(alias):
			_add_report_entry(&"error", record_id, &"aliases", file_path,
					"The alias %s appears more than once in this list." % alias, [])
			continue
		seen_aliases[alias] = true
		if not _alias_locations.has(alias):
			_alias_locations[alias] = []
		_alias_locations[alias].append({"record_id": record_id, "file_path": file_path})
		_aliases[alias] = record_id


# GDD F1 as one boolean: true when `candidate` is over ID_MAX_LENGTH, does
# not match ID_PATTERN, or does not start with the type's `prefix`. Applied to
# a record's own id and to each alias it declares, so the rule lives here once.
func _breaks_id_format(candidate: String, prefix: String) -> bool:
	return candidate.length() > ID_MAX_LENGTH or _id_regex.search(candidate) == null \
			or not candidate.begins_with(prefix)


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
