## Subclasses `GameMode`, same note as `StubOverworldMode`.
class_name StubBattleMode extends GameMode

var snapshot_to_return: RefCounted = null
var restored_snapshot: RefCounted = null

var _recorder: SequenceRecorder


func set_recorder(recorder: SequenceRecorder) -> void:
	_recorder = recorder


func handle_action(_action: StringName, _pressed: bool) -> bool:
	return false


func capture_start_snapshot() -> RefCounted:
	if _recorder != null:
		_recorder.record(&"capture_start_snapshot", [])
	return snapshot_to_return


func restore_start_snapshot(snapshot: RefCounted) -> void:
	restored_snapshot = snapshot
	if _recorder != null:
		_recorder.record(&"restore_start_snapshot", [])
