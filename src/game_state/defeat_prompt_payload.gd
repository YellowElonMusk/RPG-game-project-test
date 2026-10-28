## Plain data handed to the Defeat Prompt overlay (ADR-0002 §7-8, story 018).
## `GameStateMachine.report_battle_outcome(DEFEAT)` builds a new instance on
## every Defeat from the stored `EncounterDescriptor` -- never cached or
## reused across a Retry, so no stale offer survives into a later Defeat in
## the same battle. The payload is plain data, not a reference into the
## machine (control-manifest "every collaborator enters only through
## `_init`").
class_name DefeatPromptPayload extends RefCounted

## True when the Prompt should offer Retreat alongside Retry. This story only
## reads `EncounterDescriptor.retreat_allowed`; story 020/021 add
## camp-availability and the region-default fallback on top of this flag.
var offers_retreat: bool = false
