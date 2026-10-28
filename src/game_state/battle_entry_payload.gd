## Payload for `GameStateMachine.request_transition(Mode.BATTLE, payload)`
## (ADR-0002 Key Interfaces). `party` is interim, until Squad Roster &
## Recruitment owns the party; its `Combatant`s are the requester's own
## instances, changed in place (ADR-0002 §7, HP/MP carryover contract).
class_name BattleEntryPayload extends RefCounted

var descriptor: EncounterDescriptor = null
var party: Array[Combatant] = []
