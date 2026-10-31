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
##
## `capped = true` (the machine's `FlashGate` refused this transition's
## flash, or Reduce Flashing is On) plays the capped variant: the same fade,
## peaking at `TransitionConfig.capped_fade_peak_alpha` instead of full cover,
## a soft swell below `flash_luma_delta` (story 060 Finding 2). It no longer
## hides the swap; the input lock is unchanged.
class_name InterimFadePresenter
extends TransitionPresenter

const _FADE_COLOR: Color = Color(0x1B / 255.0, 0x24 / 255.0, 0x40 / 255.0, 1.0)
const _DEFAULT_CONFIG_PATH: String = "res://data/config/transition_config.tres"

var _rect: ColorRect
var _tween: Tween = null
var _capped_peak: float = 0.0


## `config` supplies `capped_fade_peak_alpha`; null loads the shipped
## `transition_config.tres` (callers that already hold one should pass it).
func _init(layer: CanvasLayer, config: TransitionConfig = null) -> void:
	if config == null:
		config = load(_DEFAULT_CONFIG_PATH) as TransitionConfig
	_capped_peak = clampf(config.capped_fade_peak_alpha, 0.0, 1.0) if config != null else 0.0
	_rect = ColorRect.new()
	_rect.color = _FADE_COLOR
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_rect)


## Starts OUT: locks input and fades up to full cover, or to the capped peak.
func play_out(_transition_type: StringName, duration: float, capped: bool = false) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_animate(0.0, _peak(capped), duration)


## Starts IN: fades from full cover (or the capped peak) back to clear.
func play_in(_transition_type: StringName, duration: float, capped: bool = false) -> void:
	_animate(_peak(capped), 0.0, duration)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _peak(capped: bool) -> float:
	return _capped_peak if capped else 1.0


func _animate(from_alpha: float, to_alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.modulate.a = from_alpha
	if duration <= 0.0:
		_rect.modulate.a = to_alpha
		return
	_tween = _rect.create_tween()
	_tween.tween_property(_rect, "modulate:a", to_alpha, duration)
