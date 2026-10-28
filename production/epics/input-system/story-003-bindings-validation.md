# Story 003: Bindings validation errors on a missing keyboard or gamepad binding and a double-bound key; the valid default set reports zero

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§6, §7); ADR-0004: Content Boot Ordering (§4, as amended 2026-10-23)
**ADR Decision Summary**: `InputBindingsValidator.validate` is a pure static validator registered with the catalog through `register_record_validator(&"bindings", ...)` in `ContentBootstrap`, before `load_all()`. A code-constant fallback binding set (`make_fallback_bindings()`) is used only when the catalog is `FAILED`.
**ADR Version**: ADR-0003 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure function. `OS.find_keycode_from_string()` is used for the token-parse rule (NOT SOURCEABLE in the engine reference; verify behaviour on an unknown token returns `KEY_NONE`).

**Control Manifest Rules (this layer)**:
- Required: "**Bindings validation (`InputBindingsValidator`) registers via `ContentCatalog.register_record_validator(&"bindings", ...)`** inside `ContentBootstrap`, before `load_all()`"
- Required: "**`register_record_validator(type, validator)`** — `validator: func(record) -> Array[Dictionary]` returns structured entries (`severity`, `field`, `message`, optional `related_locations`) and must be pure (empty array = valid; amended 2026-10-23)"
- Required: "**An ADR that adds a registrant must name its line in `ContentBootstrap.run()`**"
- Forbidden: "**Fallback bindings (a code constant) are used only when the catalog is `FAILED`**; never extended into a second default-bindings source"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-3** Validation reports an error for an action with no keyboard binding, an action with no gamepad binding, and a key bound to two actions. A valid default set reports zero errors.
- [ ] **T-FALLBACK** (folded, ADR-0003 §7, no GDD AC): `make_fallback_bindings()` passes `InputBindingsValidator`'s token parsing and compiles into a usable table.

---

## Implementation Notes

*Derived from ADR-0003 §6–§7 and ADR-0004 §4 (amended 2026-10-23):*

- **Validator shape.** `static func validate(record: InputBindings) -> Array[Dictionary]` is static and pure. It returns structured entries (`severity`, `field`, `message`, optional `related_locations`), and an empty array means valid. The catalog fills `record_id`/`location`. Tests assert on `severity` and `field`, never on `message` (content-catalog convention).
- **`field` convention (pinned in this story).** `field` is free-form under ADR-0004 §4, so this is a story decision and needs no ADR change. It is the only rule discriminator tests may use, and T-FALLBACK and story 026 rely on it:

  | Rule | `field` |
  |---|---|
  | missing keyboard binding | `"bindings.<action>.key"` |
  | missing gamepad binding | `"bindings.<action>.pad"` (a `move` gap is reported per `move_*`) |
  | double-bound key or button | `"bindings.<device>:<input>"` |
  | a triple that does not parse (malformed, unknown action, unknown device, unknown input token) | `"bindings[<index>]"` |
  | mouse in record | `"bindings[<index>]"` |

  `severity` is the content-catalog error constant. Confirm the exact value against content-catalog story 016.
- **Rules enforced:**
  - every action has at least one keyboard and one gamepad binding, with `move` checked as each `move_*` sub-action;
  - no key or button is bound to two actions **on the same device**: the same token on `key` vs `pad` is fine;
  - every token parses;
  - no mouse bindings appear in the record (mouse is fixed).

  The AC names only three cases. The token-parse and mouse-in-record cases are edge cases in the same test file, because they are the ADR's rules for the same function.
- **Fixtures.** Each one is the default set with **one** change, so exactly one entry is expected:
  - `no_keyboard.tres`: drop both `menu:key:*`;
  - `no_gamepad.tres`: drop `inspect:pad:north`;
  - `key_double_bound.tres`: add `cancel:key:Enter`.
- **Registration.** `ContentBootstrap.run()` gains `catalog.register_record_validator(&"bindings", InputBindingsValidator.validate)` in step 3 of the ADR-0004 order, before `load_all()`.
- **Folded test, T-FALLBACK (ADR-0003 §7, no GDD AC).** The fallback is `confirm` (Enter, south), `cancel` (Esc, east), `move` (arrows, d-pad). It intentionally fails the "every action" rule, so the assertion is: "`validate(make_fallback_bindings())` contains no entry whose `field` begins with `bindings[`", plus the compile check that `InputResolver.new(fallback, InputConfig.new())` emits `confirm` on Enter.
- Validation failure fails the catalog, so Boot goes to Content Error. That end-to-end check belongs to `production/epics/game-state-scene-flow/` (ADR-0003 Validation Criteria, last bullet).
- `validate_bindings(triples) -> PackedStringArray` (ADR-0009 §7 amendment) is **not** built here. It serves the remap screen (Vertical Slice). Factor the shared rule core so it can wrap the same checks later (story 026 reuses it on a merged triple set).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: validating player overrides through the shared rule core.
- `production/epics/game-state-scene-flow/`: the boot path to Content Error and the fallback switch on `FAILED`.
- Vertical Slice: `validate_bindings(triples)` for the remap screen.

