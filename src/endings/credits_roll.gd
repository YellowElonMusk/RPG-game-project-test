## The credits' text and pace (data: `data/endings/credits_roll.tres`).
class_name CreditsRoll
extends Resource

const PATH: String = "res://data/endings/credits_roll.tres"

## The lines after the ending heading, top to bottom ("" = a blank line).
@export var lines: PackedStringArray = PackedStringArray()
## Scroll speed, in pixels per second.
@export_range(10.0, 400.0, 1.0) var scroll_px_per_s: float = 60.0
## Seconds after opening during which `confirm`/`cancel` cannot skip, so a
## press mashed through the ending conversation never skips the credits.
@export_range(0.0, 3.0, 0.05) var skip_guard_s: float = 1.0


## The shipped roll, or an empty one when it is missing.
static func load_default() -> CreditsRoll:
	if ResourceLoader.exists(PATH):
		var roll := load(PATH) as CreditsRoll
		if roll != null:
			return roll
	return CreditsRoll.new()
