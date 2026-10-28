## Check 5 (unit): `GameRoot.resolve_data_root()`'s two cases. Written to the
## QA Test Cases in
## production/epics/game-state-scene-flow/story-035-game-root-main-scene.md
## -- no new cases invented.
extends GdUnitTestSuite


func test_resolve_data_root_with_no_flag_defaults_to_res_data() -> void:
	assert_str(GameRoot.resolve_data_root(PackedStringArray())).is_equal("res://data")


func test_resolve_data_root_with_data_root_flag_reads_the_path() -> void:
	assert_str(GameRoot.resolve_data_root(PackedStringArray(["--data-root=res://x"]))) \
			.is_equal("res://x")
