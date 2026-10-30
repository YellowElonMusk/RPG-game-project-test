## Boot-time content validation for presentation data (ADR-0005 §9, "battle
## stages validated on load"; story 046). Content-only: it runs over every
## shipped `BattleStage` resource, never a live scene.
## TODO(sprite-camera-presentation): register with `ContentBootstrap` once
## ADR-0004 gains a non-record validator hook (see `PresentationConfig.validate`).
class_name PresentationValidators
extends RefCounted

## Where shipped battle stages live.
const STAGES_DIR := "res://data/presentation/stages"


## Loads every `BattleStage` `.tres` under `dir`, sorted by file name.
static func load_battle_stages(dir: String = STAGES_DIR) -> Array[BattleStage]:
	var out: Array[BattleStage] = []
	var names: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		var file_name: String = f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			names.append(file_name)
	names.sort()
	for file_name: String in names:
		var stage := load(dir.path_join(file_name)) as BattleStage
		if stage != null:
			out.append(stage)
	return out


## Validates every stage with `BattleFraming.validate` (which includes the
## same-depth check, AC-42) and returns every content error, each naming its
## stage; empty means every stage may be used.
static func validate_battle_stages(stages: Array[BattleStage],
		config: PresentationConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	for stage: BattleStage in stages:
		errors.append_array(BattleFraming.validate(stage, config))
	return errors
