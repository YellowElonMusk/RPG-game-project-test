## One answer the player can pick under a `DialogueLine` (Dialogue system,
## systems index #17). Picking it sets `sets_flag` (when not empty) and jumps
## to the line whose `id` is `goto_id`; an empty `goto_id` carries on with
## the line after the asking one, and `ConversationRunner.END` ends the talk.
##
## Usage example (in a conversation .tres):
## [codeblock]
## [sub_resource type="Resource" id="c_yes"]
## script = ExtResource("choice")
## label = "Go on then."
## sets_flag = "paris_heard_union_tip"
## goto_id = "tip"
## [/codeblock]
class_name DialogueChoice
extends Resource

## What the player picks, shown in the choice list.
@export var label: String = ""
## Story flag set when this choice is picked; "" for none.
@export var sets_flag: String = ""
## The `id` of the line to jump to; "" = the next line, `"end"` = end.
@export var goto_id: String = ""
