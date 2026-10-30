## The overworld's SFX event ids: one per row of the GDD audio table
## (`design/gdd/overworld-exploration-encounters.md`, Visual/Audio
## Requirements § Audio direction; story 126, AC-53).
##
## `OverworldMode.sfx_cue(event, subject)` fires one of these on the frame its
## visual twin first shows ([A11Y]: every sound has a visual twin). This is
## only the trigger seam: the Audio Manager (no epic yet) will connect to the
## signal and own the sounds, layers and mix.
## TODO(audio-manager): connect the Audio Manager to `OverworldMode.sfx_cue`.
class_name OverworldSfx
extends RefCounted

## Pen-click "ahem"; twin: the "!" slip and notice pose (a symbol enters Noticing).
const NOTICE: StringName = &"notice"
## Hurried footsteps, paper rustle; twin: chase pose and paper trail (Chasing).
const CHASE: StringName = &"chase"
## Dazed paper flutter; twin: orbiting slips (Stunned, shown on the reveal).
const STUN: StringName = &"stun"
## Paper tear and reactions; twin: the on-screen clutter removal starting.
const LIBERATION: StringName = &"liberation"
## A short paper-tear sting; twin: the payoff card's "Street cleared" line.
const LIBERATION_OFF_SCREEN: StringName = &"liberation_off_screen"
## Stamp thunk; twin: the DENIED stamp with the checkpoint's failure line.
const CHECKPOINT_DENIED: StringName = &"checkpoint_denied"

## Every event, in audio-table order.
const ALL: Array[StringName] = [&"notice", &"chase", &"stun", &"liberation",
		&"liberation_off_screen", &"checkpoint_denied"]
