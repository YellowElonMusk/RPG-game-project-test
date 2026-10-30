## Story 055, AC-23b (GDD rules 8, 18): Paris's stage content rules, each
## part failing with its own named message.
## - Base stages: Town 1, segment 1, dungeon 3; a map with no `base_stage`
##   (the boss chamber) reports no stage.
## - Bureaucratia's `occupation_stage` records: civilian density
##   non-increasing and every clutter cap non-decreasing over stages 1-3 (I13).
## - Every stage-raising flag: set by a ChapterFlow step change, on a step
##   before any step whose map it raises, with no earlier route into a
##   raised map; its stage record names a decree gag that stands at every
##   EntryPoint a MapExit targets on each raised map.
## - The segment's reachable stages, from the step list, are exactly {2}.
## - Every flag a map, checkpoint, marker or step reads is registered.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]
const _REGISTRY: String = "res://data/chapters/chapter_paris_flags.tres"
const _STEPS: String = "res://data/chapters/chapter_paris_steps.tres"
const _OSTAGE: String = "res://data/occupation_stages/ostage_bureaucratia_stage%d.tres"
const _SEGMENT_ID: String = "map_paris_segment_placeholder"


func test_base_stages_and_the_stageless_boss_chamber() -> void:
	for pair: Array in [["town", 1], ["segment", 1], ["dungeon", 3]]:
		assert_int(_record(pair[0]).base_stage).override_failure_message(
				"base stage: map_paris_%s_placeholder should be %d" % pair).is_equal(pair[1])
	var none: Array = OccupationStage.compute(_record("boss_chamber"), func(_f: String) -> bool: return true, 0)
	assert_int(none[0]).override_failure_message("no base stage: the boss chamber reports a stage").is_equal(0)


func test_density_never_rises_and_caps_never_fall_across_stages() -> void:
	for s: int in [1, 2]:
		var lo: OccupationStageData = load(_OSTAGE % s)
		var hi: OccupationStageData = load(_OSTAGE % (s + 1))
		assert_float(hi.civilian_density).override_failure_message(
				"density: stage %d (%.2f) above stage %d (%.2f)" % [s + 1, hi.civilian_density, s, lo.civilian_density]) \
				.is_less_equal(lo.civilian_density)
		for kind: String in lo.clutter_caps:
			assert_int(int(hi.clutter_caps.get(kind, -1))).override_failure_message(
					"I13: %s cap falls from stage %d to %d" % [kind, s, s + 1]) \
					.is_greater_equal(lo.clutter_caps[kind])


func test_raising_flags_are_scheduled_by_chapter_steps_before_their_maps() -> void:
	var registry: StoryFlagRegistry = load(_REGISTRY)
	var steps: Array[ChapterStep] = (load(_STEPS) as ChapterSteps).steps
	var raising: Dictionary = _raising_flags()
	assert_bool(raising.is_empty()).override_failure_message("no stage-raising flag found").is_false()
	for flag: String in raising:
		assert_str(registry.set_by(flag)).override_failure_message(
				"trigger: %s is not set by a ChapterFlow step change" % flag).is_equal(StoryFlagRegistry.CHAPTER_STEP)
		var set_at: int = _step_setting(steps, flag)
		assert_int(set_at).override_failure_message("schedule: no step sets %s" % flag).is_greater_equal(0)
		for map_id: String in raising[flag]:
			for i: int in steps.size():
				if steps[i].map_id == map_id:
					assert_int(set_at).override_failure_message(
							"schedule: %s is set on step %d, not before step %d on %s" % [flag, set_at, i, map_id]) \
							.is_less(i)
			# No earlier route: trivially met on the opening step; a later
			# step must leave the raised map out of the exit graph's reach.
			if set_at > 0:
				assert_bool(_reachable_from_start().has(map_id)).override_failure_message(
						"no earlier route: %s is reachable before %s is set" % [map_id, flag]).is_false()


