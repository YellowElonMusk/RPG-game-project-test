## A chapter's ordered step list (ADR-0012 §8, interim data). Validated by
## `MapValidator.validate_steps()`: every step names an existing map and a
## leg on it (story 074).
class_name ChapterSteps
extends Resource

@export var chapter_id: String = ""
@export var steps: Array[ChapterStep] = []
## Story 069 (rule 13): the step ID that begins the last act (the walk
## home, A then B). Its maps need `liberated_profile_id` and
## `liberated_kit_id`, and none of them may reach a closed-behind map.
@export var last_act_from: String = ""
## The EntryPoint on the first last-act step's map the walk home arrives
## at (the segment's dungeon side).
@export var last_act_entry_id: StringName = &""