---

## Files

- `src/input/input_bindings_validator.gd` (`class_name InputBindingsValidator`, `static func validate(record: InputBindings) -> Array[Dictionary]`)
- `src/boot/content_bootstrap.gd` (one registration line)
- `src/input/input_resolver.gd` (`static func make_fallback_bindings()`)
- `tests/unit/input/fixtures/bindings/no_keyboard.tres`
- `tests/unit/input/fixtures/bindings/no_gamepad.tres`
- `tests/unit/input/fixtures/bindings/key_double_bound.tres`
- `tests/unit/input/input_bindings_validator_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: `field` convention, one-change fixtures, T-FALLBACK assertion). The developer implements against these — do not invent new test cases during implementation.*

**AC-3** — missing keyboard/gamepad bindings and a double-bound key are errors; the default set is valid.

```
Test: the valid default set reports zero errors
Given: the record from bindings_default.tres
When:  InputBindingsValidator.validate(record)
Then:  it returns an empty array
Edge cases: running it twice gives the same result (purity)
```

```
Test: each invalid fixture reports exactly one error with the right field
Given: no_keyboard, no_gamepad and key_double_bound (parametrized)
When:  validate(fixture)
Then:  exactly one entry, with the error severity and field "bindings.menu.key", "bindings.inspect.pad" and "bindings.key:Enter" respectively
Edge cases:
  - the same token on key vs pad (e.g. "menu:key:M" and an imaginary pad token) is not double-bound, so zero entries
  - pad button double-bound ("cancel:pad:south" added) gives one entry, field "bindings.pad:south"
  - an unparseable key token ("confirm:key:NotAKey") gives field "bindings[<i>]"
  - malformed "confirm", an unknown action "jump:key:J" and "confirm:mouse:left" each give one "bindings[<i>]" entry
  - a record missing every keyboard binding for move_left gives exactly one entry, "bindings.move_left.key"
```

**T-FALLBACK** — the fallback bindings parse and compile.

```
Test: the fallback bindings parse and compile (T-FALLBACK)
Given: make_fallback_bindings()
When:  validate it; build InputResolver.new(fallback, InputConfig.new()); press Enter, then Esc, then the right arrow
Then:  no entry's field starts with "bindings["; pressed(confirm) and pressed(cancel) are emitted; get_move_vector() == (1, 0)
Edge cases: pad south and east also emit confirm and cancel
```

**Registration** — the validator is registered before `load_all()`.

```
Test: the validator is registered before load_all
Given: ContentBootstrap with a spy catalog
When:  run()
Then:  the spy records register_record_validator(&"bindings", ...) before load_all()
Edge cases: none (the full boot path is game-state-scene-flow's)
```

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_bindings_validator_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (2026-10-28: input_bindings_validator_test.gd, 16 cases; full suite 391/391, exit 0)

---

## Dependencies

- Depends on:
  - `production/epics/input-system/story-001-default-bindings-press-release.md` (token vocabulary, `bindings_default.tres`)
  - `production/epics/content-catalog/story-002-load-one-of-each-type.md` (`ContentBootstrap.run()` and `register_record_validator` skeleton)
  - `production/epics/content-catalog/story-016-field-range-validators.md` (full `register_record_validator` behaviour; the registration line can land before it, but the boot-path check needs 016)
- Unlocks: `production/epics/input-system/story-026-invalid-override-discarded.md`

---

## Completion Notes

*2026-10-28, implementation (autonomous run).*

- **Files**: `src/input/input_bindings_validator.gd` (`InputBindingsValidator.validate`), `InputResolver.make_fallback_bindings()` in `src/input/input_resolver.gd`, the registration in `ContentBootstrap.run()` (before `load_all()`), fixtures `tests/unit/input/fixtures/bindings/{no_keyboard,no_gamepad,key_double_bound}.tres`, `tests/unit/input/input_bindings_validator_test.gd`.
- **Fixture change**: `tests/unit/content_data/fixtures/valid_one_of_each/bindings/bindings_default.tres` used the old `keyboard`/`gamepad`/`button_south` vocabulary and two rows. With the validator now registered at boot it would fail, so it was rewritten to a complete, valid set in the `key`/`pad` vocabulary. Its id and alias are unchanged.
- **Record shape**: validates `Array[Dictionary]` `{action, device, input}` entries (see story 001's notes). `field` values follow the pinned convention (`bindings.<action>.key|pad`, `bindings.<device>:<input>`, `bindings[<index>]`).
- **Engine finding**: a `const` initialized with `PackedStringArray([...])` is a parser error on 4.7.2 ("isn't a constant expression"). It is now a typed `Array[String]` literal. Under `-d`, a parser error drops gdUnit4 into the interactive debugger and the headless run hangs. Run CI with a timeout and `< /dev/null`.
- **Fallback bindings**: `confirm`, `cancel` and `move_*` on keyboard and d-pad only. They deliberately fail the coverage rule, because they are for the Content Error screen only (ADR-0003 §7).
