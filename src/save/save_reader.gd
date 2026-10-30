## Typed reads over one save section (ADR-0009 §3). JSON loses the int/float
## distinction, so `get_int` accepts an integral float and rejects any other.
## Every failed read is recorded in `dropped` for the load report.
class_name SaveReader
extends RefCounted

var _data: Dictionary
var _catalog: Object
## "key: reason" for every read that fell back to its default.
var dropped: PackedStringArray = PackedStringArray()


func _init(data: Dictionary, catalog: Object = null) -> void:
	_data = data
	_catalog = catalog


func has(key: String) -> bool:
	return _data.has(key)


func get_int(key: String, default: int = 0) -> int:
	var v: Variant = _data.get(key)
	if v is int:
		return v
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return _drop(key, default)


func get_float(key: String, default: float = 0.0) -> float:
	var v: Variant = _data.get(key)
	if v is float or v is int:
		return float(v)
	return _drop(key, default)


func get_bool(key: String, default: bool = false) -> bool:
	var v: Variant = _data.get(key)
	return v if v is bool else _drop(key, default)


func get_string(key: String, default: String = "") -> String:
	var v: Variant = _data.get(key)
	return v if v is String else _drop(key, default)


func get_array(key: String) -> Array:
	var v: Variant = _data.get(key)
	return v if v is Array else _drop(key, [])


func get_dict(key: String) -> Dictionary:
	var v: Variant = _data.get(key)
	return v if v is Dictionary else _drop(key, {})


## `[x, y]` as a Vector2.
func get_vector2(key: String, default: Vector2 = Vector2.ZERO) -> Vector2:
	var v: Variant = _data.get(key)
	if v is Array and (v as Array).size() == 2 and (v[0] is float or v[0] is int) \
			and (v[1] is float or v[1] is int):
		return Vector2(float(v[0]), float(v[1]))
	return _drop(key, default)


## A catalog ID of `record_type` read from `key`: aliases resolved, "" when
## neither live nor an alias (ADR-0009 §3; the participant decides what an
## unknown ID means).
func get_id(key: String, record_type: StringName) -> String:
	return resolve_id(get_string(key), record_type, key)


## The same check for an ID found inside a nested structure.
func resolve_id(id: String, record_type: StringName, key: String = "") -> String:
	if id.is_empty() or _catalog == null:
		return id
	if _catalog.has_method(&"resolve_alias"):
		id = String(_catalog.call(&"resolve_alias", id))
	if _catalog.call(&"get_record", record_type, id) == null:
		dropped.append("%s: unknown %s '%s'" % [key, record_type, id])
		return ""
	return id


func _drop(key: String, default: Variant) -> Variant:
	if _data.has(key):
		dropped.append("%s: wrong type (%s)" % [key, type_string(typeof(_data[key]))])
	return default
