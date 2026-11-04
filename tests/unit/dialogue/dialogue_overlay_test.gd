## Dialogue system: the conversation box reveals each line letter by letter
## (confirm completes it, confirm again advances), refuses confirm inside
## the input guard, shows choices once the line is whole, moves the choice
## highlight with up/down and picks with confirm.
extends GdUnitTestSuite

const _SCENE: String = "res://src/game_state/overlays/interim_line_dialogue.tscn"

var _flags: Dictionary = {}


func before_test() -> void:
	_flags = {}


func _overlay(payload: DialogueLinePayload) -> InterimLineDialogue:
	var box: InterimLineDialogue = auto_free(load(_SCENE).instantiate())
	box.setup(null, payload)
	return box


func _talk() -> Conversation:
	var ask := DialogueLine.new()
	ask.speaker = "Café regular"
	ask.text = "Want a tip?"
	var yes := DialogueChoice.new()
	yes.label = "Go on then."
	yes.sets_flag = "heard_tip"
	yes.goto_id = "tip"
	var no := DialogueChoice.new()
	no.label = "No time."
	no.goto_id = "end"
	ask.choices.assign([yes, no])
	var tip := DialogueLine.new()
	tip.id = "tip"
	tip.text = "Clerks go for half health."
	var talk := Conversation.new()
	talk.id = "conv_test"
	talk.lines.assign([ask, tip])
	return talk


func _payload() -> DialogueLinePayload:
	return DialogueLinePayload.for_conversation(_talk(),
			func(f: String) -> bool: return _flags.has(f),
			func(f: String) -> void: _flags[f] = true)


func test_single_line_payload_still_works() -> void:
	var box := _overlay(DialogueLinePayload.new("Mind the queue.", "Café regular"))
	assert_str(box.text).is_equal("Café regular: Mind the queue.")
	assert_bool(box.is_revealing()).is_true()


func test_confirm_in_guard_refused_then_completes_then_advances() -> void:
	var box := _overlay(DialogueLinePayload.new("A fairly long line of text to reveal."))
	box.handle_action(InputActions.CONFIRM, true)
	assert_bool(box.is_revealing()).is_true()  # inside the guard: refused
	box.advance_guard(0.2)
	assert_bool(box.is_revealing()).is_true()  # 0.2 s reveals ~9 letters only
	box.handle_action(InputActions.CONFIRM, true)
	assert_bool(box.is_revealing()).is_false()  # first confirm shows it whole


func test_reveal_finishes_on_its_own() -> void:
	var box := _overlay(DialogueLinePayload.new("Short."))
	box.advance_guard(5.0)
	assert_bool(box.is_revealing()).is_false()


func test_choices_appear_after_reveal_and_pick_with_confirm() -> void:
	var box := _overlay(_payload())
	assert_array(Array(box.choice_labels())).is_empty()
	box.reveal_all()
	assert_array(Array(box.choice_labels())).is_equal(["Go on then.", "No time."])
	# The choice guard re-arms when the choices appear.
	box.handle_action(InputActions.CONFIRM, true)
	assert_str(box.text).contains("Want a tip?")
	box.advance_guard(0.2)
	box.handle_action(InputActions.NAV_DOWN, true)
	assert_int(box.choice_index()).is_equal(1)
	box.handle_action(InputActions.MOVE_UP, true)
	assert_int(box.choice_index()).is_equal(0)
	box.handle_action(InputActions.CONFIRM, true)
	assert_str(box.text).is_equal("Clerks go for half health.")
	assert_bool(_flags.has("heard_tip")).is_true()
	assert_array(Array(box.shown_lines)).is_equal(["Café regular: Want a tip?", "Clerks go for half health."])


func test_highlight_clamps_at_the_ends() -> void:
	var box := _overlay(_payload())
	box.reveal_all()
	box.handle_action(InputActions.NAV_UP, true)
	assert_int(box.choice_index()).is_equal(0)
	for i: int in 5:
		box.handle_action(InputActions.NAV_DOWN, true)
	assert_int(box.choice_index()).is_equal(1)


func test_skip_to_end_plays_through() -> void:
	var box := _overlay(_payload())
	box.skip_to_end()
	assert_array(Array(box.shown_lines)).is_equal(["Café regular: Want a tip?", "Clerks go for half health."])
	assert_bool(_flags.has("heard_tip")).is_true()
