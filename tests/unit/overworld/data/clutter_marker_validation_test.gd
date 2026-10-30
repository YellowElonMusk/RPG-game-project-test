## Story 117, AC-49 (GDD rule 16, guardrail 4): on every shipped map at every
## reachable stage (derived from the step list, O-04), every active clutter
## marker is a `gag` with a response or a route-blocker on the walk grid.
## O-04 denominator guard: the expected population is asserted first, so an
## empty population reports NOT ASSESSED, never a pass.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _SEGMENT: String = "map_paris_segment_placeholder"
const _QUEUE: StringName = &"poster_permit_queue"


func test_shipped_maps_every_active_clutter_marker_responds_or_blocks() -> void:
	var maps: Dictionary = _maps()
	var steps: ChapterSteps = _steps()
	var out: Dictionary = ClutterResponseCheck.check(steps, _records(), maps, _stage_records(), OverworldConfig.new())
	_free(maps)
	# Every map the step list visits is assessed at least once.
	for step: ChapterStep in steps.steps:
		var found: bool = false
		for a: String in out["assessed"]:
			found = found or a.begins_with(step.map_id + "@")
		assert_bool(found).override_failure_message("NOT ASSESSED: " + step.map_id).is_true()
	# The population is not empty: the segment's queue poster is active pre-liberation.
	assert_bool((out["checked"] as Array).is_empty()).override_failure_message("NOT ASSESSED: no active clutter marker").is_false()
	var queue_checked: bool = false
	for c: String in out["checked"]:
		queue_checked = queue_checked or c.begins_with("%s:%s@" % [_SEGMENT, _QUEUE])
	assert_bool(queue_checked).is_true()
	assert_array(Array(out["errors"])).is_empty()


func test_reachable_stages_come_from_the_step_list() -> void:
	var steps: ChapterSteps = _steps()
	var records: Dictionary = _records()
	var stages: Array = ClutterResponseCheck.reachable_stages(steps, records)
	assert_int(stages.size()).is_equal(steps.steps.size())
	var flags: Array = []
	for i: int in steps.steps.size():
		var step: ChapterStep = steps.steps[i]
		for f: String in step.flags_on_enter:
			flags.append(f)
		var rec: MapData = records[step.map_id]
		var expect: int = OccupationStage.compute(rec, func(f: String) -> bool: return flags.has(f), 0)[0]
		assert_str(String(stages[i][0])).is_equal(step.map_id)
		assert_int(int(stages[i][1])).is_equal(expect)
	assert_array(ClutterResponseCheck.reachable_stages(ChapterSteps.new(), records)).is_empty()


func test_empty_step_list_assesses_nothing() -> void:
	var maps: Dictionary = _maps()
	var out: Dictionary = ClutterResponseCheck.check(ChapterSteps.new(), _records(), maps, _stage_records(), OverworldConfig.new())
	_free(maps)
	assert_array(out["assessed"] as Array).is_empty()
	assert_array(out["checked"] as Array).is_empty()


func test_silent_marker_is_reported_with_map_marker_and_stage() -> void:
	var maps: Dictionary = _maps()
	var queue: GagInteractable = _gag(maps[_SEGMENT], _QUEUE)
	queue.text = ""
	var errors: PackedStringArray = ClutterResponseCheck.check(_steps(), _records(), maps, _stage_records(), OverworldConfig.new())["errors"]
	_free(maps)
	assert_int(errors.size()).is_greater_equal(1)
	assert_str(errors[0]).contains(_SEGMENT).contains(String(_QUEUE)).contains("stage 2")


func test_route_blocker_without_response_passes() -> void:
	var maps: Dictionary = _maps()
	var map: OverworldMap = maps[_SEGMENT]
	var queue: GagInteractable = _gag(map, _QUEUE)
	queue.text = ""
	var grid: WalkGrid = map.bake_walk_grid(OverworldConfig.new())
	var cell: Vector2i = grid.cell_of(queue.ground_position(map))
	assert_bool(grid.is_walkable(cell)).is_true()
	queue.blocked_rect = Rect2(Vector2(cell) * grid.cell_m, Vector2.ONE * grid.cell_m)
	var errors: PackedStringArray = ClutterResponseCheck.check(_steps(), _records(), maps, _stage_records(), OverworldConfig.new())["errors"]
	_free(maps)
	assert_array(Array(errors)).is_empty()


