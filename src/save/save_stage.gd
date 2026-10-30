## One participant's staged load (ADR-0009 §3): decoded and resolved by
## `stage()`, applied by `commit()`. `ok` false (with `errors`) means the save
## cannot load; `staged` is the participant's own payload.
class_name SaveStage
extends RefCounted

var ok: bool = true
var errors: PackedStringArray = PackedStringArray()
var staged: Variant = null


static func success(payload: Variant) -> SaveStage:
	var s := SaveStage.new()
	s.staged = payload
	return s


static func failure(message: String) -> SaveStage:
	var s := SaveStage.new()
	s.ok = false
	s.errors.append(message)
	return s
