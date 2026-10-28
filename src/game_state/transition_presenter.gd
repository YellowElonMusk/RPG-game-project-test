## Injected collaborator (ADR-0002 Key Interfaces). Fire-and-forget: the
## machine's `tick()` timing is authoritative. The presenter never signals
## completion back and never blocks or extends a phase. UI Framework
## implements the production visuals; tests stub every call.
class_name TransitionPresenter extends RefCounted

## Called once, at the start of OUT.
func play_out(_transition_type: StringName, _duration: float, _capped: bool = false) -> void:
	pass


## Called once, at the start of IN.
func play_in(_transition_type: StringName, _duration: float, _capped: bool = false) -> void:
	pass
