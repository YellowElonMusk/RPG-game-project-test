## Story 084, AC-31d (GDD rule 12): with every other checkpoint open, every
## walk-grid route from the dungeon's camp-side EntryPoint to its exit to
## the boss chamber crosses the story encounter's checkpoint cells. The
## shipped dungeon passes; a gap in the wall beside the boom fails, even
## when another checkpoint guards that gap.
extends GdUnitTestSuite

const _PATHS: Array[String] = [
	"res://data/maps/paris_town_placeholder.tscn",
	"res://data/maps/paris_segment_placeholder.tscn",
	"res://data/maps/paris_dungeon_placeholder.tscn",
	"res://data/maps/paris_boss_chamber_placeholder.tscn",
]
const _DUNGEON: String = "map_paris_dungeon_placeholder"
## A wall pair west of the boom (rows 21-22), opened into a second doorway.
const _GAP: Array[Vector2i] = [Vector2i(3, 21), Vector2i(3, 22)]


func test_shipped_dungeon_cannot_be_routed_round_the_counter() -> void:
	var maps: Dictionary = _maps()
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_a_second_doorway_is_reported() -> void:
	var maps: Dictionary = _maps()
	_open_gap(maps[_DUNGEON])
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("exit_to_boss_chamber").contains("cp_permit_boom")


func test_a_second_doorway_behind_another_checkpoint_is_still_reported() -> void:
	var maps: Dictionary = _maps()
	var dungeon: OverworldMap = maps[_DUNGEON]
	_open_gap(dungeon)
	var gate := CheckpointMarker.new()
	gate.marker_id = &"cp_fixture_side_gate"
	gate.requirement_item_id = "item_fixture_key"
	gate.blocked_rect = Rect2(3, 21, 1, 2)
	gate.return_marker = Vector2(3.5, 25.0)
	gate.position = Vector3(3.5, 0.0, 22.0)
	dungeon.add_child(gate)
	var errors: PackedStringArray = _validate(maps)
	_free(maps)
	assert_str(", ".join(errors)).contains("cp_permit_boom")


func _open_gap(dungeon: OverworldMap) -> void:
	for cell: Vector2i in _GAP:
		dungeon.walk_layer.set_cell(cell, 0, Vector2i(0, 0))


## Only this story's check, so other rules a mutated map breaks don't mix in.
func _validate(maps: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var dungeon: OverworldMap = maps[_DUNGEON]
	for sym: EncounterSymbol in dungeon.symbol_markers():
		if sym.is_static and sym.start_on == EncounterSymbol.StartOn.CONFIRM:
			MapStructureValidator._check_not_routable_around(maps, dungeon, sym,
					OverworldConfig.new(), errors)
	return errors


func _maps() -> Dictionary:
	var maps: Dictionary = {}
	for path: String in _PATHS:
		var map: OverworldMap = (load(path) as PackedScene).instantiate() as OverworldMap
		maps[map.map_id] = map
	return maps


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