func test_raising_flags_name_a_decree_gag_at_every_targeted_entry_point() -> void:
	var raising: Dictionary = _raising_flags()
	for flag: String in raising:
		for map_id: String in raising[flag]:
			var stage: int = int((_record_by_id(map_id)).stage_table[flag])
			var ostage: OccupationStageData = _ostage_for(_record_by_id(map_id).faction_id, stage)
			assert_object(ostage).override_failure_message("decree: no stage %d record for %s" % [stage, map_id]).is_not_null()
			var decree: String = ostage.decree_gag_by_flag.get(flag, "")
			assert_str(decree).override_failure_message("decree: the stage %d record names none for %s" % [stage, flag]).is_not_empty()
			var map: OverworldMap = auto_free(_scene(map_id))
			for entry_id: StringName in _targeted_entries(map_id):
				var at: Vector2 = map.find_entry_point(entry_id).ground_position(map)
				var found: bool = false
				for gag: GagInteractable in map.gags():
					if gag.decree_stage == stage and String(gag.marker_id).begins_with(decree) \
							and gag.ground_position(map).distance_to(at) <= OverworldConfig.new().interact_reach_m * 2.0:
						found = true
				assert_bool(found).override_failure_message(
						"decree: no %s gag at %s's EntryPoint %s" % [decree, map_id, entry_id]).is_true()


func test_the_segment_reaches_only_stage_2() -> void:
	var steps: Array[ChapterStep] = (load(_STEPS) as ChapterSteps).steps
	var segment: MapData = _record("segment")
	var reached: Dictionary = {}
	var flags: Dictionary = {}
	# Flags set on a step's entry hold before the player has control on it,
	# and the segment is loadable from every step on (no gate before it).
	for step: ChapterStep in steps:
		for f: String in step.flags_on_enter:
			flags[f] = true
		reached[OccupationStage.compute(segment, func(f: String) -> bool: return flags.has(f), 0)[0]] = true
	assert_array(reached.keys()).is_equal([2])


func test_every_read_flag_is_registered() -> void:
	var registry: StoryFlagRegistry = load(_REGISTRY)
	for flag: String in _read_flags():
		assert_bool(registry.has_flag(flag)).override_failure_message(
				"registry: %s is read but not registered" % flag).is_true()


## Flag -> [map IDs whose `stage_table` it raises].
func _raising_flags() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = _record(name)
		for flag: String in rec.stage_table:
			if rec.stage_table[flag] > rec.base_stage:
				if not out.has(flag):
					out[flag] = []
				(out[flag] as Array).append(rec.id)
	return out


func _read_flags() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = _record(name)
		for flag: String in rec.stage_table:
			out[flag] = true
		if not rec.region_liberation_flag.is_empty():
			out[rec.region_liberation_flag] = true
		var map: OverworldMap = auto_free(_scene(rec.id))
		for cp: CheckpointMarker in map.checkpoints():
			if not cp.requirement_flag.is_empty():
				out[cp.requirement_flag] = true
		for gag: GagInteractable in map.gags():
			if not gag.liberation_flag.is_empty():
				out[gag.liberation_flag] = true
	for step: ChapterStep in (load(_STEPS) as ChapterSteps).steps:
		for f: String in step.flags_on_enter:
			out[f] = true
	return out


func _step_setting(steps: Array[ChapterStep], flag: String) -> int:
	for i: int in steps.size():
		if steps[i].flags_on_enter.has(flag):
			return i
	return -1


## Maps the exit graph reaches from the New Game map (ignores checkpoints,
## so it over-approximates every walk-grid route).
func _reachable_from_start() -> Dictionary:
	var start: String = ""
	for name: String in _MAPS:
		if _record(name).new_game_entry:
			start = _record(name).id
	var seen: Dictionary = {start: true}
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var map: OverworldMap = auto_free(_scene(frontier.pop_back()))
		for exit: MapExit in map.map_exits():
			if not seen.has(exit.target_map_id):
				seen[exit.target_map_id] = true
				frontier.append(exit.target_map_id)
	return seen


## Every EntryPoint on `map_id` that some Paris MapExit targets.
func _targeted_entries(map_id: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for name: String in _MAPS:
		var map: OverworldMap = auto_free(_scene(_record(name).id))
		for exit: MapExit in map.map_exits():
			if exit.target_map_id == map_id and not out.has(exit.target_entry_id):
				out.append(exit.target_entry_id)
	return out


func _ostage_for(faction_id: String, stage: int) -> OccupationStageData:
	for s: int in [1, 2, 3]:
		var rec: OccupationStageData = load(_OSTAGE % s)
		if rec.faction_id == faction_id and rec.stage == stage:
			return rec
	return null


func _record(name: String) -> MapData:
	return load("res://data/maps/map_paris_%s_placeholder.tres" % name)


func _record_by_id(map_id: String) -> MapData:
	return load("res://data/maps/%s.tres" % map_id)


## The scene by ID convention (`map_` dropped).
func _scene(map_id: String) -> OverworldMap:
	return (load("res://data/maps/%s.tscn" % map_id.trim_prefix("map_")) as PackedScene).instantiate() as OverworldMap