func test_blocker_rect_over_no_walkable_cell_blocks_nothing() -> void:
	var grid: WalkGrid = (maps_segment()).bake_walk_grid(OverworldConfig.new())
	var gag := GagInteractable.new()
	gag.blocked_rect = Rect2(Vector2(-10.0, -10.0), Vector2.ONE)
	assert_bool(ClutterResponseCheck.blocks_route(gag, grid)).is_false()
	gag.free()


func test_responses_need_their_content() -> void:
	var gag := GagInteractable.new()
	gag.text = "A line."
	for r: GagInteractable.Response in [GagInteractable.Response.LINE, GagInteractable.Response.CHANGE]:
		gag.response = r
		assert_bool(ClutterResponseCheck.responds(gag)).is_true()
	gag.response = GagInteractable.Response.CLUE
	assert_bool(ClutterResponseCheck.responds(gag)).is_false()
	gag.rumour_id = "rumour_fixture"
	assert_bool(ClutterResponseCheck.responds(gag)).is_true()
	gag.text = "  "
	assert_bool(ClutterResponseCheck.responds(gag)).is_false()
	gag.free()


func test_capped_out_marker_is_not_active() -> void:
	# A poster beyond its kind's cap holds no slot, so it is not checked.
	var maps: Dictionary = _maps()
	var map: OverworldMap = maps[_SEGMENT]
	var rec: MapData = _records()[_SEGMENT]
	var stage_records: Array = _stage_records()
	var cap: int = 0
	for r: Resource in stage_records:
		var o: OccupationStageData = r as OccupationStageData
		if o.faction_id == rec.faction_id and o.stage == 1:
			cap = int(o.clutter_caps.get("poster", 0))
	var silent: Array[StringName] = []
	for i: int in cap + 1:
		var gag := GagInteractable.new()
		gag.marker_id = StringName("silent_poster_%d" % i)
		gag.clutter_kind = "poster"
		map.add_child(gag)
		silent.append(gag.marker_id)
	var active: Array[GagInteractable] = ClutterResponseCheck.active_markers(map, rec, 1, [], stage_records)
	var active_silent: int = 0
	for g: GagInteractable in active:
		active_silent += 1 if silent.has(g.marker_id) else 0
	_free(maps)
	assert_int(active_silent).is_less_equal(cap)


func test_region_liberated_map_has_no_active_marker() -> void:
	var maps: Dictionary = _maps()
	var rec: MapData = _records()[_SEGMENT]
	var active: Array[GagInteractable] = ClutterResponseCheck.active_markers(maps[_SEGMENT], rec, 2,
			[rec.region_liberation_flag], _stage_records())
	var before: Array[GagInteractable] = ClutterResponseCheck.active_markers(maps[_SEGMENT], rec, 2, [], _stage_records())
	_free(maps)
	assert_array(active).is_empty()
	assert_bool(before.is_empty()).is_false()


func maps_segment() -> OverworldMap:
	return auto_free((load("res://data/maps/paris_segment_placeholder.tscn") as PackedScene).instantiate() as OverworldMap)


func _gag(map: OverworldMap, id: StringName) -> GagInteractable:
	for gag: GagInteractable in map.gags():
		if gag.marker_id == id:
			return gag
	return null


func _steps() -> ChapterSteps:
	return load(OverworldConfig.new().chapter_steps_path) as ChapterSteps


func _stage_records() -> Array:
	var out: Array = []
	for s: int in [1, 2, 3]:
		out.append(load("res://data/occupation_stages/ostage_bureaucratia_stage%d.tres" % s))
	return out


func _records() -> Dictionary:
	var out: Dictionary = {}
	for n: String in _MAPS:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % n) as MapData
		out[rec.id] = rec
	return out


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for n: String in _MAPS:
		var map: OverworldMap = (load("res://data/maps/paris_%s_placeholder.tscn" % n) as PackedScene) \
				.instantiate() as OverworldMap
		out[map.map_id] = map
	return out


func _free(maps: Dictionary) -> void:
	for map: OverworldMap in maps.values():
		map.free()
