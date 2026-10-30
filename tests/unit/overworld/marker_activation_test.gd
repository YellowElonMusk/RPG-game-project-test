## Story 058, AC-24 (`marker_activation`): using the GDD's P1-P6 example and
## a scrambled-order fixture, the active markers equal the formula, sorted by
## (`min_stage`, marker order). At stage 2, P1, P4, P6 and P2 hold the slots;
## liberating P2 shows 3 posters and P5 stays hidden; at stage 3 with an
## equal cap of 4 the same four keep their slots.
extends GdUnitTestSuite

const GameStateFixtures := preload("res://tests/unit/game_state/doubles/game_state_fixtures.gd")
const _SEGMENT_ID: String = "map_paris_segment_placeholder"
## The GDD example: posters in marker order, with their `min_stage`.
const _EXAMPLE: Array = [["p1", 1], ["p2", 2], ["p3", 3], ["p4", 1], ["p5", 2], ["p6", 1]]
## A fixed scramble of the example's array order (marker order is unchanged).
const _SCRAMBLE: Array[int] = [4, 0, 5, 2, 3, 1]


func test_stage_2_cap_4_slots_p1_p4_p6_p2() -> void:
	var held: Dictionary = MarkerActivation.slotted(_markers(), 2, {"poster": 4})
	assert_array(_sorted_keys(held)).is_equal([&"p1", &"p2", &"p4", &"p6"])


func test_liberating_p2_shows_three_and_p5_stays_hidden() -> void:
	var shown: Array[StringName] = MarkerActivation.visible(_markers(), 2, {"poster": 4}, [&"p2"], false)
	assert_array(shown).is_equal([&"p1", &"p4", &"p6"])


func test_stage_3_with_an_equal_cap_keeps_the_same_four() -> void:
	var at_2: Dictionary = MarkerActivation.slotted(_markers(), 2, {"poster": 4})
	var at_3: Dictionary = MarkerActivation.slotted(_markers(), 3, {"poster": 4})
	assert_array(_sorted_keys(at_3)).is_equal(_sorted_keys(at_2))


func test_stage_3_cap_7_shows_every_unliberated_poster() -> void:
	var shown: Array[StringName] = MarkerActivation.visible(_markers(), 3, {"poster": 7}, [&"p2"], false)
	assert_array(shown).is_equal([&"p1", &"p3", &"p4", &"p5", &"p6"])


func test_region_liberated_shows_none() -> void:
	assert_array(MarkerActivation.visible(_markers(), 3, {"poster": 7}, [], true)).is_empty()


func test_array_order_does_not_change_the_result() -> void:
	var scrambled: Array = []
	for i: int in _SCRAMBLE:
		scrambled.append(_markers()[i])
	for stage: int in [1, 2, 3]:
		for cap: int in [0, 2, 4, 7]:
			assert_array(_sorted_keys(MarkerActivation.slotted(scrambled, stage, {"poster": cap}))) \
					.is_equal(_sorted_keys(MarkerActivation.slotted(_markers(), stage, {"poster": cap})))


func test_kinds_are_capped_separately_and_an_uncapped_kind_is_unlimited() -> void:
	var markers: Array = _markers()
	markers.append({"id": &"q1", "kind": "queue", "min_stage": 1, "order": 7})
	markers.append({"id": &"q2", "kind": "queue", "min_stage": 1, "order": 8})
	var held: Dictionary = MarkerActivation.slotted(markers, 1, {"poster": 1})
	assert_array(_sorted_keys(held)).is_equal([&"p1", &"q1", &"q2"])


func test_the_mode_shows_the_slotted_posters_of_its_stage() -> void:
	var mode: OverworldMode = _mode()
	assert_int(mode.current_stage).is_equal(2)
	var shown: Array[StringName] = []
	for gag: GagInteractable in mode.get_map().gags():
		if gag.clutter_kind == "poster" and mode.is_gag_active(gag):
			shown.append(gag.marker_id)
	assert_array(shown).is_equal([&"p1", &"p2", &"p4", &"p6"])


func _markers() -> Array:
	var out: Array = []
	for i: int in _EXAMPLE.size():
		out.append({"id": StringName(_EXAMPLE[i][0]), "kind": "poster",
				"min_stage": _EXAMPLE[i][1], "order": i + 1})
	return out


func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return keys


## The segment (stage 2 under `permits_mandatory`) with the six posters
## added in example order and a Bureaucratia stage-2 record capping posters
## at 4.
func _mode() -> OverworldMode:
	var map: OverworldMap = (load(ProbeFixture.SEGMENT) as PackedScene).instantiate() as OverworldMap
	for i: int in _EXAMPLE.size():
		var gag: GagInteractable = ProbeFixture.gag(Vector2(4.0 + i, 14.5), GagInteractable.Response.LINE,
				StringName(_EXAMPLE[i][0]))
		gag.clutter_kind = "poster"
		gag.min_stage = _EXAMPLE[i][1]
		map.add_child(gag)
	var catalog := RecordCatalogDouble.new()
	var map_rec: MapData = load("res://data/maps/map_paris_segment_placeholder.tres")
	catalog.add(&"map", map_rec)
	var ostage := OccupationStageData.new()
	ostage.id = "ostage_fixture_stage2"
	ostage.faction_id = map_rec.faction_id
	ostage.stage = 2
	ostage.clutter_caps = {"poster": 4}
	catalog.add(&"occupation_stage", ostage)
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	mode.setup(GameStateFixtures.make_machine_in_overworld()["machine"], null)
	mode.world_state = WorldState.new()
	mode.world_state.set_flag("permits_mandatory")
	mode.encounter_catalog = catalog
	auto_free(mode)
	mode.load_map(map)
	return mode
