# Story 026: An invalid player override is discarded, defaults stay active, and exactly one notice fires; the next load fires none

> **Epic**: Input System
> **Status**: Complete (2026-10-30)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-001` (overrides persist via Save/Load; hook only)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§3 "A remap ... recompiles the table from overrides", Key Interfaces `apply_overrides`, `binding_override_discarded`); ADR-0009: Save/Load & Settings (§7 binding overrides: format, boot, discard, notice delivery)
**ADR Decision Summary**: Player overrides are `"action:device:input"` triples applied by `GameRoot` through `apply_overrides()`. An invalid set is discarded whole, the default table stays active, and `binding_override_discarded` fires once; `GameRoot` routes that to `settings.clear_bindings()`, so the next load has no overrides and no notice.
**ADR Version**: ADR-0003 2026-10-21; ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond the shared ADR-0003 notes.

**Control Manifest Rules (this layer)**:
- Required: "**The resolver's capture mode is reached only through ADR-0008's `InputCapture` facade** (the remap screen). `InputBindingsValidator.validate_bindings(triples)` validates player overrides. Only `GameRoot` applies binding overrides to the resolver (`apply_overrides()`)"
- Required: "**The resolver reference never leaves `GameStateMachine` and `UiService`.** ... (`GameRoot`, the composition root, constructs it and calls `apply_overrides()`, and passes it to nobody else — ADR-0009 §7.)"
- Forbidden: "**Fallback bindings (a code constant) are used only when the catalog is `FAILED`**; never extended into a second default-bindings source"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-22 [VS]** An invalid player override is discarded, defaults are active, and exactly one notice signal is emitted. On the next load, zero notices are emitted.

*Scope note:* AC-22 is the only [VS] AC. It covers an invalid override at the override layer, not the remap screen. The epic scope includes "the player-override layer and its interface to Save/Load", so this story is Ready (ruling 2026-10-23). Its "next load" clause is tested against a stub settings participant; the real file round-trip belongs to the Save/Load epic (ADR-0009 §7).

---

## Implementation Notes

*Derived from ADR-0003 §3, Key Interfaces, and ADR-0009 §7:*

- **Format.** Overrides use the same `"action:device:input"` triples as `InputBindings` (ADR-0009 §7).
- **`apply_overrides(overrides: PackedStringArray)`.** It merges overrides over the defaults record, validates the merged set with the same rules as story 003 (the shared rule core in `InputBindingsValidator`), and then does one of two things:
  - if valid, recompiles the binding table, with no engine-global mutation;
  - if invalid, keeps the defaults table untouched and emits `binding_override_discarded(reason: String)` **exactly once**, whatever the number of bad triples.

  An empty array is valid and a no-op, with zero signals.
- **Merge rule (recommended reading, owner to confirm).** Neither ADR-0009 §7 nor ADR-0003 defines whether an override triple *adds* to or *replaces* the defaults for its action and device. *technical-director (ADR-0009 owner) and game-designer to confirm.* AC-22 does not need it: every invalid fixture below is invalid **under any merge rule**, which is the QL-STORY-READY 2026-10-23 recommended approach. Merge semantics are needed for the valid-path test and the VS remap screen, not for this story's done gate; keep the merge step isolated in one function so the ruling changes one place.
- **Invalid fixtures (each invalid under any merge rule):**
  - `["confirm:key:NotAKey"]`;
  - `["confirm"]`;
  - `["jump:key:J"]`;
  - `["confirm:mouse:left"]`;
  - a mixed set `["inspect:key:E", "confirm:key:NotAKey", "cancel"]` (one otherwise-valid triple binding the unbound key E, plus two bad ones).
- **"Defaults are active" is proven by:**
  - E emits nothing after the mixed set;
  - story 001's discrete-binding parametrization (its `default_binding_events.gd` table) passing on the same resolver.
- **"Next load".** At resolver level, the next load means a fresh `InputResolver` given the cleared override set. ADR-0009 §7: `GameRoot` connects `binding_override_discarded` to `settings.clear_bindings()`, which clears the stored overrides and queues **one** notice. Test it with a stub settings object: invalid set → one signal → the stub's stored value becomes `[]` → new resolver + `apply_overrides(stub.get_value(&"bindings"))` → zero signals.
- **Fallback bindings.** `apply_overrides` must not be called while the resolver runs on the fallback bindings: ADR-0009 says `GameRoot` skips it. Guard it defensively anyway: log and ignore it if the resolver was built from `make_fallback_bindings()` (zero signals; Enter still emits `confirm`).
- **Only `GameRoot` applies overrides.** Tests call `apply_overrides` directly. That is fine: it is a unit test, not production code.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Save/Load epic: the real `SettingsService`, the file write and `pending_notices()`.
- `production/epics/game-state-scene-flow/`: the `GameRoot` wiring (`apply_overrides()` call, `clear_bindings()` connection).
- Vertical Slice: the remap screen, capture mode (`begin_capture` / `end_capture`, ADR-0009 §7 amendment) and `validate_bindings()`.

---

## Files

- `src/input/input_resolver.gd` (`apply_overrides(overrides: PackedStringArray)`, `binding_override_discarded(reason: String)`)
- `src/input/input_bindings_validator.gd` (a shared rule core usable on a merged triple set)
- `tests/unit/input/input_overrides_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: fixtures invalid under any merge rule, "defaults active" proof, merge rule logged as open). The developer implements against these — do not invent new test cases during implementation.*

