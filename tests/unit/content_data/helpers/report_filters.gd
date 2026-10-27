## Report filters for catalog tests. Warnings never change the load outcome
## (GDD F3; story 019), and any fixture with a record nothing references now
## also carries an unreferenced-record warning, so tests that assert an exact
## error count, or a clean load, count error-severity entries only. Deliberately
## has no `class_name`, like spy_content_catalog.gd: load it with preload().
##
## Usage example:
## [codeblock]
## const ReportFilters := preload("res://tests/unit/content_data/helpers/report_filters.gd")
## assert_int(ReportFilters.errors(catalog.report).size()).is_equal(1)
## [/codeblock]
extends RefCounted


## The error-severity entries of `report`, in report order.
## Example: [code]var errors: Array[Dictionary] = ReportFilters.errors(catalog.report)[/code]
static func errors(report: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in report:
		if entry["severity"] == &"error":
			out.append(entry)
	return out
