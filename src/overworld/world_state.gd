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
## TODO(overworld): camp_returns, chapter_step, other opened interactables,
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

# map_id -> { symbol_id -> Respawn }
var _resolved: Dictionary = {}
# map_id -> { checkpoint marker_id -> true }; an opened checkpoint stays open
# (GDD rule 10, saved).
var _opened: Dictionary = {}
# Story flags set so far (GDD rule 14), flag -> true.
var _flags: Dictionary = {}


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
