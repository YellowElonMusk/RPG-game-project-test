## Minimal interface for ADR-0005's `FlashGate` service (§12), added here
## because that class does not exist yet (story 017). `GameStateMachine`
## types its injected `flash_gate` parameter against this port instead of
## against `Object`; Presentation's `src/presentation/flash_gate.gd` will
## subclass (or otherwise satisfy) it once it ships, and test doubles
## subclass it meanwhile (`@abstract` forbids `.new()` on it directly).
@abstract class_name FlashGatePort extends RefCounted

## Books one flash for `source_id` at `clock` (the caller's own tick-
## accumulated clock -- never `Time` or a clock that pauses) and priority
## `priority`. Returns an opaque handle on success, or `-1` if the gate
## refused the booking (capped: Reduce Flashing On, or the gate is busy).
@abstract func request(source_id: StringName, clock: float, priority: float) -> int
