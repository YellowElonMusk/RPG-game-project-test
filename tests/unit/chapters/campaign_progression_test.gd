## Chapters 2-4 (2026-11-04): the shipped campaign runs Paris -> London ->
## Sydney -> New York;
## `ChapterProgression` begins the next chapter in `WorldState` (ID, first
## step, its flags) and leaves it untouched on the last chapter; the current
## chapter survives a save round trip.
extends GdUnitTestSuite


func test_the_shipped_campaign_is_paris_london_sydney_new_york() -> void:
	var campaign: Campaign = Campaign.load_default()
	assert_object(campaign).is_not_null()
	assert_int(campaign.chapters.size()).is_equal(4)
	assert_str(campaign.chapter("").chapter_id()).is_equal("chapter_paris")
	assert_str(campaign.next_after("chapter_paris").chapter_id()).is_equal("chapter_london")
	assert_str(campaign.next_after("chapter_london").chapter_id()).is_equal("chapter_sydney")
	assert_str(campaign.next_after("chapter_sydney").chapter_id()).is_equal("chapter_newyork")
	assert_object(campaign.next_after("chapter_newyork")).is_null()
	assert_object(campaign.chapter("chapter_nowhere")).is_null()


func test_the_first_chapter_is_the_config_default() -> void:
	var first: CampaignChapter = Campaign.load_default().chapter("")
	assert_str(first.steps.resource_path).is_equal(OverworldConfig.new().chapter_steps_path)


func test_advance_from_paris_begins_london() -> void:
	var ws := WorldState.new()
	ws.chapter_id = "chapter_paris"
	ws.chapter_step = "step_walk_home_b"
	var next: CampaignChapter = ChapterProgression.advance(ws, Campaign.load_default())
	assert_str(next.chapter_id()).is_equal("chapter_london")
	assert_str(ws.chapter_id).is_equal("chapter_london")
	assert_str(ws.chapter_step).is_equal("london_step_leave_town")
	assert_bool(ws.has_flag("london_billing_live")).is_true()


func test_an_empty_chapter_id_counts_as_the_first_chapter() -> void:
	var ws := WorldState.new()
	var next: CampaignChapter = ChapterProgression.advance(ws, Campaign.load_default())
	assert_str(next.chapter_id()).is_equal("chapter_london")


func test_advance_on_the_last_chapter_changes_nothing() -> void:
	var ws := WorldState.new()
	ws.chapter_id = "chapter_newyork"
	ws.chapter_step = "newyork_step_walk_home_b"
	assert_object(ChapterProgression.advance(ws, Campaign.load_default())).is_null()
	assert_str(ws.chapter_id).is_equal("chapter_newyork")
	assert_str(ws.chapter_step).is_equal("newyork_step_walk_home_b")


func test_arrival_is_the_london_town_arrival_point() -> void:
	var london: CampaignChapter = Campaign.load_default().chapter("chapter_london")
	var payload: MapEntryPayload = ChapterProgression.arrival_payload(london)
	assert_str(payload.map_id).is_equal("map_london_town_placeholder")
	assert_str(String(payload.entry_marker_id)).is_equal("from_arrival")


func test_chapter_id_survives_to_dict_and_back() -> void:
	var ws := WorldState.new()
	ws.chapter_id = "chapter_london"
	assert_str(String(ws.to_dict()["chapter_id"])).is_equal("chapter_london")
	var back := WorldState.new()
	back.from_dict({"chapter_id": "chapter_london"})
	assert_str(back.chapter_id).is_equal("chapter_london")
	back.reset_to_new_game()
	assert_str(back.chapter_id).is_equal("")


func test_london_flags_never_collide_with_paris_flags() -> void:
	var campaign: Campaign = Campaign.load_default()
	var paris: Dictionary = campaign.chapter("chapter_paris").flags.flags
	for flag: String in campaign.chapter("chapter_london").flags.flags:
		assert_bool(paris.has(flag)).override_failure_message("shared flag " + flag).is_false()


func test_advance_from_london_begins_sydney() -> void:
	var ws := WorldState.new()
	ws.chapter_id = "chapter_london"
	ws.chapter_step = "london_step_walk_home_b"
	var next: CampaignChapter = ChapterProgression.advance(ws, Campaign.load_default())
	assert_str(next.chapter_id()).is_equal("chapter_sydney")
	assert_str(ws.chapter_step).is_equal("sydney_step_leave_town")
	assert_bool(ws.has_flag("sydney_feed_live")).is_true()
	var payload: MapEntryPayload = ChapterProgression.arrival_payload(next)
	assert_str(payload.map_id).is_equal("map_sydney_town_placeholder")
	assert_str(String(payload.entry_marker_id)).is_equal("from_arrival")


func test_only_the_last_chapter_has_an_end_line() -> void:
	var campaign: Campaign = Campaign.load_default()
	assert_str(campaign.chapter("chapter_london").end_line).is_empty()
	assert_str(campaign.chapter("chapter_sydney").end_line).is_empty()
	assert_str(campaign.chapter("chapter_newyork").end_line).contains("To be continued")


func test_no_two_chapters_share_a_flag() -> void:
	var campaign: Campaign = Campaign.load_default()
	var seen: Dictionary = {}
	for c: CampaignChapter in campaign.chapters:
		for flag: String in c.flags.flags:
			assert_bool(seen.has(flag)).override_failure_message("shared flag " + flag).is_false()
			seen[flag] = true


func test_advance_from_sydney_begins_new_york() -> void:
	var ws := WorldState.new()
	ws.chapter_id = "chapter_sydney"
	ws.chapter_step = "sydney_step_walk_home_b"
	var next: CampaignChapter = ChapterProgression.advance(ws, Campaign.load_default())
	assert_str(next.chapter_id()).is_equal("chapter_newyork")
	assert_str(ws.chapter_step).is_equal("newyork_step_leave_town")
	assert_bool(ws.has_flag("newyork_anthem_live")).is_true()
	var payload: MapEntryPayload = ChapterProgression.arrival_payload(next)
	assert_str(payload.map_id).is_equal("map_newyork_town_placeholder")
	assert_str(String(payload.entry_marker_id)).is_equal("from_arrival")
