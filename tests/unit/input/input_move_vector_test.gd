## Story 004, AC-4: a single digital direction (arrow key, WASD key or d-pad
## button) yields magnitude 1; two diagonal digital directions yield length
## 1 within `EPS_V` (GDD rule 6). Sign convention pinned by ADR-0003 §8
## (y-down): right (+1, 0), left (-1, 0), up (0, -1), down (0, +1).
extends GdUnitTestSuite

## Each case is a digital direction [dx, dy]: four straights, four diagonals.
const _DIRECTIONS: Array = [
	[0, -1], [0, 1], [-1, 0], [1, 0],
	[1, -1], [1, 1], [-1, -1], [-1, 1],
]

## Fixture triple key per move action, per digital source family.
const _SOURCES: Dictionary = {
	"arrows": {
		&"move_up": "move_up:key:Up", &"move_down": "move_down:key:Down",
		&"move_left": "move_left:key:Left", &"move_right": "move_right:key:Right",
	},
	"wasd": {
		&"move_up": "move_up:key:W", &"move_down": "move_down:key:S",
		&"move_left": "move_left:key:A", &"move_right": "move_right:key:D",
	},
	"dpad": {
		&"move_up": "move_up:pad:dpad_up", &"move_down": "move_down:pad:dpad_down",
		&"move_left": "move_left:pad:dpad_left", &"move_right": "move_right:pad:dpad_right",
	},
}


func _press_event(triple_key: String, pressed: bool) -> InputEvent:
	var literal: int = DefaultBindingEvents.EVENTS[triple_key]
	if triple_key.contains(":pad:"):
		return InputTestSupport.pad_button(0, literal, pressed)
	return InputTestSupport.key(literal, pressed)


func _actions_for(dx: int, dy: int) -> Array[StringName]:
	var actions: Array[StringName] = []
	if dx > 0:
		actions.append(InputActions.MOVE_RIGHT)
	elif dx < 0:
		actions.append(InputActions.MOVE_LEFT)
	if dy > 0:
		actions.append(InputActions.MOVE_DOWN)
	elif dy < 0:
		actions.append(InputActions.MOVE_UP)
	return actions


## Every source family: the direction's vector has length 1 and points along
## (dx, dy); releasing returns to zero.
func test_digital_direction_has_unit_length(dx: int, dy: int, test_parameters := _DIRECTIONS) -> void:
	for family: String in _SOURCES:
		var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
		var map: Dictionary = _SOURCES[family]
		for action: StringName in _actions_for(dx, dy):
			resolver.feed_event(_press_event(map[action], true))

		var expected: Vector2 = Vector2(dx, dy).normalized()
		var eps := Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V)
		var got: Vector2 = resolver.get_move_vector()
		assert_vector(got).override_failure_message("%s %s" % [family, got]).is_equal_approx(expected, eps)
		assert_float(got.length()).is_equal_approx(1.0, InputTestSupport.EPS_V)

		for action: StringName in _actions_for(dx, dy):
			resolver.feed_event(_press_event(map[action], false))
		assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2.ZERO, eps)


## Mixed families on one diagonal (W + Right arrow) still normalize to length 1.
func test_mixed_family_diagonal_has_unit_length() -> void:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	resolver.feed_event(_press_event("move_up:key:W", true))
	resolver.feed_event(_press_event("move_right:pad:dpad_right", true))
	assert_float(resolver.get_move_vector().length()).is_equal_approx(1.0, InputTestSupport.EPS_V)


## Two sources of the same direction (W and Up) are still magnitude 1.
func test_two_sources_same_direction_magnitude_one() -> void:
	var resolver := InputResolver.new(InputTestSupport.default_bindings(), InputTestSupport.DEFAULT)
	resolver.feed_event(_press_event("move_up:key:W", true))
	resolver.feed_event(_press_event("move_up:key:Up", true))
	assert_vector(resolver.get_move_vector()).is_equal_approx(Vector2(0.0, -1.0),
			Vector2(InputTestSupport.EPS_V, InputTestSupport.EPS_V))
