## Story 032, AC-28 (ADR-0005 §9 `boss_profile_exists`, §3 profile requests):
## an alien faction record with no `boss_<faction>` lighting preset ends boot
## in Content Error naming the faction; with the preset, boot is READY. On a
## debug run that skipped validation, requesting the missing boss light logs
## exactly one error and leaves the Battle light on stage, with no takeover
## gating the fight. Fixture roots are copies of content-data's
## `valid_one_of_each` (alien `faction_tech_syndicate`) plus a
## `presentation/profiles` table.
extends GdUnitTestSuite

const _MISSING_ROOT := "res://tests/integration/presentation/fixtures/boss_profile_missing"
const _PRESENT_ROOT := "res://tests/integration/presentation/fixtures/boss_profile_present"
const _FACTION := "faction_tech_syndicate"


func _boot(root: String) -> ContentCatalogService:
	var catalog: ContentCatalogService = auto_free(ContentCatalogService.new())
	ContentBootstrap.run(catalog, root)
	return catalog


func _report_text(catalog: ContentCatalogService) -> String:
	var lines: PackedStringArray = []
	for entry: Dictionary in catalog.report:
		lines.append(str(entry))
	return "\n".join(lines)


func test_alien_faction_without_boss_preset_ends_boot_in_content_error() -> void:
	var catalog := _boot(_MISSING_ROOT)
	assert_int(catalog.state).override_failure_message(_report_text(catalog)) \
			.is_equal(ContentCatalogService.State.FAILED)
	var text: String = _report_text(catalog)
	assert_bool(text.contains(PresentationValidators.RULE_BOSS_PROFILE_EXISTS)) \
			.override_failure_message(text).is_true()
	assert_bool(text.contains(_FACTION)).is_true()
	assert_bool(text.contains("boss_tech_syndicate")).is_true()


func test_alien_faction_with_its_boss_preset_boots_ready() -> void:
	var catalog := _boot(_PRESENT_ROOT)
	assert_int(catalog.state).override_failure_message(_report_text(catalog)) \
			.is_equal(ContentCatalogService.State.READY)


func test_shipped_data_has_a_boss_preset_for_every_alien_faction() -> void:
	var profiles: Dictionary = PresentationValidators.load_profile_ids(
			"res://data/presentation/profiles")
	for faction: String in ["faction_bureaucratia", "faction_megacorp"]:
		assert_bool(profiles.has(PresentationValidators.boss_profile_id(faction))).is_true()


## Debug run, validation skipped: the request resolves to nothing, one error
## is logged, the Battle light stays, and no takeover blocks the fight.
func test_debug_skip_logs_one_error_and_keeps_the_battle_light() -> void:
	var stage: DioramaStage = auto_free(DioramaStage.new())
	var errors: Array[String] = []
	stage.error_sink = func(message: String) -> void: errors.append(message)
	var battle := load("res://data/presentation/profiles/battle.tres") as LightingProfile
	var director: PresentationDirector = auto_free(PresentationDirector.new())
	stage.bind_profiles(func(id: StringName) -> LightingProfile:
			return director.resolve_profile(id, _PRESENT_ROOT.path_join("presentation/profiles")) \
					if String(id) == "battle" else director.resolve_profile(id, _MISSING_ROOT.path_join("presentation/profiles")))
	stage.apply_profile(battle, 0.0)
	var before: LightingProfile = stage.current_values
	var clock_t: Array[float] = [0.0]

	stage.request_profile(&"boss_tech_syndicate", 0.9, func() -> float: return clock_t[0])

	assert_int(errors.size()).is_equal(1)
	assert_bool(errors[0].contains("boss_tech_syndicate")).is_true()
	assert_object(stage.current_values).is_same(before)
	assert_bool(stage.is_blending()).is_false()
	assert_bool(stage.is_takeover_active()).is_false()
	# The fight's punch still plays: nothing gates it.
	var punch := HitPunch.new(PresentationConfig.new())
	punch.takeover_active = stage.is_takeover_active
	assert_bool(punch.on_impact(-5, false, true, Vector2.RIGHT)).is_true()
