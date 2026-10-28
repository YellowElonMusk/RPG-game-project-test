## Interim `TransitionPresenter` (story 035; ADR-0008 §2/§8 "interim
## presenter here", replaced by `UiTransitionPresenter` once UI Framework
## ships). Ink Navy (`#1B2440`) fade on `TransitionLayer`, fire-and-forget:
## the machine's own `tick()` timing is authoritative (`TransitionPresenter`'s
## own contract) -- this class never signals completion back and never
## blocks or extends a phase. Driven by the real engine clock (its own
## `Tween`, never `machine.tick()`'s `delta`) per TR-gamestate-006.
##
## Also the input-lock blocker (`MOUSE_FILTER_STOP`) while any transition is
## playing, since input is locked for the whole OUT+SWAP+IN window regardless
## of what visual plays (AC-8) -- set at the start of OUT and cleared at the
## start of IN, matching the machine's own lock/unlock window as closely as
## a fire-and-forget presenter can.
class_name InterimFadePresenter
extends TransitionPresenter

const _FADE_COLOR: Color = Color(0x1B / 255.0, 0x24 / 255.0, 0x40 / 255.0, 1.0)

var _rect: ColorRect
var _tween: Tween = null


func _init(layer: CanvasLayer) -> void:
	_rect = ColorRect.new()
	_rect.color = _FADE_COLOR
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_rect)


func play_out(_transition_type: StringName, duration: float, _capped: bool = false) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_animate(0.0, 1.0, duration)


func play_in(_transition_type: StringName, duration: float, _capped: bool = false) -> void:
	_animate(1.0, 0.0, duration)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _animate(from_alpha: float, to_alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.modulate.a = from_alpha
	if duration <= 0.0:
		_rect.modulate.a = to_alpha
		return
	_tween = _rect.create_tween()
	_tween.tween_property(_rect, "modulate:a", to_alpha, duration)
