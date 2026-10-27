## Builds the content error screen's plain text and the full log text from a
## catalog validation report (GDD F4, UI Requirements). Pure string building,
## no scene tree, no file I/O: the cap and the log path are injected
## (dependency injection), and writing the log to disk happens at the call
## site (Game State & Scene Flow's Content Error mode, or
## `validate-content.gd`), never here. Static; no instance, no logic beyond
## string formatting (Rule 4-style: data in, text out).
##
## Usage example:
## [codeblock]
## var config := ContentReportConfig.load_or_default()
## var screen_text := ValidationReportText.build_error_screen_text(catalog.report, config.error_screen_cap, log_path)
## var log_text := ValidationReportText.build_log_text(catalog.report)
## [/codeblock]
class_name ValidationReportText
extends RefCounted


## The first `min(error_count, cap)` error-severity entries in `report`
## (already in report order — story 023), one per line, each naming the
## record id, field and file location, followed by a final line with
## `log_path` (GDD F4, UI Requirements). Warnings are never counted toward
## the cap and never shown.
## Example: [code]ValidationReportText.build_error_screen_text(report, 20, "user://content_errors.log")[/code]
static func build_error_screen_text(report: Array[Dictionary], cap: int, log_path: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var shown: int = 0
	for entry: Dictionary in report:
		if entry["severity"] != &"error":
			continue
		if shown >= cap:
			break
		lines.append(_format_entry_line(entry))
		shown += 1
	lines.append("Full log: %s" % log_path)
	return "\n".join(lines)


## Every entry in `report` (errors and warnings, already in report order),
## one per line.
## Example: [code]ValidationReportText.build_log_text(catalog.report)[/code]
static func build_log_text(report: Array[Dictionary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in report:
		lines.append(_format_entry_line(entry))
	return "\n".join(lines)


# One entry as "record_id | field | file_path: message". An empty field (the
# whole record is at fault) and an empty record_id (an unparsable file) still
# produce a readable line; the delimiters make the empty slot visible rather
# than silently collapsing it.
static func _format_entry_line(entry: Dictionary) -> String:
	var location: Dictionary = entry["location"]
	return "%s | %s | %s: %s" % [entry["record_id"], entry["field"], location["file_path"], entry["message"]]
