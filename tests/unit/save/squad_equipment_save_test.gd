## Items & Shops rule 12: each member's equipment is saved by slot and item
## id; a bad slot or id is dropped and reported; New Game builds a squad
## wearing nothing.
extends GdUnitTestSuite


func test_capture_writes_equipment_and_stage_keeps_valid_slots_only() -> void:
	var store := SquadStore.new()
	var karen := Combatant.new("Karen", 34, 12, 10, 6, 10, false, false, "char_karen")
	karen.equipment[&"outfit"] = "item_trench_coat"
	store.squad = [karen]
	var participant := SquadSaveParticipant.new(store, null)
	var captured: Dictionary = participant.capture()
	assert_dict(captured["members"]["char_karen"]["equipment"]).is_equal({"outfit": "item_trench_coat"})

	var raw: Dictionary = {"members": {"char_karen": {"level": 2, "xp": 30, "hp": 10, "mp": 5,
			"equipment": {"outfit": "item_trench_coat", "hat": "item_x", "weapon": 7}}}}
	var reader := SaveReader.new(raw)
	var staged: SaveStage = participant.stage(raw, reader)
	assert_dict((staged.staged as Dictionary)["members"]["char_karen"]["equipment"]).is_equal({"outfit": "item_trench_coat"})
	assert_int(reader.dropped.size()).is_equal(2)
