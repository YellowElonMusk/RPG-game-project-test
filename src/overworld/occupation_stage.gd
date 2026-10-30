## The `occupation_stage` formula (GDD Overworld rule 8, Formulas; registry
## entry `occupation_stage`; story 053). Pure static:
##
## `stage_new = clamp(max({base_stage} union {s : (f, s) in stage_table, f in
## flags}), 1, 3)`; `stage = max(stage_new, stage_stored)`
##
## computed only on map load (story 054), so a flag set mid-visit changes
## nothing until the next load, and the stage never goes down. A stored stage
## above the new one (a raising flag removed) keeps the stored stage and is
## reported as a warning.
class_name OccupationStage
extends RefCounted

## Stage names, for logs only: the player never sees them (GDD).
const NAMES: Array[String] = ["", "Contested", "Occupied", "Saturated"]


## The stage of `rec` given `has_flag(flag) -> bool` and the map's stored
## stage (0 when none). Returns [stage, warning] (warning "" when none).
static func compute(rec: MapData, has_flag: Callable, stored: int) -> Array:
	var raised: int = rec.base_stage
	for flag: String in rec.stage_table:
		if has_flag.call(flag):
			raised = maxi(raised, rec.stage_table[flag])
	var stage_new: int = clampi(raised, 1, 3)
	var warning: String = ""
	if stored > stage_new:
		warning = "%s: stage_stored %d is above the flags' stage %d (a raising flag was removed); keeping %d" \
				% [rec.id, stored, stage_new, stored]
	return [maxi(stage_new, stored), warning]
