## One line of a `Conversation` (Dialogue system, systems index #17): who
## says it, what they say, when it is shown and where the talk goes next.
##
## A line is skipped when `requires_flag` is set and missing, or when
## `skip_if_flag` is set and present. `speaker_id` names a squad member's
## `char_` record, whose display name is shown instead of `speaker`; a
## squad member's line is skipped when that member is not in the party.
##
## Usage example (in a conversation .tres):
## [codeblock]
## [sub_resource type="Resource" id="l_karen"]
## script = ExtResource("line")
## speaker_id = "char_karen"
## text = "I'd like to speak to whoever is in charge of this queue."
## [/codeblock]
class_name DialogueLine
extends Resource

## Optional label other lines and choices jump to (`goto_id`, `next_id`).
@export var id: String = ""
## Who speaks, shown verbatim; "" for a narrator line with no name.
@export var speaker: String = ""
## A squad member's `char_` record ID; when set, its display name wins over
## `speaker` (squad banter).
@export var speaker_id: String = ""
## What is said.
@export_multiline var text: String = ""
## Shown only while this story flag is set; "" for always.
@export var requires_flag: String = ""
## Skipped while this story flag is set; "" for never.
@export var skip_if_flag: String = ""
## Story flag set when the line is shown; "" for none.
@export var sets_flag: String = ""
## Where the talk goes after this line: "" = the next line, `"end"` = end,
## anything else = the line with that `id`. Ignored when there are choices.
@export var next_id: String = ""
## Answers shown once the line is fully revealed; empty for none.
@export var choices: Array[DialogueChoice] = []
