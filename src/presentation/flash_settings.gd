## The one comfort setting `FlashGate` reads (ADR-0005 §12 Key Interfaces):
## Reduce Flashing. Production reads the Settings service once it exists;
## tests set `reduce_flashing_on` directly.
class_name FlashSettings
extends RefCounted

## Reduce Flashing On: every gated request is refused (GDD rule 13).
var reduce_flashing_on: bool = false


## True when Reduce Flashing is On.
func reduce_flashing() -> bool:
	return reduce_flashing_on
