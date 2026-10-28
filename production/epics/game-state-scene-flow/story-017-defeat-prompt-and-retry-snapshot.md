# Story 017: Defeat opens the Defeat Prompt, and Retry restores the starting snapshot with zero scene loads

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004` (primary); `TR-gamestate-007` carried here (it has no GDD AC)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§7 snapshot handle, the Battle → Battle row, all four signals with `from == to == BATTLE`, no loader call; 2026-10-22 amendment: the machine holds `FlashGate`, `request()` at the start of OUT, `is_transition_flash_capped()`); ADR-0005: Sprite & Camera Presentation (§12 `FlashGate.request(source_id, clock, rate) -> int`, `-1` = capped); ADR-0006: Battle Replay Ownership (§5 Retry order)
**ADR Decision Summary**: Defeat opens the Defeat Prompt over Battle. Retry runs Battle → Battle (`retry_flash`) and, in SWAP, calls `restore_start_snapshot(handle)` on the same Battle instance; no scene is loaded. Flashing transitions book their flash through the injected `FlashGate` once, at the start of OUT.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0005 2026-10-22 · ADR-0006 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine against stubs. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Forbidden: "Never call `BattleCore.retry_battle()` for Retry under Game State — it full-heals the squad."
- Required: "The machine holds the `FlashGate` service, injected via `_init`. At the start of OUT of any flashing transition it calls `flash_gate.request()`, keeps the result for the whole transition, and passes `capped` to the presenter."
- Required: "`mode_entered(BATTLE)` still fires on a same-mode (Retry) row, but listeners must not re-apply entry state over what `restore_start_snapshot()` already set."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-15 [L]** GIVEN outcome Defeat, THEN the Defeat Prompt opens. WHEN Retry is chosen, THEN the battle state equals the battle's starting snapshot fixture (party stats, items, states, enemy group), and the scene-loader spy records zero loads.
- [ ] *(Supporting, TR-gamestate-007, no GDD AC)* Flashing transitions book their flash through the flash gate, and a refused booking plays the capped variant with unchanged timing.

---

## Implementation Notes

*Derived from ADR-0002 §7 and its 2026-10-22 amendment, ADR-0005 §12, and the QA gate (RC-3):*

- At battle entry, *after* the Battle mode builds its `BattleCore`, the machine calls `capture_start_snapshot()` and stores the opaque handle. Defeat opens `DEFEAT_PROMPT` (overlay signals fire; the mode stays Battle). `choose_retry()` closes the prompt and runs Battle → Battle (`retry_flash`). In SWAP it calls `restore_start_snapshot(handle)` on the **same instance** (`is_same`), and the loader spy records **zero** `begin_swap` calls.
- **The test mutates every snapshot component before Defeat** (QA fix), so "equals the starting snapshot" cannot pass vacuously.
- The stub Battle mode implements the snapshot as party stats, items, states and enemy group. Real snapshot contents are story 034's (RNG inclusion is GDD OQ-2; ADR-0010 §3 keeps one RNG per instance, not restored).
- **Flash booking (TR-007).** At the start of OUT of a flashing type (`retry_flash`, `battle_wipe`, `battle_wipe_reverse`) the machine calls `flash_gate.request(source_id, clock, 1.0)` once, keeps the result for the whole transition, and passes `capped = (handle == -1)` to both `play_out` and `play_in`. `is_transition_flash_capped()` reports it and is false outside a transition. Timing is unchanged when capped. `fade` never consults the gate. `flash_gate == null` means never capped.
- **Flash-gate clock and source IDs** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): the machine passes its own tick-accumulated `real_time` (never `mode_time`, which stops under the Menu, and never `Time`). Source IDs are `StringName` constants per flashing type (e.g. `FLASH_SOURCE_RETRY`).
- If ADR-0005's `FlashGate` does not exist yet, add `src/game_state/flash_gate_port.gd`: a minimal interface with `request(...) -> int` that the Presentation `FlashGate` later satisfies; the machine types its parameter against it.
- **TR-007 has no GDD AC.** game-designer should add the proposed AC-34 ("GIVEN the flash gate refuses the retry flash, THEN the presenter plays the capped variant with unchanged timing and `is_transition_flash_capped()` is true"). Until then this supporting test is the only evidence.
- `BattleCore.retry_battle()` stays for the debug harness and is never used for Retry under Game State (it full-heals).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: what the prompt offers.
- Story 019: repeated Retry inputs.
- Story 030: the Defeat Prompt scene and its focus.
- Story 034: the real Battle mode snapshot.

---

## Files

- `src/game_state/game_state_machine.gd` (Defeat → open `DEFEAT_PROMPT`; `choose_retry`; flash booking; `is_transition_flash_capped`)
- `src/game_state/flash_gate_port.gd` (only if `FlashGate` does not exist yet)
- `tests/unit/game_state/game_state_retry_snapshot_test.gd`
- `tests/unit/game_state/game_state_flash_gate_test.gd` (TR-007 supporting test)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: every snapshot component mutated before Defeat, flash-gate clock and source IDs pinned). The developer implements against these — do not invent new test cases during implementation.*

- **AC-15**: `game_state_retry_snapshot_test.gd :: test_defeat_opens_prompt_and_retry_restores`
  - Given: BATTLE entered; stub battle mode state = `fixtures.battle_start_state()` (party hp/mp, items, states, enemy group); the machine has captured the snapshot; then the test mutates every component (hp −10, one item consumed, a state added, one enemy removed).
  - When: `report_battle_outcome(DEFEAT)`; `choose_retry()`; run to IDLE.
  - Then: `overlay_opened(DEFEAT_PROMPT)` after DEFEAT; `overlay_closed(DEFEAT_PROMPT)` before `transition_started(BATTLE, BATTLE)`; `restore_start_snapshot` called once on `is_same(original battle mode)`; stub state deep-equals the fixture; stub loader `begin_swap` count == 0; four transition signals with `from == to == BATTLE`.
- **TR-007 (supporting)**: `game_state_flash_gate_test.gd :: test_flash_booked_and_capped`
  - Given: `stub_flash_gate` scripted (a) accepting, (b) refusing (`-1`).
  - When: a `retry_flash` transition runs, and a `fade` transition runs.
  - Then: `request` called once at OUT start with `(FLASH_SOURCE_RETRY, machine real_time, 1.0)`; `capped == (handle == -1)` passed to both `play_out` and `play_in`; `is_transition_flash_capped()` true during (b) and false after IDLE; phase durations identical in (a) and (b); `fade` → gate untouched; `flash_gate == null` → never capped.
  - Edge cases: no code path calls `BattleCore.retry_battle()` (code-review item).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_retry_snapshot_test.gd` and `tests/unit/game_state/game_state_flash_gate_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (457/457 suite-wide; `game_state_retry_snapshot_test.gd` 1 case, `game_state_flash_gate_test.gd` 3 cases incl. a 2-way parametrize)

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`
- Unlocks: `production/epics/game-state-scene-flow/story-002-transition-table-rows-succeed.md`, `production/epics/game-state-scene-flow/story-018-retreat-offer-no-stale-flag.md`, `production/epics/game-state-scene-flow/story-019-repeated-retry-one-restart.md`, `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`

