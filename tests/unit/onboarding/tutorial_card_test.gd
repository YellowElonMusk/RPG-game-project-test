## Onboarding: the pre-round-1 tutorial card shows its queue in order and
## emits `finished` once, after the last OK; an empty queue finishes at once.
extends GdUnitTestSuite

var _clock: Array = [0.0]


func _card() -> TutorialCard:
	var clock: Array = _clock
	var card: TutorialCard = auto_free(TutorialCard.new(func() -> float: return clock[0], 0.0))
	add_child(card)
	return card


func _ok(card: TutorialCard) -> void:
	(card.find_children("*", "Button", true, false)[0] as Button).pressed.emit()


func test_cards_show_in_order_then_finish_once() -> void:
	var card := _card()
	var finished: Array = [0]
	card.finished.connect(func() -> void: finished[0] += 1)
	card.show_cards([["How to fight", "Pick a command.", Color.WHITE],
			["Bureaucratia's rule", "Permit first.", Color.RED]])
	assert_bool(card.visible).is_true()
	assert_str(card.title_text()).is_equal("How to fight")
	assert_int(card.remaining()).is_equal(1)
	_ok(card)
	assert_str(card.title_text()).is_equal("Bureaucratia's rule")
	assert_str(card.body_text()).is_equal("Permit first.")
	assert_int(finished[0]).is_equal(0)
	_ok(card)
	assert_bool(card.visible).is_false()
	assert_int(finished[0]).is_equal(1)
	_ok(card)
	assert_int(finished[0]).is_equal(1)


func test_empty_queue_finishes_at_once() -> void:
	var card := _card()
	var finished: Array = [0]
	card.finished.connect(func() -> void: finished[0] += 1)
	card.show_cards([])
	assert_bool(card.visible).is_false()
	assert_int(finished[0]).is_equal(1)


func test_hidden_card_consumes_nothing() -> void:
	assert_bool(_card().handle_action(InputActions.CONFIRM, true)).is_false()
