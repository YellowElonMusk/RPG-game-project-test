## The chapter's interim data (ADR-0012 §8 "Retiring the interim"; ADR-0002
## §8). Story 137 retired the fixed fight sequence: the chapter's street
## fights are `enc_` records under `data/encounters/`, placed on the map by
## `EncounterSymbol` markers and started by `OverworldMode`. What remains is
## the interim party source -- the squad built from the `character`
## records -- until Squad Roster & Recruitment owns it.
##
## TODO(dialogue-quests): the static step list (objective text,
## `{map_id, leg_id}`, scheduled flags) lands here as a `ChapterSteps`
## resource, with `WorldState.chapter_step` as the current step (ADR-0012
## §8); no step data exists yet.
##
## Usage example:
## [codeblock]
## var squad: Array[Combatant] = ChapterFlow.build_squad(catalog)
## overworld.party_source = func() -> Array[Combatant]: return squad
## [/codeblock]
class_name ChapterFlow
extends RefCounted

const FACTION_BUREAUCRATIA: String = "bureaucratia"
const FACTION_MEGACORP: String = "megacorp"


## The starting squad (story 007): the `character` records with no
## `joins_on_flag`, in sorted id order. Later recruits join through
## `SquadStore.recruit()`. Stats and `move_ids` come from the records, never
## literals. Each call builds new `Combatant`s; the caller keeps one array
## for the whole run so HP/MP carry over by construction (ADR-0002 §7).
static func build_squad(catalog: ContentCatalogService) -> Array[Combatant]:
	var squad: Array[Combatant] = []
	if catalog == null:
		push_error("ChapterFlow.build_squad: no catalog")
		return squad
	var ids: Array[String] = []
	for record: CharacterData in catalog.all_records(&"character"):
		if record.joins_on_flag.is_empty():
			ids.append(record.id)
	ids.sort()
	for id: String in ids:
		squad.append(make_member(catalog.get_record(&"character", id)))
	return squad


## A level-1 squad member at full HP/MP from its `character` record.
static func make_member(record: CharacterData) -> Combatant:
	var combatant := Combatant.new(record.display_name, record.max_hp,
			record.max_mp, record.attack, record.defense, record.speed, false, false, record.id)
	combatant.move_ids = record.move_ids
	return combatant
