## Walks a `Conversation` line by line (Dialogue system, systems index #17):
## skips lines whose flag conditions fail, sets flags, follows `next_id` and
## choice jumps. Pure logic, no nodes; the Dialogue overlay drives it.
##
## Flags and names come in as Callables so tests need no world:
## `has_flag: func(flag: String) -> bool`, `set_flag: func(flag: String)`,
## `speaker_name: func(char_id: String) -> String` (returns "" when the
## member is not in the party, which skips their line).
##
## Usage example:
## [codeblock]
## var run := ConversationRunner.new(talk, world.has_flag, world.set_flag)
## while not run.is_finished():
##     print(run.speaker(), ": ", run.text())
##     if run.choices().is_empty():
##         run.advance()
##     else:
##         run.choose(0)
## [/codeblock]
class_name ConversationRunner
extends RefCounted

## The `next_id` / `goto_id` that ends the conversation.
const END: String = "end"
## Jumps followed before the runner gives up on a looping conversation.
const MAX_STEPS: int = 256

var _talk: Conversation = null
var _has_flag: Callable
var _set_flag: Callable
var _speaker_name: Callable
var _index: int = -1
var _steps: int = 0
## Every flag this runner set, in order (tests).
var flags_set: PackedStringArray = PackedStringArray()


func _init(talk: Conversation, has_flag: Callable = Callable(), set_flag: Callable = Callable(),
		speaker_name: Callable = Callable()) -> void:
	_talk = talk
	_has_flag = has_flag
	_set_flag = set_flag
	_speaker_name = speaker_name
	_enter(0)


## `true` once the conversation has no line left to show.
func is_finished() -> bool:
	return _talk == null or _index < 0 or _index >= _talk.lines.size()


## The line being shown, or null when finished.
func current() -> DialogueLine:
	return null if is_finished() else _talk.lines[_index]


## The current line's text ("" when finished).
func text() -> String:
	var line: DialogueLine = current()
	return line.text if line != null else ""


## The current line's speaker name: a squad member's display name for a
## `speaker_id` line, else `speaker` ("" for a narrator line).
func speaker() -> String:
	var line: DialogueLine = current()
	if line == null:
		return ""
	if not line.speaker_id.is_empty():
		var name: String = _name_of(line.speaker_id)
		return name if not name.is_empty() else line.speaker
	return line.speaker


## The current line's choices (empty for none).
func choices() -> Array[DialogueChoice]:
	var line: DialogueLine = current()
	return line.choices if line != null else ([] as Array[DialogueChoice])


## Moves past a line without choices. A line with choices waits for
## `choose()`; calling this on one does nothing.
func advance() -> void:
	var line: DialogueLine = current()
	if line == null or not line.choices.is_empty():
		return
	_jump(line.next_id)


## Picks choice `i` of the current line: sets its flag and follows its
## `goto_id`. Out of range does nothing.
func choose(i: int) -> void:
	var options: Array[DialogueChoice] = choices()
	if i < 0 or i >= options.size():
		return
	var choice: DialogueChoice = options[i]
	_raise(choice.sets_flag)
	_jump(choice.goto_id)


func _jump(target: String) -> void:
	if target == END:
		_index = _talk.lines.size()
	elif target.is_empty():
		_enter(_index + 1)
	else:
		var to: int = _talk.index_of(target)
		if to < 0:
			push_error("ConversationRunner: %s has no line '%s'" % [_talk.id, target])
			_index = _talk.lines.size()
		else:
			_enter(to)


# Lands on the first shown line at or after `from`, then sets its flag.
func _enter(from: int) -> void:
	_index = from
	if _talk == null:
		return
	while _index < _talk.lines.size():
		_steps += 1
		if _steps > MAX_STEPS:
			push_error("ConversationRunner: %s loops" % _talk.id)
			_index = _talk.lines.size()
			return
		var line: DialogueLine = _talk.lines[_index]
		if _shown(line):
			_raise(line.sets_flag)
			return
		_index += 1


func _shown(line: DialogueLine) -> bool:
	if not line.requires_flag.is_empty() and not _flag(line.requires_flag):
		return false
	if not line.skip_if_flag.is_empty() and _flag(line.skip_if_flag):
		return false
	if not line.speaker_id.is_empty() and _speaker_name.is_valid() and _name_of(line.speaker_id).is_empty():
		return false
	return true


func _flag(flag: String) -> bool:
	return _has_flag.call(flag) if _has_flag.is_valid() else false


func _raise(flag: String) -> void:
	if flag.is_empty():
		return
	flags_set.append(flag)
	if _set_flag.is_valid():
		_set_flag.call(flag)


func _name_of(char_id: String) -> String:
	return String(_speaker_name.call(char_id)) if _speaker_name.is_valid() else ""
