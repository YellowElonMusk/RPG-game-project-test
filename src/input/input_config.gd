## Input System tuning (ADR-0003 §4; GDD input-system.md Tuning Knobs). A
## project config, never a catalog record: `data/config/input_config.tres`
## holds these same declared defaults. A missing or invalid file falls back
## to `InputConfig.new()` (GameRoot, later story) and logs an error, so a
## config failure never leaves the game uncontrollable.
class_name InputConfig
extends Resource

## Radial deadzone radius (GDD Formulas, `stick_output`). Safe range 0.10-0.30.
@export var deadzone: float = 0.20
## Wait before the first menu-repeat step (GDD Formulas, `step_time`). Safe range 0.25-0.60 s.
@export var repeat_delay: float = 0.40
## Time between repeats after the first (GDD Formulas, `step_time`). Safe range 0.05-0.15 s.
@export var repeat_interval: float = 0.08
## Stick magnitude, after the deadzone rescale, that counts as a menu
## direction (GDD rule 6). Safe range 0.40-0.80.
@export var menu_stick_threshold: float = 0.60
## Cumulative pointer movement, in pixels, that switches the active device to
## keyboard_mouse or moves hover focus (GDD rule 3-4, Tuning Knobs). Safe range 4-32 px.
@export var pointer_switch_px: int = 8
## Pad-style name patterns, `"substring:style"` entries matched
## case-insensitively against `Input.get_joy_name()`, first match wins
## (ADR-0003 §4; story 014). Styles: `xbox | playstation | nintendo |
## generic`; no match gives `generic`. Steam Virtual Gamepad and Steam Deck
## report `xbox` (GDD rule 4).
@export var pad_style_patterns: PackedStringArray = PackedStringArray([
	"steam virtual gamepad:xbox", "steam deck:xbox", "xbox:xbox",
	"playstation:playstation", "dualsense:playstation", "dualshock:playstation",
	"ps4:playstation", "ps5:playstation",
	"nintendo:nintendo", "switch:nintendo", "pro controller:nintendo",
	"joy-con:nintendo",
])
