## The narrow Presentation view of the player's settings (ADR-0009 §7):
## the Battle mode receives one through `pre_setup` as
## `var presentation_settings` and hands it to `HitPunch`; no presentation
## code ever holds `SettingsService`. Until the settings service exists
## (ADR-0009, not yet built) a caller constructs this directly and injects
## the values; the adapter in `src/boot/settings_views.gd` will fill it later.
class_name PresentationSettings
extends RefCounted

## Screen Shake setting (ADR-0009 settings table: `full` / `reduced` / `off`).
enum ScreenShake { OFF, REDUCED, FULL }

## Emitted when any value changes; consumers re-read on the next frame.
signal changed

## Screen Shake: Full (the default), Reduced or Off.
var screen_shake: ScreenShake = ScreenShake.FULL:
	set(value):
		if value != screen_shake:
			screen_shake = value
			changed.emit()

## Reduce Motion: On turns the hit-punch off whatever Screen Shake says.
var reduce_motion: bool = false:
	set(value):
		if value != reduce_motion:
			reduce_motion = value
			changed.emit()

## Reduce Blur: On scales every blur (tilt-shift, battle background, Menu
## backdrop) by `reduce_blur_factor`, never brightness (story 028).
var reduce_blur: bool = false:
	set(value):
		if value != reduce_blur:
			reduce_blur = value
			changed.emit()

## Faster battle animations (ADR-0006's `set_speed_settings`).
var faster_battle_animations: bool = false:
	set(value):
		if value != faster_battle_animations:
			faster_battle_animations = value
			changed.emit()
## Speed up boss entrances (ADR-0006's `set_speed_settings`).
var speed_up_boss_entrances: bool = false:
	set(value):
		if value != speed_up_boss_entrances:
			speed_up_boss_entrances = value
			changed.emit()


## A view with the given comfort values (the other fields at defaults).
static func with_values(p_screen_shake: ScreenShake, p_reduce_motion: bool) -> PresentationSettings:
	var view := PresentationSettings.new()
	view.screen_shake = p_screen_shake
	view.reduce_motion = p_reduce_motion
	return view
