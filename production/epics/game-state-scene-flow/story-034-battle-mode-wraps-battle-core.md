# Story 034: Battle mode wraps BattleCore and BattleHud and owns the start snapshot

> **Epic**: Game State & Scene Flow
> **Status**: Ready (lands in one commit with 033 and 035, when 035 closes)
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md` (migration story: no GDD acceptance criterion)
**Requirement**: `TR-gamestate-004` (snapshot hooks), `TR-gamestate-003` (built from the descriptor)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§7: snapshot after `BattleCore` is built, `null` = swap failure, HP/MP carryover contract, `start_battle(false)` only; Migration Plan Step 2 bullet 2, Battle mode clause); ADR-0006: Battle Replay Ownership (§5 first-entry call order, Retry order, Exit order, end-of-fight holds; outcome reported only after the replay's last beat); ADR-0010: Turn Battle System (§3 `BattleFactory.build`, the interim enemy-ID table, one RNG per instance not restored on Retry; §5 reporting; §6; §7 `clear_transients`)
**ADR Decision Summary**: A Battle mode scene wraps `BattleCore` + `BattleHud`, builds the fight through `BattleFactory` from the descriptor, clears party transients, starts with `start_battle(false)`, implements `capture_start_snapshot`/`restore_start_snapshot`, and reports outcomes to the machine.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0006 2026-10-22 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `GameMode` subclass with typed-return overrides; `BattleHud` as a child of a mode scene under a disabled `ModeHost` shares story 025's verification item.

**Control Manifest Rules (this layer)**:
- Required: "Under Game State the Battle mode must call `BattleCore.start_battle(false)`, never `retry_battle()`."
- Required: "Clearing the party's per-fight transients belongs to the Battle mode, through `BattleCore.clear_transients(party)` before `start_battle(false)`."
- Forbidden: "Never call `BattleCore.retry_battle()` for Retry under Game State — it full-heals the squad."
- Required: "`mode_entered(BATTLE)` still fires on a same-mode (Retry) row, but listeners must not re-apply entry state …"

---

## Acceptance Criteria

*Migration story: the criterion is ADR-0002 Migration Plan Step 2, bullet 2 (Battle mode clause), made checkable by the derived checks below (QA RC-5).*

- [ ] **Step 2.2** — "… a Battle mode scene wrapping `BattleCore` + `BattleHud` that implements the snapshot hooks and the carryover contract …", with "the retry tests move to the Battle mode."
  1. [ ] Entry builds through `BattleFactory`, clears transients before start, and `capture_start_snapshot()` returns a non-null `BattleStartSnapshot`.
  2. [ ] Retry restores party HP/MP/items/states and the enemy group on the same `BattleCore`, with zero scene loads.
  3. [ ] Victory: the outcome is reported before the end banner shows, `report_results_done` only after confirm on the banner, and carryover damage persists on the requester's own `Combatant`s.
  4. [ ] A boss-count failure (0 or 2 boss enemies on `is_boss`) fails `setup()` and rolls back to the Overworld with no orphans.
  5. [ ] Story 032's retry test, moved to `tests/unit/battle/battle_mode_snapshot_test.gd`, passes with unchanged expected values.
  6. [ ] Grep gates: no `retry_battle(` or `start_battle()` without `false` in `battle_mode.gd`; no `BattleCore.new` outside `battle_factory.gd` and the two harnesses.

---

## Implementation Notes

*Derived from ADR-0002 §7, ADR-0006 §5, ADR-0010 §3/§5/§7 and the QA gate (RC-5):*

- **Landing group:** lands in one commit with 033 and 035 when 035 closes.
- **First-entry call order** (ADR-0006 §5, simplified while no replay controller exists): build through `BattleFactory` → `BattleCore.clear_transients(party)` → boss resolution if `is_boss` (zero or several boss enemies → swap failure → rollback) → `start_battle(false)` → (the machine calls) `capture_start_snapshot()`. Steps involving `BattleReplayController` are N/A until ADR-0006 ships; leave TODO markers at their positions.
- **Retry** (`restore_start_snapshot`): restore party HP/MP and clear transients → `start_battle(false)`. Never `start_battle()` or `retry_battle()` (both full-heal). The light request and the `is_transition_flash_capped()` blend choice (ADR-0006 §5 step 3) belong to Presentation; leave a TODO.
- **Carryover:** the party `Combatant`s are the requester's instances, changed in place.
- **Reporting:** Victory → `report_battle_outcome(VICTORY)` → results screen (interim: BattleHud's end banner, dismissed by `confirm`) → `report_results_done()`. Defeat → `report_battle_outcome(DEFEAT)`. **Fled is not wired** until `battle_fled` exists (ADR-0010 §5); leave a TODO (AC-13 is covered at machine level by 016). With no replay today, reporting on `battle_ended` satisfies "after the last beat" trivially; document it as interim.
- **RNG:** one per Battle-mode instance, not restored on Retry (ADR-0010 §3; GDD OQ-2 pending).
- **Deterministic outcome driving (QA):** each test pins one method, either a seeded RNG with fixture combatants and scripted `submit_action`, or the external `battle_ended.emit` for reporting-order cases.
- **Cross-domain (accepted):** this story adds the minimal `BattleFactory` (with ADR-0010's interim enemy-ID → factory table) and `BattleCore.clear_transients(party)`; Turn Battle (gameplay-programmer) reviews. Content-migration story 029 later makes `BattleFactory` read enemy records and deletes the interim table.
- `battle_debug_harness.tscn` and `battle_hud_demo.tscn` stay as standalone harnesses and may keep calling `retry_battle()` (harness-only).
- Player-observable: the run-and-observe screenshot is taken under 035, once the Battle mode is reachable.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 035: `GameRoot` and the demo.
- Story 041 / content-migration 029: removing the interim enemy table and flag.
- The Battle Replay epic (ADR-0006): the replay controller's gate, takeover and resync.

---

## Files

- `src/battle/battle_mode.gd`, `src/battle/battle_mode.tscn` (extends `GameMode`)
- `src/battle/battle_start_snapshot.gd` (`RefCounted`: party HP/MP, items, states, enemy group)
- `src/battle/battle_factory.gd` (minimal, with ADR-0010's interim table; cross-domain)
- `src/battle/battle_core.gd` (adds `clear_transients(party)`; cross-domain)
- `tests/unit/battle/battle_mode_snapshot_test.gd` (the moved 032 retry test)
- `tests/integration/game_state/game_state_battle_mode_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: numbered checks, deterministic outcome driving, grep gates). The developer implements against these — do not invent new test cases during implementation.*

