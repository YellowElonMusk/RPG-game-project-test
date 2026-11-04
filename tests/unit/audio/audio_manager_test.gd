## Audio Manager (systems index #20): the event table's first-existing-file
## rule, the shipped table covering every id the code fires, silence on a
## missing file (logged once), bus routing, the music crossfade and the
## pure context rules in AudioIds.
extends GdUnitTestSuite

const _A: String = "res://a.ogg"
const _B: String = "res://b.wav"


func _table() -> AudioEventTable:
	var t := AudioEventTable.new()
	t.music = {"mus_a": PackedStringArray([_A]), "mus_b": PackedStringArray([_B]),
			"stg_win": PackedStringArray([_B])}
	t.ambience = {"amb_x": PackedStringArray([_A])}
	t.sfx = {"ui_confirm": PackedStringArray(["res://real.wav", _B])}
	t.crossfade_s = 1.0
	return t


## A fake stream that stays the same object per path.
var _streams: Dictionary = {}


func _fake_load(path: String) -> AudioStream:
	if not _streams.has(path):
		var wav := AudioStreamWAV.new()
		wav.mix_rate = 22050
		var data := PackedByteArray()
		data.resize(22050 * 2)
		wav.data = data
		_streams[path] = wav
	return _streams[path]


func _manager(exists: Callable) -> AudioManager:
	_streams = {}
	var m: AudioManager = auto_free(AudioManager.new())
	add_child(m)
	m.set_process(false)
	m.setup(_table(), exists, _fake_load)
	return m


func _all_exist(_p: String) -> bool:
	return true


func test_resolve_picks_the_first_existing_candidate() -> void:
	var t := _table()
	var only_b := func(p: String) -> bool: return p == _B
	assert_str(t.resolve(AudioEventTable.Kind.SFX, &"ui_confirm", only_b)).is_equal(_B)
	var real_too := func(p: String) -> bool: return true
	assert_str(t.resolve(AudioEventTable.Kind.SFX, &"ui_confirm", real_too)).is_equal("res://real.wav")
	assert_str(t.resolve(AudioEventTable.Kind.SFX, &"nope", real_too)).is_empty()


func test_shipped_table_lists_every_fired_id_and_each_resolves() -> void:
	var t: AudioEventTable = AudioEventTable.load_default()
	var exists := func(p: String) -> bool: return ResourceLoader.exists(p)
	var sfx: Array[StringName] = [AudioIds.UI_MOVE, AudioIds.UI_CONFIRM, AudioIds.UI_CANCEL,
			AudioIds.UI_REFUSED, AudioIds.UI_TEXT_BLIP, AudioIds.UI_SAVE, AudioIds.UI_BUY,
			AudioIds.BT_ENCOUNTER_START, AudioIds.BT_HIT, AudioIds.BT_HIT_HEAVY, AudioIds.BT_CRIT,
			AudioIds.BT_HEAL, AudioIds.BT_KO_SQUAD, AudioIds.BT_KO_ENEMY, AudioIds.BT_FLEE,
			AudioIds.BT_LEVEL_UP]
	sfx.append_array(OverworldSfx.ALL)
	for id: StringName in sfx:
		assert_str(t.resolve(AudioEventTable.Kind.SFX, id, exists)) \
				.override_failure_message("sfx %s has no file" % id).is_not_empty()
	for id: StringName in [AudioIds.MUS_TITLE, AudioIds.MUS_CREDITS, AudioIds.MUS_CAMP,
			AudioIds.BX_FLOOR_PULSE, AudioIds.STG_VICTORY, AudioIds.STG_VICTORY_BOSS, AudioIds.STG_DEFEAT]:
		assert_str(t.resolve(AudioEventTable.Kind.MUSIC, id, exists)) \
				.override_failure_message("music %s has no file" % id).is_not_empty()
	assert_str(t.resolve(AudioEventTable.Kind.AMBIENCE, AudioIds.AMB_CAMP, exists)).is_not_empty()


