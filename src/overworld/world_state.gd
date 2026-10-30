## State that outlives a map visit (ADR-0012 §4; GDD
## `design/gdd/overworld-exploration-encounters.md` rule 7). Injected into
## `OverworldMode`, never an autoload. This first slice (story 043) carries
## the map/position fields and the per-map resolved-symbol set with its
## respawn policy.
##
## Deviation from ADR-0012 §4, flagged: `mark_resolved()` takes the respawn
## policy as a third argument (ADR: `mark_resolved(map_id, symbol_id)`), so
## `on_map_entered()` can apply `on_map_reenter` without a marker -> record
## lookup through the catalog (no marker table exists yet).
##
## Stories 070-072 add opened checkpoints and story flags.
##
## TODO(overworld): camp_returns, other opened interactables,
## liberation, stage_stored, granted payoffs, rest_counter and
## `reset_to_new_game()` (stories 050+, ADR-0012 §4).
class_name WorldState
extends RefCounted

## The `encounter` record's `respawn` policy (ADR-0012 §3).
enum Respawn { NEVER, ON_MAP_REENTER, ON_REST }

## How the party entered a map (ADR-0012 §4 entry-path table). Continue
## skips respawn.
enum EntryKind { MAP_ENTRY, CONTINUE, NEW_GAME }

## The current map's ID.
var map_id: String = ""
## The leader's ground-plane position (ADR-0012 §4).
var party_pos: Vector2 = Vector2.ZERO
## The leader's facing (ADR-0012 §4).
var party_facing: Vector2 = Vector2.ZERO
## A Continue lands on this EntryPoint of `map_id` instead of `party_pos`
## (a save made at Camp continues at the camp's return point, ADR-0009 §3);
## empty otherwise.
var continue_entry: String = ""
## The current ChapterFlow step ID (ADR-0012 §8; story 068). New Game sets
## the chapter's opening step; the walk home moves it through the last act.
var chapter_step: String = ""

# map_id -> { symbol_id -> Respawn }
var _resolved: Dictionary = {}
# map_id -> { checkpoint marker_id -> true }; an opened checkpoint stays open
# (GDD rule 10, saved).
var _opened: Dictionary = {}
# Story flags set so far (GDD rule 14), flag -> true.
var _flags: Dictionary = {}
# map_id -> the occupation stage last computed on load (rule 8: never
# decreases; story 053).
var _stage_stored: Dictionary = {}
# map_id -> { marker_id -> true }: liberated clutter (rule 9; permanent).
var _liberated: Dictionary = {}


## `true` when `symbol_id` on `p_map_id` is resolved (its symbol is absent).
func is_resolved(p_map_id: String, symbol_id: String) -> bool:
	return (_resolved.get(p_map_id, {}) as Dictionary).has(symbol_id)


## Resolves `symbol_id` on `p_map_id` under `policy` (GDD rule 7 Victory).
## Written only from `OverworldMode.on_thawed()`.
func mark_resolved(p_map_id: String, symbol_id: String, policy: Respawn = Respawn.NEVER) -> void:
	if not _resolved.has(p_map_id):
		_resolved[p_map_id] = {}
	(_resolved[p_map_id] as Dictionary)[symbol_id] = policy


## Map entry (ADR-0012 §4): records `p_map_id` and, unless `entry_kind` is
## `CONTINUE`, respawns that map's `ON_MAP_REENTER` symbols. `NEVER` (and
## `ON_REST`) symbols stay resolved. `_catalog` is reserved for the ADR's
## record lookup and is unused while the policy is stored per symbol.
func on_map_entered(p_map_id: String, entry_kind: EntryKind, _catalog: Object = null) -> void:
	map_id = p_map_id
	if entry_kind == EntryKind.CONTINUE or not _resolved.has(p_map_id):
		return
	var resolved: Dictionary = _resolved[p_map_id]
	for symbol_id: String in resolved.keys():
		if resolved[symbol_id] == Respawn.ON_MAP_REENTER:
			resolved.erase(symbol_id)


## The policy for `rec`. Deviation, flagged: `EncounterData.respawn` is still
## a `bool` (ADR-0012 §3 names `never` / `on_map_reenter` / `on_rest`), so
## `true` maps to `ON_MAP_REENTER` and `false` (or no record) to `NEVER`.
## TODO(content-data): widen the record field to the ADR's enum.
static func respawn_of(rec: EncounterData) -> Respawn:
	if rec != null and rec.respawn:
		return Respawn.ON_MAP_REENTER
	return Respawn.NEVER


