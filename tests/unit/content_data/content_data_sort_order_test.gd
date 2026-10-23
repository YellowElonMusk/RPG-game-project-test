## Story 003, AC-2: `all_records(type)` returns records sorted ascending by
## `id`, and the result is identical whatever order the files were loaded in.
## Three fresh ContentCatalogService instances (never the autoload) load the
## same `sort_order` fixture root: A in discovery order, B with every listing
## reversed, C with every listing rotated by one. Both transforms are fixed
## permutations, never a seeded shuffle (Determinism rule). `id` sequences
## are compared, never Resource objects: duplicate_deep() copies are never
## the same instance.
extends GdUnitTestSuite

const FIXTURE_ROOT := "res://tests/unit/content_data/fixtures/sort_order"

## The types the fixture populates (three records each); every other
## TYPE_TABLE type has no directory under FIXTURE_ROOT and so zero records.
const POPULATED_TYPES: Array[StringName] = [&"character", &"move", &"faction"]

var _catalog_a: ContentCatalogService
var _catalog_b: ContentCatalogService
var _catalog_c: ContentCatalogService


static func _reverse_listing(listing: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = listing.duplicate()
	out.reverse()
	return out


static func _rotate_listing_by_one(listing: PackedStringArray) -> PackedStringArray:
	if listing.is_empty():
		return listing
	var out: PackedStringArray = listing.slice(1)
	out.append(listing[0])
	return out


func before_test() -> void:
	_catalog_a = auto_free(ContentCatalogService.new())
	_catalog_b = auto_free(ContentCatalogService.new())
	_catalog_b.discovery_order_transform = _reverse_listing
	_catalog_c = auto_free(ContentCatalogService.new())
	_catalog_c.discovery_order_transform = _rotate_listing_by_one
	assert_int(_catalog_a.load_all(FIXTURE_ROOT)).is_equal(OK)
	assert_int(_catalog_b.load_all(FIXTURE_ROOT)).is_equal(OK)
	assert_int(_catalog_c.load_all(FIXTURE_ROOT)).is_equal(OK)


## The `id` sequence of `all_records(type)` on `catalog`.
func _ids(catalog: ContentCatalogService, type: StringName) -> Array[String]:
	var ids: Array[String] = []
	for record: Resource in catalog.all_records(type):
		ids.append(record.get("id"))
	return ids


func _assert_strictly_ascending(ids: Array[String], label: String) -> void:
	for i: int in range(1, ids.size()):
		assert_bool(ids[i - 1] < ids[i]).override_failure_message(
				"%s: %s is not before %s" % [label, ids[i - 1], ids[i]]).is_true()


func test_all_records_each_type_is_strictly_ascending_in_every_catalog() -> void:
	for type: StringName in ContentCatalogService.TYPE_TABLE:
		_assert_strictly_ascending(_ids(_catalog_a, type), "A %s" % type)
		_assert_strictly_ascending(_ids(_catalog_b, type), "B %s" % type)
		_assert_strictly_ascending(_ids(_catalog_c, type), "C %s" % type)


func test_all_records_each_type_is_equal_across_discovery_orders() -> void:
	for type: StringName in ContentCatalogService.TYPE_TABLE:
		var ids_a: Array[String] = _ids(_catalog_a, type)
		assert_array(_ids(_catalog_b, type)).override_failure_message(
				"B %s differs from A" % type).contains_exactly(ids_a)
		assert_array(_ids(_catalog_c, type)).override_failure_message(
				"C %s differs from A" % type).contains_exactly(ids_a)


func test_populated_types_carry_three_records_each() -> void:
	for type: StringName in POPULATED_TYPES:
		assert_int(_ids(_catalog_a, type).size()).override_failure_message(
				"%s record count" % type).is_equal(3)


func test_shared_prefix_ids_sort_by_plain_string_order() -> void:
	# char_a < char_a_two < char_b: a shared prefix sorts before its extension,
	# and "_" (0x5F) before "b" is irrelevant — the shorter string wins first.
	for catalog: ContentCatalogService in [_catalog_a, _catalog_b, _catalog_c]:
		assert_array(_ids(catalog, &"character")).contains_exactly(["char_a", "char_a_two", "char_b"])
		assert_array(_ids(catalog, &"move")).contains_exactly(["move_a", "move_a_two", "move_b"])
		assert_array(_ids(catalog, &"faction")).contains_exactly(["faction_a", "faction_a_two", "faction_b"])


func test_type_with_zero_records_returns_empty_in_every_catalog() -> void:
	for type: StringName in ContentCatalogService.TYPE_TABLE:
		if type in POPULATED_TYPES:
			continue
		for catalog: ContentCatalogService in [_catalog_a, _catalog_b, _catalog_c]:
			assert_array(catalog.all_records(type)).override_failure_message(
					"%s should have no records" % type).is_empty()


func test_all_records_success_leaves_last_lookup_error_empty() -> void:
	for type: StringName in ContentCatalogService.TYPE_TABLE:
		for catalog: ContentCatalogService in [_catalog_a, _catalog_b, _catalog_c]:
			catalog.all_records(type)
			assert_str(String(catalog.last_lookup_error)).override_failure_message(
					"last_lookup_error after all_records(%s)" % type).is_equal("")


func test_discovery_order_transform_defaults_to_empty_callable() -> void:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	assert_bool(catalog.discovery_order_transform.is_valid()).is_false()