---

## Completion Notes

**Implemented 2026-10-28.** `report_battle_outcome(DEFEAT)` and `choose_retry()` already existed (story 012's `_battle_snapshot` handle); this story added flash booking and the actual Retry restore.

**Files:**
- `src/game_state/game_state_machine.gd` — `FLASH_SOURCE_RETRY`/`_BATTLE_WIPE`/`_BATTLE_WIPE_REVERSE` + `_FLASH_SOURCE_BY_TYPE`; `real_time` (tick-accumulated, never pauses); `_book_flash()` called from `_begin_transition()`; `_end_out_phase()` now branches Battle→Battle into `_end_retry_swap()` (calls `restore_start_snapshot()` on the loader's current mode node, no `begin_swap`, still emits `mode_exited`/`mode_entered`).
- `src/game_state/flash_gate_port.gd` (new) — `@abstract` `FlashGatePort`, since ADR-0005's own `FlashGate` doesn't exist yet; `_init`'s `flash_gate` param is now typed against it.
- Doubles extended: `tests/unit/game_state/doubles/stub_flash_gate.gd` (now `request() -> int`, subclasses `FlashGatePort`, records calls), `stub_battle_mode.gd` (+`battle_state: Dictionary`, restore now applies a `BattleStateSnapshot`), `battle_state_snapshot.gd` (new, deep-copy handle type), `game_state_fixtures.gd` (+`battle_start_state()`, `make_machine_in_overworld()` takes an optional `flash_gate`).
- Tests: `tests/unit/game_state/game_state_retry_snapshot_test.gd` (AC-15), `tests/unit/game_state/game_state_flash_gate_test.gd` (TR-007, 3 functions incl. the named parametrized case).

**Test count:** 457/457 passing (was 452; +1 snapshot test, +4 flash-gate cases across 3 functions, net of the prior single baseline test file not existing).

**Deviations / items owed:**
- `_FLASH_SOURCE_BY_TYPE` also books `battle_wipe`/`battle_wipe_reverse` per the Implementation Notes, though only `retry_flash` has QA coverage here — the other two are exercised incidentally (every Overworld↔Battle entry/exit in the suite books and grants against a `null` gate) but have no dedicated capped-refusal test. Flagged for story-002 or a future flash-gate story to add explicit coverage.
- `BattleCore.retry_battle()` edge case: not applicable yet — no production code in this epic references `BattleCore` (story 034's concern); nothing to assert against today.
- AC-34 (capped-retry GDD anchor) is still owed by game-designer per the story's own note.
