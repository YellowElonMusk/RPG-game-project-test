## Stand-in Overworld `GameMode` (ADR-0002 Migration Plan Step 2's
## `ChapterMode` clause), hosting `ChapterFlow`'s encounter sequencing until
## the real Overworld ships (retired at Migration Plan Step 4, Overworld
## epic). Builds the next `EncounterDescriptor` and requests Battle with it;
## reacts to the return trip by advancing (`VICTORY`) or repeating (`FLED`)
## the sequence. A Defeat never reaches this mode: Retry/Retreat happen
## entirely inside Game State and Battle (Implementation Notes).
##
## Never requests a transition from `setup()` or `on_thawed()` directly --
## both run while `GameStateMachine` is still mid-swap (`_phase` is `SWAP`;
## confirmed by reading `game_state_machine.gd`: `mode_entered`/`on_thawed`
## fire before `_begin_in_phase()`), so `request_transition()` there would
## hit the busy gate. Instead this mode connects to the machine's own
## `transition_finished` once, in `setup()` -- by the time that signal's
## listeners run, `_phase` is already `IDLE` (`_end_in_phase()`'s own
## comment: "phase is already IDLE by the time listeners run") -- and only
## then, on every arrival in `OVERWORLD`, asks for the next fight.
class_name ChapterMode extends GameMode

## Set before `setup()` to override the demo squad/faction (tests do this
## directly; Story 035's `GameRoot` will inject the real squad once Squad
## Roster & Recruitment exists). `squad`'s `Combatant`s are handed to the
## Battle mode by reference as `BattleEntryPayload.party`, so HP/MP carry
## over by construction (ADR-0002 §7) -- this mode never reads or writes
## them itself.
var faction_name: String = ChapterFlow.FACTION_BUREAUCRATIA
var squad: Array[Combatant] = []
var rng: RandomNumberGenerator = null

## Built once, in `setup()`; persists across every Battle freeze/thaw (the
## same node instance, never recreated -- ADR-0002 §4).
var chapter: ChapterFlow = null

var _machine: GameStateMachine = null


func setup(machine: GameStateMachine, _payload: RefCounted) -> void:
	_machine = machine
	if squad.is_empty():
		squad = _default_squad()
	chapter = ChapterFlow.new(faction_name, squad, rng)
	chapter.start_chapter()
	_machine.transition_finished.connect(_on_transition_finished)


## `true` = consumed. This stand-in has no interactive content of its own --
## it never references `Input` (Implementation Notes) -- so every action
## falls through.
func handle_action(_action: StringName, _pressed: bool) -> bool:
	return false


## Battle -> Overworld handoff (ADR-0002 §4). Only updates `chapter`'s own
## state here; the next Battle request waits for `_on_transition_finished()`
## (class doc comment) rather than firing from inside this call.
func on_thawed(_encounter_id: String, result: GameStateMachine.BattleResult) -> void:
	if result == GameStateMachine.BattleResult.VICTORY:
		chapter.advance_on_victory()


## Builds the next fight's `EncounterDescriptor` and requests it, carrying
## this mode's own `squad` (Check 4: `is_same(payload.party[i], squad[i])`).
func _request_next_battle() -> void:
	var descriptor: EncounterDescriptor = chapter.build_next_descriptor()
	var payload := BattleEntryPayload.new()
	payload.descriptor = descriptor
	payload.party = squad
	_machine.request_transition(GameStateMachine.Mode.BATTLE, payload)


## Interim demo squad (ADR-0002: the party is interim until Squad Roster &
## Recruitment owns it) -- used only when no squad was injected before
## `setup()`, matching the retired `ChapterFlowDemo`'s stat block.
func _default_squad() -> Array[Combatant]:
	return [
		Combatant.new("Hero A", 30, 10, 12, 8, 10, false),
		Combatant.new("Hero B", 30, 10, 12, 8, 10, false),
	]


## The real trigger for "a step" (Implementation Notes: "on a step,
## `machine.request_transition(...)`") -- every arrival in `OVERWORLD`, not
## just the first, since this mode is never recreated between fights
## (ADR-0002 §4). Requests the next fight unless the chapter is already won.
func _on_transition_finished(to_mode: GameStateMachine.Mode) -> void:
	if to_mode != GameStateMachine.Mode.OVERWORLD:
		return
	if chapter.chapter_complete:
		return
	_request_next_battle()