**AC-22** — an invalid override set is discarded with exactly one notice; the next load emits none.

```
Test: an invalid override set is discarded with exactly one notice
Given: R with DEFAULT; rec
When:  apply_overrides(each invalid fixture), parametrized
Then:  count(binding_override_discarded) == 1 (also for the mixed set with 2 bad triples); after the mixed set, pressing E emits nothing; every default discrete binding still emits its action (reuse story 001's table)
Edge cases:
  - apply_overrides(PackedStringArray()) gives 0 signals and the defaults unchanged
  - the reason string is not asserted
```

```
Test: the next load emits no notice
Given: a stub settings object with get_value(&"bindings") and clear_bindings() (which sets its value to []); R connected binding_override_discarded → stub.clear_bindings
When:  apply_overrides(stub.get_value(&"bindings")) with the mixed set stored; then a new R2 = InputResolver.new(...), apply_overrides(stub.get_value(&"bindings"))
Then:  R emits 1 signal and the stub's value == []; R2 emits 0 signals
Edge cases:
  - the fallback guard: a resolver built from make_fallback_bindings() given apply_overrides(invalid) emits 0 signals and still emits confirm on Enter
```

OPEN (not in the done gate): override merge semantics (add vs replace) — technical-director (ADR-0009) and game-designer to rule; needed for the valid-path test and the VS remap screen.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_overrides_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-30; tests/unit/input 240/240, single-dir run, tag sin3)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-001-default-bindings-press-release.md`
  - `production/epics/input-system/story-003-bindings-validation.md`
- Unlocks: None

## Completion Notes

*2026-10-30, implementation (autonomous run, tag sin3).*

- **Files**: `src/input/input_resolver.gd` (`apply_overrides(PackedStringArray)`, isolated static `merge_overrides()`, fallback guard via `bindings.id == bindings_fallback` with push_warning, recompiling the table only when valid); `src/input/input_bindings_validator.gd` (`validate_rows()` shared rule core, `validate()` delegates to it); `tests/unit/input/input_overrides_test.gd`.
- **Tests**: each of the 5 invalid fixtures gives exactly 1 notice, and story 001's discrete table still passes on the same resolver; after the mixed set, E emits nothing; an empty set is a no-op; next load through StubSettings gives 1 notice, a stored value of [], then 0 notices on R2; the fallback guard gives 0 notices and Enter still emits confirm.
- **Deviations / OPEN**: merge rule implemented as *replace per (action, device)* in one function, pending the technical-director/game-designer ruling. No valid-path test, per the story. SettingsService/GameRoot wiring (connecting to clear_bindings) does not exist yet; it belongs to the Save/Load and GameRoot epics.
