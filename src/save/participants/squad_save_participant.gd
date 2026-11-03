## Saves each squad member's level, XP, HP and MP by character ID (Leveling
## GDD rule 7; ADR-0009 §3: IDs, never definitions). Stats are rebuilt from
## the record on load, never stored. A member whose character no longer
## exists is dropped and reported; numbers are clamped (GDD edge cases).
class_name SquadSaveParticipant
extends SaveParticipant

var _store: SquadStore
var _catalog: ContentCatalogService


func _init(store: SquadStore, catalog: ContentCatalogService) -> void:
	_store = store
	_catalog = catalog


func save_key() -> StringName:
	return &"squad"


func schema_version() -> int:
	return 1


func capture() -> Dictionary:
	var members: Dictionary = {}
	for m: Combatant in _store.squad:
		if m.record_id.is_empty():
			continue
		members[m.record_id] = {"level": m.level, "xp": m.xp, "hp": m.hp, "mp": m.mp}
	return {"members": members}


func stage(data: Dictionary, reader: SaveReader) -> SaveStage:
	var members: Dictionary = {}
	var raw: Dictionary = reader.get_dict("members")
	for id: Variant in raw:
		var entry: Variant = raw[id]
		if not (entry is Dictionary):
			reader.dropped.append("members.%s: not a table" % id)
			continue
		if _catalog != null and _catalog.get_record(&"character", String(id)) == null:
			reader.dropped.append("members.%s: unknown character" % id)
			continue
		var e: Dictionary = entry
		members[String(id)] = {
			"level": clampi(int(e.get("level", 1)), 1, Leveling.LEVEL_MAX),
			"xp": maxi(0, int(e.get("xp", 0))),
			"hp": maxi(0, int(e.get("hp", 0))),
			"mp": maxi(0, int(e.get("mp", 0))),
		}
	return SaveStage.success({"members": members})


func commit(staged: SaveStage) -> void:
	_store.pending = (staged.staged as Dictionary).get("members", {})
	_store.squad = []


func reset_to_new_game() -> void:
	_store.pending = {}
	_store.squad = []
