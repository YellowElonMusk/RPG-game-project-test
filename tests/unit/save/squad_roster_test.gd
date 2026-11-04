## Recruits beyond the first four (design/narrative/recruits.md): New Game
## starts with the four, a boss Victory's flag recruits the region's
## character at the squad's average level, the first four fight and the rest
## wait on the bench, the Menu swaps them, and a save keeps who joined and
## the order.
extends GdUnitTestSuite

const MIME := "char_street_mime"
const COMMUTER := "char_rush_hour_commuter"


func _store() -> SquadStore:
	var store := SquadStore.new()
	store.rebuild(BattleCatalog.shipped())
	return store


func _ids(members: Array[Combatant]) -> Array[String]:
	var out: Array[String] = []
	for m: Combatant in members:
		out.append(m.record_id)
	return out


func test_new_game_has_only_the_starting_four() -> void:
	var store := _store()
	assert_int(store.squad.size()).is_equal(SquadStore.ACTIVE_SIZE)
	assert_bool(store.has_member(MIME)).is_false()
	assert_array(store.bench()).is_empty()


func test_recruit_joins_at_the_average_level_with_full_hp_and_mp() -> void:
	var store := _store()
	for m: Combatant in store.squad:
		Leveling.apply_level(m, 5, BattleCatalog.shipped())
	var mime: Combatant = store.recruit(MIME, BattleCatalog.shipped())
	assert_object(mime).is_not_null()
	assert_int(mime.level).is_equal(5)
	assert_int(mime.xp).is_equal(Leveling.xp_total(5))
	assert_int(mime.hp).is_equal(mime.max_hp)
	assert_int(mime.mp).is_equal(mime.max_mp)
	assert_array(store.bench()).contains_exactly([mime])
	assert_int(store.active_party().size()).is_equal(SquadStore.ACTIVE_SIZE)


func test_recruit_refuses_a_duplicate_or_unknown_id() -> void:
	var store := _store()
	assert_object(store.recruit(MIME, BattleCatalog.shipped())).is_not_null()
	assert_object(store.recruit(MIME, BattleCatalog.shipped())).is_null()
	assert_int(store.squad.size()).is_equal(SquadStore.ACTIVE_SIZE + 1)


func test_sync_recruits_follows_the_liberation_flags_once() -> void:
	var store := _store()
	var ws := WorldState.new()
	assert_array(store.sync_recruits(ws, BattleCatalog.shipped())).is_empty()
	ws.set_flag("paris_liberated")
	assert_array(_ids(store.sync_recruits(ws, BattleCatalog.shipped()))).contains_exactly([MIME])
	assert_array(store.sync_recruits(ws, BattleCatalog.shipped())).is_empty()
	ws.set_flag("london_liberated")
	assert_array(_ids(store.sync_recruits(ws, BattleCatalog.shipped()))).contains_exactly([COMMUTER])


func test_swap_moves_a_bench_member_into_the_party() -> void:
	var store := _store()
	var mime: Combatant = store.recruit(MIME, BattleCatalog.shipped())
	var first: Combatant = store.squad[0]
	assert_bool(store.swap(0, 4)).is_true()
	assert_object(store.active_party()[0]).is_same(mime)
	assert_array(store.bench()).contains_exactly([first])
	assert_bool(store.swap(0, 9)).is_false()


func test_save_keeps_recruits_levels_and_the_order() -> void:
	var store := _store()
	for m: Combatant in store.squad:
		Leveling.apply_level(m, 4, BattleCatalog.shipped())
	store.recruit(MIME, BattleCatalog.shipped())
	store.swap(1, 4)
	var expect: PackedStringArray = store.order()
	var p := SquadSaveParticipant.new(store, BattleCatalog.shipped())
	var data: Dictionary = JSON.parse_string(JSON.stringify(p.capture()))

	var back := SquadStore.new()
	var p2 := SquadSaveParticipant.new(back, BattleCatalog.shipped())
	p2.commit(p2.stage(data, SaveReader.new(data, BattleCatalog.shipped())))
	back.rebuild(BattleCatalog.shipped())
	assert_array(Array(back.order())).is_equal(Array(expect))
	assert_int(back.active_party()[1].level).is_equal(4)
	assert_str(back.active_party()[1].record_id).is_equal(MIME)


