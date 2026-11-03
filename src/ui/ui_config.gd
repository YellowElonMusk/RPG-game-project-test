## UI Framework project config (ADR-0008 §7/§14): the refusal pulse's size
## and length, read from `data/config/ui_config.tres`. Data only (ADR-0001).
##
## Usage example:
## [codeblock]
## var config: UiConfig = load(UiConfig.DEFAULT_PATH)
## RefusalPulse.play(button, config, false)
## [/codeblock]
class_name UiConfig
extends Resource

## The shipped config resource.
const DEFAULT_PATH: String = "res://data/config/ui_config.tres"

## The refusal pulse's horizontal travel, in px each way (ADR-0008 §7).
@export var refusal_pulse_px: float = 2.0
## The refusal pulse's whole length, in seconds (ADR-0008 §7).
@export var refusal_pulse_time: float = 0.12
## The bus the refusal tick plays on; `Master` when it does not exist.
@export var feedback_bus: StringName = &"UI"
