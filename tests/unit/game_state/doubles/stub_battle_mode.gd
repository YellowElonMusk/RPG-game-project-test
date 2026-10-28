## Subclasses `GameMode`, same note as `StubOverworldMode`.
class_name StubBattleMode extends GameMode

var snapshot_to_return: RefCounted = null
var restored_snapshot: RefCounted = null

## Story 017: the stub's "live" battle state (party hp/mp, items, states,
## enemy group -- shape is the test's, opaque to the machine). A test mutates
## this after capture to prove Retry restores it rather than passing vacuously.
var battle_state: Dictionary = {}

## Story 010: counts `handle_action` calls.
var handle_action_count: int = 0
var last_action: StringName = &""
var last_pressed: bool = false

var _recorder: SequenceRecorder


func set_recorder(recorder: SequenceRecorder) -> void:
	_recorder = recorder


func handle_action(action: StringName, pressed: bool) -> bool:
	handle_action_count += 1
	last_action = action
	last_pressed = pressed
	return false


func capture_start_snapshot() -> RefCounted:
	if _recorder != null:
		_recorder.record(&"capture_start_snapshot", [])
	return snapshot_to_return


func restore_start_snapshot(snapshot: RefCounted) -> void:
	restored_snapshot = snapshot
	if snapshot is BattleStateSnapshot:
		battle_state = (snapshot as BattleStateSnapshot).state.duplicate(true)
	if _recorder != null:
		_recorder.record(&"restore_start_snapshot", [])
