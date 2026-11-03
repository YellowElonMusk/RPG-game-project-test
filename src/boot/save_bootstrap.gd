## The one composition-root list of save participants (ADR-0009 §3), like
## `ContentBootstrap` (ADR-0004). Save/Load imports no Feature system;
## adding a participant adds a line here, and the story that introduces it
## names that line. Order is registration order (capture and commit).
class_name SaveBootstrap
extends RefCounted


## `camp_return`: (camp_id) -> MapEntryPayload, for a save made in Camp.
## `squad` (optional): the live squad store, saved by the `squad`
## participant (Leveling GDD rule 7); null saves no squad (older tests).
static func participants(machine: GameStateMachine, world_state: WorldState,
		camp_return: Callable, squad: SquadStore = null,
		catalog: ContentCatalogService = null) -> Array[SaveParticipant]:
	var out: Array[SaveParticipant] = []
	out.append(GameStateSaveParticipant.new(machine))  # story 090: last camp
	out.append(OverworldSaveParticipant.new(world_state, machine, camp_return))  # story 090: WorldState
	if squad != null:
		out.append(SquadSaveParticipant.new(squad, catalog))  # leveling: level, XP, HP, MP
	return out
