## Button-prompt labels for an action on a device (GDD rule 9's "[fast_forward]"
## glyph; ADR-0008 §12): the first binding of `action` for that device, from
## the shipped `InputBindings`. Keys show their name ("Shift"); gamepad
## buttons show the face name for the pad style ("X" on Xbox, "Square" on
## PlayStation). INTERIM stand-in for the UI Framework's `PromptFacade`,
## which will draw real glyph images.
##
## Usage example:
## [codeblock]
## var glyphs := PromptGlyphs.new(bindings, PromptGlyphs.DEVICE_PAD, &"xbox")
## label.text = "[%s] Speed up" % glyphs.label(InputActions.FAST_FORWARD)
## [/codeblock]
class_name PromptGlyphs
extends RefCounted

## `InputBindings` device ids.
const DEVICE_KEY: StringName = &"key"
const DEVICE_PAD: StringName = &"pad"

## Face buttons by pad style: south, east, west, north.
const _FACE: Dictionary = {
	&"xbox": {"south": "A", "east": "B", "west": "X", "north": "Y"},
	&"playstation": {"south": "Cross", "east": "Circle", "west": "Square", "north": "Triangle"},
	&"nintendo": {"south": "B", "east": "A", "west": "Y", "north": "X"},
}
## Every other pad input, any style.
const _PAD_OTHER: Dictionary = {
	"left_shoulder": "LB", "right_shoulder": "RB", "left_trigger": "LT",
	"right_trigger": "RT", "start": "Start", "back": "Select",
	"dpad_up": "Up", "dpad_down": "Down", "dpad_left": "Left", "dpad_right": "Right",
}

var _bindings: InputBindings = null
var device: StringName = DEVICE_KEY
var pad_style: StringName = &"generic"


func _init(bindings: InputBindings, p_device: StringName = DEVICE_KEY,
		p_pad_style: StringName = &"generic") -> void:
	_bindings = bindings
	device = p_device
	pad_style = p_pad_style


## The prompt label for `action` on this device, or the action's name when
## it has no binding there.
func label(action: StringName) -> String:
	if _bindings != null:
		for entry: Dictionary in _bindings.bindings:
			if StringName(entry.get("action", "")) == action and StringName(entry.get("device", "")) == device:
				return _name_for(String(entry.get("input", "")))
	return String(action)


func _name_for(input: String) -> String:
	if device == DEVICE_KEY:
		return input
	var faces: Dictionary = _FACE.get(pad_style, {})
	if faces.has(input):
		return faces[input]
	if _PAD_OTHER.has(input):
		return _PAD_OTHER[input]
	return input.capitalize()
