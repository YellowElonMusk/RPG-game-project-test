## The `overworld` save section (ADR-0009 §3, ADR-0012 §4): the party's map,
## position and facing plus the rest of `WorldState` (resolved symbols,
## opened checkpoints, story flags). `WorldState` is the single owner and is
## written every frame, so a save is always current. A save made in Camp
## continues at that camp's return EntryPoint (`continue_entry`), read from
## `camp_return` (camp_id -> MapEntryPayload) for the machine's last camp.
class_name OverworldSaveParticipant
extends SaveParticipant

var _world_state: WorldState
var _machine: GameStateMachine
## (camp_id: String) -> MapEntryPayload or null; GameRoot binds it to
## `CampDirectory.return_payload`.
var _camp_return: Callable


func _init(world_state: WorldState, machine: GameStateMachine, camp_return: Callable) -> void:
	_world_state = world_state
	_machine = machine
	_camp_return = camp_return


func save_key() -> StringName:
	return &"overworld"


func schema_version() -> int:
	return 1


func capture() -> Dictionary:
	var data: Dictionary = _world_state.to_dict()
	if _machine != null and _machine.current_mode == GameStateMachine.Mode.CAMP and _camp_return.is_valid():
		var back: MapEntryPayload = _camp_return.call(_machine.last_camp_id) as MapEntryPayload
		if back != null:
			data["map_id"] = back.map_id
			data["continue_entry"] = String(back.entry_marker_id)
	else:
		data["continue_entry"] = ""
	return data


## The current map is essential: an unknown or missing one fails the load.
## Everything else is validated by type and dropped (and reported) when
## malformed.
func stage(data: Dictionary, reader: SaveReader) -> SaveStage:
	var map_id: String = reader.get_id("map_id", &"map")
	if map_id.is_empty():
		return SaveStage.failure("no valid current map (map_id '%s')" % data.get("map_id", ""))
	var staged: Dictionary = {
		"map_id": map_id,
		"party_pos": reader.get_vector2("party_pos"),
		"party_facing": reader.get_vector2("party_facing", Vector2.DOWN),
		"continue_entry": reader.get_string("continue_entry"),
		"resolved": {},
		"opened": {},
		"flags": [],
	}
	var resolved: Dictionary = reader.get_dict("resolved")
	for m: Variant in resolved:
		if not (resolved[m] is Dictionary):
			reader.dropped.append("resolved.%s: not a table" % m)
			continue
		var per_map: Dictionary = {}
		for s: Variant in resolved[m]:
			var policy: Variant = resolved[m][s]
			if (policy is float or policy is int) and int(policy) in [0, 1, 2]:
				per_map[String(s)] = int(policy)
			else:
				reader.dropped.append("resolved.%s.%s: bad respawn policy" % [m, s])
		staged["resolved"][String(m)] = per_map
	var opened: Dictionary = reader.get_dict("opened")
	for m: Variant in opened:
		var ids: Array = []
		if opened[m] is Array:
			for id: Variant in opened[m]:
				if id is String:
					ids.append(id)
		staged["opened"][String(m)] = ids
	for f: Variant in reader.get_array("flags"):
		if f is String:
			(staged["flags"] as Array).append(f)
	return SaveStage.success(staged)


func commit(staged: SaveStage) -> void:
	_world_state.from_dict(staged.staged)


func reset_to_new_game() -> void:
	_world_state.reset_to_new_game()


func summary_fields() -> Dictionary:
	return {"map_id": _world_state.map_id}
