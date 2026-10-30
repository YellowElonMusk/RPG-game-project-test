## A set kit: the set-dressing variant a map shows (GDD Overworld rule 17;
## `occupation_stage.set_kit_id`, `map.liberated_kit_id`). Interim data: the
## placeholder sets have no per-kit art yet, so a kit only says what it
## removes. Instances ship under `data/presentation/set_kits/<id>.tres`.
##
## Usage example:
## [codeblock]
## var kit: SetKit = SetKit.resolve("kit_paris_liberated")
## map.apply_set_kit(kit)
## [/codeblock]
class_name SetKit
extends Resource

const DIR: String = "res://data/presentation/set_kits"

@export var id: String = ""
## `true` for a liberated kit: every faction set-dressing addition is removed
## and the skyline landmark restored (rule 17).
@export var removes_faction_dressing: bool = false


## The kit `id` from `DIR`, or null when it does not resolve.
static func resolve(kit_id: String) -> SetKit:
	if kit_id.is_empty():
		return null
	var path: String = DIR.path_join("%s.tres" % kit_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as SetKit
