## Story 017: the opaque handle `StubBattleMode.capture_start_snapshot()`
## hands back (ADR-0002 §7). A deep-copied `Dictionary` so mutating the
## mode's live `battle_state` afterward cannot also mutate the captured
## handle. Opaque to `GameStateMachine` -- only `StubBattleMode` reads `state`.
class_name BattleStateSnapshot extends RefCounted

var state: Dictionary = {}
