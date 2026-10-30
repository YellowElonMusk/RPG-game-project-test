## Story 122, AC-51c (GDD rule 16): on `confirm` at a clue poster or a decree
## gag, the Dialogue overlay shows the record's text verbatim, through the
## localization path (ADR-0013), at the current text size. Text sizes 1.0
## and 1.5 are the scales the GDD's UI evidence list names.
extends GdUnitTestSuite

const _AT: Vector2 = ProbeFixture.OPEN_SPOT
const _AHEAD: Vector2 = ProbeFixture.OPEN_SPOT + Vector2(0.0, -1.0)
const _TEST_LOCALE: String = "fr"
## The GDD's named text scales (UI Requirements evidence: 1.0 and 1.5).
const _TEXT_SCALES: Array[float] = [1.0, 1.5]
## A long decree, so a truncating label would visibly lose its tail.
const _LONG_DECREE: String = "BY ORDER OF THE PREFECTURE: special moves are forbidden on public streets without Form 27-B, stamped twice, in triplicate, before noon."

var _translation: Translation = null
var _previous_locale: String = ""


func before_test() -> void:
	_previous_locale = TranslationServer.get_locale()


func after_test() -> void:
	if _translation != null:
		TranslationServer.remove_translation(_translation)
		_translation = null
	TranslationServer.set_locale(_previous_locale)


func test_clue_poster_shows_its_text_verbatim_at_each_text_size() -> void:
	var gag: GagInteractable = ProbeFixture.gag(_AHEAD, GagInteractable.Response.CLUE)
	gag.text = _LONG_DECREE
	_assert_shown_verbatim(_clue_mode(gag), gag, _LONG_DECREE)


func test_decree_gag_shows_its_text_verbatim_at_each_text_size() -> void:
	var mode: OverworldMode = _decree_mode()
	var decree: GagInteractable = _decree(mode, _LONG_DECREE)
	_assert_shown_verbatim(mode, decree, _LONG_DECREE)


func test_clue_poster_text_goes_through_the_localization_path() -> void:
	var gag: GagInteractable = ProbeFixture.gag(_AHEAD, GagInteractable.Response.CLUE)
	var translated: String = "Affiche de test."
	_install_translation(gag.text, translated, "%s.text" % gag.marker_id)
	_assert_shown_verbatim(_clue_mode(gag), gag, translated)


func test_decree_gag_text_goes_through_the_localization_path() -> void:
	var mode: OverworldMode = _decree_mode()
	var decree: GagInteractable = _decree(mode, "DECREE: NO JUMPING.")
	var translated: String = "DÉCRET : INTERDIT DE SAUTER."
	_install_translation(decree.text, translated, "%s.text" % decree.marker_id)
	_assert_shown_verbatim(mode, decree, translated)


func test_a_translation_under_another_context_is_not_used() -> void:
	var gag: GagInteractable = ProbeFixture.gag(_AHEAD, GagInteractable.Response.CLUE)
	_install_translation(gag.text, "Wrong poster.", "gag_other.text")
	_assert_shown_verbatim(_clue_mode(gag), gag, gag.text)


# -- helpers -------------------------------------------------------------------

## Confirms at `gag` (the leader already facing it), then checks the line the
## mode said and the Dialogue overlay's label at every text scale: the full
## string, untrimmed, wrapped, and not translated a second time.
func _assert_shown_verbatim(mode: OverworldMode, gag: GagInteractable, expected: String) -> void:
	assert_bool(mode.probe() == gag).is_true()
	mode.confirm()
	assert_array(_machine(mode).overlay_stack).is_equal([GameStateMachine.OverlayKind.DIALOGUE])
	assert_array(mode.lines_said).is_equal([expected])
	for text_scale: float in _TEXT_SCALES:
		var line: InterimLineDialogue = auto_free(
				(load("res://src/game_state/overlays/interim_line_dialogue.tscn") as PackedScene).instantiate())
		var label: Label = line.get_node(^"Box/Line") as Label
		var base_size: int = label.get_theme_font_size(&"font_size")
		label.add_theme_font_size_override(&"font_size", roundi(base_size * text_scale))
		add_child(line)
		line.setup(_machine(mode), DialogueLinePayload.new(mode.lines_said.back()))
		var why: String = "scale %.1f" % text_scale
		assert_str(line.text).override_failure_message(why).is_equal(expected)
		assert_str(label.text).override_failure_message(why).is_equal(expected)
		assert_int(label.get_theme_font_size(&"font_size")).is_equal(roundi(base_size * text_scale))
		assert_int(label.visible_characters).override_failure_message(why).is_equal(-1)
		assert_bool(label.clip_text).override_failure_message(why).is_false()
		assert_int(label.text_overrun_behavior).override_failure_message(why).is_equal(TextServer.OVERRUN_NO_TRIMMING)
		assert_bool(label.autowrap_mode != TextServer.AUTOWRAP_OFF).override_failure_message(why).is_true()
		assert_int(label.auto_translate_mode).override_failure_message(why).is_equal(Node.AUTO_TRANSLATE_MODE_DISABLED)
		remove_child(line)


func _clue_mode(gag: GagInteractable) -> OverworldMode:
	var mode: OverworldMode = auto_free(ProbeFixture.make_mode([gag]))
	ProbeFixture.stand(mode, _AT, Vector2.UP)
	return mode


## The segment map at stage 2 (`permits_mandatory`), where its stage-2 decree
## gag is active (as in story 056's test).
func _decree_mode() -> OverworldMode:
	var machine: GameStateMachine = ProbeFixture.GameStateFixtures.make_machine_in_overworld()["machine"]
	var mode := OverworldMode.new()
	mode.config = OverworldConfig.new()
	auto_free(mode)
	mode.setup(machine, null)
	mode.world_state = WorldState.new()
	mode.world_state.set_flag("permits_mandatory")
	var catalog := RecordCatalogDouble.new()
	catalog.add(&"map", load("res://data/maps/map_paris_segment_placeholder.tres"))
	catalog.add(&"encounter", load("res://data/encounters/enc_paris_permit_counter.tres"))
	mode.encounter_catalog = catalog
	mode.load_map((load(ProbeFixture.SEGMENT) as PackedScene).instantiate() as OverworldMap)
	mode.tick_timed_text(60.0)
	return mode


## The map's first stage decree, its text set to `text`, the leader facing it.
func _decree(mode: OverworldMode, text: String) -> GagInteractable:
	for gag: GagInteractable in mode.get_map().gags():
		if gag.decree_stage > 0:
			gag.text = text
			mode.set_leader_position(gag.ground_position(mode.get_map()) + Vector2(0.0, 1.0))
			mode.set_leader_facing(Vector2.UP)
			return gag
	return null


func _install_translation(source: String, translated: String, context: String) -> void:
	_translation = Translation.new()
	_translation.locale = _TEST_LOCALE
	_translation.add_message(StringName(source), StringName(translated), StringName(context))
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale(_TEST_LOCALE)


func _machine(mode: OverworldMode) -> GameStateMachine:
	return mode.get("_machine")
