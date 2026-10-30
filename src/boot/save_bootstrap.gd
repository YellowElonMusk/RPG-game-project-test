## The one composition-root list of save participants (ADR-0009 §3), like
## `ContentBootstrap` (ADR-0004). Save/Load imports no Feature system;
## adding a participant adds a line here, and the story that introduces it
## names that line. Order is registration order (capture and commit).
class_name SaveBootstrap
extends RefCounted


## `camp_return`: (camp_id) -> MapEntryPayload, for a save made in Camp.
static func participants(machine: GameStateMachine, world_state: WorldState,
		camp_return: Callable) -> Array[SaveParticipant]:
	var out: Array[SaveParticipant] = []
	out.append(GameStateSaveParticipant.new(machine))  # story 090: last camp
	out.append(OverworldSaveParticipant.new(world_state, machine, camp_return))  # story 090: WorldState
	# TODO(save-load): squad_roster (HP, items), once the Squad Roster system exists.
	return out
