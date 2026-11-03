## The visible half of refusal feedback (ADR-0008 §7; interaction pattern
## P3): a short side-to-side pulse on the refused control through 4.7's
## `offset_transform_position`, a visual offset that containers do not
## reset, so a button inside a VBox pulses without its layout moving. Scaled
## to zero under Reduce Motion. The tick is the UI service's (not built).
##
## Usage example:
## [codeblock]
## feedback.refused.connect(func(c: Control) -> void:
##     RefusalPulse.play(c, ui_config, settings.reduce_motion))
## [/codeblock]
class_name RefusalPulse
extends RefCounted

## Starts the pulse on `control` and returns its tween, or null when there
## is nothing to move (no control, Reduce Motion, or a zero-size pulse). A
## pulse already running on `control` is restarted from rest.
static func play(control: Control, config: UiConfig, reduce_motion: bool) -> Tween:
	if control == null or not control.is_inside_tree() or config == null:
		return null
	var px: float = 0.0 if reduce_motion else config.refusal_pulse_px
	control.offset_transform_enabled = true
	control.offset_transform_position = Vector2.ZERO
	if px <= 0.0 or config.refusal_pulse_time <= 0.0:
		return null
	var step: float = config.refusal_pulse_time / 4.0
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "offset_transform_position:x", px, step)
	tween.tween_property(control, "offset_transform_position:x", -px, step * 2.0)
	tween.tween_property(control, "offset_transform_position:x", 0.0, step)
	return tween
