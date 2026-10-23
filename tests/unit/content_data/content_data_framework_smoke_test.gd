## Infrastructure smoke test (Story 001). Proves the gdUnit4 runner discovers
## and passes a test under tests/unit/content_data/. Not a content-data test —
## see Story 002 for the first real catalog tests and fixtures.
extends GdUnitTestSuite


func test_framework_runs_passes() -> void:
	assert_bool(true).is_true()
