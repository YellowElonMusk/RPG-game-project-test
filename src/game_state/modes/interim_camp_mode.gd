## Interim Camp mode (GDD `game-state-scene-flow.md` modes; Overworld rules
## 13 and 13a; story 089). Entered by resting at a CampSpot or by Retreat
## after a Defeat; shows a rest card, and `confirm` sets out again: a fade
## to the camp's map at its CampSpot's return EntryPoint
## (`CampDirectory.return_payload()`, the region default camp when no camp
## is registered). The Camp & Party Management system (not designed)
## replaces it: party management, healing and the rest gags belong there.
class_name InterimCampMode extends GameMode

## Injected by `GameRoot` before `setup()`.
var camp_directory: CampDirectory = null
## Injected by `GameRoot`: setting out autosaves to slot 1 (provisional, the
## Save/Load GDD owns when saves happen; ADR-0009 §4).
var save_service: SaveService = null
## The last autosave result (tests).
var last_save_result: int = -1
var _machine: GameStateMachine = null
## The camp being rested at (the payload's ID; may be empty on a Retreat
## with no camp registered).
var camp_id: String = ""


func setup(machine: GameStateMachine, payload: RefCounted) -> void:
	_machine = machine
	var camp: CampEntryPayload = payload as CampEntryPayload
	camp_id = camp.camp_id if camp != null else ""
	(%Card as Label).text = "Resting at camp.\n[Confirm] Set out"


## `confirm` sets out; every other action is consumed and does nothing.
func handle_action(action: StringName, pressed: bool) -> bool:
	if action == InputActions.CONFIRM and pressed:
		set_out()
	return true


## Requests the Overworld at the camp's return EntryPoint. Returns Game
## State's result, or `REJECTED_INVALID_PAYLOAD` with an error logged when
## no camp return is known.
func set_out() -> GameStateMachine.RequestResult:
	var target: MapEntryPayload = camp_directory.return_payload(camp_id) if camp_directory != null else null
	if target == null or _machine == null:
		push_error("InterimCampMode: no return for camp '%s'" % camp_id)
		return GameStateMachine.RequestResult.REJECTED_INVALID_PAYLOAD
	if save_service != null:
		last_save_result = save_service.save_to_slot(1)
	return _machine.request_transition(GameStateMachine.Mode.OVERWORLD, target)
