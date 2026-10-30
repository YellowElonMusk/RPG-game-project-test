## Which floating number sits over each combatant during a replay (GDD
## sprite-camera-presentation AC-13 "no number before the end", AC-59 "old
## number cleared"; ADR-0006 §3/§7). A beat's numbers (`BeatPlan.numbers()`)
## appear at its `beat_finished`, once the displayed state is its snapshot;
## a later beat's `beat_impact` removes any number over a combatant that beat
## touches, so no stale number lingers into the next beat. The HUD's number
## widgets read `number_over()`; this never touches `BattleCore`.
##
## Usage example:
## [codeblock]
## var numbers := BeatNumbers.new()
## numbers.bind(replay)
## label.text = numbers.number_over(enemy)
## [/codeblock]
class_name BeatNumbers
extends RefCounted

## A combatant's number appeared ("" text never appears).
signal number_shown(combatant: Combatant, text: String)
## A combatant's number was removed.
signal number_cleared(combatant: Combatant)

## Combatant -> the number text over it.
var _shown: Dictionary = {}


## Connects to `controller`'s `beat_impact`, `beat_finished` and
## `display_resynced` signals.
func bind(controller: BattleReplayController) -> void:
	controller.beat_impact.connect(on_beat_impact)
	controller.beat_finished.connect(on_beat_finished)
	controller.display_resynced.connect(clear_all)


## Removes the numbers over every combatant `plan` changes or reacts on.
func on_beat_impact(plan: BeatPlan) -> void:
	for c: Combatant in plan.hp_changes.keys() + plan.reactions.keys():
		_clear(c)


## Shows `plan`'s numbers (one per non-zero HP change).
func on_beat_finished(plan: BeatPlan) -> void:
	var numbers: Dictionary = plan.numbers()
	for c: Combatant in numbers.keys():
		_shown[c] = numbers[c]
		number_shown.emit(c, numbers[c])


## Removes every number (resync, Retry, cancel).
func clear_all() -> void:
	for c: Combatant in _shown.keys():
		_clear(c)


## The number over `combatant`, or "" when none is shown.
func number_over(combatant: Combatant) -> String:
	return String(_shown.get(combatant, ""))


func _clear(c: Combatant) -> void:
	if _shown.erase(c):
		number_cleared.emit(c)
