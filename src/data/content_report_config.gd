## Project config for the content validation report (GDD F4, Tuning Knobs).
## Data only, no logic beyond `load_or_default()` and the clamp it applies.
## `data/config/` sits outside the catalog's type directories (story 002), so
## this is never loaded as content.
##
## Usage example:
## [codeblock]
## var config := ContentReportConfig.load_or_default()
## var text := ValidationReportText.build_error_screen_text(report, config.error_screen_cap, log_path)
## [/codeblock]
class_name ContentReportConfig
extends Resource

## Most errors the plain-text error screen lists (GDD F4 Tuning Knobs: 10-50, default 20).
@export var error_screen_cap: int = 20:
	set(value):
		error_screen_cap = clampi(value, 10, 50)

const DEFAULT_PATH := "res://data/config/content_report_config.tres"


## Loads the config at `path` (the shipped `DEFAULT_PATH` unless a caller
## passes another, as `validate-content.gd` or a test may). On a missing or
## unreadable file it logs an error and returns a default-valued instance,
## following `StatsConfig.load_or_default(path)` (ADR-0007). Never `null`.
## Out-of-range values in the file are clamped by `error_screen_cap`'s setter.
## Example: [code]var config := ContentReportConfig.load_or_default()[/code]
static func load_or_default(path: String = DEFAULT_PATH) -> ContentReportConfig:
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is ContentReportConfig:
			return loaded
	push_error("ContentReportConfig: %s is missing or not a ContentReportConfig; using defaults." % path)
	return ContentReportConfig.new()
