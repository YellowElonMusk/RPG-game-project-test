## Test double: duck-typed record catalog (`get_record(type, id)`).
class_name RecordCatalogDouble
extends RefCounted

var _records: Dictionary = {}


## Adds `rec` under `type`, keyed by its `id`.
func add(type: StringName, rec: Resource) -> void:
	_records["%s/%s" % [type, rec.get(&"id")]] = rec


## The record, or null.
func get_record(type: StringName, id: String) -> Resource:
	return _records.get("%s/%s" % [type, id], null)


## Builds an `encounter` fixture record.
static func make_encounter(id: String) -> EncounterData:
	var rec := EncounterData.new()
	rec.id = id
	rec.enemy_ids = PackedStringArray(["enemy_fixture_clerk", "enemy_fixture_stamper"])
	rec.battle_stage_id = "stage_fixture_street"
	rec.faction_id = "faction_fixture"
	rec.is_boss = true
	rec.can_flee = false
	rec.retreat_allowed = true
	return rec
