# Story 020: A camp registered by walking past becomes the last camp registered; outside writes are rejected

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (grew from S: the registered-camp Retreat path moved here from story 021)
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§11 `register_camp`; §4 the detached Overworld is freed on Retreat); ADR-0012: Overworld Exploration (§4 `camp_returns` derived from `machine.last_camp_id`; annotation b `CampEntryPayload`); ADR-0009: Save/Load & Settings (marks unsaved progress)
**ADR Decision Summary**: The machine is the only writer of `last_camp_id`; `CampEntryPayload` (camp entry) and `register_camp` (walking past, Overworld only) are its two inputs. Retreat runs Battle → Camp to that camp and frees the frozen Overworld.
**ADR Version**: ADR-0002 2026-10-21 (Last Verified; §11 revised 2026-10-23) · ADR-0012 2026-10-23 · ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine plus GDScript property `set()` semantics. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`register_camp(camp_id)` is the second input to `last_camp_id`: only the Overworld mode calls it, only in `OVERWORLD`; an empty ID is logged and ignored; it emits no signal and marks unsaved progress (ADR-0009)."
- Forbidden: "Never write `last_camp_id` from anything but the machine (`CampEntryPayload` or `register_camp`)."
- Required: "A detached Overworld is freed explicitly on Retreat, on Quit to Title and in `GameRoot._exit_tree()`. Tests must assert no orphan nodes."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-28 [L]** (rule 9) GIVEN the Overworld registers a camp it walked past (no mode change), THEN the last camp registered is that camp, and a later Retreat goes there. A write to the last camp registered from outside this system (any path other than camp entry or the Overworld's registration call) is rejected, and the value read back is unchanged.

---

## Implementation Notes

*Derived from ADR-0002 §4, §11, ADR-0012 §4 and the QA gate (RC-2):*

- `register_camp(camp_id)` sets `last_camp_id` **only while `current_mode == OVERWORLD` and `phase == IDLE`**. In any other mode or phase it is logged and ignored. An empty `camp_id` is logged and ignored. It emits **no signal** and marks unsaved progress for ADR-0009. Before SaveService exists, that is an injected `Callable` (or a dirty flag) the test reads.
- **Outside writes.** A getter-only GDScript property still accepts assignment into its own storage. Declare `last_camp_id` with an explicit `set(value)` that logs `&"last_camp_write_rejected"` and **does not assign**; the machine writes its private backing field.
- **Registered-camp Retreat moved here (QA RC-2).** `choose_retreat()` (when offered, story 018) runs Battle → Camp (`fade`) with `CampEntryPayload(camp_id = last_camp_id)`. During SWAP the loader frees Battle and calls `free_frozen_overworld()` (unparented nodes are not freed by their old parent). Assert the target through the stub loader's recorded `begin_swap` payload.
- This story owns `src/game_state/camp_entry_payload.gd` (ADR-0012 Payloads), used by both Overworld → Camp (002) and Retreat.
- Story 021 keeps only the region-default fallback, the no-camp non-offer and the `full_restore` flag.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 021: region-default camp, no-camp non-offer, `CampEntryPayload.full_restore`.
- Story 002: the Overworld → Camp row (camp entry recording, asserted there).

---

## Files

- `src/game_state/game_state_machine.gd` (`register_camp`, guarded `last_camp_id` setter, `choose_retreat` to the registered camp)
- `src/game_state/camp_entry_payload.gd`
- `tests/unit/game_state/game_state_register_camp_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: registered-camp Retreat moved here, dependencies 017 and 018, target asserted on the loader payload). The developer implements against these — do not invent new test cases during implementation.*

- **AC-28 (register and Retreat)**: `game_state_register_camp_test.gd :: test_walk_past_registers_and_retreat_goes_there`
  - Given: OVERWORLD, IDLE; an unsaved-progress spy (injected Callable or dirty flag).
  - When: `register_camp("camp_b")`; then Overworld→Battle (`retreat_allowed` true); DEFEAT; `choose_retreat()`; run to IDLE.
  - Then: `last_camp_id == "camp_b"` immediately and no signal was recorded by `register_camp`; the dirty spy is marked once; the `begin_swap` payload is a `CampEntryPayload` with `camp_id == "camp_b"`; `free_frozen_overworld` called once; mode CAMP.
- **AC-28 (outside write)**: `test_outside_write_rejected`
  - When: `machine.last_camp_id = "hacked"`.
  - Then: the value reads back unchanged; log code `&"last_camp_write_rejected"`.
- **AC-28 (guards)**: `test_register_ignored_outside_overworld`
  - When: `register_camp` in CAMP, BATTLE, TITLE, and in OVERWORLD with `phase != IDLE`; an empty string in OVERWORLD.
  - Then: ignored and logged in every case.
  - Edge cases: a later `register_camp("camp_c")` overwrites; Overworld→Camp (`CampEntryPayload "camp_d"`) also overwrites (002).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_register_camp_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (468/468 suite-wide; 3 new test cases)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`, `production/epics/game-state-scene-flow/story-018-retreat-offer-no-stale-flag.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`, `production/epics/game-state-scene-flow/story-021-retreat-region-default-and-no-camp.md`

---

## Completion Notes

**Files**:
- `src/game_state/camp_entry_payload.gd` (new) -- `camp_id: String`, used by `choose_retreat()`; Story 002 will reuse it for Overworld -> Camp entry.
- `src/game_state/game_state_machine.gd`:
  - `last_camp_id` gained an explicit `set(value)` that logs `&"last_camp_write_rejected"` and does not assign; the machine still writes `_last_camp_id` directly.
  - `register_camp()` now also requires `phase == IDLE` (previously mode-only), and calls the injected `_mark_unsaved` hook once on a successful write (ADR-0009, pre-SaveService).
  - `_init()` gained an 8th, defaulted parameter `mark_unsaved: Callable = Callable()` -- positionally after `flash_gate`, so every existing call site is unaffected.
  - `choose_retreat()` now builds a `CampEntryPayload(camp_id = last_camp_id)` and passes it to the Battle -> Camp transition instead of `null`.
  - `_end_out_phase()` calls `_loader.free_frozen_overworld()` on the Battle -> Camp row, before `begin_swap()`, since an unparented Overworld is not freed by its old parent.
- `tests/unit/game_state/doubles/stub_scene_loader.gd`: added `free_frozen_overworld_count` + override (previously inherited the base no-op, uncounted).
- `tests/unit/game_state/doubles/game_state_fixtures.gd`: `make_machine_in_overworld()` gained an optional `mark_unsaved: Callable` 3rd parameter, forwarded to `_init`.
- `tests/unit/game_state/doubles/unsaved_progress_spy.gd` (new) -- mirrors `QuitSpy`; stands in for `SaveService.mark_unsaved()` until ADR-0009 ships it.
- `tests/unit/game_state/game_state_register_camp_test.gd` (new) -- the 3 QA cases: `test_walk_past_registers_and_retreat_goes_there`, `test_outside_write_rejected`, `test_register_ignored_outside_overworld` (covers OVERWORLD+non-IDLE, BATTLE, TITLE, CAMP and an empty-string guard, plus the register/overwrite edge cases).

**Tests**: full suite 468/468 (465 baseline + 3 new), 0 errors, 0 orphans. Import and gdUnit4 run both clean.

**Deviations**:
- The `UnsavedProgressSpy` passed to `make_machine_in_overworld()` is constructed **without** the shared `SequenceRecorder`, so its own call doesn't appear as a "signal recorded by register_camp" in that assertion -- its count is read directly off `call_count` instead.
- `_mark_unsaved` is an injected `Callable` (not a dirty-flag bool), per the Implementation Notes' "or a dirty flag" alternative -- chosen to match the existing `_quit_hook` pattern already in `_init`.
- `register_camp`'s rejection log codes (`&"empty_camp_id"`, `&"register_camp_wrong_mode"`) were kept from the pre-existing implementation rather than invented fresh; only `&"last_camp_write_rejected"` was specified by the story and is new.

**Owed**: none against this story's QA Test Cases. Story 002 still owns wiring `CampEntryPayload` into the Overworld -> Camp SWAP-time write path (out of scope here, per Out of Scope).
