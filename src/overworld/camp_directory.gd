## Where every camp returns the party to, read once from the map scenes
## (GDD rules 11, 13, 13a; story 089). `camp_id` -> its map and its
## CampSpot's return EntryPoint, plus the region default camp (the Town
## café), the Retreat target before any camp is registered
## (`game-state-scene-flow.md` Edge Cases).
##
## Deviation from ADR-0012 §4, flagged: the ADR keeps
## `world_state.camp_returns[camp_id]`, filled when a camp is registered.
## Every CampSpot's return is fixed map data, so this directory holds them
## all from boot instead; nothing about a return changes at runtime.
##
## Usage example:
## [codeblock]
## var dir := CampDirectory.from_catalog(catalog, cfg)
## var entry: MapEntryPayload = dir.return_payload(machine.last_camp_id)
## [/codeblock]
class_name CampDirectory
extends RefCounted

## camp_id -> MapEntryPayload (the camp's map and its return EntryPoint).
var _returns: Dictionary = {}
## The region default camp's ID, or "" when no map has one.
var region_default_camp_id: String = ""


## Reads every `map` record's scene for its CampSpots.
static func from_catalog(catalog: ContentCatalogService, cfg: OverworldConfig) -> CampDirectory:
	var dir := CampDirectory.new()
	for rec: Resource in catalog.all_records(&"map"):
		var map_id: String = String(rec.get("id"))
		var path: String = OverworldMap.scene_path(map_id, cfg.map_scene_dir)
		if not ResourceLoader.exists(path):
			continue
		var map: OverworldMap = (ResourceLoader.load(path) as PackedScene).instantiate() as OverworldMap
		if map == null:
			continue
		dir.add_map(map)
		map.free()
	return dir


## Adds `map`'s CampSpots (tests, `from_catalog()`).
func add_map(map: OverworldMap) -> void:
	for camp: CampSpot in map.camp_spots():
		_returns[camp.camp_id] = MapEntryPayload.new(map.map_id, camp.return_entry_id)
		if camp.is_region_default:
			region_default_camp_id = camp.camp_id


## Where resting at `camp_id` returns the party: its map and return
## EntryPoint. An empty or unknown ID falls back to the region default camp;
## null when there is none.
func return_payload(camp_id: String) -> MapEntryPayload:
	var id: String = camp_id if _returns.has(camp_id) else region_default_camp_id
	var p: MapEntryPayload = _returns.get(id) as MapEntryPayload
	return MapEntryPayload.new(p.map_id, p.entry_marker_id) if p != null else null


## `true` when `camp_id` is a known camp.
func has_camp(camp_id: String) -> bool:
	return _returns.has(camp_id)
