## The settings fields, their defaults and their legal values (ADR-0009 §8,
## trimmed to what is wired today; volumes and text speed added with the
## settings screen, 2026-11-04). `SettingsService` validates every loaded
## and written value here; an invalid one falls back to its default.
class_name SettingsSchema
extends RefCounted

## Volume step on the settings screen, in percent.
const VOLUME_STEP: int = 10

## key -> [default, legal values]. Legal values are an Array of allowed
## values, or a Vector2i [min, max] for an int range.
var fields: Dictionary[StringName, Array] = {
	&"master_volume": [80, Vector2i(0, 100)],
	&"music_volume": [100, Vector2i(0, 100)],
	&"sfx_volume": [100, Vector2i(0, 100)],
	&"text_speed": ["normal", ["slow", "normal", "fast", "instant"]],
	&"display_fullscreen": [false, [false, true]],
	&"display_vsync": [true, [false, true]],
	&"faster_battle_animations": [false, [false, true]],
	&"speed_up_boss_entrances": [false, [false, true]],
	&"screen_shake": ["full", ["full", "reduced", "off"]],
	&"reduce_motion": [false, [false, true]],
	&"reduce_blur": [false, [false, true]],
	&"reduce_flashing": [false, [false, true]],
}


## Every key, in schema order.
func keys() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(fields.keys())
	return out


func has_key(key: StringName) -> bool:
	return fields.has(key)


func default_of(key: StringName) -> Variant:
	return fields[key][0]


## The legal values for an enum or bool key (empty for an int range).
func options_of(key: StringName) -> Array:
	var legal: Variant = fields[key][1]
	return legal if legal is Array else []


## The [min, max] range of an int key, or `Vector2i.ZERO` for an enum key.
func range_of(key: StringName) -> Vector2i:
	var legal: Variant = fields[key][1]
	return legal if legal is Vector2i else Vector2i.ZERO


## `value` normalised to the key's type when legal (JSON numbers arrive as
## floats), else null.
func coerce(key: StringName, value: Variant) -> Variant:
	if not fields.has(key):
		return null
	var legal: Variant = fields[key][1]
	if legal is Vector2i:
		if not (value is int or value is float):
			return null
		var n: int = int(value)
		if float(n) != float(value) or n < legal.x or n > legal.y:
			return null
		return n
	for option: Variant in legal:
		if typeof(option) == typeof(value) and option == value:
			return option
	return null
