## Story 104, AC-42 (GDD Formulas `chapter_walk_budget`): the shipped
## chapter's `walk_share` is under `walk_share_max`, each leg's length is its
## `L_bypass`, and `passes(leg)` comes from the step list: a step list that
## names a leg twice doubles that leg's term.
extends GdUnitTestSuite

const _MAPS: Array[String] = ["town", "segment", "dungeon", "boss_chamber"]


func test_the_shipped_chapter_is_under_the_walk_share_cap() -> void:
	var cfg := OverworldConfig.new()
	var result: Dictionary = WalkBudget.compute(_steps(), _records(), _maps(), cfg)
	assert_array(Array(result["errors"])).is_empty()
	assert_float(result["share"]).is_less_equal(cfg.walk_share_max)
	assert_float(result["share"]).is_greater(0.0)
	# Every step's leg was measured (the dungeon's boss leg through the split).
	for step: ChapterStep in _steps().steps:
		assert_bool((result["legs"] as Dictionary).has("%s:%s" % [step.map_id, step.leg_id])).is_true()


func test_a_leg_named_twice_doubles_its_term() -> void:
	var cfg := OverworldConfig.new()
	var steps: ChapterSteps = _steps()
	var once: Dictionary = WalkBudget.compute(steps, _records(), _maps(), cfg)
	var twice := ChapterSteps.new()
	twice.steps = steps.steps.duplicate()
	var again: ChapterStep = (steps.steps[1] as ChapterStep).duplicate()
	again.id = "step_fixture_again"
	twice.steps.append(again)
	var doubled: Dictionary = WalkBudget.compute(twice, _records(), _maps(), cfg)
	var key: String = "%s:%s" % [again.map_id, again.leg_id]
	assert_int(int(doubled["passes"][key])).is_equal(2)
	var leg_time: float = cfg.k_tort * float(once["legs"][key]) / cfg.walk_speed
	assert_float(float(doubled["t_walk"]) - float(once["t_walk"])).is_equal_approx(leg_time, 1e-4)


func test_a_share_over_the_cap_is_an_error() -> void:
	var cfg := OverworldConfig.new()
	cfg.t_chapter_s = 10.0
	var result: Dictionary = WalkBudget.compute(_steps(), _records(), _maps(), cfg)
	assert_str("\n".join(result["errors"])).contains("walk_share")


func _steps() -> ChapterSteps:
	return load("res://data/chapters/chapter_paris_steps.tres")


func _records() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		var rec: MapData = load("res://data/maps/map_paris_%s_placeholder.tres" % name)
		out[rec.id] = rec
	return out


func _maps() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _MAPS:
		out["map_paris_%s_placeholder" % name] = auto_free(
				(load("res://data/maps/paris_%s_placeholder.tscn" % name) as PackedScene).instantiate())
	return out
