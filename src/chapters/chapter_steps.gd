## A chapter's ordered step list (ADR-0012 §8, interim data). Validated by
## `MapValidator.validate_steps()`: every step names an existing map and a
## leg on it (story 074).
class_name ChapterSteps
extends Resource

@export var chapter_id: String = ""
@export var steps: Array[ChapterStep] = []
