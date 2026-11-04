## SettingsService (ADR-0009 §7-8): defaults, validation, persistence, the
## debounced write, and SettingsViews relaying values to each consumer.
extends GdUnitTestSuite

const _PATH: String = "user://test_settings.json"

var _fs: MemorySaveFileSystem
var _clock: Array = [0.0]


func before_test() -> void:
	_fs = MemorySaveFileSystem.new()
	_clock[0] = 0.0


func _service() -> SettingsService:
	var config := SettingsConfig.new()
	config.path = _PATH
	var service: SettingsService = auto_free(SettingsService.new())
	var clock: Array = _clock
	service.setup(_fs, config, SettingsSchema.new(), func() -> float: return clock[0])
	return service


func _views(service: SettingsService) -> SettingsViews:
	var config := SettingsConfig.new()
	config.path = _PATH
	return SettingsViews.new(service, config)


func test_no_file_gives_every_default() -> void:
	var service := _service()
	var schema := SettingsSchema.new()
	for key: StringName in schema.keys():
		assert_that(service.get_value(key)).is_equal(schema.default_of(key))
	assert_bool(service.is_dirty()).is_false()


func test_set_value_flush_and_reload_round_trips() -> void:
	var service := _service()
	assert_bool(service.set_value(&"text_speed", "fast")).is_true()
	assert_bool(service.set_value(&"music_volume", 40)).is_true()
	assert_bool(service.set_value(&"reduce_flashing", true)).is_true()
	service.flush()
	assert_bool(_fs.files.has(_PATH)).is_true()

	var reloaded := _service()
	assert_str(reloaded.get_value(&"text_speed")).is_equal("fast")
	assert_int(reloaded.get_value(&"music_volume")).is_equal(40)
	assert_bool(reloaded.get_value(&"reduce_flashing")).is_true()


func test_illegal_values_are_refused() -> void:
	var service := _service()
	assert_bool(service.set_value(&"text_speed", "ludicrous")).is_false()
	assert_bool(service.set_value(&"master_volume", 101)).is_false()
	assert_bool(service.set_value(&"display_fullscreen", "yes")).is_false()
	assert_bool(service.set_value(&"no_such_key", 1)).is_false()
	assert_str(service.get_value(&"text_speed")).is_equal("normal")
	assert_bool(service.is_dirty()).is_false()


func test_invalid_field_in_file_falls_back_to_default_and_keeps_the_rest() -> void:
	_fs.files[_PATH] = JSON.stringify({"format": SettingsService.FORMAT, "version": 1,
			"body": {"master_volume": 250, "text_speed": "slow", "screen_shake": 3}})
	var service := _service()
	assert_int(service.get_value(&"master_volume")).is_equal(80)
	assert_str(service.get_value(&"text_speed")).is_equal("slow")
	assert_str(service.get_value(&"screen_shake")).is_equal("full")
	assert_array(Array(service.rejected_on_load)).contains_exactly_in_any_order(["master_volume", "screen_shake"])


func test_garbage_file_gives_defaults() -> void:
	_fs.files[_PATH] = "not json {"
	var service := _service()
	assert_str(service.get_value(&"text_speed")).is_equal("normal")


func test_write_waits_for_the_debounce_then_lands() -> void:
	var service := _service()
	service.set_value(&"sfx_volume", 50)
	service._process(0.0)
	assert_bool(_fs.files.has(_PATH)).override_failure_message("wrote before the delay").is_false()
	_clock[0] = 0.6
	service._process(0.0)
	assert_bool(_fs.files.has(_PATH)).is_true()
	assert_bool(service.is_dirty()).is_false()


func test_failed_write_stays_dirty() -> void:
	var service := _service()
	service.set_value(&"sfx_volume", 50)
	_fs.fail_write = true
	service.flush()
	assert_bool(service.is_dirty()).is_true()


func test_value_changed_fires_once_per_real_change() -> void:
	var service := _service()
	var seen: Array[StringName] = []
	service.value_changed.connect(func(key: StringName) -> void: seen.append(key))
	service.set_value(&"reduce_motion", true)
	service.set_value(&"reduce_motion", true)
	assert_array(seen).is_equal([&"reduce_motion"])


func test_views_relay_presentation_and_flash_settings_live() -> void:
	var service := _service()
	var views := _views(service)
	assert_bool(views.flash.reduce_flashing()).is_false()
	service.set_value(&"reduce_flashing", true)
	service.set_value(&"screen_shake", "off")
	service.set_value(&"reduce_motion", true)
	service.set_value(&"faster_battle_animations", true)
	service.set_value(&"speed_up_boss_entrances", true)
	assert_bool(views.flash.reduce_flashing()).is_true()
	assert_int(views.presentation.screen_shake).is_equal(PresentationSettings.ScreenShake.OFF)
	assert_bool(views.presentation.reduce_motion).is_true()
	assert_bool(views.presentation.faster_battle_animations).is_true()
	assert_bool(views.presentation.speed_up_boss_entrances).is_true()


func test_views_read_saved_values_at_boot() -> void:
	_fs.files[_PATH] = JSON.stringify({"format": SettingsService.FORMAT, "version": 1,
			"body": {"screen_shake": "reduced", "reduce_flashing": true}})
	var views := _views(_service())
	assert_int(views.presentation.screen_shake).is_equal(PresentationSettings.ScreenShake.REDUCED)
	assert_bool(views.flash.reduce_flashing()).is_true()


func test_text_speed_maps_to_typewriter_rate() -> void:
	var service := _service()
	var views := _views(service)
	assert_float(views.text_chars_per_s()).is_equal(45.0)
	service.set_value(&"text_speed", "fast")
	assert_float(views.text_chars_per_s()).is_equal(90.0)
	service.set_value(&"text_speed", "instant")
	assert_float(views.text_chars_per_s()).is_equal(0.0)


func test_volumes_drive_the_audio_buses() -> void:
	var service := _service()
	var views := _views(service)
	var music: int = AudioServer.get_bus_index(&"Music")
	assert_int(music).override_failure_message("default_bus_layout.tres has no Music bus").is_greater_equal(0)
	service.set_value(&"music_volume", 50)
	assert_float(AudioServer.get_bus_volume_db(music)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_bool(AudioServer.is_bus_mute(music)).is_false()
	service.set_value(&"music_volume", 0)
	assert_bool(AudioServer.is_bus_mute(music)).is_true()
	service.set_value(&"music_volume", 100)
	assert_bool(AudioServer.is_bus_mute(music)).is_false()
	assert_float(AudioServer.get_bus_volume_db(music)).is_equal_approx(0.0, 0.01)
	views.apply_audio()
	# Master back to its default so other suites hear nothing odd.
	service.set_value(&"master_volume", 80)