func test_an_old_save_without_order_keeps_the_default_order() -> void:
	var data := {"members": {"char_karen": {"level": 2}}}
	var back := SquadStore.new()
	var p := SquadSaveParticipant.new(back, BattleCatalog.shipped())
	p.commit(p.stage(data, SaveReader.new(data, BattleCatalog.shipped())))
	back.rebuild(BattleCatalog.shipped())
	assert_array(Array(back.order())).is_equal(Array(_store().order()))


func test_a_recruit_gets_both_specials_from_its_records() -> void:
	var store := _store()
	var mime: Combatant = store.recruit(MIME, BattleCatalog.shipped())
	var names: Array[String] = []
	for move: Move in SquadMoves.moves_for(mime):
		names.append(move.display_name)
	assert_array(names).contains_exactly(["Attack", "Defend", "Invisible Rope", "Trapped in a Box"])


func test_every_recruit_record_has_two_specials_and_a_join_flag() -> void:
	var recruits: int = 0
	for rec: CharacterData in BattleCatalog.shipped().all_records(&"character"):
		if rec.joins_on_flag.is_empty():
			continue
		recruits += 1
		assert_int(rec.move_ids.size()).is_equal(2)
		var probe := ChapterFlow.make_member(rec)
		assert_int(SquadMoves.moves_for(probe).size()).is_equal(4)
	assert_int(recruits).is_equal(6)


func test_menu_party_screen_marks_the_bench_and_swaps() -> void:
	var store := _store()
	var mime: Combatant = store.recruit(MIME, BattleCatalog.shipped())
	var menu := InterimMenu.new()
	menu.world_state = WorldState.new()
	menu.item_catalog = BattleCatalog.shipped()
	menu.party = store.squad
	var payload := MenuPayload.new()
	payload.entries = [&"pause", &"party", &"quit"]
	menu.setup(null, payload)
	add_child(menu)
	auto_free(menu)
	assert_bool(menu.is_benched(mime)).is_true()
	menu.button_for(&"party").emit_signal(&"pressed")
	var bench_row: Button = _button_starting(menu, "[Bench] Street Mime")
	assert_object(bench_row).is_not_null()
	bench_row.emit_signal(&"pressed")
	_button_starting(menu, "Bring into the party").emit_signal(&"pressed")
	var karen_row: Button = _button_starting(menu, store.squad[0].display_name)
	var first: Combatant = store.squad[0]
	karen_row.emit_signal(&"pressed")
	# The Menu holds the store's array: the swap is the store's.
	assert_object(store.active_party()[0]).is_same(mime)
	assert_bool(menu.is_benched(first)).is_true()


func test_menu_refuses_a_swap_that_leaves_nobody_standing() -> void:
	var store := _store()
	var mime: Combatant = store.recruit(MIME, BattleCatalog.shipped())
	mime.hp = 0
	for i: int in range(1, SquadStore.ACTIVE_SIZE):
		store.squad[i].hp = 0
	var menu := InterimMenu.new()
	menu.world_state = WorldState.new()
	menu.item_catalog = BattleCatalog.shipped()
	menu.party = store.squad
	menu.setup(null, MenuPayload.new())
	add_child(menu)
	auto_free(menu)
	var standing: Combatant = store.squad[0]
	menu._swap(standing, mime)
	assert_object(store.squad[0]).is_same(standing)


func _button_starting(node: Node, prefix: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		var b: Button = child as Button
		if b.text.begins_with(prefix) and not b.is_queued_for_deletion():
			return b
	return null