- **Check 1**: `game_state_battle_mode_test.gd :: test_entry_builds_and_snapshots`
  - Given: the real `GameStateMachine` + production loader + `battle_mode.tscn`; a descriptor with interim enemy IDs; a fixture party.
  - When: Overworld (stub) → Battle.
  - Then: `capture_start_snapshot()` returns a non-null `BattleStartSnapshot`; party transients cleared before start; `BattleCore` built only via `BattleFactory`.
- **Check 2**: `test_retry_restores`
  - When: damage the party and kill one enemy, report Defeat, `choose_retry`.
  - Then: party hp/mp/items/states equal the snapshot; the enemy group is back at start values; `BattleCore` `is_same` before/after; counting-loader `begin_swap == 0`.
- **Check 3**: `test_victory_carryover_and_report_order`
  - When: a deterministic win.
  - Then: `report_battle_outcome(VICTORY)` recorded before the end banner shows; `report_results_done` only after a synthetic confirm on the banner; after return, `is_same(party[i], requester squad[i])` and damage taken persists.
- **Check 4**: `test_boss_count_failure_rolls_back`
  - Then: `is_boss` with 0 or 2 boss enemies → `setup` fails → the machine is back in OVERWORLD, error logged, no orphans.
- **Check 5**: `battle_mode_snapshot_test.gd` (unit; the moved 032 retry file) — expected values unchanged from 032.
- **Check 6 (review)**: grep gates as listed in the criterion.
  - Edge cases: Fled wiring is a TODO (016 covers AC-13).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/game_state/game_state_battle_mode_test.gd` — must exist and pass. Gate level: BLOCKING.
- Logic (moved): `tests/unit/battle/battle_mode_snapshot_test.gd` — must pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-012-failed-swap-rolls-back.md`, `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`, `production/epics/game-state-scene-flow/story-032-chapter-flow-characterization.md`, `production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`
- Unlocks: `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`, `production/epics/game-state-scene-flow/story-041-remove-interim-enemy-validation-flag.md`, `production/epics/content-migration/story-029-battle-factory-reads-enemy-records.md` (the `BattleFactory` it changes)
