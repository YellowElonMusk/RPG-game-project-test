## Plain-data payload for `open_overlay(MENU, payload)` (ADR-0002 §5-§6,
## story 029). The machine decides what the Menu offers for the mode it is
## opening over and passes it here; the Menu overlay scene (UI Framework, not
## this epic) only renders `entries`. No Callable fields.
class_name MenuPayload extends RefCounted

## Ordered, exact list (AC-31). Battle, including Battle with the Defeat
## Prompt on top: `[&"settings", &"quit"]`. Overworld and Camp:
## `[&"pause", &"party", &"codex", &"settings", &"quit"]`.
var entries: Array[StringName] = []
