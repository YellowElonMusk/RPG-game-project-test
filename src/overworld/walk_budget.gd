## The chapter walk budget (GDD Formulas `chapter_walk_budget`; story 104,
## AC-42): `T_walk = k_tort * sum over the step list of L_bypass(step's leg)
## / walk_speed`, `walk_share = T_walk / T_chapter <= walk_share_max`. Each
## step adds its leg once, so `passes(leg)` is counted from the data: a leg
## two steps name counts twice. Symbols carry no stage gate, so a leg's
## `L_bypass` is the same at every reachable stage. Pure static.
class_name WalkBudget
extends RefCounted


## `{"t_walk": s, "share": 0-1, "legs": {"map:leg": metres per pass},
## "passes": {"map:leg": n}, "errors": PackedStringArray}`. `maps` is
## map_id -> OverworldMap, `records` map_id -> MapData.
static func compute(steps: ChapterSteps, records: Dictionary, maps: Dictionary,
		cfg: OverworldConfig) -> Dictionary:
	var legs: Dictionary = {}
	var passes: Dictionary = {}
	var errors := PackedStringArray()
	var total: float = 0.0
	for step: ChapterStep in steps.steps:
		var key: String = "%s:%s" % [step.map_id, step.leg_id]
		if not legs.has(key):
			var rec: MapData = records.get(step.map_id) as MapData
			var map: OverworldMap = maps.get(step.map_id) as OverworldMap
			var length: float = INF
			if rec != null and map != null:
				for leg: CriticalPathLeg in rec.critical_path:
					if leg != null and leg.id == step.leg_id:
						length = BypassSearch.bypass_length(map, leg, cfg)
			if length == INF:
				errors.append("walk budget: step '%s' leg %s has no measurable bypass lane" % [step.id, key])
				continue
			legs[key] = length
		passes[key] = int(passes.get(key, 0)) + 1
		total += legs[key]
	var t_walk: float = cfg.k_tort * total / cfg.walk_speed
	var share: float = t_walk / cfg.t_chapter_s
	if share > cfg.walk_share_max:
		errors.append("walk budget: walk_share %.3f > walk_share_max %.2f (T_walk %.0f s)"
				% [share, cfg.walk_share_max, t_walk])
	return {"t_walk": t_walk, "share": share, "legs": legs, "passes": passes, "errors": errors}
