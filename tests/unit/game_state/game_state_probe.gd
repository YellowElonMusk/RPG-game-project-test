## Compares two `GameStateMachine.get_debug_state()` snapshots field by
## field, so a test can assert "unchanged" after a rejected request (the
## GDD's "Rejected" contract: a non-OK `RequestResult` and an unchanged
## debug state) without ever reading a private member.
class_name GameStateProbe extends RefCounted


static func states_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.keys().size() != b.keys().size():
		return false
	for key: Variant in a.keys():
		if not b.has(key):
			return false
		if a[key] != b[key]:
			return false
	return true
