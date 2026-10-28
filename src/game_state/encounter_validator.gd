## Pure Encounter-descriptor validator (ADR-0002 §8, story 013). Called by
## `GameStateMachine.request_transition()` at request time, before OUT and
## before any detach, so an invalid descriptor never starts a transition and
## never needs `rollback_swap()`. Takes the catalog and the config by
## reference; never mutates either and never keeps a record -- it only calls
## `catalog.has_record()` (control manifest: "Consumers copy a record's
## values into their own runtime objects").
class_name EncounterValidator extends RefCounted


## `catalog` is typed `Object` (duck-typed, matching
## `GameStateMachine._catalog` -- ADR-0002 §10) so this file never
## hard-depends on `ContentCatalogService`. A `null` `payload` or a `null`
## `payload.descriptor` is a caller bug, not a content bug, but is handled
## the same way: logged and rejected, no crash. Logs one
## `descriptor_invalid_runtime` error on the first field that fails --
## `context.field` names it -- and returns `false`; returns `true` only when
## every check passes.
static func validate(payload: BattleEntryPayload, config: TransitionConfig,
		catalog: Object, log_sink: GameStateLog) -> bool:
	if payload == null:
		log_sink.error(&"descriptor_invalid_runtime", {"field": &"payload"})
		return false
	var descriptor: EncounterDescriptor = payload.descriptor
	if descriptor == null:
		log_sink.error(&"descriptor_invalid_runtime", {"field": &"descriptor"})
		return false
	if descriptor.encounter_id.is_empty():
		log_sink.error(&"descriptor_invalid_runtime", {"field": &"encounter_id"})
		return false
	if descriptor.enemy_ids.is_empty():
		log_sink.error(&"descriptor_invalid_runtime", {"field": &"enemy_ids"})
		return false
	if not catalog.has_record(&"faction", descriptor.faction_id):
		log_sink.error(&"descriptor_invalid_runtime", {"field": &"faction_id"})
		return false
	# Interim flag (ADR-0002 §8), default false until ADR-0001's enemy-record
	# migration lands; story 041 removes this flag and the branch.
	if config.validate_enemy_ids_against_catalog:
		for enemy_id: String in descriptor.enemy_ids:
			if not catalog.has_record(&"enemy", enemy_id):
				log_sink.error(&"descriptor_invalid_runtime", {"field": &"enemy_ids"})
				return false
	return true
