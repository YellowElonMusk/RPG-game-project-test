## Subclasses `GameMode` (every test double must: `GameMode.new()` on the
## abstract base is a parser error on 4.7.2).
class_name StubOverworldMode extends GameMode

var freeze_count: int = 0
var thaw_calls: Array[Dictionary] = []

var _recorder: SequenceRecorder


func set_recorder(recorder: SequenceRecorder) -> void:
	_recorder = recorder


func handle_action(_action: StringName, _pressed: bool) -> bool:
	return false


func on_freezing() -> void:
	freeze_count += 1
	if _recorder != null:
		_recorder.record(&"on_freezing", [])


func on_thawed(encounter_id: String, result: GameStateMachine.BattleResult) -> void:
	thaw_calls.append({"encounter_id": encounter_id, "result": result})
	if _recorder != null:
		_recorder.record(&"on_thawed", [encounter_id, result])
