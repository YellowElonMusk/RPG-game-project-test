## Story 130, AC-58 (UI, timed text): every timed text holds for
## `text_hold(text) = max(name_card_s, text_hold_base_s + words *
## text_hold_per_word_s)`, asserted at `- dt` and `+ dt`, and every hold
## pauses while any overlay is open. Covers the bark window and the name
## card; the payoff card arrives with story 050 (Victory payoffs), which
## extends this suite with its card and the `clue` stub ordering.
extends GdUnitTestSuite

const _DT: float = 1.0 / 60.0


func test_text_hold_formula() -> void:
	var cfg := OverworldConfig.new()
	# The GDD's example: a 9-word line holds 1.0 + 9 * 0.3 = 3.7 s.
	assert_float(cfg.text_hold("one two three four five six seven eight nine")).is_equal_approx(3.7, 1e-6)
	assert_float(cfg.text_hold("They won't follow you past the café paving. Union rules.")).is_equal_approx(4.0, 1e-6)
	# Short text never holds less than name_card_s.
	assert_float(cfg.text_hold("Take a number.")).is_equal(cfg.name_card_s)


func test_bark_window_holds_for_text_hold() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var line: String = "They won't follow you past the café paving. Union rules."
	mode.call("_bark", line, Vector2.ZERO)
	var hold: float = mode.config.text_hold(line)
	mode.tick_timed_text(hold - _DT)
	assert_int(mode.bark_phase).is_equal(OverworldMode.CardPhase.SHOWN)
	mode.tick_timed_text(2.0 * _DT)
	assert_int(mode.bark_phase).is_equal(OverworldMode.CardPhase.FADING)
	mode.tick_timed_text(mode.config.text_fade_s)
	assert_int(mode.bark_phase).is_equal(OverworldMode.CardPhase.HIDDEN)
	assert_str(mode.bark_text).is_empty()


func test_holds_pause_while_an_overlay_is_open() -> void:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode())
	var machine: GameStateMachine = mode.get("_machine")
	mode.call("_bark", "Take a number.", Vector2.ZERO)
	mode.call("_show_name_card")
	var hold: float = mode.config.text_hold("Take a number.")
	mode.tick_timed_text(hold - _DT)
	machine.open_overlay(GameStateMachine.OverlayKind.MENU)
	mode.tick_timed_text(10.0)
	assert_int(mode.bark_phase).is_equal(OverworldMode.CardPhase.SHOWN)
	assert_int(mode.name_card_phase).is_equal(OverworldMode.CardPhase.SHOWN)
	machine.close_overlay()
	mode.tick_timed_text(2.0 * _DT)
	assert_int(mode.bark_phase).is_equal(OverworldMode.CardPhase.FADING)
