## Story 008 test-only spy: a `ContentCatalogService` subclass that counts
## `load_all()` calls so `ContentBootstrap.run()`'s idempotency guard can be
## proven from outside without inspecting private state. Deliberately has no
## `class_name` -- a test-only class in the global class registry is exactly
## what that would be (Implementation Notes). Load it with `load()` or
## `preload()` and instantiate with `.new()`; it satisfies the
## `ContentCatalogService` type `run()` is written against through `extends`
## alone.
##
## The explicit `return` below is load-bearing: Godot 4.7 hard-errors a typed
## override with a code path that falls through without one (Engine Notes).
##
## Usage example:
## [codeblock]
## var Spy := preload("res://tests/unit/content_data/helpers/spy_content_catalog.gd")
## var spy: ContentCatalogService = auto_free(Spy.new())
## ContentBootstrap.run(spy, fixture_root)
## ContentBootstrap.run(spy, fixture_root)
## assert_int(spy.load_all_call_count).is_equal(1)
## [/codeblock]
extends ContentCatalogService

## Number of times load_all() actually ran its body. ContentBootstrap.run()'s
## own UNLOADED guard keeps this from ever reaching 2 across two run() calls.
var load_all_call_count: int = 0


## Counts the call, then defers to the base implementation unchanged.
func load_all(data_root: String = "res://data") -> Error:
	load_all_call_count += 1
	return super(data_root)