## `true` once checkpoint `marker_id` on `p_map_id` has been opened (GDD
## rule 10: it stays open, across visits and saves).
func is_checkpoint_open(p_map_id: String, marker_id: StringName) -> bool:
	return (_opened.get(p_map_id, {}) as Dictionary).has(marker_id)


## Opens checkpoint `marker_id` on `p_map_id` for good. Written only by
## `OverworldMode`.
func open_checkpoint(p_map_id: String, marker_id: StringName) -> void:
	if not _opened.has(p_map_id):
		_opened[p_map_id] = {}
	(_opened[p_map_id] as Dictionary)[marker_id] = true


## `true` when story flag `flag` is set.
func has_flag(flag: String) -> bool:
	return _flags.has(flag)


## Sets story flag `flag` (GDD rule 14).
func set_flag(flag: String) -> void:
	_flags[flag] = true


## New Game (ADR-0009 §3 `reset_to_new_game`): every field to its default.
func reset_to_new_game() -> void:
	map_id = ""
	party_pos = Vector2.ZERO
	party_facing = Vector2.ZERO
	continue_entry = ""
	chapter_step = ""
	_resolved = {}
	_opened = {}
	_flags = {}
	_stage_stored = {}
	_liberated = {}


## JSON-safe snapshot for the `overworld` save section (ADR-0009 §3):
## Vector2 as [x, y], respawn policies as ints, sets as sorted arrays.
func to_dict() -> Dictionary:
	var resolved: Dictionary = {}
	for m: String in _resolved:
		var per_map: Dictionary = {}
		for s: String in _resolved[m]:
			per_map[s] = int(_resolved[m][s])
		resolved[m] = per_map
	var opened: Dictionary = {}
	for m: String in _opened:
		var ids: Array = []
		for id: StringName in _opened[m]:
			ids.append(String(id))
		ids.sort()
		opened[m] = ids
	var flags: Array = _flags.keys()
	flags.sort()
	return {
		"map_id": map_id,
		"party_pos": [party_pos.x, party_pos.y],
		"party_facing": [party_facing.x, party_facing.y],
		"continue_entry": continue_entry,
		"chapter_step": chapter_step,
		"resolved": resolved,
		"opened": opened,
		"flags": flags,
		"stage_stored": _stage_stored.duplicate(),
		"liberated": _liberated_lists(),
	}


## Replaces every field from a `to_dict()` snapshot already validated by the
## save participant's `stage()`.
func from_dict(data: Dictionary) -> void:
	reset_to_new_game()
	map_id = data.get("map_id", "")
	party_pos = data.get("party_pos", Vector2.ZERO)
	party_facing = data.get("party_facing", Vector2.ZERO)
	continue_entry = data.get("continue_entry", "")
	chapter_step = data.get("chapter_step", "")
	var resolved: Dictionary = data.get("resolved", {})
	for m: String in resolved:
		_resolved[m] = {}
		for s: String in resolved[m]:
			(_resolved[m] as Dictionary)[s] = resolved[m][s] as Respawn
	var opened: Dictionary = data.get("opened", {})
	for m: String in opened:
		_opened[m] = {}
		for id: String in opened[m]:
			(_opened[m] as Dictionary)[StringName(id)] = true
	for f: String in data.get("flags", []):
		_flags[f] = true
	var lib: Dictionary = data.get("liberated", {})
	for m: String in lib:
		_liberated[m] = {}
		for id: String in lib[m]:
			(_liberated[m] as Dictionary)[StringName(id)] = true
	var stored: Dictionary = data.get("stage_stored", {})
	for m: String in stored:
		_stage_stored[m] = int(stored[m])


## The stage `p_map_id` last loaded at (0 when never loaded).
func stage_stored(p_map_id: String) -> int:
	return int(_stage_stored.get(p_map_id, 0))


## Records the stage a map loaded at (written only on map load).
func store_stage(p_map_id: String, stage: int) -> void:
	_stage_stored[p_map_id] = stage


## `true` once clutter marker `marker_id` on `p_map_id` is liberated.
func is_liberated(p_map_id: String, marker_id: StringName) -> bool:
	return (_liberated.get(p_map_id, {}) as Dictionary).has(marker_id)


## Liberates clutter marker `marker_id` on `p_map_id` for good (rule 9).
func liberate(p_map_id: String, marker_id: StringName) -> void:
	if not _liberated.has(p_map_id):
		_liberated[p_map_id] = {}
	(_liberated[p_map_id] as Dictionary)[marker_id] = true


func _liberated_lists() -> Dictionary:
	var out: Dictionary = {}
	for m: String in _liberated:
		var ids: Array = []
		for id: StringName in _liberated[m]:
			ids.append(String(id))
		ids.sort()
		out[m] = ids
	return out
