## Payload for Overworld -> Camp entry (story 002) and for Retreat (ADR-0002
## §4, §11; ADR-0012 Payloads). `camp_id` names the camp the machine enters.
## On Retreat, `GameStateMachine.choose_retreat()` builds this from its own
## `last_camp_id` -- the machine stays the only writer of `last_camp_id`.
class_name CampEntryPayload extends RefCounted

var camp_id: String = ""
