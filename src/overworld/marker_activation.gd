## The GDD `marker_activation` formula (story 058, rule 8): per clutter kind,
## the candidates are the markers with `min_stage <= stage`, sorted by
## (`min_stage`, marker order); the first `cap(kind)` of them hold a slot.
## A liberated marker keeps its slot (the street visibly empties), and
## sorting by `min_stage` first means a newly eligible marker joins the end
## of the list, never displacing one that already held a slot. Pure; no
## scene or world-state access.
##
## Usage example:
## [codeblock]
## var held: Dictionary = MarkerActivation.slotted(markers, 2, {"poster": 4})
## var shown: Array[StringName] = MarkerActivation.visible(markers, 2, {"poster": 4}, liberated, false)
## [/codeblock]
class_name MarkerActivation
extends RefCounted


## The IDs holding a slot, as a set (`id -> true`). `markers` is an Array of
## Dictionaries `{id: StringName, kind: String, min_stage: int, order: int}`;
## `caps` maps kind -> cap, and a kind absent from `caps` is uncapped.
static func slotted(markers: Array, stage: int, caps: Dictionary) -> Dictionary:
	var by_kind: Dictionary = {}
	for m: Dictionary in markers:
		if int(m["min_stage"]) > stage:
			continue
		var kind: String = m["kind"]
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(m)
	var held: Dictionary = {}
	for kind: String in by_kind:
		var candidates: Array = by_kind[kind]
		candidates.sort_custom(_before)
		var cap: int = int(caps[kind]) if caps.has(kind) else candidates.size()
		for i: int in mini(cap, candidates.size()):
			held[candidates[i]["id"]] = true
	return held


## The visible IDs in marker order: slotted, not in `liberated` (a set or an
## Array of IDs), and none once the region is liberated.
static func visible(markers: Array, stage: int, caps: Dictionary, liberated: Variant,
		region_liberated: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if region_liberated:
		return out
	var held: Dictionary = slotted(markers, stage, caps)
	var ordered: Array = markers.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	for m: Dictionary in ordered:
		if held.has(m["id"]) and not liberated.has(m["id"]):
			out.append(m["id"])
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["min_stage"]) != int(b["min_stage"]):
		return int(a["min_stage"]) < int(b["min_stage"])
	return int(a["order"]) < int(b["order"])
