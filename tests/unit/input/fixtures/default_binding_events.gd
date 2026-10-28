## The literal event fixture for `bindings_default.tres` (ADR-0003
## Implementation Notes, story 001: "no circular test"). Each default binding
## triple maps to a hand-written engine literal -- a `KEY_*` / `JOY_BUTTON_*`
## constant for `key`/`pad`, or `[JoyAxis, signed value]` for `pad_axis` --
## never to `OS.find_keycode_from_string()` or the resolver's own token
## tables. A token that resolves to `KEY_NONE` (or an unrecognized pad token)
## therefore still fails a test built from this fixture, because the fixture
## never calls the same parser the resolver does.
##
## The dictionary key is the triple's identity, `"action:device:input"`,
## matching one entry of `data/bindings/bindings_default.tres`. `EVENTS.size()`
## must equal `bindings.bindings.size()` (asserted by
## `input_default_bindings_test.gd`), which catches a triple added to the data
## with no literal row here.
##
## Usage example:
## [codeblock]
## for triple_key: String in DefaultBindingEvents.EVENTS:
##     var parts := triple_key.split(":", true, 2)
##     var action := parts[0]
##     var device := parts[1]
##     var literal: Variant = DefaultBindingEvents.EVENTS[triple_key]
## [/codeblock]
class_name DefaultBindingEvents
extends RefCounted

## `"action:device:input"` -> literal. `key`/`pad` triples map to one `int`
## (a `KEY_*` or `JOY_BUTTON_*` constant); `pad_axis` triples map to
## `[JoyAxis, signed float]`.
const EVENTS: Dictionary = {
	"confirm:key:Enter": KEY_ENTER,
	"confirm:key:Space": KEY_SPACE,
	"confirm:key:Z": KEY_Z,
	"confirm:pad:south": JOY_BUTTON_A,

	"cancel:key:Escape": KEY_ESCAPE,
	"cancel:key:Backspace": KEY_BACKSPACE,
	"cancel:key:X": KEY_X,
	"cancel:pad:east": JOY_BUTTON_B,

	"menu:key:Tab": KEY_TAB,
	"menu:key:M": KEY_M,
	"menu:pad:start": JOY_BUTTON_START,

	"inspect:key:I": KEY_I,
	"inspect:key:Q": KEY_Q,
	"inspect:pad:north": JOY_BUTTON_Y,

	"page_left:key:1": KEY_1,
	"page_left:pad:left_shoulder": JOY_BUTTON_LEFT_SHOULDER,

	"page_right:key:3": KEY_3,
	"page_right:pad:right_shoulder": JOY_BUTTON_RIGHT_SHOULDER,

	"fast_forward:key:Shift": KEY_SHIFT,
	"fast_forward:pad:west": JOY_BUTTON_X,

	"move_up:key:W": KEY_W,
	"move_up:key:Up": KEY_UP,
	"move_up:pad:dpad_up": JOY_BUTTON_DPAD_UP,
	"move_up:pad_axis:left_y-": [JOY_AXIS_LEFT_Y, -1.0],

	"move_down:key:S": KEY_S,
	"move_down:key:Down": KEY_DOWN,
	"move_down:pad:dpad_down": JOY_BUTTON_DPAD_DOWN,
	"move_down:pad_axis:left_y+": [JOY_AXIS_LEFT_Y, 1.0],

	"move_left:key:A": KEY_A,
	"move_left:key:Left": KEY_LEFT,
	"move_left:pad:dpad_left": JOY_BUTTON_DPAD_LEFT,
	"move_left:pad_axis:left_x-": [JOY_AXIS_LEFT_X, -1.0],

	"move_right:key:D": KEY_D,
	"move_right:key:Right": KEY_RIGHT,
	"move_right:pad:dpad_right": JOY_BUTTON_DPAD_RIGHT,
	"move_right:pad_axis:left_x+": [JOY_AXIS_LEFT_X, 1.0],
}
