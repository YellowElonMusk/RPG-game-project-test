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
		var gear: Dictionary = {}
		for slot: Variant in m.equipment:
			gear[String(slot)] = String(m.equipment[slot])
		members[m.record_id] = {"level": m.level, "xp": m.xp, "hp": m.hp, "mp": m.mp, "equipment": gear}
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
		# Items & Shops rule 12: slot -> item id; unknown slots and non-text
		# ids are dropped and reported.
		var gear: Dictionary = {}
		var raw_gear: Variant = e.get("equipment", {})
		if raw_gear is Dictionary:
			for slot: Variant in raw_gear:
				var item_id: Variant = raw_gear[slot]
				if Equipment.SLOTS.has(StringName(String(slot))) and item_id is String and not (item_id as String).is_empty():
					gear[String(slot)] = item_id
				else:
					reader.dropped.append("members.%s.equipment.%s: not a known slot and item" % [id, slot])
		members[String(id)] = {
			"level": clampi(int(e.get("level", 1)), 1, Leveling.LEVEL_MAX),
			"xp": maxi(0, int(e.get("xp", 0))),
			"hp": maxi(0, int(e.get("hp", 0))),
			"mp": maxi(0, int(e.get("mp", 0))),
			"equipment": gear,
		}
	return SaveStage.success({"members": members})


func commit(staged: SaveStage) -> void:
	_store.pending = (staged.staged as Dictionary).get("members", {})
	_store.squad = []


func reset_to_new_game() -> void:
	_store.pending = {}
	_store.squad = []
