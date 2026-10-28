## Battle entry request data (ADR-0002 Key Interfaces). Provisional fields —
## pending the Overworld Exploration & Encounters and Turn Battle System ADRs.
class_name EncounterDescriptor extends RefCounted

var encounter_id: String = ""
var enemy_ids: PackedStringArray = PackedStringArray()
var battle_stage_id: String = ""
var faction_id: String = ""
var is_boss: bool = false
var can_flee: bool = true
var retreat_allowed: bool = false
