## Pure, static validator for the `bindings` catalog record type (ADR-0003
## §6, GDD rule 7), registered through `ContentCatalog.register_record_validator`
## in `ContentBootstrap.run()` before `load_all()` (ADR-0004 §4). Enforces:
## every action (the seven discrete actions, `move` checked as each `move_*`
## sub-action) has at least one keyboard and one gamepad binding; no key or
## button is bound to two actions on the same device (the same token on `key`
## vs `pad` is fine, since the claim is keyed by device); every token parses;
## no mouse binding appears in the record (mouse is fixed).
##
## `field` convention (pinned, story 003; the only rule discriminator a test
## may use -- never `message`):
##   - missing keyboard binding: `"bindings.<action>.key"`
##   - missing gamepad binding: `"bindings.<action>.pad"`
##   - double-bound key or button: `"bindings.<device>:<input>"`
##   - an entry that does not parse (malformed, unknown action, unknown
##     device, unknown input token, or mouse): `"bindings[<index>]"`
##
## Usage example:
## [codeblock]
## var errors: Array[Dictionary] = InputBindingsValidator.validate(record)
## if errors.is_empty():
##     pass # record is valid
## [/codeblock]
class_name InputBindingsValidator


## Devices this validator recognizes. Mouse is deliberately absent -- mouse
## is fixed and never appears in the record (ADR-0003 §6) -- so a `"mouse"`
## entry falls through to the same "does not parse" path as any other
## unknown device.
const _KNOWN_DEVICES: Array[String] = ["key", "pad", "pad_axis"]


## Validates one `InputBindings` record. Pure: calling it twice on the same
## record gives the same result (story 003 QA purity edge case). An empty
## array means valid.
static func validate(record: InputBindings) -> Array[Dictionary]:
	return validate_rows(record.bindings)


## The shared rule core (story 026): validates a bare `{action, device,
## input}` row set -- a record's `bindings`, or the defaults merged with
## player overrides -- with exactly the record rules above. Pure.
static func validate_rows(rows: Array) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	# "device:input" token -> the first action that claimed it. Scoping the
	# token by device is what makes the same input string legal on both `key`
	# and `pad` (ADR-0003 §6).
	var claims: Dictionary = {}
	var has_key: Dictionary = {}
	var has_pad: Dictionary = {}

	for index: int in rows.size():
		var parsed: Dictionary = _parse_entry(rows[index])
		if parsed.is_empty():
			errors.append(_error("bindings[%d]" % index))
			continue
		var action: StringName = parsed["action"]
		var device: String = parsed["device"]
		var input: String = parsed["input"]
		var token: String = "%s:%s" % [device, input]

		if claims.has(token) and claims[token] != action:
			errors.append(_error("bindings.%s" % token))
		else:
			claims[token] = action

		if device == "key":
			has_key[action] = true
		else:
			has_pad[action] = true

	for action: StringName in InputActions.DISCRETE:
		_check_coverage(action, has_key, has_pad, errors)
	for action: StringName in InputActions.MOVE:
		_check_coverage(action, has_key, has_pad, errors)

	return errors


# One structured error entry (ADR-0004 §4 as amended): severity plus field.
# message and related_locations are left to their catalog defaults -- tests
# assert on severity and field only, never message (content-catalog
# convention).
static func _error(field: String) -> Dictionary:
	return {"severity": &"error", "field": field}


# Reports a missing keyboard or gamepad binding for one action.
static func _check_coverage(action: StringName, has_key: Dictionary,
		has_pad: Dictionary, errors: Array[Dictionary]) -> void:
	if not has_key.has(action):
		errors.append(_error("bindings.%s.key" % action))
	if not has_pad.has(action):
		errors.append(_error("bindings.%s.pad" % action))


# Parses one `{action, device, input}` entry. Returns {} (invalid) when the
# action is unknown, the device is unknown, or the token does not parse for
# that device -- the three outcomes this story folds into one
# "bindings[<index>]" field.
static func _parse_entry(entry: Dictionary) -> Dictionary:
	var action: StringName = StringName(entry.get("action", ""))
	var device: String = String(entry.get("device", ""))
	var input: String = String(entry.get("input", ""))
	if action == &"" or device == "" or input == "":
		return {}
	if not InputActions.DISCRETE.has(action) and not InputActions.MOVE.has(action):
		return {}
	if not _KNOWN_DEVICES.has(device):
		return {}
	if not _token_parses(device, input):
		return {}
	return {"action": action, "device": device, "input": input}


# Parses one token against its device's vocabulary (ADR-0003 §4): keyboard
# through OS.find_keycode_from_string(), gamepad buttons and axes through
# InputResolver's own fixed positional vocabularies -- never a second copy of
# that vocabulary, never InputMap.
static func _token_parses(device: String, input: String) -> bool:
	match device:
		"key":
			return OS.find_keycode_from_string(input) != KEY_NONE
		"pad":
			return InputResolver.PAD_BUTTON_TOKENS.has(input)
		"pad_axis":
			return _axis_token_parses(input)
		_:
			return false


# Parses one `pad_axis` token (e.g. "left_y-") into its axis name and sign,
# the shared rule core story 026 reuses on a merged triple set
# (Implementation Notes). Mirrors InputResolver's own axis-token split.
static func _axis_token_parses(token: String) -> bool:
	if token.length() < 2:
		return false
	var axis_name: String = token.substr(0, token.length() - 1)
	var sign_char: String = token.substr(token.length() - 1)
	if sign_char != "+" and sign_char != "-":
		return false
	return InputResolver.PAD_AXIS_TOKENS.has(axis_name)
