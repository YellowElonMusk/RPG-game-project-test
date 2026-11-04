## The composition root's settings adapters (ADR-0009 §7): turns
## `SettingsService` values into each consumer's own narrow view and applies
## the machine-wide ones (display, audio buses). No consumer holds the
## service; they hold `presentation`, `flash` or a text speed.
##
## Usage example:
## [codeblock]
## var views := SettingsViews.new(settings_service, SettingsConfig.new())
## battle_mode.presentation_settings = views.presentation
## flash_gate.setup(clock, config, decls, views.flash)
## dialogue.chars_per_s = views.text_chars_per_s()
## [/codeblock]
class_name SettingsViews
extends RefCounted

## Battle and diorama comfort/speed settings, kept in step with the service.
var presentation: PresentationSettings = PresentationSettings.new()
## Reduce Flashing for `FlashGate`, kept in step with the service.
var flash: FlashSettings = FlashSettings.new()
## When false, display settings are not pushed to `DisplayServer` (headless
## runs and tests).
var apply_display: bool = DisplayServer.get_name() != "headless"

var _service: SettingsService = null
var _config: SettingsConfig = null


func _init(service: SettingsService, config: SettingsConfig) -> void:
	_service = service
	_config = config
	_service.value_changed.connect(_on_value_changed)
	for key: StringName in [&"screen_shake", &"reduce_motion", &"reduce_blur", &"reduce_flashing",
			&"faster_battle_animations", &"speed_up_boss_entrances"]:
		_sync(key)
	apply_audio()
	apply_display_settings()


## The dialogue typewriter speed for the current text speed (0 = instant).
func text_chars_per_s() -> float:
	return _config.text_speed_cps.get(str(_service.get_value(&"text_speed")), 45.0)


## Sets every configured bus's volume from its setting; 0 mutes the bus.
## Buses missing from the layout are skipped.
func apply_audio() -> void:
	for key: String in _config.volume_buses:
		var bus: int = AudioServer.get_bus_index(_config.volume_buses[key])
		if bus < 0:
			continue
		var pct: int = int(_service.get_value(StringName(key)))
		AudioServer.set_bus_mute(bus, pct <= 0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(pct, 1) / 100.0))


## Fullscreen and vsync (skipped when `apply_display` is false).
func apply_display_settings() -> void:
	if not apply_display:
		return
	var full: bool = bool(_service.get_value(&"display_fullscreen"))
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if full and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not full and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED
			if bool(_service.get_value(&"display_vsync")) else DisplayServer.VSYNC_DISABLED)


func _on_value_changed(key: StringName) -> void:
	if _config.volume_buses.has(String(key)):
		apply_audio()
	elif key == &"display_fullscreen" or key == &"display_vsync":
		apply_display_settings()
	else:
		_sync(key)


func _sync(key: StringName) -> void:
	var v: Variant = _service.get_value(key)
	match key:
		&"screen_shake":
			presentation.screen_shake = {"full": PresentationSettings.ScreenShake.FULL,
					"reduced": PresentationSettings.ScreenShake.REDUCED,
					"off": PresentationSettings.ScreenShake.OFF}.get(v, PresentationSettings.ScreenShake.FULL)
		&"reduce_motion":
			presentation.reduce_motion = bool(v)
		&"reduce_blur":
			presentation.reduce_blur = bool(v)
		&"faster_battle_animations":
			presentation.faster_battle_animations = bool(v)
		&"speed_up_boss_entrances":
			presentation.speed_up_boss_entrances = bool(v)
		&"reduce_flashing":
			flash.reduce_flashing_on = bool(v)
