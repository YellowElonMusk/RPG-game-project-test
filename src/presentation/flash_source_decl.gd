## The declaration of one flash-capable source (ADR-0005 §12; GDD rule 13
## "Flash limit"; story 059): its class, the clock its transitions are
## declared on, the transitions themselves, and the bounds that make it
## safe when the gate refuses it or exempts it. Shipped declarations live
## under `data/presentation/flash_sources/`, one `.tres` per source, and are
## checked by `PresentationValidators.validate_flash_sources`.
##
## Usage example:
## [codeblock]
## var decl := load("res://data/presentation/flash_sources/retry_flash.tres") as FlashSourceDecl
## if decl.flash_class == FlashSourceDecl.CLASS_GATED:
##     handle = flash_gate.request(decl.source_id, clock, rate)
## [/codeblock]
class_name FlashSourceDecl
extends Resource

## Asks the gate before playing; plays its capped variant when refused.
const CLASS_GATED: StringName = &"gated"
## Always booked; the sources around it yield (the boss flood).
const CLASS_RESERVED: StringName = &"reserved"
## Never covers `flash_area_min` on its own (a small hit spark).
const CLASS_EXEMPT_AREA: StringName = &"exempt_area"
## Never swings `flash_luma_delta` (campfire flicker, a slow fade).
const CLASS_EXEMPT_SWING: StringName = &"exempt_swing"
## Every legal class.
const CLASSES: Array[StringName] = [CLASS_GATED, CLASS_RESERVED, CLASS_EXEMPT_AREA, CLASS_EXEMPT_SWING]

## The mode clock (freezes with the Menu).
const CLOCK_MODE: StringName = &"mode"
## A battle replay clock (runs at speed, latches).
const CLOCK_REPLAY: StringName = &"replay"
## Real time (Game State's and the UI's transitions).
const CLOCK_REAL: StringName = &"real"
## Every legal clock.
const CLOCKS: Array[StringName] = [CLOCK_MODE, CLOCK_REPLAY, CLOCK_REAL]

## The red-transition threshold (GDD `flash_gate` "Red"): a change in
## `(R - G - B) * 320` of more than this is a red transition.
const RED_CHANGE_MAX: float = 20.0

## The source's id, as passed to `FlashGate.request()`.
@export var source_id: StringName = &""
## One of `CLASSES`. A source that declares no exemption is gated.
@export var flash_class: StringName = CLASS_GATED
## One of `CLOCKS`: the clock `transitions` are declared on. Must be named.
@export var clock: StringName = &""
## The full variant's transitions, in offset order.
@export var transitions: Array[FlashTransition] = []

@export_group("Capped variant (gated)")
## Peak relative-luminance swing of the capped variant's declared frames.
@export var capped_luma_swing: float = 0.0
## Peak `(R - G - B) * 320` change of the capped variant's declared frames.
@export var capped_red_change: float = 0.0
## The capped variant's area as a share of a 10° window.
@export var capped_area: float = 1.0

@export_group("Exemption bounds")
## Area-exempt only: the largest area the effect ever covers (10° window share).
@export var max_area: float = 0.0
## Swing-exempt only: the largest relative-luminance swing the effect makes.
@export var peak_luma_swing: float = 0.0
## Swing-exempt only: the largest `(R - G - B) * 320` change the effect makes.
@export var peak_red_change: float = 0.0