func test_every_shipped_map_has_its_own_music_and_ambience() -> void:
	var t: AudioEventTable = AudioEventTable.load_default()
	for path: String in ResourceLoader.list_directory("res://data/maps/"):
		if not path.ends_with(".tres"):
			continue
		var rec: MapData = load("res://data/maps/" + path) as MapData
		for liberated: bool in [false, true]:
			var first: StringName = AudioIds.overworld_music(rec.id, liberated)[0]
			assert_bool(t.has_id(AudioEventTable.Kind.MUSIC, first)) \
					.override_failure_message("%s (liberated %s) -> %s unlisted" % [rec.id, liberated, first]).is_true()
	for path: String in ResourceLoader.list_directory("res://data/occupation_stages/"):
		if not path.ends_with(".tres"):
			continue
		var o: OccupationStageData = load("res://data/occupation_stages/" + path) as OccupationStageData
		assert_bool(t.has_id(AudioEventTable.Kind.AMBIENCE, StringName(o.ambience_bed_id))) \
				.override_failure_message("%s unlisted" % o.ambience_bed_id).is_true()


func test_missing_files_are_silent_and_logged_once() -> void:
	var none := func(_p: String) -> bool: return false
	var m := _manager(none)
	m.play_music([&"mus_a"])
	m.play_music([&"mus_a"])
	m.play_ambience(&"amb_x")
	m.play_sfx(&"ui_confirm")
	m.advance(0.1)
	m.play_sfx(&"ui_confirm")
	m.play_sfx(&"unlisted_id")
	assert_str(String(m.current_music_id)).is_empty()
	assert_bool(m.is_fading()).is_false()
	# Each missing id is recorded exactly once, however often it is asked for.
	assert_int(m.missing_ids.size()).is_equal(4)
	assert_int(m.missing_ids.count("%d:mus_a" % AudioEventTable.Kind.MUSIC)).is_equal(1)


func test_columns_route_to_the_settings_buses() -> void:
	var m := _manager(_all_exist)
	assert_str(String(m.bus_of(AudioEventTable.Kind.MUSIC))).is_equal("Music")
	assert_str(String(m.bus_of(AudioEventTable.Kind.AMBIENCE))).is_equal("Music")
	assert_str(String(m.bus_of(AudioEventTable.Kind.SFX))).is_equal("SFX")
	# The shipped bus layout has both buses (SettingsViews drives them).
	assert_int(AudioServer.get_bus_index(&"Music")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index(&"SFX")).is_greater_equal(0)


func test_crossfade_runs_and_settles() -> void:
	var m := _manager(_all_exist)
	m.play_music([&"mus_a"])
	assert_str(String(m.current_music_id)).is_equal("mus_a")
	assert_bool(m.is_fading()).is_true()
	assert_float(m.music_volume_db()).is_equal(AudioManager.SILENT_DB)
	m.advance(0.5)
	assert_float(m.music_volume_db()).is_between(AudioManager.SILENT_DB + 1.0, -1.0)
	m.advance(0.6)
	assert_bool(m.is_fading()).is_false()
	assert_float(m.music_volume_db()).is_equal(0.0)
	# The same id again changes nothing; a new id starts a new fade.
	m.play_music([&"mus_a"])
	assert_bool(m.is_fading()).is_false()
	m.play_music([&"mus_b"])
	assert_str(String(m.current_music_id)).is_equal("mus_b")
	assert_bool(m.is_fading()).is_true()


func test_first_id_with_a_file_wins_and_none_fades_out() -> void:
	var only_b := func(p: String) -> bool: return p == _B
	var m := _manager(only_b)
	m.play_music([&"mus_a", &"mus_b"])
	assert_str(String(m.current_music_id)).is_equal("mus_b")
	m.advance(2.0)
	m.play_music([&"mus_a"])
	assert_str(String(m.current_music_id)).is_empty()
	assert_bool(m.is_fading()).is_true()


