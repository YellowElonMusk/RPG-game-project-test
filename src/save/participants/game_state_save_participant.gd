## The `game_state` save section (ADR-0009 §3): only what the machine owns,
## `last_camp_id`. Restored through `GameStateMachine.restore_last_camp_id`.
class_name GameStateSaveParticipant
extends SaveParticipant

var _machine: GameStateMachine


func _init(machine: GameStateMachine) -> void:
	_machine = machine


func save_key() -> StringName:
	return &"game_state"


func schema_version() -> int:
	return 1


func capture() -> Dictionary:
	return {"last_camp_id": _machine.last_camp_id}


## A camp ID is runtime state (a CampSpot marker), not a catalog record, so
## it is read as a plain string.
func stage(_data: Dictionary, reader: SaveReader) -> SaveStage:
	return SaveStage.success(reader.get_string("last_camp_id"))


func commit(staged: SaveStage) -> void:
	_machine.restore_last_camp_id(String(staged.staged))


func reset_to_new_game() -> void:
	_machine.restore_last_camp_id("")
