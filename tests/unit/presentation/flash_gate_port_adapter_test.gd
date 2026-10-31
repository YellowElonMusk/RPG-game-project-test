## The adapter that lets GameStateMachine book through the real FlashGate
## (ADR-0005 §12): a booking succeeds, and Reduce Flashing refuses it.
extends GdUnitTestSuite


func _gate(settings: FlashSettings) -> FlashGate:
	var gate: FlashGate = auto_free(FlashGate.new())
	var decls: Dictionary[StringName, FlashSourceDecl] = {}
	for decl: FlashSourceDecl in PresentationValidators.load_flash_sources():
		decls[decl.source_id] = decl
	gate.setup(func() -> int: return 0, PresentationConfig.new(), decls, settings)
	return gate


func test_request_books_through_the_real_gate() -> void:
	var port := FlashGatePortAdapter.new(_gate(FlashSettings.new()))
	assert_int(port.request(&"battle_wipe", 0.0, 1.0)).is_not_equal(FlashGate.REFUSED)


func test_reduce_flashing_refuses_so_the_machine_plays_capped() -> void:
	var settings := FlashSettings.new()
	settings.reduce_flashing_on = true
	var port := FlashGatePortAdapter.new(_gate(settings))
	assert_int(port.request(&"battle_wipe", 0.0, 1.0)).is_equal(FlashGate.REFUSED)


func test_no_gate_refuses() -> void:
	assert_int(FlashGatePortAdapter.new(null).request(&"battle_wipe", 0.0, 1.0)).is_equal(FlashGate.REFUSED)