func test_loops_loop_and_stings_play_once() -> void:
	var m := _manager(_all_exist)
	m.play_music([&"mus_a"])
	assert_int((_streams[_A] as AudioStreamWAV).loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	m.play_music([&"stg_win"])
	assert_int((_streams[_B] as AudioStreamWAV).loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)


func test_same_sfx_is_not_restarted_within_the_gap() -> void:
	var m := _manager(_all_exist)
	m.play_sfx(&"ui_confirm")
	m.play_sfx(&"ui_confirm")
	assert_int(m.sfx_log.size()).is_equal(1)
	m.advance(AudioManager.SFX_REPEAT_GAP_S + 0.01)
	m.play_sfx(&"ui_confirm")
	assert_int(m.sfx_log.size()).is_equal(2)


func test_battle_music_uses_the_beatbox_seam_when_it_takes_the_fight() -> void:
	var m := _manager(_all_exist)
	m.setup(_table_with_pulse(), _all_exist, _fake_load)
	m.play_battle_music(null)
	assert_str(String(m.current_music_id)).is_equal(String(AudioIds.BX_FLOOR_PULSE))
	m.battle_music_provider = func(_d: EncounterDescriptor) -> bool: return true
	m.play_battle_music(null)
	assert_str(String(m.current_music_id)).is_equal("beatbox")


func _table_with_pulse() -> AudioEventTable:
	var t := _table()
	t.music[String(AudioIds.BX_FLOOR_PULSE)] = PackedStringArray([_A])
	return t


func test_map_ids_pick_city_kind_then_generic_music() -> void:
	assert_dict(AudioIds.parse_map_id("map_paris_boss_chamber_placeholder")) \
			.is_equal({"city": "paris", "kind": "boss_chamber"})
	assert_dict(AudioIds.parse_map_id("debug_map")).is_equal({"city": "", "kind": ""})
	assert_array(AudioIds.overworld_music("map_london_dungeon_placeholder", false)) \
			.is_equal([&"mus_london_dungeon", &"mus_ow_dungeon", &"mus_ow_town"])
	assert_array(AudioIds.overworld_music("map_sydney_town_placeholder", true)) \
			.is_equal([&"mus_sydney_liberated", &"mus_ow_liberated", &"mus_sydney_town", &"mus_ow_town"])
	assert_array(AudioIds.victory_sting(true)).is_equal([AudioIds.STG_VICTORY_BOSS, AudioIds.STG_VICTORY])


func test_beat_and_ui_sfx_rules() -> void:
	var hero := Combatant.new("Hero", 10, 5, 5, 5, 5, false)
	var foe := Combatant.new("Foe", 10, 5, 5, 5, 5, true)
	var plan := BeatPlan.new()
	plan.reactions = {foe: BeatPlan.Reaction.HIT}
	plan.punch = true
	assert_str(String(AudioIds.beat_sfx(plan))).is_equal(String(AudioIds.BT_HIT))
	plan.big_punch = true
	assert_str(String(AudioIds.beat_sfx(plan))).is_equal(String(AudioIds.BT_HIT_HEAVY))
	plan.reactions = {foe: BeatPlan.Reaction.KNOCKOUT}
	plan.knockout = true
	assert_str(String(AudioIds.beat_sfx(plan))).is_equal(String(AudioIds.BT_KO_ENEMY))
	plan.reactions = {hero: BeatPlan.Reaction.KNOCKOUT}
	assert_str(String(AudioIds.beat_sfx(plan))).is_equal(String(AudioIds.BT_KO_SQUAD))
	var heal := BeatPlan.new()
	heal.reactions = {hero: BeatPlan.Reaction.HEAL}
	assert_str(String(AudioIds.beat_sfx(heal))).is_equal(String(AudioIds.BT_HEAL))
	assert_str(String(AudioIds.beat_sfx(BeatPlan.new()))).is_empty()
	assert_str(String(AudioIds.ui_sfx(InputActions.NAV_DOWN))).is_equal(String(AudioIds.UI_MOVE))
	assert_str(String(AudioIds.ui_sfx(InputActions.CONFIRM))).is_equal(String(AudioIds.UI_CONFIRM))
	assert_str(String(AudioIds.ui_sfx(InputActions.CANCEL))).is_equal(String(AudioIds.UI_CANCEL))
	assert_str(String(AudioIds.ui_sfx(InputActions.MENU))).is_empty()
