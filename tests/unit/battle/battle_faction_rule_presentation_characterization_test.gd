## Story 007 (ADR-0011 §1/§5; ADR-0001 Migration Step 0): pins both shipped
## faction rules' banner text, tooltip text, combatant tooltip note and
## colours for every round state, under the "en" locale, before ADR-0011
## moves these into `faction_rule`/`faction` records (story 017 then proves
## the record-backed text matches these pins unchanged). Strings are
## compared with `==` and, as the story's QA case asks, also as
## `to_utf8_buffer()` bytes (the em dash included). The byte check adds no
## power over `==` today -- GDScript compares strings by codepoint -- but it
## states the byte-exact contract the record migration must keep. Colours are
## compared both as `Color` values (`is_equal_approx`) and as `to_html(false)`
## strings, so a channel change can't hide inside the approx tolerance.
extends GdUnitTestSuite

var _previous_locale: String


func before_test() -> void:
	_previous_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_previous_locale)


func _assert_text_equal(actual: String, expected: String, label: String) -> void:
	assert_str(actual).override_failure_message(label).is_equal(expected)
	assert_array(actual.to_utf8_buffer()).override_failure_message(
			"%s (byte compare)" % label).is_equal(expected.to_utf8_buffer())


func _assert_color_equal(actual: Color, expected_html: String, label: String) -> void:
	var expected: Color = Color(expected_html)
	assert_bool(actual.is_equal_approx(expected)).override_failure_message(
			"%s: got %s, want #%s" % [label, actual.to_html(false), expected_html]).is_true()
	assert_str(actual.to_html(false)).override_failure_message(label).is_equal(expected_html)


# --- Test: banner and tooltip by round ---

func test_bureaucratia_banner_and_tooltip_text_by_round() -> void:
	var rule := BureaucratiaRule.new()
	for round_number: int in range(1, 5):
		_assert_text_equal(rule.get_banner_text(round_number),
				CharacterizationExpected.BUREAUCRATIA_BANNER_TEXT[round_number],
				"banner round %d" % round_number)
		_assert_text_equal(rule.get_tooltip_text(round_number),
				CharacterizationExpected.BUREAUCRATIA_TOOLTIP_TEXT[round_number],
				"tooltip round %d" % round_number)


## MegaCorp's banner and tooltip do not vary by round (in effect from round 1).
func test_megacorp_banner_and_tooltip_text_is_constant_across_rounds() -> void:
	var rule := MegaCorpRule.new()
	for round_number: int in range(1, 5):
		_assert_text_equal(rule.get_banner_text(round_number),
				CharacterizationExpected.MEGACORP_BANNER_TEXT, "banner round %d" % round_number)
		_assert_text_equal(rule.get_tooltip_text(round_number),
				CharacterizationExpected.MEGACORP_TOOLTIP_TEXT, "tooltip round %d" % round_number)


# --- Test: combatant note ---

func test_megacorp_combatant_tooltip_note() -> void:
	var rule := MegaCorpRule.new()
	var squad_member := Combatant.new(CharacterizationExpected.SQUAD_KAREN["name"],
			CharacterizationExpected.SQUAD_KAREN["max_hp"], CharacterizationExpected.SQUAD_KAREN["max_mp"],
			CharacterizationExpected.SQUAD_KAREN["attack"], CharacterizationExpected.SQUAD_KAREN["defense"],
			CharacterizationExpected.SQUAD_KAREN["speed"], false)

	BattleContentSeam.arrange_vitals(squad_member, squad_member.max_hp, 0)
	assert_str(rule.get_combatant_tooltip_note(squad_member)).override_failure_message(
			"suspended").is_equal(CharacterizationExpected.MEGACORP_SUSPENDED_NOTE)

	BattleContentSeam.arrange_vitals(squad_member, squad_member.max_hp, 4)
	assert_str(rule.get_combatant_tooltip_note(squad_member)).override_failure_message(
			"non-suspended").is_equal("")

	BattleContentSeam.arrange_vitals(squad_member, 0, 0)
	assert_str(rule.get_combatant_tooltip_note(squad_member)).override_failure_message(
			"knocked out").is_equal("")

	var enemy: Combatant = BattleContentSeam.enemy("enemy_clerk")
	assert_str(rule.get_combatant_tooltip_note(enemy)).override_failure_message("enemy").is_equal("")


## Bureaucratia overrides nothing here, so every state gives "" (the
## FactionRule base default).
func test_bureaucratia_combatant_tooltip_note_is_always_empty() -> void:
	var rule := BureaucratiaRule.new()
	var squad_member := Combatant.new(CharacterizationExpected.SQUAD_KAREN["name"],
			CharacterizationExpected.SQUAD_KAREN["max_hp"], CharacterizationExpected.SQUAD_KAREN["max_mp"],
			CharacterizationExpected.SQUAD_KAREN["attack"], CharacterizationExpected.SQUAD_KAREN["defense"],
			CharacterizationExpected.SQUAD_KAREN["speed"], false)
	var enemy: Combatant = BattleContentSeam.enemy("enemy_clerk")

	BattleContentSeam.arrange_vitals(squad_member, squad_member.max_hp, 0)
	assert_str(rule.get_combatant_tooltip_note(squad_member)).override_failure_message("suspended-shaped").is_equal("")

	BattleContentSeam.arrange_vitals(squad_member, squad_member.max_hp, 4)
	assert_str(rule.get_combatant_tooltip_note(squad_member)).override_failure_message("non-suspended-shaped").is_equal("")

	BattleContentSeam.arrange_vitals(squad_member, 0, 0)
	assert_str(rule.get_combatant_tooltip_note(squad_member)).override_failure_message("knocked-out").is_equal("")

	assert_str(rule.get_combatant_tooltip_note(enemy)).override_failure_message("enemy").is_equal("")


# --- Test: colours ---

func test_bureaucratia_colors_by_round() -> void:
	var rule := BureaucratiaRule.new()
	_assert_color_equal(rule.get_identity_color(), CharacterizationExpected.BUREAUCRATIA_IDENTITY_COLOR_HTML, "identity")
	for round_number: int in range(1, 5):
		_assert_color_equal(rule.get_banner_color(round_number),
				CharacterizationExpected.BUREAUCRATIA_BANNER_COLOR_HTML[round_number],
				"banner round %d" % round_number)


func test_megacorp_colors_are_constant() -> void:
	var rule := MegaCorpRule.new()
	_assert_color_equal(rule.get_identity_color(), CharacterizationExpected.MEGACORP_IDENTITY_COLOR_HTML, "identity")
	for round_number: int in range(1, 5):
		_assert_color_equal(rule.get_banner_color(round_number),
				CharacterizationExpected.MEGACORP_IDENTITY_COLOR_HTML, "banner round %d" % round_number)


## Control case: the neutral fallback's identity colour, pinned before
## ADR-0011 §1 changes this default.
func test_neutral_faction_rule_identity_color() -> void:
	var rule := FactionRule.new()
	_assert_color_equal(rule.get_identity_color(), CharacterizationExpected.NEUTRAL_IDENTITY_COLOR_HTML, "neutral identity")
