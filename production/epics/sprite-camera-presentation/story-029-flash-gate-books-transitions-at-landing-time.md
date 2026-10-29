# Story 029: FlashGate books every large-area transition at its landing time, not its request

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-015`, `TR-presentation-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings (the Reduce Flashing comfort setting)
**ADR Decision Summary**: `FlashGate` (a `GameRoot/Services` service) books every large-area luminance source's transitions at their landing time against an injected real-time clock, refusing a request that would exceed `flash_rate_max` flashes in any closed one-second window; a reserved source always books; Reduce Flashing refuses every gated request.
**ADR Version**: ADR-0005 2026-10-22; ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `FlashGate` itself introduces no post-cutoff API — it is a plain `RefCounted`/service driven by an injected clock (integer microseconds in tests), so the Menu never resets it. ADR-0005's HIGH risk rating is carried from its rendering domain generally; this story's logic is headless and needs no windowed verification.

**Control Manifest Rules (this layer)**:
- Required: "Every large-area luminance source must have a `FlashSourceDecl` and book through `FlashGate.request()`/`book_reserved()`. A discarded source's booking must be cancelled via `FlashGate.cancel()`" (FlashGate and the capture tool, ADR-0005 §12–§13).
- Required: "`SettingsService.set_value()` debounces writes... Invalid fields are replaced by their `SettingsSchema` default and logged" (Save/Load & Settings, ADR-0009 §7) — relevant to how Reduce Flashing's live value reaches the gate.
- Forbidden: "Never read a global shader uniform back from `RenderingServer`" — not applicable to this clause set; no Core Forbidden rule names the gate's booking algorithm directly, which instead lives in ADR-0005 §12 (quoted in Implementation Notes).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-25 [L]** (P-05) `flash_gate`, driven with an injected real-time clock in integer microseconds and transitions declared as offsets. **Landing, not request**: three stamps declaring ↑ +50,000 µs and ↓ +150,000 µs, requested at 0, 200,000 and 400,000 µs: the first two are allowed and the third is refused and plays capped; with a limit of 5 passed directly into the gate under test, all three are allowed. **Counting**: a fixed sequence of one stamp every 100,000 µs for 10 s never books more than `flash_rate_max` flashes in any closed one-second window; N alternating booked transitions count as N − 1 flashes. **Refusal**: a refused request books nothing and plays the capped variant; with Reduce Flashing On, every gated request is refused. **Reserved**: a boss flood books its transition even when the gate would refuse a gated source; a gated source that would then exceed the limit is refused; a fixture reserved sequence that alone exceeds the limit fails boot validation. **Menu**: with the window already holding `flash_rate_max` booked flashes, a request 200,000 µs later that would add one more is refused, with the Menu opened and closed in between; the Menu's own open/close transitions are gated requests too, refused in this fixture, playing capped and booking nothing. **Frozen source**: a stamp allowed and frozen by the Menu between its ↑ and its ↓ counts as pending at its resume-time landing; on resume the ↓ is re-booked with reserved priority and always lands; no closed one-second window of the composite frame holds more than `flash_rate_max` flashes. **Clock rate**: a gated two-flash source (↑↓↑↓) allowed at 1× and latched after its first ↑ has its unlanded transitions re-booked at compressed landing times; if that would exceed the limit, its first ↓ still lands and its second ↑↓ are dropped and play capped; a transition after a scheduled wind-up-to-hold rate change lands within one frame of its schedule-integrated `t_land`. **Capped means capped**: every source's capped variant has no general transition and no red transition, or stays below `flash_area_min`; a saturated-red capped variant fails boot validation. **Aggregation**: with two area-exempt sparks each at 10% of a window, a third at 10% goes through the gate; one at 4% starts exempt. **Definitions** on fixture frame pairs: a 0.11 swing at darker-state 0.78 is a transition, 0.09 is not; 0.11 at 0.82 is not; a saturated-red fixture pair where linear and gamma encodings disagree is classified as a transition; a change over 26% of one 10° window counts, 24% does not.

---

## Implementation Notes

*Derived from ADR-0005 Decision §12 (`FlashGate`):*

- **Clock.** A real-time clock is injected (integer microseconds in tests), so the Menu never resets it.
- **Declarations.** Each source has a `FlashSourceDecl` resource: class (gated, reserved, area-exempt or swing-exempt); clock (`MODE`, `REPLAY` or `REAL`); transitions (offset, direction, general/red, area share of a 10° window); its capped variant's declared peak luminance swing and peak red change, or area below `flash_area_min`; for area-exempt sources, its largest area. All are validated at boot, including every scripted reserved sequence at 1×, the largest `battle_speed_mult` and the largest `ff_mult`.
- **Requests.** `request(source_id, clock, rate) -> int` books a gated source's transitions at `t_land = now + (o − clock.call()) / rate` iff no closed one-second window would then hold more than `flash_rate_max` flashes, counted as transitions opposing their predecessor; returns a handle or `-1` (refused: the caller plays capped). With Reduce Flashing On it always returns `-1`. `set_rate(handle, rate) -> bool` re-books unlanded transitions at the new rate (`0` while the Menu freezes the source's clock: they are held unbooked); false means the re-booking would exceed the limit, dropping only not-yet-started transitions. **Closing transitions never drop** and re-book with reserved priority, so a raised screen always returns to rest. `book_reserved(source_id, clock, rate)` books unconditionally, and `set_rate` on a reserved handle always succeeds. `cancel(handle)` removes a booking's unlanded transitions. `begin_exempt(source_id) -> int` / `end_exempt(handle)` track `A_exempt`; when the sum would reach `flash_area_min`, `begin_exempt` returns `-1` and the caller requests the gate instead.
- **Consumers** (out of scope here): Game State and the UI Framework receive the gate through `setup()`, like every service; the gate never delays a source.
- This story's test fixture supplies the real-time clock as an injected `Callable` (integer microseconds), never `Time.get_ticks_usec()` directly, so the test is deterministic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-032-missing-boss-preset-fails-boot.md`: boot validation of flash source declarations as part of the general content-error sweep.
- The Game State retry-flash and UI Framework Menu-backdrop consumers of `FlashGate` (built in their own epics, not this one).
- The settings service that supplies the live Reduce Flashing value (ADR-0009, not yet built — named as a dependency below).

---

## Files

- `src/presentation/flash_gate.gd`
- `data/presentation/flash_source_decl.gd`
- `tests/unit/presentation/flash_gate_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/flash_gate_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: the settings service (ADR-0009, `src/save/settings_service.gd`, not yet built — supplies the live Reduce Flashing value this gate must honour)
- Unlocks: None
