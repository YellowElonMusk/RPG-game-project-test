## One declared large-area luminance or red change of a flash source
## (ADR-0005 §12; GDD `flash_gate`; story 059). Pure data, held by a
## `FlashSourceDecl`.
class_name FlashTransition
extends Resource

## When the change lands, in seconds on the source's own clock (`MODE`,
## `REPLAY` or `REAL`) from the source's start. Never negative.
@export var offset: float = 0.0
## True for a brightening (↑) change, false for a darkening (↓) one. A
## transition counts as a flash when it opposes the one before it.
@export var rising: bool = true
## True for a red transition (GDD `flash_gate` "Red"), false for a general
## (luminance) one.
@export var red: bool = false
## The change's area as a share of a 10° window, in `(0, 1]`.
@export_range(0.0, 1.0, 0.01) var area: float = 1.0
